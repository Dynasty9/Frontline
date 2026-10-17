class_name UiKit
extends RefCounted
## Shared look for every screen: fonts, colours, panel/button styles, theme.

## The interface's themes (Settings > Interface). Each sets the accent, the text,
## the panels and the six colours the living map's contours turn through; the
## colours that mean something (good, bad, warning, intel) are the same in all
## of them. They're named for what a soldier looks at the war through.
const THEMES := {
	"brass": {"name": "Field Brass", "accent": Color(0.96, 0.79, 0.43), "text": Color(0.93, 0.93, 0.89), "dim": Color(0.62, 0.64, 0.58),
		"panel": Color(0.055, 0.065, 0.06, 0.84), "soft": Color(0.04, 0.05, 0.045, 0.6), "line": Color(1, 1, 1, 0.09),
		"map": [Color(0.96, 0.79, 0.43), Color(1.0, 0.47, 0.27), Color(0.95, 0.33, 0.52), Color(0.58, 0.45, 1.0), Color(0.32, 0.74, 1.0), Color(0.35, 0.92, 0.68)]},
	"night": {"name": "Night Vision", "accent": Color(0.62, 1.0, 0.48), "text": Color(0.87, 0.96, 0.87), "dim": Color(0.53, 0.68, 0.55),
		"panel": Color(0.025, 0.055, 0.035, 0.86), "soft": Color(0.02, 0.045, 0.03, 0.62), "line": Color(0.6, 1.0, 0.7, 0.1),
		"map": [Color(0.55, 1.0, 0.5), Color(0.3, 0.92, 0.66), Color(0.25, 0.8, 0.78), Color(0.6, 1.0, 0.82), Color(0.78, 1.0, 0.4), Color(0.36, 0.86, 0.36)]},
	"thermal": {"name": "Thermal", "accent": Color(1.0, 0.62, 0.26), "text": Color(0.96, 0.92, 0.88), "dim": Color(0.7, 0.61, 0.58),
		"panel": Color(0.065, 0.04, 0.05, 0.86), "soft": Color(0.05, 0.03, 0.04, 0.62), "line": Color(1.0, 0.8, 0.7, 0.1),
		"map": [Color(0.48, 0.22, 0.88), Color(0.86, 0.26, 0.66), Color(1.0, 0.3, 0.25), Color(1.0, 0.56, 0.16), Color(1.0, 0.88, 0.42), Color(1.0, 0.42, 0.3)]},
	"arctic": {"name": "Arctic", "accent": Color(0.6, 0.86, 1.0), "text": Color(0.9, 0.94, 0.98), "dim": Color(0.58, 0.66, 0.74),
		"panel": Color(0.035, 0.05, 0.07, 0.86), "soft": Color(0.03, 0.04, 0.06, 0.62), "line": Color(0.7, 0.85, 1.0, 0.1),
		"map": [Color(0.32, 0.66, 1.0), Color(0.3, 0.9, 1.0), Color(0.8, 0.93, 1.0), Color(0.56, 0.6, 1.0), Color(0.3, 0.85, 0.85), Color(0.46, 0.62, 0.9)]},
	"dusk": {"name": "Dusk", "accent": Color(0.78, 0.64, 1.0), "text": Color(0.94, 0.92, 0.97), "dim": Color(0.66, 0.62, 0.72),
		"panel": Color(0.05, 0.04, 0.07, 0.86), "soft": Color(0.04, 0.03, 0.06, 0.62), "line": Color(0.85, 0.75, 1.0, 0.1),
		"map": [Color(0.62, 0.46, 1.0), Color(0.95, 0.38, 0.6), Color(0.86, 0.36, 0.95), Color(1.0, 0.52, 0.36), Color(0.42, 0.44, 0.96), Color(1.0, 0.62, 0.76)]},
}
const THEME_KEYS := ["brass", "night", "thermal", "arctic", "dusk"]

# The theme's colours. Not constants, so a theme can change them while the
# game runs; read them when drawing and a new theme shows at once.
static var ACCENT := Color(0.96, 0.79, 0.43)
static var TEXT := Color(0.93, 0.93, 0.89)
static var DIM := Color(0.62, 0.64, 0.58)
static var PANEL := Color(0.055, 0.065, 0.06, 0.84)
static var PANEL_SOFT := Color(0.04, 0.05, 0.045, 0.6)
static var LINE := Color(1, 1, 1, 0.09)
static var theme_key := "brass"
static var theme_rev := 0  # bumps with every new theme (UiFrame redraws its colours from it)
const GOOD := Color(0.55, 0.92, 0.55)
const BAD := Color(1.0, 0.5, 0.4)
const WARN := Color(1.0, 0.84, 0.45)
const INTEL := Color(0.5, 0.88, 1.0)

static var _fonts := {}
static var _theme: Theme


static func theme_names() -> Array:
	var out := []
	for k in THEME_KEYS:
		out.append(String(THEMES[k].name))
	return out


