class_name ProceduralJigsawLevel
extends LevelController

@onready var board: ProceduralJigsawBoard = %Board


func _ready() -> void:
	super._ready()
	board.completed.connect(_on_board_completed)
	completion_started.connect(func() -> void: board.set_process_unhandled_input(false))
	if get_tree().current_scene == self:
		replay_requested.connect(func() -> void: get_tree().reload_current_scene())


func _on_board_completed() -> void:
	board.set_process_unhandled_input(false)
	await get_tree().create_timer(0.65).timeout
	if is_inside_tree():
		complete_level()
