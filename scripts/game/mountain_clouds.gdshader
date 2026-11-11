shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

uniform sampler3D noise_tex : repeat_enable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
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
varying vec3 wind_direction;
varying mat4 view_to_local;

void vertex() {
	local_position = VERTEX;
	local_camera = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	offset = MODEL_MATRIX[3].xyz * 0.001;
	light_direction = normalize((inverse(MODEL_MATRIX) * vec4(sun_direction, 0.0)).xyz);
	wind_direction = (inverse(MODEL_MATRIX) * vec4(0.7, 0.0, 0.3, 0.0)).xyz;
	view_to_local = inverse(MODELVIEW_MATRIX);
}

float density(vec3 p) {
	vec3 q = p * vec3(1.2, 0.9, 1.0) + offset;
	q += wind_direction * (still ? 0.0 : TIME * 1.5);
	float n = textureLod(noise_tex, q, 0.0).r;
	if (detail) {
		n += (textureLod(noise_tex, q * 3.1, 0.0).r - 0.5) * 0.12;
	}
	float body = 1.0 - length(p * vec3(2.0, 2.15, 2.0));
	float edge = 1.0 - smoothstep(0.43, 0.5, max(abs(p.x), max(abs(p.y), abs(p.z))));
	float base = smoothstep(-0.45, -0.22, p.y);
	float billows = smoothstep(0.0, 0.16, body * 0.65 + n * 0.65 - coverage) * base;
	// A thin, broken condensation shelf trails below the main bank along the ridge.
	float shelf = exp(-pow((p.y + 0.27) * 12.0, 2.0)) * (1.0 - smoothstep(0.22, 0.49, length(p.xz)));
	shelf *= smoothstep(0.3, 0.65, n) * 0.16;
	return max(billows, shelf) * edge;
}

void fragment() {
	vec3 ray = normalize(local_position - local_camera);
	vec3 safe_ray = mix(vec3(-1.0), vec3(1.0), greaterThanEqual(ray, vec3(0.0))) * max(abs(ray), vec3(0.00001));
	vec3 distances = (mix(vec3(-0.5), vec3(0.5), greaterThanEqual(ray, vec3(0.0))) - local_position) / safe_ray;
	float length_inside = max(0.0, min(distances.x, min(distances.y, distances.z)));
	// Stop at the mountain surface, including peaks enclosed by a cloud volume.
	float depth = textureLod(scene_depth, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 surface = view_to_local * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	if (abs(surface.w) > 0.00001) {
		length_inside = min(length_inside, max(0.0, dot(surface.xyz / surface.w - local_position, ray)));
	}
	float stride = length_inside / float(steps);
	vec3 accumulated = vec3(0.0);
	float opacity = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= steps || opacity > 0.98) { break; }
		vec3 p = local_position + ray * (float(i) + 0.5) * stride;
		float d = density(p);
		float a = 1.0 - exp(-d * stride * 12.0);
		float shelter = density(p + light_direction * 0.12);
		if (detail) { shelter += density(p + light_direction * 0.28) * 0.5; }
		float light = 0.2 + 0.8 * exp(-shelter * 1.8);
		vec3 color = mix(shade_color, lit_color, light);
		accumulated += (1.0 - opacity) * a * color;
		opacity += (1.0 - opacity) * a;
	}
	ALBEDO = accumulated / max(opacity, 0.0001);
	ALPHA = opacity;
}
