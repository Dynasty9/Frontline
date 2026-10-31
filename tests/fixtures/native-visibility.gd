extends Node3D

class Scene extends World:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

class Contact extends Entity:
	var height := 1.0
	func exposed_points() -> Array:
		return [position + Vector3.UP * height, position + Vector3.UP * (height + 0.5)]


func settle() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame


func _ready() -> void:
	var world := Scene.new()
	world.srv = true
	world.has_view = false
	world.combat = Combat.new(world)
	world.fires = Fires.new(world)
	add_child(world)
	world.combat.enable_native_collision()
	assert(world.combat._visibility != null)
	var reference := Combat.new(world)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91634
	var vehicles: Array[Vehicle] = []
	for id in range(1, 61):
		var vehicle := Vehicle.new()
		vehicle.eid = id
		vehicle.world = world
		vehicle.srv = true
		vehicle.position = Vector3(rng.randf_range(-60, 60), 1.0, rng.randf_range(-60, 60))
		vehicle.rotation.y = rng.randf_range(-PI, PI)
		world.entities[id] = vehicle
		world.add_child(vehicle)
		vehicle.body = StaticBody3D.new()
		vehicle.body.collision_layer = Combat.MASK
		vehicle.body.set_meta("eid", id)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(rng.randf_range(1, 5), 4.0, rng.randf_range(1, 8))
		shape.shape = box
		vehicle.body.add_child(shape)
		vehicle.add_child(vehicle.body)
		world.combat.dirty_collision(id)
		vehicles.append(vehicle)
	world.next_eid = 100
	var smoke: Projectile = world.spawn("projectile", {"ptype": "smoke", "pos": Vector3.ZERO})
	smoke.smoke_r = 4.0
	var enemy := Contact.new()
	enemy.eid = 90
	enemy.world = world
	world.add_child(enemy)
	var queries := 0
	for round in 12:
		smoke.position = Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-40, 40))
		smoke.smoke_r = [0.8, 0.80000001, 6.5][round % 3]
		smoke.ptype = "frag" if round % 4 == 0 else "smoke"
		world.fires.smokes = [[Vector3(-30 + round * 5, 1.4, 0), 4.0]] if round % 2 else []
		world.combat.update_fire_smoke(world.fires.smokes)
		var moved := vehicles[round]
		moved.position.z += 12
		var shape: CollisionShape3D = moved.body.get_child(0)
		shape.shape.size.z += 0.3
		await settle()
		for query in 250:
			var eye := Vector3(rng.randf_range(-80, 80), 1.4, rng.randf_range(-80, 80))
			enemy.position = Vector3(rng.randf_range(-80, 80), 0, rng.randf_range(-80, 80))
			enemy.height = rng.randf_range(0.3, 1.8)
			var ex := vehicles[query % vehicles.size()].get_exclude()
			var expected := reference.can_see_from(eye, enemy, ex, true)
			assert(world.combat.can_see_from(eye, enemy, ex, true) == expected, "Visibility round=%d query=%d" % [round, query])
			assert(world.combat.can_see_from(eye, enemy, ex, true) == expected, "Repeated visibility")
			assert(world.combat.can_see_from(eye, enemy, ex, false) == expected, "Moving visibility")
			assert(world.combat.smoke_blocks(eye, enemy.position) == reference.smoke_blocks(eye, enemy.position), "Smoke geometry")
			queries += 1
		var snapshot: PackedByteArray = world.combat._visibility.checkpoint()
		var geometry: PackedByteArray = world.combat._collision.checkpoint()
		assert(world.combat._visibility.restore(snapshot))
		assert(world.combat._collision.restore(geometry))
		assert(world.combat._visibility.checkpoint() == snapshot)
		assert(world.combat._collision.checkpoint() == geometry)
	# Radius/position/type changes are visible before another simulation tick.
	smoke.ptype = "smoke"
	smoke.smoke_r = 4.0
	smoke.position = Vector3(0, 0, 200)
	var a := Vector3(-10, 1.4, 200)
	var b := Vector3(10, 1.4, 200)
	assert(world.combat.smoke_blocks(a, b))
	smoke.position.z += 30
	assert(not world.combat.smoke_blocks(a, b))
	smoke.position.z -= 30
	smoke.smoke_r = 0.8
	assert(not world.combat.smoke_blocks(a, b))
	smoke.smoke_r = 4.0
	smoke.ptype = "frag"
	assert(not world.combat.smoke_blocks(a, b))
	smoke.ptype = "smoke"
	assert(world.combat.smoke_blocks(a, b))
	world.despawn(smoke)
	assert(not world.combat.smoke_blocks(a, b))
	world.free()
	print("NATIVE_VISIBILITY passed queries=", queries)
	get_tree().quit()
