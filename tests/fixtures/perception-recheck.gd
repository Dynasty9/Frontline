extends Node3D

class Sight extends Combat:
	var queries := 0
	var physics: PhysicsDirectSpaceState3D
	func space() -> PhysicsDirectSpaceState3D:
		return physics
	func ray(a: Vector3, b: Vector3, ex: Array = []) -> Dictionary:
		queries += 1
		return super.ray(a, b, ex)

class Contact extends Entity:
	var height := 1.0
	func exposed_points() -> Array:
		return [position + Vector3.UP * height, position + Vector3.UP * (height + 0.5)]

func sync_physics() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame

func _ready() -> void:
	var world := World.new()
	world.fires = Fires.new(world)
	var sight := Sight.new(world)
	sight.physics = get_world_3d().direct_space_state
	var enemy := Contact.new()
	enemy.position = Vector3(10, 0, 0)
	world.add_child(enemy)
	var wall := StaticBody3D.new()
	wall.collision_layer = Combat.MASK
	wall.position = Vector3(5, 1, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 4, 4)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	await sync_physics()
	var eye := Vector3(0, 1, 0)
	assert(not sight.can_see_from(eye, enemy, []))
	var before := sight.queries
	assert(not sight.can_see_from(eye, enemy, []) and sight.queries == before, "Unchanged blocking geometry should reuse its result")
	assert(not sight.can_see_from(eye, enemy, [], false) and sight.queries > before, "Moving observers use fresh physics without cache bookkeeping")
	before = sight.queries
	enemy.height = 1.2
	sight.can_see_from(eye, enemy, [])
	assert(sight.queries > before, "A changed target posture must be checked")
	before = sight.queries
	sight.can_see_from(eye + Vector3.UP * 0.1, enemy, [])
	assert(sight.queries > before, "A changed observer position must be checked")
	assert(sight.can_see_from(eye, enemy, [wall.get_rid()]), "Changed exclusions must take effect immediately")
	assert(not sight.can_see_from(eye, enemy, []))
	wall.position.z = 10
	await sync_physics()
	assert(sight.can_see_from(eye, enemy, []), "Moving a blocker must clear cached obstruction")
	wall.position.z = 0
	await sync_physics()
	assert(not sight.can_see_from(eye, enemy, []), "Positive visibility is never cached")
	before = sight.queries
	box.margin = 0.2
	await sync_physics()
	assert(not sight.can_see_from(eye, enemy, []) and sight.queries > before, "Changed collision margins invalidate obstruction")
	box.margin = 0.04
	await sync_physics()
	box.size.y = 0.1
	await sync_physics()
	assert(sight.can_see_from(eye, enemy, []), "Resizing collision geometry must invalidate obstruction")
	box.size.y = 4
	wall.position.y = 1
	await sync_physics()
	assert(not sight.can_see_from(eye, enemy, []))
	wall.collision_layer = 0
	await sync_physics()
	assert(sight.can_see_from(eye, enemy, []), "Disabled collision layers must invalidate obstruction")
	wall.collision_layer = Combat.MASK
	await sync_physics()
	assert(not sight.can_see_from(eye, enemy, []))
	wall.process_mode = Node.PROCESS_MODE_DISABLED
	await sync_physics()
	assert(sight.can_see_from(eye, enemy, []), "Bodies removed from physics by process mode invalidate obstruction")
	wall.process_mode = Node.PROCESS_MODE_INHERIT
	await sync_physics()
	assert(not sight.can_see_from(eye, enemy, []))
	shape.disabled = true
	await sync_physics()
	assert(sight.can_see_from(eye, enemy, []), "Disabled shapes must invalidate obstruction")
	shape.disabled = false
	await sync_physics()
	assert(not sight.can_see_from(eye, enemy, []))
	wall.remove_child(shape)
	await sync_physics()
	assert(sight.can_see_from(eye, enemy, []), "Opening a door removes its blocking shape immediately")
	wall.add_child(shape)
	await sync_physics()
	assert(not sight.can_see_from(eye, enemy, []))
	wall.free()
	await sync_physics()
	assert(sight.can_see_from(eye, enemy, []), "Freed blockers must not leave stale references")
	world.fires.smokes.append([Vector3(5, 1, 0), 4.0])
	assert(not sight.can_see_from(eye, enemy, []))
	before = sight.queries
	assert(not sight.can_see_from(eye, enemy, []) and sight.queries > before, "Smoke obstruction must never be cached")
	world.fires.smokes.clear()
	assert(sight.can_see_from(eye, enemy, []), "Dissipated smoke restores visibility immediately")
	world.free()
	print("PERCEPTION_RECHECK passed")
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()
