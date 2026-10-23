class_name VmHeli
extends RefCounted
## Procedural models: helicopters and rotary drones.
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys must be unique per shape).
##
## Fuselages are Hulls: convex sections lofted along Z, with windows, doors,
## seams and livery laid on them as patches that follow the facets. Rotors,
## tail rotors, fantails, skids and the weapons are shared helpers below.

## Every model key this file builds (the Field Manual's model pages list them).
const KEYS: Array[String] = ["pawnee", "hummingbird", "m900", "ghosthawk", "ghosthawk_stub", "huron", "blackfoot",
	"mohawk", "hellcat", "kajman", "orca", "orca_armed", "taru", "falcon", "darter", "utility_drone", "demining_drone"]

const NATO_BLACK := Color(0.2, 0.21, 0.22)
const NATO_GREY := Color(0.42, 0.45, 0.48)
const CSAT_SAND := Color(0.47, 0.44, 0.38)
const AAF_GREEN := Color(0.36, 0.39, 0.28)


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"pawnee":
			_little_bird(k, team, seed, 1)
		"hummingbird":
			_little_bird(k, team, seed, 0)
		"m900":
			_little_bird(k, team, seed, 2)
		"ghosthawk":
			_ghost_hawk(k, team, false)
		"ghosthawk_stub":
			_ghost_hawk(k, team, true)
		"huron":
			_huron(k, team)
		"blackfoot":
			_blackfoot(k, team)
		"mohawk":
			_mohawk(k, team)
		"hellcat":
			_hellcat(k, team)
		"kajman":
			_kajman(k, team)
		"orca":
			_orca(k, team, false)
		"orca_armed":
			_orca(k, team, true)
		"taru":
			_taru(k, team)
		"falcon":
			_falcon(k, team)
		"darter":
			_darter(k, team)
		"utility_drone":
			_hexa(k, team, false)
		"demining_drone":
			_hexa(k, team, true)
		_:
			return false
	return true


# --- hulls -----------------------------------------------------------------------

## A lofted fuselage. Stations [z, cy, rx, ry_top, ry_bottom, top_scale,
## bottom_scale] run front to back; each is a convex superellipse section of n
## points round (0, cy): p = 2 an ellipse, larger boxier; top/bottom_scale
## narrow the roof or the belly. n = 6 with phase 0 gives the chined, faceted
## section of a stealth airframe. Vertex t = 0 is the right flank at cy,
## t = n / 4 the roof, n / 2 the left flank, 3n / 4 the belly; fractional t
## lies on the facet between two vertices.
class Hull:
	extends RefCounted
	var st: Array
	var n := 12
	var p := 2.0
	var ph := 0.0

	func _init(stations: Array, pts := 12, power := 2.0, phase := 0.0) -> void:
		st = stations
		n = pts
		p = power
		ph = phase

	static func _full(s: Array) -> Array:
		var o := s.duplicate()
		while o.size() < 7:
			o.append(1.0)
		return o

	## The section's parameters at z (linear between stations).
	func at(z: float) -> Array:
		if z <= float(st[0][0]):
			return _full(st[0])
		for i in st.size() - 1:
			var b: Array = st[i + 1]
			if z <= float(b[0]):
				var fa := _full(st[i])
				var fb := _full(b)
				var f := (z - float(fa[0])) / maxf(float(fb[0]) - float(fa[0]), 1e-5)
				var o := []
				for j in 7:
					o.append(lerpf(float(fa[j]), float(fb[j]), f))
				return o
		return _full(st[st.size() - 1])

	func vert(prm: Array, i: int) -> Vector2:
		var a := ph + TAU * float(posmod(i, n)) / float(n)
		var c := cos(a)
		var s := sin(a)
		var x := signf(c) * pow(absf(c), 2.0 / p) * float(prm[2])
		var y := signf(s) * pow(absf(s), 2.0 / p)
		x *= 1.0 + (float(prm[5]) - 1.0) * maxf(s, 0.0) + (float(prm[6]) - 1.0) * maxf(-s, 0.0)
		return Vector2(x, float(prm[1]) + y * (float(prm[3]) if s > 0.0 else float(prm[4])))

	func _enorm(prm: Array, i: int) -> Vector2:
		var a := vert(prm, i)
		var b := vert(prm, i + 1)
		var d := b - a
		var nn := Vector2(d.y, -d.x).normalized()
		if nn.dot((a + b) * 0.5 - Vector2(0, float(prm[1]))) < 0.0:
			nn = -nn
		return nn

	## The surface point at (z, t), pushed out along the facet normal by grow.
	func pt(z: float, t: float, grow := 0.0) -> Vector3:
		var prm := at(z)
		var i := floori(t)
		var f := t - i
		var v := vert(prm, i).lerp(vert(prm, i + 1), f)
		var nn: Vector2
		if f < 0.002:
			nn = (_enorm(prm, i - 1) + _enorm(prm, i)).normalized()
		elif f > 0.998:
			nn = (_enorm(prm, i) + _enorm(prm, i + 1)).normalized()
		else:
			nn = _enorm(prm, i)
		v += nn * grow
		return Vector3(v.x, v.y, z)

	func ring(z: float, grow := 0.0) -> PackedVector3Array:
		var r := PackedVector3Array()
		for i in n:
			r.append(pt(z, float(i), grow))
		return r

	func mesh(key: String, grow := 0.0) -> ArrayMesh:
		var rings := []
		for s in st:
			rings.append(ring(float(s[0]), grow))
		return VehicleModels.solid(rings, key)

	## A panel laid on the hull between z0..z1 and t0..t1, standing grow
	## proud and depth deep (sx = -1 mirrors it to the left).
	func patch(key: String, z0: float, z1: float, t0: float, t1: float, grow := 0.012, depth := 0.03, sx := 1.0) -> ArrayMesh:
		var zs := [z0]
		for s in st:
			if float(s[0]) > z0 + 0.01 and float(s[0]) < z1 - 0.01:
				zs.append(float(s[0]))
		zs.append(z1)
		var ts := [t0]
		for i in range(ceili(t0 + 0.01), floori(t1 - 0.01) + 1):
			ts.append(float(i))
		ts.append(t1)
		var rings := []
		for z in zs:
			var r := PackedVector3Array()
			for t in ts:
				var q := pt(z, t, grow)
				r.append(Vector3(q.x * sx, q.y, q.z))
			for j in range(ts.size() - 1, -1, -1):
				var q2 := pt(z, ts[j], -depth)
				r.append(Vector3(q2.x * sx, q2.y, q2.z))
			rings.append(r)
		return VehicleModels.solid(rings, key)


## The hull as a solid.
static func _hull(k: VehicleModels, p: Node3D, h: Hull, key: String, mat: String, col = null, grow := 0.0) -> Variant:
	return k._add(p, h.mesh(key, grow), mat, col, Vector3.ZERO)


## A patch on the hull, on the right (sx 1), the left (-1) or both (0).
static func _patch(k: VehicleModels, p: Node3D, h: Hull, key: String, z0: float, z1: float, t0: float, t1: float, mat: String, col = null, grow := 0.012, depth := 0.03, sx := 0.0) -> void:
	for s in ([1.0, -1.0] if sx == 0.0 else [sx]):
		var mi: Variant = k._add(p, h.patch("%s%s" % [key, "r" if s > 0.0 else "l"], z0, z1, t0, t1, grow, depth, s), mat, col, Vector3.ZERO)
		k._unshadow(mi)


