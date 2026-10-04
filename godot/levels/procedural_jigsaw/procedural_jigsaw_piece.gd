class_name ProceduralJigsawPiece
extends PuzzlePiece

const MATTE_PADDING := 12.0
const MATTE_COLOR := Color(0.97, 0.93, 0.82, 0.78)
const TOUCH_PADDING := 28.0

var polygon: PackedVector2Array
var uv: PackedVector2Array
var _visual: Polygon2D
var _visual_center := Vector2.ZERO
var _matte_outlines: Array[PackedVector2Array] = []
var _touch_outlines: Array[PackedVector2Array] = []
var _matte_visible := true


func _draw() -> void:
	if not _matte_visible:
		return
	draw_set_transform(Vector2.ZERO, 0.0, home_artwork_scale)
	for outline in _matte_outlines:
		draw_colored_polygon(outline, MATTE_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _add_artwork() -> void:
	if artwork == null:
		return
	_visual = Polygon2D.new()
	_visual.polygon = polygon
	_visual.uv = uv
	_visual.texture = artwork
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_visual.scale = home_artwork_scale
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	_visual_center = bounds.get_center()
	add_child(_visual)
	_refresh_matte()


func _refresh_matte() -> void:
	# Every source picture is opaque. Offsetting its cut polygon is equivalent
	# to dilating the visible fragment mask, with constant screen-space padding.
	_matte_outlines.assign(Geometry2D.offset_polygon(polygon, MATTE_PADDING / home_artwork_scale.x, Geometry2D.JOIN_ROUND))
	_touch_outlines.assign(Geometry2D.offset_polygon(polygon, TOUCH_PADDING / home_artwork_scale.x, Geometry2D.JOIN_ROUND))
	queue_redraw()


func contains_point(point: Vector2) -> bool:
	var local_point := to_local(point) / home_artwork_scale
	for outline in _touch_outlines:
		if Geometry2D.is_point_in_polygon(local_point, outline):
			return true
	return false


func begin_drag(pointer_position: Vector2, pointer_id: int = -1) -> bool:
	var started := super.begin_drag(pointer_position, pointer_id)
	if started and _visual != null:
		_matte_visible = false
		queue_redraw()
		_visual.scale = artwork_scale
		# Polygon pieces use their crop corner as the node origin, unlike the
		# authored Sprite2D pieces whose origin is already centred. Centre the
		# carried fragment beneath the pointer so it neither jumps nor drifts.
		_drag_offset = -_visual_center * artwork_scale
		global_position = pointer_position + _drag_offset
	return started


func return_home() -> void:
	if _visual != null:
		_visual.scale = home_artwork_scale
	_matte_visible = true
	queue_redraw()
	super.return_home()


func snap_to(target_position: Vector2) -> void:
	if _visual != null:
		_visual.scale = artwork_scale
	_matte_visible = false
	queue_redraw()
	super.snap_to(target_position)


func refresh_layout_scale() -> void:
	if _visual != null:
		_visual.scale = artwork_scale if is_placed() or is_dragging() else home_artwork_scale
	_refresh_matte()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_dragging():
			return_home()
