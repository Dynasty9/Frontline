class_name VmCore
extends RefCounted
## Procedural models: the core roster - the vehicles every match fields (the
## M1A2 SEP, the T-55A, the Hilux technicals, the M1151, the M2A3 Bradley, the
## BTR-80, the AH-64D and the UH-60) and the fallback convoy truck.
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys unique, "core_" prefixed).
##
## These models stand in for the originals in vehicle_models.gd, so they keep
## those builders' contracts: the same k.turret / k.gun_tip / k.mg_tip per
## key, every road wheel and tyre in k.wheels, the helicopters' rotor, blades,
## blur disc and tail rotor. Footprints stay close to the keys' Defs sizes: the
## Abrams and the Bradley are built a touch under full scale (0.9), the two
## helicopters at 0.65 (as the originals were), the rest at full scale.

## Every model key this file builds.
## ("m35" is the fallback truck on its own, whoever's convoy it is.)
const KEYS: Array[String] = ["tank", "old_tank", "technical", "aa_tech", "humvee", "ifv", "btr", "apc", "gunship", "heli", "truck", "m35"]

const X90 := Vector3(PI / 2, 0, 0)  # a cylinder lying along Z (barrels)
const Z90 := Vector3(0, 0, PI / 2)  # a cylinder lying along X (axles, wheels)
const GUN := Color(0.3, 0.32, 0.24)  # painted gun barrels, thermal sleeves
const OD := Color(0.3, 0.32, 0.22)  # olive drab: ammo cans, jerrycans
const BAG := Color(0.38, 0.37, 0.27)  # canvas bags and covers
const TAN_BAG := Color(0.47, 0.42, 0.31)  # sand-coloured kit


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"tank":
			_abrams(k, team)
		"old_tank":
			_t55(k, team, seed)
		"technical":
			_hilux(k, team, seed, false)
		"aa_tech":
			_hilux(k, team, seed, true)
		"humvee":
			_humvee(k, team)
		"ifv":
			_bradley(k, team)
		"btr", "apc":
			_btr80(k, team)
		"gunship":
			_apache(k, team)
		"heli":
			_blackhawk(k, team)
		"truck":
			# the convoy proper is the HEMTT or the Zamak (as the original did)
			if not ((team == 0 and VmNato.build(k, "hemtt_cargo", team, seed)) or (team == 1 and VmIndep.build(k, "zamak_cargo", team, seed))):
				_truck(k, team)
		"m35":
			_truck(k, team)
		_:
			return false
	return true


# --- shared helpers ------------------------------------------------------------------

static func _cam(team: int) -> String:
	return "camo_tank" if team != 1 else "camo_tank_rebel"


static var _plain := {}


## k._box, but a small part (under 4 cm thick somewhere) gets a plain box:
## its chamfers wouldn't show, and a bevelled box costs four times the
## vertices - these models stand on the battlefield by the dozen.
static func _bx(k: VehicleModels, p: Node3D, s: Vector3, pos: Vector3, mat: String, col = null, rot := Vector3.ZERO, shadow := true) -> Variant:
	if minf(s.x, minf(s.y, s.z)) >= 0.04:
		return k._box(p, s, pos, mat, col, rot, shadow)
	var key := "%.3f,%.3f,%.3f" % [s.x, s.y, s.z]
	if not _plain.has(key):
		var bm := BoxMesh.new()
		bm.size = s
		_plain[key] = bm
	return k._add(p, _plain[key], mat, col, pos, rot, Vector3.ONE, shadow)


## The Euler rotation that turns +Y onto direction d.
static func _aim(d: Vector3) -> Vector3:
	var u := d.normalized()
	if u.dot(Vector3.UP) < -0.9999:
		return Vector3(PI, 0, 0)
	if u.dot(Vector3.UP) > 0.9999:
		return Vector3.ZERO
	return Basis(Quaternion(Vector3.UP, u)).get_euler()


## A round bar from a to b (radius r, or r at a and rb at b).
static func _tube(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, r: float, mat: String, col = null, segs := 8, shadow := true, rb := -1.0) -> Variant:
	return k._cyl(p, rb if rb >= 0.0 else r, r, a.distance_to(b), (a + b) * 0.5, _aim(b - a), mat, col, segs, shadow)


## A tube along a polyline, the joints rounded.
static func _path(k: VehicleModels, p: Node3D, pts: Array, r: float, mat: String, col = null, segs := 8) -> void:
	for i in pts.size() - 1:
		_tube(k, p, pts[i], pts[i + 1], r, mat, col, segs)
		if i > 0:
			k._add(p, Res.sphere(r, segs), mat, col, pts[i])


## A square-section bar from a to b, w across (kept level where it can be), t thick.
static func _bar(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, w: float, t: float, mat: String, col = null, shadow := true) -> Variant:
	var y := (b - a).normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := ref.cross(y).normalized()
	var x := y.cross(z)
	return _bx(k, p, Vector3(w, a.distance_to(b), t), (a + b) * 0.5, mat, col, Basis(x, y, z).get_euler(), shadow)


## A plate lying on a face seen side-on: its length from a to b ((z, y)
## points), centred on x, w wide, t thick, pushed `push` out along the face's
## normal (outward is up/forward when a -> b climbs a front face toward the back).
static func _zy(k: VehicleModels, p: Node3D, x: float, w: float, a: Vector2, b: Vector2, t: float, push: float, mat: String, col = null, shadow := true) -> Variant:
	var d := b - a
	var dn := d.normalized()
	var n := Vector2(-dn.y, dn.x)
	var c := (a + b) * 0.5 + n * (push + t * 0.5)
	return _bx(k, p, Vector3(w, d.length(), t), Vector3(x, c.y, c.x), mat, col, Vector3(atan2(d.x, d.y), 0, 0), shadow)


## A box lying flat on a face: local x along ex, y along ey (squared up), its
## thickness standing out of the face toward `out`; surf the point under its centre.
static func _on_face(k: VehicleModels, p: Node3D, surf: Vector3, ex: Vector3, ey: Vector3, out: Vector3, size: Vector3, mat: String, col = null, shadow := true) -> Variant:
	var x := ex.normalized()
	var z := x.cross(ey).normalized()
	if z.dot(out) < 0.0:
		z = -z
		x = -x
	var y := z.cross(x)
	return _bx(k, p, size, surf + z * size.z * 0.5, mat, col, Basis(x, y, z).get_euler(), shadow)


## Rings for VehicleModels.solid from plan outlines (x, z pairs) at heights.
static func _rings(outlines: Array, ys: Array) -> Array:
	var r := []
	for i in outlines.size():
		r.append(VehicleModels.ring_y(VehicleModels._v2(outlines[i]), ys[i]))
	return r


## A ring across x at z from (x, y) pairs.
static func _rz(pairs: Array, z: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in range(0, pairs.size(), 2):
		r.append(Vector3(pairs[i], pairs[i + 1], z))
	return r


## A chamfered rectangle (x0..x1, z0..z1) as plan outline pairs.
static func _oct(x0: float, x1: float, z0: float, z1: float, c: float) -> Array:
	return [x0 + c, z0, x1 - c, z0, x1, z0 + c, x1, z1 - c, x1 - c, z1, x0 + c, z1, x0, z1 - c, x0, z0 + c]


## A tracked vehicle's road wheel spinning about x: twin rubber tyres with the
## guide-horn gap between them, the dished disc, the hub and its bolt ring.
## spokes > 0 adds stamped ribs on the disc (the T-55's "starfish" wheels).
static func _road_wheel(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, mat: String, col = null, spokes := 0) -> Node3D:
	var pv := k._pivot(p, pos)
	for sx: float in [-1.0, 1.0]:
		k._cyl(pv, r, r, w * 0.4, Vector3(sx * w * 0.3, 0, 0), Z90, "rubber", null, 14)
	k._cyl(pv, r * 0.82, r * 0.82, w * 0.96, Vector3.ZERO, Z90, mat, col, 14)
	k._cyl(pv, r * 0.3, r * 0.36, w + 0.06, Vector3.ZERO, Z90, "gunmetal_w", null, 8, false)
	k._cyl(pv, r * 0.13, r * 0.13, w + 0.1, Vector3.ZERO, Z90, "metal_dark", null, 6, false)
	# the stamped ribs, on the outer face only
	var ox := signf(pos.x) if pos.x != 0.0 else 1.0
	for i in spokes:
		var a := TAU * i / float(spokes)
		_bx(k, pv, Vector3(0.024, r * 0.44, 0.07), Vector3(ox * (w * 0.48 + 0.012), sin(a) * r * 0.56, cos(a) * r * 0.56), mat, col, Vector3(-a + PI / 2, 0, 0), false)
	k.wheels.append(pv)
	return pv


## A toothed drive sprocket spinning about x.
static func _sprocket(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, mat: String, col = null, teeth := 11) -> Node3D:
	var pv := k._pivot(p, pos)
	k._cyl(pv, r * 0.86, r * 0.86, w * 0.7, Vector3.ZERO, Z90, "gunmetal_w", null, 14)
	for i in teeth:
		var a := TAU * i / float(teeth)
		k._add(pv, _tooth(w * 0.72, r), "gunmetal_w", null, Vector3(0, sin(a) * r * 0.9, cos(a) * r * 0.9), Vector3(-a, 0, 0))
	k._cyl(pv, r * 0.62, r * 0.66, w * 0.76, Vector3.ZERO, Z90, mat, col, 12)
	k._cyl(pv, r * 0.28, r * 0.32, w * 0.76 + 0.08, Vector3.ZERO, Z90, "gunmetal_w", null, 8, false)
	var ox := signf(pos.x) if pos.x != 0.0 else 1.0
	for i in 6:
		var a := TAU * i / 6.0
		_bx(k, pv, Vector3(0.02, 0.05, 0.05), Vector3(ox * (w * 0.38 + 0.01), sin(a) * r * 0.45, cos(a) * r * 0.45), "metal_dark", null, Vector3.ZERO, false)
	k.wheels.append(pv)
	return pv


static var _teeth := {}


## A sprocket tooth: a plain box (w across, as deep as the rim), cached.
static func _tooth(w: float, r: float) -> BoxMesh:
	var key := "%.3f,%.3f" % [w, r]
	if not _teeth.has(key):
		var bm := BoxMesh.new()
		bm.size = Vector3(w, r * 0.26, r * 0.2)
		_teeth[key] = bm
	return _teeth[key]


## A steel idler wheel (twin discs) spinning about x.
static func _idler(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, mat: String, col = null) -> Node3D:
	var pv := k._pivot(p, pos)
	for sx: float in [-1.0, 1.0]:
		k._cyl(pv, r, r, w * 0.34, Vector3(sx * w * 0.3, 0, 0), Z90, "gunmetal_w", null, 14)
	k._cyl(pv, r * 0.76, r * 0.76, w * 0.92, Vector3.ZERO, Z90, mat, col, 12)
	k._cyl(pv, r * 0.28, r * 0.3, w + 0.06, Vector3.ZERO, Z90, "gunmetal_w", null, 8, false)
	k.wheels.append(pv)
	return pv


## A track: a belt of link plates round the convex hull of its wheels (each
## circle (z, y, r)) at x, w wide, th thick; `horns` adds the guide horns
## down the middle of the top run.
static func _belt(k: VehicleModels, p: Node3D, x: float, w: float, circles: Array, th := 0.08, horns := false) -> void:
	var pts := PackedVector2Array()
	for c in circles:
		var cv: Vector3 = c
		var rr := cv.z + th * 0.5
		for i in 12:
			var a := TAU * (i + 0.5) / 12.0
			pts.append(Vector2(cv.x + cos(a) * rr, cv.y + sin(a) * rr))
	var hull := Geometry2D.convex_hull(pts)
	var top_a := Vector2.ZERO
	var top_b := Vector2.ZERO
	for i in hull.size() - 1:
		var a2 := hull[i]
		var b2 := hull[i + 1]
		var d := b2 - a2
		var l := d.length()
		if l < 0.015:
			continue
		var mid := (a2 + b2) * 0.5
		_bx(k, p, Vector3(w, th, l + th * 0.7), Vector3(x, mid.y, mid.x), "track", null, Vector3(atan2(-d.y, d.x), 0, 0))
		# the longest run near the top is where the guide horns show
		if mid.y > 0.4 and l > top_a.distance_to(top_b):
			top_a = a2
			top_b = b2
	if horns and top_a != top_b:
		var n := int(top_a.distance_to(top_b) / 0.32)
		for i in n:
			var q := top_a.lerp(top_b, (i + 0.5) / float(n))
			_bx(k, p, Vector3(0.07, 0.08, 0.09), Vector3(x, q.y + th * 0.5 + 0.03, q.x), "gunmetal_w", null, Vector3.ZERO, false)


## A headlight facing f (-1 forward, 1 back): housing, lens, wire guard.
static func _lamp(k: VehicleModels, p: Node3D, pos: Vector3, r := 0.08, f := -1.0, guard := true) -> void:
	_bx(k, p, Vector3(r * 2.6, r * 2.3, 0.12), pos, "gunmetal_w")
	if not k.burnt:
		k._cyl(p, r, r, 0.03, pos + Vector3(0, 0, f * 0.06), X90, "plain", Color(0.72, 0.72, 0.66), 10, false)
	if guard:
		for i in 3:
			_bx(k, p, Vector3(0.014, r * 2.5, 0.014), pos + Vector3((i - 1) * r * 0.75, 0, f * 0.12), "gunmetal_w", null, Vector3.ZERO, false)
		_bx(k, p, Vector3(r * 2.7, 0.016, 0.1), pos + Vector3(0, r * 1.2, f * 0.08), "gunmetal_w", null, Vector3.ZERO, false)


## A tail light cluster (red and amber) facing back.
static func _taillight(k: VehicleModels, p: Node3D, pos: Vector3) -> void:
	_bx(k, p, Vector3(0.22, 0.12, 0.06), pos, "gunmetal_w")
	if not k.burnt:
		_bx(k, p, Vector3(0.08, 0.07, 0.02), pos + Vector3(-0.05, 0, 0.035), "paint", Color(0.45, 0.06, 0.05), Vector3.ZERO, false)
		_bx(k, p, Vector3(0.08, 0.07, 0.02), pos + Vector3(0.05, 0, 0.035), "paint", Color(0.55, 0.36, 0.08), Vector3.ZERO, false)


## A whip antenna on a base.
static func _antenna(k: VehicleModels, p: Node3D, pos: Vector3, h := 2.0) -> void:
	k._cyl(p, 0.04, 0.05, 0.12, pos + Vector3(0, 0.06, 0), Vector3.ZERO, "gunmetal_w", null, 8)
	k._cyl(p, 0.007, 0.013, h, pos + Vector3(0, 0.12 + h * 0.5, 0), Vector3.ZERO, "gunmetal_w", null, 4, false)


## A bank of smoke-grenade dischargers: `rows` x `cols` tubes on a bracket,
## the bank turned by yaw (0 faces forward, positive turns it to the left),
## the tubes pitched up.
static func _smoke(k: VehicleModels, p: Node3D, pos: Vector3, yaw: float, cols := 3, rows := 2, pitch := 0.5, r := 0.042) -> void:
	var t := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), pos)
	var w := cols * r * 2.3 + 0.04
	_bx(k, p, Vector3(w, 0.06, 0.16), t * Vector3(0, -0.03, 0.02), "gunmetal_w", null, Vector3(0, yaw, 0))
	for j in rows:
		for i in cols:
			var fx := (i - (cols - 1) * 0.5) * r * 2.3
			var lp := Vector3(fx, 0.05 + j * r * 2.1, -0.02 + j * 0.03)
			k._cyl(p, r, r, 0.22, t * lp, (t.basis * Basis.from_euler(Vector3(-PI / 2 + pitch + j * 0.15, fx * 1.2, 0))).get_euler(), "gunmetal_w", null, 8, false)


## A tow shackle (a U on its pin) at pos, facing f (-1 forward, 1 back).
static func _shackle(k: VehicleModels, p: Node3D, pos: Vector3, f := -1.0) -> void:
	_bx(k, p, Vector3(0.14, 0.14, 0.12), pos, "gunmetal_w")
	k._cyl(p, 0.035, 0.035, 0.18, pos + Vector3(0, 0, f * 0.08), X90, "gunmetal_w", null, 8)
	k._cyl(p, 0.065, 0.065, 0.035, pos + Vector3(0, -0.02, f * 0.16), Z90, "gunmetal_w", null, 10, false)


## A periscope head facing along yaw (0: forward), with its glass.
static func _periscope(k: VehicleModels, p: Node3D, pos: Vector3, yaw := 0.0, pitch := 0.0) -> void:
	_bx(k, p, Vector3(0.18, 0.1, 0.12), pos, "gunmetal_w", null, Vector3(pitch, yaw, 0))
	if not k.burnt:
		var f := Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3(0, 0.005, -0.062)
		_bx(k, p, Vector3(0.14, 0.06, 0.012), pos + f, "glass", null, Vector3(pitch, yaw, 0), false)


## A round hatch: the ring, the lid, its hinge and handle.
static func _hatch(k: VehicleModels, p: Node3D, pos: Vector3, r: float, mat: String, col = null, hinge_z := 1.0) -> void:
	k._cyl(p, r + 0.03, r + 0.05, 0.06, pos + Vector3(0, 0.03, 0), Vector3.ZERO, mat, col, 16)
	k._cyl(p, r - 0.03, r, 0.05, pos + Vector3(0, 0.085, 0), Vector3.ZERO, mat, col, 16)
	_bx(k, p, Vector3(0.26, 0.06, 0.09), pos + Vector3(0, 0.08, hinge_z * r * 0.95), "gunmetal_w", null, Vector3.ZERO, false)
	_bx(k, p, Vector3(0.14, 0.03, 0.03), pos + Vector3(0, 0.125, -hinge_z * r * 0.4), "gunmetal_w", null, Vector3.ZERO, false)


## A jerrycan standing upright, its broad face toward x (yaw turns it).
static func _jerry(k: VehicleModels, p: Node3D, pos: Vector3, col := OD, yaw := 0.0) -> void:
	_bx(k, p, Vector3(0.17, 0.46, 0.34), pos, "paint", col, Vector3(0, yaw, 0))
	_bx(k, p, Vector3(0.18, 0.04, 0.2), pos + Vector3(0, 0.08, 0), "paint", col.darkened(0.15), Vector3(0, yaw, 0), false)
	_bx(k, p, Vector3(0.06, 0.05, 0.14), pos + Vector3(0, 0.25, 0).rotated(Vector3.UP, yaw) + Vector3(0, 0, 0.04).rotated(Vector3.UP, yaw), "paint", col.darkened(0.2), Vector3(0, yaw, 0), false)


## An ammo can, its long side along z (yaw turns it).
static func _ammo_can(k: VehicleModels, p: Node3D, pos: Vector3, yaw := 0.0, col := OD) -> void:
	_bx(k, p, Vector3(0.16, 0.2, 0.3), pos, "paint", col, Vector3(0, yaw, 0))
	_bx(k, p, Vector3(0.04, 0.02, 0.18), pos + Vector3(0, 0.11, 0), "gunmetal_w", null, Vector3(0, yaw, 0), false)


## A lifting eye (a small loop) standing on a surface at pos.
static func _eye(k: VehicleModels, p: Node3D, pos: Vector3, yaw := 0.0) -> void:
	_bx(k, p, Vector3(0.12, 0.03, 0.08), pos + Vector3(0, 0.015, 0), "gunmetal_w", null, Vector3(0, yaw, 0), false)
	k._cyl(p, 0.045, 0.045, 0.025, pos + Vector3(0, 0.06, 0), Z90 + Vector3(0, yaw, 0), "gunmetal_w", null, 8, false)


# --- weapons -------------------------------------------------------------------------

## An M2 .50 cal along -Z, the receiver's centre at pos: the receiver and its
## top cover, the spade grips, the barrel support with its jacket holes, the
## heavy barrel, the flash hider, the ammo can on the left. Returns the muzzle.
static func _m2(k: VehicleModels, p: Node3D, pos: Vector3, can := true) -> Vector3:
	_bx(k, p, Vector3(0.16, 0.19, 0.62), pos + Vector3(0, 0, 0.1), "gunmetal_w")
	_bx(k, p, Vector3(0.17, 0.03, 0.44), pos + Vector3(0, 0.105, 0.08), "gunmetal_w")
	_bx(k, p, Vector3(0.15, 0.16, 0.03), pos + Vector3(0, 0, 0.42), "gunmetal_w")
	for sx: float in [-0.08, 0.08]:
		k._cyl(p, 0.02, 0.02, 0.14, pos + Vector3(sx, 0.05, 0.5), Vector3.ZERO, "gunmetal_w", null, 6, false)
	_bx(k, p, Vector3(0.03, 0.045, 0.1), pos + Vector3(0.095, 0.02, 0.04), "gunmetal_w", null, Vector3.ZERO, false)
	k._cyl(p, 0.046, 0.046, 0.26, pos + Vector3(0, 0, -0.33), X90, "gunmetal_w", null, 10)
	for z: float in [-0.25, -0.34, -0.43]:
		k._cyl(p, 0.052, 0.052, 0.025, pos + Vector3(0, 0, z), X90, "metal_dark", null, 10, false)
	k._cyl(p, 0.028, 0.028, 0.9, pos + Vector3(0, 0, -0.9), X90, "gunmetal_w", null, 8)
	_bx(k, p, Vector3(0.025, 0.07, 0.1), pos + Vector3(0, 0.06, -0.64), "gunmetal_w", null, Vector3.ZERO, false)
	k._cyl(p, 0.048, 0.03, 0.12, pos + Vector3(0, 0, -1.41), X90, "gunmetal_w", null, 8, false)
	if can:
		_bx(k, p, Vector3(0.12, 0.19, 0.29), pos + Vector3(-0.17, -0.07, 0.08), "paint", OD)
		_bx(k, p, Vector3(0.1, 0.03, 0.05), pos + Vector3(-0.12, 0.04, 0.08), "paint", Color(0.55, 0.45, 0.22), Vector3(0, 0, 0.5), false)
	return pos + Vector3(0, 0, -1.47)


