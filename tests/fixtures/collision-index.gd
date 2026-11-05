extends Node3D


func _ready() -> void:
	assert(ClassDB.class_exists("CollisionIndexCore"))
	var index: RefCounted = ClassDB.instantiate("CollisionIndexCore")
	var rng := RandomNumberGenerator.new()
	rng.seed = 637
	var bodies: Array[StaticBody3D] = []
	for id in 150:
		var body := StaticBody3D.new()
		body.set_meta("eid", id)
		body.collision_layer = Combat.MASK
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(rng.randf_range(0.2, 12), rng.randf_range(0.2, 8), rng.randf_range(0.2, 12))
		shape.shape = box
		body.add_child(shape)
		body.position = Vector3(rng.randf_range(-160, 160), rng.randf_range(-2, 6), rng.randf_range(-160, 160))
		body.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-PI, PI), rng.randf_range(-0.2, 0.2))
		add_child(body)
		bodies.append(body)
		var t := body.global_transform
		var h := box.size * 0.5
		var rows := PackedFloat32Array([t.origin.x,t.origin.y,t.origin.z,t.basis.x.x,t.basis.x.y,t.basis.x.z,t.basis.y.x,t.basis.y.y,t.basis.y.z,t.basis.z.x,t.basis.z.y,t.basis.z.z,h.x,h.y,h.z,0])
		assert(index.replace_body(id, rows))
	await get_tree().physics_frame
	await get_tree().process_frame
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = Combat.MASK
	var hits := 0
	for i in 3000:
		q.from = Vector3(rng.randf_range(-200,200), rng.randf_range(-10,15), rng.randf_range(-200,200))
		q.to = Vector3(rng.randf_range(-200,200), rng.randf_range(-10,15), rng.randf_range(-200,200))
		var exclude := i % bodies.size()
		q.exclude = [bodies[exclude].get_rid()]
		var expected := space.intersect_ray(q)
		var actual: PackedFloat64Array = index.ray(q.from,q.to,PackedInt64Array([exclude]))
		assert(expected.is_empty() == actual.is_empty(), "Ray hit disagreement at query %d" % i)
		if not expected.is_empty():
			hits += 1
			assert(int(actual[0]) == int(expected.collider.get_meta("eid")), "Collider disagreement at query %d" % i)
			assert(Vector3(actual[2],actual[3],actual[4]).distance_to(expected.position) < 0.002)
			assert(Vector3(actual[5],actual[6],actual[7]).dot(expected.normal) > 0.9999)
	assert(hits > 100)
	print("COLLISION_INDEX passed rays=3000 hits=", hits)
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	var worlds: Array[World] = []
	var heights := PackedFloat32Array()
	for z in 17:
		for x in 17:
			heights.append(12.0 + 8.0 * sin(x * 0.4) + 3.0 * cos(z * 0.3))
	for native in [false, true]:
		var w := World.new()
		w.settings = {"gdscript_terrain": not native}
		w.terrain = TerrainMap.new(w)
		w.terrain.install_landform(heights)
		worlds.append(w)
	assert(index.set_ground(worlds[1].terrain._native, PackedByteArray()))
	var terrain_hits := 0
	for i in 3000:
		if i % 500 == 0:
			var impact := Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20))
			impact.y = worlds[0].terrain.landform.height(impact)
			for w in worlds: w.terrain.add_crater(impact, 3.0)
		q.from = Vector3(rng.randf_range(-32,32), rng.randf_range(0,35), rng.randf_range(-32,32))
		q.to = Vector3(rng.randf_range(-32,32), rng.randf_range(0,35), rng.randf_range(-32,32))
		var exclude := i % bodies.size()
		q.exclude = [bodies[exclude].get_rid()]
		var expected := space.intersect_ray(q)
		var ground := worlds[0].terrain.ray_ground(q.from, expected.position if not expected.is_empty() else q.to)
		if not ground.is_empty():
			expected = ground
			terrain_hits += 1
		var actual: PackedFloat64Array = index.ray(q.from,q.to,PackedInt64Array([exclude]))
		assert(expected.is_empty() == actual.is_empty(), "Mixed ray hit %d" % i)
		if not expected.is_empty():
			assert(Vector3(actual[2],actual[3],actual[4]).distance_to(expected.position) < 0.002, "Mixed ray surface %d" % i)
			assert(Vector3(actual[5],actual[6],actual[7]).dot(expected.normal) > 0.9999, "Mixed ray normal %d" % i)
			if not ground.is_empty(): assert(actual[0] == 0 and actual[1] == -1)
			else: assert(int(actual[0]) == int(expected.collider.get_meta("eid")))
	assert(terrain_hits > 500)
	for w in worlds: w.free()
	print("TERRAIN_COLLISION passed rays=3000 hits=", terrain_hits)
	get_tree().quit()
