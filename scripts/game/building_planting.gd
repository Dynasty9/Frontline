class_name BuildingPlanting
extends RefCounted
## What grows round a house: shrubs of the kinds gardens are planted with,
## clipped hedges, beds of flowers. Built of the trees' photographed leaves in
## each plant's own colour (Mats.leaf_cards_tinted): a skin of single leaves
## facing out over a dark core (Res.leaf_ball, Res.leaf_patch), so a bush is
## dense with no see-through gaps, a hedge's shorn faces read flat, and a
## flower is a head of petals; a few loose sprays break the outline of a
## shrub that isn't clipped. Baked with the rest of the scenery. In a kit
## standing on the ground (y = 0); for a bed or a hedge x runs along it, +z
## out from the house or the street it borders.

## The kinds of shrub (a garden's usual few), with their leaves and the
## flowers each can carry (an index into its `blooms`, or none):
## - box or yew clipped into a ball, a fresh mid green;
## - a hydrangea: a soft mound under big round heads of flowers;
## - a rose bush: dark leaves, loose, small flowers all over;
## - lavender: a low silver-green dome bristling with purple spikes;
## - a laurel: a big glossy evergreen, dark;
## - a golden privet: yellow-green, loose.
const BOX := 0
const HYDRANGEA := 1
const ROSE := 2
const LAVENDER := 3
const LAUREL := 4
const GOLDEN := 5
const KINDS := [
	{"leaf": Color(0.3, 0.47, 0.15), "blooms": []},
	{"leaf": Color(0.32, 0.5, 0.2), "blooms": [Color(0.48, 0.6, 0.95), Color(0.95, 0.55, 0.72), Color(0.95, 0.95, 0.9), Color(0.72, 0.55, 0.9)]},
	{"leaf": Color(0.24, 0.39, 0.15), "blooms": [Color(0.82, 0.08, 0.12), Color(0.97, 0.52, 0.64), Color(0.97, 0.95, 0.9), Color(0.99, 0.82, 0.3)]},
	{"leaf": Color(0.42, 0.5, 0.38), "blooms": [Color(0.55, 0.42, 0.88)]},
	{"leaf": Color(0.2, 0.36, 0.13), "blooms": []},
	{"leaf": Color(0.46, 0.56, 0.2), "blooms": []},
]
## Bedding flowers: geranium red, pink, white, marigold yellow, orange,
## purple, cornflower blue.
const BLOOMS := [Color(0.88, 0.1, 0.1), Color(0.97, 0.45, 0.65), Color(0.97, 0.96, 0.92), Color(0.99, 0.8, 0.12), Color(0.99, 0.5, 0.1), Color(0.6, 0.35, 0.85), Color(0.35, 0.5, 0.95)]
## A clipped hedge's leaves: privet, box, beech, a darker yew.
const HEDGES := [Color(0.33, 0.5, 0.17), Color(0.28, 0.45, 0.15), Color(0.4, 0.52, 0.18), Color(0.22, 0.37, 0.14)]
## A leaf-card clump reaches about this far from its middle for each unit of scale.
const REACH := 0.97


## A spray of leaves (or petals) in `col` filling the box `half` about `c`
## (the trees' cards reach that far).
static func clump(k: BuildingKit, c: Vector3, half: Vector3, col: Color, shadow := false) -> void:
	k.part_with(Res.foliage_cards(false), Mats.leaf_cards_tinted(), Transform3D(Basis.from_scale(half / REACH), c), col, shadow)


## A skin of `cards` single leaves (each `leaf` of its radius long) over the
## ellipsoid `radii` about `c` (turned by `turn`).
static func skin(k: BuildingKit, c: Vector3, radii: Vector3, col: Color, cards: int, leaf: float, turn := Basis.IDENTITY) -> void:
	k.part_with(Res.leaf_ball(cards, leaf), Mats.leaf_cards_tinted(), Transform3D(turn * Basis.from_scale(radii), c), col, false)