## Switch the interface to a theme. Everything drawn each frame picks it up at
## once; the shared theme's styles are rebuilt in place; and what's already
## built (colour overrides, style boxes and colour rects carrying the old
## theme's colours) is recoloured, so no screen has to be rebuilt.
static func apply_theme(key: String, tree: SceneTree) -> void:
	if not THEMES.has(key) or key == theme_key:
		return
	var th: Dictionary = THEMES[key]
	var pairs := [
		[ACCENT, th.accent, false], [ACCENT.lightened(0.15), (th.accent as Color).lightened(0.15), false],
		[ACCENT.lightened(0.25), (th.accent as Color).lightened(0.25), false],
		[TEXT, th.text, false], [DIM, th.dim, false], [PANEL, th.panel, false], [PANEL_SOFT, th.soft, false],
		[LINE, th.line, true],
	]
	ACCENT = th.accent
	TEXT = th.text
	DIM = th.dim
	PANEL = th.panel
	PANEL_SOFT = th.soft
	LINE = th.line
	theme_key = key
	theme_rev += 1
	_boxes.clear()
	if _theme:
		_style(_theme)
	TopoBackdrop.set_palette(th.map)
	if tree and tree.root:
		_recolour(tree.root, pairs, {})


const _COLOUR_SLOTS := ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "default_color", "font_outline_color"]
const _STYLE_SLOTS := ["panel", "normal", "hover", "pressed", "hover_pressed", "disabled", "focus", "separator", "slider", "grabber_area", "grabber_area_highlight", "fill", "background"]


static func _recolour(node: Node, pairs: Array, seen: Dictionary) -> void:
	if node is Control:
		var c := node as Control
		for n in _COLOUR_SLOTS:
			if c.has_theme_color_override(n):
				c.add_theme_color_override(n, _swap(c.get_theme_color(n), pairs))
		for n in _STYLE_SLOTS:
			if c.has_theme_stylebox_override(n):
				var sb := c.get_theme_stylebox(n) as StyleBoxFlat
				if sb and not seen.has(sb):
					seen[sb] = true
					sb.bg_color = _swap(sb.bg_color, pairs)
					sb.border_color = _swap(sb.border_color, pairs)
					sb.shadow_color = _swap(sb.shadow_color, pairs)
		if c is ColorRect:
			(c as ColorRect).color = _swap((c as ColorRect).color, pairs)
	if node is CanvasItem:
		(node as CanvasItem).queue_redraw()
	for ch in node.get_children():
		_recolour(ch, pairs, seen)


## The new theme's colour for one of the old theme's (at the alpha it was used at).
static func _swap(c: Color, pairs: Array) -> Color:
	for pr in pairs:
		var o: Color = pr[0]
		if absf(c.r - o.r) + absf(c.g - o.g) + absf(c.b - o.b) < 0.006 and (not pr[2] or absf(c.a - o.a) < 0.005):
			var n: Color = pr[1]
			return Color(n.r, n.g, n.b, n.a if pr[2] else c.a * (n.a / o.a if o.a < 1.0 else 1.0))
	return c


## The theme's panel colour lightened or darkened by k (the glass of the big
## screens: k 1.12 at its head, 0.48 at its foot, as Field Brass had them).
static func panel_shade(k: float, alpha: float) -> Color:
	return Color(PANEL.r * k, PANEL.g * k, PANEL.b * k, alpha)


## A dark colour washed with the accent (pressed buttons, hovered menu rows).
static func tint(k: float, alpha := 0.95) -> Color:
	var c := Color(0.07, 0.075, 0.07).lerp(ACCENT, k)
	return Color(c.r, c.g, c.b, alpha)


## The tactical frame for panels: a dark glass fill, a hairline edge and accent
## brackets on the corners, with a faint glow in the accent round it.
static func frame(bg := Color(-1, 0, 0), pad := 10.0, glow := 1.0, arm := 12.0, opacity := -1.0) -> UiFrame:
	var f := UiFrame.new()
	f.bg = bg
	f.glow = glow
	f.arm = arm
	f.opacity = opacity
	f.set_content_margin_all(pad)
	return f


static func font(weight := 400) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Helvetica Neue", "Arial", "Sans-Serif"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	# glyphs are rasterised at the size they reach the screen (0: the window's
	# interface scale), so text stays sharp when the interface is scaled up
	f.oversampling = 0.0
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
	_style(t)
	_theme = t
	return t


