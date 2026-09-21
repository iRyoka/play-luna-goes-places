class_name FlyingCollectorBoard
extends Control

signal collectible_collected(progress: int)
signal run_started
signal landing_completed
signal sound_requested(sound_id: StringName)

const REFERENCE_SIZE := Vector2(2160.0, 1080.0)
const SAFE_TOP := 210.0
const SAFE_BOTTOM := 870.0
const FLIER_X := 430.0
const LANDING_ZONE_X := 1420.0
const LANDING_ZONE_Y := 760.0
const REST_Y := 540.0
const SCROLL_SPEED := 235.0
const PHRASE_DURATION := 6.0
const ACTIVE_DURATION := 60.0
const COLLECTION_TARGET := 42
const COLLECTION_RADIUS := 128.0
const COLLECTIBLE_RADIUS := 42.0
const RETURN_DELAY := 0.28
const RETURN_SPEED := 2.2
const FLIER_SPRING_STIFFNESS := 28.0
const FLIER_SPRING_DAMPING := 10.6
const SAMPLE_SPACING := 155.0
const BACKGROUND: Texture2D = preload("res://assets/environments/chapter-01/flying-collector/sky-mountains-background.webp")
const LANDING_CLOUD: Texture2D = preload("res://assets/environments/chapter-01/flying-collector/landing-cloud.png")
const COLLECTIBLE: Texture2D = preload("res://assets/gameplay/flying-collector/collectible-blossom.png")
const LUNA_BODY: Texture2D = preload("res://assets/gameplay/flying-collector/luna-body.png")
const KITE: Texture2D = preload("res://assets/gameplay/flying-collector/kite.png")
const KITE_BOW: Texture2D = preload("res://assets/gameplay/flying-collector/kite-tail-bow.png")
const BASKET: Texture2D = preload("res://assets/gameplay/flying-collector/basket-base.png")
const PONYTAIL_LEFT: Texture2D = preload("res://assets/gameplay/flying-collector/ponytail-left.png")
const PONYTAIL_RIGHT: Texture2D = preload("res://assets/gameplay/flying-collector/ponytail-right.png")
const TOUCHDOWN_LUNA: Texture2D = preload("res://assets/gameplay/flying-collector/luna-touchdown.png")
const AMBIENT_CLOUDS: Array[Texture2D] = [
	preload("res://assets/environments/chapter-01/flying-collector/ambient-cloud-1.png"),
	preload("res://assets/environments/chapter-01/flying-collector/ambient-cloud-2.png"),
	preload("res://assets/environments/chapter-01/flying-collector/ambient-cloud-3.png"),
	preload("res://assets/environments/chapter-01/flying-collector/ambient-cloud-4.png"),
]
const PROGRESS_BLOSSOMS: Array[Texture2D] = [
	preload("res://assets/gameplay/flying-collector/blossom-01.png"),
	preload("res://assets/gameplay/flying-collector/blossom-02.png"),
	preload("res://assets/gameplay/flying-collector/blossom-03.png"),
	preload("res://assets/gameplay/flying-collector/blossom-04.png"),
	preload("res://assets/gameplay/flying-collector/blossom-05.png"),
	preload("res://assets/gameplay/flying-collector/blossom-06.png"),
]
const PROGRESS_MILESTONE := 7
const LANDING_PUFF_DURATION := 0.72
## The production puppet stays visually light in the open sky; collection keeps
## its established forgiving body-centered geometry at the original size.
const FLIER_ART_SCALE := 0.82
const TOUCHDOWN_ART_SCALE := 1.45

class FlightCollectible:
	var position := Vector2.ZERO
	var phrase_index := 0
	var collected := false
	var collected_age := -1.0

@export var deterministic_seed := 9901

