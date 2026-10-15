class_name DockModel
extends RefCounted
## A small naval yard on a shoreline: a quay along the water's edge, a
## concrete slipway running down into the water under an open-fronted
## corrugated boat shed, a jetty on piles reaching out over the water with
## bollards and tyre fenders, a pillar jib crane on the quay, fuel, stacked
## crates and the side's flag. The Coalition's is tidy steel and concrete in
## grey-green; the Rebels' is improvised: timber, rust, mismatched sheets.
##
## Local -Z faces the water. `size` is the land footprint (x wide, z deep)
## round the origin, its -Z edge the quay; the jetty runs on JETTY metres
## beyond it, the slipway about 6. y = 0 is the ground; the water lies at
## WATER and the bed falls from about -0.7 at the quay to BED under the
## jetty's head (piles and walls reach down past it, into the ground).

const WATER := -0.45
const BED := -3.0
const JETTY := 14.0


static func build(model: Node3D, team: int, size: Vector3) -> void:
	var rebel := team == 1
	var w := maxf(size.x, 10.0)
	var d := maxf(size.z, 8.0)
	var zq := -d * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173 + team * 31
	# the slipway and its shed on the left, the jetty on the right, the crane between
	var sx := -w * 0.5 + 2.9
	var sw := 3.6
	var jx := w * 0.5 - 3.2
	var jw := 3.0
	_ground(model, rebel, w, d, sx, sw, rng)
	_quay(model, rebel, w, zq, sx, sw, jx, jw, rng)
	_slipway(model, rebel, d, zq, sx, sw)
	_shed(model, rebel, d, zq, sx, rng)
	_jetty(model, rebel, zq, jx, jw, rng)
	_crane(model, rebel, Vector3((sx + sw * 0.5 + jx - jw * 0.5) * 0.5, 0.0, zq + 1.0))
	_fuel(model, rebel, w, d, zq, jx, jw, rng)
	_flagpole(model, team, Vector3(w * 0.5 - 0.7, 0.0, zq + 2.3))
	_crates(model, rebel, Vector3(sx + 2.45 + 2.2, 0.0, zq + d * 0.62), rng)


# --- helpers ---------------------------------------------------------------------------

static func _mk(model: Node3D, mesh: Mesh, kind: String, p: Vector3, rot := Vector3.ZERO, col = null, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = p
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(mi)
	Mats.apply(mi, kind, Mats.tint_for(kind, col) if col is Color else Color(1, 1, 1))
	return mi


## (small parts plain boxes, see VmShips._box_mesh)
static func _box(model: Node3D, s: Vector3, p: Vector3, kind: String, col = null, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	return _mk(model, VmShips._box_mesh(s), kind, p, rot, col, shadow)


static func _cyl(model: Node3D, r0: float, r1: float, h: float, p: Vector3, rot: Vector3, kind: String, col = null, segs := 10, shadow := true) -> MeshInstance3D:
	return _mk(model, Res.cyl(r0, r1, h, segs), kind, p, rot, col, shadow)


## A rod from a to b.
static func _rod(model: Node3D, a: Vector3, b: Vector3, r: float, kind: String, col = null, segs := 6, shadow := false) -> void:
	_mk(model, VmShips._tube(r, a.distance_to(b), segs if r >= 0.03 else mini(segs, 4)), kind, (a + b) * 0.5, VmBoat._aim(b - a), col, shadow)


## A box from a to b (a beam, a plank on a slope), w x h across it.
static func _beam(model: Node3D, a: Vector3, b: Vector3, w: float, h: float, kind: String, col = null, shadow := true) -> void:
	var dv := b - a
	var yaw := atan2(-dv.x, -dv.z)
	var pitch := atan2(dv.y, Vector2(dv.x, dv.z).length())
	_box(model, Vector3(w, h, dv.length()), (a + b) * 0.5, kind, col, Vector3(pitch, yaw, 0), shadow)


## A solid between two outlines in the x-y plane (same point count), at z0 and z1.
static func _xsec(model: Node3D, key: String, a: Array, z0: float, b: Array, z1: float, kind: String, col = null) -> MeshInstance3D:
	return _mk(model, VehicleModels.solid([VmBoat._rz(a, z0), VmBoat._rz(b, z1)], key), kind, Vector3.ZERO, Vector3.ZERO, col)


## The bed's height at z (the quay's edge at zq).
static func _bed(zq: float, z: float) -> float:
	return lerpf(-0.7, BED, clampf((zq - z) / JETTY, 0.0, 1.0))


## A mooring bollard (a squat post with a cap and a lip).
static func _bollard(model: Node3D, p: Vector3, kind: String, col) -> void:
	_cyl(model, 0.15, 0.18, 0.34, p + Vector3(0, 0.17, 0), Vector3.ZERO, kind, col, 12)
	_cyl(model, 0.21, 0.21, 0.05, p + Vector3(0, 0.36, 0), Vector3.ZERO, kind, col, 12, false)
	_cyl(model, 0.26, 0.28, 0.04, p + Vector3(0, 0.02, 0), Vector3.ZERO, kind, col, 12, false)


## A tyre hung as a fender, its face out along `nrm`, on a rope from `hang`.
static func _tyre(model: Node3D, p: Vector3, nrm: Vector3, hang: Vector3) -> void:
	var yaw := atan2(nrm.x, nrm.z)
	var tr := _mk(model, VmShips._torus(0.2, 0.38), "rubber", p, (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2)).get_euler(), Color(0.07, 0.07, 0.07))
	tr.scale = Vector3(1, 1.4, 1)
	_rod(model, p + Vector3(0, 0.32, 0), hang, 0.015, "canvas", Color(0.45, 0.4, 0.3), 4)


## A 200-litre drum standing at p (or lying, axis along `yaw`).
static func _drum(model: Node3D, p: Vector3, col: Color, lying := false, yaw := 0.0) -> void:
	var rot := Vector3(0, yaw, PI / 2) if lying else Vector3.ZERO
	var c := p + (Vector3(0, 0.29, 0) if lying else Vector3(0, 0.44, 0))
	_cyl(model, 0.29, 0.29, 0.88, c, rot, "steel", col, 14)
	var ax := Basis.from_euler(rot) * Vector3.UP
	for e in [-0.28, 0.0, 0.28]:
		_cyl(model, 0.3, 0.3, 0.03, c + ax * e, rot, "steel", col.darkened(0.15), 14, false)


## A crate (w x h x l) with battens round it.
static func _crate(model: Node3D, p: Vector3, s: Vector3, yaw: float, kind: String, col) -> void:
	_box(model, s, p + Vector3(0, s.y * 0.5, 0), kind, col, Vector3(0, yaw, 0))
	var b := Basis(Vector3.UP, yaw)
	for e in [-1.0, 1.0]:
		_box(model, Vector3(s.x + 0.02, 0.06, 0.06), p + b * Vector3(0, s.y * 0.5, e * (s.z * 0.5 - 0.02)) + Vector3(0, 0.0, 0), kind, col.darkened(0.12) if col is Color else Color(0.3, 0.22, 0.14), Vector3(0, yaw, 0))


# --- the ground ---------------------------------------------------------------------

## The yard's ground: a concrete apron (the Rebels': packed earth with old
## slabs) on a block of fill, cut where the slipway goes down.
static func _ground(model: Node3D, rebel: bool, w: float, d: float, sx: float, sw: float, rng: RandomNumberGenerator) -> void:
	var kind := "concrete" if not rebel else "earth"
	var col := Color(0.55, 0.54, 0.5) if not rebel else Color(0.36, 0.3, 0.22)
	var top := 0.03
	var x0 := sx - sw * 0.5 - 0.3
	var x1 := sx + sw * 0.5 + 0.3
	# left of the slip, right of it, and behind the ramp's head
	_box(model, Vector3(x0 + w * 0.5, 1.2, d), Vector3((x0 - w * 0.5) * 0.5, top - 0.6, 0), kind, col)
	_box(model, Vector3(w * 0.5 - x1, 1.2, d), Vector3((x1 + w * 0.5) * 0.5, top - 0.6, 0), kind, col)
	if not rebel:
		# expansion joints, a painted safety line along the quay
		var i := 1
		while -w * 0.5 + i * 3.0 < w * 0.5:
			var x := -w * 0.5 + i * 3.0
			if x < x0 - 0.2 or x > x1 + 0.2:
				_box(model, Vector3(0.03, 0.012, d - 0.1), Vector3(x, top, 0), "plain_dark", Color(0.2, 0.2, 0.19), Vector3.ZERO, false)
			i += 1
		for j in range(1, int(d / 3.0)):
			var z := -d * 0.5 + j * 3.0
			_box(model, Vector3(x0 + w * 0.5 - 0.1, 0.012, 0.03), Vector3((x0 - w * 0.5) * 0.5, top, z), "plain_dark", Color(0.2, 0.2, 0.19), Vector3.ZERO, false)
			_box(model, Vector3(w * 0.5 - x1 - 0.1, 0.012, 0.03), Vector3((x1 + w * 0.5) * 0.5, top, z), "plain_dark", Color(0.2, 0.2, 0.19), Vector3.ZERO, false)
		_box(model, Vector3(w * 0.5 - x1 - 0.4, 0.012, 0.12), Vector3((x1 + w * 0.5) * 0.5, top, -d * 0.5 + 0.7), "paint", Color(0.8, 0.66, 0.12), Vector3.ZERO, false)
	else:
		# old broken slabs, a gravel patch, planks laid over the mud
		for q in [[2.0, 1.5, 2.2, 1.6], [-0.5, 3.5, 1.8, 1.4], [4.5, -2.6, 2.0, 1.5], [1.5, -3.4, 1.4, 1.2]]:
			_box(model, Vector3(q[2], 0.12, q[3]), Vector3(q[0], top - 0.01, q[1]), "concrete", Color(0.4, 0.39, 0.36), Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.03, 0.03)))
		for i in 5:
			_box(model, Vector3(0.28, 0.05, 2.6), Vector3(x1 + 0.6 + i * 0.32, top + 0.02, d * 0.5 - 2.2), "wood", Color(0.42, 0.33, 0.22), Vector3(0, rng.randf_range(-0.05, 0.05), 0))


