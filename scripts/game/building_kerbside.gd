class_name BuildingKerbside
extends RefCounted
## What stands at the kerb: street lamps (a town's steel columns, a village's
## lamp on a wooden pole, the square's lanterns), hydrants, stop signs, a
## farm's mailbox on its post, the electricity board's cabinet. Each in a kit
## at its foot; a lamp's arm reaches along +x, a sign or a cabinet faces -z.
## Their lenses glow from Decor (its _lens), where the lamp heads hang.

const COLUMN := Color(0.3, 0.32, 0.32)
const HERITAGE := Color(0.12, 0.16, 0.13)


## A town's street lamp: a steel column (a base with its service door, tapered
## up 6 m), an outreach arm sweeping up and out, the lantern at its end, its
## underside (the glow, 6.05 m up and 1.44 m out) a flat lens.
static func column(k: BuildingKit) -> void:
	k.cyl(0.17, 0.2, 0.9, Vector3(0, 0.45, 0), "metal_dark", COLUMN.darkened(0.1), Vector3.ZERO, 12)
	k.box(Vector3(0.14, 0.34, 0.02), Vector3(0, 0.5, -0.18), "metal_dark", COLUMN.darkened(0.2), Vector3.ZERO, false)
	k.cyl(0.19, 0.19, 0.04, Vector3(0, 0.92, 0), "metal_dark", COLUMN, Vector3.ZERO, 12, false)
	k.cyl(0.055, 0.1, 5.3, Vector3(0, 0.9 + 2.65, 0), "metal_dark", COLUMN, Vector3.ZERO, 10)
	# the arm: up out of the column's top, curving out to the lantern
	var prev := Vector3(0, 6.15, 0)
	for i in 6:
		var t := (i + 1) / 6.0
		var p := Vector3(1.2 * t, 6.15 + 0.2 * sin(t * PI * 0.5), 0)
		k.rod(prev, p, 0.04, "metal_dark", COLUMN, 8)
		prev = p
	# The socket drops into the cast head; the lens stays at its lighting anchor.
	k.rod(prev, Vector3(1.2, 6.21, 0), 0.04, "metal_dark", COLUMN, 8)
	# the lantern: a cast head, its lens under it
	k.part(Res.sphere(0.5, 10), "metal_dark", Transform3D(Basis.from_scale(Vector3(0.7, 0.18, 0.32)), Vector3(1.44, 6.17, 0)), COLUMN.lightened(0.05))
	k.box(Vector3(0.56, 0.05, 0.27), Vector3(1.44, 6.09, 0), "metal_dark", COLUMN.darkened(0.15), Vector3.ZERO, false)


## A village's lamp on its wooden pole: the pole, a steel bracket out from it,
## an enamelled shade over the bulb (its underside 5.33 m up, 1.0 m out).
static func pole_lamp(k: BuildingKit) -> void:
	k.cyl(0.085, 0.12, 6.0, Vector3(0, 3.0, 0), "wood_dark", Color(0.3, 0.24, 0.17), Vector3.ZERO, 8)
	k.rod(Vector3(0, 5.75, 0), Vector3(0.95, 5.75, 0), 0.025, "metal_dark", Color(0.2, 0.22, 0.21), 6)
	k.rod(Vector3(0, 5.3, 0), Vector3(0.6, 5.73, 0), 0.02, "metal_dark", Color(0.2, 0.22, 0.21), 6, false)
	k.cyl(0.03, 0.03, 0.18, Vector3(0.98, 5.65, 0), "metal_dark", Color(0.2, 0.22, 0.21), Vector3.ZERO, 6, false)
	k.cyl(0.06, 0.3, 0.16, Vector3(1.0, 5.47, 0), "paint", Color(0.22, 0.32, 0.25), Vector3.ZERO, 14)
	k.cyl(0.31, 0.31, 0.02, Vector3(1.0, 5.38, 0), "paint", Color(0.9, 0.9, 0.86), Vector3.ZERO, 14, false)


