class_name PizzaTopping
extends RefCounted

## One piece of topping the child has placed on the pizza.
##
## A slotted piece holds the ring slot it snapped into so the slot can be freed
## again when the piece is taken back off; a scattered piece keeps the position and
## rotation it landed with. Both are redrawn in baked artwork at the same place, so
## nothing moves when the pizza bakes.

var kind: StringName
var position: Vector2
var rotation: float
var slot_index := -1


func _init(topping_kind: StringName, at: Vector2, turned := 0.0, slot := -1) -> void:
	kind = topping_kind
	position = at
	rotation = turned
	slot_index = slot


func is_slotted() -> bool:
	return slot_index >= 0
