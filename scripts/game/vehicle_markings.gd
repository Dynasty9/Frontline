class_name VehicleMarkings
extends RefCounted
## Surface-projected paint, lettering and wear patches. Family adapters own
## projection and symbols; this owns triangulation and consistent facing.

static func polygons(k: VehicleModels, parent: Node3D, outlines: Array, project: Callable, outward: Vector3, col, material := "paint", omit_wreck := true, divisions := 1) -> void:
	if omit_wreck and k.wreck:
		return
	var surface := VehicleSurface.new(project, outward)
	for points in outlines:
		var outline := PackedVector2Array(points)
		if outline.size() < 3 or Geometry2D.triangulate_polygon(outline).is_empty():
			continue
		k._add(parent, surface.patch(outline, 0.0, 0.0, divisions), material, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)


# --- stencil lettering ----------------------------------------------------------

## The seven segments of a stencilled digit as strokes across a unit cell (x
## right, y up), run clockwise from the top: a the top, b top right, c bottom
## right, d the bottom, e bottom left, f top left, g the middle bar; and i, a
## centre upright (a T's stem, the 1 of a hull number).
const SEGMENTS := {"a": [0.0, 1.0, 1.0, 1.0], "b": [1.0, 1.0, 1.0, 0.5], "c": [1.0, 0.5, 1.0, 0.0], "d": [1.0, 0.0, 0.0, 0.0],
	"e": [0.0, 0.0, 0.0, 0.5], "f": [0.0, 0.5, 0.0, 1.0], "g": [0.0, 0.5, 1.0, 0.5], "i": [0.5, 0.0, 0.5, 1.0]}

## The segments each character lights: the digits and the letters a stencil
## can cut (tail codes, serials, USAF, number plates).
const GLYPHS := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc",
	"8": "abcdefg", "9": "abcdfg", "A": "abcefg", "C": "afed", "E": "afedg", "F": "afeg", "S": "afgcd", "T": "ai", "U": "bcdef", "-": "g",
	"H": "bcefg", "J": "bcde", "L": "def", "P": "abefg"}

## Painted stroke lettering for tail codes: each character's strokes
## [x0, y0, x1, y1] in units of the text's height, from its baseline.
const STROKE_FONT := {
	"W": [[0, 1, 0.15, 0], [0.15, 0, 0.3, 0.62], [0.3, 0.62, 0.45, 0], [0.45, 0, 0.6, 1]],
	"N": [[0, 0, 0, 1], [0, 1, 0.55, 0], [0.55, 0, 0.55, 1]],
	"H": [[0, 0, 0, 1], [0.55, 0, 0.55, 1], [0, 0.5, 0.55, 0.5]],
	"1": [[0.3, 0, 0.3, 1], [0.3, 1, 0.1, 0.8]],
	"0": [[0, 0, 0.5, 0], [0.5, 0, 0.5, 1], [0.5, 1, 0, 1], [0, 1, 0, 0]],
	"6": [[0.5, 1, 0, 1], [0, 1, 0, 0], [0, 0, 0.5, 0], [0.5, 0, 0.5, 0.5], [0.5, 0.5, 0, 0.5]],
	"8": [[0, 0, 0.5, 0], [0.5, 0, 0.5, 1], [0.5, 1, 0, 1], [0, 1, 0, 0], [0, 0.5, 0.5, 0.5]],
	"9": [[0, 0, 0.5, 0], [0.5, 0, 0.5, 1], [0.5, 1, 0, 1], [0, 1, 0, 0.5], [0, 0.5, 0.5, 0.5]],
}

## How each family's lettering is laid out, every length a fraction of the
## text's height: a character's `cell` width, the `advance` from one to the
## next and the `gap` closing the last, the `stroke` width and how far each
## stroke runs past its ends (`extend`), the middle bar's length (`middle`, a
## fraction of the cell), the 1 moved across its cell (`one`, cells), strokes
## kept inside their cell (`inset`), characters drawn differently (`glyphs`)
## or narrower (`narrow`), and the stroke pieces' longest length on a curved
## skin (`piece`).
const LETTERING := {
	# Stencilled codes and serials on combat aircraft: a short middle bar.
	"stencil": {"cell": 0.58, "advance": 0.86, "gap": 0.28, "stroke": 0.13, "extend": 0.065, "middle": 0.85, "piece": 0.2},
	# A transport's tail number: its 1 set in toward the middle of the cell.
	"tail": {"cell": 0.55, "advance": 0.82, "gap": 0.27, "stroke": 0.13, "extend": 0.06, "one": -0.4},
	# A hull number on a ship's bows: square bars kept inside the cell, the 1
	# a single upright down its middle.
	"hull": {"cell": 0.56, "advance": 0.78, "gap": 0.22, "stroke": 0.16, "inset": true, "glyphs": {"1": "i"}},
	# Painted stroke lettering from STROKE_FONT, the 1 narrower.
	"stroke": {"cell": 1.0, "advance": 0.62, "gap": 0.06, "stroke": 0.13, "extend": 0.065, "font": true, "narrow": {"1": 0.42}},
}


