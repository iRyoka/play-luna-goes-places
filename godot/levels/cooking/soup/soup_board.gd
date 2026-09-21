class_name SoupBoard
extends Control

signal action_completed(action: StringName)

const POT_HOME := Vector2(1080, 600)
const STEER_RING_RECT := Rect2(740, 260, 680, 680)
const POT_PREP := Vector2(430, 600)
## The Soup board covers wide displays, so its active objects stay above this
## conservative lower row instead of relying on cropped decorative counter space.
const WATER_HOME := Vector2(420, 650)
const BOARD_CENTER := Vector2(1140, 600)
const POT_RADIUS := Vector2(215, 122)
const DROP_RADIUS := 290.0
const CAPTURE := 165.0
const CUT_WIDTH := 92.0
const STIR_TURNS := 3
const STIR_TURN_COMPLETE_EPSILON := .02
const HERB_TARGET := 0.90
const HERB_TIMEOUT := 5.0
## Herb centres stay inside this inset ellipse so the complete rendered fleck,
## rather than only its touch point, remains on the soup surface.
const HERB_PLACEMENT_RADIUS := Vector2(165, 72)
const HERB_BRUSH_RADIUS := 80.0
const HERB_MARK_SPACING := 85.0
const HERB_FLECK_STAMP_WIDTH := 90.0
const HERB_VISIBLE_MARK_INTERVAL := 3
const MORTAR_CENTER := Vector2(1700, 650)
const PESTLE_PIVOT := Vector2(1700, 675)
const PESTLE_SOURCE_WORK_END := Vector2(100.5, 774.5)
const PESTLE_SOURCE_AXIS_ANGLE := deg_to_rad(-45.45)
const PESTLE_DRAW_WIDTH := 310.0
## The complete cue spans 90 degrees from left to right.
const ROCK_HALF_ANGLE := PI * .25
## Rotate the source's native -45.45-degree axis so the rocking arc is centred
## straight above the mortar.
const ROCK_CENTER_ROTATION := -PI * .5 - PESTLE_SOURCE_AXIS_ANGLE
const ROCK_ARC_COUNT := 4
const ROCK_ENDPOINT_TOLERANCE := .08
const SALT_HOME_POSITION := Vector2(1660, 675)
const HERB_HOME := Vector2(430, 670)
const SALT_SECOND_DISPENSE_DELAY := .75
const PROGRESS_STAR_BOUNCE_DURATION := .4

const BACKGROUND: Texture2D = preload("res://assets/gameplay/cooking/kitchen-background.webp")
const POT_EMPTY: Texture2D = preload("res://assets/gameplay/cooking/pot-empty-large.png")
const POT_READY: Texture2D = preload("res://assets/gameplay/cooking/pot-ready-large.png")
const SURFACE: Texture2D = preload("res://assets/gameplay/cooking/soup-surface.png")
const WATER_SURFACE: Texture2D = preload("res://assets/gameplay/cooking/water-surface.png")
const CARROT: Texture2D = preload("res://assets/gameplay/cooking/carrot.png")
const TOMATO: Texture2D = preload("res://assets/gameplay/cooking/tomato.png")
const CARROT_PIECES: Texture2D = preload("res://assets/gameplay/cooking/carrot-pieces.png")
const TOMATO_PIECES: Texture2D = preload("res://assets/gameplay/cooking/tomato-pieces.png")
const BOARD: Texture2D = preload("res://assets/gameplay/cooking/cutting-board.png")
const KNIFE: Texture2D = preload("res://assets/gameplay/cooking/knife.png")
const SPOON: Texture2D = preload("res://assets/gameplay/cooking/spoon.png")
const PITCHER: Texture2D = preload("res://assets/gameplay/cooking/water-pitcher-upright.png")
const PITCHER_POURING: Texture2D = preload("res://assets/gameplay/cooking/water-pitcher-pouring.png")
const MORTAR_WHOLE: Texture2D = preload("res://assets/gameplay/cooking/mortar-whole-pepper.png")
const MORTAR_CRACKED: Texture2D = preload("res://assets/gameplay/cooking/mortar-cracked-pepper.png")
const MORTAR_GROUND: Texture2D = preload("res://assets/gameplay/cooking/mortar-ground-pepper.png")
const MORTAR_TIPPED: Texture2D = preload("res://assets/gameplay/cooking/mortar-tipped-ground-pepper.png")
const PESTLE: Texture2D = preload("res://assets/gameplay/cooking/pestle.png")
const SALT: Texture2D = preload("res://assets/gameplay/cooking/salt-upright.png")
const HERB_BOWL: Texture2D = preload("res://assets/gameplay/cooking/herb-bowl.png")
const HERB_FLECKS: Texture2D = preload("res://assets/gameplay/cooking/herb-flecks.png")
const STIR_STAR_EMPTY: Texture2D = preload("res://assets/gameplay/cooking/stir-star-empty.png")
const STIR_STAR_FILLED: Texture2D = preload("res://assets/gameplay/cooking/stir-star-filled.png")
const DRAG_ARROW_EMPTY: Texture2D = preload("res://assets/gameplay/cooking/pizza/drag-arrow-empty.png")
const DRAG_ARROW_FILLED: Texture2D = preload("res://assets/gameplay/cooking/pizza/drag-arrow-filled.png")
const RECIPE_ART: Array[Texture2D] = [
	preload("res://assets/gameplay/cooking/recipe-water.png"),
	preload("res://assets/gameplay/cooking/recipe-carrot.png"),
	preload("res://assets/gameplay/cooking/recipe-tomato.png"),
	preload("res://assets/gameplay/cooking/recipe-stir.png"),
	preload("res://assets/gameplay/cooking/recipe-pepper.png"),
	preload("res://assets/gameplay/cooking/recipe-salt.png"),
	preload("res://assets/gameplay/cooking/recipe-herbs.png"),
]