## A shrub `r` across of a `kind` (KINDS), with flowers (`bloom` an index
## into its blooms, or -1) if it carries them.
static func shrub(k: BuildingKit, r: float, kind: int, bloom: int, rng: RandomNumberGenerator) -> void:
	var spec: Dictionary = KINDS[posmod(kind, KINDS.size())]
	var leaf: Color = spec["leaf"]
	var blooms: Array = spec["blooms"]
	var flowers := bloom >= 0 and not blooms.is_empty()
	var flower: Color = blooms[bloom % blooms.size()] if flowers else leaf
	match posmod(kind, KINDS.size()):
		BOX:
			# shorn: small leaves close, nothing out of line
			_mound(k, r, r * rng.randf_range(0.82, 0.95), leaf, 640, 0.15, 0, rng)
		HYDRANGEA:
			var h := r * rng.randf_range(0.75, 0.88)
			_mound(k, r, h, leaf, 360, 0.2, 3, rng)
			if flowers:
				# big round heads of florets, sitting out of the leaves over its top and sides
				for i in rng.randi_range(7, 10):
					var p := _on_dome(r * 0.4, h * 0.5, h * 0.42, rng.randf() * TAU, rng.randf_range(0.25, 1.4))
					var s := r * rng.randf_range(0.12, 0.15)
					var col := flower.lightened(rng.randf_range(-0.05, 0.08))
					k.part(Res.sphere(0.5, 6), "plain", Transform3D(Basis.from_scale(Vector3.ONE * s * 1.5), p), col.darkened(0.35), false)
					skin(k, p, Vector3(s, s * 0.9, s), col, 56, 0.6)
		ROSE:
			var h := r * rng.randf_range(0.85, 0.95)
			_mound(k, r, h, leaf, 360, 0.2, 4, rng)
			if flowers:
				for i in rng.randi_range(10, 14):
					var p := _on_dome(r * 0.47, h * 0.5, h * 0.47, rng.randf() * TAU, rng.randf_range(0.0, 1.4))
					var s := r * rng.randf_range(0.05, 0.07)
					skin(k, p, Vector3(s, s * 0.8, s), flower.lightened(rng.randf_range(-0.08, 0.06)), 20, 1.0)
		LAVENDER:
			# low and wide, the flower spikes standing a hand above it
			var h := r * rng.randf_range(0.45, 0.55)
			_mound(k, r, h, leaf, 360, 0.15, 0, rng)
			if flowers:
				for i in rng.randi_range(20, 26):
					var a := rng.randf() * TAU
					var d := sqrt(rng.randf()) * r * 0.4
					var top := h * (1.0 - (d / (r * 0.5)) * (d / (r * 0.5)) * 0.45) + r * 0.06
					skin(k, Vector3(cos(a) * d, top, sin(a) * d), Vector3(r * 0.03, r * 0.1, r * 0.03), flower.lightened(rng.randf_range(-0.08, 0.08)), 16, 1.0)
		LAUREL:
			_mound(k, r, r * rng.randf_range(0.85, 0.95), leaf, 360, 0.24, 4, rng)
		GOLDEN:
			_mound(k, r, r * rng.randf_range(0.8, 0.92), leaf, 360, 0.2, 3, rng)


## A mound of leaves `r` across and `h` high: a dark core (casting the
## shrub's shadow) under a skin of `cards` leaves (`size` of its radius
## long); one that isn't clipped (`sprays` above 0) grows lumpy, with lobes
## of leaves out of its sides and sprays out of its shoulders.
static func _mound(k: BuildingKit, r: float, h: float, leaf: Color, cards: int, size: float, sprays: int, rng: RandomNumberGenerator) -> void:
	k.part(Res.sphere(0.5, 8), "plain", Transform3D(Basis.from_scale(Vector3(r * 0.74, h * 0.84, r * 0.74)), Vector3(0, h * 0.44, 0)), leaf.darkened(0.3), true)
	if sprays == 0:
		skin(k, Vector3(0, h * 0.48, 0), Vector3(r * 0.45, h * 0.48, r * 0.45), leaf, cards, size)
		return
	skin(k, Vector3(0, h * 0.45, 0), Vector3(r * 0.41, h * 0.45, r * 0.41), leaf.darkened(0.04), cards, size)
	var lobes := rng.randi_range(3, 4)
	var turn := rng.randf() * TAU
	for i in lobes:
		var a := turn + i * TAU / lobes + rng.randf_range(-0.4, 0.4)
		var lift := rng.randf_range(0.42, 0.62)
		skin(k, Vector3(cos(a) * r * 0.2, h * lift, sin(a) * r * 0.2), Vector3(r * 0.25, h * 0.3, r * 0.25), leaf.lightened(rng.randf_range(-0.02, 0.05)), cards * 2 / 5, size * 1.15)
	var s := r * 0.17
	for i in sprays:
		var a := i * TAU / sprays + rng.randf_range(-0.5, 0.5)
		var p := _on_dome(r * 0.34, h * 0.5, h * 0.36, a, rng.randf_range(0.1, 0.9))
		clump(k, p, Vector3(s, s * 0.85, s), leaf.lightened(rng.randf_range(0.0, 0.06)))


