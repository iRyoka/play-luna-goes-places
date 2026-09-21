class_name PictureCreationBackdrop
extends Node2D

const BACKGROUND: Texture2D = preload("res://assets/gameplay/picture-creation/picture-nook-background.webp")
const REFERENCE_SIZE := Vector2(2160.0, 1080.0)


func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, REFERENCE_SIZE), false)
