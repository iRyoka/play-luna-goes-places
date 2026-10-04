class_name PopTapBoard
extends Control

signal successful_tap(progress: int)
signal event_triggered(progress: int)
signal quota_completed
signal sound_requested(sound_id: StringName)
signal target_replenished

const REFERENCE_SIZE := Vector2(2160.0, 1080.0)
const TARGET_HIT_RADIUS := 92.0
const TARGET_VISUAL_RADIUS := 58.0
const TARGET_SCALE_MIN := 0.21
const TARGET_SCALE_MAX := 0.33
const SCROLL_SPEED := 70.0
const POP_EFFECT_DURATION := 0.42
const EVENT_EFFECT_DURATION := 1.1
const WAVE_ONE_RANGE := Vector2i(7, 10)
const GIANT_ONE_RANGE := Vector2i(14, 17)
const WAVE_TWO_RANGE := Vector2i(22, 25)
const GIANT_TWO_RANGE := Vector2i(30, 33)
const WAVE_THREE_RANGE := Vector2i(38, 41)
const GIANT_THREE_RANGE := Vector2i(47, 50)
const BUBBLE_WAVE_TARGET_COUNT := 2
const BUBBLE_WAVE_DELAY := 0.14
const BUBBLE_WAVE_DURATION := 0.58
const GIANT_BUBBLE_DURATION := 0.9
const GIANT_BUBBLE_MAX_RADIUS := 280.0
const RIM_DUCK_TOTAL := 10
const RIM_DUCK_SLOT_WIDTH := 82.0
const RIM_DUCK_Y := 38.0
const RIM_DUCK_DISPLAY_HEIGHT := 64.0
const RIM_DUCK_CELEBRATION_DURATION := 1.0
const INITIAL_TARGET_COUNT := 6
const MIN_VISIBLE_TARGETS := 5
const KING_DUCK_RISE_DURATION := 2.4
const KING_DUCK_BOUNCE_DURATION := 3.8
const TUB_Y := 135.0
const TUB_HEIGHT := 810.0
const TARGET_VISUAL_TOP_Y := 250.0
const TARGET_VISUAL_BOTTOM_Y := 835.0
const TARGET_BOUND_PADDING := 12.0
const LEFT_CAP_SAFE_TOP_Y := 390.0
const LEFT_CAP_SAFE_BOTTOM_Y := 690.0
const KING_DUCK_WATERLINE_Y := 610.0
# One authored travel cycle: sampled from the earlier broad X distribution,
# with a varied vertical profile. A target re-enters on the next cycle slot,
# rather than at a uniformly random vertical position.
const TARGET_TIMELINE: Array[Vector2] = [
	# The rounded left cap only has usable water in its central band.
	Vector2(200, 520),
	Vector2(550, 510),
	Vector2(900, 720),
	Vector2(1250, 270),
	Vector2(1600, 590),
	Vector2(1950, 740),
]

class BubbleTarget:
	var id := 0
	var center := Vector2.ZERO
	var visual_radius := TARGET_VISUAL_RADIUS
	var hit_radius := TARGET_HIT_RADIUS
	var active := true
	var phase := 0.0
	var pop_age := -1.0
	var event_pop := false
	var texture_index := 0
	var scale_factor := 0.27
	var timeline_index := 0
	var wave_age := -1.0
	var wave_delay := 0.0
	var giant_bubble := false
	var chain_pop := false


class WaterDecoration:
	var x := 0.0
	var y := 0.0
	var scale_factor := 1.0

@export_range(1, 80, 1) var required_taps := 60
## Zero gives ordinary play a fresh run. Tests and bug reports set an explicit seed.
@export var deterministic_seed := 0

var _targets: Array[BubbleTarget] = []
var _water_decoration_states: Array[WaterDecoration] = []
var _rim_duck_texture_indices: Array[int] = []
var _rim_duck_celebration_ages: Array[float] = []
var _event_tap_indices: Array[int] = []
var _giant_bubble_event_progresses: Array[int] = []
var _giant_bubble_pop_count := 0
var _next_timeline_index := 0
var _rng := RandomNumberGenerator.new()
var _visual_rng := RandomNumberGenerator.new()
var _progress := 0
var _input_enabled := true
var _scrolling := true
var _quota_emitted := false
var _finale_age := -1.0
var _background_scroll := 0.0
var _rim_ducks_visible := 0
var _king_duck_bounce_age := -1.0

