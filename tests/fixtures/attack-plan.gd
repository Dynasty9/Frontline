extends "res://tests/fixtures/squad-movement.gd"

class AttackWorld extends Scene:
	var messages := []
	func send_msg(team_id: int, kind: String, text: String, ping = null) -> void:
		messages.append([team_id,kind,text,ping])

func point_bytes(b: StreamPeerBuffer, p: Vector3) -> void:
	b.put_float(p.x); b.put_float(p.y); b.put_float(p.z)

func plan_bytes(p: AttackPlan) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_data("FLAP01".to_utf8_buffer()); b.put_u16(2)
	b.put_u32(17); b.put_u8(p.team & 255); point_bytes(b,p.objective); point_bytes(b,p.axis); b.put_double(p.side)
	for elements: Array in [p.support,p.assault]:
		b.put_u32(elements.size())
		for e: Dictionary in elements: b.put_u32(e.sq.sid); b.put_u8(int(e.team) & 255)
	point_bytes(b,p.sbf); point_bytes(b,p.ap); b.put_u8(["plan","move","assault","fix","fallback"].find(p.phase))
	b.put_double(p.phase_t); point_bytes(b,p.fire_at); b.put_u8(int(p.support_set)); b.put_u8(int(p.shifted)); b.put_u8(p._rush_group)
	b.put_double(p._rush_t); b.put_u32(p._start_n); b.put_double(p._pinned_t); b.put_double(p._clear_t)
	b.put_u32(p._said.size())
	for key: String in p._said:
		var data := key.to_utf8_buffer(); b.put_u32(data.size()); b.put_data(data)
	b.put_u8(int(p.done)); b.put_double(p._tick_t); b.put_u8(int(p._smoked))
	return b.data_array

