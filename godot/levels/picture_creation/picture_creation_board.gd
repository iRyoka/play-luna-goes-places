class_name PictureCreationBoard
extends Node2D

signal dot_connected
signal trace_stage_completed(stage_index: int)
signal coloring_started
signal coloring_completed

# These reference margins become relative to the real Gameplay control size at
# runtime, keeping the same gesture-safe proportion on every landscape screen.
const TRACE_SAFE_MARGIN_FRACTION := Vector2(80.0 / 2160.0, 80.0 / 1080.0)
const MAX_FOCUS_SCALE := 12.5
const SCREEN_TRACE_TOUCH_RADIUS := 42.0
const MIN_SCREEN_TRACE_TOUCH_RADIUS := 18.0
const TRACE_TOUCH_SPACING_FRACTION := 0.36
const SCREEN_DOT_RADIUS := 36.0
const SCREEN_MARKER_RADIUS := 50.0
const TRACE_FOCUS_MARKER_PADDING := SCREEN_MARKER_RADIUS
const SCREEN_NUMBER_FONT_SIZE := 48
const MIN_SCREEN_DOT_SPACING := 180.0
const BETWEEN_STAGE_ZOOM_DURATION := 1.15
const BETWEEN_STAGE_PAUSE_DURATION := 0.35
# The whole picture is presented before the first detail is zoomed in, so the child
# sees what is missing from it rather than starting inside a close-up.
const OPENING_HOLD_DURATION := 3.5
const OUTLINE_COLOR := Color("#513d4b")
const DOT_COLOR := Color("#8f7c87")
const CURRENT_DOT_COLOR := Color("#e76f51")
const NEXT_DOT_COLOR := Color("#f4a261")
# A fill region this small cannot be tapped accurately, so it receives an
# invisible margin around its painted shape and is tested before larger regions.
const SMALL_REGION_AREA := 6000.0
const SMALL_REGION_TOUCH_MARGIN := 30.0
const CARVE_PIECE_LIMIT := 4096
# A region counts as enclosed by another when most of its area lies inside it.
const NESTED_OVERLAP_RATIO := 0.5

@export var configuration: PictureCreationConfiguration

var _stage_index := 0
var _reached_dot_index := 0
var _completed_stage_count := 0
var _is_tracing := false
var _is_transitioning := false
# Purely visual: the cue is hidden while the picture is presented and while the board
# travels between details. Its sizes are screen-relative and only correct once the
# board has arrived, and a zoom tween moves the board without redrawing it.
var _cue_suspended := false
var _is_coloring := false
var _selected_color_index := 0
var _pointer_position := Vector2.ZERO
var _number_hint_index := -1
var _number_hint_progress := 0.0
var _number_two_hint_played := false
var _closing_stage_index := -1
var _closing_reveal_progress := 0.0
var _awaiting_origin_completion := false
var _dashed_active_points := PackedVector2Array()
var _dashed_origin_index := -1
var _dashed_direction := 0
var _filled_regions: Array[bool] = []
var _region_colors: Array[Color] = []
# Painted geometry per region: its polygon minus the regions nested inside it,
# resolved once as triangles so a fill never floods through an enclosed detail.
var _region_triangles: Array[PackedVector2Array] = []
var _region_hit_polygons: Array[PackedVector2Array] = []
var _region_hit_order: Array[int] = []
var _trace_stages: Array[PictureTraceStage] = []


func _ready() -> void:
	assert(configuration != null and configuration.is_valid())
	_prepare_randomized_trace_stages()
	for region: PictureColorRegion in configuration.color_regions:
		_filled_regions.append(false)
		_region_colors.append(Color.WHITE)
	_build_region_geometry()
	# Closed from the moment the board exists: it owes the child a look at the whole
	# picture before anything can be traced.
	_is_transitioning = true
	_cue_suspended = true
	queue_redraw()
	call_deferred("_present_picture")


## Hold on the full picture, then travel into the first detail. Input stays closed
## until its cue is on screen: the dots are not visible yet, and a press accepted
## during the hold would run a trace the child cannot see.
func _present_picture() -> void:
	_is_transitioning = true
	_cue_suspended = true
	queue_redraw()
	await get_tree().create_timer(OPENING_HOLD_DURATION).timeout
	await _focus_active_stage()


func _prepare_randomized_trace_stages() -> void:
	var random := RandomNumberGenerator.new()
	random.randomize()
	for stage: PictureTraceStage in configuration.trace_stages:
		_trace_stages.append(stage.randomized_copy(random))
	_trace_stages.shuffle()
	_deal_cue_modes()


