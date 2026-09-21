class_name EllipticalPaintCoverage
extends RefCounted

## Coarse, recipe-neutral coverage for marks painted onto an elliptical food.
const GRID := Vector2i(48, 34)

var radius: Vector2
var brush_radius: float
var marks := PackedVector2Array()
var coverage := 0.0
var _paintable := PackedByteArray()
var _painted := PackedByteArray()
var _paintable_total := 0
var _painted_total := 0


func _init(surface_radius: Vector2, mark_radius: float) -> void:
	radius = surface_radius
	brush_radius = mark_radius
	_paintable.resize(GRID.x * GRID.y)
	_painted.resize(GRID.x * GRID.y)
	for y: int in GRID.y:
		for x: int in GRID.x:
			var index := y * GRID.x + x
			if _cell_offset(x, y).length_squared() <= 1.0:
				_paintable[index] = 1
				_paintable_total += 1


func add_mark(offset: Vector2, target_coverage: float) -> bool:
	marks.append(offset)
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
			if (_cell_offset(x, y) * radius).distance_to(offset) <= brush_radius:
				_painted[index] = 1
				_painted_total += 1
	coverage = float(_painted_total) / maxf(1.0, float(_paintable_total))
	return coverage >= target_coverage


func last_mark() -> Vector2:
	return marks[marks.size() - 1]


func is_empty() -> bool:
	return marks.is_empty()


func _cell_offset(x: int, y: int) -> Vector2:
	return Vector2(-1.0 + (x + 0.5) * 2.0 / GRID.x, -1.0 + (y + 0.5) * 2.0 / GRID.y)
