class_name PizzaBoard
extends Control

## Draws and drives the pizza recipe.
##
## The stage above owns the ordered story and decides when a step resolves; this
## owns the kitchen, the food, the objects, and every gesture. Geometry here is
## measured against the approved background rather than authored by eye: the
## tabletop is one perspective plane and every anchor sits on it.
##
## Everything on the food — painted marks and placed toppings alike — is held
## relative to the food's resting centre, so it all travels with the pizza when it
## slides into the oven.

signal sauce_covered
signal cheese_covered
signal topping_placed
signal topping_returned
signal done_pressed
signal pizza_baked

# --- Food ---------------------------------------------------------------------

const PIZZA_CENTER := Vector2(1080.0, 800.0)
## The four states were exported at one shared scale rather than normalised to a
## common width, so the baked pizza stays fractionally larger exactly as drawn.
const PIZZA_SCALE := 700.0 / 900.0
## Where painting is allowed: the dough inside the crust.
const BASE_RADIUS := Vector2(290.0, 211.0)
## Where coverage is measured: the area the sauce and cheese artwork actually fill.
const TOPPING_RADIUS := Vector2(240.0, 175.0)
const BRUSH_RADIUS := 45.0
## Both layers fill themselves in at this much coverage.
const TARGET_COVERAGE := 0.8
const MARK_SPACING := 16.0
const FILL_SECONDS := 0.35
const ELLIPSE_SEGMENTS := 32

# --- Counter objects ----------------------------------------------------------

const OBJECT_WIDTH := 260.0
const BOWL_WIDTH := 220.0
const OBJECT_HOME := Vector2(760.0, 980.0)
## Measured from the pour artwork: the sauce stream leaves the jar down and to the
## right of its centre and the cheese falls down and to the left, so each object is
## carried with its spill under the fingertip.
const JAR_SPOUT_OFFSET := Vector2(58.0, 146.0)
const CHEESE_SPILL_OFFSET := Vector2(-37.0, 146.0)
const GRAB_RADIUS := 150.0
const OBJECT_SLIDE_SECONDS := 0.35
const OBJECT_RETURN_SECONDS := 0.28

## Pushed to the sides so the food can be the biggest thing on the counter.
const BOWL_ROW_Y := 985.0
const BOWL_ROW_X: Array[float] = [190.0, 460.0, 1700.0, 1970.0]
const TOPPING_KINDS: Array[StringName] = [&"salami", &"olive", &"mushroom", &"basil"]
const TOPPING_SCALE := 133.0 / 217.0
const SLOT_COUNT := 8
const SLOT_RING := 0.66
const SLOT_SNAP_RADIUS := 100.0
const SCATTER_LIMIT := Vector2(252.0, 190.0)
const SCATTER_ROTATION := 0.35
const TOPPING_LIFT_RADIUS := 80.0

const DONE_CENTER := Vector2(1910.0, 700.0)
const DONE_WIDTH := 200.0
const DONE_CHECK_WIDTH := 104.0
const DONE_RADIUS := 120.0

# --- Oven ---------------------------------------------------------------------

const OVEN_CENTER_X := 1648.0
const OVEN_FLOOR_Y := 500.0
const FIRE_WIDTH := 280.0
const GLOW_WIDTH := 620.0
const OVEN_MOUTH := Vector2(1648.0, 430.0)
## Where the pizza comes to rest inside the arch. The measured opening centres at
## (1648, 398). Placed by the user in `pizza_oven_layout.tscn` so the food rests on
## the hearth floor rather than floating in the arch.
const OVEN_INSIDE := Vector2(1706.0, 471.0)
const BAKING_PIZZA_SCALE := 0.3
const FIRE_CLEAR_SECONDS := 0.3
## Extra foreshortening for the food once it is on the hearth floor, which recedes
## far more steeply than the table the pizza is drawn for. The artwork already
## carries a 0.72 three-quarter view, so these are on top of that.
const OVEN_NEAR_HALF_WIDTH := 126.0
const OVEN_FAR_HALF_WIDTH := 76.0
const OVEN_HALF_HEIGHT := 26.0
## Generous around the measured opening of x 1454..1841, y 289..506.
const BAKE_DROP_REGION := Rect2(1420.0, 250.0, 460.0, 310.0)
const ARROW_WIDTH := 88.0
const ARROW_DISTANCES: Array[float] = [330.0, 425.0, 520.0, 615.0]
const ARROW_CHASE_SECONDS := 0.28
const ARROW_FADE_SECONDS := 0.2

