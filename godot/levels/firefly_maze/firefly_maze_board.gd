class_name FireflyMazeBoard
extends Control

## Authored geometry, rendering and input share one contained reference board.

signal stage_reached_house
signal firefly_grabbed
signal wall_bumped

const REFERENCE_SIZE := Vector2(2160.0, 1080.0)
const BASE_CELL_SIZE := 64.0
const MIN_SCREEN_CELL_FRACTION := 28.0 / 540.0
const SAFE_LEFT_FRACTION := 110.0 / 1080.0
const SAFE_RIGHT_FRACTION := 970.0 / 1080.0
const SAFE_TOP_FRACTION := 40.0 / 540.0
const SAFE_BOTTOM_FRACTION := 480.0 / 540.0
const OVERVIEW_SECONDS := 0.7
const ZOOM_SECONDS := 0.6
const MAX_MOVEMENT_SAMPLE := 28.0
const FIREFLY_BODY_RADIUS := 22.0
const FIREFLY_CAPTURE_RADIUS := 112.0
const HOUSE_REACH_RADIUS := 26.0
const FLOWER_BRIGHT_SECONDS := 3.0
const FLOWER_FADE_SECONDS := 2.0
const WALL_BUMP_SECONDS := 0.18
const TRAIL_CLOCK_SECONDS := 0.04
const TRAIL_FADE_STEPS := 12
const TRAIL_BRIGHT_TICKS := int(FLOWER_BRIGHT_SECONDS / TRAIL_CLOCK_SECONDS)
const TRAIL_FADE_TICKS := int(FLOWER_FADE_SECONDS / TRAIL_CLOCK_SECONDS)
const POINTER_POSITION_GAIN := 7.5
const POINTER_MAX_SPEED := 1500.0
const POINTER_MAX_ACCELERATION := 5200.0
const POINTER_MAX_DECELERATION := 6000.0
const POINTER_ARRIVAL_DISTANCE := 6.0
const POINTER_PATH_SAMPLE_SPACING := 20.0
const POINTER_SIGHT_SAMPLE_SPACING := 8.0

const HOME := preload("res://assets/gameplay/firefly-maze/home.png")
const HOME_EMISSION := preload("res://assets/gameplay/firefly-maze/home-emission.png")
const HOME_HALO := preload("res://assets/gameplay/firefly-maze/home-halo.png")
const FIREFLY_BODY := preload("res://assets/gameplay/firefly-maze/firefly-body.png")
const FIREFLY_EMISSION := preload("res://assets/gameplay/firefly-maze/firefly-body-emission.png")
const FIREFLY_HALO := preload("res://assets/gameplay/firefly-maze/firefly-body-halo.png")
const LEFT_WING := preload("res://assets/gameplay/firefly-maze/left-wing.png")
const RIGHT_WING := preload("res://assets/gameplay/firefly-maze/right-wing.png")


class MazeStage:
	var stage_name: String
	var rows: Array[String]
	var start_cell: Vector2i
	var house_cell: Vector2i
	var main_polyline: Array[Vector2i]
	var dead_end_polylines: Array[Array]


class TrailEvent:
	var cell: Vector2i
	var generation := 0
	var fade_start_tick := 0
	var fade_step := 1


var _stages: Array[MazeStage] = []
var _interaction_polygons: Array[PackedVector2Array] = []
var _interaction_centerlines: Array[PackedVector2Array] = []
var _interaction_polygon_centerlines: Array[PackedVector2Array] = []
var _stage_index := 0
var _cell_size := BASE_CELL_SIZE
var _view_zoom := 1.0
var _zoom_tween: Tween
var _firefly_position := Vector2.ZERO
var _pointer_target := Vector2.ZERO
var _pointer_path: Array[Vector2] = []
var _last_pointer_position := Vector2.ZERO
var _follow_velocity := Vector2.ZERO
var _dragging := false
var _input_enabled := true
var _stage_resolved := false
var _trail_generations: Dictionary[Vector2i, int] = {}
var _trail_flowers: Dictionary[Vector2i, FireflyTrailFlower] = {}
var _trail_events: Dictionary[int, Array] = {}
var _trail_epoch_msec := 0
var _last_visited_cell := Vector2i(-1000, -1000)
var _trail_transition_count := 0
var _processing_trail_events := false
var _wall_bump_age := -1.0
var _static_layer: FireflyMazeStaticLayer
var _trail_layer: Control
var _trail_timer: Timer
var _wall_bump_timer: Timer
var _animation_timer: Timer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_static_layer = FireflyMazeStaticLayer.new()
	_static_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_static_layer)
	_trail_layer = Control.new()
	_trail_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trail_layer.show_behind_parent = true
	add_child(_trail_layer)
	_trail_timer = Timer.new()
	_trail_timer.one_shot = true
	_trail_timer.timeout.connect(_on_trail_timer_timeout)
	add_child(_trail_timer)
	_wall_bump_timer = Timer.new()
	_wall_bump_timer.one_shot = true
	_wall_bump_timer.timeout.connect(_finish_wall_bump)
	add_child(_wall_bump_timer)
	_animation_timer = Timer.new()
	_animation_timer.wait_time = 0.08
	_animation_timer.timeout.connect(queue_redraw)
	add_child(_animation_timer)
	_animation_timer.start()
	resized.connect(_on_resized)
	_stages = _make_candidate_stages()
	reset_run()


