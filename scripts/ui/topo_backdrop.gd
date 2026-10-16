class_name TopoBackdrop
extends ColorRect
## The living map behind every screen outside a battle: the title, the menu and
## the loading screen (and, see-through, behind the menus in a battle). A
## survey sheet of rolling ground seen from high up: fine contours with every
## fifth an index contour lettered with its height, spot heights on the
## summits, a map grid with its numbers and a ruler round the margins. The
## ground folds and drifts so slowly you notice it more than see it, and its
## lines are tinted in colours that wander round the interface theme's six
## (brass, ember, rose, violet, blue and jade in Field Brass). It stays a
## backdrop: awake it is only a little brighter than the boot splash's map. The
## whole sheet leans a little after the cursor, and a click sends a faint ring
## out across it. The view pans slowly to the right over the sheet, clouds
## drift over it, and on the title and the menu the map is at work: now and
## then a band of interference races across it and what it passes over turns
## up for a few seconds, a contact, a unit moving off, an axis of advance to an
## objective.
##
## Every copy draws the same picture at the same moment (one shared clock, one
## shared cursor, one survey), so one screen can fade into another and only
## what's in front of the map changes.

const SHADER := """
shader_type canvas_item;

uniform float aspect = 1.7778;
uniform float clock = 0.0;
// the intro's wave: where it starts (fraction of the screen) and how long ago
// (negative: not yet; everything it hasn't reached is still the boot splash)
uniform vec2 wake_at = vec2(0.5);
uniform float wake_t = 1000.0;
uniform vec2 lean = vec2(0.0);  // how far the sheet has slid after the cursor (screen heights)
uniform vec3 taps[4];  // recent clicks: x, y (fraction of the screen), seconds since
uniform float shade = 0.0;  // darkening down the left, under a column of text
uniform float scan = 0.0;  // the loading screen's survey sweep
uniform vec2 survey = vec2(0.0);  // the menu's survey: its band's leading edge across the screen (screen heights from the centre) and how strongly it shows
uniform vec2 cam = vec2(0.0);  // where the view is over the sheet (screen heights): it pans slowly to the right
uniform float zoom = 1.0;  // closing in on the ground (the loading screen)
uniform vec3 quiet = vec3(0.5, 0.5, 0.0);  // a calm patch behind a title: centre (fraction of the screen), strength
uniform float grain = 1.0;
uniform vec3 keys[6];  // the theme's colours the contours turn through
uniform float see_through = 0.0;  // over a battle: a dark veil the lines stand out of
// the heights lettered on the index contours, which break the line under them:
// centre (screen heights from the centre) and the cos and sin of the angle;
// then half the figure's length (screen heights) and how far it's shown
uniform vec4 gaps[12];
uniform vec2 gap_size[12];

// the ground's shape and drift (TopoSurvey's, which works it out again to letter it)
const float SCALE = {SCALE};
const float LEVELS = {LEVELS};
const float ROUGH = {ROUGH};
const int CREASED = {CREASED};
const float CREASE = {CREASE};
const float CREEP = {CREEP};
const vec2 WARP = {WARP};
const vec2 DRIFT = {DRIFT};
const vec2 TILT = {TILT};
const float GRID = 6.0;  // grid squares per screen height
const vec3 BG = vec3(0.031, 0.039, 0.043);
const vec3 SLEEP_LINE = vec3(0.105, 0.115, 0.115);

// the lattice's gradients from an integer hash (pcg2d), so the CPU can repeat
// them exactly
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

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);  // screen heights from the centre
	float px = 1.0 / max(1080.0 * fwidth(uv.y), 1e-4);  // one 1080p pixel, in real pixels
	// the whole sheet, grid and all, slides a little after the cursor (the
	// vignette and the shading for the text stay put: they belong to the screen)
	vec2 m = p - lean;  // where on the screen's sheet this pixel is
	float t = clock;
	// the menu's survey: now and then a band of interference races across the
	// screen, the map in it torn into rows shifted sideways
	float sdx = p.x - survey.x;
	float band = survey.y * (sdx <= 0.0 ? exp(sdx / 0.05) : exp(-sdx / 0.006));
	float tf = floor(t * 24.0);  // the interference changes 24 times a second
	float row = floor(p.y * 180.0);  // in rows 6 px high at 1080p
	float jit = (hash1(vec2(row, tf)) - 0.5) * step(0.4, hash1(vec2(row * 1.7, tf + 3.0)));
	// where on the whole sheet: the view pans across it, the loading screen zooms
	vec2 g = (m + vec2(jit * 0.04 * band, 0.0)) / zoom + cam;
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

	// the intro's wave: behind its front the map is awake
	vec2 wp = (wake_at - 0.5) * vec2(aspect, 1.0);
	float rad = length(p - wp);
	float front = wake_t < 0.0 ? -1.0 : 2.4 * (1.0 - exp(-wake_t * 0.8));
	float awake = smoothstep(front + 0.02, front - 0.22, rad);
	float wf = wake_t < 0.0 ? 0.0 : exp(-abs(rad - front) * 16.0) * exp(-wake_t * 0.8);

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
	// a tight halo, and light pooling wider where the ground is gentle (measured
	// in levels, not pixels, so it's smooth and meets itself between two lines)
	float glow = exp(-dpx / (2.6 * px)) * crowd + exp(-fd * 10.0) * 0.45;
	// the figures break the line under them, as on a printed sheet
	float onepx = fwidth(p.y);
	float gap = 0.0;
	for (int i = 0; i < 12; i++) {
		if (gap_size[i].y > 0.0) {
			vec2 d = p - gaps[i].xy;
			vec2 l = vec2(dot(d, gaps[i].zw), dot(d, vec2(-gaps[i].w, gaps[i].z)));
			vec2 e = abs(l) - vec2(gap_size[i].x, 0.0055);
			gap = max(gap, gap_size[i].y * clamp(0.5 - max(e.x, e.y) / onepx, 0.0, 1.0));
		}
	}
	line *= 1.0 - gap;
	glow *= 1.0 - gap;

	// the loading screen's survey: a beam sweeping across, lighting what it passes
	float sx = fract(t * 0.14) * (aspect + 0.8) - 0.4;
	float dx = uv.x * aspect - sx;
	float sweep = scan * (exp(-abs(dx) * 40.0) * 1.6 + (dx < 0.0 ? exp(dx * 4.0) * 0.6 : 0.0));
	float pass = band * awake * 1.4;  // the lines light up in the band

	// colour: the wheel turns over three minutes, spread across the map along a
	// direction that slowly turns, and shifted with height. Awake, the lines are
	// the splash's grey with a tint of it, a little brighter: a backdrop, never
	// the thing you look at.
	vec2 dir = vec2(cos(t * 0.008), sin(t * 0.008));
	vec3 lc = wheel(t / 180.0 + dot(m, dir) * 0.16 + h * 0.1);
	vec3 awake_line = SLEEP_LINE * 0.6 + lc * mix(0.135, 0.2, idx);
	vec3 col_line = mix(SLEEP_LINE * mix(0.95, 1.2, idx), awake_line, awake);
	float lift = 1.0 + 2.6 * wf + 0.7 * flash + sweep + pass;
	float li = lift;
	float gi = awake * mix(0.06, 0.14, idx) * lift;

	// between the lines: faint terraces, higher ground a touch lighter
	float terrace = (floor(lv) - t * CREEP) / LEVELS;
	vec3 col = BG + lc * awake * (0.004 + 0.01 * smoothstep(-0.5, 0.55, terrace) + 0.05 * wf + 0.008 * flash);
	col += BG * (1.0 - awake) * 0.5 * (1.0 - smoothstep(0.0, 0.9, length(p)));  // the splash's soft centre
	col += col_line * (line * li + glow * gi);
	col += lc * scan * (0.09 * exp(-abs(dx) * 140.0) + 0.025 * exp(-abs(dx) * 18.0));
	// the band's bright leading edge, static in it, rows dropping out, and the
	// lines in it split toward cyan and magenta row by row
	float front_line = clamp(1.0 - abs(sdx) / onepx, 0.0, 1.0) * survey.y;
	float speck = step(0.985, hash1(floor(FRAGCOORD.xy * 0.5) + tf * 17.0)) * band;
	float drop = step(0.88, hash1(vec2(row * 3.1, tf + 7.0))) * band;
	vec3 fringe = mod(row, 2.0) < 1.0 ? vec3(0.55, 1.0, 1.0) : vec3(1.0, 0.6, 0.95);
	col = mix(col, col * fringe, 0.45 * band * awake);
	col *= 1.0 - 0.55 * drop * awake;
	col += mix(lc, vec3(1.0), 0.5) * awake * (0.16 * front_line + 0.03 * band + 0.12 * speck);

	// the map grid, with a cross at each corner (it's drawn on the sheet: it pans with it)
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
	vec2 edge = min(uv, 1.0 - uv) / max(fwidth(uv), vec2(1e-6));  // real pixels in from the sides, and from the top and bottom
	float tick = clamp(0.5 * px + 0.5 - td.x, 0.0, 1.0) * step(edge.y, tlen.x) + clamp(0.5 * px + 0.5 - td.y, 0.0, 1.0) * step(edge.x, tlen.y);
	vec3 gcol = mix(vec3(0.6, 0.62, 0.6), mix(lc, vec3(1.0), 0.5), awake * 0.3);
	col += gcol * (gline * 0.04 + cross * mix(0.07, 0.09, awake) + min(tick, 1.0) * 0.14);

	// a vignette, the column of text's shade, and a little grain against banding
	vec2 vu = uv - 0.5;
	col *= 1.0 - 0.9 * dot(vu, vu);
	float sx2 = clamp(uv.x * aspect / 0.75, 0.0, 1.0);
	float dark = sx2 < 0.55 ? mix(0.82, 0.5, sx2 / 0.55) : mix(0.5, 0.0, (sx2 - 0.55) / 0.45);
	col *= 1.0 - dark * shade;
	vec2 dq = (p - (quiet.xy - 0.5) * vec2(aspect, 1.0)) / vec2(0.6, 0.27);
	col *= 1.0 - quiet.z * awake * exp(-dot(dq, dq));
	col += (hash1(FRAGCOORD.xy + fract(t * 7.31) * 113.0) - 0.5) * 0.014 * grain;
	// see-through, the dark ground lets a battle show through it and the lines don't
	float ink = clamp((col.r + col.g + col.b - BG.r - BG.g - BG.b) * 2.2, 0.0, 1.0);
	COLOR = vec4(min(col, vec3(1.0)), mix(1.0, clamp(see_through + ink, 0.0, 1.0), step(0.001, see_through)));
}
"""

