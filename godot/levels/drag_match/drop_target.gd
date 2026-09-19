class_name DropTarget
extends Area2D

signal piece_accepted(match_id: StringName)

@export var match_id: StringName
@export var shape_kind := Draggable.ShapeKind.CIRCLE
@export var visual_radius := 82.0
@export var acceptance_radius := 176.0
@export var silhouette_color := Color("#52665e")

var _feedback_tween: Tween
var _is_occupied := false


func _ready() -> void:
	input_pickable = false
	queue_redraw()


func contains_drop_point(drop_position: Vector2) -> bool:
	return global_position.distance_to(drop_position) <= acceptance_radius


func can_accept(piece_match_id: StringName, drop_position: Vector2) -> bool:
	return not _is_occupied and piece_match_id == match_id and contains_drop_point(drop_position)


func accept_piece(piece_match_id: StringName) -> bool:
	if _is_occupied or piece_match_id != match_id:
		return false
	_is_occupied = true
	queue_redraw()
	_play_pop_feedback()
	piece_accepted.emit(match_id)
	return true


func play_wrong_feedback() -> void:
	_stop_feedback()
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "scale", Vector2(0.95, 1.05), 0.07)
	_feedback_tween.tween_property(self, "scale", Vector2(1.04, 0.96), 0.08)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.1)


func is_occupied() -> bool:
	return _is_occupied


func _play_pop_feedback() -> void:
	_stop_feedback()
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.11)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.15)


func _stop_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()


func _draw() -> void:
	var outer_color := Color(1.0, 0.91, 0.62, 0.75) if _is_occupied else Color(0.96, 0.89, 0.72, 0.8)
	_draw_shape(Vector2.ZERO, visual_radius + 20.0, outer_color)
	_draw_shape(Vector2.ZERO, visual_radius, silhouette_color if not _is_occupied else silhouette_color.lightened(0.16))


func _draw_shape(center: Vector2, radius: float, color: Color) -> void:
	match shape_kind:
		Draggable.ShapeKind.CIRCLE:
			draw_circle(center, radius, color)
		Draggable.ShapeKind.TRIANGLE:
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius * 0.92, radius * 0.78),
				center + Vector2(-radius * 0.92, radius * 0.78),
			]), color)
		Draggable.ShapeKind.SQUARE:
			draw_rect(Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), color)
