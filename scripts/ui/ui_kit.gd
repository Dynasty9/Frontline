class_name UiKit
extends RefCounted
## Shared look for every screen: Signal (docs/UI.md). The interface is a battle
## management display laid straight onto the scene: data on a dark ink or an
## edge scrim, 1 px rules and corner ticks instead of frames, everything square,
## condensed capitals for labels and names, monospace for every figure and
## code, one accent colour for what's selected, active or primary. Fonts,
## colours, the shared Theme and the small drawn parts all live here.

## The interface's themes (Settings > Interface). Each sets the accent, the
## text's colour (its three strengths are mixed from it), the ink the
## interface sits on, and the six colours the living map's contours turn
## through. The colours that mean something (good, bad, warning, intel) and
## the two sides are the same in all of them. They're named for what a soldier
## looks at the war through.
const THEMES := {
	"brass": {"name": "Field Brass", "accent": Color(0.96, 0.79, 0.43), "text": Color(0.93, 0.93, 0.89), "ink": Color(0.024, 0.03, 0.028),
		"map": [Color(0.96, 0.79, 0.43), Color(1.0, 0.47, 0.27), Color(0.95, 0.33, 0.52), Color(0.58, 0.45, 1.0), Color(0.32, 0.74, 1.0), Color(0.35, 0.92, 0.68)]},
	"night": {"name": "Night Vision", "accent": Color(0.62, 1.0, 0.48), "text": Color(0.87, 0.96, 0.87), "ink": Color(0.014, 0.03, 0.02),
		"map": [Color(0.55, 1.0, 0.5), Color(0.3, 0.92, 0.66), Color(0.25, 0.8, 0.78), Color(0.6, 1.0, 0.82), Color(0.78, 1.0, 0.4), Color(0.36, 0.86, 0.36)]},
	"thermal": {"name": "Thermal", "accent": Color(1.0, 0.62, 0.26), "text": Color(0.96, 0.92, 0.88), "ink": Color(0.034, 0.02, 0.026),
		"map": [Color(0.48, 0.22, 0.88), Color(0.86, 0.26, 0.66), Color(1.0, 0.3, 0.25), Color(1.0, 0.56, 0.16), Color(1.0, 0.88, 0.42), Color(1.0, 0.42, 0.3)]},
	"arctic": {"name": "Arctic", "accent": Color(0.6, 0.86, 1.0), "text": Color(0.9, 0.94, 0.98), "ink": Color(0.018, 0.026, 0.038),
		"map": [Color(0.32, 0.66, 1.0), Color(0.3, 0.9, 1.0), Color(0.8, 0.93, 1.0), Color(0.56, 0.6, 1.0), Color(0.3, 0.85, 0.85), Color(0.46, 0.62, 0.9)]},
	"dusk": {"name": "Dusk", "accent": Color(0.78, 0.64, 1.0), "text": Color(0.94, 0.92, 0.97), "ink": Color(0.026, 0.02, 0.038),
		"map": [Color(0.62, 0.46, 1.0), Color(0.95, 0.38, 0.6), Color(0.86, 0.36, 0.95), Color(1.0, 0.52, 0.36), Color(0.42, 0.44, 0.96), Color(1.0, 0.62, 0.76)]},
}
const THEME_KEYS := ["brass", "night", "thermal", "arctic", "dusk"]

