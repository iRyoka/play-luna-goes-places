class_name PlanterArtRenderer
extends RefCounted

const PLANTER_TEXTURE: Texture2D = preload("res://assets/gameplay/numbers/planter/empty-planter.png")
const FLOWER_TEXTURES: Array[Texture2D] = [
	preload("res://assets/gameplay/numbers/planter/flower-01.png"),
	preload("res://assets/gameplay/numbers/planter/flower-02.png"),
	preload("res://assets/gameplay/numbers/planter/flower-03.png"),
	preload("res://assets/gameplay/numbers/planter/flower-04.png"),
	preload("res://assets/gameplay/numbers/planter/flower-05.png"),
	preload("res://assets/gameplay/numbers/planter/flower-06.png"),
	preload("res://assets/gameplay/numbers/planter/flower-07.png"),
	preload("res://assets/gameplay/numbers/planter/flower-08.png"),
	preload("res://assets/gameplay/numbers/planter/flower-09.png"),
	preload("res://assets/gameplay/numbers/planter/flower-10.png"),
]

const REFERENCE_PLANTER_SIZE := Vector2(1341.0, 512.0)
const REFERENCE_FLOWER_POSITIONS := [
	Vector2(166.5, 93.0),
	Vector2(412.5, 93.0),
	Vector2(665.5, 93.0),
	Vector2(920.5, 93.0),
	Vector2(1169.5, 93.0),
	Vector2(164.5, 304.0),
	Vector2(412.5, 304.0),
	Vector2(665.5, 304.0),
	Vector2(920.5, 304.0),
	Vector2(1169.5, 304.0),
]
const FLOWER_SCALE := 0.7


static func draw_planter(canvas: CanvasItem, canvas_size: Vector2, flower_count: int) -> void:
	var planter_rect := _get_planter_rect(canvas_size)
	var scale_factor := planter_rect.size.x / REFERENCE_PLANTER_SIZE.x
	canvas.draw_texture_rect(PLANTER_TEXTURE, planter_rect, false)

	for index in mini(flower_count, FLOWER_TEXTURES.size()):
		var flower_texture := FLOWER_TEXTURES[index]
		var flower_size := flower_texture.get_size() * FLOWER_SCALE * scale_factor
		var flower_position: Vector2 = planter_rect.position + REFERENCE_FLOWER_POSITIONS[index] * scale_factor - flower_size * 0.5
		canvas.draw_texture_rect(flower_texture, Rect2(flower_position, flower_size), false)


static func draw_missing_placeholder(canvas: CanvasItem, canvas_size: Vector2) -> void:
	var rect := _get_planter_rect(canvas_size)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.89, 0.55, 0.15)
	fill.corner_radius_top_left = 30
	fill.corner_radius_top_right = 30
	fill.corner_radius_bottom_left = 30
	fill.corner_radius_bottom_right = 30
	canvas.draw_style_box(fill, rect)
	var outline := Color("#ffe596")
	var corner_radius := 30.0
	canvas.draw_dashed_line(
		rect.position + Vector2(corner_radius, 0.0),
		Vector2(rect.end.x - corner_radius, rect.position.y),
		outline,
		4.0,
		12.0,
		true,
		true
	)
	canvas.draw_dashed_line(
		Vector2(rect.end.x, rect.position.y + corner_radius),
		rect.end - Vector2(0.0, corner_radius),
		outline,
		4.0,
		12.0,
		true,
		true
	)
	canvas.draw_dashed_line(
		rect.end - Vector2(corner_radius, 0.0),
		Vector2(rect.position.x + corner_radius, rect.end.y),
		outline,
		4.0,
		12.0,
		true,
		true
	)
	canvas.draw_dashed_line(
		Vector2(rect.position.x, rect.end.y - corner_radius),
		rect.position + Vector2(0.0, corner_radius),
		outline,
		4.0,
		12.0,
		true,
		true
	)
	_draw_dashed_arc(canvas, rect.position + Vector2(corner_radius, corner_radius), corner_radius, PI, PI * 1.5, outline)
	_draw_dashed_arc(canvas, rect.position + Vector2(rect.size.x - corner_radius, corner_radius), corner_radius, PI * 1.5, TAU, outline)
	_draw_dashed_arc(canvas, rect.end - Vector2(corner_radius, corner_radius), corner_radius, 0.0, PI * 0.5, outline)
	_draw_dashed_arc(canvas, Vector2(rect.position.x + corner_radius, rect.end.y - corner_radius), corner_radius, PI * 0.5, PI, outline)


static func _draw_dashed_arc(canvas: CanvasItem, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
	var segments := 8
	var segment_angle := (end_angle - start_angle) / segments
	for index in range(0, segments, 2):
		canvas.draw_arc(center, radius, start_angle + segment_angle * index, start_angle + segment_angle * (index + 1), 4, color, 4.0, true)


static func _get_planter_rect(canvas_size: Vector2) -> Rect2:
	var planter_width := canvas_size.x * 0.96
	var scale_factor := planter_width / REFERENCE_PLANTER_SIZE.x
	var planter_size := REFERENCE_PLANTER_SIZE * scale_factor
	return Rect2(
		Vector2((canvas_size.x - planter_size.x) * 0.5, canvas_size.y - planter_size.y - 14.0),
		planter_size
	)
