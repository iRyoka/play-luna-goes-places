extends Node2D

const MARKER_TEXTURE: Texture2D = preload("res://assets/characters/luna/map-marker.png")
const MARKER_SIZE := Vector2(235.0, 235.0)
const FOOT_OFFSET_Y := 82.0
const BEAT_DURATION := 60.0 / 90.0
const IDLE_OFFSET_X := 4.0
const IDLE_ROTATION := deg_to_rad(1.2)

var _idle_tween: Tween
var _foot_anchor_x := 0.0


func _ready() -> void:
	_foot_anchor_x = position.x
	queue_redraw()
	_start_idle()


func _exit_tree() -> void:
	if _idle_tween != null:
		_idle_tween.kill()


func _start_idle() -> void:
	_idle_tween = create_tween().set_loops()
	_idle_tween.set_trans(Tween.TRANS_LINEAR)
	_idle_tween.tween_method(_apply_idle_phase, 0.0, TAU, BEAT_DURATION * 4.0)


func _apply_idle_phase(phase: float) -> void:
	var sway := sin(phase)
	position.x = _foot_anchor_x + sway * IDLE_OFFSET_X
	rotation = sway * IDLE_ROTATION


func _draw() -> void:
	var marker_rect := Rect2(-MARKER_SIZE * 0.5 + Vector2(0.0, -FOOT_OFFSET_Y), MARKER_SIZE)
	draw_texture_rect(MARKER_TEXTURE, marker_rect, false)
