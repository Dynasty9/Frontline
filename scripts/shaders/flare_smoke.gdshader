shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D positive_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D negative_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D motion_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D bounds_map : filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_energy = 1.5;
uniform vec3 amb_col : source_color = vec3(0.5, 0.55, 0.62);
uniform float amb_energy = 0.6;
instance uniform vec3 local_light = vec3(3.0, 2.8, 2.3);
instance uniform float smoke_density = 1.0;
instance uniform float grille_heat = 0.0;
varying float age;
varying float animation_frame;
varying float soft_depth;
varying vec3 light_local;
varying vec3 sky_positive;
varying vec3 sky_negative;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define NDC_Z(d) ((d) * 2.0 - 1.0)
#else
#define NDC_Z(d) (d)
#endif

void vertex() {
	age = INSTANCE_CUSTOM.y;
	float start = mix(19.0, 11.5, smoothstep(0.0, 0.25, grille_heat));
	animation_frame = mix(start, 49.0, age) + 5.0 * fract(float(INSTANCE_ID) * 0.618034);
	vec4 a = textureLod(bounds_map, vec2((floor(animation_frame) + 0.5) / 128.0, 0.5), 0.0);
	vec4 b = textureLod(bounds_map, vec2((floor(animation_frame) + 1.5) / 128.0, 0.5), 0.0);
	vec4 bounds = clamp(vec4(min(a.xy, b.xy) - 0.01, max(a.zw, b.zw) + 0.01), vec4(0.0), vec4(1.0));
	UV = mix(bounds.xy, bounds.zw, UV);
	// The baked cloud rises within its tile. Keep it centred on the
	// simulated particle so that the two motions do not add together.
	vec2 centre = (bounds.xy + bounds.zw) * 0.5;
	VERTEX.xy = (UV - centre) * vec2(1.0, -1.0);
	float angle = INSTANCE_CUSTOM.x;
	float c = cos(angle); float s = sin(angle);
	mat4 billboard = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mat4 turn = mat4(vec4(c, -s, 0.0, 0.0), vec4(s, c, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard * turn;
	float width = length(MODEL_MATRIX[0].xyz);
	VERTEX *= width;
	soft_depth = clamp(width * 0.16, 0.035, 0.42);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	vec3 sun = normalize((VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz);
	light_local = vec3(c * sun.x - s * sun.y, s * sun.x + c * sun.y, sun.z);
	vec3 sky = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 sky_local = vec3(c * sky.x - s * sky.y, s * sky.x + c * sky.y, sky.z);
	vec3 sky_weights = sky_local * sky_local;
	vec3 sky_sign = step(vec3(0.0), sky_local);
	sky_positive = (vec3(0.25) + sky_sign * 0.75) * sky_weights;
	sky_negative = (vec3(1.0) - sky_sign * 0.75) * sky_weights;
}

vec2 cell_uv(vec2 uv, float frame) {
	return (vec2(mod(frame, 8.0), floor(frame / 8.0)) + clamp(uv, vec2(0.008), vec2(0.992))) / vec2(16.0, 8.0);
}

void fragment() {
	// Density and emission follow the same optical flow between frames.
	float frame = animation_frame;
	vec2 uv0 = cell_uv(UV, floor(frame));
	vec2 uv1 = cell_uv(UV, floor(frame) + 1.0);
	// Match the moving density between successive frames for close observers.
	if (-VERTEX.z < 48.0) {
		vec4 flow = texture(motion_map, uv0) * 2.0 - 1.0;
		uv0 = cell_uv(UV - flow.rg * 0.125 * fract(frame), floor(frame));
		uv1 = cell_uv(UV - flow.ba * 0.125 * (1.0 - fract(frame)), floor(frame) + 1.0);
	}
	vec4 p = mix(texture(positive_map, uv0), texture(positive_map, uv1), fract(frame));
	if (p.a < 0.003) discard;
	vec4 n = mix(texture(negative_map, uv0), texture(negative_map, uv1), fract(frame));
	float lit = dot(mix(n.rgb, p.rgb, step(vec3(0.0), light_local)), light_local * light_local) / max(p.a, 0.003);
	float sky = (dot(p.rgb, sky_positive) + dot(n.rgb, sky_negative)) / max(p.a, 0.003);
	vec3 color = COLOR.rgb * (sun_col * sun_energy * lit + amb_col * amb_energy * (0.2 + sky * 0.6));
	color += COLOR.rgb * local_light * pow(1.0 - age, 4.0);
	// In the fuel bake, negative alpha carries emission integrated through
	// the same soot. Keep the glow near the opening as each eddy rises.
	if (grille_heat > 0.0) {
		float heat = n.a / max(p.a, 0.02) * smoothstep(0.0, 0.48, grille_heat)
			* (1.0 - smoothstep(0.075, 0.30, age));
		vec3 glow = mix(vec3(1.10, 0.14, 0.012), vec3(3.1, 1.12, 0.18), smoothstep(0.16, 0.52, heat));
		color = mix(color, glow, smoothstep(0.045, 0.28, heat));
	}
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, NDC_Z(texture(depth_tex, SCREEN_UV).r), 1.0);
	float fade = smoothstep(0.0, soft_depth, -scene.z / scene.w + VERTEX.z);
	ALBEDO = color;
	ALPHA = p.a * COLOR.a * fade * smoke_density;
}
