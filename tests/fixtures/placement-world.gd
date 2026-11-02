extends "res://tests/fixtures/structure-production.gd"

func _ready() -> void:
	MapDims.N = 256; MapDims.SIZE = 256.0; MapDims.HALF = 128.0; MapDims.BIOME = 256; Defs.MAP_HALF = 128.0
	Nav.N = 256; Nav.H = 128.0; HNav.C = 16; HNav.NC = 16; HNav.NCC = 256; HNav._corner = HNav._corners()
	TerrainMap.N = 256; TerrainMap.H = 128.0; TerrainMap.DN = 512
	var movement := preload("res://tests/fixtures/squad-orders.gd").new(); var records := preload("res://tests/fixtures/battle-stats.gd").new()
	var apply: RefCounted = ClassDB.instantiate("SquadMovementCore"); var saved: Dictionary = Net.players.duplicate(true)
	var count := 0; var born := {}; var warnings := 0
	for trial in 4:
		for key: String in Defs.BUILDINGS:
			var team := trial % 2; var owner := 1 if trial < 2 else -1-team
			Net.players = {7:{"team":team,"name":"Builder"}}
			var w := ProductionWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false,"debug":true}; w.time = 100.0; w.next_eid = 100
			w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain; w.combat = Combat.new(w); w.combat.enable_native_collision()
			w.rules = Rules.new(w); w.rules.upgrades = [{},{}]; w.battle = BattleStats.new(w); add_child(w)
			var base: Structure = w.spawn("structure",{"skind":"fob","team":team,"pos":Vector3(-40,0,40),"supply":5000.0})
			if key == "dock": w.water.coast = {"x":64.0,"s":0.0}; w.water.paint_kinds()
			if key in ["mg_nest","hmg_nest"]: w.spawn("structure",{"skind":"trench","team":team,"pos":Vector3(-20,0,14),"size":Vector3(12,3,3.2)})
			var q := Squad.new(); q.world = w; q.sid = 7; q.team = team; q.owner = owner; q.kind = "engineer_team"; w.squads[7] = q
			for id in range(1,5):
				var s := Trooper.new(); s.world = w; s.srv = true; s.eid = id; s.team = team; s.owner_peer = owner
				s.utype = "engineer" if id == 2 else "rifleman"; s.udef = Defs.UNITS[s.utype]; s.wdef = Defs.WEAPONS[s.udef.weapon]; s.sname = "Builder %d" % id
				s.position = Vector3(-32+id*2,0,8+id); w.add_child(s); w._register(s); q.add(s)
			q.leader = w.entities[1]; w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
			var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore"); var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
			var rules: RefCounted = ClassDB.instantiate("RulesWorldCore"); var owners: RefCounted = ClassDB.instantiate("CommandOwnershipCore"); var battle: RefCounted = ClassDB.instantiate("BattleStatsCore")
			var water: RefCounted = ClassDB.instantiate("WaterRaster"); var state: RefCounted = ClassDB.instantiate("StructureStateCore")
			var sq: SquadStateCore = ClassDB.instantiate("SquadStateCore"); var qs: Array[SquadStateCore] = [sq]
			assert(sq.load_state(SquadState.capture(q))); var profiles := movement.import_actors(w,actors,w.next_eid)
			assert(geometry.restore(world_save(w))); assert(units.restore(spatial_save(w._uhash,12.0))); assert(water.configure(256,w.water.to_dict())); assert(owners.load_state(rules_state(w)))
			assert(battle.joined(7,team,"Builder")); w.battle.joined(7,team)
			var rng := SimulationRandom.new(); w.rng.seed = 7137+count; rng.seed = w.rng.seed
			var def: Dictionary = Defs.BUILDINGS[key]; var mask := 0
			for side: int in def.teams: mask |= 1 << side
			var definition := [key,String(def.name),mask,int(def.cost),def.size,float(def.hp)]
			for step in 4:
				var p := Vector3(30,0,20) if key == "fob" else Vector3(50,0,20 if team == 0 else -20) if key == "dock" else Vector3(-20,0,15)
				if step == 2: p.x += 12
				if step == 3: p = Vector3(120,0,0)
				var yaw := -PI/2 if key == "dock" else 0.0; var size := Vector3(8,3,def.size.y) if key == "trench" else Vector3.ZERO
				var selected: Array = [q] if trial % 2 else []; var ids := PackedInt64Array([7] if trial % 2 else []); var assign := step != 2
				var names := {}
				for st: Structure in w.structures: names[st.eid] = st.display_name()
				var input := [rules,owners,battle,water,[7,team,p,yaw,size,ids,assign],definition,PackedFloat64Array([Defs.BUILD_RADIUS,Defs.FOB_MIN_SPACING,Defs.FOB_EXPAND_RADIUS]),PackedStringArray(Defs.FOB_NAMES[team]),PackedInt64Array([2]),names]
				w.spoken.clear(); w.warnings.clear(); w.stats.clear()
				var result: Array = apply.apply(actors,geometry,units,qs,rng._backend,profiles,w.time,w.town_rect,7,34,input)
				var built := w.rules.try_place(7,team,key,p,yaw,selected,assign,size); w.combat._sync_collision()
				var label := "%s/%d/%d" % [key,trial,step]; assert(result.size() == 1,"result "+label)
				var messages := []; var said := []; var id := 0
				for e: Array in result[0]:
					if e[0] == 0: messages.append([e[1],"warn",e[2]]); warnings += 1
					elif e[0] == 1: id = e[1]; born[key] = true
					elif e[0] == 2:
						var event: Array = e[1]; assert(event[0] == 0); said.append([event[1],movement.order_speech(q,event[2],event[3])])
				assert(id == (built.eid if built else 0),"birth "+label); assert(messages == w.warnings,"warnings "+label); assert(said == w.spoken,"speech "+label)
				movement.compare_squad(q,sq,{},label)
				for s: Soldier in w.soldiers: movement.compare_actor(s,actors,label)
				for st: Structure in w.structures: assert(state.restore(actors.actor_state(st.eid))); assert(state.values() == StructureState.capture(st),"structure "+label)
				records.compare_ledger(w.battle,battle,label); assert(rules.values()[7] == PackedInt64Array(w.rules.fob_names_used),"names "+label)
				assert(geometry.inspect()[1] == nav_save(w.nav),"navigation "+label); assert(w.rng.state == rng.state,"random "+label)
				assert(actors.restore(actors.checkpoint())); assert(geometry.restore(geometry.checkpoint())); assert(rules.restore(rules.checkpoint())); count += 1
			w.free()
	assert(born.size() >= 20 and warnings > 0,"coverage")
	Net.players = saved; movement.free(); records.free(); print("PLACEMENT_WORLD passed states=",count," buildings=",born.size()); get_tree().quit()
