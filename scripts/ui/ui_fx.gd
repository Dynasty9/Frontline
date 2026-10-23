class_name UiFx
extends RefCounted
## Drawing and motion for the screens that draw themselves (the reports, the
## end of a battle), in Signal (docs/UI.md): flat ink and corner ticks, counted
## bars, figures in mono, and motion that arrives fast and exactly. All of it
## is drawn, nothing is imported.

# --- easing ----------------------------------------------------------------------------------

static func out_cubic(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


static func out_expo(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 if t >= 1.0 else 1.0 - pow(2.0, -10.0 * t)


## Once an overshoot ("things that land"); Signal lets nothing overshoot, so
## it arrives exactly (the `s` is kept for the callers that pass it).
static func out_back(t: float, _s := 1.70158) -> float:
	return out_expo(t)


static func in_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## 0 until `start`, rising to 1 over `dur` (seconds of t).
static func span(t: float, start: float, dur: float) -> float:
	return clampf((t - start) / maxf(0.001, dur), 0.0, 1.0)


# --- type ----------------------------------------------------------------------------------------

## Letter-spaced capitals for headings and labels: the label face (the caller
## writes the text in capitals).
static func spaced(weight := 700, spacing := 2) -> Font:
	return UiKit.cond(weight, spacing)


## The figures: mono, so columns of numbers line up and read like a readout.
static func digits(weight := 700) -> Font:
	return UiKit.mono(weight)


static func width(f: Font, s: String, size: int) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


# --- panels ----------------------------------------------------------------------------------

## The outline of a rect (once with two corners cut; Signal is square).
static func chamfer(r: Rect2, _cut: float) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## A sheet: flat ink and corner ticks. `top`'s alpha sets the ink's opacity;
## the other parameters are kept for the callers that pass them.
static func panel(ci: CanvasItem, r: Rect2, a := 1.0, _cut := 16.0, top := UiKit.panel_shade(1.0, 0.92), _bot := Color(), _accent := Color()) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0 or a <= 0.0:
		return
	ci.draw_rect(r, fade(Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, top.a), a))
	UiKit.ticks(ci, r, fade(UiKit.RULE2, a), UiKit.TICK_ARM, UiKit.TICK_GAP * 0.5)


## A corner tick: `dir` points into the region.
static func bracket(ci: CanvasItem, corner: Vector2, dir: Vector2, l: float, col: Color, w := 1.0) -> void:
	ci.draw_line(corner, corner + Vector2(dir.x * l, 0), col, w)
	ci.draw_line(corner, corner + Vector2(0, dir.y * l), col, w)


## A card inside a sheet: a lighter ink and a rule under it; `hot` marks it
## (the selected or the newest) with accent ticks.
static func card(ci: CanvasItem, r: Rect2, a := 1.0, hot := 0.0, _edge := Color()) -> void:
	ci.draw_rect(r, fade(Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, 0.035), a))
	ci.draw_line(Vector2(r.position.x, r.end.y), r.end, fade(UiKit.LINE, a), 1.0)
	if hot > 0.01:
		UiKit.ticks(ci, r, fade(UiKit.ACCENT, a * hot), UiKit.TICK_ARM, 3.0)


## A counted bar: steps across r, filled to frac in the colour. While it's
## still moving (live > 0) the step at its head is drawn bright.
static func bar(ci: CanvasItem, r: Rect2, frac: float, col: Color, a := 1.0, live := 0.0) -> void:
	frac = clampf(frac, 0.0, 1.0)
	var sw := 4.0
	var n := maxi(1, int((r.size.x + 2.0) / (sw + 2.0)))
	sw = (r.size.x - 2.0 * (n - 1)) / n
	var filled := frac * n
	for i in n:
		var x := r.position.x + i * (sw + 2.0)
		var c := col if float(i) < filled - 0.001 else UiKit.RULE2
		if live > 0.0 and i == int(filled) - 1:
			c = c.lightened(0.35 * live)
		ci.draw_rect(Rect2(x, r.position.y, sw, r.size.y), fade(c, a))


## A dial: the ring as a hairline, its fill clockwise from the top.
static func ring(ci: CanvasItem, c: Vector2, rad: float, w: float, frac: float, col: Color, a := 1.0) -> void:
	ci.draw_arc(c, rad, 0.0, TAU, 64, fade(UiKit.RULE2, a), 1.0, true)
	frac = clampf(frac, 0.0, 1.0)
	if frac <= 0.001:
		return
	var a0 := -PI * 0.5
	ci.draw_arc(c, rad, a0, a0 + TAU * frac, maxi(8, int(64 * frac)), fade(col, a), w, true)


