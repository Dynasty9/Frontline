class_name VmAttack
extends RefCounted
## Procedural models: ground-attack jets - the A-10 and the A-164 Wipeout.
## Conventions as in VmPlane (read its header): local -Z is forward, y = 0 is
## the ground, metres; built in flight with the gear up, round the fuselage.
## Landing gear goes under a child Node3D named "Gear", hidden by default (the
## Field Manual and the model sheets show it, standing the aircraft on it).
##
## The A-10's main wheels ride half out of their pods even when retracted:
## those tyres sit in a "GearUp" node that hides itself whenever "Gear" is
## shown, so the jet on its gear shows each wheel once.

## Every model key this file builds.
const KEYS: Array[String] = ["a10", "wipeout"]

## The A-10C's Compass Ghost: Light Ghost Grey (FS 36375) over most of the
## airframe, Dark Ghost Grey (FS 36320) over the top, Gunship Grey (FS 36118)
## for the false canopy under the nose; low-visibility black markings.
const GHOST_LIGHT := Color(0.45, 0.48, 0.51)
const GHOST_DARK := Color(0.34, 0.37, 0.41)
const GUNSHIP := Color(0.22, 0.235, 0.24)
const LOWVIS := Color(0.08, 0.085, 0.09)
## A Rebel-flown airframe: CSAT's sandy grey.
const CSAT_A := Color(0.47, 0.44, 0.38)
## Modern stores: light grey missiles and pods, olive bomb bodies.
const STORE_LIGHT := Color(0.6, 0.61, 0.6)
const STORE_MID := Color(0.47, 0.49, 0.5)

static var _mc := {}


## Builds the model for `key` into k; false if this file doesn't (yet) know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"a10":
			_a10(k, team, seed)
		"wipeout":
			_wipeout(k, team, seed)
		_:
			return false
	return true


# --- mesh helpers ------------------------------------------------------------------

## A surface of revolution about local z through the profile (Vector2(r, z)
## points in order). The side a face shows is the right of the direction of
## travel: trace an intake from deep in its duct, out over the lip and aft
## along the cowl, and every face looks the right way. Smooth round the axis,
## creased where the profile turns sharper than `crease` degrees. Cached.
static func _lathe(key: String, prof: Array, segs := 24, crease := 50.0) -> ArrayMesh:
	var kk := "at_" + key
	if _mc.has(kk):
		return _mc[kk]
	var np := prof.size()
	var sn: Array[Vector2] = []
	for i in np - 1:
		var d: Vector2 = (prof[i + 1] as Vector2) - (prof[i] as Vector2)
		sn.append(Vector2(d.y, -d.x).normalized() if d.length() > 1e-6 else Vector2(1, 0))
	var cs := cos(deg_to_rad(crease))
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	for i in np - 1:
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[i + 1]
		if a.distance_to(b) < 1e-6:
			continue
		# the normal at each end: shared with the neighbour unless it turns sharply
		var na := sn[i]
		if i > 0 and sn[i - 1].dot(sn[i]) > cs:
			na = (sn[i - 1] + sn[i]).normalized()
		var nb := sn[i]
		if i < np - 2 and sn[i + 1].dot(sn[i]) > cs:
			nb = (sn[i + 1] + sn[i]).normalized()
		for j in segs:
			var t0 := TAU * float(j) / float(segs)
			var t1 := TAU * float(j + 1) / float(segs)
			var c0 := Vector2(cos(t0), sin(t0))
			var c1 := Vector2(cos(t1), sin(t1))
			var p0 := Vector3(c0.x * a.x, c0.y * a.x, a.y)
			var p1 := Vector3(c1.x * a.x, c1.y * a.x, a.y)
			var p2 := Vector3(c1.x * b.x, c1.y * b.x, b.y)
			var p3 := Vector3(c0.x * b.x, c0.y * b.x, b.y)
			var n0 := Vector3(c0.x * na.x, c0.y * na.x, na.y)
			var n1 := Vector3(c1.x * na.x, c1.y * na.x, na.y)
			var n2 := Vector3(c1.x * nb.x, c1.y * nb.x, nb.y)
			var n3 := Vector3(c0.x * nb.x, c0.y * nb.x, nb.y)
			var f := (n0 + n1 + n2 + n3).normalized()
			VmPlane._tri(vs, ns, p0, p1, p2, n0, n1, n2, f)
			VmPlane._tri(vs, ns, p0, p2, p3, n0, n2, n3, f)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	Mats.keep_arrays(am, arr)
	_mc[kk] = am
	return am


## A faceted ring at z: the right half of a section given as points (x >= 0)
## from the foot of the centre line up to its top, mirrored about x = 0, then
## moved to (cx, cy). A raked ring (an intake's lip) moves aft by rake.y per
## metre above the centre and rake.x per metre towards side `sd`.
static func _hring(z: float, cx: float, cy: float, half: Array, rake := Vector2.ZERO, sd := 1.0) -> PackedVector3Array:
	var pts: Array[Vector2] = []
	for q in half:
		pts.append(q as Vector2)
	for i in range(half.size() - 2, 0, -1):
		var q: Vector2 = half[i]
		pts.append(Vector2(-q.x, q.y))
	var r := PackedVector3Array()
	for q in pts:
		r.append(Vector3(cx + q.x, cy + q.y, z + q.y * rake.y + q.x * sd * rake.x))
	return r


## A faceted section's half: the flat belly out to bw, the lower flank up to
## the chine (w wide, at the centre's height), the upper flank in to the deck
## (tw wide, ht up), a ridge `rd` proud along the top.
static func _facet(w: float, ht: float, hb: float, tw: float, bw: float, rd := 0.0) -> Array:
	return [Vector2(0, -hb), Vector2(bw, -hb), Vector2(w, 0), Vector2(tw, ht), Vector2(0, ht + rd)]


## An open loft between rings (no caps), each quad flat-shaded and facing away
## from the rings' axis (towards it with `inward`; or towards `face` when set,
## for a lip joining an outer ring to an inner one): ducts, lips, nozzles.
static func _sheet(key: String, rings: Array, inward := false, face := Vector3.ZERO) -> ArrayMesh:
	var kk := "at_" + key
	if _mc.has(kk):
		return _mc[kk]
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	for i in rings.size() - 1:
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var c := (VehicleModels._centroid(r0) + VehicleModels._centroid(r1)) * 0.5
		var n := r0.size()
		for j in n:
			var j1 := (j + 1) % n
			var a := r0[j]
			var b := r0[j1]
			var cc := r1[j1]
			var d := r1[j]
			var mid := (a + b + cc + d) * 0.25
			var f := (cc - a).cross(b - d)
			if f.length_squared() < 1e-14:
				continue
			f = f.normalized()
			# away from the axis (measured across the ring, not along it)
			var radial := mid - c if face == Vector3.ZERO else face
			if f.dot(radial) < 0.0:
				f = -f
			if inward:
				f = -f
			VmPlane._tri(vs, ns, a, b, cc, f, f, f, f)
			VmPlane._tri(vs, ns, a, cc, d, f, f, f, f)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	Mats.keep_arrays(am, arr)
	_mc[kk] = am
	return am


## Painted markings: 2D polygons (each star-shaped about its centroid) laid on
## the airframe by `to3` (a Callable from Vector2 to the point on the skin,
## already lifted off it), facing `out`. One mesh, no shadow; cached by key.
static func _decal(k: VehicleModels, p: Node3D, key: String, polys: Array, to3: Callable, out: Vector3, col: Color, mat := "paint") -> void:
	if k.burnt:
		return
	var kk := "at_" + key
	var am: ArrayMesh = _mc.get(kk)
	if am == null:
		var vs := PackedVector3Array()
		var ns := PackedVector3Array()
		for poly in polys:
			var cc := Vector2.ZERO
			for q in poly:
				cc += q as Vector2
			cc /= float(poly.size())
			var pc: Vector3 = to3.call(cc)
			var p3: Array[Vector3] = []
			for q in poly:
				p3.append(to3.call(q) as Vector3)
			for i in p3.size():
				var a := p3[i]
				var b := p3[(i + 1) % p3.size()]
				var f := (b - a).cross(pc - a)
				if f.length_squared() < 1e-14:
					continue
				if f.dot(out) < 0.0:
					f = -f
				f = f.normalized()
				VmPlane._tri(vs, ns, pc, a, b, f, f, f, f)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vs
		arr[Mesh.ARRAY_NORMAL] = ns
		am = ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		Mats.keep_arrays(am, arr)
		_mc[kk] = am
	k._add(p, am, mat, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)


## Strokes [a, b] (Vector2 pairs) of width lw as quads, cut into pieces no
## longer than `piece` so they follow a curved skin.
static func _strokes(strokes: Array, lw: float, piece := 0.12) -> Array:
	var out: Array = []
	for s in strokes:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var d := (b - a).normalized()
		var nn := Vector2(-d.y, d.x) * lw * 0.5
		a -= d * lw * 0.5
		b += d * lw * 0.5
		var n := maxi(1, ceili(a.distance_to(b) / piece))
		for i in n:
			var p0 := a.lerp(b, float(i) / n)
			var p1 := a.lerp(b, float(i + 1) / n)
			out.append([p0 - nn, p1 - nn, p1 + nn, p0 + nn])
	return out


## A saw-toothed seam from a to b: n teeth, each `depth` deep (the stealthy
## edge of a door or panel).
static func _zigzag(a: Vector2, b: Vector2, n: int, depth: float) -> Array:
	var d := (b - a) / float(n)
	var nn := Vector2(-d.y, d.x).normalized() * depth
	var out: Array = []
	for i in n:
		var p0 := a + d * i
		var p1 := p0 + d * 0.5 + nn
		out.append([p0, p1])
		out.append([p1, p0 + d])
	return out


## Seven-segment strokes in a 1 x 1 cell (plus "i", a centre upright).
const SEGS := {"a": [0.0, 1.0, 1.0, 1.0], "b": [1.0, 1.0, 1.0, 0.5], "c": [1.0, 0.5, 1.0, 0.0], "d": [0.0, 0.0, 1.0, 0.0],
	"e": [0.0, 0.0, 0.0, 0.5], "f": [0.0, 0.5, 0.0, 1.0], "g": [0.0, 0.5, 0.85, 0.5], "i": [0.5, 0.0, 0.5, 1.0]}
const GLYPHS := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc",
	"8": "abcdefg", "9": "abcdfg", "A": "abcefg", "F": "afeg", "T": "ai", "-": "g", "C": "afed", "E": "afedg", "U": "bcdef", "S": "afgcd"}


## Stencil lettering: `text` h tall, centred on (cx, cy), as stroke quads.
static func _text(text: String, h: float, cx: float, cy: float) -> Array:
	var cw := h * 0.58
	var adv := cw + h * 0.28
	var total := adv * text.length() - h * 0.28
	var st: Array = []
	for i in text.length():
		var ch := text[i]
		if not GLYPHS.has(ch):
			continue
		var x0 := cx - total * 0.5 + adv * i
		for sname in String(GLYPHS[ch]):
			var s: Array = SEGS[sname]
			st.append([Vector2(x0 + float(s[0]) * cw, cy - h * 0.5 + float(s[1]) * h), Vector2(x0 + float(s[2]) * cw, cy - h * 0.5 + float(s[3]) * h)])
	return _strokes(st, h * 0.13, h * 0.2)


## The low-visibility star-and-bar: the circle, the star and the two bars
## drawn in outline, radius r, centred on (cx, cy).
static func _star_bar(r: float, cx: float, cy: float, lw: float) -> Array:
	var o := Vector2(cx, cy)
	var polys: Array = []
	var n := 28
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		polys.append([o + d0 * (r - lw), o + d1 * (r - lw), o + d1 * r, o + d0 * r])
	var st: Array = []
	var pts: Array[Vector2] = []
	for i in 10:
		var a := PI / 2 + TAU * i / 10.0
		pts.append(o + Vector2(cos(a), sin(a)) * (r * 0.93 if i % 2 == 0 else r * 0.36))
	for i in 10:
		st.append([pts[i], pts[(i + 1) % 10]])
	# the bars: upper edge level with the star's arms, a radius long beyond the ring
	var yt := r * 0.31
	var yb := -r * 0.36
	for sd in [-1.0, 1.0]:
		var xt := r * cos(asin(0.31))
		var xb := r * cos(asin(0.36))
		st.append([o + Vector2(sd * xt, yt), o + Vector2(sd * r * 2.0, yt)])
		st.append([o + Vector2(sd * r * 2.0, yt), o + Vector2(sd * r * 2.0, yb)])
		st.append([o + Vector2(sd * r * 2.0, yb), o + Vector2(sd * xb, yb)])
	polys.append_array(_strokes(st, lw, 0.15))
	return polys


