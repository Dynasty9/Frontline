class_name BuildingPlay
extends RefCounted
## A town playground's equipment, as councils put it up: heavy round steel
## tube painted bright and gone chalky, moulded panels in a second colour,
## galvanised chains and fittings, stainless chutes, rubber seats, timber
## kerbs. Each in a kit standing on the ground (y = 0).
##
## Kit like this is built to take years of children and the odd car, so its
## frames are thick (a swing's top beam is 114 mm tube, its legs 89 mm) and
## that is what still reads from a commander's height. Each piece is a few
## cached parts, one per colour and surface, built once a game in script
## (Geo) and tinted where it stands, so the playground costs a dozen parts a
## piece however much tube there is in it.

const STEEL := Color(0.66, 0.67, 0.66)  # galvanised fittings and chain
const STAINLESS := Color(0.86, 0.87, 0.88)  # a chute's polished bed
const RUBBER := Color(0.09, 0.09, 0.09)
const DECK := Color(0.2, 0.21, 0.21)  # a tower's anti-slip deck
const SAND := Color(0.84, 0.76, 0.56)
const DAMP_SAND := Color(0.77, 0.61, 0.4)  # turned out of a bucket: the same sand, a shade darker
## Panel colours councils buy their moulded boards in.
const PANELS := [Color(0.95, 0.74, 0.15), Color(0.2, 0.45, 0.8), Color(0.25, 0.62, 0.32), Color(0.82, 0.22, 0.15)]

static var _made := {}


## The triangles of one cached part, gathered in script (no read-back from
## the renderer), with smooth normals round tube.
class Geo:
	var v := PackedVector3Array()
	var n := PackedVector3Array()

	## A triangle, wound the way Godot draws front faces whichever way it
	## came, each corner with its own normal.
	func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
		if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
			v.append_array([a, c, b])
			n.append_array([na, nc, nb])
		else:
			v.append_array([a, b, c])
			n.append_array([na, nb, nc])

	## A flat quad a-b-c-d facing `normal`.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
		tri(a, b, c, normal, normal, normal)
		tri(a, c, d, normal, normal, normal)

	## A round tube along `points`, `sides` round, its frame carried along
	## so it doesn't twist; a closed ring when `loop`, its ends capped when
	## `caps`.
	func pipe(points: PackedVector3Array, r: float, sides := 8, loop := false, caps := false) -> void:
		var count := points.size()
		if count < 2:
			return
		var ref := Vector3.UP
		if absf((points[1] - points[0]).normalized().dot(ref)) > 0.9:
			ref = Vector3.RIGHT
		var rings: Array[PackedVector3Array] = []
		var tangents := PackedVector3Array()
		for i in count:
			var prev := points[(i - 1 + count) % count] if loop else points[maxi(i - 1, 0)]
			var next := points[(i + 1) % count] if loop else points[mini(i + 1, count - 1)]
			var t := (next - prev).normalized()
			var x := ref.cross(t)
			if x.length_squared() < 0.000001:
				x = Vector3.BACK.cross(t)
			x = x.normalized()
			var y := t.cross(x)
			ref = y
			var ring := PackedVector3Array()
			for s in sides:
				var a := TAU * s / sides
				ring.append(x * cos(a) + y * sin(a))
			rings.append(ring)
			tangents.append(t)
		for i in (count if loop else count - 1):
			var j := (i + 1) % count
			for s in sides:
				var s2 := (s + 1) % sides
				var a0 := rings[i][s]
				var a1 := rings[i][s2]
				var b0 := rings[j][s]
				var b1 := rings[j][s2]
				tri(points[i] + a0 * r, points[j] + b0 * r, points[j] + b1 * r, a0, b0, b1)
				tri(points[i] + a0 * r, points[j] + b1 * r, points[i] + a1 * r, a0, b1, a1)
		if caps and not loop:
			for end: int in [0, count - 1]:
				var out := -tangents[0] if end == 0 else tangents[count - 1]
				for s in sides:
					var s2 := (s + 1) % sides
					tri(points[end], points[end] + rings[end][s] * r, points[end] + rings[end][s2] * r, out, out, out)

	## A straight tube from `a` to `b`.
	func rod(a: Vector3, b: Vector3, r: float, sides := 8, caps := true) -> void:
		pipe(PackedVector3Array([a, b]), r, sides, false, caps)

	## A box `size` centred on `p`, turned by `basis`.
	func box(p: Vector3, size: Vector3, basis := Basis.IDENTITY) -> void:
		var h := size * 0.5
		for axis in 3:
			for sgn: float in [-1.0, 1.0]:
				var nrm := Vector3.ZERO
				nrm[axis] = sgn
				var u := Vector3.ZERO
				u[(axis + 1) % 3] = 1.0
				var w := Vector3.ZERO
				w[(axis + 2) % 3] = 1.0
				var c := nrm * h
				var du := u * h
				var dw := w * h
				var nn := basis * nrm
				quad(p + basis * (c - du - dw), p + basis * (c + du - dw), p + basis * (c + du + dw), p + basis * (c - du + dw), nn.normalized())

	## A slab `depth` thick over the flat convex `outline` (its corners in
	## order, all in one plane), centred on it.
	func slab(outline: PackedVector3Array, depth: float) -> void:
		var count := outline.size()
		var nrm := (outline[1] - outline[0]).cross(outline[2] - outline[0]).normalized()
		var off := nrm * depth * 0.5
		var mid := Vector3.ZERO
		for p in outline:
			mid += p
		mid /= count
		for i in count:
			var a := outline[i]
			var b := outline[(i + 1) % count]
			tri(mid + off, a + off, b + off, nrm, nrm, nrm)
			tri(mid - off, a - off, b - off, -nrm, -nrm, -nrm)
			var side := (b - a).cross(nrm).normalized()
			if side.dot(a - mid) < 0.0:
				side = -side
			quad(a + off, b + off, b - off, a - off, side)

	## A ball (a hub, an end cap).
	func ball(p: Vector3, r: float, segs := 8) -> void:
		var rows := maxi(3, segs >> 1)
		for i in rows:
			var t0 := PI * i / rows
			var t1 := PI * (i + 1) / rows
			for s in segs:
				var a0 := TAU * s / segs
				var a1 := TAU * (s + 1) / segs
				var d00 := Vector3(sin(t0) * cos(a0), cos(t0), sin(t0) * sin(a0))
				var d01 := Vector3(sin(t0) * cos(a1), cos(t0), sin(t0) * sin(a1))
				var d10 := Vector3(sin(t1) * cos(a0), cos(t1), sin(t1) * sin(a0))
				var d11 := Vector3(sin(t1) * cos(a1), cos(t1), sin(t1) * sin(a1))
				if i > 0:
					tri(p + d00 * r, p + d01 * r, p + d11 * r, d00, d01, d11)
				if i < rows - 1:
					tri(p + d00 * r, p + d11 * r, p + d10 * r, d00, d11, d10)

	## The closed cross-section `section` (z across, h up off the path)
	## swept along `path` in the xy plane: a chute, its sides. Smooth along
	## the path, flat across it, its ends closed.
	func sweep(path: PackedVector2Array, section: PackedVector2Array) -> void:
		var count := path.size()
		var ups: Array[Vector2] = []
		for i in count:
			var t := (path[mini(i + 1, count - 1)] - path[maxi(i - 1, 0)]).normalized()
			ups.append(Vector2(-t.y, t.x))
		var centre := Vector2.ZERO
		for q in section:
			centre += q
		centre /= section.size()
		var at := func(i: int, q: Vector2) -> Vector3:
			var p := path[i] + ups[i] * q.y
			return Vector3(p.x, p.y, q.x)
		for e in section.size():
			var qa := section[e]
			var qb := section[(e + 1) % section.size()]
			var en := Vector2(qb.y - qa.y, qa.x - qb.x).normalized()
			if en.dot((qa + qb) * 0.5 - centre) < 0.0:
				en = -en
			for i in count - 1:
				var n0 := Vector3(ups[i].x * en.y, ups[i].y * en.y, en.x)
				var n1 := Vector3(ups[i + 1].x * en.y, ups[i + 1].y * en.y, en.x)
				var p0: Vector3 = at.call(i, qa)
				var p1: Vector3 = at.call(i + 1, qa)
				var p2: Vector3 = at.call(i + 1, qb)
				var p3: Vector3 = at.call(i, qb)
				tri(p0, p1, p2, n0, n1, n1)
				tri(p0, p2, p3, n0, n1, n0)
		for end: int in [0, count - 1]:
			var dir := (path[mini(end + 1, count - 1)] - path[maxi(end - 1, 0)]).normalized() * (1.0 if end > 0 else -1.0)
			var out := Vector3(dir.x, dir.y, 0.0)
			var c3: Vector3 = at.call(end, centre)
			for e in section.size():
				tri(c3, at.call(end, section[e]), at.call(end, section[(e + 1) % section.size()]), out, out, out)

	func mesh() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		Mats.keep_arrays(m, arrays)
		return m


