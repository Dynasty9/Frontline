shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// RGB stores lighting from camera right/up/front and left/down/back.
// Both elevation views share each atlas; coefficients are premultiplied by opacity.
uniform sampler2D positive_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D negative_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D motion_map : filter_linear_mipmap, repeat_disable;
uniform sampler2D bounds_map : filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float age = 0.0;
uniform float duration = 5.0;
uniform float span = 18.0;
uniform float center_height = 2.7;
uniform float mirror = 1.0;
uniform float opacity = 1.0;
uniform float fuel = 0.0;
uniform float ground_dust = 0.0;
uniform bool interpolate = true;
uniform bool motion_enabled = false;
uniform vec3 tint : source_color = vec3(0.46, 0.40, 0.32);
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_energy = 1.5;
uniform vec3 amb_col : source_color = vec3(0.5, 0.55, 0.62);
uniform float amb_energy = 0.6;
uniform vec3 wind = vec3(0.6, 0.0, 0.25);
varying vec3 light_local;
varying vec3 sky_positive;
varying vec3 sky_negative;
varying float elevation;
varying float world_scale;
varying vec4 animation; // frame, late fade, earth shade, earth density

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define NDC_Z(d) ((d) * 2.0 - 1.0)
#else
#define NDC_Z(d) (d)
#endif

vec4 frame_bounds(float frame, float view) {
	vec4 a = textureLod(bounds_map, vec2((frame + view * 64.0 + 0.5) / 128.0, 0.5), 0.0);
	vec4 b = textureLod(bounds_map, vec2((min(frame + 1.0, 63.0) + view * 64.0 + 0.5) / 128.0, 0.5), 0.0);
	return vec4(min(a.xy, b.xy), max(a.zw, b.zw));
}

