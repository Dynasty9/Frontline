class_name VmPlane
extends RefCounted
## Procedural models: fixed-wing aircraft and fixed-wing drones.
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys must be unique per shape).
##
## Aircraft are built in flight (gear up, except the fixed-gear ones) round
## their fuselage: the fuselage is centred on the origin's XZ with its belly a
## little above y = 0. Fuselages, nacelles, canopies, tanks and stores are
## smooth-shaded lofts through superellipse cross-sections (body()); wings,
## tails, fins and blades are airfoil lofts through spanwise sections
## (surf()), with their control surfaces cut out behind a hairline gap.
## Propellers: a pivot per propeller in k.wheels, spinning about its local Z
## (as the AC-130's do), holding "Blades" and a "Blur" disc.
## Jet exhaust glow: a node named "Afterburner" (skipped when burnt).

## Every model key this file builds (the Field Manual's model pages list them).
const KEYS: Array[String] = ["buzzard", "gryphon", "wipeout", "caesar", "blackwasp", "shikra", "neophron",
	"greyhawk", "sentinel", "fenghuang", "blackfish", "blackfish_armed", "xian"]

const NATO := Color(0.42, 0.45, 0.48)
const CSAT := Color(0.47, 0.44, 0.38)
const AAF := Color(0.4, 0.43, 0.38)
const OLIVE := Color(0.33, 0.35, 0.27)  # bombs and rocket pods
const STORE_GREY := Color(0.55, 0.56, 0.55)  # missiles

static var _mc := {}


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"buzzard":
			_buzzard(k, team)
		"gryphon":
			_gryphon(k, team)
		"wipeout":
			_wipeout(k, team)
		"caesar":
			_caesar(k, team, seed)
		"blackwasp":
			_blackwasp(k, team)
		"shikra":
			_shikra(k, team)
		"neophron":
			_neophron(k, team)
		"greyhawk":
			_greyhawk(k, team)
		"sentinel":
			_sentinel(k, team)
		"fenghuang":
			_fenghuang(k, team)
		"blackfish":
			_blackfish(k, team, false)
		"blackfish_armed":
			_blackfish(k, team, true)
		"xian":
			_xian(k, team)
		_:
			return false
	return true


# --- mesh helpers ------------------------------------------------------------------

## A smooth-shaded solid lofted through convex rings (all the same point
## count): normals are averaged across edges flatter than `crease` degrees
## (sharp chines, leading and trailing edges stay hard), both ends capped flat.
## Cached by key.
static func skin(rings: Array, key: String, crease := 40.0) -> ArrayMesh:
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
			fn[i * n + j] = v
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
	for e in [0, nr - 1]:
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


## Pads a station [z, y, w, ht, hb, (et, eb, x, rake_y, rake_x)] to all ten
## values. A raked section (an intake lip) moves aft by rake_y per metre above
## its centre and rake_x per metre outboard.
static func _sp(s: Array) -> Array:
	var o := s.duplicate()
	while o.size() < 10:
		o.append([2.0, 2.0, 0.0, 0.0, 0.0][o.size() - 5])
	return o


## A fuselage cross-section round the axis: centre (x, y) at z, half-width w,
## half-heights ht above and hb below, each half a superellipse of exponent
## et / eb (2 an ellipse; below 2 pinched to a chine; above 2 boxy).
static func sec(s: Array, n := 20, grow := 0.0) -> PackedVector3Array:
	var q := _sp(s)
	var z: float = q[0]
	var y: float = q[1]
	var w: float = q[2]
	var ht: float = q[3]
	var hb: float = q[4]
	if w > 0.0:
		w += grow
		ht += grow
		hb += grow
	var et: float = q[5]
	var eb: float = q[6]
	var x: float = q[7]
	var r := PackedVector3Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var c := cos(a)
		var sn := sin(a)
		var e := et if sn >= 0.0 else eb
		var px := w * signf(c) * pow(absf(c), 2.0 / e)
		var py := (ht if sn >= 0.0 else hb) * signf(sn) * pow(absf(sn), 2.0 / e)
		r.append(Vector3(x + px, y + py, z + py * float(q[8]) + px * float(q[9])))
	return r


## The station interpolated at z.
static func st_at(st: Array, z: float) -> Array:
	var a0 := _sp(st[0])
	if z <= float(a0[0]):
		return a0
	for i in st.size() - 1:
		var a := _sp(st[i])
		var b := _sp(st[i + 1])
		if z <= float(b[0]):
			var t := (z - float(a[0])) / maxf(1e-4, float(b[0]) - float(a[0]))
			var o := []
			for j in 10:
				o.append(lerpf(float(a[j]), float(b[j]), t))
			return o
	return _sp(st[st.size() - 1])


## A smooth lofted body through stations (see sec()).
static func body(k: VehicleModels, p: Node3D, key: String, st: Array, mat: String, col, n := 20, crease := 40.0, pos := Vector3.ZERO) -> MeshInstance3D:
	var kk := "pl_" + key
	var rings := []
	if not _mc.has(kk):
		for s in st:
			rings.append(sec(s, n))
	return k._add(p, skin(rings, kk, crease), mat, col, pos)


## body() and its mirror image across x = 0 (stations give their own x).
static func body2(k: VehicleModels, p: Node3D, key: String, st: Array, mat: String, col, n := 16, crease := 40.0) -> void:
	body(k, p, key, st, mat, col, n, crease)
	var ms := []
	for s in st:
		ms.append(_mx(s))
	body(k, p, key + "_L", ms, mat, col, n, crease)


## The mirror of station s across x = 0.
static func _mx(s: Array) -> Array:
	var q := _sp(s)
	q[7] = -float(q[7])
	q[9] = -float(q[9])
	return q


## A band round a body at z (canopy bows, intake lips, panel joints): the
## section there, grown by `grow`, `len` long.
static func band(k: VehicleModels, p: Node3D, key: String, st: Array, z: float, len: float, grow: float, mat: String, col, n := 20) -> void:
	var kk := "pl_" + key
	var rings := []
	if not _mc.has(kk):
		rings = [sec(st_at(st, z - len * 0.5), n, grow), sec(st_at(st, z + len * 0.5), n, grow)]
	k._add(p, skin(rings, kk, 50.0), mat, col, Vector3.ZERO)


## A strip of paint (a livery stripe, a radome, a walkway) laid over a body
## from z0 to z1, between section angles a0 and a1 (radians: 0 the right side's
## widest point, PI/2 the top, PI the left side), standing `grow` proud. Each
## slice is the arc closed by its chord: a thin convex sliver.
static func stripe(k: VehicleModels, p: Node3D, key: String, st: Array, z0: float, z1: float, a0: float, a1: float, mat: String, col, grow := 0.006, steps := 6) -> void:
	var kk := "pl_" + key
	var rings := []
	if not _mc.has(kk):
		var zs: Array = [z0]
		for s in st:
			if float(s[0]) > z0 + 0.05 and float(s[0]) < z1 - 0.05:
				zs.append(float(s[0]))
		zs.append(z1)
		for z in zs:
			var q := st_at(st, z)
			var r := PackedVector3Array()
			for i in steps:
				var a := lerpf(a0, a1, float(i) / float(steps - 1))
				var c := cos(a)
				var sn := sin(a)
				var e: float = q[5] if sn >= 0.0 else q[6]
				var px := (float(q[2]) + grow) * signf(c) * pow(absf(c), 2.0 / e)
				var py := (float(q[3] if sn >= 0.0 else q[4]) + grow) * signf(sn) * pow(absf(sn), 2.0 / e)
				r.append(Vector3(float(q[7]) + px, float(q[1]) + py, z))
			rings.append(r)
	k._add(p, skin(rings, kk, 50.0), mat, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)


## A dark disc just proud of a body's flat end (an intake mouth, a jet pipe):
## the station s shrunk to `inset`, facing -z (dir -1) or +z (dir 1).
static func mouth(k: VehicleModels, p: Node3D, key: String, s: Array, inset: float, dir := -1.0, mat := "plain_dark") -> void:
	var q := _sp(s)
	var a := q.duplicate()
	var b := q.duplicate()
	for j in [2, 3, 4]:
		a[j] = float(q[j]) * inset
		b[j] = float(q[j]) * inset
	a[0] = float(q[0]) + dir * 0.012
	b[0] = float(q[0]) - dir * 0.03
	var kk := "pl_" + key
	var rings := []
	if not _mc.has(kk):
		rings = [sec(a if dir < 0.0 else b, 16), sec(b if dir < 0.0 else a, 16)]
	k._add(p, skin(rings, kk, 50.0), mat, null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)


const FOIL := [0.0, 0.0, 0.03, 0.52, 0.1, 0.82, 0.25, 1.0, 0.45, 0.94, 0.7, 0.6, 1.0, 0.1]


## Thickness factor of the airfoil at chord fraction f.
static func _foil_t(f: float) -> float:
	for i in range(0, FOIL.size() - 2, 2):
		if f <= float(FOIL[i + 2]):
			return lerpf(float(FOIL[i + 1]), float(FOIL[i + 3]), (f - float(FOIL[i])) / (float(FOIL[i + 2]) - float(FOIL[i])))
	return float(FOIL[FOIL.size() - 1])


## An airfoil ring from chord fraction f0 to f1: leading edge le, chord along
## cdir, thickness th along up. A piece starting behind the leading edge (a
## control surface) gets a rounded hinge nose.
static func foil(le: Vector3, chord: float, th: float, up: Vector3, f0 := 0.0, f1 := 1.0, cdir := Vector3(0, 0, 1)) -> PackedVector3Array:
	var pts: Array = []
	if f0 <= 0.0:
		for i in range(0, FOIL.size(), 2):
			if float(FOIL[i]) < f1 - 0.01:
				pts.append([float(FOIL[i]), float(FOIL[i + 1])])
	else:
		pts.append([f0, 0.0])
		pts.append([f0 + 0.015, _foil_t(f0) * 0.85])
		for i in range(0, FOIL.size(), 2):
			if float(FOIL[i]) > f0 + 0.04 and float(FOIL[i]) < f1 - 0.01:
				pts.append([float(FOIL[i]), float(FOIL[i + 1])])
	pts.append([f1, _foil_t(f1)])
	var r := PackedVector3Array()
	for q in pts:
		r.append(le + cdir * (float(q[0]) * chord) + up * (float(q[1]) * th * 0.5))
	for i in range(pts.size() - 1, -1, -1):
		if float(pts[i][1]) > 0.0:
			r.append(le + cdir * (float(pts[i][0]) * chord) - up * (float(pts[i][1]) * th * 0.5))
	return r


## A lifting surface (wing, tailplane, fin, canard, strake) through spanwise
## sections [leading edge: Vector3, chord, thickness], root first. hinge[i]
## is the chord fraction where panel i (section i to i+1) hangs its control
## surface (0 for none). Mirrored across x = 0 unless `mirror` is false.
static func surf(k: VehicleModels, p: Node3D, key: String, secs: Array, mat: String, col, hinge := [], mirror := true, crease := 32.0) -> void:
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
			var h: float = hinge[i] if i < hinge.size() else 0.0
			var kk := "pl_%s_%d%s" % [key, i, "L" if sd < 0.0 else ""]
			if h <= 0.0:
				var rings := []
				if not _mc.has(kk):
					rings = [foil(la, a[1], a[2], up), foil(lb, b[1], b[2], up)]
				k._add(p, skin(rings, kk, crease), mat, col, Vector3.ZERO)
			else:
				var r1 := []
				var r2 := []
				if not _mc.has(kk + "m"):
					r1 = [foil(la, a[1], a[2], up, 0.0, h), foil(lb, b[1], b[2], up, 0.0, h)]
					r2 = [foil(la, a[1], a[2], up, h + 0.015, 1.0), foil(lb, b[1], b[2], up, h + 0.015, 1.0)]
				k._add(p, skin(r1, kk + "m", crease), mat, col, Vector3.ZERO)
				k._add(p, skin(r2, kk + "c", crease), mat, col, Vector3.ZERO)


## Where a surface is at span x: [leading edge, chord, thickness].
static func surf_at(secs: Array, x: float) -> Array:
	for i in secs.size() - 1:
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		var la: Vector3 = a[0]
		var lb: Vector3 = b[0]
		if x <= lb.x or i == secs.size() - 2:
			var t := clampf((x - la.x) / maxf(1e-4, lb.x - la.x), 0.0, 1.0)
			return [la.lerp(lb, t), lerpf(a[1], b[1], t), lerpf(a[2], b[2], t)]
	return secs[0]


## A rod from a to b (radius r at a, r2 at b): struts, probes, gear legs, barrels.
static func rod(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, r: float, mat: String, col = null, segs := 8, r2 := -1.0, shadow := true) -> MeshInstance3D:
	var d := b - a
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var bs := Basis(x, y, x.cross(y))
	return k._add(p, Res.cyl(r if r2 < 0.0 else r2, r, d.length(), segs), mat, col, (a + b) * 0.5, bs.get_euler(), Vector3.ONE, shadow)


# --- engines, glow, propellers -------------------------------------------------------

## The jet exhaust glow (the "Afterburner" node, as on the old jet): a soft
## additive billboard behind each nozzle. Several nozzles share one node.
static func glow(k: VehicleModels, p: Node3D, pts: Array, size: float, col := Color(1.0, 0.55, 0.25)) -> void:
	if k.burnt:
		return
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gm.albedo_color = col
	gm.albedo_texture = Res.puff_mat(true).albedo_texture
	# (the texture's alpha makes it a soft round glow, not a lit square)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var holder: Node3D = p
	if pts.size() > 1:
		var c := Vector3.ZERO
		for v in pts:
			c += v
		c /= pts.size()
		holder = k._pivot(p, c)
		holder.name = "Afterburner"
		var cp: Array = []
		for v in pts:
			cp.append((v as Vector3) - c)
		pts = cp
	for i in pts.size():
		var g := MeshInstance3D.new()
		g.name = "Afterburner" if pts.size() == 1 else "Glow%d" % i
		g.mesh = q
		g.material_override = gm
		g.position = pts[i]
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(g)


## A round jet nozzle at pos facing aft: the outer can, the darker petals ring,
## the black pipe inside.
static func nozzle(k: VehicleModels, p: Node3D, pos: Vector3, r: float, len: float, col: Color, taper := 0.9) -> void:
	k._cyl(p, r * taper, r, len, pos, Vector3(PI / 2, 0, 0), "gunmetal_w", col.darkened(0.45), 18)
	k._cyl(p, r * taper * 0.97, r * taper, 0.06, pos + Vector3(0, 0, len * 0.5 + 0.02), Vector3(PI / 2, 0, 0), "metal_dark", null, 18, false)
	k._cyl(p, r * taper * 0.8, r * taper * 0.8, 0.03, pos + Vector3(0, 0, len * 0.5 + 0.045), Vector3(PI / 2, 0, 0), "plain_dark", null, 16, false)
	k._cyl(p, r * 0.45, r * 0.3, 0.2, pos + Vector3(0, 0, len * 0.5 - 0.1), Vector3(PI / 2, 0, 0), "metal_dark", null, 10, false)


## One propeller blade along `d` (unit, in the disc plane), twisted from
## pitch p0 at the root to p1 at the tip, tapered, its own mesh.
static func _blade(key: String, d: Vector3, axis: Vector3, r0: float, r1: float, chord: float, p0: float, p1: float, th: float) -> ArrayMesh:
	var kk := "pl_" + key
	if _mc.has(kk):
		return _mc[kk]
	var t := axis.cross(d).normalized()
	var rings := []
	var fr := [0.0, 0.25, 0.55, 0.85, 1.0]
	var cf := [0.55, 1.0, 0.95, 0.72, 0.45]
	for i in fr.size():
		var u: float = fr[i]
		var pa := lerpf(p0, p1, u)
		var cdir := (t * cos(pa) + axis * sin(pa)).normalized()
		var up := d.cross(cdir).normalized()
		var c: float = chord * float(cf[i])
		var le := d * lerpf(r0, r1, u) - cdir * c * 0.35
		rings.append(foil(le, c, th * lerpf(1.6, 0.7, u) * c / chord, up, 0.0, 1.0, cdir))
	return skin(rings, kk, 40.0)


