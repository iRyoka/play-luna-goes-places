class_name PuzzlePiece
extends Node2D

## One draggable part of the picture. It rests in a visible start slot at a
## reduced size, grows to its assembled size while carried, and either snaps
## into its target or returns home. It never rotates and never records failure.
##
## A piece does not pick up its own presses. Touch regions are deliberately much
## larger than the artwork and overlap each other, so deciding which part a press
## belongs to is the level's job; a piece only reports whether a point is within
## its reach.

signal drag_started
signal drop_requested(piece: PuzzlePiece, drop_position: Vector2)
signal placed(piece: PuzzlePiece)

@export var piece_id: StringName
@export var touch_padding := 46.0
@export var artwork: Texture2D
@export var artwork_scale := Vector2.ONE
@export var home_artwork_scale := Vector2.ONE
@export var artwork_touch_radius := 0.0
@export var home_touch_radius := 0.0
@export var placed_z_index := 2

const FALLBACK_TOUCH_RADIUS := 120.0

var _home_position := Vector2.ZERO
var _pointer_id := -2
var _drag_offset := Vector2.ZERO
var _dragging := false
var _placed := false
var _resolving := false
var _input_enabled := true
var _feedback_tween: Tween
var _artwork_sprite: Sprite2D


func _ready() -> void:
	_home_position = global_position
	_add_artwork()


func _input(event: InputEvent) -> void:
	if not _dragging or not _input_enabled or _placed:
		return
	if event is InputEventScreenDrag and event.index == _pointer_id:
		global_position = event.position + _drag_offset
	elif event is InputEventScreenTouch and event.index == _pointer_id and not event.pressed:
		_release(event.position)
	elif event is InputEventMouseMotion and _pointer_id == -1:
		global_position = event.position + _drag_offset
	elif event is InputEventMouseButton and _pointer_id == -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release(event.position)


func begin_drag(pointer_position: Vector2, pointer_id: int = -1) -> bool:
	if not _input_enabled or _placed or _dragging or _resolving:
		return false
	_stop_feedback()
	_pointer_id = pointer_id
	_drag_offset = global_position - pointer_position
	_dragging = true
	z_index = 20
	scale = Vector2(1.04, 1.04)
	if _artwork_sprite != null:
		_feedback_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_feedback_tween.tween_property(_artwork_sprite, "scale", artwork_scale, 0.16)
	drag_started.emit()
	return true


func release_at(pointer_position: Vector2) -> void:
	if _dragging:
		_release(pointer_position)


func snap_to(target_position: Vector2) -> void:
	if _placed:
		return
	_stop_feedback()
	_dragging = false
	_resolving = false
	_placed = true
	_input_enabled = false
	z_index = placed_z_index
	_feedback_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(self, "global_position", target_position, 0.2)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	if _artwork_sprite != null:
		_feedback_tween.tween_property(_artwork_sprite, "scale", artwork_scale, 0.2)
	_feedback_tween.finished.connect(func() -> void: placed.emit(self))


func return_home() -> void:
	if _placed:
		return
	_stop_feedback()
	_dragging = false
	_resolving = true
	_input_enabled = false
	z_index = 4
	var wiggle := create_tween()
	wiggle.tween_property(self, "rotation", 0.07, 0.05)
	wiggle.tween_property(self, "rotation", -0.05, 0.08)
	wiggle.tween_property(self, "rotation", 0.0, 0.08)
	_feedback_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(self, "global_position", _home_position, 0.24)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.18)
	if _artwork_sprite != null:
		_feedback_tween.tween_property(_artwork_sprite, "scale", home_artwork_scale, 0.18)
	_feedback_tween.finished.connect(func() -> void:
		_resolving = false
		_input_enabled = true
	)


func is_placed() -> bool:
	return _placed


func is_dragging() -> bool:
	return _dragging


## Whether a press could start carrying this piece right now.
func can_begin_drag() -> bool:
	return _input_enabled and not _placed and not _dragging and not _resolving


## Whether `point` is within this piece's reach. The region is a generous circle
## around the piece rather than its artwork, so a child never has to aim.
func contains_point(point: Vector2) -> bool:
	return global_position.distance_to(point) <= get_touch_radius()


func get_touch_radius() -> float:
	if home_touch_radius > 0.0 and not _placed:
		return home_touch_radius + touch_padding
	if artwork_touch_radius > 0.0:
		return artwork_touch_radius + touch_padding
	return FALLBACK_TOUCH_RADIUS + touch_padding


func set_interaction_enabled(enabled: bool) -> void:
	_input_enabled = enabled and not _placed
	if not _input_enabled:
		_dragging = false
		_pointer_id = -2


func get_home_global_position() -> Vector2:
	return _home_position


func shift_layout(offset: Vector2) -> void:
	global_position += offset
	_home_position += offset


func _release(pointer_position: Vector2) -> void:
	global_position = pointer_position + _drag_offset
	_dragging = false
	_pointer_id = -2
	_resolving = true
	drop_requested.emit(self, global_position)


func _add_artwork() -> void:
	if artwork == null:
		return
	_artwork_sprite = Sprite2D.new()
	_artwork_sprite.texture = artwork
	_artwork_sprite.scale = home_artwork_scale
	_artwork_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_artwork_sprite)


func _stop_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
