class_name BuildingWire
extends RefCounted
## Wire, cable and rope: the sag of a span (shared with the power lines Decor
## draws as lines), guys with their tensioners and anchors, cables and service
## drops as solid wire, insulators, barbed strands (shared with the concertina
## of WorksModels) and the barbed topping on the cranked arms along a wall.
## Positions are in the kit's frame (see BuildingKit).


## Points along a span from `a` to `b` hanging `sag` at its middle (a parabola,
## near enough a catenary for wire pulled this tight), `n` segments.
static func catenary(a: Vector3, b: Vector3, sag: float, n := 10) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	return pts


## A solid cable from `a` to `b` sagging `sag` (a service drop, a cable
## between masts).
static func cable(k: BuildingKit, a: Vector3, b: Vector3, sag: float, r := 0.008, kind := "rubber", col: Variant = null) -> void:
	k.part(BuildingKit.tube_mesh(catenary(a, b, sag, 10), r, 4), kind, Transform3D.IDENTITY, col, false)


## A guy from `top` down to `foot` on the ground: the wire or rope, a
## tensioner (a turnbuckle, or a tent rope's wooden runner) near the foot,
## and its anchor: a steel picket, a wooden peg, or a buried block.
static func guy(k: BuildingKit, top: Vector3, foot: Vector3, rope := false, anchor := "picket") -> void:
	var kind := "canvas" if rope else "wire"
	var col: Variant = Color(0.62, 0.58, 0.48) if rope else null
	var r := 0.006 if rope else 0.004
	var d := (top - foot).normalized()
	var at := foot + d * minf(0.6, top.distance_to(foot) * 0.2)
	k.rod(top, foot + d * 0.08, r, kind, col, 3, false)
	if rope:
		k.part(BuildingKit.plain(Vector3(0.025, 0.07, 0.015)), "wood", Transform3D(BuildingKit.aim(d), at), Color(0.5, 0.4, 0.28), false)
	else:
		k.cyl(0.011, 0.011, 0.15, at, "steel", Color(0.45, 0.45, 0.43), BuildingKit.aim(d).get_euler(), 6, false)
	# the anchor, leaning back against the pull
	var back := Vector3(foot.x - top.x, 0, foot.z - top.z).normalized()
	match anchor:
		"peg":
			k.rod(foot + Vector3(0, -0.1, 0) - back * 0.03, foot + Vector3(0, 0.12, 0) + back * 0.04, 0.014, "wood", Color(0.52, 0.42, 0.3), 4, false)
		"block":
			k.box(Vector3(0.3, 0.16, 0.3), foot + Vector3(0, 0.05, 0), "concrete", Color(0.5, 0.49, 0.46))
		_:
			k.rod(foot + Vector3(0, -0.15, 0) - back * 0.05, foot + Vector3(0, 0.22, 0) + back * 0.07, 0.012, "steel", Color(0.3, 0.3, 0.28), 4, false)


## A pin insulator on its pin at `p` (the cup where the wire is tied).
static func insulator(k: BuildingKit, p: Vector3, col := Color(0.82, 0.82, 0.78)) -> void:
	k.cyl(0.012, 0.012, 0.08, p + Vector3(0, 0.04, 0), "steel", Color(0.35, 0.35, 0.33), Vector3.ZERO, 4, false)
	k.cyl(0.032, 0.055, 0.05, p + Vector3(0, 0.1, 0), "paint", col, Vector3.ZERO, 8, false)
	k.cyl(0.035, 0.035, 0.05, p + Vector3(0, 0.15, 0), "paint", col.darkened(0.05), Vector3.ZERO, 8, false)
	k.cyl(0.025, 0.03, 0.025, p + Vector3(0, 0.187, 0), "paint", col, Vector3.ZERO, 8, false)


## The surfaces wire comes in: bright new galvanised, rusted brown from years
## on a farm post, and the armies' dull dark issue wire.
const FINISHES := {"clean": "wire", "rust": "wire_rust", "military": "wire_military"}


## A barbed strand from `a` to `b`, sagging `sag`, its barbs every `every`, in
## a `finish` (FINISHES). Rusted wire has lost its tension: it sags further.
static func barbed(k: BuildingKit, a: Vector3, b: Vector3, sag := 0.02, every := 0.11, finish := "clean") -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(a.x * 31.0 + a.z * 17.0 + b.y * 7.0) * 100.0)
	var slack := sag * (1.5 if finish == "rust" else 1.0)
	var pts := catenary(a, b, slack, maxi(4, int(a.distance_to(b) / 0.25)))
	barbed_wire(v, n, pts, every, rng)
	k.part(BuildingKit._commit(v, n), FINISHES.get(finish, "wire"), Transform3D.IDENTITY, null, false)


