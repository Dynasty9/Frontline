extends "res://tests/fixtures/infantry-blast.gd"

class LossRules extends Rules:
	func nearest_fob(_team: int, _pos: Vector3) -> Structure: return null
	func truck_lost(_v: Vehicle) -> void: pass

class LossWorld extends ActorWorld:
	var crew_before_orders := []
	func stat(key: String) -> void:
		super.stat(key)
		# The crew's return order is a separate world operation, after these births.
		if key == "crew_bailout": crew_before_orders = SquadState.capture(squads.values().back())
	func spawn(kind: String, props: Dictionary) -> Entity:
		if kind != "structure": return super.spawn(kind, props)
		var wreck := Mount.new()
		wreck.world = self
		add_child(wreck)
		return wreck

class Evacuated extends Carrier:
	func _bail_out(_overkill: float) -> void: pass
	func _toss_plan(p: Vector3, y: float) -> Array:
		return [p, y, Vector2.ZERO, Vector3.ZERO, Vector3.ZERO]

func loss_world(seed_value: int) -> LossWorld:
	var w := LossWorld.new()
	w.has_view = false
	w.srv = true
	w.settings = {"rust_infantry": false}
	w.nav = RecordedRoutes.new()
	w.nav._planner = ClassDB.instantiate("PathPlannerCore")
	assert(w.nav._planner.configure(Nav.N))
	w.terrain = TerrainMap.new(w)
	w.rules = LossRules.new(w)
	w.rules.upgrades = [{}, {}]
	w.combat = ScanCombat.new(w)
	w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
	w.battle = BattleStats.new(w)
	w.time = 20.1
	w.rng.seed = seed_value
	w.next_eid = 100
	add_child(w)
	return w

func loadout(kind: String) -> Array:
	var d: Dictionary = Defs.UNITS[kind]
	var weapon: Dictionary = Defs.WEAPONS.get(d.weapon, {})
	return [kind, InfantryState.weapon_key(weapon), float(d.hp), int(weapon.get("mag", 0)), int(weapon.get("ammo", 0)),
		int(d.frags), int(d.smokes), int(d.get("rockets", 0)), int(d.get("mortar", 0)), int(d.get("drones", 0)), bool(d.get("bearer", false))]

