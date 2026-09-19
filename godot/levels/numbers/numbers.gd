class_name NumbersLevel
extends LevelController

const ROUNDS := [
	{"planter_counts": [1, 2, 3, 4], "missing_index": 3, "choices": [4, 2, 1]},
	{"planter_counts": [3, 4, 5, 6], "missing_index": 2, "choices": [5, 3, 6]},
	{"planter_counts": [7, 8, 9, 10], "missing_index": 0, "choices": [7, 9, 10]},
]

@onready var placeholder_art: Control = %PlaceholderArt
@onready var sequence_planters: Array[PlanterSlot] = [%Planter0, %Planter1, %Planter2, %Planter3]
@onready var answer_candidates: Array[PlanterCandidate] = [%Candidate0, %Candidate1, %Candidate2]

var current_round_index := 0
var completed_round_count := 0
var _accepting_input := false
var _missing_planter: PlanterSlot
var _attention_tween: Tween
var _drag_preview: PlanterCandidate
var _dragged_candidate: PlanterCandidate
var _ignore_next_pressed_candidate: PlanterCandidate


func _ready() -> void:
	super._ready()
	for candidate: PlanterCandidate in answer_candidates:
		candidate.selection_touched.connect(_on_candidate_touched)
		candidate.pressed.connect(_on_candidate_pressed.bind(candidate))
		candidate.drag_started.connect(_on_candidate_drag_started)
		candidate.drag_moved.connect(_on_candidate_drag_moved)
		candidate.drag_released.connect(_on_candidate_drag_released)
	_load_round(0)


func get_round_count() -> int:
	return ROUNDS.size()


func get_answer_values() -> Array[int]:
	var values: Array[int] = []
	for candidate: PlanterCandidate in answer_candidates:
		values.append(candidate.flower_count)
	return values


func get_correct_answer() -> int:
	var round_data: Dictionary = ROUNDS[current_round_index]
	var counts: Array = round_data.planter_counts
	return int(counts[int(round_data.missing_index)])


func get_answer_tile(value: int) -> PlanterCandidate:
	for candidate: PlanterCandidate in answer_candidates:
		if candidate.flower_count == value:
			return candidate
	return null


func is_accepting_input() -> bool:
	return _accepting_input


func get_sequence_counts() -> Array[int]:
	var counts: Array[int] = []
	for planter: PlanterSlot in sequence_planters:
		counts.append(planter.flower_count)
	return counts


func _load_round(round_index: int) -> void:
	current_round_index = round_index
	var round_data: Dictionary = ROUNDS[current_round_index]
	var counts: Array = round_data.planter_counts
	var missing_index := int(round_data.missing_index)
	for index in sequence_planters.size():
		var planter := sequence_planters[index]
		planter.flower_count = 0 if index == missing_index else int(counts[index])
		planter.is_missing = index == missing_index
		if planter.is_missing:
			_missing_planter = planter

	for index in answer_candidates.size():
		var candidate := answer_candidates[index]
		candidate.reset_feedback()
		candidate.flower_count = int(round_data.choices[index])
		candidate.visible = true
		candidate.disabled = false

	_accepting_input = true
	_start_missing_planter_attention()


func _on_candidate_touched(_candidate: PlanterCandidate) -> void:
	if _accepting_input and not is_level_complete():
		request_sound_effect(&"tap")


func _on_candidate_pressed(candidate: PlanterCandidate) -> void:
	if candidate == _ignore_next_pressed_candidate:
		_ignore_next_pressed_candidate = null
		return
	if not _accepting_input or is_level_complete():
		return
	if candidate.flower_count != get_correct_answer():
		_play_wrong_feedback(candidate)
		return
	_resolve_correct_answer(candidate)


