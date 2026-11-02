extends "res://tests/fixtures/fires-native.gd"

class TerritoryWorld extends FireWorld:
	var spoken := []; var messages := []
	func say(e: Entity, text: String) -> void: spoken.append([e.eid,text])
	func send_msg(team: int, kind: String, text: String, ping = null) -> void: messages.append([team,kind,text,ping])
	func declare_winner(team: int) -> void: winner = team

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64; Defs.MAP_HALF = 32.0
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var loss: RefCounted = ClassDB.instantiate("VehicleLossWorldCore")
	var birth := preload("res://tests/fixtures/vehicle-loss.gd").new(); var movement := preload("res://tests/fixtures/squad-movement.gd").new()
	var battle := preload("res://tests/fixtures/battle-stats.gd").new(); var infantry := preload("res://tests/fixtures/infantry-update.gd").new()
	var men := []; var buildings := []; var economy := PackedFloat64Array()
	for kind: String in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[kind]; var weapon: Dictionary = Defs.WEAPONS.get(d.weapon,{})
		men.append([kind,bool(d.get("bearer",false)),int(weapon.get("ammo",-1)),BattleStats.MAN_VALUE,float(weapon.get("range",-1)),String(d.name)])
	for kind: String in Defs.BUILDINGS: buildings.append([kind,true,float(Defs.BUILDINGS[kind].get("cost",0))])
	for k in 2: economy.append_array(PackedFloat64Array([Defs.TOWN_STOCK[k],Defs.TOWN_YIELD[k],Defs.TOWN_PACE[k]]))
	var count := 0; var seen := {}
	for trial in 32:
		for kind: String in ["fob","town","mines"]:
			var w := TerritoryWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
			w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
			w.combat = Combat.new(w); w.combat.enable_native_collision(); w.fires = Fires.new(w)
			w.rules = Rules.new(w); w.rules.upgrades = [{},{}]; w.battle = BattleStats.new(w); w._deferred_effects = DeferredEffects.new(false)
			w.time = 100.0 if trial % 7 else 1.0; w.next_eid = 1000; w.next_sid = 7; add_child(w)
			var team := trial % 2; var enemy := 1-team
			var st: Structure = w.spawn("structure",{"skind":kind,"team":-1 if kind == "town" and trial % 4 == 0 else team,"owner":7,"pos":Vector3(1.3,0,-2.7),"yaw":trial*0.317-1.3,"variant":trial % 2,"name":"Crossroads"})
			st._tick_t = 0.7 if trial % 3 == 0 else 0.0; st.built = trial % 11 != 0; st.wrecked = trial % 9 == 0
			st.supply = [0.0,0.5,27.3,179.9][trial % 4]; st.cap_prog = 99.9 if trial % 3 else 0.0; st.cap_team = enemy if trial % 3 else -1
			st.zone_c = st.position + Vector3(0.7,0,0.4); st.zone_r = 9.0; st.houses0 = -1 if trial % 2 else 5; st.intact = 0.1; st._house_t = 0.0
			for side in 2:
				var depot: Structure = w.spawn("structure",{"skind":"depot","team":side,"pos":Vector3(-25+side*50,0,-25)})
				w.rules.depots[side] = depot
				if side != team or trial % 2 == 0:
					w.spawn("structure",{"skind":"fob","team":side,"pos":Vector3(-25+side*50,0,25),"name":"Rear"})
			if kind == "town": w.rules.town_list.append(st)
			if kind != "mines":
				for x in [-4,3,20]: w.spawn("structure",{"skind":"roof","team":-1,"pos":Vector3(x,0,4),"size":Vector3(2,2,2)})
			for id in range(1,7):
				var s := Trooper.new(); s.world = w; s.srv = true; s.eid = id; s.team = enemy; s.owner_peer = 8
				s.utype = "bearer" if id == 1 else "rifleman"
				s.position = st.position + Vector3(id*0.35-1.2,0,(id % 3)*0.41); w._register(s); w.add_child(s); s.on_spawned()
				s.sname = "Patrol %d" % id; s.mag = 0 if id % 3 == 0 else 5; s.reserve = 17; s.frags = 0
				if trial % 4 == 0: s.team = team if id <= 3 else enemy
				if trial % 5 == 0: s.life = Soldier.Life.DOWNED
				if kind == "mines" and trial % 4 == 2: s.team = team
			if kind == "mines" and trial % 4 == 2:
				w.spawn("vehicle",{"vkind":"tank" if trial % 8 else "truck","team":enemy,"owner":8,"pos":st.position+Vector3(0.9,0,0.2)})
			w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
			var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
			var units: RefCounted = ClassDB.instantiate("SpatialIndexCore"); var structure_state: RefCounted = ClassDB.instantiate("StructureStateCore")
			var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore"); var soldier: RefCounted = ClassDB.instantiate("InfantryStateCore")
			var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore"); var deferred: RefCounted = ClassDB.instantiate("DeferredEffectsCore")
			var visibility: RefCounted = ClassDB.instantiate("VisibilityCore"); var fires: RefCounted = ClassDB.instantiate("FiresCore"); var random := SimulationRandom.new()
			var network: RefCounted = ClassDB.instantiate("SupplyNetworkCore")
			var types := PackedByteArray(); var blocks := []; var vehicles := []
			for e: Entity in w.entities.values():
				if e is Soldier: types.append(0); blocks.append(movement.soldier_bytes(e))
				elif e is Vehicle:
					assert(vehicle.load_state(VehicleState.capture(e))); types.append(2); blocks.append(vehicle.checkpoint())
					if not e.is_auto() and e.vkind != "truck": assert(ledger.register_unit("v%d" % e.eid,e.display_name(),"vehicle",e.team,e.owner_peer,w.time,1))
					vehicles.append([e.eid,e.display_name(),e.base(),e.is_heli(),e.is_auto(),int(e.vdef.get("crew",-1)),float(e.vdef.get("cost",0)),false,false,e.weight(),e._hull_size(),int(e.vdef.get("armor",0)),float(e.vdef.get("toss",1.0))])
				else: assert(structure_state.load_state(StructureState.capture(e))); types.append(1); blocks.append(structure_state.checkpoint())
			assert(actors.load_state(w.next_eid,types,blocks)); assert(geometry.restore(world_save(w))); assert(units.restore(spatial_save(w._uhash,12.0)))
			var depots := InfantryState.entity_ids(w.rules.depots); var towns := InfantryState.entity_ids(w.rules.town_list)
			assert(network.load_state(depots,towns,w.rules.fob_order,w.roads,w._painted_roads))
			assert(visibility.restore(w.combat._visibility.checkpoint())); assert(fires.configure(64,false))
			w.rng.seed = 3917 + count; random.seed = w.rng.seed
			for step in 8:
				if st.gone: break
				var stock := []; var metadata := []
				for s: Soldier in w.soldiers:
					var ammo := PackedInt32Array([s.wdef.get("ammo",-1),int(s.udef.frags),s.udef.smokes,s.udef.get("rockets",0),s.udef.get("drones",0),s.udef.get("mortar",0),s.cur_weapon().get("ammo",0),s.cur_weapon().get("mag",0)])
					stock.append([s.eid,ammo,float(s.cur_weapon().get("reload",0.0)),InfantryState.weapon_key(s.cur_weapon()),int(s.cur_weapon().get("mag",0))])
					metadata.append([s.eid,int(s.cur_weapon().get("ammo",-1)),int(s.udef.frags)])
				var dt: float = [0.1,0.5,1.0][step % 3]; w.time += dt
				var config := [w.next_sid,w.time,w.town_rect,[PackedStringArray(Defs.NAMES[0]),PackedStringArray(Defs.NAMES[1])],[birth.loadout("crewman"),birth.loadout("r_crewman")],vehicles,men,buildings]
				var input := [st.eid,dt,stock,metadata,economy,Defs.FOB_RADIUS,w.winner,false]
				var qs: Array[SquadStateCore] = []; w.spoken.clear(); w.messages.clear(); w.stats.clear()
				var impacts := []
				for impact: Array in w.recent_impacts: impacts.append([impact[0],impact[1]])
				var result: Array = loss.advance_territory(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,input,network,impacts)
				var label := "%s/%d/%d" % [kind,trial,step]; assert(result.size() == 4,"result " + label)
				st.sim(dt); w.combat._sync_collision()
				assert(w.rng.state == random.state,"random " + label); assert(actors.next_id() == w.next_eid,"identities " + label)
				var ids := PackedInt64Array()
				for e: Entity in w.entities.values():
					ids.append(e.eid); ids.append(0 if e is Soldier else 2 if e is Vehicle else 1)
					if e is Soldier:
						if kind == "mines": birth.check_blast_actor(e,actors,label + "/%d" % e.eid)
						else: assert(soldier.restore(actors.actor_state(e.eid))); infantry.check_state(e,soldier,label + "/%d" % e.eid)
					elif e is Vehicle: assert(vehicle.restore(actors.actor_state(e.eid))); assert(vehicle.values() == VehicleState.capture(e),"vehicle " + label)
					else: assert(structure_state.restore(actors.actor_state(e.eid))); assert(structure_state.values() == StructureState.capture(e),"building " + label + "/%d" % e.eid)
				assert(actors.identities() == ids,"registry " + label)
				assert(result[3][0] == w.winner,"victory " + label)
				assert(result[3][2] == w.recent_impacts,"impacts " + label)
				assert(network.values() == [depots,towns,w.rules.fob_order,w.roads,w._painted_roads],"network " + label)
				battle.compare_ledger(w.battle,ledger,label); assert(fires.values() == fire_values(w.fires),"fires " + label)
				var said := []; var messages := []; var stats := {}
				for key: String in result[2]: stats[key] = stats.get(key,0)+1; seen[key] = true
				for event: Array in result[3][1]:
					if event[0] == 0:
						var p: Array = event[1]; seen.warning = true
						messages.append([p[1],"alert",(("LAST STAND: FOB %s is being captured! Lose it and we lose the battle." if event[2] else "FOB %s is being captured!") % p[3]) if p[2] == "fob" else "%s is being taken! The enemy is in the %s." % [p[3],"town" if p[5] == 1 else "village"],p[4]])
					elif event[0] == 1:
						var p: Array = event[1]; var old: int = event[2]
						if p[2] == "fob":
							messages.append([p[1],"info","We captured FOB %s!" % p[3],p[4]]); messages.append([old,"alert","We lost FOB %s!" % p[3],p[4]])
						else:
							var what := "town" if p[5] == 1 else "village"; var txt := "We hold %s." % p[3]
							if event[3] > 0: txt += " %d supply in its dump is ours." % event[3]
							txt += " Its trucks will run to FOB %s." % w.entities[event[4]].sname if event[4] else " There's no FOB to truck its supply to."
							messages.append([p[1],"info",txt,p[4]])
							messages.append([old,"alert","We lost %s! The enemy holds the %s." % [p[3],what],p[4]] if old >= 0 else [1-p[1],"info","The enemy has taken the %s of %s." % [what,p[3]],p[4]])
					elif event[0] == 2: seen.victory = true
					elif event[0] == 3 and event[1][0] == 1: said.append([event[1][1],["Reloading!","Changing mag!","Cover me, reloading!"][event[1][2]]])
				if kind != "mines":
					assert(messages == w.messages,"messages " + label); assert(said == w.spoken,"speech " + label); assert(stats == w.stats,"stats " + label)
				else:
					for key in stats: assert(stats[key] == w.stats.get(key,0),"stat " + label + key)
					if st.gone: seen.mine = true
				check_geometry(w,geometry,label)
				if step % 3 == 0:
					for retained in [actors,geometry,units,ledger,deferred,visibility,fires,network]: assert(retained.restore(retained.checkpoint()))
				count += 1
			w.free()
	for key in ["fob_captured","town_captured","warning","victory","mine"]: assert(seen.has(key),"coverage "+key)
	birth.free(); movement.free(); battle.free(); infantry.free()
	print("STRUCTURE_WORLD passed states=",count); get_tree().quit()
