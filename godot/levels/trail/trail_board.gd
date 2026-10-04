class_name TrailBoard
extends Control

## Owns the route geometry, the dragged actor, and the drawing of one stage.
##
## The actor is positioned as travelled distance along the authored centre-line
## plus a sideways offset from it, so it rides the corridor like a coin in a
## slightly wider groove rather than running on a rail. What happens at the wall
## is authored per stage and may be overridden per segment: a CONTAINED leg stops
## the actor there, while a RESTART_ON_EXIT leg lets it leave and flies it back
## to the segment's start, which is its checkpoint.
##
## Presentation comes from the stage. Every texture is optional: a stage with no
## artwork draws the placeholder route it had before it was painted.

signal actor_grabbed
signal segment_restarted
signal segment_completed(segment_index: int)
signal pointer_released
signal checkpoint_revisited(segment_index: int)

## Largest jump along the route one pointer update may cause.
const MAX_PROJECTION_STEP := 460.0
## Seconds the actor takes to glide onto its marker once it has arrived.
const ARRIVAL_GLIDE_SECONDS := 0.18
const CHECKPOINT_APPROACH_DISTANCE := 220.0
const CHECKPOINT_BOUNCE_SECONDS := 0.42
## A press is accepted well away from the actor, so the actor keeps that distance
## at first and then closes it, arriving under the finger without a jump.
const GRAB_OFFSET_DECAY := 0.82
const GRAB_OFFSET_EPSILON := 1.0
## Placeholder sizes, used only while a stage has no artwork.
const PLACEHOLDER_ACTOR_RADIUS := 52.0
const START_MARKER_RADIUS := 44.0
## Width of the quiet rim drawn outside the corridor fill.
const CORRIDOR_EDGE_WIDTH := 26.0
## How far a corridor object reaches past each end of its run, so the marker at a
## junction overlaps it instead of meeting it at a visible seam.
const CORRIDOR_OBJECT_OVERLAP := 12.0

## Movement below this in one frame is the actor standing still, not a heading.
const MIN_TURN_MOVEMENT := 1.5
const REFERENCE_SIZE := Vector2(2160.0, 1080.0)

const START_MARKER_COLOR := Color(0.75, 0.82, 0.63)
const GOAL_PETAL_COLOR := Color(0.93, 0.46, 0.56)
const GOAL_CENTER_COLOR := Color(0.99, 0.84, 0.40)
const ACTOR_COLOR := Color(0.99, 0.79, 0.28)
const ACTOR_STRIPE_COLOR := Color(0.29, 0.24, 0.19)
const ACTOR_WING_COLOR := Color(1.0, 1.0, 1.0, 0.55)
## Feedback shared by every stage, so it stays the same gesture wherever the
## child meets it.
const GRAB_RING_COLOR := Color(1.0, 1.0, 1.0, 0.28)
const GRAB_RING_SCALE := 1.15
const TETHER_COLOR := Color(0.42, 0.39, 0.33, 0.30)

var course: TrailCourse

var _stage_index := 0
var _segment_index := 0
var _distance := 0.0
var _lateral := 0.0
var _dragging := false
var _segment_resolved := false
var _off_route := false
var _exit_armed := false
var _pointer_position := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _settling := false
var _settle_from_distance := 0.0
var _settle_from_lateral := 0.0
var _settle_to_distance := 0.0
var _settle_to_lateral := 0.0
var _settle_duration := 0.0
var _settle_elapsed := 0.0
var _input_enabled := true
var _actor_frame := 0
var _frame_elapsed := 0.0
var _facing_angle := 0.0
var _last_actor_position := Vector2.ZERO
var _has_last_position := false
var _pointer_pressed := false
var _pan_origin := 0.0
var _pan_from := 0.0
var _pan_to := 0.0
var _pan_inertia := 0.0
var _glow_time := 0.0


func _ready() -> void:
	set_process(false)


func configure(trail_course: TrailCourse) -> void:
	course = trail_course
	set_active_stage(0)


## Moves to a new place. The actor changes with it, so unlike a segment handover
## this is a visible cut rather than a continuation.
func set_active_stage(index: int) -> void:
	_stage_index = index
	_pan_origin = _current_stage().view_origin
	set_active_segment(0)