void vertex() {
	world_scale = length(MODEL_MATRIX[0].xyz);
	elevation = smoothstep(0.574, 0.906, abs(INV_VIEW_MATRIX[2].y));
	float progress = clamp(age / duration, 0.0, 1.0);
	animation = vec4(pow(progress, 0.6666667) * 63.0,
		1.0 - smoothstep(0.84, 1.0, progress),
		1.0 - ground_dust * 0.55 * exp(-age * 4.0),
		1.0 + ground_dust * 1.5 * exp(-age * 2.8));
	float frame = floor(animation.x);
	vec4 bounds = frame_bounds(frame, step(0.5, elevation));
	if (elevation > 0.0 && elevation < 1.0) {
		vec4 other = frame_bounds(frame, 1.0 - step(0.5, elevation));
		bounds = vec4(min(bounds.xy, other.xy), max(bounds.zw, other.zw));
	}
	// Trim empty pixels before rasterization. Adjacent frame bounds plus a
	// reconstruction margin retain wisps while avoiding a full empty square.
	bounds = clamp(bounds + vec4(-0.02, -0.02, 0.02, 0.02), vec4(0.0), vec4(1.0));
	if (mirror < 0.0) bounds.xz = vec2(1.0 - bounds.z, 1.0 - bounds.x);
	UV = mix(bounds.xy, bounds.zw, UV);
	VERTEX.xy = vec2(UV.x - 0.5, 0.5 - UV.y);
	vec3 center = MODEL_MATRIX[3].xyz + vec3(0.0, center_height * world_scale, 0.0);
	center += wind * age * (0.10 + fuel * 0.12);
	mat4 billboard = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(center, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
	VERTEX *= span * world_scale;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	light_local = normalize((VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz);
	light_local.x *= mirror;
	vec3 sky_local = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	sky_local.x *= mirror;
	// Sky and ground stay in world space. Their weights are constant across
	// the billboard, so resolve them here instead of at every smoke pixel.
	vec3 sky_weights = sky_local * sky_local;
	vec3 sky_sign = step(vec3(0.0), sky_local);
	vec3 horizon = (vec3(1.0) - sky_weights) * 0.09;
	sky_positive = (vec3(0.25) + sky_sign * 0.75) * sky_weights + horizon;
	sky_negative = (vec3(1.0) - sky_sign * 0.75) * sky_weights + horizon;
}

vec2 cell_uv(vec2 uv, float frame, float view) {
	vec2 cell = vec2(mod(frame, 8.0) + view * 8.0, floor(frame / 8.0));
	// Stay inside each tile even at the edge of a small mip level.
	return (cell + clamp(uv, vec2(0.008), vec2(0.992))) / vec2(16.0, 8.0);
}

void sample_frame(vec2 uv, float frame, float view, float blend, out vec4 positive, out vec4 negative) {
	vec2 uv0 = cell_uv(uv, frame, view);
	vec2 uv1 = cell_uv(uv, min(frame + 1.0, 63.0), view);
	if (motion_enabled && interpolate) {
		vec4 flow = texture(motion_map, uv0);
		// Forward and backward displacements are measured in tile UVs.
		uv0 = cell_uv(uv - (flow.rg * 2.0 - 1.0) * 0.125 * blend, frame, view);
		uv1 = cell_uv(uv - (flow.ba * 2.0 - 1.0) * 0.125 * (1.0 - blend), min(frame + 1.0, 63.0), view);
	}
	positive = texture(positive_map, uv0);
	negative = texture(negative_map, uv0);
	if (interpolate) {
		positive = mix(positive, texture(positive_map, uv1), blend);
		negative = mix(negative, texture(negative_map, uv1), blend);
	}
}

void fragment() {
	float frame = animation.x;
	vec2 uv = vec2(mirror < 0.0 ? 1.0 - UV.x : UV.x, UV.y);
	vec4 p; vec4 n;
	// Outside the transition, fetch only the view the camera can see. Every
	// fragment of this surface takes the same branch, including on WebGL.
	if (elevation <= 0.0 || elevation >= 1.0) {
		sample_frame(uv, floor(frame), step(0.5, elevation), fract(frame), p, n);
	} else {
		vec4 p1; vec4 n1;
		sample_frame(uv, floor(frame), 0.0, fract(frame), p, n);
		sample_frame(uv, floor(frame), 1.0, fract(frame), p1, n1);
		p = mix(p, p1, elevation);
		n = mix(n, n1, elevation);
	}
	float alpha = p.a;
	if (alpha < 0.003) discard;
	vec3 weights = light_local * light_local;
	vec3 lobes = mix(n.rgb, p.rgb, step(vec3(0.0), light_local));
	float sunlight = dot(lobes, weights) / max(alpha, 0.003);
	float sky = (dot(p.rgb, sky_positive) + dot(n.rgb, sky_negative)) / max(alpha, 0.003);
	vec3 color = tint * (sun_col * sun_energy * sunlight + amb_col * amb_energy * (0.16 + sky * 0.55));
	color *= animation.z;
	if (fuel > 0.0) {
		float heat = clamp(n.a / max(alpha, 0.003), 0.0, 1.0) * fuel;
		vec3 fire_color = mix(vec3(0.55, 0.045, 0.004), vec3(1.0, 0.3, 0.025), smoothstep(0.02, 0.35, heat));
		fire_color = mix(fire_color, vec3(1.0, 0.82, 0.42), smoothstep(0.35, 0.95, heat));
		color = mix(color, fire_color * (1.0 + 3.0 * heat), smoothstep(0.01, 0.2, heat));
	}
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, NDC_Z(depth), 1.0);
	// Approximate cloud thickness so a tilted billboard doesn't slice its own
	// ground skirt in half. Opaque scenery still occludes the near surface.
	float thickness = world_scale * (0.4 + 1.4 * sqrt(alpha));
	float contact = clamp((-scene.z / scene.w + VERTEX.z + thickness) / max(world_scale * 0.45, 0.15), 0.0, 1.0);
	ALBEDO = color;
	float dense_alpha = 1.0 - pow(max(1.0 - alpha, 0.0), animation.w);
	ALPHA = dense_alpha * opacity * contact * animation.y;
}
