extends Node2D

const LANDMARK_SIZE := Vector2(410.0, 410.0)
const ENTRY_MEDALLION_SIZE := Vector2(430.0, 430.0)
const HALO_SIZE := Vector2(455.0, 455.0)
const LANDMARK_TEXTURES: Array[Texture2D] = [
	preload("res://assets/environments/chapter-01/map/location-tbilisi.png"),
	preload("res://assets/environments/chapter-01/map/location-waterfall.png"),
	preload("res://assets/environments/chapter-01/map/location-forest.png"),
]
const COMPLETED_HALO: Texture2D = preload("res://assets/environments/chapter-01/map/completed-halo.png")
const ENTRY_MEDALLION: Texture2D = preload("res://assets/ui/common/circular-paper-button.png")

@export_enum("Drag and match", "Memory", "Numbers") var location_kind := 0
@export var completed := false:
	set(value):
		completed = value
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var medallion_rect := Rect2(-ENTRY_MEDALLION_SIZE * 0.5 + Vector2(0.0, -30.0), ENTRY_MEDALLION_SIZE)
	draw_texture_rect(ENTRY_MEDALLION, medallion_rect, false, Color(1.0, 1.0, 1.0, 0.94))
	var landmark_rect := Rect2(-LANDMARK_SIZE * 0.5 + Vector2(0.0, -38.0), LANDMARK_SIZE)
	draw_texture_rect(LANDMARK_TEXTURES[location_kind], landmark_rect, false)
	if completed:
		var halo_rect := Rect2(-HALO_SIZE * 0.5 + Vector2(0.0, -34.0), HALO_SIZE)
		draw_texture_rect(COMPLETED_HALO, halo_rect, false)


func set_completed(value: bool) -> void:
	completed = value
