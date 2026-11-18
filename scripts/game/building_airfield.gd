class_name BuildingAirfield
extends RefCounted
## A forward helipad and what's round it: the pad (a regular army's of
## aluminium landing mat, a militia's of patched concrete), its markings, the
## windsock, the fuel bladder on its berm, chocks and tie-downs. In a kit
## standing on the ground (y = 0).

const WHITE := Color(0.88, 0.88, 0.83)
const SOCK := Color(0.95, 0.42, 0.08)


## A helipad `size` square: the pad, a touchdown circle round a painted H,
## edge markers, tie-down rings, the windsock on its mast at one corner, a
## fuel bladder on its berm off another with its hose and pump, chocks, the
## flagpole (returns where its flag's hoist is).
static func helipad(k: BuildingKit, size: Vector3, team: int, rng: RandomNumberGenerator) -> Vector3:
	var hs := size.x * 0.5
	if team != 1:
		# aluminium landing mat: planks laid in a bond, their joints, the
		# ramp panels round its edge
		# (dull, a painted grey-green: landing mat isn't polished)
		k.box(Vector3(size.x, 0.05, size.z), Vector3(0, 0.025, 0), "plain", Color(0.33, 0.35, 0.31))
		var rows := roundi(size.z / 0.5)
		for r in rows:
			var z := -hs + (r + 0.5) * size.z / rows
			k.plate(Vector3(size.x, 0.006, 0.012), Vector3(0, 0.053, z - size.z / rows * 0.5), "metal_dark", Color(0.2, 0.2, 0.19))
			var shift := 1.8 if r % 2 == 0 else 0.0
			var x := -hs + shift
			while x < hs - 0.1:
				if x > -hs + 0.1:
					k.plate(Vector3(0.012, 0.006, size.z / rows), Vector3(x, 0.053, z), "metal_dark", Color(0.2, 0.2, 0.19), Vector3.ZERO, false)
				x += 3.6
		for side in 4:
			var a := side * PI * 0.5
			k.part(Res.box(Vector3(size.x + 0.4, 0.04, 0.3)), "steel", Transform3D(Basis(Vector3.UP, a), Vector3(sin(a), 0, cos(a)) * (hs + 0.14) + Vector3(0, 0.02, 0)) * Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3.ZERO), Color(0.33, 0.34, 0.31))
	else:
		# a concrete pad, cracked and patched, its edge broken
		k.box(Vector3(size.x, 0.12, size.z), Vector3(0, 0.06, 0), "concrete", Color(0.5, 0.49, 0.46))
		for i in rng.randi_range(4, 7):
			k.plate(Vector3(rng.randf_range(0.6, 1.8), 0.01, rng.randf_range(0.5, 1.4)), Vector3(rng.randf_range(-hs + 1.0, hs - 1.0), 0.125, rng.randf_range(-hs + 1.0, hs - 1.0)), "asphalt", null, Vector3(0, rng.randf() * TAU, 0))
		for i in rng.randi_range(5, 9):
			k.plate(Vector3(rng.randf_range(1.0, 3.0), 0.008, 0.03), Vector3(rng.randf_range(-hs + 0.5, hs - 0.5), 0.126, rng.randf_range(-hs + 0.5, hs - 0.5)), "plain_dark", Color(0.18, 0.18, 0.17), Vector3(0, rng.randf() * TAU, 0), false)
	var top := 0.06 if team != 1 else 0.125
	# the touchdown circle and the H
	# (painted on in short dashes round the ring, flat)
	for i in 32:
		var a := TAU * i / 32.0
		k.plate(Vector3(0.3, 0.008, 0.64), Vector3(cos(a) * 3.35, top + 0.004, sin(a) * 3.35), "paint", WHITE.darkened(rng.randf_range(0.0, 0.1)), Vector3(0, -a, 0), false)
	for sx: float in [-1.0, 1.0]:
		k.plate(Vector3(0.5, 0.008, 3.6), Vector3(sx * 1.2, top + 0.005, 0), "paint", WHITE, Vector3.ZERO, false)
	k.plate(Vector3(2.4, 0.008, 0.5), Vector3(0, top + 0.005, 0), "paint", WHITE, Vector3.ZERO, false)
	# edge markers: halved tyres painted white, a tie-down ring by each
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector3(cos(a), 0, sin(a)) * (hs - 0.45) * (1.0 / maxf(absf(cos(a)), absf(sin(a))))
		p = p.clamp(Vector3(-hs + 0.35, 0, -hs + 0.35), Vector3(hs - 0.35, 0, hs - 0.35))
		k.part(Res.torus(0.12, 0.3), "rubber", Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(0, top, 0)) * Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.0)), Vector3.ZERO), WHITE.darkened(0.1), false)
		k.part(BuildingKit.ring(0.05, 0.075), "steel", Transform3D(Basis.IDENTITY, p * 0.8 + Vector3(0, top + 0.01, 0)), Color(0.45, 0.45, 0.44), false)
	# the windsock: a steel mast on its foot, the frame, the striped sock lifting a little
	var ws := Vector3(hs + 0.2, 0, -hs - 0.2)
	k.box(Vector3(0.5, 0.15, 0.5), ws + Vector3(0, 0.075, 0), "concrete", Color(0.5, 0.5, 0.47))
	k.cyl(0.04, 0.06, 4.2, ws + Vector3(0, 2.25, 0), "steel", Color(0.72, 0.72, 0.7), Vector3.ZERO, 8)
	var lift := Basis(Vector3.BACK, rng.randf_range(-0.55, -0.25))
	var mouth := ws + Vector3(0.12, 4.15, 0)
	k.part(BuildingKit.ring(0.25, 0.28), "steel", Transform3D(lift * Basis(Vector3.BACK, PI * 0.5), mouth), Color(0.72, 0.72, 0.7), false)
	k.rod(ws + Vector3(0, 4.15, 0), mouth, 0.02, "steel", Color(0.72, 0.72, 0.7), 4, false)
	for s in 5:
		var r0 := 0.26 - s * 0.035
		var r1 := 0.26 - (s + 1) * 0.035
		var c := lift * Vector3(0.12 + (s + 0.5) * 0.24, 0, 0)
		k.part(Res.cyl(r1, r0, 0.24, 12), "fabric", Transform3D(lift * Basis(Vector3.BACK, PI * 0.5), mouth + c), SOCK if s % 2 == 0 else WHITE, false)
	# the fuel bladder on its berm off a corner, its hose to a pump
	var fb := Vector3(-hs - 0.1, 0, -hs + 1.2)
	k.part(Res.sphere(0.5, 10), "film", Transform3D(Basis.from_scale(Vector3(1.0, 0.45, 2.2)), fb + Vector3(0, 0.2, 0)), Color(0.12, 0.14, 0.11), true)
	k.part(Res.sphere(0.5, 8), "earth", Transform3D(Basis.from_scale(Vector3(1.5, 0.25, 2.7)), fb + Vector3(0, 0.02, 0)), Color(0.32, 0.26, 0.18), false)
	k.box(Vector3(0.6, 0.45, 0.45), fb + Vector3(0.6, 0.22, 1.5), "paint", Color(0.3, 0.34, 0.22))
	BuildingWire.cable(k, fb + Vector3(0.3, 0.2, 0.9), fb + Vector3(0.6, 0.3, 1.5), 0.05, 0.03, "rubber", Color(0.08, 0.08, 0.08))
	BuildingWire.cable(k, fb + Vector3(0.9, 0.3, 1.5), Vector3(-hs + 1.4, top + 0.04, -hs + 2.6), 0.04, 0.03, "rubber", Color(0.08, 0.08, 0.08))
	# chocks by the pad, a fire extinguisher on its stand
	for i in 2:
		k.prism(Vector3(0.35, 0.16, 0.2), Vector3(-hs + 0.8 + i * 0.5, top + 0.08, hs - 0.6), "paint", Color(0.85, 0.72, 0.12), Vector3(0, i * 0.4, 0), false)
	k.box(Vector3(0.05, 0.8, 0.05), Vector3(hs - 0.4, 0.4, hs - 0.4), "steel", Color(0.5, 0.5, 0.5), Vector3.ZERO, false)
	k.cyl(0.08, 0.08, 0.5, Vector3(hs - 0.4, 0.55, hs - 0.32), "paint", Color(0.75, 0.1, 0.08), Vector3.ZERO, 10, false)
	# the flagpole at the last corner
	return BuildingFittings.flagpole(k, Vector3(-hs - 0.3, 0, hs + 0.3), 4.2, Color(0.7, 0.7, 0.68))
