class_name BuildingDepot
extends RefCounted
## A side's headquarters (Structure "depot") and what it's made of: ISO
## shipping containers, a precast command post sandbagged on its roof, the
## generators that run it, the work yard under a camouflage net, the wall
## along its front and the entry control point at its gate. In a kit standing
## on the ground (y = 0).
##
## Which way it faces comes from where the battle puts it: twelve metres in
## from its own edge of the map, the enemy ahead (-z), its back to the edge
## (+z) and the road up from the rear running past its +x side. So it turns
## a wall and the command post's slits to the enemy, and its gate, vehicle
## park, the command post's door and the flag to the rear and the road, where
## the traffic comes from, and where its own commander's view first looks at
## it from.

## A 20-foot container's length, width and height (an ISO 1C box).
const CONTAINER := Vector3(6.06, 2.59, 2.44)
## Containers as a regular army has them: olive, tan, grey; and as a militia
## gets them, off the docks: rust, faded blue, teal, a white gone grey.
const ARMY := [Color(0.3, 0.33, 0.22), Color(0.5, 0.45, 0.33), Color(0.38, 0.4, 0.36)]
const COMMERCIAL := [Color(0.55, 0.28, 0.18), Color(0.22, 0.33, 0.48), Color(0.2, 0.38, 0.36), Color(0.66, 0.66, 0.62)]
const STEEL := Color(0.25, 0.26, 0.27)
const OLIVE := Color(0.3, 0.33, 0.22)
const SACKING := Color(0.55, 0.49, 0.35)
## A HESCO cell (MIL 1): 1.1 m along the wall with its joint, 1.37 m high,
## 1.06 m through.
const CELL := Vector3(1.1, 1.37, 1.06)
## The front wall's line, and the gate's: the wall stands just out from the
## compound's front edge, the gate across the lane in from the road.
const FRONT_Z := -6.15
const GATE_X := 9.35
## The yard's camouflage net spans this (x0, z0, x1, z1), from the front wall
## back to the command post, over the inner ends of both containers.
const NET := Rect2(-4.6, -6.45, 9.2, 7.75)
## The spreaders that hold the net up off the yard (x, z).
const SPREADERS := [Vector2(-1.7, -3.5), Vector2(1.7, -3.5), Vector2(0.0, -0.2)]


## A 20-foot container lying along x, `col` its paint: corrugated walls and
## roof between the frame's corner posts and rails, a casting at each corner,
## forklift pockets low in its sides; at its +x end the doors with their four
## locking bars, handles and the plate of its number. `office` cuts a window
## in its -z side, with a shutter, an air conditioner beside it and a cable
## run up to the roof, for a container fitted out as a signals office.
static func container(k: BuildingKit, col: Color, rng: RandomNumberGenerator, office := false) -> void:
	var L := CONTAINER.x
	var H := CONTAINER.y
	var W := CONTAINER.z
	var frame := col.darkened(0.18)
	# the box: its sides corrugated (the ribs run up them), the roof too
	k.box(Vector3(L - 0.2, H - 0.22, W - 0.06), Vector3(0, H * 0.5, 0), "corrugated", col)
	k.box(Vector3(L - 0.16, 0.05, W - 0.1), Vector3(0, H - 0.07, 0), "car_paint", col.darkened(0.08))
	# the frame: corner posts, top and bottom rails, the castings
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.14, H - 0.2, 0.14), Vector3(sx * (L * 0.5 - 0.07), H * 0.5, sz * (W * 0.5 - 0.07)), "steel", frame)
			for y: float in [0.06, H - 0.06]:
				k.box(Vector3(0.18, 0.12, 0.17), Vector3(sx * (L * 0.5 - 0.09), y, sz * (W * 0.5 - 0.085)), "metal_dark", frame.darkened(0.25), Vector3.ZERO, false)
		k.box(Vector3(0.12, 0.14, W - 0.3), Vector3(sx * (L * 0.5 - 0.06), H - 0.07, 0), "steel", frame)
		k.box(Vector3(0.12, 0.16, W - 0.3), Vector3(sx * (L * 0.5 - 0.06), 0.08, 0), "steel", frame)
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(L - 0.3, 0.12, 0.1), Vector3(0, H - 0.06, sz * (W * 0.5 - 0.05)), "steel", frame)
		k.box(Vector3(L - 0.3, 0.16, 0.12), Vector3(0, 0.08, sz * (W * 0.5 - 0.06)), "steel", frame)
		# the forklift pockets
		for px: float in [-1.0, 1.0]:
			k.plate(Vector3(0.36, 0.1, 0.01), Vector3(px * 1.0, 0.08, sz * (W * 0.5 - 0.0)), "plain_dark", Color(0.06, 0.06, 0.06))
	# the doors at +x: two leaves, four locking bars down them on their cams
	var door := k.at_point(Vector3(L * 0.5 - 0.1, 0, 0), Vector3(0, PI * 0.5, 0))
	for sd: float in [-1.0, 1.0]:
		door.box(Vector3(W * 0.5 - 0.18, H - 0.34, 0.04), Vector3(sd * (W * 0.25 - 0.02), H * 0.5, 0.02), "corrugated", col.lightened(0.03))
		for b: float in [0.3, 0.75]:
			var bx := sd * (W * 0.25 - 0.02) + sd * (b - 0.5) * (W * 0.5 - 0.3)
			door.rod(Vector3(bx, 0.22, 0.07), Vector3(bx, H - 0.22, 0.07), 0.018, "steel", frame.lightened(0.1), 6, false)
			door.box(Vector3(0.05, 0.1, 0.05), Vector3(bx, 0.3, 0.08), "steel", frame, Vector3.ZERO, false)
			door.box(Vector3(0.05, 0.1, 0.05), Vector3(bx, H - 0.3, 0.08), "steel", frame, Vector3.ZERO, false)
			door.box(Vector3(0.18, 0.03, 0.03), Vector3(bx + sd * 0.08, 1.15, 0.1), "steel", frame.lightened(0.15), Vector3(0, 0, sd * 0.2), false)
	door.plate(Vector3(0.36, 0.14, 0.01), Vector3(-0.42, H - 0.42, 0.045), "paint", Color(0.86, 0.85, 0.8))
	# its number stencilled high on a side
	k.plate(Vector3(1.1, 0.16, 0.01), Vector3(L * 0.5 - 1.0, H - 0.42, -(W * 0.5 + 0.0)), "paint", Color(0.88, 0.87, 0.82).lerp(col, 0.25))
	if not office:
		return
	# a signals office: a window with its shutter half down, the air
	# conditioner beside it, a cable run up the side to the aerials on the roof
	var side := k.at_point(Vector3(-0.6, 0, -W * 0.5), Vector3(0, PI, 0))
	side.box(Vector3(1.2, 0.9, 0.06), Vector3(0, 1.55, 0.0), "plain_dark", Color(0.08, 0.09, 0.1))
	side.box(Vector3(1.1, 0.8, 0.02), Vector3(0, 1.55, 0.02), "glass", Color(0.25, 0.3, 0.32), Vector3.ZERO, false)
	side.box(Vector3(1.32, 0.08, 0.1), Vector3(0, 2.03, 0.03), "steel", frame)
	side.box(Vector3(1.32, 0.06, 0.12), Vector3(0, 1.07, 0.04), "steel", frame)
	side.box(Vector3(1.24, 0.34, 0.03), Vector3(0, 1.84, 0.06), "corrugated", col.darkened(0.08))
	BuildingFittings.ac_unit(k, Vector3(1.7, 0.0, -W * 0.5 - 0.35), PI, Color(0.7, 0.7, 0.67))
	k.box(Vector3(0.12, H - 0.3, 0.06), Vector3(-1.7, H * 0.5, -W * 0.5 - 0.04), "metal_dark", Color(0.18, 0.18, 0.18))
	BuildingFittings.whip(k, Vector3(-2.2, H, -0.6), 3.2)
	BuildingFittings.whip(k, Vector3(-1.4, H, 0.7), 2.6, Vector3(-0.04, 0, 0.05))
	k.cyl(0.05, 0.05, 0.4, Vector3(-2.6, H + 0.2, 0.6), "metal_dark", STEEL, Vector3.ZERO, 6)
	# its steps up to the door
	k.box(Vector3(0.6, 0.2, 1.0), Vector3(L * 0.5 + 0.35, 0.1, 0), "steel", STEEL.lightened(0.05))


