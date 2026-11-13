class_name BuildingShops
extends RefCounted
## A shop's front: the fascia board over its windows with the shop's name
## across it in raised letters, a striped canvas awning on its arms, and what
## each kind of shop puts out on the pavement (wares): a greengrocer's crates
## of fruit and vegetables on a stand, a cafe's tables and chairs, a baker's
## board and tubs of flowers, a hardware shop's sacks, gas bottles and
## buckets, a newsagent's board and paper rack. Decor builds them (set
## dressing: the wares are knocked over by a blast or a truck) in a kit at the
## middle of the shop's street wall at its foot, the street toward -z and the
## wall's face at z = FACE.

const KINDS := ["grocer", "cafe", "baker", "hardware", "news"]
const FACE := -0.2
const FASCIA := [Color(0.13, 0.3, 0.18), Color(0.1, 0.12, 0.18), Color(0.42, 0.14, 0.1), Color(0.18, 0.18, 0.2), Color(0.1, 0.22, 0.4)]
const LETTERS := [Color(0.92, 0.86, 0.6), Color(0.9, 0.88, 0.82), Color(0.95, 0.9, 0.78), Color(0.95, 0.75, 0.2), Color(0.95, 0.95, 0.92)]
const STRIPES := [[Color(0.22, 0.46, 0.26), Color(0.9, 0.88, 0.8)], [Color(0.12, 0.18, 0.34), Color(0.88, 0.86, 0.8)],
	[Color(0.6, 0.16, 0.12), Color(0.92, 0.88, 0.78)], [Color(0.3, 0.3, 0.32), Color(0.86, 0.7, 0.2)], [Color(0.14, 0.32, 0.55), Color(0.9, 0.9, 0.86)]]
## Letter shapes in strokes over a unit glyph (x0, y0, x1, y1), close enough
## at a street's distance: I L E H O U T A C F.
const GLYPHS := [
	[[0.35, 0.0, 0.65, 1.0]],
	[[0.0, 0.0, 0.3, 1.0], [0.0, 0.0, 1.0, 0.2]],
	[[0.0, 0.0, 0.3, 1.0], [0.0, 0.0, 1.0, 0.2], [0.0, 0.41, 0.8, 0.59], [0.0, 0.8, 1.0, 1.0]],
	[[0.0, 0.0, 0.3, 1.0], [0.7, 0.0, 1.0, 1.0], [0.0, 0.41, 1.0, 0.59]],
	[[0.0, 0.0, 0.3, 1.0], [0.7, 0.0, 1.0, 1.0], [0.0, 0.0, 1.0, 0.2], [0.0, 0.8, 1.0, 1.0]],
	[[0.0, 0.0, 0.3, 1.0], [0.7, 0.0, 1.0, 1.0], [0.0, 0.0, 1.0, 0.2]],
	[[0.35, 0.0, 0.65, 1.0], [0.0, 0.8, 1.0, 1.0]],
	[[0.0, 0.0, 0.3, 1.0], [0.7, 0.0, 1.0, 1.0], [0.0, 0.8, 1.0, 1.0], [0.0, 0.41, 1.0, 0.59]],
	[[0.0, 0.0, 0.3, 1.0], [0.0, 0.0, 1.0, 0.2], [0.0, 0.8, 1.0, 1.0]],
	[[0.0, 0.0, 0.3, 1.0], [0.0, 0.41, 0.8, 0.59], [0.0, 0.8, 1.0, 1.0]],
]
const PRODUCE := [Color(0.72, 0.1, 0.08), Color(0.9, 0.5, 0.08), Color(0.35, 0.55, 0.15), Color(0.92, 0.8, 0.2), Color(0.38, 0.12, 0.3), Color(0.55, 0.38, 0.2)]


