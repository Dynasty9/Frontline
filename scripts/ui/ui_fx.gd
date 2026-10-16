class_name UiFx
extends RefCounted
## Motion and finish for the stats screens and the end of a battle: easing
## curves, and the drawing that gives them their look - cut-cornered glass
## panels with corner brackets, glowing bars, dials, a shine that sweeps over
## a card once, and the insignia on the honours. All of it is drawn, nothing
## is imported.

# --- easing ----------------------------------------------------------------------------------

static func out_cubic(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


static func out_expo(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 if t >= 1.0 else 1.0 - pow(2.0, -10.0 * t)


## Overshoots a little and settles: things that land.
static func out_back(t: float, s := 1.70158) -> float:
	t = clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + (s + 1.0) * t * t * t + s * t * t


static func in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## 0 until `start`, rising to 1 over `dur` (seconds of t).
static func span(t: float, start: float, dur: float) -> float:
	return clampf((t - start) / maxf(0.001, dur), 0.0, 1.0)


# --- type ----------------------------------------------------------------------------------------

static var _fonts := {}


## Letter-spaced capitals for headings and labels.
static func spaced(weight := 700, spacing := 2) -> Font:
	var k := "s%d_%d" % [weight, spacing]
	if not _fonts.has(k):
		var fv := FontVariation.new()
		fv.base_font = UiKit.font(weight)
		fv.spacing_glyph = spacing
		_fonts[k] = fv
	return _fonts[k]


## The figures: a condensed face where the system has one (Bahnschrift's
## SemiCondensed on Windows), so big numbers read like a scoreboard.
static func digits(weight := 700) -> Font:
	var k := "d%d" % weight
	if not _fonts.has(k):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift SemiCondensed", "Bahnschrift Condensed", "Bahnschrift", "Segoe UI", "Arial Narrow", "Sans-Serif"])
		f.font_weight = weight
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.oversampling = 0.0
		_fonts[k] = f
	return _fonts[k]


static func width(f: Font, s: String, size: int) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


# --- panels ----------------------------------------------------------------------------------

## The outline of a panel with its top-left and bottom-right corners cut.
static func chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y - cut),
		Vector2(r.end.x - cut, r.end.y), Vector2(r.position.x, r.end.y), r.position + Vector2(0, cut)])


static var _grain: ImageTexture


## A faint diagonal weave laid over the glass (one small texture, tiled).
static func grain() -> Texture2D:
	if _grain == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		for y in 8:
			for x in 8:
				var on := (x + y) % 8 == 0
				img.set_pixel(x, y, Color(1, 1, 1, 0.55 if on else 0.0))
		_grain = ImageTexture.create_from_image(img)
	return _grain


## Glass: darker at the foot, a hairline edge, the weave, and accent brackets
## at the two square corners. a fades all of it.
static func panel(ci: CanvasItem, r: Rect2, a := 1.0, cut := 16.0, top := Color(0.06, 0.075, 0.07, 0.95), bot := Color(0.025, 0.03, 0.03, 0.97), accent := UiKit.ACCENT) -> void:
	if r.size.x < cut * 2.0 or r.size.y < cut * 2.0 or a <= 0.0:
		return
	var pts := chamfer(r, cut)
	var cols := PackedColorArray()
	for p in pts:
		var k := (p.y - r.position.y) / r.size.y
		cols.append(fade(top.lerp(bot, k), a))
	ci.draw_polygon(pts, cols)
	ci.draw_texture_rect(grain(), r.grow(-2.0), true, Color(1, 1, 1, 0.022 * a))
	var edge := pts.duplicate()
	edge.append(pts[0])
	ci.draw_polyline(edge, Color(1, 1, 1, 0.09 * a), 1.0, true)
	# the cut corners take a short accent stroke along the bevel
	ci.draw_line(pts[5], pts[0], fade(accent, 0.55 * a), 2.0, true)
	ci.draw_line(pts[2], pts[3], fade(accent, 0.35 * a), 2.0, true)
	bracket(ci, Vector2(r.end.x, r.position.y), Vector2(-1, 1), 14.0, fade(accent, 0.75 * a))
	bracket(ci, Vector2(r.position.x, r.end.y), Vector2(1, -1), 14.0, fade(accent, 0.75 * a))


## An L at a corner: `dir` points into the panel.
static func bracket(ci: CanvasItem, corner: Vector2, dir: Vector2, l: float, col: Color, w := 2.0) -> void:
	ci.draw_line(corner, corner + Vector2(dir.x * l, 0), col, w)
	ci.draw_line(corner, corner + Vector2(0, dir.y * l), col, w)


