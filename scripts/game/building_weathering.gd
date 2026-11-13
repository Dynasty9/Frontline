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


## A stain on a wall face, in a face kit (+z out, x along it, y up): a patch
## of the wall's own surface laid 3 mm proud over `rect` (face x and y), each
## point the colour `tone` gives for the wall there (as its body was tinted:
## see Structure._tone) times `mul` as far as `amount` says (a Callable of u
## across and v up the patch's unit square, 0 to 1), and the wall's own colour
## all round its rim. So it fades into the wall with no edge: soot over a
## window that burned, rain stains under a sill, the scorch round a shell hit.
## `edges` says which rims fade out (1 left, 2 right, 4 bottom, 8 top): leave
## one open where something proud of the wall (a head, a sill) hides the seam.
static func stain(k: BuildingKit, rect: Rect2, surface: String, tone: Callable, mul: Color, amount: Callable, cols := 8, rows := 8, edges := 15) -> void:
	var at := PackedVector3Array()
	var shade := PackedColorArray()
	for j in rows + 1:
		for i in cols + 1:
			var u := float(i) / cols
			var v := float(j) / rows
			var p := Vector2(rect.position.x + u * rect.size.x, rect.position.y + v * rect.size.y)
			var a := 0.0
			var rim := (i == 0 and (edges & 1) != 0) or (i == cols and (edges & 2) != 0) or (j == 0 and (edges & 4) != 0) or (j == rows and (edges & 8) != 0)
			if not rim:
				a = clampf(float(amount.call(u, v)), 0.0, 1.0)
			var base: Color = tone.call(p)
			var c := Color(base.r * lerpf(1.0, mul.r, a), base.g * lerpf(1.0, mul.g, a), base.b * lerpf(1.0, mul.b, a))
			# (as a baked part's tint is packed: linear light outside the
			# browser, and scaled down for the merged material to restore)
			if not Mats.per_material:
				c = c.srgb_to_linear()
			at.append(Vector3(p.x, p.y, 0.003))
			shade.append(Color(c.r / Mats.VC_K, c.g / Mats.VC_K, c.b / Mats.VC_K))
	var v3 := PackedVector3Array()
	var n3 := PackedVector3Array()
	var c3 := PackedColorArray()
	for j in rows:
		for i in cols:
			var a0 := j * (cols + 1) + i
			# two triangles a cell, wound to face +z
			for tri: Array in [[a0, a0 + cols + 2, a0 + 1], [a0, a0 + cols + 1, a0 + cols + 2]]:
				for q: int in tri:
					v3.append(at[q])
					c3.append(shade[q])
					n3.append(Vector3.BACK)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v3
	arrays[Mesh.ARRAY_NORMAL] = n3
	arrays[Mesh.ARRAY_COLOR] = c3
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(mesh, arrays)
	k.part_with(mesh, Mats.vc_variant(Mats.get_mat(surface)), Transform3D.IDENTITY, Color(1, 1, 1), false)


## Soot from a fire inside, licked up the wall from an opening whose top is
## `head` high and `w` wide at `x`: densest at the head, widening and thinning
## as it climbs to `top`.
## (`reach` keeps it on the face: no further than that from the middle.)
static func soot(k: BuildingKit, x: float, head: float, w: float, top: float, surface: String, tone: Callable, rng: RandomNumberGenerator, reach := INF) -> void:
	var lean := rng.randf_range(-0.12, 0.12)
	var ph := rng.randf() * TAU
	var x0 := maxf(x - w * 0.5 - 0.5, -reach)
	var rect := Rect2(x0, head, minf(x + w * 0.5 + 0.5, reach) - x0, maxf(0.5, top - head))
	stain(k, rect, surface, tone, Color(0.06, 0.055, 0.05), func(u: float, v: float) -> float:
		var wide := lerpf(0.7, 1.0, v)
		var off := absf((u - 0.5 - lean * v) * 2.0) / wide
		var body := clampf(1.0 - pow(off, 2.5), 0.0, 1.0)
		var wisp := 0.85 + 0.15 * sin(u * 17.0 + v * 6.0 + ph)
		return body * pow(1.0 - v, 0.45) * wisp * 1.5, 12, 8, 11)


