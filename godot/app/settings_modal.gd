class_name SettingsModal
extends Control

signal close_requested
signal sound_requested(sound_id: StringName)

@onready var close_button: Button = %CloseButton
@onready var music_button: SettingsToggle = %MusicButton
@onready var sound_effects_button: SettingsToggle = %SoundEffectsButton


func _ready() -> void:
	close_button.pressed.connect(close_requested.emit)
	music_button.pressed.connect(_toggle_music)
	sound_effects_button.pressed.connect(_toggle_sound_effects)
	_sync_from_state()


func _sync_from_state() -> void:
	var game_state := get_node("/root/GameState")
	music_button.set_enabled_state(bool(game_state.get("music_enabled")))
	sound_effects_button.set_enabled_state(bool(game_state.get("sound_effects_enabled")))


func _toggle_music() -> void:
	var game_state := get_node("/root/GameState")
	game_state.call("set_music_enabled", not music_button.enabled_state)
	music_button.set_enabled_state(bool(game_state.get("music_enabled")))
	sound_requested.emit(&"tap")


func _toggle_sound_effects() -> void:
	var game_state := get_node("/root/GameState")
	game_state.call("set_sound_effects_enabled", not sound_effects_button.enabled_state)
	sound_effects_button.set_enabled_state(bool(game_state.get("sound_effects_enabled")))
	sound_requested.emit(&"tap")
