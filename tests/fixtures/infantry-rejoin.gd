extends "res://tests/fixtures/infantry-hidden-owned.gd"

func _ready() -> void:
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var infantry: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var helper := preload("res://tests/fixtures/infantry-update.gd").new()
	var records := preload("res://tests/fixtures/battle-stats.gd").new()
	var original_players: Dictionary = Net.players.duplicate(true)
	var seen := {}
	checks = 0
	for team_id in 2:
		for trial in 64:
			Net.players = [{7: {"team": team_id}, 9: {"team": 1 - team_id}, 6: {"team": team_id}}, {9: {"team": 1 - team_id}, 6: {"team": team_id}}, {}][trial % 3]
			var peers := PackedInt32Array()
			for peer in Net.players: peers.append(peer); peers.append(Net.players[peer].team)
			var w := HiddenWorld.new()
			w.has_view = false
			w.srv = true
			w.settings = {"rust_infantry": false}
			w.nav = SpecialRoutes.new()
			w.rules = Rules.new(w)
			w.battle = BattleStats.new(w)
			w.next_sid = 100
			add_child(w)
			var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore")
			for id in range(1, 9):
				var s := make_soldier(w, id, team_id)
				w.soldiers.append(s)
			var returning: Soldier = w.entities[1]
			returning.position = Vector3.ZERO
			returning.owner_peer = [0, 7, 8, -1 - team_id][trial % 4]
			returning.at_cover = true
			returning.next_cover_eval = 20.0
			var cores: Array[SquadStateCore] = []
			for i in 4:
				var q := Squad.new()
				q.world = w
				q.sid = [12, 11, 13, 14][i]
				q.team = 1 - team_id if i == 2 else team_id
				q.owner = [returning.owner_peer, 6, -1 - team_id, 8][i]
				q.kind = "rifle_squad"
				q.order_pos = Vector3([3.0, 3.01, 39.99, 40.0, 89.99, 90.0, 95.0][trial % 7] * (-1 if i == 1 else 1), 0, 0)
				w.squads[q.sid] = q
				if i == 0 and trial % 3 == 0:
					for id in range(2, 8):
						var s: Soldier = w.entities[id]
						s.position = q.order_pos
						s.sid = q.sid
						s.squad = q
						q.members.append(s)
				if i == 1:
					var s: Soldier = w.entities[8]
					s.position = q.order_pos
					s.sid = q.sid
					s.squad = q
					s.life = Soldier.Life.HIDDEN if trial % 5 == 0 else Soldier.Life.ALIVE
					q.members.append(s)
				w.battle.squad_formed(q)
				assert(ledger.register_unit("s%d" % q.sid, q.callsign(), q.display_name(), q.team, q.owner, w.time, 0))
				var core: SquadStateCore = ClassDB.instantiate("SquadStateCore")
				assert(core.load_state(SquadState.capture(q)))
				cores.append(core)
			var blocks := []
			for s in w.soldiers: blocks.append(soldier_bytes(s))
			assert(actors.load_state(100, PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]), blocks))
			var next_id := 100
			var random_state: int = w.rng.state
			for step in 2:
				w.time = 10.0 + step * 0.1
				w.props.clear(); w.nav.jobs.clear()
				w.rules.rejoin_squad(returning)
				var result: Array = actors.rejoin_infantry(1, w.time, peers, cores, next_id, ledger, Defs.SQUADS["rifle_squad" if team_id == 0 else "fighter_cell"].name)
				assert(result.size() == 6)
				next_id = result[2]
				if result[1]:
					var added: SquadStateCore = ClassDB.instantiate("SquadStateCore")
					assert(added.restore(result[4]))
					cores.append(added)
					seen.new = true
				assert(next_id == w.next_sid and result[0] == returning.sid)
				for s in w.soldiers:
					assert(infantry.restore(actors.actor_state(s.eid)))
					helper.check_state(s, infantry, "rejoin %d/%d/%d/%d" % [team_id, trial, step, s.eid]); checks += 1
				var qs: Array = w.squads.values()
				assert(qs.size() == cores.size())
				for i in qs.size(): assert(cores[i].values() == SquadState.capture(qs[i]), "rejoined squad")
				records.compare_ledger(w.battle, ledger, "rejoined battle record")
				var props := []
				if result[3] != null: props.append([1, {"owner": result[3]}]); seen.owner = true
				assert(w.props == props)
				var jobs := []
				for route: Array in result[5]: jobs.append([1, route[3], false, team_id, route[4]])
				assert(w.nav.jobs.size() == jobs.size())
				for i in jobs.size(): assert(w.nav.jobs[i].slice(0, 5) == jobs[i])
				if not jobs.is_empty(): seen.route = true
				assert(w.rng.state == random_state)
				assert(actors.restore(actors.checkpoint()) and ledger.restore(ledger.checkpoint()))
				for core in cores: assert(core.restore(core.checkpoint()))
			w.free()
	Net.players = original_players
	helper.free()
	records.free()
	for key in ["new", "owner", "route"]: assert(seen.has(key), "must exercise " + key)
	print("INFANTRY_REJOIN passed states=", checks)
	get_tree().quit()