const RECIPE_START := Vector2(430, 34)

var active_step := SoupStage.Step.WATER
var _pot_center := POT_HOME
var _drag := &"" as StringName
var _drag_position := Vector2.ZERO
var _water := false
var _carrot_added := false
var _tomato_added := false
var _pepper_added := false
var salt_tap_count := 0
var salt_position := SALT_HOME_POSITION
var salt_is_over_pot := false
var _dragging_salt := false
var _salt_taps_armed := false
var _seasoning_press_active := false
var _salt_can_dispense := true
var _salt_press_serial := 0
var _last_dispense_press_serial := -1
var _salt_shake_time := 0.0
var _salt_star_bounce: Array[float] = [0.0, 0.0]
var _cuts := PackedByteArray()
var _active_cut := -1
var _cut_distance := 0.0
var _cut_outside := false
var _stir_progress := 0.0
var _stir_turn := 0.0
var _last_angle := 0.0
var _stir_direction := 0.0
var _stir_cue_start_angle := -PI * .5
var _spoon_angle := -PI * .5
var _stir_started := false
var _pestle_rock_angle := ROCK_CENTER_ROTATION - ROCK_HALF_ANGLE
var _rock_arc_count := 0
var _rock_to_right := true
var _herbs: EllipticalPaintCoverage
var _herb_complete := false
var _herb_elapsed := -1.0
var _cue_time := 0.0

@onready var steer_ring_empty: TextureRect = %SteerRingEmpty
@onready var steer_ring_filled: TextureRect = %SteerRingFilled


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_apply_viewport_layout)
	# Measure completion against the full soup surface. Mark centres still use the
	# inset placement ellipse so the rendered garnish cannot cross the pot rim.
	_herbs = EllipticalPaintCoverage.new(POT_RADIUS, HERB_BRUSH_RADIUS)
	set_process(true)
	_apply_viewport_layout()


func action_for_step(step: SoupStage.Step) -> StringName:
	return [&"water", &"carrot_cut", &"carrot_transfer", &"tomato_cut", &"tomato_transfer", &"stir", &"pepper_grind", &"pepper_transfer", &"salt", &"herbs", &"ready"][step]


func set_active_step(step: SoupStage.Step) -> void:
	active_step = step
	_drag = &""
	_active_cut = -1
	if step == SoupStage.Step.CARROT_CUT:
		_cuts = PackedByteArray([0, 0, 0])
		_move_pot(POT_PREP)
	elif step == SoupStage.Step.TOMATO_CUT:
		_cuts = PackedByteArray([0, 0])
	elif step == SoupStage.Step.STIR:
		_move_pot(POT_HOME)
		_stir_progress = 0.0
		_stir_turn = 0.0
		_stir_direction = 0.0
		_stir_started = false
		_spoon_angle = -PI * .5
	elif step == SoupStage.Step.PEPPER_GRIND:
		_pestle_rock_angle = ROCK_CENTER_ROTATION - ROCK_HALF_ANGLE
		_rock_arc_count = 0
		_rock_to_right = true
	elif step == SoupStage.Step.SALT:
		salt_tap_count = 0
		salt_position = SALT_HOME_POSITION
		salt_is_over_pot = false
		_dragging_salt = false
		_salt_taps_armed = false
		_seasoning_press_active = false
		_salt_can_dispense = true
		_salt_press_serial = 0
		_last_dispense_press_serial = -1
		_salt_star_bounce = [0.0, 0.0]
	elif step == SoupStage.Step.HERBS:
		_herb_complete = false
		_herb_elapsed = -1.0
	_update_stir_ring()
	queue_redraw()