## One cached part: `build` fills a Geo the first time `key` is asked for.
static func _part(key: String, build: Callable) -> ArrayMesh:
	var m: ArrayMesh = _made.get(key)
	if m == null:
		var g := Geo.new()
		build.call(g)
		m = g.mesh()
		_made[key] = m
	return m


## The corners of a run of tube with each inner corner bent round (a bend
## about `bend` long either side of it, in `steps`), as a tube bender
## leaves it.
static func _bent(corners: Array, bend: float, steps := 4) -> PackedVector3Array:
	var out := PackedVector3Array([corners[0]])
	for i in range(1, corners.size() - 1):
		var p: Vector3 = corners[i]
		var a: Vector3 = corners[i - 1]
		var b: Vector3 = corners[i + 1]
		var t := minf(bend, minf(p.distance_to(a), p.distance_to(b)) * 0.5)
		var p0 := p + (a - p).normalized() * t
		var p1 := p + (b - p).normalized() * t
		for s in steps + 1:
			var f := float(s) / steps
			out.append(p0.lerp(p, f).lerp(p.lerp(p1, f), f))
	out.append(corners[corners.size() - 1])
	return out


## A chain hanging from `a` to `b`: links turned by turns, each a flat oval
## of wire seen as a narrow bar.
static func _chain(g: Geo, a: Vector3, b: Vector3) -> void:
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var count := maxi(2, roundi(length / 0.055))
	var step := length / count
	var base := BuildingKit.aim(dir)
	for i in count:
		var turn := Basis(dir, PI * 0.5 * (i & 1))
		g.box(a + dir * (step * (i + 0.5)), Vector3(0.017, step + 0.014, 0.006), turn * base)


# --- swings ---------------------------------------------------------------------------

