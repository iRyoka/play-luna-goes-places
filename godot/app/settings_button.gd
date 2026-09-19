extends Button

const BUTTON_TEXTURE: Texture2D = preload("res://assets/ui/common/circular-paper-button.png")
const SETTINGS_ICON: Texture2D = preload("res://assets/ui/settings/settings-sliders.png")


func _ready() -> void:
	resized.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	var press_offset := Vector2(0.0, 7.0) if button_pressed else Vector2.ZERO
	var button_extent := Vector2.ONE * radius * 1.16
	var button_rect := Rect2(center - button_extent + press_offset, button_extent * 2.0)
	draw_texture_rect(BUTTON_TEXTURE, button_rect, false)
	var icon_extent := Vector2(radius * 0.76, radius * 0.66)
	draw_texture_rect(SETTINGS_ICON, Rect2(center - icon_extent + press_offset, icon_extent * 2.0), false)
