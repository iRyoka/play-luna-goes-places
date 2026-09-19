class_name PictureTraceStage
extends Resource

enum CueMode {
	NEXT_DOT,
	NUMBERED_DOTS,
	DASHED_PATH,
}

@export var id: StringName
@export var points: PackedVector2Array
@export var cue_mode: CueMode = CueMode.NEXT_DOT
@export var focus_center := Vector2.ZERO
@export var close_outline_after_last_dot := false
@export var requires_origin_completion := false
@export var deferred_reveal_segments: Array[PackedVector2Array] = []


func is_valid() -> bool:
	if id.is_empty() or points.size() < 2 or points.size() > 15:
		return false
	var seen_points: Array[Vector2] = []
	for point: Vector2 in points:
		if seen_points.has(point):
			return false
		seen_points.append(point)
	return focus_center != Vector2.ZERO


func randomized_copy(random: RandomNumberGenerator) -> PictureTraceStage:
	var result := duplicate() as PictureTraceStage
	var randomized_points := points.duplicate()
	if requires_origin_completion or close_outline_after_last_dot:
		var start_index := random.randi_range(0, randomized_points.size() - 1)
		randomized_points = _rotated_points(randomized_points, start_index)
		if random.randi() % 2 == 1:
			randomized_points.reverse()
	elif random.randi() % 2 == 1:
		randomized_points.reverse()
	result.points = randomized_points
	return result


func _rotated_points(source: PackedVector2Array, start_index: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for offset: int in source.size():
		result.append(source[(start_index + offset) % source.size()])
	return result
