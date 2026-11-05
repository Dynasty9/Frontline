extends "res://tests/fixtures/infantry-reflex.gd"

const TASKS := ["retreat", "throw", "throw", "board", "tunnel", "pilot", "resupply"]

func _ready() -> void:
	MapDims.N = 128
	MapDims.SIZE = 128.0
	MapDims.HALF = 64.0
	MapDims.BIOME = 128
	Nav.N = 128
	Nav.H = 64.0
	HNav.C = 16
	HNav.NC = 8
	HNav.NCC = 64
	HNav._corner = HNav._corners()
	TerrainMap.N = 128
	TerrainMap.H = 64.0
	TerrainMap.DN = 256
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var infantry: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var structures: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var doors: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/infantry-update.gd").new()
	var seen := {}
	checks = 0
	for mode in TASKS.size():
		for trial in 64:
			var w: World = ground_world()
			var nav := SpecialRoutes.new()
			nav._planner = w.nav._planner
			w.nav = nav
			w.settings = {"rust_infantry": false}
			w.water = WaterMap.new(w)
			w.combat = ScanCombat.new(w)
			w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
			w.combat._visibility = ClassDB.instantiate("VisibilityCore")
			w.rules = Rules.new(w)
			w.rng.seed = 47969 + trial
			random.seed = 47969 + trial
			var qs := []
			var cores: Array[SquadStateCore] = []
			for team in 2:
				var q := Squad.new()
				q.world = w
				q.sid = 9 + team
				q.team = team
				qs.append(q)
				w.squads[q.sid] = q
				cores.append(ClassDB.instantiate("SquadStateCore"))
			for id in [1, 2, 3]:
				var s := make_soldier(w, id, 0 if id < 3 else 1)
				s.position = Vector3((id - 1) * 0.3, 0, 0)
				s.squad = qs[s.team]
				s.sid = s.squad.sid
				s.squad.members.append(s)
				s.posture = trial % 5
				s.rotation.y = [0.0, 1.3, -2.5][trial % 3]
				s.stamina = [0.1, 0.3, 0.349, 0.8][trial % 4]
				s.suppression = [0.0, 6.0, 71.0][trial % 3]
				s.say_cd = 5.0 if trial % 2 else 0.0
				s.last_shot_t = 9.8 if trial % 9 == 0 else -10.0
				s.reload_t = 1.0 if trial % 11 == 0 else 0.0
				w.soldiers.append(s)
			var s: Soldier = w.entities[1]
			w.entities[2].life = Soldier.Life.DEAD
			w.entities[2].loot = 15 + trial
			var v := Carrier.new()
			v.world = w
			v.srv = true
			v.eid = 10
			v.team = 0
			v.vkind = ["truck", "blackfoot", "rhib", "ifv"][trial % 4]
			v.vdef = Defs.VEHICLES[v.vkind].duplicate()
			v.vdef.seats = 1
			v.position = Vector3([3.59, 3.6, 7.9, 17.9, 18.0, 40.0][trial % 6], 1.01 if v.is_heli() and trial % 3 == 0 else 0, 0)
			if trial % 7 == 0: v.passengers = [w.entities[3]]
			w.add_child(v)
			w.entities[10] = v
			w.vehicles.append(v)
			var st := Mount.new()
			st.world = w
			st.srv = true
			st.eid = 20
			st.skind = "tunnel" if mode == 4 else "house_wall"
			st.position = Vector3([2.49, 2.5, 2.51, 12.0][trial % 4], 0, 0)
			st.built = trial % 7 != 0
			w.add_child(st)
			w.entities[20] = st
			var d := QuietDrone.new()
			d.world = w
			d.eid = 30
			d.position = Vector3(10, 3, -7)
			d.dead = trial % 3 == 0
			w.add_child(d)
			w.entities[30] = d
			s.task = TASKS[mode]
			s.task_ent = w.entities[2] if mode == 6 else (v if mode == 3 else st)
			s.task_pos = Vector3([24.99, 25.0, 25.01, 40.0][trial % 4], 0, 0)
			s.throw_kind = "smoke" if mode == 2 else "frag"
			s.frags = trial % 3
			s.smokes = trial % 3
			s.drone_ctrl = d if trial % 5 else null
			s.goal_kind = "task"
			s.move_mode = trial % 3
			s.hold_pos = Vector3(-25, 0, 0)
			s.path = PackedVector3Array([Vector3(8, 0, 0)]) if trial % 4 >= 2 else PackedVector3Array()
			s._path_pending = trial % 11 == 0
			s.goal = Vector3(8, 0, 0)
			s._stuck_t = 3.1 if trial % 13 == 0 else 0.0
			s._gy_t = -1.0
			s.at_cover = true
			assert(doors.load_state(1.5, []))
			if mode == 0 and trial % 8 == 2:
				st.door_shut = true
				s.door_st = st
				s.door_wait = 0.05
				s.door_kick = trial % 16 == 2
				w.add_door(st)
				assert(doors.insert_door(20, st.position))
			var blocks := []
			var kinds := PackedByteArray()
			for e: Entity in w.entities.values():
				if e is Soldier: kinds.append(0); blocks.append(soldier_bytes(e))
				elif e is Vehicle: kinds.append(2); blocks.append(vehicle_bytes(e, vehicle))
				elif e is Structure:
					kinds.append(1); assert(structure.load_state(StructureState.capture(e))); blocks.append(structure.checkpoint())
				else: kinds.append(4); blocks.append(drone_bytes(e, actors))
			assert(actors.load_state(100, kinds, blocks))
			for i in 2: assert(cores[i].load_state(SquadState.capture(qs[i])))
			assert(units.load_state(12.0, []) and units.rebuild_units(actors) and structures.load_state(16.0, []))
			w._rebuild_uhash()
			for step in 8:
				w.time = 10.0 + step * 0.1
				w.spoken.clear(); w.stats.clear(); w.effects.clear(); w.nav.jobs.clear(); w.nav.cancelled.clear()
				var result := [[]]
				if s.task in TASKS:
					s.call("_" + s.task + "_tick", 0.1)
					result = actors.advance_infantry_travel(1, PackedFloat64Array([0.1, w.time, s.wdef.ammo, v.seats(), int(v.is_heli()), int(v.is_boat())]), PackedFloat64Array(), cores, w.water.deck, w.terrain._native, w.nav._planner, units, structures, doors, w.combat._collision, random._backend)
				assert(result.size() == 1, "travel %d/%d/%d" % [mode, trial, step])
				for other in w.soldiers:
					assert(infantry.restore(actors.actor_state(other.eid)))
					helper.check_state(other, infantry, "travel %d/%d/%d/%d" % [mode, trial, step, other.eid]); checks += 1
				for i in 2: assert(cores[i].values() == SquadState.capture(qs[i]), "travel squad")
				assert(vehicle.restore(actors.actor_state(10)))
				compare_vehicle(v, vehicle, "travel vehicle")
				assert(structure.restore(actors.actor_state(20)) and structure.values() == StructureState.capture(st), "travel structure")
				var speech := []
				var stats := {}
				var jobs := []
				var cancelled := []
				var effects := []
				for event: Array in result[0]:
					match int(event[0]):
						0: jobs.append([1, event[3], false, 0, event[4]])
						1: cancelled.append(1)
						2:
							effects.append([Fx.SOUND, "door_kick" if event[2] else "door", st.position + Vector3.UP]); assert(doors.remove(event[1]))
						4: speech.append([1, ["Breaching!", "Door!", "Kicking it in!"][event[1]]])
						5: speech.append([1, "Smoke out!" if event[1] == 1 else "Frag out!"])
						6: speech.append([1, "Got ammo."])
						7: stats[event[1]] = stats.get(event[1], 0) + 1
				assert(w.rng.state == random.state, "travel random")
				assert(w.spoken == speech and w.stats == stats and w.effects == effects, "travel events %d/%d/%d: %s / %s / %s / %s" % [mode, trial, step, w.spoken, speech, w.stats, stats])
				assert(w.nav.cancelled == cancelled and w.nav.jobs.size() == jobs.size(), "travel routes")
				for i in jobs.size(): assert(w.nav.jobs[i].slice(0, 5) == jobs[i])
				for key: String in stats: seen[key] = true
				if s.life == Soldier.Life.HIDDEN: seen["hidden"] = true
				if step == 3:
					assert(actors.restore(actors.checkpoint()))
					for core in cores: assert(core.restore(core.checkpoint()))
			w.free()
	helper.free()
	for key in ["smoke", "tunnel_in", "door_opened", "door_kicked", "repath", "hidden"]: assert(seen.has(key), "must exercise " + key)
	print("INFANTRY_TRAVEL_OWNED passed states=", checks)
	get_tree().quit()
