shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, shadows_disabled;

uniform sampler3D noise_tex : repeat_enable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
uniform vec3 sun_col : source_color = vec3(1.0);
uniform vec3 amb_col : source_color = vec3(0.6);
uniform float sun_energy = 1.0;
uniform float amb_energy = 0.6;
varying vec3 exit_view;
varying mat4 to_local;
varying vec3 phase;
varying vec3 to_sun;

void vertex() {
	exit_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	to_local = inverse(MODELVIEW_MATRIX);
	// Position varies smoothly during growth. Keep the rolls stable as the bounds expand.
	vec2 origin = MODEL_MATRIX[3].xz;
	phase = 0.5 + 0.5 * sin(vec3(dot(origin, vec2(0.31, 0.27)),
		dot(origin, vec2(-0.17, 0.38)), dot(origin, vec2(0.24, -0.21))));
	to_sun = normalize((inverse(MODEL_MATRIX) * vec4(sun_dir, 0.0)).xyz);
}

float density(vec3 p) {
	// A narrow outlet feeds a widening plume. Each fold carries its shape downwind
	// from the outlet, so the sides of the plume travel as well as its texture.
	vec2 wind = vec2(0.924, 0.383);
	vec2 relative = p.xz + wind * 0.19;
	float along = dot(relative, wind);
	float across = dot(relative, vec2(-wind.y, wind.x));
	float travel = smoothstep(-0.05, 0.60, along);
	float wave = along * mix(16.0, 21.0, phase.y) - TIME * (0.95 + 0.16 * phase.x) + phase.x * 6.28;
	float roll = sin(wave) + 0.38 * sin(2.1 * wave + phase.z * 5.0);
	float width = mix(0.074, 0.27, sqrt(travel)) * (1.0 + 0.26 * roll);
	float crosswind = across - travel * (0.07 * roll + (phase.y - 0.5) * 0.20);
	float lift = smoothstep(-0.03, 0.16, along) * mix(0.08, 0.17, phase.z);
	float height = p.y + 0.32 - lift - travel * (0.11 + 0.14 * roll);
	float core = 1.0 - length(vec2(crosswind / width, height / (0.105 + 0.19 * travel)));
	vec3 flow = vec3(along - TIME * 0.07, height * 0.86, crosswind) + phase;
	float eddy = textureLod(noise_tex, flow * 1.3, 0.0).r - 0.5;
	float fray = textureLod(noise_tex, flow * 3.7 + vec3(eddy * 0.4, -TIME * 0.023, 0.0), 0.0).r - 0.5;
	float envelope = smoothstep(-0.085, 0.0, along) * (1.0 - smoothstep(0.34, 0.68, along));
	// Between successive rolls, gaps open first at the feathered end.
	float pockets = mix(1.0, smoothstep(-0.23, 0.19, eddy + 0.22 * roll), 0.82 * sqrt(travel));
	float boundary = max(abs(p.x), max(abs(p.y), abs(p.z)));
	float wisps = smoothstep(-0.32, 0.65, core + eddy * 1.65 + fray * 0.49);
	return wisps * pockets * envelope * mix(1.0, 0.48, travel) * (1.0 - smoothstep(0.42, 0.5, boundary));
}

void fragment() {
	// Trace from the box entry (or camera) to the first opaque surface or box exit.
	vec3 view_ray = PROJECTION_MATRIX[3][3] == 0.0 ? normalize(exit_view) : vec3(0.0, 0.0, -1.0);
	vec3 ray = (to_local * vec4(view_ray, 0.0)).xyz;
	vec3 end = (to_local * vec4(exit_view, 1.0)).xyz;
	vec3 denom = mix(vec3(-1.0), vec3(1.0), greaterThanEqual(ray, vec3(0.0))) * max(abs(ray), vec3(0.00001));
	vec3 spans = (end - mix(vec3(0.5), vec3(-0.5), greaterThanEqual(ray, vec3(0.0)))) / denom;
	float back = min(min(spans.x, min(spans.y, spans.z)), exit_view.z / view_ray.z);
	float z = textureLod(scene_depth, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	z = z * 2.0 - 1.0;
#endif
	vec4 surface = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	float clipped = abs(surface.w) > 0.00001 ? max(0.0, (exit_view.z - surface.z / surface.w) / view_ray.z) : 0.0;
	if (clipped >= back) discard;
	float stride = (back - clipped) / 18.0;
	vec3 p = end - ray * (back - 0.5 * stride);
	float opacity = 0.0;
	vec3 color = vec3(0.0);
	for (int i = 0; i < 18; i++) {
		float d = density(p);
		if (d > 0.01) {
			float a = (1.0 - opacity) * (1.0 - exp(-d * stride * 0.42));
			float shelter = density(p + to_sun * 0.11);
			vec3 light = amb_col * amb_energy * 0.68 + sun_col * sun_energy * mix(0.72, 0.17, shelter);
			color += a * vec3(0.50, 0.51, 0.51) * light;
			opacity += a;
			if (opacity > 0.985) break;
		}
		p += ray * stride;
	}
	ALBEDO = color / max(opacity, 0.0001);
	ALPHA = opacity;
}
