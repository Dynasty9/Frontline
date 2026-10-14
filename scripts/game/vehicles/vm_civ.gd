class_name VmCiv
extends RefCounted
## Procedural models: FIA, Syndikat and civilian ground vehicles (Offroad, MB 4WD, Truck, Van, Quadbike, Hatchback, SUV, Kart, Tractor, ED-1 mini UGV).
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys must be unique per shape).
##
## The bodies are side profiles extruded across the width with chamfered
## edges (_xbody), their wheel arches cut round; glasshouses are lofted
## between the beltline and the roof and glazed with panes laid on their
## faces (_pane). Paint is sun-faded civilian colour picked by the seed, so a
## street of them isn't uniform.

## Every model key this file builds (the Field Manual's model pages list them).
const KEYS: Array[String] = ["offroad", "offroad_hmg", "offroad_at", "offroad_repair", "mb4wd", "mb4wd_lmg", "mb4wd_at",
	"fia_truck", "fia_truck_box", "van_transport", "van_ambulance", "van_services", "quadbike", "hatchback",
	"hatchback_sport", "suv", "kart", "tractor", "ed1"]

## Sun-faded civilian paints: white, silver, dark blue, maroon, beige, dark green, black.
const CIVIL := [Color(0.74, 0.73, 0.69), Color(0.55, 0.56, 0.56), Color(0.17, 0.21, 0.3), Color(0.29, 0.1, 0.1),
	Color(0.64, 0.58, 0.46), Color(0.2, 0.26, 0.2), Color(0.12, 0.12, 0.12)]
## What irregulars drive: the same, plus their own rattle-can sand, olive and a rust brown.
const IRREG := [Color(0.74, 0.73, 0.69), Color(0.55, 0.56, 0.56), Color(0.17, 0.21, 0.3), Color(0.29, 0.1, 0.1),
	Color(0.64, 0.58, 0.46), Color(0.2, 0.26, 0.2), Color(0.12, 0.12, 0.12), Color(0.56, 0.5, 0.38),
	Color(0.34, 0.35, 0.27), Color(0.42, 0.29, 0.2)]

const TRIM := Color(0.12, 0.12, 0.12)  # black plastic: bumpers, flares, mirrors
const HEAD := Color(0.86, 0.86, 0.81)  # headlight bulbs, projectors
const LENS := Color(0.5, 0.53, 0.55)  # headlight clusters behind the glass
const TAIL := Color(0.52, 0.06, 0.05)  # tail lights
const AMBER := Color(0.8, 0.46, 0.1)  # indicators, beacons
const PLATE := Color(0.85, 0.84, 0.78)  # number plates
const OD := Color(0.3, 0.32, 0.23)  # olive drab weapon paint


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"offroad", "offroad_hmg", "offroad_at", "offroad_repair":
			_offroad(k, team, seed, key.trim_prefix("offroad").trim_prefix("_"))
		"mb4wd", "mb4wd_lmg", "mb4wd_at":
			_mb4wd(k, team, seed, key.trim_prefix("mb4wd").trim_prefix("_"))
		"fia_truck", "fia_truck_box":
			_truck(k, team, seed, key.trim_prefix("fia_truck").trim_prefix("_"))
		"van_transport", "van_ambulance", "van_services":
			_van(k, team, seed, key.trim_prefix("van_"))
		"quadbike":
			_quad(k, seed)
		"hatchback", "hatchback_sport":
			_hatch(k, seed, key == "hatchback_sport")
		"suv":
			_suv(k, seed)
		"kart":
			_kart(k, seed)
		"tractor":
			_tractor(k, seed)
		"ed1":
			_ed1(k, team)
		_:
			return false
	return true


# --- paint ------------------------------------------------------------------------

## A faded paint for this vehicle: `salt` keeps different models built with the
## same seed from all coming out the same colour.
static func _paint(seed: int, salt: int, irregular := false) -> Color:
	var pal: Array = IRREG if irregular else CIVIL
	var h := absi(hash(seed * 7919 + salt * 104729))
	var c: Color = pal[h % pal.size()]
	# a little dust and sun on top of it
	return c.lerp(Color(0.55, 0.5, 0.42), float((h >> 4) % 4) * 0.04)


# --- geometry helpers -------------------------------------------------------------

## Insets a convex polygon: edge i (p[i] to p[i+1]) moves in by d[i].
static func _inset(p: PackedVector2Array, d: Array) -> PackedVector2Array:
	var n := p.size()
	var area := 0.0
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	var sgn := 1.0 if area > 0.0 else -1.0
	var out := PackedVector2Array()
	for i in n:
		var pa := p[(i - 1 + n) % n]
		var pb := p[i]
		var pc := p[(i + 1) % n]
		var e1 := (pb - pa).normalized()
		var e2 := (pc - pb).normalized()
		var n1 := Vector2(-e1.y, e1.x) * sgn
		var n2 := Vector2(-e2.y, e2.x) * sgn
		var d1: float = d[(i - 1 + n) % n]
		var d2: float = d[i]
		var c1 := n1.dot(pb) + d1
		var c2 := n2.dot(pb) + d2
		var det := n1.x * n2.y - n1.y * n2.x
		if absf(det) < 1e-4:
			out.append(pb + n1 * maxf(d1, d2))
		else:
			out.append(Vector2((c1 * n2.y - c2 * n1.y) / det, (n1.x * c2 - n2.x * c1) / det))
	return out


## Clips a convex polygon to the half-plane nrm.p >= c. f holds a flag per edge
## (edge i runs p[i] to p[i+1]); the new edge along the cut gets `cut`.
## Returns [points, flags].
static func _clip(p: PackedVector2Array, f: Array, nrm: Vector2, c: float, cut: bool) -> Array:
	var n := p.size()
	var op := PackedVector2Array()
	var arrive := []
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		var ina := nrm.dot(a) >= c - 1e-6
		var inb := nrm.dot(b) >= c - 1e-6
		if ina and inb:
			op.append(b)
			arrive.append(f[i])
		elif ina:
			op.append(a.lerp(b, (c - nrm.dot(a)) / (nrm.dot(b) - nrm.dot(a))))
			arrive.append(f[i])
		elif inb:
			op.append(a.lerp(b, (c - nrm.dot(a)) / (nrm.dot(b) - nrm.dot(a))))
			arrive.append(cut)
			op.append(b)
			arrive.append(f[i])
	var m := op.size()
	var of := []
	for i in m:
		of.append(arrive[(i + 1) % m])
	# drop doubled points (a zero-length edge hands its place to the next)
	var dp := PackedVector2Array()
	var df := []
	for i in m:
		if dp.size() > 0 and op[i].distance_to(dp[dp.size() - 1]) < 1e-4:
			df[df.size() - 1] = of[i]
			continue
		dp.append(op[i])
		df.append(of[i])
	while dp.size() > 1 and dp[0].distance_to(dp[dp.size() - 1]) < 1e-4:
		dp.remove_at(dp.size() - 1)
		df.pop_back()
	return [dp, df]


## A convex side profile (z, y) extruded from x0 to x1, its outer edges (flag
## true) chamfered by ch at both ends. rnd [zmin, zmax, front length, front
## inset, rear length, rear inset] rounds the corners off in plan.
static func _xprism(k: VehicleModels, parent: Node3D, key: String, p: PackedVector2Array, f: Array, x0: float, x1: float, ch: float, mat: String, col = null, rnd: Array = []) -> MeshInstance3D:
	var d := []
	for fl in f:
		d.append(ch if fl else 0.0)
	var pin := _inset(p, d)
	var mesh := VehicleModels.solid([_xring(pin, x0, 1.0, rnd), _xring(p, x0 + ch, 1.0, rnd),
		_xring(p, x1 - ch, -1.0, rnd), _xring(pin, x1, -1.0, rnd)], key)
	return k._add(parent, mesh, mat, col, Vector3.ZERO)


## A side-profile ring at x, pulled in (towards +x when s is 1) where the
## plan rounding says.
static func _xring(p: PackedVector2Array, x: float, s: float, rnd: Array) -> PackedVector3Array:
	var r := PackedVector3Array()
	for q in p:
		r.append(Vector3(x + s * _taper(q.x, rnd), q.y, q.x))
	return r


static func _taper(z: float, rnd: Array) -> float:
	if rnd.is_empty():
		return 0.0
	var zmin: float = rnd[0]
	var zmax: float = rnd[1]
	var lf: float = rnd[2]
	var lr: float = rnd[4]
	if lf > 0.0 and z < zmin + lf:
		var t := (zmin + lf - z) / lf
		return float(rnd[3]) * t * t
	if lr > 0.0 and z > zmax - lr:
		var t := (z - (zmax - lr)) / lr
		return float(rnd[5]) * t * t
	return 0.0


## A body panel: a convex side profile (z, y pairs) from x0 to x1 with
## chamfered edges and round wheel arches [zc, yc, r] cut out of its underside.
## rnd [front length, front inset, rear length, rear inset] rounds the corners
## off in plan.
static func _xbody(k: VehicleModels, parent: Node3D, key: String, prof: Array, x0: float, x1: float, ch: float, arches: Array, mat: String, col = null, segs := 8, rnd: Array = []) -> void:
	var p := VehicleModels._v2(prof)
	var zmin := INF
	var zmax := -INF
	for v in p:
		zmin = minf(zmin, v.x)
		zmax = maxf(zmax, v.x)
	# strips: plain between the arches, one per chord over them, and a few
	# more where the corners round off
	var cuts := []
	for a in arches:
		var zc: float = a[0]
		var r: float = a[2]
		for i in segs + 1:
			var t := PI - PI * float(i) / segs
			cuts.append(zc + r * cos(t))
	var rr := []
	if not rnd.is_empty():
		rr = [zmin, zmax, rnd[0], rnd[1], rnd[2], rnd[3]]
		for fr in [0.12, 0.3, 0.55, 1.0]:
			if float(rnd[0]) > 0.0:
				cuts.append(zmin + float(rnd[0]) * fr)
			if float(rnd[2]) > 0.0:
				cuts.append(zmax - float(rnd[2]) * fr)
	cuts.sort()
	var bounds := [zmin]
	for z in cuts:
		if z > float(bounds[bounds.size() - 1]) + 0.015 and z < zmax - 0.015:
			bounds.append(z)
	bounds.append(zmax)
	var flags := []
	for i in p.size():
		flags.append(true)
	for i in bounds.size() - 1:
		var za: float = bounds[i]
		var zb: float = bounds[i + 1]
		var poly := p
		var fl := flags
		if i > 0:
			var r0 := _clip(poly, fl, Vector2(1, 0), za, false)
			poly = r0[0]
			fl = r0[1]
		if i < bounds.size() - 2 and poly.size() >= 3:
			var r1 := _clip(poly, fl, Vector2(-1, 0), -zb, false)
			poly = r1[0]
			fl = r1[1]
		# over an arch: keep what's above the chord
		var zm := (za + zb) * 0.5
		for a in arches:
			var zc: float = a[0]
			var yc: float = a[1]
			var r: float = a[2]
			if zm > zc - r and zm < zc + r and poly.size() >= 3:
				var ya := yc + sqrt(maxf(0.0, r * r - (za - zc) * (za - zc)))
				var yb := yc + sqrt(maxf(0.0, r * r - (zb - zc) * (zb - zc)))
				var nrm := Vector2(-(yb - ya), zb - za).normalized()
				var r2 := _clip(poly, fl, nrm, nrm.dot(Vector2(za, ya)), true)
				poly = r2[0]
				fl = r2[1]
		if poly.size() >= 3:
			_xprism(k, parent, "%s_%d" % [key, i], poly, fl, x0, x1, ch, mat, col, rr)


## A wheel-arch flare: a band round the arch from angle a0 to a1 (0 is the
## rear, PI the front), r0 to r1 from the axle, x0 to x1 across.
static func _flare(k: VehicleModels, parent: Node3D, key: String, zc: float, yc: float, r0: float, r1: float, x0: float, x1: float, a0: float, a1: float, mat: String, col = null, segs := 6) -> void:
	for i in segs:
		var t0 := lerpf(a0, a1, float(i) / segs)
		var t1 := lerpf(a0, a1, float(i + 1) / segs)
		var q := PackedVector2Array([Vector2(zc + r0 * cos(t0), yc + r0 * sin(t0)), Vector2(zc + r0 * cos(t1), yc + r0 * sin(t1)),
			Vector2(zc + r1 * cos(t1), yc + r1 * sin(t1)), Vector2(zc + r1 * cos(t0), yc + r1 * sin(t0))])
		_xprism(k, parent, "%s_%d" % [key, i], q, [true, i == segs - 1, true, i == 0], x0, x1, minf(0.012, (x1 - x0) * 0.3), mat, col)


## A loft through plan outlines (x, z pairs, convex, same point count) at the
## given heights, the top edge chamfered by ch. Returns the mesh instance.
static func _yloft(k: VehicleModels, parent: Node3D, key: String, outlines: Array, ys: Array, ch: float, mat: String, col = null, pos := Vector3.ZERO) -> MeshInstance3D:
	var rings := []
	var n := outlines.size()
	for i in n:
		var o := VehicleModels._v2(outlines[i])
		var y: float = ys[i]
		if i == n - 1 and ch > 0.0:
			var below := VehicleModels._v2(outlines[i - 1])
			var yb: float = ys[i - 1]
			var t := ch / maxf(0.01, y - yb)
			var mid := PackedVector2Array()
			for j in o.size():
				mid.append(o[j].lerp(below[j], t))
			rings.append(VehicleModels.ring_y(mid, y - ch))
			var d := []
			for j in o.size():
				d.append(ch)
			rings.append(VehicleModels.ring_y(_inset(o, d), y))
		else:
			rings.append(VehicleModels.ring_y(o, y))
	return k._add(parent, VehicleModels.solid(rings, key), mat, col, pos)


## A thin plate laid on a face given by its four corners (in order round it):
## the part [u0, u1] x [v0, v1] of it (u along c0-c1, v from c0-c1 to c3-c2),
## `out` proud of the face and `thick` thick, along the normal away from `inside`.
static func _pane(k: VehicleModels, parent: Node3D, key: String, c: Array, inside: Vector3, u0: float, u1: float, v0: float, v1: float, out: float, thick: float, mat: String, col = null) -> MeshInstance3D:
	var c0: Vector3 = c[0]
	var c1: Vector3 = c[1]
	var c2: Vector3 = c[2]
	var c3: Vector3 = c[3]
	var nrm := (c1 - c0).cross(c3 - c0).normalized()
	if nrm.dot(c0 - inside) < 0.0:
		nrm = -nrm
	var ra := PackedVector3Array()
	var rb := PackedVector3Array()
	for uv in [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]:
		var a := c0.lerp(c1, uv.x)
		var b := c3.lerp(c2, uv.x)
		var q := a.lerp(b, uv.y)
		ra.append(q + nrm * out)
		rb.append(q + nrm * (out + thick))
	return k._add(parent, VehicleModels.solid([ra, rb], key), mat, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, mat != "glass")


## The corners of face i of a loft between two rings (bottom i, i+1, top i+1, i).
static func _face(lo: PackedVector3Array, hi: PackedVector3Array, i: int) -> Array:
	var j := (i + 1) % lo.size()
	return [lo[i], lo[j], hi[j], hi[i]]


static func _ring(o: Array, y: float) -> PackedVector3Array:
	return VehicleModels.ring_y(VehicleModels._v2(o), y)


