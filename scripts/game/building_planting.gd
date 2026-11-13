class_name BuildingPlanting
extends RefCounted
## What grows round a house: shrubs, clipped hedges, beds of flowers. Built of
## the trees' photographed leaf cards round a dark core (so a bush has no
## see-through gaps), and baked with the rest of the scenery. In a kit standing
## on the ground (y = 0); for a bed or a hedge x runs along it, +z out from
## the house or the street it borders.

const GREENS := [Color(0.31, 0.45, 0.17), Color(0.36, 0.48, 0.19), Color(0.27, 0.41, 0.2), Color(0.4, 0.47, 0.19), Color(0.3, 0.39, 0.23)]
## Flowers: rose pink, lilac, white, yellow, red, orange.
const BLOOMS := [Color(0.86, 0.32, 0.48), Color(0.58, 0.46, 0.86), Color(0.93, 0.91, 0.84), Color(0.92, 0.75, 0.18), Color(0.8, 0.14, 0.14), Color(0.92, 0.48, 0.14)]
## A leaf-card clump reaches about this far from its middle for each unit of scale.
const REACH := 0.97


## A clump of leaves filling the box `half` about `c` (its cards reach that far).
static func clump(k: BuildingKit, c: Vector3, half: Vector3, col: Color, shadow := true) -> void:
	k.part_with(Res.foliage_cards(false), Mats.leaf_cards(false), Transform3D(Basis.from_scale(half / REACH), c), col, shadow)


## A shrub `r` across: a dark core under a mound of leafy clumps, a little
## uneven, and on a flowering one (`bloom` a colour, or null) heads of flowers
## over its top and sides.
static func shrub(k: BuildingKit, r: float, col: Color, bloom: Variant, rng: RandomNumberGenerator) -> void:
	var h := r * rng.randf_range(0.75, 1.1)
	k.part(Res.sphere(0.5, 8), "plain", Transform3D(Basis.from_scale(Vector3(r * 0.7, h * 0.65, r * 0.7)), Vector3(0, h * 0.4, 0)), col.darkened(0.25), false)
	clump(k, Vector3(0, h * 0.5, 0), Vector3(r * 0.5, h * 0.5, r * 0.5), col)
	for i in rng.randi_range(4, 6):
		var a := rng.randf() * TAU
		var s := r * rng.randf_range(0.22, 0.34)
		clump(k, Vector3(cos(a) * r * 0.3, h * rng.randf_range(0.35, 0.7), sin(a) * r * 0.3), Vector3(s, s * 0.9, s), col.lightened(rng.randf_range(-0.04, 0.1)), false)
	if bloom == null:
		return
	var b: Color = bloom
	for i in rng.randi_range(6, 11):
		var a := rng.randf() * TAU
		var up := rng.randf_range(0.25, 1.3)
		var p := Vector3(cos(a) * cos(up) * r * 0.48, h * 0.5 + sin(up) * h * 0.48, sin(a) * cos(up) * r * 0.48)
		var s := rng.randf_range(0.06, 0.1)
		clump(k, p, Vector3(s, s, s), b.lightened(rng.randf_range(-0.08, 0.12)), false)


## A clipped hedge `length` long, `h` high and `depth` thick, centred on x:
## a dark core with leaves over it, squared off by the shears, its top level.
static func hedge(k: BuildingKit, length: float, h: float, depth: float, col: Color, rng: RandomNumberGenerator) -> void:
	k.box(Vector3(length - 0.16, h - 0.16, depth - 0.2), Vector3(0, (h - 0.16) * 0.5, 0), "plain", col.darkened(0.25), Vector3.ZERO, false)
	var n := maxi(1, int(round(length / 0.42)))
	var seg := length / n
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * seg
		for side: float in [-1.0, 1.0]:
			clump(k, Vector3(x, h * 0.5, side * depth * 0.18), Vector3(seg * 0.7, h * 0.52, depth * 0.36), col.lightened(rng.randf_range(-0.03, 0.08)), side < 0.0)
	# the clipped top, a shade lighter where the new growth is
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * seg
		clump(k, Vector3(x + rng.randf_range(-0.1, 0.1), h - 0.06, 0), Vector3(seg * 0.55, 0.08, depth * 0.5), col.lightened(0.1), false)


## A bed of flowers `length` along a wall (or a hedge) and `depth` out from it
## (+z): turned earth edged with a row of bricks on end, plants in clumps
## along it, flowers over them in two or three colours.
static func bed(k: BuildingKit, length: float, depth: float, rng: RandomNumberGenerator) -> void:
	k.plate(Vector3(length, 0.03, depth), Vector3(0, 0.015, depth * 0.5), "earth", Color(0.3, 0.22, 0.15), Vector3.ZERO, false)
	k.box(Vector3(length, 0.07, 0.06), Vector3(0, 0.035, depth - 0.03), "brick", Color(0.55, 0.3, 0.22), Vector3.ZERO, false)
	var cols: Array = []
	for i in rng.randi_range(2, 3):
		cols.append(BLOOMS[rng.randi() % BLOOMS.size()])
	var n := maxi(2, int(length / 0.38))
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * length / n + rng.randf_range(-0.08, 0.08)
		var z := depth * rng.randf_range(0.3, 0.65)
		var s := rng.randf_range(0.14, 0.22)
		clump(k, Vector3(x, s * 0.8, z), Vector3(s, s * 0.8, s), GREENS[rng.randi() % GREENS.size()].lightened(0.05), false)
		if rng.randf() < 0.8:
			var c: Color = cols[i % cols.size()]
			for j in 2:
				var f := rng.randf_range(0.05, 0.08)
				clump(k, Vector3(x + rng.randf_range(-0.1, 0.1), s * 1.45 + f * 0.4, z + rng.randf_range(-0.08, 0.08)), Vector3(f, f * 0.8, f), c.lightened(rng.randf_range(-0.06, 0.1)), false)
