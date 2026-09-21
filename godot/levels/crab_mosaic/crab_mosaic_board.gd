class_name CrabMosaicBoard
extends Control

signal sound_requested(sound_id: StringName)
signal treasure_arrived(progress: int)
signal mosaic_completed

const TARGET_HIT_RADIUS := 72.0
const TARGET_LIFETIME := 10.0
const DEPARTURE_DURATION := 2.0
const TRANSITION_DURATION := 0.42
const FINAL_ARRIVAL_DURATION := 0.68
const FINALE_DURATION := 3.6
const FINALE_TRAVEL_DURATION := 0.9
const FINALE_HOPS_START := 0.9
const FINALE_HOP_DURATION := 0.52
const FINALE_HOP_COUNT := 3
const SEAWEED_EMIT_DURATION := 0.55
const REACTION_DURATION := 0.90
const MIN_TARGET_SLOTS := 4
const MAX_TARGET_SLOTS := 6
const SEAWEED_OFFSPRING_COUNT := 2

const SHORE_BACKDROP := preload("res://assets/gameplay/crab-mosaic/crab_mosaic_shore_backdrop.png")
const CRAB_TEXTURE := preload("res://assets/gameplay/crab-mosaic/crab_mosaic_crab.png")
const BASE_TEXTURE := preload("res://assets/gameplay/crab-mosaic/crab_mosaic_base.png")
const STONE_TEXTURES := [preload("res://assets/gameplay/crab-mosaic/crab_mosaic_stone_01.png"), preload("res://assets/gameplay/crab-mosaic/crab_mosaic_stone_02.png"), preload("res://assets/gameplay/crab-mosaic/crab_mosaic_stone_03.png"), preload("res://assets/gameplay/crab-mosaic/crab_mosaic_stone_04.png"), preload("res://assets/gameplay/crab-mosaic/crab_mosaic_stone_05.png"), preload("res://assets/gameplay/crab-mosaic/crab_mosaic_stone_06.png")]
const SHELL_CLOSED_TEXTURES: Array[Texture2D] = [
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_shell_coral_closed.png"),
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_shell_golden_mustard_closed.png"),
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_shell_muted_lilac_closed.png"),
]
const SHELL_OPEN_TEXTURES: Array[Texture2D] = [
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_shell_coral_open.png"),
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_shell_golden_mustard_open.png"),
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_shell_muted_lilac_open.png"),
]
const SEAWEED_KNOT := preload("res://assets/gameplay/crab-mosaic/crab_mosaic_seaweed_knot.png")
const MOSAIC_ALBEDOS: Array[Texture2D] = [
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_picture_01_albedo.png"),
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_picture_02_albedo.png"),
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_picture_03_albedo.png"),
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_picture_04_albedo.png"),
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_picture_05_albedo.png"),
]
const MOSAIC_ID_MAPS: Array[Texture2D] = [
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_picture_01_id.png"),
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_picture_02_id.png"),
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_picture_03_id.png"),
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_picture_04_id.png"),
	preload("res://assets/gameplay/crab-mosaic/crab_mosaic_picture_05_id.png"),
]
const KATRAN_RECOLOR_SHADER := preload("res://levels/crab_mosaic/katran_recolor.gdshader")
const MOSAIC_VARIANT_DATA := preload("res://assets/gameplay/crab-mosaic/crab_mosaic_variant_data.gd")
const STONE_EFFECT := preload("res://assets/gameplay/crab-mosaic/crab_mosaic_effect_stone.png")
const SHELL_EFFECT := preload("res://assets/gameplay/crab-mosaic/crab_mosaic_effect_shell.png")
const SEAWEED_EFFECT := preload("res://assets/gameplay/crab-mosaic/crab_mosaic_effect_seaweed.png")

const STONE_REWARD_COLORS: Array[Color] = [
	Color("#ef785e"), Color("#efb73f"), Color("#f2a273"),
	Color("#b99acb"), Color("#dc654f"), Color("#d99b32"),
]
const SHELL_REWARD_COLORS: Array[Color] = [Color("#ef785e"), Color("#efb73f"), Color("#b99acb")]

enum TargetKind { STONE, SHELL, SEAWEED_KNOT }

