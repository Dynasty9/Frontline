class_name VehicleWheelArches
extends RefCounted
## Cut body strips, folded flares and liners share the same authored arch envelope.

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
static func _xprism(k: VehicleModels, parent: Node3D, key: String, p: PackedVector2Array, f: Array, x0: float, x1: float, ch: float, mat: String, col = null, rnd: Array = []) -> Variant:
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
	liner(k, parent, zc, yc, r0, x0, x1, a0, a1, segs)
	for i in segs:
		var t0 := lerpf(a0, a1, float(i) / segs)
		var t1 := lerpf(a0, a1, float(i + 1) / segs)
		var q := PackedVector2Array([Vector2(zc + r0 * cos(t0), yc + r0 * sin(t0)), Vector2(zc + r0 * cos(t1), yc + r0 * sin(t1)),
			Vector2(zc + r1 * cos(t1), yc + r1 * sin(t1)), Vector2(zc + r1 * cos(t0), yc + r1 * sin(t0))])
		_xprism(k, parent, "%s_%d" % [key, i], q, [true, i == segs - 1, true, i == 0], x0, x1, minf(0.012, (x1 - x0) * 0.3), mat, col)



## A moulded wheel-well liner (wheel tub) inside the old dark well box: `center`
## and `size` are that box in the parent's axes (X across the vehicle, Y up, Z
## along it). Its roof arches over the tyre on a half-ellipse inscribed in the
## box's side profile, springing from the box's floor line; its open edge
## thickens into a rolled lip held by push clips, and a flat wall closes it on
## the inboard side. `side` -1 or +1: one wheel's tub, open toward that side of
## X across the box's whole width. `side` 0: the box spans the vehicle between
## a pair of wheels (a civilian frame's well block): a tub opens at each end
## and the middle between their walls stays empty. The arch-following band of
## a cut body or flare stays `liner`. Nothing is registered.
static func tub(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, side := 0.0, mat := "plain_dark", col = null, segments := 8) -> void:
	var mount := k._pivot(parent, center)
	var hx := size.x * 0.5
	var ends: Array = [-1.0, 1.0] if side == 0.0 else [signf(side)]
	var depth := minf(hx, 0.34) if side == 0.0 else size.x
	var a := size.z * 0.5
	var b := size.y
	var floor_y := -size.y * 0.5
	var shell := minf(0.012, minf(a, b) * 0.06)
	var lip := minf(0.016, minf(a, b) * 0.08)
	for e: float in ends:
		var xo: float = e * hx
		var xi: float = xo - e * depth
		var lw: float = minf(0.03, depth * 0.2)
		# One ring per station round the arch: the shell's section, thicker at the
		# open edge where the lip rolls toward the tyre.
		var rings: Array = []
		var wall := PackedVector3Array()
		for i in segments + 1:
			var t := PI * float(i) / segments
			var c := cos(t)
			var s := sin(t)
			var outer := Vector2(a * c, floor_y + b * s)
			var inner := Vector2((a - shell) * c, floor_y + (b - shell) * s)
			var rolled := Vector2((a - shell - lip) * c, floor_y + (b - shell - lip) * s)
			rings.append(PackedVector3Array([Vector3(xi, inner.y, inner.x), Vector3(xi, outer.y, outer.x), Vector3(xo, outer.y, outer.x), Vector3(xo, rolled.y, rolled.x), Vector3(xo - e * lw, rolled.y, rolled.x)]))
			wall.append(Vector3(0, outer.y, outer.x))
		k._add(mount, VehicleProfiles.loft(rings, 40.0), mat, col, Vector3.ZERO)
		# The inboard wall: a D of the arch and its floor chord.
		var thick := minf(0.012, depth * 0.1)
		var near := PackedVector3Array()
		var far := PackedVector3Array()
		for q: Vector3 in wall:
			near.append(Vector3(xi, q.y, q.z))
			far.append(Vector3(xi + e * thick, q.y, q.z))
		k._add(mount, VehicleProfiles.loft([near, far], 30.0), mat, col, Vector3.ZERO)
		for t: float in [0.18, 0.5, 0.82]:
			var r := Vector2((a - shell - lip * 0.5) * cos(PI * t), floor_y + (b - shell - lip * 0.5) * sin(PI * t))
			VehicleBody.fastener(k, mount, Vector3(xo + e * 0.002, r.y, r.x), Vector3.RIGHT * e, minf(0.008, lip * 0.45))
	k._fold(mount)


## Wheel-well liner follows the authored arch radius, outside tyre clearance.
static func liner(k: VehicleModels, parent: Node3D, zc: float, yc: float, radius: float, x0: float, x1: float, a0: float, a1: float, segments: int) -> void:
	for i in segments:
		var a := lerpf(a0, a1, float(i) / segments)
		var b := lerpf(a0, a1, float(i + 1) / segments)
		var points := [zc + (radius + 0.002) * cos(a), yc + (radius + 0.002) * sin(a), zc + (radius + 0.002) * cos(b), yc + (radius + 0.002) * sin(b), zc + (radius + 0.018) * cos(b), yc + (radius + 0.018) * sin(b), zc + (radius + 0.018) * cos(a), yc + (radius + 0.018) * sin(a)]
		k._add(parent, VehicleModels.extrude_x("liner_" + var_to_str([points, x0, x1]), points, x0, x1), "rubber", null, Vector3.ZERO)