func reset_run() -> void:
	_stage_index = 0
	_set_up_stage()


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	_dragging = false
	_follow_velocity = Vector2.ZERO
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func get_stage_index() -> int:
	return _stage_index


func get_stage_count() -> int:
	return _stages.size()


func has_next_stage() -> bool:
	return _stage_index + 1 < _stages.size()


func advance_stage() -> void:
	if not has_next_stage():
		return
	_stage_index += 1
	_set_up_stage()


func get_firefly_position() -> Vector2:
	return _firefly_position


func get_follow_speed() -> float:
	return _follow_velocity.length()


func is_dragging() -> bool:
	return _dragging


func is_stage_resolved() -> bool:
	return _stage_resolved


func get_lit_flower_count() -> int:
	return _trail_flowers.size()


func get_trail_transition_count() -> int:
	return _trail_transition_count


func get_stage_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for stage in _stages:
		errors.append_array(_validate_stage(stage))
	return errors


func get_main_reference_path() -> PackedVector2Array:
	var stage := _current_stage()
	return _reference_path(stage.main_polyline) if stage != null else PackedVector2Array()


func get_dead_end_reference_path(index: int) -> PackedVector2Array:
	var stage := _current_stage()
	if stage == null or index < 0 or index >= stage.dead_end_polylines.size():
		return PackedVector2Array()
	return _reference_path(_typed_polyline(stage.dead_end_polylines[index]))


func begin_drag_at_reference(position: Vector2) -> bool:
	var transform := get_view_transform()
	var screen_position := position * float(transform.scale) + (transform.offset as Vector2)
	if not _input_enabled or _stage_resolved or not get_screen_safe_rect().has_point(screen_position) or position.distance_to(_firefly_position) > FIREFLY_CAPTURE_RADIUS * _cell_size / BASE_CELL_SIZE:
		return false
	_dragging = true
	_pointer_target = position
	_last_pointer_position = position
	_pointer_path = [position]
	set_process(true)
	firefly_grabbed.emit()
	return true


func drag_to_reference(position: Vector2) -> void:
	if not _dragging or not _input_enabled or _stage_resolved:
		return
	_append_pointer_position(position)
	set_process(true)


func release_drag() -> void:
	_dragging = false
	_follow_velocity = Vector2.ZERO
	_pointer_path.clear()
	set_process(false)


func advance_pointer_follow_for_test(duration: float) -> void:
	var remaining := duration
	while remaining > 0.0:
		var delta := minf(remaining, 1.0 / 60.0)
		_advance_pointer_follow(delta)
		remaining -= delta