# --- the quay -------------------------------------------------------------------------

## The quay along the water's edge (z = zq), either side of the slipway: a
## concrete wall with a coping, rubber fenders and bollards; the Rebels' a
## timber pile wall with rocks heaped at its foot.
static func _quay(model: Node3D, rebel: bool, w: float, zq: float, sx: float, sw: float, jx: float, jw: float, rng: RandomNumberGenerator) -> void:
	var x0 := sx - sw * 0.5 - 0.3
	var x1 := sx + sw * 0.5 + 0.3
	for run in [[-w * 0.5, x0], [x1, w * 0.5]]:
		var a: float = run[0]
		var b: float = run[1]
		var l := b - a
		var c := (a + b) * 0.5
		if not rebel:
			_box(model, Vector3(l, 2.6, 0.6), Vector3(c, -1.27, zq + 0.3), "concrete", Color(0.5, 0.49, 0.46))
			_box(model, Vector3(l, 0.22, 0.7), Vector3(c, -0.07, zq + 0.3), "concrete", Color(0.6, 0.59, 0.55))
			# weed and staining along the tide line
			_box(model, Vector3(l, 0.35, 0.02), Vector3(c, WATER + 0.02, zq - 0.005), "plain", Color(0.16, 0.2, 0.13), Vector3.ZERO, false)
			var n := int(l / 2.4)
			for i in n:
				var x := a + (i + 0.5) * l / n
				if absf(x - jx) < jw * 0.5 + 0.4:
					continue
				_box(model, Vector3(0.3, 1.1, 0.16), Vector3(x, -0.6, zq - 0.08), "rubber", Color(0.08, 0.08, 0.08))
				if i % 2 == 0:
					_bollard(model, Vector3(x + 0.7, 0.04, zq + 0.35), "metal_dark", Color(0.14, 0.15, 0.14))
		else:
			# timber piles driven side by side, wales across them, a capping beam
			var n := int(l / 0.42)
			for i in n:
				var x := a + (i + 0.5) * l / n
				_cyl(model, 0.16, 0.17, 2.7, Vector3(x, -1.25 + rng.randf_range(-0.05, 0.08), zq + 0.18), Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.03, 0.03)), "bark", Color(0.3, 0.25, 0.19), 7)
			for y in [-0.25, -0.95]:
				_box(model, Vector3(l, 0.22, 0.12), Vector3(c, y, zq - 0.02), "wood_dark", Color(0.3, 0.22, 0.15), Vector3(0, 0, rng.randf_range(-0.01, 0.01)))
			_box(model, Vector3(l, 0.24, 0.4), Vector3(c, -0.06, zq + 0.2), "wood_dark", Color(0.33, 0.25, 0.17))
			# rocks heaped at the foot of the wall
			var k := int(l / 0.9)
			for i in k:
				var x := a + (i + rng.randf()) * l / k
				var r := rng.randf_range(0.35, 0.6)
				_mk(model, Res.sphere(r, 8), "stone", Vector3(x, WATER - 0.2 + rng.randf_range(-0.1, 0.15), zq - 0.35 - rng.randf() * 0.4), Vector3(rng.randf() * 3.0, rng.randf() * 3.0, 0), Color(0.45, 0.43, 0.4)).scale = Vector3(1.2, 0.7, 1.0)
			for i in 3:
				var x := a + (i + 0.5) * l / 3.0
				if absf(x - jx) < jw * 0.5 + 0.5:
					continue
				_tyre(model, Vector3(x, -0.6, zq - 0.25), Vector3(0, 0, -1), Vector3(x, 0.05, zq + 0.1))
				_bollard(model, Vector3(x + 0.6, 0.06, zq + 0.3), "steel", Color(0.32, 0.2, 0.12))
		# a ladder down the wall to the water
		if b - a > 4.0 and run[0] > -w * 0.5 + 0.1:
			var lx := a + 1.2
			for side in [-0.22, 0.22]:
				_rod(model, Vector3(lx + side, 0.9, zq - 0.08), Vector3(lx + side, -2.2, zq - 0.08), 0.025, "steel", Color(0.3, 0.3, 0.28) if not rebel else Color(0.36, 0.2, 0.1), 6, true)
			for i in 9:
				_rod(model, Vector3(lx - 0.22, -0.1 - i * 0.28, zq - 0.08), Vector3(lx + 0.22, -0.1 - i * 0.28, zq - 0.08), 0.018, "steel", Color(0.3, 0.3, 0.28) if not rebel else Color(0.36, 0.2, 0.1))


