class_name BuildingSquare
extends RefCounted
## The town square's monuments: the war memorial at its middle (a bronze
## soldier on a dressed-stone pedestal, or an obelisk) on its steps, with
## bronze plaques and wreaths laid at its foot. In a kit standing on the
## ground (y = 0), its front (the inscription, the wreaths, the way the
## soldier faces) at -z.

const STONE := Color(0.66, 0.63, 0.57)
## Bronze gone green with weather (the `bronze` surface mottles the patina
## with the dark metal under it), darker where the rain doesn't wash it.
const BRONZE := Color(0.27, 0.37, 0.31)
const BRONZE_DARK := Color(0.17, 0.22, 0.19)
## The memorial's steps (each one's side, a riser apart) and its plinth (side
## and height) under its moulded cap: the wreaths are laid on the top step,
## leaning on the cap's edge.
const STEPS := [3.0, 2.5, 2.0]
const RISE := 0.18
const PLINTH := 1.5
const PLINTH_H := 0.3
const CAP := 1.6
## The soldier on top is larger than life: a man of 1.8 m cast 2.1 m tall,
## on a bronze base FIGURE_BASE thick.
const STATUE_SCALE := 1.17
const FIGURE_BASE := 0.035


## A war memorial: its stone and bronze (monument()) and the wreaths laid at
## its foot (wreath_spots()).
static func memorial(k: BuildingKit, obelisk: bool, rng: RandomNumberGenerator) -> void:
	monument(k, obelisk, rng)
	for spot in wreath_spots(rng):
		wreath(k.moved(spot))


## The memorial itself: three steps, a moulded plinth, the die with a bronze
## plaque on each face, a cornice; on top the bronze soldier resting on his
## arms reversed (or, `obelisk`, a tapered obelisk with its capstone and a
## bronze laurel wreath fixed to its face).
static func monument(k: BuildingKit, obelisk: bool, rng: RandomNumberGenerator) -> void:
	var y := 0.0
	for step: float in STEPS:
		k.box(Vector3(step, RISE, step), Vector3(0, y + RISE * 0.5, 0), "stone", STONE.darkened(0.06))
		y += RISE
	k.box(Vector3(PLINTH, PLINTH_H, PLINTH), Vector3(0, y + PLINTH_H * 0.5, 0), "concrete", STONE.darkened(0.03))
	k.box(Vector3(CAP, 0.06, CAP), Vector3(0, y + PLINTH_H + 0.01, 0), "concrete", STONE)
	y += PLINTH_H + 0.04
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
		# a bronze laurel wreath fixed high on its face, its back flat on the
		# stone, which leans in as the obelisk tapers
		var lean := atan2(0.36 - 0.16, 3.4)
		var at := Vector3(0, y + 2.4, -(0.36 - (0.36 - 0.16) * 2.4 / 3.4))
		var ring := Transform3D(Basis(Vector3.RIGHT, lean).scaled(Vector3.ONE * 0.8), at) * Transform3D(Basis(), Vector3(0, -WREATH_R, -WREATH_BACK))
		k.part(_laurel(), "bronze", ring, BRONZE)
		k.part(_bow(), "bronze", ring, BRONZE)
	else:
		soldier(k.at_point(Vector3(0, y, 0)))


## Where the wreaths are laid at a memorial's foot, each a wreath()'s frame:
## two or three standing on the top step in front, leaning back with their
## faces out, each tilted just so far that its back rests on the edge of the
## plinth's cap.
static func wreath_spots(rng: RandomNumberGenerator) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var step_top := RISE * STEPS.size()
	# the cap's top front edge, which they lean on: its height and z
	var edge_y := step_top + PLINTH_H + 0.04
	var edge_z := -CAP * 0.5
	var three := rng.randf() < 0.4
	var xs: Array = [-0.52, 0.0, 0.52] if three else [-0.29, 0.29]
	for x: float in xs:
		var lean := rng.randf_range(0.17, 0.24)
		# how far up the wreath's back the edge meets it, and so where its
		# foot stands
		var up := (edge_y - step_top + WREATH_BACK * sin(lean)) / cos(lean)
		var foot_z := edge_z - up * sin(lean) - WREATH_BACK * cos(lean)
		var dx := rng.randf_range(-0.008, 0.008) if three else rng.randf_range(-0.03, 0.03)
		out.append(Transform3D(Basis(Vector3.RIGHT, lean), Vector3(x + dx, step_top, foot_z)))
	return out