# The theme's colours, as tokens (docs/UI.md). Not constants, so a theme can
# change them while the game runs; read them when drawing and a new theme
# shows at once.
static var ACCENT := Color(0.96, 0.79, 0.43)  # the signal: selected, active, primary, live
static var TEXT := Color(0.93, 0.93, 0.89)  # fg: names, figures, the active item
static var DIM := Color(0.622, 0.624, 0.597)  # fg-2: codes, values, states
static var FAINT := Color(0.477, 0.48, 0.459)  # fg-3: labels, units, timestamps, the inactive
static var INK := Color(0.024, 0.03, 0.028)  # what the interface sits on
static var PANEL := Color(0.024, 0.03, 0.028, 0.9)  # a list, a dialog or a sheet on flat ink
static var PANEL_SOFT := Color(0.024, 0.03, 0.028, 0.62)  # a lighter ink, under the HUD's lists
static var SCRIM := Color(0.024, 0.03, 0.028, 0.82)  # an edge scrim at its darkest
static var LINE := Color(0.93, 0.93, 0.89, 0.14)  # rule: hairlines under rows, beside headers
static var RULE2 := Color(0.93, 0.93, 0.89, 0.3)  # rule-2: key boxes, field lines, resting ticks
static var theme_key := "brass"
static var theme_rev := 0  # bumps with every new theme (UiFrame redraws its colours from it)
const ON_ACCENT := Color(0.043, 0.047, 0.04)  # text on an accent fill
const GOOD := Color(0.55, 0.92, 0.55)
const BAD := Color(1.0, 0.5, 0.4)
const WARN := Color(1.0, 0.84, 0.45)
const INTEL := Color(0.5, 0.88, 1.0)

# sizes (1080p, before the interface scale)
const ROW_H := 26.0  # a row in the HUD's lists (34 to 36 in menus and dialogs)
const TICK_ARM := 7.0  # how far a corner tick runs along each edge
const TICK_GAP := 6.0  # how far ticks stand off what they mark

static var _fonts := {}
static var _theme: Theme


static func theme_names() -> Array:
	var out := []
	for k in THEME_KEYS:
		out.append(String(THEMES[k].name))
	return out


## The tokens a theme's three colours make: the text's strengths are mixed
## toward the ink (opaque, so they read the same over any scene), the rules
## are the text at low alpha, the panels and scrims the ink.
static func tokens(th: Dictionary) -> Dictionary:
	var text: Color = th.text
	var ink: Color = th.ink
	return {"accent": th.accent, "text": text, "dim": ink.lerp(text, 0.66), "faint": ink.lerp(text, 0.5), "ink": ink,
		"panel": Color(ink.r, ink.g, ink.b, 0.9), "soft": Color(ink.r, ink.g, ink.b, 0.62), "scrim": Color(ink.r, ink.g, ink.b, 0.82),
		"line": Color(text.r, text.g, text.b, 0.14), "rule2": Color(text.r, text.g, text.b, 0.3)}


## Switch the interface to a theme. Everything drawn each frame picks it up at
## once; the shared theme's styles are rebuilt in place; and what's already
## built (colour overrides, style boxes and colour rects carrying the old
## theme's colours) is recoloured, so no screen has to be rebuilt.
static func apply_theme(key: String, tree: SceneTree) -> void:
	if not THEMES.has(key) or key == theme_key:
		return
	var th: Dictionary = THEMES[key]
	var n := tokens(th)
	# (the ink's family all share one colour: told apart by alpha, the
	# exact ones first, then any other alpha of the ink keeping its own)
	var pairs := [
		[ACCENT, n.accent, false], [ACCENT.lightened(0.15), (n.accent as Color).lightened(0.15), false],
		[ACCENT.lightened(0.25), (n.accent as Color).lightened(0.25), false],
		[PANEL, n.panel, true], [PANEL_SOFT, n.soft, true], [SCRIM, n.scrim, true], [INK, n.ink, false],
		[LINE, n.line, true], [RULE2, n.rule2, true], [TEXT, n.text, false], [DIM, n.dim, false], [FAINT, n.faint, false],
	]
	ACCENT = n.accent
	TEXT = n.text
	DIM = n.dim
	FAINT = n.faint
	INK = n.ink
	PANEL = n.panel
	PANEL_SOFT = n.soft
	SCRIM = n.scrim
	LINE = n.line
	RULE2 = n.rule2
	theme_key = key
	theme_rev += 1
	_boxes.clear()
	_icons.clear()
	if _theme:
		_style(_theme)
	TopoBackdrop.set_palette(th.map)
	if tree and tree.root:
		_recolour(tree.root, pairs, {})


