extends "res://tests/fixtures/fires-native.gd"

class ServiceWorld extends FireWorld:
	var spoken := []; var messages := []
	func say(e: Entity, text: String) -> void: spoken.append([e.eid,text])
	func send_msg(team: int, kind: String, text: String, ping = null) -> void: messages.append([team,kind,text,ping])

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64; Defs.MAP_HALF = 32.0
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var loss: RefCounted = ClassDB.instantiate("VehicleLossWorldCore")
	var birth := preload("res://tests/fixtures/vehicle-loss.gd").new(); var movement := preload("res://tests/fixtures/squad-movement.gd").new()
	var gun_helper := preload("res://tests/fixtures/infantry-fire.gd").new()
	var men := []; var buildings := []
	for kind: String in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[kind]; var weapon: Dictionary = Defs.WEAPONS.get(d.weapon,{})
		men.append([kind,bool(d.get("bearer",false)),int(weapon.get("ammo",-1)),BattleStats.MAN_VALUE,float(weapon.get("range",-1)),String(d.name)])
	for kind: String in Defs.BUILDINGS: buildings.append([kind,true,float(Defs.BUILDINGS[kind].get("cost",0))])
	var count := 0; var seen := {}
	for trial in 24:
		for kind: String in ["medic_tent","watchtower","mg_nest","hmg_nest","mortar_pit","at_post","ammo_cache"]:
			var w := ServiceWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
			w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
			w.combat = Combat.new(w); w.combat.enable_native_collision(); w.fires = Fires.new(w)
			w.rules = Rules.new(w); w.rules.upgrades = [{},{}]; w.battle = BattleStats.new(w); w._deferred_effects = DeferredEffects.new(false)
			w.time = 100.0; w.next_eid = 1000; w.next_sid = 7; add_child(w)
			var team := trial % 2
			if trial % 3 == 0: w.rules.upgrades[team].armor = true
			if trial % 4 == 0: w.rules.upgrades[team].grenades = true
			var st: Structure = w.spawn("structure",{"skind":kind,"team":team,"owner":7,"pos":Vector3(1.3,0,-2.7),"yaw":trial*0.317-1.3,"variant":trial % 2})
			st._tick_t = 0.7 if trial % 3 == 0 else 0.0; st.bearer_t = 0.0 if trial % 4 == 0 else 1.7
			st.supply = [0.0,0.5,1.3,20.0][trial % 4]; st.built = trial % 11 != 0
			for id in range(1,11):
				var s := Trooper.new(); s.world = w; s.srv = true; s.eid = id; s.team = team; s.owner_peer = 7
				s.utype = "bearer" if id <= 2 else "medic" if id == 3 else "mg_gunner" if id == 4 else "mortar_gunner" if id == 5 else "at_soldier" if id == 6 else "rifleman"
				s.position = st.position + Vector3(id*0.52-2.7,0,(id % 3)*0.71); w._register(s); w.add_child(s); s.on_spawned()
				s.sname = "Crew %d" % id; s.mag = 0 if id % 3 == 0 else 5; s.reserve = 0 if trial % 2 else 47; s.frags = trial % 4
				s.say_cd = 1.7 if trial % 3 == 1 else 0.0
				if id <= 2:
					if trial % 4 != 0: st.bearers.append(s)
					if trial % 5 == 0: s.life = Soldier.Life.SURRENDER if id == 1 else Soldier.Life.DEAD
					if trial % 7 == 0: s.team = 1-team
				if id >= 8:
					s.life = Soldier.Life.DOWNED if id != 9 else Soldier.Life.DEAD
					s.downed_t = w.time - (5.0 if trial % 3 == 0 else 7.0); s.dead_t = w.time - (241.0 if trial % 4 == 0 else 10.0)
					if trial % 6 == 0: s.stretcher_claimed = true
					if trial % 8 == 0: s.rescue_claimed = w.entities[3]
				if id == 7 and kind != "medic_tent" and trial % 4 == 0:
					st.gunner = s; s.task = "man" if trial % 8 == 0 else ""; s.task_ent = st; s.mounted = st; s.task_phase = 2
				if id == 3 and trial % 3 == 0: s.team = 1-team
			w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
			var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
			var units: RefCounted = ClassDB.instantiate("SpatialIndexCore"); var structure_state: RefCounted = ClassDB.instantiate("StructureStateCore")
			var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore"); var deferred: RefCounted = ClassDB.instantiate("DeferredEffectsCore")
			var visibility: RefCounted = ClassDB.instantiate("VisibilityCore"); var fires: RefCounted = ClassDB.instantiate("FiresCore"); var random := SimulationRandom.new()
			var types := PackedByteArray(); var blocks := []
			for e: Entity in w.entities.values():
				if e is Soldier: types.append(0); blocks.append(movement.soldier_bytes(e))
				else: assert(structure_state.load_state(StructureState.capture(e))); types.append(1); blocks.append(structure_state.checkpoint())
			assert(actors.load_state(w.next_eid,types,blocks)); assert(geometry.restore(world_save(w))); assert(units.restore(spatial_save(w._uhash,12.0)))
			assert(visibility.restore(w.combat._visibility.checkpoint())); assert(fires.configure(64,false))
			w.rng.seed = 3917 + count; random.seed = w.rng.seed
			for step in 8:
				if st.gone: break
				var stock := []; var metadata := []
				for s: Soldier in w.soldiers:
					var ammo := PackedInt32Array([s.wdef.get("ammo",-1),int(s.udef.frags)+int(w.rules.has_upgrade(s.team,"grenades")),s.udef.smokes,s.udef.get("rockets",0),s.udef.get("drones",0),s.udef.get("mortar",0),s.cur_weapon().get("ammo",0),s.cur_weapon().get("mag",0)])
					stock.append([s.eid,ammo,float(s.cur_weapon().get("reload",0.0)),InfantryState.weapon_key(s.cur_weapon()),int(s.cur_weapon().get("mag",0))])
					metadata.append([s.eid,int(s.cur_weapon().get("ammo",-1)),int(s.udef.frags)])
				var dt: float = [0.1,0.5,1.0][step % 3]; w.time += dt
				var config := [w.next_sid,w.time,w.town_rect,[PackedStringArray(Defs.NAMES[0]),PackedStringArray(Defs.NAMES[1])],[birth.loadout("crewman"),birth.loadout("r_crewman")],[],men,buildings]
				var input := [st.eid,dt,stock,metadata,birth.loadout("bearer"),w.rules.has_upgrade(team,"armor"),w.rules.has_upgrade(team,"grenades"),gun_helper.gun_profile(st) if kind in ["mg_nest","hmg_nest"] else PackedFloat64Array()]
				var qs: Array[SquadStateCore] = []; w.spoken.clear(); w.messages.clear(); w.stats.clear()
				var result: Array = loss.advance_structure_service(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,input)
				var label := "service %s/%d/%d" % [kind,trial,step]; assert(result.size() == 4,"result " + label)
				st.sim(dt)
				assert(w.rng.state == random.state,"random " + label); assert(actors.next_id() == w.next_eid,"identities " + label)
				if not st.gone: assert(structure_state.restore(actors.actor_state(st.eid))); assert(structure_state.values() == StructureState.capture(st),"building " + label)
				else: assert(actors.actor_state(st.eid).is_empty())
				for s: Soldier in w.soldiers: movement.compare_actor(s,actors,label + "/%d" % s.eid)
				var said := []; var messages := []; var stats := {}
				for event: Array in result[3]:
					match int(event[0]):
						0: seen.born = true
						1: said.append([event[1],["Reloading!","Changing mag!","Cover me, reloading!"][event[2]]])
						2: messages.append([event[2],"info","The ammo cache at %s is empty." % Defs.grid_ref(event[3]),event[3]])
						4: stats[event[1]] = stats.get(event[1],0)+1; seen[event[1]] = true
				assert(said == w.spoken,"speech " + label); assert(messages == w.messages,"messages " + label); assert(stats == w.stats,"stats " + label)
				check_geometry(w,geometry,label)
				w.nav.process_paths(50); assert(geometry.process_paths(actors,50,w.time,random._backend))
				for s: Soldier in w.soldiers: movement.compare_actor(s,actors,label + " routed/%d" % s.eid)
				assert(w.rng.state == random.state); assert(geometry.inspect()[1] == nav_save(w.nav))
				if step % 3 == 0:
					for retained in [actors,geometry,units,ledger,deferred,visibility,fires]: assert(retained.restore(retained.checkpoint()))
				count += 1
			w.free()
	for key in ["born","stretcher_job","manned","tower_manned","cache_draw","cache_empty"]: assert(seen.has(key),"coverage "+key)
	birth.free(); movement.free(); gun_helper.free()
	print("STRUCTURE_SERVICES passed states=",count); get_tree().quit()
