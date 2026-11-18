class_name BuildingPlay
extends RefCounted
## A town playground's equipment, as councils put it up: round steel tube
## painted bright and gone chalky, galvanised chains, rubber seats, timber
## kerbs. Each in a kit standing on the ground (y = 0).

const STEEL := Color(0.62, 0.63, 0.62)
const CHAIN := Color(0.55, 0.56, 0.55)
const RUBBER := Color(0.1, 0.1, 0.1)


## A tube from `a` to `b`, `r` thick, in paint `col`.
static func _tube(k: BuildingKit, a: Vector3, b: Vector3, r: float, col: Color, shadow := true) -> void:
	k.rod(a, b, r, "paint", col, 8, shadow)


## A chain from `a` down to `b`: links as short rods turned in turn.
static func chain(k: BuildingKit, a: Vector3, b: Vector3) -> void:
	var n := maxi(2, roundi(a.distance_to(b) / 0.09))
	for i in n:
		var p0 := a.lerp(b, float(i) / n)
		var p1 := a.lerp(b, float(i + 1) / n)
		var off := Vector3(0.008, 0, 0) if i % 2 == 0 else Vector3(0, 0, 0.008)
		k.rod(p0 + off, p1 - off, 0.007, "steel", CHAIN, 4, false)


## A swing frame 3.5 m along x: an A-frame of tube at each end, the top bar,
## two flat rubber seats on chains (one a toddler's cradle seat, `cradle`).
static func swings(k: BuildingKit, col: Color, cradle: bool) -> void:
	var top := 2.4
	for sx: float in [-1.75, 1.75]:
		for sz: float in [-0.85, 0.85]:
			_tube(k, Vector3(sx, 0, sz), Vector3(sx, top, 0), 0.045, col)
		_tube(k, Vector3(sx, 0.9, -0.5), Vector3(sx, 0.9, 0.5), 0.03, col, false)
		k.cyl(0.07, 0.07, 0.1, Vector3(sx, top, 0), "paint", col.darkened(0.1), Vector3(0, 0, PI * 0.5), 10, false)
	_tube(k, Vector3(-1.8, top, 0), Vector3(1.8, top, 0), 0.05, col)
	for i in 2:
		var x := -0.75 + i * 1.5
		var seat := 0.5
		for dx: float in [-0.22, 0.22]:
			k.box(Vector3(0.05, 0.06, 0.05), Vector3(x + dx, top - 0.06, 0), "steel", STEEL, Vector3.ZERO, false)
			chain(k, Vector3(x + dx, top - 0.1, 0), Vector3(x + dx, seat + 0.03, 0))
		if cradle and i == 1:
			# a cradle seat: a rubber cup with leg holes, a bar round its front
			k.box(Vector3(0.36, 0.22, 0.3), Vector3(x, seat + 0.05, 0), "rubber", RUBBER)
			k.box(Vector3(0.3, 0.08, 0.24), Vector3(x, seat + 0.17, 0), "rubber", Color(0.15, 0.15, 0.15), Vector3.ZERO, false)
		else:
			k.box(Vector3(0.46, 0.035, 0.18), Vector3(x, seat, 0), "rubber", RUBBER)
			k.box(Vector3(0.48, 0.05, 0.03), Vector3(x, seat + 0.02, 0.09), "steel", STEEL, Vector3.ZERO, false)
			k.box(Vector3(0.48, 0.05, 0.03), Vector3(x, seat + 0.02, -0.09), "steel", STEEL, Vector3.ZERO, false)


