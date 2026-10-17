class_name VmNato
extends RefCounted
## Procedural models: NATO ground vehicles (Hunter, Prowler, Marshall, Rhino, Slammer, Panther, Bobcat, Cheetah, Scorcher, Sandstorm, HEMTT, Stomper).
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys must be unique per shape).

## Every model key this file builds (the Field Manual's model pages list them).
const KEYS: Array[String] = ["hunter", "hunter_hmg", "hunter_gmg", "prowler", "prowler_hmg", "prowler_at",
		"marshall", "rhino", "rhino_up", "slammer", "slammer_up", "scorcher", "sandstorm", "panther", "bobcat", "cheetah",
		"hemtt", "hemtt_cargo", "hemtt_ammo", "hemtt_repair", "hemtt_medical", "hemtt_fuel", "stomper"]

const GUN := Color(0.3, 0.32, 0.24)  # painted gun barrels
const STOW := Color(0.33, 0.35, 0.25)  # olive stowage, ammo cans
const BAG := Color(0.38, 0.37, 0.27)  # canvas bags and covers


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"hunter":
			_hunter(k, team, "")
		"hunter_hmg":
			_hunter(k, team, "hmg")
		"hunter_gmg":
			_hunter(k, team, "gmg")
		"prowler":
			_prowler(k, team, "")
		"prowler_hmg":
			_prowler(k, team, "hmg")
		"prowler_at":
			_prowler(k, team, "at")
		"marshall":
			_marshall(k, team)
		"rhino":
			_rhino(k, team, false)
		"rhino_up":
			_rhino(k, team, true)
		"slammer":
			_slammer(k, team, false)
		"slammer_up":
			_slammer(k, team, true)
		"scorcher":
			_scorcher(k, team)
		"sandstorm":
			_sandstorm(k, team)
		"panther":
			_panther(k, team)
		"bobcat":
			_bobcat(k, team)
		"cheetah":
			_cheetah(k, team)
		"hemtt":
			_hemtt(k, team, "troop")
		"hemtt_cargo":
			_hemtt(k, team, "cargo")
		"hemtt_ammo":
			_hemtt(k, team, "ammo")
		"hemtt_repair":
			_hemtt(k, team, "repair")
		"hemtt_medical":
			_hemtt(k, team, "medical")
		"hemtt_fuel":
			_hemtt(k, team, "fuel")
		"stomper":
			_stomper(k, team)
		_:
			return false
	return true


# --- shared helpers ------------------------------------------------------------------

static func _cam(team: int) -> String:
	return "camo_tank" if team != 1 else "camo_tank_rebel"


## A plate lying on a sloped face seen side-on: its length runs from a to b
## ((z, y) points), centred on x, pushed `push` out along the face's normal
## (outward is forward/up when a -> b climbs a front face).
static func _zy(k: VehicleModels, p: Node3D, x: float, w: float, a: Vector2, b: Vector2, t: float, push: float, mat: String, col = null, shadow := true) -> Variant:
	var d := b - a
	var dn := d.normalized()
	var n := Vector2(-dn.y, dn.x)
	var c := (a + b) * 0.5 + n * push
	return k._box(p, Vector3(w, d.length(), t), Vector3(x, c.y, c.x), mat, col, Vector3(atan2(d.x, d.y), 0, 0), shadow)


## A plate on a side face sloping in (seen from the front): a, b are (x, y)
## points on the right-hand side, bottom to top; s = -1 mirrors it to the left.
static func _xy(k: VehicleModels, p: Node3D, s: float, z: float, l: float, a: Vector2, b: Vector2, t: float, push: float, mat: String, col = null, shadow := true) -> Variant:
	var d := b - a
	var dn := d.normalized()
	var n := Vector2(dn.y, -dn.x)
	var c := (a + b) * 0.5 + n * push
	return k._box(p, Vector3(t, d.length(), l), Vector3(s * c.x, c.y, z), mat, col, Vector3(0, 0, s * atan2(-d.x, d.y)), shadow)


## A box lying flat on a face: local x along ex, local y along ey (squared
## up to ex), its thickness standing out of the face toward `out`; surf is
## the point on the face under the box's centre.
static func _on_face(k: VehicleModels, p: Node3D, surf: Vector3, ex: Vector3, ey: Vector3, out: Vector3, size: Vector3, mat: String, col = null, shadow := true) -> Variant:
	var x := ex.normalized()
	var z := x.cross(ey).normalized()
	if z.dot(out) < 0.0:
		z = -z
		x = -x
	var y := z.cross(x)
	return k._box(p, size, surf + z * size.z * 0.5, mat, col, Basis(x, y, z).get_euler(), shadow)


## Reactive armour bricks in a grid on the quad face a-b (bottom edge) /
## c-d (top edge): nu across, nv up, each brick filling its cell less a gap.
static func _era(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nu: int, nv: int, out: Vector3, cam: String, th := 0.1, u0 := 0.0, u1 := 1.0) -> void:
	var ex := b - a
	var ey := (c + d) * 0.5 - (a + b) * 0.5
	var cu := ex.length() * (u1 - u0) / nu
	var cv := ey.length() / nv
	for i in nu:
		for j in nv:
			var u := u0 + (u1 - u0) * (i + 0.5) / nu
			var v := (j + 0.5) / nv
			var pt := a.lerp(b, u).lerp(c.lerp(d, u), v)
			_on_face(k, p, pt, ex, ey, out, Vector3(cu - 0.05, cv - 0.05, th), cam)


## The Euler rotation that turns +Y onto direction d.
static func _aim(d: Vector3) -> Vector3:
	var u := d.normalized()
	if u.dot(Vector3.UP) < -0.9999:
		return Vector3(PI, 0, 0)
	if u.dot(Vector3.UP) > 0.9999:
		return Vector3.ZERO
	return Basis(Quaternion(Vector3.UP, u)).get_euler()


## A round tube from a to b (roll cages, rails, booms, hoses).
static func _tube(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, r: float, mat: String, col = null, segs := 8, shadow := true) -> Variant:
	return k._cyl(p, r, r, a.distance_to(b), (a + b) * 0.5, _aim(b - a), mat, col, segs, shadow)


## A square-section beam from a to b.
static func _beam(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, w: float, h: float, mat: String, col = null) -> Variant:
	return k._box(p, Vector3(w, a.distance_to(b), h), (a + b) * 0.5, mat, col, _aim(b - a))


