@tool
extends Control

const LOOP_DURATION := 42.0
const CLOUD_DANCE_DURATION := 8.0 / 3.0
const CLOUD_TEXTURES: Array[Texture2D] = [
	preload("res://assets/environments/chapter-01/map/cloud-left.png"),
	preload("res://assets/environments/chapter-01/map/cloud-middle.png"),
	preload("res://assets/environments/chapter-01/map/cloud-center-right.png"),
	preload("res://assets/environments/chapter-01/map/cloud-right.png"),
]
const CLOUD_CENTERS: Array[Vector2] = [
	Vector2(0.058, 0.104),
	Vector2(0.250, 0.096),
	Vector2(0.578, 0.093),
	Vector2(0.891, 0.091),
]
const CLOUD_PHASES: Array[float] = [0.0, 1.9, 3.2, 4.1]
const EDITOR_REFERENCE_SIZE := Vector2(2160.0, 1080.0)
var _animation_time := 0.0:
	set(value):
		_animation_time = value
		queue_redraw()

var _ambient_tween: Tween


func _ready() -> void:
	resized.connect(queue_redraw)
	_ambient_tween = create_tween().set_loops()
	_ambient_tween.set_trans(Tween.TRANS_LINEAR)
	_ambient_tween.tween_property(self, "_animation_time", LOOP_DURATION, LOOP_DURATION).from(0.0)


func _exit_tree() -> void:
	if _ambient_tween != null:
		_ambient_tween.kill()


func _draw() -> void:
	_draw_clouds(_get_draw_size())


func _draw_clouds(draw_size: Vector2) -> void:
	var map_scale := draw_size.y / 1080.0
	var dance_phase := fposmod(_animation_time, CLOUD_DANCE_DURATION) / CLOUD_DANCE_DURATION * TAU
	for index in CLOUD_TEXTURES.size():
		var texture := CLOUD_TEXTURES[index]
		var direction := 1.0 if index % 2 == 0 else -1.0
		var movement := sin(dance_phase) * direction
		var offset := Vector2(movement * 22.0, -absf(movement) * 7.0) * map_scale
		var rotation := movement * deg_to_rad(2.0)
		var texture_size := texture.get_size() * map_scale
		var center := draw_size * CLOUD_CENTERS[index] + offset
		draw_set_transform(center, rotation)
		draw_texture_rect(texture, Rect2(-texture_size * 0.5, texture_size), false)
		draw_set_transform(Vector2.ZERO)


func _get_draw_size() -> Vector2:
	return size if size != Vector2.ZERO else EDITOR_REFERENCE_SIZE
