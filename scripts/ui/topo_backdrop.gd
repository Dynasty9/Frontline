class_name TopoBackdrop
extends ColorRect
## The living map behind every screen outside a battle: the title, the menu and
## the loading screen. A topographic survey of ground that slowly folds and
## drifts, its contour lines lit in colours that wander round a palette of
## brass, ember, rose, violet, blue and jade. The ground rises in a hill under
## the cursor and ripples out from a click.
##
## Every copy draws the same picture at the same moment (one shared clock, one
## shared cursor), so one screen can fade into another and only what's in front
## of the map changes.

const SHADER := """
shader_type canvas_item;

uniform float aspect = 1.7778;
uniform float clock = 0.0;
// the intro's wave: where it starts (fraction of the screen) and how long ago
// (negative: not yet; everything it hasn't reached is still the boot splash)
uniform vec2 wake_at = vec2(0.5);
uniform float wake_t = 1000.0;
uniform vec2 mouse = vec2(0.5);
uniform float mouse_on = 0.0;
uniform vec3 taps[4];  // recent clicks: x, y (fraction of the screen), seconds since
uniform float shade = 0.0;  // darkening down the left, under a column of text
uniform float scan = 0.0;  // the loading screen's survey sweep
uniform float zoom = 1.0;  // closing in on the ground (the loading screen)
uniform vec3 quiet = vec3(0.5, 0.5, 0.0);
uniform float grain = 1.0;  // a calm patch behind a title: centre (fraction of the screen), strength

const float LEVELS = 15.0;
const vec3 BG = vec3(0.031, 0.039, 0.043);
const vec3 SLEEP_LINE = vec3(0.105, 0.115, 0.115);
const vec3 BRASS = vec3(0.96, 0.79, 0.43);
const vec3 EMBER = vec3(1.0, 0.47, 0.27);
const vec3 ROSE = vec3(0.95, 0.33, 0.52);
const vec3 VIOLET = vec3(0.58, 0.45, 1.0);
const vec3 INTEL = vec3(0.32, 0.74, 1.0);
const vec3 JADE = vec3(0.35, 0.92, 0.68);

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// gradient noise with a quintic fade, so contour lines bend without kinks
float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
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
		s += a * gnoise(p);
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return s;
}

// a slow wheel of colours (each one held a while, then eased into the next)
vec3 wheel(float x) {
	x = fract(x) * 6.0;
	vec3 c = BRASS;
	c = mix(c, EMBER, smoothstep(0.0, 1.0, x));
	c = mix(c, ROSE, smoothstep(1.0, 2.0, x));
	c = mix(c, VIOLET, smoothstep(2.0, 3.0, x));
	c = mix(c, INTEL, smoothstep(3.0, 4.0, x));
	c = mix(c, JADE, smoothstep(4.0, 5.0, x));
	c = mix(c, BRASS, smoothstep(5.0, 6.0, x));
	return c;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);  // screen heights from the centre
	float px = 1.0 / max(1080.0 * fwidth(uv.y), 1e-4);  // one 1080p pixel, in real pixels
	vec2 mp = (mouse - 0.5) * vec2(aspect, 1.0);
	// the map sits a little deeper than the grid: it shifts against the cursor
	vec2 q = (p - mp * 0.025 * mouse_on) * 2.6 / zoom;

	// the ground: folded by two slow warps, so hills drift, merge and part
	float t = clock;
	vec2 w = vec2(fbm3(q * 0.6 + vec2(0.0, t * 0.011)), fbm3(q * 0.6 + vec2(5.2, 1.3) - vec2(t * 0.009, 0.0)));
	float h = fbm5(q + w * 1.1 + vec2(t * 0.006, -t * 0.004));
	// a hill under the cursor
	vec2 dm = p - mp;
	float md = dot(dm, dm);
	h += mouse_on * 0.34 * exp(-md * 42.0);
	float spot = mouse_on * exp(-md * 10.0);
	// ripples running out from clicks
	float flash = 0.0;
	for (int i = 0; i < 4; i++) {
		float age = taps[i].z;
		if (age < 4.0) {
			float r = length(p - (taps[i].xy - 0.5) * vec2(aspect, 1.0));
			float front = age * 0.55;
			float k = (r - front) * 8.0;
			float fade = exp(-age * 0.95) * smoothstep(0.0, 0.08, age);
			h += 0.09 * fade * sin((r - front) * 34.0) * exp(-k * k);
			flash += fade * exp(-abs(r - front) * 16.0);
		}
	}

	// the intro's wave: behind its front the map is awake
	vec2 wp = (wake_at - 0.5) * vec2(aspect, 1.0);
	float rad = length(p - wp);
	float front = wake_t < 0.0 ? -1.0 : 2.4 * (1.0 - exp(-wake_t * 0.8));
	float awake = smoothstep(front + 0.02, front - 0.22, rad);
	float wf = wake_t < 0.0 ? 0.0 : exp(-abs(rad - front) * 16.0) * exp(-wake_t * 0.8);

	// contour lines: crisp at any size, every fifth one an index contour;
	// the levels creep, so lines slide up and down the slopes
	float lv = h * LEVELS + t * 0.05;
	float fw = max(length(vec2(dFdx(lv), dFdy(lv))), 1e-5);
	float fd = abs(fract(lv + 0.5) - 0.5);
	float dpx = fd / fw;  // pixels to the nearest line
	float idx = step(mod(floor(lv + 0.5), 5.0), 0.5);
	float halfw = mix(0.5, 0.95, idx) * px;
	float crowd = smoothstep(0.5, 0.16, fw * px);  // lines packed tighter than a few pixels blur into mush
	float line = clamp(halfw + 0.5 - dpx, 0.0, 1.0) * crowd;
	// a tight halo, and light pooling wider where the ground is gentle (measured
	// in levels, not pixels, so it's smooth and meets itself between two lines)
	float glow = exp(-dpx / (2.6 * px)) * crowd + exp(-fd * 10.0) * 0.45;

	// the loading screen's survey: a beam sweeping across, lighting what it passes
	float sx = fract(t * 0.14) * (aspect + 0.8) - 0.4;
	float dx = uv.x * aspect - sx;
	float sweep = scan * (exp(-abs(dx) * 40.0) * 1.6 + (dx < 0.0 ? exp(dx * 4.0) * 0.6 : 0.0));

	// colour: the wheel turns over a minute and a half, spread across the screen
	// along a direction that slowly turns, and shifted with height
	vec2 dir = vec2(cos(t * 0.021), sin(t * 0.021));
	vec3 lc = wheel(t / 96.0 + dot(p, dir) * 0.16 + h * 0.1);
	vec3 ic = mix(lc, vec3(1.0), 0.18);
	vec3 col_line = mix(SLEEP_LINE, mix(lc, ic, idx), awake);
	float lift = 1.0 + 2.6 * wf + 1.3 * spot + 3.0 * flash + sweep;
	float li = mix(1.0, mix(0.3, 0.8, idx), awake) * lift;
	float gi = awake * mix(0.1, 0.28, idx) * lift;

	// between the lines: faint terraces, higher ground a touch lighter
	float terrace = (floor(lv) - t * 0.05) / LEVELS;
	vec3 col = BG + lc * awake * (0.012 + 0.03 * smoothstep(-0.5, 0.55, terrace) + 0.03 * spot + 0.05 * wf + 0.07 * flash);
	col += BG * (1.0 - awake) * 0.5 * (1.0 - smoothstep(0.0, 0.9, length(p)));  // the splash's soft centre
	col += col_line * (line * li + glow * gi);
	col += lc * scan * (0.09 * exp(-abs(dx) * 140.0) + 0.025 * exp(-abs(dx) * 18.0));

	// the map grid, fixed to the screen, with a cross at each corner
	vec2 gq = p * 6.0;
	vec2 gfw = max(fwidth(gq), vec2(1e-5));
	vec2 gd = abs(fract(gq + 0.5) - 0.5) / gfw;
	float gline = clamp(0.5 * px + 0.5 - min(gd.x, gd.y), 0.0, 1.0);
	float arm = 7.0 * px;
	float cross = clamp(0.6 * px + 0.5 - min(gd.x, gd.y), 0.0, 1.0) * step(max(gd.x, gd.y), arm);
	vec3 gcol = mix(vec3(0.6, 0.62, 0.6), mix(lc, vec3(1.0), 0.5), awake * 0.5);
	col += gcol * (gline * 0.022 + cross * mix(0.06, 0.16, awake));

	// a vignette, the column of text's shade, and a little grain against banding
	vec2 vu = uv - 0.5;
	col *= 1.0 - 0.9 * dot(vu, vu);
	float sx2 = clamp(uv.x * aspect / 0.75, 0.0, 1.0);
	float dark = sx2 < 0.55 ? mix(0.82, 0.5, sx2 / 0.55) : mix(0.5, 0.0, (sx2 - 0.55) / 0.45);
	col *= 1.0 - dark * shade;
	vec2 dq = (p - (quiet.xy - 0.5) * vec2(aspect, 1.0)) / vec2(0.6, 0.27);
	col *= 1.0 - quiet.z * awake * exp(-dot(dq, dq));
	col += (hash1(FRAGCOORD.xy + fract(t * 7.31) * 113.0) - 0.5) * 0.014 * grain;
	COLOR = vec4(min(col, vec3(1.0)), 1.0);
}
"""

