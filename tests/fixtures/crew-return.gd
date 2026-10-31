extends "res://tests/fixtures/squad-movement.gd"

class CrewWorld extends Scene:
	var messages := []
	func send_msg(team_id: int, kind: String, text: String, ping = null) -> void:
		messages.append([team_id,kind,text,ping])

func _ready() -> void:
	MapDims.N = 128; MapDims.SIZE = 128.0; MapDims.HALF = 64.0; MapDims.BIOME = 128; Defs.MAP_HALF = 64.0
	Nav.N = 128; Nav.H = 64.0; HNav.C = 16; HNav.NC = 8; HNav.NCC = 64; HNav._corner = HNav._corners()
	TerrainMap.N = 128; TerrainMap.H = 64.0; TerrainMap.DN = 256
	var helper := preload("res://tests/fixtures/world-geometry.gd").new()
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var movement: RefCounted = ClassDB.instantiate("SquadMovementCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var rng := SimulationRandom.new(); var seen := {}; checks = 0
	for trial in 64:
		var w := CrewWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}; add_child(w)
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.combat = Combat.new(w); w.combat.enable_native_collision(); w.rules = Rules.new(w); w.time = 100.0
		var q := Squad.new(); q.world = w; q.sid = 7; q.team = trial % 2; q.owner = trial % 3 - 1
		q.kind = "rifle_squad" if trial % 11 == 0 else "crew" if q.team == 0 else "r_crew"; q.order_n = 47 + trial
		q.bt_cd = {"crew":103.0 if trial % 3 == 0 else 99.0,"crew_n":q.order_n + (1 if trial % 4 == 0 else 0),"refund":50.9}
		q.drill = "contact" if trial % 8 == 0 else ""
		var core: SquadStateCore = ClassDB.instantiate("SquadStateCore"); var qs: Array[SquadStateCore] = [core]
		for id in range(1,8):
			var s := make_soldier(w,id,q.team if id <= 6 else 1 - q.team); w.soldiers.append(s)
			s.position = Vector3(-30.3 + id * 0.71,0,id * 1.37 - 3.7)
			if id == 1: s.life = Soldier.Life.DOWNED
			if id == 3 and trial % 3 == 0: s.life = Soldier.Life.CAPTIVE
			if id <= 6: q.add(s)
		q.leader = w.entities[1]
		if trial % 5 == 0: q.known = {7:{"e":w.entities[7],"pos":w.entities[7].position,"t":99.0}}
		for index in 3:
			var st := Structure.new(); st.world = w; st.srv = true; st.eid = 100 + index; st.skind = "fob"; st.sname = ["A","B","Enemy"][index]
			st.team = q.team if index < 2 else 1 - q.team; st.built = index != 1 or trial % 2 == 0; st.wrecked = index == 1 and trial % 3 == 0
			st.position = [Vector3(30,0,15),Vector3(-20,0,5),Vector3(-27,0,2)][index]; st.supply = 10.25 + index
			w._register(st); w.add_child(st); st.on_spawned(); w._shash_add(st); w.terrain.structure_changed(st)
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		assert(geometry.restore(helper.world_save(w))); assert(units.restore(helper.spatial_save(w._uhash,12.0)))
		w.rng.seed = 3117 + trial; rng.seed = w.rng.seed
		for step in 16:
			w.time = 100.0 + step * 0.73
			if step == 8:
				for s: Soldier in q.members:
					if s.life == Soldier.Life.ALIVE: s.position = Vector3(30,0,15) + Vector3(s.eid * 0.3,0,1.3)
				# The downed man still contributes to the squad's centroid.
				for s: Soldier in q.members:
					if s.life == Soldier.Life.DOWNED: s.position = Vector3(30,0,15)
			var profiles := import_actors(w,actors); assert(core.load_state(SquadState.capture(q)))
			var members := q.members.duplicate(); w.spoken.clear(); w.stats.clear(); w.messages.clear()
			Tactics.crew_tick(q)
			var result: Array = movement.apply(actors,geometry,units,qs,rng._backend,profiles,w.time,w.town_rect,7,3,[])
			assert(result.size() == 1,"crew result %d/%d" % [trial,step])
			var said := []; var stats := {}; var messages := []; var removed := []
			for e: Array in result[0]:
				match int(e[0]):
					0: said.append([e[1],speech(q,e[2],e[3])])
					2: stats[e[1]] = stats.get(e[1],0) + 1; seen[e[1]] = true
					3:
						var f: Structure = w.entities[e[2]]
						messages.append([q.team,"info","%s is back at %s - they'll crew the next one." % [q.display_name(),f.display_name()],f.position])
					4: removed.append(int(e[1]))
			var gone := []
			for s: Soldier in members:
				if s.gone: gone.append(s.eid); assert(actors.actor_state(s.eid).is_empty())
			assert(removed == gone); assert(said == w.spoken); assert(stats == w.stats); assert(messages == w.messages)
			compare_squad(q,core,{},"crew %d/%d" % [trial,step])
			for s: Soldier in w.soldiers: compare_actor(s,actors,"crew actor %d/%d/%d" % [trial,step,s.eid])
			for st: Structure in w.structures:
				assert(structure.restore(actors.actor_state(st.eid))); assert(structure.values() == StructureState.capture(st),"crew supply %d/%d" % [trial,step])
			assert(w.rng.state == rng.state); assert(geometry.inspect()[1] == helper.nav_save(w.nav))
			w.nav.process_paths(3); assert(geometry.process_paths(actors,3,w.time,rng._backend))
			for s: Soldier in w.soldiers: compare_actor(s,actors,"crew routed %d/%d/%d" % [trial,step,s.eid])
			assert(w.rng.state == rng.state); assert(geometry.inspect()[1] == helper.nav_save(w.nav))
			if q.travel: seen.travel = true
			if step % 5 == 4:
				assert(actors.restore(actors.checkpoint())); assert(core.restore(core.checkpoint())); assert(geometry.restore(geometry.checkpoint()))
			checks += 1
		w.free()
	assert(seen.has("travel") and seen.has("crew_home"))
	helper.free(); print("CREW_RETURN passed states=",checks," coverage=",seen); get_tree().quit()