## Clouds over the map, nearer than the ground: they slide across faster than
## the view pans and lean further after the cursor, and each casts a soft
## shadow a little below and to the right of itself. Drawn over the lettering,
## so a shadow darkens the figures under it too.
const CLOUDS := """
shader_type canvas_item;

uniform float aspect = 1.7778;
uniform float clock = 0.0;
uniform vec2 lean = vec2(0.0);
uniform float pan = 0.0;
uniform float strength = 0.0;

// an integer hash (pcg2d): a sine hash rounds differently for the same corner
// seen from two cells at these coordinates, and the clouds would come out in blocks
float hash(vec2 p) {
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
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
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
	float w = fbm(c * 0.45 + vec2(t * 0.012, 0.0));
	return fbm(c + vec2(w * 0.9, w * 0.4));
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	// faster than the ground as the view pans (they're nearer), plus a little wind
	vec2 c = ((p - lean * 1.8) + vec2(clock * (pan * 2.4 + 0.006), clock * 0.0025)) * 1.6;
	float cloud = smoothstep(0.45, 0.7, cover(c, clock));
	float shadow = smoothstep(0.44, 0.71, cover(c - vec2(0.1, 0.065), clock));
	float a_cloud = cloud * 0.085 * strength;
	float a_shadow = shadow * 0.4 * strength;
	float a = a_cloud + a_shadow * (1.0 - a_cloud);
	COLOR = vec4(vec3(0.74, 0.79, 0.84) * a_cloud / max(a, 1e-4), a);
}
"""

