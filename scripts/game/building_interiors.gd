class_name BuildingInteriors
extends RefCounted
## What a house has in it: against the walls with no window or door in them
## a wardrobe, a bookcase, a dresser with the television or a lamp on it, a
## settee, a kitchen run (cupboards, the sink, the cooker, wall cupboards
## over it), a desk; in the middle of the room a table and its chairs, one of
## them knocked over now and then. Looks only, like the pictures on the walls,
## and in the walls' own materials (world-space, so a town's walls still draw
## together). Work in a wall's room kit (at its inner face: x along it, y up
## from the ground, +z into the room) or the floor's (centred on the room).

## How far anything stands out from its wall, and how far it keeps in from
## either end of it: two walls meeting in a corner then never put things in
## each other's way (each keeps out of what the other's can reach).
const REACH := 0.65
## The top of the floor slab.
const FLOOR := 0.06
const WOODS := [Color(0.42, 0.28, 0.17), Color(0.3, 0.2, 0.13), Color(0.55, 0.4, 0.26), Color(0.24, 0.17, 0.11)]
const UNITS := [Color(0.88, 0.86, 0.8), Color(0.56, 0.64, 0.52), Color(0.44, 0.52, 0.62), Color(0.82, 0.74, 0.56)]
const BRASS := Color(0.62, 0.5, 0.26)


## Something against a wall `length` long, picked by `rng` from what fits
## between its ends. True if it stands tall against the wall (a wardrobe, a
## bookcase, wall cupboards), so nothing else hangs there.
static func against_wall(k: BuildingKit, length: float, rng: RandomNumberGenerator) -> bool:
	var room := length - REACH * 2.0
	var pick := rng.randf()
	var wood: Color = WOODS[rng.randi() % WOODS.size()]
	var slide := rng.randf_range(-1.0, 1.0)
	var at := func(w: float) -> float: return slide * maxf(0.0, room - w) * 0.5
	if pick < 0.2 and room >= 1.05:
		wardrobe(k, at.call(1.05), wood, rng)
		return true
	if pick < 0.36:
		bookcase(k, at.call(0.9), wood, rng)
		return true
	if pick < 0.54 and room >= 1.2:
		dresser(k, at.call(1.2), wood, rng)
		return false
	if pick < 0.72 and room >= 1.3:
		var w := minf(1.9, room)
		settee(k, at.call(w), w, BuildingFurnishings.FABRICS[rng.randi() % BuildingFurnishings.FABRICS.size()], rng)
		return false
	if pick < 0.9 and room >= 1.5:
		var w := minf(2.4, room)
		kitchen(k, at.call(w), w, UNITS[rng.randi() % UNITS.size()], rng)
		return true
	if room >= 1.0:
		desk(k, at.call(1.0), wood, rng)
		return false
	bookcase(k, at.call(0.9), wood, rng)
	return true


## A wardrobe: its body on a plinth under a cornice, two doors with their
## handles, a suitcase on top of some.
static func wardrobe(k: BuildingKit, x: float, wood: Color, rng: RandomNumberGenerator) -> void:
	var w := 1.05
	var d := 0.58
	var h := 1.95
	k.box(Vector3(w, h - 0.08, d), Vector3(x, FLOOR + 0.08 + (h - 0.08) * 0.5, d * 0.5), "wood", wood)
	k.box(Vector3(w - 0.06, 0.08, d - 0.04), Vector3(x, FLOOR + 0.04, d * 0.5 - 0.02), "wood_dark", wood.darkened(0.3))
	k.box(Vector3(w + 0.06, 0.06, d + 0.04), Vector3(x, FLOOR + h + 0.03, d * 0.5 + 0.01), "wood", wood.darkened(0.12))
	for s: float in [-1.0, 1.0]:
		k.plate(Vector3(w * 0.5 - 0.04, h - 0.26, 0.015), Vector3(x + s * w * 0.25, FLOOR + 0.12 + (h - 0.26) * 0.5, d + 0.008), "wood", wood.lightened(0.06))
		k.bar(Vector3(x + s * 0.05, FLOOR + 1.0, d + 0.025), Vector3(x + s * 0.05, FLOOR + 1.16, d + 0.025), 0.015, 0.015, "metal_dark", BRASS, false)
	if rng.randf() < 0.35:
		k.box(Vector3(0.62, 0.2, 0.42), Vector3(x + rng.randf_range(-0.15, 0.15), FLOOR + h + 0.16, d * 0.5), "canvas", [Color(0.36, 0.25, 0.17), Color(0.22, 0.25, 0.3), Color(0.45, 0.16, 0.12)][rng.randi() % 3])