## A smaller card, the same make.
static func card(ci: CanvasItem, r: Rect2, a := 1.0, hot := 0.0, edge := Color(1, 1, 1, 0.08)) -> void:
	var pts := chamfer(r, 8.0)
	var cols := PackedColorArray()
	for p in pts:
		var k := (p.y - r.position.y) / r.size.y
		cols.append(fade(Color(0.1, 0.115, 0.11, 0.78 + 0.12 * hot).lerp(Color(0.05, 0.06, 0.058, 0.85), k), a))
	ci.draw_polygon(pts, cols)
	var e := pts.duplicate()
	e.append(pts[0])
	ci.draw_polyline(e, fade(edge.lerp(Color(1, 1, 1, 0.2), hot), a), 1.0, true)


## A bar with a lit head: the track, the fill to frac, a soft bloom round
## the leading edge while it is still moving (live > 0).
static func bar(ci: CanvasItem, r: Rect2, frac: float, col: Color, a := 1.0, live := 0.0) -> void:
	ci.draw_rect(r, Color(1, 1, 1, 0.07 * a))
	frac = clampf(frac, 0.0, 1.0)
	if frac <= 0.0:
		return
	var f := Rect2(r.position, Vector2(r.size.x * frac, r.size.y))
	ci.draw_rect(f, fade(col, 0.9 * a))
	ci.draw_rect(Rect2(f.position, Vector2(f.size.x, maxf(1.0, r.size.y * 0.35))), Color(1, 1, 1, 0.18 * a))
	var hx := f.end.x
	ci.draw_rect(Rect2(hx - 2.0, r.position.y - 1.0, 2.0, r.size.y + 2.0), Color(1, 1, 1, (0.35 + 0.5 * live) * a))
	if live > 0.0:
		ci.draw_rect(Rect2(hx - 10.0, r.position.y - 3.0, 12.0, r.size.y + 6.0), fade(col.lightened(0.4), 0.22 * live * a))


## A dial: the ring, its fill clockwise from the top, a bright head.
static func ring(ci: CanvasItem, c: Vector2, rad: float, w: float, frac: float, col: Color, a := 1.0) -> void:
	ci.draw_arc(c, rad, 0.0, TAU, 64, Color(1, 1, 1, 0.08 * a), w, true)
	frac = clampf(frac, 0.0, 1.0)
	if frac <= 0.001:
		return
	var a0 := -PI * 0.5
	var a1 := a0 + TAU * frac
	ci.draw_arc(c, rad, a0, a1, maxi(8, int(64 * frac)), fade(col, 0.95 * a), w, true)
	ci.draw_arc(c, rad + w * 0.5 + 2.0, a0, a1, maxi(8, int(64 * frac)), fade(col, 0.18 * a), 2.0, true)
	var head := c + Vector2(cos(a1), sin(a1)) * rad
	ci.draw_circle(head, w * 0.75, Color(1, 1, 1, 0.85 * a))


## A band of light that crosses r once as t goes 0 to 1 (a card landing).
static func shine(ci: CanvasItem, r: Rect2, t: float, a := 1.0) -> void:
	if t <= 0.0 or t >= 1.0:
		return
	var skew := r.size.y * 0.6
	var bw := 46.0
	var x := lerpf(r.position.x - bw - skew, r.end.x + bw, out_cubic(t))
	var top := r.position.y
	var bot := r.end.y
	var k := sin(t * PI) * 0.22 * a
	var clear := Color(1, 1, 1, 0.0)
	var lit := Color(1, 1, 1, k)
	var xs := [x, x + bw * 0.5, x + bw]
	var pts := PackedVector2Array()
	for i in 3:
		pts.append(Vector2(clampf(float(xs[i]) + skew, r.position.x, r.end.x), top))
	for i in range(2, -1, -1):
		pts.append(Vector2(clampf(float(xs[i]), r.position.x, r.end.x), bot))
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	ci.draw_polygon(pts, PackedColorArray([clear, lit, clear, clear, lit, clear]))


# --- insignia ------------------------------------------------------------------------------