## A ring in the XY plane (an outline seen from the front) on a face leaning
## back: z = z0 at height y0, moving `slope` back per metre up.
static func _zring(p: PackedVector2Array, z0: float, slope: float, y0: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for q in p:
		r.append(Vector3(q.x, q.y, z0 + (q.y - y0) * slope))
	return r


## A box from a to b (w across, t thick), its width kept as level as it goes.
static func _strut(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, w: float, t: float, mat: String, col = null, shadow := true) -> MeshInstance3D:
	var mi := k._add(parent, Res.box(Vector3(w, (b - a).length(), t)), mat, col, (a + b) * 0.5, Vector3.ZERO, Vector3.ONE, shadow)
	mi.basis = _along(b - a)
	return mi


## A box from a to b (its length), h tall about `up`, t thick: lamps and
## panels laid along a curving surface.
static func _slab(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, h: float, t: float, mat: String, col = null, up := Vector3.UP, shadow := false) -> MeshInstance3D:
	var mi := k._add(parent, Res.box(Vector3((b - a).length(), h, t)), mat, col, (a + b) * 0.5, Vector3.ZERO, Vector3.ONE, shadow)
	var x := (b - a).normalized()
	var z := x.cross(up).normalized()
	mi.basis = Basis(x, z.cross(x), z)
	return mi


## A tube from a to b.
static func _rod(k: VehicleModels, parent: Node3D, a: Vector3, b: Vector3, r: float, mat: String, col = null, segs := 8, shadow := true) -> MeshInstance3D:
	var mi := k._add(parent, Res.cyl(r, r, (b - a).length(), segs), mat, col, (a + b) * 0.5, Vector3.ZERO, Vector3.ONE, shadow)
	mi.basis = _along(b - a)
	return mi


## A tube bent through the given points.
static func _bent(k: VehicleModels, parent: Node3D, pts: Array, r: float, mat: String, col = null, segs := 8) -> void:
	for i in pts.size() - 1:
		_rod(k, parent, pts[i], pts[i + 1], r, mat, col, segs)
		if i > 0:
			k._add(parent, Res.sphere(r, segs), mat, col, pts[i])


## A basis whose Y runs along d (X kept as near world X as it can be).
static func _along(d: Vector3) -> Basis:
	var y := d.normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := ref.cross(y).normalized()
	var x := y.cross(z)
	return Basis(x, y, z)


static func _lamp(k: VehicleModels, parent: Node3D, s: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> void:
	k._add(parent, Res.box(s), "paint", c, pos, rot, Vector3.ONE, false)


## A number plate facing -z (front) or +z (rear).
static func _plate(k: VehicleModels, parent: Node3D, pos: Vector3, rear: bool, w := 0.52, rot_x := 0.0) -> void:
	var s := 1.0 if rear else -1.0
	k._add(parent, Res.box(Vector3(w, 0.12, 0.016)), "paint", PLATE, pos, Vector3(rot_x, 0, 0), Vector3.ONE, false)
	k._add(parent, Res.box(Vector3(w * 0.78, 0.05, 0.006)), "paint", Color(0.16, 0.16, 0.17), pos + Vector3(0, -0.005, s * 0.01), Vector3(rot_x, 0, 0), Vector3.ONE, false)


## A wing mirror on an arm, on side s (+1 right, -1 left).
static func _mirror(k: VehicleModels, parent: Node3D, s: float, base: Vector3, reach: float, size: Vector3, mat: String, col = null) -> void:
	_strut(k, parent, base, base + Vector3(s * reach, 0.02, 0.03), 0.03, 0.05, "plain", TRIM, false)
	k._box(parent, size, base + Vector3(s * (reach + size.x * 0.4), 0.04, 0.04), mat, col, Vector3(0, s * 0.12, 0))
	k._box(parent, Vector3(size.x * 0.8, size.y * 0.8, 0.01), base + Vector3(s * (reach + size.x * 0.4), 0.04, 0.04 + size.z * 0.5), "glass", null, Vector3(0, s * 0.12, 0), false)


## A jerrycan standing at pos (turned by yaw).
static func _jerrycan(k: VehicleModels, parent: Node3D, pos: Vector3, c: Color, yaw := 0.0) -> void:
	k._box(parent, Vector3(0.17, 0.46, 0.34), pos + Vector3(0, 0.23, 0), "paint", c, Vector3(0, yaw, 0))
	k._box(parent, Vector3(0.13, 0.05, 0.2), pos + Vector3(0, 0.48, 0.0), "paint", c.darkened(0.2), Vector3(0, yaw, 0))
	k._cyl(parent, 0.025, 0.025, 0.05, pos + Vector3(0, 0.49, -0.12).rotated(Vector3.UP, yaw), Vector3.ZERO, "gunmetal_w", null, 6, false)


## A loose tyre on its rim lying flat (spare), centre at pos.
static func _spare(k: VehicleModels, parent: Node3D, pos: Vector3, r: float, w: float, rot := Vector3.ZERO, hub_mat := "steel", hub_col = null) -> void:
	k._cyl(parent, r, r, w, pos, rot, "rubber", null, 18)
	k._cyl(parent, r * 0.6, r * 0.6, w + 0.02, pos, rot, hub_mat, hub_col, 14)
	k._cyl(parent, r * 0.2, r * 0.22, w + 0.05, pos, rot, "gunmetal_w", null, 8)


# --- weapons ----------------------------------------------------------------------

## M2 .50 cal along -z, the receiver's trunnion at y above the parent's origin.
## Returns the muzzle.
static func _m2(k: VehicleModels, t: Node3D, y: float) -> Vector3:
	k._box(t, Vector3(0.17, 0.2, 0.6), Vector3(0, y - 0.02, 0.12), "gunmetal_w")
	k._box(t, Vector3(0.18, 0.03, 0.44), Vector3(0, y + 0.095, 0.1), "gunmetal_w")
	k._box(t, Vector3(0.16, 0.17, 0.03), Vector3(0, y - 0.02, 0.43), "gunmetal_w")
	for sx in [-0.085, 0.085]:
		k._cyl(t, 0.022, 0.022, 0.14, Vector3(sx, y + 0.06, 0.5), Vector3.ZERO, "gunmetal_w", null, 6, false)
	k._box(t, Vector3(0.03, 0.045, 0.1), Vector3(0.1, y + 0.01, 0.05), "gunmetal_w", null, Vector3.ZERO, false)
	k._cyl(t, 0.048, 0.048, 0.25, Vector3(0, y, -0.305), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	for z in [-0.24, -0.33]:
		k._cyl(t, 0.054, 0.054, 0.03, Vector3(0, y, z), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
	k._cyl(t, 0.029, 0.029, 0.9, Vector3(0, y, -0.88), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	k._box(t, Vector3(0.025, 0.07, 0.11), Vector3(0, y + 0.06, -0.62), "gunmetal_w", null, Vector3.ZERO, false)
	k._cyl(t, 0.05, 0.03, 0.11, Vector3(0, y, -1.38), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
	# the ammo can on its tray, the belt up into the feed
	k._box(t, Vector3(0.12, 0.19, 0.29), Vector3(-0.2, y - 0.08, 0.08), "paint", OD)
	k._box(t, Vector3(0.12, 0.02, 0.06), Vector3(-0.2, y + 0.02, 0.0), "paint", OD.darkened(0.25))
	k._box(t, Vector3(0.1, 0.03, 0.05), Vector3(-0.13, y + 0.04, 0.08), "paint", Color(0.62, 0.5, 0.24), Vector3(0, 0, 0.4), false)
	return Vector3(0, y, -1.45)


## M249-pattern light machine gun (the LIM-85) along -z. Returns the muzzle.
static func _lmg(k: VehicleModels, t: Node3D, y: float) -> Vector3:
	k._box(t, Vector3(0.075, 0.12, 0.36), Vector3(0, y, 0.05), "gunmetal_w")
	k._box(t, Vector3(0.08, 0.03, 0.22), Vector3(0, y + 0.07, 0.02), "gunmetal_w")
	k._box(t, Vector3(0.05, 0.11, 0.3), Vector3(0, y - 0.01, 0.37), "gunmetal_w", null, Vector3(0.06, 0, 0))
	k._box(t, Vector3(0.055, 0.15, 0.03), Vector3(0, y - 0.02, 0.52), "gunmetal_w")
	k._box(t, Vector3(0.035, 0.1, 0.045), Vector3(0, y - 0.1, 0.17), "gunmetal_w", null, Vector3(-0.3, 0, 0), false)
	k._box(t, Vector3(0.06, 0.05, 0.2), Vector3(0, y - 0.01, -0.22), "gunmetal_w")
	k._cyl(t, 0.016, 0.016, 0.5, Vector3(0, y, -0.5), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	k._cyl(t, 0.022, 0.018, 0.07, Vector3(0, y, -0.78), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	k._box(t, Vector3(0.02, 0.06, 0.12), Vector3(0.04, y + 0.06, -0.16), "gunmetal_w", null, Vector3.ZERO, false)
	for sx in [-0.02, 0.02]:
		k._box(t, Vector3(0.012, 0.012, 0.3), Vector3(sx, y - 0.05, -0.42), "gunmetal_w", null, Vector3.ZERO, false)
	# 200-round box under the left of the receiver
	k._box(t, Vector3(0.1, 0.13, 0.13), Vector3(-0.06, y - 0.11, 0.03), "paint", OD)
	return Vector3(0, y, -0.82)


## SPG-9 recoilless rifle along -z on its saddle, the trunnion at y. Returns the muzzle.
static func _spg9(k: VehicleModels, t: Node3D, y: float) -> Vector3:
	var g := Color(0.3, 0.32, 0.25)
	# the thin forward tube, the fat chamber, the venturi flaring at the back
	k._cyl(t, 0.05, 0.05, 1.25, Vector3(0, y, -0.62), Vector3(PI / 2, 0, 0), "paint", g, 12)
	k._cyl(t, 0.062, 0.062, 0.05, Vector3(0, y, -1.24), Vector3(PI / 2, 0, 0), "paint", g.darkened(0.2), 12, false)
	k._cyl(t, 0.085, 0.085, 0.55, Vector3(0, y, 0.25), Vector3(PI / 2, 0, 0), "paint", g, 12)
	k._cyl(t, 0.065, 0.085, 0.12, Vector3(0, y, -0.08), Vector3(PI / 2, 0, 0), "paint", g, 12)
	k._cyl(t, 0.11, 0.07, 0.3, Vector3(0, y, 0.67), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	k._cyl(t, 0.115, 0.115, 0.03, Vector3(0, y, 0.82), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12, false)
	# clamping bands, the sight on the left, trigger group underneath
	for z in [-0.6, 0.05]:
		k._cyl(t, 0.07, 0.07, 0.04, Vector3(0, y, z), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
	k._box(t, Vector3(0.08, 0.13, 0.2), Vector3(-0.13, y + 0.06, 0.0), "paint", g.darkened(0.15))
	k._cyl(t, 0.025, 0.025, 0.1, Vector3(-0.13, y + 0.1, 0.13), Vector3(PI / 2, 0, 0), "rubber", null, 8, false)
	k._box(t, Vector3(0.05, 0.06, 0.16), Vector3(0, y - 0.11, 0.12), "gunmetal_w")
	k._box(t, Vector3(0.035, 0.1, 0.04), Vector3(0, y - 0.17, 0.2), "gunmetal_w", null, Vector3(-0.3, 0, 0), false)
	# the saddle the tube sits in
	k._box(t, Vector3(0.2, 0.08, 0.26), Vector3(0, y - 0.1, 0.0), "paint", g.darkened(0.1))
	return Vector3(0, y, -1.27)


# --- Offroad ----------------------------------------------------------------------

## Offroad: a Mitsubishi L200-style two-door pickup with an Audi Q7-ish face -
## the tall single-frame grille, swept headlights, flared arches - a single cab
## and a long open bed. Variants: "" plain, "hmg" an M2 on a pedestal with a
## gunner's shield, "at" an SPG-9 on a tripod, "repair" a workshop bed.
static func _offroad(k: VehicleModels, team: int, seed: int, v: String) -> void:
	var m := k.root
	var col := _paint(seed, 11 + v.length(), v != "")
	var hw := 0.89
	var zf := -1.58
	var zr := 1.42
	var wr := 0.38
	var ar := 0.47
	# ladder frame, the wells behind the wheels, axles and diffs, exhaust
	k._box(m, Vector3(0.9, 0.2, 4.5), Vector3(0, 0.46, 0.05), "gunmetal_w")
	for z in [zf, zr]:
		k._box(m, Vector3(1.24, 0.48, 0.9), Vector3(0, 0.66, z), "plain_dark")
	k._cyl(m, 0.06, 0.06, 1.3, Vector3(0, wr, zr), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
	k._add(m, Res.sphere(0.14, 10), "gunmetal_w", null, Vector3(0.08, wr, zr), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	k._box(m, Vector3(0.7, 0.12, 0.5), Vector3(0, 0.32, zf), "gunmetal_w")
	k._cyl(m, 0.035, 0.035, 2.2, Vector3(0.38, 0.33, 1.25), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	k._cyl(m, 0.045, 0.04, 0.12, Vector3(0.38, 0.33, 2.4), Vector3(PI / 2, 0, 0), "steel", null, 8, false)
	# the cab and front wings in one panel, the nose a loft with its corners
	# rounded off for the headlights to wrap round, the bed separate
	_xbody(k, m, "civ_off_body", [-2.26, 0.5, 0.33, 0.5, 0.33, 1.21, -0.92, 1.2, -2.26, 1.05],
		-hw, hw, 0.04, [[zf, wr, ar]], "car_paint", col)
	var nlo := [-0.72, -2.53, 0.72, -2.53, 0.89, -2.38, 0.89, -2.24, -0.89, -2.24, -0.89, -2.38]
	var nhi := [-0.68, -2.45, 0.68, -2.45, 0.87, -2.32, 0.87, -2.24, -0.87, -2.24, -0.87, -2.32]
	_yloft(k, m, "civ_off_nose", [nlo, nhi], [0.47, 1.05], 0.05, "car_paint", col)
	var lo3 := _ring(nlo, 0.47)
	var hi3 := _ring(nhi, 1.05)
	var nin := Vector3(0, 0.8, -2.0)
	for f in [1, 5]:
		var fc := _face(lo3, hi3, f)
		var a := 0.1 if f == 1 else 0.0
		_pane(k, m, "civ_off_hlc%d" % f, fc, nin, a, a + 0.9, 0.64, 0.9, 0.0, 0.02, "gunmetal_w")
		_pane(k, m, "civ_off_hlcl%d" % f, fc, nin, a + 0.06, a + 0.84, 0.68, 0.87, 0.02, 0.008, "paint", LENS)
	var ff := _face(lo3, hi3, 0)
	for s in [0, 1]:
		var u0 := 0.0 if s == 0 else 0.76
		_pane(k, m, "civ_off_hl%d" % s, ff, nin, u0, u0 + 0.24, 0.62, 0.9, 0.0, 0.02, "gunmetal_w")
		_pane(k, m, "civ_off_hll%d" % s, ff, nin, u0 + 0.02, u0 + 0.22, 0.66, 0.87, 0.02, 0.008, "paint", LENS)
		for j in 2:
			var pu := u0 + 0.04 + j * 0.09 + (0.0 if s == 0 else 0.02)
			_pane(k, m, "civ_off_prj%d%d" % [s, j], ff, nin, pu, pu + 0.07, 0.7, 0.83, 0.028, 0.01, "paint", HEAD)
		_pane(k, m, "civ_off_drl%d" % s, ff, nin, u0 + 0.02, u0 + 0.22, 0.6, 0.625, 0.02, 0.008, "paint", Color(0.95, 0.95, 0.9))
		_pane(k, m, "civ_off_fog%d" % s, ff, nin, u0 + 0.06, u0 + 0.16, 0.14, 0.22, 0.0, 0.02, "paint", LENS)
	# the black lower lip and the intake under the grille
	_pane(k, m, "civ_off_lip", ff, nin, 0.08, 0.92, 0.0, 0.1, 0.0, 0.04, "plain", TRIM)
	_xbody(k, m, "civ_off_bedb", [0.39, 0.5, 2.5, 0.5, 2.5, 0.96, 0.39, 0.96], -hw, hw, 0.03, [[zr, wr, ar]], "car_paint", col)
	k._box(m, Vector3(1.6, 0.6, 0.08), Vector3(0, 0.85, 0.36), "plain_dark")
	# bed: walls on the tub, a ribbed liner, wheel tubs, the tailgate
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.08, 0.3, 2.11), Vector3(s * (hw - 0.04), 1.1, 1.445), "car_paint", col)
		k._box(m, Vector3(0.11, 0.035, 2.11), Vector3(s * (hw - 0.05), 1.265, 1.445), "car_paint", col.darkened(0.08))
		k._box(m, Vector3(0.2, 0.2, 0.92), Vector3(s * 0.71, 1.06, zr), "plain_dark")
	k._box(m, Vector3(hw * 2.0, 0.3, 0.08), Vector3(0, 1.1, 0.43), "car_paint", col)
	k._box(m, Vector3(hw * 2.0 - 0.02, 0.32, 0.07), Vector3(0, 1.1, 2.47), "car_paint", col)
	k._box(m, Vector3(0.36, 0.04, 0.02), Vector3(0, 1.17, 2.51), "plain", TRIM, Vector3.ZERO, false)
	k._box(m, Vector3(1.6, 0.02, 1.98), Vector3(0, 0.97, 1.45), "rubber")
	for i in 7:
		k._box(m, Vector3(0.05, 0.022, 1.96), Vector3(-0.66 + i * 0.22, 0.982, 1.45), "rubber", null, Vector3.ZERO, false)
	# glasshouse: windscreen raked hard back, a short cab with its back window
	var lo := _ring([-0.86, -0.92, 0.86, -0.92, 0.86, 0.32, -0.86, 0.32], 1.21)
	var hi := _ring([-0.71, -0.3, 0.71, -0.3, 0.73, 0.26, -0.73, 0.26], 1.79)
	_yloft(k, m, "civ_off_gh", [[-0.86, -0.92, 0.86, -0.92, 0.86, 0.32, -0.86, 0.32], [-0.71, -0.3, 0.71, -0.3, 0.73, 0.26, -0.73, 0.26]], [1.21, 1.79], 0.05, "car_paint", col)
	var inside := Vector3(0, 1.5, -0.2)
	_pane(k, m, "civ_off_ws", _face(lo, hi, 0), inside, 0.03, 0.97, 0.04, 0.95, 0.0, 0.012, "glass")
	_pane(k, m, "civ_off_bw", _face(lo, hi, 2), inside, 0.12, 0.88, 0.22, 0.86, 0.0, 0.012, "glass")
	_pane(k, m, "civ_off_swr", _face(lo, hi, 1), inside, 0.66, 0.97, 0.08, 0.9, 0.0, 0.012, "glass")
	_pane(k, m, "civ_off_swl", _face(lo, hi, 3), inside, 0.03, 0.34, 0.08, 0.9, 0.0, 0.012, "glass")
	# doors: shut lines, handles, mirrors; side steps under them
	for s in [-1.0, 1.0]:
		for z in [-0.88, 0.22]:
			k._box(m, Vector3(0.012, 0.66, 0.012), Vector3(s * (hw + 0.002), 0.86, z), "plain_dark", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.02, 0.035, 0.13), Vector3(s * (hw + 0.01), 1.1, 0.08), "plain", TRIM, Vector3.ZERO, false)
		_mirror(k, m, s, Vector3(s * 0.86, 1.27, -0.78), 0.1, Vector3(0.1, 0.13, 0.17), "car_paint", col)
		k._box(m, Vector3(0.14, 0.04, 1.6), Vector3(s * 0.86, 0.42, -0.28), "plain", TRIM)
		k._box(m, Vector3(0.02, 0.09, 1.92), Vector3(s * (hw + 0.004), 0.56, -0.12), "plain", TRIM)
		k._box(m, Vector3(0.012, 0.022, 2.5), Vector3(s * (hw + 0.002), 1.04, -0.97), "car_paint", col.darkened(0.25), Vector3.ZERO, false)
		k._box(m, Vector3(0.012, 0.022, 2.08), Vector3(s * (hw + 0.002), 1.04, 1.45), "car_paint", col.darkened(0.25), Vector3.ZERO, false)
		k._box(m, Vector3(0.04, 0.08, 0.06), Vector3(s * 0.8, 0.46, -0.85), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.04, 0.08, 0.06), Vector3(s * 0.8, 0.46, 0.3), "gunmetal_w", null, Vector3.ZERO, false)
		# flared arches in black plastic
		_flare(k, m, "civ_off_ff%d" % int(s), zf, wr, ar - 0.01, ar + 0.07, s * hw - 0.03, s * hw + 0.04, 0.27, PI - 0.27, "plain", TRIM, 7)
		_flare(k, m, "civ_off_fr%d" % int(s), zr, wr, ar - 0.01, ar + 0.07, s * hw - 0.03, s * hw + 0.04, 0.27, PI - 0.27, "plain", TRIM, 7)
		for z in [zf, zr]:
			k._wheel(m, Vector3(s * 0.765, wr, z), wr, 0.27, "steel", Color(0.6, 0.61, 0.6))
		# tall tail lights on the bed corners
		_lamp(k, m, Vector3(0.1, 0.32, 0.05), Vector3(s * (hw - 0.05), 1.05, 2.505), TAIL)
		_lamp(k, m, Vector3(0.1, 0.08, 0.05), Vector3(s * (hw - 0.05), 0.85, 2.505), AMBER)
	# fuel filler on the bed side
	k._cyl(m, 0.06, 0.06, 0.02, Vector3(-hw - 0.005, 0.84, 1.95), Vector3(0, 0, PI / 2), "car_paint", col.darkened(0.1), 10, false)
	# the face: the tall single-frame grille in a bright surround, slats, plate
	var slope := 0.08 / 0.58
	var gp := VehicleModels._v2([-0.4, 0.52, 0.4, 0.52, 0.44, 0.6, 0.37, 0.97, -0.37, 0.97, -0.44, 0.6])
	var gi := _inset(gp, [0.03, 0.03, 0.03, 0.03, 0.03, 0.03])
	k._add(m, VehicleModels.solid([_zring(gp, -2.53 + 0.01, slope, 0.47), _zring(gp, -2.53 - 0.02, slope, 0.47)], "civ_off_grille"), "steel", Color(0.62, 0.63, 0.62), Vector3.ZERO)
	k._add(m, VehicleModels.solid([_zring(gi, -2.53 - 0.01, slope, 0.47), _zring(gi, -2.53 - 0.03, slope, 0.47)], "civ_off_grille_in"), "gunmetal_w", null, Vector3.ZERO)
	for i in 5:
		var y := 0.7 + i * 0.055
		k._box(m, Vector3(0.74 - (y - 0.7) * 0.25, 0.016, 0.02), Vector3(0, y, -2.53 + (y - 0.47) * slope - 0.035), "steel", Color(0.6, 0.61, 0.6), Vector3(slope, 0, 0), false)
	k._box(m, Vector3(0.05, 0.28, 0.02), Vector3(0, 0.82, -2.53 + 0.35 * slope - 0.04), "steel", Color(0.6, 0.61, 0.6), Vector3(slope, 0, 0), false)
	_plate(k, m, Vector3(0, 0.62, -2.53 + 0.15 * slope - 0.05), false, 0.52, slope)
	for s in [-1.0, 1.0]:
		_lamp(k, m, Vector3(0.05, 0.04, 0.12), Vector3(s * 0.9, 0.98, -2.22), AMBER)
	# wipers, aerial
	for x in [-0.32, 0.22]:
		k._box(m, Vector3(0.5, 0.012, 0.025), Vector3(x, 1.235, -0.86), "gunmetal_w", null, Vector3(-0.8, 0, 0.12), false)
	_rod(k, m, Vector3(0.84, 1.25, -0.88), Vector3(0.84, 2.1, -0.75), 0.006, "gunmetal_w", null, 4, false)
	# rear: step bumper, plate, tow ball
	k._box(m, Vector3(1.76, 0.16, 0.16), Vector3(0, 0.55, 2.56), "steel", Color(0.5, 0.5, 0.5))
	k._box(m, Vector3(0.5, 0.04, 0.12), Vector3(0, 0.64, 2.58), "plain", TRIM)
	_plate(k, m, Vector3(0, 0.79, 2.515), true)
	k._cyl(m, 0.03, 0.03, 0.12, Vector3(0, 0.46, 2.66), Vector3.ZERO, "gunmetal_w", null, 6, false)
	k._add(m, Res.sphere(0.04, 8), "gunmetal_w", null, Vector3(0, 0.54, 2.66))
	match v:
		"hmg":
			_off_hmg(k, team)
		"at":
			_off_at(k, team)
		"repair":
			_off_repair(k, team)


## An M2 on a pedestal in the bed, behind a gunner's shield.
static func _off_hmg(k: VehicleModels, team: int) -> void:
	var m := k.root
	k._box(m, Vector3(0.5, 0.03, 0.5), Vector3(0, 0.995, 1.5), "gunmetal_w")
	k._cyl(m, 0.07, 0.08, 0.62, Vector3(0, 1.3, 1.5), Vector3.ZERO, "gunmetal_w", null, 10)
	for s in [-1.0, 1.0]:
		_strut(k, m, Vector3(s * 0.22, 1.0, 1.72), Vector3(0, 1.4, 1.5), 0.04, 0.04, "gunmetal_w")
		_strut(k, m, Vector3(s * 0.22, 1.0, 1.28), Vector3(0, 1.4, 1.5), 0.04, 0.04, "gunmetal_w")
	# ammo cans and a spare box by the gunner's feet
	for i in 3:
		k._box(m, Vector3(0.14, 0.19, 0.3), Vector3(-0.55 + i * 0.16, 1.08, 2.2), "paint", OD)
	k._box(m, Vector3(0.6, 0.25, 0.35), Vector3(0.45, 1.1, 2.15), "wood", null)
	k.turret = k._pivot(m, Vector3(0, 1.62, 1.5))
	var t := k.turret
	k._cyl(t, 0.09, 0.09, 0.08, Vector3.ZERO, Vector3.ZERO, "gunmetal_w", null, 10)
	k._box(t, Vector3(0.05, 0.3, 0.16), Vector3(-0.1, 0.16, 0.0), "gunmetal_w")
	k._box(t, Vector3(0.05, 0.3, 0.16), Vector3(0.1, 0.16, 0.0), "gunmetal_w")
	var tip := _m2(k, t, 0.36)
	k.mg_tip = k._tip(t, tip)
	# the shield: a flat plate with the barrel slot, angled wings, a vision slit
	var sc := Color(0.2, 0.21, 0.19)
	k._box(t, Vector3(0.62, 0.52, 0.025), Vector3(0, 0.38, -0.42), "paint", sc, Vector3(0.08, 0, 0))
	for s in [-1.0, 1.0]:
		k._box(t, Vector3(0.025, 0.48, 0.32), Vector3(s * 0.42, 0.37, -0.32), "paint", sc, Vector3(0.08, s * 0.55, 0))
		k._box(t, Vector3(0.06, 0.04, 0.04), Vector3(s * 0.2, 0.15, -0.38), "gunmetal_w", null, Vector3.ZERO, false)
	k._box(t, Vector3(0.12, 0.06, 0.03), Vector3(0, 0.36, -0.44), "plain_dark", null, Vector3(0.08, 0, 0), false)
	k._box(t, Vector3(0.2, 0.03, 0.03), Vector3(0.18, 0.56, -0.45), "plain_dark", null, Vector3(0.08, 0, 0), false)
	_team_side(k, team)


## An SPG-9 on its tripod in the bed.
static func _off_at(k: VehicleModels, team: int) -> void:
	var m := k.root
	var top := Vector3(0, 1.7, 1.45)
	for a in [0.0, 2.2, -2.2]:
		var foot := Vector3(sin(a) * 0.62, 0.99, 1.45 + cos(a) * 0.55)
		_rod(k, m, top + Vector3(0, -0.08, 0), foot, 0.028, "paint", OD)
		k._box(m, Vector3(0.1, 0.02, 0.1), foot, "gunmetal_w")
	k._cyl(m, 0.06, 0.07, 0.14, top + Vector3(0, -0.06, 0), Vector3.ZERO, "paint", OD, 10)
	# a crate of rounds lashed in the bed
	k._box(m, Vector3(0.7, 0.24, 0.3), Vector3(-0.35, 1.1, 2.25), "wood_dark")
	k._box(m, Vector3(0.7, 0.24, 0.3), Vector3(-0.35, 1.1, 0.7), "wood_dark")
	k._box(m, Vector3(0.72, 0.03, 0.04), Vector3(-0.35, 1.2, 2.25), "gunmetal_w", null, Vector3.ZERO, false)
	k.turret = k._pivot(m, top)
	var t := k.turret
	k._cyl(t, 0.07, 0.07, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, "paint", OD, 10)
	var tip := _spg9(k, t, 0.33)
	k.gun_tip = k._tip(t, tip)
	k.mg_tip = k.gun_tip
	_team_side(k, team)


## The workshop pickup: tool chests, a spare wheel, jerrycans, gas bottles and
## a little davit crane over the tailgate; an amber beacon on the cab.
static func _off_repair(k: VehicleModels, team: int) -> void:
	var m := k.root
	var tc := Color(0.55, 0.16, 0.12)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.42, 0.42, 1.0), Vector3(s * 0.56, 1.19, 0.98), "paint", tc if s < 0 else Color(0.3, 0.32, 0.33))
		k._box(m, Vector3(0.44, 0.03, 1.02), Vector3(s * 0.56, 1.41, 0.98), "paint", (tc if s < 0 else Color(0.3, 0.32, 0.33)).darkened(0.2))
		for z in [0.7, 1.26]:
			k._box(m, Vector3(0.2, 0.03, 0.03), Vector3(s * 0.56, 1.3, z - 0.0) + Vector3(0, 0, 0), "gunmetal_w", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.02, 0.06, 0.06), Vector3(s * 0.34, 1.3, 0.98), "steel", null, Vector3.ZERO, false)
	_spare(k, m, Vector3(0.0, 1.36, 0.6), 0.36, 0.25, Vector3(PI / 2, 0, 0), "steel", Color(0.55, 0.56, 0.55))
	for i in 3:
		_jerrycan(k, m, Vector3(-0.6 + i * 0.19, 0.98, 2.2), [Color(0.3, 0.33, 0.22), Color(0.5, 0.1, 0.08), Color(0.3, 0.33, 0.22)][i])
	for i in 2:
		k._cyl(m, 0.1, 0.1, 0.9, Vector3(0.62 - i * 0.22, 1.43, 1.85), Vector3.ZERO, "paint", [Color(0.2, 0.3, 0.22), Color(0.6, 0.5, 0.18)][i], 12)
		k._add(m, Res.sphere(0.1, 10), "paint", [Color(0.2, 0.3, 0.22), Color(0.6, 0.5, 0.18)][i], Vector3(0.62 - i * 0.22, 1.88, 1.85))
		k._cyl(m, 0.025, 0.025, 0.08, Vector3(0.62 - i * 0.22, 1.98, 1.85), Vector3.ZERO, "steel", null, 6, false)
	k._box(m, Vector3(0.5, 0.06, 0.06), Vector3(0.5, 1.7, 1.85), "gunmetal_w", null, Vector3.ZERO, false)
	# the davit: a post in the corner, a boom swung out over the tailgate
	var post := Vector3(0.7, 0.98, 2.32)
	var yc := Color(0.55, 0.45, 0.16)
	k._cyl(m, 0.05, 0.06, 0.82, post + Vector3(0, 0.41, 0), Vector3.ZERO, "paint", yc, 10)
	_strut(k, m, post + Vector3(0, 0.78, 0), post + Vector3(-0.35, 0.86, 0.5), 0.07, 0.08, "paint", yc)
	_strut(k, m, post + Vector3(0, 0.45, 0), post + Vector3(-0.2, 0.8, 0.28), 0.04, 0.04, "paint", yc)
	k._cyl(m, 0.05, 0.05, 0.08, post + Vector3(0.0, 0.55, 0.07), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	_rod(k, m, post + Vector3(-0.35, 0.84, 0.5), post + Vector3(-0.35, 0.5, 0.5), 0.008, "gunmetal_w", null, 4, false)
	k._box(m, Vector3(0.04, 0.08, 0.03), post + Vector3(-0.35, 0.46, 0.5), "gunmetal_w")
	# beacon on the roof
	k._box(m, Vector3(0.5, 0.05, 0.16), Vector3(0, 1.815, 0.0), "plain", TRIM)
	k._cyl(m, 0.07, 0.08, 0.1, Vector3(0, 1.88, 0.0), Vector3.ZERO, "paint", AMBER, 10, false)
	_team_side(k, team)


## The irregulars' recognition panel on the doors.
static func _team_side(k: VehicleModels, team: int, x := 0.895, y := 0.82, z := -0.35) -> void:
	k._team_mark(k.root, team, Vector3(x, y, z), Vector3(0.02, 0.18, 0.4))
	k._team_mark(k.root, team, Vector3(-x, y, z), Vector3(0.02, 0.18, 0.4))


# --- MB 4WD -----------------------------------------------------------------------

## MB 4WD: a two-door Jeep Wrangler (JK) - the flat face with its seven-slot
## grille and round headlights, a flat bonnet between flat-topped wings with
## squared flares, an upright windscreen frame, a tub with exposed door
## hinges, the spare on the tailgate and a sport bar inside. The plain one has
## a soft top; the technicals ride open with a gun on a pintle over the rear:
## "lmg" an LIM-85, "at" an SPG-9.
static func _mb4wd(k: VehicleModels, team: int, seed: int, v: String) -> void:
	var m := k.root
	var col := _paint(seed, 23 + v.length(), v != "")
	var hw := 0.84
	var zf := -1.22
	var zr := 1.2
	var wr := 0.39
	var ar := 0.5
	var bar := Color(0.1, 0.1, 0.1)
	# frame, wells, axles (solid beam axles front and rear), the skid plate
	k._box(m, Vector3(0.86, 0.18, 3.9), Vector3(0, 0.5, 0.0), "gunmetal_w")
	for z in [zf, zr]:
		k._box(m, Vector3(1.2, 0.5, 0.95), Vector3(0, 0.7, z), "plain_dark")
		k._cyl(m, 0.06, 0.06, 1.3, Vector3(0, wr, z), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
		k._add(m, Res.sphere(0.13, 10), "gunmetal_w", null, Vector3(0.1, wr, z), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	k._box(m, Vector3(0.7, 0.05, 0.9), Vector3(0, 0.36, -0.5), "gunmetal_w")
	k._cyl(m, 0.035, 0.035, 2.4, Vector3(-0.35, 0.36, 0.6), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	# the tub: a floor pan with the arches cut out, walls standing on it
	_xbody(k, m, "civ_mb_tub", [-0.84, 0.58, 1.98, 0.58, 1.98, 0.97, -0.84, 0.97], -hw, hw, 0.035, [[zf, wr, ar], [zr, wr, ar]], "car_paint", col, 5)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.07, 0.25, 2.82), Vector3(s * (hw - 0.033), 1.06, 0.57), "car_paint", col)
	k._box(m, Vector3(hw * 2.0 + 0.004, 0.25, 0.08), Vector3(0, 1.06, 1.94), "car_paint", col)
	k._box(m, Vector3(hw * 2.0, 0.3, 0.16), Vector3(0, 1.07, -0.78), "car_paint", col)
	# bonnet over a narrow engine bay, then the flat-topped wings with flares
	k._box(m, Vector3(1.2, 0.36, 1.1), Vector3(0, 0.78, -1.4), "plain_dark")
	_xbody(k, m, "civ_mb_bonnet", [-1.96, 0.9, -0.84, 0.9, -0.84, 1.17, -1.96, 1.12], -0.71, 0.71, 0.03, [], "car_paint", col)
	for s in [-1.0, 1.0]:
		var x0 := 0.6 if s > 0 else -0.95
		_xbody(k, m, "civ_mb_wing%d" % int(s), [-2.0, 0.76, -1.9, 0.68, -0.84, 0.6, -0.84, 1.06, -1.98, 1.06], x0, x0 + 0.35, 0.03, [[zf, wr, ar]], "car_paint", col, 5)
		_flare(k, m, "civ_mb_ff%d" % int(s), zf, wr, ar - 0.01, ar + 0.07, s * 0.92 - 0.04, s * 0.92 + 0.05, 0.3, PI - 0.15, "plain", TRIM, 5)
		_flare(k, m, "civ_mb_fr%d" % int(s), zr, wr, ar - 0.01, ar + 0.07, s * hw - 0.03, s * hw + 0.05, 0.38, PI - 0.38, "plain", TRIM, 5)
		for z in [zf, zr]:
			k._wheel(m, Vector3(s * 0.79, wr, z), wr, 0.29, "gunmetal_w", Color(0.25, 0.25, 0.24))
		# hood latches, indicator on the wing, exposed hinges, the door's
		# shut lines and handle, a black mirror, rock rails
		k._box(m, Vector3(0.05, 0.05, 0.1), Vector3(s * 0.69, 1.14, -1.8), "plain", TRIM)
		_lamp(k, m, Vector3(0.1, 0.04, 0.12), Vector3(s * 0.8, 1.065, -1.88), AMBER)
		for y in [0.75, 1.06]:
			k._box(m, Vector3(0.03, 0.08, 0.1), Vector3(s * (hw + 0.012), y, -0.78), "plain", TRIM)
		for z in [-0.82, 0.3]:
			k._box(m, Vector3(0.012, 0.6, 0.012), Vector3(s * (hw + 0.006), 0.88, z), "plain_dark", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.012, 0.012, 1.1), Vector3(s * (hw + 0.006), 1.175, -0.26), "plain_dark", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.025, 0.04, 0.12), Vector3(s * (hw + 0.01), 1.08, 0.18), "plain", TRIM, Vector3.ZERO, false)
		_mirror(k, m, s, Vector3(s * 0.85, 1.12, -0.72), 0.12, Vector3(0.05, 0.16, 0.14), "plain", TRIM)
		_rod(k, m, Vector3(s * 0.8, 0.5, -0.75), Vector3(s * 0.8, 0.5, 0.65), 0.04, "plain", TRIM, 8)
		# square tail lights on the rear corners
		_lamp(k, m, Vector3(0.12, 0.26, 0.04), Vector3(s * 0.74, 0.98, 1.99), TAIL)
		_lamp(k, m, Vector3(0.12, 0.06, 0.04), Vector3(s * 0.74, 0.82, 1.99), AMBER)
	# the face: seven slots between round headlights, bumper with tow hooks
	var slope := 0.06 / 0.48
	var gp := VehicleModels._v2([-0.68, 0.62, 0.68, 0.62, 0.7, 0.68, 0.7, 1.08, -0.7, 1.08, -0.7, 0.68])
	k._add(m, VehicleModels.solid([_zring(gp, -1.92, slope, 0.62), _zring(gp, -1.97, slope, 0.62)], "civ_mb_grille"), "car_paint", col, Vector3.ZERO)
	for i in 7:
		var x := -0.3 + i * 0.1
		k._box(m, Vector3(0.06, 0.36, 0.04), Vector3(x, 0.86, -1.97 + 0.24 * slope - 0.006), "plain", Color(0.04, 0.04, 0.04), Vector3(slope, 0, 0), false)
	for s in [-1.0, 1.0]:
		var hp := Vector3(s * 0.5, 0.88, -1.975 + 0.26 * slope)
		k._cyl(m, 0.125, 0.125, 0.04, hp, Vector3(PI / 2 + slope, 0, 0), "plain", TRIM, 16)
		k._cyl(m, 0.1, 0.1, 0.04, hp + Vector3(0, 0, -0.012), Vector3(PI / 2 + slope, 0, 0), "paint", LENS, 16, false)
		k._cyl(m, 0.04, 0.04, 0.04, hp + Vector3(0, 0, -0.02), Vector3(PI / 2 + slope, 0, 0), "paint", HEAD, 10, false)
		_lamp(k, m, Vector3(0.1, 0.05, 0.03), Vector3(s * 0.5, 0.69, -1.97), AMBER)
		k._box(m, Vector3(0.06, 0.08, 0.1), Vector3(s * 0.5, 0.56, -2.07), "paint", Color(0.45, 0.08, 0.06))
	k._box(m, Vector3(1.86, 0.18, 0.16), Vector3(0, 0.6, -1.99), "plain", bar)
	_plate(k, m, Vector3(0, 0.6, -2.075), false)
	# windscreen: an upright frame folding on the cowl, wipers
	var wlo := Vector3(0, 1.17, -0.8)
	var whi := Vector3(0, 1.72, -0.53)
	for s in [-1.0, 1.0]:
		_strut(k, m, wlo + Vector3(s * 0.73, 0, 0), whi + Vector3(s * 0.73, 0, 0), 0.07, 0.06, "car_paint", col)
		k._box(m, Vector3(0.05, 0.06, 0.08), wlo + Vector3(s * 0.66, 0.0, 0.06), "plain", TRIM)
	_strut(k, m, wlo + Vector3(-0.76, 0.02, 0), wlo + Vector3(0.76, 0.02, 0), 0.07, 0.06, "car_paint", col)
	_strut(k, m, whi + Vector3(-0.76, 0, 0), whi + Vector3(0.76, 0, 0), 0.08, 0.06, "car_paint", col)
	var wc := [wlo + Vector3(-0.7, 0.03, 0), wlo + Vector3(0.7, 0.03, 0), whi + Vector3(0.7, -0.03, 0), whi + Vector3(-0.7, -0.03, 0)]
	_pane(k, m, "civ_mb_ws", wc, Vector3(0, 1.4, 0.0), 0.0, 1.0, 0.0, 1.0, -0.01, 0.012, "glass")
	for x in [-0.36, 0.2]:
		k._box(m, Vector3(0.45, 0.012, 0.025), Vector3(x, 1.24, -0.84), "gunmetal_w", null, Vector3(-0.6, 0, 0.1), false)
	_rod(k, m, Vector3(0.8, 1.07, -1.0), Vector3(0.8, 1.95, -0.85), 0.006, "gunmetal_w", null, 4, false)
	# inside: dash, the wheel (left-hand drive), two buckets and a bench
	k._box(m, Vector3(1.5, 0.16, 0.24), Vector3(0, 1.2, -0.62), "plain", TRIM)
	k._add(m, Res.torus(0.16, 0.19), "plain", TRIM, Vector3(-0.38, 1.33, -0.42), Vector3(1.1, 0, 0))
	_rod(k, m, Vector3(-0.38, 1.33, -0.42), Vector3(-0.38, 1.22, -0.6), 0.025, "plain", TRIM, 6)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.5, 0.12, 0.5), Vector3(s * 0.38, 1.04, -0.08), "plain", Color(0.16, 0.16, 0.15))
		k._box(m, Vector3(0.48, 0.62, 0.12), Vector3(s * 0.38, 1.34, 0.2), "plain", Color(0.16, 0.16, 0.15), Vector3(-0.18, 0, 0))
		k._box(m, Vector3(0.26, 0.14, 0.09), Vector3(s * 0.38, 1.72, 0.27), "plain", Color(0.16, 0.16, 0.15), Vector3(-0.18, 0, 0))
	k._box(m, Vector3(1.4, 0.12, 0.45), Vector3(0, 1.04, 0.95), "plain", Color(0.16, 0.16, 0.15))
	k._box(m, Vector3(1.4, 0.5, 0.12), Vector3(0, 1.3, 1.2), "plain", Color(0.16, 0.16, 0.15), Vector3(-0.12, 0, 0))
	# the sport bar: a hoop behind the front seats, rails to the windscreen
	# and down to the rear corners, padded
	var bt := 1.76
	for s in [-1.0, 1.0]:
		_bent(k, m, [Vector3(s * 0.72, 1.0, 0.42), Vector3(s * 0.72, bt, 0.38), Vector3(s * 0.72, bt, -0.5)], 0.04, "plain", bar, 8)
		_bent(k, m, [Vector3(s * 0.72, bt, 0.38), Vector3(s * 0.72, bt, 1.4), Vector3(s * 0.72, 1.0, 1.84)], 0.035, "plain", bar, 8)
		_rod(k, m, Vector3(s * 0.72, 1.45, 0.4), Vector3(s * 0.72, 1.2, 1.7), 0.03, "plain", bar, 6)
	_rod(k, m, Vector3(-0.72, bt, 0.38), Vector3(0.72, bt, 0.38), 0.04, "plain", bar, 8)
	# rear: spare wheel on the tailgate, bumper, plate, third light
	_spare(k, m, Vector3(0, 1.08, 2.11), wr, 0.27, Vector3(PI / 2, 0, 0), "gunmetal_w", Color(0.25, 0.25, 0.24))
	k._box(m, Vector3(0.2, 0.2, 0.12), Vector3(0, 1.08, 2.02), "gunmetal_w")
	k._box(m, Vector3(1.8, 0.16, 0.14), Vector3(0, 0.58, 2.03), "plain", bar)
	_plate(k, m, Vector3(-0.55, 0.85, 1.985), true)
	k._box(m, Vector3(0.04, 0.06, 0.1), Vector3(0.0, 0.48, 2.08), "gunmetal_w")
	k._cyl(m, 0.06, 0.06, 0.02, Vector3(-hw - 0.01, 0.9, 1.6), Vector3(0, 0, PI / 2), "plain", TRIM, 10, false)
	match v:
		"lmg", "at":
			_mb_gun(k, team, v == "at")
		_:
			_mb_top(k)


## The plain MB 4WD's soft top: dark canvas over the bars, clear side and rear curtains.
static func _mb_top(k: VehicleModels) -> void:
	var m := k.root
	var lo := _ring([-0.83, -0.52, 0.83, -0.52, 0.83, 1.97, -0.83, 1.97], 1.12)
	var hi := _ring([-0.78, -0.5, 0.78, -0.5, 0.78, 1.9, -0.78, 1.9], 1.82)
	_yloft(k, m, "civ_mb_top", [[-0.83, -0.52, 0.83, -0.52, 0.83, 1.97, -0.83, 1.97], [-0.78, -0.5, 0.78, -0.5, 0.78, 1.9, -0.78, 1.9]], [1.12, 1.82], 0.05, "canvas", Color(0.13, 0.13, 0.12))
	var inside := Vector3(0, 1.4, 0.7)
	_pane(k, m, "civ_mb_topr", _face(lo, hi, 2), inside, 0.12, 0.88, 0.28, 0.85, 0.0, 0.01, "glass")
	_pane(k, m, "civ_mb_topsr", _face(lo, hi, 1), inside, 0.05, 0.4, 0.22, 0.85, 0.0, 0.01, "glass")
	_pane(k, m, "civ_mb_topsr2", _face(lo, hi, 1), inside, 0.48, 0.92, 0.22, 0.85, 0.0, 0.01, "glass")
	_pane(k, m, "civ_mb_topsl", _face(lo, hi, 3), inside, 0.6, 0.95, 0.22, 0.85, 0.0, 0.01, "glass")
	_pane(k, m, "civ_mb_topsl2", _face(lo, hi, 3), inside, 0.08, 0.52, 0.22, 0.85, 0.0, 0.01, "glass")
	# the door frames the curtains zip into, the bows under the roof
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.02, 0.62, 0.03), Vector3(s * 0.815, 1.47, 0.3), "plain", TRIM, Vector3(0, 0, -s * 0.07), false)
	for z in [0.35, 1.15]:
		k._box(m, Vector3(1.5, 0.025, 0.06), Vector3(0, 1.826, z), "canvas", Color(0.11, 0.11, 0.1), Vector3.ZERO, false)


## The technical's pintle on a bar across the sport bar, with the gun.
static func _mb_gun(k: VehicleModels, team: int, at: bool) -> void:
	var m := k.root
	_rod(k, m, Vector3(-0.72, 1.76, 1.15), Vector3(0.72, 1.76, 1.15), 0.035, "gunmetal_w", null, 8)
	k._box(m, Vector3(0.2, 0.1, 0.12), Vector3(0, 1.76, 1.15), "gunmetal_w")
	k._cyl(m, 0.045, 0.05, 0.16, Vector3(0, 1.86, 1.15), Vector3.ZERO, "gunmetal_w", null, 8)
	# ammunition stowed in the back
	for i in 2:
		k._box(m, Vector3(0.14, 0.19, 0.3), Vector3(0.45 - i * 0.17, 1.08, 1.6), "paint", OD)
	k.turret = k._pivot(m, Vector3(0, 1.94, 1.15))
	var t := k.turret
	k._cyl(t, 0.035, 0.035, 0.12, Vector3(0, 0.03, 0), Vector3.ZERO, "gunmetal_w", null, 8)
	if at:
		k._box(t, Vector3(0.16, 0.12, 0.12), Vector3(0, 0.1, 0), "paint", OD)
		var tip := _spg9(k, t, 0.27)
		k.gun_tip = k._tip(t, tip)
		k.mg_tip = k.gun_tip
	else:
		k._box(t, Vector3(0.05, 0.12, 0.08), Vector3(0, 0.08, 0), "gunmetal_w")
		var tip := _lmg(k, t, 0.17)
		k.mg_tip = k._tip(t, tip)
	_team_side(k, team, 0.85, 0.82, -0.3)


# --- Truck ------------------------------------------------------------------------

## Truck: an Iveco Daily 4x4 - a tall, narrow forward-control cab perched over
## the front axle behind a short sloping nose, a heavy bumper, big single
## tyres all round. "" a dropside bed with benches for a fighter cell, "box"
## a box body.
static func _truck(k: VehicleModels, team: int, seed: int, v: String) -> void:
	var m := k.root
	var col := _paint(seed, 37 + v.length(), true)
	var hw := 1.0
	var zf := -1.75
	var zr := 1.65
	var wr := 0.46
	var ar := 0.56
	var dark := Color(0.14, 0.14, 0.14)
	# ladder frame, beam axles with their diffs, fuel tank, battery box
	k._box(m, Vector3(0.9, 0.22, 5.3), Vector3(0, 0.88, 0.05), "gunmetal_w")
	k._box(m, Vector3(1.3, 0.5, 1.05), Vector3(0, 1.0, zf), "plain_dark")
	for z in [zf, zr]:
		k._cyl(m, 0.07, 0.07, 1.5, Vector3(0, wr, z), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
		k._add(m, Res.sphere(0.17, 10), "gunmetal_w", null, Vector3(0.12, wr, z), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
		_rod(k, m, Vector3(-0.42, wr + 0.05, z), Vector3(-0.42, 0.85, z), 0.05, "gunmetal_w", null, 6)
		_rod(k, m, Vector3(0.42, wr + 0.05, z), Vector3(0.42, 0.85, z), 0.05, "gunmetal_w", null, 6)
	k._cyl(m, 0.21, 0.21, 0.95, Vector3(-0.7, 0.82, -0.35), Vector3(PI / 2, 0, 0), "steel", Color(0.45, 0.45, 0.44), 14)
	k._box(m, Vector3(0.3, 0.32, 0.55), Vector3(0.72, 0.82, -0.35), "gunmetal_w")
	k._cyl(m, 0.05, 0.05, 1.4, Vector3(0.55, 0.62, 0.6), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8, false)
	# the cab over the front wheels, the short nose in front of it
	_xbody(k, m, "civ_tr_cab", [-2.3, 0.88, -1.1, 0.88, -1.1, 2.66, -1.9, 2.68, -2.3, 1.8], -hw, hw, 0.06, [[zf, wr, ar]], "car_paint", col)
	_xbody(k, m, "civ_tr_nose", [-2.8, 0.95, -2.27, 0.95, -2.27, 1.8, -2.68, 1.64, -2.8, 1.3], -0.97, 0.97, 0.05, [[zf, wr, ar]], "car_paint", col, 8, [0.3, 0.1, 0.0, 0.0])
	var inside := Vector3(0, 1.8, -1.7)
	var ws := [Vector3(-hw, 1.8, -2.3), Vector3(hw, 1.8, -2.3), Vector3(hw, 2.68, -1.9), Vector3(-hw, 2.68, -1.9)]
	_pane(k, m, "civ_tr_ws", ws, inside, 0.05, 0.95, 0.05, 0.9, 0.0, 0.012, "glass")
	k._box(m, Vector3(1.4, 0.4, 0.02), Vector3(0, 2.2, -1.095), "glass", null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		var sw := [Vector3(s * hw, 1.86, -2.19), Vector3(s * hw, 1.86, -1.28), Vector3(s * hw, 2.5, -1.28), Vector3(s * hw, 2.5, -1.9)]
		_pane(k, m, "civ_tr_sw%d" % int(s), sw, inside, 0.0, 1.0, 0.0, 1.0, 0.0, 0.012, "glass")
		# shut lines, handle, the steps behind the wheel, mirrors on long arms
		k._box(m, Vector3(0.012, 1.55, 0.012), Vector3(s * (hw + 0.005), 1.75, -1.2), "plain_dark", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.012, 0.012, 0.95), Vector3(s * (hw + 0.005), 1.04, -1.68), "plain_dark", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.03, 0.04, 0.16), Vector3(s * (hw + 0.012), 1.72, -1.4), "plain", TRIM, Vector3.ZERO, false)
		for y in [0.5, 0.78]:
			k._box(m, Vector3(0.3, 0.04, 0.2), Vector3(s * 0.86, y, -1.12), "steel", Color(0.4, 0.4, 0.4))
		k._box(m, Vector3(0.04, 0.45, 0.04), Vector3(s * 0.99, 0.66, -1.04), "gunmetal_w")
		_strut(k, m, Vector3(s * 0.98, 2.3, -2.05), Vector3(s * 1.2, 2.25, -2.05), 0.04, 0.04, "plain", TRIM)
		_strut(k, m, Vector3(s * 0.98, 1.9, -2.15), Vector3(s * 1.2, 1.95, -2.05), 0.04, 0.04, "plain", TRIM)
		k._box(m, Vector3(0.06, 0.42, 0.2), Vector3(s * 1.22, 2.1, -2.05), "plain", TRIM)
		# black flares on the front arch, mudflaps
		_flare(k, m, "civ_tr_ff%d" % int(s), zf, wr, ar - 0.01, ar + 0.06, s * hw - 0.03, s * hw + 0.05, 0.3, PI - 0.25, "plain", TRIM, 7)
		k._box(m, Vector3(0.3, 0.4, 0.02), Vector3(s * 0.86, 0.42, zr + 0.62), "rubber")
		for z in [zf, zr]:
			k._wheel(m, Vector3(s * 0.86, wr, z), wr, 0.32, "paint", Color(0.42, 0.43, 0.42))
		# the rear wheel's mudguard under the bed
		_flare(k, m, "civ_tr_fr%d" % int(s), zr, wr, wr + 0.06, wr + 0.1, s * 0.86 - 0.19, s * 0.86 + 0.19, 0.15, PI - 0.15, "plain", TRIM, 6)
		# headlights in the nose corners, indicators, roof markers
		k._box(m, Vector3(0.4, 0.2, 0.06), Vector3(s * 0.67, 1.48, -2.75), "gunmetal_w", null, Vector3(0.34, s * 0.12, 0))
		_lamp(k, m, Vector3(0.34, 0.15, 0.02), Vector3(s * 0.67, 1.49, -2.785), LENS, Vector3(0.34, s * 0.12, 0))
		_lamp(k, m, Vector3(0.1, 0.1, 0.02), Vector3(s * 0.6, 1.49, -2.8), HEAD, Vector3(0.34, s * 0.12, 0))
		_lamp(k, m, Vector3(0.06, 0.06, 0.1), Vector3(s * 0.94, 1.46, -2.62), AMBER, Vector3(0, s * 0.5, 0))
		_lamp(k, m, Vector3(0.12, 0.06, 0.08), Vector3(s * 0.55, 2.7, -1.95), AMBER)
	_lamp(k, m, Vector3(0.12, 0.06, 0.08), Vector3(0, 2.7, -1.95), AMBER)
	# grille between the lamps, the 4x4's steel bumper with a winch, plate
	var slope := 0.12 / 0.34
	for i in 4:
		var y := 1.36 + i * 0.075
		k._box(m, Vector3(0.62, 0.04, 0.03), Vector3(0, y, -2.8 + (y - 1.3) * slope - 0.015), "plain", dark, Vector3(slope, 0, 0), false)
	k._box(m, Vector3(0.7, 0.3, 0.02), Vector3(0, 1.47, -2.8 + 0.17 * slope - 0.002), "plain", Color(0.06, 0.06, 0.06), Vector3(slope, 0, 0), false)
	k._box(m, Vector3(2.04, 0.3, 0.18), Vector3(0, 1.08, -2.86), "steel", Color(0.3, 0.3, 0.3))
	k._box(m, Vector3(0.6, 0.24, 0.2), Vector3(0, 0.84, -2.82), "gunmetal_w")
	k._cyl(m, 0.08, 0.08, 0.5, Vector3(0, 0.84, -2.9), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10)
	k._box(m, Vector3(0.12, 0.08, 0.06), Vector3(0, 0.84, -3.0), "steel", Color(0.5, 0.5, 0.5))
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.08, 0.1, 0.12), Vector3(s * 0.7, 0.88, -2.95), "paint", Color(0.5, 0.1, 0.07))
		k._cyl(m, 0.05, 0.05, 0.03, Vector3(s * 0.75, 1.1, -2.96), Vector3(PI / 2, 0, 0), "paint", HEAD, 10, false)
	_plate(k, m, Vector3(0, 1.1, -2.96), false)
	_rod(k, m, Vector3(-0.95, 2.6, -1.4), Vector3(-0.95, 3.4, -1.3), 0.007, "gunmetal_w", null, 4, false)
	if v == "box":
		_truck_box(k, team)
	else:
		_truck_bed(k, team)


## The dropside bed: an aluminium-sided deck, a headboard with a cab guard,
## benches down both sides for the fighters.
static func _truck_bed(k: VehicleModels, team: int) -> void:
	var m := k.root
	var al := Color(0.62, 0.63, 0.62)
	k._box(m, Vector3(0.95, 0.14, 3.8), Vector3(0, 1.08, 0.9), "gunmetal_w")
	k._box(m, Vector3(2.1, 0.1, 3.82), Vector3(0, 1.2, 0.9), "wood_dark")
	k._box(m, Vector3(2.12, 0.06, 3.84), Vector3(0, 1.14, 0.9), "paint", al)
	# headboard and a cab guard of bars
	k._box(m, Vector3(2.1, 0.5, 0.06), Vector3(0, 1.5, -0.98), "paint", al)
	for x in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		k._box(m, Vector3(0.05, 0.75, 0.05), Vector3(x, 2.12, -0.98), "paint", al)
	k._box(m, Vector3(2.06, 0.06, 0.06), Vector3(0, 2.48, -0.98), "paint", al)
	k._box(m, Vector3(2.06, 0.04, 0.04), Vector3(0, 2.1, -0.98), "paint", al, Vector3.ZERO, false)
	# dropsides on stake posts, the tailgate; their hinges and catches
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.42, 3.78), Vector3(s * 1.03, 1.46, 0.9), "paint", al)
		k._box(m, Vector3(0.06, 0.05, 3.8), Vector3(s * 1.035, 1.68, 0.9), "paint", al.darkened(0.1))
		for z in [-0.95, 0.9, 2.77]:
			k._box(m, Vector3(0.07, 0.5, 0.07), Vector3(s * 1.04, 1.45, z), "paint", al.darkened(0.15))
		for z in [-0.1, 1.9]:
			k._box(m, Vector3(0.03, 0.06, 0.1), Vector3(s * 1.06, 1.6, z), "gunmetal_w", null, Vector3.ZERO, false)
		# a bench with a back along the side
		k._box(m, Vector3(0.32, 0.05, 3.3), Vector3(s * 0.8, 1.6, 0.95), "wood")
		for z in [-0.6, 0.95, 2.5]:
			k._box(m, Vector3(0.04, 0.36, 0.04), Vector3(s * 0.75, 1.42, z), "gunmetal_w")
		k._box(m, Vector3(0.04, 0.14, 3.3), Vector3(s * 0.99, 1.84, 0.95), "wood")
	k._box(m, Vector3(2.04, 0.42, 0.05), Vector3(0, 1.46, 2.79), "paint", al)
	k._box(m, Vector3(2.06, 0.05, 0.06), Vector3(0, 1.68, 2.8), "paint", al.darkened(0.1))
	_truck_rear(k, 2.82)
	k._team_mark(m, team, Vector3(1.06, 1.46, 0.9), Vector3(0.02, 0.24, 0.6))
	k._team_mark(m, team, Vector3(-1.06, 1.46, 0.9), Vector3(0.02, 0.24, 0.6))