## A swing frame 3.6 m along x: an A-frame of 89 mm tube at each end under a
## 114 mm top beam 2.4 m up, two seats on galvanised chains (one a toddler's
## cradle seat, `cradle`), the surfacing worn through to its black base
## under each where feet drag.
static func swings(k: BuildingKit, col: Color, cradle: bool) -> void:
	var top := 2.4
	k.part(_part("play_swing_frame", func(g: Geo) -> void:
		g.rod(Vector3(-1.79, top, 0), Vector3(1.79, top, 0), 0.057, 12)
		for sx: float in [-1.68, 1.68]:
			for sz: float in [-0.84, 0.84]:
				g.rod(Vector3(sx, -0.03, sz), Vector3(sx, top - 0.04, sz * 0.04), 0.045, 10, false)
			# the cast clamp the legs and the beam meet in
			g.box(Vector3(sx, top - 0.05, 0), Vector3(0.13, 0.24, 0.17))
			g.ball(Vector3(signf(sx) * 1.79, top, 0), 0.059, 10)), "paint", Transform3D.IDENTITY, col)
	var seats: Array[float] = [-0.8, 0.8]
	k.part(_part("play_swing_fittings|%s" % cradle, func(g: Geo) -> void:
		for i in 2:
			var x := seats[i]
			for dx: float in [-0.23, 0.23]:
				# a bearing hanger on a strap round the beam
				g.box(Vector3(x + dx, top - 0.085, 0), Vector3(0.06, 0.08, 0.075))
				g.box(Vector3(x + dx, top, 0), Vector3(0.04, 0.13, 0.13))
				if cradle and i == 1:
					_chain(g, Vector3(x + dx, top - 0.13, 0), Vector3(x + dx * 0.75, 0.98, 0))
					g.ball(Vector3(x + dx * 0.75, 0.97, 0), 0.016, 6)
					for dz: float in [-0.12, 0.12]:
						_chain(g, Vector3(x + dx * 0.75, 0.96, 0), Vector3(x + dx * 0.75, 0.78, dz))
				else:
					_chain(g, Vector3(x + dx, top - 0.13, 0), Vector3(x + dx * 0.93, 0.5, 0))
					# the seat's clamp
					g.box(Vector3(x + dx * 0.93, 0.47, 0), Vector3(0.05, 0.07, 0.19))), "galvanised", Transform3D.IDENTITY, STEEL, false)
	k.part(_part("play_swing_seats|%s" % cradle, func(g: Geo) -> void:
		for i in 2:
			var x := seats[i]
			if cradle and i == 1:
				# a cradle seat: a rubber bucket, its front cut away round two
				# leg holes either side of a middle bar
				g.box(Vector3(x, 0.6, 0), Vector3(0.38, 0.05, 0.3))
				g.box(Vector3(x, 0.71, -0.13), Vector3(0.38, 0.27, 0.05))
				for sx: float in [-0.165, 0.165]:
					g.box(Vector3(x + sx, 0.69, 0), Vector3(0.05, 0.23, 0.3))
				g.box(Vector3(x, 0.66, 0.13), Vector3(0.09, 0.13, 0.05))
				g.box(Vector3(x, 0.78, 0.13), Vector3(0.38, 0.06, 0.05))
			else:
				# a flat seat, sagging a little in the middle
				g.box(Vector3(x, 0.455, 0), Vector3(0.24, 0.045, 0.17))
				for sx: float in [-1.0, 1.0]:
					g.box(Vector3(x + sx * 0.16, 0.465, 0), Vector3(0.14, 0.045, 0.17), Basis(Vector3.BACK, sx * 0.12))), "rubber", Transform3D.IDENTITY, RUBBER)


# --- slide ----------------------------------------------------------------------------

