class_name VehicleCargo
extends RefCounted
## Supports and restraints use declared load bounds; the load and any draped
## cover remain owned by the family and VehicleCloth.

const X90 := Vector3(PI / 2, 0, 0)

static func pallet(k: VehicleModels, parent: Node3D, base: Vector3, size: Vector2, height := 0.1) -> void:
	for side: float in [-1.0, 0.0, 1.0]:
		for z: float in [-0.37, 0.0, 0.37]:
			k._box(parent, Vector3(size.x * 0.13, height * 0.50, size.y * 0.23), base + Vector3(side * size.x * 0.38, height * 0.40, z * size.y), "wood_dark")
		k._box(parent, Vector3(size.x * 0.13, height * 0.15, size.y), base + Vector3(side * size.x * 0.38, height * 0.075, 0), "wood")
	for i in 5:
		k._box(parent, Vector3(size.x, height * 0.35, size.y * 0.17), base + Vector3(0, height * 0.825, lerpf(-size.y * 0.4, size.y * 0.4, i / 4.0)), "wood")

static func restraints(k: VehicleModels, parent: Node3D, base: Vector3, size: Vector3, offsets: Array, width := 0.045, col := Color(0.28, 0.26, 0.2)) -> void:
	for z: float in offsets:
		k._box(parent, Vector3(size.x + 0.008, 0.007, width), base + Vector3(0, size.y + 0.004, z), "canvas_white", col, Vector3.ZERO, false)
		for side: float in [-1.0, 1.0]:
			var x := side * (size.x * 0.5 + 0.004)
			k._box(parent, Vector3(0.007, size.y, width), base + Vector3(x, size.y * 0.5, z), "canvas_white", col, Vector3.ZERO, false)
			var buckle := base + Vector3(x, minf(0.2, size.y * 0.3), z)
			for edge: float in [-1.0, 1.0]:
				k._box(parent, Vector3(0.022, width * 1.8, width * 0.16), buckle + Vector3(0, 0, edge * width * 0.6), "steel", Color(0.25, 0.26, 0.23))
				k._box(parent, Vector3(0.022, width * 0.16, width * 1.2), buckle + Vector3(0, edge * width * 0.82, 0), "steel", Color(0.25, 0.26, 0.23))
			VehicleEquipment._rod(k, parent, buckle + Vector3(side * 0.018, 0, -width * 0.5), buckle + Vector3(side * 0.018, 0, width * 0.5), width * 0.13, "steel", null, 6, false, 3)
			k._box(parent, Vector3(0.005, minf(size.y * 0.25, width * 3), width * 0.85), buckle + Vector3(side * 0.021, -width * 1.7, 0), "canvas_white", col, Vector3(0, 0, side * 0.12), false)
			VehicleBody.fastener(k, parent, base + Vector3(x, 0.03, z), Vector3(side, 0, 0), minf(0.012, width * 0.25))


static var _rings := {}

## A small forged tie-down ring, lying in the XZ plane (cached by size).
## `slices` round the ring and `sides` round its wire: a ring of centimetre wire
## a hand across reads as a ring with eight and three.
static func _ring(radius: float, wire: float, slices := 10, sides := 4) -> TorusMesh:
	var key := Vector4(radius, wire, slices, sides)
	if not _rings.has(key):
		var ring := TorusMesh.new()
		ring.inner_radius = radius - wire
		ring.outer_radius = radius + wire
		ring.rings = slices
		ring.ring_segments = sides
		_rings[key] = ring
	return _rings[key]