func _on_candidate_drag_started(candidate: PlanterCandidate) -> void:
	if not _accepting_input or is_level_complete():
		return
	_dragged_candidate = candidate
	_drag_preview = PlanterCandidate.new()
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.disabled = true
	_drag_preview.flower_count = candidate.flower_count
	_drag_preview.size = candidate.size
	_drag_preview.z_index = 8
	gameplay.add_child(_drag_preview)
	candidate.self_modulate = Color(1.0, 1.0, 1.0, 0.38)


func _on_candidate_drag_moved(candidate: PlanterCandidate, global_drag_position: Vector2) -> void:
	if candidate != _dragged_candidate or _drag_preview == null:
		return
	_drag_preview.global_position = global_drag_position - _drag_preview.size * 0.5


func _on_candidate_drag_released(candidate: PlanterCandidate, global_drop_position: Vector2) -> void:
	if candidate != _dragged_candidate:
		return
	_dragged_candidate = null
	_ignore_next_pressed_candidate = candidate
	if _drag_preview:
		_drag_preview.queue_free()
		_drag_preview = null
	candidate.self_modulate = Color.WHITE
	if not _accepting_input or is_level_complete():
		return
	if not _missing_planter.get_global_rect().grow(36.0).has_point(global_drop_position):
		candidate.play_wrong_feedback()
		return
	if candidate.flower_count != get_correct_answer():
		_play_wrong_feedback(candidate)
		return
	_resolve_correct_answer(candidate)


func _play_wrong_feedback(candidate: PlanterCandidate) -> void:
	request_sound_effect(&"wrong")
	candidate.play_wrong_feedback()


func _resolve_correct_answer(candidate: PlanterCandidate) -> void:
	_accepting_input = false
	_stop_missing_planter_attention()
	for answer_candidate: PlanterCandidate in answer_candidates:
		answer_candidate.disabled = true
	request_sound_effect(&"correct")

	var flying_planter := PlanterCandidate.new()
	flying_planter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flying_planter.disabled = true
	flying_planter.flower_count = candidate.flower_count
	flying_planter.size = candidate.size
	flying_planter.global_position = candidate.global_position
	flying_planter.z_index = 7
	gameplay.add_child(flying_planter)
	candidate.visible = false
	var target_position := _missing_planter.global_position + (_missing_planter.size - flying_planter.size) * 0.5

	var flight := create_tween().set_parallel(true)
	flight.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	flight.tween_property(flying_planter, "global_position", target_position, 0.42)
	flight.tween_property(flying_planter, "scale", _missing_planter.size / flying_planter.size, 0.42)
	await flight.finished
	if not is_inside_tree():
		return

	_missing_planter.flower_count = candidate.flower_count
	_missing_planter.is_missing = false
	flying_planter.queue_free()
	completed_round_count += 1
	placeholder_art.set("completed_rounds", completed_round_count)

	var resolved_bounce := create_tween()
	_missing_planter.pivot_offset = _missing_planter.size * 0.5
	resolved_bounce.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	resolved_bounce.tween_property(_missing_planter, "scale", Vector2(1.10, 1.10), 0.16)
	resolved_bounce.tween_property(_missing_planter, "scale", Vector2.ONE, 0.20)
	await get_tree().create_timer(0.48).timeout
	if not is_inside_tree():
		return

	if completed_round_count == ROUNDS.size():
		complete_level()
	else:
		_load_round(current_round_index + 1)


func _start_missing_planter_attention() -> void:
	_stop_missing_planter_attention()
	_missing_planter.pivot_offset = _missing_planter.size * 0.5
	_attention_tween = create_tween().set_loops()
	_attention_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_attention_tween.tween_property(_missing_planter, "scale", Vector2(1.035, 1.035), 0.55)
	_attention_tween.tween_property(_missing_planter, "scale", Vector2.ONE, 0.55)


func _stop_missing_planter_attention() -> void:
	if _attention_tween and _attention_tween.is_valid():
		_attention_tween.kill()
	if _missing_planter:
		_missing_planter.scale = Vector2.ONE
