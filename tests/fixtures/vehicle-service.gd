extends "res://tests/fixtures/vehicle-sling.gd"

func supplies(w: World) -> Array:
	var out := []
	for s in w.soldiers:
		var gun: Dictionary = s.cur_weapon()
		var restored: String = String(s.udef.weapon) if Defs.WEAPONS.has(s.udef.weapon) else ""
		out.append([s.eid, PackedInt32Array([s.wdef.get("ammo", -1), s.udef.frags + int(w.rules.has_upgrade(s.team, "grenades")), s.udef.smokes, s.udef.get("rockets", 0), s.udef.get("drones", 0), s.udef.get("mortar", 0), gun.get("ammo", 0), gun.get("mag", 30)]), gun.get("reload", 2.0), restored, Defs.WEAPONS[restored].mag if restored != "" else 0])
	return out

func missiles(w: World) -> Array:
	var out := []
	for v in w.vehicles: out.append(PackedInt64Array([v.eid, v.vdef.get("atgm", [0, 0])[0], v.vdef.get("sam", [0, 0])[0]]))
	return out

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
	w.rules = Rules.new(w)
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var core: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var random: RefCounted = ClassDB.instantiate("SimulationRandomCore")
	assert(units.load_state(12.0, []))
	var kinds := Defs.VEHICLES.keys()
	var infantry := Defs.UNITS.keys()
	checks = 0
	var observed := {}
	for trial in 96:
		w.rng.seed = 137 + trial
		random.set_seed(137 + trial)
		w.rules.upgrades = [{"grenades": true}, {}] if trial % 2 == 0 else [{}, {"grenades": true}]
		var v := Carrier.new()
		v.world = w
		v.srv = true
		v.eid = 1
		v.team = trial % 2
		v.vkind = "tank"
		v.vdef = Defs.VEHICLES.tank.duplicate()
		v.vdef.service = ["repair", "ammo", "medical"][trial % 3]
		v.speed = 2.1 if trial % 7 == 0 else (-2.1 if trial % 7 == 1 else 0.0)
		w.add_child(v)
		w.vehicles.append(v)
		w.entities[1] = v
		for id in range(2, 14):
			var s := make_soldier(w, id, 1 - v.team if id % 5 == 0 else v.team)
			s.utype = infantry[(trial + id) % infantry.size()]
			s.udef = Defs.UNITS[s.utype]
			s.wdef = Defs.WEAPONS.get(s.udef.weapon, {})
			if id % 4 == 0: s.wdef = {}
			s.life = [Soldier.Life.ALIVE, Soldier.Life.DOWNED, Soldier.Life.HIDDEN, Soldier.Life.DEAD][(trial + id) % 4]
			s.position = Vector3((id - 7.5) * 2.3, -0.7 if id % 3 == 0 else 0, (id % 3 - 1) * 6.0)
			s.hp = 30.3 + id
			s.mag = 0 if id % 2 == 0 else 7
			s.reserve = 0
			s.say_cd = 3.0 if id % 4 == 0 else 0.0
			s.out_said = true
			s.low_ammo_said = true
			if id % 7 == 0: s.dragged_by = w.entities[2]
			if id % 6 == 0: s.carried_by = [w.entities[2], w.entities[3]]
			w.soldiers.append(s)
		for id in range(14, 17):
			var other := Carrier.new()
			other.world = w
			other.srv = true
			other.eid = id
			other.team = 1 - v.team if id == 16 else v.team
			other.vkind = kinds[(trial + id) % kinds.size()]
			other.vdef = Defs.VEHICLES[other.vkind]
			other.hp = other.vdef.hp * 0.3
			other.max_hp = other.vdef.hp
			other.track_broken = id % 2 == 0
			other.track_fix = 4.7
			other.position = Vector3(id - 10, 0, -1)
			w.add_child(other)
			w.vehicles.append(other)
			w.entities[id] = other
		var blocks := [vehicle_bytes(v, core)]
		var types := PackedByteArray([2])
		for s in w.soldiers:
			blocks.append(soldier_bytes(s))
			types.append(0)
		for id in range(14, 17):
			blocks.append(vehicle_bytes(w.entities[id], core))
			types.append(2)
		assert(actors.load_state(17, types, blocks))
		w._rebuild_uhash()
		assert(units.rebuild_units(actors))
		for step in 24:
			var dt: float = [0.1, 0.7, 1.1][(trial / 3) % 3]
			w.time = step * dt
			w.stats.clear()
			w.spoken.clear()
			w.props.clear()
			var result: Array = actors.service_vehicle(1, dt, v.vdef.service, units, random, supplies(w), missiles(w))
			assert(result.size() == 1)
			v._service_tick(dt)
			var speech := []
			var revived := 0
			var repaired := 0
			for e in result[0]:
				if e[0] == 0:
					repaired += 1
					if e[2]: observed["track"] = true
				else:
					var choices: Array = ["Reloading!", "Changing mag!", "Cover me, reloading!"] if e[0] == 1 else ["Thanks, doc.", "I'm good, I'm good!", "Back in the fight.", "Ugh... let's go."]
					speech.append([e[1], choices[e[2]]])
					if e[0] == 2: revived += 1
			assert(w.spoken == speech)
			assert(w.stats.get("veh_repaired", 0) == repaired)
			assert(w.stats.get("veh_medevac_revive", 0) == revived and w.stats.get("revived", 0) == revived)
			assert(w.props.size() == revived)
			assert(w.rng.state == random.get_state(), "Service RNG %d/%d" % [trial, step])
			for s in w.soldiers:
				compare_actor(s, actors, "service %d/%d/%d" % [trial, step, s.eid])
				checks += 1
			for other in w.vehicles: compare_owned(other, actors, core, "service vehicle %d/%d/%d" % [trial, step, other.eid])
			if revived: observed["revived"] = true
			if repaired: observed["repaired"] = true
			if not speech.is_empty(): observed["speech"] = true
			if step % 7 == 0:
				var saved: PackedByteArray = actors.checkpoint()
				assert(actors.restore(saved) and actors.checkpoint() == saved)
		for s in w.soldiers: s.free()
		for other in w.vehicles: other.free()
		w.soldiers.clear()
		w.vehicles.clear()
		w.entities.clear()
	for key in ["track", "revived", "repaired", "speech"]: assert(observed.has(key), "Fixture must exercise " + key)
	w.free()
	print("VEHICLE_SERVICE passed states=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
