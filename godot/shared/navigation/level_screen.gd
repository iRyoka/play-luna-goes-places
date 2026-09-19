class_name LevelScreen
extends Control

signal back_to_chapter_requested
signal sound_requested(sound_id: StringName)

@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(request_back_to_chapter)


func request_back_to_chapter() -> void:
	sound_requested.emit(&"tap")
	back_to_chapter_requested.emit()
