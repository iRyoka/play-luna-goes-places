@tool
class_name ChapterMap
extends Control

signal location_selected(level_id: StringName)
signal chapter_selection_requested
signal settings_requested
signal sound_requested(sound_id: StringName)

const MARKER_RADIUS := 118.0
## Screen-corner placement for the chapter-selection exit control. The control is
## deliberately independent of the last authored level marker so map routes stay
## readable and the exit remains predictable.
const CHAPTER_EXIT_MARGIN := Vector2(170.0, 150.0)
const EDITOR_REFERENCE_SIZE := Vector2(2160.0, 1080.0)
const LUNA_INDICATOR_NAMES: Array[StringName] = [
	&"LunaIndicatorHanging",
	&"LunaIndicatorStanding",
	&"LunaIndicatorPeeking",
]
const LUNA_MARKER_OFFSETS: Dictionary[StringName, Vector2] = {
	# Each source canvas has a different circular-cutout anchor.
	&"LunaIndicatorHanging": Vector2(-41.0, 19.0),
	&"LunaIndicatorStanding": Vector2(-101.0, 9.0),
	&"LunaIndicatorPeeking": Vector2(-1.0, -46.0),
}

## The chapter this map presents. `App` assigns it before mounting the scene; the
## value stored in the scene drives the editor preview.
@export var chapter_id: StringName = &""
## Marker slot positions as fractions of the map size, keyed by the marker IDs
## used by this chapter's level definitions. Slots may outnumber current levels.
@export var marker_slots: Dictionary = {}

@onready var settings_button: Button = %SettingsButton
@onready var backdrop: ChapterBackdrop = $PlaceholderBackdrop
@onready var markers: Node2D = $Landmarks

var _chapter: ChapterDefinition
var _editor_registry: ContentCatalog
var _marker_nodes: Dictionary[StringName, Node2D] = {}
var _marker_art: Dictionary[StringName, MapLevelButton] = {}
var _chapter_exit: MapChapterExit
var _luna_random := RandomNumberGenerator.new()
var _presented_luna_level_id := &""

static var _last_luna_indicator_name := &""


func _ready() -> void:
	resized.connect(_layout_markers)
	if Engine.is_editor_hint():
		_prepare_editor_preview()
		return

	var game_state := get_node("/root/GameState")
	game_state.connect("completed_levels_changed", _refresh_map)
	settings_button.pressed.connect(_on_settings_pressed)
	_chapter = (get_node("/root/ContentRegistry") as ContentCatalog).get_chapter(chapter_id)
	_create_definition_markers()
	_create_chapter_exit()
	_layout_markers()
	_refresh_map()
	_present_last_played_luna()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		return
	for marker: Node2D in _marker_nodes.values():
		marker.free()
	_marker_nodes.clear()
	_marker_art.clear()
	if _chapter_exit != null:
		_chapter_exit.free()
		_chapter_exit = null
	if _editor_registry != null:
		_editor_registry.free()
		_editor_registry = null


func _prepare_editor_preview() -> void:
	_editor_registry = ContentCatalog.new()
	_editor_registry._ready()
	_chapter = _editor_registry.get_chapter(chapter_id)
	if _chapter == null:
		return
	_create_definition_markers()
	_create_chapter_exit()
	_layout_markers()
	for art: MapLevelButton in _marker_art.values():
		art.state = MapLevelButton.State.COMPLETED
	_update_route_segments(_chapter.level_ids)


func _create_definition_markers() -> void:
	if _chapter == null:
		return
	var registry := _get_content_registry()
	for level_index in _chapter.level_ids.size():
		var level_id := _chapter.level_ids[level_index]
		var definition := registry.get_level(level_id)
		if definition == null or not marker_slots.has(definition.map_marker_id):
			push_error("Chapter map has no marker slot for %s." % level_id)
			continue
		var marker := Node2D.new()
		marker.name = String(definition.map_marker_id)
		markers.add_child(marker)
		_marker_nodes[level_id] = marker

		var art := MapLevelButton.new()
		art.name = "Art"
		art.level_number = level_index + 1
		marker.add_child(art)
		_marker_art[level_id] = art


func _layout_markers() -> void:
	for level_id: StringName in _marker_nodes:
		var definition := _get_content_registry().get_level(level_id)
		if definition != null:
			_marker_nodes[level_id].position = _get_layout_size() * (marker_slots[definition.map_marker_id] as Vector2)
	_layout_chapter_exit()
	_layout_presented_luna()


