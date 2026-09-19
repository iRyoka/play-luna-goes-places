class_name SoupBoard
extends Control

signal ingredient_dropped(ingredient_id: StringName)
signal stirring_progressed(progress: float)
signal stirring_turn_completed
signal stirring_finished
signal salt_placed
signal salt_dispensed

const POT_CENTER := Vector2(1080.0, 600.0)
const POT_DROP_RADIUS := 300.0
const INGREDIENT_RADIUS := 120.0
const STIR_RADIUS := 350.0
const STIR_PASS_ANGLE := TAU
const STIR_MAX_ANGLE := TAU * 3.0
const STIR_TURN_COMPLETE_EPSILON := 0.02
const STIR_SEGMENT_COUNT := 3
const PROGRESS_STAR_SIZE := 46.0
const PROGRESS_STAR_BOUNCE_DURATION := 0.4
const SALT_HOME_POSITION := Vector2(1660.0, 760.0)
const SALT_POT_POSITION := POT_CENTER + Vector2(250.0, -160.0)
const SALT_SECOND_DISPENSE_DELAY := 0.75
const POT_ART_WIDTH := 680.0
const SOUP_ART_CENTER := Vector2(1076.0, 526.0)
const SOUP_ART_SIZE := Vector2(417.5, 240.5)
const INGREDIENT_ART_WIDTH := 255.0
const SPOON_REST_CENTER := POT_CENTER + Vector2(65.0, -70.0)
const SPOON_STIR_WOBBLE_RADIANS := 0.065
## Only the row's origin is soup's own.
const RECIPE_START := Vector2(696.0, 44.0)

const KITCHEN_BACKGROUND: Texture2D = preload("res://assets/gameplay/cooking/kitchen-background.png")
const POT_EMPTY: Texture2D = preload("res://assets/gameplay/cooking/pot-empty-large.png")
const POT_READY: Texture2D = preload("res://assets/gameplay/cooking/pot-ready-large.png")
const SOUP_SURFACE: Texture2D = preload("res://assets/gameplay/cooking/soup-surface.png")
const CARROT_ART: Texture2D = preload("res://assets/gameplay/cooking/carrot.png")
const TOMATO_ART: Texture2D = preload("res://assets/gameplay/cooking/tomato.png")
const SPOON_ART: Texture2D = preload("res://assets/gameplay/cooking/spoon.png")
const SALT_UPRIGHT_ART: Texture2D = preload("res://assets/gameplay/cooking/salt-upright.png")
const RECIPE_ART: Array[Texture2D] = [
	preload("res://assets/gameplay/cooking/recipe-carrot.png"),
	preload("res://assets/gameplay/cooking/recipe-tomato.png"),
	preload("res://assets/gameplay/cooking/recipe-stir.png"),
	preload("res://assets/gameplay/cooking/recipe-salt.png"),
]
const STIR_STAR_EMPTY: Texture2D = preload("res://assets/gameplay/cooking/stir-star-empty.png")
const STIR_STAR_FILLED: Texture2D = preload("res://assets/gameplay/cooking/stir-star-filled.png")

@onready var steer_ring_empty: TextureRect = %SteerRingEmpty
@onready var steer_ring_filled: TextureRect = %SteerRingFilled

var active_step := SoupStage.Step.CARROT
var carrot_position := Vector2(470.0, 750.0)
var tomato_position := Vector2(1690.0, 750.0)
var carrot_added := false
var tomato_added := false
var salt_tap_count := 0
var stir_progress := 0.0
var salt_position := SALT_HOME_POSITION
var salt_is_over_pot := false

var _dragged_ingredient: StringName
var _drag_position := Vector2.ZERO
var _stirring := false
var _stir_has_started := false
var _last_stir_angle := 0.0
var _spoon_angle := -PI * 0.5
var _stir_cue_start_angle := -PI * 0.5
var _stir_cue_direction := 0.0
var _stir_turn_progress := 0.0
var _dragging_salt := false
var _salt_taps_armed := false
var _seasoning_press_active := false
var _salt_can_dispense := true
var _salt_press_serial := 0
var _last_dispense_press_serial := -1
var _cue_time := 0.0
var _salt_shake_time := 0.0
var _stir_star_bounce: Array[float] = [0.0, 0.0, 0.0]
var _salt_star_bounce: Array[float] = [0.0, 0.0]