## A command post of precast concrete `size` (x by y by z): a lip of slab
## over it, two courses of sandbags round the roof's edge, vision slits with
## steel shutters, a guyed mast and a satellite dish on the roof. Its door is
## in its +z face, away from the battle, behind a sandbagged blast wall open
## to one side, a board in the side's colour (`sign_col`) beside it and a
## floodlight over it; the -z face, towards the enemy, has only its slits.
static func command_post(k: BuildingKit, size: Vector3, rng: RandomNumberGenerator, sign_col := Color(0.3, 0.4, 0.6)) -> void:
	var wc := Color(0.5, 0.5, 0.47)
	k.box(size, Vector3(0, size.y * 0.5, 0), "precast", wc)
	for face in 4:
		var out: Vector3 = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)][face]
		var flen := size.x if face < 2 else size.z
		var fk := k.on_face(out * Vector3(size.x * 0.5, 0, size.z * 0.5), out)
		var door := face == 1
		var gaps: Array = [Rect2(-0.6, 0.0, 1.2, 2.1)] if door else []
		# a slit in each face (two in the long one towards the enemy, one
		# beside the door), its shutter on top
		var slits: Array = [0.0]
		if face == 0:
			slits = [-flen * 0.25, flen * 0.25]
		elif door:
			slits = [flen * 0.3]
		for sx: float in slits:
			gaps.append(Rect2(sx - 0.45, 1.5, 0.9, 0.2))
		BuildingWalls.face(fk, flen, size.y, "precast", wc, gaps, {"plinth": 0.25})
		BuildingWalls.joints(fk, flen, size.y, 1.2, wc, gaps)
		for sx: float in slits:
			fk.box(Vector3(0.9, 0.2, 0.1), Vector3(sx, 1.6, -0.04), "plain_dark", Color(0.04, 0.04, 0.04), Vector3.ZERO, false)
			fk.box(Vector3(1.0, 0.24, 0.03), Vector3(sx, 1.84, 0.06), "steel", STEEL, Vector3(-0.5, 0, 0), false)
		if door:
			BuildingOpenings.doorway(fk, Vector3(0, 0, 0), Vector2(1.1, 2.05), {"material": "precast", "wall": wc, "inset": -0.05,
				"frame_kind": "metal_dark", "frame": Color(0.22, 0.23, 0.23), "step": false})
			BuildingOpenings.leaf(fk.at_point(Vector3(-0.53, 0, 0.03)), Vector2(1.06, 2.0), "steel", Color(0.24, 0.27, 0.22), 1.0)
			# a blast wall of sandbags before the door, open towards the
			# vehicle park and the gate
			sandbags(fk.at_point(Vector3(-0.3, 0, 1.25)), 2.0, 1.2, rng)
			sandbags(fk.at_point(Vector3(-1.38, 0, 0.75), Vector3(0, PI * 0.5, 0)), 0.9, 1.2, rng)
			# the board that says whose it is, and the light over the door
			fk.plate(Vector3(0.74, 0.46, 0.03), Vector3(1.5, 1.0, 0.03), "paint", sign_col, Vector3.ZERO, true)
			fk.plate(Vector3(0.62, 0.1, 0.01), Vector3(1.5, 1.04, 0.05), "paint", Color(0.92, 0.91, 0.86))
			floodlight(fk.at_point(Vector3(0, 2.45, 0.05)), 0.5)
	# the slab, a lip over the walls, and sandbags round its edge
	k.box(Vector3(size.x + 0.3, 0.25, size.z + 0.3), Vector3(0, size.y + 0.125, 0), "concrete", Color(0.46, 0.46, 0.43))
	var roof := size.y + 0.25
	for sd: float in [-1.0, 1.0]:
		sandbags(k.at_point(Vector3(0, roof, sd * (size.z * 0.5 - 0.05)), Vector3(0, 0.0 if sd < 0.0 else PI, 0)), size.x + 0.1, 0.42, rng)
		sandbags(k.at_point(Vector3(sd * (size.x * 0.5 - 0.05), roof, 0), Vector3(0, sd * PI * 0.5, 0)), size.z - 0.7, 0.42, rng)
	BuildingFittings.mast(k, Vector3(size.x * 0.25, roof, size.z * 0.15), 6.0, 3, 0.5, STEEL, 0.2, roof, [0.6])
	BuildingFittings.whip(k, Vector3(-size.x * 0.3, roof, -size.z * 0.2), 2.8)
	# the satellite terminal, its dish weighted down with sandbags against the wind
	BuildingFittings.dish(k, Vector3(-size.x * 0.22, roof, size.z * 0.2), 0.55, Vector3(-0.75, PI * 0.8, 0), Color(0.62, 0.63, 0.58), 0.55)
	for sx: float in [-0.42, 0.42]:
		sandbags(k.at_point(Vector3(-size.x * 0.22 + sx, roof, size.z * 0.2), Vector3(0, PI * 0.5, 0)), 0.55, 0.14, rng)


static var _bag: ArrayMesh


