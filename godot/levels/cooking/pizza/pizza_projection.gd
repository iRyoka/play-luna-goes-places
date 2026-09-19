class_name PizzaProjection
extends RefCounted

## Draws flat artwork onto a receding surface.
##
## The pizza is drawn in a fixed three-quarter view, which is right on the table but
## wrong once it is inside the oven, where the hearth floor recedes far more
## steeply. Godot's 2D transforms are affine, so they can squash and skew but cannot
## make a far edge narrower than a near one.
##
## This maps the artwork onto an arbitrary four-cornered shape instead. The corners
## are warped exactly, and the texture between them is drawn as a grid of small
## pieces, each one small enough that interpolating across it is indistinguishable
## from the real thing.
##
## Quad corners are always ordered far-left, far-right, near-right, near-left, which
## matches the unit square's (0,0) (1,0) (1,1) (0,1).

const SUBDIVISIONS := 12


## Coefficients mapping the unit square onto `quad`, by the standard closed form —
## no linear solve needed for this case.
static func unit_square_to_quad(quad: PackedVector2Array) -> PackedFloat32Array:
	var p0 := quad[0]
	var p1 := quad[1]
	var p2 := quad[2]
	var p3 := quad[3]
	var dx1 := p1.x - p2.x
	var dx2 := p3.x - p2.x
	var dx3 := p0.x - p1.x + p2.x - p3.x
	var dy1 := p1.y - p2.y
	var dy2 := p3.y - p2.y
	var dy3 := p0.y - p1.y + p2.y - p3.y

	var g := 0.0
	var h := 0.0
	var determinant := dx1 * dy2 - dy1 * dx2
	if not (is_zero_approx(dx3) and is_zero_approx(dy3)) and not is_zero_approx(determinant):
		g = (dx3 * dy2 - dy3 * dx2) / determinant
		h = (dx1 * dy3 - dy1 * dx3) / determinant

	return PackedFloat32Array([
		p1.x - p0.x + g * p1.x,
		p3.x - p0.x + h * p3.x,
		p0.x,
		p1.y - p0.y + g * p1.y,
		p3.y - p0.y + h * p3.y,
		p0.y,
		g,
		h,
	])


## Where (u, v) in the unit square lands on the quad.
static func map_point(coefficients: PackedFloat32Array, u: float, v: float) -> Vector2:
	var denominator := coefficients[6] * u + coefficients[7] * v + 1.0
	if is_zero_approx(denominator):
		denominator = 0.0001
	return Vector2(
		(coefficients[0] * u + coefficients[1] * v + coefficients[2]) / denominator,
		(coefficients[3] * u + coefficients[4] * v + coefficients[5]) / denominator,
	)


## The sub-quad that the rectangle `region` of the unit square maps onto. Used to
## carry a topping onto the same surface as the food it sits on.
static func map_region(coefficients: PackedFloat32Array, region: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		map_point(coefficients, region.position.x, region.position.y),
		map_point(coefficients, region.end.x, region.position.y),
		map_point(coefficients, region.end.x, region.end.y),
		map_point(coefficients, region.position.x, region.end.y),
	])


## Draws the whole of `texture` onto `quad`.
static func draw_texture_quad(
	canvas: CanvasItem,
	texture: Texture2D,
	quad: PackedVector2Array,
	modulate_color := Color.WHITE,
	subdivisions := SUBDIVISIONS,
) -> void:
	var coefficients := unit_square_to_quad(quad)
	var step := 1.0 / subdivisions
	for row: int in subdivisions:
		for column: int in subdivisions:
			var u := column * step
			var v := row * step
			var points := PackedVector2Array([
				map_point(coefficients, u, v),
				map_point(coefficients, u + step, v),
				map_point(coefficients, u + step, v + step),
				map_point(coefficients, u, v + step),
			])
			var uvs := PackedVector2Array([
				Vector2(u, v),
				Vector2(u + step, v),
				Vector2(u + step, v + step),
				Vector2(u, v + step),
			])
			canvas.draw_polygon(points, PackedColorArray([modulate_color, modulate_color, modulate_color, modulate_color]), uvs, texture)


## The quad an unrotated rectangle occupies, for artwork that is not being warped.
static func rectangle_quad(center: Vector2, half_extents: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-half_extents.x, -half_extents.y),
		center + Vector2(half_extents.x, -half_extents.y),
		center + Vector2(half_extents.x, half_extents.y),
		center + Vector2(-half_extents.x, half_extents.y),
	])


## A quad lying on a receding surface: the far edge is narrower than the near one.
static func receding_quad(center: Vector2, near_half_width: float, far_half_width: float, half_height: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-far_half_width, -half_height),
		center + Vector2(far_half_width, -half_height),
		center + Vector2(near_half_width, half_height),
		center + Vector2(-near_half_width, half_height),
	])


static func lerp_quad(from: PackedVector2Array, to: PackedVector2Array, weight: float) -> PackedVector2Array:
	var blended := PackedVector2Array()
	for index: int in from.size():
		blended.append(from[index].lerp(to[index], weight))
	return blended