## A point on a dome `rw` across and `rh` high about its middle `cy`, at the
## bearing `a` and `up` radians above the horizontal.
static func _on_dome(rw: float, cy: float, rh: float, a: float, up: float) -> Vector3:
	return Vector3(cos(a) * cos(up) * rw, cy + sin(up) * rh, sin(a) * cos(up) * rw)


## A clipped hedge `length` long, `h` high and `depth` thick, centred on x:
## a dark core (casting its shadow), its faces, ends and top shorn flat in
## leaves, the faces leaning in a little (a hedge is cut narrower at the top
## so its foot gets the light), the top a shade lighter with new growth. A
## long hedge between gardens (`fine` false) is leaved a little coarser, for
## the number of them.
static func hedge(k: BuildingKit, length: float, h: float, depth: float, col: Color, rng: RandomNumberGenerator, fine := true) -> void:
	var lean := 0.06
	k.box(Vector3(length - 0.16, h - 0.1, depth - 0.16 - 2.0 * h * lean), Vector3(0, (h - 0.1) * 0.5, 0), "plain", col.darkened(0.3), Vector3.ZERO, true)
	var n := maxi(1, int(round(length / 0.55)))
	var seg := length / n
	var rows := maxi(1, int(round(h / 0.45)))
	var row := h / rows
	var patch := Res.leaf_patch(130, 0.13) if fine else Res.leaf_patch(60, 0.19)
	var mat := Mats.leaf_cards_tinted()
	for side: float in [-1.0, 1.0]:
		var face := Basis(Vector3.UP, 0.0 if side > 0.0 else PI) * Basis(Vector3.RIGHT, -lean)
		for i in n:
			var x := -length * 0.5 + (i + 0.5) * seg
			for j in rows:
				var y := (j + 0.5) * row
				var z := side * (depth * 0.5 - 0.03 - y * lean)
				k.part_with(patch, mat, Transform3D(face * Basis.from_scale(Vector3(seg * 1.1, row * 1.15, 1.0)), Vector3(x, y, z)), col.lightened(rng.randf_range(-0.02, 0.02)), false)
	for e: float in [-1.0, 1.0]:
		for j in rows:
			var y := (j + 0.5) * row
			k.part_with(patch, mat, Transform3D(Basis(Vector3.UP, e * PI * 0.5) * Basis.from_scale(Vector3(depth - 2.0 * y * lean, row * 1.15, 1.0)), Vector3(e * (length * 0.5 - 0.03), y, 0)), col.darkened(0.04), false)
	var top := Basis(Vector3.RIGHT, -PI * 0.5)
	for i in n:
		var x := -length * 0.5 + (i + 0.5) * seg
		k.part_with(patch, mat, Transform3D(top * Basis.from_scale(Vector3(seg * 1.1, depth - 2.0 * h * lean, 1.0)), Vector3(x, h - 0.02, 0)), col.lightened(0.12), false)