## A bookcase: its sides, back and shelves, books standing along each shelf
## (a gap here and there, one leaning).
static func bookcase(k: BuildingKit, x: float, wood: Color, rng: RandomNumberGenerator) -> void:
	var w := 0.9
	var d := 0.3
	var h := 1.85
	k.plate(Vector3(w, h, 0.02), Vector3(x, FLOOR + h * 0.5, 0.01), "wood", wood.darkened(0.2))
	for s: float in [-1.0, 1.0]:
		k.box(Vector3(0.03, h, d), Vector3(x + s * (w * 0.5 - 0.015), FLOOR + h * 0.5, d * 0.5), "wood", wood)
	var shelves := 5
	for i in shelves + 1:
		var y := FLOOR + 0.06 + i * (h - 0.09) / shelves
		k.box(Vector3(w - 0.06, 0.025, d - 0.02), Vector3(x, y, d * 0.5), "wood", wood)
		if i == shelves:
			break
		# (in runs, a set or a shelf-full of one kind together, gaps between)
		var bx := x - w * 0.5 + 0.04
		while bx < x + w * 0.5 - 0.1:
			var bw := minf(rng.randf_range(0.1, 0.3), x + w * 0.5 - 0.04 - bx)
			var bh := rng.randf_range(0.18, 0.28)
			var col: Color = BuildingFurnishings.BOOKS[rng.randi() % BuildingFurnishings.BOOKS.size()]
			k.box(Vector3(bw, bh, rng.randf_range(0.17, 0.22)), Vector3(bx + bw * 0.5, y + 0.0125 + bh * 0.5, d * 0.5), "paint", col.darkened(rng.randf_range(0.0, 0.25)), Vector3.ZERO, false)
			bx += bw + rng.randf_range(0.005, 0.08)


