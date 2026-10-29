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
const GROUND_TILE := 32
const GROUND_RADIUS := 6

var world
var ground: StaticBody3D
var _ground_tiles := {}
var _ground_dirty := {}
var _ground_center := Vector2i(-999, -999)
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
	# A distant cosmetic fragment can fall out of the active tiles without
	# falling forever. Detailed collision around the camera sits above this.
	var fallback := WorldBoundaryShape3D.new()
	fallback.plane = Plane(Vector3.UP, -2.0)
	cs.shape = fallback
	ground.add_child(cs)
	add_child(ground)


var _mask := PackedByteArray()


## Cuts the trench network into the ground (called when the network changes);
## only the area that changed (metres) is redone, all of it when that is empty.
func update_ground(mask: PackedByteArray, area := Rect2()) -> void:
	_mask = mask
	for key: Vector2i in _ground_tiles:
		var bounds := Rect2(Vector2(key * GROUND_TILE) - Vector2.ONE * MapDims.HALF, Vector2.ONE * GROUND_TILE)
		if not area.has_area() or bounds.grow(1.0).intersects(area):
			_ground_dirty[key] = true


## Follows the shell holes (rect in terrain height samples).
func update_deform(r: Rect2i) -> void:
	var area := Rect2(Vector2(r.position) / TerrainMap.DRES - Vector2.ONE * MapDims.HALF, Vector2(r.size) / TerrainMap.DRES)
	update_ground(_mask, area)


func _update_ground_tiles() -> void:
	if world.cam == null:
		return
	var focus: Vector3 = world.cam.focus_pos
	var center := Vector2i(floori((focus.x + MapDims.HALF) / GROUND_TILE), floori((focus.z + MapDims.HALF) / GROUND_TILE))
	if center != _ground_center:
		_ground_center = center
		var wanted := {}
		for radius in GROUND_RADIUS + 1:
			for z in range(-radius, radius + 1):
				for x in range(-radius, radius + 1):
					if maxi(absi(x), absi(z)) != radius:
						continue
					var key := center + Vector2i(x, z)
					if key.x < 0 or key.y < 0 or key.x >= MapDims.N / GROUND_TILE or key.y >= MapDims.N / GROUND_TILE:
						continue
					wanted[key] = true
					if not _ground_tiles.has(key):
						_ground_dirty[key] = true
		for key in _ground_tiles.keys():
			if not wanted.has(key):
				(_ground_tiles[key].body as StaticBody3D).queue_free()
				_ground_tiles.erase(key)
		for key in _ground_dirty.keys():
			if not wanted.has(key):
				_ground_dirty.erase(key)
	for i in mini(2, _ground_dirty.size()):
		var key: Vector2i = _ground_dirty.keys()[0]
		_ground_dirty.erase(key)
		_rebuild_ground_tile(key)


func _rebuild_ground_tile(key: Vector2i) -> void:
	var tile: Dictionary = _ground_tiles.get(key, {})
	if tile.is_empty():
		var body := StaticBody3D.new()
		body.collision_layer = L_GROUND
		body.collision_mask = 0
		body.physics_material_override = _mat
		body.position = Vector3((key.x + 0.5) * GROUND_TILE - MapDims.HALF, 0, (key.y + 0.5) * GROUND_TILE - MapDims.HALF)
		var shape := HeightMapShape3D.new()
		shape.map_width = GROUND_TILE + 1
		shape.map_depth = GROUND_TILE + 1
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
		tile = {"body": body, "shape": shape}
		_ground_tiles[key] = tile
	var data := PackedFloat32Array()
	data.resize((GROUND_TILE + 1) * (GROUND_TILE + 1))
	for z in GROUND_TILE + 1:
		for x in GROUND_TILE + 1:
			data[z * (GROUND_TILE + 1) + x] = _height(key.x * GROUND_TILE + x, key.y * GROUND_TILE + z)
	(tile.shape as HeightMapShape3D).map_data = data


func _height(x: int, z: int) -> float:
	var n := TrenchNet.N
	if not _mask.is_empty():
		var pz := clampi(z * TrenchNet.RES, 0, n - 1)
		var px := clampi(x * TrenchNet.RES, 0, n - 1)
		if _mask[pz * n + px] > 150:
			return world.terrain.landform.height(Vector3(x - MapDims.HALF, 0, z - MapDims.HALF)) + TrenchNet.FLOOR_Y
	return world.terrain.deform_at(Vector3(x - MapDims.HALF, 0, z - MapDims.HALF)) if world.terrain else 0.0


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
	var terrain_started := Time.get_ticks_usec()
	_update_ground_tiles()
	world.vp("cosmetic terrain collision", terrain_started)
	var bodies_started := Time.get_ticks_usec()
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
	world.vp("cosmetic bodies", bodies_started)
