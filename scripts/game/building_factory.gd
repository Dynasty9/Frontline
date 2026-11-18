class_name BuildingFactory
extends RefCounted

## The vehicle works' shed, dressed as a real one: a brick dado to knee
## height under the sheeting (a lorry's bumper won't hole it), corner
## flashings, a band of glazing high along the sides and back to light the
## shop floor, gutters along the side eaves and downpipes at the corners,
## steel bollards guarding the shutter's jambs, a personnel door with its
## canopy beside it, gas bottles chained to the back wall and drums by the
## side. The shed itself is the structure's part (`size` across).

const BRICK := Color(0.5, 0.27, 0.19)
const DADO := 1.25  # how high the brick goes
const EAVES := 5.0
const DOOR := Rect2(-2.3, 0.0, 4.6, 4.45)  # the shutter's opening in the front face
const HAZARD := Color(0.78, 0.6, 0.1)
const BOTTLES := [Color(0.1, 0.1, 0.1), Color(0.42, 0.12, 0.1), Color(0.1, 0.1, 0.1), Color(0.24, 0.35, 0.5)]  # oxygen, acetylene, oxygen, argon


## The four faces, `k` at the shed's middle on the ground: front (the
## shutter, -z), back, then the two sides (-x, +x).
static func walls(k: BuildingKit, size: Vector3, shed: Color, rng: RandomNumberGenerator) -> void:
	for face in 4:
		var out: Vector3 = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)][face]
		var flen := size.x if face < 2 else size.z
		var fk := k.on_face(out * Vector3(size.x * 0.5, 0, size.z * 0.5), out)
		var gaps: Array = []
		var band := Vector2(flen * 0.7, 0.75)
		if face == 0:
			gaps.append(DOOR)
			gaps.append(Rect2(3.6 - 0.55, 0.0, 1.1, 2.2))
		else:
			gaps.append(Rect2(-band.x * 0.5, 3.95 - band.y * 0.5, band.x, band.y))
		BuildingWalls.face(fk, flen, EAVES, "corrugated", shed, gaps)
		_dado(fk, flen, gaps)
		for sx: float in [-1.0, 1.0]:
			# (the flashing over the corner, on this face's side of it)
			fk.plate(Vector3(0.14, EAVES - DADO - 0.05, 0.025), Vector3(sx * (flen * 0.5 - 0.07), (EAVES + DADO) * 0.5, 0.0125), "steel", BuildingMaterials.trim_color("corrugated", shed))
		if face == 0:
			BuildingOpenings.roller_door(fk, Vector3(0, 0, 0.035), Vector2(4.4, 3.9), Color(0.55, 0.5, 0.36))
			for sx: float in [-1.0, 1.0]:
				_bollard(fk, Vector3(sx * 2.6, 0, 0.4))
			BuildingOpenings.doorway(fk, Vector3(3.6, 0, 0.08), Vector2(1.0, 2.1), {"material": "brick", "wall": BRICK, "inset": -0.05,
				"frame_kind": "metal_dark", "frame": Color(0.25, 0.26, 0.26), "hood": true,
				"hood_covering": "roof_sheet", "hood_col": shed})
			BuildingOpenings.leaf(fk.at_point(Vector3(3.6 - 0.48, 0, 0.1)), Vector2(0.96, 2.04), "steel", Color(0.22, 0.3, 0.36), 1.0)
		else:
			BuildingOpenings.ribbon(fk, Vector3(0, 3.95, 0.05), band, maxi(3, int(band.x / 1.05)), Color(0.3, 0.32, 0.31), "metal_dark", rng.randf() < 0.7)
		if face == 1:
			_bottles(fk, Vector3(-flen * 0.25, 0, 0.08), rng)
		if face == 2:
			for i in 3:
				BuildingFittings.drum(fk, Vector3(1.2 + i * 0.62, 0, 0.42), BuildingFittings.DRUMS[(i + rng.randi()) % BuildingFittings.DRUMS.size()], false, i * 0.9)
	# rain off the roof slab: gutters along the side eaves, a downpipe at
	# each corner
	for sx: float in [-1.0, 1.0]:
		var x := sx * (size.x * 0.5 + 0.12)
		BuildingFittings.gutter(k, Vector3(x, EAVES - 0.05, -size.z * 0.5), Vector3(x, EAVES - 0.05, size.z * 0.5), Vector3(sx, 0, 0))
		for sz: float in [-1.0, 1.0]:
			BuildingFittings.downpipe(k, Vector3(x, EAVES - 0.1, sz * (size.z * 0.5 - 0.3)), Vector3(x, 0.15, sz * (size.z * 0.5 - 0.3)))


## The brick dado along a face's foot, round its openings, with a
## concrete coping over it to shed the rain off the sheeting.
static func _dado(k: BuildingKit, length: float, gaps: Array) -> void:
	for run: Vector2 in BuildingWalls.runs(-length * 0.5, length * 0.5, 0.0, DADO, gaps):
		var w := run.y - run.x
		if w < 0.05:
			continue
		var x := (run.x + run.y) * 0.5
		k.box(Vector3(w, DADO, 0.09), Vector3(x, DADO * 0.5, 0.045), "brick", BRICK)
		k.box(Vector3(w + 0.02, 0.07, 0.14), Vector3(x, DADO + 0.035, 0.06), "concrete", Color(0.55, 0.54, 0.51))


## A steel bollard guarding a jamb: a tube on the ground, filled, its foot
## at `p`, painted in hazard yellow with black bands.
static func _bollard(k: BuildingKit, p: Vector3) -> void:
	k.cyl(0.085, 0.085, 1.0, p + Vector3(0, 0.5, 0), "paint", HAZARD)
	for y: float in [0.3, 0.62]:
		k.cyl(0.088, 0.088, 0.12, p + Vector3(0, y, 0), "paint", Color(0.08, 0.08, 0.08))
	k.cyl(0.07, 0.088, 0.06, p + Vector3(0, 1.03, 0), "paint", HAZARD)


## Gas bottles for the welders, chained in a row to the wall, `p` at the
## row's middle on the ground.
static func _bottles(k: BuildingKit, p: Vector3, rng: RandomNumberGenerator) -> void:
	for i in 4:
		var c := p + Vector3((i - 1.5) * 0.3, 0, 0.13)
		var col: Color = BOTTLES[(i + rng.randi()) % BOTTLES.size()]
		k.cyl(0.115, 0.115, 1.25, c + Vector3(0, 0.625, 0), "car_paint", col)
		k.cyl(0.05, 0.115, 0.16, c + Vector3(0, 1.33, 0), "car_paint", col)
		k.cyl(0.04, 0.045, 0.08, c + Vector3(0, 1.45, 0), "steel", Color(0.6, 0.55, 0.35))  # (the valve, brass)
	# the chain across them at waist height, between two eyes in the wall
	k.box(Vector3(1.4, 0.02, 0.02), p + Vector3(0, 0.95, 0.25), "steel", Color(0.3, 0.3, 0.29))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.03, 0.03, 0.25), p + Vector3(sx * 0.7, 0.95, 0.125), "steel", Color(0.3, 0.3, 0.29))