## A wall of sandbags `length` along x and `h` high, laid in courses as men lay
## them: each course's bags (Structure's filled-sack mesh) broken over the
## joints of the one under, the top course a little narrower, every bag its
## own lean and shade of hessian.
static func sandbags(k: BuildingKit, length: float, h: float, rng: RandomNumberGenerator) -> void:
	if _bag == null:
		_bag = Structure._pillow()
	var courses := maxi(1, roundi(h / 0.14))
	var ch := h / courses
	for c in courses:
		var n := maxi(1, roundi(length / 0.6))
		var bl := length / n
		var shift := 0.5 * bl if c % 2 == 1 else 0.0
		var depth := 0.42 - 0.06 * float(c) / maxf(1.0, courses - 1)
		for i in n + (1 if c % 2 == 1 else 0):
			var x := -length * 0.5 + (i + 0.5) * bl - shift
			var w := bl * (0.5 if c % 2 == 1 and (i == 0 or i == n) else 1.0) - 0.03
			if c % 2 == 1 and i == 0:
				x += bl * 0.25
			elif c % 2 == 1 and i == n:
				x -= bl * 0.25
			var col := SACKING.darkened(rng.randf_range(0.0, 0.14))
			var turn := Basis.from_euler(Vector3(0, rng.randf_range(-0.06, 0.06) + (PI if rng.randf() < 0.5 else 0.0), rng.randf_range(-0.04, 0.04)))
			k.part(_bag, "canvas", Transform3D(turn * Basis.from_scale(Vector3(w * 1.04, ch * 1.15, depth)), Vector3(x, (c + 0.5) * ch, 0)), col, c == courses - 1)


## A run of sandbag wall `n` bags long (0.6 m each) and `courses` high, two
## bags thick, as one mesh (one of `v` layouts, cached): for the long walls,
## where every bag a part of its own would cost a part apiece for nothing
## anyone sees from a command post's height.
static func bag_run(n: int, courses: int, v := 0) -> ArrayMesh:
	if _bag == null:
		_bag = Structure._pillow()
	return BuildingKit.shape("hq_bags|%d|%d|%d" % [n, courses, v], func() -> Array:
		var r := RandomNumberGenerator.new()
		r.seed = 7717 + v * 131 + n * 7 + courses
		var out: Array = []
		var length := n * 0.6
		for c in courses:
			var shift := 0.3 if c % 2 == 1 else 0.0
			var depth := 0.42 - 0.05 * float(c) / maxf(1.0, courses - 1)
			for row: float in [-0.22, 0.22]:
				for i in n:
					var x := -length * 0.5 + (i + 0.5) * 0.6 + shift
					if x > length * 0.5:
						continue
					var turn := Basis.from_euler(Vector3(0, r.randf_range(-0.07, 0.07) + (PI if r.randf() < 0.5 else 0.0), r.randf_range(-0.04, 0.04)))
					out.append([_bag, Transform3D(turn * Basis.from_scale(Vector3(0.6, 0.16, depth)), Vector3(x, (c + 0.5) * 0.14, row * (1.0 - 0.15 * c / maxf(1.0, courses))))])
		return out)


## `n` HESCO cells in a row along x, centred, standing on y = 0: the cells
## (welded mesh lined with geotextile, filled till the sides bulge), the fill
## settled below the rims, and the wire (the top edges of the cages, the coil
## joints pinning each cell to the next). Three cached meshes, one per
## surface, for the whole run.
static func hesco(k: BuildingKit, n: int, tint: Color) -> void:
	var length := n * CELL.x
	k.part(BuildingKit.shape("hq_hesco|%d" % n, func() -> Array:
		var cell := WorksModels._bulge_box(Vector3(CELL.x - 0.03, CELL.y, CELL.z), 0.055, false)
		var out: Array = []
		for i in n:
			# (each cell sits a hair off line, as they're stood up one by one)
			var wob := 0.012 * sin(i * 2.3 + n)
			out.append([cell, Transform3D(Basis(Vector3.UP, 0.01 * sin(i * 1.7)), Vector3(-length * 0.5 + (i + 0.5) * CELL.x, 0, wob))])
		return out), "hesco_cell", Transform3D.IDENTITY, tint)
	k.part(BuildingKit.shape("hq_hesco_fill|%d" % n, func() -> Array:
		return [BuildingKit.piece(Vector3(length - 0.04, 0.06, CELL.z - 0.01), Vector3(0, CELL.y - 0.06, 0))]),
		"earth", Transform3D.IDENTITY, Color(0.3, 0.24, 0.16), false)
	k.part(BuildingKit.shape("hq_hesco_wire|%d" % n, func() -> Array:
		var out: Array = []
		for sz: float in [-CELL.z * 0.5, CELL.z * 0.5]:
			out.append([Res.cyl(0.009, 0.009, length - 0.04, 4), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, CELL.y + 0.005, sz))])
			for i in n + 1:
				out.append([Res.cyl(0.016, 0.016, CELL.y + 0.02, 5), Transform3D(Basis.IDENTITY, Vector3(-length * 0.5 + i * CELL.x, CELL.y * 0.5 + 0.01, sz))])
		return out), "wire", Transform3D.IDENTITY, Color(0.34, 0.34, 0.32), false)


## A concrete barrier (a Jersey barrier) `length` long along z: the sloped
## foot that turns a wheel, the steep upper face, the narrow top.
static func jersey(k: BuildingKit, length: float, col := Color(0.6, 0.59, 0.55)) -> void:
	var profile := PackedVector2Array([Vector2(-0.305, 0.0), Vector2(0.305, 0.0), Vector2(0.305, 0.075), Vector2(0.17, 0.33),
		Vector2(0.075, 0.81), Vector2(-0.075, 0.81), Vector2(-0.17, 0.33), Vector2(-0.305, 0.075)])
	k.part(BuildingKit.extrusion("jersey|%.2f" % length, profile, length), "concrete", Transform3D.IDENTITY, col)
	# the lifting slots through its foot
	for sz: float in [-length * 0.3, length * 0.3]:
		k.plate(Vector3(0.62, 0.08, 0.3), Vector3(0, 0.06, sz), "plain_dark", Color(0.08, 0.08, 0.08))


## A diesel generator on skids, in its olive canopy: louvres down its sides,
## the exhaust stack with its rain cap, the cable off it to a drum (`drum`).
static func generator(k: BuildingKit, col := OLIVE, drum := true) -> void:
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(2.0, 0.1, 0.1), Vector3(0, 0.05, sz * 0.45), "steel", STEEL)
	k.box(Vector3(1.9, 1.15, 1.0), Vector3(0, 0.7, 0), "paint", col)
	k.box(Vector3(1.95, 0.06, 1.05), Vector3(0, 1.3, 0), "paint", col.darkened(0.1))
	for sz: float in [-1.0, 1.0]:
		BuildingOpenings.louvre(k.at_point(Vector3(-0.4, 0, sz * 0.505), Vector3(0, 0.0 if sz > 0.0 else PI, 0)), Vector3(0, 0.75, 0), Vector2(0.8, 0.6), col.darkened(0.2), "paint")
		k.plate(Vector3(0.5, 0.3, 0.01), Vector3(0.5, 0.8, sz * 0.505), "plain_dark", Color(0.1, 0.1, 0.1))
	k.cyl(0.05, 0.05, 0.6, Vector3(0.65, 1.6, 0.3), "metal_dark", Color(0.12, 0.11, 0.1), Vector3.ZERO, 8)
	k.cyl(0.0, 0.1, 0.06, Vector3(0.65, 1.93, 0.3), "metal_dark", Color(0.12, 0.11, 0.1), Vector3.ZERO, 8, false)
	if drum:
		k.cyl(0.25, 0.25, 0.3, Vector3(-1.4, 0.25, 0.7), "rubber", Color(0.12, 0.12, 0.12), Vector3(PI * 0.5, 0, 0), 12)


