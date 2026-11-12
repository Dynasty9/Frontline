shader_type canvas_item;
render_mode unshaded;

// A fine etched ring breaks at the four axes, leaving the subject unobscured.
void fragment() {
	vec2 p = (UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float pixel = SCREEN_PIXEL_SIZE.y;
	float radius = length(p);
	float edge = smoothstep(0.441, 0.452, radius);
	float shade = smoothstep(0.24, 0.449, radius);
	float bevel = (1.0 - smoothstep(0.001, 0.0055, abs(radius - 0.465)))
		* (0.55 + 0.45 * dot(normalize(p + vec2(0.00001)), vec2(-0.6, -0.8)));
	float lip = 1.0 - smoothstep(0.001, 0.003, abs(length(p - vec2(0.001, 0.003)) - 0.482));
	vec3 housing = vec3(0.010, 0.012, 0.012) + bevel * 0.125 + lip * 0.024;

	vec2 q = abs(p);
	float ink = max(0.00070, pixel * 0.48);
	float ring = (1.0 - smoothstep(ink, ink + pixel, abs(radius - 0.024)))
		* smoothstep(0.004, 0.004 + pixel, min(q.x, q.y));
	float arms = (1.0 - smoothstep(ink, ink + pixel, q.y))
		* smoothstep(0.033, 0.033 + pixel, q.x) * (1.0 - smoothstep(0.245, 0.245 + pixel, q.x));
	float stem = (1.0 - smoothstep(ink, ink + pixel, q.x))
		* smoothstep(0.033, 0.033 + pixel, p.y) * (1.0 - smoothstep(0.19, 0.19 + pixel, p.y));
	float etching = max(ring, max(arms, stem));
	vec3 glass = mix(vec3(0.055, 0.085, 0.073), vec3(0.12, 0.070, 0.032), etching);
	COLOR = vec4(mix(glass, housing, edge), max(edge, max(0.16 * shade, 0.84 * etching)));
}