## A point on a lofted body's skin (stations as VmPlane.body) at z, at section
## angle `ang` (0 the right side's widest point, PI/2 the top), `grow` proud.
static func _sec_pt(st: Array, z: float, ang: float, grow := 0.0) -> Vector3:
	var q := VmPlane.st_at(st, z)
	var c := cos(ang)
	var s := sin(ang)
	var e: float = q[5] if s >= 0.0 else q[6]
	var px := (float(q[2]) + grow) * signf(c) * pow(absf(c), 2.0 / e)
	var py := (float(q[3] if s >= 0.0 else q[4]) + grow) * signf(s) * pow(absf(s), 2.0 / e)
	return Vector3(float(q[7]) + px, float(q[1]) + py, z)


## The height of a body's skin above (top) or below at (x, z).
static func _skin_y(st: Array, z: float, x: float, top: bool) -> float:
	var q := VmPlane.st_at(st, z)
	var w: float = q[2]
	var t := clampf(absf(x - float(q[7])) / maxf(w, 1e-4), 0.0, 1.0)
	var e: float = q[5] if top else q[6]
	var h: float = q[3] if top else q[4]
	var f := pow(maxf(0.0, 1.0 - pow(t, e)), 1.0 / e)
	return float(q[1]) + (h * f if top else -h * f)


## The half-width of a body's skin at (y, z): how far out its side is.
static func _skin_x(st: Array, z: float, y: float) -> float:
	var q := VmPlane.st_at(st, z)
	var top := y >= float(q[1])
	var h: float = q[3] if top else q[4]
	var t := clampf(absf(y - float(q[1])) / maxf(h, 1e-4), 0.0, 1.0)
	var e: float = q[5] if top else q[6]
	return float(q[2]) * pow(maxf(0.0, 1.0 - pow(t, e)), 1.0 / e)


## The height of a wing's upper (or lower) skin at (x, z), sections as VmPlane.surf.
static func _wing_y(secs: Array, x: float, z: float, top: bool) -> float:
	var w := VmPlane.surf_at(secs, absf(x))
	var le: Vector3 = w[0]
	var f := clampf((z - le.z) / float(w[1]), 0.0, 1.0)
	var h := float(w[2]) * 0.5 * VmPlane._foil_t(f)
	return le.y + (h if top else -h)


## A fin (sections running up, as VmPlane.surf with a vertical span) at height
## y: [leading edge, chord, thickness].
static func _fin_at(secs: Array, y: float) -> Array:
	for i in secs.size() - 1:
		var a: Array = secs[i]
		var b: Array = secs[i + 1]
		var la: Vector3 = a[0]
		var lb: Vector3 = b[0]
		if y <= lb.y or i == secs.size() - 2:
			var t := clampf((y - la.y) / maxf(1e-4, lb.y - la.y), 0.0, 1.0)
			return [la.lerp(lb, t), lerpf(a[1], b[1], t), lerpf(a[2], b[2], t)]
	return secs[0]


## The "Gear" node (hidden: the Field Manual shows it) and the "GearUp" node
## (shown in flight, hidden whenever the gear is shown). Empty and absent when
## FL_GEAR_UP is set (the model sheets' in-flight look).
static func _gear_nodes(k: VehicleModels, with_up := true) -> Array:
	var up: Node3D = null
	if with_up:
		up = Node3D.new()
		up.name = "GearUp"
		k.root.add_child(up)
	if OS.has_environment("FL_GEAR_UP"):
		return [null, up]
	var gear := Node3D.new()
	gear.name = "Gear"
	gear.visible = false
	k.root.add_child(gear)
	if up:
		var sync := func() -> void:
			up.visible = not gear.visible
		gear.tree_entered.connect(sync)
		gear.visibility_changed.connect(sync)
	return [gear, up]


## A wheel turning about x at pos: the tyre's rounded section, the hub and its
## bolt circle. Not spun by the game (aircraft wheels in flight stay put).
static func _wheel(k: VehicleModels, p: Node3D, key: String, pos: Vector3, r: float, w: float) -> void:
	var prof := [Vector2(r * 0.6, -w * 0.47), Vector2(r * 0.8, -w * 0.5), Vector2(r * 0.94, -w * 0.43), Vector2(r, -w * 0.25),
		Vector2(r, w * 0.25), Vector2(r * 0.94, w * 0.43), Vector2(r * 0.8, w * 0.5), Vector2(r * 0.6, w * 0.47)]
	k._add(p, _lathe(key + "_tyre", prof, 22, 40.0), "rubber", null, pos, Vector3(0, PI / 2, 0))
	k._cyl(p, r * 0.6, r * 0.6, w * 0.92, pos, Vector3(0, 0, PI / 2), "steel", Color(0.55, 0.56, 0.55), 16, false)
	k._cyl(p, r * 0.3, r * 0.34, w * 1.02, pos, Vector3(0, 0, PI / 2), "gunmetal_w", null, 12, false)
	for sd in [-1.0, 1.0]:
		for i in 6:
			var a := TAU * i / 6.0
			k._cyl(p, 0.018, 0.018, 0.03, pos + Vector3(sd * w * 0.5, sin(a) * r * 0.42, cos(a) * r * 0.42), Vector3(0, 0, PI / 2), "gunmetal_w", null, 6, false)


# --- A-10C Thunderbolt II -----------------------------------------------------------

## Fairchild Republic A-10C Thunderbolt II: 16.26 m long, 17.53 m span. The
## GAU-8/A's seven barrels under a blunt nose (a little left of the centre line,
## the nose wheel off to the right), the armoured cockpit high under a bubble
## canopy, a thick straight low wing (a flat centre section, the outer panels
## set up 7 degrees, drooped Hoerner tips) with the main gear in pods on its
## leading edge, two TF34 turbofans in nacelles on stub pylons high on the rear
## fuselage, a straight tailplane with the twin fins at its tips. Eleven
## stations of a close-air-support load. Compass Ghost grey, low-vis markings.
static func _a10(k: VehicleModels, team: int, seed: int) -> void:
	var m := k.root
	var A := "aircraft"
	var c := GHOST_LIGHT if team != 1 else CSAT_A
	var cd := GHOST_DARK if team != 1 else CSAT_A.darkened(0.22)
	var st := [
		[-7.62, 1.2, 0.0, 0.0, 0.0],
		[-7.585, 1.2, 0.17, 0.17, 0.19, 2.0, 2.0],
		[-7.5, 1.21, 0.31, 0.31, 0.35, 2.0, 2.0],
		[-7.32, 1.22, 0.43, 0.42, 0.48, 2.1, 2.1],
		[-7.0, 1.24, 0.52, 0.51, 0.58, 2.2, 2.2],
		[-6.5, 1.26, 0.6, 0.57, 0.66, 2.4, 2.3],
		[-6.0, 1.27, 0.65, 0.6, 0.72, 2.7, 2.3],
		[-5.3, 1.26, 0.69, 0.64, 0.79, 3.0, 2.4],
		[-4.4, 1.25, 0.71, 0.66, 0.8, 3.0, 2.5],
		[-3.3, 1.23, 0.71, 0.68, 0.78, 2.8, 2.5],
		[-1.9, 1.21, 0.69, 0.67, 0.75, 2.6, 2.6],
		[0.0, 1.2, 0.66, 0.65, 0.72, 2.6, 2.6],
		[1.4, 1.24, 0.62, 0.58, 0.64, 2.5, 2.5],
		[3.0, 1.32, 0.54, 0.48, 0.5, 2.4, 2.3],
		[4.6, 1.44, 0.42, 0.36, 0.32, 2.3, 2.2],
		[6.0, 1.56, 0.3, 0.24, 0.2],
		[7.0, 1.64, 0.19, 0.15, 0.12],
		[7.7, 1.68, 0.08, 0.08, 0.06],
		[7.9, 1.69, 0.02, 0.03, 0.02],
	]
	VmPlane.body(k, m, "at_a10_fus", st, A, c, 24)
	# Compass Ghost: the darker grey over the nose and cockpit, down the spine
	VmPlane.stripe(k, m, "at_a10_dk0", st, -7.45, -2.4, -0.42, PI + 0.42, A, cd, 0.005, 44)
	VmPlane.stripe(k, m, "at_a10_dk1", st, -2.4, 7.6, 0.55, PI - 0.55, A, cd, 0.005, 24)
	# panel joints round the fuselage
	for z in [-6.75, -5.95, -3.0, -1.95, 1.3, 3.15, 4.9, 6.4]:
		VmPlane.band(k, m, "at_a10_j%d" % int(z * 100), st, z, 0.022, 0.006, A, c.darkened(0.28), 24)
	_a10_cockpit(k, m, st, c, cd)
	_a10_gun(k, m, st, c)
	var ws := _a10_wing(k, m, c)
	_a10_engines(k, m, st, c)
	_a10_tail(k, m, c, team, seed)
	_a10_gear(k, m, st, c)
	_a10_stores(k, m, ws, c)
	_a10_details(k, m, st, ws, c, team)


## The cockpit: the flat armoured windscreen and its heavy frame, the big
## clamshell bubble, the canopy rails, the fairing sweeping back down the spine;
## the boarding ladder's door and the refuelling receptacle on the nose.
static func _a10_cockpit(k: VehicleModels, m: Node3D, st: Array, c: Color, cd: Color) -> void:
	var A := "aircraft"
	var cst := [
		[-6.08, 1.84, 0.4, 0.03, 0.12, 2.0, 2.0],
		[-5.8, 1.84, 0.5, 0.33, 0.12, 2.2, 2.0],
		[-5.3, 1.85, 0.55, 0.62, 0.12, 2.3, 2.0],
		[-4.6, 1.86, 0.56, 0.82, 0.12, 2.3, 2.0],
		[-3.9, 1.86, 0.53, 0.74, 0.12, 2.3, 2.0],
		[-3.35, 1.86, 0.45, 0.5, 0.12, 2.2, 2.0],
		[-2.9, 1.86, 0.32, 0.22, 0.12, 2.0, 2.0],
	]
	VmPlane.body(k, m, "at_a10_can", cst, "glass", null, 24, 60.0)
	# the windscreen bow, the canopy's own front and rear frames
	VmPlane.band(k, m, "at_a10_bow", cst, -5.32, 0.09, 0.022, A, cd.darkened(0.25), 24)
	VmPlane.band(k, m, "at_a10_cfr", cst, -5.17, 0.05, 0.016, A, cd.darkened(0.15), 24)
	VmPlane.band(k, m, "at_a10_crr", cst, -2.98, 0.08, 0.018, A, cd.darkened(0.15), 24)
	# the windscreen's two corner posts: a flat front panel and side quarter lights
	for sd in [-1.0, 1.0]:
		var a0: float = PI / 2 - sd * 0.62
		VmPlane.rod(k, m, _sec_pt(cst, -6.02, a0 - sd * 0.25, 0.01), _sec_pt(cst, -5.32, a0, 0.012), 0.022, A, cd.darkened(0.25), 6)
	# the canopy rails along both sills
	for sd in [-1.0, 1.0]:
		var a := 0.0 if sd > 0.0 else PI
		VmPlane.stripe(k, m, "at_a10_rail" + ("L" if sd < 0.0 else ""), cst, -6.05, -2.92, a - 0.12, a + 0.12, A, cd.darkened(0.3), 0.012, 4)
	# the fairing behind the canopy, down into the spine
	var dst := [[-3.4, 1.84, 0.44, 0.48, 0.14, 2.2, 2.0], [-2.6, 1.82, 0.42, 0.36, 0.14, 2.2, 2.0], [-1.2, 1.78, 0.36, 0.2, 0.14, 2.3, 2.0],
		[0.2, 1.74, 0.28, 0.12, 0.14, 2.3, 2.0], [1.4, 1.72, 0.16, 0.04, 0.14, 2.0, 2.0]]
	VmPlane.body(k, m, "at_a10_deck", dst, A, cd, 18)
	VmPlane.band(k, m, "at_a10_deckj", dst, -1.5, 0.02, 0.005, A, cd.darkened(0.3), 18)
	# the refuelling receptacle (UARRSI) on the nose, its slipway lines
	var rz := -6.95
	var ry := _skin_y(st, rz, 0.0, true)
	k._box(m, Vector3(0.3, 0.06, 0.55), Vector3(0, ry + 0.005, rz), A, cd.darkened(0.1), Vector3(-0.22, 0, 0))
	k._box(m, Vector3(0.12, 0.05, 0.3), Vector3(0, ry + 0.03, rz - 0.04), "plain_dark", null, Vector3(-0.22, 0, 0), false)
	_decal(k, m, "a10_slip", _strokes([[Vector2(-0.16, 0.0), Vector2(-0.07, 0.75)], [Vector2(0.16, 0.0), Vector2(0.07, 0.75)]], 0.025),
		func(q: Vector2) -> Vector3: return Vector3(q.x, _skin_y(st, rz + 0.3 + q.y, q.x, true) + 0.008, rz + 0.3 + q.y), Vector3.UP, Color(0.85, 0.85, 0.8))
	# the boarding ladder's door under the left canopy rail
	_decal(k, m, "a10_ladder", _strokes([[Vector2(0, 0), Vector2(0.55, 0)], [Vector2(0.55, 0), Vector2(0.55, 0.3)], [Vector2(0.55, 0.3), Vector2(0, 0.3)], [Vector2(0, 0.3), Vector2(0, 0)]], 0.014),
		func(q: Vector2) -> Vector3: return Vector3(-_skin_x(st, -4.9 + q.x, 1.05 + q.y) - 0.006, 1.05 + q.y, -4.9 + q.x), Vector3.LEFT, c.darkened(0.4))


