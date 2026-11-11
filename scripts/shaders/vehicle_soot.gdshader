shader_type spatial;
render_mode depth_draw_never;
uniform vec3 source_world;
uniform float extent;
varying vec3 p;
void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 d = p - source_world;
	float grain = sin(p.x * 14.1 + p.y * 12.7) * sin(p.z * 11.7 - p.x * 3.8);
	float border = length(d * vec3(1.0,0.74,1.0)) + grain * 0.085;
	float deposit = 1.0 - smoothstep(extent * 0.32, extent, border);
	if (deposit < 0.015) { discard; }
	ALBEDO = vec3(0.023,0.020,0.017) * (1.0 + grain * 0.24);
	ALPHA = deposit * 0.91;
	ROUGHNESS = 0.97;
}