## Barbed wire along `pts` as it's made: two 2.5 mm line wires twisted tight
## together (a turn every 7.5 cm), and every `every` a barb, two short wires wrapped round
## the pair with their four cut ends standing out.
static func barbed_wire(v: PackedVector3Array, n: PackedVector3Array, pts: PackedVector3Array, every: float, rng: RandomNumberGenerator) -> void:
	var line := resample(pts, 0.025)
	twisted(v, n, line, 0.0011, 0.075, 0.0017)
	var run := every * rng.randf()
	for i in range(1, line.size()):
		var seg := line[i] - line[i - 1]
		run += seg.length()
		if run < every:
			continue
		run -= every
		barb(v, n, line[i], seg.normalized(), 0.017, rng)


## The same line every `step` metres along it (so a twist or a barb spacing
## comes out the same however finely the line was given).
static func resample(pts: PackedVector3Array, step: float) -> PackedVector3Array:
	var out := PackedVector3Array([pts[0]])
	var carry := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var seg := pts[i] - a
		var ln := seg.length()
		var d := step - carry
		while d <= ln:
			out.append(a + seg * (d / ln))
			d += step
		carry = ln - (d - step)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > step * 0.3:
		out.append(pts[pts.size() - 1])
	return out


## Two wires of radius `r` twisted round the line `pts`, `apart` from its
## centre, a full turn every `pitch` metres.
static func twisted(v: PackedVector3Array, n: PackedVector3Array, pts: PackedVector3Array, apart: float, pitch: float, r: float) -> void:
	var a_pts := PackedVector3Array()
	var b_pts := PackedVector3Array()
	var up := Vector3.UP
	var dist := 0.0
	for i in pts.size():
		if i > 0:
			dist += pts[i].distance_to(pts[i - 1])
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := t.cross(up)
		if side.length_squared() < 1e-6:
			side = t.cross(Vector3.RIGHT)
		side = side.normalized()
		up = side.cross(t).normalized()
		var ph := dist / pitch * TAU
		var o := (side * cos(ph) + up * sin(ph)) * apart
		a_pts.append(pts[i] + o)
		b_pts.append(pts[i] - o)
	strand(v, n, a_pts, r)
	strand(v, n, b_pts, r)


