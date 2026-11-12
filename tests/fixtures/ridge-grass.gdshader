shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D marks : filter_linear, repeat_disable;
uniform vec2 mark_span;
uniform float mark_gap;
varying float straw;
void vertex() {
	straw = INSTANCE_CUSTOM.g;
	vec2 foot = MODEL_MATRIX[3].xz;
	foot.x = sign(foot.x) * max(abs(foot.x) - mark_gap, 0.0);
	float pressed = textureLod(marks, foot / mark_span + 0.5, 0.0).r;
	VERTEX.z += VERTEX.y * pressed * 0.55;
	VERTEX.y *= 1.0 - pressed * 0.9;
}
void fragment() {
	vec4 blade = texture(atlas, UV);
	// Light both sides of these crossed cards like an upright clump.
	// Flipping the back normal into the soil makes half the blades black.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = blade.rgb * mix(vec3(0.83,0.91,0.78),vec3(1.17,1.12,0.91),straw);
	ALPHA = blade.a;
	ALPHA_SCISSOR_THRESHOLD = 0.27;
	ROUGHNESS = 0.98;
}
