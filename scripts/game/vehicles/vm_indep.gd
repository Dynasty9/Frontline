class_name VmIndep
extends RefCounted
## Procedural models: AAF and LDF ground vehicles (Strider, Gorgon, Mora, Kuma, Nyx, Zamak, Zamak MRL).
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys must be unique per shape).

## Every model key this file builds (the Field Manual's model pages list them).
const KEYS: Array[String] = ["strider", "strider_hmg", "strider_gmg", "gorgon", "mora", "kuma", "nyx_ac", "nyx_at", "nyx_aa", "nyx_recon",
	"zamak", "zamak_cargo", "zamak_ammo", "zamak_repair", "zamak_medical", "zamak_fuel", "zamak_mrl"]

## AAF digital green: camo_tank tinted greener.
const AAF := Color(0.36, 0.39, 0.28)
const Z90 := Vector3(0, 0, PI / 2)  # a cylinder lying along X (axles, wheels)
const X90 := Vector3(PI / 2, 0, 0)  # a cylinder lying along Z (barrels, pointing fore and aft)


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"strider":
			_strider(k, team, 0)
		"strider_hmg":
			_strider(k, team, 1)
		"strider_gmg":
			_strider(k, team, 2)
		"gorgon":
			_gorgon(k, team)
		"mora":
			_mora(k, team)
		"kuma":
			_kuma(k, team)
		"nyx_ac", "nyx_at", "nyx_aa", "nyx_recon":
			_nyx(k, team, key.substr(4))
		"zamak", "zamak_cargo", "zamak_ammo", "zamak_repair", "zamak_medical", "zamak_fuel", "zamak_mrl":
			_zamak(k, team, key, seed)
		_:
			return false
	return true


# --- shared helpers ---------------------------------------------------------------

## The paint: AAF green; vehicles the Rebels also field (`either`) go khaki for them.
## (AAF green is camo_tank brightened and greened; a tint above 1 is lost
## when the parts are merged and the tint baked into 8-bit vertex colours,
## so it is reached by scaling camo_tank_rebel's lighter palette down to the
## AAF colour instead: the same four camo tones, nothing clamped.)
static func _paint(team: int, either := false) -> Array:
	if either and team == 1:
		return ["camo_tank_rebel", null]
	return ["camo_tank_rebel", AAF]


## A chamfered rectangle outline (x0..x1, z0..z1; z0 the front), for lofts.
static func _oct(x0: float, x1: float, z0: float, z1: float, c: float) -> Array:
	return [x0 + c, z0, x1 - c, z0, x1, z0 + c, x1, z1 - c, x1 - c, z1, x0 + c, z1, x0, z1 - c, x0, z0 + c]


static func _ring(pts: Array, y: float) -> PackedVector3Array:
	return VehicleModels.ring_y(VehicleModels._v2(pts), y)


## A plate lying along a face of a side profile, from a to b (each (z, y));
## `lift` moves it off the face (positive: away from the hull for a front face
## walked bottom to top, or a rear face walked top to bottom).
static func _plate(k: VehicleModels, p: Node3D, x: float, w: float, a: Vector2, b: Vector2, th: float, mat: String, col = null, lift := 0.0, shadow := true, ext := 0.0) -> MeshInstance3D:
	var d := b - a
	var l := d.length()
	var n := Vector2(-d.y, d.x) / l
	var mid := (a + b) * 0.5 + n * (lift + th * 0.5)
	return k._box(p, Vector3(w, l + ext, th), Vector3(x, mid.y, mid.x), mat, col, Vector3(atan2(d.x, d.y), 0, 0), shadow)


## Box / cylinder placed in a local frame t (a part group turned as one).
static func _tb(k: VehicleModels, p: Node3D, t: Transform3D, s: Vector3, lp: Vector3, mat: String, col = null, lr := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	return k._box(p, s, t * lp, mat, col, (t.basis * Basis.from_euler(lr)).get_euler(), shadow)


static func _tc(k: VehicleModels, p: Node3D, t: Transform3D, r0: float, r1: float, h: float, lp: Vector3, lr: Vector3, mat: String, col = null, segs := 12, shadow := true) -> MeshInstance3D:
	return k._cyl(p, r0, r1, h, t * lp, (t.basis * Basis.from_euler(lr)).get_euler(), mat, col, segs, shadow)


## A rectangular convoy-light cluster set in a housing, facing -Z (or +Z
## with face = 1), with a two-bar guard in front.
static func _light(k: VehicleModels, p: Node3D, pos: Vector3, w: float, h: float, face := -1.0, guard := true, rear := false) -> void:
	k._box(p, Vector3(w + 0.05, h + 0.05, 0.08), pos, "gunmetal_w")
	var lens := pos + Vector3(0, 0, face * 0.042)
	if rear:
		k._box(p, Vector3(w * 0.45, h * 0.7, 0.02), lens + Vector3(-w * 0.24, 0, 0), "paint", Color(0.45, 0.06, 0.05), Vector3.ZERO, false)
		k._box(p, Vector3(w * 0.45, h * 0.7, 0.02), lens + Vector3(w * 0.24, 0, 0), "paint", Color(0.55, 0.36, 0.08), Vector3.ZERO, false)
	else:
		k._box(p, Vector3(w * 0.55, h * 0.72, 0.02), lens + Vector3(-w * 0.18, 0, 0), "glass", null, Vector3.ZERO, false)
		k._box(p, Vector3(w * 0.25, h * 0.5, 0.02), lens + Vector3(w * 0.3, 0, 0), "paint", Color(0.6, 0.42, 0.12), Vector3.ZERO, false)
	if guard:
		for gx: float in [-0.5, 0.5]:
			k._box(p, Vector3(0.025, h + 0.12, 0.025), pos + Vector3(gx * w, 0, face * 0.12), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(p, Vector3(w + 0.05, 0.025, 0.025), pos + Vector3(0, h * 0.5 + 0.05, face * 0.12), "gunmetal_w", null, Vector3.ZERO, false)


## A round headlight in a deep housing facing -Z, with a wire guard.
static func _round_light(k: VehicleModels, p: Node3D, pos: Vector3, r: float) -> void:
	k._cyl(p, r * 1.2, r * 1.3, 0.16, pos, X90, "gunmetal_w", null, 14)
	k._cyl(p, r, r, 0.02, pos + Vector3(0, 0, -0.08), X90, "glass", null, 14, false)
	k._box(p, Vector3(0.022, r * 2.3, 0.022), pos + Vector3(0, 0, -0.13), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(p, Vector3(r * 2.3, 0.022, 0.022), pos + Vector3(0, 0, -0.13), "gunmetal_w", null, Vector3.ZERO, false)


## A cluster of n smoke-grenade dischargers on a block, fanned out, the block
## turned by yaw (0 faces forward) and the tubes pitched up.
static func _smoke(k: VehicleModels, p: Node3D, pos: Vector3, n: int, yaw: float, pitch := 0.45, r := 0.045) -> void:
	var t := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), pos)
	_tb(k, p, t, Vector3(n * r * 2.3 + 0.04, 0.08, 0.16), Vector3(0, -0.02, 0.04), "gunmetal_w")
	for i in n:
		var fx := (i - (n - 1) * 0.5) * r * 2.3
		_tc(k, p, t, r, r, 0.24, Vector3(fx, 0.06 + absf(fx) * 0.2, -0.04), Vector3(-PI / 2 + pitch, fx * 1.6, 0), "gunmetal_w", null, 8, false)


## A whip antenna on a small base.
static func _antenna(k: VehicleModels, p: Node3D, pos: Vector3, h: float) -> void:
	k._cyl(p, 0.035, 0.045, 0.1, pos + Vector3(0, 0.05, 0), Vector3.ZERO, "gunmetal_w", null, 8)
	k._cyl(p, 0.008, 0.013, h, pos + Vector3(0, 0.1 + h * 0.5, 0), Vector3.ZERO, "gunmetal_w", null, 4, false)


## A 20 l jerrycan (standing, its face toward +X or -X when yaw = 0).
static func _jerrycan(k: VehicleModels, p: Node3D, pos: Vector3, col: Color, yaw := 0.0) -> void:
	var t := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), pos)
	_tb(k, p, t, Vector3(0.17, 0.46, 0.34), Vector3(0, 0.23, 0), "paint", col)
	_tb(k, p, t, Vector3(0.18, 0.04, 0.2), Vector3(0, 0.3, 0), "paint", col.darkened(0.15), Vector3.ZERO, false)
	_tb(k, p, t, Vector3(0.05, 0.06, 0.1), Vector3(0, 0.49, -0.06), "gunmetal_w", null, Vector3.ZERO, false)


## A rubber-tyred road wheel (twin discs with the guide gap between them) on
## a spinning pivot, the disc painted like the hull.
static func _road_wheel(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, mat: String, col = null) -> Node3D:
	var pv := k._pivot(p, pos)
	for sx: float in [-1.0, 1.0]:
		k._cyl(pv, r, r, w * 0.42, Vector3(sx * w * 0.29, 0, 0), Z90, "rubber", null, 18)
	k._cyl(pv, r * 0.82, r * 0.82, w + 0.02, Vector3.ZERO, Z90, mat, col, 18)
	k._cyl(pv, r * 0.26, r * 0.3, w + 0.06, Vector3.ZERO, Z90, "gunmetal_w", null, 10, false)
	k.wheels.append(pv)
	return pv


## A steel idler (no tyre) on a spinning pivot.
static func _idler(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, mat: String, col = null) -> Node3D:
	var pv := k._pivot(p, pos)
	for sx: float in [-1.0, 1.0]:
		k._cyl(pv, r, r, w * 0.36, Vector3(sx * w * 0.3, 0, 0), Z90, "gunmetal_w", null, 16)
	k._cyl(pv, r * 0.78, r * 0.78, w * 0.9, Vector3.ZERO, Z90, mat, col, 16)
	k._cyl(pv, r * 0.25, r * 0.28, w + 0.06, Vector3.ZERO, Z90, "gunmetal_w", null, 10, false)
	k.wheels.append(pv)
	return pv


## A toothed drive sprocket on a spinning pivot.
static func _sprocket(k: VehicleModels, p: Node3D, pos: Vector3, r: float, w: float, mat: String, col = null) -> Node3D:
	var pv := k._pivot(p, pos)
	for sx: float in [-1.0, 1.0]:
		k._cyl(pv, r * 0.9, r * 0.9, w * 0.2, Vector3(sx * w * 0.3, 0, 0), Z90, "gunmetal_w", null, 12)
	for i in 8:
		var a := TAU * i / 8.0
		k._box(pv, Vector3(w * 0.2, r * 0.24, r * 0.2), Vector3(w * 0.3, sin(a) * r * 0.93, cos(a) * r * 0.93), "gunmetal_w", null, Vector3(-a, 0, 0), false)
	k._cyl(pv, r * 0.72, r * 0.72, w * 0.5, Vector3.ZERO, Z90, mat, col, 14)
	k._cyl(pv, r * 0.3, r * 0.34, w + 0.06, Vector3.ZERO, Z90, "gunmetal_w", null, 10, false)
	k.wheels.append(pv)
	return pv


## A track: a belt of link plates round the convex hull of its wheels (each
## circle (z, y, r)), so the road wheels show between the runs.
static func _track_belt(k: VehicleModels, p: Node3D, x: float, w: float, circles: Array, th := 0.08, segs := 16) -> void:
	var pts := PackedVector2Array()
	for c in circles:
		var cv: Vector3 = c
		var rr := cv.z + th * 0.5
		for i in segs:
			var a := TAU * (i + 0.5) / segs
			pts.append(Vector2(cv.x + cos(a) * rr, cv.y + sin(a) * rr))
	var hull := Geometry2D.convex_hull(pts)
	for i in hull.size() - 1:
		var a2 := hull[i]
		var b2 := hull[i + 1]
		var d := b2 - a2
		var l := d.length()
		if l < 0.015:
			continue
		var mid := (a2 + b2) * 0.5
		k._box(p, Vector3(w, th, l + th * 0.7), Vector3(x, mid.y, mid.x), "track", null, Vector3(atan2(-d.y, d.x), 0, 0))


# --- Strider: KMW Fennek LGS scout car ---------------------------------------------