## A propeller at pos: `nb` twisted, tapered blades out to radius r in a
## "Blades" node, a spinner, and a "Blur" disc (unless burnt). By default its
## pivot spins about its local z and goes in k.wheels (the game turns those,
## as the AC-130's props); rot turns the shaft (a tilting proprotor). With
## `as_rotor` it is a k.rotors rotor instead (spinning about its local y, as
## vehicle.gd turns a drone's rotors), on a fixed mount that lays that y along
## the fuselage; its blur starts hidden. A pusher's spinner points aft.
static func prop(k: VehicleModels, p: Node3D, key: String, pos: Vector3, r: float, nb: int, chord: float, spin_r: float, rot := Vector3.ZERO, pusher := false, bcol := Color(0.15, 0.15, 0.15), tipcol = null, as_rotor := false) -> Node3D:
	var pv: Node3D
	if as_rotor:
		var mount := k._pivot(p, pos)
		mount.rotation = Vector3(PI / 2, 0, 0) + rot  # its y now points aft
		pv = k._pivot(mount, Vector3.ZERO)
	else:
		pv = k._pivot(p, pos)
		pv.rotation = rot
	var dz := 1.0 if pusher else -1.0
	# the axis the blades turn about, in the pivot's own space (aft is +z, or +y for a rotor)
	var ax := Vector3(0, 1, 0) if as_rotor else Vector3(0, 0, 1)
	var srot := Vector3(-PI / 2, 0, 0) if as_rotor else Vector3.ZERO
	# the spinner: a pointed cone ahead of the hub
	var sl := spin_r * 2.6
	var sm := skin([sec([dz * sl, 0, 0, 0, 0], 16), sec([dz * sl * 0.7, 0, spin_r * 0.55, spin_r * 0.55, spin_r * 0.55], 16), sec([dz * sl * 0.3, 0, spin_r * 0.9, spin_r * 0.9, spin_r * 0.9], 16),
		sec([0.0, 0, spin_r, spin_r, spin_r], 16), sec([-dz * spin_r * 0.4, 0, spin_r * 0.96, spin_r * 0.96, spin_r * 0.96], 16)], "pl_%s_spin" % key, 50.0)
	k._add(pv, sm, "paint", bcol.lightened(0.15) if tipcol == null else Color(0.62, 0.62, 0.6), Vector3.ZERO, srot)
	var bl := k._pivot(pv, Vector3.ZERO)
	bl.name = "Blades"
	for i in nb:
		var a := TAU * float(i) / float(nb) + 0.3
		var d := Vector3(sin(a), 0, cos(a)) if as_rotor else Vector3(sin(a), cos(a), 0)
		k._add(bl, _blade("%s_b%d" % [key, i], d, -ax * dz, spin_r * 0.6, r, chord, 0.9, 0.28, chord * 0.14), "paint", bcol, Vector3.ZERO)
		if tipcol is Color:
			k._add(bl, _blade("%s_t%d" % [key, i], d, -ax * dz, r * 0.9, r * 1.004, chord * 0.62, 0.32, 0.27, chord * 0.11), "paint", tipcol, Vector3.ZERO)
	if not k.burnt:
		var disc := MeshInstance3D.new()
		disc.name = "Blur"
		var pm := PlaneMesh.new()
		pm.size = Vector2(r, r) * 2.0
		pm.orientation = PlaneMesh.FACE_Y if as_rotor else PlaneMesh.FACE_Z
		disc.mesh = pm
		disc.material_override = VehicleModels._blur_mat()
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.visible = not as_rotor
		pv.add_child(disc)
	if as_rotor:
		k.rotors.append(pv)
	else:
		k.wheels.append(pv)
	return pv


# --- stores ------------------------------------------------------------------------

## A pylon under a wing or fuselage: `at` is its top; returns where the store's
## axis hangs (r below the pylon's foot).
static func pylon(k: VehicleModels, p: Node3D, at: Vector3, len: float, h: float, col: Color, r := 0.0) -> Vector3:
	var key := "pl_pyl_%.2f_%.2f" % [len, h]
	k._add(p, VehicleModels.extrude_x(key, [-len * 0.5, 0.08, len * 0.5, 0.08, len * 0.4, -h, -len * 0.3, -h], -0.045, 0.045), "aircraft", col, at)
	# sway braces either side of the store
	for s in [-1.0, 1.0]:
		k._box(p, Vector3(0.05, 0.06, 0.05), at + Vector3(s * 0.07, -h + 0.02, -len * 0.25), "gunmetal_w", null, Vector3(0, 0, s * 0.5), false)
		k._box(p, Vector3(0.05, 0.06, 0.05), at + Vector3(s * 0.07, -h + 0.02, len * 0.25), "gunmetal_w", null, Vector3(0, 0, s * 0.5), false)
	return at + Vector3(0, -h - r, 0)