func set_active_segment(index: int) -> void:
	_segment_index = index
	_distance = 0.0
	_lateral = 0.0
	_dragging = false
	_segment_resolved = false
	_off_route = false
	_exit_armed = false
	_settling = false
	_has_last_position = false
	# A new place or a new leg starts the actor lying along its route rather than
	# swinging round from wherever the last one left it pointing.
	var segment := _current_segment()
	if segment != null:
		_facing_angle = segment.tangent_at_distance(0.0).angle()
	_update_processing()
	queue_redraw()


## Advances across a visible internal checkpoint without taking the held drag
## away. The two runs share their endpoint, so the actor remains exactly where
## the child left it while the active recovery checkpoint changes.
func continue_through_checkpoint(index: int) -> void:
	_accept_checkpoint(_current_segment())
	_segment_index = index
	_distance = 0.0
	_lateral = 0.0
	_segment_resolved = false
	_off_route = false
	_exit_armed = true
	# Internal checkpoints have no arrival glide: their shared endpoint is already
	# under the actor, and a pending settle would overwrite the next leg's travel.
	_settling = false
	_has_last_position = false
	queue_redraw()


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	if not enabled:
		_dragging = false
		_off_route = false
		queue_redraw()
	# The actor stops animating with the level, so nothing keeps redrawing behind
	# the completion overlay.
	_update_processing()


func get_stage_index() -> int:
	return _stage_index


func get_segment_index() -> int:
	return _segment_index


func get_travelled_distance() -> float:
	return _distance


func get_lateral_offset() -> float:
	return _lateral


func get_actor_position() -> Vector2:
	var segment := _current_segment()
	if segment == null:
		return Vector2.ZERO
	var position := segment.point_at_distance(_distance) + segment.normal_at_distance(_distance) * _lateral
	var stage := _current_stage()
	if stage.ant_journey != null:
		position.x += stage.view_origin - _pan_origin + _pan_inertia
	return position


## True while the actor is outside its corridor, or while a contained actor is
## held at the wall by a pointer that has wandered well past it.
func is_off_route() -> bool:
	return _off_route


func is_actor_outside_corridor() -> bool:
	var segment := _current_segment()
	if segment == null:
		return false
	var stage := _current_stage()
	if stage.ant_journey != null:
		return not stage.ant_journey.is_walkable(get_actor_position()+Vector2(_pan_origin,0)-AntJourney.SCREEN_ORIGIN,false)
	return absf(_lateral) > segment.get_half_width_at_distance(_distance)


func is_dragging() -> bool:
	return _dragging


func is_settling() -> bool:
	return _settling


func _gui_input(event: InputEvent) -> void:
	# A handover locks movement, not the release needed to leave its rest point.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_action(_screen_to_reference(event.position))
		return
	if event is InputEventScreenTouch and not event.pressed and OS.has_feature("mobile"):
		_finish_action(_screen_to_reference(event.position))
		return
	if not _input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_action(_screen_to_reference(event.position))
		else:
			_finish_action(_screen_to_reference(event.position))
	elif event is InputEventMouseMotion:
		_update_action(_screen_to_reference(event.position))
	elif event is InputEventScreenTouch:
		if not OS.has_feature("mobile"):
			return
		if event.pressed:
			_begin_action(_screen_to_reference(event.position))
		else:
			_finish_action(_screen_to_reference(event.position))
	elif event is InputEventScreenDrag:
		if not OS.has_feature("mobile"):
			return
		_update_action(_screen_to_reference(event.position))


func _begin_action(position: Vector2) -> void:
	var segment := _current_segment()
	if segment == null or _segment_resolved or not _input_enabled:
		return
	var actor_position := get_actor_position()
	if position.distance_to(actor_position) > course.actor_capture_radius:
		return
	_pointer_pressed = true
	_dragging = true
	_settling = false
	_exit_armed = false
	_update_processing()
	# The actor stays exactly where it was pressed and closes the gap to the finger
	# over the next few updates, so a press taken at the edge of the capture radius
	# neither jerks the actor nor throws it out of a corridor.
	_grab_offset = actor_position - position
	_pointer_position = position
	_apply_target(segment, position + _grab_offset)
	actor_grabbed.emit()
	queue_redraw()