## A ring of points (x, y pairs) in the XY plane at z.
static func _rz(pts: Array, z: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in range(0, pts.size(), 2):
		r.append(Vector3(pts[i], pts[i + 1], z))
	return r


## A cylinder from a to b (radius ra at a, rb at b).
static func _tube(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, ra: float, mat: String, col = null, segs := 8, rb := -1.0, shadow := true) -> Variant:
	var d := b - a
	var l := d.length()
	if l < 1e-4:
		return null
	var dn := d / l
	var q := Quaternion(Vector3.UP, dn) if dn.dot(Vector3.UP) > -0.9999 else Quaternion(Vector3.RIGHT, PI)
	return k._cyl(p, rb if rb >= 0.0 else ra, ra, l, (a + b) * 0.5, Basis(q).get_euler(), mat, col, segs, shadow)


## A tube along a polyline.
static func _path(k: VehicleModels, p: Node3D, pts: Array, r: float, mat: String, col = null, segs := 8) -> void:
	for i in pts.size() - 1:
		_tube(k, p, pts[i], pts[i + 1], r, mat, col, segs)
		if i > 0:
			k._add(p, Res.sphere(r, segs), mat, col, pts[i])


## A box in a rotated frame (base, about origin) without a pivot node of its
## own, so it merges with the rest of its parent: blades round a hub.
static func _rbox(k: VehicleModels, p: Node3D, base: Basis, s: Vector3, lpos: Vector3, mat: String, col = null, lrot := Vector3.ZERO, shadow := true, origin := Vector3.ZERO) -> Variant:
	return k._box(p, s, origin + base * lpos, mat, col, (base * Basis.from_euler(lrot)).get_euler(), shadow)


## [material, colour] for an airframe: CSAT (team 1) gets sand (or its hex
## camouflage), everyone else the given paint.
static func _air(team: int, col: Color, hex := false) -> Array:
	if team == 1:
		return ["camo_tank_rebel", null] if hex else ["aircraft", CSAT_SAND]
	return ["aircraft", col]


# --- rotors ----------------------------------------------------------------------

## A rotor: n blades of radius r and chord c round a hub at pos. The hub and
## blade grips stay; the blades sit in a node shown when slow, a blur disc
## when fast. The main rotor fills k.rotor / k.blades / k.blur, any other is
## appended to k.rotors with "Blades" and "Blur" children. tip: 0 square,
## 1 swept, 2 a BERP paddle.
static func _rotor(k: VehicleModels, p: Node3D, pos: Vector3, nb: int, r: float, c: float, main := true, phase := 0.0, droop := 0.02, hub := 0.28, tip := 0, bcol = null) -> Node3D:
	var rp := k._pivot(p, pos)
	var bl := k._pivot(rp, Vector3.ZERO)
	k._cyl(rp, hub, hub * 1.05, 0.2, Vector3.ZERO, Vector3.ZERO, "gunmetal_w", null, maxi(nb * 2, 10))
	k._cyl(rp, hub * 0.55, hub * 0.7, 0.16, Vector3(0, 0.17, 0), Vector3.ZERO, "gunmetal_w", null, 10)
	var bc: Color = bcol if bcol is Color else Color(0.15, 0.155, 0.16)
	var grip := minf(0.2 + r * 0.06, 0.75)
	for i in nb:
		var bs := Basis.from_euler(Vector3(droop, phase + TAU * float(i) / float(nb), 0))
		# the grip and pitch horn on the hub (they stay with the blur)
		_rbox(k, rp, bs, Vector3(c * 0.75, 0.1 + c * 0.12, grip), Vector3(0, 0, hub + grip * 0.5 - 0.02), "gunmetal_w")
		_rbox(k, rp, bs, Vector3(0.05, 0.05, 0.16), Vector3(c * 0.42, -0.06, hub + 0.06), "steel", null, Vector3.ZERO, false)
		# the blade
		var r0 := hub + grip - 0.04
		var th := clampf(c * 0.16, 0.03, 0.09)
		var ln := r - r0
		match tip:
			1:
				ln -= c * 1.2
				_rbox(k, bl, bs, Vector3(c, th, ln), Vector3(0, 0, r0 + ln * 0.5), "aircraft", bc, Vector3(0, 0, 0.06))
				_rbox(k, bl, bs, Vector3(c * 0.7, th * 0.8, c * 1.3), Vector3(c * 0.2, 0, r - c * 0.62), "aircraft", bc, Vector3(0, -0.45, 0.06))
			2:
				ln -= c * 1.5
				_rbox(k, bl, bs, Vector3(c, th, ln), Vector3(0, 0, r0 + ln * 0.5), "aircraft", bc, Vector3(0, 0, 0.06))
				_rbox(k, bl, bs, Vector3(c * 1.35, th * 0.85, c * 1.2), Vector3(-c * 0.12, 0, r - c * 0.95), "aircraft", bc, Vector3(0, 0, 0.06))
				_rbox(k, bl, bs, Vector3(c * 0.7, th * 0.7, c * 0.5), Vector3(c * 0.2, 0, r - c * 0.2), "aircraft", bc, Vector3(0, -0.5, 0.06))
			_:
				_rbox(k, bl, bs, Vector3(c, th, ln), Vector3(0, 0, r0 + ln * 0.5), "aircraft", bc, Vector3(0, 0, 0.06))
		# the root fairing and the leading-edge erosion strip near the tip
		_rbox(k, bl, bs, Vector3(c * 0.9, th * 1.5, 0.3), Vector3(0, 0, r0 + 0.12), "gunmetal_w")
		_rbox(k, bl, bs, Vector3(0.03, th * 1.05, ln * 0.3), Vector3(-c * 0.5, 0, r0 + ln * 0.78), "steel", Color(0.45, 0.45, 0.43), Vector3(0, 0, 0.06), false)
	if not k.burnt:
		var blur := MeshInstance3D.new()
		var disc := PlaneMesh.new()
		disc.size = Vector2(r, r) * 2.0
		blur.mesh = disc
		blur.material_override = VehicleModels._blur_mat()
		blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blur.position = Vector3(0, 0.06, 0)
		blur.visible = false
		rp.add_child(blur)
		if main:
			k.blur = blur
		else:
			blur.name = "Blur"
	if main:
		k.rotor = rp
		k.blades = bl
	else:
		bl.name = "Blades"
		k.rotors.append(rp)
	return rp


## A tail rotor spinning about X at pos: n blades of radius r, chord c.
static func _tail_rotor(k: VehicleModels, p: Node3D, pos: Vector3, nb: int, r: float, c: float, side := 1.0, phase := 0.4) -> Node3D:
	var tr := k._pivot(p, pos)
	k._cyl(tr, 0.05, 0.08, 0.2, Vector3(side * 0.04, 0, 0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10)
	k._cyl(tr, 0.035, 0.035, 0.12, Vector3(side * 0.17, 0, 0), Vector3(0, 0, PI / 2), "steel", null, 8, false)
	for i in nb:
		var bs := Basis.from_euler(Vector3(phase + TAU * float(i) / float(nb), 0, 0))
		var o := Vector3(side * 0.07, 0, 0)
		_rbox(k, tr, bs, Vector3(0.03, r - 0.07, c), Vector3(0, (r + 0.07) * 0.5, 0), "aircraft", Color(0.15, 0.155, 0.16), Vector3(0, 0.22, 0), true, o)
		_rbox(k, tr, bs, Vector3(0.032, r * 0.22, c * 1.02), Vector3(0, r * 0.84, 0), "steel", Color(0.45, 0.45, 0.43), Vector3(0, 0.22, 0), false, o)
	k.tail_rotor = tr
	return tr


## A fin (side profile pairs z, y, convex, extruded x0..x1) with a round duct
## through it at centre c, radius rd: the fin is built as convex slices round
## the hole, so the duct is open.
static func _ducted_fin(k: VehicleModels, p: Node3D, key: String, prof: Array, c: Vector2, rd: float, x0: float, x1: float, mat: String, col = null, segs := 16) -> void:
	var poly := VehicleModels._v2(prof)
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var h0 := c + Vector2(cos(a0), sin(a0)) * rd
		var h1 := c + Vector2(cos(a1), sin(a1)) * rd
		var q0 := _ray_hit(c, Vector2(cos(a0), sin(a0)), poly)
		var q1 := _ray_hit(c, Vector2(cos(a1), sin(a1)), poly)
		var pts := [h0.x, h0.y, q0.x, q0.y]
		# the outline's corners inside this wedge, in angular order
		var mids := []
		for v in poly:
			var av := fposmod((v - c).angle() - a0, TAU)
			if av > 0.0001 and av < a1 - a0 - 0.0001:
				mids.append([av, v])
		mids.sort_custom(func(m1, m2): return m1[0] < m2[0])
		for m in mids:
			pts.append((m[1] as Vector2).x)
			pts.append((m[1] as Vector2).y)
		pts.append_array([q1.x, q1.y, h1.x, h1.y])
		k._add(p, VehicleModels.extrude_x("%s%d" % [key, i], pts, x0, x1), mat, col, Vector3.ZERO)


static func _ray_hit(c: Vector2, d: Vector2, poly: PackedVector2Array) -> Vector2:
	var best := INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := b - a
		var den := d.cross(e)
		if absf(den) < 1e-8:
			continue
		var t := (a - c).cross(e) / den
		var u := (a - c).cross(d) / den
		if t > 0.0 and u >= -1e-4 and u <= 1.0001:
			best = minf(best, t)
	return c + d * (best if best < INF else 0.0)


## A fan in a duct (spinning about X): the tail rotor of a fenestron.
static func _fan(k: VehicleModels, p: Node3D, pos: Vector3, nb: int, r: float, c: float) -> Node3D:
	var tr := k._pivot(p, pos)
	k._cyl(tr, r * 0.3, r * 0.3, 0.22, Vector3.ZERO, Vector3(0, 0, PI / 2), "gunmetal_w", null, 12)
	for i in nb:
		# unevenly spaced, as on the real fans (it spreads the noise)
		var bs := Basis.from_euler(Vector3(TAU * float(i) / float(nb) + sin(float(i) * 2.3) * 0.08, 0, 0))
		_rbox(k, tr, bs, Vector3(0.02, r * 0.68, c), Vector3(0, r * 0.62, 0), "aircraft", Color(0.17, 0.17, 0.18), Vector3(0, 0.35, 0))
	k.tail_rotor = tr
	return tr


# --- landing gear ----------------------------------------------------------------

## Skids: tubes at ±x from z0 to z1 (upturned at the front), on cross tubes at
## the zs that rise to the belly (half width bx at height by).
static func _skids(k: VehicleModels, p: Node3D, x: float, z0: float, z1: float, cz: Array, bx: float, by: float, r := 0.045, mat := "gunmetal_w", col = null) -> void:
	for s in [-1.0, 1.0]:
		var y := r + 0.01
		_tube(k, p, Vector3(s * x, y, z0), Vector3(s * x, y, z1), r, mat, col, 8)
		_tube(k, p, Vector3(s * x, y, z0), Vector3(s * x, y + 0.24, z0 - 0.26), r, mat, col, 8)
		k._add(p, Res.sphere(r, 8), mat, col, Vector3(s * x, y, z0))
		k._add(p, Res.sphere(r, 8), mat, col, Vector3(s * x, y + 0.24, z0 - 0.26))
		k._add(p, Res.sphere(r, 8), mat, col, Vector3(s * x, y, z1))
		# wear shoes under the skid
		for z in cz:
			k._box(p, Vector3(r * 1.6, 0.025, 0.35), Vector3(s * x, 0.012, z), "steel", null, Vector3.ZERO, false)
	for z in cz:
		var pts := [Vector3(-x, r + 0.01, z), Vector3(-x * 0.9, by * 0.55, z), Vector3(-bx, by, z),
			Vector3(bx, by, z), Vector3(x * 0.9, by * 0.55, z), Vector3(x, r + 0.01, z)]
		_path(k, p, pts, r * 1.1, mat, col, 8)


## A wheel on an oleo leg from the airframe (top) down to the axle.
static func _gear(k: VehicleModels, p: Node3D, top: Vector3, axle: Vector3, r: float, w: float, twin := false) -> void:
	_tube(k, p, top, axle + Vector3(0, r * 0.3, 0), 0.06, "gunmetal_w", null, 8)
	_tube(k, p, top + (axle - top) * 0.45, axle + Vector3(0, r * 0.3, 0), 0.075, "steel", null, 8)
	if twin:
		for s in [-1.0, 1.0]:
			k._wheel(p, axle + Vector3(s * (w * 0.5 + 0.03), 0, 0), r, w)
		_tube(k, p, axle - Vector3(w + 0.06, 0, 0), axle + Vector3(w + 0.06, 0, 0), 0.04, "gunmetal_w", null, 6)
	else:
		var sx := signf(axle.x - top.x) if absf(axle.x - top.x) > 0.02 else 0.0
		k._wheel(p, axle, r, w)
		if sx != 0.0:
			_tube(k, p, axle, axle - Vector3(sx * (w * 0.5 + 0.08), 0, 0), 0.045, "gunmetal_w", null, 6)


# --- weapons ---------------------------------------------------------------------

## An M134 minigun pointing -Z with its breech at pos; returns the muzzle.
static func _minigun(k: VehicleModels, p: Node3D, pos: Vector3, ln := 0.75) -> Vector3:
	k._box(p, Vector3(0.15, 0.17, 0.34), pos + Vector3(0, 0, 0.1), "gunmetal_w")
	k._cyl(p, 0.04, 0.04, 0.16, pos + Vector3(0.09, 0.07, 0.12), Vector3(PI / 2, 0, 0), "metal_dark", null, 8, false)
	k._cyl(p, 0.075, 0.075, 0.08, pos + Vector3(0, 0, -0.1), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	for i in 6:
		var a := TAU * float(i) / 6.0
		k._cyl(p, 0.013, 0.013, ln, pos + Vector3(cos(a) * 0.042, sin(a) * 0.042, -0.1 - ln * 0.5), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 5, false)
	k._cyl(p, 0.062, 0.062, 0.04, pos + Vector3(0, 0, -0.1 - ln * 0.62), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
	k._cyl(p, 0.058, 0.058, 0.03, pos + Vector3(0, 0, -0.1 - ln + 0.03), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
	return pos + Vector3(0, 0, -0.12 - ln)


## A rocket pod along Z centred at pos: tubes in its face (7 or 19).
static func _rocket_pod(k: VehicleModels, p: Node3D, pos: Vector3, r: float, ln: float, mat := "paint", col = null, tubes := 7) -> void:
	var pc: Color = col if col is Color else Color(0.3, 0.32, 0.27)
	k._cyl(p, r, r, ln * 0.86, pos + Vector3(0, 0, -ln * 0.05), Vector3(PI / 2, 0, 0), mat, pc, 16)
	k._cyl(p, r * 0.97, r * 0.6, ln * 0.14, pos + Vector3(0, 0, ln * 0.43), Vector3(PI / 2, 0, 0), mat, pc, 16)
	for z in [-ln * 0.4, ln * 0.3]:
		k._cyl(p, r * 1.03, r * 1.03, 0.05, pos + Vector3(0, 0, z), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 16, false)
	var fz := pos.z - ln * 0.48
	k._cyl(p, r * 0.96, r * 0.96, 0.02, Vector3(pos.x, pos.y, fz - 0.005), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 16, false)
	var holes := [Vector2.ZERO]
	var rings := [[6, 0.55]] if tubes <= 7 else [[6, 0.36], [12, 0.72]]
	for rg in rings:
		for i in int(rg[0]):
			var a := TAU * float(i) / float(rg[0])
			holes.append(Vector2(cos(a), sin(a)) * r * float(rg[1]))
	var hr := r * (0.24 if tubes <= 7 else 0.15)
	for h in holes:
		k._cyl(p, hr, hr, 0.03, Vector3(pos.x + h.x, pos.y + h.y, fz - 0.012), Vector3(PI / 2, 0, 0), "rubber", null, 8, false)
	# the sway-brace lugs on top
	k._box(p, Vector3(0.06, 0.06, ln * 0.4), pos + Vector3(0, r + 0.02, 0), "gunmetal_w", null, Vector3.ZERO, false)


## A missile along Z (nose at -Z) centred at pos.
static func _missile(k: VehicleModels, p: Node3D, pos: Vector3, r: float, ln: float, col := Color(0.32, 0.34, 0.29), fins := true) -> void:
	k._cyl(p, r, r, ln * 0.82, pos + Vector3(0, 0, ln * 0.06), Vector3(PI / 2, 0, 0), "paint", col, 10)
	k._cyl(p, r * 0.25, r, ln * 0.14, pos + Vector3(0, 0, -ln * 0.41), Vector3(PI / 2, 0, 0), "paint", col.lightened(0.15), 10)
	if fins:
		for i in 2:
			k._box(p, Vector3(r * 3.4 if i == 0 else 0.012, r * 3.4 if i == 1 else 0.012, ln * 0.12), pos + Vector3(0, 0, ln * 0.4), "paint", col, Vector3(0, 0, PI / 4), false)


## A four-round Hellfire launcher hanging from pos (2 x 2 missiles on rails).
static func _hellfires(k: VehicleModels, p: Node3D, pos: Vector3, rounds := 4) -> void:
	k._box(p, Vector3(0.12, 0.2, 1.3), pos + Vector3(0, -0.1, 0), "gunmetal_w")
	k._box(p, Vector3(0.62, 0.06, 1.2), pos + Vector3(0, -0.22, 0.05), "gunmetal_w")
	for i in rounds:
		var sx := -1.0 if i % 2 == 0 else 1.0
		var row := 0.0 if i < 2 else 1.0
		_missile(k, p, pos + Vector3(sx * 0.21, -0.36 - row * 0.3, 0.0), 0.085, 1.62, Color(0.3, 0.33, 0.26))


# --- MD 500 / Little Bird -----------------------------------------------------------

## MD 500 "Little Bird": the glazed egg of a cabin on tall skids, the thin
## boom with its T-tail and endplates, a five-blade rotor on a short mast, the
## two-blade tail rotor on the left. v 0: MH-6 (benches outside for four),
## 1: AH-6 (two miniguns and two rocket pods on a cross-bar), 2: a civilian
## MD 500 with its doors on.
static func _little_bird(k: VehicleModels, team: int, seed: int, v: int) -> void:
	var m := k.root
	var pc := _air(team, NATO_BLACK)
	var mat: String = pc[0]
	var col = pc[1]
	if v == 2:
		mat = "car_paint"
		col = [Color(0.2, 0.3, 0.42), Color(0.75, 0.72, 0.65), Color(0.34, 0.17, 0.14), Color(0.55, 0.52, 0.45)][seed % 4]
	var dark := Color(0.07, 0.07, 0.07)
	var h := Hull.new([
		[-2.2, 1.1, 0.04, 0.04, 0.04],
		[-2.08, 1.12, 0.36, 0.36, 0.33],
		[-1.85, 1.17, 0.56, 0.58, 0.52],
		[-1.45, 1.22, 0.67, 0.7, 0.64],
		[-0.95, 1.26, 0.7, 0.74, 0.7],
		[-0.25, 1.27, 0.69, 0.73, 0.7],
		[0.35, 1.32, 0.63, 0.67, 0.64],
		[0.8, 1.42, 0.47, 0.56, 0.46],
		[1.15, 1.55, 0.28, 0.36, 0.27],
		[1.38, 1.62, 0.17, 0.22, 0.16],
	], 16, 2.2)
	_hull(k, m, h, "heli_lb_body", mat, col)
	# the bubble: windscreen and chin windows, one framed sheet
	_patch(k, m, h, "heli_lb_wind", -2.2, -0.97, -1.55, 9.55, "glass", null, 0.012, 0.05, 1.0)
	_patch(k, m, h, "heli_lb_mull", -2.15, -0.97, 3.82, 4.18, mat, col, 0.024, 0.02, 1.0)
	_patch(k, m, h, "heli_lb_sill", -2.12, -0.97, -0.62, -0.3, mat, col, 0.024, 0.02)
	_patch(k, m, h, "heli_lb_chin", -2.16, -1.5, 11.8, 12.2, mat, col, 0.024, 0.02, 1.0)
	_patch(k, m, h, "heli_lb_hoop", -1.06, -0.93, -2.6, 10.6, mat, col, 0.026, 0.03, 1.0)
	# doors: the pilots' (off on the military birds), the cabin's behind
	if v == 2:
		_patch(k, m, h, "heli_lb_dwin", -0.88, -0.25, -0.1, 2.55, "glass", null, 0.012)
		_patch(k, m, h, "heli_lb_rwin", -0.06, 0.48, 0.2, 2.3, "glass", null, 0.012)
		for z in [-0.2, 0.55]:
			_patch(k, m, h, "heli_lb_seam%d" % int(z * 100), z - 0.012, z + 0.012, -2.6, 2.75, "gunmetal_w", null, 0.008)
		# a cheat line down the flank
		var stripe: Color = Color(0.82, 0.8, 0.74) if (col as Color).v < 0.6 else Color(0.18, 0.24, 0.36)
		_patch(k, m, h, "heli_lb_stripe", -1.9, 1.3, -1.25, -0.95, "car_paint", stripe, 0.01)
	else:
		_patch(k, m, h, "heli_lb_door", -0.92, -0.2, -2.55, 2.7, "plain", dark, 0.006)
		if v == 0:
			_patch(k, m, h, "heli_lb_cabin", -0.12, 0.56, -2.4, 2.55, "plain", dark, 0.006)
		else:
			_patch(k, m, h, "heli_lb_rwin", -0.06, 0.48, 0.2, 2.3, "glass", null, 0.012)
			_patch(k, m, h, "heli_lb_seam", 0.54, 0.57, -2.4, 2.6, "gunmetal_w", null, 0.008)
		# seat backs, seen through the openings
		for s in [-1.0, 1.0]:
			k._box(m, Vector3(0.4, 0.62, 0.08), Vector3(s * 0.33, 1.22, -0.3), "plain", Color(0.2, 0.2, 0.18))
	# roof fairing over the mast and the engine intake behind it
	k._add(m, VehicleModels.loft("heli_lb_fair", [-0.3, -0.85, 0.3, -0.85, 0.36, 0.2, 0.2, 0.78, -0.2, 0.78, -0.36, 0.2],
		[-0.17, -0.55, 0.17, -0.55, 0.24, 0.1, 0.12, 0.6, -0.12, 0.6, -0.24, 0.1], 1.9, 2.2), mat, col, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.03, 0.14, 0.32), Vector3(s * 0.27, 2.08, 0.2), "plain", dark, Vector3(0, 0, s * 0.35), false)
	k._cyl(m, 0.1, 0.12, 0.38, Vector3(0, 2.36, -0.25), Vector3.ZERO, "gunmetal_w", null, 10)
	k._cyl(m, 0.2, 0.2, 0.05, Vector3(0, 2.38, -0.25), Vector3.ZERO, "steel", null, 12)
	# exhaust under the boom root, the boom, the tail
	_tube(k, m, Vector3(0, 1.4, 0.95), Vector3(0, 1.33, 1.36), 0.1, "gunmetal_w", null, 10, 0.085)
	k._cyl(m, 0.07, 0.07, 0.02, Vector3(0, 1.32, 1.37), Vector3(PI / 2 + 0.17, 0, 0), "plain", dark, 10, false)
	_tube(k, m, Vector3(0, 1.64, 1.2), Vector3(0, 1.76, 4.8), 0.2, mat, col, 12, 0.1)
	k._add(m, Res.sphere(0.1, 10), mat, col, Vector3(0, 1.76, 4.8))
	k._add(m, VehicleModels.extrude_x("heli_lb_fin", [4.28, 1.78, 4.82, 1.78, 4.98, 2.56, 4.66, 2.57], -0.035, 0.035), mat, col, Vector3.ZERO)
	k._add(m, VehicleModels.extrude_x("heli_lb_vent", [4.42, 1.74, 4.88, 1.74, 5.0, 1.24, 4.84, 1.22], -0.03, 0.03), mat, col, Vector3.ZERO)
	_tube(k, m, Vector3(0, 1.26, 4.92), Vector3(0, 1.12, 5.12), 0.018, "gunmetal_w", null, 6)
	k._box(m, Vector3(1.58, 0.045, 0.36), Vector3(0, 2.57, 4.83), mat, col)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("heli_lb_endp", [4.68, 2.4, 4.98, 2.4, 5.04, 2.8, 4.84, 2.8], -0.018, 0.018), mat, col, Vector3(s * 0.8, 0, 0))
		k._box(m, Vector3(0.03, 0.05, 0.05), Vector3(s * 0.8, 2.56, 5.06), "plain", Color(0.6, 0.1, 0.08) if s < 0 else Color(0.1, 0.5, 0.2), Vector3.ZERO, false)
	_tail_rotor(k, m, Vector3(-0.1, 1.76, 4.88), 2, 0.7, 0.11, -1.0)
	# beacon, antennas, pitot, the landing light
	k._add(m, Res.sphere(0.04, 8), "plain", Color(0.55, 0.08, 0.06), Vector3(0, 1.93, 3.2))
	_tube(k, m, Vector3(0, 1.9, 2.3), Vector3(0, 2.18, 2.48), 0.012, "gunmetal_w", null, 4)
	_tube(k, m, Vector3(0, 0.58, 0.1), Vector3(0, 0.3, 0.42), 0.01, "gunmetal_w", null, 4)
	_tube(k, m, Vector3(0.12, 0.9, -2.05), Vector3(0.12, 0.86, -2.42), 0.012, "steel", null, 4)
	k._cyl(m, 0.07, 0.07, 0.04, Vector3(0, 0.6, -1.55), Vector3(0.3, 0, 0), "glass", null, 10, false)
	_skids(k, m, 0.98, -1.5, 1.05, [-0.85, 0.5], 0.5, 0.62, 0.042, "gunmetal_w")
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.16, 0.03, 0.3), Vector3(s * 0.98, 0.15, -0.55), "steel", null, Vector3.ZERO, false)
		_tube(k, m, Vector3(s * 0.98, 0.1, -0.55), Vector3(s * 0.98, 0.14, -0.55), 0.03, "steel", null, 6)
	if v == 0:
		# the external personnel benches, two a side
		for s in [-1.0, 1.0]:
			k._box(m, Vector3(0.46, 0.05, 1.85), Vector3(s * 1.05, 0.78, -0.12), "gunmetal_w")
			k._box(m, Vector3(0.42, 0.04, 1.75), Vector3(s * 1.05, 0.82, -0.12), "canvas", Color(0.18, 0.19, 0.16))
			k._box(m, Vector3(0.04, 0.08, 1.85), Vector3(s * 1.28, 0.8, -0.12), "gunmetal_w", null, Vector3.ZERO, false)
			for z in [-0.85, 0.5]:
				_tube(k, m, Vector3(s * 0.95, 0.38, z), Vector3(s * 1.1, 0.76, z), 0.025, "gunmetal_w", null, 6)
				_tube(k, m, Vector3(s * 0.66, 0.92, z), Vector3(s * 0.85, 0.77, z), 0.025, "gunmetal_w", null, 6)
			# a grab rail over the doorway
			_tube(k, m, Vector3(s * 0.62, 1.86, -0.8), Vector3(s * 0.6, 1.88, 0.45), 0.016, "gunmetal_w", null, 6)
	elif v == 1:
		# the weapons cross-bar under the cabin floor: minigun inboard, pod out
		_tube(k, m, Vector3(-1.62, 0.92, 0.0), Vector3(1.62, 0.92, 0.0), 0.05, "gunmetal_w", null, 10)
		k._box(m, Vector3(3.0, 0.09, 0.16), Vector3(0, 0.88, 0.0), "gunmetal_w")
		for s in [-1.0, 1.0]:
			k._box(m, Vector3(0.08, 0.16, 0.42), Vector3(s * 1.0, 0.8, -0.05), "gunmetal_w")
			k._box(m, Vector3(0.08, 0.14, 0.6), Vector3(s * 1.52, 0.82, -0.05), "gunmetal_w")
			_rocket_pod(k, m, Vector3(s * 1.52, 0.6, -0.12), 0.13, 1.6, "paint", Color(0.3, 0.32, 0.27), 7)
			# the ammunition chute from the box in the cabin
			_path(k, m, [Vector3(s * 0.62, 0.9, 0.25), Vector3(s * 0.82, 0.82, 0.3), Vector3(s * 0.98, 0.72, 0.2)], 0.04, "rubber", null, 6)
			if s > 0.0:
				k.turret = k._pivot(m, Vector3(1.0, 0.66, -0.25))
				k.mg_tip = k._tip(k.turret, _minigun(k, k.turret, Vector3.ZERO, 0.72))
			else:
				_minigun(k, m, Vector3(-1.0, 0.66, -0.25), 0.72)
	if v != 2:
		# the FLIR ball under the nose
		k._box(m, Vector3(0.1, 0.12, 0.1), Vector3(0, 0.62, -1.8), "gunmetal_w")
		k._add(m, Res.sphere(0.13, 12), "paint", Color(0.3, 0.31, 0.3), Vector3(0, 0.5, -1.8))
		k._box(m, Vector3(0.12, 0.08, 0.02), Vector3(0, 0.5, -1.93), "glass", null, Vector3.ZERO, false)
		k._team_mark(m, team, Vector3(0, 1.94, 2.6), Vector3(0.14, 0.02, 0.6))
	_rotor(k, m, Vector3(0, 2.58, -0.25), 5, 4.03, 0.17, true, 0.3, 0.012, 0.2)


# --- UH-80 Ghost Hawk ----------------------------------------------------------------

## UH-80 Ghost Hawk, the stealth Black Hawk: faceted panels over a UH-60's
## lines - the angular nose and windscreens, a tumblehome cabin with its
## sliding doors, engines under a faceted top fairing, a hub cap on the
## four-blade rotor, the canted tail rotor high on the pylon over a
## stabilator, fixed main gear and a tailwheel, miniguns in the gunners'
## windows. stub: the ESSS stub wings with four rocket pods.
static func _ghost_hawk(k: VehicleModels, team: int, stub: bool) -> void:
	var m := k.root
	var pc := _air(team, NATO_BLACK)
	var mat: String = pc[0]
	var col = pc[1]
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-7.0, 1.22, 0.1, 0.1, 0.12],
		[-6.6, 1.27, 0.62, 0.42, 0.52],
		[-5.9, 1.4, 0.95, 0.66, 0.76],
		[-5.2, 1.52, 1.07, 0.98, 0.92],
		[-4.4, 1.56, 1.13, 1.0, 1.0],
		[-2.0, 1.56, 1.18, 1.0, 1.0],
		[0.6, 1.6, 1.14, 0.95, 0.98],
		[1.9, 1.78, 0.84, 0.74, 0.6],
		[3.3, 1.98, 0.46, 0.44, 0.36],
		[6.6, 2.08, 0.3, 0.32, 0.27],
		[7.7, 2.18, 0.2, 0.26, 0.2],
	], 8, 2.6, PI / 8)
	_hull(k, m, h, "heli_gh_body", mat, col)
	# windscreens: the front panes over the nose, the cockpit door windows
	_patch(k, m, h, "heli_gh_wind", -6.5, -5.28, 0.06, 2.94, "glass", null, 0.012, 0.05, 1.0)
	_patch(k, m, h, "heli_gh_post", -6.5, -5.28, 1.45, 1.55, mat, col, 0.022, 0.02, 1.0)
	_patch(k, m, h, "heli_gh_side", -5.1, -3.82, -0.55, 0.84, "glass", null, 0.012, 0.05)
	_patch(k, m, h, "heli_gh_eyeb", -5.25, -4.55, 1.08, 1.92, "glass", null, 0.012, 0.05, 1.0)
	_patch(k, m, h, "heli_gh_eyep", -5.25, -4.55, 1.47, 1.53, mat, col, 0.02, 0.02, 1.0)
	# door seams, the gunners' windows (open), the sliding cabin doors
	for z in [-5.2, -3.7, -2.8, -0.8]:
		_patch(k, m, h, "heli_gh_seam%d" % int(z * 10), z - 0.014, z + 0.014, -1.7, 0.96, "gunmetal_w", null, 0.008)
	_patch(k, m, h, "heli_gh_seamb", -2.8, -0.8, -1.72, -1.66, "gunmetal_w", null, 0.008)
	_patch(k, m, h, "heli_gh_gunwin", -3.5, -2.92, -0.3, 0.8, "plain", dark, 0.006)
	_patch(k, m, h, "heli_gh_dwin", -2.45, -1.2, -0.05, 0.76, "glass", null, 0.012)
	_patch(k, m, h, "heli_gh_rail", -2.85, 0.3, 0.9, 0.98, "gunmetal_w", null, 0.02)
	# the top fairing over the gearbox, the engines either side of it
	k._add(m, VehicleModels.loft("heli_gh_top", [-0.75, -3.7, 0.75, -3.7, 0.98, -2.9, 0.98, 0.9, 0.6, 1.8, -0.6, 1.8, -0.98, 0.9, -0.98, -2.9],
		[-0.42, -3.15, 0.42, -3.15, 0.6, -2.55, 0.6, 0.55, 0.32, 1.25, -0.32, 1.25, -0.6, 0.55, -0.6, -2.55], 2.45, 3.12), mat, col, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.loft("heli_gh_eng", [-0.36, -2.3, 0.36, -2.3, 0.4, 0.75, -0.4, 0.75], [-0.24, -2.1, 0.24, -2.1, 0.26, 0.6, -0.26, 0.6], 2.48, 3.08), mat, col, Vector3(s * 0.78, 0, 0))
		k._box(m, Vector3(0.4, 0.4, 0.04), Vector3(s * 0.78, 2.78, -2.32), "plain", dark, Vector3(-0.35, 0, 0), false)
		# the shrouded exhausts, turned out and up
		k._add(m, VehicleModels.loft("heli_gh_exh", [-0.24, 0.0, 0.24, 0.0, 0.2, 0.8, -0.2, 0.8], [-0.18, 0.05, 0.18, 0.05, 0.14, 0.7, -0.14, 0.7], 0.0, 0.34), "gunmetal_w", null, Vector3(s * 0.82, 2.66, 0.7), Vector3(0, s * 0.35, 0))
		k._box(m, Vector3(0.24, 0.03, 0.5), Vector3(s * 0.95, 3.01, 1.12), "plain", dark, Vector3(0, s * 0.35, 0), false)
	# mast, swashplate, the IR jammer behind, wire cutters, pitots
	k._cyl(m, 0.16, 0.2, 0.55, Vector3(0, 3.3, -2.0), Vector3.ZERO, "gunmetal_w", null, 10)
	k._cyl(m, 0.34, 0.34, 0.06, Vector3(0, 3.28, -2.0), Vector3.ZERO, "steel", null, 12)
	k._cyl(m, 0.13, 0.15, 0.3, Vector3(0, 3.24, 1.05), Vector3.ZERO, "gunmetal_w", null, 8)
	k._box(m, Vector3(0.04, 0.42, 0.08), Vector3(0, 2.75, -4.62), "steel", null, Vector3(0.5, 0, 0))
	k._box(m, Vector3(0.04, 0.3, 0.08), Vector3(0, 0.9, -6.2), "steel", null, Vector3(-0.6, 0, 0))
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.32, 1.72, -6.2), Vector3(s * 0.32, 1.7, -6.95), 0.018, "steel", null, 4)
		# steps, a grab handle, the navigation lights
		k._box(m, Vector3(0.12, 0.04, 0.3), Vector3(s * 1.2, 0.7, -4.6), "gunmetal_w")
		k._box(m, Vector3(0.05, 0.05, 0.06), Vector3(s * 1.12, 2.3, -4.2), "plain", Color(0.6, 0.1, 0.08) if s < 0 else Color(0.1, 0.5, 0.2), Vector3.ZERO, false)
		k._box(m, Vector3(0.02, 0.04, 0.3), Vector3(s * 1.2, 1.4, -2.65), "gunmetal_w", null, Vector3.ZERO, false)
	# the tail pylon, the canted tail rotor high on its right, the stabilator
	k._add(m, VehicleModels.extrude_x("heli_gh_pylon", [6.3, 2.25, 7.85, 2.2, 8.32, 4.3, 7.62, 4.42], -0.14, 0.14), mat, col, Vector3.ZERO)
	k._add(m, VehicleModels.loft("heli_gh_tgb", [-0.12, -0.35, 0.12, -0.35, 0.12, 0.35, -0.12, 0.35], [-0.06, -0.25, 0.06, -0.25, 0.06, 0.25, -0.06, 0.25], 0.0, 0.18), mat, col, Vector3(0.12, 3.48, 7.95), Vector3(0, 0, -PI / 2))
	var cant := k._pivot(m, Vector3(0.36, 3.48, 7.95))
	cant.rotation.z = 0.35
	_tail_rotor(k, cant, Vector3.ZERO, 4, 1.68, 0.25, 1.0, 0.3)
	k._cyl(k.tail_rotor, 0.16, 0.24, 0.12, Vector3(0.14, 0, 0), Vector3(0, 0, -PI / 2), mat, col, 8)
	k._add(m, VehicleModels.loft("heli_gh_stab", [-0.3, 7.3, 0.3, 7.3, 2.1, 7.7, 2.1, 8.32, -2.1, 8.32, -2.1, 7.7],
		[-0.3, 7.34, 0.3, 7.34, 2.1, 7.73, 2.1, 8.28, -2.1, 8.28, -2.1, 7.73], 2.22, 2.31), mat, col, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("heli_gh_endp", [7.68, 0.0, 8.32, 0.0, 8.5, 0.62, 8.08, 0.62], -0.03, 0.03), mat, col, Vector3(s * 2.1, 2.27, 0), Vector3(0, 0, -s * 0.38))
		k._team_mark(m, team, Vector3(s * 0.4, 2.06, 4.6), Vector3(0.02, 0.24, 0.8))
	_tube(k, m, Vector3(0, 2.4, 3.6), Vector3(0, 2.72, 3.9), 0.014, "gunmetal_w", null, 4)
	k._box(m, Vector3(0.03, 0.2, 0.3), Vector3(0, 2.48, 5.6), "gunmetal_w", null, Vector3(0, 0, 0))
	k._add(m, Res.sphere(0.06, 8), "plain", Color(0.55, 0.08, 0.06), Vector3(0, 4.45, 7.65))
	# tailwheel
	_tube(k, m, Vector3(0, 1.88, 6.05), Vector3(0, 0.36, 6.4), 0.06, "gunmetal_w", null, 8)
	_tube(k, m, Vector3(0, 1.84, 5.55), Vector3(0, 0.9, 6.25), 0.04, "steel", null, 6)
	k._box(m, Vector3(0.26, 0.08, 0.2), Vector3(0, 0.4, 6.42), "gunmetal_w")
	k._wheel(m, Vector3(0, 0.24, 6.48), 0.24, 0.16)
	# main gear: drag beam and shock strut, faceted hub covers
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.78, 0.68, -4.35), Vector3(s * 1.36, 0.4, -3.95), 0.07, "gunmetal_w", null, 8)
		_tube(k, m, Vector3(s * 1.08, 1.3, -3.8), Vector3(s * 1.38, 0.5, -3.92), 0.08, "gunmetal_w", null, 8)
		k._box(m, Vector3(0.22, 0.62, 0.3), Vector3(s * 1.18, 1.05, -3.84), mat, col, Vector3(0, 0, s * 0.35))
		var wp := k._wheel(m, Vector3(s * 1.48, 0.38, -3.95), 0.38, 0.26)
		k._cyl(wp, 0.3, 0.3, 0.04, Vector3(s * 0.14, 0, 0), Vector3(0, 0, PI / 2), mat, col, 8)
	# door guns: miniguns on pintles in the gunners' windows
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 1.0, 1.45, -3.2), Vector3(s * 1.3, 1.55, -3.15), 0.035, "gunmetal_w", null, 6)
		var tip := _minigun(k, m, Vector3(s * 1.34, 1.62, -3.05), 0.7)
		_path(k, m, [Vector3(s * 1.3, 1.55, -2.92), Vector3(s * 1.2, 1.4, -2.85), Vector3(s * 1.0, 1.35, -2.95)], 0.035, "rubber", null, 6)
		if s > 0.0:
			k.mg_tip = k._tip(m, tip)
	if stub:
		# the External Stores Support System: anhedral stub wings over the
		# cabin's rear, braced to the floor, two pylons and two pods a side
		for s in [-1.0, 1.0]:
			k._box(m, Vector3(2.15, 0.12, 0.88), Vector3(s * 2.0, 2.18, -0.1), mat, col, Vector3(0, 0, -s * 0.1))
			k._box(m, Vector3(0.3, 0.24, 1.0), Vector3(s * 1.05, 2.3, -0.1), mat, col)
			_tube(k, m, Vector3(s * 2.3, 2.08, -0.1), Vector3(s * 1.1, 0.95, -0.1), 0.045, "gunmetal_w", null, 6)
			for j in 2:
				var px: float = s * (1.7 + j * 0.95)
				var py: float = 2.16 - (absf(px) - 2.0) * 0.1
				k._box(m, Vector3(0.1, 0.24, 0.62), Vector3(px, py - 0.18, -0.1), "gunmetal_w")
				_rocket_pod(k, m, Vector3(px, py - 0.5, -0.2), 0.2, 1.7, "paint", Color(0.3, 0.32, 0.27), 7 if j == 0 else 19)
	# the rotor: four blades with swept tips under a faceted hub cap
	_rotor(k, m, Vector3(0, 3.62, -2.0), 4, 8.18, 0.53, true, PI / 4, 0.02, 0.42, 1)
	k._cyl(k.rotor, 0.5, 0.84, 0.2, Vector3(0, 0.22, 0), Vector3.ZERO, mat, col, 8)
	k._cyl(k.rotor, 0.2, 0.5, 0.1, Vector3(0, 0.37, 0), Vector3.ZERO, mat, col, 8)


