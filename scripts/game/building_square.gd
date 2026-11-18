class_name BuildingSquare
extends RefCounted
## The town square's monuments: the war memorial at its middle (a bronze
## soldier on a dressed-stone pedestal, or an obelisk) on its steps, with
## bronze plaques and wreaths laid at its foot. In a kit standing on the
## ground (y = 0), its front (the inscription, the wreaths, the way the
## soldier faces) at -z.

const STONE := Color(0.66, 0.63, 0.57)
## Bronze gone green with weather, and darker where the rain doesn't wash it.
const BRONZE := Color(0.27, 0.37, 0.31)
const BRONZE_DARK := Color(0.17, 0.22, 0.19)


## A war memorial: three steps, a moulded plinth, the die with a bronze plaque
## on each face, a cornice; on top a bronze soldier standing at rest on his
## rifle, head bowed (or, `obelisk`, a tapered obelisk with its capstone).
## Two wreaths of laurel and poppies lean against its front.
static func memorial(k: BuildingKit, obelisk: bool, rng: RandomNumberGenerator) -> void:
	var y := 0.0
	for step: float in [3.0, 2.5, 2.0]:
		k.box(Vector3(step, 0.18, step), Vector3(0, y + 0.09, 0), "stone", STONE.darkened(0.06))
		y += 0.18
	k.box(Vector3(1.5, 0.3, 1.5), Vector3(0, y + 0.15, 0), "concrete", STONE.darkened(0.03))
	k.box(Vector3(1.6, 0.06, 1.6), Vector3(0, y + 0.31, 0), "concrete", STONE)
	y += 0.34
	var die := 1.25 if not obelisk else 1.1
	var dh := 1.4 if not obelisk else 1.0
	k.box(Vector3(die, dh, die), Vector3(0, y + dh * 0.5, 0), "concrete", STONE)
	# a bronze plaque on each face, its border and the raised lines of names
	for f in 4:
		var a := f * PI * 0.5
		var face := k.at_point(Vector3(sin(a + PI), 0, cos(a + PI)) * die * 0.5, Vector3(0, a + PI, 0))
		var pw := die * 0.62
		var ph := dh * 0.5
		face.box(Vector3(pw, ph, 0.025), Vector3(0, y + dh * 0.52, 0.012), "bronze", BRONZE_DARK)
		face.box(Vector3(pw - 0.06, ph - 0.06, 0.012), Vector3(0, y + dh * 0.52, 0.03), "bronze", BRONZE)
		for row in 5:
			var w := pw * (0.7 if row == 0 else rng.randf_range(0.45, 0.62))
			face.box(Vector3(w, 0.022, 0.006), Vector3(0, y + dh * 0.52 + ph * 0.32 - row * ph * 0.15, 0.038), "bronze", BRONZE.lightened(0.18), Vector3.ZERO, false)
	y += dh
	k.box(Vector3(die + 0.24, 0.14, die + 0.24), Vector3(0, y + 0.07, 0), "concrete", STONE.lightened(0.04))
	k.box(Vector3(die + 0.1, 0.12, die + 0.1), Vector3(0, y + 0.2, 0), "concrete", STONE)
	y += 0.26
	if obelisk:
		k.cyl(0.16 * sqrt(2.0), 0.36 * sqrt(2.0), 3.4, Vector3(0, y + 1.7, 0), "concrete", STONE.lightened(0.03), Vector3(0, PI * 0.25, 0), 4)
		k.cyl(0.0, 0.16 * sqrt(2.0), 0.3, Vector3(0, y + 3.55, 0), "concrete", STONE.lightened(0.05), Vector3(0, PI * 0.25, 0), 4)
		# a bronze wreath fixed high on its face
		k.part(BuildingKit.ring(0.13, 0.19), "bronze", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, y + 2.4, -0.27)), BRONZE)
	else:
		soldier(k.at_point(Vector3(0, y, 0)), rng)
	# wreaths laid against the front of the die
	for sx: float in [-0.32, 0.32]:
		wreath(k.at_point(Vector3(sx + rng.randf_range(-0.05, 0.05), 0.54, -die * 0.5 - 0.08), Vector3(-0.25, rng.randf_range(-0.2, 0.2), 0)), rng)


