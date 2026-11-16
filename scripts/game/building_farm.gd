class_name BuildingFarm
extends RefCounted
## A farm's working kit. In the barn (its floor's kit, centred on the barn:
## Structure's floor, variant 2): small bales stacked in a back corner and a
## few pulled down off the stack, stalls along the rest of the back wall with
## their mangers and hay racks, a cart in the middle, a workbench along one
## end with a barrow and the churns, feed sacks and a bin along the other; all
## of it clear of the wall the door is in, none of it within reach of a wall
## above 1.45 m. On the barn's walls the tools hung on a batten over it all,
## above 1.5 m. Round the yard (Decor, each in a kit at its foot, its front to
## -z): a water trough, a plough and a harrow put away by the barn, a churn
## stand at the gate, a hen house with its run and its hens, a wheelbarrow.
## Looks only, like the houses' furniture; in the barn in world-space
## materials, so its walls and floor still draw together.

const FLOOR := 0.06
const STRAW := Color(0.74, 0.63, 0.36)
const TWINE := Color(0.78, 0.4, 0.12)
const BOARD := Color(0.45, 0.36, 0.25)
const RUST := Color(0.4, 0.23, 0.13)
const GALV := Color(0.62, 0.63, 0.61)
## The makers' paints on carts and implements, faded.
const PAINTS := [Color(0.6, 0.2, 0.13), Color(0.22, 0.36, 0.52), Color(0.78, 0.58, 0.2), Color(0.27, 0.42, 0.26)]
const SACKING := Color(0.66, 0.58, 0.44)
## Bale wrap: black, white, green.
const WRAP := [Color(0.06, 0.06, 0.06), Color(0.84, 0.85, 0.83), Color(0.2, 0.3, 0.19)]
## A small bale: long along x.
const BALE := Vector3(0.9, 0.36, 0.46)
## Nothing on the floor within reach of a wall rises above this, and nothing
## hung on a wall comes down below TOOLS: the two never meet.
const LOW := 1.45
const TOOLS := 1.5


## A barn's floor `size` fitted out, `entry` the wall its door is in (0 the
## front, -z; 1 the back; 2 the -x end; 3 the +x end; -1 the front): turned
## so that wall is at -z, and nothing within 2.3 m of it.
static func barn(k: BuildingKit, size: Vector3, entry: int, rng: RandomNumberGenerator) -> void:
	var across := entry == 2 or entry == 3
	var turn := 0.0
	match entry:
		1:
			turn = PI
		2:
			turn = PI * 0.5
		3:
			turn = -PI * 0.5
	var s := k.at_point(Vector3(0, FLOOR, 0), Vector3(0, turn, 0))
	var hx := (size.z if across else size.x) * 0.5 - 0.2  # (the walls' inner faces)
	var hz := (size.x if across else size.z) * 0.5 - 0.2
	var front := -hz + 2.3
	var e := 1.0 if rng.randf() < 0.5 else -1.0
	# the hay, stacked in the back corner at the e end; a few bales pulled
	# down in front of it, one broken open; a fork left stuck in the top
	var mw := clampf(hx * 0.45, 2.0, 3.0)
	var md := clampf(hz * 0.55, 1.9, 2.8)
	var mx := e * (hx - mw * 0.5)
	var layers := hay_stack(s.at_point(Vector3(mx, 0, hz - md * 0.5)), mw, md, rng)
	for i in rng.randi_range(1, 3):
		var lp := Vector3(clampf(mx + rng.randf_range(-0.35, 0.35) * mw, -hx + 0.55, hx - 0.55), 0, hz - md - rng.randf_range(0.5, 1.0))
		bale(s, lp, rng.randf() * TAU, rng.randf() < 0.25, true, rng)
	if rng.randf() < 0.6:
		var sp := Vector3(mx - e * rng.randf_range(0.6, 1.2), 0.012, hz - md - rng.randf_range(0.4, 1.0))
		for i in 3:
			s.block(Vector3(rng.randf_range(0.6, 1.1), 0.02, rng.randf_range(0.4, 0.7)), sp + Vector3(rng.randf_range(-0.3, 0.3), i * 0.008, rng.randf_range(-0.2, 0.2)), "canvas", STRAW.darkened(rng.randf_range(0.0, 0.15)), Vector3(0, rng.randf() * TAU, 0), false)
	if rng.randf() < 0.45:
		# (in the step below the top layer, out of reach of the walls)
		var fp := Vector3(mx + rng.randf_range(-0.25, 0.25) * mw - e * 0.2, (layers - 1) * BALE.y - 0.15, hz - md + (layers - 2) * 0.45 + 0.2)
		fork(s, fp, fp + Vector3(-e * 0.35, 1.25, -0.3))
	# stalls along the rest of the back wall, from the far end
	var pd := clampf(hz * 0.5, 2.2, 2.8)
	var avail := hx * 2.0 - mw - 0.6
	var n := mini(int(avail / 2.4), 4)
	if n > 0:
		var sw := minf(2.8, avail / n)
		for i in n:
			stall(s, -e * hx + e * (i + 0.5) * sw, hz, sw, pd, e, i == 0, rng)
	# the cart in the middle, its shafts down on the floor (pointing away
	# from the hay: it was backed in to be loaded)
	var cz0 := front + 1.6
	var cz1 := hz - pd - 1.8
	if cz1 > cz0 and rng.randf() < 0.75:
		var cx := -e * rng.randf_range(0.0, maxf(0.0, hx - 3.6))
		cart(s.at_point(Vector3(cx, 0, rng.randf_range(cz0, cz1)), Vector3(0, (PI if e > 0.0 else 0.0) + rng.randf_range(-0.15, 0.15), 0)), rng)
	# along the far end (-e; its kit's x runs along the wall, -e * z): the
	# barrow, the bench, the churns, from the door's side to the stalls
	var far := s.at_point(Vector3(-e * hx, 0, 0), Vector3(0, e * PI * 0.5, 0))
	var z := front
	var z1 := hz - pd - 0.25
	if z1 - z >= 4.4:
		barrow(far.at_point(Vector3(-e * (z + 0.82), 0, 0.46), Vector3(0, PI * 0.5 + rng.randf_range(-0.1, 0.1), 0)), rng.randi() % PAINTS.size())
		z += 1.6
	if z1 - z >= 2.0:
		bench(far.at_point(Vector3(-e * (z + 0.95), 0, 0)), rng)
		z += 2.1
	var churns := mini(int((z1 - z) / 0.42), rng.randi_range(2, 4))
	for i in churns:
		churn(far, Vector3(-e * (z + 0.22 + i * 0.42), 0, 0.24 + rng.randf_range(0.0, 0.08)), i == 2 and rng.randf() < 0.35)
	# along the near end (e; its kit's x is e * z): sacks on a pallet, a bin
	var near := s.at_point(Vector3(e * hx, 0, 0), Vector3(0, -e * PI * 0.5, 0))
	var zn := hz - md - 1.3  # (short of the bales pulled down)
	if zn - front >= 1.3:
		sacks(near.at_point(Vector3(e * (front + 0.65), 0, 0.56)), rng)
	if zn - front >= 2.1:
		near.cyl(0.29, 0.27, 0.72, Vector3(e * (front + 1.65), 0.36, 0.36), "galvanised", GALV, Vector3.ZERO, 14)
		near.cyl(0.31, 0.31, 0.04, Vector3(e * (front + 1.65), 0.74, 0.36), "galvanised", GALV.darkened(0.1), Vector3(rng.randf_range(-0.1, 0.1), 0, 0), 14)