## Truck cargo bed (dropside or flatbed body) in the parent's coordinates: the
## deck from `z0` (its front edge, behind the cab) to `z1` (the tail), `width`
## across its outer edges, its load surface at `floor_y`, `deck` thick (plank
## joins on a wood deck, plate seams on a steel one); `deck_mat` / `deck_col`
## finish it in place of `mat` / `col` when given. `subframe` = (runner centre
## x, depth under the deck, runner width) adds the runners that seat the body
## on the chassis rails, cross bearers out to the edges and bolted shear plates
## (zero for none). Rub rails run under both deck edges, tie-down rings hung
## from them. `sides` > 0 hinges dropsides that tall (their folded top rails
## included) on the deck edges, with a tailgate between them, bottom hinges and
## top catches, `board` thick; `posts` stake posts a side stand in pockets on
## the rub rails, spread from front to tail (a flat deck keeps just the
## pockets). `headboard` > 0 stands a capped bulkhead that tall on the front
## edge, and `guard` > 0 a cab guard of bars that much higher over it. All of
## it stays within the deck's width plus 4 cm a side and z0..z1 but for 3 cm
## of tailgate hinges. Loads, benches, canopy and bows, lamps, bumper and
## mudguards stay with the caller.
static func flatbed(k: VehicleModels, parent: Node3D, z0: float, z1: float, width: float, floor_y: float, mat: String, col = null, sides := 0.0, posts := 0, headboard := 0.0, guard := 0.0, deck := 0.12, deck_mat := "", deck_col = null, subframe := Vector3.ZERO, board := 0.05) -> void:
	var length := z1 - z0
	var zc := (z0 + z1) * 0.5
	var hw := width * 0.5
	var dm := deck_mat if deck_mat != "" else mat
	var dc: Variant = deck_col if deck_mat != "" else col
	var dark: Variant = (col as Color).darkened(0.18) if col is Color else null
	k._box(parent, Vector3(width, deck, length), Vector3(0, floor_y - deck * 0.5, zc), dm, dc)
	if VehicleMaterials.profile(dm, k.surface_family) == "wood":
		# Hardwood planks laid lengthwise, their joins about 20 cm apart.
		var planks := maxi(3, roundi(width / 0.2))
		for i in range(1, planks):
			k._box(parent, Vector3(0.008, 0.004, length - 0.04), Vector3(lerpf(-hw, hw, float(i) / planks), floor_y + 0.001, zc), "plain_dark", null, Vector3.ZERO, false)
	else:
		# Welded plate seams across a steel deck.
		var plates := maxi(2, roundi(length / 1.25))
		for i in range(1, plates):
			k._box(parent, Vector3(width - 0.06, 0.004, 0.01), Vector3(0, floor_y + 0.001, lerpf(z0, z1, float(i) / plates)), mat, dark, Vector3.ZERO, false)
	# The rub rails: pressed channels proud of both deck edges, a sill at the tail.
	for s: float in [-1.0, 1.0]:
		k._box(parent, Vector3(0.02, deck * 0.92, length), Vector3(s * (hw + 0.01), floor_y - deck * 0.5, zc), mat, col)
	k._add(parent, VehicleEquipment._plate(Vector3(width, deck * 0.7, 0.012)), mat, dark, Vector3(0, floor_y - deck * 0.55, z1 - 0.006), Vector3.ZERO, Vector3.ONE, false)
	if subframe.y > 0.0:
		var under := floor_y - deck
		for s: float in [-1.0, 1.0]:
			k._box(parent, Vector3(subframe.z, subframe.y, length - 0.1), Vector3(s * subframe.x, under - subframe.y * 0.5, zc), "gunmetal_w")
			# Shear plates bolting the runners to the chassis rails below.
			var plates := maxi(2, roundi(length / 2.0))
			for i in plates:
				var z := lerpf(z0 + length * 0.12, z1 - length * 0.12, float(i) / maxi(1, plates - 1))
				var x := s * (subframe.x + subframe.z * 0.5 + 0.004)
				k._box(parent, Vector3(0.008, subframe.y * 0.9, 0.14), Vector3(x, under - subframe.y * 0.5, z), "gunmetal_w", null, Vector3.ZERO, false)
				VehicleBody.fastener(k, parent, Vector3(x + s * 0.004, under - subframe.y * 0.5, z), Vector3(s, 0, 0), 0.012)
		# The cross bearers under the deck show only their undersides, between
		# the rub rails: plain bars.
		var bearers := maxi(2, ceili(length / 0.9)) + 1
		for i in bearers:
			var z := lerpf(z0 + 0.05, z1 - 0.05, float(i) / (bearers - 1))
			k._add(parent, VehicleEquipment._plate(Vector3(width - 0.04, subframe.y * 0.5, 0.06)), "gunmetal_w", null, Vector3(0, under - subframe.y * 0.25, z))
	# Tie-down rings hang from the rub rails between the stake posts, each from
	# a centimetre-thick plain bracket.
	var ring := _ring(0.026, 0.0045, 8, 3)
	var bracket := VehicleEquipment._plate(Vector3(0.012, 0.03, 0.05))
	var rings := maxi(2, roundi(length / 1.0))
	for s: float in [-1.0, 1.0]:
		for i in rings:
			var z := lerpf(z0, z1, (i + 0.5) / rings)
			var x := s * (hw + 0.021)
			k._add(parent, bracket, "steel", null, Vector3(x, floor_y - deck * 0.85, z), Vector3.ZERO, Vector3.ONE, false)
			k._add(parent, ring, "steel", null, Vector3(x + s * 0.004, floor_y - deck - 0.018, z), Vector3(0, 0, PI / 2), Vector3.ONE, false)
	var top := floor_y + sides
	var head := 0.0
	if headboard > 0.0:
		head = board + 0.01
		var hz := z0 + head * 0.5
		var panel := maxf(0.02, headboard - 0.035)
		VehicleCargo.sideboard(k, parent, Vector3(width - 0.02, panel, head), Vector3(0, floor_y + panel * 0.5, hz), mat, col, Vector3.ZERO, 2)
		k._box(parent, Vector3(width, 0.035, head + 0.02), Vector3(0, floor_y + headboard - 0.0175, hz), mat, dark)
		for s: float in [-1.0, 1.0]:
			k._box(parent, Vector3(0.06, headboard, head + 0.02), Vector3(s * (hw - 0.03), floor_y + headboard * 0.5, hz), mat, dark)
		if guard > 0.0:
			# The cab guard: bars welded between the headboard's top and a rail.
			var y0 := floor_y + headboard
			var bars := maxi(3, roundi(width / 0.5) + 1)
			for i in bars:
				var x := lerpf(-hw + 0.03, hw - 0.03, float(i) / (bars - 1))
				var post := 0.055 if i == 0 or i == bars - 1 else 0.04
				k._box(parent, Vector3(post, guard, post), Vector3(x, y0 + guard * 0.5, hz), mat, col)
			k._box(parent, Vector3(width, 0.05, 0.06), Vector3(0, y0 + guard - 0.025, hz), mat, col)
			k._box(parent, Vector3(width - 0.06, 0.035, 0.035), Vector3(0, y0 + guard * 0.45, hz), mat, col, Vector3.ZERO, false)
	# Stake pockets and catches are 2 cm plates welded on: plain.
	var pocket := VehicleEquipment._plate(Vector3(0.02, deck * 0.9, 0.09))
	if sides <= 0.0:
		# A flat deck keeps its stake pockets for removable stakes.
		for s: float in [-1.0, 1.0]:
			for i in maxi(0, posts):
				var z := lerpf(z0 + head + 0.035, z1 - 0.035, float(i) / maxi(1, posts - 1)) if posts > 1 else zc
				k._add(parent, pocket, "gunmetal_w", null, Vector3(s * (hw + 0.03), floor_y - deck * 0.5, z), Vector3.ZERO, Vector3.ONE, false)
		return
	# Dropsides: one leaf a side between the headboard and the tail, hinged on
	# the rub rail, latched to the stake posts at the top.
	var sz0 := z0 + head
	var sl := z1 - sz0
	var sc := (sz0 + z1) * 0.5
	var hinges := maxi(2, roundi(sl / 1.2))
	var leaf := maxf(0.02, sides - 0.035)
	for s: float in [-1.0, 1.0]:
		var x := s * (hw - board * 0.5)
		VehicleCargo.sideboard(k, parent, Vector3(board, leaf, sl), Vector3(x, floor_y + leaf * 0.5, sc), mat, col, Vector3.ZERO, 0)
		k._box(parent, Vector3(board + 0.02, 0.035, sl), Vector3(x, top - 0.0175, sc), mat, dark)
		for i in hinges:
			var z := lerpf(sz0 + 0.25, z1 - 0.25, float(i) / (hinges - 1))
			VehicleEquipment._cyl(k, parent, 0.016, 0.016, 0.1, Vector3(s * (hw + 0.012), floor_y + 0.012, z), X90, "steel", null, 6, false)
			k._box(parent, Vector3(0.006, 0.12, 0.05), Vector3(s * (hw + 0.003), floor_y + 0.07, z), "gunmetal_w", null, Vector3.ZERO, false)
		for i in maxi(0, posts):
			var z := lerpf(sz0 + 0.035, z1 - 0.035, float(i) / maxi(1, posts - 1)) if posts > 1 else sc
			k._box(parent, Vector3(0.04, sides + deck * 0.8, 0.06), Vector3(s * (hw + 0.018), floor_y + (sides - deck * 0.8) * 0.5, z), mat, dark)
			# The stake pocket on the rub rail, and the leaf's catch on the post.
			k._add(parent, pocket, "gunmetal_w", null, Vector3(s * (hw + 0.03), floor_y - deck * 0.5, z), Vector3.ZERO, Vector3.ONE, false)
			if i > 0 and i < posts - 1:
				for dz: float in [-1.0, 1.0]:
					k._add(parent, VehicleEquipment._plate(Vector3(0.02, 0.05, 0.05)), "gunmetal_w", null, Vector3(s * (hw + 0.008), top - 0.07, z + dz * 0.07), Vector3.ZERO, Vector3.ONE, false)
	# The tailgate between the dropsides: hinged along its foot, its two top
	# catches on the sides' ends.
	var tz := z1 - board * 0.5
	VehicleCargo.sideboard(k, parent, Vector3(width - board * 2.0, leaf, board), Vector3(0, floor_y + leaf * 0.5, tz), mat, col, Vector3.ZERO, 2)
	k._box(parent, Vector3(width - board * 2.0, 0.035, board + 0.02), Vector3(0, top - 0.0175, tz), mat, dark)
	for s: float in [-1.0, 1.0]:
		VehicleEquipment._cyl(k, parent, 0.016, 0.016, 0.12, Vector3(s * width * 0.3, floor_y + 0.006, z1 + 0.012), Vector3(0, 0, PI / 2), "steel", null, 6, false)
		k._box(parent, Vector3(0.05, 0.12, 0.006), Vector3(s * width * 0.3, floor_y + 0.07, z1 + 0.003), "gunmetal_w", null, Vector3.ZERO, false)
		k._add(parent, VehicleEquipment._plate(Vector3(0.07, 0.05, 0.02)), "gunmetal_w", null, Vector3(s * (hw - board - 0.04), top - 0.07, z1 + 0.01), Vector3.ZERO, Vector3.ONE, false)


