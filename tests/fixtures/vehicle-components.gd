extends Node

func _ready() -> void:
	TestRun.watch()
	# A spare must be folded into the chassis, not join the animated wheel list.
	var model := VehicleModels.new()
	model.root = Node3D.new()
	model._baking = true
	var position := Vector3(2, 3, 4)
	VehicleWheels.spare(model, model.root, position, 0.5, 0.2, Vector3(PI / 2, 0, 0))
	assert(model.wheels.is_empty())
	assert(model.root.get_child_count() == 0)
	var bounds := _bounds(model._parts[model.root])
	assert(bounds.get_center().distance_to(position) < 0.01)
	assert(bounds.size.x > 0.95 and bounds.size.y > 0.95 and bounds.size.z < 0.3, "Upright spare must keep its axle along Z")
	var wheel := VehicleWheels.road(model, model.root, Vector3(1, 0.5, 0), 0.5, 0.3, "paint", Color.OLIVE, 5)
	assert(model.wheels.size() == 1 and model.wheels[0] == wheel)
	assert(model._parts.has(wheel), "All road-wheel detail must rotate with its wheel")
	assert(VehicleFrames.tube(model, model.root, Vector3.ZERO, Vector3.ZERO, 0.1, "steel") == null)
	assert(VehicleFrames.aim(Vector3.DOWN).y.is_equal_approx(Vector3.DOWN))
	model.root.free()

	# Both winding orders must put pads outside the track, not inside the wheels.
	for reverse in [false, true]:
		var k := VehicleModels.new()
		k.root = Node3D.new()
		k._baking = true
		var outline := PackedVector2Array([Vector2(-1, -0.5), Vector2(1, -0.5), Vector2(1, 0.5), Vector2(-1, 0.5)])
		if reverse:
			outline.reverse()
		VehicleTracks.shoes(k, k.root, 0, 0.4, outline, 0.08, 0.2)
		var parts: Array = k._parts[k.root]
		assert(parts.size() == 90, "Six-metre perimeter should produce 30 shoes, pads and pins")
		for i in range(0, parts.size(), 3):
			var shoe: Vector3 = parts[i][4]
			var pad: Vector3 = parts[i + 1][4]
			assert(pad.length_squared() > shoe.length_squared(), "Pad must face away from the track centre")
			assert(shoe.distance_to(pad) < 0.06)
		var bounds2 := _bounds(parts)
		assert(bounds2.size.z < 2.25 and bounds2.size.y < 1.25, "Shoes must follow the supplied envelope")
		k.root.free()
	# Smoothing changes shading only: window fits and collision envelopes stay put.
	var hull := VmHeli.Hull.new([[-1, 0, 1, 1, 1, 1, 1], [1, 0, 1, 1, 1, 1, 1]], 16)
	var original := hull.mesh("test_body_skin")
	var smooth := VehicleBody.skin(original, "test_body_skin")
	assert(VehicleBody.skin(original, "test_body_skin") == smooth)
	var old_arrays := Mats._arrays(original, 0)
	var new_arrays := Mats._arrays(smooth, 0)
	assert(old_arrays[Mesh.ARRAY_VERTEX] == new_arrays[Mesh.ARRAY_VERTEX])
	assert(original.get_aabb() == smooth.get_aabb())
	var changed := false
	for i in new_arrays[Mesh.ARRAY_NORMAL].size():
		var normal: Vector3 = new_arrays[Mesh.ARRAY_NORMAL][i]
		assert(normal.is_finite() and absf(normal.length() - 1.0) < 0.001)
		changed = changed or not normal.is_equal_approx(old_arrays[Mesh.ARRAY_NORMAL][i])
	assert(changed, "Curved skins need interpolated normals")
	# Each material builds the appropriate edge; fabric and moulded panels
	# must not inherit the sheet-metal fasteners or animated part slots.
	for material in ["paint", "canvas_white", "rubber", "plain_dark", "wood", "glass"]:
		var kit := VehicleModels.new()
		kit.root = Node3D.new()
		kit._baking = true
		VehicleBody.panel(kit, kit.root, Vector3.ZERO, Vector2(1.2, 0.8), Vector3.ZERO, material)
		assert(kit.wheels.is_empty() and kit.root.get_child_count() == 0)
		assert(kit._parts.has(kit.root))
		var panel_bounds := _bounds(kit._parts[kit.root])
		assert(panel_bounds.size.x <= 1.25 and panel_bounds.size.y <= 0.85)
		for part: Array in kit._parts[kit.root]:
			if material in ["canvas_white", "rubber", "plain_dark", "wood"]:
				assert((part[1] as ShaderMaterial).get_shader_parameter("metal") == 0.0)
		kit.root.free()
	var box := Res.box(Vector3(2, 1, 0.2))
	var painted := VehicleBody.paint_mesh(box)
	assert(VehicleBody.paint_mesh(box) == painted)
	var original_flat := Mats._flat(box, 0)
	var paint_flat := Mats._flat(painted, 0)
	assert(original_flat[0] == paint_flat[0] and original_flat[1] == paint_flat[1])
	assert(paint_flat[3] != null)
	# Service fittings retain their authored parent and leave animation slots alone.
	var fittings := VehicleModels.new()
	fittings.root = Node3D.new()
	fittings._baking = true
	VehicleFittings.exhaust(fittings, fittings.root, Vector3.ZERO, Vector3.RIGHT, 1.5, 0.1)
	var pipe_parts: Array = fittings._parts[fittings.root]
	assert(pipe_parts[0][0] is CylinderMesh and not (pipe_parts[0][0] as CylinderMesh).cap_top)
	assert((pipe_parts[1][0] as CylinderMesh).flip_faces)
	var pipe_bounds := _bounds(pipe_parts)
	assert(pipe_bounds.size.x > 1.49 and pipe_bounds.size.y < 0.4)
	VehicleFittings.grille(fittings, fittings.root, Vector3(3, 0, 0), Vector2(1.5, 0.5), Vector3.ZERO, "paint")
	VehicleFittings.mudflap(fittings, fittings.root, Vector3(5, 0, 0), Vector2(0.5, 0.4))
	fittings._bag(fittings.root, Vector3(0.7, 0.3, 0.4), Vector3(7, 0, 0), "canvas", Color.OLIVE, Vector3(0, 0.4, 0))
	assert(fittings.wheels.is_empty() and fittings.root.get_child_count() == 0)
	_bounds(fittings._parts[fittings.root])
	fittings.root.free()
	var weapon := VehicleModels.new()
	weapon.root = Node3D.new()
	weapon._baking = true
	weapon.elev = weapon._pivot(weapon.root, Vector3(0, 2, 0))
	weapon.gun_tip = weapon._tip(weapon.elev, Vector3(2, 0, 0))
	VehicleFittings.barrel(weapon, weapon.elev, Vector3.ZERO, Vector3(2, 0, 0), 0.1, "paint")
	var gun_parts: Array = weapon._parts[weapon.elev]
	assert(not (VehicleFittings._barrels[Vector2(0.1, 2.0)][0] as CylinderMesh).cap_top)
	assert((gun_parts[1][0] as CylinderMesh).flip_faces)
	assert(_bounds(gun_parts).size.x > 1.99 and _bounds(gun_parts).size.y < 0.3)
	assert(weapon.gun_tip.get_parent() == weapon.elev and weapon.gun_tip.position == Vector3(2, 0, 0))
	VehicleFittings.antenna(weapon, weapon.root, Vector3.ZERO, 2.0)
	VehicleFittings.mirror(weapon, weapon.root, Vector3(1, 1, 0), Vector2(0.22, 0.4), 0.3, [Vector3(0.7, 1, 0)])
	assert(weapon.root.get_child_count() == 2 and weapon.wheels.is_empty())
	assert(weapon.antennas.size() == 1)
	var whip_parts: Array = weapon._parts[weapon.antennas[0]]
	for part: Array in whip_parts:
		assert(part[1] == whip_parts[0][1], "A whip should merge into one material draw")
	assert(Mats.get_mat(VehicleMaterials.key("mirror", "armor")).get_shader_parameter("metal") == 1.0)
	add_child(weapon.root)
	var whip := weapon.antennas[0]
	for frame in 120:
		weapon.update_antennas(Vector3(0, 0, -12), 1.0 / 60)
	assert(whip.rotation.x > 0.09 and absf(whip.rotation.z) < 0.001)
	# Reversing travel changes lean, then a stop returns it to rest.
	for frame in 120:
		weapon.update_antennas(Vector3(0, 0, 12), 1.0 / 60)
	assert(whip.rotation.x < -0.09)
	for frame in 240:
		weapon.update_antennas(Vector3.ZERO, 1.0 / 60)
	assert(whip.rotation.length() < 0.001)
	weapon.update_antennas(Vector3(0, 0, -12), 1.0 / 30)
	weapon.update_antennas(Vector3.ZERO, 1.0 / 30, false)
	assert(whip.rotation == Vector3.ZERO)
	# Traversing its parent does not rotate the world-space direction of drag.
	weapon.root.rotation.y = PI / 2
	for frame in 90:
		weapon.update_antennas(Vector3(0, 0, -12), 1.0 / 30)
	assert(whip.global_basis.y.z > 0.09)
	weapon.update_antennas(Vector3(1000, 0, 0), 1.0 / 30)
	assert(whip.rotation == Vector3.ZERO)
	weapon.root.free()
	print("VEHICLE_COMPONENTS passed")
	TestRun.quit(get_tree())

func _bounds(parts: Array) -> AABB:
	var bounds := AABB()
	var first := true
	for part: Array in parts:
		var basis: Basis = part[7] if part[7] is Basis else Basis.from_euler(part[5]).scaled(part[6])
		var transformed: AABB = Transform3D(basis, part[4]) * (part[0] as Mesh).get_aabb()
		assert(transformed.position.is_finite() and transformed.size.is_finite())
		bounds = transformed if first else bounds.merge(transformed)
		first = false
	return bounds