## A bronze soldier 2.1 m tall (a figure on a memorial is larger than life)
## standing at rest on his rifle: the butt by his right boot, both hands on
## the muzzle, head bowed under his helmet, his greatcoat to the knee and his
## pack on his back. Facing -z, his feet on y = 0.
static func soldier(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var s := 1.15
	var b := BRONZE
	var d := BRONZE_DARK
	# the boots and puttees
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.13, 0.1, 0.3) * s, Vector3(sx * 0.11, 0.05, -0.03) * s, "bronze", d)
		k.cyl(0.07 * s, 0.065 * s, 0.42 * s, Vector3(sx * 0.105, 0.31, 0.0) * s, "bronze", b, Vector3.ZERO, 8)
	# the greatcoat: its skirt to the knee, the body, the belt, the collar
	k.part(Res.cyl(0.21, 0.31, 0.56, 12), "bronze", Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.8) * s), Vector3(0, 0.8, 0.0) * s), b)
	k.part(Res.cyl(0.24, 0.21, 0.52, 12), "bronze", Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.72) * s), Vector3(0, 1.33, 0.0) * s), b)
	k.part(Res.cyl(0.218, 0.218, 0.06, 12), "bronze", Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.8) * s), Vector3(0, 1.07, 0.0) * s), d)
	k.part(Res.sphere(0.5, 10), "bronze", Transform3D(Basis.from_scale(Vector3(0.56, 0.2, 0.36) * s), Vector3(0, 1.58, 0.0) * s), b)
	k.cyl(0.075 * s, 0.09 * s, 0.1 * s, Vector3(0, 1.65, 0.0) * s, "bronze", b, Vector3.ZERO, 8)
	# the pack on his back, the bedroll over it
	k.box(Vector3(0.3, 0.32, 0.14) * s, Vector3(0, 1.36, 0.2) * s, "bronze", d.lerp(b, 0.5))
	k.part(Res.cyl(0.06, 0.06, 0.36, 8), "bronze", Transform3D(Basis(Vector3.BACK, PI * 0.5).scaled(Vector3.ONE * s), Vector3(0, 1.56, 0.22) * s), b)
	# the head bowed, the helmet over it
	var bow := Basis(Vector3.RIGHT, 0.32)
	var head := Vector3(0, 1.76, -0.04) * s
	k.part(Res.sphere(0.5, 10), "bronze", Transform3D(bow * Basis.from_scale(Vector3(0.2, 0.23, 0.22) * s), head), b)
	k.part(Res.sphere(0.5, 12), "bronze", Transform3D(bow * Basis.from_scale(Vector3(0.3, 0.17, 0.32) * s), head + bow * Vector3(0, 0.06, 0) * s), d.lerp(b, 0.6))
	k.part(Res.cyl(0.17, 0.17, 0.015, 14), "bronze", Transform3D(bow.scaled(Vector3.ONE * s), head + bow * Vector3(0, 0.03, 0) * s), d.lerp(b, 0.6))
	# the rifle: its butt by his right boot, the muzzle at his chest
	var butt := Vector3(0.08, 0.0, -0.3) * s
	var muzzle := Vector3(0.03, 1.36, -0.27) * s
	k.box(Vector3(0.05, 0.32, 0.11) * s, butt + Vector3(0, 0.17, 0) * s, "bronze", d)
	k.rod(butt + Vector3(0, 0.32, 0) * s, muzzle, 0.022 * s, "bronze", d, 6)
	# his arms: shoulders, elbows out a little, both hands on the muzzle
	for sx: float in [-1.0, 1.0]:
		var shoulder := Vector3(sx * 0.25, 1.52, 0.0) * s
		var elbow := Vector3(sx * 0.23, 1.2, -0.13) * s
		var hand := muzzle + Vector3(sx * 0.035, -0.05 + (0.06 if sx < 0.0 else 0.0), 0.0) * s
		k.rod(shoulder, elbow, 0.065 * s, "bronze", b, 8)
		k.rod(elbow, hand, 0.055 * s, "bronze", b, 8)
		k.part(Res.sphere(0.5, 8), "bronze", Transform3D(Basis.from_scale(Vector3.ONE * 0.1 * s), hand), d.lerp(b, 0.5))


## A wreath of laurel with poppies, standing on edge (its middle 0.25 m up):
## the ring of leaves, the red flowers set in it, a ribbon tied at its foot.
static func wreath(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	k.part(BuildingKit.ring(0.16, 0.25), "plain", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.25, 0)), Color(0.16, 0.25, 0.12))
	for i in 14:
		var a := TAU * i / 14.0 + rng.randf_range(-0.1, 0.1)
		k.part(Res.sphere(0.5, 6), "paint", Transform3D(Basis.from_scale(Vector3(0.07, 0.07, 0.04)), Vector3(cos(a) * 0.205, 0.25 + sin(a) * 0.205, -0.035)), Color(0.72, 0.06, 0.06), false)
	k.box(Vector3(0.09, 0.16, 0.01), Vector3(0.0, 0.06, -0.05), "fabric", Color(0.78, 0.74, 0.66), Vector3(0, 0, 0.2), false)


