class_name MemoryStageIndicator
extends Control

const INCOMPLETE_MARKER: Texture2D = preload("res://assets/gameplay/numbers/round-incomplete.png")
const COMPLETE_MARKER: Texture2D = preload("res://assets/gameplay/numbers/round-complete.png")

var stage_count := 1:
	set(value):
		stage_count = value
		visible = stage_count > 1
		queue_redraw()

var completed_stage_count := 0:
	set(value):
		completed_stage_count = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	visible = stage_count > 1


func _draw() -> void:
	var center_x := size.x * 0.5
	for index in stage_count:
		var marker_center := Vector2(center_x + (float(index) - float(stage_count - 1) * 0.5) * 76.0, size.y - 70.0)
		var marker_texture := COMPLETE_MARKER if index < completed_stage_count else INCOMPLETE_MARKER
		var marker_rect := Rect2(marker_center - Vector2(29.0, 29.0), Vector2(58.0, 58.0))
		draw_texture_rect(marker_texture, marker_rect, false)