## A slide running down along +x: a tower of tube with a deck and its
## guard rails under a little roof, a ladder of round rungs up its back
## (-x), the steel chute with its raised sides and a run-out at the foot.
static func slide(k: BuildingKit, col: Color, roof: Color) -> void:
	var deck := 1.5
	var tx := -0.85
	for sx: float in [-0.4, 0.4]:
		for sz: float in [-0.4, 0.4]:
			_tube(k, Vector3(tx + sx, 0, sz), Vector3(tx + sx, deck + 1.0, sz), 0.04, col)
	k.box(Vector3(0.84, 0.05, 0.84), Vector3(tx, deck, 0), "wood", Color(0.5, 0.38, 0.24))
	for sz: float in [-0.4, 0.4]:
		_tube(k, Vector3(tx - 0.4, deck + 0.6, sz), Vector3(tx + 0.4, deck + 0.6, sz), 0.025, col, false)
		for i in 4:
			_tube(k, Vector3(tx - 0.3 + i * 0.2, deck, sz), Vector3(tx - 0.3 + i * 0.2, deck + 0.6, sz), 0.012, col, false)
	k.prism(Vector3(1.0, 0.4, 1.0), Vector3(tx, deck + 1.2, 0), "paint", roof, Vector3(0, PI * 0.5, 0))
	# the ladder up its back
	for sz: float in [-0.25, 0.25]:
		_tube(k, Vector3(tx - 0.75, 0, sz), Vector3(tx - 0.42, deck + 0.7, sz), 0.03, col)
	for i in 5:
		var t := (i + 0.6) / 6.0
		var p := Vector3(tx - 0.75, 0, 0).lerp(Vector3(tx - 0.42, deck + 0.7, 0), t)
		k.rod(p + Vector3(0, 0, -0.25), p + Vector3(0, 0, 0.25), 0.018, "steel", STEEL, 6, false)
	# the chute: a steel bed between raised sides, falling to its run-out
	var a := Vector3(tx + 0.4, deck, 0)
	var b := Vector3(1.5, 0.32, 0)
	var run := Vector3(2.02, 0.3, 0)
	for seg: Array in [[a, b], [b, run]]:
		var p0: Vector3 = seg[0]
		var p1: Vector3 = seg[1]
		var mid := (p0 + p1) * 0.5
		var dv := p1 - p0
		var ang := atan2(dv.y, dv.x)
		k.box(Vector3(dv.length() + 0.02, 0.03, 0.5), mid, "steel", STEEL.lightened(0.1), Vector3(0, 0, ang))
		for sz: float in [-0.27, 0.27]:
			k.box(Vector3(dv.length() + 0.02, 0.18, 0.04), mid + Vector3(0, 0.08, sz), "paint", col, Vector3(0, 0, ang))
	_tube(k, Vector3(2.0, 0, -0.2), Vector3(2.0, 0.3, -0.2), 0.03, col, false)
	_tube(k, Vector3(2.0, 0, 0.2), Vector3(2.0, 0.3, 0.2), 0.03, col, false)


## A climbing frame: a dome of curved tube over a square of 2 m, its rungs in
## rings round it.
static func climber(k: BuildingKit, col: Color) -> void:
	var r := 1.15
	var ribs := 8
	for i in ribs:
		var a := TAU * i / ribs
		var prev := Vector3(cos(a) * r, 0, sin(a) * r)
		for s in 6:
			var t := (s + 1) / 6.0 * PI * 0.5
			var p := Vector3(cos(a) * r * cos(t), r * 1.45 * sin(t), sin(a) * r * cos(t))
			_tube(k, prev, p, 0.03, col, s < 3)
			prev = p
	for ring in 3:
		var t := (ring + 1) / 4.0 * PI * 0.5
		var y := r * 1.45 * sin(t)
		var rr := r * cos(t)
		for i in ribs:
			var a0 := TAU * i / ribs
			var a1 := TAU * (i + 1) / ribs
			_tube(k, Vector3(cos(a0) * rr, y, sin(a0) * rr), Vector3(cos(a1) * rr, y, sin(a1) * rr), 0.022, col.lightened(0.1), false)


