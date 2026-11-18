class_name BuildingFittings
extends RefCounted
## The fittings and stores buildings share: rainwater goods (gutters, hoppers,
## downpipes), chimneys, flues and stacks, the plant on a roof (an air
## conditioner, a water tank, a dish), masts and aerials, flagpoles, lamps,
## what's fixed to a house's walls (a meter box, an outside tap, an air
## conditioner, a dish, the number and letterbox by its door, the mat on its
## step), and the drums, crates and pallets lying round every yard, depot and dock.
## Positions are in the kit's frame (see BuildingKit); y = 0 is the ground or
## whatever the fitting stands on.

const IRON := Color(0.21, 0.22, 0.21)  # painted cast iron (gutters, downpipes)
const TERRACOTTA := Color(0.56, 0.3, 0.2)
const DRUMS := [Color(0.24, 0.32, 0.42), Color(0.5, 0.17, 0.12), Color(0.3, 0.33, 0.2), Color(0.58, 0.45, 0.14), Color(0.42, 0.42, 0.4)]


# --- rainwater -------------------------------------------------------------------------

## A gutter from `a` to `b` (level), its open side up and its front lip
## towards `outward`: a channel on brackets, a rolled front bead, stopped ends.
static func gutter(k: BuildingKit, a: Vector3, b: Vector3, outward: Vector3, col := IRON) -> void:
	var dir := b - a
	var ln := dir.length()
	if ln < 0.1:
		return
	var z := Vector3(outward.x, 0, outward.z).normalized()
	var x := Vector3.UP.cross(z)
	var key := "gutter|%.2f" % snappedf(ln, 0.05)
	k.part(BuildingKit.shape(key, func() -> Array:
		var l := snappedf(ln, 0.05)
		var out: Array = [
			BuildingKit.piece(Vector3(l, 0.012, 0.1), Vector3(0, -0.045, 0)),
			BuildingKit.piece(Vector3(l, 0.09, 0.024), Vector3(0, -0.0, 0.05)),
			BuildingKit.piece(Vector3(l, 0.1, 0.012), Vector3(0, 0.005, -0.05)),
		]
		for e: float in [-1.0, 1.0]:
			out.append(BuildingKit.piece(Vector3(0.012, 0.09, 0.11), Vector3(e * l * 0.5, -0.005, 0)))
		return out), "paint", Transform3D(Basis(x, Vector3.UP, z), (a + b) * 0.5), col)


## A hopper head at `p` (its rim), collecting from a scupper or a gutter outlet.
static func hopper(k: BuildingKit, p: Vector3, col := IRON) -> void:
	k.cyl(0.13, 0.07, 0.2, p + Vector3(0, -0.1, 0), "paint", col, Vector3(0, PI * 0.25, 0), 4)
	k.plate(Vector3(0.2, 0.03, 0.2), p + Vector3(0, 0.0, 0), "paint", col.lightened(0.05))


## A downpipe from a gutter outlet at `top` down to `bottom` by the foot of
## the wall: square-section (as most are), a swan neck back to the wall if
## they don't line up, collared joints, clips every metre and a half holding
## it to the wall, a shoe kicking the water out at the foot.
static func downpipe(k: BuildingKit, top: Vector3, bottom: Vector3, r := 0.04, col := IRON) -> void:
	var w := r * 2.0
	var off := Vector2(bottom.x - top.x, bottom.z - top.z)
	var pts: Array[Vector3] = [top]
	if off.length() > 0.03:
		pts.append(top + Vector3(0, -0.12, 0))
		pts.append(Vector3(bottom.x, top.y - 0.12 - maxf(0.2, off.length() * 0.9), bottom.z))
	pts.append(bottom + Vector3(0, 0.14, 0))
	for i in pts.size() - 1:
		k.bar(pts[i], pts[i + 1], w, w, "paint", col)
		if i > 0:
			k.plate(Vector3(w + 0.024, 0.06, w + 0.024), pts[i], "paint", col)
	var back := Vector3(top.x - bottom.x, 0, top.z - bottom.z).normalized()
	if back.is_zero_approx():
		back = Vector3.FORWARD
	var run := pts[pts.size() - 2].y - pts[pts.size() - 1].y
	var n := maxi(1, int(run / 1.5))
	for i in n:
		var y := bottom.y + 0.6 + i * run / n
		k.plate(Vector3(w + 0.03, 0.045, w + 0.03) + Vector3(absf(back.z), 0, absf(back.x)) * 0.08, Vector3(bottom.x, y, bottom.z) - back * 0.012, "paint", col.darkened(0.15))
	var foot := bottom + Vector3(0, 0.14, 0)
	k.bar(foot, foot - back * 0.15 + Vector3(0, -0.1, 0), w, w, "paint", col, false)


