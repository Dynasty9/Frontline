class_name EndBanner
extends Control
## The moment a battle ends, before the after-action report: the battlefield
## drains of colour and goes soft, a band opens across the screen and the
## result slams into it, a glint runs over the letters, your rating fills its
## bar, and then the banner lifts away and the report rises into its place.
## A click, Space, Enter or Esc skips straight to the report.

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
const OUT_AT := 3.5  # when it starts to lift away (later with a rating bar to fill)

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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_last_ms = Time.get_ticks_msec()
	if world and world.cam:
		_cam_d0 = world.cam.target_dist
		_cam_yaw0 = world.cam.yaw


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
	if not _slammed and t >= 0.5:
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
	var c := size * 0.5
	c.y -= size.y * 0.06
	var out := UiFx.span(t, _out_at(), 0.5)
	var lift := UiFx.out_cubic(out) * 60.0
	var fade := 1.0 - UiFx.out_cubic(out)
	draw_set_transform(Vector2(0, -lift))
	# the band opens out from the middle
	var bk := UiFx.out_cubic(UiFx.span(t, 0.22, 0.38))
	var bh := 186.0 if rating < 0.0 else 262.0
	var bw := size.x * bk
	if bw > 2.0:
		var x0 := c.x - bw * 0.5
		var top := c.y - 96.0
		var cols := PackedColorArray()
		var dark := Color(0.02, 0.025, 0.025, 0.82 * fade)
		var clear := Color(0.02, 0.025, 0.025, 0.0)
		var pts := PackedVector2Array([Vector2(x0, top), Vector2(x0 + bw * 0.22, top), Vector2(x0 + bw * 0.78, top), Vector2(x0 + bw, top),
			Vector2(x0 + bw, top + bh), Vector2(x0 + bw * 0.78, top + bh), Vector2(x0 + bw * 0.22, top + bh), Vector2(x0, top + bh)])
		cols = PackedColorArray([clear, dark, dark, clear, clear, dark, dark, clear])
		draw_polygon(pts, cols)
		# hairlines top and bottom, lit in the middle
		var lc := UiFx.fade(accent, 0.75 * fade)
		draw_line(Vector2(c.x - bw * 0.36, top), Vector2(c.x + bw * 0.36, top), lc, 2.0)
		draw_line(Vector2(c.x - bw * 0.36, top + bh), Vector2(c.x + bw * 0.36, top + bh), UiFx.fade(accent, 0.4 * fade), 1.0)
		draw_rect(Rect2(c.x - bw * 0.36, top, bw * 0.72, 18.0), UiFx.fade(accent, 0.06 * fade))
	# the result slams in: from big, overshooting into place
	var hk := UiFx.span(t, 0.4, 0.42)
	if hk > 0.0:
		var hs := lerpf(2.3, 1.0, UiFx.out_back(hk, 1.2))
		var ha := minf(1.0, hk * 4.0) * fade
		var size_h := 96 if headline.length() <= 10 else 64
		var f := UiFx.spaced(700, 14 if headline.length() <= 10 else 8)
		var tw := UiFx.width(f, headline, size_h)
		var base := Vector2(c.x - tw * 0.5, c.y + size_h * 0.32)
		draw_set_transform_matrix(Transform2D(0.0, Vector2(hs, hs), 0.0, Vector2(0, -lift) + c * (1.0 - hs)))
		draw_string_outline(f, base, headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size_h, 26, UiFx.fade(accent, 0.12 * ha))
		draw_string_outline(f, base, headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size_h, 8, Color(0, 0, 0, 0.55 * ha))
		draw_string(f, base, headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size_h, UiFx.fade(accent.lightened(0.25), ha))
		# a flash on impact
		var flash := 1.0 - UiFx.span(t, 0.5, 0.3)
		if hk >= 1.0 and flash > 0.0:
			draw_string(f, base, headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size_h, Color(1, 1, 1, 0.75 * flash * fade))
		draw_set_transform(Vector2(0, -lift))
		# accent strokes run out from either side of it
		var lk := UiFx.out_cubic(UiFx.span(t, 0.62, 0.5))
		if lk > 0.0:
			var gapx := tw * 0.5 + 34.0
			var ll := minf(size.x * 0.5 - gapx - 40.0, 300.0) * lk
			var ly := c.y - 4.0
			draw_rect(Rect2(c.x + gapx, ly, ll, 3.0), UiFx.fade(accent, 0.85 * fade))
			draw_rect(Rect2(c.x - gapx - ll, ly, ll, 3.0), UiFx.fade(accent, 0.85 * fade))
			draw_rect(Rect2(c.x + gapx + ll - 8.0, ly - 3.0, 8.0, 9.0), UiFx.fade(Color.WHITE, 0.6 * fade))
			draw_rect(Rect2(c.x - gapx - ll, ly - 3.0, 8.0, 9.0), UiFx.fade(Color.WHITE, 0.6 * fade))
		# a glint across the letters
		UiFx.shine(self, Rect2(c.x - tw * 0.5 - 30.0, c.y - size_h * 0.55, tw + 60.0, size_h * 1.0), UiFx.span(t, 0.78, 0.7), 1.6 * fade)
	# the line under it
	var sk := UiFx.out_cubic(UiFx.span(t, 0.95, 0.45))
	if sk > 0.0 and sub != "":
		var sf := UiFx.spaced(600, 4)
		draw_string(sf, Vector2(0, c.y + 64.0 + (1.0 - sk) * 10.0), sub.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, UiFx.fade(UiKit.TEXT, 0.85 * sk * fade))
	# your rating fills its bar, and its word lands at the end
	if rating >= 0.0:
		var rk := UiFx.out_cubic(UiFx.span(t, 1.2, 0.35))
		if rk > 0.0:
			var bwid := 440.0
			var bx := c.x - bwid * 0.5
			var by := c.y + 124.0
			var ra := rk * fade
			var fill := UiFx.out_expo(UiFx.span(t, 1.45, 1.1))
			var shown := rating * fill
			var rc := StatsPanel.rating_col(shown)
			draw_string(UiFx.spaced(700, 3), Vector2(bx, by - 10.0), "YOUR RATING", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiFx.fade(UiKit.DIM, ra))
			UiFx.bar(self, Rect2(bx, by, bwid, 10.0), shown / 100.0, rc, ra, 1.0 - fill)
			draw_string(UiFx.digits(700), Vector2(bx + bwid + 16.0, by + 12.0), "%d" % int(round(shown)), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UiFx.fade(rc, ra))
			var wk := UiFx.span(t, 2.55, 0.35)
			if wk > 0.0:
				# the word lands over the end of the bar
				var ws := lerpf(1.7, 1.0, UiFx.out_back(wk))
				var wp := Vector2(bx + bwid, by - 10.0)
				draw_set_transform_matrix(Transform2D(0.0, Vector2(ws, ws), 0.0, Vector2(0, -lift) + wp * (1.0 - ws)))
				draw_string(UiFx.spaced(700, 3), Vector2(bx, by - 10.0), rating_word.to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, bwid, 13, UiFx.fade(rc, minf(1.0, wk * 3.0) * fade))
				draw_set_transform(Vector2(0, -lift))
	if t < _out_at():
		draw_string(UiFx.spaced(600, 2), Vector2(0, size.y - 36.0), "CLICK TO CONTINUE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, UiFx.fade(UiKit.DIM, 0.5 * UiFx.span(t, 1.6, 0.6)))
	draw_set_transform(Vector2.ZERO)


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
