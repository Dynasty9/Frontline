class_name BuildingDepot
extends RefCounted
## A side's headquarters (Structure "depot") and what it's made of: ISO
## shipping containers, a precast command post sandbagged on its roof, the
## generator that runs it, the stores in the yard under a camouflage net, the
## posts and chain round it and the barrier at its gate. In a kit standing on
## the ground (y = 0); the HQ's front (towards the battle) is -z.

## A 20-foot container's length, width and height (an ISO 1C box).
const CONTAINER := Vector3(6.06, 2.59, 2.44)
## Containers as a regular army has them: olive, tan, grey; and as a militia
## gets them, off the docks: rust, faded blue, teal, a white gone grey.
const ARMY := [Color(0.3, 0.33, 0.22), Color(0.5, 0.45, 0.33), Color(0.38, 0.4, 0.36)]
const COMMERCIAL := [Color(0.55, 0.28, 0.18), Color(0.22, 0.33, 0.48), Color(0.2, 0.38, 0.36), Color(0.66, 0.66, 0.62)]
const STEEL := Color(0.25, 0.26, 0.27)


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


## A command post of precast concrete `size` (x by y by z), its door in its
## -z face: a lip of slab over it, two courses of sandbags round the roof's
## edge, vision slits in its faces with steel shutters, the door in a
## sandbagged blast wall, a mast guyed from its roof.
static func command_post(k: BuildingKit, size: Vector3, rng: RandomNumberGenerator) -> void:
	var wc := Color(0.5, 0.5, 0.47)
	k.box(size, Vector3(0, size.y * 0.5, 0), "precast", wc)
	var gaps_front := [Rect2(-0.6, 0.0, 1.2, 2.1)]
	for face in 4:
		var out: Vector3 = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)][face]
		var flen := size.x if face < 2 else size.z
		var fk := k.on_face(out * Vector3(size.x * 0.5, 0, size.z * 0.5), out)
		var gaps: Array = gaps_front.duplicate() if face == 0 else []
		# a vision slit in each face (two in the long ones), its shutter on top
		var slits: Array = [0.0] if flen < 4.5 else [-flen * 0.25, flen * 0.25]
		if face == 0:
			slits = [flen * 0.3]
		for sx: float in slits:
			gaps.append(Rect2(sx - 0.45, 1.5, 0.9, 0.2))
		BuildingWalls.face(fk, flen, size.y, "precast", wc, gaps, {"plinth": 0.25})
		BuildingWalls.joints(fk, flen, size.y, 1.2, wc, gaps)
		for sx: float in slits:
			fk.box(Vector3(0.9, 0.2, 0.1), Vector3(sx, 1.6, -0.04), "plain_dark", Color(0.04, 0.04, 0.04), Vector3.ZERO, false)
			fk.box(Vector3(1.0, 0.24, 0.03), Vector3(sx, 1.84, 0.06), "steel", STEEL, Vector3(-0.5, 0, 0), false)
		if face == 0:
			BuildingOpenings.doorway(fk, Vector3(0, 0, 0), Vector2(1.1, 2.05), {"material": "precast", "wall": wc, "inset": -0.05,
				"frame_kind": "metal_dark", "frame": Color(0.22, 0.23, 0.23), "step": false})
			BuildingOpenings.leaf(fk.at_point(Vector3(-0.53, 0, 0.03)), Vector2(1.06, 2.0), "steel", Color(0.24, 0.27, 0.22), 1.0)
			# a blast wall of sandbags before the door, open at one side
			sandbags(fk.at_point(Vector3(-0.3, 0, 1.25)), 2.0, 1.2, rng)
			sandbags(fk.at_point(Vector3(-1.38, 0, 0.75), Vector3(0, PI * 0.5, 0)), 0.9, 1.2, rng)
	# the slab, a lip over the walls, and sandbags round its edge
	k.box(Vector3(size.x + 0.3, 0.25, size.z + 0.3), Vector3(0, size.y + 0.125, 0), "concrete", Color(0.46, 0.46, 0.43))
	for sd: float in [-1.0, 1.0]:
		sandbags(k.at_point(Vector3(0, size.y + 0.25, sd * (size.z * 0.5 - 0.05)), Vector3(0, 0.0 if sd < 0.0 else PI, 0)), size.x + 0.1, 0.42, rng)
		sandbags(k.at_point(Vector3(sd * (size.x * 0.5 - 0.05), size.y + 0.25, 0), Vector3(0, sd * PI * 0.5, 0)), size.z - 0.7, 0.42, rng)
	BuildingFittings.mast(k, Vector3(size.x * 0.25, size.y + 0.25, size.z * 0.15), 6.0, 3, 0.5, STEEL, 0.2, size.y + 0.25, [0.6])
	BuildingFittings.whip(k, Vector3(-size.x * 0.3, size.y + 0.25, -size.z * 0.2), 2.8)


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
			var col := Color(0.55, 0.49, 0.35).darkened(rng.randf_range(0.0, 0.14))
			var turn := Basis.from_euler(Vector3(0, rng.randf_range(-0.06, 0.06) + (PI if rng.randf() < 0.5 else 0.0), rng.randf_range(-0.04, 0.04)))
			k.part(_bag, "canvas", Transform3D(turn * Basis.from_scale(Vector3(w * 1.04, ch * 1.15, depth)), Vector3(x, (c + 0.5) * ch, 0)), col, c == courses - 1)


