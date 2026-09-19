extends Control

@export_enum("Drag and match", "Memory", "Numbers") var mechanic := 0
@export var background_color := Color("#6f9e8a")
@export var accent_color := Color("#f2c36b")

var completion_emphasis := 0.0:
	set(value):
		completion_emphasis = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	var center := size * Vector2(0.5, 0.48)
	if completion_emphasis > 0.0:
		draw_circle(center, 285.0 + completion_emphasis * 24.0, Color(1.0, 0.90, 0.48, completion_emphasis * 0.55))
	draw_circle(center + Vector2(12.0, 18.0), 245.0, Color(0.15, 0.18, 0.20, 0.18))
	draw_circle(center, 235.0, Color("#f7e8c8"))
	match mechanic:
		0:
			_draw_drag_match_icon(center)
		1:
			_draw_memory_icon(center)
		2:
			_draw_numbers_icon(center)


func play_completion_reaction() -> void:
	var reaction := create_tween()
	reaction.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reaction.tween_property(self, "completion_emphasis", 1.0, 0.22)
	reaction.tween_property(self, "completion_emphasis", 0.25, 0.28)


func _draw_drag_match_icon(center: Vector2) -> void:
	draw_circle(center + Vector2(-82.0, 0.0), 64.0, accent_color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(28.0, -62.0),
		center + Vector2(152.0, 0.0),
		center + Vector2(28.0, 62.0),
	]), Color("#8a6ca8"))
	draw_line(center + Vector2(-5.0, 0.0), center + Vector2(25.0, 0.0), Color("#5b6670"), 18.0, true)


func _draw_memory_icon(center: Vector2) -> void:
	for x_offset in [-105.0, 25.0]:
		var card_rect := Rect2(center + Vector2(x_offset, -92.0), Vector2(80.0, 184.0))
		draw_rect(card_rect, accent_color)
		draw_circle(card_rect.get_center(), 28.0, Color("#ef796a"))


func _draw_numbers_icon(center: Vector2) -> void:
	for index in 3:
		var token_center := center + Vector2(-105.0 + index * 105.0, 0.0)
		draw_circle(token_center, 55.0, accent_color)
		draw_string(ThemeDB.fallback_font, token_center + Vector2(-18.0, 18.0), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color("#405065"))