const _COLOUR_SLOTS := ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "default_color", "font_outline_color", "font_uneditable_color", "font_placeholder_color"]
const _STYLE_SLOTS := ["panel", "normal", "hover", "pressed", "hover_pressed", "disabled", "focus", "separator", "slider", "grabber_area", "grabber_area_highlight", "fill", "background", "read_only"]


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


## The ink at a strength (k scales its colour, alpha its opacity): the
## gradients the big screens used, now flat.
static func panel_shade(_k: float, alpha: float) -> Color:
	return Color(INK.r, INK.g, INK.b, alpha)


## The ink washed with the accent (a selected row's fill, k the accent's share).
static func tint(k: float, alpha := 0.95) -> Color:
	var c := INK.lerp(ACCENT, k)
	return Color(c.r, c.g, c.b, alpha)


## A colour at a share of its alpha.
static func fa(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


## The panel frame (UiFrame): flat ink and corner ticks; no border, no glow
## (`glow` is kept for the callers that pass it). `arm` is the ticks' reach;
## frame_hot() gives the accent's ticks, for a dialog or a selected region.
static func frame(bg := Color(-1, 0, 0), pad := 10.0, glow := 0.0, arm := TICK_ARM, opacity := -1.0) -> UiFrame:
	var f := UiFrame.new()
	f.bg = bg
	f.glow = glow
	f.arm = arm
	f.opacity = opacity
	f.set_content_margin_all(pad)
	return f


static func frame_hot(pad := 16.0, opacity := 0.94) -> UiFrame:
	var f := frame(Color(-1, 0, 0), pad, 0.0, TICK_ARM, opacity)
	f.hot = true
	return f


## No frame at all: content on a scrim, with this padding.
static func bare(pad := 0.0) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(pad)
	return sb


# --- type -------------------------------------------------------------------------------------

## Prose: the only sentences (radio messages, tooltips, help, briefings).
## Bahnschrift at its normal width.
static func font(weight := 400) -> Font:
	var k := "p%d" % weight
	if _fonts.has(k):
		return _fonts[k]
	var f := _system(["Bahnschrift", "Segoe UI", "Helvetica Neue", "Arial", "Sans-Serif"], weight)
	_fonts[k] = f
	return f


## The label face: Bahnschrift's SemiCondensed cut, for capitals (labels,
## names, buttons, tabs). `spacing` opens the letters a little (in pixels at
## 1080p; capitals read best spaced).
static func cond(weight := 600, spacing := 1) -> Font:
	var k := "c%d_%d" % [weight, spacing]
	if _fonts.has(k):
		return _fonts[k]
	var base: SystemFont = _fonts.get("c%d" % weight)
	if base == null:
		base = _system(["Bahnschrift SemiCondensed", "Bahnschrift", "DejaVu Sans Condensed", "Liberation Sans Narrow", "Arial Narrow", "Sans-Serif"], weight)
		base.font_stretch = 87
		_fonts["c%d" % weight] = base
	if spacing == 0:
		_fonts[k] = base
		return base
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = spacing
	_fonts[k] = fv
	return fv


## The mono face: every figure, code, time and state.
static func mono(weight := 400) -> Font:
	var k := "m%d" % weight
	if _fonts.has(k):
		return _fonts[k]
	var f := _system(["Cascadia Mono", "Cascadia Code", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "Menlo", "Monaco", "Courier New", "Monospace"], weight)
	_fonts[k] = f
	return f


static func _system(names: Array, weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	# glyphs are rasterised at the size they reach the screen (0: the window's
	# interface scale), so text stays sharp when the interface is scaled up
	f.oversampling = 0.0
	return f


# --- style boxes ---------------------------------------------------------------------------------

static var _boxes := {}


## Shared style box for per-frame drawing (don't modify what it returns).
## Colours are quantised so fading things don't fill the cache.
static func boxc(bg: Color, radius := 0, border := LINE, bw := 1, pad := 8.0, shadow := 0) -> StyleBoxFlat:
	var q := func(c: Color) -> String: return "%d,%d,%d,%d" % [int(c.r * 63.0), int(c.g * 63.0), int(c.b * 63.0), int(c.a * 63.0)]
	var key := "%s|%d|%s|%d|%d|%d" % [q.call(bg), radius, q.call(border), bw, int(pad), shadow]
	var sb: StyleBoxFlat = _boxes.get(key)
	if sb == null:
		if _boxes.size() > 4000:
			_boxes.clear()
		sb = box(Color(int(bg.r * 63.0) / 63.0, int(bg.g * 63.0) / 63.0, int(bg.b * 63.0) / 63.0, int(bg.a * 63.0) / 63.0), radius, border, bw, pad, shadow)
		_boxes[key] = sb
	return sb


## A flat style box. Everything in Signal is square and casts no shadow, so
## `radius` and `shadow` are kept only for the callers that pass them.
static func box(bg: Color, _radius := 0, border := LINE, bw := 1, pad := 8.0, _shadow := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = false
	return sb


## A field: no box, a rule underneath that turns accent when focused.
static func underline(col: Color, pad_x := 2.0, pad_y := 5.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = col
	sb.border_width_bottom = 1
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


# --- the shared Theme ----------------------------------------------------------------------------

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
	t.set_stylebox("panel", "PanelContainer", frame(Color(-1, 0, 0), 12.0))
	t.set_stylebox("panel", "Panel", frame(Color(-1, 0, 0), 12.0))
	# buttons: a square hairline outline, capitals; the cursor turns it accent,
	# pressing or choosing it fills it
	var bn := box(Color(0, 0, 0, 0), 0, RULE2, 1, 0.0)
	_pad(bn, 14.0, 6.0)
	var bh := box(Color(TEXT.r, TEXT.g, TEXT.b, 0.04), 0, ACCENT, 1, 0.0)
	_pad(bh, 14.0, 6.0)
	var bp := box(ACCENT, 0, ACCENT, 1, 0.0)
	_pad(bp, 14.0, 6.0)
	var bd := box(Color(0, 0, 0, 0), 0, LINE, 1, 0.0)
	_pad(bd, 14.0, 6.0)
	var bf := box(Color(0, 0, 0, 0), 0, ACCENT, 1, 0.0)
	bf.draw_center = false
	for cls in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", cls, bn)
		t.set_stylebox("hover", cls, bh)
		t.set_stylebox("pressed", cls, bp)
		t.set_stylebox("hover_pressed", cls, bp)
		t.set_stylebox("disabled", cls, bd)
		t.set_stylebox("focus", cls, bf)
		t.set_font("font", cls, cond(600, 1))
		t.set_font_size("font_size", cls, 13)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, ACCENT)
		t.set_color("font_focus_color", cls, TEXT)
		t.set_color("font_pressed_color", cls, ON_ACCENT)
		t.set_color("font_hover_pressed_color", cls, ON_ACCENT)
		t.set_color("font_disabled_color", cls, FAINT)
		t.set_color("icon_normal_color", cls, DIM)
		t.set_color("icon_hover_color", cls, ACCENT)
		t.set_color("icon_pressed_color", cls, ON_ACCENT)
	t.set_icon("arrow", "OptionButton", _icon("arrow", DIM))
	t.set_constant("arrow_margin", "OptionButton", 8)
	# fields: no box, a mono line of text over a rule that turns accent when focused
	var le := underline(RULE2)
	var lf := underline(ACCENT)
	for cls in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", cls, le)
		t.set_stylebox("focus", cls, lf)
		t.set_stylebox("read_only", cls, underline(LINE))
		t.set_font("font", cls, mono(400))
		t.set_font_size("font_size", cls, 13)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_placeholder_color", cls, FAINT)
		t.set_color("caret_color", cls, ACCENT)
		t.set_color("selection_color", cls, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35))
	t.set_stylebox("panel", "TooltipPanel", frame(Color(INK.r, INK.g, INK.b, 0.97), 8.0))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 13)
	t.set_font("font", "TooltipLabel", font(400))
	t.set_stylebox("panel", "PopupMenu", frame(Color(INK.r, INK.g, INK.b, 0.98), 4.0))
	t.set_stylebox("hover", "PopupMenu", box(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2), 0, Color(0, 0, 0, 0), 0, 4.0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	t.set_font("font", "PopupMenu", cond(600, 1))
	t.set_font_size("font_size", "PopupMenu", 13)
	t.set_icon("radio_checked", "PopupMenu", _icon("check_on", ACCENT))
	t.set_icon("radio_unchecked", "PopupMenu", _icon("check_off", RULE2))
	t.set_icon("checked", "PopupMenu", _icon("check_on", ACCENT))
	t.set_icon("unchecked", "PopupMenu", _icon("check_off", RULE2))
	# ranges: a hairline track filled with the accent and a square grabber
	t.set_stylebox("slider", "HSlider", box(RULE2, 0, Color(0, 0, 0, 0), 0, 1.0))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, 0, Color(0, 0, 0, 0), 0, 1.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, 0, Color(0, 0, 0, 0), 0, 1.0))
	t.set_icon("grabber", "HSlider", _icon("grabber", TEXT))
	t.set_icon("grabber_highlight", "HSlider", _icon("grabber", ACCENT))
	t.set_stylebox("background", "ProgressBar", box(RULE2, 0, Color(0, 0, 0, 0), 0, 0.0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 0, Color(0, 0, 0, 0), 0, 0.0))
	t.set_font("font", "ProgressBar", mono(400))
	t.set_font_size("font_size", "ProgressBar", 11)
	# toggles: a square track with a square knob (CheckButton), a square box (CheckBox)
	for cls in ["CheckButton", "CheckBox"]:
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, TEXT)
		t.set_color("font_pressed_color", cls, TEXT)
		t.set_color("font_hover_pressed_color", cls, TEXT)
		t.set_color("font_focus_color", cls, TEXT)
		t.set_color("font_disabled_color", cls, FAINT)
		t.set_font("font", cls, font(400))
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			t.set_stylebox(st, cls, StyleBoxEmpty.new())
	t.set_icon("checked", "CheckButton", _icon("switch_on", ACCENT))
	t.set_icon("unchecked", "CheckButton", _icon("switch_off", RULE2))
	t.set_icon("checked_disabled", "CheckButton", _icon("switch_on", FAINT))
	t.set_icon("unchecked_disabled", "CheckButton", _icon("switch_off", LINE))
	t.set_icon("checked", "CheckBox", _icon("check_on", ACCENT))
	t.set_icon("unchecked", "CheckBox", _icon("check_off", RULE2))
	t.set_icon("checked_disabled", "CheckBox", _icon("check_on", FAINT))
	t.set_icon("unchecked_disabled", "CheckBox", _icon("check_off", LINE))
	t.set_icon("radio_checked", "CheckBox", _icon("check_on", ACCENT))
	t.set_icon("radio_unchecked", "CheckBox", _icon("check_off", RULE2))
	# scrolling: a thin bar, a rule at rest
	for cls in ["VScrollBar", "HScrollBar"]:
		var track := box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 0.0)
		track.content_margin_left = 2.0
		track.content_margin_right = 2.0
		track.content_margin_top = 2.0
		track.content_margin_bottom = 2.0
		t.set_stylebox("scroll", cls, track)
		t.set_stylebox("scroll_focus", cls, track)
		t.set_stylebox("grabber", cls, box(RULE2, 0, Color(0, 0, 0, 0), 0, 1.0))
		t.set_stylebox("grabber_highlight", cls, box(DIM, 0, Color(0, 0, 0, 0), 0, 1.0))
		t.set_stylebox("grabber_pressed", cls, box(ACCENT, 0, Color(0, 0, 0, 0), 0, 1.0))
	var sep := box(LINE, 0, Color(0, 0, 0, 0), 0, 0.0)
	sep.content_margin_top = 0.5
	sep.content_margin_bottom = 0.5
	t.set_stylebox("separator", "HSeparator", sep)
	var vsep := box(LINE, 0, Color(0, 0, 0, 0), 0, 0.0)
	vsep.content_margin_left = 0.5
	vsep.content_margin_right = 0.5
	t.set_stylebox("separator", "VSeparator", vsep)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("bold_font", "RichTextLabel", cond(600, 0))
	t.set_font("mono_font", "RichTextLabel", mono(400))