func _update_action(position: Vector2) -> void:
	if not _dragging:
		return
	var segment := _current_segment()
	if segment == null:
		return
	_pointer_position = position
	_grab_offset *= GRAB_OFFSET_DECAY
	if _grab_offset.length() < GRAB_OFFSET_EPSILON:
		_grab_offset = Vector2.ZERO
	_apply_target(segment, position + _grab_offset)
	queue_redraw()
	if not _dragging:
		# The segment restarted under this update.
		return
	segment = _current_segment()
	# Arriving is generous: an actor carried along the corridor wall reaches its
	# marker without being steered onto the last point of the centre-line.
	var reach := course.goal_reach
	if _current_stage().ant_journey != null and _segment_index < _current_stage().get_segment_count()-1:
		reach = 1.0
	if _distance >= segment.get_length() - reach and not is_actor_outside_corridor():
		_resolve_segment(segment)
		if _dragging and _current_stage().ant_journey != null and _current_segment() != segment:
			_apply_target(_current_segment(),position+_grab_offset)


func _finish_action(position: Vector2) -> void:
	_pointer_pressed = false
	pointer_released.emit()
	if not _dragging:
		return
	_update_action(position)
	if _segment_resolved:
		return
	_dragging = false
	queue_redraw()


func _process(delta: float) -> void:
	var busy := false
	if _current_stage() != null and _current_stage().ant_journey != null and _input_enabled:
		_glow_time += delta
		queue_redraw()
		busy = true
	if _settling:
		_advance_settle(delta)
		busy = true
	if _is_animating():
		_advance_actor_frame(delta)
		busy = true
	if _turns_actor():
		_advance_facing(delta)
		busy = true
	if not busy:
		set_process(false)


func _advance_settle(delta: float) -> void:
	_settle_elapsed += delta
	var fraction := clampf(_settle_elapsed / _settle_duration, 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, fraction)
	_distance = lerpf(_settle_from_distance, _settle_to_distance, eased)
	_lateral = lerpf(_settle_from_lateral, _settle_to_lateral, eased)
	if fraction >= 1.0:
		_distance = _settle_to_distance
		_lateral = _settle_to_lateral
		_settling = false
		_off_route = false
	queue_redraw()


## Redraws only when the frame actually changes, so an eleven-frame-a-second flap
## costs eleven redraws a second rather than one per rendered frame.
func _advance_actor_frame(delta: float) -> void:
	var stage := _current_stage()
	if stage == null:
		return
	_frame_elapsed += delta
	if _frame_elapsed < stage.actor_frame_seconds:
		return
	var advanced := int(_frame_elapsed / stage.actor_frame_seconds)
	_frame_elapsed -= advanced * stage.actor_frame_seconds
	_actor_frame += advanced
	queue_redraw()


func _is_animating() -> bool:
	if not _input_enabled:
		return false
	var stage := _current_stage()
	return stage != null and stage.get_actor_frame_count() > 1


func _turns_actor() -> bool:
	if not _input_enabled:
		return false
	var stage := _current_stage()
	return stage != null and stage.actor_turns_to_travel


## Swings the actor's facing toward the direction it is actually moving, which is
## not the same as the direction of its route: a finger dragged sideways or back
## along the route turns the actor that way, so leaving the corridor is something
## the child sees the actor do rather than something that merely happens to it.
##
## Coming to rest settles it along its route, so a waiting actor lies on its path
## instead of pointing wherever it was last pulled.
func _advance_facing(delta: float) -> void:
	var stage := _current_stage()
	var segment := _current_segment()
	if stage == null or segment == null:
		return
	var position := get_actor_position()
	var target := segment.tangent_at_distance(_distance)
	if _has_last_position:
		var moved := position - _last_actor_position
		if moved.length() > MIN_TURN_MOVEMENT:
			target = moved.normalized()
	_last_actor_position = position
	_has_last_position = true

	# Frame-rate independent easing toward the target heading, taking the shortest
	# way round so a heading that crosses behind the actor does not spin it.
	var weight := 1.0 - exp(-delta / maxf(stage.actor_turn_seconds, 0.001))
	var difference := wrapf(target.angle() - _facing_angle, -PI, PI)
	if absf(difference) < 0.001:
		return
	_facing_angle += difference * weight
	queue_redraw()


func _update_processing() -> void:
	var glowing := _input_enabled and _current_stage() != null and _current_stage().ant_journey != null
	set_process(_settling or _is_animating() or _turns_actor() or glowing)


func _current_stage() -> TrailStage:
	if course == null:
		return null
	return course.get_stage(_stage_index)


func _current_segment() -> TrailSegment:
	var stage := _current_stage()
	if stage == null:
		return null
	return stage.get_segment(_segment_index)


