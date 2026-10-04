class_name ProceduralJigsawBoard
extends Node2D

const GENERATOR := preload("res://levels/procedural_jigsaw/child_jigsaw_generator.gd")
const PIECE := preload("res://levels/procedural_jigsaw/procedural_jigsaw_piece.gd")
const SOURCES: Array[Texture2D] = [
	preload("res://assets/gameplay/procedural-jigsaw/jigsaw-giant-tree.webp"),
	preload("res://assets/gameplay/procedural-jigsaw/jigsaw-sea-terrace.webp"),
	preload("res://assets/gameplay/procedural-jigsaw/jigsaw-flamingos.webp"),
	preload("res://assets/gameplay/procedural-jigsaw/jigsaw-citrus.webp"),
	preload("res://assets/gameplay/procedural-jigsaw/jigsaw-crab.webp"),
	preload("res://assets/gameplay/procedural-jigsaw/jigsaw-hammock.webp"),
]
const VISIBLE_PIECES := 6
const BOARD_MAX_SCALE := 0.75
const VIEW_MARGIN := Vector2(86.0, 80.0)
const TRAY_WIDTH := 380.0
const TRAY_PIECE_SCALE := 0.60

signal completed

## Tests select an image and seed explicitly; ordinary entries choose both fresh.
@export var source_image_index := -1
@export var layout_seed := -1

var _pending: Array[Dictionary] = []
var _pieces: Array[ProceduralJigsawPiece] = []
var _layout_pieces: Array[Dictionary] = []
var _tray_occupied := [false, false, false, false, false, false]
var _placed := 0
var _source: Texture2D
var _selected_source_index := -1
var _board_origin := Vector2.ZERO
var _board_scale := BOARD_MAX_SCALE
var _tray_centers: Array[Vector2] = []
var _tray_bounds: Array[Rect2] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var selected := source_image_index if source_image_index >= 0 else rng.randi_range(0, SOURCES.size() - 1)
	_selected_source_index = selected
	_source = SOURCES[selected]
	var seed := layout_seed if layout_seed >= 0 else rng.randi()
	_calculate_layout()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	var layout: Dictionary = GENERATOR.new().generate_layout(_source.get_size(), 4, 4, {"seed": seed})
	if not layout.success:
		push_error("Procedural Jigsaw could not create a readable layout.")
		return
	_layout_pieces.assign(layout.pieces)
	_pending.assign(layout.pieces)
	_shuffle_pending(seed)
	_fill_slots()
	queue_redraw()