func _build_region_geometry() -> void:
	var areas: Array[float] = []
	for region_index: int in configuration.color_regions.size():
		var polygon := configuration.color_regions[region_index].polygon
		var area := _polygon_area(polygon)
		areas.append(area)
		_region_triangles.append(_triangulate_carved_region(polygon, _nested_polygons(region_index)))
		_region_hit_polygons.append(_region_hit_polygon(polygon, area))
		_region_hit_order.append(region_index)
	# Small regions are tested first so a generous margin around a detail cannot be
	# swallowed by the large region that encloses it.
	_region_hit_order.sort_custom(func(first: int, second: int) -> bool: return areas[first] < areas[second])


func _nested_polygons(region_index: int) -> Array[PackedVector2Array]:
	var outer := configuration.color_regions[region_index].polygon
	var nested: Array[PackedVector2Array] = []
	for other_index: int in configuration.color_regions.size():
		if other_index == region_index:
			continue
		var candidate := configuration.color_regions[other_index].polygon
		if _overlap_ratio(candidate, outer) > NESTED_OVERLAP_RATIO:
			nested.append(candidate)
	return nested


## How much of one region lies inside another, measured as real overlapping area.
## Neighbouring faces of the same outline share vertices and whole edges, so a
## vertex-containment test would mistake an adjacent face for an enclosed one.
func _overlap_ratio(inner: PackedVector2Array, outer: PackedVector2Array) -> float:
	var inner_area := _polygon_area(inner)
	if inner_area <= 0.0:
		return 0.0
	var overlap := 0.0
	for part: PackedVector2Array in Geometry2D.intersect_polygons(inner, outer):
		overlap += _polygon_area(part) * (-1.0 if Geometry2D.is_polygon_clockwise(part) else 1.0)
	return overlap / inner_area


func _triangulate_carved_region(outer: PackedVector2Array, holes: Array[PackedVector2Array]) -> PackedVector2Array:
	var triangles := PackedVector2Array()
	var pending := _ear_clipped(outer)
	var guard := 0
	while not pending.is_empty():
		guard += 1
		if guard > CARVE_PIECE_LIMIT:
			push_error("Carving a picture fill region did not converge.")
			break
		var piece: PackedVector2Array = pending.pop_back()
		var parts: Array[PackedVector2Array] = [piece]
		var enclosing_hole := -1
		for hole_index: int in holes.size():
			var remaining: Array[PackedVector2Array] = []
			for part: PackedVector2Array in parts:
				var rings := Geometry2D.clip_polygons(part, holes[hole_index])
				if _has_ring_hole(rings):
					# The hole floats entirely inside this part, so subtraction leaves a
					# ring that no simple polygon can express. Split and retry instead.
					enclosing_hole = hole_index
					break
				for ring: PackedVector2Array in rings:
					if ring.size() >= 3:
						remaining.append(ring)
			if enclosing_hole >= 0:
				break
			parts = remaining
		if enclosing_hole >= 0:
			# Split the piece through a point inside that hole. The hole then meets the
			# boundary of every sub-piece, so plain subtraction resolves it.
			var split_point := _interior_point(holes[enclosing_hole])
			for corner_index: int in piece.size():
				pending.append(PackedVector2Array([piece[corner_index], piece[(corner_index + 1) % piece.size()], split_point]))
			continue
		for part: PackedVector2Array in parts:
			triangles.append_array(_triangle_soup(part))
	return triangles


func _has_ring_hole(rings: Array[PackedVector2Array]) -> bool:
	for ring: PackedVector2Array in rings:
		if Geometry2D.is_polygon_clockwise(ring):
			return true
	return false