## A hexagonal badge with an emblem in it, for the honours.
static func insignia(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color, a := 1.0) -> void:
	var hexa := PackedVector2Array()
	for i in 6:
		var an := PI / 6.0 + i * TAU / 6.0
		hexa.append(c + Vector2(cos(an), sin(an)) * s)
	var cols := PackedColorArray()
	for p in hexa:
		cols.append(fade(col.darkened(0.55).lerp(col.darkened(0.8), (p.y - c.y + s) / (2.0 * s)), 0.95 * a))
	ci.draw_polygon(hexa, cols)
	var e := hexa.duplicate()
	e.append(hexa[0])
	ci.draw_polyline(e, fade(col, 0.9 * a), 2.0, true)
	var inner := PackedVector2Array()
	for i in 7:
		var an2 := PI / 6.0 + i * TAU / 6.0
		inner.append(c + Vector2(cos(an2), sin(an2)) * s * 0.82)
	ci.draw_polyline(inner, fade(col, 0.3 * a), 1.0, true)
	var ic := fade(col.lightened(0.35), a)
	var u := s * 0.42
	match kind:
		"star":
			var st := PackedVector2Array()
			for i in 10:
				var an3 := -PI * 0.5 + i * PI / 5.0
				st.append(c + Vector2(cos(an3), sin(an3)) * (u * 1.25 if i % 2 == 0 else u * 0.52))
			ci.draw_colored_polygon(st, ic)
		"chevrons":
			for i in 3:
				var y := c.y + u * 0.75 - i * u * 0.62
				ci.draw_polyline(PackedVector2Array([Vector2(c.x - u, y), Vector2(c.x, y - u * 0.5), Vector2(c.x + u, y)]), ic, maxf(2.0, s * 0.09), true)
		"reticle":
			ci.draw_arc(c, u * 0.9, 0.0, TAU, 32, ic, maxf(1.5, s * 0.06), true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * u * 0.45, c + d * u * 1.3, ic, maxf(1.5, s * 0.06))
			ci.draw_circle(c, maxf(1.5, s * 0.06), ic)
		"tank":
			ci.draw_rect(Rect2(c.x - u * 1.15, c.y + u * 0.05, u * 2.3, u * 0.6), ic)
			ci.draw_rect(Rect2(c.x - u * 0.55, c.y - u * 0.45, u * 1.0, u * 0.5), ic)
			ci.draw_line(c + Vector2(u * 0.4, -u * 0.25), c + Vector2(u * 1.35, -u * 0.38), ic, maxf(1.5, s * 0.07))
		"flag":
			ci.draw_line(c + Vector2(-u * 0.7, u * 1.1), c + Vector2(-u * 0.7, -u * 1.1), ic, maxf(1.5, s * 0.07))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.7, -u * 1.05), c + Vector2(u * 1.0, -u * 0.6), c + Vector2(-u * 0.7, -u * 0.1)]), ic)
		"cross":
			ci.draw_rect(Rect2(c.x - u * 0.28, c.y - u * 0.95, u * 0.56, u * 1.9), ic)
			ci.draw_rect(Rect2(c.x - u * 0.95, c.y - u * 0.28, u * 1.9, u * 0.56), ic)
		"spade":
			ci.draw_line(c + Vector2(0, -u * 1.15), c + Vector2(0, u * 0.2), ic, maxf(1.5, s * 0.07))
			ci.draw_line(c + Vector2(-u * 0.4, -u * 1.15), c + Vector2(u * 0.4, -u * 1.15), ic, maxf(1.5, s * 0.07))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.55, u * 0.15), c + Vector2(u * 0.55, u * 0.15), c + Vector2(u * 0.4, u * 0.9), c + Vector2(0, u * 1.2), c + Vector2(-u * 0.4, u * 0.9)]), ic)
		"lock":
			ci.draw_arc(c + Vector2(0, -u * 0.25), u * 0.55, PI, TAU, 16, ic, maxf(1.5, s * 0.07), true)
			ci.draw_rect(Rect2(c.x - u * 0.8, c.y - u * 0.25, u * 1.6, u * 1.25), ic)
		_:
			ci.draw_circle(c, u * 0.6, ic)


# --- the same finish and motion for ordinary Controls ------------------------------------------

## Gives a PanelContainer the glass look: its own frame drawn under its
## children, with `pad` round them.
static func glass(c: PanelContainer, cut := 14.0, pad := 18.0) -> void:
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(pad)
	c.add_theme_stylebox_override("panel", sb)
	if not c.has_meta("glass"):
		c.set_meta("glass", true)
		c.draw.connect(func(): panel(c, Rect2(Vector2.ZERO, c.size), 1.0, cut))


## Fades and settles a control into place (a panel opening).
static func pop(c: Control, from_scale := 0.96, dur := 0.22) -> void:
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2(from_scale, from_scale)
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_ignore_time_scale(true)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.7)
	tw.tween_property(c, "scale", Vector2.ONE, dur)


## Slides a control in from dx to where it is, fading up, after `delay`. In
## a container it waits a frame for the container to put it in its place.
static func slide_in(c: Control, dx := 40.0, dur := 0.32, delay := 0.0) -> void:
	c.modulate.a = 0.0
	if c.get_parent() is Container:
		await c.get_tree().process_frame
		if not is_instance_valid(c):
			return
	var x := c.position.x
	c.position.x = x + dx
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_ignore_time_scale(true)
	tw.tween_property(c, "position:x", x, dur).set_delay(delay)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.8).set_delay(delay)


## A label's number counting up to `value`, written by `fmt` (a Callable
## taking the number and returning the text), with a tick as it goes.
static func count(l: Label, value: float, fmt: Callable, dur := 0.9, delay := 0.0) -> void:
	l.text = String(fmt.call(0.0))
	var last := [0]
	var step := func(v: float) -> void:
		l.text = String(fmt.call(v))
		var now := Time.get_ticks_msec()
		if now - int(last[0]) > 55 and v < value:
			last[0] = now
			Sfx.ui("ui_tick", -24.0, randf_range(0.95, 1.08))
	var tw := l.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(delay)
	tw.tween_method(step, 0.0, value, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