func advance_time_for_test(delta: float) -> void:
	_trail_epoch_msec -= int(delta * 1000.0)
	_process_due_trail_events(_current_trail_tick())
	_arm_trail_timer()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if begin_drag_at_reference(_screen_to_reference(event.position)):
				accept_event()
		else:
			release_drag()
	elif event is InputEventMouseMotion:
		_drag_at_screen_position(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			if begin_drag_at_reference(_screen_to_reference(event.position)):
				accept_event()
		else:
			release_drag()
	elif event is InputEventScreenDrag:
		_drag_at_screen_position(event.position)


func _drag_at_screen_position(position: Vector2) -> void:
	if _dragging and not get_screen_safe_rect().has_point(position):
		release_drag()
		return
	drag_to_reference(_screen_to_reference(position))


func _set_up_stage() -> void:
	_dragging = false
	_follow_velocity = Vector2.ZERO
	_pointer_path.clear()
	_stage_resolved = false
	_clear_trail()
	_trail_epoch_msec = Time.get_ticks_msec()
	_last_visited_cell = Vector2i(-1000, -1000)
	_trail_transition_count = 0
	_wall_bump_age = -1.0
	_wall_bump_timer.stop()
	var stage := _current_stage()
	if stage == null:
		return
	var art_overhang := FireflyMazeStaticLayer.WALL_OVERLAP - 1.0 + 2.0 * FireflyMazeStaticLayer.WALL_MAX_OFFSET_FRACTION
	var fit_rect := FireflyMazeStaticLayer.BACKDROP_MAZE_RECT
	_cell_size = minf(
		fit_rect.size.x / (float(stage.rows[0].length() + 2) + art_overhang),
		fit_rect.size.y / (float(stage.rows.size() + 2) + art_overhang)
	)
	_static_layer.configure(stage.rows, _cell_size, _stage_index, stage.house_cell)
	_rebuild_interaction_polygons(stage)
	_firefly_position = _cell_center(stage.start_cell)
	_pointer_target = _firefly_position
	_last_pointer_position = _firefly_position
	_visit_cell(stage.start_cell)
	_begin_stage_view()


func _process(delta: float) -> void:
	_advance_pointer_follow(delta)


func _advance_pointer_follow(delta: float) -> void:
	if not _dragging or not _input_enabled or _stage_resolved:
		_follow_velocity = Vector2.ZERO
		set_process(false)
		return
	var reachable_target := _next_pointer_path_target()
	var error := reachable_target - _firefly_position
	var distance := error.length()
	var arrival_reach := maxf(POINTER_ARRIVAL_DISTANCE, _follow_velocity.length() * delta * 1.1)
	if (
		distance <= arrival_reach
		and (_follow_velocity.is_zero_approx() or _follow_velocity.dot(error) >= 0.0)
	):
		_firefly_position = reachable_target
		_follow_velocity = Vector2.ZERO
		if not _pointer_path.is_empty():
			_pointer_path.pop_front()
		queue_redraw()
		_resolve_house_if_reached()
		if _pointer_path.is_empty():
			set_process(false)
		return
	var motion_scale := _cell_size / BASE_CELL_SIZE
	var braking_speed := sqrt(2.0 * POINTER_MAX_DECELERATION * motion_scale * distance)
	var desired_speed := minf(POINTER_MAX_SPEED * motion_scale, minf(POINTER_POSITION_GAIN * distance, braking_speed))
	var desired_velocity := error.normalized() * desired_speed
	_follow_velocity = _follow_velocity.move_toward(desired_velocity, POINTER_MAX_ACCELERATION * motion_scale * delta)
	var before := _firefly_position
	var bumped := _move_toward(_firefly_position + _follow_velocity * delta)
	var actual_velocity := (_firefly_position - before) / maxf(delta, 0.0001)
	if bumped:
		_follow_velocity = actual_velocity
	if actual_velocity.length_squared() < 0.01 and bumped and _pointer_path.size() <= 1:
		set_process(false)


func _move_toward(target: Vector2) -> bool:
	var maximum_steps := maxi(1, ceili(_firefly_position.distance_to(target) / MAX_MOVEMENT_SAMPLE) * 2)
	var bumped := false
	for _step in maximum_steps:
		var remaining := target - _firefly_position
		if remaining.length() <= 0.5:
			_firefly_position = target
			break
		var movement := remaining.limit_length(MAX_MOVEMENT_SAMPLE)
		var candidate := _firefly_position + movement
		if _is_walkable_position(candidate):
			_firefly_position = candidate
			_visit_cell(_cell_for_position(candidate))
			continue
		bumped = true
		_firefly_position = _furthest_walkable_position(_firefly_position, candidate)
		_firefly_position = _nudge_inside_interaction_corridor(_firefly_position)
		var residual := candidate - _firefly_position
		var slid_position := _slide_along_interaction_boundary(_firefly_position, residual)
		if slid_position.is_equal_approx(_firefly_position):
			break
		_firefly_position = slid_position
		_visit_cell(_cell_for_position(_firefly_position))
	if bumped:
		_wall_bump_age = 0.0
		wall_bumped.emit()
		_wall_bump_timer.start(WALL_BUMP_SECONDS)
		queue_redraw()
	queue_redraw()
	_resolve_house_if_reached()
	return bumped


func _slide_along_interaction_boundary(position: Vector2, blocked_movement: Vector2) -> Vector2:
	var nearest_distance_squared := INF
	var nearest_tangent := Vector2.ZERO
	for polygon: PackedVector2Array in _interaction_polygons:
		for point_index in polygon.size():
			var segment_start := polygon[point_index]
			var segment_end := polygon[(point_index + 1) % polygon.size()]
			var closest := Geometry2D.get_closest_point_to_segment(position, segment_start, segment_end)
			var distance_squared := position.distance_squared_to(closest)
			if distance_squared < nearest_distance_squared:
				nearest_distance_squared = distance_squared
				nearest_tangent = (segment_end - segment_start).normalized()
	if nearest_tangent.is_zero_approx():
		return position
	var tangent_movement := nearest_tangent * blocked_movement.dot(nearest_tangent)
	if tangent_movement.length_squared() < 0.01:
		return position
	var slide_target := position + tangent_movement
	if _is_walkable_position(slide_target):
		return slide_target
	return _furthest_walkable_position(position, slide_target)


func _nudge_inside_interaction_corridor(position: Vector2) -> Vector2:
	var nearest_centerline_point := position
	var nearest_distance_squared := INF
	for polyline: PackedVector2Array in _interaction_centerlines:
		for point_index in range(polyline.size() - 1):
			var candidate := Geometry2D.get_closest_point_to_segment(
				position,
				polyline[point_index],
				polyline[point_index + 1]
			)
			var distance_squared := position.distance_squared_to(candidate)
			if distance_squared < nearest_distance_squared:
				nearest_centerline_point = candidate
				nearest_distance_squared = distance_squared
	return position.move_toward(nearest_centerline_point, 0.5)


func _resolve_house_if_reached() -> void:
	if not _stage_resolved and _house_reached():
		_stage_resolved = true
		_dragging = false
		_follow_velocity = Vector2.ZERO
		set_process(false)
		stage_reached_house.emit()


func _visit_cell(cell: Vector2i) -> void:
	if not _is_walkable_cell(cell) or cell == _last_visited_cell:
		return
	_last_visited_cell = cell
	if cell == _current_stage().house_cell or not FireflyMazeStaticLayer.has_breadcrumb(cell, _stage_index):
		return
	var generation: int = _trail_generations.get(cell, 0) + 1
	_trail_generations[cell] = generation
	var flower: FireflyTrailFlower = _trail_flowers.get(cell) as FireflyTrailFlower
	if flower == null:
		flower = FireflyTrailFlower.new()
		var plant_rect := FireflyMazeStaticLayer.breadcrumb_rect(_cell_center(cell), _cell_size, cell, _stage_index)
		flower.size = plant_rect.size
		flower.position = plant_rect.position
		flower.set_motif_index(FireflyMazeStaticLayer.breadcrumb_index(cell, _stage_index))
		_trail_layer.add_child(flower)
		_trail_flowers[cell] = flower
	flower.set_quantized_alpha(0, TRAIL_FADE_STEPS)
	var event := TrailEvent.new()
	event.cell = cell
	event.generation = generation
	event.fade_start_tick = _current_trail_tick() + TRAIL_BRIGHT_TICKS
	event.fade_step = 1
	_schedule_trail_event(event, _fade_due_tick(event))


func _house_reached() -> bool:
	var stage := _current_stage()
	return stage != null and _firefly_position.distance_to(_cell_center(stage.house_cell)) <= HOUSE_REACH_RADIUS


func _current_stage() -> MazeStage:
	return _stages[_stage_index] if _stage_index >= 0 and _stage_index < _stages.size() else null


func _board_rect() -> Rect2:
	var stage := _current_stage()
	if stage == null:
		return Rect2()
	var board_size := Vector2(stage.rows[0].length() * _cell_size, stage.rows.size() * _cell_size)
	return Rect2(FireflyMazeStaticLayer.BACKDROP_MAZE_RECT.get_center() - board_size * 0.5, board_size)


func _cell_center(cell: Vector2i) -> Vector2:
	return _board_rect().position + (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_size


func _cell_for_position(position: Vector2) -> Vector2i:
	var local := position - _board_rect().position
	return Vector2i(floori(local.x / _cell_size), floori(local.y / _cell_size))


func _is_walkable_position(position: Vector2) -> bool:
	for polygon: PackedVector2Array in _interaction_polygons:
		if Geometry2D.is_point_in_polygon(position, polygon):
			return true
	return false


func _rebuild_interaction_polygons(stage: MazeStage) -> void:
	_interaction_polygons.clear()
	_interaction_centerlines.clear()
	_interaction_polygon_centerlines.clear()
	_append_interaction_corridor(_reference_path(stage.main_polyline))
	for raw_polyline: Array in stage.dead_end_polylines:
		_append_interaction_corridor(_reference_path(_typed_polyline(raw_polyline)))


func _append_interaction_corridor(polyline: PackedVector2Array) -> void:
	if polyline.size() < 2:
		return
	_interaction_centerlines.append(polyline)
	var generated := Geometry2D.offset_polyline(
		polyline,
		_cell_size * 0.4375,
		Geometry2D.JOIN_ROUND,
		Geometry2D.END_ROUND
	)
	for polygon: PackedVector2Array in generated:
		_interaction_polygons.append(polygon)
		_interaction_polygon_centerlines.append(polyline)


func _constrain_to_interaction_corridor(position: Vector2) -> Vector2:
	if _is_walkable_position(position):
		return position
	var nearest_visible := _firefly_position
	var nearest_visible_distance_squared := INF
	var nearest_fallback := _firefly_position
	var nearest_fallback_distance_squared := INF
	for polygon_index in _interaction_polygons.size():
		var polygon := _interaction_polygons[polygon_index]
		var centerline := _interaction_polygon_centerlines[polygon_index]
		for point_index in polygon.size():
			var boundary_point := Geometry2D.get_closest_point_to_segment(
				position,
				polygon[point_index],
				polygon[(point_index + 1) % polygon.size()]
			)
			var centerline_point := _closest_point_on_polyline(boundary_point, centerline)
			var candidate := boundary_point.move_toward(centerline_point, 0.5)
			var distance_squared := position.distance_squared_to(candidate)
			if distance_squared < nearest_fallback_distance_squared:
				nearest_fallback = candidate
				nearest_fallback_distance_squared = distance_squared
			if (
				distance_squared < nearest_visible_distance_squared
				and _segment_stays_in_interaction_corridor(_firefly_position, candidate)
			):
				nearest_visible = candidate
				nearest_visible_distance_squared = distance_squared
	return nearest_visible if nearest_visible_distance_squared < INF else nearest_fallback


func _closest_point_on_polyline(position: Vector2, polyline: PackedVector2Array) -> Vector2:
	var closest := position
	var closest_distance_squared := INF
	for point_index in range(polyline.size() - 1):
		var candidate := Geometry2D.get_closest_point_to_segment(
			position,
			polyline[point_index],
			polyline[point_index + 1]
		)
		var distance_squared := position.distance_squared_to(candidate)
		if distance_squared < closest_distance_squared:
			closest = candidate
			closest_distance_squared = distance_squared
	return closest


func _append_pointer_position(position: Vector2) -> void:
	_pointer_target = position
	var distance := _last_pointer_position.distance_to(position)
	if distance <= 0.5:
		return
	var sample_count := maxi(1, ceili(distance / POINTER_PATH_SAMPLE_SPACING))
	for sample_index in range(1, sample_count + 1):
		_pointer_path.append(_last_pointer_position.lerp(position, float(sample_index) / sample_count))
	_last_pointer_position = position


func _next_pointer_path_target() -> Vector2:
	if _pointer_path.is_empty():
		return _constrain_to_interaction_corridor(_pointer_target)
	var chosen_index := -1
	var chosen_target := _constrain_to_interaction_corridor(_pointer_path[0])
	for path_index in _pointer_path.size():
		var candidate := _constrain_to_interaction_corridor(_pointer_path[path_index])
		if not _segment_stays_in_interaction_corridor(_firefly_position, candidate):
			continue
		chosen_index = path_index
		chosen_target = candidate
	if chosen_index < 0:
		return chosen_target
	for _discarded_index in chosen_index:
		_pointer_path.pop_front()
	return chosen_target


func _segment_stays_in_interaction_corridor(from: Vector2, to: Vector2) -> bool:
	var distance := from.distance_to(to)
	var sample_count := maxi(1, ceili(distance / POINTER_SIGHT_SAMPLE_SPACING))
	for sample_index in range(1, sample_count + 1):
		if not _is_walkable_position(from.lerp(to, float(sample_index) / sample_count)):
			return false
	return true


func _furthest_walkable_position(from: Vector2, to: Vector2) -> Vector2:
	var safe_fraction := 0.0
	var blocked_fraction := 1.0
	for _iteration in 8:
		var test_fraction := (safe_fraction + blocked_fraction) * 0.5
		if _is_walkable_position(from.lerp(to, test_fraction)):
			safe_fraction = test_fraction
		else:
			blocked_fraction = test_fraction
	return from.lerp(to, safe_fraction)


func _is_walkable_cell(cell: Vector2i) -> bool:
	var stage := _current_stage()
	if stage == null or cell.y < 0 or cell.y >= stage.rows.size():
		return false
	var row := stage.rows[cell.y]
	return cell.x >= 0 and cell.x < row.length() and row.substr(cell.x, 1) == "."


func _contain_transform() -> Dictionary:
	var viewport_size := size if size != Vector2.ZERO else REFERENCE_SIZE
	var scale_factor := minf(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y)
	return {"offset": (viewport_size - REFERENCE_SIZE * scale_factor) * 0.5, "scale": scale_factor}


func get_screen_safe_rect() -> Rect2:
	var viewport_size := size if size != Vector2.ZERO else REFERENCE_SIZE
	return Rect2(
		Vector2(viewport_size.x * SAFE_LEFT_FRACTION, viewport_size.y * SAFE_TOP_FRACTION),
		Vector2(viewport_size.x * (SAFE_RIGHT_FRACTION - SAFE_LEFT_FRACTION), viewport_size.y * (SAFE_BOTTOM_FRACTION - SAFE_TOP_FRACTION))
	)


func get_view_transform() -> Dictionary:
	var base := _contain_transform()
	var scale_factor: float = float(base.scale) * _view_zoom
	var viewport_size := size if size != Vector2.ZERO else REFERENCE_SIZE
	var safe_rect := get_screen_safe_rect()
	var maze_rect := FireflyMazeStaticLayer.BACKDROP_MAZE_RECT
	var offset := safe_rect.get_center() - maze_rect.get_center() * scale_factor
	var backdrop_size := REFERENCE_SIZE * scale_factor
	var scaled_maze := Rect2(maze_rect.position * scale_factor, maze_rect.size * scale_factor)
	offset.x = _safe_cover_offset(offset.x, viewport_size.x, backdrop_size.x, scaled_maze.position.x, scaled_maze.end.x, safe_rect.position.x, safe_rect.end.x)
	offset.y = _safe_cover_offset(offset.y, viewport_size.y, backdrop_size.y, scaled_maze.position.y, scaled_maze.end.y, safe_rect.position.y, safe_rect.end.y)
	return {"offset": offset, "scale": scale_factor}


static func _safe_cover_offset(desired: float, screen_length: float, backdrop_length: float, maze_start: float, maze_end: float, safe_start: float, safe_end: float) -> float:
	var safe_min := safe_start - maze_start
	var safe_max := safe_end - maze_end
	var cover_min := screen_length - backdrop_length
	if cover_min <= 0.0:
		var allowed_min := maxf(safe_min, cover_min)
		var allowed_max := minf(safe_max, 0.0)
		if allowed_min <= allowed_max:
			return clampf(desired, allowed_min, allowed_max)
	return clampf(desired, safe_min, safe_max)


func _minimum_backdrop_zoom() -> float:
	var viewport_size := size if size != Vector2.ZERO else REFERENCE_SIZE
	var base_scale: float = float(_contain_transform().scale)
	return maxf(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y) / base_scale


func _target_zoom() -> float:
	var base := _contain_transform()
	var base_scale: float = float(base.scale)
	var safe_rect := get_screen_safe_rect()
	var fit_size := FireflyMazeStaticLayer.BACKDROP_MAZE_RECT.size * base_scale
	var maximum_zoom := minf(safe_rect.size.x / fit_size.x, safe_rect.size.y / fit_size.y)
	var minimum_cell := (size.y if size.y > 0.0 else REFERENCE_SIZE.y) * MIN_SCREEN_CELL_FRACTION
	return clampf(maxf(_minimum_backdrop_zoom(), minimum_cell / (_cell_size * base_scale)), 1.0, maxf(1.0, maximum_zoom))


func _begin_stage_view() -> void:
	if _zoom_tween != null and _zoom_tween.is_running():
		_zoom_tween.kill()
	var target_zoom := _target_zoom()
	var overview_zoom := minf(_minimum_backdrop_zoom(), target_zoom)
	_set_view_zoom(overview_zoom)
	if target_zoom <= overview_zoom + 0.001:
		set_input_enabled(true)
		return
	set_input_enabled(false)
	_zoom_tween = create_tween()
	_zoom_tween.tween_interval(OVERVIEW_SECONDS)
	_zoom_tween.tween_method(_set_view_zoom, overview_zoom, target_zoom, ZOOM_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.finished.connect(_on_zoom_finished)


func _on_zoom_finished() -> void:
	set_input_enabled(true)


func _set_view_zoom(value: float) -> void:
	_view_zoom = value
	_static_layer.queue_redraw()
	_layout_trail_layer()
	queue_redraw()


func _on_resized() -> void:
	if _zoom_tween != null and _zoom_tween.is_running():
		_zoom_tween.kill()
	if _current_stage() != null:
		_view_zoom = _target_zoom()
		if not _stage_resolved:
			set_input_enabled(true)
	_set_view_zoom(_view_zoom)


func _screen_to_reference(position: Vector2) -> Vector2:
	var transform := get_view_transform()
	return (position - transform.offset) / transform.scale


func _layout_trail_layer() -> void:
	if _trail_layer == null:
		return
	var transform := get_view_transform()
	_trail_layer.position = transform.offset
	_trail_layer.scale = Vector2.ONE * transform.scale


func _draw() -> void:
	var transform := get_view_transform()
	draw_set_transform(transform.offset, 0.0, Vector2.ONE * transform.scale)
	_draw_dynamic_state()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var ui_transform := _contain_transform()
	draw_set_transform(ui_transform.offset, 0.0, Vector2.ONE * ui_transform.scale)
	_draw_progress()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_dynamic_state() -> void:
	var stage := _current_stage()
	if stage == null:
		return
	_draw_house(_home_center(stage))
	_draw_firefly()


func _home_center(stage: MazeStage) -> Vector2:
	return _cell_center(stage.house_cell)


func _draw_house(center: Vector2) -> void:
	var extent := 60.0 * _art_scale()
	var rect := Rect2(center - Vector2.ONE * extent, Vector2.ONE * extent * 2.0)
	var glow_alpha := 0.45 if _stage_resolved else 0.16
	draw_texture_rect(HOME_HALO, rect.grow(8.0), false, Color(1.0, 0.78, 0.24, glow_alpha))
	draw_texture_rect(HOME, rect, false)
	draw_texture_rect(HOME_EMISSION, rect, false, Color(1.0, 0.84, 0.34, glow_alpha))


func _draw_firefly() -> void:
	var seconds := float(Time.get_ticks_msec()) / 1000.0
	var flap_speed := 12.0 if _dragging else 7.0
	var flap := sin(seconds * flap_speed) * 0.16
	var transform := get_view_transform()
	for side in [-1, 1]:
		var pivot := _firefly_position + Vector2(float(side) * 15.0, -12.0) * _art_scale()
		var wing := LEFT_WING if side < 0 else RIGHT_WING
		var local_rect := Rect2(-34.0, -19.0, 34.0, 35.0) if side < 0 else Rect2(0.0, -19.0, 34.0, 35.0)
		draw_set_transform(transform.offset + pivot * transform.scale, flap * float(side), Vector2.ONE * transform.scale)
		draw_texture_rect(wing, Rect2(local_rect.position * _art_scale(), local_rect.size * _art_scale()), false)
	draw_set_transform(transform.offset, 0.0, Vector2.ONE * transform.scale)
	var pulse := 1.0 + sin(seconds * 4.0) * 0.05
	var bump := 1.2 if _wall_bump_age >= 0.0 else 1.0
	var body_rect := Rect2(_firefly_position - Vector2(23.0, 33.0) * pulse * bump * _art_scale(), Vector2(46.0, 66.0) * pulse * bump * _art_scale())
	draw_texture_rect(FIREFLY_HALO, body_rect.grow(18.0 * _art_scale()), false, Color(1.0, 0.84, 0.2, 0.46 if _stage_resolved else 0.25))
	draw_texture_rect(FIREFLY_BODY, body_rect, false)
	draw_texture_rect(FIREFLY_EMISSION, body_rect, false, Color(1.0, 0.91, 0.40, 0.85 if _stage_resolved else 0.42))


func _draw_progress() -> void:
	for index in _stages.size():
		var center := Vector2(130.0, 420.0 + index * 80.0)
		var rect := Rect2(center - Vector2.ONE * 37.0, Vector2.ONE * 74.0)
		draw_texture_rect(FireflyMazeStaticLayer.BREADCRUMBS[0], rect, false)
		if index <= _stage_index:
			var alpha := 0.75 if index == _stage_index else 0.45
			draw_texture_rect(FireflyTrailFlower.EMISSION[0], rect, false, Color(1.0, 0.92, 0.4, alpha))


func _art_scale() -> float:
	return minf(1.4, _cell_size / BASE_CELL_SIZE)


func _current_trail_tick() -> int:
	return maxi(0, int((Time.get_ticks_msec() - _trail_epoch_msec) / int(TRAIL_CLOCK_SECONDS * 1000.0)))


func _fade_due_tick(event: TrailEvent) -> int:
	return event.fade_start_tick + roundi(float(event.fade_step) * float(TRAIL_FADE_TICKS) / float(TRAIL_FADE_STEPS))


func _schedule_trail_event(event: TrailEvent, due_tick: int) -> void:
	if not _trail_events.has(due_tick):
		_trail_events[due_tick] = []
	var events: Array = _trail_events[due_tick]
	events.append(event)
	if not _processing_trail_events:
		_arm_trail_timer()


func _arm_trail_timer() -> void:
	if _trail_events.is_empty():
		_trail_timer.stop()
		return
	var next_tick := -1
	for due_value in _trail_events:
		var due_tick: int = due_value
		if next_tick < 0 or due_tick < next_tick:
			next_tick = due_tick
	var ticks_until_due := maxi(0, next_tick - _current_trail_tick())
	_trail_timer.start(maxf(0.001, float(ticks_until_due) * TRAIL_CLOCK_SECONDS))


func _on_trail_timer_timeout() -> void:
	_process_due_trail_events(_current_trail_tick())
	_arm_trail_timer()


func _process_due_trail_events(current_tick: int) -> void:
	_processing_trail_events = true
	while true:
		var due_tick := -1
		for due_value in _trail_events:
			var candidate_tick: int = due_value
			if candidate_tick <= current_tick and (due_tick < 0 or candidate_tick < due_tick):
				due_tick = candidate_tick
		if due_tick < 0:
			break
		var events: Array = _trail_events[due_tick]
		_trail_events.erase(due_tick)
		for event_value in events:
			var event := event_value as TrailEvent
			if event == null or _trail_generations.get(event.cell, -1) != event.generation:
				continue
			var flower: FireflyTrailFlower = _trail_flowers.get(event.cell) as FireflyTrailFlower
			if flower == null:
				continue
			_trail_transition_count += 1
			flower.set_quantized_alpha(event.fade_step, TRAIL_FADE_STEPS)
			if event.fade_step >= TRAIL_FADE_STEPS:
				_trail_flowers.erase(event.cell)
				_trail_generations.erase(event.cell)
				flower.queue_free()
				continue
			event.fade_step += 1
			_schedule_trail_event(event, _fade_due_tick(event))
	_processing_trail_events = false


func _clear_trail() -> void:
	_trail_timer.stop()
	_trail_events.clear()
	_trail_generations.clear()
	for flower: FireflyTrailFlower in _trail_flowers.values():
		flower.queue_free()
	_trail_flowers.clear()


func _finish_wall_bump() -> void:
	_wall_bump_age = -1.0
	queue_redraw()


func _make_candidate_stages() -> Array[MazeStage]:
	return [
		_make_stage_from_polylines("light", Vector2i(7, 4), [Vector2i(0, 0), Vector2i(6, 0), Vector2i(6, 2), Vector2i(3, 2), Vector2i(3, 1), Vector2i(0, 1), Vector2i(0, 3), Vector2i(1, 3), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 3), Vector2i(6, 3)], [[Vector2i(3, 1), Vector2i(5, 1)]]),
		_make_stage_from_polylines("medium", Vector2i(9, 5), [Vector2i(0, 2), Vector2i(6, 2), Vector2i(6, 1), Vector2i(0, 1), Vector2i(0, 0), Vector2i(8, 0), Vector2i(8, 3), Vector2i(1, 3), Vector2i(1, 4), Vector2i(8, 4)], [[Vector2i(1, 4), Vector2i(0, 4), Vector2i(0, 3)], [Vector2i(7, 3), Vector2i(7, 1)]]),
		_make_stage_from_polylines("final", Vector2i(11, 7), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 6), Vector2i(8, 6), Vector2i(8, 5), Vector2i(2, 5), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 0), Vector2i(6, 0), Vector2i(6, 3), Vector2i(3, 3), Vector2i(3, 4), Vector2i(7, 4), Vector2i(7, 0), Vector2i(10, 0), Vector2i(10, 1), Vector2i(8, 1), Vector2i(8, 4), Vector2i(10, 4), Vector2i(10, 6), Vector2i(9, 6)], [[Vector2i(10, 4), Vector2i(10, 2), Vector2i(9, 2), Vector2i(9, 3)], [Vector2i(5, 3), Vector2i(5, 1)]]),
	]


