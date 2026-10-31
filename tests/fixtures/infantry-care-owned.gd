extends "res://tests/fixtures/infantry-special.gd"

class CareRules extends Rules:
	var medicine := false
	var rejoined := []
	func has_upgrade(_team: int, key: String) -> bool:
		return key == "medicine" and medicine
	func rejoin_squad(s: Soldier) -> void:
		rejoined.append(s.eid)

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
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var structures: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var doors: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/infantry-update.gd").new()
	var seen := {}
	checks = 0
	for duty: String in ["rescue", "heal", "limp"]:
		for trial in 128:
			var w: World = ground_world()
			var nav := SpecialRoutes.new()
			nav._planner = w.nav._planner
			w.nav = nav
			w.settings = {"rust_infantry": false, "gdscript_cover_search": true}
			w.water = WaterMap.new(w)
			w.fires = Fires.new(w)
			w.combat = ScanCombat.new(w)
			w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
			w.combat._visibility = ClassDB.instantiate("VisibilityCore")
			w.rules = CareRules.new(w)
			w.rules.medicine = trial % 2 == 0
			w.rng.seed = 82391 + trial
			random.seed = 82391 + trial
			var q := Squad.new()
			q.world = w
			q.sid = 9
			q.order_pos = Vector3(0, 0, 10)
			w.squads[q.sid] = q
			var qcore: SquadStateCore = ClassDB.instantiate("SquadStateCore")
			var cores: Array[SquadStateCore] = [qcore]
			for id in [1, 2, 3]:
				var s := make_soldier(w, id, 0)
				s.position = Vector3.ZERO
				s.squad = q
				s.sid = q.sid
				q.members.append(s)
				w.soldiers.append(s)
			var s: Soldier = w.entities[1]
			var p: Soldier = w.entities[2]
			var other: Soldier = w.entities[3]
			s.task = duty
			s.task_ent = p if trial % 23 else null
			s.task_phase = trial % (2 if duty == "heal" else 3)
			s.task_t = [0.0, 0.1, 0.35, 1.0][trial % 4]
			s.utype = "medic" if trial % 2 else "rifleman"
			s.udef = Defs.UNITS[s.utype]
			s.rotation.y = [0.0, 1.3, -2.5][trial % 3]
			s.stamina = [0.1, 0.3, 0.349, 0.8][trial % 4]
			s.suppression = [0.0, 6.0, 71.0][trial % 3]
			s.say_cd = 5.0
			s.goal_kind = "task"
			s.move_mode = trial % 3
			s.path = PackedVector3Array([Vector3(8, 0, 0)]) if trial % 4 >= 2 else PackedVector3Array()
			s._path_pending = trial % 11 == 0
			s.goal = Vector3(8, 0, 0)
			s._gy_t = -1.0
			s.at_cover = true
			s.backwards = true
			p.position = Vector3([0.0, 1.19, 1.2, 1.39, 1.4, 2.0, 10.0][trial % 7], -0.3 if trial % 2 else 0.0, 0)
			p.life = Soldier.Life.DOWNED if duty == "rescue" else Soldier.Life.ALIVE
			if trial % 17 == 0: p.life = Soldier.Life.DEAD
			p.hp = [0.0, 10.0, 99.0, 100.0][trial % 4]
			p.times_downed = trial % 5
			p.wdef = {} if trial % 3 == 0 else Defs.WEAPONS.rifle
			p.dragged_by = other if trial % 13 == 0 else (s if trial % 2 else null)
			p.rescue_claimed = s
			p.carried_by = [other] if trial % 19 == 0 else []
			other.position = Vector3(0, 0, 10)
			other.cover_pos = other.position
			other.at_cover = true
			var tm: TerrainMap = w.terrain
			for z in range(35, 51):
				for x in range(25, 46):
					var i := z * TerrainMap.N + x
					if (x + z + trial) % 9 < 3:
						tm.cov[i] = 2
						tm.crater[i] = int(trial % 3 == 0)
						tm.rubble[i] = int(trial % 3 == 1)
						tm.woods[i] = int(trial % 3 == 2)
			assert(tm._native.configure(TerrainMap.N, [tm.base, tm.crater, tm.rubble, tm.woods, tm.cov, tm.cdir, tm.solid, tm.trench, tm.netted], tm.dh))
			if trial % 5 == 0:
				for i in w.fires.hot.size(): w.fires.hot[i] = int(i % 7 == 0)
			var blocks := []
			for e in w.soldiers: blocks.append(soldier_bytes(e))
			assert(actors.load_state(100, PackedByteArray([0, 0, 0]), blocks))
			assert(qcore.load_state(SquadState.capture(q)))
			assert(units.load_state(12.0, []) and units.rebuild_units(actors) and structures.load_state(16.0, []) and doors.load_state(1.5, []))
			w._rebuild_uhash()
			for step in 8:
				w.time = 10.0 + step * 0.1
				w.spoken.clear(); w.stats.clear(); w.effects.clear(); w.props.clear(); w.nav.jobs.clear(); w.nav.cancelled.clear(); w.rules.rejoined.clear()
				var result := [[], -1, 0, -1, false]
				if s.task == duty:
					s.call("_" + duty + "_tick", 0.1)
					result = actors.advance_infantry_care(1, PackedFloat64Array([0.1, w.time, s.udef.get("heal", 1.0), int(w.rules.medicine), s.wdef.get("range", 50.0), 0, Defs.WEAPONS.rifle.mag]), "rifle", PackedFloat64Array(), cores, w.fires.hot, w.water.deck, tm._native, w.nav._planner, units, structures, doors, w.combat._collision, random._backend)
				assert(result.size() == 5, "care %s/%d/%d" % [duty, trial, step])
				for person in w.soldiers:
					assert(infantry.restore(actors.actor_state(person.eid)))
					helper.check_state(person, infantry, "care %s/%d/%d/%d" % [duty, trial, step, person.eid]); checks += 1
				assert(qcore.values() == SquadState.capture(q), "care squad")
				var speech := []
				var stats := {}
				var jobs := []
				var cancelled := []
				var props := []
				for event: Array in result[0]:
					match int(event[0]):
						0: jobs.append([1, event[3], false, 0, event[4]])
						1: cancelled.append(1)
						7: stats[event[1]] = stats.get(event[1], 0) + 1
						_: assert(false, "unexpected medical movement event")
				if result[1] >= 0: speech.append([1, ["I've got you!", "Hang on, I've got you!", "Grab on!", "Moving him!"][result[1]]])
				if result[2] != 0:
					speech.append([result[2], ["Thanks, doc.", "I'm good, I'm good!", "Back in the fight.", "Ugh... let's go."][result[3]]])
					stats.revived = 1; stats.patched_up = 1
					props.append([result[2], {"max_hp": p.max_hp}])
				assert(w.rng.state == random.state, "care random")
				assert(w.spoken == speech and w.stats == stats and w.props == props and w.effects.is_empty(), "care events %s/%d/%d" % [duty, trial, step])
				assert(w.rules.rejoined == ([1] if result[4] else []), "limp return")
				assert(w.nav.cancelled == cancelled and w.nav.jobs.size() == jobs.size(), "care routes")
				for i in jobs.size(): assert(w.nav.jobs[i].slice(0, 5) == jobs[i])
				for key: String in stats: seen[key] = true
				if result[4]: seen.rejoined = true
				if duty == "heal" and p.hp == p.max_hp: seen.healed = true
				if step == 3:
					assert(actors.restore(actors.checkpoint()) and qcore.restore(qcore.checkpoint()))
			w.free()
	helper.free()
	for key in ["drag", "revived", "patched_up", "rejoined", "healed"]: assert(seen.has(key), "must exercise " + key)
	print("INFANTRY_CARE_OWNED passed states=", checks)
	get_tree().quit()