## Small bales stacked `w` across and `d` deep (the kit at the stack's
## middle, its back at +z): each layer laid the other way to the one under it
## (so they bind) and set back from it, the top one part taken. Returns how
## many layers.
static func hay_stack(k: BuildingKit, w: float, d: float, rng: RandomNumberGenerator) -> int:
	var layers := rng.randi_range(3, int(LOW / BALE.y))
	for i in layers:
		var deep := d - i * 0.45
		var along := i % 2 == 0
		var bx := BALE.x + 0.02 if along else BALE.z + 0.01
		var bz := BALE.z + 0.01 if along else BALE.x + 0.02
		var nx := int((w - 0.1) / bx)
		var nz := int(deep / bz)
		var top := i == layers - 1
		for a in nx:
			for b in nz:
				if top and rng.randf() < 0.35:
					continue
				var p := Vector3((a + 0.5 - nx * 0.5) * bx + rng.randf_range(-0.03, 0.03), i * BALE.y, d * 0.5 - 0.05 - (b + 0.5) * bz)
				# (the twine shows on the top layer and the front of each)
				bale(k, p, (0.0 if along else PI * 0.5) + rng.randf_range(-0.05, 0.05), false, top or b == nz - 1, rng)
	return layers


## A small bale standing at `p` (its foot), turned `yaw`, or `on_side`; the
## orange twine round it where it shows.
static func bale(k: BuildingKit, p: Vector3, yaw: float, on_side: bool, twine: bool, rng: RandomNumberGenerator) -> void:
	var b := k.at_point(p, Vector3(0, yaw, 0))
	var sz := Vector3(BALE.x, BALE.z, BALE.y) if on_side else BALE
	b.block(sz, Vector3(0, sz.y * 0.5, 0), "canvas", STRAW.darkened(rng.randf_range(0.0, 0.16)))
	if twine:
		for t: float in [-0.24, 0.24]:
			b.block(Vector3(0.02, 0.006, sz.z + 0.008), Vector3(t, sz.y + 0.002, 0), "paint", TWINE, Vector3.ZERO, false)


## A hay fork from `a` (its tines, in the hay) to the end of its handle `b`.
static func fork(k: BuildingKit, a: Vector3, b: Vector3) -> void:
	var d := (b - a).normalized()
	k.rod(a + d * 0.25, b, 0.016, "wood", Color(0.55, 0.45, 0.3))
	k.rod(a, a + d * 0.3, 0.02, "metal_dark", Color(0.2, 0.2, 0.2))


