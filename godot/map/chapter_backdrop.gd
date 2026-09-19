@tool
class_name ChapterBackdrop
extends Control

## Shared chapter-map backdrop: it owns the visual projection of the authored
## progression graph. Each chapter supplies its own background in `_draw()` and
## then calls `draw_route_segments()` so routes stay above that background.

const PATH_COLOR := Color("#f1d49a")
const PATH_EDGE_COLOR := Color(0.34, 0.25, 0.18, 0.28)
const FUTURE_PATH_COLOR := Color(0.91, 0.80, 0.58, 0.95)
const EDITOR_REFERENCE_SIZE := Vector2(2160.0, 1080.0)

var route_segments: Array[Dictionary] = []


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func set_route_segments(next_route_segments: Array[Dictionary]) -> void:
	route_segments = next_route_segments
	queue_redraw()


func get_draw_size() -> Vector2:
	return size if size != Vector2.ZERO else EDITOR_REFERENCE_SIZE


func draw_route_segments() -> void:
	var draw_size := get_draw_size()
	for segment: Dictionary in route_segments:
		var start := draw_size * (segment["from"] as Vector2)
		var finish := draw_size * (segment["to"] as Vector2)
		var is_future := bool(segment["is_future"])
		var start_handle := draw_size * (segment["from_handle"] as Vector2)
		var finish_handle := draw_size * (segment["to_handle"] as Vector2)
		_draw_route_segment(start, finish, start_handle, finish_handle, is_future)


func _draw_route_segment(
	start: Vector2,
	finish: Vector2,
	start_handle: Vector2,
	finish_handle: Vector2,
	is_future: bool,
) -> void:
	var direction := finish - start
	var length := direction.length()
	if length <= 0.0:
		return
	var visible_fraction := 1.0
	if is_future:
		visible_fraction -= minf(82.0, length * 0.32) / length
	var curve := _get_smooth_curve(start, finish, start_handle, finish_handle, visible_fraction)
	if is_future:
		_draw_dashed_curve(curve, FUTURE_PATH_COLOR, maxf(20.0, size.y * 0.019))
		return
	draw_polyline(curve, PATH_EDGE_COLOR, maxf(26.0, size.y * 0.027), true)
	draw_polyline(curve, PATH_COLOR, maxf(17.0, size.y * 0.018), true)


func _get_smooth_curve(
	start: Vector2,
	finish: Vector2,
	start_handle: Vector2,
	finish_handle: Vector2,
	end_fraction: float,
) -> PackedVector2Array:
	var direction := finish - start
	var default_handle := direction * 0.28
	var control_a := start + (start_handle if not start_handle.is_zero_approx() else default_handle)
	var control_b := finish - (finish_handle if not finish_handle.is_zero_approx() else default_handle)
	var points := PackedVector2Array()
	for index in range(25):
		var t := end_fraction * float(index) / 24.0
		var inverse_t := 1.0 - t
		points.append(
			inverse_t * inverse_t * inverse_t * start
			+ 3.0 * inverse_t * inverse_t * t * control_a
			+ 3.0 * inverse_t * t * t * control_b
			+ t * t * t * finish
		)
	return points


func _draw_dashed_curve(points: PackedVector2Array, color: Color, width: float) -> void:
	for index in range(0, points.size() - 2, 4):
		draw_line(points[index], points[min(index + 2, points.size() - 1)], color, width, true)