## A wreath's laurel, its poppies, and the ribbon tied at its foot.
const LAUREL := Color(0.14, 0.24, 0.12)
const POPPY := Color(0.72, 0.07, 0.06)
const RIBBON := Color(0.84, 0.8, 0.7)
## A wreath's outer radius (it stands this far up to its middle) and how far
## its back lies behind its foot.
const WREATH_R := 0.24
const WREATH_BACK := 0.033


## A wreath of poppies on laurel standing on edge, 0.48 m across, its foot on
## the origin and its face to -z: a ring of dark leaves, the poppies set all
## round its face, each with its black heart, a ribbon tied in a bow at its
## foot. A shape a colour, so a memorial's wreaths are a dozen parts.
static func wreath(k: BuildingKit) -> void:
	k.part(_laurel(), "canvas", Transform3D.IDENTITY, LAUREL)
	k.part(_poppies(false), "canvas", Transform3D.IDENTITY, POPPY)
	k.part(_poppies(true), "plain_dark", Transform3D.IDENTITY, Color(0.06, 0.05, 0.05), false)
	k.part(_bow(), "canvas", Transform3D.IDENTITY, RIBBON, false)


## (the ring of laurel, its leaves standing out of both its edges, all laid
## one way round; none at the foot, where the bow is and it stands)
static func _laurel() -> ArrayMesh:
	return BuildingKit.shape("wreath_laurel", func() -> Array:
		var p := [[Res.torus(0.14, 0.24), Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.75)) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, WREATH_R, 0))]]
		for i in 28:
			var a := TAU * i / 28.0
			if absf(angle_difference(a, PI * 1.5)) < 0.45:
				continue
			var r := 0.226 if i % 2 == 0 else 0.152
			p.append([Res.sphere(0.5, 6), Transform3D(Basis(Vector3.BACK, a + 0.4) * Basis.from_scale(Vector3(0.028, 0.082, 0.014)), Vector3(cos(a) * r, WREATH_R + sin(a) * r, -0.012))])
		return p)


## (the poppies round the wreath's face, or their black hearts)
static func _poppies(hearts: bool) -> ArrayMesh:
	return BuildingKit.shape("wreath_hearts" if hearts else "wreath_poppies", func() -> Array:
		var p := []
		for i in 16:
			var a := TAU * (i + 0.5) / 16.0
			var r := 0.19 if i % 2 == 0 else 0.176
			var at := Vector3(cos(a) * r, WREATH_R + sin(a) * r, -0.046 if hearts else -0.03)
			p.append([Res.sphere(0.5, 6 if hearts else 8), Transform3D(Basis(Vector3.BACK, a).scaled(Vector3(0.02, 0.02, 0.01) if hearts else Vector3(0.068, 0.068, 0.028)), at)])
		return p)


## (the bow at a wreath's foot: its knot, two loops, two tails)
static func _bow() -> ArrayMesh:
	return BuildingKit.shape("wreath_bow", func() -> Array:
		var p := [[Res.sphere(0.5, 6), Transform3D(Basis.from_scale(Vector3(0.03, 0.026, 0.016)), Vector3(0, 0.07, -0.054))]]
		for sx: float in [-1.0, 1.0]:
			p.append([Res.sphere(0.5, 6), Transform3D(Basis(Vector3.BACK, sx * 0.35) * Basis.from_scale(Vector3(0.07, 0.034, 0.012)), Vector3(sx * 0.042, 0.078, -0.05))])
			p.append([BuildingKit.plain(Vector3(0.026, 0.07, 0.004)), Transform3D(Basis(Vector3.BACK, sx * 0.45), Vector3(sx * 0.02, 0.042, -0.054))])
		return p)