# --- the slipway ------------------------------------------------------------------------

## The slipway: a concrete ramp (about 1 in 4.3) from the shed's floor down
## into the water, kerbed both sides, with grooves for grip, rails for the
## launching trolley, weed below the tide line; the winch at its head.
static func _slipway(model: Node3D, rebel: bool, d: float, zq: float, sx: float, sw: float) -> void:
	var zh := zq + 2.0  # the ramp's head
	var ze := zq - 6.0  # its toe, under the water
	var ye := -1.85
	var x0 := sx - sw * 0.5
	var x1 := sx + sw * 0.5
	var conc := Color(0.56, 0.55, 0.51) if not rebel else Color(0.48, 0.47, 0.43)
	var key := "dock_slip_%.2f_%.2f_%.2f" % [sw, d, sx]
	_xsec(model, key, [x0, 0.0, x1, 0.0, x1, -2.6, x0, -2.6], zh, [x0, ye, x1, ye, x1, -2.6, x0, -2.6], ze, "concrete", conc)
	# the flat floor in the shed
	_box(model, Vector3(sw + 0.6, 1.2, d * 0.5 - zh), Vector3(sx, -0.57, (zh + d * 0.5) * 0.5), "concrete", conc)
	# kerbs both sides of the ramp, down to its toe
	for e in [-1.0, 1.0]:
		var xa: float = sx + e * (sw * 0.5 + 0.15)
		_xsec(model, key + "_k%d" % int(e), [xa - 0.15, 0.2, xa + 0.15, 0.2, xa + 0.15, -2.6, xa - 0.15, -2.6], zh + 0.4,
			[xa - 0.15, ye + 0.2, xa + 0.15, ye + 0.2, xa + 0.15, -2.6, xa - 0.15, -2.6], ze, "concrete", conc.darkened(0.08))
	var slope := atan2(-ye, zh - ze)
	var n := int((zh - ze) / 0.45)
	for i in n:
		var t := (i + 0.5) / n
		var z := lerpf(zh, ze, t)
		var y := lerpf(0.0, ye, t)
		_box(model, Vector3(sw - 0.1, 0.012, 0.06), Vector3(sx, y + 0.004, z), "plain_dark", Color(0.25, 0.25, 0.24), Vector3(slope, 0, 0), false)
	# green slime from the tide line down
	var tw := WATER / ye
	_beam(model, Vector3(sx, WATER + 0.12 + 0.008, lerpf(zh, ze, tw - 0.06)), Vector3(sx, ye * 0.95 + 0.008, lerpf(zh, ze, 0.95)), sw - 0.05, 0.012, "plain", Color(0.2, 0.2, 0.15), false)
	# the trolley's rails, from the shed's back down the ramp
	var rc := Color(0.3, 0.29, 0.27) if not rebel else Color(0.38, 0.22, 0.12)
	for e in [-0.75, 0.75]:
		_beam(model, Vector3(sx + e, 0.06, d * 0.5 - 0.6), Vector3(sx + e, 0.06, zh), 0.08, 0.1, "steel", rc)
		_beam(model, Vector3(sx + e, 0.06, zh), Vector3(sx + e, ye + 0.06, ze + 0.3), 0.08, 0.1, "steel", rc)
	# the winch at the head, its cable down to the trolley
	var wz := d * 0.5 - 1.0
	_box(model, Vector3(0.9, 0.4, 0.7), Vector3(sx, 0.2, wz), "concrete", conc.darkened(0.1))
	_box(model, Vector3(0.45, 0.4, 0.45), Vector3(sx + 0.2, 0.6, wz + 0.05), "paint", Color(0.36, 0.42, 0.36) if not rebel else Color(0.45, 0.2, 0.12))
	_cyl(model, 0.16, 0.16, 0.42, Vector3(sx - 0.22, 0.6, wz), Vector3(0, 0, PI / 2), "steel", Color(0.25, 0.25, 0.24), 12)
	_cyl(model, 0.21, 0.21, 0.04, Vector3(sx - 0.45, 0.6, wz), Vector3(0, 0, PI / 2), "steel", Color(0.25, 0.25, 0.24), 12, false)
	# a launching trolley at the ramp's head with a skiff on it
	_trolley(model, rebel, Vector3(sx, 0.06, zq + 4.6))
	_rod(model, Vector3(sx - 0.22, 0.6, wz - 0.12), Vector3(sx, 0.45, zq + 7.0), 0.012, "steel", Color(0.2, 0.2, 0.2), 4)


## The launching trolley on the rails, a skiff in its cradle.
static func _trolley(model: Node3D, rebel: bool, p: Vector3) -> void:
	var fc := Color(0.33, 0.38, 0.33) if not rebel else Color(0.4, 0.22, 0.12)
	for e in [-0.75, 0.75]:
		_box(model, Vector3(0.12, 0.14, 4.0), p + Vector3(e, 0.32, 0), "steel", fc)
		for z in [-1.6, 1.6]:
			_cyl(model, 0.16, 0.16, 0.1, p + Vector3(e, 0.18, z), Vector3(0, 0, PI / 2), "steel", Color(0.2, 0.2, 0.2), 12)
	for z in [-1.2, 0.0, 1.2]:
		_box(model, Vector3(1.7, 0.12, 0.12), p + Vector3(0, 0.42, z), "steel", fc)
		for e in [-1.0, 1.0]:
			_box(model, Vector3(0.08, 0.5, 0.1), p + Vector3(e * 0.62, 0.66, z), "steel", fc, Vector3(0, 0, -e * 0.5))
			_box(model, Vector3(0.12, 0.05, 0.3), p + Vector3(e * 0.52, 0.86, z), "rubber", Color(0.1, 0.1, 0.1), Vector3(0, 0, -e * 0.6))
	# the skiff: a V-hull on the cradle, its open interior, thwarts, a transom motor
	var hp := {"z0": 2.3, "len": 4.8, "b": 0.86, "bc": 0.7, "kh": 0.03, "ys0": 0.62, "ys1": 0.85, "dr0": 0.32, "dr1": 0.85,
		"fore": 0.45, "kb": 0.72, "kp": 2.0, "ent": 0.38, "entc": 0.3, "pb": 2.0, "pc": 1.6, "cl": 0.08}
	var hc := Color(0.52, 0.55, 0.55) if not rebel else Color(0.22, 0.38, 0.5)
	var base := p + Vector3(0, 0.62, 0)
	_mk(model, VmBoat._band_mesh("dock_skiff_hull", VmBoat._hull(hp), -9.0, 9.0), "plain" if not rebel else "steel", base, Vector3.ZERO, hc)
	_mk(model, VmBoat._deck_mesh("dock_skiff_in", VmBoat._hull(hp, 0.02, 0.86), 0.07, 0.0), "plain_dark", base + Vector3(0, -0.02, 0), Vector3.ZERO, Color(0.2, 0.2, 0.2))
	for z in [-0.8, 0.5]:
		_box(model, Vector3(1.4, 0.04, 0.24), base + Vector3(0, 0.62, z), "wood", null)
	_box(model, Vector3(0.36, 0.5, 0.42), base + Vector3(0, 0.75, 2.45), "plain_dark", Color(0.12, 0.12, 0.13))
	_box(model, Vector3(0.12, 0.6, 0.18), base + Vector3(0, 0.25, 2.5), "plain_dark", Color(0.12, 0.12, 0.13))
	if rebel:
		_box(model, Vector3(0.6, 0.012, 0.9), base + Vector3(-0.2, 0.25, 1.5), "steel", Color(0.4, 0.2, 0.1), Vector3(0, 0, 0), false)


