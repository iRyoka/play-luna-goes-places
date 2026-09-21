class_name PizzaPaintLayer
extends EllipticalPaintCoverage

## Pizza's visual layer over the shared coverage recognizer. Soup uses the same
## recognizer for herbs but draws independent flecks rather than a full texture.

var texture: Texture2D
var fill := 0.0


func _init(layer_texture: Texture2D, layer_radius: Vector2, layer_brush_radius: float) -> void:
	texture = layer_texture
	super(layer_radius, layer_brush_radius)
