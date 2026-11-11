extends Node

func kit() -> VehicleModels:
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k._baking = true
	return k

func occupied(k: VehicleModels, point: Vector3) -> bool:
	for part: Array in k._parts[k.root]:
		var basis: Basis = part[7] if part[7] is Basis else Basis.from_euler(part[5]).scaled(part[6])
		var local := Transform3D(basis, part[4]).affine_inverse() * point
		if (part[0] as Mesh).get_aabb().has_point(local):
			return true
	return false

func valid_static(k: VehicleModels) -> void:
	assert(k.root.get_child_count() == 0, "Construction pivots must fold into their original parent")
	assert(k.wheels.is_empty(), "Static fittings must not register wheel animation")
	for part: Array in k._parts[k.root]:
		var mesh := part[0] as Mesh
		assert(mesh.get_aabb().size.is_finite())
		assert((part[4] as Vector3).is_finite())
		if k.burnt:
			assert(part[1] == Mats.get_mat(VehicleMaterials.key("burnt", k.surface_family)))

func _ready() -> void:
	TestRun.watch()
	# Open fittings must have real gaps; changing shared detail must not fill them.
	var k := kit()
	VehicleMounts.basket(k, k.root, Vector3.ZERO, Vector3(2.0, 0.6, 0.8))
	assert(not occupied(k, Vector3(0, 0.2, 0)))
	assert(not occupied(k, Vector3(0.11, 0.2, 0.4)))
	valid_static(k)
	k.root.free()
	k = kit()
	VehicleMounts.hitch(k, k.root, Vector3.ZERO, Vector3(0.2, 0.2, 0.3))
	assert(not occupied(k, Vector3(0, 0, 0)))
	assert(occupied(k, Vector3(0.075, 0, 0.02)))
	valid_static(k)
	k.root.free()
	k = kit()
	VehicleMounts.slats(k, k.root, Vector3(-1, 0, 0), Vector3(1, 0, 0), 0.6, 0.2)
	assert(not occupied(k, Vector3(0.4, 0.1, 0)))
	assert(occupied(k, Vector3(0.4, 0.2, 0)))
	valid_static(k)
	k.root.free()
	# Sprockets register exactly one X-axis wheel, at the caller's axle position.
	for twin in [false, true]:
		k = kit()
		var at := Vector3(1.4, 0.7, -2.8)
		var wheel := VehicleWheels.sprocket(k, k.root, at, 0.35, 0.5, "paint", Color.OLIVE, 11, twin)
		assert(k.wheels.size() == 1 and k.wheels[0] == wheel)
		assert(wheel.position == at and wheel.basis == Basis.IDENTITY)
		k.root.free()
	# All panel orientations preserve the old leaf's occupied centre and thickness.
	for axis in 3:
		k = kit()
		var size := Vector3.ONE
		size[axis] = 0.04
		VehicleDoors.leaf(k, k.root, size, Vector3.ZERO, "paint", Color.OLIVE, Vector3.ZERO, axis)
		assert(occupied(k, Vector3.ZERO))
		var outside := Vector3.ZERO
		outside[axis] = 0.08
		assert(not occupied(k, outside))
		valid_static(k)
		k.root.free()
	# Static assemblies keep the wreck material contract through their nested calls.
	for burnt in [false, true]:
		k = kit()
		k.burnt = burnt
		VehicleMounts.mantlet(k, k.root, Vector3(0.4, 0.3, 0.5), Vector3.ZERO, "paint", Color.OLIVE)
		VehicleMounts.boom(k, k.root, Vector3.ZERO, Vector3(0.3, 0.2, 2), 0.2, 0.18, "paint", Color.OLIVE)
		VehicleMounts.radar_array(k, k.root, Vector3(1.2, 0.3, 0.1), Vector3.ZERO, "paint", Color.OLIVE)
		VehicleCab.dashboard(k, k.root, Vector3(1, 0.2, 0.3), Vector3.ZERO)
		VehicleAircraft.pitot(k, k.root, Vector3.ZERO, Vector3(0, 0, -0.8), 0.02)
		VehicleMarine.propeller(k, k.root, Vector3.ZERO, 0.25, 3, "steel")
		valid_static(k)
		k.root.free()
	print("VEHICLE_ASSEMBLIES passed")
	TestRun.quit(get_tree())
