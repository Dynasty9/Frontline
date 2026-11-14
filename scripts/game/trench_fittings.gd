class_name TrenchFittings
## Fittings for a finished fire trench, after the digging (view only).
##
## A dug trench is only a ditch until it is fitted out. Field manuals from 1916
## to the trenches round Bakhmut describe the same work: the cut walls are
## revetted so they don't slump (planks behind posts, corrugated iron on
## pickets, or woven wattle hurdles: whatever came up the line), the spoil in
## front is faced with sandbags into a parapet with loopholes for the rifles
## (some behind steel plates), a lower parados of bags at the back stops
## rounds bursting behind, and scaling ladders lean on the front wall for
## going over. Along the bays: ammunition on the fire step, a box periscope for
## the sentry, a water can, the field telephone line pegged along the back
## wall. In the rear recesses: dugout entrances, timber-framed and roofed, a
## gas blanket rolled over the door; roofed funk holes; supply shelves.
##
## Everything here is drawn from the section's id, so host and client see the
## same trench, and only on the "Done" node, so it shows once the section is
## finished and intact.

const PANEL := 1.8  # revetment panels run between posts this far apart
const STEP_Y := -0.9  # the top of the fire step, against a full-depth wall
const PARAPET_Y := 0.06  # where the bags bed into the spoil above the lip
const OLIVE := Color(0.3, 0.33, 0.2)
const CAN := Color(0.27, 0.3, 0.2)
const WIRE := Color(0.08, 0.08, 0.07)

enum Revet { TIMBER, IRON, WATTLE }
enum Recess { DUGOUT, FUNK_HOLE, SHELF }


## How this section's walls are held up. Neighbours differ: a line is revetted
## a bay at a time, with what the carrying party brought up that night.
static func revetment(st) -> int:
	return posmod(st.eid * 5 + 1, 3)


## What fills a section's rear recess (see TrenchNet.has_recess).
static func recess(st) -> int:
	return TrenchNet.recess_kind(st)


## A section running across the enemy's front is a fire bay, with a parapet to
## fire over; one running towards him (a communication trench, a traverse) is not.
static func fire_bay(st) -> bool:
	if st.size.x < 5.0:
		return false
	var axis: Vector3 = Basis(Vector3.UP, st.yaw) * Vector3.RIGHT
	var enemy := Vector3(0, 0, -1) if st.team == 0 else Vector3(0, 0, 1)
	return absf(axis.dot(enemy)) < 0.6


## Stretches of the section (local x, [from, to]) taken up by a machine-gun
## bay dug into it: its own bags and roof stand there, not the bay's kit.
static func gun_bays(st) -> Array:
	var out := []
	if st.world == null:
		return out
	var inv := Basis(Vector3.UP, st.yaw).inverse()
	for other in st.world.structures_near(st.position, st.size.x * 0.5 + 3.0):
		if other.skind in ["mg_nest", "hmg_nest"] and other.variant == 1 and not other.gone:
			var local: Vector3 = inv * (other.position - st.position)
			if absf(local.z) < 1.5 and absf(local.x) < st.size.x * 0.5 + 1.8:
				out.append([local.x - 1.75, local.x + 1.75])
	return out


static func _clear(spans: Array, x: float, half := 0.0) -> bool:
	for span in spans:
		if x + half > span[0] and x - half < span[1]:
			return false
	return true


## Height of the ground at a point of the section's model, above its origin.
static func grade(st, local: Vector3) -> float:
	if st.world == null:
		return 0.0
	return st.world.terrain.landform.height(st.position + Basis(Vector3.UP, st.yaw) * Vector3(local.x, 0, local.z)) - st.position.y


