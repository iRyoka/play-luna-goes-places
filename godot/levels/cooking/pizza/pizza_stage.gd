class_name PizzaStage
extends CookingStage

## Pizza: paint the sauce, paint the cheese, choose and place toppings, tap done,
## and slide the pizza into the oven. The stage owns the ordered story and the
## board owns the kitchen and every gesture.

enum Step { SAUCE, CHEESE, TOPPINGS, BAKE, SERVED }

const DONE_HOLD := 0.3
const SERVED_HOLD := 2.2

## Approved safe arrangements of the four topping bowls, left to right. This is the
## recipe's bounded run variation; the child's own topping choice supplies the rest,
## which is why pizza needs less authored randomisation than soup.
const BOWL_ARRANGEMENTS: Array = [
	[&"salami", &"olive", &"mushroom", &"basil"],
	[&"olive", &"salami", &"basil", &"mushroom"],
	[&"mushroom", &"basil", &"salami", &"olive"],
	[&"basil", &"mushroom", &"olive", &"salami"],
]

## Fixed bowl arrangement for tests. Below zero picks a fresh approved one.
@export var bowl_arrangement_index := -1

@onready var pizza_board: PizzaBoard = %PizzaBoard

var _step := Step.SAUCE


func _ready() -> void:
	var index := bowl_arrangement_index
	if index < 0:
		index = randi() % BOWL_ARRANGEMENTS.size()
	var order: Array[StringName] = []
	order.assign(BOWL_ARRANGEMENTS[index % BOWL_ARRANGEMENTS.size()])
	pizza_board.configure_bowl_order(order)

	pizza_board.sauce_covered.connect(_on_sauce_covered)
	pizza_board.cheese_covered.connect(_on_cheese_covered)
	pizza_board.topping_placed.connect(_on_topping_placed)
	pizza_board.topping_returned.connect(_on_topping_returned)
	pizza_board.done_pressed.connect(_on_done_pressed)
	pizza_board.pizza_baked.connect(_on_pizza_baked)
	# The first cue is drawn before input opens, so the kitchen fades in already
	# showing the child what to reach for.
	pizza_board.set_active_step(_step)


func begin() -> void:
	set_input_enabled(true)


func set_input_enabled(enabled: bool) -> void:
	pizza_board.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func get_current_step() -> Step:
	return _step


func get_sauce_coverage() -> float:
	return pizza_board.sauce.coverage


func get_cheese_coverage() -> float:
	return pizza_board.cheese.coverage


func get_placed_topping_count() -> int:
	return pizza_board.placed_toppings.size()


func _on_sauce_covered() -> void:
	if _step != Step.SAUCE:
		return
	sound_requested.emit(&"correct")
	_advance_step()


func _on_cheese_covered() -> void:
	if _step != Step.CHEESE:
		return
	sound_requested.emit(&"correct")
	_advance_step()


func _on_topping_placed() -> void:
	if _step != Step.TOPPINGS:
		return
	sound_requested.emit(&"drop")
	# The medallion rises once the first topping lands, so the child is never asked
	# to end a phase they have not started.
	if not pizza_board.done_medallion_visible:
		pizza_board.show_done_medallion()


func _on_topping_returned() -> void:
	if _step == Step.TOPPINGS:
		sound_requested.emit(&"tap")


func _on_done_pressed() -> void:
	if _step != Step.TOPPINGS:
		return
	sound_requested.emit(&"tap")
	pizza_board.withdraw_topping_bowls()
	await get_tree().create_timer(DONE_HOLD).timeout
	if _step != Step.TOPPINGS:
		return
	_advance_step()


func _on_pizza_baked() -> void:
	if _step != Step.BAKE:
		return
	sound_requested.emit(&"correct")
	_advance_step()


func _advance_step() -> void:
	_step += 1
	pizza_board.set_active_step(_step)
	if _step == Step.SERVED:
		# The baked pizza is seen before the level hands over or celebrates.
		await get_tree().create_timer(SERVED_HOLD).timeout
		if _step != Step.SERVED:
			return
		recipe_finished.emit()