func _make_stage_from_polylines(stage_name: String, authored_size: Vector2i, main_polyline: Array[Vector2i], dead_end_polylines: Array[Array]) -> MazeStage:
	var stage := MazeStage.new()
	stage.stage_name = stage_name
	stage.main_polyline = main_polyline
	stage.dead_end_polylines = dead_end_polylines
	stage.rows = _rows_from_polylines(authored_size, main_polyline, dead_end_polylines)
	stage.start_cell = main_polyline.front() * 2
	stage.house_cell = main_polyline.back() * 2
	return stage


func _rows_from_polylines(authored_size: Vector2i, main_polyline: Array[Vector2i], dead_end_polylines: Array[Array]) -> Array[String]:
	var fine_size := authored_size * 2 - Vector2i.ONE
	var grid: Array[Array] = []
	for y in fine_size.y:
		var row: Array[String] = []
		row.resize(fine_size.x)
		row.fill("#")
		grid.append(row)
	_mark_polyline_walkable(grid, main_polyline)
	for branch: Array in dead_end_polylines:
		_mark_polyline_walkable(grid, _typed_polyline(branch))
	var rows: Array[String] = []
	for row: Array in grid:
		var text := ""
		for cell: String in row:
			text += cell
		rows.append(text)
	return rows


func _mark_polyline_walkable(grid: Array[Array], polyline: Array[Vector2i]) -> void:
	for authored_cell in _expand_polyline(polyline):
		var fine_cell := authored_cell * 2
		grid[fine_cell.y][fine_cell.x] = "."
	for point_index in range(polyline.size() - 1):
		var start := polyline[point_index] * 2
		var end := polyline[point_index + 1] * 2
		var direction := Vector2i(signi(end.x - start.x), signi(end.y - start.y))
		var point := start
		while point != end:
			grid[point.y][point.x] = "."
			point += direction
		grid[end.y][end.x] = "."