## Fits the finished section out: walls, parapet, ladders, kit and its recess.
## Returns the sandbags to lay (Structure._bag_walls).
static func furnish(st, done: Node3D, rng: RandomNumberGenerator) -> Array:
	var bags: Array = []
	var fsgn: float = st._enemy_side()
	match revetment(st):
		Revet.TIMBER:
			WorksModels.trench_shoring(st, done, rng)
		Revet.IRON:
			_iron(st, done, rng)
		Revet.WATTLE:
			_wattle(st, done, rng)
	if fire_bay(st):
		var guns := gun_bays(st)
		_parapet(st, bags, done, rng, fsgn, guns)
		_bay_kit(st, done, rng, fsgn, guns)
	elif st.size.x >= 5.0:
		# a communication trench: a few bags on the lips and the telephone line
		for i in rng.randi_range(1, 2):
			var side: float = fsgn if rng.randf() < 0.5 else -fsgn
			var bx := rng.randf_range(-st.size.x * 0.5 + 1.2, st.size.x * 0.5 - 1.2)
			var bag := {"p": Vector3(bx, grade(st, Vector3(bx, 0, side)) + 0.2, side * 1.05), "s": Vector3(0.55 * rng.randi_range(1, 2), 0.19, 0.36), "r": rng.randf_range(-0.2, 0.2)}
			if WorksModels.trench_backed(st, bag.p, bag.s.x * 0.5):
				bags.append(bag)
		_phone_line(st, done, -fsgn)
	if TrenchNet.has_recess(st):
		match recess(st):
			Recess.DUGOUT:
				_dugout(st, done, rng, -fsgn, bags)
			Recess.FUNK_HOLE:
				_funk_hole(st, done, rng, -fsgn)
			Recess.SHELF:
				_shelf(st, done, rng, -fsgn)
	return bags


# --- revetment ------------------------------------------------------------------------

## Where the panels go along each wall: [x of the panel's middle, side], skipping
## the opening of a rear recess and anywhere a joining trench has cut the wall away.
static func _panels(st) -> Array:
	var out := []
	var count := maxi(1, floori(st.size.x / PANEL))
	var rear: float = -st._enemy_side()
	for side in [-1.0, 1.0]:
		for i in count - 1:
			var middle: float = -st.size.x * 0.5 + 0.7 + i * PANEL + PANEL * 0.5
			if TrenchNet.has_recess(st) and side == rear and absf(middle) < 1.55:
				continue
			if not WorksModels.trench_backed(st, Vector3(middle, 0, side * (TrenchNet.HALF_W + 0.25)), PANEL * 0.5):
				continue
			out.append([middle, side])
	return out


## Corrugated iron, two lapped sheets a panel, held against the cut by round
## pickets driven into the floor; sheets dented and rusting at different rates.
static func _iron(st, done: Node3D, rng: RandomNumberGenerator) -> void:
	var basis := Basis(Vector3.UP, st.yaw)
	for panel in _panels(st):
		var middle: float = panel[0]
		var side: float = panel[1]
		var point: Vector3 = st.position + basis * Vector3(middle, 0, side * TrenchNet.HALF_W)
		var edge := WorksModels._shoring_edge(point, basis.x)
		var g := grade(st, Vector3(middle, 0, side))
		for k in 2:
			var x := middle + (k - 0.5) * 0.86
			var col: Color = WorksModels.RUST.lightened(rng.randf_range(0.05, 0.3)) if rng.randf() < 0.55 else Color(0.42, 0.43, 0.41).darkened(rng.randf_range(0.0, 0.25))
			# leaning back into the cut (the wall is battered), each a little out of true
			WorksModels._mk(done, Res.box(Vector3(0.95, 1.06, 0.018)), "corrugated", Vector3(x, g - 0.66, side * (edge + 0.05 - k * 0.012)),
				Vector3(side * rng.randf_range(0.05, 0.1), rng.randf_range(-0.04, 0.04), rng.randf_range(-0.025, 0.025)), col, false)
		for e in [-1.0, 1.0]:
			var px: float = middle + e * PANEL * 0.5
			if absf(px) > st.size.x * 0.5 - 0.3:
				continue
			WorksModels._mk(done, Res.cyl(0.035, 0.04, 1.32, 6), "wood", Vector3(px, g - 0.58, side * (edge - 0.03)), Vector3(side * 0.06, 0, rng.randf_range(-0.04, 0.04)), Color(0.33, 0.28, 0.21), false)