## The GAU-8/A Avenger: seven barrels round a turning cluster, the muzzle clamp
## near their ends, the dark gun port they come out of, soot behind it.
static func _a10_gun(k: VehicleModels, m: Node3D, st: Array, c: Color) -> void:
	var gz := Vector3(-0.1, 0.88, 0.0)
	# the gun port: a dark recess in the nose's lower face
	k._cyl(m, 0.21, 0.24, 0.5, gz + Vector3(0, 0, -7.25), Vector3(PI / 2, 0, 0), "plain_dark", null, 16)
	k._cyl(m, 0.23, 0.23, 0.04, gz + Vector3(0, 0, -7.48), Vector3(PI / 2, 0, 0), "aircraft", c.darkened(0.3), 16, false)
	for i in 7:
		var a := TAU * float(i) / 7.0 + 0.2
		var o := Vector3(cos(a) * 0.105, sin(a) * 0.105, 0)
		VmPlane.rod(k, m, gz + o + Vector3(0, 0, -7.2), gz + o + Vector3(0, 0, -8.12), 0.032, "gunmetal_w", null, 8, 0.029)
		# the muzzle bore
		k._cyl(m, 0.016, 0.016, 0.02, gz + o + Vector3(0, 0, -8.125), Vector3(PI / 2, 0, 0), "plain_dark", null, 6, false)
	# the barrel clamp and the mid support ring
	k._cyl(m, 0.155, 0.155, 0.09, gz + Vector3(0, 0, -7.92), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 18)
	k._cyl(m, 0.15, 0.15, 0.05, gz + Vector3(0, 0, -7.6), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 18, false)
	k._cyl(m, 0.06, 0.06, 0.94, gz + Vector3(0, 0, -7.66), Vector3(PI / 2, 0, 0), "metal_dark", null, 10, false)
	k.mg_tip = k._tip(m, gz + Vector3(0, 0, -8.2))
	k.gun_tip = k.mg_tip
	# gun gas soot fanning back under the nose
	var soot := []
	for i in 9:
		var a := lerpf(-0.95, 0.95, i / 8.0)
		soot.append(Vector2(sin(a) * 0.42 * (1.0 + 0.3 * absf(a)), -cos(a) * 0.5 + 0.5))
	var sp := []
	for i in 9:
		sp.append(Vector2(soot[i].x, soot[i].y * 1.9))
	sp.append(Vector2(0, 0))
	_decal(k, m, "a10_soot", [sp], func(q: Vector2) -> Vector3: return Vector3(q.x - 0.06, _skin_y(st, -7.2 + q.y, q.x - 0.06, false) - 0.006, -7.2 + q.y), Vector3.DOWN, Color(0.2, 0.2, 0.2))


## The wing: a flat constant-chord centre section, outer panels with 7 degrees
## of dihedral tapering to drooped Hoerner tips; flaps inboard, the split
## ailerons (decelerons) outboard. Returns its sections.
static func _a10_wing(k: VehicleModels, m: Node3D, c: Color) -> Array:
	var A := "aircraft"
	var ws := [[Vector3(0.5, 0.8, -1.85), 3.0, 0.48], [Vector3(3.5, 0.8, -1.85), 3.0, 0.46], [Vector3(6.2, 1.13, -1.75), 2.45, 0.36],
		[Vector3(8.45, 1.41, -1.65), 1.92, 0.26]]
	VmPlane.surf(k, m, "at_a10_wing", ws, A, c, [0.74, 0.74, 0.7])
	# the Hoerner tips: the skin curling down at the ends
	VmPlane.surf(k, m, "at_a10_htip", [[Vector3(8.44, 1.41, -1.65), 1.92, 0.26], [Vector3(8.66, 1.33, -1.6), 1.82, 0.16], [Vector3(8.77, 1.17, -1.5), 1.62, 0.07]], A, c, [])
	# the deceleron split line along each aileron's trailing edge
	for sd in [-1.0, 1.0]:
		var a := VmPlane.surf_at(ws, 6.25)
		var b := VmPlane.surf_at(ws, 8.4)
		var pa: Vector3 = (a[0] as Vector3) + Vector3(0, 0, float(a[1]) * 0.985)
		var pb: Vector3 = (b[0] as Vector3) + Vector3(0, 0, float(b[1]) * 0.985)
		VmPlane.rod(k, m, Vector3(sd * pa.x, pa.y, pa.z), Vector3(sd * pb.x, pb.y, pb.z), 0.012, "plain_dark", null, 4, -1.0, false)
	# panel lines on the upper skins: the slat and leading-edge panels, the spar
	# joints, the centre-section break, the walkway
	for sd in [-1.0, 1.0]:
		var lines := []
		for x in [0.8, 3.5, 5.0, 6.2, 7.4]:
			var w := VmPlane.surf_at(ws, x)
			var le: Vector3 = w[0]
			lines.append([Vector2(x, le.z + 0.05), Vector2(x, le.z + float(w[1]) * 0.72)])
		for f in [0.13, 0.45]:
			var pts := []
			for x in [0.75, 3.5, 6.2, 8.4]:
				var w := VmPlane.surf_at(ws, x)
				pts.append(Vector2(x, (w[0] as Vector3).z + float(w[1]) * f))
			for i in 3:
				lines.append([pts[i], pts[i + 1]])
		_decal(k, m, "a10_wlines" + ("L" if sd < 0.0 else ""), _strokes(lines, 0.016, 0.3),
			func(q: Vector2) -> Vector3: return Vector3(sd * q.x, _wing_y(ws, q.x, q.y, true) + 0.007, q.y), Vector3.UP, c.darkened(0.3))
		# the black no-step walkway outline by the root
		var wk := [[Vector2(0.75, -1.5), Vector2(1.55, -1.5)], [Vector2(1.55, -1.5), Vector2(1.55, 0.5)], [Vector2(0.75, 0.5), Vector2(1.55, 0.5)]]
		_decal(k, m, "a10_walk" + ("L" if sd < 0.0 else ""), _strokes(wk, 0.03, 0.3),
			func(q: Vector2) -> Vector3: return Vector3(sd * q.x, _wing_y(ws, q.x, q.y, true) + 0.009, q.y), Vector3.UP, LOWVIS)
	return ws


## The engines: TF34 turbofans in fat round nacelles high on the rear fuselage,
## raked a little nose-up, each on a stub pylon. Deep intakes with the fan and
## its spinner inside, the fan duct's nozzle, the core cowl and exhaust plug
## behind; the faint glow of the exhaust.
static func _a10_engines(k: VehicleModels, m: Node3D, st: Array, c: Color) -> void:
	var A := "aircraft"
	var tilt := 0.06
	var duct := [Vector2(0.46, 0.66), Vector2(0.49, 0.15), Vector2(0.52, 0.045)]
	var nac := [Vector2(0.52, 0.04), Vector2(0.56, 0.0), Vector2(0.6, 0.03), Vector2(0.64, 0.18),
		Vector2(0.665, 0.55), Vector2(0.67, 1.2), Vector2(0.665, 2.3), Vector2(0.64, 2.85), Vector2(0.6, 3.18), Vector2(0.565, 3.32),
		Vector2(0.54, 3.3), Vector2(0.51, 3.05)]
	var core := [Vector2(0.43, 2.95), Vector2(0.43, 3.32), Vector2(0.4, 3.62), Vector2(0.35, 3.86), Vector2(0.33, 3.9), Vector2(0.3, 3.88), Vector2(0.29, 3.8)]
	var plug := [Vector2(0.27, 3.7), Vector2(0.25, 3.95), Vector2(0.17, 4.18), Vector2(0.06, 4.33), Vector2(0.0, 4.36)]
	var spin := [Vector2(0.0, 0.3), Vector2(0.06, 0.36), Vector2(0.13, 0.48), Vector2(0.17, 0.6), Vector2(0.17, 0.64)]
	var b := Basis.from_euler(Vector3(tilt, 0, 0))
	var glows := []
	for sd in [-1.0, 1.0]:
		var pos := Vector3(sd * 1.52, 2.42, 1.12)
		var rot := Vector3(tilt, 0, 0)
		k._add(m, _lathe("a10_nac", nac, 28, 42.0), A, c, pos, rot)
		k._add(m, _lathe("a10_duct", duct, 28, 42.0), A, c.darkened(0.45), pos, rot)
		k._add(m, _lathe("a10_core", core, 22, 42.0), "gunmetal_w", Color(0.36, 0.36, 0.35), pos, rot)
		k._add(m, _lathe("a10_plug", plug, 16, 42.0), "metal_dark", null, pos, rot)
		# inside the intake: the fan face, its blades and spinner
		k._cyl(m, 0.465, 0.465, 0.03, pos + b * Vector3(0, 0, 0.64), Vector3(PI / 2 + tilt, 0, 0), "plain_dark", Color(0.05, 0.05, 0.05), 24, false)
		k._add(m, _lathe("a10_spin", spin, 16, 50.0), "metal_dark", null, pos, rot)
		for i in 18:
			var a := TAU * i / 18.0
			var bb := b * Basis(Vector3(0, 0, 1), a) * Basis(Vector3(0, 1, 0), 0.55)
			k._add(m, Res.box(Vector3(0.015, 0.29, 0.1)), "metal_dark", null, pos + b * Vector3(-sin(a) * 0.31, cos(a) * 0.31, 0.6), bb.get_euler(), Vector3.ONE, false)
		# the fan exhaust: the dark annulus between the core cowl and the nozzle
		k._cyl(m, 0.5, 0.5, 0.02, pos + b * Vector3(0, 0, 3.08), Vector3(PI / 2 + tilt, 0, 0), "plain_dark", null, 24, false)
		k._cyl(m, 0.26, 0.26, 0.02, pos + b * Vector3(0, 0, 3.76), Vector3(PI / 2 + tilt, 0, 0), "plain_dark", null, 16, false)
		# cowling joints round the nacelle
		for z in [0.45, 1.25, 2.45]:
			k._cyl(m, 0.675, 0.675, 0.02, pos + b * Vector3(0, 0, z), Vector3(PI / 2 + tilt, 0, 0), A, c.darkened(0.3), 28, false)
		# the pylon from the fuselage shoulder to the nacelle's inner flank
		var root := Vector3(sd * 0.34, _skin_y(st, 2.0, 0.34, true) - 0.06, 1.75)
		var tip := pos + b * Vector3(-sd * 0.5, -0.38, 0.75)
		VmPlane.surf(k, m, "at_a10_epyl" + ("L" if sd < 0.0 else ""), [[root, 2.35, 0.2], [Vector3(tip.x, tip.y, 1.8), 2.0, 0.18]], A, c, [], false)
		glows.append(pos + b * Vector3(0, 0, 4.6))
	VmPlane.glow(k, m, glows, 0.9, Color(0.3, 0.17, 0.1))


