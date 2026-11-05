extends "res://tests/fixtures/fires-native.gd"

class ProductionWorld extends FireWorld:
	var spoken := []; var messages := []; var warnings := []
	func say(e: Entity, text: String) -> void: spoken.append([e.eid,text])
	func send_msg(team: int, kind: String, text: String, ping = null) -> void: messages.append([team,kind,text,ping])
	func send_msg_to(peer: int, kind: String, text: String) -> void: warnings.append([peer,kind,text])

func squad_profile(key: String, birth: Node) -> Array:
	var members := []
	for kind: String in Defs.SQUADS[key].members: members.append(birth.loadout(kind))
	return [key,String(Defs.SQUADS[key].name),members]

func product(key: String, birth: Node) -> Array:
	if Defs.SQUADS.has(key): return [0,squad_profile(key,birth)]
	if Defs.UPGRADES.has(key): return [2,key,String(Defs.UPGRADES[key].name)]
	var d: Dictionary = Defs.VEHICLES[key]; var base := String(d.get("base","tank")); var carry := String(d.get("carry",""))
	return [1,key,base,float(d.hp),d.get("size",Vector3(2.3,2.6,6.0)),int(d.get("atgm",[0,0.0])[0]),int(d.get("sam",[0,0.0])[0]),String(d.name),int(d.cap),bool(d.get("air",false)),bool(d.get("supply",false)),bool(d.get("auto",false)),squad_profile(carry,birth) if Defs.SQUADS.has(carry) else [],bool(d.get("tracked",false))]