static var _wattle_mesh: ArrayMesh


## A hurdle: hazel withies woven in and out of a row of stakes, PANEL long and
## a metre high, its face at z = 0 (stakes behind, at +z). The earth hides the
## back, so each withy is a ribbon bent round the stakes, not a full rod.
static func _hurdle() -> ArrayMesh:
	if _wattle_mesh != null:
		return _wattle_mesh
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var stakes := 9
	var gap := PANEL / float(stakes - 1)
	for i in stakes:
		var x := -PANEL * 0.5 + i * gap
		BuildingWire.strand(v, n, PackedVector3Array([Vector3(x, -0.52, 0.035), Vector3(x - 0.004, 0.56, 0.035)]), 0.026)
	var segments := (stakes - 1) * 2
	for row in 14:
		var y := -0.47 + row * 0.07
		var half := 0.03 + 0.004 * sin(row * 2.3)
		var phase := PI if row % 2 == 1 else 0.0
		var prev := Vector3.ZERO
		for j in segments + 1:
			var x := -PANEL * 0.5 + PANEL * j / float(segments)
			var p := Vector3(x, y + 0.008 * sin(x * 5.0 + row * 1.7), 0.035 + 0.028 * sin(x / gap * PI + phase))
			if j > 0:
				var along := (p - prev).normalized()
				var out := Vector3.UP.cross(along).normalized()
				if out.z > 0.0:
					out = -out
				var up := Vector3.UP * half
				_tri_pair(v, n, prev - up, prev + up, p + up, p - up, (out + Vector3.UP * 0.3).normalized(), (out - Vector3.UP * 0.3).normalized())
			prev = p
	_wattle_mesh = WorksModels._commit(v, n)
	return _wattle_mesh


## A quad (a b c d round its edge), lit across its width: the top edge turned
## up a little and the bottom down, so a flat ribbon shades like a round withy.
static func _tri_pair(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, top: Vector3, bottom: Vector3) -> void:
	WorksModels._tri(v, n, a, b, c, bottom, top, top)
	WorksModels._tri(v, n, a, c, d, bottom, top, bottom)


## Wattle hurdles: cheap, light to carry up at night, and they hold a clay cut.
static func _wattle(st, done: Node3D, rng: RandomNumberGenerator) -> void:
	var basis := Basis(Vector3.UP, st.yaw)
	var mesh := _hurdle()
	for panel in _panels(st):
		var middle: float = panel[0]
		var side: float = panel[1]
		var point: Vector3 = st.position + basis * Vector3(middle, 0, side * TrenchNet.HALF_W)
		var edge := WorksModels._shoring_edge(point, basis.x)
		var g := grade(st, Vector3(middle, 0, side))
		# turned so its stakes are against the earth, face to the trench
		var turn := 0.0 if side > 0.0 else PI
		WorksModels._mk(done, mesh, "bark", Vector3(middle, g - 0.66, side * (edge + 0.01)), Vector3(side * rng.randf_range(0.04, 0.08), turn + rng.randf_range(-0.02, 0.02), rng.randf_range(-0.02, 0.02)), Color(0.45, 0.38, 0.28).darkened(rng.randf_range(0.0, 0.2)), false)


# --- parapet and parados -----------------------------------------------------------------