# --- the boat shed -------------------------------------------------------------------------

## The boat shed over the slipway's head, open toward the water: a steel
## portal frame clad in corrugated sheet (the Rebels': timber posts, rusty and
## odd sheets, gaps, a tarpaulin), a workbench and an outboard on a stand inside.
static func _shed(model: Node3D, rebel: bool, d: float, zq: float, sx: float, rng: RandomNumberGenerator) -> void:
	var hw := 2.45
	var z0 := zq + 1.0
	var z1 := d * 0.5 - 0.3
	var eave := 3.7
	var ridge := 4.75
	var l := z1 - z0
	var fk := "steel" if not rebel else "wood_dark"
	var fc := Color(0.34, 0.39, 0.34) if not rebel else Color(0.33, 0.25, 0.17)
	var sheet := Color(0.46, 0.5, 0.46) if not rebel else Color(0.44, 0.33, 0.24)
	var nb := maxi(2, int(round(l / 2.6)))
	# the frames: posts, a tie at the eaves, rafters to the ridge
	for i in nb + 1:
		var z := z0 + l * i / nb
		for e in [-1.0, 1.0]:
			if rebel:
				_cyl(model, 0.09, 0.1, eave, Vector3(sx + e * (hw - 0.08), eave * 0.5, z), Vector3(rng.randf_range(-0.02, 0.02), 0, rng.randf_range(-0.02, 0.02)), "bark", fc, 7)
			else:
				_box(model, Vector3(0.18, eave, 0.18), Vector3(sx + e * (hw - 0.09), eave * 0.5, z), fk, fc)
			_beam(model, Vector3(sx + e * (hw + 0.15), eave - 0.05, z), Vector3(sx, ridge - 0.08, z), 0.12, 0.2, fk, fc)
		if i == 0 or i == nb:
			_box(model, Vector3(hw * 2.0, 0.2, 0.14), Vector3(sx, eave - 0.1, z), fk, fc)
	for e in [-1.0, 1.0]:
		_box(model, Vector3(0.12, 0.14, l + 0.2), Vector3(sx + e * (hw - 0.09), eave - 0.07, (z0 + z1) * 0.5), fk, fc)
	# the side walls and back wall in corrugated sheet
	var gaps := [] if not rebel else [[1, 1.1], [-1, 2.6]]
	for e in [-1.0, 1.0]:
		var n := int(ceil(l / 1.05))
		for i in n:
			var za := z0 + 0.1 + i * (l - 0.1) / n
			var zb := za + (l - 0.1) / n
			var skip := false
			for g in gaps:
				if int(g[0]) == int(e) and absf((za + zb) * 0.5 - z0 - float(g[1])) < 0.6:
					skip = true
			if skip:
				continue
			var c := sheet
			if rebel:
				c = sheet.lerp(Color(0.5, 0.26, 0.12) if i % 3 == 0 else Color(0.38, 0.4, 0.42), rng.randf() * 0.6)
			var h := eave - 0.05 - (rng.randf() * 0.5 if rebel and i % 4 == 2 else 0.0)
			_box(model, Vector3(0.03, h, zb - za + 0.04), Vector3(sx + e * hw, h * 0.5 + 0.05, (za + zb) * 0.5), "corrugated", c, Vector3(0, 0, e * rng.randf_range(0.0, 0.015) if rebel else 0.0))
	var nb2 := int(ceil(hw * 2.0 / 1.05))
	for i in nb2:
		var xa := sx - hw + i * hw * 2.0 / nb2
		var c := sheet if not rebel else sheet.lerp(Color(0.5, 0.26, 0.12), rng.randf() * 0.7)
		_box(model, Vector3(hw * 2.0 / nb2 + 0.04, eave - 0.05, 0.03), Vector3(xa + hw / nb2, eave * 0.5, z1 + 0.02), "corrugated", c)
	# the gables: the back one clad, the front one clad above the opening
	for zz in [z1 + 0.02, z0 - 0.02]:
		var gm := _xsec(model, "dock_gable", [-hw - 0.05, eave, hw + 0.05, eave, 0.0, ridge], -0.015, [-hw - 0.05, eave, hw + 0.05, eave, 0.0, ridge], 0.015, "corrugated", sheet.darkened(0.06))
		gm.position = Vector3(sx, 0, zz)
	# the roof: two slopes of sheet with an overhang, a ridge capping, lap lines
	var slope := atan2(ridge - eave, hw)
	var rl := sqrt(hw * hw + (ridge - eave) * (ridge - eave)) + 0.35
	for e in [-1.0, 1.0]:
		var cx: float = sx + e * (hw * 0.5 + 0.12)
		var cy := (eave + ridge) * 0.5 + 0.08 - 0.12
		_box(model, Vector3(rl, 0.04, l + 0.6), Vector3(cx, cy, (z0 + z1) * 0.5), "corrugated", sheet.lightened(0.04), Vector3(0, 0, -e * slope))
		for i in int(l / 0.95):
			var z := z0 - 0.3 + (i + 1) * 0.95
			_box(model, Vector3(rl, 0.012, 0.03), Vector3(cx, cy + 0.03, z), "plain_dark", sheet.darkened(0.3), Vector3(0, 0, -e * slope), false)
	_box(model, Vector3(0.36, 0.08, l + 0.6), Vector3(sx, ridge + 0.03, (z0 + z1) * 0.5), "steel", sheet.darkened(0.15))
	if rebel:
		# a tarpaulin weighted down over a hole in the roof, rust weeping down the walls
		_box(model, Vector3(1.6, 0.03, 2.2), Vector3(sx + 1.2, (eave + ridge) * 0.5 + 0.06, z0 + l * 0.6), "canvas", Color(0.24, 0.32, 0.4), Vector3(0, 0, -slope))
		for q in [[0.6, 0.0], [-0.6, 0.6]]:
			_mk(model, Res.capsule(0.12, 0.5, 8), "bark", Vector3(sx + 1.2 + float(q[0]) * 0.5, (eave + ridge) * 0.5 + 0.18 - float(q[0]) * 0.2, z0 + l * 0.6 + float(q[1])), Vector3(PI / 2, 0, -slope), Color(0.3, 0.25, 0.2))
	# the gutter along the eaves, a downpipe
	for e in [-1.0, 1.0]:
		_box(model, Vector3(0.12, 0.1, l + 0.6), Vector3(sx + e * (hw + 0.38), eave - 0.12, (z0 + z1) * 0.5), "steel", sheet.darkened(0.2))
	_rod(model, Vector3(sx + hw + 0.38, eave - 0.15, z1), Vector3(sx + hw + 0.38, 0.1, z1), 0.05, "steel", sheet.darkened(0.2), 8, true)
	# inside: a workbench along the right wall, a vice, tools, an outboard on a stand, a lamp
	var bx := sx + hw - 0.45
	var bz := z0 + l * 0.62
	_box(model, Vector3(0.7, 0.06, 2.2), Vector3(bx, 0.9, bz), "wood", Color(0.45, 0.35, 0.22))
	for q in [[-0.3, -1.0], [0.3, -1.0], [-0.3, 1.0], [0.3, 1.0]]:
		_box(model, Vector3(0.06, 0.88, 0.06), Vector3(bx + float(q[0]), 0.44, bz + float(q[1])), "steel", Color(0.3, 0.3, 0.3))
	_box(model, Vector3(0.6, 0.04, 2.0), Vector3(bx, 0.3, bz), "wood", Color(0.4, 0.3, 0.2))
	_box(model, Vector3(0.14, 0.14, 0.24), Vector3(bx - 0.2, 1.0, bz - 0.8), "steel", Color(0.2, 0.3, 0.45) if not rebel else Color(0.3, 0.28, 0.25))
	_box(model, Vector3(0.4, 0.22, 0.25), Vector3(bx + 0.05, 1.04, bz + 0.5), "paint", Color(0.6, 0.12, 0.08))
	for i in 3:
		_cyl(model, 0.09, 0.09, 0.14, Vector3(bx + 0.15, 1.0, bz + 0.0 - i * 0.22), Vector3.ZERO, "steel", [Color(0.7, 0.68, 0.6), Color(0.3, 0.4, 0.3), Color(0.5, 0.2, 0.1)][i], 10)
	_box(model, Vector3(0.03, 0.9, 1.6), Vector3(sx + hw - 0.06, 1.75, bz), "wood", Color(0.5, 0.42, 0.3))
	var ox := sx + hw - 0.7
	var oz := z0 + l * 0.32
	_box(model, Vector3(0.6, 0.06, 0.6), Vector3(ox, 0.03, oz), "steel", Color(0.3, 0.3, 0.3))
	_box(model, Vector3(0.06, 1.1, 0.06), Vector3(ox, 0.58, oz), "steel", Color(0.3, 0.3, 0.3))
	_box(model, Vector3(0.5, 0.06, 0.08), Vector3(ox, 1.1, oz), "steel", Color(0.3, 0.3, 0.3))
	_box(model, Vector3(0.42, 0.55, 0.62), Vector3(ox, 1.42, oz + 0.12), "plain_dark", Color(0.12, 0.12, 0.13))
	_box(model, Vector3(0.14, 0.9, 0.22), Vector3(ox, 0.75, oz + 0.15), "plain_dark", Color(0.12, 0.12, 0.13))
	_cyl(model, 0.012, 0.012, 0.8, Vector3(sx, eave - 0.45, (z0 + z1) * 0.5), Vector3.ZERO, "steel", Color(0.2, 0.2, 0.2), 4, false)
	_cyl(model, 0.03, 0.22, 0.14, Vector3(sx, eave - 0.9, (z0 + z1) * 0.5), Vector3.ZERO, "paint", Color(0.3, 0.33, 0.3), 12, false)
	# lifejackets hung on the left wall
	for i in 4:
		_box(model, Vector3(0.1, 0.5, 0.36), Vector3(sx - hw + 0.1, 1.5, z0 + l * 0.45 + i * 0.45), "canvas", ORANGE, Vector3(0, 0, 0.05))