## The box body: a plain van box on the chassis, ribbed, barn doors at the back.
static func _truck_box(k: VehicleModels, team: int) -> void:
	var m := k.root
	var bc := Color(0.74, 0.73, 0.69)
	k._box(m, Vector3(0.95, 0.14, 3.8), Vector3(0, 1.08, 0.9), "gunmetal_w")
	_xbody(k, m, "civ_tr_box", [-0.98, 1.16, 2.82, 1.16, 2.82, 2.8, -0.98, 2.8], -1.05, 1.05, 0.04, [], "paint", bc)
	for s in [-1.0, 1.0]:
		for z in [-0.1, 0.9, 1.9]:
			k._box(m, Vector3(0.025, 1.6, 0.06), Vector3(s * 1.058, 1.98, z), "paint", bc.darkened(0.08))
		k._box(m, Vector3(0.03, 0.1, 3.8), Vector3(s * 1.06, 1.2, 0.92), "steel", Color(0.5, 0.5, 0.5))
		k._box(m, Vector3(0.03, 0.06, 3.8), Vector3(s * 1.06, 2.77, 0.92), "steel", Color(0.5, 0.5, 0.5))
		_lamp(k, m, Vector3(0.03, 0.05, 0.08), Vector3(s * 1.07, 1.3, 0.4), AMBER)
		_lamp(k, m, Vector3(0.03, 0.05, 0.08), Vector3(s * 1.07, 1.3, 1.9), AMBER)
		# barn doors: their seam, hinges and the locking bars
		for x in [0.3, 0.8]:
			k._cyl(m, 0.018, 0.018, 1.5, Vector3(s * x, 1.98, 2.835), Vector3.ZERO, "steel", null, 6, false)
			k._box(m, Vector3(0.06, 0.12, 0.04), Vector3(s * x, 1.75, 2.85), "gunmetal_w", null, Vector3.ZERO, false)
		for y in [1.4, 2.0, 2.6]:
			k._box(m, Vector3(0.12, 0.06, 0.03), Vector3(s * 0.98, y, 2.835), "gunmetal_w", null, Vector3.ZERO, false)
		_lamp(k, m, Vector3(0.06, 0.06, 0.03), Vector3(s * 0.95, 2.74, 2.83), TAIL)
	k._box(m, Vector3(0.012, 1.6, 0.02), Vector3(0, 1.98, 2.83), "plain_dark", null, Vector3.ZERO, false)
	# the wind deflector over the cab
	k._box(m, Vector3(1.9, 0.12, 0.3), Vector3(0, 2.74, -1.2), "plain", TRIM, Vector3(-0.3, 0, 0))
	_truck_rear(k, 2.84)
	k._team_mark(m, team, Vector3(1.072, 2.0, 0.4), Vector3(0.02, 0.3, 0.7))
	k._team_mark(m, team, Vector3(-1.072, 2.0, 0.4), Vector3(0.02, 0.3, 0.7))