## The front lip faced with sandbags, two bags high and a bag course on top
## broken by loopholes; every other loophole behind a steel plate with a slot.
## At the back, on some bays, one course of bags as a parados.
static func _parapet(st, bags: Array, done: Node3D, rng: RandomNumberGenerator, fsgn: float, guns: Array) -> void:
	var half: float = st.size.x * 0.5 - 0.35
	var z := fsgn * (TrenchNet.HALF_W + 0.48)
	# the lower courses, in runs of about a metre so they bed into the slope
	var runs := maxi(1, ceili(half * 2.0 / 1.1))
	var run_len := half * 2.0 / runs
	for i in runs:
		var x := -half + (i + 0.5) * run_len
		var bag := {"p": Vector3(x, grade(st, Vector3(x, 0, z)) + PARAPET_Y + 0.19, z), "s": Vector3(run_len, 0.38, 0.52), "r": rng.randf_range(-0.03, 0.03)}
		if WorksModels.trench_backed(st, bag.p, run_len * 0.5) and _clear(guns, x, run_len * 0.5):
			bags.append(bag)
	# the top course, gapped for loopholes
	var holes := maxi(2, floori(half * 2.0 / 1.45))
	var spacing := half * 2.0 / holes
	var top_z := z - fsgn * 0.04
	for i in holes:
		var hx := -half + (i + 0.5) * spacing
		var g := grade(st, Vector3(hx, 0, top_z))
		if not WorksModels.trench_backed(st, Vector3(hx, 0, top_z), spacing * 0.5) or not _clear(guns, hx, spacing * 0.5):
			continue
		for e in [-1.0, 1.0]:
			var a: float = hx + e * 0.16
			var b: float = hx + e * spacing * 0.5
			var len := absf(b - a)
			if len > 0.25:
				bags.append({"p": Vector3((a + b) * 0.5, g + PARAPET_Y + 0.38 + 0.1, top_z), "s": Vector3(len, 0.2, 0.42), "r": rng.randf_range(-0.04, 0.04)})
		if (i + st.eid) % 2 == 0:
			_loophole_plate(done, Vector3(hx, g + PARAPET_Y + 0.38, z - fsgn * 0.3), fsgn, rng)
	if not TrenchNet.has_recess(st) and st.eid % 2 == 0:
		var rz := -fsgn * (TrenchNet.HALF_W + 0.42)
		for i in runs:
			var x := -half + (i + 0.5) * run_len
			var bag := {"p": Vector3(x, grade(st, Vector3(x, 0, rz)) + PARAPET_Y + 0.1, rz), "s": Vector3(run_len, 0.2, 0.42), "r": rng.randf_range(-0.04, 0.04)}
			if WorksModels.trench_backed(st, bag.p, run_len * 0.5):
				bags.append(bag)


## A loophole plate: a sheet of armour steel with a shuttered slot, set in the
## parapet and leaning back so a round glances up off it.
static func _loophole_plate(done: Node3D, p: Vector3, fsgn: float, rng: RandomNumberGenerator) -> void:
	var tilt := -fsgn * 0.22
	var col := Color(0.25, 0.24, 0.22).lerp(WorksModels.RUST, rng.randf_range(0.2, 0.6))
	WorksModels._mk(done, Res.box(Vector3(0.5, 0.42, 0.022)), "rust_steel", p + Vector3(0, 0.19, 0), Vector3(tilt, rng.randf_range(-0.06, 0.06), 0), col, false)
	# the slot and its shutter, open
	var slot := Res.mi(done, Res.box(Vector3(0.11, 0.06, 0.03)), Res.mat(Color(0.015, 0.014, 0.012), 1.0, 0.0, true), p + Vector3(0, 0.24, 0), Vector3(tilt, 0, 0), false)
	slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WorksModels._mk(done, Res.box(Vector3(0.13, 0.08, 0.012)), "rust_steel", p + Vector3(0.1, 0.24, fsgn * 0.02), Vector3(tilt, 0, 0.5), col.darkened(0.15), false)


# --- along the bay -------------------------------------------------------------------