const ORANGE := Color(0.86, 0.36, 0.08)


# --- the jetty ------------------------------------------------------------------------------

## The jetty: pairs of piles every 3 m (steel tubes, or the Rebels' timber),
## headstocks across them, stringers, a planked deck with a kerb, cross
## bracing, bollards and tyre fenders, a ladder down at the head, a lamp and
## a life ring; a fuel line along its side to a hose reel at the head.
static func _jetty(model: Node3D, rebel: bool, zq: float, jx: float, jw: float, rng: RandomNumberGenerator) -> void:
	var za := zq + 1.2
	var zb := zq - JETTY
	var top := 0.18
	var pk := "steel" if not rebel else "bark"
	var pc := Color(0.22, 0.24, 0.22) if not rebel else Color(0.3, 0.24, 0.17)
	var bk := "steel" if not rebel else "wood_dark"
	var bc := Color(0.34, 0.39, 0.34) if not rebel else Color(0.3, 0.22, 0.15)
	var n := int(ceil((za - zb) / 3.0))
	var hx := jw * 0.5 - 0.2
	for i in n + 1:
		var z := zb + 0.25 + i * (za - zb - 0.5) / n
		var bed := _bed(zq, z) if z < zq else 0.0
		var tilt := Vector3(rng.randf_range(-0.025, 0.025), 0, rng.randf_range(-0.025, 0.025)) if rebel else Vector3.ZERO
		for e in [-1.0, 1.0]:
			var x: float = jx + e * hx
			var ln := top - 0.32 - (bed - 1.2)
			_cyl(model, 0.17 if not rebel else 0.15, 0.17 if not rebel else 0.16, ln, Vector3(x, top - 0.32 - ln * 0.5, z), tilt, pk, pc, 10 if not rebel else 7)
			if z < zq:
				# weed and barnacles round the tide line
				_cyl(model, 0.185, 0.185, 0.45, Vector3(x, WATER - 0.05, z), tilt, "plain", Color(0.16, 0.19, 0.12), 10, false)
		_box(model, Vector3(jw + 0.3, 0.28, 0.3), Vector3(jx, top - 0.44, z), bk, bc)
		# cross bracing between the pair, under the headstock
		if z < zq - 1.0:
			var ylo := maxf(bed + 0.3, WATER - 0.9)
			_beam(model, Vector3(jx - hx, top - 0.6, z + 0.12), Vector3(jx + hx, ylo, z + 0.12), 0.1, 0.16, bk, bc)
			if not rebel:
				_beam(model, Vector3(jx + hx, top - 0.6, z - 0.12), Vector3(jx - hx, ylo, z - 0.12), 0.1, 0.16, bk, bc)
	# stringers under the planks
	for e in [-1.0, -0.33, 0.33, 1.0]:
		_box(model, Vector3(0.14, 0.24, za - zb), Vector3(jx + e * (jw * 0.5 - 0.2), top - 0.18, (za + zb) * 0.5), bk if not rebel else "wood_dark", bc)
	# the deck: planks across, the Rebels' uneven and a few missing
	var pl := 0.26
	var np := int((za - zb) / (pl + 0.025))
	for i in np:
		var z := zb + 0.1 + i * (pl + 0.025)
		if rebel and (i == 17 or i == 31 or i == 32):
			continue
		var c := Color(0.48, 0.47, 0.43) if not rebel else Color(0.42, 0.33, 0.23).lerp(Color(0.3, 0.27, 0.22), rng.randf())
		var off := rng.randf_range(-0.1, 0.1) if rebel else 0.0
		_box(model, Vector3(jw + (0.0 if not rebel else rng.randf_range(-0.2, 0.15)), 0.06, pl), Vector3(jx + off, top - 0.03 + (rng.randf_range(-0.015, 0.015) if rebel else 0.0), z + pl * 0.5), "wood", c, Vector3(0, rng.randf_range(-0.03, 0.03) if rebel else 0.0, 0))
	# kerbs along the edges, bollards on them, tyre fenders outside
	for e in [-1.0, 1.0]:
		var x: float = jx + e * (jw * 0.5 - 0.1)
		_box(model, Vector3(0.18, 0.14, za - zb), Vector3(x, top + 0.07, (za + zb) * 0.5), bk if not rebel else "wood_dark", bc.darkened(0.05))
		var nbo := int((za - zb) / 4.2)
		for i in nbo:
			var z := zb + 0.9 + i * 4.2
			_bollard(model, Vector3(x - e * 0.05, top + 0.14, z), "metal_dark" if not rebel else "steel", Color(0.14, 0.15, 0.14) if not rebel else Color(0.33, 0.2, 0.12))
			var tz := z + 2.1
			if tz < zq:
				_tyre(model, Vector3(jx + e * (jw * 0.5 + 0.12), -0.15, tz), Vector3(e, 0, 0), Vector3(x, top + 0.14, tz))
	# a handrail along one side (the Coalition's), a rope on posts (the Rebels')
	var rx := jx + jw * 0.5 - 0.1
	var nr := int((za - zb) / 2.0)
	for i in nr + 1:
		var z := zb + 0.3 + i * (za - zb - 0.6) / nr
		if rebel:
			_cyl(model, 0.05, 0.06, 1.0, Vector3(rx, top + 0.5, z), Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05)), "bark", Color(0.32, 0.26, 0.18), 6)
			if i > 0:
				var zp := zb + 0.3 + (i - 1) * (za - zb - 0.6) / nr
				_rod(model, Vector3(rx, top + 0.92, zp), Vector3(rx, top + 0.85, (zp + z) * 0.5), 0.016, "canvas", Color(0.5, 0.45, 0.33), 4)
				_rod(model, Vector3(rx, top + 0.85, (zp + z) * 0.5), Vector3(rx, top + 0.92, z), 0.016, "canvas", Color(0.5, 0.45, 0.33), 4)
		else:
			_rod(model, Vector3(rx, top + 0.14, z), Vector3(rx, top + 1.1, z), 0.025, "steel", bc, 6, true)
	if not rebel:
		for h in [1.1, 0.6]:
			_rod(model, Vector3(rx, top + h, zb + 0.3), Vector3(rx, top + h, za - 0.3), 0.022, "steel", bc, 6, true)
		# the fuel line on brackets along the other side, a hose reel at the head
		var fx := jx - jw * 0.5 - 0.12
		_rod(model, Vector3(fx, top - 0.12, za), Vector3(fx, top - 0.12, zb + 1.2), 0.05, "paint", Color(0.55, 0.45, 0.12), 8, true)
		for i in 5:
			var z := za - 1.0 - i * 3.0
			_box(model, Vector3(0.2, 0.06, 0.08), Vector3(fx + 0.06, top - 0.18, z), "steel", bc, Vector3.ZERO, false)
		_box(model, Vector3(0.5, 0.9, 0.4), Vector3(jx - jw * 0.5 + 0.45, top + 0.45, zb + 1.5), "paint", Color(0.55, 0.45, 0.12))
		_cyl(model, 0.32, 0.32, 0.28, Vector3(jx - jw * 0.5 + 0.45, top + 1.05, zb + 1.5), Vector3(0, 0, PI / 2), "rubber", Color(0.08, 0.08, 0.08), 16)
		# a lamp at the head
		_cyl(model, 0.05, 0.07, 4.2, Vector3(rx - 0.15, top + 2.1, zb + 0.5), Vector3.ZERO, "steel", bc, 8)
		_box(model, Vector3(0.6, 0.06, 0.06), Vector3(rx - 0.42, top + 4.15, zb + 0.5), "steel", bc, Vector3.ZERO, false)
		_box(model, Vector3(0.32, 0.1, 0.18), Vector3(rx - 0.7, top + 4.1, zb + 0.5), "steel", Color(0.3, 0.3, 0.3), Vector3.ZERO, false)
	# the ladder down at the head
	var lx := jx - 0.5
	for side in [-0.22, 0.22]:
		_rod(model, Vector3(lx + side, top + 0.9, zb - 0.12), Vector3(lx + side, _bed(zq, zb) + 0.3, zb - 0.12), 0.025, "steel", Color(0.3, 0.3, 0.28) if not rebel else Color(0.36, 0.2, 0.1), 6, true)
	for i in 9:
		_rod(model, Vector3(lx - 0.22, top - 0.2 - i * 0.28, zb - 0.12), Vector3(lx + 0.22, top - 0.2 - i * 0.28, zb - 0.12), 0.018, "steel", Color(0.3, 0.3, 0.28) if not rebel else Color(0.36, 0.2, 0.1))
	# a life ring on a post at the root
	var lr := Vector3(jx - jw * 0.5 + 0.2, top, zq - 0.6)
	_box(model, Vector3(0.1, 1.3, 0.1), lr + Vector3(0, 0.65, 0), "wood" if rebel else "steel", Color(0.4, 0.3, 0.2) if rebel else bc)
	_mk(model, VmShips._torus(0.2, 0.33), "plain", lr + Vector3(0.05, 0.95, 0), Vector3(0, 0, PI / 2), ORANGE)


