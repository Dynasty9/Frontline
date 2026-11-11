shader_type spatial;
render_mode depth_prepass_alpha;

void fragment() {
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.2);
	ALBEDO = mix(vec3(0.08, 0.065, 0.04), vec3(0.36, 0.28, 0.14), rim);
	METALLIC = 0.16;
	ROUGHNESS = 0.09;
	SPECULAR = 0.65;
	ALPHA = mix(0.42, 0.88, rim);
}
