@tool
extends Node2D

## The support stays fixed while the wheel turns slowly. Twelve alternating carts
## orbit the moved support hub but counter-rotate so they remain upright.

const REVOLUTION_DURATION := 24.0
const HUB_POSITION := Vector2(2.0, -20.0)
const CART_RADIUS := Vector2(102.0, 92.0)

@onready var wheel: Sprite2D = $Wheel
var _carts: Array[Sprite2D] = []

var _animation_time := 0.0:
	set(value):
		_animation_time = value
		_apply_animation()

var _wheel_tween: Tween


func _ready() -> void:
	for child: Node in get_children():
		if child is Sprite2D and child.name.begins_with("Cart"):
			_carts.append(child as Sprite2D)
	wheel.position = HUB_POSITION
	_apply_animation()
	if Engine.is_editor_hint():
		return
	_wheel_tween = create_tween().set_loops()
	_wheel_tween.set_trans(Tween.TRANS_LINEAR)
	_wheel_tween.tween_property(self, "_animation_time", REVOLUTION_DURATION, REVOLUTION_DURATION).from(0.0)


func _exit_tree() -> void:
	if _wheel_tween != null:
		_wheel_tween.kill()


func _apply_animation() -> void:
	if _carts.is_empty():
		return
	var angle := _animation_time / REVOLUTION_DURATION * TAU
	wheel.rotation = angle
	for index in _carts.size():
		_set_cart(_carts[index], angle + PI * 0.5 + TAU * float(index) / float(_carts.size()))


func _set_cart(cart: Sprite2D, angle: float) -> void:
	cart.position = HUB_POSITION + Vector2(cos(angle) * CART_RADIUS.x, sin(angle) * CART_RADIUS.y)
	cart.rotation = 0.0
