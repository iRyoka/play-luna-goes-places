class_name CookingBoardViewport
extends RefCounted

## The cooking recipes share one authored 2160x1080 kitchen board.  This is a
## mechanic-local display contract, not a cross-level responsive framework.

const REFERENCE_SIZE := Vector2(2160.0, 1080.0)


static func cover_transform(viewport_size: Vector2) -> Dictionary:
	var effective_size := viewport_size if viewport_size != Vector2.ZERO else REFERENCE_SIZE
	var scale_factor := maxf(
		effective_size.x / REFERENCE_SIZE.x,
		effective_size.y / REFERENCE_SIZE.y,
	)
	return {
		"offset": (effective_size - REFERENCE_SIZE * scale_factor) * 0.5,
		"scale": scale_factor,
	}


static func fit_transform(viewport_size: Vector2) -> Dictionary:
	var effective_size := viewport_size if viewport_size != Vector2.ZERO else REFERENCE_SIZE
	var scale_factor := minf(
		effective_size.x / REFERENCE_SIZE.x,
		effective_size.y / REFERENCE_SIZE.y,
	)
	return {
		"offset": (effective_size - REFERENCE_SIZE * scale_factor) * 0.5,
		"scale": scale_factor,
	}


static func to_reference(position: Vector2, transform: Dictionary) -> Vector2:
	return (position - (transform["offset"] as Vector2)) / float(transform["scale"])
