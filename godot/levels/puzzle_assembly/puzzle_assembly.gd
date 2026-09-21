class_name PuzzleAssemblyLevel
extends LevelController

## Assembles one authored picture at a time from its fixed-orientation parts.
## A level plays the stages of its board in order: the finished picture takes
## its bow, hands over to the next stage, and the last stage resolves the level.
## The board owns every picture-specific value, so a new picture is a resource
## and its artwork rather than a change here.

@export var board: PuzzleBoard
## Fixed start-slot arrangement for tests. Below zero picks a fresh safe one.
@export var shuffle_seed := -1

@onready var placeholder_backing: ColorRect = %PlaceholderBacking
@onready var backdrop: TextureRect = %Backdrop
@onready var backings_container: Node2D = %Backings
@onready var pieces_container: Node2D = %Pieces
@onready var slots_container: Node2D = %Slots

const REVEAL_HOLD := 0.85
const HANDOVER_FADE := 0.3
const REFERENCE_SIZE := Vector2(2160.0, 1080.0)

var _stage_index := 0
var _pieces: Array[PuzzlePiece] = []
var _slots: Array[PuzzleSlot] = []
var _placed_count := 0
var _placement_rng := RandomNumberGenerator.new()
var _assembly_center := Vector2.ZERO
var _is_playable := false
var _viewport_offset := Vector2.ZERO


