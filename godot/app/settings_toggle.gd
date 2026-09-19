class_name SettingsToggle
extends Button

enum ToggleKind {
	MUSIC,
	SOUND_EFFECTS,
}

const BUTTON_TEXTURE: Texture2D = preload("res://assets/ui/common/circular-paper-button.png")
const MUSIC_ENABLED_ICON: Texture2D = preload("res://assets/ui/settings/music-enabled.png")
const MUSIC_DISABLED_ICON: Texture2D = preload("res://assets/ui/settings/music-disabled.png")
const SOUND_ENABLED_ICON: Texture2D = preload("res://assets/ui/settings/sound-effects-enabled.png")
const SOUND_DISABLED_ICON: Texture2D = preload("res://assets/ui/settings/sound-effects-disabled.png")

@export var toggle_kind := ToggleKind.MUSIC

var enabled_state := true


func _ready() -> void:
	resized.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	queue_redraw()


func set_enabled_state(value: bool) -> void:
	enabled_state = value
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	var press_offset := Vector2(0.0, 8.0) if button_pressed else Vector2.ZERO
	var button_extent := Vector2.ONE * radius * 1.16
	draw_texture_rect(BUTTON_TEXTURE, Rect2(center - button_extent + press_offset, button_extent * 2.0), false)
	var icon := _get_icon()
	var icon_extent := Vector2.ONE * radius * 0.72
	draw_texture_rect(icon, Rect2(center - icon_extent + press_offset, icon_extent * 2.0), false)


func _get_icon() -> Texture2D:
	match toggle_kind:
		ToggleKind.MUSIC:
			return MUSIC_ENABLED_ICON if enabled_state else MUSIC_DISABLED_ICON
		ToggleKind.SOUND_EFFECTS:
			return SOUND_ENABLED_ICON if enabled_state else SOUND_DISABLED_ICON
	return MUSIC_ENABLED_ICON
