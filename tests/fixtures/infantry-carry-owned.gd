extends "res://tests/fixtures/infantry-special.gd"

func _ready() -> void:
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	MapDims.BIOME = 64
	Defs.MAP_HALF = 32.0
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
	var infantry: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var structures: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var doors: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/infantry-update.gd").new()
	var seen := {}
	checks = 0
	for trial in 256:
		var w: World = ground_world()
		var nav := SpecialRoutes.new()
		nav._planner = w.nav._planner
		w.nav = nav
		w.settings = {"rust_infantry": false}
		w.water = WaterMap.new(w)
		w.rules = Rules.new(w)
		w.combat = ScanCombat.new(w)
		w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
		w.combat._visibility = ClassDB.instantiate("VisibilityCore")
		w.rng.seed = 91591 + trial
		random.seed = 91591 + trial
		var q := Squad.new()
		q.world = w
		q.sid = 9
		w.squads[q.sid] = q
		var qcore: SquadStateCore = ClassDB.instantiate("SquadStateCore")
		var cores: Array[SquadStateCore] = [qcore]
		var tent := Mount.new()
		tent.eid = 10
		tent.world = w
		tent.skind = "medic_tent"
		tent.position = Vector3(15, 0, 0)
		tent.rotation.y = [0.0, 1.3, -2.5][trial % 3]
		tent.size = Vector3(5, 3, 7)
		tent.gone = trial % 11 == 0
		w.add_child(tent)
		w.entities[10] = tent
		for id in [1, 2, 3]:
			var s := make_soldier(w, id, 0)
			s.utype = "bearer" if id < 3 else "rifleman"
			s.udef = Defs.UNITS[s.utype]
			s.wdef = Defs.WEAPONS.get(s.udef.weapon, {})
			s.position = Vector3((id - 1) * 0.3, 0, 0)
			s.rotation.y = [0.0, 1.3, -2.5][trial % 3]
			s._last_dir = Vector3(0.3, 0, -0.9).normalized()
			s.squad = q
			s.sid = q.sid
			q.members.append(s)
			w.soldiers.append(s)
		var p: Soldier = w.entities[3]
		p.life = Soldier.Life.DEAD if trial % 2 == 0 else Soldier.Life.DOWNED
		if trial % 17 == 0: p.life = Soldier.Life.ALIVE
		p.stretcher_claimed = true
		p.carried_by = [w.entities[1], w.entities[2]] if trial % 3 == 2 else ([w.entities[1]] if trial % 3 == 1 else [])
		p.position.x = [0.0, 1.79, 1.8, 1.81, 10.0][trial % 5]
		p.dragged_by = w.entities[1] if trial % 19 == 0 else null
		for id in [1, 2]:
			var s: Soldier = w.entities[id]
			s.task = "stretcher"
			s.task_ent = p if trial % 23 else null
			s.task_ent2 = w.entities[2 if id == 1 else 1]
			s.task_phase = (trial / (1 if id == 1 else 4)) % 4
			s.task_t = [-8.0, -0.1, 0.1, 0.35, 1.0][trial % 5]
			s.is_front = (id == 1) == (trial % 3 != 0)
			s.home = tent
			s.say_cd = 5.0
			s.goal_kind = "task"
			s.path = PackedVector3Array([Vector3(8, 0, 0)]) if trial % 5 == 0 else PackedVector3Array()
			s._path_pending = trial % 7 == 0
			s.goal = Vector3(8, 0, 0)
			s._gy_t = -1.0
			if id == 2 and trial % 13 == 0: s.life = Soldier.Life.DEAD
		var blocks := []
		var kinds := PackedByteArray()
		for e in w.soldiers: blocks.append(soldier_bytes(e)); kinds.append(0)
		if not tent.gone:
			assert(structure.load_state(StructureState.capture(tent)))
			blocks.append(structure.checkpoint()); kinds.append(1)
		assert(actors.load_state(100, kinds, blocks))
		assert(qcore.load_state(SquadState.capture(q)))
		assert(units.load_state(12.0, []) and units.rebuild_units(actors) and structures.load_state(16.0, []) and doors.load_state(1.5, []))
		w._rebuild_uhash()
		for step in 8:
			w.time = 10.0 + step * 0.1
			for id in [1, 2]:
				var s: Soldier = w.entities[id]
				w.spoken.clear(); w.stats.clear(); w.effects.clear(); w.props.clear(); w.nav.jobs.clear(); w.nav.cancelled.clear()
				var result := [[]]
				if s.task == "stretcher":
					s._stretcher_tick(0.1)
					result = actors.advance_infantry_stretcher(id, 0.1, w.time, PackedFloat64Array(), cores, w.water.deck, w.terrain._native, w.nav._planner, units, structures, doors, w.combat._collision, random._backend)
				assert(result.size() == 1, "carry %d/%d/%d" % [trial, step, id])
				for person in w.soldiers:
					assert(infantry.restore(actors.actor_state(person.eid)))
					helper.check_state(person, infantry, "carry %d/%d/%d/%d" % [trial, step, id, person.eid]); checks += 1
				assert(qcore.values() == SquadState.capture(q), "carry squad")
				var speech := []
				var stats := {}
				var jobs := []
				var cancelled := []
				for event: Array in result[0]:
					match int(event[0]):
						0:
							var move: Array = event[2]
							match int(move[0]):
								0: jobs.append([event[1], move[3], false, 0, move[4]])
								1: cancelled.append(event[1])
								7: stats[move[1]] = stats.get(move[1], 0) + 1
								_: assert(false, "unexpected stretcher movement event")
						1:
							speech.append([event[1], ["Lift on three!", "I've got him!", "Bearer down! I'll drag him!"][event[2]]])
							seen["speech_%d" % event[2]] = true
						2: stats.into_tent = stats.get("into_tent", 0) + 1
				assert(w.rng.state == random.state, "carry random")
				assert(w.spoken == speech and w.stats == stats and w.props.is_empty() and w.effects.is_empty(), "carry events %d/%d/%d" % [trial, step, id])
				assert(w.nav.cancelled == cancelled and w.nav.jobs.size() == jobs.size(), "carry routes")
				for i in jobs.size(): assert(w.nav.jobs[i].slice(0, 5) == jobs[i])
				for key: String in stats: seen[key] = true
			if step == 3:
				assert(actors.restore(actors.checkpoint()) and qcore.restore(qcore.checkpoint()))
		w.free()
	helper.free()
	for key in ["into_tent", "speech_0", "speech_1", "speech_2"]: assert(seen.has(key), "must exercise " + key)
	print("INFANTRY_CARRY_OWNED passed states=", checks)
	get_tree().quit()
