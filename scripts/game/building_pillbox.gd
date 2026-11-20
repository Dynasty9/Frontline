class_name BuildingPillbox
extends RefCounted

## The Coalition's concrete bunker, drawn as a pillbox cast in place: walls
## poured against plank shuttering in one piece (the `shuttered` surface
## carries the boards' print), their outer corners cut back so a round glances
## off rather than knocking the arris away, and dark inside; a roof slab thick
## enough to stop a mortar round, its edge chamfered and its top cast with a
## fall to every side so the rain runs off, moss grown on it, a steel
## observation cupola, the escape hatch and a vent on its crown; at every
## firing slit a splayed embrasure (a hood over it, a sill sloped out under
## it, cheeks angled so the gunner can traverse); open steel doors at the
## back; the grime of a season and the strikes round the slits. Earth is
## banked against the front and sides up to the slits (WorksModels.berms). The
## walls stand exactly where the structure's parts are, since those are what
## stop the bullets: only the corners' chamfer is drawn short of them.

const SURFACE := "shuttered"
const CONCRETE := Color(0.5, 0.47, 0.41)  # weathered, not new-white
const WEATHERED := Color(0.38, 0.37, 0.33)  # the roof: darker, rained on and grown over
const DARK := Color(0.11, 0.11, 0.1)  # the inside, out of the light
const STEEL := Color(0.2, 0.2, 0.19)
const OLIVE := Color(0.3, 0.32, 0.25)
const ARMY_PAINT := "wire_military"  # (the army's dull olive on steel: nothing to catch the light)
const HALF := 2.8  # the walls' outer faces, from the middle
const CHAMFER := 0.3  # how far the outer corners are cut back along each face
const EAVE := 2.14  # the slab's underside where it overhangs the walls
const SLAB_HALF := 3.0  # how far the slab reaches out (0.2 m over the walls)
const SLAB_TOP := 2.8  # the top of the slab's crown, where the hatch and the rest stand
const CROWN := 1.6  # the crown's half-width: from there the top falls to the edge
const EMBRASURE := 0.38  # how far an embrasure's frame stands out of the wall

static var _meshes := {}


## The walls, `k` at the bunker's middle on the ground: the structure's wall
## parts (`parts`; the roof part is left to the slab) drawn as plain boxes,
## so they meet flush with no seam between them, as one pour does, and the
## four that make the outer corners cut back by CHAMFER.
static func walls(k: BuildingKit, parts: Array, col: Color) -> void:
	for p: Dictionary in parts:
		var c: Vector3 = p.p
		var s: Vector3 = p.s
		if c.y - s.y * 0.5 >= EAVE - 0.1:
			continue
		var lo := Vector2(c.x - s.x * 0.5, c.z - s.z * 0.5)
		var hi := Vector2(c.x + s.x * 0.5, c.z + s.z * 0.5)
		var cx := -1.0 if is_equal_approx(lo.x, -HALF) else (1.0 if is_equal_approx(hi.x, HALF) else 0.0)
		var cz := -1.0 if is_equal_approx(lo.y, -HALF) else (1.0 if is_equal_approx(hi.y, HALF) else 0.0)
		if cx == 0.0 or cz == 0.0:
			k.part(BuildingKit.plain(s), SURFACE, Mats.place(c, Vector3(0, float(p.get("r", 0.0)), 0)), col)
			continue
		var corner := Vector2(cx * HALF, cz * HALF)
		var square: Array[Vector2] = [lo, Vector2(hi.x, lo.y), hi, Vector2(lo.x, hi.y)]
		var outline := PackedVector2Array()
		for i in 4:
			var q: Vector2 = square[i]
			if not q.is_equal_approx(corner):
				outline.append(q)
				continue
			outline.append(q + (square[(i + 3) % 4] - q).normalized() * CHAMFER)
			outline.append(q + (square[(i + 1) % 4] - q).normalized() * CHAMFER)
		var key := "wall|%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d" % [lo.x, lo.y, hi.x, hi.y, c.y - s.y * 0.5, c.y + s.y * 0.5, int(cx), int(cz)]
		k.part(solid(key, [[c.y - s.y * 0.5, outline], [c.y + s.y * 0.5, outline]]), SURFACE, Transform3D.IDENTITY, col)
	_lining(k, parts)