## Once a band of light sweeping a card; Signal doesn't glint.
static func shine(_ci: CanvasItem, _r: Rect2, _t: float, _a := 1.0) -> void:
	pass


# --- insignia ------------------------------------------------------------------------------

## A hexagonal badge with an emblem in it, for the honours: a hairline hexagon
## on ink, the emblem in the colour.
static func insignia(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color, a := 1.0) -> void:
	var hexa := PackedVector2Array()
	for i in 6:
		var an := PI / 6.0 + i * TAU / 6.0
		hexa.append(c + Vector2(cos(an), sin(an)) * s)
	ci.draw_colored_polygon(hexa, fade(UiKit.INK, 0.9 * a))
	var e := hexa.duplicate()
	e.append(hexa[0])
	ci.draw_polyline(e, fade(col, 0.9 * a), 1.5, true)
	var ic := fade(col, a)
	var u := s * 0.42
	var lw := maxf(1.5, s * 0.07)
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
			ci.draw_arc(c, u * 0.9, 0.0, TAU, 32, ic, lw, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * u * 0.45, c + d * u * 1.3, ic, lw)
			ci.draw_circle(c, lw, ic)
		"tank":
			ci.draw_rect(Rect2(c.x - u * 1.15, c.y + u * 0.05, u * 2.3, u * 0.6), ic)
			ci.draw_rect(Rect2(c.x - u * 0.55, c.y - u * 0.45, u * 1.0, u * 0.5), ic)
			ci.draw_line(c + Vector2(u * 0.4, -u * 0.25), c + Vector2(u * 1.35, -u * 0.38), ic, lw)
		"flag":
			ci.draw_line(c + Vector2(-u * 0.7, u * 1.1), c + Vector2(-u * 0.7, -u * 1.1), ic, lw)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.7, -u * 1.05), c + Vector2(u * 1.0, -u * 0.6), c + Vector2(-u * 0.7, -u * 0.1)]), ic)
		"cross":
			ci.draw_rect(Rect2(c.x - u * 0.28, c.y - u * 0.95, u * 0.56, u * 1.9), ic)
			ci.draw_rect(Rect2(c.x - u * 0.95, c.y - u * 0.28, u * 1.9, u * 0.56), ic)
		"spade":
			ci.draw_line(c + Vector2(0, -u * 1.15), c + Vector2(0, u * 0.2), ic, lw)
			ci.draw_line(c + Vector2(-u * 0.4, -u * 1.15), c + Vector2(u * 0.4, -u * 1.15), ic, lw)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.55, u * 0.15), c + Vector2(u * 0.55, u * 0.15), c + Vector2(u * 0.4, u * 0.9), c + Vector2(0, u * 1.2), c + Vector2(-u * 0.4, u * 0.9)]), ic)
		"lock":
			ci.draw_arc(c + Vector2(0, -u * 0.25), u * 0.55, PI, TAU, 16, ic, lw, true)
			ci.draw_rect(Rect2(c.x - u * 0.8, c.y - u * 0.25, u * 1.6, u * 1.25), ic)
		_:
			ci.draw_circle(c, u * 0.6, ic)


# --- the same finish and motion for ordinary Controls ------------------------------------------

## Gives a PanelContainer the sheet's look (ink and ticks) with `pad` round its children.
static func glass(c: PanelContainer, _cut := 14.0, pad := 18.0) -> void:
	c.add_theme_stylebox_override("panel", UiKit.frame(Color(-1, 0, 0), pad, 0.0, UiKit.TICK_ARM, 0.92))


## A panel arriving (see UiMotion).
static func pop(c: Control, _from_scale := 0.96, _dur := 0.22) -> void:
	UiMotion.arrive(c, Vector2(0, 1))


## A control arriving from the side it belongs to, after `delay`.
static func slide_in(c: Control, dx := 40.0, _dur := 0.32, delay := 0.0) -> void:
	UiMotion.arrive(c, Vector2(signf(dx) if dx != 0.0 else 1.0, 0), delay)


## A label's number counting up to `value`, written by `fmt` (a Callable
## taking the number and returning the text), with a tick as it goes.
static func count(l: Label, value: float, fmt: Callable, dur := 0.9, delay := 0.0) -> void:
	UiMotion.count(l, value, fmt, dur, delay)