## A dresser: drawers under a top, and on it the television or a lamp.
static func dresser(k: BuildingKit, x: float, wood: Color, rng: RandomNumberGenerator) -> void:
	var w := 1.2
	var d := 0.46
	var h := 0.82
	k.box(Vector3(w, h - 0.03, d), Vector3(x, FLOOR + (h - 0.03) * 0.5, d * 0.5), "wood", wood)
	k.box(Vector3(w + 0.04, 0.03, d + 0.03), Vector3(x, FLOOR + h - 0.015, d * 0.5 + 0.01), "wood", wood.darkened(0.15))
	for row in 3:
		for col in 2:
			var c := Vector3(x + (col - 0.5) * (w * 0.5), FLOOR + 0.13 + row * 0.22, d + 0.006)
			k.plate(Vector3(w * 0.5 - 0.05, 0.18, 0.012), c, "wood", wood.lightened(0.05))
			k.plate(Vector3(0.1, 0.018, 0.02), c + Vector3(0, 0.02, 0.012), "metal_dark", BRASS, Vector3.ZERO, false)
	var top := FLOOR + h
	if rng.randf() < 0.5:
		# an old television, its screen grey
		var tx := x + rng.randf_range(-0.2, 0.2)
		k.box(Vector3(0.56, 0.42, 0.42), Vector3(tx, top + 0.21, 0.24), "plain_dark", Color(0.12, 0.12, 0.12))
		k.plate(Vector3(0.44, 0.32, 0.01), Vector3(tx - 0.03, top + 0.22, 0.455), "glass", Color(0.24, 0.27, 0.28))
		k.rod(Vector3(tx, top + 0.42, 0.24), Vector3(tx - 0.22, top + 0.72, 0.18), 0.006, "metal_dark", Color(0.6, 0.6, 0.6), 3, false)
		k.rod(Vector3(tx, top + 0.42, 0.24), Vector3(tx + 0.22, top + 0.72, 0.18), 0.006, "metal_dark", Color(0.6, 0.6, 0.6), 3, false)
	else:
		# a lamp, and a jug or a plant
		var lx := x - w * 0.3
		k.cyl(0.07, 0.09, 0.05, Vector3(lx, top + 0.025, d * 0.5), "paint", BRASS, Vector3.ZERO, 8, false)
		k.rod(Vector3(lx, top + 0.05, d * 0.5), Vector3(lx, top + 0.38, d * 0.5), 0.012, "metal_dark", BRASS, 4, false)
		k.cyl(0.08, 0.15, 0.2, Vector3(lx, top + 0.44, d * 0.5), "canvas", Color(0.86, 0.8, 0.64), Vector3.ZERO, 10, false)
		var jx := x + w * 0.28
		if rng.randf() < 0.5:
			k.cyl(0.06, 0.08, 0.2, Vector3(jx, top + 0.1, d * 0.5), "paint", [Color(0.3, 0.4, 0.6), Color(0.75, 0.72, 0.65), Color(0.55, 0.25, 0.18)][rng.randi() % 3], Vector3.ZERO, 8, false)
		else:
			k.cyl(0.08, 0.06, 0.14, Vector3(jx, top + 0.07, d * 0.5), "paint", Color(0.6, 0.32, 0.2), Vector3.ZERO, 8, false)
			k.part(Res.sphere(0.13, 6), "paint", Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 1.0)), Vector3(jx, top + 0.24, d * 0.5)), Color(0.25, 0.42, 0.2), false)


## A settee `w` wide: its base, the seat cushions, the back and the arms,
## a cushion thrown in one corner.
static func settee(k: BuildingKit, x: float, w: float, cloth: Color, rng: RandomNumberGenerator) -> void:
	var d := 0.62
	var arm := 0.14
	k.box(Vector3(w, 0.26, d - 0.06), Vector3(x, FLOOR + 0.1 + 0.13, d * 0.5 + 0.03), "canvas", cloth.darkened(0.12))
	for s: float in [-1.0, 1.0]:
		k.bar(Vector3(x + s * (w * 0.5 - 0.08), FLOOR, d - 0.08), Vector3(x + s * (w * 0.5 - 0.08), FLOOR + 0.1, d - 0.08), 0.04, 0.04, "wood_dark", Color(0.2, 0.14, 0.09), false)
		k.box(Vector3(arm, 0.56, d), Vector3(x + s * (w * 0.5 - arm * 0.5), FLOOR + 0.1 + 0.28, d * 0.5), "canvas", cloth)
	var seats := 3 if w > 1.6 else 2
	var sw := (w - arm * 2.0) / seats
	for i in seats:
		k.box(Vector3(sw - 0.02, 0.12, d - 0.2), Vector3(x - w * 0.5 + arm + (i + 0.5) * sw, FLOOR + 0.42, d * 0.5 + 0.08), "canvas", cloth.lightened(0.05))
		k.box(Vector3(sw - 0.02, 0.4, 0.16), Vector3(x - w * 0.5 + arm + (i + 0.5) * sw, FLOOR + 0.62, 0.12), "canvas", cloth)
	if rng.randf() < 0.6:
		var cx := x + (w * 0.5 - arm - 0.22) * (1.0 if rng.randf() < 0.5 else -1.0)
		k.box(Vector3(0.36, 0.34, 0.12), Vector3(cx, FLOOR + 0.62, 0.3), "canvas", BuildingFurnishings.FABRICS[rng.randi() % BuildingFurnishings.FABRICS.size()],
			Vector3(-0.35, rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.2)), false)