## One barb at `p` on a line running `t`, as the barbing machine makes it: two
## short wires each coiled twice round the twisted pair, their four cut ends
## standing out at right angles round the line as round tapered points `size`
## long, one pair leaning a little forward along the wire and the other back,
## none quite where the next one is.
static func barb(v: PackedVector3Array, n: PackedVector3Array, p: Vector3, t: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var s := t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
	var u := s.cross(t)
	var a0 := rng.randf() * TAU
	for w in 2:
		# the wrap: two turns of a 2 mm wire round the pair, side by side
		var start := p + t * (-0.006 + w * 0.006)
		var coil := PackedVector3Array()
		for k in 13:
			var a := a0 + w * PI * 0.5 + k * TAU * 2.0 / 12.0
			coil.append(start + t * (k * 0.0045 / 12.0) + (s * cos(a) + u * sin(a)) * 0.0042)
		strand(v, n, coil, 0.0011)
		# its two cut ends, opposite each other, leaning one forward and one back
		for e in 2:
			var a := a0 + w * PI * 0.5 + e * PI + rng.randf_range(-0.3, 0.3)
			var out := s * cos(a) + u * sin(a)
			var lean := t * (0.32 if (w + e) % 2 == 0 else -0.32) + t * rng.randf_range(-0.12, 0.12)
			var root := start + t * 0.0022 + out * 0.004
			var tip := root + (out + lean).normalized() * size * rng.randf_range(0.8, 1.1)
			point(v, n, root, tip, 0.0012)


## A sharpened wire end from `root` to `tip`: a round rod `r` thick tapering to
## a point (four sides: it is a few pixels across at most).
static func point(v: PackedVector3Array, n: PackedVector3Array, root: Vector3, tip: Vector3, r: float) -> void:
	var d := (tip - root).normalized()
	var x := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var y := d.cross(x)
	for k in 4:
		var a0 := TAU * k / 4.0
		var a1 := TAU * (k + 1) / 4.0
		var o0 := x * cos(a0) + y * sin(a0)
		var o1 := x * cos(a1) + y * sin(a1)
		var nm := (o0 + o1).normalized()
		_tri(v, n, root + o0 * r, root + o1 * r, tip, o0, o1, nm)


## Barbed wire along the top of a wall `length` long whose top is at `y`:
## angle-iron arms cranked out over the `lean` side (+1 is +z), three strands
## strained between them.
static func topping(k: BuildingKit, length: float, y: float, lean := 1.0, strands := 3, finish := "clean") -> void:
	var n := maxi(2, int(ceil(length / 2.4)) + 1)
	var arm := Vector3(0, 0.42, lean * 0.3)
	var xs: Array[float] = []
	for i in n:
		xs.append(-length * 0.5 + 0.15 + (length - 0.3) * float(i) / (n - 1))
	for x in xs:
		var foot := Vector3(x, y - 0.25, lean * 0.06)
		k.beam(foot, Vector3(x, y, lean * 0.06), 0.035, 0.035, "steel", Color(0.3, 0.29, 0.27), false)
		k.beam(Vector3(x, y, lean * 0.06), Vector3(x, y, lean * 0.06) + arm, 0.032, 0.032, "steel", Color(0.3, 0.29, 0.27), false)
	for s in strands:
		var f := float(s + 1) / strands
		var off := Vector3(0, y, lean * 0.06) + arm * f + Vector3(0, 0.02, 0)
		barbed(k, Vector3(xs[0], off.y, off.z), Vector3(xs[xs.size() - 1], off.y, off.z), 0.025, 0.11, finish)


## A wire along `pts`: a thin three-sided tube, its frame carried along so it
## doesn't twist. (The concertina in WorksModels is wound from the same.)
static func strand(v: PackedVector3Array, n: PackedVector3Array, pts: PackedVector3Array, r: float) -> void:
	var up := Vector3.UP
	var last: Array = []
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := t.cross(up)
		if side.length_squared() < 1e-6:
			side = t.cross(Vector3.RIGHT)
		side = side.normalized()
		up = side.cross(t).normalized()
		var ring: Array = []
		for k in 3:
			var a := TAU * k / 3.0
			var d := side * cos(a) + up * sin(a)
			ring.append([pts[i] + d * r, d])
		if not last.is_empty():
			for k in 3:
				var k2 := (k + 1) % 3
				var a0: Array = last[k]
				var a1: Array = last[k2]
				var b0: Array = ring[k]
				var b1: Array = ring[k2]
				_tri(v, n, a0[0], b0[0], b1[0], a0[1], b0[1], b1[1])
				_tri(v, n, a0[0], b1[0], a1[0], a0[1], b1[1], a1[1])
		last = ring


## Barbs every `every` metres along the wire: little four-pointed stars of
## sharpened wire (razor tape's blades read the same from any distance).
static func barbs(v: PackedVector3Array, n: PackedVector3Array, pts: PackedVector3Array, every: float, size: float, rng: RandomNumberGenerator) -> void:
	var run := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i] - pts[i - 1]
		run += seg.length()
		if run < every:
			continue
		run = 0.0
		var t := seg.normalized()
		var s := t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
		var u := s.cross(t)
		var a := rng.randf() * TAU
		var d1 := (s * cos(a) + u * sin(a)) * size
		var d2 := (s * -sin(a) + u * cos(a)) * size
		var p := pts[i]
		for d in [d1, d2]:
			var tip0: Vector3 = p + d
			var tip1: Vector3 = p - d
			var w: Vector3 = t * size * 0.35
			var nn: Vector3 = (d as Vector3).cross(t).normalized()
			_tri(v, n, tip0, p + w, tip1, nn, nn, nn)
			_tri(v, n, tip0, tip1, p + w, -nn, -nn, -nn)
			_tri(v, n, tip0, p - w, tip1, -nn, -nn, -nn)
			_tri(v, n, tip0, tip1, p - w, nn, nn, nn)


## A triangle (a, b, c) with per-corner normals, wound the way Godot draws
## front faces whichever way it was given.
static func _tri(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		v.append_array([a, c, b])
		n.append_array([na, nc, nb])
	else:
		v.append_array([a, b, c])
		n.append_array([na, nb, nc])