## The inside, out of the light: dark on the walls' inner faces and under the
## slab, so a slit or the doorway looks into the gloom of the room behind it
## rather than at lit concrete. Flat on the faces, so it is never in the way of
## the men inside.
static func _lining(k: BuildingKit, parts: Array) -> void:
	var room := HALF - 0.6
	for p: Dictionary in parts:
		var c: Vector3 = p.p
		var s: Vector3 = p.s
		var y0 := c.y - s.y * 0.5
		if y0 >= EAVE - 0.1:
			continue
		var y1 := minf(c.y + s.y * 0.5, EAVE)
		for d: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			# (the face of this part looking into the room along d)
			if not is_equal_approx(c.dot(d) + absf(s.dot(d)) * 0.5, -room):
				continue
			var ax := Vector3.UP.cross(d)
			var a := maxf(c.dot(ax) - absf(s.dot(ax)) * 0.5, -room)
			var b := minf(c.dot(ax) + absf(s.dot(ax)) * 0.5, room)
			if b - a < 0.02:
				continue
			var size := Vector3(absf(ax.x) * (b - a) + absf(d.x) * 0.01, y1 - y0, absf(ax.z) * (b - a) + absf(d.z) * 0.01)
			k.plate(size, ax * (a + b) * 0.5 - d * (room - 0.006) + Vector3(0, (y0 + y1) * 0.5, 0), "plain_dark", DARK)
	k.plate(Vector3(room * 2.0, 0.01, room * 2.0), Vector3(0, EAVE - 0.006, 0), "plain_dark", DARK)
	k.plate(Vector3(room * 2.0, 0.01, room * 2.0), Vector3(0, 0.046, 0), "plain_dark", DARK.lightened(0.06))


