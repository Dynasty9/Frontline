class_name TrenchFittings
## Fittings for a finished fire trench, after the digging (view only).
##
## Modelled on the field positions dug since 2022 rather than a 1916 manual:
## nobody revets a whole line to one pattern. Walls are left as raw earth
## where the clay stands, and shored where it slumps with whatever the
## position could get: logs cut from the tree line stacked behind stakes,
## pallets stood on edge, odd planks, a sheet of OSB or roofing iron. Bags go
## where a rifle or a gun works from, in loose heaps, not tidy walls; they are
## whatever colour the depot had, all of it the colour of the mud within a
## week. The floor collects what a section lives on: ammunition tins, water bottles,
## ration packs, cardboard, a spent launcher tube. Dugout doors are a frame of
## logs with a tarpaulin hung over the opening.
##
## Everything here is drawn from the section's id, so host and client see the
## same trench, and only on the "Done" node, so it shows once the section is
## finished and intact.

const PANEL := 1.8  # the walls are shored (or not) a stretch this long at a time
const STEP_Y := -0.9  # the top of the fire step, against a full-depth wall
const FLOOR_Y := -1.17  # the trench floor, against a full-depth wall
const PARAPET_Y := 0.06  # where the bags bed into the spoil above the lip
const CAN := Color(0.27, 0.3, 0.2)
const WIRE := Color(0.08, 0.08, 0.07)
const LOG := Color(0.4, 0.32, 0.23)

## What a section's shored stretches are mostly made of: cut logs, or salvage
## (pallets, planks, sheets) where there's no wood line near.
enum Revet { LOGS, SALVAGE }
enum Recess { DUGOUT, FUNK_HOLE, SHELF }


## What this section's shoring mostly is (neighbours differ: each was dug and
## shored by whoever held it, with what came up).
static func revetment(st) -> int:
	return Revet.SALVAGE if posmod(st.eid * 7 + 3, 5) < 2 else Revet.LOGS


## What fills a section's rear recess (see TrenchNet.has_recess).
static func recess(st) -> int:
	return TrenchNet.recess_kind(st)


## A section running across the enemy's front is a fire bay, with firing
## points; one running towards him (a communication trench, a traverse) is not.
static func fire_bay(st) -> bool:
	if st.size.x < 5.0:
		return false
	var axis: Vector3 = Basis(Vector3.UP, st.yaw) * Vector3.RIGHT
	var enemy := Vector3(0, 0, -1) if st.team == 0 else Vector3(0, 0, 1)
	return absf(axis.dot(enemy)) < 0.6


## Stretches of the section (local x, [from, to]) taken up by a machine-gun
## bay dug into it: its own bags stand there, not the section's.
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


## Fits the finished section out: shoring, firing points, what lies about
## and its recess. Returns the sandbags to lay (Structure._bag_walls).
static func furnish(st, done: Node3D, rng: RandomNumberGenerator) -> Array:
	var bags: Array = []
	var fsgn: float = st._enemy_side()
	_shore(st, done, rng)
	var guns := gun_bays(st)
	if fire_bay(st):
		_firing_points(st, bags, rng, fsgn, guns)
	if st.size.x >= 5.0:
		_strays(st, bags, rng, fsgn)
		_debris(st, done, rng, fsgn, guns)
		_phone_line(st, done, -fsgn, rng)
	if TrenchNet.has_recess(st):
		match recess(st):
			Recess.DUGOUT:
				_dugout(st, done, rng, -fsgn)
			Recess.FUNK_HOLE:
				_funk_hole(st, done, rng, -fsgn)
			Recess.SHELF:
				_shelf(st, done, rng, -fsgn)
	return bags


# --- shoring -----------------------------------------------------------------------------

## Where the stretches go along each wall: [x of the middle, side], skipping
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