## A kitchen run `w` long: the cupboards under a worktop, the sink with its
## tap, the cooker at one end with its rings and oven door, wall cupboards
## over it, a kettle or a pan on the side.
static func kitchen(k: BuildingKit, x: float, w: float, col: Color, rng: RandomNumberGenerator) -> void:
	var d := 0.58
	var h := 0.88
	var end := 1.0 if rng.randf() < 0.5 else -1.0
	var cooker := x + end * (w * 0.5 - 0.3)
	var run := w - 0.6
	var rx := x - end * 0.3
	k.box(Vector3(run, h - 0.1, d), Vector3(rx, FLOOR + 0.1 + (h - 0.1) * 0.5, d * 0.5), "paint", col)
	k.box(Vector3(run - 0.04, 0.1, d - 0.06), Vector3(rx, FLOOR + 0.05, d * 0.5 - 0.03), "plain_dark", Color(0.15, 0.15, 0.14))
	var doors := maxi(1, int(run / 0.5))
	for i in doors:
		var dx := rx - run * 0.5 + (i + 0.5) * run / doors
		k.plate(Vector3(run / doors - 0.03, h - 0.18, 0.015), Vector3(dx, FLOOR + 0.1 + (h - 0.18) * 0.5, d + 0.008), "paint", col.lightened(0.06))
		k.bar(Vector3(dx - 0.1, FLOOR + h - 0.14, d + 0.025), Vector3(dx + 0.1, FLOOR + h - 0.14, d + 0.025), 0.012, 0.012, "metal_dark", Color(0.65, 0.65, 0.63), false)
	k.box(Vector3(w + 0.02, 0.04, d + 0.04), Vector3(x, FLOOR + h + 0.02, d * 0.5 + 0.02), "wood", Color(0.5, 0.36, 0.22))
	# the sink: a steel bowl let into the top, its tap
	var sx := rx + rng.randf_range(-0.15, 0.15) * maxf(0.0, run - 0.6)
	k.plate(Vector3(0.52, 0.006, 0.4), Vector3(sx, FLOOR + h + 0.043, d * 0.5), "steel", Color(0.7, 0.7, 0.7))
	k.plate(Vector3(0.36, 0.006, 0.3), Vector3(sx, FLOOR + h + 0.046, d * 0.5 + 0.02), "plain_dark", Color(0.32, 0.33, 0.34))
	k.rod(Vector3(sx, FLOOR + h + 0.04, 0.08), Vector3(sx, FLOOR + h + 0.28, 0.08), 0.012, "steel", Color(0.75, 0.75, 0.75), 4, false)
	k.rod(Vector3(sx, FLOOR + h + 0.28, 0.08), Vector3(sx, FLOOR + h + 0.24, 0.24), 0.012, "steel", Color(0.75, 0.75, 0.75), 4, false)
	# the cooker
	k.box(Vector3(0.58, h + 0.02, d), Vector3(cooker, FLOOR + (h + 0.02) * 0.5, d * 0.5), "paint", Color(0.88, 0.87, 0.84))
	k.plate(Vector3(0.46, 0.34, 0.012), Vector3(cooker, FLOOR + 0.32, d + 0.006), "glass", Color(0.12, 0.12, 0.12))
	k.bar(Vector3(cooker - 0.2, FLOOR + 0.56, d + 0.03), Vector3(cooker + 0.2, FLOOR + 0.56, d + 0.03), 0.015, 0.015, "metal_dark", Color(0.6, 0.6, 0.6), false)
	for i in 4:
		var rp := Vector3(cooker + (0.13 if i % 2 == 0 else -0.13), FLOOR + h + 0.03, d * 0.5 + (0.12 if i < 2 else -0.12))
		k.cyl(0.08, 0.08, 0.012, rp, "plain_dark", Color(0.1, 0.1, 0.1), Vector3.ZERO, 10, false)
	k.plate(Vector3(0.58, 0.12, 0.03), Vector3(cooker, FLOOR + h + 0.08, 0.02), "paint", Color(0.85, 0.84, 0.8))
	# wall cupboards over the run (clear of the cooker's heat)
	var uw := run * 0.8
	k.box(Vector3(uw, 0.62, 0.32), Vector3(rx, FLOOR + 1.52 + 0.31, 0.16), "paint", col)
	for i in maxi(1, int(uw / 0.5)):
		var n := maxi(1, int(uw / 0.5))
		k.plate(Vector3(uw / n - 0.03, 0.56, 0.012), Vector3(rx - uw * 0.5 + (i + 0.5) * uw / n, FLOOR + 1.83, 0.327), "paint", col.lightened(0.06))
	if rng.randf() < 0.6:
		var kx := rx + run * 0.35 * -end
		k.cyl(0.07, 0.08, 0.2, Vector3(kx, FLOOR + h + 0.14, d * 0.5), "steel", Color(0.72, 0.72, 0.7), Vector3.ZERO, 10, false)
	if rng.randf() < 0.5:
		k.cyl(0.1, 0.1, 0.1, Vector3(cooker + 0.13, FLOOR + h + 0.09, d * 0.5 + 0.12), "metal_dark", Color(0.25, 0.25, 0.26), Vector3.ZERO, 10, false)


