@tool
extends Node2D

## Editor-only alignment grid. Sprite transforms in firefly_wall_layout.tscn are
## the source of truth; the garden and grid stay fixed while the tiles are moved.

const BACKDROP := preload("res://assets/gameplay/firefly-maze/garden-backdrop.png")
const REFERENCE_SIZE := Vector2(2160.0, 1080.0)
const GRID_ORIGIN := Vector2(845.0, 308.0)
const CELL_SIZE := 160.0
const GRID_DIMENSIONS := Vector2i(3, 3)


func _draw() -> void:
	draw_texture_rect(BACKDROP, Rect2(Vector2.ZERO, REFERENCE_SIZE), false)
	if not Engine.is_editor_hint():
		return
	for row in GRID_DIMENSIONS.y:
		for column in GRID_DIMENSIONS.x:
			var rect := Rect2(
				GRID_ORIGIN + Vector2(column, row) * CELL_SIZE,
				Vector2.ONE * CELL_SIZE
			)
			draw_rect(rect, Color(1.0, 0.35, 0.28, 0.18), true)
			draw_rect(rect, Color(1.0, 0.48, 0.32, 0.85), false, 2.0)
			draw_circle(rect.get_center(), 4.0, Color(1.0, 0.82, 0.5, 0.95))