## A tower slide running down along +x: a tower of four posts with a deck
## 1.2 m up, moulded side panels and a pitched roof, a ladder up its back
## (-x) with hand loops at the top, a bar over the chute to make children sit,
## and a stainless chute in coloured sides falling at 36 degrees to its
## run-out. `col` is the steel, `roof` the moulded panels and roof.
static func slide(k: BuildingKit, col: Color, roof: Color) -> void:
	var deck := 1.2
	var tx := -0.45
	var hp := 0.5
	var path := _chute_path(tx + hp, deck)
	k.part(_part("play_slide_frame", func(g: Geo) -> void:
		for sx: float in [-hp, hp]:
			for sz: float in [-hp, hp]:
				g.rod(Vector3(tx + sx, -0.04, sz), Vector3(tx + sx, 2.52, sz), 0.045, 10)
			# rails between the posts under the deck and under the roof
			g.rod(Vector3(tx + sx, 0.35, -hp), Vector3(tx + sx, 0.35, hp), 0.03, 8, false)
			g.rod(Vector3(tx + sx, 2.46, -hp), Vector3(tx + sx, 2.46, hp), 0.03, 8, false)
		for sz: float in [-hp, hp]:
			g.rod(Vector3(tx - hp, deck - 0.06, sz), Vector3(tx + hp, deck - 0.06, sz), 0.03, 8, false)
		# the sit-down bar over the chute
		g.rod(Vector3(tx + hp, deck + 0.74, -hp), Vector3(tx + hp, deck + 0.74, hp), 0.03, 8, false)
		# the back's guard either side of the ladder
		for sz: float in [-1.0, 1.0]:
			for y: float in [deck + 0.35, deck + 0.7]:
				g.rod(Vector3(tx - hp, y, sz * hp), Vector3(tx - hp, y, sz * 0.27), 0.022, 8, false)
		# the ladder's stiles, carried up past the deck into hand loops
		var foot := Vector3(tx - hp - 0.62, 0.0, 0)
		for sz: float in [-0.25, 0.25]:
			g.pipe(_bent([foot + Vector3(-0.01, -0.02, sz), Vector3(tx - hp, deck, sz), Vector3(tx - hp + 0.08, deck + 0.68, sz),
				Vector3(tx - hp + 0.34, deck + 0.68, sz), Vector3(tx - hp + 0.36, deck, sz)], 0.12, 4), 0.026, 8)
		# the chute's legs, halfway down the slope and under the run-out
		var mid_slope := (path[7] + path[8]) * 0.5
		for p: Vector2 in [mid_slope, path[path.size() - 1]]:
			for sz: float in [-0.19, 0.19]:
				g.rod(Vector3(p.x - 0.12, -0.04, sz), Vector3(p.x - 0.12, p.y - 0.06, sz), 0.03, 8, false)
			g.rod(Vector3(p.x - 0.12, p.y - 0.08, -0.19), Vector3(p.x - 0.12, p.y - 0.08, 0.19), 0.025, 8, false)
		# a porthole's ring on each side panel
		for sz: float in [-1.0, 1.0]:
			var ring := PackedVector3Array()
			for i in 16:
				var a := TAU * i / 16.0
				ring.append(Vector3(tx + cos(a) * 0.17, deck + 0.42 + sin(a) * 0.17, sz * (hp + 0.03)))
			g.pipe(ring, 0.022, 6, true)
		g.rod(Vector3(tx - hp - 0.08, 2.86, 0), Vector3(tx + hp + 0.08, 2.86, 0), 0.04, 8)), "paint", Transform3D.IDENTITY, col)
	k.part(_part("play_slide_panels", func(g: Geo) -> void:
		for sz: float in [-1.0, 1.0]:
			g.box(Vector3(tx, deck + 0.42, sz * hp), Vector3(2.0 * hp - 0.09, 0.78, 0.03))
			# the front's guard either side of the chute
			g.box(Vector3(tx + hp, deck + 0.36, sz * 0.385), Vector3(0.03, 0.66, 0.2))
			# the roof, pitched to its ridge along x
			var eave := Vector3(0, 2.48, sz * 0.68)
			var ridge := Vector3(0, 2.86, 0)
			var mid := (eave + ridge) * 0.5
			var slope := atan2(ridge.y - eave.y, absf(eave.z))
			g.box(Vector3(tx, mid.y, mid.z), Vector3(2.0 * hp + 0.24, 0.035, eave.distance_to(ridge) + 0.02), Basis(Vector3.RIGHT, slope * sz))), "plain", Transform3D.IDENTITY, roof)
	k.box(Vector3(2.0 * hp + 0.04, 0.06, 2.0 * hp + 0.04), Vector3(tx, deck - 0.03, 0), "metal_dark", DECK)
	k.part(_part("play_slide_rungs", func(g: Geo) -> void:
		var foot := Vector3(tx - hp - 0.62, 0.0, 0)
		for i in 4:
			var p := foot.lerp(Vector3(tx - hp, deck, 0), (i + 1) / 5.0)
			g.rod(p + Vector3(0, 0, -0.25), p + Vector3(0, 0, 0.25), 0.018, 6, false)), "galvanised", Transform3D.IDENTITY, STEEL, false)
	k.part(_part("play_slide_chute", func(g: Geo) -> void:
		g.sweep(path, PackedVector2Array([Vector2(-0.245, -0.014), Vector2(0.245, -0.014), Vector2(0.245, 0.0), Vector2(-0.245, 0.0)]))), "galvanised", Transform3D.IDENTITY, STAINLESS)
	k.part(_part("play_slide_sides", func(g: Geo) -> void:
		for sz: float in [-1.0, 1.0]:
			g.sweep(path, PackedVector2Array([Vector2(sz * 0.245, -0.06), Vector2(sz * 0.28, -0.06), Vector2(sz * 0.28, 0.17), Vector2(sz * 0.245, 0.17)]))
			var lip := PackedVector3Array()
			for i in path.size():
				var t := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
				var p := path[i] + Vector2(-t.y, t.x) * 0.17
				lip.append(Vector3(p.x, p.y, sz * 0.2625))
			g.pipe(lip, 0.024, 8, false, true)), "paint", Transform3D.IDENTITY, col)


## Where a chute's bed runs (x, y) from the deck's edge at `x0`, `deck` up:
## a short flat to sit on, the drop at 36 degrees, the run-out nearly level
## a hand's height off the ground, the bends between rounded.
static func _chute_path(x0: float, deck: float) -> PackedVector2Array:
	var drop := deck - 0.33
	var run := drop / tan(deg_to_rad(36.0))
	var corners := [Vector3(x0, deck + 0.02, 0), Vector3(x0 + 0.3, deck + 0.02, 0), Vector3(x0 + 0.3 + run, 0.33, 0), Vector3(x0 + 0.3 + run + 0.52, 0.29, 0)]
	var out := PackedVector2Array()
	for p in _bent(corners, 0.3, 6):
		out.append(Vector2(p.x, p.y))
	return out


# --- climbing dome --------------------------------------------------------------------