func _ear_clipped(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	var triangles: Array[PackedVector2Array] = []
	var indices := Geometry2D.triangulate_polygon(polygon)
	for base: int in range(0, indices.size(), 3):
		triangles.append(PackedVector2Array([polygon[indices[base]], polygon[indices[base + 1]], polygon[indices[base + 2]]]))
	return triangles


func _triangle_soup(polygon: PackedVector2Array) -> PackedVector2Array:
	var soup := PackedVector2Array()
	for triangle: PackedVector2Array in _ear_clipped(polygon):
		soup.append_array(triangle)
	return soup


## A point that is genuinely inside the polygon, including a concave one, so
## splitting through it always meets the polygon's interior.
func _interior_point(polygon: PackedVector2Array) -> Vector2:
	var triangles := _ear_clipped(polygon)
	if triangles.is_empty():
		return get_polygon_center(polygon)
	return (triangles[0][0] + triangles[0][1] + triangles[0][2]) / 3.0


## Painted shapes stay exactly as drawn; only the invisible tap area of a small
## region grows, so a detail such as the nose is reachable without a colour halo.
func _region_hit_polygon(polygon: PackedVector2Array, area: float) -> PackedVector2Array:
	if area >= SMALL_REGION_AREA:
		return polygon
	var expanded := Geometry2D.offset_polygon(polygon, SMALL_REGION_TOUCH_MARGIN)
	if expanded.is_empty():
		return polygon
	return expanded[0]


func _polygon_area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for index: int in polygon.size():
		var current := polygon[index]
		var next := polygon[(index + 1) % polygon.size()]
		total += current.x * next.y - next.x * current.y
	return absf(total) * 0.5


## Which detail carries which cue is dealt fresh each run rather than authored, so a
## child does not always meet numbers on the same part of the picture. Closure is a
## property of the contour, not of its cue, so every pairing is playable. A picture
## whose detail count differs from the number of cues keeps its authored modes.
func _deal_cue_modes() -> void:
	var modes: Array[PictureTraceStage.CueMode] = [
		PictureTraceStage.CueMode.NEXT_DOT,
		PictureTraceStage.CueMode.NUMBERED_DOTS,
		PictureTraceStage.CueMode.DASHED_PATH,
	]
	if _trace_stages.size() != modes.size():
		return
	modes.shuffle()
	for index: int in _trace_stages.size():
		_trace_stages[index].cue_mode = modes[index]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_handle_press(to_local(touch.position))
		else:
			_end_trace()
	elif event is InputEventScreenDrag:
		_handle_drag(to_local((event as InputEventScreenDrag).position))
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_handle_press(to_local(mouse_button.position))
			else:
				_end_trace()
	elif event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_handle_drag(to_local(mouse_motion.position))


func get_active_stage_points() -> PackedVector2Array:
	if _stage_index >= _trace_stages.size():
		return PackedVector2Array()
	if get_active_cue_mode() == PictureTraceStage.CueMode.DASHED_PATH and not _dashed_active_points.is_empty():
		return _dashed_active_points
	return _trace_stages[_stage_index].points


## The detail being traced, or null once the picture moves on to coloring.
func get_active_stage() -> PictureTraceStage:
	if _stage_index >= _trace_stages.size():
		return null
	return _trace_stages[_stage_index]


func get_active_cue_mode() -> PictureTraceStage.CueMode:
	if _stage_index >= _trace_stages.size():
		return PictureTraceStage.CueMode.NEXT_DOT
	return _trace_stages[_stage_index].cue_mode


func get_active_marker_index() -> int:
	# The marker is a property of the cue, not of the contour. Numbered dots carry
	# their order in the numbers themselves and deliberately add no persistent
	# marker, including for a closing segment back to dot one.
	if _stage_index >= _trace_stages.size() or get_active_cue_mode() == PictureTraceStage.CueMode.NUMBERED_DOTS:
		return -1
	if _awaiting_origin_completion:
		return 0
	var points := get_active_stage_points()
	if _is_tracing and _reached_dot_index + 1 < points.size():
		return _reached_dot_index + 1
	return _reached_dot_index


func get_trace_touch_radius() -> float:
	var points := get_active_stage_points()
	var nearest_spacing := INF
	for point_index: int in range(points.size() - 1):
		nearest_spacing = minf(nearest_spacing, points[point_index].distance_to(points[point_index + 1]) * _screen_scale())
	if _trace_stages[_stage_index].requires_origin_completion:
		nearest_spacing = minf(nearest_spacing, points[-1].distance_to(points[0]) * _screen_scale())
	var capped_screen_radius := minf(SCREEN_TRACE_TOUCH_RADIUS, nearest_spacing * TRACE_TOUCH_SPACING_FRACTION)
	return maxf(MIN_SCREEN_TRACE_TOUCH_RADIUS, capped_screen_radius) / _screen_scale()


func has_readable_active_spacing() -> bool:
	var points := get_active_stage_points()
	for point_index: int in range(points.size() - 1):
		if points[point_index].distance_to(points[point_index + 1]) * _screen_scale() < MIN_SCREEN_DOT_SPACING:
			return false
	if _trace_stages[_stage_index].requires_origin_completion and points[-1].distance_to(points[0]) * _screen_scale() < MIN_SCREEN_DOT_SPACING:
		return false
	return true


## Whether the board is presenting or travelling rather than waiting for a touch.
func is_ready_for_trace() -> bool:
	return not _is_transitioning and not _is_coloring


func get_completed_stage_count() -> int:
	return _completed_stage_count


func is_trace_contour_revealed(stage_index: int) -> bool:
	return stage_index >= 0 and stage_index < _completed_stage_count


func is_coloring() -> bool:
	return _is_coloring


func get_filled_region_count() -> int:
	var count := 0
	for is_filled: bool in _filled_regions:
		if is_filled:
			count += 1
	return count


func get_palette_position(color_index: int) -> Vector2:
	var column := color_index % configuration.palette_columns
	var row := color_index / configuration.palette_columns
	return configuration.palette_origin + Vector2(configuration.palette_spacing.x * column, configuration.palette_spacing.y * row)


func get_color_region_center(region_index: int) -> Vector2:
	return get_polygon_center(configuration.color_regions[region_index].polygon)


func get_polygon_center(polygon: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	return center / polygon.size()


func get_color_region_count() -> int:
	return configuration.color_regions.size()


## Region a tap belongs to, smallest first so an enclosed detail wins over the
## region around it. Returns -1 when the tap is outside every region.
func find_region_at(position: Vector2) -> int:
	for region_index: int in _region_hit_order:
		if Geometry2D.is_point_in_polygon(position, _region_hit_polygons[region_index]):
			return region_index
	return -1


func get_region_fill_triangles(region_index: int) -> PackedVector2Array:
	return _region_triangles[region_index]


## Area actually painted for a region: the sum of its resolved triangles.
func get_region_painted_area(region_index: int) -> float:
	var triangles := _region_triangles[region_index]
	var total := 0.0
	for base: int in range(0, triangles.size(), 3):
		total += _polygon_area(triangles.slice(base, base + 3))
	return total


## Area a region should paint: its own polygon minus the outermost regions nested
## inside it. A hole inside another hole is already excluded by its parent.
func get_region_carved_area(region_index: int) -> float:
	var nested := _nested_polygons(region_index)
	var total := _polygon_area(configuration.color_regions[region_index].polygon)
	for hole_index: int in nested.size():
		var is_inner_hole := false
		for other_index: int in nested.size():
			if other_index != hole_index and _overlap_ratio(nested[hole_index], nested[other_index]) > NESTED_OVERLAP_RATIO:
				is_inner_hole = true
				break
		if not is_inner_hole:
			total -= _polygon_area(nested[hole_index])
	return total


func begin_trace_at(position: Vector2) -> bool:
	if _is_transitioning or _is_coloring or _stage_index >= _trace_stages.size():
		return false
	if get_active_cue_mode() == PictureTraceStage.CueMode.DASHED_PATH:
		return _begin_dashed_trace(position)
	var points := get_active_stage_points()
	var start_point := points[-1] if _awaiting_origin_completion else points[_reached_dot_index]
	if position.distance_to(start_point) > get_trace_touch_radius():
		return false
	_is_tracing = true
	_pointer_position = position
	if get_active_cue_mode() == PictureTraceStage.CueMode.NUMBERED_DOTS and _reached_dot_index == 0 and not _number_two_hint_played:
		_number_two_hint_played = true
		_play_number_hint(1)
	queue_redraw()
	return true


func advance_trace_to(position: Vector2) -> bool:
	if not _is_tracing or _is_transitioning or _is_coloring:
		return false
	if get_active_cue_mode() == PictureTraceStage.CueMode.DASHED_PATH:
		return _advance_dashed_trace(position)
	_pointer_position = position
	var points := get_active_stage_points()
	if _awaiting_origin_completion:
		if position.distance_to(points[0]) > get_trace_touch_radius():
			queue_redraw()
			return false
		_awaiting_origin_completion = false
		_complete_active_stage()
		return true
	var next_index := _reached_dot_index + 1
	if next_index >= points.size() or position.distance_to(points[next_index]) > get_trace_touch_radius():
		queue_redraw()
		return false
	_reached_dot_index = next_index
	dot_connected.emit()
	queue_redraw()
	if _reached_dot_index == points.size() - 1:
		if _trace_stages[_stage_index].requires_origin_completion:
			_awaiting_origin_completion = true
			queue_redraw()
			return true
		_complete_active_stage()
	return true


func select_color_at(position: Vector2) -> bool:
	if not _is_coloring:
		return false
	for color_index: int in configuration.palette.size():
		if position.distance_to(get_palette_position(color_index)) <= configuration.palette_touch_radius:
			_selected_color_index = color_index
			queue_redraw()
			return true
	return false


func fill_region_at(position: Vector2) -> bool:
	if not _is_coloring or _is_transitioning:
		return false
	var region_index := find_region_at(position)
	if region_index < 0:
		return false
	_filled_regions[region_index] = true
	_region_colors[region_index] = configuration.palette[_selected_color_index]
	queue_redraw()
	if get_filled_region_count() == configuration.color_regions.size():
		_is_transitioning = true
		coloring_completed.emit()
	return true


func _handle_press(position: Vector2) -> void:
	if _is_coloring:
		if not select_color_at(position):
			fill_region_at(position)
		return
	begin_trace_at(position)


func _handle_drag(position: Vector2) -> void:
	advance_trace_to(position)


func _end_trace() -> void:
	if not _is_tracing:
		return
	_is_tracing = false
	queue_redraw()


func _complete_active_stage() -> void:
	_finish_active_stage()


func _finish_active_stage() -> void:
	_is_tracing = false
	_is_transitioning = true
	var stage := _trace_stages[_stage_index]
	if stage.close_outline_after_last_dot:
		_closing_stage_index = _stage_index
		var reveal := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		reveal.tween_method(_set_closing_reveal_progress, 0.0, 1.0, 0.55)
		await reveal.finished
		_closing_stage_index = -1
		queue_redraw()
	_completed_stage_count += 1
	trace_stage_completed.emit(_stage_index)
	queue_redraw()
	_continue_after_stage_reveal()


func _continue_after_stage_reveal() -> void:
	var pulse := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pulse.tween_property(self, "scale", scale * 1.07, 0.14)
	pulse.tween_property(self, "scale", scale, 0.16)
	await pulse.finished
	if _completed_stage_count < _trace_stages.size():
		await _zoom_out_between_stages()
		await get_tree().create_timer(BETWEEN_STAGE_PAUSE_DURATION).timeout
		_stage_index += 1
		_reached_dot_index = 0
		_awaiting_origin_completion = false
		_dashed_active_points = PackedVector2Array()
		_dashed_origin_index = -1
		_dashed_direction = 0
		await _focus_active_stage()
		return
	await _return_to_full_picture()


func _focus_active_stage() -> void:
	# Redraw immediately: a zoom tween changes the transform without redrawing, so
	# whatever the cue last drew would simply be rasterised four times larger.
	_cue_suspended = true
	queue_redraw()
	var stage := _trace_stages[_stage_index]
	var focus_scale := _focus_scale_for(stage)
	var target_position: Vector2 = _focus_position_for(stage, focus_scale)
	var zoom := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	zoom.set_parallel(true)
	zoom.tween_property(self, "scale", Vector2.ONE * focus_scale, BETWEEN_STAGE_ZOOM_DURATION)
	zoom.tween_property(self, "position", target_position, BETWEEN_STAGE_ZOOM_DURATION)
	await zoom.finished
	_cue_suspended = false
	_is_transitioning = false
	_number_two_hint_played = false
	if stage.cue_mode == PictureTraceStage.CueMode.NUMBERED_DOTS:
		_play_number_hint(0)
	queue_redraw()


func _zoom_out_between_stages() -> void:
	_cue_suspended = true
	queue_redraw()
	var zoom := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	zoom.set_parallel(true)
	zoom.tween_property(self, "scale", Vector2.ONE, BETWEEN_STAGE_ZOOM_DURATION)
	zoom.tween_property(self, "position", Vector2.ZERO, BETWEEN_STAGE_ZOOM_DURATION)
	await zoom.finished


func _return_to_full_picture() -> void:
	var zoom := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	zoom.set_parallel(true)
	zoom.tween_property(self, "scale", Vector2.ONE, 0.42)
	zoom.tween_property(self, "position", Vector2.ZERO, 0.42)
	await zoom.finished
	_cue_suspended = false
	_is_coloring = true
	_is_transitioning = false
	coloring_started.emit()
	queue_redraw()


func _draw() -> void:
	if configuration.background_art != null:
		draw_texture_rect(configuration.background_art, Rect2(Vector2.ZERO, configuration.reference_size), false)
	if configuration.paper_field_color.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, configuration.reference_size), configuration.paper_field_color)
	if configuration.base_art != null:
		draw_texture_rect(configuration.base_art, Rect2(Vector2.ZERO, configuration.reference_size), false)
	for region_index: int in configuration.color_regions.size():
		var region := configuration.color_regions[region_index]
		if _filled_regions[region_index]:
			_draw_region_fill(region_index)
		if configuration.outline_art == null and _should_draw_region_outline(region.id):
			draw_polyline(_closed_polygon(region.polygon), OUTLINE_COLOR, 12.0)
	var outline_texture := configuration.coloring_outline_art if _is_coloring and configuration.coloring_outline_art != null else configuration.outline_art
	if outline_texture != null:
		draw_texture_rect(outline_texture, Rect2(Vector2.ZERO, configuration.reference_size), false)
	else:
		_draw_temporary_cat_details()
	# The matting frames the workspace, so it appears with the cue rather than over
	# the presented picture or over a board still on its way.
	if not _is_coloring and not _is_transitioning and not _cue_suspended and _stage_index < _trace_stages.size():
		_draw_focus_dim()
	if not _is_coloring:
		for completed_index: int in _completed_stage_count:
			_draw_completed_trace(_trace_stages[completed_index])
	# Dots, numbers and dashes are sized in screen pixels so that zooming spreads a
	# contour without making its targets easier to hit. That holds only once the
	# board has reached its zoom: drawn over the full picture they are four times
	# too large for it, so the cue waits until its workspace is in place.
	if not _is_coloring and not _is_transitioning and not _cue_suspended and _stage_index < _trace_stages.size():
		_draw_active_trace()
	if _closing_stage_index >= 0:
		_draw_closing_reveal(_trace_stages[_closing_stage_index])
	if _is_coloring:
		_draw_palette()


