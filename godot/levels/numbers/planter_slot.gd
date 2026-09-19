class_name PlanterSlot
extends Control

@export_range(0, 10) var flower_count := 0:
	set(value):
		flower_count = clampi(value, 0, 10)
		queue_redraw()

@export var is_missing := false:
	set(value):
		is_missing = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if is_missing:
		PlanterArtRenderer.draw_missing_placeholder(self, size)
		return
	PlanterArtRenderer.draw_planter(self, size, flower_count)
