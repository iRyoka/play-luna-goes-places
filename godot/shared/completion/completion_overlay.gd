class_name CompletionOverlay
extends Control

signal replay_requested
signal continue_requested

@export var success_audio: AudioStream

@onready var backdrop: Control = %Backdrop
@onready var luna: Control = %Luna
@onready var particles: CPUParticles2D = %Particles
@onready var replay_button: Button = %ReplayButton
@onready var continue_button: Button = %ContinueButton
@onready var success_player: AudioStreamPlayer = %SuccessPlayer


func _ready() -> void:
	resized.connect(_layout_effects)
	replay_button.pressed.connect(replay_requested.emit)
	continue_button.pressed.connect(continue_requested.emit)
	visible = false
	_layout_effects()


func lock_gameplay_input() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.modulate = Color(1.0, 1.0, 1.0, 0.0)
	luna.modulate = Color(1.0, 1.0, 1.0, 0.0)
	replay_button.visible = false
	continue_button.visible = false
	replay_button.disabled = true
	continue_button.disabled = true


func play_celebration() -> void:
	particles.restart()
	particles.emitting = true
	if success_audio != null:
		success_player.stream = success_audio
		success_player.play()

	var reveal := create_tween().set_parallel(true)
	reveal.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(backdrop, "modulate:a", 1.0, 0.35)
	reveal.tween_property(luna, "modulate:a", 1.0, 0.25)
	luna.call("play_celebration")
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree():
		return

	replay_button.visible = true
	continue_button.visible = true
	var controls := create_tween().set_parallel(true)
	controls.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	replay_button.scale = Vector2(0.6, 0.6)
	continue_button.scale = Vector2(0.6, 0.6)
	controls.tween_property(replay_button, "scale", Vector2.ONE, 0.25)
	controls.tween_property(continue_button, "scale", Vector2.ONE, 0.3)
	await controls.finished
	replay_button.disabled = false
	continue_button.disabled = false


func _layout_effects() -> void:
	particles.position = size * Vector2(0.5, 0.42)
