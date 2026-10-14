class_name VmBoat
extends RefCounted
## Procedural models: boats and the SDV.
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys must be unique per shape).
##
## The map has no water yet, so a boat sits with its keel on y = 0 (on a
## trailer, or beached) and its outboards trimmed up just clear of the ground.
## Planing hulls are lofted through many cross-sections (a V-bottom with hard
## chines, sharp at the stem, flat at the transom); inflatable tubes are runs
## of capsules along the outline.

## Every model key this file builds (the Field Manual's model pages list them).
const KEYS: Array[String] = ["assault_boat", "motorboat", "rhib", "sdv", "speedboat_minigun", "speedboat_hmg", "water_scooter"]

## Station spacing along a hull, transom (0) to stem (1): closer toward the
## bow, where the shape changes fastest.
const US := [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.58, 0.66, 0.73, 0.79, 0.84, 0.88, 0.915, 0.945, 0.97, 0.988, 1.0]

## Planing hulls (see _station): z0 the transom, len, b sheer half-beam, bc
## chine half-beam, kh keel half-width, ys0/ys1 sheer height aft/at the stem,
## dr0/dr1 deadrise aft/forward (rad), fore where the forefoot starts to rise
## (0..1 from the transom), kb keel height at the stem and kp its curve,
## ent/entc where the sheer/chine start to narrow, pb/pc how full the bow is in
## plan, cl chine lift toward the bow; kn/th a knuckle (that fraction of the
## way from the chine to the sheer) with the sides tumbling home above it;
## marks: depths below the sheer where a painted stripe runs (extra section
## points there keep the stripe on flat faces).
const MOTORBOAT := {"z0": 2.9, "len": 5.9, "b": 1.12, "bc": 0.82, "kh": 0.03, "ys0": 0.9, "ys1": 1.28, "dr0": 0.33, "dr1": 0.9,
	"fore": 0.45, "kb": 1.02, "kp": 2.2, "ent": 0.4, "entc": 0.3, "pb": 2.3, "pc": 1.6, "cl": 0.12, "marks": [0.25, 0.15]}
const RHIB := {"z0": 3.75, "len": 7.85, "b": 1.08, "bc": 0.98, "kh": 0.04, "ys0": 0.82, "ys1": 1.12, "dr0": 0.42, "dr1": 0.95,
	"fore": 0.42, "kb": 0.88, "kp": 2.0, "ent": 0.35, "entc": 0.3, "pb": 1.8, "pc": 1.5, "cl": 0.1}
const SURC := {"z0": 5.7, "len": 11.8, "b": 1.55, "bc": 1.38, "kh": 0.05, "ys0": 1.3, "ys1": 1.75, "dr0": 0.36, "dr1": 0.95,
	"fore": 0.4, "kb": 1.38, "kp": 2.0, "ent": 0.5, "entc": 0.4, "pb": 1.8, "pc": 1.4, "cl": 0.12, "kn": 0.55, "th": 0.9}
const SCOOTER := {"z0": 1.48, "len": 3.18, "b": 0.6, "bc": 0.5, "kh": 0.02, "ys0": 0.4, "ys1": 0.55, "dr0": 0.38, "dr1": 0.85,
	"fore": 0.4, "kb": 0.42, "kp": 2.0, "ent": 0.45, "entc": 0.35, "pb": 2.8, "pc": 2.0, "cl": 0.05, "marks": [0.12, 0.075]}

const STAINLESS := Color(0.62, 0.63, 0.63)


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"assault_boat":
			_zodiac(k, team)
		"motorboat":
			_motorboat(k, seed)
		"rhib":
			_rhib(k, team)
		"sdv":
			_sdv(k, team)
		"speedboat_minigun":
			_surc(k, team, false)
		"speedboat_hmg":
			_surc(k, team, true)
		"water_scooter":
			_scooter(k, seed)
		_:
			return false
	return true


# --- hull geometry -----------------------------------------------------------------
## A hull station is [z, side]: side is the right half of the cross-section as
## [x, y, x, y, ...] from the keel up to the sheer, heights rising, with the
## same number of points at every station of one hull.

static func _station(p: Dictionary, u: float) -> Array:
	var s := clampf((u - float(p["ent"])) / (1.0 - float(p["ent"])), 0.0, 1.0)
	var sc := clampf((u - float(p["entc"])) / (1.0 - float(p["entc"])), 0.0, 1.0)
	var f := clampf((u - float(p["fore"])) / (1.0 - float(p["fore"])), 0.0, 1.0)
	var bs: float = float(p["b"]) * (1.0 - pow(s, float(p["pb"])))
	var kh: float = float(p["kh"]) * (1.0 - s)
	var bc: float = clampf(float(p["bc"]) * (1.0 - pow(sc, float(p["pc"]))), kh, maxf(bs, kh))
	var ky: float = float(p["kb"]) * pow(f, float(p["kp"]))
	var ys := _sheer(p, u)
	var dr := lerpf(float(p["dr0"]), float(p["dr1"]), pow(u, 1.5))
	var cy := clampf(ky + (bc - kh) * tan(dr) + float(p["cl"]) * pow(u, 3.0), ky, ys - 0.03)
	var side := [kh, ky, bc, cy]
	if p.has("kn"):
		side.append_array([bs, lerpf(cy, ys, float(p["kn"])), bs * float(p["th"]), ys])
	else:
		# extra points on the topsides at "marks" (depths below the sheer), so a
		# painted stripe there lies on flat faces of the hull, not across them
		for d in p.get("marks", []):
			var y := clampf(ys - float(d), cy, ys)
			side.append_array([lerpf(bc, bs, (y - cy) / maxf(ys - cy, 1e-5)), y])
		side.append_array([bs, ys])
	# keep the section convex: a deep-V bow can't flare out above its chine,
	# so there the chine eases onto the straight line from keel to sheer
	var n := side.size() >> 1
	for _pass in 2:
		for i in range(1, n - 1):
			var ay: float = side[i * 2 - 1]
			var cy2: float = side[i * 2 + 3]
			var t := (float(side[i * 2 + 1]) - ay) / maxf(cy2 - ay, 1e-5)
			var xc := lerpf(side[i * 2 - 2], side[i * 2 + 2], t)
			if float(side[i * 2]) < xc + 0.004:
				side[i * 2] = xc + 0.004
	return [float(p["z0"]) - u * float(p["len"]), side]


static func _sheer(p: Dictionary, u: float) -> float:
	return float(p["ys0"]) + (float(p["ys1"]) - float(p["ys0"])) * u * u


## Where the stem is at height y (on the forefoot's curve).
static func _stem(p: Dictionary, y: float) -> float:
	var f := pow(clampf(y / float(p["kb"]), 0.0, 1.0), 1.0 / float(p["kp"]))
	return float(p["z0"]) - (float(p["fore"]) + f * (1.0 - float(p["fore"]))) * float(p["len"])


## The station parameter (0 transom .. 1 stem) at z.
static func _u(p: Dictionary, z: float) -> float:
	return clampf((float(p["z0"]) - z) / float(p["len"]), 0.0, 1.0)


## The stations between u0 and u1 (both ends included).
static func _hull(p: Dictionary, u0 := 0.0, u1 := 1.0) -> Array:
	var out := [_station(p, u0)]
	for u in US:
		if u > u0 + 0.004 and u < u1 - 0.004:
			out.append(_station(p, u))
	out.append(_station(p, u1))
	return out


## Half-width of a section at height y.
static func _hw(side: Array, y: float) -> float:
	var n := side.size() >> 1
	if y <= float(side[1]):
		return side[0]
	for i in range(1, n):
		var y1: float = side[i * 2 + 1]
		if y <= y1:
			var y0: float = side[i * 2 - 1]
			return lerpf(side[i * 2 - 2], side[i * 2], (y - y0) / maxf(y1 - y0, 1e-5))
	return side[n * 2 - 2]


static func _top(st: Array) -> float:
	var side: Array = st[1]
	return side[side.size() - 1]


static func _beam(st: Array) -> float:
	var side: Array = st[1]
	return side[side.size() - 2]


## The hull section between heights y0 and y1 (clamped to the hull) as a
## convex ring; `crown` raises the middle of the top (a cambered deck),
## `inset` pulls the sides in.
static func _band(st: Array, y0: float, y1: float, crown := 0.0, inset := 0.0) -> PackedVector3Array:
	var z: float = st[0]
	var side: Array = st[1]
	var n := side.size() >> 1
	var a := clampf(y0, side[1], side[n * 2 - 1])
	var b := clampf(y1, side[1], side[n * 2 - 1])
	var ys := []
	for i in n:
		ys.append(clampf(side[i * 2 + 1], a, b))
	var r := PackedVector3Array()
	for y in ys:
		r.append(Vector3(maxf(_hw(side, y) - inset, 0.0), y, z))
	r.append(Vector3(0, b + crown, z))
	for i in range(n - 1, -1, -1):
		r.append(Vector3(-maxf(_hw(side, ys[i]) - inset, 0.0), ys[i], z))
	return r


## A thin skin on one side (s = +-1) of the hull between heights y0 and y1:
## `out` proud of the hull, `inn` into it (topsides, a painted stripe).
static func _skin(st: Array, y0: float, y1: float, out: float, inn: float, s: float) -> PackedVector3Array:
	var z: float = st[0]
	var side: Array = st[1]
	var n := side.size() >> 1
	var a := clampf(y0, side[1], side[n * 2 - 1])
	var b := clampf(y1, side[1], side[n * 2 - 1])
	var wa := _hw(side, a)
	var wb := _hw(side, b)
	return PackedVector3Array([Vector3(s * (wa + out), a, z), Vector3(s * (wb + out), b, z), Vector3(s * (wb - inn), b, z), Vector3(s * (wa - inn), a, z)])


static func _band_mesh(key: String, sts: Array, y0: float, y1: float, crown := 0.0, inset := 0.0) -> ArrayMesh:
	var rings := []
	for st in sts:
		rings.append(_band(st, y0, y1, crown, inset))
	return VehicleModels.solid(rings, key)


## A piece of the hull's section between za and zb (a bulkhead, a transom, a
## seat box built into the hull).
static func _slab(p: Dictionary, key: String, za: float, zb: float, y0: float, y1: float, inset := 0.0) -> ArrayMesh:
	return VehicleModels.solid([_band(_station(p, _u(p, za)), y0, y1, 0.0, inset), _band(_station(p, _u(p, zb)), y0, y1, 0.0, inset)], key)


## A non-skid deck overlay `t` thick, `inset` in from the sheer.
static func _deck_mesh(key: String, sts: Array, inset: float, t: float) -> ArrayMesh:
	var rings := []
	for st in sts:
		var ys := _top(st)
		var x := maxf(_beam(st) - inset, 0.02)
		rings.append(_rz([x, ys - 0.03, x, ys + t, -x, ys + t, -x, ys - 0.03], st[0]))
	return VehicleModels.solid(rings, key)


## A strip along a run of points (a rubbing strake, a spray rail): a small
## rectangle across each point, the points in order along z.
static func _strip(key: String, pts: Array, hw: float, hh: float) -> ArrayMesh:
	var rings := []
	for q in pts:
		var c: Vector3 = q
		rings.append(PackedVector3Array([Vector3(c.x - hw, c.y - hh, c.z), Vector3(c.x + hw, c.y - hh, c.z), Vector3(c.x + hw, c.y + hh, c.z), Vector3(c.x - hw, c.y + hh, c.z)]))
	return VehicleModels.solid(rings, key)


