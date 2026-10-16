class_name BodyMesh
extends ArrayMesh
## Sculpted shapes for the soldiers. A body part is a stack of rounded
## cross-sections - a chest, a thigh, a helmet - each one a superellipse with
## its own width, its own depth in front and behind (a chest is deep in front
## and flat across the back) and its own squareness (round limbs, boxy armour).
## Lofted with smooth normals and kept as plain triangle lists, so a soldier's
## parts merge into one mesh per joint without re-indexing (Mats.merge_static).
## Shapes are cached: every man with the same build shares them.

static var _cache := {}


## One cross-section at height y: half width, depth in front (-z), depth
## behind (+z), squareness (2 an ellipse, 3-4 a rounded box) and its centre.
static func ring(y: float, hw: float, front: float, back: float, sq := 2.0, cx := 0.0, cz := 0.0) -> PackedFloat32Array:
	return PackedFloat32Array([y, hw, front, back, sq, cx, cz])


## A point on a ring at angle a (0 is +x, -PI/2 straight ahead), pushed out
## (or in, for a negative grow) from the ring's outline.
static func _pt(r: PackedFloat32Array, a: float, grow := 0.0) -> Vector3:
	var c := cos(a)
	var s := sin(a)
	var e := 2.0 / r[4]
	var x := signf(c) * pow(absf(c), e) * maxf(r[1] + grow, 0.0005)
	var d := (r[2] if s < 0.0 else r[3]) + grow
	var z := signf(s) * pow(absf(s), e) * maxf(d, 0.0005)
	return Vector3(r[5] + x, r[0], r[6] + z)


static func _centre(r: PackedFloat32Array) -> Vector3:
	return Vector3(r[5], r[0], r[6])


## A closed loft through the rings (bottom to top or top to bottom), capped at
## the ends that `caps` asks for (1 the first ring, 2 the last).
static func loft(rings: Array, segs := 10, caps := 3) -> BodyMesh:
	var key := "L%d|%d|%s" % [segs, caps, str(rings)]
	if _cache.has(key):
		return _cache[key]
	var nr := rings.size()
	var p: Array[PackedVector3Array] = []
	for r in rings:
		var row := PackedVector3Array()
		for i in segs:
			row.append(_pt(r, TAU * i / segs))
		p.append(row)
	var nm := _normals(p, rings, true)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for k in nr - 1:
		for i in segs:
			var j := (i + 1) % segs
			_quad(v, n, p[k][i], p[k][j], p[k + 1][j], p[k + 1][i], nm[k][i], nm[k][j], nm[k + 1][j], nm[k + 1][i])
	for e in [0, nr - 1]:
		if not (caps & (1 if e == 0 else 2)):
			continue
		var c := _centre(rings[e])
		var out := (c - _centre(rings[1 if e == 0 else nr - 2])).normalized()
		for i in segs:
			_tri(v, n, c, p[e][i], p[e][(i + 1) % segs], out)
	return _commit(key, v, n)


## A curved plate lying on part of a loft - a chest plate, a knee pad, the
## band of a cap - covering the arc a0..a1 of each ring, `thick` deep (built
## inwards from the rings), with a smooth face and hard edges.
static func plate(rings: Array, a0: float, a1: float, segs: int, thick: float) -> BodyMesh:
	var key := "P%d|%.3f|%.3f|%.3f|%s" % [segs, a0, a1, thick, str(rings)]
	if _cache.has(key):
		return _cache[key]
	var nr := rings.size()
	var o: Array[PackedVector3Array] = []
	var ii: Array[PackedVector3Array] = []
	for r in rings:
		var ro := PackedVector3Array()
		var ri := PackedVector3Array()
		for j in segs + 1:
			var a := lerpf(a0, a1, float(j) / segs)
			ro.append(_pt(r, a))
			ri.append(_pt(r, a, -thick))
		o.append(ro)
		ii.append(ri)
	var nm := _normals(o, rings, false)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var z := Vector3.ZERO
	for k in nr - 1:
		for j in segs:
			# the face, and the back of it
			_quad(v, n, o[k][j], o[k][j + 1], o[k + 1][j + 1], o[k + 1][j], nm[k][j], nm[k][j + 1], nm[k + 1][j + 1], nm[k + 1][j])
			var inn := ii[k][j] - o[k][j]
			_quad(v, n, ii[k][j], ii[k][j + 1], ii[k + 1][j + 1], ii[k + 1][j], inn, inn, inn, inn, true)
		# the two side edges
		for e in [0, segs]:
			var side := (o[k][e] - o[k][1 if e == 0 else segs - 1]).normalized()
			_quad(v, n, o[k][e], ii[k][e], ii[k + 1][e], o[k + 1][e], side, z, z, z, true)
	# the top and bottom edges
	for e in [0, nr - 1]:
		for j in segs:
			var up := (o[e][j] - o[1 if e == 0 else nr - 2][j]).normalized()
			_quad(v, n, o[e][j], o[e][j + 1], ii[e][j + 1], ii[e][j], up, z, z, z, true)
	return _commit(key, v, n)


## Smooth normals over a grid of ring points (closed: the rings wrap round).
static func _normals(p: Array[PackedVector3Array], rings: Array, closed: bool) -> Array[PackedVector3Array]:
	var nr := p.size()
	var out: Array[PackedVector3Array] = []
	for k in nr:
		var row := PackedVector3Array()
		var cnt := p[k].size()
		for i in cnt:
			var i0 := (i - 1 + cnt) % cnt if closed else maxi(i - 1, 0)
			var i1 := (i + 1) % cnt if closed else mini(i + 1, cnt - 1)
			var tu: Vector3 = p[k][i1] - p[k][i0]
			var tv: Vector3 = p[mini(k + 1, nr - 1)][i] - p[maxi(k - 1, 0)][i]
			var nn := tv.cross(tu)
			var away: Vector3 = p[k][i] - _centre(rings[k])
			if nn.dot(away) < 0.0:
				nn = -nn
			row.append(nn.normalized() if nn.length_squared() > 1e-14 else away.normalized())
		out.append(row)
	return out


## Two triangles a-b-c, a-c-d facing along the given normals (or, flat, all
## facing along na).
static func _quad(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3, flat := false) -> void:
	if flat:
		_tri(v, n, a, b, c, na)
		_tri(v, n, a, c, d, na)
		return
	_tri(v, n, a, b, c, na + nb + nc, na, nb, nc)
	_tri(v, n, a, c, d, na + nc + nd, na, nc, nd)


## A triangle wound to face `out` (Godot's front faces turn clockwise), with
## per-vertex normals or, if none are given, its own flat one.
static func _tri(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, out: Vector3,
		na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-14:
		return
	if cr.dot(out) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
		cr = -cr
	if na == Vector3.ZERO:
		na = -cr.normalized()
		nb = na
		nc = na
	v.append(a)
	v.append(b)
	v.append(c)
	n.append(na)
	n.append(nb)
	n.append(nc)


static func _commit(key: String, v: PackedVector3Array, n: PackedVector3Array) -> BodyMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	var m := BodyMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = m
	return m