## Tail lights, plate and the underrun bar at the back of the truck.
static func _truck_rear(k: VehicleModels, z: float) -> void:
	var m := k.root
	k._box(m, Vector3(1.9, 0.12, 0.1), Vector3(0, 0.98, z - 0.05), "gunmetal_w")
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.36, 0.14, 0.06), Vector3(s * 0.75, 0.98, z + 0.0), "plain", TRIM)
		_lamp(k, m, Vector3(0.14, 0.1, 0.03), Vector3(s * 0.84, 0.98, z + 0.035), TAIL)
		_lamp(k, m, Vector3(0.08, 0.1, 0.03), Vector3(s * 0.7, 0.98, z + 0.035), AMBER)
		_lamp(k, m, Vector3(0.06, 0.1, 0.03), Vector3(s * 0.61, 0.98, z + 0.035), HEAD)
		k._box(m, Vector3(0.06, 0.4, 0.06), Vector3(s * 0.7, 0.68, z - 0.2), "gunmetal_w")
	k._box(m, Vector3(1.8, 0.1, 0.08), Vector3(0, 0.5, z - 0.18), "steel", Color(0.4, 0.4, 0.4))
	_plate(k, m, Vector3(0, 0.8, z - 0.1), true)
	k._box(m, Vector3(0.15, 0.1, 0.18), Vector3(0, 0.78, z - 0.2), "gunmetal_w")