static func _pad(sb: StyleBoxFlat, x: float, y: float) -> void:
	sb.content_margin_left = x
	sb.content_margin_right = x
	sb.content_margin_top = y
	sb.content_margin_bottom = y


static var _icons := {}


## The theme's small drawn icons (made once per theme, at 2x for sharpness).
static func _icon(kind: String, col: Color) -> Texture2D:
	var k := "%s|%s" % [kind, col.to_html()]
	if _icons.has(k):
		return _icons[k]
	var img: Image
	match kind:
		"arrow":
			img = Image.create(10, 6, false, Image.FORMAT_RGBA8)
			for y in 6:
				for x in range(y, 10 - y):
					img.set_pixel(x, y, col)
		"grabber":
			img = Image.create(8, 16, false, Image.FORMAT_RGBA8)
			img.fill(col)
		"switch_on", "switch_off":
			img = Image.create(34, 16, false, Image.FORMAT_RGBA8)
			for x in 34:
				img.set_pixel(x, 0, col)
				img.set_pixel(x, 15, col)
			for y in 16:
				img.set_pixel(0, y, col)
				img.set_pixel(33, y, col)
			var x0 := 20 if kind == "switch_on" else 3
			for y in range(3, 13):
				for x in range(x0, x0 + 11):
					img.set_pixel(x, y, col)
		"check_on", "check_off":
			img = Image.create(14, 14, false, Image.FORMAT_RGBA8)
			for i in 14:
				img.set_pixel(i, 0, col)
				img.set_pixel(i, 13, col)
				img.set_pixel(0, i, col)
				img.set_pixel(13, i, col)
			if kind == "check_on":
				for y in range(3, 11):
					for x in range(3, 11):
						img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_icons[k] = tex
	return tex


