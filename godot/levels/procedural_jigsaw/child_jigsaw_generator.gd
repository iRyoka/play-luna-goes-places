class_name ChildJigsawGenerator
extends RefCounted

## A bounded shared-edge cutter for large, child-readable image fragments.
const DEFAULTS := {
	"seed": 1, "jitter_fraction": 0.16, "curve_probability": 0.35,
	"curve_depth": 0.07, "curve_subdivisions": 12, "max_attempts": 64,
	"min_area_ratio": 0.60, "max_aspect_ratio": 2.0, "min_angle_deg": 50.0,
}


func generate_layout(image_size: Vector2, rows: int = 4, columns: int = 4, overrides: Dictionary = {}) -> Dictionary:
	if image_size.x <= 0.0 or image_size.y <= 0.0 or rows < 1 or columns < 1:
		return {"success": false, "errors": PackedStringArray(["Invalid image or grid size."])}
	var config := DEFAULTS.duplicate()
	config.merge(overrides, true)
	var nominal := image_size / Vector2(columns, rows)
	for attempt in range(int(config.max_attempts)):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(config.seed) + attempt * 104729
		var result := _build(image_size, rows, columns, config, rng)
		if _is_valid(result.pieces, nominal, config):
			result.success = true
			result.attempt = attempt + 1
			result.config = config
			return result
	return {"success": false, "errors": PackedStringArray(["No readable layout after retries."]), "config": config}


func _build(size: Vector2, rows: int, columns: int, config: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cell := size / Vector2(columns, rows)
	var vertices: Array = []
	for row in range(rows + 1):
		var line: Array = []
		for column in range(columns + 1):
			var point := Vector2(column * cell.x, row * cell.y)
			if row > 0 and row < rows and column > 0 and column < columns:
				point += Vector2(rng.randf_range(-cell.x, cell.x), rng.randf_range(-cell.y, cell.y)) * float(config.jitter_fraction)
			line.append(point)
		vertices.append(line)
	var horizontal := {}
	var vertical := {}
	for row in range(rows + 1):
		for column in range(columns):
			horizontal[_key(row, column)] = _edge(vertices[row][column], vertices[row][column + 1], row > 0 and row < rows, config, rng)
	for row in range(rows):
		for column in range(columns + 1):
			vertical[_key(row, column)] = _edge(vertices[row][column], vertices[row + 1][column], column > 0 and column < columns, config, rng)
	var pieces: Array = []
	for row in range(rows):
		for column in range(columns):
			var polygon := PackedVector2Array()
			_append(polygon, horizontal[_key(row, column)], true)
			_append(polygon, vertical[_key(row, column + 1)], false)
			_append(polygon, _reverse(horizontal[_key(row + 1, column)]), false)
			_append(polygon, _reverse(vertical[_key(row, column)]), false)
			pieces.append({"id": row * columns + column, "row": row, "column": column, "polygon": polygon, "bbox": _bbox(polygon)})
	return {"pieces": pieces}


func _edge(a: Vector2, b: Vector2, internal: bool, config: Dictionary, rng: RandomNumberGenerator) -> PackedVector2Array:
	if not internal or rng.randf() >= float(config.curve_probability):
		return PackedVector2Array([a, b])
	var direction := b - a
	var normal := Vector2(-direction.y, direction.x).normalized()
	var depth := direction.length() * float(config.curve_depth) * (-1.0 if rng.randf() < 0.5 else 1.0)
	var result := PackedVector2Array()
	for index in range(int(config.curve_subdivisions)):
		var t := float(index) / float(int(config.curve_subdivisions) - 1)
		result.append(a.lerp(b, t) + normal * sin(t * PI) * depth)
	return result


func _is_valid(pieces: Array, nominal: Vector2, config: Dictionary) -> bool:
	var nominal_area := nominal.x * nominal.y
	for piece in pieces:
		var polygon: PackedVector2Array = piece.polygon
		var bounds: Rect2 = piece.bbox
		if absf(_polygon_area(polygon)) < nominal_area * float(config.min_area_ratio):
			return false
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or maxf(bounds.size.x / bounds.size.y, bounds.size.y / bounds.size.x) > float(config.max_aspect_ratio):
			return false
		if Geometry2D.triangulate_polygon(polygon).is_empty():
			return false
	return true


func _bbox(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect


func _polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index in points.size():
		var next: Vector2 = points[(index + 1) % points.size()]
		area += points[index].cross(next)
	return area * 0.5


func _append(destination: PackedVector2Array, source: PackedVector2Array, include_first: bool) -> void:
	for index in range(0 if include_first else 1, source.size()):
		destination.append(source[index])


func _reverse(points: PackedVector2Array) -> PackedVector2Array:
	var reversed := PackedVector2Array()
	for index in range(points.size() - 1, -1, -1):
		reversed.append(points[index])
	return reversed


func _key(row: int, column: int) -> String:
	return "%d:%d" % [row, column]