func _move_pot(target: Vector2) -> void:
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(self, "_pot_center", target, 0.32)


func _process(delta: float) -> void:
	_cue_time += delta
	if active_step == SoupStage.Step.HERBS and _herb_elapsed >= 0.0 and not _herb_complete:
		_herb_elapsed += delta
		if _herb_elapsed >= HERB_TIMEOUT:
			_herb_complete = true
			_complete_current()
	if _salt_shake_time > 0.0:
		_salt_shake_time = maxf(0.0, _salt_shake_time - delta)
	for index: int in _salt_star_bounce.size():
		_salt_star_bounce[index] = maxf(0.0, _salt_star_bounce[index] - delta)
	_update_stir_ring()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _begin(_screen_to_reference(event.position))
		else: _finish(_screen_to_reference(event.position))
	elif event is InputEventMouseMotion:
		_move(_screen_to_reference(event.position))
	elif event is InputEventScreenTouch:
		if event.pressed: _begin(_screen_to_reference(event.position))
		else: _finish(_screen_to_reference(event.position))
	elif event is InputEventScreenDrag:
		_move(_screen_to_reference(event.position))


func _begin_action(position: Vector2) -> void: _begin(position)
func _update_action(position: Vector2) -> void: _move(position)
func _finish_action(position: Vector2) -> void: _finish(position)


func _begin(position: Vector2) -> void:
	_drag_position = position
	match active_step:
		SoupStage.Step.WATER:
			if position.distance_to(WATER_HOME) < CAPTURE: _drag = &"water"
		SoupStage.Step.CARROT_TRANSFER, SoupStage.Step.TOMATO_TRANSFER:
			if position.distance_to(BOARD_CENTER) < 390: _drag = &"board"
		SoupStage.Step.CARROT_CUT, SoupStage.Step.TOMATO_CUT:
			_begin_cut(position)
		SoupStage.Step.STIR:
			if position.distance_to(_pot_center) < 300:
				_drag = &"stir"
				_stir_started = true
				_last_angle = (position - _pot_center).angle()
				_spoon_angle = _last_angle
				# v0.3.0 recovery: a release abandons only the incomplete circle.
				if not is_zero_approx(_stir_turn):
					_stir_progress = floorf(_stir_progress / TAU) * TAU
					_stir_turn = 0.0
				_stir_cue_start_angle = _last_angle
				_stir_direction = 0.0
		SoupStage.Step.PEPPER_GRIND:
			if position.distance_to(PESTLE_PIVOT) < 390:
				_drag = &"pestle"
				_update_pestle(position)
		SoupStage.Step.PEPPER_TRANSFER:
			if position.distance_to(MORTAR_CENTER) < CAPTURE: _drag = &"pepper"
		SoupStage.Step.SALT:
			if position.distance_to(_salt_visual_center()) <= CAPTURE:
				if salt_is_over_pot:
					_seasoning_press_active = _salt_taps_armed and _salt_can_dispense
					if _seasoning_press_active:
						_salt_press_serial += 1
				else:
					_dragging_salt = true
		SoupStage.Step.HERBS:
			if position.distance_to(HERB_HOME) < CAPTURE: _drag = &"herbs"


func _move(position: Vector2) -> void:
	_drag_position = position
	if _dragging_salt:
		salt_position = position
		queue_redraw()
		return
	match _drag:
		&"cut": _update_cut(position)
		&"stir": _update_stir(position)
		&"pestle": _update_pestle(position)
		&"herbs": _paint_herbs(position)
	queue_redraw()


func _finish(position: Vector2) -> void:
	if _seasoning_press_active and _salt_press_serial != _last_dispense_press_serial:
		_seasoning_press_active = false
		_last_dispense_press_serial = _salt_press_serial
		_register_salt_tap()
		if salt_tap_count == 1:
			_salt_can_dispense = false
			get_tree().create_timer(SALT_SECOND_DISPENSE_DELAY).timeout.connect(_unlock_second_salt_dispense, CONNECT_ONE_SHOT)
		else:
			_complete_current()
		return
	if _dragging_salt:
		_dragging_salt = false
		salt_position = _pot_center + Vector2(250, -160)
		salt_is_over_pot = true
		call_deferred("_arm_salt_taps")
		queue_redraw()
		return
	var finished := _drag
	_drag = &""
	if finished == &"cut" and (_cut_outside or _cut_distance < _cut_path(_active_cut).get_length() - 12.0):
		_active_cut = -1
		_cut_distance = 0.0
	elif finished in [&"water", &"board", &"pepper"] and position.distance_to(_pot_center) < DROP_RADIUS:
		if finished == &"water": _water = true
		elif finished == &"board":
			if active_step == SoupStage.Step.CARROT_TRANSFER: _carrot_added = true
			else: _tomato_added = true
		else: _pepper_added = true
		_complete_current()
	queue_redraw()


