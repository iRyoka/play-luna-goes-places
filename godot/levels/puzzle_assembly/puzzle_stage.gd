class_name PuzzleStage
extends Resource

## One complete picture to assemble. A level plays its stages in order, so a
## second picture is a second stage resource plus its artwork rather than new
## mechanic code.

## Background behind this picture. When empty the board's default background is
## used, and when that is empty too the level shows its plain placeholder
## backing rather than failing.
@export var background: Texture2D
## How much colour the background keeps. Backgrounds are pushed back so the
## parts stay the brightest thing on screen; a background already painted pale
## needs less of this, or none.
@export_range(0.0, 1.0) var background_saturation := 0.9
## How much light the background keeps, applied after the desaturation.
@export_range(0.0, 1.0) var background_dim := 0.93
## The parts of this picture, in authoring order.
@export var parts: Array[PuzzlePart] = []
## Artwork the child does not place. It is on screen from the first frame at its
## authored position and draw order, behind everything else. Use it only for
## shapes with no identity of their own to recognise, such as the dark space
## behind a doorway; anything a child could name belongs in `parts`.
@export var backing_parts: Array[PuzzlePart] = []
## Always-visible perimeter rectangles a part may rest in before it is placed.
## There must be at least one slot per part.
@export var start_slots: Array[Rect2] = []
## Whether a fresh run reallocates the parts among these approved safe slots.
@export var shuffle_start_slots := true


func get_part_count() -> int:
	return parts.size()
