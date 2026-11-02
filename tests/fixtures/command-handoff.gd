extends "res://tests/fixtures/structure-production.gd"

func _ready() -> void:
	var movement := preload("res://tests/fixtures/squad-movement.gd").new()
	var battle := preload("res://tests/fixtures/battle-stats.gd").new()
	var saved: Dictionary = Net.players.duplicate(true); var count := 0
	for trial in 32:
		var team := trial % 2
		Net.players = {7:{"team":team,"name":"First"},9:{"team":1-team,"name":"Enemy"},11:{"team":-1,"name":"Watcher"}}
		if trial % 3 == 0: Net.players[8] = {"team":team,"name":"Ally"}; Net.players[10] = {"team":team,"name":"Last ally"}
		var w := ProductionWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
		w.rules = Rules.new(w); w.rules.upgrades = [{},{}]; w.battle = BattleStats.new(w); add_child(w)
		w.settings.ai_teams = [team] if trial % 4 == 0 else []
		var core: RefCounted = ClassDB.instantiate("CommandOwnershipCore")
		var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
		var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore")
		var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
		var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
		var qs: Array[SquadStateCore] = []
		for sid in range(1,6):
			var side := 1-team if sid == 5 else team
			var peer := 9 if sid == 5 else -1-team if sid == 4 else 7
			var q := Squad.new(); q.world = w; q.sid = sid; q.team = side; q.owner = peer; q.kind = "rifle_squad"; w.squads[sid] = q
			for index in 2:
				var s := Trooper.new(); s.world = w; s.srv = true; s.eid = sid*2+index; s.team = side; s.owner_peer = peer
				s.utype = "rifleman"; s.udef = Defs.UNITS.rifleman; s.wdef = Defs.WEAPONS[s.udef.weapon]; s.sname = "Soldier %d" % s.eid
				s.life = (trial + sid + index) % 6; w.add_child(s); w._register(s); q.add(s)
			var state: SquadStateCore = ClassDB.instantiate("SquadStateCore"); assert(state.load_state(SquadState.capture(q,{}))); qs.append(state)
		for id in range(20,24):
			var v := Truck.new(); v.world = w; v.srv = true; v.eid = id; v.team = team; v.owner_peer = 7 if id < 22 else -1-team
			v.vkind = "tank" if id % 2 == 0 else "truck"; v.vdef = Defs.VEHICLES[v.vkind].duplicate(); v.vdef.auto = id % 2 == 1
			w.add_child(v); w._register(v)
		var st := Wall.new(); st.world = w; st.srv = true; st.eid = 30; st.team = 1-team; st.skind = "barracks"
		st.queue = [{"item":"rifle_squad","t":3.0,"total":10.0,"owner":7,"cost":50}]; w.add_child(st); w._register(st)
		movement.import_actors(w,actors); assert(core.load_state(rules_state(w)))
		w.battle.joined(7,team); w.battle.add(7,team,"spent",150.0)
		assert(ledger.joined(7,team,"First")); assert(ledger.add(7,team,14,150.0))
		for step in 7:
			var result: Array; var request := []; var selected_s := PackedInt64Array(); var selected_v := PackedInt64Array()
			if step <= 1:
				var peer: int = [7,-1-team][step]
				for who in [peer,9,11,0,999]:
					var chosen: Array = core.select(actors,qs,who,PackedInt64Array([4,1,5,4,999,2]),PackedInt64Array([21,20,23,22,20]),PackedStringArray(["truck"]))
					var sqs: Array = w._command_squads(who,[4,1,5,4,999,2]); var vs: Array = w._command_vehicles(who,[21,20,23,22,20])
					assert(chosen == [PackedInt64Array(sqs.map(func(q): return q.sid)),PackedInt64Array(vs.map(func(v): return v.eid))],"selection")
					if who == peer: selected_s = chosen[0]; selected_v = chosen[1]
				request = [0,peer,0,"",false,selected_s,selected_v]
				w.take_command(peer,w._command_squads(peer,Array(selected_s)),w._command_vehicles(peer,Array(selected_v)))
			elif step in [2,4,6]:
				var peer := 7 if step == 2 else 17 if step == 4 else 11
				var side: int = Net.players[peer].team; var pname: String = Net.players[peer].name
				request = [1,peer,0,"",false,selected_s,selected_v]
				Net.players.erase(peer); w._on_player_left(peer,side,pname)
			else:
				var peer := 17 if step == 3 else 27; var old := 7 if step == 3 else 17
				Net.players[peer] = {"team":team,"name":"Returned %d" % peer}; assert(core.join_peer(peer,team))
				var stand := false
				for c: CommanderAI in w.commanders:
					if c.team == team and not team in w.settings.ai_teams: stand = true
				request = [2,peer,old,String(Net.players[peer].name),stand,selected_s,selected_v]
				w._on_player_rejoined(peer,old,team,Net.players[peer].name)
			result = core.advance(actors,qs,ledger,request,PackedStringArray(["truck"]))
			var label := "%d/%d" % [trial,step]; assert(result.size() == 3,"result "+label)
			assert(core.values() == rules_state(w),"ownership "+label)
			for i in qs.size(): assert(qs[i].restore(result[1][i])); movement.compare_squad(w.squads[i+1],qs[i],{},label)
			for e: Entity in w.entities.values():
				if e is Soldier: assert(actors.actor_state(e.eid) == movement.soldier_bytes(e),"soldier "+label)
				elif e is Vehicle: assert(vehicle.restore(actors.actor_state(e.eid))); assert(vehicle.values() == VehicleState.capture(e),"vehicle "+label)
				else: assert(structure.restore(actors.actor_state(e.eid))); assert(structure.values() == StructureState.capture(e),"structure "+label)
			battle.compare_ledger(w.battle,ledger,label)
			assert(core.restore(core.checkpoint())); assert(actors.restore(actors.checkpoint())); assert(ledger.restore(ledger.checkpoint())); count += 1
		w.free()
	Net.players = saved; movement.free(); battle.free(); print("COMMAND_HANDOFF passed states=",count); get_tree().quit()
