class_name InsigniaArt
extends RefCounted
## The insignia's art. Every patch, medal and badge is drawn here as SVG from
## a short description (Insignia's catalog), so the game and the website show
## the very same picture: Godot rasterizes the SVG (Image.load_svg_from_string)
## and the website is given the files themselves (--insignia-dump).
##
## A patch is built the way one is embroidered: a field of twill cut to the
## patch's outline, the device (eagle, skull, bolt...) stitched on with a dark
## outline round it, lettering, then the merrowed edge round the whole thing.
## Medals hang from a striped ribbon; badges are bare metal; a ribbon rack is
## the bars a soldier wears in place of the medals.
##
## The picture is 128 x 128. Devices are drawn in a 100 x 100 box (centre
## 50, 50) and placed with a scale. Lettering is a small stroke alphabet,
## since Godot's SVG renderer draws no <text>, so every glyph is a path.

const INK := "#14150f"  # the dark thread round every device and letter
const LIGHT := "#f3eedc"
const OUTLINE := 1.3  # how far the ink shows past a device, in pixels
const BOX := Rect2(8, 8, 112, 112)  # where a patch sits without a tab above it
const TAB_BOX := Rect2(17, 46, 94, 76)  # ... and with one

## Twill colours: the thread a patch is woven in.
const PALETTE := {
	"od": "#4b5427", "odd": "#30361a", "khaki": "#c4b28a", "tan": "#b39a68", "sand": "#d9c79b",
	"black": "#18191a", "white": "#f1ede0", "cream": "#e8dcb6", "grey": "#7d828a", "steel": "#4a535e",
	"red": "#c4232b", "maroon": "#74202c", "orange": "#e07a26", "yellow": "#f2c230", "brown": "#6b4a2b",
	"green": "#2f7e3c", "jungle": "#1e5631", "teal": "#1d6f6f", "lime": "#9cc83a",
	"blue": "#24478f", "navy": "#17264d", "sky": "#5d9bd8", "ultra": "#2b52b8", "purple": "#5b2a86",
	"coalition": "#2f63b8", "rebel": "#b8382c",
}
## Metals, top to bottom: the light catching the rim, the face, the shadow.
const METALS := {
	"gold": ["#fff6c4", "#ebc25a", "#a87420", "#e8b950"],
	"silver": ["#ffffff", "#d4d8dc", "#7c838a", "#c9cdd2"],
	"bronze": ["#f6cf9c", "#c3864a", "#6a3c16", "#b07238"],
}

# the picture being drawn
static var _out := PackedStringArray()
static var _defs := PackedStringArray()
static var _id := "x"
static var _used := {}  # gradient names already defined for this picture


## The SVG for one catalog entry.
static func svg(spec: Dictionary) -> String:
	_out = PackedStringArray()
	_defs = PackedStringArray()
	_id = String(spec.get("id", "x"))
	_used = {}
	match String(spec.get("m", "patch")):
		"medal":
			_medal(spec)
		"rack":
			_rack(spec)
		_:
			_patch(spec)
	var s := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">'
	if not _defs.is_empty():
		s += "<defs>" + "".join(_defs) + "</defs>"
	return s + "".join(_out) + "</svg>"


# --- patches ----------------------------------------------------------------------------

static func _patch(spec: Dictionary) -> void:
	var shape := String(spec.get("s", "circle"))
	var tab: Array = spec.get("tab", [])
	var box: Rect2 = TAB_BOX if not tab.is_empty() else BOX
	if spec.has("box"):
		var b: Array = spec.box
		box = Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))
	var centre := box.get_center() + Vector2(0, 2.0 if shape in ["shield", "pentagon", "arrowhead"] else 0.0)
	if shape != "none":
		var outline := shape_d(shape, box)
		_defs.append('<clipPath id="%s-c"><path d="%s"/></clipPath>' % [_id, outline])
		_out.append('<g clip-path="url(#%s-c)">' % _id)
		_field(spec.get("f", ["plain", "od"]), box, shape)
		_out.append("</g>")
	for c in spec.get("c", []):
		_charge(c, centre)
	for t in spec.get("t", []):
		if String(t[0]) != "scroll":
			_text_item(t, box)
	if shape != "none":
		var outline := shape_d(shape, box)
		_sheen(outline)
		_border(shape, box, String(spec.get("b", "black")), float(spec.get("bw", 6.0)))
	# a scroll is sewn on over the edge
	for t in spec.get("t", []):
		if String(t[0]) == "scroll":
			_text_item(t, box)
	if not tab.is_empty():
		_tab(tab)


## The patch's outline: shape `kind` filling `r`, drawn `ins` inside it (the
## stitching runs just inside the edge).
static func shape_d(kind: String, r: Rect2, ins := 0.0) -> String:
	var x0 := r.position.x + ins
	var y0 := r.position.y + ins
	var x1 := r.end.x - ins
	var y1 := r.end.y - ins
	var w := x1 - x0
	var h := y1 - y0
	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5
	match kind:
		"shield":
			return _d(["M", x0, y0, "L", x1, y0, "L", x1, y0 + h * 0.42, "C", x1, y0 + h * 0.78, cx + w * 0.22, y1 - h * 0.08, cx, y1,
				"C", cx - w * 0.22, y1 - h * 0.08, x0, y0 + h * 0.78, x0, y0 + h * 0.42, "Z"])
		"shield2":
			return _d(["M", x0, y0, "L", x1, y0, "L", x1, y0 + h * 0.5, "A", w * 0.5, h * 0.5, "0 0 1", x0, y0 + h * 0.5, "Z"])
		"arrowhead":
			return _d(["M", cx, y0, "Q", x1 - w * 0.02, y0 + h * 0.52, x1, y1, "Q", cx, y1 - h * 0.17, x0, y1,
				"Q", x0 + w * 0.02, y0 + h * 0.52, cx, y0, "Z"])
		"triangle":
			return _d(["M", cx, y0 + h * 0.04, "L", x1, y1 - h * 0.06, "L", x0, y1 - h * 0.06, "Z"])
		"diamond":
			return _d(["M", cx, y0, "L", x1, cy, "L", cx, y1, "L", x0, cy, "Z"])
		"square", "tab":
			var rr := minf(w, h) * (0.14 if kind == "square" else 0.3)
			return _d(["M", x0 + rr, y0, "L", x1 - rr, y0, "Q", x1, y0, x1, y0 + rr, "L", x1, y1 - rr, "Q", x1, y1, x1 - rr, y1,
				"L", x0 + rr, y1, "Q", x0, y1, x0, y1 - rr, "L", x0, y0 + rr, "Q", x0, y0, x0 + rr, y0, "Z"])
		"octagon":
			var c := minf(w, h) * 0.29
			return _d(["M", x0 + c, y0, "L", x1 - c, y0, "L", x1, y0 + c, "L", x1, y1 - c, "L", x1 - c, y1, "L", x0 + c, y1,
				"L", x0, y1 - c, "L", x0, y0 + c, "Z"])
		"hexagon":
			return _d(["M", cx, y0, "L", x1, y0 + h * 0.25, "L", x1, y0 + h * 0.75, "L", cx, y1, "L", x0, y0 + h * 0.75, "L", x0, y0 + h * 0.25, "Z"])
		"pentagon":
			return _d(["M", x0, y0, "L", x1, y0, "L", x1, y0 + h * 0.6, "L", cx, y1, "L", x0, y0 + h * 0.6, "Z"])
		"tombstone":
			return _d(["M", x0, y1, "L", x0, y0 + w * 0.5, "A", w * 0.5, w * 0.5, "0 0 1", x1, y0 + w * 0.5, "L", x1, y1, "Z"])
		"trapezoid":
			return _d(["M", x0, y0, "L", x1, y0, "L", x1 - w * 0.14, y1, "L", x0 + w * 0.14, y1, "Z"])
		"star":
			var ro := minf(w, h) * 0.54
			return _star_d(cx, cy + h * 0.05, ro, ro * 0.5, 5)
		"spade":
			var m := func(px: float, py: float) -> Vector2: return Vector2(x0 + px * w / 100.0, y0 + py * h / 100.0)
			var p := [m.call(50, 0), m.call(38, 24), m.call(0, 36), m.call(0, 60), m.call(0, 80), m.call(18, 90), m.call(34, 88),
				m.call(40, 87), m.call(44, 84), m.call(46, 81), m.call(42, 100), m.call(58, 100), m.call(54, 81), m.call(56, 84),
				m.call(60, 87), m.call(66, 88), m.call(82, 90), m.call(100, 80), m.call(100, 60), m.call(100, 36), m.call(62, 24)]
			return _d(["M", p[0].x, p[0].y, "C", p[1].x, p[1].y, p[2].x, p[2].y, p[3].x, p[3].y, "C", p[4].x, p[4].y, p[5].x, p[5].y, p[6].x, p[6].y,
				"C", p[7].x, p[7].y, p[8].x, p[8].y, p[9].x, p[9].y, "L", p[10].x, p[10].y, "L", p[11].x, p[11].y, "L", p[12].x, p[12].y,
				"C", p[13].x, p[13].y, p[14].x, p[14].y, p[15].x, p[15].y, "C", p[16].x, p[16].y, p[17].x, p[17].y, p[18].x, p[18].y,
				"C", p[19].x, p[19].y, p[20].x, p[20].y, p[0].x, p[0].y, "Z"])
		_:  # circle, oval
			return _d(["M", x0, cy, "A", w * 0.5, h * 0.5, "0 1 1", x1, cy, "A", w * 0.5, h * 0.5, "0 1 1", x0, cy, "Z"])