## A diesel generator on skids, in its olive canopy: louvres down its sides,
## the exhaust stack with its rain cap, the cable off it to a drum.
static func generator(k: BuildingKit, col := Color(0.3, 0.33, 0.22)) -> void:
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(2.0, 0.1, 0.1), Vector3(0, 0.05, sz * 0.45), "steel", STEEL)
	k.box(Vector3(1.9, 1.15, 1.0), Vector3(0, 0.7, 0), "paint", col)
	k.box(Vector3(1.95, 0.06, 1.05), Vector3(0, 1.3, 0), "paint", col.darkened(0.1))
	for sz: float in [-1.0, 1.0]:
		BuildingOpenings.louvre(k.at_point(Vector3(-0.4, 0, sz * 0.505), Vector3(0, 0.0 if sz > 0.0 else PI, 0)), Vector3(0, 0.75, 0), Vector2(0.8, 0.6), col.darkened(0.2), "paint")
		k.plate(Vector3(0.5, 0.3, 0.01), Vector3(0.5, 0.8, sz * 0.505), "plain_dark", Color(0.1, 0.1, 0.1))
	k.cyl(0.05, 0.05, 0.6, Vector3(0.65, 1.6, 0.3), "metal_dark", Color(0.12, 0.11, 0.1), Vector3.ZERO, 8)
	k.cyl(0.0, 0.1, 0.06, Vector3(0.65, 1.93, 0.3), "metal_dark", Color(0.12, 0.11, 0.1), Vector3.ZERO, 8, false)
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
	k.box(Vector3(0.06, 1.5, 0.06), Vector3(-0.6, 0.75, 0.3), "steel", STEEL)
	k.box(Vector3(0.9, 0.55, 0.04), Vector3(-0.6, 1.55, 0.3), "paint", sign_col)
	k.box(Vector3(0.8, 0.12, 0.045), Vector3(-0.6, 1.6, 0.3), "paint", Color(0.92, 0.91, 0.86))


