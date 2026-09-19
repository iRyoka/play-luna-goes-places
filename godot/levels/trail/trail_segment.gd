class_name TrailSegment
extends Resource

## One authored leg of a gentle route: a centre-line the actor travels along and
## the corridor width around it. Authored points stay sparse; a smooth segment is
## tessellated through them, so authoring a curve costs a few points rather than
## a dense polyline.
##
## Segments chain inside one stage, and a segment's start is a checkpoint: a
## restarting actor returns there rather than to the beginning of the level.

## What the corridor does when the actor is dragged out of it.
## CONTAINED keeps the actor inside the corridor walls, like a coin in a groove.
## RESTART_ON_EXIT lets the actor leave and flies it back to the start of the
## segment, so the segment asks the child to stay inside a corridor whose width
## is what makes it easy or demanding.
## INHERIT is only meaningful on a segment, which normally takes the rule its
## stage authored rather than choosing its own.
enum Containment { INHERIT, CONTAINED, RESTART_ON_EXIT }

const TESSELLATION_SEGMENTS := 4
const TESSELLATION_TOLERANCE_DEGREES := 3.0
const SMOOTHING_TANGENT_SCALE := 0.25

## Overrides the stage's containment for this leg alone. Leave it on INHERIT,
## which is what keeps play inside a stage homogeneous; set it only for a leg
## that genuinely needs a different rule from the rest of its stage.
@export var containment: Containment = Containment.INHERIT
## The object this run's corridor is made of — a straw, a plank, a branch. It is
## stretched to the run's length and its authored width, so the surface the child
## sees and the boundary the corridor enforces are the same number. When empty
## the stage's default object is used, and when that is empty too the corridor is
## drawn as flat colour.
@export var corridor_texture: Texture2D
## Artwork marking the end of this segment. When empty the stage's checkpoint
## marker is drawn instead, so only a segment ending somewhere special — the
## flower a journey is heading for — needs to name its own.
@export var end_marker_texture: Texture2D
## Drawn radius of that marker. It carries no interaction meaning; arriving is
## governed by the course's goal_reach.
@export var end_marker_radius := 44.0
@export var points := PackedVector2Array():
	set(value):
		points = value
		_invalidate()
@export var path_width := 220.0:
	set(value):
		path_width = value
		_invalidate()
@export var smooth := true:
	set(value):
		smooth = value
		_invalidate()

var _polyline := PackedVector2Array()
var _distances := PackedFloat32Array()


func get_polyline() -> PackedVector2Array:
	_ensure_polyline()
	return _polyline


func get_length() -> float:
	_ensure_polyline()
	if _distances.is_empty():
		return 0.0
	return _distances[_distances.size() - 1]


func get_start_point() -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	return points[0]


func get_end_point() -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	return points[points.size() - 1]


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
		var fraction := (target - _distances[index - 1]) / segment_length
		return _polyline[index - 1].lerp(_polyline[index], fraction)
	return _polyline[_polyline.size() - 1]


func get_half_width() -> float:
	return path_width * 0.5


## Direction of travel at `distance`, used to resolve how far the actor sits to
## the side of the centre-line.
func tangent_at_distance(distance: float) -> Vector2:
	_ensure_polyline()
	if _polyline.size() < 2:
		return Vector2.RIGHT
	var target := clampf(distance, 0.0, get_length())
	for index in range(1, _polyline.size()):
		if target > _distances[index]:
			continue
		var direction := _polyline[index] - _polyline[index - 1]
		if direction.length_squared() > 0.0:
			return direction.normalized()
	for index in range(_polyline.size() - 1, 0, -1):
		var direction := _polyline[index] - _polyline[index - 1]
		if direction.length_squared() > 0.0:
			return direction.normalized()
	return Vector2.RIGHT


func normal_at_distance(distance: float) -> Vector2:
	return tangent_at_distance(distance).orthogonal()


## Nearest travelled distance to `point`, searched only within `search_radius` of
## `search_center`. The window keeps a stray finger from teleporting the actor
## across a fold of its own route.
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
		var segment := _polyline[index] - _polyline[index - 1]
		var segment_length := segment.length()
		if segment_length <= 0.0:
			continue
		var along := (point - _polyline[index - 1]).dot(segment) / (segment_length * segment_length)
		var candidate := _distances[index - 1] + clampf(along, 0.0, 1.0) * segment_length
		candidate = clampf(candidate, window_start, window_end)
		var candidate_squared := point.distance_squared_to(point_at_distance(candidate))
		if candidate_squared < best_squared:
			best_squared = candidate_squared
			best_distance = candidate
	return best_distance


func _invalidate() -> void:
	_polyline = PackedVector2Array()
	_distances = PackedFloat32Array()


func _ensure_polyline() -> void:
	if not _polyline.is_empty():
		return
	if points.size() < 2:
		_polyline = points.duplicate()
		_distances = PackedFloat32Array()
		if _polyline.size() == 1:
			_distances.append(0.0)
		return
	_polyline = _build_smooth_polyline() if smooth else points.duplicate()
	_distances = PackedFloat32Array()
	_distances.resize(_polyline.size())
	_distances[0] = 0.0
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