## The field, in full-picture coordinates (it is clipped to the outline).
## [kind, colour, colour, (colour)]: how the twill is divided and dyed.
static func _field(f: Array, box: Rect2, shape: String) -> void:
	var kind := String(f[0])
	var c1 := col(f[1])
	var c2 := col(f[2]) if f.size() > 2 else c1
	var c3 := col(f[3]) if f.size() > 3 else c2
	var cx := box.get_center().x
	var cy := box.get_center().y
	_out.append('<rect x="0" y="0" width="128" height="128" fill="%s"/>' % c1)
	match kind:
		"pale":
			_rect(cx, 0, 128, 128, c2)
		"fess":
			_rect(0, cy, 128, 128, c2)
		"bend":
			_fill(_d(["M0 0L128 128L0 128Z"]), c2)
		"sinister":
			_fill(_d(["M128 0L0 128L128 128Z"]), c2)
		"band":
			_fill(_d(["M", -10, 10, "L", 10, -10, "L", 138, 118, "L", 118, 138, "Z"]), c2)
		"quarter":
			_rect(cx, 0, 128, cy, c2)
			_rect(0, cy, cx, 128, c2)
		"chevron":
			_fill(_d(["M", 0, cy + 30, "L", cx, cy - 26, "L", 128, cy + 30, "L", 128, cy + 52, "L", cx, cy - 4, "L", 0, cy + 52, "Z"]), c2)
		"saltire":
			_fill(_d(["M", -6, 8, "L", 8, -6, "L", 134, 120, "L", 120, 134, "Z", "M", 134, 8, "L", 120, -6, "L", -6, 120, "L", 8, 134, "Z"]), c2)
		"cross":
			_rect(cx - 11, 0, 22, 128, c2)
			_rect(0, cy - 11, 128, 22, c2)
		"rays":
			var n := 18
			var parts := PackedStringArray()
			for i in n:
				if i % 2 == 0:
					continue
				var a0 := TAU * i / n
				var a1 := TAU * (i + 1) / n
				parts.append(_d(["M", cx, cy, "L", cx + cos(a0) * 120, cy + sin(a0) * 120, "L", cx + cos(a1) * 120, cy + sin(a1) * 120, "Z"]))
			_fill("".join(parts), c2)
		"vstripes", "hstripes":
			var n := int(f[3]) if f.size() > 3 else 5
			var step := box.size.x / n if kind == "vstripes" else box.size.y / n
			for i in n:
				if i % 2 == 1:
					if kind == "vstripes":
						_rect(box.position.x + i * step, 0, step, 128, c2)
					else:
						_rect(0, box.position.y + i * step, 128, step, c2)
		"chief":
			_rect(0, 0, 128, box.position.y + box.size.y * 0.3, c2)
		"base":
			_rect(0, box.position.y + box.size.y * 0.7, 128, 128, c2)
		"wave":
			var y := box.position.y + box.size.y * 0.66
			_fill(_d(["M", 0, y, "Q", 16, y - 8, 32, y, "T", 64, y, "T", 96, y, "T", 128, y, "L", 128, 128, "L", 0, 128, "Z"]), c2)
			_out.append('<path d="%s" fill="none" stroke="%s" stroke-width="3" stroke-opacity="0.5"/>' % [
				_d(["M", 0, y + 12, "Q", 16, y + 4, 32, y + 12, "T", 64, y + 12, "T", 96, y + 12, "T", 128, y + 12]), c3])
		"chequy":
			var parts := PackedStringArray()
			for i in 8:
				for j in 8:
					if (i + j) % 2 == 1:
						parts.append(_d(["M", i * 16, j * 16, "h16v16h-16Z"]))
			_fill("".join(parts), c2)
		"tierce":
			# three bands: across, or (on a triangle) from the point down
			var h := box.size.y / 3.0
			_rect(0, box.position.y + h, 128, h, c2)
			_rect(0, box.position.y + 2.0 * h, 128, 128, c3)
		"tri":
			# the armoured triangle: three panels meeting in the middle
			var c := Vector2(cx, box.position.y + box.size.y * 0.62)
			_fill(_d(["M", c.x, c.y, "L", 140, 140, "L", -12, 140, "Z"]), c3)
			_fill(_d(["M", c.x, c.y, "L", cx, -10, "L", 140, -10, "L", 140, 140, "Z"]), c2)
		"ring":
			# a band round the edge for the lettering, and the disc inside it
			var r := minf(box.size.x, box.size.y) * 0.5 - 18.0
			_fill(_circ(cx, cy, r), c2)
			_out.append('<path d="%s" fill="none" stroke="%s" stroke-width="2"/>' % [_circ(cx, cy, r), c3 if f.size() > 3 else INK])
		"plain":
			pass


## Light from the top left, shadow to the bottom right: cloth, not a sticker.
static func _sheen(outline: String) -> void:
	_defs.append('<radialGradient id="%s-sh" cx="0.3" cy="0.22" r="0.95"><stop offset="0" stop-color="#fff" stop-opacity="0.2"/>' % _id
		+ '<stop offset="0.5" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.32"/></radialGradient>')
	_out.append('<path d="%s" fill="url(#%s-sh)"/>' % [outline, _id])


## The merrowed edge: a thick overlocked border, a dark line outside it so
## the patch reads on any background, and the stitching just inside.
static func _border(shape: String, box: Rect2, bc: String, bw: float) -> void:
	var d := shape_d(shape, box)
	var c := col(bc)
	_out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % [d, INK, _n(bw + 2.6)])
	_out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % [d, c, _n(bw)])
	if bc.begins_with("@"):
		# bullion: a twisted cord of metal thread
		_out.append('<path d="%s" fill="none" stroke="#3a2608" stroke-opacity="0.45" stroke-width="%s" stroke-dasharray="1.2 2.2" stroke-linejoin="round"/>' % [d, _n(bw)])
	else:
		_out.append('<path d="%s" fill="none" stroke="#000" stroke-opacity="0.28" stroke-width="%s" stroke-dasharray="0.9 1.6" stroke-linejoin="round"/>' % [d, _n(bw * 0.8)])
	var st := shape_d(shape, box, bw * 0.5 + 2.2)
	_out.append('<path d="%s" fill="none" stroke="%s" stroke-opacity="0.5" stroke-width="0.9" stroke-dasharray="1.8 1.4"/>' % [st, INK])


## An arched tab above the patch ("AIRBORNE", "MOUNTAIN"): [text, field, letters, border].
static func _tab(tab: Array) -> void:
	var fc := col(tab[1]) if tab.size() > 1 else col("black")
	var tc := col(tab[2]) if tab.size() > 2 else col("yellow")
	var bc := col(tab[3]) if tab.size() > 3 else tc
	var d := "M13 22.5A136 136 0 0 1 115 22.5L115 43A116 116 0 0 0 13 43Z"
	_out.append('<path d="%s" fill="%s" stroke="%s" stroke-width="7.4" stroke-linejoin="round"/>' % [d, fc, INK])
	_out.append('<path d="%s" fill="%s"/>' % [d, fc])
	_sheen(d)
	_out.append('<path d="%s" fill="none" stroke="%s" stroke-width="4.4" stroke-linejoin="round"/>' % [d, bc])
	_letters(String(tab[0]), Vector2(64, 148), 11.0, tc, 126.0, false, 96.0)


# --- devices ----------------------------------------------------------------------------

## One device on the patch: [symbol, colour, scale, dx, dy, rotation, second
## colour, outline colour]. A negative scale mirrors it.
static func _charge(c: Array, centre: Vector2) -> void:
	var name := String(c[0])
	var c0 := col(c[1]) if c.size() > 1 else LIGHT
	var s: float = float(c[2]) if c.size() > 2 else 0.6
	var dx: float = float(c[3]) if c.size() > 3 else 0.0
	var dy: float = float(c[4]) if c.size() > 4 else 0.0
	var rot: float = float(c[5]) if c.size() > 5 else 0.0
	var c1 := col(c[6]) if c.size() > 6 and String(c[6]) != "" else c0
	var ink := col(c[7]) if c.size() > 7 else INK
	var flip := s < 0.0
	s = absf(s)
	var tf := "translate(%s %s)" % [_n(centre.x + dx), _n(centre.y + dy)]
	if rot != 0.0:
		tf += " rotate(%s)" % _n(rot)
	tf += " scale(%s %s) translate(-50 -50)" % ["%.3f" % (-s if flip else s), "%.3f" % s]
	var prims := symbol(name)
	var ow := 2.0 * OUTLINE / s
	var cols := [c0, c1, ink, LIGHT, col("red"), col("yellow")]
	var g := PackedStringArray()
	# the ink under the whole device first, so parts that touch read as one
	for p: Array in prims:
		var kind := String(p[0])
		var ptf := ' transform="%s"' % p[4] if p.size() > 4 and String(p[4]) != "" else ""
		if kind == "f":
			g.append('<path d="%s" fill="%s" fill-rule="evenodd" stroke="%s" stroke-width="%s" stroke-linejoin="round"%s/>' % [p[1], ink, ink, _n(ow), ptf])
		elif kind == "s":
			g.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"%s/>' % [p[1], ink, _n(float(p[3]) + ow), ptf])
	for p: Array in prims:
		var kind := String(p[0])
		var pc: String = cols[int(p[2])] if p[2] is int else col(p[2])
		var ptf := ' transform="%s"' % p[4] if p.size() > 4 and String(p[4]) != "" else ""
		if kind == "f" or kind == "df":
			g.append('<path d="%s" fill="%s" fill-rule="evenodd"%s/>' % [p[1], pc, ptf])
		else:
			g.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"%s/>' % [p[1], pc, _n(float(p[3])), ptf])
	_out.append('<g transform="%s">%s</g>' % [tf, "".join(g)])


