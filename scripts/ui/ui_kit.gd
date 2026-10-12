class_name UiKit
extends RefCounted
## Shared look for every screen: fonts, colours, panel/button styles, theme.

const ACCENT := Color(0.96, 0.79, 0.43)
const TEXT := Color(0.93, 0.93, 0.89)
const DIM := Color(0.62, 0.64, 0.58)
const PANEL := Color(0.055, 0.065, 0.06, 0.84)
const PANEL_SOFT := Color(0.04, 0.05, 0.045, 0.6)
const LINE := Color(1, 1, 1, 0.09)
const GOOD := Color(0.55, 0.92, 0.55)
const BAD := Color(1.0, 0.5, 0.4)
const WARN := Color(1.0, 0.84, 0.45)
const INTEL := Color(0.5, 0.88, 1.0)

static var _fonts := {}
static var _theme: Theme


static func font(weight := 400) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Helvetica Neue", "Arial", "Sans-Serif"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.oversampling = 1.0
	_fonts[weight] = f
	return f


static var _boxes := {}


## Shared style box for per-frame drawing (don't modify what it returns).
## Colours are quantised so fading things don't fill the cache.
static func boxc(bg: Color, radius := 6, border := LINE, bw := 1, pad := 8.0, shadow := 0) -> StyleBoxFlat:
	var q := func(c: Color) -> String: return "%d,%d,%d,%d" % [int(c.r * 63.0), int(c.g * 63.0), int(c.b * 63.0), int(c.a * 63.0)]
	var key := "%s|%d|%s|%d|%d|%d" % [q.call(bg), radius, q.call(border), bw, int(pad), shadow]
	var sb: StyleBoxFlat = _boxes.get(key)
	if sb == null:
		if _boxes.size() > 4000:
			_boxes.clear()
		sb = box(Color(int(bg.r * 63.0) / 63.0, int(bg.g * 63.0) / 63.0, int(bg.b * 63.0) / 63.0, int(bg.a * 63.0) / 63.0), radius, border, bw, pad, shadow)
		_boxes[key] = sb
	return sb


static func box(bg: Color, radius := 6, border := LINE, bw := 1, pad := 8.0, shadow := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_offset = Vector2(0, 2)
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font(400)
	t.default_font_size = 14
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 7, LINE, 1, 10.0, 10))
	t.set_stylebox("panel", "Panel", box(PANEL, 7, LINE, 1, 10.0, 10))
	var bn := box(Color(0.12, 0.13, 0.12, 0.9), 5, Color(1, 1, 1, 0.1), 1, 6.0)
	var bh := box(Color(0.17, 0.18, 0.16, 0.95), 5, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.7), 1, 6.0)
	var bp := box(Color(0.24, 0.22, 0.15, 0.95), 5, ACCENT, 1, 6.0)
	var bd := box(Color(0.08, 0.08, 0.08, 0.6), 5, Color(1, 1, 1, 0.04), 1, 6.0)
	for cls in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", cls, bn)
		t.set_stylebox("hover", cls, bh)
		t.set_stylebox("pressed", cls, bp)
		t.set_stylebox("hover_pressed", cls, bp)
		t.set_stylebox("disabled", cls, bd)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, Color(1, 1, 1))
		t.set_color("font_pressed_color", cls, ACCENT)
		t.set_color("font_disabled_color", cls, Color(0.5, 0.5, 0.48))
	t.set_stylebox("normal", "LineEdit", box(Color(0.03, 0.035, 0.03, 0.9), 5, Color(1, 1, 1, 0.14), 1, 7.0))
	t.set_stylebox("focus", "LineEdit", box(Color(0.03, 0.035, 0.03, 0.9), 5, ACCENT, 1, 7.0))
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.03, 0.035, 0.03, 0.96), 5, Color(1, 1, 1, 0.15), 1, 8.0, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	t.set_stylebox("panel", "PopupMenu", box(Color(0.06, 0.07, 0.065, 0.97), 5, Color(1, 1, 1, 0.12), 1, 6.0, 8))
	t.set_stylebox("hover", "PopupMenu", box(Color(0.24, 0.22, 0.15, 0.95), 3, Color(0, 0, 0, 0), 0, 4.0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.12), 3, Color(0, 0, 0, 0), 0, 2.0))
	t.set_stylebox("grabber_area", "HSlider", box(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.75), 3, Color(0, 0, 0, 0), 0, 2.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, 3, Color(0, 0, 0, 0), 0, 2.0))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color(1, 1, 1))
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", Color(1, 1, 1))
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	_theme = t
	return t


static func label(text: String, size := 14, col := TEXT, weight := 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if weight != 400:
		l.add_theme_font_override("font", font(weight))
	return l


## Small caps header used above groups of controls.
static func header(text: String) -> Label:
	var l := label(text.to_upper(), 12, ACCENT, 600)
	l.add_theme_constant_override("outline_size", 0)
	return l


## Draws text with a soft dark outline on any CanvasItem.
static func text(ci: CanvasItem, p: Vector2, s: String, size := 13, col := TEXT, weight := 400, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := font(weight)
	ci.draw_string_outline(f, p, s, align, width, size, 4, Color(0, 0, 0, 0.55 * col.a))
	ci.draw_string(f, p, s, align, width, size, col)


static var _tw := {}
static var _tw_n := 0


static func text_width(s: String, size := 13, weight := 400) -> float:
	var k := size * 1000 + weight
	var d: Dictionary = _tw.get(k, {})
	if d.is_empty():
		_tw[k] = d
	var w = d.get(s)
	if w == null:
		_tw_n += 1
		if _tw_n > 6000:
			_tw.clear()
			_tw_n = 0
			d = {}
			_tw[k] = d
		w = font(weight).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		d[s] = w
	return w


static func pill(ci: CanvasItem, r: Rect2, bg := PANEL, border := LINE) -> void:
	var sb := boxc(bg, int(minf(r.size.y * 0.5, 10.0)), border, 1, 0.0)
	ci.draw_style_box(sb, r)