## A ring across z from [x, y, x, y, ...].
static func _rz(xy: Array, z: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in range(0, xy.size(), 2):
		r.append(Vector3(xy[i], xy[i + 1], z))
	return r


## A ring at height y from [x, z, x, z, ...].
static func _ry(xz: Array, y: float) -> PackedVector3Array:
	return VehicleModels.ring_y(VehicleModels._v2(xz), y)


## A chamfered rectangle outline [x, z, ...]: w wide, l long, centred on zc,
## the corners cut by cf at the front and cr at the back.
static func _rr(w: float, l: float, zc: float, cf: float, cr: float) -> Array:
	var x := w * 0.5
	var f := zc - l * 0.5
	var b := zc + l * 0.5
	return [-x + cf, f, x - cf, f, x, f + cf, x, b - cr, x - cr, b, -x + cr, b, -x, b - cr, -x, f + cf]


## A rounded rectangle outline [x, z, ...]: w wide, l long, centred on zc,
## corner radius rf at the front and rb at the back, k points to a corner.
static func _rnd(w: float, l: float, zc: float, rf: float, rb: float, k := 3) -> Array:
	var out := []
	var x := w * 0.5
	var f := zc - l * 0.5
	var b := zc + l * 0.5
	for c in [[x - rf, f + rf, rf, -PI / 2], [x - rb, b - rb, rb, 0.0], [-x + rb, b - rb, rb, PI / 2], [-x + rf, f + rf, rf, PI]]:
		for i in k:
			var a: float = float(c[3]) + (PI / 2) * i / (k - 1)
			out.append_array([float(c[0]) + cos(a) * float(c[2]), float(c[1]) + sin(a) * float(c[2])])
	return out


## A streamlined strut outline [x, z, ...]: w thick, c chord from z0 aft.
static func _foil(w: float, c: float, z0: float) -> Array:
	var h := w * 0.5
	return [0.0, z0, h * 0.7, z0 + c * 0.06, h, z0 + c * 0.28, h * 0.8, z0 + c * 0.62, h * 0.12, z0 + c,
		-h * 0.12, z0 + c, -h * 0.8, z0 + c * 0.62, -h, z0 + c * 0.28, -h * 0.7, z0 + c * 0.06]


## A rounded-rectangle (superellipse) ring across z: half-width a, half-height
## b about height yc; e = 2 is an ellipse, higher is squarer.
static func _sring(a: float, b: float, yc: float, z: float, e: float, n := 20) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in n:
		var t := TAU * i / n
		var c := cos(t)
		var s := sin(t)
		r.append(Vector3(a * signf(c) * pow(absf(c), 2.0 / e), yc + b * signf(s) * pow(absf(s), 2.0 / e), z))
	return r


# --- part helpers ------------------------------------------------------------------

## Euler angles that turn +Y onto d (either way along it).
static func _aim(d: Vector3) -> Vector3:
	var n := d.normalized()
	if n.y < 0.0:
		n = -n
	if n.y > 0.99999:
		return Vector3.ZERO
	return Basis(Quaternion(Vector3.UP, n)).get_euler()


## A rod from a to b (rails, ropes, struts).
static func _rod(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, r: float, mat: String, col = null, segs := 6, shadow := false) -> void:
	k._cyl(parent, r, r, a.distance_to(b), (a + b) * 0.5, _aim(b - a), mat, col, segs, shadow)


## An inflatable tube along a path: a capsule per leg, the joints rounding
## themselves off.
static func _tube(k: VehicleModels, parent: Node3D, pts: Array, r: float, mat: String, col = null) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var mesh: Mesh = VehicleModels._capsule(r, a.distance_to(b) + r * 2.0) if r >= 0.1 else Res.capsule(r, a.distance_to(b) + r * 2.0, 8)
		k._add(parent, mesh, mat, col, (a + b) * 0.5, _aim(b - a))


## Points every `step` metres along a polyline (both ends kept).
static func _resample(pts: Array, step: float) -> Array:
	var out := [pts[0]]
	var carry := 0.0
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := a.distance_to(b)
		var t := step - carry
		while t < d:
			out.append(a.lerp(b, t / d))
			t += step
		carry = d - (t - step)
	if (out[out.size() - 1] as Vector3).distance_to(pts[pts.size() - 1]) > step * 0.3:
		out.append(pts[pts.size() - 1])
	return out


## The path pushed `out` outward in plan (away from the centreline, round a
## bow centred on cz) and `up`.
static func _offset(pts: Array, out: float, up: float, cz: float) -> Array:
	var res := []
	for i in pts.size():
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var t := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		var nrm := Vector3(-t.z, 0, t.x)
		var p: Vector3 = pts[i]
		if nrm.dot(Vector3(p.x, 0, p.z - cz)) < 0.0:
			nrm = -nrm
		res.append(p + nrm * out + Vector3(0, up, 0))
	return res


## The hardware along an inflatable tube: a rubbing strake low on its outer
## side, a lifeline looped through patches along the top, carrying handles on
## the inboard side. `ax` is the tube's centreline (one side, aft to bow).
static func _tube_kit(k: VehicleModels, parent: Node3D, ax: Array, r: float, cz: float, mat: String, col: Color, s: float) -> void:
	var side := []
	for q in ax:
		var v: Vector3 = q
		side.append(Vector3(v.x * s, v.y, v.z))
	_tube(k, parent, _offset(side, r * 0.92, -r * 0.2, cz), 0.045, mat, col.darkened(0.3))
	var rs := _resample(side, r * 1.05)
	var hi := _offset(rs, (r + 0.012) * cos(0.88), (r + 0.012) * sin(0.88), cz)
	var lo := _offset(rs, (r + 0.012) * cos(0.72), (r + 0.012) * sin(0.72), cz)
	var prev: Vector3 = hi[0]
	for i in range(1, rs.size()):
		var q: Vector3 = hi[i] if i % 2 == 0 else lo[i]
		_rod(k, parent, prev, q, 0.011, "canvas", Color(0.17, 0.17, 0.16), 5)
		if i % 2 == 0:
			k._box(parent, Vector3(0.07, 0.03, 0.07), q, mat, col.lightened(0.08), Vector3.ZERO, false)
		prev = q
	# carrying handles on the inboard top
	var inner := _offset(rs, -(r + 0.01) * cos(1.0), (r + 0.01) * sin(1.0), cz)
	for i in range(2, inner.size() - 3, 4):
		k._box(parent, Vector3(0.05, 0.04, 0.2), inner[i], "rubber", null, Vector3.ZERO, false)


## A thin panel laid on the quad face p0-p1-p2-p3 (a window, a hatch, a
## door), `inset` in from its edges, `t` thick, standing `lift` proud of the
## face (outward = away from `inside`).
static func _panel(k: VehicleModels, parent: Node3D, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, inside: Vector3, inset: float, t: float, mat: String, col = null, lift := 0.0) -> void:
	var u := ((p1 - p0) + (p2 - p3)) * 0.5
	var v := ((p3 - p0) + (p2 - p1)) * 0.5
	var c := (p0 + p1 + p2 + p3) * 0.25
	var n := u.cross(v).normalized()
	if n.dot(c - inside) < 0.0:
		n = -n
	var x := u.normalized()
	var y := n.cross(x).normalized()
	var b := Basis(x, y, n)
	k._box(parent, Vector3(maxf(u.length() - inset * 2.0, 0.02), maxf(v.length() - inset * 2.0, 0.02), t), c + n * lift, mat, col, b.get_euler(), false)


## A point of a flat [x, z, ...] outline at height y.
static func _pt(xz: Array, i: int, y: float) -> Vector3:
	return Vector3(xz[i * 2], y, xz[i * 2 + 1])


## A horn cleat at pos, its horns along `yaw` (0 = fore and aft).
static func _cleat(k: VehicleModels, parent: Node3D, pos: Vector3, yaw := 0.0, sc := 1.0) -> void:
	for dz in [-0.035, 0.035]:
		k._box(parent, Vector3(0.03, 0.045, 0.025) * sc, pos + Basis(Vector3.UP, yaw) * Vector3(0, 0.022, dz) * sc, "steel", STAINLESS, Vector3(0, yaw, 0), false)
	k._box(parent, Vector3(0.028, 0.024, 0.2) * sc, pos + Vector3(0, 0.05 * sc, 0), "steel", STAINLESS, Vector3(0, yaw, 0), false)


## A propeller on an axis along z: a hub with a tail cone and n twisted blades.
static func _prop(k: VehicleModels, parent: Node3D, pos: Vector3, r: float, n: int, mat: String, col = null) -> void:
	k._cyl(parent, r * 0.26, r * 0.3, r * 0.5, pos, Vector3(PI / 2, 0, 0), mat, col, 10, false)
	k._cyl(parent, r * 0.06, r * 0.26, r * 0.4, pos + Vector3(0, 0, r * 0.45), Vector3(PI / 2, 0, 0), mat, col, 10, false)
	for i in n:
		var rz := Basis(Vector3(0, 0, 1), TAU * i / n)
		k._box(parent, Vector3(r * 0.62, r * 0.76, 0.008), pos + rz * Vector3(0, r * 0.6, 0), mat, col, (rz * Basis(Vector3(0, 1, 0), 0.7)).get_euler(), false)


## An outboard motor hung on a transom. `pos` is its tilt tube on the top of
## the transom's aft face, the leg reaching `leg` below it to the
## anti-ventilation plate; `s` scales it (0.75 a 55 hp tiller motor, 1 a
## 150 hp, 1.15 a 250 hp). It's trimmed up just far enough that the skeg and
## propeller clear the ground. Returns the tilting motor (-z toward the boat).
static func _outboard(k: VehicleModels, parent: Node3D, pos: Vector3, s: float, leg: float, cowl: String, ccol, low: String, lcol, key: String) -> Node3D:
	# the clamp bracket on the transom and its tilt tube
	k._box(parent, Vector3(0.26 * s, 0.3 * s, 0.07), pos + Vector3(0, -0.13 * s, -0.02), "gunmetal_w")
	k._cyl(parent, 0.028 * s, 0.028 * s, 0.32 * s, pos + Vector3(0, 0, 0.02), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8, false)
	var mo := k._pivot(parent, pos + Vector3(0, 0, 0.03))
	var th := 0.0
	while th < 1.3:
		var lowest := minf(-(leg + 0.32 * s) * cos(th) + 0.42 * s * sin(th), -(leg + 0.27 * s) * cos(th) + 0.6 * s * sin(th))
		if pos.y + lowest >= 0.03:
			break
		th += 0.02
	mo.rotation.x = -th
	# swivel bracket and the leg, a streamlined strut down to the gearcase
	k._box(mo, Vector3(0.16 * s, 0.3 * s, 0.12 * s), Vector3(0, -0.1 * s, 0.07 * s), low, lcol)
	var c := 0.36 * s
	k._add(mo, VehicleModels.solid([_ry(_foil(0.17 * s, c, 0.04 * s), 0.0), _ry(_foil(0.1 * s, c * 0.85, 0.08 * s), -leg - 0.07 * s)], key + "_leg"), low, lcol, Vector3.ZERO)
	# anti-ventilation plate, the gearcase torpedo, skeg and propeller
	k._box(mo, Vector3(0.34 * s, 0.018, 0.42 * s), Vector3(0, -leg, 0.28 * s), low, lcol)
	k._add(mo, Res.sphere(0.5, 14), low, lcol, Vector3(0, -leg - 0.1 * s, 0.27 * s), Vector3.ZERO, Vector3(0.15 * s, 0.15 * s, 0.6 * s))
	k._box(mo, Vector3(0.024, 0.2 * s, 0.15 * s), Vector3(0, -leg - 0.21 * s, 0.4 * s), low, lcol, Vector3(-0.3, 0, 0))
	k._box(mo, Vector3(0.05, 0.05, 0.1) * s, Vector3(0, -leg - 0.035 * s, 0.42 * s), "gunmetal_w", null, Vector3.ZERO, false)
	_prop(k, mo, Vector3(0, -leg - 0.1 * s, 0.6 * s), 0.17 * s, 3, "steel", Color(0.48, 0.48, 0.47))
	# the lower cowl (apron), the cowling with its parting line and air intake
	k._box(mo, Vector3(0.42 * s, 0.17 * s, 0.6 * s), Vector3(0, 0.04 * s, 0.29 * s), low, lcol)
	var w := 0.5 * s
	var l := 0.74 * s
	var h := 0.6 * s
	var zc := 0.3 * s
	var y0 := 0.12 * s
	k._add(mo, VehicleModels.solid([_ry(_rnd(w, l, zc, 0.1 * s, 0.2 * s), y0), _ry(_rnd(w * 1.03, l * 1.02, zc + 0.01 * s, 0.11 * s, 0.21 * s), y0 + h * 0.55),
		_ry(_rnd(w * 0.94, l * 0.96, zc + 0.03 * s, 0.1 * s, 0.2 * s), y0 + h * 0.86), _ry(_rnd(w * 0.7, l * 0.78, zc + 0.06 * s, 0.08 * s, 0.15 * s), y0 + h)], key + "_cowl"), cowl, ccol, Vector3.ZERO)
	k._add(mo, VehicleModels.solid([_ry(_rr(w + 0.014, l + 0.014, zc, 0.1 * s, 0.17 * s), y0 + 0.015), _ry(_rr(w + 0.014, l + 0.014, zc, 0.1 * s, 0.17 * s), y0 + 0.05 * s)], key + "_band"), low, lcol, Vector3.ZERO)
	k._box(mo, Vector3(w * 0.42, 0.05 * s, 0.03), Vector3(0, y0 + h * 0.8, zc + l * 0.5 + 0.01), "gunmetal_w", null, Vector3.ZERO, false)
	return mo


## Moves a tilted assembly's parts onto its parent, where they already are:
## the Field Manual stands a model on the lowest corner of its parts' boxes,
## and a rotated sub-node's box reaches lower than its parts do.
static func _bake(pv: Node3D) -> void:
	var par := pv.get_parent() as Node3D
	for c in pv.get_children():
		var n := c as Node3D
		var t: Transform3D = pv.transform * n.transform
		pv.remove_child(n)
		par.add_child(n)
		n.transform = t
	par.remove_child(pv)
	pv.free()


# --- Zodiac F470 ---------------------------------------------------------------------

## Zodiac F470 combat rubber raiding craft: a U of black Hypalon tube round a
## flat floor, the tube ends running on past a low plywood transom with a
## 55 hp tiller outboard; lifelines, paddles and a fuel tank aboard.
static func _zodiac(k: VehicleModels, team: int) -> void:
	var m := k.root
	var tm := "plain_dark"
	var tc := Color(0.12, 0.12, 0.125)
	var r := 0.25
	var zt := 1.95  # the transom
	# the tube's centreline: straight sides into a round bow that kicks up
	var right := [Vector3(0.7, 0.27, zt), Vector3(0.7, 0.27, -0.55)]
	for i in range(1, 9):
		var a := PI * 0.5 * i / 8.0
		right.append(Vector3(0.7 * cos(a), 0.27 + 0.15 * pow(sin(a), 2.0), -0.55 - 1.55 * sin(a)))
	var path := right.duplicate()
	for i in range(right.size() - 2, -1, -1):
		var q: Vector3 = right[i]
		path.append(Vector3(-q.x, q.y, q.z))
	_tube(k, m, path, r, tm, tc)
	for s in [-1.0, 1.0]:
		# the tube ends: cones past the transom
		k._cyl(m, 0.16, r, 0.3, Vector3(s * 0.7, 0.27, zt + 0.15), Vector3(PI / 2, 0, 0), tm, tc, 16)
		k._add(m, Res.sphere(0.16, 14), tm, tc, Vector3(s * 0.7, 0.27, zt + 0.3))
		# compartment seams round the tube
		for z in [0.95, -0.35]:
			k._cyl(m, r + 0.007, r + 0.007, 0.035, Vector3(s * 0.7, 0.27, z), Vector3(PI / 2, 0, 0), tm, tc.darkened(0.35), 16, false)
		_tube_kit(k, m, right, r, -0.6, tm, tc, s)
		# inflation valves on top
		for z in [1.45, 0.2]:
			k._cyl(m, 0.035, 0.035, 0.03, Vector3(s * 0.7, 0.27 + r, z), Vector3.ZERO, "plain", Color(0.3, 0.3, 0.29), 8, false)
	k._cyl(m, 0.035, 0.035, 0.03, Vector3(0.0, 0.42 + r, -2.1), Vector3.ZERO, "plain", Color(0.3, 0.3, 0.29), 8, false)
	# the hull: a shallow V of fabric under a flat floor, rising into the bow
	var rings := []
	for z in [zt, 1.0, 0.0, -0.55, -0.95, -1.3, -1.6, -1.82, -1.98]:
		var f := clampf((-0.55 - z) / 1.55, 0.0, 1.0)
		var hw := 0.7 * sqrt(1.0 - f * f) - 0.08
		var ky := 0.2 * f * f
		var top := 0.21 + 0.12 * f * f
		rings.append(_rz([0.05, ky, hw * 0.8, ky + 0.07, hw, top, -hw, top, -hw * 0.8, ky + 0.07, -0.05, ky], z))
	k._add(m, VehicleModels.solid(rings, "boat_crrc_floor"), tm, tc.lightened(0.04), Vector3.ZERO)
	# aluminium floorboards
	for zz in [[1.88, 0.94], [0.9, -0.06], [-0.1, -1.0]]:
		k._box(m, Vector3(0.84, 0.02, zz[0] - zz[1]), Vector3(0, 0.218, (zz[0] + zz[1]) * 0.5), "plain_dark", Color(0.2, 0.2, 0.2))
	# the transom with its knees and the motor pad
	k._box(m, Vector3(1.02, 0.5, 0.07), Vector3(0, 0.38, zt + 0.02), "paint", Color(0.12, 0.12, 0.12), Vector3(0.1, 0, 0))
	k._box(m, Vector3(0.34, 0.05, 0.15), Vector3(0, 0.635, zt + 0.045), "wood_dark")
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("boat_crrc_knee", [zt - 0.01, 0.6, zt - 0.01, 0.22, zt - 0.36, 0.22], -0.022, 0.022), "paint", Color(0.12, 0.12, 0.12), Vector3(s * 0.3, 0, 0))
	# 55 hp outboard on a tiller, its fuel tank and hose
	var mo := _outboard(k, m, Vector3(0, 0.62, zt + 0.1), 0.78, 0.5, "plain_dark", Color(0.14, 0.14, 0.145), "plain_dark", Color(0.12, 0.12, 0.125), "boat_crrc_ob")
	_rod(k, mo, Vector3(0, 0.1, 0.0), Vector3(0, 0.2, -0.62), 0.024, "gunmetal_w", null, 8, true)
	k._cyl(mo, 0.032, 0.032, 0.16, Vector3(0, 0.215, -0.7), _aim(Vector3(0, 0.1, -0.62)), "rubber", null, 8)
	_bake(mo)
	k._box(m, Vector3(0.34, 0.25, 0.5), Vector3(0.24, 0.355, 1.45), "paint", Color(0.27, 0.29, 0.21))
	k._box(m, Vector3(0.04, 0.05, 0.3), Vector3(0.24, 0.5, 1.45), "gunmetal_w", null, Vector3.ZERO, false)
	k._cyl(m, 0.035, 0.035, 0.04, Vector3(0.32, 0.49, 1.27), Vector3.ZERO, "plain", Color(0.18, 0.18, 0.17), 8, false)
	_rod(k, m, Vector3(0.24, 0.42, 1.7), Vector3(0.08, 0.62, 2.05), 0.012, "rubber", null, 5)
	# two paddles along the tubes, a rucksack and a dry bag lashed amidships
	for s in [-1.0, 1.0]:
		var pz := 0.35 if s > 0 else -0.05
		_rod(k, m, Vector3(s * 0.36, 0.25, pz + 0.75), Vector3(s * 0.36, 0.25, pz - 0.55), 0.016, "paint", Color(0.2, 0.21, 0.19), 6, true)
		k._box(m, Vector3(0.15, 0.02, 0.4), Vector3(s * 0.36, 0.25, pz - 0.75), "paint", Color(0.2, 0.21, 0.19))
	k._box(m, Vector3(0.42, 0.32, 0.52), Vector3(-0.12, 0.39, 0.35), "canvas", Color(0.33, 0.35, 0.25), Vector3(0, 0.18, 0))
	k._box(m, Vector3(0.36, 0.1, 0.3), Vector3(-0.1, 0.57, 0.27), "canvas", Color(0.3, 0.32, 0.23), Vector3(0, 0.18, 0))
	k._add(m, Res.capsule(0.13, 0.62, 12), "rubber", Color(0.1, 0.1, 0.1), Vector3(0.15, 0.36, -0.45), Vector3(0, 0.35, PI / 2))
	# the bow's towing ring and grab handle
	k._add(m, Res.torus(0.025, 0.05), "gunmetal_w", null, Vector3(0, 0.33, -2.36), Vector3(0, 0, PI / 2))
	k._box(m, Vector3(0.24, 0.04, 0.05), Vector3(0, 0.45 + r - 0.01, -1.98), "rubber", null, Vector3.ZERO, false)
	k._team_mark(m, team, Vector3(0.32, 0.42, zt + 0.07), Vector3(0.2, 0.12, 0.012))