## A writing desk on its pedestal, its chair pushed in under it, papers and
## a lamp on top.
static func desk(k: BuildingKit, x: float, wood: Color, rng: RandomNumberGenerator) -> void:
	var w := 1.0
	var d := 0.55
	var h := 0.74
	k.box(Vector3(w, 0.035, d), Vector3(x, FLOOR + h - 0.018, d * 0.5), "wood", wood)
	k.box(Vector3(0.38, h - 0.04, d - 0.04), Vector3(x + w * 0.5 - 0.21, FLOOR + (h - 0.04) * 0.5, d * 0.5), "wood", wood.darkened(0.08))
	for i in 3:
		k.plate(Vector3(0.34, 0.18, 0.012), Vector3(x + w * 0.5 - 0.21, FLOOR + 0.13 + i * 0.22, d + 0.006), "wood", wood.lightened(0.06))
	for z: float in [0.04, d - 0.04]:
		k.bar(Vector3(x - w * 0.5 + 0.04, FLOOR, z), Vector3(x - w * 0.5 + 0.04, FLOOR + h - 0.035, z), 0.04, 0.04, "wood", wood, false)
	chair(k, Vector3(x - 0.12, FLOOR, d - 0.12), PI, wood.darkened(0.1))
	k.plate(Vector3(0.3, 0.004, 0.22), Vector3(x - 0.15, FLOOR + h + 0.002, d * 0.5), "paint", Color(0.92, 0.9, 0.84), Vector3(0, rng.randf_range(-0.4, 0.4), 0), false)
	k.cyl(0.06, 0.07, 0.03, Vector3(x + 0.32, FLOOR + h + 0.015, 0.12), "metal_dark", Color(0.2, 0.3, 0.22), Vector3.ZERO, 8, false)
	k.rod(Vector3(x + 0.32, FLOOR + h + 0.03, 0.12), Vector3(x + 0.26, FLOOR + h + 0.36, 0.2), 0.01, "metal_dark", Color(0.2, 0.3, 0.22), 4, false)
	k.cyl(0.03, 0.09, 0.1, Vector3(x + 0.24, FLOOR + h + 0.34, 0.24), "paint", Color(0.2, 0.3, 0.22), Vector3(0.5, 0, 0), 8, false)