## A ladder or two for going over, ammunition boxes on the fire step, the
## sentry's periscope, a water can and the telephone line along the back wall.
static func _bay_kit(st, done: Node3D, rng: RandomNumberGenerator, fsgn: float, guns: Array) -> void:
	var kx: float = st.size.x * 0.5 - 1.2
	var spots: Array[float] = []
	for i in 4:
		spots.append(-kx + (i + rng.randf_range(0.25, 0.75)) * kx * 0.5)
	# keep the middle clear when the recess opens there
	if TrenchNet.has_recess(st):
		spots = spots.filter(func(x: float) -> bool: return absf(x) > 0.9)
	spots = spots.filter(func(x: float) -> bool: return _clear(guns, x, 0.3))
	var used := 0
	if st.eid % 2 == 1 and used < spots.size():
		_ladder(st, done, rng, spots[used], fsgn)
		used += 1
	if used < spots.size():
		var x := spots[used]
		used += 1
		for k in rng.randi_range(1, 3):
			var bx := x + k * 0.34 - 0.3
			var g := grade(st, Vector3(bx, 0, fsgn * 0.5))
			var lid := rng.randf() < 0.3
			WorksModels._mk(done, Res.box(Vector3(0.32, 0.17, 0.16)), "paint", Vector3(bx, g + STEP_Y + 0.085 + (0.17 if k == 2 else 0.0), fsgn * 0.5), Vector3(0, rng.randf_range(-0.15, 0.15), 0), OLIVE.darkened(rng.randf_range(0.0, 0.15)), false)
			if lid:
				WorksModels._mk(done, Res.box(Vector3(0.33, 0.02, 0.17)), "paint", Vector3(bx + 0.02, g + STEP_Y + 0.2, fsgn * 0.43), Vector3(fsgn * 0.6, 0, 0), OLIVE, false)
	if (st.eid + 1) % 3 != 0 and used < spots.size():
		_periscope(st, done, spots[used], fsgn)
		used += 1
	if used < spots.size():
		var x := spots[used]
		var g := grade(st, Vector3(x, 0, -fsgn * 0.5))
		WorksModels._mk(done, Res.box(Vector3(0.17, 0.34, 0.26)), "paint", Vector3(x, g + STEP_Y + 0.17, -fsgn * 0.52), Vector3(0, rng.randf_range(-0.4, 0.4), 0), CAN, false)
	_phone_line(st, done, -fsgn)


## A trench ladder: two rails and the rungs, foot on the duckboards, top on
## the parapet.
static func _ladder(st, done: Node3D, rng: RandomNumberGenerator, x: float, fsgn: float) -> void:
	var g := grade(st, Vector3(x, 0, fsgn * 0.5))
	var foot := Vector3(x, g - 1.05, fsgn * 0.22)
	var head := Vector3(x + rng.randf_range(-0.05, 0.05), g + 0.42, fsgn * (TrenchNet.HALF_W + 0.16))
	var up := (head - foot).normalized()
	var across := Vector3.RIGHT
	var wood := Color(0.42, 0.33, 0.22)
	for e in [-0.21, 0.21]:
		WorksModels._beam(done, (foot + head) * 0.5 + across * e, up, across, Vector3(0.05, 0.07, foot.distance_to(head)), "wood", wood)
	for r in 6:
		var p := foot.lerp(head, (r + 0.6) / 6.6)
		WorksModels._mk(done, Res.box(Vector3(0.46, 0.035, 0.045)), "wood", p, Vector3.ZERO, wood.darkened(0.1), false)


## The sentry's box periscope, propped on the fire step against the front wall
## with its head just over the top of the bags.
static func _periscope(st, done: Node3D, x: float, fsgn: float) -> void:
	var g := grade(st, Vector3(x, 0, fsgn * 0.6))
	var col := Color(0.32, 0.3, 0.23)
	WorksModels._mk(done, Res.box(Vector3(0.08, 1.58, 0.12)), "paint", Vector3(x, g + STEP_Y + 0.79, fsgn * 0.62), Vector3(fsgn * 0.06, 0, 0), col, false)
	WorksModels._mk(done, Res.box(Vector3(0.09, 0.1, 0.16)), "paint", Vector3(x, g + STEP_Y + 1.6, fsgn * 0.68), Vector3(fsgn * 0.06, 0, 0), col, false)
	var glass := Res.mi(done, Res.box(Vector3(0.06, 0.05, 0.01)), Res.mat(Color(0.18, 0.22, 0.24), 0.15), Vector3(x, g + STEP_Y + 1.6, fsgn * 0.765), Vector3.ZERO, false)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The field telephone line, run along the back wall on pegs, sagging between them.