## Box body on a truck bed (van box, workshop or ambulance shelter, kung):
## the box from `z0` (front) to `z1` (rear), `width` across, standing on
## `floor_y` with its roof at `roof_y`, in the parent's coordinates. `corner`
## chamfers its four upright edges and `roof` the roof's edge (zero for square
## ones). Corner extrusions, a bottom rail and a roof drip rail round it,
## `ribs` upright ribs a side (-1 spaces them about 95 cm apart, 0 leaves the
## sides plain for the caller's shutters and windows), `vents` mushroom vents
## along the roof and clearance markers at the roof's corners (their lenses
## gone on a wreck). `door` is the rear door opening, its centre (x, y) on the
## rear face and its size (a zero size fills the face); `leaves` 2 hangs a pair
## of doors there, 1 or -1 one leaf hinged on its +X or -X edge, 0 none (see
## body_door). A nonzero `ladder` puts a rung ladder up the rear face at that
## x. Stays within the box but for 4 cm of markers and rails a side, 9 cm of
## ladder at the back and 17 cm of vents on the roof. Windows, crosses, side
## doors (body_door), roller shutters (roller_shutter), crane, awning and roof
## plant stay with the caller.
static func shelter(k: VehicleModels, parent: Node3D, z0: float, z1: float, width: float, floor_y: float, roof_y: float, mat: String, col = null, door := Rect2(), leaves := 2, ribs := -1, corner := 0.05, roof := 0.0, ladder := 0.0, vents := 2) -> void:
	var hw := width * 0.5
	var height := roof_y - floor_y
	var length := z1 - z0
	var zc := (z0 + z1) * 0.5
	var c := clampf(corner, 0.0, minf(hw, length * 0.5) * 0.3)
	var rc := clampf(roof, 0.0, minf(height * 0.3, minf(hw, length * 0.5) * 0.3))
	var dark: Variant = (col as Color).darkened(0.12) if col is Color else null
	var rings := [_plan(hw, z0, z1, c, floor_y)]
	if rc > 0.0:
		rings.append(_plan(hw, z0, z1, c, roof_y - rc))
		rings.append(_plan(hw - rc, z0 + rc, z1 - rc, c, roof_y))
	else:
		rings.append(_plan(hw, z0, z1, c, roof_y))
	k._add(parent, VehicleModels.solid(rings, "cargo_shelter_%.3f_%.3f_%.3f_%.3f_%.3f_%.3f_%.3f" % [z0, z1, width, floor_y, roof_y, c, rc]), mat, col, Vector3.ZERO)
	var wall := height - rc
	# Corner extrusions: angle sections over the four upright edges.
	for s: float in [-1.0, 1.0]:
		for e: float in [-1.0, 1.0]:
			var z := zc + e * length * 0.5
			if c > 0.0:
				var at := Vector3(s * (hw - c * 0.5), floor_y + wall * 0.5, z - e * c * 0.5) + Vector3(s, 0, e).normalized() * 0.008
				k._box(parent, Vector3(c * 1.414 + 0.03, wall, 0.016), at, mat, dark, Vector3(0, s * e * PI / 4, 0))
			else:
				k._box(parent, Vector3(0.05, wall, 0.012), Vector3(s * (hw - 0.025), floor_y + wall * 0.5, z + e * 0.006), mat, dark)
				k._box(parent, Vector3(0.012, wall, 0.05), Vector3(s * (hw + 0.006), floor_y + wall * 0.5, z - e * 0.025), mat, dark)
	# The bottom rail and the roof's drip rail along both sides and the ends.
	# The bottom rail stands 2.8 cm proud, past the 2 cm of a door leaf, so a
	# door hung down to the floor sits behind it as behind a sill.
	for s: float in [-1.0, 1.0]:
		k._box(parent, Vector3(0.028, 0.07, length - c * 2.0), Vector3(s * (hw + 0.014), floor_y + 0.035, zc), "gunmetal_w")
		k._box(parent, Vector3(0.022, 0.025, length - c * 2.0), Vector3(s * (hw + 0.011), roof_y - rc - 0.02, zc), mat, dark)
		k._box(parent, Vector3(width - c * 2.0, 0.025, 0.022), Vector3(0, roof_y - rc - 0.02, zc + s * (length * 0.5 + 0.011)), mat, dark)
	k._box(parent, Vector3(width - c * 2.0, 0.07, 0.028), Vector3(0, floor_y + 0.035, z1 + 0.014), "gunmetal_w")
	var count := ribs if ribs >= 0 else maxi(1, roundi(length / 0.95)) - 1
	for s: float in [-1.0, 1.0]:
		for i in count:
			var z := lerpf(z0, z1, (i + 1.0) / (count + 1.0))
			k._box(parent, Vector3(0.014, wall - 0.16, 0.05), Vector3(s * (hw + 0.007), floor_y + wall * 0.5 + 0.02, z), mat, dark)
	# Clearance markers: amber toward the front, red toward the back.
	for s: float in [-1.0, 1.0]:
		for e: float in [-1.0, 1.0]:
			var marker := Color(0.62, 0.36, 0.06) if e < 0.0 else Color(0.5, 0.05, 0.04)
			VehicleFittings.marker(k, parent, Vector3(s * (hw + 0.012), roof_y - rc - 0.09, zc + e * (length * 0.5 - c - 0.12)), Vector3(0.024, 0.045, 0.08), s, marker)
	for i in maxi(0, vents):
		var z := lerpf(z0 + length * 0.2, z1 - length * 0.2, float(i) / maxi(1, vents - 1)) if vents > 1 else zc
		var at := Vector3(-hw * 0.4, roof_y, z)
		# The vent stands on the roof, its dark throat between body and cap.
		VehicleEquipment._cyl(k, parent, 0.11, 0.13, 0.12, at + Vector3(0, 0.06, 0), Vector3.ZERO, mat, col, 10, true, 2)
		VehicleEquipment._cyl(k, parent, 0.17, 0.17, 0.035, at + Vector3(0, 0.15, 0), Vector3.ZERO, mat, dark, 10)
		VehicleEquipment._cyl(k, parent, 0.1, 0.1, 0.03, at + Vector3(0, 0.12, 0), Vector3.ZERO, "plain_dark", null, 10, false, 0)
	if leaves != 0:
		var opening := door
		if opening.size.x <= 0.0 or opening.size.y <= 0.0:
			var h := height - rc - 0.2
			opening = Rect2(Vector2(0, floor_y + 0.08 + h * 0.5), Vector2(width - c * 2.0 - 0.2, h))
		body_door(k, parent, Vector3(opening.position.x, opening.position.y, z1), opening.size, Vector3.BACK, leaves, mat, col)
	if ladder != 0.0:
		rung_ladder(k, parent, Vector3(ladder, floor_y - 0.12, z1), roof_y + 0.25, Vector3.BACK)