## The fascia and awning across a front `width` wide, for a shop of `kind`
## (an index into KINDS).
static func front(k: BuildingKit, width: float, kind: int, rng: RandomNumberGenerator) -> void:
	var col: Color = FASCIA[kind % FASCIA.size()]
	k.box(Vector3(width, 0.48, 0.07), Vector3(0, 2.62, FACE - 0.035), "paint", col)
	k.box(Vector3(width + 0.12, 0.06, 0.13), Vector3(0, 2.89, FACE - 0.065), "paint", col.lightened(0.12))
	lettering(k.at_point(Vector3(0, 2.62, FACE - 0.07)), width * 0.72, LETTERS[kind % LETTERS.size()], rng)
	awning(k, width - 0.3, STRIPES[kind % STRIPES.size()])
	# a sign standing out from the wall at one end, on a bracket, for those
	# coming along the pavement
	if rng.randf() < 0.55:
		var sx := (width * 0.5 + 0.05) * (1.0 if rng.randf() < 0.5 else -1.0)
		var blade := k.at_point(Vector3(sx, 2.72, FACE - 0.42), Vector3(0, PI * 0.5, 0))
		blade.box(Vector3(0.62, 0.46, 0.05), Vector3.ZERO, "paint", col)
		for side: float in [-1.0, 1.0]:
			lettering(blade.at_point(Vector3(0, 0, side * 0.026), Vector3(0, 0.0 if side < 0.0 else PI, 0)), 0.48, LETTERS[kind % LETTERS.size()], rng, 1)
		k.bar(Vector3(sx, 2.98, FACE), Vector3(sx, 2.98, FACE - 0.75), 0.03, 0.03, "metal_dark", Color(0.15, 0.15, 0.16), false)


## A name in raised letters on a board, in a kit on the board's face (the
## street toward -z): one or two words (or `words`) no wider than `span`.
## (Seen from the street the kit's +x is on the left, so the letters run
## toward -x and each is drawn mirrored in x.)
static func lettering(k: BuildingKit, span: float, col: Color, rng: RandomNumberGenerator, words := 0) -> void:
	var glyphs: Array[float] = []
	for word in (words if words > 0 else rng.randi_range(1, 2)):
		if word > 0:
			glyphs.append(-0.16)
		for i in rng.randi_range(4, 8):
			glyphs.append(rng.randf_range(0.1, 0.17))
	var total := 0.0
	for g in glyphs:
		total += absf(g) + (0.045 if g > 0.0 else 0.0)
	var s := minf(1.0, span / total)
	var x := -total * s * 0.5
	for g in glyphs:
		if g > 0.0:
			var h := 0.25 * s
			var gi := rng.randi() % GLYPHS.size()
			k.part(BuildingKit.shape("glyph|%d" % gi, func() -> Array:
				var out: Array = []
				for st: Array in GLYPHS[gi]:
					out.append(BuildingKit.piece(Vector3(st[2] - st[0], st[3] - st[1], 1.0), Vector3(0.5 - (st[0] + st[2]) * 0.5, (st[1] + st[3]) * 0.5 - 0.5, 0)))
				return out), "paint", Transform3D(Basis.from_scale(Vector3(g * s, h, 0.016)), Vector3(-(x + g * s * 0.5), 0, -0.008)), col)
			x += (g + 0.045) * s
		else:
			x -= g * s


