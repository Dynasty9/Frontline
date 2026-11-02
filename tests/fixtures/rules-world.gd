extends "res://tests/fixtures/structure-production.gd"

class RulesWorld extends ProductionWorld:
	var effects := []
	func fx_event(e: Array) -> void: effects.append(e)
	func declare_winner(t: int) -> void: winner = t

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64; Defs.MAP_HALF = 32.0; MapDims.CELL = 8.0
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var loss: RefCounted = ClassDB.instantiate("VehicleLossWorldCore")
	var birth := preload("res://tests/fixtures/vehicle-loss.gd").new(); var movement := preload("res://tests/fixtures/squad-movement.gd").new()
	var battle := preload("res://tests/fixtures/battle-stats.gd").new()
	var fog_helper := preload("res://tests/fixtures/fog.gd").new(); var support_helper := preload("res://tests/fixtures/support-calls.gd").new()
	var projectile_helper := preload("res://tests/fixtures/projectile-actor.gd").new()
	var weapons := []; var item_names := {}
	for kind: String in Defs.UNITS:
		var key := String(Defs.UNITS[kind].weapon); weapons.append([kind,key if Defs.WEAPONS.has(key) else "",int(Defs.WEAPONS.get(key,{}).get("mag",0))])
	for kind: String in Defs.SQUADS: item_names[kind] = String(Defs.SQUADS[kind].name)
	for kind: String in Defs.VEHICLES: item_names[kind] = String(Defs.VEHICLES[kind].name)
	var men := []; var buildings := []
	for kind: String in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[kind]; var weapon: Dictionary = Defs.WEAPONS.get(d.weapon,{})
		men.append([kind,bool(d.get("bearer",false)),int(weapon.get("ammo",-1)),BattleStats.MAN_VALUE,float(weapon.get("range",-1)),String(d.name)])
	for kind: String in Defs.BUILDINGS: buildings.append([kind,true,float(Defs.BUILDINGS[kind].get("cost",0))])
	var count := 0; var seen := {}; var original_players: Dictionary = Net.players.duplicate(true)
	for trial in 32:
		var w := RulesWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false,"scenario":"attack" if trial % 11 == 0 else ""}
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.combat = Combat.new(w); w.combat.enable_native_collision(); w.fires = Fires.new(w)
		w.rules = Rules.new(w); w.rules.upgrades = [{},{}]; w.battle = BattleStats.new(w); w._deferred_effects = DeferredEffects.new(false)
		w.time = 100.0; w.next_eid = 1000; w.next_sid = 7; add_child(w)
		if trial % 13 == 0: w.mission = MissionDirector.new(w,"bridgehead",null)
		Net.players = {7:{"team":0},8:{"team":1},9:{"team":0}} if trial % 3 else {}
		if trial % 2: w.rules.upgrades[0] = {"armor":true,"grenades":true}
		var depots := PackedInt64Array(); var towns := PackedInt64Array(); var bases := []
		for team in 2:
			var hq: Structure = w.spawn("structure",{"skind":"depot","team":team,"pos":Vector3(-24,0,20 if team == 0 else -20)})
			w.rules.depots[team] = hq; depots.append(hq.eid)
			for i in 3:
				var st: Structure = w.spawn("structure",{"skind":"fob","team":team,"pos":Vector3(i*12-8,0,20 if team == 0 else -20)})
				st.supply_parent = hq if i == 0 else bases.back(); st.wrecked = trial % 4 == i
				st.road = PackedVector3Array([st.supply_parent.position+Vector3(0,0,-3),st.position+Vector3(0,0,-3)]); st.truck_t = [0.0,0.4,4.0][(trial+i)%3]
				if (trial+i)%7 == 0: st.supply_parent = null
				if (trial+i)%9 == 0: st.built = false
				bases.append(st)
		for i in 6:
			var st: Structure = w.spawn("structure",{"skind":"town","team":i%2,"pos":Vector3(i*8-20,0,0)})
			st.zone_c = st.position; st.zone_r = 9.0
			st.variant = (trial+i)%4; st.supply_parent = bases[i]; st.truck_t = [0.0,0.4,4.0][(trial+i)%3]
			var k := clampi(st.variant,0,1); st.supply = [0.0,float(Defs.TOWN_LOAD[k])-0.1,float(Defs.TOWN_LOAD[k]),float(Defs.TOWN_STOCK[k])-0.9,float(Defs.TOWN_LOAD[k])*2+0.7][(trial+i)%5]
			st.road = PackedVector3Array([st.position+Vector3(0,0,4),st.supply_parent.position+Vector3(0,0,4)])
			if (trial+i)%7 == 0: st.road.clear()
			if (trial+i)%11 == 0: st.supply_parent = null
			if (trial+i)%13 == 0: st.team = -1
			w.rules.town_list.append(st); towns.append(st.eid)
		for team in 2:
			for i in range(4 + (trial+team)%3):
				var s := Trooper.new(); s.world = w; s.srv = true; s.eid = 1+team*10+i; s.team = team; s.owner_peer = 7+team
				s.utype = "bearer" if i == 0 else "rifleman"; s.position = Vector3(20,0,i*2-5); w._register(s); w.add_child(s); s.on_spawned(); s.sname = "Waiting %d" % s.eid
				if trial % 4 == 0 and i == 1: s.life = Soldier.Life.DOWNED
		var prisoner: Soldier = w.entities[2]; var guard: Soldier = w.entities[12]
		prisoner.life = [Soldier.Life.SURRENDER,Soldier.Life.SURRENDER,Soldier.Life.CAPTIVE,Soldier.Life.HIDDEN,Soldier.Life.HIDDEN][trial%5]
		prisoner.hidden_reason = "held" if trial%5 == 3 else "interrogation" if trial%5 == 4 else ""; prisoner.wdef = {}
		prisoner.intel_left = 3; prisoner.intel_t = [119.9,120.0,120.1][trial%3]
		if trial%5 in [1,2]: prisoner.position = Vector3(-20,0,0); guard.position = Vector3(-19,0,1)
		if trial%5 == 2: prisoner.captor = guard; guard.task = "captor"; guard.task_ent = prisoner
		w.rules._support_q = [[120.0,"arty",0,Vector3(3,0,2),22.0,Vector3(0,0,380),7],[120.0,"grad",1,Vector3(-3,0,2),20.0,Vector3(0,0,-300),8],[121.0,"mortar",0,Vector3(2,0,1),15.0,Vector3(0,0,130),7]]
		w.rules.marks = [[Vector4(20,-3,15,120.4)],[]]
		w.rules._t_vis = [0.0,0.2,0.4][trial%3]; w.rules._t_sec = [0.0,0.1,1.0][trial%3]
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
		var units: RefCounted = ClassDB.instantiate("SpatialIndexCore"); var structure_state: RefCounted = ClassDB.instantiate("StructureStateCore")
		var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore"); var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore"); var deferred: RefCounted = ClassDB.instantiate("DeferredEffectsCore")
		var visibility: RefCounted = ClassDB.instantiate("VisibilityCore"); var fires: RefCounted = ClassDB.instantiate("FiresCore"); var random := SimulationRandom.new()
		var network: RefCounted = ClassDB.instantiate("SupplyNetworkCore"); assert(network.load_state(depots,towns,w.rules.fob_order,w.roads,w._painted_roads))
		var rules: RefCounted = ClassDB.instantiate("RulesWorldCore"); var fog: RefCounted = ClassDB.instantiate("FogCore")
		var support: RefCounted = ClassDB.instantiate("SupportCallsCore"); var intelligence: RefCounted = ClassDB.instantiate("PrisonerIntelligenceCore"); var projectile: RefCounted = ClassDB.instantiate("ProjectileActorCore")
		assert(fog.load_state(fog_helper.fog_values(w))); assert(support.load_state(support_helper.support_state(w)))
		assert(rules.load_state([network.checkpoint(),rules_state(w)[0],fog.checkpoint(),support.checkpoint(),intelligence.checkpoint(),PackedFloat64Array([w.rules._t_vis,w.rules._t_sec,w.rules._reserve_t[0],w.rules._reserve_t[1]]),w.rules._income,PackedInt64Array(w.rules.fob_names_used)]))
		var types := PackedByteArray(); var blocks := []
		for e: Entity in w.entities.values():
			if e is Soldier: types.append(0); blocks.append(movement.soldier_bytes(e))
			else: assert(structure_state.load_state(StructureState.capture(e))); types.append(1); blocks.append(structure_state.checkpoint())
		assert(actors.load_state(w.next_eid,types,blocks)); assert(geometry.restore(world_save(w))); assert(units.restore(spatial_save(w._uhash,12.0)))
		assert(visibility.restore(w.combat._visibility.checkpoint())); assert(fires.configure(64,false))
		var qs: Array[SquadStateCore] = []
		w.rng.seed = 3917 + trial; random.seed = w.rng.seed
		for step in 5:
			var dt: float = [0.1,0.1,0.5,0.5,8.0][step]; w.time = [119.99,120.0,120.5,195.0,196.0][step]; var vehicles := []
			for v: Vehicle in w.vehicles: vehicles.append([v.eid,v.display_name(),v.base(),v.is_heli(),v.is_auto(),int(v.vdef.get("crew",-1)),float(v.vdef.get("cost",0)),w.rules.has_upgrade(v.team,"armor"),w.rules.has_upgrade(v.team,"grenades"),v.weight(),v._hull_size()])
			var config := [w.next_sid,w.time,w.town_rect,[PackedStringArray(Defs.NAMES[0]),PackedStringArray(Defs.NAMES[1])],[birth.loadout("crewman"),birth.loadout("r_crewman")],vehicles,men,buildings]
			var fog_profiles := []; var names := {}
			for v: Vehicle in w.vehicles: fog_profiles.append([v.eid,float(v.vdef.get("sight",50.0)),v.is_heli(),v.is_auto(),bool(v.vdef.get("cannon",false))])
			for st: Structure in w.structures: names[st.eid] = st.display_name()
			var input := [dt,w.settings.scenario != "",w.winner,w.mission != null,[product("rifle_squad",birth),product("fighter_cell",birth)],product("truck",birth),PackedInt64Array(Defs.TOWN_LOAD),PackedFloat64Array(Defs.TOWN_STOCK),PackedInt64Array(Defs.SUPPLY_PER_TRUCK),rules_state(w),fog_profiles,weapons,names,item_names,PackedInt64Array()]
			w.spoken.clear(); w.messages.clear(); w.stats.clear(); w.effects.clear()
			var result: Array = loss.advance_rules(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,input,rules)
			var label := "%d/%d" % [trial,step]; assert(result.size() == 4,"result " + label)
			w.rules.tick(dt); w.combat._sync_collision()
			var parts: Array = rules.values(); assert(fog.restore(parts[2])); assert(support.restore(parts[3])); assert(intelligence.restore(parts[4]))
			assert(fog.values() == fog_helper.fog_values(w),"fog "+label); assert(support.values() == support_helper.support_state(w),"salvos "+label)
			for s: Soldier in w.soldiers: assert(intelligence.given(s.eid) == PackedStringArray(s.get_meta("given",[])),"intel history "+label)
			assert(parts[5] == PackedFloat64Array([w.rules._t_vis,w.rules._t_sec,w.rules._reserve_t[0],w.rules._reserve_t[1]]),"clocks "+label)
			assert(w.winner == result[3][0],"winner "+label)
			assert(w.rng.state == random.state,"random " + label); assert(actors.next_id() == w.next_eid and result[0] == w.next_sid,"identities " + label)
			var ids := PackedInt64Array()
			for e: Entity in w.entities.values():
				ids.append(e.eid); ids.append(0 if e is Soldier else 2 if e is Vehicle else 3 if e is Projectile else 1)
				if e is Soldier: movement.compare_actor(e,actors,label + "/%d" % e.eid)
				elif e is Projectile: projectile_helper.snapshot(e,projectile); assert(actors.actor_state(e.eid) == projectile.checkpoint(),"projectile "+label)
				elif e is Vehicle: assert(vehicle.restore(actors.actor_state(e.eid))); assert(vehicle.values() == VehicleState.capture(e),"vehicle " + label)
				else: assert(structure_state.restore(actors.actor_state(e.eid))); assert(structure_state.values() == StructureState.capture(e),"building " + label)
			assert(actors.identities() == ids,"registry " + label)
			qs.clear()
			for bytes: PackedByteArray in result[1]:
				var q: SquadStateCore = ClassDB.instantiate("SquadStateCore"); assert(q.restore(bytes)); qs.append(q); movement.compare_squad(w.squads[q.values()[0][0]],q,{},label)
			var said := []; var messages := []; var stats := {}; var effects := []
			for key: String in result[2]: stats[key] = int(stats.get(key,0))+1
			for event: Array in result[3][1]:
				match int(event[0]):
					0:
						var e: Array = event[1]
						if e[0] == 5: effects.append([Fx.FAR_SOUND,e[1],-14.0,e[2]])
					2: seen.truck = true; seen.town = seen.get("town",false) or event[2] != 0
					3: messages.append([event[2],"info","Reserves have arrived at HQ.",event[3]]); seen.reserves = true
					4:
						var speech: Array = event[1]
						if speech[0] == 0:
							var s: Soldier = w.entities[speech[1]]; said.append([s.eid,movement.speech(s.squad,speech[2],speech[3])])
					5:
						said.append([event[1],"Thanks! Get me out of here!"]); messages.append([event[2],"info","%s has been freed!" % event[3],event[4]]); seen.freed = true
					6: messages.append([event[1],"intel",event[2],event[3]]); seen.intel = true
			assert(said == w.spoken,"speech " + label); assert(messages == w.messages,"messages %s native=%s godot=%s" % [label,str(messages),str(w.messages)]); assert(stats == w.stats,"stats %s native=%s godot=%s" % [label,str(stats),str(w.stats)]); assert(effects == w.effects,"effects "+label)
			battle.compare_ledger(w.battle,ledger,label); check_geometry(w,geometry,label)
			w.nav.process_paths(50); assert(geometry.process_paths(actors,50,w.time,random._backend))
			for s: Soldier in w.soldiers: movement.compare_actor(s,actors,label + " routed/%d" % s.eid)
			assert(w.rng.state == random.state); assert(geometry.inspect()[1] == nav_save(w.nav))
			for retained in [actors,geometry,units,ledger,deferred,visibility,fires,network,rules]: assert(retained.restore(retained.checkpoint()))
			count += 1
		w.free()
	Net.players = original_players
	assert(seen.get("truck",false) and seen.get("town",false) and seen.get("reserves",false) and seen.get("freed",false) and seen.get("intel",false),"coverage")
	birth.free(); movement.free(); battle.free(); fog_helper.free(); support_helper.free(); projectile_helper.free()
	print("RULES_WORLD passed states=",count); get_tree().quit()
