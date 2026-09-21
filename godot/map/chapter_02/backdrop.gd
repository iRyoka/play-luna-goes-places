@tool
class_name Chapter02Backdrop
extends ChapterBackdrop

## Chapter 2's supplied production map. The shared map controller continues to
## draw authored progression routes above this background.

const BACKGROUND: Texture2D = preload("res://assets/environments/chapter-02/map/chapter-background.webp")
# Kept for the blank, still-temporary Chapter 2 selection card until Task 59.
const SKY_COLOR := Color("#bcd7dd")
const BANDS: Array[Dictionary] = [
	{"color": Color("#9fb9c4"), "height": 0.42},
	{"color": Color("#8faa71"), "height": 0.55},
	{"color": Color("#7d9a5f"), "height": 0.70},
	{"color": Color("#8fae66"), "height": 0.86},
]


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, get_draw_size()), false)
	draw_route_segments()
