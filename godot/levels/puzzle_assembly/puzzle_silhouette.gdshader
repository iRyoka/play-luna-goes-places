shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.945, 0.875, 0.70, 1.0);
uniform float outline_pixels : hint_range(1.0, 12.0, 1.0) = 8.0;


void fragment() {
	float center_alpha = texture(TEXTURE, UV).a;
	vec2 offset = TEXTURE_PIXEL_SIZE * outline_pixels;
	float surrounding_alpha = max(
		max(texture(TEXTURE, UV + vec2(offset.x, 0.0)).a, texture(TEXTURE, UV - vec2(offset.x, 0.0)).a),
		max(texture(TEXTURE, UV + vec2(0.0, offset.y)).a, texture(TEXTURE, UV - vec2(0.0, offset.y)).a)
	);
	float outline_alpha = max(0.0, surrounding_alpha - center_alpha);
	// Sprite2D supplies the source texture alpha through COLOR. Do not multiply by
	// it here: the outline intentionally occupies the transparent pixels beside the
	// source artwork.
	COLOR = vec4(outline_color.rgb, outline_alpha * outline_color.a);
}
