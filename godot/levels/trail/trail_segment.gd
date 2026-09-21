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
## Optional per-sample widths for a phrase derived from its painted support.
## Empty preserves the authored constant-width corridor used by older courses.
@export var width_samples := PackedFloat32Array()
## A phrase is painted as one compact source image rather than shredding it into
## straight span textures. Only its first split segment draws this surface.
@export var phrase_texture: Texture2D
@export var phrase_position := Vector2.ZERO
@export var phrase_scale := 1.0
@export var phrase_mirrored := false
@export var smooth := true:
	set(value):
		smooth = value
		_invalidate()

var _guided_path: GuidedPath
var global_start_distance := 0.0


func get_polyline() -> PackedVector2Array:
	return _path().get_polyline()


func get_length() -> float:
	return _path().get_length()


func get_start_point() -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	return points[0]


func get_end_point() -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	return points[points.size() - 1]


func point_at_distance(distance: float) -> Vector2:
	return _path().point_at_distance(distance)


func get_width_at_distance(distance: float) -> float:
	# Width samples belong to the finished polyline, never to sparse controls
	# that smoothing expands into a differently sized array.
	var polyline := get_polyline()
	if width_samples.size() != polyline.size() or width_samples.is_empty():
		return path_width
	distance = clampf(distance, 0.0, get_length())
	var covered := 0.0
	for index in range(1, polyline.size()):
		var span := polyline[index - 1].distance_to(polyline[index])
		if span > 0.0 and covered + span >= distance:
			var fraction := inverse_lerp(covered, covered + span, distance)
			return lerpf(width_samples[index - 1], width_samples[index], fraction)
		covered += span
	return width_samples[width_samples.size() - 1]


func get_half_width_at_distance(distance: float) -> float:
	return get_width_at_distance(distance) * 0.5


## Preserve the constant-width API used by authored Bee courses and tests.
func get_half_width() -> float:
	return path_width * 0.5


## Direction of travel at `distance`, used to resolve how far the actor sits to
## the side of the centre-line.
func tangent_at_distance(distance: float) -> Vector2:
	return _path().tangent_at_distance(distance)


func normal_at_distance(distance: float) -> Vector2:
	return tangent_at_distance(distance).orthogonal()


## Nearest travelled distance to `point`, searched only within `search_radius` of
## `search_center`. The window keeps a stray finger from teleporting the actor
## across a fold of its own route.
func project_distance(point: Vector2, search_center: float, search_radius: float) -> float:
	return _path().project_distance(point, search_center, search_radius)


func _invalidate() -> void:
	_guided_path = null


func _path() -> GuidedPath:
	if _guided_path == null:
		_guided_path = GuidedPath.new(points, smooth)
	return _guided_path