# --- the crane ----------------------------------------------------------------------------

## A pillar jib crane on the quay: a column on a concrete plinth, a slewing
## jib out over the water with its tie rods and counterweight, a trolley and
## a hoist block on its cable.
static func _crane(model: Node3D, rebel: bool, p: Vector3) -> void:
	var c := Color(0.34, 0.39, 0.34) if not rebel else Color(0.42, 0.24, 0.13)
	var k := "steel"
	_box(model, Vector3(1.3, 0.55, 1.3), p + Vector3(0, 0.27, 0), "concrete", Color(0.55, 0.54, 0.5))
	for e in [Vector3(0.45, 0, 0.45), Vector3(-0.45, 0, 0.45), Vector3(0.45, 0, -0.45), Vector3(-0.45, 0, -0.45)]:
		_cyl(model, 0.035, 0.035, 0.08, p + e + Vector3(0, 0.58, 0), Vector3.ZERO, "steel", Color(0.25, 0.25, 0.24), 6, false)
	_cyl(model, 0.38, 0.4, 0.06, p + Vector3(0, 0.58, 0), Vector3.ZERO, k, c, 14)
	_cyl(model, 0.19, 0.22, 3.9, p + Vector3(0, 2.5, 0), Vector3.ZERO, k, c, 12)
	var yaw := -0.45
	var b := Basis(Vector3.UP, yaw)
	var hy := 4.35
	_cyl(model, 0.26, 0.26, 0.25, p + Vector3(0, hy, 0), Vector3.ZERO, k, c, 14)
	_cyl(model, 0.12, 0.14, 1.1, p + Vector3(0, hy + 0.65, 0), Vector3.ZERO, k, c, 10)
	# the jib: an I-beam out over the water, the tail with its counterweight
	var tip := p + b * Vector3(0, hy, -4.6)
	var tail := p + b * Vector3(0, hy, 1.1)
	_box(model, Vector3(0.22, 0.4, 5.7), p + b * Vector3(0, hy, -1.75), k, c, Vector3(0, yaw, 0))
	_box(model, Vector3(0.3, 0.04, 5.7), p + b * Vector3(0, hy - 0.2, -1.75), k, c.darkened(0.1), Vector3(0, yaw, 0))
	_box(model, Vector3(0.3, 0.04, 5.7), p + b * Vector3(0, hy + 0.2, -1.75), k, c.darkened(0.1), Vector3(0, yaw, 0))
	_box(model, Vector3(0.7, 0.7, 0.6), tail + Vector3(0, -0.15, 0), "concrete", Color(0.5, 0.49, 0.46), Vector3(0, yaw, 0))
	for e in [-0.08, 0.08]:
		_rod(model, p + Vector3(0, hy + 1.15, 0) + b * Vector3(e, 0, 0), tip + Vector3(0, 0.2, 0) + b * Vector3(e, 0, 0), 0.022, k, c, 6, true)
		_rod(model, p + Vector3(0, hy + 1.15, 0) + b * Vector3(e, 0, 0), tail + Vector3(0, 0.2, 0) + b * Vector3(e, 0, 0), 0.022, k, c, 6, true)
	# the trolley under the jib, the hoist, its cable and the hook block
	var tr := p + b * Vector3(0, hy - 0.32, -3.5)
	_box(model, Vector3(0.36, 0.24, 0.4), tr, k, Color(0.3, 0.3, 0.29), Vector3(0, yaw, 0))
	_box(model, Vector3(0.3, 0.36, 0.5), tr + Vector3(0, -0.32, 0), "paint", Color(0.75, 0.6, 0.12) if not rebel else Color(0.3, 0.29, 0.27), Vector3(0, yaw, 0))
	var hook := tr + Vector3(0, -2.6, 0)
	_rod(model, tr + Vector3(0, -0.5, 0), hook + Vector3(0, 0.22, 0), 0.012, "steel", Color(0.2, 0.2, 0.2), 4)
	_box(model, Vector3(0.22, 0.3, 0.14), hook + Vector3(0, 0.08, 0), "paint", Color(0.8, 0.62, 0.1) if not rebel else Color(0.35, 0.3, 0.25), Vector3(0, yaw, 0))
	_mk(model, VmShips._torus(0.05, 0.11), "steel", hook + Vector3(0, -0.15, 0), Vector3(PI / 2, yaw, 0), Color(0.25, 0.25, 0.24))
	if not rebel:
		for i in 4:
			_box(model, Vector3(0.012, 0.06, 0.15), hook + Vector3(0, 0.0 + i * 0.075, 0) + b * Vector3(0.112, 0, 0), "plain_dark", Color(0.05, 0.05, 0.05), Vector3(0, yaw, 0.6), false)
		# the pendant control on its cable
		_rod(model, tr + Vector3(0, -0.2, 0), tr + Vector3(0, -3.0, 0) + b * Vector3(0.3, 0, 0.3), 0.008, "rubber", null, 3)
		_box(model, Vector3(0.1, 0.24, 0.08), tr + Vector3(0, -3.1, 0) + b * Vector3(0.3, 0, 0.3), "paint", Color(0.75, 0.6, 0.12))