# --- Recipe strip -------------------------------------------------------------

## Only the row's origin is pizza's own: the oven dome sweeps into the band where
## soup puts its strip, so this one starts further left.
const RECIPE_START := Vector2(600.0, 44.0)

const BACKGROUND: Texture2D = preload("res://assets/gameplay/cooking/pizza/pizza-kitchen-background.webp")
const PIZZA_RAW: Texture2D = preload("res://assets/gameplay/cooking/pizza/pizza-raw.png")
const PIZZA_SAUCE: Texture2D = preload("res://assets/gameplay/cooking/pizza/pizza-sauce.png")
const PIZZA_CHEESE: Texture2D = preload("res://assets/gameplay/cooking/pizza/pizza-cheese.png")
const PIZZA_BAKED: Texture2D = preload("res://assets/gameplay/cooking/pizza/pizza-baked.png")
const JAR_UPRIGHT: Texture2D = preload("res://assets/gameplay/cooking/pizza/sauce-jar-upright.png")
const JAR_POURING: Texture2D = preload("res://assets/gameplay/cooking/pizza/sauce-jar-pouring.png")
const CHEESE_UPRIGHT: Texture2D = preload("res://assets/gameplay/cooking/pizza/cheese-bowl-upright.png")
const CHEESE_TIPPING: Texture2D = preload("res://assets/gameplay/cooking/pizza/cheese-bowl-tipping.png")
const OVEN_FIRE: Texture2D = preload("res://assets/gameplay/cooking/pizza/oven-fire.png")
const OVEN_GLOW: Texture2D = preload("res://assets/gameplay/cooking/pizza/oven-glow.png")
const ARROW_EMPTY: Texture2D = preload("res://assets/gameplay/cooking/pizza/drag-arrow-empty.png")
const ARROW_FILLED: Texture2D = preload("res://assets/gameplay/cooking/pizza/drag-arrow-filled.png")
const DONE_FACE: Texture2D = preload("res://assets/ui/common/circular-paper-button.png")
const DONE_CHECK: Texture2D = preload("res://assets/gameplay/cooking/pizza/done-check.png")
const RECIPE_ART: Array[Texture2D] = [
	preload("res://assets/gameplay/cooking/pizza/recipe-sauce.png"),
	preload("res://assets/gameplay/cooking/pizza/recipe-cheese.png"),
	preload("res://assets/gameplay/cooking/pizza/recipe-toppings.png"),
	preload("res://assets/gameplay/cooking/pizza/recipe-bake.png"),
]
const BOWL_ART: Dictionary[StringName, Texture2D] = {
	&"salami": preload("res://assets/gameplay/cooking/pizza/bowl-salami.png"),
	&"olive": preload("res://assets/gameplay/cooking/pizza/bowl-olive.png"),
	&"mushroom": preload("res://assets/gameplay/cooking/pizza/bowl-mushroom.png"),
	&"basil": preload("res://assets/gameplay/cooking/pizza/bowl-basil.png"),
}
const TOPPING_RAW_ART: Dictionary[StringName, Texture2D] = {
	&"salami": preload("res://assets/gameplay/cooking/pizza/topping-salami-raw.png"),
	&"olive": preload("res://assets/gameplay/cooking/pizza/topping-olive-raw.png"),
	&"mushroom": preload("res://assets/gameplay/cooking/pizza/topping-mushroom-raw.png"),
	&"basil": preload("res://assets/gameplay/cooking/pizza/topping-basil-raw.png"),
}
const TOPPING_BAKED_ART: Dictionary[StringName, Texture2D] = {
	&"salami": preload("res://assets/gameplay/cooking/pizza/topping-salami-baked.png"),
	&"olive": preload("res://assets/gameplay/cooking/pizza/topping-olive-baked.png"),
	&"mushroom": preload("res://assets/gameplay/cooking/pizza/topping-mushroom-baked.png"),
	&"basil": preload("res://assets/gameplay/cooking/pizza/topping-basil-baked.png"),
}