## A barrier at a gate: a striped boom on its post, raised or down, a sign
## board by it.
static func boom(k: BuildingKit, length: float, up: bool, sign_col: Color) -> void:
	k.box(Vector3(0.3, 1.0, 0.3), Vector3(0, 0.5, 0), "paint", Color(0.85, 0.84, 0.8))
	k.box(Vector3(0.36, 0.2, 0.36), Vector3(0, 1.05, 0), "metal_dark", STEEL)
	var arm := Basis(Vector3.BACK, 1.3 if up else 0.0)
	var stripes := maxi(4, roundi(length / 0.5))
	for i in stripes:
		var x := 0.25 + (i + 0.5) * (length - 0.3) / stripes
		k.part(Res.box(Vector3((length - 0.3) / stripes, 0.09, 0.09)), "paint", Transform3D(arm, Vector3(0, 1.05, 0)) * Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)),
			Color(0.82, 0.12, 0.1) if i % 2 == 0 else Color(0.9, 0.9, 0.86), true)
	# the rest the arm comes down on, at the far side of the lane
	k.box(Vector3(0.12, 0.95, 0.12), Vector3(length, 0.475, 0), "paint", Color(0.85, 0.84, 0.8))
	k.box(Vector3(0.2, 0.06, 0.16), Vector3(length, 0.98, 0), "metal_dark", STEEL, Vector3.ZERO, false)
	k.box(Vector3(0.06, 1.5, 0.06), Vector3(-0.6, 0.75, 0.3), "steel", STEEL)
	k.box(Vector3(0.9, 0.55, 0.04), Vector3(-0.6, 1.55, 0.3), "paint", sign_col)
	k.box(Vector3(0.8, 0.12, 0.045), Vector3(-0.6, 1.6, 0.3), "paint", Color(0.92, 0.91, 0.86))


## A floodlight on its bracket, its face turned down by `tilt` towards +z of
## the kit: the housing, the lamp glass (lit after dark, as the windows are).
static func floodlight(k: BuildingKit, tilt := 0.6) -> void:
	k.box(Vector3(0.05, 0.05, 0.22), Vector3(0, 0, -0.1), "steel", STEEL, Vector3.ZERO, false)
	var f := k.at_point(Vector3(0, -0.02, 0.04), Vector3(tilt, 0, 0))
	f.box(Vector3(0.34, 0.26, 0.12), Vector3.ZERO, "metal_dark", Color(0.2, 0.21, 0.2), Vector3.ZERO, false)
	f.plate(Vector3(0.28, 0.2, 0.01), Vector3(0, 0, 0.065), "window_lit", Color(0.7, 0.7, 0.66))


## A trailer light tower, its drawbar along +x: the box body with its own
## generator on two wheels, outriggers down at the corners, the mast run up
## and the bar of four lamps at the top turned towards -x.
static func light_tower(k: BuildingKit, h := 6.2) -> void:
	var body := Color(0.86, 0.72, 0.18)
	k.box(Vector3(1.9, 0.95, 1.05), Vector3(0, 0.95, 0), "paint", body)
	k.box(Vector3(1.95, 0.05, 1.1), Vector3(0, 1.45, 0), "paint", body.darkened(0.12))
	BuildingOpenings.louvre(k.at_point(Vector3(0.3, 0, 0.53)), Vector3(0, 0.95, 0), Vector2(0.7, 0.45), body.darkened(0.25), "paint")
	for sz: float in [-1.0, 1.0]:
		k.cyl(0.3, 0.3, 0.2, Vector3(0, 0.3, sz * 0.66), "rubber", Color(0.1, 0.1, 0.1), Vector3(PI * 0.5, 0, 0), 12)
		for sx: float in [-1.0, 1.0]:
			k.beam(Vector3(sx * 0.85, 0.6, sz * 0.5), Vector3(sx * 1.25, 0.08, sz * 0.95), 0.06, 0.06, "steel", STEEL, false)
			k.box(Vector3(0.22, 0.04, 0.22), Vector3(sx * 1.25, 0.02, sz * 0.95), "steel", STEEL, Vector3.ZERO, false)
	k.beam(Vector3(0.95, 0.5, 0), Vector3(1.9, 0.42, 0), 0.08, 0.08, "steel", STEEL)
	k.part(BuildingKit.ring(0.04, 0.07), "steel", Mats.place(Vector3(1.95, 0.42, 0), Vector3(PI * 0.5, 0, 0)), STEEL, false)
	# the mast, three sections run up
	for i in 3:
		var r := 0.075 - i * 0.015
		k.cyl(r, r, (h - 1.4) / 3.0 + 0.2, Vector3(-0.7, 1.45 + (h - 1.4) * (i + 0.5) / 3.0, 0), "steel", Color(0.7, 0.7, 0.68), Vector3.ZERO, 8)
	k.box(Vector3(0.08, 0.08, 1.3), Vector3(-0.7, h, 0), "steel", STEEL)
	for sz: float in [-0.48, -0.16, 0.16, 0.48]:
		floodlight(k.at_point(Vector3(-0.72, h + 0.05, sz), Vector3(0, -PI * 0.5, 0)), 0.45)