## KMW Fennek: low and wide on four big wheels, the steep armoured nose and
## sloped twin windscreen, the cabin sides leaning in, the engine deck at the
## back with its grilles; the sensor mast behind the cabin (the scout's is
## telescopic and tall), an RCWS on the roof of the armed ones (variant 1:
## 12.7 mm HMG, 2: 40 mm GMG).
static func _strider(k: VehicleModels, team: int, variant: int) -> void:
	var pc := _paint(team)
	var cam: String = pc[0]
	var col = pc[1]
	var m := k.root
	var wr := 0.54
	var wx := 1.06
	var wz := [-1.62, 1.62]
	# the belly between the wheels (its front sloping under the nose)
	k._add(m, VehicleModels.loft("indep_str_core", _oct(-0.7, 0.7, -2.2, 2.3, 0.15), _oct(-0.84, 0.84, -2.7, 2.72, 0.1), 0.42, 1.18), cam, col, Vector3.ZERO)
	# the nose and tail blocks ahead of and behind the wheel arches, the sills between
	k._add(m, VehicleModels.loft("indep_str_nose", _oct(-1.15, 1.15, -2.62, -2.3, 0.05), _oct(-1.26, 1.26, -2.79, -2.3, 0.08), 0.62, 1.18), cam, col, Vector3.ZERO)
	k._add(m, VehicleModels.loft("indep_str_tail", _oct(-1.17, 1.17, 2.3, 2.66, 0.05), _oct(-1.26, 1.26, 2.3, 2.79, 0.08), 0.62, 1.18), cam, col, Vector3.ZERO)
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.42, 0.56, 1.88), Vector3(s * 1.04, 0.9, 0.0), cam, col)
	# the upper hull: a chine all round, then the armoured nose and windscreen
	# in one steep slope, the cabin's sides leaning in, the engine deck a step
	# lower at the back
	k._add(m, VehicleModels.loft("indep_str_hull", _oct(-1.275, 1.275, -2.79, 2.79, 0.1), _oct(-1.25, 1.25, -2.52, 2.77, 0.12), 1.18, 1.36), cam, col, Vector3.ZERO)
	k._add(m, VehicleModels.loft("indep_str_cab", _oct(-1.25, 1.25, -2.52, 1.05, 0.12), _oct(-1.02, 1.02, -1.88, 1.0, 0.1), 1.36, 1.79), cam, col, Vector3.ZERO)
	k._add(m, VehicleModels.loft("indep_str_deck", _oct(-1.25, 1.25, 0.95, 2.77, 0.12), _oct(-1.07, 1.07, 1.0, 2.5, 0.1), 1.36, 1.7), cam, col, Vector3.ZERO)
	# wheels in their dark wells, mud flaps behind the rear ones
	for s: float in [-1.0, 1.0]:
		for z in wz:
			k._box(m, Vector3(0.03, 0.5, 1.25), Vector3(s * 0.855, 0.92, z), "plain_dark", null, Vector3.ZERO, false)
			k._wheel(m, Vector3(s * wx, wr, z), wr, 0.38, cam, col)
			# the arch's lip
			k._box(m, Vector3(0.1, 0.06, 1.42), Vector3(s * 1.24, 1.16, z), cam, col)
		k._box(m, Vector3(0.32, 0.36, 0.02), Vector3(s * 1.04, 0.8, 2.3), "rubber")
	# windscreen: two armoured panes in heavy frames on the slope, the pillar between
	var ws_a := Vector2(-2.52, 1.36)
	var ws_b := Vector2(-1.88, 1.79)
	for s: float in [-1.0, 1.0]:
		_plate(k, m, s * 0.45, 0.7, ws_a.lerp(ws_b, 0.2), ws_a.lerp(ws_b, 0.86), 0.03, "glass", null, -0.008, false)
		_plate(k, m, s * 0.45, 0.8, ws_a.lerp(ws_b, 0.13), ws_a.lerp(ws_b, 0.2), 0.035, cam, col, 0.0)
	_plate(k, m, 0.0, 0.12, ws_a.lerp(ws_b, 0.13), ws_b, 0.04, cam, col, 0.0)
	# a wiper over each pane
	for s: float in [-1.0, 1.0]:
		_plate(k, m, s * 0.5, 0.025, ws_a.lerp(ws_b, 0.22), ws_a.lerp(ws_b, 0.6), 0.02, "gunmetal_w", null, 0.025, false)
	# the nose: headlight clusters in guards, tow shackles, a plate
	for s: float in [-1.0, 1.0]:
		_light(k, m, Vector3(s * 0.92, 1.02, -2.8), 0.3, 0.13)
		k._box(m, Vector3(0.1, 0.14, 0.16), Vector3(s * 0.55, 0.72, -2.62), "gunmetal_w")
		k._cyl(m, 0.05, 0.05, 0.14, Vector3(s * 0.55, 0.66, -2.7), Z90, "gunmetal_w", null, 8, false)
	k._box(m, Vector3(0.44, 0.12, 0.02), Vector3(0, 0.98, -2.8), "paint", Color(0.82, 0.8, 0.72), Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		# mirrors on their arms by the windscreen
		k._cyl(m, 0.015, 0.015, 0.32, Vector3(s * 1.3, 1.48, -2.2), Z90, "gunmetal_w", null, 6, false)
		k._box(m, Vector3(0.05, 0.24, 0.15), Vector3(s * 1.46, 1.52, -2.2), "gunmetal_w")
		k._box(m, Vector3(0.012, 0.2, 0.12), Vector3(s * 1.46, 1.52, -2.13), "glass", null, Vector3.ZERO, false)
		# the side door: seams, an armoured window, the handle, a step below
		var sl: float = s * 0.49
		k._box(m, Vector3(0.03, 0.26, 0.58), Vector3(s * 1.15, 1.57, -0.52), "glass", null, Vector3(0, 0, sl), false)
		for dz: float in [-0.92, -0.04]:
			k._box(m, Vector3(0.02, 0.54, 0.025), Vector3(s * 1.255, 0.9, dz), "gunmetal_w", null, Vector3.ZERO, false)
			k._box(m, Vector3(0.02, 0.6, 0.025), Vector3(s * 1.16, 1.5, dz), "gunmetal_w", null, Vector3(0, 0, sl), false)
		k._box(m, Vector3(0.04, 0.05, 0.16), Vector3(s * 1.27, 1.06, -0.26), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.18, 0.04, 0.5), Vector3(s * 1.18, 0.6, -0.48), "gunmetal_w")
		# a small rear-quarter window, the stowage bin over the rear wheel
		k._box(m, Vector3(0.03, 0.18, 0.26), Vector3(s * 1.15, 1.57, 0.55), "glass", null, Vector3(0, 0, sl), false)
		k._box(m, Vector3(0.16, 0.3, 0.9), Vector3(s * 1.33, 1.3, 1.85), cam, col)
		k._box(m, Vector3(0.02, 0.04, 0.9), Vector3(s * 1.415, 1.38, 1.85), "gunmetal_w", null, Vector3.ZERO, false)
		# smoke dischargers on the deck corners, a whip antenna at each back corner
		_smoke(k, m, Vector3(s * 0.88, 1.72, 1.15), 3, s * -0.6)
		_antenna(k, m, Vector3(s * 0.95, 1.7, 2.4), 2.1)
		# rear: tail light clusters, the jerrycan rack on the left, a box on the right
		_light(k, m, Vector3(s * 1.0, 1.25, 2.8), 0.22, 0.1, 1.0, false, true)
	_jerrycan(k, m, Vector3(-0.55, 0.62, 2.98), Color(0.3, 0.33, 0.23), PI / 2)
	_jerrycan(k, m, Vector3(-0.32, 0.62, 2.98), Color(0.3, 0.33, 0.23), PI / 2)
	k._box(m, Vector3(0.55, 0.06, 0.4), Vector3(-0.44, 0.6, 2.98), "gunmetal_w")
	k._box(m, Vector3(0.6, 0.38, 0.3), Vector3(0.5, 0.86, 2.95), cam, col)
	k._box(m, Vector3(0.16, 0.14, 0.18), Vector3(0, 0.66, 2.86), "gunmetal_w")
	k._cyl(m, 0.06, 0.06, 0.12, Vector3(0, 0.66, 2.96), X90, "gunmetal_w", null, 8, false)
	# exhaust out of the right flank behind the rear wheel, under a heat shield
	k._box(m, Vector3(0.12, 0.2, 0.4), Vector3(1.3, 1.0, 2.5), "gunmetal_w")
	k._cyl(m, 0.06, 0.06, 0.18, Vector3(1.36, 0.9, 2.62), Z90, "metal_dark", null, 8, false)
	# roof: the driver's and commander's hatches with periscopes, the
	# observer's hatch behind
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.6, 0.06, 0.6), Vector3(s * 0.48, 1.81, -1.3), cam, col)
		k._box(m, Vector3(0.08, 0.05, 0.08), Vector3(s * 0.48 + 0.2, 1.85, -1.08), "gunmetal_w", null, Vector3.ZERO, false)
		for i in 3:
			k._box(m, Vector3(0.14, 0.08, 0.06), Vector3(s * 0.48 + (i - 1) * 0.18, 1.83, -1.7), "glass", null, Vector3(-0.3, 0, 0), false)
	k._box(m, Vector3(0.55, 0.05, 0.5), Vector3(-0.45, 1.81, 0.55), cam, col)
	# engine deck: two grilles with their slats
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.8, 0.03, 1.2), Vector3(s * 0.5, 1.705, 1.75), "gunmetal_w")
		for i in 4:
			k._box(m, Vector3(0.78, 0.03, 0.05), Vector3(s * 0.5, 1.725, 1.27 + i * 0.32), cam, col, Vector3.ZERO, false)
	_tow_eyes(k, m, 2.84, 0.72)
	k._team_mark(m, team, Vector3(1.275, 0.9, 0.5), Vector3(0.03, 0.22, 0.6))
	k._team_mark(m, team, Vector3(-1.275, 0.9, 0.5), Vector3(0.03, 0.22, 0.6))
	if variant == 0:
		# the scout: the BAA sensor head (camera, thermal imager, rangefinder)
		# high on a telescopic mast behind the cabin; the head pans
		k._box(m, Vector3(0.36, 0.14, 0.36), Vector3(0.0, 1.86, 0.72), "gunmetal_w")
		k._cyl(m, 0.1, 0.11, 0.55, Vector3(0, 2.1, 0.72), Vector3.ZERO, cam, col, 12)
		k._cyl(m, 0.075, 0.075, 0.55, Vector3(0, 2.62, 0.72), Vector3.ZERO, "gunmetal_w", null, 10)
		k._cyl(m, 0.055, 0.055, 0.5, Vector3(0, 3.1, 0.72), Vector3.ZERO, "gunmetal_w", null, 10)
		for i in 3:
			k._cyl(m, 0.09 - i * 0.02, 0.09 - i * 0.02, 0.04, Vector3(0, 2.38 + i * 0.52, 0.72), Vector3.ZERO, "gunmetal_w", null, 10, false)
		k.turret = k._pivot(m, Vector3(0, 3.35, 0.72))
		_sensor_head(k, k.turret, Vector3(0, 0.12, 0), cam, col, 1.0)
	else:
		# the commander's periscope mast, folded low at the cabin's back corner
		k._cyl(m, 0.05, 0.06, 0.32, Vector3(0.72, 1.95, 0.75), Vector3.ZERO, "gunmetal_w", null, 10)
		_sensor_head(k, m, Vector3(0.72, 2.16, 0.75), cam, col, 0.7)
		_rcws(k, m, Vector3(0, 1.79, 0.1), variant == 2, cam, col, 0.9)


## Tow eyes and a pintle under the back.
static func _tow_eyes(k: VehicleModels, p: Node3D, z: float, y: float) -> void:
	for s: float in [-1.0, 1.0]:
		k._box(p, Vector3(0.08, 0.12, 0.12), Vector3(s * 0.6, y, z), "gunmetal_w")
		k._cyl(p, 0.045, 0.045, 0.12, Vector3(s * 0.6, y - 0.05, z + 0.06), Z90, "gunmetal_w", null, 8, false)


## An electro-optical sensor head: a box with a camera window, a thermal
## imager's round lens and the rangefinder's, facing -Z.
static func _sensor_head(k: VehicleModels, p: Node3D, pos: Vector3, cam: String, col, sc := 1.0) -> void:
	k._box(p, Vector3(0.5, 0.26, 0.3) * sc, pos, cam, col)
	k._box(p, Vector3(0.54, 0.03, 0.34) * sc, pos + Vector3(0, 0.145, 0) * sc, cam, col)
	k._box(p, Vector3(0.14, 0.12, 0.02) * sc, pos + Vector3(-0.14, 0.01, -0.155) * sc, "glass", null, Vector3.ZERO, false)
	k._cyl(p, 0.06 * sc, 0.06 * sc, 0.03 * sc, pos + Vector3(0.05, 0.01, -0.155) * sc, X90, "glass", null, 12, false)
	k._cyl(p, 0.035 * sc, 0.035 * sc, 0.03 * sc, pos + Vector3(0.18, 0.04, -0.155) * sc, X90, "glass", null, 10, false)
	k._box(p, Vector3(0.12, 0.2, 0.12) * sc, pos + Vector3(0, -0.2, 0.02) * sc, "gunmetal_w")


