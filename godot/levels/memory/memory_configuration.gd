class_name MemoryConfiguration
extends Resource

@export_range(1, 4, 1) var rows := 3
@export_range(2, 6, 1) var columns := 4
@export var pair_ids: Array[StringName] = [
	&"cat",
	&"grapes",
	&"flower",
	&"bird",
	&"bread",
	&"tower",
]
@export var random_pair_pool: Array[StringName] = []
@export var select_pairs_randomly := false
@export var shuffle_seed := 0
@export var card_size := Vector2(260.0, 210.0)
@export_range(0.0, 80.0, 1.0) var card_separation := 28.0
@export var board_center_offset := Vector2.ZERO


func is_valid() -> bool:
	if (rows * columns) % 2 != 0:
		return false
	if card_size.x < 160.0 or card_size.y < 140.0 or card_separation < 0.0:
		return false
	var configured_ids := random_pair_pool if select_pairs_randomly else pair_ids
	if configured_ids.is_empty() or configured_ids.has(&""):
		return false
	if configured_ids.size() != _unique_ids(configured_ids).size():
		return false
	if select_pairs_randomly:
		if configured_ids.size() < pair_count():
			return false
	elif configured_ids.size() != pair_count():
		return false
	for pair_id in configured_ids:
		if MemoryCard.symbol_index_for(pair_id) < 0:
			return false
	return true


func pair_count() -> int:
	return (rows * columns) / 2


func select_pair_ids(random: RandomNumberGenerator) -> Array[StringName]:
	var selected_ids := pair_ids.duplicate()
	if select_pairs_randomly:
		selected_ids = random_pair_pool.duplicate()
		_shuffle(selected_ids, random)
		selected_ids.resize(pair_count())
	return selected_ids


func _unique_ids(ids: Array[StringName]) -> Array[StringName]:
	var unique_ids: Array[StringName] = []
	for pair_id in ids:
		if not unique_ids.has(pair_id):
			unique_ids.append(pair_id)
	return unique_ids


func _shuffle(ids: Array[StringName], random: RandomNumberGenerator) -> void:
	for index in range(ids.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var swap_value := ids[index]
		ids[index] = ids[swap_index]
		ids[swap_index] = swap_value