## A water trailer (a "buffalo"), its drawbar along +x: the tank on its
## frame, the hatch on top, the taps along its rear end, two wheels under
## mudguards, the prop stand down.
static func water_trailer(k: BuildingKit, col := OLIVE) -> void:
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(2.7, 0.12, 0.1), Vector3(-0.1, 0.58, sz * 0.45), "steel", col.darkened(0.2))
		k.cyl(0.38, 0.38, 0.24, Vector3(0, 0.38, sz * 0.86), "rubber", Color(0.1, 0.1, 0.1), Vector3(PI * 0.5, 0, 0), 14)
		k.cyl(0.18, 0.18, 0.26, Vector3(0, 0.38, sz * 0.86), "paint", col.darkened(0.15), Vector3(PI * 0.5, 0, 0), 10, false)
		k.box(Vector3(0.95, 0.04, 0.32), Vector3(0, 0.83, sz * 0.84), "paint", col)
	k.box(Vector3(0.1, 0.1, 1.9), Vector3(0, 0.38, 0), "steel", STEEL, Vector3.ZERO, false)
	k.cyl(0.56, 0.56, 2.3, Vector3(-0.15, 1.22, 0), "paint", col, Vector3(0, 0, PI * 0.5), 16)
	for x: float in [-0.9, -0.15, 0.6]:
		k.cyl(0.575, 0.575, 0.06, Vector3(x, 1.22, 0), "paint", col.darkened(0.12), Vector3(0, 0, PI * 0.5), 16, false)
	k.cyl(0.2, 0.2, 0.12, Vector3(0.1, 1.82, 0), "paint", col.darkened(0.05), Vector3.ZERO, 10)
	for i in 4:
		k.rod(Vector3(-1.32, 0.85, -0.3 + i * 0.2), Vector3(-1.42, 0.78, -0.3 + i * 0.2), 0.025, "steel", Color(0.55, 0.52, 0.42), 6, false)
	# the drawbar: an A-frame out to the towing eye, the prop stand under it
	for sz: float in [-1.0, 1.0]:
		k.beam(Vector3(1.2, 0.58, sz * 0.45), Vector3(2.2, 0.5, 0), 0.08, 0.08, "steel", col.darkened(0.2))
	k.part(BuildingKit.ring(0.05, 0.08), "steel", Mats.place(Vector3(2.28, 0.5, 0), Vector3(PI * 0.5, 0, 0)), STEEL, false)
	k.rod(Vector3(1.9, 0.5, 0), Vector3(1.9, 0.0, 0), 0.03, "steel", STEEL, 6, false)
	k.box(Vector3(0.16, 0.03, 0.16), Vector3(1.9, 0.015, 0), "steel", STEEL, Vector3.ZERO, false)


## A guard's booth at a gate, its window towards -z and +x (the lane and the
## road): plywood on a frame, a band of windows round it, a sheet roof
## overhanging, sandbags up to the sill on its two outward sides. A
## militia's is bare boards under a rusty sheet.
static func guard_post(k: BuildingKit, regular: bool, rng: RandomNumberGenerator) -> void:
	var wall := Color(0.62, 0.55, 0.4) if regular else Color(0.48, 0.38, 0.26)
	var roof := Color(0.42, 0.43, 0.4) if regular else Color(0.45, 0.27, 0.16)
	k.box(Vector3(1.5, 1.05, 1.5), Vector3(0, 0.525, 0), "wood_painted" if regular else "wood", wall)
	k.box(Vector3(1.5, 0.35, 1.5), Vector3(0, 2.07, 0), "wood_painted" if regular else "wood", wall)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(0.1, 0.85, 0.1), Vector3(sx * 0.7, 1.47, sz * 0.7), "wood_painted" if regular else "wood", wall.darkened(0.1))
	k.box(Vector3(1.36, 0.82, 1.36), Vector3(0, 1.47, 0), "glass", Color(0.2, 0.24, 0.26), Vector3.ZERO, false)
	k.box(Vector3(1.9, 0.06, 1.9), Vector3(0.0, 2.28, 0.0), "corrugated", roof, Vector3(0.05, 0, 0))
	# its door on the side towards the compound
	k.plate(Vector3(0.02, 1.9, 0.7), Vector3(-0.76, 0.98, 0.1), "wood_painted" if regular else "wood", wall.darkened(0.2), Vector3.ZERO, true)
	# sandbags up to the sill, on the two sides a car bomb would come from
	sandbags(k.at_point(Vector3(0.15, 0, -0.97)), 1.8, 1.0, rng)
	sandbags(k.at_point(Vector3(0.97, 0, 0.15), Vector3(0, PI * 0.5, 0)), 1.6, 1.0, rng)
	floodlight(k.at_point(Vector3(0.6, 2.2, -0.8), Vector3(0, PI, 0)), 0.7)


## A biconical aerial (the kind a headquarters puts up for its long-range
## net) on a sectional mast `h` tall at `base`, guyed three ways at two
## levels: two cones of six elements each at the top, the hub between them.
static func bicone(k: BuildingKit, base: Vector3, h: float, yaw := 0.0) -> void:
	k.box(Vector3(0.4, 0.1, 0.4), base + Vector3(0, 0.05, 0), "steel", STEEL)
	for i in 4:
		var r := 0.05 - i * 0.006
		k.cyl(r, r, h / 4.0, base + Vector3(0, h * (i + 0.5) / 4.0, 0), "paint", OLIVE.darkened(0.2), Vector3.ZERO, 8)
		if i > 0:
			k.cyl(r + 0.015, r + 0.015, 0.1, base + Vector3(0, h * i / 4.0, 0), "paint", OLIVE.darkened(0.3), Vector3.ZERO, 8, false)
	var hub := base + Vector3(0, h + 0.75, 0)
	k.cyl(0.06, 0.06, 0.4, hub, "paint", OLIVE.darkened(0.25), Vector3.ZERO, 8)
	k.rod(base + Vector3(0, h, 0), hub, 0.025, "paint", OLIVE.darkened(0.2), 6, false)
	for i in 6:
		var a := yaw + TAU * i / 6.0
		var out := Vector3(cos(a), 0, sin(a))
		k.rod(hub + Vector3(0, 0.2, 0), hub + out * 0.8 + Vector3(0, 0.95, 0), 0.012, "metal_dark", Color(0.15, 0.15, 0.15), 4, false)
		k.rod(hub - Vector3(0, 0.2, 0), hub + out * 0.8 - Vector3(0, 0.95, 0), 0.012, "metal_dark", Color(0.15, 0.15, 0.15), 4, false)
	for lvl: float in [0.45, 0.95]:
		for i in 3:
			var a := yaw + PI / 6.0 + TAU * i / 3.0
			BuildingWire.guy(k, base + Vector3(0, h * lvl, 0), base + Vector3(cos(a), 0, sin(a)) * h * 0.25, false, "picket")


## A power cable lying on the ground along `pts` (y is ignored: it lies on
## y = 0), kinked a little where it was dropped.
static func ground_cable(k: BuildingKit, pts: Array) -> void:
	var run := PackedVector3Array()
	for i in pts.size():
		var p: Vector3 = pts[i]
		run.append(Vector3(p.x, 0.025, p.z))
		if i + 1 < pts.size():
			var q: Vector3 = pts[i + 1]
			var m := p.lerp(q, 0.5)
			var side := Vector3(q.z - p.z, 0, p.x - q.x).normalized()
			run.append(Vector3(m.x, 0.025, m.z) + side * 0.12 * sin(p.x * 3.1 + q.z))
	k.part(BuildingKit.tube_mesh(run, 0.022, 4), "rubber", Transform3D.IDENTITY, Color(0.07, 0.07, 0.07), false)


