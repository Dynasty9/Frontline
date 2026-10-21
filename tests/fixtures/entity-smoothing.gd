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

func _ready() -> void:
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
	world.free()
	print("ENTITY_SMOOTHING passed")
	get_tree().quit()