# --- chimneys, flues and stacks ----------------------------------------------------------

## A brick chimney stack from `base` (inside the roof) up to `top`: the stack,
## an oversailing course near the top, a cast cap and its pots.
static func chimney(k: BuildingKit, base: Vector3, size: Vector2, top: float, material := "brick", col := Color(0.56, 0.3, 0.21), pots := 2) -> void:
	var h := top - base.y
	var kind := BuildingMaterials.surface(material)
	k.box(Vector3(size.x, h, size.y), base + Vector3(0, h * 0.5, 0), kind, col)
	k.box(Vector3(size.x + 0.08, 0.1, size.y + 0.08), Vector3(base.x, top - 0.16, base.z), kind, col.darkened(0.08))
	k.box(Vector3(size.x + 0.1, 0.07, size.y + 0.1), Vector3(base.x, top + 0.035, base.z), kind, col.darkened(0.25))
	for i in pots:
		var x := base.x + (float(i) - (pots - 1) * 0.5) * size.x * 0.45
		k.cyl(0.1, 0.11, 0.34, Vector3(x, top + 0.24, base.z), "paint", TERRACOTTA, Vector3.ZERO, 6)
		k.cyl(0.07, 0.07, 0.01, Vector3(x, top + 0.415, base.z), "paint", Color(0.04, 0.04, 0.04), Vector3.ZERO, 6, false)


## A tall works chimney from `base`: tapered, banded with iron hoops, a cap
## round its mouth and the soot inside it.
static func stack(k: BuildingKit, base: Vector3, r_bottom: float, r_top: float, h: float, material := "brick", col := Color(0.58, 0.37, 0.28)) -> void:
	var kind := BuildingMaterials.surface(material)
	k.cyl(r_top, r_bottom, h, base + Vector3(0, h * 0.5, 0), kind, col, Vector3.ZERO, 12)
	for f: float in [0.3, 0.6, 0.88]:
		var r := lerpf(r_bottom, r_top, f) + 0.02
		k.cyl(r, r, 0.07, base + Vector3(0, h * f, 0), "metal_dark", IRON, Vector3.ZERO, 12, false)
	k.cyl(r_top + 0.05, r_top + 0.05, 0.22, base + Vector3(0, h + 0.05, 0), "concrete", Color(0.5, 0.49, 0.46), Vector3.ZERO, 12)
	k.cyl(r_top - 0.04, r_top - 0.04, 0.02, base + Vector3(0, h + 0.161, 0), "plain_dark", Color(0.03, 0.03, 0.03), Vector3.ZERO, 12, false)


## A flue or vent pipe from `base`, `h` tall, under a cowl that keeps the
## rain out: a collar where it leaves the roof, a cap on three stays.
static func flue(k: BuildingKit, base: Vector3, r: float, h: float, col := Color(0.25, 0.26, 0.25), kind := "metal_dark") -> void:
	k.cyl(r + 0.03, r + 0.05, 0.08, base + Vector3(0, 0.04, 0), kind, col.darkened(0.15), Vector3.ZERO, 10, false)
	k.cyl(r, r, h, base + Vector3(0, h * 0.5, 0), kind, col, Vector3.ZERO, 10)
	k.cyl(0.0, r * 2.3, r * 1.2, base + Vector3(0, h + r * 1.4, 0), kind, col, Vector3.ZERO, 10)
	for i in 3:
		var a := TAU * i / 3.0
		k.rod(base + Vector3(cos(a) * r, h - 0.02, sin(a) * r), base + Vector3(cos(a) * r * 1.4, h + r * 0.9, sin(a) * r * 1.4), 0.008, kind, col, 4, false)


# --- plant -------------------------------------------------------------------------------