## Places the actor for one pointer position: how far along the route it now is,
## and how far to the side of the centre-line the corridor lets it sit.
func _apply_target(segment: TrailSegment, target: Vector2) -> void:
	var stage := _current_stage()
	if stage == null:
		return
	var actor_radius := stage.actor_radius
	var candidate := segment.project_distance(target, _distance, MAX_PROJECTION_STEP)
	if stage.ant_journey != null and _segment_index > 0 and candidate < 1.0:
		if (target-segment.get_start_point()).dot(segment.tangent_at_distance(0)) < -4:
			_segment_index -= 1
			segment = _current_segment()
			_distance = segment.get_length()
			candidate = segment.project_distance(target,_distance,MAX_PROJECTION_STEP)
			checkpoint_revisited.emit(_segment_index)
	var half_width := segment.get_half_width_at_distance(candidate)
	var lateral := _lateral_at(segment, candidate, target)
	if stage.resolve_containment(segment) == TrailSegment.Containment.RESTART_ON_EXIT:
		_distance = candidate
		_lateral = lateral
		# The same grace a contained corridor gets, applied where it matters more.
		# It sits outside the visible edge, so the actor is seen to leave the route
		# before it is sent back: the rule is never harsher than the picture.
		var outside := absf(_lateral) > half_width + course.off_route_tolerance
		if stage.ant_journey != null:
			var point := segment.point_at_distance(candidate)+segment.normal_at_distance(candidate)*lateral
			var offset := Vector2(stage.view_origin,0)-AntJourney.SCREEN_ORIGIN
			# A far-away pointer can project onto a bend with almost zero lateral
			# offset. Discarding its longitudinal residual would falsely advance it.
			outside = not stage.ant_journey.is_walkable(target+offset,true) or not stage.ant_journey.is_walkable(point+offset,true)
		# A press that begins outside the corridor must not restart the segment
		# before the actor has been inside it once.
		if outside and _exit_armed:
			_restart_segment()
			return
		_exit_armed = _exit_armed or not outside
		_off_route = outside
	else:
		_off_route = absf(lateral) > half_width + course.off_route_tolerance
		if _off_route:
			# The finger has left the groove, so the coin stays where it is and
			# waits rather than being carried forward from outside the corridor.
			# Nearest-point projection would otherwise let a finger well inside a
			# curve pull the actor around it.
			lateral = _lateral_at(segment, _distance, target)
		else:
			_distance = candidate
		# The actor stops with its own edge against the wall.
		var limit := maxf(half_width - actor_radius, 0.0)
		_lateral = clampf(lateral, -limit, limit)


func _lateral_at(segment: TrailSegment, distance: float, target: Vector2) -> float:
	var centre := segment.point_at_distance(distance)
	return (target - centre).dot(segment.normal_at_distance(distance))


func _resolve_segment(segment: TrailSegment) -> void:
	if _segment_resolved:
		return
	_segment_resolved = true
	if not _current_stage().continuous_checkpoints or _segment_index >= _current_stage().get_segment_count() - 1:
		_dragging = false
	_off_route = false
	# The actor glides the last of the way onto its marker, well inside the pause
	# before the next segment appears.
	_start_settle(segment.get_length(), 0.0, ARRIVAL_GLIDE_SECONDS)
	queue_redraw()
	segment_completed.emit(_segment_index)


## Checkpoint presentation is committed only when the board accepts the segment.
## Grace can keep an Ant moving near a straw edge, but it must not pre-visit a
## berry while the stricter support check still rejects the checkpoint.
func _accept_checkpoint(segment: TrailSegment) -> void:
	var stage := _current_stage()
	if stage == null or stage.ant_journey == null or segment == null:
		return
	var journey := stage.ant_journey
	journey.passed_distance = maxf(journey.passed_distance, segment.global_start_distance + segment.get_length())
	_record_checkpoint_passes(journey)


## Leaving a restarting corridor sends the actor back to this segment's start,
## which is the last checkpoint it passed. Nothing is scored or lost: the leg
## simply begins again, and the flight back is the feedback.
func _restart_segment() -> void:
	_dragging = false
	_off_route = false
	_exit_armed = false
	_start_settle(0.0, 0.0, course.restart_duration)
	queue_redraw()
	segment_restarted.emit()


func _start_settle(target_distance: float, target_lateral: float, duration: float) -> void:
	if is_equal_approx(_distance, target_distance) and is_equal_approx(_lateral, target_lateral):
		_off_route = false
		return
	_settling = true
	_settle_from_distance = _distance
	_settle_from_lateral = _lateral
	_settle_to_distance = target_distance
	_settle_to_lateral = target_lateral
	_settle_duration = maxf(duration, 0.01)
	_settle_elapsed = 0.0
	set_process(true)