## A bronze soldier larger than life resting on his arms reversed, as the
## memorials of the Great War stand them: his rifle upside down before him,
## its muzzle on the base between his boots, both hands folded on the butt,
## his head bowed under his helmet; in his greatcoat with belt and pouches,
## his pack on his back. One cast mesh on its bronze base, facing -z, the
## base on y = 0.
static func soldier(k: BuildingKit) -> void:
	k.part(_figure(), "bronze", Transform3D(Basis.from_scale(Vector3.ONE * STATUE_SCALE), Vector3.ZERO), BRONZE)


## The greatcoat's cross-sections, hem to collar (as BodyMesh rings: height,
## half width, depth in front, depth behind, squareness): full in the skirt,
## belted in at the waist, square across the shoulders.
const COAT := [[0.42, 0.218, 0.172, 0.192, 2.3], [0.48, 0.215, 0.168, 0.188, 2.3], [0.66, 0.2, 0.15, 0.17, 2.3],
	[0.86, 0.186, 0.134, 0.148, 2.3], [1.0, 0.174, 0.122, 0.126, 2.4], [1.06, 0.17, 0.116, 0.118, 2.4],
	[1.14, 0.18, 0.124, 0.12, 2.4], [1.27, 0.198, 0.134, 0.124, 2.5], [1.36, 0.206, 0.13, 0.122, 2.6],
	[1.42, 0.204, 0.116, 0.11, 2.8], [1.465, 0.182, 0.094, 0.094, 2.6], [1.5, 0.085, 0.064, 0.068, 2.0]]
## An ankle boot along the foot from behind the ankle to the toe: [along,
## half width, depth below its line (the sole), above it (the instep), squareness].
const BOOT := [[-0.085, 0.028, 0.05, 0.03, 2.2], [-0.07, 0.04, 0.056, 0.06, 2.5], [-0.025, 0.044, 0.056, 0.09, 2.5],
	[0.05, 0.045, 0.056, 0.048, 2.6], [0.13, 0.046, 0.056, 0.022, 2.7], [0.18, 0.042, 0.054, 0.016, 2.6],
	[0.205, 0.032, 0.05, 0.012, 2.4], [0.215, 0.014, 0.042, 0.006, 2.2]]
## A hand laid flat, wrist to fingertips, the fingers curled over an edge:
## [along (a fraction), half width, palm side, back, squareness, curl].
const HAND := [[0.0, 0.026, 0.02, 0.02, 2.2, 0.0], [0.25, 0.04, 0.02, 0.018, 2.5, 0.0], [0.5, 0.043, 0.016, 0.019, 2.6, -0.002],
	[0.7, 0.04, 0.012, 0.013, 2.5, -0.014], [0.86, 0.037, 0.01, 0.011, 2.4, -0.032], [1.0, 0.03, 0.007, 0.008, 2.2, -0.054]]
## The head from the chin up (as the soldiers' own: a squared jaw set
## forward, a high brow), and the helmet's bowl and brim from the brim up.
const HEAD := [[0.012, 0.03, 0.022, 0.03, 2.15, -0.058], [0.035, 0.06, 0.05, 0.06, 2.15, -0.035], [0.07, 0.078, 0.082, 0.078, 2.15, -0.012],
	[0.11, 0.084, 0.096, 0.09, 2.15, 0.0], [0.15, 0.086, 0.098, 0.098, 2.15, 0.003], [0.19, 0.083, 0.092, 0.1, 2.15, 0.006],
	[0.222, 0.068, 0.072, 0.086, 2.15, 0.01], [0.243, 0.04, 0.04, 0.052, 2.15, 0.012]]