func _draw() -> void:
	var board_size := _source.get_size() * _board_scale
	draw_rect(Rect2(_board_origin + Vector2(10, 12), board_size + Vector2(20, 20)), Color(0.19, 0.24, 0.22, 0.32))
	draw_rect(Rect2(_board_origin - Vector2(10, 10), board_size + Vector2(20, 20)), Color(0.97, 0.94, 0.86, 0.96))
	draw_set_transform(_board_origin, 0.0, Vector2.ONE * _board_scale)
	draw_texture(_source, Vector2.ZERO, Color(1.0, 1.0, 1.0, 0.28))
	for piece in _layout_pieces:
		var outline: PackedVector2Array = piece.polygon
		draw_colored_polygon(outline, Color(0.96, 0.88, 0.65, 0.16))
		var closed := PackedVector2Array(outline)
		closed.append(outline[0])
		draw_polyline(closed, Color(0.40, 0.25, 0.12, 0.72), 7.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_begin_nearest(event.position, event.index)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_begin_nearest(event.position, -1)


func _begin_nearest(position: Vector2, pointer_id: int) -> void:
	for piece in _pieces:
		if piece.is_dragging(): return
	var candidate: ProceduralJigsawPiece
	var nearest := INF
	for piece in _pieces:
		if piece.can_begin_drag() and piece.contains_point(position):
			var center := piece.to_global(piece._visual_center * piece.home_artwork_scale)
			var distance := center.distance_squared_to(position)
			if distance < nearest:
				nearest = distance
				candidate = piece
	if candidate != null: candidate.begin_drag(position, pointer_id)


func _fill_slots() -> void:
	while _pieces.size() < VISIBLE_PIECES and not _pending.is_empty():
		var data: Dictionary = _pending.pop_front()
		var index := _tray_occupied.find(false)
		if index < 0:
			return
		_tray_occupied[index] = true
		var piece: ProceduralJigsawPiece = PIECE.new()
		piece.artwork = _source
		piece.piece_id = StringName("piece_%d" % data.id)
		piece.polygon = _local(data.polygon, data.bbox.position)
		piece.uv = data.polygon
		piece.artwork_scale = Vector2.ONE * _board_scale
		var tray_scale := _tray_scale_for(data.bbox.size, index)
		piece.home_artwork_scale = Vector2.ONE * tray_scale
		piece.home_touch_radius = 155.0
		piece.artwork_touch_radius = 170.0
		piece.global_position = _tray_centers[index] - data.bbox.size * tray_scale * 0.5
		piece.set_meta("picture_origin", data.bbox.position)
		piece.set_meta("picture_size", data.bbox.size)
		piece.set_meta("target", _board_origin + data.bbox.position * _board_scale)
		piece.set_meta("tray_slot", index)
		add_child(piece); _pieces.append(piece)
		piece.drop_requested.connect(_on_drop)
		piece.placed.connect(_on_placed)


func _on_drop(piece: ProceduralJigsawPiece, position: Vector2) -> void:
	if position.distance_to(piece.get_meta("target")) <= 190.0: piece.snap_to(piece.get_meta("target"))
	else: piece.return_home()


func _on_placed(piece: ProceduralJigsawPiece) -> void:
	_tray_occupied[piece.get_meta("tray_slot")] = false
	_pieces.erase(piece)
	_placed += 1
	if _placed == 16: completed.emit()
	else: _fill_slots()


func get_visible_piece_count() -> int:
	return _pieces.size()


func get_selected_source_index() -> int:
	return _selected_source_index


func get_pending_piece_count() -> int:
	return _pending.size()


func get_visible_pieces() -> Array[ProceduralJigsawPiece]:
	return _pieces


func _local(points: PackedVector2Array, origin: Vector2) -> PackedVector2Array:
	var local := PackedVector2Array()
	for point in points:
		local.append(point - origin)
	return local


func _shuffle_pending(seed: int) -> void:
	var order_rng := RandomNumberGenerator.new()
	order_rng.seed = seed + 7919
	for index in range(_pending.size() - 1, 0, -1):
		var other := order_rng.randi_range(0, index)
		var held: Dictionary = _pending[index]
		_pending[index] = _pending[other]
		_pending[other] = held


func _calculate_layout() -> void:
	var layout := layout_for_view(get_viewport_rect().size, _source.get_size())
	_board_origin = layout.origin
	_board_scale = layout.scale
	_tray_centers.assign(layout.tray_centers)
	_tray_bounds.assign(layout.tray_bounds)


func _tray_scale_for(piece_size: Vector2, slot: int) -> float:
	var tray := _tray_bounds[int(slot / 3)]
	var available_height := minf(get_viewport_rect().size.y * 0.22 - 24.0, 168.0)
	return minf(TRAY_PIECE_SCALE, minf((tray.size.x - 24.0) / piece_size.x, available_height / piece_size.y))


static func layout_for_view(view: Vector2, picture: Vector2) -> Dictionary:
	var board_scale := minf(BOARD_MAX_SCALE, (view.x - TRAY_WIDTH * 2.0 - VIEW_MARGIN.x * 2.0) / picture.x)
	board_scale = minf(board_scale, (view.y - VIEW_MARGIN.y * 2.0) / picture.y)
	board_scale = maxf(0.1, board_scale)
	var board_size := picture * board_scale
	var board_origin := (view - board_size) * 0.5
	var left_x := (board_origin.x + VIEW_MARGIN.x) * 0.5
	var right_x := view.x - left_x
	var tray_centers: Array[Vector2] = []
	for side_x in [left_x, right_x]:
		for row in range(3):
			tray_centers.append(Vector2(side_x, view.y * (0.32 + row * 0.22)))
	var tray_width := minf(280.0, 2.0 * (board_origin.x - 24.0 - left_x))
	var tray_height := view.y * 0.44 + 192.0
	var tray_top := view.y * 0.32 - 96.0
	var tray_bounds: Array[Rect2] = []
	for side_x in [left_x, right_x]:
		tray_bounds.append(Rect2(Vector2(side_x - tray_width * 0.5, tray_top), Vector2(tray_width, tray_height)))
	return {"origin": board_origin, "scale": board_scale, "tray_centers": tray_centers, "tray_bounds": tray_bounds}


func _on_viewport_size_changed() -> void:
	if _source == null:
		return
	_calculate_layout()
	for piece in _pieces:
		var target: Vector2 = _board_origin + Vector2(piece.get_meta("picture_origin")) * _board_scale
		piece.set_meta("target", target)
		piece.artwork_scale = Vector2.ONE * _board_scale
		piece.home_artwork_scale = Vector2.ONE * _tray_scale_for(piece.get_meta("picture_size"), piece.get_meta("tray_slot"))
		piece.refresh_layout_scale()
		var slot: int = piece.get_meta("tray_slot")
		var home := _tray_centers[slot] - piece._visual_center * piece.home_artwork_scale
		piece.shift_layout(home - piece.get_home_global_position())
		if piece.is_placed():
			piece.global_position = target
	queue_redraw()
