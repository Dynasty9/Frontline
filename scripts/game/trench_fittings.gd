class_name TrenchFittings
## Fittings for a finished fire trench, after the digging (view only).
##
## A dug trench is only a ditch until it is fitted out. Field manuals from 1916
## to the trenches round Bakhmut describe the same work: the cut walls are
## revetted so they don't slump (planks behind posts, or corrugated iron on
## pickets), the spoil in front is faced with a low wall of sandbags to fire
## over, and scaling ladders lean on the front wall for going over. Ammunition
## sits on the fire step and the field telephone line runs along the back
## wall. In the rear recesses: dugout entrances, a timber frame in the back
## wall with the stairs going down, a gas blanket rolled over the door;
## roofed funk holes; supply shelves.
##
## Kept plain on purpose: a few things that read clearly from the camera, not
## every item a real bay held.
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

enum Revet { TIMBER, IRON }
enum Recess { DUGOUT, FUNK_HOLE, SHELF }


## How this section's walls are held up: mostly planks, every third section
## corrugated iron (a line is revetted a bay at a time, with what came up).
static func revetment(st) -> int:
	return Revet.IRON if posmod(st.eid, 3) == 0 else Revet.TIMBER


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
## bay dug into it: its own bags stand there, not the bay's parapet and kit.
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
	if fire_bay(st):
		var guns := gun_bays(st)
		_parapet(st, bags, rng, fsgn, guns)
		_bay_kit(st, done, rng, fsgn, guns)
	elif st.size.x >= 5.0:
		# a communication trench: just the telephone line
		_phone_line(st, done, -fsgn)
	if TrenchNet.has_recess(st):
		match recess(st):
			Recess.DUGOUT:
				_dugout(st, done, rng, -fsgn)
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


# --- parapet -----------------------------------------------------------------------------

## The front lip faced with sandbags: a low wall two bags high, laid in runs
## of about a metre so it beds into the lie of the spoil, set back from the
## edge so the cut doesn't crumble under it.
static func _parapet(st, bags: Array, rng: RandomNumberGenerator, fsgn: float, guns: Array) -> void:
	var half: float = st.size.x * 0.5 - 0.35
	var z := fsgn * (TrenchNet.HALF_W + 0.42)
	var runs := maxi(1, ceili(half * 2.0 / 1.1))
	var run_len := half * 2.0 / runs
	for i in runs:
		var x := -half + (i + 0.5) * run_len
		var bag := {"p": Vector3(x, grade(st, Vector3(x, 0, z)) + PARAPET_Y + 0.15, z), "s": Vector3(run_len, 0.3, 0.36), "r": rng.randf_range(-0.02, 0.02)}
		if WorksModels.trench_backed(st, bag.p, run_len * 0.5) and _clear(guns, x, run_len * 0.5):
			bags.append(bag)


# --- along the bay -------------------------------------------------------------------

## A ladder for going over, ammunition boxes on the fire step and the
## telephone line along the back wall.
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

## A dugout entrance in the back of the recess: a timber door frame in the
## wall under the bay's plank roof, the stairs going down into the dark, the
## gas blanket rolled up over the door and a threshold board worn by boots.
## The dugout itself is mined deep under the ground behind, so nothing of it
## shows above the surface.
static func _dugout(st, done: Node3D, rng: RandomNumberGenerator, rear: float) -> void:
	var g := grade(st, Vector3(0, 0, rear * 1.5))
	var wood := Color(0.36, 0.28, 0.19)
	var door_z := rear * 1.76
	for x in [-0.56, 0.56]:
		WorksModels._mk(done, Res.box(Vector3(0.15, 1.36, 0.15)), "wood_dark", Vector3(x, g - 0.54, door_z), Vector3(0, 0, rng.randf_range(-0.02, 0.02)), wood, false)
	WorksModels._mk(done, Res.cyl(0.1, 0.1, 1.5, 8), "bark", Vector3(0, g + 0.1, door_z), Vector3(0, 0, PI * 0.5), wood.darkened(0.15))
	# the stairway: dark beyond the frame, a step catching the light at the door
	var dark := Res.mi(done, Res.box(Vector3(0.98, 1.25, 0.03)), Res.mat(Color(0.012, 0.011, 0.009), 1.0, 0.0, true), Vector3(0, g - 0.6, door_z + rear * 0.09), Vector3.ZERO, false)
	dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WorksModels._mk(done, Res.box(Vector3(0.95, 0.06, 0.3)), "wood_dark", Vector3(0, g - 1.13, door_z - rear * 0.12), Vector3.ZERO, wood.darkened(0.1), false)
	# the gas blanket, rolled and tied up over the door
	WorksModels._mk(done, Res.cyl(0.07, 0.07, 1.0, 8), "canvas", Vector3(0, g + 0.02, door_z - rear * 0.11), Vector3(0, 0, PI * 0.5), Color(0.32, 0.3, 0.22), false)


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