class MosaicTarget:
	var id := 0
	var kind := TargetKind.STONE
	var center := Vector2.ZERO
	var phase := 0
	var ready := true
	var transition_age := -1.0
	var ready_age := 0.0
	var departing := false
	var departure_age := -1.0
	var pulse_age := 0.0
	var spawn_slot_cost := 1
	var stone_index := 0
	var shell_colorway_index := 0
	var reward_color := Color.WHITE
	var emitting := false
	var emit_origin := Vector2.ZERO
	var emit_age := 0.0

class FlyingUnit:
	var origin := Vector2.ZERO
	var delay := 0.0
	var age := 0.0
	var color := Color.WHITE
	var destination_piece_indices: Array[int] = []
	var completed_piece_indices: Array[int] = []

class ReactionEffect:
	var center := Vector2.ZERO
	var kind := TargetKind.STONE
	var age := 0.0

@export var deterministic_seed := 11301
@export var total_taps_target := 68

var total_mosaic_pebbles := 0

var _rng := RandomNumberGenerator.new()
var _targets: Array[MosaicTarget] = []
var _flying_units: Array[FlyingUnit] = []
var _reaction_effects: Array[ReactionEffect] = []
var _next_target_id := 0
var _progress := 0
var _input_enabled := true
var _spawning_enabled := true
var _completion_emitted := false
var _completion_signal_emitted := false
var _final_arrival_age := -1.0
var _finale_age := -1.0
var _crab_admire_age := -1.0
var _mosaic_piece_colors: Array[Color] = []
var _mosaic_piece_centers: Array[Vector2] = []
var _mosaic_variant_index := 0
var _katran_display: TextureRect
var _katran_material: ShaderMaterial
var _palette_image: Image
var _palette_texture: ImageTexture
var _layout_size := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout_size = size
	_create_katran_display()
	resized.connect(_on_resized)
	reset_run()

func _process(delta: float) -> void:
	_advance(delta)

func _create_katran_display() -> void:
	if _palette_image == null:
		_palette_image = Image.create(256, 1, false, Image.FORMAT_RGBA8)
		_palette_image.fill(Color.TRANSPARENT)
	if _palette_texture == null:
		_palette_texture = ImageTexture.create_from_image(_palette_image)
	_katran_material = ShaderMaterial.new()
	_katran_material.shader = KATRAN_RECOLOR_SHADER
	_katran_material.set_shader_parameter("id_map", MOSAIC_ID_MAPS[0])
	_katran_material.set_shader_parameter("reward_palette", _palette_texture)
	_katran_display = TextureRect.new()
	_katran_display.name = "MosaicComposite"
	_katran_display.texture = MOSAIC_ALBEDOS[0]
	_katran_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_katran_display.stretch_mode = TextureRect.STRETCH_SCALE
	_katran_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_katran_display.material = _katran_material
	add_child(_katran_display)
	_update_katran_layout()

func _on_resized() -> void:
	var previous_size := _layout_size
	_layout_size = size
	if previous_size.x > 0.0 and previous_size.y > 0.0 and not previous_size.is_equal_approx(size):
		_reflow_live_positions(previous_size)
	_update_katran_layout()
	queue_redraw()

func _reflow_live_positions(previous_size: Vector2) -> void:
	var previous_safe := _safe_rect_for_size(previous_size)
	var current_safe := _safe_rect()
	var active_targets: Array[MosaicTarget] = _targets.duplicate()
	_targets.clear()
	for target: MosaicTarget in active_targets:
		var normalized: Vector2 = (target.center - previous_safe.position) / previous_safe.size
		var preferred: Vector2 = current_safe.position + normalized * current_safe.size
		target.center = _find_spawn_position(target.kind, preferred)
		if target.emitting:
			var origin_normalized: Vector2 = (target.emit_origin - previous_safe.position) / previous_safe.size
			target.emit_origin = current_safe.position + origin_normalized * current_safe.size
		_targets.append(target)
	for unit: FlyingUnit in _flying_units:
		var normalized: Vector2 = (unit.origin - previous_safe.position) / previous_safe.size
		unit.origin = current_safe.position + normalized * current_safe.size
	for effect: ReactionEffect in _reaction_effects:
		var normalized: Vector2 = (effect.center - previous_safe.position) / previous_safe.size
		effect.center = current_safe.position + normalized * current_safe.size

