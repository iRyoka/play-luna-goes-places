shader_type canvas_item;

uniform sampler2D id_map : filter_nearest, repeat_disable;
uniform sampler2D reward_palette : source_color, filter_nearest, repeat_disable;
uniform vec4 empty_color : source_color = vec4(0.42, 0.48, 0.46, 0.52);

const float CANONICAL_HUE = 0.029;
const float CANONICAL_SATURATION = 0.607;
const float CANONICAL_VALUE = 0.937;

vec3 rgb_to_hsv(vec3 color) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(color.bg, k.wz), vec4(color.gb, k.xy), step(color.b, color.g));
	vec4 q = mix(vec4(p.xyw, color.r), vec4(color.r, p.yzx), step(p.x, color.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 color) {
	vec3 p = abs(fract(color.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return color.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), color.y);
}

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float piece_id = floor(texture(id_map, UV).a * 255.0 + 0.5);
	if (piece_id < 0.5 || art.a < 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec4 reward = texture(reward_palette, vec2((piece_id + 0.5) / 256.0, 0.5));
		vec3 art_hsv = rgb_to_hsv(art.rgb);
		if (reward.a < 0.5) {
			float shading = mix(0.72, 1.16, art_hsv.z);
			COLOR = vec4(empty_color.rgb * shading, art.a * empty_color.a);
		} else {
			vec3 target_hsv = rgb_to_hsv(reward.rgb);
			float hue_detail = mod(art_hsv.x - CANONICAL_HUE + 0.5, 1.0) - 0.5;
			art_hsv.x = mod(target_hsv.x + clamp(hue_detail, -0.04, 0.04) * 0.5, 1.0);
			art_hsv.y = clamp(art_hsv.y * target_hsv.y / CANONICAL_SATURATION, 0.0, 1.0);
			art_hsv.z = clamp(art_hsv.z * target_hsv.z / CANONICAL_VALUE, 0.0, 1.0);
			COLOR = vec4(hsv_to_rgb(art_hsv), art.a);
		}
	}
}
