class_name VmFighter
extends RefCounted
## Procedural models: fast jets - the F/A-181 Black Wasp II and the generic
## strike jet (an F-16C Block 50/52 Fighting Falcon).
## Conventions as in VmPlane (read its header): local -Z is forward, y = 0 is
## the ground, metres; built in flight with the gear up, round the fuselage.
## Landing gear goes under a child Node3D named "Gear", hidden by default (the
## Field Manual and the model sheets show it, standing the aircraft on it);
## with FL_GEAR_UP in the environment it is left out, for checking the
## in-flight look. In flight the gear doors are closed flush: panel lines.
##
## Fuselages are lofted through hand-drawn half sections (_hull): the right
## half of each station from the top centre round to the bottom centre,
## mirrored, resampled along the body by cubic curves. The stealth jet keeps
## them faceted (flat panels, hard chines); the F-16's are smoothed round each
## section. A body splits at a section point into an upper and a lower shell
## for the two-tone paint. Intakes and jet pipes are hollow (_duct): a lip, an
## inner wall and a dark face deep inside, so they have depth from any angle.
## Exhaust glow: the "Afterburner" node (VmPlane.glow).

## Every model key this file builds.
const KEYS: Array[String] = ["blackwasp", "jet"]

const WHITE := Color(0.8, 0.8, 0.78)  # landing gear legs and wheel hubs
const STEEL := Color(0.62, 0.63, 0.64)  # oleo struts

static var _mc := {}
static var _glass := {}
static var _skin_mat: ShaderMaterial


## Builds the model for `key` into k; false if this file doesn't (yet) know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"blackwasp":
			_blackwasp(k, team)
		"jet":
			_f16(k, team)
		_:
			return false
	_repaint(k)
	return true


# --- mesh helpers ------------------------------------------------------------------

## A solid lofted through rings (closed loops, all the same point count):
## normals averaged across edges flatter than `crease` degrees, both ends
## capped flat unless `caps` is off. The faces turn outward (or, with
## `inward`, to the inside: a duct's inner wall), decided by a vote over all
## of them, so concave sections (a strake blending into a fuselage) are fine.
## Cached by key.
static func _skin(rings: Array, key: String, crease := 30.0, caps := true, inward := false) -> ArrayMesh:
	var kk := "ft_" + key
	if _mc.has(kk):
		return _mc[kk]
	var nr := rings.size()
	var n := (rings[0] as PackedVector3Array).size()
	var cen: Array[Vector3] = []
	for r in rings:
		cen.append(VehicleModels._centroid(r))
	var fn := PackedVector3Array()
	fn.resize((nr - 1) * n)
	var rad := PackedVector3Array()
	rad.resize((nr - 1) * n)
	var vote := 0.0
	for i in nr - 1:
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var c := (cen[i] + cen[i + 1]) * 0.5
		for j in n:
			var j1 := (j + 1) % n
			var mid := (r0[j] + r0[j1] + r1[j] + r1[j1]) * 0.25
			var v := (r1[j1] - r0[j]).cross(r0[j1] - r1[j])
			rad[i * n + j] = (mid - c).normalized()
			if v.length_squared() > 1e-14:
				v = v.normalized()
				vote += signf(v.dot(mid - c))
			else:
				v = Vector3.ZERO
			fn[i * n + j] = v
	var flip := (vote < 0.0) != inward
	for q in fn.size():
		if fn[q] == Vector3.ZERO:
			# a degenerate quad (a pointed nose): face along the section's radius
			fn[q] = -rad[q] if inward else rad[q]
		elif flip:
			fn[q] = -fn[q]
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
	if caps:
		for e in [0, nr - 1]:
			var r: PackedVector3Array = rings[e]
			var out: Vector3 = cen[e] - cen[1 if e == 0 else nr - 2]
			var c0: Vector3 = cen[e]
			var pn := Vector3.ZERO
			for i in n:
				pn += (r[i] - c0).cross(r[(i + 1) % n] - c0)
			if pn.length_squared() < 1e-10:
				continue
			pn = pn.normalized()
			if pn.dot(out) < 0.0:
				pn = -pn
			for i in n:
				_tri(vs, ns, c0, r[i], r[(i + 1) % n], pn, pn, pn, pn)
	var am := _mesh(vs, ns)
	_mc[kk] = am
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


## One triangle, wound the way Godot draws front faces (clockwise from the
## side f points to).
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