# --- fuel -----------------------------------------------------------------------------------

## Fuel: the Coalition's in a bunded tank on saddles with a dispenser, and
## drums on a spill pallet; the Rebels' in a jumble of odd drums with a hand
## pump, jerrycans.
static func _fuel(model: Node3D, rebel: bool, w: float, d: float, zq: float, jx: float, jw: float, rng: RandomNumberGenerator) -> void:
	var fx := w * 0.5 - 2.0
	var fz := d * 0.5 - 1.7
	if not rebel:
		var c := Color(0.34, 0.39, 0.34)
		_box(model, Vector3(3.4, 0.3, 2.0), Vector3(fx, 0.15, fz), "concrete", Color(0.52, 0.51, 0.48))
		_box(model, Vector3(3.2, 0.04, 1.8), Vector3(fx, 0.3, fz), "concrete", Color(0.42, 0.41, 0.38))
		for e in [-1.0, 1.0]:
			_box(model, Vector3(0.25, 0.6, 1.1), Vector3(fx + e * 0.8, 0.6, fz), "steel", c)
		_cyl(model, 0.68, 0.68, 2.6, Vector3(fx, 1.45, fz), Vector3(0, 0, PI / 2), "paint", Color(0.4, 0.45, 0.4), 18)
		for e in [-1.0, 1.0]:
			_mk(model, Res.sphere(0.68, 18), "paint", Vector3(fx + e * 1.3, 1.45, fz), Vector3.ZERO, Color(0.4, 0.45, 0.4)).scale = Vector3(0.25, 1, 1)
		_box(model, Vector3(1.2, 0.2, 0.012), Vector3(fx, 1.45, fz - 0.685), "paint", Color(0.8, 0.66, 0.12), Vector3.ZERO, false)
		_cyl(model, 0.12, 0.12, 0.2, Vector3(fx + 0.6, 2.18, fz), Vector3.ZERO, "steel", c, 10)
		_rod(model, Vector3(fx - 0.4, 2.1, fz), Vector3(fx - 0.4, 2.6, fz), 0.04, "steel", c, 6, true)
		# the dispenser by the tank, its hose to the jetty's fuel line
		_box(model, Vector3(0.6, 1.4, 0.45), Vector3(fx - 2.1, 0.7, fz - 0.4), "paint", Color(0.55, 0.45, 0.12))
		_box(model, Vector3(0.4, 0.3, 0.012), Vector3(fx - 2.1, 1.1, fz - 0.63), "glass", Color(0.15, 0.17, 0.18), Vector3.ZERO, false)
		_rod(model, Vector3(fx - 2.1, 0.1, fz - 0.65), Vector3(jx - jw * 0.5 - 0.12, 0.06, zq + 1.2), 0.05, "paint", Color(0.55, 0.45, 0.12), 8, true)
		# drums on a spill pallet
		_box(model, Vector3(1.4, 0.18, 1.4), Vector3(fx - 0.6, 0.09, fz - 2.3), "plain", Color(0.75, 0.62, 0.12))
		for q in [[-0.33, -0.33], [0.33, -0.33], [-0.33, 0.33], [0.33, 0.33]]:
			_drum(model, Vector3(fx - 0.6 + float(q[0]), 0.18, fz - 2.3 + float(q[1])), Color(0.26, 0.32, 0.24))
		_drum(model, Vector3(fx + 0.9, 0.0, fz - 2.2), Color(0.2, 0.3, 0.45))
		# a fire point: extinguishers on a stand, a sand bin
		_box(model, Vector3(0.6, 1.2, 0.08), Vector3(fx + 1.6, 0.6, fz - 1.4), "paint", Color(0.6, 0.12, 0.08))
		for e in [-0.15, 0.15]:
			_cyl(model, 0.08, 0.08, 0.5, Vector3(fx + 1.6 + e, 0.5, fz - 1.48), Vector3.ZERO, "paint", Color(0.7, 0.1, 0.07), 10)
		_box(model, Vector3(0.6, 0.5, 0.45), Vector3(fx + 1.6, 0.25, fz - 2.0), "paint", Color(0.6, 0.12, 0.08))
	else:
		var cols := [Color(0.42, 0.18, 0.1), Color(0.18, 0.28, 0.42), Color(0.3, 0.32, 0.24), Color(0.5, 0.42, 0.15), Color(0.36, 0.2, 0.12)]
		var spots := [[0.0, 0.0], [0.62, 0.05], [1.22, -0.05], [0.3, 0.55], [0.92, 0.6], [-0.6, 0.4], [-0.35, -0.6]]
		for i in spots.size():
			var q: Array = spots[i]
			_drum(model, Vector3(fx - 0.6 + float(q[0]), 0.03, fz - 0.4 + float(q[1])), cols[i % cols.size()])
		_drum(model, Vector3(fx - 0.2, 0.03, fz - 1.6), cols[0], true, 0.4)
		_drum(model, Vector3(fx + 1.0, 0.03, fz - 1.4), cols[1], true, -0.9)
		# a hand pump in one drum, its hose trailing
		_cyl(model, 0.04, 0.04, 0.9, Vector3(fx - 0.6, 1.3, fz - 0.4), Vector3.ZERO, "steel", Color(0.3, 0.3, 0.3), 6)
		_box(model, Vector3(0.12, 0.15, 0.2), Vector3(fx - 0.6, 1.5, fz - 0.4), "paint", Color(0.55, 0.12, 0.08))
		_rod(model, Vector3(fx - 0.6, 1.45, fz - 0.5), Vector3(fx - 1.6, 0.06, fz - 1.4), 0.025, "rubber", null, 5)
		for i in 5:
			_box(model, Vector3(0.17, 0.45, 0.34), Vector3(fx - 1.6 + i * 0.22, 0.26, fz + 0.5), "paint", [Color(0.32, 0.36, 0.24), Color(0.6, 0.15, 0.1)][i % 2], Vector3(0, rng.randf_range(-0.15, 0.15), 0))