## A general-purpose bomb (Mk 82 / 84 style) centred at c, or with `guided` a
## laser-guided one (Paveway: seeker and canards ahead, big tail wings).
static func bomb(k: VehicleModels, p: Node3D, c: Vector3, len: float, r: float, guided := false) -> void:
	var st := [[-0.5 * len, 0, r * 0.08, r * 0.08, r * 0.08], [-0.44 * len, 0, r * 0.55, r * 0.55, r * 0.55], [-0.3 * len, 0, r * 0.92, r * 0.92, r * 0.92],
		[-0.12 * len, 0, r, r, r], [0.18 * len, 0, r, r, r], [0.34 * len, 0, r * 0.72, r * 0.72, r * 0.72], [0.46 * len, 0, r * 0.5, r * 0.5, r * 0.5]]
	body(k, p, "bomb_%.2f_%.2f" % [len, r], st, "paint", OLIVE, 14, 50.0, c)
	# the yellow high-explosive band, the lugs
	k._cyl(p, r * 1.01, r * 1.01, 0.05, c + Vector3(0, 0, -0.2 * len), Vector3(PI / 2, 0, 0), "paint", Color(0.62, 0.55, 0.22), 14, false)
	k._box(p, Vector3(0.03, 0.05, 0.06), c + Vector3(0, r, -0.1 * len), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(p, Vector3(0.03, 0.05, 0.06), c + Vector3(0, r, 0.15 * len), "gunmetal_w", null, Vector3.ZERO, false)
	var fs := r * (3.2 if guided else 2.7)
	for a in [PI / 4, -PI / 4]:
		k._box(p, Vector3(0.014, fs, len * (0.2 if guided else 0.16)), c + Vector3(0, 0, len * 0.41), "paint", OLIVE.darkened(0.1), Vector3(0, 0, a), false)
	if guided:
		k._cyl(p, r * 0.55, r * 0.75, len * 0.16, c + Vector3(0, 0, -0.56 * len), Vector3(PI / 2, 0, 0), "paint", STORE_GREY, 12, false)
		k._add(p, Res.sphere(r * 0.55, 10), "glass", null, c + Vector3(0, 0, -0.64 * len), Vector3.ZERO, Vector3(1, 1, 0.8), false)
		for a in [PI / 4, -PI / 4]:
			k._box(p, Vector3(0.012, r * 2.4, len * 0.07), c + Vector3(0, 0, -0.55 * len), "paint", STORE_GREY, Vector3(0, 0, a), false)


## A rocket pod (LAU-61 style) centred at c: the faired tube with the
## rockets' noses in a dark honeycomb front.
static func rocket_pod(k: VehicleModels, p: Node3D, c: Vector3, len: float, r: float, col := OLIVE) -> void:
	var st := [[-0.5 * len, 0, r * 0.86, r * 0.86, r * 0.86], [-0.46 * len, 0, r * 0.98, r * 0.98, r * 0.98], [-0.4 * len, 0, r, r, r],
		[0.34 * len, 0, r, r, r], [0.44 * len, 0, r * 0.82, r * 0.82, r * 0.82], [0.5 * len, 0, r * 0.55, r * 0.55, r * 0.55]]
	body(k, p, "rpod_%.2f_%.2f" % [len, r], st, "paint", col, 16, 50.0, c)
	k._cyl(p, r * 0.8, r * 0.8, 0.02, c + Vector3(0, 0, -0.5 * len - 0.005), Vector3(PI / 2, 0, 0), "plain_dark", null, 14, false)
	for i in 7:
		var o := Vector2.ZERO if i == 0 else Vector2(cos(TAU * i / 6.0), sin(TAU * i / 6.0)) * r * 0.5
		k._cyl(p, 0.0, r * 0.17, 0.08, c + Vector3(o.x, o.y, -0.5 * len - 0.02), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	for z in [-0.3, 0.25]:
		k._cyl(p, r * 1.02, r * 1.02, 0.04, c + Vector3(0, 0, z * len), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 14, false)


## An air-to-air missile (AIM-9 style) on its launch rail, centred at c:
## seeker, canards, tail fins.
static func missile(k: VehicleModels, p: Node3D, c: Vector3, len: float, r: float, col := STORE_GREY, rail := true) -> void:
	k._cyl(p, r, r, len * 0.86, c + Vector3(0, 0, 0.05 * len), Vector3(PI / 2, 0, 0), "paint", col, 10)
	k._cyl(p, r * 0.3, r, len * 0.1, c + Vector3(0, 0, -0.43 * len), Vector3(PI / 2, 0, 0), "paint", col, 10, false)
	k._add(p, Res.sphere(r * 0.42, 8), "glass", null, c + Vector3(0, 0, -0.485 * len), Vector3.ZERO, Vector3.ONE, false)
	k._cyl(p, r * 1.02, r * 1.02, 0.08, c + Vector3(0, 0, -0.3 * len), Vector3(PI / 2, 0, 0), "paint", Color(0.6, 0.55, 0.25), 10, false)
	for a in [PI / 4, -PI / 4]:
		k._box(p, Vector3(0.012, r * 5.2, len * 0.08), c + Vector3(0, 0, -0.33 * len), "paint", col, Vector3(0, 0, a), false)
		k._box(p, Vector3(0.012, r * 7.0, len * 0.11), c + Vector3(0, 0, 0.43 * len), "paint", col, Vector3(0, 0, a), false)
	if rail:
		k._box(p, Vector3(0.07, 0.07, len * 0.6), c + Vector3(0, r + 0.035, 0.05 * len), "gunmetal_w")


## An air-to-ground missile (Maverick / Kh-25 style): a fat body, a glass
## seeker dome, long low wings and tail fins.
static func agm(k: VehicleModels, p: Node3D, c: Vector3, len: float, r: float, col := STORE_GREY) -> void:
	var st := [[-0.5 * len, 0, r * 0.3, r * 0.3, r * 0.3], [-0.46 * len, 0, r * 0.82, r * 0.82, r * 0.82], [-0.4 * len, 0, r, r, r], [0.5 * len, 0, r, r, r]]
	body(k, p, "agm_%.2f_%.2f" % [len, r], st, "paint", col, 14, 50.0, c)
	k._add(p, Res.sphere(r * 0.62, 10), "glass", null, c + Vector3(0, 0, -0.47 * len), Vector3.ZERO, Vector3(1, 1, 0.8), false)
	for a in [PI / 4, -PI / 4]:
		k._box(p, Vector3(0.014, r * 3.6, len * 0.42), c + Vector3(0, 0, 0.12 * len), "paint", col.darkened(0.1), Vector3(0, 0, a), false)
		k._box(p, Vector3(0.012, r * 4.0, len * 0.1), c + Vector3(0, 0, 0.45 * len), "paint", col.darkened(0.1), Vector3(0, 0, a), false)
	k._box(p, Vector3(0.08, 0.06, len * 0.5), c + Vector3(0, r + 0.03, 0.0), "gunmetal_w")


## A drop tank centred at c, pointed both ends.
static func drop_tank(k: VehicleModels, p: Node3D, c: Vector3, len: float, r: float, col: Color) -> void:
	var st := [[-0.5 * len, 0, 0, 0, 0], [-0.42 * len, 0, r * 0.5, r * 0.5, r * 0.5], [-0.25 * len, 0, r * 0.92, r * 0.92, r * 0.92], [-0.05 * len, 0, r, r, r],
		[0.15 * len, 0, r, r, r], [0.35 * len, 0, r * 0.75, r * 0.75, r * 0.75], [0.5 * len, 0, r * 0.1, r * 0.1, r * 0.1]]
	body(k, p, "tank_%.2f_%.2f" % [len, r], st, "aircraft", col, 16, 50.0, c)
	for a in [0.0, 2.1, -2.1]:
		k._box(p, Vector3(0.012, r * 1.5, len * 0.1), c + Vector3(sin(a) * r * 0.7, -cos(a) * r * 0.7, 0.4 * len), "aircraft", col, Vector3(0, 0, -a), false)


## A cannon pod (centreline gun pod) centred at c; returns the muzzle.
static func gun_pod(k: VehicleModels, p: Node3D, c: Vector3, len: float, r: float, col: Color) -> Vector3:
	var st := [[-0.5 * len, 0, r * 0.35, r * 0.35, r * 0.35], [-0.38 * len, 0, r * 0.85, r * 0.85, r * 0.85], [-0.2 * len, 0, r, r, r], [0.3 * len, 0, r, r, r], [0.5 * len, 0, r * 0.3, r * 0.3, r * 0.3]]
	body(k, p, "gpod_%.2f_%.2f" % [len, r], st, "aircraft", col, 16, 50.0, c)
	var mz := c + Vector3(0, -r * 0.1, -0.5 * len - 0.35)
	k._cyl(p, 0.035, 0.035, 0.45, mz + Vector3(0, 0, 0.2), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
	k._cyl(p, 0.05, 0.05, 0.08, mz + Vector3(0, 0, 0.02), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
	return mz


## Small details: a blade antenna, navigation lights.
static func antenna(k: VehicleModels, p: Node3D, pos: Vector3, h: float, down := false, col := Color(0.2, 0.2, 0.2)) -> void:
	var s := -1.0 if down else 1.0
	k._box(p, Vector3(0.02, h, h * 0.7), pos + Vector3(0, s * h * 0.45, h * 0.15), "paint", col, Vector3(s * 0.45, 0, 0), false)


static func nav_lights(k: VehicleModels, p: Node3D, right: Vector3, sz := 0.08) -> void:
	if k.burnt:
		return
	k._box(p, Vector3(sz, sz * 0.6, sz * 1.6), right, "paint", Color(0.15, 0.5, 0.2), Vector3.ZERO, false)
	k._box(p, Vector3(sz, sz * 0.6, sz * 1.6), right * Vector3(-1, 1, 1), "paint", Color(0.6, 0.12, 0.1), Vector3.ZERO, false)


## A team panel flat on a wing's upper surface at span x, both wings.
static func wing_marks(k: VehicleModels, p: Node3D, team: int, secs: Array, x: float, s: float) -> void:
	var w := surf_at(secs, x)
	var le: Vector3 = w[0]
	var y := le.y + float(w[2]) * 0.5 + 0.008
	for sd in [-1.0, 1.0]:
		k._team_mark(p, team, Vector3(sd * x, y, le.z + float(w[1]) * 0.38), Vector3(s, 0.015, s))


# --- A-143 Buzzard ------------------------------------------------------------------

## A-143 Buzzard (Aero L-159 ALCA): a long sharp nose, a single bubble canopy,
## semicircular intakes on the fuselage sides behind it, a tapered low wing
## with tip tanks, a tall swept fin with a dorsal fillet, one jet pipe. Seven
## pylons: the 20 mm gun pod on the centreline, bombs, rocket pods and
## Sidewinders under the wings. AAF green-grey.
static func _buzzard(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := AAF
	var A := "aircraft"
	var st := [
		[-6.36, 1.0, 0.0, 0.0, 0.0],
		[-6.15, 1.0, 0.07, 0.07, 0.07],
		[-5.7, 1.0, 0.19, 0.19, 0.19],
		[-5.0, 1.0, 0.32, 0.33, 0.32],
		[-4.2, 1.0, 0.43, 0.45, 0.43, 2.1, 2.3],
		[-3.4, 1.0, 0.51, 0.55, 0.51, 2.2, 2.5],
		[-2.4, 1.0, 0.58, 0.62, 0.57, 2.3, 2.6],
		[-1.2, 1.0, 0.68, 0.69, 0.61, 2.5, 2.6],
		[0.4, 1.0, 0.7, 0.7, 0.61, 2.5, 2.6],
		[2.0, 1.03, 0.6, 0.62, 0.55, 2.3, 2.4],
		[3.6, 1.07, 0.46, 0.52, 0.44],
		[5.0, 1.1, 0.38, 0.42, 0.36],
		[6.0, 1.12, 0.33, 0.35, 0.32],
		[6.36, 1.12, 0.3, 0.31, 0.29],
	]
	body(k, m, "buz_fus", st, A, c)
	# the radome a shade darker, a joint band behind it
	band(k, m, "buz_rjoint", st, -4.6, 0.03, 0.006, A, c.darkened(0.25))
	band(k, m, "buz_tjoint", st, 3.0, 0.03, 0.005, A, c.darkened(0.2))
	# dorsal spine from the canopy to the fin
	body(k, m, "buz_spine", [[-1.3, 1.42, 0.34, 0.4, 0.1], [-0.4, 1.44, 0.33, 0.37, 0.1], [1.6, 1.45, 0.25, 0.3, 0.1], [3.6, 1.45, 0.14, 0.19, 0.1]], A, c, 16)
	# the canopy: windscreen and bubble, its bows
	var cst := [[-3.45, 1.45, 0.3, 0.08, 0.08], [-3.0, 1.45, 0.43, 0.36, 0.08], [-2.4, 1.46, 0.47, 0.54, 0.08], [-1.7, 1.47, 0.46, 0.57, 0.08],
		[-1.0, 1.48, 0.4, 0.46, 0.08], [-0.5, 1.48, 0.27, 0.28, 0.08]]
	body(k, m, "buz_can", cst, "glass", null, 18, 60.0)
	band(k, m, "buz_bow0", cst, -2.92, 0.07, 0.02, A, c.darkened(0.2), 18)
	band(k, m, "buz_bow1", cst, -1.05, 0.08, 0.02, A, c.darkened(0.2), 18)
	# the intakes: D-shaped mouths standing off the fuselage on splitter plates
	var ist := [[-2.3, 1.06, 0.24, 0.33, 0.33, 2.4, 2.4, 0.84], [-1.9, 1.05, 0.27, 0.36, 0.36, 2.4, 2.4, 0.83], [-1.2, 1.03, 0.24, 0.35, 0.36, 2.4, 2.4, 0.78],
		[-0.2, 1.01, 0.16, 0.32, 0.34, 2.3, 2.3, 0.68], [1.2, 1.0, 0.06, 0.24, 0.26, 2.0, 2.0, 0.6]]
	body2(k, m, "buz_int", ist, A, c, 16)
	for s in [-1.0, 1.0]:
		var q := _sp(ist[0])
		q[7] = s * 0.85
		mouth(k, m, "buz_mouth" + ("L" if s < 0.0 else ""), q, 0.8)
		k._box(m, Vector3(0.03, 0.66, 0.6), Vector3(s * 0.6, 1.05, -2.05), A, c.darkened(0.1))
	# the wing: tapered, a little dihedral, flaps and ailerons
	var ws := [[Vector3(0.45, 0.6, -0.7), 3.0, 0.36], [Vector3(2.55, 0.68, -0.3), 2.4, 0.28], [Vector3(4.42, 0.75, 0.02), 1.8, 0.2]]
	surf(k, m, "buz_wing", ws, A, c, [0.74, 0.74])
	# tip tanks with their navigation lights
	var tt := [[-1.3, 0.75, 0, 0, 0, 2, 2, 4.64], [-1.05, 0.75, 0.12, 0.12, 0.12, 2, 2, 4.64], [-0.55, 0.75, 0.22, 0.22, 0.22, 2, 2, 4.64],
		[0.2, 0.75, 0.26, 0.26, 0.26, 2, 2, 4.64], [0.9, 0.75, 0.25, 0.25, 0.25, 2, 2, 4.64], [1.5, 0.75, 0.17, 0.17, 0.17, 2, 2, 4.64], [1.78, 0.75, 0.05, 0.05, 0.05, 2, 2, 4.64]]
	body2(k, m, "buz_tip", tt, A, c, 16)
	nav_lights(k, m, Vector3(4.9, 0.75, -0.3), 0.07)
	# tailplane and fin (rudder, elevators), the dorsal fillet
	surf(k, m, "buz_tail", [[Vector3(0.25, 1.3, 4.35), 1.5, 0.14], [Vector3(2.3, 1.42, 5.0), 0.8, 0.08]], A, c, [0.66])
	surf(k, m, "buz_fin", [[Vector3(0, 1.45, 3.2), 2.5, 0.2], [Vector3(0, 3.6, 5.3), 1.05, 0.1]], A, c, [0.66], false)
	surf(k, m, "buz_fillet", [[Vector3(0, 1.55, 2.0), 1.6, 0.12], [Vector3(0, 1.95, 3.4), 0.5, 0.08]], A, c, [], false)
	k._box(m, Vector3(0.12, 0.08, 0.3), Vector3(0, 3.62, 6.05), A, c.darkened(0.3))
	# the jet pipe
	nozzle(k, m, Vector3(0, 1.12, 6.4), 0.29, 0.22, c, 0.92)
	glow(k, m, [Vector3(0, 1.12, 6.75)], 1.0, Color(0.7, 0.4, 0.22))
	# probes, antennas, the airbrakes under the belly
	rod(k, m, Vector3(0, 1.0, -6.3), Vector3(0, 1.0, -6.95), 0.03, "gunmetal_w", null, 6, 0.012)
	antenna(k, m, Vector3(0, 1.74, 0.9), 0.28)
	antenna(k, m, Vector3(0, 0.38, -1.4), 0.22, true)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.36, 0.02, 0.9), Vector3(s * 0.32, 0.42, 1.0), A, c.darkened(0.15), Vector3(0, 0, s * 0.2), false)
	# stores: gun pod on the centreline; bombs, rocket pods, Sidewinders
	var gc := pylon(k, m, Vector3(0, 0.45, 0.2), 1.4, 0.12, c, 0.2)
	var mz := gun_pod(k, m, gc, 2.5, 0.2, c.darkened(0.1))
	k.mg_tip = k._tip(m, mz + Vector3(0, 0, -0.05))
	k.gun_tip = k.mg_tip
	for sd in [-1.0, 1.0]:
		for x in [1.5, 2.5, 3.45]:
			var w := surf_at(ws, x)
			var le: Vector3 = w[0]
			var at := Vector3(sd * x, le.y - float(w[2]) * 0.3, le.z + float(w[1]) * 0.42)
			if x < 2.0:
				bomb(k, m, pylon(k, m, at, 1.2, 0.22, c, 0.14), 2.2, 0.14)
			elif x < 3.0:
				rocket_pod(k, m, pylon(k, m, at, 1.2, 0.2, c, 0.2), 2.0, 0.2)
			else:
				missile(k, m, pylon(k, m, at, 0.9, 0.12, c, 0.1), 2.85, 0.064)
	# national markings
	wing_marks(k, m, team, ws, 3.3, 0.6)
	for s in [-1.0, 1.0]:
		k._team_mark(m, team, Vector3(s * 0.47, 1.1, 3.6), Vector3(0.02, 0.34, 0.34))


# --- A-149 Gryphon ------------------------------------------------------------------

## A-149 Gryphon (Saab JAS 39 Gripen): a slim fuselage with a long radome,
## a one-piece bubble canopy over a dorsal spine, D-shaped intakes with the
## close-coupled canards on their shoulders, a cranked delta wing with
## elevons, one tall fin, one afterburning engine. Sidewinders on the tips,
## laser-guided bombs and Mavericks under the wings, a centreline tank, the
## 27 mm gun low on the left. AAF green-grey.
static func _gryphon(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := AAF
	var A := "aircraft"
	var st := [
		[-6.8, 0.96, 0.0, 0.0, 0.0],
		[-6.5, 0.96, 0.1, 0.1, 0.1],
		[-5.9, 0.97, 0.25, 0.26, 0.25],
		[-5.0, 0.99, 0.39, 0.41, 0.39],
		[-4.3, 1.0, 0.46, 0.5, 0.46, 2.1, 2.4],
		[-3.4, 1.0, 0.52, 0.56, 0.52, 2.2, 2.6],
		[-2.4, 1.0, 0.6, 0.6, 0.55, 2.4, 2.6],
		[-1.0, 1.0, 0.8, 0.62, 0.55, 2.8, 2.6],
		[1.0, 1.0, 0.82, 0.6, 0.52, 2.8, 2.6],
		[3.0, 1.02, 0.7, 0.56, 0.5, 2.6, 2.4],
		[5.0, 1.04, 0.56, 0.5, 0.48],
		[6.2, 1.05, 0.48, 0.47, 0.46],
		[6.6, 1.05, 0.46, 0.46, 0.45],
	]
	body(k, m, "gry_fus", st, A, c)
	stripe(k, m, "gry_rad", st, -6.8, -5.05, -PI, PI, A, c.darkened(0.18), 0.004, 20)
	band(k, m, "gry_tjoint", st, 4.4, 0.03, 0.005, A, c.darkened(0.2))
	body(k, m, "gry_spine", [[-2.3, 1.42, 0.36, 0.36, 0.1], [-1.0, 1.44, 0.34, 0.34, 0.1], [1.5, 1.44, 0.28, 0.3, 0.1], [3.5, 1.44, 0.18, 0.22, 0.1], [5.2, 1.42, 0.08, 0.1, 0.1]], A, c, 16)
	var cst := [[-4.55, 1.42, 0.28, 0.06, 0.06], [-4.0, 1.42, 0.4, 0.33, 0.06], [-3.4, 1.43, 0.44, 0.49, 0.06], [-2.7, 1.44, 0.42, 0.47, 0.06],
		[-2.1, 1.45, 0.34, 0.33, 0.06], [-1.7, 1.45, 0.2, 0.17, 0.06]]
	body(k, m, "gry_can", cst, "glass", null, 18, 60.0)
	band(k, m, "gry_bow0", cst, -3.95, 0.07, 0.018, A, c.darkened(0.2), 18)
	band(k, m, "gry_bow1", cst, -2.15, 0.07, 0.018, A, c.darkened(0.2), 18)
	# D-shaped intakes on splitter plates, the canards on their shoulders
	var ist := [[-3.65, 0.95, 0.23, 0.4, 0.38, 2.5, 2.5, 0.78], [-3.2, 0.95, 0.27, 0.42, 0.4, 2.5, 2.5, 0.78], [-2.0, 0.97, 0.25, 0.42, 0.42, 2.5, 2.5, 0.73],
		[-0.6, 1.0, 0.14, 0.36, 0.38, 2.4, 2.4, 0.68], [0.6, 1.0, 0.05, 0.3, 0.3, 2.2, 2.2, 0.66]]
	body2(k, m, "gry_int", ist, A, c, 16)
	for s in [-1.0, 1.0]:
		var q := _sp(ist[0])
		q[7] = s * 0.78
		mouth(k, m, "gry_mouth" + ("L" if s < 0.0 else ""), q, 0.8)
		k._box(m, Vector3(0.03, 0.76, 0.55), Vector3(s * 0.535, 0.95, -3.4), A, c.darkened(0.1))
	surf(k, m, "gry_can_w", [[Vector3(0.8, 1.36, -3.15), 1.75, 0.13], [Vector3(2.45, 1.36, -1.75), 0.72, 0.05]], A, c, [])
	# the cranked delta, elevons along its trailing edge
	var ws := [[Vector3(0.75, 0.88, -1.8), 6.4, 0.36], [Vector3(2.4, 0.9, -0.05), 4.45, 0.22], [Vector3(4.0, 0.92, 1.95), 2.3, 0.12]]
	surf(k, m, "gry_wing", ws, A, c, [0.86, 0.8])
	# the dogtooth: a small step in the leading edge
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.03, 0.08, 0.35), Vector3(s * 2.42, 0.9, 0.08), A, c.darkened(0.2), Vector3.ZERO, false)
	# tip rails with Sidewinders, navigation lights
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.08, 0.1, 2.3), Vector3(s * 4.06, 0.92, 2.95), A, c)
		missile(k, m, Vector3(s * 4.06, 0.8, 2.6), 2.85, 0.064, STORE_GREY, false)
	nav_lights(k, m, Vector3(4.1, 0.98, 2.0), 0.06)
	# the fin with its rudder, a fairing at the tip
	surf(k, m, "gry_fin", [[Vector3(0, 1.4, 2.1), 3.6, 0.22], [Vector3(0, 3.9, 5.0), 1.3, 0.1]], A, c, [0.72], false)
	k._box(m, Vector3(0.1, 0.1, 0.5), Vector3(0, 3.9, 5.6), A, c.darkened(0.25))
	# the afterburner nozzle, airbrakes on the tail cone
	nozzle(k, m, Vector3(0, 1.05, 6.8), 0.45, 0.4, c, 0.9)
	glow(k, m, [Vector3(0, 1.05, 7.3)], 1.2)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.03, 0.42, 0.75), Vector3(s * 0.53, 1.12, 5.4), A, c.darkened(0.15), Vector3(0, s * 0.08, 0), false)
	# probes and antennas, the gun port low on the left
	rod(k, m, Vector3(0, 0.96, -6.75), Vector3(0, 0.96, -7.3), 0.03, "gunmetal_w", null, 6, 0.012)
	antenna(k, m, Vector3(0, 1.74, -0.6), 0.25)
	antenna(k, m, Vector3(0, 0.46, 0.2), 0.2, true)
	k._box(m, Vector3(0.06, 0.1, 0.4), Vector3(-0.62, 0.66, -2.2), "plain_dark", null, Vector3(0, 0, 0.5), false)
	k.mg_tip = k._tip(m, Vector3(-0.64, 0.64, -2.45))
	k.gun_tip = k.mg_tip
	# stores: a centreline tank, Paveways inboard, Mavericks outboard
	drop_tank(k, m, pylon(k, m, Vector3(0, 0.5, 0.6), 1.4, 0.16, c, 0.3), 3.6, 0.3, c)
	for sd in [-1.0, 1.0]:
		for x in [1.55, 3.0]:
			var w := surf_at(ws, x)
			var le: Vector3 = w[0]
			var at := Vector3(sd * x, le.y - float(w[2]) * 0.3, le.z + float(w[1]) * 0.4)
			if x < 2.0:
				bomb(k, m, pylon(k, m, at, 1.3, 0.22, c, 0.16), 2.4, 0.16, true)
			else:
				agm(k, m, pylon(k, m, at, 1.1, 0.16, c, 0.15), 2.4, 0.15)
	wing_marks(k, m, team, ws, 2.9, 0.55)
	for s in [-1.0, 1.0]:
		k._team_mark(m, team, Vector3(s * 0.082, 2.6, 4.15), Vector3(0.02, 0.4, 0.4))


# --- A-164 Wipeout ------------------------------------------------------------------