var active_step := PizzaStage.Step.SAUCE
## Left-to-right order of the topping bowls: the recipe's approved run variation.
var bowl_order: Array[StringName] = TOPPING_KINDS.duplicate()
var placed_toppings: Array[PizzaTopping] = []
var done_medallion_visible := false
var is_baking := false

var sauce: PizzaPaintLayer
var cheese: PizzaPaintLayer

var _cue_time := 0.0
var _sauce_fill := 0.0
var _cheese_fill := 0.0

var _jar_position := OBJECT_HOME
var _cheese_position := OBJECT_HOME
var _painting_layer: PizzaPaintLayer = null

var _carried_kind: StringName = &""
var _carried_position := Vector2.ZERO
var _bowls_present := false
var _bowl_slide := 0.0

var _dragging_pizza := false
var _pizza_draw_center := PIZZA_CENTER
var _pizza_draw_scale := 1.0
var _pizza_is_baked := false
## Zero on the counter, one on the hearth floor. The food foreshortens as it goes
## in and flattens again as it comes out, which is most of what sells the depth.
var _oven_warp := 0.0
var _oven_lit := 0.0
## The fire and the pizza never share the arch: the fire burns while the child
## still has the pizza, hides while the pizza is inside, and does not come back.
var _fire_alpha := 0.0
var _glow_pulse := 0.0
var _arrow_alpha := 0.0
var _arrow_chase := 0.0


func _ready() -> void:
	# The stage opens input once the board is fully on screen, so a touch during a
	# recipe handover cannot reach a kitchen the child cannot see yet.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sauce = PizzaPaintLayer.new(PIZZA_SAUCE, TOPPING_RADIUS, BRUSH_RADIUS)
	cheese = PizzaPaintLayer.new(PIZZA_CHEESE, TOPPING_RADIUS, BRUSH_RADIUS)
	set_process(true)


func configure_bowl_order(order: Array[StringName]) -> void:
	bowl_order = order.duplicate()
	queue_redraw()


func set_active_step(next_step: PizzaStage.Step) -> void:
	active_step = next_step
	_painting_layer = null
	_dragging_pizza = false
	_carried_kind = &""
	if next_step == PizzaStage.Step.TOPPINGS:
		_bowls_present = true
	elif next_step > PizzaStage.Step.TOPPINGS:
		_bowls_present = false
	if next_step == PizzaStage.Step.BAKE:
		var lighting := create_tween()
		lighting.tween_property(self, "_oven_lit", 1.0, 0.6)
		lighting.parallel().tween_property(self, "_fire_alpha", 1.0, 0.6)
	queue_redraw()


func get_topping_count(kind: StringName) -> int:
	var count := 0
	for topping: PizzaTopping in placed_toppings:
		if topping.kind == kind:
			count += 1
	return count


func _process(delta: float) -> void:
	_cue_time += delta
	_bowl_slide = move_toward(_bowl_slide, 1.0 if _bowls_present else 0.0, delta / OBJECT_SLIDE_SECONDS)
	if active_step == PizzaStage.Step.BAKE and not is_baking:
		_arrow_alpha = move_toward(_arrow_alpha, 0.0 if _dragging_pizza else 1.0, delta / ARROW_FADE_SECONDS)
		_arrow_chase = fmod(_arrow_chase + delta / ARROW_CHASE_SECONDS, float(ARROW_DISTANCES.size() + 1))
	else:
		_arrow_alpha = move_toward(_arrow_alpha, 0.0, delta / ARROW_FADE_SECONDS)
	queue_redraw()