## A split air-conditioning unit standing at `base`, facing +z turned by `yaw`:
## the casing, the fan guard and its motor, side louvres, the feet.
static func ac_unit(k: BuildingKit, base: Vector3, yaw := 0.0, col := Color(0.78, 0.78, 0.75)) -> void:
	var a := k.at_point(base, Vector3(0, yaw, 0))
	for x: float in [-0.3, 0.3]:
		a.plate(Vector3(0.06, 0.06, 0.52), Vector3(x, 0.03, 0), "metal_dark", Color(0.3, 0.3, 0.29), Vector3.ZERO, true)
	a.box(Vector3(0.8, 0.55, 0.32), Vector3(0, 0.335, 0), "paint", col)
	a.cyl(0.19, 0.19, 0.02, Vector3(-0.1, 0.335, 0.162), "plain_dark", Color(0.06, 0.06, 0.06), Vector3(PI * 0.5, 0, 0), 14, false)
	a.part(BuildingKit.ring(0.17, 0.2), "metal_dark", Mats.place(Vector3(-0.1, 0.335, 0.168), Vector3(PI * 0.5, 0, 0)), Color(0.35, 0.35, 0.34), false)
	a.plate(Vector3(0.38, 0.016, 0.01), Vector3(-0.1, 0.335, 0.172), "metal_dark", Color(0.35, 0.35, 0.34))
	a.plate(Vector3(0.016, 0.38, 0.01), Vector3(-0.1, 0.335, 0.172), "metal_dark", Color(0.35, 0.35, 0.34))
	a.cyl(0.05, 0.05, 0.03, Vector3(-0.1, 0.335, 0.17), "metal_dark", Color(0.3, 0.3, 0.3), Vector3(PI * 0.5, 0, 0), 8, false)
	for i in 5:
		a.plate(Vector3(0.18, 0.012, 0.01), Vector3(0.24, 0.17 + i * 0.075, 0.163), "paint", col.darkened(0.3))
	a.rod(Vector3(0.36, 0.12, -0.12), Vector3(0.36, 0.12, -0.4), 0.012, "metal_dark", Color(0.6, 0.45, 0.3), 4, false)


# --- on a house's walls ------------------------------------------------------------------
# (in a kit at the wall's outer face: x along it, y up from the ground, +z out)

const BRASS := Color(0.62, 0.48, 0.22)
## A house number's plate and figures: blue enamel, white, black and brass.
const NUMBERS := [[Color(0.1, 0.2, 0.45), Color(0.92, 0.92, 0.88)], [Color(0.92, 0.91, 0.86), Color(0.08, 0.08, 0.08)],
	[Color(0.12, 0.12, 0.12), Color(0.62, 0.48, 0.22)], [Color(0.55, 0.22, 0.14), Color(0.92, 0.9, 0.84)]]
const LETTERBOXES := [Color(0.15, 0.25, 0.18), Color(0.55, 0.12, 0.1), Color(0.12, 0.12, 0.12), Color(0.5, 0.5, 0.48)]
const MATS := [Color(0.5, 0.38, 0.22), Color(0.14, 0.14, 0.13), Color(0.36, 0.13, 0.1)]
const HOSES := [Color(0.15, 0.4, 0.15), Color(0.75, 0.6, 0.1), Color(0.2, 0.22, 0.25)]
## The seven segments a figure is made of ([x0, y0, x1, y1] in a cell 0.6
## wide and 1 high: top, upper right, lower right, bottom, lower left, upper
## left, middle), and which of them each of 0 to 9 lights (a bit each).
const _SEGMENTS := [[0.0, 0.84, 0.6, 1.0], [0.44, 0.5, 0.6, 1.0], [0.44, 0.0, 0.6, 0.5], [0.0, 0.0, 0.6, 0.16],
	[0.0, 0.0, 0.16, 0.5], [0.0, 0.5, 0.16, 1.0], [0.0, 0.42, 0.6, 0.58]]
const _FIGURES := [63, 6, 91, 79, 102, 109, 125, 7, 127, 111]


## The cabinet the mains come in at, on a wall with its foot at `p`: low on
## the wall for the electricity, standing on the ground for the gas (`gas`).
## A moulded box with its door, the window the meter's read through, a key
## slot, and (off the ground) the duct the cable comes up in.
static func meter_box(k: BuildingKit, p: Vector3, gas := false) -> void:
	var s := Vector3(0.45, 0.5, 0.24) if gas else Vector3(0.4, 0.55, 0.19)
	var col := Color(0.78, 0.74, 0.62) if gas else Color(0.82, 0.8, 0.73)
	k.box(s, p + Vector3(0, s.y * 0.5, s.z * 0.5), "paint", col)
	k.plate(Vector3(s.x - 0.05, s.y - 0.05, 0.01), p + Vector3(0, s.y * 0.5, s.z + 0.004), "paint", col.darkened(0.08))
	k.plate(Vector3(0.14, 0.09, 0.008), p + Vector3(0, s.y * 0.66, s.z + 0.01), "glass", Color(0.25, 0.28, 0.3))
	k.plate(Vector3(0.025, 0.04, 0.008), p + Vector3(s.x * 0.32, s.y * 0.45, s.z + 0.01), "metal_dark", Color(0.2, 0.2, 0.2))
	if p.y > 0.05:
		k.box(Vector3(0.12, p.y + 0.04, 0.1), Vector3(p.x, p.y * 0.5 - 0.02, 0.05), "paint", col.darkened(0.15))