## The tail: a straight tailplane on the end of the fuselage with elevators and
## trim tabs, the twin fins at its tips (above and below it, rounded corners)
## with their rudders; the tail code on the fins.
static func _a10_tail(k: VehicleModels, m: Node3D, c: Color, team: int, seed: int) -> void:
	var A := "aircraft"
	var ty := 1.74
	var hs := [[Vector3(0.15, ty, 6.1), 1.9, 0.17], [Vector3(2.88, ty, 6.15), 1.85, 0.14]]
	VmPlane.surf(k, m, "at_a10_stab", hs, A, c, [0.66])
	# the elevator trim tabs
	for sd in [-1.0, 1.0]:
		k._box(m, Vector3(0.7, 0.02, 0.012), Vector3(sd * 0.9, ty, 7.68), "plain_dark", null, Vector3.ZERO, false)
	var fx := 2.92
	var fs := [[Vector3(fx, 1.06, 6.32), 1.5, 0.11], [Vector3(fx, 1.24, 6.08), 1.82, 0.13], [Vector3(fx, ty, 5.98), 2.02, 0.15],
		[Vector3(fx, 3.3, 6.1), 1.98, 0.13], [Vector3(fx, 3.62, 6.28), 1.78, 0.11], [Vector3(fx, 3.82, 6.62), 1.36, 0.08]]
	for sd in [-1.0, 1.0]:
		var ms := []
		for s in fs:
			var le: Vector3 = s[0]
			ms.append([Vector3(sd * le.x, le.y, le.z), s[1], s[2]])
		VmPlane.surf(k, m, "at_a10_fin" + ("L" if sd < 0.0 else ""), ms, A, c, [0.6, 0.6, 0.6, 0.6, 0.6], false)
		# the fin-tip cap and its tail light
		k._box(m, Vector3(0.07, 0.05, 0.3), Vector3(sd * fx, 3.84, 7.85), A, c.darkened(0.2))
		if not k.burnt:
			k._box(m, Vector3(0.05, 0.06, 0.05), Vector3(sd * fx, 3.4, 8.12), "glass", null, Vector3.ZERO, false)
	if team == 1 or k.burnt:
		for sd in [-1.0, 1.0]:
			k._team_mark(m, team, Vector3(sd * (fx + 0.08), 2.7, 7.0), Vector3(0.02, 0.5, 0.5))
		return
	# Moody's "FT" tail code, the serial and a black fin-tip band, both sides
	var serial := "%02d-%03d" % [78 + absi(seed) % 4, 100 + absi(seed * 37) % 800]
	for sd in [-1.0, 1.0]:
		var to3 := func(q: Vector2) -> Vector3:
			var f := _fin_at(fs, q.y)
			var le: Vector3 = f[0]
			var z: float = 7.0 - sd * q.x
			var t := float(f[2]) * 0.5 * VmPlane._foil_t(clampf((z - le.z) / float(f[1]), 0.0, 1.0))
			return Vector3(sd * (fx + t + 0.006), q.y, z)
		var polys := _text("FT", 0.62, 0.0, 2.72)
		polys.append_array(_text("AF " + serial, 0.13, 0.05, 2.2))
		_decal(k, m, "a10_code" + ("L" if sd < 0.0 else ""), polys, to3, Vector3(sd, 0, 0), LOWVIS)
		# (the band runs from just behind the fin's leading edge to the rudder's end)
		var fb := _fin_at(fs, 3.42)
		var bz0: float = (fb[0] as Vector3).z + 0.1
		var bz1: float = (fb[0] as Vector3).z + float(fb[1]) - 0.1
		var band := [[Vector2(sd * (7.0 - bz0), 3.42), Vector2(sd * (7.0 - bz1), 3.42)]]
		_decal(k, m, "a10_finband" + ("L" if sd < 0.0 else ""), _strokes(band, 0.16, 0.25), to3, Vector3(sd, 0, 0), LOWVIS.lightened(0.05))


## The main gear in its pods (the wheels half out even retracted, "GearUp")
## and, in "Gear", the legs let down with the wheels; the nose gear, offset to
## starboard to clear the gun, with its doors.
static func _a10_gear(k: VehicleModels, m: Node3D, st: Array, c: Color) -> void:
	var A := "aircraft"
	var nodes := _gear_nodes(k)
	var gear: Node3D = nodes[0]
	var up: Node3D = nodes[1]
	var gx := 2.62
	for sd in [-1.0, 1.0]:
		var x: float = sd * gx
		var pst := [[-3.32, 0.66, 0.0, 0.0, 0.0, 2, 2, x], [-3.18, 0.65, 0.17, 0.17, 0.19, 2, 2, x], [-2.85, 0.63, 0.3, 0.3, 0.36, 2.1, 2.2, x],
			[-2.25, 0.62, 0.37, 0.34, 0.44, 2.2, 2.4, x], [-1.2, 0.63, 0.38, 0.33, 0.44, 2.3, 2.4, x], [0.0, 0.66, 0.34, 0.27, 0.38, 2.2, 2.3, x],
			[0.85, 0.7, 0.2, 0.16, 0.22, 2, 2, x], [1.28, 0.72, 0.04, 0.05, 0.05, 2, 2, x]]
		VmPlane.body(k, m, "at_a10_pod" + ("L" if sd < 0.0 else ""), pst, A, c, 20)
		VmPlane.band(k, m, "at_a10_podj" + ("L" if sd < 0.0 else ""), pst, -2.9, 0.02, 0.005, A, c.darkened(0.3), 20)
		# the open well along the pod's belly the wheel hangs out of
		k._box(m, Vector3(0.36, 0.06, 1.25), Vector3(x, 0.21, -2.05), "plain_dark", null, Vector3.ZERO, false)
		# the chaff and flare dispensers in the pod's tail
		k._box(m, Vector3(0.2, 0.012, 0.3), Vector3(x, 0.39, 0.55), "plain_dark", null, Vector3(0.18, 0, 0), false)
		# retracted: the tyre a third out of the pod
		_wheel(k, up, "a10_mw", Vector3(x, 0.33, -2.15), 0.455, 0.28)
		if gear == null:
			continue
		# let down: the wheel below and a little aft, the leg slanting from the
		# pod's nose, its drag brace and torque links
		var wp := Vector3(x, -0.165, -1.9)
		_wheel(k, gear, "a10_mw", wp, 0.455, 0.28)
		var lx: float = x - sd * 0.22
		VmPlane.rod(k, gear, Vector3(lx, 0.42, -2.55), Vector3(lx, 0.02, -2.1), 0.085, "steel", Color(0.6, 0.6, 0.58), 10)
		VmPlane.rod(k, gear, Vector3(lx, 0.02, -2.1), wp + Vector3(-sd * 0.22, 0, 0), 0.06, "steel", Color(0.6, 0.6, 0.58), 8)
		VmPlane.rod(k, gear, Vector3(lx, 0.36, -1.5), Vector3(lx, 0.06, -2.1), 0.045, "gunmetal_w", null, 8)
		k._cyl(gear, 0.06, 0.06, 0.26, wp + Vector3(-sd * 0.1, 0, 0), Vector3(0, 0, PI / 2), "steel", Color(0.6, 0.6, 0.58), 10)
	# the nose gear well's doors (closed in flight)
	var nx := 0.36
	_decal(k, m, "a10_ndoor", _strokes([[Vector2(-0.2, -6.55), Vector2(-0.2, -4.95)], [Vector2(0.2, -6.55), Vector2(0.2, -4.95)], [Vector2(-0.2, -6.55), Vector2(0.2, -6.55)],
		[Vector2(-0.2, -4.95), Vector2(0.2, -4.95)], [Vector2(0.0, -6.55), Vector2(0.0, -4.95)]], 0.014, 0.2),
		func(q: Vector2) -> Vector3: return Vector3(nx + q.x, _skin_y(st, q.y, nx + q.x, false) - 0.006, q.y), Vector3.DOWN, c.darkened(0.35))
	if gear == null:
		return
	var nw := Vector3(nx, -0.315, -5.85)
	_wheel(k, gear, "a10_nw", nw, 0.305, 0.2)
	var top := Vector3(nx, _skin_y(st, -5.7, nx, false) + 0.1, -5.7)
	VmPlane.rod(k, gear, top, Vector3(nx, 0.0, -5.82), 0.075, "steel", Color(0.6, 0.6, 0.58), 10)
	for sd in [-1.0, 1.0]:
		VmPlane.rod(k, gear, Vector3(nx + sd * 0.13, 0.02, -5.82), Vector3(nx + sd * 0.13, -0.315, -5.85), 0.035, "steel", Color(0.6, 0.6, 0.58), 6)
	k._box(gear, Vector3(0.3, 0.05, 0.1), Vector3(nx, 0.02, -5.82), "steel", Color(0.6, 0.6, 0.58))
	VmPlane.rod(k, gear, Vector3(nx, _skin_y(st, -5.0, nx, false) + 0.05, -5.0), Vector3(nx, 0.0, -5.75), 0.035, "gunmetal_w", null, 6)
	# the taxi light on the leg
	k._cyl(gear, 0.05, 0.05, 0.06, Vector3(nx, 0.05, -5.9), Vector3(PI / 2, 0, 0), "glass", null, 10, false)
	# the two long well doors hanging open
	for sd in [-1.0, 1.0]:
		var dx: float = nx + sd * 0.22
		var dy := _skin_y(st, -5.75, dx, false)
		k._box(gear, Vector3(0.025, 0.42, 1.5), Vector3(dx + sd * 0.03, dy - 0.2, -5.75), A, c, Vector3(0, 0, sd * 0.12))


## Eleven stations: an ECM pod (ALQ-131) and a rocket pod (LAU-131) outboard on
## the left, a Maverick on a LAU-117, GBU-12s inboard on both sides, empty
## fuselage pylons, two Mavericks on a LAU-88, the Sniper targeting pod and two
## Sidewinders on a dual rail on the right.
static func _a10_stores(k: VehicleModels, m: Node3D, ws: Array, c: Color) -> void:
	for sd in [-1.0, 1.0]:
		for x in [1.55, 3.4, 4.75, 6.0]:
			var w := VmPlane.surf_at(ws, x)
			var le: Vector3 = w[0]
			var at := Vector3(sd * x, _wing_y(ws, x, le.z + float(w[1]) * 0.4, false) + 0.02, le.z + float(w[1]) * 0.42)
			if x < 2.0:
				VmPlane.bomb(k, m, VmPlane.pylon(k, m, at, 1.75, 0.32, c, 0.137), 3.27, 0.137, true)
			elif x < 4.0 and sd < 0.0:
				# a Maverick on a single LAU-117 rail
				var ft := VmPlane.pylon(k, m, at, 1.75, 0.3, c, 0.0)
				k._box(m, Vector3(0.16, 0.13, 2.1), ft + Vector3(0, -0.06, -0.05), "gunmetal_w", Color(0.4, 0.41, 0.4))
				VmPlane.agm(k, m, ft + Vector3(0, -0.32, -0.15), 2.49, 0.152, STORE_LIGHT)
			elif x < 4.0:
				# two Mavericks on the shoulders of a LAU-88
				var ft2 := VmPlane.pylon(k, m, at, 1.75, 0.3, c, 0.0)
				k._box(m, Vector3(0.2, 0.16, 2.2), ft2 + Vector3(0, -0.08, -0.05), "gunmetal_w", Color(0.4, 0.41, 0.4))
				for o in [-1.0, 1.0]:
					k._box(m, Vector3(0.1, 0.07, 1.6), ft2 + Vector3(o * 0.16, -0.16, -0.1), "gunmetal_w", Color(0.4, 0.41, 0.4), Vector3(0, 0, -o * 0.6))
					VmPlane.agm(k, m, ft2 + Vector3(o * 0.3, -0.36, -0.15), 2.49, 0.152, STORE_LIGHT)
			elif x < 5.0 and sd < 0.0:
				VmPlane.rocket_pod(k, m, VmPlane.pylon(k, m, at, 1.5, 0.3, c, 0.2), 1.75, 0.2, STORE_LIGHT)
			elif x < 5.0:
				_sniper(k, m, VmPlane.pylon(k, m, at, 1.5, 0.28, c, 0.16), 2.39, 0.16)
			elif sd < 0.0:
				_ecm_pod(k, m, VmPlane.pylon(k, m, at, 1.4, 0.2, c, 0.27), 2.84)
			else:
				# two Sidewinders on a LAU-105 dual rail
				var ft3 := VmPlane.pylon(k, m, at, 1.3, 0.22, c, 0.0)
				k._box(m, Vector3(0.42, 0.1, 1.3), ft3 + Vector3(0, -0.04, 0.0), "gunmetal_w", Color(0.4, 0.41, 0.4))
				for o in [-1.0, 1.0]:
					VmPlane.missile(k, m, ft3 + Vector3(o * 0.19, -0.2, -0.1), 2.87, 0.064, STORE_LIGHT, true)
	# the fuselage stations either side of the centre line, empty
	for sd in [-1.0, 1.0]:
		VmPlane.pylon(k, m, Vector3(sd * 0.5, 0.5, -0.4), 1.5, 0.2, c, 0.0)


