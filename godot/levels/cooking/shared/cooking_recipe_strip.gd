class_name CookingRecipeStrip
extends RefCounted

## The picture-only recipe strip both cooking recipes show.
##
## A row of torn-paper cards, one per step, with the current step lit and every
## finished step marked. It carries no text and no numbers, so it reads the same to
## a child who cannot read as to one who can.
##
## Both recipes proved this identical: the same tile size, spacing, glow, and
## success mark, differing only in which cards they show and where the row starts.
## Those two are data and stay with each recipe — soup's row sits at x 696, pizza's
## at 600, because the oven dome sweeps into that band of its kitchen wall.
##
## A recipe may draw its own extra marks over a tile; soup puts progress stars under
## its stirring and salting cards. `tile_rect` is public so it can place them
## without repeating the arithmetic.

const TILE_SIZE := Vector2(164.0, 138.0)
const SPACING := 184.0
const GLOW_RADIUS := 106.0
const GLOW_PULSE := 6.0
const GLOW_COLOR := Color(1.0, 0.94, 0.56, 0.42)
const SUCCESS_OFFSET := Vector2(132.0, 26.0)
const SUCCESS_WIDTH := 46.0

const SUCCESS_MARK: Texture2D = preload("res://assets/gameplay/cooking/recipe-success.png")


static func tile_rect(start: Vector2, index: int) -> Rect2:
	return Rect2(start + Vector2(index * SPACING, 0.0), TILE_SIZE)


## `active` is the step now being played: earlier cards are marked finished, and the
## active one pulses. A step past the last card leaves every card marked.
static func draw_strip(
	canvas: CanvasItem,
	start: Vector2,
	cards: Array[Texture2D],
	active: int,
	cue_time: float,
) -> void:
	for index: int in cards.size():
		var rect := tile_rect(start, index)
		if index == active:
			canvas.draw_circle(rect.get_center(), GLOW_RADIUS + sin(cue_time * 3.0) * GLOW_PULSE, GLOW_COLOR)
		canvas.draw_texture_rect(cards[index], rect, false)
		if index < active:
			CookingDraw.texture_centered(canvas, SUCCESS_MARK, rect.position + SUCCESS_OFFSET, SUCCESS_WIDTH)