func _update_katran_layout() -> void:
	if _katran_display == null:
		return
	var base_rect := _mosaic_rect()
	var fish_rect := base_rect.grow_individual(
		-base_rect.size.x * 0.17,
		-base_rect.size.y * 0.19,
		-base_rect.size.x * 0.10,
		-base_rect.size.y * 0.19
	)
	_katran_display.position = fish_rect.position
	_katran_display.size = fish_rect.size

func _reset_mosaic_palette() -> void:
	if _palette_image == null:
		_palette_image = Image.create(256, 1, false, Image.FORMAT_RGBA8)
	_mosaic_piece_colors.clear()
	for index in total_mosaic_pebbles:
		_mosaic_piece_colors.append(Color.TRANSPARENT)
	_palette_image.fill(Color.TRANSPARENT)
	if _palette_texture != null:
		_palette_texture.update(_palette_image)

func _set_piece_color(index: int, color: Color) -> void:
	if index < 0 or index >= total_mosaic_pebbles:
		return
	_mosaic_piece_colors[index] = color
	_palette_image.set_pixel(index + 1, 0, color)
	if _palette_texture != null:
		_palette_texture.update(_palette_image)

func _select_mosaic_variant() -> void:
	_mosaic_variant_index = _rng.randi_range(0, MOSAIC_ALBEDOS.size() - 1)
	if _katran_display != null:
		_katran_display.texture = MOSAIC_ALBEDOS[_mosaic_variant_index]
	if _katran_material != null:
		_katran_material.set_shader_parameter("id_map", MOSAIC_ID_MAPS[_mosaic_variant_index])
	_cache_mosaic_piece_centers()

func _cache_mosaic_piece_centers() -> void:
	total_mosaic_pebbles = MOSAIC_VARIANT_DATA.PEBBLE_COUNTS[_mosaic_variant_index]
	_mosaic_piece_centers.assign(MOSAIC_VARIANT_DATA.PEBBLE_CENTERS[_mosaic_variant_index])