## An M240 / PKT-sized machine gun along -Z, receiver at pos. Returns the muzzle.
static func _mmg(k: VehicleModels, p: Node3D, pos: Vector3, can := true) -> Vector3:
	_bx(k, p, Vector3(0.08, 0.13, 0.42), pos, "gunmetal_w")
	_bx(k, p, Vector3(0.09, 0.03, 0.26), pos + Vector3(0, 0.075, -0.02), "gunmetal_w")
	_bx(k, p, Vector3(0.05, 0.1, 0.24), pos + Vector3(0, -0.01, 0.32), "gunmetal_w")
	k._cyl(p, 0.03, 0.03, 0.18, pos + Vector3(0, 0, -0.3), X90, "gunmetal_w", null, 8)
	k._cyl(p, 0.016, 0.016, 0.48, pos + Vector3(0, 0, -0.62), X90, "gunmetal_w", null, 6, false)
	k._cyl(p, 0.022, 0.018, 0.07, pos + Vector3(0, 0, -0.89), X90, "gunmetal_w", null, 6, false)
	if can:
		_bx(k, p, Vector3(0.08, 0.13, 0.15), pos + Vector3(-0.08, -0.07, 0.02), "paint", OD)
	return pos + Vector3(0, 0, -0.93)


# --- tank: M1A2 SEP Abrams ---------------------------------------------------------

