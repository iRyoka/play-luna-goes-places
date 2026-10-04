class_name ContentCatalog
extends Node

var _chapters: Dictionary[StringName, ChapterDefinition] = {}
var _levels: Dictionary[StringName, LevelDefinition] = {}
var _chapter_ids: Array[StringName] = []
var _errors: PackedStringArray = []


func _ready() -> void:
	load_definitions(_build_default_chapters(), _build_default_levels())


func load_definitions(chapters: Array[ChapterDefinition], levels: Array[LevelDefinition]) -> void:
	_chapters.clear()
	_levels.clear()
	_chapter_ids.clear()
	_errors.clear()

	_register_chapters(chapters)
	_register_levels(levels)
	_validate_chapter_membership()
	_validate_chapter_unlocks()
	_validate_progression()
	_validate_scene_references()

	for error_message: String in _errors:
		push_error("Content registry: %s" % error_message)


func is_valid() -> bool:
	return _errors.is_empty()


func get_errors() -> PackedStringArray:
	return _errors.duplicate()


func get_chapter(chapter_id: StringName) -> ChapterDefinition:
	if not is_valid():
		return null
	return _chapters.get(chapter_id)


func get_level(level_id: StringName) -> LevelDefinition:
	if not is_valid():
		return null
	return _levels.get(level_id)


func get_first_chapter_id() -> StringName:
	if not is_valid() or _chapter_ids.is_empty():
		return &""
	return _chapter_ids[0]


func get_chapter_ids() -> Array[StringName]:
	if not is_valid():
		return []
	return _chapter_ids.duplicate()


func _register_chapters(chapters: Array[ChapterDefinition]) -> void:
	for definition: ChapterDefinition in chapters:
		if definition == null:
			_add_error("A chapter definition is missing.")
			continue
		if not _is_valid_id_segment(String(definition.id)):
			_add_error("Chapter has an invalid or missing ID: %s." % definition.id)
			continue
		if _chapters.has(definition.id):
			_add_error("Duplicate chapter ID: %s." % definition.id)
			continue
		if definition.map_scene_path.is_empty():
			_add_error("Chapter %s has no map scene." % definition.id)
		_chapters[definition.id] = definition
		_chapter_ids.append(definition.id)


func _register_levels(levels: Array[LevelDefinition]) -> void:
	for definition: LevelDefinition in levels:
		if definition == null:
			_add_error("A level definition is missing.")
			continue
		if not _is_valid_level_id(String(definition.id)):
			_add_error("Level has an invalid or missing ID: %s." % definition.id)
			continue
		if _levels.has(definition.id):
			_add_error("Duplicate level ID: %s." % definition.id)
			continue
		if not _is_valid_id_segment(String(definition.chapter_id)):
			_add_error("Level %s has an invalid or missing chapter ID." % definition.id)
		if String(definition.id).get_slice("/", 0) != String(definition.chapter_id):
			_add_error("Level %s is not qualified by its chapter ID." % definition.id)
		if definition.scene_path.is_empty():
			_add_error("Level %s has no scene." % definition.id)
		if not _is_valid_id_segment(String(definition.mechanic_family)):
			_add_error("Level %s has an invalid or missing mechanic family." % definition.id)
		if definition.map_marker_id.is_empty():
			_add_error("Level %s has no map marker ID." % definition.id)
		if definition.progression_group_id.is_empty():
			_add_error("Level %s has no progression group ID." % definition.id)
		_levels[definition.id] = definition


func _validate_chapter_membership() -> void:
	for chapter: ChapterDefinition in _chapters.values():
		var listed_levels: Dictionary[StringName, bool] = {}
		for level_id: StringName in chapter.level_ids:
			if listed_levels.has(level_id):
				_add_error("Chapter %s lists level %s more than once." % [chapter.id, level_id])
				continue
			listed_levels[level_id] = true
			var level: LevelDefinition = _levels.get(level_id)
			if level == null:
				_add_error("Chapter %s references missing level %s." % [chapter.id, level_id])
			elif level.chapter_id != chapter.id:
				_add_error("Chapter %s lists level %s from chapter %s." % [chapter.id, level.id, level.chapter_id])

	for level: LevelDefinition in _levels.values():
		var chapter: ChapterDefinition = _chapters.get(level.chapter_id)
		if chapter == null:
			_add_error("Level %s references missing chapter %s." % [level.id, level.chapter_id])
		elif not chapter.level_ids.has(level.id):
			_add_error("Level %s is not listed by chapter %s." % [level.id, chapter.id])