## Rain off a sill run down the wall under its ends: two pale-dark streaks
## below a sill `w` wide at `x`, `y` high.
static func streaks(k: BuildingKit, x: float, y: float, w: float, surface: String, tone: Callable, rng: RandomNumberGenerator) -> void:
	for sx: float in [-1.0, 1.0]:
		var length := rng.randf_range(0.55, minf(1.2, y - 0.4))
		var sw := rng.randf_range(0.18, 0.3)
		var cx := x + sx * (w * 0.5 - sw * 0.2)
		var strength := rng.randf_range(0.6, 0.95)
		stain(k, Rect2(cx - sw * 0.5, y - 0.06 - length, sw, length), surface, tone, Color(0.5, 0.48, 0.45), func(u: float, v: float) -> float:
			var across := 1.0 - absf(u * 2.0 - 1.0)
			return across * pow(v, 0.7) * strength, 4, 6, 7)


## Where a shell burst against a wall: the face blown off in a ragged patch
## round `c` (`raw`: the brick under the render, or raw brick or stone), the
## scorch round it, strikes (`chips`) spattered further out.
static func scar(k: BuildingKit, c: Vector2, r: float, surface: String, tone: Callable, raw: Color, chips: Color, rng: RandomNumberGenerator, gaps: Array = [], reach := INF) -> void:
	var ph := rng.randf() * TAU
	stain(k, Rect2(c.x - r * 1.9, c.y - r * 1.6, r * 3.8, r * 3.4), surface, tone, Color(0.2, 0.19, 0.18), func(u: float, v: float) -> float:
		var q := Vector2((u - 0.5) * 2.0, (v - 0.47) * 2.0)
		# (ragged: the blast throws it further one way than another)
		var d := q.length() * (1.0 + 0.12 * sin(q.angle() * 3.0 + ph) + 0.06 * sin(q.angle() * 7.0 - ph))
		return pow(clampf(1.0 - d, 0.0, 1.0), 1.1) * 1.3, 14, 14)
	var brick := BuildingMaterials.surface("brick")
	for i in rng.randi_range(5, 8):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, r * 0.45)
		var s := Vector2(rng.randf_range(0.3, 0.55), rng.randf_range(0.18, 0.4)) * r * 1.6
		k.plate(Vector3(s.x, s.y, 0.012), Vector3(c.x + cos(a) * d, c.y + sin(a) * d * 0.8, 0.008 + i * 0.001), brick, raw.darkened(rng.randf_range(0.0, 0.25)), Vector3(0, 0, rng.randf() * TAU))
	# the hole it punched (dark) and the pocks round it
	k.plate(Vector3(r * 0.42, r * 0.34, 0.01), Vector3(c.x, c.y, 0.02), "plain_dark", Color(0.05, 0.045, 0.04), Vector3(0, 0, rng.randf() * TAU))
	pocks(k, c, r * 2.6, rng.randi_range(10, 18), chips, rng, gaps, reach)


## Bullet strikes on a face: `count` chips round `c` within `spread`, each a
## flake of the face knocked off (the fresh `raw` under it) round a dark hole;
## none in the openings (`gaps`) or further than `reach` from the middle.
static func pocks(k: BuildingKit, c: Vector2, spread: float, count: int, raw: Color, rng: RandomNumberGenerator, gaps: Array = [], reach := INF) -> void:
	for i in count:
		var p := c + Vector2(rng.randfn(0.0, spread * 0.45), rng.randfn(0.0, spread * 0.35))
		var s := rng.randf_range(0.05, 0.1)
		var inside := p.y < 0.4 or p.y > 2.8 or absf(p.x) > reach - s
		for g: Rect2 in gaps:
			inside = inside or g.grow(s).has_point(p)
		if inside:
			continue
		var turn := Basis(Vector3.BACK, rng.randf() * TAU)
		k.part(_flake(), "plain", Transform3D(turn.scaled(Vector3(s, s * rng.randf_range(0.7, 1.0), 1.0)), Vector3(p.x, p.y, 0.005)), raw.darkened(rng.randf_range(0.0, 0.15)), false)
		k.part(_flake(), "plain_dark", Transform3D(turn.scaled(Vector3(s * 0.34, s * 0.34, 1.0)), Vector3(p.x, p.y, 0.009)), Color(0.05, 0.045, 0.04), false)