func _draw() -> void:
	_set_reference_draw_transform(Vector2.ZERO)
	var stage := _current_stage()
	_draw_background(stage)
	if stage == null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if stage.ant_journey != null:
		_draw_ant_journey(stage)
		var ant_segment := _current_segment()
		if ant_segment != null:
			_draw_route_hint(ant_segment)
			_draw_actor(stage,ant_segment)
			if _segment_resolved and _stage_index < course.get_stage_count()-1:
				draw_arc(get_actor_position(),100,0,TAU,48,Color(1,1,1,0.3),5,true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if stage.draw_corridor_overlay:
		_draw_stage_corridor(stage)
	var segment := stage.get_segment(_segment_index)
	if segment == null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# Progress is marked whatever the route is drawn from, because it is feedback
	# rather than scenery. A stage that does not want it authors a transparent
	# travelled colour.
	_draw_travelled(stage, segment)
	for index in range(stage.get_segment_count()):
		if not _is_segment_marked(stage, index):
			continue
		var marked := stage.get_segment(index)
		_draw_marker(
			stage,
			stage.get_end_marker_texture(marked),
			marked.get_end_point(),
			marked.end_marker_radius,
			true
		)
	_draw_marker(
		stage,
		stage.start_marker_texture,
		segment.get_start_point(),
		START_MARKER_RADIUS,
		false
	)
	_draw_route_hint(segment)
	_draw_actor(stage, segment)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_background(stage: TrailStage) -> void:
	if stage != null and stage.ant_journey != null and stage.ant_journey.background != null:
		draw_texture_rect(stage.ant_journey.background,Rect2(Vector2(-_pan_origin,0),Vector2(5760,1080)),false)
		return
	var background := stage.background if stage != null else null
	if background != null:
		draw_texture_rect(background, Rect2(Vector2.ZERO, REFERENCE_SIZE), false)
		return
	var fallback := course.placeholder_background_color if course != null else Color.WHITE
	draw_rect(Rect2(Vector2.ZERO, REFERENCE_SIZE), fallback)


func _board_transform() -> Dictionary:
	var viewport_size := size if size != Vector2.ZERO else REFERENCE_SIZE
	var scale_factor := maxf(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y)
	return {"offset": (viewport_size - REFERENCE_SIZE * scale_factor) * 0.5, "scale": scale_factor}


func _screen_to_reference(position: Vector2) -> Vector2:
	var transform := _board_transform()
	return (position - (transform["offset"] as Vector2)) / float(transform["scale"])


func _set_reference_draw_transform(origin: Vector2, rotation := 0.0, local_scale := Vector2.ONE) -> void:
	var transform := _board_transform()
	var viewport_scale := float(transform["scale"])
	draw_set_transform(
		(transform["offset"] as Vector2) + origin * viewport_scale,
		rotation,
		local_scale * viewport_scale
	)


func is_pointer_pressed() -> bool:
	return _pointer_pressed


func shift_to_stage(index: int) -> void:
	_input_enabled = false
	_pan_from = _pan_origin
	_pan_to = course.get_stage(index).view_origin
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_pan_fraction,0.0,1.0,course.stage_handover_duration)
	await tween.finished
	_pan_inertia = 0
	set_active_stage(index)
	_distance = minf(18.0,_current_segment().get_length())
	_input_enabled = true
	_update_processing()
	queue_redraw()


func _set_pan_fraction(fraction: float) -> void:
	_pan_origin = lerpf(_pan_from,_pan_to,fraction)
	_pan_inertia = 18*fraction
	queue_redraw()