func _ready() -> void:
	# The stage opens input once the board is fully on screen, so a touch during a
	# recipe handover cannot reach a kitchen the child cannot see yet.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_update_stir_ring_art()


func configure_ingredient_positions(carrot_start: Vector2, tomato_start: Vector2) -> void:
	carrot_position = carrot_start
	tomato_position = tomato_start
	queue_redraw()


func set_active_step(next_step: SoupStage.Step) -> void:
	active_step = next_step
	_dragged_ingredient = &""
	_stirring = false
	if next_step == SoupStage.Step.STIR:
		_stir_has_started = false
		_stir_star_bounce = [0.0, 0.0, 0.0]
	if next_step == SoupStage.Step.SALT:
		_salt_star_bounce = [0.0, 0.0]
	_dragging_salt = false
	_salt_taps_armed = false
	_seasoning_press_active = false
	_salt_can_dispense = true
	_salt_press_serial = 0
	_last_dispense_press_serial = -1
	_update_stir_ring_art()
	queue_redraw()


func accept_ingredient(ingredient_id: StringName) -> void:
	if ingredient_id == &"carrot":
		carrot_added = true
	elif ingredient_id == &"tomato":
		tomato_added = true
	queue_redraw()


func register_salt_tap() -> void:
	salt_tap_count += 1
	_salt_shake_time = 0.32
	_salt_star_bounce[salt_tap_count - 1] = PROGRESS_STAR_BOUNCE_DURATION
	queue_redraw()


func _process(delta: float) -> void:
	_cue_time += delta
	if _salt_shake_time > 0.0:
		_salt_shake_time = maxf(0.0, _salt_shake_time - delta)
	for index: int in _stir_star_bounce.size():
		_stir_star_bounce[index] = maxf(0.0, _stir_star_bounce[index] - delta)
	for index: int in _salt_star_bounce.size():
		_salt_star_bounce[index] = maxf(0.0, _salt_star_bounce[index] - delta)
	_update_stir_ring_art()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_action(event.position)
		else:
			_finish_action(event.position)
	elif event is InputEventMouseMotion:
		_update_action(event.position)
	elif event is InputEventScreenTouch:
		if not OS.has_feature("mobile"):
			return
		if event.pressed:
			_begin_action(event.position)
		else:
			_finish_action(event.position)
	elif event is InputEventScreenDrag:
		if not OS.has_feature("mobile"):
			return
		_update_action(event.position)


func _begin_action(position: Vector2) -> void:
	if active_step == SoupStage.Step.CARROT and position.distance_to(carrot_position) <= INGREDIENT_RADIUS:
		_dragged_ingredient = &"carrot"
		_drag_position = position
		queue_redraw()
		return
	if active_step == SoupStage.Step.TOMATO and position.distance_to(tomato_position) <= INGREDIENT_RADIUS:
		_dragged_ingredient = &"tomato"
		_drag_position = position
		queue_redraw()
		return
	if active_step == SoupStage.Step.STIR and position.distance_to(POT_CENTER) <= STIR_RADIUS:
		_stirring = true
		_stir_has_started = true
		_last_stir_angle = _angle_from_pot(position)
		_spoon_angle = _last_stir_angle
		# Releasing during a turn restarts just that unfinished circle at the new grab point.
		if not is_zero_approx(_stir_turn_progress):
			stir_progress = floorf(stir_progress / TAU) * TAU
			_stir_turn_progress = 0.0
		_stir_cue_start_angle = _last_stir_angle
		_stir_cue_direction = 0.0
		queue_redraw()
		return
	if active_step == SoupStage.Step.SALT and position.distance_to(_salt_visual_center()) <= INGREDIENT_RADIUS:
		if salt_is_over_pot:
			_seasoning_press_active = _salt_taps_armed and _salt_can_dispense
			if _seasoning_press_active:
				_salt_press_serial += 1
		else:
			_dragging_salt = true