## A flake knocked off a face: a jagged outline a unit across, 8 mm thick.
static func _flake() -> ArrayMesh:
	var o := PackedVector2Array()
	for i in 9:
		var a := TAU * i / 9.0
		var r := 0.5 * (0.62 + 0.38 * absf(sin(i * 2.3 + 0.7)))
		o.append(Vector2(cos(a), sin(a)) * r)
	return BuildingKit.extrusion("flake", o, 0.008)


## Planks nailed across a window from outside (`c` its middle, `size` the
## opening), weathered grey: two or three with gaps between, so it's still a
## window a man can see and shoot through.
static func boards(k: BuildingKit, c: Vector3, size: Vector2, rng: RandomNumberGenerator) -> void:
	var wood := Color(0.47, 0.4, 0.32).darkened(rng.randf_range(0.0, 0.25))
	var n := rng.randi_range(2, 3)
	for i in n:
		var y := c.y + size.y * (0.32 if i == 0 else (-0.3 if i == 1 else 0.0))
		var tilt := rng.randf_range(-0.07, 0.07) if i < 2 else rng.randf_range(0.42, 0.55) * (1.0 if rng.randf() < 0.5 else -1.0)
		var ln := (size.x + 0.26) / cos(tilt) if i < 2 else size.y / sin(absf(tilt)) * 0.9
		k.plate(Vector3(ln, rng.randf_range(0.15, 0.2), 0.026), Vector3(c.x, y, 0.035 + i * 0.027), "wood", wood.lightened(rng.randf_range(-0.05, 0.08)), Vector3(0, 0, tilt), true)


## Sandbags laid along a window's sill (`c` the window's middle, `size` its
## opening), two courses: a firing position somebody made of it.
static func sill_bags(k: BuildingKit, c: Vector3, size: Vector2, rng: RandomNumberGenerator) -> void:
	var y := c.y - size.y * 0.5
	var col := Color(0.55, 0.49, 0.34)
	var per := maxi(2, int(size.x / 0.42))
	for row in 2:
		var count := per if row == 0 else per - 1
		for i in count:
			var x := c.x + (float(i) - (count - 1) * 0.5) * size.x / per
			k.box(Vector3(size.x / per + 0.02, 0.14, 0.24), Vector3(x, y + 0.07 + row * 0.13, 0.0), "sandbag",
				col.darkened(rng.randf_range(0.0, 0.18)), Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.08, 0.08), 0))


## Straw strewn over a barn's floor (`size` its slab, `top` its height),
## thickest along the walls where it's swept: flat, so nobody trips on it.
static func straw(k: BuildingKit, size: Vector3, top: float, rng: RandomNumberGenerator) -> void:
	var hx := size.x * 0.5 - 0.3
	var hz := size.z * 0.5 - 0.3
	for i in rng.randi_range(14, 22):
		var edge := rng.randf() < 0.6
		var p := Vector3(rng.randf_range(-hx, hx), 0, rng.randf_range(-hz, hz))
		if edge:
			if rng.randf() < 0.5:
				p.x = signf(p.x) * (hx - rng.randf_range(0.0, 0.5))
			else:
				p.z = signf(p.z) * (hz - rng.randf_range(0.0, 0.5))
		var s := Vector2(rng.randf_range(0.5, 1.4), rng.randf_range(0.3, 0.8))
		k.plate(Vector3(s.x, 0.012, s.y), p + Vector3(0, top + 0.006 + i * 0.0005, 0), "plain", Color(0.72, 0.62, 0.36).darkened(rng.randf_range(0.0, 0.25)), Vector3(0, rng.randf() * TAU, 0))


