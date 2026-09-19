class_name PlanterCandidate
extends Button

signal selection_touched(candidate: PlanterCandidate)
signal drag_started(candidate: PlanterCandidate)
signal drag_moved(candidate: PlanterCandidate, global_drag_position: Vector2)
signal drag_released(candidate: PlanterCandidate, global_drop_position: Vector2)

const DRAG_THRESHOLD := 18.0

@export_range(0, 10) var flower_count := 0:
	set(value):
		flower_count = clampi(value, 0, 10)
		queue_redraw()

var _press_position := Vector2.ZERO
var _dragging := false
var _feedback_tween: Tween


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)
	resized.connect(_update_pivot)
	_update_pivot()
	queue_redraw()


func reset_feedback() -> void:
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	rotation = 0.0
	scale = Vector2.ONE
	self_modulate = Color.WHITE
	_dragging = false


func play_wrong_feedback() -> void:
	reset_feedback()
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_feedback_tween.tween_property(self, "rotation", -0.055, 0.07)
	_feedback_tween.tween_property(self, "rotation", 0.055, 0.10)
	_feedback_tween.tween_property(self, "rotation", -0.035, 0.08)
	_feedback_tween.tween_property(self, "rotation", 0.0, 0.07)


func _on_gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_update_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_touch(event.position, event.pressed)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_update_drag(event.position)


func _handle_touch(local_position: Vector2, is_pressed: bool) -> void:
	if is_pressed:
		_press_position = local_position
		_dragging = false
		selection_touched.emit(self)
		return
	if _dragging:
		_dragging = false
		drag_released.emit(self, get_global_transform() * local_position)


func _update_drag(local_position: Vector2) -> void:
	if not _dragging and local_position.distance_to(_press_position) < DRAG_THRESHOLD:
		return
	if not _dragging:
		_dragging = true
		drag_started.emit(self)
	drag_moved.emit(self, get_global_transform() * local_position)


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _draw() -> void:
	PlanterArtRenderer.draw_planter(self, size, flower_count)
