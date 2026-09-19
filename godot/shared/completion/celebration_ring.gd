extends Control

const CELEBRATION_RING: Texture2D = preload("res://assets/ui/common/celebration-ring.png")


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var ring_size := minf(size.y * 0.82, 820.0)
	var ring_rect := Rect2(center - Vector2.ONE * ring_size * 0.5, Vector2.ONE * ring_size)
	draw_texture_rect(CELEBRATION_RING, ring_rect, false)
