extends Control

const INCOMPLETE_MARKER: Texture2D = preload("res://assets/gameplay/numbers/round-incomplete.png")
const COMPLETE_MARKER: Texture2D = preload("res://assets/gameplay/numbers/round-complete.png")

var completion_emphasis := 0.0:
	set(value):
		completion_emphasis = value
		queue_redraw()

var completed_rounds := 0:
	set(value):
		completed_rounds = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func play_completion_reaction() -> void:
	var reaction := create_tween()
	reaction.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reaction.tween_property(self, "completion_emphasis", 1.0, 0.22)
	reaction.tween_property(self, "completion_emphasis", 0.28, 0.30)


func _draw() -> void:
	_draw_round_markers()
	if completion_emphasis > 0.0:
		var center := size * Vector2(0.5, 0.47)
		draw_circle(center, 360.0 + completion_emphasis * 35.0, Color(1.0, 0.88, 0.45, completion_emphasis * 0.28))


func _draw_round_markers() -> void:
	var center_x := size.x * 0.5
	for index in 3:
		var marker_center := Vector2(center_x + (float(index) - 1.0) * 76.0, size.y - 70.0)
		var marker_texture := COMPLETE_MARKER if index < completed_rounds else INCOMPLETE_MARKER
		var marker_rect := Rect2(marker_center - Vector2(29.0, 29.0), Vector2(58.0, 58.0))
		draw_texture_rect(marker_texture, marker_rect, false)
