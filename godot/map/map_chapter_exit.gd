@tool
class_name MapChapterExit
extends Node2D

## The chapter map's exit control. It sits in the bottom-right corner and opens
## chapter selection. The unfolded-map artwork keeps an irregular silhouette so it
## does not read as one of the circular level medallions.

const EXIT_ART: Texture2D = preload("res://assets/ui/map-controls/chapter-exit-map.png")
## Slightly wider than a map level button's 156 px, because this flat parchment
## carries less visual weight than a bright level medallion at the same size.
const VISIBLE_WIDTH := 180.0


func _draw() -> void:
	var scale_factor := VISIBLE_WIDTH / EXIT_ART.get_width()
	var draw_size := EXIT_ART.get_size() * scale_factor
	draw_texture_rect(EXIT_ART, Rect2(-draw_size * 0.5, draw_size), false)