# --- Van --------------------------------------------------------------------------

## Van: a Mercedes-Benz Sprinter (NCV3) with the high roof - the short
## sloping bonnet with its three-slat grille and big swept headlights, a
## steep windscreen, the high roof rising behind it, a sliding side door and
## rear barn doors. "transport" a minibus with windows all round; "ambulance"
## white with red bands, crosses and a light bar; "services" a utility van in
## safety orange with a ladder on the roof rack.
static func _van(k: VehicleModels, team: int, seed: int, v: String) -> void:
	var m := k.root
	var amb := v == "ambulance"
	var srv := v == "services"
	var col := Color(0.8, 0.79, 0.76) if amb else (Color(0.72, 0.44, 0.15) if srv else _paint(seed, 41, false))
	var hw := 0.99
	var zf := -1.98
	var zr := 1.69
	var wr := 0.35
	var ar := 0.43
	k._box(m, Vector3(1.1, 0.2, 5.3), Vector3(0, 0.42, 0.0), "gunmetal_w")
	for z in [zf, zr]:
		k._box(m, Vector3(1.3, 0.42, 0.85), Vector3(0, 0.55, z), "plain_dark")
	k._cyl(m, 0.06, 0.06, 1.4, Vector3(0, wr, zr), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
	k._add(m, Res.sphere(0.14, 10), "gunmetal_w", null, Vector3(0.0, wr, zr), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	k._cyl(m, 0.035, 0.035, 2.0, Vector3(-0.5, 0.3, 1.9), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	# the bonnet, and the body with the windscreen and the high roof
	_xbody(k, m, "civ_van_nose", [-2.92, 0.36, -2.05, 0.36, -2.05, 1.28, -2.62, 1.11, -2.86, 0.97, -2.96, 0.7], -hw, hw, 0.05, [[zf, wr, ar]], "car_paint", col, 8, [0.5, 0.17, 0.0, 0.0])
	_xbody(k, m, "civ_van_body", [-2.1, 0.36, 2.95, 0.36, 2.95, 2.5, 2.88, 2.6, -0.6, 2.6, -1.0, 2.56, -1.42, 2.15, -2.08, 1.29, -2.1, 1.25],
		-hw, hw, 0.07, [[zf, wr, ar], [zr, wr, ar]], "car_paint", col, 8, [0.0, 0.0, 0.1, 0.04])
	var inside := Vector3(0, 1.4, 0.0)
	var ws := [Vector3(-hw, 1.29, -2.08), Vector3(hw, 1.29, -2.08), Vector3(hw, 2.15, -1.42), Vector3(-hw, 2.15, -1.42)]
	_pane(k, m, "civ_van_ws", ws, inside, 0.05, 0.95, 0.05, 0.94, 0.0, 0.012, "glass")
	# windows: the cab doors always; the rest on the minibus, rear doors on all
	var wins := [[-1.95, -1.3]]
	if v == "transport":
		wins.append_array([[-1.05, 0.3], [0.5, 1.45], [1.65, 2.75]])
	for s in [-1.0, 1.0]:
		for w in wins:
			var za: float = w[0]
			var zb: float = w[1]
			var zt := za + (0.5 if za < -1.5 else 0.0)
			if s < 0.0 and za > -1.1 and za < 0.0:
				za = -1.15
			var c := [Vector3(s * hw, 1.38, za), Vector3(s * hw, 1.38, zb), Vector3(s * hw, 2.02, zb), Vector3(s * hw, 2.02, zt)]
			_pane(k, m, "civ_van_w%d_%d" % [int(s), int(za * 10)], c, inside, 0.0, 1.0, 0.0, 1.0, 0.0, 0.012, "glass")
		# shut lines: cab door, and on the right the sliding door with its rail
		k._box(m, Vector3(0.012, 1.7, 0.012), Vector3(s * (hw + 0.004), 1.2, -1.2), "plain_dark", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.03, 0.04, 0.16), Vector3(s * (hw + 0.012), 1.22, -1.36), "plain", TRIM, Vector3.ZERO, false)
		_mirror(k, m, s, Vector3(s * 0.96, 1.45, -1.95), 0.12, Vector3(0.08, 0.32, 0.18), "plain", TRIM)
		# a black rubbing strip, the flares' lips, the tall tail lights
		k._box(m, Vector3(0.02, 0.12, 4.8), Vector3(s * (hw + 0.006), 0.5, 0.05), "plain", TRIM)
		for z in [zf, zr]:
			_flare(k, m, "civ_van_fl%d%d" % [int(s), int(z)], z, wr, ar - 0.01, ar + 0.035, s * hw - 0.03, s * hw + 0.02, 0.4, PI - 0.4, "plain", TRIM, 6)
			k._wheel(m, Vector3(s * 0.85, wr, z), wr, 0.235, "steel", Color(0.5, 0.51, 0.5))
		_lamp(k, m, Vector3(0.1, 0.5, 0.05), Vector3(s * (hw - 0.06), 0.82, 2.955), TAIL)
		_lamp(k, m, Vector3(0.1, 0.1, 0.05), Vector3(s * (hw - 0.06), 0.62, 2.96), AMBER)
		# rear doors: windows, hinges
		if not amb:
			k._box(m, Vector3(0.74, 0.62, 0.012), Vector3(s * 0.44, 1.88, 2.952), "glass", null, Vector3.ZERO, false)
		for y in [0.7, 2.2]:
			k._box(m, Vector3(0.05, 0.12, 0.04), Vector3(s * 0.93, y, 2.96), "gunmetal_w", null, Vector3.ZERO, false)
	for z in [-1.12, 0.38]:
		k._box(m, Vector3(0.012, 1.75, 0.012), Vector3(hw + 0.004, 1.22, z), "plain_dark", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.012, 0.03, 2.5), Vector3(hw + 0.004, 1.37, 1.65), "plain_dark", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.03, 0.04, 0.16), Vector3(hw + 0.012, 1.25, 0.25), "plain", TRIM, Vector3.ZERO, false)
	k._box(m, Vector3(0.012, 2.0, 0.02), Vector3(0, 1.45, 2.952), "plain_dark", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.14, 0.04, 0.03), Vector3(0.1, 1.28, 2.96), "plain", TRIM, Vector3.ZERO, false)
	_lamp(k, m, Vector3(0.3, 0.05, 0.04), Vector3(0, 2.56, 2.94), TAIL)
	# rear bumper with its step, plate
	k._box(m, Vector3(1.96, 0.2, 0.16), Vector3(0, 0.46, 2.98), "plain", TRIM)
	k._box(m, Vector3(0.8, 0.04, 0.2), Vector3(0, 0.57, 3.0), "plain", Color(0.18, 0.18, 0.18))
	_plate(k, m, Vector3(0, 0.75, 2.96), true)
	# the face: three slats and the star, big swept headlights, the bumper
	var slope := (2.86 - 2.96) / (0.97 - 0.7)
	for i in 3:
		var y := 0.76 + i * 0.07
		k._box(m, Vector3(0.62 - i * 0.04, 0.045, 0.03), Vector3(0, y, -2.96 - (y - 0.7) * slope - 0.012), "steel", Color(0.48, 0.49, 0.49), Vector3(-slope, 0, 0), false)
	k._box(m, Vector3(0.66, 0.24, 0.02), Vector3(0, 0.83, -2.96 - 0.13 * slope - 0.002), "plain", Color(0.06, 0.06, 0.06), Vector3(-slope, 0, 0), false)
	k._cyl(m, 0.06, 0.06, 0.03, Vector3(0, 0.83, -2.96 - 0.13 * slope - 0.03), Vector3(PI / 2 - slope, 0, 0), "steel", Color(0.6, 0.6, 0.6), 12, false)
	for s in [-1.0, 1.0]:
		# the big headlight: across the front corner and back along the wing
		var up := Vector3(0, 1, 0.37).normalized()
		_slab(k, m, Vector3(s * 0.42, 0.9, -2.9), Vector3(s * 0.8, 0.92, -2.885), 0.21, 0.05, "gunmetal_w", null, up)
		_slab(k, m, Vector3(s * 0.79, 0.92, -2.88), Vector3(s * 0.95, 0.98, -2.64), 0.21, 0.05, "gunmetal_w", null, up)
		_slab(k, m, Vector3(s * 0.44, 0.9, -2.915), Vector3(s * 0.79, 0.92, -2.9), 0.17, 0.03, "paint", LENS, up)
		_slab(k, m, Vector3(s * 0.81, 0.925, -2.89), Vector3(s * 0.96, 0.98, -2.66), 0.17, 0.03, "paint", LENS, up)
		_slab(k, m, Vector3(s * 0.5, 0.91, -2.925), Vector3(s * 0.6, 0.91, -2.92), 0.09, 0.03, "paint", HEAD, up)
		_slab(k, m, Vector3(s * 0.64, 0.92, -2.92), Vector3(s * 0.74, 0.92, -2.915), 0.09, 0.03, "paint", HEAD, up)
		_slab(k, m, Vector3(s * 0.88, 0.96, -2.8), Vector3(s * 0.95, 0.98, -2.68), 0.06, 0.035, "paint", AMBER, up)
		k._cyl(m, 0.045, 0.045, 0.03, Vector3(s * 0.7, 0.5, -3.0), Vector3(PI / 2, 0, 0), "paint", LENS, 10, false)
	k._box(m, Vector3(1.98, 0.34, 0.18), Vector3(0, 0.53, -2.92), "plain", TRIM)
	k._box(m, Vector3(0.9, 0.12, 0.03), Vector3(0, 0.47, -3.01), "gunmetal_w", null, Vector3.ZERO, false)
	_plate(k, m, Vector3(0, 0.62, -3.015), false)
	for x in [-0.3, 0.25]:
		k._box(m, Vector3(0.6, 0.012, 0.025), Vector3(x, 1.33, -2.07), "gunmetal_w", null, Vector3(-0.9, 0, 0.1), false)
	match v:
		"ambulance":
			_van_ambulance(k)
		"services":
			_van_services(k)
		_:
			k._team_mark(m, team, Vector3(hw + 0.01, 1.0, 1.2), Vector3(0.02, 0.2, 0.5))
			k._team_mark(m, team, Vector3(-hw - 0.01, 1.0, 1.2), Vector3(0.02, 0.2, 0.5))


## Red bands and crosses, a light bar over the cab and beacons at the back.
static func _van_ambulance(k: VehicleModels) -> void:
	var m := k.root
	var red := Color(0.62, 0.1, 0.08)
	var hw := 0.99
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.012, 0.18, 4.95), Vector3(s * (hw + 0.004), 1.06, 0.42), "paint", red, Vector3.ZERO, false)
		k._box(m, Vector3(0.012, 0.42, 0.13), Vector3(s * (hw + 0.004), 1.78, 1.05), "paint", red, Vector3.ZERO, false)
		k._box(m, Vector3(0.012, 0.13, 0.42), Vector3(s * (hw + 0.004), 1.78, 1.05), "paint", red, Vector3.ZERO, false)
		_lamp(k, m, Vector3(0.14, 0.1, 0.14), Vector3(s * 0.85, 2.65, 2.82), red)
		k._box(m, Vector3(0.74, 0.62, 0.012), Vector3(s * 0.44, 1.88, 2.952), "glass", null, Vector3.ZERO, false)
	k._box(m, Vector3(0.62, 0.42, 0.012), Vector3(0, 1.75, 2.958), "paint", Color(0.85, 0.84, 0.8), Vector3.ZERO, false)
	k._box(m, Vector3(0.36, 0.1, 0.014), Vector3(0, 1.75, 2.962), "paint", red, Vector3.ZERO, false)
	k._box(m, Vector3(0.1, 0.36, 0.014), Vector3(0, 1.75, 2.962), "paint", red, Vector3.ZERO, false)
	k._box(m, Vector3(1.94, 0.15, 0.03), Vector3(0, 0.83, -2.98), "paint", red, Vector3(0.35, 0, 0), false)
	# the big cross on the roof
	k._box(m, Vector3(1.0, 0.012, 0.3), Vector3(0, 2.605, 1.0), "paint", red, Vector3.ZERO, false)
	k._box(m, Vector3(0.3, 0.012, 1.0), Vector3(0, 2.605, 1.0), "paint", red, Vector3.ZERO, false)
	# light bar: red lenses either side of white
	k._box(m, Vector3(1.5, 0.1, 0.28), Vector3(0, 2.66, -0.75), "plain", Color(0.22, 0.22, 0.22))
	for i in 5:
		var x := -0.6 + i * 0.3
		_lamp(k, m, Vector3(0.26, 0.09, 0.24), Vector3(x, 2.74, -0.75), red if i != 2 else Color(0.9, 0.9, 0.86))