## Each stretch of wall is shored with what was to hand, or not at all.
static func _shore(st, done: Node3D, rng: RandomNumberGenerator) -> void:
	var basis := Basis(Vector3.UP, st.yaw)
	var logs := revetment(st) == Revet.LOGS
	for panel in _panels(st):
		var middle: float = panel[0] + rng.randf_range(-0.25, 0.25)
		var side: float = panel[1]
		var point: Vector3 = st.position + basis * Vector3(middle, 0, side * TrenchNet.HALF_W)
		var edge := WorksModels._shoring_edge(point, basis.x)
		var g := grade(st, Vector3(middle, 0, side))
		var roll := rng.randf()
		if roll < 0.32:
			continue  # the clay stands here: raw earth
		roll = (roll - 0.32) / 0.68
		if logs:
			if roll < 0.7:
				_log_wall(done, rng, middle, side, edge, g)
			elif roll < 0.85:
				_planks(done, rng, middle, side, edge, g)
			else:
				_pallet_wall(done, rng, middle, side, edge, g)
		else:
			if roll < 0.4:
				_pallet_wall(done, rng, middle, side, edge, g)
			elif roll < 0.65:
				_sheet(done, rng, middle, side, edge, g)
			elif roll < 0.85:
				_planks(done, rng, middle, side, edge, g)
			else:
				_log_wall(done, rng, middle, side, edge, g)


## Logs cut from the tree line, laid one on another against the cut and held
## by two stakes driven into the floor; crooked, of no one thickness, the top
## one or two often not there.
static func _log_wall(done: Node3D, rng: RandomNumberGenerator, x: float, side: float, edge: float, g: float) -> void:
	var length := rng.randf_range(1.4, 2.0)
	var y := g + FLOOR_Y
	var rows := rng.randi_range(3, 6)
	for row in rows:
		var r := rng.randf_range(0.055, 0.09)
		y += r
		if y > g - 0.1:
			break
		var col := LOG.darkened(rng.randf_range(0.0, 0.3)).lerp(Color(0.33, 0.29, 0.22), rng.randf_range(0.0, 0.4))
		var lx := x + rng.randf_range(-0.15, 0.15)
		var l := length * rng.randf_range(0.85, 1.05)
		WorksModels._mk(done, Res.cyl(r * rng.randf_range(0.85, 1.0), r, l, 7), "bark", Vector3(lx, y, side * (edge + r * 0.5)),
			Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.04, 0.04), PI * 0.5 + rng.randf_range(-0.05, 0.05)), col, false)
		y += r * rng.randf_range(0.8, 0.95)
	for e in [-1.0, 1.0]:
		var sx: float = x + e * length * rng.randf_range(0.38, 0.47)
		var top := g + rng.randf_range(-0.25, 0.12)
		var foot := Vector3(sx, g + FLOOR_Y - 0.05, side * (edge - 0.07))
		var head := Vector3(sx + rng.randf_range(-0.06, 0.06), top, side * (edge - 0.07 + rng.randf_range(0.0, 0.08)))
		WorksModels._rod(done, foot, head, rng.randf_range(0.035, 0.05), "bark", LOG.darkened(0.2), 6, false)


## A pallet or two stood on edge against the wall, slats out, leaning back on it.
static func _pallet_wall(done: Node3D, rng: RandomNumberGenerator, x: float, side: float, edge: float, g: float) -> void:
	var count := rng.randi_range(1, 2)
	var wood := Color(0.56, 0.5, 0.4).darkened(rng.randf_range(0.0, 0.3))
	for k in count:
		var px := x + (k - (count - 1) * 0.5) * 1.15 + rng.randf_range(-0.1, 0.1)
		var h := rng.randf_range(0.95, 1.12)
		var lean := side * rng.randf_range(0.04, 0.12)
		var holder := Node3D.new()
		holder.position = Vector3(px, g + FLOOR_Y, side * (edge - 0.05))
		holder.rotation = Vector3(lean, rng.randf_range(-0.06, 0.06), rng.randf_range(-0.03, 0.03))
		done.add_child(holder)
		var c := wood.darkened(rng.randf_range(0.0, 0.12))
		# the slats facing the trench, one or two missing or split
		var slats := 5
		for s in slats:
			if rng.randf() < 0.12:
				continue
			var sy := 0.06 + s * (h - 0.12) / (slats - 1)
			WorksModels._mk(holder, Res.box(Vector3(1.15 * rng.randf_range(0.9, 1.0), 0.1, 0.022)), "wood", Vector3(0, sy, -side * 0.01), Vector3(0, 0, rng.randf_range(-0.02, 0.02)), c, false)
		for s in 3:
			WorksModels._mk(holder, Res.box(Vector3(0.09, h, 0.09)), "wood", Vector3(-0.52 + s * 0.52, h * 0.5, side * 0.06), Vector3.ZERO, c.darkened(0.15), false)