static func _phone_line(st, done: Node3D, side: float) -> void:
	var half: float = st.size.x * 0.5 - 0.25
	var z := side * (TrenchNet.HALF_W - 0.1)
	var pts := PackedVector3Array()
	var pegs := maxi(2, ceili(half * 2.0 / 1.5))
	for i in pegs + 1:
		var x := -half + half * 2.0 * i / pegs
		var g := grade(st, Vector3(x, 0, z))
		pts.append(Vector3(x, g - 0.32, z))
		if i < pegs:
			var mid := -half + half * 2.0 * (i + 0.5) / pegs
			pts.append(Vector3(mid, grade(st, Vector3(mid, 0, z)) - 0.4, z))
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	BuildingWire.strand(v, n, pts, 0.007)
	var line := WorksModels._mk(done, WorksModels._commit(v, n), "rubber", Vector3.ZERO, Vector3.ZERO, WIRE, false)
	line.name = "PhoneLine"


# --- recesses ------------------------------------------------------------------------

## A dugout entrance in the back of the recess: a timber door frame under a
## roof of logs and bags, the stairs going down into the dark, the gas blanket
## rolled up over the door and a threshold board worn by boots.
static func _dugout(st, done: Node3D, rng: RandomNumberGenerator, rear: float, bags: Array) -> void:
	var g := grade(st, Vector3(0, 0, rear * 1.5))
	var wood := Color(0.36, 0.28, 0.19)
	var door_z := rear * 1.76
	for x in [-0.56, 0.56]:
		WorksModels._mk(done, Res.box(Vector3(0.15, 1.5, 0.15)), "wood_dark", Vector3(x, g - 0.47, door_z), Vector3(0, 0, rng.randf_range(-0.02, 0.02)), wood, false)
	WorksModels._mk(done, Res.cyl(0.1, 0.1, 1.5, 8), "bark", Vector3(0, g + 0.3, door_z), Vector3(0, 0, PI * 0.5), wood.darkened(0.15))
	# the stairway: dark beyond the frame, a step catching the light at the door
	var dark := Res.mi(done, Res.box(Vector3(0.98, 1.4, 0.03)), Res.mat(Color(0.012, 0.011, 0.009), 1.0, 0.0, true), Vector3(0, g - 0.5, door_z + rear * 0.09), Vector3.ZERO, false)
	dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# lamplight from the bottom of the stairs, catching the last steps
	var glow := Res.mi(done, Res.box(Vector3(0.7, 0.32, 0.02)), Res.mat(Color(0.3, 0.17, 0.07), 1.0, 0.0, true), Vector3(0, g - 1.0, door_z + rear * 0.07), Vector3.ZERO, false)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WorksModels._mk(done, Res.box(Vector3(0.95, 0.06, 0.3)), "wood_dark", Vector3(0, g - 1.13, door_z - rear * 0.12), Vector3.ZERO, wood.darkened(0.1), false)
	# the gas blanket, rolled and tied over the door, a corner hanging loose
	WorksModels._mk(done, Res.cyl(0.075, 0.075, 1.0, 8), "canvas", Vector3(0, g + 0.13, door_z - rear * 0.11), Vector3(0, 0, PI * 0.5), Color(0.32, 0.3, 0.22), false)
	WorksModels._mk(done, Res.box(Vector3(0.26, 0.55, 0.015)), "canvas", Vector3(0.33, g - 0.17, door_z - rear * 0.12), Vector3(rear * 0.05, 0, 0.06), Color(0.3, 0.28, 0.2), false)
	# the roof: logs across the recess, the spoil thrown back over them and a
	# course of bags along its front edge
	for i in 8:
		var x := -0.7 + i * 0.2
		WorksModels._mk(done, Res.cyl(0.085, 0.09, 1.55, 7), "bark", Vector3(x, g + 0.36 + rng.randf_range(-0.02, 0.02), rear * 1.42), Vector3(PI * 0.5, rng.randf_range(-0.04, 0.04), 0), wood.darkened(rng.randf_range(0.0, 0.2)))
	_soil_cap(done, Vector3(0, g + 0.47, rear * 1.5), Vector3(0.3, 0.42, 0.24), st.eid)
	bags.append({"p": Vector3(0, g + 0.52, rear * 0.82), "s": Vector3(1.5, 0.19, 0.38), "r": 0.0})
	# a signboard on the post, chalked with the dugout's number
	WorksModels._mk(done, Res.box(Vector3(0.36, 0.16, 0.02)), "wood", Vector3(-0.5, g - 0.05, door_z - rear * 0.09), Vector3(0, 0, rng.randf_range(-0.08, 0.08)), Color(0.55, 0.5, 0.4), false)


