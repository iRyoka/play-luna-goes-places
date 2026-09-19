shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.0, 0.01) = 0.9;


void fragment() {
	vec4 sampled = texture(TEXTURE, UV) * COLOR;
	float luminance = dot(sampled.rgb, vec3(0.299, 0.587, 0.114));
	sampled.rgb = mix(vec3(luminance), sampled.rgb, saturation);
	COLOR = sampled;
}