## Odd planks of no one length across the wall behind two posts, gaps between.
static func _planks(done: Node3D, rng: RandomNumberGenerator, x: float, side: float, edge: float, g: float) -> void:
	var y := g + FLOOR_Y + rng.randf_range(0.05, 0.15)
	var wood := Color(0.42, 0.36, 0.28)
	while y < g - 0.25:
		var h := rng.randf_range(0.12, 0.24)
		var l := rng.randf_range(0.9, 1.9)
		WorksModels._mk(done, Res.box(Vector3(l, h, 0.03)), "fence_rail", Vector3(x + rng.randf_range(-0.25, 0.25), y + h * 0.5, side * (edge + 0.02)),
			Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.06, 0.06)), wood.darkened(rng.randf_range(0.0, 0.3)), false)
		y += h + rng.randf_range(0.0, 0.12)
	for e in [-1.0, 1.0]:
		var px: float = x + e * rng.randf_range(0.5, 0.8)
		var ph := rng.randf_range(0.9, 1.2)
		WorksModels._mk(done, Res.box(Vector3(0.08, ph, 0.08)), "wood", Vector3(px, g + FLOOR_Y + ph * 0.5, side * (edge - 0.04)), Vector3(side * rng.randf_range(0.0, 0.08), 0, rng.randf_range(-0.08, 0.08)), wood.darkened(0.2), false)


## A sheet of OSB or roofing iron stood against the wall, held by a stake.
static func _sheet(done: Node3D, rng: RandomNumberGenerator, x: float, side: float, edge: float, g: float) -> void:
	var iron := rng.randf() < 0.45
	var w := rng.randf_range(1.0, 1.25)
	var h := rng.randf_range(0.9, 1.15)
	var col: Color
	if iron:
		col = WorksModels.RUST.lightened(rng.randf_range(0.0, 0.25)) if rng.randf() < 0.6 else Color(0.4, 0.41, 0.39).darkened(rng.randf_range(0.0, 0.25))
	else:
		col = Color(0.6, 0.5, 0.34).darkened(rng.randf_range(0.05, 0.35))
	WorksModels._mk(done, Res.box(Vector3(w, h, 0.02)), "corrugated" if iron else "wood", Vector3(x, g + FLOOR_Y + h * 0.5, side * (edge + 0.03)),
		Vector3(side * rng.randf_range(0.04, 0.12), rng.randf_range(-0.08, 0.08), rng.randf_range(-0.05, 0.05)), col, false)
	var sx := x + w * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0) * 0.8
	WorksModels._rod(done, Vector3(sx, g + FLOOR_Y - 0.05, side * (edge - 0.05)), Vector3(sx, g + rng.randf_range(-0.3, 0.0), side * (edge - 0.03)), 0.035, "bark", LOG.darkened(0.25), 6, false)


# --- bags -----------------------------------------------------------------------------------

