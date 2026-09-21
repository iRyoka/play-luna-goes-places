class_name AntRouteGenerator
extends RefCounted

## Trail-local puzzle composition. Produces one global 5400x800 route, not
## independent boards. Artwork, support and fitted geometry share tile pixels.

const LIBRARY_PATH := "res://assets/gameplay/trail/generated-ant/route-tiles/library.json"
const ZONE_WIDTH := 1800.0
const ZONE_HEIGHT := 800.0
const ENABLED_LAYOUTS := ["1x1", "2x2", "2x3"]
const DEFERRED_LAYOUTS := ["1x2", "1x3", "2x1"]
const MAX_ATTEMPTS := 64

static var _tiles: Dictionary = {}
static var _library_errors := PackedStringArray()
static var _spacing_certificates := {}
const MIN_SEPARATION := 340.0


static func generate(seed: int) -> Dictionary:
	_load_library()
	if not _library_errors.is_empty():
		return {"seed": seed, "errors": _library_errors}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for attempt in range(MAX_ATTEMPTS):
		var result := _assemble(rng)
		var errors := validate(result)
		if errors.is_empty():
			result.seed = seed
			result.attempt = attempt
			result.errors = errors
			return result
	return {"seed": seed, "errors": PackedStringArray(["Ant puzzle exhausted its bounded attempts."])}


static func get_tile(id: String) -> Dictionary:
	_load_library()
	return _tiles.get(id, {})


static func _load_library() -> void:
	if not _tiles.is_empty() or not _library_errors.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIBRARY_PATH))
	if not parsed is Dictionary or not parsed.get("tiles") is Array:
		_library_errors.append("Missing or malformed Ant tile library.")
		return
	for record: Dictionary in parsed.tiles:
		var points := PackedVector2Array()
		for point: Array in record.points:
			points.append(Vector2(float(point[0]), float(point[1])))
		record.points = points
		record.widths = PackedFloat32Array(record.widths)
		record.size = Vector2(float(record.size[0]), float(record.size[1]))
		_tiles[record.id] = record
		_library_errors.append_array(_validate_tile(record))
	if _tiles.size() != 19:
		_library_errors.append("Ant library needs all 19 accepted families.")


