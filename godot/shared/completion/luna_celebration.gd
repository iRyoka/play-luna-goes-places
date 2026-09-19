extends Control

var _celebration_tween: Tween


func _ready() -> void:
	resized.connect(_update_pivot)
	_update_pivot()


func play_celebration() -> void:
	if _celebration_tween != null:
		_celebration_tween.kill()
	var grounded_y := position.y
	pivot_offset = Vector2(size.x * 0.5, size.y)
	rotation = 0.0
	scale = Vector2(0.82, 0.82)
	position.y = grounded_y + 70.0
	_celebration_tween = create_tween()
	_celebration_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_celebration_tween.tween_property(self, "position:y", grounded_y - 26.0, 0.23)
	_celebration_tween.parallel().tween_property(self, "scale", Vector2(1.08, 0.94), 0.23)
	_celebration_tween.tween_property(self, "position:y", grounded_y, 0.25)
	_celebration_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.25)


func _update_pivot() -> void:
	pivot_offset = Vector2(size.x * 0.5, size.y)