func _begin_cut(position: Vector2) -> void:
	for index: int in _cuts.size():
		if _cuts[index] == 0 and position.distance_to(_cut_path(index).point_at_distance(0.0)) < CAPTURE:
			_active_cut = index
			_cut_distance = 0.0
			_cut_outside = false
			_drag = &"cut"
			return


func _update_cut(position: Vector2) -> void:
	var path := _cut_path(_active_cut)
	var projected := path.project_distance(position, _cut_distance, 360.0)
	_cut_outside = position.distance_to(path.point_at_distance(projected)) > CUT_WIDTH
	if not _cut_outside: _cut_distance = projected
	if _cut_distance >= path.get_length() - 12.0:
		_cuts[_active_cut] = 1
		_drag = &""
		_active_cut = -1
		if not _cuts.has(0): _complete_current()


func _cut_path(index: int) -> GuidedPath:
	if active_step == SoupStage.Step.CARROT_CUT:
		return GuidedPath.new(PackedVector2Array([
			BOARD_CENTER + Vector2(-180 + index * 180, -135),
			BOARD_CENTER + Vector2(-180 + index * 180, 135),
		]), false)
	# Separate entry points bind a vertical or horizontal tomato stroke even where
	# they cross at the fruit centre.
	if index == 0:
		return GuidedPath.new(PackedVector2Array([BOARD_CENTER + Vector2(0, -145), BOARD_CENTER + Vector2(0, 140)]), false)
	return GuidedPath.new(PackedVector2Array([BOARD_CENTER + Vector2(-220, 0), BOARD_CENTER + Vector2(220, 0)]), false)


func _update_stir(position: Vector2) -> void:
	# This is the v0.3.0 turn recognizer, retained verbatim apart from names.
	var angle := (position - _pot_center).angle()
	var delta := wrapf(angle - _last_angle, -PI, PI)
	_last_angle = angle
	_spoon_angle = angle
	if absf(delta) <= PI * .65:
		if is_zero_approx(_stir_direction) and not is_zero_approx(delta):
			_stir_direction = signf(delta)
		var directed_delta := delta * _stir_direction
		if _stir_turn <= 0.0 and directed_delta < 0.0:
			_stir_direction = signf(delta)
			directed_delta = absf(delta)
		var completed_turns := floori(_stir_progress / TAU)
		var combined_turn_progress := _stir_turn + directed_delta
		if combined_turn_progress >= TAU - STIR_TURN_COMPLETE_EPSILON:
			completed_turns += 1
			_stir_turn = maxf(0.0, combined_turn_progress - TAU)
			if completed_turns < STIR_TURNS:
				_stir_cue_start_angle = angle - _stir_direction * _stir_turn
		else:
			_stir_turn = maxf(0.0, combined_turn_progress)
		_stir_progress = minf(TAU * STIR_TURNS, completed_turns * TAU + _stir_turn)
		if _stir_progress >= TAU * STIR_TURNS:
			_complete_current()
	_update_stir_ring()


func _update_pestle(position: Vector2) -> void:
	var pointer_angle := (position - PESTLE_PIVOT).angle()
	var relative_angle := wrapf(pointer_angle - PESTLE_SOURCE_AXIS_ANGLE, -PI, PI)
	var left_angle := ROCK_CENTER_ROTATION - ROCK_HALF_ANGLE
	var right_angle := ROCK_CENTER_ROTATION + ROCK_HALF_ANGLE
	_pestle_rock_angle = clampf(relative_angle, left_angle, right_angle)
	var reached_target := (
		_pestle_rock_angle >= right_angle - ROCK_ENDPOINT_TOLERANCE
		if _rock_to_right
		else _pestle_rock_angle <= left_angle + ROCK_ENDPOINT_TOLERANCE
	)
	if not reached_target:
		return
	_rock_arc_count += 1
	_rock_to_right = not _rock_to_right
	if _rock_arc_count >= ROCK_ARC_COUNT:
		_complete_current()


func _paint_herbs(position: Vector2) -> void:
	var offset := position - _soup_center()
	if pow(offset.x / HERB_PLACEMENT_RADIUS.x, 2.0) + pow(offset.y / HERB_PLACEMENT_RADIUS.y, 2.0) > 1.0: return
	if _herb_elapsed < 0.0:
		_herb_elapsed = 0.0
	if _herbs.is_empty():
		if _herbs.add_mark(offset, HERB_TARGET):
			_herb_complete = true
			_complete_current()
		return
	var last := _herbs.last_mark()
	var distance := last.distance_to(offset)
	if distance < HERB_MARK_SPACING:
		return
	var direction := last.direction_to(offset)
	var steps := floori(distance / HERB_MARK_SPACING)
	for step: int in range(1, steps + 1):
		if _herbs.add_mark(last + direction * HERB_MARK_SPACING * step, HERB_TARGET):
			_herb_complete = true
			_complete_current()
			return