# --- CH-67 Huron ----------------------------------------------------------------------

## CH-67 Huron, the stealth Chinook: a long faceted box of a fuselage on four
## fixed wheels, fuel sponsons down its flanks, the forward rotor on a low
## pylon over the cockpit and the aft one on the tall rear pylon with an
## engine either side, the shaft tunnel along the roof between them, two
## three-blade rotors turning against each other, the loading ramp under the
## tail. No tail rotor.
static func _huron(k: VehicleModels, team: int) -> void:
	var m := k.root
	var pc := _air(team, Color(0.24, 0.25, 0.26))
	var mat: String = pc[0]
	var col = pc[1]
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-7.95, 1.72, 0.32, 0.3, 0.42],
		[-7.6, 1.78, 0.95, 0.74, 0.98],
		[-7.0, 1.87, 1.2, 1.15, 1.15],
		[-6.2, 1.95, 1.28, 1.25, 1.25],
		[3.9, 1.95, 1.28, 1.25, 1.25],
		[4.6, 2.0, 1.28, 1.2, 1.25],
		[7.95, 2.35, 1.2, 0.85, 0.82],
	], 8, 5.0, PI / 8)
	_hull(k, m, h, "heli_hu_body", mat, col)
	# cockpit glazing: windscreen, chin windows, side windows; the crew door
	_patch(k, m, h, "heli_hu_wind", -7.72, -6.98, 0.12, 2.88, "glass", null, 0.012, 0.05, 1.0)
	for t in [1.0, 1.5, 2.0]:
		_patch(k, m, h, "heli_hu_post%d" % int(t * 10), -7.72, -6.98, t - 0.04, t + 0.04, mat, col, 0.022, 0.02, 1.0)
	_patch(k, m, h, "heli_hu_chin", -7.76, -7.08, -1.86, -1.14, "glass", null, 0.012, 0.05)
	_patch(k, m, h, "heli_hu_side", -6.88, -5.86, -0.55, 0.86, "glass", null, 0.012, 0.05)
	_patch(k, m, h, "heli_hu_sidep", -6.4, -6.33, -0.55, 0.86, mat, col, 0.022, 0.02)
	for z in [-5.58, -4.72]:
		_patch(k, m, h, "heli_hu_dseam%d" % int(-z * 10), z - 0.014, z + 0.014, -1.85, 0.92, "gunmetal_w", null, 0.008, 0.03, 1.0)
	_patch(k, m, h, "heli_hu_dwin", -5.42, -4.88, -0.15, 0.6, "glass", null, 0.012, 0.05, 1.0)
	_patch(k, m, h, "heli_hu_hatch", -5.42, -4.88, -0.15, 0.6, "glass", null, 0.012, 0.05, -1.0)
	# the row of small cabin windows
	for i in 6:
		var zc := -3.6 + i * 1.4
		_patch(k, m, h, "heli_hu_cw%d" % i, zc - 0.2, zc + 0.2, -0.38, -0.12, "glass", null, 0.012)
	# the ramp: hinge line, its edges under the tail, the door in the back
	_patch(k, m, h, "heli_hu_hinge", 4.56, 4.66, 4.8, 7.2, "gunmetal_w", null, 0.012, 0.03, 1.0)
	for t in [4.85, 6.15]:
		_patch(k, m, h, "heli_hu_redge%d" % int(t * 10), 4.6, 7.95, t - 0.04, t + 0.04, "gunmetal_w", null, 0.01, 0.03, 1.0)
	k._box(m, Vector3(1.9, 0.05, 0.05), Vector3(0, 2.3, 7.96), "gunmetal_w", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.75, 0.05), Vector3(s * 0.95, 1.93, 7.96), "gunmetal_w", null, Vector3.ZERO, false)
	# fuel sponsons down the flanks
	for s in [-1.0, 1.0]:
		var base := [1.02, 0.78, 1.72, 0.82, 1.92, 1.05, 1.92, 1.42, 1.74, 1.66, 1.02, 1.7]
		var rings := []
		for zf in [[-4.75, 0.3], [-4.25, 0.86], [-3.8, 1.0], [3.0, 1.0], [3.75, 0.86], [4.3, 0.35]]:
			var pts := []
			for i in range(0, base.size(), 2):
				pts.append(s * (1.02 + (float(base[i]) - 1.02) * float(zf[1])))
				pts.append(1.24 + (float(base[i + 1]) - 1.24) * float(zf[1]))
			rings.append(_rz(pts, float(zf[0])))
		k._add(m, VehicleModels.solid(rings, "heli_hu_spon%s" % ("r" if s > 0.0 else "l")), mat, col, Vector3.ZERO)
		for z in [-2.0, 0.6]:
			k._box(m, Vector3(0.03, 0.42, 0.03), Vector3(s * 1.935, 1.24, z), "gunmetal_w", null, Vector3.ZERO, false)
		k._cyl(m, 0.07, 0.07, 0.04, Vector3(s * 1.84, 1.6, -1.0), Vector3.ZERO, "gunmetal_w", null, 8, false)
		# the gear: two wheels forward of the sponsons, two under their tails
		_gear(k, m, Vector3(s * 1.3, 0.95, -4.45), Vector3(s * 1.42, 0.45, -4.62), 0.45, 0.3)
		_tube(k, m, Vector3(s * 0.8, 0.75, -4.75), Vector3(s * 1.36, 0.6, -4.62), 0.06, "gunmetal_w", null, 8)
		_gear(k, m, Vector3(s * 1.55, 0.85, 3.55), Vector3(s * 1.6, 0.45, 3.72), 0.45, 0.3)
		# steps, lights, the rescue hoist over the door
		k._box(m, Vector3(0.14, 0.04, 0.32), Vector3(s * 1.32, 0.62, -5.15), "gunmetal_w")
		k._box(m, Vector3(0.05, 0.06, 0.06), Vector3(s * 1.95, 1.66, -3.0), "plain", Color(0.6, 0.1, 0.08) if s < 0 else Color(0.1, 0.5, 0.2), Vector3.ZERO, false)
	k._box(m, Vector3(0.5, 0.18, 0.3), Vector3(1.3, 3.02, -5.15), "gunmetal_w", null, Vector3(0, 0, -0.5))
	_tube(k, m, Vector3(1.55, 3.0, -5.15), Vector3(1.55, 2.6, -5.15), 0.015, "steel", null, 4)
	# cargo hooks, the FLIR ball, pitots
	for z in [-1.5, 0.0, 1.5]:
		k._box(m, Vector3(0.2, 0.12, 0.3), Vector3(0, 0.66, z), "gunmetal_w")
	k._box(m, Vector3(0.14, 0.14, 0.14), Vector3(0, 0.85, -7.3), "gunmetal_w")
	k._add(m, Res.sphere(0.2, 12), "paint", Color(0.28, 0.29, 0.28), Vector3(0, 0.7, -7.32))
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.45, 2.3, -7.75), Vector3(s * 0.45, 2.28, -8.25), 0.02, "steel", null, 4)
	# forward pylon, the shaft tunnel, the tall aft pylon with its engines
	k._add(m, VehicleModels.loft("heli_hu_fpyl", [-0.95, -7.35, 0.95, -7.35, 1.1, -6.6, 1.1, -4.55, -1.1, -4.55, -1.1, -6.6],
		[-0.42, -6.85, 0.42, -6.85, 0.58, -6.4, 0.58, -5.25, -0.58, -5.25, -0.58, -6.4], 3.1, 3.92), mat, col, Vector3.ZERO)
	k._add(m, VehicleModels.loft("heli_hu_tun", [-0.6, -4.8, 0.6, -4.8, 0.6, 3.6, -0.6, 3.6], [-0.4, -4.75, 0.4, -4.75, 0.4, 3.6, -0.4, 3.6], 3.1, 3.5), mat, col, Vector3.ZERO)
	k._add(m, VehicleModels.loft("heli_hu_apyl", [-0.9, 3.2, 0.9, 3.2, 1.02, 4.0, 1.02, 7.98, -1.02, 7.98, -1.02, 4.0],
		[-0.5, 5.0, 0.5, 5.0, 0.58, 5.4, 0.58, 6.9, -0.58, 6.9, -0.58, 5.4], 3.1, 5.02), mat, col, Vector3.ZERO)
	var eng := Hull.new([[3.3, 3.55, 0.32, 0.32, 0.32], [3.6, 3.55, 0.47, 0.47, 0.47], [6.25, 3.55, 0.47, 0.47, 0.47], [6.95, 3.55, 0.33, 0.33, 0.33]], 8, 2.2, PI / 8)
	for s in [-1.0, 1.0]:
		k._add(m, eng.mesh("heli_hu_eng"), mat, col, Vector3(s * 1.56, 0, 0))
		k._cyl(m, 0.3, 0.3, 0.04, Vector3(s * 1.56, 3.55, 3.29), Vector3(PI / 2, 0, 0), "plain", dark, 8, false)
		k._cyl(m, 0.13, 0.13, 0.06, Vector3(s * 1.56, 3.55, 3.27), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
		k._box(m, Vector3(0.32, 0.3, 0.12), Vector3(s * 1.56, 3.55, 6.98), "plain", dark, Vector3.ZERO, false)
		k._box(m, Vector3(0.5, 0.18, 1.6), Vector3(s * 1.12, 3.5, 4.9), mat, col)
		k._team_mark(m, team, Vector3(s * 0.97, 4.0, 6.6), Vector3(0.02, 0.4, 0.8))
	# masts, antennas, beacons
	k._cyl(m, 0.2, 0.24, 0.45, Vector3(0, 4.05, -5.95), Vector3.ZERO, "gunmetal_w", null, 10)
	k._cyl(m, 0.2, 0.24, 0.45, Vector3(0, 5.2, 6.0), Vector3.ZERO, "gunmetal_w", null, 10)
	_tube(k, m, Vector3(0, 3.5, -1.0), Vector3(0, 3.9, -0.8), 0.014, "gunmetal_w", null, 4)
	k._box(m, Vector3(0.03, 0.22, 0.32), Vector3(0, 3.6, 1.6), "gunmetal_w")
	k._add(m, Res.sphere(0.07, 8), "plain", Color(0.55, 0.08, 0.06), Vector3(0, 3.53, 2.6))
	_tube(k, m, Vector3(0, 0.66, 2.8), Vector3(0, 0.36, 3.1), 0.012, "gunmetal_w", null, 4)
	# the rotors: three-blade, contra-rotating, the aft one higher
	_rotor(k, m, Vector3(0, 4.32, -5.95), 3, 9.15, 0.81, true, 0.0, 0.028, 0.5, 1)
	k._cyl(k.rotor, 0.4, 0.78, 0.22, Vector3(0, 0.24, 0), Vector3.ZERO, mat, col, 6)
	var rr := _rotor(k, m, Vector3(0, 5.48, 6.0), 3, 9.15, 0.81, false, PI / 3, 0.028, 0.5, 1)
	k._cyl(rr, 0.4, 0.78, 0.22, Vector3(0, 0.24, 0), Vector3.ZERO, mat, col, 6)


# --- AH-99 Blackfoot ------------------------------------------------------------------

## AH-99 Blackfoot, the RAH-66 Comanche: a chined, faceted stealth fuselage
## with the stepped tandem canopy, the 20 mm three-barrel gun in a chin
## turret, weapon bay doors opened out like stub wings with three Hellfires
## on each, short gear legs out of their stubs and a tailwheel, a five-blade
## rotor with swept tips, the fantail in its shroud under a T-tail.
static func _blackfoot(k: VehicleModels, team: int) -> void:
	var m := k.root
	var pc := _air(team, Color(0.33, 0.35, 0.33))
	var mat: String = pc[0]
	var col = pc[1]
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-6.55, 1.02, 0.05, 0.05, 0.05],
		[-6.1, 1.05, 0.42, 0.36, 0.34],
		[-5.3, 1.1, 0.66, 0.62, 0.46],
		[-4.3, 1.15, 0.78, 0.98, 0.52],
		[-3.5, 1.18, 0.83, 1.08, 0.55],
		[-3.25, 1.19, 0.85, 1.3, 0.56],
		[-2.3, 1.2, 0.9, 1.34, 0.57],
		[-1.4, 1.22, 0.95, 1.28, 0.6],
		[0.6, 1.28, 0.92, 1.12, 0.6],
		[1.8, 1.38, 0.62, 0.8, 0.42],
		[3.8, 1.52, 0.36, 0.46, 0.28],
		[5.3, 1.58, 0.3, 0.38, 0.24],
	], 6, 2.0, 0.0)
	_hull(k, m, h, "heli_bf_body", mat, col)
	# the stepped tandem canopy, framed, and the night-pilotage window
	_patch(k, m, h, "heli_bf_can1", -5.25, -3.55, 0.22, 2.78, "glass", null, 0.012, 0.05, 1.0)
	_patch(k, m, h, "heli_bf_can2", -3.2, -2.05, 0.22, 2.78, "glass", null, 0.012, 0.05, 1.0)
	_patch(k, m, h, "heli_bf_bow", -3.56, -3.2, 0.1, 2.9, mat, col, 0.026, 0.03, 1.0)
	for t in [1.0, 2.0]:
		_patch(k, m, h, "heli_bf_rail%d" % int(t), -5.25, -2.05, t - 0.05, t + 0.05, mat, col, 0.022, 0.02, 1.0)
	_patch(k, m, h, "heli_bf_nvps", -6.5, -6.0, 0.2, 2.8, "glass", null, 0.01, 0.04, 1.0)
	# the bays, open; engine inlets; exhaust slots down the tail
	_patch(k, m, h, "heli_bf_bay", -1.85, 0.55, -0.88, -0.1, "plain", dark, 0.006)
	_patch(k, m, h, "heli_bf_inlet", -1.95, -1.05, 0.25, 0.72, "plain", dark, 0.008)
	_patch(k, m, h, "heli_bf_exh", 1.9, 3.4, -0.72, -0.25, "plain", dark, 0.008)
	_patch(k, m, h, "heli_bf_seam", -4.35, -4.3, -0.95, 0.2, "gunmetal_w", null, 0.008)
	# the mast fairing and mast
	k._add(m, VehicleModels.loft("heli_bf_mast", [-0.5, -2.1, 0.5, -2.1, 0.62, -1.2, 0.55, 1.2, -0.55, 1.2, -0.62, -1.2],
		[-0.24, -1.62, 0.24, -1.62, 0.34, -1.05, 0.28, 0.35, -0.28, 0.35, -0.34, -1.05], 2.2, 2.78), mat, col, Vector3.ZERO)
	k._cyl(m, 0.12, 0.16, 0.35, Vector3(0, 2.92, -1.1), Vector3.ZERO, "gunmetal_w", null, 10)
	# the fantail: a shroud with an open duct, a fin over it, the T-tail
	_ducted_fin(k, m, "heli_bf_duct", [5.05, 1.25, 5.45, 0.95, 6.6, 0.95, 6.98, 1.4, 6.98, 2.15, 6.6, 2.52, 5.45, 2.52, 5.05, 2.15],
		Vector2(6.0, 1.72), 0.62, -0.19, 0.19, mat, col, 16)
	_fan(k, m, Vector3(0, 1.72, 6.0), 8, 0.6, 0.13)
	for a in [0.4, 2.2, 4.0]:
		k._box(m, Vector3(0.03, 0.56, 0.08), Vector3(-0.1, 1.72 + sin(a) * 0.32, 6.0 + cos(a) * 0.32), "gunmetal_w", null, Vector3(-a + PI / 2, 0, 0), false)
	k._add(m, VehicleModels.extrude_x("heli_bf_fin", [5.95, 2.45, 6.95, 2.45, 7.22, 3.35, 6.78, 3.38], -0.07, 0.07), mat, col, Vector3.ZERO)
	k._add(m, VehicleModels.loft("heli_bf_hstab", [-0.2, 6.62, 0.2, 6.62, 1.08, 6.85, 1.08, 7.3, -1.08, 7.3, -1.08, 6.85],
		[-0.2, 6.65, 0.2, 6.65, 1.08, 6.87, 1.08, 7.27, -1.08, 7.27, -1.08, 6.87], 3.34, 3.41), mat, col, Vector3.ZERO)
	k._add(m, Res.sphere(0.05, 8), "plain", Color(0.55, 0.08, 0.06), Vector3(0, 3.44, 7.1))
	# tailwheel under the boom
	_tube(k, m, Vector3(0, 1.34, 4.5), Vector3(0, 0.3, 4.82), 0.045, "gunmetal_w", null, 8)
	k._box(m, Vector3(0.18, 0.06, 0.16), Vector3(0, 0.34, 4.84), "gunmetal_w")
	k._wheel(m, Vector3(0, 0.2, 4.88), 0.2, 0.12)
	for s in [-1.0, 1.0]:
		# main gear legs out of their stubs
		k._box(m, Vector3(0.24, 0.24, 0.62), Vector3(s * 0.78, 0.8, -2.95), mat, col, Vector3(0, 0, s * 0.5))
		_tube(k, m, Vector3(s * 0.82, 0.8, -3.1), Vector3(s * 0.98, 0.34, -2.85), 0.06, "gunmetal_w", null, 8)
		_tube(k, m, Vector3(s * 0.8, 0.86, -2.7), Vector3(s * 0.95, 0.4, -2.85), 0.04, "steel", null, 6)
		var wp := k._wheel(m, Vector3(s * 1.04, 0.3, -2.85), 0.3, 0.16)
		k._cyl(wp, 0.22, 0.22, 0.03, Vector3(s * 0.08, 0, 0), Vector3(0, 0, PI / 2), mat, col, 6)
		# the bay doors opened out: three Hellfires on rails under each
		k._box(m, Vector3(0.82, 0.05, 2.3), Vector3(s * 1.33, 1.2, -0.65), mat, col, Vector3(0, 0, -s * 0.06))
		k._box(m, Vector3(0.06, 0.12, 2.2), Vector3(s * 0.94, 1.22, -0.65), "gunmetal_w")
		for j in 3:
			var mx: float = s * (1.08 + j * 0.25)
			k._box(m, Vector3(0.06, 0.1, 1.2), Vector3(mx, 1.12, -0.6), "gunmetal_w", null, Vector3.ZERO, false)
			_missile(k, m, Vector3(mx, 0.97, -0.6), 0.085, 1.62, Color(0.3, 0.33, 0.26))
		k._team_mark(m, team, Vector3(s * 0.43, 1.58, 3.0), Vector3(0.02, 0.18, 0.7))
		k._box(m, Vector3(0.05, 0.05, 0.06), Vector3(s * 1.74, 1.18, -0.2), "plain", Color(0.6, 0.1, 0.08) if s < 0 else Color(0.1, 0.5, 0.2), Vector3.ZERO, false)
	# the chin turret: XM301 three-barrel 20 mm
	k.turret = k._pivot(m, Vector3(0, 0.68, -4.75))
	k._cyl(k.turret, 0.2, 0.24, 0.2, Vector3(0, -0.02, 0), Vector3.ZERO, mat, col, 8)
	k._box(k.turret, Vector3(0.22, 0.2, 0.55), Vector3(0, -0.18, -0.18), "gunmetal_w")
	for i in 3:
		var a := TAU * float(i) / 3.0 + PI / 2
		k._cyl(k.turret, 0.022, 0.022, 1.3, Vector3(cos(a) * 0.045, -0.18 + sin(a) * 0.045, -1.05), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	k._cyl(k.turret, 0.075, 0.075, 0.1, Vector3(0, -0.18, -0.6), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k._cyl(k.turret, 0.07, 0.07, 0.06, Vector3(0, -0.18, -1.62), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
	k.mg_tip = k._tip(k.turret, Vector3(0, -0.18, -1.72))
	# pitots and an antenna
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.25, 1.35, -5.8), Vector3(s * 0.25, 1.33, -6.35), 0.012, "steel", null, 4)
	k._box(m, Vector3(0.03, 0.16, 0.25), Vector3(0, 2.0, 1.5), "gunmetal_w")
	# the rotor: five blades with swept tips, a faceted hub shroud
	_rotor(k, m, Vector3(0, 3.12, -1.1), 5, 5.95, 0.36, true, 0.0, 0.015, 0.3, 1)
	k._cyl(k.rotor, 0.3, 0.6, 0.2, Vector3(0, 0.18, 0), Vector3.ZERO, mat, col, 5)


# --- CH-49 Mohawk ---------------------------------------------------------------------

## CH-49 Mohawk, the AW101 Merlin: a long, slab-sided cabin with the rear
## ramp under its upswept tail, three engines on the roof (two either side of
## the gearbox, one behind it), sponsons holding the twin-wheel main gear, a
## twin nosewheel, the five-blade rotor with BERP paddle tips, the four-blade
## tail rotor on the left of the pylon and the tailplane on its right. AAF
## two-tone: olive over grey-green.
static func _mohawk(k: VehicleModels, team: int) -> void:
	var m := k.root
	var lo := ["aircraft", Color(0.42, 0.44, 0.39)]
	var hi := ["aircraft", Color(0.3, 0.33, 0.24)]
	if team == 1:
		lo = ["aircraft", CSAT_SAND]
		hi = ["aircraft", CSAT_SAND.darkened(0.12)]
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-9.8, 1.65, 0.3, 0.3, 0.4],
		[-9.4, 1.68, 0.95, 0.78, 0.92],
		[-8.8, 1.72, 1.25, 1.02, 1.08],
		[-7.9, 1.75, 1.38, 1.15, 1.13],
		[1.6, 1.75, 1.38, 1.15, 1.13],
		[2.6, 1.95, 1.36, 0.95, 0.95],
		[4.6, 2.35, 1.0, 0.62, 0.48],
		[8.4, 2.6, 0.42, 0.36, 0.3],
		[9.73, 2.7, 0.3, 0.3, 0.25],
	], 12, 3.0)
	_hull(k, m, h, "heli_mo_body", lo[0], lo[1])
	# the olive upper half of the scheme
	_patch(k, m, h, "heli_mo_top", -8.6, 9.73, 0.55, 5.45, hi[0], hi[1], 0.005, 0.03, 1.0)
	# the cockpit: windscreen, chin windows, side windows
	_patch(k, m, h, "heli_mo_wind", -9.6, -8.55, 0.65, 5.35, "glass", null, 0.012, 0.05, 1.0)
	for t in [1.6, 3.0, 4.4]:
		_patch(k, m, h, "heli_mo_post%d" % int(t * 10), -9.6, -8.55, t - 0.05, t + 0.05, hi[0], hi[1], 0.022, 0.02, 1.0)
	_patch(k, m, h, "heli_mo_chin", -9.55, -8.75, -2.2, -1.25, "glass", null, 0.012, 0.05)
	_patch(k, m, h, "heli_mo_side", -8.45, -7.45, -0.35, 1.5, "glass", null, 0.012, 0.05)
	# the cabin door (right, forward), windows down both sides
	for z in [-6.85, -5.25]:
		_patch(k, m, h, "heli_mo_dseam%d" % int(-z * 10), z - 0.015, z + 0.015, -2.0, 1.7, "gunmetal_w", null, 0.01, 0.03, 1.0)
	_patch(k, m, h, "heli_mo_drail", -6.9, -3.8, -2.05, -1.95, "gunmetal_w", null, 0.014, 0.03, 1.0)
	for i in 6:
		var zc := -6.05 + i * 1.32
		_patch(k, m, h, "heli_mo_cw%d" % i, zc - 0.3, zc + 0.3, 0.15, 0.9, "glass", null, 0.012)
	# the ramp: hinge line, its edges
	_patch(k, m, h, "heli_mo_hinge", 1.55, 1.65, 7.6, 10.4, "gunmetal_w", null, 0.012, 0.03, 1.0)
	for t in [7.7, 10.3]:
		_patch(k, m, h, "heli_mo_redge%d" % int(t * 10), 1.6, 4.6, t - 0.05, t + 0.05, "gunmetal_w", null, 0.01, 0.03, 1.0)
	# sponsons with the twin-wheel main gear, the twin nosewheel
	for s in [-1.0, 1.0]:
		var base := [1.25, 0.66, 1.9, 0.7, 2.14, 0.95, 2.14, 1.3, 1.92, 1.52, 1.25, 1.58]
		var rings := []
		for zf in [[-1.95, 0.25], [-1.25, 0.88], [-0.8, 1.0], [1.0, 1.0], [1.6, 0.82], [2.35, 0.28]]:
			var pts := []
			for i in range(0, base.size(), 2):
				pts.append(s * (1.25 + (float(base[i]) - 1.25) * float(zf[1])))
				pts.append(1.12 + (float(base[i + 1]) - 1.12) * float(zf[1]))
			rings.append(_rz(pts, float(zf[0])))
		k._add(m, VehicleModels.solid(rings, "heli_mo_spon%s" % ("r" if s > 0.0 else "l")), lo[0], lo[1], Vector3.ZERO)
		_gear(k, m, Vector3(s * 1.78, 0.72, 0.0), Vector3(s * 1.8, 0.38, 0.12), 0.38, 0.22, true)
		k._box(m, Vector3(0.05, 0.06, 0.06), Vector3(s * 2.15, 1.3, -0.5), "plain", Color(0.6, 0.1, 0.08) if s < 0 else Color(0.1, 0.5, 0.2), Vector3.ZERO, false)
		k._box(m, Vector3(0.14, 0.04, 0.32), Vector3(s * 1.4, 0.66, -6.0), "gunmetal_w")
		k._team_mark(m, team, Vector3(s * 0.4, 2.6, 7.4), Vector3(0.02, 0.26, 0.9))
	_gear(k, m, Vector3(0, 0.72, -8.3), Vector3(0, 0.32, -8.45), 0.32, 0.18, true)
	# the hoist over the door, the radome, pitots
	k._box(m, Vector3(0.55, 0.2, 0.32), Vector3(1.35, 3.0, -6.1), "gunmetal_w", null, Vector3(0, 0, -0.45))
	_tube(k, m, Vector3(1.62, 2.95, -6.1), Vector3(1.62, 2.55, -6.1), 0.015, "steel", null, 4)
	k._add(m, Res.sphere(0.45, 12), lo[0], (lo[1] as Color).darkened(0.1), Vector3(0, 0.88, -8.95), Vector3.ZERO, Vector3(1.3, 0.55, 1.3))
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.55, 2.35, -9.45), Vector3(s * 0.55, 2.32, -10.0), 0.02, "steel", null, 4)
	# the roof: gearbox fairing, three engines, their intakes and exhausts
	k._add(m, VehicleModels.loft("heli_mo_roof", [-0.95, -5.5, 0.95, -5.5, 1.15, -4.7, 1.15, 1.2, 0.8, 2.3, -0.8, 2.3, -1.15, 1.2, -1.15, -4.7],
		[-0.6, -5.05, 0.6, -5.05, 0.82, -4.35, 0.82, 0.9, 0.5, 1.8, -0.5, 1.8, -0.82, 0.9, -0.82, -4.35], 2.8, 3.6), hi[0], hi[1], Vector3.ZERO)
	var eng := Hull.new([[-4.75, 3.25, 0.3, 0.3, 0.3], [-4.55, 3.25, 0.38, 0.4, 0.36], [-1.9, 3.25, 0.38, 0.4, 0.36], [-1.3, 3.25, 0.3, 0.32, 0.28]], 10, 2.4)
	for s in [-1.0, 1.0]:
		k._add(m, eng.mesh("heli_mo_eng"), hi[0], hi[1], Vector3(s * 0.98, 0, 0))
		k._cyl(m, 0.27, 0.27, 0.04, Vector3(s * 0.98, 3.25, -4.76), Vector3(PI / 2, 0, 0), "plain", dark, 10, false)
		k._cyl(m, 0.1, 0.1, 0.06, Vector3(s * 0.98, 3.25, -4.78), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
		_tube(k, m, Vector3(s * 1.0, 3.25, -1.45), Vector3(s * 1.42, 3.3, -1.0), 0.2, "gunmetal_w", null, 10, 0.18)
		k._cyl(m, 0.15, 0.15, 0.03, Vector3(s * 1.43, 3.3, -0.99), Vector3(0, 0, PI / 2 - s * 0.0), "plain", dark, 10, false)
	k._add(m, VehicleModels.loft("heli_mo_eng2", [-0.45, -0.9, 0.45, -0.9, 0.5, 1.9, -0.5, 1.9], [-0.3, -0.75, 0.3, -0.75, 0.34, 1.6, -0.34, 1.6], 3.5, 4.0), hi[0], hi[1], Vector3.ZERO)
	k._box(m, Vector3(0.5, 0.3, 0.04), Vector3(0, 3.78, -0.92), "plain", dark, Vector3(-0.3, 0, 0), false)
	_tube(k, m, Vector3(-0.3, 3.7, 1.7), Vector3(-0.6, 3.75, 2.3), 0.18, "gunmetal_w", null, 10, 0.16)
	# mast, the IR jammer, antennas
	k._cyl(m, 0.2, 0.26, 0.6, Vector3(0, 4.1, -2.5), Vector3.ZERO, "gunmetal_w", null, 10)
	k._cyl(m, 0.42, 0.42, 0.06, Vector3(0, 3.95, -2.5), Vector3.ZERO, "steel", null, 12)
	_tube(k, m, Vector3(0, 2.95, 4.0), Vector3(0, 3.35, 4.3), 0.014, "gunmetal_w", null, 4)
	k._box(m, Vector3(0.03, 0.22, 0.32), Vector3(0, 3.05, 6.0), "gunmetal_w")
	_tube(k, m, Vector3(0, 0.64, -3.0), Vector3(0, 0.32, -2.7), 0.012, "gunmetal_w", null, 4)
	# the tail pylon, the tail rotor on its left, the tailplane on its right
	k._add(m, VehicleModels.extrude_x("heli_mo_pylon", [7.95, 2.6, 9.75, 2.5, 10.15, 5.3, 9.3, 5.45], -0.16, 0.16), hi[0], hi[1], Vector3.ZERO)
	k._add(m, VehicleModels.loft("heli_mo_tail", [0.1, 9.15, 2.35, 9.35, 2.35, 9.95, 0.1, 10.05], [0.1, 9.18, 2.35, 9.37, 2.35, 9.93, 0.1, 10.02], 4.92, 5.02), hi[0], hi[1], Vector3.ZERO)
	k._add(m, VehicleModels.extrude_x("heli_mo_tendp", [9.3, 4.75, 9.95, 4.75, 10.05, 5.25, 9.55, 5.25], -0.025, 0.025), hi[0], hi[1], Vector3(2.35, 0, 0))
	k._add(m, Res.sphere(0.07, 8), "plain", Color(0.55, 0.08, 0.06), Vector3(0, 5.5, 9.45))
	_tail_rotor(k, m, Vector3(-0.22, 4.68, 9.55), 4, 2.0, 0.3, -1.0, 0.2)
	k._cyl(k.tail_rotor, 0.14, 0.22, 0.14, Vector3(-0.12, 0, 0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10)
	# the rotor: five BERP blades
	_rotor(k, m, Vector3(0, 4.45, -2.5), 5, 9.3, 0.62, true, 0.25, 0.026, 0.5, 2)
	k._cyl(k.rotor, 0.36, 0.5, 0.18, Vector3(0, 0.2, 0), Vector3.ZERO, "gunmetal_w", null, 10)


# --- WY-55 Hellcat --------------------------------------------------------------------

## WY-55 Hellcat, the AW159 Wildcat (on skids): the compact Lynx cabin with
## the Wildcat's angular nose and its sensor turret on top, sliding doors,
## twin engines under the roof fairing exhausting out the sides, the slim
## boom up to the swept pylon with the four-blade tail rotor on the left and
## the tailplane on the right, four BERP blades, weapon pylons either side
## with a minigun and a rocket pod.
static func _hellcat(k: VehicleModels, team: int) -> void:
	var m := k.root
	var mat := "camo_tank"
	var col = AAF_GREEN
	if team == 1:
		mat = "camo_tank_rebel"
		col = null
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-5.5, 1.35, 0.18, 0.18, 0.24],
		[-5.15, 1.38, 0.62, 0.5, 0.58],
		[-4.5, 1.48, 0.92, 0.76, 0.72],
		[-3.6, 1.6, 1.0, 0.86, 0.85],
		[0.4, 1.62, 1.02, 0.85, 0.85],
		[1.3, 1.8, 0.78, 0.66, 0.6],
		[2.4, 2.0, 0.42, 0.38, 0.32],
		[6.0, 2.18, 0.26, 0.26, 0.22],
		[6.6, 2.22, 0.22, 0.24, 0.2],
	], 12, 2.6)
	_hull(k, m, h, "heli_hc_body", mat, col)
	# glazing: windscreen, chin windows, cockpit doors; the sliding doors
	_patch(k, m, h, "heli_hc_wind", -4.75, -3.62, 0.55, 5.45, "glass", null, 0.012, 0.05, 1.0)
	_patch(k, m, h, "heli_hc_post", -4.75, -3.62, 2.95, 3.05, mat, col, 0.022, 0.02, 1.0)
	_patch(k, m, h, "heli_hc_chin", -5.1, -4.3, -2.1, -1.2, "glass", null, 0.012, 0.05)
	_patch(k, m, h, "heli_hc_side", -3.5, -2.45, -0.35, 1.6, "glass", null, 0.012, 0.05)
	for z in [-3.58, -2.35, -0.55]:
		_patch(k, m, h, "heli_hc_seam%d" % int(-z * 100), z - 0.014, z + 0.014, -2.2, 1.75, "gunmetal_w", null, 0.008)
	_patch(k, m, h, "heli_hc_dwin", -2.05, -0.95, 0.15, 1.35, "glass", null, 0.012)
	_patch(k, m, h, "heli_hc_rail", -2.4, 0.5, 1.75, 1.85, "gunmetal_w", null, 0.016)
	# the roof fairing, engines with side exhausts, mast
	k._add(m, VehicleModels.loft("heli_hc_roof", [-0.72, -3.3, 0.72, -3.3, 0.9, -2.5, 0.9, 1.2, 0.5, 2.3, -0.5, 2.3, -0.9, 1.2, -0.9, -2.5],
		[-0.42, -2.9, 0.42, -2.9, 0.6, -2.2, 0.6, 0.9, 0.3, 1.8, -0.3, 1.8, -0.6, 0.9, -0.6, -2.2], 2.3, 2.95), mat, col, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.04, 0.3, 0.5), Vector3(s * 0.8, 2.62, -1.9), "plain", dark, Vector3(0, 0, s * 0.3), false)
		_tube(k, m, Vector3(s * 0.6, 2.62, 0.75), Vector3(s * 0.98, 2.62, 1.1), 0.17, "gunmetal_w", null, 10, 0.15)
		k._cyl(m, 0.12, 0.12, 0.02, Vector3(s * 0.99, 2.62, 1.11), Vector3(0, -s * 0.75, s * PI / 2), "plain", dark, 10, false)
	k._cyl(m, 0.14, 0.18, 0.45, Vector3(0, 3.12, -0.7), Vector3.ZERO, "gunmetal_w", null, 10)
	k._cyl(m, 0.3, 0.3, 0.05, Vector3(0, 3.02, -0.7), Vector3.ZERO, "steel", null, 12)
	# the sensor turret on the nose, pitots, wire cutters
	k._cyl(m, 0.12, 0.15, 0.14, Vector3(0, 2.05, -4.85), Vector3.ZERO, "gunmetal_w", null, 10)
	k._add(m, Res.sphere(0.21, 12), "paint", Color(0.3, 0.31, 0.3), Vector3(0, 2.28, -4.85))
	k._box(m, Vector3(0.18, 0.12, 0.03), Vector3(0, 2.28, -5.06), "glass", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.35, 1.6, -5.1), Vector3(s * 0.35, 1.58, -5.65), 0.015, "steel", null, 4)
	k._box(m, Vector3(0.04, 0.34, 0.08), Vector3(0, 2.62, -3.7), "steel", null, Vector3(0.5, 0, 0))
	# the tail: pylon, tail rotor on its left, tailplane on its right
	k._add(m, VehicleModels.extrude_x("heli_hc_pylon", [5.55, 2.1, 6.95, 2.05, 7.32, 3.75, 6.75, 3.85], -0.12, 0.12), mat, col, Vector3.ZERO)
	k._add(m, VehicleModels.loft("heli_hc_tail", [0.08, 5.95, 1.55, 6.15, 1.55, 6.6, 0.08, 6.7], [0.08, 5.98, 1.55, 6.17, 1.55, 6.58, 0.08, 6.67], 2.7, 2.78), mat, col, Vector3.ZERO)
	k._add(m, VehicleModels.extrude_x("heli_hc_tendp", [6.05, 2.5, 6.62, 2.5, 6.72, 3.0, 6.28, 3.0], -0.02, 0.02), mat, col, Vector3(1.55, 0, 0))
	k._add(m, VehicleModels.extrude_x("heli_hc_vent", [5.9, 2.0, 6.5, 2.0, 6.75, 1.55, 6.5, 1.5], -0.04, 0.04), mat, col, Vector3.ZERO)
	_tail_rotor(k, m, Vector3(-0.18, 3.28, 6.95), 4, 1.1, 0.18, -1.0, 0.2)
	k._add(m, Res.sphere(0.05, 8), "plain", Color(0.55, 0.08, 0.06), Vector3(0, 3.88, 6.8))
	_tube(k, m, Vector3(0, 2.36, 3.0), Vector3(0, 2.66, 3.25), 0.012, "gunmetal_w", null, 4)
	# skids
	_skids(k, m, 1.15, -3.3, 0.95, [-2.55, 0.25], 0.7, 0.8, 0.05, "gunmetal_w")
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.16, 0.03, 0.34), Vector3(s * 1.15, 0.18, -3.0), "steel", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.05, 0.06, 0.06), Vector3(s * 1.0, 1.2, -4.0), "plain", Color(0.6, 0.1, 0.08) if s < 0 else Color(0.1, 0.5, 0.2), Vector3.ZERO, false)
		k._team_mark(m, team, Vector3(s * 0.29, 2.14, 4.4), Vector3(0.02, 0.18, 0.7))
	# weapon pylons: a minigun inboard, a rocket pod out
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.loft("heli_hc_pyl%d" % int(s), _mx([0.0, -0.45, 1.0, -0.3, 1.0, 0.15, 0.0, 0.3], s), _mx([0.0, -0.4, 1.0, -0.27, 1.0, 0.12, 0.0, 0.25], s), 0.0, 0.1),
			mat, col, Vector3(s * 0.85, 1.05, -1.25))
		k._box(m, Vector3(0.08, 0.16, 0.5), Vector3(s * 1.3, 0.97, -1.3), "gunmetal_w")
		k._box(m, Vector3(0.08, 0.16, 0.7), Vector3(s * 1.78, 0.97, -1.25), "gunmetal_w")
		_rocket_pod(k, m, Vector3(s * 1.78, 0.72, -1.3), 0.17, 1.6, "paint", Color(0.3, 0.32, 0.27), 7)
		if s > 0.0:
			k.turret = k._pivot(m, Vector3(1.3, 0.8, -1.4))
			k.mg_tip = k._tip(k.turret, _minigun(k, k.turret, Vector3.ZERO, 0.72))
		else:
			_minigun(k, m, Vector3(-1.3, 0.8, -1.4), 0.72)
	# the rotor: four BERP blades on the compact hub
	_rotor(k, m, Vector3(0, 3.4, -0.7), 4, 6.4, 0.39, true, PI / 4, 0.018, 0.32, 2)
	k._cyl(k.rotor, 0.22, 0.32, 0.14, Vector3(0, 0.18, 0), Vector3.ZERO, "gunmetal_w", null, 10)


