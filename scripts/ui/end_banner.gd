class_name EndBanner
extends Control
## The moment a battle ends, before the after-action report: the battlefield
## drains of colour and goes soft, a band of ink ruled off in the result's
## colour cuts on across the screen, interference runs through it as the
## signal comes in, and the result types on in capitals over a line of what
## happened and the facts in mono (the battle's clock, the objectives met);
## your rating counts up its steps, and then the banner goes and the report
## arrives in its place (docs/UI.md, Motion). A click, Space, Enter or Esc
## skips straight to the report.

signal finished

## The battlefield behind the report: desaturated, blurred, vignetted and
## darkened by `amount` (0-1), tinted by `tint` (a defeat runs red).
const GRADE := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, amount * 2.8).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), amount * 0.78);
	c = mix(c, c * tint.rgb * 1.6, amount * tint.a);
	vec2 d = UV - 0.5;
	float v = smoothstep(0.9, 0.18, length(d * vec2(1.0, 0.85)));
	c *= mix(1.0, 0.28 + 0.72 * v, amount);
	c *= 1.0 - 0.42 * amount;
	COLOR = vec4(c, 1.0);
}
"""
const OUT_AT := 3.5  # when it goes (later with a rating bar to fill)
const BAND_AT := 0.15  # the band cuts on (and flickers once)
const TYPE_AT := 0.5  # the result starts to type on, as it lands
const SUB_AT := 0.95  # the line under it
## The interference as the band comes on: [start, length, where across the
## band (0 its top, 1 its foot), height] of each pass
const NOISE := [[0.17, 0.08, 0.3, 8.0], [0.21, 0.05, 0.78, 3.0], [0.33, 0.06, 0.62, 5.0], [0.5, 0.1, 0.52, 14.0],
	[0.54, 0.05, 0.24, 3.0], [0.72, 0.05, 0.4, 2.0]]

var world: World
var won := true
var headline := "VICTORY"
var sub := ""
var accent := UiKit.GOOD
var rating := -1.0  # the player's own rating (-1: an observer, no bar)
var rating_word := ""
var grade: ColorRect  # stays under the report once the banner has gone
var t := 0.0
var _last_ms := 0
var _done := false
var _slammed := false
var _medal := false
var _tick_ms := 0
var _cam_d0 := -1.0
var _cam_yaw0 := 0.0
var _facts := ""  # the mono line: T+12:40 · OBJECTIVES 3/3


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_last_ms = Time.get_ticks_msec()
	if world and world.cam:
		_cam_d0 = world.cam.target_dist
		_cam_yaw0 = world.cam.yaw
	_facts = _facts_line()


## What the battle came to, as codes: how long it ran (a mission by its own
## clock) and, in a mission, how many of the objectives it had to meet were met.
## The time is left out when the line over it already says it.
func _facts_line() -> String:
	if world == null:
		return ""
	var parts := PackedStringArray()
	var el := world.time
	var info: Dictionary = world.mission_info
	if not info.is_empty():
		el = float(info.get("el", el))
	if not sub.contains(UiKit.fmt_time(el)):
		var s := maxi(0, int(el))
		parts.append("T+%02d:%02d" % [s / 60, s % 60] if s < 3600 else "T+%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60])
	var need := 0
	var met := 0
	for o in info.get("objs", []):
		if not bool(o[7]):  # (the optional ones aren't counted)
			need += 1
			if int(o[2]) == MissionDirector.DONE:
				met += 1
	if need > 0:
		parts.append("OBJECTIVES %d/%d" % [met, need])
	return " · ".join(parts)


func _out_at() -> float:
	return OUT_AT + (0.9 if rating >= 0.0 else 0.0)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		skip()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE, KEY_KP_ENTER]:
		skip()
		get_viewport().set_input_as_handled()


func skip() -> void:
	if t < _out_at():
		t = _out_at()
		if not _slammed:
			_slam()


func _process(_d: float) -> void:
	var now := Time.get_ticks_msec()
	var dt := clampf((now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now
	t += dt
	if grade:
		(grade.material as ShaderMaterial).set_shader_parameter("amount", UiFx.out_cubic(t / 1.3))
	# the camera eases back and drifts round the field while the banner is up
	if world and world.cam and _cam_d0 > 0.0 and t < _out_at() + 0.6:
		var k := UiFx.in_out(t / (_out_at() + 0.6))
		world.cam.target_dist = lerpf(_cam_d0, _cam_d0 * 1.35, k)
		world.cam.yaw = _cam_yaw0 + 0.22 * k
	if not _slammed and t >= TYPE_AT:
		_slam()
	if rating >= 0.0 and t > 1.45 and t < 2.6 and now - _tick_ms > 45:
		_tick_ms = now
		Sfx.ui("ui_tick", -20.0, 0.9 + 0.3 * UiFx.span(t, 1.45, 1.1))
	if rating >= 0.0 and not _medal and t >= 2.55:
		_medal = true
		Sfx.ui("ui_medal", -13.0, 0.9 if not won else 1.0)
	if not _done and t >= _out_at() + 0.15:
		_done = true
		finished.emit()
	if t >= _out_at() + 0.6:
		queue_free()
		return
	queue_redraw()


func _slam() -> void:
	_slammed = true
	Sfx.ui("ui_slam" if won else "ui_slam_low", -4.0)
	if world and world.cam:
		world.cam.shake(0.6 if won else 0.9)


func _draw() -> void:
	var calm := UiMotion.reduced()
	# going: a few pixels up and gone as the report arrives (at once with
	# Reduce motion)
	var go := UiFx.span(t, _out_at(), UiMotion.QUICK)
	if go >= 1.0 or (calm and t >= _out_at()):
		return
	var c := Vector2(size.x * 0.5, size.y * 0.44 - go * UiMotion.TRAVEL_MD * 0.5)
	# the band: ink across the screen, ruled off top and foot in the result's
	# colour; it cuts on and flickers once
	if t < BAND_AT or (not calm and t >= BAND_AT + UiMotion.INSTANT and t < BAND_AT + UiMotion.INSTANT * 2.0):
		return
	var top := c.y - 84.0
	var bh := 206.0 if rating < 0.0 else 262.0
	draw_rect(Rect2(0, top, size.x, bh), UiKit.fa(UiKit.INK, 0.84))
	draw_line(Vector2(0, top + 0.5), Vector2(size.x, top + 0.5), UiKit.fa(accent, 0.7), 1.0)
	draw_line(Vector2(0, top + bh - 0.5), Vector2(size.x, top + bh - 0.5), UiKit.fa(accent, 0.7), 1.0)
	# the result types on in capitals, a square cursor running ahead of it
	var size_h := 96 if headline.length() <= 10 else 64
	var f := UiKit.cond(700, 14 if headline.length() <= 10 else 8)
	var tw := UiFx.width(f, headline, size_h)
	var base := Vector2(c.x - tw * 0.5, c.y + size_h * 0.36)
	var shown := _typed(headline, TYPE_AT, minf(headline.length() * 0.06, 0.5))
	if shown != "":
		draw_string(f, base, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size_h, accent)
	if not calm and t >= TYPE_AT and shown.length() < headline.length():
		var cx := base.x + UiFx.width(f, shown, size_h) + (8.0 if shown != "" else 0.0)
		draw_rect(Rect2(cx, base.y - size_h * 0.7, size_h * 0.42, size_h * 0.7), accent)
	# what happened in capitals, and the facts in mono, typing on under it
	var y := c.y + 66.0
	if sub != "":
		var sf := UiKit.cond(600, 2)
		var su := sub.to_upper()
		UiKit.text_f(self, sf, Vector2(c.x - UiFx.width(sf, su, 15) * 0.5, y), _typed(su, SUB_AT, -1.0), 15, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, false)
		y += 26.0
	if _facts != "":
		var ft := _typed(_facts, SUB_AT + 0.12, -1.0)
		UiKit.mono_at(self, Vector2(c.x - UiKit.mono_w(_facts, 13) * 0.5, y), ft, 13, UiKit.DIM, false)
	# your rating counts up its steps, and its word types on over the end
	if rating >= 0.0 and t >= 1.2:
		var bwid := 440.0
		var bx := c.x - bwid * 0.5
		var by := c.y + 130.0
		var fill := 1.0 if calm else UiFx.out_expo(UiFx.span(t, 1.45, 1.1))
		var val := rating * fill
		var rc := UiKit.rating_col(val)
		UiKit.caps_at(self, Vector2(bx, by - 10.0), "Your rating", 11, UiKit.FAINT, false)
		UiFx.bar(self, Rect2(bx, by, bwid, 10.0), val / 100.0, rc, 1.0, 1.0 - fill)
		UiKit.text_f(self, UiKit.mono(700), Vector2(bx + bwid + 16.0, by + 11.0), "%d" % int(round(val)), 30, rc, HORIZONTAL_ALIGNMENT_LEFT, -1, false)
		var word := rating_word.to_upper()
		var wt := _typed(word, 2.55, -1.0)
		if wt != "":
			UiKit.caps_at(self, Vector2(bx + bwid - UiKit.caps_w(word, 13), by - 10.0), wt, 13, rc, false)
	if t >= 1.6:
		var ct := "Click to continue"
		UiKit.caps_at(self, Vector2(c.x - UiKit.caps_w(ct, 11) * 0.5, size.y - 36.0), ct, 11, UiKit.FAINT, false)
	if not calm:
		_interference(top, bh)


## The first letters of `s`, typing on from `at` over `dur` seconds (-1: the
## interface's own pace; all of it at once with Reduce motion).
func _typed(s: String, at: float, dur: float) -> String:
	if t < at:
		return ""
	if UiMotion.reduced():
		return s
	if dur < 0.0:
		dur = minf(s.length() * UiMotion.TYPE, UiMotion.TYPE_MAX)
	return s.left(ceili(clampf((t - at) / maxf(dur, 0.001), 0.0, 1.0) * s.length()))


## The signal coming in: a few passes of interference across the band, each a
## strip of ink broken by bright runs that change 24 times a second (as the
## map's do, TopoBackdrop), cutting on and off. No glow, nothing eased.
func _interference(top: float, bh: float) -> void:
	var tick := int(t * 24.0)
	for i in NOISE.size():
		var nz: Array = NOISE[i]
		if t < float(nz[0]) or t >= float(nz[0]) + float(nz[1]):
			continue
		var h: float = nz[3]
		var y := top + bh * float(nz[2]) + (_hash(tick * 7 + i) - 0.5) * 16.0
		draw_rect(Rect2(0, y, size.x, h), UiKit.fa(UiKit.INK, 0.92))
		var x := 0.0
		var k := 0
		while x < size.x:
			var w := 4.0 + _hash(tick * 131 + i * 17 + k) * 70.0
			var v := _hash(tick * 71 + i * 29 + k * 3 + 5)
			if v > 0.45:
				var col := accent if v > 0.88 else UiKit.TEXT
				var sh := maxf(1.0, h * (0.3 + 0.7 * _hash(k * 13 + tick)))
				draw_rect(Rect2(x, y + (h - sh) * 0.5, w, sh), UiKit.fa(col, 0.15 + (v - 0.45) * 1.1))
			x += w
			k += 1


## A cheap repeatable 0-1 noise for the interference (the look only; nothing
## in the game hangs on it).
static func _hash(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)


## The grade under everything: one full-screen rect with the shader.
static func make_grade(won_it: bool) -> ColorRect:
	var g := ColorRect.new()
	g.name = "OverGrade"
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_STOP
	var sh := Shader.new()
	sh.code = GRADE
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("amount", 0.0)
	m.set_shader_parameter("tint", Color(0.85, 0.95, 1.0, 0.25) if won_it else Color(1.0, 0.55, 0.45, 0.4))
	g.material = m
	return g