func _complete_current() -> void:
	if _drag == &"done": return
	_drag = &"done"
	action_completed.emit(action_for_step(active_step))


func _draw() -> void:
	var transform := _board_transform()
	draw_set_transform(transform["offset"] as Vector2, 0.0, Vector2.ONE * float(transform["scale"]))
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, CookingBoardViewport.REFERENCE_SIZE), false)
	CookingRecipeStrip.draw_strip(self, RECIPE_START, RECIPE_ART, _recipe_card_index(), _cue_time)
	if active_step == SoupStage.Step.SALT:
		_draw_salt_recipe_markers(CookingRecipeStrip.tile_rect(RECIPE_START, 5))
	if active_step == SoupStage.Step.STIR and _stir_started:
		_draw_submerged_spoon()
	_draw_pot()
	match active_step:
		SoupStage.Step.WATER:
			var pouring := _drag == &"water" and _drag_position.distance_to(_pot_center) < DROP_RADIUS
			_draw_object(PITCHER_POURING if pouring else PITCHER, WATER_HOME, 340)
		SoupStage.Step.CARROT_CUT, SoupStage.Step.TOMATO_CUT: _draw_cuts()
		SoupStage.Step.CARROT_TRANSFER: _draw_transfer(CARROT_PIECES)
		SoupStage.Step.TOMATO_TRANSFER: _draw_transfer(TOMATO_PIECES)
		SoupStage.Step.STIR: _draw_stir()
		SoupStage.Step.PEPPER_GRIND: _draw_grind()
		SoupStage.Step.PEPPER_TRANSFER: _draw_pepper_transfer()
		SoupStage.Step.SALT: _draw_salt()
		SoupStage.Step.HERBS: _draw_herbs()
		SoupStage.Step.READY: _draw_steam()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _board_transform() -> Dictionary:
	return CookingBoardViewport.cover_transform(size)


func _restore_board_transform() -> void:
	_set_reference_draw_transform(Vector2.ZERO)


func _set_reference_draw_transform(origin: Vector2, rotation := 0.0, local_scale := Vector2.ONE) -> void:
	var transform := _board_transform()
	var viewport_scale := float(transform["scale"])
	draw_set_transform(
		(transform["offset"] as Vector2) + origin * viewport_scale,
		rotation,
		local_scale * viewport_scale
	)


func _screen_to_reference(position: Vector2) -> Vector2:
	return CookingBoardViewport.to_reference(position, _board_transform())


func _apply_viewport_layout() -> void:
	var transform := _board_transform()
	var scale_factor := float(transform["scale"])
	var ring_rect := Rect2(
		STEER_RING_RECT.position * scale_factor + (transform["offset"] as Vector2),
		STEER_RING_RECT.size * scale_factor,
	)
	steer_ring_empty.position = ring_rect.position
	steer_ring_empty.size = ring_rect.size
	steer_ring_filled.position = ring_rect.position
	steer_ring_filled.size = ring_rect.size


func _draw_pot() -> void:
	if active_step in [SoupStage.Step.HERBS, SoupStage.Step.READY]:
		CookingDraw.texture_centered(self, POT_READY, _pot_center, 680)
		_draw_herb_marks()
		return
	CookingDraw.texture_centered(self, POT_EMPTY, _pot_center, 680)
	if _water and not _carrot_added:
		CookingDraw.texture_centered_size(self, WATER_SURFACE, _soup_center(), Vector2(418, 241))
	elif _carrot_added or _tomato_added or _pepper_added:
		CookingDraw.texture_centered_size(self, SURFACE, _soup_center(), Vector2(418, 241))
	if _carrot_added:
		draw_circle(_soup_center() + Vector2(-68, -10), 24, Color("#eb7b35"))
		draw_circle(_soup_center() + Vector2(-18, 22), 20, Color("#f09a42"))
		draw_circle(_soup_center() + Vector2(42, -18), 19, Color("#d96e2f"))
	if _tomato_added:
		draw_circle(_soup_center() + Vector2(75, -2), 25, Color("#df5146"))
		draw_circle(_soup_center() + Vector2(12, -32), 18, Color("#ea6759"))
		draw_circle(_soup_center() + Vector2(-35, 26), 17, Color("#c9423a"))