# --- civilian motorboat -----------------------------------------------------------

## A small open centre-console runabout: a white V-hull with a coloured stripe
## and rub rail, a short foredeck with a bow rail, the console with its wrap
## windscreen, a helm bench and a stern bench, a 115 hp outboard.
static func _motorboat(k: VehicleModels, seed: int) -> void:
	var m := k.root
	var p := MOTORBOAT
	var hm := "plain"
	var white := Color(0.86, 0.86, 0.83)
	var stripe: Color = [Color(0.16, 0.24, 0.38), Color(0.42, 0.14, 0.12), Color(0.15, 0.33, 0.33), Color(0.18, 0.28, 0.42)][seed % 4]
	var vinyl := Color(0.86, 0.84, 0.78)
	var sole := 0.4
	var t := 0.06
	var zt: float = p["z0"]
	var zf := -1.5  # where the foredeck starts
	var uf := _u(p, zf)
	var aft := _hull(p, 0.0, uf)
	var fwd := _hull(p, uf, 1.0)
	var all := _hull(p)
	k._add(m, _band_mesh("boat_mb_bottom", aft, -9.0, sole), hm, white, Vector3.ZERO)
	k._add(m, _band_mesh("boat_mb_fore", fwd, -9.0, 9.0, 0.05), hm, white, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		# topsides round the cockpit, in two runs so they keep the chine
		var lo := []
		var hi := []
		for st in aft:
			var side: Array = st[1]
			var cy := maxf(float(side[3]), sole)
			lo.append(_skin(st, sole, cy, 0.0, t, s))
			hi.append(_skin(st, cy, 99.0, 0.0, t, s))
		k._add(m, VehicleModels.solid(lo, "boat_mb_wlo%d" % int(s)), hm, white, Vector3.ZERO)
		k._add(m, VehicleModels.solid(hi, "boat_mb_whi%d" % int(s)), hm, white, Vector3.ZERO)
		# the stripe, the rub rail under the sheer, spray rails on the bottom
		var sa := []
		var rail := []
		var chine := []
		var sp1 := []
		var sp2 := []
		for st in all:
			var side: Array = st[1]
			var ys := _top(st)
			var z: float = st[0]
			sa.append(_skin(st, ys - 0.25, ys - 0.15, 0.005, 0.03, s))
			rail.append(Vector3(s * (_beam(st) + 0.012), ys - 0.03, z))
			if z > -2.6:
				var kp := Vector2(side[0], side[1])
				var cp := Vector2(side[2], side[3])
				chine.append(Vector3(s * (cp.x + 0.012), cp.y - 0.006, z))
				var q1 := kp.lerp(cp, 0.38)
				var q2 := kp.lerp(cp, 0.7)
				sp1.append(Vector3(s * q1.x, q1.y - 0.006, z))
				sp2.append(Vector3(s * q2.x, q2.y - 0.006, z))
		k._add(m, VehicleModels.solid(sa, "boat_mb_stripe%d" % int(s)), "plain", stripe, Vector3.ZERO)
		k._add(m, _strip("boat_mb_rail%d" % int(s), rail, 0.02, 0.026), "rubber", Color(0.12, 0.12, 0.12), Vector3.ZERO)
		k._add(m, _strip("boat_mb_chine%d" % int(s), chine, 0.022, 0.01), hm, white, Vector3.ZERO)
		k._add(m, _strip("boat_mb_sp1%d" % int(s), sp1, 0.018, 0.012), hm, white, Vector3.ZERO)
		k._add(m, _strip("boat_mb_sp2%d" % int(s), sp2, 0.018, 0.012), hm, white, Vector3.ZERO)
	# the transom above the sole, notched for the motor, and the splash well
	k._add(m, _slab(p, "boat_mb_tr_lo", zt - 0.07, zt, sole - 0.01, 0.7), hm, white, Vector3.ZERO)
	var ta := _station(p, _u(p, zt - 0.07))
	var tb := _station(p, 0.0)
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.solid([_skin(ta, 0.7, 99.0, 0.0, 0.72, s), _skin(tb, 0.7, 99.0, 0.0, 0.72, s)], "boat_mb_tr_hi%d" % int(s)), hm, white, Vector3.ZERO)
	k._add(m, _slab(p, "boat_mb_well", zt - 0.46, zt - 0.06, sole - 0.01, 0.62, 0.02), hm, white, Vector3.ZERO)
	k._add(m, _slab(p, "boat_mb_bulk", zt - 0.5, zt - 0.44, sole - 0.01, 0.84, 0.02), hm, white, Vector3.ZERO)
	# the stern bench in front of it
	k._add(m, _slab(p, "boat_mb_bench", zt - 0.95, zt - 0.5, sole - 0.01, 0.68, 0.03), hm, white, Vector3.ZERO)
	k._box(m, Vector3(1.55, 0.08, 0.42), Vector3(0, 0.72, zt - 0.73), "canvas_white", vinyl)
	k._box(m, Vector3(1.55, 0.26, 0.08), Vector3(0, 0.92, zt - 0.5), "canvas_white", vinyl, Vector3(0.12, 0, 0))
	# the centre console: a sloped dash, a wrap windscreen, wheel and throttle
	var cz := -0.25
	k._add(m, VehicleModels.solid([_ry(_rr(0.76, 0.72, cz, 0.1, 0.03), sole - 0.01), _ry(_rr(0.76, 0.72, cz, 0.1, 0.03), 0.98), _ry(_rr(0.7, 0.38, cz - 0.15, 0.08, 0.02), 1.14)], "boat_mb_console"), hm, white, Vector3.ZERO)
	k._box(m, Vector3(0.72, 0.04, 0.4), Vector3(0, 1.15, cz - 0.15), hm, white.darkened(0.1))
	# the windscreen: a raked front pane and two side wings, framed, a grab rail on top
	var smoke := Color(0.2, 0.24, 0.27)
	k._box(m, Vector3(0.6, 0.32, 0.012), Vector3(0, 1.276, -0.496), "glass", smoke, Vector3(0.55, 0, 0), false)
	_rod(k, m, Vector3(-0.31, 1.41, -0.41), Vector3(0.31, 1.41, -0.41), 0.016, "gunmetal_w")
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.012, 0.25, 0.24), Vector3(s * 0.33, 1.27, -0.4), "glass", smoke, Vector3(0.0, -s * 0.22, 0), false)
		_rod(k, m, Vector3(s * 0.31, 1.41, -0.41), Vector3(s * 0.31, 1.14, -0.58), 0.016, "gunmetal_w")
		_rod(k, m, Vector3(s * 0.31, 1.41, -0.41), Vector3(s * 0.35, 1.15, -0.27), 0.014, "steel", STAINLESS)
	var dash := Vector3(0.46, 0, 0)  # the dash panel's tilt
	k._box(m, Vector3(0.26, 0.016, 0.15), Vector3(-0.12, 1.07, -0.06), "glass", null, dash, false)
	k._add(m, Res.torus(0.14, 0.165), "rubber", null, Vector3(0.12, 1.16, 0.03), dash)
	_rod(k, m, Vector3(0.12, 1.06, -0.03), Vector3(0.12, 1.16, 0.03), 0.02, "gunmetal_w")
	k._add(m, Res.sphere(0.05, 10), "glass", null, Vector3(0.0, 1.16, -0.48))
	k._box(m, Vector3(0.08, 0.1, 0.16), Vector3(0.41, 0.98, -0.05), "gunmetal_w")
	_rod(k, m, Vector3(0.43, 1.0, -0.05), Vector3(0.43, 1.18, 0.02), 0.012, "steel", STAINLESS)
	k._add(m, Res.sphere(0.025, 8), "rubber", null, Vector3(0.43, 1.19, 0.03))
	# a seat on a cool box in front of the console, the helm bench behind it
	k._box(m, Vector3(0.6, 0.34, 0.42), Vector3(0, sole + 0.17, -0.9), hm, white)
	k._box(m, Vector3(0.62, 0.08, 0.44), Vector3(0, sole + 0.38, -0.9), "canvas_white", vinyl)
	k._box(m, Vector3(0.88, 0.42, 0.48), Vector3(0, sole + 0.21, 0.72), hm, white)
	k._box(m, Vector3(0.92, 0.09, 0.5), Vector3(0, sole + 0.46, 0.72), "canvas_white", vinyl)
	k._box(m, Vector3(0.92, 0.36, 0.09), Vector3(0, sole + 0.72, 0.97), "canvas_white", vinyl, Vector3(0.18, 0, 0))
	_rod(k, m, Vector3(-0.44, sole + 0.93, 1.03), Vector3(0.44, sole + 0.93, 1.03), 0.014, "steel", STAINLESS)
	for s in [-1.0, 1.0]:
		_rod(k, m, Vector3(s * 0.44, sole + 0.93, 1.03), Vector3(s * 0.44, sole + 0.45, 0.98), 0.014, "steel", STAINLESS)
	# the bow rail on its stanchions
	var rp := []
	for u in [uf + 0.03, 0.8, 0.86, 0.91, 0.95, 0.98]:
		var st := _station(p, u)
		rp.append(Vector3(maxf(_beam(st) - 0.08, 0.0), _top(st) + 0.38, st[0]))
	var tip := _station(p, 0.995)
	rp.append(Vector3(0, _top(tip) + 0.36, float(tip[0]) - 0.02))
	for s in [-1.0, 1.0]:
		for i in rp.size() - 1:
			var a: Vector3 = rp[i]
			var b: Vector3 = rp[i + 1]
			_rod(k, m, Vector3(s * a.x, a.y, a.z), Vector3(s * b.x, b.y, b.z), 0.014, "steel", STAINLESS)
		for i in [0, 2, 4]:
			var a: Vector3 = rp[i]
			_rod(k, m, Vector3(s * a.x, a.y, a.z), Vector3(s * a.x, a.y - 0.38, a.z), 0.013, "steel", STAINLESS)
	var tp: Vector3 = rp[rp.size() - 1]
	_rod(k, m, tp, tp - Vector3(0, 0.36, -0.02), 0.013, "steel", STAINLESS)
	# cleats, a bow navigation light, the stern light's pole
	var bst := _station(p, 0.86)
	_cleat(k, m, Vector3(0, _top(bst) + 0.04, bst[0]))
	for s in [-1.0, 1.0]:
		for z in [zt - 0.3, 0.2]:
			var st := _station(p, _u(p, z))
			_cleat(k, m, Vector3(s * (_beam(st) - 0.035), _top(st), z), 0.0, 0.8)
	var nst := _station(p, 0.965)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.045, 0.05, 0.08), Vector3(s * 0.025, _top(nst) + 0.06, float(nst[0]) + 0.05), "paint", Color(0.55, 0.08, 0.06) if s < 0 else Color(0.08, 0.42, 0.16), Vector3.ZERO, false)
	var lst := _station(p, _u(p, zt - 0.2))
	var lx := -(_beam(lst) - 0.035)
	_rod(k, m, Vector3(lx, _top(lst), zt - 0.2), Vector3(lx, _top(lst) + 1.0, zt - 0.2), 0.014, "steel", STAINLESS)
	k._add(m, Res.sphere(0.04, 10), "plain", Color(0.9, 0.9, 0.86), Vector3(lx, _top(lst) + 1.03, zt - 0.2))
	# a non-skid sole between the topsides
	var sr := []
	for st in aft:
		var x := maxf(_hw(st[1], sole) - t - 0.012, 0.02)
		sr.append(_rz([x, sole - 0.01, x, sole + 0.01, -x, sole + 0.01, -x, sole - 0.01], st[0]))
	k._add(m, VehicleModels.solid(sr, "boat_mb_sole"), "plain", Color(0.7, 0.7, 0.68), Vector3.ZERO)
	# two fenders stowed on the sole, a VHF whip on the console
	for f in [[-0.62, 1.45, 0.25], [-0.46, 1.5, 0.0]]:
		var fz: float = f[1]
		k._add(m, Res.capsule(0.075, 0.46, 12), "plain", Color(0.86, 0.86, 0.83), Vector3(f[0], sole + 0.085, fz), Vector3(PI / 2, f[2], 0))
		for e in [-1.0, 1.0]:
			k._cyl(m, 0.045, 0.045, 0.06, Vector3(f[0], sole + 0.085, fz) + Basis(Vector3.UP, f[2]) * Vector3(0, 0, e * 0.22), Vector3(PI / 2, f[2], 0), "plain", stripe, 10, false)
	k._cyl(m, 0.025, 0.03, 0.08, Vector3(-0.39, 1.0, -0.05), Vector3.ZERO, "gunmetal_w", null, 8, false)
	_rod(k, m, Vector3(-0.39, 1.04, -0.05), Vector3(-0.42, 2.45, 0.12), 0.011, "plain", Color(0.85, 0.85, 0.82), 5)
	# the bow eye and the registration number on both bows
	k._add(m, Res.torus(0.022, 0.045), "steel", STAINLESS, Vector3(0, 0.56, _stem(p, 0.56) - 0.03), Vector3(0, 0, PI / 2))
	for s in [-1.0, 1.0]:
		for i in 7:
			if i == 2:
				continue
			var z := -1.45 - i * 0.085
			var st := _station(p, _u(p, z))
			var side: Array = st[1]
			var y := _top(st) - 0.1
			var fl := atan2(float(side[4]) - float(side[2]), float(side[5]) - float(side[3]))
			k._box(m, Vector3(0.006, 0.1, 0.055), Vector3(s * (_hw(side, y) + 0.004), y, z), "paint", stripe.darkened(0.3), Vector3(0, 0, -s * fl), false)
	# 115 hp outboard on the transom notch
	_bake(_outboard(k, m, Vector3(0, 0.71, zt + 0.04), 0.92, 0.66, "plain", Color(0.86, 0.86, 0.84), "plain", Color(0.7, 0.7, 0.69), "boat_mb_ob"))