## A remote weapon station (FLW-style): a turntable, the cradle between two
## yoke arms with the 12.7 mm HMG or the 40 mm GMG, the ammunition box on one
## side and the sight on the other. Sets k.turret and k.mg_tip.
static func _rcws(k: VehicleModels, p: Node3D, pos: Vector3, gmg: bool, cam: String, col, sc := 1.0) -> void:
	var t := k._pivot(p, pos)
	k.turret = t
	k._cyl(t, 0.32 * sc, 0.35 * sc, 0.08 * sc, Vector3(0, 0.04, 0) * sc, Vector3.ZERO, "gunmetal_w", null, 16)
	k._add(t, VehicleModels.loft("indep_rcws_base", _oct(-0.26, 0.26, -0.28, 0.3, 0.06), _oct(-0.22, 0.22, -0.2, 0.26, 0.05), 0.0, 0.2), cam, col, Vector3(0, 0.08, 0) * sc, Vector3.ZERO, Vector3.ONE * sc)
	for s: float in [-1.0, 1.0]:
		k._box(t, Vector3(0.06, 0.3, 0.26) * sc, Vector3(s * 0.2, 0.38, 0.0) * sc, cam, col)
	k._cyl(t, 0.05 * sc, 0.05 * sc, 0.46 * sc, Vector3(0, 0.44, 0) * sc, Z90, "gunmetal_w", null, 10, false)
	# the sight box on the right, the ammo box on the left
	k._box(t, Vector3(0.16, 0.2, 0.3) * sc, Vector3(0.34, 0.46, -0.05) * sc, cam, col)
	k._box(t, Vector3(0.11, 0.09, 0.02) * sc, Vector3(0.34, 0.48, -0.205) * sc, "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.035 * sc, 0.035 * sc, 0.02 * sc, Vector3(0.34, 0.39, -0.205) * sc, X90, "glass", null, 10, false)
	if gmg:
		# HK GMG: a squat receiver, a short thick barrel, the big belt box
		k._box(t, Vector3(0.24, 0.22, 0.62) * sc, Vector3(0, 0.46, 0.0) * sc, "gunmetal_w")
		k._box(t, Vector3(0.18, 0.08, 0.3) * sc, Vector3(0, 0.6, 0.08) * sc, "gunmetal_w")
		k._cyl(t, 0.06 * sc, 0.06 * sc, 0.36 * sc, Vector3(0, 0.46, -0.48) * sc, X90, "gunmetal_w", null, 10)
		k._cyl(t, 0.075 * sc, 0.07 * sc, 0.12 * sc, Vector3(0, 0.46, -0.7) * sc, X90, "gunmetal_w", null, 10)
		k._box(t, Vector3(0.22, 0.26, 0.36) * sc, Vector3(-0.36, 0.44, 0.04) * sc, "paint", Color(0.3, 0.33, 0.23))
		k.mg_tip = k._tip(t, Vector3(0, 0.46, -0.78) * sc)
	else:
		# M2: the long receiver, the barrel with its carrying handle, flash hider
		k._box(t, Vector3(0.15, 0.17, 0.72) * sc, Vector3(0, 0.46, 0.02) * sc, "gunmetal_w")
		k._cyl(t, 0.042 * sc, 0.042 * sc, 0.22 * sc, Vector3(0, 0.46, -0.44) * sc, X90, "gunmetal_w", null, 10)
		k._cyl(t, 0.026 * sc, 0.026 * sc, 1.0 * sc, Vector3(0, 0.46, -0.95) * sc, X90, "gunmetal_w", null, 8)
		k._cyl(t, 0.036 * sc, 0.03 * sc, 0.1 * sc, Vector3(0, 0.46, -1.48) * sc, X90, "gunmetal_w", null, 8, false)
		k._box(t, Vector3(0.03, 0.08, 0.14) * sc, Vector3(0, 0.55, -0.52) * sc, "gunmetal_w", null, Vector3.ZERO, false)
		k._box(t, Vector3(0.17, 0.22, 0.3) * sc, Vector3(-0.32, 0.44, 0.04) * sc, "paint", Color(0.3, 0.33, 0.23))
		k.mg_tip = k._tip(t, Vector3(0, 0.46, -1.54) * sc)


## A slat cage panel: top and bottom rails, end posts and the vertical slats,
## centred at c; along X (a rear cage) or along Z (a side cage).
static func _slats(k: VehicleModels, p: Node3D, c: Vector3, l: float, h: float, along_x: bool, gap := 0.17) -> void:
	var n := int(l / gap)
	var ax := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var rail := Vector3(l, 0.045, 0.045) if along_x else Vector3(0.045, 0.045, l)
	for e: float in [-0.5, 0.5]:
		k._box(p, rail, c + Vector3(0, e * h, 0), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(p, Vector3(0.05, h, 0.05), c + ax * (e * l), "gunmetal_w", null, Vector3.ZERO, false)
	var bar := Vector3(0.018, h, 0.07) if along_x else Vector3(0.07, h, 0.018)
	for i in range(1, n):
		k._box(p, bar, c + ax * (-0.5 * l + l * i / float(n)), "gunmetal_w", null, Vector3.ZERO, false)


## A track set on one side: road wheels, sprocket, idler, return rollers and
## the belt round them all. side -1 / +1; rw the road wheels' z; sprocket and
## idler as (z, y, r).
static func _running_gear(k: VehicleModels, side: float, x: float, tw: float, rw: Array, rr: float, sprocket: Vector3, idler: Vector3, rollers: Array, roller_y: float, th: float, cam: String, col) -> void:
	var m := k.root
	var wy := rr + th
	var circles := []
	for z in rw:
		_road_wheel(k, m, Vector3(side * x, wy, z), rr, tw * 0.86, cam, col)
		circles.append(Vector3(z, wy, rr))
	_sprocket(k, m, Vector3(side * x, sprocket.y, sprocket.x), sprocket.z, tw * 0.8, cam, col)
	_idler(k, m, Vector3(side * x, idler.y, idler.x), idler.z, tw * 0.8, cam, col)
	circles.append(sprocket)
	circles.append(idler)
	for z in rollers:
		k._cyl(m, 0.075, 0.075, tw * 0.6, Vector3(side * x, roller_y, z), Z90, "gunmetal_w", null, 10)
		circles.append(Vector3(z, roller_y, 0.075))
	_track_belt(k, m, side * x, tw, circles, th)


# --- Mora: BAE FV510 Warrior ---------------------------------------------------------

## FV510 Warrior: a big slab-sided box on six road wheels a side under deep
## skirts, the long glacis with the driver front-left and the engine louvres
## front-right, the two-man turret in the middle with the long thin 30 mm
## RARDEN and its four-barrel smoke dischargers, the big rear door between
## two stowage bins.
static func _mora(k: VehicleModels, team: int) -> void:
	var pc := _paint(team)
	var cam: String = pc[0]
	var col = pc[1]
	var m := k.root
	# running gear: front sprocket, six road wheels, rear idler, three rollers
	var rw := []
	for i in 6:
		rw.append(-2.0 + i * 0.78)
	for s: float in [-1.0, 1.0]:
		_running_gear(k, s, 1.2, 0.46, rw, 0.31, Vector3(-2.74, 0.66, 0.27), Vector3(2.62, 0.6, 0.26), [-1.6, -0.1, 1.4], 0.86, 0.08, cam, col)
	# the hull: belly between the tracks, the upper hull out over them with
	# the long glacis
	k._add(m, VehicleModels.loft("indep_mora_low", _oct(-0.9, 0.9, -2.72, 2.95, 0.1), _oct(-0.96, 0.96, -3.15, 3.15, 0.1), 0.42, 1.02), cam, col, Vector3.ZERO)
	k._add(m, VehicleModels.solid([_ring(_oct(-1.45, 1.45, -3.17, 3.17, 0.06), 1.0), _ring(_oct(-1.45, 1.45, -3.0, 3.17, 0.06), 1.12), _ring(_oct(-1.43, 1.43, -2.05, 3.15, 0.05), 1.93)], "indep_mora_up"), cam, col, Vector3.ZERO)
	# skirts: five bolted panels a side, the front one raked
	for s: float in [-1.0, 1.0]:
		for i in 5:
			k._box(m, Vector3(0.05, 0.44, 1.08), Vector3(s * 1.49, 0.8, -1.9 + i * 1.1), cam, col)
			k._box(m, Vector3(0.02, 0.03, 1.0), Vector3(s * 1.52, 0.98, -1.9 + i * 1.1), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.05, 0.36, 0.6), Vector3(s * 1.49, 0.86, -2.78), cam, col, Vector3(-0.45, 0, 0))
		# the hull's side seam at the deck line, a stowage box aft
		k._box(m, Vector3(0.04, 0.05, 6.1), Vector3(s * 1.45, 1.5, 0.05), cam, col)
		k._box(m, Vector3(0.22, 0.38, 1.1), Vector3(s * 1.52, 1.45, 2.2), cam, col)
		# headlight clusters in guards on the glacis corners, tow hooks
		_light(k, m, Vector3(s * 1.16, 1.22, -3.08), 0.26, 0.12)
		k._box(m, Vector3(0.12, 0.16, 0.18), Vector3(s * 0.62, 0.92, -3.18), "gunmetal_w")
		k._cyl(m, 0.05, 0.05, 0.16, Vector3(s * 0.62, 0.86, -3.27), Z90, "gunmetal_w", null, 8, false)
	# glacis: the driver's hatch and vision blocks front-left, the engine
	# louvres front-right, lifting eyes
	var ga := Vector2(-3.0, 1.12)
	var gb := Vector2(-2.05, 1.93)
	k._box(m, Vector3(0.62, 0.06, 0.66), Vector3(-0.72, 1.95, -1.68), cam, col)
	for i in 3:
		k._box(m, Vector3(0.15, 0.08, 0.06), Vector3(-0.9 + i * 0.18, 1.94, -2.06), "glass", null, Vector3(-0.4, 0, 0), false)
	_plate(k, m, 0.62, 1.3, ga.lerp(gb, 0.3), ga.lerp(gb, 0.95), 0.03, "gunmetal_w", null, 0.0)
	for i in 6:
		_plate(k, m, 0.62, 1.26, ga.lerp(gb, 0.33 + i * 0.1), ga.lerp(gb, 0.37 + i * 0.1), 0.03, cam, col, 0.02, false)
	k._box(m, Vector3(1.0, 0.03, 0.7), Vector3(0.62, 1.945, -1.6), "gunmetal_w")
	for i in 4:
		k._box(m, Vector3(0.98, 0.03, 0.05), Vector3(0.62, 1.965, -1.85 + i * 0.17), cam, col, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.08, 0.1, 0.12), Vector3(s * 1.2, 1.97, -1.95), "gunmetal_w", null, Vector3.ZERO, false)
	# exhaust: the louvred outlet on the right flank, forward
	k._box(m, Vector3(0.1, 0.36, 0.6), Vector3(1.48, 1.62, -1.85), "gunmetal_w")
	for i in 3:
		k._box(m, Vector3(0.04, 0.03, 0.56), Vector3(1.54, 1.52 + i * 0.1, -1.85), cam, col, Vector3.ZERO, false)
	# roof: the troop compartment's long hatch, a vent, antennas at the back
	k._box(m, Vector3(1.5, 0.06, 1.2), Vector3(0, 1.96, 2.15), cam, col)
	k._box(m, Vector3(0.04, 0.04, 1.1), Vector3(0, 2.0, 2.15), "gunmetal_w", null, Vector3.ZERO, false)
	k._cyl(m, 0.12, 0.14, 0.12, Vector3(-0.95, 1.99, 1.35), Vector3.ZERO, "gunmetal_w", null, 10)
	# rear: the big door with its vision block and handles, a stowage bin
	# either side of it, tail lights, the tow pintle
	k._box(m, Vector3(1.0, 1.15, 0.08), Vector3(0.12, 1.4, 3.2), cam, col)
	k._box(m, Vector3(0.18, 0.1, 0.04), Vector3(0.12, 1.75, 3.25), "glass", null, Vector3.ZERO, false)
	for hy: float in [1.05, 1.75]:
		k._cyl(m, 0.04, 0.04, 0.16, Vector3(-0.4, hy, 3.24), Vector3.ZERO, "gunmetal_w", null, 8, false)
	k._box(m, Vector3(0.05, 0.05, 0.2), Vector3(0.52, 1.35, 3.28), "gunmetal_w", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		var bx: float = s * 1.08 + (0.0 if s < 0.0 else 0.06)
		k._box(m, Vector3(0.62 if s < 0.0 else 0.5, 0.78, 0.42), Vector3(bx, 1.36, 3.38), cam, col)
		k._box(m, Vector3(0.5 if s < 0.0 else 0.4, 0.04, 0.03), Vector3(bx, 1.66, 3.6), "gunmetal_w", null, Vector3.ZERO, false)
		_light(k, m, Vector3(s * 1.1, 0.88, 3.24), 0.22, 0.1, 1.0, false, true)
	k._box(m, Vector3(0.16, 0.14, 0.2), Vector3(0, 0.82, 3.22), "gunmetal_w")
	k._cyl(m, 0.06, 0.06, 0.12, Vector3(0, 0.82, 3.33), X90, "gunmetal_w", null, 8, false)
	k._team_mark(m, team, Vector3(1.46, 1.3, 0.9), Vector3(0.03, 0.26, 0.7))
	k._team_mark(m, team, Vector3(-1.46, 1.3, 0.9), Vector3(0.03, 0.26, 0.7))
	# the turret: faceted, the RARDEN in its narrow mantlet, the chain gun
	# beside it, sights and hatches on the roof
	var t := k._pivot(m, Vector3(0, 1.93, -0.25))
	k.turret = t
	k._cyl(t, 1.0, 1.02, 0.08, Vector3(0, 0.04, 0.1), Vector3.ZERO, "gunmetal_w", null, 20)
	var tb := [-0.55, -1.22, 0.55, -1.22, 1.05, -0.72, 1.1, 0.95, 0.85, 1.18, -0.85, 1.18, -1.1, 0.95, -1.05, -0.72]
	var tt := [-0.42, -0.88, 0.42, -0.88, 0.86, -0.5, 0.93, 0.85, 0.72, 1.04, -0.72, 1.04, -0.93, 0.85, -0.86, -0.5]
	k._add(t, VehicleModels.loft("indep_mora_tur", tb, tt, 0.06, 0.74), cam, col, Vector3.ZERO)
	k._box(t, Vector3(0.36, 0.4, 0.4), Vector3(0, 0.4, -1.18), cam, col)
	k._cyl(t, 0.075, 0.075, 0.5, Vector3(0, 0.4, -1.55), X90, "gunmetal_w", null, 10)
	k._cyl(t, 0.045, 0.045, 2.2, Vector3(0, 0.4, -2.85), X90, "gunmetal_w", null, 10)
	k._cyl(t, 0.065, 0.06, 0.22, Vector3(0, 0.4, -4.0), X90, "gunmetal_w", null, 10)
	k.mg_tip = k._tip(t, Vector3(0, 0.4, -4.14))
	k._cyl(t, 0.02, 0.02, 0.5, Vector3(-0.3, 0.3, -1.45), X90, "gunmetal_w", null, 6, false)
	# gunner's sight left, the commander's sight right, two hatches
	k._box(t, Vector3(0.32, 0.2, 0.4), Vector3(-0.45, 0.8, -0.42), cam, col)
	k._box(t, Vector3(0.24, 0.11, 0.02), Vector3(-0.45, 0.82, -0.63), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.14, 0.16, 0.12, Vector3(0.48, 0.79, -0.2), Vector3.ZERO, cam, col, 12)
	k._box(t, Vector3(0.26, 0.15, 0.28), Vector3(0.48, 0.92, -0.22), cam, col)
	k._box(t, Vector3(0.18, 0.09, 0.02), Vector3(0.48, 0.93, -0.37), "glass", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		k._cyl(t, 0.3, 0.3, 0.07, Vector3(s * 0.42, 0.77, 0.45), Vector3.ZERO, cam, col, 14)
		k._box(t, Vector3(0.08, 0.05, 0.08), Vector3(s * 0.42, 0.82, 0.68), "gunmetal_w", null, Vector3.ZERO, false)
		# four-barrel smoke dischargers on the front corners
		_smoke(k, t, Vector3(s * 0.98, 0.52, -0.68), 4, s * -0.55, 0.5, 0.05)
		_antenna(k, t, Vector3(s * 0.7, 0.74, 0.9), 1.9)
	# the bustle: a stowage basket with a rolled tarp and kit in it
	k._box(t, Vector3(1.6, 0.05, 0.55), Vector3(0, 0.3, 1.42), "gunmetal_w")
	k._box(t, Vector3(1.6, 0.4, 0.04), Vector3(0, 0.5, 1.7), "gunmetal_w")
	for s: float in [-1.0, 1.0]:
		k._box(t, Vector3(0.04, 0.4, 0.55), Vector3(s * 0.8, 0.5, 1.42), "gunmetal_w")
	k._cyl(t, 0.16, 0.16, 1.3, Vector3(0, 0.5, 1.45), Z90, "canvas", Color(0.33, 0.35, 0.24), 10)
	k._box(t, Vector3(0.42, 0.3, 0.3), Vector3(0.55, 0.55, 1.5), "canvas", Color(0.38, 0.37, 0.27))


# --- Kuma: Leopard 2 with the Revolution urban upgrade --------------------------

## Leopard 2 "Revolution": the long low hull with its shallow upper glacis,
## seven road wheels a side under armoured skirts, the rear engine deck; the
## boxy wedge-free 2A4 turret made boxier still by flat bolt-on armour on its
## cheeks and sides, the EMES sight doghouse and the PERI periscope on the
## roof, a remote .50 over the loader, slat cages round the turret bustle and
## the hull's back, and the long 120 mm with its thermal sleeve.
static func _kuma(k: VehicleModels, team: int) -> void:
	var pc := _paint(team)
	var cam: String = pc[0]
	var col = pc[1]
	var m := k.root
	# running gear: front idler, seven road wheels, rear sprocket, four rollers
	var rw := []
	for i in 7:
		rw.append(-2.58 + i * 0.86)
	for s: float in [-1.0, 1.0]:
		_running_gear(k, s, 1.38, 0.62, rw, 0.35, Vector3(3.3, 0.72, 0.32), Vector3(-3.3, 0.68, 0.3), [-1.92, -0.64, 0.64, 1.92], 0.91, 0.1, cam, col)
	# hull: the belly between the tracks (the lower glacis its front), the
	# upper hull out over the tracks with the long shallow upper glacis
	k._add(m, VehicleModels.loft("indep_kuma_low", _oct(-1.02, 1.02, -3.25, 3.5, 0.1), _oct(-1.06, 1.06, -3.86, 3.84, 0.1), 0.48, 1.12), cam, col, Vector3.ZERO)
	k._add(m, VehicleModels.solid([_ring(_oct(-1.76, 1.76, -3.86, 3.86, 0.05), 1.12), _ring(_oct(-1.76, 1.76, -3.72, 3.86, 0.05), 1.24), _ring(_oct(-1.74, 1.74, -2.5, 3.82, 0.05), 1.68)], "indep_kuma_up"), cam, col, Vector3.ZERO)
	var ga := Vector2(-3.72, 1.24)
	var gb := Vector2(-2.5, 1.68)
	# a bolted add-on plate over the glacis, the driver's hatch front-right
	_plate(k, m, -0.35, 2.2, ga.lerp(gb, 0.12), ga.lerp(gb, 0.8), 0.06, cam, col, 0.0)
	k._box(m, Vector3(0.7, 0.06, 0.62), Vector3(0.82, 1.7, -2.15), cam, col)
	for i in 3:
		k._box(m, Vector3(0.16, 0.08, 0.06), Vector3(0.64 + i * 0.18, 1.69, -2.5), "glass", null, Vector3(-0.5, 0, 0), false)
	for s: float in [-1.0, 1.0]:
		# headlight clusters with guards on the front corners, tow eyes
		_light(k, m, Vector3(s * 1.45, 1.36, -3.6), 0.3, 0.13)
		k._box(m, Vector3(0.14, 0.18, 0.2), Vector3(s * 0.72, 1.02, -3.88), "gunmetal_w")
		k._cyl(m, 0.055, 0.055, 0.18, Vector3(s * 0.72, 0.96, -3.98), Z90, "gunmetal_w", null, 8, false)
		# skirts: three heavy armour modules forward, three light panels aft,
		# the bow panel raked
		for i in 6:
			var heavy := i < 3
			var sz := -2.62 + i * 1.08
			k._box(m, Vector3(0.14 if heavy else 0.06, 0.52, 1.06), Vector3(s * (1.83 if heavy else 1.8), 0.88, sz), cam, col)
			if heavy:
				k._box(m, Vector3(0.02, 0.03, 0.9), Vector3(s * 1.905, 1.06, sz), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.14, 0.4, 0.56), Vector3(s * 1.83, 0.96, -3.48), cam, col, Vector3(-0.5, 0, 0))
		# the hull's sides: a stowage box and the tool rack above the skirts
		k._box(m, Vector3(0.12, 0.3, 1.2), Vector3(s * 1.8, 1.4, 2.6), cam, col)
		k._cyl(m, 0.03, 0.03, 2.4, Vector3(s * 1.79, 1.5, 0.1), X90, "gunmetal_w", null, 6, false)
		# engine deck grilles either side of the centre access panel
		k._box(m, Vector3(1.2, 0.03, 1.5), Vector3(s * 0.85, 1.695, 2.65), "gunmetal_w")
		for i in 5:
			k._box(m, Vector3(1.18, 0.03, 0.05), Vector3(s * 0.85, 1.715, 2.03 + i * 0.31), cam, col, Vector3.ZERO, false)
		# rear: tail lights, tow eyes
		_light(k, m, Vector3(s * 1.4, 1.4, 3.88), 0.22, 0.1, 1.0, false, true)
		k._box(m, Vector3(0.14, 0.18, 0.2), Vector3(s * 0.8, 1.0, 3.88), "gunmetal_w")
	k._box(m, Vector3(0.5, 0.05, 1.5), Vector3(0, 1.69, 2.65), cam, col)
	# the exhaust louvres across the top of the rear plate, the slat cage
	# standing off the back on its struts
	k._box(m, Vector3(2.8, 0.26, 0.06), Vector3(0, 1.5, 3.88), "gunmetal_w")
	for i in 3:
		k._box(m, Vector3(2.76, 0.03, 0.05), Vector3(0, 1.41 + i * 0.09, 3.92), cam, col, Vector3.ZERO, false)
	_slats(k, m, Vector3(0, 1.22, 4.18), 3.3, 0.8, true, 0.26)
	for sx: float in [-1.2, 0.0, 1.2]:
		k._box(m, Vector3(0.05, 0.05, 0.32), Vector3(sx, 1.0, 4.02), "gunmetal_w", null, Vector3.ZERO, false)
	k._team_mark(m, team, Vector3(1.81, 1.4, 1.2), Vector3(0.03, 0.22, 0.7))
	k._team_mark(m, team, Vector3(-1.81, 1.4, 1.2), Vector3(0.03, 0.22, 0.7))
	# the turret, its front cheeks just behind the glacis
	var t := k._pivot(m, Vector3(0, 1.68, 0.15))
	k.turret = t
	k._cyl(t, 1.2, 1.22, 0.08, Vector3(0, 0.02, 0.0), Vector3.ZERO, "gunmetal_w", null, 22)
	var tb := [-1.25, -1.98, 1.25, -1.98, 1.66, -1.5, 1.66, 1.1, 1.42, 2.05, -1.42, 2.05, -1.66, 1.1, -1.66, -1.5]
	var tt := [-1.2, -1.92, 1.2, -1.92, 1.6, -1.45, 1.6, 1.06, 1.36, 1.98, -1.36, 1.98, -1.6, 1.06, -1.6, -1.45]
	k._add(t, VehicleModels.loft("indep_kuma_tur", tb, tt, 0.0, 0.86), cam, col, Vector3.ZERO)
	# bolt-on armour: flat slabs on the cheeks either side of the mantlet and
	# along the sides
	for s: float in [-1.0, 1.0]:
		k._box(t, Vector3(1.42, 0.82, 0.26), Vector3(s * 1.08, 0.43, -2.1), cam, col)
		k._box(t, Vector3(0.02, 0.78, 0.02), Vector3(s * 1.08, 0.43, -2.235), "gunmetal_w", null, Vector3.ZERO, false)
		for bx: float in [0.6, 1.55]:
			for by: float in [0.15, 0.72]:
				k._cyl(t, 0.03, 0.03, 0.02, Vector3(s * bx, by, -2.235), X90, "gunmetal_w", null, 6, false)
		k._box(t, Vector3(0.14, 0.76, 2.95), Vector3(s * 1.72, 0.43, -0.5), cam, col)
		k._box(t, Vector3(0.02, 0.72, 0.02), Vector3(s * 1.795, 0.43, -0.5), "gunmetal_w", null, Vector3.ZERO, false)
		for i in 4:
			k._cyl(t, 0.03, 0.03, 0.02, Vector3(s * 1.795, 0.72, -1.75 + i * 0.85), Z90, "gunmetal_w", null, 6, false)
		k._team_mark(t, team, Vector3(s * 1.8, 0.34, 0.25), Vector3(0.03, 0.22, 0.7))
		# smoke dischargers: a group of four on each side, aft
		_smoke(k, t, Vector3(s * 1.62, 0.92, 1.12), 4, s * -1.05, 0.5, 0.05)
		_antenna(k, t, Vector3(s * 1.1, 0.86, 1.75), 2.2)
	# the gun: mantlet, thermal sleeve, fume extractor, muzzle reference sensor
	var gc := Color(0.31, 0.34, 0.25)
	k._box(t, Vector3(0.62, 0.54, 0.36), Vector3(0, 0.42, -2.06), cam, col)
	k._cyl(t, 0.2, 0.22, 0.2, Vector3(0, 0.42, -2.32), X90, cam, col, 14)
	k._cyl(t, 0.12, 0.12, 1.1, Vector3(0, 0.42, -2.97), X90, "paint", gc, 14)
	k._cyl(t, 0.165, 0.165, 0.7, Vector3(0, 0.42, -3.87), X90, "paint", gc, 14)
	k._cyl(t, 0.105, 0.105, 1.62, Vector3(0, 0.42, -5.03), X90, "paint", gc, 14)
	for bz: float in [-3.52, -4.22, -5.03]:
		k._cyl(t, 0.13, 0.13, 0.04, Vector3(0, 0.42, bz), X90, "gunmetal_w", null, 14, false)
	k._cyl(t, 0.095, 0.1, 0.14, Vector3(0, 0.42, -5.91), X90, "gunmetal_w", null, 12)
	k._box(t, Vector3(0.06, 0.07, 0.1), Vector3(0, 0.55, -5.78), "gunmetal_w", null, Vector3.ZERO, false)
	k.gun_tip = k._tip(t, Vector3(0, 0.42, -6.0))
	# the coaxial MG left of the gun
	k._cyl(t, 0.022, 0.022, 0.3, Vector3(-0.345, 0.3, -2.3), X90, "gunmetal_w", null, 6, false)
	var coax := k._tip(t, Vector3(-0.345, 0.3, -2.46))
	# roof: the EMES gunner's sight doghouse front-right, the PERI periscope
	# behind it, the commander's and loader's hatches, the wind sensor
	k._box(t, Vector3(0.6, 0.4, 0.78), Vector3(0.92, 1.04, -1.42), cam, col)
	k._box(t, Vector3(0.42, 0.18, 0.02), Vector3(0.92, 1.06, -1.82), "glass", null, Vector3.ZERO, false)
	k._box(t, Vector3(0.64, 0.04, 0.82), Vector3(0.92, 1.25, -1.42), cam, col)
	k._box(t, Vector3(0.34, 0.1, 0.34), Vector3(0.48, 0.91, -0.55), cam, col)
	k._cyl(t, 0.17, 0.17, 0.3, Vector3(0.48, 1.11, -0.55), Vector3.ZERO, "gunmetal_w", null, 14)
	k._cyl(t, 0.19, 0.19, 0.04, Vector3(0.48, 1.28, -0.55), Vector3.ZERO, "gunmetal_w", null, 14)
	k._box(t, Vector3(0.2, 0.12, 0.02), Vector3(0.48, 1.14, -0.72), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.36, 0.38, 0.12, Vector3(0.62, 0.92, 0.25), Vector3.ZERO, cam, col, 16)
	for i in 5:
		var a := -0.9 + i * 0.45
		k._box(t, Vector3(0.12, 0.08, 0.05), Vector3(0.62 + sin(a) * 0.4, 0.94, 0.25 - cos(a) * 0.4), "glass", null, Vector3(0, -a, 0), false)
	k._box(t, Vector3(0.62, 0.06, 0.62), Vector3(-0.62, 0.89, -0.35), cam, col)
	k._cyl(t, 0.03, 0.03, 0.45, Vector3(0.0, 1.08, 1.55), Vector3.ZERO, "gunmetal_w", null, 6, false)
	k._box(t, Vector3(0.1, 0.06, 0.1), Vector3(0.0, 1.32, 1.55), "gunmetal_w", null, Vector3.ZERO, false)
	# the bustle's stowage basket, the slat cage round it on its struts
	k._box(t, Vector3(2.6, 0.05, 0.5), Vector3(0, 0.24, 2.3), "gunmetal_w")
	k._box(t, Vector3(2.6, 0.44, 0.04), Vector3(0, 0.46, 2.55), "gunmetal_w")
	k._cyl(t, 0.17, 0.17, 1.6, Vector3(-0.4, 0.44, 2.3), Z90, "canvas", Color(0.33, 0.35, 0.24), 10)
	k._box(t, Vector3(0.6, 0.32, 0.38), Vector3(0.85, 0.44, 2.3), "canvas", Color(0.38, 0.37, 0.27))
	_slats(k, t, Vector3(0, 0.46, 2.8), 3.3, 0.78, true, 0.26)
	for s: float in [-1.0, 1.0]:
		_slats(k, t, Vector3(s * 1.86, 0.46, 1.9), 1.8, 0.78, false, 0.26)
		k._box(t, Vector3(0.22, 0.05, 0.05), Vector3(s * 1.74, 0.64, 1.1), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(t, Vector3(0.05, 0.05, 0.3), Vector3(s * 1.4, 0.64, 2.65), "gunmetal_w", null, Vector3.ZERO, false)
	# a remote .50 over the loader's hatch
	_rcws(k, t, Vector3(-0.72, 0.86, 0.45), false, cam, col, 0.85)
	k.turret = t
	k.mg_tip = coax


# --- Nyx: Rheinmetall Wiesel AWC tankette -----------------------------------------

## Wiesel: a tiny box on four road wheels a side, the long shallow glacis with
## the driver's hatch front-left and the engine grilles front-right, the
## weapon mount at the back of the roof. kind: "ac" (open 20 mm cannon
## mount), "at" (twin missile launcher and a .50), "aa" (two four-round
## Stinger-class pods and a .50) or "recon" (radar and a periscope mast).
static func _nyx(k: VehicleModels, team: int, kind: String) -> void:
	var pc := _paint(team)
	var cam: String = pc[0]
	var col = pc[1]
	var m := k.root
	for s: float in [-1.0, 1.0]:
		_running_gear(k, s, 0.72, 0.26, [-0.95, -0.38, 0.19, 0.76], 0.19, Vector3(-1.42, 0.46, 0.18), Vector3(1.38, 0.38, 0.19), [-0.1], 0.53, 0.05, cam, col)
	# hull: the belly between the tracks, the upper hull over them with the
	# long glacis
	k._add(m, VehicleModels.loft("indep_nyx_low", _oct(-0.55, 0.55, -1.38, 1.5, 0.06), _oct(-0.58, 0.58, -1.77, 1.76, 0.06), 0.28, 0.66), cam, col, Vector3.ZERO)
	k._add(m, VehicleModels.solid([_ring(_oct(-0.91, 0.91, -1.775, 1.775, 0.04), 0.66), _ring(_oct(-0.91, 0.91, -1.7, 1.775, 0.04), 0.78), _ring(_oct(-0.88, 0.88, -0.92, 1.73, 0.04), 1.2)], "indep_nyx_up"), cam, col, Vector3.ZERO)
	var ga := Vector2(-1.7, 0.78)
	var gb := Vector2(-0.92, 1.2)
	# the driver's hatch and periscopes front-left, the engine grille on the
	# glacis front-right, the exhaust on the right flank
	k._box(m, Vector3(0.48, 0.05, 0.5), Vector3(-0.42, 1.22, -0.62), cam, col)
	for i in 3:
		k._box(m, Vector3(0.12, 0.07, 0.05), Vector3(-0.56 + i * 0.14, 1.21, -0.9), "glass", null, Vector3(-0.5, 0, 0), false)
	_plate(k, m, 0.42, 0.72, ga.lerp(gb, 0.3), ga.lerp(gb, 0.92), 0.02, "gunmetal_w", null, 0.0)
	for i in 5:
		_plate(k, m, 0.42, 0.7, ga.lerp(gb, 0.33 + i * 0.12), ga.lerp(gb, 0.37 + i * 0.12), 0.02, cam, col, 0.015, false)
	k._box(m, Vector3(0.1, 0.16, 0.45), Vector3(0.95, 0.98, -0.75), "gunmetal_w")
	k._cyl(m, 0.04, 0.04, 0.12, Vector3(0.98, 0.9, -1.0), X90, "metal_dark", null, 8, false)
	for s: float in [-1.0, 1.0]:
		# headlights with guards on the glacis corners, tow eyes, smoke
		# dischargers on the roof's front corners
		_light(k, m, Vector3(s * 0.7, 0.86, -1.72), 0.18, 0.09)
		k._box(m, Vector3(0.08, 0.1, 0.12), Vector3(s * 0.32, 0.6, -1.76), "gunmetal_w")
		_smoke(k, m, Vector3(s * 0.74, 1.22, -0.78), 3, s * -0.5, 0.5, 0.04)
		# a stowage box on each flank aft, tail lights, a jerrycan
		k._box(m, Vector3(0.1, 0.24, 0.6), Vector3(s * 0.95, 0.98, 1.1), cam, col)
		_light(k, m, Vector3(s * 0.7, 0.98, 1.79), 0.16, 0.08, 1.0, false, true)
	# rear: the crew door and its handle, the tow pintle, a jerrycan rack
	k._box(m, Vector3(0.7, 0.42, 0.05), Vector3(-0.08, 0.95, 1.79), cam, col)
	k._box(m, Vector3(0.04, 0.04, 0.16), Vector3(0.18, 0.95, 1.83), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.12, 0.1, 0.14), Vector3(0, 0.55, 1.8), "gunmetal_w")
	_jerrycan(k, m, Vector3(0.52, 0.6, 1.9), Color(0.3, 0.33, 0.23), PI / 2)
	_antenna(k, m, Vector3(0.72, 1.2, 1.55), 1.7)
	k._team_mark(m, team, Vector3(0.915, 0.95, 0.3), Vector3(0.03, 0.18, 0.5))
	k._team_mark(m, team, Vector3(-0.915, 0.95, 0.3), Vector3(0.03, 0.18, 0.5))
	if kind == "recon":
		# the periscope mast, extended, at the back left
		k._box(m, Vector3(0.24, 0.1, 0.24), Vector3(-0.5, 1.25, 1.25), "gunmetal_w")
		k._cyl(m, 0.075, 0.08, 0.45, Vector3(-0.5, 1.5, 1.25), Vector3.ZERO, cam, col, 10)
		k._cyl(m, 0.055, 0.055, 0.45, Vector3(-0.5, 1.92, 1.25), Vector3.ZERO, "gunmetal_w", null, 10)
		k._cyl(m, 0.04, 0.04, 0.4, Vector3(-0.5, 2.3, 1.25), Vector3.ZERO, "gunmetal_w", null, 8)
		_sensor_head(k, m, Vector3(-0.5, 2.6, 1.25), cam, col, 0.55)
		# the radar: a flat array on a turning pedestal over its electronics
		var r := k._pivot(m, Vector3(0.1, 1.2, 0.2))
		k.turret = r
		k._cyl(r, 0.3, 0.32, 0.08, Vector3(0, 0.04, 0), Vector3.ZERO, "gunmetal_w", null, 14)
		k._box(r, Vector3(0.46, 0.22, 0.4), Vector3(0, 0.19, 0.05), cam, col)
		k._cyl(r, 0.06, 0.06, 0.2, Vector3(0, 0.38, 0), Vector3.ZERO, "gunmetal_w", null, 8)
		k._box(r, Vector3(0.8, 0.46, 0.07), Vector3(0, 0.66, -0.02), cam, col, Vector3(0.25, 0, 0))
		k._box(r, Vector3(0.72, 0.38, 0.02), Vector3(0, 0.66, -0.065), "plain_dark", null, Vector3(0.25, 0, 0), false)
		k._box(r, Vector3(0.2, 0.12, 0.12), Vector3(0, 0.66, 0.08), "gunmetal_w")
		return
	# the weapon mount: a low armoured turntable at the back of the roof
	var t := k._pivot(m, Vector3(0, 1.2, 0.45))
	k.turret = t
	k._cyl(t, 0.5, 0.52, 0.08, Vector3(0, 0.04, 0), Vector3.ZERO, "gunmetal_w", null, 16)
	k._add(t, VehicleModels.loft("indep_nyx_mount", _oct(-0.42, 0.42, -0.5, 0.45, 0.14), _oct(-0.36, 0.36, -0.38, 0.4, 0.12), 0.0, 0.3), cam, col, Vector3(0, 0.08, 0))
	match kind:
		"ac":
			# the Rh 202 in its cradle on top, ammunition boxes either side, a sight
			k._box(t, Vector3(0.26, 0.2, 0.66), Vector3(-0.04, 0.47, -0.08), cam, col)
			k._box(t, Vector3(0.18, 0.18, 0.84), Vector3(-0.04, 0.6, -0.02), "gunmetal_w")
			k._cyl(t, 0.06, 0.06, 0.4, Vector3(-0.04, 0.58, -0.62), X90, "gunmetal_w", null, 10)
			k._cyl(t, 0.032, 0.032, 1.45, Vector3(-0.04, 0.58, -1.5), X90, "gunmetal_w", null, 8)
			k._cyl(t, 0.05, 0.045, 0.16, Vector3(-0.04, 0.58, -2.28), X90, "gunmetal_w", null, 8)
			k.mg_tip = k._tip(t, Vector3(-0.04, 0.58, -2.38))
			for s: float in [-1.0, 1.0]:
				k._box(t, Vector3(0.16, 0.24, 0.38), Vector3(-0.04 + s * 0.22, 0.56, 0.1), "paint", Color(0.3, 0.33, 0.23))
			k._box(t, Vector3(0.16, 0.18, 0.24), Vector3(0.3, 0.5, -0.28), cam, col)
			k._box(t, Vector3(0.1, 0.08, 0.02), Vector3(0.3, 0.52, -0.405), "glass", null, Vector3.ZERO, false)
			k._cyl(t, 0.2, 0.2, 0.05, Vector3(0.18, 0.4, 0.25), Vector3.ZERO, cam, col, 12)
		"at":
			# a twin launcher for the fire-and-forget missiles on the left, a
			# sight head in the middle, the .50 on the right
			k._box(t, Vector3(0.1, 0.32, 0.3), Vector3(-0.3, 0.46, 0.0), cam, col)
			for i in 2:
				var lx := -0.44 - i * 0.2
				k._cyl(t, 0.08, 0.08, 1.1, Vector3(lx, 0.58, -0.1), X90, "paint", Color(0.33, 0.35, 0.26), 12)
				k._cyl(t, 0.1, 0.1, 0.12, Vector3(lx, 0.58, -0.62), X90, "paint", Color(0.3, 0.32, 0.24), 12)
				k._cyl(t, 0.095, 0.095, 0.1, Vector3(lx, 0.58, 0.44), X90, "paint", Color(0.3, 0.32, 0.24), 12)
			k._box(t, Vector3(0.44, 0.04, 0.6), Vector3(-0.54, 0.68, -0.1), "gunmetal_w", null, Vector3.ZERO, false)
			k.gun_tip = k._tip(t, Vector3(-0.54, 0.58, -0.72))
			_sensor_head(k, t, Vector3(0.0, 0.62, -0.15), cam, col, 0.6)
			_nyx_m2(k, t, Vector3(0.36, 0.48, 0.0), cam, col)
		"aa":
			# two four-round pods either side of the sight head, the .50
			# under the left one
			_sensor_head(k, t, Vector3(0.0, 0.58, -0.12), cam, col, 0.65)
			k._cyl(t, 0.04, 0.04, 1.05, Vector3(0, 0.62, 0.05), Z90, "gunmetal_w", null, 8)
			for s: float in [-1.0, 1.0]:
				var px: float = s * 0.52
				k._box(t, Vector3(0.3, 0.3, 1.45), Vector3(px, 0.62, -0.1), cam, col)
				for i in 4:
					k._cyl(t, 0.055, 0.055, 0.03, Vector3(px + (i % 2 - 0.5) * 0.14, 0.62 + (floorf(i / 2.0) - 0.5) * 0.14, -0.83), X90, "plain_dark", null, 10, false)
				k._box(t, Vector3(0.32, 0.04, 0.12), Vector3(px, 0.79, 0.4), "gunmetal_w", null, Vector3.ZERO, false)
			k.gun_tip = k._tip(t, Vector3(0.52, 0.62, -0.86))
			_nyx_m2(k, t, Vector3(-0.52, 0.32, -0.05), cam, col)
	_smoke(k, t, Vector3(0.0, 0.38, 0.42), 2, PI, 0.5, 0.04)


## The Nyx's .50 cal on a small cradle with its ammunition box. Sets k.mg_tip.
static func _nyx_m2(k: VehicleModels, p: Node3D, pos: Vector3, cam: String, col) -> void:
	k._box(p, Vector3(0.18, 0.12, 0.4), pos + Vector3(0, -0.08, 0.05), cam, col)
	k._box(p, Vector3(0.13, 0.15, 0.62), pos + Vector3(0, 0.04, 0.02), "gunmetal_w")
	k._cyl(p, 0.036, 0.036, 0.2, pos + Vector3(0, 0.04, -0.38), X90, "gunmetal_w", null, 10)
	k._cyl(p, 0.022, 0.022, 0.85, pos + Vector3(0, 0.04, -0.82), X90, "gunmetal_w", null, 8)
	k._cyl(p, 0.03, 0.026, 0.08, pos + Vector3(0, 0.04, -1.27), X90, "gunmetal_w", null, 8, false)
	k._box(p, Vector3(0.14, 0.18, 0.26), pos + Vector3(0.14, 0.0, 0.05), "paint", Color(0.3, 0.33, 0.23))
	k.mg_tip = k._tip(p, pos + Vector3(0, 0.04, -1.32))


# --- Gorgon: Pandur II 8x8 ----------------------------------------------------------

## Pandur II 8x8: a flat-sided box overhanging eight wheels (the gap between
## the second and third axles), the sloped bow with the trim vane folded on
## it, the driver front-left and the engine front-right, the big rear door;
## a low turret aft of centre with the 30 mm cannon and a Titan tube on
## each side.
static func _gorgon(k: VehicleModels, team: int) -> void:
	var pc := _paint(team)
	var cam: String = pc[0]
	var col = pc[1]
	var m := k.root
	var wr := 0.56
	var axles := [-2.3, -0.92, 0.98, 2.36]
	# the V-shaped belly between the wheels, the upper hull over them
	k._add(m, VehicleModels.loft("indep_gorg_low", _oct(-0.6, 0.6, -3.1, 3.35, 0.1), _oct(-0.88, 0.88, -3.72, 3.7, 0.1), 0.45, 1.2), cam, col, Vector3.ZERO)
	k._add(m, VehicleModels.solid([_ring(_oct(-1.335, 1.335, -3.72, 3.72, 0.08), 1.2), _ring(_oct(-1.335, 1.335, -3.06, 3.72, 0.08), 1.85), _ring(_oct(-1.17, 1.17, -2.84, 3.66, 0.08), 2.08)], "indep_gorg_up"), cam, col, Vector3.ZERO)
	for s: float in [-1.0, 1.0]:
		for z in axles:
			k._wheel(m, Vector3(s * 1.1, wr, z), wr, 0.42, cam, col)
			# the wheel well's dark liner under the overhang
			k._box(m, Vector3(0.03, 0.4, 1.2), Vector3(s * 0.885, 0.95, z), "plain_dark", null, Vector3.ZERO, false)
		for z: float in [-1.6, 3.0]:
			k._box(m, Vector3(0.36, 0.3, 0.02), Vector3(s * 1.1, 0.98, z), "rubber")
		# the hull's side: a chine strake at mid height, stowage boxes aft,
		# the side's lifting eyes
		k._box(m, Vector3(0.05, 0.06, 7.2), Vector3(s * 1.345, 1.84, 0.0), cam, col)
		k._box(m, Vector3(0.16, 0.42, 1.0), Vector3(s * 1.41, 1.5, 1.7), cam, col)
		k._box(m, Vector3(0.02, 0.04, 0.95), Vector3(s * 1.495, 1.62, 1.7), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.16, 0.42, 0.7), Vector3(s * 1.41, 1.5, -1.62), cam, col)
		# headlight clusters with guards at the bow's corners, tow eyes
		_light(k, m, Vector3(s * 1.1, 1.6, -3.32), 0.28, 0.13)
		k._box(m, Vector3(0.12, 0.16, 0.2), Vector3(s * 0.62, 1.08, -3.66), "gunmetal_w")
		k._cyl(m, 0.05, 0.05, 0.16, Vector3(s * 0.62, 1.02, -3.76), Z90, "gunmetal_w", null, 8, false)
		# rear: tail lights, tow eyes, a whip antenna on each corner
		_light(k, m, Vector3(s * 1.1, 1.75, 3.74), 0.22, 0.1, 1.0, false, true)
		k._box(m, Vector3(0.12, 0.16, 0.2), Vector3(s * 0.75, 1.0, 3.72), "gunmetal_w")
		_antenna(k, m, Vector3(s * 1.0, 2.08, 3.3), 2.4)
	# the bow: the trim vane folded on the glacis, its hinge line
	var ga := Vector2(-3.72, 1.2)
	var gb := Vector2(-3.06, 1.85)
	_plate(k, m, 0.0, 2.2, ga.lerp(gb, 0.12), ga.lerp(gb, 0.92), 0.05, cam, col, 0.035)
	k._cyl(m, 0.035, 0.035, 2.0, Vector3(0, 1.3, -3.72), Z90, "gunmetal_w", null, 8, false)
	# roof: the driver's hatch and periscopes front-left, a mirror; the engine
	# grille front-right; the exhaust on the right flank
	k._box(m, Vector3(0.6, 0.06, 0.62), Vector3(-0.62, 2.1, -2.35), cam, col)
	for i in 3:
		k._box(m, Vector3(0.15, 0.08, 0.06), Vector3(-0.8 + i * 0.18, 2.09, -2.72), "glass", null, Vector3(-0.4, 0, 0), false)
	k._cyl(m, 0.015, 0.015, 0.3, Vector3(-1.3, 1.92, -2.95), Z90, "gunmetal_w", null, 6, false)
	k._box(m, Vector3(0.05, 0.24, 0.15), Vector3(-1.46, 1.96, -2.95), "gunmetal_w")
	k._box(m, Vector3(0.95, 0.03, 1.15), Vector3(0.62, 2.095, -2.1), "gunmetal_w")
	for i in 5:
		k._box(m, Vector3(0.93, 0.03, 0.05), Vector3(0.62, 2.115, -2.56 + i * 0.23), cam, col, Vector3.ZERO, false)
	k._box(m, Vector3(0.1, 0.34, 0.55), Vector3(1.38, 1.55, -2.55), "gunmetal_w")
	for i in 3:
		k._box(m, Vector3(0.04, 0.03, 0.5), Vector3(1.44, 1.45 + i * 0.1, -2.55), cam, col, Vector3.ZERO, false)
	# the troop compartment's roof hatches, aft
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.66, 0.06, 0.8), Vector3(s * 0.5, 2.1, 2.55), cam, col)
		k._box(m, Vector3(0.08, 0.05, 0.08), Vector3(s * 0.5, 2.15, 2.2), "gunmetal_w", null, Vector3.ZERO, false)
	# the rear door: vision block, handle, hinges; a step under it
	k._box(m, Vector3(1.1, 1.25, 0.08), Vector3(0.1, 1.5, 3.74), cam, col)
	k._box(m, Vector3(0.2, 0.12, 0.03), Vector3(0.1, 1.85, 3.79), "glass", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.05, 0.05, 0.2), Vector3(0.5, 1.45, 3.8), "gunmetal_w", null, Vector3.ZERO, false)
	for hy: float in [1.1, 1.9]:
		k._cyl(m, 0.04, 0.04, 0.16, Vector3(-0.45, hy, 3.79), Vector3.ZERO, "gunmetal_w", null, 8, false)
	k._box(m, Vector3(0.9, 0.05, 0.25), Vector3(0.1, 0.82, 3.8), "gunmetal_w")
	k._team_mark(m, team, Vector3(1.345, 1.45, 0.3), Vector3(0.03, 0.26, 0.7))
	k._team_mark(m, team, Vector3(-1.345, 1.45, 0.3), Vector3(0.03, 0.26, 0.7))
	# the turret: low and faceted, the 30 mm in its mantlet with the coax
	# beside it, a Titan tube on each side
	var t := k._pivot(m, Vector3(0, 2.08, 0.3))
	k.turret = t
	k._cyl(t, 0.92, 0.94, 0.06, Vector3(0, 0.03, 0.05), Vector3.ZERO, "gunmetal_w", null, 20)
	var tb := [-0.5, -1.12, 0.5, -1.12, 0.96, -0.7, 1.0, 0.78, 0.8, 1.08, -0.8, 1.08, -1.0, 0.78, -0.96, -0.7]
	var tt := [-0.4, -0.86, 0.4, -0.86, 0.8, -0.55, 0.85, 0.7, 0.66, 0.94, -0.66, 0.94, -0.85, 0.7, -0.8, -0.55]
	k._add(t, VehicleModels.loft("indep_gorg_tur", tb, tt, 0.05, 0.58), cam, col, Vector3.ZERO)
	k._box(t, Vector3(0.42, 0.34, 0.32), Vector3(0, 0.32, -1.12), cam, col)
	k._cyl(t, 0.085, 0.085, 0.5, Vector3(0, 0.32, -1.5), X90, "gunmetal_w", null, 12)
	k._cyl(t, 0.05, 0.05, 2.6, Vector3(0, 0.32, -2.95), X90, "gunmetal_w", null, 10)
	k._cyl(t, 0.075, 0.07, 0.2, Vector3(0, 0.32, -4.3), X90, "gunmetal_w", null, 10)
	k.mg_tip = k._tip(t, Vector3(0, 0.32, -4.42))
	k._cyl(t, 0.02, 0.02, 0.4, Vector3(0.26, 0.24, -1.3), X90, "gunmetal_w", null, 6, false)
	for s: float in [-1.0, 1.0]:
		# the Titan tube on its bracket
		k._box(t, Vector3(0.22, 0.12, 0.3), Vector3(s * 0.98, 0.36, -0.15), "gunmetal_w")
		k._cyl(t, 0.09, 0.09, 1.3, Vector3(s * 1.1, 0.44, -0.2), X90, "paint", Color(0.33, 0.35, 0.26), 12)
		k._cyl(t, 0.11, 0.11, 0.1, Vector3(s * 1.1, 0.44, -0.84), X90, "paint", Color(0.3, 0.32, 0.24), 12)
		k._cyl(t, 0.1, 0.1, 0.1, Vector3(s * 1.1, 0.44, 0.44), X90, "paint", Color(0.3, 0.32, 0.24), 12)
		# smoke dischargers on the front corners
		_smoke(k, t, Vector3(s * 0.82, 0.48, -0.66), 3, s * -0.6, 0.5, 0.045)
	k.gun_tip = k._tip(t, Vector3(-1.1, 0.44, -0.9))
	# roof: the gunner's sight front-left, the commander's panoramic sight
	# right, his hatch behind it
	k._box(t, Vector3(0.3, 0.24, 0.36), Vector3(-0.4, 0.68, -0.48), cam, col)
	k._box(t, Vector3(0.22, 0.13, 0.02), Vector3(-0.4, 0.7, -0.67), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.06, 0.07, 0.16, Vector3(0.5, 0.66, -0.15), Vector3.ZERO, "gunmetal_w", null, 10)
	k._box(t, Vector3(0.3, 0.18, 0.26), Vector3(0.5, 0.82, -0.15), cam, col)
	k._box(t, Vector3(0.2, 0.09, 0.02), Vector3(0.5, 0.83, -0.285), "glass", null, Vector3.ZERO, false)
	k._cyl(t, 0.28, 0.28, 0.06, Vector3(0.35, 0.61, 0.5), Vector3.ZERO, cam, col, 14)
	k._box(t, Vector3(0.5, 0.05, 0.5), Vector3(-0.35, 0.6, 0.45), cam, col)
	_antenna(k, t, Vector3(-0.6, 0.58, 0.8), 1.9)
	# a stowage basket on the turret's back
	k._box(t, Vector3(1.4, 0.04, 0.4), Vector3(0, 0.2, 1.2), "gunmetal_w")
	k._box(t, Vector3(1.4, 0.3, 0.04), Vector3(0, 0.35, 1.4), "gunmetal_w")
	k._box(t, Vector3(0.7, 0.24, 0.3), Vector3(-0.3, 0.34, 1.2), "canvas", Color(0.36, 0.36, 0.26))


