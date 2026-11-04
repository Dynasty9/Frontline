extends Node

class Unit extends Entity:
	var changes := 0
	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

class Man extends Soldier:
	var changes := 0
	var floor_y := 0.0
	func _ground() -> float: return floor_y
	func seen_by_local() -> bool: return false
	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

class DisplayedMan extends Soldier:
	var sight_checks := 0
	func seen_by_local() -> bool:
		sight_checks += 1
		return super.seen_by_local()

class Part extends Node3D:
	var changes := 0
	func _notification(what: int) -> void:
		if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
			changes += 1

class Car extends Vehicle:
	func _ground_h(_p: Vector3) -> float: return 0.0
	func seen_by_local() -> bool: return true

func _ready() -> void:
	_check_native_soldier_motion()
	_check_native_soldier_lifecycle()
	_check_shared_presentation_changes()
	var unit := Unit.new()
	add_child(unit)
	unit.set_notify_local_transform(true)
	unit.net_init = true
	unit.net_smooth(0.1)
	assert(unit.changes == 0, "Stationary interpolation must not dirty the model")
	unit.rotation.y = 1.2
	unit.net_yaw = 1.2
	unit.changes = 0
	unit.net_smooth(0.1)
	assert(unit.changes == 0, "Float rounding must not dirty a settled facing")
	unit.net_pos = Vector3(2, 1, -3)
	unit.net_yaw = 1.2
	var expected := unit.position.lerp(unit.net_pos, 1.0 - exp(-0.1 * 14.0))
	var yaw := lerp_angle(unit.rotation.y, unit.net_yaw, 1.0 - exp(-0.1 * 14.0))
	unit.net_smooth(0.1)
	assert(unit.position == expected and is_equal_approx(unit.rotation.y, yaw))
	assert(unit.changes > 0)
	unit.net_pos = Vector3(100, 0, 0)
	unit.net_smooth(0.1)
	assert(unit.position == unit.net_pos, "Teleports still snap")
	unit.net_init = false
	unit.changes = 0
	unit.net_pos = Vector3.ZERO
	unit.net_smooth(0.1)
	assert(unit.changes == 0 and unit.position.x == 100)
	unit.free()
	var man := Man.new()
	add_child(man)
	man.set_process(false)
	man.set_notify_local_transform(true)
	man._settle_y_work(0.1)
	assert(man.changes == 0, "A settled soldier must not dirty his model")
	man.floor_y = -1.0
	var expected_y := lerpf(man.position.y, -1.0, 1.0 - exp(-0.1 * 8.0))
	man._settle_y_work(0.1)
	assert(is_equal_approx(man.position.y, expected_y) and man.changes > 0)
	var world := World.new()
	world.has_view = true
	man.world = world
	man.srv = false
	man.net_pos = man.position
	man.rotation.y = 1.2
	man.net_yaw = 1.2
	man.changes = 0
	man._view_process(0.1)
	assert(man.changes == 0, "Stationary soldier view must not dirty a settled facing")
	man.net_yaw = 2.0
	man._view_process(0.1)
	assert(man.changes > 0 and man.rotation.y > 1.2)
	man.free()
	_check_vehicle(world)
	world.free()
	print("ENTITY_SMOOTHING passed")
	get_tree().quit()


func _check_vehicle(world: World) -> void:
	var car := Car.new()
	car.world = world
	car.srv = false
	add_child(car)
	car.set_process(false)
	car.model = Part.new()
	car.add_child(car.model)
	car.turret = Part.new()
	car.model.add_child(car.turret)
	car._vm = VehicleModels.new()
	car._vm.elev = Part.new()
	car.turret.add_child(car._vm.elev)
	var wheel := Part.new()
	car.model.add_child(wheel)
	car.wheels = [wheel]
	car._steer_k = [1.0]
	var parts := [car.model, car.turret, car._vm.elev, wheel]
	for part: Part in parts:
		part.set_notify_local_transform(true)
	for i in 10:
		car._view_process(1.0 / 60.0)
	for part: Part in parts:
		assert(part.changes == 0, "Idle vehicle parts must not invalidate their model hierarchy")
	car.turret_yaw = 1.2
	car.flags = Vehicle.F_ELEV
	car.position.z = -0.1
	car._view_process(1.0 / 60.0)
	assert(is_equal_approx(car.turret.rotation.y, 1.2) and car.turret.changes > 0)
	assert(car._vm.elev.rotation.x > 0.0 and car._vm.elev.changes > 0)
	assert(is_equal_approx(wheel.rotation.x, -0.1 / 0.42) and wheel.changes > 0)
	assert(car.model.changes > 0, "Acceleration still rocks the hull")
	car.gun_kick(0.2)
	car._view_process(1.0 / 60.0)
	assert(car.turret.position != Vector3.ZERO, "Firing still recoils the turret")
	car.free()