func _ready() -> void:
	super._ready()
	_viewport_offset = _current_viewport_offset()
	resized.connect(_apply_viewport_offset)
	completion_started.connect(_on_completion_started)
	if get_tree().current_scene == self:
		replay_requested.connect(_restart_preview)
		back_to_chapter_requested.connect(_restart_preview)
		continue_to_chapter_requested.connect(_restart_preview)
	if not _prepare_board():
		return
	_is_playable = true
	_build_stage(0)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_playable or is_level_complete():
		return
	if event is InputEventScreenTouch and event.pressed:
		begin_nearest_drag(event.position, event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		begin_nearest_drag(event.position, -1)


## One press carries one part. Touch regions are deliberately far larger than the
## artwork and overlap their neighbours, so a press is resolved to the part whose
## centre is nearest, and it is ignored entirely while another part is already
## being carried. Without this, every part under the press starts its own drag.
func begin_nearest_drag(pointer_position: Vector2, pointer_id: int) -> PuzzlePiece:
	for piece: PuzzlePiece in _pieces:
		if piece.is_dragging():
			return null
	var nearest: PuzzlePiece
	var nearest_distance := INF
	for piece: PuzzlePiece in _pieces:
		if not piece.can_begin_drag() or not piece.contains_point(pointer_position):
			continue
		var distance := piece.global_position.distance_to(pointer_position)
		if distance < nearest_distance:
			nearest = piece
			nearest_distance = distance
	if nearest == null or not nearest.begin_drag(pointer_position, pointer_id):
		return null
	return nearest


func get_placed_count() -> int:
	return _placed_count


func get_stage_index() -> int:
	return _stage_index


func get_stage_count() -> int:
	if board == null:
		return 0
	return board.get_stage_count()


func is_playable() -> bool:
	return _is_playable


## Reports authoring problems and leaves the level unplayable rather than
## presenting a broken picture.
func _prepare_board() -> bool:
	if board == null:
		push_error("Puzzle level %s has no authored board." % level_id)
		return false
	var errors := board.validate()
	if not errors.is_empty():
		for error: String in errors:
			push_error("Puzzle board problem in %s: %s" % [level_id, error])
		return false
	placeholder_backing.color = board.placeholder_background_color
	if shuffle_seed >= 0:
		_placement_rng.seed = shuffle_seed
	else:
		_placement_rng.randomize()
	return true


func _build_stage(index: int) -> void:
	_stage_index = index
	_placed_count = 0
	_assembly_center = Vector2.ZERO
	pieces_container.scale = Vector2.ONE
	pieces_container.position = Vector2.ZERO
	var stage := board.get_stage(index)
	_apply_backdrop(stage)
	for backing: PuzzlePart in stage.backing_parts:
		_create_backing(backing)
	var slot_order := _slot_order_for(stage)
	for part_index: int in stage.parts.size():
		var part: PuzzlePart = stage.parts[part_index]
		var start_slot: Rect2 = stage.start_slots[slot_order[part_index]]
		_slots.append(_create_slot(part, part_index))
		_pieces.append(_create_piece(part, part_index, start_slot))


## Each picture decides how far its own background is pushed back, because a
## background painted pale needs less pushing than a fully saturated one.
func _apply_backdrop(stage: PuzzleStage) -> void:
	backdrop.texture = board.get_background_for(stage)
	backdrop.visible = backdrop.texture != null
	var dim := clampf(stage.background_dim, 0.0, 1.0)
	backdrop.self_modulate = Color(dim, dim, dim, 1.0)
	var material := backdrop.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("saturation", clampf(stage.background_saturation, 0.0, 1.0))


func _slot_order_for(stage: PuzzleStage) -> Array[int]:
	var order: Array[int] = []
	for index: int in stage.start_slots.size():
		order.append(index)
	if not stage.shuffle_start_slots:
		return order
	for index: int in range(order.size() - 1, 0, -1):
		var other_index := _placement_rng.randi_range(0, index)
		var current := order[index]
		order[index] = order[other_index]
		order[other_index] = current
	return order


func _create_backing(part: PuzzlePart) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Backing_%s" % part.part_id
	sprite.texture = part.artwork
	sprite.scale = part.assembled_scale
	sprite.z_index = part.placed_z_index
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backings_container.add_child(sprite)
	sprite.global_position = _to_viewport_position(part.assembled_position)


func _create_slot(part: PuzzlePart, index: int) -> PuzzleSlot:
	var slot := PuzzleSlot.new()
	slot.name = "Slot%d" % index
	slot.piece_id = part.part_id
	slot.artwork = part.artwork
	slot.artwork_scale = part.assembled_scale
	slot.snap_radius = part.get_snap_radius()
	slot.global_position = _to_viewport_position(part.assembled_position)
	slots_container.add_child(slot)
	return slot


func _create_piece(part: PuzzlePart, index: int, start_slot: Rect2) -> PuzzlePiece:
	var piece := PuzzlePiece.new()
	piece.name = "Piece%d" % index
	piece.piece_id = part.part_id
	piece.artwork = part.artwork
	piece.artwork_scale = part.assembled_scale
	piece.home_artwork_scale = _home_scale_for(part, start_slot.size)
	piece.touch_padding = board.touch_padding
	piece.artwork_touch_radius = part.get_snap_radius()
	piece.home_touch_radius = _home_touch_radius(part, piece.home_artwork_scale)
	piece.placed_z_index = part.placed_z_index
	piece.global_position = _to_viewport_position(start_slot.get_center())
	pieces_container.add_child(piece)
	piece.drag_started.connect(func() -> void: request_sound_effect(&"grab"))
	piece.drop_requested.connect(_on_piece_drop_requested)
	piece.placed.connect(_on_piece_placed)
	return piece


## A resting part fills its slot without ever looking as large as the picture it
## belongs to. The reduction is applied to the authored scale rather than
## replacing it, so a part authored with a non-uniform scale keeps its shape.
func _home_scale_for(part: PuzzlePart, slot_size: Vector2) -> Vector2:
	var assembled_size := part.get_assembled_size()
	var fitted := minf(slot_size.x / assembled_size.x, slot_size.y / assembled_size.y) * board.home_slot_fill
	return part.assembled_scale * minf(fitted, board.home_to_assembled_scale_ratio)


func _home_touch_radius(part: PuzzlePart, artwork_scale: Vector2) -> float:
	var artwork_size: Vector2 = part.artwork.get_size() * artwork_scale
	return maxf(artwork_size.x, artwork_size.y) * 0.5


func _on_piece_drop_requested(piece: PuzzlePiece, drop_position: Vector2) -> void:
	if is_level_complete() or piece.is_placed():
		return
	var matching_slot: PuzzleSlot
	var matching_distance := INF
	for slot: PuzzleSlot in _slots:
		var distance := slot.global_position.distance_to(drop_position)
		if slot.can_accept(piece, drop_position) and distance < matching_distance:
			matching_slot = slot
			matching_distance = distance
	if matching_slot != null:
		matching_slot.accept()
		request_sound_effect(&"drop")
		piece.snap_to(matching_slot.global_position)
		return

	var touched_slot: PuzzleSlot
	var nearest_distance := INF
	for slot: PuzzleSlot in _slots:
		var distance := slot.global_position.distance_to(drop_position)
		if slot.contains(drop_position) and distance < nearest_distance:
			touched_slot = slot
			nearest_distance = distance
	if touched_slot != null:
		touched_slot.play_wrong_feedback()
	request_sound_effect(&"wrong")
	piece.return_home()


func _on_piece_placed(_piece: PuzzlePiece) -> void:
	_placed_count += 1
	if _placed_count == _pieces.size():
		_play_assembly_reveal()


func _play_assembly_reveal() -> void:
	for piece: PuzzlePiece in _pieces:
		piece.set_interaction_enabled(false)
		_assembly_center += piece.global_position
	_assembly_center /= _pieces.size()
	var reveal := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.tween_interval(0.35)
	reveal.tween_method(_set_assembly_scale, 1.0, 1.06, 0.26)
	reveal.tween_method(_set_assembly_scale, 1.06, 0.985, 0.26)
	reveal.tween_method(_set_assembly_scale, 0.985, 1.0, 0.30)
	reveal.tween_interval(REVEAL_HOLD)
	reveal.finished.connect(func() -> void:
		_set_assembly_scale(1.0)
		_resolve_stage()
	)


func _resolve_stage() -> void:
	if _stage_index + 1 >= board.get_stage_count():
		complete_level()
		return
	_hand_over_to_next_stage()


## The finished picture fades away and the next one fades in, so the child reads
## one continued activity rather than a restart.
func _hand_over_to_next_stage() -> void:
	var handover := create_tween().set_trans(Tween.TRANS_SINE)
	handover.tween_property(gameplay, "modulate:a", 0.0, HANDOVER_FADE)
	handover.tween_callback(func() -> void:
		var next_index := _stage_index + 1
		_clear_stage()
		_build_stage(next_index)
	)
	handover.tween_interval(board.stage_handover_duration)
	handover.tween_property(gameplay, "modulate:a", 1.0, HANDOVER_FADE)


## Leaves the tree immediately rather than at the end of the frame, so the next
## stage never shares a frame with the finished one.
func _clear_stage() -> void:
	for piece: PuzzlePiece in _pieces:
		pieces_container.remove_child(piece)
		piece.queue_free()
	for slot: PuzzleSlot in _slots:
		slots_container.remove_child(slot)
		slot.queue_free()
	for backing: Node in backings_container.get_children():
		backings_container.remove_child(backing)
		backing.queue_free()
	_pieces.clear()
	_slots.clear()


func _set_assembly_scale(value: float) -> void:
	pieces_container.scale = Vector2.ONE * value
	pieces_container.position = _assembly_center * (1.0 - value)


func _current_viewport_offset() -> Vector2:
	return (size - REFERENCE_SIZE) * 0.5


func _to_viewport_position(authored_position: Vector2) -> Vector2:
	return authored_position + _viewport_offset


func _apply_viewport_offset() -> void:
	var next_offset := _current_viewport_offset()
	var delta := next_offset - _viewport_offset
	if delta == Vector2.ZERO:
		return
	_viewport_offset = next_offset
	for backing: Node2D in backings_container.get_children():
		backing.global_position += delta
	for slot: PuzzleSlot in _slots:
		slot.global_position += delta
	for piece: PuzzlePiece in _pieces:
		piece.shift_layout(delta)


func _on_completion_started() -> void:
	for piece: PuzzlePiece in _pieces:
		piece.set_interaction_enabled(false)


func _restart_preview() -> void:
	get_tree().reload_current_scene()