func _draw_ant_journey(stage: TrailStage) -> void:
	var journey := stage.ant_journey
	var offset := AntJourney.SCREEN_ORIGIN-Vector2(_pan_origin,0)
	for tile: Dictionary in journey.tiles:
		var position: Vector2 = tile.offset+offset
		var tile_size: Vector2 = tile.size
		if not Rect2(position,tile_size).intersects(Rect2(Vector2.ZERO,REFERENCE_SIZE)): continue
		var scale := Vector2.ONE
		if tile.orientation in ["T-R","B-R"]:
			position.x += tile_size.x
			scale.x = -1
		if tile.orientation in ["T-R","L-T","L-R-flip"]:
			position.y += tile_size.y
			scale.y = -1
		_set_reference_draw_transform(position, 0.0, scale)
		draw_texture_rect(tile.texture,Rect2(Vector2.ZERO,tile_size),false)
		_set_reference_draw_transform(Vector2.ZERO)
	for cover: Dictionary in journey.covers:
		_draw_ant_sprite(cover,cover.position+offset,0.5,cover.angle,Color.WHITE)
	for marker: Dictionary in journey.markers:
		var point: Vector2 = marker.position+offset
		if point.x < -220 or point.x > REFERENCE_SIZE.x+220: continue
		var objective := bool(marker.objective)
		if objective:
			var halo := _objective_glow()
			_draw_berry_glow(point,halo.radius,halo.color,true)
			_draw_ant_sprite(marker,point,1.0,0,Color.WHITE)
		else:
			var feedback := _checkpoint_feedback(marker,journey)
			if not feedback.passed:
				_draw_berry_glow(point,feedback.halo_radius,Color(1,0.86,0.42,feedback.halo_alpha),true)
			_draw_ant_sprite(marker,point+feedback.offset,0.5*feedback.scale,0,feedback.tint)


func _objective_glow() -> Dictionary:
	var pulse := (1+sin(TAU*_glow_time/3))/2
	# The double-size fruit needs visible light beyond its opaque body.
	return {"radius":210+18*pulse,
		"color":Color.from_hsv(fmod(_glow_time/9,1.0),0.55,1,0.48+0.16*pulse)}


func _record_checkpoint_passes(journey: AntJourney) -> void:
	for marker: Dictionary in journey.markers:
		var distance := float(marker.distance)
		if marker.objective or journey.passed_distance+1<distance: continue
		if not journey.checkpoint_pass_times.has(distance):
			journey.checkpoint_pass_times[distance]=_glow_time


func _checkpoint_feedback(marker: Dictionary,journey: AntJourney) -> Dictionary:
	var distance := float(marker.distance)
	var passed := journey.passed_distance+1>=distance
	if passed:
		var elapsed := maxf(0,_glow_time-float(journey.checkpoint_pass_times.get(distance,-100.0)))
		var bounce := sin(PI*clampf(elapsed/CHECKPOINT_BOUNCE_SECONDS,0,1))
		return {"passed":true,"approach":0.0,"halo_radius":0.0,"halo_alpha":0.0,
			"scale":1+0.16*bounce,"offset":Vector2(0,-14*bounce),"tint":Color(0.55,0.58,0.52,1)}
	var segment := _current_segment()
	var remaining := distance-(segment.global_start_distance+_distance)
	# Arc distance avoids reacting to a nearby but unrelated arm of a snake.
	var approach := smoothstep(CHECKPOINT_APPROACH_DISTANCE,0.0,maxf(remaining,0.0))
	var breath := (1+sin(TAU*_glow_time/2.8))/2
	return {"passed":false,"approach":approach,"halo_radius":105+6*breath+14*approach,
		"halo_alpha":0.34+0.08*breath+0.18*approach,
		"scale":1+0.10*approach,"offset":Vector2.ZERO,"tint":Color.WHITE}


func _draw_ant_sprite(record: Dictionary,position: Vector2,scale: float,angle: float,color: Color) -> void:
	var texture: Texture2D = record.texture
	_set_reference_draw_transform(position, angle, Vector2.ONE * scale)
	draw_texture_rect(texture,Rect2(-Vector2(record.anchor),texture.get_size()),false,color)
	_set_reference_draw_transform(Vector2.ZERO)


func _draw_berry_glow(position: Vector2,radius: float,color: Color,checkpoint_halo := false) -> void:
	for layer in range(16,0,-1):
		var fraction := float(layer)/16
		var tint := color
		tint.a *= (1-fraction)/4 if checkpoint_halo else (1-fraction)*(1-fraction)/3
		draw_circle(position,radius*fraction,tint)


## A quiet line back toward the route. It carries no sound or colour change: it
## says where the route is, it does not say that anything went wrong.
func _draw_route_hint(segment: TrailSegment) -> void:
	if not _off_route:
		return
	var actor_position := get_actor_position()
	if is_actor_outside_corridor():
		draw_line(actor_position, segment.point_at_distance(_distance), TETHER_COLOR, 10.0, true)
	elif _dragging:
		draw_line(_pointer_position, actor_position, TETHER_COLOR, 10.0, true)


