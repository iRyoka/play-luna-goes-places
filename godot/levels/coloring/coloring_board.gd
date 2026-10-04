class_name ColoringBoard
extends Node2D

signal meaningful_action

const CANVAS := Rect2(450, 112, 1260, 850)
const TOOL_RECTS := [Rect2(220, 285, 170, 120), Rect2(220, 420, 170, 120), Rect2(220, 555, 170, 120), Rect2(220, 690, 170, 120)]
const UNDO_RECT := Rect2(220, 850, 170, 120)
const TOOL_PANEL_RECT := Rect2(200, 265, 210, 730)
const FAMILY_X := 1770.0
const VARIANT_X := 1925.0
const SWATCH_SIZE := Vector2(102, 72)
const UI_PATH := "res://assets/gameplay/coloring/ui/"
const BACKDROP: Texture2D = preload("res://assets/gameplay/coloring/ui/promenade-background.webp")
const BOARD_ART: Texture2D = preload("res://assets/gameplay/coloring/ui/craft-board.png")
const PAPER_ART: Texture2D = preload("res://assets/gameplay/coloring/ui/cream-paper.png")
const CLIP_ART: Texture2D = preload("res://assets/gameplay/coloring/ui/wood-clip.png")
const TOOL_PANEL: Texture2D = preload("res://assets/gameplay/coloring/ui/tool-panel.png")
const PALETTE_PANEL: Texture2D = preload("res://assets/gameplay/coloring/ui/palette-panel.png")
const SIZE_PANEL: Texture2D = preload("res://assets/gameplay/coloring/ui/size-panel.png")
const TOOL_BUTTON: Texture2D = preload("res://assets/gameplay/coloring/ui/tool-button.png")
const TOOL_SELECTION: Texture2D = preload("res://assets/gameplay/coloring/ui/selection-tool-mustard.png")
const SWATCH_SELECTION: Texture2D = preload("res://assets/gameplay/coloring/ui/selection-swatch-mustard.png")
const SWATCH_SELECTION_CREAM: Texture2D = preload("res://assets/gameplay/coloring/ui/selection-swatch-cream.png")
const SIZE_SELECTION: Texture2D = preload("res://assets/gameplay/coloring/ui/selection-size-mustard.png")
const SIZE_SELECTION_CREAM: Texture2D = preload("res://assets/gameplay/coloring/ui/selection-size-cream.png")
const PAGE_OUTLINES := [
	preload("res://assets/gameplay/coloring/pages/octopus-shell-outline.png"),
	preload("res://assets/gameplay/coloring/pages/crab-outline.png"),
	preload("res://assets/gameplay/coloring/pages/sunhat-outline.png"),
	preload("res://assets/gameplay/coloring/pages/lighthouse-outline.png"),
	preload("res://assets/gameplay/coloring/pages/flamingo-outline.png"),
	preload("res://assets/gameplay/coloring/pages/village-outline.png"),
	preload("res://assets/gameplay/coloring/pages/beach-chair-outline.png"),
	preload("res://assets/gameplay/coloring/pages/sailboat-outline.png"),
]
const PAGE_REGIONS := [
	preload("res://assets/gameplay/coloring/pages/octopus-shell-region-mask.png"),
	preload("res://assets/gameplay/coloring/pages/crab-region-mask.png"),
	preload("res://assets/gameplay/coloring/pages/sunhat-region-mask.png"),
	preload("res://assets/gameplay/coloring/pages/lighthouse-region-mask.png"),
	preload("res://assets/gameplay/coloring/pages/flamingo-region-mask.png"),
	preload("res://assets/gameplay/coloring/pages/village-region-mask.png"),
	preload("res://assets/gameplay/coloring/pages/beach-chair-region-mask.png"),
	preload("res://assets/gameplay/coloring/pages/sailboat-region-mask.png"),
]
const TOOLS := [&"brush", &"fill", &"eraser", &"splash"]
const FAMILY_NAMES := ["red_pink", "orange_terracotta", "yellow_mustard", "green", "turquoise", "blue", "violet_lilac", "neutral_stone"]
const BRUSH_RADII := [12.0, 26.0, 46.0]
const UNDO_HISTORY_LIMIT := 10
const TIP_MAX_LAG := 8.0
const TIP_SLOW_TIME_CONSTANT := 0.022
const TIP_FAST_TIME_CONSTANT := 0.003
const TIP_FAST_SPEED := 1600.0
const FAMILIES := [
	[Color("F6D4D8"), Color("F0B8C4"), Color("EA8EA4"), Color("E46F8C"), Color("D95B78"), Color("C24767"), Color("A85A5D"), Color("8F4A55")],
	[Color("F8DFC9"), Color("F4C7A9"), Color("EEAA78"), Color("E4925F"), Color("D97A4E"), Color("C96A44"), Color("A95B3F"), Color("8C4A35")],
	[Color("F9EDB9"), Color("F3DE8C"), Color("EFCF5D"), Color("E8C347"), Color("DDAE32"), Color("C8962C"), Color("AE8128"), Color("8F6A24")],
	[Color("DDECCB"), Color("C7E09F"), Color("A8D06E"), Color("86BA52"), Color("679E45"), Color("4F803C"), Color("3F6535"), Color("31512D")],
	[Color("D5F1EA"), Color("B3E7DD"), Color("82D9CB"), Color("58C7BC"), Color("35B1AE"), Color("25939A"), Color("1F727E"), Color("1C5963")],
	[Color("DCEBF8"), Color("BFD8F1"), Color("97BEE4"), Color("719FCD"), Color("4E82B1"), Color("3F698E"), Color("36536F"), Color("2F435A")],
	[Color("E9DDF6"), Color("D8C3EE"), Color("C19DDF"), Color("A882CD"), Color("8C68B1"), Color("75548F"), Color("60436F"), Color("4C3558")],
	[Color("F2E7D6"), Color("E6DAC9"), Color("D4C8B7"), Color("C1B4A3"), Color("AC9F8E"), Color("938778"), Color("766B5F"), Color("5D554C")],
]

