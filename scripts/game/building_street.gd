class_name BuildingStreet
extends RefCounted
## The furniture of a town's streets beyond its lamps and poles: traffic
## lights at the crossroads (dark: the power's off), a telephone box, post
## boxes, an advertising column on the square, hoardings over a car park or a
## bombed-out lot, street names on posts at the junctions, and what people
## running from the fighting left on the pavements. Each in a kit at its foot,
## its face (or its front) toward -z, the street.

const POLE := Color(0.24, 0.28, 0.26)
const SIGNS := [[Color(0.12, 0.2, 0.42), Color(0.92, 0.92, 0.88)], [Color(0.92, 0.91, 0.86), Color(0.1, 0.1, 0.1)], [Color(0.1, 0.1, 0.1), Color(0.92, 0.9, 0.84)]]
## Posters: the ground of each, and what's printed on it.
const POSTERS := [[Color(0.85, 0.2, 0.14), Color(0.96, 0.92, 0.8)], [Color(0.95, 0.82, 0.25), Color(0.12, 0.12, 0.14)], [Color(0.18, 0.32, 0.6), Color(0.95, 0.95, 0.9)],
	[Color(0.92, 0.9, 0.84), Color(0.7, 0.12, 0.1)], [Color(0.2, 0.45, 0.28), Color(0.95, 0.9, 0.7)], [Color(0.12, 0.12, 0.14), Color(0.95, 0.75, 0.2)]]
const LUGGAGE := [Color(0.38, 0.25, 0.16), Color(0.12, 0.12, 0.13), Color(0.16, 0.22, 0.38), Color(0.5, 0.14, 0.12), Color(0.42, 0.4, 0.34)]


## A traffic light on its pole: a head facing the street (-z), and one facing
## the cross street (local +x, or -x with `side` < 0), their lenses dark.
## Now and then one hangs askew from its bracket, or the pole leans where
## something hit it.
static func traffic_light(k: BuildingKit, side: float, rng: RandomNumberGenerator) -> void:
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12)) if rng.randf() < 0.2 else Vector3.ZERO
	var p := k.at_point(Vector3.ZERO, lean)
	p.cyl(0.12, 0.14, 0.2, Vector3(0, 0.1, 0), "metal_dark", POLE.darkened(0.2), Vector3.ZERO, 10)
	p.cyl(0.055, 0.06, 3.3, Vector3(0, 1.65, 0), "metal_dark", POLE, Vector3.ZERO, 8)
	p.box(Vector3(0.13, 0.2, 0.1), Vector3(0, 1.1, -0.1), "paint", Color(0.82, 0.76, 0.3))
	var askew := rng.randi() % 6
	for i in 2:
		var yaw := 0.0 if i == 0 else -side * PI * 0.5
		var tilt := Vector3(0, 0, rng.randf_range(0.5, 1.1)) if askew == i else Vector3.ZERO
		head(p.at_point(Vector3(0, 2.75, 0), Vector3(0, yaw, 0)).at_point(Vector3(0, 0.45, -0.14), tilt))


## A three-lens signal head, hung from its top at the kit's origin, facing
## -z: the housing, the backboard, the hooded lenses (red, amber, green;
## unlit).
static func head(k: BuildingKit) -> void:
	k.box(Vector3(0.3, 0.88, 0.22), Vector3(0, -0.45, 0), "plain_dark", Color(0.1, 0.1, 0.1))
	k.plate(Vector3(0.48, 1.02, 0.02), Vector3(0, -0.45, 0.12), "plain_dark", Color(0.06, 0.06, 0.06))
	k.bar(Vector3(0, 0.0, 0.0), Vector3(0, 0.05, 0.14), 0.04, 0.04, "metal_dark", POLE, false)
	for i in 3:
		var y := -0.18 - i * 0.27
		var dead: Color = [Color(0.3, 0.06, 0.05), Color(0.32, 0.22, 0.05), Color(0.05, 0.22, 0.12)][i]
		k.cyl(0.085, 0.085, 0.02, Vector3(0, y, -0.115), "glass", dead, Vector3(PI * 0.5, 0, 0), 12, false)
		k.plate(Vector3(0.22, 0.015, 0.16), Vector3(0, y + 0.1, -0.18), "plain_dark", Color(0.08, 0.08, 0.08), Vector3(-0.25, 0, 0), false)