## A side's headquarters `size` across (x) and deep (z), for `team` (0 a
## regular army's, 1 a militia's): two 20-foot containers either side of a
## yard (the stores, and the signals office), the precast command post at the
## back of it, a camouflage net over the yard on poles, stores and fuel under
## it, the generator by the command post, a line of posts and chain along the
## front with a barrier at the gate. The posts are where Structure's parts
## are (the containers and the command post stand on them); returns where the
## flag's hoist is, on the pole in the yard. The net itself is `net`'s.
static func compound(k: BuildingKit, size: Vector3, team: int, flag_col: Color, rng: RandomNumberGenerator) -> Vector3:
	var paint: Array = ARMY if team != 1 else COMMERCIAL
	var a: Color = paint[rng.randi() % paint.size()]
	var b: Color = paint[(paint.find(a) + 1 + rng.randi() % (paint.size() - 1)) % paint.size()]
	# the two containers, on sleepers (Structure's parts at (-5, 0) and (5, -1))
	for spec: Array in [[Vector3(-5, 0, 0), a, false], [Vector3(5, 0, -1), b, true]]:
		var at: Vector3 = spec[0]
		for sx: float in [-2.4, 0.0, 2.4]:
			k.box(Vector3(0.2, 0.12, 2.6), at + Vector3(sx, 0.06, 0), "wood_dark", Color(0.3, 0.24, 0.17), Vector3.ZERO, false)
		container(k.at_point(at + Vector3(0, 0.1, 0), Vector3(0, PI if at.x < 0.0 else 0.0, 0)), spec[1], rng, spec[2])
	# the command post at the back (its part at (0, 3.5), 5 by 3 by 4)
	command_post(k.at_point(Vector3(0, 0, 3.5)), Vector3(5.0, 2.9, 4.0), rng)
	generator(k.at_point(Vector3(3.6, 0, 3.6), Vector3(0, PI * 0.5, 0)))
	# the poles of the net over the yard (see net), guyed out
	for px: float in [-3.4, 3.4]:
		for pz: float in [-5.2, 1.0]:
			k.cyl(0.05, 0.06, 3.15, Vector3(px, 1.575, pz), "wood_dark", Color(0.3, 0.24, 0.17), Vector3.ZERO, 6)
			if pz < 0.0:
				BuildingWire.guy(k, Vector3(px, 3.1, pz), Vector3(px * 1.15, 0.0, pz - 1.0), true, "peg")
	# under it: stores crated on pallets, the fuel, a table with the maps and the set
	for i in 2:
		BuildingFittings.pallet(k, Vector3(-1.9 + i * 1.2, 0, -3.6), Vector2(1.15, 1.0))
		for j in 2:
			for y in 2 - (i + j) % 2:
				BuildingFittings.crate(k, Vector3(-1.9 + i * 1.2 + (j - 0.5) * 0.55, 0.13 + y * 0.42, -3.6), Vector3(0.52, 0.4, 0.92), (Color(0.3, 0.33, 0.2) if team != 1 else Color(0.45, 0.35, 0.22)).darkened(rng.randf_range(0.0, 0.1)), rng.randf_range(-0.05, 0.05), "paint")
	var drum_col := Color(0.3, 0.33, 0.24) if team != 1 else Color(0.45, 0.17, 0.12)
	for i in 4:
		BuildingFittings.drum(k, Vector3(2.0 + (i % 2) * 0.62, 0, -4.0 + floorf(i / 2.0) * 0.62), drum_col, false, i * 0.9, "paint")
	for i in 6:
		k.box(Vector3(0.17, 0.46, 0.34), Vector3(2.0 + i * 0.2, 0.23, -2.6), "paint", Color(0.27, 0.32, 0.2).darkened(rng.randf_range(0.0, 0.12)), Vector3(0, rng.randf_range(-0.1, 0.1), 0))
	k.box(Vector3(1.6, 0.05, 0.8), Vector3(-0.2, 0.76, -1.0), "wood", Color(0.45, 0.36, 0.24))
	for sx: float in [-0.7, 0.7]:
		for sz: float in [-0.34, 0.34]:
			k.box(Vector3(0.04, 0.74, 0.04), Vector3(-0.2 + sx, 0.37, -1.0 + sz), "steel", STEEL, Vector3.ZERO, false)
	k.plate(Vector3(0.9, 0.01, 0.6), Vector3(-0.35, 0.79, -1.0), "paint", Color(0.82, 0.8, 0.66))
	k.box(Vector3(0.36, 0.22, 0.26), Vector3(0.35, 0.9, -0.95), "paint", Color(0.24, 0.27, 0.2))
	BuildingFittings.whip(k, Vector3(0.45, 1.01, -0.85), 1.6)
	# the flag on its pole in the yard
	var hoist := BuildingFittings.flagpole(k, Vector3(0, 0, 0.2), 8.6, Color(0.7, 0.7, 0.68))
	# along the front: posts and a chain between them, a barrier at the gate
	var posts := [-8.5, -6.0, -3.5, -1.5, 1.5, 3.5, 6.0, 8.5]
	for i in posts.size():
		var x: float = posts[i]
		k.box(Vector3(0.12, 0.9, 0.12), Vector3(x, 0.45, -size.z * 0.5 - 0.4), "paint", Color(0.85, 0.84, 0.8) if i % 2 == 0 else Color(0.75, 0.15, 0.12))
		if i + 1 < posts.size() and not (x < 0.0 and float(posts[i + 1]) > 0.0):
			BuildingWire.cable(k, Vector3(x, 0.8, -size.z * 0.5 - 0.4), Vector3(float(posts[i + 1]), 0.8, -size.z * 0.5 - 0.4), 0.18, 0.018, "metal_dark", Color(0.2, 0.2, 0.2))
	boom(k.at_point(Vector3(-1.5, 0, -size.z * 0.5 - 0.4)), 3.0, rng.randf() < 0.5, flag_col)
	return hoist


## The camouflage net over an HQ's yard (compound draws its poles), a node of
## its own under `root`: netting has its own shader, which doesn't bake.
static func net(root: Node3D, team: int) -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(7.4, 6.6)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	mi.mesh = plane
	mi.material_override = Mats.netting()
	Mats.set_inst(mi, &"tint", Color(0.3, 0.34, 0.2) if team != 1 else Color(0.44, 0.39, 0.27))
	mi.position = Vector3(0, 3.2, -2.1)
	root.add_child(mi)
