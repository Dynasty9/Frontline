extends "res://tests/fixtures/infantry-hidden-owned.gd"

func _ready() -> void:
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var infantry: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/infantry-update.gd").new()
	var seen := {}
	checks = 0
	for team_id in 2:
		for mode in 3:
			for trial in 32:
				var w := HiddenWorld.new()
				w.has_view = false
				w.srv = true
				w.settings = {"rust_infantry": false}
				add_child(w)
				w.rng.seed = 7931 + trial
				random.seed = 7931 + trial
				var q := Squad.new()
				q.world = w
				q.sid = 9
				q.team = team_id
				q._combat_cache_t = 3.0
				if mode == 2 and trial % 6 == 0: q.heard = [[Vector3(9, 0, 9), 19.0]]
				w.squads[q.sid] = q
				var qcore: SquadStateCore = ClassDB.instantiate("SquadStateCore")
				var cores: Array[SquadStateCore] = [qcore]
				for id in [1, 3, 2]:
					var s := make_soldier(w, id, team_id)
					w.soldiers.append(s)
					s.squad = q
					s.sid = q.sid
					q.members.append(s)
					s.rotation.y = [0.0, 1.3, -2.5][(trial + id) % 3]
					s.last_shot_t = -99.0
					s.calm_t = [4.9, 5.0, 11.9, 12.0][(trial + id) % 4]
					s.idle_until = 100.0
					s.idle_next = 21.0 if trial % 7 == 0 else 0.0
					s.say_cd = 3.0 if trial % 3 == 0 else 0.0
					if mode == 1:
						s.idle_act = Soldier.Act.IDLE_CHAT
						s._banter = [[19.0, "First"], [20.0, "!laugh"], [20.0, "Last"], [22.8, "Later"]]
					if mode == 2:
						s.idle_act = Soldier.Act.IDLE_SIT
						match trial % 6:
							1: s.suppression = 5.1
							2: s._sector = Vector3.FORWARD
							3: s.reload_t = 0.1
							4: s.last_shot_t = 8.0
							5: s._path_pending = true
				if mode == 1:
					w.entities[1].chat_with = w.entities[3]
					w.entities[3].chat_with = w.entities[1] if trial % 5 != 0 else w.entities[2]
					w.entities[2].chat_with = w.entities[1]
					if trial % 7 == 0: w.entities[3].life = Soldier.Life.DEAD
				var blocks := []
				for s in w.soldiers: blocks.append(soldier_bytes(s))
				assert(actors.load_state(100, PackedByteArray([0, 0, 0]), blocks))
				assert(qcore.load_state(SquadState.capture(q)) and units.load_state(12.0, []) and units.rebuild_units(actors))
				w._rebuild_uhash()
				var last_chat := PackedFloat64Array(w.last_chat)
				for step in 8:
					w.time = 20.0 + step * 2.8
					w.spoken.clear(); w.stats.clear()
					var s: Soldier = w.soldiers[step % 3]
					var moving: bool = mode == 2 and trial % 6 == 5
					s._idle_tick(0.1, moving)
					var result: Array = actors.advance_infantry_idle(s.eid, 0.1, w.time, moving, cores, last_chat, units, random._backend)
					assert(result.size() == 2)
					last_chat = result[1]
					for other in w.soldiers:
						assert(infantry.restore(actors.actor_state(other.eid)))
						helper.check_state(other, infantry, "idle %d/%d/%d/%d/%d" % [team_id, mode, trial, step, other.eid]); checks += 1
					assert(qcore.values() == SquadState.capture(q), "idle squad cache")
					assert(last_chat == PackedFloat64Array(w.last_chat), "team conversation deadline")
					var speech := []
					var stats := {}
					for event: Array in result[0]:
						if event[0] == 0: stats.banter = 1
						else: speech.append([s.eid, event[1]]); seen.speech = true
					assert(w.spoken == speech and w.stats == stats, "idle events")
					assert(w.rng.state == random.state, "idle random")
					for key in stats: seen[key] = true
					if s.act == Soldier.Act.IDLE_LAUGH: seen.laugh = true
					if step == 3: assert(actors.restore(actors.checkpoint()) and qcore.restore(qcore.checkpoint()))
				w.free()
	helper.free()
	for key in ["banter", "speech", "laugh"]: assert(seen.has(key), "must exercise " + key)
	print("INFANTRY_IDLE_OWNED passed states=", checks)
	get_tree().quit()