## A device as primitives in its 100 x 100 box: [kind, path, colour, width,
## transform]. Kinds: "f" filled (holes cut with even-odd), "s" a stroked
## line, both outlined in ink; "df" / "d" the same as detail drawn on top
## without an outline. Colours: 0 the device's colour, 1 its second colour,
## 2 ink, 3 light, 4 red, 5 yellow (or a colour name).
static func symbol(name: String) -> Array:
	if SYMBOLS.has(name):
		return SYMBOLS[name]
	match name:
		"star":
			return [["f", _star_d(50, 53, 48, 19.5, 5), 0]]
		"star4":
			return [["f", _star_d(50, 50, 48, 11, 4), 0]]
		"compass":
			return [["f", _star_d(50, 50, 34, 8, 4, -45.0), 1], ["f", _star_d(50, 50, 49, 10, 4), 0], ["df", _circ(50, 50, 5), 2]]
		"sunburst":
			return [["f", _star_d(50, 50, 48, 30, 16), 0], ["df", _circ(50, 50, 22), 1]]
		"gear":
			return [["f", _gear_d(50, 50, 47, 38, 10) + _circ(50, 50, 15), 0]]
		"globe":
			return [["f", _circ(50, 50, 44), 0],
				["d", "M50 6L50 94M6 50L94 50M14 28L86 28M14 72L86 72" + _ellipse(50, 50, 20, 44) + _ellipse(50, 50, 36, 44), 1, 2.2]]
		"wreath":
			return _wreath()
		"crosshair":
			return [["s", _circ(50, 50, 33), 0, 5.5], ["s", "M50 4L50 32M50 68L50 96M4 50L32 50M68 50L96 50", 0, 5.5], ["f", _circ(50, 50, 4.5), 0]]
		"maltese":
			var parts := PackedStringArray()
			for i in 4:
				var a := i * PI * 0.5
				var pts := [Vector2(0, -4), Vector2(-17, -47), Vector2(0, -36), Vector2(17, -47)]
				var q := PackedStringArray()
				for k in pts.size():
					var v: Vector2 = pts[k].rotated(a) + Vector2(50, 50)
					q.append(("M" if k == 0 else "L") + _n(v.x) + " " + _n(v.y))
				parts.append("".join(q) + "Z")
			return [["f", "".join(parts), 0], ["df", _circ(50, 50, 10), 1]]
		"chev1", "chev2", "chev3":
			var n := int(name.substr(4))
			var parts := PackedStringArray()
			var y0 := 50.0 - (n * 18.0 + 12.0) * 0.5 + 6.0
			for i in n:
				var y := y0 + i * 18.0
				parts.append(_d(["M", 8, y + 34, "L", 50, y, "L", 92, y + 34, "L", 92, y + 46, "L", 50, y + 12, "L", 8, y + 46, "Z"]))
			return [["f", "".join(parts), 0]]
		"rocker":
			return [["s", "M12 64Q50 92 88 64", 0, 11]]
		"swords":
			return _crossed("sword", 38.0)
		"rifles":
			return _crossed("rifle", 34.0)
		"cannons":
			return _crossed("cannon", 36.0)
		"arrows":
			return _crossed("arrow", 38.0)
		"axes":
			return _xf(symbol("axe"), "") + _xf(symbol("axe"), "matrix(-1 0 0 1 100 0)")
		"bolts":
			return _crossed("lightning", 22.0)
		"tools":
			return _xf(symbol("wrench"), "rotate(-35 50 50)") + _xf(symbol("hammer"), "rotate(35 50 50)")
		"skullbones":
			return symbol("bones") + _xf(symbol("skull"), "translate(50 48) scale(0.6) translate(-50 -50)")
		"reaper":
			return _xf(symbol("scythe"), "translate(8 0)") + symbol("hood") + _recolour(_xf(symbol("skull"), "translate(50 53) scale(0.42) translate(-50 -50)"), 3)
		"jumpwings":
			return symbol("wings") + _xf(symbol("parachute"), "translate(50 46) scale(0.62) translate(-50 -50)")
		"airwings":
			return symbol("wings") + _xf(symbol("shieldc"), "translate(50 50) scale(0.34) translate(-50 -50)")
		"eyewings":
			return symbol("wings") + _xf(symbol("eye"), "translate(50 50) scale(0.34) translate(-50 -50)")
		"heliwings":
			return symbol("wings") + _xf(symbol("helicopter"), "translate(50 44) scale(0.48) translate(-50 -50)")
		"torchwings":
			return symbol("wings") + _xf(symbol("torch"), "translate(50 50) scale(0.6) translate(-50 -50)")
	if name.begins_with("stars"):
		return _stars(name)
	push_warning("Insignia: no device called %s" % name)
	return [["f", _circ(50, 50, 30), 0]]


## A device twice, crossed like the branch insignia.
static func _crossed(name: String, deg: float) -> Array:
	return _xf(symbol(name), "rotate(%s 50 50)" % _n(-deg)) + _xf(symbol(name), "rotate(%s 50 50)" % _n(deg))


## Primitives drawn in another colour (a light skull in a dark hood).
static func _recolour(prims: Array, k: int) -> Array:
	var out := []
	for p: Array in prims:
		var q := p.duplicate()
		if int(q[2]) == 0:
			q[2] = k
		out.append(q)
	return out


## Primitives with a transform put in front of their own.
static func _xf(prims: Array, tf: String) -> Array:
	var out := []
	for p: Array in prims:
		var q := p.duplicate()
		while q.size() < 4:
			q.append(0.0)
		var own := String(q[4]) if q.size() > 4 else ""
		var t := (tf + " " + own).strip_edges()
		if q.size() > 4:
			q[4] = t
		else:
			q.append(t)
		out.append(q)
	return out


## "stars3": stars in a row; "starsring5": in a ring (the five-star insignia).
static func _stars(name: String) -> Array:
	var ring := name.begins_with("starsring")
	var n := int(name.substr(9 if ring else 5))
	var parts := PackedStringArray()
	for i in n:
		var p := Vector2(50, 50)
		var r := 14.0
		if ring:
			var a := -PI * 0.5 + TAU * i / n
			p = Vector2(50, 52) + Vector2(cos(a), sin(a)) * 30.0
			r = 15.0
		else:
			r = minf(16.0, 88.0 / n * 0.5)
			p = Vector2(50 + (i - (n - 1) * 0.5) * r * 2.15, 50)
		parts.append(_star_d(p.x, p.y, r, r * 0.4, 5))
	return [["f", "".join(parts), 0]]


## The laurel wreath: two branches curving up from a tie at the foot, open
## at the top, leaves in pairs along each stem.
static func _wreath() -> Array:
	var leaves := PackedStringArray()
	var stems := PackedStringArray()
	var c := Vector2(50, 50)
	for side: float in [-1.0, 1.0]:
		var pts := PackedStringArray()
		var n := 9
		for i in n:
			var t := i / float(n - 1)
			var a := PI * 0.5 + side * (0.22 + t * (PI - 0.7))
			var p := c + Vector2(cos(a), sin(a)) * 39.0
			pts.append(("M" if i == 0 else "L") + _n(p.x) + " " + _n(p.y))
			var grow := Vector2(-sin(a), cos(a)) * side
			var nrm := Vector2(cos(a), sin(a))
			var ln := 14.0 - 4.0 * t
			var wd := 5.2 - 1.4 * t
			var dirs := [grow * 0.82 + nrm * 0.57, grow * 0.82 - nrm * 0.57]
			if i == n - 1:
				dirs.append(grow)
			for dv: Vector2 in dirs:
				var dir := dv.normalized()
				var tip := p + dir * ln
				var mid := p + dir * ln * 0.45
				var perp := Vector2(-dir.y, dir.x) * wd
				leaves.append(_d(["M", p.x, p.y, "Q", mid.x + perp.x, mid.y + perp.y, tip.x, tip.y, "Q", mid.x - perp.x, mid.y - perp.y, p.x, p.y, "Z"]))
		stems.append("".join(pts))
	return [["s", "".join(stems), 0, 2.4], ["f", "".join(leaves), 0], ["f", "M43 86L57 86L61 95L50 91L39 95Z", 1]]


