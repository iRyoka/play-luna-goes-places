class_name LevelController
extends LevelScreen

signal completion_started
signal replay_requested
signal continue_to_chapter_requested

@export var level_id: StringName

@onready var gameplay: Control = %Gameplay
@onready var completion_overlay: CompletionOverlay = %CompletionOverlay

var _is_complete := false
var _quiet_progress_recorded := false


func _ready() -> void:
	super._ready()
	completion_overlay.replay_requested.connect(_on_replay_requested)
	completion_overlay.continue_requested.connect(_on_continue_requested)


func complete_level() -> void:
	if _is_complete:
		return

	_is_complete = true
	back_button.disabled = true
	back_button.visible = false
	completion_overlay.lock_gameplay_input()
	# Start the flourish with completion, rather than after the visual handoff.
	sound_requested.emit(&"level_complete")
	completion_started.emit()
	get_node("/root/GameState").call("mark_level_completed", level_id)

	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	await completion_overlay.play_celebration()


## Records progression for a creative sandbox without invoking the normal
## completion overlay or locking its interaction surface.
func record_quiet_progress() -> bool:
	if _quiet_progress_recorded:
		return false
	_quiet_progress_recorded = true
	get_node("/root/GameState").call("mark_level_completed", level_id)
	return true


func is_quiet_progress_recorded() -> bool:
	return _quiet_progress_recorded


func request_sound_effect(sound_id: StringName) -> void:
	sound_requested.emit(sound_id)


func is_level_complete() -> bool:
	return _is_complete


func _on_replay_requested() -> void:
	sound_requested.emit(&"tap")
	replay_requested.emit()


func _on_continue_requested() -> void:
	continue_to_chapter_requested.emit()