const HELMET := [[-0.014, 0.152, 0.166, 0.166, 2.0], [-0.005, 0.156, 0.17, 0.17, 2.0], [0.0, 0.146, 0.16, 0.16, 2.0],
	[0.006, 0.118, 0.13, 0.13, 2.0], [0.04, 0.115, 0.127, 0.127, 2.0], [0.075, 0.097, 0.107, 0.107, 2.0],
	[0.096, 0.064, 0.07, 0.07, 2.0], [0.108, 0.018, 0.02, 0.02, 2.0]]
## The rifle (a Lee-Enfield) from its muzzle to the heel of its butt, its
## magazine and the toe of its butt to the front.
const RIFLE := [[0.0, 0.011, 0.011, 0.011, 2.0], [0.035, 0.015, 0.016, 0.016, 2.0], [0.05, 0.02, 0.024, 0.02, 2.6],
	[0.5, 0.022, 0.027, 0.022, 2.6], [0.6, 0.024, 0.03, 0.024, 2.8], [0.635, 0.024, 0.07, 0.024, 3.0],
	[0.715, 0.024, 0.07, 0.024, 3.0], [0.745, 0.022, 0.046, 0.024, 2.6], [0.79, 0.02, 0.03, 0.022, 2.4],
	[0.86, 0.021, 0.034, 0.024, 2.6], [1.105, 0.024, 0.08, 0.03, 3.0], [1.13, 0.022, 0.074, 0.026, 3.0]]


## The soldier at life size (1.8 m to the crown of his head) on his base, as
## one cached mesh, sculpted from lofted cross-sections (BodyMesh) as the
## game's own soldiers are: the coat, limbs and helmet read as one figure.
static func _figure() -> ArrayMesh:
	return BuildingKit.shape("memorial_soldier", func() -> Array:
		var p := []
		var on_base := Transform3D(Basis(), Vector3(0, FIGURE_BASE, 0))
		for piece: Array in _figure_pieces():
			p.append([piece[0], on_base * (piece[1] as Transform3D)])
		p.append([Res.box(Vector3(0.56, FIGURE_BASE, 0.52)), Transform3D(Basis(), Vector3(0, FIGURE_BASE * 0.5, -0.06))])
		return p)