## Flat [x, z, ...] pairs with x scaled by s (mirrors an outline to the left).
static func _mx(a: Array, s: float) -> Array:
	var o := a.duplicate()
	for i in range(0, o.size(), 2):
		o[i] = float(o[i]) * s
	return o


## A faceted canopy of flat panes: a glass loft between two XZ outlines (at
## y0 and y1), framed with bars along its edges in the airframe's paint.
static func _canopy(k: VehicleModels, p: Node3D, key: String, bottom: Array, top: Array, y0: float, y1: float, mat: String, col = null, r := 0.03) -> void:
	k._add(p, VehicleModels.loft(key, bottom, top, y0, y1), "glass", null, Vector3.ZERO)
	var nb := bottom.size() >> 1
	for i in nb:
		var j := (i + 1) % nb
		var b := Vector3(bottom[2 * i], y0, bottom[2 * i + 1])
		var t := Vector3(top[2 * i], y1, top[2 * i + 1])
		var t2 := Vector3(top[2 * j], y1, top[2 * j + 1])
		_tube(k, p, b, t, r, mat, col, 6)
		_tube(k, p, t, t2, r, mat, col, 6)
		k._add(p, Res.sphere(r, 6), mat, col, t)


## A launcher of four anti-tank missile tubes (2 x 2) hanging from pos.
static func _atgm_tubes(k: VehicleModels, p: Node3D, pos: Vector3, ln := 1.9, r := 0.11) -> void:
	k._box(p, Vector3(0.1, 0.16, ln * 0.6), pos + Vector3(0, -0.08, 0), "gunmetal_w")
	k._box(p, Vector3(r * 4.6, 0.05, ln * 0.7), pos + Vector3(0, -0.18, 0), "gunmetal_w")
	for i in 4:
		var x := (r * 1.08) * (-1.0 if i % 2 == 0 else 1.0)
		var y := -0.18 - r * 1.1 - (0.0 if i < 2 else r * 2.15)
		k._cyl(p, r, r, ln, pos + Vector3(x, y, 0), Vector3(PI / 2, 0, 0), "paint", Color(0.33, 0.35, 0.28), 10)
		k._cyl(p, r * 0.8, r * 0.8, 0.02, pos + Vector3(x, y, -ln * 0.5 - 0.01), Vector3(PI / 2, 0, 0), "paint", Color(0.5, 0.48, 0.4), 10, false)
	for z in [-ln * 0.38, ln * 0.38]:
		k._box(p, Vector3(r * 4.7, r * 4.6, 0.05), pos + Vector3(0, -0.18 - r * 2.15, z), "gunmetal_w", null, Vector3.ZERO, false)