var _rng := RandomNumberGenerator.new()
var _collectibles: Array[FlightCollectible] = []
var _phrase_names: Array[StringName] = []
var _phrase_center_offsets: Array[float] = []
var _running := false
var _input_enabled := true
var _landing := false
var _landing_pending := false
var _landing_emitted := false
var _landing_phase := 0
var _landing_zone_x := REFERENCE_SIZE.x + 220.0
var _landing_cutoff_x := INF
var _landing_settle_age := -1.0
var _flier_y := REST_Y
var _flier_velocity := 0.0
var _flier_x := FLIER_X
var _flier_x_velocity := 0.0
var _flier_target_x := FLIER_X
var _target_y := REST_Y
var _anchor_y := 0.0
var _anchor_target_y := REST_Y
var _active_pointer := -1
var _release_age := -1.0
var _active_age := 0.0
var _scroll_distance := 0.0
var _progress := 0
var _motion_age := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	reset_run()


func reset_run() -> void:
	_rng.seed = deterministic_seed
	_collectibles.clear()
	_phrase_names.clear()
	_phrase_center_offsets.clear()
	_running = false
	_input_enabled = true
	_landing = false
	_landing_pending = false
	_landing_emitted = false
	_landing_phase = 0
	_landing_zone_x = REFERENCE_SIZE.x + 220.0
	_landing_cutoff_x = INF
	_landing_settle_age = -1.0
	_flier_y = REST_Y
	_flier_velocity = 0.0
	_flier_x = FLIER_X
	_flier_x_velocity = 0.0
	_flier_target_x = FLIER_X
	_target_y = REST_Y
	_active_pointer = -1
	_release_age = -1.0
	_active_age = 0.0
	_scroll_distance = 0.0
	_progress = 0
	_motion_age = 0.0
	_generate_run()
	queue_redraw()


func _generate_run() -> void:
	# The first centered ribbon is a discoverable invitation. Later phrases are
	# chosen from broad, authored shapes rather than scattered random targets.
	# Their lanes deliberately leave the resting height, so watching without
	# steering cannot quietly collect a whole journey.
	_add_phrase(&"center", 0, 0.0)
	var last_name := &"center"
	for phrase_index in range(1, 13):
		var choices: Array[StringName] = [&"climb", &"descent", &"hill", &"valley", &"wave", &"breather"]
		choices.erase(last_name)
		var phrase := choices[_rng.randi_range(0, choices.size() - 1)]
		var lane_sign := -1.0 if _rng.randi_range(0, 1) == 0 else 1.0
		var lane_offset := lane_sign * _rng.randf_range(170.0, 230.0)
		_add_phrase(phrase, phrase_index, lane_offset)
		last_name = phrase


func _add_phrase(phrase: StringName, phrase_index: int, center_offset: float) -> void:
	_phrase_names.append(phrase)
	_phrase_center_offsets.append(center_offset)
	# Keep the opening ribbon already in view: the child sees what to follow before
	# flight begins, then its first touch simply starts the same visible journey.
	var start_x := 850.0 if phrase_index == 0 else REFERENCE_SIZE.x + float(phrase_index - 1) * PHRASE_DURATION * SCROLL_SPEED
	for sample_index in range(9):
		var t := float(sample_index) / 8.0
		var collectible := FlightCollectible.new()
		collectible.phrase_index = phrase_index
		collectible.position = Vector2(start_x + float(sample_index) * SAMPLE_SPACING, _phrase_y(phrase, t, center_offset))
		_collectibles.append(collectible)


func _phrase_y(phrase: StringName, t: float, center_offset: float) -> float:
	var amplitude := 0.0
	var center := REST_Y + center_offset
	match phrase:
		&"climb":
			return lerpf(REST_Y + 105.0, REST_Y - 175.0, t)
		&"descent":
			return lerpf(REST_Y - 175.0, REST_Y + 105.0, t)
		&"hill":
			amplitude = -185.0 * sin(t * PI)
		&"valley":
			amplitude = 185.0 * sin(t * PI)
		&"wave":
			amplitude = 125.0 * sin(t * TAU)
		&"breather":
			amplitude = 38.0 * sin(t * TAU)
		_:
			amplitude = 28.0 * sin(t * TAU)
	return clampf(center + amplitude, SAFE_TOP + 50.0, SAFE_BOTTOM - 50.0)