## A canvas awning `width` wide off the wall under the fascia, in stripes of
## `cols`, on a pair of arms, a scalloped valance along its front.
static func awning(k: BuildingKit, width: float, cols: Array) -> void:
	# (its scalloped edge clear of a man's head: no lower than 1.88 m)
	var depth := 1.35
	var top := 2.36
	var drop := 0.26
	var ang := atan2(drop, depth)
	var slope := sqrt(depth * depth + drop * drop)
	var n := maxi(5, int(width / 0.34))
	if n % 2 == 0:
		n += 1  # (so both ends are the same colour)
	var sw := width / n
	for i in n:
		var x := -width * 0.5 + (i + 0.5) * sw
		var c: Color = cols[i % 2]
		k.plate(Vector3(sw + 0.003, 0.018, slope), Vector3(x, top - drop * 0.5, FACE - depth * 0.5), "canvas", c, Vector3(-ang, 0, 0), true)
		k.plate(Vector3(sw + 0.003, 0.16, 0.012), Vector3(x, top - drop - 0.08, FACE - depth - 0.006), "canvas", c)
		# (a scallop under each stripe)
		k.prism(Vector3(sw * 0.98, 0.06, 0.012), Vector3(x, top - drop - 0.19, FACE - depth - 0.006), "canvas", c, Vector3(PI, 0, 0), false)
	var metal := Color(0.22, 0.23, 0.24)
	k.rod(Vector3(-width * 0.5, top - drop + 0.01, FACE - depth), Vector3(width * 0.5, top - drop + 0.01, FACE - depth), 0.025, "metal_dark", metal, 6)
	for sx: float in [-1.0, 1.0]:
		var ax := sx * (width * 0.5 - 0.15)
		k.bar(Vector3(ax, top - 0.5, FACE - 0.02), Vector3(ax, top - drop - 0.01, FACE - depth + 0.05), 0.03, 0.03, "metal_dark", metal, false)


## What a shop of `kind` puts out on the pavement in front of it, about 1.6 m
## along the wall, in a kit at its middle against the wall's face line (the
## street toward -z).
static func wares(k: BuildingKit, kind: int, rng: RandomNumberGenerator) -> void:
	match KINDS[kind % KINDS.size()]:
		"grocer":
			_stand(k.at_point(Vector3(0, 0, FACE - 0.5)), rng)
		"cafe":
			_bistro(k.at_point(Vector3(0, 0, FACE - 0.85)), rng)
		"baker":
			a_board(k.at_point(Vector3(-0.45, 0, FACE - 1.0), Vector3(0, rng.randf_range(-0.3, 0.3), 0)), FASCIA[2], rng)
			BuildingYards.pots(k.at_point(Vector3(0.45, 0, FACE - 0.3)), 2, rng)
		"hardware":
			_hardware(k.at_point(Vector3(0, 0, FACE - 0.55)), rng)
		"news":
			_rack(k.at_point(Vector3(0.3, 0, FACE - 0.35)), rng)
			a_board(k.at_point(Vector3(-0.55, 0, FACE - 1.0), Vector3(0, rng.randf_range(-0.3, 0.3), 0)), FASCIA[4], rng)


## A sandwich board: two boards hinged at the top, chalked on the face.
static func a_board(k: BuildingKit, col: Color, rng: RandomNumberGenerator) -> void:
	for s: float in [-1.0, 1.0]:
		var b := k.at_point(Vector3(0, 0.46, s * 0.13), Vector3(s * 0.28, 0, 0))
		b.box(Vector3(0.56, 0.9, 0.025), Vector3.ZERO, "wood_painted", col.darkened(0.1))
		b.plate(Vector3(0.44, 0.66, 0.006), Vector3(0, 0.02, s * 0.014), "plain_dark", Color(0.08, 0.09, 0.08))
		for line in rng.randi_range(3, 5):
			var lw := rng.randf_range(0.18, 0.36)
			b.plate(Vector3(lw, 0.035, 0.004), Vector3(rng.randf_range(-0.03, 0.03), 0.24 - line * 0.11, s * 0.018), "paint", Color(0.85, 0.85, 0.8))


