extends Node

class TestTank extends Vehicle:
	var shots := 0
	func _fire_cannon() -> void:
		shots += 1

class TurningTank extends Vehicle:
	func _drive(_dt: float) -> void:
		rotation.y += 0.02


func _ready() -> void:
	var tank := TestTank.new()
	var enemy := Vehicle.new()
	tank.vdef = {"base": "tank", "cannon": true, "mg": ""}
	enemy.vdef = {"base": "tank"}
	enemy.eid = 10
	enemy.position = Vector3(50, 0, 0)
	tank.target = enemy
	tank.cannon_t = 0.0
	var dt := 1.0 / 30.0
	tank._turret_tick(dt)
	assert(absf(tank.turret_yaw) <= dt * dt + 0.00001, "traverse starts with acceleration")
	for i in 240:
		var previous := tank.turret_yaw
		tank._turret_tick(dt)
		assert(absf(wrapf(tank.turret_yaw - previous, -PI, PI)) <= 0.7 * dt + 0.00001)
	assert(tank._aim_err() < 0.001 and tank._aim_time > 0.3, "gun settles on target")
	tank._fire_tick()
	assert(tank.shots == 1)
	enemy.eid = 11
	tank.cannon_t = 0.0
	tank._turret_tick(dt)
	tank._fire_tick()
	assert(tank.shots == 1, "a new target needs its own firing solution")
	for i in 12:
		tank._turret_tick(dt)
	tank._fire_tick()
	assert(tank.shots == 2)
	tank.target = null
	tank.turret_yaw = TAU - 0.1
	tank._traverse = 0.0
	tank._turret_tick(dt)
	assert(tank.turret_yaw > -0.1, "return to forward takes the shortest arc")
	assert(tank._aim_time == 0.0)
	var moving := TurningTank.new()
	var world := World.new()
	world.terrain = TerrainMap.new(world)
	moving.world = world
	moving.vdef = tank.vdef
	moving.scan_t = 100.0
	moving.smash_t = 100.0
	moving.cannon_t = 100.0
	moving.target = enemy
	moving.turret_yaw = Defs.yaw_of(enemy.position)
	var bearing := moving.turret_yaw
	for i in 30:
		moving.sim(dt)
	assert(absf(wrapf(moving.rotation.y + moving.turret_yaw - bearing, -PI, PI)) < 0.001,
		"gun stays on its world bearing while the hull turns")
	moving.free()
	world.free()
	tank.target = enemy
	enemy.free()
	tank._turret_tick(dt)
	assert(tank._aim_time == 0.0, "a despawned target is safely released")
	tank.free()
	print("TANK_OPERATION passed")
	get_tree().quit()
