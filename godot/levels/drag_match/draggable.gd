class_name Draggable
extends Area2D

signal drop_requested(piece: Draggable, drop_position: Vector2)
signal drag_started
signal placed(piece: Draggable)
signal returned_home(piece: Draggable)

enum ShapeKind {
	CIRCLE,
	TRIANGLE,
	SQUARE,
}

@export var match_id: StringName
@export var shape_kind := ShapeKind.CIRCLE
@export var fill_color := Color("#ef796a")
@export var visual_radius := 72.0
@export var touch_radius := 112.0
@export var use_generated_art := false

var _active_pointer_id := -2
var _awaiting_resolution := false
var _drag_offset := Vector2.ZERO
var _feedback_tween: Tween
var _home_global_position := Vector2.ZERO
var _input_enabled := true
var _is_dragging := false
var _drag_motion_unlocked := true
var _is_placed := false
var _pending_pointer_position := Vector2.ZERO
var _resting_z_index := 0


func _ready() -> void:
	input_pickable = true
	_home_global_position = global_position
	_resting_z_index = z_index
	input_event.connect(_on_input_event)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _is_dragging or not _input_enabled or _is_placed:
		return

	if event is InputEventScreenDrag and event.index == _active_pointer_id:
		drag_to(event.position)
	elif event is InputEventScreenTouch and event.index == _active_pointer_id and not event.pressed:
		release_at(event.position)
	elif event is InputEventMouseMotion and _active_pointer_id == -1:
		drag_to(event.position)
	elif event is InputEventMouseButton and _active_pointer_id == -1:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			release_at(event.position)


func begin_drag(pointer_position: Vector2, pointer_id: int = -1) -> bool:
	if not _input_enabled or _is_placed or _is_dragging or _awaiting_resolution:
		return false

	_stop_feedback()
	_active_pointer_id = pointer_id
	_drag_offset = global_position - pointer_position
	_is_dragging = true
	_drag_motion_unlocked = false
	_pending_pointer_position = pointer_position
	z_index = 20
	drag_started.emit()
	var audio_delay := clampf(
		float(AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()),
		0.0,
		0.25
	)
	if audio_delay > 0.0:
		get_tree().create_timer(audio_delay).timeout.connect(_unlock_drag_motion)
	else:
		_unlock_drag_motion()
	return true


func drag_to(pointer_position: Vector2) -> void:
	if not _is_dragging or not _input_enabled or _is_placed:
		return
	_pending_pointer_position = pointer_position
	if not _drag_motion_unlocked:
		return
	global_position = pointer_position + _drag_offset


func release_at(pointer_position: Vector2) -> void:
	if not _is_dragging or not _input_enabled or _is_placed:
		return
	_drag_motion_unlocked = true
	drag_to(pointer_position)
	_is_dragging = false
	_active_pointer_id = -2
	_awaiting_resolution = true
	drop_requested.emit(self, global_position)


func snap_to(target_position: Vector2) -> void:
	if _is_placed:
		return
	_stop_feedback()
	_is_dragging = false
	_awaiting_resolution = false
	_is_placed = true
	_input_enabled = false
	z_index = 2
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(self, "global_position", target_position, 0.2)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	_feedback_tween.finished.connect(func() -> void: placed.emit(self))


func return_home() -> void:
	if _is_placed:
		return
	_stop_feedback()
	_is_dragging = false
	_input_enabled = false
	_awaiting_resolution = true
	z_index = _resting_z_index

	var wiggle := create_tween()
	wiggle.tween_property(self, "rotation", 0.08, 0.05)
	wiggle.tween_property(self, "rotation", -0.06, 0.07)
	wiggle.tween_property(self, "rotation", 0.0, 0.08)

	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(self, "global_position", _home_global_position, 0.24)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.18)
	_feedback_tween.finished.connect(_finish_return_home)


func set_interaction_enabled(enabled: bool) -> void:
	_input_enabled = enabled and not _is_placed
	if not _input_enabled and _is_dragging:
		_is_dragging = false
		_active_pointer_id = -2
		_drag_motion_unlocked = true


func is_dragging() -> bool:
	return _is_dragging


func is_placed() -> bool:
	return _is_placed


func get_home_global_position() -> Vector2:
	return _home_global_position


func set_home_global_position(home_position: Vector2) -> void:
	global_position = home_position
	_home_global_position = home_position


func _finish_return_home() -> void:
	_awaiting_resolution = false
	_input_enabled = true
	returned_home.emit(self)


func _unlock_drag_motion() -> void:
	if not _is_dragging or not _input_enabled or _is_placed:
		return
	_drag_motion_unlocked = true
	global_position = _pending_pointer_position + _drag_offset
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.12)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		begin_drag(event.position, event.index)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			begin_drag(event.position)


func _stop_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()


func _draw() -> void:
	if use_generated_art:
		return
	_draw_shape(Vector2(7.0, 10.0), visual_radius + 5.0, Color(0.12, 0.14, 0.17, 0.2))
	_draw_shape(Vector2.ZERO, visual_radius, fill_color)
	_draw_shape(Vector2(-10.0, -12.0), visual_radius * 0.68, fill_color.lightened(0.12))


func _draw_shape(center: Vector2, radius: float, color: Color) -> void:
	match shape_kind:
		ShapeKind.CIRCLE:
			draw_circle(center, radius, color)
		ShapeKind.TRIANGLE:
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius * 0.92, radius * 0.78),
				center + Vector2(-radius * 0.92, radius * 0.78),
			]), color)
		ShapeKind.SQUARE:
			draw_rect(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color)
