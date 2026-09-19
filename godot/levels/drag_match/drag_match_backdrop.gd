extends Control

var completion_emphasis := 0.0:
	set(value):
		completion_emphasis = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func play_completion_reaction() -> void:
	var reaction := create_tween()
	reaction.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reaction.tween_property(self, "completion_emphasis", 1.0, 0.22)
	reaction.tween_property(self, "completion_emphasis", 0.25, 0.28)


func _draw() -> void:
	if completion_emphasis > 0.0:
		draw_circle(size * Vector2(0.5, 0.47), 360.0 + completion_emphasis * 45.0, Color(1.0, 0.9, 0.45, completion_emphasis * 0.38))