## A-164 Wipeout (A-10 Thunderbolt II): the GAU-8's seven barrels in the nose,
## the cockpit high on an armoured tub under a bubble canopy, a thick straight
## low wing with gear pods and drooped Hoerner tips, two big turbofans on
## pylons on the rear fuselage with sharp-lipped intakes, a tailplane with twin
## fins. Twelve pylons of stores. Darker grey.
static func _wipeout(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := Color(0.35, 0.37, 0.39)
	var A := "aircraft"
	var st := [
		[-7.72, 1.12, 0.0, 0.0, 0.0],
		[-7.62, 1.12, 0.28, 0.3, 0.3, 2.2, 2.2],
		[-7.3, 1.14, 0.48, 0.52, 0.5, 2.2, 2.3],
		[-6.7, 1.17, 0.66, 0.72, 0.66, 2.3, 2.5],
		[-5.8, 1.2, 0.76, 0.84, 0.74, 2.5, 2.7],
		[-4.4, 1.2, 0.8, 0.86, 0.76, 2.6, 2.7],
		[-2.5, 1.2, 0.8, 0.8, 0.74, 2.6, 2.7],
		[0.5, 1.22, 0.76, 0.74, 0.68, 2.5, 2.6],
		[3.0, 1.26, 0.63, 0.64, 0.58, 2.4, 2.4],
		[5.0, 1.32, 0.49, 0.52, 0.44],
		[6.6, 1.4, 0.34, 0.4, 0.3],
		[7.7, 1.48, 0.17, 0.24, 0.16],
		[7.95, 1.5, 0.06, 0.1, 0.06],
	]
	body(k, m, "wip_fus", st, A, c)
	stripe(k, m, "wip_nose", st, -7.72, -7.25, -PI, PI, A, c.darkened(0.2), 0.004, 20)
	band(k, m, "wip_joint0", st, -3.6, 0.03, 0.005, A, c.darkened(0.2))
	band(k, m, "wip_joint1", st, 2.6, 0.03, 0.005, A, c.darkened(0.2))
	# the canopy on its high cockpit: windscreen and bubble
	var cst := [[-6.75, 1.86, 0.3, 0.06, 0.06], [-6.3, 1.86, 0.48, 0.36, 0.06], [-5.6, 1.88, 0.53, 0.58, 0.06], [-4.9, 1.9, 0.5, 0.56, 0.06],
		[-4.3, 1.9, 0.4, 0.4, 0.06], [-3.85, 1.9, 0.24, 0.2, 0.06]]
	body(k, m, "wip_can", cst, "glass", null, 18, 60.0)
	band(k, m, "wip_bow0", cst, -6.25, 0.08, 0.02, A, c.darkened(0.2), 18)
	band(k, m, "wip_bow1", cst, -4.3, 0.08, 0.02, A, c.darkened(0.2), 18)
	body(k, m, "wip_hump", [[-4.6, 1.85, 0.4, 0.4, 0.1], [-3.4, 1.85, 0.36, 0.34, 0.1], [-1.2, 1.85, 0.2, 0.2, 0.1], [0.0, 1.8, 0.1, 0.12, 0.1]], A, c, 16)
	# the GAU-8: seven barrels in a ring, low in the nose, the muzzle cluster
	var gz := Vector3(0, 0.92, -7.7)
	k._cyl(m, 0.17, 0.2, 0.14, gz + Vector3(0, 0, 0.05), Vector3(PI / 2, 0, 0), "metal_dark", null, 14)
	for i in 7:
		var a := TAU * float(i) / 7.0
		k._cyl(m, 0.026, 0.026, 0.48, gz + Vector3(cos(a) * 0.1, sin(a) * 0.1, -0.22), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	k._cyl(m, 0.14, 0.14, 0.05, gz + Vector3(0, 0, -0.3), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 14, false)
	k.mg_tip = k._tip(m, gz + Vector3(0, 0, -0.48))
	k.gun_tip = k.mg_tip
	# the straight wing: centre section, outer panels with dihedral, drooped tips
	var ws := [[Vector3(0.7, 0.86, -1.35), 3.05, 0.56], [Vector3(3.2, 0.86, -1.3), 3.0, 0.5], [Vector3(8.4, 1.5, -0.85), 1.85, 0.26]]
	surf(k, m, "wip_wing", ws, A, c, [0.76, 0.74])
	surf(k, m, "wip_htip", [[Vector3(8.38, 1.5, -0.84), 1.84, 0.26], [Vector3(8.77, 1.36, -0.7), 1.55, 0.12]], A, c, [])
	nav_lights(k, m, Vector3(8.78, 1.36, -0.2), 0.08)
	# main gear pods under the wing, the wheel just showing
	for s in [-1.0, 1.0]:
		body(k, m, "wip_gpod" + ("L" if s < 0.0 else ""), [[-2.75, 0.62, 0.0, 0.0, 0.0, 2, 2, s * 2.15], [-2.45, 0.62, 0.2, 0.2, 0.22, 2, 2, s * 2.15],
			[-1.8, 0.62, 0.34, 0.32, 0.38, 2.2, 2.2, s * 2.15], [-0.4, 0.66, 0.36, 0.32, 0.4, 2.3, 2.3, s * 2.15], [0.9, 0.7, 0.26, 0.24, 0.26, 2.2, 2.2, s * 2.15], [1.7, 0.74, 0.04, 0.1, 0.04, 2, 2, s * 2.15]], A, c, 16)
		k._cyl(m, 0.36, 0.36, 0.26, Vector3(s * 2.18, 0.42, -1.6), Vector3(0, 0, PI / 2), "rubber", null, 16)
	# engines: nacelles on stub pylons, sharp intake lips, dark fan faces
	for s in [-1.0, 1.0]:
		var nx: float = s * 1.62
		var nst := [[1.75, 2.42, 0.64, 0.64, 0.64, 2, 2, nx], [2.0, 2.42, 0.67, 0.67, 0.67, 2, 2, nx], [3.0, 2.42, 0.66, 0.66, 0.66, 2, 2, nx],
			[4.2, 2.42, 0.6, 0.6, 0.6, 2, 2, nx], [5.1, 2.42, 0.48, 0.48, 0.48, 2, 2, nx], [5.45, 2.42, 0.42, 0.42, 0.42, 2, 2, nx]]
		body(k, m, "wip_nac" + ("L" if s < 0.0 else ""), nst, A, c, 20)
		mouth(k, m, "wip_fan" + ("L" if s < 0.0 else ""), nst[0], 0.88, -1.0, "metal_dark")
		k._cyl(m, 0.17, 0.0, 0.3, Vector3(nx, 2.42, 1.72), Vector3(-PI / 2, 0, 0), "gunmetal_w", null, 10, false)
		k._cyl(m, 0.42, 0.36, 0.3, Vector3(nx, 2.42, 5.55), Vector3(PI / 2, 0, 0), "gunmetal_w", c.darkened(0.4), 16)
		k._cyl(m, 0.3, 0.3, 0.03, Vector3(nx, 2.42, 5.71), Vector3(PI / 2, 0, 0), "plain_dark", null, 12, false)
		# the pylon from the fuselage shoulder
		k._add(m, VehicleModels.extrude_x("pl_wip_npyl", [2.3, 0.0, 4.9, 0.0, 4.6, 0.8, 2.7, 0.8], -0.09, 0.09), A, c, Vector3(s * 0.48, 1.68, 0), Vector3(0, 0, s * -0.85))
	glow(k, m, [Vector3(-1.62, 2.42, 5.9), Vector3(1.62, 2.42, 5.9)], 1.2, Color(0.55, 0.33, 0.2))
	# the tailplane and twin fins, elevators and rudders
	var tz := 6.05
	surf(k, m, "wip_tail", [[Vector3(0.1, 1.62, tz), 2.0, 0.14], [Vector3(2.9, 1.62, tz + 0.05), 1.95, 0.12]], A, c, [0.7])
	for s in [-1.0, 1.0]:
		surf(k, m, "wip_fin" + ("L" if s < 0.0 else ""), [[Vector3(s * 2.9, 0.7, tz - 0.05), 1.85, 0.14], [Vector3(s * 2.9, 1.0, tz - 0.15), 2.2, 0.16],
			[Vector3(s * 2.9, 3.4, tz + 0.15), 2.05, 0.14], [Vector3(s * 2.9, 3.85, tz + 0.5), 1.5, 0.1]], A, c, [0.0, 0.7, 0.7], false)
	# refuelling receptacle, antennas, the formation-light strips
	k._box(m, Vector3(0.2, 0.03, 0.3), Vector3(0, 2.06, -6.95), "plain_dark", null, Vector3(-0.35, 0, 0), false)
	antenna(k, m, Vector3(0, 1.98, -2.0), 0.3)
	antenna(k, m, Vector3(0, 0.48, 1.0), 0.22, true)
	# twelve stations: two under the fuselage, five under each wing
	for x in [-0.36, 0.36]:
		bomb(k, m, pylon(k, m, Vector3(x, 0.6, -0.2), 1.2, 0.18, c, 0.14), 2.2, 0.14)
	for sd in [-1.0, 1.0]:
		for x in [1.25, 3.05, 4.45, 5.65, 6.85]:
			var w := surf_at(ws, x)
			var le: Vector3 = w[0]
			var at := Vector3(sd * x, le.y - float(w[2]) * 0.32, le.z + float(w[1]) * 0.42)
			if x < 2.0:
				bomb(k, m, pylon(k, m, at, 1.3, 0.24, c, 0.16), 2.4, 0.16, true)
			elif x < 4.0:
				bomb(k, m, pylon(k, m, at, 1.3, 0.24, c, 0.14), 2.2, 0.14)
			elif x < 5.0:
				# a Maverick each side of a triple launcher
				var mc := pylon(k, m, at, 1.3, 0.2, c, 0.0)
				k._box(m, Vector3(0.5, 0.12, 1.4), mc + Vector3(0, -0.04, 0.1), "gunmetal_w")
				for o in [-0.26, 0.26]:
					agm(k, m, mc + Vector3(o, -0.2, 0.0), 2.4, 0.15)
			elif x < 6.0:
				rocket_pod(k, m, pylon(k, m, at, 1.2, 0.2, c, 0.22), 2.2, 0.22)
			elif sd < 0.0:
				# the ECM pod on the left, Sidewinders on the right
				var ec := pylon(k, m, at, 1.0, 0.16, c, 0.16)
				body(k, m, "wip_ecm", [[-1.3, 0, 0.08, 0.08, 0.08], [-1.1, 0, 0.16, 0.16, 0.16], [1.0, 0, 0.16, 0.16, 0.16], [1.3, 0, 0.06, 0.06, 0.06]], "paint", Color(0.5, 0.52, 0.5), 12, 50.0, ec)
				k._box(m, Vector3(0.05, 0.18, 0.3), ec + Vector3(0, -0.2, -0.6), "paint", Color(0.45, 0.47, 0.45))
			else:
				var mc2 := pylon(k, m, at, 1.0, 0.14, c, 0.0)
				k._box(m, Vector3(0.36, 0.08, 1.0), mc2 + Vector3(0, -0.02, 0.1), "gunmetal_w")
				for o in [-0.17, 0.17]:
					missile(k, m, mc2 + Vector3(o, -0.12, 0.0), 2.85, 0.064, STORE_GREY, false)
	wing_marks(k, m, team, ws, 6.2, 0.75)
	for s in [-1.0, 1.0]:
		k._team_mark(m, team, Vector3(s * 0.66, 1.3, 3.4), Vector3(0.02, 0.4, 0.5))


# --- Caesar BTT ---------------------------------------------------------------------

## Caesar BTT (Cessna TTx): a sleek four-seat composite single, cowled engine
## and three-blade tractor propeller, a big glazed cabin with gull-wing doors,
## a low tapered wing, swept fin, fixed tricycle gear in wheel spats (down,
## wheels on the ground). Civilian white with a stripe.
static func _caesar(k: VehicleModels, team: int, seed: int) -> void:
	var m := k.root
	var P := "car_paint"
	var c := Color(0.86, 0.86, 0.83)
	var sc: Color = [Color(0.5, 0.12, 0.1), Color(0.16, 0.25, 0.42), Color(0.2, 0.32, 0.25)][absi(seed) % 3]
	var st := [
		[-3.45, 1.32, 0.3, 0.3, 0.28],
		[-3.1, 1.33, 0.45, 0.43, 0.4, 2.2, 2.4],
		[-2.3, 1.35, 0.57, 0.5, 0.49, 2.3, 2.6],
		[-1.5, 1.36, 0.63, 0.55, 0.53, 2.4, 2.6],
		[-0.6, 1.38, 0.66, 0.58, 0.55, 2.4, 2.6],
		[0.6, 1.4, 0.62, 0.56, 0.52, 2.4, 2.5],
		[1.6, 1.47, 0.47, 0.46, 0.4],
		[2.8, 1.56, 0.25, 0.3, 0.22],
		[3.7, 1.62, 0.09, 0.14, 0.09],
		[3.86, 1.63, 0.03, 0.05, 0.03],
	]
	body(k, m, "cae_fus", st, P, c)
	# the livery: a stripe down each flank, a pinstripe above it
	for s in [-1.0, 1.0]:
		var a0 := -0.2 if s > 0.0 else PI + 0.02
		stripe(k, m, "cae_str" + ("L" if s < 0.0 else ""), st, -3.4, 3.7, a0, a0 + 0.18, P, sc, 0.005, 5)
		var a1 := 0.06 if s > 0.0 else PI - 0.1
		stripe(k, m, "cae_pin" + ("L" if s < 0.0 else ""), st, -3.0, 3.5, a1, a1 + 0.04, P, sc.lightened(0.15), 0.005, 3)
	# the cabin: a glass house, its pillars and a painted roof
	var cst := [[-1.75, 1.82, 0.4, 0.05, 0.1], [-1.2, 1.84, 0.58, 0.34, 0.1], [-0.4, 1.86, 0.62, 0.42, 0.1], [0.5, 1.86, 0.58, 0.4, 0.1],
		[1.3, 1.86, 0.45, 0.28, 0.1], [2.0, 1.86, 0.25, 0.1, 0.1]]
	body(k, m, "cae_cab", cst, "glass", null, 20, 60.0)
	for i in 3:
		band(k, m, "cae_pil%d" % i, cst, [-1.15, 0.15, 1.2][i], [0.08, 0.1, 0.12][i], 0.012, P, c, 20)
	body(k, m, "cae_roof", [[-1.2, 1.85, 0.32, 0.35, 0.05, 3.0, 2.0], [-0.4, 1.86, 0.46, 0.43, 0.05, 3.0, 2.0], [0.5, 1.86, 0.44, 0.41, 0.05, 3.0, 2.0],
		[1.3, 1.86, 0.34, 0.29, 0.05, 3.0, 2.0], [2.0, 1.86, 0.18, 0.11, 0.05, 3.0, 2.0]], P, c, 20)
	# door seams
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.012, 0.5, 0.012), Vector3(s * 0.665, 1.55, -1.1), "gunmetal_w", null, Vector3(0, 0, 0), false)
		k._box(m, Vector3(0.012, 0.5, 0.012), Vector3(s * 0.62, 1.55, 0.9), "gunmetal_w", null, Vector3(0, 0, 0), false)
	# cowl inlets and exhaust stacks, the landing light
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.18, 0.1, 0.04), Vector3(s * 0.2, 1.42, -3.44), "plain_dark", null, Vector3.ZERO, false)
		rod(k, m, Vector3(s * 0.3, 0.92, -2.3), Vector3(s * 0.32, 0.86, -1.95), 0.04, "steel", null, 8)
	# the wing: low, tapered, dihedral, flaps and ailerons, upturned tips
	var ws := [[Vector3(0.55, 0.85, -1.0), 1.75, 0.26], [Vector3(2.7, 1.0, -0.88), 1.4, 0.2], [Vector3(5.3, 1.2, -0.72), 0.98, 0.12]]
	surf(k, m, "cae_wing", ws, P, c, [0.74, 0.74])
	surf(k, m, "cae_wtip", [[Vector3(5.28, 1.2, -0.71), 0.98, 0.12], [Vector3(5.48, 1.32, -0.6), 0.75, 0.06]], P, c, [])
	nav_lights(k, m, Vector3(5.5, 1.32, -0.42), 0.06)
	# tail: the swept fin and the stabiliser
	surf(k, m, "cae_fin", [[Vector3(0, 1.6, 2.0), 1.55, 0.14], [Vector3(0, 2.72, 3.05), 0.8, 0.07]], P, c, [0.66], false)
	surf(k, m, "cae_stab", [[Vector3(0.1, 1.62, 2.85), 1.0, 0.1], [Vector3(1.85, 1.66, 3.2), 0.6, 0.06]], P, c, [0.6])
	stripe(k, m, "cae_finstr", [[2.3, 2.25, 0.07, 0.05, 0.05], [3.4, 2.25, 0.05, 0.05, 0.05]], 2.3, 3.0, -PI, PI, P, sc, 0.0, 3)
	# fixed tricycle gear: a nose leg, spring-steel mains, wheels in spats
	var wr := 0.22
	rod(k, m, Vector3(0, 0.95, -2.45), Vector3(0, wr, -2.55), 0.045, "steel", Color(0.6, 0.6, 0.58), 8)
	for s in [-1.0, 1.0, 0.0]:
		var wp := Vector3(s * 1.32, wr, -0.05) if s != 0.0 else Vector3(0, wr, -2.6)
		if s != 0.0:
			rod(k, m, Vector3(s * 0.45, 0.85, -0.1), wp + Vector3(-s * 0.1, 0.05, 0), 0.05, "car_paint", c, 8, 0.04)
		k._cyl(m, wr, wr, 0.13, wp, Vector3(0, 0, PI / 2), "rubber", null, 16)
		k._cyl(m, wr * 0.5, wr * 0.5, 0.15, wp, Vector3(0, 0, PI / 2), "steel", null, 12, false)
		body(k, m, "cae_spat", [[-0.48, 0.0, 0.04, 0.05, 0.04], [-0.35, 0.0, 0.12, 0.17, 0.12], [-0.05, 0.0, 0.15, 0.2, 0.14], [0.25, 0.0, 0.13, 0.17, 0.1], [0.5, 0.02, 0.03, 0.05, 0.03]], P, c, 14, 50.0, wp + Vector3(0, 0.07, 0.02))
	# the propeller: three blades with painted tips, the spinner
	prop(k, m, "cae_prop", Vector3(0, 1.32, -3.55), 0.97, 3, 0.17, 0.17, Vector3.ZERO, false, Color(0.12, 0.12, 0.12), Color(0.75, 0.72, 0.6))
	# antennas on the roof and belly, the pitot under the left wing
	antenna(k, m, Vector3(0, 2.28, 0.6), 0.18, false, Color(0.25, 0.25, 0.25))
	antenna(k, m, Vector3(0, 0.84, 0.4), 0.14, true, Color(0.25, 0.25, 0.25))
	rod(k, m, Vector3(-3.6, 0.95, -0.6), Vector3(-3.6, 0.95, -1.1), 0.015, "steel", null, 6)


