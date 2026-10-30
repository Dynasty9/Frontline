extends Node

class SupportWorld extends World:
	var events: Array = []
	var nearby_soldiers: Array = []
	var nearby_vehicles: Array = []
	func despawn(e: Entity) -> void:
		e.gone = true
		events.append(["despawn"])
	func spawn(kind: String, props: Dictionary) -> Entity:
		events.append(["spawn", kind, props])
		return null
	func fx_event(event: Array) -> void:
		events.append(["fx", event])
	func soldiers_near(_point: Vector3, _radius: float) -> Array:
		return nearby_soldiers
	func vehicles_near(_point: Vector3, _radius: float) -> Array:
		return nearby_vehicles

class SupportCombat extends Combat:
	func explode(pos: Vector3, data: Dictionary) -> void:
		(world as SupportWorld).events.append(["explode", pos, data])
		# Damage consumes random draws after the incoming rounds have been scheduled.
		world.rng.randi()

class SupportRules extends Rules:
	func add_mark(team: int, point: Vector3, radius: float, linger: float) -> void:
		(world as SupportWorld).events.append(["mark", team, point, radius, linger])


func same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Vector3:
		return (a as Vector3).distance_to(b) < 0.003
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not same(a[key], b[key]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not same(a[i], b[i]):
				return false
		return true
	return a == b


func _ready() -> void:
	assert(ClassDB.class_exists("SupportFlightCore"))
	var setups := [["jet", ""], ["a10", ""], ["ac130", ""], ["ac130", "blackfish"], ["ac130", "xian"], ["ac130", "greyhawk"], ["ac130", "none"]]
	var cases := 0
	for setup in setups:
		for trial in 6:
			var worlds: Array[SupportWorld] = [SupportWorld.new(), SupportWorld.new()]
			var pair: Array[Projectile] = [Projectile.new(), Projectile.new()]
			var soldier := Soldier.new()
			soldier.position = Vector3(11, 0, 3)
			soldier.team = 1
			var vehicle := Vehicle.new()
			vehicle.position = Vector3(-12, 0, 7)
			vehicle.team = 1
			var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1][trial % 3]
			var target := Vector3(2, 0, -5)
			var direction := Vector3(1, 0, 0.5).normalized()
			var props := {"ptype": setup[0], "guns": setup[1], "team": 0, "pos": target - direction * 420.0 + Vector3(0, 62, 0), "vel": direction * 58.0, "target": target, "fuse": 4.0, "by": 77, "sight": 65.0, "stay": 15.0 if setup[0] == "ac130" and trial % 2 == 0 else 0.0}
			props.mk = setup[1] if trial % 2 == 1 else ""
			for i in 2:
				pair[i].eid = 29
				worlds[i].has_view = false
				worlds[i].rng.seed = 8972 + trial
				worlds[i].combat = SupportCombat.new(worlds[i])
				worlds[i].rules = SupportRules.new(worlds[i])
				if trial % 2 == 1:
					worlds[i].nearby_soldiers = [soldier]
					worlds[i].nearby_vehicles = [vehicle]
				pair[i].world = worlds[i]
				pair[i].apply_props(props)
			pair[1]._support = ClassDB.instantiate("SupportFlightCore")
			pair[1]._reset_support()
			for tick in 2300:
				if tick % 19 == 0:
					var checkpoint: PackedByteArray = pair[1]._support.checkpoint()
					assert(pair[1]._support.restore(checkpoint))
					var bad := checkpoint.duplicate()
					bad[4] = 3
					assert(not pair[1]._support.restore(bad))
					assert(pair[1]._support.checkpoint() == checkpoint)
				for i in 2:
					worlds[i].events.clear()
					worlds[i].time += dt
					pair[i].sim(dt)
				assert(pair[0].position.distance_to(pair[1].position) < 0.003, "Support position %s trial=%d tick=%d" % [setup, trial, tick])
				assert(pair[0].vel.distance_to(pair[1].vel) < 0.003, "Support velocity %s trial=%d tick=%d" % [setup, trial, tick])
				for key in ["life_t", "fuse", "_fire_el", "_bombs0", "_mark_t", "gone"]:
					assert(pair[0].get(key) == pair[1].get(key), "Support %s %s trial=%d tick=%d" % [setup, key, trial, tick])
				assert(worlds[0].rng.state == worlds[1].rng.state, "Support RNG %s trial=%d tick=%d" % [setup, trial, tick])
				assert(worlds[0].stats == worlds[1].stats)
				assert(same(worlds[0].events, worlds[1].events), "Support events %s trial=%d tick=%d expected=%s actual=%s" % [setup, trial, tick, worlds[0].events, worlds[1].events])
				if pair[0].gone:
					break
			assert(pair[0].gone and pair[1].gone)
			for p in pair:
				p.free()
			for w in worlds:
				w.free()
			soldier.free()
			vehicle.free()
			cases += 1
	print("SUPPORT_FLIGHT passed cases=", cases)
	get_tree().quit()