## The centre lines of `text`, `height` tall, laid out in `style` (a
## LETTERING key) and centred on `center`, as strokes [a, b] (Vector2 pairs,
## x along the line, y up). A character the style can't draw still takes its
## place, as a space does.
static func digit_strokes(text: String, height: float, center := Vector2.ZERO, style := "stencil") -> Array:
	var spec: Dictionary = LETTERING[style]
	var cell: float = height * float(spec.get("cell", 0.58))
	var advance: float = height * float(spec.get("advance", 0.86))
	var stroke: float = height * float(spec.get("stroke", 0.13))
	var middle: float = spec.get("middle", 1.0)
	var one: float = spec.get("one", 0.0)
	var inset: bool = spec.get("inset", false)
	var font: bool = spec.get("font", false)
	var glyphs: Dictionary = spec.get("glyphs", {})
	var narrow: Dictionary = spec.get("narrow", {})
	var total := -height * float(spec.get("gap", 0.28))
	for i in text.length():
		total += height * float(narrow[text[i]]) if narrow.has(text[i]) else advance
	var x := center.x - total * 0.5
	var y0 := center.y - height * 0.5
	var out: Array = []
	for i in text.length():
		var ch := text[i]
		var left := x + (cell * one if ch == "1" else 0.0)
		x += height * float(narrow[ch]) if narrow.has(ch) else advance
		var strokes: Array = []
		if font:
			strokes = STROKE_FONT.get(ch, [])
		else:
			for segment in String(glyphs.get(ch, GLYPHS.get(ch, ""))):
				var seg: Array = SEGMENTS[segment]
				strokes.append([seg[0], seg[1], middle if segment == "g" else seg[2], seg[3]])
		for seg: Array in strokes:
			var a := Vector2(left + float(seg[0]) * cell, y0 + float(seg[1]) * height)
			var b := Vector2(left + float(seg[2]) * cell, y0 + float(seg[3]) * height)
			if inset:
				# Square bars stay inside the cell: the edges of the cell carry
				# each bar's outer face, not its centre line.
				if is_equal_approx(a.y, b.y):
					var dy := stroke * 0.5 * (1.0 if float(seg[1]) < 0.25 else (-1.0 if float(seg[1]) > 0.75 else 0.0))
					a.y += dy
					b.y += dy
				elif is_equal_approx(a.x, b.x):
					var dx := stroke * 0.5 * (1.0 if float(seg[0]) < 0.25 else (-1.0 if float(seg[0]) > 0.75 else 0.0))
					a.x += dx
					b.x += dx
			out.append([a, b])
	return out


## `text` in `style`, `height` tall and centred on `center`, as the stroke
## quads VehicleMarkings.polygons lays on a surface (each a four-point Array).
static func digit_quads(text: String, height: float, center := Vector2.ZERO, style := "stencil") -> Array:
	var spec: Dictionary = LETTERING[style]
	return stroke_quads(digit_strokes(text, height, center, style), height * float(spec.get("stroke", 0.13)), height * float(spec.get("extend", 0.0)), height * float(spec.get("piece", 0.0)))


## Strokes [a, b] of width `width` as quads, each run `extend` past both ends
## and, when `piece` > 0, cut into pieces no longer than that so they follow
## a curved skin.
static func stroke_quads(strokes: Array, width: float, extend := 0.0, piece := 0.0) -> Array:
	var out: Array = []
	for s: Array in strokes:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var d := (b - a).normalized()
		var side := Vector2(-d.y, d.x) * width * 0.5
		a -= d * extend
		b += d * extend
		var n := maxi(1, ceili(a.distance_to(b) / piece)) if piece > 0.0 else 1
		for i in n:
			var p0 := a.lerp(b, float(i) / n)
			var p1 := a.lerp(b, float(i + 1) / n)
			out.append([p0 - side, p1 - side, p1 + side, p0 + side])
	return out


