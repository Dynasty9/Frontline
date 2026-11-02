extends Node3D

class CollisionScene extends World:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)


func _ready() -> void:
	var world := CollisionScene.new()
	world.srv = true
	world.has_view = false
	world.combat = Combat.new(world)
	world.combat.enable_native_collision()
	assert(world.combat._collision != null)
	add_child(world)
	var vehicle := Vehicle.new()
	vehicle.world = world
	vehicle.srv = true
	vehicle.eid = 1
	vehicle.position = Vector3(5, 1, 0)
	world.entities[1] = vehicle
	world.add_child(vehicle)
	vehicle.body = StaticBody3D.new()
	vehicle.body.collision_layer = Combat.MASK
	vehicle.body.set_meta("eid", 1)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1,4,4)
	shape.shape = box
	vehicle.body.add_child(shape)
	vehicle.add_child(vehicle.body)
	world.combat.dirty_collision(1)
	var from := Vector3(0, 1, 0)
	var to := Vector3(10, 1, 0)
	assert(not world.combat.ray(from,to).is_empty())
	assert(world.combat.ray(from,to,vehicle.get_exclude()).is_empty())
	vehicle.position.z = 10
	assert(world.combat.ray(from,to).is_empty(), "Movement must update collision before the next ray")
	vehicle.position.z = 0
	assert(not world.combat.ray(from,to).is_empty())
	world.combat.retire_collision(1)
	assert(not world.combat.ray(from,to).is_empty(), "Destroyed bodies shield shots until the tick ends")
	world.combat.finish_tick()
	assert(world.combat.ray(from,to).is_empty(), "Retired bodies must be absent next tick")
	world.combat.dirty_collision(1)
	box.size.z = 0.1
	assert(world.combat.ray(from + Vector3(0,0,1),to + Vector3(0,0,1)).is_empty(), "Shape changes must update collision")
	vehicle.body.remove_child(shape)
	shape.free()
	world.combat.dirty_collision(1)
	assert(world.combat.ray(from,to).is_empty(), "Removing a door or shape must remove its collision")
	world.combat.remove_collision(1)
	assert(world.combat._collision_bodies.is_empty())
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	world.terrain = TerrainMap.new(world)
	var heights := PackedFloat32Array()
	heights.resize(17 * 17)
	heights.fill(12.0)
	world.terrain.install_landform(heights)
	var ground := world.combat.ray(Vector3(0, 20, 0), Vector3.ZERO)
	assert(world.combat._collision != null, "Elevated maps retain native combat queries")
	assert(not ground.is_empty() and ground.collider == null and absf(ground.position.y - 12.0) < 0.08, "Terrain has no entity collider")
	world.free()
	print("COLLISION_LIFECYCLE passed")
	get_tree().quit()
