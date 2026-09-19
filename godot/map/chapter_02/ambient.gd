@tool
extends Node2D

## Gentle decorative motion only; the placed assets do not receive input and are
## deliberately kept clear of route and marker areas.

const LOOP_DURATION := 8.0 / 3.0
const TALL_FLAMINGO_ROCK_DEGREES := 5.0
const SHORT_FLAMINGO_ROCK_DEGREES := 6.0
const EDITOR_REFERENCE_SIZE := Vector2(2160.0, 1080.0)

@onready var tall_flamingo: Node2D = $TallFlamingoPivot
@onready var short_flamingo: Node2D = $ShortFlamingoPivot
@onready var chapter_map: Control = get_parent() as Control

var _animation_time := 0.0:
	set(value):
		_animation_time = value
		_apply_animation()

var _ambient_tween: Tween


func _ready() -> void:
	chapter_map.resized.connect(_scale_to_map)
	_scale_to_map()
	_apply_animation()
	_ambient_tween = create_tween().set_loops()
	_ambient_tween.set_trans(Tween.TRANS_LINEAR)
	_ambient_tween.tween_property(self, "_animation_time", LOOP_DURATION, LOOP_DURATION).from(0.0)


func _exit_tree() -> void:
	if _ambient_tween != null:
		_ambient_tween.kill()


func _scale_to_map() -> void:
	var map_size := chapter_map.size if chapter_map.size != Vector2.ZERO else EDITOR_REFERENCE_SIZE
	scale = map_size / EDITOR_REFERENCE_SIZE


func _apply_animation() -> void:
	var phase := _animation_time / LOOP_DURATION * TAU
	_apply_flamingo(tall_flamingo, phase, 0.0, TALL_FLAMINGO_ROCK_DEGREES)
	_apply_flamingo(short_flamingo, phase, 1.9, SHORT_FLAMINGO_ROCK_DEGREES)


func _apply_flamingo(flamingo: Node2D, phase: float, offset: float, degrees: float) -> void:
	flamingo.rotation = deg_to_rad(sin(phase + offset) * degrees)