## A ring of the shelter's plan, its corners chamfered by `c`, at height y.
static func _plan(hw: float, z0: float, z1: float, c: float, y: float) -> PackedVector3Array:
	if c <= 0.0:
		return PackedVector3Array([Vector3(-hw, y, z0), Vector3(hw, y, z0), Vector3(hw, y, z1), Vector3(-hw, y, z1)])
	return PackedVector3Array([Vector3(-hw + c, y, z0), Vector3(hw - c, y, z0), Vector3(hw, y, z0 + c), Vector3(hw, y, z1 - c),
		Vector3(hw - c, y, z1), Vector3(-hw + c, y, z1), Vector3(-hw, y, z1 - c), Vector3(-hw, y, z0 + c)])


## A wall's frame: `normal` outward, "along" to its right as seen from outside.
static func _wall(normal: Vector3) -> Basis:
	var n := Vector3(normal.x, 0, normal.z).normalized()
	return Basis(Vector3.UP.cross(n), Vector3.UP, n)


## Door in a body wall: `center` the opening's centre on the wall's outer face,
## `size` its width and height, `normal` the wall's outward direction (level).
## A pressed frame round the opening and a drip cap over it; `leaves` 2 hangs
## a pair of leaves on their outer edges with a locking bar on each, 1 or -1 a
## single leaf hinged on its edge toward +along or -along (along = the wall's
## right as seen from outside: +X on a rear wall, -Z on a right-hand side
## wall). Leaves stand 2 cm proud of the wall with VehicleDoors' hinges and
## handles. Windows in the leaves stay with the caller.
static func body_door(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, normal: Vector3, leaves: int, mat: String, col = null) -> void:
	var basis := _wall(normal)
	var m := k._pivot(parent, center)
	m.basis = basis
	var dark: Variant = (col as Color).darkened(0.15) if col is Color else null
	var frame := 0.035
	for side: float in [-1.0, 1.0]:
		k._box(m, Vector3(frame, size.y + frame * 2.0, 0.012), Vector3(side * (size.x + frame) * 0.5, 0, 0.006), mat, dark, Vector3.ZERO, false)
		k._box(m, Vector3(size.x, frame, 0.012), Vector3(0, side * (size.y + frame) * 0.5, 0.006), mat, dark, Vector3.ZERO, false)
	k._box(m, Vector3(size.x + frame * 2.6, 0.02, 0.05), Vector3(0, size.y * 0.5 + frame + 0.012, 0.025), mat, dark, Vector3(-0.2, 0, 0))
	var pair := absi(leaves) >= 2
	var count := 2 if pair else 1
	var w := size.x / count
	for i in count:
		var x0 := -size.x * 0.5 + w * i
		var surface := VehicleSurface.plane(Vector3(x0 + 0.004, -size.y * 0.5 + 0.004, 0.0), Vector3.RIGHT * (w - 0.008), Vector3.UP * (size.y - 0.008))
		var hinge_u := 0.92
		if pair:
			hinge_u = 0.08 if i == 0 else 0.92
		elif leaves < 0:
			hinge_u = 0.08
		var hinges: Array[Vector2] = [Vector2(hinge_u, 0.16), Vector2(hinge_u, 0.84)]
		VehicleDoors.closed(k, m, surface, PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), hinges, Vector2(1.0 - hinge_u, 0.5), mat, col)
		if pair:
			# The cam locking bar down each leaf, in its top and bottom keepers.
			var x := x0 + w * (0.62 if i == 0 else 0.38)
			VehicleEquipment._rod(k, m, Vector3(x, -size.y * 0.5 + 0.06, 0.04), Vector3(x, size.y * 0.5 - 0.06, 0.04), 0.011, "steel", null, 6, false, 3)
			for e: float in [-1.0, 1.0]:
				k._box(m, Vector3(0.05, 0.04, 0.04), Vector3(x, e * (size.y * 0.5 - 0.05), 0.03), "gunmetal_w", null, Vector3.ZERO, false)
	k._fold(m)