## A stall `sw` wide and `pd` deep against the back wall (its face at `hz`,
## the stall toward -z) on `cx`: the boarded partition at its `e` end (at its
## other the stall before's, or the end wall `at_wall`), the rail along its
## front with a gate shut or swung in, the manger along the wall with a hay
## rack over it, a bucket, fresh straw.
static func stall(k: BuildingKit, cx: float, hz: float, sw: float, pd: float, e: float, at_wall: bool, rng: RandomNumberGenerator) -> void:
	var z0 := hz - pd
	var wood := BOARD.darkened(rng.randf_range(0.0, 0.15))
	k.part(_partition(pd), "wood", Transform3D(Basis.IDENTITY, Vector3(cx + e * sw * 0.5, 0, hz - pd * 0.5)), wood)
	if at_wall:
		k.box(Vector3(0.12, 1.35, 0.12), Vector3(cx - e * (sw * 0.5 - 0.06), 0.675, z0 + 0.06), "wood", wood.darkened(0.1))
	k.part(_stall_front(sw), "wood", Transform3D(Basis.IDENTITY, Vector3(cx, 0, z0 + 0.06)), wood)
	var swing := 0.0 if rng.randf() < 0.45 else rng.randf_range(0.5, 1.4)
	k.part(BuildingKit.shape("stall_gate", func() -> Array:
		var pieces := []
		for x: float in [0.04, 0.92]:
			pieces.append(BuildingKit.piece(Vector3(0.07, 1.1, 0.06), Vector3(x, 0.66, 0)))
		for y: float in [0.2, 0.66, 1.16]:
			pieces.append(BuildingKit.piece(Vector3(0.95, 0.09, 0.04), Vector3(0.48, y, 0)))
		pieces.append([BuildingKit.plain(Vector3(1.25, 0.08, 0.035)), Transform3D(Basis(Vector3.BACK, 0.82), Vector3(0.48, 0.68, 0.012))])
		return pieces), "wood", Transform3D(Basis(Vector3.UP, -swing), Vector3(cx - 0.5, 0, z0 + 0.06)), wood.lightened(0.06))
	k.part(_manger(snappedf(sw - 0.5, 0.1)), "wood", Transform3D(Basis.IDENTITY, Vector3(cx, 0, hz)), wood.darkened(0.08))
	if rng.randf() < 0.5:
		k.cyl(0.14, 0.12, 0.3, Vector3(cx + rng.randf_range(-0.4, 0.4) * sw, 0.15, hz - rng.randf_range(0.7, 1.2)), "galvanised", GALV, Vector3.ZERO, 12)
	for i in 2:
		k.block(Vector3(rng.randf_range(0.7, 1.1), 0.02, rng.randf_range(0.45, 0.7)), Vector3(cx + rng.randf_range(-0.15, 0.15) * sw, 0.012 + i * 0.006, hz - rng.randf_range(0.8, pd - 0.5)), "canvas", STRAW.darkened(rng.randf_range(0.05, 0.25)), Vector3(0, rng.randf() * TAU, 0), false)


## (a stall's partition `pd` long: its post at the front, -z; the boards
## nailed to it run back to the wall)
static func _partition(pd: float) -> ArrayMesh:
	return BuildingKit.shape("partition|%.2f" % pd, func() -> Array:
		var pieces := [BuildingKit.piece(Vector3(0.12, 1.35, 0.12), Vector3(0, 0.675, -pd * 0.5 + 0.06))]
		for j in 4:
			pieces.append(BuildingKit.piece(Vector3(0.04, 0.2, pd - 0.12), Vector3(0, 0.2 + j * 0.29, 0.06)))
		pieces.append(BuildingKit.piece(Vector3(0.08, 0.05, pd), Vector3(0, 1.32, 0)))
		return pieces)


## (a stall's front `sw` across: two rails each side of the gateway, the
## gate's posts)
static func _stall_front(sw: float) -> ArrayMesh:
	return BuildingKit.shape("stall_front|%.2f" % sw, func() -> Array:
		var pieces := []
		var len := sw * 0.5 - 0.6
		for side: float in [-1.0, 1.0]:
			for y: float in [0.62, 1.12]:
				pieces.append(BuildingKit.piece(Vector3(len, 0.1, 0.05), Vector3(side * (0.6 + len * 0.5), y, 0)))
			pieces.append(BuildingKit.piece(Vector3(0.1, 1.3, 0.1), Vector3(side * 0.55, 0.65, 0)))
		return pieces)


## (a manger `w` long along the wall, the room at -z: the trough on its legs,
## the hay rack over it, its slats leaning out to a rail)
static func _manger(w: float) -> ArrayMesh:
	return BuildingKit.shape("manger|%.1f" % w, func() -> Array:
		var pieces := [BuildingKit.piece(Vector3(w, 0.04, 0.42), Vector3(0, 0.5, -0.23)), BuildingKit.piece(Vector3(w, 0.3, 0.04), Vector3(0, 0.63, -0.44))]
		for sx: float in [-1.0, 1.0]:
			pieces.append(BuildingKit.piece(Vector3(0.04, 0.3, 0.42), Vector3(sx * w * 0.5, 0.63, -0.23)))
			pieces.append(BuildingKit.piece(Vector3(0.08, 0.5, 0.08), Vector3(sx * (w * 0.5 - 0.1), 0.25, -0.4)))
		var rw := minf(w, 1.6)
		pieces.append(BuildingKit.piece(Vector3(rw, 0.06, 0.06), Vector3(0, 1.36, -0.42)))
		var slats := maxi(2, int(rw / 0.16))
		for j in slats + 1:
			pieces.append([BuildingKit.plain(Vector3(0.03, 0.64, 0.03)), Transform3D(Basis(Vector3.RIGHT, -0.64), Vector3(-rw * 0.5 + j * rw / slats, 1.1, -0.23))])
		return pieces)