# --- F/A-181 Black Wasp II ----------------------------------------------------------

## F/A-181 Black Wasp II: a Super Hornet's fuselage (chined nose, big LEXes,
## raked caret intakes under them), an F-35C's one-piece canopy and chin
## sensor, an F-22's trapezoid wing, twin canted fins, diamond stabilators and
## the two engines' flat thrust-vectoring nozzles. Sidewinders on the tips,
## a Paveway and an AMRAAM under each wing, the gun in the right LEX. NATO grey.
static func _blackwasp(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := NATO
	var A := "aircraft"
	var st := [
		[-9.25, 1.2, 0.0, 0.0, 0.0],
		[-8.95, 1.21, 0.12, 0.09, 0.08, 1.7, 1.5],
		[-8.1, 1.24, 0.32, 0.26, 0.22, 1.8, 1.5],
		[-6.9, 1.28, 0.52, 0.44, 0.36, 1.9, 1.5],
		[-5.6, 1.3, 0.68, 0.56, 0.48, 2.1, 1.6],
		[-4.2, 1.3, 0.84, 0.6, 0.58, 2.2, 1.8],
		[-2.6, 1.3, 1.0, 0.58, 0.62, 2.4, 2.2],
		[-0.8, 1.3, 1.2, 0.52, 0.62, 2.8, 2.4],
		[1.5, 1.3, 1.25, 0.48, 0.6, 3.0, 2.6],
		[4.0, 1.3, 1.15, 0.42, 0.55, 3.0, 2.8],
		[6.0, 1.3, 0.95, 0.35, 0.48, 3.0, 3.0],
		[7.4, 1.3, 0.75, 0.28, 0.38, 3.0, 3.0],
		[7.9, 1.3, 0.6, 0.24, 0.3, 3.0, 3.0],
	]
	body(k, m, "bw_fus", st, A, c)
	stripe(k, m, "bw_rad", st, -9.25, -7.4, -PI, PI, A, c.darkened(0.16), 0.004, 20)
	body(k, m, "bw_spine", [[-4.0, 1.7, 0.45, 0.45, 0.1], [-2.4, 1.72, 0.6, 0.34, 0.1, 2.8], [0.5, 1.7, 0.75, 0.26, 0.1, 3.2], [4.0, 1.66, 0.6, 0.18, 0.1, 3.2], [6.5, 1.56, 0.32, 0.1, 0.1]], A, c, 18)
	# the F-35 canopy: one piece, a single bow behind the seat; the chin sensor
	var cst := [[-7.15, 1.68, 0.3, 0.05, 0.05], [-6.6, 1.7, 0.45, 0.36, 0.05], [-5.8, 1.72, 0.52, 0.56, 0.05], [-4.9, 1.74, 0.5, 0.6, 0.05],
		[-4.0, 1.76, 0.42, 0.48, 0.05], [-3.3, 1.78, 0.28, 0.26, 0.05]]
	body(k, m, "bw_can", cst, "glass", null, 18, 60.0)
	band(k, m, "bw_bow", cst, -4.3, 0.09, 0.02, A, c.darkened(0.2), 18)
	band(k, m, "bw_bowr", cst, -3.45, 0.08, 0.02, A, c.darkened(0.2), 18)
	body(k, m, "bw_eots", [[-7.0, 0.95, 0.0, 0.0, 0.0], [-6.8, 0.95, 0.13, 0.04, 0.12, 2.0, 1.2], [-6.4, 0.95, 0.15, 0.04, 0.13, 2.0, 1.2], [-6.15, 0.95, 0.0, 0.0, 0.0]], "glass", null, 12, 20.0)
	# LEXes from the cockpit to the wing root
	surf(k, m, "bw_lex", [[Vector3(0.55, 1.3, -6.1), 6.1, 0.12], [Vector3(2.3, 1.29, -1.5), 1.6, 0.06]], A, c, [])
	# caret intakes under the LEXes, ducts running back into the engine bays
	var ist := [[-3.4, 0.92, 0.34, 0.36, 0.36, 3.5, 3.5, 1.08, 0.55, 0.35], [-2.8, 0.93, 0.36, 0.38, 0.38, 3.2, 3.2, 1.06], [-1.0, 0.95, 0.33, 0.37, 0.38, 3.0, 3.0, 0.98],
		[1.0, 0.98, 0.22, 0.3, 0.32, 3.0, 3.0, 0.86], [2.5, 1.0, 0.08, 0.2, 0.2, 2.5, 2.5, 0.76]]
	body2(k, m, "bw_int", ist, A, c, 16)
	for s in [-1.0, 1.0]:
		var q: Array = _sp(ist[0]) if s > 0.0 else _mx(ist[0])
		mouth(k, m, "bw_mouth" + ("L" if s < 0.0 else ""), q, 0.8)
		k._box(m, Vector3(0.03, 0.66, 0.7), Vector3(s * 0.72, 0.94, -3.0), A, c.darkened(0.1))
	# engine bays and the flat two-dimensional nozzles
	for s in [-1.0, 1.0]:
		var nx: float = s * 0.6
		body(k, m, "bw_nac" + ("L" if s < 0.0 else ""), [[-0.5, 1.0, 0.36, 0.36, 0.38, 2.6, 2.6, nx], [2.0, 0.98, 0.48, 0.4, 0.44, 2.6, 2.8, nx], [5.0, 1.0, 0.47, 0.4, 0.42, 2.8, 3.0, nx],
			[7.5, 1.02, 0.44, 0.36, 0.36, 3.5, 3.5, nx]], A, c, 18)
		var zst := [[7.45, 1.02, 0.44, 0.34, 0.34, 4.0, 4.0, nx], [8.3, 1.02, 0.43, 0.29, 0.29, 4.0, 4.0, nx], [8.8, 1.02, 0.41, 0.17, 0.17, 4.0, 4.0, nx]]
		body(k, m, "bw_noz" + ("L" if s < 0.0 else ""), zst, "gunmetal_w", c.darkened(0.42), 18, 30.0)
		var zq := _sp(zst[2])
		mouth(k, m, "bw_pipe" + ("L" if s < 0.0 else ""), zq, 0.82, 1.0)
	glow(k, m, [Vector3(-0.6, 1.02, 9.15), Vector3(0.6, 1.02, 9.15)], 1.05)
	# the F-22 wing: trapezoid, flaperons inboard, ailerons outboard
	var ws := [[Vector3(0.9, 1.25, -2.83), 7.88, 0.3], [Vector3(3.6, 1.15, -0.4), 4.9, 0.2], [Vector3(6.8, 1.02, 2.48), 1.4, 0.1]]
	surf(k, m, "bw_wing", ws, A, c, [0.8, 0.76])
	# twin fins canted out, rudders; diamond stabilators
	surf(k, m, "bw_fin", [[Vector3(0.95, 1.62, 2.6), 3.4, 0.18], [Vector3(2.22, 4.0, 5.0), 1.45, 0.08]], A, c, [0.7])
	surf(k, m, "bw_stab", [[Vector3(0.95, 1.08, 4.6), 3.8, 0.14], [Vector3(4.1, 1.0, 6.6), 1.4, 0.06]], A, c, [])
	# wingtip rails with Sidewinders, navigation lights
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.08, 0.1, 2.0), Vector3(s * 6.86, 1.02, 3.0), A, c)
		missile(k, m, Vector3(s * 6.86, 0.9, 2.7), 2.85, 0.064, STORE_GREY, false)
	nav_lights(k, m, Vector3(6.9, 1.08, 2.4), 0.06)
	# gun in the right LEX, probes, antennas, the tail hook, weapon bay doors
	k._box(m, Vector3(0.12, 0.05, 0.5), Vector3(1.0, 1.36, -3.1), "plain_dark", null, Vector3.ZERO, false)
	k.mg_tip = k._tip(m, Vector3(1.0, 1.38, -3.4))
	k.gun_tip = k.mg_tip
	antenna(k, m, Vector3(0, 2.02, -1.5), 0.26)
	antenna(k, m, Vector3(0, 0.66, 2.5), 0.2, true)
	rod(k, m, Vector3(0, 0.95, 6.4), Vector3(0, 0.75, 8.1), 0.045, "gunmetal_w", null, 6)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.012, 0.02, 3.6), Vector3(s * 0.32, 0.69, 0.6), "gunmetal_w", null, Vector3.ZERO, false)
	# stores: a Paveway and an AMRAAM under each wing
	for sd in [-1.0, 1.0]:
		for x in [2.7, 4.6]:
			var w := surf_at(ws, x)
			var le: Vector3 = w[0]
			var at := Vector3(sd * x, le.y - float(w[2]) * 0.3, le.z + float(w[1]) * 0.4)
			if x < 3.0:
				bomb(k, m, pylon(k, m, at, 1.5, 0.26, c, 0.16), 2.4, 0.16, true)
			else:
				missile(k, m, pylon(k, m, at, 1.2, 0.14, c, 0.09), 3.65, 0.09)
	wing_marks(k, m, team, ws, 5.3, 0.6)
	for s in [-1.0, 1.0]:
		k._team_mark(m, team, Vector3(s * 1.43, 0.95, -1.5), Vector3(0.02, 0.36, 0.36))


# --- To-201 Shikra ------------------------------------------------------------------