## An air conditioner's outdoor unit on two angle brackets, their top at `p`
## (on the face): the brackets bolted to the wall, the unit on them, its pipes
## in white trunking from its side into the wall, the drain run down.
static func wall_unit(k: BuildingKit, p: Vector3, col := Color(0.8, 0.8, 0.77)) -> void:
	var steel := Color(0.32, 0.32, 0.31)
	for x: float in [-0.3, 0.3]:
		k.plate(Vector3(0.04, 0.04, 0.5), p + Vector3(x, -0.02, 0.25), "metal_dark", steel, Vector3.ZERO, true)
		k.plate(Vector3(0.05, 0.5, 0.012), p + Vector3(x, -0.25, 0.006), "metal_dark", steel)
		k.bar(p + Vector3(x, -0.46, 0.012), p + Vector3(x, -0.04, 0.42), 0.03, 0.03, "metal_dark", steel, false)
	ac_unit(k, p + Vector3(0, 0, 0.24), 0.0, col)
	var duct := Color(0.88, 0.88, 0.85)
	k.box(Vector3(0.1, 0.06, 0.06), Vector3(p.x + 0.44, p.y + 0.16, 0.24), "paint", duct)
	k.box(Vector3(0.06, 0.06, 0.22), Vector3(p.x + 0.5, p.y + 0.16, 0.13), "paint", duct)
	k.box(Vector3(0.07, 0.55, 0.05), Vector3(p.x + 0.5, p.y + 0.41, 0.025), "paint", duct)
	k.rod(p + Vector3(-0.34, 0.0, 0.22), p + Vector3(-0.34, -0.06, 0.02), 0.008, "rubber", Color(0.08, 0.08, 0.08), 4, false)
	k.rod(p + Vector3(-0.34, -0.06, 0.02), Vector3(p.x - 0.34, 0.25, 0.02), 0.008, "rubber", Color(0.08, 0.08, 0.08), 4, false)


## A satellite dish on an arm off the wall at `p` (on the face), aimed by
## `aim` (pitch out from the wall, yaw): the wall plate, the arm, the dish,
## and its cable clipped down the wall to where it goes in.
static func wall_dish(k: BuildingKit, p: Vector3, aim := Vector3(0.9, 0.0, 0), col := Color(0.82, 0.82, 0.8)) -> void:
	var steel := Color(0.45, 0.45, 0.44)
	k.plate(Vector3(0.16, 0.24, 0.012), p + Vector3(0, 0, 0.006), "steel", steel)
	k.bar(p + Vector3(0, 0, 0.012), p + Vector3(0, 0, 0.34), 0.04, 0.04, "steel", steel, false)
	dish(k, p + Vector3(0, -0.02, 0.34), 0.3, aim, col, 0.14)
	var black := Color(0.08, 0.08, 0.08)
	k.rod(p + Vector3(0.03, -0.02, 0.33), p + Vector3(0.1, -0.14, 0.012), 0.005, "rubber", black, 4, false)
	k.rod(p + Vector3(0.1, -0.14, 0.012), Vector3(p.x + 0.1, maxf(0.9, p.y - 1.2), 0.012), 0.005, "rubber", black, 4, false)


