class_name MemoryCard
extends Button

signal flip_requested(card: MemoryCard)
signal flip_touched(card: MemoryCard)

const SHADOW_COLOR := Color(0.18, 0.12, 0.16, 0.24)
const CARD_FRONT: Texture2D = preload("res://assets/gameplay/memory/card-front.png")
const CARD_BACK: Texture2D = preload("res://assets/gameplay/memory/card-back.png")
const SYMBOL_TEXTURES: Array[Texture2D] = [
	preload("res://assets/gameplay/memory/cat.png"),
	preload("res://assets/gameplay/memory/grapes.png"),
	preload("res://assets/gameplay/memory/flower.png"),
	preload("res://assets/gameplay/memory/bird.png"),
	preload("res://assets/gameplay/memory/shoti.png"),
	preload("res://assets/gameplay/memory/tower.png"),
	preload("res://assets/gameplay/memory/butterfly.png"),
	preload("res://assets/gameplay/memory/pomegranate.png"),
]
const SYMBOL_IDS: Array[StringName] = [
	&"cat",
	&"grapes",
	&"flower",
	&"bird",
	&"bread",
	&"tower",
	&"butterfly",
	&"pomegranate",
]

var pair_id: StringName
var symbol_index := 0
var is_face_up := false
var is_matched := false
var _board_input_enabled := true
var _feedback_tween: Tween


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	resized.connect(_update_pivot)
	gui_input.connect(_on_gui_input)
	pressed.connect(_on_pressed)
	_update_pivot()
	_update_disabled_state()
	queue_redraw()


func configure(card_pair_id: StringName, card_symbol_index: int) -> void:
	pair_id = card_pair_id
	symbol_index = card_symbol_index
	is_face_up = false
	is_matched = false
	_board_input_enabled = true
	_update_disabled_state()
	queue_redraw()


static func symbol_index_for(card_pair_id: StringName) -> int:
	return SYMBOL_IDS.find(card_pair_id)


func request_flip() -> bool:
	if disabled or is_face_up or is_matched:
		return false

	# Request feedback at the touch boundary, before the visual reveal begins.
	flip_requested.emit(self)
	is_face_up = true
	_update_disabled_state()
	queue_redraw()
	_play_reveal_feedback()
	return true


func set_board_input_enabled(enabled: bool) -> void:
	_board_input_enabled = enabled
	_update_disabled_state()


func play_match_feedback() -> Tween:
	is_matched = true
	is_face_up = true
	_update_disabled_state()
	_stop_feedback()
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2(1.13, 1.13), 0.16)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.18)
	return _feedback_tween


func play_mismatch_feedback() -> Tween:
	_stop_feedback()
	var resting_position := position
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_feedback_tween.tween_property(self, "position", resting_position + Vector2(-12.0, 0.0), 0.07)
	_feedback_tween.tween_property(self, "position", resting_position + Vector2(12.0, 0.0), 0.10)
	_feedback_tween.tween_property(self, "position", resting_position, 0.07)
	_feedback_tween.tween_callback(_conceal)
	return _feedback_tween


func _on_pressed() -> void:
	request_flip()


func _on_gui_input(event: InputEvent) -> void:
	if disabled or is_face_up or is_matched:
		return
	if event is InputEventScreenTouch and event.pressed:
		flip_touched.emit(self)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		flip_touched.emit(self)


func _play_reveal_feedback() -> void:
	_stop_feedback()
	scale = Vector2(0.9, 1.06)
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.18)


func _conceal() -> void:
	is_face_up = false
	queue_redraw()
	_update_disabled_state()


func _stop_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = null
	scale = Vector2.ONE


func _update_disabled_state() -> void:
	disabled = not _board_input_enabled or is_face_up or is_matched


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _draw() -> void:
	var card_rect := Rect2(Vector2(8.0, 4.0), size - Vector2(16.0, 16.0))
	var shadow_rect := Rect2(card_rect.position + Vector2(0.0, 10.0), card_rect.size)
	draw_style_box(_card_style(SHADOW_COLOR, 30.0), shadow_rect)
	if is_face_up:
		draw_texture_rect(CARD_FRONT, card_rect, false)
		_draw_pair_symbol(card_rect.get_center(), minf(card_rect.size.x, card_rect.size.y) * 0.39)
	else:
		draw_texture_rect(CARD_BACK, card_rect, false)


func _card_style(fill: Color, radius: float, border := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	return style


func _draw_pair_symbol(center: Vector2, symbol_size: float) -> void:
	var symbol_texture := SYMBOL_TEXTURES[symbol_index % SYMBOL_TEXTURES.size()]
	var symbol_rect := Rect2(center - Vector2.ONE * symbol_size, Vector2.ONE * symbol_size * 2.0)
	draw_texture_rect(symbol_texture, symbol_rect, false)
