class_name PhysicsFx
extends Node3D
## Real physics for things the battle doesn't hinge on, run on every client:
## ragdolls for the dead, chunks of earth, brick and timber thrown by blasts,
## and wrecks, cars and crates tossed through the air. The server sends the
## impulses and, for anything that changes the battlefield (a wreck, a car
## blown across the street), where it ends up: the flight is physics, then it
## settles onto that spot so every player sees the same battlefield.
##
## The ground is a 1 m heightfield with the trench network cut into it, so a
## body or a clod thrown into a trench falls in. Bodies collide with every wall,
## house and sandbag (layer L_COVER) and with each other.

const L_RAGDOLL := 16
const L_GROUND := 32
const MAX_RAGDOLLS := 16
const MAX_CHUNKS := 90
const GROUND_N := MapDims.N + 1

var world
var ground: StaticBody3D
var _hm: HeightMapShape3D
var _mat: PhysicsMaterial
var _chunk_mat: PhysicsMaterial
var ragdolls: Array = []
var _chunks: Array = []  # [body, visual, prev, curr, t, life]
var _tosses: Array = []  # [body, model, owner, final local transform, prev, curr, t, offset, blend from]


func _init(w) -> void:
	world = w


func _ready() -> void:
	_mat = PhysicsMaterial.new()
	_mat.friction = 0.9
	_mat.bounce = 0.05
	_chunk_mat = PhysicsMaterial.new()
	_chunk_mat.friction = 0.8
	_chunk_mat.bounce = 0.25
	ground = StaticBody3D.new()
	ground.collision_layer = L_GROUND
	ground.collision_mask = 0
	ground.physics_material_override = _mat
	var cs := CollisionShape3D.new()
	_hm = HeightMapShape3D.new()
	_hm.map_width = GROUND_N
	_hm.map_depth = GROUND_N
	var data := PackedFloat32Array()
	data.resize(GROUND_N * GROUND_N)
	data.fill(0.0)
	_hm.map_data = data
	cs.shape = _hm
	ground.add_child(cs)
	add_child(ground)


var _hdata := PackedFloat32Array()
var _mask := PackedByteArray()
## The ground samples (x0, z0, x1, z1, inclusive) waiting to be redone (x0 < 0:
## none). Changes that come in together are redone in one go, at the end of
## the frame: the first frame of a battle brings two over the whole map (the
## shell holes and riverbeds the map was made with, and the trenches).
var _pend := Rect2i(-1, 0, 0, 0)
var _job: HeightsJob = null  # a big redo, under way on a worker thread
var _task := -1
## A redo over more samples than this goes to a worker thread: the whole map
## is a million, about a second of script.
const BIG := 40000


## Cuts the trench network into the ground (called when the network changes);
## only the area that changed (metres) is redone, all of it when that is empty.
func update_ground(mask: PackedByteArray, area := Rect2()) -> void:
	_mask = mask
	var full := _hdata.size() != GROUND_N * GROUND_N or not area.has_area()
	if full:
		_redo(0, 0, GROUND_N - 1, GROUND_N - 1)
		return
	var h := (GROUND_N - 1) * 0.5
	_redo(clampi(floori(area.position.x + h), 0, GROUND_N - 1), clampi(floori(area.position.y + h), 0, GROUND_N - 1),
		clampi(ceili(area.end.x + h), 0, GROUND_N - 1), clampi(ceili(area.end.y + h), 0, GROUND_N - 1))


## Follows the shell holes (rect in terrain height samples).
func update_deform(r: Rect2i) -> void:
	var k := TerrainMap.DRES
	_redo(clampi(r.position.x / k, 0, GROUND_N - 1), clampi(r.position.y / k, 0, GROUND_N - 1),
		clampi(r.end.x / k + 1, 0, GROUND_N - 1), clampi(r.end.y / k + 1, 0, GROUND_N - 1))


## Samples x0..x1, z0..z1 are to be redone: at the end of the frame, with
## whatever else comes in before then.
func _redo(x0: int, z0: int, x1: int, z1: int) -> void:
	if _pend.position.x < 0:
		_pend = Rect2i(x0, z0, x1 - x0, z1 - z0)
		if _task < 0:
			_flush.call_deferred()
	else:
		_pend = _pend.merge(Rect2i(x0, z0, x1 - x0, z1 - z0))


