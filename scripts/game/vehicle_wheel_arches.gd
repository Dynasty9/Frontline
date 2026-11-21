class_name VehicleWheelArches
extends RefCounted
## Cut body strips, folded flares and liners share the same authored arch envelope.

## How far a rolled body's top normals lean out at its shoulders (see _crowned).
const CROWN := 0.2
## A wheel-arch flare's faces shade round from segment to segment flatter
## than this (degrees); its 45-degree chamfers stay crisp.
const FLARE_ROLL := 40.0

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
## inset, rear length, rear inset] rounds the corners off in plan. `roll` > 0
## shades it as pressed sheet metal rather than a cut block: normals are
## averaged across every edge flatter than `roll` degrees (the chamfers into
## the roof and bonnet, the gentle bends of the profile, the corners rounded
## in plan), so a car's shoulders and bumpers roll over instead of breaking at
## a hard line; the flat sides keep their own normal. Same vertices either way.
## `crown` > 0 (with `roll`) crowns the top as well (see _crowned); `span` is
## the whole body's (middle, half length) along z.
static func _xprism(k: VehicleModels, parent: Node3D, key: String, p: PackedVector2Array, f: Array, x0: float, x1: float, ch: float, mat: String, col = null, rnd: Array = [], roll := 0.0, crown := 0.0, span := Vector2.ZERO) -> Variant:
	return k._add(parent, _xprism_mesh(p, f, x0, x1, ch, rnd, roll, crown, span, key), mat, col, Vector3.ZERO)


## _xprism's mesh (`key` caches an unrolled one).
static func _xprism_mesh(p: PackedVector2Array, f: Array, x0: float, x1: float, ch: float, rnd: Array, roll: float, crown: float, span: Vector2, key: String) -> ArrayMesh:
	var d := []
	for fl in f:
		d.append(ch if fl else 0.0)
	var pin := _inset(p, d)
	var rings := [_xring(pin, x0, 1.0, rnd), _xring(p, x0 + ch, 1.0, rnd), _xring(p, x1 - ch, -1.0, rnd), _xring(pin, x1, -1.0, rnd)]
	var mesh: ArrayMesh = VehicleProfiles.loft(rings, roll) if roll > 0.0 else VehicleModels.solid(rings, key)
	if roll > 0.0 and crown > 0.0:
		mesh = _crowned(mesh, x0 + ch, x1 - ch, rnd, crown, span)
	return mesh


static var _crowns := {}


## A rolled panel's top crowned like a pressing. A car's bonnet, roof and boot
## lid are domed: a little across (higher on the centre line than at the
## shoulders) and more along, curving down into the nose and the tail. The
## loft's top spans the body's whole width in one quad, so its normals ran
## straight from one shoulder's roll to the other's and the sun lit one thin
## line of it end to end: a white streak down every bonnet. Here the top's
## edge normals lean out across by `crown` (less than the roll's average, so
## the shoulder turns over in the chamfer) and along by how far the point
## lies from the body's middle (`span`), so the highlight is a soft patch
## that slides over the panel. The chamfers' normals at the top edge follow
## (they were shared), crisp chamfers keep their own; normals only, so the
## vertices are the loft's.
static func _crowned(mesh: ArrayMesh, xa: float, xb: float, rnd: Array, crown: float, span: Vector2) -> ArrayMesh:
	var key := "%d|%.4f|%.4f|%.3f|%.3f|%.3f" % [mesh.get_instance_id(), xa, xb, crown, span.x, span.y]
	if _crowns.has(key):
		return _crowns[key]
	var src: Array = mesh.get_meta(&"src")
	var vs: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var ns := _crown_normals(vs, src[Mesh.ARRAY_NORMAL], xa, xb, rnd, crown, span)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vs
	arrays[Mesh.ARRAY_NORMAL] = ns
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(out, arrays)
	_crowns[key] = out
	return out