var _bubble_textures: Array[Texture2D] = []
var _effect_textures: Dictionary = {}
var _duck_textures: Array[Texture2D] = []
var _megaduck_texture: Texture2D
var _tub_left_cap: Texture2D
var _tub_middle_strip: Texture2D
var _water_decorations: Array[Texture2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	_load_textures()
	reset_run()


func _load_textures() -> void:
	for i in range(6):
		_bubble_textures.append(load("res://assets/gameplay/pop-tap/bubble_%02d.png" % (i + 1)))
	_effect_textures = {
		&"pop_ring_small": load("res://assets/gameplay/pop-tap/effect_pop_ring_small.png"),
		&"pop_ring_large": load("res://assets/gameplay/pop-tap/effect_pop_ring_large.png"),
		&"bubble_burst": load("res://assets/gameplay/pop-tap/effect_bubble_burst.png"),
		&"droplet_fan_small": load("res://assets/gameplay/pop-tap/effect_droplet_fan_small.png"),
		&"splash_crown_small": load("res://assets/gameplay/pop-tap/effect_splash_crown_small.png"),
		&"foam_cloud": load("res://assets/gameplay/pop-tap/effect_foam_cloud.png"),
	}
	_duck_textures = [
		load("res://assets/gameplay/pop-tap/rim_duck_01.png"),
		load("res://assets/gameplay/pop-tap/rim_duck_02.png"),
	]
	_megaduck_texture = load("res://assets/gameplay/pop-tap/megaduck_finale.png")
	_tub_left_cap = load("res://assets/gameplay/pop-tap/tub_left_cap.png")
	_tub_middle_strip = load("res://assets/gameplay/pop-tap/tub_middle_strip.png")
	for i in range(3):
		_water_decorations.append(load("res://assets/gameplay/pop-tap/water_decoration_%02d.png" % (i + 1)))


func _process(delta: float) -> void:
	var needs_redraw := false
	if _scrolling:
		_background_scroll += SCROLL_SPEED * delta
		needs_redraw = true
	for target in _targets:
		if target.active:
			target.phase += delta * 3.0
			if _scrolling:
				target.center.x -= SCROLL_SPEED * delta
				if target.center.x < -TARGET_HIT_RADIUS:
					_recycle_target(target)
			needs_redraw = true
		if target.wave_age >= 0.0:
			target.wave_age += delta
			if target.wave_age > target.wave_delay + BUBBLE_WAVE_DURATION:
				target.wave_age = -1.0
			needs_redraw = true
		elif target.pop_age >= 0.0:
			target.pop_age += delta
			if target.giant_bubble:
				_consume_giant_bubble_contacts(target)
			var effect_duration := EVENT_EFFECT_DURATION if target.event_pop else POP_EFFECT_DURATION
			if target.pop_age > effect_duration:
				target.pop_age = -1.0
				if not _quota_emitted:
					_recycle_target(target)
					target.active = true
					target_replenished.emit()
			needs_redraw = true
	if _finale_age >= 0.0:
		_finale_age += delta
		needs_redraw = true
	if _king_duck_bounce_age >= 0.0:
		_king_duck_bounce_age += delta
		needs_redraw = true
	for index in range(_rim_duck_celebration_ages.size()):
		if _rim_duck_celebration_ages[index] >= 0.0:
			_rim_duck_celebration_ages[index] += delta
			if _rim_duck_celebration_ages[index] >= RIM_DUCK_CELEBRATION_DURATION:
				_rim_duck_celebration_ages[index] = -1.0
			needs_redraw = true
	if needs_redraw:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		accept_event()
		tap_at(_screen_to_reference(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		tap_at(_screen_to_reference(event.position))


func reset_run() -> void:
	if deterministic_seed == 0:
		_rng.randomize()
		_visual_rng.randomize()
	else:
		_rng.seed = deterministic_seed
		_visual_rng.seed = deterministic_seed + 137
	_targets.clear()
	_water_decoration_states.clear()
	_rim_duck_texture_indices.clear()
	_rim_duck_celebration_ages.clear()
	_event_tap_indices = _build_event_tap_indices()
	_giant_bubble_event_progresses = [
		_event_tap_indices[1],
		_event_tap_indices[3],
		_event_tap_indices[5],
	]
	_giant_bubble_pop_count = 0
	_next_timeline_index = 0
	_progress = 0
	_input_enabled = true
	_scrolling = true
	_quota_emitted = false
	_finale_age = -1.0
	_background_scroll = 0.0
	_rim_ducks_visible = 0
	_king_duck_bounce_age = -1.0
	for index in range(INITIAL_TARGET_COUNT):
		var target := BubbleTarget.new()
		target.id = index
		target.timeline_index = index
		target.center = TARGET_TIMELINE[index] + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-10.0, 10.0))
		target.visual_radius = TARGET_VISUAL_RADIUS + _rng.randf_range(-8.0, 10.0)
		target.phase = _rng.randf_range(0.0, TAU)
		_randomize_target_visual(target)
		_constrain_target_to_bathtub(target)
		_targets.append(target)
	for index in range(RIM_DUCK_TOTAL):
		_rim_duck_texture_indices.append(_visual_rng.randi_range(0, _duck_textures.size() - 1))
		_rim_duck_celebration_ages.append(-1.0)
	for index in range(_water_decorations.size()):
		var decoration := WaterDecoration.new()
		decoration.x = _visual_rng.randf_range(80.0, REFERENCE_SIZE.x - 80.0)
		decoration.y = _visual_rng.randf_range(TUB_Y + 80.0, TUB_Y + TUB_HEIGHT - 160.0)
		decoration.scale_factor = _visual_rng.randf_range(0.55, 0.85)
		_water_decoration_states.append(decoration)
	queue_redraw()


func start_run_with_seed(seed: int) -> void:
	deterministic_seed = seed
	reset_run()


func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func tap_at(position: Vector2) -> bool:
	if not _input_enabled or _quota_emitted:
		return false
	var target := _target_at(position)
	if target == null:
		return false
	_consume_target(target)
	return true


func get_progress() -> int:
	return _progress


func get_rim_duck_count() -> int:
	return _rim_ducks_visible


func get_rim_duck_total() -> int:
	return RIM_DUCK_TOTAL


func get_rim_duck_celebration_age(index: int) -> float:
	if index < 0 or index >= _rim_duck_celebration_ages.size():
		return -1.0
	return _rim_duck_celebration_ages[index]


func get_target_texture_indices() -> Array[int]:
	var indices: Array[int] = []
	for target in _targets:
		indices.append(target.texture_index)
	return indices


func get_target_scale_factors() -> Array[float]:
	var scales: Array[float] = []
	for target in _targets:
		scales.append(target.scale_factor)
	return scales


func is_complete() -> bool:
	return _quota_emitted


func is_scrolling() -> bool:
	return _scrolling


func get_completion_emit_count() -> int:
	return 1 if _quota_emitted else 0


func is_event_progress(progress: int) -> bool:
	return _event_tap_indices.has(progress)


func get_event_tap_indices() -> Array[int]:
	return _event_tap_indices.duplicate()


func get_active_bubble_wave_count() -> int:
	var count := 0
	for target in _targets:
		if target.active and target.wave_age >= 0.0:
			count += 1
	return count


func get_giant_bubble_event_progresses() -> Array[int]:
	return _giant_bubble_event_progresses.duplicate()


func get_active_giant_bubble_count() -> int:
	var count := 0
	for target in _targets:
		if target.giant_bubble and target.pop_age >= 0.0:
			count += 1
	return count


func get_giant_bubble_pop_count() -> int:
	return _giant_bubble_pop_count


func get_active_target_count() -> int:
	var count := 0
	for target in _targets:
		if target.active:
			count += 1
	return count


func get_visible_active_target_count() -> int:
	var count := 0
	for target in _targets:
		if target.active and target.center.x >= -TARGET_HIT_RADIUS and target.center.x <= REFERENCE_SIZE.x + TARGET_HIT_RADIUS:
			count += 1
	return count


func get_active_target_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for target in _targets:
		if target.active:
			centers.append(target.center)
	return centers


func get_cued_target_count() -> int:
	var count := 0
	for target in _targets:
		if target.active and target.center.y < 430.0:
			count += 1
	return count


func targets_fit_bathtub() -> bool:
	for target in _targets:
		if not target.active:
			continue
		var texture := _bubble_textures[target.texture_index]
		var half_height := texture.get_height() * target.scale_factor * 1.08 * 0.5
		if target.center.y - half_height - 5.0 < TARGET_VISUAL_TOP_Y:
			return false
		if target.center.y + half_height + 5.0 > TARGET_VISUAL_BOTTOM_Y:
			return false
	return true


func hit_areas_are_separated() -> bool:
	for left_index in range(_targets.size()):
		for right_index in range(left_index + 1, _targets.size()):
			var left := _targets[left_index]
			var right := _targets[right_index]
			if left.center.distance_to(right.center) <= left.hit_radius + right.hit_radius:
				return false
	return true


func _reference_transform() -> Dictionary:
	var viewport_size := size if size != Vector2.ZERO else REFERENCE_SIZE
	# Cover the full gameplay viewport. Wide Android screens crop a little of the
	# reference board vertically instead of exposing untappable side gutters.
	var scale_factor := maxf(
		viewport_size.x / REFERENCE_SIZE.x,
		viewport_size.y / REFERENCE_SIZE.y,
	)
	if scale_factor <= 0.0:
		scale_factor = 1.0
	return {
		"offset": (viewport_size - REFERENCE_SIZE * scale_factor) * 0.5,
		"scale": scale_factor,
	}


func _screen_to_reference(position: Vector2) -> Vector2:
	var transform := _reference_transform()
	return (position - (transform["offset"] as Vector2)) / float(transform["scale"])


func _target_at(position: Vector2) -> BubbleTarget:
	for target in _targets:
		if target.active and target.center.distance_to(position) <= target.hit_radius:
			return target
	return null


func _recycle_target(target: BubbleTarget) -> void:
	target.visual_radius = TARGET_VISUAL_RADIUS + _rng.randf_range(-8.0, 10.0)
	target.phase = _rng.randf_range(0.0, TAU)
	_randomize_target_visual(target)

	if get_visible_active_target_count() < MIN_VISIBLE_TARGETS:
		# Restore a readable field immediately when ordinary play has become sparse.
		target.center = _find_visible_spawn_position(target)
		return

	var furthest_x := 0.0
	for other in _targets:
		if other != target and other.active:
			furthest_x = maxf(furthest_x, other.center.x)

	var profile := TARGET_TIMELINE[_next_timeline_index]
	_next_timeline_index = (_next_timeline_index + 1) % TARGET_TIMELINE.size()
	target.timeline_index = _next_timeline_index
	# Preserve the authored time/X spacing while the field is already healthy.
	target.center = Vector2(
		maxf(2200.0 + profile.x * 0.25, furthest_x + 300.0),
		profile.y + _rng.randf_range(-10.0, 10.0),
	)
	_constrain_target_to_bathtub(target)


func _find_visible_spawn_position(target: BubbleTarget) -> Vector2:
	for attempt in range(24):
		var candidate := Vector2(
			_rng.randf_range(TARGET_HIT_RADIUS, REFERENCE_SIZE.x - TARGET_HIT_RADIUS),
			_rng.randf_range(TARGET_VISUAL_TOP_Y, TARGET_VISUAL_BOTTOM_Y),
		)
		target.center = candidate
		_constrain_target_to_bathtub(target)
		var overlaps := false
		for other in _targets:
			if other != target and other.active and target.center.distance_to(other.center) <= target.hit_radius + other.hit_radius:
				overlaps = true
				break
		if not overlaps:
			_constrain_target_to_left_cap(target)
			return target.center

	# The authored edge entry remains a safe fallback if the visible field is
	# temporarily too full to place another generous touch target.
	return Vector2(REFERENCE_SIZE.x + TARGET_HIT_RADIUS, TARGET_VISUAL_TOP_Y + 180.0)


func _randomize_target_visual(target: BubbleTarget) -> void:
	target.texture_index = _visual_rng.randi_range(0, _bubble_textures.size() - 1)
	target.scale_factor = _visual_rng.randf_range(TARGET_SCALE_MIN, TARGET_SCALE_MAX)


func _build_event_tap_indices() -> Array[int]:
	# Keep the opening taps simple, then alternate small waves with three giant
	# bubbles. Each authored range is separate, so spectacles never bunch.
	return [
		_rng.randi_range(WAVE_ONE_RANGE.x, WAVE_ONE_RANGE.y),
		_rng.randi_range(GIANT_ONE_RANGE.x, GIANT_ONE_RANGE.y),
		_rng.randi_range(WAVE_TWO_RANGE.x, WAVE_TWO_RANGE.y),
		_rng.randi_range(GIANT_TWO_RANGE.x, GIANT_TWO_RANGE.y),
		_rng.randi_range(WAVE_THREE_RANGE.x, WAVE_THREE_RANGE.y),
		_rng.randi_range(GIANT_THREE_RANGE.x, GIANT_THREE_RANGE.y),
	]


func _constrain_target_to_bathtub(target: BubbleTarget) -> void:
	# Protect against the sprite's randomized size, pulse, and bob moving visible
	# pixels beyond the bathtub's interior.
	var texture := _bubble_textures[target.texture_index]
	var half_height := texture.get_height() * target.scale_factor * 1.08 * 0.5
	var min_center_y := TARGET_VISUAL_TOP_Y + half_height + 5.0 + TARGET_BOUND_PADDING
	var max_center_y := TARGET_VISUAL_BOTTOM_Y - half_height - 5.0 - TARGET_BOUND_PADDING
	target.center.y = clampf(target.center.y, min_center_y, max_center_y)
	_constrain_target_to_left_cap(target)


func _constrain_target_to_left_cap(target: BubbleTarget) -> void:
	# The cap and targets travel at the same speed, so this test stays valid for
	# an initial target as it crosses the rounded start of the bathtub.
	var scaled_cap_width := float(_tub_left_cap.get_width()) * TUB_HEIGHT / float(_tub_left_cap.get_height())
	var cap_right_x := scaled_cap_width - _background_scroll
	if target.center.x >= cap_right_x:
		return
	var texture := _bubble_textures[target.texture_index]
	var half_height := texture.get_height() * target.scale_factor * 1.08 * 0.5
	target.center.y = clampf(
		target.center.y,
		LEFT_CAP_SAFE_TOP_Y + half_height + TARGET_BOUND_PADDING,
		LEFT_CAP_SAFE_BOTTOM_Y - half_height - TARGET_BOUND_PADDING,
	)


func _consume_target(target: BubbleTarget) -> void:
	target.active = false
	target.pop_age = 0.0
	# Recycling retains a target object and its visual variant. Clear any previous
	# reaction form before assigning this tap's form so an old giant cannot turn an
	# ordinary later tap into another giant bubble.
	target.giant_bubble = false
	target.chain_pop = false
	# A child may tap a bubble while it is reacting to a previous wave. Its own pop
	# takes over immediately; otherwise the stale wave timer postpones recycling
	# after the pop effect and thins the field during rapid play.
	target.wave_age = -1.0
	target.wave_delay = 0.0
	_progress += 1
	target.event_pop = is_event_progress(_progress)
	if target.event_pop:
		target.giant_bubble = _giant_bubble_event_progresses.has(_progress)
		if target.giant_bubble:
			for earlier_target in _targets:
				if earlier_target != target and earlier_target.giant_bubble and earlier_target.pop_age >= 0.0:
					# Rapid taps can reach the next giant Event before the previous
					# animation settles. Keep the spectacle singular rather than
					# stacking two expanding bubbles.
					earlier_target.giant_bubble = false
					earlier_target.pop_age = EVENT_EFFECT_DURATION
			# The expanding bubble owns only its local visual space: nearby targets
			# pop when visibly reached, but the child can keep tapping everywhere.
		else:
			_start_bubble_wave(target)
		sound_requested.emit(&"pop_event")
		event_triggered.emit(_progress)
	else:
		sound_requested.emit(&"pop")
	successful_tap.emit(_progress)
	
	# Show a duck only after its 10%-completion threshold has been crossed.
	var new_duck_count := mini(RIM_DUCK_TOTAL, int(floor(float(_progress) * float(RIM_DUCK_TOTAL) / float(required_taps))))
	if new_duck_count > _rim_ducks_visible:
		for duck_index in range(_rim_ducks_visible, new_duck_count):
			_rim_duck_celebration_ages[duck_index] = 0.0
		_rim_ducks_visible = new_duck_count
	
	if _progress >= required_taps:
		_quota_emitted = true
		_input_enabled = false
		_scrolling = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Start king duck rise and bubble finale
		_king_duck_bounce_age = 0.0
		_finale_age = 0.0
		sound_requested.emit(&"bubbles")
		quota_completed.emit()
	queue_redraw()


func _start_bubble_wave(source: BubbleTarget) -> void:
	var nearest: Array[BubbleTarget] = []
	for candidate in _targets:
		if candidate == source or not candidate.active:
			continue
		var insert_at := nearest.size()
		for index in range(nearest.size()):
			if candidate.center.distance_squared_to(source.center) < nearest[index].center.distance_squared_to(source.center):
				insert_at = index
				break
		nearest.insert(insert_at, candidate)
		if nearest.size() > BUBBLE_WAVE_TARGET_COUNT:
			nearest.pop_back()
	for index in range(nearest.size()):
		nearest[index].wave_age = 0.0
		nearest[index].wave_delay = BUBBLE_WAVE_DELAY * float(index)


func _consume_giant_bubble_contacts(source: BubbleTarget) -> void:
	var expansion := clampf(source.pop_age / GIANT_BUBBLE_DURATION, 0.0, 1.0)
	var giant_radius := lerpf(source.visual_radius, GIANT_BUBBLE_MAX_RADIUS, ease(expansion, 0.45))
	for candidate in _targets:
		if candidate == source or not candidate.active:
			continue
		if candidate.center.distance_to(source.center) > giant_radius + candidate.visual_radius:
			continue
		candidate.active = false
		candidate.pop_age = 0.0
		# A giant bubble visibly replaces any earlier nearby wave. Leaving its wave
		# timer live delays this target's pop/recycle path and can make rapid play
		# look needlessly sparse.
		candidate.wave_age = -1.0
		candidate.wave_delay = 0.0
		candidate.event_pop = true
		candidate.chain_pop = true
		_giant_bubble_pop_count += 1


func _draw() -> void:
	var transform := _reference_transform()
	var offset := transform["offset"] as Vector2
	var scale_factor := float(transform["scale"])
	draw_set_transform(offset, 0.0, Vector2.ONE * scale_factor)
	_draw_bathtub()
	for target in _targets:
		_draw_target(target)
	if _king_duck_bounce_age >= 0.0:
		_draw_king_duck()
		_draw_king_duck_foreground_water()
	if _finale_age >= 0.0:
		_draw_finale()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_rim_ducks()


func _draw_bathtub() -> void:
	# Draw a finite scrolling bathtub passage (~75% of screen height)
	var cap_w := float(_tub_left_cap.get_width())
	var cap_h := float(_tub_left_cap.get_height())
	var strip_w := float(_tub_middle_strip.get_width())
	var strip_h := float(_tub_middle_strip.get_height())
	
	var cap_scale := TUB_HEIGHT / cap_h
	var strip_scale := TUB_HEIGHT / strip_h
	var scaled_cap_w := cap_w * cap_scale
	var scaled_strip_w := strip_w * strip_scale
	
	# Left cap: starts at x=0, scrolls off to the left
	var left_cap_x := -_background_scroll
	if left_cap_x + scaled_cap_w > 0:
		draw_texture_rect(_tub_left_cap, Rect2(left_cap_x, TUB_Y, scaled_cap_w, TUB_HEIGHT), false)
	
	# Middle strips: tile from after left cap to fill the screen
	var middle_start := scaled_cap_w - _background_scroll
	var screen_w := REFERENCE_SIZE.x
	var x := middle_start
	while x < screen_w:
		draw_texture_rect(_tub_middle_strip, Rect2(x, TUB_Y, scaled_strip_w, TUB_HEIGHT), false)
		x += scaled_strip_w
	
	# Right cap: appears when scrolling stops (quota reached)
	if not _scrolling:
		var right_cap_x := screen_w - scaled_cap_w
		draw_texture_rect(_tub_left_cap, Rect2(right_cap_x + scaled_cap_w, TUB_Y, -scaled_cap_w, TUB_HEIGHT), false)
	
	# Decorations share bathtub horizontal travel while retaining independently
	# sampled vertical positions for a loose, non-lane-like water surface.
	for index in range(_water_decorations.size()):
		var tex := _water_decorations[index]
		var state := _water_decoration_states[index]
		var deco_size := tex.get_size() * state.scale_factor
		var deco_x := fposmod(state.x - _background_scroll * 0.5, screen_w + deco_size.x) - deco_size.x
		draw_texture_rect(tex, Rect2(deco_x, state.y, deco_size.x, deco_size.y), false, Color(1.0, 1.0, 1.0, 0.4))





func _draw_rim_ducks() -> void:
	# Progress belongs to the screen, not to the scrolling bathtub reference board.
	# Keep it below a fixed safe top margin on every phone aspect ratio.
	var screen_size := size if size != Vector2.ZERO else REFERENCE_SIZE
	var display_scale := minf(screen_size.x / REFERENCE_SIZE.x, screen_size.y / REFERENCE_SIZE.y)
	var display_height := RIM_DUCK_DISPLAY_HEIGHT * display_scale
	var slot_width := RIM_DUCK_SLOT_WIDTH * display_scale
	var row_start_x := (screen_size.x - slot_width * RIM_DUCK_TOTAL) * 0.5
	for i in range(RIM_DUCK_TOTAL):
		var texture := _duck_textures[_rim_duck_texture_indices[i]]
		var target_scale := display_height / float(texture.get_height())
		var target_w := float(texture.get_width()) * target_scale
		var center := Vector2(
			row_start_x + slot_width * (float(i) + 0.5),
			RIM_DUCK_Y * display_scale + display_height * 0.5,
		)
		var is_lit := i < _rim_ducks_visible
		var celebration_age := _rim_duck_celebration_ages[i]
		var celebration_t := clampf(celebration_age / RIM_DUCK_CELEBRATION_DURATION, 0.0, 1.0)
		var bounce_scale := 1.0
		if celebration_age >= 0.0:
			bounce_scale += 0.13 * sin(celebration_t * PI)
			var glow_size := Vector2(target_w, display_height) * (1.10 + 0.08 * sin(celebration_t * PI))
			var glow_rect := Rect2(center - glow_size * 0.5, glow_size)
			if center.x > screen_size.x * 0.5:
				glow_rect = Rect2(glow_rect.position.x + glow_rect.size.x, glow_rect.position.y, -glow_rect.size.x, glow_rect.size.y)
			draw_texture_rect(
				texture,
				glow_rect,
				false,
				Color(1.0, 0.88, 0.35, 0.30 * (1.0 - celebration_t)),
			)
		var duck_size := Vector2(target_w, display_height) * bounce_scale
		var rect := Rect2(center - duck_size * 0.5, duck_size)
		# Both source ducks face right. Ducks on the right half turn inward.
		if center.x > screen_size.x * 0.5:
			rect = Rect2(rect.position.x + rect.size.x, rect.position.y, -rect.size.x, rect.size.y)
		var modulate := Color.WHITE if is_lit else Color(0.14, 0.17, 0.24, 0.42)
		draw_texture_rect(texture, rect, false, modulate)


func _draw_target(target: BubbleTarget) -> void:
	if target.active:
		# Draw bubble sprite texture
		var tex: Texture2D = _bubble_textures[target.texture_index]
		var cue_scale := 1.0 + 0.08 * sin(target.phase)
		var center := target.center + Vector2(0.0, 5.0 * sin(target.phase * 0.7))
		var draw_size := tex.get_size() * target.scale_factor * cue_scale
		var draw_pos := center - draw_size * 0.5
		draw_texture_rect(tex, Rect2(draw_pos, draw_size), false)
		if target.wave_age >= target.wave_delay:
			var wave_t := clampf((target.wave_age - target.wave_delay) / BUBBLE_WAVE_DURATION, 0.0, 1.0)
			var wave_texture: Texture2D = _effect_textures[&"pop_ring_large"]
			var wave_size := wave_texture.get_size() * lerpf(0.45, 1.05, wave_t)
			var wave_alpha := 0.65 * (1.0 - wave_t)
			draw_texture_rect(
				wave_texture,
				Rect2(center - wave_size * 0.5, wave_size),
				false,
				Color(1.0, 1.0, 1.0, wave_alpha),
			)
		return
	if target.pop_age >= 0.0:
		if target.giant_bubble:
			var giant_t := clampf(target.pop_age / GIANT_BUBBLE_DURATION, 0.0, 1.0)
			var giant_texture: Texture2D = _bubble_textures[target.texture_index]
			var giant_radius := lerpf(target.visual_radius, GIANT_BUBBLE_MAX_RADIUS, ease(giant_t, 0.45))
			var giant_size := Vector2.ONE * giant_radius * 2.0
			var giant_alpha := 1.0 - 0.25 * giant_t
			draw_texture_rect(
				giant_texture,
				Rect2(target.center - giant_size * 0.5, giant_size),
				false,
				Color(1.0, 1.0, 1.0, giant_alpha),
			)
			var ring_texture: Texture2D = _effect_textures[&"pop_ring_large"]
			var ring_size := giant_size * 1.12
			draw_texture_rect(
				ring_texture,
				Rect2(target.center - ring_size * 0.5, ring_size),
				false,
				Color(1.0, 1.0, 1.0, 0.7 * (1.0 - giant_t)),
			)
			return
		# Draw effect texture for pop
		var effect_duration := EVENT_EFFECT_DURATION if target.event_pop else POP_EFFECT_DURATION
		var t := clampf(target.pop_age / effect_duration, 0.0, 1.0)
		var alpha := 1.0 - t
		var tex_name: StringName
		if target.event_pop:
			tex_name = &"bubble_burst"
		else:
			tex_name = &"pop_ring_small" if target.id % 2 == 0 else &"foam_cloud"
		var tex: Texture2D = _effect_textures.get(tex_name, _effect_textures[&"pop_ring_small"])
		var effect_scale := lerpf(0.8, 2.0 if target.event_pop else 1.4, t)
		var draw_size := tex.get_size() * effect_scale
		var draw_pos := target.center - draw_size * 0.5
		var mod := Color(1.0, 1.0, 1.0, alpha)
		draw_texture_rect(tex, Rect2(draw_pos, draw_size), false, mod)


func _draw_king_duck() -> void:
	# King duck rises for 2.4 seconds, then bounces before shared completion.
	var rise_t := clampf(_king_duck_bounce_age / KING_DUCK_RISE_DURATION, 0.0, 1.0)
	var bounce_t := clampf(
		(_king_duck_bounce_age - KING_DUCK_RISE_DURATION) / (KING_DUCK_BOUNCE_DURATION - KING_DUCK_RISE_DURATION),
		0.0,
		1.0,
	)
	
	var duck_size := _megaduck_texture.get_size() * 0.7  # Scale megaduck to fit
	# Rise from below, then settle half a duck-height higher than the prior pose.
	var start_y := REFERENCE_SIZE.y + 100.0
	var end_y := REFERENCE_SIZE.y * 0.35 - duck_size.y * 0.5
	var y := lerpf(start_y, end_y, ease(rise_t, 0.4))
	
	# Bounce effect
	var bounce_offset := 0.0
	if bounce_t > 0.0:
		bounce_offset = 30.0 * sin(bounce_t * PI * 4.0) * (1.0 - bounce_t)
	
	var duck_pos := Vector2(REFERENCE_SIZE.x * 0.5 - duck_size.x * 0.5, y + bounce_offset)
	var duck_rect := Rect2(duck_pos, duck_size)
	# The bathroom backdrop is not part of the bathtub foreground. Crop away only
	# the portion below the tub so the rising sprite cannot appear on that backdrop.
	var bathtub_bottom_y := TUB_Y + TUB_HEIGHT
	if duck_rect.position.y >= bathtub_bottom_y:
		return
	var visible_height := minf(duck_rect.end.y, bathtub_bottom_y) - duck_rect.position.y
	var visible_rect := Rect2(duck_rect.position, Vector2(duck_rect.size.x, visible_height))
	var source_height := _megaduck_texture.get_height() * visible_height / duck_rect.size.y
	draw_texture_rect_region(
		_megaduck_texture,
		visible_rect,
		Rect2(0.0, 0.0, _megaduck_texture.get_width(), source_height),
	)


func _draw_king_duck_foreground_water() -> void:
	# Re-draw exactly the same scaled/tiled water pixels over the duck. The old
	# centered stretched crop included the lower rim and caused a visible rectangle.
	var source_size := _tub_middle_strip.get_size()
	var strip_scale := TUB_HEIGHT / float(source_size.y)
	var source_water_start_y := (KING_DUCK_WATERLINE_Y - TUB_Y) / strip_scale
	var source_water_end_y := float(source_size.y)
	# Include the lower rim so the duck remains behind the complete foreground tub.
	var source_region := Rect2(0.0, source_water_start_y, source_size.x, source_water_end_y - source_water_start_y)
	var strip_width := source_size.x * strip_scale
	var foreground_height := source_region.size.y * strip_scale
	var cap_scale := TUB_HEIGHT / float(_tub_left_cap.get_height())
	var x := float(_tub_left_cap.get_width()) * cap_scale - _background_scroll
	while x < REFERENCE_SIZE.x:
		draw_texture_rect_region(
			_tub_middle_strip,
			Rect2(x, KING_DUCK_WATERLINE_Y, strip_width, foreground_height),
			source_region,
		)
		x += strip_width

	var foam: Texture2D = _effect_textures[&"foam_cloud"]
	for index in range(5):
		var foam_size := foam.get_size() * 0.52
		var foam_x := REFERENCE_SIZE.x * 0.5 - 370.0 + float(index) * 175.0
		var foam_y := KING_DUCK_WATERLINE_Y - foam_size.y * 0.45 + 12.0 * sin(_king_duck_bounce_age * 4.0 + index)
		draw_texture_rect(foam, Rect2(foam_x, foam_y, foam_size.x, foam_size.y), false)


func _draw_finale() -> void:
	# Bubble/foam celebration around the king duck
	var t := clampf(_finale_age / 1.5, 0.0, 1.0)
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		var center := REFERENCE_SIZE * 0.5 + Vector2(cos(angle), sin(angle)) * lerpf(60.0, 560.0, t)
		var bob := 15.0 * sin(_finale_age * 5.0 + float(index))
		# Draw small bubble sprites in a circle
		var tex: Texture2D = _bubble_textures[index % _bubble_textures.size()]
		var sprite_size := Vector2(50.0, 50.0) * (1.0 - t * 0.3)
		draw_texture_rect(tex, Rect2(center - sprite_size * 0.5 + Vector2(0.0, bob), sprite_size), false, Color(1.0, 1.0, 1.0, 0.55 * (1.0 - t * 0.35)))
