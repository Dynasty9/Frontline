extends "res://tests/fixtures/infantry-special.gd"

class NoIgnition extends Fires:
	func blast(_p: Vector3, _size: float, _radius: float) -> void: pass

func check_blast_actor(s: Soldier, actors: RefCounted, label: String) -> void:
	var state: RefCounted = ClassDB.instantiate("InfantryStateCore")
	assert(state.restore(actors.actor_state(s.eid)))
	var expected := InfantryState.capture(s)
	var actual: Array = state.values()
	# The pinned power function can differ from Godot's libm by an ulp.
	var vitals: PackedFloat64Array = expected[1][0]
	for i in [2, 8]:
		assert(absf(vitals[i] - float(actual[1][0][i])) < 0.000000001, label + " blast health")
		vitals[i] = actual[1][0][i]
	expected[1][0] = vitals
	for group in expected.size():
		assert(expected[group] == actual[group], "%s group %d: %s / %s" % [label, group, expected[group], actual[group]])

func _ready() -> void:
	MapDims.N = 32
	MapDims.SIZE = 32.0
	MapDims.HALF = 16.0
	MapDims.BIOME = 32
	Nav.N = 32
	Nav.H = 16.0
	HNav.C = 16
	HNav.NC = 2
	HNav.NCC = 4
	HNav._corner = HNav._corners()
	TerrainMap.N = 32
	TerrainMap.H = 16.0
	TerrainMap.DN = 64
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var random := SimulationRandom.new()
	var seen := {}
	checks = 0
	for mode in 4:
		for trial in 64:
			var w: World = ground_world()
			w.settings = {"rust_infantry": false}
			w.combat = ScanCombat.new(w)
			w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
			w.battle = BattleStats.new(w)
			w.fires = NoIgnition.new(w)
			w.rng.seed = 42713 + trial
			random.seed = 42713 + trial
			var qs := []
			var cores: Array[SquadStateCore] = []
			for team in 2:
				var q := Squad.new()
				q.world = w
				q.sid = 9 + team
				q.team = team
				q.morale = 77.0
				w.squads[q.sid] = q
				qs.append(q)
				cores.append(ClassDB.instantiate("SquadStateCore"))
			for id in range(1, 9):
				var s := make_soldier(w, id, 0 if id < 5 else 1)
				s.position = Vector3([-0.5, 0.0, 0.4, 1.7, 3.1, 6.2, 10.1, 13.1][id - 1], 0, -0.2 if id % 2 else 0.2)
				s.squad = qs[s.team]
				s.sid = s.squad.sid
				s.squad.members.append(s)
				s.posture = (trial + id) % 5
				s.life = (trial / 3) % 6 if id in [2, 4, 7] else Soldier.Life.ALIVE
				s.times_downed = trial % 4
				s.bleed = 30.0
				s.downed_t = 1.0
				s.say_cd = 4.0 if trial % 2 else 0.0
				s.utype = "bearer" if id == 1 and trial % 11 == 0 else "rifleman"
				s.udef = Defs.UNITS[s.utype]
				s.wdef = Defs.WEAPONS.get(s.udef.weapon, {})
				s.mag = 17
				s.reserve = 103
				s.path = PackedVector3Array([Vector3(12, 0, 5)])
				s.task = "breach" if id == 1 else ""
				w.soldiers.append(s)
			qs[0].leader = w.entities[1]
			qs[0].breach_by = w.entities[1]
			if mode == 3:
				var carrier: Soldier = w.entities[1]
				var patient: Soldier = w.entities[4]
				carrier.task = "rescue" if trial % 2 else "stretcher"
				carrier.task_ent = patient
				patient.carried_by = [carrier] if carrier.task == "stretcher" else []
				patient.dragged_by = carrier if carrier.task == "rescue" else null
				patient.rescue_claimed = carrier
				qs[0].breach_by = null
				w.entities[3].dazed_t = 1.0 if trial % 3 == 0 else 0.0
				w.entities[5].act_t = 1.0
				w.entities[5].act_kind = "melee"
				w.entities[5].act_data = {"tgt": w.entities[1]}
			if mode == 1:
				var st := Mount.new()
				st.world = w
				st.eid = 20
				st.skind = ["medic_tent", "house_wall", "concrete_wall", "fob"][trial % 4]
				st.indestructible = true
				st.position = Vector3(1, 0, 0)
				w.add_child(st)
				w.entities[20] = st
				collider(w.combat._collision, 20 if trial % 5 else 99, Vector3(0.8, 1, 0), Vector3(0.1, 2, 2))
			if mode == 2:
				for i in 1024:
					w.terrain.trench[i] = int(i % 32 >= 16 and trial % 2 == 0)
					w.terrain.crater[i] = int(i % 32 < 16 and trial % 3 == 0)
				assert(w.terrain._native.replace_ground([w.terrain.base, w.terrain.crater, w.terrain.rubble, w.terrain.woods, w.terrain.cov,
					w.terrain.cdir, w.terrain.solid, w.terrain.trench, w.terrain.netted], w.terrain.dh))
			w._rebuild_uhash()
			var cells := []
			for key: Vector2i in w._uhash:
				cells.append([key, InfantryState.entity_ids(w._uhash[key])])
			assert(units.load_state(12.0, cells))
			if trial % 4 == 0:
				w.entities[6].position = Vector3(13.3, 0, 0)
				w.entities[8].position = Vector3(0.7, 0, 0)
			var blocks := []
			var kinds := PackedByteArray()
			var stocks := PackedInt64Array()
			for e: Entity in w.entities.values():
				if e is Soldier:
					kinds.append(0)
					blocks.append(soldier_bytes(e))
					stocks.append_array(PackedInt64Array([e.eid, e.wdef.get("ammo", -1), int(e.is_bearer())]))
				else:
					kinds.append(1)
					assert(structure.load_state(StructureState.capture(e)))
					blocks.append(structure.checkpoint())
			assert(actors.load_state(100, kinds, blocks))
			for i in 2: assert(cores[i].load_state(SquadState.capture(qs[i])))
			for step in 6:
				w.time = 10.0 + step * 0.71
				w.spoken.clear()
				w.stats.clear()
				var source: Entity = w.entities[8] if trial % 3 else null
				var blame := [-2, 1, "s10", 8] if trial % 3 == 0 else []
				w.battle._blame = blame
				var p := Vector3(0, 0.25 if trial % 5 else 0.0, 0.0)
				var damage: float = [0.0, 24.3, 67.8, 181.7][(trial + step) % 4]
				var radius: float = [0.0, 0.3, 2.3, 5.0, 7.7][trial % 5]
				var fling := 0.0 if trial % 3 == 0 else 8.7
				w.combat._explode(p, {"dmg": damage, "radius": radius, "fling": fling, "src": source, "size": 0.0})
				var result: Array = actors.blast_infantry(p, PackedFloat64Array([damage, radius, fling, w.time]), InfantryState.entity_id(source),
					blame, stocks, w.terrain._native, units, w.combat._collision, cores, random._backend)
				assert(result.size() == 1, "Rejected infantry blast")
				var spoken := []
				var stats := {}
				for event: Array in result[0]:
					var id: int = event[0]
					var hit: Array = event[1]
					if not hit.is_empty():
						seen["damage_%d" % hit[0]] = true
						if hit[2] >= 0: spoken.append([id, ["I'm hit!", "Argh!", "Took one!", "Hit! I'm hit!"][hit[2]]])
						if hit[3] != 0: spoken.append([hit[3], ["Man down!", "%s is hit!" % w.entities[id].sname, "We've got wounded!", "Medic! %s is down!" % w.entities[id].sname][hit[4]]])
						if hit[0] in [2, 3]:
							var key := "downed" if hit[0] == 2 else "killed"
							stats[key] = stats.get(key, 0) + 1
					if event[2]: stats.flung = stats.get("flung", 0) + 1
				for key in stats: seen[key] = true
				assert(w.stats == stats, "Blast stats %d/%d/%d: %s / %s" % [mode, trial, step, w.stats, stats])
				assert(w.spoken == spoken, "Blast speech %d/%d/%d" % [mode, trial, step])
				assert(w.rng.state == random.state, "Blast RNG %d/%d/%d" % [mode, trial, step])
				for s: Soldier in w.soldiers:
					check_blast_actor(s, actors, "blast %d/%d/%d/%d" % [mode, trial, step, s.eid])
					checks += 1
				for i in 2: assert(cores[i].values() == SquadState.capture(qs[i]), "Blast squad %d/%d/%d/%d" % [mode, trial, step, i])
				if step == 2:
					assert(actors.restore(actors.checkpoint()) and units.restore(units.checkpoint()))
					for core in cores: assert(core.restore(core.checkpoint()))
			w.free()
	for key in ["damage_0", "damage_1", "damage_2", "damage_3", "flung", "downed", "killed"]: assert(seen.has(key), "Unexercised blast outcome " + key)
	print("INFANTRY_BLAST passed states=%d outcomes=%s" % [checks, seen])
	get_tree().quit()
