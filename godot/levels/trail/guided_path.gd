class_name GuidedPath
extends RefCounted

## Geometry shared by a drawn guided gesture. It intentionally knows nothing about
## actors, stages, checkpoints, or what a caller does when a gesture is released.

const TESSELLATION_SEGMENTS := 4
const TESSELLATION_TOLERANCE_DEGREES := 3.0
const SMOOTHING_TANGENT_SCALE := 0.25

var points := PackedVector2Array()
var smooth := true
var _polyline := PackedVector2Array()
var _distances := PackedFloat32Array()


func _init(authored_points := PackedVector2Array(), should_smooth := true) -> void:
	points = authored_points
	smooth = should_smooth


func get_length() -> float:
	_ensure_polyline()
	return _distances[_distances.size() - 1] if not _distances.is_empty() else 0.0


func get_polyline() -> PackedVector2Array:
	_ensure_polyline()
	return _polyline


func point_at_distance(distance: float) -> Vector2:
	_ensure_polyline()
	if _polyline.is_empty():
		return Vector2.ZERO
	var target := clampf(distance, 0.0, get_length())
	for index in range(1, _polyline.size()):
		if target > _distances[index]:
			continue
		var segment_length := _distances[index] - _distances[index - 1]
		if segment_length <= 0.0:
			return _polyline[index]
		return _polyline[index - 1].lerp(_polyline[index], (target - _distances[index - 1]) / segment_length)
	return _polyline[_polyline.size() - 1]


func tangent_at_distance(distance: float) -> Vector2:
	_ensure_polyline()
	if _polyline.size() < 2:
		return Vector2.RIGHT
	var target := clampf(distance, 0.0, get_length())
	for index in range(1, _polyline.size()):
		if target <= _distances[index]:
			var direction := _polyline[index] - _polyline[index - 1]
			if direction.length_squared() > 0.0:
				return direction.normalized()
	return (_polyline[_polyline.size() - 1] - _polyline[_polyline.size() - 2]).normalized()


func normal_at_distance(distance: float) -> Vector2:
	return tangent_at_distance(distance).orthogonal()


## A bounded search prevents a stray pointer from jumping across a folded path.
func project_distance(point: Vector2, search_center: float, search_radius: float) -> float:
	_ensure_polyline()
	if _polyline.size() < 2:
		return 0.0
	var window_start := clampf(search_center - search_radius, 0.0, get_length())
	var window_end := clampf(search_center + search_radius, 0.0, get_length())
	var best_distance := clampf(search_center, window_start, window_end)
	var best_squared := point.distance_squared_to(point_at_distance(best_distance))
	for index in range(1, _polyline.size()):
		if _distances[index] < window_start or _distances[index - 1] > window_end:
			continue
		var line := _polyline[index] - _polyline[index - 1]
		var line_length := line.length()
		if line_length <= 0.0:
			continue
		var along := (point - _polyline[index - 1]).dot(line) / (line_length * line_length)
		var candidate := clampf(_distances[index - 1] + clampf(along, 0.0, 1.0) * line_length, window_start, window_end)
		var candidate_squared := point.distance_squared_to(point_at_distance(candidate))
		if candidate_squared < best_squared:
			best_squared = candidate_squared
			best_distance = candidate
	return best_distance


func _ensure_polyline() -> void:
	if not _polyline.is_empty():
		return
	if points.size() < 2:
		_polyline = points.duplicate()
		_distances = PackedFloat32Array([0.0]) if points.size() == 1 else PackedFloat32Array()
		return
	_polyline = _build_smooth_polyline() if smooth else points.duplicate()
	_distances.resize(_polyline.size())
	for index in range(1, _polyline.size()):
		_distances[index] = _distances[index - 1] + _polyline[index - 1].distance_to(_polyline[index])


func _build_smooth_polyline() -> PackedVector2Array:
	var curve := Curve2D.new()
	for index in range(points.size()):
		var previous := points[maxi(index - 1, 0)]
		var next := points[mini(index + 1, points.size() - 1)]
		var tangent := (next - previous) * SMOOTHING_TANGENT_SCALE
		curve.add_point(points[index], -tangent, tangent)
	return curve.tessellate(TESSELLATION_SEGMENTS, TESSELLATION_TOLERANCE_DEGREES)