func _draw_herb_marks() -> void:
	for index: int in _herbs.marks.size():
		if index % HERB_VISIBLE_MARK_INTERVAL != 0:
			continue
		var center := _soup_center() + _herbs.marks[index]
		# Use the complete authored garnish sprite at half the previous display
		# scale. Coverage remains fine-grained, while only every third sample is
		# visible so the soup does not become crowded.
		_set_reference_draw_transform(center, deg_to_rad(float((index * 47) % 90) - 45.0))
		CookingDraw.texture_centered(self, HERB_FLECKS, Vector2.ZERO, HERB_FLECK_STAMP_WIDTH)
		_restore_board_transform()


func _draw_cuts() -> void:
	if active_step == SoupStage.Step.CARROT_CUT:
		CookingDraw.texture_centered(self, BOARD, BOARD_CENTER, 690)
		# The edible carrot's alpha silhouette is diagonal down-left in the source;
		# this turn aligns its long axis horizontally across the board.
		# Root-centred board alignment: 20% initial compensation plus the owner's
		# approved additional 15% of the 620 px source width.
		_set_reference_draw_transform(BOARD_CENTER + Vector2(217, 0), PI * .25)
		CookingDraw.texture_centered(self, CARROT, Vector2.ZERO, 620)
		_restore_board_transform()
	else:
		_draw_board(TOMATO)
	for index: int in _cuts.size():
		var path := _cut_path(index)
		if _cuts[index] != 0:
			# A completed cut keeps its full orange guide as a partial
			# completion marker, but no longer shows a ghost knife.
			draw_line(path.point_at_distance(0.0), path.point_at_distance(path.get_length()), Color("#f5a13c"), 12.0, true)
			continue
		# The blue waiting guide remains dashed; dragged progress is a continuous
		# orange stroke, matching the live motion of the knife.
		draw_dashed_line(path.point_at_distance(0.0), path.point_at_distance(path.get_length()), Color("#67a8e3"), 12.0, 18.0, false)
		if _drag == &"cut" and index == _active_cut:
			# The same path distance that constrains the knife fills the guide, so
			# progress is visible continuously rather than only at completion.
			draw_line(path.point_at_distance(0.0), path.point_at_distance(_cut_distance), Color("#f5a13c"), 12.0, true)
		var endpoint := path.point_at_distance(path.get_length())
		_set_reference_draw_transform(endpoint, path.tangent_at_distance(path.get_length()).angle())
		CookingDraw.texture_centered(self, DRAG_ARROW_EMPTY, Vector2.ZERO, 54)
		_restore_board_transform()
		var knife_position := path.point_at_distance(_cut_distance) if _drag == &"cut" and index == _active_cut else path.point_at_distance(0.0) - path.tangent_at_distance(0.0) * 95.0
		var alpha := 1.0 if _drag == &"cut" and index == _active_cut else .32
		CookingDraw.texture_centered(self, KNIFE, knife_position, 170, Color(1.0, 1.0, 1.0, alpha))


func _draw_board(food: Texture2D) -> void:
	CookingDraw.texture_centered(self, BOARD, BOARD_CENTER, 690)
	CookingDraw.texture_centered(self, food, BOARD_CENTER, 350)


func _draw_stir() -> void:
	var spoon_center := _pot_center + Vector2(65, -70)
	if _stir_started:
		_draw_spoon_handle(spoon_center)
	else:
		CookingDraw.texture_centered(self, SPOON, spoon_center, 325)
	for index: int in STIR_TURNS:
		var complete := _stir_progress >= TAU * (index + 1)
		draw_circle(Vector2(1038 + index * 42, 190), 13, Color("#f5d55e") if complete else Color("#b8cad7"))


func _draw_grind() -> void:
	var mortar := MORTAR_WHOLE if _rock_arc_count < 2 else MORTAR_CRACKED if _rock_arc_count < 4 else MORTAR_GROUND
	_draw_mortar_half(mortar, true)
	_draw_pestle_from_work_end()
	_draw_mortar_half(mortar, false)
	_draw_rock_cue()


func _draw_pestle_from_work_end() -> void:
	var scale := PESTLE_DRAW_WIDTH / PESTLE.get_width()
	var destination := Rect2(-PESTLE_SOURCE_WORK_END * scale, PESTLE.get_size() * scale)
	_set_reference_draw_transform(PESTLE_PIVOT, _pestle_rock_angle)
	draw_texture_rect(PESTLE, destination, false)
	_restore_board_transform()


func _draw_mortar_half(texture: Texture2D, upper: bool) -> void:
	var scale := 390.0 / texture.get_width()
	var full_size := texture.get_size() * scale
	var split_y := roundf(texture.get_height() * .48)
	var source := Rect2(0, 0, texture.get_width(), split_y) if upper else Rect2(0, split_y, texture.get_width(), texture.get_height() - split_y)
	var destination := Rect2(MORTAR_CENTER - full_size * .5 + source.position * scale, source.size * scale)
	draw_texture_rect_region(texture, destination, source)


