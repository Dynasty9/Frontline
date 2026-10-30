extends Node3D

class Subject extends Node3D:
	var utype := "rifleman"
	var life := Soldier.Life.ALIVE
	var model = null

class SquadStub extends Node:
	var members: Array = []
	func alive_members() -> Array:
		return members.filter(func(man): return man.life == Soldier.Life.ALIVE)

func _ready() -> void:
	var rig = load("res://tests/mocap/combat_camera.gd").new()
	add_child(rig)
	rig.set_process(false)
	var focus := Vector3(0, 1, 0)
	var offset := Vector3(3, 2.2, -4.8)
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = Defs.L_COVER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 0.15, 0.15)
	shape.shape = box
	obstacle.add_child(shape)
	add_child(obstacle)
	# Blocks the face while leaving the old single pelvis ray unobstructed.
	obstacle.position = focus + offset * 0.5 + Vector3.UP * 0.3
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ray := PhysicsRayQueryParameters3D.create(focus, focus + offset, Defs.L_COVER)
	assert(get_world_3d().direct_space_state.intersect_ray(ray).is_empty())
	assert(not rig._visible(focus, focus + offset))
	var adjusted: Vector3 = rig._camera_offset(focus, offset)
	assert(rig._visible(focus, focus + adjusted))
	assert(not adjusted.is_equal_approx(offset))
	var smoke := [[focus + adjusted * 0.5, 0.6]]
	assert(rig._smoke_depth(focus, focus + adjusted, smoke) > 1.1)
	var clear: Vector3 = rig._camera_offset(focus, offset, smoke)
	assert(rig._visible(focus, focus + clear))
	assert(rig._smoke_depth(focus, focus + clear, smoke) == 0.0)
	assert(is_equal_approx(rig._smoke_depth(focus, focus + offset, [[focus, 1.0]]), 1.0))
	assert(rig._smoke_depth(focus, focus + offset, [[focus - offset, 0.5]]) == 0.0)
	var grass := Grass.new()
	grass.bush = grass._make_bush()
	var bush := MultiMeshInstance3D.new()
	bush.multimesh = MultiMesh.new()
	bush.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	bush.multimesh.mesh = grass.bush
	bush.multimesh.instance_count = 1
	var bush_pos := focus + clear * 0.5 - grass.bush.get_aabb().get_center()
	# The headless dummy renderer does not retain GPU instance transforms.
	bush.multimesh.set_instance_transform(0, Transform3D.IDENTITY)
	bush.position = bush_pos
	if DisplayServer.get_name() != "headless":
		bush.position = Vector3.ZERO
		bush.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, bush_pos))
	add_child(bush)
	grass._built[Vector2i(floori(bush_pos.x / Grass.CHUNK), floori(bush_pos.z / Grass.CHUNK))] = [bush]
	rig._gather_foliage(grass, focus)
	assert(rig.foliage.size() == 1)
	assert(not rig._visible(focus, focus + clear), "Non-colliding foliage did not obstruct the camera")
	var around_bush: Vector3 = rig._camera_offset(focus, offset)
	assert(rig._visible(focus, focus + around_bush))
	rig.foliage.clear()
	# A bush around the feet must not force a close overhead fallback.
	rig.foliage.append(AABB(focus + Vector3(-0.4, -0.7, -0.4), Vector3(0.8, 0.4, 0.8)))
	var partial: Vector3 = rig._camera_offset(focus, offset)
	assert(rig._clear_rays(focus, focus + partial) == 2)
	assert(is_equal_approx(partial.length(), offset.length()))
	rig.foliage.clear()
	rig.foliage.append(AABB(focus - Vector3.ONE, Vector3.ONE * 2.0))
	var enclosed: Vector3 = rig._camera_offset(focus, offset)
	assert(is_equal_approx(enclosed.length(), offset.length()))
	rig.foliage.clear()
	grass.free()
	# A bush enclosing the lower body masks a wall's penalty in the combined score.
	obstacle.position = focus + offset * 0.5 - Vector3.UP * 0.125
	box.size = Vector3(2, 0.5, 0.2)
	rig.foliage.append(AABB(focus + Vector3(-0.4, -0.7, -0.4), Vector3(0.8, 0.9, 0.8)))
	rig.view_angle = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(rig._clear_rays(focus, focus + offset) == 1)
	assert(rig._clear_rays(focus, focus + offset, false) < 3)
	var without_wall: Vector3 = rig._camera_offset(focus, offset)
	assert(rig._clear_rays(focus, focus + without_wall, false) == 3, "Foliage must not hide an additional solid obstruction")
	rig.foliage.clear()
	# Reproduce the battle frame: pelvis rays graze the wall edge, shoulders do not.
	obstacle.position = Vector3(-4, 1.3, -3)
	box.size = Vector3(3, 2.6, 0.5)
	var edge_focus := Vector3(-2.046242, 0.708896, -1.370767)
	var edge_eye := Vector3(-3.319034, 2.908896, -6.8862)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for height in [-0.5, 0.0, 0.6]:
		var center_ray := PhysicsRayQueryParameters3D.create(edge_eye, edge_focus + Vector3.UP * height, Defs.L_COVER)
		assert(get_world_3d().direct_space_state.intersect_ray(center_ray).is_empty())
	assert(not rig._visible(edge_focus, edge_eye), "Wall edge hides the shoulders despite clear center rays")
	var edge_offset: Vector3 = rig._camera_offset(edge_focus, edge_eye - edge_focus)
	assert(rig._visible(edge_focus, edge_focus + edge_offset))
	var squad := SquadStub.new()
	add_child(squad)
	var fallen := Subject.new()
	var living := Subject.new()
	add_child(fallen)
	add_child(living)
	squad.members = [fallen, living]
	var tank := Node3D.new()
	add_child(tank)
	rig.setup(squad, tank)
	fallen.life = Soldier.Life.DEAD
	rig._process(0.6)
	assert(rig.subject == fallen)
	rig._process(0.7)
	assert(rig.subject == living)
	rig.elapsed = 18.0
	rig.subject = fallen
	rig._process(2.0)
	assert(rig.subject == fallen)
	print("CAMERA PASS cover/smoke/foliage clearance, living retarget, staged ragdoll hold")
	get_tree().quit()