## The roof, `k` at the bunker's middle on the ground: the slab, the moss on
## it, and on its crown the observation cupola, the escape hatch and a vent.
static func roof(k: BuildingKit, col: Color, rng: RandomNumberGenerator) -> void:
	# the slab: a vertical edge over the walls, chamfered at the top, the top
	# falling from the crown to the edge; its corners cut back with the walls'
	var cut := CHAMFER + (SLAB_HALF - HALF) * (2.0 - sqrt(2.0))
	k.part(solid("slab", [
		[EAVE, octagon(SLAB_HALF, cut)],
		[2.5, octagon(SLAB_HALF, cut)],
		[2.62, octagon(SLAB_HALF - 0.12, cut - 0.07)],
		[SLAB_TOP, octagon(CROWN, 0.2)],
	]), SURFACE, Transform3D.IDENTITY, col)
	var y := SLAB_TOP
	# what grows on a roof left out in the weather: moss and lichen in
	# patches where the water stands, as one stain over the whole crown (so
	# no patch's rim is laid over another's), in a frame lying on it, +z up
	var up := k.moved(Transform3D(Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP), Vector3(0, y, 0)))
	var tint := Mats.tint_for(SURFACE, col)
	var tone := func(_p: Vector2) -> Color: return tint
	var blots: Array[Vector4] = []  # (x, y, radius, how thick)
	for i in rng.randi_range(5, 7):
		var r := rng.randf_range(0.35, 0.8)
		blots.append(Vector4(rng.randf_range(-CROWN + r * 0.6, CROWN - r * 0.6), rng.randf_range(-CROWN + r * 0.6, CROWN - r * 0.6), r, rng.randf_range(0.5, 1.0)))
	var ph := rng.randf() * TAU
	BuildingWeathering.stain(up, Rect2(-CROWN, -CROWN, CROWN * 2.0, CROWN * 2.0), SURFACE, tone, Color(0.62, 0.68, 0.48), func(u: float, v: float) -> float:
		var p := Vector2(lerpf(-CROWN, CROWN, u), lerpf(-CROWN, CROWN, v))
		var a := 0.0
		for b: Vector4 in blots:
			var d := p.distance_to(Vector2(b.x, b.y)) / b.z
			a = maxf(a, clampf(1.25 - d + 0.25 * sin(p.x * 6.0 + ph) * sin(p.y * 5.0 - ph), 0.0, 1.0) * b.w)
		return a, 11, 11)
	# the escape hatch: a steel lid on a kerb, a bar to lift it by, its hinges
	# to the back
	var hatch := Vector3(0.95, y, 0.95)
	k.box(Vector3(0.95, 0.14, 0.95), hatch + Vector3(0, 0.07, 0), SURFACE, col.darkened(0.04))
	k.box(Vector3(0.78, 0.04, 0.78), hatch + Vector3(0, 0.16, 0), ARMY_PAINT, OLIVE.darkened(0.15))
	k.plate(Vector3(0.36, 0.03, 0.03), hatch + Vector3(0, 0.2, -0.24), "metal_dark", STEEL)
	for sx: float in [-1.0, 1.0]:
		k.plate(Vector3(0.03, 0.04, 0.03), hatch + Vector3(sx * 0.17, 0.18, -0.24), "metal_dark", STEEL)
		k.plate(Vector3(0.12, 0.05, 0.06), hatch + Vector3(sx * 0.24, 0.16, 0.41), "metal_dark", STEEL)
	# the observation cupola: a cast steel bell set in a concrete collar, its
	# vision slits round the front half, a periscope up through its crown
	var cup := Vector3(-0.8, y, -0.85)
	k.cyl(0.6, 0.66, 0.1, cup + Vector3(0, 0.05, 0), SURFACE, col.darkened(0.05), Vector3.ZERO, 16)
	k.cyl(0.46, 0.48, 0.26, cup + Vector3(0, 0.23, 0), ARMY_PAINT, OLIVE, Vector3.ZERO, 16)
	k.part(Res.dome(0.46, 16), ARMY_PAINT, Transform3D(Basis.from_scale(Vector3(1, 0.5, 1)), cup + Vector3(0, 0.36, 0)), OLIVE)
	for i in 5:
		var a := PI + (i - 2) * 0.62
		k.plate(Vector3(0.18, 0.045, 0.03), cup + Vector3(sin(a) * 0.465, 0.27, cos(a) * 0.465), "plain_dark", DARK, Vector3(0, a, 0))
	k.cyl(0.035, 0.035, 0.22, cup + Vector3(0.12, 0.6, 0.05), "metal_dark", STEEL)
	k.box(Vector3(0.09, 0.08, 0.13), cup + Vector3(0.12, 0.74, 0.03), "metal_dark", STEEL)
	# the vent: a mushroom cowl over the fresh-air shaft, turned a little
	var vent := Vector3(1.05, y, -0.85)
	k.cyl(0.1, 0.1, 0.42, vent + Vector3(0, 0.21, 0), "metal_dark", STEEL)
	k.cyl(0.04, 0.22, 0.12, vent + Vector3(0, 0.48, 0), "metal_dark", STEEL, Vector3(0, rng.randf() * TAU, 0))


