class_name PictureCreationViewport
extends Node2D

const REFERENCE_SIZE := Vector2(2160.0, 1080.0)


func _ready() -> void:
	var gameplay := get_parent() as Control
	if gameplay != null:
		gameplay.resized.connect(_apply_layout)
	_apply_layout()


func _apply_layout() -> void:
	var gameplay := get_parent() as Control
	var viewport_size := gameplay.size if gameplay != null else REFERENCE_SIZE
	if viewport_size == Vector2.ZERO:
		viewport_size = REFERENCE_SIZE
	var scale_factor := minf(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y)
	scale = Vector2.ONE * scale_factor
	position = (viewport_size - REFERENCE_SIZE * scale_factor) * 0.5