func _flush() -> void:
	if _task >= 0 or _pend.position.x < 0:
		return  # (a worker is on it: what came in since goes after, see _process)
	if _hdata.size() != GROUND_N * GROUND_N:
		_hdata.resize(GROUND_N * GROUND_N)
	var r := _pend
	_pend = Rect2i(-1, 0, 0, 0)
	var job := HeightsJob.new(_hdata, _mask, world.terrain.dh if world.terrain else PackedFloat32Array(), r)
	if (r.size.x + 1) * (r.size.y + 1) > BIG and not OS.has_feature("nothreads"):
		# the ground stays as it was for the second or so this takes
		_job = job
		_task = WorkerThreadPool.add_task(job.run, false, "Physics ground")
		return
	job.run()
	_take(job)


## A finished redo: the ground the bodies land on.
func _take(job: HeightsJob) -> void:
	_hdata = job.heights
	_hm.map_data = _hdata


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)  # nothing may be left running on a worker
		_task = -1


## The physics ground's heights redone over a rectangle of its samples: the
## trench floor where the trench mask is dug, else the shell holes and
## riverbeds (TerrainMap.deform_at, worked out the same way). It works on its
## own copies of the heights and masks (packed arrays copy when written to),
## so it can run on a worker thread while the battle goes on.
class HeightsJob:
	var heights: PackedFloat32Array
	var mask: PackedByteArray
	var dh: PackedFloat32Array
	var rect: Rect2i

	func _init(h: PackedFloat32Array, m: PackedByteArray, d: PackedFloat32Array, r: Rect2i) -> void:
		heights = h
		mask = m
		dh = d
		rect = r

	func run() -> void:
		var n := TrenchNet.N
		var dn := TerrainMap.DN
		var has_mask := not mask.is_empty()
		var has_dh := dh.size() == dn * dn
		for z in range(rect.position.y, rect.end.y + 1):
			var pz := clampi(z * TrenchNet.RES, 0, n - 1)
			var fz := (float(z) - MapDims.HALF + TerrainMap.H) * TerrainMap.DRES - 0.5
			var z0 := clampi(floori(fz), 0, dn - 2)
			var tz := clampf(fz - z0, 0.0, 1.0)
			var row := z * PhysicsFx.GROUND_N
			for x in range(rect.position.x, rect.end.x + 1):
				if has_mask and mask[pz * n + clampi(x * TrenchNet.RES, 0, n - 1)] > 150:
					heights[row + x] = TrenchNet.FLOOR_Y
				elif has_dh:
					var fx := (float(x) - MapDims.HALF + TerrainMap.H) * TerrainMap.DRES - 0.5
					var x0 := clampi(floori(fx), 0, dn - 2)
					var tx := clampf(fx - x0, 0.0, 1.0)
					var j := z0 * dn + x0
					heights[row + x] = lerpf(lerpf(dh[j], dh[j + 1], tx), lerpf(dh[j + dn], dh[j + dn + 1], tx), tz)
				else:
					heights[row + x] = 0.0


func _mask_all() -> int:
	return Defs.L_COVER | L_GROUND | L_RAGDOLL


# --- ragdolls -------------------------------------------------------------------------

func ragdoll(s: Soldier, impulse: Vector3, kind: int) -> void:
	if not Settings.get_v("ragdolls") or s.model == null or not s.visible or s.model.ragdoll != null:
		return
	if world.cam and world.cam.cam.global_position.distance_to(s.position) > 170.0:
		return
	while ragdolls.size() >= MAX_RAGDOLLS:
		var old = ragdolls.pop_front()
		if is_instance_valid(old):
			old.finish()
	var r := Ragdoll.new()
	add_child(r)
	r.setup(s.model, impulse, kind, _mat, L_RAGDOLL, _mask_all())
	ragdolls.append(r)


# --- chunks ---------------------------------------------------------------------------