const LEAN := 0.04  # how far the sheet follows the cursor (screen heights, with it at the edge)
const PAN := 0.007  # how fast the view pans to the right over the sheet (screen heights a second)
const GRID := 6.0  # grid squares per screen height (as the shader's)
const EASTING := 31  # the grid's numbers: the first square right of the centre
const NORTHING := 58  # and the first above it
const BG := Color(0.031, 0.039, 0.043)
const SLEEP_LINE := Color(0.105, 0.115, 0.115)
const SURVEY_EVERY := 0.5  # seconds between surveys of the drifting ground
# The menu's survey: now and then a band of interference races across the
# screen, and what it passes over turns up for a few seconds: a contact, a unit
# on the move, an axis of advance to an objective. Nothing stays; it's the map
# at work.
const TACT_START := 4.0  # the first pass, seconds in (after the title)
const TACT_CYCLE := 11.0  # from one pass to the next
const TACT_SWEEP := 1.1  # how long a pass takes to cross the screen
const TACT_LIFE := 9.0  # how long what it turns up stays
const TACT_INK := 0.55  # how strongly it's drawn: a backdrop, never a display
const CALLSIGNS := ["BRAVO 2", "CHARLIE 1", "FOXTROT 3", "GOLF 1", "ECHO 2", "DELTA 4", "KILO 1"]
const OBJECTIVES := ["OBJ IRON", "OBJ RIDGE", "OBJ LANTERN", "OBJ ANVIL", "OBJ FALCON", "OBJ HARVEST"]
enum Tact { CONTACT, UNIT, AXIS }


## A height lettered on the map: on an index contour, along the line, or a
## spot height on a summit.
class Mark:
	var id := 0
	var spot := false
	var at := Vector2.ZERO  # on the ground (TopoSurvey's positions), easing toward the last survey's
	var to := Vector2.ZERO
	var ang := 0.0
	var ang_to := 0.0
	var level := 0
	var text := ""
	var half := 0.0  # half the figure's length (screen heights), for the gap in the line
	var a := 0.0  # how far it's shown
	var keep := true  # the last survey still had it (else it fades out)


## One survey, run on a worker thread.
class Job:
	var t := 0.0
	var centre := Vector2.ZERO
	var aspect := 1.0
	var old: Array = []
	var out: Array = []

	func run() -> void:
		out = TopoSurvey.survey(t, aspect, centre, old)


## Draws the lettering over the map (a child, so the map's shader isn't on it).
class Ink:
	extends Control
	var map: TopoBackdrop

	func _draw() -> void:
		map._draw_ink(self)


static var _shader: Shader
static var _cloud_shader: Shader
static var _clock := 0.0
static var _frame := -1
static var _mouse := Vector2(0.5, 0.5)
static var _mouse_to := Vector2(0.5, 0.5)
static var _mouse_on := 0.0
static var _moved := false  # the cursor has moved since the game started
static var _pinned := false  # --menu-cursor: held still for screenshots
static var _held := false  # --intro-at: the clock stopped for screenshots
static var _taps: Array = []  # [Vector2 (fraction of the screen), clock when clicked]
static var _tap_frame := -1
static var _keys: Array = (UiKit.THEMES.brass.map as Array).duplicate()  # the colours drawn now
static var _keys_to: Array = _keys.duplicate()  # and the theme's, which they ease toward
static var _keys_packed := PackedVector3Array()
static var _marks: Array = []  # Mark
static var _next_mark := 0
static var _surveyed := -1.0  # the clock when the last survey began
static var _task := -1  # the survey under way on a worker
static var _job: Job
static var _aspect := 16.0 / 9.0
static var _copies := 0
static var _tact_rng := RandomNumberGenerator.new()

