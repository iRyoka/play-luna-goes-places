@tool
extends Node2D

## Mockup for placing the baked pizza inside the oven.
##
## Drag this node in the 2D editor to move the pizza; its position is the centre of
## the shape the food is warped onto. The shape itself is exported below, so the
## foreshortening can be tuned at the same time.
##
## It draws through the same `PizzaProjection` the level uses, with the same
## textures, so what is placed here is what the game draws. Once the position is
## settled it is transcribed into `PizzaBoard` and this scene stops mattering.
##
## The kitchen's horizon is y=247 and the measured oven opening is x 1454..1841,
## y 289..506. The pizza artwork already carries a 0.72 foreshortening from being
## drawn in three-quarter view, so these numbers are the EXTRA foreshortening that
## puts it on the hearth floor rather than standing against the back wall.

const RAW: Texture2D = preload("res://assets/gameplay/cooking/pizza/pizza-raw.png")
const BAKED: Texture2D = preload("res://assets/gameplay/cooking/pizza/pizza-baked.png")
const PIZZA_SCALE := 700.0 / 900.0
const TOPPING_SCALE := 133.0 / 217.0
const SLOT_RING := 0.66
const SLOT_COUNT := 8

const TOPPING_ART: Dictionary[StringName, Texture2D] = {
	&"salami": preload("res://assets/gameplay/cooking/pizza/topping-salami-baked.png"),
	&"olive": preload("res://assets/gameplay/cooking/pizza/topping-olive-baked.png"),
	&"mushroom": preload("res://assets/gameplay/cooking/pizza/topping-mushroom-baked.png"),
	&"basil": preload("res://assets/gameplay/cooking/pizza/topping-basil-baked.png"),
}

@export var near_half_width := 126.0:
	set(value):
		near_half_width = value
		queue_redraw()
@export var far_half_width := 76.0:
	set(value):
		far_half_width = value
		queue_redraw()
@export var half_height := 26.0:
	set(value):
		half_height = value
		queue_redraw()
## Draws the untouched artwork faintly behind, to compare against.
@export var show_unwarped_reference := false:
	set(value):
		show_unwarped_reference = value
		queue_redraw()

## A representative arrangement, so the toppings can be judged too.
const SCATTERED: Array = [
	[&"olive", Vector2(-80.0, 45.0)],
	[&"olive", Vector2(90.0, -35.0)],
	[&"mushroom", Vector2(10.0, 80.0)],
	[&"basil", Vector2(-25.0, -70.0)],
]


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# Local space: this node's position is the centre of the warped shape.
	var quad := PizzaProjection.receding_quad(Vector2.ZERO, near_half_width, far_half_width, half_height)

	if show_unwarped_reference:
		var half := BAKED.get_size() * PIZZA_SCALE * 0.5 * 0.3
		PizzaProjection.draw_texture_quad(
			self, BAKED, PizzaProjection.rectangle_quad(Vector2.ZERO, half), Color(1.0, 1.0, 1.0, 0.28))

	PizzaProjection.draw_texture_quad(self, BAKED, quad)

	var coefficients := PizzaProjection.unit_square_to_quad(quad)
	for placement: Array in _placements():
		_draw_topping(coefficients, placement[0], placement[1])


func _placements() -> Array:
	var placements: Array = []
	var half := RAW.get_size() * PIZZA_SCALE * 0.5
	for index: int in 6:
		var angle := -PI * 0.5 + index * TAU / SLOT_COUNT
		placements.append([&"salami", Vector2(cos(angle) * half.x * SLOT_RING, sin(angle) * half.y * SLOT_RING)])
	placements.append_array(SCATTERED)
	return placements


## A topping rides the same surface as the food, so its own little quad is carried
## through the food's mapping rather than being placed on screen independently.
func _draw_topping(coefficients: PackedFloat32Array, kind: StringName, offset: Vector2) -> void:
	var texture: Texture2D = TOPPING_ART[kind]
	var food_size := BAKED.get_size() * PIZZA_SCALE
	var piece_size := texture.get_size() * TOPPING_SCALE
	var center_uv := Vector2(0.5, 0.5) + offset / food_size
	var half_uv := piece_size * 0.5 / food_size
	var region := Rect2(center_uv - half_uv, half_uv * 2.0)
	PizzaProjection.draw_texture_quad(self, texture, PizzaProjection.map_region(coefficients, region), Color.WHITE, 4)