@export var picture_index := -1

var _active_tool: StringName = &"brush"
var _undo_pressed := false
var _family_index := 0
var _variant_indices := [4, 4, 4, 4, 4, 4, 4, 4]
var _tool_sizes := {&"brush": 1, &"eraser": 1}
var _open_size_tool: StringName = &""
var _operations: Array[Dictionary] = []
var _history: Array[PackedByteArray] = []
var _active_path := PackedVector2Array()
var _drawing := false
var _stroke_distance := 0.0
var _last_raw_pointer := Vector2.ZERO
var _filtered_tip := Vector2.ZERO
var _last_input_time_usec := 0
var _stroke_base: Image
var _stroke_coverage: Image
var _rng := RandomNumberGenerator.new()
var _selected_picture := 0
var _paint_image: Image
var _paint_texture: ImageTexture
var _region_pixels := PackedByteArray()
var _region_bounds: Array[Rect2i] = []
var _tool_icons: Dictionary = {}
var _size_icons: Array[Texture2D] = []
var _selector_textures: Array[Texture2D] = []
var _variant_textures: Array = []

func _ready() -> void:
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	for tool in ["brush", "fill", "eraser", "splash", "undo"]:
		_tool_icons[tool] = load(UI_PATH + tool + ".png")
	for size_name in ["small", "medium", "large"]:
		_size_icons.append(load(UI_PATH + "size-" + size_name + ".png"))
	for family_name in FAMILY_NAMES:
		_selector_textures.append(load(UI_PATH + "swatch-" + family_name + "-selector.png"))
		var variants: Array[Texture2D] = []
		for variant in range(1, 9):
			variants.append(load(UI_PATH + "swatch-" + family_name + "-" + str(variant) + ".png"))
		_variant_textures.append(variants)
	_rng.randomize()
	assert(picture_index >= -1 and picture_index < PAGE_OUTLINES.size())
	_selected_picture = picture_index if picture_index >= 0 else _rng.randi_range(0, PAGE_OUTLINES.size() - 1)
	var region_texture: Texture2D = PAGE_REGIONS[_selected_picture]
	var region_image := region_texture.get_image()
	region_image.convert(Image.FORMAT_L8)
	_region_pixels = region_image.get_data()
	assert(region_image.get_size() == Vector2i(CANVAS.size))
	assert(_region_pixels.size() == int(CANVAS.size.x * CANVAS.size.y))
	_build_region_bounds()
	_paint_image = Image.create(int(CANVAS.size.x), int(CANVAS.size.y), false, Image.FORMAT_RGBA8)
	_paint_image.fill(Color.TRANSPARENT)
	_paint_texture = ImageTexture.create_from_image(_paint_image)
	queue_redraw()