func _refresh_map() -> void:
	if _chapter == null:
		return
	var game_state := get_node("/root/GameState")
	var completed_ids: Dictionary[StringName, bool] = {}
	for level_id: StringName in _chapter.level_ids:
		if game_state.is_level_completed(level_id):
			completed_ids[level_id] = true
	var available_ids := ProgressionEvaluator.get_available_level_ids(_chapter, completed_ids)
	for level_id: StringName in _marker_art:
		var art := _marker_art[level_id]
		var is_completed := completed_ids.has(level_id)
		art.state = MapLevelButton.State.COMPLETED if is_completed else (MapLevelButton.State.AVAILABLE if available_ids.has(level_id) else MapLevelButton.State.LOCKED)
		_set_marker_tap_target(level_id, available_ids.has(level_id))
	_update_route_segments(available_ids)
	_set_chapter_exit_available(_has_available_other_chapter())


func get_presented_luna_level_id() -> StringName:
	return _presented_luna_level_id


func _present_last_played_luna() -> void:
	if _chapter == null or _chapter.level_ids.is_empty():
		return
	var game_state := get_node("/root/GameState")
	var last_played_level_id := game_state.last_played_level_id as StringName
	_presented_luna_level_id = last_played_level_id if _marker_nodes.has(last_played_level_id) else _chapter.level_ids[0]
	_luna_random.seed = Time.get_ticks_usec()
	var selected_index := _luna_random.randi_range(0, LUNA_INDICATOR_NAMES.size() - 1)
	var selected_indicator_name := LUNA_INDICATOR_NAMES[selected_index]
	if selected_indicator_name == _last_luna_indicator_name:
		selected_index = (selected_index + _luna_random.randi_range(1, LUNA_INDICATOR_NAMES.size() - 1)) % LUNA_INDICATOR_NAMES.size()
		selected_indicator_name = LUNA_INDICATOR_NAMES[selected_index]
	_last_luna_indicator_name = selected_indicator_name
	for indicator_name: StringName in LUNA_INDICATOR_NAMES:
		var indicator := markers.get_node_or_null(NodePath(indicator_name)) as Sprite2D
		if indicator == null:
			continue
		indicator.visible = indicator_name == selected_indicator_name
	_layout_presented_luna()


func _layout_presented_luna() -> void:
	if _presented_luna_level_id == &"":
		return
	for indicator_name: StringName in LUNA_INDICATOR_NAMES:
		var indicator := markers.get_node_or_null(NodePath(indicator_name)) as Sprite2D
		if indicator != null and indicator.visible:
			indicator.position = _marker_nodes[_presented_luna_level_id].position + LUNA_MARKER_OFFSETS[indicator_name]
			return


func _set_marker_tap_target(level_id: StringName, is_available: bool) -> void:
	var marker := _marker_nodes[level_id]
	var target := marker.get_node_or_null("TapTarget") as TapTarget
	if is_available and target == null:
		target = TapTarget.new()
		target.name = "TapTarget"
		target.destination_id = level_id
		target.feedback_target = _marker_art[level_id]
		target.add_to_group(&"chapter_map_targets")
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = MARKER_RADIUS
		collision.shape = shape
		target.add_child(collision)
		marker.add_child(target)
		target.feedback_requested.connect(_on_target_feedback_requested)
		target.activated.connect(_on_target_activated)
	elif target != null:
		target.input_pickable = is_available


func _update_route_segments(available_ids: Array[StringName]) -> void:
	var segments: Array[Dictionary] = []
	var incoming_ids: Dictionary[StringName, Array] = {}
	var outgoing_ids: Dictionary[StringName, Array] = {}
	for node: ChapterProgressionNode in _chapter.progression_nodes:
		for prerequisite_id: StringName in node.prerequisite_level_ids:
			if not _marker_nodes.has(prerequisite_id) or not _marker_nodes.has(node.level_id):
				continue
			if not outgoing_ids.has(prerequisite_id):
				outgoing_ids[prerequisite_id] = []
			if not incoming_ids.has(node.level_id):
				incoming_ids[node.level_id] = []
			outgoing_ids[prerequisite_id].append(node.level_id)
			incoming_ids[node.level_id].append(prerequisite_id)
	for node: ChapterProgressionNode in _chapter.progression_nodes:
		var destination := _marker_nodes.get(node.level_id) as Node2D
		if destination == null:
			continue
		for prerequisite_id: StringName in node.prerequisite_level_ids:
			var source := _marker_nodes.get(prerequisite_id) as Node2D
			if source != null:
				segments.append({
					"from": source.position / _get_layout_size(),
					"to": destination.position / _get_layout_size(),
					"from_handle": _get_route_handle(prerequisite_id, incoming_ids, outgoing_ids),
					"to_handle": _get_route_handle(node.level_id, incoming_ids, outgoing_ids),
					"is_future": not available_ids.has(node.level_id),
				})
	backdrop.set_route_segments(segments)