# --- RHIB ------------------------------------------------------------------------------

## A centre-console rigid-hulled inflatable: a deep-V grey hull under a dark
## grey collar that rides up at the bow, the console with its windscreen
## under a radar arch, two rows of jockey seats, twin outboards.
static func _rhib(k: VehicleModels, team: int) -> void:
	var m := k.root
	var p := RHIB
	var hm := "plain"
	var hc := Color(0.36, 0.38, 0.4)
	var cm := "plain_dark"
	var cc := Color(0.19, 0.2, 0.21)
	var zt: float = p["z0"]
	var r := 0.28
	var all := _hull(p)
	k._add(m, _band_mesh("boat_rhib_hull", all, -9.0, 9.0, 0.0), hm, hc, Vector3.ZERO)
	k._add(m, _deck_mesh("boat_rhib_deck", _hull(p, 0.0, 0.93), 0.09, 0.012), "plain", Color(0.22, 0.23, 0.24), Vector3.ZERO)
	# spray rails along the bottom
	for s in [-1.0, 1.0]:
		var sp1 := []
		var sp2 := []
		for st in _hull(p, 0.0, 0.85):
			var side: Array = st[1]
			var kp := Vector2(side[0], side[1])
			var cp := Vector2(side[2], side[3])
			var q1 := kp.lerp(cp, 0.35)
			var q2 := kp.lerp(cp, 0.68)
			sp1.append(Vector3(s * q1.x, q1.y - 0.008, st[0]))
			sp2.append(Vector3(s * q2.x, q2.y - 0.008, st[0]))
		k._add(m, _strip("boat_rhib_sp1%d" % int(s), sp1, 0.022, 0.014), hm, hc, Vector3.ZERO)
		k._add(m, _strip("boat_rhib_sp2%d" % int(s), sp2, 0.022, 0.014), hm, hc, Vector3.ZERO)
	# the collar: runs along the sheer, kicks up at the bow, its ends past the transom
	var right := [Vector3(1.22, _sheer(p, 0.0) + 0.16, zt + 0.16)]
	for u in [0.0, 0.2, 0.4, 0.52, 0.62, 0.7, 0.77, 0.83, 0.88, 0.92, 0.955, 0.98]:
		var st := _station(p, u)
		var kick := 0.36 * pow(clampf((u - 0.45) / 0.55, 0.0, 1.0), 2.0)
		right.append(Vector3(maxf(_beam(st) + 0.14, 0.0), _top(st) + 0.16 + kick, st[0]))
	var nose := Vector3(0, _sheer(p, 1.0) + 0.16 + 0.36, zt - float(p["len"]) + 0.1)
	var path := right.duplicate()
	path.append(nose)
	for i in range(right.size() - 1, -1, -1):
		var q: Vector3 = right[i]
		path.append(Vector3(-q.x, q.y, q.z))
	_tube(k, m, path, r, cm, cc)
	var rk := right.duplicate()
	rk.append(nose)
	for s in [-1.0, 1.0]:
		var e: Vector3 = right[0]
		k._cyl(m, 0.19, r, 0.26, Vector3(s * e.x, e.y, e.z + 0.13), Vector3(PI / 2, 0, 0), cm, cc, 16)
		k._add(m, Res.sphere(0.19, 14), cm, cc, Vector3(s * e.x, e.y, e.z + 0.26))
		_tube_kit(k, m, rk, r, -1.5, cm, cc, s)
		for i in [2, 5, 8]:
			var a: Vector3 = right[i]
			var b: Vector3 = right[i + 1]
			k._cyl(m, r + 0.008, r + 0.008, 0.04, Vector3(s * a.x, a.y, a.z), _aim(Vector3(s * (b.x - a.x), b.y - a.y, b.z - a.z)), cm, cc.darkened(0.35), 16, false)
	# the centre console under its radar arch
	var cz := -0.75
	var dy := _top(_station(p, _u(p, cz)))
	k._add(m, VehicleModels.solid([_ry(_rr(0.95, 0.85, cz, 0.14, 0.05), dy - 0.03), _ry(_rr(0.95, 0.85, cz, 0.14, 0.05), dy + 0.8), _ry(_rr(0.88, 0.45, cz - 0.17, 0.12, 0.03), dy + 0.98)], "boat_rhib_console"), hm, hc, Vector3.ZERO)
	k._box(m, Vector3(0.78, 0.05, 0.12), Vector3(0, dy + 0.9, cz + 0.27), "gunmetal_w", null, Vector3(0.48, 0, 0), false)
	k._box(m, Vector3(0.3, 0.016, 0.2), Vector3(-0.15, dy + 0.9, cz + 0.2), "glass", null, Vector3(0.48, 0, 0), false)
	k._add(m, Res.torus(0.14, 0.165), "rubber", null, Vector3(0.18, dy + 0.98, cz + 0.32), Vector3(0.48, 0, 0))
	k._box(m, Vector3(0.08, 0.1, 0.16), Vector3(0.5, dy + 0.85, cz + 0.2), "gunmetal_w")
	for i in 2:
		_rod(k, m, Vector3(0.52, dy + 0.88, cz + 0.17 + i * 0.06), Vector3(0.52, dy + 1.06, cz + 0.24 + i * 0.06), 0.012, "gunmetal_w")
	k._box(m, Vector3(0.8, 0.42, 0.014), Vector3(0, dy + 1.17, cz - 0.4), "glass", Color(0.2, 0.24, 0.27), Vector3(0.42, 0, 0), false)
	_rod(k, m, Vector3(-0.42, dy + 1.4, cz - 0.31), Vector3(0.42, dy + 1.4, cz - 0.31), 0.016, "gunmetal_w")
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.014, 0.36, 0.3), Vector3(s * 0.44, dy + 1.15, cz - 0.28), "glass", Color(0.2, 0.24, 0.27), Vector3(0.0, -s * 0.28, 0), false)
		_rod(k, m, Vector3(s * 0.42, dy + 1.4, cz - 0.31), Vector3(s * 0.45, dy + 0.98, cz - 0.15), 0.016, "gunmetal_w")
		# side lights on the console's shoulders, the team panel below them
		k._box(m, Vector3(0.03, 0.06, 0.1), Vector3(s * 0.48, dy + 0.72, cz - 0.2), "paint", Color(0.55, 0.08, 0.06) if s < 0 else Color(0.08, 0.42, 0.16), Vector3.ZERO, false)
		k._team_mark(m, team, Vector3(s * 0.48, dy + 0.4, cz + 0.05), Vector3(0.012, 0.18, 0.36))
	# the arch: two legs a side up to a platform with the radar, lights, whips
	var ah := dy + 1.95
	var am := "plain"
	var ac := Color(0.5, 0.52, 0.53)
	for s in [-1.0, 1.0]:
		_rod(k, m, Vector3(s * 0.62, dy, cz - 0.55), Vector3(s * 0.5, ah, cz - 0.05), 0.035, am, ac, 8, true)
		_rod(k, m, Vector3(s * 0.62, dy, cz + 0.85), Vector3(s * 0.5, ah, cz + 0.35), 0.035, am, ac, 8, true)
		_rod(k, m, Vector3(s * 0.5, ah, cz - 0.05), Vector3(s * 0.5, ah, cz + 0.35), 0.035, am, ac, 8, true)
		_rod(k, m, Vector3(s * 0.585, dy + 0.75, cz - 0.38), Vector3(s * 0.585, dy + 0.75, cz + 0.68), 0.025, am, ac, 6, true)
		k._box(m, Vector3(0.1, 0.03, 0.12), Vector3(s * 0.62, dy + 0.015, cz - 0.55), am, ac)
		k._box(m, Vector3(0.1, 0.03, 0.12), Vector3(s * 0.62, dy + 0.015, cz + 0.85), am, ac)
		_rod(k, m, Vector3(s * 0.42, ah + 0.03, cz + 0.32), Vector3(s * 0.48, ah + 2.0, cz + 0.55), 0.01, "gunmetal_w", null, 4)
		k._cyl(m, 0.02, 0.025, 0.12, Vector3(s * 0.42, ah + 0.08, cz + 0.32), Vector3.ZERO, "plain", Color(0.85, 0.85, 0.82), 6, false)
	k._box(m, Vector3(1.06, 0.05, 0.5), Vector3(0, ah + 0.01, cz + 0.15), am, ac)
	k._cyl(m, 0.3, 0.3, 0.2, Vector3(0, ah + 0.14, cz + 0.12), Vector3.ZERO, "plain", Color(0.82, 0.82, 0.79), 18)
	k._add(m, Res.sphere(0.3, 16), "plain", Color(0.82, 0.82, 0.79), Vector3(0, ah + 0.24, cz + 0.12), Vector3.ZERO, Vector3(1, 0.25, 1))
	_rod(k, m, Vector3(0, ah + 0.03, cz + 0.36), Vector3(0, ah + 0.62, cz + 0.36), 0.018, am, ac)
	k._add(m, Res.sphere(0.04, 10), "plain", Color(0.9, 0.9, 0.86), Vector3(0, ah + 0.66, cz + 0.36))
	k._cyl(m, 0.075, 0.09, 0.14, Vector3(0.36, ah + 0.13, cz - 0.08), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k._cyl(m, 0.06, 0.06, 0.01, Vector3(0.36, ah + 0.13, cz - 0.155), Vector3(PI / 2, 0, 0), "glass", null, 10, false)
	k._box(m, Vector3(0.12, 0.06, 0.04), Vector3(-0.32, ah + 0.07, cz - 0.05), "gunmetal_w")
	# two rows of jockey seats, each with a grab bar
	for zr in [cz + 1.3, cz + 2.15]:
		var sy := _top(_station(p, _u(p, zr)))
		for s in [-1.0, 1.0]:
			var x: float = s * 0.38
			k._box(m, Vector3(0.34, 0.5, 0.5), Vector3(x, sy + 0.24, zr), hm, hc)
			k._box(m, Vector3(0.36, 0.12, 0.6), Vector3(x, sy + 0.55, zr + 0.02), "plain_dark", Color(0.12, 0.12, 0.12))
			k._box(m, Vector3(0.34, 0.2, 0.1), Vector3(x, sy + 0.68, zr + 0.3), "plain_dark", Color(0.12, 0.12, 0.12), Vector3(0.2, 0, 0))
			for dx in [-0.13, 0.13]:
				_rod(k, m, Vector3(x + dx, sy + 0.58, zr - 0.25), Vector3(x + dx, sy + 0.84, zr - 0.31), 0.015, "steel", STAINLESS)
			_rod(k, m, Vector3(x - 0.13, sy + 0.84, zr - 0.31), Vector3(x + 0.13, sy + 0.84, zr - 0.31), 0.015, "steel", STAINLESS)
	# a seat box forward of the console, the stern locker
	var by := _top(_station(p, _u(p, -1.8)))
	k._box(m, Vector3(1.0, 0.44, 0.62), Vector3(0, by + 0.2, -1.8), hm, hc)
	k._box(m, Vector3(0.96, 0.09, 0.58), Vector3(0, by + 0.46, -1.8), "plain_dark", Color(0.12, 0.12, 0.12))
	var sy2 := _top(_station(p, _u(p, 2.95)))
	k._box(m, Vector3(1.3, 0.4, 0.75), Vector3(0, sy2 + 0.18, 2.95), hm, hc.darkened(0.25))
	k._box(m, Vector3(1.0, 0.03, 0.5), Vector3(0, sy2 + 0.395, 2.95), hm, hc.darkened(0.4))
	# bow: an anchor locker hatch, a cleat and the towing eye on the stem
	var hst := _station(p, 0.86)
	k._box(m, Vector3(0.5, 0.03, 0.42), Vector3(0, _top(hst) + 0.01, float(hst[0]) + 0.1), hm, hc.darkened(0.1))
	var cst := _station(p, 0.93)
	_cleat(k, m, Vector3(0, _top(cst), cst[0]))
	for s in [-1.0, 1.0]:
		_cleat(k, m, Vector3(s * 0.8, _sheer(p, 0.02), zt - 0.2), 0.0, 1.2)
	k._add(m, Res.torus(0.025, 0.05), "steel", STAINLESS, Vector3(0, 0.62, _stem(p, 0.62) - 0.04), Vector3(0, 0, PI / 2))
	# twin outboards and the tie bar between them
	for s in [-1.0, 1.0]:
		_bake(_outboard(k, m, Vector3(s * 0.46, _sheer(p, 0.0) + 0.02, zt + 0.04), 1.15, 0.78, "plain_dark", Color(0.12, 0.12, 0.125), "plain_dark", Color(0.1, 0.1, 0.105), "boat_rhib_ob"))
	_rod(k, m, Vector3(-0.46, 0.9, zt + 0.02), Vector3(0.46, 0.9, zt + 0.02), 0.018, "gunmetal_w")


# --- SDV --------------------------------------------------------------------------------

## SEAL Delivery Vehicle Mk 8 Mod 1: a free-flooding torpedo of a hull with a
## squarish section, four canopy hatches over the crew compartment, a mast
## with the periscope, a ducted propeller with cruciform control fins aft,
## and skids under it to sit on.
static func _sdv(k: VehicleModels, team: int) -> void:
	var m := k.root
	var bm := "plain_dark"
	var bc := Color(0.1, 0.1, 0.105)
	var yc := 0.78
	var secs := [[-3.35, 0.06, 0.05, 2.0], [-3.31, 0.26, 0.23, 2.2], [-3.2, 0.43, 0.37, 2.5], [-3.02, 0.57, 0.48, 2.9],
		[-2.78, 0.67, 0.56, 3.0], [-2.48, 0.73, 0.6, 3.2], [-2.15, 0.75, 0.62, 3.3], [1.3, 0.75, 0.62, 3.3],
		[1.75, 0.71, 0.59, 3.1], [2.15, 0.61, 0.51, 2.8], [2.5, 0.46, 0.4, 2.5], [2.8, 0.31, 0.28, 2.3], [3.02, 0.18, 0.17, 2.0]]
	var rings := []
	for q in secs:
		rings.append(_sring(q[1], q[2], yc, q[0], q[3], 24))
	k._add(m, VehicleModels.solid(rings, "boat_sdv_hull"), bm, bc, Vector3.ZERO)
	# the raised hatch deck over the crew compartment, and its four hatches
	var hd := _rr(1.22, 2.9, -0.5, 0.18, 0.12)
	k._add(m, VehicleModels.solid([_ry(hd, 1.3), _ry(_rr(1.18, 2.86, -0.5, 0.17, 0.11), 1.44)], "boat_sdv_deck"), bm, bc.lightened(0.04), Vector3.ZERO)
	# forward: the pilot's and navigator's canopy, split down the middle, with
	# viewports in its sloped front and sides
	var cb := _rr(1.08, 1.22, -1.33, 0.22, 0.08)
	var ct := _rr(0.84, 0.84, -1.24, 0.16, 0.06)
	k._add(m, VehicleModels.solid([_ry(cb, 1.43), _ry(ct, 1.62)], "boat_sdv_canopy"), bm, bc.lightened(0.08), Vector3.ZERO)
	var cin := Vector3(0, 1.45, -1.3)
	for tt in [[0.08, 0.44], [0.56, 0.92]]:
		_panel(k, m, _pt(cb, 0, 1.43).lerp(_pt(cb, 1, 1.43), tt[0]), _pt(cb, 0, 1.43).lerp(_pt(cb, 1, 1.43), tt[1]),
			_pt(ct, 0, 1.62).lerp(_pt(ct, 1, 1.62), tt[1]), _pt(ct, 0, 1.62).lerp(_pt(ct, 1, 1.62), tt[0]), cin, 0.03, 0.012, "glass", null, 0.0)
	for f in [[2, 3], [7, 6]]:
		_panel(k, m, _pt(cb, f[0], 1.43).lerp(_pt(cb, f[1], 1.43), 0.08), _pt(cb, f[0], 1.43).lerp(_pt(cb, f[1], 1.43), 0.45),
			_pt(ct, f[0], 1.62).lerp(_pt(ct, f[1], 1.62), 0.45), _pt(ct, f[0], 1.62).lerp(_pt(ct, f[1], 1.62), 0.08), cin, 0.03, 0.012, "glass", null, 0.0)
	_rod(k, m, Vector3(0, 1.625, -1.64), Vector3(0, 1.625, -0.84), 0.016, "gunmetal_w")
	for s in [-1.0, 1.0]:
		_rod(k, m, Vector3(s * 0.55, 1.45, -1.8), Vector3(s * 0.55, 1.45, -0.8), 0.018, "gunmetal_w")
		k._box(m, Vector3(0.03, 0.04, 0.12), Vector3(s * 0.3, 1.64, -1.0), "gunmetal_w", null, Vector3.ZERO, false)
	# aft: the passengers' two flat hatches
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.52, 0.04, 1.18), Vector3(s * 0.29, 1.455, 0.33), bm, bc.lightened(0.08))
		k._box(m, Vector3(0.22, 0.012, 0.28), Vector3(s * 0.29, 1.478, 0.08), "glass", null, Vector3.ZERO, false)
		_rod(k, m, Vector3(s * 0.56, 1.46, -0.17), Vector3(s * 0.56, 1.46, 0.83), 0.018, "gunmetal_w")
		k._box(m, Vector3(0.12, 0.03, 0.04), Vector3(s * 0.12, 1.49, 0.68), "gunmetal_w", null, Vector3.ZERO, false)
	_rod(k, m, Vector3(0, 1.45, -0.6), Vector3(0, 1.45, 0.95), 0.02, "gunmetal_w")
	# lifting eyes at the deck's corners
	for s in [-1.0, 1.0]:
		for z in [-2.05, 1.05]:
			k._add(m, Res.torus(0.025, 0.05), "gunmetal_w", null, Vector3(s * 0.48, 1.42, z), Vector3(0, PI / 2, 0))
	# the mast with the periscope head and a comms antenna beside it
	k._add(m, VehicleModels.solid([_ry(_foil(0.22, 0.5, -2.55), 1.32), _ry(_foil(0.16, 0.36, -2.47), 1.62)], "boat_sdv_mast"), bm, bc, Vector3.ZERO)
	k._cyl(m, 0.04, 0.04, 0.5, Vector3(0, 1.85, -2.38), Vector3.ZERO, "gunmetal_w", null, 10)
	k._box(m, Vector3(0.09, 0.13, 0.14), Vector3(0, 2.15, -2.39), "gunmetal_w")
	k._box(m, Vector3(0.06, 0.06, 0.012), Vector3(0, 2.17, -2.465), "glass", null, Vector3.ZERO, false)
	_rod(k, m, Vector3(0.0, 1.62, -2.18), Vector3(0.0, 2.02, -2.12), 0.012, "gunmetal_w")
	k._cyl(m, 0.03, 0.03, 0.05, Vector3(0.0, 2.04, -2.12), Vector3.ZERO, "gunmetal_w", null, 8, false)
	# nose: the sonar window and two lamps
	k._add(m, Res.sphere(0.5, 16), "glass", null, Vector3(0, yc - 0.08, -3.22), Vector3.ZERO, Vector3(0.62, 0.42, 0.24))
	for s in [-1.0, 1.0]:
		k._cyl(m, 0.06, 0.06, 0.1, Vector3(s * 0.36, yc + 0.28, -3.0), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
		k._cyl(m, 0.045, 0.045, 0.01, Vector3(s * 0.36, yc + 0.28, -3.055), Vector3(PI / 2, 0, 0), "glass", null, 10, false)
	# the free-flooding hull's vent grilles and panel seams down each side
	for s in [-1.0, 1.0]:
		for zc in [-1.5, -0.4, 0.7]:
			k._box(m, Vector3(0.012, 0.2, 0.6), Vector3(s * 0.752, yc - 0.12, zc), "plain_dark", Color(0.05, 0.05, 0.05), Vector3.ZERO, false)
			for i in 4:
				k._box(m, Vector3(0.016, 0.018, 0.56), Vector3(s * 0.755, yc - 0.2 + i * 0.055, zc), bm, bc.lightened(0.05), Vector3.ZERO, false)
		k._box(m, Vector3(0.01, 0.012, 3.4), Vector3(s * 0.752, yc + 0.22, -0.4), "gunmetal_w", null, Vector3.ZERO, false)
		for z in [-2.05, 1.2]:
			k._box(m, Vector3(0.01, 0.5, 0.012), Vector3(s * 0.752, yc, z), "gunmetal_w", null, Vector3.ZERO, false)
		# the skids it rests on
		k._add(m, VehicleModels.extrude_x("boat_sdv_skid", [-2.5, 0.26, -2.2, 0.0, 1.7, 0.0, 1.95, 0.26], -0.045, 0.045), "metal_dark", null, Vector3(s * 0.42, 0, 0))
	# tail: the cone's end, cruciform fins and the duct round the propeller
	k._cyl(m, 0.04, 0.17, 0.2, Vector3(0, yc, 3.12), Vector3(PI / 2, 0, 0), bm, bc, 12)
	var fin := [2.2, 0.3, 3.05, 0.13, 3.28, 0.66, 2.86, 0.7]
	for s in [-1.0, 1.0]:
		var vf := []
		for i in range(0, fin.size(), 2):
			vf.append_array([fin[i], s * float(fin[i + 1])])
		k._add(m, VehicleModels.extrude_x("boat_sdv_vfin%d" % int(s), vf, -0.028, 0.028), bm, bc, Vector3(0, yc, 0))
		var hf := []
		for i in range(0, fin.size(), 2):
			hf.append_array([s * float(fin[i + 1]), fin[i]])
		k._add(m, VehicleModels.loft("boat_sdv_hfin%d" % int(s), hf, hf, -0.028, 0.028), bm, bc, Vector3(0, yc, 0))
	k._add(m, Res.torus(0.53, 0.61), bm, bc, Vector3(0, yc, 3.1), Vector3(PI / 2, 0, 0), Vector3(1.0, 4.6, 1.0))
	_prop(k, m, Vector3(0, yc, 2.98), 0.48, 5, "metal_dark")
	k._team_mark(m, team, Vector3(0.62, 1.37, -0.5), Vector3(0.012, 0.08, 0.5))


# --- SURC speedboat ------------------------------------------------------------------

## The Speedboat: a futuristic Small Unit Riverine Craft. A long hard-chined
## hull with a knuckle and tumblehome sides, an armoured cabin amidships with
## slanted glass, a remote weapon station with a 40 mm GMG on the bow, an open
## troop deck aft with a ring-mounted gun (a minigun, or a 12.7 mm HMG on the
## CSAT boat), waterjets at the transom.
static func _surc(k: VehicleModels, team: int, csat: bool) -> void:
	var m := k.root
	var p := SURC
	var hm := "camo_tank_rebel" if csat else "plain"
	var hc = null if csat else Color(0.4, 0.42, 0.43)
	var dc := Color(0.33, 0.3, 0.23) if csat else Color(0.27, 0.28, 0.29)
	var zt: float = p["z0"]
	var all := _hull(p)
	k._add(m, _band_mesh("boat_surc_hull", all, -9.0, 9.0, 0.0), hm, hc, Vector3.ZERO)
	# the fendering strake along the knuckle, spray rails on the bottom
	for s in [-1.0, 1.0]:
		var kn := []
		var sp1 := []
		var sp2 := []
		for st in all:
			var side: Array = st[1]
			var z: float = st[0]
			if float(side[4]) > 0.05:
				kn.append(Vector3(s * (float(side[4]) + 0.03), side[5], z))
			if z > -4.4:
				var kp := Vector2(side[0], side[1])
				var cp := Vector2(side[2], side[3])
				var q1 := kp.lerp(cp, 0.36)
				var q2 := kp.lerp(cp, 0.7)
				sp1.append(Vector3(s * q1.x, q1.y - 0.01, z))
				sp2.append(Vector3(s * q2.x, q2.y - 0.01, z))
		k._add(m, _strip("boat_surc_fender%d" % int(s), kn, 0.045, 0.07), "rubber", Color(0.11, 0.11, 0.11), Vector3.ZERO)
		k._add(m, _strip("boat_surc_sp1%d" % int(s), sp1, 0.03, 0.018), hm, hc, Vector3.ZERO)
		k._add(m, _strip("boat_surc_sp2%d" % int(s), sp2, 0.03, 0.018), hm, hc, Vector3.ZERO)
	# non-skid decks: the open troop deck aft and the foredeck
	var uc := _u(p, 1.2)
	k._add(m, _deck_mesh("boat_surc_deck_a", _hull(p, 0.005, uc), 0.17, 0.012), "plain", dc, Vector3.ZERO)
	k._add(m, _deck_mesh("boat_surc_deck_f", _hull(p, _u(p, -2.3), 0.9), 0.14, 0.012), "plain", dc, Vector3.ZERO)
	# armoured bulwarks round the troop deck, capped
	var aft := _hull(p, 0.0, uc)
	for s in [-1.0, 1.0]:
		var wr := []
		var cap := []
		for st in aft:
			var ys := _top(st)
			var x := _beam(st)
			wr.append(_rz([s * x, ys - 0.03, s * (x - 0.09), ys + 0.6, s * (x - 0.16), ys + 0.6, s * (x - 0.07), ys - 0.03], st[0]))
			cap.append(Vector3(s * (x - 0.125), ys + 0.61, st[0]))
		k._add(m, VehicleModels.solid(wr, "boat_surc_bulwark%d" % int(s)), hm, hc, Vector3.ZERO)
		k._add(m, _strip("boat_surc_cap%d" % int(s), cap, 0.06, 0.015), "gunmetal_w", null, Vector3.ZERO)
	# the bulwarks' ballistic panels: seams down their sloped faces
	for s in [-1.0, 1.0]:
		for z in [1.75, 2.85, 3.95, 5.05]:
			var st := _station(p, _u(p, z))
			k._box(m, Vector3(0.012, 0.58, 0.025), Vector3(s * (_beam(st) - 0.04), _top(st) + 0.29, z), "gunmetal_w", null, Vector3(0, 0, s * 0.148), false)
	# the transom's bulwark, with a gate in the middle
	var ys0 := _sheer(p, 0.0)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.95, 0.6, 0.07), Vector3(s * 0.85, ys0 + 0.28, zt - 0.05), hm, hc)
	# the cabin: near-vertical armoured walls, a band of steeply slanted glass
	var base := [-1.22, 1.2, 1.22, 1.2, 1.12, -1.6, 0.6, -2.5, -0.6, -2.5, -1.12, -1.6]
	var sill := [-1.19, 1.16, 1.19, 1.16, 1.09, -1.52, 0.57, -2.38, -0.57, -2.38, -1.09, -1.52]
	var roof := [-0.96, 0.95, 0.96, 0.95, 0.9, -0.78, 0.42, -1.32, -0.42, -1.32, -0.9, -0.78]
	var y0 := 1.25
	var y1 := 2.0
	var y2 := 2.66
	k._add(m, VehicleModels.solid([_ry(base, y0), _ry(sill, y1), _ry(roof, y2)], "boat_surc_cab"), hm, hc, Vector3.ZERO)
	k._add(m, VehicleModels.solid([_ry(_scale_xz(sill, 1.012, -0.4), y1 - 0.035), _ry(_scale_xz(sill, 1.012, -0.4), y1 + 0.01)], "boat_surc_sill"), "gunmetal_w", null, Vector3.ZERO)
	var inside := Vector3(0, 1.9, -0.5)
	for f in [[2, 3], [3, 4], [4, 5]]:
		_panel(k, m, _pt(sill, f[0], y1), _pt(sill, f[1], y1), _pt(roof, f[1], y2), _pt(roof, f[0], y2), inside, 0.13, 0.03, "glass", null, 0.0)
	for f in [[1, 2], [5, 0]]:
		for tt in [[0.06, 0.46], [0.52, 0.94]]:
			var a0 := _pt(sill, f[0], y1).lerp(_pt(sill, f[1], y1), tt[0])
			var a1 := _pt(sill, f[0], y1).lerp(_pt(sill, f[1], y1), tt[1])
			var b1 := _pt(roof, f[0], y2).lerp(_pt(roof, f[1], y2), tt[1])
			var b0 := _pt(roof, f[0], y2).lerp(_pt(roof, f[1], y2), tt[0])
			_panel(k, m, a0, a1, b1, b0, inside, 0.11, 0.03, "glass", null, 0.0)
	# the rear: a door below, a window above it
	_panel(k, m, _pt(base, 0, y0 + 0.08).lerp(_pt(base, 1, y0 + 0.08), 0.35), _pt(base, 0, y0 + 0.08).lerp(_pt(base, 1, y0 + 0.08), 0.65),
		_pt(sill, 0, y1).lerp(_pt(sill, 1, y1), 0.65), _pt(sill, 0, y1).lerp(_pt(sill, 1, y1), 0.35), inside, 0.02, 0.04, hm, hc, 0.01)
	_panel(k, m, _pt(sill, 0, y1).lerp(_pt(sill, 1, y1), 0.3), _pt(sill, 0, y1).lerp(_pt(sill, 1, y1), 0.7),
		_pt(roof, 0, y2).lerp(_pt(roof, 1, y2), 0.7), _pt(roof, 0, y2).lerp(_pt(roof, 1, y2), 0.3), inside, 0.12, 0.03, "glass", null, 0.0)
	k._box(m, Vector3(0.04, 0.12, 0.04), Vector3(0.28, 1.65, 1.21), "gunmetal_w", null, Vector3.ZERO, false)
	# wipers on the windscreen, armour seams on the lower walls
	for s in [-1.0, 1.0]:
		_rod(k, m, Vector3(s * 0.2, 2.06, -2.34), Vector3(s * 0.12, 2.42, -1.78), 0.01, "gunmetal_w", null, 4)
		for z in [-0.9, 0.2]:
			k._box(m, Vector3(0.012, 0.7, 0.02), Vector3(s * 1.205, 1.62, z), "gunmetal_w", null, Vector3(0, 0, s * 0.04), false)
		# side lights on the cabin's shoulders, the team panel aft of them
		k._box(m, Vector3(0.05, 0.08, 0.14), Vector3(s * 1.13, 1.9, -1.45), "paint", Color(0.55, 0.08, 0.06) if s < 0 else Color(0.08, 0.42, 0.16), Vector3.ZERO, false)
		k._team_mark(m, team, Vector3(s * 1.21, 1.62, 0.75), Vector3(0.012, 0.24, 0.5))
	# the roof: a raked mast with the radar, a satcom dome, whips, searchlight,
	# smoke dischargers at the front corners, grab rails
	k._add(m, VehicleModels.loft("boat_surc_mast", [-0.28, -0.3, 0.28, -0.3, 0.28, 0.72, -0.28, 0.72], [-0.15, 0.28, 0.15, 0.28, 0.15, 0.66, -0.15, 0.66], y2 - 0.02, y2 + 0.72), hm, hc, Vector3.ZERO)
	k._cyl(m, 0.07, 0.08, 0.12, Vector3(0, y2 + 0.78, 0.48), Vector3.ZERO, "gunmetal_w", null, 10)
	k._box(m, Vector3(1.3, 0.12, 0.16), Vector3(0, y2 + 0.88, 0.48), "plain", Color(0.75, 0.76, 0.75))
	_rod(k, m, Vector3(0, y2 + 0.7, 0.34), Vector3(0, y2 + 1.25, 0.34), 0.015, "gunmetal_w")
	k._add(m, Res.sphere(0.04, 10), "plain", Color(0.9, 0.9, 0.86), Vector3(0, y2 + 1.28, 0.34))
	k._add(m, Res.sphere(0.22, 14), "plain", Color(0.72, 0.73, 0.72) if not csat else Color(0.55, 0.52, 0.44), Vector3(0.55, y2 + 0.04, 0.55), Vector3.ZERO, Vector3(1, 0.85, 1))
	for s in [-1.0, 1.0]:
		_rod(k, m, Vector3(s * 0.82, y2, 0.82), Vector3(s * 0.88, y2 + 2.6, 1.35), 0.012, "gunmetal_w", null, 4)
		k._cyl(m, 0.035, 0.04, 0.12, Vector3(s * 0.82, y2 + 0.06, 0.82), Vector3.ZERO, "gunmetal_w", null, 8, false)
		_rod(k, m, Vector3(s * 0.78, y2 + 0.12, -0.55), Vector3(s * 0.78, y2 + 0.12, 0.7), 0.016, "gunmetal_w")
		for z in [-0.5, 0.65]:
			_rod(k, m, Vector3(s * 0.78, y2, z), Vector3(s * 0.78, y2 + 0.12, z), 0.014, "gunmetal_w")
		for i in 3:
			_rod(k, m, Vector3(s * (0.7 + i * 0.07), y2 + 0.05, -0.62 + i * 0.04), Vector3(s * (0.78 + i * 0.07), y2 + 0.24, -0.82 + i * 0.04), 0.04, "gunmetal_w", null, 8, true)
	k._cyl(m, 0.1, 0.11, 0.16, Vector3(-0.45, y2 + 0.1, -0.6), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k._cyl(m, 0.085, 0.085, 0.01, Vector3(-0.45, y2 + 0.1, -0.685), Vector3(PI / 2, 0, 0), "glass", null, 10, false)
	k._box(m, Vector3(0.5, 0.06, 0.45), Vector3(0, y2 + 0.02, -0.25), hm, hc)
	# side-deck handrails along the cabin
	for s in [-1.0, 1.0]:
		var rp := []
		for z in [-2.0, -0.9, 0.2, 1.15]:
			var st := _station(p, _u(p, z))
			rp.append(Vector3(s * (_beam(st) - 0.05), _top(st), z))
		for i in rp.size():
			var a: Vector3 = rp[i]
			_rod(k, m, a, a + Vector3(0, 0.55, 0), 0.016, "gunmetal_w")
			if i > 0:
				_rod(k, m, (rp[i - 1] as Vector3) + Vector3(0, 0.55, 0), a + Vector3(0, 0.55, 0), 0.018, "gunmetal_w")
	# the troop deck: benches with backrests along both bulwarks
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.46, 0.4, 3.5), Vector3(s * 1.02, 1.52, 3.45), hm, hc)
		for i in 4:
			var z := 1.95 + i * 0.95
			k._box(m, Vector3(0.44, 0.08, 0.86), Vector3(s * 1.02, 1.76, z), "plain_dark", Color(0.14, 0.14, 0.13))
			k._box(m, Vector3(0.08, 0.38, 0.86), Vector3(s * 1.22, 2.02, z), "plain_dark", Color(0.14, 0.14, 0.13), Vector3(0, 0, -s * 0.14))
	# the rear gun on its pedestal ring mount, looking aft over the quarter
	var gy := _sheer(p, _u(p, 3.65))
	k._cyl(m, 0.13, 0.17, 0.75, Vector3(0, gy + 0.37, 3.65), Vector3.ZERO, hm, hc, 12)
	k._cyl(m, 0.24, 0.24, 0.08, Vector3(0, gy + 0.78, 3.65), Vector3.ZERO, "gunmetal_w", null, 16)
	var rg := k._pivot(m, Vector3(0, gy + 0.82, 3.65))
	rg.rotation.y = PI - 0.55
	k._box(rg, Vector3(0.14, 0.3, 0.2), Vector3(0, 0.15, 0.0), "gunmetal_w")
	k._box(rg, Vector3(0.9, 0.5, 0.05), Vector3(0, 0.42, -0.5), hm, hc, Vector3(-0.12, 0, 0))
	for sx in [-1.0, 1.0]:
		k._box(rg, Vector3(0.05, 0.42, 0.3), Vector3(sx * 0.46, 0.4, -0.38), hm, hc, Vector3(-0.12, sx * 0.5, 0))
	k._box(rg, Vector3(0.24, 0.1, 0.02), Vector3(0, 0.56, -0.535), "glass", null, Vector3(-0.12, 0, 0), false)
	if csat:
		# 12.7 mm HMG: a long receiver, a heavy barrel with its muzzle brake
		k._box(rg, Vector3(0.12, 0.15, 0.7), Vector3(0, 0.36, -0.12), "gunmetal_w")
		k._cyl(rg, 0.022, 0.026, 0.95, Vector3(0, 0.37, -0.92), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
		k._cyl(rg, 0.038, 0.038, 0.12, Vector3(0, 0.37, -1.42), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
		k._box(rg, Vector3(0.03, 0.08, 0.2), Vector3(0, 0.47, -0.2), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(rg, Vector3(0.14, 0.17, 0.26), Vector3(-0.15, 0.32, -0.08), "paint", Color(0.3, 0.32, 0.22))
	else:
		# M134 minigun: six barrels in a clamp, the motor housing, the feed chute
		k._box(rg, Vector3(0.16, 0.17, 0.42), Vector3(0, 0.36, -0.05), "gunmetal_w")
		for i in 6:
			var a := TAU * i / 6.0
			k._cyl(rg, 0.012, 0.012, 0.62, Vector3(cos(a) * 0.035, 0.37 + sin(a) * 0.035, -0.55), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 5, false)
		k._cyl(rg, 0.055, 0.055, 0.04, Vector3(0, 0.37, -0.72), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
		k._cyl(rg, 0.05, 0.05, 0.08, Vector3(0, 0.37, -0.3), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
		_rod(k, rg, Vector3(-0.08, 0.38, -0.05), Vector3(-0.3, 0.22, 0.1), 0.03, "gunmetal_w", null, 6)
		k._box(rg, Vector3(0.22, 0.24, 0.3), Vector3(-0.36, 0.14, 0.12), "paint", Color(0.3, 0.32, 0.22))
	for sx in [-1.0, 1.0]:
		_rod(k, rg, Vector3(sx * 0.07, 0.36, 0.2), Vector3(sx * 0.07, 0.48, 0.3), 0.016, "rubber")
	# bow remote weapon station: 40 mm GMG, sight on the right, ammo on the left
	var bu := _u(p, -4.1)
	var bdy := _sheer(p, bu)
	k._add(m, VehicleModels.loft("boat_surc_rws_base", _rr(0.82, 0.82, 0.0, 0.18, 0.18), _rr(0.7, 0.7, 0.0, 0.15, 0.15), -0.25, 0.22), hm, hc, Vector3(0, bdy, -4.1))
	k.turret = k._pivot(m, Vector3(0, bdy + 0.22, -4.1))
	var tu := k.turret
	k._cyl(tu, 0.34, 0.36, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, "gunmetal_w", null, 16)
	k._add(tu, VehicleModels.loft("boat_surc_rws", [-0.34, -0.2, 0.34, -0.2, 0.34, 0.32, -0.34, 0.32], [-0.3, -0.08, 0.3, -0.08, 0.3, 0.28, -0.3, 0.28], 0.1, 0.36), hm, hc, Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		k._box(tu, Vector3(0.06, 0.34, 0.42), Vector3(sx * 0.22, 0.5, 0.0), hm, hc)
	k._cyl(tu, 0.05, 0.05, 0.5, Vector3(0, 0.52, 0.0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10, false)
	k._box(tu, Vector3(0.2, 0.22, 0.72), Vector3(0, 0.55, -0.08), "gunmetal_w")
	k._cyl(tu, 0.045, 0.045, 0.6, Vector3(0, 0.55, -0.72), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k._cyl(tu, 0.068, 0.068, 0.34, Vector3(0, 0.55, -0.6), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	k._cyl(tu, 0.055, 0.05, 0.08, Vector3(0, 0.55, -1.04), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
	k.mg_tip = k._tip(tu, Vector3(0, 0.55, -1.1))
	k._box(tu, Vector3(0.2, 0.24, 0.34), Vector3(0.38, 0.56, -0.08), hm, hc)
	for gy2 in [0.6, 0.5]:
		k._box(tu, Vector3(0.08, 0.06, 0.012), Vector3(0.38, gy2, -0.255), "glass", null, Vector3.ZERO, false)
	k._box(tu, Vector3(0.24, 0.3, 0.4), Vector3(-0.4, 0.52, 0.0), "paint", Color(0.3, 0.32, 0.22))
	_rod(k, tu, Vector3(-0.28, 0.6, -0.05), Vector3(-0.1, 0.58, -0.05), 0.04, "gunmetal_w", null, 6)
	# foredeck: twin bitts, a cleat each side, the towing eye on the stem
	var fst := _station(p, 0.9)
	for dx in [-0.12, 0.12]:
		k._cyl(m, 0.06, 0.06, 0.24, Vector3(dx, _top(fst) + 0.12, float(fst[0])), Vector3.ZERO, "gunmetal_w", null, 10)
	k._box(m, Vector3(0.4, 0.04, 0.16), Vector3(0, _top(fst) + 0.02, float(fst[0])), "gunmetal_w")
	k._add(m, Res.torus(0.04, 0.075), "gunmetal_w", null, Vector3(0, 1.05, zt - float(p["len"]) * 0.905), Vector3(0, 0, PI / 2))
	for s in [-1.0, 1.0]:
		var cst := _station(p, 0.78)
		_cleat(k, m, Vector3(s * (_beam(cst) - 0.15), _top(cst), cst[0]), 0.0, 1.3)
		_cleat(k, m, Vector3(s * 1.15, ys0 + 0.6, zt - 0.3), 0.0, 1.3)
	# transom: twin waterjets with their steering nozzles and raised reversing
	# buckets, tucked under a stern step; the stern light
	k._add(m, VehicleModels.loft("boat_surc_step", [-1.25, zt - 0.02, 1.25, zt - 0.02, 1.15, zt + 0.5, -1.15, zt + 0.5], [-1.3, zt - 0.02, 1.3, zt - 0.02, 1.2, zt + 0.55, -1.2, zt + 0.55], 0.78, 0.96), hm, hc, Vector3.ZERO)
	k._box(m, Vector3(2.2, 0.012, 0.45), Vector3(0, 0.966, zt + 0.27), "plain", dc)
	for s in [-1.0, 1.0]:
		var x: float = s * 0.72
		k._cyl(m, 0.17, 0.21, 0.36, Vector3(x, 0.5, zt + 0.18), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 14)
		k._cyl(m, 0.13, 0.16, 0.18, Vector3(x, 0.5, zt + 0.44), Vector3(PI / 2, 0, 0), "metal_dark", null, 14)
		k._box(m, Vector3(0.36, 0.26, 0.04), Vector3(x, 0.66, zt + 0.6), "gunmetal_w", null, Vector3(-0.3, 0, 0))
		for dx in [-0.19, 0.19]:
			k._box(m, Vector3(0.035, 0.05, 0.36), Vector3(x + dx, 0.66, zt + 0.42), "gunmetal_w", null, Vector3(0.15, 0, 0), false)
		_rod(k, m, Vector3(x + s * 0.24, 0.74, zt + 0.06), Vector3(x + s * 0.19, 0.58, zt + 0.4), 0.022, "steel", null, 6)
	k._add(m, Res.torus(0.035, 0.065), "gunmetal_w", null, Vector3(0, 0.66, zt + 0.02), Vector3(PI / 2, 0, 0))
	_rod(k, m, Vector3(1.1, ys0 + 0.6, zt - 0.1), Vector3(1.1, ys0 + 1.2, zt - 0.1), 0.014, "gunmetal_w")
	k._add(m, Res.sphere(0.035, 8), "plain", Color(0.9, 0.9, 0.86), Vector3(1.1, ys0 + 1.22, zt - 0.1))


## A flat outline [x, z, ...] scaled about (0, zc).
static func _scale_xz(xz: Array, f: float, zc: float) -> Array:
	var out := []
	for i in range(0, xz.size(), 2):
		out.append_array([float(xz[i]) * f, zc + (float(xz[i + 1]) - zc) * f])
	return out


# --- water scooter -------------------------------------------------------------------

## A three-seat jet ski: a white V-hull with a bumper strake, the coloured
## deck with its rounded hood, the handlebar pod with mirrors and a smoked
## visor, a long stepped saddle between two footwells, the boarding platform,
## grab handle and the jet nozzle at the stern.
static func _scooter(k: VehicleModels, seed: int) -> void:
	var m := k.root
	var p := SCOOTER
	var liv: Color = [Color(0.58, 0.17, 0.13), Color(0.15, 0.38, 0.42), Color(0.17, 0.27, 0.46), Color(0.85, 0.47, 0.1)][seed % 4]
	var hm := "plain"
	var white := Color(0.84, 0.84, 0.82)
	var dark := Color(0.13, 0.13, 0.14)
	var all := _hull(p)
	k._add(m, _band_mesh("boat_pwc_hull", all, -9.0, 9.0, 0.0), hm, white, Vector3.ZERO)
	# the bumper strake round the sheer and a livery band along each side
	for s in [-1.0, 1.0]:
		var rail := []
		var band := []
		for st in all:
			rail.append(Vector3(s * (_beam(st) + 0.01), _top(st) - 0.015, st[0]))
			band.append(_skin(st, _top(st) - 0.12, _top(st) - 0.075, 0.004, 0.02, s))
		k._add(m, _strip("boat_pwc_rail%d" % int(s), rail, 0.018, 0.022), "plain_dark", dark, Vector3.ZERO)
		k._add(m, VehicleModels.solid(band, "boat_pwc_band%d" % int(s)), hm, liv, Vector3.ZERO)
		# low gunwale lips round the footwells
		var lip := []
		for st in _hull(p, _u(p, 1.2), _u(p, -0.45)):
			var ys := _top(st)
			var x := _beam(st)
			lip.append(_rz([s * (x + 0.002), ys - 0.01, s * (x - 0.01), ys + 0.05, s * (x - 0.05), ys + 0.05, s * (x - 0.05), ys - 0.01], st[0]))
		k._add(m, VehicleModels.solid(lip, "boat_pwc_lip%d" % int(s)), "plain_dark", Color(0.2, 0.2, 0.21), Vector3.ZERO)
		# sponsons near the stern
		var sst := _station(p, 0.12)
		var side: Array = sst[1]
		k._box(m, Vector3(0.035, 0.045, 0.4), Vector3(s * (float(side[2]) + 0.018), float(side[3]) + 0.03, float(sst[0])), "plain_dark", dark)
	# the hood: a rounded dome rising from the bow to the handlebar pod
	var hood := []
	for zq in [[-0.42, 0.9], [-0.55, 0.92], [-0.75, 0.905], [-0.98, 0.85], [-1.2, 0.775], [-1.38, 0.705], [-1.52, 0.645], [-1.62, 0.6], [-1.67, 0.572], [-1.695, 0.555]]:
		var st := _station(p, _u(p, zq[0]))
		var by := _top(st) - 0.01
		var hw := _beam(st) + 0.012 - 0.05 * clampf((float(zq[0]) + 1.6) / 0.6, 0.0, 1.0)
		hood.append(_dome(hw, by, maxf(float(zq[1]) - by, 0.01), st[0], 2.2, 14))
	k._add(m, VehicleModels.solid(hood, "boat_pwc_hood"), hm, liv, Vector3.ZERO)
	# the pedestal and the stepped three-place saddle on it
	var ped := []
	for q in [[-0.5, 0.26, 0.66], [-0.2, 0.27, 0.68], [0.6, 0.27, 0.68], [0.98, 0.24, 0.64], [1.1, 0.18, 0.56]]:
		var w: float = q[1]
		ped.append(_rz([w, 0.36, w + 0.01, 0.5, w - 0.04, q[2], -w + 0.04, q[2], -w - 0.01, 0.5, -w, 0.36], q[0]))
	k._add(m, VehicleModels.solid(ped, "boat_pwc_ped"), hm, liv, Vector3.ZERO)
	var seat1 := []
	for q in [[-0.47, 0.15, 0.74], [-0.39, 0.215, 0.785], [0.12, 0.225, 0.795], [0.24, 0.2, 0.775]]:
		seat1.append(_cushion(q[1], 0.63, q[2], q[0]))
	k._add(m, VehicleModels.solid(seat1, "boat_pwc_seat1"), "plain_dark", dark, Vector3.ZERO)
	var seat2 := []
	for q in [[0.16, 0.2, 0.815], [0.28, 0.23, 0.85], [0.86, 0.23, 0.85], [0.99, 0.17, 0.805]]:
		seat2.append(_cushion(q[1], 0.63, q[2], q[0]))
	k._add(m, VehicleModels.solid(seat2, "boat_pwc_seat2"), "plain_dark", dark, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		# footwell mats
		k._box(m, Vector3(0.2, 0.012, 1.45), Vector3(s * 0.4, _sheer(p, 0.25) + 0.004, 0.35), "plain_dark", Color(0.22, 0.22, 0.22))
	# the boarding platform, its step and the grab handle behind the saddle
	k._box(m, Vector3(0.86, 0.014, 0.34), Vector3(0, 0.405, 1.29), "plain_dark", Color(0.22, 0.22, 0.22))
	k._box(m, Vector3(0.22, 0.025, 0.1), Vector3(0, 0.24, 1.54), "plain_dark", dark)
	_rod(k, m, Vector3(-0.14, 0.8, 1.06), Vector3(0.14, 0.8, 1.06), 0.016, "plain_dark", dark, 8, true)
	for sx in [-0.14, 0.14]:
		_rod(k, m, Vector3(sx, 0.8, 1.06), Vector3(sx, 0.6, 1.02), 0.016, "plain_dark", dark, 8, true)
	# jet nozzle and reverse gate under the stern, tow eyes at both ends
	k._cyl(m, 0.075, 0.09, 0.18, Vector3(0, 0.2, 1.55), Vector3(PI / 2, 0, 0), "metal_dark", null, 12)
	k._cyl(m, 0.058, 0.07, 0.1, Vector3(0, 0.2, 1.69), Vector3(PI / 2, 0, 0), "metal_dark", null, 12)
	k._box(m, Vector3(0.17, 0.12, 0.022), Vector3(0, 0.27, 1.73), "plain_dark", dark, Vector3(-0.4, 0, 0))
	k._add(m, Res.torus(0.016, 0.03), "steel", STAINLESS, Vector3(0, 0.36, 1.49), Vector3(PI / 2, 0, 0))
	k._add(m, Res.torus(0.016, 0.03), "steel", STAINLESS, Vector3(0, 0.46, _stem(p, 0.46) - 0.02), Vector3(0, 0, PI / 2))
	# the handlebar pod, bars and grips, a smoked visor, the display
	k._add(m, VehicleModels.loft("boat_pwc_pod", _rr(0.28, 0.28, -0.52, 0.08, 0.06), _rr(0.2, 0.18, -0.49, 0.06, 0.05), 0.88, 1.0), hm, dark, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		_rod(k, m, Vector3(0, 0.99, -0.49), Vector3(s * 0.3, 1.02, -0.41), 0.015, "gunmetal_w", null, 6, true)
		k._cyl(m, 0.023, 0.023, 0.13, Vector3(s * 0.36, 1.025, -0.395), Vector3(0, 0, PI / 2), "rubber", null, 8)
		# mirrors on stalks off the pod
		_rod(k, m, Vector3(s * 0.12, 0.97, -0.58), Vector3(s * 0.3, 1.0, -0.62), 0.01, "plain_dark", dark)
		k._box(m, Vector3(0.11, 0.065, 0.03), Vector3(s * 0.34, 1.0, -0.62), hm, liv)
		k._box(m, Vector3(0.09, 0.05, 0.006), Vector3(s * 0.34, 1.0, -0.603), "glass", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.1, 0.045, 0.04), Vector3(0.29, 0.995, -0.44), "plain_dark", dark)
	k._box(m, Vector3(0.28, 0.12, 0.008), Vector3(0, 1.03, -0.62), "glass", Color(0.2, 0.24, 0.27), Vector3(0.95, 0, 0), false)
	k._box(m, Vector3(0.13, 0.012, 0.08), Vector3(0, 1.005, -0.53), "glass", null, Vector3(0.3, 0, 0), false)
	# a strap across the pillion seat, grey panels down the pedestal's sides,
	# air vents on the hood's shoulders, the fuel cap
	k._box(m, Vector3(0.44, 0.012, 0.05), Vector3(0, 0.853, 0.58), "plain_dark", Color(0.08, 0.08, 0.08), Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.01, 0.09, 1.0), Vector3(s * 0.283, 0.48, 0.3), "plain", Color(0.33, 0.33, 0.34), Vector3.ZERO, false)
		# (on the hood's dome section at z = -0.75: half-width 0.495 from 0.464 up 0.441)
		for i in 2:
			var a := deg_to_rad(31.0 + i * 9.0)
			var vp := Vector3(s * 0.495 * pow(cos(a), 2.0 / 2.2), 0.464 + 0.441 * pow(sin(a), 2.0 / 2.2), -0.75)
			k._box(m, Vector3(0.012, 0.022, 0.16), vp, "plain_dark", Color(0.06, 0.06, 0.06), Vector3(0, 0, s * a), false)
	k._cyl(m, 0.035, 0.035, 0.02, Vector3(0.2, 0.83, -1.05), Vector3(0.3, 0, -0.3), "plain_dark", dark, 10, false)
	# the hood's storage hatch seam
	k._box(m, Vector3(0.008, 0.01, 0.42), Vector3(0, 0.905, -0.98), "plain_dark", dark, Vector3(0.24, 0, 0), false)


## A saddle cross-section ring: half-width w, from y0 up to y1, rounded.
static func _cushion(w: float, y0: float, y1: float, z: float) -> PackedVector3Array:
	var h := y1 - y0
	return _rz([w * 0.9, y0, w, y0 + h * 0.35, w * 0.93, y0 + h * 0.7, w * 0.72, y0 + h * 0.93, w * 0.35, y1,
		-w * 0.35, y1, -w * 0.72, y0 + h * 0.93, -w * 0.93, y0 + h * 0.7, -w, y0 + h * 0.35, -w * 0.9, y0], z)


## A dome-shaped section standing on a base line (a hood, a fairing): half
## base width w at height y, h tall, squareness e, n points.
static func _dome(w: float, y: float, h: float, z: float, e: float, n: int) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in n:
		var a := PI * i / (n - 1)
		var c := cos(a)
		r.append(Vector3(w * signf(c) * pow(absf(c), 2.0 / e), y + h * pow(sin(a), 2.0 / e), z))
	return r