## A side's headquarters `size` across (x) and deep (z), for `team` (0 a
## regular army's, 1 a militia's). The containers and the command post stand
## where Structure's parts are; around them, from the front: the wall (HESCO
## for an army, sandbags and drums for a militia) with its returns back to
## the containers; the yard behind it under the net, with the map table, the
## radio desk and the stores; the generators and the long-range aerial
## behind the signals office; the gate, the guard's booth, the vehicle park
## and its light tower behind the stores; the flag by the command post's
## door. Returns where the flag's hoist is. The net itself is `net`'s.
static func compound(k: BuildingKit, size: Vector3, team: int, flag_col: Color, rng: RandomNumberGenerator) -> Vector3:
	var regular := team != 1
	var paint: Array = ARMY if regular else COMMERCIAL
	var a: Color = paint[rng.randi() % paint.size()]
	var b: Color = paint[(paint.find(a) + 1 + rng.randi() % (paint.size() - 1)) % paint.size()]
	# the two containers on sleepers (Structure's parts at (-5, 0) and (5, -1)):
	# the signals office on the left, turned so its window, air conditioner
	# and cables face the rear, where its power comes from; the stores on the
	# right, its doors towards the gate for the lorries
	for spec: Array in [[Vector3(-5, 0, 0), a, true], [Vector3(5, 0, -1), b, false]]:
		var at: Vector3 = spec[0]
		for sx: float in [-2.4, 0.0, 2.4]:
			k.box(Vector3(0.2, 0.12, 2.6), at + Vector3(sx, 0.06, 0), "wood_dark", Color(0.3, 0.24, 0.17), Vector3.ZERO, false)
		container(k.at_point(at + Vector3(0, 0.1, 0), Vector3(0, PI if at.x < 0.0 else 0.0, 0)), spec[1], rng, spec[2])
	# the command post at the back (its part at (0, 3.5), 5 by 3 by 4), its door to the rear
	command_post(k.at_point(Vector3(0, 0, 3.5)), Vector3(5.0, 2.9, 4.0), rng, flag_col)
	_front(k, regular, rng)
	_yard(k, regular, rng)
	_power(k, regular, rng)
	_entry(k, regular, flag_col, rng)
	# the flag by the command post's door, where those arriving see it first
	return BuildingFittings.flagpole(k, Vector3(2.7, 0, 6.4), 8.6, Color(0.7, 0.7, 0.68))


## The wall towards the battle, out in front of the yard, and its returns
## back along both sides to the containers' ends. An army's is HESCO; a
## militia's is sandbags in runs, oil drums filled with earth between them.
static func _front(k: BuildingKit, regular: bool, rng: RandomNumberGenerator) -> void:
	var cells := 17
	var half := cells * CELL.x * 0.5
	var side_x := half - CELL.z * 0.5
	# the returns: back to the office's front end on the left, the stores' on the right
	var back := [-1.3, -2.3]
	if regular:
		var tint := Color(0.53, 0.48, 0.36)
		hesco(k.at_point(Vector3(0, 0, FRONT_Z)), cells, tint)
		for i in 2:
			var sx := -1.0 if i == 0 else 1.0
			var z0 := FRONT_Z + CELL.z * 0.5
			var n := roundi((float(back[i]) - z0) / CELL.x)
			hesco(k.at_point(Vector3(sx * side_x, 0, z0 + n * CELL.x * 0.5), Vector3(0, PI * 0.5, 0)), n, tint.darkened(0.04 * i))
		return
	# the militia's: runs of bags with a drum stood between each
	var x := -half
	var v := 0
	while x < half - 0.5:
		var bags := mini(5, int((half - x) / 0.6))
		if bags < 2:
			break
		k.part(bag_run(bags, 8, v % 3), "canvas", Mats.place(Vector3(x + bags * 0.3, 0, FRONT_Z)), SACKING.darkened(0.04 * (v % 3)))
		x += bags * 0.6
		v += 1
		if x < half - 0.8:
			BuildingFittings.drum(k, Vector3(x + 0.3, 0, FRONT_Z + rng.randf_range(-0.05, 0.05)), Color(0.32, 0.3, 0.26).lerp(Color(0.45, 0.17, 0.12), rng.randf()), false, rng.randf() * TAU, "paint")
			x += 0.6
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		var n := roundi((float(back[i]) - (FRONT_Z + 0.4)) / 0.6)
		k.part(bag_run(n, 8, i), "canvas", Mats.place(Vector3(sx * (half - 0.35), 0, FRONT_Z + 0.4 + n * 0.3), Vector3(0, PI * 0.5, 0)), SACKING.darkened(0.06))