## Safety orange with a white band, a ladder on the roof rack, a beacon,
## chevrons on the rear doors.
static func _van_services(k: VehicleModels) -> void:
	var m := k.root
	var hw := 0.99
	var al := Color(0.55, 0.56, 0.55)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.012, 0.12, 4.95), Vector3(s * (hw + 0.004), 1.08, 0.42), "paint", Color(0.82, 0.82, 0.78), Vector3.ZERO, false)
		# roof rack rails on their feet
		k._box(m, Vector3(0.05, 0.05, 3.5), Vector3(s * 0.78, 2.72, 1.0), "paint", al)
		for z in [-0.6, 0.6, 1.8, 2.6]:
			k._box(m, Vector3(0.06, 0.12, 0.06), Vector3(s * 0.78, 2.65, z), "gunmetal_w")
	for z in [-0.6, 0.2, 1.0, 1.8, 2.6]:
		k._box(m, Vector3(1.6, 0.04, 0.05), Vector3(0, 2.76, z), "paint", al)
	# the ladder
	for x in [-0.2, 0.2]:
		k._box(m, Vector3(0.05, 0.06, 3.2), Vector3(x, 2.81, 1.05), "steel", Color(0.7, 0.7, 0.68))
	for i in 10:
		k._box(m, Vector3(0.4, 0.025, 0.03), Vector3(0, 2.81, -0.4 + i * 0.32), "steel", Color(0.7, 0.7, 0.68), Vector3.ZERO, false)
	# amber beacon over the cab
	k._box(m, Vector3(0.6, 0.06, 0.2), Vector3(0, 2.63, -0.8), "plain", TRIM)
	k._cyl(m, 0.08, 0.09, 0.12, Vector3(0, 2.72, -0.8), Vector3.ZERO, "paint", AMBER, 12, false)
	# red and white chevrons on the lower rear doors
	for i in 6:
		var x := -0.75 + i * 0.3
		var cc := Color(0.62, 0.1, 0.08) if i % 2 == 0 else Color(0.85, 0.85, 0.8)
		k._box(m, Vector3(0.16, 0.6, 0.012), Vector3(x, 1.0, 2.956), "paint", cc, Vector3(0, 0, 0.7 if x < 0.0 else -0.7), false)


# --- Quadbike ---------------------------------------------------------------------

## Quadbike: a Yamaha Grizzly 450 ATV - balloon tyres, the moulded front and
## rear fender bodies with tubular racks on top, a saddle, handlebars with
## the headlight pod, floorboards, a brush guard and the exhaust out back.
static func _quad(k: VehicleModels, seed: int) -> void:
	var m := k.root
	var pal := [Color(0.24, 0.32, 0.2), Color(0.45, 0.12, 0.1), Color(0.15, 0.22, 0.36), Color(0.5, 0.45, 0.33), Color(0.13, 0.13, 0.13)]
	var col: Color = pal[absi(hash(seed * 31 + 5)) % pal.size()]
	var dark := Color(0.12, 0.12, 0.12)
	var zf := -0.6
	var zr := 0.62
	# frame, engine, swingarm
	for s in [-1.0, 1.0]:
		_bent(k, m, [Vector3(s * 0.15, 0.32, -0.85), Vector3(s * 0.15, 0.28, -0.3), Vector3(s * 0.15, 0.28, 0.6), Vector3(s * 0.15, 0.45, 0.85)], 0.025, "gunmetal_w", null, 6)
		# double wishbones and a shock to each front wheel
		_rod(k, m, Vector3(s * 0.15, 0.3, zf - 0.08), Vector3(s * 0.38, 0.27, zf), 0.018, "gunmetal_w", null, 6)
		_rod(k, m, Vector3(s * 0.15, 0.42, zf + 0.06), Vector3(s * 0.36, 0.36, zf), 0.018, "gunmetal_w", null, 6)
		_rod(k, m, Vector3(s * 0.15, 0.62, zf + 0.12), Vector3(s * 0.33, 0.32, zf + 0.02), 0.025, "paint", Color(0.55, 0.12, 0.08), 6)
		_rod(k, m, Vector3(s * 0.15, 0.32, 0.05), Vector3(s * 0.2, 0.3, zr), 0.03, "gunmetal_w", null, 6)
	k._box(m, Vector3(0.3, 0.28, 0.5), Vector3(0, 0.42, 0.02), "gunmetal_w")
	k._box(m, Vector3(0.22, 0.2, 0.22), Vector3(0, 0.6, -0.12), "metal_dark", null, Vector3(-0.4, 0, 0))
	k._cyl(m, 0.06, 0.06, 1.2, Vector3(0, 0.3, zr), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
	k._add(m, Res.sphere(0.1, 10), "gunmetal_w", null, Vector3(0.0, 0.3, zr))
	# the front body over the wheels, the console and tank, the rear body
	_xbody(k, m, "civ_quad_front", [-0.98, 0.56, -0.24, 0.56, -0.2, 0.7, -0.34, 0.84, -0.9, 0.85, -1.0, 0.72], -0.57, 0.57, 0.04, [[zf, 0.29, 0.35]], "paint", col, 7, [0.22, 0.08, 0.0, 0.0])
	_xbody(k, m, "civ_quad_rear", [0.24, 0.56, 0.98, 0.56, 1.0, 0.7, 0.92, 0.84, 0.3, 0.85, 0.2, 0.7], -0.58, 0.58, 0.04, [[zr, 0.3, 0.36]], "paint", col, 7, [0.0, 0.0, 0.2, 0.07])
	k._add(m, VehicleModels.loft("civ_quad_tank", [-0.22, -0.4, 0.22, -0.4, 0.2, 0.05, -0.2, 0.05], [-0.15, -0.3, 0.15, -0.3, 0.14, 0.0, -0.14, 0.0], 0.62, 0.92), "paint", col, Vector3.ZERO)
	k._add(m, VehicleModels.loft("civ_quad_seat", [-0.19, -0.04, 0.19, -0.04, 0.19, 0.62, -0.19, 0.62], [-0.16, 0.0, 0.16, 0.0, 0.16, 0.58, -0.16, 0.58], 0.8, 0.95), "plain", dark, Vector3.ZERO)
	# floorboards with their raised lips
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.34, 0.04, 0.5), Vector3(s * 0.38, 0.4, 0.0), "plain", dark)
		k._box(m, Vector3(0.04, 0.08, 0.5), Vector3(s * 0.56, 0.44, 0.0), "plain", dark)
		k._box(m, Vector3(0.26, 0.2, 0.04), Vector3(s * 0.38, 0.5, -0.24), "plain", dark, Vector3(-0.3, 0, 0))
		k._box(m, Vector3(0.26, 0.2, 0.04), Vector3(s * 0.38, 0.5, 0.24), "plain", dark, Vector3(0.3, 0, 0))
		k._wheel(m, Vector3(s * 0.47, 0.29, zf), 0.29, 0.2, "steel", Color(0.45, 0.46, 0.45))
		k._wheel(m, Vector3(s * 0.455, 0.3, zr), 0.3, 0.25, "steel", Color(0.45, 0.46, 0.45))
	# tubular racks front and back
	for r in [[-0.95, -0.42], [0.42, 0.96]]:
		var z0: float = r[0]
		var z1: float = r[1]
		var y := 0.9
		for x in [-0.44, 0.44]:
			_rod(k, m, Vector3(x, y, z0), Vector3(x, y, z1), 0.016, "plain", dark, 6)
		for i in 5:
			var z := lerpf(z0, z1, i / 4.0)
			_rod(k, m, Vector3(-0.44, y, z), Vector3(0.44, y, z), 0.014, "plain", dark, 6)
		for x in [-0.3, 0.3]:
			for z in [z0 + 0.05, z1 - 0.05]:
				_rod(k, m, Vector3(x, 0.84, z), Vector3(x, y, z), 0.014, "plain", dark, 6)
	# handlebars and the pod with its headlight, grips, levers
	_rod(k, m, Vector3(0, 0.7, -0.32), Vector3(0, 1.0, -0.4), 0.025, "gunmetal_w", null, 6)
	_bent(k, m, [Vector3(-0.42, 1.06, -0.32), Vector3(-0.2, 1.02, -0.4), Vector3(0.2, 1.02, -0.4), Vector3(0.42, 1.06, -0.32)], 0.014, "gunmetal_w", null, 6)
	for s in [-1.0, 1.0]:
		_rod(k, m, Vector3(s * 0.33, 1.05, -0.34), Vector3(s * 0.44, 1.065, -0.31), 0.022, "rubber", null, 8)
		k._box(m, Vector3(0.1, 0.02, 0.02), Vector3(s * 0.28, 1.06, -0.38), "gunmetal_w", null, Vector3(0, s * 0.3, 0), false)
		_lamp(k, m, Vector3(0.12, 0.06, 0.03), Vector3(s * 0.2, 0.74, -0.995), LENS)
		_lamp(k, m, Vector3(0.05, 0.04, 0.03), Vector3(s * 0.2, 0.74, -1.005), HEAD)
	k._box(m, Vector3(0.24, 0.14, 0.16), Vector3(0, 1.0, -0.47), "paint", col, Vector3(0.2, 0, 0))
	_lamp(k, m, Vector3(0.12, 0.07, 0.02), Vector3(0, 0.99, -0.555), HEAD, Vector3(0.2, 0, 0))
	k._box(m, Vector3(0.1, 0.03, 0.06), Vector3(0, 1.09, -0.45), "plain", dark, Vector3(0.3, 0, 0), false)
	# the brush guard, the tail light, the exhaust out back, a tow hitch
	_bent(k, m, [Vector3(-0.24, 0.42, -0.9), Vector3(-0.22, 0.66, -1.04), Vector3(0.22, 0.66, -1.04), Vector3(0.24, 0.42, -0.9)], 0.02, "plain", dark, 6)
	_rod(k, m, Vector3(-0.24, 0.5, -1.0), Vector3(0.24, 0.5, -1.0), 0.016, "plain", dark, 6)
	_lamp(k, m, Vector3(0.14, 0.06, 0.03), Vector3(0, 0.72, 1.0), TAIL)
	_rod(k, m, Vector3(0.14, 0.5, 0.1), Vector3(0.25, 0.55, 0.65), 0.025, "steel", null, 6)
	k._cyl(m, 0.055, 0.055, 0.3, Vector3(0.25, 0.56, 0.8), Vector3(PI / 2, 0, 0), "steel", Color(0.52, 0.52, 0.5), 10)
	k._cyl(m, 0.025, 0.025, 0.06, Vector3(0.25, 0.56, 0.97), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	k._box(m, Vector3(0.06, 0.06, 0.16), Vector3(0, 0.36, 0.92), "gunmetal_w")
	_plate(k, m, Vector3(-0.22, 0.66, 1.005), true, 0.2)


# --- Hatchback --------------------------------------------------------------------

## Hatchback: a compact five-door after the Hyundai i-Blue concept - a low
## pointed nose, a long raked windscreen, a rising beltline and a short,
## steep hatch. The Sport sits lower on dark wheels, with a roof spoiler, a
## splitter and skirts and a two-tone racing livery.
static func _hatch(k: VehicleModels, seed: int, sport: bool) -> void:
	var m := k.root
	var col := _paint(seed, 53, false)
	var acc := Color(0.82, 0.81, 0.77)
	if sport:
		var liv := [[Color(0.12, 0.2, 0.42), Color(0.82, 0.81, 0.77)], [Color(0.6, 0.12, 0.09), Color(0.82, 0.81, 0.77)],
			[Color(0.78, 0.77, 0.73), Color(0.14, 0.14, 0.15)], [Color(0.13, 0.13, 0.14), Color(0.75, 0.55, 0.12)],
			[Color(0.7, 0.55, 0.14), Color(0.13, 0.13, 0.14)]]
		var lv: Array = liv[absi(hash(seed * 13 + 3)) % liv.size()]
		col = lv[0]
		acc = lv[1]
	var dy := -0.045 if sport else 0.0
	var key := "civ_hbs" if sport else "civ_hb"
	var hw := 0.88
	var zf := -1.31
	var zr := 1.34
	var wr := 0.31
	k._box(m, Vector3(1.2, 0.16, 3.6), Vector3(0, 0.3 + dy, 0.0), "gunmetal_w")
	for z in [zf, zr]:
		k._box(m, Vector3(1.24, 0.36, 0.72), Vector3(0, 0.48 + dy, z), "plain_dark")
	var prof := [-2.1, 0.28, 2.1, 0.28, 2.18, 0.55, 2.15, 1.02, 1.6, 1.06, -0.75, 0.96, -1.95, 0.78, -2.15, 0.62, -2.17, 0.45]
	for i in range(1, prof.size(), 2):
		prof[i] = float(prof[i]) + dy
	_xbody(k, m, key + "_body", prof, -hw, hw, 0.06, [[zf, wr, 0.37], [zr, wr, 0.37]], "car_paint", col, 8, [0.55, 0.2, 0.45, 0.16])
	# glasshouse
	var lo := PackedVector3Array([Vector3(-0.8, 0.965 + dy, -0.75), Vector3(0.8, 0.965 + dy, -0.75), Vector3(0.76, 1.035 + dy, 1.98), Vector3(-0.76, 1.035 + dy, 1.98)])
	var hi := PackedVector3Array([Vector3(-0.67, 1.47 + dy, -0.08), Vector3(0.67, 1.47 + dy, -0.08), Vector3(0.62, 1.42 + dy, 1.45), Vector3(-0.62, 1.42 + dy, 1.45)])
	_glasshouse(k, m, key, lo, hi, 0.03, col)
	var inside := Vector3(0, 1.2 + dy, 0.6)
	_pane(k, m, key + "_ws", _face(lo, hi, 0), inside, 0.03, 0.97, 0.04, 0.95, 0.0, 0.012, "glass")
	_pane(k, m, key + "_rw", _face(lo, hi, 2), inside, 0.08, 0.92, 0.12, 0.9, 0.0, 0.012, "glass")
	if not sport:
		# the concept's panoramic glass roof
		_pane(k, m, key + "_roof", [hi[0], hi[1], hi[2], hi[3]], inside, 0.1, 0.9, 0.06, 0.9, 0.0, 0.006, "glass")
	for f in [1, 3]:
		var a: bool = f == 1
		for w in [[0.04, 0.42], [0.47, 0.75], [0.79, 0.9]]:
			var u0: float = w[0] if a else 1.0 - float(w[1])
			var u1: float = w[1] if a else 1.0 - float(w[0])
			_pane(k, m, "%s_sw%d_%d" % [key, f, int(u0 * 100)], _face(lo, hi, f), inside, u0, u1, 0.07, 0.9, 0.0, 0.012, "glass")
	_car_details(k, m, dy, zr, 0.97 + dy)
	for s in [-1.0, 1.0]:
		for z in [zf, zr]:
			if sport:
				k._wheel(m, Vector3(s * 0.765, wr, z), wr, 0.215, "gunmetal_w", Color(0.18, 0.18, 0.18))
			else:
				k._wheel(m, Vector3(s * 0.765, wr, z), wr, 0.205, "steel", Color(0.6, 0.61, 0.6))
		# door shut lines: front door, rear door
		for z in [-0.72, 0.44, 1.26]:
			k._box(m, Vector3(0.012, 0.6, 0.012), Vector3(s * (hw + 0.002), 0.64 + dy, z), "plain_dark", null, Vector3.ZERO, false)
		for z in [0.2, 1.1]:
			k._box(m, Vector3(0.02, 0.03, 0.12), Vector3(s * (hw + 0.008), 0.88 + dy, z), "car_paint", col.darkened(0.15), Vector3.ZERO, false)
		_mirror(k, m, s, Vector3(s * 0.8, 1.02 + dy, -0.62), 0.1, Vector3(0.1, 0.09, 0.15), "car_paint", col)
	# the face: swept lamps, a slim upper grille, the wide lower intake
	for s in [-1.0, 1.0]:
		var up := Vector3(0, 1, 0.5).normalized()
		_slab(k, m, Vector3(s * 0.4, 0.68 + dy, -2.14), Vector3(s * 0.8, 0.735 + dy, -1.88), 0.1, 0.05, "gunmetal_w", null, up)
		_slab(k, m, Vector3(s * 0.42, 0.685 + dy, -2.155), Vector3(s * 0.79, 0.74 + dy, -1.9), 0.075, 0.03, "paint", LENS, up)
		_slab(k, m, Vector3(s * 0.48, 0.69 + dy, -2.16), Vector3(s * 0.6, 0.71 + dy, -2.1), 0.05, 0.03, "paint", HEAD, up)
		_slab(k, m, Vector3(s * 0.4, 0.88 + dy, 2.172), Vector3(s * 0.69, 0.885 + dy, 2.165), 0.09, 0.03, "paint", TAIL, Vector3.UP)
		_slab(k, m, Vector3(s * 0.68, 0.885 + dy, 2.16), Vector3(s * 0.85, 0.9 + dy, 1.96), 0.09, 0.03, "paint", TAIL, Vector3.UP)
		k._cyl(m, 0.035, 0.035, 0.03, Vector3(s * 0.62, 0.42 + dy, -2.15), Vector3(PI / 2, 0, 0), "paint", LENS, 10, false)
	k._box(m, Vector3(0.5, 0.05, 0.03), Vector3(0, 0.66 + dy, -2.155), "plain", Color(0.06, 0.06, 0.06), Vector3(0.6, 0, 0), false)
	k._box(m, Vector3(0.9, 0.16, 0.03), Vector3(0, 0.44 + dy, -2.175), "plain", Color(0.06, 0.06, 0.06), Vector3.ZERO, false)
	_plate(k, m, Vector3(0, 0.5 + dy, -2.19), false, 0.46)
	_plate(k, m, Vector3(0, 0.7 + dy, 2.165), true, 0.46)
	_rod(k, m, Vector3(0, 1.08 + dy, 2.02), Vector3(0, 1.0 + dy, 2.12), 0.006, "plain", TRIM, 4, false)
	k._box(m, Vector3(0.05, 0.05, 0.14), Vector3(0, 1.45 + dy, 1.2), "plain", TRIM)
	if sport:
		_hatch_sport(k, acc, dy)


## Racing stripes over bonnet, roof and tail, the roof spoiler, a splitter
## and side skirts.
static func _hatch_sport(k: VehicleModels, acc: Color, dy: float) -> void:
	var m := k.root
	for x in [-0.14, 0.14]:
		_slab(k, m, Vector3(x, 0.965 + dy + 0.004, -0.78), Vector3(x, 0.785 + dy + 0.004, -1.93), 0.18, 0.006, "car_paint", acc, Vector3(1, 0, 0))
		_slab(k, m, Vector3(x, 0.785 + dy + 0.004, -1.93), Vector3(x, 0.63 + dy, -2.13), 0.18, 0.006, "car_paint", acc, Vector3(1, 0, 0))
		_slab(k, m, Vector3(x, 1.474 + dy, -0.05), Vector3(x, 1.424 + dy, 1.42), 0.18, 0.006, "car_paint", acc, Vector3(1, 0, 0))
		_slab(k, m, Vector3(x, 1.0 + dy, 2.163), Vector3(x, 0.8 + dy, 2.175), 0.006, 0.18, "car_paint", acc, Vector3(0, 0, 1))
	# spoiler over the hatch on two stays, its end plates
	var sp := Vector3(0, 1.44 + dy, 1.5)
	k._add(m, VehicleModels.loft("civ_hbs_wing", [-0.62, -0.06, 0.62, -0.06, 0.62, 0.16, -0.62, 0.16], [-0.62, -0.06, 0.62, -0.06, 0.62, 0.12, -0.62, 0.12], 0.0, 0.035), "car_paint", acc, sp)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.025, 0.08, 0.24), sp + Vector3(s * 0.62, 0.0, 0.05), "car_paint", acc)
		k._box(m, Vector3(0.02, 0.06, 0.04), sp + Vector3(s * 0.3, -0.03, 0.02), "plain", TRIM)
		k._box(m, Vector3(0.05, 0.07, 2.45), Vector3(s * 0.875, 0.3 + dy, 0.0), "plain", TRIM)
		k._box(m, Vector3(0.012, 0.08, 2.45), Vector3(s * 0.9, 0.44 + dy, 0.0), "car_paint", acc, Vector3.ZERO, false)
	k._box(m, Vector3(1.7, 0.03, 0.12), Vector3(0, 0.27 + dy, -2.14), "plain", TRIM)
	k._box(m, Vector3(1.4, 0.06, 0.1), Vector3(0, 0.3 + dy, 2.14), "plain", TRIM)
	for x in [0.35, 0.47]:
		k._cyl(m, 0.035, 0.035, 0.1, Vector3(x, 0.3 + dy, 2.16), Vector3(PI / 2, 0, 0), "steel", Color(0.55, 0.55, 0.55), 10, false)