## A heritage lantern on the square: a cast base with its mouldings, a fluted
## column, the ladder bar under the lantern, the lantern (its glass, the
## glow, about 4.4 m up), its roof and finial.
static func lantern_post(k: BuildingKit) -> void:
	var c := HERITAGE
	k.cyl(0.2, 0.24, 0.12, Vector3(0, 0.06, 0), "metal_dark", c, Vector3.ZERO, 12)
	k.cyl(0.14, 0.2, 0.55, Vector3(0, 0.395, 0), "metal_dark", c, Vector3.ZERO, 12)
	k.cyl(0.17, 0.17, 0.06, Vector3(0, 0.7, 0), "metal_dark", c.lightened(0.05), Vector3.ZERO, 12, false)
	k.cyl(0.055, 0.075, 3.0, Vector3(0, 0.7 + 1.5, 0), "metal_dark", c, Vector3.ZERO, 10)
	for i in 8:
		var a := TAU * i / 8.0
		k.box(Vector3(0.012, 2.6, 0.012), Vector3(cos(a) * 0.07, 1.95, sin(a) * 0.07), "metal_dark", c.lightened(0.08), Vector3.ZERO, false)
	k.cyl(0.11, 0.08, 0.14, Vector3(0, 3.77, 0), "metal_dark", c, Vector3.ZERO, 10)
	k.rod(Vector3(-0.32, 3.9, 0), Vector3(0.32, 3.9, 0), 0.018, "metal_dark", c, 6, false)
	# the lantern: four glazed sides between its frame, its roof and finial
	k.cyl(0.16, 0.12, 0.08, Vector3(0, 4.0, 0), "metal_dark", c, Vector3(0, PI * 0.25, 0), 4)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.025, 0.5, 0.025), Vector3(sx * 0.15, 4.3, sz * 0.15), "metal_dark", c, Vector3.ZERO, false)
	k.cyl(0.0, 0.24, 0.22, Vector3(0, 4.66, 0), "metal_dark", c, Vector3(0, PI * 0.25, 0), 4)
	k.cyl(0.25, 0.25, 0.03, Vector3(0, 4.56, 0), "metal_dark", c.lightened(0.05), Vector3(0, PI * 0.25, 0), 4, false)
	k.part(Res.sphere(0.05, 6), "metal_dark", Transform3D(Basis.IDENTITY, Vector3(0, 4.83, 0)), c)


## A pillar hydrant: its flange on the pavement, the barrel, the bonnet
## with its operating nut, two hose outlets with their caps on chains.
static func hydrant(k: BuildingKit, col := Color(0.7, 0.12, 0.08)) -> void:
	k.cyl(0.17, 0.17, 0.05, Vector3(0, 0.025, 0), "paint", col.darkened(0.2), Vector3.ZERO, 12)
	for i in 6:
		var a := TAU * i / 6.0
		k.cyl(0.02, 0.02, 0.03, Vector3(cos(a) * 0.14, 0.06, sin(a) * 0.14), "metal_dark", Color(0.2, 0.2, 0.2), Vector3.ZERO, 6, false)
	k.cyl(0.11, 0.12, 0.55, Vector3(0, 0.33, 0), "paint", col, Vector3.ZERO, 12)
	k.cyl(0.14, 0.14, 0.05, Vector3(0, 0.6, 0), "paint", col.darkened(0.08), Vector3.ZERO, 12, false)
	k.part(Res.sphere(0.12, 10), "paint", Transform3D(Basis.from_scale(Vector3(1.0, 0.7, 1.0)), Vector3(0, 0.64, 0)), col)
	k.cyl(0.03, 0.03, 0.06, Vector3(0, 0.74, 0), "metal_dark", Color(0.3, 0.3, 0.3), Vector3(0, PI * 0.2, 0), 5, false)
	for sx: float in [-1.0, 1.0]:
		k.cyl(0.045, 0.045, 0.1, Vector3(sx * 0.15, 0.42, 0), "paint", col, Vector3(0, 0, PI * 0.5), 10, false)
		k.cyl(0.055, 0.055, 0.04, Vector3(sx * 0.21, 0.42, 0), "metal_dark", Color(0.62, 0.55, 0.32), Vector3(0, 0, PI * 0.5), 6, false)
		k.rod(Vector3(sx * 0.21, 0.4, 0.03), Vector3(sx * 0.1, 0.5, 0.06), 0.005, "steel", Color(0.55, 0.55, 0.55), 3, false)


## A stop sign on its post: the red octagon in its white border, a bare
## galvanised back, its two brackets on the post.
static func stop_sign(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	k.cyl(0.035, 0.035, 2.4, Vector3(0, 1.2, 0), "steel", Color(0.55, 0.56, 0.55), Vector3.ZERO, 8)
	# Turn the octagon within its own plane before tipping it upright, so
	# the face stays parallel to the lettering.
	var face := Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI / 8.0)
	k.part(Res.cyl(0.39, 0.39, 0.02, 8), "steel", Transform3D(face, Vector3(0, 2.15, -0.05)), Color(0.6, 0.61, 0.6))
	k.part(Res.cyl(0.38, 0.38, 0.005, 8), "car_paint", Transform3D(face, Vector3(0, 2.15, -0.062)), Color(0.92, 0.92, 0.9), false)
	k.part(Res.cyl(0.345, 0.345, 0.006, 8), "car_paint", Transform3D(face, Vector3(0, 2.15, -0.066)), Color(0.72, 0.07, 0.06), false)
	stop_word(k.at_point(Vector3(0, 2.15, -0.071)), Color(0.95, 0.95, 0.92))
	for y: float in [1.98, 2.32]:
		k.box(Vector3(0.1, 0.03, 0.05), Vector3(0, y, -0.025), "steel", Color(0.5, 0.5, 0.5), Vector3.ZERO, false)