# --- Mi-48 Kajman ---------------------------------------------------------------------

## Mi-48 Kajman: the Mi-28's stepped tandem cockpit of flat armoured panes
## on a Mi-24-style fuselage with its troop cabin and split doors, the
## Ka-50/52's coaxial rotors (three blades each, turning against each other,
## no tail rotor), twin engines with exhaust deflectors, stub wings with six
## pylons (rocket pods and Ataka tubes) and countermeasure pods at the tips,
## the 30 mm cannon in a chin turret, fixed tailwheel gear.
static func _kajman(k: VehicleModels, team: int) -> void:
	var m := k.root
	var mat := "camo_tank_rebel"
	var col = null
	if team != 1:
		mat = "aircraft"
		col = NATO_GREY
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-8.35, 1.35, 0.12, 0.12, 0.12],
		[-8.0, 1.38, 0.5, 0.45, 0.48],
		[-7.2, 1.42, 0.62, 0.6, 0.6],
		[-6.2, 1.45, 0.68, 0.68, 0.62],
		[-5.3, 1.5, 0.74, 0.82, 0.66],
		[-4.4, 1.55, 0.84, 0.95, 0.72],
		[-3.6, 1.6, 0.96, 1.0, 0.8],
		[0.6, 1.65, 0.98, 1.0, 0.82],
		[1.6, 1.85, 0.7, 0.78, 0.6],
		[3.0, 2.05, 0.4, 0.42, 0.34],
		[7.6, 2.25, 0.24, 0.26, 0.2],
		[8.4, 2.3, 0.16, 0.2, 0.16],
	], 12, 2.6)
	_hull(k, m, h, "heli_kj_body", mat, col)
	# the stepped cockpits: the gunner low in front, the pilot high behind
	_canopy(k, m, "heli_kj_can1", [-0.6, -7.25, 0.6, -7.25, 0.7, -5.45, -0.7, -5.45], [-0.34, -6.75, 0.34, -6.75, 0.42, -5.5, -0.42, -5.5], 1.95, 2.55, mat, col, 0.035)
	_canopy(k, m, "heli_kj_can2", [-0.72, -5.55, 0.72, -5.55, 0.84, -3.75, -0.84, -3.75], [-0.4, -5.1, 0.4, -5.1, 0.5, -3.8, -0.5, -3.8], 2.3, 3.05, mat, col, 0.035)
	k._add(m, VehicleModels.loft("heli_kj_spine", [-0.84, -3.8, 0.84, -3.8, 0.75, -2.9, -0.75, -2.9], [-0.5, -3.8, 0.5, -3.8, 0.45, -3.0, -0.45, -3.0], 2.5, 3.05), mat, col, Vector3.ZERO)
	# the cabin: split doors with a window in the upper half, side windows
	for z in [-3.25, -1.95]:
		_patch(k, m, h, "heli_kj_dseam%d" % int(-z * 100), z - 0.014, z + 0.014, -2.4, 1.85, "gunmetal_w", null, 0.008)
	_patch(k, m, h, "heli_kj_dsplit", -3.25, -1.95, -0.32, -0.26, "gunmetal_w", null, 0.008)
	_patch(k, m, h, "heli_kj_dwin", -2.95, -2.25, 0.15, 1.0, "glass", null, 0.012)
	for i in 3:
		var zc := -1.35 + i * 0.75
		_patch(k, m, h, "heli_kj_cw%d" % i, zc - 0.2, zc + 0.2, 0.35, 0.95, "glass", null, 0.012)
	# the nose sensors
	k._add(m, Res.sphere(0.3, 12), "paint", Color(0.3, 0.31, 0.29), Vector3(0, 1.05, -7.85))
	k._box(m, Vector3(0.28, 0.16, 0.04), Vector3(0, 1.07, -8.14), "glass", null, Vector3.ZERO, false)
	k._add(m, Res.sphere(0.17, 10), "paint", Color(0.3, 0.31, 0.29), Vector3(0, 1.75, -8.05))
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.3, 1.6, -7.9), Vector3(s * 0.3, 1.58, -8.55), 0.018, "steel", null, 4)
	# top fairing, the engines with their dust filters and exhaust deflectors
	k._add(m, VehicleModels.loft("heli_kj_top", [-0.6, -3.0, 0.6, -3.0, 0.75, -2.3, 0.75, 0.8, 0.45, 1.4, -0.45, 1.4, -0.75, 0.8, -0.75, -2.3],
		[-0.35, -2.6, 0.35, -2.6, 0.48, -2.0, 0.48, 0.4, 0.25, 1.0, -0.25, 1.0, -0.48, 0.4, -0.48, -2.0], 2.5, 3.32), mat, col, Vector3.ZERO)
	var eng := Hull.new([[-3.1, 2.95, 0.3, 0.3, 0.3], [-2.85, 2.95, 0.42, 0.42, 0.42], [0.3, 2.95, 0.42, 0.42, 0.4], [0.75, 2.95, 0.34, 0.34, 0.32]], 10, 2.2)
	for s in [-1.0, 1.0]:
		k._add(m, eng.mesh("heli_kj_eng"), mat, col, Vector3(s * 1.0, 0, 0))
		# the dust protector: a cone ahead of a dark annular intake
		k._cyl(m, 0.4, 0.4, 0.06, Vector3(s * 1.0, 2.95, -3.08), Vector3(PI / 2, 0, 0), "plain", dark, 12, false)
		k._cyl(m, 0.09, 0.36, 0.42, Vector3(s * 1.0, 2.95, -3.3), Vector3(-PI / 2, 0, 0), mat, col, 12)
		_tube(k, m, Vector3(s * 1.0, 2.95, 0.7), Vector3(s * 1.3, 2.75, 1.5), 0.3, mat, col, 10, 0.26)
		k._cyl(m, 0.22, 0.22, 0.03, Vector3(s * 1.3, 2.75, 1.51), Vector3(PI / 2 - 0.25, s * 0.35, 0), "plain", dark, 10, false)
		_tube(k, m, Vector3(s * 0.62, 2.6, -1.0), Vector3(s * 0.7, 2.55, 0.2), 0.04, "gunmetal_w", null, 6)
	# the coaxial mast
	k._cyl(m, 0.17, 0.2, 1.65, Vector3(0, 4.13, -1.4), Vector3.ZERO, "gunmetal_w", null, 10)
	k._cyl(m, 0.36, 0.36, 0.06, Vector3(0, 3.5, -1.4), Vector3.ZERO, "steel", null, 12)
	k._cyl(m, 0.3, 0.3, 0.06, Vector3(0, 4.45, -1.4), Vector3.ZERO, "steel", null, 12)
	# stub wings: anhedral, three pylons a side, flare pods at the tips
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.loft("heli_kj_wing%d" % int(s), _mx([0.0, -2.45, 2.6, -2.15, 2.6, -1.25, 0.0, -0.95], s), _mx([0.0, -2.42, 2.6, -2.12, 2.6, -1.28, 0.0, -0.98], s), -0.07, 0.07),
			mat, col, Vector3(s * 0.85, 2.12, 0), Vector3(0, 0, -s * 0.1))
		k._box(m, Vector3(0.22, 0.26, 1.1), Vector3(s * 3.5, 1.86, -1.7), "gunmetal_w")
		k._box(m, Vector3(0.02, 0.16, 0.5), Vector3(s * 3.62, 1.86, -1.75), "plain", dark, Vector3.ZERO, false)
		for j in 3:
			var px: float = s * (1.6 + j * 0.72)
			var py: float = 2.12 - (absf(px) - 0.85) * 0.1
			k._box(m, Vector3(0.09, 0.2, 0.7), Vector3(px, py - 0.14, -1.7), "gunmetal_w")
			if j < 2:
				_rocket_pod(k, m, Vector3(px, py - 0.5, -1.85), 0.26, 2.0, "paint", Color(0.3, 0.32, 0.27), 19 if j == 0 else 7)
			else:
				_atgm_tubes(k, m, Vector3(px, py - 0.22, -1.75))
		# main gear on trailing legs
		_tube(k, m, Vector3(s * 0.8, 1.0, -3.65), Vector3(s * 1.32, 0.48, -3.2), 0.07, "gunmetal_w", null, 8)
		_tube(k, m, Vector3(s * 0.85, 1.55, -3.4), Vector3(s * 1.3, 0.55, -3.22), 0.06, "steel", null, 8)
		k._wheel(m, Vector3(s * 1.38, 0.42, -3.2), 0.42, 0.28)
		k._box(m, Vector3(0.05, 0.06, 0.06), Vector3(s * 3.62, 2.02, -1.3), "plain", Color(0.6, 0.1, 0.08) if s < 0 else Color(0.1, 0.5, 0.2), Vector3.ZERO, false)
		k._team_mark(m, team, Vector3(s * 0.33, 2.15, 4.6), Vector3(0.02, 0.2, 0.8))
	# the tail: a swept fin, the stabiliser with endplate fins, the tailwheel
	k._add(m, VehicleModels.extrude_x("heli_kj_fin", [6.6, 2.3, 8.3, 2.25, 8.75, 4.0, 8.15, 4.05], -0.08, 0.08), mat, col, Vector3.ZERO)
	k._box(m, Vector3(3.3, 0.07, 0.8), Vector3(0, 2.42, 7.55), mat, col)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("heli_kj_endp", [7.05, 1.95, 7.95, 1.95, 8.2, 2.95, 7.5, 2.95], -0.03, 0.03), mat, col, Vector3(s * 1.65, 0, 0))
	k._add(m, Res.sphere(0.05, 8), "plain", Color(0.55, 0.08, 0.06), Vector3(0, 4.07, 8.4))
	_tube(k, m, Vector3(0, 1.95, 6.8), Vector3(0, 0.38, 7.1), 0.05, "gunmetal_w", null, 8)
	k._box(m, Vector3(0.2, 0.07, 0.18), Vector3(0, 0.42, 7.12), "gunmetal_w")
	k._wheel(m, Vector3(0, 0.25, 7.16), 0.25, 0.16)
	_tube(k, m, Vector3(0, 2.5, 2.4), Vector3(0, 2.85, 2.7), 0.014, "gunmetal_w", null, 4)
	# the chin turret: 2A42 30 mm with its ammunition boxes either side
	k.turret = k._pivot(m, Vector3(0, 0.9, -6.75))
	k._cyl(k.turret, 0.26, 0.3, 0.16, Vector3.ZERO, Vector3.ZERO, mat, col, 12)
	k._box(k.turret, Vector3(0.2, 0.3, 0.3), Vector3(0, -0.2, 0), "gunmetal_w")
	k._box(k.turret, Vector3(0.24, 0.24, 0.9), Vector3(0, -0.36, -0.2), "gunmetal_w")
	for s in [-1.0, 1.0]:
		k._box(k.turret, Vector3(0.2, 0.3, 0.7), Vector3(s * 0.25, -0.34, 0.05), mat, col)
	k._cyl(k.turret, 0.05, 0.05, 1.7, Vector3(0, -0.36, -1.45), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._cyl(k.turret, 0.07, 0.07, 0.4, Vector3(0, -0.36, -0.82), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._cyl(k.turret, 0.075, 0.075, 0.18, Vector3(0, -0.36, -2.32), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k.mg_tip = k._tip(k.turret, Vector3(0, -0.36, -2.45))
	# the coaxial rotors: three blades each, the upper one turning the other way
	_rotor(k, m, Vector3(0, 3.92, -1.4), 3, 7.25, 0.5, true, 0.0, 0.016, 0.36, 1)
	var up := _rotor(k, m, Vector3(0, 4.95, -1.4), 3, 7.25, 0.5, false, PI / 3, 0.01, 0.36, 1)
	k._cyl(up, 0.18, 0.34, 0.24, Vector3(0, 0.22, 0), Vector3.ZERO, mat, col, 10)


# --- PO-30 Orca -----------------------------------------------------------------------

## PO-30 Orca, the Ka-60 Kasatka: a sleek, rounded fuselage with a pointed
## nose under a big windscreen, sliding doors both sides, the twin engines
## under a smooth roof fairing, the slim boom running into a fenestron with
## a fin over it and the tailplane ahead of it, a four-blade rotor, tricycle
## wheels. armed: a minigun on the left pylon, a rocket pod on the right.
static func _orca(k: VehicleModels, team: int, armed: bool) -> void:
	var m := k.root
	var mat := "aircraft"
	var col = CSAT_SAND
	if team == 1 and armed:
		mat = "camo_tank_rebel"
		col = null
	elif team != 1:
		col = NATO_GREY
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-5.6, 1.25, 0.06, 0.06, 0.08],
		[-5.3, 1.27, 0.45, 0.4, 0.45],
		[-4.7, 1.32, 0.8, 0.7, 0.7],
		[-3.9, 1.4, 0.95, 0.85, 0.8],
		[0.2, 1.45, 0.98, 0.85, 0.82],
		[1.3, 1.65, 0.72, 0.66, 0.55],
		[2.6, 1.85, 0.36, 0.36, 0.3],
		[6.2, 1.92, 0.22, 0.24, 0.2],
	], 14, 2.3)
	_hull(k, m, h, "heli_or_body", mat, col)
	# the windscreen, chin windows, cockpit door windows
	_patch(k, m, h, "heli_or_wind", -5.12, -3.85, 0.8, 6.2, "glass", null, 0.012, 0.05, 1.0)
	_patch(k, m, h, "heli_or_post", -5.12, -3.85, 3.45, 3.55, mat, col, 0.022, 0.02, 1.0)
	_patch(k, m, h, "heli_or_chin", -5.05, -4.2, -2.5, -1.45, "glass", null, 0.012, 0.05)
	_patch(k, m, h, "heli_or_side", -3.75, -2.75, -0.3, 2.2, "glass", null, 0.012, 0.05)
	# the sliding doors and a window behind them
	for z in [-3.8, -2.6, -0.65]:
		_patch(k, m, h, "heli_or_seam%d" % int(-z * 100), z - 0.014, z + 0.014, -2.6, 2.4, "gunmetal_w", null, 0.008)
	_patch(k, m, h, "heli_or_dwin", -2.3, -1.0, 0.3, 1.85, "glass", null, 0.012)
	_patch(k, m, h, "heli_or_rwin", -0.42, 0.15, 0.45, 1.7, "glass", null, 0.012)
	_patch(k, m, h, "heli_or_rail", -2.65, 0.6, 2.35, 2.45, "gunmetal_w", null, 0.014)
	# the roof fairing with the engine intakes and exhausts
	k._add(m, VehicleModels.loft("heli_or_roof", [-0.62, -3.6, 0.62, -3.6, 0.85, -2.6, 0.85, 1.0, 0.5, 2.1, -0.5, 2.1, -0.85, 1.0, -0.85, -2.6],
		[-0.3, -3.0, 0.3, -3.0, 0.56, -2.2, 0.56, 0.7, 0.28, 1.6, -0.28, 1.6, -0.56, 0.7, -0.56, -2.2], 2.08, 2.86), mat, col, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.loft("heli_or_intk", [-0.17, 0.0, 0.17, 0.0, 0.17, 0.7, -0.17, 0.7], [-0.13, 0.08, 0.13, 0.08, 0.13, 0.7, -0.13, 0.7], 0.0, 0.32), mat, col, Vector3(s * 0.72, 2.4, -2.5))
		k._box(m, Vector3(0.24, 0.24, 0.03), Vector3(s * 0.72, 2.56, -2.5), "plain", dark, Vector3.ZERO, false)
		_tube(k, m, Vector3(s * 0.5, 2.48, 1.2), Vector3(s * 0.85, 2.45, 1.6), 0.15, "gunmetal_w", null, 10, 0.13)
		k._box(m, Vector3(0.05, 0.06, 0.06), Vector3(s * 0.96, 1.3, -3.6), "plain", Color(0.6, 0.1, 0.08) if s < 0 else Color(0.1, 0.5, 0.2), Vector3.ZERO, false)
		k._team_mark(m, team, Vector3(s * 0.27, 1.9, 4.6), Vector3(0.02, 0.18, 0.7))
	k._cyl(m, 0.13, 0.17, 0.48, Vector3(0, 3.06, -1.0), Vector3.ZERO, "gunmetal_w", null, 10)
	k._cyl(m, 0.3, 0.3, 0.05, Vector3(0, 2.95, -1.0), Vector3.ZERO, "steel", null, 12)
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.28, 1.45, -5.2), Vector3(s * 0.28, 1.43, -5.75), 0.015, "steel", null, 4)
	k._add(m, Res.sphere(0.06, 8), "plain", Color(0.55, 0.08, 0.06), Vector3(0, 2.88, 0.9))
	_tube(k, m, Vector3(0, 2.15, 2.6), Vector3(0, 2.45, 2.85), 0.012, "gunmetal_w", null, 4)
	# the fenestron: shroud with its open duct, the fin, the tailplane
	_ducted_fin(k, m, "heli_or_duct", [6.05, 1.45, 6.4, 1.15, 7.55, 1.15, 7.9, 1.5, 7.9, 2.3, 7.55, 2.65, 6.4, 2.65, 6.05, 2.35],
		Vector2(6.98, 1.9), 0.58, -0.17, 0.17, mat, col, 16)
	_fan(k, m, Vector3(0, 1.9, 6.98), 11, 0.56, 0.11)
	for a in [0.6, 2.4, 4.2]:
		k._box(m, Vector3(0.03, 0.52, 0.07), Vector3(-0.09, 1.9 + sin(a) * 0.3, 6.98 + cos(a) * 0.3), "gunmetal_w", null, Vector3(-a + PI / 2, 0, 0), false)
	k._add(m, VehicleModels.extrude_x("heli_or_fin", [6.7, 2.6, 7.85, 2.6, 8.05, 3.6, 7.45, 3.62], -0.07, 0.07), mat, col, Vector3.ZERO)
	k._box(m, Vector3(2.5, 0.06, 0.55), Vector3(0, 1.98, 5.45), mat, col)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("heli_or_endp", [5.15, 1.75, 5.72, 1.75, 5.85, 2.3, 5.42, 2.3], -0.02, 0.02), mat, col, Vector3(s * 1.25, 0, 0))
	# tricycle wheels: the nosewheel, mains in their fairings
	_gear(k, m, Vector3(0, 0.7, -4.15), Vector3(0, 0.26, -4.3), 0.26, 0.16)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.loft("heli_or_spon%d" % int(s), _mx([0.75, -0.3, 1.15, -0.1, 1.15, 1.0, 0.75, 1.2], s), _mx([0.75, -0.1, 1.05, 0.0, 1.05, 0.85, 0.75, 1.0], s), 0.62, 1.08), mat, col, Vector3.ZERO)
		_gear(k, m, Vector3(s * 1.0, 0.7, 0.4), Vector3(s * 1.15, 0.3, 0.45), 0.3, 0.18)
		k._box(m, Vector3(0.14, 0.04, 0.3), Vector3(s * 1.0, 0.55, -2.0), "gunmetal_w")
	if armed:
		# side pylons: a minigun on the left, a rocket pod on the right
		for s in [-1.0, 1.0]:
			k._add(m, VehicleModels.loft("heli_or_pyl%d" % int(s), _mx([0.0, -0.45, 0.85, -0.3, 0.85, 0.2, 0.0, 0.35], s), _mx([0.0, -0.4, 0.85, -0.27, 0.85, 0.17, 0.0, 0.3], s), 0.0, 0.1),
				mat, col, Vector3(s * 0.8, 1.08, 0.0))
			k._box(m, Vector3(0.08, 0.16, 0.62), Vector3(s * 1.5, 1.0, -0.05), "gunmetal_w")
		_rocket_pod(k, m, Vector3(1.5, 0.74, -0.15), 0.2, 1.6, "paint", Color(0.3, 0.32, 0.27), 19)
		k.turret = k._pivot(m, Vector3(-1.5, 0.82, -0.1))
		k._cyl(k.turret, 0.16, 0.16, 0.9, Vector3(0, 0, 0.25), Vector3(PI / 2, 0, 0), "paint", Color(0.3, 0.32, 0.27), 12)
		k._add(k.turret, Res.sphere(0.16, 12), "paint", Color(0.3, 0.32, 0.27), Vector3(0, 0, 0.7), Vector3.ZERO, Vector3(1, 1, 0.8))
		k.mg_tip = k._tip(k.turret, _minigun(k, k.turret, Vector3(0, 0, -0.2), 0.6))
	# the rotor: four blades with swept tips
	_rotor(k, m, Vector3(0, 3.36, -1.0), 4, 6.75, 0.4, true, PI / 4, 0.018, 0.32, 1)
	k._cyl(k.rotor, 0.2, 0.36, 0.2, Vector3(0, 0.2, 0), Vector3.ZERO, mat, col, 10)