## A telephone box: plinth, corner posts, glazed sides in their bars (a pane
## or two shot out), the door to the street, the roof with the word under
## it, the telephone inside on the back wall.
static func phone_box(k: BuildingKit, col: Color, rng: RandomNumberGenerator) -> void:
	var w := 0.92
	var h := 2.35
	k.box(Vector3(w + 0.1, 0.1, w + 0.1), Vector3(0, 0.05, 0), "concrete", Color(0.55, 0.54, 0.5))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.08, h, 0.08), Vector3(sx * (w * 0.5 - 0.04), 0.1 + h * 0.5, sz * (w * 0.5 - 0.04)), "paint", col)
	k.box(Vector3(w + 0.08, 0.2, w + 0.08), Vector3(0, 0.1 + h + 0.1, 0), "paint", col)
	k.box(Vector3(w - 0.1, 0.1, w - 0.1), Vector3(0, 0.1 + h + 0.25, 0), "paint", col.darkened(0.1))
	for f in 4:
		var a := f * PI * 0.5
		var face := k.at_point(Vector3(sin(a), 0, -cos(a)) * (w * 0.5 - 0.02), Vector3(0, -a, 0))
		face.plate(Vector3(w - 0.24, 0.13, 0.015), Vector3(0, 0.1 + h - 0.12, -0.01), "paint", Color(0.92, 0.9, 0.84))
		BuildingShops.lettering(face.at_point(Vector3(0, 0.1 + h - 0.12, -0.02)), w - 0.36, Color(0.1, 0.1, 0.1), rng, 1)
		if f == 2:
			face.plate(Vector3(w - 0.16, h - 0.4, 0.04), Vector3(0, 0.1 + (h - 0.4) * 0.5 + 0.1, 0.02), "paint", col.darkened(0.15))
			continue
		face.plate(Vector3(w - 0.16, 0.5, 0.04), Vector3(0, 0.1 + 0.25, 0), "paint", col)
		for r in 3:
			for c in 2:
				if rng.randf() < 0.12:
					continue  # (shot out)
				face.plate(Vector3((w - 0.2) * 0.5 - 0.03, 0.42, 0.006), Vector3((c - 0.5) * (w - 0.2) * 0.5, 0.1 + 0.55 + r * 0.46 + 0.21, 0), "glass", Color(0.5, 0.55, 0.55))
		for r in 4:
			face.plate(Vector3(w - 0.16, 0.035, 0.03), Vector3(0, 0.1 + 0.53 + r * 0.46, 0), "paint", col)
		face.plate(Vector3(0.035, h - 0.6, 0.03), Vector3(0, 0.1 + 0.5 + (h - 0.6) * 0.5, 0), "paint", col)
		if f == 0:
			face.bar(Vector3(w * 0.5 - 0.12, 1.0, -0.03), Vector3(w * 0.5 - 0.12, 1.25, -0.03), 0.03, 0.03, "metal_dark", Color(0.6, 0.55, 0.4), false)
	k.box(Vector3(0.24, 0.3, 0.14), Vector3(0, 1.45, w * 0.5 - 0.14), "plain_dark", Color(0.15, 0.15, 0.15))
	k.box(Vector3(0.06, 0.2, 0.08), Vector3(-0.17, 1.5, w * 0.5 - 0.16), "plain_dark", Color(0.08, 0.08, 0.08))


