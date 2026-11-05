extends "res://tests/fixtures/structure-production.gd"

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64; Defs.MAP_HALF = 32.0
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var core: RefCounted = ClassDB.instantiate("ProductionOrdersCore")
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore")
	var state: RefCounted = ClassDB.instantiate("StructureStateCore"); var helper := preload("res://tests/fixtures/battle-stats.gd").new()
	var research := []; var cases := []
	for key: String in Defs.UPGRADES:
		var d: Dictionary = Defs.UPGRADES[key]; var mask := 0
		for team: int in d.teams: mask |= 1 << team
		research.append([key,String(d.name),mask,int(d.get("tier",0))])
		for team in 2: cases.append(["research",team,key,true])
	for kind: String in Defs.BUILDINGS:
		var d: Dictionary = Defs.BUILDINGS[kind]
		if kind == "research" or not d.has("produces"): continue
		for team in 2:
			for key: String in d.produces[team]: cases.append([kind,team,key,false])
	var count := 0; var changed := 0; var warned := 0; var ignored := 0
	for trial in 6:
		for row: Array in cases:
			var kind: String = row[0]; var team: int = row[1]; var key: String = row[2]; var is_research: bool = row[3]
			var d: Dictionary = Defs.UPGRADES[key] if is_research else Defs.SQUADS[key] if Defs.SQUADS.has(key) else Defs.VEHICLES[key]
			var mask := 0
			for side: int in d.get("teams",[0,1]): mask |= 1 << side
			var profile := [key,String(d.name),int(d.cost),float(d.time),int(d.get("tier",1)),is_research,mask,String(d.get("requires",""))]
			var w := ProductionWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
			w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
			w.combat = Combat.new(w); w.combat.enable_native_collision(); w.fires = Fires.new(w)
			w.rules = Rules.new(w); w.rules.upgrades = [{},{}]; w.battle = BattleStats.new(w); w._deferred_effects = DeferredEffects.new(false)
			w.time = 100.0; w.next_eid = 1000; add_child(w)
			if trial != 2:
				for upgrade: String in Defs.UPGRADES:
					if upgrade != key or trial == 4: w.rules.upgrades[team][upgrade] = true
			var st: Structure = w.spawn("structure",{"skind":kind,"team":team,"owner":7,"pos":Vector3(0,0,-12)})
			st.built = trial != 3
			for i in 2:
				var f: Structure = w.spawn("structure",{"skind":"fob","team":team,"pos":Vector3(i*20-10,0,20)})
				f.supply = 0.0 if trial == 1 else 10000.3
				f.wrecked = trial == 5 and i == 0
			var blocks := []; var types := PackedByteArray()
			for e: Structure in w.structures: assert(state.load_state(StructureState.capture(e))); blocks.append(state.checkpoint()); types.append(1)
			assert(actors.load_state(w.next_eid,types,blocks)); ledger = ClassDB.instantiate("BattleStatsCore")
			var produces := PackedStringArray(Defs.BUILDINGS[kind].get("produces",[[],[]])[team])
			var input := [rules_state(w)[0],profile,produces,research]
			for step in 9:
				var peer := -1-team if trial == 5 else 7+step%2; var cancel := step >= 7; var old := st.queue.size(); w.warnings.clear()
				var result: Array = core.request(actors,ledger,st.eid,peer,team,cancel,input)
				if cancel: st.cancel_last(peer)
				elif is_research: st.queue_research(peer,key)
				else: st.queue_item(peer,key)
				var label := "%s/%s/%d/%d/%d" % [kind,key,team,trial,step]
				assert(not result.is_empty(),"result "+label)
				var warnings := []
				if result[0] == 2: warnings.append([result[1],"warn",result[2]]); warned += 1
				elif result[0] == 1: changed += 1
				else: ignored += 1
				assert(warnings == w.warnings,"warnings "+label)
				assert((result[0] == 1) == (old != st.queue.size()),"admission "+label)
				for e: Structure in w.structures:
					assert(state.restore(actors.actor_state(e.eid))); assert(state.values() == StructureState.capture(e),"state "+label)
				helper.compare_ledger(w.battle,ledger,label)
				assert(actors.restore(actors.checkpoint())); assert(ledger.restore(ledger.checkpoint())); count += 1
			w.free()
	assert(changed > 0 and warned > 0 and ignored > 0,"coverage")
	helper.free(); print("PRODUCTION_ORDERS passed states=",count); get_tree().quit()