# --- Mi-290 Taru ----------------------------------------------------------------------

## Mi-290 Taru: a CH-54 Tarhe's skeletal sky-crane - a glazed cab hung off
## the front of a narrow spine, four long legs splayed out to the wheels -
## under a Ka-226's coaxial rotors (no tail rotor; a twin-finned tailplane),
## two engines on the spine, the transport pod slung underneath on its
## hooks.
static func _taru(k: VehicleModels, team: int) -> void:
	var m := k.root
	var mat := "camo_tank_rebel"
	var col = null
	if team != 1:
		mat = "aircraft"
		col = NATO_GREY
	var dark := Color(0.06, 0.06, 0.06)
	# the spine
	var sp := Hull.new([
		[-5.7, 3.45, 0.6, 0.55, 0.58],
		[-4.2, 3.45, 0.66, 0.62, 0.6],
		[1.6, 3.45, 0.66, 0.62, 0.6],
		[4.0, 3.5, 0.5, 0.48, 0.42],
		[7.7, 3.6, 0.28, 0.3, 0.25],
		[8.5, 3.62, 0.2, 0.22, 0.18],
	], 8, 3.0, PI / 8)
	_hull(k, m, sp, "heli_ta_spine", mat, col)
	_patch(k, m, sp, "heli_ta_keel", -4.0, 4.5, 5.35, 5.65, "gunmetal_w", null, 0.012, 0.03, 1.0)
	# the cab, glazed all round its nose
	var cab := Hull.new([
		[-8.3, 3.0, 0.1, 0.1, 0.1],
		[-8.05, 3.0, 0.68, 0.6, 0.6],
		[-7.45, 3.05, 0.98, 0.86, 0.84],
		[-6.2, 3.12, 1.04, 0.9, 0.88],
		[-5.3, 3.2, 0.95, 0.82, 0.76],
		[-4.7, 3.3, 0.7, 0.68, 0.5],
	], 14, 2.2)
	_hull(k, m, cab, "heli_ta_cab", mat, col)
	_patch(k, m, cab, "heli_ta_wind", -8.3, -6.55, -0.7, 7.7, "glass", null, 0.012, 0.05, 1.0)
	_patch(k, m, cab, "heli_ta_chin", -8.2, -6.6, -2.9, -1.3, "glass", null, 0.012, 0.05)
	for t in [1.7, 3.5, 5.3]:
		_patch(k, m, cab, "heli_ta_post%d" % int(t * 10), -8.25, -6.55, t - 0.07, t + 0.07, mat, col, 0.022, 0.02, 1.0)
	_patch(k, m, cab, "heli_ta_cpost", -8.2, -6.6, -2.15, -2.05, mat, col, 0.022, 0.02)
	_patch(k, m, cab, "heli_ta_bow", -6.65, -6.5, -3.2, 10.2, mat, col, 0.026, 0.03, 1.0)
	_patch(k, m, cab, "heli_ta_side", -6.3, -5.35, -0.6, 2.4, "glass", null, 0.012, 0.05)
	_patch(k, m, cab, "heli_ta_dseam", -6.42, -6.38, -2.4, 2.6, "gunmetal_w", null, 0.01)
	k._box(m, Vector3(0.9, 0.5, 0.04), Vector3(0, 2.75, -4.85), "glass", null, Vector3(0.5, 0, 0), false)
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.35, 3.0, -8.1), Vector3(s * 0.35, 2.98, -8.7), 0.018, "steel", null, 4)
		k._box(m, Vector3(0.14, 0.04, 0.3), Vector3(s * 0.95, 2.28, -5.8), "gunmetal_w")
	# the engines and the gearbox fairing on the spine
	k._add(m, VehicleModels.loft("heli_ta_top", [-0.55, -4.4, 0.55, -4.4, 0.62, -3.6, 0.62, 0.8, 0.4, 1.4, -0.4, 1.4, -0.62, 0.8, -0.62, -3.6],
		[-0.3, -3.9, 0.3, -3.9, 0.4, -3.2, 0.4, 0.4, 0.22, 0.95, -0.22, 0.95, -0.4, 0.4, -0.4, -3.2], 3.95, 4.62), mat, col, Vector3.ZERO)
	var eng := Hull.new([[-3.7, 4.36, 0.26, 0.26, 0.26], [-3.45, 4.36, 0.36, 0.36, 0.36], [-0.7, 4.36, 0.36, 0.36, 0.36], [-0.2, 4.36, 0.27, 0.27, 0.27]], 10, 2.2)
	for s in [-1.0, 1.0]:
		k._add(m, eng.mesh("heli_ta_eng"), mat, col, Vector3(s * 0.66, 0, 0))
		k._cyl(m, 0.24, 0.24, 0.04, Vector3(s * 0.66, 4.36, -3.71), Vector3(PI / 2, 0, 0), "plain", dark, 10, false)
		k._cyl(m, 0.1, 0.1, 0.06, Vector3(s * 0.66, 4.36, -3.73), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
		_tube(k, m, Vector3(s * 0.66, 4.36, -0.25), Vector3(s * 0.95, 4.42, 0.25), 0.2, "gunmetal_w", null, 10, 0.17)
		k._team_mark(m, team, Vector3(s * 0.4, 3.62, 5.6), Vector3(0.02, 0.24, 0.9))
	k._cyl(m, 0.17, 0.2, 1.5, Vector3(0, 5.3, -1.0), Vector3.ZERO, "gunmetal_w", null, 10)
	k._cyl(m, 0.34, 0.34, 0.06, Vector3(0, 4.66, -1.0), Vector3.ZERO, "steel", null, 12)
	k._add(m, Res.sphere(0.07, 8), "plain", Color(0.55, 0.08, 0.06), Vector3(0, 4.08, 2.6))
	_tube(k, m, Vector3(0, 4.0, 3.4), Vector3(0, 4.35, 3.7), 0.012, "gunmetal_w", null, 4)
	# the tailplane with its twin fins, a ventral fin
	k._box(m, Vector3(3.1, 0.07, 0.8), Vector3(0, 3.62, 8.0), mat, col)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("heli_ta_fin", [7.5, 3.15, 8.4, 3.15, 8.62, 4.35, 7.95, 4.35], -0.035, 0.035), mat, col, Vector3(s * 1.55, 0, 0))
	k._add(m, VehicleModels.extrude_x("heli_ta_vent", [7.6, 3.45, 8.45, 3.45, 8.6, 2.95, 8.1, 2.9], -0.04, 0.04), mat, col, Vector3.ZERO)
	# the legs: long oleo struts splayed out from the spine, braced
	for s in [-1.0, 1.0]:
		for lz in [[-4.25, -4.55, 2.45], [3.7, 4.3, 2.6]]:
			var top := Vector3(s * 0.55, 3.05, float(lz[0]))
			var axle := Vector3(s * float(lz[2]), 0.42, float(lz[1]))
			var knee := top.lerp(axle, 0.62)
			_tube(k, m, top, knee, 0.085, "gunmetal_w", null, 8)
			_tube(k, m, knee, axle + Vector3(0, 0.25, 0), 0.06, "steel", null, 8)
			_tube(k, m, knee - (knee - top) * 0.15, knee, 0.11, "gunmetal_w", null, 8)
			_tube(k, m, Vector3(s * 0.3, 2.9, float(lz[0]) + (0.9 if float(lz[0]) < 0.0 else -0.9)), top.lerp(axle, 0.45), 0.05, "gunmetal_w", null, 6)
			_tube(k, m, Vector3(s * 0.45, 2.88, float(lz[0])), knee, 0.04, "gunmetal_w", null, 6)
			k._box(m, Vector3(0.1, 0.12, 0.38), axle + Vector3(-s * 0.05, 0.28, 0), "gunmetal_w")
			k._wheel(m, axle, 0.42, 0.3)
	# the transport pod on its four hooks
	var pod := Hull.new([
		[-3.45, 1.6, 1.0, 0.8, 0.8],
		[-3.2, 1.6, 1.25, 1.0, 1.0],
		[2.95, 1.6, 1.25, 1.0, 1.0],
		[3.2, 1.6, 1.05, 0.85, 0.85],
	], 8, 6.0, PI / 8)
	_hull(k, m, pod, "heli_ta_pod", mat, col)
	for i in 4:
		var zc := -2.4 + i * 1.6
		_patch(k, m, pod, "heli_ta_pw%d" % i, zc - 0.25, zc + 0.25, -0.33, -0.05, "glass", null, 0.012)
	for z in [-0.6, 0.45]:
		_patch(k, m, pod, "heli_ta_pdoor%d" % int(z * 10 + 10), z - 0.014, z + 0.014, -0.95, 0.75, "gunmetal_w", null, 0.008, 0.03, -1.0)
	_patch(k, m, pod, "heli_ta_pdwin", -0.4, 0.25, -0.35, -0.08, "glass", null, 0.012, 0.03, -1.0)
	k._box(m, Vector3(2.2, 1.7, 0.03), Vector3(0, 1.6, 3.21), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(2.1, 1.6, 0.04), Vector3(0, 1.6, 3.22), mat, col, Vector3.ZERO, false)
	k._box(m, Vector3(0.03, 1.6, 0.05), Vector3(0, 1.6, 3.25), "gunmetal_w", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.05, 0.4), Vector3(s * 1.27, 0.95, -0.1), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.24, 0.04, 0.5), Vector3(s * 1.3, 0.62, -0.1), "gunmetal_w")
		for z in [-2.6, 2.4]:
			_tube(k, m, Vector3(s * 0.4, 2.6, z), Vector3(s * 0.3, 2.95, z), 0.05, "gunmetal_w", null, 6)
			k._box(m, Vector3(0.3, 0.08, 0.3), Vector3(s * 0.4, 2.62, z), "gunmetal_w")
	k._box(m, Vector3(0.9, 0.05, 6.0), Vector3(0, 2.62, -0.1), "gunmetal_w")
	# the coaxial rotors: three blades each, turning against each other
	_rotor(k, m, Vector3(0, 4.98, -1.0), 3, 7.5, 0.48, true, 0.0, 0.02, 0.36, 0)
	var up := _rotor(k, m, Vector3(0, 6.08, -1.0), 3, 7.5, 0.48, false, PI / 3, 0.012, 0.36, 0)
	k._cyl(up, 0.16, 0.32, 0.22, Vector3(0, 0.2, 0), Vector3.ZERO, mat, col, 10)


