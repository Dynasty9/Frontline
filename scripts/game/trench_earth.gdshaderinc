// The same scanned soil, turf and leaf litter as the surrounding battlefield.
uniform sampler2DArray earth_colors : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray earth_surfaces : filter_linear_mipmap_anisotropic, repeat_enable;
global uniform float rain_wet;
float earth_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float earth_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(earth_hash(i), earth_hash(i + vec2(1,0)), f.x), mix(earth_hash(i + vec2(0,1)), earth_hash(i + vec2(1,1)), f.x), f.y);
}
vec3 earth_color(vec2 uv, float layer) {
	vec3 color = texture(earth_colors, vec3(uv, layer)).rgb;
	if (OUTPUT_IS_SRGB) color = mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), color));
	return color;
}
vec3 earth_soil(vec2 uv, vec3 p, float depth, float wet) {
	vec3 soil = earth_color(uv, 8.0);
	soil = mix(vec3(dot(soil, vec3(0.299, 0.587, 0.114))), soil, 0.24);
	float patch = earth_noise(p.xz * 0.31 + vec2(2.8, 9.1));
	float stratum = smoothstep(0.26, 0.52, depth + (patch - 0.5) * 0.24);
	vec3 topsoil = soil * vec3(0.28, 0.24, 0.19);
	vec3 clay = soil * mix(vec3(0.56, 0.48, 0.38), vec3(0.38, 0.33, 0.27), patch);
	return mix(topsoil, clay, stratum) * mix(1.0, 0.48, wet);
}
vec3 earth_output(vec3 linear_color) {
	if (OUTPUT_IS_SRGB) return mix(linear_color * 12.92, 1.055 * pow(max(linear_color, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), linear_color));
	return linear_color;
}