## A heap of rubble where a wall came down, `L` long and `D` deep, standing
## on y = 0 (its cover is the boxes Structure gives it: about 0.7 m high, a
## metre at its crown off to one side): a faceted mound of broken masonry,
## lumps of brick and slabs of plaster on it, a charred joist or two and
## bent reinforcing rods sticking out.
static func heap(k: BuildingKit, L: float, D: float, rng: RandomNumberGenerator) -> void:
	var nx := maxi(8, int(L / 0.22))
	var nz := maxi(5, int(D / 0.2))
	var ph := rng.randf() * TAU
	var cx := L * 0.15
	var lumps := PackedFloat32Array()
	for i in (nx + 1) * (nz + 1):
		lumps.append(rng.randf_range(-0.09, 0.09))
	var at := func(i: int, j: int) -> Vector3:
		var x := -L * 0.5 + L * i / nx
		var z := -D * 0.5 + D * j / nz
		var ex := absf(x) / (L * 0.5)
		var ez := absf(z) / (D * 0.5)
		var body := 0.62 * (1.0 - pow(ex, 3.0)) * (1.0 - pow(ez, 2.5))
		var crown := 0.85 * exp(-(pow((x - cx) / (L * 0.32), 2.0) + pow((z - 0.1) / 0.6, 2.0))) * (1.0 - pow(ez, 2.5))
		var rough := 0.0 if i == 0 or j == 0 or i == nx or j == nz else lumps[j * (nx + 1) + i] + 0.04 * sin(x * 6.0 + ph)
		return Vector3(x, maxf(0.0, maxf(body, crown) + rough), z)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for j in nz:
		for i in nx:
			var a: Vector3 = at.call(i, j)
			var b: Vector3 = at.call(i + 1, j)
			var c: Vector3 = at.call(i + 1, j + 1)
			var d: Vector3 = at.call(i, j + 1)
			for tri: Array in [[a, b, c], [a, c, d]]:
				var nm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
				if nm.y < 0.0:
					nm = -nm
				BuildingKit._tri(v, n, tri[0], tri[1], tri[2], nm)
	# (dust and grit: the broken pieces are on it)
	k.part(BuildingKit._commit(v, n), "concrete", Transform3D.IDENTITY, Color(0.5, 0.46, 0.41))
	var top := func(x: float, z: float) -> float:
		var p: Vector3 = at.call(clampi(roundi((x / L + 0.5) * nx), 0, nx), clampi(roundi((z / D + 0.5) * nz), 0, nz))
		return p.y
	# lumps of brick (some still mortared together) and of concrete and stone
	for i in rng.randi_range(16, 26):
		var x := rng.randf_range(-L * 0.42, L * 0.42)
		var z := rng.randf_range(-D * 0.38, D * 0.38)
		var s := rng.randf_range(0.8, 2.0)
		var roll := rng.randf()
		var col := Color(0.5, 0.29, 0.22) if roll < 0.55 else (Color(0.55, 0.54, 0.5) if roll < 0.85 else Color(0.62, 0.58, 0.5))
		k.box(Vector3(0.22, 0.08, 0.12) * s if roll < 0.55 else Vector3(0.2, 0.12, 0.16) * s, Vector3(x, float(top.call(x, z)) + 0.02, z), "paint" if roll < 0.55 else "concrete",
			col.darkened(rng.randf_range(0.0, 0.3)).lerp(Color(0.5, 0.48, 0.44), 0.25), Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)), false)
	# slabs of plaster, still painted on one side
	for i in rng.randi_range(3, 6):
		var x := rng.randf_range(-L * 0.4, L * 0.4)
		var z := rng.randf_range(-D * 0.35, D * 0.35)
		k.plate(Vector3(rng.randf_range(0.35, 0.8), 0.035, rng.randf_range(0.25, 0.55)), Vector3(x, float(top.call(x, z)) + 0.03, z), "plaster",
			Color(0.74, 0.69, 0.6).darkened(rng.randf_range(0.0, 0.2)), Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45)), true)
	# a joist or two, charred or bare, run up out of the heap
	for i in rng.randi_range(1, 2):
		var x := rng.randf_range(-L * 0.3, L * 0.3)
		var z := rng.randf_range(-D * 0.2, D * 0.2)
		var base := Vector3(x, float(top.call(x, z)) * 0.5, z)
		var yaw := rng.randf() * TAU
		var rise := rng.randf_range(0.25, 0.6)
		var ln := rng.randf_range(1.1, 1.9)
		var tip := base + Vector3(cos(yaw) * cos(rise), sin(rise), sin(yaw) * cos(rise)) * ln
		tip.x = clampf(tip.x, -L * 0.5 - 0.3, L * 0.5 + 0.3)
		tip.z = clampf(tip.z, -D * 0.5 - 0.3, D * 0.5 + 0.3)
		var charred := rng.randf() < 0.5
		k.bar(base, tip, 0.14, 0.09, "burnt" if charred else "wood_dark", CHAR if charred else Color(0.36, 0.27, 0.18))
	# reinforcing rods bent out of a lump of concrete
	for i in rng.randi_range(0, 3):
		var x := rng.randf_range(-L * 0.35, L * 0.35)
		var z := rng.randf_range(-D * 0.3, D * 0.3)
		var a := Vector3(x, float(top.call(x, z)), z)
		var b := a + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.3, 0.55), rng.randf_range(-0.2, 0.2))
		var c := b + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.1, 0.15), rng.randf_range(-0.35, 0.35))
		var rust := Color(0.36, 0.22, 0.14)
		k.rod(a, b, 0.012, "metal_dark", rust, 4, false)
		k.rod(b, c, 0.012, "metal_dark", rust, 4, false)