# --- labels and buttons ---------------------------------------------------------------------------

## Prose (sentence case): descriptions, tips, messages.
static func label(text: String, size := 14, col := TEXT, weight := 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if weight != 400:
		l.add_theme_font_override("font", font(weight))
	return l


## Capitals in the label face: labels (11, faint or dim), names (13+, text),
## buttons and tabs. The text is kept as written and drawn in capitals.
static func caps(text: String, size := 11, col := FAINT, weight := 600, spacing := 1) -> Label:
	var l := Label.new()
	l.text = text
	l.uppercase = true
	l.add_theme_font_override("font", cond(weight, spacing))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## Mono: figures, codes, times, states.
static func mono_label(text: String, size := 12, col := DIM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", mono(400))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## A header: a one-word label, an optional count in mono, and a rule running
## to the end of its column.
static func header(text: String, count := "") -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var l := caps(text, 11, DIM)
	l.name = "Text"
	hb.add_child(l)
	if count != "":
		var c := mono_label(count, 11, FAINT)
		c.name = "Count"
		hb.add_child(c)
	var r := ColorRect.new()
	r.color = LINE
	r.custom_minimum_size = Vector2(8, 1)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(r)
	return hb


## A button of a kind: "secondary" (an outline), "primary" (accent, one per
## screen), "quiet" (text only) or "danger" (bad). The text is drawn in capitals.
static func button(text: String, kind := "secondary", w := 0.0, h := 32.0) -> Button:
	if kind == "primary":
		return primary_button(text, w, h)
	var b := Button.new()
	b.text = text.to_upper()
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	match kind:
		"quiet":
			var q := box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 0.0)
			_pad(q, 4.0, 6.0)
			for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
				b.add_theme_stylebox_override(st, q)
			b.add_theme_color_override("font_color", DIM)
			b.add_theme_color_override("font_hover_color", TEXT)
			b.add_theme_color_override("font_pressed_color", ACCENT)
			b.add_theme_color_override("font_hover_pressed_color", ACCENT)
		"danger":
			var dn := box(Color(0, 0, 0, 0), 0, Color(BAD.r, BAD.g, BAD.b, 0.45), 1, 0.0)
			_pad(dn, 14.0, 6.0)
			var dh := box(Color(BAD.r, BAD.g, BAD.b, 0.12), 0, BAD, 1, 0.0)
			_pad(dh, 14.0, 6.0)
			b.add_theme_stylebox_override("normal", dn)
			b.add_theme_stylebox_override("hover", dh)
			b.add_theme_stylebox_override("pressed", dh)
			b.add_theme_stylebox_override("hover_pressed", dh)
			b.add_theme_color_override("font_color", BAD)
			b.add_theme_color_override("font_hover_color", BAD)
			b.add_theme_color_override("font_pressed_color", BAD)
			b.add_theme_color_override("font_hover_pressed_color", BAD)
	return b


## The accent-filled button for a screen's main action (Deploy, Join, Host).
static func primary_button(text: String, w := 150.0, h := 40.0, size := 14) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", cond(700, 2))
	b.add_theme_font_size_override("font_size", size)
	var n := box(ACCENT, 0, ACCENT, 0, 6.0)
	var hi := box(ACCENT.lightened(0.15), 0, ACCENT, 0, 6.0)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hi)
	b.add_theme_stylebox_override("pressed", hi)
	b.add_theme_stylebox_override("hover_pressed", hi)
	b.add_theme_stylebox_override("disabled", box(Color(0, 0, 0, 0), 0, LINE, 1, 6.0))
	b.add_theme_color_override("font_color", ON_ACCENT)
	b.add_theme_color_override("font_hover_color", ON_ACCENT)
	b.add_theme_color_override("font_pressed_color", ON_ACCENT)
	b.add_theme_color_override("font_hover_pressed_color", ON_ACCENT)
	b.add_theme_color_override("font_disabled_color", FAINT)
	return b


