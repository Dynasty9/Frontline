// The living map behind the game's menus (scripts/ui/topo_backdrop.gd and the
// ground's constants from topo_survey.gd), drawn behind the site's pages: fine
// contours with every fifth an index contour, a map grid with a cross at each
// corner and a ruler round the margins, the lines tinted in colours that
// wander round the interface theme's six, and clouds drifting over it. The
// ground folds and drifts so slowly you notice it more than see it; the sheet
// leans a little after the cursor, a click sends a faint ring out across it,
// and the view pans slowly to the right (and a little with the page as it
// scrolls). Behind the page's column of text it's quieter still. Port it again if the game's changes: the maths here is the
// game's, line for line, without what's only for the menu's own screens
// (the intro's wave, the survey's interference, the loading screen's beam,
// the lettering the game draws on top).

/** Field Brass, the interface theme the site wears (UiKit.THEMES.brass.map): the six colours the contours turn through. */
export const BRASS = [
  [0.96, 0.79, 0.43],
  [1.0, 0.47, 0.27],
  [0.95, 0.33, 0.52],
  [0.58, 0.45, 1.0],
  [0.32, 0.74, 1.0],
  [0.35, 0.92, 0.68],
]

export const LEAN = 0.012 // how far the sheet follows the cursor (screen heights, with it at the edge): a hint, not a sway
export const PAN = 0.007 // how fast the view pans to the right over the sheet (screen heights a second)
export const TAP_LIFE = 1.6 // seconds a click's ring is on the map

export const VERTEX = `#version 300 es
// one triangle that covers the screen
void main() {
	vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
	gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
`