## A headlight facing f (-1 forward, 1 back): housing, lens, wire guard.
static func _lamp(k: VehicleModels, p: Node3D, pos: Vector3, r := 0.08, f := -1.0, guard := true) -> void:
	k._box(p, Vector3(r * 2.6, r * 2.3, 0.12), pos, "gunmetal_w")
	if not k.burnt:
		k._cyl(p, r, r, 0.03, pos + Vector3(0, 0, f * 0.06), Vector3(PI / 2, 0, 0), "plain", Color(0.72, 0.72, 0.66), 10, false)
	if guard:
		for i in 3:
			k._box(p, Vector3(0.014, r * 2.5, 0.014), pos + Vector3((i - 1) * r * 0.75, 0, f * 0.12), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(p, Vector3(r * 2.7, 0.016, 0.1), pos + Vector3(0, r * 1.2, f * 0.08), "gunmetal_w", null, Vector3.ZERO, false)


## A tail light cluster (red and amber) facing back.
static func _taillight(k: VehicleModels, p: Node3D, pos: Vector3) -> void:
	k._box(p, Vector3(0.22, 0.12, 0.06), pos, "gunmetal_w")
	if not k.burnt:
		k._box(p, Vector3(0.08, 0.07, 0.02), pos + Vector3(-0.05, 0, 0.035), "paint", Color(0.45, 0.06, 0.05), Vector3.ZERO, false)
		k._box(p, Vector3(0.08, 0.07, 0.02), pos + Vector3(0.05, 0, 0.035), "paint", Color(0.55, 0.36, 0.08), Vector3.ZERO, false)


## A jerrycan standing upright, its face toward x (s = side it faces).
static func _jerry(k: VehicleModels, p: Node3D, pos: Vector3, col := Color(0.3, 0.33, 0.22), rot := Vector3.ZERO) -> void:
	k._box(p, Vector3(0.17, 0.46, 0.34), pos, "paint", col, rot)
	k._box(p, Vector3(0.06, 0.05, 0.16), pos + Vector3(0, 0.25, 0.04), "paint", col.darkened(0.2), rot, false)


## An ammo can (olive), its long side along z.
static func _ammo_can(k: VehicleModels, p: Node3D, pos: Vector3, rot := Vector3.ZERO) -> void:
	k._box(p, Vector3(0.16, 0.2, 0.3), pos, "paint", STOW, rot)
	k._box(p, Vector3(0.04, 0.02, 0.18), pos + Vector3(0, 0.11, 0), "gunmetal_w", null, rot, false)


## A whip antenna on a base.
static func _antenna(k: VehicleModels, p: Node3D, pos: Vector3, h := 2.2) -> void:
	k._cyl(p, 0.04, 0.05, 0.12, pos + Vector3(0, 0.06, 0), Vector3.ZERO, "gunmetal_w", null, 8)
	k._cyl(p, 0.008, 0.014, h, pos + Vector3(0, 0.12 + h * 0.5, 0), Vector3.ZERO, "gunmetal_w", null, 4, false)


## A cluster of smoke-grenade dischargers: n tubes fanned on a bracket on the
## side s, pointing out and up; yaw turns the bank (radians about Y).
static func _smoke(k: VehicleModels, p: Node3D, pos: Vector3, s: float, n := 4, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	k._box(p, Vector3(0.14, 0.1, 0.12 * n + 0.04), pos, "gunmetal_w", null, Vector3(0, yaw, 0))
	for i in n:
		var o := b * Vector3(0, 0.07 + (i % 2) * 0.05, (i - (n - 1) * 0.5) * 0.12)
		k._cyl(p, 0.042, 0.042, 0.22, pos + o + Vector3(s * 0.06, 0.04, 0), Vector3(0, yaw, s * -0.9), "gunmetal_w", null, 8, false)


## A tow shackle (a U on its pin) at pos.
static func _shackle(k: VehicleModels, p: Node3D, pos: Vector3, f := -1.0) -> void:
	k._box(p, Vector3(0.14, 0.12, 0.1), pos, "gunmetal_w")
	k._cyl(p, 0.035, 0.035, 0.16, pos + Vector3(0, 0, f * 0.08), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._cyl(p, 0.06, 0.06, 0.035, pos + Vector3(0, -0.02, f * 0.15), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10, false)


## A static spare wheel (not spinning) lying with its axle along `axis`.
static func _spare(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, rot: Vector3) -> void:
	k._cyl(p, r, r, w * 0.8, pos, rot, "rubber", null, 18)
	k._cyl(p, r * 0.93, r * 0.93, w, pos, rot, "rubber", null, 18)
	k._cyl(p, r * 0.58, r * 0.58, w + 0.02, pos, rot, "gunmetal_w", null, 14, false)
	k._cyl(p, r * 0.22, r * 0.22, w + 0.06, pos, rot, "gunmetal_w", null, 8, false)


## The subdued identification panel (VehicleModels._team_mark).
static func _team_mark(k: VehicleModels, p: Node3D, team: int, pos: Vector3, s: Vector3) -> void:
	k._team_mark(p, team, pos, s)


## A seat: pan and back, facing f (-1 forward).
static func _seat(k: VehicleModels, p: Node3D, pos: Vector3, f := -1.0, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	k._box(p, Vector3(0.46, 0.12, 0.46), pos, "canvas", Color(0.2, 0.21, 0.17), Vector3(0, yaw, 0))
	k._box(p, Vector3(0.42, 0.5, 0.1), pos + b * Vector3(0, 0.27, -f * 0.22), "canvas", Color(0.2, 0.21, 0.17), Vector3(f * 0.15, yaw, 0))


# --- weapons -----------------------------------------------------------------------

## An M2 .50 cal on its own, receiver at pos, firing along -Z. Returns the
## muzzle position (in p's space).
static func _m2(k: VehicleModels, p: Node3D, pos: Vector3, grips := false) -> Vector3:
	k._box(p, Vector3(0.15, 0.19, 0.74), pos, "gunmetal_w")
	k._box(p, Vector3(0.1, 0.06, 0.4), pos + Vector3(0, 0.12, -0.08), "gunmetal_w")
	k._cyl(p, 0.042, 0.042, 0.26, pos + Vector3(0, 0, -0.5), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._cyl(p, 0.026, 0.026, 1.0, pos + Vector3(0, 0, -1.1), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6)
	k._cyl(p, 0.038, 0.032, 0.12, pos + Vector3(0, 0, -1.62), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
	if grips:
		for s in [-1.0, 1.0]:
			k._box(p, Vector3(0.03, 0.14, 0.05), pos + Vector3(s * 0.08, -0.02, 0.42), "gunmetal_w", null, Vector3(0.3, 0, 0), false)
	return pos + Vector3(0, 0, -1.69)


## A 40 mm grenade machine gun: a squat receiver, short fat perforated barrel
## and a drum of linked grenades on its right. Returns the muzzle position.
static func _gmg(k: VehicleModels, p: Node3D, pos: Vector3) -> Vector3:
	k._box(p, Vector3(0.24, 0.24, 0.62), pos, "gunmetal_w")
	k._box(p, Vector3(0.18, 0.08, 0.32), pos + Vector3(0, 0.15, 0.05), "gunmetal_w")
	k._cyl(p, 0.075, 0.075, 0.36, pos + Vector3(0, 0.0, -0.48), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k._cyl(p, 0.05, 0.05, 0.2, pos + Vector3(0, 0.0, -0.74), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._cyl(p, 0.062, 0.062, 0.08, pos + Vector3(0, 0.0, -0.86), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
	for i in 3:
		k._cyl(p, 0.078, 0.078, 0.02, pos + Vector3(0, 0, -0.36 - i * 0.1), Vector3(PI / 2, 0, 0), "metal_dark", null, 10, false)
	# the drum feeding in from the right
	k._cyl(p, 0.19, 0.19, 0.16, pos + Vector3(0.24, -0.04, 0.05), Vector3(0, 0, PI / 2), "paint", STOW, 14)
	k._box(p, Vector3(0.1, 0.08, 0.12), pos + Vector3(0.14, 0.05, 0.0), "gunmetal_w")
	return pos + Vector3(0, 0, -0.9)


## A remote weapon station (CROWS / Samson pattern) on a roof at pos: the
## turntable, the yoke, the gun cradle and the sight. gun: "hmg", "gmg" or
## "both" (HMG left, GMG right); sc scales the whole station. Becomes
## k.turret, k.mg_tip at the (HMG's) muzzle - on a tank's turret roof, put
## k.turret back to the main turret afterwards (the station turns with it).
static func _rcws(k: VehicleModels, p: Node3D, pos: Vector3, gun: String, cam: String, sc := 1.0) -> Node3D:
	var t := k._pivot(p, pos)
	t.scale = Vector3.ONE * sc
	k.turret = t
	k._cyl(t, 0.34, 0.38, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, cam, null, 16)
	k._cyl(t, 0.24, 0.28, 0.14, Vector3(0, 0.17, 0), Vector3.ZERO, "gunmetal_w", null, 12)
	var gy := 0.52
	if gun == "both":
		# Samson-style: a wide box between two cradles
		k._box(t, Vector3(0.62, 0.34, 0.6), Vector3(0, 0.36, 0.05), cam)
		k._box(t, Vector3(0.3, 0.2, 0.3), Vector3(0, 0.62, -0.05), cam)
		k._box(t, Vector3(0.22, 0.14, 0.02), Vector3(0, 0.62, -0.21), "glass", null, Vector3.ZERO, false)
		k._box(t, Vector3(0.08, 0.16, 0.08), Vector3(0, 0.75, 0.08), "gunmetal_w")
		var a := _m2(k, t, Vector3(-0.42, 0.42, -0.05))
		k._box(t, Vector3(0.24, 0.26, 0.38), Vector3(-0.42, 0.32, 0.35), "paint", STOW)
		_gmg(k, t, Vector3(0.44, 0.42, -0.05))
		k.mg_tip = k._tip(t, a)
		_smoke(k, t, Vector3(0, 0.3, 0.38), 1.0, 3, PI / 2)
		return t
	# yoke arms either side of the cradle
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.06, 0.42, 0.34), Vector3(s * 0.2, 0.42, 0.02), cam)
	k._cyl(t, 0.045, 0.045, 0.5, Vector3(0, gy, 0.02), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
	var tip: Vector3
	if gun == "gmg":
		tip = _gmg(k, t, Vector3(0, gy, -0.05))
	else:
		tip = _m2(k, t, Vector3(0, gy, 0.0))
		k._box(t, Vector3(0.22, 0.3, 0.42), Vector3(0.33, gy - 0.05, 0.08), "paint", STOW)
	# the sight unit on the left of the cradle: day camera and thermal windows
	k._box(t, Vector3(0.24, 0.26, 0.36), Vector3(-0.36, gy + 0.06, -0.06), cam)
	if not k.burnt:
		k._box(t, Vector3(0.08, 0.08, 0.02), Vector3(-0.41, gy + 0.08, -0.25), "glass", null, Vector3.ZERO, false)
		k._box(t, Vector3(0.08, 0.08, 0.02), Vector3(-0.31, gy + 0.08, -0.25), "glass", null, Vector3.ZERO, false)
	k._box(t, Vector3(0.28, 0.03, 0.42), Vector3(-0.36, gy + 0.2, -0.08), cam)
	k.mg_tip = k._tip(t, tip)
	return t


# --- Hunter: Oshkosh M-ATV ---------------------------------------------------------

## M-ATV: the V-shaped hull under a tall slab-sided crew capsule with four
## heavy doors and small thick windows, a short bonnet with a big grille, the
## open cargo bed behind and the spare wheel on the back. arm: "", "hmg",
## "gmg" (a CROWS remote weapon station on the roof).
static func _hunter(k: VehicleModels, team: int, arm: String) -> void:
	var cam := _cam(team)
	var m := k.root
	var fz := -1.9
	var rz := 1.9
	var wr := 0.59
	var roof := 2.6
	# --- V-hull, engine block, suspension and the wheels
	k._add(m, VehicleModels.loft("nato_matv_v", [-0.22, -1.0, 0.22, -1.0, 0.22, 2.3, -0.22, 2.3], [-0.74, -1.2, 0.74, -1.2, 0.74, 2.55, -0.74, 2.55], 0.41, 1.13), cam, null, Vector3.ZERO)
	k._box(m, Vector3(1.2, 0.5, 1.95), Vector3(0, 0.95, -2.0), "gunmetal_w")
	k._box(m, Vector3(1.3, 0.2, 5.6), Vector3(0, 1.0, -0.1), "gunmetal_w")
	for s in [-1.0, 1.0]:
		for z in [fz, rz]:
			k._wheel(m, Vector3(s * 0.98, wr, z), wr, 0.44)
			k._box(m, Vector3(0.5, 0.07, 0.16), Vector3(s * 0.55, 0.52, z), "gunmetal_w", null, Vector3(0, 0, s * 0.14))
			k._box(m, Vector3(0.46, 0.07, 0.14), Vector3(s * 0.55, 0.84, z - 0.04), "gunmetal_w", null, Vector3(0, 0, -s * 0.12))
			k._cyl(m, 0.075, 0.075, 0.55, Vector3(s * 0.56, 0.88, z + 0.24), Vector3(0, 0, s * 0.4), "metal_dark", null, 8)
	# --- bonnet over the engine, fenders over the front wheels, the grille
	var bon := [-2.95, 1.24, -0.94, 1.24, -0.94, 1.8, -2.45, 1.71, -2.97, 1.5]
	k._add(m, VehicleModels.extrude_x("nato_matv_bonnet", bon, -0.84, 0.84), cam, null, Vector3.ZERO)
	var fen := [-2.94, 1.22, -0.94, 1.22, -0.94, 1.66, -2.4, 1.6, -2.95, 1.44]
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("nato_matv_fender", fen, -0.2, 0.2), cam, null, Vector3(s * 1.04, 0, 0))
		# the wheel arch lip and mud flap behind the front wheel
		k._box(m, Vector3(0.42, 0.05, 1.36), Vector3(s * 1.04, 1.22, fz), "gunmetal_w")
		k._box(m, Vector3(0.36, 0.5, 0.03), Vector3(s * 1.0, 0.98, -1.22), "rubber")
		_lamp(k, m, Vector3(s * 1.02, 1.4, -2.95), 0.078)
		k._box(m, Vector3(0.1, 0.05, 0.03), Vector3(s * 1.15, 1.54, -2.93), "paint", Color(0.55, 0.36, 0.08), Vector3.ZERO, false)
	k._box(m, Vector3(1.3, 0.38, 0.05), Vector3(0, 1.4, -2.97), "gunmetal_w")
	for i in 9:
		k._box(m, Vector3(0.055, 0.34, 0.03), Vector3(-0.54 + i * 0.135, 1.4, -3.0), cam, null, Vector3.ZERO, false)
	k._box(m, Vector3(1.36, 0.05, 0.06), Vector3(0, 1.6, -2.97), cam)
	# the hood's centre bulge and its latches
	k._add(m, VehicleModels.loft("nato_matv_bulge", [-0.44, -2.4, 0.44, -2.4, 0.44, -1.0, -0.44, -1.0], [-0.34, -2.3, 0.34, -2.3, 0.34, -1.0, -0.34, -1.0], 0.0, 0.07), cam, null, Vector3(0, 1.73, 0), Vector3(-0.062, 0, 0))
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.1, 0.06), Vector3(s * 0.74, 1.56, -2.62), "gunmetal_w", null, Vector3.ZERO, false)
	# bumper with tow shackles and a recovery winch
	k._box(m, Vector3(2.3, 0.3, 0.26), Vector3(0, 1.0, -3.02), "steel", Color(0.28, 0.3, 0.22))
	k._box(m, Vector3(0.6, 0.2, 0.14), Vector3(0, 1.0, -3.15), "gunmetal_w")
	for s in [-1.0, 1.0]:
		_shackle(k, m, Vector3(s * 0.62, 0.94, -3.08))
	# --- the crew capsule: vertical lower sides, the upper sides leaning in,
	# a lightly raked windscreen
	var lo := [-1.2, -0.98, 1.2, -0.98, 1.2, 1.62, -1.2, 1.62]
	var mid := [-1.24, -0.98, 1.24, -0.98, 1.24, 1.62, -1.24, 1.62]
	var top := [-1.04, -0.68, 1.04, -0.68, 1.04, 1.5, -1.04, 1.5]
	k._add(m, VehicleModels.solid([VehicleModels.ring_y(VehicleModels._v2(lo), 1.12), VehicleModels.ring_y(VehicleModels._v2(mid), 1.68), VehicleModels.ring_y(VehicleModels._v2(top), roof)], "nato_matv_cab"), cam, null, Vector3.ZERO)
	# windscreen: two small thick panes in a heavy frame
	for s in [-1.0, 1.0]:
		_zy(k, m, s * 0.47, 0.72, Vector2(-0.905, 1.92), Vector2(-0.745, 2.4), 0.05, 0.0, "glass", null, false)
		_zy(k, m, s * 0.47, 0.84, Vector2(-0.92, 1.87), Vector2(-0.73, 2.45), 0.03, -0.01, "gunmetal_w", null, false)
	# doors: seams, small thick windows on the upper sides, handles, hinges
	for s in [-1.0, 1.0]:
		for dz in [-0.88, 0.32, 1.48]:
			k._box(m, Vector3(0.02, 0.6, 0.03), Vector3(s * 1.245, 1.37, dz), "gunmetal_w", null, Vector3.ZERO, false)
			_xy(k, m, s, dz, 0.03, Vector2(1.24, 1.68), Vector2(1.08, 2.45), 0.02, 0.005, "gunmetal_w", null, false)
		for wz in [-0.28, 0.9]:
			_xy(k, m, s, wz, 0.5, Vector2(1.2, 1.88), Vector2(1.11, 2.32), 0.07, 0.0, cam)
			_xy(k, m, s, wz, 0.4, Vector2(1.2, 1.93), Vector2(1.12, 2.28), 0.03, 0.045, "glass", null, false)
		for dz in [-0.05, 1.18]:
			k._box(m, Vector3(0.04, 0.05, 0.16), Vector3(s * 1.27, 1.56, dz), "gunmetal_w", null, Vector3.ZERO, false)
		for dz in [-0.8, 0.4]:
			k._box(m, Vector3(0.05, 0.12, 0.06), Vector3(s * 1.26, 1.3, dz), "gunmetal_w", null, Vector3.ZERO, false)
			k._box(m, Vector3(0.05, 0.12, 0.06), Vector3(s * 1.19, 2.0, dz), "gunmetal_w", null, Vector3(0, 0, s * 0.21), false)
		# the steps under the doors, the mirror on its arm
		k._box(m, Vector3(0.24, 0.05, 0.5), Vector3(s * 1.2, 0.98, -0.3), "gunmetal_w")
		k._box(m, Vector3(0.24, 0.05, 0.4), Vector3(s * 1.2, 0.98, 0.9), "gunmetal_w")
		_tube(k, m, Vector3(s * 1.17, 2.2, -0.74), Vector3(s * 1.44, 2.24, -0.92), 0.02, "gunmetal_w")
		k._box(m, Vector3(0.05, 0.32, 0.2), Vector3(s * 1.46, 2.16, -0.94), "gunmetal_w")
		# stowage box low on the capsule side by the rear door
		k._box(m, Vector3(0.14, 0.26, 0.5), Vector3(s * 1.3, 1.26, 1.15), cam)
	# the engine air intake up the right A-pillar
	_zy(k, m, 1.27, 0.18, Vector2(-0.95, 1.8), Vector2(-0.72, 2.5), 0.2, 0.06, cam)
	k._box(m, Vector3(0.22, 0.12, 0.28), Vector3(1.27, 2.52, -0.72), "gunmetal_w")
	# roof: rails, antennas, the lights over the windscreen
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.05, 2.1), Vector3(s * 0.96, roof + 0.02, 0.42), "gunmetal_w")
		_antenna(k, m, Vector3(s * 0.86, roof, 1.36), 1.3)
		k._box(m, Vector3(0.16, 0.1, 0.1), Vector3(s * 0.35, roof + 0.05, -0.62), "gunmetal_w")
	# --- the cargo bed behind the capsule, fenders over the rear wheels
	k._add(m, VehicleModels.loft("nato_matv_bed", [-1.2, 1.5, 1.2, 1.5, 1.2, 2.75, -1.2, 2.75], [-1.2, 1.5, 1.2, 1.5, 1.2, 2.78, -1.2, 2.78], 1.22, 1.46), cam, null, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.08, 0.5, 1.24), Vector3(s * 1.18, 1.7, 2.15), cam)
		k._box(m, Vector3(0.44, 0.05, 1.36), Vector3(s * 1.02, 1.22, rz), "gunmetal_w")
		k._box(m, Vector3(0.36, 0.42, 0.03), Vector3(s * 1.0, 1.0, 2.76), "rubber")
		_jerry(k, m, Vector3(s * 0.88, 1.7, 2.0))
		_taillight(k, m, Vector3(s * 0.95, 1.32, 2.8))
		_shackle(k, m, Vector3(s * 0.55, 1.12, 2.82), 1.0)
	k._box(m, Vector3(2.3, 0.1, 0.08), Vector3(0, 1.92, 2.74), cam)
	_zy(k, m, -0.45, 0.5, Vector2(1.537, 2.32), Vector2(1.581, 1.98), 0.06, 0.0, cam)
	_zy(k, m, -0.45, 0.4, Vector2(1.54, 2.29), Vector2(1.578, 2.01), 0.03, 0.035, "glass", null, false)
	k._box(m, Vector3(0.5, 0.05, 0.2), Vector3(-0.6, 1.05, 2.86), "gunmetal_w")
	k._box(m, Vector3(1.1, 0.36, 0.5), Vector3(-0.15, 1.64, 2.1), "canvas", BAG, Vector3(0, 0.1, 0))
	# the spare wheel on its swing-out carrier
	_spare(k, m, Vector3(0.22, 1.66, 3.0), 0.56, 0.38, Vector3(PI / 2, 0, 0))
	k._box(m, Vector3(0.12, 0.8, 0.1), Vector3(0.22, 1.66, 2.8), "gunmetal_w")
	k._box(m, Vector3(1.1, 0.1, 0.1), Vector3(0.0, 1.36, 2.82), "gunmetal_w")
	_team_mark(k, m, team, Vector3(1.228, 1.36, -0.3), Vector3(0.02, 0.2, 0.5))
	_team_mark(k, m, team, Vector3(-1.228, 1.36, -0.3), Vector3(0.02, 0.2, 0.5))
	# --- the roof: a remote weapon station, or the gunner's hatch closed
	if arm == "":
		k._cyl(m, 0.42, 0.44, 0.08, Vector3(0, roof + 0.04, 0.4), Vector3.ZERO, cam, null, 16)
		k._cyl(m, 0.36, 0.36, 0.05, Vector3(0, roof + 0.1, 0.4), Vector3.ZERO, cam, null, 16)
		k._box(m, Vector3(0.1, 0.06, 0.2), Vector3(0.3, roof + 0.13, 0.4), "gunmetal_w")
		return
	_rcws(k, m, Vector3(0, roof, 0.35), arm, cam, 1.15)


# --- Prowler: Polaris DAGOR ---------------------------------------------------------

## DAGOR: a low open chassis on big off-road tyres, a flat bonnet, the tube
## roll cage over two rows of seats and the rear cargo deck with outward
## benches. arm: "" (none), "hmg" (an M2 on a ring mount on the cage, a
## pintle MG for the passenger), "at" (a Titan launcher on the cage mount).
static func _prowler(k: VehicleModels, team: int, arm: String) -> void:
	var cam := _cam(team)
	var m := k.root
	var wr := 0.46
	var fz := -1.6
	var rz := 1.5
	# --- the chassis tub, belly plate and suspension
	k._add(m, VehicleModels.loft("nato_dagor_tub", [-0.5, -1.95, 0.5, -1.95, 0.5, 2.1, -0.5, 2.1], [-0.6, -2.05, 0.6, -2.05, 0.6, 2.2, -0.6, 2.2], 0.42, 0.78), cam, null, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		for z in [fz, rz]:
			k._wheel(m, Vector3(s * 0.79, wr, z), wr, 0.32)
			k._box(m, Vector3(0.36, 0.06, 0.12), Vector3(s * 0.5, 0.42, z), "gunmetal_w", null, Vector3(0, 0, s * 0.1))
			k._box(m, Vector3(0.36, 0.06, 0.12), Vector3(s * 0.5, 0.66, z), "gunmetal_w", null, Vector3(0, 0, -s * 0.1))
			k._cyl(m, 0.05, 0.05, 0.5, Vector3(s * 0.5, 0.8, z + (0.18 if z > 0 else -0.18)), Vector3(0, 0, s * 0.45), "metal_dark", null, 8)
	# --- the flat bonnet, its fenders and the nose
	var bon := [-2.24, 0.62, -0.92, 0.62, -0.92, 1.1, -2.1, 1.06, -2.26, 0.94]
	k._add(m, VehicleModels.extrude_x("nato_dagor_bonnet", bon, -0.66, 0.66), cam, null, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.36, 0.035, 1.1), Vector3(s * 0.8, 0.98, fz), cam, null, Vector3(0, 0, -s * 0.06))
		k._box(m, Vector3(0.36, 0.035, 0.3), Vector3(s * 0.8, 0.91, fz - 0.66), cam, null, Vector3(-0.45, 0, -s * 0.06))
		k._box(m, Vector3(0.36, 0.035, 0.9), Vector3(s * 0.8, 0.98, rz), cam, null, Vector3(0, 0, -s * 0.06))
	k._box(m, Vector3(1.0, 0.28, 0.04), Vector3(0, 0.82, -2.27), "gunmetal_w")
	for i in 6:
		k._box(m, Vector3(0.04, 0.24, 0.02), Vector3(-0.4 + i * 0.16, 0.82, -2.29), cam, null, Vector3.ZERO, false)
	# tube bumper with the winch, lights each side and on the cage
	_tube(k, m, Vector3(-0.85, 0.66, -2.32), Vector3(0.85, 0.66, -2.32), 0.045, "gunmetal_w")
	_tube(k, m, Vector3(-0.85, 0.66, -2.32), Vector3(-0.72, 0.6, -2.08), 0.04, "gunmetal_w")
	_tube(k, m, Vector3(0.85, 0.66, -2.32), Vector3(0.72, 0.6, -2.08), 0.04, "gunmetal_w")
	k._box(m, Vector3(0.42, 0.18, 0.14), Vector3(0, 0.6, -2.3), "gunmetal_w")
	for s in [-1.0, 1.0]:
		_lamp(k, m, Vector3(s * 0.52, 0.9, -2.3), 0.065, -1.0, false)
		_shackle(k, m, Vector3(s * 0.35, 0.56, -2.24))
	# --- the cockpit: dash, the cowl, seats, steering wheel
	k._box(m, Vector3(1.3, 0.24, 0.2), Vector3(0, 1.06, -0.86), cam)
	k._box(m, Vector3(1.4, 0.1, 3.0), Vector3(0, 0.82, 0.62), "gunmetal_w")
	for x in [-0.36, 0.36]:
		_seat(k, m, Vector3(x, 0.94, -0.3))
		_seat(k, m, Vector3(x, 0.98, 0.62))
	_tube(k, m, Vector3(-0.36, 1.05, -0.8), Vector3(-0.36, 1.2, -0.62), 0.025, "gunmetal_w")
	k._cyl(m, 0.17, 0.17, 0.03, Vector3(-0.36, 1.22, -0.6), Vector3(-0.9, 0, 0), "rubber", null, 14, false)
	# rear deck: outward-facing benches either side, kit stowed between
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.4, 0.1, 0.9), Vector3(s * 0.45, 1.0, 1.62), "canvas", Color(0.2, 0.21, 0.17))
		k._box(m, Vector3(0.08, 0.36, 0.88), Vector3(s * 0.22, 1.2, 1.62), "canvas", Color(0.2, 0.21, 0.17))
		k._box(m, Vector3(0.34, 0.32, 0.28), Vector3(s * 0.62, 0.62, 1.95), "gunmetal_w")
	k._box(m, Vector3(0.36, 0.3, 0.6), Vector3(0, 1.05, 1.4), "canvas", BAG)
	_ammo_can(k, m, Vector3(-0.08, 1.01, 2.0))
	_ammo_can(k, m, Vector3(0.1, 1.01, 2.0))
	_jerry(k, m, Vector3(0.82, 0.95, 0.4), Color(0.3, 0.33, 0.22))
	_jerry(k, m, Vector3(-0.82, 0.95, 0.4), Color(0.3, 0.33, 0.22))
	# the spare wheel upright on the tailgate
	_spare(k, m, Vector3(0, 1.16, 2.25), 0.44, 0.28, Vector3(PI / 2, 0, 0))
	k._box(m, Vector3(0.9, 0.08, 0.08), Vector3(0, 1.1, 2.16), "gunmetal_w")
	for s in [-1.0, 1.0]:
		_taillight(k, m, Vector3(s * 0.62, 0.72, 2.24))
	# --- the roll cage
	var cr := 0.035
	var ry := 1.8
	for s in [-1.0, 1.0]:
		var x0: float = s * 0.7
		var x1: float = s * 0.68
		_tube(k, m, Vector3(x0, 1.08, -0.92), Vector3(x1, ry, -0.28), cr, cam)  # A-pillar
		_tube(k, m, Vector3(x1, 0.8, 0.12), Vector3(x1, ry, 0.12), cr, cam)  # B-post
		_tube(k, m, Vector3(x1, 0.8, 1.05), Vector3(x1, ry, 1.05), cr, cam)  # C-post
		_tube(k, m, Vector3(x1, ry, -0.28), Vector3(x1, ry, 1.05), cr, cam)  # roof rail
		_tube(k, m, Vector3(x1, ry, 1.05), Vector3(x1 * 0.98, 1.32, 2.15), cr, cam)  # over the deck
		_tube(k, m, Vector3(x1 * 0.98, 1.32, 2.15), Vector3(x1 * 0.98, 0.8, 2.15), cr, cam)
		_tube(k, m, Vector3(x1, 1.3, 0.12), Vector3(x1, 1.3, 1.05), cr * 0.8, cam)  # side bar
		_tube(k, m, Vector3(x1, 0.8, 0.12), Vector3(x1, 1.6, 1.05), cr * 0.7, cam)  # diagonal
	for z in [-0.28, 0.12, 1.05]:
		_tube(k, m, Vector3(-0.68, ry, z), Vector3(0.68, ry, z), cr, cam)
	_tube(k, m, Vector3(-0.67, 1.32, 2.15), Vector3(0.67, 1.32, 2.15), cr, cam)
	_tube(k, m, Vector3(-0.68, ry, 0.12), Vector3(0.68, ry, 1.05), cr * 0.8, cam)
	# light bar on the front roof bar, antennas at the back
	k._box(m, Vector3(0.9, 0.09, 0.08), Vector3(0, ry + 0.05, -0.3), "gunmetal_w")
	if not k.burnt:
		for i in 4:
			k._box(m, Vector3(0.14, 0.06, 0.02), Vector3(-0.33 + i * 0.22, ry + 0.05, -0.345), "plain", Color(0.72, 0.72, 0.66), Vector3.ZERO, false)
	_antenna(k, m, Vector3(-0.66, 1.3, 2.12), 1.8)
	_team_mark(k, m, team, Vector3(0.67, 0.98, -1.4), Vector3(0.02, 0.06, 0.6))
	_team_mark(k, m, team, Vector3(-0.67, 0.98, -1.4), Vector3(0.02, 0.06, 0.6))
	if arm == "":
		return
	# the passenger's pintle MG (an M240-class .338) on a swing arm
	var pz := -0.78
	_tube(k, m, Vector3(0.6, 1.08, pz), Vector3(0.6, 1.38, pz), 0.03, "gunmetal_w")
	k._box(m, Vector3(0.08, 0.12, 0.6), Vector3(0.6, 1.45, pz - 0.1), "gunmetal_w")
	k._cyl(m, 0.02, 0.02, 0.7, Vector3(0.6, 1.46, pz - 0.75), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	k._box(m, Vector3(0.1, 0.12, 0.14), Vector3(0.68, 1.4, pz - 0.05), "paint", STOW)
	var ptip := Vector3(0.6, 1.46, pz - 1.12)
	# the ring mount on the cage roof
	var t := k._pivot(m, Vector3(0, ry + 0.02, 0.58))
	k.turret = t
	for i in 12:
		var a0 := TAU * i / 12.0
		var a1 := TAU * (i + 1) / 12.0
		_tube(k, t, Vector3(sin(a0) * 0.48, 0, cos(a0) * 0.48), Vector3(sin(a1) * 0.48, 0, cos(a1) * 0.48), 0.03, "gunmetal_w", null, 6)
	_tube(k, t, Vector3(-0.48, 0, 0), Vector3(0.48, 0, 0), 0.025, "gunmetal_w", null, 6)
	k._cyl(t, 0.05, 0.06, 0.32, Vector3(0, 0.16, -0.12), Vector3.ZERO, "gunmetal_w", null, 8)
	if arm == "hmg":
		var tip := _m2(k, t, Vector3(0, 0.42, -0.12), true)
		k._box(t, Vector3(0.22, 0.26, 0.36), Vector3(0.2, 0.36, -0.1), "paint", STOW)
		k.mg_tip = k._tip(t, tip)
		# the pintle gun is the second gun, decoration here
	else:
		# Titan launcher: the tube, the sight/command unit, the grip
		var ly := 0.48
		k._cyl(t, 0.085, 0.085, 1.25, Vector3(0, ly, -0.25), Vector3(PI / 2, 0, 0), "paint", Color(0.33, 0.35, 0.27), 12)
		k._cyl(t, 0.1, 0.1, 0.1, Vector3(0, ly, -0.86), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
		k._cyl(t, 0.1, 0.1, 0.1, Vector3(0, ly, 0.36), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
		k._box(t, Vector3(0.22, 0.24, 0.42), Vector3(-0.2, ly - 0.02, -0.1), "gunmetal_w")
		if not k.burnt:
			k._box(t, Vector3(0.14, 0.12, 0.02), Vector3(-0.2, ly, -0.315), "glass", null, Vector3.ZERO, false)
		k._box(t, Vector3(0.12, 0.2, 0.12), Vector3(0, ly - 0.2, -0.1), "gunmetal_w")
		k.gun_tip = k._tip(t, Vector3(0, ly, -0.92))
		# two reloads in a rack on the deck
		for x in [-0.12, 0.12]:
			k._cyl(m, 0.08, 0.08, 1.2, Vector3(x, 1.12, 1.85), Vector3(PI / 2, 0, 0), "paint", Color(0.33, 0.35, 0.27), 10)
	if k.mg_tip == null:
		k.mg_tip = k._tip(m, ptip)


# --- 8x8s: Marshall (Patria AMV), Rhino (Rooikat MTTD) ---------------------------------

## Road wheels on independent suspension either side at +-x: the tyres, the
## lower and upper arms going in to the hull, a mud flap behind the last.
static func _axles(k: VehicleModels, m: Node3D, x: float, zs: Array, r: float, w: float) -> void:
	for s in [-1.0, 1.0]:
		for z in zs:
			k._wheel(m, Vector3(s * x, r, z), r, w)
			k._box(m, Vector3(0.42, 0.08, 0.16), Vector3(s * (x - 0.4), r - 0.08, z), "gunmetal_w", null, Vector3(0, 0, s * 0.14))
			k._box(m, Vector3(0.38, 0.07, 0.14), Vector3(s * (x - 0.4), r + 0.24, z - 0.05), "gunmetal_w", null, Vector3(0, 0, -s * 0.12))
		var zl: float = zs[zs.size() - 1]
		k._box(m, Vector3(w + 0.04, 0.42, 0.03), Vector3(s * x, r * 0.85, zl + r + 0.12), "rubber")


## Patria AMV with the Denel 40 mm turret: the long flat-sided hull over eight
## big wheels, the long raked glacis with the trim vane folded on it, the
## driver forward left beside the engine, the troop compartment and its ramp
## at the back, the two-man turret mid-hull.
static func _marshall(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	var m := k.root
	var wr := 0.6
	var roof := 2.14
	_axles(k, m, 1.08, [-2.55, -1.05, 0.8, 2.3], wr, 0.44)
	# lower hull between the wheels; the nose and tail blocks full width
	k._add(m, VehicleModels.loft("nato_amv_low", [-0.6, -3.1, 0.6, -3.1, 0.6, 3.5, -0.6, 3.5], [-0.86, -3.6, 0.86, -3.6, 0.86, 3.85, -0.86, 3.85], 0.46, 1.27), cam, null, Vector3.ZERO)
	k._add(m, VehicleModels.loft("nato_amv_nose", [-1.1, -3.45, 1.1, -3.45, 1.25, -3.25, -1.25, -3.25], [-1.15, -3.85, 1.15, -3.85, 1.38, -3.25, -1.38, -3.25], 0.78, 1.27), cam, null, Vector3.ZERO)
	k._add(m, VehicleModels.loft("nato_amv_tail", [-1.3, 2.98, 1.3, 2.98, 1.3, 3.8, -1.3, 3.8], [-1.38, 2.98, 1.38, 2.98, 1.38, 3.85, -1.38, 3.85], 0.74, 1.27), cam, null, Vector3.ZERO)
	# the upper hull: a vertical band over the wheels, then the sides leaning in
	var r0 := [-1.15, -3.85, 1.15, -3.85, 1.4, -3.45, 1.4, 3.85, -1.4, 3.85, -1.4, -3.45]
	var r1 := [-1.1, -3.72, 1.1, -3.72, 1.4, -3.3, 1.4, 3.85, -1.4, 3.85, -1.4, -3.3]
	var r2 := [-0.92, -2.42, 0.92, -2.42, 1.16, -2.18, 1.16, 3.78, -1.16, 3.78, -1.16, -2.18]
	k._add(m, VehicleModels.solid([VehicleModels.ring_y(VehicleModels._v2(r0), 1.26), VehicleModels.ring_y(VehicleModels._v2(r1), 1.56), VehicleModels.ring_y(VehicleModels._v2(r2), roof)], "nato_amv_hull"), cam, null, Vector3.ZERO)
	# wheel wells: dark liners under the overhang over each wheel
	for s in [-1.0, 1.0]:
		for z in [-2.55, -1.05, 0.8, 2.3]:
			k._box(m, Vector3(0.5, 0.03, 1.3), Vector3(s * 1.12, 1.245, z), "gunmetal_w", null, Vector3.ZERO, false)
	# glacis: the trim vane folded flat, the driver's hatch and periscopes,
	# the engine deck grilles on the right, lights and tow eyes on the nose
	var ga := Vector2(-3.72, 1.56)
	var gb := Vector2(-2.42, roof)
	_zy(k, m, 0.0, 2.3, ga.lerp(gb, 0.12), ga.lerp(gb, 0.62), 0.06, 0.03, cam)
	for x in [-0.8, 0.0, 0.8]:
		_zy(k, m, x, 0.22, ga.lerp(gb, 0.1), ga.lerp(gb, 0.15), 0.06, 0.07, "gunmetal_w")
	for s in [-1.0, 1.0]:
		_zy(k, m, s * 1.08, 0.06, ga.lerp(gb, 0.6), ga.lerp(gb, 0.72), 0.12, 0.06, "gunmetal_w")
	k._cyl(m, 0.3, 0.3, 0.06, Vector3(-0.6, roof + 0.03, -2.0), Vector3.ZERO, cam, null, 14)
	for i in 3:
		k._box(m, Vector3(0.16, 0.1, 0.07), Vector3(-0.78 + i * 0.18, roof + 0.05, -2.36), "gunmetal_w", null, Vector3(0, (i - 1) * 0.3, 0))
	k._box(m, Vector3(1.0, 0.04, 1.1), Vector3(0.42, roof + 0.01, -1.55), "gunmetal_w")
	for i in 6:
		k._box(m, Vector3(0.9, 0.025, 0.05), Vector3(0.42, roof + 0.035, -2.0 + i * 0.18), cam, null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		_lamp(k, m, Vector3(s * 1.0, 1.14, -3.6), 0.07)
		_lamp(k, m, Vector3(s * 0.72, 1.14, -3.68), 0.06, -1.0, false)
		_shackle(k, m, Vector3(s * 0.5, 0.9, -3.62))
	# exhaust grille on the right side, forward
	k._box(m, Vector3(0.06, 0.32, 0.6), Vector3(1.4, 1.42, -2.2), "gunmetal_w")
	# side details: stowage bins on the sloping sides, the hull door seams,
	# vision blocks, a tow cable
	for s in [-1.0, 1.0]:
		_xy(k, m, s, 0.2, 1.3, Vector2(1.4, 1.56), Vector2(1.16, roof), 0.14, 0.07, cam)
		_xy(k, m, s, 2.6, 1.1, Vector2(1.4, 1.56), Vector2(1.16, roof), 0.14, 0.07, cam)
		for z in [-0.9, 1.5]:
			_xy(k, m, s, z, 0.22, Vector2(1.36, 1.64), Vector2(1.26, 1.86), 0.05, 0.02, "glass", null, false)
		_tube(k, m, Vector3(s * 1.42, 1.38, -2.9), Vector3(s * 1.42, 1.38, 3.3), 0.025, "gunmetal_w", null, 6)
		k._box(m, Vector3(0.05, 0.12, 0.3), Vector3(s * 1.42, 1.4, 3.5), "gunmetal_w")
		_antenna(k, m, Vector3(s * 0.95, roof, 3.45), 1.6)
	# roof over the troop compartment: two hatches, periscopes
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.72, 0.06, 0.95), Vector3(s * 0.48, roof + 0.03, 2.55), cam)
		k._box(m, Vector3(0.06, 0.06, 0.2), Vector3(s * 0.2, roof + 0.08, 2.2), "gunmetal_w")
		for z in [1.75, 3.4]:
			k._box(m, Vector3(0.14, 0.1, 0.12), Vector3(s * 0.95, roof + 0.05, z), "gunmetal_w")
	# the rear: ramp with its door, hinges, lights, steps
	k._box(m, Vector3(1.75, 1.15, 0.08), Vector3(0, 1.4, 3.86), cam)
	k._box(m, Vector3(0.6, 0.95, 0.04), Vector3(0.42, 1.48, 3.91), cam)
	k._box(m, Vector3(0.04, 0.08, 0.16), Vector3(0.18, 1.45, 3.95), "gunmetal_w", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		k._cyl(m, 0.06, 0.06, 0.3, Vector3(s * 0.62, 0.86, 3.88), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
		_taillight(k, m, Vector3(s * 1.15, 1.72, 3.82))
		_shackle(k, m, Vector3(s * 1.05, 0.92, 3.86), 1.0)
		_jerry(k, m, Vector3(s * 1.15, 1.25, 3.95), Color(0.3, 0.33, 0.22), Vector3(0, PI / 2, 0))
	_team_mark(k, m, team, Vector3(1.405, 1.42, 1.5), Vector3(0.02, 0.2, 0.7))
	_team_mark(k, m, team, Vector3(-1.405, 1.42, 1.5), Vector3(0.02, 0.2, 0.7))
	# --- the turret: low and faceted, the 40 mm, smoke dischargers, the
	# commander's panoramic sight on its mast
	var t := k._pivot(m, Vector3(0, roof, 0.2))
	k.turret = t
	k._cyl(t, 0.9, 0.95, 0.08, Vector3(0, 0.04, 0.1), Vector3.ZERO, cam, null, 20)
	var tb := [-0.42, -1.05, 0.42, -1.05, 0.94, -0.55, 0.97, 1.12, 0.74, 1.4, -0.74, 1.4, -0.97, 1.12, -0.94, -0.55]
	var tt := [-0.34, -0.76, 0.34, -0.76, 0.76, -0.4, 0.79, 1.02, 0.6, 1.24, -0.6, 1.24, -0.79, 1.02, -0.76, -0.4]
	k._add(t, VehicleModels.loft("nato_amv_tur", tb, tt, 0.06, 0.74), cam, null, Vector3.ZERO)
	# gun: the mantlet, the barrel with its jacket, the muzzle brake
	k._box(t, Vector3(0.44, 0.36, 0.4), Vector3(0, 0.34, -1.18), cam)
	k._cyl(t, 0.1, 0.1, 0.6, Vector3(0, 0.34, -1.62), Vector3(PI / 2, 0, 0), "paint", GUN, 12)
	k._cyl(t, 0.052, 0.058, 2.4, Vector3(0, 0.34, -3.1), Vector3(PI / 2, 0, 0), "paint", GUN, 10)
	k._cyl(t, 0.08, 0.08, 0.3, Vector3(0, 0.34, -4.38), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k._cyl(t, 0.066, 0.066, 0.06, Vector3(0, 0.34, -4.56), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
	k.mg_tip = k._tip(t, Vector3(0, 0.34, -4.6))
	# coaxial MG port beside the mantlet
	k._cyl(t, 0.025, 0.025, 0.3, Vector3(0.32, 0.3, -1.3), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	# sights: gunner's forward left, the commander's panoramic sight on a mast
	k._box(t, Vector3(0.3, 0.26, 0.34), Vector3(-0.42, 0.78, -0.5), cam)
	k._box(t, Vector3(0.22, 0.16, 0.02), Vector3(-0.42, 0.8, -0.68), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.08, 0.1, 0.2, Vector3(0.45, 0.82, 0.55), Vector3.ZERO, "gunmetal_w", null, 10)
	k._box(t, Vector3(0.36, 0.3, 0.36), Vector3(0.45, 1.05, 0.55), cam)
	k._box(t, Vector3(0.24, 0.16, 0.02), Vector3(0.45, 1.07, 0.36), "glass", null, Vector3.ZERO, false)
	# hatches, smoke dischargers, bustle stowage, antenna
	k._cyl(t, 0.3, 0.3, 0.06, Vector3(-0.42, 0.69, 0.6), Vector3.ZERO, cam, null, 14)
	k._box(t, Vector3(0.12, 0.08, 0.2), Vector3(-0.2, 0.74, 0.6), "gunmetal_w")
	for s in [-1.0, 1.0]:
		_smoke(k, t, Vector3(s * 0.92, 0.5, -0.55), s, 4, s * -0.55)
		k._box(t, Vector3(0.06, 0.3, 0.9), Vector3(s * 1.0, 0.36, 0.55), cam, null, Vector3(0, 0, s * 0.18))
	k._box(t, Vector3(1.5, 0.05, 0.4), Vector3(0, 0.22, 1.72), "gunmetal_w")
	k._box(t, Vector3(1.5, 0.3, 0.04), Vector3(0, 0.38, 1.92), "gunmetal_w")
	k._box(t, Vector3(0.7, 0.32, 0.36), Vector3(-0.35, 0.42, 1.72), "canvas", BAG, Vector3(0, 0.08, 0))
	_antenna(k, t, Vector3(-0.6, 0.66, 1.25), 1.5)


## Rooikat with the 120 mm MTTD turret: a long low hull with a pointed nose
## and a ridge up the glacis, the sides leaning in over eight big wheels, the
## big turret set mid-rear with its long bustle and the long 120 mm with a
## fume extractor. up: reactive armour on the nose and turret, slat cages
## along the sides and over the back, and a remote .50 on the turret roof.
static func _rhino(k: VehicleModels, team: int, up: bool) -> void:
	var cam := _cam(team)
	var m := k.root
	var wr := 0.6
	var roof := 1.96
	_axles(k, m, 1.1, [-2.45, -0.95, 1.05, 2.5], wr, 0.44)
	# the lower hull: a pointed nose under the glacis, sides inboard of the wheels
	var lb := [-0.1, -3.0, 0.1, -3.0, 0.62, -2.7, 0.62, 3.3, -0.62, 3.3, -0.62, -2.7]
	var lt := [-0.16, -3.58, 0.16, -3.58, 0.88, -3.05, 0.88, 3.55, -0.88, 3.55, -0.88, -3.05]
	k._add(m, VehicleModels.loft("nato_rk_low", lb, lt, 0.5, 1.22), cam, null, Vector3.ZERO)
	k._add(m, VehicleModels.loft("nato_rk_tail", [-1.3, 3.08, 1.3, 3.08, 1.3, 3.5, -1.3, 3.5], [-1.4, 3.08, 1.4, 3.08, 1.4, 3.55, -1.4, 3.55], 0.75, 1.22), cam, null, Vector3.ZERO)
	# the upper hull: the arrowhead nose climbing to a narrow front of the roof
	var u0 := [-0.16, -3.58, 0.16, -3.58, 1.42, -2.78, 1.42, 3.55, -1.42, 3.55, -1.42, -2.78]
	var u1 := [-0.15, -3.42, 0.15, -3.42, 1.42, -2.62, 1.42, 3.55, -1.42, 3.55, -1.42, -2.62]
	var u2 := [-0.36, -2.3, 0.36, -2.3, 1.12, -1.82, 1.12, 3.48, -1.12, 3.48, -1.12, -1.82]
	k._add(m, VehicleModels.solid([VehicleModels.ring_y(VehicleModels._v2(u0), 1.21), VehicleModels.ring_y(VehicleModels._v2(u1), 1.45), VehicleModels.ring_y(VehicleModels._v2(u2), roof)], "nato_rk_hull"), cam, null, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		for z in [-2.45, -0.95, 1.05, 2.5]:
			k._box(m, Vector3(0.52, 0.03, 1.3), Vector3(s * 1.12, 1.195, z), "gunmetal_w", null, Vector3.ZERO, false)
	# the driver's hatch centred at the top of the glacis, his periscopes,
	# lights in guards on the nose, tow eyes
	k._cyl(m, 0.28, 0.28, 0.06, Vector3(0, roof + 0.03, -1.9), Vector3.ZERO, cam, null, 14)
	for i in 3:
		k._box(m, Vector3(0.16, 0.1, 0.07), Vector3(-0.18 + i * 0.18, roof + 0.05, -2.24), "gunmetal_w", null, Vector3(0, (i - 1) * 0.35, 0))
	_tube(k, m, Vector3(0, 1.22, -3.56), Vector3(0, roof + 0.01, -2.3), 0.04, cam)
	for s in [-1.0, 1.0]:
		_lamp(k, m, Vector3(s * 0.95, 1.36, -2.88), 0.07)
		_shackle(k, m, Vector3(s * 0.32, 0.98, -3.32))
		# big stowage bins along the leaning sides, the engine deck louvres
		_xy(k, m, s, -0.6, 1.5, Vector2(1.42, 1.45), Vector2(1.12, roof), 0.16, 0.08, cam)
		_xy(k, m, s, 1.25, 1.2, Vector2(1.42, 1.45), Vector2(1.12, roof), 0.16, 0.08, cam)
		k._box(m, Vector3(0.06, 0.06, 2.8), Vector3(s * 1.44, 1.32, 0.3), "gunmetal_w")
		k._box(m, Vector3(0.05, 0.3, 0.55), Vector3(s * 1.43, 1.0, 3.1), "gunmetal_w")
		_taillight(k, m, Vector3(s * 1.15, 1.5, 3.57))
		_shackle(k, m, Vector3(s * 0.7, 0.95, 3.58), 1.0)
		_antenna(k, m, Vector3(s * 0.95, roof, 3.3), 1.5)
	k._box(m, Vector3(1.6, 0.04, 0.9), Vector3(0, roof + 0.01, 2.85), "gunmetal_w")
	for i in 5:
		k._box(m, Vector3(1.5, 0.025, 0.05), Vector3(0, roof + 0.035, 2.5 + i * 0.18), cam, null, Vector3.ZERO, false)
	k._box(m, Vector3(1.9, 0.6, 0.06), Vector3(0, 1.5, 3.57), "gunmetal_w")
	_team_mark(k, m, team, Vector3(1.425, 1.33, -1.6), Vector3(0.02, 0.18, 0.6))
	_team_mark(k, m, team, Vector3(-1.425, 1.33, -1.6), Vector3(0.02, 0.18, 0.6))
	# --- the turret: wedged front faces round the gun, a long bustle
	var t := k._pivot(m, Vector3(0, roof, 0.5))
	k.turret = t
	k._cyl(t, 1.05, 1.1, 0.08, Vector3(0, 0.04, 0), Vector3.ZERO, cam, null, 20)
	var tb := [-0.48, -1.5, 0.48, -1.5, 1.16, -0.85, 1.2, 1.95, 0.98, 2.3, -0.98, 2.3, -1.2, 1.95, -1.16, -0.85]
	var tt := [-0.4, -1.22, 0.4, -1.22, 0.98, -0.68, 1.02, 1.9, 0.84, 2.16, -0.84, 2.16, -1.02, 1.9, -0.98, -0.68]
	k._add(t, VehicleModels.loft("nato_rk_tur", tb, tt, 0.06, 0.8), cam, null, Vector3.ZERO)
	# the gun: mantlet, barrel with its thermal sleeve and fume extractor, the
	# muzzle reference sensor
	var gy := 0.42
	k._box(t, Vector3(0.62, 0.5, 0.42), Vector3(0, gy, -1.55), cam)
	k._cyl(t, 0.13, 0.13, 0.7, Vector3(0, gy, -2.05), Vector3(PI / 2, 0, 0), "paint", GUN, 14)
	k._cyl(t, 0.1, 0.115, 4.4, Vector3(0, gy, -4.3), Vector3(PI / 2, 0, 0), "paint", GUN, 14)
	k._cyl(t, 0.165, 0.165, 0.7, Vector3(0, gy, -3.25), Vector3(PI / 2, 0, 0), "paint", GUN, 14)
	for z in [-2.7, -4.3, -5.4]:
		k._cyl(t, 0.122, 0.122, 0.06, Vector3(0, gy, z), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12, false)
	k._cyl(t, 0.12, 0.12, 0.16, Vector3(0, gy, -6.42), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	k._box(t, Vector3(0.08, 0.06, 0.12), Vector3(0, gy + 0.15, -6.4), "gunmetal_w", null, Vector3.ZERO, false)
	k.gun_tip = k._tip(t, Vector3(0, gy, -6.52))
	k._cyl(t, 0.025, 0.025, 0.3, Vector3(0.42, gy - 0.08, -1.7), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	k.mg_tip = k._tip(t, Vector3(0.42, gy - 0.08, -1.86))
	# sights: the gunner's ahead on the left, the commander's cupola and his
	# panoramic sight on the right; the loader's hatch
	k._box(t, Vector3(0.36, 0.3, 0.42), Vector3(-0.62, 0.95, -0.5), cam)
	k._box(t, Vector3(0.26, 0.18, 0.02), Vector3(-0.62, 0.98, -0.72), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.34, 0.36, 0.2, Vector3(0.52, 0.9, 0.6), Vector3.ZERO, cam, null, 14)
	k._cyl(t, 0.3, 0.3, 0.06, Vector3(0.52, 1.03, 0.6), Vector3.ZERO, cam, null, 14)
	for i in 5:
		var a := -0.9 + i * 0.45
		k._box(t, Vector3(0.1, 0.08, 0.05), Vector3(0.52 + sin(a) * 0.35, 0.9, 0.6 - cos(a) * 0.35), "glass", null, Vector3(0, -a, 0), false)
	k._cyl(t, 0.07, 0.08, 0.3, Vector3(0.62, 0.95, -0.4), Vector3.ZERO, "gunmetal_w", null, 8)
	k._box(t, Vector3(0.32, 0.28, 0.32), Vector3(0.62, 1.2, -0.4), cam)
	k._box(t, Vector3(0.22, 0.14, 0.02), Vector3(0.62, 1.22, -0.57), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.28, 0.28, 0.06, Vector3(-0.5, 0.83, 0.75), Vector3.ZERO, cam, null, 14)
	for s in [-1.0, 1.0]:
		_smoke(k, t, Vector3(s * 1.06, 0.6, -0.72), s, 4, s * -0.5)
		# bins on the bustle sides
		k._box(t, Vector3(0.24, 0.42, 1.0), Vector3(s * 1.18, 0.42, 1.35), cam, null, Vector3(0, 0, s * 0.1))
	k._box(t, Vector3(2.0, 0.05, 0.42), Vector3(0, 0.3, 2.48), "gunmetal_w")
	k._box(t, Vector3(2.0, 0.34, 0.04), Vector3(0, 0.48, 2.68), "gunmetal_w")
	k._box(t, Vector3(0.8, 0.36, 0.38), Vector3(0.45, 0.52, 2.48), "canvas", BAG, Vector3(0, -0.1, 0))
	k._cyl(t, 0.018, 0.018, 0.45, Vector3(0.1, 1.0, 1.9), Vector3.ZERO, "gunmetal_w", null, 6, false)
	k._box(t, Vector3(0.14, 0.05, 0.05), Vector3(0.1, 1.24, 1.9), "gunmetal_w", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.14, 0.1, 0.14), Vector3(s * 0.85, 0.85, -0.55), "gunmetal_w")
		k._box(t, Vector3(0.1, 0.06, 0.02), Vector3(s * 0.85, 0.86, -0.63), "glass", null, Vector3.ZERO, false)
	_jerry(k, t, Vector3(-0.45, 0.55, 2.48), Color(0.3, 0.33, 0.22), Vector3(0, PI / 2, 0))
	_jerry(k, t, Vector3(-0.85, 0.55, 2.48), Color(0.3, 0.33, 0.22), Vector3(0, PI / 2, 0))
	if not up:
		_antenna(k, t, Vector3(-0.8, 0.8, 2.2), 1.6)
		return
	# --- urban package: ERA bricks on the turret front and cheeks and along
	# the glacis, slat cages round the hull sides and back, a remote .50
	for s in [-1.0, 1.0]:
		# the turret's front cheeks and the forward half of its sides
		_era(k, t, Vector3(s * 0.48, 0.06, -1.5), Vector3(s * 1.16, 0.06, -0.85), Vector3(s * 0.4, 0.8, -1.22), Vector3(s * 0.98, 0.8, -0.68), 3, 2, Vector3(s, 0.2, -1.0), cam, 0.12)
		_era(k, t, Vector3(s * 1.16, 0.06, -0.85), Vector3(s * 1.2, 0.06, 1.95), Vector3(s * 0.98, 0.8, -0.68), Vector3(s * 1.02, 0.8, 1.9), 3, 2, Vector3(s, 0.0, 0.0), cam, 0.12, 0.02, 0.56)
		# both plates of the arrowhead glacis
		_era(k, m, Vector3(s * 0.15, 1.45, -3.42), Vector3(s * 1.42, 1.45, -2.62), Vector3(s * 0.36, 1.96, -2.3), Vector3(s * 1.12, 1.96, -1.82), 4, 2, Vector3(s * 0.4, 0.6, -0.8), cam)
	# slat cages: a frame standing off each side and across the back
	for s in [-1.0, 1.0]:
		var sx: float = s * 1.62
		for z in [-2.0, -0.4, 1.2, 2.8]:
			k._box(m, Vector3(0.05, 0.85, 0.05), Vector3(sx, 1.68, z), "gunmetal_w")
			k._box(m, Vector3(0.24, 0.04, 0.04), Vector3(s * 1.5, 1.6, z), "gunmetal_w", null, Vector3.ZERO, false)
		for i in 5:
			k._box(m, Vector3(0.025, 0.05, 4.84), Vector3(sx, 1.3 + i * 0.19, 0.4), cam, null, Vector3.ZERO, false)
	for i in 5:
		k._box(m, Vector3(3.24, 0.05, 0.025), Vector3(0, 1.3 + i * 0.19, 3.85), cam, null, Vector3.ZERO, false)
	for x in [-1.6, -0.55, 0.55, 1.6]:
		k._box(m, Vector3(0.05, 0.85, 0.05), Vector3(x, 1.68, 3.85), "gunmetal_w")
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.05, 0.6), Vector3(s * 1.6, 1.9, 3.55), "gunmetal_w", null, Vector3.ZERO, false)
	# the remote weapon station on the turret roof (it turns with the gun)
	_rcws(k, t, Vector3(-0.35, 0.8, 1.35), "hmg", cam, 0.9)
	k.turret = t


# --- tracked: the Merkava IV family ----------------------------------------------------

## A track belt seen side-on, as a loop of link plates round the drive
## sprocket (front: z, y, r), the road wheels' bottoms (z0..z1 at ground) and
## the idler (rear: z, y, r), back along the top run. x is the belt's centre,
## w its width.
static func _track_loop(k: VehicleModels, m: Node3D, x: float, w: float, front: Vector3, rear: Vector3, z0: float, z1: float, th := 0.08) -> void:
	var pts: Array[Vector2] = []
	for i in 5:
		var a := deg_to_rad(90.0 + i * 30.0)
		pts.append(Vector2(front.x + cos(a) * front.z, front.y + sin(a) * front.z))
	pts.append(Vector2(z0, th))
	pts.append(Vector2(z1, th))
	for i in 5:
		var a := deg_to_rad(-60.0 + i * 37.5)
		pts.append(Vector2(rear.x + cos(a) * rear.z, rear.y + sin(a) * rear.z))
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		if a.distance_to(b) < 0.02:
			continue
		# overlap the plates a little so the belt reads as one
		var d := (b - a).normalized() * 0.03
		_zy(k, m, x, w, a - d, b + d, th, -th * 0.5, "track")
	# the guide horns down the middle of the top run
	k._box(m, Vector3(0.08, 0.06, absf(rear.x - front.x) - 0.4), Vector3(x, maxf(front.y + front.z, rear.y + rear.z) + 0.02, (front.x + rear.x) * 0.5), "gunmetal_w", null, Vector3.ZERO, false)


## A tracked vehicle's road wheel: rubber tyre, the dished disc standing
## proud of it, the hub with its bolt ring. Lighter than k._wheel (a tank has
## sixteen of these) but registered the same way, so it spins.
static func _road_wheel(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float) -> Node3D:
	var pv := k._pivot(p, pos)
	var ax := Vector3(0, 0, PI / 2)
	k._cyl(pv, r, r, w * 0.9, Vector3.ZERO, ax, "rubber", null, 18)
	k._cyl(pv, r * 0.8, r * 0.8, w, Vector3.ZERO, ax, "gunmetal_w", null, 16, false)
	k._cyl(pv, r * 0.42, r * 0.46, w + 0.05, Vector3.ZERO, ax, "metal_dark", null, 12, false)
	k._cyl(pv, r * 0.16, r * 0.16, w + 0.1, Vector3.ZERO, ax, "gunmetal_w", null, 8, false)
	k.wheels.append(pv)
	return pv


## The Merkava IV's running gear either side: the track belt, six road wheels,
## the drive sprocket forward (front engine), the idler aft.
static func _mk_running(k: VehicleModels, m: Node3D) -> void:
	var tx := 1.42
	for s in [-1.0, 1.0]:
		_track_loop(k, m, s * tx, 0.64, Vector3(-3.28, 0.86, 0.36), Vector3(3.3, 0.66, 0.34), -2.55, 2.55)
		for i in 6:
			_road_wheel(k, m, Vector3(s * tx, 0.45, -2.45 + i * 0.98), 0.38, 0.56)
		var sp := _road_wheel(k, m, Vector3(s * tx, 0.86, -3.28), 0.31, 0.5)
		_road_wheel(k, m, Vector3(s * tx, 0.66, 3.3), 0.3, 0.5)
		# the sprocket's teeth ring
		k._cyl(sp, 0.36, 0.36, 0.14, Vector3.ZERO, Vector3(0, 0, PI / 2), "gunmetal_w", null, 14)


## The Merkava IV hull: the long shallow glacis over the front engine with its
## sharp nose, the flat hull roof aft, the sponsons over the tracks with the
## big side skirts, the rear door into the troop compartment. era: reactive
## armour on the glacis and skirts. Returns nothing; the roof is at y 1.9.
static func _mk_hull(k: VehicleModels, team: int, cam: String, era: bool) -> void:
	var m := k.root
	_mk_running(k, m)
	# lower hull between the tracks: the lower nose plate, the belly, the tail
	k._add(m, VehicleModels.loft("nato_mk_low", [-1.08, -3.2, 1.08, -3.2, 1.08, 3.5, -1.08, 3.5], [-1.1, -3.82, 1.1, -3.82, 1.1, 3.78, -1.1, 3.78], 0.45, 1.21), cam, null, Vector3.ZERO)
	# the upper hull: the sponsons over the tracks, the glacis rising from the
	# nose to the front of the roof, the roof flat back to the rear
	var u0 := [-1.5, -3.82, 1.5, -3.82, 1.78, -3.42, 1.78, 3.78, -1.78, 3.78, -1.78, -3.42]
	var u1 := [-1.24, -0.92, 1.24, -0.92, 1.72, -0.52, 1.72, 3.72, -1.72, 3.72, -1.72, -0.52]
	k._add(m, VehicleModels.loft("nato_mk_up", u0, u1, 1.2, 1.9), cam, null, Vector3.ZERO)
	# the nose: a heavy cast beak with tow eyes and the headlight clusters
	k._box(m, Vector3(2.9, 0.12, 0.16), Vector3(0, 1.18, -3.84), cam)
	for s in [-1.0, 1.0]:
		_shackle(k, m, Vector3(s * 0.75, 0.98, -3.62))
		_lamp(k, m, Vector3(s * 1.25, 1.42, -3.08), 0.07)
		k._box(m, Vector3(0.36, 0.06, 0.24), Vector3(s * 1.25, 1.5, -3.06), "gunmetal_w", null, Vector3(-0.24, 0, 0))
	# glacis: engine access panels and the big intake grilles, the driver's
	# hatch and periscopes at the top on the left
	var ga := Vector2(-3.82, 1.2)
	var gb := Vector2(-0.92, 1.9)
	_zy(k, m, 0.55, 1.3, ga.lerp(gb, 0.3), ga.lerp(gb, 0.8), 0.04, 0.02, "gunmetal_w")
	for i in 7:
		var f := 0.32 + i * 0.065
		_zy(k, m, 0.55, 1.2, ga.lerp(gb, f), ga.lerp(gb, f + 0.02), 0.03, 0.05, cam, null, false)
	_zy(k, m, -0.6, 0.9, ga.lerp(gb, 0.25), ga.lerp(gb, 0.6), 0.04, 0.02, cam)
	for f in [0.25, 0.6]:
		_zy(k, m, -0.6, 0.94, ga.lerp(gb, f - 0.005), ga.lerp(gb, f + 0.005), 0.02, 0.045, "gunmetal_w", null, false)
	k._cyl(m, 0.28, 0.28, 0.06, Vector3(-0.85, 1.92, -1.25), Vector3.ZERO, cam, null, 14)
	for i in 3:
		k._box(m, Vector3(0.15, 0.1, 0.07), Vector3(-1.05 + i * 0.2, 1.88, -1.58), "gunmetal_w", null, Vector3(-0.24, (i - 1) * 0.3, 0))
	# the exhaust louvres on the left of the glacis
	k._box(m, Vector3(0.05, 0.3, 1.0), Vector3(-1.79, 1.48, -2.1), "gunmetal_w")
	# skirts: bolted heavy panels hanging off the sponsons, the front one raked
	for s in [-1.0, 1.0]:
		var sx: float = s * 1.82
		for i in 5:
			var z := -2.25 + i * 1.12
			k._box(m, Vector3(0.08, 0.62, 1.08), Vector3(sx, 0.93, z), cam)
		k._box(m, Vector3(0.08, 0.55, 0.9), Vector3(sx, 0.98, -3.22), cam, null, Vector3(0.42, 0, 0))
		# the rail along the sponson edge and a tow cable on it
		k._box(m, Vector3(0.1, 0.06, 6.9), Vector3(s * 1.8, 1.24, -0.02), "gunmetal_w")
		_tube(k, m, Vector3(s * 1.79, 1.4, -2.9), Vector3(s * 1.76, 1.4, 1.6), 0.028, "gunmetal_w", null, 6)
		# tool boxes along the sponson (the hull roof aft stays clear: the
		# bustle and its chains sweep over it)
		k._box(m, Vector3(0.12, 0.3, 1.1), Vector3(s * 1.82, 1.52, 1.0), cam)
		k._box(m, Vector3(0.12, 0.3, 0.7), Vector3(s * 1.82, 1.52, 2.3), cam)
		k._box(m, Vector3(0.04, 0.04, 0.16), Vector3(s * 1.89, 1.55, 1.0), "gunmetal_w", null, Vector3.ZERO, false)
		_taillight(k, m, Vector3(s * 1.45, 1.58, 3.8))
		_shackle(k, m, Vector3(s * 0.85, 0.85, 3.6), 1.0)
		if era:
			# reactive armour bricks over the skirts and up the glacis
			for i in 6:
				for j in 2:
					k._box(m, Vector3(0.12, 0.3, 0.86), Vector3(s * 1.9, 0.72 + j * 0.33, -2.4 + i * 0.93), cam)
	if era:
		for i in 4:
			for j in 5:
				var f := 0.06 + j * 0.115
				var x := (i - 1.5) * 0.72
				if absf(x + 0.6) < 0.4 and f > 0.7:
					continue
				_zy(k, m, x, 0.66, ga.lerp(gb, f), ga.lerp(gb, f + 0.1), 0.12, 0.08, cam)
	# the rear: the troop door with its vision block, steps, stowage baskets
	k._box(m, Vector3(1.0, 1.1, 0.08), Vector3(0.2, 1.3, 3.8), cam)
	k._box(m, Vector3(0.04, 0.2, 0.06), Vector3(0.55, 1.35, 3.86), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.24, 0.14, 0.04), Vector3(0.2, 1.62, 3.85), "glass", null, Vector3.ZERO, false)
	for y in [0.88, 1.7]:
		k._box(m, Vector3(0.08, 0.16, 0.08), Vector3(-0.32, y, 3.86), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.9, 0.06, 0.3), Vector3(0.2, 0.68, 3.9), "gunmetal_w")
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.62, 0.6, 0.36), Vector3(s * 1.2, 1.5, 3.98), "gunmetal_w")
		k._box(m, Vector3(0.5, 0.42, 0.3), Vector3(s * 1.2, 1.56, 3.98), "canvas", BAG)
		_jerry(k, m, Vector3(s * 1.62, 1.55, 3.92), Color(0.3, 0.33, 0.22), Vector3(0, PI / 2, 0))
	var mx := 1.975 if era else 1.865
	_team_mark(k, m, team, Vector3(mx, 0.95, 1.2), Vector3(0.02, 0.24, 0.8))
	_team_mark(k, m, team, Vector3(-mx, 0.95, 1.2), Vector3(0.02, 0.24, 0.8))


## The Merkava IV turret: a long, sharply wedged nose round a small mantlet,
## the roof sloping down to it, the long bustle overhanging the hull with the
## ball-and-chain curtain hanging under it, sights, cupola, smoke dischargers,
## 120 mm with its thermal sleeve and fume extractor. up: reactive armour on
## the turret sides and a remote .50 on the roof.
static func _mk_turret(k: VehicleModels, team: int, cam: String, up: bool) -> void:
	var m := k.root
	var t := k._pivot(m, Vector3(0, 1.9, 0.75))
	k.turret = t
	# the turret's body: the wedge in front, the main body over the ring
	var b0 := [-0.32, -2.55, 0.32, -2.55, 1.48, -0.72, 1.6, 1.2, -1.6, 1.2, -1.48, -0.72]
	var b1 := [-0.26, -1.75, 0.26, -1.75, 1.3, -0.42, 1.42, 1.2, -1.42, 1.2, -1.3, -0.42]
	k._add(t, VehicleModels.loft("nato_mk_tur", b0, b1, 0.0, 0.8), cam, null, Vector3.ZERO)
	# the bustle, raised clear of the hull roof (the chains hang across the gap)
	var c0 := [-1.6, 1.15, 1.6, 1.15, 1.56, 2.55, 1.3, 2.85, -1.3, 2.85, -1.56, 2.55]
	var c1 := [-1.42, 1.15, 1.42, 1.15, 1.4, 2.5, 1.16, 2.76, -1.16, 2.76, -1.4, 2.5]
	k._add(t, VehicleModels.loft("nato_mk_bustle", c0, c1, 0.3, 0.8), cam, null, Vector3.ZERO)
	k._cyl(t, 1.2, 1.25, 0.12, Vector3(0, 0.06, 0.4), Vector3.ZERO, "gunmetal_w", null, 20)
	# ball-and-chain curtain along the bustle's rear and sides
	for i in 11:
		var x := -1.15 + i * 0.23
		_chain(k, t, Vector3(x, 0.3, 2.78 - absf(x) * 0.12))
	for s in [-1.0, 1.0]:
		for i in 3:
			_chain(k, t, Vector3(s * 1.5, 0.3, 1.5 + i * 0.4))
	# the gun: a small mantlet low in the wedge, the barrel's thermal sleeve
	# in sections, the fume extractor, the muzzle reference sensor
	var gy := 0.32
	k._box(t, Vector3(0.48, 0.4, 0.5), Vector3(0, gy, -2.4), cam)
	k._cyl(t, 0.16, 0.16, 0.5, Vector3(0, gy, -2.8), Vector3(PI / 2, 0, 0), "paint", GUN, 14)
	k._cyl(t, 0.105, 0.12, 3.1, Vector3(0, gy, -4.35), Vector3(PI / 2, 0, 0), "paint", GUN, 14)
	k._cyl(t, 0.17, 0.17, 0.75, Vector3(0, gy, -3.85), Vector3(PI / 2, 0, 0), "paint", GUN, 14)
	for z in [-3.2, -4.6, -5.4]:
		k._cyl(t, 0.125, 0.125, 0.05, Vector3(0, gy, z), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12, false)
	k._cyl(t, 0.115, 0.115, 0.14, Vector3(0, gy, -5.92), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	k._box(t, Vector3(0.07, 0.06, 0.1), Vector3(0, gy + 0.14, -5.88), "gunmetal_w", null, Vector3.ZERO, false)
	k.gun_tip = k._tip(t, Vector3(0, gy, -6.0))
	k._cyl(t, 0.025, 0.025, 0.3, Vector3(0.36, gy + 0.06, -2.55), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	k.mg_tip = k._tip(t, Vector3(0.36, gy + 0.06, -2.72))
	# the gunner's sight box forward left, the commander's big panoramic sight
	# forward right, the cupola behind it, the loader's hatch, the 60 mm mortar
	k._box(t, Vector3(0.36, 0.3, 0.5), Vector3(-0.68, 0.92, -0.55), cam)
	k._box(t, Vector3(0.28, 0.18, 0.02), Vector3(-0.68, 0.95, -0.81), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.08, 0.1, 0.28, Vector3(0.62, 0.92, -0.25), Vector3.ZERO, "gunmetal_w", null, 8)
	k._box(t, Vector3(0.38, 0.32, 0.38), Vector3(0.62, 1.18, -0.25), cam)
	k._box(t, Vector3(0.26, 0.16, 0.02), Vector3(0.62, 1.2, -0.45), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.36, 0.38, 0.16, Vector3(0.62, 0.88, 0.62), Vector3.ZERO, cam, null, 14)
	k._cyl(t, 0.32, 0.32, 0.06, Vector3(0.62, 0.99, 0.62), Vector3.ZERO, cam, null, 14)
	for i in 5:
		var a := -0.9 + i * 0.45
		k._box(t, Vector3(0.1, 0.07, 0.05), Vector3(0.62 + sin(a) * 0.37, 0.88, 0.62 - cos(a) * 0.37), "glass", null, Vector3(0, -a, 0), false)
	k._cyl(t, 0.3, 0.3, 0.06, Vector3(-0.6, 0.83, 0.75), Vector3.ZERO, cam, null, 14)
	k._box(t, Vector3(0.1, 0.06, 0.24), Vector3(-0.35, 0.86, 0.75), "gunmetal_w")
	k._cyl(t, 0.055, 0.055, 0.7, Vector3(-0.85, 1.0, 1.35), Vector3(PI / 2 - 0.5, 0, 0), "gunmetal_w", null, 8)
	k._box(t, Vector3(0.16, 0.16, 0.2), Vector3(-0.85, 0.86, 1.62), "gunmetal_w")
	# the loader's MG on its pintle, the wind sensor mast, antennas
	k._box(t, Vector3(0.08, 0.12, 0.62), Vector3(-0.6, 1.02, 0.35), "gunmetal_w")
	k._cyl(t, 0.018, 0.018, 0.5, Vector3(-0.6, 1.03, -0.2), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	k._cyl(t, 0.02, 0.02, 0.5, Vector3(0.0, 1.05, 2.2), Vector3.ZERO, "gunmetal_w", null, 6, false)
	k._box(t, Vector3(0.12, 0.05, 0.05), Vector3(0.0, 1.3, 2.2), "gunmetal_w", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		_antenna(k, t, Vector3(s * 1.05, 0.8, 2.4), 1.5)
		# smoke dischargers on the wedge's flanks, side armour modules with
		# their channels, stowage baskets along the bustle
		_smoke(k, t, Vector3(s * 1.2, 0.62, -0.95), s, 5, s * -0.6)
		_xy(k, t, s, 0.3, 1.5, Vector2(1.6, 0.04), Vector2(1.42, 0.78), 0.08, 0.04, cam)
		_xy(k, t, s, 0.3, 1.52, Vector2(1.52, 0.38), Vector2(1.51, 0.44), 0.06, 0.09, "gunmetal_w", null, false)
		k._box(t, Vector3(0.3, 0.42, 1.3), Vector3(s * 1.66, 0.6, 2.05), "gunmetal_w")
		k._box(t, Vector3(0.24, 0.34, 1.2), Vector3(s * 1.64, 0.62, 2.05), "canvas", BAG if s < 0 else STOW)
	if up:
		# reactive armour bricks over the wedge's faces and the turret sides
		for s in [-1.0, 1.0]:
			_era(k, t, Vector3(s * 0.32, 0.0, -2.55), Vector3(s * 1.48, 0.0, -0.72), Vector3(s * 0.26, 0.8, -1.75), Vector3(s * 1.3, 0.8, -0.42), 4, 2, Vector3(s, 0.3, -0.5), cam, 0.12, 0.0, 0.78)
			for i in 3:
				for j in 2:
					k._box(t, Vector3(0.12, 0.3, 0.46), Vector3(s * 1.72, 0.25 + j * 0.34, -0.25 + i * 0.5), cam)
		var gt := t
		_rcws(k, t, Vector3(-0.15, 0.8, 1.55), "hmg", cam, 0.9)
		k.turret = gt


## A hanging chain with a ball on its end (the Merkava's curtain).
static func _chain(k: VehicleModels, p: Node3D, top: Vector3) -> void:
	k._cyl(p, 0.012, 0.012, 0.2, top + Vector3(0, -0.1, 0), Vector3.ZERO, "gunmetal_w", null, 4, false)
	k._add(p, Res.sphere(0.045, 6), "gunmetal_w", null, top + Vector3(0, -0.22, 0), Vector3.ZERO, Vector3.ONE, false)


## M2A1 Slammer: the Merkava IV. up: the urban package (ERA, remote .50).
static func _slammer(k: VehicleModels, team: int, up: bool) -> void:
	var cam := _cam(team)
	_mk_hull(k, team, cam, up)
	_mk_turret(k, team, cam, up)


## M4 Scorcher: the Merkava IV hull under a tall boxy M109A7-style turret set
## aft, the long 155 mm on k.elev (pivot at the trunnion, raises to fire), a
## travel lock on the glacis, the commander's remote .50 on the roof.
static func _scorcher(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	var m := k.root
	_mk_hull(k, team, cam, false)
	# the barrel's travel lock folded down on the glacis
	k._box(m, Vector3(0.12, 0.1, 0.9), Vector3(0, 1.48, -2.6), "gunmetal_w", null, Vector3(-0.24, 0, 0))
	var t := k._pivot(m, Vector3(0, 1.9, 1.0))
	k.turret = t
	k._cyl(t, 1.2, 1.25, 0.12, Vector3(0, 0.06, 0), Vector3.ZERO, "gunmetal_w", null, 20)
	# the tall box: sloped front faces, vertical sides, the bustle
	var b0 := [-1.0, -1.85, 1.0, -1.85, 1.58, -1.3, 1.58, 2.55, -1.58, 2.55, -1.58, -1.3]
	var b1 := [-0.9, -1.55, 0.9, -1.55, 1.5, -1.05, 1.5, 2.45, -1.5, 2.45, -1.5, -1.05]
	k._add(t, VehicleModels.solid([VehicleModels.ring_y(VehicleModels._v2(b0), 0.08), VehicleModels.ring_y(VehicleModels._v2(b0), 0.7), VehicleModels.ring_y(VehicleModels._v2(b1), 1.28)], "nato_scorch_tur"), cam, null, Vector3.ZERO)
	# side doors, roof hatches, the commander's cupola with a remote .50
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.04, 0.8, 0.7), Vector3(s * 1.6, 0.62, 0.9), cam)
		k._box(t, Vector3(0.05, 0.05, 0.14), Vector3(s * 1.63, 0.62, 0.65), "gunmetal_w", null, Vector3.ZERO, false)
		_smoke(k, t, Vector3(s * 1.45, 0.88, -1.3), s, 4, s * -0.4)
		k._box(t, Vector3(0.3, 0.4, 1.2), Vector3(s * 1.74, 0.5, -0.15), "gunmetal_w")
		k._box(t, Vector3(0.24, 0.32, 1.1), Vector3(s * 1.72, 0.52, -0.15), "canvas", BAG)
		_antenna(k, t, Vector3(s * 1.2, 1.28, 2.2), 1.4)
	k._box(t, Vector3(0.7, 0.06, 0.6), Vector3(-0.6, 1.31, 0.9), cam)
	k._box(t, Vector3(2.8, 0.05, 0.5), Vector3(0, 0.5, 2.75), "gunmetal_w")
	k._box(t, Vector3(2.8, 0.42, 0.04), Vector3(0, 0.72, 2.98), "gunmetal_w")
	for i in 3:
		k._box(t, Vector3(0.7, 0.36, 0.4), Vector3(-0.9 + i * 0.9, 0.72, 2.75), "canvas", BAG if i != 1 else STOW)
	_team_mark(k, t, team, Vector3(1.59, 0.42, 1.75), Vector3(0.02, 0.24, 0.6))
	_team_mark(k, t, team, Vector3(-1.59, 0.42, 1.75), Vector3(0.02, 0.24, 0.6))
	# the gun: trunnions at the turret front, the cradle, recoil cylinders, the
	# long tube with its fume extractor and the double-baffle muzzle brake
	var e := k._pivot(t, Vector3(0, 0.72, -1.4))
	k.elev = e
	k._box(e, Vector3(0.8, 0.62, 0.5), Vector3(0, 0, -0.22), cam)
	k._cyl(e, 0.22, 0.22, 0.8, Vector3(0, 0, -0.8), Vector3(PI / 2, 0, 0), "paint", GUN, 14)
	for s in [-1.0, 1.0]:
		k._cyl(e, 0.07, 0.07, 1.0, Vector3(s * 0.22, -0.12, -0.75), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._cyl(e, 0.11, 0.13, 5.3, Vector3(0, 0, -3.65), Vector3(PI / 2, 0, 0), "paint", GUN, 14)
	k._cyl(e, 0.19, 0.19, 0.9, Vector3(0, 0, -3.9), Vector3(PI / 2, 0, 0), "paint", GUN, 14)
	k._cyl(e, 0.18, 0.18, 0.2, Vector3(0, 0, -6.35), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	k._cyl(e, 0.18, 0.18, 0.2, Vector3(0, 0, -6.68), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	k._cyl(e, 0.12, 0.12, 0.34, Vector3(0, 0, -6.5), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	k.gun_tip = k._tip(e, Vector3(0, 0, -6.8))
	var gt := t
	_rcws(k, t, Vector3(0.62, 1.28, 0.6), "hmg", cam, 0.85)
	k.turret = gt


## M5 Sandstorm: the Merkava IV hull with an M270-style launcher at the back:
## a traversing mount (k.turret) and the armoured box of two six-round pods
## on k.elev, pivoting at its rear so the front rises to fire.
static func _sandstorm(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	var m := k.root
	_mk_hull(k, team, cam, false)
	# the crew's cupola and periscopes forward, where a turret would be
	k._cyl(m, 0.4, 0.42, 0.14, Vector3(0.7, 1.97, -0.5), Vector3.ZERO, cam, null, 14)
	k._cyl(m, 0.34, 0.34, 0.06, Vector3(0.7, 2.06, -0.5), Vector3.ZERO, cam, null, 14)
	k._cyl(m, 0.3, 0.3, 0.06, Vector3(-0.55, 1.93, -0.3), Vector3.ZERO, cam, null, 14)
	k._box(m, Vector3(0.36, 0.3, 0.36), Vector3(0.2, 2.05, -0.6), cam)
	k._box(m, Vector3(0.24, 0.14, 0.02), Vector3(0.2, 2.08, -0.79), "glass", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		_antenna(k, m, Vector3(s * 1.35, 1.9, -0.75), 1.5)
	# the launcher's travel rest on the roof, where the box's front end sits
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.12, 0.3, 0.14), Vector3(s * 0.7, 2.05, -0.1), "gunmetal_w")
	k._box(m, Vector3(1.6, 0.08, 0.2), Vector3(0, 2.2, -0.1), "gunmetal_w")
	# the turntable and the launcher's base with its elevation rams
	var t := k._pivot(m, Vector3(0, 1.9, 2.2))
	k.turret = t
	k._cyl(t, 1.15, 1.2, 0.14, Vector3(0, 0.07, 0), Vector3.ZERO, "gunmetal_w", null, 20)
	k._box(t, Vector3(2.0, 0.2, 1.6), Vector3(0, 0.22, 0.6), cam)
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.16, 0.3, 0.5), Vector3(s * 1.0, 0.38, 1.25), cam)
		k._cyl(t, 0.06, 0.06, 0.9, Vector3(s * 0.7, 0.32, 0.2), Vector3(PI / 2 - 0.05, 0, 0), "steel", null, 8)
	# the launcher box: hinged at its rear end, the pods' tubes facing forward
	var e := k._pivot(t, Vector3(0, 0.34, 1.3))
	k.elev = e
	var L := 3.8
	var H := 0.86
	k._box(e, Vector3(2.2, H, L), Vector3(0, H * 0.5, -L * 0.5), cam)
	k._box(e, Vector3(2.0, 0.3, 0.36), Vector3(0, 0.35, 0.18), "gunmetal_w")
	for s in [-1.0, 1.0]:
		# each pod's face: six tube mouths behind the frangible covers
		k._box(e, Vector3(1.0, H - 0.1, 0.04), Vector3(s * 0.54, H * 0.5, -L - 0.01), "gunmetal_w")
		for i in 3:
			for j in 2:
				k._cyl(e, 0.12, 0.12, 0.04, Vector3(s * 0.54 + (i - 1) * 0.31, 0.24 + j * 0.38, -L - 0.03), Vector3(PI / 2, 0, 0), "metal_dark", null, 10, false)
		# ribs down the sides, the boom-hoists along the top edges
		for i in 4:
			k._box(e, Vector3(0.04, H - 0.06, 0.08), Vector3(s * 1.11, H * 0.5, -0.45 - i * 0.98), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(e, Vector3(0.12, 0.12, L - 0.3), Vector3(s * 0.95, H + 0.06, -L * 0.5), cam)
		k._cyl(e, 0.07, 0.07, 0.14, Vector3(s * 0.95, H + 0.1, -L + 0.1), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10)
		k._box(e, Vector3(0.04, 0.2, 0.04), Vector3(s * 0.95, H - 0.04, -L + 0.06), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(e, Vector3(0.04, 0.03, L - 0.2), Vector3(0, H + 0.01, -L * 0.5), "gunmetal_w", null, Vector3.ZERO, false)
	k.gun_tip = k._tip(e, Vector3(0, H * 0.5, -L - 0.1))
	_team_mark(k, e, team, Vector3(1.105, 0.5, -2.0), Vector3(0.02, 0.26, 0.9))
	_team_mark(k, e, team, Vector3(-1.105, 0.5, -2.0), Vector3(0.02, 0.26, 0.9))


# --- tracked: the Namer family ---------------------------------------------------------

## The Namer hull: the Merkava IV's running gear, glacis and skirts, but the
## hull built up into a tall flat-sided box over the troop compartment, with
## the big hydraulic ramp at the back. Its roof is at y 2.32. cupola: the
## commander's cupola and the roof hatches; stow: the stowage rack at the back
## of the roof (leave them off where a turret or a crane sits).
static func _namer_hull(k: VehicleModels, team: int, cam: String, cupola := true, stow := true) -> void:
	var m := k.root
	_mk_running(k, m)
	var roof := 2.32
	k._add(m, VehicleModels.loft("nato_nm_low", [-1.08, -3.2, 1.08, -3.2, 1.08, 3.5, -1.08, 3.5], [-1.1, -3.82, 1.1, -3.82, 1.1, 3.78, -1.1, 3.78], 0.45, 1.21), cam, null, Vector3.ZERO)
	# the glacis over the engine, then the superstructure's sloped front face,
	# its sides straight up from the sponsons
	var u0 := [-1.5, -3.82, 1.5, -3.82, 1.78, -3.42, 1.78, 3.78, -1.78, 3.78, -1.78, -3.42]
	var u1 := [-1.32, -1.35, 1.32, -1.35, 1.76, -1.0, 1.76, 3.78, -1.76, 3.78, -1.76, -1.0]
	var u2 := [-1.12, -0.72, 1.12, -0.72, 1.66, -0.5, 1.66, 3.7, -1.66, 3.7, -1.66, -0.5]
	k._add(m, VehicleModels.solid([VehicleModels.ring_y(VehicleModels._v2(u0), 1.2), VehicleModels.ring_y(VehicleModels._v2(u1), 1.8), VehicleModels.ring_y(VehicleModels._v2(u2), roof)], "nato_nm_up"), cam, null, Vector3.ZERO)
	# the nose with tow eyes and lights in guards
	k._box(m, Vector3(2.9, 0.12, 0.16), Vector3(0, 1.18, -3.84), cam)
	for s in [-1.0, 1.0]:
		_shackle(k, m, Vector3(s * 0.75, 0.98, -3.62))
		_lamp(k, m, Vector3(s * 1.25, 1.42, -3.08), 0.07)
		k._box(m, Vector3(0.36, 0.06, 0.24), Vector3(s * 1.25, 1.5, -3.06), "gunmetal_w", null, Vector3(-0.24, 0, 0))
	# glacis: engine grilles, access panels
	var ga := Vector2(-3.82, 1.2)
	var gb := Vector2(-1.35, 1.8)
	_zy(k, m, 0.55, 1.3, ga.lerp(gb, 0.3), ga.lerp(gb, 0.85), 0.04, 0.02, "gunmetal_w")
	for i in 8:
		var f := 0.33 + i * 0.065
		_zy(k, m, 0.55, 1.2, ga.lerp(gb, f), ga.lerp(gb, f + 0.02), 0.03, 0.05, cam, null, false)
	_zy(k, m, -0.65, 0.9, ga.lerp(gb, 0.3), ga.lerp(gb, 0.7), 0.04, 0.02, cam)
	k._box(m, Vector3(0.05, 0.3, 1.0), Vector3(-1.79, 1.48, -2.1), "gunmetal_w")
	# the driver's hatch and periscopes on the superstructure front, left
	var fa := Vector2(-1.35, 1.8)
	var fb := Vector2(-0.72, roof)
	for i in 3:
		_zy(k, m, -0.95 + i * 0.22, 0.16, fa.lerp(fb, 0.55), fa.lerp(fb, 0.8), 0.06, 0.03, "glass", null, false)
	k._cyl(m, 0.3, 0.3, 0.06, Vector3(-0.72, roof + 0.03, -0.3), Vector3.ZERO, cam, null, 14)
	# skirts and side armour: heavy panels low, the superstructure's armour
	# modules with a channel between them, stowage, tow cable
	for s in [-1.0, 1.0]:
		var sx: float = s * 1.82
		for i in 5:
			var z := -2.25 + i * 1.12
			k._box(m, Vector3(0.08, 0.62, 1.08), Vector3(sx, 0.93, z), cam)
		k._box(m, Vector3(0.08, 0.55, 0.9), Vector3(sx, 0.98, -3.22), cam, null, Vector3(0.42, 0, 0))
		k._box(m, Vector3(0.1, 0.06, 6.9), Vector3(s * 1.8, 1.24, -0.02), "gunmetal_w")
		for i in 4:
			var z := -0.15 + i * 0.95
			k._box(m, Vector3(0.12, 0.62, 0.9), Vector3(s * 1.74, 1.98, z), cam)
			k._box(m, Vector3(0.04, 0.05, 0.05), Vector3(s * 1.81, 2.2, z), "gunmetal_w", null, Vector3.ZERO, false)
		_tube(k, m, Vector3(s * 1.8, 1.4, -2.9), Vector3(s * 1.8, 1.4, -0.6), 0.028, "gunmetal_w", null, 6)
		_taillight(k, m, Vector3(s * 1.4, 1.6, 3.8))
		_shackle(k, m, Vector3(s * 0.85, 0.85, 3.6), 1.0)
		_antenna(k, m, Vector3(s * 1.45, roof, 3.4), 1.5)
		# smoke dischargers on the front roof corners
		_smoke(k, m, Vector3(s * 1.45, roof + 0.05, -0.45), s, 4, s * -0.5)
	# roof: the commander's cupola with periscopes, hatches over the troop
	# compartment, stowage at the back
	if cupola:
		k._cyl(m, 0.36, 0.38, 0.16, Vector3(0.62, roof + 0.08, 0.15), Vector3.ZERO, cam, null, 14)
		k._cyl(m, 0.32, 0.32, 0.06, Vector3(0.62, roof + 0.19, 0.15), Vector3.ZERO, cam, null, 14)
		for i in 5:
			var a := -1.0 + i * 0.5
			k._box(m, Vector3(0.1, 0.07, 0.05), Vector3(0.62 + sin(a) * 0.37, roof + 0.08, 0.15 - cos(a) * 0.37), "glass", null, Vector3(0, -a, 0), false)
		for s in [-1.0, 1.0]:
			k._box(m, Vector3(0.7, 0.06, 0.8), Vector3(s * 0.55, roof + 0.03, 1.55), cam)
			k._box(m, Vector3(0.06, 0.06, 0.2), Vector3(s * 0.3, roof + 0.08, 1.3), "gunmetal_w")
	if stow:
		k._box(m, Vector3(2.8, 0.05, 0.9), Vector3(0, roof + 0.02, 3.0), "gunmetal_w")
		k._box(m, Vector3(2.8, 0.3, 0.04), Vector3(0, roof + 0.17, 3.44), "gunmetal_w")
		for i in 3:
			k._box(m, Vector3(0.7, 0.32, 0.6), Vector3(-0.85 + i * 0.85, roof + 0.2, 3.0), "canvas", BAG if i != 1 else STOW, Vector3(0, (i - 1) * 0.08, 0))
	# the rear: the big ramp with its door, hinges, steps
	k._box(m, Vector3(2.0, 1.55, 0.1), Vector3(0, 1.35, 3.8), cam)
	k._box(m, Vector3(0.62, 1.1, 0.04), Vector3(0.45, 1.4, 3.86), cam)
	k._box(m, Vector3(0.04, 0.08, 0.16), Vector3(0.2, 1.4, 3.9), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.22, 0.14, 0.04), Vector3(0.45, 1.75, 3.89), "glass", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		k._cyl(m, 0.06, 0.06, 0.4, Vector3(s * 0.7, 0.62, 3.84), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
		_tube(k, m, Vector3(s * 0.95, 1.95, 3.6), Vector3(s * 0.95, 1.2, 3.84), 0.05, "steel")
		_jerry(k, m, Vector3(s * 1.4, 1.2, 3.92), Color(0.3, 0.33, 0.22), Vector3(0, PI / 2, 0))
	_team_mark(k, m, team, Vector3(1.805, 1.98, 1.75), Vector3(0.02, 0.24, 0.7))
	_team_mark(k, m, team, Vector3(-1.805, 1.98, 1.75), Vector3(0.02, 0.24, 0.7))


## IFV-6c Panther: the Namer with a remote station carrying a 12.7 mm and a
## 40 mm grenade machine gun.
static func _panther(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	_namer_hull(k, team, cam)
	_rcws(k, k.root, Vector3(-0.5, 2.32, -0.05), "both", cam, 1.15)


## CRV-6e Bobcat: the Namer as an engineering / recovery vehicle: a dozer
## blade on push arms across the nose, the recovery crane's boom folded along
## the roof, its winch, tools, and a remote .50.
static func _bobcat(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	var m := k.root
	_namer_hull(k, team, cam, true, false)
	# the dozer blade, raised for travel: a curved mouldboard of three facets,
	# its cutting edge, the push arms and the lifting rams
	var bz := -4.32
	var by := 0.28
	k._box(m, Vector3(3.9, 0.36, 0.1), Vector3(0, by + 0.18, bz), cam, null, Vector3(-0.35, 0, 0))
	k._box(m, Vector3(3.9, 0.4, 0.1), Vector3(0, by + 0.53, bz - 0.04), cam)
	k._box(m, Vector3(3.9, 0.36, 0.1), Vector3(0, by + 0.88, bz + 0.02), cam, null, Vector3(0.4, 0, 0))
	k._box(m, Vector3(3.92, 0.08, 0.14), Vector3(0, by + 0.02, bz + 0.06), "steel")
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.06, 0.9, 0.3), Vector3(s * 1.94, by + 0.48, bz + 0.12), cam)
		for x in [0.6, 1.5]:
			k._box(m, Vector3(0.06, 0.5, 0.36), Vector3(s * x, by + 0.55, bz + 0.2), "gunmetal_w")
		_beam(k, m, Vector3(s * 1.5, by + 0.35, bz + 0.25), Vector3(s * 1.55, 0.75, -2.7), 0.18, 0.16, cam)
		_tube(k, m, Vector3(s * 1.1, by + 0.85, bz + 0.25), Vector3(s * 1.1, 1.3, -3.2), 0.06, "gunmetal_w")
		_tube(k, m, Vector3(s * 1.1, by + 0.75, bz + 0.25), Vector3(s * 1.1, by + 0.95, bz + 0.6), 0.04, "steel")
	# the crane: its slewing base on the roof's back right, the boom folded
	# forward along the right side onto a rest, the hook stowed
	var cb := Vector3(1.0, 2.32, 2.75)
	k._cyl(m, 0.42, 0.46, 0.14, cb + Vector3(0, 0.07, 0), Vector3.ZERO, "gunmetal_w", null, 14)
	k._box(m, Vector3(0.6, 0.3, 0.7), cb + Vector3(0, 0.29, 0), cam)
	var bt := Vector3(1.0, 2.58, -0.9)
	_beam(k, m, cb + Vector3(0, 0.3, -0.1), bt, 0.28, 0.26, cam)
	_beam(k, m, cb + Vector3(0, 0.34, -1.2), bt + Vector3(0, 0.02, -0.5), 0.2, 0.18, "steel", Color(0.3, 0.32, 0.24))
	_tube(k, m, cb + Vector3(0.18, 0.18, -0.4), cb + Vector3(0.18, 0.3, -1.6), 0.06, "gunmetal_w")
	k._box(m, Vector3(0.14, 0.14, 0.14), Vector3(1.0, 2.38, -1.0), "gunmetal_w")
	k._cyl(m, 0.1, 0.1, 0.2, bt + Vector3(0, 0.0, -0.55), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10)
	k._box(m, Vector3(0.1, 0.2, 0.1), bt + Vector3(0, 0.0, -0.75), "steel")
	# the main winch drum at the back of the roof, tow bars and tools
	k._cyl(m, 0.2, 0.2, 0.9, Vector3(-0.5, 2.55, 2.75), Vector3(0, 0, PI / 2), "gunmetal_w", null, 12)
	k._cyl(m, 0.17, 0.17, 0.92, Vector3(-0.5, 2.55, 2.75), Vector3(0, 0, PI / 2), "steel", null, 12)
	for x in [-0.98, -0.02]:
		k._box(m, Vector3(0.06, 0.32, 0.36), Vector3(x, 2.48, 2.75), "gunmetal_w")
	k._box(m, Vector3(0.1, 0.1, 2.0), Vector3(-1.5, 2.4, 0.9), "gunmetal_w")
	k._box(m, Vector3(0.08, 0.08, 1.4), Vector3(-1.38, 2.4, 1.0), "wood")
	_rcws(k, m, Vector3(-0.5, 2.32, -0.05), "hmg", cam)


## IFV-6a Cheetah: the Namer under a Marksman-style twin 35 mm turret: a large
## box with a gun on each side, the search radar on its mast at the back, the
## tracking radar in front, two four-round missile boxes.
static func _cheetah(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	var m := k.root
	_namer_hull(k, team, cam, false, false)
	var t := k._pivot(m, Vector3(0, 2.32, 0.95))
	k.turret = t
	k._cyl(t, 1.15, 1.2, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, "gunmetal_w", null, 20)
	var b0 := [-0.95, -1.4, 0.95, -1.4, 1.22, -1.0, 1.22, 1.5, 1.0, 1.75, -1.0, 1.75, -1.22, 1.5, -1.22, -1.0]
	var b1 := [-0.82, -1.15, 0.82, -1.15, 1.1, -0.85, 1.1, 1.4, 0.9, 1.62, -0.9, 1.62, -1.1, 1.4, -1.1, -0.85]
	k._add(t, VehicleModels.loft("nato_ch_tur", b0, b1, 0.08, 0.92), cam, null, Vector3.ZERO)
	# a 35 mm on each flank: the trunnion housing, the cradle, the long barrel
	# with its muzzle velocity radar ring and brake
	var gy := 0.52
	for s in [-1.0, 1.0]:
		var gx: float = s * 1.42
		k._box(t, Vector3(0.24, 0.42, 0.9), Vector3(s * 1.3, gy, -0.4), cam)
		k._box(t, Vector3(0.24, 0.3, 1.1), Vector3(gx, gy, -0.75), "gunmetal_w")
		k._cyl(t, 0.07, 0.07, 0.6, Vector3(gx, gy, -1.55), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
		k._cyl(t, 0.04, 0.045, 2.2, Vector3(gx, gy, -2.95), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
		k._cyl(t, 0.075, 0.075, 0.16, Vector3(gx, gy, -3.1), Vector3(PI / 2, 0, 0), "metal_dark", null, 10)
		k._cyl(t, 0.06, 0.06, 0.2, Vector3(gx, gy, -4.1), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
		# the ammunition feed chute and the missile box above the gun
		k._box(t, Vector3(0.18, 0.2, 0.4), Vector3(gx, gy - 0.24, -0.4), "gunmetal_w")
		var mb := Vector3(s * 1.36, 1.02, 0.55)
		k._box(t, Vector3(0.5, 0.48, 1.4), mb, cam)
		for i in 2:
			for j in 2:
				k._cyl(t, 0.09, 0.09, 0.03, mb + Vector3((i - 0.5) * 0.22, (j - 0.5) * 0.22, -0.71), Vector3(PI / 2, 0, 0), "metal_dark", null, 10, false)
		k._box(t, Vector3(0.08, 0.3, 0.3), Vector3(s * 1.14, 0.88, 0.55), "gunmetal_w")
		_smoke(k, t, Vector3(s * 1.12, 0.78, -1.1), s, 4, s * -0.5)
	k.mg_tip = k._tip(t, Vector3(1.42, gy, -4.22))
	# the tracking radar (a dish in a drum) on the front of the roof, the
	# optics beside it
	k._cyl(t, 0.36, 0.36, 0.3, Vector3(0, 1.08, -0.65), Vector3(PI / 2, 0, 0), cam, null, 16)
	k._cyl(t, 0.3, 0.3, 0.04, Vector3(0, 1.08, -0.82), Vector3(PI / 2, 0, 0), "plain_dark", null, 16, false)
	k._box(t, Vector3(0.3, 0.26, 0.3), Vector3(-0.6, 1.05, -0.7), cam)
	k._box(t, Vector3(0.22, 0.14, 0.02), Vector3(-0.6, 1.07, -0.86), "glass", null, Vector3.ZERO, false)
	# hatches, the search radar on its folding mast at the back
	k._cyl(t, 0.28, 0.28, 0.06, Vector3(0.5, 0.95, 0.4), Vector3.ZERO, cam, null, 14)
	k._cyl(t, 0.28, 0.28, 0.06, Vector3(-0.5, 0.95, 0.4), Vector3.ZERO, cam, null, 14)
	k._box(t, Vector3(0.5, 0.3, 0.5), Vector3(0, 1.07, 1.3), cam)
	k._cyl(t, 0.08, 0.1, 0.26, Vector3(0, 1.33, 1.3), Vector3.ZERO, "gunmetal_w", null, 10)
	var rp := k._pivot(t, Vector3(0, 1.45, 1.3))
	k._add(rp, Res.sphere(1.0, 16), cam, null, Vector3(0, 0.22, 0), Vector3(-0.3, 0, 0), Vector3(0.7, 0.26, 0.07))
	k._add(rp, Res.sphere(1.0, 16), "gunmetal_w", null, Vector3(0, 0.21, 0.03), Vector3(-0.3, 0, 0), Vector3(0.66, 0.23, 0.06))
	k._box(rp, Vector3(0.22, 0.14, 0.26), Vector3(0, 0.02, 0.1), "gunmetal_w")
	k._box(rp, Vector3(0.06, 0.3, 0.06), Vector3(0, 0.12, 0.08), "gunmetal_w")
	_antenna(k, t, Vector3(-0.8, 0.92, 1.4), 1.2)
	_team_mark(k, t, team, Vector3(1.165, 0.45, 0.5), Vector3(0.02, 0.24, 0.8))
	_team_mark(k, t, team, Vector3(-1.165, 0.45, 0.5), Vector3(0.02, 0.24, 0.8))


# --- HEMTT: Oshkosh M977 family ----------------------------------------------------------

## A ring in the XY plane (a cross-section) at z.
static func _ring_z(pts: Array, z: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in range(0, pts.size(), 2):
		r.append(Vector3(pts[i], pts[i + 1], z))
	return r


## A cross-section (x, y pairs, convex) extruded along z from z0 to z1.
static func _extrude_z(key: String, sec: Array, z0: float, z1: float) -> ArrayMesh:
	return VehicleModels.solid([_ring_z(sec, z0), _ring_z(sec, z1)], key)


## The HEMTT's cab and chassis: the wide flat-fronted cab over the front
## axles with its short blunt nose and big grille, four axles (two steering
## pairs forward, the tandem aft) on huge tyres, the exhaust stack and air
## cleaner behind the cab, fuel tank and boxes along the frame rails. The
## bodies start at z -2.45 with their deck at y 1.36.
static func _hemtt_chassis(k: VehicleModels, team: int, paint: Color) -> void:
	var m := k.root
	var cab := "camo_tank" if team != 1 else "camo_tank_rebel"
	var wr := 0.63
	var axles := [-3.8, -2.3, 2.15, 3.65]
	for s in [-1.0, 1.0]:
		for z in axles:
			k._wheel(m, Vector3(s * 0.98, wr, z), wr, 0.46)
			k._box(m, Vector3(0.36, 0.14, 0.2), Vector3(s * 0.6, wr, z), "gunmetal_w")
	# frame rails, the axles' beams and springs
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.14, 0.3, 9.9), Vector3(s * 0.45, 1.0, 0.1), "gunmetal_w")
	for z in axles:
		k._box(m, Vector3(1.5, 0.16, 0.18), Vector3(0, wr, z), "metal_dark")
		k._box(m, Vector3(1.1, 0.1, 0.9), Vector3(0, 0.84, z), "gunmetal_w")
	# the cab: a slightly raked windscreen, flat sides, the nose out in front
	var cb := [-1.2, -4.5, 1.2, -4.5, 1.2, -2.85, -1.2, -2.85]
	k._add(m, VehicleModels.solid([VehicleModels.ring_y(VehicleModels._v2(cb), 1.36), VehicleModels.ring_y(VehicleModels._v2(cb), 1.95), VehicleModels.ring_y(VehicleModels._v2([-1.14, -4.34, 1.14, -4.34, 1.14, -2.88, -1.14, -2.88]), 2.86)], "nato_hemtt_cab"), cab, null, Vector3.ZERO)
	var nose := [-5.12, 0.96, -4.45, 0.96, -4.45, 1.98, -4.88, 1.92, -5.12, 1.74]
	k._add(m, VehicleModels.extrude_x("nato_hemtt_nose", nose, -1.1, 1.1), cab, null, Vector3.ZERO)
	# the big grille, the bumper with the headlights in its ends, tow eyes,
	# the pintle
	k._box(m, Vector3(1.86, 0.66, 0.04), Vector3(0, 1.4, -5.13), "gunmetal_w")
	for i in 12:
		k._box(m, Vector3(1.8, 0.024, 0.03), Vector3(0, 1.12 + i * 0.052, -5.15), cab, null, Vector3.ZERO, false)
	k._box(m, Vector3(2.0, 0.06, 0.08), Vector3(0, 1.76, -5.13), cab)
	k._box(m, Vector3(2.44, 0.32, 0.24), Vector3(0, 0.9, -5.14), "steel", paint.darkened(0.15))
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.3, 0.2, 0.06), Vector3(s * 0.96, 0.94, -5.27), "gunmetal_w")
		if not k.burnt:
			k._box(m, Vector3(0.12, 0.12, 0.02), Vector3(s * 1.02, 0.94, -5.305), "plain", Color(0.72, 0.72, 0.66), Vector3.ZERO, false)
			k._box(m, Vector3(0.08, 0.08, 0.02), Vector3(s * 0.88, 0.94, -5.305), "paint", Color(0.55, 0.36, 0.08), Vector3.ZERO, false)
		_shackle(k, m, Vector3(s * 0.55, 0.8, -5.2))
		k._box(m, Vector3(0.12, 0.06, 0.03), Vector3(s * 1.1, 1.82, -5.0), "paint", Color(0.55, 0.36, 0.08), Vector3.ZERO, false)
	k._box(m, Vector3(0.3, 0.22, 0.16), Vector3(0, 0.84, -5.3), "gunmetal_w")
	# the sun visor over the windscreen
	k._box(m, Vector3(2.24, 0.04, 0.32), Vector3(0, 2.84, -4.44), cab, null, Vector3(0.12, 0, 0))
	# windscreen panes, door windows, door seams, handles, mirrors, steps
	var wa := Vector2(-4.5, 1.95)
	var wb := Vector2(-4.34, 2.86)
	for s in [-1.0, 1.0]:
		_zy(k, m, s * 0.56, 0.98, wa.lerp(wb, 0.12), wa.lerp(wb, 0.82), 0.04, 0.0, "glass", null, false)
		k._box(m, Vector3(0.04, 0.6, 0.85), Vector3(s * 1.2, 2.26, -3.72), "glass", null, Vector3(0, 0, s * 0.03), false)
		k._box(m, Vector3(0.03, 0.02, 1.25), Vector3(s * 1.205, 1.92, -3.65), "gunmetal_w", null, Vector3.ZERO, false)
		for dz in [-4.3, -3.05]:
			k._box(m, Vector3(0.02, 1.3, 0.03), Vector3(s * 1.205, 2.05, dz), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.04, 0.05, 0.16), Vector3(s * 1.23, 1.75, -3.2), "gunmetal_w", null, Vector3.ZERO, false)
		_tube(k, m, Vector3(s * 1.2, 2.5, -4.35), Vector3(s * 1.5, 2.45, -4.5), 0.022, "gunmetal_w")
		_tube(k, m, Vector3(s * 1.2, 2.0, -4.35), Vector3(s * 1.5, 2.1, -4.5), 0.022, "gunmetal_w")
		k._box(m, Vector3(0.05, 0.42, 0.24), Vector3(s * 1.52, 2.28, -4.52), "gunmetal_w")
		# the ladder steps up to the door
		for i in 2:
			k._box(m, Vector3(0.3, 0.04, 0.42), Vector3(s * 1.12, 0.55 + i * 0.36, -3.05), "gunmetal_w")
		k._box(m, Vector3(0.04, 0.8, 0.04), Vector3(s * 1.26, 0.85, -3.25), "gunmetal_w")
		k._box(m, Vector3(0.04, 0.8, 0.04), Vector3(s * 1.26, 0.85, -2.85), "gunmetal_w")
		# the long black fender over both front axles, raked at its front
		k._box(m, Vector3(0.54, 0.06, 2.55), Vector3(s * 0.98, 1.34, -3.08), "rubber")
		k._box(m, Vector3(0.54, 0.06, 0.5), Vector3(s * 0.98, 1.24, -4.55), "rubber", null, Vector3(0.45, 0, 0))
		k._box(m, Vector3(0.54, 0.45, 0.05), Vector3(s * 0.98, 1.12, -1.8), "rubber")
	# the roof hatch, marker lights, antenna
	k._box(m, Vector3(0.7, 0.06, 0.7), Vector3(0.35, 2.87, -3.5), cab)
	for i in 3:
		k._box(m, Vector3(0.08, 0.05, 0.05), Vector3(-0.15 + i * 0.15, 2.86, -4.32), "paint", Color(0.55, 0.36, 0.08), Vector3.ZERO, false)
	_antenna(k, m, Vector3(-1.05, 2.84, -2.95), 1.4)
	# behind the cab: the engine's air cleaner (left), the exhaust stack
	# (right), the spare wheel between
	k._cyl(m, 0.24, 0.24, 1.3, Vector3(-0.85, 2.0, -2.68), Vector3.ZERO, cab, null, 12)
	k._cyl(m, 0.2, 0.2, 0.1, Vector3(-0.85, 2.7, -2.68), Vector3.ZERO, "gunmetal_w", null, 12)
	k._cyl(m, 0.08, 0.08, 1.9, Vector3(0.92, 2.15, -2.7), Vector3.ZERO, "gunmetal_w", null, 8)
	k._cyl(m, 0.1, 0.1, 0.5, Vector3(0.92, 2.0, -2.7), Vector3.ZERO, "metal_dark", null, 8)
	k._cyl(m, 0.085, 0.07, 0.12, Vector3(0.92, 3.12, -2.7), Vector3(0.6, 0, 0), "gunmetal_w", null, 8)
	_spare(k, m, Vector3(0.0, 2.0, -2.65), 0.6, 0.42, Vector3(PI / 2, 0, 0))
	# fuel tank and battery box on the frame, air tanks
	k._cyl(m, 0.3, 0.3, 1.1, Vector3(-0.95, 1.0, -1.0), Vector3(PI / 2, 0, 0), "steel", paint.darkened(0.2), 14)
	k._box(m, Vector3(0.5, 0.5, 0.7), Vector3(0.95, 1.0, -1.1), cab)
	for s in [-1.0, 1.0]:
		k._cyl(m, 0.12, 0.12, 0.8, Vector3(s * 0.75, 0.72, 0.4), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
		_tube(k, m, Vector3(s * 1.15, 0.7, -1.7), Vector3(s * 1.15, 0.7, 1.5), 0.04, "gunmetal_w", null, 6)
	_team_mark(k, m, team, Vector3(1.205, 1.6, -3.7), Vector3(0.02, 0.24, 0.6))
	_team_mark(k, m, team, Vector3(-1.205, 1.6, -3.7), Vector3(0.02, 0.24, 0.6))


## The rear end common to the flatbed bodies: the deck on its frame, fenders
## over the tandem, tail lights, mud flaps, the rear bumper.
static func _hemtt_deck(k: VehicleModels, paint: Color, z0 := -2.4, z1 := 5.05) -> void:
	var m := k.root
	k._box(m, Vector3(2.44, 0.16, z1 - z0), Vector3(0, 1.3, (z0 + z1) * 0.5), "steel", paint.darkened(0.1))
	k._box(m, Vector3(2.4, 0.2, z1 - z0), Vector3(0, 1.14, (z0 + z1) * 0.5), "gunmetal_w")
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.5, 0.05, 3.1), Vector3(s * 0.98, 1.36 - 0.06, 2.9), "rubber")
		k._box(m, Vector3(0.46, 0.5, 0.03), Vector3(s * 0.98, 0.8, 4.4), "rubber")
		_taillight(k, m, Vector3(s * 0.95, 1.12, z1 + 0.04))
		_shackle(k, m, Vector3(s * 0.5, 0.95, z1 + 0.02), 1.0)
	k._box(m, Vector3(2.3, 0.16, 0.16), Vector3(0, 0.9, z1 + 0.06), "steel", paint.darkened(0.15))
	k._box(m, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.95, z1 + 0.1), "gunmetal_w")


## HEMTT variants by body: "troop" (benches under a canvas tilt), "cargo"
## (crates and pallets), "ammo" (ammunition pallets and a loading crane),
## "repair" (a workshop box), "medical" (an ambulance box with red crosses),
## "fuel" (a tanker).
static func _hemtt(k: VehicleModels, team: int, body: String) -> void:
	var m := k.root
	var paint := Color(0.3, 0.32, 0.23) if team != 1 else Color(0.46, 0.42, 0.32)
	var cam := "camo_tank" if team != 1 else "camo_tank_rebel"
	_hemtt_chassis(k, team, paint)
	match body:
		"troop", "cargo", "ammo":
			_hemtt_deck(k, paint)
			# drop sides and the headboard
			var sh := 0.62 if body != "ammo" else 0.36
			for s in [-1.0, 1.0]:
				k._box(m, Vector3(0.06, sh, 7.4), Vector3(s * 1.2, 1.38 + sh * 0.5, 1.33), cam)
				for i in 6:
					k._box(m, Vector3(0.08, sh, 0.06), Vector3(s * 1.22, 1.38 + sh * 0.5, -2.3 + i * 1.47), "gunmetal_w", null, Vector3.ZERO, false)
			k._box(m, Vector3(2.44, 1.1, 0.08), Vector3(0, 1.93, -2.4), cam)
			k._box(m, Vector3(2.4, sh, 0.06), Vector3(0, 1.38 + sh * 0.5, 5.02), cam)
			if body == "troop":
				# the canvas tilt over its bows, the back rolled up over the benches
				var tsec := [-1.22, 1.98, 1.22, 1.98, 1.22, 2.55, 0.98, 2.86, -0.98, 2.86, -1.22, 2.55]
				k._add(m, _extrude_z("nato_hemtt_tilt", tsec, -2.35, 4.95), "canvas", paint.lightened(0.08), Vector3.ZERO)
				for i in 6:
					var z := -2.2 + i * 1.42
					k._add(m, _extrude_z("nato_hemtt_bow", [-1.24, 1.98, 1.24, 1.98, 1.24, 2.56, 0.99, 2.88, -0.99, 2.88, -1.24, 2.56], -0.04, 0.04), "canvas", paint.darkened(0.12), Vector3(0, 0, z))
				k._box(m, Vector3(2.3, 0.82, 0.02), Vector3(0, 2.38, 4.965), "plain_dark", null, Vector3.ZERO, false)
				k._cyl(m, 0.12, 0.12, 2.4, Vector3(0, 2.7, 5.0), Vector3(0, 0, PI / 2), "canvas", paint.lightened(0.04), 10)
				for s in [-1.0, 1.0]:
					k._box(m, Vector3(0.38, 0.08, 6.6), Vector3(s * 0.88, 1.85, 1.3), "wood_dark")
					k._box(m, Vector3(0.06, 0.3, 6.6), Vector3(s * 1.1, 2.1, 1.3), "wood_dark")
					for i in 8:
						k._box(m, Vector3(0.05, 0.03, 0.03), Vector3(s * 1.2, 2.2 + (i % 2) * 0.25, -1.8 + i * 0.85), "gunmetal_w", null, Vector3.ZERO, false)
				k._box(m, Vector3(0.6, 0.06, 0.4), Vector3(0, 0.8, 5.2), "gunmetal_w")
			elif body == "cargo":
				# palletised crates and boxes lashed down, a tarp over one load
				var loads := [[-0.55, -1.7, 1.0, 0.9, 1.0, 0], [0.55, -1.7, 1.0, 0.7, 1.0, 1], [-0.55, -0.55, 1.0, 1.0, 1.1, 2], [0.55, -0.55, 1.0, 0.8, 1.0, 0],
						[-0.55, 0.65, 1.0, 0.75, 1.1, 1], [0.55, 0.65, 1.0, 1.05, 1.1, 3], [-0.55, 1.95, 1.0, 0.9, 1.2, 0], [0.55, 1.95, 1.0, 0.6, 1.2, 2],
						[-0.55, 3.3, 1.0, 1.0, 1.2, 3], [0.55, 3.3, 1.0, 0.8, 1.2, 1], [0.0, 4.45, 2.0, 0.55, 0.8, 2]]
				for l in loads:
					_cargo(k, m, Vector3(l[0], 1.38, l[1]), Vector3(l[2], l[3], l[4]), int(l[5]))
			else:
				# ammunition: pallets of boxes, then the knuckle-boom crane at the
				# back, folded forward over the load
				for i in 5:
					for s in [-1.0, 1.0]:
						var pz := -1.7 + i * 1.25
						k._box(m, Vector3(1.05, 0.12, 1.1), Vector3(s * 0.56, 1.44, pz), "wood")
						var hh := 0.62 if (i + int(s > 0.0)) % 3 != 0 else 0.32
						for a in 2:
							for b in 2:
								k._box(m, Vector3(0.48, hh, 0.5), Vector3(s * 0.56 + (a - 0.5) * 0.5, 1.5 + hh * 0.5, pz + (b - 0.5) * 0.52), "paint", STOW if (a + b) % 2 == 0 else STOW.darkened(0.15))
						k._box(m, Vector3(1.07, 0.03, 0.06), Vector3(s * 0.56, 1.51 + hh, pz), "plain_dark", null, Vector3.ZERO, false)
				var cb := Vector3(0.75, 1.38, 4.55)
				k._cyl(m, 0.3, 0.34, 0.3, cb + Vector3(0, 0.15, 0), Vector3.ZERO, "gunmetal_w", null, 12)
				k._box(m, Vector3(0.36, 0.9, 0.36), cb + Vector3(0, 0.75, 0), cam)
				_beam(k, m, cb + Vector3(0, 1.1, 0), cb + Vector3(0, 1.32, -2.6), 0.24, 0.26, cam)
				_beam(k, m, cb + Vector3(0, 1.32, -2.6), cb + Vector3(0, 1.0, -1.0), 0.18, 0.2, "steel", paint)
				_tube(k, m, cb + Vector3(0, 0.6, -0.1), cb + Vector3(0, 1.15, -1.2), 0.07, "gunmetal_w")
				k._box(m, Vector3(0.1, 0.25, 0.1), cb + Vector3(0, 0.82, -1.0), "steel")
				for s in [-1.0, 1.0]:
					k._box(m, Vector3(0.5, 0.14, 0.14), Vector3(s * 1.0, 1.14, 4.7), "gunmetal_w")
					k._box(m, Vector3(0.14, 0.42, 0.14), Vector3(s * 1.25, 0.95, 4.7), "gunmetal_w")
					k._box(m, Vector3(0.22, 0.05, 0.22), Vector3(s * 1.25, 0.72, 4.7), "gunmetal_w")
		"repair", "medical":
			_hemtt_deck(k, paint)
			# the shelter: a tall box body with a ribbed roof edge
			k._box(m, Vector3(2.44, 1.62, 7.3), Vector3(0, 2.2, 1.33), cam)
			for s in [-1.0, 1.0]:
				k._box(m, Vector3(0.06, 0.06, 7.3), Vector3(s * 1.23, 3.0, 1.33), "gunmetal_w", null, Vector3.ZERO, false)
				k._box(m, Vector3(0.06, 0.06, 7.3), Vector3(s * 1.23, 1.4, 1.33), "gunmetal_w", null, Vector3.ZERO, false)
			if body == "repair":
				for s in [-1.0, 1.0]:
					# roll-up shutters with their slats, tool lockers below
					for j in 3:
						var z := -1.2 + j * 2.2
						k._box(m, Vector3(0.03, 1.3, 1.9), Vector3(s * 1.225, 2.2, z), "steel", paint.darkened(0.08))
						for i in 6:
							k._box(m, Vector3(0.02, 0.02, 1.88), Vector3(s * 1.24, 1.65 + i * 0.22, z), "gunmetal_w", null, Vector3.ZERO, false)
					k._box(m, Vector3(0.3, 0.4, 2.4), Vector3(s * 1.08, 0.88, 3.4), "gunmetal_w")
				# the light mast, AC unit, the rear door and ladder, a vice bench
				k._box(m, Vector3(1.0, 0.36, 0.7), Vector3(0, 3.18, -1.6), "gunmetal_w")
				k._cyl(m, 0.06, 0.06, 1.6, Vector3(-0.9, 3.08, 3.8), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
				k._box(m, Vector3(0.5, 0.14, 0.14), Vector3(-0.9, 3.08, 3.0), "gunmetal_w")
				k._box(m, Vector3(0.14, 0.14, 0.1), Vector3(-0.9, 3.06, 4.6), "gunmetal_w")
				k._box(m, Vector3(0.9, 1.4, 0.04), Vector3(0.45, 2.15, 5.0), "steel", paint.darkened(0.08))
				for i in 5:
					k._box(m, Vector3(0.4, 0.03, 0.04), Vector3(-0.6, 1.5 + i * 0.32, 5.05), "gunmetal_w", null, Vector3.ZERO, false)
				for s in [-1.0, 1.0]:
					k._box(m, Vector3(0.03, 1.5, 0.04), Vector3(-0.6 + s * 0.2, 2.15, 5.05), "gunmetal_w", null, Vector3.ZERO, false)
			else:
				# windows, the rear doors with a step, roof vents, red crosses
				for s in [-1.0, 1.0]:
					for z in [0.0, 2.2]:
						k._box(m, Vector3(0.03, 0.4, 0.6), Vector3(s * 1.225, 2.45, z), "glass", null, Vector3.ZERO, false)
					_cross(k, m, Vector3(s * 1.23, 2.2, 3.6), Vector3(0, s * PI / 2, 0), 1.0)
					_cross(k, m, Vector3(s * 1.23, 2.2, -1.25), Vector3(0, s * PI / 2, 0), 1.0)
				_cross(k, m, Vector3(0, 3.02, 1.3), Vector3(-PI / 2, 0, 0), 1.3)
				for s in [-1.0, 1.0]:
					k._box(m, Vector3(1.15, 1.45, 0.04), Vector3(s * 0.6, 2.15, 5.0), "steel", paint.darkened(0.05))
				_cross(k, m, Vector3(0.6, 2.4, 5.03), Vector3.ZERO, 0.6)
				k._box(m, Vector3(1.6, 0.05, 0.5), Vector3(0, 0.95, 5.3), "gunmetal_w")
				k._box(m, Vector3(0.5, 0.3, 0.5), Vector3(0.6, 3.15, -0.8), "gunmetal_w")
				k._box(m, Vector3(0.8, 0.3, 0.7), Vector3(-0.3, 3.15, 3.6), "gunmetal_w")
		"fuel":
			_hemtt_deck(k, paint, -2.4, 5.05)
			# the tank: an oval barrel on cradles, its end caps, the walkway on
			# top with its rail, manholes, the pump cabinet and hose reels at the back
			var ts := []
			for i in 12:
				var a := TAU * i / 12.0
				ts.append(cos(a) * 1.12)
				ts.append(2.08 + sin(a) * 0.68)
			k._add(m, _extrude_z("nato_hemtt_tank", ts, -2.2, 3.7), cam, null, Vector3.ZERO)
			for z in [-2.2, 3.7]:
				k._add(m, _extrude_z("nato_hemtt_tankend", ts, -0.04, 0.04), "gunmetal_w", null, Vector3(0, 0, z), Vector3.ZERO, Vector3(0.98, 0.98, 1.0))
			for z in [-1.4, 0.75, 2.9]:
				k._box(m, Vector3(2.3, 0.3, 0.2), Vector3(0, 1.5, z), "gunmetal_w")
				k._box(m, Vector3(2.28, 0.05, 0.08), Vector3(0, 2.08, z), "gunmetal_w", null, Vector3.ZERO, false)
			k._box(m, Vector3(0.6, 0.04, 5.6), Vector3(0, 2.78, 0.75), "gunmetal_w")
			for z in [-1.2, 0.75, 2.7]:
				k._cyl(m, 0.24, 0.24, 0.1, Vector3(0, 2.8, z), Vector3.ZERO, "gunmetal_w", null, 12)
			for s in [-1.0, 1.0]:
				for i in 5:
					k._cyl(m, 0.015, 0.015, 0.45, Vector3(s * 0.3, 3.0, -1.9 + i * 1.32), Vector3.ZERO, "gunmetal_w", null, 4, false)
				k._box(m, Vector3(0.03, 0.03, 5.4), Vector3(s * 0.3, 3.22, 0.75), "gunmetal_w", null, Vector3.ZERO, false)
			k._box(m, Vector3(2.4, 1.3, 1.2), Vector3(0, 2.0, 4.42), cam)
			k._box(m, Vector3(2.0, 1.0, 0.04), Vector3(0, 2.0, 5.03), "steel", paint.darkened(0.08))
			for s in [-1.0, 1.0]:
				k._cyl(m, 0.36, 0.36, 0.3, Vector3(s * 1.05, 1.95, 4.4), Vector3(0, 0, PI / 2), "gunmetal_w", null, 14)
				k._cyl(m, 0.3, 0.3, 0.32, Vector3(s * 1.05, 1.95, 4.4), Vector3(0, 0, PI / 2), "rubber", null, 14)
			# the hazard placard
			if not k.burnt:
				k._box(m, Vector3(0.36, 0.26, 0.02), Vector3(0, 1.62, 5.06), "paint", Color(0.62, 0.48, 0.12), Vector3.ZERO, false)


## One crate / pallet load on the cargo bed: kind 0 wooden crate, 1 olive
## boxes on a pallet, 2 a tarp-covered load, 3 drums.
static func _cargo(k: VehicleModels, m: Node3D, base: Vector3, s: Vector3, kind: int) -> void:
	match kind:
		0:
			k._box(m, Vector3(s.x - 0.08, s.y, s.z - 0.06), base + Vector3(0, s.y * 0.5, 0), "wood")
			for y in [0.1, s.y - 0.1]:
				k._box(m, Vector3(s.x - 0.06, 0.06, s.z - 0.04), base + Vector3(0, y, 0), "wood_dark", null, Vector3.ZERO, false)
		1:
			k._box(m, Vector3(s.x - 0.06, 0.12, s.z - 0.06), base + Vector3(0, 0.06, 0), "wood")
			for i in 2:
				for j in 2:
					k._box(m, Vector3(s.x * 0.46, s.y - 0.14, s.z * 0.45), base + Vector3((i - 0.5) * s.x * 0.48, 0.12 + (s.y - 0.14) * 0.5, (j - 0.5) * s.z * 0.47), "paint", STOW if (i + j) % 2 == 0 else STOW.darkened(0.12))
			k._box(m, Vector3(s.x - 0.04, 0.03, 0.05), base + Vector3(0, s.y + 0.0, 0), "plain_dark", null, Vector3.ZERO, false)
		2:
			k._box(m, Vector3(s.x - 0.06, 0.12, s.z - 0.06), base + Vector3(0, 0.06, 0), "wood")
			k._box(m, Vector3(s.x - 0.1, s.y - 0.12, s.z - 0.1), base + Vector3(0, 0.12 + (s.y - 0.12) * 0.5, 0), "canvas", BAG)
		_:
			k._box(m, Vector3(s.x - 0.06, 0.1, s.z - 0.06), base + Vector3(0, 0.05, 0), "wood")
			for i in 2:
				for j in 2:
					k._cyl(m, 0.21, 0.21, s.y - 0.1, base + Vector3((i - 0.5) * 0.46, 0.1 + (s.y - 0.1) * 0.5, (j - 0.5) * 0.48), Vector3.ZERO, "steel", Color(0.28, 0.32, 0.22) if (i + j) % 2 == 0 else Color(0.36, 0.3, 0.2), 12)


## A red cross on a white square, facing along the panel's local +z.
static func _cross(k: VehicleModels, p: Node3D, pos: Vector3, rot: Vector3, size: float) -> void:
	if k.burnt:
		return
	var b := Basis.from_euler(rot)
	k._box(p, Vector3(size, size, 0.02), pos, "plain", Color(0.86, 0.86, 0.82), rot, false)
	k._box(p, Vector3(size * 0.7, size * 0.22, 0.02), pos + b * Vector3(0, 0, 0.012), "paint", Color(0.62, 0.07, 0.06), rot, false)
	k._box(p, Vector3(size * 0.22, size * 0.7, 0.02), pos + b * Vector3(0, 0, 0.012), "paint", Color(0.62, 0.07, 0.06), rot, false)


# --- Stomper: NREC Crusher UGCV ----------------------------------------------------------

## Crusher: a low angular robot on six big wheels on long swing arms, an
## open space-frame over its armoured tub, the sensor mast forward, and a
## remote weapon station with a 12.7 mm and a 40 mm GMG on top.
static func _stomper(k: VehicleModels, team: int) -> void:
	var cam := _cam(team)
	var m := k.root
	var wr := 0.57
	for s in [-1.0, 1.0]:
		for z in [-1.85, 0.0, 1.85]:
			k._wheel(m, Vector3(s * 1.06, wr, z), wr, 0.48)
			# the swing arm from the hull to the hub, its motor housing
			_beam(k, m, Vector3(s * 0.62, 0.86, z + 0.45 * signf(z + 0.01)), Vector3(s * 0.8, wr, z), 0.14, 0.2, "gunmetal_w")
			k._cyl(m, 0.2, 0.2, 0.16, Vector3(s * 0.74, wr, z), Vector3(0, 0, PI / 2), "metal_dark", null, 12)
	# the armoured tub: a wedge nose, the flanks leaning in
	var b0 := [-0.42, -2.2, 0.42, -2.2, 0.62, -1.85, 0.62, 2.15, 0.42, 2.4, -0.42, 2.4, -0.62, 2.15, -0.62, -1.85]
	var b1 := [-0.5, -2.5, 0.5, -2.5, 0.72, -2.15, 0.72, 2.3, 0.5, 2.55, -0.5, 2.55, -0.72, 2.3, -0.72, -2.15]
	var b2 := [-0.4, -1.75, 0.4, -1.75, 0.58, -1.5, 0.58, 2.1, 0.42, 2.32, -0.42, 2.32, -0.58, 2.1, -0.58, -1.5]
	k._add(m, VehicleModels.solid([VehicleModels.ring_y(VehicleModels._v2(b0), 0.42), VehicleModels.ring_y(VehicleModels._v2(b1), 0.9), VehicleModels.ring_y(VehicleModels._v2(b2), 1.32)], "nato_crusher_tub"), cam, null, Vector3.ZERO)
	# side pods over the wheels (batteries / engine), angular, low
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.loft("nato_crusher_pod", [-0.14, -1.3, 0.14, -1.3, 0.14, 1.4, -0.14, 1.4], [-0.1, -1.1, 0.1, -1.1, 0.1, 1.25, -0.1, 1.25], 0.0, 0.34), cam, null, Vector3(s * 0.7, 0.98, 0))
	# the space frame over the tub: rails, hoops and diagonals
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.62, 1.3, -1.8), Vector3(s * 0.55, 1.62, -0.9), 0.04, "gunmetal_w")
		_tube(k, m, Vector3(s * 0.55, 1.62, -0.9), Vector3(s * 0.55, 1.62, 1.6), 0.04, "gunmetal_w")
		_tube(k, m, Vector3(s * 0.55, 1.62, 1.6), Vector3(s * 0.6, 1.3, 2.25), 0.04, "gunmetal_w")
		for z in [-0.9, 0.35, 1.6]:
			_tube(k, m, Vector3(s * 0.58, 1.3, z), Vector3(s * 0.55, 1.62, z), 0.035, "gunmetal_w")
		_tube(k, m, Vector3(s * 0.58, 1.3, 0.35), Vector3(s * 0.55, 1.62, 1.6), 0.03, "gunmetal_w")
	for z in [-0.9, 1.6]:
		_tube(k, m, Vector3(-0.55, 1.62, z), Vector3(0.55, 1.62, z), 0.04, "gunmetal_w")
	# the sensor mast at the nose: stereo cameras, laser scanners, a GPS dome
	_tube(k, m, Vector3(0, 1.3, -1.6), Vector3(0, 1.85, -1.75), 0.05, "gunmetal_w")
	k._box(m, Vector3(0.7, 0.16, 0.2), Vector3(0, 1.9, -1.78), "gunmetal_w")
	if not k.burnt:
		for x in [-0.25, 0.25]:
			k._cyl(m, 0.05, 0.05, 0.04, Vector3(x, 1.9, -1.9), Vector3(PI / 2, 0, 0), "glass", null, 10, false)
	for s in [-1.0, 1.0]:
		k._cyl(m, 0.08, 0.08, 0.12, Vector3(s * 0.45, 1.36, -2.0), Vector3.ZERO, "plain_dark", null, 10)
		k._cyl(m, 0.08, 0.08, 0.12, Vector3(s * 0.45, 1.36, 2.15), Vector3.ZERO, "plain_dark", null, 10)
		_lamp(k, m, Vector3(s * 0.4, 0.95, -2.5), 0.05, -1.0, false)
		_taillight(k, m, Vector3(s * 0.38, 0.95, 2.56))
	k._add(m, Res.sphere(0.1, 10), "plain", Color(0.7, 0.7, 0.66), Vector3(0, 2.02, -1.75), Vector3.ZERO, Vector3(1, 0.6, 1))
	_antenna(k, m, Vector3(-0.45, 1.62, 1.9), 1.2)
	_antenna(k, m, Vector3(0.45, 1.62, 1.9), 0.8)
	k._box(m, Vector3(0.8, 0.12, 0.5), Vector3(0, 1.38, 1.95), "gunmetal_w")
	_team_mark(k, m, team, Vector3(0.66, 1.1, 1.0), Vector3(0.02, 0.18, 0.6))
	_team_mark(k, m, team, Vector3(-0.66, 1.1, 1.0), Vector3(0.02, 0.18, 0.6))
	# the RCWS on the frame
	k._box(m, Vector3(1.0, 0.06, 0.9), Vector3(0, 1.64, 0.35), "gunmetal_w")
	_rcws(k, m, Vector3(0, 1.67, 0.35), "both", cam, 0.9)