# --- the flag ----------------------------------------------------------------------------

## The side's flag on a pole: the Coalition's a white mast on a concrete
## base, the Rebels' a lashed-up wooden pole.
static func _flagpole(model: Node3D, team: int, p: Vector3) -> void:
	var rebel := team == 1
	var h := 7.2 if not rebel else 5.6
	if not rebel:
		_box(model, Vector3(0.7, 0.3, 0.7), p + Vector3(0, 0.15, 0), "concrete", Color(0.58, 0.57, 0.53))
		_cyl(model, 0.045, 0.075, h, p + Vector3(0, 0.3 + h * 0.5, 0), Vector3.ZERO, "paint", Color(0.82, 0.82, 0.8), 10)
		_mk(model, Res.sphere(0.09, 10), "paint", p + Vector3(0, 0.3 + h + 0.06, 0), Vector3.ZERO, Color(0.7, 0.58, 0.25))
		_rod(model, p + Vector3(0.08, 0.3 + h, 0), p + Vector3(0.08, 1.2, 0), 0.006, "plain", Color(0.85, 0.85, 0.82), 3)
		_box(model, Vector3(0.04, 0.12, 0.08), p + Vector3(0.08, 1.2, 0), "steel", Color(0.4, 0.4, 0.4), Vector3.ZERO, false)
	else:
		_cyl(model, 0.06, 0.09, h, p + Vector3(0, h * 0.5 - 0.3, 0), Vector3(0.03, 0, -0.04), "bark", Color(0.33, 0.27, 0.2), 7)
		for i in 4:
			var a := TAU * i / 4.0 + 0.4
			_mk(model, Res.sphere(0.22, 7), "stone", p + Vector3(cos(a) * 0.3, 0.1, sin(a) * 0.3), Vector3(a, a, 0), Color(0.48, 0.46, 0.42))
		_rod(model, p + Vector3(-0.3, 0.0, -1.6), p + Vector3(-0.1, h * 0.7, 0.05), 0.01, "canvas", Color(0.45, 0.4, 0.3), 3)
	if team < 0 or team >= Defs.TEAM_COLORS.size():
		return
	var tc: Color = Defs.TEAM_COLORS[team].lerp(Color(0.45, 0.45, 0.42), 0.35).darkened(0.12)
	var fw := 1.6 if not rebel else 1.25
	var fh := 1.0 if not rebel else 0.8
	var top := p + Vector3(0, (0.3 + h if not rebel else h - 0.3) - 0.1, 0)
	var x := 0.0
	var z := 0.0
	for i in 4:
		var a := 0.35 if i % 2 == 0 else -0.3
		var l := fw / 4.0
		_box(model, Vector3(l + 0.02, fh - i * 0.03, 0.012), top + Vector3(x + cos(a) * l * 0.5, -fh * 0.5 - i * 0.025, z + sin(a) * l * 0.5), "fabric", tc, Vector3(0, -a, 0), false)
		x += cos(a) * l
		z += sin(a) * l


# --- crates ------------------------------------------------------------------------------

## Stores on the hard: the Coalition's on pallets in neat stacks, the
## Rebels' piled anyhow under a tarpaulin.
static func _crates(model: Node3D, rebel: bool, p: Vector3, rng: RandomNumberGenerator) -> void:
	if not rebel:
		for s in [[0.0, 0.0], [0.0, 1.35], [1.25, 0.2]]:
			var b := p + Vector3(s[0], 0.0, s[1])
			_box(model, Vector3(1.2, 0.14, 1.0), b + Vector3(0, 0.07, 0), "wood", Color(0.55, 0.45, 0.3))
			for lv in 2:
				for q in [[-0.3, -0.25], [0.3, -0.25], [-0.3, 0.25], [0.3, 0.25]]:
					if lv == 1 and s[0] > 0.5 and q[1] > 0.0:
						continue
					_crate(model, b + Vector3(q[0], 0.14 + lv * 0.42, q[1]), Vector3(0.58, 0.4, 0.48), 0.0, "wood_painted", Color(0.3, 0.33, 0.23))
		# a pallet of boxed stores under shrink wrap
		_box(model, Vector3(1.0, 0.14, 1.0), p + Vector3(-1.4, 0.07, 0.6), "wood", Color(0.55, 0.45, 0.3))
		_box(model, Vector3(0.95, 0.9, 0.95), p + Vector3(-1.4, 0.6, 0.6), "canvas_white", Color(0.75, 0.75, 0.72))
	else:
		var spots := [[0.0, 0.0, 0.2], [0.75, -0.1, -0.3], [0.3, 0.75, 0.5], [1.2, 0.8, 0.1], [-0.6, 0.6, -0.2]]
		for q in spots:
			var s := Vector3(rng.randf_range(0.6, 0.9), rng.randf_range(0.4, 0.6), rng.randf_range(0.5, 0.7))
			_crate(model, p + Vector3(q[0], 0.03, q[1]), s, q[2], "wood", Color(0.5, 0.4, 0.27).lerp(Color(0.35, 0.3, 0.22), rng.randf()))
		_crate(model, p + Vector3(0.1, 0.55, 0.05), Vector3(0.7, 0.45, 0.55), 0.35, "wood", Color(0.46, 0.37, 0.25))
		_box(model, Vector3(1.6, 0.04, 1.4), p + Vector3(0.35, 1.05, 0.35), "canvas", Color(0.28, 0.32, 0.22), Vector3(0.12, 0.3, 0.08))
		for i in 3:
			_mk(model, Res.capsule(0.2, 0.7, 8), "canvas", p + Vector3(-1.0 + i * 0.1, 0.2, -0.5 + i * 0.4), Vector3(PI / 2, rng.randf() * PI, 0), Color(0.55, 0.5, 0.38))