## The Sniper XR targeting pod: a slim tube, the faceted sensor head turning in
## its nose with a dark window, a tapered tail, the adaptor on top.
static func _sniper(k: VehicleModels, p: Node3D, ctr: Vector3, len: float, r: float) -> void:
	var col := STORE_MID
	var st := [[-0.5 * len, 0, r * 0.2, r * 0.2, r * 0.2], [-0.47 * len, 0, r * 0.72, r * 0.72, r * 0.72], [-0.42 * len, 0, r * 0.95, r * 0.95, r * 0.95],
		[-0.36 * len, 0, r, r, r], [0.3 * len, 0, r, r, r], [0.45 * len, 0, r * 0.8, r * 0.8, r * 0.8], [0.5 * len, 0, r * 0.45, r * 0.45, r * 0.45]]
	VmPlane.body(k, p, "at_snp_%.2f" % len, st, "paint", col, 16, 50.0, ctr)
	# the head's joint, its window looking forward and down
	k._cyl(p, r * 1.02, r * 1.02, 0.03, ctr + Vector3(0, 0, -0.36 * len), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 16, false)
	k._box(p, Vector3(r * 1.1, r * 0.9, 0.03), ctr + Vector3(0, -r * 0.2, -0.47 * len), "glass", null, Vector3(-0.5, 0, 0), false)
	k._box(p, Vector3(0.1, 0.08, len * 0.5), ctr + Vector3(0, r + 0.03, 0.0), "gunmetal_w")


## The AN/ALQ-131 jamming pod: deep and narrow, rounded radomes at both ends,
## the equipment bays' seams down its flanks.
static func _ecm_pod(k: VehicleModels, p: Node3D, ctr: Vector3, len: float) -> void:
	var col := STORE_LIGHT
	var st := [[-0.5 * len, 0, 0.05, 0.08, 0.1, 2, 2], [-0.46 * len, 0, 0.11, 0.17, 0.21, 2.2, 2.2], [-0.4 * len, 0, 0.14, 0.22, 0.26, 2.6, 2.6],
		[0.38 * len, 0, 0.14, 0.22, 0.26, 2.6, 2.6], [0.46 * len, 0, 0.11, 0.17, 0.21, 2.2, 2.2], [0.5 * len, 0, 0.05, 0.08, 0.1, 2, 2]]
	VmPlane.body(k, p, "at_ecm_%.2f" % len, st, "paint", col, 16, 50.0, ctr)
	for z in [-0.4, -0.15, 0.15, 0.38]:
		k._box(p, Vector3(0.3, 0.5, 0.02), ctr + Vector3(0, -0.02, z * len), "paint", col.darkened(0.3), Vector3.ZERO, false)
	# the radomes darker
	k._box(p, Vector3(0.22, 0.36, 0.05), ctr + Vector3(0, -0.02, -0.455 * len), "paint", col.darkened(0.15), Vector3.ZERO, false)
	k._box(p, Vector3(0.1, 0.08, len * 0.4), ctr + Vector3(0, 0.25, 0.0), "gunmetal_w")


## Lights, antennas, probes, the false canopy and the national markings.
static func _a10_details(k: VehicleModels, m: Node3D, st: Array, ws: Array, c: Color, team: int) -> void:
	var A := "aircraft"
	# navigation lights on the Hoerner tips, the anti-collision strobes
	VmPlane.nav_lights(k, m, Vector3(8.74, 1.2, -1.15), 0.08)
	if not k.burnt:
		for sd in [-1.0, 1.0]:
			k._box(m, Vector3(0.05, 0.04, 0.09), Vector3(sd * 8.72, 1.18, -0.05), "glass", null, Vector3.ZERO, false)
	# the formation ("slime") lights: pale strips on the nose, the tail and fins
	for sd in [-1.0, 1.0]:
		var nzx := _skin_x(st, -6.3, 1.45) + 0.008
		k._box(m, Vector3(0.012, 0.06, 0.55), Vector3(sd * nzx, 1.45, -6.3), "paint", Color(0.55, 0.62, 0.45), Vector3(0, -sd * 0.08, 0), false)
		var tzx := _skin_x(st, 4.2, 1.55) + 0.008
		k._box(m, Vector3(0.012, 0.06, 0.55), Vector3(sd * tzx, 1.55, 4.2), "paint", Color(0.55, 0.62, 0.45), Vector3(0, sd * 0.12, 0), false)
	# the chaff and flare dispensers under the wing tips
	for sd in [-1.0, 1.0]:
		k._box(m, Vector3(0.18, 0.012, 0.5), Vector3(sd * 8.3, _wing_y(ws, 8.3, -0.9, false) - 0.004, -0.9), "plain_dark", null, Vector3(0, 0, sd * 0.12), false)
	# static dischargers trailing from the ailerons, the elevators and rudders
	var sdis := []
	for x in [7.1, 7.8, 8.35]:
		var w := VmPlane.surf_at(ws, x)
		sdis.append((w[0] as Vector3) + Vector3(0, 0, float(w[1])))
	sdis.append(Vector3(2.7, 1.74, 8.0))
	sdis.append(Vector3(2.92, 3.7, 8.1))
	for sd in [-1.0, 1.0]:
		for te in sdis:
			var t: Vector3 = te * Vector3(sd, 1, 1)
			VmPlane.rod(k, m, t + Vector3(0, 0, -0.05), t + Vector3(0, 0, 0.14), 0.006, "plain_dark", null, 4, -1.0, false)
	# antennas: UHF/VHF blades on the spine and belly, the IFF and TACAN, a GPS dome
	var ac := c.darkened(0.25)
	VmPlane.antenna(k, m, Vector3(0, _skin_y(st, -0.6, 0, true) + 0.08, -0.6), 0.3, false, ac)
	VmPlane.antenna(k, m, Vector3(0, _skin_y(st, 2.4, 0, true), 2.4), 0.22, false, ac)
	VmPlane.antenna(k, m, Vector3(0, _skin_y(st, -2.6, 0, false), -2.6), 0.26, true, ac)
	VmPlane.antenna(k, m, Vector3(0.18, _skin_y(st, 0.6, 0.18, false), 0.6), 0.18, true, ac)
	k._add(m, Res.dome(0.09, 10), A, c.darkened(0.15), Vector3(0, _skin_y(st, -1.8, 0, true) + 0.13, -1.8), Vector3.ZERO, Vector3(1, 0.5, 1.4), false)
	# the angle-of-attack vane and a pitot probe on the nose's flanks
	for sd in [-1.0, 1.0]:
		var px := _skin_x(st, -6.6, 1.32)
		VmPlane.rod(k, m, Vector3(sd * px, 1.32, -6.6), Vector3(sd * (px + 0.16), 1.32, -6.7), 0.012, "gunmetal_w", null, 6, 0.008, false)
	# the false canopy painted under the nose
	var fc := []
	for i in 16:
		var a := TAU * i / 16.0
		var rr := 0.42 * pow(absf(sin(a)), 0.6)
		fc.append(Vector2(signf(sin(a)) * rr, cos(a) * 1.15))
	_decal(k, m, "a10_falsecan", [fc], func(q: Vector2) -> Vector3: return Vector3(q.x, _skin_y(st, -4.55 - q.y, q.x, false) - 0.008, -4.55 - q.y), Vector3.DOWN, GUNSHIP if team != 1 else CSAT_A.darkened(0.5))
	_decal(k, m, "a10_falsebow", _strokes([[Vector2(-0.4, 0.55), Vector2(0.4, 0.55)]], 0.06), func(q: Vector2) -> Vector3: return Vector3(q.x, _skin_y(st, -4.55 - q.y, q.x, false) - 0.012, -4.55 - q.y), Vector3.DOWN, c)
	if team == 1:
		# a Rebel airframe: their identification panels on the wings
		VmPlane.wing_marks(k, m, team, ws, 6.0, 0.8)
		return
	# the low-vis star-and-bar on the nacelles' outer flanks, the upper left and
	# the lower right wing; "USAF" is left off at this size
	var tilt := 0.06
	var b := Basis.from_euler(Vector3(tilt, 0, 0))
	for sd in [-1.0, 1.0]:
		var pos := Vector3(sd * 1.52, 2.42, 1.12)
		var nac := func(q: Vector2) -> Vector3:
			var v := clampf(q.y, -0.64, 0.64)
			return pos + b * Vector3(sd * (sqrt(0.6724 - v * v) + 0.008), v, 1.65 - sd * q.x)
		_decal(k, m, "a10_ins_nac" + ("L" if sd < 0.0 else ""), _star_bar(0.3, 0.0, 0.0, 0.028), nac, Vector3(sd, 0, 0), LOWVIS)
	var wt := func(q: Vector2) -> Vector3: return Vector3(-6.4 + q.x, _wing_y(ws, 6.4 - q.x, -0.75 - q.y, true) + 0.01, -0.75 - q.y)
	_decal(k, m, "a10_ins_wl", _star_bar(0.48, 0.0, 0.0, 0.035), wt, Vector3.UP, LOWVIS)
	var wb := func(q: Vector2) -> Vector3: return Vector3(6.4 + q.x, _wing_y(ws, 6.4 + q.x, -0.75 - q.y, false) - 0.01, -0.75 - q.y)
	_decal(k, m, "a10_ins_wr", _star_bar(0.48, 0.0, 0.0, 0.035), wb, Vector3.DOWN, LOWVIS)
	# "USAF" across the upper right wing and the lower left one, read from behind
	var ut := func(q: Vector2) -> Vector3: return Vector3(5.5 + q.x, _wing_y(ws, 5.5 + q.x, -0.7 - q.y, true) + 0.01, -0.7 - q.y)
	_decal(k, m, "a10_usaf_t", _text("USAF", 0.72, 0.0, 0.0), ut, Vector3.UP, LOWVIS)
	var ub := func(q: Vector2) -> Vector3: return Vector3(-5.5 - q.x, _wing_y(ws, 5.5 + q.x, -0.7 - q.y, false) - 0.01, -0.7 - q.y)
	_decal(k, m, "a10_usaf_b", _text("USAF", 0.72, 0.0, 0.0), ub, Vector3.DOWN, LOWVIS)


# --- A-164 Wipeout ------------------------------------------------------------------

## The Wipeout's two-tone "dark grey / ghost grey": dark over the top, the
## lighter grey under the belly, light grey low-vis markings.
const WIP_DARK := Color(0.29, 0.31, 0.34)
const WIP_LIGHT := Color(0.43, 0.45, 0.48)
const WIP_MARK := Color(0.6, 0.62, 0.64)


## The fuselage stations [z, cx, cy, chine w, ht, hb, deck tw, belly bw,
## ridge], interpolated at z.
static func _wst(fs: Array, z: float) -> Array:
	if z <= float(fs[0][0]):
		return fs[0]
	for i in fs.size() - 1:
		var a: Array = fs[i]
		var b: Array = fs[i + 1]
		if z <= float(b[0]):
			var t := (z - float(a[0])) / maxf(1e-4, float(b[0]) - float(a[0]))
			var o := []
			for j in a.size():
				o.append(lerpf(float(a[j]), float(b[j]), t))
			return o
	return fs[fs.size() - 1]