## Where a rifleman or a gunner works from, a loose heap of bags on the lip:
## two or three firing points to a bay, never a continuous wall.
static func _firing_points(st, bags: Array, rng: RandomNumberGenerator, fsgn: float, guns: Array) -> void:
	var half: float = st.size.x * 0.5 - 0.9
	var points := rng.randi_range(1, 3)
	for i in points:
		var cx := -half + (i + rng.randf_range(0.2, 0.8)) * half * 2.0 / points
		if not _clear(guns, cx, 0.9) or (TrenchNet.has_recess(st) and absf(cx) < 1.0 and rng.randf() < 0.5):
			continue
		var width := rng.randf_range(0.9, 1.6)
		var z := fsgn * (TrenchNet.HALF_W + rng.randf_range(0.3, 0.5))
		var count := rng.randi_range(4, 9)
		for k in count:
			var t := (k + rng.randf_range(0.0, 1.0)) / count - 0.5
			var bx := cx + t * width
			var bz := z + fsgn * rng.randf_range(-0.12, 0.2)
			# the middle of the heap a course higher, with a gap to shoot through
			var course := 1 if absf(t) > 0.12 and absf(t) < 0.42 and rng.randf() < 0.6 else 0
			_loose_bag(st, bags, rng, Vector3(bx, 0, bz), course)


## A few bags lying about: on the spoil, half off it, one dropped in the trench.
static func _strays(st, bags: Array, rng: RandomNumberGenerator, fsgn: float) -> void:
	var half: float = st.size.x * 0.5 - 0.8
	for i in rng.randi_range(0, 3):
		var side: float = fsgn if rng.randf() < 0.4 else -fsgn
		var p := Vector3(rng.randf_range(-half, half), 0, side * (TrenchNet.HALF_W + rng.randf_range(0.35, 1.2)))
		_loose_bag(st, bags, rng, p, 0)


## One filled bag lying where it was dropped: turned any way, slumped and tilted.
static func _loose_bag(st, bags: Array, rng: RandomNumberGenerator, p: Vector3, course: int) -> void:
	if not WorksModels.trench_backed(st, Vector3(p.x, 0, p.z), 0.25):
		return
	p.y = grade(st, p) + PARAPET_Y + 0.07 + course * 0.15
	bags.append({"p": p, "s": Vector3(rng.randf_range(0.46, 0.56), 0.17, rng.randf_range(0.28, 0.34)), "r": rng.randf_range(-0.7, 0.7), "loose": 1.0})


# --- what lies about ---------------------------------------------------------------------------

## What a section lives on, dropped along the floor and the fire step:
## ammunition tins, water bottles, a ration pack, cardboard, a jerrycan, a bit
## of tarpaulin, a spent launcher tube.
static func _debris(st, done: Node3D, rng: RandomNumberGenerator, fsgn: float, guns: Array) -> void:
	var half: float = st.size.x * 0.5 - 0.6
	for i in rng.randi_range(3, 7):
		var x := rng.randf_range(-half, half)
		if not _clear(guns, x, 0.3):
			continue
		# against one wall or the other, clear of the middle where men walk
		var side: float = fsgn if rng.randf() < 0.55 else -fsgn
		var on_step := side == fsgn and rng.randf() < 0.5
		var z := side * (rng.randf_range(0.42, 0.55) if on_step else rng.randf_range(0.36, 0.5))
		var g := grade(st, Vector3(x, 0, z))
		var y := g + (STEP_Y if on_step else FLOOR_Y)
		var yaw := rng.randf() * TAU
		match rng.randi_range(0, 7):
			0, 1:
				# ammunition tins, one or two
				for k in rng.randi_range(1, 2):
					WorksModels._mk(done, Res.box(Vector3(0.28, 0.18, 0.11)), "paint", Vector3(x + k * 0.13, y + 0.09 + k * 0.01, z), Vector3(0, yaw + k * 0.4, 0), Color(0.25, 0.28, 0.19).darkened(rng.randf_range(0.0, 0.2)), false)
			2:
				# water bottles, lying where they rolled
				for k in rng.randi_range(1, 3):
					var bp := Vector3(x + rng.randf_range(-0.2, 0.2), y + 0.035, z + rng.randf_range(-0.08, 0.08))
					WorksModels._mk(done, Res.cyl(0.035, 0.037, 0.28, 8), "paint", bp, Vector3(PI * 0.5, rng.randf() * TAU, 0), Color(0.66, 0.74, 0.78).darkened(rng.randf_range(0.0, 0.25)), false)
			3:
				# a cardboard box, sagging
				var s := Vector3(rng.randf_range(0.3, 0.45), rng.randf_range(0.14, 0.24), rng.randf_range(0.22, 0.32))
				WorksModels._mk(done, Res.box(s), "canvas", Vector3(x, y + s.y * 0.45, z), Vector3(rng.randf_range(-0.08, 0.08), yaw, rng.randf_range(-0.08, 0.08)), Color(0.55, 0.45, 0.31).darkened(rng.randf_range(0.0, 0.3)), false)
			4:
				# a jerrycan
				WorksModels._mk(done, Res.box(Vector3(0.17, 0.34, 0.27)), "paint", Vector3(x, y + 0.17, z), Vector3(0, yaw, 0), Color(0.24, 0.28, 0.18), false)
			5:
				# a piece of tarpaulin trodden into the mud
				WorksModels._mk(done, Res.box(Vector3(rng.randf_range(0.6, 1.0), 0.015, rng.randf_range(0.3, 0.5))), "canvas", Vector3(x, y + 0.02, z), Vector3(rng.randf_range(-0.12, 0.12), yaw, rng.randf_range(-0.1, 0.1)), Color(0.19, 0.23, 0.16), false)
			6:
				# ration packs
				for k in rng.randi_range(1, 3):
					WorksModels._mk(done, Res.box(Vector3(0.18, 0.04, 0.12)), "canvas", Vector3(x + rng.randf_range(-0.15, 0.15), y + 0.02 + k * 0.035, z + rng.randf_range(-0.06, 0.06)), Vector3(0, rng.randf() * TAU, 0), Color(0.45, 0.38, 0.25).darkened(rng.randf_range(0.0, 0.2)), false)
			7:
				# a spent launcher tube, thrown down
				WorksModels._mk(done, Res.cyl(0.05, 0.05, 0.95, 10), "paint", Vector3(x, y + 0.05, z), Vector3(rng.randf_range(-0.05, 0.05), yaw, PI * 0.5), Color(0.29, 0.32, 0.21), false)