static func _figure_pieces() -> Array:
	var p := []
	# the greatcoat and its turned-down collar
	var coat := []
	for r: Array in COAT:
		coat.append(BodyMesh.ring(float(r[0]), float(r[1]), float(r[2]), float(r[3]), float(r[4])))
	p.append([BodyMesh.loft(coat, 18), Transform3D.IDENTITY])
	p.append([BodyMesh.loft([BodyMesh.ring(1.44, 0.132, 0.1, 0.112, 2.4), BodyMesh.ring(1.485, 0.118, 0.09, 0.1, 2.4), BodyMesh.ring(1.525, 0.09, 0.074, 0.086, 2.2)], 16), Transform3D.IDENTITY])
	# two rows of buttons down its breast, over them the belt and its buckle,
	# the ammunition pouches in two tiers either side, and the braces from
	# them up over his shoulders
	for sx: float in [-1.0, 1.0]:
		for by: float in [1.29, 1.37]:
			p.append([Res.sphere(0.013, 6), Transform3D(Basis(), _on_coat(by, sx * 0.07, 0.004))])
	p.append([BodyMesh.loft([_coat_at(1.035, 0.008), _coat_at(1.085, 0.008)], 18), Transform3D.IDENTITY])
	p.append([Res.box(Vector3(0.062, 0.058, 0.014)), _facing(1.06, 0.0, 0.014)])
	for sx: float in [-1.0, 1.0]:
		for i in 3:
			p.append([Res.box(Vector3(0.042, 0.072, 0.04)), _facing(1.105, sx * (0.06 + i * 0.046), 0.036)])
		for i in 2:
			p.append([Res.box(Vector3(0.042, 0.064, 0.036)), _facing(1.18, sx * (0.083 + i * 0.046), 0.03)])
		# (up the breast, over the shoulder and down the back to the pack)
		var brace: Array[Vector3] = []
		for by: float in [1.22, 1.32, 1.4, 1.45, 1.47, 1.482]:
			brace.append(_on_coat(by, sx * lerpf(0.1, 0.116, (by - 1.22) / 0.26), 0.005))
		brace.append_array([Vector3(sx * 0.116, 1.494, -0.02), Vector3(sx * 0.116, 1.494, 0.02)])
		for by: float in [1.482, 1.47, 1.45, 1.41]:
			brace.append(_on_coat(by, sx * 0.116, 0.005, true))
		for i in brace.size() - 1:
			var mid := (brace[i] + brace[i + 1]) * 0.5
			p.append([BuildingKit.plain(Vector3(0.04, brace[i].distance_to(brace[i + 1]) + 0.008, 0.008)),
				Transform3D(_along(brace[i + 1] - brace[i], mid - Vector3(0, 1.3, 0)), mid)])
	# the pack on his back, a groundsheet rolled on top of it
	p.append([BodyMesh.loft([BodyMesh.ring(1.13, 0.122, 0.044, 0.044, 4.0, 0.0, 0.17), BodyMesh.ring(1.15, 0.135, 0.05, 0.052, 4.0, 0.0, 0.17),
		BodyMesh.ring(1.33, 0.135, 0.05, 0.052, 4.0, 0.0, 0.17), BodyMesh.ring(1.35, 0.122, 0.044, 0.044, 4.0, 0.0, 0.17)], 12), Transform3D.IDENTITY])
	p.append([Res.cyl(0.044, 0.044, 0.27, 12), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 1.395, 0.165))])
	# the double-breasted front's edge down the skirt
	var edge: Array[Vector3] = [_on_coat(1.03, 0.07, 0.002), _on_coat(0.86, 0.075, 0.002), _on_coat(0.66, 0.08, 0.002), _on_coat(0.425, 0.085, 0.002)]
	for i in edge.size() - 1:
		p.append([BuildingKit.plain(Vector3(0.012, edge[i].distance_to(edge[i + 1]) + 0.004, 0.008)),
			Transform3D(_along(edge[i + 1] - edge[i], Vector3.FORWARD), (edge[i] + edge[i + 1]) * 0.5)])
	# his legs below the coat's hem, in puttees, and his boots, turned out a little
	for sx: float in [-1.0, 1.0]:
		var ankle := Vector3(sx * 0.095, 0.0, 0.0)
		p.append([BodyMesh.loft([BodyMesh.ring(0.1, 0.045, 0.047, 0.052), BodyMesh.ring(0.19, 0.049, 0.05, 0.058), BodyMesh.ring(0.3, 0.056, 0.054, 0.068),
			BodyMesh.ring(0.42, 0.055, 0.053, 0.062), BodyMesh.ring(0.52, 0.056, 0.056, 0.06), BodyMesh.ring(0.66, 0.064, 0.064, 0.066)], 12), Transform3D(Basis(), ankle)])
		var toe := Vector3(sin(sx * 0.17), 0.0, -cos(sx * 0.17))
		var boot := []
		for r: Array in BOOT:
			boot.append(BodyMesh.ring(float(r[0]), float(r[1]), float(r[2]), float(r[3]), float(r[4])))
		p.append([BodyMesh.loft(boot, 12), Transform3D(Basis(toe.cross(Vector3.UP), toe, Vector3.UP), ankle + Vector3(0, 0.06, 0))])
	# his arms: from the shoulders the sleeves hang to elbows a little out
	# from his sides, the forearms come in to the rifle, and the hands lie one
	# over the other on its butt
	var muzzle := Vector3(0.0, 0.0, -0.3)
	var heel := Vector3(0.0, 1.13, -0.25)
	var hands := {-1.0: [Vector3(-0.072, 1.168, -0.238), Vector3(0.95, -0.04, -0.3)], 1.0: [Vector3(0.072, 1.19, -0.226), Vector3(-0.95, -0.03, -0.32)]}
	for sx: float in [-1.0, 1.0]:
		var shoulder := Vector3(sx * 0.198, 1.385, 0.01)
		var wrist: Vector3 = hands[sx][0]
		var elbow := _elbow(shoulder, wrist, 0.32, 0.26, Vector3(sx * 0.6, -0.8, 0.1))
		p.append([Res.sphere(0.07, 12), Transform3D(Basis(), shoulder)])
		p.append(_limb(shoulder, elbow, [[0.0, 0.07, 0.07, 0.07], [0.4, 0.07, 0.071, 0.068], [1.0, 0.064, 0.065, 0.064]], Vector3.FORWARD))
		p.append([Res.sphere(0.064, 10), Transform3D(Basis(), elbow)])
		p.append(_limb(elbow, wrist, [[0.0, 0.064, 0.064, 0.064], [0.5, 0.06, 0.06, 0.058], [0.74, 0.057, 0.057, 0.055], [0.78, 0.066, 0.066, 0.064], [1.0, 0.064, 0.064, 0.062]], Vector3.DOWN))
		var dir: Vector3 = (hands[sx][1] as Vector3).normalized()
		p.append(_limb(wrist - dir * 0.02, wrist + dir * 0.17, HAND, Vector3.DOWN))
	# the rifle reversed, its sling hanging slack
	var rifle := Transform3D(_along(heel - muzzle, Vector3.FORWARD), muzzle)
	var stock := []
	for r: Array in RIFLE:
		stock.append(BodyMesh.ring(float(r[0]), float(r[1]), float(r[2]), float(r[3]), float(r[4])))
	p.append([BodyMesh.loft(stock, 10), rifle])
	p.append([Res.sphere(0.016, 6), rifle * Transform3D(Basis(), Vector3(0.034, 0.665, 0.01))])
	var sling: Array[Vector3] = [Vector3(0, 0.27, -0.028), Vector3(0, 0.5, -0.058), Vector3(0, 0.74, -0.062), Vector3(0, 0.95, -0.05)]
	for i in sling.size() - 1:
		p.append([BuildingKit.plain(Vector3(0.026, sling[i].distance_to(sling[i + 1]) + 0.006, 0.006)),
			rifle * Transform3D(_along(sling[i + 1] - sling[i], Vector3.FORWARD), (sling[i] + sling[i + 1]) * 0.5)])
	# his neck, and his head bowed, the helmet over it and its chin strap
	p.append([BodyMesh.loft([BodyMesh.ring(1.42, 0.057, 0.056, 0.06), BodyMesh.ring(1.5, 0.055, 0.054, 0.058, 2.0, 0.0, -0.012), BodyMesh.ring(1.57, 0.053, 0.052, 0.056, 2.0, 0.0, -0.04)], 12), Transform3D.IDENTITY])
	var head := Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0, 1.54, -0.018))
	var skull := []
	for r: Array in HEAD:
		skull.append(BodyMesh.ring(float(r[0]), float(r[1]), float(r[2]), float(r[3]), float(r[4]), 0.0, float(r[5])))
	p.append([BodyMesh.loft(skull, 14), head])
	p.append([Res.sphere(0.5, 8), head * Transform3D(Basis(Vector3.RIGHT, 0.3) * Basis.from_scale(Vector3(0.022, 0.048, 0.034)), Vector3(0, 0.112, -0.1))])
	for sx: float in [-1.0, 1.0]:
		p.append([Res.sphere(0.5, 8), head * Transform3D(Basis.from_scale(Vector3(0.016, 0.058, 0.034)), Vector3(sx * 0.085, 0.115, 0.012))])
		var strap: Array[Vector3] = [Vector3(sx * 0.1, 0.168, 0.006), Vector3(sx * 0.086, 0.09, -0.018), Vector3(sx * 0.048, 0.022, -0.05), Vector3(0, 0.006, -0.06)]
		for i in strap.size() - 1:
			p.append([BuildingKit.plain(Vector3(0.014, strap[i].distance_to(strap[i + 1]) + 0.006, 0.005)),
				head * Transform3D(_along(strap[i + 1] - strap[i], Vector3(sx, 0.0, -0.4)), (strap[i] + strap[i + 1]) * 0.5)])
	var helmet := []
	for r: Array in HELMET:
		helmet.append(BodyMesh.ring(float(r[0]), float(r[1]), float(r[2]), float(r[3]), float(r[4])))
	p.append([BodyMesh.loft(helmet, 20), head * Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.165, 0.004))])
	return p


