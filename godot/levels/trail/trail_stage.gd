class_name TrailStage
extends Resource

## One place in a trail level: a background, the actor that travels it, the rule
## the corridor applies, and the ordered segments of its route. Play inside a
## stage is homogeneous — the same actor crosses the same scenery and only the
## track changes, each segment continuing where the last one ended.
##
## A second place is a second stage resource plus its artwork rather than new
## mechanic code. Missing artwork is never an error: a stage with no textures
## draws the plain placeholder route, so a route can be authored and tested
## before its pictures exist.

const CHAIN_TOLERANCE := 2.0
const DEFAULT_CORRIDOR_COLOR := Color(0.97, 0.94, 0.80)
const DEFAULT_CORRIDOR_EDGE_COLOR := Color(0.69, 0.78, 0.56)
const DEFAULT_TRAVELLED_COLOR := Color(0.99, 0.87, 0.55)
const DEFAULT_COMPLETED_CORRIDOR_COLOR := Color(0.88, 0.90, 0.78)

@export_group("Route")
## The legs of this stage's journey, travelled in order. Each one starts where
## the previous one ended, and each start is a checkpoint.
@export var segments: Array[TrailSegment] = []
## What this stage's corridor does when the actor is dragged out of it. Every
## segment inherits this unless it overrides it, which is what keeps one stage
## feeling like one rule. It must not be left on INHERIT.
@export var containment: TrailSegment.Containment = TrailSegment.Containment.CONTAINED
## Internal checkpoints remain part of one held drag. Generated Ant uses this;
## authored places keep their existing pause-and-release behaviour.
@export var continuous_checkpoints := false

## Runtime-only shared panorama; authored stages leave this empty.
var ant_journey: AntJourney
var view_origin := 0.0

@export_group("Actor")
## The travelling actor's frames, cycled in order while the level is playable. One
## frame is a still actor; several make it alive, which matters most for an actor
## that does not turn, since otherwise nothing about it moves as it travels. When
## empty the placeholder actor is drawn.
@export var actor_frames: Array[Texture2D] = []
## Seconds each frame is held.
@export var actor_frame_seconds := 0.09
## Half the actor's collision width. A contained actor stops when this reaches
## the corridor wall, so a wider actor has less room to weave. It belongs to the
## stage because an ant and a bee are not the same size.
@export var actor_radius := 52.0
## Half the actor's drawn width. Zero means "the same as actor_radius"; set it
## only when the artwork should read larger or smaller than the space the actor
## actually occupies.
@export var actor_draw_radius := 0.0
## Whether the actor turns to face the direction it is actually moving, easing
## round rather than snapping, and settling along its route when it comes to rest.
## True suits an actor that walks; false suits one that hovers and should stay
## upright, and is the only right answer for artwork drawn symmetrically.
@export var actor_turns_to_travel := true
## How long the actor's facing takes to swing most of the way to a new heading.
## Smaller turns sharper. It is the momentum in the turn: without it the actor
## snaps between headings on every pointer update.
@export var actor_turn_seconds := 0.12
## Which way this actor's artwork already points, in degrees clockwise from the
## right. Zero for art drawn facing right; 90 for art drawn facing down the
## screen. It is a fact about the picture, so it is declared rather than baked
## into the export, and a turning stage would otherwise face its actor sideways
## for the whole journey.
@export_range(-180.0, 180.0) var actor_art_facing_degrees := 0.0

