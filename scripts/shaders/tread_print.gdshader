shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never;

void fragment() {
	vec2 uv = abs(UV - 0.5);
	float pad = smoothstep(0.02, 0.085, uv.x) * (1.0 - smoothstep(0.40, 0.49, uv.x));
	float edge = abs(UV.y - 0.5 + (uv.x - 0.23) * 0.18);
	ALBEDO = vec3(0.025, 0.021, 0.015);
	ALPHA = pad * (1.0 - smoothstep(0.25, 0.49, edge)) * 0.34;
}
