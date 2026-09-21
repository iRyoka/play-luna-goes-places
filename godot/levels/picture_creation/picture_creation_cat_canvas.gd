class_name PictureCreationCatCanvas
extends Node2D

# The approved composite provides a paper sheet for the cat. Keep the cat's
# original authoring transform: its complete silhouette fits inside this sheet.
const PAPER_TOP_Y := 80.0
const PAPER_BOTTOM_Y := 1010.0
const CAT_HIGHEST_AUTHORED_Y := 137.25
const CAT_LOWEST_AUTHORED_Y := 961.5
const SAFE_MARGIN := 40.0
const CAT_SCALE := 1.0
const CAT_OFFSET := Vector2.ZERO


func _ready() -> void:
	position = CAT_OFFSET
	scale = Vector2.ONE * CAT_SCALE
	assert(CAT_HIGHEST_AUTHORED_Y * CAT_SCALE + CAT_OFFSET.y >= PAPER_TOP_Y + SAFE_MARGIN)
	assert(CAT_LOWEST_AUTHORED_Y * CAT_SCALE + CAT_OFFSET.y <= PAPER_BOTTOM_Y - SAFE_MARGIN)
