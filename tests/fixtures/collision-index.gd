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
	get_tree().quit()