## A bed of flowers `length` along a wall (or a hedge) and `depth` out from it
## (+z): dark turned earth edged with a row of bricks on end, planted in rows
## as a gardener does, the tall at the back (spires of flowers on a leafy
## foot), cushions of flowers in the middle, a low edging in front, in two
## or three colours and white.
static func bed(k: BuildingKit, length: float, depth: float, rng: RandomNumberGenerator) -> void:
	k.plate(Vector3(length, 0.03, depth), Vector3(0, 0.015, depth * 0.5), "earth", Color(0.32, 0.24, 0.17), Vector3.ZERO, false)
	k.box(Vector3(length, 0.07, 0.06), Vector3(0, 0.035, depth - 0.03), "brick", Color(0.55, 0.3, 0.22), Vector3.ZERO, false)
	var cols: Array = []
	for i in rng.randi_range(2, 3):
		cols.append(BLOOMS[rng.randi() % BLOOMS.size()])
	var green := Color(0.3, 0.47, 0.17)
	# the back row: spires (delphiniums, foxgloves, hollyhocks) where there's depth for them
	if depth > 0.5:
		var n := maxi(2, int(length / 0.4))
		var spire: Color = cols[rng.randi() % cols.size()]
		for i in n:
			var x := -length * 0.5 + (i + 0.5) * length / n + rng.randf_range(-0.05, 0.05)
			var z := depth * 0.2
			var h := rng.randf_range(0.42, 0.6)
			skin(k, Vector3(x, 0.12, z), Vector3(0.13, 0.12, 0.1), green.darkened(0.08), 40, 0.7)
			skin(k, Vector3(x, h * 0.6, z), Vector3(0.045, h * 0.38, 0.045), spire.lightened(rng.randf_range(-0.08, 0.08)), 36, 0.9)
	# the middle: cushions of flowers on their leaves
	var mz := depth * (0.52 if depth > 0.5 else 0.4)
	var m := maxi(2, int(length / 0.34))
	for i in m:
		var x := -length * 0.5 + (i + 0.5) * length / m + rng.randf_range(-0.04, 0.04)
		var s := rng.randf_range(0.14, 0.18)
		var z := mz + rng.randf_range(-0.03, 0.03)
		skin(k, Vector3(x, s * 0.7, z), Vector3(s, s * 0.7, s * 0.85), green.lightened(rng.randf_range(-0.04, 0.06)), 40, 0.6)
		var c: Color = cols[i % cols.size()]
		skin(k, Vector3(x, s * 1.2, z), Vector3(s * 0.85, s * 0.4, s * 0.75), c.lightened(rng.randf_range(-0.06, 0.08)), 44, 0.5)
	# the front: a low edging of small flowers (white alyssum, or the bed's last colour)
	var edge: Color = BLOOMS[2] if rng.randf() < 0.6 else cols[cols.size() - 1]
	var e := maxi(2, int(length / 0.24))
	for i in e:
		var x := -length * 0.5 + (i + 0.5) * length / e
		skin(k, Vector3(x, 0.06, depth - 0.14), Vector3(0.11, 0.06, 0.07), edge.lightened(rng.randf_range(-0.05, 0.05)), 20, 0.8)


