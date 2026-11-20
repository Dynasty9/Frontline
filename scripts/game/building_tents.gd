class_name BuildingTents
extends RefCounted
## Tents: the field hospital a side puts up behind its lines (Structure
## "medic_tent"). In a kit standing on the ground (y = 0), x along the tent.

const RED := Color(0.72, 0.07, 0.06)
const WHITE := Color(0.9, 0.9, 0.87)


## A field hospital `size` (x long, z wide): a frame tent of canvas walls 1.8 m
## high under a pitched roof, its arches showing through as seams every bay,
## clear windows down both sides with their blinds rolled up, the door at the
## -x end open with its flap rolled over it and boards for a step; a red cross
## on white on both slopes of the roof and over the door; guy ropes out to
## pegs; outside the door stretchers on trestles, crates of medical stores and
## oxygen cylinders, a flag with the cross on a pole. A regular army's (`team`
## 0) canvas is olive drab and new; a militia's an old tent, faded and patched.
static func field_hospital(k: BuildingKit, size: Vector3, team: int, rng: RandomNumberGenerator) -> void:
	var L := size.x
	var W := size.z
	var eave := 1.8
	var ridge := 2.85
	var canvas := Color(0.4, 0.41, 0.31) if team != 1 else Color(0.6, 0.53, 0.38)
	var seam := canvas.darkened(0.22)
	var hz := W * 0.5
	var hx := L * 0.5
	# the floor, a groundsheet a little proud of the walls
	k.box(Vector3(L + 0.3, 0.04, W + 0.3), Vector3(0, 0.02, 0), "canvas", Color(0.28, 0.27, 0.23), Vector3.ZERO, false)
	# the long walls, with windows; the end walls, with the door at -x
	var bays := maxi(2, roundi(L / 1.75))
	var bay := L / bays
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(L, eave, 0.04), Vector3(0, eave * 0.5, sz * hz), "canvas", canvas)
		for i in bays:
			var x := -hx + (i + 0.5) * bay
			if i == 0 or i == bays - 1:
				continue
			# a clear window, its blind rolled up over it
			k.box(Vector3(bay * 0.55, 0.5, 0.01), Vector3(x, 1.2, sz * (hz + 0.025)), "glass", Color(0.32, 0.36, 0.36), Vector3.ZERO, false)
			k.box(Vector3(bay * 0.6, 0.06, 0.02), Vector3(x, 0.93, sz * (hz + 0.03)), "canvas", seam, Vector3.ZERO, false)
			k.cyl(0.05, 0.05, bay * 0.6, Vector3(x, 1.52, sz * (hz + 0.06)), "canvas", canvas.lightened(0.05), Vector3(0, 0, PI * 0.5), 8, false)
		# the frame's legs and the seams over them, down the walls and up the roof
		for i in bays + 1:
			var x := -hx + i * bay
			k.box(Vector3(0.05, eave, 0.02), Vector3(x, eave * 0.5, sz * (hz + 0.02)), "canvas", seam, Vector3.ZERO, false)
	var slope := Vector2(hz, ridge - eave).length()
	var ang := atan2(ridge - eave, hz)
	for sz: float in [-1.0, 1.0]:
		var mid := Vector3(0, (eave + ridge) * 0.5, sz * hz * 0.5)
		k.box(Vector3(L + 0.3, 0.04, slope + 0.1), mid, "canvas", canvas.lightened(0.04), Vector3(sz * ang, 0, 0))
		for i in bays + 1:
			var x := -hx + i * bay
			k.box(Vector3(0.06, 0.02, slope + 0.1), mid + Vector3(x, 0.025, 0), "canvas", seam, Vector3(sz * ang, 0, 0), false)
		# the cross on white, on this slope
		var n := Vector3(0, hz, sz * (ridge - eave)).normalized()
		var at := mid + n * 0.03
		k.box(Vector3(1.9, 0.01, 1.9), at, "canvas", WHITE, Vector3(sz * ang, 0, 0), false)
		k.box(Vector3(1.4, 0.012, 0.42), at + n * 0.01, "canvas", RED, Vector3(sz * ang, 0, 0), false)
		k.box(Vector3(0.42, 0.012, 1.4), at + n * 0.01, "canvas", RED, Vector3(sz * ang, 0, 0), false)
	k.rod(Vector3(-hx - 0.15, ridge + 0.02, 0), Vector3(hx + 0.15, ridge + 0.02, 0), 0.04, "canvas", seam, 6, false)
	# the end walls, gabled to the ridge
	for sx: float in [-1.0, 1.0]:
		var end := k.at_point(Vector3(sx * hx, 0, 0), Vector3(0, sx * PI * 0.5, 0))
		end.box(Vector3(W, eave, 0.04), Vector3(0, eave * 0.5, 0), "canvas", canvas.darkened(0.03))
		end.prism(Vector3(W, ridge - eave, 0.04), Vector3(0, eave + (ridge - eave) * 0.5, 0), "canvas", canvas.darkened(0.03))
		if sx < 0.0:
			# the door: the dark inside through it, the flap rolled up over it, step boards
			end.box(Vector3(1.4, 1.95, 0.02), Vector3(0, 0.975, 0.03), "plain_dark", Color(0.05, 0.05, 0.045), Vector3.ZERO, false)
			end.cyl(0.08, 0.08, 1.5, Vector3(0, 2.0, 0.08), "canvas", canvas, Vector3(0, 0, PI * 0.5), 8, false)
			end.box(Vector3(1.6, 0.04, 0.9), Vector3(0, 0.05, 0.5), "wood", Color(0.5, 0.4, 0.27))
			# the cross over the door
			end.box(Vector3(0.7, 0.7, 0.01), Vector3(0, 2.28, 0.03), "canvas", WHITE, Vector3.ZERO, false)
			end.box(Vector3(0.52, 0.16, 0.012), Vector3(0, 2.28, 0.04), "canvas", RED, Vector3.ZERO, false)
			end.box(Vector3(0.16, 0.52, 0.012), Vector3(0, 2.28, 0.04), "canvas", RED, Vector3.ZERO, false)
	# patches on an old tent
	if team == 1:
		for i in rng.randi_range(3, 5):
			var sz := -1.0 if rng.randf() < 0.5 else 1.0
			k.box(Vector3(rng.randf_range(0.4, 0.9), rng.randf_range(0.3, 0.6), 0.01), Vector3(rng.randf_range(-hx + 0.5, hx - 0.5), rng.randf_range(0.4, 1.4), sz * (hz + 0.025)), "canvas", canvas.darkened(rng.randf_range(0.1, 0.25)), Vector3(0, 0, rng.randf_range(-0.2, 0.2)), false)
	# guy ropes from the eaves out to pegs
	for sz: float in [-1.0, 1.0]:
		for i in bays + 1:
			var x := -hx + i * bay
			BuildingWire.guy(k, Vector3(x, eave, sz * hz), Vector3(x, 0.0, sz * (hz + 1.2)), true, "peg")
	# outside the door: stretchers, the stores, oxygen, the flag
	for i in 2:
		stretcher(k.at_point(Vector3(-hx - 1.7, 0, -1.1 + i * 1.5), Vector3(0, PI * 0.5 + rng.randf_range(-0.12, 0.12), 0)), canvas)
	for i in 3:
		medical_crate(k.at_point(Vector3(-hx - 0.6, 0.0 if i < 2 else 0.42, hz + 0.4 - (i % 2) * 0.62), Vector3(0, rng.randf_range(-0.1, 0.1), 0)))
	for i in 3:
		var p := Vector3(hx + 0.4, 0, -hz + 0.5 + i * 0.28)
		k.cyl(0.11, 0.11, 1.3, p + Vector3(0, 0.65, 0), "car_paint", Color(0.85, 0.86, 0.84) if team != 1 else Color(0.24, 0.42, 0.3), Vector3(0.06, 0, 0), 10)
		k.cyl(0.04, 0.06, 0.12, p + Vector3(0.04, 1.36, 0), "metal_dark", Color(0.3, 0.3, 0.3), Vector3.ZERO, 6, false)
	var pole := BuildingFittings.flagpole(k, Vector3(hx + 0.8, 0, hz + 0.5), 4.2, Color(0.7, 0.7, 0.68), false)
	k.box(Vector3(1.0, 0.65, 0.03), pole + Vector3(0.52, -0.33, 0), "fabric", WHITE, Vector3.ZERO, false)
	k.box(Vector3(0.6, 0.16, 0.035), pole + Vector3(0.52, -0.33, 0), "fabric", RED, Vector3.ZERO, false)
	k.box(Vector3(0.16, 0.5, 0.035), pole + Vector3(0.52, -0.33, 0), "fabric", RED, Vector3.ZERO, false)