## A market stall's canopy colours (each striped with cream): tomato red,
## navy, bottle green, mustard, slate.
const AWNINGS := [Color(0.66, 0.18, 0.14), Color(0.16, 0.24, 0.44), Color(0.18, 0.38, 0.24), Color(0.78, 0.6, 0.2), Color(0.32, 0.34, 0.36)]


## A market stall 2.4 m along x, its front (where the trader serves) to -z: a
## timber frame under a pitched canopy of striped canvas, scalloped along its
## eaves, and a trestle with crates of produce heaped up, a set of scales, a
## crate or two under it.
static func stall(k: BuildingKit, ci: int, rng: RandomNumberGenerator) -> void:
	var wood := Color(0.42, 0.32, 0.2)
	var col: Color = AWNINGS[posmod(ci, AWNINGS.size())]
	var cream := Color(0.9, 0.87, 0.78)
	# the frame: four posts, a ridge pole, the trestle
	for sx: float in [-1.15, 1.15]:
		for sz: float in [-0.6, 0.6]:
			k.box(Vector3(0.06, 2.05, 0.06), Vector3(sx, 1.025, sz), "wood_dark", wood)
		k.bar(Vector3(sx, 2.05, -0.6), Vector3(sx, 2.4, 0.0), 0.05, 0.05, "wood_dark", wood, false)
		k.bar(Vector3(sx, 2.05, 0.6), Vector3(sx, 2.4, 0.0), 0.05, 0.05, "wood_dark", wood, false)
	k.rod(Vector3(-1.2, 2.4, 0), Vector3(1.2, 2.4, 0), 0.03, "wood_dark", wood, 6, false)
	# the canopy: a stripe at a time down each slope, its scalloped valance
	var n := 7
	var sw := 2.6 / n
	var slope := sqrt(0.75 * 0.75 + 0.38 * 0.38)
	var ang := atan2(0.38, 0.75)
	for i in n:
		var x := -1.3 + (i + 0.5) * sw
		var c := col if i % 2 == 0 else cream
		for sz: float in [-1.0, 1.0]:
			k.plate(Vector3(sw + 0.004, 0.015, slope), Vector3(x, 2.4 - 0.19, sz * 0.375), "canvas", c, Vector3(sz * ang, 0, 0), true)
			k.plate(Vector3(sw + 0.004, 0.14, 0.01), Vector3(x, 1.95, sz * 0.755), "canvas", c)
			k.prism(Vector3(sw * 0.97, 0.06, 0.01), Vector3(x, 1.85, sz * 0.755), "canvas", c, Vector3(PI, 0, 0), false)
	# the trestle: its top on two A-frames, crates heaped with produce
	k.box(Vector3(2.2, 0.05, 0.8), Vector3(0, 0.86, -0.15), "wood", wood.lightened(0.15))
	for sx: float in [-0.9, 0.9]:
		k.bar(Vector3(sx, 0.0, -0.5), Vector3(sx, 0.84, -0.15), 0.04, 0.04, "wood", wood, false)
		k.bar(Vector3(sx, 0.0, 0.2), Vector3(sx, 0.84, -0.15), 0.04, 0.04, "wood", wood, false)
	for i in 4:
		var x := -0.78 + i * 0.52
		var crate := k.at_point(Vector3(x, 0.885, -0.3), Vector3(0.22, rng.randf_range(-0.05, 0.05), 0))
		crate.box(Vector3(0.46, 0.16, 0.36), Vector3(0, 0.08, 0), "wood", wood.lightened(0.25))
		crate.part(Res.sphere(0.5, 8), "paint", Transform3D(Basis.from_scale(Vector3(0.42, 0.16, 0.32)), Vector3(0, 0.16, 0)), BuildingShops.PRODUCE[(i + ci + rng.randi() % 2) % BuildingShops.PRODUCE.size()])
	# the scales at the end, a crate or two under the trestle
	k.box(Vector3(0.22, 0.08, 0.2), Vector3(0.9, 0.93, 0.08), "metal_dark", Color(0.3, 0.32, 0.3))
	k.cyl(0.12, 0.12, 0.02, Vector3(0.9, 1.06, 0.08), "steel", Color(0.6, 0.6, 0.58), Vector3.ZERO, 10, false)
	for i in rng.randi_range(1, 2):
		k.box(Vector3(0.5, 0.3, 0.38), Vector3(-0.5 + i * 0.6, 0.15, 0.0), "wood", wood.lightened(0.1), Vector3(0, rng.randf_range(-0.2, 0.2), 0))