## Whether a run's marker is on screen. It follows the run: a marker belongs to a
## place the child can see, and a checkpoint they could be sent back to must never
## be invisible while they are walking away from it.
func _is_segment_marked(stage: TrailStage, index: int) -> bool:
	if not stage.draw_corridor_overlay:
		# The route is painted into the background, so the whole way across is
		# already visible and its markers belong with it.
		return true
	if stage.get_corridor_texture(stage.get_segment(index)) != null:
		# The objects of a crossing are physically there from the first frame, and
		# so are the leaves resting between them.
		return true
	return index <= _segment_index


## A corridor made of objects is drawn whole, because the straws and leaves of a
## crossing are physically there and a child should see the way across before
## setting out. A corridor made of colour keeps the quieter reading it was
## authored for: where you have been, and where you are.
func _draw_stage_corridor(stage: TrailStage) -> void:
	for index in range(stage.get_segment_count()):
		var segment := stage.get_segment(index)
		if segment == null:
			continue
		var texture := stage.get_corridor_texture(segment)
		if segment.phrase_texture != null:
			_draw_phrase_surface(segment)
		elif texture != null:
			_draw_corridor_objects(segment, texture)
		elif index < _segment_index:
			_draw_corridor_fill(
				segment, stage.completed_corridor_color, stage.completed_corridor_color
			)
		elif index == _segment_index:
			_draw_corridor_fill(segment, stage.corridor_edge_color, stage.corridor_color)


## Lays the run's object along it: one copy per straight stretch, stretched to
## that stretch's length and to the authored corridor width, so the visible
## surface and the corridor boundary cannot disagree.
func _draw_corridor_objects(segment: TrailSegment, texture: Texture2D) -> void:
	var polyline := segment.get_polyline()
	for index in range(1, polyline.size()):
		var from := polyline[index - 1]
		var to := polyline[index]
		var span := to - from
		var length := span.length()
		if length <= 0.0:
			continue
		var drawn := Vector2(length + CORRIDOR_OBJECT_OVERLAP * 2.0, segment.path_width)
		_set_reference_draw_transform((from + to) * 0.5, span.angle())
		draw_texture_rect(texture, Rect2(-drawn * 0.5, drawn), false)
		_set_reference_draw_transform(Vector2.ZERO)


func _draw_phrase_surface(segment: TrailSegment) -> void:
	var texture := segment.phrase_texture
	if texture == null:
		return
	var drawn := texture.get_size() * segment.phrase_scale
	if segment.phrase_mirrored:
		_set_reference_draw_transform(
			segment.phrase_position + Vector2(0.0, drawn.y), 0.0, Vector2(1.0, -1.0)
		)
		draw_texture_rect(texture, Rect2(Vector2.ZERO, drawn), false)
		_set_reference_draw_transform(Vector2.ZERO)
		return
	draw_texture_rect(texture, Rect2(segment.phrase_position, drawn), false)


func _draw_corridor_fill(segment: TrailSegment, edge_color: Color, fill_color: Color) -> void:
	if segment == null:
		return
	var polyline := segment.get_polyline()
	if polyline.size() < 2:
		return
	if edge_color != fill_color:
		_draw_corridor(polyline, segment.path_width + CORRIDOR_EDGE_WIDTH, edge_color)
	_draw_corridor(polyline, segment.path_width, fill_color)


## A polyline with round joints, so a curved corridor keeps one even width.
func _draw_corridor(polyline: PackedVector2Array, width: float, color: Color) -> void:
	for index in range(1, polyline.size()):
		draw_line(polyline[index - 1], polyline[index], color, width, true)
	for point in polyline:
		draw_circle(point, width * 0.5, color)


func _draw_travelled(stage: TrailStage, segment: TrailSegment) -> void:
	if _distance <= 0.0:
		return
	var polyline := segment.get_polyline()
	var travelled := PackedVector2Array()
	travelled.append(polyline[0])
	var covered := 0.0
	for index in range(1, polyline.size()):
		covered += polyline[index - 1].distance_to(polyline[index])
		if covered > _distance:
			break
		travelled.append(polyline[index])
	travelled.append(segment.point_at_distance(_distance))
	if travelled.size() < 2:
		return
	_draw_corridor(travelled, segment.get_width_at_distance(_distance) * 0.42, stage.travelled_color)