static func _mesh(vs: PackedVector3Array, ns: PackedVector3Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	var am := ArrayMesh.new()
	if not vs.is_empty():
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


## A flat polygon facing nrm, fanned from its centre c (by default the
## points' centroid), so star shapes work.
static func _poly_mesh(pts: PackedVector3Array, nrm: Vector3, c := Vector3.INF) -> ArrayMesh:
	if c == Vector3.INF:
		c = VehicleModels._centroid(pts)
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	for i in pts.size():
		_tri(vs, ns, c, pts[i], pts[(i + 1) % pts.size()], nrm, nrm, nrm, nrm)
	return _mesh(vs, ns)


## A thin plate t thick through the quad a-b-c-d (a-b one end, d-c the other):
## a fin, a petal, a door, a pylon. Its edges stay hard.
static func _slab(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> ArrayMesh:
	var n := (b - a).cross(d - a).normalized() * (t * 0.5)
	return _skin([PackedVector3Array([a - n, b - n, b + n, a + n]), PackedVector3Array([d - n, c - n, c + n, d + n])], key, 30.0)


## k._add with the order of arguments used here.
static func _put(k: VehicleModels, p: Node3D, mesh: Mesh, mat: String, col, pos := Vector3.ZERO, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	return k._add(p, mesh, mat, col, pos, rot, Vector3.ONE, shadow)


## The airframe's paint: the shared aircraft surface without its worn,
## bare-metal patches (fine on a truck, dirty-looking on a jet's fresh
## low-visibility grey); the broad tonal variation stays. Every part built
## with "aircraft" (here or by VmPlane's helpers) is switched to it.
static func _repaint(k: VehicleModels) -> void:
	if k.burnt:
		return
	var src := Mats.get_mat("aircraft")
	if _skin_mat == null:
		_skin_mat = src.duplicate() as ShaderMaterial
		_skin_mat.set_shader_parameter("pattern", Mats.PLAIN)
		_skin_mat.set_shader_parameter("bump", 0.15)
	_swap_mat(k.root, src, _skin_mat)


static func _swap_mat(n: Node, from: Material, to: Material) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override == from:
			(c as MeshInstance3D).material_override = to
		_swap_mat(c, from, to)


## Canopy glass with a coloured coating (a stealth jet's gold): the shared
## glass surface, more metallic, tinted. One material per colour.
static func _glaze(k: VehicleModels, mi: MeshInstance3D, col: Color, metal := 0.7) -> void:
	if k.burnt:
		return
	var key := "%s_%.2f" % [col.to_html(), metal]
	if not _glass.has(key):
		var g := Mats.get_mat("glass").duplicate() as ShaderMaterial
		g.set_shader_parameter("col_a", col)
		g.set_shader_parameter("metal", metal)
		g.set_shader_parameter("rough", 0.07)
		_glass[key] = g
	mi.material_override = _glass[key]


# --- sections ----------------------------------------------------------------------

## Stations [z, [Vector2 ...]] (each the same number of points) resampled
## along z, `sub` rows per span, by cubic Hermite curves through the
## stations, then each section densified `sub_ring` times round (Catmull-Rom;
## a half profile, mirrored at its ends) for smooth bodies.
static func _rows(st: Array, sub: int, sub_ring := 1) -> Array:
	var out := []
	var ns := st.size()
	for i in ns - 1:
		var z0: float = st[i][0]
		var z1: float = st[i + 1][0]
		var h := z1 - z0
		for s in maxi(sub, 1):
			var t := float(s) / float(maxi(sub, 1))
			var h00 := 2.0 * t * t * t - 3.0 * t * t + 1.0
			var h10 := t * t * t - 2.0 * t * t + t
			var h01 := -2.0 * t * t * t + 3.0 * t * t
			var h11 := t * t * t - t * t
			var pts := []
			for j in (st[i][1] as Array).size():
				var p0: Vector2 = st[i][1][j]
				var p1: Vector2 = st[i + 1][1][j]
				pts.append(p0 * h00 + _tan(st, i, j) * h * h10 + p1 * h01 + _tan(st, i + 1, j) * h * h11)
			out.append([z0 + h * t, pts])
	out.append([st[ns - 1][0], (st[ns - 1][1] as Array).duplicate()])
	if sub_ring > 1:
		for r in out:
			r[1] = _dense(r[1], sub_ring)
	return out


## The slope of station point j along z at station i.
static func _tan(st: Array, i: int, j: int) -> Vector2:
	var a := maxi(i - 1, 0)
	var b := mini(i + 1, st.size() - 1)
	return ((st[b][1][j] as Vector2) - (st[a][1][j] as Vector2)) / maxf(1e-4, float(st[b][0]) - float(st[a][0]))


## A half profile densified by centripetal Catmull-Rom, `sub` points a span;
## its ends meet their mirror images square (a smooth crown and keel).
static func _dense(half: Array, sub: int) -> Array:
	var n := half.size()
	var out := []
	for i in n - 1:
		var p1: Vector2 = half[i]
		var p2: Vector2 = half[i + 1]
		var p0: Vector2 = half[i - 1] if i > 0 else Vector2(-(half[1] as Vector2).x, (half[1] as Vector2).y)
		var p3: Vector2 = half[i + 2] if i + 2 < n else Vector2(-(half[n - 2] as Vector2).x, (half[n - 2] as Vector2).y)
		for s in sub:
			out.append(_ccr(p0, p1, p2, p3, float(s) / float(sub)))
	out.append(half[n - 1])
	return out


## Centripetal Catmull-Rom between p1 and p2 (no loops or overshoot at
## unevenly spaced points).
static func _ccr(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t1 := sqrt(maxf(p0.distance_to(p1), 1e-4))
	var t2 := t1 + sqrt(maxf(p1.distance_to(p2), 1e-4))
	var t3 := t2 + sqrt(maxf(p2.distance_to(p3), 1e-4))
	var tt := lerpf(t1, t2, t)
	var a1 := p0 * ((t1 - tt) / t1) + p1 * (tt / t1)
	var a2 := p1 * ((t2 - tt) / (t2 - t1)) + p2 * ((tt - t1) / (t2 - t1))
	var a3 := p2 * ((t3 - tt) / (t3 - t2)) + p3 * ((tt - t2) / (t3 - t2))
	var b1 := a1 * ((t2 - tt) / t2) + a2 * (tt / t2)
	var b2 := a2 * ((t3 - tt) / (t3 - t1)) + a3 * ((tt - t1) / (t3 - t1))
	return b1 * ((t2 - tt) / (t2 - t1)) + b2 * ((tt - t1) / (t2 - t1))


## A section ring from a half profile (Vector2 points, the right side from the
## top centre to the bottom centre; y from the axis at y0): points j0..j1 and
## their mirror images (the centre points once), at z, shifted xo across.
static func _ring(half: Array, z: float, y0: float, j0 := 0, j1 := -1, xo := 0.0) -> PackedVector3Array:
	var h := half.size()
	if j1 < 0:
		j1 = h - 1
	var r := PackedVector3Array()
	for j in range(j0, j1 + 1):
		var p: Vector2 = half[j]
		r.append(Vector3(xo + p.x, y0 + p.y, z))
	for j in range(j1, j0 - 1, -1):
		if j == 0 or j == h - 1:
			continue
		var p: Vector2 = half[j]
		r.append(Vector3(xo - p.x, y0 + p.y, z))
	return r


## A closed loop (Vector2 points round it) at z, mirrored to the left when
## sd is -1.
static func _loop(pts: Array, z: float, y0: float, sd := 1.0) -> PackedVector3Array:
	var r := PackedVector3Array()
	for p in pts:
		r.append(Vector3(sd * (p as Vector2).x, y0 + (p as Vector2).y, z))
	return r


## A body through resampled rows: points j0..j1 of each half section (the
## whole section by default), rows i0..i1.
static func _hull(k: VehicleModels, p: Node3D, key: String, rows: Array, y0: float, mat: String, col, j0 := 0, j1 := -1, i0 := 0, i1 := -1, crease := 30.0) -> MeshInstance3D:
	var rings := []
	if not _mc.has("ft_" + key):
		var last := rows.size() - 1 if i1 < 0 else i1
		for i in range(i0, last + 1):
			rings.append(_ring(rows[i][1], rows[i][0], y0, j0, j1))
	return _put(k, p, _skin(rings, key, crease), mat, col)


## A thin band round a hull at row i (a panel joint): its section grown by
## `grow`, `len` long.
static func _hband(k: VehicleModels, p: Node3D, key: String, rows: Array, y0: float, i: int, len: float, grow: float, col, j0 := 0, j1 := -1) -> void:
	var rings := []
	if not _mc.has("ft_" + key):
		var half: Array = rows[i][1]
		var big := []
		for q in half:
			var v: Vector2 = q
			big.append(v + v.normalized() * grow if v.length() > 1e-3 else v)
		var z: float = rows[i][0]
		rings = [_ring(big, z - len * 0.5, y0, j0, j1), _ring(big, z + len * 0.5, y0, j0, j1)]
	_put(k, p, _skin(rings, key, 50.0), "aircraft", col, Vector3.ZERO, Vector3.ZERO, false)


## A trapezoid loop (12 points) for a nacelle or caret intake on the right:
## inner wall at xi, the outer wall from xot at the top to xob at the bottom,
## top yt, bottom yb; corners at points 0, 3, 6, 9.
static func _qloop(xi: float, xot: float, xob: float, yt: float, yb: float) -> Array:
	var cs := [Vector2(xi, yt), Vector2(xot, yt), Vector2(xob, yb), Vector2(xi, yb)]
	var o := []
	for e in 4:
		var a: Vector2 = cs[e]
		var b: Vector2 = cs[(e + 1) % 4]
		for s in 3:
			o.append(a.lerp(b, float(s) / 3.0))
	return o


## A round loop (12 points) matching _qloop's: point 0 up and inboard.
static func _cloop(cx: float, cy: float, r: float) -> Array:
	var o := []
	for i in 12:
		var a := deg_to_rad(135.0 - 30.0 * i)
		o.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return o


## Two loops blended point by point.
static func _mixloop(a: Array, b: Array, t: float) -> Array:
	var o := []
	for i in a.size():
		o.append((a[i] as Vector2).lerp(b[i], t))
	return o


## A loop shrunk towards its centre by d, across (not along) the axis.
static func _inset(r: PackedVector3Array, d: float) -> PackedVector3Array:
	var c := VehicleModels._centroid(r)
	var o := PackedVector3Array()
	for v in r:
		var t := c - v
		t.z = 0.0
		o.append(v + t.normalized() * d if t.length() > d * 2.0 else v + t * 0.5)
	return o


## A hollow intake mouth or jet pipe: the outer skin from the lip loop back
## to the `back` loop, the lip's rim th thick, the inner wall and a dark face
## at the back. dir -1 opens forward (an intake), 1 aft (a jet pipe).
static func _duct(k: VehicleModels, p: Node3D, key: String, lip: PackedVector3Array, back: PackedVector3Array, th: float, mat: String, col, inner_col, dir := -1.0, crease := 40.0, outer := true) -> void:
	if outer:
		_put(k, p, _skin([lip, back], key + "_o", crease, false), mat, col)
	var li := _inset(lip, th)
	var bi := _inset(back, th * 0.8)
	_put(k, p, _skin([li, bi], key + "_i", crease, false, true), mat, inner_col, Vector3.ZERO, Vector3.ZERO, false)
	var kr := "ft_" + key + "_r"
	if not _mc.has(kr):
		var vs := PackedVector3Array()
		var ns := PackedVector3Array()
		var n := lip.size()
		for j in n:
			var j1 := (j + 1) % n
			var f := (li[j] - lip[j]).cross(lip[j1] - lip[j])
			if f.length_squared() < 1e-12:
				f = Vector3(0, 0, dir)
			f = f.normalized()
			if f.z * dir < 0.0:
				f = -f
			_tri(vs, ns, lip[j], lip[j1], li[j1], f, f, f, f)
			_tri(vs, ns, lip[j], li[j1], li[j], f, f, f, f)
		_mc[kr] = _mesh(vs, ns)
	_put(k, p, _mc[kr], mat, col)
	# the dark face deep inside (the engine face, the darkness of a jet pipe)
	var kf := "ft_" + key + "_f"
	if not _mc.has(kf):
		var fr := PackedVector3Array()
		for v in bi:
			fr.append(v + Vector3(0, 0, dir * 0.01))
		_mc[kf] = _poly_mesh(fr, Vector3(0, 0, dir))
	_put(k, p, _mc[kf], "plain_dark", null, Vector3.ZERO, Vector3.ZERO, false)


## A ring of n nozzle petals (flaps) round the axis at c pointing aft: from
## radius r0 at the base to r1 at the exit, len long, each w of its share of
## the circumference wide at the base and taper times that at the tip (a
## sawtooth edge when small). Each its own plate, so the gaps between show.
static func _petals(k: VehicleModels, p: Node3D, key: String, c: Vector3, n: int, r0: float, r1: float, len: float, w: float, taper: float, t: float, col: Color) -> void:
	var w0 := TAU * r0 / float(n) * w
	var w1 := TAU * r1 / float(n) * w * taper
	var pm := _slab(key, Vector3(-w0 * 0.5, r0, 0), Vector3(w0 * 0.5, r0, 0), Vector3(w1 * 0.5, r1, len), Vector3(-w1 * 0.5, r1, len), t)
	for i in n:
		var sh := 1.0 if i % 2 == 0 else 0.9
		_put(k, p, pm, "gunmetal_w", Color(col.r * sh, col.g * sh, col.b * sh), c, Vector3(0, 0, TAU * float(i) / float(n)), i % 3 == 0)


## A jet pipe's insides at c (the exit plane), radius r: the liner down to
## `depth`, the dark face, the burner behind it.
static func _pipe(k: VehicleModels, p: Node3D, key: String, c: Vector3, r: float, depth: float) -> void:
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for i in 20:
		var ang := TAU * float(i) / 20.0
		a.append(c + Vector3(cos(ang) * r, sin(ang) * r, 0))
		b.append(c + Vector3(cos(ang) * r * 0.92, sin(ang) * r * 0.92, -depth))
	_put(k, p, _skin([a, b], key + "_liner", 40.0, false, true), "gunmetal_w", Color(0.3, 0.27, 0.24), Vector3.ZERO, Vector3.ZERO, false)
	var kf := "ft_" + key + "_face"
	if not _mc.has(kf):
		var fr := PackedVector3Array()
		for v in b:
			fr.append(v + Vector3(0, 0, 0.01))
		_mc[kf] = _poly_mesh(fr, Vector3(0, 0, 1))
	_put(k, p, _mc[kf], "plain_dark", null, Vector3.ZERO, Vector3.ZERO, false)
	_burner(k, p, c + Vector3(0, 0, -depth + 0.02), r * 0.92)


## The afterburner's flame holder (two thin rings) and the turbine's tail
## cone, on a jet pipe's dark face at c (radius r).
static func _burner(k: VehicleModels, p: Node3D, c: Vector3, r: float) -> void:
	for f in [0.74, 0.44]:
		k._cyl(p, r * f, r * f, 0.03, c + Vector3(0, 0, 0.04), Vector3(PI / 2, 0, 0), "gunmetal_w", Color(0.24, 0.22, 0.2), 18, false)
		k._cyl(p, r * f - 0.035, r * f - 0.035, 0.034, c + Vector3(0, 0, 0.041), Vector3(PI / 2, 0, 0), "plain_dark", null, 18, false)
	k._cyl(p, 0.02, r * 0.28, r * 0.5, c + Vector3(0, 0, r * 0.25), Vector3(PI / 2, 0, 0), "gunmetal_w", Color(0.22, 0.2, 0.19), 12, false)


# --- surfaces ----------------------------------------------------------------------

## Airfoil thickness factor at chord fraction f (VmPlane's section).
static func _ft(f: float) -> float:
	var fl: Array = VmPlane.FOIL
	for i in range(0, fl.size() - 2, 2):
		if f <= float(fl[i + 2]):
			return lerpf(float(fl[i + 1]), float(fl[i + 3]), (f - float(fl[i])) / (float(fl[i + 2]) - float(fl[i])))
	return float(fl[fl.size() - 1])


## An airfoil ring with a fixed point count from chord fraction f0 to f1:
## leading edge le, chord along +z, thickness th along up. A piece starting
## behind the leading edge (a control surface) gets a blunt hinge nose.
static func _af(le: Vector3, chord: float, th: float, up: Vector3, f0: float, f1: float, n := 8) -> PackedVector3Array:
	var fr: Array[float] = []
	for i in n:
		var t := float(i) / float(n - 1)
		fr.append(lerpf(f0, f1, t if f0 > 0.0 else 1.0 - cos(t * PI * 0.5)))
	var r := PackedVector3Array()
	for i in n:
		var h := _ft(fr[i]) * th * 0.5 * (0.6 if i == 0 and f0 > 0.0 else 1.0)
		r.append(le + Vector3(0, 0, fr[i] * chord) + up * h)
	for i in range(n - 1, -1, -1):
		if i == 0 and f0 <= 0.0:
			continue
		var h := _ft(fr[i]) * th * 0.5 * (0.6 if i == 0 and f0 > 0.0 else 1.0)
		r.append(le + Vector3(0, 0, fr[i] * chord) - up * h)
	return r


## A lifting surface through spanwise sections [leading edge, chord,
## thickness], root first. Panel i (section i to i+1) is cut chordwise at
## cuts[i] = [[fractions at its root], [the same count at its tip]] (a
## leading-edge flap, a flaperon, a rudder) behind a hairline gap, so the
## hinge lines can run across the taper. Mirrored across x = 0 unless
## `mirror` is false.
static func _surf(k: VehicleModels, p: Node3D, key: String, secs: Array, mat: String, col, cuts := [], mirror := true, crease := 30.0) -> void:
	for side in ([1.0, -1.0] if mirror else [1.0]):
		var sd: float = side
		for i in secs.size() - 1:
			var a: Array = secs[i]
			var b: Array = secs[i + 1]
			var la: Vector3 = a[0]
			var lb: Vector3 = b[0]
			la.x *= sd
			lb.x *= sd
			var span := lb - la
			span.z = 0.0
			var up := Vector3(0, 0, 1).cross(span).normalized() if span.length() > 1e-3 else Vector3.UP
			var cu: Array = cuts[i] if i < cuts.size() else []
			var fa: Array = [0.0]
			var fb: Array = [0.0]
			if cu.size() == 2:
				fa.append_array(cu[0])
				fb.append_array(cu[1])
			fa.append(1.0)
			fb.append(1.0)
			for q in fa.size() - 1:
				var kk := "%s_%d_%d%s" % [key, i, q, "L" if sd < 0.0 else ""]
				var rings := []
				if not _mc.has("ft_" + kk):
					var ga := 0.022 / float(a[1])
					var gb := 0.022 / float(b[1])
					rings = [_af(la, a[1], a[2], up, float(fa[q]) + (ga if q > 0 else 0.0), float(fa[q + 1])),
						_af(lb, b[1], b[2], up, float(fb[q]) + (gb if q > 0 else 0.0), float(fb[q + 1]))]
				_put(k, p, _skin(rings, kk, crease), mat, col)


# --- markings ----------------------------------------------------------------------

static func _circle2(r: float, n := 20, c := Vector2.ZERO) -> Array:
	var o := []
	for i in n:
		var a := TAU * float(i) / float(n)
		o.append(c + Vector2(cos(a), sin(a)) * r)
	return o


static func _rect2(c: Vector2, s: Vector2) -> Array:
	return [c + Vector2(-s.x, -s.y) * 0.5, c + Vector2(s.x, -s.y) * 0.5, c + Vector2(s.x, s.y) * 0.5, c + Vector2(-s.x, s.y) * 0.5]


## A five-pointed star, a point up.
static func _star2(ro: float, ri: float) -> Array:
	var o := []
	for i in 10:
		var a := PI / 2.0 + TAU * float(i) / 10.0
		o.append(Vector2(cos(a), sin(a)) * (ro if i % 2 == 0 else ri))
	return o


## A flat marking just proud of a surface: the 2D outline pts laid out at o,
## x along ax, y along n x ax, facing n. `proj` lays its corners onto a curved
## skin (see _project).
static func _decal(k: VehicleModels, p: Node3D, key: String, pts: Array, o: Vector3, n: Vector3, ax: Vector3, col: Color, lift := 0.006, proj := []) -> void:
	if k.burnt:
		return
	var kk := "ft_dc_" + key
	if not _mc.has(kk):
		var nn := n.normalized()
		var x := (ax - nn * ax.dot(nn)).normalized()
		var y := nn.cross(x)
		var r := PackedVector3Array()
		var c2 := Vector2.ZERO
		for q in pts:
			var v: Vector2 = q
			r.append(_project(o + x * v.x + y * v.y, nn, lift, proj))
			c2 += v / float(pts.size())
		_mc[kk] = _poly_mesh(r, nn, _project(o + x * c2.x + y * c2.y, nn, lift, proj))
	_put(k, p, _mc[kk], "aircraft", col, Vector3.ZERO, Vector3.ZERO, false)


## A point laid onto a skin along n, `lift` proud: proj [] keeps it where it
## is (lifted), ["hull", rows, y0] finds a _hull's surface (the section at the
## point's z), ["surf", secs] a lifting surface's (secs as for _surf, the
## left side's mirrored with _msecs).
static func _project(v: Vector3, n: Vector3, lift: float, proj: Array) -> Vector3:
	if proj.is_empty():
		return v + n * lift
	if String(proj[0]) == "hull":
		return _hwrap(v, n, proj[1], float(proj[2]), lift)
	return _wrap(v, proj[1], n, lift)


## A point moved along n (across the body) onto a hull's skin.
static func _hwrap(v: Vector3, n: Vector3, rows: Array, y0: float, lift: float) -> Vector3:
	var i := 0
	while i < rows.size() - 2 and float(rows[i + 1][0]) < v.z:
		i += 1
	var t := clampf((v.z - float(rows[i][0])) / maxf(1e-4, float(rows[i + 1][0]) - float(rows[i][0])), 0.0, 1.0)
	var ha: Array = rows[i][1]
	var hb: Array = rows[i + 1][1]
	var sx := -1.0 if v.x < -1e-4 else 1.0
	var p := Vector2(v.x * sx, v.y - y0)
	var d := Vector2(n.x * sx, n.y).normalized()
	var best := INF
	var hit := p
	for j in ha.size() - 1:
		var a := (ha[j] as Vector2).lerp(hb[j], t)
		var e := (ha[j + 1] as Vector2).lerp(hb[j + 1], t) - a
		var den := d.x * e.y - d.y * e.x
		if absf(den) < 1e-9:
			continue
		var w := a - p
		var s := (w.x * e.y - w.y * e.x) / den
		var u := (w.x * d.y - w.y * d.x) / den
		if u >= -0.02 and u <= 1.02 and absf(s) < absf(best):
			best = s
			hit = p + d * s
	return Vector3(hit.x * sx, hit.y + y0, v.z) + n.normalized() * lift


## A point moved onto a lifting surface's skin on the side n faces: the
## airfoil's thickness there, from the section at its span and chord.
static func _wrap(v: Vector3, secs: Array, n: Vector3, lift: float) -> Vector3:
	var a: Vector3 = secs[0][0]
	var sp: Vector3 = secs[secs.size() - 1][0] - a
	sp.z = 0.0
	var sdir := sp.normalized()
	var up := Vector3(0, 0, 1).cross(sdir).normalized()
	var u := (v - a).dot(sdir)
	var le := a
	var ch := 1.0
	var th := 0.0
	for i in secs.size() - 1:
		var ua := ((secs[i][0] as Vector3) - a).dot(sdir)
		var ub := ((secs[i + 1][0] as Vector3) - a).dot(sdir)
		if u <= ub or i == secs.size() - 2:
			var t := clampf((u - ua) / maxf(1e-4, ub - ua), 0.0, 1.0)
			le = (secs[i][0] as Vector3).lerp(secs[i + 1][0], t)
			ch = lerpf(secs[i][1], secs[i + 1][1], t)
			th = lerpf(secs[i][2], secs[i + 1][2], t)
			break
	var f := clampf((v.z - le.z) / ch, 0.0, 1.0)
	var face := 1.0 if up.dot(n) >= 0.0 else -1.0
	return v - up * (v - le).dot(up) + up * face * (th * 0.5 * _ft(f) + lift)


## A surface's sections mirrored across x = 0 (the left wing or fin).
static func _msecs(secs: Array) -> Array:
	var o := []
	for q in secs:
		var le: Vector3 = q[0]
		o.append([Vector3(-le.x, le.y, le.z), q[1], q[2]])
	return o


## The national marking at o facing n, ax across it, radius r: the
## low-visibility US star-and-bar (dark disc and bars, the star in the
## paint) for the Coalition; a plain two-tone roundel for anyone else.
static func _insignia(k: VehicleModels, p: Node3D, key: String, o: Vector3, n: Vector3, ax: Vector3, r: float, team: int, dark: Color, light: Color, proj := []) -> void:
	if team < 0:
		return
	if team == 1:
		_decal(k, p, key + "_a", _circle2(r), o, n, ax, dark, 0.006, proj)
		_decal(k, p, key + "_b", _circle2(r * 0.55), o, n, ax, light, 0.009, proj)
		_decal(k, p, key + "_c", _circle2(r * 0.22, 12), o, n, ax, dark, 0.012, proj)
		return
	_decal(k, p, key + "_d", _circle2(r), o, n, ax, dark, 0.006, proj)
	_decal(k, p, key + "_br", _rect2(Vector2(1.45 * r, 0.06 * r), Vector2(r * 1.1, r * 0.5)), o, n, ax, dark, 0.006, proj)
	_decal(k, p, key + "_bl", _rect2(Vector2(-1.45 * r, 0.06 * r), Vector2(r * 1.1, r * 0.5)), o, n, ax, dark, 0.006, proj)
	_decal(k, p, key + "_s", _star2(r * 0.96, r * 0.37), o, n, ax, light, 0.009, proj)


## Stroke letters for tail codes and numbers (unit height).
const FONT := {
	"W": [[0, 1, 0.15, 0], [0.15, 0, 0.3, 0.62], [0.3, 0.62, 0.45, 0], [0.45, 0, 0.6, 1]],
	"N": [[0, 0, 0, 1], [0, 1, 0.55, 0], [0.55, 0, 0.55, 1]],
	"H": [[0, 0, 0, 1], [0.55, 0, 0.55, 1], [0, 0.5, 0.55, 0.5]],
	"1": [[0.3, 0, 0.3, 1], [0.3, 1, 0.1, 0.8]],
	"0": [[0, 0, 0.5, 0], [0.5, 0, 0.5, 1], [0.5, 1, 0, 1], [0, 1, 0, 0]],
	"6": [[0.5, 1, 0, 1], [0, 1, 0, 0], [0, 0, 0.5, 0], [0.5, 0, 0.5, 0.5], [0.5, 0.5, 0, 0.5]],
	"8": [[0, 0, 0.5, 0], [0.5, 0, 0.5, 1], [0.5, 1, 0, 1], [0, 1, 0, 0], [0, 0.5, 0.5, 0.5]],
	"9": [[0, 0, 0.5, 0], [0.5, 0, 0.5, 1], [0.5, 1, 0, 1], [0, 1, 0, 0.5], [0, 0.5, 0.5, 0.5]],
}


## Painted text (a tail code, a serial) h tall, its baseline centred on o,
## reading along ax on the face n; `proj` as for _decal. One merged mesh.
static func _text(k: VehicleModels, p: Node3D, key: String, txt: String, o: Vector3, n: Vector3, ax: Vector3, h: float, col: Color, proj := []) -> void:
	if k.burnt:
		return
	var kk := "ft_tx_" + key
	if not _mc.has(kk):
		var nn := n.normalized()
		var x := (ax - nn * ax.dot(nn)).normalized()
		var y := nn.cross(x)
		var w := h * 0.13
		var vs := PackedVector3Array()
		var ns := PackedVector3Array()
		var wide := 0.0
		for ch in txt:
			wide += 0.62 if ch != "1" else 0.42
		var cx := -(wide - 0.06) * 0.5
		for ch in txt:
			for sg in FONT.get(ch, []):
				var a := o + x * ((cx + float(sg[0])) * h) + y * (float(sg[1]) * h)
				var b := o + x * ((cx + float(sg[2])) * h) + y * (float(sg[3]) * h)
				var d := (b - a).normalized()
				var s := nn.cross(d) * (w * 0.5)
				a -= d * w * 0.5
				b += d * w * 0.5
				var q := [_project(a - s, nn, 0.007, proj), _project(b - s, nn, 0.007, proj), _project(b + s, nn, 0.007, proj), _project(a + s, nn, 0.007, proj)]
				_tri(vs, ns, q[0], q[1], q[2], nn, nn, nn, nn)
				_tri(vs, ns, q[0], q[2], q[3], nn, nn, nn, nn)
			cx += 0.62 if ch != "1" else 0.42
		_mc[kk] = _mesh(vs, ns)
	_put(k, p, _mc[kk], "aircraft", col, Vector3.ZERO, Vector3.ZERO, false)


## Panel lines: thin dark strips [a, b, n] (n the face's outward normal),
## one merged mesh; `proj` as for _decal lays them on a curved skin.
static func _lines(k: VehicleModels, p: Node3D, key: String, segs: Array, w: float, col: Color, proj := []) -> void:
	if k.burnt:
		return
	var kk := "ft_ln_" + key
	if not _mc.has(kk):
		var vs := PackedVector3Array()
		var ns := PackedVector3Array()
		for sg in segs:
			var nn: Vector3 = (sg[2] as Vector3).normalized()
			var a := _project(sg[0], nn, 0.004, proj)
			var b := _project(sg[1], nn, 0.004, proj)
			var s := nn.cross(b - a).normalized() * (w * 0.5)
			_tri(vs, ns, a - s, b - s, b + s, nn, nn, nn, nn)
			_tri(vs, ns, a - s, b + s, a + s, nn, nn, nn, nn)
		_mc[kk] = _mesh(vs, ns)
	_put(k, p, _mc[kk], "aircraft", col, Vector3.ZERO, Vector3.ZERO, false)


## A sawtooth panel edge from a to b on the face n: `teeth` teeth of depth d
## pointing along dd, as line segments for _lines.
static func _zigzag(a: Vector3, b: Vector3, n: Vector3, dd: Vector3, d: float, teeth: int) -> Array:
	var o := []
	var prev := a
	for i in teeth:
		var m := a.lerp(b, (float(i) + 0.5) / float(teeth)) + dd.normalized() * d
		var e := a.lerp(b, float(i + 1) / float(teeth))
		o.append([prev, m, n])
		o.append([m, e, n])
		prev = e
	return o


## The outline of a quad panel a-b-c-d on the face n, for _lines.
static func _outline(pts: Array, n: Vector3) -> Array:
	var o := []
	for i in pts.size():
		o.append([pts[i], pts[(i + 1) % pts.size()], n])
	return o


# --- landing gear ------------------------------------------------------------------

## The landing gear's holder: hidden in flight, shown on the ground.
static func _gear_node(k: VehicleModels) -> Node3D:
	var g := k._pivot(k.root, Vector3.ZERO)
	g.name = "Gear"
	g.visible = false
	return g


## An aircraft wheel at pos, its axle along x: the tyre with rounded
## shoulders, the hub and the brake housing.
static func _awheel(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float) -> void:
	k._cyl(p, r * 0.88, r * 0.88, w, pos, Vector3(0, 0, PI / 2), "rubber", null, 22)
	k._cyl(p, r, r, w * 0.74, pos, Vector3(0, 0, PI / 2), "rubber", null, 22)
	k._cyl(p, r * 0.6, r * 0.6, w + 0.012, pos, Vector3(0, 0, PI / 2), "paint", WHITE, 18, false)
	k._cyl(p, r * 0.24, r * 0.3, w + 0.06, pos, Vector3(0, 0, PI / 2), "paint", WHITE.darkened(0.15), 12, false)
	k._cyl(p, r * 0.08, r * 0.08, w + 0.1, pos, Vector3(0, 0, PI / 2), "gunmetal_w", null, 8, false)


## A gear leg from the trunnion `top` to the axle: the white strut, the bright
## oleo slide below it, a torque link.
static func _leg(k: VehicleModels, p: Node3D, top: Vector3, axle: Vector3, r: float) -> void:
	var mid := top.lerp(axle, 0.62)
	VmPlane.rod(k, p, top, mid, r, "paint", WHITE, 10)
	VmPlane.rod(k, p, mid + (top - mid).normalized() * 0.08, axle + (top - axle).normalized() * r, r * 0.68, "steel", STEEL, 10)
	k._cyl(p, r * 1.15, r * 1.15, 0.06, mid, Vector3.ZERO, "paint", WHITE.darkened(0.1), 10, false)
	# the torque link: two arms folded forward
	var kn := mid.lerp(axle, 0.5) + Vector3(0, 0, -r * 2.6)
	VmPlane.rod(k, p, mid + Vector3(0, -0.04, -r), kn, r * 0.28, "paint", WHITE, 6)
	VmPlane.rod(k, p, kn, axle + Vector3(0, r * 1.4, -r * 0.6), r * 0.28, "paint", WHITE, 6)


# --- F-16C Block 50/52 Fighting Falcon ----------------------------------------------

## The F-16's fuselage section (from its axis): a round tube (crown top, keel
## bot, half-width w) flaring at mid-height through the strake and the wing
## root blend out to the sharp edge at half-span e, height ey.
static func _f16_half(top: float, bot: float, w: float, e: float, ey: float) -> Array:
	var b := e - w
	var s := clampf(b / 0.22, 0.0, 1.0)
	var et := lerpf(w * 0.14, 0.03, s)
	return [Vector2(0, top), Vector2(0.5 * w + 0.06 * b, 0.866 * top),
		Vector2(0.866 * w + 0.22 * b, lerpf(0.5 * top, 0.46 * top, s)),
		Vector2(0.985 * w + 0.58 * b, lerpf(0.17 * top, ey + 0.12, s)),
		Vector2(e, ey + et), Vector2(e, ey - et),
		Vector2(0.985 * w + 0.5 * b, lerpf(0.17 * bot, ey - 0.1, s)),
		Vector2(0.866 * w + 0.16 * b, lerpf(0.5 * bot, 0.47 * bot, s)),
		Vector2(0.5 * w + 0.04 * b, 0.866 * bot), Vector2(0, bot)]


## F-16C Block 50/52 Fighting Falcon (the generic strike jet): 15.06 m over
## the pitot, 9.96 m span over the wingtip AMRAAMs, 4.88 m tall. The blended
## wing-body: a round fuselage flaring through the curved strakes into the
## 40-degree cropped-delta wing, the frameless bubble canopy, the ventral
## intake under the cockpit, one tall fin over its base housing, all-moving
## anhedral tailerons, ventral fins, split speedbrakes beside the F110's petal
## nozzle. Strike load: GBU-31s (Mk 84 + JDAM) on stations 3/7, 370-gal tanks
## on 4/6, AIM-9X on 2/8, AIM-120C on the tips, an ALQ-184 jammer on the
## centreline and a Sniper pod on the right intake station. Two-tone air
## superiority grey with low-visibility markings.
static func _f16(k: VehicleModels, team: int) -> void:
	var m := k.root
	var A := "aircraft"
	var top := Color(0.43, 0.46, 0.49) if team != 1 else Color(0.5, 0.47, 0.4)  # FS 36270
	var bot := Color(0.57, 0.59, 0.61) if team != 1 else Color(0.6, 0.57, 0.5)  # FS 36375
	var dark := Color(0.33, 0.35, 0.37) if team != 1 else Color(0.36, 0.33, 0.28)  # FS 36118 markings
	var line := top.darkened(0.3)
	var y0 := 1.45  # the fuselage axis (the jet pipe's centre)
	var z0 := -7.0  # the radome tip: s, the station, runs aft from it
	var yg := y0 - 1.77  # the ground under the wheels: 4.88 m to the fin tip
	var t40 := tan(deg_to_rad(40.0))

	# --- fuselage: radome, the round body, strakes flaring into the wing root
	# [s, crown, keel, half-width, strake edge's half-span, its height]
	var fs := []
	for q in [[0.0, 0.015, -0.015, 0.015, 0.015, 0.0], [0.12, 0.08, -0.08, 0.08, 0.08, 0.0], [0.45, 0.185, -0.18, 0.18, 0.18, 0.0],
			[1.0, 0.3, -0.29, 0.29, 0.29, 0.0], [1.6, 0.385, -0.37, 0.375, 0.375, 0.0], [2.2, 0.45, -0.43, 0.44, 0.44, 0.0],
			[2.9, 0.5, -0.48, 0.48, 0.48, 0.0], [3.5, 0.53, -0.5, 0.5, 0.52, -0.04], [4.3, 0.55, -0.52, 0.52, 0.62, -0.06],
			[5.2, 0.57, -0.54, 0.54, 0.74, -0.06], [6.2, 0.58, -0.56, 0.56, 0.88, -0.05], [7.2, 0.6, -0.58, 0.58, 1.02, -0.04],
			[8.0, 0.6, -0.6, 0.6, 1.1, -0.03], [9.2, 0.6, -0.6, 0.62, 1.13, -0.03], [10.6, 0.6, -0.6, 0.62, 1.13, -0.03],
			[11.9, 0.58, -0.58, 0.6, 1.12, -0.03], [12.7, 0.57, -0.57, 0.58, 1.06, -0.03], [13.3, 0.56, -0.56, 0.56, 0.95, -0.03]]:
		fs.append([z0 + float(q[0]), _f16_half(q[1], q[2], q[3], q[4], q[5])])
	var rows := _rows(fs, 2, 3)
	var hp := ["hull", rows, y0]
	var ir := 10  # the radome joint's row (station 5, s 2.2)
	_hull(k, m, "f16_radome", rows, y0, A, top.lerp(bot, 0.35), 0, -1, 0, ir, 40.0)
	_hull(k, m, "f16_up", rows, y0, A, top, 0, 12, ir, -1, 40.0)
	_hull(k, m, "f16_lo", rows, y0, A, bot, 12, -1, ir, -1, 40.0)
	_hband(k, m, "f16_rj", rows, y0, ir, 0.025, 0.004, line)
	_hband(k, m, "f16_j1", rows, y0, 26, 0.02, 0.004, line, 0, 12)
	_hband(k, m, "f16_j2", rows, y0, 32, 0.02, 0.004, line)
	# the cockpit sill the canopy sits on, the dorsal spine behind it
	VmPlane.body(k, m, "ft_f16_sill", [[z0 + 3.0, y0 + 0.3, 0.36, 0.12, 0.3, 2.4, 2.0], [z0 + 3.6, y0 + 0.33, 0.48, 0.12, 0.34, 2.6, 2.0],
		[z0 + 6.2, y0 + 0.36, 0.52, 0.1, 0.4, 2.6, 2.0], [z0 + 7.6, y0 + 0.38, 0.44, 0.1, 0.4, 2.4, 2.0], [z0 + 8.6, y0 + 0.4, 0.3, 0.08, 0.35, 2.2, 2.0]], A, top, 24)
	VmPlane.body(k, m, "ft_f16_spine", [[z0 + 5.8, y0 + 0.42, 0.4, 0.5, 0.1, 2.3, 2.0], [z0 + 7.0, y0 + 0.43, 0.36, 0.34, 0.1, 2.4, 2.0],
		[z0 + 8.5, y0 + 0.43, 0.32, 0.25, 0.1, 2.5, 2.0], [z0 + 10.2, y0 + 0.43, 0.27, 0.2, 0.1, 2.4, 2.0], [z0 + 11.4, y0 + 0.42, 0.16, 0.16, 0.1, 2.2, 2.0],
		[z0 + 12.3, y0 + 0.42, 0.04, 0.08, 0.05, 2.0, 2.0]], A, top, 20)
	# the frameless bubble canopy (its bow behind the seat), the sill rails
	var cst := [[z0 + 3.05, y0 + 0.44, 0.26, 0.02, 0.05], [z0 + 3.35, y0 + 0.44, 0.39, 0.32, 0.05, 2.1], [z0 + 3.85, y0 + 0.44, 0.45, 0.6, 0.05, 2.2],
		[z0 + 4.5, y0 + 0.44, 0.47, 0.74, 0.05, 2.3], [z0 + 5.15, y0 + 0.44, 0.47, 0.75, 0.05, 2.3], [z0 + 5.8, y0 + 0.44, 0.44, 0.64, 0.05, 2.3],
		[z0 + 6.3, y0 + 0.44, 0.38, 0.47, 0.05, 2.3], [z0 + 6.75, y0 + 0.44, 0.27, 0.27, 0.05, 2.2], [z0 + 7.1, y0 + 0.44, 0.12, 0.08, 0.05, 2.0]]
	_glaze(k, VmPlane.body(k, m, "ft_f16_can", cst, "glass", null, 24, 60.0), Color(0.3, 0.26, 0.16), 0.6)
	VmPlane.band(k, m, "ft_f16_bow", cst, z0 + 5.95, 0.07, 0.015, A, top.darkened(0.15), 24)
	VmPlane.stripe(k, m, "ft_f16_rail", cst, z0 + 3.1, z0 + 7.05, -0.06, 0.1, A, top.darkened(0.2), 0.01, 4)
	VmPlane.stripe(k, m, "ft_f16_railL", cst, z0 + 3.1, z0 + 7.05, PI - 0.1, PI + 0.06, A, top.darkened(0.2), 0.01, 4)

	# --- the ventral intake: a hollow raked mouth, the splitter above it, the
	# duct fairing running back under the fuselage
	var ist := [[z0 + 5.0, y0 - 0.84, 0.53, 0.27, 0.27, 3.0, 2.2], [z0 + 6.4, y0 - 0.82, 0.57, 0.3, 0.29, 3.0, 2.3],
		[z0 + 8.0, y0 - 0.8, 0.6, 0.3, 0.3, 3.0, 2.4], [z0 + 9.5, y0 - 0.74, 0.6, 0.28, 0.3, 2.8, 2.6],
		[z0 + 11.0, y0 - 0.62, 0.56, 0.2, 0.26, 2.6, 2.6], [z0 + 12.3, y0 - 0.5, 0.48, 0.1, 0.12, 2.4, 2.4]]
	VmPlane.body(k, m, "ft_f16_int", ist, A, bot, 24)
	var lip := VmPlane.sec([z0 + 4.42, y0 - 0.85, 0.5, 0.25, 0.27, 3.0, 2.2, 0.0, 0.7, 0.0], 24)
	_duct(k, m, "f16_mouth", lip, VmPlane.sec(ist[0], 24), 0.045, A, bot, bot.darkened(0.55))
	k._box(m, Vector3(0.04, 0.12, 0.75), Vector3(0, y0 - 0.56, z0 + 5.0), A, bot)

	# --- wing: leading-edge flaps the full span, flaperons inboard
	var ws := [[Vector3(0.7, y0 - 0.03, z0 + 7.6 - 0.35 * t40), 11.68 - 7.6 + 0.35 * t40, 0.18],
		[Vector3(1.15, y0 - 0.03, z0 + 7.6 + 0.1 * t40), 11.68 - 7.6 - 0.1 * t40, 0.165],
		[Vector3(3.4, y0 - 0.03, z0 + 7.6 + 2.35 * t40), 11.68 - 7.6 - 2.35 * t40, 0.09],
		[Vector3(4.57, y0 - 0.03, z0 + 7.6 + 3.52 * t40), 11.68 - 7.6 - 3.52 * t40, 0.045]]
	_surf(k, m, "f16_wing", ws, A, top, [[], [[0.12, 0.8], [0.13, 0.74]], [[0.13], [0.14]]])
	# all-moving tailerons, 10 degrees down
	_surf(k, m, "f16_tail", [[Vector3(0.95, y0 - 0.04, z0 + 11.9 - 0.05 * t40), 2.19, 0.1],
		[Vector3(2.79, y0 - 0.04 - 1.84 * tan(deg_to_rad(10.0)), z0 + 11.9 + 1.79 * t40), 0.72, 0.035]], A, top)
	# the fin with its rudder, the squadron band round its tip, the base
	# housing behind it, the antenna cap
	var fin := [[Vector3(0, y0 + 0.5, z0 + 9.9), 3.2, 0.17], [Vector3(0, y0 + 0.62, z0 + 10.03), 3.1, 0.16],
		[Vector3(0, y0 + 2.46, z0 + 12.0), 1.49, 0.08], [Vector3(0, y0 + 3.07, z0 + 12.66), 0.95, 0.05]]
	_surf(k, m, "f16_fin", fin, A, top, [[], [[0.8], [0.62]], []], false)
	_surf(k, m, "f16_finband", [[Vector3(0, y0 + 2.6, z0 + 12.145), 1.376, 0.085], [Vector3(0, y0 + 2.98, z0 + 12.555), 1.04, 0.066]], A, dark, [], false)
	VmPlane.body(k, m, "ft_f16_finbase", [[z0 + 12.3, y0 + 0.56, 0.12, 0.18, 0.05, 2.2, 2.0], [z0 + 12.9, y0 + 0.6, 0.2, 0.2, 0.08, 2.4, 2.0],
		[z0 + 13.8, y0 + 0.6, 0.2, 0.17, 0.1, 2.4, 2.0], [z0 + 14.05, y0 + 0.6, 0.15, 0.1, 0.1, 2.2, 2.0]], A, top, 16)
	k._box(m, Vector3(0.06, 0.1, 0.5), Vector3(0, y0 + 3.08, z0 + 13.32), "paint", dark.darkened(0.2), Vector3.ZERO, false)
	# ventral fins, canted out under the strake shelves
	for sd in [1.0, -1.0]:
		var vf := _slab("f16_vfin" + ("L" if sd < 0.0 else ""), Vector3(sd * 0.5, y0 - 0.5, z0 + 10.9), Vector3(sd * 0.5, y0 - 0.5, z0 + 12.5),
			Vector3(sd * 0.64, y0 - 1.02, z0 + 12.6), Vector3(sd * 0.64, y0 - 1.02, z0 + 11.6), 0.035)
		_put(k, m, vf, A, bot)
	# split speedbrakes at the ends of the strake shelves
	var sb := [[z0 + 12.9, y0 - 0.03, 0.27, 0.08, 0.08, 2.0, 2.0, 0.84], [z0 + 13.5, y0 - 0.03, 0.25, 0.08, 0.08, 2.0, 2.0, 0.84],
		[z0 + 13.95, y0 - 0.03, 0.17, 0.025, 0.025, 2.0, 2.0, 0.84]]
	VmPlane.body2(k, m, "ft_f16_sb", sb, A, top, 14)

	# --- the F110's nozzle: actuator ring, petals, the pipe inside
	var nz := Vector3(0, y0, z0 + 13.3)
	k._cyl(m, 0.555, 0.565, 0.3, nz + Vector3(0, 0, 0.15), Vector3(PI / 2, 0, 0), "gunmetal_w", Color(0.36, 0.35, 0.34), 24)
	_petals(k, m, "f16_pet", nz + Vector3(0, 0, 0.28), 16, 0.55, 0.47, 0.92, 0.94, 0.95, 0.03, Color(0.4, 0.37, 0.34))
	_pipe(k, m, "f16_pipe", nz + Vector3(0, 0, 1.18), 0.455, 0.8)
	VmPlane.glow(k, m, [nz + Vector3(0, 0, 1.55)], 1.7)

	# --- details: pitot, AOA probes, IFF "bird slicers", the gun, refuelling
	# receptacle, antennas, lights
	VmPlane.rod(k, m, Vector3(0, y0, z0 + 0.05), Vector3(0, y0, z0 - 0.55), 0.03, "steel", STEEL, 6, 0.012)
	for sd in [1.0, -1.0]:
		VmPlane.rod(k, m, Vector3(sd * 0.43, y0 + 0.12, z0 + 2.6), Vector3(sd * 0.5, y0 + 0.1, z0 + 2.45), 0.012, "gunmetal_w", null, 5)
	for x in [-0.15, -0.05, 0.05, 0.15]:
		k._box(m, Vector3(0.012, 0.12, 0.16), Vector3(x, y0 + 0.52, z0 + 2.55), "paint", dark, Vector3(0.35, 0, 0), false)
	var gn := Vector3(-0.6, 0.8, 0)
	var gun := _project(Vector3(-0.55, y0 + 0.1, z0 + 6.0), gn, 0.0, hp)
	_decal(k, m, "f16_gun", _rect2(Vector2.ZERO, Vector2(0.32, 0.1)), gun, gn, Vector3(0, 0, 1), Color(0.12, 0.12, 0.12), 0.006, hp)
	k.mg_tip = k._tip(m, gun + Vector3(0, 0, -0.2))
	k.gun_tip = k.mg_tip
	_decal(k, m, "f16_aar", _rect2(Vector2.ZERO, Vector2(0.2, 0.4)), Vector3(0, y0 + 0.715, z0 + 7.7), Vector3.UP, Vector3(1, 0, 0), dark.darkened(0.25))
	_lines(k, m, "f16_aarl", [[Vector3(-0.1, y0 + 0.73, z0 + 7.3), Vector3(-0.04, y0 + 0.75, z0 + 6.85), Vector3.UP],
		[Vector3(0.1, y0 + 0.73, z0 + 7.3), Vector3(0.04, y0 + 0.75, z0 + 6.85), Vector3.UP]], 0.025, dark)
	VmPlane.antenna(k, m, Vector3(0, y0 + 0.66, z0 + 8.9), 0.16, false, dark)
	VmPlane.antenna(k, m, Vector3(0, y0 - 1.1, z0 + 6.9), 0.16, true, dark)
	VmPlane.nav_lights(k, m, Vector3(0.54, y0 - 0.7, z0 + 5.75), 0.06)
	k._box(m, Vector3(0.05, 0.05, 0.1), Vector3(0, y0 + 3.0, z0 + 13.55), "paint", Color(0.85, 0.85, 0.8), Vector3.ZERO, false)
	# formation strip lights: nose sides, fin
	var fl := Color(0.62, 0.68, 0.5)
	var fp := ["surf", fin]
	for sd in [1.0, -1.0]:
		var L := "L" if sd < 0.0 else ""
		_decal(k, m, "f16_fl1" + L, _rect2(Vector2.ZERO, Vector2(0.06, 0.42)), Vector3(sd * 0.4, y0 + 0.08, z0 + 3.2), Vector3(sd, 0.15, 0), Vector3(0, 0, 1), fl, 0.006, hp)
		_decal(k, m, "f16_fl3" + L, _rect2(Vector2.ZERO, Vector2(0.4, 0.06)), Vector3(0, y0 + 2.2, z0 + 13.05), Vector3(sd, 0, 0), Vector3(0, -1.07, 1), fl, 0.006, fp)
		_decal(k, m, "f16_fl2" + L, _rect2(Vector2.ZERO, Vector2(0.4, 0.06)), Vector3(sd * 0.5, y0 + 0.1, z0 + 12.3), Vector3(sd, 0.2, 0), Vector3(0, 0, 1), fl, 0.006, hp)

	# --- panel lines: control-surface hinge lines are gaps; these are the
	# access panels and the gear doors (closed flush)
	var pl := []
	for sd in [1.0, -1.0]:
		var dn := Vector3(sd * 0.5, -0.85, 0)
		pl.append_array(_outline([Vector3(sd * 0.64, y0 - 0.3, z0 + 8.1), Vector3(sd * 1.0, y0 - 0.1, z0 + 8.1),
			Vector3(sd * 1.0, y0 - 0.1, z0 + 10.0), Vector3(sd * 0.64, y0 - 0.3, z0 + 10.0)], dn))
		var un := Vector3(sd * 0.4, 0.9, 0)
		pl.append_array(_outline([Vector3(sd * 0.55, y0 + 0.4, z0 + 8.4), Vector3(sd * 0.85, y0 + 0.25, z0 + 8.4),
			Vector3(sd * 0.85, y0 + 0.25, z0 + 9.6), Vector3(sd * 0.55, y0 + 0.4, z0 + 9.6)], un))
	_lines(k, m, "f16_pl", pl, 0.016, line, hp)
	_lines(k, m, "f16_pln", _outline([Vector3(-0.16, y0 - 1.115, z0 + 5.4), Vector3(0.16, y0 - 1.115, z0 + 5.4),
		Vector3(0.16, y0 - 1.115, z0 + 6.6), Vector3(-0.16, y0 - 1.115, z0 + 6.6)], Vector3.DOWN), 0.016, bot.darkened(0.3))

	# --- stores
	for sd in [1.0, -1.0]:
		for e in [[2.1, "tank"], [3.0, "gbu"], [3.95, "aim9"]]:
			var x: float = e[0]
			var w := VmPlane.surf_at(ws, x)
			var le: Vector3 = w[0]
			var at := Vector3(sd * x, le.y - float(w[2]) * 0.42, le.z + float(w[1]) * 0.42)
			match String(e[1]):
				"tank":
					VmPlane.drop_tank(k, m, VmPlane.pylon(k, m, at + Vector3(0, 0, 0.1), 1.7, 0.3, bot, 0.35), 4.6, 0.35, bot)
				"gbu":
					_gbu31(k, m, VmPlane.pylon(k, m, at + Vector3(0, 0, 0.1), 1.5, 0.26, bot, 0.23))
				"aim9":
					var c := VmPlane.pylon(k, m, at + Vector3(0, 0, -0.1), 1.1, 0.16, bot, 0.12)
					k._box(m, Vector3(0.07, 0.07, 2.2), c + Vector3(0, 0.08, 0), "gunmetal_w", bot.darkened(0.3))
					_aim9x(k, m, c + Vector3(0, -0.02, -0.15))
		# the tip launcher and its AMRAAM
		var tw := VmPlane.surf_at(ws, 4.57)
		var tle: Vector3 = tw[0]
		k._box(m, Vector3(0.09, 0.12, 2.9), Vector3(sd * 4.63, tle.y, z0 + 11.0), A, top)
		_aim120(k, m, Vector3(sd * 4.76, tle.y - 0.03, z0 + 10.75))
	# Sniper pod on the right intake station, the ALQ-184 on the centreline
	k._box(m, Vector3(0.1, 0.22, 0.9), Vector3(0.5, y0 - 1.0, z0 + 6.9), A, bot, Vector3(0, 0, 0.6))
	_sniper(k, m, Vector3(0.66, y0 - 1.13, z0 + 6.8))
	_alq184(k, m, VmPlane.pylon(k, m, Vector3(0, y0 - 1.03, z0 + 9.6), 1.4, 0.18, bot, 0.17))

	# --- markings: low-vis star-and-bar on the intake and the wings, the wing's
	# tail code and serial on the fin
	for sd in [1.0, -1.0]:
		var L := "L" if sd < 0.0 else ""
		_insignia(k, m, "f16_ins" + L, Vector3(sd * 0.585, y0 - 0.84, z0 + 7.3), Vector3(sd, 0, 0), Vector3(0, 0, -sd), 0.2, team, dark, bot)
		if team == 0:
			_text(k, m, "f16_tc" + L, "WW", Vector3(0, y0 + 1.25, z0 + 12.1), Vector3(sd, 0, 0), Vector3(0, 0, -sd), 0.42, dark, fp)
			_text(k, m, "f16_sn" + L, "0068", Vector3(0, y0 + 1.04, z0 + 12.1), Vector3(sd, 0, 0), Vector3(0, 0, -sd), 0.12, dark, fp)
	var iw := VmPlane.surf_at(ws, 3.2)
	var ile: Vector3 = iw[0]
	_insignia(k, m, "f16_wins", Vector3(-3.2, ile.y, ile.z + float(iw[1]) * 0.5), Vector3.UP, Vector3(0, 0, -1), 0.3, team, dark, top, ["surf", _msecs(ws)])
	_insignia(k, m, "f16_wins2", Vector3(3.2, ile.y, ile.z + float(iw[1]) * 0.5), Vector3.DOWN, Vector3(0, 0, -1), 0.3, team, dark, bot, ["surf", ws])
	VmPlane.wing_marks(k, m, team, ws, 3.95, 0.35)

	# --- landing gear (shown on the ground): the short nose leg behind the
	# intake, the main legs splayed out from under the strakes, open doors
	if OS.has_environment("FL_GEAR_UP"):
		return
	var g := _gear_node(k)
	var na := Vector3(0, yg + 0.23, z0 + 5.55)
	_leg(k, g, Vector3(0, y0 - 1.08, z0 + 5.45), na, 0.055)
	_awheel(k, g, na, 0.23, 0.15)
	k._box(g, Vector3(0.05, 0.03, 0.08), na + Vector3(0, 0.33, -0.06), "paint", Color(0.85, 0.85, 0.8), Vector3.ZERO, false)
	for sd in [1.0, -1.0]:
		var L := "L" if sd < 0.0 else ""
		var dn := Vector3(sd * 0.5, -0.85, 0)
		_put(k, g, _slab("f16_ndoor" + L, Vector3(sd * 0.16, y0 - 1.1, z0 + 5.4), Vector3(sd * 0.16, y0 - 1.1, z0 + 6.55),
			Vector3(sd * 0.2, y0 - 1.45, z0 + 6.5), Vector3(sd * 0.2, y0 - 1.45, z0 + 5.45), 0.025), A, bot)
		var ma := Vector3(sd * 1.18, yg + 0.36, z0 + 9.3)
		var tp := _project(Vector3(sd * 0.8, y0 - 0.5, z0 + 9.1), Vector3.DOWN, -0.02, hp)
		_leg(k, g, tp, ma + Vector3(-sd * 0.14, 0, 0), 0.075)
		VmPlane.rod(k, g, _project(Vector3(sd * 0.72, y0 - 0.5, z0 + 8.4), Vector3.DOWN, -0.02, hp), ma + Vector3(-sd * 0.12, 0.45, -0.05), 0.035, "paint", WHITE, 6)
		_awheel(k, g, ma, 0.36, 0.22)
		# the main door hangs from the strake outboard of the well
		var h0 := _project(Vector3(sd * 1.0, y0 - 0.5, z0 + 8.15), Vector3.DOWN, 0.0, hp)
		var h1 := _project(Vector3(sd * 1.0, y0 - 0.5, z0 + 9.95), Vector3.DOWN, 0.0, hp)
		_put(k, g, _slab("f16_mdoor" + L, h0, h1, h1 + Vector3(sd * 0.22, -0.62, 0), h0 + Vector3(sd * 0.22, -0.62, 0), 0.03), A, bot)
		_decal(k, g, "f16_well" + L, _rect2(Vector2.ZERO, Vector2(1.8, 0.34)), Vector3(sd * 0.82, y0 - 0.3, z0 + 9.05), dn, Vector3(0, 0, 1), Color(0.3, 0.3, 0.3), 0.012, hp)


## GBU-31(V)1 JDAM: a Mk 84 2,000 lb bomb (olive, yellow nose band) with
## the strake kit along its middle and the JDAM tail kit's four fins.
static func _gbu31(k: VehicleModels, p: Node3D, c: Vector3) -> void:
	var r := 0.229
	var ol := VmPlane.OLIVE
	VmPlane.body(k, p, "ft_mk84", [[-1.94, 0, 0.02, 0.02, 0.02], [-1.78, 0, r * 0.42, r * 0.42, r * 0.42], [-1.5, 0, r * 0.76, r * 0.76, r * 0.76],
		[-1.05, 0, r * 0.96, r * 0.96, r * 0.96], [-0.7, 0, r, r, r], [0.45, 0, r, r, r], [0.92, 0, r * 0.84, r * 0.84, r * 0.84],
		[0.95, 0, r * 0.88, r * 0.88, r * 0.88], [1.8, 0, r * 0.8, r * 0.8, r * 0.8], [1.94, 0, r * 0.6, r * 0.6, r * 0.6]], "paint", ol, 16, 50.0, c)
	k._cyl(p, r * 0.98, r * 0.98, 0.06, c + Vector3(0, 0, -1.25), Vector3(PI / 2, 0, 0), "paint", Color(0.62, 0.55, 0.22), 16, false)
	k._cyl(p, r * 0.9, r * 0.9, 0.03, c + Vector3(0, 0, 0.94), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 16, false)
	# strakes: either side and below
	for a in [0.0, PI, -PI / 2]:
		var d := Vector3(cos(a), sin(a), 0)
		k._box(p, Vector3(0.012, 0.09, 0.8) if absf(d.y) > 0.5 else Vector3(0.09, 0.012, 0.8), c + d * (r + 0.04) + Vector3(0, 0, -0.25), "paint", ol.darkened(0.1), Vector3.ZERO, false)
	# the tail kit's fins (X)
	var fm := _slab("jdam_fin", Vector3(0, r * 0.7, 1.45), Vector3(0, r * 0.7, 1.93), Vector3(0, r + 0.2, 1.93), Vector3(0, r + 0.2, 1.68), 0.016)
	for i in 4:
		_put(k, p, fm, "paint", ol.darkened(0.08), c, Vector3(0, 0, PI / 4 + PI / 2 * float(i)), false)
	k._box(p, Vector3(0.04, 0.05, 0.08), c + Vector3(0, r, -0.4), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(p, Vector3(0.04, 0.05, 0.08), c + Vector3(0, r, 0.36), "gunmetal_w", null, Vector3.ZERO, false)


## AIM-9X Sidewinder at c: the slender body, the glass seeker dome, small
## fixed fins forward, clipped tail control fins.
static func _aim9x(k: VehicleModels, p: Node3D, c: Vector3) -> void:
	var r := 0.0635
	var col := Color(0.68, 0.69, 0.68)
	k._cyl(p, r, r, 2.86, c + Vector3(0, 0, 0.07), Vector3(PI / 2, 0, 0), "paint", col, 12)
	k._cyl(p, r * 0.55, r, 0.1, c + Vector3(0, 0, -1.41), Vector3(PI / 2, 0, 0), "paint", col, 12, false)
	k._add(p, Res.sphere(r * 0.56, 10), "glass", null, c + Vector3(0, 0, -1.47), Vector3.ZERO, Vector3.ONE, false)
	k._cyl(p, r * 1.02, r * 1.02, 0.06, c + Vector3(0, 0, -0.9), Vector3(PI / 2, 0, 0), "paint", Color(0.6, 0.55, 0.25), 12, false)
	var ff := _slab("aim9x_ff", Vector3(0, r, -1.05), Vector3(0, r, -0.86), Vector3(0, r + 0.04, -0.9), Vector3(0, r + 0.04, -1.0), 0.008)
	var tf := _slab("aim9x_tf", Vector3(0, r, 1.18), Vector3(0, r, 1.5), Vector3(0, r + 0.11, 1.5), Vector3(0, r + 0.11, 1.32), 0.01)
	for i in 4:
		var rot := Vector3(0, 0, PI / 4 + PI / 2 * float(i))
		_put(k, p, ff, "paint", col, c, rot, false)
		_put(k, p, tf, "paint", col, c, rot, false)


## AIM-120C AMRAAM at c: the grey radome, clipped mid-body wings, tail fins.
static func _aim120(k: VehicleModels, p: Node3D, c: Vector3) -> void:
	var r := 0.089
	var col := Color(0.72, 0.73, 0.72)
	VmPlane.body(k, p, "ft_aim120", [[-1.83, 0, 0.01, 0.01, 0.01], [-1.7, 0, r * 0.5, r * 0.5, r * 0.5], [-1.5, 0, r * 0.88, r * 0.88, r * 0.88],
		[-1.3, 0, r, r, r], [1.83, 0, r, r, r]], "paint", col, 12, 50.0, c)
	k._cyl(p, r * 1.01, r * 1.01, 0.05, c + Vector3(0, 0, -1.28), Vector3(PI / 2, 0, 0), "paint", Color(0.6, 0.55, 0.25), 12, false)
	var wf := _slab("aim120_w", Vector3(0, r, -0.35), Vector3(0, r, 0.1), Vector3(0, r + 0.13, 0.08), Vector3(0, r + 0.13, -0.15), 0.01)
	var tf := _slab("aim120_t", Vector3(0, r, 1.5), Vector3(0, r, 1.83), Vector3(0, r + 0.135, 1.83), Vector3(0, r + 0.135, 1.66), 0.01)
	for i in 4:
		var rot := Vector3(0, 0, PI / 4 + PI / 2 * float(i))
		_put(k, p, wf, "paint", col, c, rot, false)
		_put(k, p, tf, "paint", col, c, rot, false)


## AN/AAQ-33 Sniper targeting pod at c: the long body, the faceted nose
## with its sensor window.
static func _sniper(k: VehicleModels, p: Node3D, c: Vector3) -> void:
	var r := 0.15
	var col := Color(0.5, 0.52, 0.54)
	VmPlane.body(k, p, "ft_sniper", [[-0.85, 0, r * 0.98, r * 0.98, r * 0.98], [0.9, 0, r, r, r], [1.1, 0, r * 0.82, r * 0.82, r * 0.82], [1.2, 0, r * 0.45, r * 0.45, r * 0.45]], "paint", col, 14, 50.0, c)
	# the rotating head: a faceted nose, its window
	var hd := []
	for z in [[-0.85, 1.0], [-1.0, 0.95], [-1.12, 0.75], [-1.19, 0.3]]:
		var ring := PackedVector3Array()
		for i in 8:
			var a := TAU * float(i) / 8.0 + PI / 8.0
			ring.append(c + Vector3(cos(a) * r * float(z[1]), sin(a) * r * float(z[1]), float(z[0])))
		hd.append(ring)
	_put(k, p, _skin(hd, "sniper_head", 20.0), "paint", col.darkened(0.12))
	_decal(k, p, "sniper_win", _rect2(Vector2.ZERO, Vector2(0.16, 0.12)), c + Vector3(0, -r * 0.83, -1.07), Vector3(0, -1, -0.6), Vector3(1, 0, 0), Color(0.1, 0.1, 0.12))


## AN/ALQ-184 jamming pod at c: a long can with rounded radome ends and the
## antenna blisters under it.
static func _alq184(k: VehicleModels, p: Node3D, c: Vector3) -> void:
	var r := 0.17
	var col := Color(0.52, 0.54, 0.55)
	VmPlane.body(k, p, "ft_alq184", [[-1.95, 0, 0.02, 0.02, 0.02], [-1.82, 0, r * 0.6, r * 0.6, r * 0.6], [-1.6, 0, r * 0.95, r * 0.95, r * 0.95], [-1.45, 0, r, r, r],
		[1.45, 0, r, r, r], [1.6, 0, r * 0.95, r * 0.95, r * 0.95], [1.82, 0, r * 0.6, r * 0.6, r * 0.6], [1.95, 0, 0.02, 0.02, 0.02]], "paint", col, 14, 50.0, c)
	for z in [-1.45, 1.45]:
		k._cyl(p, r * 1.01, r * 1.01, 0.03, c + Vector3(0, 0, z), Vector3(PI / 2, 0, 0), "paint", col.darkened(0.25), 14, false)
	for z in [-1.1, 1.1]:
		k._add(p, Res.sphere(0.09, 10), "paint", col.lightened(0.1), c + Vector3(0, -r, z), Vector3.ZERO, Vector3(1, 0.6, 1.6), false)


# --- F/A-181 Black Wasp II ----------------------------------------------------------

## A Black Wasp section (8 points, from its axis): the crown, the deck's
## shoulder, the chine (top and bottom: the LEX edge further aft), the
## LEX underside's inner corner, the side wall's foot, the belly's corner,
## the keel.
static func _bw_half(q: Array) -> Array:
	return [Vector2(0, q[1]), Vector2(q[2], q[3]), Vector2(q[4], q[5] + q[6]), Vector2(q[4], q[5] - q[6]),
		Vector2(q[7], q[8]), Vector2(q[9], q[10]), Vector2(q[11], q[12]), Vector2(0, q[13])]


## F/A-181 Black Wasp II (Arma 3 Jets): a carrier stealth fighter - a Super
## Hornet "futurized" with the F-22 and F-35C. A faceted, chined nose under
## the one-piece gold canopy, the chines sweeping out into big LEXes over
## raked caret intakes, a flat deck between them, the F-22's trapezoid wing
## (its trailing edge swept forward) and diamond stabilators, twin fins canted
## out, two engines in nacelles under the deck ending in round nozzles with
## sawtooth lips. Weapons inside: the bay doors closed (sawtooth edges) for
## the bomb run. Two-tone dark ghost grey, low-visibility Navy markings.
static func _blackwasp(k: VehicleModels, team: int) -> void:
	var m := k.root
	var A := "aircraft"
	var top := Color(0.31, 0.33, 0.36) if team != 1 else Color(0.44, 0.41, 0.35)
	var low := Color(0.4, 0.42, 0.45) if team != 1 else Color(0.52, 0.49, 0.42)
	var dark := Color(0.22, 0.23, 0.25) if team != 1 else Color(0.3, 0.28, 0.24)
	var line := top.darkened(0.35)
	var y0 := 1.35  # the fuselage axis
	var yg := y0 - 1.75  # the ground under the wheels

	# --- fuselage: [z, crown, shoulder x y, chine x y half-thickness, LEX
	# underside corner x y, side wall foot x y, belly corner x y, keel]
	var st := []
	for q in [[-8.6, 0.01, 0.006, 0.008, 0.02, -0.02, 0.002, 0.016, -0.024, 0.012, -0.028, 0.004, -0.032, -0.033],
			[-8.2, 0.12, 0.07, 0.1, 0.2, -0.04, 0.004, 0.16, -0.08, 0.12, -0.12, 0.05, -0.15, -0.155],
			[-7.4, 0.33, 0.2, 0.28, 0.48, -0.06, 0.005, 0.39, -0.18, 0.3, -0.3, 0.12, -0.36, -0.37],
			[-6.4, 0.5, 0.3, 0.43, 0.7, -0.06, 0.006, 0.575, -0.25, 0.45, -0.44, 0.18, -0.52, -0.53],
			[-5.5, 0.6, 0.36, 0.53, 0.84, -0.04, 0.008, 0.7, -0.27, 0.56, -0.5, 0.24, -0.6, -0.61],
			[-4.5, 0.66, 0.42, 0.58, 1.0, 0.0, 0.01, 0.8, -0.26, 0.6, -0.55, 0.3, -0.65, -0.655],
			[-3.6, 0.7, 0.48, 0.62, 1.22, 0.03, 0.012, 0.66, -0.04, 0.6, -0.6, 0.38, -0.67, -0.672],
			[-2.6, 0.72, 0.55, 0.64, 1.47, 0.05, 0.014, 0.62, -0.01, 0.6, -0.6, 0.4, -0.672, -0.675],
			[-1.4, 0.72, 0.62, 0.64, 1.68, 0.07, 0.016, 0.62, 0.0, 0.6, -0.6, 0.4, -0.672, -0.675],
			[0.5, 0.7, 0.7, 0.62, 1.72, 0.07, 0.016, 0.62, 0.0, 0.6, -0.6, 0.4, -0.672, -0.675],
			[2.5, 0.66, 0.74, 0.58, 1.7, 0.06, 0.016, 0.62, 0.0, 0.6, -0.6, 0.4, -0.67, -0.672],
			[4.2, 0.58, 0.72, 0.52, 1.55, 0.04, 0.016, 0.6, -0.02, 0.56, -0.52, 0.36, -0.6, -0.62],
			[5.5, 0.42, 0.6, 0.38, 1.3, 0.02, 0.016, 0.5, -0.04, 0.4, -0.38, 0.25, -0.46, -0.48],
			[6.3, 0.28, 0.42, 0.26, 0.9, -0.02, 0.014, 0.35, -0.06, 0.28, -0.26, 0.18, -0.32, -0.34],
			[6.85, 0.17, 0.24, 0.15, 0.42, -0.04, 0.012, 0.2, -0.08, 0.16, -0.17, 0.1, -0.21, -0.22]]:
		st.append([float(q[0]), _bw_half(q)])
	var rows := _rows(st, 3)
	var hp := ["hull", rows, y0]
	_hull(k, m, "bw_up", rows, y0, A, top, 0, 3, 0, -1, 16.0)
	_hull(k, m, "bw_lo", rows, y0, A, low, 3, 7, 0, -1, 16.0)

	# the F-22-style one-piece canopy, gold-coated, its sill frame
	var cst := [[-5.7, y0 + 0.5, 0.1, 0.02, 0.04], [-5.3, y0 + 0.5, 0.33, 0.24, 0.04, 2.0], [-4.7, y0 + 0.5, 0.45, 0.5, 0.04, 2.1],
		[-4.0, y0 + 0.5, 0.49, 0.6, 0.04, 2.2], [-3.3, y0 + 0.5, 0.48, 0.57, 0.04, 2.2], [-2.6, y0 + 0.5, 0.4, 0.42, 0.04, 2.1],
		[-2.0, y0 + 0.5, 0.26, 0.22, 0.04, 2.0], [-1.5, y0 + 0.5, 0.1, 0.06, 0.04, 2.0]]
	_glaze(k, VmPlane.body(k, m, "ft_bw_can", cst, "glass", null, 24, 60.0), Color(0.62, 0.46, 0.16), 0.85)
	VmPlane.stripe(k, m, "ft_bw_rail", cst, -5.65, -1.55, -0.05, 0.1, A, dark, 0.01, 4)
	VmPlane.stripe(k, m, "ft_bw_railL", cst, -5.65, -1.55, PI - 0.1, PI + 0.05, A, dark, 0.01, 4)

	# --- intakes and engine nacelles: caret mouths raked in two planes, the
	# ducts turning round into the engines, the nozzles
	var ns := [[-2.75, _qloop(0.55, 1.33, 1.15, 0.0, -0.68)], [-1.0, _qloop(0.55, 1.35, 1.17, 0.0, -0.68)],
		[1.0, _qloop(0.55, 1.32, 1.15, 0.0, -0.68)], [2.8, _mixloop(_qloop(0.5, 1.25, 1.12, 0.05, -0.68), _cloop(0.66, -0.2, 0.5), 0.5)],
		[4.4, _cloop(0.66, -0.2, 0.5)], [6.4, _cloop(0.66, -0.2, 0.47)]]
	var nrows := _rows(ns, 2)
	var lipz := [-3.35, -3.15, -3.0, -3.05, -3.25, -3.42, -3.6, -3.7, -3.8, -3.85, -3.7, -3.52]
	for sd in [1.0, -1.0]:
		var L := "L" if sd < 0.0 else ""
		var rings := []
		if not _mc.has("ft_bw_nac" + L):
			for r in nrows:
				rings.append(_loop(r[1], r[0], y0, sd))
		_put(k, m, _skin(rings, "bw_nac" + L, 40.0), A, low)
		var lip := PackedVector3Array()
		for i in 12:
			var v: Vector2 = nrows[0][1][i]
			lip.append(Vector3(sd * v.x, y0 + v.y, lipz[i]))
		_duct(k, m, "bw_in" + L, lip, _loop(nrows[0][1], nrows[0][0], y0, sd), 0.04, A, low, low.darkened(0.42), -1.0, 30.0)
		# the nozzle: a hollow can, short sawtooth teeth round its lip, the
		# flame holder deep inside
		var nc := Vector3(sd * 0.66, y0 - 0.2, 6.4)
		var nl := PackedVector3Array()
		var nb := PackedVector3Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			nl.append(nc + Vector3(cos(a) * 0.43, sin(a) * 0.43, 0.66))
			nb.append(nc + Vector3(cos(a) * 0.47, sin(a) * 0.47, 0.0))
		_duct(k, m, "bw_noz" + L, nl, nb, 0.025, "gunmetal_w", top.darkened(0.3), Color(0.3, 0.27, 0.24), 1.0)
		_petals(k, m, "bw_teeth", nc + Vector3(0, 0, 0.62), 16, 0.433, 0.422, 0.2, 0.96, 0.3, 0.022, top.darkened(0.3))
		_burner(k, m, nc + Vector3(0, 0, 0.02), 0.4)
	VmPlane.glow(k, m, [Vector3(-0.66, y0 - 0.2, 7.45), Vector3(0.66, y0 - 0.2, 7.45)], 1.25)

	# --- wing: trapezoid, LE flaps, flaperons inboard, ailerons outboard
	var ws := [[Vector3(1.4, y0 + 0.07, -1.635), 6.7, 0.3], [Vector3(1.75, y0 + 0.052, -1.341), 6.31, 0.29],
		[Vector3(4.2, y0 - 0.076, 0.714), 3.62, 0.17], [Vector3(6.0, y0 - 0.17, 2.25), 1.62, 0.08], [Vector3(6.2, y0 - 0.18, 2.42), 1.4, 0.07]]
	_surf(k, m, "bw_wing", ws, A, top, [[], [[0.1, 0.8], [0.12, 0.76]], [[0.12, 0.76], [0.14, 0.72]], [[0.14], [0.14]]], true, 28.0)
	# diamond stabilators on the tail shelves
	_surf(k, m, "bw_stab", [[Vector3(0.85, y0 + 0.0, 3.86), 3.55, 0.15], [Vector3(1.0, y0 + 0.0, 4.0), 3.4, 0.14], [Vector3(3.55, y0 - 0.02, 6.3), 0.85, 0.04]], A, top, [], true, 28.0)
	# twin fins canted 22 degrees out, rudders
	var cv := Vector3(sin(deg_to_rad(22.0)), cos(deg_to_rad(22.0)), 0)
	var fr := Vector3(1.0, y0 + 0.42, 1.4)
	var fin := [[fr - cv * 0.25 + Vector3(0, 0, -0.1), 3.3, 0.16], [fr, 3.1, 0.15], [fr + cv * 2.1 + Vector3(0, 0, 2.1 * 0.78), 1.55, 0.07],
		[fr + cv * 2.6 + Vector3(0, 0, 2.6 * 0.78), 1.15, 0.05]]
	_surf(k, m, "bw_fin", fin, A, top, [[], [[0.72], [0.66]], []], true, 28.0)

	# --- details: the gun port in the right LEX, the EOTS window under the
	# nose, the tail hook, antennas, lights
	var gn := Vector3(0.5, 0.87, 0)
	var gun := _project(Vector3(1.02, y0 + 0.2, -2.2), gn, 0.0, hp)
	_decal(k, m, "bw_gun", _rect2(Vector2.ZERO, Vector2(0.11, 0.42)), gun, gn, Vector3(1, 0, 0), Color(0.1, 0.1, 0.1), 0.006, hp)
	k.mg_tip = k._tip(m, gun + Vector3(0, 0.02, -0.25))
	k.gun_tip = k.mg_tip
	var eo := []
	for q in [[-6.75, 0.02, 0.02], [-6.6, 0.15, 0.1], [-6.15, 0.14, 0.09], [-5.98, 0.02, 0.02]]:
		var ring := PackedVector3Array()
		for i in 6:
			var a := TAU * float(i) / 6.0
			ring.append(Vector3(cos(a) * float(q[1]), y0 - 0.5 + minf(0.0, sin(a)) * float(q[2]) + 0.03, float(q[0])))
		eo.append(ring)
	_glaze(k, _put(k, m, _skin(eo, "bw_eots", 12.0), "glass", null), Color(0.55, 0.42, 0.18), 0.85)
	# the arrestor hook stowed between the nozzles, its point showing
	VmPlane.rod(k, m, Vector3(0, y0 - 0.3, 5.0), Vector3(0, y0 - 0.25, 6.95), 0.05, "paint", dark, 8)
	k._box(m, Vector3(0.1, 0.08, 0.2), Vector3(0, y0 - 0.25, 7.02), "paint", Color(0.7, 0.68, 0.6), Vector3.ZERO, false)
	VmPlane.antenna(k, m, Vector3(0, y0 + 0.72, -0.4), 0.14, false, top.darkened(0.1))
	VmPlane.antenna(k, m, Vector3(0, y0 - 0.675, 2.6), 0.14, true, low.darkened(0.1))
	VmPlane.nav_lights(k, m, Vector3(6.18, y0 - 0.18, 2.95), 0.05)
	var fl := Color(0.46, 0.5, 0.4)
	for sd in [1.0, -1.0]:
		var L := "L" if sd < 0.0 else ""
		var fp := ["surf", fin if sd > 0.0 else _msecs(fin)]
		var fo := Vector3(sd * (fr.x + cv.x * 1.3), fr.y + cv.y * 1.3, fr.z + 1.3 * 0.78 + 0.45)
		_decal(k, m, "bw_flf" + L, _rect2(Vector2.ZERO, Vector2(0.5, 0.06)), fo, Vector3(sd * cv.y, -cv.x, 0), Vector3(0, -cv.y, 0.78), fl, 0.006, fp)
		_decal(k, m, "bw_fln" + L, _rect2(Vector2.ZERO, Vector2(0.4, 0.05)), Vector3(sd * 0.6, y0 - 0.15, -5.6), Vector3(sd * 0.83, -0.56, 0), Vector3(0, 0, 1), fl, 0.006, hp)

	# --- panel lines: the weapon bay doors and the gear doors (sawtooth ends),
	# the radome joint, access panels on the deck
	var dn := Vector3.DOWN
	var yb := y0 - 0.675
	var pl := []
	pl.append_array(_zigzag(Vector3(-0.54, yb, -2.3), Vector3(0.54, yb, -2.3), dn, Vector3(0, 0, -1), 0.14, 4))
	pl.append_array(_zigzag(Vector3(-0.54, yb, 1.9), Vector3(0.54, yb, 1.9), dn, Vector3(0, 0, 1), 0.14, 4))
	for x in [-0.54, 0.0, 0.54]:
		pl.append([Vector3(x, yb, -2.3), Vector3(x, yb, 1.9), dn])
	for sd in [1.0, -1.0]:
		pl.append_array(_zigzag(Vector3(sd * 0.62, y0 - 0.68, -0.4), Vector3(sd * 1.12, y0 - 0.68, -0.4), dn, Vector3(0, 0, -1), 0.12, 3))
		pl.append_array(_zigzag(Vector3(sd * 0.62, y0 - 0.68, 1.4), Vector3(sd * 1.12, y0 - 0.68, 1.4), dn, Vector3(0, 0, 1), 0.12, 3))
		pl.append([Vector3(sd * 0.62, y0 - 0.68, -0.4), Vector3(sd * 0.62, y0 - 0.68, 1.4), dn])
		pl.append([Vector3(sd * 1.12, y0 - 0.68, -0.4), Vector3(sd * 1.12, y0 - 0.68, 1.4), dn])
	_lines(k, m, "bw_bays", pl, 0.016, low.darkened(0.35))
	var nl2 := _zigzag(Vector3(-0.19, yb, -5.9), Vector3(0.19, yb, -5.9), dn, Vector3(0, 0, -1), 0.1, 2)
	for x in [-0.19, 0.0, 0.19]:
		nl2.append([Vector3(x, yb, -5.9), Vector3(x, yb, -4.4), dn])
	nl2.append([Vector3(-0.19, yb, -4.4), Vector3(0.19, yb, -4.4), dn])
	_lines(k, m, "bw_nbay", nl2, 0.016, low.darkened(0.35), hp)
	var dk := []
	for sd in [1.0, -1.0]:
		# the radome joint: a sawtooth across the chined nose
		var rn := Vector3(sd * 0.75, 0.66, 0)
		dk.append_array(_zigzag(Vector3(0, y0 + 0.4, -6.1), Vector3(sd * 0.3, y0 + 0.4, -6.1), Vector3(0, 1, 0), Vector3(0, 0, -1), 0.12, 2))
		dk.append_array(_zigzag(Vector3(sd * 0.3, y0 + 0.4, -6.1), Vector3(sd * 0.68, y0 - 0.0, -6.1), rn, Vector3(0, 0, -1), 0.12, 3))
		# deck access panels and the fuel tank doors over the LEX
		dk.append_array(_outline([Vector3(sd * 0.25, y0 + 0.6, -0.6), Vector3(sd * 0.55, y0 + 0.6, -0.6), Vector3(sd * 0.55, y0 + 0.6, 0.6), Vector3(sd * 0.25, y0 + 0.6, 0.6)], Vector3.UP))
		dk.append_array(_outline([Vector3(sd * 0.95, y0 + 0.3, 0.9), Vector3(sd * 1.3, y0 + 0.2, 0.9), Vector3(sd * 1.3, y0 + 0.2, 2.2), Vector3(sd * 0.95, y0 + 0.3, 2.2)], Vector3(sd * 0.5, 0.9, 0)))
	_lines(k, m, "bw_deck", dk, 0.016, line, hp)
	var fold := []
	for sd in [1.0, -1.0]:
		fold.append([Vector3(sd * 4.4, y0, 0.9), Vector3(sd * 4.4, y0, 4.2), Vector3.UP])
	_lines(k, m, "bw_fold", fold, 0.018, line, ["surf", ws])
	# the side weapon bays in the intake walls, the engine bay doors under the
	# nacelles, the refuelling probe's door on the right of the nose
	var sbl := []
	for sd in [1.0, -1.0]:
		var wn := Vector3(sd * 0.967, -0.256, 0)
		var a0 := Vector3(sd * 1.31, y0 - 0.15, -2.1)
		var a1 := Vector3(sd * 1.205, y0 - 0.55, -2.1)
		var b0 := Vector3(sd * 1.305, y0 - 0.15, -0.7)
		var b1 := Vector3(sd * 1.2, y0 - 0.55, -0.7)
		sbl.append_array(_zigzag(a0, a1, wn, Vector3(0, 0, -1), 0.09, 2))
		sbl.append_array(_zigzag(b0, b1, wn, Vector3(0, 0, 1), 0.09, 2))
		sbl.append([a0, b0, wn])
		sbl.append([a1, b1, wn])
		sbl.append_array(_outline([Vector3(sd * 0.72, y0 - 0.682, 1.3), Vector3(sd * 1.08, y0 - 0.682, 1.3), Vector3(sd * 1.08, y0 - 0.682, 2.6), Vector3(sd * 0.72, y0 - 0.682, 2.6)], dn))
	_lines(k, m, "bw_sbay", sbl, 0.016, low.darkened(0.35))
	var pn := Vector3(0.73, 0.68, 0)
	_lines(k, m, "bw_probe", _outline([Vector3(0.36, y0 + 0.3, -6.3), Vector3(0.6, y0 + 0.12, -6.3), Vector3(0.66, y0 + 0.08, -5.2), Vector3(0.42, y0 + 0.28, -5.2)], pn), 0.014, line, hp)
	for sd in [1.0, -1.0]:
		for q in [[-7.05, 0.22, 0.75], [-6.9, 0.32, -0.6]]:
			var an := Vector3(sd * absf(float(q[2])), signf(float(q[2])) * 0.6, 0)
			_decal(k, m, "bw_ads%d%s" % [int(float(q[0]) * -100.0), "L" if sd < 0.0 else ""], _circle2(0.025, 8), Vector3(sd * float(q[1]), y0 + 0.05 * signf(float(q[2])), float(q[0])), an, Vector3(0, 0, 1), Color(0.15, 0.15, 0.15), 0.005, hp)
	# radar-absorbent dark caps on the fin tips
	var ta: Vector3 = fr + cv * 2.45 + Vector3(0, 0, 2.45 * 0.78 - 0.006)
	var tb: Vector3 = fr + cv * 2.62 + Vector3(0, 0, 2.62 * 0.78 - 0.006)
	_surf(k, m, "bw_fintip", [[ta, 1.282, 0.07], [tb, 1.15, 0.06]], A, dark, [], true, 28.0)

	# --- markings: low-visibility Navy star-and-bar, the air wing's tail
	# code, the modex on the nose
	for sd in [1.0, -1.0]:
		var L := "L" if sd < 0.0 else ""
		_insignia(k, m, "bw_ins" + L, Vector3(sd * 1.244, y0 - 0.34, 0.3), Vector3(sd * 0.969, -0.247, 0), Vector3(0, 0, -sd), 0.2, team, dark, low)
		if team == 0:
			var fp := ["surf", fin if sd > 0.0 else _msecs(fin)]
			var fn := Vector3(sd * cv.y, -cv.x, 0)
			var to := Vector3(sd * (fr.x + cv.x * 0.62), fr.y + cv.y * 0.62, 3.15)
			_text(k, m, "bw_tc" + L, "NH", to, fn, Vector3(0, 0, -sd), 0.4, dark, fp)
			_text(k, m, "bw_mx" + L, "100", Vector3(sd * 0.6, y0 + 0.18, -5.0), Vector3(sd * 0.73, 0.68, 0), Vector3(0, 0, -sd), 0.2, dark, hp)
	var iw := VmPlane.surf_at(ws, 3.6)
	var ile: Vector3 = iw[0]
	_insignia(k, m, "bw_wins", Vector3(-3.6, ile.y, ile.z + float(iw[1]) * 0.45), Vector3.UP, Vector3(0, 0, -1), 0.32, team, dark, top, ["surf", _msecs(ws)])
	_insignia(k, m, "bw_wins2", Vector3(3.6, ile.y, ile.z + float(iw[1]) * 0.45), Vector3.DOWN, Vector3(0, 0, -1), 0.32, team, dark, low, ["surf", ws])
	VmPlane.wing_marks(k, m, team, ws, 5.0, 0.45)

	# --- landing gear (shown on the ground): twin nose wheels with the
	# catapult launch bar, the main legs out of the intake trunks, open doors
	if OS.has_environment("FL_GEAR_UP"):
		return
	var g := _gear_node(k)
	var na := Vector3(0, yg + 0.28, -5.2)
	_leg(k, g, _project(Vector3(0, y0, -4.8), Vector3.DOWN, -0.02, hp), na, 0.07)
	for sd in [1.0, -1.0]:
		_awheel(k, g, na + Vector3(sd * 0.15, 0, 0), 0.28, 0.17)
	VmPlane.rod(k, g, na + Vector3(0, 0.25, -0.1), Vector3(0, yg + 0.12, -5.85), 0.03, "paint", WHITE, 6)
	VmPlane.rod(k, g, _project(Vector3(0, y0, -4.45), Vector3.DOWN, -0.02, hp), na + Vector3(0, 0.75, 0.05), 0.04, "paint", WHITE, 6)
	for sd in [1.0, -1.0]:
		var L := "L" if sd < 0.0 else ""
		var d0 := _project(Vector3(sd * 0.19, y0, -5.85), Vector3.DOWN, 0.0, hp)
		var d1 := _project(Vector3(sd * 0.19, y0, -4.45), Vector3.DOWN, 0.0, hp)
		_put(k, g, _slab("bw_ndoor" + L, d0, d1, d1 + Vector3(sd * 0.04, -0.5, 0), d0 + Vector3(sd * 0.04, -0.5, 0), 0.025), A, low)
		var ma := Vector3(sd * 1.45, yg + 0.38, 0.9)
		_leg(k, g, Vector3(sd * 0.95, yb - 0.005, 0.4), ma + Vector3(-sd * 0.16, 0, 0), 0.085)
		VmPlane.rod(k, g, Vector3(sd * 0.75, yb - 0.005, -0.2), ma + Vector3(-sd * 0.14, 0.55, -0.05), 0.04, "paint", WHITE, 6)
		_awheel(k, g, ma, 0.38, 0.26)
		_put(k, g, _slab("bw_mdoor" + L, Vector3(sd * 0.64, yb - 0.01, -0.35), Vector3(sd * 0.64, yb - 0.01, 1.35),
			Vector3(sd * 0.58, yb - 0.62, 1.3), Vector3(sd * 0.58, yb - 0.62, -0.3), 0.03), A, low)
		_decal(k, g, "bw_well" + L, _rect2(Vector2.ZERO, Vector2(0.46, 1.7)), Vector3(sd * 0.88, y0 - 0.68, 0.5), Vector3.DOWN, Vector3(1, 0, 0), Color(0.3, 0.3, 0.3), 0.012)
	_decal(k, g, "bw_nwell", _rect2(Vector2.ZERO, Vector2(0.36, 1.4)), Vector3(0, y0, -5.15), Vector3.DOWN, Vector3(1, 0, 0), Color(0.3, 0.3, 0.3), 0.012, hp)