var wake_at := Vector2(0.5, 0.5)
var wake_t := 1000.0
var shade := 0.0
var scan := 0.0
var quiet := Vector3(0.5, 0.5, 0.0)
var zoom := 1.0
var see_through := 0.0
var _mat: ShaderMaterial
var _ink: Ink
var _clouds: ColorRect
var _cloud_mat: ShaderMaterial
var _gaps := PackedVector4Array()
var _gap_size := PackedVector2Array()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = BG
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER.format({"SCALE": _glsl(TopoSurvey.SCALE), "LEVELS": _glsl(TopoSurvey.LEVELS), "ROUGH": _glsl(TopoSurvey.ROUGH),
			"CREASED": str(TopoSurvey.CREASED), "CREASE": _glsl(TopoSurvey.CREASE), "CREEP": _glsl(TopoSurvey.CREEP),
			"WARP": _glsl(TopoSurvey.WARP), "DRIFT": _glsl(TopoSurvey.DRIFT), "TILT": _glsl(TopoSurvey.TILT)})
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	material = _mat
	_ink = Ink.new()
	_ink.map = self
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ink)
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _cloud_shader == null:
		_cloud_shader = Shader.new()
		_cloud_shader.code = CLOUDS
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = _cloud_shader
	_clouds = ColorRect.new()
	_clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clouds.material = _cloud_mat
	add_child(_clouds)
	_clouds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gaps.resize(12)
	_gap_size.resize(12)
	_push()


func _enter_tree() -> void:
	_copies += 1


func _exit_tree() -> void:
	_copies -= 1
	if _copies <= 0 and _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)  # nothing may be left running on a worker at exit
		_task = -1


static func _glsl(v: Variant) -> String:
	if v is Vector2:
		return "vec2(%.6f, %.6f)" % [v.x, v.y]
	return "%.6f" % float(v)


## How far the intro's wave has spread, in screen heights, t seconds after it
## went out (as the shader has it).
static func wave_front(t: float) -> float:
	return 2.4 * (1.0 - exp(-t * 0.8))


## The shared clock, cursor and survey, once a frame. The clock runs in real
## time (not a test's --timescale) and from 0 on the first frame drawn, which is
## the boot splash; it advances by at most a tenth of a second, so a long build
## frame doesn't jump the map.
static func _tick(vp: Viewport, delta: float) -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	var first := _frame < 0
	var dt := 0.0 if first or _held else minf(delta / maxf(Engine.time_scale, 0.001), 0.1)
	_frame = f
	_clock += dt
	# a new theme's colours flow into the map over a second or so
	var k := 1.0 - exp(-dt * 2.5)
	_keys_packed.resize(6)
	for i in 6:
		_keys[i] = (_keys[i] as Color).lerp(_keys_to[i], k)
		var c: Color = _keys[i]
		_keys_packed[i] = Vector3(c.r, c.g, c.b)
	if vp:
		var vs := vp.get_visible_rect().size
		_aspect = vs.x / maxf(vs.y, 1.0)
		if not _pinned:
			var m := vp.get_mouse_position()
			var inside := Rect2(Vector2.ZERO, vs).has_point(m) and DisplayServer.window_is_focused()
			if inside and _moved:
				_mouse_to = m / vs
			_mouse_on = move_toward(_mouse_on, 1.0 if inside and _moved else 0.0, dt * 0.8)
	_mouse = _mouse.lerp(_mouse_to, 1.0 - exp(-dt * 2.0))  # the map follows lazily, never snaps
	for i in range(_taps.size() - 1, -1, -1):
		if _clock - float(_taps[i][1]) > 1.6:
			_taps.remove_at(i)
	_letter(dt, first)


## Keep the lettering on the drifting ground: a survey at once on the first
## frame (the boot splash has its figures), then one after another on a worker,
## each carrying the figures along and finding room for new ones, which fade in
## as the ones the ground has shrugged off fade out.
static func _letter(dt: float, first: bool) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_take(_job.out, false)
	if first:
		_surveyed = _clock
		_take(TopoSurvey.survey(_clock, _aspect, camera(), []), true)
	elif _task < 0 and _clock - _surveyed >= SURVEY_EVERY:
		_surveyed = _clock
		_job = Job.new()
		_job.t = _clock
		_job.aspect = _aspect
		_job.centre = camera()
		for mk: Mark in _marks:
			if mk.keep:
				_job.old.append([mk.id, mk.spot, mk.to, mk.level])
		_task = WorkerThreadPool.add_task(_job.run, false, "Topo survey")
	var k := 1.0 - exp(-dt * 3.0)
	for i in range(_marks.size() - 1, -1, -1):
		var mk: Mark = _marks[i]
		mk.at = mk.at.lerp(mk.to, k)
		mk.ang = lerp_angle(mk.ang, mk.ang_to, k)
		mk.a = move_toward(mk.a, 1.0 if mk.keep else 0.0, dt * 1.2)
		if not mk.keep and mk.a <= 0.0:
			_marks.remove_at(i)


