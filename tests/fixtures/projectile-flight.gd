extends Node

class FlightWorld extends World:
	var spawned: Array = []
	func despawn(e: Entity) -> void:
		e.gone = true
	func spawn(kind: String, props: Dictionary) -> Entity:
		spawned.append([kind, props])
		return null

class FlightCombat extends Combat:
	var collision := {}
	var explosions: Array = []
	func ray(_from: Vector3, _to: Vector3, _ex: Array = []) -> Dictionary:
		return collision
	func explode(pos: Vector3, data: Dictionary) -> void:
		explosions.append([pos, data])


func _ready() -> void:
	assert(ClassDB.class_exists("ProjectileFlightCore"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8732
	var cases := 0
	for kind in ["frag", "smoke", "rocket", "recoilless", "mortar", "mortar_smoke", "grad", "arty", "ac105", "ac40", "ac25", "bomb"]:
		for trial in 12:
			var worlds: Array[FlightWorld] = [FlightWorld.new(), FlightWorld.new()]
			var pair: Array[Projectile] = [Projectile.new(), Projectile.new()]
			var holder := Soldier.new()
			holder.position = Vector3(3, 0, 2)
			var props := {"ptype": kind, "pos": Vector3(-2, rng.randf_range(1, 30), 7), "vel": Vector3(rng.randf_range(-20, 20), rng.randf_range(-8, 8), 4), "origin": Vector3(10, 2, -7), "target": Vector3(87, 0, 21), "T": rng.randf_range(0.1, 4), "fuse": rng.randf_range(0.3, 3.4)}
			for i in 2:
				worlds[i].has_view = false
				worlds[i].combat = FlightCombat.new(worlds[i])
				pair[i].world = worlds[i]
				pair[i].apply_props(props)
			pair[1]._flight = ClassDB.instantiate("ProjectileFlightCore")
			pair[1]._reset_flight()
			var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][trial % 3]
			for tick in 1900:
				if trial % 2 == 0 and kind in ["frag", "smoke"]:
					if tick == 2:
						for projectile in pair:
							projectile.pick_up(holder)
					if tick == 5:
						holder.life = Soldier.Life.DEAD
				if kind in ["frag", "smoke"] and trial % 2 == 1:
					if tick == 1:
						for projectile in pair:
							projectile.kick(holder, Vector3(8, 2, -3))
					if tick == 2:
						for projectile in pair:
							projectile.release_throw(holder, Vector3(15, 0, 7))
				for w in worlds:
					(w.combat as FlightCombat).collision = {"position": Vector3(1, 1.5, 2), "normal": Vector3(1, 0, 1).normalized()} if tick == 9 and trial % 3 == 1 else {}
				if tick % 13 == 0:
					var checkpoint: PackedByteArray = pair[1]._flight.checkpoint()
					assert(pair[1]._flight.restore(checkpoint))
					var invalid := checkpoint.duplicate()
					invalid[4] = 2
					assert(not pair[1]._flight.restore(invalid))
					assert(pair[1]._flight.checkpoint() == checkpoint)
				for projectile in pair:
					projectile.sim(dt)
				var a := pair[0]
				var b := pair[1]
				assert(a.position.distance_to(b.position) < 0.001, "%s position at tick %d: %s vs %s" % [kind, tick, a.position, b.position])
				assert(a.vel.distance_to(b.vel) < 0.0001, "%s velocity at tick %d" % [kind, tick])
				for key in ["fuse", "flying", "life_t", "smoke_t", "smoke_r", "gone", "held_by"]:
					assert(a.get(key) == b.get(key), "%s %s at tick %d" % [kind, key, tick])
				if a.gone:
					break
			assert(pair[0].gone and pair[1].gone)
			var first: Array = (worlds[0].combat as FlightCombat).explosions
			var second: Array = (worlds[1].combat as FlightCombat).explosions
			assert(first.size() == second.size())
			if not first.is_empty():
				assert((first[0][0] as Vector3).distance_to(second[0][0]) < 0.001)
				assert(first[0][1] == second[0][1], "Impact damage and attribution must match")
			assert(worlds[0].spawned == worlds[1].spawned)
			for projectile in pair:
				projectile.free()
			for w in worlds:
				w.free()
			holder.free()
			cases += 1
	print("PROJECTILE_FLIGHT passed cases=", cases)
	get_tree().quit()
