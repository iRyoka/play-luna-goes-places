class_name AntJourney
extends Resource

## Shared route/presentation for three overlapping movement windows.
const SCREEN_ORIGIN := Vector2(180,180)

var points := PackedVector2Array()
var widths := PackedFloat32Array()
var distances := PackedFloat32Array()
var tiles: Array[Dictionary] = []
var markers: Array[Dictionary] = []
var covers: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var passed_distance := 0.0
var checkpoint_pass_times := {}
var path: GuidedPath
var background: Texture2D


func initialize(route: Dictionary) -> void:
	points = route.points
	widths = route.widths
	zones.assign(route.zones)
	path = GuidedPath.new(points,false)
	distances.append(0.0)
	for index in range(1,points.size()):
		distances.append(distances[-1]+points[index-1].distance_to(points[index]))


func width_at(distance: float) -> float:
	for index in range(1,distances.size()):
		if distance <= distances[index]:
			return lerpf(widths[index-1],widths[index],inverse_lerp(distances[index-1],distances[index],distance))
	return widths[-1]


static func pixel_in_source(point: Vector2,size: Vector2,orientation: String) -> Vector2:
	var result := point
	if orientation in ["T-R","B-R"]: result.x=size.x-result.x
	if orientation in ["T-R","L-T","L-R-flip"]: result.y=size.y-result.y
	return result


func is_walkable(global_point: Vector2,with_grace: bool) -> bool:
	for tile: Dictionary in tiles:
		var point := pixel_in_source(global_point-Vector2(tile.offset),tile.size,tile.orientation)
		var image: Image = tile.grace if with_grace else tile.support
		if with_grace: point+=Vector2(60,60)
		var pixel := Vector2i(floori(point.x),floori(point.y))
		if pixel.x>=0 and pixel.y>=0 and pixel.x<image.get_width() and pixel.y<image.get_height():
			if image.get_pixelv(pixel).r>=0.5: return true
		if not with_grace:
			for port: Array in tile.ports:
				if point.distance_to(Vector2(float(port[0]),float(port[1])))<=12: return true
	return false