static func _take(out: Array, at_once: bool) -> void:
	var seen := {}
	for r in out:
		var mk: Mark = null
		for o: Mark in _marks:
			if o.id == int(r[0]):
				mk = o
				break
		if mk == null:
			mk = Mark.new()
			mk.id = _next_mark
			_next_mark += 1
			mk.spot = r[1]
			mk.at = r[2]
			mk.ang = r[3]
			mk.a = 1.0 if at_once else 0.0
			_marks.append(mk)
		mk.to = r[2]
		mk.ang_to = r[3]
		mk.level = r[4]
		mk.text = r[5]
		mk.half = (UiKit.text_width(mk.text, 11, 500) * 0.5 + 4.0) / 1080.0
		mk.keep = true
		seen[mk.id] = true
	for mk: Mark in _marks:
		if not seen.has(mk.id):
			mk.keep = false


## The theme's six colours for the contours. Before the first frame they're
## taken at once (the boot splash must match); after it they ease in.
static func set_palette(cols: Array) -> void:
	_keys_to = cols.duplicate()
	if _frame < 0:
		_keys = cols.duplicate()


## Start the clock that far in (screenshots of later colours).
static func start_at(seconds: float) -> void:
	_clock = seconds


## Stop the clock at a moment (screenshots of the title, and the boot splash).
static func hold(seconds: float) -> void:
	_clock = seconds
	_held = true


## Hold the cursor at a spot (fractions of the screen) and the map leaning
## after it, for screenshots.
static func pin_cursor(at: Vector2) -> void:
	_pinned = true
	_mouse = at
	_mouse_to = at
	_mouse_on = 1.0


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if ev is InputEventMouseMotion:
		_moved = true
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _tap_frame != Engine.get_process_frames():
		_tap_frame = Engine.get_process_frames()
		var vs := get_viewport().get_visible_rect().size
		_taps.append([(ev as InputEventMouseButton).position / vs, _clock])
		if _taps.size() > 4:
			_taps.pop_front()


func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	_tick(get_viewport(), dt)
	_push()
	_ink.queue_redraw()


## How far the sheet has slid after the cursor, on a screen of that aspect
## (screen heights).
static func _lean(aspect: float) -> Vector2:
	return (_mouse - Vector2(0.5, 0.5)) * Vector2(aspect, 1.0) * LEAN * _mouse_on


## Where the view is over the sheet (screen heights): it pans slowly to the
## right with the clock, so the ground, its grid and its figures drift left.
static func camera() -> Vector2:
	return Vector2(_clock * PAN, 0.0)


func _push() -> void:
	if _mat == null:
		return
	var aspect := size.x / maxf(size.y, 1.0)
	var lean := _lean(aspect)
	var cam := camera()
	_mat.set_shader_parameter("aspect", aspect)
	_mat.set_shader_parameter("cam", cam)
	_mat.set_shader_parameter("clock", _clock)
	_mat.set_shader_parameter("wake_at", wake_at)
	_mat.set_shader_parameter("wake_t", wake_t)
	_mat.set_shader_parameter("lean", lean)
	_mat.set_shader_parameter("shade", shade)
	_mat.set_shader_parameter("scan", scan)
	_mat.set_shader_parameter("survey", _sweep(aspect) if _tactical() else Vector2.ZERO)
	_mat.set_shader_parameter("quiet", quiet)
	_mat.set_shader_parameter("zoom", zoom)
	_mat.set_shader_parameter("grain", 0.0 if _held else 1.0)
	_mat.set_shader_parameter("see_through", see_through)
	if _keys_packed.size() < 6:
		_keys_packed.resize(6)
		for i in 6:
			var c: Color = _keys[i]
			_keys_packed[i] = Vector3(c.r, c.g, c.b)
	_mat.set_shader_parameter("keys", _keys_packed)  # a held frame is a still (the boot splash is one: no grain keeps it small)
	var taps := PackedVector3Array()
	for i in 4:
		if i < _taps.size():
			var tp: Vector2 = _taps[i][0]
			taps.append(Vector3(tp.x, tp.y, _clock - float(_taps[i][1])))
		else:
			taps.append(Vector3(0.5, 0.5, 99.0))
	_mat.set_shader_parameter("taps", taps)
	# the gaps in the index contours under their figures
	var n := 0
	for mk: Mark in _marks:
		if n >= 12:
			break
		if mk.spot or mk.a <= 0.0:
			continue
		var p := (mk.at - cam) * zoom + lean
		_gaps[n] = Vector4(p.x, p.y, cos(mk.ang), sin(mk.ang))
		_gap_size[n] = Vector2(mk.half, _shown(mk, p, aspect))
		n += 1
	for i in range(n, 12):
		_gap_size[i] = Vector2.ZERO
	_mat.set_shader_parameter("gaps", _gaps)
	_mat.set_shader_parameter("gap_size", _gap_size)
	# the clouds come in after the wake, and stay off over a battle
	var cloud := 0.0 if see_through > 0.0 else smoothstep(0.6, 3.0, _clock)
	_clouds.visible = cloud > 0.0
	if _clouds.visible:
		_cloud_mat.set_shader_parameter("aspect", aspect)
		_cloud_mat.set_shader_parameter("clock", _clock)
		_cloud_mat.set_shader_parameter("lean", lean)
		_cloud_mat.set_shader_parameter("pan", PAN)
		_cloud_mat.set_shader_parameter("strength", cloud)


## How far a figure is shown at a point on the screen (screen heights from the
## centre): as it fades in or out, and not at all in the calm patch behind a
## title or a briefing, asleep or awake.
func _shown(mk: Mark, p: Vector2, aspect: float) -> float:
	return mk.a * _calm(p, aspect)