# hand-drawn devices
const SYMBOLS := {
	"lightning": [["f", "M60 2L24 54L46 54L34 98L78 40L55 40L70 2Z", 0]],
	"sword": [["f", "M50 2L57 14L56 66L44 66L43 14Z", 0], ["d", "M50 14L50 62", 1, 2.0],
		["f", "M27 64L73 64L73 71L27 71Z", 1], ["f", "M45 71L55 71L55 88L45 88Z", 1], ["f", "M44 92A6 6 0 1 0 56 92A6 6 0 1 0 44 92Z", 1]],
	"dagger": [["f", "M50 3L60 22L58 62L42 62L40 22Z", 0], ["d", "M50 10L50 58", 1, 2.0], ["f", "M31 61L69 61L66 69L34 69Z", 1],
		["f", "M44 69L56 69L55 88L45 88Z", 1], ["d", "M45 75L55 75M45 81L55 81", 2, 1.4], ["f", "M41 88L59 88L56 96L44 96Z", 1]],
	"rifle": [["f", "M48.5 2L51.5 2L52 50L48 50Z", 1], ["f", "M47 28L53 28L54.5 58L45.5 58Z", 0], ["f", "M45.5 56L54.5 56L55 67L45 67Z", 1],
		["s", "M54 66Q59 72 52 75", 1, 2.0], ["s", "M54.5 60L61 57", 1, 2.6], ["f", "M45 65L55 65L58 78L62 96L50 98L41 96L43 78Z", 0]],
	"cannon": [["f", "M44 9L56 9L60 78Q60 88 50 88Q40 88 40 78Z", 0], ["f", "M41.5 4L58.5 4L58.5 11L41.5 11Z", 0],
		["d", "M42.5 32L57.5 32M41 62L59 62", 1, 2.6], ["f", "M45 93A5 5 0 1 0 55 93A5 5 0 1 0 45 93Z", 0]],
	"anchor": [["s", "M50 4A7 7 0 1 0 50.1 4Z", 0, 4.5], ["s", "M30 26L70 26", 0, 7.5], ["f", "M46 18L54 18L54 86L46 86Z", 0],
		["s", "M16 62Q20 90 50 90Q80 90 84 62", 0, 7.0], ["f", "M7 66L16 47L27 66Z", 0], ["f", "M93 66L84 47L73 66Z", 0]],
	"parachute": [["f", "M8 46C8 20 28 6 50 6C72 6 92 20 92 46Q81 39 71 46Q60 39 50 46Q40 39 29 46Q19 39 8 46Z", 0],
		["d", "M50 7L50 44M50 7Q35 18 29.5 44M50 7Q65 18 70.5 44", 1, 1.6],
		["s", "M9 46L48 84M29 45L49 84M71 45L51 84M91 46L52 84", 0, 1.5], ["f", "M45 88A5 5 0 1 0 55 88A5 5 0 1 0 45 88Z", 0]],
	"wings": [["f", "M45 44C34 37 18 31 2 28C8 33 11 37 12 40C9 41 7 43 7 45C13 46 17 48 19 50C16 51 14 53 14 55C20 56 25 57 28 59C26 60 24 61 24 63C33 63 40 61 45 57Z", 0],
		["d", "M43 46C32 42 21 38 10 36M43 50C35 48 27 46 18 45M43 54C37 54 30 53 23 53", 1, 1.3],
		["f", "M45 44C34 37 18 31 2 28C8 33 11 37 12 40C9 41 7 43 7 45C13 46 17 48 19 50C16 51 14 53 14 55C20 56 25 57 28 59C26 60 24 61 24 63C33 63 40 61 45 57Z", 0, 0.0, "matrix(-1 0 0 1 100 0)"],
		["d", "M43 46C32 42 21 38 10 36M43 50C35 48 27 46 18 45M43 54C37 54 30 53 23 53", 1, 1.3, "matrix(-1 0 0 1 100 0)"]],
	"skull": [["f", "M50 6C26 6 12 22 12 44C12 57 19 65 27 69L27 82C27 88 31 92 37 92L63 92C69 92 73 88 73 82L73 69C81 65 88 57 88 44C88 22 74 6 50 6Z"
		+ "M24 47A10 11 0 1 0 44 47A10 11 0 1 0 24 47Z M56 47A10 11 0 1 0 76 47A10 11 0 1 0 56 47Z M50 57L44 69L56 69Z", 0],
		["d", "M37 78L63 78M41.5 73L41.5 92M50 73L50 92M58.5 73L58.5 92", 2, 1.8]],
	"bones": [["s", "M20 80L80 20M20 20L80 80", 0, 9.0],
		["f", "M9 79A6 6 0 1 0 21 79A6 6 0 1 0 9 79Z M15 87A6 6 0 1 0 27 87A6 6 0 1 0 15 87Z M73 13A6 6 0 1 0 85 13A6 6 0 1 0 73 13Z M79 21A6 6 0 1 0 91 21A6 6 0 1 0 79 21Z"
		+ "M9 21A6 6 0 1 0 21 21A6 6 0 1 0 9 21Z M15 13A6 6 0 1 0 27 13A6 6 0 1 0 15 13Z M73 87A6 6 0 1 0 85 87A6 6 0 1 0 73 87Z M79 79A6 6 0 1 0 91 79A6 6 0 1 0 79 79Z", 0]],
	"spade": [["f", "M50 4C40 24 8 38 8 60C8 76 21 85 33 84C40 83 45 79 47 75L42 96L58 96L53 75C55 79 60 83 67 84C79 85 92 76 92 60C92 38 60 24 50 4Z", 0]],
	"eaglehead": [["f", "M40 96C42 84 40 72 34 63C30 58 24 56 18 57C12 58 10 62 12 65C5 63 3 55 7 47C11 35 21 25 35 20C49 15 67 15 79 23C89 31 93 45 91 57L97 65L88 67L94 77L85 79L91 91L80 89L82 96Z"
		+ "M42 33A4 4 0 1 0 50 33A4 4 0 1 0 42 33Z", 0],
		["f", "M35 20C21 25 11 35 7 47C3 55 5 63 12 65C10 62 12 58 18 57C24 56 30 58 33 61L40 49C34 43 35 30 41 22Z", 1],
		["d", "M14 53Q24 49 38 50M38 30Q47 23 58 29", 2, 1.8]],
	"tank": [["f", "M10 70L90 70Q96 70 96 78Q96 90 86 90L14 90Q4 90 4 78Q4 70 10 70Z", 1],
		["df", "M11 80A5 5 0 1 0 21 80A5 5 0 1 0 11 80Z M25 82A5 5 0 1 0 35 82A5 5 0 1 0 25 82Z M39 82A5 5 0 1 0 49 82A5 5 0 1 0 39 82Z M53 82A5 5 0 1 0 63 82A5 5 0 1 0 53 82Z M67 82A5 5 0 1 0 77 82A5 5 0 1 0 67 82Z M80 80A5 5 0 1 0 90 80A5 5 0 1 0 80 80Z", 0],
		["f", "M5 70L12 55L88 55L96 70Z", 0], ["f", "M27 55L34 39L62 39L71 55Z", 0], ["f", "M66 43L98 43L98 48.5L66 48.5Z", 0],
		["f", "M40 39L42 33L52 33L54 39Z", 0]],
	"helicopter": [["s", "M5 16L95 16", 0, 3.2], ["f", "M47 16L53 16L54 28L46 28Z", 0],
		["f", "M12 50C12 36 26 28 42 28L64 28C72 28 76 34 78 40L95 42L97 50L78 52C74 60 66 64 56 64L28 64C18 64 12 58 12 50Z M18 48C18 40 26 34 36 34L38 34L38 48Z", 0],
		["s", "M95 33L95 54", 0, 2.6], ["d", "M44 34L44 60M44 34L62 34", 1, 1.6],
		["s", "M12 72Q12 77 18 77L68 77M30 64L28 77M56 64L58 77", 0, 2.8]],
	"jet": [["f", "M50 2L56 26L56 42L94 66L94 74L56 64L56 80L68 90L68 96L50 92L32 96L32 90L44 80L44 64L6 74L6 66L44 42L44 26Z", 0],
		["df", "M47.5 16L52.5 16L53.5 30L46.5 30Z", 1]],
	"ship": [["f", "M3 64L98 59L88 80L14 80Z", 0], ["f", "M28 64L30 50L44 50L46 38L56 38L58 50L68 50L70 62Z", 0],
		["s", "M51 38L51 18M44 26L58 26", 0, 2.5], ["f", "M33 50L37 41L43 41L41 50Z", 1], ["s", "M80 57L93 53", 0, 2.4],
		["s", "M4 88Q12 84 20 88Q28 92 36 88Q44 84 52 88Q60 92 68 88Q76 84 84 88Q92 92 98 88", 1, 3.0]],
	"mountain": [["f", "M2 90L34 30L46 48L62 20L98 90Z", 0], ["df", "M34 30L26.5 44L32 41L36 47L40 41L43.5 44.5Z M62 20L52.5 38L58 35L62 41L67 35L72.5 38.5Z", 3]],
	"castle": [["f", "M10 92L10 30L6 30L6 12L16 12L16 20L24 20L24 12L34 12L34 30L30 30L30 44L38 44L38 36L46 36L46 44L54 44L54 36L62 36L62 44L70 44L70 30L66 30L66 12L76 12L76 20L84 20L84 12L94 12L94 30L90 30L90 92Z"
		+ "M42 92L42 72A8 8 0 0 1 58 72L58 92Z M16 46L24 46L24 58L16 58Z M76 46L84 46L84 58L76 58Z", 0]],
	"crown": [["f", "M10 78L14 30L32 52L50 20L68 52L86 30L90 78Z", 0], ["f", "M10 78L90 78L90 92L10 92Z", 0],
		["f", "M9 28A5 5 0 1 0 19 28A5 5 0 1 0 9 28Z M45 18A5 5 0 1 0 55 18A5 5 0 1 0 45 18Z M81 28A5 5 0 1 0 91 28A5 5 0 1 0 81 28Z", 1],
		["df", "M26.5 85A3.5 3.5 0 1 0 33.5 85A3.5 3.5 0 1 0 26.5 85Z M46.5 85A3.5 3.5 0 1 0 53.5 85A3.5 3.5 0 1 0 46.5 85Z M66.5 85A3.5 3.5 0 1 0 73.5 85A3.5 3.5 0 1 0 66.5 85Z", 1]],
	"trident": [["s", "M50 36L50 96", 0, 7.0], ["s", "M22 18L22 34Q22 46 50 46Q78 46 78 34L78 18M50 18L50 46", 0, 7.0],
		["f", "M15 21L22 3L29 21Z M43 21L50 1L57 21Z M71 21L78 3L85 21Z", 0]],
	"wolf": [["f", "M50 94L38 80L24 72L16 54L14 34L18 10L36 28C40 26 46 25 50 25C54 25 60 26 64 28L82 10L86 34L84 54L76 72L62 80Z M28 46L42 51L31 55Z M72 46L58 51L69 55Z", 0],
		["df", "M22 20L32 31L24 35Z M78 20L68 31L76 35Z", 1], ["df", "M40 60L60 60L58 79L50 87L42 79Z", 3],
		["df", "M44.5 75L55.5 75L50 81Z", 2]],
	"cobra": [["s", "M42 74C30 77 16 81 16 88C16 95 84 95 84 88C84 82 70 79 60 77", 0, 9.0],
		["f", "M50 3C57 3 61 8 61 14C72 17 87 29 87 41C87 53 72 61 58 67L58 76L42 76L42 67C28 61 13 53 13 41C13 29 28 17 39 14C39 8 43 3 50 3Z", 0],
		["df", "M35 42C35 35 44 33 50 38C56 33 65 35 65 42C65 49 56 50 50 45C44 50 35 49 35 42Z", 1],
		["d", "M44 58L56 58M45 64L55 64M45 70L55 70", 1, 1.6], ["df", "M43.2 10A2.2 2.2 0 1 0 47.6 10A2.2 2.2 0 1 0 43.2 10Z M52.4 10A2.2 2.2 0 1 0 56.8 10A2.2 2.2 0 1 0 52.4 10Z", 2],
		["d", "M50 16L50 23M50 23L47 26.5M50 23L53 26.5", 4, 1.5]],
	"bat": [["f", "M50 34L46 22L44 32C36 28 22 26 2 32C10 38 12 46 10 54C18 48 26 50 30 58C36 52 44 54 50 66C56 54 64 52 70 58C74 50 82 48 90 54C88 46 90 38 98 32C78 26 64 28 56 32L54 22Z", 0],
		["df", "M45.5 31A1.6 1.6 0 1 0 48.7 31A1.6 1.6 0 1 0 45.5 31Z M51.3 31A1.6 1.6 0 1 0 54.5 31A1.6 1.6 0 1 0 51.3 31Z", 4]],
	"owl": [["f", "M50 94C26 94 18 76 18 56C18 42 21 32 26 24L20 6L38 18C42 17 46 16 50 16C54 16 58 17 62 18L80 6L74 24C79 32 82 42 82 56C82 76 74 94 50 94Z", 0],
		["df", "M24 42A12 12 0 1 0 48 42A12 12 0 1 0 24 42Z M52 42A12 12 0 1 0 76 42A12 12 0 1 0 52 42Z", 1],
		["df", "M31 42A5 5 0 1 0 41 42A5 5 0 1 0 31 42Z M59 42A5 5 0 1 0 69 42A5 5 0 1 0 59 42Z", 2], ["df", "M45 53L55 53L50 64Z", 5],
		["d", "M36 72Q40 76 44 72M48 77Q52 81 56 77M56 70Q60 74 64 70M42 83Q46 87 50 83", 2, 1.6]],
	"horse": [["f", "M28 96L28 82C28 72 34 66 40 60C32 62 22 66 14 64C8 62 6 54 10 48L30 28C34 20 38 14 44 10L46 2L54 10C72 14 86 30 88 52C90 70 84 84 82 96Z M38 30A3.5 3.5 0 1 0 45 30A3.5 3.5 0 1 0 38 30Z", 0],
		["d", "M54 10C66 22 72 36 74 52M60 15L67 12M66 23L75 21M70 33L79 32M72 43L82 43", 1, 2.2], ["df", "M13 55A2 2 0 1 0 17 55A2 2 0 1 0 13 55Z", 2]],
	"tiger": [["f", "M50 92C34 92 22 82 18 68C14 56 15 44 19 36L15 14L33 25C39 22 45 21 50 21C55 21 61 22 67 25L85 14L81 36C85 44 86 56 82 68C78 82 66 92 50 92Z", 0],
		["df", "M28 48Q36 42 44 48Q36 53 28 48Z M72 48Q64 42 56 48Q64 53 72 48Z", 1], ["df", "M35 44.5L37 44.5L37 51.5L35 51.5Z M63 44.5L65 44.5L65 51.5L63 51.5Z", 2],
		["df", "M44 61L56 61L50 68Z", 2], ["d", "M50 68L50 74M50 74Q44 80 38 76M50 74Q56 80 62 76", 2, 1.8],
		["d", "M50 26L50 37M42 27L44 37M58 27L56 37M18 52L29 54M17 60L28 60M82 52L71 54M83 60L72 60", 2, 2.6],
		["df", "M42 78L45 87L47.5 79Z M58 78L55 87L52.5 79Z", 3]],
	"dragon": [["f", "M95 75C89 63 85 53 79 47L91 33L75 37L81 21L65 33C59 29 51 28 45 30L31 27C21 25 11 29 7 37L23 39L21 43L9 47C11 55 19 59 29 57L41 55C47 61 51 71 47 85L59 77L61 89L69 79L75 91Z M45 36A3 3 0 1 0 51 36A3 3 0 1 0 45 36Z", 0],
		["df", "M12 39L14.5 43L17 39Z M19 39L21.5 43L24 39Z M13 46L15.5 42L18 46Z", 3], ["d", "M54 30Q66 24 76 30M58 42Q70 44 80 52", 1, 2.0]],
	"scorpion": [["s", "M43 30L32 22L26 15M57 30L68 22L74 15", 0, 5.0],
		["f", "M30 16C22 20 12 14 14 6C15 2 19 2 21 4L24 10L24 4C27 2 32 4 32 9C32 12 31 14 30 16Z", 0],
		["f", "M30 16C22 20 12 14 14 6C15 2 19 2 21 4L24 10L24 4C27 2 32 4 32 9C32 12 31 14 30 16Z", 0, 0.0, "matrix(-1 0 0 1 100 0)"],
		["s", "M42 38L30 34L24 40M42 44L28 45L22 53M42 50L30 55L27 63M43 56L33 63L31 71", 0, 2.6],
		["s", "M42 38L30 34L24 40M42 44L28 45L22 53M42 50L30 55L27 63M43 56L33 63L31 71", 0, 2.6, "matrix(-1 0 0 1 100 0)"],
		["s", "M50 66C50 82 56 92 68 92C80 92 86 80 82 67", 0, 7.0],
		["f", "M80 70C75 62 77 55 84 52C83 57 85 61 89 63Z", 0],
		["f", "M50 26C56 26 59 30 59 36L58 62C58 68 54 70 50 70C46 70 42 68 42 62L41 36C41 30 44 26 50 26Z", 0],
		["d", "M42 44L58 44M42 50L58 50M42.5 56L57.5 56M43 62L57 62", 2, 1.2], ["d", "M56 86L58 82M66 92L66 88M76 89L74 86", 2, 1.2]],
	"fist": [["f", "M28 96L28 58C22 54 20 46 22 38L24 28C24 22 28 19 33 20C35 14 41 12 45 16C49 12 55 12 58 16C62 12 69 14 70 21C75 19 80 23 79 30L77 56L72 64L72 96Z", 0],
		["d", "M33 20L34 37M45 16L46 37M58 16L58 37M70 21L69 38M23 41Q36 45 51 41", 2, 1.6]],
	"axe": [["s", "M26 96L64 12", 1, 6.0], ["f", "M53 19C63 8 82 7 95 18C85 26 79 34 77 45C71 37 62 32 51 32Z", 0]],
	"bomb": [["f", "M12 60A32 32 0 1 0 76 60A32 32 0 1 0 12 60Z", 0], ["f", "M58 21L73 36L66 43L51 28Z", 0], ["s", "M69 29Q78 18 86 16", 1, 3.0],
		["df", "M88 6L90.4 11.7L96.6 12.2L91.9 16.2L93.3 22.3L88 19L82.7 22.3L84.1 16.2L79.4 12.2L85.6 11.7Z", 5], ["d", "M27 52Q29 41 38 37", 3, 3.0]],
	"grenade": [["f", "M50 30C64 30 74 44 74 62C74 82 64 94 50 94C36 94 26 82 26 62C26 44 36 30 50 30Z", 0],
		["d", "M28 52L72 52M26 66L74 66M28 80L72 80M40 32L40 92M60 32L60 92", 2, 1.6], ["f", "M42 20L58 20L58 32L42 32Z", 1],
		["s", "M58 22C68 22 72 30 72 44", 1, 4.0], ["s", "M30 20A6 6 0 1 0 42 20A6 6 0 1 0 30 20Z", 1, 2.5]],
	"torch": [["f", "M42 50L58 50L54 96L46 96Z", 1], ["f", "M39 46L61 46L61 54L39 54Z", 1],
		["f", "M50 2C56 14 70 22 70 36C70 44 62 48 50 48C38 48 30 44 30 36C30 26 38 22 40 14C42 22 46 24 48 26C46 16 48 8 50 2Z", 0],
		["df", "M50 20C54 28 60 32 60 38C60 42 56 44 50 44C44 44 40 42 40 38C40 32 46 30 50 20Z", 5]],
	"flame": [["f", "M50 4C56 20 76 30 76 56C76 76 64 92 50 92C36 92 24 78 24 60C24 46 32 38 36 26C38 38 42 42 46 44C44 30 46 16 50 4Z", 0],
		["df", "M50 40C55 50 64 56 64 68C64 78 58 86 50 86C42 86 36 80 36 70C36 60 44 56 50 40Z", 1]],
	"oakleaf": [["f", "M50 4C56 10 60 12 62 18C68 16 72 20 70 26C78 26 80 34 74 38C82 42 80 50 72 50C78 58 72 64 64 60C66 68 60 72 54 68L53 96L47 96L46 68C40 72 34 68 36 60C28 64 22 58 28 50C20 50 18 42 26 38C20 34 22 26 30 26C28 20 32 16 38 18C40 12 44 10 50 4Z", 0],
		["d", "M50 10L50 70M50 30L62 22M50 30L38 22M50 44L68 38M50 44L32 38M50 56L64 54M50 56L36 54", 1, 1.4]],
	"palm": [["s", "M50 94C48 76 50 56 56 40", 1, 6.0],
		["f", "M56 40C44 28 26 26 10 34C26 32 40 36 50 44Z M56 40C52 24 40 12 26 10C40 18 48 30 52 42Z M56 40C64 24 78 18 92 22C78 24 66 32 60 44Z M56 40C70 34 86 38 96 50C84 44 70 44 58 46Z M56 40C62 30 62 16 56 4C58 18 56 30 54 40Z", 0],
		["df", "M51 45A3 3 0 1 0 57 45A3 3 0 1 0 51 45Z M56 47A3 3 0 1 0 62 47A3 3 0 1 0 56 47Z", 1]],
	"eye": [["f", "M4 50C22 22 78 22 96 50C78 78 22 78 4 50Z", 3], ["df", "M33 50A17 17 0 1 0 67 50A17 17 0 1 0 33 50Z", 0],
		["df", "M43 50A7 7 0 1 0 57 50A7 7 0 1 0 43 50Z", 2], ["df", "M53 44A3.5 3.5 0 1 0 60 44A3.5 3.5 0 1 0 53 44Z", 3]],
	"scythe": [["s", "M30 96C40 70 48 40 50 10", 1, 5.0], ["f", "M50 12C70 8 88 18 96 36C84 26 70 22 52 24Z", 0]],
	"bullet": [["f", "M40 40L60 40L60 92L40 92Z", 0], ["f", "M37 90L63 90L63 96L37 96Z", 0], ["f", "M40 40C40 22 46 10 50 4C54 10 60 22 60 40Z", 1],
		["d", "M40 47L60 47", 2, 1.5]],
	"bull": [["f", "M50 92C42 92 38 86 36 78L32 50C24 48 14 42 8 30C6 24 8 16 12 12C14 24 20 30 30 33C36 31 42 29 50 29C58 29 64 31 70 33C80 30 86 24 88 12C92 16 94 24 92 30C86 42 76 48 68 50L64 78C62 86 58 92 50 92Z"
		+ "M38 48A3.5 3.5 0 1 0 45 48A3.5 3.5 0 1 0 38 48Z M55 48A3.5 3.5 0 1 0 62 48A3.5 3.5 0 1 0 55 48Z", 0],
		["df", "M40 72Q50 66 60 72L60 82Q50 90 40 82Z", 1], ["df", "M42.8 78A2.2 2.2 0 1 0 47.2 78A2.2 2.2 0 1 0 42.8 78Z M52.8 78A2.2 2.2 0 1 0 57.2 78A2.2 2.2 0 1 0 52.8 78Z", 2]],
	"bear": [["f", "M50 92C30 92 16 80 16 60C16 48 20 40 26 34C18 30 16 20 22 14C28 8 38 12 40 20C44 19 47 18 50 18C53 18 56 19 60 20C62 12 72 8 78 14C84 20 82 30 74 34C80 40 84 48 84 60C84 80 70 92 50 92Z"
		+ "M34 50A3.5 3.5 0 1 0 41 50A3.5 3.5 0 1 0 34 50Z M59 50A3.5 3.5 0 1 0 66 50A3.5 3.5 0 1 0 59 50Z", 0],
		["df", "M24 22A5 5 0 1 0 34 22A5 5 0 1 0 24 22Z M66 22A5 5 0 1 0 76 22A5 5 0 1 0 66 22Z", 1],
		["df", "M50 58C60 58 66 64 66 72C66 80 58 84 50 84C42 84 34 80 34 72C34 64 40 58 50 58Z", 1], ["df", "M44 66L56 66Q56 72 50 74Q44 72 44 66Z", 2]],
	"shark": [["f", "M4 56C18 42 40 34 60 36L70 16L74 38C84 40 90 46 96 52L86 56L96 64C84 64 74 64 64 66L58 78L54 66C36 68 18 64 4 56Z M21 48A3 3 0 1 0 27 48A3 3 0 1 0 21 48Z", 0],
		["df", "M8 58C20 64 36 66 54 64L52 61C36 63 20 61 8 58Z", 3], ["d", "M40 46Q38 52 40 58M45 45Q43 52 45 59M50 45Q48 52 50 59", 2, 1.6],
		["df", "M8 56L12 54L13 58Z M13 57L17 55L18 59Z M18 58L22 56L23 60Z", 3]],
	"missile": [["f", "M50 4C58 14 60 26 60 40L60 74L72 88L72 94L60 88L40 88L28 94L28 88L40 74L40 40C40 26 42 14 50 4Z", 0],
		["d", "M41 28L59 28", 1, 3.0], ["df", "M42 89L58 89L50 99Z", 4]],
	"binoculars": [["f", "M18 40L38 40L42 82Q42 92 30 92Q14 92 14 80Z M62 40L82 40L86 80Q86 92 70 92Q58 92 58 82Z M38 44L62 44L62 60L38 60Z", 0],
		["df", "M20 82A8 8 0 1 0 36 82A8 8 0 1 0 20 82Z M64 82A8 8 0 1 0 80 82A8 8 0 1 0 64 82Z", 1], ["f", "M20 30L36 30L37 40L19 40Z M64 30L80 30L81 40L63 40Z", 1]],
	"antenna": [["s", "M50 30L34 94M50 30L66 94M38 76L62 76M42 60L58 60M38 76L58 60M62 76L42 60", 0, 3.0], ["f", "M45 26A5 5 0 1 0 55 26A5 5 0 1 0 45 26Z", 0],
		["s", "M37 15Q31 26 37 37M63 15Q69 26 63 37M27 7Q17 26 27 45M73 7Q83 26 73 45", 1, 3.0]],
	"wrench": [["s", "M50 30L50 90", 0, 9.0], ["f", "M35 6C34 22 41 32 50 32C59 32 66 22 65 6L58 6L58 18L42 18L42 6Z", 0], ["f", "M43 92A7 7 0 1 0 57 92A7 7 0 1 0 43 92Z", 0]],
	"hammer": [["s", "M50 30L50 96", 1, 7.0], ["f", "M28 12L72 12L72 32L28 32Z", 0]],
	"arrow": [["s", "M50 22L50 90", 0, 5.0], ["f", "M50 2L62 27L50 22L38 27Z", 0], ["f", "M50 78L40 90L40 98L50 88L60 98L60 90Z", 0]],
	"bar": [["f", "M4 37L96 37L96 63L4 63Z", 0]],
	"bridge": [["f", "M2 46L98 46L98 57L91 57Q78 60 76 84L67 84Q64 64 50 64Q36 64 33 84L24 84Q22 60 9 57L2 57Z", 0],
		["s", "M4 36L96 36M10 36L10 46M26 36L26 46M42 36L42 46M58 36L58 46M74 36L74 46M90 36L90 46", 0, 3.0]],
	"shieldc": [["f", "M18 10L82 10L82 46C82 70 64 84 50 92C36 84 18 70 18 46Z", 0]],
	"fleur": [["f", "M50 4C58 16 62 28 58 44C56 52 54 58 54 64L46 64C46 58 44 52 42 44C38 28 42 16 50 4Z", 0],
		["f", "M44 60C34 64 22 60 18 48C14 38 20 28 30 30C24 36 26 46 36 50C40 52 44 54 46 58Z", 0],
		["f", "M44 60C34 64 22 60 18 48C14 38 20 28 30 30C24 36 26 46 36 50C40 52 44 54 46 58Z", 0, 0.0, "matrix(-1 0 0 1 100 0)"],
		["f", "M30 60L70 60L70 70L30 70Z", 0], ["f", "M46 70L54 70L58 92L50 86L42 92Z", 0]],
	"horseshoe": [["s", "M28 90L26 50C26 28 38 14 50 14C62 14 74 28 74 50L72 90", 0, 11.0],
		["df", "M24.5 76A2 2 0 1 0 28.5 76A2 2 0 1 0 24.5 76Z M24 58A2 2 0 1 0 28 58A2 2 0 1 0 24 58Z M71.5 76A2 2 0 1 0 75.5 76A2 2 0 1 0 71.5 76Z M72 58A2 2 0 1 0 76 58A2 2 0 1 0 72 58Z", 2]],
	"crescent": [["f", "M50 6A44 44 0 1 0 50 94A50 50 0 0 1 50 6Z", 0]],
	"heart": [["f", "M50 90C20 66 6 50 6 32C6 18 18 8 30 8C40 8 46 14 50 22C54 14 60 8 70 8C82 8 94 18 94 32C94 50 80 66 50 90Z", 0]],
	"pattee": [["f", "M38 4L62 4L55 40L60 45L96 38L96 62L60 55L55 60L62 96L38 96L45 60L40 55L4 62L4 38L40 45L45 40Z", 0]],
	"cross": [["f", "M38 6L62 6L62 38L94 38L94 62L62 62L62 94L38 94L38 62L6 62L6 38L38 38Z", 0]],
	"disc": [["f", "M6 50A44 44 0 1 0 94 50A44 44 0 1 0 6 50Z", 0], ["d", "M13 50A37 37 0 1 0 87 50A37 37 0 1 0 13 50Z", 1, 2.2]],
	"hood": [["f", "M50 4C74 4 88 24 88 50C88 70 82 86 76 96L24 96C18 86 12 70 12 50C12 24 26 4 50 4Z M50 22C37 22 28 35 28 52C28 68 37 82 50 82C63 82 72 68 72 52C72 35 63 22 50 22Z", 0]],
	"waves": [["s", "M4 30Q16 20 28 30Q40 40 52 30Q64 20 76 30Q88 40 96 30M4 52Q16 42 28 52Q40 62 52 52Q64 42 76 52Q88 62 96 52M4 74Q16 64 28 74Q40 84 52 74Q64 64 76 74Q88 84 96 74", 0, 6.0]],
	"eagle": [["f", "M44 44C38 36 30 24 26 8L21 18L17 6L14 20L8 12L8 28L2 24L5 38C10 50 24 58 42 58Z", 0],
		["f", "M44 44C38 36 30 24 26 8L21 18L17 6L14 20L8 12L8 28L2 24L5 38C10 50 24 58 42 58Z", 0, 0.0, "matrix(-1 0 0 1 100 0)"],
		["d", "M41 46C33 39 26 29 21 18M39 52C29 47 20 39 12 28M38 56C27 54 17 47 8 38", 1, 1.4],
		["d", "M41 46C33 39 26 29 21 18M39 52C29 47 20 39 12 28M38 56C27 54 17 47 8 38", 1, 1.4, "matrix(-1 0 0 1 100 0)"],
		["f", "M50 30C58 30 61 38 60 48L58 68L68 86L50 80L32 86L42 68L40 48C39 38 42 30 50 30Z", 0],
		["d", "M44 76L50 81L56 76M50 68L50 80M45 50Q50 54 55 50M45 58Q50 62 55 58", 1, 1.4],
		["f", "M50 11C57 11 61 16 60 22C60 26 58 29 56 31L50 34L44 31C40 28 40 17 44 14C46 12 48 11 50 11Z", 0],
		["df", "M57 14C63 14 68 16 70 20C71 23 69 26 67 26C67 24 65 23 61 23L57 25Z", 5], ["df", "M51.5 18A1.8 1.8 0 1 0 55.1 18A1.8 1.8 0 1 0 51.5 18Z", 2],
		["d", "M47 15.5L58 14", 2, 1.6]],
}