func _draw() -> void:
	_draw_background()
	draw_texture_rect(BOARD_ART, Rect2(420, 70, 1320, 930), false)
	draw_texture_rect(PAPER_ART, CANVAS, false)
	draw_texture_rect(_paint_texture, CANVAS, false)
	var outline: Texture2D = PAGE_OUTLINES[_selected_picture]
	draw_texture_rect(outline, CANVAS, false)
	draw_texture_rect(CLIP_ART, Rect2(840, -9, 480, 170), false)
	_draw_toolbox()
	_draw_palette()
	if not _open_size_tool.is_empty():
		_draw_size_popup()


func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var reference_size := Vector2(2160, 1080)
	var fit_scale := minf(viewport_size.x / reference_size.x, viewport_size.y / reference_size.y)
	scale = Vector2.ONE * fit_scale
	position = (viewport_size - reference_size * fit_scale) * 0.5
	queue_redraw()


func _draw_background() -> void:
	var frame := Rect2(-position / scale, get_viewport_rect().size / scale)
	var texture_size := BACKDROP.get_size()
	var cover := maxf(frame.size.x / texture_size.x, frame.size.y / texture_size.y)
	var visible_source := frame.size / cover
	var source_rect := Rect2((texture_size - visible_source) * 0.5, visible_source)
	draw_texture_rect_region(BACKDROP, frame, source_rect)


