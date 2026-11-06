shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D positive_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D negative_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D bounds_map : filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_energy = 1.5;
uniform vec3 amb_col : source_color = vec3(0.5, 0.55, 0.62);
uniform float amb_energy = 0.6;
instance uniform vec3 local_light = vec3(3.0, 2.8, 2.3);
varying float age;
varying float animation_frame;
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
	animation_frame = mix(19.0, 54.0, age);
	vec4 a = textureLod(bounds_map, vec2((floor(animation_frame) + 0.5) / 128.0, 0.5), 0.0);
	vec4 b = textureLod(bounds_map, vec2((floor(animation_frame) + 1.5) / 128.0, 0.5), 0.0);
	vec4 bounds = clamp(vec4(min(a.xy, b.xy) - 0.01, max(a.zw, b.zw) + 0.01), vec4(0.0), vec4(1.0));
	UV = mix(bounds.xy, bounds.zw, UV);
	VERTEX.xy = vec2(UV.x - 0.5, 0.5 - UV.y);
	float angle = INSTANCE_CUSTOM.x;
	float c = cos(angle); float s = sin(angle);
	mat4 billboard = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mat4 turn = mat4(vec4(c, -s, 0.0, 0.0), vec4(s, c, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard * turn;
	VERTEX *= length(MODEL_MATRIX[0].xyz);
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
	// Only the cooling smoke portion is used, never the fuel emission map.
	float frame = animation_frame;
	vec2 uv0 = cell_uv(UV, floor(frame));
	vec2 uv1 = cell_uv(UV, floor(frame) + 1.0);
	vec4 p = mix(texture(positive_map, uv0), texture(positive_map, uv1), fract(frame));
	if (p.a < 0.003) discard;
	vec3 n = mix(texture(negative_map, uv0).rgb, texture(negative_map, uv1).rgb, fract(frame));
	float lit = dot(mix(n, p.rgb, step(vec3(0.0), light_local)), light_local * light_local) / max(p.a, 0.003);
	float sky = (dot(p.rgb, sky_positive) + dot(n, sky_negative)) / max(p.a, 0.003);
	vec3 color = COLOR.rgb * (sun_col * sun_energy * lit + amb_col * amb_energy * (0.2 + sky * 0.6));
	color += COLOR.rgb * local_light * pow(1.0 - age, 4.0);
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, NDC_Z(texture(depth_tex, SCREEN_UV).r), 1.0);
	float fade = clamp((-scene.z / scene.w + VERTEX.z) / 0.25, 0.0, 1.0);
	ALBEDO = color;
	ALPHA = p.a * COLOR.a * fade;
}