# --- MQ-12 Falcon ---------------------------------------------------------------------

## MQ-12 Falcon, the MQ-8 Fire Scout: an unmanned Schweizer - a windowless
## teardrop of a pod on skids, the sensor ball under its nose, the engine
## fairing and exhaust on its back, a thin boom with fins, a two-blade tail
## rotor, the four-blade rotor, stub wings with four small missiles.
static func _falcon(k: VehicleModels, team: int) -> void:
	var m := k.root
	var pc := _air(team, NATO_GREY)
	var mat: String = pc[0]
	var col = pc[1]
	var dark := Color(0.06, 0.06, 0.06)
	var h := Hull.new([
		[-2.9, 1.26, 0.16, 0.15, 0.15],
		[-2.78, 1.27, 0.4, 0.37, 0.36],
		[-2.45, 1.31, 0.55, 0.52, 0.5],
		[-1.6, 1.36, 0.64, 0.62, 0.6],
		[-0.6, 1.38, 0.65, 0.64, 0.6],
		[0.3, 1.42, 0.58, 0.6, 0.52],
		[1.0, 1.5, 0.38, 0.42, 0.32],
		[1.5, 1.58, 0.18, 0.2, 0.16],
	], 14, 2.1)
	_hull(k, m, h, "heli_fa_body", mat, col)
	# panel seams and access hatches (no windows: nobody aboard)
	for z in [-2.2, -1.05, 0.25]:
		_patch(k, m, h, "heli_fa_seam%d" % int(z * 100 + 300), z - 0.012, z + 0.012, -3.4, 10.4, "gunmetal_w", null, 0.006, 0.03, 1.0)
	_patch(k, m, h, "heli_fa_hatch", -0.9, -0.2, -0.6, 1.4, mat, (col as Color).darkened(0.08) if col is Color else null, 0.008)
	_patch(k, m, h, "heli_fa_nose", -2.9, -2.45, -3.4, 10.4, mat, (col as Color).darkened(0.12) if col is Color else null, 0.006, 0.03, 1.0)
	# the engine fairing on the back, its intake and exhaust; the mast
	k._add(m, VehicleModels.loft("heli_fa_eng", [-0.32, -1.2, 0.32, -1.2, 0.36, 0.7, 0.2, 1.15, -0.2, 1.15, -0.36, 0.7],
		[-0.18, -0.9, 0.18, -0.9, 0.22, 0.5, 0.1, 0.9, -0.1, 0.9, -0.22, 0.5], 1.9, 2.3), mat, col, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.03, 0.12, 0.3), Vector3(s * 0.27, 2.1, -0.15), "plain", dark, Vector3(0, 0, s * 0.3), false)
	_tube(k, m, Vector3(0, 2.12, 0.85), Vector3(0, 2.2, 1.25), 0.09, "gunmetal_w", null, 10, 0.08)
	k._cyl(m, 0.08, 0.1, 0.36, Vector3(0, 2.42, -0.5), Vector3.ZERO, "gunmetal_w", null, 10)
	k._cyl(m, 0.17, 0.17, 0.04, Vector3(0, 2.35, -0.5), Vector3.ZERO, "steel", null, 12)
	# the boom, fins, stabiliser, the tail rotor on the left
	_tube(k, m, Vector3(0, 1.58, 1.3), Vector3(0, 1.7, 4.35), 0.13, mat, col, 10, 0.07)
	k._add(m, Res.sphere(0.07, 8), mat, col, Vector3(0, 1.7, 4.35))
	k._add(m, VehicleModels.extrude_x("heli_fa_fin", [3.8, 1.72, 4.3, 1.72, 4.48, 2.35, 4.2, 2.36], -0.025, 0.025), mat, col, Vector3.ZERO)
	k._add(m, VehicleModels.extrude_x("heli_fa_vent", [3.9, 1.66, 4.3, 1.66, 4.45, 1.2, 4.28, 1.18], -0.025, 0.025), mat, col, Vector3.ZERO)
	k._box(m, Vector3(1.15, 0.035, 0.3), Vector3(0, 1.7, 3.55), mat, col)
	_tail_rotor(k, m, Vector3(-0.08, 1.72, 4.3), 2, 0.62, 0.09, -1.0)
	# the sensor ball under the nose, antennas, the datalink dome
	k._box(m, Vector3(0.12, 0.14, 0.12), Vector3(0, 0.82, -2.15), "gunmetal_w")
	k._add(m, Res.sphere(0.18, 14), "paint", Color(0.28, 0.29, 0.3), Vector3(0, 0.66, -2.15))
	k._box(m, Vector3(0.16, 0.1, 0.03), Vector3(0, 0.66, -2.33), "glass", null, Vector3.ZERO, false)
	k._add(m, Res.dome(0.16, 10), mat, col, Vector3(0, 1.98, -1.6))
	k._box(m, Vector3(0.025, 0.18, 0.18), Vector3(0, 0.66, 0.0), "gunmetal_w")
	_tube(k, m, Vector3(0, 1.82, 2.4), Vector3(0, 2.05, 2.55), 0.01, "gunmetal_w", null, 4)
	k._add(m, Res.sphere(0.035, 8), "plain", Color(0.55, 0.08, 0.06), Vector3(0, 2.38, 4.22))
	# skids
	_skids(k, m, 0.82, -1.55, 0.85, [-1.1, 0.4], 0.42, 0.8, 0.035, "gunmetal_w")
	# stub wings with two pylons a side, a small missile on each
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.75, 0.05, 0.42), Vector3(s * 0.95, 1.12, -0.7), mat, col, Vector3(0, 0, -s * 0.05))
		for j in 2:
			var px: float = s * (0.82 + j * 0.36)
			k._box(m, Vector3(0.04, 0.1, 0.3), Vector3(px, 1.05, -0.7), "gunmetal_w")
			_missile(k, m, Vector3(px, 0.94, -0.75), 0.055, 1.1, Color(0.32, 0.34, 0.29))
		k._team_mark(m, team, Vector3(s * 0.11, 1.62, 2.5), Vector3(0.02, 0.1, 0.5))
	# the rotor: four blades
	_rotor(k, m, Vector3(0, 2.64, -0.5), 4, 4.2, 0.2, true, PI / 4, 0.012, 0.18, 0)


