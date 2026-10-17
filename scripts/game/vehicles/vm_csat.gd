class_name VmCsat
extends RefCounted
## Procedural models: CSAT ground vehicles (Ifrit, Qilin, Marid, Kamysh, Varsuk, Futura, Angara, Tigris, Sochor, Tempest).
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys must be unique per shape).
##
## Hulls are shared where the real vehicles share them: the Karatel (Ifrits),
## the LSV (Qilins), the Arma 6x6 (Marid), the Stalker (Kamysh, Tigris), the
## T-100 (Varsuk, Futura, Sochor), the T-14 (Angaras) and the Typhoon-K
## (Tempests). CSAT paint is the arid hex camouflage, camo_tank_rebel.

## Every model key this file builds (the Field Manual's model pages list them).
const KEYS: Array[String] = ["ifrit", "ifrit_hmg", "ifrit_gmg", "qilin", "qilin_mg", "qilin_at", "marid", "kamysh", "tigris", "varsuk", "futura", "sochor",
	"angara", "angara_k", "tempest", "tempest_ammo", "tempest_repair", "tempest_medical", "tempest_fuel"]

const CAM := "camo_tank_rebel"
const WHEEL_PAINT := Color(0.31, 0.29, 0.22)  # road wheels and hubs, a shade darker than the hull
const OLIVE := Color(0.3, 0.31, 0.23)  # ammo boxes, launchers, canvas


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"ifrit":
			_ifrit(k, team, "")
		"ifrit_hmg":
			_ifrit(k, team, "hmg")
		"ifrit_gmg":
			_ifrit(k, team, "gmg")
		"qilin":
			_qilin(k, team, "")
		"qilin_mg":
			_qilin(k, team, "mg")
		"qilin_at":
			_qilin(k, team, "at")
		"marid":
			_marid(k, team)
		"kamysh":
			_kamysh(k, team)
		"tigris":
			_tigris(k, team)
		"varsuk":
			_varsuk(k, team)
		"futura":
			_futura(k, team)
		"sochor":
			_sochor(k, team)
		"angara":
			_angara(k, team, false)
		"angara_k":
			_angara(k, team, true)
		"tempest":
			_tempest(k, team, "")
		"tempest_ammo":
			_tempest(k, team, "ammo")
		"tempest_repair":
			_tempest(k, team, "repair")
		"tempest_medical":
			_tempest(k, team, "medical")
		"tempest_fuel":
			_tempest(k, team, "fuel")
		_:
			return false
	return true


# --- shared geometry helpers -------------------------------------------------------

## An 8-sided cross-section across x at z, symmetric about x = 0: the bottom
## (half-width bw at y0), the lower chine (cw, yc), the belt line (ww, yw) and
## the roof edge (rw, yr). Successive sections lofted with VehicleModels.solid
## make faceted hulls.
static func _sec(z: float, bw: float, y0: float, cw: float, yc: float, ww: float, yw: float, rw: float, yr: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(-bw, y0, z), Vector3(bw, y0, z), Vector3(cw, yc, z), Vector3(ww, yw, z),
		Vector3(rw, yr, z), Vector3(-rw, yr, z), Vector3(-ww, yw, z), Vector3(-cw, yc, z)])


## A convex ring across x at z from x, y pairs.
static func _rz(pairs: Array, z: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in range(0, pairs.size(), 2):
		r.append(Vector3(pairs[i], pairs[i + 1], z))
	return r


## XZ outline pairs mirrored to the -x side.
static func _mx(pairs: Array) -> Array:
	var o := []
	for i in range(0, pairs.size(), 2):
		o.append(-float(pairs[i]))
		o.append(pairs[i + 1])
	return o


## Euler rotation that turns +Y onto d (the second axis hint keeps +X near `xh`).
static func _aim_y(d: Vector3, xh := Vector3.RIGHT) -> Vector3:
	var y := d.normalized()
	if absf(y.dot(xh.normalized())) > 0.95:
		xh = Vector3.FORWARD
	var z := xh.cross(y).normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z).get_euler()


## A round bar from a to b.
static func _tube(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, r: float, mat: String, col = null, segs := 8, shadow := true) -> Variant:
	return k._add(p, Res.cyl(r, r, (b - a).length(), segs), mat, col, (a + b) * 0.5, _aim_y(b - a), Vector3.ONE, shadow)


## A flat plate whose length runs from a to b, `w` wide (along x unless the
## plate runs along x) and `t` thick.
static func _plate(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, w: float, t: float, mat: String, col = null, xh := Vector3.RIGHT, shadow := true) -> Variant:
	return k._add(p, Res.box(Vector3(w, (b - a).length(), t)), mat, col, (a + b) * 0.5, _aim_y(b - a, xh), Vector3.ONE, shadow)


## A pane (glass, a hatch, a grille) lying on a sloped face: centre c, `up`
## the in-face direction its height runs along, size (width along x, height).
static func _pane(k: VehicleModels, p: Node3D, c: Vector3, up: Vector3, s: Vector2, mat: String, col = null, t := 0.03, xh := Vector3.RIGHT) -> Variant:
	var u := up.normalized() * s.y * 0.5
	return _plate(k, p, c - u, c + u, s.x, t, mat, col, xh, false)


## Three flat plates over a wheel: the faceted arch of an armoured car.
static func _arch(k: VehicleModels, p: Node3D, x: float, z: float, r: float, w: float, y_top: float, mat := CAM) -> void:
	var f := Vector3(x, y_top - r * 0.62, z - r * 1.18)
	var a := Vector3(x, y_top, z - r * 0.55)
	var b := Vector3(x, y_top, z + r * 0.55)
	var e := Vector3(x, y_top - r * 0.62, z + r * 1.18)
	_plate(k, p, f, a, w, 0.05, mat)
	_plate(k, p, a, b, w, 0.05, mat)
	_plate(k, p, b, e, w, 0.05, mat)


