extends Control

func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	# A warm veil keeps the completed scene present without competing with Luna.
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2b2039", 0.84))
