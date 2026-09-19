class_name MemoryBoard
extends Control

signal board_completed
signal card_flipped
signal feedback_requested(sound_id: StringName)
signal resolution_finished(was_match: bool)

const CARD_SCENE := preload("res://levels/memory/memory_card.tscn")
@export var configuration: MemoryConfiguration
@export_range(0.0, 2.0, 0.05) var mismatch_pause_seconds := 0.6
@export_range(0.0, 1.0, 0.05) var match_pause_seconds := 0.12

@onready var card_grid: GridContainer = %CardGrid

var cards: Array[MemoryCard] = []
var _first_card: MemoryCard
var _resolving := false
var _matched_pair_count := 0
var _completion_emitted := false


func _ready() -> void:
	resized.connect(_center_card_grid)
	if configuration != null:
		start_stage(configuration)


func get_cards() -> Array[MemoryCard]:
	return cards.duplicate()


func is_resolving() -> bool:
	return _resolving


func matched_pair_count() -> int:
	return _matched_pair_count


func pair_count() -> int:
	if configuration == null:
		return 0
	return configuration.pair_count()


func start_stage(stage_configuration: MemoryConfiguration) -> bool:
	if stage_configuration == null or not stage_configuration.is_valid():
		push_error("Memory board has an invalid configuration.")
		return false
	configuration = stage_configuration
	for card in cards:
		card.queue_free()
	cards.clear()
	_first_card = null
	_resolving = false
	_matched_pair_count = 0
	_completion_emitted = false
	_build_cards()
	call_deferred("_center_card_grid")
	return true


func play_completion_reaction() -> void:
	for index in cards.size():
		var card := cards[index]
		var delay := float(index % configuration.columns) * 0.035
		var tween := card.create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_interval(delay)
		tween.tween_property(card, "position:y", card.position.y - 14.0, 0.12)
		tween.tween_property(card, "position:y", card.position.y, 0.16)


func _build_cards() -> void:
	var random := _create_random()
	var shuffled_pairs := configuration.select_pair_ids(random)
	for pair_id in shuffled_pairs.duplicate():
		shuffled_pairs.append(pair_id)
	_shuffle_pairs(shuffled_pairs, random)
	card_grid.columns = configuration.columns
	card_grid.add_theme_constant_override("h_separation", roundi(configuration.card_separation))
	card_grid.add_theme_constant_override("v_separation", roundi(configuration.card_separation))

	for pair_id in shuffled_pairs:
		var card := CARD_SCENE.instantiate() as MemoryCard
		card.custom_minimum_size = configuration.card_size
		var symbol_index := MemoryCard.symbol_index_for(pair_id)
		card.configure(pair_id, symbol_index)
		card.flip_touched.connect(_on_card_touched)
		card.flip_requested.connect(_on_card_flip_requested)
		card_grid.add_child(card)
		cards.append(card)


func _center_card_grid() -> void:
	if configuration == null:
		return
	var grid_size := Vector2(
		configuration.card_size.x * configuration.columns + configuration.card_separation * (configuration.columns - 1),
		configuration.card_size.y * configuration.rows + configuration.card_separation * (configuration.rows - 1),
	)
	card_grid.size = grid_size
	card_grid.position = (size - grid_size) * 0.5 + configuration.board_center_offset


func _on_card_flip_requested(card: MemoryCard) -> void:
	if _resolving or card.is_matched:
		return
	card_flipped.emit()
	if _first_card == null:
		_first_card = card
		return
	if card == _first_card:
		return

	_resolving = true
	_set_card_input_enabled(false)
	_resolve_pair(_first_card, card)


func _on_card_touched(card: MemoryCard) -> void:
	if _resolving or card.is_matched or card.is_face_up:
		return
	if _first_card != null and card != _first_card:
		if card.pair_id == _first_card.pair_id:
			feedback_requested.emit(&"match")
		else:
			feedback_requested.emit(&"card_flip")
		return
	feedback_requested.emit(&"card_flip")


func _resolve_pair(first: MemoryCard, second: MemoryCard) -> void:
	var was_match := first.pair_id == second.pair_id
	if was_match:
		await get_tree().create_timer(match_pause_seconds).timeout
		var match_tween := first.play_match_feedback()
		second.play_match_feedback()
		await match_tween.finished
		_matched_pair_count += 1
	else:
		await get_tree().create_timer(mismatch_pause_seconds).timeout
		var mismatch_tween := first.play_mismatch_feedback()
		var second_mismatch_tween := second.play_mismatch_feedback()
		await mismatch_tween.finished
		if second_mismatch_tween.is_running():
			await second_mismatch_tween.finished

	_first_card = null
	_resolving = false
	if _matched_pair_count == pair_count():
		_emit_completion_once()
	else:
		_set_card_input_enabled(true)
	resolution_finished.emit(was_match)


func _set_card_input_enabled(enabled: bool) -> void:
	for card in cards:
		card.set_board_input_enabled(enabled)


func _emit_completion_once() -> void:
	if _completion_emitted:
		return
	_completion_emitted = true
	_set_card_input_enabled(false)
	board_completed.emit()


func _create_random() -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	if configuration.shuffle_seed == 0:
		random.randomize()
	else:
		random.seed = configuration.shuffle_seed
	return random


func _shuffle_pairs(pairs: Array[StringName], random: RandomNumberGenerator) -> void:
	for index in range(pairs.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var swap_value := pairs[index]
		pairs[index] = pairs[swap_index]
		pairs[swap_index] = swap_value