## A faceted body through stations [z, cx, cy, w, ht, hb, tw, bw, ridge],
## its facets kept crisp (crease 22 degrees). `grow` lifts it off (a paint
## layer); `lower` keeps only the belly below the chines (the light underside).
static func _fbody(k: VehicleModels, p: Node3D, key: String, st: Array, mat: String, col, grow := 0.0, lower := false) -> void:
	var rings := []
	for s in st:
		var g := grow
		var h: Array
		if lower:
			h = [Vector2(0, -float(s[5]) - g), Vector2(float(s[7]) + g * 0.5, -float(s[5]) - g), Vector2(float(s[3]) + g, 0.0), Vector2(0, 0.0)]
		else:
			h = _facet(float(s[3]) + g, float(s[4]) + g, float(s[5]) + g, float(s[6]) + g * 0.5, float(s[7]) + g * 0.5, float(s[8]))
		rings.append(_hring(float(s[0]), float(s[1]), float(s[2]), h))
	k._add(p, VmPlane.skin(rings, "at_" + key, 22.0), mat, col, Vector3.ZERO)


## A-164 Wipeout, Arma's successor to the A-10: the same idea - the seven-barrel
## 30 mm gun, a pilot high under glass, a straight thick wing with the gear in
## pods, two turbofans high on the back, twin tails - reworked with stealth
## styling. A long faceted fuselage with sharp chines and a pointed nose, the
## gun in a chin fairing, an EO/IR turret under the nose, a faceted canopy, the
## engines in faceted nacelles blended into the spine with acute raked inlets,
## outward-canted swept fins, raked wing tips and closed gear pods. Ten
## pylons as in Arma: Falchion-22s, Shrieker pods, Macer triples, GBU-12s.
static func _wipeout(k: VehicleModels, team: int, seed: int) -> void:
	var m := k.root
	var A := "aircraft"
	var c := WIP_DARK if team != 1 else CSAT_A.darkened(0.12)
	var cl := WIP_LIGHT if team != 1 else CSAT_A.lightened(0.06)
	# [z, cx, cy, chine half-width, height above the chine, depth below, deck half-width, belly half-width, ridge]
	var fs := [
		[-8.6, 0.0, 1.24, 0.015, 0.01, 0.012, 0.006, 0.006, 0.0],
		[-8.35, 0.0, 1.235, 0.19, 0.11, 0.14, 0.06, 0.07, 0.0],
		[-7.8, 0.0, 1.22, 0.4, 0.26, 0.32, 0.16, 0.19, 0.01],
		[-7.0, 0.0, 1.2, 0.57, 0.43, 0.5, 0.28, 0.29, 0.02],
		[-6.0, 0.0, 1.18, 0.7, 0.56, 0.66, 0.42, 0.37, 0.02],
		[-4.8, 0.0, 1.16, 0.77, 0.62, 0.74, 0.52, 0.42, 0.02],
		[-3.0, 0.0, 1.15, 0.79, 0.64, 0.74, 0.48, 0.44, 0.02],
		[-1.0, 0.0, 1.15, 0.78, 0.64, 0.72, 0.4, 0.44, 0.02],
		[1.0, 0.0, 1.18, 0.72, 0.6, 0.64, 0.34, 0.4, 0.02],
		[3.0, 0.0, 1.28, 0.6, 0.5, 0.5, 0.29, 0.32, 0.02],
		[5.0, 0.0, 1.42, 0.45, 0.39, 0.33, 0.23, 0.22, 0.02],
		[6.6, 0.0, 1.55, 0.3, 0.27, 0.2, 0.15, 0.14, 0.01],
		[7.8, 0.0, 1.63, 0.16, 0.16, 0.1, 0.08, 0.07, 0.0],
		[8.3, 0.0, 1.66, 0.05, 0.05, 0.04, 0.03, 0.03, 0.0],
	]
	_fbody(k, m, "wip_fus", fs, A, c)
	_fbody(k, m, "wip_belly", fs.slice(1, fs.size() - 1), A, cl, 0.006, true)
	# panel joints: thin raised frames round the fuselage
	for z in [-7.3, -6.05, -2.75, -0.6, 2.2, 4.4, 6.2]:
		var q := _wst(fs, z)
		var q0 := q.duplicate()
		var q1 := q.duplicate()
		q0[0] = z - 0.012
		q1[0] = z + 0.012
		_fbody(k, m, "wip_j%d" % int(z * 100), [q0, q1], A, c.darkened(0.3), 0.005)
	var ws := _wip_wing(k, m, c, cl)
	_wip_cockpit(k, m, c)
	_wip_gun(k, m, fs, c)
	_wip_engines(k, m, fs, c)
	var fins := _wip_tail(k, m, c)
	_wip_gear(k, m, fs, c)
	_wip_stores(k, m, ws, c)
	_wip_details(k, m, fs, ws, fins, c, team, seed)


## The faceted canopy: the armoured front pane and its frame, the long glass
## hood behind, its sills; the faceted spine fairing back between the engines.
static func _wip_cockpit(k: VehicleModels, m: Node3D, c: Color) -> void:
	var A := "aircraft"
	# [z, base height, half-width, height]
	var cs := [[-6.3, 1.72, 0.3, 0.02], [-5.85, 1.74, 0.41, 0.28], [-5.25, 1.76, 0.47, 0.5], [-4.5, 1.78, 0.49, 0.62],
		[-3.6, 1.79, 0.46, 0.58], [-2.8, 1.79, 0.38, 0.42], [-2.15, 1.79, 0.26, 0.18]]
	var rings := []
	for s in cs:
		rings.append(_hring(float(s[0]), 0.0, float(s[1]), _canopy_half(float(s[2]), float(s[3]))))
	# (a faint gold in the glass: the radar-reflective coating of a stealthy canopy)
	k._add(m, VmPlane.skin(rings, "at_wip_can", 18.0), "glass", Color(0.15, 0.13, 0.08), Vector3.ZERO)
	# frames: the armoured pane's bow, a hoop over the middle
	for z in [-5.25, -3.9]:
		var fr := []
		for dz in [-0.045, 0.045]:
			var q := _wst(cs, z + dz)
			fr.append(_hring(z + dz, 0.0, float(q[1]), _canopy_half(float(q[2]) + 0.02, float(q[3]) + 0.02)))
		k._add(m, VmPlane.skin(fr, "at_wip_bow%d" % int(-z * 100), 18.0), A, c.darkened(0.35), Vector3.ZERO)
	# the sills
	for sd in [-1.0, 1.0]:
		for i in cs.size() - 1:
			var a: Array = cs[i]
			var b: Array = cs[i + 1]
			VmPlane.rod(k, m, Vector3(sd * (float(a[2]) + 0.01), float(a[1]) + 0.02, float(a[0])), Vector3(sd * (float(b[2]) + 0.01), float(b[1]) + 0.02, float(b[0])), 0.03, A, c.darkened(0.35), 4)
	# the spine: a faceted fairing from the canopy back between the engines
	var sp := [[-2.6, 0.0, 1.79, 0.36, 0.34, 0.1, 0.16, 0.36, 0.02], [-1.0, 0.0, 1.79, 0.36, 0.3, 0.1, 0.18, 0.36, 0.02], [1.5, 0.0, 1.76, 0.34, 0.26, 0.1, 0.16, 0.34, 0.02],
		[4.0, 0.0, 1.76, 0.26, 0.16, 0.1, 0.12, 0.26, 0.01], [5.6, 0.0, 1.76, 0.12, 0.04, 0.1, 0.05, 0.12, 0.0]]
	_fbody(k, m, "wip_spine", sp, A, c)
	# the air-refuelling receptacle's door on the spine
	k._box(m, Vector3(0.26, 0.012, 0.5), Vector3(0, 2.11, -1.6), A, c.darkened(0.3), Vector3.ZERO, false)


## The canopy's half-section: the sill, the steep side pane, the shoulder, the roof.
static func _canopy_half(w: float, h: float) -> Array:
	return [Vector2(0, -0.12), Vector2(w, 0), Vector2(w * 0.93, h * 0.52), Vector2(w * 0.6, h * 0.9), Vector2(0, h)]


## The gun: seven barrels out of a faceted fairing under the chin; the EO/IR
## turret under the nose.
static func _wip_gun(k: VehicleModels, m: Node3D, fs: Array, c: Color) -> void:
	var A := "aircraft"
	var gy := 0.74
	var gf := [[-8.05, 0.0, gy, 0.18, 0.14, 0.16, 0.1, 0.1, 0.0], [-7.6, 0.0, gy, 0.23, 0.2, 0.2, 0.13, 0.14, 0.0], [-6.6, 0.0, gy + 0.02, 0.25, 0.22, 0.18, 0.15, 0.15, 0.0],
		[-5.6, 0.0, gy + 0.1, 0.22, 0.2, 0.1, 0.13, 0.12, 0.0], [-5.0, 0.0, gy + 0.2, 0.14, 0.12, 0.04, 0.08, 0.06, 0.0]]
	_fbody(k, m, "wip_gunf", gf, A, c)
	k._cyl(m, 0.15, 0.15, 0.02, Vector3(0, gy, -8.06), Vector3(PI / 2, 0, 0), "plain_dark", null, 14, false)
	for i in 7:
		var a := TAU * float(i) / 7.0
		var o := Vector3(cos(a) * 0.085, sin(a) * 0.085, 0)
		VmPlane.rod(k, m, Vector3(0, gy, -7.9) + o, Vector3(0, gy, -8.5) + o, 0.026, "gunmetal_w", null, 8, 0.024)
		k._cyl(m, 0.013, 0.013, 0.02, Vector3(0, gy, -8.505) + o, Vector3(PI / 2, 0, 0), "plain_dark", null, 6, false)
	k._cyl(m, 0.125, 0.125, 0.07, Vector3(0, gy, -8.38), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 14, false)
	k.mg_tip = k._tip(m, Vector3(0, gy, -8.6))
	k.gun_tip = k.mg_tip
	# the EO/IR targeting turret under the nose, its window looking ahead
	var ball := [Vector2(0.0, -0.17), Vector2(0.1, -0.14), Vector2(0.16, -0.06), Vector2(0.17, 0.02), Vector2(0.14, 0.1), Vector2(0.07, 0.15), Vector2(0.0, 0.16)]
	var q := _wst(fs, -4.4)
	var tp := Vector3(-0.3, float(q[2]) - float(q[5]) - 0.12, -4.4)
	k._add(m, _lathe("wip_ball", ball, 8, 20.0), "gunmetal_w", Color(0.3, 0.31, 0.32), tp, Vector3(PI / 2, 0, 0))
	k._cyl(m, 0.1, 0.12, 0.1, tp + Vector3(0, 0.12, 0), Vector3.ZERO, A, c.darkened(0.1), 8)
	k._box(m, Vector3(0.16, 0.13, 0.02), tp + Vector3(0, -0.01, -0.165), "glass", null, Vector3(0.2, 0, 0), false)