## _crowned's normals for a triangle list (vs, ns), its top's edges at xa and xb.
static func _crown_normals(vs: PackedVector3Array, ns: PackedVector3Array, xa: float, xb: float, rnd: Array, crown: float, span: Vector2) -> PackedVector3Array:
	for t in range(0, vs.size() - 2, 3):
		var fc := (vs[t + 1] - vs[t]).cross(vs[t + 2] - vs[t])
		if fc.length_squared() < 1e-14:
			continue
		var fx := absf(fc.normalized().x)
		for j in 3:
			var v := vs[t + j]
			var lift := _taper(v.z, rnd)
			var side := 0.0
			if absf(v.x - (xa + lift)) < 1e-4:
				side = -1.0
			elif absf(v.x - (xb - lift)) < 1e-4:
				side = 1.0
			if side == 0.0:
				continue
			var n := ns[t + j]
			# (a chamfer whose normal wasn't shared with the top keeps it)
			if fx > 0.05 and absf(n.x) > fx - 0.05:
				continue
			# the profile's own normal, the lean across taken out of it
			var np := Vector3(0.0, n.y, n.z)
			if np.length_squared() < 1e-6:
				continue
			np = np.normalized()
			# (only what faces the sky: a nose or tail standing upright stays as it was)
			var w := smoothstep(0.25, 0.7, np.y)
			if w <= 0.0:
				continue
			var along := clampf((v.z - span.x) / span.y, -1.0, 1.0) if span.y > 0.0 else 0.0
			ns[t + j] = (np + Vector3(side * crown, 0.0, along * crown * 0.9) * w).normalized()
	return ns


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
## off in plan; `roll` shades its edges as rolled sheet metal (see _xprism)
## and crowns its top by `crown` (see _crowned; a wreck's top stays flat, as
## it always was). A live panel is one mesh per piece (_plate); a wreck keeps
## a mesh per strip.
static func _xbody(k: VehicleModels, parent: Node3D, key: String, prof: Array, x0: float, x1: float, ch: float, arches: Array, mat: String, col = null, segs := 8, rnd: Array = [], roll := 0.0, crown := CROWN) -> void:
	var p := VehicleModels._v2(prof)
	var zmin := INF
	var zmax := -INF
	for v in p:
		zmin = minf(zmin, v.x)
		zmax = maxf(zmax, v.x)
	var span := Vector2((zmin + zmax) * 0.5, (zmax - zmin) * 0.5)
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
	var strips := []
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
		strips.append([poly, fl, za, zb])
	if k.wreck:
		# (a wreck keeps its strips, each a mesh, as it always had)
		for i in strips.size():
			var sp: PackedVector2Array = strips[i][0]
			if sp.size() >= 3:
				_xprism(k, parent, "%s_%d" % [key, i], sp, strips[i][1], x0, x1, ch, mat, col, rr, roll, 0.0, span)
		return
	# The strips only lay out the panel's outline: a pressed or flame-cut
	# panel is one sheet, so each piece of it (an arch reaching over the
	# plate's top parts it) is one mesh, its chords edges of one outline.
	# Strip by strip, every chord was a prism of its own: walls hidden inside
	# the panel at every cut, and the top and the sill broken at each, so a
	# rounder arch cost a strip where it now costs two edges; and the paint's
	# worn edges (VehicleBody.paint_mesh, from each part's bounds) ran down
	# every cut, a row of false seams across an armoured car's side plates.
	var mk := var_to_str([key, prof, x0, x1, ch, arches, segs, rnd, roll, crown])
	var mesh: ArrayMesh = _plates.get(mk)
	if mesh == null:
		mesh = _plate(strips, x0, x1, ch, rr, roll, crown, span)
		_plates[mk] = mesh
	if mesh.get_surface_count() > 0:
		k._add(parent, mesh, mat, col, Vector3.ZERO)


static var _plates := {}


## A live _xbody's strips ([outline, edge flags, za, zb]) as one mesh: each
## run of strips joined wall to wall is a piece, its outline extruded as
## _xprism extrudes a strip (chamfered where flagged, rounded in plan by
## `rnd`, rolled by `roll`, crowned by `crown`).
static func _plate(strips: Array, x0: float, x1: float, ch: float, rnd: Array, roll: float, crown: float, span: Vector2) -> ArrayMesh:
	var pieces := []
	var run := []
	for st: Array in strips:
		if (st[0] as PackedVector2Array).size() < 3:
			if not run.is_empty():
				pieces.append(run)
			run = []
			continue
		var s := _ccw(st)
		if not run.is_empty() and not _joined(run[run.size() - 1], s):
			pieces.append(run)
			run = []
		run.append(s)
	if not run.is_empty():
		pieces.append(run)
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	for pc: Array in pieces:
		var outline := _outline(pc, rnd)
		var arr: Array
		if outline.is_empty():
			# (an outline that won't close: its strips as they were)
			for st: Array in pc:
				var m := _xprism_mesh(st[0], st[1], x0, x1, ch, rnd, roll, crown, span, "xplate|" + var_to_str([st, x0, x1, ch, rnd]))
				arr = m.get_meta(&"src")
				vs.append_array(arr[Mesh.ARRAY_VERTEX])
				ns.append_array(arr[Mesh.ARRAY_NORMAL])
			continue
		arr = _extrude(outline[0], outline[1], x0, x1, ch, rnd, roll)
		var pv: PackedVector3Array = arr[0]
		var pn: PackedVector3Array = arr[1]
		if roll > 0.0 and crown > 0.0:
			pn = _crown_normals(pv, pn, x0 + ch, x1 - ch, rnd, crown, span)
		vs.append_array(pv)
		ns.append_array(pn)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vs
	arrays[Mesh.ARRAY_NORMAL] = ns
	var out := ArrayMesh.new()
	if not vs.is_empty():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		Mats.keep_arrays(out, arrays)
	return out