## 0 in the middle of the calm patch behind a title or a briefing, 1 clear of it.
func _calm(p: Vector2, aspect: float) -> float:
	var dq := (p - (Vector2(quiet.x, quiet.y) - Vector2(0.5, 0.5)) * Vector2(aspect, 1.0)) / Vector2(0.6, 0.27)
	return clampf(1.0 - quiet.z * 1.6 * exp(-dq.dot(dq)), 0.0, 1.0)


## How much of the map's light reaches a point on the screen (screen heights
## from the centre), as the shader has it, and how awake the map is there.
func _lit(p: Vector2, aspect: float) -> Vector2:
	var uv := p / Vector2(aspect, 1.0) + Vector2(0.5, 0.5)
	var wp := (wake_at - Vector2(0.5, 0.5)) * Vector2(aspect, 1.0)
	var front := -1.0 if wake_t < 0.0 else wave_front(wake_t)
	var awake := smoothstep(front + 0.02, front - 0.22, p.distance_to(wp))
	var vu := uv - Vector2(0.5, 0.5)
	var k := 1.0 - 0.9 * vu.dot(vu)
	var sx := clampf(uv.x * aspect / 0.75, 0.0, 1.0)
	var dark := lerpf(0.82, 0.5, sx / 0.55) if sx < 0.55 else lerpf(0.5, 0.0, (sx - 0.55) / 0.45)
	k *= 1.0 - dark * shade
	var dq := (p - (Vector2(quiet.x, quiet.y) - Vector2(0.5, 0.5)) * Vector2(aspect, 1.0)) / Vector2(0.6, 0.27)
	k *= 1.0 - quiet.z * awake * exp(-dq.dot(dq))
	return Vector2(k, awake)


static func _wheel(x: float) -> Color:
	x = fposmod(x, 1.0) * 6.0
	var c: Color = _keys[0]
	for i in 6:
		c = c.lerp(_keys[(i + 1) % 6], smoothstep(float(i), float(i + 1), x))
	return c


## The colour of the map's ink at a point on the screen (screen heights from the
## centre), as the shader lights its index contours there: grey asleep, tinted
## awake, under the same vignette, shading and calm patch.
func _ink_colour(p: Vector2, aspect: float, lean: Vector2, h: float, boost := 1.4) -> Color:
	var lit := _lit(p, aspect)
	var dir := Vector2(cos(_clock * 0.008), sin(_clock * 0.008))
	var lc := _wheel(_clock / 180.0 + (p - lean).dot(dir) * 0.16 + h * 0.1)
	var line := (SLEEP_LINE * 1.25).lerp(SLEEP_LINE * 0.6 + lc * 0.21, lit.y)
	var c := BG + line * boost
	return Color(c.r * lit.x, c.g * lit.x, c.b * lit.x)


## Whether this copy shows the survey's sweep and what it turns up: on the
## menu and the title, not over a battle or on the loading screen (which has
## its own beam).
func _tactical() -> bool:
	return see_through <= 0.0 and scan <= 0.0


## Where the survey's band of interference is across the screen (its leading
## edge, screen heights from the centre) and how strongly it shows: it races
## across once a cycle, left to right, and is gone between.
static func _sweep(aspect: float) -> Vector2:
	var c := _clock - TACT_START
	if c < 0.0:
		return Vector2.ZERO
	var u := fposmod(c, TACT_CYCLE) / TACT_SWEEP
	if u >= 1.0:
		return Vector2.ZERO
	var x0 := -aspect * 0.5 - 0.15
	return Vector2(lerpf(x0, -x0, u), smoothstep(0.0, 0.05, u) * (1.0 - smoothstep(0.95, 1.0, u)))


## What the passes of this cycle and the last have turned up and is still on the
## map: [kind, place on the sheet, seconds since the pass found it, angle,
## length, label]. A pure function of the clock (each cycle's events come from
## its own seed), so every copy shows the same, and a held clock the same again.
static func _tactics(aspect: float) -> Array:
	var out: Array = []
	var c := _clock - TACT_START
	if c < 0.0:
		return out
	var cur := int(floorf(c / TACT_CYCLE))
	var x0 := -aspect * 0.5 - 0.15
	for n: int in [cur - 1, cur]:
		if n < 0:
			continue
		_tact_rng.seed = 7919 * n + 104729
		var count := 2 + _tact_rng.randi() % 2
		var placed: Array = []
		for k in count:
			# the right of the screen mostly: the menu's column covers the left
			var g := Vector2.ZERO
			for attempt in 8:
				g = Vector2(_tact_rng.randf_range(-0.12, aspect * 0.5 - 0.14), _tact_rng.randf_range(-0.36, 0.34))
				var clear := true
				for o in placed:
					if g.distance_to(o) < 0.24:
						clear = false
				if clear:
					break
			placed.append(g)
			var ang := _tact_rng.randf_range(-PI, PI)
			var length := _tact_rng.randf_range(0.17, 0.25)
			var kind: int = (n + k) % 3
			var label := ""
			if kind == Tact.UNIT:
				label = CALLSIGNS[_tact_rng.randi() % CALLSIGNS.size()]
			elif kind == Tact.AXIS:
				label = OBJECTIVES[_tact_rng.randi() % OBJECTIVES.size()]
				# an axis heads into the sheet, not off it
				var end := g + Vector2(cos(ang), sin(ang)) * length
				if absf(end.x) > aspect * 0.5 - 0.1 or absf(end.y) > 0.4:
					ang += PI
			var seen := float(n) * TACT_CYCLE + (g.x - x0) / (-2.0 * x0) * TACT_SWEEP
			var age := c - seen
			if age >= 0.0 and age < TACT_LIFE:
				# found where it was on the screen then; it stays put on the sheet
				out.append([kind, g + Vector2((TACT_START + seen) * PAN, 0.0), age, ang, length, label])
	return out


