class_name BuildingWeathering
extends RefCounted
## What time and the war leave on buildings: ivy climbing an old wall, weeds
## in the angle between a wall and the ground, and in a house that has burned
## and fallen in, its roof on the floor: charred rafters, broken tiles, lumps
## of plaster and brick, soot, glass. Work in a face kit (see BuildingWalls)
## or, for a floor, a kit at its middle.
##
## As with furnishings, nothing may stand where a man does (Cover's fighting
## positions are half a metre off every wall): ivy and weeds keep within a
## hand's breadth of the wall, and the debris of a ruin lies flat on the floor,
## no higher than a man's ankle. Everything is a world-space surface or leaf
## cards, so batched scenery stays batched.

const IVY := [Color(0.16, 0.27, 0.11), Color(0.2, 0.3, 0.12), Color(0.13, 0.22, 0.1)]
const WEEDS := [Color(0.34, 0.42, 0.16), Color(0.42, 0.44, 0.2), Color(0.3, 0.38, 0.17)]
const CHAR := Color(0.09, 0.085, 0.08)


static func _leaves(k: BuildingKit, c: Vector3, half: Vector3, col: Color) -> void:
	k.part_with(Res.foliage_cards(false), Mats.leaf_cards(false), Transform3D(Basis.from_scale(half), c), col, false)


## Ivy up a face from its foot at `x`, `width` across at the bottom and no
## higher than `height`: clumps narrowing and wandering as it climbs.
static func ivy(k: BuildingKit, x: float, width: float, height: float, rng: RandomNumberGenerator) -> void:
	var y := 0.0
	var w := width
	var col: Color = IVY[rng.randi() % IVY.size()]
	while y < height - 0.3 and w > 0.3:
		var h := minf(rng.randf_range(0.55, 0.85), height - y)
		_leaves(k, Vector3(x, y + h * 0.5, 0.07), Vector3(w * 0.5, h * 0.5, 0.07), col.lightened(rng.randf_range(0.0, 0.08)))
		y += h * 0.7
		w *= rng.randf_range(0.62, 0.86)
		x += rng.randf_range(-0.22, 0.22)


## Weeds along the foot of a face `length` long, in tufts, stopping at the
## openings in `gaps` (no weeds across a doorstep).
static func weeds(k: BuildingKit, length: float, gaps: Array, rng: RandomNumberGenerator, z := 0.1) -> void:
	for run: Vector2 in BuildingWalls.runs(-length * 0.5, length * 0.5, 0.0, 0.3, gaps):
		var n := int((run.y - run.x) / 0.55)
		for i in n:
			if rng.randf() < 0.45:
				continue
			var x := lerpf(run.x, run.y, (i + rng.randf_range(0.2, 0.8)) / n)
			var h := rng.randf_range(0.08, 0.2)
			_leaves(k, Vector3(x, h * 0.6, z), Vector3(rng.randf_range(0.14, 0.3), h, 0.09), WEEDS[rng.randi() % WEEDS.size()])


## The floor of a house that burned and fell in, `size` its footprint, its
## top at `top`: soot where the fire was, rafters lying charred across it,
## broken tiles, lumps of plaster and brick, glass.
static func ruin(k: BuildingKit, size: Vector3, top: float, rng: RandomNumberGenerator) -> void:
	var hx := size.x * 0.5 - 0.6
	var hz := size.z * 0.5 - 0.6
	for i in rng.randi_range(2, 3):
		var s := Vector2(rng.randf_range(1.5, 3.0), rng.randf_range(1.2, 2.4))
		k.plate(Vector3(s.x, 0.004, s.y), Vector3(rng.randf_range(-hx, hx) * 0.6, top + 0.002 + i * 0.001, rng.randf_range(-hz, hz) * 0.6), "burnt", CHAR.lightened(0.05 * i), Vector3(0, rng.randf() * TAU, 0))
	for i in rng.randi_range(2, 4):
		var ln := rng.randf_range(1.8, minf(3.6, size.x))
		k.box(Vector3(0.12, 0.13, ln), Vector3(rng.randf_range(-hx, hx) * 0.7, top + 0.065 + i * 0.002, rng.randf_range(-hz, hz) * 0.7), "burnt", CHAR, Vector3(rng.randf_range(-0.02, 0.02), rng.randf() * TAU, 0))
	for i in rng.randi_range(14, 22):
		k.plate(Vector3(rng.randf_range(0.12, 0.28), 0.016, rng.randf_range(0.1, 0.2)), Vector3(rng.randf_range(-hx, hx), top + 0.01, rng.randf_range(-hz, hz)),
			"paint", Color(0.5, 0.24, 0.16).darkened(rng.randf_range(0.0, 0.4)), Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12)))
	for i in rng.randi_range(8, 14):
		var s := rng.randf_range(0.06, 0.14)
		k.box(Vector3(s * 1.4, s, s), Vector3(rng.randf_range(-hx, hx), top + s * 0.45, rng.randf_range(-hz, hz)),
			"rubble" if i % 3 != 0 else "brick", Color(0.6, 0.57, 0.52).darkened(rng.randf_range(0.0, 0.3)), Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, 0))
	for i in rng.randi_range(4, 8):
		k.plate(Vector3(rng.randf_range(0.04, 0.1), 0.004, rng.randf_range(0.03, 0.08)), Vector3(rng.randf_range(-hx, hx), top + 0.006, rng.randf_range(-hz, hz)), "glass", BuildingOpenings.GLASS, Vector3(0, rng.randf() * TAU, 0))