## A strip [outline, flags, za, zb] wound counter-clockwise in (z, y).
static func _ccw(st: Array) -> Array:
	var p: PackedVector2Array = st[0]
	var f: Array = st[1]
	var n := p.size()
	var area := 0.0
	for i in n:
		area += p[i].x * p[(i + 1) % n].y - p[(i + 1) % n].x * p[i].y
	if area >= 0.0:
		return st
	var q := PackedVector2Array()
	var g := []
	for i in n:
		q.append(p[n - 1 - i])
		g.append(f[(2 * n - 2 - i) % n])
	return [q, g, st[2], st[3]]


## The lowest and highest point an outline has at z (x > y where it has none).
static func _wall(p: PackedVector2Array, z: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for q in p:
		if absf(q.x - z) < 1e-4:
			lo = minf(lo, q.y)
			hi = maxf(hi, q.y)
	return Vector2(lo, hi)


## Do strips a and b (a's zb at b's za) share a stretch of wall?
static func _joined(a: Array, b: Array) -> bool:
	var z: float = a[3]
	var wa := _wall(a[0], z)
	var wb := _wall(b[0], z)
	return wa.x <= wa.y and wb.x <= wb.y and minf(wa.y, wb.y) - maxf(wa.x, wb.x) > 1e-3


## A piece's strips joined into one counter-clockwise outline: every edge but
## the walls between them, and what one wall stands proud of the next (the
## upright edge of an arch's mouth, not chamfered, as a strip's cut wasn't).
## Straight runs close up into one edge, except where `rnd` rounds the plan
## (each point there takes its own inset). [points, flags], or [] if it won't close.
static func _outline(pc: Array, rnd: Array) -> Array:
	var edges := []
	for si in pc.size():
		var st: Array = pc[si]
		var p: PackedVector2Array = st[0]
		var f: Array = st[1]
		var za: float = st[2]
		var zb: float = st[3]
		var n := p.size()
		for i in n:
			var a := p[i]
			var b := p[(i + 1) % n]
			if si > 0 and absf(a.x - za) < 1e-4 and absf(b.x - za) < 1e-4:
				continue
			if si < pc.size() - 1 and absf(a.x - zb) < 1e-4 and absf(b.x - zb) < 1e-4:
				continue
			edges.append([a, b, f[i]])
		if si < pc.size() - 1:
			var wl := _wall(p, zb)
			var wr := _wall((pc[si + 1] as Array)[0], zb)
			if absf(wl.x - wr.x) > 1e-4:
				edges.append([Vector2(zb, wl.x), Vector2(zb, wr.x), false])
			if absf(wr.y - wl.y) > 1e-4:
				edges.append([Vector2(zb, wr.y), Vector2(zb, wl.y), false])
	var used := []
	used.resize(edges.size())
	used.fill(false)
	var pts := PackedVector2Array()
	var fl := []
	var start: Vector2 = edges[0][0]
	var at: Vector2 = start
	var e := 0
	while true:
		used[e] = true
		pts.append(edges[e][0])
		fl.append(edges[e][2])
		at = edges[e][1]
		if at.distance_to(start) < 1e-4:
			break
		e = -1
		for j in edges.size():
			if not used[j] and (edges[j][0] as Vector2).distance_to(at) < 1e-4:
				e = j
				break
		if e < 0:
			return []
	if pts.size() != edges.size():
		return []
	# straight runs closed up
	var q := PackedVector2Array()
	var qf := []
	var n := pts.size()
	for i in n:
		var a := pts[(i - 1 + n) % n]
		var b := pts[i]
		var c := pts[(i + 1) % n]
		var z := b.x
		var rounds := not rnd.is_empty() and ((float(rnd[2]) > 0.0 and z < float(rnd[0]) + float(rnd[2]) + 1e-3) or (float(rnd[4]) > 0.0 and z > float(rnd[1]) - float(rnd[4]) - 1e-3))
		var u := (b - a).normalized()
		var v := (c - b).normalized()
		if not rounds and fl[(i - 1 + n) % n] == fl[i] and absf(u.cross(v)) < 1e-5 and u.dot(v) > 0.0:
			continue
		q.append(b)
		qf.append(fl[i])
	if q.size() < 3:
		return []
	return [q, qf]


## An outline (z, y, counter-clockwise; it needn't be convex) extruded from x0
## to x1 as _xprism extrudes a strip: [vertices, normals]. Each face's
## outward side comes from the winding, not from a centre (an arch's mouth
## faces into the hollow), and both ends are zipped from the leftmost point
## to the rightmost along the sill and the top, so every triangle spans only
## the outline's neighbouring points (true on a side rounded in plan).
static func _extrude(p: PackedVector2Array, f: Array, x0: float, x1: float, ch: float, rnd: Array, roll: float) -> Array:
	var d := []
	for fl in f:
		d.append(ch if fl else 0.0)
	var pin := _inset(p, d)
	var rings := [_xring(pin, x0, 1.0, rnd), _xring(p, x0 + ch, 1.0, rnd), _xring(p, x1 - ch, -1.0, rnd), _xring(pin, x1, -1.0, rnd)]
	if ch <= 0.0:
		# (no chamfers: a plain extrusion, one band)
		rings = [_xring(p, x0, 1.0, rnd), _xring(p, x1, -1.0, rnd)]
	var nb := rings.size() - 1
	var n := p.size()
	var fn := PackedVector3Array()
	fn.resize(nb * n)
	for i in nb:
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		for j in n:
			var j1 := (j + 1) % n
			var e := (p[j1] - p[j]).normalized()
			var ref := Vector3(0.0 if nb == 1 else 0.5 * float(i - 1), -e.x, e.y)
			var v := (r1[j1] - r0[j]).cross(r0[j1] - r1[j])
			if v.length_squared() < 1e-14:
				v = ref
			v = v.normalized()
			if v.dot(ref) < 0.0:
				v = -v
			fn[i * n + j] = v
	var cs := cos(deg_to_rad(roll))
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	for i in nb:
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		for j in n:
			var j1 := (j + 1) % n
			var fc := fn[i * n + j]
			var na := fc
			var nn := fc
			var nc := fc
			var nd := fc
			if roll > 0.0:
				na = VehicleProfiles._vn(fn, nb + 1, n, i, j, fc, cs)
				nn = VehicleProfiles._vn(fn, nb + 1, n, i, j1, fc, cs)
				nc = VehicleProfiles._vn(fn, nb + 1, n, i + 1, j1, fc, cs)
				nd = VehicleProfiles._vn(fn, nb + 1, n, i + 1, j, fc, cs)
			VehicleProfiles._tri(vs, ns, r0[j], r0[j1], r1[j1], na, nn, nc, fc)
			VehicleProfiles._tri(vs, ns, r0[j], r1[j1], r1[j], na, nc, nd, fc)
	for e in [0, nb]:
		_zip(vs, ns, pin, rings[e], Vector3(-1.0 if e == 0 else 1.0, 0.0, 0.0))
	return [vs, ns]


## A counter-clockwise outline's end face (`ring` its points in 3D, facing
## `out`), zipped along its lower and upper chains from the leftmost point to
## the rightmost: each triangle joins neighbours, so it stays inside an
## outline whose top is convex however its underside is cut.
static func _zip(vs: PackedVector3Array, ns: PackedVector3Array, p: PackedVector2Array, ring: PackedVector3Array, out: Vector3) -> void:
	var n := p.size()
	var lo := 0
	var hi := 0
	for i in n:
		var q := p[i]
		if q.x < p[lo].x - 1e-6 or (absf(q.x - p[lo].x) <= 1e-6 and q.y < p[lo].y):
			lo = i
		if q.x > p[hi].x + 1e-6 or (absf(q.x - p[hi].x) <= 1e-6 and q.y > p[hi].y):
			hi = i
	var lower: Array[int] = []
	var i := lo
	while true:
		lower.append(i)
		if i == hi:
			break
		i = (i + 1) % n
	var upper: Array[int] = []
	i = lo
	while true:
		upper.append(i)
		if i == hi:
			break
		i = (i - 1 + n) % n
	var a := 0
	var b := 0
	while a < lower.size() - 1 or b < upper.size() - 1:
		var t0: int
		var t1: int
		var t2: int
		if b == upper.size() - 1 or (a < lower.size() - 1 and p[lower[a + 1]].x <= p[upper[b + 1]].x):
			t0 = lower[a]
			t1 = lower[a + 1]
			t2 = upper[b]
			a += 1
		else:
			t0 = lower[a]
			t1 = upper[b + 1]
			t2 = upper[b]
			b += 1
		if t0 == t1 or t1 == t2 or t0 == t2:
			continue
		var c := (ring[t1] - ring[t0]).cross(ring[t2] - ring[t0])
		if c.length_squared() < 1e-14:
			continue
		c = c.normalized()
		if c.dot(out) < 0.0:
			c = -c
		VehicleProfiles._tri(vs, ns, ring[t0], ring[t1], ring[t2], c, c, c, c)


## A band round an axle at (zc, yc), r0 to r1 out, from angle a0 to a1 (within
## 0 to PI) in `segs` segments, extruded x0 to x1 as one outline (_extrude),
## chamfered by `ch` all round (none at 0), shaded round from segment to
## segment (FLARE_ROLL). Cached by its shape.
static func _arc_band(zc: float, yc: float, r0: float, r1: float, a0: float, a1: float, segs: int, x0: float, x1: float, ch: float) -> ArrayMesh:
	var mk := var_to_str(["band", zc, yc, r0, r1, a0, a1, segs, x0, x1, ch])
	var mesh: ArrayMesh = _plates.get(mk)
	if mesh != null:
		return mesh
	var band := PackedVector2Array()
	for i in segs + 1:
		var t := lerpf(a0, a1, float(i) / segs)
		band.append(Vector2(zc + r0 * cos(t), yc + r0 * sin(t)))
	for i in segs + 1:
		var t := lerpf(a1, a0, float(i) / segs)
		band.append(Vector2(zc + r1 * cos(t), yc + r1 * sin(t)))
	var flags := []
	for i in band.size():
		flags.append(ch > 0.0)
	var st := _ccw([band, flags, 0.0, 0.0])
	var arr := _extrude(st[0], st[1], x0, x1, ch, [], FLARE_ROLL)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = arr[0]
	arrays[Mesh.ARRAY_NORMAL] = arr[1]
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(mesh, arrays)
	_plates[mk] = mesh
	return mesh


## A wheel-arch flare: a band round the arch from angle a0 to a1 (0 is the
## rear, PI the front), r0 to r1 from the axle, x0 to x1 across.
static func _flare(k: VehicleModels, parent: Node3D, key: String, zc: float, yc: float, r0: float, r1: float, x0: float, x1: float, a0: float, a1: float, mat: String, col = null, segs := 6) -> void:
	liner(k, parent, zc, yc, r0, x0, x1, a0, a1, segs)
	if not k.wreck and a0 >= 0.0 and a1 <= PI:
		# An arch extension is moulded in one piece, a smooth curve round the
		# tyre that the light runs along: one outline (_extrude), its faces
		# rolled from segment to segment (they meet at 20-30 degrees) and its
		# chamfers left crisp. Segment by segment it was a ring of flat
		# facets, hidden walls between them. (A wreck keeps its segments.)
		k._add(parent, _arc_band(zc, yc, r0, r1, a0, a1, segs, x0, x1, minf(0.012, (x1 - x0) * 0.3)), mat, col, Vector3.ZERO)
		return
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
## A live one is moulded in one piece, its inside shading round the tyre (the
## old segments, each a mesh of its own size, stay on wrecks).
static func liner(k: VehicleModels, parent: Node3D, zc: float, yc: float, radius: float, x0: float, x1: float, a0: float, a1: float, segments: int) -> void:
	if not k.wreck and a0 >= 0.0 and a1 <= PI:
		k._add(parent, _arc_band(zc, yc, radius + 0.002, radius + 0.018, a0, a1, segments, x0, x1, 0.0), "rubber", null, Vector3.ZERO)
		return
	for i in segments:
		var a := lerpf(a0, a1, float(i) / segments)
		var b := lerpf(a0, a1, float(i + 1) / segments)
		var points := [zc + (radius + 0.002) * cos(a), yc + (radius + 0.002) * sin(a), zc + (radius + 0.002) * cos(b), yc + (radius + 0.002) * sin(b), zc + (radius + 0.018) * cos(b), yc + (radius + 0.018) * sin(b), zc + (radius + 0.018) * cos(a), yc + (radius + 0.018) * sin(a)]
		k._add(parent, VehicleModels.extrude_x("liner_" + var_to_str([points, x0, x1]), points, x0, x1), "rubber", null, Vector3.ZERO)