## The yard behind the wall, under the net: the map table with its set, the
## board of maps facing it, the radio desk along the stores' front, crated
## stores, rations and water on pallets, the net's spreader poles and its
## corner poles guyed out.
static func _yard(k: BuildingKit, regular: bool, rng: RandomNumberGenerator) -> void:
	var issue := OLIVE if regular else Color(0.45, 0.35, 0.22)
	# the map table, the set and its handset; benches either side
	var t := Vector3(0.0, 0, -2.3)
	k.box(Vector3(1.8, 0.05, 0.9), t + Vector3(0, 0.76, 0), "wood", Color(0.45, 0.36, 0.24))
	for sx: float in [-0.8, 0.8]:
		for sz: float in [-0.38, 0.38]:
			k.box(Vector3(0.04, 0.74, 0.04), t + Vector3(sx, 0.37, sz), "steel", STEEL, Vector3.ZERO, false)
	k.plate(Vector3(1.0, 0.01, 0.66), t + Vector3(-0.2, 0.79, 0), "paint", Color(0.82, 0.8, 0.66))
	k.plate(Vector3(0.3, 0.012, 0.4), t + Vector3(-0.45, 0.8, 0.05), "paint", Color(0.55, 0.62, 0.45), Vector3(0, 0.3, 0))
	k.box(Vector3(0.36, 0.22, 0.26), t + Vector3(0.6, 0.9, 0.1), "paint", Color(0.24, 0.27, 0.2))
	BuildingFittings.whip(k, t + Vector3(0.7, 1.01, 0.18), 1.6)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(1.6, 0.05, 0.3), t + Vector3(0, 0.45, sx * 0.75), "wood", Color(0.42, 0.33, 0.22))
		for ex: float in [-0.65, 0.65]:
			k.box(Vector3(0.05, 0.43, 0.24), t + Vector3(ex, 0.215, sx * 0.75), "wood", Color(0.38, 0.3, 0.2), Vector3.ZERO, false)
	# the board of maps, facing the table from the wall's side
	var mb := k.at_point(Vector3(0.0, 0, -4.15))
	for sx: float in [-0.75, 0.75]:
		mb.box(Vector3(0.05, 1.9, 0.05), Vector3(sx, 0.95, 0), "steel", STEEL)
	mb.box(Vector3(1.5, 1.0, 0.04), Vector3(0, 1.35, 0), "plain", Color(0.85, 0.85, 0.82))
	for i in 3:
		mb.plate(Vector3(0.42, 0.55, 0.01), Vector3(-0.45 + i * 0.45, 1.38, 0.025), "paint", [Color(0.78, 0.76, 0.6), Color(0.62, 0.7, 0.55), Color(0.8, 0.78, 0.7)][i])
	# the radio desk along the stores' front: sets stacked on folding tables
	for i in 2:
		var d := Vector3(3.4 + i * 1.9, 0, -3.0)
		k.box(Vector3(1.8, 0.04, 0.7), d + Vector3(0, 0.74, 0), "plain", Color(0.42, 0.42, 0.38))
		for sx: float in [-0.82, 0.82]:
			k.box(Vector3(0.04, 0.72, 0.6), d + Vector3(sx, 0.36, 0), "steel", STEEL, Vector3.ZERO, false)
		for j in 2:
			k.box(Vector3(0.42, 0.24 + 0.08 * j, 0.36), d + Vector3(-0.5 + j * 0.75, 0.88 + 0.04 * j, -0.1), "paint", Color(0.22, 0.25, 0.2).darkened(0.1 * j))
		var ch := d + Vector3(0.1 - 0.5 * i, 0, -0.62)
		k.box(Vector3(0.42, 0.04, 0.42), ch + Vector3(0, 0.46, 0), "plain_dark", Color(0.14, 0.15, 0.13), Vector3.ZERO, false)
		k.box(Vector3(0.42, 0.4, 0.03), ch + Vector3(0, 0.68, -0.2), "plain_dark", Color(0.14, 0.15, 0.13), Vector3(-0.12, 0, 0), false)
		for sx: float in [-0.19, 0.19]:
			k.beam(ch + Vector3(sx, 0.0, -0.2), ch + Vector3(sx, 0.45, 0.18), 0.02, 0.02, "steel", STEEL, false)
			k.beam(ch + Vector3(sx, 0.0, 0.2), ch + Vector3(sx, 0.45, -0.18), 0.02, 0.02, "steel", STEEL, false)
	BuildingFittings.whip(k, Vector3(5.2, 1.06, -3.1), 1.4)
	# stores crated on pallets, rations and water, in the left of the yard
	for i in 2:
		var p := Vector3(-6.4 + i * 1.3, 0, -3.6)
		BuildingFittings.pallet(k, p, Vector2(1.15, 1.0))
		for j in 2:
			for y in 2 - (i + j) % 2:
				BuildingFittings.crate(k, p + Vector3((j - 0.5) * 0.55, 0.13 + y * 0.42, 0), Vector3(0.52, 0.4, 0.92), issue.darkened(rng.randf_range(0.0, 0.1)), rng.randf_range(-0.05, 0.05), "paint")
	var food := Vector3(-3.8, 0, -4.6)
	BuildingFittings.pallet(k, food, Vector2(1.15, 1.0))
	k.box(Vector3(1.1, 0.9, 0.95), food + Vector3(0, 0.58, 0), "plain", Color(0.62, 0.55, 0.42))
	var water := Vector3(-5.2, 0, -4.9)
	BuildingFittings.pallet(k, water, Vector2(1.15, 1.0))
	k.box(Vector3(1.1, 0.75, 0.95), water + Vector3(0, 0.5, 0), "glass", Color(0.62, 0.7, 0.72))
	k.box(Vector3(1.12, 0.03, 0.97), water + Vector3(0, 0.88, 0), "plain", Color(0.85, 0.86, 0.84))
	# the net's poles: the spreaders under it, and its front corners guyed out
	for sp: Vector2 in SPREADERS:
		var top := _net_h(sp.x, sp.y)
		k.cyl(0.04, 0.05, top - 0.04, Vector3(sp.x, (top - 0.04) * 0.5, sp.y), "wood_dark" if not regular else "steel", Color(0.3, 0.24, 0.17) if not regular else Color(0.45, 0.46, 0.42), Vector3.ZERO, 6)
		k.cyl(0.18, 0.18, 0.02, Vector3(sp.x, top - 0.03, sp.y), "metal_dark", Color(0.2, 0.2, 0.2), Vector3.ZERO, 8, false)
	for sx: float in [-1.0, 1.0]:
		var c := Vector2(sx * (NET.size.x * 0.5 - 0.2), -4.9)
		var top := _net_h(c.x, c.y)
		k.cyl(0.035, 0.045, top, Vector3(c.x, top * 0.5, c.y), "wood_dark" if not regular else "steel", Color(0.3, 0.24, 0.17) if not regular else Color(0.45, 0.46, 0.42), Vector3.ZERO, 6)
		BuildingWire.guy(k, Vector3(c.x, top, c.y), Vector3(c.x + sx * 1.2, 0.0, c.y + 0.3), true, "peg")


## Behind the signals office: the power. Two generators side by side (one
## running, one standing by) on a concrete pad, the fuel by them on a spill
## pallet with an extinguisher, the cables run along the ground to a
## distribution board on the command post's wall and on into the office;
## the long-range aerial in the corner.
static func _power(k: BuildingKit, regular: bool, rng: RandomNumberGenerator) -> void:
	k.plate(Vector3(5.6, 0.04, 2.3), Vector3(-5.6, 0.02, 3.75), "concrete", Color(0.47, 0.46, 0.43), Vector3.ZERO, false)
	var gen := OLIVE if regular else Color(0.78, 0.6, 0.16)
	generator(k.at_point(Vector3(-6.95, 0, 3.7)), gen, false)
	generator(k.at_point(Vector3(-4.5, 0, 3.7)), gen.darkened(0.06), true)
	# the distribution board, on the command post's wall facing them
	var db := Vector3(-2.62, 0, 2.7)
	k.box(Vector3(0.22, 0.8, 0.6), db + Vector3(0, 1.0, 0), "paint", Color(0.55, 0.56, 0.52))
	k.box(Vector3(0.08, 0.6, 0.08), db + Vector3(-0.05, 0.3, 0.2), "metal_dark", Color(0.18, 0.18, 0.18), Vector3.ZERO, false)
	ground_cable(k, [Vector3(-6.0, 0, 3.15), Vector3(-5.2, 0, 2.6), Vector3(-3.4, 0, 2.6), db + Vector3(-0.1, 0, 0.2)])
	ground_cable(k, [Vector3(-3.6, 0, 3.15), Vector3(-3.0, 0, 2.95), db + Vector3(-0.1, 0, 0.25)])
	# and on to the office: up its side to where its cables go in
	ground_cable(k, [db + Vector3(-0.1, 0, -0.2), Vector3(-2.9, 0, 1.9), Vector3(-3.3, 0, 1.45)])
	# the fuel, on a spill pallet, jerrycans by it, the extinguisher on its stand
	var fuel := Vector3(-7.6, 0, 5.35)
	k.box(Vector3(1.3, 0.14, 1.3), fuel + Vector3(0, 0.07, 0), "paint", Color(0.2, 0.22, 0.2) if regular else Color(0.22, 0.3, 0.42))
	for i in 4:
		BuildingFittings.drum(k, fuel + Vector3(-0.3 + (i % 2) * 0.6, 0.14, -0.3 + floorf(i / 2.0) * 0.6), OLIVE if regular else Color(0.45, 0.17, 0.12), false, i * 0.9, "paint")
	for i in 4:
		k.box(Vector3(0.17, 0.46, 0.34), Vector3(-6.4 + i * 0.2, 0.23, 5.5), "paint", OLIVE.darkened(rng.randf_range(0.0, 0.12)), Vector3(0, rng.randf_range(-0.1, 0.1), 0))
	k.box(Vector3(0.05, 1.0, 0.05), Vector3(-5.4, 0.5, 5.6), "steel", STEEL)
	k.cyl(0.08, 0.08, 0.5, Vector3(-5.4, 0.6, 5.5), "paint", Color(0.72, 0.1, 0.08), Vector3.ZERO, 8)
	# the long-range aerial
	bicone(k, Vector3(-8.0, 0, 6.4), 8.0, 0.4)


