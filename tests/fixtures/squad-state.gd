extends "res://tests/fixtures/actors.gd"

func compare_squad(q: Squad, core: RefCounted, plans: Dictionary, label: String) -> void:
	var expected := SquadState.capture(q, plans)
	var actual: Array = core.values()
	for group in expected.size():
		assert(expected[group] == actual[group], "%s group %d: %s / %s" % [label, group, expected[group], actual[group]])

func _ready() -> void:
	var w := ActorWorld.new()
	w.srv = true
	w.has_view = false
	w.settings = {"rust_infantry": false}
	add_child(w)
	var core: RefCounted = ClassDB.instantiate("SquadStateCore")
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var rng := SimulationRandom.new()
	var layout := RandomNumberGenerator.new()
	layout.seed = 9381
	var st := Mount.new()
	st.eid = 90
	st.skind = "house"
	st.world = w
	w.add_child(st)
	var plan := RefCounted.new()
	var ambush := RefCounted.new()
	var plans := {plan: 31, ambush: 37}
	checks = 0
	for trial in 128:
		for operation in 8:
			var q := Squad.new()
			q.world = w
			q.sid = 17
			q.team = trial % 2
			q.kind = "rifle"
			q.owner = -2 + trial % 5
			var soldiers: Array[Soldier] = []
			var blocks := []
			var kinds := PackedByteArray()
			var bearers := PackedInt64Array()
			for id in range(1, 11):
				var s := make_soldier(w, id, q.team if id <= 6 else 1 - q.team)
				s.position = Vector3(layout.randf_range(-36, 36), layout.randf_range(-1, 1), layout.randf_range(-36, 36))
				s.life = (trial + id) % 6
				s.task = ["", "retreat", "rescue"][id % 3]
				s.say_cd = 1.0
				if id <= 6:
					q.add(s)
				if id == 2:
					s.udef = s.udef.duplicate()
					s.udef.bearer = true
					bearers.append(id)
				if id == 3 and trial % 11 == 0:
					s.gone = true
				if id == 1:
					s.life = Soldier.Life.DOWNED if trial % 2 else Soldier.Life.DEAD
					s.times_downed = trial % 3
					s.downed_t = 17.0 if trial % 4 else 0.0
				soldiers.append(s)
				if not s.gone:
					blocks.append(soldier_bytes(s))
					kinds.append(0)
			w.time = 100.0 + trial * 0.3
			w.rng.seed = trial + 137
			rng.seed = trial + 137
			w.spoken.clear()
			q.leader = soldiers[trial % 6] if trial % 4 else null
			q.order = ["hold", "move", "defend", "assault"][trial % 4]
			q.order_pos = Vector3(3.1, 0.7, -9.3)
			q.order_n = 137 + trial
			q.shown_order = "contact"
			q.facing = Vector3(0.7, 0, -0.3)
			q.cover_fire_until = 117.2
			q.cover_fire_pos = Vector3(-7.1, 0, 4.9)
			q.think_t = 0.25
			q.smoked = {1: 77.3, 3: 85.9}
			q.build_target = st
			q.tunnel_exit_pos = Vector3(10, 0, 11) if trial % 3 else Vector3.INF
			q.fire_queue = [[Vector3(10, 0, 2), "he"], [Vector3(-7, 0, 3), "smoke"]]
			q.bound_team = trial % 2
			q.bound_t = 86.7
			q.contact_t = 93.1
			q.alert_t = w.time - [59.9, 60.0, 60.1][trial % 3]
			q.travel = trial % 2 == 0
			q.travel_mode = trial % 3
			q.final_slots = {1: Vector3(3, 0, 1), 4: Vector3(1, 0, 3)}
			q.plan = plan if trial % 3 == 0 else null
			q.ambush_plan = ambush if trial % 5 == 0 else null
			q.breach_by = soldiers[2]
			q.morale = 78.0 - trial * 0.3
			q.drill = ["", "contact", "displace", "withdraw", "rout"][trial % 5]
			q.drill_t = 91.7
			q.drill_pos = Vector3(-9, 0, 7)
			q.halt_dest = Vector3(2, 0, -13)
			q.halt_face = Vector3.LEFT
			q.halt_mode = (trial + 1) % 3
			q.move_mode_ord = (trial + 2) % 3
			q.impacts = [[Vector3.ONE, 87.3], [Vector3.LEFT, 99.4]]
			q.last_cas_t = 73.6
			q.displace_cd = 111.3
			q.pre_order = ["defend", Vector3(1, 0, -3), Vector3.RIGHT, 2] if trial % 2 else []
			q.ammo_t = 0.1
			q.bt_cd = {"clear": 113.4, "crew": 113.8, "crew_n": q.order_n, "refund": 50}
			q.ambush = trial % 2 == 0
			q.ambush_t = 73.3
			q._offsets = {1: Vector2(2.3, 4.7), 3: Vector2(-2.3, 4.7)}
			q.technique = "bound" if trial % 2 else ""
			q.ow_team = (trial + 1) % 2
			q.ow_t = 83.9
			q.ow_rbf_t = 102.9
			q.then_defend = [Vector3.ONE, Vector3.RIGHT] if trial % 3 else []
			q.halt_then = [Vector3.LEFT, Vector3.FORWARD] if trial % 4 else []
			q.cleared = {90: 93.7, 89: 84.9}
			q.bt_clear = [st, [st, Vector3.ONE, Vector3.RIGHT, true], soldiers[1], soldiers[2]] if trial % 2 else []
			q.clear_call = [soldiers[4], 103.7] if trial % 5 else []
			for id in range(7, 11):
				var s := soldiers[id - 1]
				q.known[id] = {"e": s, "pos": s.position, "t": w.time - (id - 6) * 4.0}
			q.known_at_order = q.known.duplicate(true)
			q.heard = [[Vector3(1, 0, 3), w.time - 5.3], [Vector3(3, 0, 1), w.time - 8.0]]
			q._combat_cache_t = w.time if trial % 3 else -1.0
			q._combat_cache = trial % 2 == 0
			q._centroid_t = w.time if trial % 4 else -1.0
			q._centroid = Vector3(3.7, 0.2, -5.3)
			q._briefing_t = w.time - [0.1, 0.25, 0.3][trial % 3]
			q._briefing = [Vector3(8, 1.5, -7)] if trial % 3 else []
			q._buildings_t = 99.7
			q._building_contacts = [[soldiers[7], st]]
			assert(core.load_state(SquadState.capture(q, plans)))
			assert(actors.load_state(99, kinds, blocks))
			compare_squad(q, core, plans, "initial")
			match operation:
				0:
					q.report(soldiers[8])
					assert(core.report(9, soldiers[8].position, w.time))
					q.report(soldiers[4])
					assert(core.report(5, soldiers[4].position, w.time))
				1:
					for n in 12:
						var pos := Vector3(n * 0.7, 0, -n * 1.3)
						q.report_pos(pos)
						assert(core.report_position(pos, w.time))
						w.time += 0.3
				2:
					assert(q.centroid() == core.centroid(w.time, actors)[0])
					soldiers[5].gone = true
					assert(actors.remove(6))
					assert(q.centroid() == core.centroid(w.time, actors)[0])
					w.time += 0.3
					assert(q.centroid() == core.centroid(w.time, actors)[0])
				3:
					var leader := q.get_leader()
					var result: PackedInt64Array = core.get_leader(actors, bearers, rng._backend)
					assert(result[0] == InfantryState.entity_id(leader))
					assert((result[1] < 0) == w.spoken.is_empty())
				4:
					q.on_member_down(soldiers[0])
					var result: PackedInt64Array = core.casualty(1, w.time, actors, rng._backend)
					assert((result[0] == 0) == w.spoken.is_empty())
					if result[0] != 0:
						assert(result[0] == w.spoken[0][0])
				5:
					for n in 12:
						assert(q.in_combat() == (core.in_combat(w.time) == 1))
						assert(q.tactical() == (core.tactical(w.time) == 1))
						w.time += 1.3
				6, 7:
					for n in 6:
						var origin := Vector3(n * 7.3 - 14.7, 0.3, n * 3.9)
						var expected: Array = q.sector_threats(origin) if operation == 7 else q.threat_points(origin, n)
						var result: Array = core.threat_points(origin, n, w.time, operation == 7, actors)
						assert(result.size() == 1 and PackedVector3Array(expected) == result[0], "threats %d/%d/%d" % [trial, operation, n])
						w.time += 0.07
			compare_squad(q, core, plans, "case %d/%d" % [trial, operation])
			assert(w.rng.state == rng.state)
			for s in soldiers:
				if not s.gone:
					compare_actor(s, actors, "squad actor %d/%d/%d" % [trial, operation, s.eid])
			var saved: PackedByteArray = core.checkpoint()
			assert(core.restore(saved))
			assert(core.checkpoint() == saved)
			var bad := saved.duplicate()
			bad[4] = 2
			assert(not core.restore(bad))
			assert(core.checkpoint() == saved)
			checks += 1
			for s in soldiers:
				s.free()
	print("SQUAD_STATE passed cases=%d" % checks)
	get_tree().quit()