## A funk hole: a resting bay scraped under the back wall, a few boards over
## it on bearers, a groundsheet on the floor.
static func _funk_hole(st, done: Node3D, rng: RandomNumberGenerator, rear: float) -> void:
	var g := grade(st, Vector3(0, 0, rear * 1.4))
	var wood := Res.mat(Structure.C_WOOD.darkened(0.25))
	Res.mi(done, Res.box(Vector3(1.2, 0.1, 0.48)), wood, Vector3(0, g - 0.7, rear * 1.55), Vector3.ZERO, false)
	for x in [-0.66, 0.66]:
		Res.mi(done, Res.box(Vector3(0.09, 1.35, 0.09)), wood, Vector3(x, g - 0.42, rear * 1.7), Vector3.ZERO, false)
	for board in 8:
		Res.mi(done, Res.box(Vector3(0.18, 0.1, 1.1)), Mats.get_mat("wood"), Vector3(-0.66 + board * 0.19, g + 0.3 + rng.randf_range(-0.018, 0.018), rear * 1.4), Vector3(0, rng.randf_range(-0.025, 0.025), 0.04), false)
	for x in [-0.55, 0.55]:
		Res.mi(done, Res.box(Vector3(0.12, 0.13, 1.18)), wood, Vector3(x, g + 0.18, rear * 1.4), Vector3.ZERO, false)
	Res.mi(done, Res.box(Vector3(0.9, 0.12, 0.4)), Res.mat(Color(0.29, 0.31, 0.23)), Vector3(0, g - 0.59, rear * 1.55), Vector3.ZERO, false)
	_litter(st, done, rng, rear)


## A shelf cut into the back of the recess, stores on it.
static func _shelf(st, done: Node3D, rng: RandomNumberGenerator, rear: float) -> void:
	var g := grade(st, Vector3(0, 0, rear * 1.4))
	var wood := Res.mat(Structure.C_WOOD.darkened(0.25))
	Res.mi(done, Res.box(Vector3(1.2, 0.1, 0.48)), wood, Vector3(0, g - 0.7, rear * 1.55), Vector3.ZERO, false)
	for x in [-0.33, 0.3]:
		Res.mi(done, Res.box(Vector3(0.45, 0.26, 0.3)), Res.mat(Color(0.25, 0.28, 0.2)), Vector3(x, g - 0.52, rear * 1.55), Vector3.ZERO, false)
	WorksModels._mk(done, Res.box(Vector3(0.17, 0.34, 0.26)), "paint", Vector3(0.45, g - 1.03, rear * 1.6), Vector3(0, 0.3, 0), CAN, false)
	_litter(st, done, rng, rear)


static func _litter(st, done: Node3D, rng: RandomNumberGenerator, rear: float) -> void:
	for i in 3:
		var p := Vector3(rng.randf_range(-0.5, 0.5), 0, rear * rng.randf_range(1.0, 1.6))
		p.y = grade(st, p) - 1.13
		Res.mi(done, Res.box(Vector3(0.13, 0.025, 0.18)), Res.mat(Color(0.31, 0.27, 0.19)), p, Vector3(0, rng.randf() * TAU, 0), false)