## The entry behind the stores, off the road: the drive in from it, the gate
## across the lane (the barrier, the guard's booth, a board telling drivers
## to stop), a concrete barrier closing the gap between the wall's end and
## the gate, and inside, the vehicle park: a hardstand, wheel stops, the water
## trailer, the jerrycans, the light tower in its corner.
static func _entry(k: BuildingKit, regular: bool, flag_col: Color, rng: RandomNumberGenerator) -> void:
	# the barrier across the lane (z 0.5 to 4.5), its post on the far side from the stores
	boom(k.at_point(Vector3(GATE_X, 0, 4.85), Vector3(0, PI * 0.5, 0)), 4.3, rng.randf() < 0.5, flag_col)
	guard_post(k.at_point(Vector3(GATE_X, 0, 6.9)), regular, rng)
	# the stop board out at the lane's mouth, facing the road
	var stop := k.at_point(Vector3(GATE_X + 0.8, 0, 0.0), Vector3(0, PI * 0.5, 0))
	for sx: float in [-0.4, 0.4]:
		stop.box(Vector3(0.06, 1.7, 0.06), Vector3(sx, 0.85, 0), "steel", STEEL)
	stop.box(Vector3(1.0, 0.6, 0.04), Vector3(0, 1.4, 0.04), "paint", Color(0.78, 0.1, 0.08))
	stop.plate(Vector3(0.84, 0.16, 0.01), Vector3(0, 1.4, 0.065), "paint", Color(0.94, 0.93, 0.9))
	# the gap between the wall's end and the gate
	if regular:
		jersey(k.at_point(Vector3(GATE_X, 0, -0.85)), 2.9)
	else:
		for i in 4:
			BuildingFittings.drum(k, Vector3(GATE_X, 0, -2.1 + i * 0.65), Color(0.32, 0.3, 0.26).lerp(Color(0.45, 0.17, 0.12), rng.randf()), false, rng.randf() * TAU, "paint")
	# the vehicle park
	k.plate(Vector3(6.2, 0.04, 4.9), Vector3(5.75, 0.02, 3.05), "concrete", Color(0.5, 0.49, 0.45), Vector3.ZERO, false)
	# and on out through the gate to the road's edge, the drive in
	k.plate(Vector3(2.75, 0.04, 4.0), Vector3(10.23, 0.015, 2.6), "concrete", Color(0.48, 0.47, 0.43), Vector3.ZERO, false)
	for x: float in [3.9, 6.2]:
		k.box(Vector3(1.6, 0.14, 0.2), Vector3(x, 0.07, 5.05), "wood_dark", Color(0.32, 0.26, 0.18))
	water_trailer(k.at_point(Vector3(3.9, 0, 3.3), Vector3(0, PI * 0.5, 0)), OLIVE if regular else Color(0.6, 0.62, 0.6))
	for i in 6:
		k.box(Vector3(0.17, 0.46, 0.34), Vector3(6.3 + i * 0.2, 0.23, 1.15), "paint", OLIVE.darkened(rng.randf_range(0.0, 0.12)), Vector3(0, rng.randf_range(-0.1, 0.1), 0))
	light_tower(k.at_point(Vector3(8.0, 0, 4.3), Vector3(0, -PI * 0.5, 0)))


## How high the net is over (x, z) of the yard: up over its spreaders,
## sagging between them, never down onto the containers' roofs, draped down
## its front onto the wall's top and down its open sides in front of the
## containers.
static func _net_h(x: float, z: float) -> float:
	var h := 3.0
	for sp: Vector2 in SPREADERS:
		h += 0.38 * exp(-((x - sp.x) * (x - sp.x) + (z - sp.y) * (z - sp.y)) / 1.3)
	h += 0.05 * sin(x * 1.9 + 0.7) * sin(z * 1.6 - 0.4)
	# down its sides in front of the containers' ends
	var end_z := -1.25 if x < 0.0 else -2.25
	var band := clampf((end_z - 0.3 - z) / 1.2, 0.0, 1.0)
	var side := clampf((absf(x) - 3.0) / 1.6, 0.0, 1.0)
	h -= 0.95 * side * side * band
	# and over the front, onto the wall
	var f := clampf((z - NET.position.y) / 2.2, 0.0, 1.0)
	return lerpf(CELL.y + 0.1, h, f * f * (3.0 - 2.0 * f))


static var _net: ArrayMesh


## The camouflage net over an HQ's yard (`_yard` draws its poles), a node of
## its own under `root`: netting has its own shader, which doesn't bake.
static func net(root: Node3D, team: int) -> void:
	if _net == null:
		_net = _net_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _net
	mi.material_override = Mats.netting_tent()
	Mats.set_inst(mi, &"tint", Color(0.3, 0.34, 0.2) if team != 1 else Color(0.44, 0.39, 0.27))
	root.add_child(mi)


## The net's shape (see _net_h) as a mesh, UV running 0..1 corner to corner
## (the netting shader frays its edges).
static func _net_mesh() -> ArrayMesh:
	var nx := 26
	var nz := 22
	var pos: Array = []
	for j in nz + 1:
		var row: Array = []
		for i in nx + 1:
			var x := NET.position.x + NET.size.x * i / nx
			var z := NET.position.y + NET.size.y * j / nz
			row.append(Vector3(x, _net_h(x, z), z))
		pos.append(row)
	var vv := PackedVector3Array()
	var nn := PackedVector3Array()
	var uu := PackedVector2Array()
	for j in nz:
		for i in nx:
			var q := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			for tri: Array in [[0, 1, 2], [0, 2, 3]]:
				for c: int in tri:
					var g: Vector2i = q[c]
					var du: Vector3 = pos[g.y][mini(g.x + 1, nx)] - pos[g.y][maxi(g.x - 1, 0)]
					var dv: Vector3 = pos[mini(g.y + 1, nz)][g.x] - pos[maxi(g.y - 1, 0)][g.x]
					var n := dv.cross(du).normalized()
					vv.append(pos[g.y][g.x])
					nn.append(n if n.y >= 0.0 else -n)
					uu.append(Vector2(float(g.x) / nx, float(g.y) / nz))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vv
	arrays[Mesh.ARRAY_NORMAL] = nn
	arrays[Mesh.ARRAY_TEX_UV] = uu
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