# --- Zamak: KamAZ-4310 6x6 -------------------------------------------------------

## The Zamak's axles: one at the front, two in tandem at the back.
const ZK_AXLES := [-2.45, 0.9, 2.22]


## Zamak trucks: the shared chassis and bonneted cab, then the body for
## `kind`. Rebel-captured ones (team 1) wear khaki.
static func _zamak(k: VehicleModels, team: int, kind: String, seed: int) -> void:
	var pc := _paint(team, true)
	var cam: String = pc[0]
	var col = pc[1]
	var tarp := Color(0.37, 0.39, 0.27) if team != 1 else Color(0.5, 0.46, 0.34)
	_zamak_cab(k, team, cam, col)
	match kind:
		"zamak":
			_zamak_bed(k, cam, col, 0.55)
			_zamak_tilt(k, tarp)
		"zamak_cargo":
			_zamak_bed(k, cam, col, 0.55)
			_zamak_cargo(k, tarp, seed)
		"zamak_ammo":
			_zamak_bed(k, cam, col, 0.45)
			_zamak_ammo(k, tarp)
		"zamak_repair":
			_zamak_bed(k, cam, col, 0.0)
			_zamak_repair(k, cam, col)
		"zamak_medical":
			_zamak_bed(k, cam, col, 0.0)
			_zamak_medical(k, cam, col)
		"zamak_fuel":
			_zamak_fuel(k, cam, col)
		"zamak_mrl":
			_zamak_bed(k, cam, col, 0.0)
			_zamak_mrl(k, cam, col)