func _process(delta: float) -> void:
	_motion_age += delta
	if _running and not _landing:
		_active_age += delta
		_scroll_distance += SCROLL_SPEED * delta
		if _landing_pending:
			_retire_future_collectibles()
			if not _has_visible_collectibles():
				_start_landing()
		elif _active_age >= ACTIVE_DURATION:
			_request_landing_at_boundary()
		for collectible in _collectibles:
			if not collectible.collected and _display_position(collectible).x < -COLLECTIBLE_RADIUS:
				collectible.collected = true # A harmless miss leaves the scene.
			if collectible.collected_age >= 0.0:
				collectible.collected_age += delta
		_check_collection()
	elif _landing and _landing_phase == 1:
		# The landing zone travels with the scenery. No targets remain after the
		# completion condition, so the landing invitation stays unambiguous.
		_scroll_distance += SCROLL_SPEED * delta
		_landing_zone_x -= SCROLL_SPEED * delta
		if _landing_zone_x <= LANDING_ZONE_X:
			_landing_zone_x = LANDING_ZONE_X
			_landing_phase = 2
			_flier_target_x = LANDING_ZONE_X
	elif _landing and _landing_phase == 2:
		if absf(_flier_x - _flier_target_x) < 4.0 and absf(_flier_y - REST_Y) < 8.0:
			_landing_phase = 3
			_landing_settle_age = 0.0
	elif _landing and _landing_phase == 3:
		_landing_settle_age += delta
		if _landing_settle_age >= 0.65:
			_landing_phase = 4
			landing_completed.emit()
	if _release_age >= 0.0:
		_release_age += delta
		if _release_age >= RETURN_DELAY:
			_target_y = move_toward(_target_y, REST_Y, 360.0 * delta)
	# The finger chooses a target rather than directly placing the flier. This
	# critically damped spring carries enough velocity to feel like flight while
	# settling without the distracting bounce of an underdamped controller.
	var spring_acceleration := (_target_y - _flier_y) * FLIER_SPRING_STIFFNESS - _flier_velocity * FLIER_SPRING_DAMPING
	_flier_velocity += spring_acceleration * delta
	_flier_y += _flier_velocity * delta
	if _flier_y <= SAFE_TOP or _flier_y >= SAFE_BOTTOM:
		_flier_y = clampf(_flier_y, SAFE_TOP, SAFE_BOTTOM)
		_flier_velocity = 0.0
	var horizontal_acceleration := (_flier_target_x - _flier_x) * FLIER_SPRING_STIFFNESS - _flier_x_velocity * FLIER_SPRING_DAMPING
	_flier_x_velocity += horizontal_acceleration * delta
	_flier_x += _flier_x_velocity * delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_pointer(event.index, _screen_to_reference(event.position))
		else:
			_end_pointer(event.index)
		accept_event()
	elif event is InputEventScreenDrag:
		_move_pointer(event.index, _screen_to_reference(event.position))
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_pointer(0, _screen_to_reference(event.position))
		else:
			_end_pointer(0)
		accept_event()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_move_pointer(0, _screen_to_reference(event.position))
		accept_event()


func _begin_pointer(pointer: int, position: Vector2) -> void:
	if _active_pointer != -1:
		return
	_active_pointer = pointer
	_anchor_y = position.y
	_anchor_target_y = _target_y
	_release_age = -1.0
	if not _running:
		_running = true
		run_started.emit()


func _move_pointer(pointer: int, position: Vector2) -> void:
	if pointer != _active_pointer:
		return
	_target_y = clampf(_anchor_target_y + position.y - _anchor_y, SAFE_TOP, SAFE_BOTTOM)
	_release_age = -1.0


func _end_pointer(pointer: int) -> void:
	if pointer != _active_pointer:
		return
	_active_pointer = -1
	_release_age = 0.0


func release_interrupted_input() -> void:
	# App suspension and lost touch use the same gentle recovery as a release.
	if _active_pointer != -1:
		_end_pointer(_active_pointer)


func _check_collection() -> void:
	for collectible in _collectibles:
		if collectible.collected:
			continue
		if _display_position(collectible).distance_to(Vector2(_flier_x, _flier_y)) <= COLLECTION_RADIUS:
			collectible.collected = true
			collectible.collected_age = 0.0
			_progress += 1
			collectible_collected.emit(_progress)
			sound_requested.emit(&"correct")
			if _progress >= COLLECTION_TARGET:
				_request_landing_at_boundary()


