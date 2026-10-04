class_name FireflyMazeStaticLayer
extends Control

## Draws the immutable garden and unlit ground plants once per stage or resize.

const REFERENCE_SIZE := Vector2(2160.0, 1080.0)
const BACKDROP_MAZE_RECT := Rect2(410.0, 210.0, 1350.0, 675.0)
const BACKDROP := preload("res://assets/gameplay/firefly-maze/garden-backdrop.png")
const WALLS := [
	preload("res://assets/gameplay/firefly-maze/wall-01.png"),
	preload("res://assets/gameplay/firefly-maze/wall-02.png"),
	preload("res://assets/gameplay/firefly-maze/wall-03.png"),
	preload("res://assets/gameplay/firefly-maze/wall-04.png"),
	preload("res://assets/gameplay/firefly-maze/wall-05.png"),
	preload("res://assets/gameplay/firefly-maze/wall-06.png"),
	preload("res://assets/gameplay/firefly-maze/wall-07.png"),
	preload("res://assets/gameplay/firefly-maze/wall-08.png"),
	preload("res://assets/gameplay/firefly-maze/wall-09.png"),
]
const BREADCRUMBS := [
	preload("res://assets/gameplay/firefly-maze/breadcrumb-01.png"),
	preload("res://assets/gameplay/firefly-maze/breadcrumb-02.png"),
	preload("res://assets/gameplay/firefly-maze/breadcrumb-03.png"),
	preload("res://assets/gameplay/firefly-maze/breadcrumb-04.png"),
	preload("res://assets/gameplay/firefly-maze/breadcrumb-05.png"),
	preload("res://assets/gameplay/firefly-maze/breadcrumb-06.png"),
]
# Derived from the saved 160px-cell layout scene: a 128px sprite at 1.65 scale.
const WALL_OVERLAP := 128.0 * 1.65 / 160.0
const WALL_MAX_OFFSET_FRACTION := 17.0 / 160.0
const WALL_LAYOUT_OFFSETS := [
	Vector2(-7.0, -17.0), Vector2(5.0, -17.0), Vector2(10.0, -17.0),
	Vector2(-7.0, -6.0), Vector2(5.0, -6.0), Vector2(10.0, -6.0),
	Vector2(-7.0, 9.0), Vector2(5.0, 9.0), Vector2(10.0, 9.0),
]
const BREADCRUMB_SIZE_FRACTION := 0.60
const BREADCRUMB_JITTER_FRACTION := 0.12

var _rows: Array[String] = []
var _cell_size := 64.0
var _stage_index := 0
var _house_cell := Vector2i(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	resized.connect(queue_redraw)


func configure(rows: Array[String], cell_size: float, stage_index: int, house_cell: Vector2i) -> void:
	_rows = rows.duplicate()
	_cell_size = cell_size
	_stage_index = stage_index
	_house_cell = house_cell
	queue_redraw()


static func breadcrumb_index(cell: Vector2i, stage_index: int) -> int:
	return posmod(cell.x * 13 + cell.y * 7 + stage_index * 5, BREADCRUMBS.size())


static func breadcrumb_seed(cell: Vector2i, stage_index: int) -> int:
	return ((cell.x + 1) * 73856093) ^ ((cell.y + 1) * 19349663) ^ ((stage_index + 1) * 83492791)


static func has_breadcrumb(cell: Vector2i, stage_index: int) -> bool:
	return posmod(breadcrumb_seed(cell, stage_index), 10) != 0


static func breadcrumb_rect(center: Vector2, cell_size: float, cell: Vector2i, stage_index: int) -> Rect2:
	var seed := breadcrumb_seed(cell, stage_index)
	var jitter := Vector2(
		float(posmod(seed * 31, 101)) / 50.0 - 1.0,
		float(posmod(seed * 47, 103)) / 51.0 - 1.0
	) * cell_size * BREADCRUMB_JITTER_FRACTION
	var size_pixels := cell_size * BREADCRUMB_SIZE_FRACTION
	return Rect2(center + jitter - Vector2.ONE * size_pixels * 0.5, Vector2.ONE * size_pixels)


func _wall_index(cell: Vector2i) -> int:
	var hash_value := posmod(cell.x * 31 + cell.y * 47 + _stage_index * 71, 17)
	return hash_value % 5 if hash_value < 13 else 5 + (hash_value - 13)


static func wall_rect(center: Vector2, cell_size: float, variant_index: int) -> Rect2:
	var draw_size := cell_size * WALL_OVERLAP
	var offset: Vector2 = WALL_LAYOUT_OFFSETS[variant_index] * cell_size / 160.0
	return Rect2(center + offset - Vector2.ONE * draw_size * 0.5, Vector2.ONE * draw_size)


func _draw() -> void:
	var transform := (get_parent() as FireflyMazeBoard).get_view_transform()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#203a4a"))
	draw_set_transform(transform.offset, 0.0, Vector2.ONE * transform.scale)
	draw_texture_rect(BACKDROP, Rect2(Vector2.ZERO, REFERENCE_SIZE), false)
	if _rows.is_empty():
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var board_size := Vector2(_rows[0].length() * _cell_size, _rows.size() * _cell_size)
	var board := Rect2(BACKDROP_MAZE_RECT.get_center() - board_size * 0.5, board_size)
	for row_index in range(-1, _rows.size() + 1):
		# Draw back-to-front: lower cells cover upper cells, and left covers right.
		for column in range(_rows[0].length(), -2, -1):
			var center := board.position + (Vector2(column, row_index) + Vector2(0.5, 0.5)) * _cell_size
			var cell := Vector2i(column, row_index)
			var is_outer_wall := row_index < 0 or row_index >= _rows.size() or column < 0 or column >= _rows[0].length()
			if is_outer_wall or _rows[row_index].substr(column, 1) == "#":
				var variant_index := _wall_index(cell)
				draw_texture_rect(WALLS[variant_index], wall_rect(center, _cell_size, variant_index), false)
			elif cell != _house_cell and has_breadcrumb(cell, _stage_index):
				draw_texture_rect(BREADCRUMBS[breadcrumb_index(cell, _stage_index)], breadcrumb_rect(center, _cell_size, cell, _stage_index), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