## A climbing dome: a geodesic of 48 mm tube on a circle 2.3 m across, its
## joints in cast hubs, a few of its triangles filled with moulded panels
## to climb on (in a colour from the kit's generator).
static func climber(k: BuildingKit, col: Color) -> void:
	var r := 1.12
	var tall := 1.22
	var net := _geodesic()
	var verts: PackedVector3Array = net[0]
	var edges: Array = net[1]
	var faces: Array = net[2]
	k.part(_part("play_dome_frame", func(g: Geo) -> void:
		for e: Vector2i in edges:
			g.rod(_dome_at(verts[e.x], r, tall), _dome_at(verts[e.y], r, tall), 0.025, 8, false)
		for p in verts:
			g.ball(_dome_at(p, r, tall), 0.042, 8)), "paint", Transform3D.IDENTITY, col)
	var panel: Color = PANELS[k.rng.randi() % PANELS.size()]
	if Vector3(panel.r - col.r, panel.g - col.g, panel.b - col.b).length() < 0.3:
		panel = PANELS[(PANELS.find(panel) + 1) % PANELS.size()]
	k.part(_part("play_dome_panels", func(g: Geo) -> void:
		for i in faces.size():
			if i % 5 != 2:
				continue
			var f: Vector3i = faces[i]
			var a := _dome_at(verts[f.x], r, tall)
			var b := _dome_at(verts[f.y], r, tall)
			var c := _dome_at(verts[f.z], r, tall)
			var mid := (a + b + c) / 3.0
			g.slab(PackedVector3Array([mid.lerp(a, 0.78), mid.lerp(b, 0.78), mid.lerp(c, 0.78)]), 0.025)), "plain", Transform3D.IDENTITY, panel)


static func _dome_at(u: Vector3, r: float, tall: float) -> Vector3:
	return Vector3(u.x * r, u.y * tall, u.z * r)