func _request_landing_at_boundary() -> void:
	if _landing or _landing_pending:
		return
	# Freeze the generated horizon at the current screen edge. Flowers already in
	# flight remain real, collectable objects until they naturally leave screen;
	# only then does the cloud take over the empty right-hand sky.
	_landing_pending = true
	_landing_cutoff_x = _scroll_distance + REFERENCE_SIZE.x
	_retire_future_collectibles()


func _retire_future_collectibles() -> void:
	for collectible in _collectibles:
		if not collectible.collected and collectible.position.x > _landing_cutoff_x:
			collectible.collected = true


func _has_visible_collectibles() -> bool:
	for collectible in _collectibles:
		if collectible.collected:
			continue
		var position := _display_position(collectible)
		if position.x >= -COLLECTIBLE_RADIUS and position.x <= REFERENCE_SIZE.x + COLLECTIBLE_RADIUS:
			return true
	return false


func _start_landing() -> void:
	if _landing:
		return
	_landing = true
	_input_enabled = false
	_active_pointer = -1
	_target_y = REST_Y
	_landing_phase = 1


func force_landing_for_test() -> void:
	_start_landing()
	_landing_zone_x = LANDING_ZONE_X
	_landing_phase = 2
	_flier_target_x = LANDING_ZONE_X


func _display_position(collectible: FlightCollectible) -> Vector2:
	return collectible.position - Vector2(_scroll_distance, 0.0)


func _reference_transform() -> Dictionary:
	var viewport_size := size if size != Vector2.ZERO else REFERENCE_SIZE
	var scale_factor := maxf(viewport_size.x / REFERENCE_SIZE.x, viewport_size.y / REFERENCE_SIZE.y)
	return {"offset": (viewport_size - REFERENCE_SIZE * scale_factor) * 0.5, "scale": scale_factor}


func _screen_to_reference(position: Vector2) -> Vector2:
	var transform := _reference_transform()
	return (position - (transform["offset"] as Vector2)) / float(transform["scale"])


func _set_reference_draw_transform(origin: Vector2, rotation := 0.0, local_scale := Vector2.ONE) -> void:
	var transform := _reference_transform()
	var viewport_scale := float(transform["scale"])
	draw_set_transform(
		(transform["offset"] as Vector2) + origin * viewport_scale,
		rotation,
		local_scale * viewport_scale
	)


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled


func get_progress() -> int:
	return _progress


func get_phrase_names() -> Array[StringName]:
	return _phrase_names.duplicate()


func get_phrase_center_offsets() -> Array[float]:
	return _phrase_center_offsets.duplicate()


func get_idle_collectible_count() -> int:
	# Every generated item eventually passes the fixed horizontal collection line.
	# This count models the maximum a child can gather without a vertical gesture.
	var count := 0
	for collectible in _collectibles:
		if absf(collectible.position.y - REST_Y) <= COLLECTION_RADIUS:
			count += 1
	return count


func get_collectible_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for collectible in _collectibles:
		positions.append(collectible.position)
	return positions


func get_flier_y() -> float:
	return _flier_y


func get_target_y() -> float:
	return _target_y


func is_running() -> bool:
	return _running


func is_landing() -> bool:
	return _landing


func _draw() -> void:
	_set_reference_draw_transform(Vector2.ZERO)
	_draw_background()
	if not _landing:
		for collectible in _collectibles:
			_draw_collectible(collectible)
	if _landing:
		_draw_landing_zone()
	_draw_flier()
	_draw_progress()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_background() -> void:
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, REFERENCE_SIZE), false)
	# Slow clouds establish forward travel without cluttering the collection band.
	for index in AMBIENT_CLOUDS.size():
		var texture := AMBIENT_CLOUDS[index]
		var cloud_size := texture.get_size() * (0.72 + float(index % 2) * 0.14)
		var x := fposmod(260.0 + float(index) * 620.0 - _scroll_distance * (0.10 + float(index % 2) * 0.035), 2920.0) - 340.0
		var y := 92.0 + float(index % 2) * 152.0 + sin(_motion_age * 0.45 + index) * 12.0
		draw_texture_rect(texture, Rect2(Vector2(x, y), cloud_size), false, Color(1.0, 1.0, 1.0, 0.78))