## Field cable along the back wall, hung on a nail here and there, looping
## low between and left lying where it came loose.
static func _phone_line(st, done: Node3D, side: float, rng: RandomNumberGenerator) -> void:
	var half: float = st.size.x * 0.5 - 0.25
	var z := side * (TrenchNet.HALF_W - 0.12)
	var pts := PackedVector3Array()
	var pegs := maxi(2, ceili(half * 2.0 / 1.4))
	for i in pegs + 1:
		var x := -half + half * 2.0 * i / pegs
		var g := grade(st, Vector3(x, 0, z))
		pts.append(Vector3(x, g - rng.randf_range(0.25, 0.6), z))
		if i < pegs:
			var mid := -half + half * 2.0 * (i + 0.5) / pegs
			pts.append(Vector3(mid, grade(st, Vector3(mid, 0, z)) - rng.randf_range(0.5, 0.95), z - side * rng.randf_range(0.0, 0.05)))
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	BuildingWire.strand(v, n, pts, 0.007)
	var line := WorksModels._mk(done, WorksModels._commit(v, n), "rubber", Vector3.ZERO, Vector3.ZERO, WIRE, false)
	line.name = "PhoneLine"


# --- recesses ------------------------------------------------------------------------

## A dugout entrance in the back of the recess: a frame of round logs in the
## wall, more logs laid over it, a tarpaulin hung across the opening and one
## corner hooked back, the stairs going down into the dark behind. The dugout
## itself is dug deep under the ground behind, so nothing of it shows above.
static func _dugout(st, done: Node3D, rng: RandomNumberGenerator, rear: float) -> void:
	var g := grade(st, Vector3(0, 0, rear * 1.5))
	var door_z := rear * 1.76
	for x in [-0.58, 0.58]:
		WorksModels._rod(done, Vector3(x + rng.randf_range(-0.03, 0.03), g + FLOOR_Y - 0.05, door_z), Vector3(x + rng.randf_range(-0.04, 0.04), g + 0.02, door_z), rng.randf_range(0.075, 0.09), "bark", LOG.darkened(rng.randf_range(0.0, 0.2)), 7, false)
	# the lintel and the logs over it, bedded into the spoil
	for k in 3:
		var r := rng.randf_range(0.08, 0.1)
		WorksModels._mk(done, Res.cyl(r * 0.9, r, rng.randf_range(1.5, 1.8), 8), "bark", Vector3(rng.randf_range(-0.08, 0.08), g + 0.06 + k * 0.03, door_z + rear * (k * 0.17 - 0.02)),
			Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.06, 0.06), PI * 0.5), LOG.darkened(rng.randf_range(0.0, 0.25)))
	# the stairway: dark beyond the frame, a worn step at the door
	var dark := Res.mi(done, Res.box(Vector3(1.0, 1.25, 0.03)), Res.mat(Color(0.012, 0.011, 0.009), 1.0, 0.0, true), Vector3(0, g - 0.6, door_z + rear * 0.09), Vector3.ZERO, false)
	dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	WorksModels._mk(done, Res.box(Vector3(0.95, 0.06, 0.3)), "wood_dark", Vector3(0, g - 1.13, door_z - rear * 0.12), Vector3.ZERO, Color(0.3, 0.24, 0.17), false)
	# the tarpaulin over the door, one side hooked back
	var tarp := Color(0.27, 0.3, 0.2).darkened(rng.randf_range(0.0, 0.2))
	var open := 1.0 if rng.randf() < 0.5 else -1.0
	var curtain := WorksModels._mk(done, _curtain(open, float(posmod(st.eid, 13))), "canvas", Vector3(0, g + 0.02, door_z - rear * 0.12), Vector3(0, 0.0 if rear > 0.0 else PI, 0), tarp, false)
	curtain.name = "Curtain"