## A glasshouse lofted from the beltline ring up to the roof ring, its roof
## edge chamfered.
static func _glasshouse(k: VehicleModels, parent: Node3D, key: String, lo: PackedVector3Array, hi: PackedVector3Array, ch: float, col: Color) -> void:
	var c := VehicleModels._centroid(hi)
	var mid := PackedVector3Array()
	var top := PackedVector3Array()
	for i in hi.size():
		var t := ch / maxf(0.05, hi[i].y - lo[i].y)
		mid.append(hi[i].lerp(lo[i], t))
		var flat := Vector3(c.x, hi[i].y, c.z)
		top.append(hi[i] + (flat - hi[i]).normalized() * ch)
	k._add(parent, VehicleModels.solid([lo, mid, top], key + "_gh"), "car_paint", col, Vector3.ZERO)


## The bits every car has: the chassis under it, wipers, a tow eye.
static func _car_details(k: VehicleModels, m: Node3D, dy: float, zr: float, ywiper: float) -> void:
	k._cyl(m, 0.05, 0.05, 1.3, Vector3(0, 0.31 + dy, zr), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
	k._cyl(m, 0.03, 0.03, 1.6, Vector3(-0.35, 0.22 + dy, 0.8), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	for x in [-0.3, 0.2]:
		k._box(m, Vector3(0.48, 0.012, 0.025), Vector3(x, ywiper + 0.02, -0.73), "gunmetal_w", null, Vector3(-1.0, 0, 0.1), false)


# --- SUV --------------------------------------------------------------------------

## SUV: a BMW X6 (E71) - a big high-shouldered body on large wheels under a
## coupe roofline sloping all the way to the boot lip, the twin kidney grille,
## twin ring headlights, L-shaped tail lights and quad exhausts.
static func _suv(k: VehicleModels, seed: int) -> void:
	var m := k.root
	var col := _paint(seed, 61, false)
	var hw := 0.97
	var zf := -1.5
	var zr := 1.43
	var wr := 0.37
	k._box(m, Vector3(1.3, 0.16, 4.2), Vector3(0, 0.4, 0.0), "gunmetal_w")
	for z in [zf, zr]:
		k._box(m, Vector3(1.35, 0.42, 0.82), Vector3(0, 0.6, z), "plain_dark")
	_xbody(k, m, "civ_suv_body", [-2.36, 0.41, 2.36, 0.41, 2.45, 0.67, 2.44, 1.17, 2.3, 1.28, 1.6, 1.3, -0.62, 1.21, -2.2, 1.05, -2.42, 0.93, -2.45, 0.67],
		-hw, hw, 0.07, [[zf, wr, 0.43], [zr, wr, 0.43]], "car_paint", col, 8, [0.6, 0.22, 0.5, 0.16])
	var lo := PackedVector3Array([Vector3(-0.88, 1.21, -0.62), Vector3(0.88, 1.21, -0.62), Vector3(0.8, 1.285, 2.05), Vector3(-0.8, 1.285, 2.05)])
	var hi := PackedVector3Array([Vector3(-0.69, 1.7, 0.12), Vector3(0.69, 1.7, 0.12), Vector3(0.64, 1.66, 0.85), Vector3(-0.64, 1.66, 0.85)])
	_glasshouse(k, m, "civ_suv", lo, hi, 0.04, col)
	var inside := Vector3(0, 1.4, 0.5)
	_pane(k, m, "civ_suv_ws", _face(lo, hi, 0), inside, 0.03, 0.97, 0.04, 0.95, 0.0, 0.012, "glass")
	_pane(k, m, "civ_suv_rw", _face(lo, hi, 2), inside, 0.1, 0.9, 0.16, 0.88, 0.0, 0.012, "glass")
	for f in [1, 3]:
		var a: bool = f == 1
		for w in [[0.03, 0.43], [0.47, 0.8]]:
			var u0: float = w[0] if a else 1.0 - float(w[1])
			var u1: float = w[1] if a else 1.0 - float(w[0])
			_pane(k, m, "civ_suv_sw%d_%d" % [f, int(u0 * 100)], _face(lo, hi, f), inside, u0, u1, 0.1, 0.88, 0.0, 0.012, "glass")
	_car_details(k, m, 0.05, zr, 1.19)
	for s in [-1.0, 1.0]:
		for z in [zf, zr]:
			k._wheel(m, Vector3(s * 0.835, wr, z), wr, 0.26, "steel", Color(0.55, 0.56, 0.56))
			_flare(k, m, "civ_suv_fl%d%d" % [int(s), int(z)], z, wr, 0.42, 0.46, s * hw - 0.03, s * hw + 0.025, 0.42, PI - 0.42, "plain", TRIM, 7)
		# doors, chrome handles, the shoulder crease, black skirts, mirrors
		for z in [-0.6, 0.46, 1.36]:
			k._box(m, Vector3(0.012, 0.7, 0.012), Vector3(s * (hw + 0.002), 0.86, z), "plain_dark", null, Vector3.ZERO, false)
		for z in [0.22, 1.18]:
			k._box(m, Vector3(0.025, 0.035, 0.15), Vector3(s * (hw + 0.01), 1.1, z), "steel", Color(0.65, 0.66, 0.66), Vector3.ZERO, false)
		k._box(m, Vector3(0.012, 0.02, 3.4), Vector3(s * (hw + 0.002), 1.06, 0.1), "car_paint", col.darkened(0.25), Vector3.ZERO, false)
		k._box(m, Vector3(0.03, 0.12, 2.0), Vector3(s * (hw + 0.004), 0.48, -0.04), "plain", TRIM)
		_mirror(k, m, s, Vector3(s * 0.88, 1.27, -0.5), 0.1, Vector3(0.12, 0.11, 0.17), "car_paint", col)
		# headlights flanking the kidneys, two rings in each, wrapping round
		var up := Vector3(0, 1, 0.1).normalized()
		_slab(k, m, Vector3(s * 0.31, 0.87, -2.445), Vector3(s * 0.67, 0.875, -2.445), 0.12, 0.04, "gunmetal_w", null, up)
		_slab(k, m, Vector3(s * 0.66, 0.875, -2.44), Vector3(s * 0.88, 0.9, -2.23), 0.11, 0.04, "gunmetal_w", null, up)
		_slab(k, m, Vector3(s * 0.32, 0.87, -2.465), Vector3(s * 0.66, 0.875, -2.465), 0.09, 0.02, "paint", LENS, up)
		_slab(k, m, Vector3(s * 0.67, 0.877, -2.455), Vector3(s * 0.885, 0.9, -2.25), 0.08, 0.02, "paint", LENS, up)
		for j in 2:
			k._add(m, Res.torus(0.03, 0.042), "paint", HEAD, Vector3(s * (0.42 + j * 0.15), 0.872, -2.478), Vector3(PI / 2, 0, 0))
		# the tail lights across the corners, a reflector under them
		_slab(k, m, Vector3(s * 0.4, 1.1, 2.455), Vector3(s * 0.75, 1.1, 2.455), 0.1, 0.03, "paint", TAIL, Vector3.UP)
		_slab(k, m, Vector3(s * 0.74, 1.1, 2.45), Vector3(s * 0.93, 1.1, 2.17), 0.1, 0.03, "paint", TAIL, Vector3.UP)
		_slab(k, m, Vector3(s * 0.55, 0.62, 2.455), Vector3(s * 0.75, 0.62, 2.455), 0.03, 0.02, "paint", TAIL, Vector3.UP)
		# lower intakes and fog lights, exhausts
		k._box(m, Vector3(0.32, 0.17, 0.03), Vector3(s * 0.52, 0.6, -2.455), "plain", Color(0.06, 0.06, 0.06), Vector3.ZERO, false)
		k._cyl(m, 0.04, 0.04, 0.03, Vector3(s * 0.52, 0.6, -2.47), Vector3(PI / 2, 0, 0), "paint", LENS, 10, false)
		for x in [0.5, 0.62]:
			k._cyl(m, 0.04, 0.04, 0.1, Vector3(s * x, 0.47, 2.42), Vector3(PI / 2, 0, 0), "steel", Color(0.6, 0.6, 0.6), 10, false)
	# the twin kidneys
	for s in [-1.0, 1.0]:
		var kc := Vector3(s * 0.15, 0.83, -2.447)
		k._box(m, Vector3(0.24, 0.18, 0.04), kc, "steel", Color(0.7, 0.71, 0.7), Vector3(0.1, 0, 0))
		k._box(m, Vector3(0.2, 0.14, 0.03), kc + Vector3(0, 0, -0.012), "plain", Color(0.05, 0.05, 0.05), Vector3(0.1, 0, 0), false)
		for i in 5:
			k._box(m, Vector3(0.012, 0.14, 0.03), kc + Vector3(-0.08 + i * 0.04, 0, -0.02), "steel", Color(0.55, 0.55, 0.55), Vector3(0.1, 0, 0), false)
	k._box(m, Vector3(0.5, 0.12, 0.03), Vector3(0, 0.55, -2.455), "plain", Color(0.06, 0.06, 0.06), Vector3.ZERO, false)
	k._box(m, Vector3(1.4, 0.12, 0.06), Vector3(0, 0.45, 2.42), "plain", TRIM)
	_plate(k, m, Vector3(0, 0.7, -2.47), false, 0.5)
	_plate(k, m, Vector3(0, 0.93, 2.455), true, 0.5)
	k._box(m, Vector3(0.05, 0.05, 0.14), Vector3(0, 1.69, 0.72), "plain", TRIM)


# --- Kart -------------------------------------------------------------------------

## Kart: a racing go-kart - a bare tube frame on four small slicks, the nose
## fairing, a front panel with its number in front of the wheel, side pods,
## a moulded seat, the two-stroke beside it and a rear bumper.
static func _kart(k: VehicleModels, seed: int) -> void:
	var m := k.root
	var liv := [[Color(0.7, 0.14, 0.1), Color(0.85, 0.84, 0.8)], [Color(0.14, 0.3, 0.6), Color(0.85, 0.7, 0.15)],
		[Color(0.85, 0.6, 0.12), Color(0.12, 0.12, 0.13)], [Color(0.16, 0.48, 0.26), Color(0.85, 0.84, 0.8)],
		[Color(0.84, 0.83, 0.79), Color(0.7, 0.14, 0.1)], [Color(0.85, 0.4, 0.1), Color(0.14, 0.3, 0.6)]]
	var lv: Array = liv[absi(hash(seed * 17 + 9)) % liv.size()]
	var col: Color = lv[0]
	var acc: Color = lv[1]
	var tube := Color(0.55, 0.56, 0.57)
	var zf := -0.52
	var zr := 0.5
	# the frame: two main rails, cross members, the front stubs
	for s in [-1.0, 1.0]:
		_bent(k, m, [Vector3(s * 0.15, 0.09, -0.72), Vector3(s * 0.24, 0.07, -0.35), Vector3(s * 0.26, 0.07, 0.35), Vector3(s * 0.2, 0.09, 0.62)], 0.016, "steel", tube, 6)
		_rod(k, m, Vector3(s * 0.15, 0.09, zf), Vector3(s * 0.48, 0.12, zf), 0.014, "steel", tube, 6)
		_rod(k, m, Vector3(s * 0.26, 0.07, -0.2), Vector3(s * 0.55, 0.08, -0.2), 0.012, "steel", tube, 6)
		_rod(k, m, Vector3(s * 0.26, 0.07, 0.25), Vector3(s * 0.62, 0.08, 0.25), 0.012, "steel", tube, 6)
		k._wheel(m, Vector3(s * 0.56, 0.13, zf), 0.13, 0.13, "steel", Color(0.7, 0.7, 0.7))
		k._wheel(m, Vector3(s * 0.6, 0.14, zr), 0.14, 0.2, "steel", Color(0.7, 0.7, 0.7))
	for z in [-0.6, -0.1, 0.35]:
		_rod(k, m, Vector3(-0.24, 0.07, z), Vector3(0.24, 0.07, z), 0.014, "steel", tube, 6)
	k._box(m, Vector3(0.44, 0.012, 0.9), Vector3(0, 0.06, -0.25), "gunmetal_w")
	k._cyl(m, 0.022, 0.022, 1.3, Vector3(0, 0.14, zr), Vector3(0, 0, PI / 2), "steel", tube, 8)
	k._cyl(m, 0.09, 0.09, 0.012, Vector3(-0.32, 0.14, zr), Vector3(0, 0, PI / 2), "gunmetal_w", null, 14)
	k._cyl(m, 0.08, 0.08, 0.012, Vector3(0.2, 0.14, zr), Vector3(0, 0, PI / 2), "steel", Color(0.6, 0.6, 0.6), 14)
	# nose fairing, front panel, pods in the livery
	k._add(m, VehicleModels.loft("civ_kart_nose", [-0.38, -0.92, 0.38, -0.92, 0.5, -0.66, -0.5, -0.66], [-0.28, -0.88, 0.28, -0.88, 0.42, -0.68, -0.42, -0.68], 0.05, 0.15), "paint", col, Vector3.ZERO)
	k._add(m, VehicleModels.loft("civ_kart_nose_tip", [-0.28, -0.88, 0.28, -0.88, 0.42, -0.68, -0.42, -0.68], [-0.2, -0.82, 0.2, -0.82, 0.3, -0.72, -0.3, -0.72], 0.15, 0.18), "paint", acc, Vector3.ZERO)
	k._add(m, VehicleModels.loft("civ_kart_panel", [-0.2, -0.47, 0.2, -0.47, 0.2, -0.43, -0.2, -0.43], [-0.16, -0.4, 0.16, -0.4, 0.16, -0.36, -0.16, -0.36], 0.1, 0.42), "paint", col, Vector3.ZERO)
	k._box(m, Vector3(0.24, 0.17, 0.012), Vector3(0, 0.3, -0.425), "paint", Color(0.88, 0.87, 0.83), Vector3(-0.22, 0, 0), false)
	k._box(m, Vector3(0.06, 0.12, 0.014), Vector3(-0.04, 0.3, -0.43), "paint", Color(0.08, 0.08, 0.08), Vector3(-0.22, 0, 0), false)
	k._box(m, Vector3(0.06, 0.12, 0.014), Vector3(0.05, 0.3, -0.43), "paint", Color(0.08, 0.08, 0.08), Vector3(-0.22, 0, 0), false)
	for s in [-1.0, 1.0]:
		var pb := [0.27, -0.34, 0.66, -0.26, 0.66, 0.3, 0.27, 0.3]
		var pt := [0.3, -0.28, 0.62, -0.22, 0.62, 0.26, 0.3, 0.26]
		if s < 0.0:
			pb = [-0.66, -0.26, -0.27, -0.34, -0.27, 0.3, -0.66, 0.3]
			pt = [-0.62, -0.22, -0.3, -0.28, -0.3, 0.26, -0.62, 0.26]
		k._add(m, VehicleModels.loft("civ_kart_pod%d" % int(s), pb, pt, 0.06, 0.2), "paint", col, Vector3.ZERO)
		k._box(m, Vector3(0.012, 0.1, 0.22), Vector3(s * 0.645, 0.13, 0.05), "paint", Color(0.88, 0.87, 0.83), Vector3.ZERO, false)
		k._box(m, Vector3(0.014, 0.07, 0.04), Vector3(s * 0.65, 0.13, 0.02), "paint", Color(0.08, 0.08, 0.08), Vector3.ZERO, false)
		k._box(m, Vector3(0.014, 0.07, 0.04), Vector3(s * 0.65, 0.13, 0.08), "paint", Color(0.08, 0.08, 0.08), Vector3.ZERO, false)
		k._box(m, Vector3(0.26, 0.012, 0.04), Vector3(s * 0.46, 0.205, -0.1), "paint", acc, Vector3.ZERO, false)
	# seat, steering wheel and column, pedals
	k._box(m, Vector3(0.36, 0.05, 0.32), Vector3(0, 0.1, 0.18), "plain", Color(0.1, 0.1, 0.1))
	k._box(m, Vector3(0.36, 0.38, 0.05), Vector3(0, 0.3, 0.38), "plain", Color(0.1, 0.1, 0.1), Vector3(-0.35, 0, 0))
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.04, 0.22, 0.3), Vector3(s * 0.18, 0.2, 0.25), "plain", Color(0.1, 0.1, 0.1), Vector3(-0.2, 0, 0))
		k._box(m, Vector3(0.05, 0.08, 0.02), Vector3(s * 0.08, 0.12, -0.6), "gunmetal_w", null, Vector3(0.4, 0, 0), false)
	_rod(k, m, Vector3(0, 0.1, -0.55), Vector3(0, 0.42, -0.2), 0.012, "steel", tube, 6)
	k._add(m, Res.torus(0.12, 0.145), "plain", Color(0.1, 0.1, 0.1), Vector3(0, 0.43, -0.19), Vector3(1.05, 0, 0))
	k._box(m, Vector3(0.1, 0.06, 0.03), Vector3(0, 0.44, -0.2), "gunmetal_w", null, Vector3(1.05 - PI / 2, 0, 0), false)
	# the two-stroke to the right of the seat, its airbox and silencer
	k._box(m, Vector3(0.18, 0.16, 0.2), Vector3(0.38, 0.17, 0.28), "metal_dark")
	k._cyl(m, 0.06, 0.06, 0.12, Vector3(0.38, 0.3, 0.26), Vector3(0, 0, 0.3), "metal_dark", null, 10)
	for i in 4:
		k._cyl(m, 0.08, 0.08, 0.01, Vector3(0.38 + 0.01 * i, 0.26 + 0.03 * i, 0.26), Vector3(0, 0, 0.3), "metal_dark", null, 10, false)
	k._cyl(m, 0.06, 0.06, 0.18, Vector3(0.38, 0.2, 0.08), Vector3(PI / 2, 0, 0), "plain", Color(0.15, 0.15, 0.15), 10)
	_bent(k, m, [Vector3(0.38, 0.2, 0.38), Vector3(0.42, 0.24, 0.48), Vector3(0.36, 0.28, 0.62)], 0.022, "steel", Color(0.55, 0.55, 0.53), 6)
	k._cyl(m, 0.045, 0.045, 0.22, Vector3(0.3, 0.28, 0.72), Vector3(PI / 2, 0, 0.0), "steel", Color(0.62, 0.62, 0.6), 10)
	# rear bumper and its plate
	k._add(m, VehicleModels.loft("civ_kart_rb", [-0.62, 0.7, 0.62, 0.7, 0.58, 0.84, -0.58, 0.84], [-0.6, 0.72, 0.6, 0.72, 0.56, 0.8, -0.56, 0.8], 0.06, 0.15), "plain", Color(0.1, 0.1, 0.1), Vector3.ZERO)
	for s in [-1.0, 1.0]:
		_rod(k, m, Vector3(s * 0.2, 0.09, 0.6), Vector3(s * 0.3, 0.12, 0.72), 0.014, "steel", tube, 6)
	k._box(m, Vector3(0.2, 0.13, 0.012), Vector3(0, 0.22, 0.52), "paint", Color(0.88, 0.87, 0.83), Vector3(0.35, 0, 0), false)


