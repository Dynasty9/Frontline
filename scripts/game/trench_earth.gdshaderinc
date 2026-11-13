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
// Horizons follow depth below the local surface, not sea level or excavation progress.
float earth_horizon(vec3 p, float depth) {
	float broad = earth_noise(p.xz * 0.22 + vec2(2.8, 9.1));
	float broken = earth_noise(p.xz * 3.8 + depth * 0.45);
	float topsoil = 0.18 + broad * 0.22 + (broken - 0.5) * 0.08;
	return smoothstep(topsoil - 0.045, topsoil + 0.075, depth);
}
void earth_material(vec2 uv, vec3 p, float depth, float wet, out vec3 color, out vec4 surface) {
	vec3 soil = earth_color(uv, 10.0);
	vec3 gravel = earth_color(uv * 0.65 + vec2(0.37, 0.61), 5.0);
	float patch = earth_noise(p.xz * 0.31 + vec2(2.8, 9.1));
	float mineral = earth_horizon(p, depth);
	float pockets = smoothstep(0.38, 0.7, earth_noise(p.xz * 0.65 + depth * 0.15));
	float stones = mineral * smoothstep(0.38, 0.95, depth) * pockets * 0.72;
	float luma = dot(soil, vec3(0.299, 0.587, 0.114));
	vec3 topsoil = mix(vec3(luma), soil, 0.65) * vec3(0.36, 0.32, 0.27);
	vec3 subsoil = mix(vec3(luma), soil, 0.35) * mix(vec3(1.18, 0.87, 0.56), vec3(0.89, 0.81, 0.67), patch);
	float lens_depth = 0.45 + patch * 0.2;
	float lens = (1.0 - smoothstep(0.025, 0.09, abs(depth - lens_depth))) * smoothstep(0.35, 0.65, patch);
	subsoil = mix(subsoil, vec3(luma) * vec3(1.25, 1.16, 0.96), lens * 0.65);
	color = mix(mix(topsoil, subsoil, mineral), gravel * vec3(0.62, 0.54, 0.43), stones) * mix(1.0, 0.45, wet);
	vec4 organic_surface = texture(earth_surfaces, vec3(uv, 10.0));
	vec4 mineral_surface = texture(earth_surfaces, vec3(uv * 0.65 + vec2(0.37, 0.61), 5.0));
	// The shore scan keeps normal Z in blue; it has no separate occlusion channel.
	mineral_surface.b = 1.0;
	surface = mix(organic_surface, mineral_surface, stones);
}
// A derivative tangent frame keeps scanned normals correctly oriented on any cut or bank.
vec3 earth_detail_normal(vec3 normal, vec3 position, vec2 uv, vec2 packed, float strength) {
	vec3 dx = dFdx(position), dy = dFdy(position);
	vec2 ux = dFdx(uv), uy = dFdy(uv);
	vec3 px = cross(dy, normal), py = cross(normal, dx);
	vec3 tangent = px * ux.x + py * uy.x;
	vec3 bitangent = px * ux.y + py * uy.y;
	float scale = inversesqrt(max(max(dot(tangent, tangent), dot(bitangent, bitangent)), 0.00000001));
	vec2 detail = (packed * 2.0 - 1.0) * strength;
	return normalize((tangent * detail.x + bitangent * detail.y) * scale + normal * sqrt(max(0.1, 1.0 - dot(detail, detail))));
}
vec3 earth_output(vec3 linear_color) {
	if (OUTPUT_IS_SRGB) return mix(linear_color * 12.92, 1.055 * pow(max(linear_color, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), linear_color));
	return linear_color;
}