## Strokes as a flat list of 2D triangles (three points each), for a family
## that builds its own decal mesh.
static func stroke_triangles(strokes: Array, width: float, extend := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for s: Array in strokes:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var d := (b - a).normalized()
		var side := Vector2(-d.y, d.x) * width * 0.5
		a -= d * extend
		b += d * extend
		out.append_array([a + side, a - side, b - side, a + side, b - side, b + side])
	return out


## Upright and level strokes as the rectangles they cover (painted bars laid
## one at a time, embossed characters).
static func stroke_rects(strokes: Array, width: float, extend := 0.0) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for s: Array in strokes:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
		if absf(a.y - b.y) <= absf(a.x - b.x):
			out.append(Rect2(lo.x - extend, lo.y - width * 0.5, hi.x - lo.x + extend * 2.0, width))
		else:
			out.append(Rect2(lo.x - width * 0.5, lo.y - extend, width, hi.y - lo.y + extend * 2.0))
	return out


## Painted stencil lettering (a tail code, a serial, a hull number): `text`
## `height` tall in `style`, centred on `center` in the domain `project` maps
## onto the skin (2D metres, x along the line, y up), facing `outward`. Every
## family's numbers come from the one segment table, so they all delegate here
## and keep their own sizes and spacing. Gone with the paint on a wreck.
static func digits(k: VehicleModels, parent: Node3D, text: String, height: float, project: Callable, outward: Vector3, col, center := Vector2.ZERO, style := "stencil", material := "paint", omit_wreck := true, divisions := 1) -> void:
	polygons(k, parent, digit_quads(text, height, center, style), project, outward, col, material, omit_wreck, divisions)


# --- number plates --------------------------------------------------------------

const PLATE := Color(0.85, 0.84, 0.78)
const PLATE_INK := Color(0.16, 0.16, 0.17)
## The characters a registration is drawn from: the letters a stencil cuts
## that can't be read as digits.
const PLATE_LETTERS := "ACEFHJLPU"
const PLATE_DIGITS := "0123456789"

static var _embossed := {}

## A number plate: the pressed plate in a black holder, its registration
## embossed as raised stencil bars and two screws holding it on. `center` and
## `size` (width, height) are the old plate box's: its outer face stays `depth`
## / 2 in front of `center` along `facing` (the direction it faces before
## `tilt`, the old box's turn about X), and it reads left to right as seen
## from in front. `text` is the registration (letters and digits a stencil can
## cut, spaces between groups); empty draws one from `center`, so a builder
## that wants matching front and rear plates passes the same string to both.
## `holder` false bolts a bare plate straight on (a military vehicle's). The
## plate is metal: a wreck keeps it, burnt like the rest.
static func plate(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, facing := Vector3.BACK, tilt := 0.0, text := "", depth := 0.016, col := PLATE, ink := PLATE_INK, holder := true) -> void:
	var mount := k._pivot(parent, center)
	mount.basis = Basis(Vector3.RIGHT, tilt) * _facing(facing)
	var rim := minf(0.008, size.y * 0.07) if holder else 0.0
	var face := Vector2(size.x - rim * 2.0, size.y - rim * 2.0)
	if holder:
		k._box(mount, Vector3(size.x, size.y, depth * 0.75), Vector3(0, 0, -depth * 0.125), "plain_dark")
		k._box(mount, Vector3(face.x, face.y, depth * 0.25), Vector3(0, 0, depth * 0.375), "paint", col, Vector3.ZERO, false)
	else:
		k._box(mount, Vector3(size.x, size.y, depth), Vector3.ZERO, "paint", col)
	var registration := text if text != "" else _registration(center, size)
	var height := face.y * 0.62
	var count := float(registration.length()) * 0.78 - 0.22
	if count > 0.0:
		height = minf(height, face.x * 0.8 / count)
		k._add(mount, _emboss(registration, height), "paint", ink, Vector3(0, 0, depth * 0.5), Vector3.ZERO, Vector3.ONE, false)
	for s: float in [-1.0, 1.0]:
		VehicleBody.fastener(k, mount, Vector3(s * face.x * 0.45, 0, depth * 0.5), Vector3.BACK, minf(0.006, size.y * 0.06))
	k._fold(mount)


## A registration for a plate with no text of its own: letters, a space and
## digits, as many as fit, fixed by where the plate is.
static func _registration(center: Vector3, size: Vector2) -> String:
	var seed := absi(hash(Vector3i((center * 100.0).round())))
	var n := clampi(int(size.x / (size.y * 0.62)), 3, 7)
	var letters := 2 if n >= 6 else (1 if n >= 4 else 0)
	var out := ""
	for i in n:
		var pick := seed >> (i * 4)
		if i < letters:
			out += PLATE_LETTERS[posmod(pick, PLATE_LETTERS.length())]
		elif i == letters and letters > 0:
			out += " "
		else:
			out += PLATE_DIGITS[posmod(pick, PLATE_DIGITS.length())]
	return out


## Embossed characters as raised bars (their top and four sides) standing up
## from z = 0, one merged mesh per registration and height.
static func _emboss(text: String, height: float) -> ArrayMesh:
	var key := "%s|%.4f" % [text, height]
	if _embossed.has(key):
		return _embossed[key]
	var raise := clampf(height * 0.02, 0.0008, 0.0015)
	var data := [[], [], []]
	for r: Rect2 in stroke_rects(digit_strokes(text, height, Vector2.ZERO, "hull"), height * 0.16):
		var a := r.position
		var b := r.end
		VehicleSurface._quad(data, Vector3(a.x, a.y, raise), Vector3(b.x, a.y, raise), Vector3(b.x, b.y, raise), Vector3(a.x, b.y, raise), Vector3.BACK)
		# The four sides, each [from, to, outward].
		for side: Array in [[Vector2(a.x, a.y), Vector2(b.x, a.y), Vector3.DOWN], [Vector2(b.x, a.y), Vector2(b.x, b.y), Vector3.RIGHT],
				[Vector2(b.x, b.y), Vector2(a.x, b.y), Vector3.UP], [Vector2(a.x, b.y), Vector2(a.x, a.y), Vector3.LEFT]]:
			var p: Vector2 = side[0]
			var q: Vector2 = side[1]
			VehicleSurface._quad(data, Vector3(p.x, p.y, raise), Vector3(q.x, q.y, raise), Vector3(q.x, q.y, 0), Vector3(p.x, p.y, 0), side[2])
	var mesh := VehicleSurface._mesh(data)
	_embossed[key] = mesh
	return mesh


## A face's frame: local +Z along `facing`, +Y as near up as it allows, +X to
## the right of someone looking at it.
static func _facing(facing: Vector3) -> Basis:
	var z := facing.normalized()
	var up := Vector3.UP if absf(z.y) < 0.95 else Vector3.FORWARD
	var y := (up - z * up.dot(z)).normalized()
	return Basis(y.cross(z), y, z)


# --- medical crosses ------------------------------------------------------------

const CROSS_GROUND := Color(0.86, 0.86, 0.82)
const CROSS_RED := Color(0.62, 0.07, 0.06)

## The outline of a cross `span` across, its arms `bar` wide, centred on the
## origin: for a cross painted on a curved skin through polygons().
static func cross_outline(span: float, bar: float) -> PackedVector2Array:
	var a := span * 0.5
	var b := bar * 0.5
	return PackedVector2Array([Vector2(b, -a), Vector2(b, -b), Vector2(a, -b), Vector2(a, b), Vector2(b, b), Vector2(b, a),
		Vector2(-b, a), Vector2(-b, b), Vector2(-a, b), Vector2(-a, -b), Vector2(-b, -b), Vector2(-b, -a)])


## A medical cross: one painted cross on a white ground. `center`, `size` and
## `rotation` are the old ground box's (local +Z outward, `depth` thick, its
## outer face `depth` / 2 out from `center`); the cross spans `arm` and its arms
## are `bar` wide, both fractions of the ground's shorter side, painted just
## proud of the ground's face. `ground` null paints the cross straight onto a
## body that is already white: then `size` is the cross's own square and the
## cross is a painted layer `depth` thick centred on `center`, where the old
## bars were. `material` finishes the ground (a "plain" board for a removable
## panel), `bolts` fixes it with a screw in each corner. Markings are gone on a
## wreck unless `omit_wreck` is false (then everything is burnt).
static func cross(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation := Vector3.ZERO, ground = CROSS_GROUND, red := CROSS_RED, arm := 0.7, bar := 0.22, depth := 0.02, material := "paint", bolts := false, omit_wreck := true) -> void:
	if omit_wreck and k.wreck:
		return
	var basis := Basis.from_euler(rotation)
	var span := minf(size.x, size.y)
	var outline := cross_outline(span * arm, span * bar)
	if ground is Color:
		k._box(parent, Vector3(size.x, size.y, depth), center, material, ground, rotation, false)
		var surface := VehicleSurface.plane(center + basis.z * (depth * 0.5 + 0.0015), basis.x, basis.y)
		k._add(parent, surface.patch(outline), "paint", red, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
		if bolts:
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var at := Vector2(corner.x * (size.x * 0.5 - span * 0.06), corner.y * (size.y * 0.5 - span * 0.06))
				VehicleBody.fastener(k, parent, center + basis * Vector3(at.x, at.y, depth * 0.5), basis.z, minf(0.01, span * 0.02))
	else:
		var surface := VehicleSurface.plane(center, basis.x, basis.y)
		k._add(parent, surface.patch(outline, depth * 0.5, depth), "paint", red, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