## A stretcher on its trestles (along x): two poles, the canvas slung between
## them, the handles out past the ends, the folded legs.
static func stretcher(k: BuildingKit, canvas: Color) -> void:
	for sx: float in [-0.75, 0.75]:
		k.bar(Vector3(sx, 0, -0.22), Vector3(sx, 0.55, 0.0), 0.04, 0.04, "wood", Color(0.45, 0.35, 0.22), false)
		k.bar(Vector3(sx, 0, 0.22), Vector3(sx, 0.55, 0.0), 0.04, 0.04, "wood", Color(0.45, 0.35, 0.22), false)
	for sz: float in [-0.27, 0.27]:
		k.rod(Vector3(-1.15, 0.62, sz), Vector3(1.15, 0.62, sz), 0.022, "wood", Color(0.5, 0.4, 0.26), 6, false)
	k.box(Vector3(1.85, 0.02, 0.52), Vector3(0, 0.6, 0), "canvas", canvas.darkened(0.1))
	k.box(Vector3(0.5, 0.06, 0.4), Vector3(0.65, 0.65, 0), "canvas", Color(0.6, 0.55, 0.45), Vector3.ZERO, false)


## A crate of medical stores: white, the red cross on its lid and side.
static func medical_crate(k: BuildingKit) -> void:
	k.box(Vector3(0.7, 0.42, 0.5), Vector3(0, 0.21, 0), "paint", Color(0.86, 0.86, 0.82))
	k.box(Vector3(0.72, 0.04, 0.52), Vector3(0, 0.42, 0), "paint", Color(0.78, 0.78, 0.75))
	for p: Array in [[Vector3(0, 0.445, 0), Vector3.ZERO], [Vector3(0, 0.22, -0.255), Vector3(PI * 0.5, 0, 0)]]:
		k.box(Vector3(0.3, 0.005, 0.09), p[0], "paint", RED, p[1], false)
		k.box(Vector3(0.09, 0.005, 0.3), p[0], "paint", RED, p[1], false)
