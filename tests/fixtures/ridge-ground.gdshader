shader_type spatial;
uniform sampler2D turf : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D scree : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D relief : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D marks : filter_linear, repeat_disable;
uniform vec4 contact_lines[4];
varying vec2 ground;
void vertex() {
	ground = VERTEX.xz;
}
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1,311.7))) * 4375.5453);
}
float field(vec2 p) {
	vec2 c = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(c), hash(c+vec2(1,0)), f.x),
		mix(hash(c+vec2(0,1)), hash(c+vec2(1,1)), f.x), f.y);
}
void fragment() {
	mat2 turn = mat2(vec2(0.60,0.80), vec2(-0.80,0.60));
	vec2 warp = vec2(field(ground*0.035),field(ground*0.042+13.8));
	vec2 uv = ground * 0.21 + warp * 1.1;
	vec2 rotated = turn * ground * 0.165 - warp * 0.65;
	float patch = smoothstep(0.18, 0.82, field(ground * 0.13));
	vec3 soil = mix(texture(turf,uv).rgb, texture(turf,rotated).rgb, patch);
	float stone = smoothstep(0.46,0.83,warp.x*0.65 + field(ground*0.26)*0.35);
	soil = mix(soil, texture(scree,rotated*0.74).rgb * vec3(0.89,0.86,0.76), stone*0.69);
	soil *= mix(vec3(0.70,0.76,0.72), vec3(1.22,1.12,0.98), warp.y);
	vec2 mask_uv = UV2;
	float ruts = texture(marks,mask_uv).r;
	vec2 texel = 1.0 / vec2(textureSize(marks,0));
	vec2 shoulder = vec2(texture(marks,mask_uv+vec2(texel.x,0)).r-texture(marks,mask_uv-vec2(texel.x,0)).r,
		texture(marks,mask_uv+vec2(0,texel.y)).r-texture(marks,mask_uv-vec2(0,texel.y)).r);
	float impression = ruts * mix(0.88, 0.25, stone) * mix(0.55, 1.0, patch);
	float earth = dot(soil, vec3(0.30, 0.59, 0.11));
	ALBEDO = mix(soil, earth * vec3(0.64,0.44,0.29), impression);
	vec3 normal = texture(relief,uv).rgb*2.0-1.0;
	normal.xy = normal.xy * (1.0 - 0.35 * impression) + shoulder * vec2(0.16,-0.16) * (1.0 - stone);
	NORMAL_MAP = normalize(normal)*0.5+0.5;
	NORMAL_MAP_DEPTH = 0.72;
	// Wheel load blocks the sky beside the planted shoes. The raised
	// idler and sprocket leave the soil lighter at either end.
	float shade = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 front = contact_lines[i].xy;
		vec2 line = contact_lines[i].zw - front;
		float t = clamp(dot(ground - front, line) / max(dot(line, line), 0.01), 0.0, 1.0);
		float d = distance(ground, front + t * line);
		shade = max(shade, 1.0 - smoothstep(0.19, 0.65, d));
	}
	AO = 1.0 - 0.85 * shade;
	AO_LIGHT_AFFECT = 0.22;
	ROUGHNESS = 0.94;
}