# --- machine-gun emplacements ---------------------------------------------------------------

## A machine gun dug into the front of a trench, roofed over: posts in the
## trench and behind the parapet carry a roof of logs under bags and soil, so
## splinters and the weather stay off the gun and its crew. The gun fires
## through the long embrasure between the front bags and the roof; the bags
## either side of it close the arc down to the gun's traverse. The gunner
## stands in the trench behind, his head under the back edge of the roof.
static func mg_bay(model: Node3D, st, heavy: bool, rng: RandomNumberGenerator, bags: Array) -> void:
	var pz: float = st.mg_pivot_local().z
	var roof_y := 0.86 if heavy else 0.76
	var wood := Color(0.36, 0.28, 0.19)
	var back := -(TrenchNet.HALF_W - 0.12)
	var front := pz - 0.95
	for x in [-1.1, 1.1]:
		# the rear posts stand on the trench floor, the front ones behind the bags
		WorksModels._mk(model, Res.box(Vector3(0.14, roof_y + 1.2, 0.14)), "wood_dark", Vector3(x, (roof_y - 1.2) * 0.5, back), Vector3.ZERO, wood)
		WorksModels._mk(model, Res.box(Vector3(0.14, roof_y, 0.14)), "wood_dark", Vector3(x, roof_y * 0.5, front + 0.3), Vector3.ZERO, wood)
	for z in [back, front + 0.3]:
		WorksModels._mk(model, Res.cyl(0.08, 0.08, 2.5, 7), "bark", Vector3(0, roof_y - 0.02, z), Vector3(0, 0, PI * 0.5), wood.darkened(0.1))
	var logs := 9
	for i in logs:
		var z := back + (front - back) * (i + 0.5) / logs
		WorksModels._mk(model, Res.cyl(0.075, 0.085, 2.75, 7), "bark", Vector3(rng.randf_range(-0.05, 0.05), roof_y + 0.08, z), Vector3(rng.randf_range(-0.02, 0.02), 0, PI * 0.5), wood.darkened(rng.randf_range(0.0, 0.2)))
	# earth over the logs, a row of bags holding its front edge above the slit
	_soil_cap(model, Vector3(0, roof_y + 0.17, (back + front) * 0.5 - 0.05), Vector3(0.47, 0.55, 0.3), st.eid)
	bags.append({"p": Vector3(0, roof_y + 0.25, front + 0.1), "s": Vector3(2.4, 0.19, 0.4), "r": 0.0})
	# the cheeks of the embrasure, up to the roof either side of the gun's arc,
	# and the side walls back to the trench, so it opens only to the front
	var lip := -(TrenchNet.HALF_W + 0.15)
	for e in [-1.0, 1.0]:
		bags.append({"p": Vector3(e * 1.02, 0.3 + (roof_y - 0.3) * 0.5, front + 0.18), "s": Vector3(0.62, roof_y - 0.32, 0.55), "r": 0.0})
		bags.append({"p": Vector3(e * 1.25, roof_y * 0.5, (front + 0.45 + lip) * 0.5), "s": Vector3(0.45, roof_y - 0.02, absf(lip - front - 0.45)), "r": 0.0})
	# a strip of hessian hung under the front of the roof to hide the muzzle flash
	WorksModels._mk(model, Res.box(Vector3(1.8, 0.12, 0.012)), "canvas", Vector3(0, roof_y - 0.08, front - 0.06), Vector3(0.12, 0, 0), Color(0.38, 0.33, 0.24), false)


## Soil thrown over a roof of logs (WorksModels.roof_soil, scaled to the roof).
static func _soil_cap(parent: Node3D, p: Vector3, scale: Vector3, eid: int) -> void:
	var mound := WorksModels._mk(parent, WorksModels.roof_soil(posmod(eid, 4)), "bank", p, Vector3.ZERO, Color(0.29, 0.27, 0.17))
	mound.scale = scale
	mound.material_override = TrenchNet.bank_material()