## An embrasure, `k` on the wall's outer face at the ground (x along the wall,
## z out of it): round a slit `length` long from `sill` to `head` high, a hood
## over it with its top falling away from the wall, a sill sloped out and down
## (to drain, and to throw a round off downwards), cheeks splayed so the gunner
## can traverse, and steel angle cast into the slit's lips.
static func embrasure(k: BuildingKit, length: float, col: Color, sill := 1.1, head := 1.65) -> void:
	# The opening splays out from the slit through a frame EMBRASURE deep:
	# room for the gunner to traverse, and faces that turn a round striking
	# near the slit away from it rather than into it.
	var d := EMBRASURE
	var sp := d - 0.14  # how far the mouth opens past the slit on every side
	var band := 0.13  # the frame round the mouth
	var w := length + (sp + band) * 2.0
	# (a profile in z out and y up, run along the wall)
	var along := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	var hood := PackedVector2Array([Vector2(-0.04, head), Vector2(d, head + sp), Vector2(d, head + sp + 0.1), Vector2(-0.04, head + 0.44)])
	k.part(BuildingKit.extrusion("pillbox-hood|%.2f|%.2f" % [w, head], hood, w), SURFACE, Transform3D(along, Vector3.ZERO), col)
	var ledge := PackedVector2Array([Vector2(-0.04, sill), Vector2(d, sill - sp), Vector2(d, sill - sp - 0.1), Vector2(-0.04, sill - 0.42)])
	k.part(BuildingKit.extrusion("pillbox-sill|%.2f|%.2f" % [w, sill], ledge, w), SURFACE, Transform3D(along, Vector3.ZERO), col.darkened(0.04))
	for sx: float in [-1.0, 1.0]:
		var x0 := length * 0.5
		var cheek := PackedVector2Array([Vector2(sx * x0, -0.04), Vector2(sx * (x0 + sp + band), -0.04), Vector2(sx * (x0 + sp + band), d), Vector2(sx * (x0 + sp), d)])
		k.part(solid("cheek|%.2f|%.2f|%.2f|%d" % [length, sill, head, int(sx)], [[sill - sp - 0.05, cheek], [head + sp + 0.05, cheek]]), SURFACE, Transform3D.IDENTITY, col)
	for y: float in [sill, head]:
		k.plate(Vector3(length + 0.04, 0.05, 0.07), Vector3(0, y, 0.0), "metal_dark", STEEL)


## The doorway at the back, `k` on the wall's outer face (x along it): steel
## angle round the opening, `width` by `height`, and its two steel leaves
## standing open, folded back flat against the wall either side (so the way
## in is clear: the squads that garrison it come and go through here).
static func door(k: BuildingKit, width: float, height: float) -> void:
	for sx: float in [-1.0, 1.0]:
		k.plate(Vector3(0.07, height, 0.07), Vector3(sx * width * 0.5, height * 0.5, 0.0), "metal_dark", STEEL)
		BuildingOpenings.leaf(k.at_point(Vector3(sx * (width * 0.5 + 0.04), 0, 0.05)), Vector2(width * 0.5 - 0.04, height - 0.06), "steel", OLIVE, sx)
	k.plate(Vector3(width + 0.07, 0.07, 0.07), Vector3(0, height, 0.0), "metal_dark", STEEL)


## Step irons up the back wall to the roof, `k` on its outer face, at `x`.
static func step_irons(k: BuildingKit, x: float) -> void:
	for i in 5:
		var y := 0.45 + i * 0.36
		k.plate(Vector3(0.34, 0.025, 0.025), Vector3(x, y, 0.13), "metal_dark", STEEL)
		for sx: float in [-1.0, 1.0]:
			k.plate(Vector3(0.025, 0.025, 0.13), Vector3(x + sx * 0.16, y, 0.065), "metal_dark", STEEL)


