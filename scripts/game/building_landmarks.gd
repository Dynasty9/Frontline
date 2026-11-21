class_name BuildingLandmarks
extends RefCounted
## The landmarks over a town's roofs: its water tower. In a kit standing on
## the ground (y = 0).

const STEEL := Color(0.58, 0.6, 0.58)
const RUST := Color(0.42, 0.27, 0.17)


## A steel water tower about 13.7 m to its finial: four legs of round column
## splayed out to concrete piers, two tiers of struts with crossed tension
## rods between them, the riser pipe up the middle; the tank 4.6 m across on
## its ring girder, a catwalk round its foot with a railing, its plates in
## riveted bands with rust weeping down from the seams, a cone roof with a
## hatch, a vent and a finial; a ladder up one leg in its safety cage to the
## catwalk, another up the tank to the roof.
static func water_tower(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var paint := STEEL.lerp(Color(0.52, 0.58, 0.54), rng.randf() * 0.5)
	var top := 9.2
	var foot := 2.7
	var head := 1.7
	var legs: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var a := Vector3(sx * foot, 0.4, sz * foot)
			var b := Vector3(sx * head, top, sz * head)
			legs.append(b)
			k.box(Vector3(0.8, 0.5, 0.8), Vector3(sx * foot, 0.25, sz * foot), "concrete", Color(0.55, 0.54, 0.5))
			k.box(Vector3(0.36, 0.06, 0.36), Vector3(sx * foot, 0.53, sz * foot), "steel", paint.darkened(0.2), Vector3.ZERO, false)
			k.rod(a, b, 0.13, "paint", paint, 10)
	# the struts and the crossed rods in each face, two tiers
	var ys := [0.4, 3.4, 6.4, top - 0.3]
	var at := func(c: int, y: float) -> Vector3:
		var cx := -1.0 if c < 2 else 1.0
		var cz := -1.0 if c % 2 == 0 else 1.0
		var r := lerpf(foot, head, (y - 0.4) / (top - 0.4))
		return Vector3(cx * r, y, cz * r)
	var faces := [[0, 1], [1, 3], [3, 2], [2, 0]]
	for t in range(1, ys.size()):
		for f: Array in faces:
			var a0: Vector3 = at.call(f[0], ys[t])
			var a1: Vector3 = at.call(f[1], ys[t])
			k.rod(a0, a1, 0.07, "paint", paint, 8)
			if t < ys.size() - 1:
				var b0: Vector3 = at.call(f[0], ys[t - 1] + 0.1)
				var b1: Vector3 = at.call(f[1], ys[t - 1] + 0.1)
				k.rod(b0, a1, 0.022, "steel", paint.darkened(0.15), 6, false)
				k.rod(b1, a0, 0.022, "steel", paint.darkened(0.15), 6, false)
				# a turnbuckle midway along each rod
				k.cyl(0.04, 0.04, 0.22, (b0 + a1) * 0.5, "steel", paint.darkened(0.25), Vector3.ZERO, 6, false)
	# the riser up the middle to the tank's bottom
	k.cyl(0.2, 0.2, top + 0.2, Vector3(0, (top + 0.2) * 0.5, 0), "paint", paint.darkened(0.08), Vector3.ZERO, 12)
	k.cyl(0.32, 0.32, 0.2, Vector3(0, 0.1, 0), "concrete", Color(0.5, 0.5, 0.47), Vector3.ZERO, 12)
	# the ring girder, the catwalk and its railing
	k.cyl(2.45, 2.45, 0.3, Vector3(0, top + 0.05, 0), "steel", paint.darkened(0.12), Vector3.ZERO, 24)
	k.cyl(2.95, 2.95, 0.06, Vector3(0, top + 0.22, 0), "steel", paint.darkened(0.2), Vector3.ZERO, 28)
	for i in 24:
		var a := TAU * i / 24.0
		var p := Vector3(cos(a) * 2.9, top + 0.25, sin(a) * 2.9)
		k.rod(p, p + Vector3(0, 1.05, 0), 0.022, "steel", paint, 4, false)
		var a1 := TAU * (i + 1) / 24.0
		var q := Vector3(cos(a1) * 2.9, top + 0.25, sin(a1) * 2.9)
		for h: float in [0.55, 1.05]:
			k.rod(p + Vector3(0, h, 0), q + Vector3(0, h, 0), 0.018, "steel", paint, 4, false)
	# the tank: its bottom dished, its plates in riveted bands, rust down the seams
	var tb := top + 0.25
	var th := 2.9
	k.cyl(2.3, 1.6, 0.4, Vector3(0, tb - 0.15, 0), "paint", paint.darkened(0.05), Vector3.ZERO, 24)
	k.cyl(2.3, 2.3, th, Vector3(0, tb + th * 0.5, 0), "paint", paint, Vector3.ZERO, 28)
	for band in 4:
		var y := tb + (band + 0.5) * th / 4.0 + th / 8.0
		if band < 3:
			k.cyl(2.32, 2.32, 0.05, Vector3(0, y, 0), "steel", paint.darkened(0.12), Vector3.ZERO, 28, false)
	# (rust weeping from the top seam: a faint streak, fading as it runs)
	for i in 16:
		var a := TAU * i / 16.0 + rng.randf_range(-0.1, 0.1)
		if rng.randf() < 0.6:
			var len := rng.randf_range(0.5, th * 0.8)
			var w := rng.randf_range(0.12, 0.3)
			var face := Basis(Vector3.UP, -a + PI * 0.5)
			for seg in 3:
				var sl := len / 3.0
				k.part(Res.box(Vector3(w * (1.0 - seg * 0.2), sl, 0.008)), "paint", Transform3D(face, Vector3(cos(a) * 2.306, tb + th - 0.2 - sl * (seg + 0.5), sin(a) * 2.306)), RUST.lerp(paint, 0.55 + seg * 0.14), false)
	# the roof: a cone, its hatch, a vent, the finial
	var rb := tb + th
	k.cyl(2.38, 2.38, 0.08, Vector3(0, rb + 0.04, 0), "steel", paint.darkened(0.1), Vector3.ZERO, 28)
	k.cyl(0.18, 2.4, 0.9, Vector3(0, rb + 0.53, 0), "paint", paint.darkened(0.06), Vector3.ZERO, 28)
	k.cyl(0.22, 0.22, 0.22, Vector3(0, rb + 1.07, 0), "paint", paint.darkened(0.1), Vector3.ZERO, 12)
	k.cyl(0.0, 0.3, 0.2, Vector3(0, rb + 1.28, 0), "paint", paint.darkened(0.15), Vector3.ZERO, 12)
	k.part(Res.sphere(0.07, 8), "steel", Transform3D(Basis.IDENTITY, Vector3(0, rb + 1.42, 0)), paint.darkened(0.2), false)
	k.box(Vector3(0.6, 0.1, 0.5), Vector3(1.1, rb + 0.45, 0), "paint", paint.darkened(0.12), Vector3(0, 0, -0.42), false)
	# the ladder up the +x leg in its cage, and up the tank's side
	var la: Vector3 = Vector3(foot, 0.6, 0.2)
	var lb: Vector3 = Vector3(head + 0.9, top + 0.2, 0.2)
	for sz: float in [-0.22, 0.22]:
		k.rod(la + Vector3(0, 0, sz), lb + Vector3(0, 0, sz), 0.02, "steel", paint, 4, false)
	var rungs := 28
	for i in rungs:
		var p := la.lerp(lb, (i + 0.5) / rungs)
		k.rod(p + Vector3(0, 0, -0.22), p + Vector3(0, 0, 0.22), 0.012, "steel", paint, 4, false)
		if i > 6 and i % 3 == 0:
			k.part(BuildingKit.ring(0.32, 0.35), "steel", Transform3D(Basis(Vector3.BACK, -atan2(lb.x - la.x, lb.y - la.y)), p + Vector3(0.3, 0, 0)), paint.darkened(0.1), false)
	for sz: float in [-0.2, 0.2]:
		k.rod(Vector3(2.32, tb, 0.9 + sz), Vector3(2.32, rb + 0.1, 0.9 + sz), 0.018, "steel", paint, 4, false)
	for i in 10:
		var y := tb + 0.2 + i * (th - 0.2) / 10.0
		k.rod(Vector3(2.33, y, 0.7), Vector3(2.33, y, 1.1), 0.011, "steel", paint, 4, false)