## A two-wheeled farm cart (the kit at its middle on the floor, its shafts to
## +x and down on the floor): the bed, its sides and tailboard on the axle,
## spoked wheels; a load of bales, or of sacks, or straw left in it.
static func cart(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var col: Color = (PAINTS[rng.randi() % PAINTS.size()] as Color).lerp(BOARD, 0.55)
	k.part(BuildingKit.shape("cart", func() -> Array:
		var pieces := [BuildingKit.piece(Vector3(2.6, 0.06, 1.4), Vector3(0, 0.86, 0)), BuildingKit.piece(Vector3(0.1, 0.1, 1.84), Vector3(0, 0.5, 0))]
		for sz: float in [-1.0, 1.0]:
			pieces.append(BuildingKit.piece(Vector3(2.6, 0.32, 0.04), Vector3(0, 1.05, sz * 0.68)))
			pieces.append(BuildingKit.piece(Vector3(2.7, 0.1, 0.1), Vector3(-0.05, 0.78, sz * 0.5)))
			pieces.append([BuildingKit.plain(Vector3(1.6, 0.08, 0.08)), Transform3D(Basis(Vector3.BACK, -0.44), Vector3(2.0, 0.45, sz * 0.42))])
		for sx: float in [-1.0, 1.0]:
			pieces.append(BuildingKit.piece(Vector3(0.04, 0.32, 1.4), Vector3(sx * 1.28, 1.05, 0)))
		pieces.append(BuildingKit.piece(Vector3(0.08, 0.08, 0.9), Vector3(2.72, 0.1, 0)))
		# (blocks under the bed's tail, for the axle: the wheels bear it)
		pieces.append(BuildingKit.piece(Vector3(0.1, 0.12, 1.0), Vector3(0.0, 0.62, 0)))
		return pieces), "wood", Transform3D.IDENTITY, col)
	k.part(BuildingKit.shape("cart_wheels", func() -> Array:
		var pieces := []
		for sz: float in [-1.0, 1.0]:
			var hub := Vector3(0, 0.5, sz * 0.86)
			pieces.append([BuildingKit.ring(0.44, 0.5), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), hub)])
			pieces.append([Res.cyl(0.09, 0.09, 0.2, 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), hub)])
			for j in 4:
				pieces.append([BuildingKit.plain(Vector3(0.04, 0.9, 0.04)), Transform3D(Basis(Vector3.BACK, j * PI * 0.25), hub)])
		return pieces), "wood", Transform3D.IDENTITY, Color(0.24, 0.2, 0.16))
	match rng.randi() % 3:
		0:
			# a load of bales, two layers
			for y in 2:
				for i in (2 if y == 0 else rng.randi_range(0, 2)):
					bale(k, Vector3(-0.6 + i * 1.1 + rng.randf_range(-0.1, 0.1), 0.89 + y * BALE.y, rng.randf_range(-0.3, 0.3)), rng.randf_range(-0.15, 0.15), false, true, rng)
		1:
			for i in rng.randi_range(2, 5):
				var sp := Vector3(rng.randf_range(-1.0, 1.0), 1.0, rng.randf_range(-0.4, 0.4))
				k.part(Res.sphere(0.24, 8), "canvas", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.7, 0.6, 1.1)), sp), SACKING.darkened(rng.randf_range(0.0, 0.2)), false)
		_:
			k.plate(Vector3(2.2, 0.02, 1.1), Vector3(0, 0.9, 0), "canvas", STRAW.darkened(0.25), Vector3(0, rng.randf_range(-0.1, 0.1), 0))


## A workbench against a wall (the kit at its middle, the wall at z = 0): the
## top, its back board, the shelf under it with a jerrycan and a crate on it;
## a vice at one end, a toolbox and an oil can on top.
static func bench(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	k.part(BuildingKit.shape("workbench", func() -> Array:
		var pieces := [BuildingKit.piece(Vector3(1.8, 0.06, 0.62), Vector3(0, 0.86, 0.33)), BuildingKit.piece(Vector3(1.7, 0.03, 0.55), Vector3(0, 0.2, 0.33)),
			BuildingKit.piece(Vector3(1.8, 0.18, 0.025), Vector3(0, 0.98, 0.02))]
		for sx: float in [-0.82, 0.82]:
			for sz: float in [0.07, 0.58]:
				pieces.append(BuildingKit.piece(Vector3(0.07, 0.83, 0.07), Vector3(sx, 0.415, sz)))
		return pieces), "wood", Transform3D.IDENTITY, BOARD.darkened(0.12))
	var vs := 1.0 if rng.randf() < 0.5 else -1.0
	k.box(Vector3(0.14, 0.12, 0.22), Vector3(vs * 0.72, 0.95, 0.56), "metal_dark", Color(0.2, 0.26, 0.23))
	k.rod(Vector3(vs * 0.62, 0.93, 0.7), Vector3(vs * 0.82, 0.93, 0.7), 0.01, "steel", Color(0.6, 0.6, 0.58))
	k.box(Vector3(0.48, 0.2, 0.22), Vector3(-vs * rng.randf_range(0.2, 0.55), 0.99, 0.28), "paint", PAINTS[rng.randi() % PAINTS.size()])
	k.cyl(0.05, 0.065, 0.16, Vector3(rng.randf_range(-0.3, 0.3), 0.97, 0.45), "metal_dark", Color(0.3, 0.27, 0.2), Vector3.ZERO, 8)
	k.box(Vector3(0.17, 0.46, 0.34), Vector3(rng.randf_range(-0.7, -0.3), 0.445, 0.3), "paint", Color(0.3, 0.33, 0.22))
	k.box(Vector3(0.5, 0.3, 0.4), Vector3(rng.randf_range(0.25, 0.55), 0.365, 0.32), "wood", Color(0.55, 0.44, 0.3), Vector3(0, rng.randf_range(-0.2, 0.2), 0))


## A milk churn standing at `p`, or `tipped` over on its side.
static func churn(k: BuildingKit, p: Vector3, tipped: bool) -> void:
	var xf := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(0, 0.17, -0.19)) if tipped else Transform3D(Basis.IDENTITY, p)
	k.part(BuildingKit.shape("churn", func() -> Array:
		return [[Res.cyl(0.17, 0.17, 0.48, 14), Mats.place(Vector3(0, 0.24, 0))], [Res.cyl(0.08, 0.17, 0.12, 14), Mats.place(Vector3(0, 0.54, 0))],
			[Res.cyl(0.075, 0.075, 0.1, 12), Mats.place(Vector3(0, 0.65, 0))], [Res.cyl(0.095, 0.095, 0.035, 12), Mats.place(Vector3(0, 0.715, 0))],
			[Res.cyl(0.18, 0.18, 0.02, 14), Mats.place(Vector3(0, 0.46, 0))], [Res.cyl(0.18, 0.18, 0.02, 14), Mats.place(Vector3(0, 0.03, 0))]]),
		"galvanised", xf, GALV)