## A six-figure grid reference for a point on the sheet, as the margins number it.
static func _grid_ref(g: Vector2) -> String:
	var ex := g.x * GRID
	var ny := g.y * GRID
	var south := ceilf(ny)
	var e := posmod(EASTING + int(floorf(ex)), 100) * 10 + int(floorf((ex - floorf(ex)) * 10.0))
	var n := posmod(NORTHING - int(south), 100) * 10 + int(floorf((south - ny) * 10.0))
	return "%03d %03d" % [e, n]


## What the survey turns up, drawn faint: a contact (a hostile frame, a ring as
## it's found, its grid square bracketed for a moment and its reference), a unit
## moving off along a track, and an axis of advance pencilled in to an
## objective. They fade in as the band finds them and out after a few seconds,
## and drift left with the sheet as the view pans.
func _draw_tactics(ci: Control, vs: Vector2, aspect: float, lean: Vector2, font: Font, fs: int) -> void:
	var hgt := maxf(vs.y, 1.0)
	var u := hgt / 1080.0
	var mid := vs * 0.5
	var acc := UiKit.ACCENT
	var cam := camera()
	for ev in _tactics(aspect):
		var g: Vector2 = ev[1]
		var age: float = ev[2]
		var p := (g - cam) * zoom + lean
		var lit := _lit(p, aspect)
		var a := TACT_INK * lit.x * lit.y * _calm(p, aspect) * smoothstep(0.0, 0.35, age) * (1.0 - smoothstep(TACT_LIFE - 1.6, TACT_LIFE, age))
		if a <= 0.01:
			continue
		var at := p * hgt + mid
		var ink := _ink_colour(p, aspect, lean, 0.0, 2.2)
		ink.a = a / TACT_INK
		match int(ev[0]):
			Tact.CONTACT:
				var red := Defs.TEAM_COLORS[1] as Color
				var s := 7.0 * u
				var dia := PackedVector2Array([at + Vector2(0, -s), at + Vector2(s, 0), at + Vector2(0, s), at + Vector2(-s, 0), at + Vector2(0, -s)])
				ci.draw_colored_polygon(dia, Color(red.r, red.g, red.b, a * 0.18))
				ci.draw_polyline(dia, Color(red.r, red.g, red.b, a), 1.5 * u, true)
				var e := age / 1.4
				if e < 1.0:
					ci.draw_arc(at, (9.0 + 30.0 * UiFx.out_cubic(e)) * u, 0.0, TAU, 48, Color(red.r, red.g, red.b, a * (1.0 - e)), 1.2 * u, true)
				# its grid square, bracketed while it's fresh
				var b := a * (1.0 - smoothstep(1.0, 2.6, age))
				if b > 0.01:
					var sq0 := ((Vector2(floorf(g.x * GRID), floorf(g.y * GRID)) / GRID - cam) * zoom + lean) * hgt + mid
					var side := hgt / GRID * zoom
					var arm := 9.0 * u
					var lines := PackedVector2Array()
					for cx in [0.0, 1.0]:
						for cy in [0.0, 1.0]:
							var o: Vector2 = sq0 + Vector2(cx, cy) * side
							var dx: float = 1.0 - 2.0 * cx
							var dy: float = 1.0 - 2.0 * cy
							lines.append_array([o, o + Vector2(arm * dx, 0.0), o, o + Vector2(0.0, arm * dy)])
					ci.draw_multiline(lines, Color(acc.r, acc.g, acc.b, b), 1.5 * u)
				ci.draw_string(font, at + Vector2(12.0 * u, -1.0 * u), "CONTACT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, Color(red.r, red.g, red.b, a))
				ci.draw_string(font, at + Vector2(12.0 * u, fs + 1.0 * u), _grid_ref(g), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, ink)
			Tact.UNIT:
				var blue := Defs.TEAM_COLORS[0] as Color
				var dir := Vector2(cos(float(ev[3])), sin(float(ev[3])))
				var now := ((g + dir * 0.045 * UiFx.in_out((age - 0.6) / (TACT_LIFE - 2.0)) - cam) * zoom + lean) * hgt + mid
				if at.distance_to(now) > 2.0 * u:
					ci.draw_dashed_line(at, now, Color(blue.r, blue.g, blue.b, a * 0.7), 1.2 * u, 4.0 * u)
				var r := Rect2(now - Vector2(8.0, 5.5) * u, Vector2(16.0, 11.0) * u)
				ci.draw_rect(r, Color(blue.r, blue.g, blue.b, a * 0.18))
				ci.draw_rect(r, Color(blue.r, blue.g, blue.b, a), false, 1.5 * u)
				ci.draw_multiline(PackedVector2Array([r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]), Color(blue.r, blue.g, blue.b, a), 1.2 * u)
				ci.draw_string(font, now + Vector2(12.0 * u, 4.0 * u), String(ev[5]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, ink)
			Tact.AXIS:
				# pencilled in as it's planned: the line grows to its objective
				var dir := Vector2(cos(float(ev[3])), sin(float(ev[3])))
				var length: float = ev[4]
				var bend := Vector2(-dir.y, dir.x) * length * 0.18
				var drawn := UiFx.out_cubic((age - 0.2) / 2.4)
				var pen := Color(acc.r, acc.g, acc.b, a)
				var pts := PackedVector2Array()
				for i in 19:
					var t := drawn * float(i) / 18.0
					var q := g + dir * length * t + bend * 4.0 * t * (1.0 - t)
					pts.append(((q - cam) * zoom + lean) * hgt + mid)
				if drawn > 0.02:
					ci.draw_polyline(pts, pen, 2.0 * u, true)
				if drawn > 0.97:
					var tip := pts[pts.size() - 1]
					var back := (pts[pts.size() - 3] - tip).normalized() * 10.0 * u
					ci.draw_polyline(PackedVector2Array([tip + back.rotated(0.45), tip, tip + back.rotated(-0.45)]), pen, 2.0 * u, true)
					# the objective it's aimed at, ringed and named
					var obj := ((g + dir * length * 1.12 - cam) * zoom + lean) * hgt + mid
					for i in 8:
						var a0 := float(i) / 8.0 * TAU
						ci.draw_arc(obj, 13.0 * u, a0, a0 + TAU / 16.0, 6, pen, 1.5 * u, true)
					ci.draw_string(font, obj + Vector2(17.0 * u, 4.0 * u), String(ev[5]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, pen)


## The lettering: the grid's numbers in the margins, the heights along the
## index contours and the spot heights, in the map's own ink.
func _draw_ink(ci: Control) -> void:
	var vs := size
	var hgt := maxf(vs.y, 1.0)
	var aspect := vs.x / hgt
	var u := hgt / 1080.0
	var lean := _lean(aspect)
	var cam := camera()
	var font := UiKit.font(500)
	var fs := maxi(9, roundi(11.0 * u))
	var gs := maxi(9, roundi(12.0 * u))
	var cap := fs * 0.36
	var mid := vs * 0.5
	# the grid's numbers: eastings along the top and bottom, northings up the sides
	var wx := (Vector2(-aspect * 0.5, aspect * 0.5) - Vector2(lean.x, lean.x)) / zoom + Vector2(cam.x, cam.x)
	for i in range(floori(wx.x * GRID) - 1, ceili(wx.y * GRID) + 2):
		var x := ((float(i) / GRID - cam.x) * zoom + lean.x) * hgt + mid.x
		if x < 4.0 * u or x > vs.x - 24.0 * u:
			continue
		var s := "%02d" % posmod(EASTING + i, 100)
		var p := Vector2(x, 0.0) - mid
		ci.draw_string(font, Vector2(x + 3.0 * u, 12.0 * u + gs * 0.72), s, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, _ink_colour(Vector2(p.x / hgt, -0.47), aspect, lean, 0.0, 1.8))
		ci.draw_string(font, Vector2(x + 3.0 * u, vs.y - 12.0 * u), s, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, _ink_colour(Vector2(p.x / hgt, 0.47), aspect, lean, 0.0, 1.8))
	var wy := (Vector2(-0.5, 0.5) - Vector2(lean.y, lean.y)) / zoom + Vector2(cam.y, cam.y)
	for j in range(floori(wy.x * GRID) - 1, ceili(wy.y * GRID) + 2):
		var y := ((float(j) / GRID - cam.y) * zoom + lean.y) * hgt + mid.y
		if y < 30.0 * u or y > vs.y - 8.0 * u:
			continue
		var s := "%02d" % posmod(NORTHING - j, 100)
		var py := (y - mid.y) / hgt
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
		ci.draw_string(font, Vector2(13.0 * u, y - 3.0 * u), s, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, _ink_colour(Vector2(-aspect * 0.5 + 0.02, py), aspect, lean, 0.0, 1.8))
		ci.draw_string(font, Vector2(vs.x - 13.0 * u - w, y - 3.0 * u), s, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, _ink_colour(Vector2(aspect * 0.5 - 0.02, py), aspect, lean, 0.0, 1.8))
	# the heights: along the index contours (upright, the line broken under
	# them) and beside a dot on each summit
	for mk: Mark in _marks:
		if mk.a <= 0.0:
			continue
		var p := (mk.at - cam) * zoom + lean
		var at := p * hgt + mid
		if at.x < -40.0 or at.y < -20.0 or at.x > vs.x + 40.0 or at.y > vs.y + 20.0:
			continue
		var h := (float(mk.level) - _clock * TopoSurvey.CREEP) / TopoSurvey.LEVELS
		var col := _ink_colour(p, aspect, lean, h)
		col.a = _shown(mk, p, aspect)
		if col.a <= 0.01:
			continue
		if mk.spot:
			ci.draw_circle(at, 1.6 * u, col, true, -1.0, true)
			ci.draw_string(font, at + Vector2(4.0 * u, cap), mk.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		else:
			var w := font.get_string_size(mk.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			ci.draw_set_transform(at, mk.ang)
			ci.draw_string(font, Vector2(-w * 0.5, cap), mk.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			ci.draw_set_transform(Vector2.ZERO)
	if _tactical():
		_draw_tactics(ci, vs, aspect, lean, font, fs)
