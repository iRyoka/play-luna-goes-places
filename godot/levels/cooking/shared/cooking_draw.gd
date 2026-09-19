class_name CookingDraw
extends RefCounted

## Drawing helpers both cooking recipes proved they need.
##
## Every object on a cooking board is a transparent export placed by its centre and
## drawn at an authored width, because that is how the artwork pipeline exports
## them. Both boards had written these out identically; there are twenty-five call
## sites between them.

## Draws `texture` centred on `center`, scaled so it is `target_width` across and
## keeps its own aspect.
static func texture_centered(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	target_width: float,
	modulate_color := Color.WHITE,
) -> void:
	var texture_size := texture.get_size()
	var target_size := Vector2(target_width, target_width * texture_size.y / texture_size.x)
	texture_centered_size(canvas, texture, center, target_size, modulate_color)


## Draws `texture` centred on `center` at an exact size, for artwork whose aspect
## was adjusted when it was aligned against the board.
static func texture_centered_size(
	canvas: CanvasItem,
	texture: Texture2D,
	center: Vector2,
	target_size: Vector2,
	modulate_color := Color.WHITE,
) -> void:
	canvas.draw_texture_rect(texture, Rect2(center - target_size * 0.5, target_size), false, modulate_color)
