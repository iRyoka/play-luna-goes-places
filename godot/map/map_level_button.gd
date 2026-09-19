@tool
class_name MapLevelButton
extends Node2D

enum State { LOCKED, AVAILABLE, COMPLETED }

const AVAILABLE_ART: Texture2D = preload("res://assets/ui/map-level-buttons/level-button-available.png")
const COMPLETED_ART: Texture2D = preload("res://assets/ui/map-level-buttons/level-button-completed.png")
const LOCKED_ART: Texture2D = preload("res://assets/ui/map-level-buttons/level-button-unavailable.png")
const VISIBLE_WIDTH := 156.0
# The completed source includes a crown beyond the medallion's circular core.
# Scale it to the same core diameter as the other two source textures, letting
# only the crown extend beyond the standard button footprint.
const COMPLETED_CORE_SCALE := 1.20

var level_number := 1
var state := State.LOCKED:
	set(value):
		state = value
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var texture := _get_texture()
	var visible_width := VISIBLE_WIDTH * COMPLETED_CORE_SCALE if state == State.COMPLETED else VISIBLE_WIDTH
	var scale_factor := visible_width / texture.get_width()
	var draw_size := texture.get_size() * scale_factor
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false)
	_draw_number()


func _get_texture() -> Texture2D:
	match state:
		State.AVAILABLE:
			return AVAILABLE_ART
		State.COMPLETED:
			return COMPLETED_ART
		_:
			return LOCKED_ART


func _draw_number() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 76
	var text := str(level_number)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline := (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var color := Color("#fff8e9") if state != State.LOCKED else Color("#443d37")
	draw_string(font, Vector2(-text_size.x * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