## A vegetable plot `length` by `depth` at the bottom of a garden (x along
## it): turned earth inside a board edging, and across it rows of what a
## household grows, a crop to a row: cabbages, lettuces, potatoes earthed up
## in ridges, a feathery row of carrots, and runner beans up a row of crossed
## canes, in flower.
static func veg_patch(k: BuildingKit, length: float, depth: float, rng: RandomNumberGenerator) -> void:
	k.plate(Vector3(length, 0.04, depth), Vector3(0, 0.02, 0), "earth", Color(0.3, 0.22, 0.15), Vector3.ZERO, false)
	for side: float in [-1.0, 1.0]:
		k.box(Vector3(length + 0.06, 0.12, 0.03), Vector3(0, 0.06, side * (depth * 0.5 + 0.015)), "wood", Color(0.42, 0.33, 0.22), Vector3.ZERO, false)
		k.box(Vector3(0.03, 0.12, depth), Vector3(side * (length * 0.5 + 0.015), 0.06, 0), "wood", Color(0.42, 0.33, 0.22), Vector3.ZERO, false)
	var rows := maxi(1, int(depth / 0.65))
	var gap := depth / rows
	# (the low crops in turn, and the beans, being tall, along the far edge)
	var low := [0, 1, 2, 3]
	var first := rng.randi() % low.size()
	var beans := rows >= 3 and rng.randf() < 0.7
	for r in rows:
		var z := -depth * 0.5 + (r + 0.5) * gap
		match 4 if beans and r == rows - 1 else low[(first + r) % low.size()]:
			0:
				# cabbages: tight blue-green heads in a ruff of outer leaves
				var n := maxi(1, int(length / 0.45))
				for i in n:
					var x := -length * 0.5 + (i + 0.5) * length / n
					var s := rng.randf_range(0.13, 0.16)
					skin(k, Vector3(x, 0.07, z), Vector3(s * 1.7, 0.06, s * 1.7), Color(0.36, 0.5, 0.38), 24, 0.8)
					skin(k, Vector3(x, s, z), Vector3(s, s * 0.9, s), Color(0.5, 0.62, 0.5).lightened(rng.randf_range(-0.04, 0.04)), 40, 0.6)
			1:
				# lettuces: bright rosettes
				var n := maxi(1, int(length / 0.32))
				for i in n:
					var x := -length * 0.5 + (i + 0.5) * length / n
					skin(k, Vector3(x, 0.08, z), Vector3(0.12, 0.08, 0.12), Color(0.55, 0.72, 0.28).lightened(rng.randf_range(-0.05, 0.05)), 28, 0.7)
			2:
				# potatoes: an earthed-up ridge, leafy tops along it
				k.part(Res.cyl(0.5, 0.5, 1.0, 6), "earth", Transform3D(Basis(Vector3.FORWARD, PI * 0.5) * Basis.from_scale(Vector3(0.2, length - 0.1, 0.32)), Vector3(0, 0.03, z)), Color(0.33, 0.25, 0.17), false)
				var n := maxi(1, int(length / 0.42))
				for i in n:
					var x := -length * 0.5 + (i + 0.5) * length / n
					skin(k, Vector3(x, 0.24, z), Vector3(0.19, 0.13, 0.17), Color(0.3, 0.46, 0.18).lightened(rng.randf_range(-0.04, 0.05)), 36, 0.6)
			3:
				# carrots: a low feathery row
				var n := maxi(1, int(length / 0.3))
				for i in n:
					var x := -length * 0.5 + (i + 0.5) * length / n
					skin(k, Vector3(x, 0.1, z), Vector3(0.14, 0.1, 0.07), Color(0.38, 0.6, 0.22), 18, 0.9)
			4:
				# runner beans: crossed canes, the vines up them, scarlet flowers
				var n := maxi(1, int(length / 0.5))
				var top := 1.75
				k.bar(Vector3(-length * 0.5 + 0.1, top - 0.08, z), Vector3(length * 0.5 - 0.1, top - 0.08, z), 0.02, 0.02, "wood", Color(0.62, 0.52, 0.34), false)
				for i in n:
					var x := -length * 0.5 + (i + 0.5) * length / n
					for side: float in [-1.0, 1.0]:
						var foot := Vector3(x, 0.0, z + side * 0.28)
						var head := Vector3(x, top, z - side * 0.06)
						k.bar(foot, head, 0.018, 0.018, "wood", Color(0.62, 0.52, 0.34), false)
						# the vine up the cane, thinning and stopping short of its top
						var climb := rng.randf_range(0.65, 0.92)
						var mid := foot.lerp(head, climb * 0.5)
						var lean := Basis(Vector3.RIGHT, -side * atan2(0.34, top))
						skin(k, mid, Vector3(0.12, top * climb * 0.5, 0.12), Color(0.25, 0.42, 0.16).lightened(rng.randf_range(-0.03, 0.05)), 56, 0.45, lean)
						if rng.randf() < 0.8:
							skin(k, foot.lerp(head, rng.randf_range(0.35, climb)) + Vector3(0, 0, side * 0.04), Vector3(0.03, 0.03, 0.03), Color(0.9, 0.16, 0.1), 8, 1.0)