## The years and the war on the walls, `k` at the bunker's middle: on each
## face the grime gathered under the slab's overhang (where the rain never
## washes it), a dark run here and there down from the drip edge and, at the
## back where no earth is banked, the splash at the foot and weeds; round the
## slits the strikes of the rounds that missed them. The faces are read off
## the wall `parts`, so nothing is laid over an opening.
static func weather(k: BuildingKit, parts: Array, col: Color, rng: RandomNumberGenerator) -> void:
	var tint := Mats.tint_for(SURFACE, col)
	var tone := func(_p: Vector2) -> Color: return tint
	var reach := HALF - CHAMFER
	for out: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var fk := k.on_face(out * HALF, out)
		var ax := Vector3.UP.cross(out)
		var rects: Array = []
		for p: Dictionary in parts:
			var c: Vector3 = p.p
			var s: Vector3 = p.s
			if c.y - s.y * 0.5 >= EAVE - 0.1 or not is_equal_approx(c.dot(out) + absf(s.dot(out)) * 0.5, HALF):
				continue
			var mid := c.dot(ax)
			var span := absf(s.dot(ax)) * 0.5
			var a := maxf(mid - span, -reach)
			var b := minf(mid + span, reach)
			rects.append(Rect2(a, c.y - s.y * 0.5, b - a, minf(s.y, EAVE - (c.y - s.y * 0.5))))
		var back := out == Vector3.BACK
		BuildingWeathering.grime(fk, reach * 2.0, EAVE, rects, SURFACE, tone, 0.75, rng, back, 0.3 if back else 0.95)
		if back:
			# weeds along the foot where no earth is banked, not in the doorway
			BuildingWeathering.weeds(fk, reach * 2.0, [Rect2(-1.0, 0.0, 2.0, 1.9)], rng)
	# strikes round the slits, thickest round the front one
	var raw := Color(0.68, 0.66, 0.62)
	BuildingWeathering.pocks(k.on_face(Vector3.FORWARD * HALF, Vector3.FORWARD), Vector2(0, 1.4), 2.4, rng.randi_range(7, 12), raw, rng, [Rect2(-1.8, 0.65, 3.6, 1.5)], reach)
	for sx: float in [-1.0, 1.0]:
		BuildingWeathering.pocks(k.on_face(Vector3(sx * HALF, 0, 0), Vector3(sx, 0, 0)), Vector2(0, 1.4), 1.8, rng.randi_range(2, 5), raw, rng, [Rect2(-1.4, 0.65, 2.8, 1.5)], reach)


## A square `half` across from the middle with its corners cut back `cut`
## along each side, in plan (x, z).
static func octagon(half: float, cut: float) -> PackedVector2Array:
	var h := half
	var e := half - cut
	return PackedVector2Array([Vector2(h, -e), Vector2(h, e), Vector2(e, h), Vector2(-e, h), Vector2(-h, e), Vector2(-h, -e), Vector2(-e, -h), Vector2(e, -h)])


## A solid lofted up through `rings` ([y, outline] from the bottom up: convex
## outlines in plan, x and z, with as many corners each), capped at both ends,
## every face flat so each arris catches the light. Cached by `key`.
static func solid(key: String, rings: Array) -> ArrayMesh:
	var m: ArrayMesh = _meshes.get(key)
	if m != null:
		return m
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var first: PackedVector2Array = rings[0][1]
	var count := first.size()
	var mid := Vector2.ZERO
	for q in first:
		mid += q
	mid /= count
	for r in rings.size() - 1:
		var y0: float = rings[r][0]
		var y1: float = rings[r + 1][0]
		var a: PackedVector2Array = rings[r][1]
		var b: PackedVector2Array = rings[r + 1][1]
		for i in count:
			var j := (i + 1) % count
			var p0 := Vector3(a[i].x, y0, a[i].y)
			var p1 := Vector3(a[j].x, y0, a[j].y)
			var p2 := Vector3(b[j].x, y1, b[j].y)
			var p3 := Vector3(b[i].x, y1, b[i].y)
			var side := (p1 - p0).cross(p3 - p0).normalized()
			if side.dot(Vector3((a[i].x + a[j].x) * 0.5 - mid.x, 0.0, (a[i].y + a[j].y) * 0.5 - mid.y)) < 0.0:
				side = -side
			BuildingKit._tri(v, n, p0, p1, p2, side)
			BuildingKit._tri(v, n, p0, p2, p3, side)
	for end: int in [0, rings.size() - 1]:
		var y: float = rings[end][0]
		var o: PackedVector2Array = rings[end][1]
		var c := Vector2.ZERO
		for q in o:
			c += q
		c /= count
		for i in count:
			var j := (i + 1) % count
			BuildingKit._tri(v, n, Vector3(c.x, y, c.y), Vector3(o[i].x, y, o[i].y), Vector3(o[j].x, y, o[j].y), Vector3.DOWN if end == 0 else Vector3.UP)
	m = BuildingKit._commit(v, n)
	_meshes[key] = m
	return m
