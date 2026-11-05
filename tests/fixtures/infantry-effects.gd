extends "res://tests/fixtures/actors.gd"

func _ready() -> void:
	MapDims.N = 32
	MapDims.SIZE = 32.0
	MapDims.HALF = 16.0
	Nav.N = 32
	Nav.H = 16.0
	HNav.C = 16
	HNav.NC = 2
	HNav.NCC = 4
	HNav._corner = HNav._corners()
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var random := SimulationRandom.new()
	var seen := {}
	checks = 0
	for mode in 3:
		for trial in 128:
			var w := ActorWorld.new()
			w.has_view = false
			w.srv = true
			w.settings = {"rust_infantry": false}
			w.nav = Nav.new()
			w.nav.finalize()
			w.combat = Combat.new(w)
			w.battle = BattleStats.new(w)
			add_child(w)
			w.rng.seed = 23171 + trial
			random.seed = 23171 + trial
			var qs := []
			var cores: Array[SquadStateCore] = []
			for team in 2:
				var q := Squad.new()
				q.world = w
				q.sid = 9 + team
				q.team = team
				q.morale = 75.0
				qs.append(q)
				w.squads[q.sid] = q
				cores.append(ClassDB.instantiate("SquadStateCore"))
			var st := Mount.new()
			st.world = w
			st.eid = 7
			st.skind = "watchtower" if trial % 3 == 0 else "hmg_nest"
			st.built = true
			w.add_child(st)
			w.entities[7] = st
			for id in range(1, 7):
				var s := make_soldier(w, id, (0 if id < 4 else 1) if id != 6 else -1)
				s.position = Vector3((id - 3) * 1.1, 0, (trial % 4) * 0.7)
				s.utype = "bearer" if id == 1 and trial % 11 == 0 else "rifleman"
				s.udef = Defs.UNITS[s.utype]
				s.wdef = Defs.WEAPONS.get(s.udef.weapon, {})
				s.life = trial % 6 if id == 1 else Soldier.Life.ALIVE
				s.bleed = 23.7
				s.times_downed = trial % 4
				s.downed_t = 1.0 if trial % 3 == 0 else 0.0
				s.say_cd = 4.0 if trial % 2 == 0 else 0.0
				s.suppression = trial % 80
				s.at_cover = trial % 2 == 0
				s.cover_type = trial % 4
				s.cover_mat = trial % 5 - 1
				s.peek_up = trial % 3 == 0
				s._gy = -1.05 if trial % 5 == 0 else 0.0
				s.mounted = st if trial % 3 != 0 else null
				s.mag = 17
				s.reserve = 103
				if id != 6:
					s.squad = qs[s.team]
					s.sid = s.squad.sid
					s.squad.members.append(s)
				w.soldiers.append(s)
			var s: Soldier = w.entities[1]
			s.task = ["breach", "rescue", "stretcher", "retreat"][trial % 4]
			s.task_ent = w.entities[2]
			s.path = PackedVector3Array([Vector3(10, 0, 0)])
			w.entities[2].dragged_by = s
			w.entities[2].rescue_claimed = s
			w.entities[2].carried_by = [s, w.entities[3]]
			qs[0].breach_by = s
			qs[0].leader = s
			qs[0].members = [s, w.entities[3], w.entities[2]]
			var blocks := []
			var types := PackedByteArray()
			for e: Entity in w.entities.values():
				if e is Soldier:
					blocks.append(soldier_bytes(e))
					types.append(0)
				else:
					assert(structure.load_state(StructureState.capture(e)))
					blocks.append(structure.checkpoint())
					types.append(1)
			assert(actors.load_state(100, types, blocks))
			for i in 2: assert(cores[i].load_state(SquadState.capture(qs[i])))
			assert(units.load_state(12.0, []) and units.rebuild_units(actors))
			w._rebuild_uhash()
			for step in 8:
				w.time = 10.0 + step * 0.71
				w.spoken.clear()
				w.stats.clear()
				var spoken := []
				if mode == 0:
					var id := 1 + step % 3
					var victim: Soldier = w.entities[id]
					var source: Entity = w.entities.get([4, 2, 6, 0][trial % 4])
					var blame := [-2, 1, "", 0] if trial % 3 == 0 else []
					w.battle._blame = blame
					var amount: float = [1.1, 21.37, 105.9, 48.3][(trial + step) % 4]
					var kind := "explosion" if trial % 3 == 0 else "bullet"
					var previous := victim.life
					var before_damage: float = w.battle.sides[1].dmg
					victim.take_damage(amount, source, Vector3(0.71, 0, -0.31), kind)
					var result: Array = actors.damage_infantry(id, InfantryState.entity_id(source), Vector3(0.71, 0, -0.31), kind,
						PackedFloat64Array([amount, w.time, victim.wdef.get("ammo", -1), int(victim.is_bearer())]), blame, cores, random._backend)
					assert(result.size() == 8 and result[1] == previous)
					if result[2] >= 0: spoken.append([id, ["I'm hit!", "Argh!", "Took one!", "Hit! I'm hit!"][result[2]]])
					if result[3] != 0: spoken.append([result[3], ["Man down!", "%s is hit!" % victim.sname, "We've got wounded!", "Medic! %s is down!" % victim.sname][result[4]]])
					if not result[6].is_empty():
						assert(victim.hit_by == result[6])
						if result[6][1] == 1: assert(is_equal_approx(w.battle.sides[1].dmg - before_damage, result[7]))
					seen["damage_%d" % result[0]] = true
					assert(w.stats == ({"downed": 1} if result[0] == 2 else ({"killed": 1} if result[0] == 3 else {})))
				elif mode == 1:
					var victim: Soldier = w.entities[1 + step % 6]
					victim.add_suppression(17.3 + trial, Vector3(9, 1, -3))
					var qcore: RefCounted = cores[victim.team] if victim.squad else null
					var result: Array = actors.suppress_infantry(victim.eid, 17.3 + trial, Vector3(9, 1, -3), w.time, qcore, random._backend)
					assert(result.size() == 1)
					if result[0] >= 0: spoken.append([victim.eid, ["I'm pinned!", "Can't move!", "Heads down!", "They've got us pinned!"][result[0]]])
				else:
					var from := Vector3(-11.3, 1.1, 0.17)
					var to := Vector3(10.7, 0.83, -0.31)
					var target: Soldier = w.entities[1] if step % 3 == 0 else null
					w.combat._suppress(from, to, 1, 17.3 + trial * 0.13, target)
					var result: Array = actors.suppress_bullet(from, to, 1, 17.3 + trial * 0.13, InfantryState.entity_id(target), w.time, units, cores, random._backend)
					assert(result.size() == 1)
					var lines: PackedInt64Array = result[0]
					for i in range(0, lines.size(), 2): spoken.append([lines[i], ["I'm pinned!", "Can't move!", "Heads down!", "They've got us pinned!"][lines[i + 1]]])
				assert(w.spoken == spoken, "Speech %d/%d/%d: %s / %s" % [mode, trial, step, w.spoken, spoken])
				assert(random.state == w.rng.state, "Random %d/%d/%d" % [mode, trial, step])
				for member in w.soldiers:
					compare_actor(member, actors, "effects %d/%d/%d/%d" % [mode, trial, step, member.eid])
					checks += 1
				for i in 2: assert(cores[i].values() == SquadState.capture(qs[i]), "Squad %d/%d/%d/%d" % [mode, trial, step, i])
				if step == 3:
					assert(actors.restore(actors.checkpoint()))
					for core in cores: assert(core.restore(core.checkpoint()))
			w.free()
	for result in 4: assert(seen.has("damage_%d" % result))
	print("INFANTRY_EFFECTS passed states=%d outcomes=%s" % [checks, seen])
	get_tree().quit()
