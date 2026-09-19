class_name PictureColorRegion
extends Resource

@export var id: StringName
@export var polygon: PackedVector2Array


func is_valid() -> bool:
	return not id.is_empty() and polygon.size() >= 3


func contains(position: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(position, polygon)
