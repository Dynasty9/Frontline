shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;

uniform sampler2D frame_a : filter_linear, repeat_disable;
uniform sampler2D frame_b : filter_linear, repeat_disable;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 corner;
uniform vec3 extent;
uniform float phase;
uniform float heat;
varying vec3 surface;

void vertex() {
	surface = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 slice_uv(float slice, vec2 xy) {
	vec2 tile = vec2(mod(slice, 8.0), floor(slice / 8.0));
	return (tile + (xy * vec2(79.0,33.0) + 0.5) / vec2(80.0,34.0)) / vec2(8.0,9.0);
}

vec3 voxel(vec3 uvw) {
	float z = clamp(uvw.y,0.0,1.0) * 67.0;
	vec2 xy = clamp(vec2(uvw.x,1.0-uvw.z),vec2(0.0),vec2(1.0));
	vec2 a = slice_uv(floor(z),xy);
	vec2 b = slice_uv(min(floor(z)+1.0,67.0),xy);
	vec3 one = mix(texture(frame_a,a).rgb,texture(frame_a,b).rgb,fract(z));
	vec3 two = mix(texture(frame_b,a).rgb,texture(frame_b,b).rgb,fract(z));
	return mix(one,two,phase);
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 ray = normalize(surface-eye);
	vec3 inv = 1.0 / (ray + vec3(1e-8));
	vec3 a = (corner-eye)*inv, b = (corner+extent-eye)*inv;
	vec3 near_box = min(a,b), far_box = max(a,b);
	float entry = max(0.0,max(max(near_box.x,near_box.y),near_box.z));
	float exit_t = min(min(far_box.x,far_box.y),far_box.z);
	float depth = texture(scene_depth,SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV*2.0-1.0,mix(CLIP_SPACE_FAR,1.0,depth));
	vec4 view = INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	float opaque = length(view.xyz/view.w);
	exit_t = min(exit_t,opaque);
	if (entry >= exit_t) { discard; }
	float step_length = (exit_t-entry)/64.0;
	vec3 radiance = vec3(0.0);
	float transmission = 1.0;
	for (int i=0; i<64; i++) {
		vec3 p = eye + ray * (entry+(float(i)+0.5)*step_length);
		vec3 uvw = (p-corner)/extent;
		// Wind leans the high billows while the foot stays on the wreck.
		uvw.xz -= vec2(0.095, -0.065) * uvw.y * uvw.y;
		if (any(lessThan(uvw, vec3(0.0))) || any(greaterThan(uvw, vec3(1.0)))) { continue; }
		vec3 v = voxel(uvw);
		vec3 margin = min(uvw, vec3(1.0) - uvw);
		float boundary = smoothstep(0.0, 0.033, min(margin.x, min(margin.y, margin.z)));
		float density = v.r*v.r * boundary;
		float flame = heat*v.g*v.g * boundary;
		float absorb = 1.0-exp(-(density*2.55+flame*1.7)*step_length);
		// The blue channel stores sunlight transmission through the bake.
		// Thin edges catch the low sun; dense folds retain cool skylight.
		vec3 scattered = mix(vec3(0.053,0.061,0.071), vec3(0.46,0.39,0.31), v.b);
		scattered += vec3(0.30,0.085,0.018) * heat * (0.18 + v.g) * exp(-uvw.y * 12.0);
		vec3 glow = vec3(6.1,1.75,0.15)*flame*flame + vec3(2.0,0.15,0.006)*flame;
		glow += vec3(3.5,2.2,0.6)*pow(flame,4.0);
		radiance += transmission*absorb*(scattered+glow);
		transmission *= 1.0-absorb;
		if (transmission < 0.008) { break; }
	}
	ALPHA = 1.0-transmission;
	vec3 color = radiance / max(ALPHA,0.00001);
	if (OUTPUT_IS_SRGB) {
		color = mix(12.92*color, 1.055*pow(color,vec3(1.0/2.4))-0.055, step(vec3(0.00313),color));
	}
	ALBEDO = color;
}