# --- Input --------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
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
	match active_step:
		PizzaStage.Step.SAUCE:
			if position.distance_to(_jar_body_center()) <= GRAB_RADIUS:
				_painting_layer = sauce
				# Settle so the spill meets the finger: what is poured then appears
				# both under the child's finger and at the object's mouth, instead of
				# a long way from either.
				_jar_position = position - JAR_SPOUT_OFFSET
		PizzaStage.Step.CHEESE:
			if position.distance_to(_cheese_body_center()) <= GRAB_RADIUS:
				_painting_layer = cheese
				_cheese_position = position - CHEESE_SPILL_OFFSET
		PizzaStage.Step.TOPPINGS:
			_begin_topping_action(position)
		PizzaStage.Step.BAKE:
			if not is_baking and _pizza_contains(position):
				_dragging_pizza = true
	queue_redraw()


func _update_action(position: Vector2) -> void:
	if _painting_layer != null:
		if _painting_layer == sauce:
			_jar_position = position - JAR_SPOUT_OFFSET
		else:
			_cheese_position = position - CHEESE_SPILL_OFFSET
		_paint_to(position)
	elif not _carried_kind.is_empty():
		_carried_position = position
	elif _dragging_pizza:
		_pizza_draw_center = position
	else:
		return
	queue_redraw()


func _finish_action(position: Vector2) -> void:
	if _painting_layer != null:
		_release_painting_object()
	elif not _carried_kind.is_empty():
		_drop_carried_topping(position)
	elif _dragging_pizza:
		_dragging_pizza = false
		if BAKE_DROP_REGION.has_point(position):
			_slide_into_the_oven()
		else:
			create_tween().set_trans(Tween.TRANS_SINE).tween_property(self, "_pizza_draw_center", PIZZA_CENTER, 0.25)
	queue_redraw()


# --- Painting -----------------------------------------------------------------


## Lays marks along the movement, so a fast drag cannot leave a gap, and decimates
## them, so a slow one cannot pile up thousands.
func _paint_to(spill: Vector2) -> void:
	var layer := _painting_layer
	var offset := spill - PIZZA_CENTER
	var last := layer.last_mark() if not layer.is_empty() else offset
	var steps := maxi(1, ceili(last.distance_to(offset) / MARK_SPACING))
	for step: int in range(1, steps + 1):
		_mark(layer, last.lerp(offset, float(step) / steps))


func _mark(layer: PizzaPaintLayer, offset: Vector2) -> void:
	if pow(offset.x / BASE_RADIUS.x, 2.0) + pow(offset.y / BASE_RADIUS.y, 2.0) > 1.0:
		return
	if not layer.is_empty() and layer.last_mark().distance_to(offset) < MARK_SPACING * 0.5:
		return
	if layer.add_mark(offset, TARGET_COVERAGE):
		_finish_painting(layer)


func _finish_painting(layer: PizzaPaintLayer) -> void:
	_release_painting_object()
	var property := "_sauce_fill" if layer == sauce else "_cheese_fill"
	var fill := create_tween()
	fill.tween_property(self, property, 1.0, FILL_SECONDS)
	fill.tween_callback(func() -> void:
		if layer == sauce:
			sauce_covered.emit()
		else:
			cheese_covered.emit()
	)


func _release_painting_object() -> void:
	if _painting_layer == null:
		return
	var property := "_jar_position" if _painting_layer == sauce else "_cheese_position"
	_painting_layer = null
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(self, property, OBJECT_HOME, OBJECT_RETURN_SECONDS)


# --- Toppings -----------------------------------------------------------------


func _begin_topping_action(position: Vector2) -> void:
	if done_medallion_visible and position.distance_to(DONE_CENTER) <= DONE_RADIUS:
		done_pressed.emit()
		return
	var lifted := _lift_topping_at(position)
	if lifted != null:
		placed_toppings.erase(lifted)
		_carried_kind = lifted.kind
		_carried_position = position
		topping_returned.emit()
		return
	for index: int in bowl_order.size():
		if position.distance_to(Vector2(BOWL_ROW_X[index], BOWL_ROW_Y)) <= GRAB_RADIUS:
			_carried_kind = bowl_order[index]
			_carried_position = position
			return