## Rung ladder up a body wall: `foot` the bottom of its centre line on the
## wall's outer face, the rails rising to `top_y` (a grab loop above a roof
## edge), `normal` the wall's outward direction. Rungs every 28 cm on two
## rails held off the wall by bolted stand-off brackets.
static func rung_ladder(k: VehicleModels, parent: Node3D, foot: Vector3, top_y: float, normal: Vector3, width := 0.36) -> void:
	var basis := _wall(normal)
	var m := k._pivot(parent, foot)
	m.basis = basis
	var height := top_y - foot.y
	var off := 0.07
	for side: float in [-1.0, 1.0]:
		var x := side * width * 0.5
		VehicleFrames.beam(k, m, Vector3(x, 0, off), Vector3(x, height, off), 0.025, 0.035, "gunmetal_w")
		for y: float in [0.25, height - 0.35]:
			VehicleFrames.beam(k, m, Vector3(x, y, 0.0), Vector3(x, y, off), 0.02, 0.03, "gunmetal_w", null, false)
			VehicleBody.fastener(k, m, Vector3(x + side * 0.02, y, 0.012), Vector3.BACK, 0.009)
	var rungs := maxi(2, floori((height - 0.3) / 0.28))
	for i in rungs:
		var y := 0.15 + i * 0.28
		# Each rung's ends are in the rails.
		VehicleEquipment._rod(k, m, Vector3(-width * 0.5, y, off), Vector3(width * 0.5, y, off), 0.014, "steel", null, 6, false, 0)
	k._fold(m)


