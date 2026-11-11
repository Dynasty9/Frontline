class_name VehicleProfiles
extends RefCounted
## Shared crease-aware loft and revolved-profile kernels. Families retain their
## station data. Cache identities include every shape parameter, not just names.
static var _mc := {}

static func loft(rings: Array, crease := 40.0, caps := true, inward := false) -> ArrayMesh:
	var key := var_to_str([rings, crease, caps, inward])
	if _mc.has(key):
		return _mc[key]
	var nr := rings.size()
	var n := (rings[0] as PackedVector3Array).size()
	var cen: Array[Vector3] = []
	for r in rings:
		cen.append(VehicleModels._centroid(r))
	# the outward normal of every quad, for the smoothing
	var fn := PackedVector3Array()
	fn.resize((nr - 1) * n)
	for i in nr - 1:
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var c := (cen[i] + cen[i + 1]) * 0.5
		for j in n:
			var j1 := (j + 1) % n
			var mid := (r0[j] + r0[j1] + r1[j] + r1[j1]) * 0.25
			var v := (r1[j1] - r0[j]).cross(r0[j1] - r1[j])
			if v.length_squared() < 1e-14:
				v = mid - c
			v = v.normalized()
			if v.dot(mid - c) < 0.0:
				v = -v
			fn[i * n + j] = -v if inward else v
	var cs := cos(deg_to_rad(crease))
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	for i in nr - 1:
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		for j in n:
			var j1 := (j + 1) % n
			var f := fn[i * n + j]
			var na := _vn(fn, nr, n, i, j, f, cs)
			var nb := _vn(fn, nr, n, i, j1, f, cs)
			var nc := _vn(fn, nr, n, i + 1, j1, f, cs)
			var nd := _vn(fn, nr, n, i + 1, j, f, cs)
			_tri(vs, ns, r0[j], r0[j1], r1[j1], na, nb, nc, f)
			_tri(vs, ns, r0[j], r1[j1], r1[j], na, nc, nd, f)
	for e in ([0, nr - 1] if caps else []):
		var r: PackedVector3Array = rings[e]
		var out: Vector3 = cen[e] - cen[1 if e == 0 else nr - 2]
		var pn := Vector3.ZERO
		for i in range(1, n - 1):
			pn += (r[i] - r[0]).cross(r[i + 1] - r[0])
		if pn.length_squared() < 1e-10:
			continue
		pn = pn.normalized()
		if pn.dot(out) < 0.0:
			pn = -pn
		for i in range(1, n - 1):
			_tri(vs, ns, r[0], r[i], r[i + 1], pn, pn, pn, pn)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	Mats.keep_arrays(am, arr)
	_mc[key] = am
	return am


## The smoothed normal at ring vi, point vj, as seen from the quad facing f.
static func _vn(fn: PackedVector3Array, nr: int, n: int, vi: int, vj: int, f: Vector3, cs: float) -> Vector3:
	var s := Vector3.ZERO
	for qi in [vi - 1, vi]:
		if qi < 0 or qi > nr - 2:
			continue
		for qj in [(vj - 1 + n) % n, vj]:
			var g := fn[qi * n + qj]
			if g.dot(f) >= cs:
				s += g
	return s.normalized() if s.length_squared() > 1e-12 else f


## One triangle, wound the way Godot draws front faces (clockwise from outside).
static func _tri(vs: PackedVector3Array, ns: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, f: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-14:
		return
	if cr.dot(f) > 0.0:
		vs.append_array([a, c, b])
		ns.append_array([na, nc, nb])
	else:
		vs.append_array([a, b, c])
		ns.append_array([na, nb, nc])


static func revolve(prof: Array, segs := 24, crease := 50.0) -> ArrayMesh:
	var kk := var_to_str([prof, segs, crease])
	if _mc.has(kk):
		return _mc[kk]
	var np := prof.size()
	var sn: Array[Vector2] = []
	for i in np - 1:
		var d: Vector2 = (prof[i + 1] as Vector2) - (prof[i] as Vector2)
		sn.append(Vector2(d.y, -d.x).normalized() if d.length() > 1e-6 else Vector2(1, 0))
	var cs := cos(deg_to_rad(crease))
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	for i in np - 1:
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[i + 1]
		if a.distance_to(b) < 1e-6:
			continue
		# the normal at each end: shared with the neighbour unless it turns sharply
		var na := sn[i]
		if i > 0 and sn[i - 1].dot(sn[i]) > cs:
			na = (sn[i - 1] + sn[i]).normalized()
		var nb := sn[i]
		if i < np - 2 and sn[i + 1].dot(sn[i]) > cs:
			nb = (sn[i + 1] + sn[i]).normalized()
		for j in segs:
			var t0 := TAU * float(j) / float(segs)
			var t1 := TAU * float(j + 1) / float(segs)
			var c0 := Vector2(cos(t0), sin(t0))
			var c1 := Vector2(cos(t1), sin(t1))
			var p0 := Vector3(c0.x * a.x, c0.y * a.x, a.y)
			var p1 := Vector3(c1.x * a.x, c1.y * a.x, a.y)
			var p2 := Vector3(c1.x * b.x, c1.y * b.x, b.y)
			var p3 := Vector3(c0.x * b.x, c0.y * b.x, b.y)
			var n0 := Vector3(c0.x * na.x, c0.y * na.x, na.y)
			var n1 := Vector3(c1.x * na.x, c1.y * na.x, na.y)
			var n2 := Vector3(c1.x * nb.x, c1.y * nb.x, nb.y)
			var n3 := Vector3(c0.x * nb.x, c0.y * nb.x, nb.y)
			var f := (n0 + n1 + n2 + n3).normalized()
			_tri(vs, ns, p0, p1, p2, n0, n1, n2, f)
			_tri(vs, ns, p0, p2, p3, n0, n2, n3, f)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	Mats.keep_arrays(am, arr)
	_mc[kk] = am
	return am