func _draw_region_fill(region_index: int) -> void:
	var triangles := _region_triangles[region_index]
	var color := _region_colors[region_index]
	for base: int in range(0, triangles.size(), 3):
		draw_colored_polygon(triangles.slice(base, base + 3), color)


func _draw_temporary_cat_details() -> void:
	draw_arc(Vector2(1400.0, 590.0), 260.0, -0.15, 1.2, 30, OUTLINE_COLOR, 18.0)
	draw_circle(Vector2(900.0, 410.0), 18.0, OUTLINE_COLOR)
	draw_circle(Vector2(1050.0, 410.0), 18.0, OUTLINE_COLOR)
	draw_line(Vector2(945.0, 480.0), Vector2(1000.0, 480.0), OUTLINE_COLOR, 8.0)


func _draw_focus_dim() -> void:
	var focus_rect := _screen_rect_to_local(_trace_safe_rect())
	var full_rect := Rect2(Vector2(-1000.0, -1000.0), Vector2(4160.0, 3080.0))
	draw_rect(Rect2(full_rect.position, Vector2(full_rect.size.x, focus_rect.position.y - full_rect.position.y)), configuration.trace_fade_color)
	draw_rect(Rect2(Vector2(full_rect.position.x, focus_rect.end.y), Vector2(full_rect.size.x, full_rect.end.y - focus_rect.end.y)), configuration.trace_fade_color)
	draw_rect(Rect2(Vector2(full_rect.position.x, focus_rect.position.y), Vector2(focus_rect.position.x - full_rect.position.x, focus_rect.size.y)), configuration.trace_fade_color)
	draw_rect(Rect2(Vector2(focus_rect.end.x, focus_rect.position.y), Vector2(full_rect.end.x - focus_rect.end.x, focus_rect.size.y)), configuration.trace_fade_color)
	draw_rect(focus_rect, Color(NEXT_DOT_COLOR, 0.13), false, 10.0)