func _draw_rock_cue() -> void:
	var left_rotation := ROCK_CENTER_ROTATION - ROCK_HALF_ANGLE
	var right_rotation := ROCK_CENTER_ROTATION + ROCK_HALF_ANGLE
	var start_angle := PESTLE_SOURCE_AXIS_ANGLE + (left_rotation if _rock_to_right else right_rotation)
	var target_angle := PESTLE_SOURCE_AXIS_ANGLE + (right_rotation if _rock_to_right else left_rotation)
	_draw_rock_arc(start_angle, target_angle, 1.0, Color("#67a8e3"), 11.0)
	var current_progress := inverse_lerp(
		left_rotation if _rock_to_right else right_rotation,
		right_rotation if _rock_to_right else left_rotation,
		_pestle_rock_angle
	)
	_draw_rock_arc(start_angle, target_angle, clampf(current_progress, 0.0, 1.0), Color("#f5a13c"), 12.0)
	var endpoint := PESTLE_PIVOT + Vector2.from_angle(target_angle) * 165.0
	var tangent := target_angle + (PI * .5 if _rock_to_right else -PI * .5)
	_set_reference_draw_transform(endpoint, tangent)
	CookingDraw.texture_centered(self, DRAG_ARROW_EMPTY, Vector2.ZERO, 54)
	_restore_board_transform()