## To-201 Shikra (Su-57 with Su-35 touches): a long chined nose with the IRST
## ball ahead of the bubble canopy, a flat lifting body between two widely
## spaced engine nacelles (the tunnel under it), raked intakes under the
## LEVCONs, a big trapezoid wing, all-moving canted fins and tailplanes on
## tail booms, the sting between the round nozzles. Two-tone CSAT.
static func _shikra(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := CSAT
	var c2 := Color(0.37, 0.37, 0.34)
	var A := "aircraft"
	var st := [
		[-10.05, 1.3, 0.0, 0.0, 0.0],
		[-9.7, 1.31, 0.13, 0.1, 0.09, 1.7, 1.5],
		[-8.7, 1.34, 0.34, 0.28, 0.24, 1.8, 1.5],
		[-7.4, 1.38, 0.52, 0.46, 0.38, 1.9, 1.5],
		[-6.0, 1.4, 0.66, 0.56, 0.46, 2.0, 1.6],
		[-4.6, 1.42, 0.78, 0.56, 0.46, 2.2, 1.8],
		[-3.0, 1.45, 0.95, 0.48, 0.38, 2.4, 2.0],
		[-0.5, 1.5, 1.15, 0.4, 0.3, 2.8, 2.4],
		[3.0, 1.5, 1.15, 0.36, 0.28, 3.0, 2.6],
		[6.0, 1.48, 0.95, 0.3, 0.25, 3.0, 2.6],
		[7.8, 1.45, 0.6, 0.25, 0.22],
		[8.6, 1.42, 0.3, 0.18, 0.15],
	]
	body(k, m, "shk_fus", st, A, c)
	stripe(k, m, "shk_rad", st, -10.05, -8.0, -PI, PI, A, c2, 0.004, 20)
	body(k, m, "shk_spine", [[-4.6, 1.85, 0.42, 0.38, 0.1], [-2.5, 1.86, 0.6, 0.26, 0.1, 2.8], [1.0, 1.86, 0.65, 0.2, 0.1, 3.2], [4.0, 1.82, 0.5, 0.14, 0.1, 3.2], [6.0, 1.75, 0.25, 0.08, 0.1]], A, c, 18)
	var cst := [[-7.6, 1.8, 0.3, 0.05, 0.05], [-7.1, 1.82, 0.44, 0.34, 0.05], [-6.3, 1.84, 0.5, 0.55, 0.05], [-5.4, 1.86, 0.48, 0.55, 0.05],
		[-4.6, 1.88, 0.38, 0.38, 0.05], [-4.1, 1.88, 0.22, 0.18, 0.05]]
	body(k, m, "shk_can", cst, "glass", null, 18, 60.0)
	band(k, m, "shk_bow0", cst, -7.05, 0.08, 0.02, A, c2, 18)
	band(k, m, "shk_bow1", cst, -4.75, 0.08, 0.02, A, c2, 18)
	k._add(m, Res.sphere(0.14, 12), "glass", null, Vector3(0.22, 1.76, -7.85))
	# the nacelles, raked intakes under the LEVCONs, round Su-35 nozzles
	var nst := [[-3.7, 1.0, 0.5, 0.45, 0.45, 3.0, 3.0, 1.38, 0.5, 0.0], [-3.0, 1.02, 0.54, 0.48, 0.48, 3.0, 3.0, 1.38], [0.0, 1.05, 0.56, 0.5, 0.5, 2.8, 2.8, 1.38],
		[4.0, 1.07, 0.55, 0.5, 0.5, 2.6, 2.6, 1.38], [7.0, 1.08, 0.5, 0.48, 0.48, 2.3, 2.3, 1.38], [8.2, 1.08, 0.48, 0.48, 0.48, 2.0, 2.0, 1.38]]
	body2(k, m, "shk_nac", nst, A, c, 20)
	for s in [-1.0, 1.0]:
		var q: Array = _sp(nst[0]) if s > 0.0 else _mx(nst[0])
		mouth(k, m, "shk_mouth" + ("L" if s < 0.0 else ""), q, 0.82)
		nozzle(k, m, Vector3(s * 1.38, 1.08, 8.55), 0.47, 0.7, c, 0.86)
	glow(k, m, [Vector3(-1.38, 1.08, 9.3), Vector3(1.38, 1.08, 9.3)], 1.3)
	# LEVCONs, the wing with ailerons and flaperons
	surf(k, m, "shk_levcon", [[Vector3(0.85, 1.5, -4.9), 2.9, 0.1], [Vector3(2.4, 1.48, -2.3), 0.9, 0.05]], A, c2, [])
	var ws := [[Vector3(1.3, 1.52, -2.4), 7.2, 0.3], [Vector3(3.8, 1.5, 0.25), 4.6, 0.2], [Vector3(7.05, 1.45, 3.65), 1.6, 0.1]]
	surf(k, m, "shk_wing", ws, A, c, [0.8, 0.78])
	# tail booms carrying the all-moving tailplanes; all-moving canted fins
	body2(k, m, "shk_boom", [[3.0, 1.2, 0.0, 0.0, 0.0, 2, 2, 2.05], [3.8, 1.2, 0.15, 0.14, 0.14, 2, 2, 2.05], [8.2, 1.2, 0.15, 0.14, 0.14, 2, 2, 2.05], [9.4, 1.2, 0.04, 0.05, 0.04, 2, 2, 2.05]], A, c, 12)
	surf(k, m, "shk_stab", [[Vector3(2.22, 1.2, 6.0), 3.0, 0.14], [Vector3(4.85, 1.18, 8.0), 1.15, 0.06]], A, c, [])
	surf(k, m, "shk_fin", [[Vector3(1.42, 1.6, 3.9), 2.9, 0.16], [Vector3(2.42, 3.67, 6.0), 1.2, 0.07]], A, c2, [])
	for s in [-1.0, 1.0]:
		k._cyl(m, 0.07, 0.07, 0.16, Vector3(s * 1.5, 1.62, 5.2), Vector3(0, 0, s * 0.45), "gunmetal_w", null, 8, false)
	# the sting between the nozzles
	body(k, m, "shk_sting", [[6.5, 1.42, 0.0, 0.0, 0.0], [7.0, 1.42, 0.28, 0.22, 0.22], [9.0, 1.4, 0.26, 0.2, 0.2], [10.0, 1.4, 0.1, 0.09, 0.09]], A, c, 14)
	# the gun at the right wing root, antennas, navigation lights
	k._box(m, Vector3(0.12, 0.05, 0.5), Vector3(1.0, 1.58, -3.3), "plain_dark", null, Vector3.ZERO, false)
	k.mg_tip = k._tip(m, Vector3(1.0, 1.6, -3.6))
	k.gun_tip = k.mg_tip
	antenna(k, m, Vector3(0, 2.07, -2.0), 0.26)
	antenna(k, m, Vector3(0, 1.2, 3.5), 0.2, true)
	nav_lights(k, m, Vector3(7.08, 1.47, 4.4), 0.06)
	# stores: Kh-38s under the nacelles, KAB bombs and R-73s under the wings
	for sd in [-1.0, 1.0]:
		agm(k, m, pylon(k, m, Vector3(sd * 1.38, 0.6, 0.6), 1.6, 0.14, c, 0.17), 3.6, 0.17)
		for x in [3.4, 5.4]:
			var w := surf_at(ws, x)
			var le: Vector3 = w[0]
			var at := Vector3(sd * x, le.y - float(w[2]) * 0.3, le.z + float(w[1]) * 0.42)
			if x < 4.0:
				bomb(k, m, pylon(k, m, at, 1.6, 0.26, c, 0.2), 3.0, 0.2, true)
			else:
				missile(k, m, pylon(k, m, at, 1.0, 0.14, c, 0.08), 2.9, 0.08)
	wing_marks(k, m, team, ws, 5.9, 0.65)
	for s in [-1.0, 1.0]:
		k._team_mark(m, team, Vector3(s * 1.95, 1.08, 2.5), Vector3(0.02, 0.36, 0.36))


# --- To-199 Neophron ----------------------------------------------------------------

## To-199 Neophron (Yak-130, single-seat Yak-131): a slender nose, a bubble
## canopy, the shoulder wing fed by long wing-root extensions, the two engines
## in nacelles under them with raked intakes, a tall swept fin, low
## stabilators. R-73s on the tips; bombs, rocket pods and missiles underwing,
## the twin-cannon pod on the centreline. CSAT.
static func _neophron(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := CSAT
	var A := "aircraft"
	var st := [
		[-5.75, 1.08, 0.0, 0.0, 0.0],
		[-5.5, 1.08, 0.08, 0.08, 0.08],
		[-4.9, 1.1, 0.24, 0.25, 0.23],
		[-4.0, 1.13, 0.38, 0.4, 0.36],
		[-3.0, 1.15, 0.46, 0.5, 0.45, 2.2, 2.4],
		[-1.8, 1.15, 0.5, 0.56, 0.48, 2.3, 2.5],
		[-0.4, 1.17, 0.5, 0.58, 0.46, 2.4, 2.5],
		[1.4, 1.2, 0.46, 0.54, 0.42, 2.4, 2.4],
		[3.2, 1.25, 0.38, 0.45, 0.32],
		[4.6, 1.3, 0.26, 0.32, 0.2],
		[5.6, 1.32, 0.14, 0.18, 0.1],
		[5.75, 1.32, 0.06, 0.08, 0.05],
	]
	body(k, m, "neo_fus", st, A, c)
	stripe(k, m, "neo_rad", st, -5.75, -4.3, -PI, PI, A, c.darkened(0.2), 0.004, 20)
	band(k, m, "neo_tjoint", st, 3.4, 0.03, 0.005, A, c.darkened(0.2))
	body(k, m, "neo_spine", [[-1.4, 1.6, 0.3, 0.32, 0.1], [0.0, 1.6, 0.3, 0.28, 0.1], [2.0, 1.6, 0.2, 0.18, 0.1], [3.2, 1.58, 0.1, 0.1, 0.1]], A, c, 14)
	var cst := [[-3.75, 1.6, 0.26, 0.05, 0.05], [-3.3, 1.6, 0.38, 0.32, 0.05], [-2.6, 1.62, 0.42, 0.5, 0.05], [-1.9, 1.63, 0.4, 0.48, 0.05],
		[-1.3, 1.64, 0.32, 0.32, 0.05], [-0.9, 1.64, 0.18, 0.15, 0.05]]
	body(k, m, "neo_can", cst, "glass", null, 18, 60.0)
	band(k, m, "neo_bow0", cst, -3.25, 0.07, 0.018, A, c.darkened(0.2), 18)
	band(k, m, "neo_bow1", cst, -1.35, 0.07, 0.018, A, c.darkened(0.2), 18)
	# engine nacelles under the wing-root extensions, intakes raked back
	var nst := [[-1.7, 0.74, 0.32, 0.35, 0.35, 2.8, 2.8, 0.7, -0.4, 0.0], [-1.2, 0.74, 0.36, 0.38, 0.38, 2.8, 2.8, 0.7], [1.0, 0.74, 0.37, 0.4, 0.4, 2.6, 2.6, 0.68],
		[3.0, 0.76, 0.34, 0.36, 0.36, 2.4, 2.4, 0.64], [3.95, 0.78, 0.3, 0.3, 0.3, 2.2, 2.2, 0.62]]
	body2(k, m, "neo_nac", nst, A, c, 18)
	for s in [-1.0, 1.0]:
		var q: Array = _sp(nst[0]) if s > 0.0 else _mx(nst[0])
		mouth(k, m, "neo_mouth" + ("L" if s < 0.0 else ""), q, 0.8)
		nozzle(k, m, Vector3(s * 0.62, 0.78, 4.08), 0.28, 0.26, c, 0.92)
	glow(k, m, [Vector3(-0.62, 0.78, 4.4), Vector3(0.62, 0.78, 4.4)], 0.9, Color(0.7, 0.4, 0.22))
	# LERX into the shoulder wing, the fin and the stabilators
	surf(k, m, "neo_lerx", [[Vector3(0.42, 1.38, -3.3), 3.3, 0.12], [Vector3(1.2, 1.42, -0.75), 0.9, 0.06]], A, c, [])
	var ws := [[Vector3(0.4, 1.5, -0.35), 2.75, 0.3], [Vector3(2.6, 1.44, 0.45), 1.95, 0.2], [Vector3(4.92, 1.36, 1.3), 1.15, 0.12]]
	surf(k, m, "neo_wing", ws, A, c, [0.75, 0.75])
	surf(k, m, "neo_fin", [[Vector3(0, 1.55, 1.9), 2.8, 0.2], [Vector3(0, 3.55, 4.1), 1.05, 0.09]], A, c, [0.7], false)
	surf(k, m, "neo_stab", [[Vector3(0.3, 1.2, 3.55), 1.6, 0.12], [Vector3(2.25, 1.15, 4.35), 0.75, 0.06]], A, c, [])
	# tip rails with R-73s, lights, probes, antennas
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.08, 0.1, 1.6), Vector3(s * 4.98, 1.36, 1.9), A, c)
		missile(k, m, Vector3(s * 4.98, 1.25, 1.6), 2.9, 0.08, STORE_GREY, false)
	nav_lights(k, m, Vector3(5.0, 1.42, 1.3), 0.06)
	rod(k, m, Vector3(0, 1.08, -5.7), Vector3(0, 1.08, -6.2), 0.028, "gunmetal_w", null, 6, 0.011)
	antenna(k, m, Vector3(0, 1.88, 0.4), 0.24)
	antenna(k, m, Vector3(0, 0.72, -2.4), 0.18, true)
	# stores: the gun pod; bombs, B-8 rocket pods and R-73s underwing
	var gc := pylon(k, m, Vector3(0, 0.72, 0.6), 1.3, 0.12, c, 0.2)
	var mz := gun_pod(k, m, gc, 2.4, 0.2, c.darkened(0.1))
	k.mg_tip = k._tip(m, mz + Vector3(0, 0, -0.05))
	k.gun_tip = k.mg_tip
	for sd in [-1.0, 1.0]:
		for x in [1.7, 2.8, 3.85]:
			var w := surf_at(ws, x)
			var le: Vector3 = w[0]
			var at := Vector3(sd * x, le.y - float(w[2]) * 0.3, le.z + float(w[1]) * 0.42)
			if x < 2.0:
				bomb(k, m, pylon(k, m, at, 1.2, 0.24, c, 0.16), 2.1, 0.16)
			elif x < 3.0:
				rocket_pod(k, m, pylon(k, m, at, 1.2, 0.2, c, 0.26), 2.5, 0.26, Color(0.4, 0.42, 0.38))
			else:
				missile(k, m, pylon(k, m, at, 0.9, 0.14, c, 0.08), 2.9, 0.08)
	wing_marks(k, m, team, ws, 3.6, 0.5)
	for s in [-1.0, 1.0]:
		k._team_mark(m, team, Vector3(s * 0.068, 2.9, 3.8), Vector3(0.02, 0.36, 0.36))


# --- MQ-4A Greyhawk -----------------------------------------------------------------

## MQ-4A Greyhawk (MQ-9 Reaper with canards): a slender fuselage with the
## bulbous satellite-dish nose, the sensor ball under it, small canards, a
## long straight high-aspect wing, the Y tail (a V-tail over a ventral fin
## guarding the propeller), the rear pusher turboprop with its intakes and
## exhaust stubs. A Paveway on each of its two pylons. NATO.
static func _greyhawk(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := NATO.lightened(0.1)
	var A := "aircraft"
	var st := [
		[-5.45, 0.95, 0.0, 0.0, 0.0],
		[-5.32, 0.95, 0.2, 0.22, 0.2],
		[-5.0, 0.97, 0.34, 0.38, 0.32],
		[-4.4, 1.0, 0.43, 0.55, 0.4],
		[-3.6, 1.0, 0.46, 0.6, 0.42],
		[-2.6, 1.0, 0.46, 0.53, 0.43, 2.2, 2.2],
		[-1.2, 1.0, 0.45, 0.47, 0.44, 2.3, 2.3],
		[0.5, 1.0, 0.44, 0.45, 0.44, 2.3, 2.3],
		[2.0, 1.02, 0.4, 0.42, 0.4],
		[3.4, 1.05, 0.32, 0.33, 0.3],
		[4.5, 1.08, 0.21, 0.22, 0.19],
		[5.0, 1.08, 0.15, 0.15, 0.14],
	]
	body(k, m, "gh_fus", st, A, c)
	# the dish housing a shade lighter, its joint line
	stripe(k, m, "gh_dome", st, -5.45, -2.9, -0.35, PI + 0.35, A, c.lightened(0.08), 0.004, 14)
	# the sensor ball under the nose, its window looking forward
	k._cyl(m, 0.12, 0.14, 0.22, Vector3(0, 0.55, -4.3), Vector3.ZERO, A, c)
	k._add(m, Res.sphere(0.27, 16), "paint", Color(0.55, 0.56, 0.55), Vector3(0, 0.3, -4.3))
	k._add(m, Res.sphere(0.13, 12), "glass", null, Vector3(0, 0.27, -4.52), Vector3.ZERO, Vector3(1.0, 1.0, 0.5))
	k._add(m, Res.sphere(0.06, 8), "glass", null, Vector3(0.12, 0.34, -4.5), Vector3.ZERO, Vector3(1.0, 1.0, 0.5))
	# canards, the wing with flaps and ailerons
	surf(k, m, "gh_canard", [[Vector3(0.36, 0.95, -3.4), 0.5, 0.06], [Vector3(1.25, 0.97, -3.2), 0.28, 0.03]], A, c, [0.65])
	var ws := [[Vector3(0.35, 1.28, -0.75), 1.35, 0.2], [Vector3(4.6, 1.38, -0.55), 0.95, 0.12], [Vector3(10.0, 1.52, -0.3), 0.5, 0.06]]
	surf(k, m, "gh_wing", ws, A, c, [0.72, 0.72])
	nav_lights(k, m, Vector3(10.0, 1.52, -0.1), 0.05)
	# the Y tail: ruddervators up, the ventral fin down
	surf(k, m, "gh_vtail", [[Vector3(0.12, 1.25, 3.2), 1.05, 0.09], [Vector3(1.8, 2.75, 3.8), 0.55, 0.04]], A, c, [0.68])
	surf(k, m, "gh_ventral", [[Vector3(0, 0.85, 3.3), 1.0, 0.09], [Vector3(0, -0.25, 3.8), 0.6, 0.04]], A, c, [0.68], false)
	# the turboprop: dorsal NACA inlet, ventral scoop, exhaust stubs; the prop
	k._box(m, Vector3(0.22, 0.03, 0.5), Vector3(0, 1.46, 1.4), "plain_dark", null, Vector3(0.08, 0, 0), false)
	var sst := [[1.5, 0.6, 0.15, 0.1, 0.12, 2.5, 2.5, 0, 0.5], [2.1, 0.6, 0.17, 0.11, 0.13, 2.5, 2.5], [3.1, 0.66, 0.1, 0.08, 0.08]]
	body(k, m, "gh_scoop", sst, A, c, 14)
	mouth(k, m, "gh_scoopm", sst[0], 0.7)
	for s in [-1.0, 1.0]:
		rod(k, m, Vector3(s * 0.25, 1.02, 3.5), Vector3(s * 0.36, 1.0, 3.9), 0.06, "gunmetal_w", null, 8)
	prop(k, m, "gh_prop", Vector3(0, 1.08, 5.2), 1.08, 3, 0.2, 0.15, Vector3.ZERO, true, Color(0.3, 0.31, 0.32))
	# antennas: the satcom blades, the belly whips
	antenna(k, m, Vector3(0, 1.45, -1.0), 0.22, false, c.darkened(0.4))
	antenna(k, m, Vector3(0, 1.44, 0.6), 0.18, false, c.darkened(0.4))
	antenna(k, m, Vector3(0, 0.56, -1.8), 0.2, true, c.darkened(0.4))
	# two pylons, a Paveway on each
	for sd in [-1.0, 1.0]:
		var w := surf_at(ws, 2.9)
		var le: Vector3 = w[0]
		var at := Vector3(sd * 2.9, le.y - float(w[2]) * 0.3, le.z + float(w[1]) * 0.42)
		bomb(k, m, pylon(k, m, at, 0.9, 0.18, c, 0.16), 2.4, 0.16, true)
	k.gun_tip = k._tip(m, Vector3(0, 0.3, -4.6))
	wing_marks(k, m, team, ws, 7.6, 0.45)


# --- UCAV Sentinel ------------------------------------------------------------------

## UCAV Sentinel (Northrop Grumman X-47B): a tailless cranked-kite flying wing.
## A thick lifting body swept back from a sharp nose to a point at the tail,
## the dorsal caret intake behind the nose, the buried exhaust on top at the
## back, cranked outer wings with elevons. Internal bays. Dark grey.
static func _sentinel(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := Color(0.3, 0.32, 0.34)
	var A := "aircraft"
	var yc := 0.7
	var st := [
		[-5.8, yc, 0.0, 0.0, 0.0],
		[-5.3, yc, 0.27, 0.14, 0.08, 1.4, 1.6],
		[-4.0, yc, 0.96, 0.5, 0.22, 1.4, 1.6],
		[-2.5, yc, 1.76, 0.7, 0.3, 1.4, 1.6],
		[-1.0, yc, 2.55, 0.72, 0.32, 1.4, 1.6],
		[0.4, yc, 3.3, 0.66, 0.3, 1.4, 1.6],
		[2.6, yc, 3.3, 0.5, 0.25, 1.4, 1.6],
		[4.2, yc, 1.65, 0.3, 0.16, 1.5, 1.6],
		[5.8, yc, 0.0, 0.0, 0.0],
	]
	body(k, m, "sen_body", st, A, c, 28, 34.0)
	# the dorsal intake: a raked hood standing off the hump, its dark mouth
	var ist := [[-3.6, 1.18, 0.5, 0.24, 0.12, 2.6, 2.0, 0.0, -0.6], [-3.2, 1.22, 0.56, 0.26, 0.14, 2.6, 2.0], [-2.0, 1.3, 0.56, 0.24, 0.15, 2.4, 2.0],
		[-0.4, 1.32, 0.32, 0.14, 0.15, 2.2, 2.0], [0.7, 1.3, 0.05, 0.05, 0.1]]
	body(k, m, "sen_hood", ist, A, c, 18)
	mouth(k, m, "sen_mouth", ist[0], 0.78)
	# the exhaust buried in the upper surface at the back
	var est := [[1.4, 1.12, 0.2, 0.08, 0.1, 2.5, 2.5], [2.4, 1.13, 0.48, 0.13, 0.1, 3.0, 2.5], [3.3, 1.1, 0.55, 0.1, 0.1, 3.5, 2.5]]
	body(k, m, "sen_exh", est, A, c, 18)
	# (no exhaust glow: the pipe is buried in the upper surface to hide it)
	mouth(k, m, "sen_pipe", est[2], 0.8, 1.0)
	# the cranked outer wings: elevons, the fold line
	var ws := [[Vector3(2.6, yc, 0.0), 2.75, 0.2], [Vector3(6.0, yc + 0.06, 1.72), 1.9, 0.12], [Vector3(9.46, yc + 0.12, 3.4), 1.0, 0.07]]
	surf(k, m, "sen_wing", ws, A, c, [0.78, 0.74])
	nav_lights(k, m, Vector3(9.47, yc + 0.12, 3.8), 0.05)
	# body elevons along the inner trailing edges
	for s in [-1.0, 1.0]:
		var a := Vector3(s * 3.1, yc, 2.95)
		var b := Vector3(s * 0.9, yc, 4.95)
		var mid := (a + b) * 0.5
		k._box(m, Vector3(0.012, 0.02, a.distance_to(b)), mid + Vector3(0, 0.12, -0.25), "gunmetal_w", null, Vector3(0, atan2(b.x - a.x, b.z - a.z), 0), false)
	# the sensor window under the nose, belly doors, the hook, antennas
	k._box(m, Vector3(0.3, 0.02, 0.4), Vector3(0, yc - 0.12, -4.4), "glass", null, Vector3(0.1, 0, 0), false)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.012, 0.02, 2.8), Vector3(s * 0.55, yc - 0.31, -0.6), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(1.1, 0.02, 0.012), Vector3(0, yc - 0.31, -2.0), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(1.1, 0.02, 0.012), Vector3(0, yc - 0.31, 0.8), "gunmetal_w", null, Vector3.ZERO, false)
	rod(k, m, Vector3(0, yc - 0.15, 3.2), Vector3(0, yc - 0.25, 4.6), 0.04, "gunmetal_w", null, 6)
	antenna(k, m, Vector3(0, yc - 0.32, -3.0), 0.16, true, c.darkened(0.3))
	# flush satcom and GPS patches on the hump, the refuelling probe door
	k._box(m, Vector3(0.7, 0.02, 0.5), Vector3(0, yc + 0.73, -0.9), "paint", c.lightened(0.12), Vector3.ZERO, false)
	k._box(m, Vector3(0.25, 0.02, 0.25), Vector3(0.5, yc + 0.62, 0.6), "paint", c.lightened(0.12), Vector3.ZERO, false)
	k._box(m, Vector3(0.4, 0.02, 0.9), Vector3(1.1, yc + 0.5, -1.9), A, c.darkened(0.12), Vector3(0, 0, -0.3), false)
	k.gun_tip = k._tip(m, Vector3(0, yc - 0.3, 0.0))
	wing_marks(k, m, team, ws, 7.6, 0.55)