## KamAZ-4310 running gear and cab: ladder chassis on three axles of big
## single tyres (tandem bogie at the back), the protruding engine bonnet
## with its grille, flat-topped wings carrying round headlights, the
## squared-off cab with a split windscreen, the spare wheel upright behind it.
static func _zamak_cab(k: VehicleModels, team: int, cam: String, col) -> void:
	var m := k.root
	# chassis rails and cross members, axles with their differentials, springs
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.14, 0.22, 7.2), Vector3(s * 0.48, 1.0, 0.1), "gunmetal_w")
		k._box(m, Vector3(0.1, 0.08, 1.3), Vector3(s * 0.6, 0.8, -2.45), "gunmetal_w")
		k._box(m, Vector3(0.12, 0.14, 1.9), Vector3(s * 0.62, 0.78, 1.56), "gunmetal_w")
		k._cyl(m, 0.13, 0.13, 0.22, Vector3(s * 0.62, 0.84, 1.56), Z90, "gunmetal_w", null, 10)
		for z in ZK_AXLES:
			k._wheel(m, Vector3(s * 1.03, 0.6, z), 0.6, 0.42, cam, col)
		for z: float in [-1.78, 2.9]:
			k._box(m, Vector3(0.44, 0.42, 0.02), Vector3(s * 1.03, 0.82, z), "rubber")
	for z: float in [-3.3, -1.0, 0.2, 1.56, 3.55]:
		k._box(m, Vector3(0.84, 0.12, 0.1), Vector3(0, 1.0, z), "gunmetal_w")
	for z in ZK_AXLES:
		k._cyl(m, 0.08, 0.08, 1.7, Vector3(0, 0.6, z), Z90, "gunmetal_w", null, 8)
		k._add(m, Res.sphere(0.2, 10), "gunmetal_w", null, Vector3(0, 0.62, z), Vector3.ZERO, Vector3(1.0, 0.9, 0.9))
	# the bonnet: louvres down its sides, the grille in front
	k._add(m, VehicleModels.loft("indep_zk_bonnet", _oct(-0.6, 0.6, -3.62, -2.12, 0.08), _oct(-0.5, 0.5, -3.48, -2.12, 0.14), 1.12, 1.84), cam, col, Vector3.ZERO)
	var ba := Vector2(-3.62, 1.16)
	var bb := Vector2(-3.49, 1.8)
	_plate(k, m, 0.0, 0.92, ba, bb, 0.03, "gunmetal_w", null, -0.012)
	for i in 7:
		_plate(k, m, -0.36 + i * 0.12, 0.04, ba.lerp(bb, 0.05), ba.lerp(bb, 0.95), 0.03, cam, col, 0.0, false)
	k._box(m, Vector3(0.9, 0.03, 0.04), Vector3(0, 1.84, -2.2), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.03, 0.02, 1.3), Vector3(0, 1.845, -2.85), "gunmetal_w", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		for i in 4:
			k._box(m, Vector3(0.02, 0.04, 0.42), Vector3(s * 0.57, 1.42 + i * 0.09, -2.75), "gunmetal_w", null, Vector3(0, 0, s * 0.14), false)
		# the wing over the front wheel: flat top, raked front, a valance
		var fx: float = s * 0.93
		k._box(m, Vector3(0.68, 0.05, 1.12), Vector3(fx, 1.42, -2.56), cam, col)
		_plate(k, m, fx, 0.68, Vector2(-3.42, 1.02), Vector2(-3.12, 1.42), 0.05, cam, col, -0.025)
		_plate(k, m, fx, 0.68, Vector2(-2.0, 1.42), Vector2(-1.86, 1.2), 0.05, cam, col, -0.025)
		k._box(m, Vector3(0.04, 0.2, 1.12), Vector3(s * 1.25, 1.32, -2.56), cam, col)
		# a round headlight on the wing's front, the sidelight on top of it
		_round_light(k, m, Vector3(s * 0.88, 1.24, -3.34), 0.1)
		k._box(m, Vector3(0.08, 0.06, 0.1), Vector3(s * 1.12, 1.47, -3.0), "paint", Color(0.62, 0.45, 0.12), Vector3.ZERO, false)
	# the bumper with its tow hooks and plate
	k._box(m, Vector3(2.42, 0.22, 0.2), Vector3(0, 0.95, -3.72), cam, col)
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.1, 0.16, 0.12), Vector3(s * 0.72, 0.88, -3.85), "gunmetal_w")
		k._cyl(m, 0.05, 0.05, 0.14, Vector3(s * 0.72, 0.82, -3.92), Z90, "gunmetal_w", null, 8, false)
	k._box(m, Vector3(0.5, 0.12, 0.02), Vector3(0, 0.96, -3.83), "paint", Color(0.82, 0.8, 0.72), Vector3.ZERO, false)
	# the cab: vertical lower half, the glasshouse leaning in a little
	k._add(m, VehicleModels.solid([_ring(_oct(-1.2, 1.2, -2.15, -0.72, 0.08), 1.22), _ring(_oct(-1.2, 1.2, -2.15, -0.72, 0.08), 2.0), _ring(_oct(-1.12, 1.12, -2.0, -0.76, 0.1), 2.72)], "indep_zk_cab"), cam, col, Vector3.ZERO)
	var wa := Vector2(-2.15, 2.0)
	var wb := Vector2(-2.0, 2.72)
	for s: float in [-1.0, 1.0]:
		_plate(k, m, s * 0.52, 0.9, wa.lerp(wb, 0.08), wa.lerp(wb, 0.9), 0.03, "glass", null, -0.008, false)
		_plate(k, m, s * 0.5, 0.025, wa.lerp(wb, 0.12), wa.lerp(wb, 0.55), 0.02, "gunmetal_w", null, 0.02, false)
	_plate(k, m, 0.0, 0.1, wa.lerp(wb, 0.05), wa.lerp(wb, 0.95), 0.035, cam, col, 0.0)
	k._box(m, Vector3(0.8, 0.34, 0.03), Vector3(0, 2.35, -0.73), "glass", null, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		var sl: float = s * 0.11
		# door window and rear quarter light, the door's seams and handle,
		# the step and grab handle, the mirror on its arm
		k._box(m, Vector3(0.03, 0.48, 0.64), Vector3(s * 1.175, 2.34, -1.6), "glass", null, Vector3(0, 0, sl), false)
		k._box(m, Vector3(0.03, 0.4, 0.22), Vector3(s * 1.175, 2.34, -0.95), "glass", null, Vector3(0, 0, sl), false)
		for dz: float in [-2.04, -1.13]:
			k._box(m, Vector3(0.02, 1.3, 0.025), Vector3(s * 1.2, 1.88, dz), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.04, 0.04, 0.14), Vector3(s * 1.22, 1.95, -1.3), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.32, 0.04, 0.44), Vector3(s * 1.12, 0.92, -1.58), "gunmetal_w")
		k._box(m, Vector3(0.04, 0.34, 0.04), Vector3(s * 1.2, 1.1, -1.38), "gunmetal_w", null, Vector3.ZERO, false)
		k._cyl(m, 0.018, 0.018, 0.6, Vector3(s * 1.23, 1.75, -2.1), Vector3.ZERO, "gunmetal_w", null, 6, false)
		k._cyl(m, 0.018, 0.018, 0.36, Vector3(s * 1.37, 2.32, -2.1), Z90, "gunmetal_w", null, 6, false)
		k._box(m, Vector3(0.05, 0.36, 0.22), Vector3(s * 1.56, 2.22, -2.1), "gunmetal_w")
		k._box(m, Vector3(0.012, 0.3, 0.17), Vector3(s * 1.56, 2.22, -2.18), "glass", null, Vector3.ZERO, false)
		k._team_mark(m, team, Vector3(s * 1.205, 1.65, -1.6), Vector3(0.03, 0.24, 0.5))
	# the roof hatch and marker lights, an antenna on the back corner
	k._cyl(m, 0.3, 0.3, 0.05, Vector3(0.42, 2.745, -1.35), Vector3.ZERO, cam, col, 14)
	for x: float in [-0.3, 0.0, 0.3]:
		k._box(m, Vector3(0.09, 0.05, 0.06), Vector3(x, 2.74, -1.94), "paint", Color(0.62, 0.45, 0.12), Vector3.ZERO, false)
	_antenna(k, m, Vector3(-1.0, 2.72, -0.86), 1.6)
	# behind the cab: the spare wheel upright in its frame, the air intake,
	# the fuel tank on the left and the battery box on the right
	k._cyl(m, 0.6, 0.6, 0.4, Vector3(0, 1.74, -0.5), X90, "rubber", null, 20)
	k._cyl(m, 0.36, 0.36, 0.42, Vector3(0, 1.74, -0.5), X90, cam, col, 14)
	k._cyl(m, 0.14, 0.14, 0.46, Vector3(0, 1.74, -0.5), X90, "gunmetal_w", null, 10)
	k._box(m, Vector3(1.2, 0.08, 0.1), Vector3(0, 1.16, -0.5), "gunmetal_w")
	k._cyl(m, 0.17, 0.17, 0.9, Vector3(0.95, 1.85, -0.52), Vector3.ZERO, cam, col, 12)
	k._cyl(m, 0.2, 0.2, 0.08, Vector3(0.95, 2.34, -0.52), Vector3.ZERO, "gunmetal_w", null, 12)
	k._cyl(m, 0.26, 0.26, 0.85, Vector3(-0.98, 0.95, -0.18), X90, cam, col, 14)
	for z: float in [-0.45, 0.1]:
		k._cyl(m, 0.27, 0.27, 0.04, Vector3(-0.98, 0.95, z), X90, "gunmetal_w", null, 14, false)
	k._box(m, Vector3(0.42, 0.4, 0.6), Vector3(0.98, 0.95, -0.18), cam, col)
	# the exhaust's silencer under the right side of the cab
	k._cyl(m, 0.1, 0.1, 0.6, Vector3(0.78, 0.8, -1.35), X90, "metal_dark", null, 10)