## A chair standing at `p` (its seat's back edge middle on the floor below),
## facing `yaw` (toward +z unturned); on its back with `fallen`. One shape,
## made once (rooms have them by the dozen).
static func chair(k: BuildingKit, p: Vector3, yaw: float, col: Color, fallen := false) -> void:
	var c := k.at_point(p + (Vector3(0, 0.02, 0) if fallen else Vector3.ZERO), Vector3(0, yaw, 0) + (Vector3(-PI * 0.5, 0, 0) if fallen else Vector3.ZERO))
	c.part(BuildingKit.shape("chair", func() -> Array:
		var pieces := [BuildingKit.piece(Vector3(0.42, 0.04, 0.4), Vector3(0, 0.44, 0.2)), BuildingKit.piece(Vector3(0.4, 0.14, 0.025), Vector3(0, 0.82, 0.01))]
		for lx: float in [-0.18, 0.18]:
			for lz: float in [0.03, 0.37]:
				pieces.append(BuildingKit.piece(Vector3(0.035, 0.42, 0.035), Vector3(lx, 0.21, lz)))
			pieces.append(BuildingKit.piece(Vector3(0.035, 0.46, 0.035), Vector3(lx, 0.69, 0.01)))
		return pieces), "wood", Transform3D.IDENTITY, col, false)


## The table in the middle of a room `size` (the floor's), its chairs drawn
## up round it, one pushed back or knocked over now and then; a cloth on
## some, a jug and plates on it.
static func table(k: BuildingKit, size: Vector3, wood: Color, rng: RandomNumberGenerator) -> void:
	var c := Vector3(rng.randf_range(-0.4, 0.4), FLOOR, rng.randf_range(-0.3, 0.3))
	var t := k.at_point(c, Vector3(0, rng.randf_range(-0.12, 0.12) + (PI * 0.5 if size.z > size.x else 0.0), 0))
	var L := 1.4
	var W := 0.85
	var h := 0.75
	t.part(BuildingKit.shape("table", func() -> Array:
		var pieces := [BuildingKit.piece(Vector3(L, 0.04, W), Vector3(0, h - 0.02, 0))]
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				pieces.append(BuildingKit.piece(Vector3(0.055, h - 0.04, 0.055), Vector3(sx * (L * 0.5 - 0.06), (h - 0.04) * 0.5, sz * (W * 0.5 - 0.06))))
		return pieces), "wood", Transform3D.IDENTITY, wood)
	if rng.randf() < 0.5:
		t.box(Vector3(L * 0.72, 0.006, W + 0.08), Vector3(0, h + 0.003, 0), "canvas", [Color(0.88, 0.86, 0.8), Color(0.62, 0.2, 0.16), Color(0.32, 0.42, 0.56)][rng.randi() % 3], Vector3.ZERO, false)
	for i in rng.randi_range(1, 3):
		t.cyl(0.11, 0.1, 0.015, Vector3(rng.randf_range(-0.5, 0.5), h + 0.012, rng.randf_range(-0.25, 0.25)), "paint", Color(0.9, 0.89, 0.85), Vector3.ZERO, 10, false)
	if rng.randf() < 0.6:
		t.cyl(0.06, 0.07, 0.2, Vector3(rng.randf_range(-0.3, 0.3), h + 0.1, rng.randf_range(-0.15, 0.15)), "paint", [Color(0.3, 0.4, 0.6), Color(0.75, 0.72, 0.65)][rng.randi() % 2], Vector3.ZERO, 8, false)
	var chair_col := wood.darkened(rng.randf_range(0.0, 0.15))
	for sx: float in [-0.35, 0.35]:
		for sz: float in [-1.0, 1.0]:
			var back := rng.randf_range(0.0, 0.25)
			var fallen := rng.randf() < 0.08
			chair(t, Vector3(sx, 0, sz * (W * 0.5 + 0.12 + back)), 0.0 if sz < 0.0 else PI, chair_col, fallen)