## An outside tap at `p` (on the face): the copper pipe up to it out of the
## ground, the bib tap with its spout and handle; with `hose` (its colour) a
## hose coiled on a hook beside it, its end run down to the ground.
static func tap(k: BuildingKit, p: Vector3, hose: Variant = null) -> void:
	k.rod(Vector3(p.x, 0.0, 0.025), p + Vector3(0, 0, 0.025), 0.01, "metal_dark", Color(0.55, 0.34, 0.2), 6, false)
	k.rod(p + Vector3(0, 0, 0.025), p + Vector3(0, 0, 0.09), 0.016, "metal", BRASS, 6, false)
	k.rod(p + Vector3(0, 0, 0.09), p + Vector3(0, -0.06, 0.1), 0.011, "metal", BRASS, 6, false)
	k.rod(p + Vector3(0, 0, 0.07), p + Vector3(0, 0.035, 0.07), 0.006, "metal", BRASS, 4, false)
	k.plate(Vector3(0.07, 0.012, 0.02), p + Vector3(0, 0.04, 0.07), "paint", Color(0.55, 0.12, 0.1))
	if hose == null:
		return
	var hook := p + Vector3(0.36, 0.38, 0)
	k.bar(hook, hook + Vector3(0, 0, 0.14), 0.025, 0.025, "metal_dark", IRON, false)
	for i in 3:
		var r := 0.17 + i * 0.01
		k.part(BuildingKit.ring(r - 0.012, r + 0.012), "rubber", Mats.place(hook + Vector3(0.0, -r + 0.01, 0.05 + i * 0.026), Vector3(PI * 0.5, 0, 0.1 * i)), hose, false)
	k.rod(hook + Vector3(-0.17, -0.2, 0.06), Vector3(hook.x - 0.24, 0.02, 0.12), 0.012, "rubber", hose, 4, false)


