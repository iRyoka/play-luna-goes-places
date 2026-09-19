class_name PictureCreationLevel
extends LevelController

@onready var picture_board: PictureCreationBoard = %PictureBoard


func _ready() -> void:
	super._ready()
	picture_board.dot_connected.connect(func() -> void: request_sound_effect(&"tap"))
	picture_board.coloring_completed.connect(_on_coloring_completed)
	completion_started.connect(_on_completion_started)
	if get_tree().current_scene == self:
		replay_requested.connect(_restart_preview)


func _on_coloring_completed() -> void:
	var reveal := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal.tween_property(picture_board, "scale", Vector2.ONE * 1.04, 0.2)
	reveal.tween_property(picture_board, "scale", Vector2.ONE, 0.26)
	await reveal.finished
	await get_tree().create_timer(2.0).timeout
	complete_level()


func _on_completion_started() -> void:
	picture_board.set_process_unhandled_input(false)


func _restart_preview() -> void:
	get_tree().reload_current_scene()