func _update_action(position: Vector2) -> void:
	if not _dragged_ingredient.is_empty():
		_drag_position = position
		queue_redraw()
		return
	if _dragging_salt:
		salt_position = position
		queue_redraw()
		return
	if not _stirring:
		return
	var new_angle := _angle_from_pot(position)
	var delta := wrapf(new_angle - _last_stir_angle, -PI, PI)
	_last_stir_angle = new_angle
	_spoon_angle = new_angle
	if absf(delta) <= PI * 0.65:
		if is_zero_approx(_stir_cue_direction) and not is_zero_approx(delta):
			_stir_cue_direction = signf(delta)
		var directed_delta := delta * _stir_cue_direction
		if _stir_turn_progress <= 0.0 and directed_delta < 0.0:
			_stir_cue_direction = signf(delta)
			directed_delta = absf(delta)
		var completed_turns := floori(stir_progress / TAU)
		var combined_turn_progress := _stir_turn_progress + directed_delta
		if combined_turn_progress >= TAU - STIR_TURN_COMPLETE_EPSILON:
			completed_turns += 1
			_stir_turn_progress = maxf(0.0, combined_turn_progress - TAU)
			_stir_star_bounce[completed_turns - 1] = PROGRESS_STAR_BOUNCE_DURATION
			stirring_turn_completed.emit()
			if completed_turns < STIR_SEGMENT_COUNT:
				_stir_cue_start_angle = new_angle - _stir_cue_direction * _stir_turn_progress
		else:
			_stir_turn_progress = maxf(0.0, combined_turn_progress)
		stir_progress = minf(STIR_MAX_ANGLE, completed_turns * TAU + _stir_turn_progress)
		stirring_progressed.emit(stir_progress)
		if stir_progress >= STIR_MAX_ANGLE:
			_stirring = false
			stirring_finished.emit()
		queue_redraw()


func _finish_action(position: Vector2) -> void:
	if not _dragged_ingredient.is_empty():
		var ingredient_id := _dragged_ingredient
		_dragged_ingredient = &""
		queue_redraw()
		if position.distance_to(POT_CENTER) <= POT_DROP_RADIUS:
			ingredient_dropped.emit(ingredient_id)
		return
	if _seasoning_press_active and _salt_press_serial != _last_dispense_press_serial:
		_seasoning_press_active = false
		_last_dispense_press_serial = _salt_press_serial
		var is_first_dispense := salt_tap_count == 0
		salt_dispensed.emit()
		if is_first_dispense:
			_salt_can_dispense = false
			get_tree().create_timer(SALT_SECOND_DISPENSE_DELAY).timeout.connect(_unlock_second_salt_dispense, CONNECT_ONE_SHOT)
		return
	if _dragging_salt:
		_dragging_salt = false
		salt_position = SALT_POT_POSITION
		salt_is_over_pot = true
		salt_placed.emit()
		call_deferred("_arm_salt_taps")
		queue_redraw()
		return
	if _stirring and stir_progress >= STIR_MAX_ANGLE:
		stirring_finished.emit()
	_stirring = false


func _angle_from_pot(position: Vector2) -> float:
	return (position - POT_CENTER).angle()


func _arm_salt_taps() -> void:
	_salt_taps_armed = true


func _unlock_second_salt_dispense() -> void:
	_salt_can_dispense = true


func _salt_render_position() -> Vector2:
	return salt_position


func _salt_visual_center() -> Vector2:
	var center_offset := Vector2(0.0, -20.0)
	if salt_is_over_pot:
		var pour_angle := (POT_CENTER - salt_position).angle() + PI * 0.5
		center_offset = center_offset.rotated(pour_angle)
	return _salt_render_position() + center_offset


func _draw() -> void:
	draw_texture_rect(KITCHEN_BACKGROUND, Rect2(Vector2.ZERO, size), false)
	_draw_recipe_strip()
	if active_step >= SoupStage.Step.STIR and active_step < SoupStage.Step.READY and _stir_has_started:
		_draw_submerged_spoon()
	_draw_pot()
	if active_step >= SoupStage.Step.STIR and active_step < SoupStage.Step.READY:
		if _stir_has_started:
			_draw_spoon_handle()
		else:
			_draw_preview_spoon()
	_draw_ingredients()
	if active_step >= SoupStage.Step.SALT and active_step < SoupStage.Step.READY:
		_draw_salt_shaker()
	if active_step == SoupStage.Step.READY:
		_draw_ready_steam()