## The flatbed on the chassis; `sides` > 0 gives it dropsides that high, a
## headboard and a tailgate. Tail lights, bumper and pintle under the back.
static func _zamak_bed(k: VehicleModels, cam: String, col, sides: float) -> void:
	var m := k.root
	k._box(m, Vector3(2.5, 0.12, 4.05), Vector3(0, 1.38, 1.775), cam, col)
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.16, 0.14, 4.0), Vector3(s * 0.48, 1.25, 1.775), "gunmetal_w")
	if sides > 0.0:
		var sy := 1.44 + sides * 0.5
		k._box(m, Vector3(2.5, sides + 0.25, 0.05), Vector3(0, 1.44 + (sides + 0.25) * 0.5, -0.225), cam, col)
		k._box(m, Vector3(2.5, sides, 0.05), Vector3(0, sy, 3.775), cam, col)
		for s: float in [-1.0, 1.0]:
			k._box(m, Vector3(0.05, sides, 4.05), Vector3(s * 1.225, sy, 1.775), cam, col)
			for i in 5:
				k._box(m, Vector3(0.04, sides, 0.06), Vector3(s * 1.26, sy, -0.1 + i * 0.96), cam, col)
			k._box(m, Vector3(0.04, 0.04, 4.0), Vector3(s * 1.26, 1.44 + sides - 0.04, 1.775), "gunmetal_w", null, Vector3.ZERO, false)
			k._box(m, Vector3(0.06, 0.08, 0.06), Vector3(s * 1.0, 1.44 + sides * 0.3, 3.81), "gunmetal_w", null, Vector3.ZERO, false)
	# under the back: tail lights on their brackets, the bumper bar, pintle, plate
	for s: float in [-1.0, 1.0]:
		_light(k, m, Vector3(s * 0.98, 1.16, 3.74), 0.24, 0.1, 1.0, false, true)
	k._box(m, Vector3(2.0, 0.1, 0.1), Vector3(0, 0.82, 3.72), "gunmetal_w")
	k._box(m, Vector3(0.14, 0.14, 0.2), Vector3(0, 0.98, 3.74), "gunmetal_w")
	k._cyl(m, 0.06, 0.06, 0.1, Vector3(0, 0.98, 3.85), X90, "gunmetal_w", null, 8, false)
	k._box(m, Vector3(0.44, 0.12, 0.02), Vector3(0, 1.18, 3.79), "paint", Color(0.82, 0.8, 0.72), Vector3.ZERO, false)