func _validate_chapter_unlocks() -> void:
	for chapter_index in _chapter_ids.size():
		var chapter_id := _chapter_ids[chapter_index]
		var chapter := _chapters[chapter_id]
		if chapter_index == 0 and not chapter.unlock_prerequisite_level_ids.is_empty():
			_add_error("First chapter %s cannot require unlock prerequisites." % chapter_id)
		var seen_prerequisites: Dictionary[StringName, bool] = {}
		for prerequisite_level_id: StringName in chapter.unlock_prerequisite_level_ids:
			if seen_prerequisites.has(prerequisite_level_id):
				_add_error("Chapter %s repeats unlock prerequisite %s." % [chapter_id, prerequisite_level_id])
				continue
			seen_prerequisites[prerequisite_level_id] = true
			var prerequisite: LevelDefinition = _levels.get(prerequisite_level_id)
			if prerequisite == null:
				_add_error("Chapter %s requires unknown unlock prerequisite %s." % [chapter_id, prerequisite_level_id])
				continue
			if prerequisite.chapter_id == chapter_id:
				_add_error("Chapter %s cannot require its own level %s to unlock." % [chapter_id, prerequisite_level_id])
				continue
			# Restricting prerequisites to earlier chapters keeps chapter unlocking
			# acyclic by construction, without a second progression graph.
			if _chapter_ids.find(prerequisite.chapter_id) >= chapter_index:
				_add_error("Chapter %s requires unlock prerequisite %s from a later chapter." % [chapter_id, prerequisite_level_id])


func _validate_progression() -> void:
	for chapter: ChapterDefinition in _chapters.values():
		var nodes_by_level_id: Dictionary[StringName, ChapterProgressionNode] = {}
		for node: ChapterProgressionNode in chapter.progression_nodes:
			if node == null:
				_add_error("Chapter %s has a missing progression node." % chapter.id)
				continue
			if not chapter.level_ids.has(node.level_id):
				_add_error("Chapter %s progression references unlisted level %s." % [chapter.id, node.level_id])
				continue
			if nodes_by_level_id.has(node.level_id):
				_add_error("Chapter %s has duplicate progression for level %s." % [chapter.id, node.level_id])
				continue
			nodes_by_level_id[node.level_id] = node
			_validate_progression_node(chapter, node)

		for level_id: StringName in chapter.level_ids:
			if not nodes_by_level_id.has(level_id):
				_add_error("Chapter %s has no progression for level %s." % [chapter.id, level_id])

		if nodes_by_level_id.size() == chapter.level_ids.size():
			_validate_progression_is_acyclic(chapter, nodes_by_level_id)
			_validate_progression_is_reachable(chapter, nodes_by_level_id)


func _validate_progression_node(chapter: ChapterDefinition, node: ChapterProgressionNode) -> void:
	var prerequisite_ids: Dictionary[StringName, bool] = {}
	for prerequisite_level_id: StringName in node.prerequisite_level_ids:
		if prerequisite_ids.has(prerequisite_level_id):
			_add_error("Chapter %s progression for level %s repeats prerequisite %s." % [chapter.id, node.level_id, prerequisite_level_id])
			continue
		prerequisite_ids[prerequisite_level_id] = true
		if prerequisite_level_id == node.level_id:
			_add_error("Chapter %s progression for level %s cannot require itself." % [chapter.id, node.level_id])
		elif not chapter.level_ids.has(prerequisite_level_id):
			_add_error("Chapter %s progression for level %s references unlisted prerequisite %s." % [chapter.id, node.level_id, prerequisite_level_id])

	if node.required_completed_prerequisites < 0 or node.required_completed_prerequisites > node.prerequisite_level_ids.size():
		_add_error("Chapter %s progression for level %s has an invalid prerequisite quota." % [chapter.id, node.level_id])
	elif node.prerequisite_level_ids.is_empty() and node.required_completed_prerequisites != 0:
		_add_error("Chapter %s starting level %s must require zero prerequisites." % [chapter.id, node.level_id])
	elif not node.prerequisite_level_ids.is_empty() and node.required_completed_prerequisites == 0:
		_add_error("Chapter %s progression for level %s must require at least one prerequisite." % [chapter.id, node.level_id])