## Sacks of feed on a pallet (the kit at the pallet's middle), in two layers.
static func sacks(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	k.part(BuildingKit.shape("pallet", func() -> Array:
		var pieces := []
		for i in 5:
			pieces.append(BuildingKit.piece(Vector3(1.2, 0.022, 0.14), Vector3(0, 0.133, -0.42 + i * 0.21)))
		for x: float in [-0.52, 0.0, 0.52]:
			pieces.append(BuildingKit.piece(Vector3(0.1, 0.1, 1.0), Vector3(x, 0.07, 0)))
		return pieces), "wood", Transform3D.IDENTITY, Color(0.62, 0.52, 0.38))
	var col := SACKING if rng.randf() < 0.6 else Color(0.86, 0.84, 0.78)
	for y in 2:
		for i in (3 if y == 0 else rng.randi_range(1, 3)):
			var sp := Vector3(rng.randf_range(-0.08, 0.08), 0.26 + y * 0.19, -0.22 + i * 0.22)
			k.part(Res.sphere(0.24, 8), "canvas", Transform3D(Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.2, 0.2)).scaled(Vector3(1.8, 0.62, 1.15)), sp), col.darkened(rng.randf_range(0.0, 0.18)), false)


## A wheelbarrow (the kit at its middle, its wheel to -z): the steel pan on
## its frame, the handles back to +z, the wheel and legs; `paint` its colour.
static func barrow(k: BuildingKit, paint: int) -> void:
	var col: Color = (PAINTS[paint % PAINTS.size()] as Color).lerp(RUST, 0.25)
	k.part(BuildingKit.shape("barrow_pan", func() -> Array:
		var pieces := [BuildingKit.piece(Vector3(0.44, 0.03, 0.5), Vector3(0, 0.36, -0.05))]
		for sx: float in [-1.0, 1.0]:
			pieces.append([BuildingKit.plain(Vector3(0.03, 0.3, 0.62)), Transform3D(Basis(Vector3.BACK, sx * 0.35), Vector3(sx * 0.27, 0.5, -0.05))])
		pieces.append([BuildingKit.plain(Vector3(0.6, 0.32, 0.03)), Transform3D(Basis(Vector3.RIGHT, -0.75), Vector3(0, 0.5, -0.42))])
		pieces.append([BuildingKit.plain(Vector3(0.6, 0.28, 0.03)), Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 0.5, 0.27))])
		return pieces), "paint", Transform3D.IDENTITY, col)
	k.part(BuildingKit.shape("barrow_frame", func() -> Array:
		var pieces := []
		for sx: float in [-1.0, 1.0]:
			pieces.append([BuildingKit.plain(Vector3(0.035, 0.035, 1.3)), Transform3D(Basis(Vector3.RIGHT, 0.1), Vector3(sx * 0.2, 0.36, 0.08))])
			pieces.append(BuildingKit.piece(Vector3(0.03, 0.34, 0.03), Vector3(sx * 0.18, 0.17, 0.22)))
		pieces.append([Res.cyl(0.02, 0.02, 0.4, 6), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.18, -0.58))])
		return pieces), "metal_dark", Transform3D.IDENTITY, Color(0.18, 0.18, 0.17))
	k.cyl(0.18, 0.18, 0.08, Vector3(0, 0.18, -0.58), "rubber", Color(0.08, 0.08, 0.08), Vector3(0, 0, PI * 0.5), 12)


## The tools hung on a barn wall `length` long (its room kit: x along it, +z
## into the barn), nailed to a batten above TOOLS: a scythe, a hay rake, a
## fork, a coil of rope, a horse collar, a bow saw, a lantern; whatever fits
## between the wall's ends, a few to a wall.
static func wall_tools(k: BuildingKit, length: float, rng: RandomNumberGenerator) -> void:
	const REACH := 0.65
	var room := length - REACH * 2.0
	if room < 0.4:
		return
	var picks := []
	var x := -room * 0.5
	for i in rng.randi_range(1, 3):
		var kind := rng.randi() % 7
		var w: float = [1.25, 1.2, 1.15, 0.36, 0.56, 0.66, 0.26][kind]
		if x + w > room * 0.5:
			kind = 3 if x + 0.36 <= room * 0.5 else -1
			w = 0.36
		if kind < 0:
			break
		picks.append([kind, x + w * 0.5])
		x += w + rng.randf_range(0.1, 0.3)
	if picks.is_empty():
		return
	var y := 1.95
	var x0 := maxf(float(picks[0][1]) - 0.7, -room * 0.5)
	var x1 := minf(float(picks[-1][1]) + 0.7, room * 0.5)
	k.box(Vector3(x1 - x0, 0.09, 0.025), Vector3((x0 + x1) * 0.5, y, 0.0125), "wood", BOARD.darkened(0.2))
	var handle := Color(0.55, 0.45, 0.3)
	var iron := Color(0.22, 0.21, 0.2)
	for pk: Array in picks:
		var at: float = pk[1]
		match int(pk[0]):
			0:
				# a scythe: its snath on two pegs, the blade hanging under it
				k.rod(Vector3(at - 0.6, y + 0.06, 0.05), Vector3(at + 0.6, y - 0.02, 0.05), 0.016, "wood", handle)
				k.rod(Vector3(at - 0.15, y + 0.04, 0.05), Vector3(at - 0.15, y + 0.2, 0.09), 0.012, "wood", handle)
				k.box(Vector3(0.7, 0.07, 0.006), Vector3(at + 0.28, y - 0.24, 0.05), "steel", Color(0.5, 0.5, 0.48), Vector3(0, 0, 0.45))
			1:
				# a wooden hay rake, its head up
				k.rod(Vector3(at - 0.48, y + 0.08, 0.04), Vector3(at + 0.58, y + 0.08, 0.04), 0.014, "wood", handle)
				k.box(Vector3(0.04, 0.5, 0.04), Vector3(at - 0.5, y + 0.08, 0.05), "wood", handle.darkened(0.1))
				for j in 6:
					k.rod(Vector3(at - 0.5, y - 0.14 + j * 0.088, 0.05), Vector3(at - 0.59, y - 0.14 + j * 0.088, 0.05), 0.006, "wood", handle.lightened(0.1), 4, false)
			2:
				# a fork
				k.rod(Vector3(at - 0.56, y + 0.08, 0.04), Vector3(at + 0.34, y + 0.08, 0.04), 0.015, "wood", handle)
				for j in 3:
					k.rod(Vector3(at + 0.34, y + 0.04 + j * 0.04, 0.04), Vector3(at + 0.55, y + 0.02 + j * 0.06, 0.05), 0.006, "metal_dark", iron, 4, false)
			3:
				# a coil of rope on a nail
				k.part(BuildingKit.ring(0.11, 0.16), "canvas", Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.0, 1.2, 1.0)), Vector3(at, y - 0.18, 0.04)), Color(0.62, 0.55, 0.4))
			4:
				# a horse collar, the harness left with it
				k.part(BuildingKit.ring(0.14, 0.22), "canvas", Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.0, 1.3, 1.0)), Vector3(at, y - 0.05, 0.06)), Color(0.3, 0.19, 0.11))
				k.box(Vector3(0.05, 0.3, 0.02), Vector3(at + 0.12, y - 0.1, 0.03), "canvas", Color(0.24, 0.16, 0.1))
			5:
				# a bow saw
				k.rod(Vector3(at - 0.3, y - 0.05, 0.03), Vector3(at + 0.3, y - 0.05, 0.03), 0.004, "steel", Color(0.55, 0.55, 0.52), 4, false)
				k.rod(Vector3(at - 0.31, y - 0.05, 0.03), Vector3(at, y + 0.12, 0.03), 0.012, "metal_dark", Color(0.55, 0.15, 0.1), 6)
				k.rod(Vector3(at, y + 0.12, 0.03), Vector3(at + 0.31, y - 0.05, 0.03), 0.012, "metal_dark", Color(0.55, 0.15, 0.1), 6)
			6:
				# a storm lantern on a nail
				k.cyl(0.06, 0.07, 0.04, Vector3(at, y - 0.3, 0.08), "metal_dark", Color(0.6, 0.12, 0.1), Vector3.ZERO, 10)
				k.cyl(0.05, 0.05, 0.14, Vector3(at, y - 0.2, 0.08), "glass", Color(0.8, 0.78, 0.7), Vector3.ZERO, 10, false)
				k.cyl(0.03, 0.065, 0.05, Vector3(at, y - 0.105, 0.08), "metal_dark", Color(0.6, 0.12, 0.1), Vector3.ZERO, 10)