## M1A2 SEP Abrams (built at 0.9 scale to the Battle Tank's footprint): the
## long hull with its very shallow upper glacis and the driver in the middle
## under the gun, seven road wheels a side under the big bolted skirts (the
## front two heavy armoured panels, the first raked over the idler), the rear
## sprocket, the engine deck grilles and the turbine's exhaust grille across
## the back plate. The welded turret: wide flat slab with the cheek armour
## swept back either side of the recessed gun shield and undercut beneath,
## the gunner's sight doghouse and the CITV on the roof, the commander's .50
## and the loader's M240 behind its shield, M250 smoke dischargers, stowage
## boxes along the sides and the bustle rack round the back; the 120 mm in
## its thermal sleeve with the bore evacuator and the muzzle reference sensor.
static func _abrams(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	var m := k.root
	var roof := 1.42
	# --- running gear: front idler, seven road wheels, rear sprocket
	var tx := 1.3
	var tw := 0.56
	var rw := []
	for i in 7:
		rw.append(-2.2 + i * 0.72)
	for s: float in [-1.0, 1.0]:
		var circles := []
		for z in rw:
			_road_wheel(k, m, Vector3(s * tx, 0.36, z), 0.29, tw * 0.86, cam)
			circles.append(Vector3(z, 0.36, 0.29))
		_idler(k, m, Vector3(s * tx, 0.6, -2.96), 0.27, tw * 0.8, cam)
		_sprocket(k, m, Vector3(s * tx, 0.64, 2.98), 0.3, tw * 0.8, cam)
		circles.append(Vector3(-2.96, 0.6, 0.27))
		circles.append(Vector3(2.98, 0.64, 0.3))
		for z: float in [-0.95, 0.85]:
			k._cyl(m, 0.075, 0.075, tw * 0.5, Vector3(s * tx, 0.86, z), Z90, "gunmetal_w", null, 10, false)
			circles.append(Vector3(z, 0.86, 0.075))
		_belt(k, m, s * tx, tw, circles, 0.08)
	# --- the hull: the belly between the tracks with the lower glacis at its
	# front, the upper hull out over the tracks with the long upper glacis
	k._add(m, VehicleModels.loft("core_m1_low", _oct(-0.98, 0.98, -2.95, 3.22, 0.08), _oct(-1.0, 1.0, -3.5, 3.48, 0.08), 0.42, 1.0), cam, null, Vector3.ZERO)
	var u0 := _oct(-1.62, 1.62, -3.52, 3.5, 0.06)
	var u1 := _oct(-1.62, 1.62, -3.46, 3.5, 0.06)
	var u2 := _oct(-1.6, 1.6, -1.78, 3.48, 0.05)
	k._add(m, VehicleModels.solid(_rings([u0, u1, u2], [0.98, 1.08, roof]), "core_m1_up"), cam, null, Vector3.ZERO)
	var ga := Vector2(-3.46, 1.08)
	var gb := Vector2(-1.78, roof)
	# the glacis: the driver's hatch in the middle at its top, his three
	# periscopes; a seam across the nose, lifting eyes
	_zy(k, m, 0.0, 3.1, ga.lerp(gb, 0.02), ga.lerp(gb, 0.05), 0.02, 0.0, "gunmetal_w", null, false)
	var dh := ga.lerp(gb, 0.82)
	_zy(k, m, 0.0, 0.72, dh - (gb - ga).normalized() * 0.3, dh + (gb - ga).normalized() * 0.3, 0.05, 0.0, cam)
	_zy(k, m, 0.0, 0.1, dh + (gb - ga).normalized() * 0.18, dh + (gb - ga).normalized() * 0.3, 0.05, 0.05, "gunmetal_w", null, false)
	for i in 3:
		var pz := ga.lerp(gb, 0.62)
		_periscope(k, m, Vector3(-0.22 + i * 0.22, pz.y + 0.06, pz.x), (1 - i) * 0.3, -0.2)
	for s: float in [-1.0, 1.0]:
		var e := ga.lerp(gb, 0.3)
		_eye(k, m, Vector3(s * 1.05, e.y + 0.01, e.x))
	# the front: headlight clusters in their guards on the fender tops, tow
	# shackles on the lower glacis, the front fenders' rubber flaps
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.42, 0.24, 0.3), Vector3(s * 1.36, 1.22, -3.38), cam)
		_lamp(k, m, Vector3(s * 1.36, 1.24, -3.56), 0.065)
		_bx(k, m, Vector3(0.12, 0.05, 0.05), Vector3(s * 1.2, 1.24, -3.58), "paint", Color(0.55, 0.38, 0.1), Vector3.ZERO, false)
		_shackle(k, m, Vector3(s * 0.62, 0.72, -3.28))
		_bx(k, m, Vector3(0.5, 0.36, 0.03), Vector3(s * 1.33, 0.8, -3.6), "rubber", null, Vector3(-0.35, 0, 0))
	# skirts: seven bolted panels a side, the first two heavy armoured ones,
	# the front panel raked over the idler; a bolt line along their tops
	var front := [-2.25, 0.5, -2.25, 1.38, -3.6, 1.38, -3.6, 1.22, -3.1, 0.5]
	for s: float in [-1.0, 1.0]:
		var sx: float = s * 1.68
		k._add(m, VehicleModels.extrude_x("core_m1_skf", front, -0.055, 0.055), cam, null, Vector3(sx, 0, 0))
		for i in 6:
			var z0 := -2.22 + i * 0.84
			var z1 := z0 + 0.82
			var heavy := i == 0
			_bx(k, m, Vector3(0.11 if heavy else 0.06, 0.88, z1 - z0), Vector3(sx + (0.0 if heavy else -0.02 * s), 0.94, (z0 + z1) * 0.5), cam)
			for j in 3:
				_bx(k, m, Vector3(0.02, 0.044, 0.044), Vector3(sx + s * (0.06 if heavy else 0.035), 1.3, z0 + 0.12 + j * 0.29), "gunmetal_w", null, Vector3.ZERO, false)
		for j in 4:
			_bx(k, m, Vector3(0.02, 0.044, 0.044), Vector3(sx + s * 0.06, 1.3, -3.4 + j * 0.34), "gunmetal_w", null, Vector3.ZERO, false)
		# the handrail-like lip of the fender over the skirts, a rear mudguard
		_bx(k, m, Vector3(0.12, 0.05, 7.0), Vector3(s * 1.64, roof - 0.02, 0.0), cam)
		_bx(k, m, Vector3(0.62, 0.05, 0.5), Vector3(s * 1.33, 1.08, 3.25), cam)
		_bx(k, m, Vector3(0.5, 0.42, 0.03), Vector3(s * 1.33, 0.84, 3.48), "rubber")
		# fuel filler caps on the deck over the sponsons
		k._cyl(m, 0.09, 0.09, 0.04, Vector3(s * 1.28, roof + 0.02, 1.1), Vector3.ZERO, "gunmetal_w", null, 10, false)
		k._team_mark(m, team, Vector3(s * 1.74, 0.95, 1.1), Vector3(0.02, 0.22, 0.7))
	# --- the engine deck: the big grille doors over the turbine and the
	# transmission, the centre access plate, lifting eyes
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(1.22, 0.035, 1.5), Vector3(s * 0.74, roof + 0.012, 2.55), "gunmetal_w")
		for i in 7:
			_bx(k, m, Vector3(1.14, 0.03, 0.05), Vector3(s * 0.74, roof + 0.035, 1.9 + i * 0.21), cam, null, Vector3.ZERO, false)
		_bx(k, m, Vector3(1.0, 0.03, 0.62), Vector3(s * 0.74, roof + 0.012, 1.25), cam)
		_bx(k, m, Vector3(0.12, 0.03, 0.04), Vector3(s * 0.74, roof + 0.035, 1.1), "gunmetal_w", null, Vector3.ZERO, false)
		_eye(k, m, Vector3(s * 1.35, roof, 3.3))
	_bx(k, m, Vector3(0.22, 0.04, 2.2), Vector3(0, roof + 0.015, 2.3), cam)
	# --- the rear plate: the turbine exhaust grille across the middle, the
	# tail light clusters, tow pintle and shackles, the infantry phone box
	_bx(k, m, Vector3(2.0, 0.58, 0.08), Vector3(0, 1.08, 3.52), "gunmetal_w")
	for i in 6:
		_bx(k, m, Vector3(1.94, 0.025, 0.06), Vector3(0, 0.84 + i * 0.095, 3.57), cam, null, Vector3(0.5, 0, 0), false)
	for x: float in [-0.5, 0.0, 0.5]:
		_bx(k, m, Vector3(0.03, 0.56, 0.04), Vector3(x, 1.08, 3.58), "gunmetal_w", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_taillight(k, m, Vector3(s * 1.3, 1.3, 3.52))
		_bx(k, m, Vector3(0.3, 0.2, 0.1), Vector3(s * 1.3, 1.3, 3.5), "gunmetal_w")
		_shackle(k, m, Vector3(s * 0.7, 0.62, 3.42), 1.0)
	_bx(k, m, Vector3(0.18, 0.16, 0.2), Vector3(0, 0.6, 3.5), "gunmetal_w")
	k._cyl(m, 0.05, 0.05, 0.12, Vector3(0, 0.6, 3.62), X90, "gunmetal_w", null, 8, false)
	_bx(k, m, Vector3(0.24, 0.28, 0.14), Vector3(1.0, 1.24, 3.56), cam)
	# --- the turret
	var t := k._pivot(m, Vector3(0, roof, -0.3))
	k.turret = t
	k._cyl(t, 1.1, 1.14, 0.06, Vector3(0, 0.03, 0.1), Vector3.ZERO, "gunmetal_w", null, 22)
	var tr := 0.7  # the turret roof
	# the main body: the crew compartment and the long bustle over the deck
	var b0 := [-1.36, -1.3, 1.36, -1.3, 1.46, -1.05, 1.46, 2.32, 1.26, 2.58, -1.26, 2.58, -1.46, 2.32, -1.46, -1.05]
	var b1 := [-1.3, -1.2, 1.3, -1.2, 1.4, -0.98, 1.4, 2.28, 1.2, 2.52, -1.2, 2.52, -1.4, 2.28, -1.4, -0.98]
	k._add(t, VehicleModels.loft("core_m1_tur", b0, b1, 0.04, tr), cam, null, Vector3.ZERO)
	# the cheeks: armour blocks either side of the gun shield, swept back in
	# plan, their faces near vertical over a deep undercut
	for s: float in [-1.0, 1.0]:
		var c0 := [0.42, -1.72, 1.46, -1.45, 1.46, -0.7, 0.42, -0.7]
		var c1 := [0.42, -2.36, 1.52, -1.98, 1.52, -0.7, 0.42, -0.7]
		var c2 := [0.42, -2.26, 1.44, -1.9, 1.44, -0.7, 0.42, -0.7]
		var key := "core_m1_cheek_r" if s > 0.0 else "core_m1_cheek_l"
		if s < 0.0:
			c0 = _mirror(c0)
			c1 = _mirror(c1)
			c2 = _mirror(c2)
		k._add(t, VehicleModels.solid(_rings([c0, c1, c2], [0.06, 0.3, tr]), key), cam, null, Vector3.ZERO)
		# the seam where the cheek block meets the turret side
		_bx(k, t, Vector3(0.03, 0.5, 0.03), Vector3(s * 1.5, 0.52, -1.0), "gunmetal_w", null, Vector3.ZERO, false)
	# the gun shield, recessed between the cheeks; the gunner's auxiliary sight
	# port on it, the coax M240 to its right
	var gy := 0.4
	_bx(k, t, Vector3(0.82, 0.54, 0.5), Vector3(0, gy, -1.82), cam)
	_bx(k, t, Vector3(0.6, 0.42, 0.06), Vector3(0, gy, -2.08), cam)
	_bx(k, t, Vector3(0.12, 0.1, 0.06), Vector3(0.28, gy + 0.12, -2.12), "gunmetal_w")
	if not k.burnt:
		_bx(k, t, Vector3(0.08, 0.06, 0.02), Vector3(0.28, gy + 0.12, -2.15), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.024, 0.024, 0.2, Vector3(0.3, gy - 0.1, -2.18), X90, "gunmetal_w", null, 6, false)
	k.mg_tip = k._tip(t, Vector3(0.3, gy - 0.1, -2.29))
	# the 120 mm: the sleeve in sections with their clamp bands, the bore
	# evacuator, the muzzle and its reference sensor
	k._cyl(t, 0.14, 0.15, 0.16, Vector3(0, gy, -2.18), X90, "paint", GUN, 14)
	k._cyl(t, 0.11, 0.1, 1.3, Vector3(0, gy, -2.95), X90, "paint", GUN, 14)
	k._cyl(t, 0.135, 0.135, 0.56, Vector3(0, gy, -3.82), X90, "paint", GUN, 14)
	k._cyl(t, 0.098, 0.088, 1.12, Vector3(0, gy, -4.66), X90, "paint", GUN, 14)
	for z: float in [-2.42, -3.0, -3.56, -4.08, -4.72]:
		k._cyl(t, 0.118 if z > -3.6 else 0.102, 0.118 if z > -3.6 else 0.102, 0.04, Vector3(0, gy, z), X90, "gunmetal_w", null, 14, false)
	k._cyl(t, 0.1, 0.1, 0.12, Vector3(0, gy, -5.25), X90, "gunmetal_w", null, 14)
	k._cyl(t, 0.07, 0.07, 0.02, Vector3(0, gy, -5.315), X90, "plain_dark", null, 12, false)
	_bx(k, t, Vector3(0.09, 0.07, 0.14), Vector3(0, gy + 0.13, -5.14), "gunmetal_w", null, Vector3.ZERO, false)
	k.gun_tip = k._tip(t, Vector3(0, gy, -5.34))
	# --- the roof: the gunner's primary sight doghouse front right with its
	# armoured doors, the commander's independent thermal viewer front left
	k._add(t, VehicleModels.loft("core_m1_gps", _oct(0.5, 1.12, -1.62, -0.8, 0.05), _oct(0.54, 1.08, -1.48, -0.84, 0.05), tr, tr + 0.42), cam, null, Vector3.ZERO)
	for sx: float in [0.63, 0.99]:
		_bx(k, t, Vector3(0.24, 0.26, 0.04), Vector3(sx, tr + 0.24, -1.56), cam, null, Vector3(0.3, 0, 0))
	if not k.burnt:
		_bx(k, t, Vector3(0.4, 0.14, 0.02), Vector3(0.81, tr + 0.22, -1.6), "glass", null, Vector3(0.3, 0, 0), false)
	k._cyl(t, 0.2, 0.22, 0.24, Vector3(-0.78, tr + 0.12, -0.95), Vector3.ZERO, "gunmetal_w", null, 14)
	k._add(t, VehicleModels.loft("core_m1_citv", _oct(-0.98, -0.58, -1.18, -0.74, 0.06), _oct(-0.95, -0.61, -1.12, -0.77, 0.05), tr + 0.24, tr + 0.58), cam, null, Vector3.ZERO)
	if not k.burnt:
		_bx(k, t, Vector3(0.26, 0.16, 0.02), Vector3(-0.78, tr + 0.42, -1.16), "glass", null, Vector3.ZERO, false)
	# the commander's station on the right: the cupola ring with its vision
	# blocks, the hatch, the .50 on its mount ahead of it
	var cp := Vector3(0.62, tr, 0.3)
	k._cyl(t, 0.44, 0.47, 0.16, cp + Vector3(0, 0.08, 0), Vector3.ZERO, cam, null, 18)
	for i in 6:
		var a := -1.2 + i * 0.48
		_bx(k, t, Vector3(0.13, 0.07, 0.05), cp + Vector3(sin(a) * 0.45, 0.09, -cos(a) * 0.45), "glass", null, Vector3(0, -a, 0), false)
	_hatch(k, t, cp + Vector3(0, 0.12, 0.04), 0.33, cam)
	_bx(k, t, Vector3(0.1, 0.22, 0.14), cp + Vector3(0.0, 0.28, -0.44), "gunmetal_w")
	_m2(k, t, cp + Vector3(0.0, 0.48, -0.5))
	# the loader's hatch on the left and his M240 behind the gun shield kit
	var lp := Vector3(-0.66, tr, 0.35)
	_hatch(k, t, lp, 0.34, cam, null, 1.0)
	k._cyl(t, 0.42, 0.42, 0.04, lp + Vector3(0, 0.02, 0), Vector3.ZERO, "gunmetal_w", null, 18, false)
	_bx(k, t, Vector3(0.06, 0.3, 0.1), lp + Vector3(0, 0.22, -0.42), "gunmetal_w")
	_mmg(k, t, lp + Vector3(0, 0.42, -0.62))
	_bx(k, t, Vector3(0.74, 0.46, 0.04), lp + Vector3(0, 0.44, -0.78), cam, null, Vector3(0.12, 0, 0))
	if not k.burnt:
		_bx(k, t, Vector3(0.26, 0.16, 0.02), lp + Vector3(0.17, 0.52, -0.81), "glass", null, Vector3(0.12, 0, 0), false)
	for s: float in [-1.0, 1.0]:
		_bx(k, t, Vector3(0.04, 0.42, 0.42), lp + Vector3(s * 0.39, 0.42, -0.6), cam, null, Vector3(0, s * 0.35, 0))
	# the crosswind sensor mast at the back of the roof, the blow-off panels
	# over the ammunition in the bustle, lifting eyes, antennas
	k._cyl(t, 0.02, 0.025, 0.5, Vector3(0, tr + 0.25, 1.85), Vector3.ZERO, "gunmetal_w", null, 6)
	_bx(k, t, Vector3(0.18, 0.04, 0.04), Vector3(0, tr + 0.5, 1.85), "gunmetal_w", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_bx(k, t, Vector3(0.9, 0.025, 0.9), Vector3(s * 0.55, tr + 0.012, 1.6), cam)
		_bx(k, t, Vector3(0.92, 0.012, 0.03), Vector3(s * 0.55, tr + 0.028, 1.15), "gunmetal_w", null, Vector3.ZERO, false)
		_eye(k, t, Vector3(s * 1.2, tr, -0.75))
		_eye(k, t, Vector3(s * 1.15, tr, 2.2))
		_antenna(k, t, Vector3(s * 1.08, tr, 2.22), 2.1 if s < 0.0 else 1.6)
		# M250 smoke dischargers on the flanks behind the cheeks
		_smoke(k, t, Vector3(s * 1.54, 0.6, -1.12), -s * 1.05, 3, 2, 0.5, 0.043)
		# stowage boxes along the turret sides, their lids and latches
		_bx(k, t, Vector3(0.24, 0.46, 1.5), Vector3(s * 1.58, 0.42, 1.3), cam)
		_bx(k, t, Vector3(0.26, 0.04, 1.52), Vector3(s * 1.585, 0.66, 1.3), cam)
		for z: float in [0.9, 1.7]:
			_bx(k, t, Vector3(0.02, 0.08, 0.05), Vector3(s * 1.71, 0.57, z), "gunmetal_w", null, Vector3.ZERO, false)
		k._team_mark(t, team, Vector3(s * 1.705, 0.38, 1.3), Vector3(0.02, 0.2, 0.6))
	# the bustle rack: a basket round the back of the bustle, packed with kit
	var rz0 := 2.54
	var rz1 := 3.16
	_bx(k, t, Vector3(2.9, 0.04, rz1 - rz0), Vector3(0, 0.26, (rz0 + rz1) * 0.5), "gunmetal_w")
	_bx(k, t, Vector3(2.92, 0.04, 0.04), Vector3(0, 0.68, rz1), "gunmetal_w", null, Vector3.ZERO, false)
	_bx(k, t, Vector3(2.92, 0.04, 0.04), Vector3(0, 0.47, rz1), "gunmetal_w", null, Vector3.ZERO, false)
	for i in 9:
		_bx(k, t, Vector3(0.03, 0.44, 0.03), Vector3(-1.44 + i * 0.36, 0.47, rz1), "gunmetal_w", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_bx(k, t, Vector3(0.04, 0.04, 0.9), Vector3(s * 1.46, 0.68, rz1 - 0.42), "gunmetal_w", null, Vector3.ZERO, false)
		_bx(k, t, Vector3(0.03, 0.44, 0.03), Vector3(s * 1.46, 0.47, rz0 + 0.06), "gunmetal_w", null, Vector3.ZERO, false)
	_bx(k, t, Vector3(0.8, 0.4, 0.5), Vector3(-0.85, 0.48, 2.86), "canvas", BAG, Vector3(0, 0.06, 0))
	k._cyl(t, 0.17, 0.17, 0.9, Vector3(0.05, 0.45, 2.84), Z90, "canvas", TAN_BAG, 10)
	_ammo_can(k, t, Vector3(0.7, 0.38, 2.72), PI / 2)
	_ammo_can(k, t, Vector3(0.7, 0.38, 3.02), PI / 2)
	_bx(k, t, Vector3(0.5, 0.3, 0.5), Vector3(1.12, 0.43, 2.86), "canvas", BAG, Vector3(0, -0.1, 0))
	_jerry(k, t, Vector3(-1.3, 0.51, 2.84), OD, PI / 2)


# --- old_tank: T-55A --------------------------------------------------------------

const RUST := Color(0.33, 0.19, 0.11)
const RUST_D := Color(0.24, 0.14, 0.09)


## A rounded plan outline at height y: n points round (0, 0), hw half wide,
## reaching ef forward and er back (each half an ellipse, p > 2 squarer).
static func _round_ring(hw: float, ef: float, er: float, y: float, n := 24, p := 2.0) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in n:
		var a := TAU * (i + 0.5) / n
		var c := cos(a)
		var s := sin(a)
		var x := signf(c) * pow(absf(c), 2.0 / p) * hw
		var zz := signf(s) * pow(absf(s), 2.0 / p)
		r.append(Vector3(x, y, zz * (er if zz > 0.0 else ef)))
	return r


## A DShK 12.7 mm along -Z, its receiver's centre at pos: the receiver and
## feed cover, the spade grips, the finned barrel, the gas cylinder under it,
## the big flat muzzle brake, the 50-round box on the left. Returns the muzzle.
static func _dshk(k: VehicleModels, p: Node3D, pos: Vector3) -> Vector3:
	_bx(k, p, Vector3(0.13, 0.15, 0.56), pos + Vector3(0, 0, 0.1), "gunmetal_w")
	_bx(k, p, Vector3(0.14, 0.05, 0.26), pos + Vector3(0, 0.09, 0.0), "gunmetal_w")
	_bx(k, p, Vector3(0.14, 0.15, 0.03), pos + Vector3(0, 0.0, 0.39), "gunmetal_w")
	for sx: float in [-0.08, 0.08]:
		k._cyl(p, 0.022, 0.022, 0.14, pos + Vector3(sx, 0.06, 0.47), Vector3.ZERO, "wood_dark", null, 6, false)
	k._cyl(p, 0.028, 0.028, 1.06, pos + Vector3(0, 0, -0.71), X90, "gunmetal_w", null, 8)
	for i in 8:
		k._cyl(p, 0.052, 0.052, 0.016, pos + Vector3(0, 0, -0.24 - i * 0.05), X90, "gunmetal_w", null, 10, false)
	k._cyl(p, 0.016, 0.016, 0.6, pos + Vector3(0, -0.06, -0.48), X90, "gunmetal_w", null, 6, false)
	_bx(k, p, Vector3(0.025, 0.07, 0.1), pos + Vector3(0, 0.06, -0.62), "gunmetal_w", null, Vector3.ZERO, false)
	_bx(k, p, Vector3(0.02, 0.06, 0.02), pos + Vector3(0, 0.06, -1.12), "gunmetal_w", null, Vector3.ZERO, false)
	k._cyl(p, 0.042, 0.042, 0.13, pos + Vector3(0, 0, -1.29), X90, "gunmetal_w", null, 10)
	_bx(k, p, Vector3(0.12, 0.016, 0.1), pos + Vector3(0, 0, -1.29), "gunmetal_w", null, Vector3.ZERO, false)
	_bx(k, p, Vector3(0.1, 0.17, 0.24), pos + Vector3(-0.15, -0.07, 0.04), "paint", OD)
	return pos + Vector3(0, 0, -1.36)


## T-55A (the Rebels' old tank, full scale): the low hull with its 60-degree
## glacis and the V of the splash board across it, five big "starfish" road
## wheels a side with the gap after the first and the track sagging straight
## onto them (no return rollers), thin sheet-steel fenders running the full
## length with the external fuel tanks on the right and the stowage boxes and
## the exhaust on the left, two 200-litre drums on the back; the cast dome
## turret, its 100 mm D-10T with the fume extractor near the muzzle and the
## canvas boot over the mantlet, the IR searchlight beside the gun, the
## commander's cupola and the loader's hatch with its DShK, grab rails, the
## snorkel stowed on the back. Worn: faded, rust-streaked, a replacement road
## wheel in another army's green, a bent mudguard, mismatched fuel drums.
static func _t55(k: VehicleModels, team: int, seed: int) -> void:
	var cam := _cam(team)
	var m := k.root
	var roof := 1.5
	var green := Color(0.29, 0.31, 0.22)
	# --- running gear: front idler, five road wheels (the gap after the
	# first), rear sprocket; the track sagging onto the wheels
	var tx := 1.32
	var tw := 0.58
	var rw := [-1.98, -0.88, -0.03, 0.82, 1.67]
	var wr := 0.405
	var wy := 0.48
	for s: float in [-1.0, 1.0]:
		var circles := []
		for i in rw.size():
			var z: float = rw[i]
			# one road wheel a replacement, still in its old green
			var odd := (s < 0.0 and i == 2) or (s > 0.0 and i == (seed % 3) + 1 and seed % 2 == 0)
			_road_wheel(k, m, Vector3(s * tx, wy, z), wr, tw * 0.82, "paint" if odd else cam, green if odd else null, 6)
			circles.append(Vector3(z, wy, wr))
		_idler(k, m, Vector3(s * tx, 0.56, -2.72), 0.28, tw * 0.8, cam)
		_sprocket(k, m, Vector3(s * tx, 0.6, 2.58), 0.33, tw * 0.8, cam, null, 13)
		circles.append(Vector3(-2.72, 0.56, 0.28))
		circles.append(Vector3(2.58, 0.6, 0.33))
		_belt(k, m, s * tx, tw, circles, 0.075, true)
	# --- the hull: the belly between the tracks with the lower glacis, the
	# upper hull over the tracks, the glacis rising at 60 degrees
	k._add(m, VehicleModels.loft("core_t55_low", _oct(-1.0, 1.0, -2.78, 2.86, 0.08), _oct(-1.02, 1.02, -3.08, 3.06, 0.08), 0.42, 0.97), cam, null, Vector3.ZERO)
	var u0 := _oct(-1.38, 1.38, -3.1, 3.06, 0.05)
	var u1 := _oct(-1.38, 1.38, -3.08, 3.04, 0.05)
	var u2 := _oct(-1.37, 1.37, -2.12, 2.98, 0.05)
	k._add(m, VehicleModels.solid(_rings([u0, u1, u2], [0.96, 1.0, roof]), "core_t55_up"), cam, null, Vector3.ZERO)
	var ga := Vector2(-3.08, 1.0)
	var gb := Vector2(-2.12, roof)
	var gu := Vector3(0, gb.y - ga.y, gb.x - ga.x).normalized()
	var gn := Vector3(0, -gu.z, gu.y)
	# the splash board: a V across the glacis, its point forward
	for s: float in [-1.0, 1.0]:
		var a := Vector3(0, ga.lerp(gb, 0.18).y, ga.lerp(gb, 0.18).x)
		var b := Vector3(s * 1.2, ga.lerp(gb, 0.62).y, ga.lerp(gb, 0.62).x)
		var mid := (a + b) * 0.5
		var along := (b - a).normalized()
		_on_face(k, m, mid, along, gn.cross(along), gn, Vector3(a.distance_to(b) + 0.05, 0.03, 0.14), cam)
	# spare track links bolted across the glacis below it, tow hooks under the nose
	for i in 4:
		var c := ga.lerp(gb, 0.75)
		_on_face(k, m, Vector3(0.62 + (i - 1.5) * 0.17, c.y, c.x), Vector3.RIGHT, gu, gn, Vector3(0.15, 0.56, 0.05), "track")
	for s: float in [-1.0, 1.0]:
		_shackle(k, m, Vector3(s * 0.7, 0.78, -2.95))
	# the driver's hatch front left and his two periscopes, the lights on the
	# glacis corners: the headlight and the IR driving light on the left (its
	# lens long gone), one headlight on the right
	_bx(k, m, Vector3(0.62, 0.05, 0.56), Vector3(-0.72, roof + 0.025, -1.75), cam)
	_bx(k, m, Vector3(0.1, 0.04, 0.1), Vector3(-0.5, roof + 0.06, -1.55), "gunmetal_w", null, Vector3.ZERO, false)
	for i in 2:
		_periscope(k, m, Vector3(-0.86 + i * 0.28, roof + 0.05, -2.08), (i - 0.5) * 0.4)
	for e in [[-1.15, 0.34, true], [-0.82, 0.34, false], [1.15, 0.34, true]]:
		var c2 := ga.lerp(gb, float(e[1]))
		var lp := Vector3(float(e[0]), c2.y + 0.16, c2.x + 0.06)
		k._cyl(k.root, 0.012, 0.012, 0.18, lp + Vector3(0, -0.1, 0.02), Vector3.ZERO, "gunmetal_w", null, 4, false)
		k._cyl(m, 0.095, 0.11, 0.16, lp, X90, "gunmetal_w", null, 12)
		if not k.burnt:
			k._cyl(m, 0.08, 0.08, 0.02, lp + Vector3(0, 0, -0.08), X90, "plain" if bool(e[2]) else "plain_dark", Color(0.7, 0.7, 0.64) if bool(e[2]) else null, 12, false)
		_bx(k, m, Vector3(0.24, 0.016, 0.016), lp + Vector3(0, 0, -0.12), "gunmetal_w", null, Vector3.ZERO, false)
		_bx(k, m, Vector3(0.016, 0.24, 0.016), lp + Vector3(0, 0, -0.12), "gunmetal_w", null, Vector3.ZERO, false)
	# --- fenders: thin shelves the full length over the tracks, on brackets,
	# the front mudguards angled down (the left one bent up), the rear ones
	for s: float in [-1.0, 1.0]:
		var fx: float = s * 1.52
		_bx(k, m, Vector3(0.3, 0.035, 5.6), Vector3(fx, 0.985, -0.05), cam)
		_bx(k, m, Vector3(0.02, 0.08, 5.6), Vector3(s * 1.665, 0.95, -0.05), cam, null, Vector3.ZERO, false)
		for i in 6:
			_bar(k, m, Vector3(s * 1.38, 0.86, -2.2 + i * 0.9), Vector3(s * 1.64, 0.97, -2.2 + i * 0.9), 0.04, 0.03, "gunmetal_w", null, false)
		var bent := 0.55 if s < 0.0 else 0.0
		_bx(k, m, Vector3(0.3, 0.035, 0.62), Vector3(fx, 0.9 + bent * 0.12, -3.1), cam, null, Vector3(-0.42 + bent, 0, s * 0.04 * (1.0 if bent > 0.0 else 0.0)))
		_bx(k, m, Vector3(0.3, 0.035, 0.5), Vector3(fx, 0.9, 3.05), cam, null, Vector3(0.45, 0, 0))
	# the right fender: three external fuel tanks (dented, one streaked with
	# rust), a stowage box forward; their straps and pipes
	for i in 3:
		var z := 0.35 + i * 0.82
		_bx(k, m, Vector3(0.27, 0.42, 0.74), Vector3(1.52, 1.22, z), "steel", Color(0.4, 0.37, 0.28), Vector3(0, [0.0, 0.03, -0.02][i], [0.0, 0.02, 0.04][i]))
		for dz: float in [-0.22, 0.22]:
			_bx(k, m, Vector3(0.29, 0.03, 0.04), Vector3(1.52, 1.44, z + dz), "gunmetal_w", null, Vector3.ZERO, false)
			_bx(k, m, Vector3(0.03, 0.44, 0.04), Vector3(1.66, 1.22, z + dz), "gunmetal_w", null, Vector3.ZERO, false)
		k._cyl(m, 0.05, 0.05, 0.05, Vector3(1.5, 1.45, z - 0.25), Vector3.ZERO, "gunmetal_w", null, 8, false)
	_bx(k, m, Vector3(0.02, 0.3, 0.06), Vector3(1.665, 1.2, 0.97), "paint", RUST, Vector3.ZERO, false)
	_bx(k, m, Vector3(0.02, 0.22, 0.05), Vector3(1.665, 1.15, 1.85), "paint", RUST, Vector3.ZERO, false)
	_tube(k, m, Vector3(1.42, 1.38, 0.0), Vector3(1.42, 1.38, 2.6), 0.022, "gunmetal_w", null, 6)
	_bx(k, m, Vector3(0.27, 0.36, 0.95), Vector3(1.52, 1.19, -1.15), cam)
	_bx(k, m, Vector3(0.29, 0.03, 0.97), Vector3(1.52, 1.38, -1.15), cam)
	# the left fender: stowage boxes, the spare parts box, the oil tank; the
	# exhaust louvre on the hull side above it, sooted round
	for e in [[-1.6, 0.85], [-0.55, 0.95], [0.55, 0.6]]:
		_bx(k, m, Vector3(0.26, 0.34, float(e[1])), Vector3(-1.52, 1.18, float(e[0])), cam, null, Vector3(0, 0.02, 0))
		_bx(k, m, Vector3(0.28, 0.03, float(e[1]) + 0.02), Vector3(-1.52, 1.365, float(e[0])), cam)
		_bx(k, m, Vector3(0.02, 0.06, 0.08), Vector3(-1.665, 1.26, float(e[0])), "gunmetal_w", null, Vector3.ZERO, false)
	k._cyl(m, 0.17, 0.17, 0.8, Vector3(-1.5, 1.18, 2.4), X90, "steel", Color(0.36, 0.34, 0.27), 12)
	_bx(k, m, Vector3(0.05, 0.3, 0.62), Vector3(-1.39, 1.2, 1.35), "gunmetal_w")
	for i in 4:
		_bx(k, m, Vector3(0.04, 0.025, 0.58), Vector3(-1.42, 1.09 + i * 0.07, 1.35), "metal_dark", null, Vector3(0, 0, 0.4), false)
	_bx(k, m, Vector3(0.02, 0.36, 0.9), Vector3(-1.385, 1.27, 1.55), "plain", Color(0.07, 0.07, 0.065), Vector3.ZERO, false)
	# rust streaks down the hull sides and the glacis corners
	for e in [[1.385, 1.22, -0.4, 0.32], [-1.385, 1.25, -0.9, 0.36], [1.385, 1.2, 2.2, 0.26], [-1.385, 1.18, 2.7, 0.3]]:
		_bx(k, m, Vector3(0.012, float(e[3]), 0.04), Vector3(float(e[0]), float(e[1]), float(e[2])), "paint", RUST, Vector3.ZERO, false)
	# --- the engine deck: the louvred grilles, the access plates, the
	# radiator grille across the back
	_bx(k, m, Vector3(2.2, 0.03, 1.15), Vector3(0, roof + 0.01, 2.25), "gunmetal_w")
	for i in 7:
		_bx(k, m, Vector3(2.1, 0.03, 0.05), Vector3(0, roof + 0.03, 1.77 + i * 0.16), cam, null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.9, 0.035, 0.75), Vector3(s * 0.55, roof + 0.012, 0.95), cam, null, Vector3(0, s * 0.01, 0))
		_bx(k, m, Vector3(0.1, 0.03, 0.04), Vector3(s * 0.55, roof + 0.035, 0.75), "gunmetal_w", null, Vector3.ZERO, false)
	k._cyl(m, 0.13, 0.13, 0.06, Vector3(0.6, roof + 0.03, 0.35), Vector3.ZERO, "gunmetal_w", null, 10, false)
	# --- the rear: the sloped plate, the two 200-litre drums on their
	# brackets (one rust-brown, one green), the unditching log under them,
	# tail lights, tow hooks
	_bx(k, m, Vector3(2.6, 0.4, 0.06), Vector3(0, 1.22, 3.06), "gunmetal_w", null, Vector3(-0.35, 0, 0))
	for s: float in [-1.0, 1.0]:
		var dc: Color = Color(0.3, 0.2, 0.14) if s < 0.0 else Color(0.28, 0.31, 0.22)
		k._cyl(m, 0.29, 0.29, 0.86, Vector3(s * 0.66, 1.5, 3.3), X90, "steel", dc, 16)
		for dz: float in [-0.2, 0.2]:
			k._cyl(m, 0.3, 0.3, 0.03, Vector3(s * 0.66, 1.5, 3.3 + dz), X90, "steel", dc.darkened(0.15), 16, false)
		k._cyl(m, 0.04, 0.04, 0.03, Vector3(s * 0.66 + s * 0.12, 1.62, 3.74), X90, "gunmetal_w", null, 8, false)
		for dz: float in [-0.15, 0.25]:
			_bar(k, m, Vector3(s * 0.66, 1.18, 3.06), Vector3(s * 0.66, 1.2, 3.3 + dz), 0.05, 0.04, "gunmetal_w", null, false)
			_bx(k, m, Vector3(0.66, 0.04, 0.04), Vector3(s * 0.66, 1.8, 3.3 + dz), "gunmetal_w", null, Vector3.ZERO, false)
		_taillight(k, m, Vector3(s * 1.2, 1.25, 3.1))
		_shackle(k, m, Vector3(s * 0.75, 0.7, 2.95), 1.0)
	k._cyl(m, 0.13, 0.14, 2.7, Vector3(0, 1.0, 3.12), Z90, "bark", null, 10)
	for x: float in [-0.95, 0.95]:
		_bx(k, m, Vector3(0.05, 0.3, 0.3), Vector3(x, 1.02, 3.12), "gunmetal_w", null, Vector3.ZERO, false)
	_antenna(k, m, Vector3(-1.1, roof, 2.85), 1.8)
	k._team_mark(m, team, Vector3(0, roof + 0.012, 1.5), Vector3(0.7, 0.02, 0.4))
	# --- the turret: the cast dome
	var t := k._pivot(m, Vector3(0, roof, -0.95))
	k.turret = t
	k._cyl(t, 1.02, 1.06, 0.06, Vector3(0, 0.03, 0.0), Vector3.ZERO, "gunmetal_w", null, 22)
	var dome := [
		_round_ring(1.06, 1.08, 1.02, 0.02),
		_round_ring(1.16, 1.2, 1.14, 0.13),
		_round_ring(1.14, 1.15, 1.13, 0.32),
		_round_ring(1.03, 0.99, 1.04, 0.5),
		_round_ring(0.84, 0.76, 0.88, 0.65),
		_round_ring(0.58, 0.5, 0.64, 0.75),
		_round_ring(0.28, 0.22, 0.34, 0.8)]
	k._add(t, VehicleModels.solid(dome, "core_t55_dome"), cam, null, Vector3.ZERO)
	# the cast mantlet in the dome's front and the canvas boot over the gun
	var gy := 0.4
	k._add(t, VehicleModels.solid([_rz([-0.36, gy - 0.26, 0.36, gy - 0.26, 0.42, gy - 0.1, 0.42, gy + 0.14, 0.3, gy + 0.28, -0.3, gy + 0.28, -0.42, gy + 0.14, -0.42, gy - 0.1], -0.85),
		_rz([-0.3, gy - 0.22, 0.3, gy - 0.22, 0.36, gy - 0.08, 0.36, gy + 0.1, 0.26, gy + 0.22, -0.26, gy + 0.22, -0.36, gy + 0.1, -0.36, gy - 0.08], -1.24)], "core_t55_mant"), cam, null, Vector3.ZERO)
	k._cyl(t, 0.13, 0.2, 0.3, Vector3(0, gy, -1.38), X90, "canvas", Color(0.36, 0.34, 0.25), 12)
	for z: float in [-1.31, -1.45]:
		k._cyl(t, 0.18 - (z + 1.31) * 0.4, 0.18 - (z + 1.31) * 0.4, 0.025, Vector3(0, gy, z), X90, "canvas", Color(0.3, 0.29, 0.21), 12, false)
	# the 100 mm: the long tapering barrel, the fume extractor near the muzzle
	k._cyl(t, 0.07, 0.088, 3.3, Vector3(0, gy, -3.15), X90, "paint", Color(0.36, 0.34, 0.26), 12)
	k._cyl(t, 0.118, 0.118, 0.5, Vector3(0, gy, -4.42), X90, "paint", Color(0.36, 0.34, 0.26), 14)
	k._cyl(t, 0.1, 0.118, 0.08, Vector3(0, gy, -4.14), X90, "paint", Color(0.36, 0.34, 0.26), 14, false)
	k._cyl(t, 0.1, 0.118, 0.08, Vector3(0, gy, -4.7), X90, "paint", Color(0.36, 0.34, 0.26), 14, false)
	k._cyl(t, 0.066, 0.068, 0.36, Vector3(0, gy, -4.86), X90, "paint", Color(0.36, 0.34, 0.26), 12)
	k._cyl(t, 0.074, 0.074, 0.05, Vector3(0, gy, -5.04), X90, "gunmetal_w", null, 12)
	k.gun_tip = k._tip(t, Vector3(0, gy, -5.1))
	# the coaxial PKT's port right of the gun
	k._cyl(t, 0.022, 0.022, 0.16, Vector3(0.27, gy - 0.02, -1.26), X90, "gunmetal_w", null, 6, false)
	k.mg_tip = k._tip(t, Vector3(0.27, gy - 0.02, -1.34))
	# the L-2 IR searchlight on its bracket to the right of the gun
	_bx(k, t, Vector3(0.08, 0.2, 0.12), Vector3(0.5, 0.62, -0.98), "gunmetal_w")
	k._cyl(t, 0.17, 0.17, 0.3, Vector3(0.5, 0.82, -1.0), X90, cam, null, 14)
	k._cyl(t, 0.19, 0.19, 0.04, Vector3(0.5, 0.82, -1.17), X90, "gunmetal_w", null, 14, false)
	if not k.burnt:
		k._cyl(t, 0.15, 0.15, 0.02, Vector3(0.5, 0.82, -1.19), X90, "plain_dark", null, 14, false)
	_bar(k, t, Vector3(0.38, 0.5, -1.1), Vector3(0.42, 0.74, -1.04), 0.03, 0.03, "gunmetal_w", null, false)
	# the gunner's sight port front left, the ventilator dome front right
	_bx(k, t, Vector3(0.18, 0.12, 0.24), Vector3(-0.45, 0.72, -0.72), "gunmetal_w", null, Vector3(0.2, 0, 0))
	if not k.burnt:
		_bx(k, t, Vector3(0.12, 0.06, 0.02), Vector3(-0.45, 0.73, -0.85), "glass", null, Vector3(0.2, 0, 0), false)
	k._cyl(t, 0.12, 0.15, 0.08, Vector3(0.12, 0.8, -0.5), Vector3.ZERO, cam, null, 12)
	k._cyl(t, 0.16, 0.13, 0.06, Vector3(0.12, 0.86, -0.5), Vector3.ZERO, "gunmetal_w", null, 12)
	# the commander's cupola on the left with its vision blocks and the small
	# IR spotlight, the loader's hatch on the right with the DShK on its ring
	var cp := Vector3(-0.44, 0.73, 0.18)
	k._cyl(t, 0.34, 0.37, 0.16, cp + Vector3(0, 0.08, 0), Vector3.ZERO, cam, null, 16)
	for i in 5:
		var a := -1.0 + i * 0.5
		_bx(k, t, Vector3(0.11, 0.06, 0.05), cp + Vector3(sin(a) * 0.35, 0.1, -cos(a) * 0.35), "glass", null, Vector3(0, -a, 0), false)
	_hatch(k, t, cp + Vector3(0, 0.14, 0.02), 0.27, cam)
	k._cyl(t, 0.08, 0.08, 0.14, cp + Vector3(0.0, 0.3, -0.34), X90, "gunmetal_w", null, 10)
	_bx(k, t, Vector3(0.12, 0.06, 0.12), cp + Vector3(0, 0.2, -0.3), "gunmetal_w", null, Vector3.ZERO, false)
	var lp := Vector3(0.46, 0.7, 0.28)
	k._cyl(t, 0.36, 0.38, 0.08, lp + Vector3(0, 0.04, 0), Vector3.ZERO, cam, null, 16)
	k._cyl(t, 0.39, 0.39, 0.04, lp + Vector3(0, 0.1, 0), Vector3.ZERO, "gunmetal_w", null, 18, false)
	k._cyl(t, 0.3, 0.32, 0.05, lp + Vector3(0.0, 0.2, 0.52), Vector3(-0.35, 0, 0), cam, null, 16)
	_bx(k, t, Vector3(0.24, 0.06, 0.1), lp + Vector3(0, 0.12, 0.36), "gunmetal_w", null, Vector3.ZERO, false)
	_bx(k, t, Vector3(0.06, 0.34, 0.1), lp + Vector3(0, 0.27, -0.3), "gunmetal_w")
	_bx(k, t, Vector3(0.16, 0.1, 0.18), lp + Vector3(0, 0.45, -0.3), "gunmetal_w")
	_dshk(k, t, lp + Vector3(0, 0.56, -0.35))
	# grab rails round the dome, the snorkel stowed across the back, a rolled
	# tarpaulin, lifting eyes
	for s: float in [-1.0, 1.0]:
		var rp := []
		for i in 5:
			var a := -1.0 + i * 0.52
			rp.append(Vector3(s * sin(PI / 2 + a) * 1.18 * 0.98, 0.36, -cos(PI / 2 + a) * 1.16 * 0.98 - 0.0))
		_path(k, t, rp, 0.016, "gunmetal_w", null, 6)
		for q in [rp[0], rp[4]]:
			_tube(k, t, q, (q as Vector3) * Vector3(0.93, 1.0, 0.93), 0.016, "gunmetal_w", null, 6, false)
		_eye(k, t, Vector3(s * 0.6, 0.7, -0.62), s * 0.5)
		k._team_mark(t, team, Vector3(s * 1.155, 0.26, 0.15), Vector3(0.02, 0.18, 0.5))
	k._cyl(t, 0.16, 0.16, 1.7, Vector3(-0.15, 0.36, 1.2), Z90, "steel", Color(0.32, 0.33, 0.26), 12)
	for x: float in [-0.75, 0.45]:
		k._cyl(t, 0.175, 0.175, 0.04, Vector3(x, 0.36, 1.2), Z90, "gunmetal_w", null, 12, false)
		_bar(k, t, Vector3(x, 0.36, 1.04), Vector3(x, 0.42, 0.96), 0.04, 0.03, "gunmetal_w", null, false)
	k._cyl(t, 0.14, 0.14, 1.1, Vector3(0.82, 0.48, 0.55), Vector3(PI / 2, 0.55, 0), "canvas", Color(0.35, 0.33, 0.24), 10)
	_antenna(k, t, Vector3(-0.62, 0.72, 0.62), 2.1)
	# rust round the cupola and a streak down the dome's flank
	_bx(k, t, Vector3(0.012, 0.22, 0.05), Vector3(1.1, 0.25, -0.6), "paint", RUST, Vector3(0, 0.5, 0.1), false)


# --- technical / aa_tech: Toyota Hilux double cab ----------------------------------

## What the technicals were before the war: sun-faded white (most of them),
## beige, a tired light blue, maroon, dark green, silver.
const HILUX := [Color(0.72, 0.71, 0.66), Color(0.6, 0.54, 0.42), Color(0.45, 0.5, 0.53), Color(0.34, 0.15, 0.12),
	Color(0.27, 0.31, 0.25), Color(0.55, 0.56, 0.55)]
const TRIM := Color(0.12, 0.12, 0.12)  # black plastic
const PRIMER := Color(0.46, 0.46, 0.43)  # a replacement panel in grey primer
const MUD := Color(0.27, 0.22, 0.16)


## Toyota Hilux double cab (full scale): the long bonnet over the front
## axle with its grille and square headlights, the raked windscreen, the
## four-door cab, the short bed behind it with the roll bar; a pipe bull bar
## welded on the front. Rough: faded paint, a door in grey primer, rust round
## the arches, mud up the sills, a brushed-on sand camouflage on some, a
## dented tailgate hanging open. aa: a ZU-23-2 on a raised turntable in the
## bed; otherwise a DShK on a pintle with a welded gun shield.
static func _hilux(k: VehicleModels, team: int, seed: int, aa: bool) -> void:
	var m := k.root
	var h := absi(hash(seed * 7919 + (31 if aa else 17)))
	var col: Color = HILUX[h % HILUX.size()]
	col = col.lerp(Color(0.55, 0.5, 0.42), 0.08 * float((h >> 3) % 3))
	var hw := 0.87
	var zf := -1.65
	var zr := 1.4
	var wr := 0.385
	var ar := 0.47
	# ladder frame, the front diff and the rear axle, the exhaust, fuel tank
	_bx(k, m, Vector3(0.86, 0.18, 4.6), Vector3(0, 0.44, 0.0), "gunmetal_w")
	for z in [zf, zr]:
		_bx(k, m, Vector3(1.22, 0.46, 0.92), Vector3(0, 0.66, z), "plain_dark")
	k._cyl(m, 0.055, 0.055, 1.35, Vector3(0, wr, zr), Z90, "gunmetal_w", null, 8)
	k._add(m, Res.sphere(0.14, 10), "gunmetal_w", null, Vector3(0.06, wr, zr), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	_bx(k, m, Vector3(0.62, 0.12, 0.45), Vector3(0, 0.3, zf), "gunmetal_w")
	k._cyl(m, 0.032, 0.032, 2.3, Vector3(0.36, 0.3, 1.2), X90, "gunmetal_w", null, 6, false)
	_bx(k, m, Vector3(0.5, 0.26, 0.7), Vector3(-0.45, 0.42, 0.55), "gunmetal_w")
	# the body: bonnet, front wings and the cab's lower half in one panel, the
	# bed's sides in another, their arches cut round the wheels
	VmCiv._xbody(k, m, "core_hlx_body", [-2.42, 0.5, 0.96, 0.5, 0.96, 1.13, -0.85, 1.12, -2.3, 1.02, -2.45, 0.86],
		-hw, hw, 0.04, [[zf, wr, ar]], "car_paint", col, 8, [0.22, 0.08, 0.0, 0.0])
	VmCiv._xbody(k, m, "core_hlx_bed", [1.0, 0.52, 2.44, 0.52, 2.44, 0.86, 1.0, 0.86], -hw, hw, 0.03, [[zr, wr, ar]], "car_paint", col)
	_bx(k, m, Vector3(1.6, 0.6, 0.06), Vector3(0, 0.84, 0.98), "plain_dark")
	# the bed: its walls, the top rails, the wheel tubs, a ribbed floor
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.07, 0.3, 1.44), Vector3(s * (hw - 0.035), 1.01, 1.72), "car_paint", col)
		_bx(k, m, Vector3(0.1, 0.035, 1.44), Vector3(s * (hw - 0.05), 1.165, 1.72), "car_paint", col.darkened(0.1))
		_bx(k, m, Vector3(0.2, 0.2, 0.9), Vector3(s * 0.66, 0.96, zr), "car_paint", col.darkened(0.2))
	_bx(k, m, Vector3(hw * 2.0, 0.34, 0.07), Vector3(0, 1.0, 1.0), "car_paint", col)
	_bx(k, m, Vector3(1.6, 0.02, 1.42), Vector3(0, 0.87, 1.72), "steel", col.darkened(0.45))
	for i in 6:
		_bx(k, m, Vector3(0.05, 0.02, 1.4), Vector3(-0.62 + i * 0.25, 0.885, 1.72), "steel", col.darkened(0.5), Vector3.ZERO, false)
	# the tailgate hanging open on its chains, dented
	_bx(k, m, Vector3(hw * 2.0 - 0.04, 0.06, 0.34), Vector3(0, 0.82, 2.62), "car_paint", col, Vector3(0.12, 0, 0.03))
	for s: float in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.8, 1.1, 2.42), Vector3(s * 0.8, 0.86, 2.76), 0.008, "gunmetal_w", null, 4, false)
	# the glasshouse: the windscreen raked well back, the four-door cab, its
	# back window; the panes laid on its faces
	var lo := [-0.86, -0.85, 0.86, -0.85, 0.86, 0.93, -0.86, 0.93]
	var hi := [-0.71, -0.22, 0.71, -0.22, 0.73, 0.86, -0.73, 0.86]
	VmCiv._yloft(k, m, "core_hlx_gh", [lo, hi], [1.12, 1.79], 0.05, "car_paint", col)
	var r0 := VehicleModels.ring_y(VehicleModels._v2(lo), 1.12)
	var r1 := VehicleModels.ring_y(VehicleModels._v2(hi), 1.79)
	var inside := Vector3(0, 1.45, 0.1)
	if not k.burnt:
		VmCiv._pane(k, m, "core_hlx_ws", VmCiv._face(r0, r1, 0), inside, 0.03, 0.97, 0.05, 0.94, 0.0, 0.012, "glass")
		VmCiv._pane(k, m, "core_hlx_bw", VmCiv._face(r0, r1, 2), inside, 0.14, 0.86, 0.2, 0.85, 0.0, 0.012, "glass")
		for f in [1, 3]:
			var a := 0.0 if f == 1 else 0.48
			VmCiv._pane(k, m, "core_hlx_sw%d" % f, VmCiv._face(r0, r1, f), inside, a + 0.03, a + 0.49, 0.07, 0.9, 0.0, 0.012, "glass")
			VmCiv._pane(k, m, "core_hlx_sv%d" % f, VmCiv._face(r0, r1, f), inside, 0.52 - a, 0.97 - a, 0.07, 0.9, 0.0, 0.012, "glass")
	# the doors: shut lines, handles; one rear door a replacement in primer
	var primer := (h >> 5) % 2 == 0
	for s: float in [-1.0, 1.0]:
		for z: float in [-0.83, 0.08, 0.93]:
			_bx(k, m, Vector3(0.012, 0.66, 0.012), Vector3(s * (hw + 0.003), 0.84, z), "plain_dark", null, Vector3.ZERO, false)
		for z: float in [-0.12, 0.74]:
			_bx(k, m, Vector3(0.02, 0.035, 0.13), Vector3(s * (hw + 0.012), 1.04, z), "plain", TRIM, Vector3.ZERO, false)
		_bx(k, m, Vector3(0.012, 0.022, 3.3), Vector3(s * (hw + 0.002), 1.0, -0.75), "car_paint", col.darkened(0.25), Vector3.ZERO, false)
		# mud up the sills and round the arches
		_bx(k, m, Vector3(0.014, 0.16, 1.7), Vector3(s * (hw + 0.004), 0.6, -0.05), "plain", MUD, Vector3.ZERO, false)
		# wing mirrors at the windscreen's foot
		_bar(k, m, Vector3(s * 0.84, 1.16, -0.78), Vector3(s * 1.0, 1.2, -0.76), 0.03, 0.04, "plain", TRIM, false)
		_bx(k, m, Vector3(0.05, 0.14, 0.2), Vector3(s * 1.02, 1.22, -0.74), "plain", TRIM, Vector3(0, s * 0.2, 0))
		# arches flared in black, rust round the rear ones, the side step
		VmCiv._flare(k, m, "core_hlx_ff%d" % int(s), zf, wr, ar - 0.01, ar + 0.06, s * hw - 0.03, s * hw + 0.035, 0.25, PI - 0.25, "plain", TRIM, 7)
		VmCiv._flare(k, m, "core_hlx_fr%d" % int(s), zr, wr, ar - 0.01, ar + 0.06, s * hw - 0.03, s * hw + 0.035, 0.25, PI - 0.25, "plain", TRIM, 7)
		_bx(k, m, Vector3(0.016, 0.1, 0.36), Vector3(s * (hw + 0.006), 0.72, zr + 0.48), "paint", RUST, Vector3(0.5, 0, 0), false)
		_bx(k, m, Vector3(0.12, 0.035, 1.66), Vector3(s * 0.84, 0.45, -0.38), "steel", Color(0.4, 0.4, 0.4))
		for z in [zf, zr]:
			k._wheel(m, Vector3(s * 0.76, wr, z), wr, 0.27, "steel", Color(0.58, 0.58, 0.55))
		# tail lights up the bed's corners
		_bx(k, m, Vector3(0.1, 0.3, 0.05), Vector3(s * (hw - 0.05), 1.0, 2.455), "paint", Color(0.5, 0.06, 0.05), Vector3.ZERO, false)
		_bx(k, m, Vector3(0.1, 0.08, 0.05), Vector3(s * (hw - 0.05), 0.8, 2.455), "paint", Color(0.75, 0.45, 0.12), Vector3.ZERO, false)
	if primer and not k.burnt:
		_bx(k, m, Vector3(0.014, 0.6, 0.8), Vector3(hw + 0.006, 0.82, 0.5), "car_paint", PRIMER, Vector3(0, 0, -0.01), false)
	# brushed-on sand camouflage on some: blotches down the flanks
	if (h >> 7) % 3 == 0 and not k.burnt:
		var bc := Color(0.55, 0.47, 0.33) if col.v < 0.6 else Color(0.42, 0.36, 0.26)
		for e in [[1, -0.4, 0.8, 0.5], [1, 0.5, 0.92, 0.42], [-1, -0.1, 0.75, 0.6], [-1, 1.7, 0.98, 0.5], [1, 1.9, 0.98, 0.36]]:
			var sx := float(e[0]) * (hw + 0.007)
			for j in 2:
				_bx(k, m, Vector3(0.012, 0.2 - j * 0.07, float(e[3]) * (1.0 - j * 0.35)), Vector3(sx + float(e[0]) * j * 0.002, float(e[2]) + j * 0.08, float(e[1]) + (j * 0.14 if j == 1 else 0.0)), "car_paint", bc, Vector3(0.22 - j * 0.6, 0, 0), false)
	# the face: grille, square headlights, indicators, a dented bumper and the
	# pipe bull bar welded across it, the number plate long gone
	var nz := -2.45
	_bx(k, m, Vector3(0.94, 0.3, 0.05), Vector3(0, 0.88, nz - 0.005), "plain", Color(0.2, 0.2, 0.2))
	for i in 4:
		_bx(k, m, Vector3(0.9, 0.025, 0.03), Vector3(0, 0.77 + i * 0.075, nz - 0.03), "steel", Color(0.55, 0.55, 0.53), Vector3.ZERO, false)
	_bx(k, m, Vector3(0.24, 0.07, 0.03), Vector3(0, 0.88, nz - 0.045), "steel", Color(0.6, 0.6, 0.58), Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.3, 0.17, 0.05), Vector3(s * 0.66, 0.9, nz + 0.01), "gunmetal_w")
		if not k.burnt:
			_bx(k, m, Vector3(0.18, 0.12, 0.02), Vector3(s * 0.6, 0.9, nz - 0.02), "plain", Color(0.74, 0.74, 0.68), Vector3.ZERO, false)
			_bx(k, m, Vector3(0.07, 0.12, 0.02), Vector3(s * 0.76, 0.9, nz - 0.02), "paint", Color(0.75, 0.45, 0.12), Vector3.ZERO, false)
	_bx(k, m, Vector3(1.8, 0.2, 0.16), Vector3(0, 0.6, nz - 0.04), "steel", Color(0.45, 0.45, 0.44), Vector3(0, 0, 0.02))
	_path(k, m, [Vector3(-0.7, 0.62, nz - 0.2), Vector3(-0.7, 1.08, nz - 0.18), Vector3(0.7, 1.08, nz - 0.18), Vector3(0.7, 0.62, nz - 0.2)], 0.035, "gunmetal_w", null, 8)
	_tube(k, m, Vector3(-0.7, 0.86, nz - 0.19), Vector3(0.7, 0.86, nz - 0.19), 0.03, "gunmetal_w", null, 8)
	for x: float in [-0.7, 0.7]:
		_tube(k, m, Vector3(x, 0.62, nz - 0.2), Vector3(x, 0.55, nz + 0.05), 0.03, "gunmetal_w", null, 6)
	# the rear: a step bumper, the tow ball
	_bx(k, m, Vector3(1.7, 0.14, 0.14), Vector3(0, 0.55, 2.52), "steel", Color(0.42, 0.42, 0.41))
	k._cyl(m, 0.028, 0.028, 0.1, Vector3(0, 0.66, 2.58), Vector3.ZERO, "gunmetal_w", null, 6, false)
	k._add(m, Res.sphere(0.04, 8), "gunmetal_w", null, Vector3(0, 0.72, 2.58))
	# wipers, a whip antenna on the wing
	for x: float in [-0.32, 0.22]:
		_bx(k, m, Vector3(0.48, 0.012, 0.025), Vector3(x, 1.15, -0.81), "gunmetal_w", null, Vector3(-0.8, 0, 0.1), false)
	_tube(k, m, Vector3(0.82, 1.1, -0.95), Vector3(0.84, 2.6, -0.9), 0.006, "gunmetal_w", null, 4, false)
	# the roll bar behind the cab
	_path(k, m, [Vector3(-0.8, 1.17, 1.12), Vector3(-0.74, 1.86, 1.08), Vector3(0.74, 1.86, 1.08), Vector3(0.8, 1.17, 1.12)], 0.036, "gunmetal_w", null, 8)
	for s: float in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.76, 1.8, 1.1), Vector3(s * 0.8, 1.17, 1.62), 0.03, "gunmetal_w", null, 6)
	k._team_mark(m, team, Vector3(hw + 0.008, 0.85, -0.4), Vector3(0.02, 0.18, 0.42))
	k._team_mark(m, team, Vector3(-hw - 0.008, 0.85, -0.4), Vector3(0.02, 0.18, 0.42))
	if aa:
		_zu23(k, team)
	else:
		_hilux_dshk(k)


