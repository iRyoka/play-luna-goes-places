extends Control

const SPREAD: Texture2D = preload("res://assets/ui/chapter-selection/storybook-spread.png")


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(SPREAD, Rect2(Vector2.ZERO, size), false)