## Earth and stones thrown out of a crater: they arc, bounce, roll and lie there.
func blast_chunks(p: Vector3, size: float) -> void:
	var n := int(clampf(size * 3.0, 2.0, 9.0) * clampf(Settings.fx_mult(), 0.3, 1.0))
	for i in n:
		var s := randf_range(0.12, 0.3) * (0.8 + size * 0.25)
		var a := randf() * TAU
		var out := randf_range(2.5, 7.0) * sqrt(size)
		var v := Vector3(cos(a) * out, randf_range(5.0, 11.0) * sqrt(size), sin(a) * out)
		var col := Color(0.2, 0.16, 0.12) if randf() < 0.75 else Color(0.29, 0.28, 0.26)
		_chunk(p + Vector3(cos(a) * 0.6, 0.4, sin(a) * 0.6), Vector3(s, s * 0.7, s * 0.85), col, v, randf_range(14.0, 30.0))
	# and whatever else was lying close by gets thrown about
	var r := 2.0 + size * 3.0
	for rd in ragdolls:
		if is_instance_valid(rd) and not rd.done and rd.bodies.has("torso") and (rd.bodies.torso as RigidBody3D).global_position.distance_to(p) < r:
			rd.push(p, size * 4.0)
	for c in _chunks:
		var b: RigidBody3D = c[0]
		if b.global_position.distance_to(p) < r:
			b.freeze = false
			b.sleeping = false
			var d := b.global_position - p
			b.apply_central_impulse((d.normalized() + Vector3.UP) * size * 2.5 * b.mass / maxf(1.0, d.length()))


## Pieces of a wall, a crate or a vehicle when it's destroyed.
func debris(p: Vector3, col: Color, n: int) -> void:
	for i in mini(n, 14):
		var s := randf_range(0.14, 0.42)
		var v := Vector3(randf_range(-5, 5), randf_range(3, 9), randf_range(-5, 5))
		_chunk(p + Vector3(randf_range(-0.6, 0.6), randf_range(0.2, 1.0), randf_range(-0.6, 0.6)), Vector3(s, s * 0.55, s * 0.8), col.darkened(randf_range(0.0, 0.3)), v, randf_range(20.0, 40.0))


func _chunk(p: Vector3, size: Vector3, col: Color, v: Vector3, life: float) -> void:
	var e: Array
	if _chunks.size() >= MAX_CHUNKS:
		e = _chunks.pop_front()
		(e[0] as RigidBody3D).queue_free()
		(e[1] as Node3D).queue_free()
	var b := RigidBody3D.new()
	b.mass = maxf(0.5, size.x * size.y * size.z * 1600.0)
	b.physics_material_override = _chunk_mat
	b.collision_layer = L_RAGDOLL
	b.collision_mask = _mask_all()
	b.gravity_scale = 2.0
	b.continuous_cd = true
	b.angular_damp = 0.4
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	add_child(b)
	b.global_transform = Transform3D(Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)), p)
	b.linear_velocity = v
	b.angular_velocity = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
	var vis := MeshInstance3D.new()
	vis.mesh = Res.box(size)
	vis.material_override = Res.mat(col)
	add_child(vis)
	vis.global_transform = b.global_transform
	_chunks.append([b, vis, b.global_transform, b.global_transform, 0.0, life])


# --- tossed props -----------------------------------------------------------------------

## Throws a structure's model through the air from where it was, then sets it
## down where the server says it ended up. `size` is the model's bounding box.
func toss(who: Node3D, model: Node3D, from_xf: Transform3D, vel: Vector3, spin: Vector3, size: Vector3, mass: float) -> void:
	if model == null or not who.visible:
		return
	if world.cam and world.cam.cam.global_position.distance_to(who.global_position) > 200.0:
		return
	var final_local := model.transform
	var b := RigidBody3D.new()
	b.mass = mass
	b.physics_material_override = _mat
	b.collision_layer = L_RAGDOLL
	b.collision_mask = L_GROUND | Defs.L_COVER
	b.gravity_scale = 2.0
	b.continuous_cd = true
	b.angular_damp = 0.5
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size * 0.92
	cs.shape = bs
	b.add_child(cs)
	add_child(b)
	# the body's centre sits half a height up from the model's base
	var off := Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5, 0))
	b.global_transform = from_xf * off
	b.linear_velocity = vel
	b.angular_velocity = spin
	model.global_transform = from_xf
	_tosses.append([b, model, who, final_local, b.global_transform, b.global_transform, 0.0, off, Transform3D()])


## A loose prop (a lamp post, a bench) thrown or toppled: it falls under
## physics and stays where it ends up (the oldest go after a while).
var _props: Array = []  # [body, model, prev, curr, t, offset]
const MAX_PROPS := 40