# --- the yard -------------------------------------------------------------------------

## Round bales in a row along x (the kit at the row's middle), `count` of
## them and, on three, one more up on top: straw, its rolled end showing in
## rings; or wrapped in plastic for silage, black, white or green, a stack
## all the same.
static func round_bales(k: BuildingKit, count: int, rng: RandomNumberGenerator) -> void:
	var wrapped := rng.randf() < 0.35
	var wrap: Color = WRAP[rng.randi() % WRAP.size()]
	for i in count:
		round_bale(k, Vector3((i - (count - 1) * 0.5) * 1.35, 0.65, 0), wrapped, wrap, rng)
	if count >= 3:
		round_bale(k, Vector3(0, 1.85, 0), wrapped, wrap, rng)


## A round bale lying with its axis along x, its middle at `c`.
static func round_bale(k: BuildingKit, c: Vector3, wrapped: bool, wrap: Color, rng: RandomNumberGenerator) -> void:
	var b := k.at_point(c, Vector3(0, 0, PI * 0.5))
	if wrapped:
		b.cyl(0.66, 0.66, 1.12, Vector3.ZERO, "paint", wrap.lightened(rng.randf_range(0.0, 0.05)), Vector3.ZERO, 18)
		for sy: float in [-1.0, 1.0]:
			b.cyl(0.6 if sy > 0.0 else 0.66, 0.66 if sy > 0.0 else 0.6, 0.05, Vector3(0, sy * 0.585, 0), "paint", wrap, Vector3.ZERO, 18)
		return
	var tone := STRAW.darkened(rng.randf_range(0.0, 0.15))
	b.cyl(0.65, 0.65, 1.2, Vector3.ZERO, "canvas", tone, Vector3.ZERO, 18)
	for sy: float in [-1.0, 1.0]:
		# (the rolled end: rings of it round a tight core)
		b.cyl(0.62, 0.62, 0.012, Vector3(0, sy * 0.603, 0), "canvas", tone.darkened(0.16), Vector3.ZERO, 18, false)
		b.cyl(0.45, 0.45, 0.012, Vector3(0, sy * 0.607, 0), "canvas", tone.lightened(0.08), Vector3.ZERO, 16, false)
		b.cyl(0.25, 0.25, 0.012, Vector3(0, sy * 0.611, 0), "canvas", tone.darkened(0.08), Vector3.ZERO, 12, false)
		b.cyl(0.08, 0.08, 0.012, Vector3(0, sy * 0.615, 0), "canvas", tone.darkened(0.25), Vector3.ZERO, 8, false)