## The wing: a constant-chord centre section, outer panels with 5 degrees of
## dihedral and raked tips; flaps and the split decelerons. Returns sections.
static func _wip_wing(k: VehicleModels, m: Node3D, c: Color, cl: Color) -> Array:
	var A := "aircraft"
	var ws := [[Vector3(0.5, 0.82, -1.7), 3.25, 0.46], [Vector3(3.3, 0.82, -1.7), 3.25, 0.44], [Vector3(6.0, 1.06, -1.38), 2.6, 0.32],
		[Vector3(8.55, 1.28, -1.02), 1.95, 0.22]]
	VmPlane.surf(k, m, "at_wip_wing", ws, A, c, [0.72, 0.72, 0.7])
	VmPlane.surf(k, m, "at_wip_wtip", [[Vector3(8.54, 1.28, -1.02), 1.95, 0.22], [Vector3(8.98, 1.31, -0.34), 1.2, 0.12]], A, c, [])
	# the leading-edge root extensions: thin faceted strakes running forward
	# from the wing roots along the chines
	VmPlane.surf(k, m, "at_wip_lerx", [[Vector3(0.6, 1.0, -4.1), 2.45, 0.07], [Vector3(1.4, 0.86, -1.72), 0.25, 0.05]], A, c, [], true, 20.0)
	for sd in [-1.0, 1.0]:
		var L := "L" if sd < 0.0 else ""
		# the deceleron split along the outer trailing edges
		var a := VmPlane.surf_at(ws, 6.05)
		var b := VmPlane.surf_at(ws, 8.5)
		var pa: Vector3 = (a[0] as Vector3) + Vector3(0, 0, float(a[1]) * 0.985)
		var pb: Vector3 = (b[0] as Vector3) + Vector3(0, 0, float(b[1]) * 0.985)
		VmPlane.rod(k, m, Vector3(sd * pa.x, pa.y, pa.z), Vector3(sd * pb.x, pb.y, pb.z), 0.012, "plain_dark", null, 4, -1.0, false)
		# the lighter grey under the wing
		var lw := []
		for x in [0.75, 2.0, 3.3, 4.65, 6.0, 7.3, 8.5]:
			var w := VmPlane.surf_at(ws, x)
			lw.append([Vector2(x, (w[0] as Vector3).z + 0.06), Vector2(x, (w[0] as Vector3).z + float(w[1]) * 0.7)])
		var under := []
		for i in lw.size() - 1:
			under.append([lw[i][0], lw[i + 1][0], lw[i + 1][1], lw[i][1]])
		_decal(k, m, "wip_under" + L, under,
			func(q: Vector2) -> Vector3: return Vector3(sd * q.x, _wing_y(ws, q.x, q.y, false) - 0.006, q.y), Vector3.DOWN, cl, A)
		# panel lines on the upper skin
		var lines := []
		for x in [0.85, 3.3, 6.0, 7.3]:
			var w := VmPlane.surf_at(ws, x)
			lines.append([Vector2(x, (w[0] as Vector3).z + 0.05), Vector2(x, (w[0] as Vector3).z + float(w[1]) * 0.7)])
		var pts := []
		for x in [0.8, 3.3, 6.0, 8.5]:
			var w := VmPlane.surf_at(ws, x)
			pts.append(Vector2(x, (w[0] as Vector3).z + float(w[1]) * 0.16))
		for i in 3:
			lines.append([pts[i], pts[i + 1]])
		_decal(k, m, "wip_wlines" + L, _strokes(lines, 0.016, 0.3),
			func(q: Vector2) -> Vector3: return Vector3(sd * q.x, _wing_y(ws, q.x, q.y, true) + 0.007, q.y), Vector3.UP, c.darkened(0.35))
	return ws


## The nacelle's faceted half-section, `f` times its size.
static func _nac_half(f: float) -> Array:
	var r := 0.66 * f
	return [Vector2(0, -r * 0.84), Vector2(r * 0.62, -r * 0.74), Vector2(r, -r * 0.12), Vector2(r * 0.93, r * 0.42), Vector2(r * 0.52, r * 0.82), Vector2(0, r * 0.88)]


## The engines: faceted nacelles high on the rear fuselage, blended into it by
## broad fairings; acute raked inlets opening on dark ducts with the fans and
## spinners deep inside; faceted nozzles with the cones in the jet pipes.
static func _wip_engines(k: VehicleModels, m: Node3D, fs: Array, c: Color) -> void:
	var A := "aircraft"
	var r := 0.66
	var glows := []
	var rake := Vector2(0.3, -0.42)
	for sd in [-1.0, 1.0]:
		var nx: float = sd * 1.5
		var ny := 2.34
		var L := "L" if sd < 0.0 else ""
		# the outer skin from the lip aft to the nozzle
		var outer := [_hring(0.75, nx, ny, _nac_half(0.97), rake, sd), _hring(1.05, nx, ny, _nac_half(1.0), rake * 0.4, sd), _hring(1.8, nx, ny, _nac_half(1.02)),
			_hring(3.6, nx, ny, _nac_half(1.0)), _hring(4.6, nx, ny, _nac_half(0.9)), _hring(5.35, nx, ny, _nac_half(0.7))]
		k._add(m, _sheet("wip_nac" + L, outer), A, c, Vector3.ZERO)
		# the inlet's lip and duct, the fan face inside
		var inner := [_hring(0.8, nx, ny, _nac_half(0.86), rake, sd), _hring(1.2, nx, ny, _nac_half(0.8), rake * 0.3, sd), _hring(1.55, nx, ny, _nac_half(0.78))]
		k._add(m, _sheet("wip_lip" + L, [outer[0], inner[0]], false, Vector3(0, 0, -1)), A, c.darkened(0.15), Vector3.ZERO)
		k._add(m, _sheet("wip_duct" + L, inner, true), A, c.darkened(0.5), Vector3.ZERO)
		k._cyl(m, 0.5, 0.5, 0.03, Vector3(nx, ny, 1.55), Vector3(PI / 2, 0, 0), "plain_dark", Color(0.05, 0.05, 0.05), 20, false)
		k._add(m, _lathe("a10_spin", [Vector2(0.0, 0.3), Vector2(0.06, 0.36), Vector2(0.13, 0.48), Vector2(0.17, 0.6), Vector2(0.17, 0.64)], 16, 50.0), "metal_dark", null, Vector3(nx, ny, 0.9))
		for i in 16:
			var a := TAU * i / 16.0
			var bb := Basis(Vector3(0, 0, 1), a) * Basis(Vector3(0, 1, 0), 0.55)
			k._add(m, Res.box(Vector3(0.015, 0.28, 0.1)), "metal_dark", null, Vector3(nx - sin(a) * 0.3, ny + cos(a) * 0.3, 1.5), bb.get_euler(), Vector3.ONE, false)
		# the nozzle: its lip, the jet pipe's wall, the cone in it
		var pipe := [_hring(5.33, nx, ny, _nac_half(0.62)), _hring(4.9, nx, ny, _nac_half(0.56))]
		k._add(m, _sheet("wip_noz" + L, [outer[outer.size() - 1], pipe[0]], false, Vector3(0, 0, 1)), "gunmetal_w", Color(0.3, 0.3, 0.3), Vector3.ZERO)
		k._add(m, _sheet("wip_pipe" + L, pipe, true), "metal_dark", null, Vector3.ZERO)
		k._cyl(m, 0.38, 0.38, 0.02, Vector3(nx, ny, 4.92), Vector3(PI / 2, 0, 0), "plain_dark", Color(0.05, 0.05, 0.05), 16, false)
		k._add(m, _lathe("wip_cone", [Vector2(0.24, 4.9), Vector2(0.22, 5.1), Vector2(0.12, 5.35), Vector2(0.0, 5.48)], 12, 30.0), "metal_dark", null, Vector3(nx, ny, 0))
		# cowling seams
		for z in [1.9, 3.3]:
			var q0 := _hring(z - 0.012, nx, ny, _nac_half(1.025))
			var q1 := _hring(z + 0.012, nx, ny, _nac_half(1.025))
			k._add(m, VmPlane.skin([q0, q1], "at_wip_seam%d%s" % [int(z * 10), L], 22.0), A, c.darkened(0.35), Vector3.ZERO)
		# the broad pylon blending the nacelle into the spine, tapered at both ends
		var fr := []
		for z in [1.15, 1.8, 3.7, 4.45]:
			var q := _wst(fs, z)
			var dy := float(q[2]) + float(q[4])
			var pa := Vector3(sd * 0.3, 1.96, z)
			var pb := Vector3(sd * 0.52, dy - 0.12, z)
			var pc := Vector3(nx - sd * r * 0.55, ny - r * 0.72, z)
			var pd := Vector3(nx - sd * r * 0.92, ny - r * 0.15, z)
			var ring := PackedVector3Array([pa, pd, pc, pb])
			if z < 1.5 or z > 4.0:
				# the ends drawn in towards the pylon's middle
				var cc := (pa + pb + pc + pd) * 0.25
				for i in 4:
					ring[i] = cc + (ring[i] - cc) * Vector3(0.45, 0.45, 1.0)
			fr.append(ring)
		k._add(m, VmPlane.skin(fr, "at_wip_fair" + L, 22.0), A, c, Vector3.ZERO)
		glows.append(Vector3(nx, ny, 5.5))
	VmPlane.glow(k, m, glows, 1.0, Color(0.32, 0.18, 0.1))


## The tail: a slightly swept tailplane on the end of the fuselage, the twin
## fins canted outwards at its tips, swept, with their rudders. Returns the
## fins' sections (right side).
static func _wip_tail(k: VehicleModels, m: Node3D, c: Color) -> Array:
	var A := "aircraft"
	var ty := 1.86
	VmPlane.surf(k, m, "at_wip_stab", [[Vector3(0.15, ty, 6.0), 2.05, 0.16], [Vector3(2.85, ty, 6.42), 1.62, 0.12], [Vector3(3.05, ty, 6.6), 1.4, 0.09]], A, c, [0.66, 0.66])
	var fx := 2.62
	var cant := deg_to_rad(20.0)
	var hgt := 2.05
	var fins := [[Vector3(fx, ty - 0.02, 6.18), 1.92, 0.15], [Vector3(fx + tan(cant) * hgt * 0.5, ty + hgt * 0.5, 6.7), 1.5, 0.12],
		[Vector3(fx + tan(cant) * hgt, ty + hgt, 7.28), 0.95, 0.08]]
	for sd in [-1.0, 1.0]:
		var ms := []
		for s in fins:
			var le: Vector3 = s[0]
			ms.append([Vector3(sd * le.x, le.y, le.z), s[1], s[2]])
		VmPlane.surf(k, m, "at_wip_fin" + ("L" if sd < 0.0 else ""), ms, A, c, [0.64, 0.64], false)
		# the fin-tip fairing with its light
		var tip: Vector3 = fins[2][0]
		k._box(m, Vector3(0.06, 0.04, 0.9), Vector3(sd * tip.x, tip.y + 0.01, tip.z + 0.5), A, c.darkened(0.2), Vector3(0, 0, -sd * cant))
		if not k.burnt:
			k._box(m, Vector3(0.05, 0.05, 0.05), Vector3(sd * tip.x, tip.y + 0.02, tip.z + 0.97), "glass", null, Vector3.ZERO, false)
	return fins