func _lift_topping_at(position: Vector2) -> PizzaTopping:
	var nearest: PizzaTopping = null
	var nearest_distance := TOPPING_LIFT_RADIUS
	for topping: PizzaTopping in placed_toppings:
		var distance := (PIZZA_CENTER + topping.position).distance_to(position)
		if distance < nearest_distance:
			nearest = topping
			nearest_distance = distance
	return nearest


func _drop_carried_topping(position: Vector2) -> void:
	var kind := _carried_kind
	_carried_kind = &""
	var offset := position - PIZZA_CENTER
	var on_the_base := pow(offset.x / BASE_RADIUS.x, 2.0) + pow(offset.y / BASE_RADIUS.y, 2.0) <= 1.0
	if not on_the_base or not _has_room_for(kind):
		# A piece dropped away from the pizza goes home visibly.
		return
	if kind == &"salami":
		var slot := _nearest_free_slot(offset)
		if slot >= 0:
			placed_toppings.append(PizzaTopping.new(kind, _slot_offset(slot), 0.0, slot))
		else:
			placed_toppings.append(PizzaTopping.new(kind, _nudge_inside(offset), randf_range(-SCATTER_ROTATION, SCATTER_ROTATION)))
	else:
		placed_toppings.append(PizzaTopping.new(kind, _nudge_inside(offset), randf_range(-SCATTER_ROTATION, SCATTER_ROTATION)))
	topping_placed.emit()


func _has_room_for(_kind: StringName) -> bool:
	return true


func _slot_offset(index: int) -> Vector2:
	var angle := -PI * 0.5 + index * TAU / SLOT_COUNT
	var half := _pizza_half_extents(PIZZA_RAW)
	return Vector2(cos(angle) * half.x * SLOT_RING, sin(angle) * half.y * SLOT_RING)


## The child's approximate choice survives: the piece takes the nearest free slot
## within a generous radius, and any free slot if none is near.
func _nearest_free_slot(offset: Vector2) -> int:
	var taken: Dictionary[int, bool] = {}
	for topping: PizzaTopping in placed_toppings:
		if topping.is_slotted():
			taken[topping.slot_index] = true
	var best := -1
	var best_distance := SLOT_SNAP_RADIUS
	var first_free := -1
	for index: int in SLOT_COUNT:
		if taken.has(index):
			continue
		if first_free < 0:
			first_free = index
		var distance := _slot_offset(index).distance_to(offset)
		if distance < best_distance:
			best = index
			best_distance = distance
	return best if best >= 0 else first_free


func _nudge_inside(offset: Vector2) -> Vector2:
	var reach := sqrt(pow(offset.x / SCATTER_LIMIT.x, 2.0) + pow(offset.y / SCATTER_LIMIT.y, 2.0))
	return offset if reach <= 1.0 else offset / reach


func show_done_medallion() -> void:
	done_medallion_visible = true
	queue_redraw()


func withdraw_topping_bowls() -> void:
	_bowls_present = false
	done_medallion_visible = false
	queue_redraw()


# --- Bake ---------------------------------------------------------------------


func _pizza_contains(position: Vector2) -> bool:
	var half := _pizza_half_extents(_current_pizza_art()) * _pizza_draw_scale
	var offset := position - _pizza_draw_center
	return pow(offset.x / half.x, 2.0) + pow(offset.y / half.y, 2.0) <= 1.0


