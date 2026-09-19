@tool
extends ChapterBackdrop

const BACKGROUND: Texture2D = preload("res://assets/environments/chapter-01/map/chapter-background.png")


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, get_draw_size()), false)
	draw_route_segments()
