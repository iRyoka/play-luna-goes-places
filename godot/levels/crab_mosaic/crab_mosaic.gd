class_name CrabMosaicLevel
extends LevelController

const CELEBRATION_SETTLE_DURATION := 0.1

@onready var crab_mosaic_board: CrabMosaicBoard = %CrabMosaicBoard

var _completion_request_count := 0


func _ready() -> void:
	super._ready()
	completion_started.connect(_on_completion_started)
	crab_mosaic_board.sound_requested.connect(request_sound_effect)
	crab_mosaic_board.mosaic_completed.connect(_on_mosaic_completed)
	crab_mosaic_board.start_run_with_seed(randi())
	if get_tree().current_scene == self:
		replay_requested.connect(_restart_preview)


func _on_mosaic_completed() -> void:
	_completion_request_count += 1
	await get_tree().create_timer(CELEBRATION_SETTLE_DURATION).timeout
	complete_level()


func _on_completion_started() -> void:
	crab_mosaic_board.set_input_enabled(false)


func _restart_preview() -> void:
	get_tree().reload_current_scene()


func get_completion_request_count() -> int:
	return _completion_request_count