func _mosaic_piece_center(piece_index: int) -> Vector2:
	if _mosaic_piece_centers.is_empty():
		return _mosaic_rect().get_center()
	var normalized := _mosaic_piece_centers[clampi(piece_index, 0, _mosaic_piece_centers.size() - 1)]
	return _katran_display.position + normalized * _katran_display.size

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		accept_event()
		tap_at(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		tap_at(event.position)

func reset_run() -> void:
	_rng.seed = deterministic_seed
	_select_mosaic_variant()
	_targets.clear()
	_flying_units.clear()
	_reaction_effects.clear()
	_next_target_id = 0
	_progress = 0
	_input_enabled = true
	_spawning_enabled = true
	_completion_emitted = false
	_completion_signal_emitted = false
	_final_arrival_age = -1.0
	_finale_age = -1.0
	_crab_admire_age = -1.0
	_reset_mosaic_palette()
	for index in MIN_TARGET_SLOTS:
		_spawn_target(_initial_kind(index))
	queue_redraw()

func start_run_with_seed(seed: int) -> void:
	deterministic_seed = seed
	reset_run()

func set_input_enabled(enabled: bool) -> void:
	_input_enabled = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func tap_at(position: Vector2) -> bool:
	if not _input_enabled or _completion_emitted:
		return false
	var target := _target_at(position)
	if target == null:
		return false
	_activate_target(target)
	return true

func advance_for_test(delta: float) -> void:
	_advance(delta)

func get_progress() -> int:
	return _progress

func get_goal() -> int:
	return maxi(1, total_taps_target)

func get_katran_dot_count() -> int:
	return total_mosaic_pebbles

func get_mosaic_variant_index() -> int:
	return _mosaic_variant_index

func get_emitting_target_count() -> int:
	var count := 0
	for target in _targets:
		if target.emitting:
			count += 1
	return count

func get_reaction_effect_count() -> int:
	return _reaction_effects.size()

func get_mosaic_piece_color(index: int) -> Color:
	return _mosaic_piece_colors[index] if index >= 0 and index < _mosaic_piece_colors.size() else Color.TRANSPARENT

func set_full_mosaic_for_test() -> void:
	_progress = get_goal()
	for index in total_mosaic_pebbles:
		_set_piece_color(index, STONE_REWARD_COLORS[index % STONE_REWARD_COLORS.size()])

func is_complete() -> bool:
	return _completion_emitted

func get_target_count() -> int:
	return _targets.size()

func get_target_slot_count() -> int:
	var slots := 0
	for target in _targets:
		slots += target.spawn_slot_cost
	return slots

func get_ready_target_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for target in _targets:
		if target.ready:
			centers.append(target.center)
	return centers

func get_target_kinds() -> Array[int]:
	var kinds: Array[int] = []
	for target in _targets:
		kinds.append(target.kind)
	return kinds

func get_ready_target_centers_of_kind(kind: int) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for target in _targets:
		if target.kind == kind and target.ready:
			centers.append(target.center)
	return centers

func get_target_phase_at(position: Vector2) -> int:
	var target := _any_target_at(position)
	return target.phase if target != null else -1

func get_target_ready_age_at(position: Vector2) -> float:
	var target := _any_target_at(position)
	return target.ready_age if target != null else -1.0

func get_target_reward_color_at(position: Vector2) -> Color:
	var target := _any_target_at(position)
	return target.reward_color if target != null else Color.TRANSPARENT

func get_transition_target_count() -> int:
	var count := 0
	for target in _targets:
		if not target.ready:
			count += 1
	return count

func hit_areas_are_separated() -> bool:
	for left_index in _targets.size():
		for right_index in range(left_index + 1, _targets.size()):
			if _targets[left_index].center.distance_to(_targets[right_index].center) < TARGET_HIT_RADIUS * 2.0:
				return false
	return true

func _advance(delta: float) -> void:
	var needs_redraw := false
	var final_started_this_frame := false
	var finale_started_this_frame := false
	for unit in _flying_units.duplicate():
		unit.age += delta
		needs_redraw = true
		if unit.age >= unit.delay + 0.5:
			_flying_units.erase(unit)
			_arrive_unit(unit)
			final_started_this_frame = _final_arrival_age == 0.0
	for effect in _reaction_effects.duplicate():
		effect.age += delta
		needs_redraw = true
		if effect.age >= REACTION_DURATION:
			_reaction_effects.erase(effect)
	for target in _targets.duplicate():
		target.pulse_age += delta
		if target.emitting:
			target.emit_age += delta
			needs_redraw = true
			if target.emit_age >= SEAWEED_EMIT_DURATION:
				target.emitting = false
				target.ready = true
				target.ready_age = 0.0
		elif target.transition_age >= 0.0:
			target.transition_age += delta
			needs_redraw = true
			if target.transition_age >= TRANSITION_DURATION:
				_finish_transition(target)
		elif target.departing:
			target.departure_age += delta
			needs_redraw = true
			if target.departure_age >= DEPARTURE_DURATION:
				_targets.erase(target)
		elif target.ready:
			target.ready_age += delta
			if target.ready_age >= TARGET_LIFETIME and not target.departing:
				target.departing = true
				target.departure_age = 0.0
	if _crab_admire_age >= 0.0:
		_crab_admire_age += delta
		if _crab_admire_age > 0.75:
			_crab_admire_age = -1.0
		needs_redraw = true
	if _final_arrival_age >= 0.0 and not final_started_this_frame:
		_final_arrival_age += delta
		needs_redraw = true
		if _final_arrival_age >= FINAL_ARRIVAL_DURATION:
			_finish_mosaic()
			finale_started_this_frame = true
	if _finale_age >= 0.0 and not finale_started_this_frame:
		_finale_age += delta
		_update_katran_layout()
		needs_redraw = true
		if _finale_age >= FINALE_DURATION and not _completion_signal_emitted:
			_completion_signal_emitted = true
			mosaic_completed.emit()
	if _spawning_enabled and _final_arrival_age < 0.0:
		_spawn_until_readable()
	if needs_redraw:
		queue_redraw()

func _initial_kind(index: int) -> int:
	return [TargetKind.STONE, TargetKind.SHELL, TargetKind.STONE, TargetKind.SEAWEED_KNOT][index]

func _spawn_until_readable() -> void:
	while get_target_slot_count() < MIN_TARGET_SLOTS:
		_spawn_target(_random_kind())

func _random_kind() -> int:
	var roll := _rng.randi_range(0, 9)
	if roll <= 5:
		return TargetKind.STONE
	if roll <= 8:
		return TargetKind.SHELL
	return TargetKind.SEAWEED_KNOT

func _spawn_target(kind: int, preferred_center := Vector2.INF) -> MosaicTarget:
	var slot_cost := SEAWEED_OFFSPRING_COUNT if kind == TargetKind.SEAWEED_KNOT else 1
	if get_target_slot_count() + slot_cost > MAX_TARGET_SLOTS:
		return null
	var target := MosaicTarget.new()
	target.id = _next_target_id
	_next_target_id += 1
	target.kind = kind
	target.spawn_slot_cost = slot_cost
	target.stone_index = target.id % STONE_TEXTURES.size()
	if kind == TargetKind.SHELL:
		target.shell_colorway_index = _rng.randi_range(0, SHELL_REWARD_COLORS.size() - 1)
		target.reward_color = SHELL_REWARD_COLORS[target.shell_colorway_index]
	else:
		target.reward_color = STONE_REWARD_COLORS[target.stone_index]
	target.center = _find_spawn_position(kind, preferred_center)
	_targets.append(target)
	return target

func _find_spawn_position(kind: int, preferred_center: Vector2) -> Vector2:
	if preferred_center != Vector2.INF and _is_safe_target_center(preferred_center) and _suits_setting(preferred_center, kind) and _fits_target(preferred_center):
		return preferred_center
	for attempt in 40:
		var candidate := _candidate_for_kind(kind)
		if _is_safe_target_center(candidate) and _fits_target(candidate):
			return candidate
	for candidate in _fallback_positions(kind):
		if _is_safe_target_center(candidate) and _suits_setting(candidate, kind) and _fits_target(candidate):
			return candidate
	return _safe_rect().get_center()

func _candidate_for_kind(kind: int) -> Vector2:
	var safe := _safe_rect()
	match kind:
		TargetKind.STONE:
			return Vector2(_rng.randf_range(safe.position.x, safe.end.x * 0.72), _rng.randf_range(safe.position.y + safe.size.y * 0.46, safe.end.y))
		TargetKind.SHELL:
			return Vector2(_rng.randf_range(safe.position.x + safe.size.x * 0.38, safe.end.x), _rng.randf_range(safe.position.y + safe.size.y * 0.32, safe.position.y + safe.size.y * 0.76))
		_:
			return Vector2(_rng.randf_range(safe.position.x + safe.size.x * 0.66, safe.end.x), _rng.randf_range(safe.position.y, safe.position.y + safe.size.y * 0.46))

func _fallback_positions(kind: int) -> Array[Vector2]:
	var safe := _safe_rect()
	match kind:
		TargetKind.STONE:
			return [safe.position + safe.size * Vector2(0.16, 0.78), safe.position + safe.size * Vector2(0.78, 0.84), safe.position + safe.size * Vector2(0.40, 0.67)]
		TargetKind.SHELL:
			return [safe.position + safe.size * Vector2(0.74, 0.52), safe.position + safe.size * Vector2(0.88, 0.66), safe.position + safe.size * Vector2(0.56, 0.58)]
		_:
			return [safe.position + safe.size * Vector2(0.80, 0.24), safe.position + safe.size * Vector2(0.93, 0.36)]

func _safe_rect() -> Rect2:
	return _safe_rect_for_size(size)

func _safe_rect_for_size(board_size: Vector2) -> Rect2:
	var margin := clampf(minf(board_size.x, board_size.y) * 0.09, TARGET_HIT_RADIUS + 8.0, 115.0)
	return Rect2(Vector2(margin, margin), Vector2(maxf(1.0, board_size.x - margin * 2.0), maxf(1.0, board_size.y - margin * 2.0)))

func _rest_mosaic_rect() -> Rect2:
	var safe := _safe_rect()
	var width := minf(safe.size.x * 0.40, safe.size.y * 0.62)
	return Rect2(safe.position + safe.size * Vector2(0.18, 0.39) - Vector2(width * 0.5, width * 0.29), Vector2(width, width * 0.58))

func _rest_crab_rect() -> Rect2:
	var safe := _safe_rect()
	var width := minf(safe.size.x * 0.31, safe.size.y * 0.36)
	return Rect2(safe.position + safe.size * Vector2(0.16, 0.20) - Vector2(width * 0.5, width * 0.34), Vector2(width, width * 0.68))

func _rest_group_rect() -> Rect2:
	return _rest_mosaic_rect().merge(_rest_crab_rect())

func _finale_scale() -> float:
	var group := _rest_group_rect()
	var bounds := _safe_rect().size * 0.74
	return minf(bounds.x / group.size.x, bounds.y / group.size.y)

func _finale_rect(rest_rect: Rect2) -> Rect2:
	if _finale_age < 0.0:
		return rest_rect
	var group := _rest_group_rect()
	var scale_factor := _finale_scale()
	var final_position := _safe_rect().get_center() + (rest_rect.position - group.get_center()) * scale_factor
	var final_rect := Rect2(final_position, rest_rect.size * scale_factor)
	var travel := ease(clampf(_finale_age / FINALE_TRAVEL_DURATION, 0.0, 1.0), -1.8)
	return Rect2(rest_rect.position.lerp(final_rect.position, travel), rest_rect.size.lerp(final_rect.size, travel))

func _mosaic_rect() -> Rect2:
	return _finale_rect(_rest_mosaic_rect())

func _crab_rect() -> Rect2:
	return _finale_rect(_rest_crab_rect())

func _finale_group_rect() -> Rect2:
	return _finale_rect(_rest_group_rect())

func _crab_finale_hop_offset() -> float:
	if _finale_age < FINALE_HOPS_START:
		return 0.0
	var hop_time := _finale_age - FINALE_HOPS_START
	var hop_index := floori(hop_time / FINALE_HOP_DURATION)
	if hop_index < 0 or hop_index >= FINALE_HOP_COUNT:
		return 0.0
	var phase := fmod(hop_time, FINALE_HOP_DURATION) / FINALE_HOP_DURATION
	return -sin(phase * PI) * _crab_rect().size.y * 0.13

func _suits_setting(candidate: Vector2, kind: int) -> bool:
	match kind:
		TargetKind.STONE:
			return candidate.y >= size.y * 0.42
		TargetKind.SHELL:
			return candidate.x >= size.x * 0.36
		_:
			return candidate.x >= size.x * 0.60 and candidate.y <= size.y * 0.50

func _is_safe_target_center(candidate: Vector2) -> bool:
	var safe := _safe_rect()
	if not safe.grow(-TARGET_HIT_RADIUS).has_point(candidate):
		return false
	if _mosaic_rect().grow(TARGET_HIT_RADIUS * 1.30).has_point(candidate):
		return false
	return not _crab_rect().grow(TARGET_HIT_RADIUS * 0.95).has_point(candidate)

func _fits_target(candidate: Vector2) -> bool:
	for target in _targets:
		if target.center.distance_to(candidate) < TARGET_HIT_RADIUS * 2.15:
			return false
	return true

func _target_at(position: Vector2) -> MosaicTarget:
	for target in _targets:
		if target.ready and target.center.distance_to(position) <= TARGET_HIT_RADIUS:
			return target
	return null

func _any_target_at(position: Vector2) -> MosaicTarget:
	for target in _targets:
		if target.center.distance_to(position) <= TARGET_HIT_RADIUS:
			return target
	return null

func _activate_target(target: MosaicTarget) -> void:
	target.departing = false
	target.departure_age = -1.0
	target.ready = false
	target.transition_age = 0.0
	_add_reaction_effect(target.center, target.kind)
	sound_requested.emit(&"pop" if target.kind == TargetKind.STONE else &"pop_event" if target.kind == TargetKind.SHELL else &"bubbles")
	queue_redraw()

func _finish_transition(target: MosaicTarget) -> void:
	if not _targets.has(target):
		return
	target.transition_age = -1.0
	if target.kind == TargetKind.SHELL and target.phase == 0:
		target.phase = 1
		target.ready = true
		target.ready_age = 0.0
		return
	_targets.erase(target)
	if target.kind == TargetKind.SEAWEED_KNOT:
		_emit_knot_offspring(target.center)
		return
	_award_units(target.center, 3 if target.kind == TargetKind.SHELL else 1, target.reward_color)

func _emit_knot_offspring(center: Vector2) -> void:
	for offset in [Vector2(-TARGET_HIT_RADIUS * 1.15, -TARGET_HIT_RADIUS * 0.55), Vector2(TARGET_HIT_RADIUS * 1.15, TARGET_HIT_RADIUS * 0.55)]:
		var child := _spawn_target(TargetKind.STONE if _rng.randi_range(0, 1) == 0 else TargetKind.SHELL, center + offset)
		if child == null:
			continue
		child.emitting = true
		child.ready = false
		child.emit_origin = center
		child.emit_age = 0.0

func _award_units(origin: Vector2, units: int, color: Color) -> void:
	if _completion_emitted:
		return
	for index in units:
		if _progress + _flying_units.size() >= get_goal():
			break
		var flying := FlyingUnit.new()
		flying.origin = origin
		flying.delay = float(index) * 0.12
		flying.color = color
		var reserved_unit := _progress + _flying_units.size()
		var completed_before := floori(float(reserved_unit * total_mosaic_pebbles) / float(get_goal()))
		var completed_after := floori(float((reserved_unit + 1) * total_mosaic_pebbles) / float(get_goal()))
		for piece_index in range(completed_before, completed_after):
			flying.completed_piece_indices.append(piece_index)
			flying.destination_piece_indices.append(piece_index)
		if flying.destination_piece_indices.is_empty():
			flying.destination_piece_indices.append(mini(completed_after, total_mosaic_pebbles - 1))
		_flying_units.append(flying)
	queue_redraw()

func _arrive_unit(unit: FlyingUnit) -> void:
	if _progress >= get_goal():
		return
	_progress += 1
	for piece_index in unit.completed_piece_indices:
		_set_piece_color(piece_index, unit.color)
	_crab_admire_age = 0.0
	treasure_arrived.emit(_progress)
	if _progress >= get_goal() and _flying_units.is_empty():
		_spawning_enabled = false
		_input_enabled = false
		_final_arrival_age = 0.0

func _add_reaction_effect(center: Vector2, kind: int) -> void:
	var effect := ReactionEffect.new()
	effect.center = center
	effect.kind = kind
	_reaction_effects.append(effect)

func _finish_mosaic() -> void:
	if _completion_emitted:
		return
	_completion_emitted = true
	_final_arrival_age = -1.0
	_finale_age = 0.0
	_input_enabled = false
	_spawning_enabled = false
	for target in _targets:
		target.emitting = false
		target.ready = false
		target.departing = true
		# Clear the playfield as the enlarged finale group reaches center.
		target.departure_age = maxf(0.0, DEPARTURE_DURATION - FINALE_TRAVEL_DURATION + 0.001)
	_update_katran_layout()
	queue_redraw()

func _draw() -> void:
	_draw_backdrop()
	if _completion_emitted:
		var pulse := 0.18 + sin(_finale_age * TAU * 1.35) * 0.04
		draw_circle(_mosaic_rect().get_center(), _mosaic_rect().size.x * 0.44, Color(1.0, 0.95, 0.66, pulse))
	_draw_mosaic_and_crab()
	for target in _targets:
		if target.emitting:
			_draw_emitted_target(target)
		else:
			_draw_target(target)
	_draw_reaction_effects()
	_draw_arrivals()

func _draw_backdrop() -> void:
	var texture_size := SHORE_BACKDROP.get_size()
	var scale_factor := maxf(size.x / texture_size.x, size.y / texture_size.y)
	var drawn_size := texture_size * scale_factor
	var rect := Rect2(Vector2((size.x - drawn_size.x) * 0.5, size.y - drawn_size.y), drawn_size)
	draw_texture_rect(SHORE_BACKDROP, rect, false)

func _draw_mosaic_and_crab() -> void:
	var base_rect := _mosaic_rect()
	draw_texture_rect(BASE_TEXTURE, base_rect, false)
	var crab_rect := _crab_rect()
	crab_rect.position.y += _crab_finale_hop_offset()
	if _crab_admire_age >= 0.0:
		crab_rect.position.y -= clampf(_crab_admire_age * 24.0, 0.0, 14.0)
	draw_texture_rect(CRAB_TEXTURE, crab_rect, false)

func _draw_target(target: MosaicTarget) -> void:
	var alpha := 1.0
	var center := target.center
	if target.departing:
		var leave_t := clampf(target.departure_age / DEPARTURE_DURATION, 0.0, 1.0)
		alpha = 1.0 - leave_t
		center += Vector2(0, -TARGET_HIT_RADIUS * 0.55 * leave_t)
	var visual_size := Vector2.ONE * TARGET_HIT_RADIUS * 1.75 * (1.0 + sin(target.pulse_age * 3.0 + float(target.id)) * 0.04)
	draw_circle(center, TARGET_HIT_RADIUS * 1.08, Color(1.0, 0.95, 0.70, alpha * 0.30))
	var texture: Texture2D = STONE_TEXTURES[target.stone_index]
	if target.kind == TargetKind.SHELL:
		texture = SHELL_OPEN_TEXTURES[target.shell_colorway_index] if target.phase == 1 else SHELL_CLOSED_TEXTURES[target.shell_colorway_index]
	elif target.kind == TargetKind.SEAWEED_KNOT:
		texture = SEAWEED_KNOT
	draw_set_transform(center, 0.0, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-visual_size * 0.5, visual_size), false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if target.transition_age >= 0.0:
		var t := clampf(target.transition_age / TRANSITION_DURATION, 0.0, 1.0)
		draw_arc(center, TARGET_HIT_RADIUS * (1.30 + t * 0.25), 0.0, TAU, 24, Color(1.0, 0.94, 0.65, (1.0 - t) * alpha), 5.0, true)

func _draw_emitted_target(target: MosaicTarget) -> void:
	var t := clampf(target.emit_age / SEAWEED_EMIT_DURATION, 0.0, 1.0)
	var control := (target.emit_origin + target.center) * 0.5 + Vector2(0.0, -TARGET_HIT_RADIUS * 1.25)
	var point := target.emit_origin * pow(1.0 - t, 2.0) + control * 2.0 * (1.0 - t) * t + target.center * t * t
	var visual_size := Vector2.ONE * TARGET_HIT_RADIUS * lerpf(0.62, 1.72, ease(t, 0.4))
	var texture: Texture2D = STONE_TEXTURES[target.stone_index] if target.kind == TargetKind.STONE else SHELL_CLOSED_TEXTURES[target.shell_colorway_index]
	draw_circle(point, TARGET_HIT_RADIUS * lerpf(0.32, 0.90, t), Color(1.0, 0.95, 0.70, 0.22 * t))
	draw_texture_rect(texture, Rect2(point - visual_size * 0.5, visual_size), false, Color(1.0, 1.0, 1.0, t))

func _draw_reaction_effects() -> void:
	for effect in _reaction_effects:
		var t := clampf(effect.age / REACTION_DURATION, 0.0, 1.0)
		var texture: Texture2D = STONE_EFFECT
		if effect.kind == TargetKind.SHELL:
			texture = SHELL_EFFECT
		elif effect.kind == TargetKind.SEAWEED_KNOT:
			texture = SEAWEED_EFFECT
		var diameter := TARGET_HIT_RADIUS * lerpf(1.35, 2.65, ease(t, 0.35))
		var effect_size := Vector2.ONE * diameter
		if effect.kind == TargetKind.SEAWEED_KNOT:
			effect_size.y *= 1.25
		var alpha := 1.0 - smoothstep(0.55, 1.0, t)
		draw_texture_rect(texture, Rect2(effect.center - effect_size * 0.5, effect_size), false, Color(1.0, 1.0, 1.0, alpha))

func _draw_arrivals() -> void:
	for unit in _flying_units:
		if unit.age < unit.delay:
			continue
		var t := clampf((unit.age - unit.delay) / 0.5, 0.0, 1.0)
		for piece_index in unit.destination_piece_indices:
			var destination := _mosaic_piece_center(piece_index)
			var point := unit.origin.lerp(destination, ease(t, 0.35))
			draw_circle(point, lerpf(19.0, 8.0, t), unit.color)
			draw_circle(point - Vector2(3.0, 3.0), lerpf(6.0, 2.0, t), Color(1.0, 0.95, 0.82, 0.85))