func _get_route_handle(
	level_id: StringName,
	incoming_ids: Dictionary[StringName, Array],
	outgoing_ids: Dictionary[StringName, Array],
) -> Vector2:
	var incoming: Array = incoming_ids.get(level_id, [])
	var outgoing: Array = outgoing_ids.get(level_id, [])
	if incoming.size() != 1 or outgoing.size() != 1:
		return Vector2.ZERO
	var previous := _marker_nodes.get(incoming[0] as StringName) as Node2D
	var current := _marker_nodes.get(level_id) as Node2D
	var next := _marker_nodes.get(outgoing[0] as StringName) as Node2D
	if previous == null or current == null or next == null:
		return Vector2.ZERO
	var approach := current.position - previous.position
	var departure := next.position - current.position
	var tangent := next.position - previous.position
	if tangent.is_zero_approx() or approach.is_zero_approx() or departure.is_zero_approx():
		return Vector2.ZERO
	var handle_length := minf(approach.length(), departure.length()) * 0.28
	return tangent.normalized() * handle_length / _get_layout_size()


func _create_chapter_exit() -> void:
	if _chapter == null:
		return
	_chapter_exit = MapChapterExit.new()
	_chapter_exit.name = "ChapterExit"
	markers.add_child(_chapter_exit)
	if Engine.is_editor_hint():
		return
	var target := TapTarget.new()
	target.name = "TapTarget"
	target.feedback_target = _chapter_exit
	target.add_to_group(&"chapter_map_exit_targets")
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = MARKER_RADIUS
	collision.shape = shape
	target.add_child(collision)
	_chapter_exit.add_child(target)
	target.feedback_requested.connect(_on_target_feedback_requested)
	target.activated.connect(_on_chapter_exit_activated)


func _set_chapter_exit_available(is_available: bool) -> void:
	if _chapter_exit == null:
		return
	_chapter_exit.visible = is_available
	var target := _chapter_exit.get_node_or_null("TapTarget") as TapTarget
	if target != null:
		target.input_pickable = is_available


func _has_available_other_chapter() -> bool:
	var registry := _get_content_registry()
	var game_state := get_node("/root/GameState")
	for candidate_chapter_id: StringName in registry.get_chapter_ids():
		if candidate_chapter_id == chapter_id:
			continue
		var candidate := registry.get_chapter(candidate_chapter_id)
		if candidate == null:
			continue
		var completed_prerequisites: Dictionary[StringName, bool] = {}
		for prerequisite_level_id: StringName in candidate.unlock_prerequisite_level_ids:
			if game_state.is_level_completed(prerequisite_level_id):
				completed_prerequisites[prerequisite_level_id] = true
		if ProgressionEvaluator.is_chapter_available(candidate, completed_prerequisites):
			return true
	return false


func _layout_chapter_exit() -> void:
	if _chapter_exit == null:
		return
	var layout_size := _get_layout_size()
	_chapter_exit.position = Vector2(
		layout_size.x - CHAPTER_EXIT_MARGIN.x,
		layout_size.y - CHAPTER_EXIT_MARGIN.y,
	)


func _get_content_registry() -> ContentCatalog:
	if _editor_registry != null:
		return _editor_registry
	return get_node("/root/ContentRegistry") as ContentCatalog


func _get_layout_size() -> Vector2:
	return size if size != Vector2.ZERO else EDITOR_REFERENCE_SIZE


func _on_target_activated(level_id: StringName) -> void:
	location_selected.emit(level_id)


func _on_chapter_exit_activated(_destination_id: StringName) -> void:
	chapter_selection_requested.emit()


func _on_settings_pressed() -> void:
	sound_requested.emit(&"tap")
	settings_requested.emit()


func _on_target_feedback_requested() -> void:
	sound_requested.emit(&"tap")