# --- Tractor ----------------------------------------------------------------------

## Tractor: a Zetor 8011/8811-style farm tractor - the long red bonnet with a
## grille and weights in front, small front wheels on a beam axle, the big
## rear wheels with deep chevron treads under wide mudguards, the glazed
## safety cab with its white roof, the exhaust stack, the three-point hitch.
static func _tractor(k: VehicleModels, seed: int) -> void:
	var m := k.root
	var red := Color(0.58, 0.14, 0.1).lerp(Color(0.55, 0.42, 0.34), float(absi(hash(seed * 3 + 1)) % 4) * 0.06)
	var cream := Color(0.82, 0.8, 0.74)
	var grey := Color(0.18, 0.18, 0.18)
	var zf := -1.55
	var zr := 0.85
	var rr := 0.75
	var ry := 0.81
	var fr := 0.44
	var fy := 0.46
	# engine, gearbox and the rear axle housings, the front beam axle
	k._box(m, Vector3(0.56, 0.4, 2.1), Vector3(0, 0.66, -1.1), "metal_dark")
	k._box(m, Vector3(0.62, 0.62, 1.1), Vector3(0, 0.74, 0.45), "metal_dark")
	k._box(m, Vector3(0.7, 0.5, 0.5), Vector3(0, 0.82, zr), "metal_dark")
	k._cyl(m, 0.13, 0.17, 1.3, Vector3(0, ry, zr), Vector3(0, 0, PI / 2), "metal_dark", null, 12)
	k._box(m, Vector3(1.45, 0.14, 0.16), Vector3(0, fy + 0.02, zf), "paint", grey)
	k._cyl(m, 0.08, 0.08, 0.3, Vector3(0, fy + 0.08, zf), Vector3(PI / 2, 0, 0), "metal_dark", null, 8)
	# the bonnet, its grille and lamps, the weights hung on the front
	_xbody(k, m, "civ_tr_bonnet", [-2.12, 0.86, -0.36, 0.86, -0.36, 1.64, -1.95, 1.58, -2.12, 1.46], -0.38, 0.38, 0.04, [], "paint", red)
	k._box(m, Vector3(0.6, 0.5, 0.03), Vector3(0, 1.15, -2.125), "plain", Color(0.07, 0.07, 0.07))
	for i in 6:
		k._box(m, Vector3(0.62, 0.025, 0.03), Vector3(0, 0.94 + i * 0.08, -2.14), "paint", grey.lightened(0.15), Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.14, 0.1, 0.05), Vector3(s * 0.23, 1.4, -2.13), "paint", grey)
		_lamp(k, m, Vector3(0.11, 0.07, 0.02), Vector3(s * 0.23, 1.4, -2.16), HEAD)
		# louvres along the bonnet sides
		for i in 5:
			k._box(m, Vector3(0.012, 0.03, 0.2), Vector3(s * 0.382, 1.3 - i * 0.07, -1.2), "plain", Color(0.07, 0.07, 0.07), Vector3.ZERO, false)
	k._box(m, Vector3(0.3, 0.1, 0.3), Vector3(0, 0.62, -2.2), "paint", grey)
	for i in 5:
		k._box(m, Vector3(0.82, 0.34, 0.045), Vector3(0, 0.78, -2.19 - i * 0.05), "paint", grey.lightened(0.05))
	k._box(m, Vector3(0.1, 0.12, 0.42), Vector3(0, 1.0, -2.3), "paint", grey)
	# wheels: small fronts under cycle wings, big rears with chevron lugs
	for s in [-1.0, 1.0]:
		k._wheel(m, Vector3(s * 0.72, fy, zf), fr, 0.2, "paint", red)
		_flare(k, m, "civ_trc_fw%d" % int(s), zf, fy, fr + 0.05, fr + 0.08, s * 0.72 - 0.13, s * 0.72 + 0.13, 0.5, PI - 0.3, "paint", red, 5)
		_rod(k, m, Vector3(s * 0.72, fy + 0.53, zf - 0.1), Vector3(s * 0.62, fy + 0.05, zf), 0.02, "paint", grey, 6)
		var w := k._wheel(m, Vector3(s * 0.84, ry, zr), rr, 0.44, "paint", red)
		for i in 22:
			var a := TAU * i / 22.0
			for side in [-1.0, 1.0]:
				var lug := k._add(w, Res.box(Vector3(0.24, 0.05, 0.07)), "rubber", null, Vector3(side * 0.11, sin(a) * (rr + 0.01), cos(a) * (rr + 0.01)))
				lug.basis = Basis(Vector3.RIGHT, -a) * Basis(Vector3.UP, side * 0.45)
		# the mudguards: a wide curved guard and its inner wall
		_flare(k, m, "civ_trc_rw%d" % int(s), zr, ry, rr + 0.1, rr + 0.13, s * 0.84 - 0.27, s * 0.84 + 0.27, 0.12, PI - 0.12, "paint", red, 8)
		var x0 := 0.58 if s > 0 else -0.62
		var half := []
		for i in 9:
			var a := lerpf(0.12, PI - 0.12, i / 8.0)
			half.append_array([zr + (rr + 0.12) * cos(a), ry + (rr + 0.12) * sin(a)])
		_xbody(k, m, "civ_trc_wall%d" % int(s), half, x0, x0 + 0.04, 0.012, [], "paint", red)
		_lamp(k, m, Vector3(0.08, 0.12, 0.05), Vector3(s * 1.0, 1.15, zr + 0.88), TAIL)
		_lamp(k, m, Vector3(0.08, 0.06, 0.05), Vector3(s * 1.0, 1.28, zr - 0.72), AMBER)
	# the cab: floor, posts, white roof, glass all round
	k._box(m, Vector3(1.3, 0.1, 1.6), Vector3(0, 1.2, 0.42), "paint", grey)
	var cx := 0.66
	var cz0 := -0.36
	var cz1 := 1.22
	var cy0 := 1.22
	var cy1 := 2.58
	for p in [Vector2(-cx, cz0), Vector2(cx, cz0), Vector2(-cx, cz1), Vector2(cx, cz1)]:
		k._box(m, Vector3(0.06, cy1 - cy0, 0.06), Vector3(p.x, (cy0 + cy1) * 0.5, p.y), "paint", grey)
	for s in [-1.0, 1.0]:
		k._box(m, Vector3(0.05, 0.05, cz1 - cz0), Vector3(s * cx, 1.7, (cz0 + cz1) * 0.5), "paint", grey)
		k._box(m, Vector3(0.012, cy1 - 1.72, cz1 - cz0 - 0.08), Vector3(s * cx, (1.72 + cy1) * 0.5, (cz0 + cz1) * 0.5), "glass", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.012, 0.44, 0.34), Vector3(s * cx, 1.47, cz0 + 0.2), "glass", null, Vector3.ZERO, false)
		k._box(m, Vector3(0.03, 0.03, 0.14), Vector3(s * (cx + 0.02), 1.9, 0.3), "plain", TRIM, Vector3.ZERO, false)
		_mirror(k, m, s, Vector3(s * (cx + 0.02), 2.3, cz0), 0.22, Vector3(0.05, 0.22, 0.14), "plain", TRIM)
		_lamp(k, m, Vector3(0.12, 0.08, 0.06), Vector3(s * 0.45, 2.62, cz1 + 0.12), HEAD)
	k._box(m, Vector3(cx * 2.0 - 0.06, 0.92, 0.012), Vector3(0, 2.12, cz0), "glass", null, Vector3.ZERO, false)
	k._box(m, Vector3(cx * 2.0, 0.05, 0.05), Vector3(0, 1.66, cz0), "paint", grey)
	k._box(m, Vector3(cx * 2.0 - 0.06, 0.82, 0.012), Vector3(0, 2.12, cz1), "glass", null, Vector3.ZERO, false)
	k._box(m, Vector3(cx * 2.0, 0.42, 0.04), Vector3(0, 1.48, cz1), "paint", red)
	k._add(m, VehicleModels.loft("civ_trc_roof", [-0.76, -0.5, 0.76, -0.5, 0.76, 1.34, -0.76, 1.34], [-0.7, -0.44, 0.7, -0.44, 0.7, 1.28, -0.7, 1.28], cy1, cy1 + 0.14), "paint", cream, Vector3.ZERO)
	k._box(m, Vector3(0.3, 0.03, 0.3), Vector3(0.2, cy1 + 0.15, 0.4), "paint", cream.darkened(0.1))
	_lamp(k, m, Vector3(0.1, 0.08, 0.1), Vector3(-0.3, cy1 + 0.18, 0.0), AMBER)
	# inside: the seat and the wheel
	k._box(m, Vector3(0.45, 0.1, 0.42), Vector3(0, 1.62, 0.6), "plain", Color(0.15, 0.15, 0.14))
	k._box(m, Vector3(0.45, 0.5, 0.1), Vector3(0, 1.9, 0.82), "plain", Color(0.15, 0.15, 0.14), Vector3(-0.15, 0, 0))
	k._add(m, Res.torus(0.17, 0.2), "plain", TRIM, Vector3(0, 1.95, -0.05), Vector3(0.5, 0, 0))
	_rod(k, m, Vector3(0, 1.95, -0.05), Vector3(0, 1.62, -0.32), 0.03, "plain", TRIM, 6)
	# exhaust stack with its silencer and rain cap, the air intake
	k._cyl(m, 0.045, 0.045, 1.25, Vector3(0.22, 2.2, -0.62), Vector3.ZERO, "metal_dark", null, 8)
	k._cyl(m, 0.08, 0.08, 0.45, Vector3(0.22, 1.95, -0.62), Vector3.ZERO, "metal_dark", null, 10)
	k._box(m, Vector3(0.1, 0.012, 0.12), Vector3(0.22, 2.84, -0.6), "metal_dark", null, Vector3(0.4, 0, 0))
	k._cyl(m, 0.05, 0.05, 0.5, Vector3(-0.22, 1.88, -0.62), Vector3.ZERO, "paint", grey, 8)
	k._cyl(m, 0.08, 0.06, 0.1, Vector3(-0.22, 2.18, -0.62), Vector3.ZERO, "paint", grey, 10)
	# steps on the left, the three-point hitch and the PTO at the back
	for y in [0.62, 0.92]:
		k._box(m, Vector3(0.24, 0.03, 0.2), Vector3(-0.52, y, -0.15), "paint", grey)
	for s in [-1.0, 1.0]:
		_rod(k, m, Vector3(s * 0.3, 0.55, zr + 0.1), Vector3(s * 0.42, 0.48, zr + 0.95), 0.03, "paint", grey, 6)
		_rod(k, m, Vector3(s * 0.32, 1.05, zr + 0.2), Vector3(s * 0.4, 0.55, zr + 0.6), 0.02, "paint", grey, 6)
	_rod(k, m, Vector3(0, 1.06, zr + 0.25), Vector3(0, 0.95, zr + 0.9), 0.035, "paint", grey, 6)
	k._cyl(m, 0.035, 0.035, 0.18, Vector3(0, 0.62, zr + 0.35), Vector3(PI / 2, 0, 0), "steel", null, 8)
	k._box(m, Vector3(0.3, 0.06, 0.4), Vector3(0, 0.5, zr + 0.4), "paint", grey)
	_plate(k, m, Vector3(0, 1.3, cz1 + 0.04), true, 0.34)


# --- ED-1 -------------------------------------------------------------------------

## ED-1: a small tracked EOD robot, PackBot / Talon-like - a low hull between
## two rubber tracks with flippers at the front, a folding two-link arm on a
## turntable carrying the sensor head and its gripper, whip antennas.
static func _ed1(k: VehicleModels, team: int) -> void:
	var m := k.root
	var col := Color(0.33, 0.35, 0.27) if team == 0 else (Color(0.5, 0.46, 0.36) if team == 1 else Color(0.42, 0.43, 0.42))
	var dark := Color(0.12, 0.12, 0.12)
	_xbody(k, m, "civ_ed1_hull", [-0.36, 0.06, 0.32, 0.06, 0.38, 0.12, 0.36, 0.23, -0.32, 0.23, -0.38, 0.15], -0.19, 0.19, 0.015, [], "paint", col)
	k._box(m, Vector3(0.3, 0.012, 0.4), Vector3(0, 0.236, 0.02), "plain", dark, Vector3.ZERO, false)
	var tp := [-0.43, 0.11, -0.37, 0.0, 0.37, 0.0, 0.43, 0.11, 0.38, 0.2, -0.38, 0.2]
	for s in [-1.0, 1.0]:
		k._add(m, VehicleModels.extrude_x("civ_ed1_trk", tp, -0.055, 0.055), "track", null, Vector3(s * 0.25, 0, 0))
		for z in [-0.33, 0.33]:
			k._wheel(m, Vector3(s * 0.31, 0.1, z), 0.085, 0.02, "paint", col.darkened(0.2))
		for z in [-0.15, 0.0, 0.15]:
			k._wheel(m, Vector3(s * 0.31, 0.07, z), 0.05, 0.016, "gunmetal_w")
		# the flippers, swung forward and up off the front sprockets
		var fp := k._pivot(m, Vector3(s * 0.34, 0.1, -0.33))
		fp.rotation.x = 0.35
		k._add(fp, VehicleModels.extrude_x("civ_ed1_flip", [0.0, -0.085, -0.2, -0.05, -0.24, 0.0, -0.2, 0.05, 0.0, 0.085, 0.07, 0.0], -0.03, 0.03), "track", null, Vector3.ZERO)
		k._cyl(fp, 0.04, 0.04, 0.07, Vector3.ZERO, Vector3(0, 0, PI / 2), "paint", col.darkened(0.2), 10)
		# carry handles on the hull sides
		_bent(k, m, [Vector3(s * 0.19, 0.18, -0.1), Vector3(s * 0.2, 0.26, -0.08), Vector3(s * 0.2, 0.26, 0.08), Vector3(s * 0.19, 0.18, 0.1)], 0.01, "plain", dark, 6)
		_lamp(k, m, Vector3(0.05, 0.03, 0.02), Vector3(s * 0.12, 0.2, -0.375), HEAD, Vector3(0.6, 0, 0))
		_rod(k, m, Vector3(s * 0.14, 0.24, 0.3), Vector3(s * 0.15, 0.62, 0.32), 0.004, "plain", dark, 4, false)
		k._cyl(m, 0.012, 0.014, 0.05, Vector3(s * 0.14, 0.26, 0.3), Vector3.ZERO, "plain", dark, 6)
	# the payload box at the back
	k._box(m, Vector3(0.26, 0.08, 0.16), Vector3(0, 0.27, 0.22), "paint", col.darkened(0.1))
	k._box(m, Vector3(0.1, 0.02, 0.04), Vector3(0, 0.32, 0.22), "plain", dark, Vector3.ZERO, false)
	# the arm, folded: turntable, shoulder, upper arm back, forearm forward
	k._cyl(m, 0.07, 0.075, 0.04, Vector3(0, 0.255, -0.06), Vector3.ZERO, "plain", dark, 14)
	k._box(m, Vector3(0.1, 0.08, 0.1), Vector3(0, 0.3, -0.06), "paint", col)
	var sh := Vector3(0, 0.32, -0.06)
	var el := Vector3(0, 0.38, 0.24)
	var wr := Vector3(0, 0.44, -0.12)
	_strut(k, m, sh, el, 0.06, 0.05, "paint", col)
	k._cyl(m, 0.035, 0.035, 0.1, el, Vector3(0, 0, PI / 2), "plain", dark, 10)
	k._cyl(m, 0.035, 0.035, 0.1, sh, Vector3(0, 0, PI / 2), "plain", dark, 10)
	_strut(k, m, el + Vector3(0.0, 0.02, 0), wr, 0.05, 0.04, "paint", col)
	_rod(k, m, sh + Vector3(0.04, 0.02, 0), el + Vector3(0.04, 0.03, 0), 0.008, "plain", dark, 4, false)
	# the sensor head: cameras and a light, the gripper's jaws under it
	k._box(m, Vector3(0.14, 0.08, 0.12), wr + Vector3(0, 0.04, -0.03), "paint", col.darkened(0.15))
	for x in [-0.035, 0.035]:
		k._cyl(m, 0.022, 0.022, 0.03, wr + Vector3(x, 0.05, -0.095), Vector3(PI / 2, 0, 0), "glass", null, 10, false)
	_lamp(k, m, Vector3(0.04, 0.02, 0.02), wr + Vector3(0, 0.02, -0.095), HEAD)
	k._box(m, Vector3(0.04, 0.03, 0.06), wr + Vector3(0, 0.1, -0.02), "plain", dark)
	for x in [-0.025, 0.025]:
		k._box(m, Vector3(0.012, 0.07, 0.03), wr + Vector3(x, -0.03, -0.06), "gunmetal_w", null, Vector3(0.3, 0, 0), false)
	k._team_mark(m, team, Vector3(0.0, 0.237, -0.22), Vector3(0.14, 0.01, 0.08))
