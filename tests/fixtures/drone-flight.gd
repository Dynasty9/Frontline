extends Node

class DroneWorld extends World:
	func despawn(e: Entity) -> void:
		e.gone = true
	func fx_event(_event: Array) -> void:
		pass
	func send_msg(_team: int, _kind: String, _text: String, _ping = null) -> void:
		pass

class DroneCombat extends Combat:
	var explosions: Array = []
	func explode(pos: Vector3, data: Dictionary) -> void:
		explosions.append([pos, data])


func _ready() -> void:
	assert(ClassDB.class_exists("DroneFlightCore"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9471
	for trial in 72:
		var operator := Soldier.new()
		var target := Soldier.new()
		target.position = Vector3(rng.randf_range(-120, 120), 0, rng.randf_range(-120, 120))
		var worlds: Array[DroneWorld] = [DroneWorld.new(), DroneWorld.new()]
		var pair: Array[Drone] = [Drone.new(), Drone.new()]
		var start := Vector3(rng.randf_range(-40, 40), rng.randf_range(1, 10), rng.randf_range(-40, 40))
		for i in 2:
			worlds[i].has_view = false
			worlds[i].combat = DroneCombat.new(worlds[i])
			worlds[i].combat.enable_native_collision()
			pair[i].world = worlds[i]
			pair[i].position = start
			pair[i].target_pos = start
			pair[i].target = target
			pair[i].operator = operator
			pair[i].warhead = 1.5 if trial % 2 else 1.0
		pair[1]._flight = ClassDB.instantiate("DroneFlightCore")
		assert(pair[1]._flight.reset(start, 0.0))
		var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][trial % 3]
		for tick in 3100:
			if tick == 20 and trial % 6 == 0:
				operator.life = Soldier.Life.DEAD
			if tick == 140 and trial % 6 == 1:
				operator.gone = true
			if tick == 35 and trial % 6 == 2:
				target.life = Soldier.Life.DEAD
			if tick == 50 and trial % 6 == 3:
				target.gone = true
			if tick == 12 and trial % 6 == 4:
				for drone in pair:
					drone.shot_down()
			if trial % 6 == 5:
				target.position.x += 1.5 * dt
			if tick % 17 == 0:
				var checkpoint: PackedByteArray = pair[1]._flight.checkpoint()
				assert(pair[1]._flight.restore(checkpoint))
				var bad := checkpoint.duplicate()
				bad[4] = 2
				assert(not pair[1]._flight.restore(bad))
				assert(pair[1]._flight.checkpoint() == checkpoint)
			for drone in pair:
				drone.sim(dt)
			var a := pair[0]
			var b := pair[1]
			assert(a.position.distance_to(b.position) < 0.002, "Drone position trial=%d tick=%d expected=%s actual=%s" % [trial, tick, a.position, b.position])
			assert(a.vel.distance_to(b.vel) < 0.002)
			assert(absf(angle_difference(a.rotation.y, b.rotation.y)) < 0.0001)
			for key in ["life_t", "phase", "diving", "dead", "gone", "operator", "target"]:
				assert(a.get(key) == b.get(key), "Drone %s trial=%d tick=%d" % [key, trial, tick])
			if a.gone:
				break
		assert(pair[0].gone and pair[1].gone)
		var expected: Array = (worlds[0].combat as DroneCombat).explosions
		var actual: Array = (worlds[1].combat as DroneCombat).explosions
		assert(expected.size() == actual.size())
		if not expected.is_empty():
			assert((expected[0][0] as Vector3).distance_to(actual[0][0]) < 0.002)
			assert(expected[0][1] == actual[0][1])
		for drone in pair:
			drone.free()
		for world in worlds:
			world.free()
		operator.free()
		target.free()
	print("DRONE_FLIGHT passed cases=72")
	get_tree().quit()