## Roller shutter over a locker or workshop opening: `center` the opening's
## centre on the wall's outer face, `size` its width and height, `normal` the
## wall's outward direction (level). A slatted curtain (`slats`
## joints, 0 for one about every 11 cm) between guide channels, the roll
## housing over the top and a bottom bar with a lift strap and lock. The
## default "steel" with no colour reads as bare aluminium; pass the body's
## material (and no colour) for a painted or camouflaged shutter. Stands at
## most 6 cm proud of the wall and 9 cm over the opening's top.
static func roller_shutter(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, normal: Vector3, mat := "steel", col = null, slats := 0) -> void:
	var basis := _wall(normal)
	var m := k._pivot(parent, center)
	m.basis = basis
	# Without a colour the curtain keeps its material's own finish, so a shutter
	# painted in the body's camouflage stays camouflaged; the slat joints are
	# then plain dark metal rather than a darker tint of it.
	var tint: Variant = col
	var dark: Variant = (col as Color).darkened(0.35) if col is Color else null
	var joint_mat := mat if col is Color else "metal_dark"
	k._box(m, Vector3(size.x, size.y, 0.012), Vector3(0, 0, 0.006), mat, tint)
	var joints := slats if slats > 0 else clampi(roundi(size.y / 0.11), 3, 24)
	for i in range(1, joints):
		k._box(m, Vector3(size.x - 0.01, 0.008, 0.004), Vector3(0, lerpf(-size.y * 0.5, size.y * 0.5, float(i) / joints), 0.013), joint_mat, dark, Vector3.ZERO, false)
	for side: float in [-1.0, 1.0]:
		k._box(m, Vector3(0.03, size.y + 0.02, 0.028), Vector3(side * (size.x * 0.5 + 0.015), 0, 0.014), "gunmetal_w")
	k._box(m, Vector3(size.x + 0.06, 0.09, 0.06), Vector3(0, size.y * 0.5 + 0.045, 0.03), mat, tint)
	# The bottom bar, its lift strap and the lock in its middle.
	k._box(m, Vector3(size.x - 0.004, 0.035, 0.022), Vector3(0, -size.y * 0.5 + 0.0175, 0.011), "gunmetal_w")
	k._box(m, Vector3(0.03, 0.09, 0.006), Vector3(size.x * 0.3, -size.y * 0.5 - 0.02, 0.022), "webbing", Color(0.16, 0.16, 0.14), Vector3.ZERO, false)
	k._cyl(m, 0.014, 0.014, 0.012, Vector3(0, -size.y * 0.5 + 0.0175, 0.026), X90, "steel", null, 8, false)
	k._fold(m)