func _expand_polyline(polyline: Array[Vector2i]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if polyline.is_empty():
		return cells
	cells.append(polyline[0])
	for point_index in range(polyline.size() - 1):
		var start := polyline[point_index]
		var end := polyline[point_index + 1]
		var direction := Vector2i(signi(end.x - start.x), signi(end.y - start.y))
		var point := start
		while point != end:
			point += direction
			cells.append(point)
	return cells


func _typed_polyline(polyline: Array) -> Array[Vector2i]:
	var typed: Array[Vector2i] = []
	for point: Vector2i in polyline:
		typed.append(point)
	return typed


func _reference_path(polyline: Array[Vector2i]) -> PackedVector2Array:
	var path := PackedVector2Array()
	for authored_cell in _expand_polyline(polyline):
		path.append(_cell_center(authored_cell * 2))
	return path


func _validate_stage(stage: MazeStage) -> PackedStringArray:
	var errors := PackedStringArray()
	if stage.rows.is_empty():
		errors.append("%s has no rows." % stage.stage_name)
		return errors
	var width := stage.rows[0].length()
	if width == 0:
		errors.append("%s has an empty row." % stage.stage_name)
	for row in stage.rows:
		if row.length() != width:
			errors.append("%s is not rectangular." % stage.stage_name)
		if row.replace("#", "").replace(".", "").length() > 0:
			errors.append("%s has an unsupported cell." % stage.stage_name)
	if not _is_cell_walkable_in_stage(stage, stage.start_cell) or not _is_cell_walkable_in_stage(stage, stage.house_cell):
		errors.append("%s has a blocked endpoint." % stage.stage_name)
	elif not _has_walkable_path(stage):
		errors.append("%s has no path from firefly to house." % stage.stage_name)
	return errors


func _is_cell_walkable_in_stage(stage: MazeStage, cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < stage.rows.size() and cell.x >= 0 and cell.x < stage.rows[cell.y].length() and stage.rows[cell.y].substr(cell.x, 1) == "."


func _has_walkable_path(stage: MazeStage) -> bool:
	var pending: Array[Vector2i] = [stage.start_cell]
	var seen: Dictionary[Vector2i, bool] = {stage.start_cell: true}
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if cell == stage.house_cell:
			return true
		var directions: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		for direction: Vector2i in directions:
			var neighbor: Vector2i = cell + direction
			if _is_cell_walkable_in_stage(stage, neighbor) and not seen.has(neighbor):
				seen[neighbor] = true
				pending.append(neighbor)
	return false