# --- lettering ----------------------------------------------------------------------------

## The stroke alphabet: [advance, strokes], on a grid 6 high. Block capitals,
## like the embroidered lettering on a tab or a scroll.
const GLYPHS := {
	"A": [4.0, [[0, 6, 2, 0, 4, 6], [0.7, 4, 3.3, 4]]],
	"B": [4.0, [[0, 3, 2.7, 3, 3.5, 2.3, 3.5, 0.7, 2.7, 0, 0, 0, 0, 6, 2.9, 6, 3.8, 5.2, 3.8, 3.8, 2.9, 3]]],
	"C": [4.0, [[4, 1, 3, 0, 1, 0, 0, 1, 0, 5, 1, 6, 3, 6, 4, 5]]],
	"D": [4.0, [[0, 0, 0, 6, 2.4, 6, 4, 4.4, 4, 1.6, 2.4, 0, 0, 0]]],
	"E": [3.6, [[3.6, 0, 0, 0, 0, 6, 3.6, 6], [0, 3, 2.8, 3]]],
	"F": [3.6, [[3.6, 0, 0, 0, 0, 6], [0, 3, 2.8, 3]]],
	"G": [4.0, [[4, 1, 3, 0, 1, 0, 0, 1, 0, 5, 1, 6, 3, 6, 4, 5, 4, 3.2, 2.3, 3.2]]],
	"H": [4.0, [[0, 0, 0, 6], [4, 0, 4, 6], [0, 3, 4, 3]]],
	"I": [0.0, [[0, 0, 0, 6]]],
	"J": [4.0, [[4, 0, 4, 5, 3, 6, 1, 6, 0, 5]]],
	"K": [4.0, [[0, 0, 0, 6], [4, 0, 0, 3.6], [1.4, 2.6, 4, 6]]],
	"L": [3.6, [[0, 0, 0, 6, 3.6, 6]]],
	"M": [5.0, [[0, 6, 0, 0, 2.5, 3.6, 5, 0, 5, 6]]],
	"N": [4.0, [[0, 6, 0, 0, 4, 6, 4, 0]]],
	"O": [4.0, [[1, 0, 3, 0, 4, 1, 4, 5, 3, 6, 1, 6, 0, 5, 0, 1, 1, 0]]],
	"P": [4.0, [[0, 6, 0, 0, 3, 0, 4, 1, 4, 2.2, 3, 3.2, 0, 3.2]]],
	"Q": [4.0, [[1, 0, 3, 0, 4, 1, 4, 5, 3, 6, 1, 6, 0, 5, 0, 1, 1, 0], [2.6, 4.6, 4.2, 6.2]]],
	"R": [4.0, [[0, 6, 0, 0, 3, 0, 4, 1, 4, 2.2, 3, 3.2, 0, 3.2], [2, 3.2, 4, 6]]],
	"S": [4.0, [[4, 1, 3, 0, 1, 0, 0, 1, 0, 2, 1, 3, 3, 3, 4, 4, 4, 5, 3, 6, 1, 6, 0, 5]]],
	"T": [4.0, [[0, 0, 4, 0], [2, 0, 2, 6]]],
	"U": [4.0, [[0, 0, 0, 5, 1, 6, 3, 6, 4, 5, 4, 0]]],
	"V": [4.0, [[0, 0, 2, 6, 4, 0]]],
	"W": [5.4, [[0, 0, 1.35, 6, 2.7, 2.2, 4.05, 6, 5.4, 0]]],
	"X": [4.0, [[0, 0, 4, 6], [4, 0, 0, 6]]],
	"Y": [4.0, [[0, 0, 2, 3, 4, 0], [2, 3, 2, 6]]],
	"Z": [4.0, [[0, 0, 4, 0, 0, 6, 4, 6]]],
	"0": [4.0, [[1, 0, 3, 0, 4, 1, 4, 5, 3, 6, 1, 6, 0, 5, 0, 1, 1, 0]]],
	"1": [3.0, [[0.6, 1.2, 1.8, 0, 1.8, 6], [0.4, 6, 3, 6]]],
	"2": [4.0, [[0, 1, 1, 0, 3, 0, 4, 1, 4, 2.2, 0, 6, 4, 6]]],
	"3": [4.0, [[0, 1, 1, 0, 3, 0, 4, 1, 4, 2, 3, 3, 1.6, 3], [3, 3, 4, 4, 4, 5, 3, 6, 1, 6, 0, 5]]],
	"4": [4.0, [[3, 6, 3, 0, 0, 4.2, 4, 4.2]]],
	"5": [4.0, [[4, 0, 0.4, 0, 0, 2.8, 3, 2.8, 4, 3.8, 4, 5, 3, 6, 1, 6, 0, 5]]],
	"6": [4.0, [[3.6, 0.4, 3, 0, 1, 0, 0, 1, 0, 5, 1, 6, 3, 6, 4, 5, 4, 4, 3, 3, 0, 3]]],
	"7": [4.0, [[0, 0, 4, 0, 1.5, 6]]],
	"8": [4.0, [[1, 3, 0, 2, 0, 1, 1, 0, 3, 0, 4, 1, 4, 2, 3, 3, 1, 3, 0, 4, 0, 5, 1, 6, 3, 6, 4, 5, 4, 4, 3, 3]]],
	"9": [4.0, [[4, 3, 1, 3, 0, 2, 0, 1, 1, 0, 3, 0, 4, 1, 4, 5, 3, 6, 1, 6, 0.4, 5.6]]],
	"-": [2.6, [[0.2, 3, 2.4, 3]]],
	".": [0.0, [[0, 5.7, 0, 6]]],
	"'": [0.0, [[0, 0, 0, 1.6]]],
	"/": [3.0, [[0, 6, 3, 0]]],
	"&": [4.2, [[4.2, 6, 1, 2, 1, 1, 2, 0, 3, 1, 3, 2, 0, 4, 0, 5, 1, 6, 2.6, 6, 4.2, 4]]],
	" ": [1.6, []],
}
const GAP := 1.35  # between letters, in grid units


