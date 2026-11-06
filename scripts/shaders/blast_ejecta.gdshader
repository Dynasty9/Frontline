shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
uniform float now = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 light = vec3(0.8);
varying vec4 tint;
varying float progress;
varying float seed;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define NDC_Z(d) ((d) * 2.0 - 1.0)
#else
#define NDC_Z(d) (d)
#endif

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 velocity = MODEL_MATRIX[0].xyz;
	vec3 params = MODEL_MATRIX[1].xyz; // width, drag, ground height
	float age = now - INSTANCE_CUSTOM.x;
	float life = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.z;
	progress = clamp(age / max(life, 0.01), 0.0, 1.0);
	tint = COLOR;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 point = cam + INV_VIEW_MATRIX[2].xyz;
	if (age >= 0.0 && age < life) {
		float along = 1.0 - UV.y;
		// The dense fast head pulls ahead of finer earth, which loses speed
		// rapidly. Subdivided strips preserve the curved trajectory.
		float t = age * mix(0.18, 1.0, along);
		float drag = params.y;
		float reach = (1.0 - exp(-drag * t)) / drag;
		point = origin + velocity * reach;
		point.y -= 4.9 * t * t;
		vec3 tangent = velocity * exp(-drag * t) - vec3(0.0, 9.8 * t, 0.0);
		vec3 side = cross(tangent, point - cam);
		side = length(side) > 0.0001 ? normalize(side) : INV_VIEW_MATRIX[0].xyz;
		float width = params.x * (0.25 + age * 1.8) * mix(1.0, 0.24, along);
		point += side * ((UV.x - 0.5) * width * 2.0);
		point.y = max(point.y, params.z + 0.025);
	}
	VERTEX = (VIEW_MATRIX * vec4(point, 1.0)).xyz;
}

void fragment() {
	vec2 uv = vec2(UV.x * 1.8, UV.y * 5.0) + vec2(seed * 17.0, seed * 9.0 - progress * 0.4);
	vec3 noise = texture(noise_tex, uv).rgb;
	float edge = abs(UV.x * 2.0 - 1.0);
	float shape = 1.0 - smoothstep(0.15, 0.95, edge + (noise.g - 0.5) * 0.6);
	shape *= smoothstep(0.0, 0.08, UV.y) * smoothstep(0.0, 0.22, 1.0 - UV.y);
	float breakup = smoothstep(0.1 + progress * 0.45, 0.65, noise.r * 0.6 + noise.b * 0.4);
	shape *= mix(0.85, breakup, smoothstep(0.05, 0.65, progress));
	float opacity = shape * tint.a * smoothstep(0.0, 0.035, progress) * (1.0 - smoothstep(0.25, 1.0, progress));
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, NDC_Z(texture(depth_tex, SCREEN_UV).r), 1.0);
	opacity *= clamp((-scene.z / scene.w + VERTEX.z) / 0.15, 0.0, 1.0);
	ALBEDO = tint.rgb * light * mix(0.65, 1.15, noise.g);
	ALPHA = opacity;
}
