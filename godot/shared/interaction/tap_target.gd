class_name TapTarget
extends Area2D

signal activated(destination_id: StringName)
signal feedback_requested

@export var destination_id: StringName
@export var feedback_target: Node2D

var _activation_locked := false


func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)


func activate() -> void:
	if _activation_locked:
		return
	_activation_locked = true
	feedback_requested.emit()
	_play_press_feedback()
	get_tree().create_timer(0.04).timeout.connect(
		func() -> void: activated.emit(destination_id)
	)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		activate()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		activate()


func _play_press_feedback() -> void:
	if feedback_target == null:
		return
	feedback_target.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(feedback_target, "scale", Vector2(0.92, 0.92), 0.06)
	tween.tween_property(feedback_target, "scale", Vector2(1.04, 1.04), 0.08)
	tween.tween_property(feedback_target, "scale", Vector2.ONE, 0.08)