## A tarpaulin's colours: blue and grey-blue sheet, green, brown, orange, all
## faded by the sun.
const TARPS := [Color(0.22, 0.38, 0.6), Color(0.3, 0.42, 0.55), Color(0.29, 0.36, 0.25), Color(0.47, 0.42, 0.32), Color(0.62, 0.38, 0.16)]


## A tarpaulin pulled over a hole in a roof, in a kit lying on the slope (-z
## down it, `eave` how far down the slope the eave is, 0 if unknown; `room`
## the most it may spread either side, short of a hip): the sheet heaped over
## the broken tiles under it, drawn into ridges between the weights holding
## it down (old tyres, a sandbag, a batten along its top edge) and creased by
## the wind, its edges pulled in between the corners, its hem a darker band
## with eyelets at the corners; cords from the lower two run down the tiles and
## over the eave.
static func tarp(k: BuildingKit, rng: RandomNumberGenerator, eave := 0.0, room := INF) -> void:
	var t := RandomNumberGenerator.new()
	t.seed = rng.randi()
	var sx := minf(t.randf_range(1.9, 2.7), room * 2.0)
	var sz := t.randf_range(1.5, 2.1)
	if sx < 1.0:
		return
	var col: Color = TARPS[t.randi() % TARPS.size()].darkened(t.randf_range(0.0, 0.12))
	var tk := k.at_point(Vector3.ZERO, Vector3(0, t.randf_range(-0.06, 0.06), 0))
	var hx := sx * 0.5
	var hz := sz * 0.5
	# where it's weighted: a tyre near each lower corner, one or two more
	# and a sandbag on it, none on top of another; the batten holds the top
	var weights: Array = []  # [where, how wide it presses, a sandbag]
	for cx: float in [-1.0, 1.0]:
		weights.append([Vector2(cx * (hx - t.randf_range(0.3, 0.4)), -(hz - t.randf_range(0.3, 0.4))), 0.34, false])
	for i in t.randi_range(2, 3):
		for attempt in 8:
			var p := Vector2(t.randf_range(-0.32, 0.32) * sx, t.randf_range(-0.15, 0.32) * sz)
			var clear := true
			for w: Array in weights:
				if (w[0] as Vector2).distance_to(p) < 0.75:
					clear = false
			if clear:
				weights.append([p, 0.32, i == 0])
				break
	var heap := Vector2(t.randf_range(-0.15, 0.15) * sx, t.randf_range(-0.1, 0.15) * sz)
	var creases: Array = []
	for i in 4:
		var a := t.randf() * TAU
		creases.append([Vector2(cos(a), sin(a)) * t.randf_range(6.0, 12.0), t.randf() * TAU, t.randf_range(0.01, 0.022)])
	var height := func(x: float, z: float) -> float:
		var u := x / hx
		var v := z / hz
		var q := Vector2(x, z)
		# heaped over the broken battens and tiles under it, highest over the hole
		var y := 0.06 * maxf(0.0, (1.0 - u * u) * (1.0 - v * v)) + 0.08 * exp(-(pow((x - heap.x) / 0.5, 2.0) + pow((z - heap.y) / 0.4, 2.0)))
		for c: Array in creases:
			y += float(c[2]) * sin((c[0] as Vector2).dot(q) + float(c[1]))
		# pulled taut into a ridge between each pair of weights
		for i in weights.size():
			for j in range(i + 1, weights.size()):
				var a: Vector2 = weights[i][0]
				var b: Vector2 = weights[j][0]
				var ab := b - a
				var f := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				var off := q.distance_to(a + ab * f)
				y += 0.03 * exp(-pow(off / 0.07, 2.0)) * sin(f * PI)
		# the edges lie on the tiles, lifting a little between the weights
		var edge := minf(hx - absf(x), hz - absf(z))
		y = y * smoothstep(0.0, 0.25, edge) + 0.012 * (1.0 + sin(x * 4.0 + z * 3.0)) * (1.0 - smoothstep(0.0, 0.2, edge))
		for w: Array in weights:
			var d: float = (w[0] as Vector2).distance_to(q)
			y = lerpf(y, 0.0, exp(-pow(d / float(w[1]), 2.0)))
		return 0.014 + maxf(0.0, y)
	# (its edges pulled in between the corners, as a sheet held by its corners is)
	var drawn := func(x: float, z: float) -> Vector2:
		var u := x / hx
		var v := z / hz
		return Vector2(x - signf(x) * 0.07 * (1.0 - v * v) * pow(absf(u), 6.0), z - signf(z) * 0.06 * (1.0 - u * u) * pow(absf(v), 6.0))
	# the sheet on a grid, its outermost band the hem
	var xs := PackedFloat32Array([-hx, -hx + 0.045])
	var zs := PackedFloat32Array([-hz, -hz + 0.045])
	var nx := maxi(10, int(sx / 0.11))
	var nz := maxi(8, int(sz / 0.11))
	for i in range(1, nx):
		xs.append(lerpf(-hx + 0.045, hx - 0.045, float(i) / nx))
	for j in range(1, nz):
		zs.append(lerpf(-hz + 0.045, hz - 0.045, float(j) / nz))
	xs.append_array([hx - 0.045, hx])
	zs.append_array([hz - 0.045, hz])
	var pts: Array = []
	var nrm: Array = []
	for j in zs.size():
		var row := PackedVector3Array()
		var nrow := PackedVector3Array()
		for i in xs.size():
			var x := xs[i]
			var z := zs[j]
			var at: Vector2 = drawn.call(x, z)
			row.append(Vector3(at.x, float(height.call(x, z)), at.y))
			var e := 0.025
			var dx: float = float(height.call(x + e, z)) - float(height.call(x - e, z))
			var dz: float = float(height.call(x, z + e)) - float(height.call(x, z - e))
			nrow.append(Vector3(-dx / (2.0 * e), 1.0, -dz / (2.0 * e)).normalized())
		pts.append(row)
		nrm.append(nrow)
	var body_v := PackedVector3Array()
	var body_n := PackedVector3Array()
	var hem_v := PackedVector3Array()
	var hem_n := PackedVector3Array()
	var last_i := xs.size() - 2
	var last_j := zs.size() - 2
	for j in zs.size() - 1:
		for i in xs.size() - 1:
			var hem := i == 0 or j == 0 or i == last_i or j == last_j
			var v := hem_v if hem else body_v
			var n := hem_n if hem else body_n
			var r0: PackedVector3Array = pts[j]
			var r1: PackedVector3Array = pts[j + 1]
			var m0: PackedVector3Array = nrm[j]
			var m1: PackedVector3Array = nrm[j + 1]
			BuildingWire._tri(v, n, r0[i], r0[i + 1], r1[i + 1], m0[i], m0[i + 1], m1[i + 1])
			BuildingWire._tri(v, n, r0[i], r1[i + 1], r1[i], m0[i], m1[i + 1], m1[i])
	tk.part(BuildingKit._commit(body_v, body_n), "canvas", Transform3D.IDENTITY, col)
	tk.part(BuildingKit._commit(hem_v, hem_n), "canvas", Transform3D.IDENTITY, col.darkened(0.3), false)
	# the eyelets at its corners; cords from the lower two down to the eave
	var cord := Color(0.78, 0.74, 0.62) if t.randf() < 0.6 else Color(0.85, 0.66, 0.18)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var c2: Vector2 = drawn.call(cx * (hx - 0.05), cz * (hz - 0.05))
			var e := Vector3(c2.x, 0.02, c2.y)
			tk.part(BuildingKit.ring(0.008, 0.016), "metal", Transform3D(Basis.IDENTITY, e), Color(0.6, 0.6, 0.58), false)
			if cz < 0.0 and eave > hz + 0.2:
				var foot := Vector3(e.x + cx * t.randf_range(0.0, 0.2), 0.02, -eave)
				tk.rod(e, foot, 0.006, "canvas", cord, 4, false)
				tk.rod(foot, foot + Vector3(0, -0.18, -0.06), 0.006, "canvas", cord, 4, false)
	# the weights on it: old tyres lying flat, a sandbag, a batten along the top
	for w: Array in weights:
		var p: Vector2 = w[0]
		if w[2]:
			tk.box(Vector3(0.52, 0.16, 0.32), Vector3(p.x, 0.09, p.y), "sandbag", Color(0.55, 0.49, 0.34), Vector3(t.randf_range(-0.08, 0.08), t.randf() * TAU, 0))
		else:
			var tilt := Basis.from_euler(Vector3(t.randf_range(-0.07, 0.07), t.randf() * TAU, t.randf_range(-0.07, 0.07)))
			tk.part(Res.torus(0.2, 0.31), "rubber", Transform3D(tilt * Basis.from_scale(Vector3(1.0, 1.55, 1.0)), Vector3(p.x, 0.08, p.y)), Color(0.07, 0.07, 0.07))
	if t.randf() < 0.6:
		tk.bar(Vector3(-hx + 0.08, 0.035, hz - 0.12), Vector3(hx - 0.08, 0.035, hz - 0.12), 0.07, 0.035, "wood", Color(0.46, 0.38, 0.27))


## A hole in a roof, in a kit lying on the slope: the dark of the loft, the
## battens across it, broken tiles at its edges.
static func hole(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var size := Vector2(rng.randf_range(0.8, 1.4), rng.randf_range(0.6, 1.1))
	k.plate(Vector3(size.x, 0.006, size.y), Vector3(0, 0.003, 0), "plain_dark", Color(0.03, 0.025, 0.02))
	for i in 3:
		k.bar(Vector3(-size.x * 0.55, 0.012, (i - 1) * size.y * 0.3), Vector3(size.x * 0.55, 0.012, (i - 1) * size.y * 0.3), 0.04, 0.025, "wood", Color(0.42, 0.32, 0.2), false)
	for i in rng.randi_range(3, 6):
		var a := rng.randf() * TAU
		k.plate(Vector3(0.2, 0.014, 0.14), Vector3(cos(a) * size.x * 0.52, 0.01, sin(a) * size.y * 0.52), "paint", Color(0.48, 0.22, 0.14), Vector3(rng.randf_range(-0.3, 0.3), a, 0))


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