## A line of lettering, as one path. Straight when `arc_r` is 0; otherwise
## along a circle of that radius round `at` (top: reading clockwise over the
## top, letters standing outwards; bottom: reading left to right under the
## bottom, upright). Shrinks to fit `maxw` (pixels, or along the arc).
static func _letters(text: String, at: Vector2, h: float, colour: String, arc_r := 0.0, bottom := false, maxw := 0.0, y_straight := 0.0) -> void:
	text = text.to_upper()
	var tw := 0.0
	for ch in text:
		var g: Array = GLYPHS.get(ch, GLYPHS[" "])
		tw += float(g[0]) + GAP
	tw -= GAP
	if tw <= 0.0:
		return
	var k := h / 6.0
	if maxw > 0.0 and tw * k > maxw:
		k = maxw / tw
	var sw := maxf(1.2, k * 1.05)
	var parts := PackedStringArray()
	var x := -tw * 0.5
	for ch in text:
		var g: Array = GLYPHS.get(ch, GLYPHS[" "])
		var adv := float(g[0])
		for st: Array in g[1]:
			var q := PackedStringArray()
			for i in range(0, st.size(), 2):
				var lx := (x + float(st[i])) * k
				var ly := (float(st[i + 1]) - 3.0) * k
				var p := Vector2.ZERO
				if arc_r <= 0.0:
					p = at + Vector2(lx, ly + y_straight)
				elif not bottom:
					var a := -PI * 0.5 + lx / arc_r
					var up := Vector2(cos(a), sin(a))
					p = at + up * (arc_r - ly)
				else:
					var a := PI * 0.5 - lx / arc_r
					var dn := Vector2(cos(a), sin(a))
					p = at + dn * (arc_r + ly)
				q.append(("M" if i == 0 else "L") + _n(p.x) + " " + _n(p.y))
			parts.append("".join(q))
		x += adv + GAP
	var d := "".join(parts)
	_out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % [d, INK, _n(sw + OUTLINE * 2.0)])
	_out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"/>' % [d, colour, _n(sw)])