static var _shader: Shader
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

var wake_at := Vector2(0.5, 0.5)
var wake_t := 1000.0
var shade := 0.0
var scan := 0.0
var quiet := Vector3(0.5, 0.5, 0.0)
var zoom := 1.0
var _mat: ShaderMaterial


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0.031, 0.039, 0.043)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	material = _mat
	_push()


## How far the intro's wave has spread, in screen heights, t seconds after it
## went out (as the shader has it).
static func wave_front(t: float) -> float:
	return 2.4 * (1.0 - exp(-t * 0.8))


## The shared clock and cursor, once a frame. The clock runs in real time (not
## a test's --timescale) and from 0 on the first frame drawn, which is the boot
## splash; it advances by at most a tenth of a second, so a long build frame
## doesn't jump the map.
static func _tick(vp: Viewport, delta: float) -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	var dt := 0.0 if _frame < 0 or _held else minf(delta / maxf(Engine.time_scale, 0.001), 0.1)
	_frame = f
	_clock += dt
	if vp and not _pinned:
		var vs := vp.get_visible_rect().size
		var m := vp.get_mouse_position()
		var inside := Rect2(Vector2.ZERO, vs).has_point(m) and DisplayServer.window_is_focused()
		if inside and _moved:
			_mouse_to = m / vs
		_mouse_on = move_toward(_mouse_on, 1.0 if inside and _moved else 0.0, dt * 0.8)
	_mouse = _mouse.lerp(_mouse_to, 1.0 - exp(-dt * 3.5))
	for i in range(_taps.size() - 1, -1, -1):
		if _clock - float(_taps[i][1]) > 4.0:
			_taps.remove_at(i)


