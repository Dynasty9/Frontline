class_name BuildingUtility
extends RefCounted

## The overhead line's timber poles, `k` at a pole's foot (Decor "pole"): a
## tapered, creosoted pole darker where it stands in the ground, a weather cap
## on top, the crossarm across the line (local z) on two steel braces, three
## pin insulators the wires hang from (Decor strings them to 7.66 m), steps up
## the pole out of a child's reach, its number and the danger plate at eye
## height, a thin earth wire stapled flat down one side. Every so often the
## pole carries the street's transformer: a finned tank on a platform of
## channels, its bushings, the fuses on the crossarm, its cable clipped flat
## down the pole.

const TIMBER := Color(0.3, 0.24, 0.17)
const STEEL := Color(0.34, 0.35, 0.34)
const GALV := Color(0.6, 0.61, 0.6)  # galvanised: steps, braces, bands
const COPPER := Color(0.7, 0.46, 0.26)  # bare copper, dulled
const SHEATH := Color(0.4, 0.41, 0.4)  # a cable's grey sheath, weathered
const HEIGHT := 8.4
const ARM := 7.45  # the crossarm's middle
# What comes down a pole to the ground is stapled flat along an edge of it:
# the earth wire on the far side (-z), a transformer's cable on the edge
# between the plates and the earth wire. Each is one plain wire a centimetre
# or so across, lying on the wood: no guard or conduit standing off the pole.
const EARTH := Vector3(0, 0, -1)
const CABLE := Vector3(0.7071, 0, -0.7071)
const EARTH_R := 0.005
const CABLE_R := 0.007


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
	# the earth wire: bare copper stapled flat down the far edge, from the
	# brace's foot (it bonds the ironwork) into the ground
	_down(k, EARTH, 6.95, EARTH_R, "steel", COPPER)
	if transformer:
		_transformer(k, rng)


## The pole's radius `y` up it: it tapers from 0.16 at the ground to 0.11.
static func radius(y: float) -> float:
	return lerpf(0.16, 0.11, y / HEIGHT)


## The middle of a wire `r` thick lying on the pole's edge toward `dir` (a
## level unit vector), `y` up it.
static func on_pole(dir: Vector3, y: float, r: float) -> Vector3:
	return dir * (radius(y) + r) + Vector3(0, y, 0)


## A wire stapled flat down the pole's edge toward `dir`, from `top` into the
## ground: the pole's taper is straight, so the wire is one straight piece.
## (Drawn from the ground up: BuildingKit.aim turns a rod pointing all but
## straight down to plumb, which would stand it off the taper.)
static func _down(k: BuildingKit, dir: Vector3, top: float, r: float, kind: String, col: Color) -> void:
	k.rod(on_pole(dir, 0.0, r), on_pole(dir, top, r), r, kind, col, 4)


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
	# its cable out of the underside to the pole, and clipped flat down the
	# edge beside the plates into the ground
	var drop := 5.45
	k.rod(c + Vector3(-0.18, -0.425, -0.08), on_pole(CABLE, drop, CABLE_R), CABLE_R, "plain_dark", SHEATH, 4)
	_down(k, CABLE, drop, CABLE_R, "plain_dark", SHEATH)
	if rng.randf() < 0.5:
		k.plate(Vector3(0.008, 0.1, 0.16), c + Vector3(0.28, 0.0, 0), "paint", Color(0.85, 0.7, 0.1))