func _validate_progression_is_acyclic(
	chapter: ChapterDefinition,
	nodes_by_level_id: Dictionary[StringName, ChapterProgressionNode],
) -> void:
	var visiting: Dictionary[StringName, bool] = {}
	var visited: Dictionary[StringName, bool] = {}
	for level_id: StringName in chapter.level_ids:
		if _has_progression_cycle(level_id, nodes_by_level_id, visiting, visited):
			_add_error("Chapter %s progression contains a cycle." % chapter.id)
			return


func _has_progression_cycle(
	level_id: StringName,
	nodes_by_level_id: Dictionary[StringName, ChapterProgressionNode],
	visiting: Dictionary[StringName, bool],
	visited: Dictionary[StringName, bool],
) -> bool:
	if visiting.has(level_id):
		return true
	if visited.has(level_id):
		return false
	visiting[level_id] = true
	var node := nodes_by_level_id.get(level_id) as ChapterProgressionNode
	if node != null:
		for prerequisite_level_id: StringName in node.prerequisite_level_ids:
			if nodes_by_level_id.has(prerequisite_level_id) and _has_progression_cycle(prerequisite_level_id, nodes_by_level_id, visiting, visited):
				return true
	visiting.erase(level_id)
	visited[level_id] = true
	return false


func _validate_progression_is_reachable(
	chapter: ChapterDefinition,
	nodes_by_level_id: Dictionary[StringName, ChapterProgressionNode],
) -> void:
	var reached: Dictionary[StringName, bool] = {}
	var changed := true
	while changed:
		changed = false
		for level_id: StringName in chapter.level_ids:
			if reached.has(level_id):
				continue
			var node := nodes_by_level_id.get(level_id) as ChapterProgressionNode
			if node == null:
				continue
			var reached_prerequisite_count := 0
			for prerequisite_level_id: StringName in node.prerequisite_level_ids:
				if reached.has(prerequisite_level_id):
					reached_prerequisite_count += 1
			if reached_prerequisite_count >= node.required_completed_prerequisites:
				reached[level_id] = true
				changed = true

	for level_id: StringName in chapter.level_ids:
		if not reached.has(level_id):
			_add_error("Chapter %s progression cannot reach level %s." % [chapter.id, level_id])


func _validate_scene_references() -> void:
	for chapter: ChapterDefinition in _chapters.values():
		_validate_scene(chapter.map_scene_path, "Chapter %s map" % chapter.id, ChapterMap)
	for level: LevelDefinition in _levels.values():
		_validate_scene(level.scene_path, "Level %s" % level.id, LevelController)


func _validate_scene(scene_path: String, label: String, expected_type: Variant) -> void:
	if scene_path.is_empty():
		return
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		_add_error("%s scene is missing: %s." % [label, scene_path])
		return
	var scene := ResourceLoader.load(scene_path, "PackedScene") as PackedScene
	if scene == null:
		_add_error("%s scene could not load: %s." % [label, scene_path])
		return
	var root := scene.instantiate()
	if not is_instance_of(root, expected_type):
		_add_error("%s scene root has the wrong type: %s." % [label, scene_path])
	root.free()


func _add_error(error_message: String) -> void:
	_errors.append(error_message)


func _is_valid_level_id(value: String) -> bool:
	var parts := value.split("/", false)
	return parts.size() == 2 and _is_valid_id_segment(parts[0]) and _is_valid_id_segment(parts[1])


func _is_valid_id_segment(value: String) -> bool:
	if value.is_empty():
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		var is_lowercase_letter := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not is_lowercase_letter and not is_digit and code != 95:
			return false
	return true