## The DShK on a pintle welded to the bed floor, behind a welded shield; ammo
## boxes, a spare tyre and a jerrycan in the bed.
static func _hilux_dshk(k: VehicleModels) -> void:
	var m := k.root
	var px := Vector3(0, 0.88, 1.5)
	_bx(k, m, Vector3(0.5, 0.03, 0.5), px + Vector3(0, 0.015, 0), "gunmetal_w")
	k._cyl(m, 0.06, 0.07, 0.68, px + Vector3(0, 0.34, 0), Vector3.ZERO, "gunmetal_w", null, 10)
	for s: float in [-1.0, 1.0]:
		_tube(k, m, px + Vector3(s * 0.22, 0.02, 0.2), px + Vector3(0, 0.45, 0), 0.02, "gunmetal_w", null, 6)
		_tube(k, m, px + Vector3(s * 0.22, 0.02, -0.2), px + Vector3(0, 0.45, 0), 0.02, "gunmetal_w", null, 6)
	# kit in the bed: ammo boxes, the spare tyre, a jerrycan, a crate
	for i in 3:
		_ammo_can(k, m, Vector3(-0.55 + i * 0.18, 0.98, 2.2), 0.0, Color(0.27, 0.3, 0.21))
	_bx(k, m, Vector3(0.55, 0.24, 0.32), Vector3(0.5, 1.0, 2.2), "wood_dark", null, Vector3(0, 0.1, 0))
	k._cyl(m, 0.36, 0.36, 0.25, Vector3(-0.5, 1.0, 1.35), Vector3(0.12, 0, 0.18), "rubber", null, 16)
	k._cyl(m, 0.21, 0.21, 0.26, Vector3(-0.5, 1.0, 1.35), Vector3(0.12, 0, 0.18), "steel", Color(0.5, 0.5, 0.48), 12)
	_jerry(k, m, Vector3(0.62, 1.12, 1.25), Color(0.32, 0.34, 0.24), 0.3)
	# the traversing head: the yoke, the gun, the shield, a box on the cradle
	var t := k._pivot(m, px + Vector3(0, 0.7, 0))
	k.turret = t
	k._cyl(t, 0.08, 0.08, 0.08, Vector3(0, 0.0, 0), Vector3.ZERO, "gunmetal_w", null, 10)
	for s: float in [-1.0, 1.0]:
		_bx(k, t, Vector3(0.04, 0.26, 0.14), Vector3(s * 0.09, 0.14, 0.0), "gunmetal_w")
	k._cyl(t, 0.025, 0.025, 0.24, Vector3(0, 0.24, 0.0), Z90, "gunmetal_w", null, 6, false)
	var tip := _dshk(k, t, Vector3(0, 0.3, 0.02))
	k.mg_tip = k._tip(t, tip)
	var sc := Color(0.3, 0.31, 0.26)
	_bx(k, t, Vector3(0.7, 0.44, 0.025), Vector3(0, 0.34, -0.5), "steel", sc, Vector3(0.1, 0, 0))
	_bx(k, t, Vector3(0.14, 0.1, 0.03), Vector3(0, 0.3, -0.51), "plain_dark", null, Vector3(0.1, 0, 0), false)
	for s: float in [-1.0, 1.0]:
		_bx(k, t, Vector3(0.025, 0.4, 0.26), Vector3(s * 0.43, 0.33, -0.4), "steel", sc, Vector3(0.1, s * -0.6, 0))
		_bar(k, t, Vector3(s * 0.2, 0.18, -0.48), Vector3(s * 0.07, 0.2, -0.02), 0.025, 0.025, "gunmetal_w", null, false)
	_bx(k, t, Vector3(0.16, 0.05, 0.03), Vector3(0.24, 0.53, -0.53), "paint", RUST, Vector3(0.1, 0, 0), false)