# --- rotary drones --------------------------------------------------------------------

## A drone's propeller at pos (radius r, nb blades) on k.rotors: the spinner
## stays, the blades sit in "Blades" (shown slow), a "Blur" disc (fast).
static func _prop(k: VehicleModels, p: Node3D, pos: Vector3, r: float, nb := 2, phase := 0.0, col := Color(0.11, 0.11, 0.11)) -> Node3D:
	var rp := k._pivot(p, pos)
	var bl := k._pivot(rp, Vector3.ZERO)
	bl.name = "Blades"
	k._cyl(rp, r * 0.1, r * 0.14, r * 0.14, Vector3(0, r * 0.05, 0), Vector3.ZERO, "gunmetal_w", null, 8)
	for i in nb:
		var bs := Basis.from_euler(Vector3(0, phase + TAU * float(i) / float(nb), 0))
		_rbox(k, bl, bs, Vector3(r * 0.17, r * 0.045, r * 0.55), Vector3(0, r * 0.07, r * 0.36), "plain", col, Vector3(0, 0, 0.3))
		_rbox(k, bl, bs, Vector3(r * 0.13, r * 0.04, r * 0.36), Vector3(r * 0.015, r * 0.07, r * 0.8), "plain", col, Vector3(0, 0.08, 0.22))
	if not k.burnt:
		var blur := MeshInstance3D.new()
		blur.name = "Blur"
		var disc := PlaneMesh.new()
		disc.size = Vector2(r, r) * 2.0
		blur.mesh = disc
		blur.material_override = VehicleModels._blur_mat()
		blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blur.position = Vector3(0, r * 0.08, 0)
		blur.visible = false
		rp.add_child(blur)
	k.rotors.append(rp)
	return rp


## AR-2 Darter: a palm-sized quadcopter, 0.9 m across - a small fuselage on
## an X of arms, each rotor inside its guard ring, a camera on a gimbal under
## the nose, two little skids.
static func _darter(k: VehicleModels, team: int) -> void:
	var m := k.root
	var mat := "aircraft"
	var col: Color = Color(0.36, 0.37, 0.32) if team != 1 else CSAT_SAND
	var dark := Color(0.08, 0.08, 0.08)
	var h := Hull.new([
		[-0.19, 0.2, 0.05, 0.025, 0.03],
		[-0.13, 0.2, 0.1, 0.055, 0.05],
		[0.1, 0.205, 0.11, 0.06, 0.05],
		[0.18, 0.21, 0.07, 0.04, 0.035],
	], 10, 2.4)
	_hull(k, m, h, "heli_da_body", mat, col)
	_patch(k, m, h, "heli_da_stripe", -0.19, -0.13, 1.2, 3.8, "plain", dark, 0.003, 0.01, 1.0)
	k._box(m, Vector3(0.1, 0.028, 0.15), Vector3(0, 0.27, 0.03), "plain", Color(0.15, 0.15, 0.15))
	_tube(k, m, Vector3(0.03, 0.28, 0.12), Vector3(0.03, 0.36, 0.15), 0.004, "gunmetal_w", null, 4)
	# the X of arms, a motor and guard ring at each end
	var order := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in 4:
		var d: Vector2 = order[i]
		var mp := Vector3(d.x * 0.29, 0.22, d.y * 0.29)
		var ab := Vector3(d.x * 0.06, 0.215, d.y * 0.06)
		_tube(k, m, ab, mp, 0.016, mat, col, 6)
		k._box(m, Vector3(0.05, 0.02, 0.24), (ab + mp) * 0.5 + Vector3(0, -0.012, 0), mat, col, Vector3(0, atan2(d.x, d.y), 0))
		k._cyl(m, 0.03, 0.03, 0.05, mp + Vector3(0, 0.015, 0), Vector3.ZERO, "gunmetal_w", null, 10)
		k._add(m, Res.torus(0.17, 0.19), mat, col, mp + Vector3(0, 0.05, 0))
		for j in 3:
			var a := atan2(d.y, d.x) + PI + (float(j) - 1.0) * 0.9
			var e := mp + Vector3(cos(a) * 0.17, 0.045, sin(a) * 0.17)
			_tube(k, m, mp + Vector3(0, 0.02, 0), e, 0.006, mat, col, 4)
		# lights: green on the right, red on the left, white aft
		var lc := Color(0.1, 0.5, 0.2) if d.x > 0.0 else Color(0.6, 0.1, 0.08)
		if d.y > 0.0:
			lc = Color(0.8, 0.8, 0.75)
		k._box(m, Vector3(0.02, 0.012, 0.02), mp + Vector3(0, -0.018, 0), "plain", lc, Vector3.ZERO, false)
		_prop(k, m, mp + Vector3(0, 0.05, 0), 0.155, 2, float(i) * 0.7)
	# the camera on its gimbal under the nose
	k._box(m, Vector3(0.05, 0.03, 0.04), Vector3(0, 0.15, -0.12), "gunmetal_w")
	k._add(m, Res.sphere(0.036, 10), "plain", Color(0.15, 0.15, 0.15), Vector3(0, 0.12, -0.13))
	k._cyl(m, 0.018, 0.018, 0.01, Vector3(0, 0.12, -0.165), Vector3(PI / 2, 0, 0), "glass", null, 10, false)
	# skids
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.06, 0.16, -0.06), Vector3(s * 0.12, 0.012, -0.08), 0.006, "gunmetal_w", null, 4)
		_tube(k, m, Vector3(s * 0.06, 0.16, 0.08), Vector3(s * 0.12, 0.012, 0.1), 0.006, "gunmetal_w", null, 4)
		_tube(k, m, Vector3(s * 0.12, 0.012, -0.16), Vector3(s * 0.12, 0.012, 0.16), 0.008, "rubber", null, 4)


## A hexacopter, about 1.5 m across: a round hub with a dome over the
## electronics, six carbon arms with a motor and two-blade prop at each end,
## two skids. demining: white, with a rack of demolition charges and a
## ground-scanning sensor under it; else (utility) a cargo box slung under.
static func _hexa(k: VehicleModels, team: int, demining: bool) -> void:
	var m := k.root
	var mat := "aircraft"
	var col: Color = Color(0.26, 0.27, 0.27) if team != 1 else CSAT_SAND
	if demining:
		col = Color(0.8, 0.8, 0.76)
	var dark := Color(0.08, 0.08, 0.08)
	var carbon := Color(0.12, 0.12, 0.12)
	# the hub: a hexagonal frame, the dome, the battery under it
	k._cyl(m, 0.2, 0.2, 0.025, Vector3(0, 0.3, 0), Vector3.ZERO, "plain", carbon, 6)
	k._cyl(m, 0.2, 0.2, 0.025, Vector3(0, 0.38, 0), Vector3.ZERO, "plain", carbon, 6)
	k._cyl(m, 0.15, 0.17, 0.06, Vector3(0, 0.34, 0), Vector3.ZERO, mat, col, 12)
	k._add(m, Res.dome(0.16, 14), mat, col, Vector3(0, 0.39, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	k._box(m, Vector3(0.14, 0.06, 0.24), Vector3(0, 0.26, 0), "plain", Color(0.18, 0.18, 0.18))
	_tube(k, m, Vector3(0, 0.49, 0.03), Vector3(0, 0.58, 0.03), 0.006, "gunmetal_w", null, 4)
	k._cyl(m, 0.04, 0.04, 0.015, Vector3(0, 0.585, 0.03), Vector3.ZERO, "plain", Color(0.2, 0.2, 0.2), 10)
	# six arms, alternately turning props, orientation colours on the front pair
	for i in 6:
		var a := PI / 6 + float(i) * PI / 3
		var d := Vector3(sin(a), 0, -cos(a))
		var mp := d * 0.56 + Vector3(0, 0.34, 0)
		_tube(k, m, d * 0.15 + Vector3(0, 0.34, 0), mp, 0.016, "plain", carbon, 8)
		k._box(m, Vector3(0.05, 0.035, 0.06), d * 0.17 + Vector3(0, 0.34, 0), "plain", carbon, Vector3(0, atan2(d.x, d.z), 0))
		var front := i == 0 or i == 5
		k._cyl(m, 0.04, 0.042, 0.06, mp + Vector3(0, 0.03, 0), Vector3.ZERO, "plain", Color(0.62, 0.2, 0.1) if front else Color(0.16, 0.16, 0.16), 12)
		k._box(m, Vector3(0.06, 0.02, 0.06), mp + Vector3(0, -0.005, 0), mat, col)
		_prop(k, m, mp + Vector3(0, 0.065, 0), 0.21, 2, float(i) * 0.9)
	# skids on two legs each
	for s in [-1.0, 1.0]:
		for z in [-0.1, 0.1]:
			_tube(k, m, Vector3(s * 0.09, 0.29, z), Vector3(s * 0.22, 0.015, z * 1.6), 0.008, "plain", carbon, 6)
		_tube(k, m, Vector3(s * 0.22, 0.015, -0.24), Vector3(s * 0.22, 0.015, 0.24), 0.011, "plain", carbon, 6)
	if demining:
		# a rack of four demolition charges and the ground-scanning sensor
		k._box(m, Vector3(0.3, 0.02, 0.3), Vector3(0, 0.215, 0), "gunmetal_w")
		for i in 4:
			var cx := -0.08 if i % 2 == 0 else 0.08
			var cz := -0.08 if i < 2 else 0.08
			k._cyl(m, 0.045, 0.045, 0.13, Vector3(cx, 0.14, cz), Vector3.ZERO, "paint", Color(0.72, 0.38, 0.1), 10)
			k._cyl(m, 0.025, 0.025, 0.03, Vector3(cx, 0.06, cz), Vector3.ZERO, "plain", dark, 8)
		k._box(m, Vector3(0.05, 0.05, 0.2), Vector3(0, 0.27, -0.19), "gunmetal_w")
		k._box(m, Vector3(0.12, 0.03, 0.12), Vector3(0, 0.235, -0.33), mat, col)
		k._add(m, Res.sphere(0.035, 10), "plain", Color(0.15, 0.15, 0.15), Vector3(0, 0.2, -0.33))
		k._cyl(m, 0.016, 0.016, 0.01, Vector3(0, 0.2, -0.366), Vector3(PI / 2, 0, 0), "glass", null, 8, false)
		k._box(m, Vector3(0.05, 0.022, 0.08), Vector3(0.1, 0.4, 0.1), "plain", Color(0.15, 0.3, 0.55))
	else:
		# the cargo box on its release hook
		k._box(m, Vector3(0.05, 0.06, 0.05), Vector3(0, 0.205, 0), "gunmetal_w")
		k._box(m, Vector3(0.3, 0.17, 0.34), Vector3(0, 0.1, 0), "canvas", Color(0.36, 0.36, 0.26))
		for x in [-0.08, 0.08]:
			k._box(m, Vector3(0.03, 0.175, 0.345), Vector3(x, 0.1, 0), "plain", Color(0.15, 0.15, 0.13))
		k._box(m, Vector3(0.1, 0.06, 0.005), Vector3(0, 0.12, -0.172), "plain", Color(0.8, 0.78, 0.7), Vector3.ZERO, false)
		k._add(m, Res.sphere(0.03, 8), "plain", Color(0.15, 0.15, 0.15), Vector3(0, 0.29, -0.15))
