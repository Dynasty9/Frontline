shader_type spatial;
render_mode world_vertex_coords;
uniform float age = 0.0;
uniform bool animated_poses = false;
uniform sampler2D poses : filter_nearest, repeat_disable;
uniform int rows;
uniform int animation_frame;
vec3 turn(vec3 v, float a) {
	float c = cos(a); float s = sin(a);
	return vec3(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}
void vertex() {
	if (animated_poses) {
		int state = int(round(COLOR.a * 255.0));
		int phase = state % 8;
		int pose = (state / 8) * 5 + (phase == 0 ? 0 : ((animation_frame + phase - 1) % 4) + 1);
		ivec2 address = ivec2(round(UV)) + ivec2(0, pose * rows * 2);
		vec3 local_vertex = texelFetch(poses, address, 0).xyz;
		vec3 local_normal = texelFetch(poses, address + ivec2(0, rows), 0).xyz;
		VERTEX = (MODEL_MATRIX * vec4(local_vertex, 1.0)).xyz;
		NORMAL = MODEL_NORMAL_MATRIX * local_normal;
	}
	float blend = 1.0 - exp(-14.0 * age);
	vec3 origin = MODEL_MATRIX[3].xyz;
	VERTEX = origin + turn(VERTEX - origin, INSTANCE_CUSTOM.w * blend) + INSTANCE_CUSTOM.xyz * blend;
	NORMAL = turn(NORMAL, INSTANCE_CUSTOM.w * blend);
}
void fragment() { ALBEDO = COLOR.rgb; ROUGHNESS = 0.9; }
