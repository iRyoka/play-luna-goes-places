class_name SfxPlayer
extends Node

const STREAMS: Dictionary[StringName, AudioStream] = {
	&"tap": preload("res://assets/audio/sfx/tap.wav"),
	&"grab": preload("res://assets/audio/sfx/grab.wav"),
	&"drop": preload("res://assets/audio/sfx/drop.wav"),
	&"wrong": preload("res://assets/audio/sfx/wrong.wav"),
	&"correct": preload("res://assets/audio/sfx/correct.wav"),
	&"card_flip": preload("res://assets/audio/sfx/card_flip.wav"),
	&"match": preload("res://assets/audio/sfx/match.wav"),
	&"level_complete": preload("res://assets/audio/sfx/level_complete.wav"),
	&"pop": preload("res://assets/audio/sfx/pop_tap_pop_01.wav"),
	&"pop_event": preload("res://assets/audio/sfx/pop_tap_pop_splash_01.wav"),
	&"bubbles": preload("res://assets/audio/sfx/pop_tap_bubbles_01.wav"),
}
# Random variant pools: each key maps to an array of streams to pick from.
const VARIANT_POOLS: Dictionary[StringName, Array] = {
	&"pop": [
		preload("res://assets/audio/sfx/pop_tap_pop_01.wav"),
		preload("res://assets/audio/sfx/pop_tap_pop_02.wav"),
	],
	&"pop_event": [
		preload("res://assets/audio/sfx/pop_tap_pop_splash_01.wav"),
		preload("res://assets/audio/sfx/pop_tap_splash_small.wav"),
	],
}
const VOLUMES_DB: Dictionary[StringName, float] = {
	&"tap": -10.0,
	&"grab": -10.0,
	&"drop": -14.0,
	&"wrong": -8.0,
	&"correct": -24.0,
	&"card_flip": -16.0,
	&"match": -10.0,
	&"level_complete": -8.0,
	&"pop": -10.0,
	&"pop_event": -10.0,
	&"bubbles": -10.0,
}
const START_OFFSETS_SECONDS: Dictionary[StringName, float] = {
	&"tap": 0.020,
	&"grab": 0.022,
}

@onready var _players: Array[AudioStreamPlayer] = [%PlayerA, %PlayerB, %PlayerC]


func play_sound(sound_id: StringName) -> void:
	# Pick a random variant if available, otherwise use the primary stream
	var stream: AudioStream
	var pool: Array = VARIANT_POOLS.get(sound_id, [])
	if pool.size() > 0:
		stream = pool[randi() % pool.size()]
	else:
		stream = STREAMS.get(sound_id)
	if stream == null:
		push_warning("Unknown SFX: %s" % sound_id)
		return

	# Restart an identical active cue so rapid taps produce a fresh attack instead
	# of two matching tails masking each other.
	for player: AudioStreamPlayer in _players:
		if player.playing and player.stream == stream:
			_play_on(player, sound_id, stream)
			return

	for player: AudioStreamPlayer in _players:
		if player.playing:
			continue
		_play_on(player, sound_id, stream)
		return


func _play_on(player: AudioStreamPlayer, sound_id: StringName, stream: AudioStream) -> void:
	player.stream = stream
	player.volume_db = VOLUMES_DB.get(sound_id, -12.0)
	player.play(START_OFFSETS_SECONDS.get(sound_id, 0.0))


func get_estimated_output_delay_seconds() -> float:
	return clampf(
		float(AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()),
		0.0,
		0.25
	)


func get_playing_count() -> int:
	var count := 0
	for player: AudioStreamPlayer in _players:
		if player.playing:
			count += 1
	return count