func _should_draw_region_outline(region_id: StringName) -> bool:
	for trace_index: int in _trace_stages.size():
		if _trace_stages[trace_index].id == region_id:
			return is_trace_contour_revealed(trace_index)
	return true


func _draw_completed_trace(stage: PictureTraceStage) -> void:
	_draw_trace_line(stage.points, OUTLINE_COLOR, 12.0)
	if stage.close_outline_after_last_dot or stage.requires_origin_completion:
		draw_line(stage.points[-1], stage.points[0], OUTLINE_COLOR, 12.0)
	for segment: PackedVector2Array in stage.deferred_reveal_segments:
		if segment.size() == 2:
			draw_line(segment[0], segment[1], OUTLINE_COLOR, 12.0)


func _draw_closing_reveal(stage: PictureTraceStage) -> void:
	var from := stage.points[-1]
	var to := from.lerp(stage.points[0], _closing_reveal_progress)
	draw_line(from, to, OUTLINE_COLOR, 12.0 / _screen_scale())


func _set_closing_reveal_progress(value: float) -> void:
	_closing_reveal_progress = value
	queue_redraw()


func _draw_active_trace() -> void:
	var stage := _trace_stages[_stage_index]
	var points := stage.points
	if stage.cue_mode == PictureTraceStage.CueMode.DASHED_PATH:
		_draw_dashed_trace(points, stage.requires_origin_completion)
		points = get_active_stage_points()
	_draw_trace_line(_reached_points(points), CURRENT_DOT_COLOR, 18.0 / _screen_scale())
	if _is_tracing:
		draw_line(points[_reached_dot_index], _pointer_position, CURRENT_DOT_COLOR, 12.0 / _screen_scale())
	var marker_index := get_active_marker_index()
	for point_index: int in points.size():
		var point := points[point_index]
		if stage.cue_mode == PictureTraceStage.CueMode.NUMBERED_DOTS:
			# The disc behind a number stays opaque even when the level leaves its paper
			# to background artwork, so the glyph never sits straight on the picture.
			var disc_color := Color(configuration.paper_field_color, 1.0)
			draw_circle(point, SCREEN_DOT_RADIUS / _screen_scale(), disc_color)
			draw_arc(point, SCREEN_DOT_RADIUS / _screen_scale(), 0.0, TAU, 24, OUTLINE_COLOR, 5.0 / _screen_scale())
		else:
			draw_circle(point, SCREEN_DOT_RADIUS / _screen_scale(), DOT_COLOR)
		if point_index == marker_index:
			draw_circle(point, SCREEN_MARKER_RADIUS / _screen_scale(), Color(CURRENT_DOT_COLOR, 0.22))
			draw_arc(point, (SCREEN_MARKER_RADIUS - 8.0) / _screen_scale(), 0.0, TAU, 24, CURRENT_DOT_COLOR, 6.0 / _screen_scale())
		if stage.cue_mode == PictureTraceStage.CueMode.NUMBERED_DOTS:
			_draw_number_label(point, str(point_index + 1))
	if _number_hint_index >= 0:
		_draw_number_hint(points[_number_hint_index])