func _slide_into_the_oven() -> void:
	is_baking = true
	_arrow_alpha = 0.0
	# The fire clears the arch as the pizza arrives, so the two are never both in it.
	create_tween().tween_property(self, "_fire_alpha", 0.0, FIRE_CLEAR_SECONDS)
	var bake := create_tween()
	bake.set_trans(Tween.TRANS_SINE)
	bake.tween_property(self, "_pizza_draw_center", OVEN_INSIDE, 0.5)
	bake.parallel().tween_property(self, "_pizza_draw_scale", BAKING_PIZZA_SCALE, 0.5)
	bake.parallel().tween_property(self, "_oven_warp", 1.0, 0.5)
	bake.tween_property(self, "_glow_pulse", 1.0, 0.45)
	bake.tween_property(self, "_glow_pulse", 0.35, 0.45)
	bake.tween_property(self, "_glow_pulse", 1.0, 0.45)
	bake.tween_callback(func() -> void: _pizza_is_baked = true)
	bake.tween_property(self, "_pizza_draw_center", PIZZA_CENTER, 0.55)
	bake.parallel().tween_property(self, "_pizza_draw_scale", 1.0, 0.55)
	bake.parallel().tween_property(self, "_oven_warp", 0.0, 0.55)
	# With the food out and the fire gone, the arch goes quiet again.
	bake.parallel().tween_property(self, "_oven_lit", 0.0, 0.55)
	bake.tween_callback(func() -> void: pizza_baked.emit())


# --- Geometry helpers ---------------------------------------------------------


func _pizza_half_extents(texture: Texture2D) -> Vector2:
	return texture.get_size() * PIZZA_SCALE * 0.5


func _pizza_rect(texture: Texture2D) -> Rect2:
	var half := _pizza_half_extents(texture) * _pizza_draw_scale
	return Rect2(_pizza_draw_center - half, half * 2.0)


## Where a point held relative to the food's resting centre is drawn right now.
## Everything on the pizza goes through this, so it all travels into the oven.
func _food_point(offset: Vector2) -> Vector2:
	return _pizza_draw_center + offset * _pizza_draw_scale


func _current_pizza_art() -> Texture2D:
	if _pizza_is_baked:
		return PIZZA_BAKED
	if _cheese_fill >= 1.0:
		return PIZZA_CHEESE
	if _sauce_fill >= 1.0:
		return PIZZA_SAUCE
	return PIZZA_RAW


func _jar_body_center() -> Vector2:
	return _jar_position + Vector2(0.0, -30.0)


func _cheese_body_center() -> Vector2:
	return _cheese_position + Vector2(0.0, -20.0)


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	_draw_ambient_backdrop()
	var transform := _board_transform()
	draw_set_transform(transform["offset"] as Vector2, 0.0, Vector2.ONE * float(transform["scale"]))
	draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, CookingBoardViewport.REFERENCE_SIZE), false)
	_draw_oven_glow()
	_draw_oven_fire()
	CookingRecipeStrip.draw_strip(self, RECIPE_START, RECIPE_ART, active_step, _cue_time)
	_draw_pizza()
	_draw_counter_objects()
	if active_step == PizzaStage.Step.BAKE:
		_draw_drag_arrows()
	if done_medallion_visible:
		_draw_done_medallion()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _board_transform() -> Dictionary:
	return CookingBoardViewport.fit_transform(size)


func _draw_ambient_backdrop() -> void:
	# Keep the full authored kitchen readable while its enlarged, softened colours
	# fill any letterbox space like a padded video rather than a flat empty field.
	var backdrop_transform := CookingBoardViewport.cover_transform(size)
	var backdrop_scale := float(backdrop_transform["scale"]) * 1.08
	var backdrop_offset := (size - CookingBoardViewport.REFERENCE_SIZE * backdrop_scale) * 0.5
	var blur_offsets: Array[Vector2] = [
		Vector2(-12.0, 0.0), Vector2(12.0, 0.0),
		Vector2(0.0, -8.0), Vector2(0.0, 8.0),
		Vector2.ZERO,
	]
	for blur_offset: Vector2 in blur_offsets:
		draw_set_transform(backdrop_offset + blur_offset, 0.0, Vector2.ONE * backdrop_scale)
		draw_texture_rect(BACKGROUND, Rect2(Vector2.ZERO, CookingBoardViewport.REFERENCE_SIZE), false, Color(0.82, 0.67, 0.48, 0.26))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.20, 0.13, 0.09, 0.48))


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


