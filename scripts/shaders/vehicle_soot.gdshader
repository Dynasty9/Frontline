// A vehicle burnt out, laid over its own paint (as material_overlay): the fire
// spreads from where it took hold (source_world) as far as `extent`. Inside
// it the paint is gone: mostly black char and heat-dulled steel; round the
// heart of the fire, where it burnt hottest, the paint has burnt to a pale
// grey film in ragged sheets; bare steel rusting in streaks down the sides;
// soot run down from the hatches and grilles; ash drifted on the tops. At the
// edge of the fire the paint is blistered brown, and a few islands of it
// survive in the char. While it burns, embers glow in thin cracks near the
// heart of the fire (`glow`).
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
	// warped, so the burn lies in ragged sheets and runs rather than the round
	// blobs of a camouflage scheme
	vec3 w = p + vec3(vnoise(p * 0.7) - 0.5, (vnoise(p * 0.7 + 31.0) - 0.5) * 0.5, vnoise(p * 0.7 + 17.0) - 0.5) * 2.2;
	float big = fbm(w * 0.5);
	float mid = fbm(w * 1.9 + 11.0);
	float fine = vnoise(p * 9.0);
	float grain = vnoise(p * 33.0);
	// how far the fire reached: a ragged front, not a circle
	float border = length((p - source_world) * vec3(1.0, 0.74, 1.0)) + (big - 0.5) * extent * 0.3;
	float burnt = 1.0 - smoothstep(extent * 0.8, extent * 1.05, border);
	// a few islands of paint survive in the char
	burnt *= 1.0 - smoothstep(0.78, 0.86, mid) * 0.85;
	if (burnt < 0.02) { discard; }
	float up = clamp(n.y, 0.0, 1.0);
	float side = 1.0 - abs(n.y);
	// rust and soot run down the plates: noise drawn out along the vertical
	float streak = vnoise(vec3(w.x * 3.1, p.y * 0.42, w.z * 3.1) + 3.0) * 0.7 + mid * 0.3;
	// how near the heart of the fire, where it burnt hottest (ragged too)
	float hot = 1.0 - smoothstep(extent * 0.1, extent * 0.75, length(p - source_world) + (big - 0.5) * extent * 0.45);
	vec3 charred = vec3(0.021, 0.019, 0.017) * (0.72 + 0.4 * fine + 0.2 * grain);
	vec3 steel = vec3(0.046, 0.038, 0.032) * (0.8 + 0.3 * fine + 0.15 * grain);  // bare steel the heat has dulled
	vec3 film = mix(vec3(0.075, 0.071, 0.066), vec3(0.15, 0.144, 0.134), smoothstep(0.25, 0.85, fine * 0.6 + grain * 0.4));
	vec3 rust = mix(vec3(0.055, 0.028, 0.015), vec3(0.105, 0.048, 0.022), mid) * (0.85 + 0.3 * fine);
	vec3 ash = vec3(0.12, 0.116, 0.11) * (0.8 + 0.4 * fine);
	vec3 c = mix(charred, steel, smoothstep(0.42, 0.66, big));
	// where it burnt hottest the paint is a pale grey film, in sheets
	float filmed = smoothstep(0.48, 0.64, big * 0.55 + mid * 0.45) * hot * (0.5 + 0.5 * up);
	c = mix(c, film, filmed * 0.9);
	// the bare steel rusts in runs down the sides, less on the tops
	float rusted = smoothstep(0.56, 0.76, mid * 0.5 + streak * 0.5) * (0.25 + 0.75 * side) * (1.0 - filmed);
	c = mix(c, rust, rusted * 0.85 * smoothstep(0.35, 0.75, burnt));
	// soot streaked down from the hatches and grilles
	c *= 1.0 - smoothstep(0.6, 0.82, streak) * side * 0.45;
	// ash settles on what faces up, in drifts
	c = mix(c, ash, smoothstep(0.6, 0.82, fine * 0.25 + mid * 0.75) * up * up * 0.6);
	// blistered, browned paint at the edge of the fire
	float edge = smoothstep(0.02, 0.3, burnt) * (1.0 - smoothstep(0.3, 0.75, burnt));
	c = mix(c, vec3(0.085, 0.055, 0.034) * (0.8 + 0.4 * fine), edge * 0.7);
	ALBEDO = c;
	ROUGHNESS = mix(0.86, 1.0, max(filmed, up * 0.5)) - rusted * 0.06;
	SPECULAR = 0.12;
	// while it burns, embers glow in thin cracks near the heart of the fire
	float crack = 1.0 - smoothstep(0.0, 0.012, abs(vnoise(p * 5.3 + 5.0) - 0.5));
	crack *= smoothstep(0.62, 0.8, mid) * (0.25 + 0.75 * up);
	float heat = 1.0 - smoothstep(extent * 0.12, extent * 0.45, length(p - source_world));
	float flick = 0.6 + 0.4 * sin(TIME * 3.3 + p.x * 2.1 + p.z * 1.7 + mid * 8.0);
	EMISSION = vec3(1.0, 0.3, 0.04) * glow * glow * crack * heat * 3.5 * flick;
	ALPHA = clamp(burnt * 1.15, 0.0, 1.0);
}