## The theme's styles in the current colours (again when the theme changes:
## every control using the shared theme restyles itself).
static func _style(t: Theme) -> void:
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", frame(Color(-1, 0, 0), 10.0, 1.0))
	t.set_stylebox("panel", "Panel", frame(Color(-1, 0, 0), 10.0, 1.0))
	var bn := box(Color(0.12, 0.13, 0.12, 0.9), 4, Color(1, 1, 1, 0.1), 1, 6.0)
	var bh := box(Color(0.17, 0.18, 0.16, 0.95), 4, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.7), 1, 6.0)
	bh.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.16)  # a soft glow on the button under the cursor
	bh.shadow_size = 7
	var bp := box(tint(0.2), 4, ACCENT, 1, 6.0)
	var bd := box(Color(0.08, 0.08, 0.08, 0.6), 4, Color(1, 1, 1, 0.04), 1, 6.0)
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
	t.set_stylebox("panel", "TooltipPanel", frame(Color(0.03, 0.035, 0.035, 0.96), 8.0, 0.5, 6.0))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	t.set_stylebox("panel", "PopupMenu", frame(Color(0.05, 0.06, 0.06, 0.97), 6.0, 0.6, 7.0))
	t.set_stylebox("hover", "PopupMenu", box(tint(0.2), 3, Color(0, 0, 0, 0), 0, 4.0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_stylebox("slider", "HSlider", box(Color(1, 1, 1, 0.12), 3, Color(0, 0, 0, 0), 0, 2.0))
	t.set_stylebox("grabber_area", "HSlider", box(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.75), 3, Color(0, 0, 0, 0), 0, 2.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, 3, Color(0, 0, 0, 0), 0, 2.0))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color(1, 1, 1))
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", Color(1, 1, 1))
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)


static func label(text: String, size := 14, col := TEXT, weight := 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if weight != 400:
		l.add_theme_font_override("font", font(weight))
	return l


## The accent-filled button for a panel's main action (Deploy, Join, Host).
static func primary_button(text: String, w := 150.0, h := 40.0, size := 15) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", size)
	var hi := box(ACCENT.lightened(0.15), 4, ACCENT, 0, 6.0)
	b.add_theme_stylebox_override("normal", box(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.85), 4, ACCENT, 0, 6.0))
	b.add_theme_stylebox_override("hover", hi)
	b.add_theme_stylebox_override("pressed", hi)
	b.add_theme_stylebox_override("hover_pressed", hi)
	b.add_theme_stylebox_override("disabled", box(Color(0.22, 0.21, 0.17, 0.7), 4, Color(0, 0, 0, 0), 0, 6.0))
	b.add_theme_color_override("font_color", Color(0.08, 0.07, 0.05))
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.04, 0.03))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.04, 0.03))
	b.add_theme_color_override("font_hover_pressed_color", Color(0.05, 0.04, 0.03))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.47))
	return b


## A small rounded tag (LISTED, IN LOBBY, 3 / 8 PLAYERS) in a colour.
static func chip(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(col.r, col.g, col.b, 0.1), 3, Color(col.r, col.g, col.b, 0.45), 1, 0.0)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, 11, col, 700)
	l.name = "Text"
	p.add_child(l)
	return p


## Small caps header used above groups of controls.
static func header(text: String) -> Label:
	var l := label(text.to_upper(), 12, ACCENT, 600)
	l.add_theme_constant_override("outline_size", 0)
	return l


# --- numbers as the reports write them: the after-action report, the end of a
# battle and the menu's service record (kept here, with no game in them, so the
# menu can show the record without compiling the battle's classes)

## A count: 12,480 (or -3).
static func fmt_num(v: float) -> String:
	var n := int(round(v))
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## A length of time: 4:05, or 1:02:09 past the hour.
static func fmt_time(t: float) -> String:
	var s := maxi(0, int(t))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


## A commander's rating (0-100, BattleStats.rating) in a word.
static func rating_word(v: float) -> String:
	if v >= 85.0:
		return "Outstanding"
	if v >= 70.0:
		return "Effective"
	if v >= 55.0:
		return "Capable"
	if v >= 40.0:
		return "Mixed"
	if v >= 25.0:
		return "Costly"
	return "Ineffective"


## And in a colour.
static func rating_col(v: float) -> Color:
	if v >= 70.0:
		return GOOD
	if v >= 55.0:
		return Color(0.8, 0.9, 0.5)
	if v >= 40.0:
		return WARN
	return BAD


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


## Centres a panel on its parent at the size it wants, or as much of that as
## the parent has room for (a big interface scale in a small window), and
## keeps it so as the window changes. Call again to change the size it wants.
static func fit_center(c: Control, want: Vector2, margin := 16.0) -> void:
	c.set_meta("fit_want", want)
	c.set_meta("fit_margin", margin)
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	var p := c.get_parent_control()
	if p and not c.has_meta("fit_hooked"):
		c.set_meta("fit_hooked", true)
		p.resized.connect(func(): _fit(c))
	_fit(c)


static func _fit(c) -> void:
	if not is_instance_valid(c):
		return
	var p: Control = c.get_parent_control()
	var room: Vector2 = (p.size if p else c.get_viewport_rect().size) - Vector2.ONE * float(c.get_meta("fit_margin")) * 2.0
	var want: Vector2 = c.get_meta("fit_want")
	if room.x <= 0.0 or room.y <= 0.0:
		room = want  # not laid out yet: it fits again when it is
	var s := Vector2(minf(want.x, room.x), minf(want.y, room.y))
	c.offset_left = -s.x * 0.5
	c.offset_right = s.x * 0.5
	c.offset_top = -s.y * 0.5
	c.offset_bottom = s.y * 0.5


static func pill(ci: CanvasItem, r: Rect2, bg := PANEL, border := LINE) -> void:
	var sb := boxc(bg, int(minf(r.size.y * 0.5, 10.0)), border, 1, 0.0)
	ci.draw_style_box(sb, r)