## A pillar post box: its plinth, the column, the cap, the slot and the plate
## with the collection times.
static func post_box(k: BuildingKit, col := Color(0.72, 0.1, 0.08)) -> void:
	k.cyl(0.25, 0.26, 0.12, Vector3(0, 0.06, 0), "plain_dark", Color(0.12, 0.12, 0.12), Vector3.ZERO, 14)
	k.cyl(0.24, 0.24, 1.15, Vector3(0, 0.12 + 0.575, 0), "paint", col, Vector3.ZERO, 14)
	k.cyl(0.29, 0.27, 0.08, Vector3(0, 1.31, 0), "paint", col.darkened(0.08), Vector3.ZERO, 14)
	k.part(Res.sphere(0.24, 8), "paint", Transform3D(Basis.from_scale(Vector3(1.0, 0.45, 1.0)), Vector3(0, 1.36, 0)), col, false)
	k.plate(Vector3(0.24, 0.035, 0.03), Vector3(0, 1.12, -0.235), "plain_dark", Color(0.04, 0.04, 0.04))
	k.plate(Vector3(0.14, 0.11, 0.012), Vector3(0, 0.88, -0.24), "paint", Color(0.92, 0.9, 0.84))


## An advertising column on the square: the drum, posters pasted round it (a
## headline on some, torn on others), the cap with its rim.
static func ad_column(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var r := 0.62
	k.cyl(r + 0.05, r + 0.07, 0.25, Vector3(0, 0.125, 0), "paint", Color(0.18, 0.24, 0.2), Vector3.ZERO, 16)
	k.cyl(r, r, 2.4, Vector3(0, 0.25 + 1.2, 0), "paint", Color(0.82, 0.8, 0.72), Vector3.ZERO, 16)
	k.cyl(r + 0.1, r + 0.04, 0.14, Vector3(0, 2.72, 0), "paint", Color(0.18, 0.24, 0.2), Vector3.ZERO, 16)
	k.part(Res.sphere(r, 8), "paint", Transform3D(Basis.from_scale(Vector3(1.0, 0.4, 1.0)), Vector3(0, 2.79, 0)), Color(0.2, 0.27, 0.22), false)
	# (pasted all round, edge to edge, three deep; one now and then torn
	# down to the paper under it)
	var n := 10
	for i in n:
		var a := TAU * (i + 0.5) / n
		var face := k.at_point(Vector3(sin(a), 0, -cos(a)) * (r + 0.006), Vector3(0, -a, 0))
		for row in 3:
			var pc: Array = POSTERS[rng.randi() % POSTERS.size()]
			var y := 0.65 + row * 0.72
			if rng.randf() < 0.1:
				face.plate(Vector3(0.36, rng.randf_range(0.2, 0.5), 0.004), Vector3(0, y - 0.1, 0), "paint", Color(0.86, 0.82, 0.7), Vector3(0, 0, rng.randf_range(-0.2, 0.2)), false)
				continue
			face.plate(Vector3(TAU * r / n - 0.02, 0.68, 0.004), Vector3(0, y, 0), "paint", pc[0], Vector3.ZERO, false)
			if rng.randf() < 0.5:
				BuildingShops.lettering(face.at_point(Vector3(0, y + 0.18, -0.006)), 0.3, pc[1], rng, 1)
			else:
				face.plate(Vector3(0.24, 0.26, 0.003), Vector3(0, y - 0.08, -0.004), "paint", pc[1], Vector3.ZERO, false)


## A hoarding `w` wide on its posts (the face to -z): the board, posters
## pasted across it, one half torn off or pasted over, the lamps over it.
static func hoarding(k: BuildingKit, w: float, rng: RandomNumberGenerator) -> void:
	var h := 2.4
	var bottom := 1.0
	var wood := Color(0.32, 0.25, 0.18)
	for x: float in [-(w * 0.5 - 0.4), 0.0, w * 0.5 - 0.4]:
		k.box(Vector3(0.12, bottom + h, 0.12), Vector3(x, (bottom + h) * 0.5, 0.14), "wood_dark", wood)
		k.bar(Vector3(x, 0.0, 0.9), Vector3(x, bottom + h * 0.6, 0.2), 0.09, 0.09, "wood_dark", wood, false)
	k.box(Vector3(w, h, 0.06), Vector3(0, bottom + h * 0.5, 0.05), "wood", Color(0.36, 0.33, 0.28))
	k.box(Vector3(w + 0.12, 0.1, 0.12), Vector3(0, bottom + h + 0.05, 0.04), "paint", Color(0.18, 0.2, 0.18))
	k.box(Vector3(w + 0.12, 0.1, 0.12), Vector3(0, bottom - 0.05, 0.04), "paint", Color(0.18, 0.2, 0.18))
	var halves := 2 if w > 4.0 else 1
	var pw := (w - 0.2) / halves
	for i in halves:
		var cx := -w * 0.5 + 0.1 + (i + 0.5) * pw
		var pc: Array = POSTERS[rng.randi() % POSTERS.size()]
		var torn := rng.randf() < 0.35
		var face := k.at_point(Vector3(cx, bottom + h * 0.5, -0.01))
		if torn:
			# half of it torn away, the paper under it showing in scraps
			face.plate(Vector3(pw - 0.1, h * 0.45, 0.004), Vector3(0, h * 0.24, 0), "paint", pc[0], Vector3.ZERO, false)
			for s in rng.randi_range(3, 6):
				face.plate(Vector3(rng.randf_range(0.15, 0.5), rng.randf_range(0.12, 0.4), 0.004), Vector3(rng.randf_range(-pw * 0.4, pw * 0.4), rng.randf_range(-h * 0.45, 0.0), -0.002), "paint",
					(POSTERS[rng.randi() % POSTERS.size()][0] as Color).lightened(0.15), Vector3(0, 0, rng.randf_range(-0.4, 0.4)), false)
			continue
		face.plate(Vector3(pw - 0.1, h - 0.14, 0.004), Vector3.ZERO, "paint", pc[0], Vector3.ZERO, false)
		BuildingShops.lettering(face.at_point(Vector3(0, h * 0.28, -0.004)), pw * 0.8, pc[1], rng, rng.randi_range(1, 2))
		# the picture: a block of colour with a figure in it, the line under it
		var pic: Color = POSTERS[rng.randi() % POSTERS.size()][1]
		face.plate(Vector3(pw * 0.5, h * 0.42, 0.003), Vector3(-pw * 0.18, -h * 0.12, -0.003), "paint", pic.darkened(0.25), Vector3.ZERO, false)
		face.cyl(h * 0.11, h * 0.11, 0.004, Vector3(-pw * 0.18, -h * 0.06, -0.006), "paint", pc[1], Vector3(PI * 0.5, 0, 0), 12, false)
		BuildingShops.lettering(face.at_point(Vector3(pw * 0.2, -h * 0.3, -0.004)), pw * 0.4, pc[1], rng, 1)
	for x: float in [-w * 0.25, w * 0.25]:
		k.bar(Vector3(x, bottom + h + 0.1, 0.0), Vector3(x, bottom + h + 0.35, -0.55), 0.035, 0.035, "metal_dark", Color(0.2, 0.2, 0.2), false)
		k.box(Vector3(0.36, 0.08, 0.16), Vector3(x, bottom + h + 0.34, -0.6), "metal_dark", Color(0.22, 0.22, 0.22), Vector3.ZERO, false)


## A street's name on a post at a corner: two blades, one along each street
## (local x and z), the names in raised letters both sides.
static func street_name(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var c: Array = SIGNS[rng.randi() % SIGNS.size()]
	k.cyl(0.04, 0.045, 2.55, Vector3(0, 1.275, 0), "metal_dark", Color(0.45, 0.46, 0.45), Vector3.ZERO, 6)
	for i in 2:
		var blade := k.at_point(Vector3(0, 2.42 - i * 0.2, 0), Vector3(0, i * PI * 0.5, 0))
		blade.box(Vector3(0.8, 0.17, 0.03), Vector3(0.36, 0, 0), "paint", c[0])
		for s: float in [-1.0, 1.0]:
			BuildingShops.lettering(blade.at_point(Vector3(0.36, 0, s * 0.016), Vector3(0, 0.0 if s < 0.0 else PI, 0)), 0.62, c[1], rng, 1)


## What someone running from the fighting dropped on the pavement: a case
## or two, a holdall, a bundle in a blanket, now and then a pram or a bike on
## its side, papers blown about.
static func belongings(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(1, 3):
		var s := Vector3(rng.randf_range(0.5, 0.72), rng.randf_range(0.36, 0.48), rng.randf_range(0.17, 0.24))
		var col: Color = LUGGAGE[rng.randi() % LUGGAGE.size()]
		var flat := rng.randf() < 0.5
		var c := k.at_point(Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.4, 0.4)), Vector3(0, rng.randf() * TAU, 0))
		if flat:
			c.box(Vector3(s.x, s.z, s.y), Vector3(0, s.z * 0.5, 0), "canvas", col)
		else:
			c.box(s, Vector3(0, s.y * 0.5, 0), "canvas", col)
			c.bar(Vector3(-0.08, s.y, 0), Vector3(0.08, s.y, 0), 0.03, 0.03, "plain_dark", Color(0.1, 0.1, 0.1), false)
	if rng.randf() < 0.6:
		k.part(Res.cyl(0.16, 0.16, 0.6, 10), "canvas", Mats.place(Vector3(rng.randf_range(-0.6, 0.6), 0.15, rng.randf_range(-0.5, 0.5)), Vector3(0, rng.randf() * TAU, PI * 0.5)),
			[Color(0.22, 0.3, 0.2), Color(0.3, 0.22, 0.18), Color(0.2, 0.22, 0.3)][rng.randi() % 3])
	if rng.randf() < 0.5:
		k.part(Res.sphere(0.32, 8), "canvas", Transform3D(Basis.from_scale(Vector3(1.2, 0.6, 0.9)).rotated(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.6, 0.6), 0.18, rng.randf_range(-0.5, 0.5))),
			BuildingFurnishings.FABRICS[rng.randi() % BuildingFurnishings.FABRICS.size()])
	var extra := rng.randf()
	if extra < 0.25:
		pram(k.at_point(Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.6, 0.6)), Vector3(0, rng.randf() * TAU, 0)), LUGGAGE[rng.randi() % LUGGAGE.size()])
	elif extra < 0.45:
		BuildingYards.bicycle(k.at_point(Vector3(rng.randf_range(-0.5, 0.5), 0.05, rng.randf_range(-0.5, 0.5)), Vector3(0, rng.randf() * TAU, PI * 0.5)), BuildingYards.BIKE_COLS[rng.randi() % BuildingYards.BIKE_COLS.size()])
	for i in rng.randi_range(2, 6):
		k.plate(Vector3(0.21, 0.003, 0.3), Vector3(rng.randf_range(-1.4, 1.4), 0.004 + i * 0.001, rng.randf_range(-1.0, 1.0)), "paint", Color(0.9, 0.88, 0.82).darkened(rng.randf_range(0.0, 0.2)), Vector3(0, rng.randf() * TAU, 0), false)


## A pram: the body on its springs, the hood up, four wheels, the handle.
static func pram(k: BuildingKit, col: Color) -> void:
	k.box(Vector3(0.42, 0.3, 0.8), Vector3(0, 0.55, 0), "canvas", col)
	k.part(Res.sphere(0.24, 8), "canvas", Transform3D(Basis.from_scale(Vector3(0.9, 1.0, 0.9)), Vector3(0, 0.7, -0.26)), col.darkened(0.2), false)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.part(BuildingKit.ring(0.11, 0.135), "rubber", Mats.place(Vector3(sx * 0.24, 0.13, sz * 0.3), Vector3(0, 0, PI * 0.5)), Color(0.08, 0.08, 0.08), false)
		k.rod(Vector3(sx * 0.18, 0.4, 0.38), Vector3(sx * 0.2, 0.95, 0.62), 0.012, "metal_dark", Color(0.6, 0.6, 0.6), 4, false)
	k.rod(Vector3(-0.2, 0.95, 0.62), Vector3(0.2, 0.95, 0.62), 0.016, "metal_dark", Color(0.6, 0.6, 0.6), 4, false)