## A water trough (along x): galvanised on bricks, its rolled rim, the ball
## valve's box at one end and its pipe up out of the ground; or cast in
## concrete. Water in it.
static func trough(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.35:
		k.box(Vector3(1.9, 0.08, 0.6), Vector3(0, 0.04, 0), "concrete", Color(0.6, 0.58, 0.54))
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(1.9, 0.55, 0.09), Vector3(0, 0.275, sz * 0.255), "concrete", Color(0.6, 0.58, 0.54))
		for sx: float in [-1.0, 1.0]:
			k.box(Vector3(0.09, 0.55, 0.42), Vector3(sx * 0.905, 0.275, 0), "concrete", Color(0.58, 0.56, 0.52))
		k.plate(Vector3(1.72, 0.01, 0.42), Vector3(0, 0.44, 0), "plain_dark", Color(0.08, 0.11, 0.1))
		return
	for x: float in [-0.65, 0.65]:
		k.box(Vector3(0.22, 0.1, 0.55), Vector3(x, 0.05, 0), "concrete", Color(0.55, 0.32, 0.24))
	k.box(Vector3(1.9, 0.03, 0.56), Vector3(0, 0.12, 0), "galvanised", GALV)
	for sz: float in [-1.0, 1.0]:
		k.box(Vector3(1.9, 0.5, 0.02), Vector3(0, 0.35, sz * 0.28), "galvanised", GALV)
		k.rod(Vector3(-0.95, 0.6, sz * 0.285), Vector3(0.95, 0.6, sz * 0.285), 0.018, "galvanised", GALV.lightened(0.05))
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.02, 0.5, 0.56), Vector3(sx * 0.94, 0.35, 0), "galvanised", GALV)
	k.plate(Vector3(1.86, 0.01, 0.54), Vector3(0, 0.52, 0), "plain_dark", Color(0.08, 0.11, 0.1))
	k.box(Vector3(0.3, 0.2, 0.56), Vector3(0.8, 0.7, 0), "galvanised", GALV.darkened(0.1))
	k.rod(Vector3(1.0, 0.0, 0.2), Vector3(1.0, 0.65, 0.2), 0.02, "metal_dark", Color(0.2, 0.2, 0.2))


