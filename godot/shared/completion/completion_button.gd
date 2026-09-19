extends Button

@export_enum("Replay", "Continue") var icon_kind := 0

const BUTTON_TEXTURE: Texture2D = preload("res://assets/ui/common/circular-paper-button.png")
const BACK_ARROW: Texture2D = preload("res://assets/ui/settings/back-arrow.png")
const ICON_COLOR := Color("#405065")


func _ready() -> void:
	resized.connect(_refresh_drawing)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	pivot_offset = size * 0.5
	queue_redraw()


func _refresh_drawing() -> void:
	pivot_offset = size * 0.5
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	var press_offset := Vector2(0.0, 7.0) if button_pressed else Vector2.ZERO
	var button_extent := Vector2.ONE * radius * 1.16
	var button_rect := Rect2(center - button_extent + press_offset, button_extent * 2.0)
	draw_texture_rect(BUTTON_TEXTURE, button_rect, false)
	center += press_offset
	if icon_kind == 0:
		_draw_replay_icon(center, radius)
	else:
		_draw_continue_icon(center, radius)


func _draw_replay_icon(center: Vector2, radius: float) -> void:
	var icon_radius := radius * 0.48
	draw_arc(center, icon_radius, -2.5, 2.35, 28, ICON_COLOR, radius * 0.15, true)
	var tip := center + Vector2.from_angle(-2.5) * icon_radius
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(-radius * 0.02, -radius * 0.24),
		tip + Vector2(-radius * 0.25, radius * 0.02),
		tip + Vector2(radius * 0.12, radius * 0.08),
	]), ICON_COLOR)


func _draw_continue_icon(center: Vector2, radius: float) -> void:
	var icon_extent := Vector2(radius * 0.70, radius * 0.55)
	draw_set_transform(center, 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect(BACK_ARROW, Rect2(-icon_extent, icon_extent * 2.0), false)
	draw_set_transform(Vector2.ZERO)
