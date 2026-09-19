class_name PizzaPaintLayer
extends RefCounted

## One thing the child paints onto the pizza with the object that holds it.
##
## Sauce and cheese are the same action with different artwork, so both keep one of
## these: the marks laid down, how much of the food they cover, and the fill that
## closes the last gaps once the step resolves. Marks are held relative to the food
## so they travel with it into the oven.

## Coarse enough to be cheap, fine enough for a stable coverage threshold.
const GRID := Vector2i(48, 34)

var texture: Texture2D
var radius: Vector2
var brush_radius: float
## Mark centres, relative to the food's resting centre.
var marks: PackedVector2Array = PackedVector2Array()
## Closes the last gaps when the step resolves, so no child chases missed specks.
var fill := 0.0
var coverage := 0.0

var _paintable: PackedByteArray = PackedByteArray()
var _painted: PackedByteArray = PackedByteArray()
var _paintable_total := 0
var _painted_total := 0


func _init(layer_texture: Texture2D, layer_radius: Vector2, layer_brush_radius: float) -> void:
	texture = layer_texture
	radius = layer_radius
	brush_radius = layer_brush_radius
	_paintable.resize(GRID.x * GRID.y)
	_painted.resize(GRID.x * GRID.y)
	for y: int in GRID.y:
		for x: int in GRID.x:
			var offset := cell_offset(x, y)
			var inside := pow(offset.x / radius.x, 2.0) + pow(offset.y / radius.y, 2.0) <= 1.0
			_paintable[y * GRID.x + x] = 1 if inside else 0
			if inside:
				_paintable_total += 1


func cell_offset(x: int, y: int) -> Vector2:
	var cell := Vector2(radius.x * 2.0 / GRID.x, radius.y * 2.0 / GRID.y)
	return -radius + Vector2((x + 0.5) * cell.x, (y + 0.5) * cell.y)


## `offset` is relative to the food's resting centre. Returns true if this mark
## finished the layer.
func add_mark(offset: Vector2, target_coverage: float) -> bool:
	marks.append(offset)
	if coverage >= target_coverage:
		return false
	var cell := Vector2(radius.x * 2.0 / GRID.x, radius.y * 2.0 / GRID.y)
	var min_x := maxi(0, floori((offset.x - brush_radius + radius.x) / cell.x))
	var max_x := mini(GRID.x - 1, ceili((offset.x + brush_radius + radius.x) / cell.x))
	var min_y := maxi(0, floori((offset.y - brush_radius + radius.y) / cell.y))
	var max_y := mini(GRID.y - 1, ceili((offset.y + brush_radius + radius.y) / cell.y))
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var index := y * GRID.x + x
			if _paintable[index] == 0 or _painted[index] == 1:
				continue
			if cell_offset(x, y).distance_to(offset) > brush_radius:
				continue
			_painted[index] = 1
			_painted_total += 1
	coverage = float(_painted_total) / maxf(1.0, float(_paintable_total))
	return coverage >= target_coverage


func last_mark() -> Vector2:
	return marks[marks.size() - 1]


func is_empty() -> bool:
	return marks.is_empty()