## A plough put away (along x, its hitch to -x): the frame and its mast, two
## or three bodies along the beam, their mouldboards worn bright, the depth
## wheel, the parking stand.
static func plough(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var col: Color = (PAINTS[rng.randi() % PAINTS.size()] as Color).lerp(RUST, rng.randf_range(0.2, 0.6))
	var b := k.at_point(Vector3.ZERO, Vector3(0, 0.22, 0))
	b.box(Vector3(2.2, 0.12, 0.12), Vector3(0.1, 0.72, 0), "paint", col)
	b.box(Vector3(0.12, 0.12, 0.8), Vector3(-1.0, 0.72, 0), "paint", col)
	for sz: float in [-0.35, 0.35]:
		b.rod(Vector3(-1.0, 0.72, sz), Vector3(-1.05, 1.15, 0), 0.03, "paint", col)
	b.box(Vector3(0.08, 0.5, 0.08), Vector3(-1.15, 0.47, 0), "metal_dark", col.darkened(0.3))
	var bodies := rng.randi_range(2, 3)
	for i in bodies:
		var x := -0.55 + i * 0.7
		# the leg down from the beam, the frog on it; the share along the
		# ground, the mouldboard sweeping up and over from it (in two plates,
		# the lower steeper), worn bright where the soil runs
		b.box(Vector3(0.1, 0.5, 0.1), Vector3(x, 0.45, 0), "paint", col, Vector3(0, 0, 0.3))
		b.box(Vector3(0.36, 0.22, 0.14), Vector3(x - 0.04, 0.16, 0.0), "metal_dark", col.darkened(0.35))
		b.box(Vector3(0.42, 0.025, 0.2), Vector3(x - 0.16, 0.035, 0.08), "steel", Color(0.6, 0.6, 0.58), Vector3(0, 0.55, 0))
		b.box(Vector3(0.5, 0.26, 0.025), Vector3(x + 0.05, 0.16, 0.2), "steel", Color(0.64, 0.64, 0.62), Vector3(0.55, 0.62, 0.1))
		b.box(Vector3(0.46, 0.2, 0.025), Vector3(x + 0.26, 0.36, 0.33), "steel", Color(0.62, 0.62, 0.6), Vector3(0.95, 0.85, 0.2))
	b.cyl(0.28, 0.28, 0.1, Vector3(1.05, 0.28, 0.32), "rubber", Color(0.08, 0.08, 0.08), Vector3(PI * 0.5, 0, 0), 14)
	b.box(Vector3(0.06, 0.45, 0.06), Vector3(1.05, 0.55, 0.22), "paint", col)


## A harrow lying flat (along x): its frame of bars, the tines under it.
static func harrow(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var col: Color = (PAINTS[rng.randi() % PAINTS.size()] as Color).lerp(RUST, rng.randf_range(0.3, 0.7))
	k.part(BuildingKit.shape("harrow", func() -> Array:
		var pieces := []
		for i in 4:
			pieces.append(BuildingKit.piece(Vector3(2.0, 0.06, 0.06), Vector3(0, 0.18, -0.75 + i * 0.5)))
		for i in 3:
			pieces.append(BuildingKit.piece(Vector3(0.06, 0.06, 1.6), Vector3(-0.9 + i * 0.9, 0.24, 0)))
		for i in 4:
			for j in 6:
				pieces.append(BuildingKit.piece(Vector3(0.025, 0.16, 0.025), Vector3(-0.9 + j * 0.36, 0.08, -0.75 + i * 0.5)))
		pieces.append(BuildingKit.piece(Vector3(0.5, 0.05, 0.05), Vector3(-1.2, 0.18, 0)))
		return pieces), "paint", Transform3D.IDENTITY, col)


## A churn stand at the gate (along x, the road at -z): a deck of boards on
## four posts at the height of a lorry's bed, churns on it, one or two
## waiting beside it.
static func churn_stand(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	k.part(BuildingKit.shape("churn_stand", func() -> Array:
		var pieces := []
		for i in 5:
			pieces.append(BuildingKit.piece(Vector3(1.5, 0.05, 0.17), Vector3(0, 0.9, -0.36 + i * 0.18)))
		for sx: float in [-0.68, 0.68]:
			for sz: float in [-0.36, 0.36]:
				pieces.append(BuildingKit.piece(Vector3(0.11, 0.88, 0.11), Vector3(sx, 0.44, sz)))
			pieces.append(BuildingKit.piece(Vector3(0.08, 0.08, 0.86), Vector3(sx, 0.82, 0)))
		return pieces), "wood", Transform3D.IDENTITY, BOARD.darkened(rng.randf_range(0.0, 0.2)))
	for i in rng.randi_range(2, 4):
		churn(k, Vector3(-0.5 + i * 0.36 + rng.randf_range(-0.03, 0.03), 0.925, rng.randf_range(-0.12, 0.12)), false)
	for i in rng.randi_range(0, 2):
		churn(k, Vector3((1.0 if i == 0 else -1.0) * rng.randf_range(0.98, 1.06), 0, rng.randf_range(-0.2, 0.1)), rng.randf() < 0.3)


## A hen house on its legs (at -x) with its run (to +x) of wire netting on
## posts, the hens in it and a couple out.
static func hen_house(k: BuildingKit, rng: RandomNumberGenerator) -> void:
	var col: Color = [Color(0.45, 0.33, 0.22), Color(0.36, 0.4, 0.3), Color(0.62, 0.3, 0.2)][rng.randi() % 3]
	var hk := k.at_point(Vector3(-1.1, 0, 0))
	hk.part(BuildingKit.shape("hen_house", func() -> Array:
		var pieces := [BuildingKit.piece(Vector3(1.1, 0.72, 0.95), Vector3(0, 0.81, 0)), BuildingKit.piece(Vector3(0.5, 0.36, 0.34), Vector3(-0.2, 0.75, 0.62))]
		for sx: float in [-0.46, 0.46]:
			for sz: float in [-0.38, 0.38]:
				pieces.append(BuildingKit.piece(Vector3(0.07, 0.45, 0.07), Vector3(sx, 0.225, sz)))
		pieces.append([BuildingKit.plain(Vector3(0.95, 0.03, 0.32)), Transform3D(Basis(Vector3.BACK, -0.42), Vector3(0.98, 0.25, -0.2))])
		return pieces), "wood", Transform3D.IDENTITY, col)
	hk.prism(Vector3(1.15, 0.32, 1.3), Vector3(0, 1.33, 0), "plain_dark", Color(0.12, 0.12, 0.12), Vector3(0, PI * 0.5, 0))
	hk.box(Vector3(0.02, 0.26, 0.2), Vector3(0.56, 0.62, -0.2), "plain_dark", Color(0.05, 0.05, 0.05))
	# the run: posts at its corners, netting round three sides
	var x0 := -0.55
	var x1 := 1.85
	var hz := 0.8
	for p: Vector2 in [Vector2(x0, -hz), Vector2(x1, -hz), Vector2(x1, hz), Vector2(x0, hz), Vector2((x0 + x1) * 0.5, -hz), Vector2((x0 + x1) * 0.5, hz)]:
		k.cyl(0.03, 0.035, 1.15, Vector3(p.x, 0.575, p.y), "wood", Color(0.45, 0.38, 0.28), Vector3.ZERO, 6)
	for sz: float in [-1.0, 1.0]:
		BuildingFences.mesh_panel(k, x1 - x0, 0.0, 1.1, Vector3((x0 + x1) * 0.5, 0, sz * hz), Color(0.55, 0.56, 0.55), false)
	BuildingFences.mesh_panel(k.at_point(Vector3(x1, 0, 0), Vector3(0, PI * 0.5, 0)), hz * 2.0, 0.0, 1.1, Vector3.ZERO, Color(0.55, 0.56, 0.55), false)
	var hens: Color = [Color(0.88, 0.86, 0.8), Color(0.55, 0.3, 0.15), Color(0.15, 0.14, 0.13)][rng.randi() % 3]
	for i in rng.randi_range(3, 6):
		var out := i >= 4
		var hp := Vector3(rng.randf_range(x0 + 0.3, x1 - 0.2), 0, rng.randf_range(-hz + 0.2, hz - 0.2))
		if out:
			hp = Vector3(rng.randf_range(x0, x1), 0, -hz - rng.randf_range(0.3, 0.8))
		hen(k, hp, rng.randf() * TAU, hens.darkened(rng.randf_range(0.0, 0.15)), rng.randf() < 0.5)


## A hen at `p` facing `yaw` (-z), her head down pecking or up.
static func hen(k: BuildingKit, p: Vector3, yaw: float, col: Color, pecking: bool) -> void:
	var h := k.at_point(p, Vector3(0, yaw, 0))
	h.part(Res.sphere(0.1, 8), "canvas", Transform3D(Basis.from_scale(Vector3(0.95, 0.9, 1.35)), Vector3(0, 0.2, 0)), col)
	h.box(Vector3(0.1, 0.12, 0.06), Vector3(0, 0.29, 0.13), "canvas", col.darkened(0.1), Vector3(-0.5, 0, 0))
	var head := Vector3(0, 0.14, -0.17) if pecking else Vector3(0, 0.33, -0.13)
	h.part(Res.sphere(0.045, 6), "canvas", Transform3D(Basis.IDENTITY, head), col)
	h.box(Vector3(0.015, 0.035, 0.04), head + Vector3(0, 0.045, 0), "paint", Color(0.75, 0.1, 0.08), Vector3.ZERO, false)
	h.box(Vector3(0.02, 0.02, 0.04), head + Vector3(0, -0.005, -0.05), "paint", Color(0.85, 0.65, 0.2), Vector3.ZERO, false)
	for sx: float in [-0.04, 0.04]:
		h.box(Vector3(0.012, 0.11, 0.012), Vector3(sx, 0.055, 0.01), "paint", Color(0.85, 0.65, 0.2), Vector3.ZERO, false)