## A geodesic hemisphere (a twice-divided icosahedron, a vertex at the top,
## cut at its equator) on the unit sphere: [vertices, edges, faces].
static func _geodesic() -> Array:
	var cached: Variant = _made.get("geodesic")
	if cached != null:
		return cached
	var g := (1.0 + sqrt(5.0)) * 0.5
	var ico := [Vector3(-1, g, 0), Vector3(1, g, 0), Vector3(-1, -g, 0), Vector3(1, -g, 0), Vector3(0, -1, g), Vector3(0, 1, g),
		Vector3(0, -1, -g), Vector3(0, 1, -g), Vector3(g, 0, -1), Vector3(g, 0, 1), Vector3(-g, 0, -1), Vector3(-g, 0, 1)]
	var tris := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	# (turned so a vertex is at the top: then the midpoints between the two
	# rings of five lie on the equator, and the cut is clean)
	var up := Basis(Quaternion((ico[0] as Vector3).normalized(), Vector3.UP))
	var pts := PackedVector3Array()
	for p: Vector3 in ico:
		pts.append(up * p.normalized())
	var mids := {}
	var fine: Array[Vector3i] = []
	for t: Array in tris:
		var m := []
		for e in 3:
			var a: int = t[e]
			var b: int = t[(e + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not mids.has(key):
				mids[key] = pts.size()
				pts.append(((pts[a] + pts[b]) * 0.5).normalized())
			m.append(mids[key])
		fine.append(Vector3i(t[0], m[0], m[2]))
		fine.append(Vector3i(t[1], m[1], m[0]))
		fine.append(Vector3i(t[2], m[2], m[1]))
		fine.append(Vector3i(m[0], m[1], m[2]))
	var keep: Array[Vector3i] = []
	for f in fine:
		if pts[f.x].y > -0.01 and pts[f.y].y > -0.01 and pts[f.z].y > -0.01:
			keep.append(f)
	# renumber the kept vertices, and list each edge once
	var index := {}
	var verts := PackedVector3Array()
	var faces: Array[Vector3i] = []
	var seen := {}
	var edges: Array[Vector2i] = []
	for f in keep:
		var ids := Vector3i.ZERO
		for c in 3:
			var old: int = f[c]
			if not index.has(old):
				index[old] = verts.size()
				var p := pts[old]
				verts.append(Vector3(p.x, maxf(p.y, 0.0), p.z))
			ids[c] = index[old]
		faces.append(ids)
		for c in 3:
			var key := Vector2i(mini(ids[c], ids[(c + 1) % 3]), maxi(ids[c], ids[(c + 1) % 3]))
			if not seen.has(key):
				seen[key] = true
				edges.append(key)
	var out := [verts, edges, faces]
	_made["geodesic"] = out
	return out


# --- seesaw ---------------------------------------------------------------------------

## A seesaw along x: a beam of box-section steel on a pivot frame, a moulded
## seat and a hoop handle at each end, and under each seat a tyre half sunk
## in the ground for that end to come down on. It rests with its -x end down.
static func seesaw(k: BuildingKit, col: Color) -> void:
	var seat_x := 1.38
	var pivot := 0.6
	var tyre := 0.28
	# (the low end's beam lies on its tyre)
	var tilt := atan2(pivot - (tyre + 0.05), seat_x)
	k.part(_part("play_seesaw_pivot", func(g: Geo) -> void:
		g.box(Vector3(0, 0.0, 0), Vector3(0.5, 0.08, 0.42))
		for sz: float in [-0.13, 0.13]:
			for sx: float in [-0.24, 0.24]:
				g.rod(Vector3(sx, -0.02, sz), Vector3(0, pivot - 0.04, sz), 0.035, 8, false)
		g.rod(Vector3(0, pivot - 0.04, -0.17), Vector3(0, pivot - 0.04, 0.17), 0.055, 10)), "metal_dark", Transform3D.IDENTITY, Color(0.24, 0.25, 0.26))
	var beam := k.at_point(Vector3(0, pivot, 0), Vector3(0, 0, tilt))
	beam.box(Vector3(3.2, 0.1, 0.2), Vector3.ZERO, "paint", col)
	beam.part(_part("play_seesaw_handles", func(g: Geo) -> void:
		for sx: float in [-1.0, 1.0]:
			var x := sx * (seat_x - 0.3)
			g.pipe(_bent([Vector3(x, 0.03, -0.12), Vector3(x, 0.34, -0.12), Vector3(x, 0.34, 0.12), Vector3(x, 0.03, 0.12)], 0.07, 4), 0.019, 8)
		# the bearing block the beam turns in
		g.box(Vector3(0, -0.07, 0), Vector3(0.22, 0.06, 0.24))), "galvanised", Transform3D.IDENTITY, STEEL)
	beam.part(_part("play_seesaw_seats", func(g: Geo) -> void:
		for sx: float in [-1.0, 1.0]:
			g.box(Vector3(sx * seat_x, 0.085, 0), Vector3(0.34, 0.07, 0.3))
			g.box(Vector3(sx * (seat_x + 0.15), 0.17, 0), Vector3(0.05, 0.16, 0.3))), "rubber", Transform3D.IDENTITY, RUBBER)
	k.part(_part("play_seesaw_tyres", func(g: Geo) -> void:
		# (only what shows above the ground: an arch of tread, its section
		# a car tyre's, wider than it is deep)
		var section := PackedVector2Array([Vector2(0.095, -0.03), Vector2(0.095, 0.03), Vector2(0.07, 0.055), Vector2(-0.07, 0.055),
			Vector2(-0.095, 0.03), Vector2(-0.095, -0.03), Vector2(-0.07, -0.055), Vector2(0.07, -0.055)])
		for sx: float in [-1.0, 1.0]:
			var arc := PackedVector2Array()
			for i in 17:
				var a := lerpf(-0.08, PI + 0.08, i / 16.0)
				arc.append(Vector2(sx * seat_x + cos(a) * (tyre - 0.055), sin(a) * (tyre - 0.055)))
			g.sweep(arc, section)), "rubber", Transform3D.IDENTITY, RUBBER)


# --- sandpit --------------------------------------------------------------------------

## A sandpit 2.8 m square: kerbs of timber sleepers with a seat board round
## them and a corner seat across each corner, the sand raked about and dug
## (one of a few ways, from the kit's generator), a castle or two turned out
## of the bucket, and the bucket and spade left in it.
static func sandpit(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	k.part(_part("play_sandpit_frame", func(g: Geo) -> void:
		for side in 4:
			var b := Basis(Vector3.UP, side * PI * 0.5)
			g.box(b * Vector3(0, 0.12, 1.34), Vector3(2.8, 0.24, 0.12), b)
			g.box(b * Vector3(-0.07, 0.258, 1.26), Vector3(2.66, 0.036, 0.28), b)
			# a corner seat across the corner
			g.slab(PackedVector3Array([b * Vector3(1.12, 0.262, 1.12), b * Vector3(0.62, 0.262, 1.12), b * Vector3(1.12, 0.262, 0.62)]), 0.034)), "wood", Transform3D.IDENTITY, Color(0.5, 0.38, 0.25))
	var layout := rng.randi() % 4
	k.part(_part("play_sand|%d" % layout, func(g: Geo) -> void:
		_sand(g, layout)), "earth", Transform3D.IDENTITY, SAND)
	var spots := _sand_spots(layout)
	for i in spots.size() - 1:
		var p: Vector3 = spots[i]
		p.y = _sand_y(layout, p.x, p.z)
		k.cyl(0.075, 0.1, 0.13, p + Vector3(0, 0.055, 0), "earth", DAMP_SAND, Vector3.ZERO, 10, false)
		k.cyl(0.04, 0.055, 0.06, p + Vector3(0, 0.14, 0), "earth", DAMP_SAND, Vector3.ZERO, 8, false)
	var toy: Color = [Color(0.85, 0.2, 0.15), Color(0.2, 0.45, 0.8), Color(0.95, 0.75, 0.15), Color(0.3, 0.65, 0.3)][rng.randi() % 4]
	var bp: Vector3 = spots[spots.size() - 1]
	bp.y = _sand_y(layout, bp.x, bp.z)
	# the bucket, on its side, and its spade stuck in the sand by it
	k.cyl(0.085, 0.065, 0.15, bp + Vector3(0, 0.08, 0), "paint", toy, Vector3(0, rng.randf() * TAU, PI * 0.5), 10, false)
	var sp := bp + Vector3(0.28, 0, 0.12)
	sp.y = _sand_y(layout, sp.x, sp.z)
	k.box(Vector3(0.11, 0.13, 0.012), sp + Vector3(0, 0.03, 0), "paint", toy.darkened(0.25), Vector3(0.35, 0.5, 0), false)
	k.cyl(0.012, 0.012, 0.3, sp + Vector3(-0.05, 0.22, 0.03), "paint", toy.darkened(0.25), Vector3(0.35, 0.5, 0), 6, false)


## Where the castles stand in a layout, and (last) where the bucket lies.
static func _sand_spots(layout: int) -> Array:
	return [[Vector3(0.45, 0, -0.35), Vector3(0.62, 0, -0.1), Vector3(-0.5, 0, 0.55)],
		[Vector3(-0.4, 0, -0.5), Vector3(0.55, 0, 0.45)],
		[Vector3(0.1, 0, 0.6), Vector3(-0.55, 0, -0.3)],
		[Vector3(-0.6, 0, 0.1), Vector3(-0.35, 0, 0.3), Vector3(0.5, 0, -0.55)]][layout]


## The sand's height at (x, z) in a layout: raked level a hand under the
## seat boards, kicked up into the corners, a heap where a hole was dug.
static func _sand_y(layout: int, x: float, z: float) -> float:
	var h := 0.16 + 0.012 * sin(x * 3.1 + layout) * cos(z * 2.7 - layout)
	# kicked against the kerbs
	h += 0.03 * maxf(0.0, maxf(absf(x), absf(z)) - 0.9)
	var digs: Array = [[Vector2(-0.3, 0.2), Vector2(0.25, 0.5)], [Vector2(0.4, -0.2), Vector2(-0.1, 0.25)],
		[Vector2(-0.4, 0.35), Vector2(0.45, -0.4)], [Vector2(0.35, 0.4), Vector2(0.4, -0.1)]][layout]
	var hole: Vector2 = digs[0]
	var heap: Vector2 = digs[1]
	h -= 0.1 * exp(-Vector2(x, z).distance_squared_to(hole) / 0.05)
	h += 0.12 * exp(-Vector2(x, z).distance_squared_to(heap) / 0.08)
	return h


## The sand: a grid inside the kerbs shaped by _sand_y, its normals smooth.
static func _sand(g: Geo, layout: int) -> void:
	var cells := 14
	var half := 1.28
	var step := half * 2.0 / cells
	var at := func(i: int, j: int) -> Vector3:
		var x := -half + i * step
		var z := -half + j * step
		return Vector3(x, _sand_y(layout, x, z), z)
	var normal := func(i: int, j: int) -> Vector3:
		var x := -half + i * step
		var z := -half + j * step
		var e := 0.02
		return Vector3(_sand_y(layout, x - e, z) - _sand_y(layout, x + e, z), 2.0 * e, _sand_y(layout, x, z - e) - _sand_y(layout, x, z + e)).normalized()
	for i in cells:
		for j in cells:
			var a: Vector3 = at.call(i, j)
			var b: Vector3 = at.call(i + 1, j)
			var c: Vector3 = at.call(i + 1, j + 1)
			var d: Vector3 = at.call(i, j + 1)
			g.tri(a, b, c, normal.call(i, j), normal.call(i + 1, j), normal.call(i + 1, j + 1))
			g.tri(a, c, d, normal.call(i, j), normal.call(i + 1, j + 1), normal.call(i, j + 1))


# --- roundabout -----------------------------------------------------------------------

## A roundabout: a disc 1.9 m across a hand's height off the ground on its
## bearing, its deck in segments of two colours (`cols`) inside a galvanised
## rim, a skirt under it so no foot goes beneath, and the grab rails: six
## arms out from the hub, each bent down to the deck, tied by a ring.
static func roundabout(k: BuildingKit, cols: Array) -> void:
	var deck := 0.25
	k.cyl(0.2, 0.24, 0.16, Vector3(0, 0.08, 0), "metal_dark", Color(0.18, 0.18, 0.18), Vector3.ZERO, 10, false)
	k.cyl(0.95, 0.86, 0.15, Vector3(0, deck - 0.1, 0), "galvanised", STEEL.darkened(0.15), Vector3.ZERO, 28)
	for half in 2:
		k.part(_part("play_disc|%d" % half, func(g: Geo) -> void:
			for s in 6:
				if s % 2 != half:
					continue
				var a0 := TAU * s / 6.0
				var a1 := TAU * (s + 1) / 6.0
				var outline := PackedVector3Array([Vector3(0, deck, 0)])
				for i in 7:
					var a := lerpf(a0, a1, i / 6.0)
					outline.append(Vector3(cos(a) * 0.93, deck, sin(a) * 0.93))
				g.slab(outline, 0.03)), "plain", Transform3D.IDENTITY, cols[half % cols.size()])
	k.part(_part("play_disc_rails", func(g: Geo) -> void:
		# the hub, the arms and the ring
		g.rod(Vector3(0, deck, 0), Vector3(0, deck + 0.7, 0), 0.06, 10, false)
		g.ball(Vector3(0, deck + 0.7, 0), 0.075, 10)
		var ring := PackedVector3Array()
		for i in 30:
			var a := TAU * i / 30.0
			ring.append(Vector3(cos(a) * 0.74, deck + 0.42, sin(a) * 0.74))
		g.pipe(ring, 0.02, 8, true)
		for i in 6:
			var a := TAU * (i + 0.5) / 6.0
			var out := Vector3(cos(a), 0, sin(a))
			g.pipe(_bent([Vector3(0, deck + 0.66, 0), out * 0.62 + Vector3(0, deck + 0.66, 0), out * 0.74 + Vector3(0, deck + 0.5, 0), out * 0.74 + Vector3(0, deck, 0)], 0.1, 5), 0.021, 8)
			# the steel strip along each joint between the segments
			var b := TAU * i / 6.0
			g.box(Vector3(cos(b) * 0.47, deck + 0.017, sin(b) * 0.47), Vector3(0.9, 0.006, 0.05), Basis(Vector3.UP, -b))
		var rim := PackedVector3Array()
		for i in 40:
			var a := TAU * i / 40.0
			rim.append(Vector3(cos(a) * 0.94, deck, sin(a) * 0.94))
		g.pipe(rim, 0.025, 6, true)), "galvanised", Transform3D.IDENTITY, STEEL)


# --- spring riders --------------------------------------------------------------------

## A spring rider facing +x: an animal cut from thick moulded board (a horse
## when `variant` is even, a duck when odd) on a heavy coil spring bolted to
## a plate in the ground, a saddle, handles through its neck and foot rests
## through its body. Its colours from `rng`.
static func spring_rider(k: BuildingKit, variant: int, rng: RandomNumberGenerator) -> void:
	var duck := variant % 2 == 1
	var body: Color = Color(0.95, 0.78, 0.15) if duck else PANELS[rng.randi() % PANELS.size()]
	var coil: Color = [Color(0.82, 0.22, 0.15), Color(0.2, 0.45, 0.8), Color(0.25, 0.62, 0.32)][rng.randi() % 3]
	k.part(_part("play_rider_duck" if duck else "play_rider_horse", func(g: Geo) -> void:
		for outline: Array in (_DUCK if duck else _HORSE):
			var pts := PackedVector3Array()
			for p: Vector2 in outline:
				pts.append(Vector3(p.x, p.y, 0.0))
			g.slab(pts, 0.05)), "plain", Transform3D.IDENTITY, body)
	if duck:
		k.part(_part("play_rider_beak", func(g: Geo) -> void:
			g.slab(PackedVector3Array([Vector3(0.4, 0.94, 0), Vector3(0.58, 0.9, 0), Vector3(0.58, 0.95, 0), Vector3(0.42, 1.0, 0)]), 0.06)), "plain", Transform3D.IDENTITY, Color(0.92, 0.45, 0.12))
	k.part(_part("play_rider_seat|%s" % duck, func(g: Geo) -> void:
		g.box(Vector3(-0.06, 0.765 if duck else 0.745, 0), Vector3(0.27, 0.05, 0.2))
		for sz: float in [-1.0, 1.0]:
			g.box(Vector3(0.35 if duck else 0.52, 0.97 if duck else 0.9, sz * 0.03), Vector3(0.035, 0.035, 0.012))), "rubber", Transform3D.IDENTITY, RUBBER, false)
	k.part(_part("play_rider_handles|%s" % duck, func(g: Geo) -> void:
		var hy := 0.84 if duck else 0.86
		var hx := 0.3 if duck else 0.35
		g.rod(Vector3(hx, hy, -0.15), Vector3(hx, hy, 0.15), 0.016, 8)
		g.rod(Vector3(0.04, 0.52, -0.17), Vector3(0.04, 0.52, 0.17), 0.016, 8)
		g.box(Vector3(0, 0.445, 0), Vector3(0.28, 0.02, 0.24))), "galvanised", Transform3D.IDENTITY, STEEL)
	k.part(_part("play_rider_spring", func(g: Geo) -> void:
		var helix := PackedVector3Array()
		for i in 61:
			var a := TAU * 6.0 * i / 60.0
			helix.append(Vector3(cos(a) * 0.1, 0.05 + 0.38 * i / 60.0, sin(a) * 0.1))
		g.pipe(helix, 0.021, 6)), "paint", Transform3D.IDENTITY, coil)
	k.cyl(0.15, 0.17, 0.05, Vector3(0, 0.025, 0), "metal_dark", Color(0.22, 0.22, 0.22), Vector3.ZERO, 12, false)


## A horse's profile, its parts each convex: body, neck, head, ear, tail.
const _HORSE := [
	[Vector2(-0.3, 0.46), Vector2(0.2, 0.46), Vector2(0.3, 0.54), Vector2(0.3, 0.66), Vector2(0.18, 0.72), Vector2(-0.26, 0.72), Vector2(-0.36, 0.64), Vector2(-0.36, 0.54)],
	[Vector2(0.1, 0.66), Vector2(0.3, 0.58), Vector2(0.48, 0.84), Vector2(0.32, 0.94)],
	[Vector2(0.3, 0.92), Vector2(0.47, 0.8), Vector2(0.65, 0.74), Vector2(0.69, 0.81), Vector2(0.53, 0.95), Vector2(0.37, 0.99)],
	[Vector2(0.34, 0.97), Vector2(0.38, 1.07), Vector2(0.43, 0.97)],
	[Vector2(-0.34, 0.68), Vector2(-0.47, 0.62), Vector2(-0.49, 0.47), Vector2(-0.37, 0.56)]]

## A duck's: body, tail, neck, head.
const _DUCK := [
	[Vector2(-0.34, 0.5), Vector2(0.18, 0.46), Vector2(0.32, 0.56), Vector2(0.3, 0.68), Vector2(0.1, 0.75), Vector2(-0.3, 0.75), Vector2(-0.44, 0.7), Vector2(-0.43, 0.58)],
	[Vector2(-0.38, 0.72), Vector2(-0.52, 0.88), Vector2(-0.46, 0.7)],
	[Vector2(0.16, 0.7), Vector2(0.32, 0.66), Vector2(0.36, 0.86), Vector2(0.2, 0.88)],
	[Vector2(0.3, 0.82), Vector2(0.39, 0.85), Vector2(0.43, 0.95), Vector2(0.39, 1.04), Vector2(0.3, 1.08), Vector2(0.21, 1.04), Vector2(0.17, 0.95), Vector2(0.21, 0.85)]]