## Strokes over a unit glyph (x0, y0, x1, y1, y up) for S, T, O, P.
const STOP_GLYPHS := [
	[[0.0, 0.0, 1.0, 0.18], [0.72, 0.0, 1.0, 0.5], [0.0, 0.41, 1.0, 0.59], [0.0, 0.5, 0.28, 1.0], [0.0, 0.82, 1.0, 1.0]],
	[[0.36, 0.0, 0.64, 1.0], [0.0, 0.82, 1.0, 1.0]],
	[[0.0, 0.0, 0.28, 1.0], [0.72, 0.0, 1.0, 1.0], [0.0, 0.0, 1.0, 0.18], [0.0, 0.82, 1.0, 1.0]],
	[[0.0, 0.0, 0.28, 1.0], [0.0, 0.82, 1.0, 1.0], [0.0, 0.41, 1.0, 0.59], [0.72, 0.5, 1.0, 1.0]],
]


## STOP across a sign's face (in a kit at its middle, facing -z): four letters
## 0.11 wide and 0.15 high.
static func stop_word(k: BuildingKit, col: Color) -> void:
	var w := 0.11
	var h := 0.15
	var gap := 0.028
	var x0 := -(4.0 * w + 3.0 * gap) * 0.5
	for g in 4:
		# (seen from -z, the glyph's left is the kit's +x)
		var gx := -(x0 + g * (w + gap))
		for st: Array in STOP_GLYPHS[g]:
			var sz := Vector3((st[2] - st[0]) * w, (st[3] - st[1]) * h, 0.004)
			k.box(sz, Vector3(gx - (st[0] + st[2]) * 0.5 * w, ((st[1] + st[3]) * 0.5 - 0.5) * h, -0.002), "car_paint", col, Vector3.ZERO, false)


## A farm's mailbox on its post: the round-topped box, its door, the red
## flag at its side (up or down), the post with a brace.
static func mailbox(k: BuildingKit, col: Color, up: bool) -> void:
	k.box(Vector3(0.08, 1.0, 0.08), Vector3(0, 0.5, 0), "wood_dark", Color(0.32, 0.25, 0.17))
	k.box(Vector3(0.06, 0.04, 0.4), Vector3(0, 0.97, 0), "wood_dark", Color(0.32, 0.25, 0.17))
	k.box(Vector3(0.22, 0.16, 0.44), Vector3(0, 1.07, 0), "car_paint", col)
	k.cyl(0.11, 0.11, 0.44, Vector3(0, 1.15, 0), "car_paint", col, Vector3(PI * 0.5, 0, 0), 12)
	k.box(Vector3(0.21, 0.24, 0.02), Vector3(0, 1.09, -0.22), "car_paint", col.darkened(0.1), Vector3.ZERO, false)
	var flag := Basis(Vector3.RIGHT, 0.0 if up else PI * 0.5)
	k.part(Res.box(Vector3(0.012, 0.22, 0.03)), "paint", Transform3D(flag, Vector3(0.125, 1.1, 0.1)) * Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), Color(0.82, 0.12, 0.08), false)
	k.part(Res.box(Vector3(0.012, 0.08, 0.1)), "paint", Transform3D(flag, Vector3(0.125, 1.1, 0.1)) * Transform3D(Basis.IDENTITY, Vector3(0, 0.19, 0.03)), Color(0.82, 0.12, 0.08), false)


## The electricity board's cabinet: green steel on a concrete plinth, double
## doors with their handle and lock, louvres low and high for its cooling, a
## danger plate, its roof overhanging.
static func cabinet(k: BuildingKit) -> void:
	var g := Color(0.3, 0.4, 0.3)
	k.box(Vector3(1.2, 0.12, 0.7), Vector3(0, 0.06, 0), "concrete", Color(0.5, 0.5, 0.48))
	k.box(Vector3(1.1, 1.3, 0.6), Vector3(0, 0.77, 0), "paint", g)
	k.box(Vector3(1.18, 0.05, 0.68), Vector3(0, 1.445, 0), "paint", g.darkened(0.12))
	k.plate(Vector3(0.012, 1.18, 0.008), Vector3(0, 0.77, -0.302), "paint", g.darkened(0.3))
	for sx: float in [-1.0, 1.0]:
		BuildingOpenings.louvre(k.at_point(Vector3(sx * 0.27, 0, -0.302), Vector3(0, PI, 0)), Vector3(0, 0.35, 0), Vector2(0.36, 0.2), g.darkened(0.2), "paint")
		BuildingOpenings.louvre(k.at_point(Vector3(sx * 0.27, 0, -0.302), Vector3(0, PI, 0)), Vector3(0, 1.22, 0), Vector2(0.36, 0.14), g.darkened(0.2), "paint")
		k.box(Vector3(0.03, 0.14, 0.03), Vector3(sx * 0.05, 0.85, -0.31), "metal_dark", Color(0.18, 0.18, 0.18), Vector3.ZERO, false)
	k.plate(Vector3(0.2, 0.15, 0.006), Vector3(0.27, 0.9, -0.305), "paint", Color(0.95, 0.8, 0.1))
	k.prism(Vector3(0.1, 0.07, 0.004), Vector3(0.27, 0.91, -0.309), "plain_dark", Color(0.05, 0.05, 0.05), Vector3(PI, 0, 0), false)