func _draw_collectible(collectible: FlightCollectible) -> void:
	if collectible.collected and collectible.collected_age < 0.0:
		return
	var position := _display_position(collectible)
	if collectible.collected_age >= 0.0:
		var t := clampf(collectible.collected_age / 0.32, 0.0, 1.0)
		position = position.lerp(_basket_center(), t)
		var fly_size := COLLECTIBLE.get_size() * lerpf(0.76, 0.38, t)
		draw_texture_rect(COLLECTIBLE, Rect2(position - fly_size * 0.5, fly_size), false, Color(1.0, 1.0, 1.0, 1.0 - t))
		return
	if position.x < -100.0 or position.x > REFERENCE_SIZE.x + 100.0:
		return
	var blossom_size := COLLECTIBLE.get_size() * 0.72
	draw_texture_rect(COLLECTIBLE, Rect2(position - blossom_size * 0.5, blossom_size), false)


func _draw_flier() -> void:
	if _landing_phase >= 3:
		_draw_touchdown()
		return
	var root := Vector2(_flier_x, _flier_y + sin(_motion_age * TAU * 0.72) * 7.0)
	var body_rotation := sin(_motion_age * TAU * 0.72) * deg_to_rad(1.5)
	var kite_sway := sin((_motion_age - 0.18) * TAU * 0.72) * deg_to_rad(4.0)
	var ponytail_sway := sin((_motion_age - 0.10) * TAU * 0.72) * deg_to_rad(8.0)
	var basket_sway := sin((_motion_age - 0.14) * TAU * 0.72) * deg_to_rad(2.2)

	_draw_ponytail(PONYTAIL_LEFT, root, Vector2(-67, -162), Vector2(-116, -184), -0.2805, ponytail_sway, body_rotation)
	_draw_ponytail(PONYTAIL_RIGHT, root, Vector2(34, -196), Vector2(68, -237), -0.1470, -ponytail_sway, body_rotation)
	_draw_kite(root, body_rotation, kite_sway)
	_draw_basket(root, body_rotation, basket_sway)
	_draw_rotated_texture(LUNA_BODY, root, Vector2(320, 420) * FLIER_ART_SCALE, body_rotation)
	_draw_kite_tail(root, body_rotation, kite_sway)


func _draw_landing_zone() -> void:
	var center := Vector2(_landing_zone_x, LANDING_ZONE_Y)
	var cloud_size := LANDING_CLOUD.get_size() * 0.72
	draw_texture_rect(LANDING_CLOUD, Rect2(center - cloud_size * 0.5, cloud_size), false)


func _draw_progress() -> void:
	# The carried basket is the only progress display. Six large blossoms reveal
	# at broad milestones, never as a score or numeric HUD.
	if _landing_phase >= 3:
		return
	var visible_blossoms := mini(PROGRESS_BLOSSOMS.size(), _progress / PROGRESS_MILESTONE)
	var center := _basket_center()
	var offsets: Array[Vector2] = [Vector2(-36, -22), Vector2(0, -40), Vector2(39, -22), Vector2(-27, 15), Vector2(19, 12), Vector2(0, -3)]
	for index in visible_blossoms:
		var texture := PROGRESS_BLOSSOMS[index]
		var blossom_size := texture.get_size() * 0.48
		draw_texture_rect(texture, Rect2(center + offsets[index] - blossom_size * 0.5, blossom_size), false)


func _basket_center() -> Vector2:
	return Vector2(_flier_x, _flier_y) + Vector2(-137.0, 20.0) * FLIER_ART_SCALE


func _draw_rotated_texture(texture: Texture2D, center: Vector2, draw_size: Vector2, rotation: float, modulate := Color.WHITE) -> void:
	_set_reference_draw_transform(center, rotation)
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false, modulate)
	_set_reference_draw_transform(Vector2.ZERO)


func _rotate_offset(offset: Vector2, rotation: float) -> Vector2:
	return offset.rotated(rotation)