## A small tag (LISTED, HOST, 3/8): capitals in a square hairline of its colour.
static func chip(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(col.r, col.g, col.b, 0.0), 0, Color(col.r, col.g, col.b, 0.45), 1, 0.0)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	var l := caps(text, 10, col, 600, 1)
	l.name = "Text"
	p.add_child(l)
	return p


# --- drawing --------------------------------------------------------------------------------------

## Draws text with a soft dark outline on any CanvasItem (text on the
## battlefield needs it; on ink it's barely there).
static func text(ci: CanvasItem, p: Vector2, s: String, size := 13, col := TEXT, weight := 400, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := font(weight)
	ci.draw_string_outline(f, p, s, align, width, size, 3, Color(0, 0, 0, 0.5 * col.a))
	ci.draw_string(f, p, s, align, width, size, col)


## The same in a given font (cond() for capitals, mono() for codes).
static func text_f(ci: CanvasItem, f: Font, p: Vector2, s: String, size := 12, col := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := true) -> void:
	if outline:
		ci.draw_string_outline(f, p, s, align, width, size, 3, Color(0, 0, 0, 0.5 * col.a))
	ci.draw_string(f, p, s, align, width, size, col)


## Capitals in the label face drawn at a point; returns the width.
static func caps_at(ci: CanvasItem, p: Vector2, t: String, size := 12, col := TEXT, outline := true) -> float:
	var f := cond(600, 1)
	var u := t.to_upper()
	text_f(ci, f, p, u, size, col, HORIZONTAL_ALIGNMENT_LEFT, -1, outline)
	return f.get_string_size(u, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Mono drawn at a point; returns the width.
static func mono_at(ci: CanvasItem, p: Vector2, t: String, size := 12, col := DIM, outline := true) -> float:
	var f := mono(400)
	text_f(ci, f, p, t, size, col, HORIZONTAL_ALIGNMENT_LEFT, -1, outline)
	return f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func caps_w(t: String, size := 12) -> float:
	return cond(600, 1).get_string_size(t.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func mono_w(t: String, size := 12) -> float:
	return mono(400).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Four corner ticks round a rect, `gap` outside it.
static func ticks(ci: CanvasItem, r: Rect2, col: Color, arm := TICK_ARM, gap := TICK_GAP, w := 1.0) -> void:
	var a := r.grow(gap)
	var p0 := a.position
	var p1 := a.end
	var pts := PackedVector2Array([
		p0, p0 + Vector2(arm, 0), p0, p0 + Vector2(0, arm),
		Vector2(p1.x, p0.y), Vector2(p1.x - arm, p0.y), Vector2(p1.x, p0.y), Vector2(p1.x, p0.y + arm),
		Vector2(p0.x, p1.y), Vector2(p0.x + arm, p1.y), Vector2(p0.x, p1.y), Vector2(p0.x, p1.y - arm),
		p1, p1 - Vector2(arm, 0), p1, p1 - Vector2(0, arm)])
	ci.draw_multiline(pts, col, w)


## Strength in pips: one 3 x 9 block per man, alive, wounded, lost. Returns the width.
static func pips(ci: CanvasItem, p: Vector2, alive: int, hurt := 0, lost := 0, h := 9.0, a := 1.0) -> float:
	var x := p.x
	for i in alive + hurt + lost:
		var c := TEXT if i < alive else (WARN if i < alive + hurt else RULE2)
		ci.draw_rect(Rect2(x, p.y, 3.0, h), fa(c, a))
		x += 5.0
	return maxf(0.0, x - p.x - 2.0)


## A counted bar: `total` steps, `filled` of them in the colour. Returns the width.
static func steps(ci: CanvasItem, p: Vector2, filled: float, total: int, col := ACCENT, sw := 7.0, h := 12.0, a := 1.0) -> float:
	var x := p.x
	for i in total:
		ci.draw_rect(Rect2(x, p.y, sw, h), fa(col if float(i) < filled - 0.001 else RULE2, a))
		x += sw + 2.0
	return x - p.x - 2.0


## A key in its box: a mono letter in a hairline square, filled with the
## accent when it's the active one. Returns the width.
static func key(ci: CanvasItem, p: Vector2, k: String, active := false, size := 10, a := 1.0) -> float:
	var f := mono(400)
	var tw := f.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var r := Rect2(p, Vector2(maxf(tw + 8.0, size + 4.0), size + 5.0))
	if active:
		ci.draw_rect(r, fa(ACCENT, a))
	else:
		ci.draw_rect(r, fa(RULE2, a), false, 1.0)
	ci.draw_string(f, Vector2(r.position.x + (r.size.x - tw) * 0.5, r.end.y - 4.0), k, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fa(ON_ACCENT if active else DIM, a))
	return r.size.x


## A hairline.
static func rule(ci: CanvasItem, a: Vector2, b: Vector2, col := LINE) -> void:
	ci.draw_line(a, b, col, 1.0)


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


## A square tag drawn on a canvas (once a pill: Signal has none).
static func pill(ci: CanvasItem, r: Rect2, bg := PANEL, border := LINE) -> void:
	ci.draw_style_box(boxc(bg, 0, border, 1, 0.0), r)