## A house's number beside its door, `n` on a plate (its middle at `p`, on
## the face): the plate with its rim, the figures standing off it.
static func house_number(k: BuildingKit, p: Vector3, n: int, plate: Color, figure: Color) -> void:
	var digits := str(n)
	var h := 0.085
	var cw := h * 0.6
	var gap := h * 0.25
	var span := digits.length() * cw + (digits.length() - 1) * gap
	k.plate(Vector3(span + 0.08, h + 0.07, 0.012), p + Vector3(0, 0, 0.006), "paint", figure)
	k.plate(Vector3(span + 0.06, h + 0.05, 0.003), p + Vector3(0, 0, 0.0135), "paint", plate)
	for i in digits.length():
		var x0 := -span * 0.5 + i * (cw + gap)
		var lit: int = _FIGURES[digits.unicode_at(i) - 48]
		for s in 7:
			if (lit & (1 << s)) == 0:
				continue
			var r: Array = _SEGMENTS[s]
			var lo := Vector2(x0 + r[0] * h, r[1] * h - h * 0.5)
			var hi := Vector2(x0 + r[2] * h, r[3] * h - h * 0.5)
			k.plate(Vector3(hi.x - lo.x, hi.y - lo.y, 0.002), p + Vector3((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, 0.016), "paint", figure, Vector3.ZERO, false)


## A letterbox on the wall at `p` (its middle, on the face): the box, its
## lid sloped over the slot to shed the rain, the name card.
static func letterbox(k: BuildingKit, p: Vector3, col: Color) -> void:
	k.box(Vector3(0.26, 0.34, 0.1), p + Vector3(0, 0, 0.05), "paint", col)
	k.plate(Vector3(0.28, 0.025, 0.13), p + Vector3(0, 0.18, 0.06), "paint", col.darkened(0.15), Vector3(0.25, 0, 0))
	k.plate(Vector3(0.18, 0.014, 0.006), p + Vector3(0, 0.1, 0.102), "plain_dark", Color(0.05, 0.05, 0.05))
	k.plate(Vector3(0.1, 0.035, 0.004), p + Vector3(0, -0.05, 0.102), "paint", Color(0.9, 0.88, 0.82))


## A doormat lying at `p` (its middle, on the step): the mat, its border.
static func doormat(k: BuildingKit, p: Vector3, col: Color) -> void:
	k.plate(Vector3(0.8, 0.014, 0.48), p + Vector3(0, 0.007, 0), "canvas", col.darkened(0.3), Vector3.ZERO, false)
	k.plate(Vector3(0.7, 0.004, 0.38), p + Vector3(0, 0.016, 0), "canvas", col, Vector3.ZERO, false)


## A water tank on its stand at `base`: legs and a frame, the drum banded
## round, a lid and the pipe down from it.
static func water_tank(k: BuildingKit, base: Vector3, r := 0.45, h := 1.0, col := Color(0.15, 0.17, 0.2)) -> void:
	var lift := 0.25
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var p := base + Vector3(cos(a), 0, sin(a)) * r * 0.75
		k.plate(Vector3(0.05, lift, 0.05), p + Vector3(0, lift * 0.5, 0), "steel", Color(0.32, 0.32, 0.3), Vector3.ZERO, true)
	k.plate(Vector3(r * 1.7, 0.05, r * 1.7), base + Vector3(0, lift, 0), "steel", Color(0.32, 0.32, 0.3), Vector3.ZERO, true)
	k.cyl(r, r, h, base + Vector3(0, lift + h * 0.5 + 0.025, 0), "paint", col, Vector3.ZERO, 14)
	for f: float in [0.25, 0.75]:
		k.cyl(r + 0.012, r + 0.012, 0.04, base + Vector3(0, lift + 0.025 + h * f, 0), "paint", col.darkened(0.2), Vector3.ZERO, 14, false)
	k.cyl(r * 0.35, r * 0.35, 0.06, base + Vector3(0, lift + h + 0.055, 0), "paint", col.lightened(0.1), Vector3.ZERO, 10, false)
	k.rod(base + Vector3(r * 0.95, lift + 0.12, 0), base + Vector3(r * 1.2, 0.02, 0), 0.025, "metal_dark", Color(0.3, 0.3, 0.3), 6, false)


## A satellite dish at `base` aimed by `aim` (pitch, yaw): a post, the
## bracket, the dish with its rim, the feed arm and the receiver at its focus.
static func dish(k: BuildingKit, base: Vector3, r := 0.38, aim := Vector3(-0.9, 0.6, 0), col := Color(0.82, 0.82, 0.8), post := 0.45) -> void:
	var pr := 0.03 if post < 0.6 else 0.08
	k.cyl(pr, pr * 1.15, post, base + Vector3(0, post * 0.5, 0), "steel", Color(0.45, 0.45, 0.44), Vector3.ZERO, 6)
	var d := k.at_point(base + Vector3(0, post + 0.05, 0), aim)
	d.cyl(r, r * 0.14, r * 0.3, Vector3(0, 0, 0), "paint", col, Vector3.ZERO, 14)
	d.part(BuildingKit.ring(r - 0.015, r + 0.01), "paint", Mats.place(Vector3(0, r * 0.15, 0)), col.darkened(0.08), false)
	d.rod(Vector3(0, r * 0.15, -r * 0.96), Vector3(0, r * 0.7, -r * 0.04), 0.012, "steel", Color(0.4, 0.4, 0.4), 4, false)
	d.plate(Vector3(0.06, 0.1, 0.06), Vector3(0, r * 0.75, 0), "plain_dark", Color(0.15, 0.15, 0.15), Vector3.ZERO, true)


## A pipe run from `a` to `b` held off a wall, `wall` the offset from its
## axis to the wall's face: flanged joints every three metres or so, a
## bracket back to the wall between each pair.
static func pipe(k: BuildingKit, a: Vector3, b: Vector3, r: float, col: Color, wall: Vector3, kind := "steel") -> void:
	k.rod(a, b, r, kind, col, 10)
	var n := maxi(1, int(a.distance_to(b) / 3.0))
	var rot := BuildingKit.aim(b - a).get_euler()
	var w := wall.normalized()
	for i in n + 1:
		k.cyl(r + 0.035, r + 0.035, 0.05, a.lerp(b, float(i) / n), kind, col.darkened(0.12), rot, 10, false)
	for i in n:
		var q := a.lerp(b, (i + 0.5) / n)
		k.beam(q + w * r, q + wall, 0.05, 0.05, "metal_dark", IRON, false)
		k.plate(Vector3(0.012, 0.14, 0.14) if absf(w.x) > 0.5 else Vector3(0.14, 0.14, 0.012), q + wall - w * 0.006, "metal_dark", IRON)


# --- masts, aerials, flags, lamps -------------------------------------------------------

## A sectional radio mast from `base`, `h` tall, guyed at two levels to
## `guys` anchors round it, an aerial array at the top.
## `spread` is how far out the anchors are as a share of its height, `foot`
## the height they're made fast at (the ground, or the roof it stands on).
static func mast(k: BuildingKit, base: Vector3, h: float, guys := 3, yaw := 0.0, col := Color(0.25, 0.26, 0.27), spread := 0.45, foot := NAN, levels: Array = [0.5, 0.9]) -> void:
	k.box(Vector3(0.36, 0.12, 0.36), base + Vector3(0, 0.06, 0), "concrete", Color(0.5, 0.49, 0.46))
	var sections := 3
	for i in sections:
		var r0 := lerpf(0.07, 0.035, float(i) / sections)
		var r1 := lerpf(0.07, 0.035, float(i + 1) / sections)
		var y0 := h * i / sections
		k.cyl(r1, r0, h / sections, base + Vector3(0, y0 + h / sections * 0.5, 0), "steel", col, Vector3.ZERO, 8)
		if i > 0:
			k.cyl(r0 + 0.015, r0 + 0.015, 0.1, base + Vector3(0, y0, 0), "steel", col.darkened(0.1), Vector3.ZERO, 8, false)
	# the aerial: a whip and a crossed dipole
	k.rod(base + Vector3(0, h, 0), base + Vector3(0, h + 1.6, 0), 0.012, "metal_dark", null, 4, false)
	for s: float in [-1.0, 1.0]:
		k.rod(base + Vector3(0, h - 0.4, 0), base + Vector3(s * 1.2, h + 0.5, 0), 0.012, "steel", col, 4, false)
	var fy := base.y if is_nan(foot) else foot
	for lvl: float in levels:
		for i in guys:
			var a := yaw + TAU * i / guys
			var anchor := Vector3(base.x, fy, base.z) + Vector3(cos(a), 0, sin(a)) * h * spread
			BuildingWire.guy(k, base + Vector3(0, h * lvl, 0), anchor, false, "picket" if is_nan(foot) else "block")


## A whip aerial on its base at `base`.
static func whip(k: BuildingKit, base: Vector3, h := 2.4, lean := Vector3(0.05, 0, 0.04)) -> void:
	k.cyl(0.04, 0.05, 0.08, base + Vector3(0, 0.04, 0), "metal_dark", Color(0.2, 0.2, 0.2), Vector3.ZERO, 8, false)
	k.cyl(0.02, 0.02, 0.14, base + Vector3(0, 0.15, 0), "rubber", null, Vector3.ZERO, 6, false)
	k.part(Res.cyl(0.006, 0.011, h, 4), "metal_dark", Transform3D(Basis.from_euler(lean), base + Vector3(0, 0.22, 0) + Basis.from_euler(lean) * Vector3(0, h * 0.5, 0)), Color(0.15, 0.15, 0.15), false)


## A flagpole at `base`, `h` tall: a footing, the tapered pole, the truck and
## finial at the top, the halyard down to its cleat. Returns where the flag's
## hoist (its top inner corner) hangs, for the builder's own flag.
static func flagpole(k: BuildingKit, base: Vector3, h: float, col := Color(0.8, 0.8, 0.78), footing := true) -> Vector3:
	if footing:
		k.cyl(0.22, 0.28, 0.3, base + Vector3(0, 0.15, 0), "concrete", Color(0.52, 0.5, 0.47), Vector3.ZERO, 10)
	k.cyl(0.04, 0.065, h, base + Vector3(0, h * 0.5, 0), "steel", col, Vector3.ZERO, 8)
	k.cyl(0.055, 0.055, 0.08, base + Vector3(0, h + 0.02, 0), "steel", col.darkened(0.2), Vector3.ZERO, 8, false)
	k.part(Res.sphere(0.07, 6), "paint", Transform3D(Basis.IDENTITY, base + Vector3(0, h + 0.12, 0)), Color(0.75, 0.62, 0.25), false)
	k.rod(base + Vector3(0.06, 1.1, 0), base + Vector3(0.06, h - 0.05, 0), 0.005, "canvas", Color(0.75, 0.72, 0.62), 3, false)
	k.plate(Vector3(0.03, 0.14, 0.03), base + Vector3(0.075, 1.15, 0), "metal_dark", IRON)
	return base + Vector3(0.06, h - 0.1, 0)


## A lamp post at `base` with its lantern out on an arm along `out`.
static func lamp(k: BuildingKit, base: Vector3, out: Vector3, h := 4.6, col := Color(0.22, 0.23, 0.24)) -> void:
	var o := Vector3(out.x, 0, out.z).normalized()
	k.cyl(0.11, 0.13, 0.35, base + Vector3(0, 0.175, 0), "metal", col, Vector3.ZERO, 8)
	k.cyl(0.06, 0.08, h, base + Vector3(0, h * 0.5, 0), "metal", col, Vector3.ZERO, 8)
	var top := base + Vector3(0, h - 0.05, 0)
	k.beam(top, top + o * 0.9 + Vector3(0, 0.06, 0), 0.06, 0.08, "metal", col, false)
	k.beam(top + Vector3(0, -0.5, 0), top + o * 0.5 + Vector3(0, 0.02, 0), 0.04, 0.04, "metal", col, false)
	var head := top + o * 0.88
	k.box(Vector3(0.38, 0.1, 0.22), head, "metal", Color(0.3, 0.3, 0.3), Vector3(0, atan2(o.x, o.z) + PI * 0.5, 0), false)
	k.plate(Vector3(0.3, 0.012, 0.15), head + Vector3(0, -0.055, 0), "glass", Color(0.55, 0.52, 0.45), Vector3(0, atan2(o.x, o.z) + PI * 0.5, 0))


# --- stores ------------------------------------------------------------------------------

## A 200-litre drum at `base` (standing, or lying with its axis along `yaw`):
## the shell, its two rolling hoops and rims, the bungs in the lid.
static func drum(k: BuildingKit, base: Vector3, col: Color, lying := false, yaw := 0.0, kind := "car_paint") -> void:
	var rot := Vector3(0, yaw, PI * 0.5) if lying else Vector3(0, yaw, 0)
	var d := k.at_point(base + (Vector3(0, 0.29, 0) if lying else Vector3(0, 0.44, 0)), rot)
	d.cyl(0.29, 0.29, 0.88, Vector3.ZERO, kind, col, Vector3.ZERO, 14)
	for y: float in [-0.43, -0.15, 0.15, 0.43]:
		d.cyl(0.3, 0.3, 0.025 if absf(y) < 0.3 else 0.03, Vector3(0, y, 0), kind, col.darkened(0.15), Vector3.ZERO, 14, false)
	d.cyl(0.035, 0.035, 0.02, Vector3(0.17, 0.445, 0.05), "steel", Color(0.4, 0.4, 0.38), Vector3.ZERO, 6, false)
	d.cyl(0.022, 0.022, 0.02, Vector3(-0.16, 0.445, -0.08), "steel", Color(0.4, 0.4, 0.38), Vector3.ZERO, 6, false)


## A crate `size` standing at `base` turned by `yaw`: the box, battens round
## each end, rope handles; with `lid` the lid boards' line round the top.
static func crate(k: BuildingKit, base: Vector3, size: Vector3, col: Color, yaw := 0.0, kind := "wood", handles := true, lid := true) -> void:
	var c := k.at_point(base, Vector3(0, yaw, 0))
	c.box(size, Vector3(0, size.y * 0.5, 0), kind, col)
	for sx: float in [-1.0, 1.0]:
		c.plate(Vector3(0.05, size.y + 0.01, size.z + 0.01), Vector3(sx * (size.x * 0.5 - 0.06), size.y * 0.5, 0), kind, col.darkened(0.15), Vector3.ZERO, true)
		if handles:
			c.part(BuildingKit.ring(0.03, 0.05), "canvas", Mats.place(Vector3(sx * (size.x * 0.5 + 0.01), size.y * 0.55, 0), Vector3(0, 0, PI * 0.5)), Color(0.55, 0.5, 0.36), false)
	if lid:
		c.plate(Vector3(size.x - 0.2, 0.012, size.z + 0.006), Vector3(0, size.y - 0.06, 0), kind, col.darkened(0.3))


## A wooden pallet `size` (x by z) at `base`: deck boards on three stringers,
## boards under them; its deck is 0.13 m up.
static func pallet(k: BuildingKit, base: Vector3, size := Vector2(1.15, 1.0), col := Color(0.55, 0.45, 0.32), yaw := 0.0) -> void:
	k.part(BuildingKit.shape("pallet|%.2f|%.2f" % [size.x, size.y], func() -> Array:
		var out: Array = []
		var boards := maxi(4, int(round(size.y / 0.18)))
		for s in boards:
			out.append(BuildingKit.piece(Vector3(size.x, 0.022, 0.12), Vector3(0, 0.119, -size.y * 0.5 + 0.06 + s * (size.y - 0.12) / (boards - 1))))
		for s in 3:
			var x := -size.x * 0.5 + 0.05 + s * (size.x - 0.1) * 0.5
			out.append(BuildingKit.piece(Vector3(0.1, 0.09, size.y), Vector3(x, 0.063, 0)))
		for s in 3:
			out.append(BuildingKit.piece(Vector3(size.x, 0.018, 0.1), Vector3(0, 0.009, -size.y * 0.5 + 0.05 + s * (size.y - 0.1) * 0.5)))
		return out), "wood", Mats.place(base, Vector3(0, yaw, 0)), col)
