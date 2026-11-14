// A vehicle burnt out, laid over its own paint (as material_overlay): the fire
// spreads from where it took hold (source_world) as far as `extent`. Inside
// it the paint is gone: black char, steel the heat has turned a dull grey,
// broad rust where the bare metal has oxidised down the sides, soot streaks,
// and pale ash
// settled on the tops. At the edge of the fire the paint is blistered brown,
// and a few islands of it survive in the char. While it burns, embers glow
// in thin cracks near the heart of the fire (`glow`).
shader_type spatial;
render_mode depth_draw_never;
uniform vec3 source_world;
uniform float extent;
uniform float glow = 0.0;
varying vec3 p;
varying vec3 n;

void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec3 q) {
	q = fract(q * 0.3183099 + vec3(0.1, 0.17, 0.13));
	q *= 17.0;
	return fract(q.x * q.y * q.z * (q.x + q.y + q.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 x) {
	return vnoise(x) * 0.55 + vnoise(x * 2.03 + 7.1) * 0.3 + vnoise(x * 4.11 + 3.3) * 0.15;
}

void fragment() {
	float big = fbm(p * 0.55);
	float mid = fbm(p * 1.9 + 11.0);
	float fine = vnoise(p * 9.0);
	// how far the fire reached: a ragged front, not a circle
	float border = length((p - source_world) * vec3(1.0, 0.74, 1.0)) + (big - 0.5) * extent * 0.3;
	float burnt = 1.0 - smoothstep(extent * 0.8, extent * 1.05, border);
	// a few islands of paint survive in the char
	burnt *= 1.0 - smoothstep(0.74, 0.82, mid) * 0.85;
	if (burnt < 0.02) { discard; }
	float up = clamp(n.y, 0.0, 1.0);
	float side = 1.0 - abs(n.y);
	// rust and soot run down the plates: noise drawn out along the vertical
	float streak = vnoise(vec3(p.x * 3.3, p.y * 0.55, p.z * 3.3) + 3.0) * 0.7 + mid * 0.3;
	vec3 charred = vec3(0.022, 0.019, 0.017) * (0.75 + 0.5 * fine);
	vec3 scorched = vec3(0.052, 0.043, 0.036) * (0.8 + 0.4 * fine);  // bare steel the heat has dulled
	vec3 rust = mix(vec3(0.07, 0.03, 0.015), vec3(0.15, 0.066, 0.028), mid) * (0.85 + 0.3 * fine);
	vec3 ash = vec3(0.12, 0.116, 0.11) * (0.8 + 0.4 * fine);
	vec3 c = mix(charred, scorched, smoothstep(0.4, 0.68, big));
	// the sides rust where the paint burnt off them, the tops less
	float rusted = smoothstep(0.46, 0.7, big * 0.45 + mid * 0.4 + streak * 0.15) * (0.35 + 0.65 * side);
	c = mix(c, rust, rusted * smoothstep(0.35, 0.75, burnt));
	// blackest where it burnt hottest, round the heart of the fire
	c *= mix(0.5, 1.0, smoothstep(extent * 0.1, extent * 0.55, length(p - source_world) + (mid - 0.5) * extent * 0.3));
	// soot streaked down from the hatches and grilles
	c *= 1.0 - smoothstep(0.6, 0.8, streak) * side * 0.4;
	// ash settles on what faces up, in drifts
	c = mix(c, ash, smoothstep(0.6, 0.82, fine * 0.25 + mid * 0.75) * up * up * 0.7);
	// blistered, browned paint at the edge of the fire
	float edge = smoothstep(0.02, 0.3, burnt) * (1.0 - smoothstep(0.3, 0.75, burnt));
	c = mix(c, vec3(0.085, 0.055, 0.034) * (0.8 + 0.4 * fine), edge * 0.7);
	ALBEDO = c;
	ROUGHNESS = 0.93;
	SPECULAR = 0.12;
	// while it burns, embers glow in thin cracks near the heart of the fire
	float crack = 1.0 - smoothstep(0.0, 0.012, abs(vnoise(p * 5.3 + 5.0) - 0.5));
	crack *= smoothstep(0.62, 0.8, mid) * (0.25 + 0.75 * up);
	float heat = 1.0 - smoothstep(extent * 0.12, extent * 0.45, length(p - source_world));
	float flick = 0.6 + 0.4 * sin(TIME * 3.3 + p.x * 2.1 + p.z * 1.7 + mid * 8.0);
	EMISSION = vec3(1.0, 0.3, 0.04) * glow * glow * crack * heat * 3.5 * flick;
	ALPHA = clamp(burnt * 1.15, 0.0, 1.0);
}
