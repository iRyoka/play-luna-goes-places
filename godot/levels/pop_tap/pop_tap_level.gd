class_name PopTapLevel
extends LevelController

const KING_DUCK_BOUNCE_DURATION := 2.0

@onready var pop_tap_board: PopTapBoard = %PopTapBoard

var _completion_request_count := 0


func _ready() -> void:
	super._ready()
	completion_started.connect(_on_completion_started)
	if get_tree().current_scene == self:
		replay_requested.connect(_restart_preview)
	pop_tap_board.sound_requested.connect(request_sound_effect)
	pop_tap_board.quota_completed.connect(_on_quota_completed)


func get_completion_request_count() -> int:
	return _completion_request_count


func _on_quota_completed() -> void:
	_completion_request_count += 1
	# Wait for king duck bounce, then complete
	await get_tree().create_timer(KING_DUCK_BOUNCE_DURATION).timeout
	complete_level()


func _on_completion_started() -> void:
	pop_tap_board.set_input_enabled(false)


func _restart_preview() -> void:
	get_tree().reload_current_scene()