## Soup draws its own progress stars over the shared strip: it counts stirred turns
## and salt taps, which pizza has nothing equivalent to.
func _draw_recipe_strip() -> void:
	CookingRecipeStrip.draw_strip(self, RECIPE_START, RECIPE_ART, active_step, _cue_time)
	if active_step >= SoupStage.Step.STIR:
		_draw_stir_recipe_markers(CookingRecipeStrip.tile_rect(RECIPE_START, SoupStage.Step.STIR))
	if active_step >= SoupStage.Step.SALT:
		_draw_salt_recipe_markers(CookingRecipeStrip.tile_rect(RECIPE_START, SoupStage.Step.SALT))


func _draw_pot() -> void:
	if active_step == SoupStage.Step.READY:
		CookingDraw.texture_centered(self, POT_READY, POT_CENTER, POT_ART_WIDTH)
		return
	CookingDraw.texture_centered(self, POT_EMPTY, POT_CENTER, POT_ART_WIDTH)
	if carrot_added or tomato_added:
		CookingDraw.texture_centered_size(self, SOUP_SURFACE, SOUP_ART_CENTER, SOUP_ART_SIZE)
	if carrot_added:
		draw_circle(POT_CENTER + Vector2(-68.0, -102.0), 24.0, Color("#eb7b35"))
	if tomato_added:
		draw_circle(POT_CENTER + Vector2(68.0, -86.0), 26.0, Color("#df5146"))


func _draw_ingredients() -> void:
	if not carrot_added:
		_draw_carrot(_drag_position if _dragged_ingredient == &"carrot" else carrot_position, active_step == SoupStage.Step.CARROT)
	if not tomato_added:
		_draw_tomato(_drag_position if _dragged_ingredient == &"tomato" else tomato_position, active_step == SoupStage.Step.TOMATO)


func _draw_carrot(position: Vector2, is_active: bool) -> void:
	if is_active:
		position += Vector2(0.0, sin(_cue_time * 3.0) * 12.0)
	if is_active:
		draw_circle(position, 140.0, Color(1.0, 0.95, 0.6, 0.45))
	CookingDraw.texture_centered(self, CARROT_ART, position, INGREDIENT_ART_WIDTH)


func _draw_tomato(position: Vector2, is_active: bool) -> void:
	if is_active:
		position += Vector2(0.0, sin(_cue_time * 3.0) * 12.0)
	if is_active:
		draw_circle(position, 140.0, Color(1.0, 0.95, 0.6, 0.45))
	CookingDraw.texture_centered(self, TOMATO_ART, position, INGREDIENT_ART_WIDTH)


func _draw_submerged_spoon() -> void:
	# The pot and soup are deliberately drawn over the spoon bowl, leaving only the handle visible.
	draw_set_transform(SPOON_REST_CENTER, 0.0)
	CookingDraw.texture_centered(self, SPOON_ART, Vector2.ZERO, 325.0)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_preview_spoon() -> void:
	draw_set_transform(SPOON_REST_CENTER, 0.0)
	CookingDraw.texture_centered(self, SPOON_ART, Vector2.ZERO, 325.0)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_spoon_handle() -> void:
	# Re-draw only the upper handle over the pot. Its bowl remains hidden by the soup.
	var target_width := 325.0
	var texture_size := SPOON_ART.get_size()
	var scale := target_width / texture_size.x
	var full_size := texture_size * scale
	var handle_source := Rect2(118.0, 0.0, texture_size.x - 118.0, 151.0)
	var handle_position := -full_size * 0.5 + handle_source.position * scale
	var wobble := sin(_cue_time * 9.0) * SPOON_STIR_WOBBLE_RADIANS if _stirring else 0.0
	draw_set_transform(SPOON_REST_CENTER, wobble)
	draw_texture_rect_region(SPOON_ART, Rect2(handle_position, handle_source.size * scale), handle_source)
	draw_set_transform(Vector2.ZERO, 0.0)


