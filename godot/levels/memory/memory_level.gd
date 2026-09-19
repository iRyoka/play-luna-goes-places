extends LevelController

@export var configuration: MemoryLevelConfiguration

@onready var memory_board: MemoryBoard = %MemoryBoard
@onready var stage_indicator: MemoryStageIndicator = %StageIndicator

var _current_stage_index := 0


func _ready() -> void:
	super._ready()
	memory_board.board_completed.connect(_on_board_completed)
	memory_board.feedback_requested.connect(request_sound_effect)
	completion_started.connect(memory_board.play_completion_reaction)
	if configuration == null or not configuration.is_valid():
		push_error("Memory level has an invalid configuration.")
		return
	memory_board.start_stage(configuration.stages[_current_stage_index])
	stage_indicator.stage_count = get_stage_count()


func get_stage_count() -> int:
	return 0 if configuration == null else configuration.stages.size()


func current_stage_number() -> int:
	return _current_stage_index + 1


func _on_board_completed() -> void:
	stage_indicator.completed_stage_count = current_stage_number()
	if _current_stage_index + 1 == get_stage_count():
		complete_level()
		return
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree() or is_level_complete():
		return
	_current_stage_index += 1
	memory_board.start_stage(configuration.stages[_current_stage_index])