## Ribbed cargo leaf. Layout, opening angle and stake posts remain authored;
## folded edges and stiffeners are constructed once for all flat-sided beds.
static func sideboard(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, mat: String, col = null, rotation := Vector3.ZERO, axis := 2) -> void:
	VehicleDoors.leaf(k, parent, size, center, mat, col, rotation, axis)
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var length := size.z if axis == 0 else size.x
	var count := maxi(2, ceili(length / 0.65))
	for i in range(1, count):
		var at := Vector3(0, 0, lerpf(-length * 0.5, length * 0.5, float(i) / count)) if axis == 0 else Vector3(lerpf(-length * 0.5, length * 0.5, float(i) / count), 0, 0)
		var rib := Vector3(size.x + 0.012, size.y * 0.88, 0.025) if axis == 0 else Vector3(0.025, size.y * 0.88, size.z + 0.012)
		k._add(mount, BevelMesh.make(rib, 0.004), mat, col, at)
	k._fold(mount)


## Roof rails on their feet, and the cross bars of a roof rack clamped across
## them (vans, SUVs, MRAPs): `base` the middle of the pair on the roof, its y
## the roof's top; `size` = (the rails' spacing centre to centre, the rails'
## top above the roof, their length along Z); `rail` the rail's width and
## depth. A rail standing more than 1.5 cm clear of the roof stands on `feet`
## feet a side (-1: about one every 1.1 m, the end ones 8 to 15 cm in from the
## rail's ends), each a moulded block on a rubber pad with the cover of its
## roof bolt on the rail above; a lower rail lies on a rubber strip, bolted
## down through its top about every 45 cm. Black end caps close the rails.
## `bars` > 0 clamps that many cross bars, `bar` = (height, depth), on top of
## the rails, spread between the end feet, each gripping both rails in a clamp
## foot and closed by end caps. Stays within the rails' footprint but for
## 0.75 of a rail's width of pads and 0.8 cm of clamps a side, and 0.6 cm of
## bolt heads over the bars. Loads, ladders and baskets on it stay with the
## caller.
static func roof_rack(k: VehicleModels, parent: Node3D, base: Vector3, size: Vector3, feet := -1, bars := 0, mat := "gunmetal_w", col = null, rail := Vector2(0.05, 0.05), bar := Vector2(0.04, 0.05)) -> void:
	var length := size.z
	var z0 := base.z - length * 0.5
	var z1 := base.z + length * 0.5
	var inset := clampf(length * 0.06, 0.08, 0.15)
	var gap := size.y - rail.y
	var ry := base.y + size.y - rail.y * 0.5
	var standing := gap > 0.015
	var count := feet if feet >= 0 else (maxi(2, roundi(length / 1.1) + 1) if standing else 0)
	var cap_col := Color(0.08, 0.08, 0.08)
	var bolt := minf(0.01, rail.x * 0.22)
	for s: float in [-1.0, 1.0]:
		var x := base.x + s * size.x * 0.5
		k._box(parent, Vector3(rail.x, rail.y, length - 0.06), Vector3(x, ry, base.z), mat, col)
		for e: float in [-1.0, 1.0]:
			k._box(parent, Vector3(rail.x * 1.06, rail.y * 1.04, 0.03), Vector3(x, ry, base.z + e * (length * 0.5 - 0.015)), "plain_dark", cap_col)
		if standing:
			for i in count:
				var z := lerpf(z0 + inset, z1 - inset, float(i) / maxi(1, count - 1)) if count > 1 else base.z
				k._box(parent, Vector3(rail.x * 1.2, gap, 0.08), Vector3(x, base.y + gap * 0.5, z), "gunmetal_w")
				k._box(parent, Vector3(rail.x * 1.5, 0.008, 0.1), Vector3(x, base.y + 0.004, z), "rubber", null, Vector3.ZERO, false)
				VehicleBody.fastener(k, parent, Vector3(x, base.y + size.y + 0.003, z), Vector3.UP, bolt)
		else:
			# A flush rail: bedded on rubber and bolted straight through the roof.
			k._box(parent, Vector3(rail.x * 1.2, 0.008, length - 0.04), Vector3(x, base.y + 0.004, base.z), "rubber", null, Vector3.ZERO, false)
			var bolts := maxi(2, roundi(length / 0.45))
			for i in bolts:
				VehicleBody.fastener(k, parent, Vector3(x, base.y + size.y + 0.003, lerpf(z0 + inset, z1 - inset, float(i) / (bolts - 1))), Vector3.UP, bolt)
	var span := size.x + rail.x
	for i in maxi(0, bars):
		var z := lerpf(z0 + inset, z1 - inset, float(i) / maxi(1, bars - 1)) if bars > 1 else base.z
		k._box(parent, Vector3(span - 0.02, bar.x, bar.y), Vector3(base.x, base.y + size.y + bar.x * 0.5, z), mat, col)
		for s: float in [-1.0, 1.0]:
			k._box(parent, Vector3(0.01, bar.x * 1.05, bar.y * 1.05), Vector3(base.x + s * (span * 0.5 - 0.005), base.y + size.y + bar.x * 0.5, z), "plain_dark", cap_col, Vector3.ZERO, false)
			# The clamp foot closes over the rail's top and sides.
			k._box(parent, Vector3(rail.x + 0.016, rail.y * 0.5, bar.y + 0.016), Vector3(base.x + s * size.x * 0.5, base.y + size.y - rail.y * 0.25, z), "plain_dark", cap_col)


