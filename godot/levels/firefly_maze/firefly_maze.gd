class_name FireflyMazeLevel
extends LevelController

const STAGE_ADVANCE_DELAY := 0.75
const FINAL_ARRIVAL_DELAY := 1.1

@onready var firefly_board: FireflyMazeBoard = %FireflyMazeBoard

var _completion_request_count := 0


func _ready() -> void:
	super._ready()
	firefly_board.stage_reached_house.connect(_on_stage_reached_house)
	completion_started.connect(_on_completion_started)
	if get_tree().current_scene == self:
		replay_requested.connect(_restart_preview)


func _on_stage_reached_house() -> void:
	var solved_stage := firefly_board.get_stage_index()
	await get_tree().create_timer(STAGE_ADVANCE_DELAY).timeout
	if not is_inside_tree() or is_level_complete() or firefly_board.get_stage_index() != solved_stage:
		return
	if firefly_board.has_next_stage():
		firefly_board.advance_stage()
		return
	_completion_request_count += 1
	await get_tree().create_timer(FINAL_ARRIVAL_DELAY - STAGE_ADVANCE_DELAY).timeout
	if is_inside_tree():
		complete_level()


func _on_completion_started() -> void:
	firefly_board.set_input_enabled(false)


func _restart_preview() -> void:
	get_tree().reload_current_scene()


func get_completion_request_count() -> int:
	return _completion_request_count