## Start the clock that far in (screenshots of later colours).
static func start_at(seconds: float) -> void:
	_clock = seconds


## Stop the clock at a moment (screenshots of the title, and the boot splash).
static func hold(seconds: float) -> void:
	_clock = seconds
	_held = true


## Hold the cursor's hill at a spot (fractions of the screen), for screenshots.
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


func _push() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_mat.set_shader_parameter("clock", _clock)
	_mat.set_shader_parameter("wake_at", wake_at)
	_mat.set_shader_parameter("wake_t", wake_t)
	_mat.set_shader_parameter("mouse", _mouse)
	_mat.set_shader_parameter("mouse_on", _mouse_on)
	_mat.set_shader_parameter("shade", shade)
	_mat.set_shader_parameter("scan", scan)
	_mat.set_shader_parameter("quiet", quiet)
	_mat.set_shader_parameter("zoom", zoom)
	_mat.set_shader_parameter("grain", 0.0 if _held else 1.0)  # a held frame is a still (the boot splash is one: no grain keeps it small)
	var taps := PackedVector3Array()
	for i in 4:
		if i < _taps.size():
			var tp: Vector2 = _taps[i][0]
			taps.append(Vector3(tp.x, tp.y, _clock - float(_taps[i][1])))
		else:
			taps.append(Vector3(0.5, 0.5, 99.0))
	_mat.set_shader_parameter("taps", taps)
