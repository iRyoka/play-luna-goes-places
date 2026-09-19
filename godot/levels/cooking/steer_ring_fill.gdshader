shader_type canvas_item;
render_mode unshaded;

uniform float sweep_start = -1.5708;
uniform float sweep_amount = 0.0;
uniform float sweep_direction = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	vec2 centered_uv = UV - vec2(0.5);
	float angle = atan(centered_uv.y, centered_uv.x);
	float relative_angle = mod(angle - sweep_start + TAU, TAU);
	if (sweep_direction < 0.0) {
		relative_angle = mod(sweep_start - angle + TAU, TAU);
	}
	if (relative_angle > sweep_amount) {
		color.a = 0.0;
	}
	COLOR = color;
}