@export_group("Presentation")
## Scenery behind the route, drawn to fill the board. When empty the course's
## placeholder colour is used instead.
@export var background: Texture2D
## Artwork at the very start of the stage's route.
@export var start_marker_texture: Texture2D
## Artwork at the end of every segment that does not name its own, so the inner
## checkpoints of a journey share one object and only its destination differs.
@export var checkpoint_marker_texture: Texture2D
## Whether the corridor itself is drawn. Turn it off for a stage whose route is
## painted into its background, which then has to be painted at exactly the
## coordinates the segments author.
@export var draw_corridor_overlay := true
## The object every run of this stage is made of unless the run names its own.
## When empty the corridor is drawn as flat colour, which suits a route that is a
## surface — trodden ground — rather than a thing.
@export var default_corridor_texture: Texture2D
@export var corridor_color := DEFAULT_CORRIDOR_COLOR
@export var corridor_edge_color := DEFAULT_CORRIDOR_EDGE_COLOR
## The stretch already travelled, marked behind the actor so progress stays
## readable at a glance and after a pause.
@export var travelled_color := DEFAULT_TRAVELLED_COLOR
## Segments of this stage that are already finished. They stay visible but quiet.
@export var completed_corridor_color := DEFAULT_COMPLETED_CORRIDOR_COLOR


func get_segment_count() -> int:
	return segments.size()


func get_segment(index: int) -> TrailSegment:
	if index < 0 or index >= segments.size():
		return null
	return segments[index]


func get_start_point() -> Vector2:
	var first := get_segment(0)
	if first == null:
		return Vector2.ZERO
	return first.get_start_point()


func get_actor_draw_radius() -> float:
	return actor_draw_radius if actor_draw_radius > 0.0 else actor_radius


func get_actor_frame_count() -> int:
	return actor_frames.size()


func get_actor_frame(index: int) -> Texture2D:
	if actor_frames.is_empty():
		return null
	return actor_frames[index % actor_frames.size()]


## The rule that actually applies to one segment: its own override when it has
## one, and this stage's rule otherwise.
func resolve_containment(segment: TrailSegment) -> TrailSegment.Containment:
	if segment == null or segment.containment == TrailSegment.Containment.INHERIT:
		return containment
	return segment.containment


## The object a run's corridor is drawn from: its own when it names one, this
## stage's default otherwise, and null when the corridor is flat colour.
func get_corridor_texture(segment: TrailSegment) -> Texture2D:
	if segment != null and segment.corridor_texture != null:
		return segment.corridor_texture
	return default_corridor_texture


## The marker drawn at a segment's end: its own when it names one, this stage's
## shared checkpoint marker otherwise.
func get_end_marker_texture(segment: TrailSegment) -> Texture2D:
	if segment != null and segment.end_marker_texture != null:
		return segment.end_marker_texture
	return checkpoint_marker_texture


## Authoring errors that make this stage unplayable. Artwork is deliberately not
## checked: a stage without pictures is a stage that has not been painted yet.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if containment == TrailSegment.Containment.INHERIT:
		errors.append("A stage must choose a containment rule for its segments to inherit.")
	if actor_radius <= 0.0:
		errors.append("A stage needs a positive actor radius.")
	if actor_frames.size() > 1 and actor_frame_seconds <= 0.0:
		errors.append("An animated actor needs a positive frame duration.")
	if actor_turns_to_travel and actor_turn_seconds <= 0.0:
		errors.append("A turning actor needs a positive turn duration.")
	if segments.is_empty():
		errors.append("A stage needs at least one segment.")
		return errors
	for index in range(segments.size()):
		var segment := segments[index]
		if segment == null:
			errors.append("Segment %d is missing." % index)
			continue
		if segment.points.size() < 2:
			errors.append("Segment %d needs at least two authored points." % index)
		if segment.path_width <= 0.0:
			errors.append("Segment %d needs a positive path width." % index)
		if segment.get_length() <= 0.0:
			errors.append("Segment %d has no travellable length." % index)
		if segment.path_width <= actor_radius * 2.0:
			errors.append("Segment %d is narrower than its actor." % index)
		if get_corridor_texture(segment) != null and segment.smooth:
			# A tessellated curve would shred the object into slivers, so a run
			# made of a thing is a straight run.
			errors.append("Segment %d draws a corridor object, so it cannot be smoothed." % index)
		if index == 0:
			continue
		var previous := segments[index - 1]
		if previous == null:
			continue
		if previous.get_end_point().distance_to(segment.get_start_point()) > CHAIN_TOLERANCE:
			errors.append("Segment %d does not start where segment %d ended." % [index, index - 1])
	return errors
