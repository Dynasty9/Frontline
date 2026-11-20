class_name BuildingFarm
extends RefCounted
## What stands about a farm: its bales. In a kit standing on the ground
## (y = 0), x along a row of them.

const STRAW := Color(0.76, 0.64, 0.38)
## Silage wrap: black, a dark green, now and then white.
const WRAP := [Color(0.07, 0.07, 0.07), Color(0.12, 0.2, 0.13), Color(0.8, 0.8, 0.76)]
const RADIUS := 0.65
const LENGTH := 1.2


## `count` round bales (1 to 3) lying in a row along x, a third on the two
## below where there are three: straw bales settled a little flat on their
## bellies, their ends showing the spiral of the roll and their twine round
## them, the straw weathered grey on top; or (`wrapped`) silage bales sealed
## in plastic, their ends puckered where the film was drawn tight.
static func bales(k: BuildingKit, count: int, wrapped: bool, rng: RandomNumberGenerator) -> void:
	var pick := rng.randf()
	var wrap: Color = WRAP[0 if pick < 0.55 else (1 if pick < 0.88 else 2)]
	var at: Array[Vector3] = []
	var n := clampi(count, 1, 3)
	for i in mini(n, 2):
		at.append(Vector3((i - (mini(n, 2) - 1) * 0.5) * 1.35 + rng.randf_range(-0.06, 0.06), RADIUS * 0.935, rng.randf_range(-0.08, 0.08)))
	if n >= 3:
		at.append(Vector3(rng.randf_range(-0.1, 0.1), RADIUS * 0.94 + RADIUS * 1.75, rng.randf_range(-0.05, 0.05)))
	for p in at:
		var tilt := Basis(Vector3.UP, rng.randf_range(-0.12, 0.12))
		if wrapped:
			_silage(k.at_point(p, tilt.get_euler()), wrap, rng)
		else:
			_straw(k.at_point(p, tilt.get_euler()), rng)


## A round bale of straw about its axis (x), settled a little flat: the
## straw wound round it, a net over it, its ends the spiral of the roll.
static func _straw(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var col := STRAW.lerp(Color(0.6, 0.55, 0.42), rng.randf_range(0.0, 0.35))
	var lie := Basis(Vector3.BACK, PI * 0.5)
	# (flattened in its height: the cylinder's own x is the height once it lies)
	var squash := Basis.from_scale(Vector3(0.94, 1.0, 1.0))
	k.part(Res.cyl(RADIUS, RADIUS, LENGTH, 20), "straw", Transform3D(lie * squash, Vector3.ZERO), col)
	# the net wrap, faint pale bands round it
	for i in 3:
		var x := -LENGTH * 0.33 + i * LENGTH * 0.33
		k.part(Res.cyl(RADIUS * 1.006, RADIUS * 1.006, 0.02, 20), "plain", Transform3D(lie * squash, Vector3(x, 0, 0)), col.lightened(0.18), false)
	for sx: float in [-1.0, 1.0]:
		# (the end's own frame: its face out along +y)
		var end := Transform3D(Basis(Vector3.BACK, -sx * PI * 0.5) * squash, Vector3(sx * LENGTH * 0.5, 0, 0))
		k.part(Res.cyl(RADIUS * 0.985, RADIUS * 0.985, 0.012, 20), "straw", end * Transform3D(Basis.IDENTITY, Vector3(0, 0.004, 0)), col.darkened(0.1), false)
		for r in 5:
			var rr := RADIUS * (0.2 + r * 0.16)
			k.part(BuildingKit.ring(rr - 0.01, rr + 0.01), "plain", end * Transform3D(Basis.IDENTITY, Vector3(0, 0.012, 0)), col.darkened(0.32), false)
		k.part(Res.cyl(RADIUS * 0.12, RADIUS * 0.12, 0.01, 10), "plain", end * Transform3D(Basis.IDENTITY, Vector3(0, 0.014, 0)), col.darkened(0.5), false)


## A silage bale sealed in film about its axis (x): its body smooth and a
## little shiny, its ends puckered with folds of film round a darker middle.
static func _silage(k: BuildingKit, wrap: Color, rng: RandomNumberGenerator) -> void:
	var lie := Basis(Vector3.BACK, PI * 0.5)
	var squash := Basis.from_scale(Vector3(0.93, 1.0, 1.0))
	k.part(Res.cyl(RADIUS, RADIUS, LENGTH, 20), "film", Transform3D(lie * squash, Vector3.ZERO), wrap)
	for i in 3:
		var x := -LENGTH * 0.3 + i * LENGTH * 0.3
		k.part(Res.cyl(RADIUS * 1.006, RADIUS * 1.006, 0.05, 20), "film", Transform3D(lie * squash, Vector3(x, 0, 0)), wrap.lightened(0.05), false)
	for sx: float in [-1.0, 1.0]:
		var end := Transform3D(Basis(Vector3.BACK, -sx * PI * 0.5) * squash, Vector3(sx * LENGTH * 0.5, 0, 0))
		k.part(Res.cyl(RADIUS * 0.9, RADIUS * 0.97, 0.04, 20), "film", end * Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), wrap.darkened(0.12), false)
		# (folds where the film was drawn tight over the corner, short and soft)
		for f in 11:
			var a := TAU * f / 11.0 + rng.randf_range(-0.15, 0.15)
			var long := RADIUS * rng.randf_range(0.25, 0.45)
			k.part(Res.box(Vector3(0.05, 0.008, long)), "film", end * Transform3D(Basis(Vector3.UP, a), Vector3(0, 0.041, 0)) * Transform3D(Basis.IDENTITY, Vector3(0, 0, RADIUS * 0.92 - long * 0.5)), wrap.lightened(0.03), false)
		k.part(Res.cyl(RADIUS * 0.2, RADIUS * 0.2, 0.03, 12), "film", end * Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), wrap.darkened(0.25), false)