## A seesaw along x: its pivot on a sprung base, the plank, a seat and a
## grab handle at each end, a tyre half sunk under each to soften the bump.
static func seesaw(k: BuildingKit, col: Color) -> void:
	k.box(Vector3(0.5, 0.06, 0.5), Vector3(0, 0.03, 0), "concrete", Color(0.5, 0.5, 0.48))
	for sz: float in [-0.16, 0.16]:
		_tube(k, Vector3(-0.18, 0, sz), Vector3(0, 0.5, sz), 0.035, STEEL)
		_tube(k, Vector3(0.18, 0, sz), Vector3(0, 0.5, sz), 0.035, STEEL)
	var tilt := 0.14
	var plank := k.at_point(Vector3(0, 0.52, 0), Vector3(0, 0, tilt))
	plank.box(Vector3(3.4, 0.07, 0.3), Vector3.ZERO, "paint", col)
	for sx: float in [-1.0, 1.0]:
		plank.box(Vector3(0.36, 0.08, 0.32), Vector3(sx * 1.45, 0.06, 0), "rubber", RUBBER)
		plank.rod(Vector3(sx * 1.2, 0.03, -0.12), Vector3(sx * 1.2, 0.3, -0.12), 0.02, "paint", col.darkened(0.15), 6, false)
		plank.rod(Vector3(sx * 1.2, 0.03, 0.12), Vector3(sx * 1.2, 0.3, 0.12), 0.02, "paint", col.darkened(0.15), 6, false)
		plank.rod(Vector3(sx * 1.2, 0.3, -0.12), Vector3(sx * 1.2, 0.3, 0.12), 0.02, "paint", col.darkened(0.15), 6, false)
		k.part(Res.torus(0.14, 0.3), "rubber", Transform3D(Basis.IDENTITY, Vector3(sx * 1.55, 0.02, 0)), RUBBER, false)


## A sandpit 2.8 m square: kerbs of timber with a seat board round them, the
## sand heaped and dug, a bucket and spade left in it.
static func sandpit(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var wood := Color(0.46, 0.35, 0.22)
	for side in 4:
		var a := side * PI * 0.5
		var f := k.at_point(Vector3(sin(a), 0, cos(a)) * 1.32, Vector3(0, a, 0))
		f.box(Vector3(2.8, 0.28, 0.14), Vector3(0, 0.14, 0), "wood", wood.darkened(rng.randf_range(0.0, 0.1)))
		f.box(Vector3(2.9, 0.04, 0.3), Vector3(0, 0.3, 0.02), "wood", wood.lightened(0.08))
	k.box(Vector3(2.5, 0.08, 2.5), Vector3(0, 0.08, 0), "earth", Color(0.82, 0.74, 0.55), Vector3.ZERO, false)
	for i in 3:
		var p := Vector3(rng.randf_range(-0.7, 0.7), 0.12, rng.randf_range(-0.7, 0.7))
		k.part(Res.sphere(0.5, 8), "earth", Transform3D(Basis.from_scale(Vector3(rng.randf_range(0.4, 0.8), 0.12, rng.randf_range(0.4, 0.8))), p), Color(0.8, 0.72, 0.53), false)
	var toy: Color = [Color(0.85, 0.2, 0.15), Color(0.2, 0.45, 0.8), Color(0.95, 0.75, 0.15)][rng.randi() % 3]
	k.cyl(0.09, 0.07, 0.14, Vector3(0.6, 0.19, 0.4), "paint", toy, Vector3(0.3, 0, 0.2), 10, false)
	k.box(Vector3(0.05, 0.02, 0.3), Vector3(0.35, 0.14, 0.55), "paint", toy.darkened(0.2), Vector3(0, 0.7, 0), false)


## A roundabout: a disc of steel on its hub, painted in segments, the grab
## rails over it.
static func roundabout(k: BuildingKit, cols: Array) -> void:
	k.cyl(0.18, 0.22, 0.3, Vector3(0, 0.15, 0), "metal_dark", Color(0.2, 0.2, 0.2), Vector3.ZERO, 10)
	k.cyl(1.1, 1.1, 0.06, Vector3(0, 0.33, 0), "paint", cols[0], Vector3.ZERO, 24)
	k.cyl(1.12, 1.12, 0.04, Vector3(0, 0.32, 0), "steel", STEEL, Vector3.ZERO, 24, false)
	# the steel strips between its sections
	for i in 4:
		var a := TAU * i / 4.0
		k.box(Vector3(2.16, 0.012, 0.05), Vector3(0, 0.366, 0), "steel", STEEL, Vector3(0, a * 0.5, 0), false)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var out := Vector3(cos(a), 0, sin(a))
		_tube(k, out * 0.95 + Vector3(0, 0.36, 0), out * 0.25 + Vector3(0, 0.95, 0), 0.025, STEEL, false)
	k.cyl(0.25, 0.25, 0.04, Vector3(0, 0.97, 0), "steel", STEEL, Vector3.ZERO, 12, false)