## Draws one marker: its artwork when the stage supplies it, and the placeholder
## shape otherwise, so an unpainted route still shows where it begins and ends.
## Placeholder furniture belongs to the unpainted state, and a background is the
## signal that a stage has been painted: once one exists, a place that wants no
## start marker simply names none rather than getting a stray dot over its
## scenery.
func _draw_marker(
	stage: TrailStage, texture: Texture2D, center: Vector2, radius: float, is_goal: bool
) -> void:
	if texture != null:
		_draw_texture_centered(texture, center, radius, 0.0)
		return
	if stage.background != null:
		return
	if not is_goal:
		draw_circle(center, radius * 0.55, START_MARKER_COLOR)
		return
	for petal in range(6):
		var angle := TAU * float(petal) / 6.0
		var offset := Vector2(cos(angle), sin(angle)) * radius * 0.8
		draw_circle(center + offset, radius * 0.62, GOAL_PETAL_COLOR)
	draw_circle(center, radius * 0.6, GOAL_CENTER_COLOR)


func _draw_actor(stage: TrailStage, segment: TrailSegment) -> void:
	var center := get_actor_position()
	var radius := stage.get_actor_draw_radius()
	if _dragging:
		# A halo just outside the actor. It is deliberately close: sized against a
		# placeholder the size of its own collision circle it could be generous,
		# but real artwork is drawn much larger than that and a wide ring then
		# covers more of the corridor than the actor does.
		draw_circle(center, radius * GRAB_RING_SCALE, GRAB_RING_COLOR)
	var texture := stage.get_actor_frame(_actor_frame)
	if texture == null:
		_draw_placeholder_actor(center, radius)
		return
	if not stage.actor_turns_to_travel:
		_draw_texture_centered(texture, center, radius, 0.0)
		return
	_draw_texture_centered(
		texture,
		center,
		radius,
		actor_draw_rotation(stage.actor_art_facing_degrees, _facing_angle),
		is_actor_mirrored(stage.actor_art_facing_degrees, _facing_angle)
	)


## How far to rotate artwork that already points `art_facing_degrees` so that it
## points along `facing_angle`. Beyond a quarter turn the sprite is mirrored rather
## than rotated further.
##
## The mirror is a reflection about the axis perpendicular to the artwork's own
## forward, because that is the reflection which actually reverses forward. For art
## drawn pointing right that is a horizontal flip; for art drawn pointing down the
## screen it is a vertical one. Against the artwork's declared facing the two
## collapse into one rule: flip vertically and rotate by `facing + art` instead of
## rotating by `facing - art`. Getting this wrong is silent on art drawn pointing
## right, where both forms agree, and reverses art drawn pointing any other way.
##
## Mirroring does not bound how far the sprite turns: a top-down actor rotates
## through the whole circle, because a creature seen from above genuinely does. What
## it chooses is which of the two chiralities is used, the two differing by a
## reflection about the actor's own body axis. On an asymmetric actor that is the
## difference between reading as a creature travelling leftward and reading as an
## upside-down one. On artwork symmetric about that axis it makes no visible
## difference at all, and costs nothing.
static func actor_draw_rotation(art_facing_degrees: float, facing_angle: float) -> float:
	var art := deg_to_rad(art_facing_degrees)
	if is_actor_mirrored(art_facing_degrees, facing_angle):
		return facing_angle + art
	return facing_angle - art


static func is_actor_mirrored(art_facing_degrees: float, facing_angle: float) -> bool:
	return cos(facing_angle - deg_to_rad(art_facing_degrees)) < 0.0


func _draw_texture_centered(
	texture: Texture2D, center: Vector2, radius: float, angle: float, mirrored := false
) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	# Artwork is fitted by width, so a stage's authored radius means the same
	# thing whatever aspect its picture happens to have.
	var fit_scale := radius * 2.0 / texture_size.x
	var drawn := texture_size * fit_scale
	_set_reference_draw_transform(center, angle, Vector2(1.0, -1.0 if mirrored else 1.0))
	draw_texture_rect(texture, Rect2(-drawn * 0.5, drawn), false)
	_set_reference_draw_transform(Vector2.ZERO)


func _draw_placeholder_actor(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(-radius * 0.5, -radius * 0.75), radius * 0.55, ACTOR_WING_COLOR)
	draw_circle(center + Vector2(radius * 0.5, -radius * 0.75), radius * 0.55, ACTOR_WING_COLOR)
	draw_circle(center, radius, ACTOR_COLOR)
	draw_line(
		center + Vector2(-radius * 0.55, -radius * 0.4),
		center + Vector2(-radius * 0.25, radius * 0.8),
		ACTOR_STRIPE_COLOR,
		14.0,
		true
	)
	draw_line(
		center + Vector2(radius * 0.1, -radius * 0.7),
		center + Vector2(radius * 0.4, radius * 0.6),
		ACTOR_STRIPE_COLOR,
		14.0,
		true
	)
