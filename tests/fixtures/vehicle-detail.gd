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

func bounds(k: VehicleModels) -> AABB:
	var result := AABB()
	var first := true
	for part: Array in k._parts[k.root]:
		var basis: Basis = part[7] if part[7] is Basis else Basis.from_euler(part[5]).scaled(part[6])
		var box: AABB = Transform3D(basis, part[4]) * (part[0] as Mesh).get_aabb()
		assert(box.position.is_finite() and box.size.is_finite())
		result = box if first else result.merge(box)
		first = false
	return result

func _ready() -> void:
	TestRun.watch()
	# An actual empty channel, not a dark line painted on a solid rail.
	var k := kit()
	VehicleRunningGear.frame(k, k.root, Vector3.ZERO, 0.45, 2.0, Vector2(0.12, 0.2), [0.0])
	assert(not occupied(k, Vector3(0.43, 0, 0.8)))
	assert(occupied(k, Vector3(0.50, 0, 0.8)))
	assert(k.root.get_child_count() == 0 and k.wheels.is_empty())
	k.root.free()
	# Forklift channels remain clear while feet and lower runners carry the load.
	k = kit()
	VehicleCargo.pallet(k, k.root, Vector3.ZERO, Vector2(1, 1), 0.15)
	assert(not occupied(k, Vector3(0.38, 0.075, 0.185)))
	assert(occupied(k, Vector3(0.38, 0.075, 0.37)))
	assert(is_equal_approx(bounds(k).size.y, 0.15))
	k.root.free()
	# Size variants change dimensions without leaking construction pivots or
	# borrowing another can's cached shoulder. Rotation affects the whole fitting.
	for size: Vector3 in [Vector3(0.1, 0.25, 0.18), Vector3(0.17, 0.46, 0.34), Vector3(0.25, 0.65, 0.42)]:
		k = kit()
		VehicleFittings.jerrycan(k, k.root, Vector3.ZERO, Color.OLIVE, Vector3(0, PI / 2, 0), 0.17, size)
		var box := bounds(k)
		assert(absf(box.size.x - size.z) < 0.025)
		assert(box.size.y > size.y and box.size.y < size.y * 1.2)
		assert(box.size.z < size.x * 1.2)
		assert(k.root.get_child_count() == 0 and k.wheels.is_empty())
		k.root.free()
	for burnt in [false, true]:
		k = kit()
		k.burnt = burnt
		VehicleEquipment.sensor(k, k.root, Vector3.ZERO, Vector3.ONE * 0.4, "paint", Color.OLIVE, "ball")
		assert(bounds(k).size.length() < 0.85)
		if burnt:
			for part: Array in k._parts[k.root]:
				assert(part[1] == Mats.get_mat(VehicleMaterials.key("burnt", k.surface_family)))
		k.root.free()
	k = kit()
	VmCsat._tempest(k, 0, "ammo")
	assert(occupied(k, Vector3(0.75, 2.40, -0.55)), "Missile cases should occupy the load bed")
	assert(not occupied(k, Vector3(0.75, 2.47, -0.55)), "Palletized cases must leave clearance below the folded crane boom")
	k.root.free()
	print("VEHICLE_DETAIL passed")
	TestRun.quit(get_tree())
