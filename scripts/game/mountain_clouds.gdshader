shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform int steps = 20;
uniform bool detail = true;
uniform bool still = false;
uniform float coverage = 0.57;
uniform vec3 lit_color : source_color;
uniform vec3 shade_color : source_color;
uniform vec3 sun_direction;
varying vec3 local_position;
varying vec3 local_camera;
varying vec3 offset;
varying vec3 light_direction;

void vertex() {
	local_position = VERTEX;
	local_camera = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	offset = MODEL_MATRIX[3].xyz * 0.001;
	light_direction = normalize((inverse(MODEL_MATRIX) * vec4(sun_direction, 0.0)).xyz);
}

float density(vec3 p) {
	vec3 q = p * vec3(0.65, 0.45, 0.5) + offset;
	q.x += still ? 0.0 : TIME * 0.003;
	float n = textureLod(noise_tex, q.xz + q.y * vec2(0.17, 0.31), 0.0).r;
	n = n * 0.7 + textureLod(noise_tex, q.xy * 0.73, 0.0).r * 0.3;
	if (detail) {
		n += (textureLod(noise_tex, q.xz * 3.1 + q.y * 0.2, 0.0).r - 0.5) * 0.12;
	}
	float edge = 1.0 - smoothstep(0.45, 1.0, length(p.xz * 2.0));
	float vertical = smoothstep(-0.49, -0.18, p.y) * (1.0 - smoothstep(-0.05, 0.18 + n * 0.3, p.y));
	return smoothstep(coverage - 0.15, coverage + 0.12, n) * edge * vertical;
}

void fragment() {
	// shortcut: no depth termination inside a bank; add it before allowing clouds over playable terrain.
	vec3 ray = normalize(local_position - local_camera);
	vec3 safe_ray = mix(vec3(-1.0), vec3(1.0), greaterThanEqual(ray, vec3(0.0))) * max(abs(ray), vec3(0.00001));
	vec3 distances = (mix(vec3(-0.5), vec3(0.5), greaterThanEqual(ray, vec3(0.0))) - local_position) / safe_ray;
	float length_inside = max(0.0, min(distances.x, min(distances.y, distances.z)));
	float stride = length_inside / float(steps);
	vec3 accumulated = vec3(0.0);
	float opacity = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= steps || opacity > 0.98) { break; }
		vec3 p = local_position + ray * (float(i) + 0.5) * stride;
		float d = density(p);
		float a = 1.0 - exp(-d * stride * 9.0);
		float light = exp(-density(p + light_direction * 0.15) * 2.5);
		vec3 color = mix(shade_color, lit_color, light);
		accumulated += (1.0 - opacity) * a * color;
		opacity += (1.0 - opacity) * a;
	}
	ALBEDO = accumulated / max(opacity, 0.0001);
	ALPHA = opacity;
}