## A tarpaulin hung from the lintel (top edge at the origin, facing -z):
## folds running down from where it is nailed, the hem dragging on the step,
## one side pulled back and hooked so the opening shows dark behind it.
static func _curtain(open: float, seed: float) -> ArrayMesh:
	var nx := 14
	var ny := 10
	var w := 1.08
	var h := 1.18
	var pos: Array = []
	for j in ny + 1:
		var row: Array = []
		var v := float(j) / ny
		for i in nx + 1:
			var u := float(i) / nx
			var x := (u - 0.5) * w
			# the hooked-back side gathers in towards the hook
			var pull := smoothstep(0.35, 1.0, u if open > 0.0 else 1.0 - u) * smoothstep(0.15, 0.9, v)
			x -= open * pull * 0.42 * (1.0 - absf(v - 0.55))
			var fold := 0.025 * sin(u * 19.0 + seed + v * 1.5) * (0.4 + v) + 0.008 * sin(u * 41.0 - v * 3.0 + seed)
			var z := -fold - 0.05 * pull - 0.06 * v * v
			row.append(Vector3(x, -v * h + 0.03 * sin(u * 9.0 + seed) * v, z))
		pos.append(row)
	return _cloth(pos, nx, ny, Vector3.FORWARD)


## A sheet of cloth from a grid of points (rows of columns), smooth-shaded,
## its front facing `out` (Godot's front faces wind clockwise).
static func _cloth(pos: Array, nx: int, ny: int, out: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in ny:
		for i in nx:
			var q := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = pos[q[tri[0]][1]][q[tri[0]][0]]
				var b: Vector3 = pos[q[tri[1]][1]][q[tri[1]][0]]
				var c: Vector3 = pos[q[tri[2]][1]][q[tri[2]][0]]
				var order: Array = tri
				if (b - a).cross(c - a).dot(out) > 0.0:
					order = [tri[0], tri[2], tri[1]]
				for k in order:
					st.set_uv(Vector2(float(q[k][0]) / nx, float(q[k][1]) / ny))
					st.add_vertex(pos[q[k][1]][q[k][0]])
	st.index()
	st.generate_normals()
	return st.commit()


## A funk hole: a resting bay scraped under the back wall, old boards of no
## one length over it on bearers, a tarpaulin and a few bags thrown on top to
## keep the rain and the splinters off, a groundsheet on the floor.
static func _funk_hole(st, done: Node3D, rng: RandomNumberGenerator, rear: float) -> void:
	var g := grade(st, Vector3(0, 0, rear * 1.4))
	var wood := Res.mat(Structure.C_WOOD.darkened(0.25))
	Res.mi(done, Res.box(Vector3(1.2, 0.1, 0.48)), wood, Vector3(0, g - 0.7, rear * 1.55), Vector3.ZERO, false)
	for x in [-0.66, 0.66]:
		Res.mi(done, Res.box(Vector3(0.09, 1.35, 0.09)), wood, Vector3(x, g - 0.42, rear * 1.7), Vector3.ZERO, false)
	var bx0 := -0.72
	while bx0 < 0.7:
		var bw := rng.randf_range(0.1, 0.22)
		WorksModels._mk(done, Res.box(Vector3(bw, 0.035, rng.randf_range(0.95, 1.25))), "wood", Vector3(bx0 + bw * 0.5, g + 0.27 + rng.randf_range(-0.02, 0.02), rear * (1.4 + rng.randf_range(-0.06, 0.06))),
			Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.08, 0.08), rng.randf_range(-0.04, 0.04)), Color(0.36, 0.33, 0.27).darkened(rng.randf_range(0.0, 0.3)), false)
		bx0 += bw + rng.randf_range(0.0, 0.05)
	# a tarpaulin over the boards, its edges hanging, and bags to hold it down
	WorksModels._mk(done, Res.box(Vector3(rng.randf_range(1.1, 1.4), 0.015, rng.randf_range(0.8, 1.1))), "canvas", Vector3(rng.randf_range(-0.12, 0.12), g + 0.3, rear * 1.42),
		Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.05, 0.05)), Color(0.2, 0.24, 0.16).darkened(rng.randf_range(0.0, 0.25)), false)
	for bx in [-0.55, 0.55]:
		Res.mi(done, Res.box(Vector3(0.12, 0.13, 1.18)), wood, Vector3(bx, g + 0.18, rear * 1.4), Vector3.ZERO, false)
	Res.mi(done, Res.box(Vector3(0.9, 0.12, 0.4)), Res.mat(Color(0.29, 0.31, 0.23)), Vector3(0, g - 0.59, rear * 1.55), Vector3.ZERO, false)
	_litter(st, done, rng, rear)