static func _validate_tile(tile: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var points: PackedVector2Array = tile.points
	var size: Vector2 = tile.size
	if points.size() < 2 or tile.widths.size() != points.size():
		errors.append("%s has mismatched path/width samples." % tile.id)
		return errors
	for index in range(points.size()):
		var point := points[index]
		if point.x < 0 or point.y < 0 or point.x > size.x or point.y > size.y:
			errors.append("%s leaves its cell." % tile.id)
		# Strict interiors plus simple paths guarantee different occupied cells
		# cannot cross except at their explicitly joined active ports.
		if index > 0 and index < points.size() - 1:
			if point.x <= 0 or point.y <= 0 or point.x >= size.x or point.y >= size.y:
				errors.append("%s touches an inactive cell edge." % tile.id)
		if float(tile.widths[index]) <= 0:
			errors.append("%s has an unsupported path sample." % tile.id)
		if index > 0 and points[index - 1].distance_to(point) < 0.001:
			errors.append("%s has duplicate path samples." % tile.id)
	for first in range(points.size() - 1):
		for second in range(first + 2, points.size() - 1):
			if _intersects(points[first], points[first + 1], points[second], points[second + 1]):
				errors.append("%s self-intersects." % tile.id)
				return errors
	var distances := PackedFloat32Array([0.0])
	for index in range(1,points.size()):
		distances.append(distances[-1]+points[index-1].distance_to(points[index]))
	for first in range(points.size()-1):
		for second in range(first+2,points.size()-1):
			# Nearby spans belong to the same local bend, not separate route arms.
			if distances[second]-distances[first+1]<MIN_SEPARATION*2: continue
			if not _paths_separated(PackedVector2Array([points[first],points[first+1]]),PackedVector2Array([points[second],points[second+1]]),Vector2.INF):
				errors.append("%s has nonlocal arms closer than 340px." % tile.id)
				return errors
	return errors


static func _intersects(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	if maxf(a.x, b.x) < minf(c.x, d.x) or maxf(c.x, d.x) < minf(a.x, b.x):
		return false
	if maxf(a.y, b.y) < minf(c.y, d.y) or maxf(c.y, d.y) < minf(a.y, b.y):
		return false
	var u := b - a
	var v := d - c
	var cross1 := u.cross(c - a)
	var cross2 := u.cross(d - a)
	var cross3 := v.cross(a - c)
	var cross4 := v.cross(b - c)
	return cross1 * cross2 <= 0.000001 and cross3 * cross4 <= 0.000001


static func _pick(rng: RandomNumberGenerator, items: Array) -> String:
	return String(items[rng.randi_range(0, items.size() - 1)])


static func _layouts(rng: RandomNumberGenerator) -> PackedStringArray:
	for attempt in range(20):
		var result := PackedStringArray()
		for zone in range(3):
			var value := rng.randf()
			result.append("1x1" if value < 0.25 else "2x2" if value < 0.60 else "2x3")
		if result.count("1x1") <= 1 and not (result[0] == result[1] and result[1] == result[2]):
			return result
	return PackedStringArray(["2x2", "2x3", "2x2"])


static func _walk(layout: String, topology: String, corner: String, passage: String) -> Array:
	if layout == "2x2":
		match topology:
			"excursion": return [[corner,0,0,"L-B"],[corner,0,1,"T-R"],[corner,1,1,"L-T"],[corner,1,0,"B-R"]]
			"early-change": return [[corner,0,0,"L-B"],[corner,0,1,"T-R"],[passage,1,1,"L-R-flip"]]
			"late-change": return [[passage,0,0,"L-R"],[corner,1,0,"L-B"],[corner,1,1,"T-R"]]
	else:
		match topology:
			"central-change": return [[passage,0,0,"L-R"],[corner,1,0,"L-B"],[corner,1,1,"T-R"],[passage,2,1,"L-R"]]
			"staggered-weave": return [[corner,0,0,"L-B"],[corner,0,1,"T-R"],[corner,1,1,"L-T"],[corner,1,0,"B-R"],[passage,2,0,"L-R"]]
			"full-snake": return [[corner,0,0,"L-B"],[corner,0,1,"T-R"],[corner,1,1,"L-T"],[corner,1,0,"B-R"],[corner,2,0,"L-B"],[corner,2,1,"T-R"]]
	return []


static func transform_points(points: PackedVector2Array, size: Vector2, orientation: String) -> PackedVector2Array:
	var result := points.duplicate()
	if orientation in ["T-R", "B-R"]:
		result.reverse()
	for index in range(result.size()):
		if orientation in ["T-R", "B-R"]:
			result[index].x = size.x - result[index].x
		if orientation in ["T-R", "L-T", "L-R-flip"]:
			result[index].y = size.y - result[index].y
	return result


static func _assemble(rng: RandomNumberGenerator) -> Dictionary:
	var layouts := _layouts(rng)
	var lane := rng.randi_range(0, 1)
	var points := PackedVector2Array()
	var widths := PackedFloat32Array()
	var placements: Array[Dictionary] = []
	var zones: Array[Dictionary] = []
	var signature := PackedStringArray()
	var flip := {"L-B":"L-T","T-R":"B-R","L-T":"L-B","B-R":"T-R","L-R":"L-R-flip","L-R-flip":"L-R"}
	for zi in range(3):
		var layout := layouts[zi]
		var topology := "authored"
		var walk: Array
		if layout == "1x1":
			var family := _pick(rng, ["broad-sweep","s-weave","gentle-terrace","rising-staircase","arc-counter-turn"])
			var tile: Dictionary = _tiles["1x1-" + family]
			var base: PackedVector2Array = tile.points
			var mirrored := not is_equal_approx(base[0].y, 200.0 + lane * 400.0)
			walk = [[family,0,0,"L-R-flip" if mirrored else "L-R"]]
		else:
			var corner: String
			var passage: String
			var value := rng.randf()
			if layout == "2x2":
				corner = _pick(rng,["E01","E02","E03","E04","E05"])
				passage = _pick(rng,["S01","S02","S03"])
				topology = "excursion" if value < 0.35 else "early-change" if value < 0.675 else "late-change"
			else:
				var choice := rng.randf()
				corner = "C02" if choice < 0.4 else "C07" if choice < 0.8 else "C08"
				passage = _pick(rng,["P01","P02","P03"])
				topology = "central-change" if value < 0.3 else "staggered-weave" if value < 0.6 else "full-snake"
			walk = _walk(layout,topology,corner,passage)
			if lane == 1:
				for cell: Array in walk:
					cell[2] = 1 - int(cell[2])
					cell[3] = flip[cell[3]]
		var zone_start := maxi(points.size() - 1, 0)
		var input_lane := lane
		for cell: Array in walk:
			var id := layout + "-" + String(cell[0])
			var tile: Dictionary = _tiles[id]
			var offset := Vector2(zi * ZONE_WIDTH + int(cell[1]) * tile.size.x, int(cell[2]) * 400.0)
			var path := transform_points(tile.points,tile.size,String(cell[3]))
			var samples: PackedFloat32Array = tile.widths.duplicate()
			if cell[3] in ["T-R","B-R"]:
				samples.reverse()
			for index in range(path.size()):
				path[index] += offset
				if index == 0 and not points.is_empty():
					continue
				points.append(path[index])
				widths.append(samples[index])
			placements.append({"id":id,"zone":zi,"cell":Vector2i(int(cell[1]),int(cell[2])),"offset":offset,"orientation":cell[3],"points":path})
			signature.append("%s:%d:%d:%s" % [id,int(cell[1]),int(cell[2]),String(cell[3])])
		lane = 0 if is_equal_approx(points[-1].y,200.0) else 1
		zones.append({"layout":layout,"topology":topology,"input_lane":input_lane,"output_lane":lane,"start_index":zone_start,"end_index":points.size()-1})
	return {"points":points,"widths":widths,"placements":placements,"zones":zones,"signature":"/".join(signature)}


static func validate(result: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not result.has("points") or not result.has("placements") or not result.has("zones"):
		return PackedStringArray(["Ant route result is incomplete."])
	var points: PackedVector2Array = result.points
	if result.zones.size() != 3 or points.size() < 2 or result.widths.size() != points.size():
		return PackedStringArray(["Ant needs three zones and complete path/width samples."])
	var seen := {}
	var previous := PackedVector2Array()
	var assembled := PackedVector2Array()
	var assembled_widths := PackedFloat32Array()
	for placement: Dictionary in result.placements:
		if not _tiles.has(placement.id):
			errors.append("Ant placement uses an unknown tile.")
			continue
		var tile: Dictionary = _tiles[placement.id]
		var zone_index := int(placement.zone)
		var cell: Vector2i = placement.cell
		if zone_index < 0 or zone_index > 2:
			errors.append("Ant placement has an invalid zone.")
			continue
		var layout: String = result.zones[zone_index].layout
		var columns := 1 if layout == "1x1" else 2 if layout == "2x2" else 3
		var rows := 1 if layout == "1x1" else 2
		if tile.layout != layout or cell.x < 0 or cell.x >= columns or cell.y < 0 or cell.y >= rows:
			errors.append("Ant tile does not belong to its declared grid cell.")
			continue
		var expected_offset := Vector2(zone_index*1800.0+cell.x*tile.size.x,cell.y*400.0)
		if Vector2(placement.offset).distance_to(expected_offset) > 0.001:
			errors.append("Ant tile offset does not match its grid cell.")
		if not String(placement.orientation) in tile.allowed_transforms:
			errors.append("Ant placement uses a forbidden transform.")
			continue
		var path: PackedVector2Array = placement.points
		if path.size() < 2:
			errors.append("Ant placement has no travelled path.")
			continue
		var expected := transform_points(tile.points,tile.size,String(placement.orientation))
		var offset: Vector2 = placement.offset
		for index in range(expected.size()): expected[index] += offset
		if expected != path:
			errors.append("Ant placement differs from its certified artwork path.")
		var samples: PackedFloat32Array = tile.widths.duplicate()
		if placement.orientation in ["T-R","B-R"]: samples.reverse()
		for index in range(path.size()):
			if index == 0 and not assembled.is_empty(): continue
			assembled.append(path[index])
			if index < samples.size(): assembled_widths.append(samples[index])
		var key := "%d:%s" % [placement.zone,placement.cell]
		if seen.has(key): errors.append("Ant visits an occupied cell twice.")
		seen[key] = true
		if not previous.is_empty():
			if previous[-1].distance_to(path[0]) > 0.001:
				errors.append("Ant tile ports do not meet.")
			var incoming := (previous[-1]-previous[-2]).normalized()
			var outgoing := (path[1]-path[0]).normalized()
			if rad_to_deg(acos(clampf(incoming.dot(outgoing),-1.0,1.0))) > 10.0:
				errors.append("Ant tile tangents differ by more than 10 degrees.")
		previous = path
	if assembled != points or assembled_widths != result.widths:
		errors.append("Ant global geometry differs from its ordered tile assembly.")
	for zi in range(3):
		var zone: Dictionary = result.zones[zi]
		if not String(zone.layout) in ENABLED_LAYOUTS: errors.append("Ant selected a disabled layout.")
		if int(zone.start_index) < 0 or int(zone.end_index) >= points.size() or int(zone.end_index) <= int(zone.start_index):
			errors.append("Ant zone has invalid route indices.")
			continue
		var start := points[int(zone.start_index)]
		var end := points[int(zone.end_index)]
		if start.distance_to(Vector2(zi*1800.0,200.0+int(zone.input_lane)*400.0)) > 0.001:
			errors.append("Ant missed its zone entrance.")
		if end.distance_to(Vector2((zi+1)*1800.0,200.0+int(zone.output_lane)*400.0)) > 0.001:
			errors.append("Ant missed its zone exit.")
	for point in points:
		if point.x < 0 or point.x > 5400 or point.y < 0 or point.y > 800:
			errors.append("Ant leaves its continuous 3X envelope.")
	if errors.is_empty():
		errors.append_array(_validate_spacing(result.placements))
	return errors


static func _validate_spacing(placements: Array) -> PackedStringArray:
	for first in range(placements.size()):
		for second in range(first+1,placements.size()):
			var a: Dictionary=placements[first]
			var b: Dictionary=placements[second]
			var delta := Vector2(b.offset)-Vector2(a.offset)
			var neighbors := second==first+1
			var key := "%s:%s/%s:%s/%s/%s" % [a.id,a.orientation,b.id,b.orientation,delta,neighbors]
			if not _spacing_certificates.has(key):
				var port := Vector2.INF
				if neighbors: port=a.points[-1]
				_spacing_certificates[key]=_paths_separated(a.points,b.points,port)
			if not _spacing_certificates[key]:
				return PackedStringArray(["Ant nonadjacent portions violate 340px separation."])
	return PackedStringArray()


static func _paths_separated(a: PackedVector2Array,b: PackedVector2Array,port: Vector2) -> bool:
	for ai in range(a.size()-1):
		var a0 := a[ai]
		var a1 := a[ai+1]
		for bi in range(b.size()-1):
			var b0 := b[bi]
			var b1 := b[bi+1]
			if maxf(a0.x,a1.x)+MIN_SEPARATION<=minf(b0.x,b1.x) or maxf(b0.x,b1.x)+MIN_SEPARATION<=minf(a0.x,a1.x): continue
			if maxf(a0.y,a1.y)+MIN_SEPARATION<=minf(b0.y,b1.y) or maxf(b0.y,b1.y)+MIN_SEPARATION<=minf(a0.y,a1.y): continue
			# Only the local disk at the shared port exempts consecutive tiles.
			if port.is_finite() and maxf(a0.distance_to(port),a1.distance_to(port))<=MIN_SEPARATION and maxf(b0.distance_to(port),b1.distance_to(port))<=MIN_SEPARATION: continue
			for pair in [[a0,Geometry2D.get_closest_point_to_segment(a0,b0,b1)], [a1,Geometry2D.get_closest_point_to_segment(a1,b0,b1)], [Geometry2D.get_closest_point_to_segment(b0,a0,a1),b0], [Geometry2D.get_closest_point_to_segment(b1,a0,a1),b1]]:
				if pair[0].distance_to(pair[1])>=MIN_SEPARATION-0.001: continue
				if port.is_finite() and pair[0].distance_to(port)<=MIN_SEPARATION and pair[1].distance_to(port)<=MIN_SEPARATION: continue
				return false
	return true
