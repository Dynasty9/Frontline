class_name BuildingYards
extends RefCounted
## What people keep round a house: wheelie bins at a front corner, a woodpile
## against the back wall, a table and chairs out the back (a parasol over some),
## a dog's kennel, a bicycle leaning on the wall, pots of flowers by the door.
## Decor builds them (they're set dressing: no cover, and a blast or a truck
## knocks them over) in a kit at the piece's own origin, standing on y = 0,
## facing +z.

const BIN_COLS := [Color(0.16, 0.3, 0.18), Color(0.26, 0.28, 0.3), Color(0.15, 0.24, 0.42), Color(0.12, 0.12, 0.12)]
const BIKE_COLS := [Color(0.62, 0.12, 0.1), Color(0.16, 0.28, 0.5), Color(0.15, 0.15, 0.15), Color(0.24, 0.42, 0.26), Color(0.75, 0.72, 0.66)]
const PARASOLS := [Color(0.78, 0.22, 0.16), Color(0.86, 0.82, 0.7), Color(0.22, 0.4, 0.55), Color(0.36, 0.5, 0.3)]
const TERRACOTTA := Color(0.62, 0.32, 0.2)


## A wheelie bin or two side by side, lids shut, handles to the back.
static func bins(k: BuildingKit, count: int, col: Color) -> void:
	for i in count:
		var b := k.at_point(Vector3((float(i) - (count - 1) * 0.5) * 0.66, 0, 0))
		b.part(BuildingKit.shape("wheelie_bin", func() -> Array:
			return [
				BuildingKit.piece(Vector3(0.56, 0.84, 0.66), Vector3(0, 0.5, 0), Vector3.ZERO, true),
				BuildingKit.piece(Vector3(0.52, 0.06, 0.6), Vector3(0, 0.07, 0.02)),
				BuildingKit.piece(Vector3(0.48, 0.05, 0.08), Vector3(0, 0.88, -0.36)),
			]), "plain", Transform3D.IDENTITY, col)
		b.plate(Vector3(0.6, 0.04, 0.72), Vector3(0, 0.94, 0.02), "plain", col.darkened(0.15), Vector3(0.04, 0, 0), true)
		for sx: float in [-1.0, 1.0]:
			b.cyl(0.1, 0.1, 0.05, Vector3(sx * 0.3, 0.1, -0.32), "rubber", null, Vector3(0, 0, PI * 0.5), 8, false)


## A woodpile `length` long against a wall (its back to -z): split logs stacked
## between two posts, their sawn ends out, a chopping block in front.
static func woodpile(k: BuildingKit, length: float, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(0.7, 1.05)
	k.box(Vector3(length, h, 0.4), Vector3(0, h * 0.5, 0), "bark", Color(0.34, 0.26, 0.18))
	k.part(BuildingKit.shape("log_ends|%.1f|%.1f" % [length, h], func() -> Array:
		var out: Array = []
		var rows := int(h / 0.17)
		for r in rows:
			var per := int(length / 0.17)
			for c in per:
				var x := -length * 0.5 + (c + 0.5 + (0.5 if r % 2 == 1 else 0.0)) * length / (per + 0.5)
				out.append([Res.cyl(0.075, 0.075, 0.02, 5), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 0.09 + r * 0.17, 0.205))])
		return out), "wood", Transform3D.IDENTITY, Color(0.66, 0.52, 0.34))
	for sx: float in [-1.0, 1.0]:
		k.bar(Vector3(sx * (length * 0.5 + 0.04), 0, 0), Vector3(sx * (length * 0.5 + 0.04), h + 0.1, 0), 0.06, 0.06, "wood_dark", Color(0.3, 0.24, 0.17))
	var block := Vector3(rng.randf_range(-length * 0.3, length * 0.3), 0, 0.75)
	k.cyl(0.21, 0.23, 0.42, block + Vector3(0, 0.21, 0), "bark", Color(0.32, 0.25, 0.18), Vector3.ZERO, 8)
	k.cyl(0.2, 0.2, 0.01, block + Vector3(0, 0.425, 0), "wood", Color(0.62, 0.5, 0.34), Vector3.ZERO, 8, false)
	# the axe left standing in it
	k.bar(block + Vector3(0.02, 0.42, 0), block + Vector3(0.28, 0.78, 0.05), 0.035, 0.035, "wood", Color(0.55, 0.42, 0.28), false)
	k.plate(Vector3(0.12, 0.09, 0.02), block + Vector3(0.02, 0.45, 0), "metal_dark", Color(0.25, 0.25, 0.24), Vector3(0, 0, 0.9))