export const FRAGMENT = `#version 300 es
precision highp float;
precision highp int;

uniform vec2 res;  // the canvas, in pixels
uniform float clock;
uniform vec2 lean;  // how far the sheet has slid after the cursor (screen heights)
uniform vec2 cam;  // where the view is over the sheet (screen heights)
uniform vec3 taps[4];  // recent clicks: x, y (fraction of the screen), seconds since
uniform vec3 keys[6];  // the theme's colours the contours turn through
uniform float ink;  // how strongly the map is drawn over the page's ground
uniform vec2 column;  // the page's column of text: half its width (pixels), and how much quieter the map is behind it
uniform float clouds;
uniform float grain;

out vec4 frag;

// the ground's shape and drift (TopoSurvey's)
const float SCALE = 4.2;
const float LEVELS = 20.0;
const float ROUGH = 0.45;
const int CREASED = 1;
const float CREASE = 1.0;
const float CREEP = 0.016;
const vec2 WARP = vec2(0.004, 0.0033);
const vec2 DRIFT = vec2(0.0022, -0.0015);
const vec2 TILT = vec2(0.055, -0.03);
const float GRID = 6.0;  // grid squares per screen height
const float PAN = ${PAN.toFixed(4)};
const vec3 BG = vec3(0.0392, 0.0471, 0.0431);  // the site's ground, #0a0c0b
const vec3 SLEEP_LINE = vec3(0.105, 0.115, 0.115);

// the lattice's gradients from an integer hash (pcg2d)
vec2 hash2(vec2 p) {
	uvec2 v = uvec2(ivec2(p));
	v = v * 1664525u + 1013904223u;
	v.x += v.y * 1664525u;
	v.y += v.x * 1664525u;
	v = v ^ (v >> 16u);
	v.x += v.y * 1664525u;
	v.y += v.x * 1664525u;
	v = v ^ (v >> 16u);
	return vec2(v) * (2.0 / 4294967295.0) - 1.0;
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// gradient noise with a quintic fade, so contour lines bend without kinks
float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(hash2(i), f);
	float b = dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm3(vec2 p) {
	float s = 0.5 * gnoise(p);
	p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(1.7, 9.2);
	s += 0.25 * gnoise(p);
	p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(8.3, 2.8);
	s += 0.125 * gnoise(p);
	return s;
}

float fbm5(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		float n = gnoise(p);
		if (i < CREASED) {
			n = mix(n, sqrt(n * n + 0.002) - 0.22, CREASE);  // a valley cut along the fold
		}
		s += a * n;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(3.1, 7.7);
		a *= ROUGH;
	}
	return s;
}

// the ground: folded by two slow warps, so hills drift, merge and part over
// minutes rather than seconds, on land that climbs gently across the sheet
float ground(vec2 q, float t) {
	vec2 w = vec2(fbm3(q * 0.6 + vec2(0.0, t * WARP.x)), fbm3(q * 0.6 + vec2(5.2, 1.3) - vec2(t * WARP.y, 0.0)));
	return fbm5(q + w * 1.1 + t * DRIFT) + dot(q, TILT);
}

// a slow wheel of colours (each one held a while, then eased into the next)
vec3 wheel(float x) {
	x = fract(x) * 6.0;
	vec3 c = keys[0];
	c = mix(c, keys[1], smoothstep(0.0, 1.0, x));
	c = mix(c, keys[2], smoothstep(1.0, 2.0, x));
	c = mix(c, keys[3], smoothstep(2.0, 3.0, x));
	c = mix(c, keys[4], smoothstep(3.0, 4.0, x));
	c = mix(c, keys[5], smoothstep(4.0, 5.0, x));
	c = mix(c, keys[0], smoothstep(5.0, 6.0, x));
	return c;
}

// the clouds' own hash: a sine hash rounds differently for the same corner
// seen from two cells at these coordinates, and they'd come out in blocks
float chash(vec2 p) {
	uvec2 v = uvec2(ivec2(p));
	v = v * 1664525u + 1013904223u;
	v.x += v.y * 1664525u;
	v.y += v.x * 1664525u;
	v = v ^ (v >> 16u);
	v.x += v.y * 1664525u;
	return float(v.x) * (1.0 / 4294967295.0);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(chash(i), chash(i + vec2(1.0, 0.0)), f.x), mix(chash(i + vec2(0.0, 1.0)), chash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float cfbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return s;
}

// how much cloud there is at c (cloud space), its shape slowly turning over
float cover(vec2 c, float t) {
	float w = cfbm(c * 0.45 + vec2(t * 0.012, 0.0));
	return cfbm(c + vec2(w * 0.9, w * 0.4));
}

void main() {
	vec2 uv = vec2(gl_FragCoord.x / res.x, 1.0 - gl_FragCoord.y / res.y);
	float aspect = res.x / res.y;
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);  // screen heights from the centre
	float px = max(res.y / 1080.0, 0.7);  // one 1080p pixel, in real pixels
	// the whole sheet, grid and all, slides a little after the cursor (the
	// vignette stays put: it belongs to the screen)
	vec2 m = p - lean;
	float t = clock;
	vec2 g = m + cam;  // where on the whole sheet: the view pans across it
	float h = ground(g * SCALE, t);
	// a click sends a thin ring out across the sheet, gone in a second or so,
	// that lights the lines it crosses a little and moves none of them
	float flash = 0.0;
	for (int i = 0; i < 4; i++) {
		float age = taps[i].z;
		if (age < 1.6) {
			float r = length(p - (taps[i].xy - 0.5) * vec2(aspect, 1.0));
			float fade = exp(-age * 2.6) * smoothstep(0.0, 0.05, age);
			flash += fade * exp(-abs(r - age * 0.45) * 45.0);
		}
	}

	// contour lines: crisp at any size, fine, and every fifth one a heavier index
	// contour; the levels creep, so lines slide down the slopes (a level a minute)
	float lv = h * LEVELS + t * CREEP;
	float fw = max(length(vec2(dFdx(lv), dFdy(lv))), 1e-5);
	float fd = abs(fract(lv + 0.5) - 0.5);
	float dpx = fd / fw;  // pixels to the nearest line
	float idx = step(mod(floor(lv + 0.5), 5.0), 0.5);
	float halfw = mix(0.5, 0.85, idx) * px;
	float crowd = smoothstep(0.5, 0.16, fw * px);  // lines packed tighter than a few pixels blur into mush
	float line = clamp(halfw + 0.5 - dpx, 0.0, 1.0) * crowd;
	// a tight halo, and light pooling wider where the ground is gentle
	float glow = exp(-dpx / (2.6 * px)) * crowd + exp(-fd * 10.0) * 0.45;

	// colour: the wheel turns over three minutes, spread across the map along a
	// direction that slowly turns, and shifted with height: a backdrop, never
	// the thing you look at
	vec2 dir = vec2(cos(t * 0.008), sin(t * 0.008));
	vec3 lc = wheel(t / 180.0 + dot(m, dir) * 0.16 + h * 0.1);
	vec3 col_line = SLEEP_LINE * 0.6 + lc * mix(0.135, 0.2, idx);
	float lift = 1.0 + 0.7 * flash;
	float gi = mix(0.06, 0.14, idx) * lift;

	// between the lines: faint terraces, higher ground a touch lighter
	float terrace = (floor(lv) - t * CREEP) / LEVELS;
	vec3 add = lc * (0.004 + 0.01 * smoothstep(-0.5, 0.55, terrace) + 0.008 * flash);
	add += col_line * (line * lift + glow * gi);

	// the map grid, with a cross at each corner (drawn on the sheet: it pans with it)
	vec2 gq = g * GRID;
	vec2 gfw = max(fwidth(gq), vec2(1e-5));
	vec2 gd = abs(fract(gq + 0.5) - 0.5) / gfw;
	float gline = clamp(0.5 * px + 0.5 - min(gd.x, gd.y), 0.0, 1.0);
	float arm = 7.0 * px;
	float cross = clamp(0.6 * px + 0.5 - min(gd.x, gd.y), 0.0, 1.0) * step(max(gd.x, gd.y), arm);
	// and a ruler round the margins: a tick every tenth of a square, longer at
	// the half and longest where a grid line meets the edge
	vec2 tq = g * GRID * 10.0;
	vec2 td = abs(fract(tq + 0.5) - 0.5) / max(fwidth(tq), vec2(1e-5));
	vec2 tn = floor(tq + 0.5);
	vec2 tlen = vec2(mod(tn.x, 10.0) < 0.5 ? 10.0 : (mod(tn.x, 5.0) < 0.5 ? 6.0 : 3.0),
		mod(tn.y, 10.0) < 0.5 ? 10.0 : (mod(tn.y, 5.0) < 0.5 ? 6.0 : 3.0)) * px;
	vec2 edge = min(uv, 1.0 - uv) * res;  // real pixels in from the sides, and from the top and bottom
	float tick = clamp(0.5 * px + 0.5 - td.x, 0.0, 1.0) * step(edge.y, tlen.x) + clamp(0.5 * px + 0.5 - td.y, 0.0, 1.0) * step(edge.x, tlen.y);
	vec3 gcol = mix(vec3(0.6, 0.62, 0.6), mix(lc, vec3(1.0), 0.5), 0.3);
	add += gcol * (gline * 0.04 + cross * 0.09 + min(tick, 1.0) * 0.14);

	// quieter behind the page's column of text, as the menu's map is behind a title
	float aside = smoothstep(column.x * 0.6, column.x * 1.08, abs(gl_FragCoord.x - res.x * 0.5));
	vec3 col = BG + add * ink * mix(1.0 - column.y, 1.0, aside);

	// clouds over the map, nearer than the ground: they slide across faster than
	// the view pans and lean further after the cursor, and each casts a soft
	// shadow a little below and to the right of itself
	if (clouds > 0.0) {
		vec2 c = ((p - lean * 1.3) + vec2(t * (PAN * 2.4 + 0.006), t * 0.0025) + vec2(0.0, cam.y * 1.6)) * 1.6;
		float cloud = smoothstep(0.45, 0.7, cover(c, t));
		float shadow = smoothstep(0.44, 0.71, cover(c - vec2(0.1, 0.065), t));
		float a_cloud = cloud * 0.085 * clouds;
		float a_shadow = shadow * 0.4 * clouds;
		float a = a_cloud + a_shadow * (1.0 - a_cloud);
		// (a shadow takes the lines under it and only a little of the ground,
		// which stays close to the page's own colour)
		col = vec3(0.74, 0.79, 0.84) * a_cloud + (col - BG) * (1.0 - a) + BG * (1.0 - 0.25 * a);
	}

	// a vignette (on the map's ink only: the ground stays the page's own colour,
	// so whatever sits on it in that colour meets it without a seam), and a
	// little grain against banding
	vec2 vu = uv - 0.5;
	col = BG + (col - BG) * (1.0 - 0.9 * dot(vu, vu));
	col +=(hash1(gl_FragCoord.xy + fract(t * 7.31) * 113.0) - 0.5) * 0.012 * grain;
	frag = vec4(min(col, vec3(1.0)), 1.0);
}
`
