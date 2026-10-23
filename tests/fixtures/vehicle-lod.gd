extends Node

func _ready() -> void:
	var pivot := Node3D.new()
	add_child(pivot)
	var original := Res.mi(pivot, Res.box(Vector3(2, 1, 4)), Mats.get_mat("steel"), Vector3(0, 1, 0))
	var kept := Res.mi(pivot, Res.box(Vector3.ONE), Mats.get_mat("steel"), Vector3(4, 0, 0))
	var child := Node3D.new()
	pivot.add_child(child)
	var nested := Res.mi(child, Res.box(Vector3.ONE), Mats.get_mat("steel"), Vector3.ZERO)
	Mats.add_distance_lod(pivot, 100.0, [kept])
	var coarse := pivot.get_child(pivot.get_child_count() - 1) as MeshInstance3D
	assert(coarse != null and coarse != original and coarse.mesh.get_surface_count() == 1)
	assert(coarse.visibility_range_begin == 100.0 and original.visibility_range_end == 100.0)
	assert(kept.visibility_range_end == 0.0 and nested.visibility_range_end == 0.0)
	assert(coarse.mesh.get_aabb() == AABB(Vector3(-1, 0.5, -2), Vector3(2, 1, 4)))
	pivot.rotation.y = 1.2
	assert(coarse.global_transform == pivot.global_transform)
	var empty := Node3D.new()
	Mats.add_distance_lod(empty, 100.0)
	assert(empty.get_child_count() == 0)
	empty.free()
	pivot.free()
	var tank := VehicleModels.build("tank", 0, 3)
	assert(_lod_count(tank.root) > 0 and _lod_count(tank.turret) > 0)
	tank.root.free()
	var wreck := VehicleModels.build("tank", 0, 3, true)
	assert(_lod_count(wreck.root) == 0)
	wreck.root.free()
	print("VEHICLE_LOD passed")
	get_tree().quit()


func _lod_count(root: Node3D) -> int:
	var count := 0
	for child in root.get_children():
		if child is MeshInstance3D and child.visibility_range_begin == 100.0:
			count += 1
		if child is Node3D:
			count += _lod_count(child)
	return count