## A shelf cut into the back of the recess, stores on it.
static func _shelf(st, done: Node3D, rng: RandomNumberGenerator, rear: float) -> void:
	var g := grade(st, Vector3(0, 0, rear * 1.4))
	var wood := Res.mat(Structure.C_WOOD.darkened(0.25))
	Res.mi(done, Res.box(Vector3(1.2, 0.1, 0.48)), wood, Vector3(0, g - 0.7, rear * 1.55), Vector3.ZERO, false)
	for x in [-0.33, 0.3]:
		Res.mi(done, Res.box(Vector3(0.45, 0.26, 0.3)), Res.mat(Color(0.25, 0.28, 0.2)), Vector3(x, g - 0.52, rear * 1.55), Vector3(0, rng.randf_range(-0.2, 0.2), 0), false)
	WorksModels._mk(done, Res.box(Vector3(0.17, 0.34, 0.26)), "paint", Vector3(0.45, g - 1.03, rear * 1.6), Vector3(0, 0.3, 0), CAN, false)
	_litter(st, done, rng, rear)


static func _litter(st, done: Node3D, rng: RandomNumberGenerator, rear: float) -> void:
	for i in 3:
		var p := Vector3(rng.randf_range(-0.5, 0.5), 0, rear * rng.randf_range(1.0, 1.6))
		p.y = grade(st, p) - 1.13
		Res.mi(done, Res.box(Vector3(0.13, 0.025, 0.18)), Res.mat(Color(0.31, 0.27, 0.19)), p, Vector3(0, rng.randf() * TAU, 0), false)
