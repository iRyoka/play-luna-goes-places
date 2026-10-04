class_name FireflyTrailFlower
extends Control

const EMISSION := [
	preload("res://assets/gameplay/firefly-maze/breadcrumb-01-emission.png"),
	preload("res://assets/gameplay/firefly-maze/breadcrumb-02-emission.png"),
	preload("res://assets/gameplay/firefly-maze/breadcrumb-03-emission.png"),
	preload("res://assets/gameplay/firefly-maze/breadcrumb-04-emission.png"),
	preload("res://assets/gameplay/firefly-maze/breadcrumb-05-emission.png"),
	preload("res://assets/gameplay/firefly-maze/breadcrumb-06-emission.png"),
]
var _alpha_step := -1
var _alpha := 1.0
var _motif_index := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_quantized_alpha(step: int, total_steps: int) -> void:
	if step == _alpha_step:
		return
	_alpha_step = step
	_alpha = 1.0 - clampf(float(step) / float(total_steps), 0.0, 1.0)
	queue_redraw()


func set_motif_index(index: int) -> void:
	_motif_index = clampi(index, 0, EMISSION.size() - 1)
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(EMISSION[_motif_index], Rect2(Vector2.ZERO, size), false, Color(1.0, 0.95, 0.55, _alpha))