## Lettering on a patch: [where, text, colour, height, offset].
##   top / bot: round the band of a round patch.
##   line: straight across, [.., colour, height, dy, dx] from the centre.
##   scroll: on a ribbon scroll across the foot: [.., colour, scroll colour, y].
##   big: a big numeral or initials as the device: [.., colour, height, dy].
static func _text_item(t: Array, box: Rect2) -> void:
	var kind := String(t[0])
	var text := String(t[1])
	var c := col(t[2]) if t.size() > 2 else LIGHT
	var cen := box.get_center()
	var r := minf(box.size.x, box.size.y) * 0.5 - 9.0
	match kind:
		"top":
			_letters(text, cen, float(t[3]) if t.size() > 3 else 10.5, c, r, false, r * 2.5)
		"bot":
			_letters(text, cen, float(t[3]) if t.size() > 3 else 10.5, c, r, true, r * 2.1)
		"line":
			var h: float = float(t[3]) if t.size() > 3 else 11.0
			var dy: float = float(t[4]) if t.size() > 4 else 0.0
			var dx: float = float(t[5]) if t.size() > 5 else 0.0
			_letters(text, cen + Vector2(dx, 0), h, c, 0.0, false, box.size.x * 0.8, dy)
		"big":
			var h: float = float(t[3]) if t.size() > 3 else 46.0
			var dy: float = float(t[4]) if t.size() > 4 else 0.0
			_letters(text, cen, h, c, 0.0, false, box.size.x * 0.7, dy)
		"scroll":
			var sc := col(t[3]) if t.size() > 3 else col("white")
			var y: float = float(t[4]) if t.size() > 4 else box.end.y - 16.0
			_scroll(text, y, c, sc)