func _fire_center() -> Vector2:
	var fire_height := FIRE_WIDTH * OVEN_FIRE.get_size().y / OVEN_FIRE.get_size().x
	return Vector2(OVEN_CENTER_X, OVEN_FLOOR_Y - fire_height * 0.5)


func _draw_oven_glow() -> void:
	if _oven_lit <= 0.0:
		return
	var pulse := 0.55 + 0.45 * _glow_pulse if is_baking else 0.55 + 0.12 * sin(_cue_time * 2.2)
	CookingDraw.texture_centered(self, OVEN_GLOW, _fire_center(), GLOW_WIDTH, Color(1.0, 1.0, 1.0, _oven_lit * pulse))


func _draw_oven_fire() -> void:
	if _fire_alpha <= 0.0:
		return
	CookingDraw.texture_centered(self, OVEN_FIRE, _fire_center(), FIRE_WIDTH, Color(1.0, 1.0, 1.0, _fire_alpha))


func _draw_pizza() -> void:
	# On the hearth the food lies on a receding surface, so it is drawn onto a
	# four-cornered shape rather than a rectangle. Painted marks are never visible
	# by then, so only the state artwork and the toppings need carrying across.
	if _oven_warp > 0.0:
		_draw_pizza_on_the_hearth()
		return
	if _pizza_is_baked:
		draw_texture_rect(PIZZA_BAKED, _pizza_rect(PIZZA_BAKED), false)
		_draw_placed_toppings(TOPPING_BAKED_ART)
		return
	draw_texture_rect(PIZZA_RAW, _pizza_rect(PIZZA_RAW), false)
	_draw_paint_layer(sauce, _sauce_fill)
	_draw_paint_layer(cheese, _cheese_fill)
	_draw_placed_toppings(TOPPING_RAW_ART)
	if not _carried_kind.is_empty():
		_draw_topping_piece(TOPPING_RAW_ART[_carried_kind], _carried_position, 0.0)


func _draw_pizza_on_the_hearth() -> void:
	var texture := _current_pizza_art()
	var rect := _pizza_rect(texture)
	var flat := PizzaProjection.rectangle_quad(rect.get_center(), rect.size * 0.5)
	var receding := PizzaProjection.receding_quad(
		_pizza_draw_center, OVEN_NEAR_HALF_WIDTH, OVEN_FAR_HALF_WIDTH, OVEN_HALF_HEIGHT)
	var quad := PizzaProjection.lerp_quad(flat, receding, _oven_warp)
	PizzaProjection.draw_texture_quad(self, texture, quad)

	var art := TOPPING_BAKED_ART if _pizza_is_baked else TOPPING_RAW_ART
	var coefficients := PizzaProjection.unit_square_to_quad(quad)
	var food_size := texture.get_size() * PIZZA_SCALE
	for topping: PizzaTopping in placed_toppings:
		var piece: Texture2D = art[topping.kind]
		var piece_size := piece.get_size() * TOPPING_SCALE
		var half_uv := piece_size * 0.5 / food_size
		var region := Rect2(Vector2(0.5, 0.5) + topping.position / food_size - half_uv, half_uv * 2.0)
		PizzaProjection.draw_texture_quad(self, piece, PizzaProjection.map_region(coefficients, region), Color.WHITE, 4)


func _draw_paint_layer(layer: PizzaPaintLayer, fill: float) -> void:
	var rect := _pizza_rect(layer.texture)
	if fill > 0.0:
		draw_texture_rect(layer.texture, rect, false, Color(1.0, 1.0, 1.0, fill))
	if fill >= 1.0:
		return
	# Every mark samples the same texture at the same place on the food, so
	# overlapping marks redraw identical pixels: the union needs no compositing.
	var radius := Vector2(layer.brush_radius, layer.brush_radius) * _pizza_draw_scale
	for mark: Vector2 in layer.marks:
		_draw_texture_ellipse(layer.texture, rect, _food_point(mark), radius)