func rules_state(w: World) -> Array:
	var peers := PackedInt64Array(); var away := []
	for peer: int in Net.players: peers.append(peer); peers.append(int(Net.players[peer].team))
	for peer: int in w.away_forces: away.append([peer,PackedInt64Array(w.away_forces[peer].squads.keys()),PackedInt64Array(w.away_forces[peer].vehicles.keys())])
	return [[PackedStringArray(w.rules.upgrades[0].keys()),PackedStringArray(w.rules.upgrades[1].keys())],peers,away]

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64; Defs.MAP_HALF = 32.0
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var loss: RefCounted = ClassDB.instantiate("VehicleLossWorldCore")
	var birth := preload("res://tests/fixtures/vehicle-loss.gd").new(); var movement := preload("res://tests/fixtures/squad-movement.gd").new()
	var battle := preload("res://tests/fixtures/battle-stats.gd").new(); var boat_helper := preload("res://tests/fixtures/boat-navigation.gd").new()
	var men := []; var buildings := []
	for kind: String in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[kind]; var weapon: Dictionary = Defs.WEAPONS.get(d.weapon,{})
		men.append([kind,bool(d.get("bearer",false)),int(weapon.get("ammo",-1)),BattleStats.MAN_VALUE,float(weapon.get("range",-1)),String(d.name)])
	for kind: String in Defs.BUILDINGS: buildings.append([kind,true,float(Defs.BUILDINGS[kind].get("cost",0))])
	var count := 0; var seen := {}; var original_players: Dictionary = Net.players.duplicate(true)
	var items: Array = Defs.SQUADS.keys()+Defs.VEHICLES.keys()+Defs.UPGRADES.keys()
	for trial in 4:
		for key: String in items:
			var w := ProductionWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
			w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
			w.combat = Combat.new(w); w.combat.enable_native_collision(); w.fires = Fires.new(w)
			w.rules = Rules.new(w); w.rules.upgrades = [{},{}]; w.battle = BattleStats.new(w); w._deferred_effects = DeferredEffects.new(false)
			w.time = 100.0; w.next_eid = 1000; w.next_sid = 7; add_child(w)
			var team := trial % 2; Net.players = {7:{"team":team}} if trial == 0 else {8:{"team":team},9:{"team":1-team},10:{"team":team}} if trial == 1 else {}
			if trial > 0: w.away_forces[7] = {"squads":{},"vehicles":{}}
			if trial == 1: w.rules.upgrades[team] = {"armor":true,"grenades":true}
			var d: Dictionary = Defs.VEHICLES.get(key,{}); var kind := "research" if Defs.UPGRADES.has(key) else "barracks" if Defs.SQUADS.has(key) else "dock" if d.get("base","") == "boat" else "helipad" if d.get("air",false) else "factory"
			var st: Structure = w.spawn("structure",{"skind":kind,"team":team,"owner":7,"pos":Vector3(0.3,0,-9.7),"yaw":PI if kind == "dock" else trial*0.317-1.3})
			st.queue = [{"item":key,"t":0.3,"total":10.0,"owner":7,"cost":90}]; st._tick_t = 0.2
			if trial % 2: st.rally = Vector3(9.3,0,20.7)
			if trial != 3: w.spawn("structure",{"skind":"fob","team":team,"pos":Vector3(-22,0,-22)})
			for id in range(1,7):
				var s := Trooper.new(); s.world = w; s.srv = true; s.eid = id; s.team = team; s.owner_peer = 7
				s.utype = "bearer" if id == 1 else "rifleman"; s.position = Vector3(20,0,id*1.3); w._register(s); w.add_child(s); s.on_spawned(); s.sname = "Waiting %d" % id
				if id == 2: s.life = Soldier.Life.DOWNED
				if id == 3: s.life = Soldier.Life.HIDDEN; s.hidden_reason = "tent"
			w.water.deck.resize(64*64); w.water.deck.fill(0)
			if kind == "dock":
				w.water.rivers = [{"pts":PackedVector3Array([Vector3(-32,0,20),Vector3(32,0,20)]),"w":40.0}]
				for z in range(32,64):
					for x in range(3,61): w.terrain.base[z*64+x] = TerrainMap.WATER
				assert(w.terrain._native.configure(64,[w.terrain.base,w.terrain.crater,w.terrain.rubble,w.terrain.woods,w.terrain.cov,w.terrain.cdir,w.terrain.solid,w.terrain.trench,w.terrain.netted],w.terrain.dh))
				w.nav.build_boat_grid(w.water); boat_helper.reference_grid(w)
			w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
			var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
			var units: RefCounted = ClassDB.instantiate("SpatialIndexCore"); var structure_state: RefCounted = ClassDB.instantiate("StructureStateCore")
			var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore"); var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore"); var deferred: RefCounted = ClassDB.instantiate("DeferredEffectsCore")
			var visibility: RefCounted = ClassDB.instantiate("VisibilityCore"); var fires: RefCounted = ClassDB.instantiate("FiresCore"); var random := SimulationRandom.new()
			var boats: RefCounted = ClassDB.instantiate("BoatNavigationCore"); assert(boats.configure(w.terrain._native,w.water.deck))
			var types := PackedByteArray(); var blocks := []
			for e: Entity in w.entities.values():
				if e is Soldier: types.append(0); blocks.append(movement.soldier_bytes(e))
				else: assert(structure_state.load_state(StructureState.capture(e))); types.append(1); blocks.append(structure_state.checkpoint())
			assert(actors.load_state(w.next_eid,types,blocks)); assert(geometry.restore(world_save(w))); assert(units.restore(spatial_save(w._uhash,12.0)))
			assert(visibility.restore(w.combat._visibility.checkpoint())); assert(fires.configure(64,false))
			var retained_rules := rules_state(w); var qs: Array[SquadStateCore] = []
			w.rng.seed = 3917 + count; random.seed = w.rng.seed
			for step in 3:
				var dt: float = [0.1,0.5,1.0][step]; w.time += dt; var vehicles := []; var caps := PackedInt64Array()
				for v: Vehicle in w.vehicles:
					vehicles.append([v.eid,v.display_name(),v.base(),v.is_heli(),v.is_auto(),int(v.vdef.get("crew",-1)),float(v.vdef.get("cost",0)),w.rules.has_upgrade(v.team,"armor"),w.rules.has_upgrade(v.team,"grenades"),v.weight(),v._hull_size()]); caps.append(v.eid); caps.append(int(v.vdef.cap))
				var config := [w.next_sid,w.time,w.town_rect,[PackedStringArray(Defs.NAMES[0]),PackedStringArray(Defs.NAMES[1])],[birth.loadout("crewman"),birth.loadout("r_crewman")],vehicles,men,buildings]
				var input := [st.eid,dt,Defs.BASE_CAP,Defs.CAP_PER_FOB,product(key,birth) if not st.queue.is_empty() else [],caps,retained_rules]
				w.spoken.clear(); w.messages.clear(); w.warnings.clear(); w.stats.clear()
				var result: Array = loss.advance_production(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,input,boats)
				var label := "%s/%d/%d" % [key,trial,step]; assert(result.size() == 4,"result " + label)
				st.sim(dt); w.combat._sync_collision(); retained_rules = result[3][1]
				assert(w.rng.state == random.state,"random " + label); assert(actors.next_id() == w.next_eid and result[0] == w.next_sid,"identities " + label)
				assert(retained_rules == rules_state(w),"research and ownership " + label)
				var ids := PackedInt64Array()
				for e: Entity in w.entities.values():
					ids.append(e.eid); ids.append(0 if e is Soldier else 2 if e is Vehicle else 1)
					if e is Soldier: movement.compare_actor(e,actors,label + "/%d" % e.eid)
					elif e is Vehicle:
						assert(vehicle.restore(actors.actor_state(e.eid)))
						var expected := VehicleState.capture(e); var actual: Array = vehicle.values()
						for group in expected.size(): assert(expected[group] == actual[group], "vehicle %s group=%d expected=%s actual=%s" % [label, group, expected[group], actual[group]])
					else: assert(structure_state.restore(actors.actor_state(e.eid))); assert(structure_state.values() == StructureState.capture(e),"building " + label)
				assert(actors.identities() == ids,"registry " + label)
				qs.clear()
				for bytes: PackedByteArray in result[1]:
					var q: SquadStateCore = ClassDB.instantiate("SquadStateCore"); assert(q.restore(bytes)); qs.append(q); movement.compare_squad(w.squads[q.values()[0][0]],q,{},label)
				var said := []; var messages := []; var warnings := []
				for event: Array in result[3][0]:
					match int(event[0]):
						0:
							seen.cap = true
							if event[1] > 0: warnings.append([event[1],"warn","Unit cap reached. Build another FOB to raise it."])
						1: seen.squad = true
						2: seen.vehicle = true; seen[kind] = true
						3: messages.append([event[1],"info","Research complete: %s." % event[2],null]); seen.research = true
						4: messages.append([event[1],"info","%s ready." % event[2],null])
						5:
							var speech: Array = event[1]
							if speech[0] == 0:
								var s: Soldier = w.entities[speech[1]]; said.append([s.eid,movement.speech(s.squad,speech[2],speech[3])])
				assert(said == w.spoken,"speech " + label); assert(messages == w.messages,"messages " + label); assert(warnings == w.warnings,"warnings " + label)
				battle.compare_ledger(w.battle,ledger,label); check_geometry(w,geometry,label)
				w.nav.process_paths(50); assert(geometry.process_paths(actors,50,w.time,random._backend))
				for s: Soldier in w.soldiers: movement.compare_actor(s,actors,label + " routed/%d" % s.eid)
				assert(w.rng.state == random.state); assert(geometry.inspect()[1] == nav_save(w.nav))
				for retained in [actors,geometry,units,ledger,deferred,visibility,fires,boats]: assert(retained.restore(retained.checkpoint()))
				count += 1
			w.free()
	Net.players = original_players
	for key in ["cap","squad","vehicle","research","dock","helipad"]: assert(seen.has(key),"coverage "+key)
	birth.free(); movement.free(); battle.free(); boat_helper.free()
	print("STRUCTURE_PRODUCTION passed states=",count); get_tree().quit()