func _play_number_hint(point_index: int) -> void:
	_number_hint_index = point_index
	_number_hint_progress = 0.0
	var hint := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hint.tween_method(_set_number_hint_progress, 0.0, 1.0, 0.45)
	hint.finished.connect(func() -> void:
		_number_hint_index = -1
		queue_redraw()
	)


func _set_number_hint_progress(value: float) -> void:
	_number_hint_progress = value
	queue_redraw()


func _draw_number_hint(point: Vector2) -> void:
	var radius := lerpf(SCREEN_DOT_RADIUS + 6.0, SCREEN_MARKER_RADIUS + 18.0, _number_hint_progress) / _screen_scale()
	var alpha := 1.0 - _number_hint_progress
	draw_arc(point, radius, 0.0, TAU, 24, Color(NEXT_DOT_COLOR.r, NEXT_DOT_COLOR.g, NEXT_DOT_COLOR.b, alpha), 6.0 / _screen_scale())


func _draw_number_label(point: Vector2, value: String) -> void:
	# Cancel the board zoom for text so glyphs render at their intended screen size,
	# then centre the glyph in its dot the way the map's level medallions do.
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SCREEN_NUMBER_FONT_SIZE)
	var baseline := (font.get_ascent(SCREEN_NUMBER_FONT_SIZE) - font.get_descent(SCREEN_NUMBER_FONT_SIZE)) * 0.5
	draw_set_transform(point, 0.0, Vector2.ONE / _screen_scale())
	draw_string(font, Vector2(-text_size.x * 0.5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SCREEN_NUMBER_FONT_SIZE, OUTLINE_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _reached_points(points: PackedVector2Array) -> PackedVector2Array:
	var reached := PackedVector2Array()
	for point_index: int in _reached_dot_index + 1:
		reached.append(points[point_index])
	return reached


func _draw_trace_line(points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size() > 1:
		draw_polyline(points, color, width, true)


func _draw_dashed_trace(points: PackedVector2Array, closes: bool) -> void:
	for point_index: int in range(points.size() - 1):
		_draw_dashed_segment(points[point_index], points[point_index + 1])
	if closes:
		_draw_dashed_segment(points[-1], points[0])


func _draw_dashed_segment(from: Vector2, to: Vector2) -> void:
	var direction := from.direction_to(to)
	var distance := from.distance_to(to)
	var offset := 0.0
	while offset < distance:
		var end := minf(offset + 18.0 / _screen_scale(), distance)
		draw_line(from + direction * offset, from + direction * end, Color(DOT_COLOR, 0.45), 6.0 / _screen_scale())
		offset += 42.0 / _screen_scale()


func _begin_dashed_trace(position: Vector2) -> bool:
	var stage := _trace_stages[_stage_index]
	var source_points := stage.points
	if _awaiting_origin_completion:
		if position.distance_to(_dashed_active_points[-1]) > get_trace_touch_radius():
			return false
		_is_tracing = true
		_pointer_position = position
		queue_redraw()
		return true
	if not _dashed_active_points.is_empty():
		if position.distance_to(_dashed_active_points[_reached_dot_index]) > get_trace_touch_radius():
			return false
		_is_tracing = true
		_pointer_position = position
		queue_redraw()
		return true
	var selected_index := _find_touched_point(source_points, position)
	if selected_index < 0:
		return false
	if stage.requires_origin_completion:
		_dashed_origin_index = selected_index
		_dashed_active_points = PackedVector2Array([source_points[selected_index]])
		_dashed_direction = 0
	else:
		if selected_index != 0 and selected_index != source_points.size() - 1:
			return false
		_dashed_origin_index = selected_index
		_dashed_direction = 1 if selected_index == 0 else -1
		_dashed_active_points = _ordered_dashed_points(source_points, selected_index, _dashed_direction, false)
	_reached_dot_index = 0
	_is_tracing = true
	_pointer_position = position
	queue_redraw()
	return true


func _advance_dashed_trace(position: Vector2) -> bool:
	var stage := _trace_stages[_stage_index]
	_pointer_position = position
	if _awaiting_origin_completion:
		if position.distance_to(_dashed_active_points[0]) > get_trace_touch_radius():
			queue_redraw()
			return false
		_awaiting_origin_completion = false
		_complete_active_stage()
		return true
	if _dashed_direction == 0:
		var source_points := stage.points
		var forward_index := posmod(_dashed_origin_index + 1, source_points.size())
		var backward_index := posmod(_dashed_origin_index - 1, source_points.size())
		if position.distance_to(source_points[forward_index]) <= get_trace_touch_radius():
			_dashed_direction = 1
		elif position.distance_to(source_points[backward_index]) <= get_trace_touch_radius():
			_dashed_direction = -1
		else:
			queue_redraw()
			return false
		_dashed_active_points = _ordered_dashed_points(source_points, _dashed_origin_index, _dashed_direction, true)
		_reached_dot_index = 1
		dot_connected.emit()
		queue_redraw()
		return true
	var points := _dashed_active_points
	var next_index := _reached_dot_index + 1
	if next_index >= points.size() or position.distance_to(points[next_index]) > get_trace_touch_radius():
		queue_redraw()
		return false
	_reached_dot_index = next_index
	dot_connected.emit()
	queue_redraw()
	if _reached_dot_index == points.size() - 1:
		if stage.requires_origin_completion:
			_awaiting_origin_completion = true
			queue_redraw()
			return true
		_complete_active_stage()
	return true


func _find_touched_point(points: PackedVector2Array, position: Vector2) -> int:
	for point_index: int in points.size():
		if position.distance_to(points[point_index]) <= get_trace_touch_radius():
			return point_index
	return -1


func _ordered_dashed_points(points: PackedVector2Array, origin_index: int, direction: int, wraps: bool) -> PackedVector2Array:
	var ordered := PackedVector2Array()
	for offset: int in points.size():
		var index := origin_index + direction * offset
		if wraps:
			index = posmod(index, points.size())
		ordered.append(points[index])
	return ordered


func _focus_scale_for(stage: PictureTraceStage) -> float:
	var bounds := _trace_stage_bounds(stage)
	var usable_size := _trace_safe_rect().size - Vector2.ONE * TRACE_FOCUS_MARKER_PADDING * 2.0
	var scale := MAX_FOCUS_SCALE
	if bounds.size.x > 0.0:
		scale = minf(scale, usable_size.x / bounds.size.x)
	if bounds.size.y > 0.0:
		scale = minf(scale, usable_size.y / bounds.size.y)
	return maxf(scale, 1.0)


func _focus_position_for(stage: PictureTraceStage, focus_scale: float) -> Vector2:
	var bounds := _trace_stage_bounds(stage)
	return _trace_safe_rect().get_center() - bounds.get_center() * focus_scale


func _trace_stage_bounds(stage: PictureTraceStage) -> Rect2:
	var bounds := Rect2(stage.points[0], Vector2.ZERO)
	for point_index: int in range(1, stage.points.size()):
		bounds = bounds.expand(stage.points[point_index])
	return bounds


func _trace_safe_rect() -> Rect2:
	var gameplay := get_parent() as Control
	var screen_size := gameplay.size if gameplay != null else configuration.reference_size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		screen_size = configuration.reference_size
	var margins := screen_size * TRACE_SAFE_MARGIN_FRACTION
	return Rect2(margins, screen_size - margins * 2.0)


func _screen_rect_to_local(screen_rect: Rect2) -> Rect2:
	var screen_scale := _screen_scale()
	return Rect2((screen_rect.position - position) / screen_scale, screen_rect.size / screen_scale)


func _screen_scale() -> float:
	return maxf(absf(scale.x), 0.01)


func _closed_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var closed := polygon.duplicate()
	closed.append(polygon[0])
	return closed


func _draw_palette() -> void:
	for color_index: int in configuration.palette.size():
		var palette_position := get_palette_position(color_index)
		# The chosen color fills its pot to the brim and takes a dark rim, rather
		# than sitting on a ring that reads as a shadow inside the pot.
		if color_index == _selected_color_index:
			draw_circle(palette_position, configuration.palette_selected_radius, configuration.palette[color_index])
			draw_arc(palette_position, configuration.palette_selected_radius - 2.0, 0.0, TAU, 32, OUTLINE_COLOR, 5.0)
		else:
			draw_circle(palette_position, configuration.palette_swatch_radius, configuration.palette[color_index])