func _draw_placed_toppings(art: Dictionary[StringName, Texture2D]) -> void:
	for topping: PizzaTopping in placed_toppings:
		_draw_topping_piece(art[topping.kind], _food_point(topping.position), topping.rotation)


func _draw_topping_piece(texture: Texture2D, center: Vector2, turned: float) -> void:
	var width := texture.get_size().x * TOPPING_SCALE * _pizza_draw_scale
	_set_reference_draw_transform(center, turned)
	CookingDraw.texture_centered(self, texture, Vector2.ZERO, width)
	_restore_board_transform()


func _draw_counter_objects() -> void:
	match active_step:
		PizzaStage.Step.SAUCE:
			var pouring := _painting_layer == sauce
			if not pouring and sauce.is_empty():
				draw_circle(_jar_body_center(), 150.0 + sin(_cue_time * 3.0) * 8.0, Color(1.0, 0.95, 0.6, 0.4))
			CookingDraw.texture_centered(self, JAR_POURING if pouring else JAR_UPRIGHT, _jar_position, OBJECT_WIDTH)
		PizzaStage.Step.CHEESE:
			var tipping := _painting_layer == cheese
			if not tipping and cheese.is_empty():
				draw_circle(_cheese_body_center(), 150.0 + sin(_cue_time * 3.0) * 8.0, Color(1.0, 0.95, 0.6, 0.4))
			CookingDraw.texture_centered(self, CHEESE_TIPPING if tipping else CHEESE_UPRIGHT, _cheese_position, OBJECT_WIDTH)
	if _bowl_slide > 0.0:
		_draw_topping_bowls()


func _draw_topping_bowls() -> void:
	for index: int in bowl_order.size():
		# Bowls arrive and withdraw with a short slide up from below the counter.
		var center := Vector2(BOWL_ROW_X[index], BOWL_ROW_Y + (1.0 - _bowl_slide) * 220.0)
		if _bowl_slide >= 1.0 and active_step == PizzaStage.Step.TOPPINGS:
			draw_circle(center + Vector2(0.0, -20.0), 128.0 + sin(_cue_time * 3.0 + index) * 5.0, Color(1.0, 0.95, 0.6, 0.32))
		CookingDraw.texture_centered(self, BOWL_ART[bowl_order[index]], center, BOWL_WIDTH, Color(1.0, 1.0, 1.0, _bowl_slide))


func _draw_done_medallion() -> void:
	var center := DONE_CENTER + Vector2(0.0, sin(_cue_time * 2.6) * 9.0)
	CookingDraw.texture_centered(self, DONE_FACE, center, DONE_WIDTH)
	CookingDraw.texture_centered(self, DONE_CHECK, center, DONE_CHECK_WIDTH)


func _draw_drag_arrows() -> void:
	if _arrow_alpha <= 0.0:
		return
	var direction := (OVEN_MOUTH - PIZZA_CENTER).normalized()
	var angle := direction.angle()
	for index: int in ARROW_DISTANCES.size():
		var center := PIZZA_CENTER + direction * ARROW_DISTANCES[index]
		# The chase lights one arrow at a time and rests a beat before repeating.
		var texture := ARROW_FILLED if floori(_arrow_chase) == index else ARROW_EMPTY
		_set_reference_draw_transform(center, angle)
		CookingDraw.texture_centered(self, texture, Vector2.ZERO, ARROW_WIDTH, Color(1.0, 1.0, 1.0, _arrow_alpha))
		_restore_board_transform()


## Draws `texture` masked to an ellipse, as one textured polygon.
func _draw_texture_ellipse(texture: Texture2D, rect: Rect2, center: Vector2, radius: Vector2) -> void:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for index: int in ELLIPSE_SEGMENTS:
		var angle := TAU * index / float(ELLIPSE_SEGMENTS)
		var point := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		points.append(point)
		uvs.append((point - rect.position) / rect.size)
		colors.append(Color.WHITE)
	draw_polygon(points, colors, uvs, texture)
