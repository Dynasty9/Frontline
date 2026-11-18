class_name BuildingUtility
extends RefCounted

## The overhead line's timber poles, `k` at a pole's foot (Decor "pole"): a
## tapered, creosoted pole darker where it stands in the ground, a weather cap
## on top, the crossarm across the line (local z) on two steel braces, three
## pin insulators the wires hang from (Decor strings them to 7.66 m), steps up
## the pole out of a child's reach, its number and the danger plate at eye
## height, the earth wire down one side under a guard. Every so often the pole
## carries the street's transformer: a finned tank on a platform of channels,
## its bushings, the fuses on the crossarm, the cable down in a conduit.

const TIMBER := Color(0.3, 0.24, 0.17)
const STEEL := Color(0.34, 0.35, 0.34)
const GALV := Color(0.6, 0.61, 0.6)  # galvanised: steps, braces, bands
const HEIGHT := 8.4
const ARM := 7.45  # the crossarm's middle


static func pole(k: BuildingKit, transformer: bool, rng: RandomNumberGenerator) -> void:
	var col := Res.vary(TIMBER, 0.05, rng)
	k.cyl(0.11, 0.16, HEIGHT, Vector3(0, HEIGHT * 0.5, 0), "wood_dark", col)
	# (soaked darker where it comes out of the ground, and splashed)
	k.cyl(0.158, 0.165, 0.45, Vector3(0, 0.22, 0), "wood_dark", col.darkened(0.35))
	k.cyl(0.13, 0.13, 0.04, Vector3(0, HEIGHT + 0.02, 0), "metal_dark", STEEL)
	# the crossarm on its braces, the insulators on its pins
	k.box(Vector3(0.12, 0.11, 2.0), Vector3(0, ARM, 0), "wood_dark", col.darkened(0.08))
	for sz: float in [-1.0, 1.0]:
		k.bar(Vector3(0, ARM - 0.6, 0.0), Vector3(0, ARM - 0.06, sz * 0.62), 0.04, 0.008, "steel", GALV)
	k.box(Vector3(0.16, 0.07, 0.14), Vector3(0, ARM, 0), "steel", GALV)  # (the bolt through it)
	for z: float in [-0.8, 0.0, 0.8]:
		BuildingWire.insulator(k, Vector3(0, ARM + 0.02, z))
	# steps, staggered either side from out of reach to the crossarm
	var y := 2.6
	var side := 1.0
	while y < ARM - 0.7:
		var r := lerpf(0.155, 0.12, y / HEIGHT)
		k.cyl(0.014, 0.014, 0.24, Vector3(side * (r + 0.1), y, 0), "steel", GALV, Vector3(0, 0, PI * 0.5), 5)
		y += 0.42
		side = -side
	# the number plate and the danger plate, facing along the line (local x)
	var face := 0.16
	k.plate(Vector3(0.012, 0.13, 0.09), Vector3(face, 1.85, 0), "paint", Color(0.82, 0.82, 0.78))
	for i in 3:
		k.plate(Vector3(0.004, 0.022, 0.012), Vector3(face + 0.008, 1.88 - i * 0.035, -0.02 + rng.randi_range(0, 2) * 0.02), "paint", Color(0.08, 0.08, 0.08))
	k.plate(Vector3(0.012, 0.22, 0.18), Vector3(face - 0.005, 2.3, 0), "paint", Color(0.85, 0.7, 0.1))
	k.plate(Vector3(0.004, 0.12, 0.03), Vector3(face + 0.003, 2.3, 0), "paint", Color(0.1, 0.09, 0.08), Vector3(0.4, 0, 0))  # (the bolt of lightning)
	# the earth wire down the far side, under a guard to head height
	k.rod(Vector3(0, ARM - 0.3, -0.12), Vector3(0, 2.5, -0.165), 0.008, "steel", Color(0.55, 0.38, 0.22))
	k.box(Vector3(0.06, 2.5, 0.035), Vector3(0, 1.25, -0.175), "paint", Color(0.3, 0.32, 0.3))
	if transformer:
		_transformer(k, rng)


## A pole transformer, hung on the pole's +x side at about 6 m.
static func _transformer(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var c := Vector3(0.42, 6.3, 0)
	var tank := Color(0.5, 0.52, 0.48)
	# the platform: two channels through the pole under it, a strap round
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(0.9, 0.1, 0.05), Vector3(0.22, 5.8, sz * 0.17), "steel", STEEL)
	k.cyl(0.172, 0.172, 0.05, Vector3(0, 6.55, 0), "steel", GALV)
	# the tank, its cooling fins round the sides, the lid, the bushings
	k.cyl(0.27, 0.27, 0.85, c, "paint", tank)
	for i in 10:
		var a := i * TAU / 10.0 + 0.3
		if cos(a) < -0.6:
			continue  # (none on the side against the pole)
		k.box(Vector3(0.1, 0.62, 0.016), c + Vector3(cos(a), 0, sin(a)) * 0.31, "paint", tank.darkened(0.06), Vector3(0, -a, 0))
	k.cyl(0.28, 0.29, 0.05, c + Vector3(0, 0.45, 0), "paint", tank.darkened(0.12))
	for sz: float in [-1.0, 1.0]:
		BuildingWire.insulator(k, c + Vector3(-0.05, 0.47, sz * 0.12))
		# the fuse on the crossarm above it, and the jumper down to the bushing
		k.cyl(0.02, 0.02, 0.32, Vector3(0.0, ARM - 0.3, sz * 0.45), "paint", Color(0.55, 0.3, 0.2), Vector3(0.25 * sz, 0, 0), 5)
		k.rod(Vector3(0.0, ARM - 0.45, sz * 0.45), c + Vector3(-0.05, 0.6, sz * 0.12), 0.007, "steel", Color(0.25, 0.25, 0.25))
	# the cable from it down the pole to the ground, in a conduit
	k.rod(c + Vector3(-0.2, -0.3, 0.15), Vector3(0.17, 3.0, 0.14), 0.02, "metal_dark", Color(0.15, 0.15, 0.14))
	k.box(Vector3(0.07, 3.0, 0.07), Vector3(0.17, 1.5, 0.14), "metal_dark", Color(0.2, 0.21, 0.2))
	if rng.randf() < 0.5:
		k.plate(Vector3(0.008, 0.1, 0.16), c + Vector3(0.28, 0.0, 0), "paint", Color(0.85, 0.7, 0.1))