func _update_stir_ring_art() -> void:
	var show_ring := active_step == SoupStage.Step.STIR
	steer_ring_empty.visible = show_ring
	steer_ring_filled.visible = show_ring and _stir_has_started
	if not steer_ring_filled.visible:
		return
	var material := steer_ring_filled.material as ShaderMaterial
	material.set_shader_parameter("sweep_start", _stir_cue_start_angle)
	material.set_shader_parameter("sweep_amount", _stir_turn_progress)
	material.set_shader_parameter("sweep_direction", _stir_cue_direction if not is_zero_approx(_stir_cue_direction) else 1.0)


func _draw_stir_recipe_markers(rect: Rect2) -> void:
	for segment: int in STIR_SEGMENT_COUNT:
		var center := rect.get_center() + Vector2(-52.0 + segment * 52.0, rect.size.y * 0.5 + 29.0)
		var is_complete := stir_progress >= (segment + 1) * TAU - STIR_TURN_COMPLETE_EPSILON
		var bounce_ratio := _stir_star_bounce[segment] / PROGRESS_STAR_BOUNCE_DURATION
		var bounce_scale := 1.0 + sin(bounce_ratio * PI) * 0.34
		var star_art := STIR_STAR_FILLED if is_complete else STIR_STAR_EMPTY
		CookingDraw.texture_centered(self, star_art, center, PROGRESS_STAR_SIZE * bounce_scale)


func _draw_salt_recipe_markers(rect: Rect2) -> void:
	for index: int in 2:
		var center := rect.get_center() + Vector2(-29.0 + index * 58.0, rect.size.y * 0.5 + 29.0)
		var is_complete := index < salt_tap_count
		var bounce_ratio := _salt_star_bounce[index] / PROGRESS_STAR_BOUNCE_DURATION
		var bounce_scale := 1.0 + sin(bounce_ratio * PI) * 0.34
		var star_art := STIR_STAR_FILLED if is_complete else STIR_STAR_EMPTY
		CookingDraw.texture_centered(self, star_art, center, 42.0 * bounce_scale)


func _draw_salt_shaker() -> void:
	var is_active := active_step == SoupStage.Step.SALT
	var shaker_render_position := _salt_render_position()
	var shaker_visual_center := _salt_visual_center()
	if is_active:
		draw_circle(shaker_visual_center, 145.0, Color(1.0, 0.95, 0.6, 0.45))
	var pour_angle := 0.0
	if salt_is_over_pot:
		var pour_direction := (POT_CENTER - salt_position).normalized()
		# The shaker cap is at the top of its upright art, so turn it toward the pot.
		pour_angle = pour_direction.angle() + PI * 0.5
	var shake_ratio := _salt_shake_time / 0.32
	var tap_tilt := sin(shake_ratio * PI) * 0.22
	draw_set_transform(shaker_render_position, pour_angle + tap_tilt)
	CookingDraw.texture_centered(self, SALT_UPRIGHT_ART, Vector2.ZERO, 220.0)
	draw_set_transform(Vector2.ZERO, 0.0)
	if _salt_shake_time > 0.0:
		var pour_direction := (POT_CENTER - salt_position).normalized()
		var cap_position := shaker_render_position + Vector2(0.0, -82.0).rotated(pour_angle + tap_tilt)
		var fall_progress := 1.0 - shake_ratio
		var lateral_offsets: Array[float] = [-25.0, 18.0, -8.0, 30.0, 4.0]
		for index: int in lateral_offsets.size():
			var distance: float = 30.0 + fall_progress * 92.0 + (index % 2) * 13.0
			var particle_position: Vector2 = cap_position + pour_direction * distance + pour_direction.orthogonal() * lateral_offsets[index]
			var particle_radius: float = 7.0 + (index % 2) * 2.0
			draw_circle(particle_position, particle_radius, Color("#fff4d5"))


func _draw_ready_steam() -> void:
	for index: int in 3:
		var x := POT_CENTER.x - 85.0 + index * 85.0
		draw_arc(Vector2(x, POT_CENTER.y - 240.0), 38.0, -PI * 0.2, PI * 0.8, 16, Color(1.0, 1.0, 1.0, 0.72), 12.0)