## The main gear in closed, faceted pods ("Gear": the legs down, the pod doors
## open) and the nose gear behind the gun fairing.
static func _wip_gear(k: VehicleModels, m: Node3D, fs: Array, c: Color) -> void:
	var A := "aircraft"
	var nodes := _gear_nodes(k, false)
	var gear: Node3D = nodes[0]
	var gx := 2.7
	for sd in [-1.0, 1.0]:
		var x: float = sd * gx
		var L := "L" if sd < 0.0 else ""
		var ps := [[-3.35, x, 0.66, 0.02, 0.02, 0.02, 0.01, 0.01, 0.0], [-3.1, x, 0.65, 0.2, 0.16, 0.2, 0.08, 0.1, 0.0], [-2.6, x, 0.63, 0.33, 0.3, 0.38, 0.17, 0.2, 0.0],
			[-1.6, x, 0.63, 0.36, 0.32, 0.43, 0.2, 0.22, 0.0], [0.0, x, 0.66, 0.32, 0.26, 0.36, 0.17, 0.19, 0.0], [1.0, x, 0.7, 0.18, 0.14, 0.18, 0.09, 0.1, 0.0],
			[1.45, x, 0.72, 0.03, 0.03, 0.03, 0.02, 0.02, 0.0]]
		_fbody(k, m, "wip_pod" + L, ps, A, c)
		# the doors' seams along the belly, saw-toothed fore and aft
		var y0 := 0.63 - 0.43 - 0.008
		var seam := [[Vector2(-0.2, -2.8), Vector2(-0.2, -0.7)], [Vector2(0.2, -2.8), Vector2(0.2, -0.7)], [Vector2(0.0, -2.8), Vector2(0.0, -0.7)]]
		seam.append_array(_zigzag(Vector2(-0.2, -2.8), Vector2(0.2, -2.8), 4, 0.1))
		seam.append_array(_zigzag(Vector2(-0.2, -0.7), Vector2(0.2, -0.7), 4, 0.1))
		_decal(k, m, "wip_podseam" + L, _strokes(seam, 0.014, 0.4), func(q: Vector2) -> Vector3: return Vector3(x + q.x, y0, q.y), Vector3.DOWN, c.darkened(0.4))
		if gear == null:
			continue
		var wp := Vector3(x, -0.16, -1.75)
		_wheel(k, gear, "wip_mw", wp, 0.46, 0.3)
		var lx: float = x - sd * 0.24
		VmPlane.rod(k, gear, Vector3(lx, 0.45, -1.95), Vector3(lx, -0.16, -1.78), 0.09, "steel", Color(0.6, 0.6, 0.58), 10)
		VmPlane.rod(k, gear, Vector3(lx, 0.4, -1.1), Vector3(lx, -0.02, -1.8), 0.045, "gunmetal_w", null, 8)
		k._cyl(gear, 0.06, 0.06, 0.26, wp + Vector3(-sd * 0.12, 0, 0), Vector3(0, 0, PI / 2), "steel", Color(0.6, 0.6, 0.58), 10)
		# the pod's bay doors hanging open either side
		for o in [-1.0, 1.0]:
			k._box(gear, Vector3(0.025, 0.4, 2.0), Vector3(x + o * 0.2, y0 - 0.19, -1.75), A, c, Vector3(0, 0, o * 0.15))
	# the nose gear on the centre line behind the gun fairing, its doors
	var q := _wst(fs, -4.95)
	var by := float(q[2]) - float(q[5])
	var nd := [[Vector2(-0.19, -5.6), Vector2(-0.19, -4.4)], [Vector2(0.19, -5.6), Vector2(0.19, -4.4)], [Vector2(0.0, -5.6), Vector2(0.0, -4.4)]]
	nd.append_array(_zigzag(Vector2(-0.19, -5.6), Vector2(0.19, -5.6), 4, 0.09))
	nd.append_array(_zigzag(Vector2(-0.19, -4.4), Vector2(0.19, -4.4), 4, 0.09))
	_decal(k, m, "wip_ndoor", _strokes(nd, 0.014, 0.3),
		func(p: Vector2) -> Vector3: return Vector3(0.3 + p.x, by - 0.007, p.y), Vector3.DOWN, c.darkened(0.4))
	if gear == null:
		return
	var nw := Vector3(0.3, -0.32, -5.1)
	_wheel(k, gear, "wip_nw", nw, 0.3, 0.2)
	VmPlane.rod(k, gear, Vector3(0.3, by + 0.1, -4.95), Vector3(0.3, 0.0, -5.08), 0.075, "steel", Color(0.6, 0.6, 0.58), 10)
	for sd in [-1.0, 1.0]:
		VmPlane.rod(k, gear, Vector3(0.3 + sd * 0.13, 0.02, -5.08), Vector3(0.3 + sd * 0.13, -0.32, -5.1), 0.035, "steel", Color(0.6, 0.6, 0.58), 6)
		k._box(gear, Vector3(0.025, 0.4, 1.15), Vector3(0.3 + sd * 0.21, by - 0.2, -5.0), A, c, Vector3(0, 0, sd * 0.12))
	k._box(gear, Vector3(0.3, 0.05, 0.1), Vector3(0.3, 0.02, -5.08), "steel", Color(0.6, 0.6, 0.58))
	k._cyl(gear, 0.05, 0.05, 0.06, Vector3(0.3, 0.1, -5.2), Vector3(PI / 2, 0, 0), "glass", null, 10, false)


## Ten pylons, Arma's default load: a Falchion-22 outboard each side, then a
## Shrieker rocket pod, a Macer triple rack, GBU-12s on the inner wing and
## under the fuselage.
static func _wip_stores(k: VehicleModels, m: Node3D, ws: Array, c: Color) -> void:
	for sd in [-1.0, 1.0]:
		for x in [1.55, 3.6, 5.05, 6.6]:
			var w := VmPlane.surf_at(ws, x)
			var le: Vector3 = w[0]
			var at := Vector3(sd * x, _wing_y(ws, x, le.z + float(w[1]) * 0.4, false) + 0.02, le.z + float(w[1]) * 0.42)
			if x < 2.0:
				VmPlane.bomb(k, m, VmPlane.pylon(k, m, at, 1.75, 0.3, c, 0.137), 3.27, 0.137, true)
			elif x < 4.0:
				# three Macers on a triple rack: two on the shoulders, one below
				var ft := VmPlane.pylon(k, m, at, 1.75, 0.28, c, 0.0)
				k._box(m, Vector3(0.22, 0.18, 2.2), ft + Vector3(0, -0.09, -0.05), "gunmetal_w", Color(0.36, 0.37, 0.37))
				for o in [-1.0, 1.0]:
					k._box(m, Vector3(0.1, 0.07, 1.6), ft + Vector3(o * 0.16, -0.17, -0.1), "gunmetal_w", Color(0.36, 0.37, 0.37), Vector3(0, 0, -o * 0.6))
					VmPlane.agm(k, m, ft + Vector3(o * 0.3, -0.37, -0.15), 2.49, 0.152, STORE_LIGHT)
				VmPlane.agm(k, m, ft + Vector3(0, -0.5, -0.15), 2.49, 0.152, STORE_LIGHT)
			elif x < 6.0:
				VmPlane.rocket_pod(k, m, VmPlane.pylon(k, m, at, 1.5, 0.28, c, 0.22), 2.0, 0.22, STORE_MID)
			else:
				var ft2 := VmPlane.pylon(k, m, at, 1.3, 0.2, c, 0.0)
				_falchion(k, m, ft2 + Vector3(0, -0.12, -0.1), 3.0, 0.064)
	for sd in [-1.0, 1.0]:
		VmPlane.bomb(k, m, VmPlane.pylon(k, m, Vector3(sd * 0.5, 0.46, -0.3), 1.75, 0.22, c, 0.137), 3.27, 0.137, true)


## The Falchion-22 (an AIM-9X style dogfight missile) on its rail: a slim body,
## small clipped tail fins and long fixed strakes, no canards.
static func _falchion(k: VehicleModels, p: Node3D, ctr: Vector3, len: float, r: float) -> void:
	k._box(p, Vector3(0.07, 0.07, len * 0.6), ctr + Vector3(0, r + 0.035, 0.05 * len), "gunmetal_w")
	k._cyl(p, r, r, len * 0.88, ctr + Vector3(0, 0, 0.06 * len), Vector3(PI / 2, 0, 0), "paint", STORE_LIGHT, 10)
	k._cyl(p, r * 0.35, r, len * 0.08, ctr + Vector3(0, 0, -0.42 * len), Vector3(PI / 2, 0, 0), "paint", STORE_LIGHT, 10, false)
	k._add(p, Res.sphere(r * 0.4, 8), "glass", null, ctr + Vector3(0, 0, -0.465 * len), Vector3.ZERO, Vector3.ONE, false)
	k._cyl(p, r * 1.02, r * 1.02, 0.06, ctr + Vector3(0, 0, -0.28 * len), Vector3(PI / 2, 0, 0), "paint", Color(0.6, 0.55, 0.25), 10, false)
	for a in [PI / 4, -PI / 4]:
		k._box(p, Vector3(0.01, r * 3.4, len * 0.2), ctr + Vector3(0, 0, -0.05 * len), "paint", STORE_LIGHT.darkened(0.1), Vector3(0, 0, a), false)
		k._box(p, Vector3(0.012, r * 4.6, len * 0.07), ctr + Vector3(0, 0, 0.45 * len), "paint", STORE_LIGHT.darkened(0.1), Vector3(0, 0, a), false)


## Lights, antennas, probes and the markings.
static func _wip_details(k: VehicleModels, m: Node3D, fs: Array, ws: Array, fins: Array, c: Color, team: int, seed: int) -> void:
	VmPlane.nav_lights(k, m, Vector3(8.98, 1.31, -0.17), 0.08)
	if not k.burnt:
		for sd in [-1.0, 1.0]:
			k._box(m, Vector3(0.05, 0.04, 0.09), Vector3(sd * 8.9, 1.31, 0.18), "glass", null, Vector3.ZERO, false)
	# formation light strips along the chines
	for sd in [-1.0, 1.0]:
		for z in [-6.4, 4.0]:
			var q := _wst(fs, z)
			var yaw: float = -sd * 0.1 if z < 0.0 else sd * 0.12
			k._box(m, Vector3(0.012, 0.05, 0.6), Vector3(sd * (float(q[3]) + 0.006), float(q[2]) + 0.06, z), "paint", Color(0.55, 0.62, 0.45), Vector3(0, yaw, 0), false)
	# antennas on the spine and belly, the angle-of-attack probes
	var ac := c.darkened(0.2)
	VmPlane.antenna(k, m, Vector3(0, 2.07, 0.4), 0.26, false, ac)
	VmPlane.antenna(k, m, Vector3(0, 1.96, 3.4), 0.2, false, ac)
	var qb := _wst(fs, -1.5)
	VmPlane.antenna(k, m, Vector3(0, float(qb[2]) - float(qb[5]), -1.5), 0.24, true, ac)
	var q2 := _wst(fs, -7.2)
	for sd in [-1.0, 1.0]:
		var px: float = q2[3]
		VmPlane.rod(k, m, Vector3(sd * (px - 0.02), float(q2[2]), -7.2), Vector3(sd * (px + 0.14), float(q2[2]), -7.3), 0.012, "gunmetal_w", null, 6, 0.008, false)
	# static dischargers on the wing tips
	for sd in [-1.0, 1.0]:
		for x in [7.0, 7.9, 8.5]:
			var w := VmPlane.surf_at(ws, x)
			var te: Vector3 = (w[0] as Vector3) + Vector3(0, 0, float(w[1]))
			VmPlane.rod(k, m, Vector3(sd * x, te.y, te.z - 0.05), Vector3(sd * x, te.y, te.z + 0.14), 0.006, "plain_dark", null, 4, -1.0, false)
	if team == 1:
		VmPlane.wing_marks(k, m, team, ws, 6.2, 0.8)
		for sd in [-1.0, 1.0]:
			k._team_mark(m, team, Vector3(sd * 0.7, 1.55, -1.6), Vector3(0.02, 0.4, 0.4))
		return
	# light grey low-vis markings: the star-and-bar on the fuselage's upper
	# flanks and the left wing, a tail code and serial on the fins
	for sd in [-1.0, 1.0]:
		var fl := func(q: Vector2) -> Vector3:
			var z: float = -1.7 - sd * q.x
			var s := _wst(fs, z)
			var y: float = float(s[2]) + 0.12 + q.y
			var t := clampf((y - float(s[2])) / float(s[4]), 0.0, 1.0)
			return Vector3(sd * (lerpf(float(s[3]), float(s[6]), t) + 0.008), y, z)
		_decal(k, m, "wip_ins" + ("L" if sd < 0.0 else ""), _star_bar(0.2, 0.0, 0.2, 0.024), fl, Vector3(sd, 0.6, 0), WIP_MARK)
	var wt := func(q: Vector2) -> Vector3: return Vector3(-6.5 + q.x, _wing_y(ws, 6.5 - q.x, -0.55 - q.y, true) + 0.01, -0.55 - q.y)
	_decal(k, m, "wip_ins_wl", _star_bar(0.45, 0.0, 0.0, 0.032), wt, Vector3.UP, WIP_MARK)
	var serial := "35-%03d" % (100 + absi(seed * 53) % 800)
	var r0: Vector3 = fins[0][0]
	var r2: Vector3 = fins[2][0]
	var up := Vector3(r2.x - r0.x, r2.y - r0.y, 0).normalized()
	var out := Vector3(up.y, -up.x, 0)
	var span := Vector2(r2.x - r0.x, r2.y - r0.y).length()
	for sd in [-1.0, 1.0]:
		# the fin's outer skin, q.y up its span from the root: the airfoil's
		# thickness there, at that point of the chord
		var fn := func(q: Vector2) -> Vector3:
			var t := clampf(q.y / span, 0.0, 1.0)
			var lez := lerpf(r0.z, r2.z, t)
			var z: float = 7.15 - sd * q.x
			var f := clampf((z - lez) / lerpf(float(fins[0][1]), float(fins[2][1]), t), 0.0, 1.0)
			var off := lerpf(float(fins[0][2]), float(fins[2][2]), t) * 0.5 * VmPlane._foil_t(f) + 0.006
			var base := Vector3(r0.x, r0.y, 0) + up * q.y + out * off
			return Vector3(sd * base.x, base.y, z)
		var polys := _text("AT", 0.42, 0.0, 0.85)
		polys.append_array(_text(serial, 0.11, 0.0, 0.45))
		_decal(k, m, "wip_code" + ("L" if sd < 0.0 else ""), polys, fn, Vector3(sd * out.x, out.y, 0), WIP_MARK)