func _ready() -> void:
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	Defs.MAP_HALF = 32.0
	MapDims.BIOME = 64
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	HNav.NCC = 16
	HNav._corner = HNav._corners()
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var random := SimulationRandom.new()
	var born := 0
	var kinds := Defs.VEHICLES.keys()
	var seen := {}
	for trial in 256:
		var w := loss_world(62219 + trial)
		random.seed = 62219 + trial
		w.next_sid = trial * 47 + 1
		for team in 2:
			if trial % 2: w.rules.upgrades[team]["armor"] = true
			if trial % 4 >= 2: w.rules.upgrades[team]["grenades"] = true
		var v := Carrier.new()
		v.world = w
		v.srv = true
		v.eid = 20
		v.team = trial % 2
		v.owner_peer = 7
		v.vkind = kinds[trial % kinds.size()]
		v.vdef = Defs.VEHICLES[v.vkind]
		v.max_hp = v.vdef.hp
		v.hp = -v.max_hp * [0.1, 0.35, 0.350001, 0.8][trial % 4]
		v.position = Vector3(27.8 if trial % 7 == 0 else 0.3, 0, -1.7)
		v.rotation.y = trial * 0.137
		v._last_blast = [v.position if trial % 5 == 0 else v.position + Vector3(-1.3, 1, 0.7), 0.5 + trial % 9, w.time - [0.0, 0.599, 0.601][trial % 3]] if trial % 4 else []
		w.add_child(v)
		w.entities[20] = v
		assert(actors.load_state(100, PackedByteArray([2]), [vehicle_bytes(v, vehicle)]))
		var result: Array = actors.bail_out_vehicle(20, -v.hp,
			[v.base(), v.is_heli(), v.is_auto(), int(v.vdef.get("crew", -1)), float(v.vdef.get("cost", 0)),
			w.rules.has_upgrade(v.team, "armor"), w.rules.has_upgrade(v.team, "grenades")],
			loadout("crewman" if v.team == 0 else "r_crewman"), PackedStringArray(Defs.NAMES[v.team]), w.next_sid, w.nav._planner, random._backend)
		assert(result.size() == 4)
		v._bail_out(-v.hp)
		assert(w.next_sid == result[2] and w.rng.state == random.state)
		var expected_attempt := not v.is_heli() and not v.is_auto() and not v.base() in ["supply", "uav", "ugv", "attack_heli", "lift_heli", "boat"]
		assert(result[0] == expected_attempt)
		if result[3].is_empty():
			assert(w.squads.is_empty())
			assert(w.stats.get("crew_lost", 0) == int(expected_attempt))
		else:
			var q: RefCounted = ClassDB.instantiate("SquadStateCore")
			assert(q.restore(result[3]))
			assert(q.values() == w.crew_before_orders, "Crew squad %d" % trial)
			assert(w.stats.crew_bailout == 1 and w.spoken.size() == 1)
			for s: Soldier in w.soldiers:
				compare_actor(s, actors, "crew %d/%d" % [trial, s.eid])
				born += 1
		seen["bailout" if not result[3].is_empty() else "lost" if expected_attempt else "excluded"] = true
		assert(actors.restore(actors.checkpoint()))
		var plan: Array = actors.vehicle_wreck_plan(20, v.weight(), w.time, w.nav._planner, random._backend)
		var reference := v._toss_plan(Vector3(v.position.x, 0, v.position.z), v.rotation.y)
		assert(plan.size() == 5 and w.rng.state == random.state)
		for i in [0, 2, 3, 4]: assert(plan[i].distance_to(reference[i]) < 0.00001, "Wreck %d/%d: %s / %s" % [trial, i, plan[i], reference[i]])
		assert(absf(float(plan[1]) - float(reference[1])) < 0.000000001)
		w.free()
	assert(seen.size() == 3 and born > 100)
	var evacuated := 0
	for trial in 192:
		var w := loss_world(9127 + trial)
		random.seed = 9127 + trial
		var v := Evacuated.new()
		v.world = w
		v.srv = true
		v.eid = 20
		v.team = 0
		v.vkind = "rhib" if trial % 3 else "tank"
		v.vdef = Defs.VEHICLES[v.vkind]
		v.position = Vector3(100 if trial % 7 == 0 else 0.3, 0, 0.7)
		v.hit_by = [8, 1, "v9", 0] if trial % 2 else []
		w.add_child(v)
		w.entities[20] = v
		if trial % 7 == 0:
			w.nav.ikind.fill(Nav.SOLID)
			for z in Nav.N:
				for x in Nav.N: w.nav.inf.set_point_solid(Vector2i(x, z), true)
			assert(w.nav._planner.load_cells(w.nav.ikind, w.nav.vkind, w.nav.heat))
		var q := Squad.new()
		q.world = w
		q.sid = 9
		q.morale = 73.0
		w.squads[9] = q
		var qc: SquadStateCore = ClassDB.instantiate("SquadStateCore")
		var qcores: Array[SquadStateCore] = [qc]
		var kinds_in := PackedByteArray([2])
		var blocks := []
		var stocks := PackedInt64Array()
		for id in range(1, 9):
			var s := make_soldier(w, id, 0)
			s.squad = q
			s.sid = 9
			q.members.append(s)
			s.position = v.position + Vector3(id * 0.4, 0, 0)
			s.life = Soldier.Life.HIDDEN if id < 5 else (trial + id) % 6
			s.riding = v if id < 5 else null
			s.times_downed = trial % 4
			s.hp = 20.0 if trial % 5 == 0 else 100.0
			s.posture = (trial + id) % 5
			if id < 5: v.passengers.append(s)
			w.soldiers.append(s)
			kinds_in.append(0)
			blocks.append(soldier_bytes(s))
			stocks.append_array(PackedInt64Array([id, s.wdef.ammo, 0]))
		blocks.push_front(vehicle_bytes(v, vehicle))
		assert(actors.load_state(100, kinds_in, blocks))
		assert(qc.load_state(SquadState.capture(q)))
		w._rebuild_uhash()
		var cells := []
		for key: Vector2i in w._uhash: cells.append([key, InfantryState.entity_ids(w._uhash[key])])
		assert(units.load_state(12.0, cells))
		var blame := [11, 1, "s5", 0] if trial % 3 else []
		w.battle.blame_hit(blame)
		var hits: Array = actors.evacuate_destroyed_vehicle(20, v.is_boat(), w.time, blame, stocks, w.nav._planner, units, qcores, random._backend)
		assert(hits.size() == 1 and hits[0].size() == 4)
		v._destroyed()
		assert(w.rng.state == random.state, "Evacuation random %d" % trial)
		assert(qc.values() == SquadState.capture(q), "Evacuation squad %d" % trial)
		for s: Soldier in w.soldiers:
			check_blast_actor(s, actors, "evacuation %d/%d" % [trial, s.eid])
			evacuated += 1
		assert(vehicle.restore(actors.actor_state(20)))
		assert(vehicle.values()[7][3].is_empty() and v.passengers.is_empty())
		assert(actors.restore(actors.checkpoint()))
		w.free()
	print("VEHICLE_LOSS passed crew=", born, " wrecks=256 evacuated=", evacuated)
