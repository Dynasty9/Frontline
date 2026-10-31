extends "res://tests/fixtures/vehicle-sling.gd"

class Transport extends Carrier:
	var requests := 0
	func dismount() -> void:
		requests += 1
	func exit_passengers() -> void:
		super.dismount()

class Orders extends Squad:
	var calls := []
	func get_leader() -> Soldier:
		return null
	func order_defend(p: Vector3, f: Vector3, _direct := false) -> void:
		calls.append([false, p, f])
	func order_assault(p: Vector3, f: Vector3, _deliberate := true) -> void:
		calls.append([true, p, f])

func _ready() -> void:
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	MapDims.BIOME = 64
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	var w := ground_world()
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	assert(units.load_state(12.0, []))
	checks = 0
	var observed := {}
	for trial in 128:
		w.soldiers.clear()
		w.vehicles.clear()
		w.stats.clear()
		for z in Nav.N:
			for x in Nav.N:
				var solid := trial % 3 == 2 or (trial % 3 == 1 and x < 40)
				w.nav.ikind[z * Nav.N + x] = Nav.SOLID if solid else Nav.FREE
				w.nav.inf.set_point_solid(Vector2i(x, z), solid)
		assert(w.nav._planner.load_cells(w.nav.ikind, w.nav.vkind, w.nav.heat))
		var q := Orders.new()
		q.world = w
		q.sid = 90
		q.team = 0
		var v := Transport.new()
		v.world = w
		v.srv = true
		v.eid = 1
		v.team = 0
		v.vkind = ["ifv", "rhib", "tank", "technical"][trial % 4]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.hp = v.vdef.hp * (0.3 if trial % 7 == 0 else 1.0)
		v.max_hp = v.vdef.hp
		v.position = Vector3(0.3, 0, 1.7)
		v.rotation.y = trial * 0.37
		v.speed = 3.0 if trial % 5 == 0 else 0.0
		v.path = PackedVector3Array([Vector3(20, 0, 0)]) if trial % 6 == 0 else PackedVector3Array()
		v.assault = trial % 2 == 0
		v.assault_dest = Vector3(21, 0, 7) if trial % 3 != 0 else Vector3.INF
		v._landing = trial % 3 == 0
		v._dis_t = 0.2
		w.add_child(v)
		w.vehicles.append(v)
		var blocks := []
		var types := PackedByteArray()
		var members := []
		for id in range(2, 7):
			var s := make_soldier(w, id, 0)
			s.life = Soldier.Life.ALIVE if id == 3 and trial % 3 == 1 else Soldier.Life.HIDDEN
			s.hidden_reason = "vehicle"
			s.riding = v
			s.squad = q if id != 6 or trial % 5 != 0 else null
			s.sid = q.sid if s.squad else 0
			v.passengers.append(s)
			w.soldiers.append(s)
			members.append(s)
			blocks.append(soldier_bytes(s))
			types.append(0)
		var enemy := Carrier.new()
		enemy.world = w
		enemy.eid = 7
		enemy.team = 1
		enemy.vkind = "tank"
		enemy.vdef = Defs.VEHICLES.tank
		enemy.position = Vector3(0, 0, -30)
		enemy.vis_mask = 1 if trial % 2 == 0 else 0
		w.add_child(enemy)
		w.vehicles.append(enemy)
		blocks.append(vehicle_bytes(v, core))
		types.append(2)
		blocks.append(vehicle_bytes(enemy, core))
		types.append(2)
		assert(actors.load_state(8, types, blocks))
		if trial % 7 == 1:
			members[2].gone = true
			assert(actors.remove(members[2].eid))
		w._rebuild_uhash()
		assert(units.rebuild_units(actors))
		for step in 4:
			var before := v.requests
			var due: int = actors.dismount_due(1, 0.1, v.base() == "lift_heli", v.is_boat(), w.nav._planner, units)
			v._dismount_check(0.1)
			assert(due == int(v.requests > before), "Dismount schedule %d/%d" % [trial, step])
			compare_owned(v, actors, core, "schedule %d/%d" % [trial, step])
		var result: Array = actors.dismount(1, v.is_boat(), w.nav._planner)
		assert(result.size() == 5)
		v.exit_passengers()
		assert(bool(result[0]) == w.stats.has("dismount"))
		compare_owned(v, actors, core, "empty transport %d" % trial)
		if result[0]:
			observed["boat" if v.is_boat() else "ground"] = true
			if int(result[1]) > 0:
				assert(q.calls.size() == 1 and bool(result[4]) == bool(q.calls[0][0]))
				assert((result[2] as Vector3).distance_to(q.calls[0][1]) < 0.0001)
				assert((result[3] as Vector3).distance_to(q.calls[0][2]) < 0.0001)
			else:
				assert(q.calls.is_empty(), "Squad order trial=%d result=%s calls=%s last=%s" % [trial, result, q.calls, members.back().squad])
		for s in members:
			if not s.gone:
				compare_actor(s, actors, "passenger %d/%d" % [trial, s.eid])
			s.free()
		var saved: PackedByteArray = actors.checkpoint()
		assert(actors.restore(saved) and actors.checkpoint() == saved)
		v.free()
		enemy.free()
	for key in ["boat", "ground"]:
		assert(observed.has(key))
	w.free()
	print("VEHICLE_TRANSPORT passed states=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