## (the coat's cross-section at height y, grown by `grow`)
static func _coat_at(y: float, grow := 0.0) -> PackedFloat32Array:
	var i := 0
	while i < COAT.size() - 2 and float(COAT[i + 1][0]) < y:
		i += 1
	var a: Array = COAT[i]
	var b: Array = COAT[i + 1]
	var t := clampf((y - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
	return BodyMesh.ring(y, lerpf(float(a[1]), float(b[1]), t) + grow, lerpf(float(a[2]), float(b[2]), t) + grow,
		lerpf(float(a[3]), float(b[3]), t) + grow, lerpf(float(a[4]), float(b[4]), t))


## (a point on the coat's breast, or its `back`, at height y and across x,
## `out` proud of it)
static func _on_coat(y: float, x: float, out := 0.0, back := false) -> Vector3:
	var r := _coat_at(y, out)
	var u := clampf(absf(x) / r[1], 0.0, 0.999)
	var depth := pow(1.0 - pow(u, r[4]), 1.0 / r[4])
	return Vector3(x, y, r[3] * depth if back else -r[2] * depth)


## (a thing `depth` deep on the coat's breast at height y and across x, its
## back on the coat and its face turned out square to it)
static func _facing(y: float, x: float, depth: float) -> Transform3D:
	var a := _on_coat(y, x - 0.01)
	var b := _on_coat(y, x + 0.01)
	var out := Vector3(b.z - a.z, 0.0, -(b.x - a.x)).normalized()
	return Transform3D(Basis(Vector3.UP, atan2(-out.x, -out.z)), _on_coat(y, x) + out * (depth * 0.5 - 0.004))


## (a loft along a limb from a to b: its rings [fraction along, half width,
## front, back, squareness, curl], its front turned as near `front` as it goes)
static func _limb(a: Vector3, b: Vector3, rings: Array, front: Vector3) -> Array:
	var ln := a.distance_to(b)
	var rs := []
	for r: Array in rings:
		rs.append(BodyMesh.ring(float(r[0]) * ln, float(r[1]), float(r[2]), float(r[3]), float(r[4]) if r.size() > 4 else 2.0, 0.0, float(r[5]) if r.size() > 5 else 0.0))
	return [BodyMesh.loft(rs, 10), Transform3D(_along(b - a, front), a)]


## (a basis with +y along `axis` and -z as near `front` as it can be)
static func _along(axis: Vector3, front: Vector3) -> Basis:
	var y := axis.normalized()
	var z := -(front - y * front.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


## (where an elbow goes for a shoulder and a wrist so far apart, bent toward `pole`)
static func _elbow(shoulder: Vector3, wrist: Vector3, upper: float, fore: float, pole: Vector3) -> Vector3:
	var d := wrist - shoulder
	var dl := clampf(d.length(), 0.01, upper + fore - 0.001)
	var u := d.normalized()
	var ca := clampf((upper * upper + dl * dl - fore * fore) / (2.0 * upper * dl), -1.0, 1.0)
	var side := (pole - u * pole.dot(u)).normalized()
	return shoulder + (u * ca + side * sqrt(1.0 - ca * ca)) * upper


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
