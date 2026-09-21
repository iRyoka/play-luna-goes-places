class_name FlyingCollectorLevel
extends LevelController

@onready var flying_collector_board: FlyingCollectorBoard = %FlyingCollectorBoard

var _completion_request_count := 0


func _ready() -> void:
	super._ready()
	completion_started.connect(_on_completion_started)
	flying_collector_board.landing_completed.connect(_on_landing_completed)
	flying_collector_board.sound_requested.connect(request_sound_effect)
	if get_tree().current_scene == self:
		replay_requested.connect(_restart_preview)


func _on_landing_completed() -> void:
	_completion_request_count += 1
	complete_level()


func _on_completion_started() -> void:
	flying_collector_board.set_input_enabled(false)


func _restart_preview() -> void:
	get_tree().reload_current_scene()


func get_completion_request_count() -> int:
	return _completion_request_count