## Troop transport: a canvas tilt over hoops, the back flap rolled up.
static func _zamak_tilt(k: VehicleModels, tarp: Color) -> void:
	var m := k.root
	var prof := [-1.27, 1.9, 1.27, 1.9, 1.27, 2.6, 1.03, 2.88, -1.03, 2.88, -1.27, 2.6]
	var r0 := PackedVector3Array()
	var r1 := PackedVector3Array()
	for i in range(0, prof.size(), 2):
		r0.append(Vector3(prof[i], prof[i + 1], -0.2))
		r1.append(Vector3(prof[i], prof[i + 1], 3.72))
	k._add(m, VehicleModels.solid([r0, r1], "indep_zk_tilt"), "canvas_white", tarp, Vector3.ZERO)
	# the hoops showing through, the lashing along the bottom
	var rib := tarp.darkened(0.18)
	for z: float in [0.45, 1.25, 2.05, 2.85, 3.62]:
		k._box(m, Vector3(2.08, 0.035, 0.07), Vector3(0, 2.895, z), "canvas_white", rib, Vector3.ZERO, false)
		for s: float in [-1.0, 1.0]:
			k._box(m, Vector3(0.035, 0.68, 0.07), Vector3(s * 1.285, 2.25, z), "canvas_white", rib, Vector3.ZERO, false)
			k._box(m, Vector3(0.035, 0.37, 0.07), Vector3(s * 1.165, 2.75, z), "canvas_white", rib, Vector3(0, 0, s * 0.69), false)
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.03, 0.03, 3.9), Vector3(s * 1.285, 1.93, 1.76), "plain_dark", null, Vector3.ZERO, false)
		for i in 8:
			k._box(m, Vector3(0.02, 0.12, 0.02), Vector3(s * 1.285, 1.86, -0.05 + i * 0.52), "plain_dark", null, Vector3.ZERO, false)
	# the back: the flap rolled up under the roof, the dark inside, benches
	k._box(m, Vector3(2.36, 0.62, 0.02), Vector3(0, 2.27, 3.725), "plain_dark", null, Vector3.ZERO, false)
	k._cyl(m, 0.11, 0.11, 2.3, Vector3(0, 2.72, 3.76), Z90, "canvas_white", tarp.darkened(0.1), 10)
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.4, 0.05, 0.03), Vector3(s * 0.8, 2.05, 3.73), "wood_dark", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.03, 0.3, 0.03), Vector3(s * 0.55, 2.57, 3.79), "plain_dark", null, Vector3.ZERO, false)


## The Rebels' supply truck: drums, crates, a tarpaulined pile, sacks and
## jerrycans in the open bed (laid out by seed).
static func _zamak_cargo(k: VehicleModels, tarp: Color, seed: int) -> void:
	var m := k.root
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# two oil drums at the front left, a crate stack at the front right
	var drum: Color = [Color(0.25, 0.3, 0.22), Color(0.22, 0.26, 0.32), Color(0.4, 0.2, 0.14)][rng.randi() % 3]
	for z: float in [0.15, 0.78]:
		k._cyl(m, 0.29, 0.29, 0.88, Vector3(-0.86, 1.88, z), Vector3.ZERO, "paint", drum, 14)
		for y: float in [1.72, 2.04]:
			k._cyl(m, 0.3, 0.3, 0.03, Vector3(-0.86, y, z), Vector3.ZERO, "paint", drum.darkened(0.2), 14, false)
		k._cyl(m, 0.04, 0.04, 0.02, Vector3(-0.76, 2.33, z + 0.12), Vector3.ZERO, "gunmetal_w", null, 6, false)
	k._box(m, Vector3(0.95, 0.62, 0.72), Vector3(0.62, 1.75, 0.22), "wood")
	k._box(m, Vector3(0.7, 0.46, 0.6), Vector3(0.55, 2.29, 0.25), "wood", null, Vector3(0, rng.randf_range(-0.2, 0.2), 0))
	k._box(m, Vector3(0.97, 0.04, 0.05), Vector3(0.62, 1.75, -0.15), "wood_dark", null, Vector3.ZERO, false)
	# the middle: a pile under a tarpaulin, lashed down
	k._add(m, VehicleModels.loft("indep_zk_pile", _oct(-1.17, 1.17, 1.1, 2.55, 0.1), _oct(-0.85, 0.85, 1.28, 2.38, 0.25), 1.44, 2.38), "canvas_white", tarp.lightened(0.05), Vector3.ZERO)
	for z: float in [1.45, 2.2]:
		k._box(m, Vector3(2.3, 0.03, 0.04), Vector3(0, 2.39, z), "plain_dark", null, Vector3.ZERO, false)
		for s: float in [-1.0, 1.0]:
			k._box(m, Vector3(0.03, 0.95, 0.04), Vector3(s * 1.03, 1.92, z), "plain_dark", null, Vector3(0, 0, s * 0.32), false)
	# the back: crates, sacks and jerrycans
	k._box(m, Vector3(0.82, 0.56, 0.58), Vector3(-0.62, 1.72, 3.1), "wood", null, Vector3(0, rng.randf_range(-0.12, 0.12), 0))
	k._box(m, Vector3(0.6, 0.4, 0.5), Vector3(-0.6, 2.2, 3.05), "wood_dark", null, Vector3(0, rng.randf_range(-0.3, 0.3), 0))
	for i in 3:
		k._box(m, Vector3(0.55, 0.22, 0.36), Vector3(0.5, 1.55 + i * 0.2, 2.95 + (i % 2) * 0.12), "canvas_white", Color(0.56, 0.5, 0.38), Vector3(0, rng.randf_range(-0.4, 0.4), 0))
	for i in 3:
		_jerrycan(k, m, Vector3(0.38 + i * 0.22, 1.44, 3.55), Color(0.3, 0.33, 0.23), PI / 2)


## Ammunition: palletised crates in stacks, strapped down, the front ones
## under a tarpaulin.
static func _zamak_ammo(k: VehicleModels, tarp: Color) -> void:
	var m := k.root
	var box := Color(0.3, 0.33, 0.22)
	for row in 3:
		var z := 0.4 + row * 1.13
		for s: float in [-1.0, 1.0]:
			var x: float = s * 0.6
			k._box(m, Vector3(1.05, 0.1, 0.98), Vector3(x, 1.49, z), "wood")
			if row == 0:
				continue
			k._box(m, Vector3(1.0, 0.72, 0.92), Vector3(x, 1.9, z), "paint", box)
			for y: float in [1.78, 2.02]:
				k._box(m, Vector3(1.02, 0.014, 0.94), Vector3(x, y, z), "plain_dark", null, Vector3.ZERO, false)
			k._box(m, Vector3(0.04, 0.74, 0.94), Vector3(x, 1.9, z), "plain_dark", null, Vector3.ZERO, false)
			k._box(m, Vector3(0.012, 0.05, 0.4), Vector3(x + s * 0.505, 1.66, z), "paint", Color(0.6, 0.52, 0.2), Vector3.ZERO, false)
	# the front stacks under a tarp, its rolled edge
	k._add(m, VehicleModels.loft("indep_zk_ammotarp", _oct(-1.2, 1.2, -0.18, 0.92, 0.04), _oct(-1.02, 1.02, -0.12, 0.86, 0.12), 1.54, 2.32), "canvas_white", tarp, Vector3.ZERO)
	k._cyl(m, 0.1, 0.1, 2.2, Vector3(0, 2.26, 0.95), Z90, "canvas_white", tarp.darkened(0.12), 10)
	for z: float in [0.12, 0.6]:
		k._box(m, Vector3(2.1, 0.03, 0.04), Vector3(0, 2.33, z), "plain_dark", null, Vector3.ZERO, false)
	k._cyl(m, 0.08, 0.08, 0.5, Vector3(1.0, 1.7, 3.5), Vector3.ZERO, "paint", Color(0.5, 0.12, 0.08), 10)


## A box body (kung) on the bed, z0..z1: chamfered, a roof cap, ribs.
static func _zamak_box(k: VehicleModels, cam: String, col, z0: float, z1: float, key: String) -> void:
	var m := k.root
	k._add(m, VehicleModels.loft(key, _oct(-1.24, 1.24, z0, z1, 0.06), _oct(-1.24, 1.24, z0, z1, 0.06), 1.44, 2.92), cam, col, Vector3.ZERO)
	k._add(m, VehicleModels.loft(key + "_roof", _oct(-1.24, 1.24, z0, z1, 0.06), _oct(-1.18, 1.18, z0 + 0.05, z1 - 0.05, 0.05), 2.92, 2.98), cam, col, Vector3.ZERO)
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.04, 0.05, z1 - z0 - 0.1), Vector3(s * 1.25, 1.5, (z0 + z1) * 0.5), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.04, 0.05, z1 - z0 - 0.1), Vector3(s * 1.25, 2.86, (z0 + z1) * 0.5), cam, col, Vector3.ZERO, false)
	# roof vents
	for z: float in [z0 + 0.6, z1 - 0.7]:
		k._cyl(m, 0.14, 0.16, 0.14, Vector3(-0.5, 3.04, z), Vector3.ZERO, cam, col, 10)
		k._cyl(m, 0.2, 0.2, 0.04, Vector3(-0.5, 3.12, z), Vector3.ZERO, "gunmetal_w", null, 10)