func _check_native_soldier_motion() -> void:
	var actual := Node3D.new()
	var expected := Node3D.new()
	add_child(actual)
	add_child(expected)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7138
	var largest_error := 0.0
	var motion := SoldierViewMotion.new()
	for sample in 1000:
		var p := Vector3(rng.randf_range(-3072, 3072), rng.randf_range(-10, 100), rng.randf_range(-3072, 3072))
		var offset := Vector3(rng.randf_range(-5, 5), rng.randf_range(-1, 1), rng.randf_range(-5, 5))
		if sample % 7 == 0:
			offset = Vector3(0.001, 0.002, 0.003)
		elif sample % 11 == 0:
			offset = Vector3(30, 40, -80)
		var initial_yaw := rng.randf_range(-PI, PI)
		var yaw := rng.randf_range(-PI, PI)
		var blend := 1.0 - exp(-rng.randf_range(0, 0.15) * 14.0)
		actual.position = p
		expected.position = p
		actual.rotation = Vector3(0.1, initial_yaw, -0.2)
		expected.rotation = actual.rotation
		var target := p + offset
		# Reference the former GDScript path, including its one-centimetre rest threshold.
		var moving := absf((target - p).y) > 0.01 or (target - p).length() > 0.01
		if moving:
			expected.position = target if p.distance_to(target) > 8.0 else p.lerp(target, blend)
		var facing := expected.rotation
		facing.y = lerp_angle(facing.y, yaw, blend)
		expected.rotation = facing
		motion.target(actual, target, yaw, true)
		motion.advance(blend)
		largest_error = maxf(largest_error, actual.position.distance_to(expected.position))
		assert(actual.position.is_equal_approx(expected.position))
		assert(actual.rotation.is_equal_approx(expected.rotation))
	assert(largest_error <= 0.0005, "Native interpolation must retain submillimetre agreement on the largest map")
	actual.position = Vector3(1000.25, 17, -1000.25)
	expected.position = actual.position
	actual.rotation = Vector3(0.1, 3.0, -0.2)
	expected.rotation = actual.rotation
	var target := actual.position
	var yaw := -3.0
	motion.target(actual, target, yaw, true)
	for frame in 500:
		if frame % 7 == 0:
			target += Vector3(0.2, 0.01, -0.15)
			yaw = wrapf(yaw + 0.03, -PI, PI)
			motion.target(actual, target, yaw, false)
		var blend := 1.0 - exp(-14.0 / 60.0)
		var delta := target - expected.position
		if absf(delta.y) > 0.01 or delta.length() > 0.01:
			expected.position = expected.position.lerp(target, blend)
		var facing := expected.rotation
		facing.y = lerp_angle(facing.y, yaw, blend)
		expected.rotation = facing
		motion.advance(blend)
		assert(actual.position.distance_to(expected.position) <= 0.0005)
		assert(actual.rotation.is_equal_approx(expected.rotation), "Retained motion must not drift across snapshots")
	motion.remove(actual)
	var before := actual.transform
	motion.advance(0.5)
	assert(actual.transform == before, "Removed soldiers no longer advance")
	motion.target(actual, Vector3.ZERO, 0.0, true)
	actual.free()
	motion.advance(0.5)
	expected.free()


func _check_native_soldier_lifecycle() -> void:
	var world := World.new()
	world.simulation_client = SimulationClient.new()
	world.add_child(world.simulation_client)
	var view := SoldierViewBatch.new()
	view.world = world
	world.soldier_view = view
	add_child(view)
	view.set_process(false)
	var man := Man.new()
	man.world = world
	man.eid = 17
	man.team = 0
	world._register(man)
	add_child(man)
	man.on_spawned()
	view._warmup.clear()
	assert(man._native_view_motion)
	var packet := StreamPeerBuffer.new()
	man.write_state(packet)
	packet.seek(0)
	Entity.put_v3(packet, Vector3(4, 2, -1))
	Entity.put_ang(packet, 1.0)
	packet.seek(0)
	man.read_state(packet)
	var expected := man.position.lerp(man.net_pos, 1.0 - exp(-14.0 / 60.0))
	view._process(1.0 / 60.0)
	assert(man.position.is_equal_approx(expected), "The batch advances a received target exactly once")
	man.apply_props({"pos": Vector3(30, 10, 2), "yaw": 2.0})
	view._process(1.0 / 60.0)
	assert(man.position == Vector3(30, 10, 2), "Property corrections replace the native target")
	world.despawn(man)
	man.position = Vector3.ZERO
	view.motion.advance(0.5)
	assert(man.position == Vector3.ZERO, "Despawn removes the native target before the node is freed")
	man.free()
	view.free()
	world.free()


func _check_shared_presentation_changes() -> void:
	var world := World.new()
	world.local_team = 0
	world.view_team = 0
	world.simulation_client = SimulationClient.new()
	world.add_child(world.simulation_client)
	world.cam = RtsCamera.new()
	world.cam.cam = Camera3D.new()
	add_child(world.cam.cam)
	var view := SoldierViewBatch.new()
	view.world = world
	world.soldier_view = view
	var man := DisplayedMan.new()
	man.world = world
	man.eid = 18
	man.team = 1
	man.vis_mask = 1
	man.position = Vector3(0, 0, -20)
	world._register(man)
	add_child(man)
	man.on_spawned()
	man._view_process(1.0 / 60.0, 0.2, true)
	assert(man.view_lod and man.visible and man.sight_checks == 1)
	for frame in 10:
		view.motion.advance(0.2)
		man._view_process(1.0 / 60.0, 0.2, true)
	assert(man.sight_checks == 1, "Unchanged shared presentation does not repeat visibility and model checks")
	man.selected = true
	man._view_process(1.0 / 60.0, 0.2, true)
	assert(man.sight_checks == 2 and man.ring.visible, "Selection remains immediate")
	var packet := StreamPeerBuffer.new()
	packet.put_float(1.0)
	packet.put_u32(man.eid)
	packet.put_u8(0)
	world._rpc_snap(packet.data_array)
	man._view_process(1.0 / 60.0, 0.2, true)
	assert(not man.visible, "A zero-length hidden snapshot immediately invalidates presentation")
	world.view_team = 1
	man._view_process(1.0 / 60.0, 0.2, true)
	assert(man.visible, "Changing observer team immediately updates visibility")
	view.detail_ids[man.eid] = true
	man._view_process(1.0 / 60.0, 0.2, true)
	assert(not man.view_lod and man.model != null, "Detail promotion bypasses retained presentation")
	man.free()
	view.free()
	world.cam.cam.free()
	world.cam.free()
	world.free()