## A headlight cluster facing -z: housing, two lenses and a wire guard.
static func _headlight(k: VehicleModels, p: Node3D, pos: Vector3, guard := true) -> void:
	k._box(p, Vector3(0.26, 0.15, 0.1), pos, "gunmetal_w")
	if not k.burnt:
		k._box(p, Vector3(0.1, 0.09, 0.02), pos + Vector3(-0.06, 0, -0.052), "plain", Color(0.85, 0.84, 0.76), Vector3.ZERO, false)
		k._box(p, Vector3(0.08, 0.07, 0.02), pos + Vector3(0.07, 0, -0.052), "glass", null, Vector3.ZERO, false)
	if guard:
		for dx in [-0.1, 0.0, 0.1]:
			k._box(p, Vector3(0.015, 0.17, 0.015), pos + Vector3(dx, 0, -0.09), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(p, Vector3(0.28, 0.015, 0.1), pos + Vector3(0, 0.09, -0.05), "gunmetal_w", null, Vector3.ZERO, false)


## A tail light pair facing +z.
static func _taillight(k: VehicleModels, p: Node3D, pos: Vector3) -> void:
	k._box(p, Vector3(0.2, 0.1, 0.05), pos, "gunmetal_w")
	if not k.burnt:
		k._box(p, Vector3(0.07, 0.06, 0.02), pos + Vector3(-0.045, 0, 0.03), "paint", Color(0.42, 0.06, 0.04), Vector3.ZERO, false)
		k._box(p, Vector3(0.07, 0.06, 0.02), pos + Vector3(0.045, 0, 0.03), "paint", Color(0.5, 0.3, 0.05), Vector3.ZERO, false)


## A whip antenna on a base.
static func _antenna(k: VehicleModels, p: Node3D, pos: Vector3, h: float) -> void:
	k._cyl(p, 0.04, 0.05, 0.12, pos + Vector3(0, 0.06, 0), Vector3.ZERO, "gunmetal_w", null, 8)
	k._cyl(p, 0.008, 0.012, h, pos + Vector3(0, 0.12 + h * 0.5, 0), Vector3.ZERO, "gunmetal_w", null, 4, false)


## A tow hook/shackle facing along `dir` (-1 front, +1 rear).
static func _tow(k: VehicleModels, p: Node3D, pos: Vector3, dir: float) -> void:
	k._box(p, Vector3(0.12, 0.12, 0.14), pos, "gunmetal_w")
	k._cyl(p, 0.05, 0.05, 0.03, pos + Vector3(0, 0, dir * 0.1), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8, false)
	k._box(p, Vector3(0.03, 0.12, 0.05), pos + Vector3(-0.045, 0, dir * 0.11), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(p, Vector3(0.03, 0.12, 0.05), pos + Vector3(0.045, 0, dir * 0.11), "gunmetal_w", null, Vector3.ZERO, false)


## A jerrycan standing upright, its face toward x.
static func _jerrycan(k: VehicleModels, p: Node3D, pos: Vector3, col := OLIVE, rot := Vector3.ZERO) -> void:
	k._box(p, Vector3(0.16, 0.46, 0.34), pos, "paint", col, rot)
	k._box(p, Vector3(0.05, 0.05, 0.14), pos + Vector3(0, 0.25, 0.06), "paint", col.darkened(0.2), rot, false)


## A round hatch with its hinge (a cupola lid).
static func _hatch(k: VehicleModels, p: Node3D, pos: Vector3, r: float, mat := CAM, col = null) -> void:
	k._cyl(p, r + 0.03, r + 0.04, 0.06, pos + Vector3(0, 0.03, 0), Vector3.ZERO, mat, col, 16)
	k._cyl(p, r - 0.02, r, 0.05, pos + Vector3(0, 0.08, 0), Vector3.ZERO, mat, col, 16)
	k._box(p, Vector3(0.24, 0.05, 0.08), pos + Vector3(0, 0.08, r * 0.95), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(p, Vector3(0.12, 0.03, 0.03), pos + Vector3(0, 0.12, -r * 0.4), "gunmetal_w", null, Vector3.ZERO, false)


## A periscope head facing along yaw (0: forward).
static func _periscope(k: VehicleModels, p: Node3D, pos: Vector3, yaw := 0.0) -> void:
	k._box(p, Vector3(0.2, 0.1, 0.12), pos, "gunmetal_w", null, Vector3(0, yaw, 0))
	if not k.burnt:
		var f := Vector3(sin(yaw), 0, cos(yaw)) * -0.062
		k._box(p, Vector3(0.16, 0.06, 0.012), pos + f + Vector3(0, 0.005, 0), "glass", null, Vector3(0, yaw, 0), false)


## A bank of smoke dischargers on the side `s` (-1 left, +1 right), firing
## forward and outward.
static func _smoke(k: VehicleModels, p: Node3D, pos: Vector3, s: float, n := 3, yaw := 0.45) -> void:
	k._box(p, Vector3(0.16, 0.08, 0.1 + n * 0.12), pos + Vector3(0, -0.06, 0.05), "gunmetal_w", null, Vector3(0, s * -yaw, 0))
	for i in n:
		var o := Basis(Vector3.UP, s * -yaw) * Vector3(0, 0, -0.1 + i * 0.13)
		k._cyl(p, 0.045, 0.045, 0.26, pos + o + Vector3(0, 0.03, 0), Vector3(-0.9, s * -yaw, 0), "gunmetal_w", null, 8, false)


## A remote weapon station on the roof: the turntable, the cradle with a
## 12.7 mm HMG ("hmg"), a 40 mm grenade launcher ("gmg"), a 7.62 ("mmg") or a
## 30 mm cannon ("ac30"), the sight head with its windows, the ammunition box.
## Returns the traversing pivot; the muzzle is stored in k.mg_tip.
static func _rcws(k: VehicleModels, p: Node3D, pos: Vector3, gun: String, mat := CAM) -> Node3D:
	var t := k._pivot(p, pos)
	k._cyl(t, 0.3, 0.34, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, "gunmetal_w", null, 16)
	k._add(t, VehicleModels.loft("csat_rcws_ped", [-0.2, -0.22, 0.2, -0.22, 0.2, 0.26, -0.2, 0.26], [-0.16, -0.16, 0.16, -0.16, 0.16, 0.22, -0.16, 0.22], 0.1, 0.36), mat, null, Vector3.ZERO)
	# the trunnion arms either side of the cradle
	for sx in [-0.17, 0.17]:
		k._box(t, Vector3(0.05, 0.22, 0.24), Vector3(sx, 0.44, 0.0), mat)
	var y := 0.5
	match gun:
		"gmg":
			k._box(t, Vector3(0.24, 0.24, 0.62), Vector3(0, y, 0.0), "gunmetal_w")
			k._box(t, Vector3(0.2, 0.06, 0.4), Vector3(0, y + 0.15, 0.02), "gunmetal_w")
			k._cyl(t, 0.065, 0.065, 0.3, Vector3(0, y, -0.45), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
			k._cyl(t, 0.045, 0.045, 0.22, Vector3(0, y, -0.68), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
			k._cyl(t, 0.055, 0.055, 0.04, Vector3(0, y, -0.79), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
			k.mg_tip = k._tip(t, Vector3(0, y, -0.82))
		"ac30":
			k._box(t, Vector3(0.28, 0.26, 0.8), Vector3(0, y, 0.0), "gunmetal_w")
			k._cyl(t, 0.07, 0.07, 0.3, Vector3(0, y, -0.55), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
			k._cyl(t, 0.045, 0.04, 1.6, Vector3(0, y, -1.45), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
			k._cyl(t, 0.06, 0.06, 0.16, Vector3(0, y, -2.25), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
			k.mg_tip = k._tip(t, Vector3(0, y, -2.35))
		"mmg":
			k._box(t, Vector3(0.14, 0.18, 0.6), Vector3(0, y, 0.0), "gunmetal_w")
			k._cyl(t, 0.022, 0.02, 0.6, Vector3(0, y + 0.02, -0.6), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6)
			k.mg_tip = k._tip(t, Vector3(0, y + 0.02, -0.92))
		_:
			k._box(t, Vector3(0.18, 0.22, 0.78), Vector3(0, y, 0.02), "gunmetal_w")
			k._box(t, Vector3(0.1, 0.08, 0.3), Vector3(0, y + 0.13, -0.05), "gunmetal_w")
			k._cyl(t, 0.045, 0.045, 0.3, Vector3(0, y, -0.5), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
			k._cyl(t, 0.028, 0.026, 0.95, Vector3(0, y, -1.1), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
			k._cyl(t, 0.042, 0.042, 0.13, Vector3(0, y, -1.62), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
			k.mg_tip = k._tip(t, Vector3(0, y, -1.7))
	# the sight head beside the gun, the ammunition box on the other side
	k._box(t, Vector3(0.24, 0.26, 0.34), Vector3(0.33, y + 0.06, -0.02), mat)
	k._box(t, Vector3(0.22, 0.04, 0.3), Vector3(0.33, y + 0.2, -0.02), mat)
	if not k.burnt:
		k._box(t, Vector3(0.08, 0.08, 0.02), Vector3(0.28, y + 0.08, -0.2), "glass", null, Vector3.ZERO, false)
		k._box(t, Vector3(0.06, 0.06, 0.02), Vector3(0.39, y + 0.08, -0.2), "glass", null, Vector3.ZERO, false)
	k._box(t, Vector3(0.18, 0.26, 0.42), Vector3(-0.3, y - 0.02, 0.05), "paint", OLIVE)
	k._box(t, Vector3(0.12, 0.04, 0.16), Vector3(-0.21, y + 0.06, -0.08), "gunmetal_w", null, Vector3(0, 0, -0.5), false)
	return t


# --- Ifrit: ZiL Karatel ------------------------------------------------------------

## ZiL-4327 Karatel ("Punisher"): a faceted armoured body like a stealth
## fighter's - the long tapered bonnet between angular wheel arches, the
## steeply raked windscreen with its two small panes, upper sides leaning in
## hard over a near-vertical belt, small slit windows, the door seams, the rear
## door with the spare wheel beside it. `arm`: "" (unarmed: a roof hatch),
## "hmg" (RCWS 12.7 mm) or "gmg" (RCWS 40 mm).
static func _ifrit(k: VehicleModels, team: int, arm: String) -> void:
	var m := k.root
	var c := CAM
	# the V-shaped belly between the wheels
	k._add(m, VehicleModels.loft("csat_ifr_belly", [-0.3, -2.3, 0.3, -2.3, 0.3, 2.5, -0.3, 2.5], [-0.84, -2.55, 0.84, -2.55, 0.84, 2.8, -0.84, 2.8], 0.42, 1.02), c, null, Vector3.ZERO)
	# the faceted body: nose, bonnet, windscreen, cabin, rear face
	var body := [
		_sec(-3.17, 0.56, 1.02, 0.66, 1.06, 0.84, 1.24, 0.56, 1.3),
		_sec(-3.08, 0.62, 0.98, 0.72, 1.03, 0.94, 1.28, 0.64, 1.38),
		_sec(-1.3, 0.88, 0.98, 1.0, 1.03, 1.22, 1.5, 0.95, 1.75),
		_sec(-0.45, 0.88, 0.98, 1.0, 1.03, 1.22, 1.5, 0.8, 2.5),
		_sec(2.98, 0.88, 0.98, 1.0, 1.03, 1.22, 1.5, 0.8, 2.5),
		_sec(3.16, 0.84, 1.02, 0.96, 1.06, 1.15, 1.5, 0.75, 2.44)]
	k._add(m, VehicleModels.solid(body, "csat_ifr_body"), c, null, Vector3.ZERO)
	# the lower nose (grille and bumper) and the tail below the rear door
	k._add(m, VehicleModels.loft("csat_ifr_nose", [-0.78, -3.04, 0.78, -3.04, 0.78, -2.45, -0.78, -2.45], [-0.84, -3.19, 0.84, -3.19, 0.84, -2.42, -0.84, -2.42], 0.55, 1.03), c, null, Vector3.ZERO)
	k._add(m, VehicleModels.loft("csat_ifr_tail", [-0.86, 2.5, 0.86, 2.5, 0.86, 3.05, -0.86, 3.05], [-1.0, 2.45, 1.0, 2.45, 1.0, 3.15, -1.0, 3.15], 0.6, 1.03), c, null, Vector3.ZERO)
	# the door sills between the wheels, their ends cut to the arches
	var sill := [0.8, -0.98, 0.92, -0.98, 0.92, 1.05, 0.8, 1.05]
	var sill_t := [0.8, -1.26, 1.01, -1.26, 1.01, 1.32, 0.8, 1.32]
	k._add(m, VehicleModels.loft("csat_ifr_sill_r", sill, sill_t, 0.6, 1.02), c, null, Vector3.ZERO)
	k._add(m, VehicleModels.loft("csat_ifr_sill_l", _mx(sill), _mx(sill_t), 0.6, 1.02), c, null, Vector3.ZERO)
	# a raised panel down the bonnet and the air intake grille before the screen
	_plate(k, m, Vector3(0, 1.415, -2.95), Vector3(0, 1.735, -1.45), 0.62, 0.05, c)
	_pane(k, m, Vector3(0, 1.73, -1.62), Vector3(0, 0.37, 1.78), Vector2(1.05, 0.26), "gunmetal_w", null, 0.03)
	for i in 6:
		_pane(k, m, Vector3(-0.45 + i * 0.18, 1.745, -1.62), Vector3(0, 0.37, 1.78), Vector2(0.03, 0.24), c, null, 0.03)
	# the windscreen: two small panes in the raked front of the cabin
	var wu := Vector3(0, 0.75, 0.85)
	var wn := Vector3(0, 0.85, -0.75).normalized() * 0.016
	for s in [-1.0, 1.0]:
		_pane(k, m, Vector3(s * 0.38, 2.14, -0.86) + wn, wu, Vector2(0.56, 0.44), "glass")
		# A-pillar cover strips on the screen's facets
		_pane(k, m, Vector3(s * 0.84, 1.98, -0.92), Vector3(s * -0.15, 0.75, 0.85), Vector2(0.06, 0.95), c, null, 0.04)
	_pane(k, m, Vector3(0, 2.14, -0.86) + wn, wu, Vector2(0.12, 0.62), c, null, 0.05)
	# side windows, door seams and handles, the doors' steps
	for s in [-1.0, 1.0]:
		var up := Vector3(s * -0.4, 1.0, 0)
		var on := Vector3(s * 0.928, 0.371, 0) * 0.014
		for wz in [0.15, 1.3]:
			_pane(k, m, Vector3(s * 0.99, 2.02, wz) + on, up, Vector2(0.62, 0.36), "glass", null, 0.03, Vector3.BACK)
		for sz in [-0.4, 0.72, 1.86]:
			_pane(k, m, Vector3(s * 1.0, 2.0, sz) + on * 0.6, up, Vector2(0.025, 0.98), "gunmetal_w", null, 0.02, Vector3.BACK)
			_pane(k, m, Vector3(s * 1.12, 1.27, sz), Vector3(s * 0.22, 0.47, 0), Vector2(0.025, 0.48), "gunmetal_w", null, 0.02, Vector3.BACK)
		for hz in [0.55, 1.7]:
			k._box(m, Vector3(0.04, 0.05, 0.16), Vector3(s * 1.18, 1.38, hz), "gunmetal_w", null, Vector3.ZERO, false)
		for sz in [0.15, 1.3]:
			k._box(m, Vector3(0.24, 0.04, 0.42), Vector3(s * 1.0, 0.62, sz - 0.2), "gunmetal_w")
		# mirrors on stalks at the screen's base
		_tube(k, m, Vector3(s * 1.08, 1.62, -1.2), Vector3(s * 1.32, 1.82, -1.26), 0.018, "gunmetal_w", null, 6, false)
		k._box(m, Vector3(0.05, 0.26, 0.17), Vector3(s * 1.35, 1.88, -1.26), "gunmetal_w", null, Vector3(0, s * 0.2, 0))
		# angular arches over the wheels and mud flaps behind them
		for wz in [-1.85, 1.9]:
			_arch(k, m, s * 1.14, wz, 0.56, 0.2, 1.16)
			k._wheel(m, Vector3(s * 0.97, 0.55, wz), 0.55, 0.42)
		k._box(m, Vector3(0.4, 0.36, 0.02), Vector3(s * 0.97, 0.42, 2.58), "rubber", null, Vector3.ZERO, false)
		# headlight clusters in the wings, rear lights, tow hooks
		_headlight(k, m, Vector3(s * 0.66, 1.0, -3.2))
		_taillight(k, m, Vector3(s * 0.95, 1.22, 3.15))
		_tow(k, m, Vector3(s * 0.5, 0.62, -3.12), -1.0)
		# whip antennas at the rear roof corners
		_antenna(k, m, Vector3(s * 0.62, 2.5, 2.78), 2.1 if s > 0 else 1.6)
	# the grille, the bumper
	_pane(k, m, Vector3(0, 0.84, -3.12), Vector3(0, 0.47, -0.15), Vector2(0.8, 0.36), "gunmetal_w", null, 0.03)
	for i in 5:
		_pane(k, m, Vector3(0, 0.72 + i * 0.065, -3.115 - i * 0.02), Vector3(0, 0, 1), Vector2(0.76, 0.03), c, null, 0.04)
	k._box(m, Vector3(1.9, 0.18, 0.2), Vector3(0, 0.58, -3.08), "steel", Color(0.3, 0.29, 0.25))
	# the rear: the door with its window and hinges, the spare wheel, the step
	k._box(m, Vector3(0.8, 1.2, 0.04), Vector3(0.38, 1.66, 3.17), c)
	if not k.burnt:
		k._box(m, Vector3(0.36, 0.26, 0.02), Vector3(0.38, 1.98, 3.195), "glass", null, Vector3.ZERO, false)
	for hy in [1.25, 2.05]:
		k._box(m, Vector3(0.06, 0.12, 0.06), Vector3(0.78, hy, 3.19), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.05, 0.16, 0.05), Vector3(0.05, 1.6, 3.21), "gunmetal_w", null, Vector3.ZERO, false)
	var sp := k._pivot(m, Vector3(-0.5, 1.62, 3.38))
	k._cyl(sp, 0.52, 0.52, 0.36, Vector3.ZERO, Vector3(PI / 2, 0, 0), "rubber", null, 18)
	k._cyl(sp, 0.3, 0.3, 0.38, Vector3.ZERO, Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	k._cyl(sp, 0.12, 0.12, 0.42, Vector3.ZERO, Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._box(m, Vector3(0.5, 0.08, 0.12), Vector3(-0.5, 1.62, 3.2), "gunmetal_w")
	k._box(m, Vector3(1.7, 0.08, 0.3), Vector3(0, 0.66, 3.2), "steel", Color(0.3, 0.29, 0.25))
	_tow(k, m, Vector3(0, 0.75, 3.18), 1.0)
	# roof: rails, the hatch or the weapon station
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.04, 0.05, 1.6), Vector3(s * 0.68, 2.54, 1.95), "gunmetal_w")
		for rz in [1.25, 2.65]:
			k._box(m, Vector3(0.04, 0.05, 0.04), Vector3(s * 0.68, 2.515, rz), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.6, 0.18, 0.4), Vector3(0.3, 2.59, 1.95), "canvas", Color(0.34, 0.33, 0.25), Vector3(0, 0.1, 0))
	_hatch(k, m, Vector3(0, 2.5, 1.1), 0.32)
	if arm == "":
		_hatch(k, m, Vector3(0, 2.5, -0.05), 0.36)
		_periscope(k, m, Vector3(-0.45, 2.55, -0.35))
		_periscope(k, m, Vector3(0.45, 2.55, -0.35))
	else:
		_periscope(k, m, Vector3(-0.5, 2.55, -0.35))
		_periscope(k, m, Vector3(0.5, 2.55, -0.35))
		k.turret = _rcws(k, m, Vector3(0, 2.5, 0.05), arm)
	k._team_mark(m, team, Vector3(-0.2, 2.53, 2.65), Vector3(0.7, 0.02, 0.45))


# --- Qilin: ST Kinetics LSV Mk II --------------------------------------------------

## LSV Mk II: a low flat open body on big tyres, the short sloping nose with its
## grille and round lamps, a tubular roll cage over the crew carrying the
## weapon ring, the passengers' bench over the rear engine, the spare wheel and
## jerrycans on the tail. `arm`: "" (unarmed), "mg" (6.5 mm minigun) or "at"
## (Vorona missile launcher).
static func _qilin(k: VehicleModels, team: int, arm: String) -> void:
	var m := k.root
	var c := CAM
	# the belly pan and chassis rails
	k._box(m, Vector3(1.0, 0.14, 4.2), Vector3(0, 0.46, 0.1), "gunmetal_w")
	# the nose over the radiator: a sloping bonnet
	var nose := [
		_sec(-2.45, 0.42, 0.5, 0.54, 0.56, 0.57, 0.76, 0.5, 0.84),
		_sec(-2.36, 0.46, 0.46, 0.59, 0.52, 0.62, 0.8, 0.55, 0.92),
		_sec(-0.95, 0.6, 0.46, 0.7, 0.52, 0.74, 0.88, 0.7, 1.06)]
	k._add(m, VehicleModels.solid(nose, "csat_qil_nose"), c, null, Vector3.ZERO)
	# a vent in the bonnet before the screen
	var bn := Vector3(0, 1.41, -0.14)
	var bu := Vector3(0, 0.14, 1.41)
	_onface(k, m, Vector3(0, 1.015, -1.45), bn, bu, Vector3(0.7, 0.36, 0.02), "gunmetal_w", null, 0.0, false)
	for i in 4:
		_onface(k, m, Vector3(0, 1.006 + i * 0.008, -1.58 + i * 0.09), bn, bu, Vector3(0.66, 0.03, 0.03), c, null, 0.0, false)
	# the open crew tub: floor and low side walls, the rear engine deck
	k._box(m, Vector3(1.38, 0.1, 3.3), Vector3(0, 0.55, 0.75), c)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.06, 0.42, 1.6), Vector3(s * 0.69, 0.76, -0.15), c)
	k._add(m, VehicleModels.loft("csat_qil_deck", [-0.72, 0.8, 0.72, 0.8, 0.72, 2.42, -0.72, 2.42], [-0.7, 0.85, 0.7, 0.85, 0.7, 2.36, -0.7, 2.36], 0.5, 0.96), c, null, Vector3.ZERO)
	# the dash under the screen frame, the steering wheel, the seats
	k._box(m, Vector3(1.3, 0.22, 0.3), Vector3(0, 0.98, -0.82), "plain_dark")
	_tube(k, m, Vector3(-0.36, 0.85, -0.72), Vector3(-0.36, 1.02, -0.58), 0.025, "gunmetal_w", null, 6, false)
	k._cyl(m, 0.17, 0.17, 0.03, Vector3(-0.36, 1.04, -0.56), Vector3(-1.0, 0, 0), "plain_dark", null, 14, false)
	for sx in [-0.36, 0.36]:
		k._box(m, Vector3(0.44, 0.12, 0.44), Vector3(sx, 0.7, -0.15), "canvas", Color(0.24, 0.24, 0.2))
		k._box(m, Vector3(0.44, 0.52, 0.1), Vector3(sx, 0.98, 0.1), "canvas", Color(0.24, 0.24, 0.2), Vector3(-0.2, 0, 0))
	# the passengers' bench over the engine, back to back, facing out
	k._box(m, Vector3(0.08, 0.36, 1.2), Vector3(0, 1.16, 1.6), "canvas", Color(0.24, 0.24, 0.2))
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.4, 0.08, 1.2), Vector3(s * 0.25, 1.0, 1.6), "canvas", Color(0.24, 0.24, 0.2))
	# fenders: faceted mudguards over the wheels, steps between them
	for s in [-1.0, 1.0]:
		for wz in [-1.55, 1.5]:
			_arch(k, m, s * 0.87, wz, 0.43, 0.38, 0.98)
			k._wheel(m, Vector3(s * 0.86, 0.42, wz), 0.42, 0.3)
		k._box(m, Vector3(0.3, 0.06, 1.7), Vector3(s * 0.85, 0.62, 0.0), "gunmetal_w")
		k._box(m, Vector3(0.06, 0.2, 1.7), Vector3(s * 0.72, 0.62, 0.0), c)
		# round headlamps with guards, the indicators
		k._cyl(m, 0.09, 0.085, 0.08, Vector3(s * 0.48, 0.74, -2.46), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
		if not k.burnt:
			k._cyl(m, 0.065, 0.065, 0.02, Vector3(s * 0.48, 0.74, -2.51), Vector3(PI / 2, 0, 0), "plain", Color(0.85, 0.84, 0.76), 12, false)
		k._box(m, Vector3(0.015, 0.2, 0.015), Vector3(s * 0.48, 0.74, -2.56), "gunmetal_w", null, Vector3.ZERO, false)
		_taillight(k, m, Vector3(s * 0.55, 0.85, 2.43))
		# mirrors on the screen frame
		k._box(m, Vector3(0.04, 0.14, 0.12), Vector3(s * 0.82, 1.18, -0.92), "gunmetal_w")
	# exhaust out of the right rear
	k._cyl(m, 0.045, 0.045, 0.3, Vector3(0.62, 0.62, 2.45), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	# the grille and bull bar
	k._box(m, Vector3(0.6, 0.22, 0.03), Vector3(0, 0.7, -2.46), "gunmetal_w")
	for i in 4:
		k._box(m, Vector3(0.56, 0.02, 0.03), Vector3(0, 0.62 + i * 0.055, -2.475), c, null, Vector3.ZERO, false)
	_tube(k, m, Vector3(-0.66, 0.55, -2.58), Vector3(0.66, 0.55, -2.58), 0.04, "gunmetal_w")
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.32, 0.5, -2.45), Vector3(s * 0.32, 0.86, -2.6), 0.03, "gunmetal_w", null, 6)
		_tow(k, m, Vector3(s * 0.4, 0.45, -2.42), -1.0)
	_tube(k, m, Vector3(-0.32, 0.86, -2.6), Vector3(0.32, 0.86, -2.6), 0.03, "gunmetal_w", null, 6)
	# the spare wheel upright on the tail, jerrycans beside it
	var sp := k._pivot(m, Vector3(0, 0.98, 2.56))
	k._cyl(sp, 0.4, 0.4, 0.28, Vector3.ZERO, Vector3(PI / 2, 0, 0), "rubber", null, 18)
	k._cyl(sp, 0.23, 0.23, 0.3, Vector3.ZERO, Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	for s in [-1.0, 1.0]:
		_jerrycan(k, m, Vector3(s * 0.56, 1.2, 2.3), OLIVE, Vector3(0, PI / 2, 0))
	# the roll cage
	var r := 0.036
	for s in [-1.0, 1.0]:
		var a0 := Vector3(s * 0.68, 1.0, -0.95)
		var a1 := Vector3(s * 0.6, 1.66, -0.3)
		var b0 := Vector3(s * 0.69, 0.96, 0.55)
		var b1 := Vector3(s * 0.6, 1.72, 0.55)
		var c0 := Vector3(s * 0.66, 0.96, 1.85)
		var c1 := Vector3(s * 0.6, 1.4, 1.85)
		_tube(k, m, a0, a1, r, c)
		_tube(k, m, a1, b1, r, c)
		_tube(k, m, b0, b1, r, c)
		_tube(k, m, b1, c1, r, c)
		_tube(k, m, c0, c1, r, c)
		_tube(k, m, c1, Vector3(s * 0.62, 0.96, 2.4), r, c)
		_tube(k, m, b0, Vector3(s * 0.62, 1.42, 1.1), r * 0.8, c)
	_tube(k, m, Vector3(-0.6, 1.66, -0.3), Vector3(0.6, 1.66, -0.3), r, c)
	_tube(k, m, Vector3(-0.6, 1.72, 0.55), Vector3(0.6, 1.72, 0.55), r, c)
	_tube(k, m, Vector3(-0.6, 1.4, 1.85), Vector3(0.6, 1.4, 1.85), r, c)
	_tube(k, m, Vector3(-0.68, 1.04, -0.95), Vector3(0.68, 1.04, -0.95), r, c)
	_tube(k, m, Vector3(-0.6, 1.72, 0.55), Vector3(0.6, 0.96, 0.55), r * 0.8, c)
	# the weapon ring on the cage over the gunner's station
	var rc := Vector3(0, 1.72, 0.12)
	for i in 8:
		var a0 := TAU * i / 8.0
		var a1 := TAU * (i + 1) / 8.0
		_tube(k, m, rc + Vector3(cos(a0), 0, sin(a0)) * 0.36, rc + Vector3(cos(a1), 0, sin(a1)) * 0.36, 0.03, "gunmetal_w", null, 6)
	for s in [-1.0, 1.0]:
		_tube(k, m, rc + Vector3(s * 0.36, 0, 0), Vector3(s * 0.6, 1.7, 0.12), 0.03, "gunmetal_w", null, 6)
	_antenna(k, m, Vector3(-0.6, 1.4, 1.85), 1.8)
	k._team_mark(m, team, Vector3(0.725, 0.82, -0.5), Vector3(0.03, 0.16, 0.5))
	k._team_mark(m, team, Vector3(-0.725, 0.82, -0.5), Vector3(0.03, 0.16, 0.5))
	if arm == "":
		return
	var t := k._pivot(m, rc + Vector3(0, 0.02, 0))
	k.turret = t
	k._cyl(t, 0.05, 0.06, 0.32, Vector3(0, 0.16, 0), Vector3.ZERO, "gunmetal_w", null, 8)
	k._box(t, Vector3(0.12, 0.1, 0.2), Vector3(0, 0.34, 0), "gunmetal_w")
	if arm == "mg":
		# the minigun: six barrels round a spindle, the motor and feed chute
		var gy := 0.42
		k._box(t, Vector3(0.18, 0.18, 0.36), Vector3(0, gy, 0.02), "gunmetal_w")
		k._cyl(t, 0.07, 0.07, 0.12, Vector3(0, gy, -0.2), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
		for i in 6:
			var a := TAU * i / 6.0
			k._cyl(t, 0.012, 0.012, 0.62, Vector3(cos(a) * 0.04, gy + sin(a) * 0.04, -0.56), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 5, false)
		k._cyl(t, 0.06, 0.06, 0.03, Vector3(0, gy, -0.72), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
		k._cyl(t, 0.055, 0.055, 0.03, Vector3(0, gy, -0.86), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
		k._box(t, Vector3(0.04, 0.06, 0.24), Vector3(0, gy + 0.03, 0.25), "gunmetal_w", null, Vector3.ZERO, false)
		for s in [-1.0, 1.0]:
			k._box(t, Vector3(0.03, 0.12, 0.03), Vector3(s * 0.12, gy - 0.02, 0.26), "gunmetal_w", null, Vector3.ZERO, false)
		_plate(k, t, Vector3(0.1, gy, 0.1), Vector3(0.36, gy - 0.25, 0.25), 0.08, 0.03, "gunmetal_w", null, Vector3.BACK)
		k._box(t, Vector3(0.22, 0.24, 0.32), Vector3(0.42, gy - 0.32, 0.25), "paint", OLIVE)
		k.mg_tip = k._tip(t, Vector3(0, gy, -0.9))
	else:
		# the Vorona: a fat launch tube on a cradle, the thermal sight beside it
		var gy := 0.48
		k._box(t, Vector3(0.1, 0.16, 0.3), Vector3(0, gy - 0.08, 0.0), "gunmetal_w")
		k._cyl(t, 0.1, 0.1, 1.3, Vector3(0, gy + 0.04, -0.15), Vector3(PI / 2, 0, 0), "paint", OLIVE, 12)
		k._cyl(t, 0.115, 0.115, 0.08, Vector3(0, gy + 0.04, -0.78), Vector3(PI / 2, 0, 0), "paint", OLIVE.darkened(0.15), 12)
		k._cyl(t, 0.115, 0.115, 0.08, Vector3(0, gy + 0.04, 0.48), Vector3(PI / 2, 0, 0), "paint", OLIVE.darkened(0.15), 12)
		k._box(t, Vector3(0.2, 0.2, 0.3), Vector3(0.22, gy + 0.02, -0.1), "paint", OLIVE.darkened(0.1))
		if not k.burnt:
			k._cyl(t, 0.055, 0.055, 0.04, Vector3(0.22, gy + 0.03, -0.26), Vector3(PI / 2, 0, 0), "glass", null, 10, false)
		k._box(t, Vector3(0.05, 0.12, 0.12), Vector3(0.12, gy - 0.1, 0.25), "gunmetal_w")
		k.gun_tip = k._tip(t, Vector3(0, gy + 0.04, -0.85))
		k.mg_tip = k.gun_tip


# --- more shared helpers: faces, tracks --------------------------------------------

## A box lying on a face: `n` the face's outward normal, `ay` the in-face
## direction its height runs along, size (width, height, thickness). It sits
## on the face (pushed out by half its thickness); `psi` turns it in the face.
static func _onface(k: VehicleModels, p: Node3D, c: Vector3, n: Vector3, ay: Vector3, s: Vector3, mat: String, col = null, psi := 0.0, shadow := true) -> Variant:
	var z := n.normalized()
	var y := (ay - z * ay.dot(z)).normalized()
	var x := y.cross(z).normalized()
	if psi != 0.0:
		var x2 := x * cos(psi) + y * sin(psi)
		y = -x * sin(psi) + y * cos(psi)
		x = x2
	return k._add(p, Res.box(s), mat, col, c + z * s.z * 0.5, Basis(x, y, z).get_euler(), Vector3.ONE, shadow)


## A road wheel spinning about x: rubber tyre, painted disc, hub.
static func _rwheel(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, col := WHEEL_PAINT) -> Node3D:
	var pv := k._pivot(p, pos)
	var rx := Vector3(0, 0, PI / 2)
	k._cyl(pv, r, r, w, Vector3.ZERO, rx, "rubber", null, 18)
	k._cyl(pv, r * 0.84, r * 0.84, w + 0.03, Vector3.ZERO, rx, "paint", col, 18)
	k._cyl(pv, r * 0.22, r * 0.26, w + 0.1, Vector3.ZERO, rx, "gunmetal_w", null, 8, false)
	k.wheels.append(pv)
	return pv


## A toothed drive sprocket spinning about x.
static func _sprocket(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, col := WHEEL_PAINT) -> Node3D:
	var pv := k._pivot(p, pos)
	var rx := Vector3(0, 0, PI / 2)
	k._cyl(pv, r * 0.8, r * 0.8, w * 0.7, Vector3.ZERO, rx, "gunmetal_w", null, 16)
	for i in 8:
		var a := TAU * i / 8.0
		k._box(pv, Vector3(w * 0.6, 0.08, 0.12), Vector3(0, sin(a) * r * 0.86, cos(a) * r * 0.86), "gunmetal_w", null, Vector3(-a, 0, 0), false)
	k._cyl(pv, r * 0.5, r * 0.5, w * 0.7 + 0.06, Vector3.ZERO, rx, "paint", col, 12, false)
	k._cyl(pv, r * 0.2, r * 0.2, w * 0.7 + 0.12, Vector3.ZERO, rx, "gunmetal_w", null, 8, false)
	k.wheels.append(pv)
	return pv


## Tracked running gear on both sides at +-x: the track belt as a loop of
## plates round the front wheel `f` and the rear wheel `r` (each Vector3(z,
## y, radius)) and under the road wheels (at the z's in `road`, radius rr),
## the sprocket at the front or the rear, the idler at the other end, return
## rollers under the top run.
static func _running_gear(k: VehicleModels, p: Node3D, x: float, w: float, f: Vector3, r: Vector3, road: Array, rr: float, sprocket_front: bool, rollers: Array = []) -> void:
	var t := 0.08
	var pts: Array[Vector2] = []
	for i in 5:
		var a := deg_to_rad(90.0 + i * 37.5)
		pts.append(Vector2(f.x + cos(a) * (f.z + t), f.y + sin(a) * (f.z + t)))
	pts.append(Vector2(float(road[0]) - rr * 0.2, 0.0))
	pts.append(Vector2(float(road[road.size() - 1]) + rr * 0.2, 0.0))
	for i in 5:
		var a := deg_to_rad(-60.0 + i * 37.5)
		pts.append(Vector2(r.x + cos(a) * (r.z + t), r.y + sin(a) * (r.z + t)))
	var cen := Vector2.ZERO
	for q in pts:
		cen += q
	cen /= pts.size()
	var top_y := maxf(f.y + f.z, r.y + r.z)
	for s in [-1.0, 1.0]:
		for i in pts.size():
			var a2: Vector2 = pts[i]
			var b2: Vector2 = pts[(i + 1) % pts.size()]
			var d := b2 - a2
			var mid := (a2 + b2) * 0.5
			var nn := Vector2(d.y, -d.x).normalized()
			if nn.dot(mid - cen) < 0.0:
				nn = -nn
			var cc := mid - nn * t * 0.5
			k._box(p, Vector3(w, t, d.length() + t * 0.7), Vector3(s * x, cc.y, cc.x), "track", null, Vector3(atan2(-d.y, d.x), 0, 0))
		for z in road:
			_rwheel(k, p, Vector3(s * x, rr + t, z), rr, w * 0.72)
		for z in rollers:
			k._cyl(p, 0.09, 0.09, w * 0.5, Vector3(s * x, top_y - 0.09, z), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10, false)
		if sprocket_front:
			_sprocket(k, p, Vector3(s * x, f.y, f.x), f.z, w)
			_rwheel(k, p, Vector3(s * x, r.y, r.x), r.z, w * 0.72)
		else:
			_rwheel(k, p, Vector3(s * x, f.y, f.x), f.z, w * 0.72)
			_sprocket(k, p, Vector3(s * x, r.y, r.x), r.z, w)


## A block of reactive armour bricks on a face: rows x cols bricks of size
## `b`, centred on c, the face given by its normal n and up direction ay.
static func _era(k: VehicleModels, p: Node3D, c: Vector3, n: Vector3, ay: Vector3, rows: int, cols: int, b: Vector3, psi := 0.0, mat := CAM) -> void:
	var z := n.normalized()
	var y := (ay - z * ay.dot(z)).normalized()
	var x := y.cross(z).normalized()
	if psi != 0.0:
		var x2 := x * cos(psi) + y * sin(psi)
		y = -x * sin(psi) + y * cos(psi)
		x = x2
	for i in rows:
		for j in cols:
			var o := x * (j - (cols - 1) * 0.5) * (b.x + 0.025) + y * (i - (rows - 1) * 0.5) * (b.y + 0.025)
			k._add(p, Res.box(b), mat, null, c + o + z * b.z * 0.5, Basis(x, y, z).get_euler())


# --- Marid: Otokar Arma 6x6 --------------------------------------------------------

## Otokar Arma 6x6: a tall boxy hull with a sharp wedge nose, a long glacis
## with the driver's windows at its top, upper sides leaning in over a crease
## that runs the length of the hull, the lower hull narrowing into a V between
## six evenly spaced wheels, the rear ramp with its door and the water jets,
## and twin remote weapon stations (12.7 mm and 40 mm) side by side on the roof.
static func _marid(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := CAM
	var hull := [
		_sec(-3.5, 0.82, 1.04, 1.18, 1.1, 1.3, 1.24, 1.08, 1.32),
		_sec(-2.85, 0.8, 0.5, 0.98, 1.18, 1.45, 1.42, 1.15, 1.7),
		_sec(-2.0, 0.8, 0.5, 0.98, 1.2, 1.45, 1.42, 1.15, 2.2),
		_sec(3.3, 0.8, 0.5, 0.98, 1.2, 1.45, 1.42, 1.15, 2.2),
		_sec(3.5, 0.76, 0.58, 0.94, 1.22, 1.4, 1.42, 1.1, 2.14)]
	k._add(m, VehicleModels.solid(hull, "csat_marid_hull"), c, null, Vector3.ZERO)
	# the glacis plane (for things mounted on it)
	var gu := Vector3(0, 0.5, 0.85).normalized()
	var gn := Vector3(0, 0.85, -0.5).normalized()
	# the driver's windows at the top of the glacis, front left, and his hatch
	for wx in [-0.88, -0.4]:
		_onface(k, m, Vector3(wx, 1.97, -2.4), gn, gu, Vector3(0.4, 0.3, 0.03), "glass", null, 0.0, false)
	_onface(k, m, Vector3(-0.64, 2.0, -2.35), gn, gu, Vector3(1.0, 0.42, 0.02), "gunmetal_w", null, 0.0, false)
	_hatch(k, m, Vector3(-0.62, 2.2, -1.55), 0.3)
	_hatch(k, m, Vector3(0.62, 2.2, -1.55), 0.3)
	_periscope(k, m, Vector3(0.62, 2.25, -1.95))
	# the engine's louvres on the right of the glacis, exhaust on the right side
	_onface(k, m, Vector3(0.62, 1.72, -2.84), gn, gu, Vector3(0.82, 0.66, 0.02), "gunmetal_w", null, 0.0, false)
	for i in 5:
		_onface(k, m, Vector3(0.62, 1.6 + i * 0.06, -3.04 + i * 0.1), gn, gu, Vector3(0.78, 0.035, 0.04), c, null, 0.0, false)
	# headlight clusters and tow hooks on the nose, smoke dischargers
	for s in [-1.0, 1.0]:
		_headlight(k, m, Vector3(s * 1.0, 1.42, -3.36))
		_tow(k, m, Vector3(s * 0.55, 1.0, -3.5), -1.0)
		_smoke(k, m, Vector3(s * 1.0, 2.28, -1.85), s, 4, 0.5)
	# the wheels on three evenly spaced axles, mud flaps
	for s in [-1.0, 1.0]:
		for wz in [-2.0, -0.2, 1.6]:
			k._wheel(m, Vector3(s * 1.15, 0.6, wz), 0.6, 0.46)
		k._box(m, Vector3(0.44, 0.4, 0.02), Vector3(s * 1.15, 0.5, 2.3), "rubber", null, Vector3.ZERO, false)
	# the crease's side: vision blocks and firing ports along the troop
	# compartment, stowage boxes, the exhaust
	var su := Vector3(-0.3, 0.78, 0)
	for s in [-1.0, 1.0]:
		var sn := Vector3(s * 0.933, 0.359, 0)
		var sup := Vector3(s * su.x, su.y, 0)
		for vz in [0.35, 1.25, 2.15]:
			_onface(k, m, Vector3(s * 1.285, 1.86, vz), sn, sup, Vector3(0.24, 0.2, 0.03), "glass", null, 0.0, false)
			_onface(k, m, Vector3(s * 1.285, 1.86, vz), sn, sup, Vector3(0.34, 0.3, 0.015), "gunmetal_w", null, 0.0, false)
			k._cyl(m, 0.05, 0.06, 0.06, Vector3(s * 1.41, 1.5, vz + 0.35), Vector3(0, 0, s * (PI / 2 - 0.37)), "gunmetal_w", null, 8, false)
		_onface(k, m, Vector3(s * 1.3, 1.82, -1.2), sn, sup, Vector3(0.9, 0.5, 0.16), c)
		# grab rails along the roof edge
		k._box(m, Vector3(0.04, 0.04, 2.6), Vector3(s * 1.1, 2.24, 1.6), "gunmetal_w")
	k._box(m, Vector3(0.12, 0.36, 0.6), Vector3(1.38, 1.66, -0.5), "gunmetal_w", null, Vector3(0, 0, -0.37))
	# rear: the ramp with its door, hinges, water jets, lights, stowage
	k._box(m, Vector3(1.7, 1.45, 0.05), Vector3(0, 1.38, 3.5), c)
	k._box(m, Vector3(0.62, 1.15, 0.03), Vector3(0.38, 1.5, 3.535), c)
	if not k.burnt:
		k._box(m, Vector3(0.22, 0.18, 0.02), Vector3(0.38, 1.82, 3.555), "glass", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.05, 0.16, 0.05), Vector3(0.12, 1.5, 3.56), "gunmetal_w", null, Vector3.ZERO, false)
	for hx in [-0.6, 0.6]:
		k._cyl(m, 0.06, 0.06, 0.3, Vector3(hx, 0.7, 3.5), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
	for s in [-1.0, 1.0]:
		k._cyl(m, 0.17, 0.2, 0.18, Vector3(s * 1.08, 0.86, 3.44), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
		k._cyl(m, 0.12, 0.12, 0.2, Vector3(s * 1.08, 0.86, 3.46), Vector3(PI / 2, 0, 0), "rubber", null, 10, false)
		_taillight(k, m, Vector3(s * 1.08, 1.9, 3.48))
		_tow(k, m, Vector3(s * 0.55, 0.62, 3.45), 1.0)
		_antenna(k, m, Vector3(s * 0.95, 2.2, 3.0), 2.2 if s < 0 else 1.7)
		_jerrycan(k, m, Vector3(s * 1.08, 1.35, 3.62), OLIVE, Vector3(0, PI / 2, 0))
	# roof: the troop compartment's hatches, a stowage basket
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.62, 0.06, 0.8), Vector3(s * 0.48, 2.23, 1.9), c)
		k._box(m, Vector3(0.1, 0.05, 0.14), Vector3(s * 0.48, 2.28, 1.55), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(1.4, 0.05, 0.7), Vector3(0, 2.23, 2.95), "gunmetal_w")
	k._box(m, Vector3(0.7, 0.26, 0.5), Vector3(-0.3, 2.37, 2.95), "canvas", Color(0.33, 0.33, 0.24), Vector3(0, 0.1, 0))
	k._box(m, Vector3(0.45, 0.22, 0.4), Vector3(0.35, 2.35, 3.0), "paint", OLIVE)
	k._team_mark(m, team, Vector3(0, 2.235, 0.85), Vector3(0.7, 0.02, 0.5))
	# twin remote weapon stations on one ring: the 12.7 mm on the left, the
	# 40 mm on the right, the sight head between them
	var t := k._pivot(m, Vector3(0, 2.2, -0.45))
	k.turret = t
	k._cyl(t, 0.52, 0.56, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, "gunmetal_w", null, 18)
	k._add(t, VehicleModels.loft("csat_marid_rws", [-0.42, -0.36, 0.42, -0.36, 0.46, 0.3, -0.46, 0.3], [-0.36, -0.28, 0.36, -0.28, 0.4, 0.24, -0.4, 0.24], 0.1, 0.34), c, null, Vector3.ZERO)
	var y := 0.52
	k._box(t, Vector3(0.26, 0.3, 0.36), Vector3(0, y + 0.02, -0.08), c)
	if not k.burnt:
		k._box(t, Vector3(0.09, 0.09, 0.02), Vector3(-0.06, y + 0.05, -0.27), "glass", null, Vector3.ZERO, false)
		k._box(t, Vector3(0.07, 0.07, 0.02), Vector3(0.07, y + 0.05, -0.27), "glass", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.05, 0.24, 0.3), Vector3(s * 0.15, y - 0.06, 0.0), c)
	# 12.7 mm, left
	k._box(t, Vector3(0.17, 0.2, 0.74), Vector3(-0.3, y, 0.0), "gunmetal_w")
	k._cyl(t, 0.042, 0.042, 0.3, Vector3(-0.3, y, -0.5), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._cyl(t, 0.028, 0.026, 0.9, Vector3(-0.3, y, -1.08), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._cyl(t, 0.042, 0.042, 0.12, Vector3(-0.3, y, -1.58), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._box(t, Vector3(0.16, 0.24, 0.4), Vector3(-0.5, y - 0.02, 0.04), "paint", OLIVE)
	# 40 mm, right
	k._box(t, Vector3(0.22, 0.24, 0.58), Vector3(0.3, y, 0.02), "gunmetal_w")
	k._cyl(t, 0.062, 0.062, 0.28, Vector3(0.3, y, -0.4), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k._cyl(t, 0.043, 0.043, 0.22, Vector3(0.3, y, -0.62), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k._box(t, Vector3(0.18, 0.28, 0.42), Vector3(0.52, y - 0.02, 0.04), "paint", OLIVE)
	k.mg_tip = k._tip(t, Vector3(0.3, y, -0.75))
	k.gun_tip = k._tip(t, Vector3(-0.3, y, -1.66))


# --- Kamysh and Tigris: BM-2T Stalker -----------------------------------------------

## BM-2T Stalker: a long, low, faceted hull - the sharp nose, a long shallow
## glacis over the front engine, upper sides leaning in hard over the side
## skirts, the rear door - on six road wheels a side, the sprocket at the
## front. Returns the turret ring's centre.
static func _stalker(k: VehicleModels, team: int) -> Vector3:
	var m := k.root
	var c := CAM
	var hull := [
		_sec(-3.88, 0.9, 0.88, 1.0, 0.94, 1.5, 1.02, 1.18, 1.07),
		_sec(-3.42, 1.02, 0.42, 1.08, 0.95, 1.7, 1.1, 1.3, 1.3),
		_sec(-2.3, 1.02, 0.42, 1.08, 0.95, 1.7, 1.1, 1.24, 1.72),
		_sec(3.5, 1.02, 0.42, 1.08, 0.95, 1.7, 1.1, 1.24, 1.72),
		_sec(3.86, 0.98, 0.58, 1.06, 0.95, 1.62, 1.1, 1.16, 1.6)]
	k._add(m, VehicleModels.solid(hull, "csat_stalker_hull"), c, null, Vector3.ZERO)
	_running_gear(k, m, 1.36, 0.56, Vector3(-3.32, 0.58, 0.27), Vector3(3.3, 0.56, 0.27), [-2.45, -1.45, -0.45, 0.55, 1.55, 2.55], 0.33, true, [-1.95, 0.05, 2.05])
	# side skirts in bolted sections, the front one angled up toward the sprocket
	for s in [-1.0, 1.0]:
		for i in 5:
			k._box(m, Vector3(0.06, 0.54, 1.3), Vector3(s * 1.69, 0.84, -2.15 + i * 1.33), c, null, Vector3(0, 0, s * -0.1))
			k._box(m, Vector3(0.08, 0.04, 0.05), Vector3(s * 1.72, 1.04, -2.62 + i * 1.33), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.06, 0.4, 0.75), Vector3(s * 1.66, 0.9, -3.15), c, null, Vector3(-0.45, 0, s * -0.1))
	# the glacis: driver's hatch and periscopes front left, engine louvres
	# front right, headlights in guards at the corners, tow hooks on the nose
	var gu := Vector3(0, 0.42, 1.12).normalized()
	var gn := Vector3(0, 1.12, -0.42).normalized()
	_hatch(k, m, Vector3(-0.62, 1.72, -2.0), 0.3)
	for i in 3:
		_periscope(k, m, Vector3(-0.92 + i * 0.3, 1.73, -2.38), (i - 1) * 0.35)
	_onface(k, m, Vector3(0.55, 1.42, -3.0), gn, gu, Vector3(1.0, 0.9, 0.02), "gunmetal_w", null, 0.0, false)
	for i in 6:
		_onface(k, m, Vector3(0.55, 1.29 + i * 0.054, -3.34 + i * 0.145), gn, gu, Vector3(0.94, 0.04, 0.04), c, null, 0.0, false)
	for s in [-1.0, 1.0]:
		_headlight(k, m, Vector3(s * 1.28, 1.22, -3.42))
		_tow(k, m, Vector3(s * 0.6, 0.86, -3.84), -1.0)
	_onface(k, m, Vector3(0, 1.2, -3.55), gn, gu, Vector3(1.6, 0.16, 0.06), "gunmetal_w")
	# upper sides: stowage boxes and vision blocks, the exhaust on the right
	var su := Vector3(-0.46, 0.62, 0)
	for s in [-1.0, 1.0]:
		var sn := Vector3(s * 0.62, 0.46, 0).normalized()
		var sup := Vector3(s * su.x, su.y, 0)
		_onface(k, m, Vector3(s * 1.47, 1.41, 1.8), sn, sup, Vector3(1.6, 0.42, 0.18), c)
		_onface(k, m, Vector3(s * 1.47, 1.41, -0.9), sn, sup, Vector3(0.7, 0.36, 0.14), c)
		for vz in [0.6, 1.2]:
			_onface(k, m, Vector3(s * 1.43, 1.46, vz), sn, sup, Vector3(0.18, 0.14, 0.03), "glass", null, 0.0, false)
	_onface(k, m, Vector3(1.45, 1.43, -1.85), Vector3(0.62, 0.46, 0).normalized(), Vector3(-0.46, 0.62, 0), Vector3(0.6, 0.3, 0.08), "gunmetal_w")
	# the rear: the troop door, its hinges and vision block, lights, stowage
	k._box(m, Vector3(0.9, 0.95, 0.05), Vector3(0, 1.08, 3.84), c)
	if not k.burnt:
		k._box(m, Vector3(0.2, 0.12, 0.02), Vector3(0, 1.38, 3.87), "glass", null, Vector3.ZERO, false)
	for hy in [0.78, 1.36]:
		k._box(m, Vector3(0.06, 0.1, 0.06), Vector3(-0.47, hy, 3.86), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.05, 0.14, 0.05), Vector3(0.36, 1.1, 3.88), "gunmetal_w", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		_taillight(k, m, Vector3(s * 1.25, 1.35, 3.76))
		_tow(k, m, Vector3(s * 0.75, 0.75, 3.86), 1.0)
		k._box(m, Vector3(0.55, 0.5, 0.3), Vector3(s * 1.0, 1.25, 3.95), "steel", Color(0.32, 0.31, 0.25))
		_antenna(k, m, Vector3(s * 0.95, 1.72, 3.3), 2.2 if s < 0 else 1.6)
	# roof: the troop compartment's hatches behind the turret
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.6, 0.05, 0.75), Vector3(s * 0.48, 1.74, 2.4), c)
		k._box(m, Vector3(0.12, 0.04, 0.12), Vector3(s * 0.48, 1.78, 2.08), "gunmetal_w", null, Vector3.ZERO, false)
	k._team_mark(m, team, Vector3(0, 1.735, 3.3), Vector3(0.7, 0.02, 0.4))
	return Vector3(0, 1.72, -0.35)


## BTR-K Kamysh: the Stalker with a Samson RCWS-30 style unmanned turret - a
## low faceted box with the 30 mm cannon, the sight heads on its roof and a
## twin Titan launcher on each side.
static func _kamysh(k: VehicleModels, team: int) -> void:
	var c := CAM
	var t := k._pivot(k.root, _stalker(k, team))
	k.turret = t
	k._cyl(t, 0.95, 1.0, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, c, null, 20)
	k._add(t, VehicleModels.loft("csat_kam_tur", [-0.62, -1.15, 0.62, -1.15, 0.95, -0.6, 0.95, 1.05, -0.95, 1.05, -0.95, -0.6],
		[-0.5, -0.88, 0.5, -0.88, 0.8, -0.45, 0.8, 0.92, -0.8, 0.92, -0.8, -0.45], 0.08, 0.62), c, null, Vector3.ZERO)
	# the bustle box at the back
	k._box(t, Vector3(1.5, 0.42, 0.42), Vector3(0, 0.33, 1.15), c)
	# mantlet, the 30 mm with its barrel jacket and muzzle brake, the coax
	k._box(t, Vector3(0.42, 0.36, 0.3), Vector3(0.08, 0.36, -1.18), c)
	k._cyl(t, 0.075, 0.075, 0.5, Vector3(0.08, 0.36, -1.55), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k._cyl(t, 0.048, 0.042, 1.9, Vector3(0.08, 0.36, -2.7), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._cyl(t, 0.065, 0.065, 0.2, Vector3(0.08, 0.36, -3.68), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k.mg_tip = k._tip(t, Vector3(0.08, 0.36, -3.8))
	k._cyl(t, 0.022, 0.022, 0.35, Vector3(-0.2, 0.3, -1.4), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	# the gunner's sight head (front left) and the commander's panoramic sight
	k._box(t, Vector3(0.34, 0.3, 0.42), Vector3(-0.42, 0.77, -0.45), c)
	if not k.burnt:
		k._box(t, Vector3(0.12, 0.12, 0.02), Vector3(-0.48, 0.79, -0.67), "glass", null, Vector3.ZERO, false)
		k._box(t, Vector3(0.08, 0.08, 0.02), Vector3(-0.33, 0.79, -0.67), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.1, 0.12, 0.3, Vector3(0.45, 0.77, 0.3), Vector3.ZERO, "gunmetal_w", null, 10)
	k._box(t, Vector3(0.3, 0.24, 0.3), Vector3(0.45, 1.02, 0.3), c)
	if not k.burnt:
		k._box(t, Vector3(0.18, 0.1, 0.02), Vector3(0.45, 1.03, 0.14), "glass", null, Vector3.ZERO, false)
	# the twin Titan launchers on arms either side, smoke dischargers behind
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.25, 0.14, 0.3), Vector3(s * 0.98, 0.42, 0.05), "gunmetal_w")
		k._box(t, Vector3(0.32, 0.6, 1.35), Vector3(s * 1.2, 0.5, -0.15), "paint", OLIVE)
		for ty in [0.36, 0.64]:
			k._cyl(t, 0.1, 0.1, 1.38, Vector3(s * 1.2, ty, -0.15), Vector3(PI / 2, 0, 0), "paint", OLIVE.darkened(0.1), 12)
			k._cyl(t, 0.075, 0.075, 1.4, Vector3(s * 1.2, ty, -0.15), Vector3(PI / 2, 0, 0), "plain_dark", null, 10, false)
		_smoke(k, t, Vector3(s * 0.85, 0.55, 0.65), s, 3, 1.2)
	_antenna(k, t, Vector3(-0.6, 0.62, 0.9), 1.6)


## ZSU-39 Tigris: the Stalker with a Marconi Marksman turret - a big boxy
## turret with a 35 mm cannon on each side, the tracking radar between them at
## the front, the search radar on its mast at the back, missile boxes on top.
static func _tigris(k: VehicleModels, team: int) -> void:
	var c := CAM
	var t := k._pivot(k.root, _stalker(k, team))
	k.turret = t
	k._cyl(t, 1.0, 1.05, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, c, null, 20)
	k._add(t, VehicleModels.loft("csat_tig_tur", [-0.95, -1.35, 0.95, -1.35, 1.2, -0.95, 1.2, 1.35, -1.2, 1.35, -1.2, -0.95],
		[-0.8, -0.95, 0.8, -0.95, 1.05, -0.7, 1.05, 1.2, -1.05, 1.2, -1.05, -0.7], 0.08, 1.05), c, null, Vector3.ZERO)
	# the guns: a 35 mm in a cradle on each side, ammunition feed fairings
	for s in [-1.0, 1.0]:
		var gx: float = s * 1.42
		k._box(t, Vector3(0.16, 0.3, 0.5), Vector3(s * 1.22, 0.6, -0.3), "gunmetal_w")
		k._box(t, Vector3(0.3, 0.42, 1.5), Vector3(gx, 0.6, -0.35), c)
		k._box(t, Vector3(0.26, 0.2, 0.6), Vector3(gx, 0.6, 0.6), c)
		k._cyl(t, 0.07, 0.07, 0.4, Vector3(gx, 0.62, -1.28), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
		k._cyl(t, 0.046, 0.04, 2.4, Vector3(gx, 0.62, -2.6), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
		k._cyl(t, 0.06, 0.06, 0.26, Vector3(gx, 0.62, -3.86), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
		k._box(t, Vector3(0.12, 0.1, 0.16), Vector3(gx, 0.75, -1.15), "gunmetal_w")
		_smoke(k, t, Vector3(s * 1.0, 0.95, 0.9), s, 3, 1.3)
	k.mg_tip = k._tip(t, Vector3(1.42, 0.62, -4.0))
	k.gun_tip = k._tip(t, Vector3(-1.42, 0.62, -4.0))
	# the tracking radar in its housing on the front of the roof
	k._box(t, Vector3(0.7, 0.45, 0.5), Vector3(0, 1.25, -0.55), c)
	k._cyl(t, 0.3, 0.3, 0.06, Vector3(0, 1.27, -0.83), Vector3(PI / 2, 0, 0), "plain_dark", null, 16)
	# the optical sight beside it
	k._box(t, Vector3(0.3, 0.3, 0.36), Vector3(-0.6, 1.2, -0.4), c)
	if not k.burnt:
		k._box(t, Vector3(0.18, 0.14, 0.02), Vector3(-0.6, 1.22, -0.59), "glass", null, Vector3.ZERO, false)
	# the search radar: a flat antenna on a mast at the back
	k._cyl(t, 0.12, 0.15, 0.5, Vector3(0, 1.3, 0.75), Vector3.ZERO, "gunmetal_w", null, 10)
	k._box(t, Vector3(0.3, 0.12, 0.3), Vector3(0, 1.58, 0.75), "gunmetal_w")
	k._box(t, Vector3(1.5, 0.55, 0.1), Vector3(0, 1.85, 0.78), "paint", Color(0.36, 0.35, 0.3), Vector3(-0.25, 0, 0))
	# twin missile boxes either side of the mast
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.12, 0.2, 0.3), Vector3(s * 0.72, 1.15, 0.5), "gunmetal_w")
		k._box(t, Vector3(0.36, 0.34, 1.15), Vector3(s * 0.72, 1.4, 0.35), "paint", OLIVE)
		for mx in [-0.085, 0.085]:
			k._cyl(t, 0.065, 0.065, 0.02, Vector3(s * 0.72 + mx, 1.4, -0.235), Vector3(PI / 2, 0, 0), "plain_dark", null, 10, false)
	_hatch(k, t, Vector3(0.55, 1.05, 0.2), 0.25)


# --- Varsuk, Futura, Sochor: the T-100 hull ----------------------------------------

const GUN_PAINT := Color(0.43, 0.39, 0.3)


## T-100 hull (Object 640 / T-80 lineage): the long shallow upper glacis faced
## with a chevron of reactive armour, the lower glacis under the nose, the low
## hull between fender shelves, side skirts with ERA on their front half, the
## engine deck with its grilles and the turbine's wide exhaust at the back;
## seven road wheels a side, the sprocket at the rear. Returns the turret
## ring's centre.
static func _t100(k: VehicleModels, team: int) -> Vector3:
	var m := k.root
	var c := CAM
	var hull := [
		_sec(-3.75, 1.0, 0.9, 1.08, 0.95, 1.56, 0.99, 1.52, 1.02),
		_sec(-3.3, 1.04, 0.42, 1.08, 0.95, 1.62, 1.02, 1.58, 1.16),
		_sec(-2.2, 1.04, 0.42, 1.08, 0.95, 1.62, 1.02, 1.58, 1.5),
		_sec(3.55, 1.04, 0.42, 1.08, 0.95, 1.62, 1.02, 1.58, 1.5),
		_sec(3.75, 1.0, 0.6, 1.06, 0.95, 1.6, 1.02, 1.55, 1.36)]
	k._add(m, VehicleModels.solid(hull, "csat_t100_hull"), c, null, Vector3.ZERO)
	_running_gear(k, m, 1.33, 0.58, Vector3(-3.3, 0.55, 0.27), Vector3(3.36, 0.56, 0.29), [-2.55, -1.7, -0.85, 0.0, 0.85, 1.7, 2.55], 0.33, false, [-2.1, -0.42, 1.27])
	# the glacis: a chevron of reactive armour plates, the driver's hatch and
	# periscope at its top, headlights at its corners, tow hooks on the nose
	var gu := Vector3(0, 0.48, 1.55).normalized()
	var gn := Vector3(0, 1.55, -0.48).normalized()
	var g0 := Vector3(0, 1.02, -3.75)
	for s in [-1.0, 1.0]:
		for i in 3:
			var d := 0.28 + i * 0.44
			_onface(k, m, g0 + gu * d + Vector3(s * 0.56, 0, 0), gn, gu, Vector3(0.92, 0.4, 0.1), c, null, s * 0.24)
		_headlight(k, m, Vector3(s * 1.36, 1.2, -3.2))
		_tow(k, m, Vector3(s * 0.75, 0.84, -3.76), -1.0)
		# fender shelves, the front mudguards
		k._box(m, Vector3(0.24, 0.05, 7.4), Vector3(s * 1.7, 1.03, 0.05), c)
		_plate(k, m, Vector3(s * 1.7, 1.02, -3.62), Vector3(s * 1.7, 0.8, -3.95), 0.26, 0.04, c)
	_onface(k, m, g0 + gu * 1.45, gn, gu, Vector3(0.7, 0.24, 0.05), c)
	_hatch(k, m, Vector3(0, 1.5, -2.02), 0.27)
	_periscope(k, m, Vector3(0, 1.5, -2.36))
	# side skirts: reactive armour on the front three sections, rubber behind
	for s in [-1.0, 1.0]:
		for i in 6:
			var z := -2.95 + i * 1.12
			if i < 3:
				k._box(m, Vector3(0.06, 0.5, 1.08), Vector3(s * 1.79, 0.8, z), c)
				_era(k, m, Vector3(s * 1.82, 0.8, z), Vector3(s, 0, 0), Vector3.UP, 1, 3, Vector3(0.32, 0.44, 0.1))
			else:
				k._box(m, Vector3(0.05, 0.52, 1.08), Vector3(s * 1.79, 0.79, z), "rubber")
				k._box(m, Vector3(0.07, 0.04, 1.08), Vector3(s * 1.8, 1.0, z), "gunmetal_w", null, Vector3.ZERO, false)
		# stowage along the fenders behind the turret: bins left, fuel tanks right
		if s < 0.0:
			for i in 3:
				k._box(m, Vector3(0.26, 0.36, 0.62), Vector3(s * 1.66, 1.23, 1.6 + i * 0.68), c)
		else:
			for i in 3:
				k._cyl(m, 0.2, 0.2, 0.6, Vector3(s * 1.66, 1.25, 1.6 + i * 0.68), Vector3(PI / 2, 0, 0), "steel", Color(0.33, 0.32, 0.25), 12)
	# engine deck: grilles and the access panels
	k._box(m, Vector3(2.3, 0.04, 1.4), Vector3(0, 1.51, 2.6), "gunmetal_w")
	for i in 6:
		k._box(m, Vector3(2.2, 0.03, 0.05), Vector3(0, 1.535, 2.0 + i * 0.24), c, null, Vector3.ZERO, false)
	k._box(m, Vector3(1.0, 0.04, 0.8), Vector3(0, 1.51, 1.45), c)
	# the rear: the turbine's exhaust grille, the unditching beam, lights, hooks
	k._box(m, Vector3(1.5, 0.3, 0.06), Vector3(0, 1.16, 3.76), "gunmetal_w", null, Vector3(-0.3, 0, 0))
	k._cyl(m, 0.13, 0.13, 2.8, Vector3(0, 1.62, 3.5), Vector3(0, 0, PI / 2), "bark")
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.08, 0.2, 0.2), Vector3(s * 1.45, 1.6, 3.5), "gunmetal_w")
		_taillight(k, m, Vector3(s * 1.38, 1.12, 3.74))
		_tow(k, m, Vector3(s * 0.75, 0.78, 3.76), 1.0)
	return Vector3(0, 1.5, -0.2)


## A 125 mm gun along -z from z0 at height y on parent p (under a turret):
## the barrel with its thermal sleeve bands, the fume extractor, the muzzle
## and its reference sensor. Returns the muzzle marker.
static func _gun125(k: VehicleModels, p: Node3D, y: float, z0: float, length: float, extractor := true) -> Node3D:
	var zc := z0 - length * 0.5
	k._cyl(p, 0.105, 0.088, length, Vector3(0, y, zc), Vector3(PI / 2, 0, 0), "paint", GUN_PAINT, 12)
	for i in 4:
		k._cyl(p, 0.112, 0.112, 0.05, Vector3(0, y, z0 - 0.4 - i * length * 0.2), Vector3(PI / 2, 0, 0), "paint", GUN_PAINT.darkened(0.15), 12, false)
	if extractor:
		k._cyl(p, 0.15, 0.15, 0.62, Vector3(0, y, z0 - length * 0.58), Vector3(PI / 2, 0, 0), "paint", GUN_PAINT, 14)
	k._cyl(p, 0.1, 0.1, 0.14, Vector3(0, y, z0 - length + 0.07), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	k._box(p, Vector3(0.06, 0.05, 0.1), Vector3(0, y + 0.12, z0 - length + 0.2), "gunmetal_w", null, Vector3.ZERO, false)
	return k._tip(p, Vector3(0, y, z0 - length - 0.05))


## A commander's cupola with a 12.7 mm on its ring, the gun facing forward.
static func _cupola_mg(k: VehicleModels, p: Node3D, pos: Vector3, mat := CAM) -> void:
	k._cyl(p, 0.36, 0.39, 0.2, pos + Vector3(0, 0.1, 0), Vector3.ZERO, mat, null, 16)
	k._cyl(p, 0.3, 0.3, 0.06, pos + Vector3(0, 0.23, 0.05), Vector3.ZERO, mat, null, 14)
	for i in 4:
		var a := -PI / 2 + (i - 1.5) * 0.55
		k._box(p, Vector3(0.12, 0.07, 0.05), pos + Vector3(cos(a) * 0.37, 0.14, sin(a) * 0.37), "glass", null, Vector3(0, -a + PI / 2, 0), false)
	k._box(p, Vector3(0.06, 0.3, 0.12), pos + Vector3(0.0, 0.36, -0.2), "gunmetal_w")
	k._box(p, Vector3(0.15, 0.15, 0.6), pos + Vector3(0.0, 0.5, -0.25), "gunmetal_w")
	k._cyl(p, 0.028, 0.026, 0.85, pos + Vector3(0.0, 0.52, -0.97), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._cyl(p, 0.04, 0.04, 0.12, pos + Vector3(0.0, 0.52, -1.42), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
	k._box(p, Vector3(0.14, 0.2, 0.3), pos + Vector3(-0.15, 0.46, -0.2), "paint", OLIVE)


## T-100 Varsuk: the Black Eagle's wide welded turret with reactive armour on
## its cheeks, the enormous box bustle of the autoloader behind it, Drozd
## launchers on its flanks, the commander's cupola with its 12.7 mm, the long
## 125 mm with its fume extractor.
static func _varsuk(k: VehicleModels, team: int) -> void:
	var c := CAM
	var t := k._pivot(k.root, _t100(k, team))
	k.turret = t
	k._cyl(t, 1.12, 1.16, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, c, null, 22)
	k._add(t, VehicleModels.loft("csat_var_tur", [-0.7, -1.55, 0.7, -1.55, 1.38, -0.95, 1.42, 0.95, 1.2, 1.2, -1.2, 1.2, -1.42, 0.95, -1.38, -0.95],
		[-0.58, -1.38, 0.58, -1.38, 1.22, -0.82, 1.27, 0.88, 1.08, 1.1, -1.08, 1.1, -1.27, 0.88, -1.22, -0.82], 0.06, 0.78), c, null, Vector3.ZERO)
	# the bustle: a long box hung off the turret's back
	k._add(t, VehicleModels.loft("csat_var_bus", [-1.1, 1.0, 1.1, 1.0, 1.05, 2.9, -1.05, 2.9], [-1.05, 1.0, 1.05, 1.0, 1.0, 2.82, -1.0, 2.82], 0.14, 0.74), c, null, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.5, 0.03, 0.36), Vector3(s * 0.5, 0.755, 2.4), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(t, Vector3(0.7, 0.05, 0.5), Vector3(s * 0.45, 0.76, 1.55), c)
	k._box(t, Vector3(0.6, 0.22, 0.04), Vector3(0.5, 0.45, 2.88), c)
	# reactive armour on the cheeks either side of the mantlet, and on the roof
	for s in [-1.0, 1.0]:
		var n := Vector3(s * 0.662, 0.2, -0.75).normalized()
		_era(k, t, Vector3(s * 0.97, 0.42, -1.18), n, Vector3.UP, 2, 3, Vector3(0.26, 0.3, 0.14))
		_era(k, t, Vector3(s * 0.75, 0.78, -0.95), Vector3.UP, Vector3(0, 0, -1), 1, 2, Vector3(0.36, 0.5, 0.1), s * 0.5)
	# mantlet, gun, coax
	k._box(t, Vector3(0.72, 0.5, 0.3), Vector3(0, 0.42, -1.58), c)
	k._cyl(t, 0.2, 0.15, 0.3, Vector3(0, 0.42, -1.8), Vector3(PI / 2, 0, 0), "canvas", Color(0.3, 0.29, 0.22), 12)
	k.gun_tip = _gun125(k, t, 0.42, -1.9, 5.4)
	k._cyl(t, 0.022, 0.022, 0.3, Vector3(0.3, 0.33, -1.85), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	k.mg_tip = k._tip(t, Vector3(0.3, 0.33, -2.0))
	# commander's cupola (right) with the 12.7 mm, gunner's sight (left front)
	_cupola_mg(k, t, Vector3(0.6, 0.78, 0.25))
	k._box(t, Vector3(0.4, 0.34, 0.46), Vector3(-0.66, 0.95, -0.7), c)
	if not k.burnt:
		k._box(t, Vector3(0.28, 0.16, 0.02), Vector3(-0.66, 0.98, -0.94), "glass", null, Vector3.ZERO, false)
	_hatch(k, t, Vector3(-0.55, 0.78, 0.35), 0.26)
	# Drozd launchers on the flanks, their radar heads on the cheeks, smoke
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.12, 0.16, 0.5), Vector3(s * 1.42, 0.4, -0.35), "gunmetal_w")
		for i in 2:
			k._box(t, Vector3(0.22, 0.2, 0.46), Vector3(s * (1.56 + i * 0.03), 0.3 + i * 0.22, -0.42 - i * 0.04), "paint", OLIVE, Vector3(-0.12, s * 0.25, 0))
			k._cyl(t, 0.065, 0.065, 0.02, Vector3(s * (1.5 + i * 0.03), 0.3 + i * 0.22, -0.66 - i * 0.04), Vector3(PI / 2 - 0.12, s * 0.25, 0), "plain_dark", null, 10, false)
			k._cyl(t, 0.065, 0.065, 0.02, Vector3(s * (1.62 + i * 0.03), 0.3 + i * 0.22, -0.64 - i * 0.04), Vector3(PI / 2 - 0.12, s * 0.25, 0), "plain_dark", null, 10, false)
		k._box(t, Vector3(0.22, 0.14, 0.16), Vector3(s * 1.1, 0.86, -0.82), "gunmetal_w", null, Vector3(0, s * -0.7, 0))
		_smoke(k, t, Vector3(s * 1.3, 0.7, 0.35), s, 4, 0.9)
		# antennas at the bustle's back corners
		_antenna(k, t, Vector3(s * 0.8, 0.76, 2.6), 2.0 if s < 0 else 1.5)
	# stowage on the bustle's back, a wind sensor mast
	k._box(t, Vector3(1.6, 0.36, 0.3), Vector3(0, 0.5, 3.02), "canvas", Color(0.33, 0.33, 0.24))
	k._cyl(t, 0.015, 0.015, 0.35, Vector3(0.2, 0.95, 1.2), Vector3.ZERO, "gunmetal_w", null, 4, false)
	k._team_mark(t, team, Vector3(1.09, 0.45, 1.95), Vector3(0.03, 0.24, 0.7))
	k._team_mark(t, team, Vector3(-1.09, 0.45, 1.95), Vector3(0.03, 0.24, 0.7))


## T-100X Futura: the Varsuk's hull under an experimental turret - two faceted
## wedge tiers, low and sharp-nosed, the railgun's twin flat rails in a boxy
## shroud with spacer bands, a capacitor bank at the back.
static func _futura(k: VehicleModels, team: int) -> void:
	var c := CAM
	var t := k._pivot(k.root, _t100(k, team))
	k.turret = t
	k._cyl(t, 1.12, 1.16, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, c, null, 22)
	k._add(t, VehicleModels.loft("csat_fut_tur", [-0.45, -1.95, 0.45, -1.95, 1.42, -0.75, 1.48, 1.4, 1.15, 2.35, -1.15, 2.35, -1.48, 1.4, -1.42, -0.75],
		[-0.32, -1.62, 0.32, -1.62, 1.14, -0.55, 1.2, 1.3, 0.92, 2.15, -0.92, 2.15, -1.2, 1.3, -1.14, -0.55], 0.06, 0.6), c, null, Vector3.ZERO)
	k._add(t, VehicleModels.loft("csat_fut_top", [-0.3, -1.55, 0.3, -1.55, 1.06, -0.5, 1.12, 1.25, 0.86, 2.05, -0.86, 2.05, -1.12, 1.25, -1.06, -0.5],
		[-0.16, -0.95, 0.16, -0.95, 0.68, -0.25, 0.74, 1.0, 0.56, 1.7, -0.56, 1.7, -0.74, 1.0, -0.68, -0.25], 0.6, 0.86), c, null, Vector3.ZERO)
	# seams of the panels on the faceted roof
	for s in [-1.0, 1.0]:
		_plate(k, t, Vector3(s * 0.46, 0.75, -1.2), Vector3(s * 0.9, 0.74, -0.3), 0.025, 0.02, "gunmetal_w", null, Vector3.UP, false)
	# the railgun: a boxy shroud round the breech end, two flat rails ahead
	# held by spacer bands, an open frame at the muzzle
	var gy := 0.42
	k._box(t, Vector3(0.5, 0.46, 2.4), Vector3(0, gy, -2.6), c)
	for i in 4:
		k._box(t, Vector3(0.52, 0.03, 0.12), Vector3(0, gy + 0.24, -1.9 - i * 0.45), "gunmetal_w", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.07, 0.26, 4.0), Vector3(s * 0.085, gy, -5.75), "gunmetal_w")
		k._box(t, Vector3(0.02, 0.2, 4.0), Vector3(s * 0.045, gy, -5.75), "steel", Color(0.45, 0.4, 0.33), Vector3.ZERO, false)
	for i in 4:
		k._box(t, Vector3(0.34, 0.34, 0.1), Vector3(0, gy, -4.3 - i * 0.95), c)
	k._box(t, Vector3(0.36, 0.06, 0.22), Vector3(0, gy + 0.16, -7.68), "gunmetal_w")
	k._box(t, Vector3(0.36, 0.06, 0.22), Vector3(0, gy - 0.16, -7.68), "gunmetal_w")
	k.gun_tip = k._tip(t, Vector3(0, gy, -7.8))
	# the capacitor bank and its cooling vents at the back
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.6, 0.36, 0.7), Vector3(s * 0.48, 0.42, 2.5), c)
		k._box(t, Vector3(0.5, 0.2, 0.03), Vector3(s * 0.48, 0.45, 2.86), "gunmetal_w", null, Vector3.ZERO, false)
		_smoke(k, t, Vector3(s * 1.18, 0.55, 0.6), s, 4, 1.0)
		_antenna(k, t, Vector3(s * 0.7, 0.75, 1.9), 1.8 if s < 0 else 1.3)
	# sights: the gunner's block, the commander's panoramic head, a remote MG
	k._box(t, Vector3(0.36, 0.26, 0.4), Vector3(-0.42, 0.98, -0.25), c)
	if not k.burnt:
		k._box(t, Vector3(0.26, 0.12, 0.02), Vector3(-0.42, 1.0, -0.46), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.08, 0.1, 0.32, Vector3(0.45, 1.0, 0.6), Vector3.ZERO, "gunmetal_w", null, 10)
	k._box(t, Vector3(0.3, 0.22, 0.3), Vector3(0.45, 1.25, 0.6), c)
	if not k.burnt:
		k._box(t, Vector3(0.18, 0.1, 0.02), Vector3(0.45, 1.26, 0.44), "glass", null, Vector3.ZERO, false)
	_rcws(k, t, Vector3(-0.3, 0.86, 1.0), "hmg")
	k._team_mark(t, team, Vector3(0, 0.865, 1.35), Vector3(0.6, 0.02, 0.4))


## 2S9 Sochor: the T-100 hull under a big flat-sided howitzer turret (2S35
## Koalitsiya-like) with the long 152 mm overhanging the nose, its muzzle brake
## and fume extractor, a remote 12.7 mm on the roof, a travel lock folded on
## the glacis. The barrel rides k.elev (pivot at the trunnions).
static func _sochor(k: VehicleModels, team: int) -> void:
	var c := CAM
	var m := k.root
	var ring := _t100(k, team)
	var t := k._pivot(m, ring + Vector3(0, 0, 0.5))
	k.turret = t
	k._cyl(t, 1.2, 1.25, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, c, null, 22)
	k._add(t, VehicleModels.loft("csat_sch_tur", [-1.5, -2.0, 1.5, -2.0, 1.62, -1.5, 1.62, 2.75, -1.62, 2.75, -1.62, -1.5],
		[-1.3, -1.45, 1.3, -1.45, 1.46, -1.1, 1.48, 2.62, -1.48, 2.62, -1.46, -1.1], 0.06, 1.28), c, null, Vector3.ZERO)
	# flat sides: a crew door, stowage boxes, vents; the ammunition door at the back
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.03, 0.85, 0.7), Vector3(s * 1.565, 0.62, 0.4), c, null, Vector3(0, 0, s * 0.11))
		k._box(t, Vector3(0.05, 0.05, 0.14), Vector3(s * 1.6, 0.62, 0.15), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(t, Vector3(0.3, 0.42, 1.0), Vector3(s * 1.72, 0.45, 1.75), c)
		k._box(t, Vector3(0.03, 0.3, 0.5), Vector3(s * 1.58, 0.95, -0.6), "gunmetal_w", null, Vector3(0, 0, s * 0.11))
		_smoke(k, t, Vector3(s * 1.42, 1.02, -1.25), s, 4, 0.6)
		_antenna(k, t, Vector3(s * 1.2, 1.28, 2.4), 2.0 if s < 0 else 1.5)
	k._box(t, Vector3(1.0, 0.7, 0.04), Vector3(0.45, 0.6, 2.69), c)
	k._box(t, Vector3(0.06, 0.16, 0.06), Vector3(0.0, 0.6, 2.72), "gunmetal_w", null, Vector3.ZERO, false)
	# roof: hatches, the commander's panoramic sight, the remote 12.7 mm
	_hatch(k, t, Vector3(0.65, 1.28, 0.5), 0.3)
	_hatch(k, t, Vector3(-0.2, 1.28, 1.6), 0.28)
	k._cyl(t, 0.1, 0.12, 0.3, Vector3(0.75, 1.42, -0.6), Vector3.ZERO, "gunmetal_w", null, 10)
	k._box(t, Vector3(0.34, 0.26, 0.34), Vector3(0.75, 1.68, -0.6), c)
	if not k.burnt:
		k._box(t, Vector3(0.2, 0.12, 0.02), Vector3(0.75, 1.7, -0.78), "glass", null, Vector3.ZERO, false)
	k._box(t, Vector3(0.36, 0.3, 0.44), Vector3(-0.85, 1.42, -0.85), c)
	if not k.burnt:
		k._box(t, Vector3(0.24, 0.14, 0.02), Vector3(-0.85, 1.45, -1.08), "glass", null, Vector3.ZERO, false)
	_rcws(k, t, Vector3(-0.65, 1.28, 0.6), "hmg")
	k._team_mark(t, team, Vector3(0.5, 1.285, 2.0), Vector3(0.7, 0.02, 0.5))
	# the barrel on its trunnions: mantlet, recoil cylinders, fume extractor,
	# the long tube and the muzzle brake
	var e := k._pivot(t, Vector3(0, 0.72, -1.5))
	k.elev = e
	k._box(e, Vector3(0.82, 0.66, 0.6), Vector3(0, 0.0, -0.38), c)
	for s in [-1.0, 1.0]:
		k._cyl(e, 0.07, 0.07, 0.9, Vector3(s * 0.2, 0.22, -0.9), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k._cyl(e, 0.22, 0.2, 0.6, Vector3(0, 0, -0.95), Vector3(PI / 2, 0, 0), "paint", GUN_PAINT, 14)
	k._cyl(e, 0.14, 0.115, 5.6, Vector3(0, 0, -3.9), Vector3(PI / 2, 0, 0), "paint", GUN_PAINT, 12)
	k._cyl(e, 0.2, 0.2, 0.7, Vector3(0, 0, -3.2), Vector3(PI / 2, 0, 0), "paint", GUN_PAINT, 14)
	k._cyl(e, 0.18, 0.18, 0.5, Vector3(0, 0, -6.9), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	for s in [-1.0, 1.0]:
		k._box(e, Vector3(0.08, 0.26, 0.42), Vector3(s * 0.17, 0, -6.92), "gunmetal_w")
	k.gun_tip = k._tip(e, Vector3(0, 0, -7.2))
	# the travel lock, folded down on the glacis
	var gu := Vector3(0, 0.48, 1.55).normalized()
	for s in [-1.0, 1.0]:
		_tube(k, m, Vector3(s * 0.3, 1.2, -3.6), Vector3(s * 0.08, 1.48, -2.7), 0.04, "gunmetal_w", null, 6)
	k._box(m, Vector3(0.36, 0.1, 0.16), Vector3(0, 1.5, -2.64), "gunmetal_w", null, Vector3(atan2(gu.z, gu.y) - PI / 2, 0, 0))


# --- Angara: T-14 Armata -----------------------------------------------------------

## A run of slat armour: horizontal bars between posts, from a to b (the
## run's bottom line), `h` tall, standing off the hull along `out`.
static func _slats(k: VehicleModels, p: Node3D, a: Vector3, b: Vector3, h: float, out: Vector3) -> void:
	var d := b - a
	var n := int(ceil(d.length() / 0.9))
	for i in n + 1:
		var q := a + d * (float(i) / n)
		k._box(p, Vector3(0.05, h, 0.05), q + Vector3(0, h * 0.5, 0), "gunmetal_w")
		var br := Vector3(0.16, 0.04, 0.04) if absf(out.x) > 0.5 else Vector3(0.04, 0.04, 0.16)
		k._box(p, br, q - out * 0.08 + Vector3(0, h * 0.5, 0), "gunmetal_w", null, Vector3.ZERO, false)
	var rows := int(h / 0.13)
	for j in rows:
		var y := 0.06 + j * (h - 0.1) / maxf(1.0, rows - 1)
		_tube(k, p, a + Vector3(0, y, 0), b + Vector3(0, y, 0), 0.016, "gunmetal_w", null, 4, false)


## T-14 hull: long and tall, the glacis faced with reactive armour, the crew
## capsule in the front with its three hatches side by side, tall skirts with
## reactive armour on their front sections, slat cages round the engine bay at
## the back; seven road wheels a side, the sprocket at the rear. Returns the
## turret ring's centre.
static func _t14(k: VehicleModels, team: int) -> Vector3:
	var m := k.root
	var c := CAM
	var hull := [
		_sec(-4.35, 1.0, 0.98, 1.08, 1.02, 1.6, 1.06, 1.56, 1.1),
		_sec(-3.9, 1.04, 0.45, 1.1, 1.0, 1.68, 1.1, 1.64, 1.3),
		_sec(-2.75, 1.04, 0.45, 1.1, 1.0, 1.68, 1.1, 1.64, 1.85),
		_sec(4.1, 1.04, 0.45, 1.1, 1.0, 1.68, 1.1, 1.64, 1.85),
		_sec(4.35, 1.0, 0.7, 1.06, 1.0, 1.62, 1.1, 1.58, 1.65)]
	k._add(m, VehicleModels.solid(hull, "csat_t14_hull"), c, null, Vector3.ZERO)
	_running_gear(k, m, 1.38, 0.6, Vector3(-3.9, 0.6, 0.28), Vector3(3.92, 0.6, 0.29), [-3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0], 0.36, false, [-2.5, -0.5, 1.5])
	# the glacis: a grid of reactive armour blocks, the lights, tow hooks
	var gu := Vector3(0, 0.75, 1.6).normalized()
	var gn := Vector3(0, 1.6, -0.75).normalized()
	var g0 := Vector3(0, 1.1, -4.35)
	for i in 3:
		for j in 6:
			_onface(k, m, g0 + gu * (0.32 + i * 0.47) + Vector3((j - 2.5) * 0.51, 0, 0), gn, gu, Vector3(0.48, 0.44, 0.12), c)
	for s in [-1.0, 1.0]:
		_headlight(k, m, Vector3(s * 1.45, 1.25, -3.95))
		_tow(k, m, Vector3(s * 0.8, 0.88, -4.36), -1.0)
		k._box(m, Vector3(0.24, 0.05, 8.3), Vector3(s * 1.72, 1.12, 0.05), c)
		_plate(k, m, Vector3(s * 1.74, 1.1, -4.2), Vector3(s * 1.74, 0.82, -4.5), 0.24, 0.04, c)
	# the crew capsule: three hatches abreast, periscopes ahead of each
	for i in 3:
		var hx := (i - 1) * 0.82
		_hatch(k, m, Vector3(hx, 1.85, -2.3), 0.27)
		for j in 2:
			_periscope(k, m, Vector3(hx + (j - 0.5) * 0.24, 1.87, -2.66), (j - 0.5) * 0.4)
	# tall skirts: reactive armour forward, plain plates aft; slat cages round
	# the engine bay
	for s in [-1.0, 1.0]:
		for i in 7:
			var z := -3.55 + i * 1.08
			if i < 4:
				k._box(m, Vector3(0.06, 0.66, 1.04), Vector3(s * 1.8, 0.8, z), c)
				_era(k, m, Vector3(s * 1.83, 0.8, z), Vector3(s, 0, 0), Vector3.UP, 1, 3, Vector3(0.31, 0.58, 0.12))
			else:
				k._box(m, Vector3(0.06, 0.66, 1.04), Vector3(s * 1.8, 0.8, z), c)
				k._box(m, Vector3(0.07, 0.04, 1.04), Vector3(s * 1.81, 1.08, z), "gunmetal_w", null, Vector3.ZERO, false)
		_slats(k, m, Vector3(s * 1.84, 1.15, 1.25), Vector3(s * 1.84, 1.15, 4.3), 0.72, Vector3(s, 0, 0))
	_slats(k, m, Vector3(-1.84, 0.95, 4.5), Vector3(1.84, 0.95, 4.5), 0.92, Vector3(0, 0, 1))
	# engine deck: grilles, the exhaust on the left, stowage boxes on the deck
	k._box(m, Vector3(2.4, 0.04, 1.6), Vector3(0, 1.86, 3.1), "gunmetal_w")
	for i in 6:
		k._box(m, Vector3(2.3, 0.03, 0.05), Vector3(0, 1.885, 2.4 + i * 0.28), c, null, Vector3.ZERO, false)
	k._box(m, Vector3(0.12, 0.4, 1.0), Vector3(-1.68, 1.5, 2.2), "gunmetal_w")
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.5, 0.36, 1.2), Vector3(s * 1.3, 2.03, 3.45), c)
		_taillight(k, m, Vector3(s * 1.35, 1.45, 4.36))
		_tow(k, m, Vector3(s * 0.75, 0.9, 4.36), 1.0)
	k._team_mark(m, team, Vector3(1.645, 1.5, 0.6), Vector3(0.03, 0.26, 0.8))
	k._team_mark(m, team, Vector3(-1.645, 1.5, 0.6), Vector3(0.03, 0.26, 0.8))
	return Vector3(0, 1.85, 0.55)


## T-140 Angara: the T-14's unmanned turret - a faceted casing with steeply
## sloped faces and a narrow gun slot, the 125 mm without a fume extractor,
## Afghanit launch tubes round its base and smoke launchers on its roof, the
## gunner's and commander's sights, radar panels on its corners and a remote
## 12.7 mm (or, for the command tank, a remote 30 mm turret) on top.
static func _angara(k: VehicleModels, team: int, command: bool) -> void:
	var c := CAM
	var t := k._pivot(k.root, _t14(k, team))
	k.turret = t
	k._cyl(t, 1.2, 1.25, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, c, null, 22)
	k._add(t, VehicleModels.loft("csat_ang_tur", [-0.55, -1.85, 0.55, -1.85, 1.35, -1.15, 1.45, 1.4, 1.15, 2.1, -1.15, 2.1, -1.45, 1.4, -1.35, -1.15],
		[-0.42, -1.55, 0.42, -1.55, 1.12, -1.0, 1.2, 1.3, 0.95, 1.9, -0.95, 1.9, -1.2, 1.3, -1.12, -1.0], 0.06, 0.74), c, null, Vector3.ZERO)
	k._add(t, VehicleModels.loft("csat_ang_top", [-0.9, -0.6, 0.9, -0.6, 0.95, 1.6, -0.95, 1.6], [-0.8, -0.4, 0.8, -0.4, 0.85, 1.5, -0.85, 1.5], 0.74, 0.86), c, null, Vector3.ZERO)
	# the gun slot and mask, the 125 mm, the coax
	k._box(t, Vector3(0.5, 0.42, 0.3), Vector3(0, 0.42, -1.82), c)
	k._box(t, Vector3(0.3, 0.3, 0.04), Vector3(0, 0.42, -1.98), "plain_dark", null, Vector3.ZERO, false)
	k.gun_tip = _gun125(k, t, 0.42, -1.98, 5.1, false)
	k._cyl(t, 0.022, 0.022, 0.3, Vector3(0.32, 0.3, -1.85), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	k.mg_tip = k._tip(t, Vector3(0.32, 0.3, -2.0))
	# Afghanit: five launch tubes in a housing low on each flank, firing out
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.36, 0.3, 1.5), Vector3(s * 1.45, 0.2, -0.35), c, null, Vector3(0, s * -0.16, 0))
		for i in 5:
			var z := -0.95 + i * 0.3
			var a := Vector3(s * 1.5, 0.2, z)
			_tube(k, t, a, a + Vector3(s * 0.32, 0, -0.14), 0.075, "paint", OLIVE, 10)
		# radar panels on the corners
		_onface(k, t, Vector3(s * 0.86, 0.46, -1.38), Vector3(s * 0.659, 0.18, -0.753).normalized(), Vector3.UP, Vector3(0.26, 0.24, 0.03), "gunmetal_w")
		_onface(k, t, Vector3(s * 1.18, 0.46, 1.67), Vector3(s * 0.92, 0.15, 0.39).normalized(), Vector3.UP, Vector3(0.26, 0.24, 0.03), "gunmetal_w")
		# the soft-kill smoke launchers on the roof
		k._box(t, Vector3(0.5, 0.18, 0.34), Vector3(s * 0.85, 0.84, -0.55), "gunmetal_w", null, Vector3(0, s * -0.3, 0))
		for i in 3:
			k._cyl(t, 0.045, 0.045, 0.2, Vector3(s * (0.7 + i * 0.13), 0.95, -0.62 + i * 0.05 * s), Vector3(-0.8, s * -0.3, 0), "gunmetal_w", null, 8, false)
		_antenna(k, t, Vector3(s * 0.85, 0.74, 1.75), 2.0 if s < 0 else 1.5)
	# the gunner's sight (front left) and the commander's panoramic sight
	k._box(t, Vector3(0.44, 0.34, 0.5), Vector3(-0.5, 1.0, -0.2), c)
	if not k.burnt:
		k._box(t, Vector3(0.3, 0.16, 0.02), Vector3(-0.5, 1.03, -0.46), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.12, 0.14, 0.4, Vector3(0.55, 1.06, 0.5), Vector3.ZERO, "gunmetal_w", null, 12)
	k._box(t, Vector3(0.4, 0.3, 0.4), Vector3(0.55, 1.4, 0.5), c)
	if not k.burnt:
		k._box(t, Vector3(0.26, 0.14, 0.02), Vector3(0.55, 1.42, 0.29), "glass", null, Vector3.ZERO, false)
	# the remote weapon on top: a 12.7 mm, or the command tank's 30 mm turret
	if command:
		var rw := k._pivot(t, Vector3(-0.1, 0.86, 0.95))
		k._add(rw, VehicleModels.loft("csat_ang_k30", [-0.4, -0.45, 0.4, -0.45, 0.45, 0.45, -0.45, 0.45], [-0.32, -0.32, 0.32, -0.32, 0.38, 0.38, -0.38, 0.38], 0.04, 0.42), c, null, Vector3.ZERO)
		k._box(rw, Vector3(0.22, 0.22, 0.36), Vector3(0, 0.26, -0.55), c)
		k._cyl(rw, 0.06, 0.06, 0.4, Vector3(0, 0.26, -0.85), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
		k._cyl(rw, 0.04, 0.035, 1.5, Vector3(0, 0.26, -1.75), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
		k._cyl(rw, 0.055, 0.055, 0.15, Vector3(0, 0.26, -2.55), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
		k._box(rw, Vector3(0.22, 0.2, 0.26), Vector3(0.32, 0.52, -0.1), c)
		if not k.burnt:
			k._box(rw, Vector3(0.14, 0.08, 0.02), Vector3(0.32, 0.53, -0.24), "glass", null, Vector3.ZERO, false)
		k._box(rw, Vector3(0.2, 0.26, 0.4), Vector3(-0.5, 0.2, 0.05), "paint", OLIVE)
		k.mg_tip = k._tip(rw, Vector3(0, 0.26, -2.65))
	else:
		_rcws(k, t, Vector3(-0.1, 0.86, 0.95), "hmg")
	k._team_mark(t, team, Vector3(0.0, 0.865, -0.1), Vector3(0.6, 0.02, 0.4))


# --- Tempest: KamAZ-63968 Typhoon-K -------------------------------------------------

const CANVAS_TAN := Color(0.47, 0.42, 0.31)  # on canvas_white: tints above the preset's base would clip


## Typhoon-K cab and chassis: the armoured cab-over with its two big flat
## windscreen panes, thick side windows and doors, the massive bumper with the
## headlights, a ladder of steps, mirrors on long arms; the frame, the fuel
## tank and the exhaust stack behind the cab, six wheels (one axle at the
## front, two at the back). The mission module goes on from z = -2.1.
static func _typhoon(k: VehicleModels, team: int) -> void:
	var m := k.root
	var c := CAM
	k._box(m, Vector3(0.95, 0.28, 8.4), Vector3(0, 0.96, 0.05), "gunmetal_w")
	var cab := [
		_sec(-4.45, 0.86, 1.32, 1.04, 1.38, 1.08, 2.0, 1.03, 2.05),
		_sec(-4.15, 1.04, 1.3, 1.24, 1.36, 1.27, 2.1, 1.13, 3.12),
		_sec(-2.32, 1.04, 1.3, 1.24, 1.36, 1.27, 2.1, 1.15, 3.14),
		_sec(-2.24, 1.0, 1.34, 1.2, 1.4, 1.23, 2.1, 1.1, 3.08)]
	k._add(m, VehicleModels.solid(cab, "csat_typh_cab"), c, null, Vector3.ZERO)
	# the bumper block under the cab's nose
	k._add(m, VehicleModels.loft("csat_typh_bump", [-1.18, -4.6, 1.18, -4.6, 1.18, -3.75, -1.18, -3.75], [-1.22, -4.66, 1.22, -4.66, 1.22, -3.72, -1.22, -3.72], 0.72, 1.34), c, null, Vector3.ZERO)
	# the windscreen: two big flat panes, a pillar between them
	var wu := Vector3(0, 1.07, 0.3).normalized()
	var wn := Vector3(0, 0.3, -1.07).normalized()
	for s in [-1.0, 1.0]:
		_onface(k, m, Vector3(s * 0.52, 2.6, -4.3), wn, wu, Vector3(0.9, 0.84, 0.03), "glass", null, 0.0, false)
	_onface(k, m, Vector3(0, 2.6, -4.3), wn, wu, Vector3(0.12, 1.0, 0.04), c)
	_onface(k, m, Vector3(0, 3.06, -4.18), wn, wu, Vector3(2.1, 0.1, 0.06), c)
	# the grille on the cab front, headlights and tow hooks in the bumper
	k._box(m, Vector3(1.5, 0.48, 0.04), Vector3(0, 1.7, -4.46), "gunmetal_w")
	for i in 5:
		k._box(m, Vector3(1.44, 0.03, 0.04), Vector3(0, 1.52 + i * 0.09, -4.48), c, null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		_headlight(k, m, Vector3(s * 0.88, 1.18, -4.68))
		_tow(k, m, Vector3(s * 0.45, 0.8, -4.65), -1.0)
		var sn := Vector3(s * 0.99, 0.136, 0)
		var sup := Vector3(s * -0.14, 1.02, 0)
		# door window and the small one behind it, the door seam and handle
		_onface(k, m, Vector3(s * 1.2, 2.62, -3.55), sn, sup, Vector3(0.72, 0.62, 0.03), "glass", null, 0.0, false)
		_onface(k, m, Vector3(s * 1.2, 2.66, -2.7), sn, sup, Vector3(0.4, 0.5, 0.03), "glass", null, 0.0, false)
		for dz in [-4.0, -3.0]:
			_onface(k, m, Vector3(s * 1.25, 1.9, dz), sn, sup, Vector3(0.025, 1.12, 0.02), "gunmetal_w", null, 0.0, false)
		k._box(m, Vector3(0.05, 0.05, 0.18), Vector3(s * 1.29, 2.05, -3.15), "gunmetal_w", null, Vector3.ZERO, false)
		# the step ladder under the door, behind the front wheel
		for sy in [0.62, 0.95]:
			k._box(m, Vector3(0.3, 0.04, 0.3), Vector3(s * 1.1, sy, -2.32), "gunmetal_w")
		k._box(m, Vector3(0.04, 0.5, 0.3), Vector3(s * 1.24, 0.85, -2.32), "gunmetal_w")
		# mirrors on long arms
		_tube(k, m, Vector3(s * 1.2, 2.5, -4.25), Vector3(s * 1.52, 2.55, -4.2), 0.02, "gunmetal_w", null, 6, false)
		k._box(m, Vector3(0.06, 0.42, 0.22), Vector3(s * 1.55, 2.5, -4.2), "gunmetal_w", null, Vector3(0, s * 0.15, 0))
		# the front wheel under its faceted arch, the rear tandem
		_arch(k, m, s * 1.13, -3.05, 0.64, 0.26, 1.34)
		k._wheel(m, Vector3(s * 1.0, 0.62, -3.05), 0.62, 0.48)
		k._wheel(m, Vector3(s * 1.0, 0.62, 1.55), 0.62, 0.48)
		k._wheel(m, Vector3(s * 1.0, 0.62, 3.0), 0.62, 0.48)
		k._box(m, Vector3(0.5, 0.42, 0.02), Vector3(s * 1.0, 0.5, 3.75), "rubber", null, Vector3.ZERO, false)
		# the rear tandem's mudguard
		k._box(m, Vector3(0.56, 0.05, 2.4), Vector3(s * 1.0, 1.35, 2.28), "gunmetal_w")
		_taillight(k, m, Vector3(s * 0.95, 0.98, 4.48))
	# fuel tank and battery box on the frame, the exhaust stack behind the cab
	k._box(m, Vector3(0.5, 0.52, 1.4), Vector3(0.95, 0.95, -1.2), "steel", Color(0.32, 0.31, 0.25))
	k._box(m, Vector3(0.5, 0.45, 0.8), Vector3(-0.95, 0.95, -1.5), "gunmetal_w")
	_tube(k, m, Vector3(1.05, 1.3, -2.18), Vector3(1.05, 3.25, -2.18), 0.06, "gunmetal_w", null, 8)
	k._box(m, Vector3(0.18, 0.7, 0.12), Vector3(1.05, 2.4, -2.1), "gunmetal_w")
	# the rear underrun bar
	k._box(m, Vector3(2.2, 0.14, 0.14), Vector3(0, 0.75, 4.45), "steel", Color(0.3, 0.29, 0.25))
	# roof: hatch, antennas, a light
	_hatch(k, m, Vector3(0.3, 3.13, -3.0), 0.3)
	_antenna(k, m, Vector3(-0.85, 3.12, -2.5), 2.0)
	k._box(m, Vector3(0.3, 0.12, 0.12), Vector3(-0.6, 3.18, -3.95), "gunmetal_w")
	k._team_mark(m, team, Vector3(0.0, 3.145, -3.7), Vector3(0.6, 0.02, 0.4))


## Tempest: the Typhoon-K with its mission module. `kind`: "" (troops under a
## canvas cover over armoured sides), "ammo" (crates and a loading crane),
## "repair" (a workshop body and a crane), "medical" (an armoured ambulance
## body) or "fuel" (a tank).
static func _tempest(k: VehicleModels, team: int, kind: String) -> void:
	var m := k.root
	var c := CAM
	_typhoon(k, team)
	match kind:
		"ammo":
			_tempest_flatbed(k, 0.4)
			# long missile crates stacked forward, ammunition boxes behind them,
			# cans at the tail, all strapped down
			for l in 3:
				for j in 2:
					k._box(m, Vector3(1.0, 0.3, 1.9), Vector3((j - 0.5) * 1.08, 1.66 + l * 0.32, -0.55), "paint", OLIVE if (j + l) % 2 == 0 else OLIVE.lightened(0.08))
			for i in 3:
				for j in 3:
					for l in 2:
						k._box(m, Vector3(0.66, 0.4, 0.8), Vector3((j - 1) * 0.72, 1.71 + l * 0.42, 0.95 + i * 0.88), "paint", OLIVE.darkened(0.06) if (i + j + l) % 2 == 0 else OLIVE.lightened(0.1))
			for j in 4:
				k._box(m, Vector3(0.4, 0.3, 0.55), Vector3((j - 1.5) * 0.5, 1.66, 3.8), "paint", Color(0.27, 0.29, 0.21))
			var strap := Color(0.28, 0.26, 0.2)
			for z in [-1.1, 0.0]:
				k._box(m, Vector3(2.2, 0.02, 0.07), Vector3(0, 2.465, z), "canvas_white", strap, Vector3.ZERO, false)
			for z in [0.95, 1.83, 2.71]:
				k._box(m, Vector3(2.2, 0.02, 0.07), Vector3(0, 2.345, z), "canvas_white", strap, Vector3.ZERO, false)
			# the loading crane behind the cab, its boom folded back over the load
			var cc := Color(0.5, 0.45, 0.32)
			k._cyl(m, 0.17, 0.21, 0.95, Vector3(0.75, 1.97, -1.78), Vector3.ZERO, "paint", cc, 12)
			k._box(m, Vector3(0.36, 0.26, 0.42), Vector3(0.75, 2.5, -1.75), "paint", cc)
			k._box(m, Vector3(0.2, 0.2, 3.3), Vector3(0.75, 2.6, 0.0), "paint", cc)
			k._box(m, Vector3(0.14, 0.14, 1.2), Vector3(0.75, 2.6, 2.2), "paint", cc.darkened(0.15))
			k._box(m, Vector3(0.1, 0.22, 0.12), Vector3(0.75, 2.46, 2.8), "gunmetal_w")
		"repair":
			_tempest_flatbed(k, 0.0)
			_tempest_box(k, -2.05, 2.15, 3.05, "csat_typh_shop")
			for s in [-1.0, 1.0]:
				# roller shutters on the sides, toolboxes under the body
				k._box(m, Vector3(0.03, 1.15, 1.6), Vector3(s * 1.255, 2.25, -0.95), "gunmetal_w")
				for i in 8:
					k._box(m, Vector3(0.035, 0.02, 1.58), Vector3(s * 1.26, 1.75 + i * 0.13, -0.95), c, null, Vector3.ZERO, false)
				k._box(m, Vector3(0.03, 1.15, 1.4), Vector3(s * 1.255, 2.25, 1.05), "gunmetal_w")
				k._box(m, Vector3(0.36, 0.42, 1.1), Vector3(s * 1.05, 1.1, 0.0), "steel", Color(0.32, 0.31, 0.25))
			# the workshop's back door onto the platform
			k._box(m, Vector3(0.9, 1.3, 0.03), Vector3(-0.3, 2.2, 2.165), c)
			k._box(m, Vector3(0.05, 0.16, 0.05), Vector3(-0.66, 2.2, 2.19), "gunmetal_w", null, Vector3.ZERO, false)
			for hy in [1.7, 2.7]:
				k._box(m, Vector3(0.06, 0.12, 0.06), Vector3(0.16, hy, 2.18), "gunmetal_w", null, Vector3.ZERO, false)
			# the crane on the open platform behind, its boom along the roof
			k._cyl(m, 0.22, 0.26, 1.45, Vector3(0.6, 2.22, 3.3), Vector3.ZERO, "paint", Color(0.5, 0.45, 0.32), 12)
			k._box(m, Vector3(0.4, 0.3, 0.5), Vector3(0.6, 3.05, 3.3), "paint", Color(0.5, 0.45, 0.32))
			k._box(m, Vector3(0.22, 0.24, 3.2), Vector3(0.6, 3.26, 1.85), "paint", Color(0.5, 0.45, 0.32))
			_tube(k, m, Vector3(0.6, 2.6, 3.15), Vector3(0.6, 3.18, 2.2), 0.06, "gunmetal_w", null, 8)
			k._box(m, Vector3(0.1, 0.12, 0.1), Vector3(0.6, 3.1, 0.6), "gunmetal_w")
			k._box(m, Vector3(0.12, 0.2, 0.12), Vector3(0.6, 3.3, 0.18), "gunmetal_w")
			# a spare wheel standing on the platform, a welding bottle rack
			var sp := k._pivot(m, Vector3(-0.55, 2.14, 3.6))
			k._cyl(sp, 0.6, 0.6, 0.45, Vector3.ZERO, Vector3(PI / 2, 0, 0), "rubber", null, 18)
			k._cyl(sp, 0.36, 0.36, 0.47, Vector3.ZERO, Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
			for i in 2:
				k._cyl(m, 0.1, 0.1, 0.9, Vector3(-0.95, 1.95, 2.55 + i * 0.25), Vector3.ZERO, "paint", Color(0.25, 0.32, 0.3) if i == 0 else Color(0.5, 0.42, 0.2), 10)
		"medical":
			_tempest_flatbed(k, 0.0, false)
			_tempest_box(k, -2.05, 4.42, 3.22, "csat_typh_med")
			for s in [-1.0, 1.0]:
				for wz in [-0.6, 0.5]:
					k._box(m, Vector3(0.03, 0.34, 0.5), Vector3(s * 1.255, 2.55, wz), "glass", null, Vector3.ZERO, false)
				_cross(k, m, Vector3(s * 1.26, 2.4, 2.2), Vector3(s, 0, 0))
				k._box(m, Vector3(0.36, 0.3, 1.2), Vector3(s * 1.05, 1.15, 0.2), "steel", Color(0.32, 0.31, 0.25))
			# the rear door with its steps, the cross on it, the roof's air units
			k._box(m, Vector3(1.0, 1.5, 0.04), Vector3(-0.2, 2.25, 4.44), c)
			if not k.burnt:
				k._box(m, Vector3(0.36, 0.3, 0.02), Vector3(-0.2, 2.7, 4.465), "glass", null, Vector3.ZERO, false)
			_cross(k, m, Vector3(0.75, 2.6, 4.45), Vector3(0, 0, 1))
			for sy in [0.95, 1.25]:
				k._box(m, Vector3(0.9, 0.04, 0.3), Vector3(-0.2, sy, 4.62), "gunmetal_w")
			k._box(m, Vector3(1.0, 0.3, 0.9), Vector3(0, 3.38, -1.2), "gunmetal_w")
			k._box(m, Vector3(0.6, 0.2, 0.6), Vector3(0.4, 3.32, 2.6), c)
			_cross(k, m, Vector3(0, 3.235, 1.0), Vector3.UP)
		"fuel":
			_tempest_flatbed(k, 0.0, false)
			k._add(m, Res.cyl(1.0, 1.0, 5.6, 22), c, null, Vector3(0, 2.38, 0.9), Vector3(PI / 2, 0, 0), Vector3(1.18, 1.0, 0.86))
			for ez in [-1.9, 3.7]:
				k._add(m, Res.cyl(0.92, 0.92, 0.12, 22), c, null, Vector3(0, 2.38, ez), Vector3(PI / 2, 0, 0), Vector3(1.18, 1.0, 0.86))
			# cradles, the walkway with its rails and manholes, a ladder
			for z in [-1.2, 0.9, 3.0]:
				k._box(m, Vector3(2.0, 0.3, 0.2), Vector3(0, 1.55, z), "gunmetal_w")
			k._box(m, Vector3(0.7, 0.04, 5.0), Vector3(0, 3.24, 0.9), "gunmetal_w")
			for i in 3:
				_hatch(k, m, Vector3(0, 3.24, -0.8 + i * 1.6), 0.25, "gunmetal_w")
			for s in [-1.0, 1.0]:
				k._box(m, Vector3(0.03, 0.03, 5.0), Vector3(s * 0.38, 3.55, 0.9), "gunmetal_w", null, Vector3.ZERO, false)
				for i in 5:
					k._box(m, Vector3(0.03, 0.32, 0.03), Vector3(s * 0.38, 3.4, -1.5 + i * 1.2), "gunmetal_w", null, Vector3.ZERO, false)
				k._box(m, Vector3(0.36, 0.3, 1.4), Vector3(s * 1.05, 1.15, 0.0), "steel", Color(0.32, 0.31, 0.25))
			for i in 7:
				k._box(m, Vector3(0.5, 0.03, 0.05), Vector3(0.62, 1.5 + i * 0.27, 3.85), "gunmetal_w", null, Vector3.ZERO, false)
			for s in [-1.0, 1.0]:
				k._box(m, Vector3(0.04, 1.9, 0.05), Vector3(0.62 + s * 0.25, 2.3, 3.85), "gunmetal_w", null, Vector3.ZERO, false)
			# the pump cabinet and hose reels at the back
			k._box(m, Vector3(1.0, 0.7, 0.6), Vector3(-0.6, 1.85, 4.1), "gunmetal_w")
			k._cyl(m, 0.24, 0.24, 0.5, Vector3(-0.6, 1.9, 4.42), Vector3(0, 0, PI / 2), "rubber", null, 14)
			if not k.burnt:
				k._box(m, Vector3(0.4, 0.3, 0.02), Vector3(0, 2.75, 3.77), "paint", Color(0.55, 0.36, 0.1), Vector3.ZERO, false)
		_:
			# troops: armoured sides, the canvas cover on its bows
			_tempest_flatbed(k, 0.62)
			k._add(m, VehicleModels.loft("csat_typh_tarp", [-1.25, -2.0, 1.25, -2.0, 1.25, 4.38, -1.25, 4.38], [-1.12, -1.95, 1.12, -1.95, 1.12, 4.32, -1.12, 4.32], 2.1, 3.2), "canvas_white", CANVAS_TAN, Vector3.ZERO)
			k._add(m, VehicleModels.loft("csat_typh_tarp2", [-1.12, -1.95, 1.12, -1.95, 1.12, 4.32, -1.12, 4.32], [-0.95, -1.9, 0.95, -1.9, 0.95, 4.27, -0.95, 4.27], 3.2, 3.3), "canvas_white", CANVAS_TAN, Vector3.ZERO)
			var strap := CANVAS_TAN.darkened(0.25)
			for i in 6:
				var z := -1.6 + i * 1.18
				k._box(m, Vector3(1.92, 0.03, 0.08), Vector3(0, 3.31, z), "canvas_white", strap, Vector3.ZERO, false)
				for s in [-1.0, 1.0]:
					_plate(k, m, Vector3(s * 1.262, 2.1, z), Vector3(s * 1.132, 3.2, z), 0.08, 0.03, "canvas_white", strap, Vector3.BACK, false)
					_plate(k, m, Vector3(s * 1.135, 3.2, z), Vector3(s * 0.95, 3.31, z), 0.08, 0.03, "canvas_white", strap, Vector3.BACK, false)
			k._box(m, Vector3(2.1, 0.9, 0.04), Vector3(0, 2.62, 4.4), "canvas_white", CANVAS_TAN.darkened(0.12))
			for s in [-1.0, 1.0]:
				k._box(m, Vector3(0.06, 0.08, 0.02), Vector3(s * 0.7, 2.15, 4.43), "gunmetal_w", null, Vector3.ZERO, false)
			# the boarding ladder hung on the tailgate
			for i in 3:
				k._box(m, Vector3(0.5, 0.04, 0.05), Vector3(0, 0.9 + i * 0.3, 4.55), "gunmetal_w", null, Vector3.ZERO, false)
			for s in [-1.0, 1.0]:
				k._box(m, Vector3(0.04, 0.9, 0.05), Vector3(s * 0.25, 1.2, 4.55), "gunmetal_w", null, Vector3.ZERO, false)


## The Tempest's load bed from behind the cab to the tail, with low armoured
## sides `h` tall (none when 0) and the headboard.
static func _tempest_flatbed(k: VehicleModels, h: float, head := true) -> void:
	var m := k.root
	var c := CAM
	k._box(m, Vector3(2.5, 0.14, 6.55), Vector3(0, 1.43, 1.17), c)
	k._box(m, Vector3(2.4, 0.08, 6.4), Vector3(0, 1.32, 1.17), "gunmetal_w")
	if head:
		k._box(m, Vector3(2.5, 1.1, 0.08), Vector3(0, 2.05, -2.07), c)
	if h > 0.0:
		for s in [-1.0, 1.0]:
			k._box(m, Vector3(0.07, h, 6.5), Vector3(s * 1.22, 1.5 + h * 0.5, 1.17), c)
			for i in 4:
				k._box(m, Vector3(0.09, h, 0.06), Vector3(s * 1.25, 1.5 + h * 0.5, -1.0 + i * 1.6), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(2.5, h, 0.07), Vector3(0, 1.5 + h * 0.5, 4.42), c)


## A closed armoured box body on the bed from z0 to z1, its roof at `top`.
static func _tempest_box(k: VehicleModels, z0: float, z1: float, top: float, key: String) -> void:
	k._add(k.root, VehicleModels.solid([
		_rz([-1.22, 1.5, 1.22, 1.5, 1.25, 1.6, 1.25, top - 0.15, 1.1, top, -1.1, top, -1.25, top - 0.15, -1.25, 1.6], z0),
		_rz([-1.22, 1.5, 1.22, 1.5, 1.25, 1.6, 1.25, top - 0.15, 1.1, top, -1.1, top, -1.25, top - 0.15, -1.25, 1.6], z1)], key), CAM, null, Vector3.ZERO)


## A muted medical cross on a pale square, facing along n.
static func _cross(k: VehicleModels, p: Node3D, pos: Vector3, n: Vector3) -> void:
	if k.burnt:
		return
	var up := Vector3.UP if absf(n.y) < 0.9 else Vector3(0, 0, -1)
	_onface(k, p, pos, n, up, Vector3(0.62, 0.62, 0.012), "paint", Color(0.72, 0.7, 0.64), 0.0, false)
	_onface(k, p, pos + n * 0.012, n, up, Vector3(0.14, 0.46, 0.012), "paint", Color(0.48, 0.09, 0.07), 0.0, false)
	_onface(k, p, pos + n * 0.012, n, up, Vector3(0.46, 0.14, 0.012), "paint", Color(0.48, 0.09, 0.07), 0.0, false)