## A table and chairs set out on the grass, now and then under a parasol.
static func garden_set(k: BuildingKit, rng: RandomNumberGenerator, parasol: bool) -> void:
	var white := Color(0.88, 0.87, 0.84) if rng.randf() < 0.6 else Color(0.48, 0.36, 0.24)
	var kind := "plain" if white.r > 0.6 else "wood"
	k.cyl(0.46, 0.46, 0.03, Vector3(0, 0.72, 0), kind, white, Vector3.ZERO, 12)
	k.cyl(0.03, 0.03, 0.7, Vector3(0, 0.35, 0), "metal_dark", Color(0.3, 0.3, 0.3), Vector3.ZERO, 6, false)
	k.cyl(0.25, 0.27, 0.03, Vector3(0, 0.015, 0), kind, white, Vector3.ZERO, 10, false)
	var n := rng.randi_range(2, 4)
	var a0 := rng.randf() * TAU
	for i in n:
		var a := a0 + TAU * i / n + rng.randf_range(-0.2, 0.2)
		chair(k.at_point(Vector3(sin(a), 0, cos(a)) * 0.78, Vector3(0, a + PI + rng.randf_range(-0.3, 0.3), 0)), white, kind)
	if parasol:
		var pc: Color = PARASOLS[rng.randi() % PARASOLS.size()]
		k.cyl(0.02, 0.02, 2.2, Vector3(0, 1.1, 0), "metal_dark", Color(0.75, 0.75, 0.73), Vector3.ZERO, 6, false)
		k.cyl(0.0, 1.15, 0.38, Vector3(0, 2.1, 0), "canvas", pc, Vector3.ZERO, 10)
		k.cyl(1.16, 1.16, 0.1, Vector3(0, 1.9, 0), "canvas", pc.darkened(0.1), Vector3.ZERO, 10, false)


## A garden chair in its own kit (facing +z, the table behind it at -z... its back to +z).
static func chair(k: BuildingKit, col: Color, kind: String) -> void:
	k.part(BuildingKit.shape("garden_chair", func() -> Array:
		var out: Array = [BuildingKit.piece(Vector3(0.44, 0.03, 0.42), Vector3(0, 0.44, 0)), BuildingKit.piece(Vector3(0.44, 0.42, 0.03), Vector3(0, 0.66, 0.21), Vector3(-0.12, 0, 0))]
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				out.append(BuildingKit.piece(Vector3(0.03, 0.44, 0.03), Vector3(sx * 0.19, 0.22, sz * 0.18)))
		return out), kind, Transform3D.IDENTITY, col)


## A dog's kennel: a box on a raised floor under a felted gable, its doorway
## dark, a bowl by it.
static func kennel(k: BuildingKit, col: Color) -> void:
	k.box(Vector3(0.72, 0.5, 0.92), Vector3(0, 0.3, 0), "wood_painted", col)
	k.prism(Vector3(0.84, 0.28, 1.0), Vector3(0, 0.69, 0), "plain_dark", Color(0.18, 0.18, 0.17))
	k.prism(Vector3(0.72, 0.26, 0.9), Vector3(0, 0.68, 0), "wood_painted", col)
	k.plate(Vector3(0.32, 0.38, 0.01), Vector3(0, 0.27, 0.461), "plain_dark", Color(0.03, 0.03, 0.03))
	k.cyl(0.11, 0.08, 0.06, Vector3(0.28, 0.03, 0.72), "metal_dark", Color(0.6, 0.6, 0.62), Vector3.ZERO, 8, false)


## A bicycle leaning on a wall behind it (-z), its wheels, frame, bars and
## saddle.
static func bicycle(k: BuildingKit, col: Color) -> void:
	var b := k.at_point(Vector3(0, 0, 0.18), Vector3(0.22, PI * 0.5, 0))
	for sx: float in [-0.52, 0.52]:
		b.part(BuildingKit.ring(0.3, 0.33), "rubber", Mats.place(Vector3(sx, 0.33, 0), Vector3(PI * 0.5, 0, 0)), null, false)
		b.cyl(0.04, 0.04, 0.05, Vector3(sx, 0.33, 0), "metal_dark", Color(0.5, 0.5, 0.5), Vector3(PI * 0.5, 0, 0), 6, false)
	var crank := Vector3(-0.02, 0.3, 0)
	var seat := Vector3(-0.18, 0.78, 0)
	var head := Vector3(0.36, 0.82, 0)
	for pair: Array in [[Vector3(-0.52, 0.33, 0), crank], [crank, seat], [seat, head], [crank, head + Vector3(-0.03, -0.1, 0)],
			[Vector3(-0.52, 0.33, 0), seat], [head, Vector3(0.52, 0.33, 0)]]:
		b.bar(pair[0], pair[1], 0.028, 0.028, "car_paint", col, false)
	b.plate(Vector3(0.22, 0.04, 0.09), seat + Vector3(-0.02, 0.06, 0), "plain_dark", Color(0.1, 0.1, 0.1))
	b.bar(head + Vector3(0, 0.08, -0.24), head + Vector3(0, 0.08, 0.24), 0.025, 0.025, "metal_dark", Color(0.55, 0.55, 0.55), false)


## Pots of flowers in a row by a door.
static func pots(k: BuildingKit, count: int, rng: RandomNumberGenerator) -> void:
	for i in count:
		var p := Vector3((float(i) - (count - 1) * 0.5) * 0.42, 0, rng.randf_range(-0.06, 0.06))
		var r := rng.randf_range(0.12, 0.2)
		k.cyl(r, r * 0.75, r * 1.5, p + Vector3(0, r * 0.75, 0), "paint", TERRACOTTA.darkened(rng.randf_range(0.0, 0.2)), Vector3.ZERO, 8)
		k.part_with(Res.foliage_cards(false), Mats.leaf_cards(false), Transform3D(Basis.from_scale(Vector3(r * 1.3, r * 1.4, r * 1.3)), p + Vector3(0, r * 2.1, 0)),
			[Color(0.75, 0.15, 0.15), Color(0.86, 0.5, 0.65), Color(0.3, 0.45, 0.2), Color(0.9, 0.78, 0.25)][rng.randi() % 4], false)