func _unhandled_input(event: InputEvent) -> void:
	# Godot mirrors touchscreen input as mouse input by default; handling both toggles size trays twice.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		_handle_pointer(to_local(event.position), event.pressed)
	elif event is InputEventScreenDrag:
		if _drawing: _append_stroke_point(to_local(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer(to_local(event.position), event.pressed)
	elif event is InputEventMouseMotion and _drawing and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_append_stroke_point(to_local(event.position))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _undo_pressed:
		_undo_pressed = false
		queue_redraw()


func _handle_pointer(position: Vector2, pressed: bool) -> void:
	if pressed:
		if _handle_control_press(position): return
		if not CANVAS.has_point(position): return
		_open_size_tool = &""
		match _active_tool:
			&"brush", &"eraser":
				_begin_stroke(position)
			&"fill": apply_fill_at(position)
			&"splash": apply_splash_at(position)
	else:
		_undo_pressed = false
		if _drawing:
			_finish_stroke(position)
	queue_redraw()


func _handle_control_press(position: Vector2) -> bool:
	if not _open_size_tool.is_empty():
		var popup := _popup_rect(_open_size_tool)
		if popup.has_point(position):
			var size_index := clampi(int((position.x - popup.position.x) / (popup.size.x / 3.0)), 0, 2)
			_tool_sizes[_open_size_tool] = size_index; _open_size_tool = &""; queue_redraw(); return true
	for index in TOOLS.size():
		if TOOL_RECTS[index].has_point(position):
			var tool: StringName = TOOLS[index]
			if tool == _active_tool and (tool == &"brush" or tool == &"eraser"):
				_open_size_tool = &"" if _open_size_tool == tool else tool
			else:
				_active_tool = tool
				_open_size_tool = tool if tool == &"brush" or tool == &"eraser" else &""
			queue_redraw(); return true
	if UNDO_RECT.has_point(position):
		_undo_pressed = true
		undo()
		queue_redraw()
		return true
	for row in 8:
		if Rect2(FAMILY_X, 170 + row * 88, SWATCH_SIZE.x, SWATCH_SIZE.y).has_point(position):
			_family_index = row; queue_redraw(); return true
		if Rect2(VARIANT_X, 170 + row * 88, SWATCH_SIZE.x, SWATCH_SIZE.y).has_point(position):
			_variant_indices[_family_index] = row; queue_redraw(); return true
	return false


func apply_fill_at(position: Vector2) -> bool:
	var region_id := get_region_at(position)
	if region_id == 0: return false
	_commit({"kind": &"fill", "region_id": region_id, "color": _active_color()})
	meaningful_action.emit(); queue_redraw(); return true


func get_region_at(position: Vector2) -> int:
	if not CANVAS.has_point(position): return 0
	var local := position - CANVAS.position
	return _region_pixels[floori(local.y) * int(CANVAS.size.x) + floori(local.x)]


func apply_splash_at(position: Vector2) -> bool:
	var drops := []
	for count in 14:
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(8.0, 82.0)
		drops.append({"position": position + Vector2.from_angle(angle) * distance, "radius": _rng.randf_range(6.0, 18.0)})
	_commit({"kind": &"splash", "drops": drops, "color": _active_color()})
	meaningful_action.emit(); queue_redraw(); return true


func undo() -> void:
	if _history.is_empty(): return
	var restored := Image.new()
	if restored.load_webp_from_buffer(_history[-1]) != OK: return
	_history.pop_back()
	_paint_image = restored
	_paint_texture.update(_paint_image)
	_operations.pop_back()
	queue_redraw()


func get_operation_count() -> int:
	return _operations.size()


func get_selected_picture() -> int:
	return _selected_picture


func get_region_count() -> int:
	return _region_bounds.size()


func _build_region_bounds() -> void:
	var width := int(CANVAS.size.x)
	var height := int(CANVAS.size.y)
	var left := PackedInt32Array()
	var top := PackedInt32Array()
	var right := PackedInt32Array()
	var bottom := PackedInt32Array()
	left.resize(256)
	top.resize(256)
	right.resize(256)
	bottom.resize(256)
	left.fill(width)
	top.fill(height)
	right.fill(-1)
	bottom.fill(-1)
	var largest_id := 0
	for y in height:
		for x in width:
			var region_id: int = _region_pixels[y * width + x]
			if region_id == 0:
				continue
			largest_id = maxi(largest_id, region_id)
			left[region_id] = mini(left[region_id], x)
			top[region_id] = mini(top[region_id], y)
			right[region_id] = maxi(right[region_id], x)
			bottom[region_id] = maxi(bottom[region_id], y)
	_region_bounds.clear()
	for region_id in range(1, largest_id + 1):
		assert(right[region_id] >= left[region_id])
		_region_bounds.append(Rect2i(left[region_id], top[region_id], right[region_id] - left[region_id] + 1, bottom[region_id] - top[region_id] + 1))


func _commit(operation: Dictionary) -> void:
	_save_undo(_paint_image)
	_operations.append(operation)
	_rasterize(operation)


func _append_stroke_point(position: Vector2, finish := false) -> void:
	if not _drawing or not CANVAS.has_point(position): return
	var target := position
	if not finish:
		var now := Time.get_ticks_usec()
		var elapsed := clampf(float(now - _last_input_time_usec) / 1000000.0, 1.0 / 240.0, 0.05)
		var speed := _last_raw_pointer.distance_to(position) / elapsed
		var time_constant := lerpf(TIP_SLOW_TIME_CONSTANT, TIP_FAST_TIME_CONSTANT, clampf(speed / TIP_FAST_SPEED, 0.0, 1.0))
		var response := elapsed / (time_constant + elapsed)
		_filtered_tip = _filtered_tip.lerp(position, response)
		if _filtered_tip.distance_to(position) > TIP_MAX_LAG:
			_filtered_tip = position + position.direction_to(_filtered_tip) * TIP_MAX_LAG
		target = _filtered_tip
		_last_raw_pointer = position
		_last_input_time_usec = now
	else:
		_filtered_tip = position
	var previous: Vector2 = _active_path[-1]
	var distance: float = previous.distance_to(target)
	if distance < 2.0 and not finish: return
	if distance < 0.5: return
	var steps: int = maxi(1, ceili(distance / 12.0))
	for step in range(1, steps + 1):
		_append_stroke_sample(previous.lerp(target, float(step) / steps))
	_paint_texture.update(_paint_image)
	queue_redraw()


func _begin_stroke(position: Vector2) -> void:
	_drawing = true
	_active_path = PackedVector2Array([position])
	_stroke_distance = 0.0
	_last_raw_pointer = position
	_filtered_tip = position
	_last_input_time_usec = Time.get_ticks_usec()
	_stroke_base = _paint_image.duplicate()
	_stroke_coverage = Image.create(_paint_image.get_width(), _paint_image.get_height(), false, Image.FORMAT_L8)
	_stroke_coverage.fill(Color.BLACK)


func _append_stroke_sample(position: Vector2) -> void:
	var count: int = _active_path.size()
	_stroke_distance += _active_path[count - 1].distance_to(position)
	var radius: float = BRUSH_RADII[_tool_sizes[_active_tool]]
	if count == 1:
		_paint_curve_segment(_active_path[0], _active_path[0], (_active_path[0] + position) * 0.5, radius)
	else:
		var start: Vector2 = (_active_path[count - 2] + _active_path[count - 1]) * 0.5
		var end: Vector2 = (_active_path[count - 1] + position) * 0.5
		_paint_curve_segment(start, _active_path[count - 1], end, radius)
	_active_path.append(position)


func _finish_stroke(position: Vector2) -> void:
	_append_stroke_point(position if CANVAS.has_point(position) else _last_raw_pointer, true)
	_drawing = false
	if _active_path.size() >= 2 and _stroke_distance >= 8.0:
		var count: int = _active_path.size()
		var radius: float = BRUSH_RADII[_tool_sizes[_active_tool]]
		_paint_curve_segment((_active_path[count - 2] + _active_path[count - 1]) * 0.5, _active_path[count - 1], _active_path[count - 1], radius)
		_paint_texture.update(_paint_image)
		_save_undo(_stroke_base)
		_operations.append({"kind": _active_tool})
		if _active_tool == &"brush": meaningful_action.emit()
	else:
		_paint_image = _stroke_base
		_paint_texture.update(_paint_image)
	_active_path = PackedVector2Array()
	_stroke_distance = 0.0
	_stroke_base = null
	_stroke_coverage = null


func _paint_curve_segment(start: Vector2, control: Vector2, end: Vector2, radius: float) -> void:
	var length: float = start.distance_to(control) + control.distance_to(end)
	var steps: int = maxi(1, ceili(length / maxf(2.0, radius * 0.2)))
	for step in range(steps + 1):
		var t: float = float(step) / steps
		var point: Vector2 = start * (1.0 - t) * (1.0 - t) + control * 2.0 * t * (1.0 - t) + end * t * t
		_paint_stroke_circle(point, radius)


func _paint_stroke_circle(screen_position: Vector2, radius: float) -> void:
	var center: Vector2 = screen_position - CANVAS.position
	var left: int = maxi(0, floori(center.x - radius - 1.0))
	var right: int = mini(_paint_image.get_width() - 1, ceili(center.x + radius + 1.0))
	var top: int = maxi(0, floori(center.y - radius - 1.0))
	var bottom: int = mini(_paint_image.get_height() - 1, ceili(center.y + radius + 1.0))
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			var distance: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			var coverage: float = clampf(radius + 0.5 - distance, 0.0, 1.0)
			if coverage <= _stroke_coverage.get_pixel(x, y).r: continue
			_stroke_coverage.set_pixel(x, y, Color(coverage, coverage, coverage))
			var base: Color = _stroke_base.get_pixel(x, y)
			if _active_tool == &"eraser":
				_paint_image.set_pixel(x, y, Color(base.r, base.g, base.b, base.a * (1.0 - coverage)))
			else:
				_paint_image.set_pixel(x, y, base.blend(Color(_active_color(), coverage)))


func _save_undo(image: Image) -> void:
	_history.append(image.save_webp_to_buffer(true))
	if _history.size() > UNDO_HISTORY_LIMIT: _history.pop_front()


func _active_color() -> Color:
	return FAMILIES[_family_index][_variant_indices[_family_index]]


func _rasterize(operation: Dictionary) -> void:
	match operation.kind:
		&"fill": _rasterize_region(operation.region_id, operation.color)
		&"splash":
			for drop in operation.drops: _rasterize_circle(drop.position, drop.radius, operation.color)
	_paint_texture.update(_paint_image)


func _rasterize_circle(screen_position: Vector2, radius: float, color: Color) -> void:
	var center: Vector2 = screen_position - CANVAS.position
	var left: int = max(0, floori(center.x - radius - 1.0))
	var right: int = min(_paint_image.get_width() - 1, ceili(center.x + radius + 1.0))
	var top: int = max(0, floori(center.y - radius - 1.0))
	var bottom: int = min(_paint_image.get_height() - 1, ceili(center.y + radius + 1.0))
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			var distance: float = Vector2(x, y).distance_to(center)
			if distance <= radius:
				var pixel: Color = color
				if color.a > 0.0: pixel.a *= clampf((radius + 1.0 - distance) / 3.0, 0.0, 1.0)
				_paint_image.set_pixel(x, y, pixel)


func _rasterize_region(region_id: int, color: Color) -> void:
	var bounds: Rect2i = _region_bounds[region_id - 1]
	var width := int(CANVAS.size.x)
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			if _region_pixels[y * width + x] == region_id:
				_paint_image.set_pixel(x, y, color)


func _draw_toolbox() -> void:
	draw_texture_rect(TOOL_PANEL, TOOL_PANEL_RECT, false)
	for index in TOOLS.size():
		var rect: Rect2 = TOOL_RECTS[index]
		var center := rect.get_center()
		_draw_tool_button(center, _tool_icons[String(TOOLS[index])], TOOLS[index] == _active_tool)
	_draw_tool_button(UNDO_RECT.get_center(), _tool_icons["undo"], _undo_pressed)


func _draw_tool_button(center: Vector2, icon: Texture2D, selected: bool) -> void:
	if selected:
		_draw_centered(TOOL_SELECTION, center)
	_draw_centered(TOOL_BUTTON, center)
	_draw_centered(icon, center)


func _draw_palette() -> void:
	draw_texture_rect(PALETTE_PANEL, Rect2(1750, 120, 310, 850), false)
	for row in 8:
		var family_rect := Rect2(FAMILY_X, 170 + row * 88, SWATCH_SIZE.x, SWATCH_SIZE.y)
		var variant_rect := Rect2(VARIANT_X, 170 + row * 88, SWATCH_SIZE.x, SWATCH_SIZE.y)
		_draw_swatch(family_rect, _selector_textures[row], row == _family_index)
		_draw_swatch(variant_rect, _variant_textures[_family_index][row], row == _variant_indices[_family_index])


func _draw_swatch(rect: Rect2, swatch: Texture2D, selected: bool) -> void:
	var center := rect.get_center()
	if selected:
		_draw_centered(SWATCH_SELECTION, center)
		_draw_centered(SWATCH_SELECTION_CREAM, center)
	_draw_centered(swatch, center)


func _draw_size_popup() -> void:
	var popup := _popup_rect(_open_size_tool)
	draw_texture_rect(SIZE_PANEL, popup, false)
	for index in 3:
		var center := Vector2(popup.position.x + popup.size.x * (0.166 + index / 3.0), popup.get_center().y)
		var icon := _size_icons[index]
		if index == _tool_sizes[_open_size_tool]:
			_draw_centered(SIZE_SELECTION, center)
			_draw_centered(SIZE_SELECTION_CREAM, center)
		_draw_centered(icon, center)


func _popup_rect(tool: StringName) -> Rect2:
	var index := TOOLS.find(tool)
	return Rect2(390, TOOL_RECTS[index].position.y + 8, 280, 104)


func _draw_centered(texture: Texture2D, center: Vector2) -> void:
	draw_texture_rect(texture, Rect2(center - texture.get_size() * 0.5, texture.get_size()), false)