## A ZU-23-2 (its wheeled carriage dropped) on a turntable raised on a
## welded box in the bed: the two 23 mm guns side by side in their cradle,
## the long barrels with their flash hiders, the ammunition boxes outboard,
## the gunner's seat and the ZAP-23 sight on the left, the second seat right.
static func _zu23(k: VehicleModels, team: int) -> void:
	var m := k.root
	var g := Color(0.33, 0.35, 0.27)
	var px := Vector3(0, 0.88, 1.62)
	_bx(k, m, Vector3(1.0, 0.3, 0.9), px + Vector3(0, 0.15, 0), "steel", Color(0.32, 0.31, 0.27))
	_bx(k, m, Vector3(1.06, 0.04, 0.96), px + Vector3(0, 0.31, 0), "gunmetal_w")
	# loose kit in the corners: ammunition boxes, a jerrycan
	for i in 2:
		_bx(k, m, Vector3(0.22, 0.2, 0.5), Vector3(-0.72, 0.98, 1.95 + i * 0.0), "wood_dark", null, Vector3(0, 0.1 * i, 0))
	_jerry(k, m, Vector3(0.7, 1.12, 2.2), Color(0.32, 0.34, 0.24), 0.2)
	var t := k._pivot(m, px + Vector3(0, 0.33, 0))
	k.turret = t
	k._cyl(t, 0.46, 0.5, 0.08, Vector3(0, 0.04, 0), Vector3.ZERO, "paint", g, 18)
	_bx(k, t, Vector3(0.95, 0.06, 1.0), Vector3(0, 0.1, 0.1), "paint", g)
	# the side frames carrying the trunnions
	for s: float in [-1.0, 1.0]:
		k._add(t, VehicleModels.extrude_x("core_zu_frame", [-0.3, 0.12, 0.42, 0.12, 0.3, 0.42, -0.12, 0.62, -0.3, 0.5], -0.025, 0.025), "paint", g, Vector3(s * 0.4, 0, 0))
	# the cradle, raised a little, with both guns
	var el := k._pivot(t, Vector3(0, 0.58, -0.02))
	el.rotation.x = 0.2
	for s: float in [-1.0, 1.0]:
		var gx: float = s * 0.17
		_bx(k, el, Vector3(0.15, 0.22, 0.82), Vector3(gx, 0.0, 0.05), "paint", g)
		_bx(k, el, Vector3(0.12, 0.06, 0.5), Vector3(gx, 0.13, 0.0), "gunmetal_w")
		k._cyl(el, 0.048, 0.048, 0.55, Vector3(gx, 0.02, -0.6), X90, "gunmetal_w", null, 10)
		k._cyl(el, 0.03, 0.026, 1.55, Vector3(gx, 0.02, -1.62), X90, "gunmetal_w", null, 8)
		k._cyl(el, 0.035, 0.035, 0.08, Vector3(gx, 0.02, -1.0), X90, "gunmetal_w", null, 8, false)
		k._cyl(el, 0.05, 0.034, 0.24, Vector3(gx, 0.02, -2.5), X90, "gunmetal_w", null, 10)
		# the ammunition box outboard of each gun, the spent-case chute under it
		_bx(k, el, Vector3(0.17, 0.3, 0.56), Vector3(s * 0.38, 0.02, 0.1), "paint", g.darkened(0.08))
		_bx(k, el, Vector3(0.18, 0.03, 0.58), Vector3(s * 0.38, 0.18, 0.1), "paint", g.darkened(0.2))
		_bx(k, el, Vector3(0.1, 0.16, 0.2), Vector3(gx, -0.18, 0.15), "gunmetal_w")
	_bx(k, el, Vector3(0.22, 0.1, 0.4), Vector3(0, -0.05, -0.2), "paint", g)
	k.mg_tip = k._tip(el, Vector3(0, 0.02, -2.63))
	# the gunner's seat and his sight on the left, the hand wheels, the second
	# seat on the right
	_bx(k, t, Vector3(0.05, 0.4, 0.06), Vector3(-0.3, 0.75, -0.3), "gunmetal_w")
	_bx(k, t, Vector3(0.14, 0.16, 0.22), Vector3(-0.3, 0.98, -0.32), "paint", g)
	if not k.burnt:
		_bx(k, t, Vector3(0.1, 0.08, 0.02), Vector3(-0.3, 1.0, -0.44), "glass", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_bx(k, t, Vector3(0.32, 0.05, 0.3), Vector3(s * 0.38, 0.42, 0.55), "canvas", Color(0.2, 0.2, 0.17))
		_bx(k, t, Vector3(0.28, 0.2, 0.05), Vector3(s * 0.38, 0.54, 0.71), "canvas", Color(0.2, 0.2, 0.17), Vector3(-0.25, 0, 0))
		_tube(k, t, Vector3(s * 0.38, 0.12, 0.55), Vector3(s * 0.38, 0.4, 0.55), 0.025, "gunmetal_w", null, 6)
		k._cyl(t, 0.11, 0.11, 0.02, Vector3(s * 0.48, 0.5, 0.22), Z90, "gunmetal_w", null, 12, false)


# --- humvee: M1151 HMMWV --------------------------------------------------------------

## M1151 up-armoured HMMWV (full scale): wide and low on its big tyres, the
## one-piece bonnet over the wheels with its rubber latches sloping down to
## the slotted grille, the headlights in the wing corners, the bumper with
## the winch and the lifting shackles; the boxy armoured cab with the split
## near-vertical windscreen and four heavy doors with their thick little
## windows; the rear deck behind it; the O-GPK gunner's turret on the roof -
## faceted shields with ballistic windows round an M2.
static func _humvee(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	var m := k.root
	var hw := 1.09
	var zf := -1.66
	var zr := 1.66
	var wr := 0.47
	var ar := 0.6
	# the chassis under the body: frame, the portal hub housings and the
	# A-arms out to each wheel, the drivetrain block
	_bx(k, m, Vector3(1.0, 0.3, 4.4), Vector3(0, 0.58, 0.0), "gunmetal_w")
	for z in [zf, zr]:
		_bx(k, m, Vector3(1.5, 0.5, 1.15), Vector3(0, 0.82, z), "plain_dark")
		for s: float in [-1.0, 1.0]:
			_bx(k, m, Vector3(0.16, 0.3, 0.24), Vector3(s * 0.72, wr, z), "gunmetal_w")
			_bar(k, m, Vector3(s * 0.3, 0.45, z), Vector3(s * 0.66, wr - 0.06, z), 0.08, 0.06, "gunmetal_w", null, false)
			_bar(k, m, Vector3(s * 0.3, 0.72, z - 0.05), Vector3(s * 0.66, wr + 0.12, z - 0.05), 0.07, 0.05, "gunmetal_w", null, false)
	# the body: bonnet over the wings, the cab's lower half and the rear deck
	# in one panel, the arches cut round the wheels
	VmCiv._xbody(k, m, "core_hmv_body", [-2.42, 0.62, 2.46, 0.62, 2.47, 1.3, 0.92, 1.33, -0.8, 1.33, -2.32, 1.14, -2.46, 1.02],
		-hw, hw, 0.04, [[zf, wr, ar], [zr, wr, ar]], cam, null, 8)
	_bx(k, m, Vector3(1.9, 0.5, 4.0), Vector3(0, 0.92, 0.0), "plain_dark")
	# the wheels, their mud flaps
	for s: float in [-1.0, 1.0]:
		for z in [zf, zr]:
			k._wheel(m, Vector3(s * 0.9, wr, z), wr, 0.36, cam)
		_bx(k, m, Vector3(0.36, 0.42, 0.03), Vector3(s * 0.9, 0.42, zf + 0.68), "rubber")
		_bx(k, m, Vector3(0.36, 0.42, 0.03), Vector3(s * 0.9, 0.42, zr + 0.66), "rubber")
	# the bonnet: its seam and the raised middle, the rubber T-latches either
	# side, the intake grille on the right
	_bx(k, m, Vector3(1.3, 0.04, 1.3), Vector3(0, 1.26, -1.5), cam, null, Vector3(-0.115, 0, 0))
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.012, 0.03, 1.55), Vector3(s * 0.66, 1.25, -1.55), "plain_dark", null, Vector3(-0.115, 0, 0), false)
		for z: float in [-2.2, -1.0]:
			_bx(k, m, Vector3(0.04, 0.12, 0.06), Vector3(s * (hw + 0.012), 1.08 + (z + 2.2) * 0.12, z), "rubber", null, Vector3.ZERO, false)
	_bx(k, m, Vector3(0.36, 0.03, 0.42), Vector3(0.84, 1.29, -1.15), "gunmetal_w", null, Vector3(-0.115, 0, 0))
	# the face: the slotted grille, headlights in the wing corners, the
	# indicators, the bumper with its winch and lifting shackles
	var nz := -2.46
	_bx(k, m, Vector3(1.16, 0.4, 0.04), Vector3(0, 0.88, nz - 0.005), "gunmetal_w")
	for i in 9:
		_bx(k, m, Vector3(0.05, 0.36, 0.03), Vector3(-0.48 + i * 0.12, 0.88, nz - 0.03), cam, null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.28, 0.2, 0.06), Vector3(s * 0.84, 0.98, nz - 0.01), "gunmetal_w")
		if not k.burnt:
			k._cyl(m, 0.075, 0.075, 0.02, Vector3(s * 0.88, 0.98, nz - 0.045), X90, "plain", Color(0.72, 0.72, 0.66), 12, false)
			_bx(k, m, Vector3(0.06, 0.06, 0.02), Vector3(s * 0.74, 0.98, nz - 0.045), "paint", Color(0.6, 0.4, 0.1), Vector3.ZERO, false)
		_bx(k, m, Vector3(0.025, 0.24, 0.025), Vector3(s * 0.84, 0.98, nz - 0.08), "gunmetal_w", null, Vector3.ZERO, false)
		_shackle(k, m, Vector3(s * 0.62, 0.66, nz - 0.18))
	_bx(k, m, Vector3(2.08, 0.22, 0.2), Vector3(0, 0.66, nz - 0.06), "gunmetal_w")
	k._cyl(m, 0.1, 0.1, 0.5, Vector3(0, 0.66, nz - 0.18), Z90, "gunmetal_w", null, 12)
	_bx(k, m, Vector3(0.12, 0.08, 0.08), Vector3(0, 0.62, nz - 0.3), "steel")
	# the cab: armoured walls lofted from the belt to the roof
	var lo := [-1.06, -0.8, 1.06, -0.8, 1.06, 0.92, -1.06, 0.92]
	var hi := [-1.0, -0.68, 1.0, -0.68, 1.0, 0.88, -1.0, 0.88]
	var roof := 1.92
	VmCiv._yloft(k, m, "core_hmv_cab", [lo, hi], [1.32, roof], 0.03, cam, null)
	var r0 := VehicleModels.ring_y(VehicleModels._v2(lo), 1.32)
	var r1 := VehicleModels.ring_y(VehicleModels._v2(hi), roof)
	var inside := Vector3(0, 1.6, 0.1)
	if not k.burnt:
		# the split windscreen, thick armoured glass in heavy frames
		for e in [[0.05, 0.47], [0.53, 0.95]]:
			VmCiv._pane(k, m, "core_hmv_ws%d" % int(float(e[0]) * 100), VmCiv._face(r0, r1, 0), inside, float(e[0]), float(e[1]), 0.12, 0.88, 0.0, 0.02, "glass")
		# the door windows, small and square; the cab's back window
		for f in [1, 3]:
			for e in [[0.12, 0.36], [0.6, 0.84]]:
				var u0 := float(e[0]) if f == 1 else 1.0 - float(e[1])
				VmCiv._pane(k, m, "core_hmv_sw%d_%d" % [f, int(u0 * 100)], VmCiv._face(r0, r1, f), inside, u0, u0 + 0.24, 0.2, 0.78, 0.0, 0.02, "glass")
		VmCiv._pane(k, m, "core_hmv_bw", VmCiv._face(r0, r1, 2), inside, 0.32, 0.68, 0.35, 0.8, 0.0, 0.02, "glass")
	# the doors: heavy armoured slabs proud of the body, their seams, hinges
	# and the big latch handles
	for s: float in [-1.0, 1.0]:
		for e in [[-0.78, 0.04], [0.06, 0.88]]:
			var z0 := float(e[0])
			var z1 := float(e[1])
			_bx(k, m, Vector3(0.05, 0.62, z1 - z0 - 0.04), Vector3(s * (hw + 0.025), 1.0, (z0 + z1) * 0.5), cam)
			_bx(k, m, Vector3(0.03, 0.05, 0.12), Vector3(s * (hw + 0.06), 1.18, z1 - 0.15), "gunmetal_w", null, Vector3.ZERO, false)
			for y: float in [0.8, 1.2]:
				_bx(k, m, Vector3(0.04, 0.08, 0.05), Vector3(s * (hw + 0.04), y, z0 + 0.05), "gunmetal_w", null, Vector3.ZERO, false)
		# the wing mirrors on their arms
		_bar(k, m, Vector3(s * 1.08, 1.42, -0.72), Vector3(s * 1.3, 1.5, -0.74), 0.04, 0.04, "gunmetal_w", null, false)
		_bx(k, m, Vector3(0.05, 0.26, 0.2), Vector3(s * 1.32, 1.56, -0.74), "gunmetal_w", null, Vector3(0, s * 0.15, 0))
		# armour over the rear deck's sides
		_bx(k, m, Vector3(0.05, 0.12, 1.5), Vector3(s * (hw - 0.02), 1.39, 1.68), cam)
		k._team_mark(m, team, Vector3(s * (hw + 0.052), 1.0, -0.38), Vector3(0.02, 0.18, 0.5))
	# the rear: the deck lid, tail lights in the corners, the pintle, jerrycans
	_bx(k, m, Vector3(2.1, 0.04, 1.5), Vector3(0, 1.33, 1.68), cam)
	_bx(k, m, Vector3(2.12, 0.62, 0.05), Vector3(0, 1.0, 2.47), cam)
	for s: float in [-1.0, 1.0]:
		_taillight(k, m, Vector3(s * 0.88, 1.1, 2.49))
		_jerry(k, m, Vector3(s * 0.62, 1.58, 2.25), OD, PI / 2)
		_antenna(k, m, Vector3(s * 0.95, 1.35, 2.3), 2.6 if s < 0.0 else 2.0)
	_bx(k, m, Vector3(1.9, 0.16, 0.16), Vector3(0, 0.68, 2.5), "gunmetal_w")
	_bx(k, m, Vector3(0.16, 0.14, 0.2), Vector3(0, 0.66, 2.6), "gunmetal_w")
	k._cyl(m, 0.05, 0.05, 0.1, Vector3(0, 0.66, 2.72), X90, "gunmetal_w", null, 8, false)
	_bx(k, m, Vector3(0.6, 0.32, 0.5), Vector3(0.0, 1.51, 1.85), "canvas", BAG, Vector3(0, 0.15, 0))
	# --- the O-GPK turret on the roof ring
	var t := k._pivot(m, Vector3(0, roof, 0.25))
	k.turret = t
	k._cyl(t, 0.66, 0.68, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, "gunmetal_w", null, 18)
	k._cyl(t, 0.62, 0.62, 0.04, Vector3(0, 0.12, 0), Vector3.ZERO, cam, null, 18)
	# the faceted shields: three across the front, angled wings, side panels,
	# each with its ballistic window; the back left open for the gunner
	var panels := [[0.0, -0.7, 0.62, 0.0], [0.49, -0.53, 0.5, 0.785], [0.68, -0.04, 0.62, 1.57], [0.575, 0.375, 0.3, 2.36]]
	for s: float in [-1.0, 1.0]:
		for i in panels.size():
			var pd: Array = panels[i]
			if i == 0 and s > 0.0:
				continue
			var cx := float(pd[0]) * s
			var cz := float(pd[1])
			var w := float(pd[2]) if i > 0 else 0.62
			var yaw := -s * float(pd[3]) if i > 0 else 0.0
			var tilt := 0.12
			_bx(k, t, Vector3(w, 0.62, 0.035), Vector3(cx, 0.48, cz), cam, null, Vector3(tilt if i < 2 else 0.0, yaw, 0))
			if not k.burnt and i < 3:
				var wo := Basis.from_euler(Vector3(tilt if i < 2 else 0.0, yaw, 0)) * Vector3(0, 0.1, -0.02)
				_bx(k, t, Vector3(w * 0.6, 0.2, 0.02), Vector3(cx, 0.48, cz) + wo, "glass", null, Vector3(tilt if i < 2 else 0.0, yaw, 0), false)
	# the gun slot in the front shield and the M2 through it
	_bx(k, t, Vector3(0.06, 0.32, 0.1), Vector3(0, 0.3, -0.48), "gunmetal_w")
	var tip := _m2(k, t, Vector3(0, 0.5, -0.15))
	k.mg_tip = k._tip(t, tip)
	# the ballistic glass ring over the shields on the front
	if not k.burnt:
		_bx(k, t, Vector3(0.5, 0.18, 0.04), Vector3(0, 0.87, -0.68), "glass", null, Vector3(0.12, 0, 0), false)
	_bx(k, t, Vector3(0.56, 0.03, 0.06), Vector3(0, 0.97, -0.67), cam, null, Vector3(0.12, 0, 0))
	_ammo_can(k, t, Vector3(0.32, 0.22, 0.1))