## A stack of boxes (ammunition, rations, stores) on a truck bed, strapped
## down: `base` the middle of its foot on the load surface, `size` the whole
## stack with its pallet (width along X, height, depth along Z), `grid` the
## boxes across, the layers and the boxes along. `pallet_height` > 0 builds a
## wooden pallet that tall under them (see pallet); the boxes share the rest,
## stacked straight up and standing 2 to 4 cm apart. Wooden boxes (by `mat`'s
## finish) are crates bound with two dark battens; painted or steel ones have a
## lid seam and a carrying handle on each short end. Every other box is
## darkened by `shade` (negative lightens) so the stack reads as boxes from
## above. `straps` are the z offsets of ratchet straps over the boxes (see
## restraints), `strap` their colour. `yaw` turns the whole stack about its
## base. Stays within `size` but for 1.1 cm of handles and 0.8 cm of battens
## at its sides, and the straps' 1 cm over the top and 3 cm of buckles at the
## sides.
static func crate_stack(k: VehicleModels, parent: Node3D, base: Vector3, size: Vector3, grid := Vector3i.ONE, mat := "paint", col = null, pallet_height := 0.0, straps: Array = [], shade := 0.12, strap := Color(0.28, 0.26, 0.2), yaw := 0.0) -> void:
	var m := k._pivot(parent, base)
	m.rotation.y = yaw
	var nx := maxi(1, grid.x)
	var ny := maxi(1, grid.y)
	var nz := maxi(1, grid.z)
	var lift := maxf(0.0, pallet_height)
	if lift > 0.0:
		pallet(k, m, Vector3.ZERO, Vector2(size.x, size.z), lift)
	var px := size.x / nx
	var pz := size.z / nz
	var gx := minf(0.04, px * 0.06)
	var gz := minf(0.04, pz * 0.06)
	var bw := px - gx
	var bd := pz - gz
	var ph := (size.y - lift) / ny
	var wood := VehicleMaterials.profile(mat, k.surface_family) == "wood"
	# Handles sit on the boxes' short ends, reaching half way across the gap.
	var ends_z := bd <= bw
	var reach := minf(0.011, (gz if ends_z else gx) * 0.45)
	var handle := Vector3(minf(0.08, bw * 0.4), 0.02, reach) if ends_z else Vector3(reach, 0.02, minf(0.08, bd * 0.4))
	var band := minf(0.06, ph * 0.18)
	for l in ny:
		for i in nx:
			for j in nz:
				var at := Vector3(-size.x * 0.5 + px * (i + 0.5), lift + ph * (l + 0.5), -size.z * 0.5 + pz * (j + 0.5))
				var tint: Variant = col
				if col is Color and ((i + j + l) & 1) == 1:
					tint = (col as Color).darkened(shade) if shade >= 0.0 else (col as Color).lightened(-shade)
				k._box(m, Vector3(bw, ph, bd), at, mat, tint)
				if wood:
					for e: float in [-1.0, 1.0]:
						k._box(m, Vector3(bw + 0.016, band, bd + 0.016), at + Vector3(0, e * (ph * 0.5 - band * 0.5 - minf(0.04, ph * 0.1)), 0), "wood_dark")
				else:
					k._box(m, Vector3(bw + 0.004, 0.008, bd + 0.004), at + Vector3(0, ph * 0.5 - minf(0.05, ph * 0.22), 0), "plain_dark", null, Vector3.ZERO, false)
					for e: float in [-1.0, 1.0]:
						var out := Vector3(0, 0, e * (bd + reach) * 0.5) if ends_z else Vector3(e * (bw + reach) * 0.5, 0, 0)
						k._box(m, handle, at + out + Vector3(0, ph * 0.2, 0), "gunmetal_w", null, Vector3.ZERO, false)
	if not straps.is_empty():
		restraints(k, m, Vector3(0, lift, 0), Vector3(size.x - gx, size.y - lift, size.z), straps, 0.045, strap)
	k._fold(m)
