class_name SoupStage
extends CookingStage

## Recipe-local state. The board recognises the gestures and draws their results.
enum Step { WATER, CARROT_CUT, CARROT_TRANSFER, TOMATO_CUT, TOMATO_TRANSFER, STIR, PEPPER_GRIND, PEPPER_TRANSFER, SALT, HERBS, READY }

const READY_CELEBRATION_DELAY := 2.5
const ACTION_HOLD_SECONDS := 0.32

@onready var soup_board: SoupBoard = %SoupBoard
var _step := Step.WATER
var _finishing := false

func _ready() -> void:
	soup_board.action_completed.connect(_on_action_completed)
	soup_board.set_active_step(_step)

func begin() -> void:
	set_input_enabled(true)

func set_input_enabled(enabled: bool) -> void:
	soup_board.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func get_current_step() -> Step:
	return _step

func _on_action_completed(action: StringName) -> void:
	if _finishing or action != soup_board.action_for_step(_step):
		return
	_finishing = true
	sound_requested.emit(&"correct")
	await get_tree().create_timer(ACTION_HOLD_SECONDS).timeout
	if action != soup_board.action_for_step(_step):
		return
	_finishing = false
	_step += 1
	soup_board.set_active_step(_step)
	if _step == Step.READY:
		await get_tree().create_timer(READY_CELEBRATION_DELAY).timeout
		if _step == Step.READY:
			recipe_finished.emit()