# --- KH-3A Fenghuang ----------------------------------------------------------------

## KH-3A Fenghuang (CASC CH-3A Rainbow): a small canard drone, a rounded
## fuselage with the sensor ball under it, canards up front, the main wing
## at the back with fins at its tips (no central fin), the rear pusher
## propeller, fixed tricycle gear. Four small missiles. CSAT.
## It's a roster vehicle (vehicle.gd), so its propeller is a k.rotors rotor.
static func _fenghuang(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := CSAT.lightened(0.06)
	var A := "aircraft"
	var st := [
		[-2.75, 0.8, 0.0, 0.0, 0.0],
		[-2.62, 0.8, 0.15, 0.16, 0.15],
		[-2.3, 0.81, 0.25, 0.28, 0.25, 2.3, 2.3],
		[-1.6, 0.83, 0.29, 0.33, 0.3, 2.6, 2.6],
		[0.0, 0.85, 0.3, 0.34, 0.3, 2.7, 2.7],
		[1.4, 0.87, 0.27, 0.3, 0.27, 2.5, 2.5],
		[2.2, 0.88, 0.2, 0.22, 0.18],
		[2.5, 0.88, 0.13, 0.14, 0.12],
	]
	body(k, m, "fen_fus", st, A, c, 18)
	stripe(k, m, "fen_nose", st, -2.75, -2.1, -PI, PI, A, c.darkened(0.25), 0.004, 18)
	# canards with elevators; the main wing with ailerons; fins at its tips
	surf(k, m, "fen_canard", [[Vector3(0.2, 0.93, -2.15), 0.56, 0.07], [Vector3(1.3, 0.96, -2.0), 0.36, 0.04]], A, c, [0.65])
	var ws := [[Vector3(0.2, 1.05, 0.55), 0.95, 0.12], [Vector3(4.0, 1.15, 0.85), 0.55, 0.06]]
	surf(k, m, "fen_wing", ws, A, c, [0.72])
	surf(k, m, "fen_tipfin", [[Vector3(4.03, 0.8, 0.95), 0.48, 0.05], [Vector3(4.03, 1.15, 0.8), 0.62, 0.06], [Vector3(4.03, 1.62, 1.08), 0.4, 0.04]], A, c, [0.0, 0.62])
	# the engine's air scoop on top, the exhaust, the pusher propeller
	var sst := [[1.0, 1.13, 0.08, 0.06, 0.06, 2.5, 2.5, 0.0, -0.4], [1.4, 1.15, 0.1, 0.07, 0.07], [2.1, 1.1, 0.04, 0.03, 0.04]]
	body(k, m, "fen_scoop", sst, A, c, 12)
	mouth(k, m, "fen_scoopm", sst[0], 0.7)
	rod(k, m, Vector3(0.16, 0.75, 2.1), Vector3(0.24, 0.72, 2.45), 0.035, "gunmetal_w", null, 8)
	prop(k, m, "fen_prop", Vector3(0, 0.88, 2.62), 0.62, 3, 0.12, 0.1, Vector3.ZERO, true, Color(0.2, 0.2, 0.2), null, true)
	# the sensor ball
	k._cyl(m, 0.07, 0.08, 0.16, Vector3(0, 0.52, -1.3), Vector3.ZERO, A, c)
	k._add(m, Res.sphere(0.16, 14), "paint", Color(0.5, 0.5, 0.48), Vector3(0, 0.38, -1.3))
	k._add(m, Res.sphere(0.07, 10), "glass", null, Vector3(0, 0.37, -1.43), Vector3.ZERO, Vector3(1, 1, 0.5))
	# fixed tricycle gear
	rod(k, m, Vector3(0, 0.58, -1.95), Vector3(0, 0.12, -2.0), 0.022, "steel", Color(0.55, 0.55, 0.52), 6)
	k._cyl(m, 0.11, 0.11, 0.06, Vector3(0, 0.11, -2.0), Vector3(0, 0, PI / 2), "rubber", null, 12)
	for s in [-1.0, 1.0]:
		rod(k, m, Vector3(s * 0.18, 0.6, 0.5), Vector3(s * 0.72, 0.14, 0.55), 0.025, "steel", Color(0.55, 0.55, 0.52), 6)
		k._cyl(m, 0.13, 0.13, 0.07, Vector3(s * 0.74, 0.13, 0.55), Vector3(0, 0, PI / 2), "rubber", null, 12)
	# antennas: the satcom blade, a whip
	antenna(k, m, Vector3(0, 1.18, -0.6), 0.14, false, c.darkened(0.4))
	rod(k, m, Vector3(0, 0.55, 0.0), Vector3(0, 0.3, 0.3), 0.008, "gunmetal_w", null, 4)
	# four small missiles, two under each wing
	for sd in [-1.0, 1.0]:
		for x in [1.3, 2.3]:
			var w := surf_at(ws, x)
			var le: Vector3 = w[0]
			var at := Vector3(sd * x, le.y - float(w[2]) * 0.3, le.z + float(w[1]) * 0.45)
			agm(k, m, pylon(k, m, at, 0.55, 0.1, c, 0.08), 1.4, 0.08)
	k.gun_tip = k._tip(m, Vector3(0, 0.37, -1.48))
	wing_marks(k, m, team, ws, 3.2, 0.35)


# --- V-44X Blackfish ----------------------------------------------------------------

## V-44X Blackfish: an Osprey grown by 1.4. A deep cabin with sponsons for the
## gear, a glazed V-22 nose and refuelling probe, a high, slightly
## forward-swept wing with fixed engine nacelles at its tips (V-280 style)
## whose proprotors tilt - shown half-way, converting - an upswept tail over
## the rear ramp, an H tail. The gunship (`armed`) carries an AC-130's guns
## on the left: a 20 mm Gatling forward, the 40 mm and the 105 mm aft. NATO.
static func _blackfish(k: VehicleModels, team: int, armed: bool) -> void:
	var m := k.root
	var c := NATO
	var A := "aircraft"
	var st := [
		[-12.25, 1.95, 0.0, 0.0, 0.0],
		[-12.05, 1.95, 0.3, 0.3, 0.28],
		[-11.5, 2.0, 0.72, 0.75, 0.68, 2.2, 2.3],
		[-10.5, 2.1, 1.08, 1.18, 1.05, 2.3, 2.5],
		[-9.2, 2.2, 1.36, 1.55, 1.4, 2.5, 2.8],
		[-7.6, 2.28, 1.54, 1.85, 1.75, 2.6, 3.0],
		[-5.0, 2.3, 1.6, 1.95, 1.9, 2.7, 3.3],
		[2.5, 2.3, 1.6, 1.95, 1.9, 2.7, 3.3],
		[5.0, 2.42, 1.55, 1.85, 1.75, 2.7, 3.0],
		[7.5, 2.8, 1.35, 1.5, 1.2, 2.6, 2.6],
		[9.8, 3.3, 0.95, 1.05, 0.6, 2.4, 2.4],
		[11.6, 3.65, 0.45, 0.55, 0.28],
		[12.15, 3.72, 0.15, 0.22, 0.1],
	]
	body(k, m, "bf_fus", st, A, c, 24)
	# the glazed nose: windscreens, side and chin windows, their frames
	stripe(k, m, "bf_wind", st, -11.25, -8.9, 0.12, PI - 0.12, "glass", null, 0.012, 14)
	for s in [-1.0, 1.0]:
		var a0 := -0.62 if s > 0.0 else PI + 0.2
		stripe(k, m, "bf_chin" + ("L" if s < 0.0 else ""), st, -10.9, -9.7, a0, a0 + 0.42, "glass", null, 0.012, 5)
	for a in [PI / 2, 0.95, PI - 0.95, 0.35, PI - 0.35]:
		stripe(k, m, "bf_post%.2f" % a, st, -11.3, -8.85, a - 0.035, a + 0.035, A, c.darkened(0.15), 0.022, 3)
	stripe(k, m, "bf_wbow", st, -10.15, -10.05, 0.1, PI - 0.1, A, c.darkened(0.15), 0.022, 12)
	stripe(k, m, "bf_wbow2", st, -8.95, -8.85, 0.1, PI - 0.1, A, c.darkened(0.15), 0.022, 12)
	# cabin windows, the crew door on the right
	for s in [-1.0, 1.0]:
		for z in [-6.4, -3.2, 0.2, 3.0]:
			if s > 0.0 and z < -6.0:
				continue
			k._box(m, Vector3(0.03, 0.42, 0.42), Vector3(s * 1.585, 2.95, z), "glass", null, Vector3.ZERO, false)
	for z in [-7.25, -5.75]:
		k._box(m, Vector3(0.02, 1.9, 0.03), Vector3(1.6, 2.15, z), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.03, 0.42, 0.42), Vector3(1.6, 2.75, -6.5), "glass", null, Vector3.ZERO, false)
	# the sponsons for the main gear
	body2(k, m, "bf_spon", [[-4.3, 1.15, 0.0, 0.0, 0.0, 2, 2, 1.5], [-3.7, 1.15, 0.5, 0.45, 0.5, 2.4, 2.4, 1.6], [-2.0, 1.12, 0.8, 0.55, 0.65, 2.6, 2.6, 1.7],
		[2.0, 1.15, 0.8, 0.55, 0.65, 2.6, 2.6, 1.7], [3.8, 1.2, 0.55, 0.45, 0.5, 2.4, 2.4, 1.6], [4.8, 1.25, 0.08, 0.12, 0.12, 2, 2, 1.5]], A, c, 18)
	# the rear ramp's seams under the upswept tail
	for a in [-PI / 2 - 0.8, -PI / 2 + 0.8]:
		stripe(k, m, "bf_ramp%.2f" % a, st, 5.0, 9.7, a - 0.02, a + 0.02, "gunmetal_w", null, 0.01, 3)
	stripe(k, m, "bf_rampx", st, 4.98, 5.06, -PI / 2 - 0.8, -PI / 2 + 0.8, "gunmetal_w", null, 0.01, 10)
	# the high wing, slightly forward-swept, flaperons along it
	var ws := [[Vector3(0.0, 4.6, -1.4), 3.6, 0.75], [Vector3(9.0, 4.6, -2.3), 3.4, 0.6]]
	surf(k, m, "bf_wing", ws, A, c, [0.7])
	# fixed engine nacelles at the tips; tilting proprotors ahead of them
	var tilt := PI / 4
	for s in [-1.0, 1.0]:
		var nx: float = s * 9.85
		var nst := [[-3.0, 4.6, 0.95, 0.95, 0.95, 2.2, 2.2, nx], [-1.0, 4.6, 1.0, 1.05, 1.0, 2.3, 2.3, nx], [2.0, 4.6, 0.95, 1.0, 0.95, 2.3, 2.3, nx],
			[3.8, 4.6, 0.62, 0.66, 0.6, 2.2, 2.2, nx], [4.4, 4.6, 0.3, 0.35, 0.3, 2.0, 2.0, nx]]
		body(k, m, "bf_nac" + ("L" if s < 0.0 else ""), nst, A, c, 20)
		# the intake grille on top, the exhaust low on the outboard side
		k._box(m, Vector3(0.7, 0.05, 1.3), Vector3(nx, 5.6, -1.0), "plain_dark", null, Vector3(0.05, 0, 0), false)
		k._box(m, Vector3(0.12, 0.5, 0.9), Vector3(nx + s * 0.92, 4.2, 3.2), "gunmetal_w", null, Vector3(0, 0, s * 0.3))
		# the swivelling gearbox and the proprotor
		var pv := prop(k, m, "bf_rotor" + ("L" if s < 0.0 else ""), Vector3(nx, 4.6, -3.25), 8.1, 3, 0.95, 0.85, Vector3(tilt, 0, 0), false, Color(0.24, 0.25, 0.26))
		k._cyl(pv, 0.92, 0.95, 1.1, Vector3(0, 0, 0.45), Vector3(PI / 2, 0, 0), A, c, 20)
	nav_lights(k, m, Vector3(10.82, 4.6, -0.5), 0.1)
	# the H tail: stabiliser with elevators, fins with rudders at its tips
	surf(k, m, "bf_stab", [[Vector3(0.0, 4.3, 9.5), 2.5, 0.25], [Vector3(4.15, 4.3, 10.0), 2.1, 0.18]], A, c, [0.7])
	surf(k, m, "bf_fin", [[Vector3(4.15, 3.1, 9.6), 2.2, 0.2], [Vector3(4.15, 4.3, 9.65), 2.55, 0.24], [Vector3(4.15, 6.9, 10.5), 1.8, 0.16]], A, c, [0.0, 0.68])
	# the refuelling probe, the sensor turret under the nose, antennas
	rod(k, m, Vector3(1.1, 2.75, -9.4), Vector3(1.0, 2.95, -13.3), 0.08, A, c, 10, 0.05)
	k._cyl(m, 0.1, 0.06, 0.25, Vector3(1.0, 2.95, -13.4), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
	k._cyl(m, 0.18, 0.2, 0.3, Vector3(0, 0.95, -10.2), Vector3.ZERO, A, c)
	k._add(m, Res.sphere(0.34, 16), "paint", Color(0.5, 0.51, 0.5), Vector3(0, 0.7, -10.2))
	k._add(m, Res.sphere(0.16, 10), "glass", null, Vector3(0, 0.66, -10.48), Vector3.ZERO, Vector3(1, 1, 0.5))
	antenna(k, m, Vector3(0, 4.25, -6.0), 0.4)
	antenna(k, m, Vector3(0, 0.4, -2.0), 0.3, true)
	antenna(k, m, Vector3(0, 4.27, 4.0), 0.3)
	k.gun_tip = k._tip(m, Vector3(0, 0.62, -10.55))
	if armed:
		# the 20 mm Gatling in a blister behind the cockpit
		var gx := -1.6
		body(k, m, "bf_blister", [[-6.75, 2.0, 0.0, 0.0, 0.0, 2, 2, gx], [-6.55, 2.0, 0.22, 0.26, 0.26, 2, 2, gx], [-5.75, 2.0, 0.26, 0.3, 0.3, 2, 2, gx], [-5.35, 2.0, 0.08, 0.1, 0.1, 2, 2, gx]], A, c, 14)
		for i in 6:
			var a := TAU * float(i) / 6.0
			var o := Vector3(0, cos(a) * 0.07, sin(a) * 0.07)
			rod(k, m, Vector3(-1.75, 1.98, -6.15) + o, Vector3(-2.85, 1.9, -6.15) + o, 0.024, "gunmetal_w", null, 6, -1.0, false)
		k._cyl(m, 0.11, 0.11, 0.06, Vector3(-2.55, 1.92, -6.15), Vector3(0, 0, PI / 2 - 0.07), "gunmetal_w", null, 10, false)
		k.mg_tip = k._tip(m, Vector3(-2.9, 1.9, -6.15))
		# the 40 mm Bofors: a mount on the side, the long barrel and flash hider
		k._box(m, Vector3(0.24, 0.8, 0.8), Vector3(-1.58, 2.55, 2.6), A, c.darkened(0.15))
		rod(k, m, Vector3(-1.6, 2.55, 2.6), Vector3(-2.2, 2.54, 2.6), 0.17, "gunmetal_w", null, 12)
		rod(k, m, Vector3(-1.6, 2.55, 2.6), Vector3(-3.7, 2.5, 2.6), 0.085, "gunmetal_w", null, 10)
		rod(k, m, Vector3(-3.5, 2.5, 2.6), Vector3(-4.0, 2.49, 2.6), 0.12, "gunmetal_w", null, 10, 0.08)
		# the 105 mm howitzer: a mantlet plate, the recoil sleeve, the barrel and muzzle brake
		k._box(m, Vector3(0.26, 1.2, 1.4), Vector3(-1.58, 2.55, 5.4), A, c.darkened(0.15))
		rod(k, m, Vector3(-1.6, 2.55, 5.4), Vector3(-4.4, 2.48, 5.4), 0.15, "gunmetal_w", null, 12)
		rod(k, m, Vector3(-1.6, 2.55, 5.4), Vector3(-2.6, 2.53, 5.4), 0.26, "gunmetal_w", null, 12)
		k._box(m, Vector3(0.5, 0.38, 0.42), Vector3(-4.55, 2.47, 5.4), "gunmetal_w")
		k.gun_tip = k._tip(m, Vector3(-4.82, 2.47, 5.4))
		# a second sensor turret on the gun side
		k._add(m, Res.sphere(0.3, 14), "paint", Color(0.5, 0.51, 0.5), Vector3(-1.25, 0.95, -7.6))
		k._add(m, Res.sphere(0.13, 10), "glass", null, Vector3(-1.5, 0.9, -7.6), Vector3.ZERO, Vector3(0.5, 1, 1))
	wing_marks(k, m, team, ws, 6.5, 1.1)
	for s in [-1.0, 1.0]:
		k._team_mark(m, team, Vector3(s * 1.6, 2.6, 6.0), Vector3(0.02, 0.8, 0.8))


# --- Y-32 Xi'an ---------------------------------------------------------------------

## A ducted lift fan set in a wing: the duct's lip ring on the upper surface,
## a k.rotors fan (spinning about y, with "Blades" and a hidden "Blur" disc)
## over a dark well, louvres on the underside.
static func lift_fan(k: VehicleModels, p: Node3D, key: String, pos: Vector3, r: float, depth: float, col: Color) -> void:
	k._add(p, Res.torus(r * 0.98, r * 1.12), "aircraft", col.darkened(0.2), pos + Vector3(0, 0.01, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	k._cyl(p, r, r, depth, pos + Vector3(0, -depth * 0.5, 0), Vector3.ZERO, "plain_dark", null, 24, false)
	k._cyl(p, r * 0.98, r * 0.98, 0.02, pos + Vector3(0, -depth - 0.005, 0), Vector3.ZERO, "plain_dark", null, 24, false)
	for i in 6:
		k._box(p, Vector3(r * 1.9 * sqrt(1.0 - pow((i - 2.5) / 3.0, 2.0)), 0.03, 0.1), pos + Vector3(0, -depth - 0.03, (i - 2.5) * r * 0.32), "gunmetal_w", col.darkened(0.3), Vector3(0.5, 0, 0), false)
	var rt := k._pivot(p, pos + Vector3(0, -0.06, 0))
	k._add(rt, Res.sphere(r * 0.22, 12), "gunmetal_w", null, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.5, 1))
	var bl := k._pivot(rt, Vector3.ZERO)
	bl.name = "Blades"
	for i in 12:
		var a := TAU * float(i) / 12.0
		k._box(bl, Vector3(0.012, 0.05, r * 0.76), Vector3(sin(a) * r * 0.58, -0.02, cos(a) * r * 0.58), "gunmetal_w", null, Vector3(0, a, 0.6), false)
	if not k.burnt:
		var disc := MeshInstance3D.new()
		disc.name = "Blur"
		var pm := PlaneMesh.new()
		pm.size = Vector2(r, r) * 2.0
		disc.mesh = pm
		disc.material_override = VehicleModels._blur_mat()
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.position = Vector3(0, 0.02, 0)
		disc.visible = false
		rt.add_child(disc)
	k.rotors.append(rt)


## Y-32 Xi'an: CSAT's VTOL gunship, a Quinjet-like airframe. A stepped
## Mi-24-style cockpit (the gunner low in front, the pilot above and behind,
## each under his own framed bubble), a chin turret with a twin 23 mm, a deep
## troop cabin with side doors and a rear ramp, wings with big ducted lift
## fans, stub wings with rocket pods and missile racks below them, two
## turbofans with vectoring nozzles high on the back between twin canted
## tails. CSAT.
static func _xian(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := CSAT
	var c2 := CSAT.darkened(0.16)
	var A := "aircraft"
	var st := [
		[-9.0, 1.55, 0.0, 0.0, 0.0],
		[-8.75, 1.56, 0.2, 0.2, 0.18],
		[-8.1, 1.6, 0.46, 0.44, 0.4, 2.1, 2.2],
		[-7.1, 1.66, 0.68, 0.62, 0.58, 2.3, 2.4],
		[-5.9, 1.78, 0.86, 0.82, 0.74, 2.5, 2.6],
		[-4.6, 1.92, 1.05, 1.05, 0.9, 2.6, 2.8],
		[-3.0, 2.0, 1.25, 1.22, 1.18, 2.8, 3.0],
		[1.0, 2.0, 1.3, 1.25, 1.22, 2.8, 3.0],
		[4.0, 2.15, 1.18, 1.12, 1.0, 2.7, 2.8],
		[6.5, 2.5, 0.88, 0.88, 0.6, 2.5, 2.5],
		[8.4, 2.85, 0.45, 0.5, 0.3],
		[9.0, 2.9, 0.14, 0.2, 0.1],
	]
	body(k, m, "xi_fus", st, A, c, 22)
	stripe(k, m, "xi_nose", st, -9.0, -7.9, -PI, PI, A, c2, 0.004, 20)
	# the stepped cockpit: the gunner's bubble low in front, the pilot's above
	var g := [[-7.75, 2.0, 0.3, 0.05, 0.05, 2.6], [-7.3, 2.02, 0.48, 0.32, 0.05, 2.6], [-6.6, 2.06, 0.55, 0.48, 0.05, 2.6], [-6.0, 2.1, 0.52, 0.42, 0.05, 2.6], [-5.6, 2.12, 0.35, 0.2, 0.05, 2.6]]
	var p := [[-5.6, 2.62, 0.35, 0.05, 0.05, 2.6], [-5.1, 2.64, 0.55, 0.36, 0.05, 2.6], [-4.4, 2.68, 0.6, 0.52, 0.05, 2.6], [-3.7, 2.72, 0.56, 0.45, 0.05, 2.6], [-3.2, 2.74, 0.36, 0.22, 0.05, 2.6]]
	for cp in [[g, "g", -7.25, -6.0], [p, "p", -5.05, -3.75]]:
		var cs: Array = cp[0]
		body(k, m, "xi_can" + String(cp[1]), cs, "glass", null, 18, 30.0)
		band(k, m, "xi_bow0" + String(cp[1]), cs, float(cp[2]), 0.08, 0.02, A, c2, 18)
		band(k, m, "xi_bow1" + String(cp[1]), cs, float(cp[3]), 0.08, 0.02, A, c2, 18)
		stripe(k, m, "xi_rail" + String(cp[1]), cs, float(cs[0][0]), float(cs[cs.size() - 1][0]), PI / 2 - 0.04, PI / 2 + 0.04, A, c2, 0.02, 3)
	# the chin turret: a twin 23 mm that traverses
	k.turret = k._pivot(m, Vector3(0, 1.05, -7.2))
	k._add(k.turret, Res.sphere(0.36, 14), A, c2, Vector3(0, -0.05, 0), Vector3.ZERO, Vector3(1, 0.75, 1))
	k._box(k.turret, Vector3(0.36, 0.3, 0.5), Vector3(0, -0.15, -0.3), "gunmetal_w")
	for x in [-0.09, 0.09]:
		rod(k, k.turret, Vector3(x, -0.15, -0.5), Vector3(x, -0.15, -1.75), 0.04, "gunmetal_w", null, 8, -1.0, false)
		k._cyl(k.turret, 0.055, 0.055, 0.14, Vector3(x, -0.15, -1.7), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
	k.mg_tip = k._tip(k.turret, Vector3(0, -0.15, -1.8))
	# troop doors on both sides, the rear ramp
	for s in [-1.0, 1.0]:
		for z in [-2.2, -0.2]:
			k._box(m, Vector3(0.02, 1.7, 0.03), Vector3(s * 1.3, 1.95, z), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.02, 0.03, 2.0), Vector3(s * 1.29, 2.8, -1.2), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.03, 0.36, 0.5), Vector3(s * 1.3, 2.5, -1.2), "glass", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.03, 0.36, 0.5), Vector3(s * 1.29, 2.5, 1.8), "glass", null, Vector3.ZERO, false)
	for a in [-PI / 2 - 0.75, -PI / 2 + 0.75]:
		stripe(k, m, "xi_ramp%.2f" % a, st, 4.2, 7.6, a - 0.02, a + 0.02, "gunmetal_w", null, 0.01, 3)
	stripe(k, m, "xi_rampx", st, 4.18, 4.26, -PI / 2 - 0.75, -PI / 2 + 0.75, "gunmetal_w", null, 0.01, 10)
	# the wings, a lift fan in each, ailerons outboard
	var ws := [[Vector3(1.2, 2.95, -1.6), 5.0, 0.55], [Vector3(5.6, 3.0, -0.2), 3.4, 0.42], [Vector3(8.0, 3.05, 0.5), 2.6, 0.26]]
	surf(k, m, "xi_wing", ws, A, c, [0.0, 0.74])
	for s in [-1.0, 1.0]:
		var w := surf_at(ws, 4.0)
		var le: Vector3 = w[0]
		var fz := le.z + float(w[1]) * 0.45
		lift_fan(k, m, "xi_fan" + ("L" if s < 0.0 else ""), Vector3(s * 4.0, le.y + float(w[2]) * 0.47, fz), 1.2, float(w[2]) * 0.9, c)
		# wingtip pod with the lights
		body(k, m, "xi_tip" + ("L" if s < 0.0 else ""), [[0.2, 3.05, 0.0, 0.0, 0.0, 2, 2, s * 8.05], [0.6, 3.05, 0.14, 0.14, 0.14, 2, 2, s * 8.05], [2.9, 3.05, 0.14, 0.14, 0.14, 2, 2, s * 8.05], [3.4, 3.05, 0.04, 0.04, 0.04, 2, 2, s * 8.05]], A, c2, 10)
	nav_lights(k, m, Vector3(8.06, 3.05, 0.25), 0.07)
	# stub wings below, with their stores
	var sw := [[Vector3(1.2, 1.55, -1.9), 2.0, 0.22], [Vector3(3.4, 1.5, -1.6), 1.5, 0.15]]
	surf(k, m, "xi_stub", sw, A, c, [])
	for sd in [-1.0, 1.0]:
		for x in [2.1, 3.05]:
			var w := surf_at(sw, x)
			var le: Vector3 = w[0]
			var at := Vector3(sd * x, le.y - float(w[2]) * 0.3, le.z + float(w[1]) * 0.45)
			if x < 2.5:
				rocket_pod(k, m, pylon(k, m, at, 1.0, 0.16, c, 0.26), 2.4, 0.26, Color(0.4, 0.4, 0.36))
			else:
				var rc := pylon(k, m, at, 0.9, 0.12, c, 0.0)
				k._box(m, Vector3(0.42, 0.08, 1.4), rc + Vector3(0, -0.03, 0.1), "gunmetal_w")
				for o in [Vector2(-0.12, -0.14), Vector2(0.12, -0.14), Vector2(-0.12, -0.38), Vector2(0.12, -0.38)]:
					k._cyl(m, 0.09, 0.09, 1.7, rc + Vector3(o.x, o.y, 0.05), Vector3(PI / 2, 0, 0), "paint", Color(0.36, 0.38, 0.3), 10)
	# twin turbofans high on the back, vectoring nozzles, a fairing between them
	body(k, m, "xi_dorsal", [[0.6, 3.25, 0.0, 0.0, 0.0], [1.4, 3.3, 0.55, 0.3, 0.1], [5.5, 3.3, 0.6, 0.28, 0.1], [7.2, 3.15, 0.2, 0.1, 0.1]], A, c, 16)
	for s in [-1.0, 1.0]:
		var nx: float = s * 0.95
		var nst := [[1.2, 3.72, 0.55, 0.55, 0.55, 2.2, 2.2, nx, 0.3], [1.6, 3.72, 0.62, 0.62, 0.6, 2.2, 2.2, nx], [4.0, 3.72, 0.62, 0.62, 0.6, 2.3, 2.3, nx],
			[6.2, 3.7, 0.5, 0.48, 0.48, 2.6, 2.6, nx], [6.7, 3.68, 0.45, 0.42, 0.42, 3.0, 3.0, nx]]
		body(k, m, "xi_nac" + ("L" if s < 0.0 else ""), nst, A, c2, 20)
		var q: Array = _sp(nst[0]) if s > 0.0 else _mx(nst[0])
		mouth(k, m, "xi_fan" + ("L" if s < 0.0 else "") + "m", q, 0.82, -1.0, "metal_dark")
		k._cyl(m, 0.16, 0.0, 0.3, Vector3(nx, 3.72, 1.25), Vector3(-PI / 2, 0, 0), "gunmetal_w", null, 10, false)
		var zst := [[6.65, 3.68, 0.44, 0.4, 0.4, 3.2, 3.2, nx], [7.2, 3.6, 0.42, 0.34, 0.34, 3.2, 3.2, nx], [7.55, 3.52, 0.4, 0.28, 0.28, 3.2, 3.2, nx]]
		body(k, m, "xi_noz" + ("L" if s < 0.0 else ""), zst, "gunmetal_w", c.darkened(0.45), 16, 30.0)
		mouth(k, m, "xi_pipe" + ("L" if s < 0.0 else ""), zst[2], 0.8, 1.0)
	glow(k, m, [Vector3(-0.95, 3.52, 7.85), Vector3(0.95, 3.52, 7.85)], 1.1)
	# twin tails canted outboard of the engines, rudders
	surf(k, m, "xi_fin", [[Vector3(1.5, 3.5, 4.6), 3.4, 0.24], [Vector3(2.29, 5.66, 6.9), 1.6, 0.12]], A, c2, [0.7])
	# probes, antennas, the sensor under the nose
	rod(k, m, Vector3(0.5, 1.7, -8.4), Vector3(0.5, 1.7, -9.3), 0.03, "gunmetal_w", null, 6, 0.012)
	antenna(k, m, Vector3(0, 3.25, -2.0), 0.3)
	antenna(k, m, Vector3(0, 0.8, 0.5), 0.26, true)
	k._add(m, Res.sphere(0.2, 12), "glass", null, Vector3(0, 1.62, -8.6), Vector3.ZERO, Vector3(1, 0.8, 1))
	k.gun_tip = k.mg_tip
	wing_marks(k, m, team, ws, 6.7, 0.8)
	for s in [-1.0, 1.0]:
		k._team_mark(m, team, Vector3(s * 1.28, 2.2, 2.9), Vector3(0.02, 0.6, 0.6))
