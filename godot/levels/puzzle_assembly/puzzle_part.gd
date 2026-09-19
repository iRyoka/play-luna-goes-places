class_name PuzzlePart
extends Resource

## One authored part of an assembled picture: its artwork, where that artwork
## belongs in the finished picture, and how forgiving its target is. Positions,
## scale, and draw order are authored visually in the stage's `*_layout.tscn`
## and transcribed here; they are not guessed or derived from the artwork.

const DEFAULT_SNAP_RADIUS := 140.0

## Stable identity of the part inside its stage. A part accepts only the target
## carrying the same id.
@export var part_id: StringName
@export var artwork: Texture2D
## Where the part's centre sits in the finished picture, in level coordinates.
@export var assembled_position := Vector2.ZERO
## Scale the part is drawn at once it belongs to the picture.
@export var assembled_scale := Vector2.ONE
## Draw order among placed parts. A higher value covers a lower one.
@export var placed_z_index := 0
## How far from its target a release still counts as correct. Deliberately
## larger than the visible artwork; 0 falls back to half the part's own size.
@export var snap_radius := 0.0


## The visible size of the part where it belongs in the picture.
func get_assembled_size() -> Vector2:
	if artwork == null:
		return Vector2.ZERO
	return artwork.get_size() * assembled_scale


func get_snap_radius() -> float:
	if snap_radius > 0.0:
		return snap_radius
	var size := get_assembled_size()
	if size == Vector2.ZERO:
		return DEFAULT_SNAP_RADIUS
	return maxf(size.x, size.y) * 0.5