## Workshop truck: the box body with windows and a side door, a ladder up
## the back, the knuckle crane, generator and gas bottles on the open deck
## behind it.
static func _zamak_repair(k: VehicleModels, cam: String, col) -> void:
	var m := k.root
	_zamak_box(k, cam, col, -0.2, 2.85, "indep_zk_shop")
	for s: float in [-1.0, 1.0]:
		for z: float in [0.35, 1.5]:
			k._box(m, Vector3(0.03, 0.42, 0.62), Vector3(s * 1.245, 2.35, z), "glass", null, Vector3.ZERO, false)
			k._box(m, Vector3(0.05, 0.05, 0.7), Vector3(s * 1.25, 2.6, z), "gunmetal_w", null, Vector3.ZERO, false)
	# the side door on the right with its fold-down step, a locker on the left
	for dz: float in [2.0, 2.72]:
		k._box(m, Vector3(0.02, 1.32, 0.025), Vector3(1.25, 2.15, dz), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.04, 0.05, 0.14), Vector3(1.26, 2.1, 2.62), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.36, 0.04, 0.6), Vector3(1.38, 1.3, 2.36), "gunmetal_w")
	k._box(m, Vector3(0.02, 0.7, 0.9), Vector3(-1.255, 1.85, 2.35), cam, col)
	for i in 5:
		k._box(m, Vector3(0.02, 0.025, 0.86), Vector3(-1.27, 1.6 + i * 0.12, 2.35), "gunmetal_w", null, Vector3.ZERO, false)
	# a ladder up the back of the body
	for x: float in [-1.05, -0.75]:
		k._box(m, Vector3(0.04, 1.6, 0.04), Vector3(x, 2.25, 2.9), "gunmetal_w", null, Vector3.ZERO, false)
	for i in 6:
		k._box(m, Vector3(0.3, 0.03, 0.03), Vector3(-0.9, 1.6 + i * 0.26, 2.9), "gunmetal_w", null, Vector3.ZERO, false)
	# the crane on the deck: slewing base, column, the boom folded forward
	# over the roof, its ram and hook
	k._cyl(m, 0.26, 0.28, 0.24, Vector3(0.6, 1.56, 3.35), Vector3.ZERO, "gunmetal_w", null, 14)
	k._box(m, Vector3(0.26, 1.15, 0.28), Vector3(0.6, 2.25, 3.35), cam, col)
	var bc := Vector3(0.6, 3.02, 2.3)
	k._box(m, Vector3(0.2, 0.22, 2.3), bc, cam, col, Vector3(0.2, 0, 0))
	k._cyl(m, 0.05, 0.05, 1.0, Vector3(0.6, 2.62, 2.95), Vector3(-0.75, 0, 0), "steel", null, 8)
	k._box(m, Vector3(0.1, 0.2, 0.12), Vector3(0.6, 3.06, 1.08), "gunmetal_w")
	k._box(m, Vector3(0.06, 0.12, 0.08), Vector3(0.6, 2.98, 1.08), "paint", Color(0.6, 0.48, 0.12))
	# generator and gas bottles chained to the deck
	k._box(m, Vector3(0.75, 0.62, 0.5), Vector3(-0.42, 1.75, 3.45), "paint", Color(0.27, 0.3, 0.22))
	for i in 4:
		k._box(m, Vector3(0.02, 0.4, 0.02), Vector3(-0.68 + i * 0.12, 1.78, 3.705), "gunmetal_w", null, Vector3.ZERO, false)
	for i in 2:
		k._cyl(m, 0.11, 0.11, 1.05, Vector3(-1.02, 1.97, 3.2 + i * 0.26), Vector3.ZERO, "paint", [Color(0.42, 0.2, 0.14), Color(0.22, 0.27, 0.32)][i], 10)
		k._cyl(m, 0.05, 0.05, 0.1, Vector3(-1.02, 2.55, 3.2 + i * 0.26), Vector3.ZERO, "gunmetal_w", null, 8, false)


## Field ambulance: the box body with red crosses on white on both sides,
## the back doors and the roof; frosted windows, a step, an awning rolled up.
static func _zamak_medical(k: VehicleModels, cam: String, col) -> void:
	var m := k.root
	_zamak_box(k, cam, col, -0.2, 3.72, "indep_zk_med")
	var white := Color(0.84, 0.83, 0.78)
	var red := Color(0.62, 0.08, 0.07)
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.02, 0.92, 0.92), Vector3(s * 1.252, 2.2, 1.95), "paint", white, Vector3.ZERO, false)
		k._box(m, Vector3(0.02, 0.7, 0.22), Vector3(s * 1.262, 2.2, 1.95), "paint", red, Vector3.ZERO, false)
		k._box(m, Vector3(0.02, 0.22, 0.7), Vector3(s * 1.262, 2.2, 1.95), "paint", red, Vector3.ZERO, false)
		k._box(m, Vector3(0.03, 0.34, 0.6), Vector3(s * 1.245, 2.4, 0.4), "glass", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.03, 0.34, 0.6), Vector3(s * 1.245, 2.4, 3.15), "glass", null, Vector3.ZERO, false)
	# the roof: a white panel with its cross, the rolled awning
	k._box(m, Vector3(1.3, 0.02, 1.3), Vector3(0.2, 2.99, 1.9), "paint", white, Vector3.ZERO, false)
	k._box(m, Vector3(1.0, 0.02, 0.3), Vector3(0.2, 3.0, 1.9), "paint", red, Vector3.ZERO, false)
	k._box(m, Vector3(0.3, 0.02, 1.0), Vector3(0.2, 3.0, 1.9), "paint", red, Vector3.ZERO, false)
	k._cyl(m, 0.09, 0.09, 3.3, Vector3(1.2, 2.84, 1.76), X90, "canvas", Color(0.4, 0.4, 0.3), 10)
	# the back: two doors with the cross across them, handles, a step
	k._box(m, Vector3(0.02, 1.3, 0.025), Vector3(0, 2.15, 3.735), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.8, 0.8, 0.02), Vector3(0, 2.25, 3.735), "paint", white, Vector3.ZERO, false)
	k._box(m, Vector3(0.6, 0.18, 0.02), Vector3(0, 2.25, 3.745), "paint", red, Vector3.ZERO, false)
	k._box(m, Vector3(0.18, 0.6, 0.02), Vector3(0, 2.25, 3.745), "paint", red, Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.14, 0.04), Vector3(s * 0.12, 1.75, 3.75), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.04, 0.04, 0.08), Vector3(s * 1.0, 2.5, 3.74), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.9, 0.04, 0.22), Vector3(0, 1.28, 3.9), "gunmetal_w")
	k._box(m, Vector3(0.9, 0.04, 0.22), Vector3(0, 1.02, 3.96), "gunmetal_w")
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.04, 0.36, 0.04), Vector3(s * 0.45, 1.15, 3.93), "gunmetal_w", null, Vector3.ZERO, false)


## Fuel tanker: the elliptical tank on its saddles with dished ends, manholes
## and a walkway on top, the pump cabinet behind with a hose reel, a ladder,
## hazard placards.
static func _zamak_fuel(k: VehicleModels, cam: String, col) -> void:
	var m := k.root
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.16, 0.14, 4.0), Vector3(s * 0.48, 1.19, 1.775), "gunmetal_w")
	for z: float in [0.25, 1.5, 2.75]:
		k._box(m, Vector3(1.8, 0.2, 0.2), Vector3(0, 1.32, z), cam, col)
	var tc := Vector3(0, 2.02, 1.5)
	k._add(m, Res.cyl(1.0, 1.0, 3.1, 24), cam, col, tc, X90, Vector3(1.17, 1.0, 0.72))
	for e: float in [-1.0, 1.0]:
		k._add(m, Res.sphere(1.0, 20), cam, col, tc + Vector3(0, 0, e * 1.55), Vector3.ZERO, Vector3(1.17, 0.72, 0.16))
	for z: float in [0.3, 1.5, 2.7]:
		k._add(m, Res.cyl(1.0, 1.0, 0.06, 24), "gunmetal_w", null, Vector3(0, 2.02, z), X90, Vector3(1.19, 1.0, 0.74))
	# on top: two manholes, the walkway, fold-down rails
	for z: float in [0.75, 2.25]:
		k._cyl(m, 0.26, 0.28, 0.14, Vector3(0, 2.76, z), Vector3.ZERO, cam, col, 14)
		k._cyl(m, 0.2, 0.2, 0.06, Vector3(0, 2.86, z), Vector3.ZERO, "gunmetal_w", null, 12)
	k._box(m, Vector3(0.36, 0.03, 2.9), Vector3(-0.42, 2.73, 1.5), "gunmetal_w")
	for s: float in [-1.0, 1.0]:
		k._cyl(m, 0.02, 0.02, 2.7, Vector3(s * 0.62, 2.9, 1.5), X90, "gunmetal_w", null, 6, false)
		for z: float in [0.3, 1.5, 2.7]:
			k._cyl(m, 0.02, 0.02, 0.26, Vector3(s * 0.62, 2.78, z), Vector3.ZERO, "gunmetal_w", null, 6, false)
		# hazard placards and the fire extinguisher by the cabinet
		k._box(m, Vector3(0.02, 0.32, 0.42), Vector3(s * 1.17, 2.02, 1.5), "paint", Color(0.7, 0.42, 0.12), Vector3.ZERO, false)
		k._cyl(m, 0.08, 0.08, 0.45, Vector3(s * 1.2, 1.75, 3.25), Vector3.ZERO, "paint", Color(0.5, 0.1, 0.08), 10)
	# the pump cabinet at the back: louvred doors, the hose reel on top,
	# a ladder up its back
	k._box(m, Vector3(2.3, 1.05, 0.62), Vector3(0, 1.88, 3.48), cam, col)
	k._box(m, Vector3(0.02, 0.95, 0.02), Vector3(0, 1.88, 3.8), "gunmetal_w", null, Vector3.ZERO, false)
	for i in 4:
		k._box(m, Vector3(0.8, 0.025, 0.02), Vector3(0.55, 2.1 + i * 0.07, 3.8), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.34, 0.3, 0.02), Vector3(-0.55, 2.0, 3.8), "paint", Color(0.7, 0.42, 0.12), Vector3.ZERO, false)
	k._box(m, Vector3(1.2, 0.06, 0.5), Vector3(0.45, 2.43, 3.48), "gunmetal_w")
	k._cyl(m, 0.26, 0.26, 0.52, Vector3(0.45, 2.7, 3.48), Z90, "rubber", null, 16)
	k._cyl(m, 0.29, 0.29, 0.03, Vector3(0.18, 2.7, 3.48), Z90, "gunmetal_w", null, 16)
	k._cyl(m, 0.29, 0.29, 0.03, Vector3(0.72, 2.7, 3.48), Z90, "gunmetal_w", null, 16)
	for x: float in [-1.0, -0.72]:
		k._box(m, Vector3(0.04, 1.25, 0.04), Vector3(x, 1.95, 3.82), "gunmetal_w", null, Vector3.ZERO, false)
	for i in 5:
		k._box(m, Vector3(0.28, 0.03, 0.03), Vector3(-0.86, 1.45 + i * 0.25, 3.82), "gunmetal_w", null, Vector3.ZERO, false)
	# under the back: tail lights, bumper, pintle
	for s: float in [-1.0, 1.0]:
		_light(k, m, Vector3(s * 0.98, 1.16, 3.74), 0.24, 0.1, 1.0, false, true)
	k._box(m, Vector3(2.0, 0.1, 0.1), Vector3(0, 0.82, 3.72), "gunmetal_w")
	k._box(m, Vector3(0.14, 0.14, 0.2), Vector3(0, 0.98, 3.74), "gunmetal_w")


## The MRL: a flat deck carrying the 12-cell launcher pod on a traversing
## turntable (k.turret), the pod hinged at its back (k.elev) and resting
## level, pointing forward over the cab; stabiliser jacks at the back.
static func _zamak_mrl(k: VehicleModels, cam: String, col) -> void:
	var m := k.root
	for s: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.14, 4.05), Vector3(s * 1.225, 1.51, 1.775), cam, col)
		# stabiliser jacks behind the rear wheels, raised
		k._box(m, Vector3(0.18, 0.4, 0.22), Vector3(s * 1.08, 1.05, 3.5), cam, col)
		k._cyl(m, 0.06, 0.06, 0.45, Vector3(s * 1.08, 0.78, 3.5), Vector3.ZERO, "steel", null, 8)
		k._box(m, Vector3(0.3, 0.05, 0.3), Vector3(s * 1.08, 0.55, 3.5), "gunmetal_w")
	# the fire-control and reload boxes at the front of the deck
	k._box(m, Vector3(2.3, 0.5, 0.5), Vector3(0, 1.69, 0.1), cam, col)
	k._box(m, Vector3(2.32, 0.03, 0.02), Vector3(0, 1.8, -0.155), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.6, 0.3, 0.02), Vector3(-0.6, 1.66, -0.155), cam, col)
	# the turntable and its trunnion brackets
	var t := k._pivot(m, Vector3(0, 1.44, 2.45))
	k.turret = t
	k._cyl(t, 0.82, 0.84, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, "gunmetal_w", null, 20)
	k._cyl(t, 0.72, 0.76, 0.24, Vector3(0, 0.22, 0), Vector3.ZERO, cam, col, 20)
	for s: float in [-1.0, 1.0]:
		k._box(t, Vector3(0.14, 0.62, 0.62), Vector3(s * 0.84, 0.5, 0.4), cam, col)
		k._cyl(t, 0.1, 0.1, 0.2, Vector3(s * 0.84, 0.72, 0.62), Z90, "gunmetal_w", null, 10)
	# the elevating ram's base on the turntable
	k._box(t, Vector3(0.3, 0.22, 0.4), Vector3(0, 0.42, -0.45), "gunmetal_w")
	# the pod: twelve cells, three rows of four, its frame bands and covers
	var e := k._pivot(t, Vector3(0, 0.72, 0.62))
	k.elev = e
	k._box(e, Vector3(1.48, 0.96, 3.05), Vector3(0, 0.42, -1.4), cam, col)
	for bz: float in [-0.3, -1.4, -2.5]:
		k._box(e, Vector3(1.52, 1.0, 0.07), Vector3(0, 0.42, bz), "gunmetal_w")
	k._box(e, Vector3(1.5, 0.98, 0.06), Vector3(0, 0.42, -2.92), "gunmetal_w")
	for i in 12:
		var cx := -0.51 + (i % 4) * 0.34
		var cy := 0.14 + floorf(i / 4.0) * 0.28
		k._cyl(e, 0.115, 0.115, 0.04, Vector3(cx, cy, -2.95), X90, "plain_dark", null, 12, false)
	k._box(e, Vector3(1.44, 0.9, 0.04), Vector3(0, 0.42, 0.13), "plain_dark")
	k._box(e, Vector3(0.3, 0.2, 0.4), Vector3(0.82, 0.3, -0.8), "gunmetal_w")
	k._box(e, Vector3(0.2, 0.3, 0.2), Vector3(0, 0.0, -2.4), "gunmetal_w")
	k.gun_tip = k._tip(e, Vector3(0, 0.42, -3.0))