## A ribbon scroll across the foot of a patch, its ends folded back.
static func _scroll(text: String, y: float, tc: String, sc: String) -> void:
	var dark := _shade(sc, 0.62)
	var ends := _d(["M", 22, y - 5, "L", 7, y - 5, "L", 13, y + 3, "L", 7, y + 11, "L", 22, y + 11, "Z",
		"M", 106, y - 5, "L", 121, y - 5, "L", 115, y + 3, "L", 121, y + 11, "L", 106, y + 11, "Z"])
	var band := _d(["M", 18, y - 9, "Q", 64, y - 2, 110, y - 9, "L", 110, y + 8, "Q", 64, y + 15, 18, y + 8, "Z"])
	for d in [ends, band]:
		_out.append('<path d="%s" fill="%s" stroke="%s" stroke-width="2.6" stroke-linejoin="round"/>' % [d, INK, INK])
	_out.append('<path d="%s" fill="%s"/>' % [ends, dark])
	_out.append('<path d="%s" fill="%s"/>' % [band, sc])
	# the lettering follows the scroll's sag
	var sag := 3.5
	var rr := (46.0 * 46.0 + sag * sag) / (2.0 * sag)
	_letters(text, Vector2(64, y + sag - rr), 9.5, tc, rr, true, 76.0)


# --- medals and ribbons ------------------------------------------------------------------

## A medal: the ribbon it hangs from, the ring, and the pendant (devices,
## centred on the pendant).
static func _medal(spec: Dictionary) -> void:
	var drape := "M42 4L86 4L86 38L64 50L42 38Z"
	_defs.append('<clipPath id="%s-r"><path d="%s"/></clipPath>' % [_id, drape])
	_out.append('<path d="%s" fill="%s" stroke="%s" stroke-width="2.8" stroke-linejoin="round"/>' % [drape, INK, INK])
	_out.append('<g clip-path="url(#%s-r)">' % _id)
	_stripes(spec.get("rib", ["blue"]), 42.0, 0.0, 44.0, 52.0)
	_out.append('<path d="M42 4L86 4" stroke="#000" stroke-opacity="0.25" stroke-width="5"/>')
	_out.append("</g>")
	_sheen(drape)
	var metal := col(spec.get("metal", "@gold"))
	_out.append('<path d="M64 47A5 5 0 1 0 64.1 47Z" fill="none" stroke="%s" stroke-width="5"/>' % INK)
	_out.append('<path d="M64 47A5 5 0 1 0 64.1 47Z" fill="none" stroke="%s" stroke-width="2.6"/>' % metal)
	for c in spec.get("c", []):
		_charge(c, Vector2(64, 88))


## Vertical stripes of ribbon across [x, x + w]: colours, each optionally
## "colour:weight".
static func _stripes(stripes: Array, x: float, y: float, w: float, h: float) -> void:
	var total := 0.0
	var parts := []
	for s in stripes:
		var bits := String(s).split(":")
		var wt := float(bits[1]) if bits.size() > 1 else 1.0
		parts.append([bits[0], wt])
		total += wt
	var at := x
	for p: Array in parts:
		var sw: float = float(p[1]) / total * w
		_rect(at, y, sw + 0.05, h, col(p[0]))
		at += sw


## A ribbon rack: the bars worn in place of the medals, rows of up to three.
## [stripes..] per bar; a bar's stripes may end with "*" for a small star on it.
static func _rack(spec: Dictionary) -> void:
	var bars: Array = spec.get("bars", [])
	var bw := 34.0
	var bh := 13.0
	var rows := ceili(bars.size() / 3.0)
	var top := 64.0 - rows * (bh + 3.0) * 0.5
	var i := 0
	for row in rows:
		var n := mini(3, bars.size() - i)
		var x0 := 64.0 - n * (bw + 2.0) * 0.5
		for k in n:
			var stripes: Array = (bars[i] as Array).duplicate()
			var star := false
			if not stripes.is_empty() and String(stripes[-1]) == "*":
				stripes.pop_back()
				star = true
			var x := x0 + k * (bw + 2.0)
			var y := top + row * (bh + 3.0)
			_out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s" stroke="%s" stroke-width="2.4"/>' % [_n(x), _n(y), _n(bw), _n(bh), INK, INK])
			_stripes(stripes, x, y, bw, bh)
			_out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="#fff" fill-opacity="0.12"/>' % [_n(x), _n(y), _n(bw), _n(bh * 0.4)])
			if star:
				_out.append('<path d="%s" fill="%s" stroke="%s" stroke-width="0.8"/>' % [_star_d(x + bw * 0.5, y + bh * 0.52, 5.2, 2.1, 5), col("@silver"), INK])
			i += 1


# --- colours and paths --------------------------------------------------------------------

## A colour: a name from the palette, "#rrggbb", or "@gold" / "@silver" /
## "@bronze" for metal (a gradient, defined the first time it's used).
static func col(c: Variant) -> String:
	var s := str(c)
	if s.begins_with("@"):
		var m := s.substr(1)
		if not _used.has(m) and METALS.has(m):
			_used[m] = true
			var st: Array = METALS[m]
			_defs.append('<linearGradient id="%s-%s" x1="0" y1="0" x2="0.35" y2="1"><stop offset="0" stop-color="%s"/><stop offset="0.38" stop-color="%s"/><stop offset="0.72" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient>' % [_id, m, st[0], st[1], st[2], st[3]])
		return "url(#%s-%s)" % [_id, m]
	if s.begins_with("#"):
		return s
	return String(PALETTE.get(s, s))


## A darker shade of a colour (metal stays metal).
static func _shade(c: String, k := 0.7) -> String:
	if not c.begins_with("#"):
		return c
	var cc := Color(c)
	return "#" + Color(cc.r * k, cc.g * k, cc.b * k).to_html(false)


static func _n(v: float) -> String:
	var s := "%.1f" % v
	return s.substr(0, s.length() - 2) if s.ends_with(".0") else s


## A path from commands and numbers: ["M", 10, 20, "L", 30, 40, "Z"].
static func _d(a: Array) -> String:
	var parts := PackedStringArray()
	for v in a:
		parts.append(v if v is String else _n(float(v)))
	return " ".join(parts)


static func _rect(x: float, y: float, w: float, h: float, c: String) -> void:
	_out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % [_n(x), _n(y), _n(w), _n(h), c])


static func _fill(d: String, c: String) -> void:
	_out.append('<path d="%s" fill="%s"/>' % [d, c])


static func _circ(cx: float, cy: float, r: float) -> String:
	return _d(["M", cx - r, cy, "A", r, r, "0 1 0", cx + r, cy, "A", r, r, "0 1 0", cx - r, cy, "Z"])


static func _ellipse(cx: float, cy: float, rx: float, ry: float) -> String:
	return _d(["M", cx - rx, cy, "A", rx, ry, "0 1 0", cx + rx, cy, "A", rx, ry, "0 1 0", cx - rx, cy, "Z"])


static func _star_d(cx: float, cy: float, ro: float, ri: float, n: int, rot_deg := -90.0) -> String:
	var q := PackedStringArray()
	for i in n * 2:
		var a := deg_to_rad(rot_deg) + PI * i / n
		var r := ro if i % 2 == 0 else ri
		q.append(("M" if i == 0 else "L") + _n(cx + cos(a) * r) + " " + _n(cy + sin(a) * r))
	return "".join(q) + "Z"


static func _gear_d(cx: float, cy: float, ro: float, ri: float, teeth: int) -> String:
	var q := PackedStringArray()
	var n := teeth * 4
	for i in n:
		var a := TAU * i / n - PI * 0.5
		var r := ro if (i % 4) in [1, 2] else ri
		q.append(("M" if i == 0 else "L") + _n(cx + cos(a) * r) + " " + _n(cy + sin(a) * r))
	return "".join(q) + "Z"