func _draw_ponytail(texture: Texture2D, root: Vector2, anchor: Vector2, center: Vector2, base_rotation: float, sway: float, body_rotation: float) -> void:
	var positioned_anchor := root + _rotate_offset(anchor * FLIER_ART_SCALE, body_rotation)
	var offset := _rotate_offset((center - anchor) * FLIER_ART_SCALE, sway)
	var positioned_center := positioned_anchor + _rotate_offset(offset, body_rotation)
	_draw_rotated_texture(texture, positioned_center, texture.get_size() * 0.8 * FLIER_ART_SCALE, body_rotation + base_rotation + sway)


func _draw_kite(root: Vector2, body_rotation: float, kite_sway: float) -> void:
	var hand := root + _rotate_offset(Vector2(127, -170) * FLIER_ART_SCALE, body_rotation)
	var resting_rope := Vector2(53, -135).rotated(kite_sway) * FLIER_ART_SCALE * (1.0 + sin(_motion_age * TAU * 0.72) * 0.07)
	var kite_tie := hand + resting_rope
	draw_line(hand, kite_tie, Color("#7a5831"), 5.0 * FLIER_ART_SCALE, true)
	var kite_center := kite_tie + Vector2(34, -105).rotated(kite_sway) * FLIER_ART_SCALE
	_draw_rotated_texture(KITE, kite_center, KITE.get_size() * FLIER_ART_SCALE, 0.3081 + kite_sway)


func _draw_basket(root: Vector2, body_rotation: float, basket_sway: float) -> void:
	var center := root + _rotate_offset(Vector2(-137, 20) * FLIER_ART_SCALE, body_rotation)
	_draw_rotated_texture(BASKET, center, BASKET.get_size() * 0.59 * FLIER_ART_SCALE, body_rotation + 0.3335 + basket_sway)


func _draw_kite_tail(root: Vector2, body_rotation: float, kite_sway: float) -> void:
	var tail_root := root + _rotate_offset(Vector2(124, -135) * FLIER_ART_SCALE, body_rotation)
	var bows: Array[Vector2] = [Vector2(99, -96), Vector2(57, -29), Vector2(10, 51)]
	var previous := tail_root
	for index in bows.size():
		var point := tail_root + _rotate_offset((bows[index] - Vector2(124, -135)) * FLIER_ART_SCALE, body_rotation + kite_sway)
		draw_line(previous, point, Color("#8a6a9d"), 4.0 * FLIER_ART_SCALE, true)
		_draw_rotated_texture(KITE_BOW, point, KITE_BOW.get_size() * FLIER_ART_SCALE, body_rotation + kite_sway)
		previous = point


func _draw_touchdown() -> void:
	var base_size := TOUCHDOWN_LUNA.get_size() * 0.78 * FLIER_ART_SCALE
	var touchdown_size := base_size * TOUCHDOWN_ART_SCALE
	# Preserve the approved feet-on-cloud anchor while compensating for the
	# touchdown source's generous transparent padding.
	var center := Vector2(LANDING_ZONE_X, LANDING_ZONE_Y - 152.0 - (touchdown_size.y - base_size.y) * 0.5)
	var puff_t := clampf(_landing_settle_age / LANDING_PUFF_DURATION, 0.0, 1.0)
	for index in 3:
		var puff_size := LANDING_CLOUD.get_size() * (0.36 + float(index) * 0.08 + puff_t * 0.12)
		var puff_center := Vector2(LANDING_ZONE_X + (float(index) - 1.0) * 118.0, LANDING_ZONE_Y + 80.0 - float(index % 2) * 28.0)
		draw_texture_rect(LANDING_CLOUD, Rect2(puff_center - puff_size * 0.5, puff_size), false, Color(1.0, 1.0, 1.0, (1.0 - puff_t) * 0.86))
	# The standing composition comes through as the cloud reaches its obscuring
	# peak, avoiding an empty beat between the flight puppet and touchdown.
	var alpha := clampf(puff_t / 0.12, 0.0, 1.0)
	draw_texture_rect(TOUCHDOWN_LUNA, Rect2(center - touchdown_size * 0.5, touchdown_size), false, Color(1.0, 1.0, 1.0, alpha))