## A greengrocer's stand: a stepped trestle with crates of produce tilted
## toward the street.
static func _stand(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var wood := Color(0.5, 0.38, 0.24)
	for sx: float in [-0.75, 0.75]:
		k.bar(Vector3(sx, 0, 0.25), Vector3(sx, 0.95, 0.25), 0.05, 0.05, "wood", wood, false)
		k.bar(Vector3(sx, 0, -0.35), Vector3(sx, 0.6, -0.35), 0.05, 0.05, "wood", wood, false)
	for row in 2:
		var y := 0.62 + row * 0.3
		var z := -0.22 + row * 0.38
		for i in 3:
			var x := (i - 1) * 0.5
			var c := k.at_point(Vector3(x, y, z), Vector3(0.28, rng.randf_range(-0.05, 0.05), 0))
			c.box(Vector3(0.5, 0.2, 0.4), Vector3(0, 0.1, 0), "wood", wood.lightened(0.1))
			# heaped with fruit or vegetables
			c.part(Res.sphere(0.5, 8), "paint", Transform3D(Basis.from_scale(Vector3(0.46, 0.2, 0.36)), Vector3(0, 0.19, 0)), PRODUCE[rng.randi() % PRODUCE.size()])


## A cafe table and two chairs set out by the wall.
static func _bistro(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var metal := Color(0.16, 0.17, 0.18)
	k.cyl(0.32, 0.32, 0.03, Vector3(0, 0.73, 0), "paint", Color(0.82, 0.8, 0.76), Vector3.ZERO, 12)
	k.cyl(0.025, 0.025, 0.7, Vector3(0, 0.36, 0), "metal_dark", metal, Vector3.ZERO, 6, false)
	k.cyl(0.2, 0.22, 0.03, Vector3(0, 0.015, 0), "metal_dark", metal, Vector3.ZERO, 10, false)
	for s: float in [-1.0, 1.0]:
		BuildingYards.chair(k.at_point(Vector3(s * 0.62, 0, rng.randf_range(-0.1, 0.1)), Vector3(0, s * PI * 0.5 + rng.randf_range(-0.3, 0.3), 0)), metal, "metal_dark")


## A hardware shop's stock: sacks on a pallet, gas bottles, a stack of buckets.
static func _hardware(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	BuildingFittings.pallet(k, Vector3(-0.35, 0, 0), Vector2(0.9, 0.7))
	for i in rng.randi_range(3, 5):
		k.box(Vector3(0.55, 0.16, 0.36), Vector3(-0.35 + (i % 2) * 0.05, 0.22 + i * 0.15, (i % 2) * 0.12 - 0.06), "sandbag",
			Color(0.82, 0.78, 0.68).darkened(rng.randf_range(0.0, 0.15)), Vector3(0, rng.randf_range(-0.15, 0.15), 0))
	for i in 2:
		k.cyl(0.15, 0.15, 0.95, Vector3(0.45 + i * 0.32, 0.475, 0.15), "paint", [Color(0.7, 0.12, 0.1), Color(0.15, 0.3, 0.6)][rng.randi() % 2], Vector3.ZERO, 10)
	for i in rng.randi_range(2, 4):
		k.cyl(0.16, 0.13, 0.26, Vector3(0.6, 0.13 + i * 0.07, -0.3), "paint", Color(0.85, 0.55, 0.12), Vector3.ZERO, 10, false)


## A newsagent's rack of papers: a wire frame with three sloping shelves.
static func _rack(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var metal := Color(0.3, 0.31, 0.32)
	for sx: float in [-0.35, 0.35]:
		k.bar(Vector3(sx, 0, 0.1), Vector3(sx, 1.2, 0.1), 0.025, 0.025, "metal_dark", metal, false)
	for row in 3:
		var y := 0.45 + row * 0.3
		var shelf := k.at_point(Vector3(0, y, -0.05 + row * 0.06), Vector3(0.6, 0, 0))
		shelf.plate(Vector3(0.7, 0.02, 0.24), Vector3.ZERO, "metal_dark", metal)
		for i in 3:
			var paper := shelf.at_point(Vector3((i - 1) * 0.23, 0.02, 0))
			paper.plate(Vector3(0.21, 0.012, 0.22), Vector3.ZERO, "paint", Color(0.88, 0.87, 0.84))
			paper.plate(Vector3(0.21, 0.004, 0.05), Vector3(0, 0.008, -0.08), "paint", [Color(0.7, 0.1, 0.1), Color(0.1, 0.2, 0.5), Color(0.15, 0.15, 0.15)][rng.randi() % 3])
