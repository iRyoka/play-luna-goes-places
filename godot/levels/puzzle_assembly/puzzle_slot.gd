class_name PuzzleSlot
extends Node2D

## The authored destination of one part: a muted silhouette of the artwork that
## belongs here, with a snap radius generous enough that a near-correct release
## still counts.

@export var piece_id: StringName
@export var snap_radius := 0.0
@export var artwork: Texture2D
@export var artwork_scale := Vector2.ONE

const SILHOUETTE_SHADER := preload("res://levels/puzzle_assembly/puzzle_silhouette.gdshader")
## Extra reach beyond the snap radius that still counts as touching this target,
## so a near miss can answer with its own wiggle.
const TOUCH_GRACE := 35.0

var _occupied := false
var _feedback_tween: Tween


func _ready() -> void:
	_add_silhouette()


func can_accept(piece: PuzzlePiece, drop_position: Vector2) -> bool:
	return not _occupied and piece.piece_id == piece_id and global_position.distance_to(drop_position) <= snap_radius


func contains(drop_position: Vector2) -> bool:
	return global_position.distance_to(drop_position) <= snap_radius + TOUCH_GRACE


func accept() -> void:
	_occupied = true
	visible = false
	_feedback_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.1)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.14)


func play_wrong_feedback() -> void:
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "scale", Vector2(0.96, 1.04), 0.07)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.1)


func is_occupied() -> bool:
	return _occupied


func get_snap_radius() -> float:
	return snap_radius


func _add_silhouette() -> void:
	if artwork == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = artwork
	sprite.scale = artwork_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var material := ShaderMaterial.new()
	material.shader = SILHOUETTE_SHADER
	material.set_shader_parameter("outline_color", Color("#f1dfb2"))
	sprite.material = material
	add_child(sprite)