func _build_default_chapters() -> Array[ChapterDefinition]:
	return [
		ChapterDefinition.new(
			&"chapter_01",
			"res://map/chapter_01/map.tscn",
			[&"chapter_01/drag_match", &"chapter_01/puzzle_assembly", &"chapter_01/memory_intro", &"chapter_01/memory", &"chapter_01/cooking", &"chapter_01/flying_collector", &"chapter_01/pop_tap"],
			[
				ChapterProgressionNode.new(&"chapter_01/drag_match"),
				ChapterProgressionNode.new(&"chapter_01/puzzle_assembly", [&"chapter_01/drag_match"], 1),
				ChapterProgressionNode.new(&"chapter_01/memory_intro", [&"chapter_01/puzzle_assembly"], 1),
				ChapterProgressionNode.new(&"chapter_01/memory", [&"chapter_01/memory_intro"], 1),
				ChapterProgressionNode.new(&"chapter_01/cooking", [&"chapter_01/memory"], 1),
				ChapterProgressionNode.new(&"chapter_01/flying_collector", [&"chapter_01/cooking"], 1),
				ChapterProgressionNode.new(&"chapter_01/pop_tap", [&"chapter_01/flying_collector"], 1),
			],
		),
		ChapterDefinition.new(
			&"chapter_02",
			"res://map/chapter_02/map.tscn",
			[&"chapter_02/trail_meadow", &"chapter_02/picture_creation", &"chapter_02/procedural_jigsaw", &"chapter_02/crab_mosaic", &"chapter_02/coloring", &"chapter_02/firefly_maze"],
			[
				ChapterProgressionNode.new(&"chapter_02/trail_meadow"),
				ChapterProgressionNode.new(&"chapter_02/picture_creation", [&"chapter_02/trail_meadow"], 1),
				ChapterProgressionNode.new(&"chapter_02/procedural_jigsaw", [&"chapter_02/picture_creation"], 1),
				ChapterProgressionNode.new(&"chapter_02/crab_mosaic", [&"chapter_02/procedural_jigsaw"], 1),
				ChapterProgressionNode.new(&"chapter_02/coloring", [&"chapter_02/crab_mosaic"], 1),
				ChapterProgressionNode.new(&"chapter_02/firefly_maze", [&"chapter_02/coloring"], 1),
			],
			[&"chapter_01/pop_tap"],
		),
	]


func _build_default_levels() -> Array[LevelDefinition]:
	return [
		LevelDefinition.new(&"chapter_01/drag_match", &"chapter_01", "res://levels/drag_match/drag_match.tscn", &"drag_match", &"DragMatchLocation", &"main"),
		LevelDefinition.new(&"chapter_01/memory_intro", &"chapter_01", "res://levels/memory/memory_intro.tscn", &"memory", &"MemoryIntroLocation", &"main"),
		LevelDefinition.new(&"chapter_01/memory", &"chapter_01", "res://levels/memory/memory.tscn", &"memory", &"ValleyLookout", &"main"),
		LevelDefinition.new(&"chapter_01/puzzle_assembly", &"chapter_01", "res://levels/puzzle_assembly/puzzle_assembly.tscn", &"puzzle_assembly", &"NumbersLocation", &"main"),
		LevelDefinition.new(&"chapter_01/cooking", &"chapter_01", "res://levels/cooking/cooking.tscn", &"cooking", &"CreekBend", &"main"),
		LevelDefinition.new(&"chapter_01/flying_collector", &"chapter_01", "res://levels/flying_collector/flying_collector.tscn", &"flying_collector", &"ForestClearing", &"main"),
		LevelDefinition.new(&"chapter_01/pop_tap", &"chapter_01", "res://levels/pop_tap/pop_tap.tscn", &"pop_tap", &"CoastRoad", &"main"),
		LevelDefinition.new(&"chapter_02/trail_meadow", &"chapter_02", "res://levels/trail/trail.tscn", &"trail", &"MountainFalls", &"main"),
		LevelDefinition.new(&"chapter_02/picture_creation", &"chapter_02", "res://levels/picture_creation/picture_creation.tscn", &"picture_creation", &"BambooGrove", &"main"),
		LevelDefinition.new(&"chapter_02/firefly_maze", &"chapter_02", "res://levels/firefly_maze/firefly_maze.tscn", &"firefly_maze", &"GrandTree", &"main"),
		LevelDefinition.new(&"chapter_02/crab_mosaic", &"chapter_02", "res://levels/crab_mosaic/crab_mosaic.tscn", &"crab_mosaic", &"Lighthouse", &"main"),
		LevelDefinition.new(&"chapter_02/coloring", &"chapter_02", "res://levels/coloring/coloring.tscn", &"coloring", &"FerrisWheel", &"main"),
		LevelDefinition.new(&"chapter_02/procedural_jigsaw", &"chapter_02", "res://levels/procedural_jigsaw/procedural_jigsaw.tscn", &"procedural_jigsaw", &"GardenPavilion", &"main"),
	]