func _ready() -> void:
	MapDims.N = 128; MapDims.SIZE = 128.0; MapDims.HALF = 64.0; MapDims.BIOME = 128; Defs.MAP_HALF = 64.0
	Nav.N = 128; Nav.H = 64.0; HNav.C = 16; HNav.NC = 8; HNav.NCC = 64; HNav._corner = HNav._corners()
	TerrainMap.N = 128; TerrainMap.H = 64.0; TerrainMap.DN = 256
	var helper := preload("res://tests/fixtures/world-geometry.gd").new()
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var visibility: RefCounted = ClassDB.instantiate("VisibilityCore")
	var movement: RefCounted = ClassDB.instantiate("SquadMovementCore")
	var rng := SimulationRandom.new(); var seen := {}; checks = 0
	for trial in 64:
		var w := AttackWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false,"debug":true}; add_child(w)
		w.time = 100.0; w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.combat = Combat.new(w); w.combat.enable_native_collision()
		var qs: Array[Squad] = []; var cores: Array[SquadStateCore] = []; var plans := {}
		for k in 2:
			var q := Squad.new(); q.world = w; q.sid = 7 + k; q.team = trial % 2; q.owner = trial % 3 - 1; q.kind = "rifle_squad"; q.order_n = trial
			qs.append(q); cores.append(ClassDB.instantiate("SquadStateCore"))
		for id in range(1,23):
			var s := make_soldier(w,id,qs[0].team if id <= 12 else 1 - qs[0].team); w.soldiers.append(s)
			s.position = Vector3(-30.3 + id * 0.71,0,id * 1.37 - 3.7) if id <= 12 else Vector3(30.7,0,-4.3 + (id - 13) * 0.7)
			s.utype = "mg_gunner" if id % 4 == 0 else "medic" if id == 6 else "rifleman"; s.udef = Defs.UNITS[s.utype]; s.wdef = Defs.WEAPONS[s.udef.weapon]
			s.say_cd = 1.7 if trial % 3 == 0 else 0.0; s.smokes = 1; s.frags = 2
			if id <= 12: qs[0 if id <= 6 else 1].add(s)
		for q: Squad in qs:
			q.leader = q.members[0]; q.leader.flags |= Soldier.F_LEADER
			if trial % 6 == 0: q.members.reverse()
			if trial % 5 == 1:
				for id in range(13,23): q.known[id] = {"e":w.entities[id],"pos":w.entities[id].position,"t":99.0}
			elif trial % 4 == 0: q.known[13] = {"e":w.entities[13],"pos":w.entities[13].position,"t":99.0}
		if trial % 7 == 0: w.entities[1].life = Soldier.Life.DOWNED
		if trial % 5 == 0:
			w.entities[3].task = "rescue"; w.entities[3].task_ent = w.entities[7]; w.entities[7].dragged_by = w.entities[3]; w.entities[7].rescue_claimed = w.entities[3]
			w.entities[5].task = "breach"; w.entities[5].task_phase = 2
		var transport: Vehicle = null
		if trial % 4 == 3:
			transport = Truck.new(); transport.world = w; transport.srv = true; transport.eid = 110; transport.team = qs[0].team
			transport.vkind = "truck"; transport.vdef = Defs.VEHICLES.truck.duplicate(); transport.position = Vector3(-28.7,0,2.3); transport.rotation.y = trial * 0.17
			if trial % 8 == 7: transport.vdef.base = "boat"
			transport.assault = true; transport.assault_dest = Vector3(30.7,0,-4.3); w.add_child(transport); w._register(transport)
			for s: Soldier in qs[0].members:
				if s.life == Soldier.Life.ALIVE: s.life = Soldier.Life.HIDDEN; s.riding = transport; transport.passengers.append(s)
		for index in 2:
			var st := Structure.new(); st.world = w; st.srv = true; st.eid = 100 + index; st.team = -1
			st.skind = "hesco"; st.size = Vector3(10,2,1); st.position = Vector3(6.7 + index * 10.13,0,-4.1)
			st.yaw = trial % 4 * 0.317; st.rotation.y = st.yaw
			w._register(st); w.add_child(st); st.on_spawned(); w._shash_add(st); w.terrain.structure_changed(st)
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		assert(geometry.restore(helper.world_save(w))); assert(units.restore(helper.spatial_save(w._uhash,12.0)))
		w.rng.seed = 3917 + trial; rng.seed = w.rng.seed
		var p: AttackPlan = null; var q := qs[0]; var objective := Vector3(30.7,0,-4.3); var case_id := trial % 8
		for step in 40:
			w.time = 100.0 + step * 3.7
			if p != null and not p.done:
				if step == 4 and case_id in [2,3,4,6]: p.phase = "assault"; p.phase_t = w.time; p._rush_t = 0.0
				if case_id == 2 and step >= 4:
					for squad: Squad in qs:
						for s: Soldier in squad.members: s.suppression = 80.0
				if case_id == 3 and step == 5: p.phase = "fallback"; p.phase_t = w.time - 21.0
				if case_id in [0,4,6] and step >= 4:
					for e: Dictionary in p.assault:
						for s: Soldier in e.sq.members:
							if e.team >= 0 and s.fteam != e.team: continue
							s.position = objective - Vector3([30.0,22.0,15.0,5.0][mini(step - 4,3)],0,0)
				if case_id == 7 and step == 6:
					for squad: Squad in qs: squad.plan = null
				if case_id == 5:
					for squad: Squad in qs:
						for contact: Dictionary in squad.known.values(): contact.t = w.time
				if step % 3 == 0:
					for s: Soldier in w.soldiers:
						if not s._path_pending: s.path.clear(); s.goal_kind = ""
			w._rebuild_uhash(); assert(units.restore(helper.spatial_save(w._uhash,12.0)))
			var profiles := import_actors(w,actors)
			for i in qs.size(): assert(cores[i].load_state(SquadState.capture(qs[i],plans)))
			w.spoken.clear(); w.stats.clear(); w.messages.clear()
			var op := 8; var target := 7; var args := []
			if step == 0:
				if transport != null:
					op = 11; target = transport.eid; args = [transport.is_boat(),17,visibility]; transport.dismount(); p = q.plan
				elif trial % 4 == 1:
					op = 10; target = 17; args = [objective,Vector3.ZERO,visibility,PackedInt64Array([7,8])]
					p = AttackPlan.make(w,qs,objective,Vector3.ZERO)
				else:
					op = 7; args = [objective,Vector3.ZERO,visibility,17]; q.order_assault(objective,Vector3.ZERO); p = q.plan
				assert(p != null); plans[p] = 17
			else:
				args = [plan_bytes(p)]
				if step == 3 and trial % 4 == 2: op = 9; target = 8; p.join(qs[1])
				else: p.tick()
			var result: Array = movement.apply(actors,geometry,units,cores,rng._backend,profiles,w.time,w.town_rect,target,op,args)
			assert(result.size() == 2,"attack result %d/%d" % [trial,step])
			var said := []; var stats := {}; var messages := []
			for e: Array in result[0]:
				match int(e[0]):
					0: said.append([e[1],speech(w.entities[e[1]].squad,e[2],e[3])])
					2: stats[e[1]] = stats.get(e[1],0) + 1; seen[e[1]] = true
					5: said.append([e[1],e[2]])
					6: messages.append([e[1],"alert","%s: outnumbered at %s, gone firm. Need fires or reinforcements!" % [Squad.callsign_of(e[1],e[2]),Defs.grid_ref(e[3])],e[3]])
			assert(said == w.spoken,"attack speech %d/%d: %s / %s" % [trial,step,said,w.spoken])
			assert(stats == w.stats,"attack stats %d/%d: %s / %s" % [trial,step,stats,w.stats])
			assert(messages == w.messages,"attack messages %d/%d" % [trial,step])
			var expected := plan_bytes(p)
			if expected != result[1]:
				var first := -1
				for i in mini(expected.size(),result[1].size()):
					if expected[i] != result[1][i]: first = i; break
				assert(false,"attack plan %d/%d byte %d %s" % [trial,step,first,p.info()])
			for i in qs.size(): compare_squad(qs[i],cores[i],plans,"attack squad %d/%d/%d" % [trial,step,i])
			for s: Soldier in w.soldiers: compare_actor(s,actors,"attack actor %d/%d/%d" % [trial,step,s.eid])
			if transport != null:
				var vehicle_core: RefCounted = ClassDB.instantiate("VehicleStateCore")
				assert(vehicle_core.restore(actors.actor_state(transport.eid)))
				assert(VehicleState.capture(transport) == vehicle_core.values(),"attack transport %d/%d" % [trial,step])
			assert(w.rng.state == rng.state,"attack random %d/%d" % [trial,step])
			assert(geometry.inspect()[1] == helper.nav_save(w.nav),"attack queue %d/%d" % [trial,step])
			w.nav.process_paths(3); assert(geometry.process_paths(actors,3,w.time,rng._backend))
			for s: Soldier in w.soldiers: compare_actor(s,actors,"attack routed %d/%d/%d" % [trial,step,s.eid])
			assert(w.rng.state == rng.state); assert(geometry.inspect()[1] == helper.nav_save(w.nav))
			if p._smoked: seen.smoke = true
			for s: Soldier in w.soldiers:
				if s.task == "throw" and s.throw_kind == "frag": seen.frag = true
			if step % 7 == 6:
				assert(actors.restore(actors.checkpoint())); assert(geometry.restore(geometry.checkpoint()))
				for core: SquadStateCore in cores: assert(core.restore(core.checkpoint()))
			checks += 1
		for squad: Squad in qs: squad.plan = null
		plans.clear(); p = null; w.free()
	for key in ["plan_move","plan_assault","plan_fix","plan_fallback","plan_won","plan_failed","plan_reinforced","smoke","frag"]: assert(seen.has(key),"attack coverage " + key)
	helper.free(); print("ATTACK_PLAN passed states=",checks," coverage=",seen); get_tree().quit()