func prop(model: Node3D, from_xf: Transform3D, vel: Vector3, spin: Vector3, size: Vector3, mass: float) -> void:
	while _props.size() >= MAX_PROPS:
		var old: Array = _props.pop_front()
		(old[0] as Node).queue_free()
		(old[1] as Node).queue_free()
	var b := RigidBody3D.new()
	b.mass = mass
	b.physics_material_override = _mat
	b.collision_layer = L_RAGDOLL
	b.collision_mask = _mask_all()
	b.gravity_scale = 2.0
	b.continuous_cd = true
	b.angular_damp = 0.6
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	add_child(b)
	var off := Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5, 0))
	b.global_transform = from_xf * off
	b.linear_velocity = vel
	b.angular_velocity = spin
	if model.get_parent() != self:
		model.reparent(self)
	model.global_transform = from_xf
	_props.append([b, model, b.global_transform, b.global_transform, 0.0, off])


# --- stepping --------------------------------------------------------------------------

func _physics_process(_dt: float) -> void:
	for r in ragdolls:
		if is_instance_valid(r):
			r.capture()
	for c in _chunks:
		var b: RigidBody3D = c[0]
		c[2] = c[3]
		c[3] = b.global_transform
	for e in _tosses:
		var b2: RigidBody3D = e[0]
		e[4] = e[5]
		e[5] = b2.global_transform
	for pr in _props:
		var b3: RigidBody3D = pr[0]
		if not b3.freeze:
			pr[2] = pr[3]
			pr[3] = b3.global_transform


func _process(dt: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_take(_job)
		_job = null
		_flush()  # (anything that came in meanwhile)
	var a := Engine.get_physics_interpolation_fraction()
	for i in range(ragdolls.size() - 1, -1, -1):
		var r = ragdolls[i]
		if not is_instance_valid(r) or r.done:
			ragdolls.remove_at(i)
			continue
		r.update(dt, a)
	for i in range(_chunks.size() - 1, -1, -1):
		var c: Array = _chunks[i]
		var b: RigidBody3D = c[0]
		var vis: Node3D = c[1]
		c[4] = float(c[4]) + dt
		if not b.freeze:
			vis.global_transform = (c[2] as Transform3D).interpolate_with(c[3], a)
			# at rest: stop simulating it, it just lies there
			if float(c[4]) > 1.0 and (b.sleeping or b.linear_velocity.length() < 0.05):
				b.freeze = true
				vis.global_transform = b.global_transform
		if float(c[4]) > float(c[5]):
			var s: float = clampf(1.0 - (float(c[4]) - float(c[5])) / 2.0, 0.0, 1.0)
			vis.scale = Vector3.ONE * maxf(s, 0.01)
			if s <= 0.0:
				b.queue_free()
				vis.queue_free()
				_chunks.remove_at(i)
	for pr in _props:
		var b4: RigidBody3D = pr[0]
		if b4.freeze:
			continue
		pr[4] = float(pr[4]) + dt
		(pr[1] as Node3D).global_transform = (pr[2] as Transform3D).interpolate_with(pr[3], a) * (pr[5] as Transform3D).affine_inverse()
		if float(pr[4]) > 1.0 and (b4.sleeping or b4.linear_velocity.length() < 0.05) or float(pr[4]) > 8.0:
			b4.freeze = true
			(pr[1] as Node3D).global_transform = b4.global_transform * (pr[5] as Transform3D).affine_inverse()
	for i in range(_tosses.size() - 1, -1, -1):
		var e: Array = _tosses[i]
		var b2: RigidBody3D = e[0]
		var model: Node3D = e[1]
		var who = e[2]
		# (a despawned prop stays valid a while, out of the tree: a road bulldozed it)
		if not is_instance_valid(who) or not is_instance_valid(model) or not (who as Node).is_inside_tree():
			b2.queue_free()
			_tosses.remove_at(i)
			continue
		e[6] = float(e[6]) + dt
		var t: float = e[6]
		var off: Transform3D = e[7]
		var final_xf: Transform3D = (who as Node3D).global_transform * (e[3] as Transform3D)
		if t < 2.6 and not (t > 1.0 and b2.sleeping):
			model.global_transform = (e[4] as Transform3D).interpolate_with(e[5], a) * off.affine_inverse()
			e[8] = model.global_transform
		else:
			# settle onto where the battle has it
			e[8] = (e[8] as Transform3D).interpolate_with(final_xf, clampf(dt * 5.0, 0.0, 1.0))
			model.global_transform = e[8]
			if (e[8] as Transform3D).origin.distance_to(final_xf.origin) < 0.03 or t > 4.5:
				model.transform = e[3]
				b2.queue_free()
				_tosses.remove_at(i)