# --- btr / apc: BTR-80 ----------------------------------------------------------------

## BTR-80 (full scale): the long boat-shaped hull that swims - the lower bow
## raked forward to a sharp stem, the trim vane folded flat against it, the
## upper glacis climbing to the steep plate with the driver's and the
## commander's windows under their raised armoured shutters; the upper sides
## leaning in over the wheel wells, the lower hull a narrow V between eight
## big tyres, the side doors between the second and third axles; the engine
## deck aft with its louvres, the water-jet's flap in the stern; the small
## conical BPU-1 turret over the second axle with the KPVT and its coaxial
## PKT, six smoke dischargers across its back.
static func _btr80(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	var m := k.root
	var wr := 0.53
	var axles := [-2.36, -1.01, 0.54, 1.89]
	var roof := 2.05
	# the hull: belly, the wheel wells' roof, the crease, the upper sides
	var r0 := [-0.6, -2.95, 0.6, -2.95, 0.78, -2.6, 0.78, 3.3, 0.6, 3.48, -0.6, 3.48, -0.78, 3.3, -0.78, -2.6]
	var r1 := [-0.82, -3.7, 0.82, -3.7, 1.0, -3.3, 1.0, 3.52, 0.85, 3.68, -0.85, 3.68, -1.0, 3.52, -1.0, -3.3]
	var r2 := [-0.92, -3.8, 0.92, -3.8, 1.42, -3.1, 1.44, 3.55, 1.15, 3.74, -1.15, 3.74, -1.44, 3.55, -1.42, -3.1]
	var r3 := [-0.92, -3.68, 0.92, -3.68, 1.46, -2.98, 1.46, 3.58, 1.18, 3.78, -1.18, 3.78, -1.46, 3.58, -1.46, -2.98]
	var r4 := [-0.8, -3.05, 0.8, -3.05, 1.25, -2.6, 1.25, 3.56, 1.02, 3.72, -1.02, 3.72, -1.25, 3.56, -1.25, -2.6]
	var r5 := [-0.66, -2.74, 0.66, -2.74, 1.08, -2.32, 1.08, 3.52, 0.9, 3.64, -0.9, 3.64, -1.08, 3.52, -1.08, -2.32]
	k._add(m, VehicleModels.solid(_rings([r0, r1, r2, r3, r4, r5], [0.42, 1.05, 1.11, 1.38, 1.75, roof]), "core_btr_hull"), cam, null, Vector3.ZERO)
	# the wheels on their axles, the wells' dark liners, mud flaps
	for s: float in [-1.0, 1.0]:
		for z in axles:
			k._wheel(m, Vector3(s * 1.2, wr, z), wr, 0.38, cam)
			_bx(k, m, Vector3(0.5, 0.03, 1.14), Vector3(s * 1.2, 1.09, z), "plain_dark", null, Vector3.ZERO, false)
			_bx(k, m, Vector3(0.24, 0.22, 0.2), Vector3(s * 0.9, wr, z), "gunmetal_w")
		_bx(k, m, Vector3(0.36, 0.36, 0.025), Vector3(s * 1.2, 0.62, 2.48), "rubber")
	# the bow: the trim vane folded against the lower bow plate, tow hooks,
	# a splash rail across the stem
	var ba := Vector2(-2.95, 0.42)
	var bb := Vector2(-3.8, 1.11)
	_zy(k, m, 0.0, 1.5, ba.lerp(bb, 0.25), ba.lerp(bb, 0.92), 0.05, 0.0, cam)
	for s: float in [-1.0, 1.0]:
		_zy(k, m, s * 0.62, 0.08, ba.lerp(bb, 0.3), ba.lerp(bb, 0.85), 0.04, 0.05, "gunmetal_w", null, false)
		_shackle(k, m, Vector3(s * 0.55, 0.72, -3.2))
	_bx(k, m, Vector3(1.7, 0.05, 0.06), Vector3(0, 1.12, -3.78), "gunmetal_w")
	# the upper glacis and the window plate: the driver's and commander's
	# windows with their shutters propped open, the lights in guards on the
	# corners, the IR light on the left
	var ga := Vector2(-3.68, 1.38)
	var gb := Vector2(-3.05, 1.75)
	var gc := Vector2(-2.74, roof)
	var wu := Vector3(0, gc.y - gb.y, gc.x - gb.x).normalized()
	var wn := Vector3(0, -wu.z, wu.y)
	for s: float in [-1.0, 1.0]:
		var c := Vector3(s * 0.36, (gb.y + gc.y) * 0.5, (gb.x + gc.x) * 0.5)
		_on_face(k, m, c, Vector3.RIGHT, wu, wn, Vector3(0.52, 0.32, 0.02), "gunmetal_w")
		if not k.burnt:
			_on_face(k, m, c + wn * 0.02, Vector3.RIGHT, wu, wn, Vector3(0.44, 0.24, 0.015), "glass", null, false)
		# the shutter hinged at the top, propped up and out
		var top := Vector3(s * 0.36, gc.y + 0.02, gc.x - 0.02)
		_bx(k, m, Vector3(0.56, 0.04, 0.36), top + Vector3(0, 0.1, -0.15), cam, null, Vector3(-0.55, 0, 0))
		var lp := Vector3(s * 1.0, ga.lerp(gb, 0.6).y + 0.12, ga.lerp(gb, 0.6).x + 0.05)
		_lamp(k, m, lp, 0.065)
	k._cyl(m, 0.09, 0.1, 0.16, Vector3(-0.68, 1.72, -3.12), X90, "gunmetal_w", null, 12)
	if not k.burnt:
		k._cyl(m, 0.075, 0.075, 0.02, Vector3(-0.68, 1.72, -3.2), X90, "plain_dark", null, 12, false)
	# the roof: driver's and commander's hatches at the front, the troop
	# hatches behind the turret, periscopes along the edges
	for s: float in [-1.0, 1.0]:
		_hatch(k, m, Vector3(s * 0.38, roof, -2.25), 0.25, cam)
		_hatch(k, m, Vector3(s * 0.45, roof, 0.3), 0.27, cam)
		for z: float in [-1.75, -0.6, 0.85]:
			_periscope(k, m, Vector3(s * 0.95, roof + 0.03, z), s * -PI / 2)
	# the side doors between the second and third axles: the upper half in
	# the sloped side, the lower half below the crease; firing ports, the
	# stowage boxes and the exhausts aft, tow cable
	var su := Vector3(-0.38, 0.67, 0).normalized()
	for s: float in [-1.0, 1.0]:
		var sn := Vector3(s * 0.67, 0.38, 0).normalized()
		var sup := Vector3(s * su.x, su.y, 0)
		var dc := Vector3(s * 1.36, 1.58, -0.24)
		_on_face(k, m, dc, Vector3(0, 0, 1), sup, sn, Vector3(0.6, 0.42, 0.03), cam)
		for e in [[0.0, 0.21, 0.64, 0.025], [0.0, -0.21, 0.64, 0.025], [0.31, 0.0, 0.025, 0.44], [-0.31, 0.0, 0.025, 0.44]]:
			_on_face(k, m, dc + Vector3(0, 0, float(e[0])) + sup * float(e[1]), Vector3(0, 0, 1), sup, sn, Vector3(float(e[2]), float(e[3]), 0.04), "plain_dark", null, false)
		for e: float in [-0.12, 0.12]:
			_bx(k, m, Vector3(0.05, 0.08, 0.06), dc + sn * 0.03 + sup * e + Vector3(0, 0, -0.33), "gunmetal_w", null, Vector3.ZERO, false)
		k._cyl(m, 0.05, 0.065, 0.06, dc + sn * 0.04 + Vector3(0, 0, 0.12), Vector3(0, 0, s * (PI / 2 - 0.5)), "gunmetal_w", null, 8, false)
		_bx(k, m, Vector3(0.04, 0.05, 0.12), dc + sn * 0.05 + Vector3(0, -0.08, -0.15), "gunmetal_w", null, Vector3.ZERO, false)
		# the lower half, below the crease, folding down into a step
		_bx(k, m, Vector3(0.04, 0.32, 0.56), Vector3(s * 1.23, 0.88, -0.24), cam, null, Vector3(0, 0, s * 0.12))
		for e: float in [-0.29, 0.29]:
			_bx(k, m, Vector3(0.05, 0.34, 0.025), Vector3(s * 1.245, 0.88, -0.24 + e), "plain_dark", null, Vector3(0, 0, s * 0.12), false)
		_bx(k, m, Vector3(0.05, 0.04, 0.5), Vector3(s * 1.27, 0.72, -0.24), "gunmetal_w", null, Vector3.ZERO, false)
		for z: float in [-1.85, -0.95, 0.65, 1.5]:
			k._cyl(m, 0.055, 0.075, 0.06, Vector3(s * 1.33, 1.6, z), Vector3(0, 0, s * (PI / 2 - 0.5)), "gunmetal_w", null, 8, false)
		_on_face(k, m, Vector3(s * 1.33, 1.58, 2.6), Vector3(0, 0, 1), sup, sn, Vector3(1.0, 0.36, 0.16), cam)
		_bx(k, m, Vector3(0.05, 0.2, 0.42), Vector3(s * 1.44, 1.26, 3.3), "gunmetal_w")
		_tube(k, m, Vector3(s * 1.47, 1.3, -2.7), Vector3(s * 1.47, 1.3, 1.7), 0.022, "gunmetal_w", null, 6)
		k._team_mark(m, team, Vector3(s * 1.462, 1.25, -1.7), Vector3(0.02, 0.2, 0.6))
	# the engine deck: the louvred grilles, the access panels
	_bx(k, m, Vector3(1.7, 0.03, 1.6), Vector3(0, roof + 0.01, 2.55), "gunmetal_w")
	for i in 8:
		_bx(k, m, Vector3(1.6, 0.03, 0.05), Vector3(0, roof + 0.03, 1.85 + i * 0.2), cam, null, Vector3.ZERO, false)
	_bx(k, m, Vector3(1.6, 0.03, 0.55), Vector3(0, roof + 0.012, 1.3), cam)
	# the stern: the water-jet's flap, tail lights, tow hooks, the antenna
	_bx(k, m, Vector3(0.5, 0.42, 0.04), Vector3(0, 0.95, 3.6), cam, null, Vector3(-0.38, 0, 0))
	for s: float in [-1.0, 1.0]:
		_taillight(k, m, Vector3(s * 0.85, 1.5, 3.74))
		_shackle(k, m, Vector3(s * 0.45, 0.7, 3.44), 1.0)
	_antenna(k, m, Vector3(0.85, roof, 3.25), 2.4)
	_antenna(k, m, Vector3(-0.85, roof, 3.25), 1.6)
	# --- the BPU-1 turret: a low cone, the mantlet, the KPVT and the PKT
	var t := k._pivot(m, Vector3(0, roof, -1.15))
	k.turret = t
	k._cyl(t, 0.7, 0.72, 0.08, Vector3(0, 0.04, 0), Vector3.ZERO, "gunmetal_w", null, 20)
	k._cyl(t, 0.46, 0.66, 0.44, Vector3(0, 0.3, 0), Vector3.ZERO, cam, null, 20)
	k._cyl(t, 0.42, 0.46, 0.04, Vector3(0, 0.54, 0), Vector3.ZERO, cam, null, 20)
	var gy := 0.32
	_bx(k, t, Vector3(0.42, 0.32, 0.36), Vector3(0, gy, -0.56), cam)
	k._cyl(t, 0.13, 0.15, 0.2, Vector3(0, gy, -0.82), X90, cam, null, 12)
	# the KPVT: the perforated jacket over its rear half, the bare barrel, the
	# muzzle
	k._cyl(t, 0.065, 0.065, 0.62, Vector3(0, gy, -1.2), X90, "gunmetal_w", null, 12)
	for i in 4:
		k._cyl(t, 0.07, 0.07, 0.03, Vector3(0, gy, -0.98 - i * 0.14), X90, "metal_dark", null, 12, false)
	k._cyl(t, 0.034, 0.032, 1.3, Vector3(0, gy, -2.15), X90, "gunmetal_w", null, 8)
	k._cyl(t, 0.045, 0.045, 0.12, Vector3(0, gy, -2.84), X90, "gunmetal_w", null, 10)
	k.mg_tip = k._tip(t, Vector3(0, gy, -2.92))
	k._cyl(t, 0.02, 0.02, 0.4, Vector3(0.2, gy - 0.04, -0.85), X90, "gunmetal_w", null, 6, false)
	# the gunner's sight on the left of the roof, a vision block right, the hatch
	_bx(k, t, Vector3(0.16, 0.2, 0.2), Vector3(-0.2, 0.62, -0.25), "gunmetal_w")
	if not k.burnt:
		_bx(k, t, Vector3(0.1, 0.08, 0.02), Vector3(-0.2, 0.64, -0.36), "glass", null, Vector3.ZERO, false)
	_periscope(k, t, Vector3(0.22, 0.58, -0.25))
	k._cyl(t, 0.2, 0.2, 0.04, Vector3(0.08, 0.58, 0.18), Vector3.ZERO, cam, null, 12)
	# six smoke dischargers in a row across the back, firing over the turret
	for i in 6:
		k._cyl(t, 0.045, 0.045, 0.24, Vector3(sin((i - 2.5) * 0.3) * 0.56, 0.42, cos((i - 2.5) * 0.3) * 0.56), Vector3(-0.6, (i - 2.5) * 0.3, 0), "gunmetal_w", null, 8, false)
	_bx(k, t, Vector3(0.9, 0.06, 0.14), Vector3(0, 0.3, 0.58), "gunmetal_w")


# --- ifv: M2A3 Bradley -----------------------------------------------------------------

## M2A3 Bradley (0.9 scale): the tall slab-sided hull with its steep lower
## nose and long upper glacis (the driver front left, the engine's grilles
## and exhaust front right), the big bolted appliqué armour tiles over the
## sides and the heavy skirts below them, six road wheels a side with the
## sprocket forward, the big ramp at the back with its door; the two-man
## turret with the 25 mm Bushmaster and its coax, the TOW launcher box on the
## left, the IBAS sight and the commander's independent viewer, smoke
## dischargers, the stowage basket round the back.
static func _bradley(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	var m := k.root
	var roof := 1.8
	# running gear: front sprocket, six road wheels, rear idler
	var tx := 1.18
	var tw := 0.48
	var rw := []
	for i in 6:
		rw.append(-1.9 + i * 0.76)
	for s: float in [-1.0, 1.0]:
		var circles := []
		for z in rw:
			_road_wheel(k, m, Vector3(s * tx, 0.34, z), 0.27, tw * 0.86, cam)
			circles.append(Vector3(z, 0.34, 0.27))
		_sprocket(k, m, Vector3(s * tx, 0.64, -2.62), 0.27, tw * 0.8, cam)
		_idler(k, m, Vector3(s * tx, 0.56, 2.6), 0.25, tw * 0.8, cam)
		circles.append(Vector3(-2.62, 0.64, 0.27))
		circles.append(Vector3(2.6, 0.56, 0.25))
		for z: float in [-1.15, 0.4, 1.95]:
			k._cyl(m, 0.07, 0.07, tw * 0.5, Vector3(s * tx, 0.84, z), Z90, "gunmetal_w", null, 10, false)
			circles.append(Vector3(z, 0.84, 0.07))
		_belt(k, m, s * tx, tw, circles, 0.07)
	# the hull: the belly with the steep lower nose, the upper hull out over
	# the tracks with the long upper glacis
	k._add(m, VehicleModels.loft("core_m2_low", _oct(-0.9, 0.9, -2.55, 2.75, 0.06), _oct(-0.92, 0.92, -2.95, 2.95, 0.06), 0.4, 0.98), cam, null, Vector3.ZERO)
	var u0 := _oct(-1.42, 1.42, -2.97, 2.95, 0.05)
	var u1 := _oct(-1.42, 1.42, -2.95, 2.95, 0.05)
	var u2 := _oct(-1.38, 1.38, -1.78, 2.92, 0.05)
	k._add(m, VehicleModels.solid(_rings([u0, u1, u2], [0.96, 1.12, roof]), "core_m2_up"), cam, null, Vector3.ZERO)
	var ga := Vector2(-2.95, 1.12)
	var gb := Vector2(-1.78, roof)
	var gu := Vector3(0, gb.y - ga.y, gb.x - ga.x).normalized()
	var gn := Vector3(0, -gu.z, gu.y)
	# the glacis: its armour plate with the bolt rows, the driver's hatch and
	# periscopes front left, the engine access and grilles front right
	_zy(k, m, 0.0, 2.7, ga.lerp(gb, 0.04), ga.lerp(gb, 0.7), 0.05, 0.0, cam)
	for f: float in [0.08, 0.66]:
		for i in 7:
			var c := ga.lerp(gb, f)
			_bx(k, m, Vector3(0.044, 0.02, 0.044), Vector3(-1.2 + i * 0.4, c.y + 0.06, c.x + 0.0), "gunmetal_w", null, Vector3(-atan2(gb.x - ga.x, gb.y - ga.y) + PI / 2, 0, 0), false)
	_bx(k, m, Vector3(0.62, 0.05, 0.6), Vector3(-0.78, roof + 0.025, -1.45), cam)
	for i in 4:
		_periscope(k, m, Vector3(-1.05 + i * 0.19, roof + 0.05, -1.72), (1.5 - i) * 0.22)
	var gr := ga.lerp(gb, 0.82)
	_on_face(k, m, Vector3(0.5, gr.y, gr.x), Vector3.RIGHT, gu, gn, Vector3(1.0, 0.5, 0.03), "gunmetal_w")
	for i in 5:
		_on_face(k, m, Vector3(0.5, gr.y, gr.x) + gu * (-0.2 + i * 0.1), Vector3.RIGHT, gu, gn, Vector3(0.95, 0.03, 0.05), cam, null, false)
	# the exhaust on the right of the nose, lights in guards, tow hooks
	_bx(k, m, Vector3(0.12, 0.3, 0.4), Vector3(1.45, 1.42, -2.3), "gunmetal_w")
	_bx(k, m, Vector3(0.04, 0.24, 0.34), Vector3(1.51, 1.42, -2.3), "plain_dark", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_lamp(k, m, Vector3(s * 1.15, 1.28, -2.9), 0.07)
		_shackle(k, m, Vector3(s * 0.62, 0.72, -2.78))
	# the sides: the appliqué armour tiles with their bolts, the skirts under
	# them, the grab rail
	for s: float in [-1.0, 1.0]:
		var sx: float = s * 1.47
		for i in 4:
			var z0 := -2.55 + i * 1.32
			_bx(k, m, Vector3(0.08, 0.6, 1.28), Vector3(sx, 1.46, z0 + 0.64), cam)
			for bz in 3:
				for by in 2:
					_bx(k, m, Vector3(0.02, 0.050, 0.050), Vector3(sx + s * 0.045, 1.28 + by * 0.36, z0 + 0.2 + bz * 0.44), "gunmetal_w", null, Vector3.ZERO, false)
		for i in 5:
			var z0 := -2.55 + i * 1.06
			_bx(k, m, Vector3(0.07, 0.5, 1.03), Vector3(s * 1.46, 0.88, z0 + 0.52), cam)
			_bx(k, m, Vector3(0.02, 0.03, 0.9), Vector3(s * 1.5, 1.08, z0 + 0.52), "gunmetal_w", null, Vector3.ZERO, false)
		_bx(k, m, Vector3(0.07, 0.42, 0.5), Vector3(s * 1.44, 0.95, -2.85), cam, null, Vector3(-0.45, 0, 0))
		k._team_mark(m, team, Vector3(s * 1.515, 1.46, 1.42), Vector3(0.02, 0.24, 0.7))
	# the roof: the troop compartment's long cargo hatch, vision blocks
	_bx(k, m, Vector3(1.3, 0.06, 1.2), Vector3(0, roof + 0.03, 2.05), cam)
	_bx(k, m, Vector3(0.04, 0.04, 1.1), Vector3(0.62, roof + 0.08, 2.05), "gunmetal_w", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		for z: float in [0.9, 1.5]:
			_periscope(k, m, Vector3(s * 1.22, roof + 0.05, z), s * -PI / 2)
	# the rear: the big ramp with its door, hinges, stowage boxes either side,
	# tail lights, a water can and kit
	_bx(k, m, Vector3(2.0, 1.2, 0.08), Vector3(0, 1.18, 2.96), cam)
	_bx(k, m, Vector3(0.62, 0.95, 0.04), Vector3(-0.42, 1.3, 3.01), cam)
	if not k.burnt:
		_bx(k, m, Vector3(0.18, 0.12, 0.02), Vector3(-0.42, 1.62, 3.035), "glass", null, Vector3.ZERO, false)
	_bx(k, m, Vector3(0.04, 0.16, 0.06), Vector3(-0.18, 1.28, 3.04), "gunmetal_w", null, Vector3.ZERO, false)
	for x: float in [-0.7, 0.7]:
		k._cyl(m, 0.06, 0.06, 0.3, Vector3(x, 0.62, 2.96), Z90, "gunmetal_w", null, 8)
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.4, 0.86, 0.3), Vector3(s * 1.2, 1.3, 3.02), cam)
		_bx(k, m, Vector3(0.42, 0.04, 0.32), Vector3(s * 1.2, 1.74, 3.02), cam)
		_bx(k, m, Vector3(0.04, 0.06, 0.1), Vector3(s * 1.2, 1.5, 3.18), "gunmetal_w", null, Vector3.ZERO, false)
		_taillight(k, m, Vector3(s * 1.2, 0.82, 3.0))
		_antenna(k, m, Vector3(s * 1.15, roof, 2.7), 2.0 if s < 0.0 else 1.5)
	_jerry(k, m, Vector3(0.45, 1.25, 3.1), OD, PI / 2)
	# --- the turret
	var t := k._pivot(m, Vector3(0.12, roof, -0.55))
	k.turret = t
	k._cyl(t, 0.92, 0.95, 0.06, Vector3(0, 0.03, 0.1), Vector3.ZERO, "gunmetal_w", null, 20)
	var tr := 0.84
	var tb := [-0.5, -1.1, 0.5, -1.1, 1.0, -0.62, 1.02, 0.95, 0.82, 1.22, -0.82, 1.22, -1.02, 0.95, -1.0, -0.62]
	var tt := [-0.38, -0.8, 0.38, -0.8, 0.86, -0.42, 0.9, 0.9, 0.72, 1.12, -0.72, 1.12, -0.9, 0.9, -0.86, -0.42]
	k._add(t, VehicleModels.loft("core_m2_tur", tb, tt, 0.04, tr), cam, null, Vector3.ZERO)
	# the spaced armour on the turret's front faces
	for s: float in [-1.0, 1.0]:
		var a := Vector3(s * 0.52, 0.1, -1.16)
		var b := Vector3(s * 1.05, 0.1, -0.66)
		_on_face(k, t, (a + b) * 0.5 + Vector3(0, 0.26, 0), b - a, Vector3.UP, Vector3(s * 0.65, 0, -0.76), Vector3(a.distance_to(b) + 0.04, 0.48, 0.06), cam)
		for f: float in [0.2, 0.8]:
			_bx(k, t, Vector3(0.050, 0.02, 0.050), a.lerp(b, f) + Vector3(0, 0.42, 0) + Vector3(s * 0.65, 0, -0.76) * 0.07, "gunmetal_w", null, Vector3(PI / 2, -s * 0.7, 0), false)
	# the 25 mm in its mantlet, the coax to its right
	var gy := 0.4
	_bx(k, t, Vector3(0.44, 0.4, 0.4), Vector3(-0.05, gy, -1.1), cam)
	k._cyl(t, 0.1, 0.11, 0.3, Vector3(-0.05, gy, -1.38), X90, "gunmetal_w", null, 12)
	k._cyl(t, 0.045, 0.04, 1.85, Vector3(-0.05, gy, -2.45), X90, "gunmetal_w", null, 10)
	k._cyl(t, 0.065, 0.055, 0.24, Vector3(-0.05, gy, -3.42), X90, "gunmetal_w", null, 10)
	for i in 3:
		k._cyl(t, 0.07, 0.07, 0.025, Vector3(-0.05, gy, -3.36 - i * 0.06), X90, "metal_dark", null, 10, false)
	k.mg_tip = k._tip(t, Vector3(-0.05, gy, -3.56))
	k._cyl(t, 0.022, 0.022, 0.32, Vector3(0.28, gy - 0.05, -1.25), X90, "gunmetal_w", null, 6, false)
	# the TOW launcher box on its arm on the left
	_bx(k, t, Vector3(0.18, 0.24, 0.34), Vector3(-1.02, 0.36, 0.0), "gunmetal_w")
	_bx(k, t, Vector3(0.44, 0.5, 1.38), Vector3(-1.32, 0.42, -0.1), cam)
	for ty: float in [0.3, 0.55]:
		k._cyl(t, 0.1, 0.1, 0.03, Vector3(-1.32, ty, -0.8), X90, "plain_dark", null, 12, false)
	_bx(k, t, Vector3(0.46, 0.04, 0.12), Vector3(-1.32, 0.68, -0.65), "gunmetal_w", null, Vector3.ZERO, false)
	# the IBAS sight head front left, the CIV on the right, the hatches
	_bx(k, t, Vector3(0.5, 0.36, 0.5), Vector3(-0.45, tr + 0.18, -0.42), cam)
	_bx(k, t, Vector3(0.44, 0.06, 0.2), Vector3(-0.45, tr + 0.38, -0.59), cam, null, Vector3(0.6, 0, 0))
	if not k.burnt:
		_bx(k, t, Vector3(0.34, 0.16, 0.02), Vector3(-0.45, tr + 0.18, -0.68), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.14, 0.16, 0.24, Vector3(0.55, tr + 0.12, 0.55), Vector3.ZERO, "gunmetal_w", null, 12)
	_bx(k, t, Vector3(0.34, 0.28, 0.34), Vector3(0.55, tr + 0.36, 0.55), cam)
	if not k.burnt:
		_bx(k, t, Vector3(0.22, 0.12, 0.02), Vector3(0.55, tr + 0.38, 0.37), "glass", null, Vector3.ZERO, false)
	_hatch(k, t, Vector3(0.42, tr, 0.0), 0.3, cam)
	_hatch(k, t, Vector3(-0.4, tr, 0.42), 0.28, cam)
	for s: float in [-1.0, 1.0]:
		_smoke(k, t, Vector3(s * 0.92, 0.66, -0.64), -s * 0.85, 2, 2, 0.5, 0.045)
		_eye(k, t, Vector3(s * 0.7, tr, 0.85))
	# the stowage basket round the back, bags and a bedroll in it
	_bx(k, t, Vector3(1.8, 0.04, 0.44), Vector3(0, 0.3, 1.42), "gunmetal_w")
	for y: float in [0.5, 0.7]:
		_bx(k, t, Vector3(1.84, 0.035, 0.035), Vector3(0, y, 1.64), "gunmetal_w", null, Vector3.ZERO, false)
	for i in 7:
		_bx(k, t, Vector3(0.03, 0.42, 0.03), Vector3(-0.9 + i * 0.3, 0.5, 1.64), "gunmetal_w", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_bx(k, t, Vector3(0.035, 0.035, 0.44), Vector3(s * 0.91, 0.7, 1.42), "gunmetal_w", null, Vector3.ZERO, false)
		_bx(k, t, Vector3(0.03, 0.42, 0.03), Vector3(s * 0.91, 0.5, 1.22), "gunmetal_w", null, Vector3.ZERO, false)
	_bx(k, t, Vector3(0.6, 0.34, 0.36), Vector3(-0.45, 0.5, 1.42), "canvas", BAG)
	k._cyl(t, 0.15, 0.15, 0.7, Vector3(0.38, 0.47, 1.42), Z90, "canvas", TAN_BAG, 10)
	_antenna(k, t, Vector3(0.75, tr, 1.0), 1.6)


# --- helicopters: AH-64D and UH-60 ----------------------------------------------------

## The helicopters are built at full scale inside a node scaled down to the
## size the originals had (the rotors and the gun turret are inside it too).
const HELI_SCALE := 0.65
## US Army helicopter drab, and the sand they wear for the other side.
const HELO_DRAB := Color(0.25, 0.27, 0.22)
const HELO_SAND := Color(0.47, 0.44, 0.38)


## The scaled airframe node the helicopter is built in.
static func _airframe(k: VehicleModels) -> Node3D:
	var b := k._pivot(k.root, Vector3.ZERO)
	b.scale = Vector3.ONE * HELI_SCALE
	return b


## AH-64D Apache Longbow: the narrow fuselage with the stepped tandem
## cockpit of flat panes (the gunner low in front, the pilot high behind),
## the avionics bays bulging along its lower flanks, the TADS/PNVS sensor
## turrets on the nose and the M230 chain gun in its turret under the chin;
## the two engines slung either side of the gearbox fairing with their
## exhaust suppressors, stub wings with a Hellfire rack outboard and a
## 19-tube rocket pod inboard each side, the four-blade rotor under the
## Longbow radar dome, the tail rotor on the left of the swept fin, the
## stabilator low at the back, fixed main gear and the tailwheel.
static func _apache(k: VehicleModels, team: int) -> void:
	var b := _airframe(k)
	var mat := "aircraft"
	var col: Color = HELO_DRAB if team != 1 else HELO_SAND
	var dark := Color(0.06, 0.06, 0.06)
	var h := VmHeli.Hull.new([
		[-6.05, 1.28, 0.16, 0.16, 0.16],
		[-5.8, 1.32, 0.4, 0.38, 0.4],
		[-5.25, 1.4, 0.48, 0.55, 0.5, 0.9, 1.0],
		[-4.2, 1.5, 0.5, 0.52, 0.58, 0.9, 1.0],
		[-3.0, 1.56, 0.52, 0.62, 0.62, 0.88, 1.0],
		[-1.6, 1.66, 0.58, 0.82, 0.68, 0.8, 1.0],
		[0.4, 1.78, 0.56, 0.86, 0.64, 0.75, 1.0],
		[1.7, 1.98, 0.42, 0.6, 0.44],
		[3.2, 2.12, 0.3, 0.4, 0.3],
		[6.9, 2.3, 0.2, 0.27, 0.2],
		[8.05, 2.36, 0.15, 0.22, 0.15],
	], 12, 2.4)
	VmHeli._hull(k, b, h, "core_ah_body", mat, col)
	# the stepped canopy: the gunner's low in front, the pilot's high behind,
	# the blast shield between them; the fairing over the gearbox behind
	VmHeli._canopy(k, b, "core_ah_can1", [-0.42, -5.32, 0.42, -5.32, 0.5, -3.92, -0.5, -3.92], [-0.25, -4.92, 0.25, -4.92, 0.33, -3.96, -0.33, -3.96], 1.97, 2.5, mat, col, 0.03)
	VmHeli._canopy(k, b, "core_ah_can2", [-0.5, -3.96, 0.5, -3.96, 0.56, -2.56, -0.56, -2.56], [-0.29, -3.66, 0.29, -3.66, 0.35, -2.62, -0.35, -2.62], 2.08, 2.92, mat, col, 0.03)
	k._add(b, VehicleModels.loft("core_ah_spine", [-0.56, -2.62, 0.56, -2.62, 0.62, 1.3, -0.62, 1.3], [-0.36, -2.6, 0.36, -2.6, 0.4, 0.85, -0.4, 0.85], 2.2, 2.94), mat, col, Vector3.ZERO)
	# the avionics bays along the lower flanks, their access panel seams
	for s: float in [-1.0, 1.0]:
		k._add(b, VehicleModels.loft("core_ah_bay%d" % int(s), VmHeli._mx([0.38, -3.85, 0.78, -3.55, 0.9, -0.7, 0.38, -0.7], s),
			VmHeli._mx([0.38, -4.45, 0.74, -4.15, 0.8, -0.9, 0.38, -0.9], s), 1.0, 1.92), mat, col, Vector3.ZERO)
		for z: float in [-3.0, -2.0]:
			_bx(k, b, Vector3(0.015, 0.8, 0.025), Vector3(s * 0.86, 1.45, z), "gunmetal_w", null, Vector3(0, 0, -s * 0.07), false)
		# the radar warning receivers and a pitot on the nose
		_bx(k, b, Vector3(0.08, 0.12, 0.16), Vector3(s * 0.42, 1.55, -5.55), "gunmetal_w", null, Vector3(0, s * 0.5, 0))
	# --- the nose: the TADS drum with its two sensor heads, the PNVS above
	k._cyl(b, 0.3, 0.3, 0.44, Vector3(0, 1.1, -6.3), Vector3.ZERO, mat, col, 16)
	k._add(b, Res.sphere(0.3, 14), mat, col, Vector3(0, 1.32, -6.3), Vector3.ZERO, Vector3(1.0, 0.35, 1.0))
	for s: float in [-1.0, 1.0]:
		_bx(k, b, Vector3(0.18, 0.34, 0.46), Vector3(s * 0.38, 1.1, -6.28), mat, col)
		if not k.burnt:
			_bx(k, b, Vector3(0.12, 0.22, 0.02), Vector3(s * 0.38, 1.1, -6.52), "glass", null, Vector3.ZERO, false)
	if not k.burnt:
		_bx(k, b, Vector3(0.22, 0.14, 0.02), Vector3(0, 1.08, -6.6), "glass", null, Vector3.ZERO, false)
	k._cyl(b, 0.15, 0.17, 0.26, Vector3(0, 1.7, -6.0), Vector3.ZERO, mat, col, 12)
	if not k.burnt:
		_bx(k, b, Vector3(0.14, 0.12, 0.02), Vector3(0, 1.7, -6.16), "glass", null, Vector3.ZERO, false)
	# wire cutters over the canopy and under the chin
	VmHeli._tube(k, b, Vector3(0, 2.48, -4.95), Vector3(0, 2.75, -5.25), 0.025, "steel", null, 4)
	VmHeli._tube(k, b, Vector3(0, 0.84, -5.3), Vector3(0, 0.66, -5.62), 0.025, "steel", null, 4)
	# --- the engines either side of the gearbox fairing: the nacelles on
	# their pylons, the dark intakes, the exhaust suppressors turned out
	var eng := VmHeli.Hull.new([[-1.45, 2.58, 0.24, 0.24, 0.24], [-1.25, 2.58, 0.36, 0.36, 0.36], [0.9, 2.58, 0.38, 0.38, 0.36], [1.5, 2.58, 0.3, 0.3, 0.28]], 12, 2.2)
	for s: float in [-1.0, 1.0]:
		k._add(b, eng.mesh("core_ah_eng"), mat, col, Vector3(s * 0.98, 0, 0))
		k._cyl(b, 0.25, 0.25, 0.04, Vector3(s * 0.98, 2.58, -1.47), X90, "plain", dark, 12, false)
		k._cyl(b, 0.08, 0.08, 0.1, Vector3(s * 0.98, 2.58, -1.5), X90, "gunmetal_w", null, 8, false)
		_bx(k, b, Vector3(0.5, 0.26, 2.0), Vector3(s * 0.68, 2.42, -0.15), mat, col)
		VmHeli._tube(k, b, Vector3(s * 0.98, 2.56, 1.4), Vector3(s * 1.3, 2.38, 2.05), 0.28, mat, col, 10, 0.22)
		k._cyl(b, 0.18, 0.18, 0.03, Vector3(s * 1.3, 2.38, 2.07), Vector3(PI / 2 - 0.3, s * 0.45, 0), "plain", dark, 10, false)
	# --- stub wings: Hellfires outboard, rocket pods inboard, rails at the tips
	for s: float in [-1.0, 1.0]:
		k._add(b, VehicleModels.loft("core_ah_wing%d" % int(s), VmHeli._mx([0.0, -0.95, 2.05, -0.72, 2.05, 0.2, 0.0, 0.36], s),
			VmHeli._mx([0.0, -0.93, 2.05, -0.7, 2.05, 0.18, 0.0, 0.34], s), -0.08, 0.08), mat, col, Vector3(s * 0.55, 1.88, 0), Vector3(0, 0, -s * 0.05))
		for px: float in [1.48, 2.28]:
			_bx(k, b, Vector3(0.1, 0.26, 0.74), Vector3(s * px, 1.7 - (px - 0.55) * 0.05, -0.3), "gunmetal_w")
		VmHeli._rocket_pod(k, b, Vector3(s * 1.48, 1.32, -0.42), 0.21, 1.62, "paint", Color(0.3, 0.32, 0.27), 19)
		VmHeli._hellfires(k, b, Vector3(s * 2.28, 1.62, -0.3), 4)
		_bx(k, b, Vector3(0.14, 0.14, 0.86), Vector3(s * 2.66, 1.76, -0.3), "gunmetal_w")
		_bx(k, b, Vector3(0.05, 0.05, 0.06), Vector3(s * 2.66, 1.85, -0.75), "plain", Color(0.6, 0.1, 0.08) if s < 0.0 else Color(0.1, 0.5, 0.2), Vector3.ZERO, false)
		k._team_mark(b, team, Vector3(s * 0.31, 2.2, 4.6), Vector3(0.02, 0.22, 0.9))
	# --- the tail: the swept fin, the tail rotor on its left, the stabilator
	# low at the back, the tailwheel under the fin
	k._add(b, VehicleModels.extrude_x("core_ah_fin", [6.7, 2.36, 7.95, 2.3, 8.55, 4.25, 7.95, 4.3], -0.09, 0.09), mat, col, Vector3.ZERO)
	_bx(k, b, Vector3(0.24, 0.3, 0.42), Vector3(-0.12, 3.96, 8.12), mat, col)
	VmHeli._tail_rotor(k, b, Vector3(-0.3, 3.96, 8.12), 4, 1.4, 0.24, -1.0, 0.3)
	_bx(k, b, Vector3(3.3, 0.07, 0.78), Vector3(0, 2.42, 8.02), mat, col)
	k._add(b, Res.sphere(0.06, 8), "plain", Color(0.55, 0.08, 0.06), Vector3(0, 4.32, 8.0))
	VmHeli._tube(k, b, Vector3(0, 2.12, 7.45), Vector3(0, 0.4, 7.85), 0.06, "gunmetal_w", null, 8)
	_bx(k, b, Vector3(0.24, 0.08, 0.2), Vector3(0, 0.42, 7.9), "gunmetal_w")
	k._wheel(b, Vector3(0, 0.25, 7.98), 0.25, 0.15)
	# --- main gear: trailing arms off the bays, the shock struts
	for s: float in [-1.0, 1.0]:
		VmHeli._tube(k, b, Vector3(s * 0.8, 1.02, -3.55), Vector3(s * 1.08, 0.4, -3.05), 0.07, "gunmetal_w", null, 8)
		VmHeli._tube(k, b, Vector3(s * 0.84, 1.5, -3.2), Vector3(s * 1.06, 0.5, -3.08), 0.055, "steel", null, 8)
		k._wheel(b, Vector3(s * 1.12, 0.34, -3.05), 0.34, 0.22)
	# --- the M230 chain gun in its turret under the chin
	var t := k._pivot(b, Vector3(0, 0.92, -3.85))
	k.turret = t
	k._cyl(t, 0.24, 0.28, 0.16, Vector3(0, 0.02, 0), Vector3.ZERO, mat, col, 12)
	_bx(k, t, Vector3(0.24, 0.26, 0.56), Vector3(0, -0.2, -0.05), "gunmetal_w")
	_bx(k, t, Vector3(0.16, 0.14, 0.34), Vector3(0.18, -0.16, 0.12), "gunmetal_w")
	k._cyl(t, 0.062, 0.062, 0.42, Vector3(0, -0.22, -0.52), X90, "gunmetal_w", null, 10)
	k._cyl(t, 0.036, 0.036, 1.12, Vector3(0, -0.22, -1.28), X90, "gunmetal_w", null, 8)
	k._cyl(t, 0.058, 0.05, 0.18, Vector3(0, -0.22, -1.9), X90, "gunmetal_w", null, 10)
	k.mg_tip = k._tip(t, Vector3(0, -0.22, -2.01))
	# --- the mast, the rotor and the Longbow radar dome over it
	k._cyl(b, 0.16, 0.22, 0.9, Vector3(0, 3.33, -1.2), Vector3.ZERO, "gunmetal_w", null, 10)
	VmHeli._rotor(k, b, Vector3(0, 3.82, -1.2), 4, 7.3, 0.53, true, PI / 4, 0.02, 0.36, 1)
	k._cyl(b, 0.09, 0.11, 0.42, Vector3(0, 4.17, -1.2), Vector3.ZERO, "gunmetal_w", null, 8)
	k._cyl(b, 0.56, 0.56, 0.16, Vector3(0, 4.45, -1.2), Vector3.ZERO, mat, col, 18)
	k._add(b, Res.sphere(0.56, 16), mat, col, Vector3(0, 4.52, -1.2), Vector3.ZERO, Vector3(1.0, 0.32, 1.0))
	k._add(b, Res.sphere(0.56, 16), mat, col, Vector3(0, 4.38, -1.2), Vector3.ZERO, Vector3(1.0, 0.18, 1.0))
	# antennas along the boom
	VmHeli._tube(k, b, Vector3(0, 2.5, 3.4), Vector3(0, 2.78, 3.7), 0.014, "gunmetal_w", null, 4)
	_bx(k, b, Vector3(0.03, 0.18, 0.26), Vector3(0, 1.0, 1.2), "gunmetal_w")


## A 230-gallon external fuel tank along z, centred at pos.
static func _fuel_tank(k: VehicleModels, p: Node3D, pos: Vector3, r: float, ln: float, mat: String, col) -> void:
	k._cyl(p, r, r, ln * 0.7, pos, X90, mat, col, 16)
	k._add(p, Res.sphere(r, 16), mat, col, pos + Vector3(0, 0, -ln * 0.35), Vector3.ZERO, Vector3(1.0, 1.0, 1.7))
	k._add(p, Res.sphere(r, 16), mat, col, pos + Vector3(0, 0, ln * 0.35), Vector3.ZERO, Vector3(1.0, 1.0, 1.5))
	_bx(k, p, Vector3(0.06, 0.14, ln * 0.4), pos + Vector3(0, r + 0.05, 0), "gunmetal_w", null, Vector3.ZERO, false)


## UH-60 Black Hawk: the rounded nose and the big two-pane windscreen with
## the eyebrow windows over it, the cockpit doors, the gunners' windows, the
## wide cabin with its big sliding doors; the engines either side of the
## gearbox on the roof with their exhaust suppressors, the four-blade rotor
## with swept tips and the bifilar absorber on its hub, the long tapering
## boom with the swept pylon, the canted tail rotor high on its right and
## the big stabilator low across it; fixed main gear on drag beams, the
## tailwheel; the stores wings with a fuel tank each side.
static func _blackhawk(k: VehicleModels, team: int) -> void:
	var b := _airframe(k)
	var mat := "aircraft"
	var col: Color = HELO_DRAB if team != 1 else HELO_SAND
	var dark := Color(0.06, 0.06, 0.06)
	var h := VmHeli.Hull.new([
		[-7.0, 1.28, 0.12, 0.12, 0.14],
		[-6.8, 1.3, 0.55, 0.42, 0.5],
		[-6.35, 1.38, 0.88, 0.7, 0.72],
		[-5.7, 1.48, 1.06, 0.92, 0.84],
		[-4.8, 1.55, 1.14, 1.0, 0.9],
		[-2.2, 1.58, 1.18, 1.02, 0.92],
		[0.3, 1.62, 1.15, 0.98, 0.92],
		[1.3, 1.78, 0.92, 0.8, 0.68],
		[2.7, 2.0, 0.5, 0.48, 0.38],
		[6.3, 2.14, 0.32, 0.34, 0.27],
		[7.6, 2.22, 0.22, 0.28, 0.2],
	], 16, 2.8)
	VmHeli._hull(k, b, h, "core_uh_body", mat, col)
	# glazing: the two-pane windscreen, the eyebrow windows over it, the
	# cockpit doors' windows, the gunners' windows, the cabin doors' windows
	VmHeli._patch(k, b, h, "core_uh_ws", -6.72, -5.62, 1.15, 3.85, "glass", null, 0.012, 0.05)
	VmHeli._patch(k, b, h, "core_uh_eye", -5.55, -4.95, 3.1, 3.88, "glass", null, 0.012, 0.05)
	VmHeli._patch(k, b, h, "core_uh_cw", -5.3, -4.25, -0.2, 1.75, "glass", null, 0.012, 0.05)
	VmHeli._patch(k, b, h, "core_uh_gw", -4.05, -3.55, 0.05, 1.4, "glass", null, 0.012, 0.05)
	for z0: float in [-3.12, -2.3]:
		VmHeli._patch(k, b, h, "core_uh_dw%d" % int(-z0 * 10), z0, z0 + 0.62, 0.3, 1.35, "glass", null, 0.012, 0.05)
	VmHeli._patch(k, b, h, "core_uh_rw", -1.2, -0.75, 0.4, 1.2, "glass", null, 0.012, 0.05)
	# the frame between the windscreen panes, the door seams and the cabin
	# door's rail, the steps
	VmHeli._patch(k, b, h, "core_uh_post", -6.72, -5.62, 3.92, 4.08, mat, col, 0.024, 0.02, 1.0)
	for z: float in [-5.35, -4.15, -3.4, -1.5]:
		VmHeli._patch(k, b, h, "core_uh_seam%d" % int(-z * 100), z - 0.014, z + 0.014, -2.6, 1.9, "gunmetal_w", null, 0.008)
	VmHeli._patch(k, b, h, "core_uh_rail", -3.4, 0.4, 1.92, 2.04, "gunmetal_w", null, 0.02)
	VmHeli._patch(k, b, h, "core_uh_sill", -3.4, -1.5, -2.65, -2.5, "gunmetal_w", null, 0.02)
	# the nose: the radome's seam, pitots on the roof, the wire cutters
	VmHeli._patch(k, b, h, "core_uh_nose", -6.6, -6.56, -4.0, 0.9, "gunmetal_w", null, 0.008)
	for s: float in [-1.0, 1.0]:
		VmHeli._tube(k, b, Vector3(s * 0.35, 2.32, -5.4), Vector3(s * 0.35, 2.3, -6.0), 0.02, "steel", null, 4)
		_bx(k, b, Vector3(0.12, 0.04, 0.3), Vector3(s * 1.2, 0.68, -4.7), "gunmetal_w")
		_bx(k, b, Vector3(0.05, 0.05, 0.06), Vector3(s * 1.14, 2.36, -4.3), "plain", Color(0.6, 0.1, 0.08) if s < 0.0 else Color(0.1, 0.5, 0.2), Vector3.ZERO, false)
	VmHeli._tube(k, b, Vector3(0, 2.45, -5.0), Vector3(0, 2.78, -5.35), 0.03, "steel", null, 4)
	VmHeli._tube(k, b, Vector3(0, 0.66, -5.9), Vector3(0, 0.5, -6.25), 0.03, "steel", null, 4)
	# --- the roof: the gearbox fairing, the engines either side with their
	# dark intakes and the exhaust suppressors turned out, the IR jammer
	k._add(b, VehicleModels.loft("core_uh_top", [-0.8, -3.7, 0.8, -3.7, 1.0, -3.0, 1.0, 0.8, 0.62, 1.7, -0.62, 1.7, -1.0, 0.8, -1.0, -3.0],
		[-0.42, -3.2, 0.42, -3.2, 0.58, -2.7, 0.58, 0.5, 0.34, 1.3, -0.34, 1.3, -0.58, 0.5, -0.58, -2.7], 2.45, 3.1), mat, col, Vector3.ZERO)
	var eng := VmHeli.Hull.new([[-2.85, 2.82, 0.22, 0.22, 0.22], [-2.65, 2.82, 0.36, 0.34, 0.32], [0.2, 2.82, 0.38, 0.36, 0.32], [0.7, 2.82, 0.3, 0.28, 0.26]], 12, 2.4)
	for s: float in [-1.0, 1.0]:
		k._add(b, eng.mesh("core_uh_eng"), mat, col, Vector3(s * 0.9, 0, 0))
		k._cyl(b, 0.25, 0.25, 0.04, Vector3(s * 0.9, 2.82, -2.87), X90, "plain", dark, 12, false)
		k._cyl(b, 0.08, 0.08, 0.1, Vector3(s * 0.9, 2.82, -2.9), X90, "gunmetal_w", null, 8, false)
		k._add(b, VehicleModels.loft("core_uh_hirss", [-0.22, 0.0, 0.22, 0.0, 0.2, 1.1, -0.2, 1.1], [-0.16, 0.06, 0.16, 0.06, 0.13, 1.0, -0.13, 1.0], 0.0, 0.42), mat, col, Vector3(s * 0.95, 2.6, 0.62), Vector3(0, s * 0.42, 0))
		_bx(k, b, Vector3(0.28, 0.03, 0.7), Vector3(s * 1.2, 3.03, 1.25), "plain", dark, Vector3(0, s * 0.42, 0), false)
	k._cyl(b, 0.16, 0.18, 0.32, Vector3(0, 3.22, 1.1), Vector3.ZERO, "gunmetal_w", null, 10)
	k._add(b, Res.sphere(0.16, 10), "glass", null, Vector3(0, 3.42, 1.1))
	# --- the mast and the rotor: swept tips, the bifilar absorber on the hub
	k._cyl(b, 0.18, 0.22, 0.55, Vector3(0, 3.3, -2.0), Vector3.ZERO, "gunmetal_w", null, 10)
	k._cyl(b, 0.36, 0.36, 0.06, Vector3(0, 3.28, -2.0), Vector3.ZERO, "steel", null, 12)
	VmHeli._rotor(k, b, Vector3(0, 3.62, -2.0), 4, 8.18, 0.53, true, PI / 4, 0.02, 0.42, 1)
	k._cyl(k.rotor, 0.16, 0.2, 0.3, Vector3(0, 0.3, 0), Vector3.ZERO, "gunmetal_w", null, 10)
	for i in 4:
		var a := PI / 4 + i * PI / 2
		var d := Vector3(sin(a), 0, cos(a))
		_bx(k, k.rotor, Vector3(0.08, 0.06, 0.5), d * 0.25 + Vector3(0, 0.42, 0), "gunmetal_w", null, Vector3(0, a, 0), false)
		k._add(k.rotor, Res.sphere(0.09, 8), "gunmetal_w", null, d * 0.5 + Vector3(0, 0.42, 0))
	# --- the stores wings over the cabin's rear, braced to the floor, a fuel
	# tank on each
	for s: float in [-1.0, 1.0]:
		_bx(k, b, Vector3(1.9, 0.12, 0.8), Vector3(s * 1.95, 2.18, -0.5), mat, col, Vector3(0, 0, -s * 0.12))
		VmHeli._tube(k, b, Vector3(s * 2.3, 2.1, -0.5), Vector3(s * 1.1, 0.95, -0.5), 0.045, "gunmetal_w", null, 6)
		_bx(k, b, Vector3(0.1, 0.3, 0.8), Vector3(s * 2.15, 1.95, -0.5), "gunmetal_w")
		_fuel_tank(k, b, Vector3(s * 2.15, 1.42, -0.6), 0.34, 3.0, mat, col)
	# --- the tail: the swept pylon, the canted tail rotor on its right, the
	# stabilator, the antenna along the boom, the tailwheel
	k._add(b, VehicleModels.extrude_x("core_uh_pylon", [6.25, 2.25, 7.8, 2.2, 8.3, 4.28, 7.6, 4.4], -0.13, 0.13), mat, col, Vector3.ZERO)
	_bx(k, b, Vector3(0.28, 0.36, 0.5), Vector3(0.16, 3.5, 7.93), mat, col)
	var cant := k._pivot(b, Vector3(0.38, 3.5, 7.93))
	cant.rotation.z = 0.35
	VmHeli._tail_rotor(k, cant, Vector3.ZERO, 4, 1.68, 0.25, 1.0, 0.3)
	k._add(b, VehicleModels.loft("core_uh_stab", [-0.3, 7.32, 0.3, 7.32, 2.2, 7.6, 2.2, 8.3, -2.2, 8.3, -2.2, 7.6],
		[-0.3, 7.36, 0.3, 7.36, 2.2, 7.63, 2.2, 8.26, -2.2, 8.26, -2.2, 7.63], 2.12, 2.22), mat, col, Vector3.ZERO)
	k._add(b, Res.sphere(0.06, 8), "plain", Color(0.55, 0.08, 0.06), Vector3(0, 4.42, 7.65))
	VmHeli._tube(k, b, Vector3(0, 2.52, 3.0), Vector3(0, 2.6, 5.6), 0.02, "gunmetal_w", null, 4)
	for z: float in [3.0, 5.6]:
		VmHeli._tube(k, b, Vector3(0, 2.42, z), Vector3(0, 2.6, z), 0.015, "gunmetal_w", null, 4)
	VmHeli._tube(k, b, Vector3(0, 1.92, 6.05), Vector3(0, 0.36, 6.4), 0.06, "gunmetal_w", null, 8)
	VmHeli._tube(k, b, Vector3(0, 1.86, 5.55), Vector3(0, 0.9, 6.25), 0.04, "steel", null, 6)
	_bx(k, b, Vector3(0.26, 0.08, 0.2), Vector3(0, 0.4, 6.42), "gunmetal_w")
	k._wheel(b, Vector3(0, 0.24, 6.48), 0.24, 0.16)
	for s: float in [-1.0, 1.0]:
		k._team_mark(b, team, Vector3(s * 0.37, 2.12, 4.6), Vector3(0.02, 0.24, 0.9))
	# --- main gear: the drag beam and the shock strut to each wheel
	for s: float in [-1.0, 1.0]:
		VmHeli._tube(k, b, Vector3(s * 0.8, 0.66, -4.35), Vector3(s * 1.38, 0.4, -3.95), 0.07, "gunmetal_w", null, 8)
		VmHeli._tube(k, b, Vector3(s * 1.12, 1.35, -3.8), Vector3(s * 1.4, 0.5, -3.92), 0.08, "gunmetal_w", null, 8)
		VmHeli._tube(k, b, Vector3(s * 1.16, 1.2, -3.82), Vector3(s * 1.36, 0.62, -3.92), 0.11, "steel", null, 8)
		k._wheel(b, Vector3(s * 1.5, 0.38, -3.95), 0.38, 0.26)


# --- truck: the fallback convoy truck ---------------------------------------------

## A generic 6x6 cargo truck, an M35A2 "deuce and a half" (full scale): the
## narrow bonnet between flat-topped wings with the headlights on them and the
## brush guard across its nose, the boxy cab with its flat two-pane
## windscreen, the spare wheel behind it, the cargo bed on the tandem axles
## under its canvas tilt and bows. (The convoy is the HEMTT or the Zamak; this
## stands in only if those can't be built.)
static func _truck(k: VehicleModels, team: int) -> void:
	var m := k.root
	var col := Color(0.32, 0.35, 0.25) if team != 1 else Color(0.45, 0.39, 0.29)
	var wr := 0.5
	var axles := [-2.15, 1.05, 2.4]
	# the chassis: frame rails, the axles and their diffs, the wheels
	_bx(k, m, Vector3(0.86, 0.24, 6.2), Vector3(0, 0.84, 0.15), "gunmetal_w")
	for z in axles:
		k._cyl(m, 0.07, 0.07, 1.7, Vector3(0, wr, z), Z90, "gunmetal_w", null, 8)
		k._add(m, Res.sphere(0.2, 10), "gunmetal_w", null, Vector3(0.1, wr, z), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
		for s: float in [-1.0, 1.0]:
			k._wheel(m, Vector3(s * 0.95, wr, z), wr, 0.38)
	# the bonnet, the flat wings over the front wheels with the headlights on
	# them, the brush guard, the bumper and its tow hooks
	k._add(m, VehicleModels.loft("core_trk_hood", [-0.56, -3.22, 0.56, -3.22, 0.56, -1.85, -0.56, -1.85], [-0.5, -3.16, 0.5, -3.16, 0.52, -1.85, -0.52, -1.85], 0.95, 1.66), "paint", col, Vector3.ZERO)
	for i in 4:
		_bx(k, m, Vector3(0.012, 0.6, 0.02), Vector3(-0.15 + i * 0.1, 1.35, -3.2), "plain_dark", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.6, 0.04, 1.6), Vector3(s * 0.86, 1.24, -2.42), "paint", col)
		_bx(k, m, Vector3(0.04, 0.3, 1.6), Vector3(s * 0.58, 1.1, -2.42), "paint", col)
		_bx(k, m, Vector3(0.58, 0.04, 0.4), Vector3(s * 0.86, 1.12, -3.3), "paint", col, Vector3(-0.6, 0, 0))
		_lamp(k, m, Vector3(s * 0.86, 1.38, -3.05), 0.08)
		_shackle(k, m, Vector3(s * 0.6, 0.86, -3.45))
		# the louvres down the bonnet's sides
		for i in 4:
			_bx(k, m, Vector3(0.012, 0.03, 0.4), Vector3(s * 0.555, 1.32 + i * 0.07, -2.5), "plain_dark", null, Vector3.ZERO, false)
	_path(k, m, [Vector3(-0.62, 0.95, -3.4), Vector3(-0.62, 1.62, -3.36), Vector3(0.62, 1.62, -3.36), Vector3(0.62, 0.95, -3.4)], 0.025, "gunmetal_w", null, 6)
	for x: float in [-0.3, 0.0, 0.3]:
		_tube(k, m, Vector3(x, 1.0, -3.39), Vector3(x, 1.62, -3.36), 0.02, "gunmetal_w", null, 6)
	_bx(k, m, Vector3(2.3, 0.22, 0.2), Vector3(0, 0.84, -3.38), "paint", col.darkened(0.25))
	# the cab: its walls lofted up to the roof, the flat windscreen in two
	# panes, door windows, the doors' seams, mirrors on their arms
	var lo := [-1.08, -1.88, 1.08, -1.88, 1.08, -0.62, -1.08, -0.62]
	var hi := [-1.04, -1.82, 1.04, -1.82, 1.04, -0.66, -1.04, -0.66]
	VmCiv._yloft(k, m, "core_trk_cab", [lo, hi], [1.1, 2.55], 0.04, "paint", col)
	if not k.burnt:
		for s: float in [-1.0, 1.0]:
			_bx(k, m, Vector3(0.9, 0.55, 0.02), Vector3(s * 0.5, 2.15, -1.84), "glass", null, Vector3(0.06, 0, 0), false)
			_bx(k, m, Vector3(0.02, 0.45, 0.6), Vector3(s * 1.065, 2.12, -1.3), "glass", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.012, 1.1, 0.012), Vector3(s * 1.085, 1.7, -0.7), "plain_dark", null, Vector3.ZERO, false)
		_bx(k, m, Vector3(0.03, 0.04, 0.14), Vector3(s * 1.09, 1.72, -0.95), "gunmetal_w", null, Vector3.ZERO, false)
		_bar(k, m, Vector3(s * 1.06, 2.2, -1.8), Vector3(s * 1.32, 2.15, -1.82), 0.03, 0.03, "gunmetal_w", null, false)
		_bx(k, m, Vector3(0.05, 0.38, 0.2), Vector3(s * 1.34, 2.08, -1.82), "gunmetal_w")
		_bx(k, m, Vector3(0.3, 0.04, 0.22), Vector3(s * 0.98, 0.72, -1.25), "gunmetal_w")
		k._team_mark(m, team, Vector3(s * 1.09, 1.55, -1.35), Vector3(0.02, 0.24, 0.5))
	# behind the cab: the spare wheel standing up, the fuel tank, a tool box
	VmNato._spare(k, m, Vector3(0.45, 1.75, -0.45), 0.48, 0.3, Vector3(PI / 2, 0, 0))
	k._cyl(m, 0.22, 0.22, 0.9, Vector3(-1.0, 0.92, 0.1), X90, "paint", col.darkened(0.1), 12)
	_bx(k, m, Vector3(0.36, 0.34, 0.6), Vector3(1.0, 0.95, 0.1), "paint", col.darkened(0.1))
	# the cargo bed: floor, sides and the tailgate, the canvas tilt on its
	# bows, the rope lashing, tail lights, mudflaps and the pintle
	_bx(k, m, Vector3(2.3, 0.14, 3.4), Vector3(0, 1.3, 1.35), "wood_dark")
	for s: float in [-1.0, 1.0]:
		_bx(k, m, Vector3(0.06, 0.5, 3.4), Vector3(s * 1.15, 1.6, 1.35), "paint", col)
		_bx(k, m, Vector3(0.36, 0.4, 0.03), Vector3(s * 0.95, 0.5, 3.15), "rubber")
		_taillight(k, m, Vector3(s * 0.9, 1.1, 3.08))
	_bx(k, m, Vector3(2.3, 0.5, 0.06), Vector3(0, 1.6, 3.05), "paint", col)
	var tarp := col.lightened(0.08)
	_bx(k, m, Vector3(2.32, 0.9, 3.36), Vector3(0, 2.25, 1.35), "canvas", tarp)
	k._add(m, Res.cyl(1.16, 1.16, 3.36, 16), "canvas", tarp, Vector3(0, 2.7, 1.35), X90, Vector3(1.0, 1.0, 0.42))
	for i in 4:
		var z := -0.28 + i * 1.1
		_bx(k, m, Vector3(2.36, 0.9, 0.05), Vector3(0, 2.25, z), "canvas", tarp.darkened(0.15))
	for x: float in [-0.7, 0.0, 0.7]:
		_bx(k, m, Vector3(0.025, 1.0, 0.02), Vector3(x, 2.25, 3.04), "canvas", tarp.darkened(0.25), Vector3.ZERO, false)
	_bx(k, m, Vector3(0.18, 0.16, 0.2), Vector3(0, 0.84, 3.15), "gunmetal_w")
	_antenna(k, m, Vector3(-1.0, 2.55, -0.8), 1.8)


## Mirrors plan outline pairs (x, z) to the other side, keeping the winding.
static func _mirror(pairs: Array) -> Array:
	var o := []
	for i in range(pairs.size() - 2, -1, -2):
		o.append(-float(pairs[i]))
		o.append(pairs[i + 1])
	return o