func _draw_rock_arc(from_angle: float, to_angle: float, progress: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var segment_count := maxi(1, ceili(18.0 * progress))
	for index: int in range(segment_count + 1):
		var fraction := progress * float(index) / segment_count
		points.append(PESTLE_PIVOT + Vector2.from_angle(lerpf(from_angle, to_angle, fraction)) * 165.0)
	if points.size() >= 2:
		draw_polyline(points, color, width, true)


func _draw_salt() -> void:
	_draw_salt_shaker()


func _draw_pepper_transfer() -> void:
	var is_dragging := _drag == &"pepper"
	var center := _drag_position if is_dragging else MORTAR_CENTER
	var over_soup := is_dragging and center.distance_to(_soup_center()) < DROP_RADIUS
	if not is_dragging:
		draw_circle(center, 190.0 + sin(_cue_time * 3.0) * 7.0, Color(1.0, .95, .6, .28))
	CookingDraw.texture_centered(self, MORTAR_TIPPED if over_soup else MORTAR_GROUND, center, 380)


func _draw_herbs() -> void:
	_draw_object(HERB_BOWL, HERB_HOME, 330)


func get_essential_home_bounds() -> Array[Rect2]:
	return [
		CookingDraw.centered_rect(PITCHER, WATER_HOME, 340),
		CookingDraw.centered_rect(BOARD, BOARD_CENTER, 690),
		CookingDraw.centered_rect(MORTAR_GROUND, MORTAR_CENTER, 390),
		CookingDraw.centered_rect(SALT, SALT_HOME_POSITION, 300),
		CookingDraw.centered_rect(HERB_BOWL, HERB_HOME, 330),
	]


func _draw_object(texture: Texture2D, center: Vector2, width: float) -> void:
	var active := _drag != &"" and _drag != &"done"
	if not active: draw_circle(center, width * .48 + sin(_cue_time * 3.0) * 7.0, Color(1.0, .95, .6, .28))
	CookingDraw.texture_centered(self, texture, _drag_position if active else center, width)


func _draw_transfer(food: Texture2D) -> void:
	var target := _soup_center()
	var board_position := _drag_position if _drag == &"board" else BOARD_CENTER
	CookingDraw.texture_centered(self, BOARD, board_position, 690)
	CookingDraw.texture_centered(self, food, board_position, 350)
	var progress := clampf(BOARD_CENTER.distance_to(board_position) / BOARD_CENTER.distance_to(target), 0.0, 1.0)
	# The board travels from the right-hand centre board to the soup opening;
	# these arrows are ordered and oriented in that same visible direction.
	var direction := (target - BOARD_CENTER).normalized()
	for index: int in 4:
		# Board-to-pot order; keep the final arrow just before the centre marker so
		# an ordinary generous drop can visibly complete it.
		var at := .15 + float(index) * .25
		var center := BOARD_CENTER.lerp(target, at)
		_set_reference_draw_transform(center, direction.angle())
		CookingDraw.texture_centered(self, DRAG_ARROW_FILLED if at <= progress else DRAG_ARROW_EMPTY, Vector2.ZERO, 72)
		_restore_board_transform()
	draw_circle(target, 42.0, Color(1.0, .95, .6, .28))


func _draw_submerged_spoon() -> void:
	var center := _pot_center + Vector2(65, -70)
	# This is deliberately the proven v0.3.0 treatment: the spoon bowl stays
	# planted below the soup and only the exposed handle gives motion feedback.
	_set_reference_draw_transform(center)
	CookingDraw.texture_centered(self, SPOON, Vector2.ZERO, 325)
	_restore_board_transform()


func _draw_spoon_handle(center: Vector2) -> void:
	var scale := 325.0 / SPOON.get_size().x
	var source := Rect2(118.0, 0.0, SPOON.get_size().x - 118.0, 151.0)
	var full_size := SPOON.get_size() * scale
	var destination := -full_size * .5 + source.position * scale
	var wobble := sin(_cue_time * 9.0) * .065 if _drag == &"stir" else 0.0
	_set_reference_draw_transform(center, wobble)
	draw_texture_rect_region(SPOON, Rect2(destination, source.size * scale), source)
	_restore_board_transform()


func _register_salt_tap() -> void:
	salt_tap_count += 1
	_salt_shake_time = .32
	_salt_star_bounce[salt_tap_count - 1] = PROGRESS_STAR_BOUNCE_DURATION
	queue_redraw()


func _arm_salt_taps() -> void:
	_salt_taps_armed = true


func _unlock_second_salt_dispense() -> void:
	_salt_can_dispense = true


func _salt_visual_center() -> Vector2:
	var center_offset := Vector2(0, -20)
	if salt_is_over_pot:
		var pour_angle := (_pot_center - salt_position).angle() + PI * .5
		center_offset = center_offset.rotated(pour_angle)
	return salt_position + center_offset


func _draw_salt_shaker() -> void:
	var visual_center := _salt_visual_center()
	draw_circle(visual_center, 145.0, Color(1.0, .95, .6, .45))
	var pour_angle := 0.0
	if salt_is_over_pot:
		pour_angle = (_pot_center - salt_position).angle() + PI * .5
	var shake_ratio := _salt_shake_time / .32
	var tap_tilt := sin(shake_ratio * PI) * .22
	_set_reference_draw_transform(salt_position, pour_angle + tap_tilt)
	CookingDraw.texture_centered(self, SALT, Vector2.ZERO, 220)
	_restore_board_transform()
	if _salt_shake_time <= 0.0:
		return
	var pour_direction := (_pot_center - salt_position).normalized()
	var cap_position := salt_position + Vector2(0, -82).rotated(pour_angle + tap_tilt)
	var fall_progress := 1.0 - shake_ratio
	var lateral_offsets: Array[float] = [-25.0, 18.0, -8.0, 30.0, 4.0]
	for index: int in lateral_offsets.size():
		var distance := 30.0 + fall_progress * 92.0 + (index % 2) * 13.0
		var particle_position := cap_position + pour_direction * distance + pour_direction.orthogonal() * lateral_offsets[index]
		draw_circle(particle_position, 7.0 + (index % 2) * 2.0, Color("#fff4d5"))


func _draw_salt_recipe_markers(rect: Rect2) -> void:
	for index: int in 2:
		var center := rect.get_center() + Vector2(-29.0 + index * 58.0, rect.size.y * .5 + 29.0)
		var bounce_ratio := _salt_star_bounce[index] / PROGRESS_STAR_BOUNCE_DURATION
		var bounce_scale := 1.0 + sin(bounce_ratio * PI) * .34
		var art := STIR_STAR_FILLED if index < salt_tap_count else STIR_STAR_EMPTY
		CookingDraw.texture_centered(self, art, center, 42.0 * bounce_scale)


func _soup_center() -> Vector2:
	return _pot_center + Vector2(-4, -74)


func _draw_steam() -> void:
	for index: int in 3:
		draw_arc(_pot_center + Vector2(-85 + index * 85, -235), 38, -.2, 2.5, 16, Color(1, 1, 1, .72), 12)


func _recipe_card_index() -> int:
	return [0, 1, 1, 2, 2, 3, 4, 4, 5, 6, 7][active_step]


func _update_stir_ring() -> void:
	if not is_instance_valid(steer_ring_empty): return
	var visible := active_step == SoupStage.Step.STIR
	steer_ring_empty.visible = visible
	# The v0.3.0 cue begins on the first useful motion, not after a completed turn.
	steer_ring_filled.visible = visible and _stir_started
	if steer_ring_filled.visible:
		var material := steer_ring_filled.material as ShaderMaterial
		material.set_shader_parameter("sweep_start", _stir_cue_start_angle)
		material.set_shader_parameter("sweep_amount", _stir_turn)
		material.set_shader_parameter("sweep_direction", _stir_direction if not is_zero_approx(_stir_direction) else 1.0)
