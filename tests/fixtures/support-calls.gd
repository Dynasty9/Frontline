extends "res://tests/fixtures/structure-production.gd"

class CallWorld extends ProductionWorld:
	var events := []
	func fx_event(e: Array) -> void:
		if e[0] == Fx.SUPPORT: events.append([1,e[1],e[2]])
		elif e[0] == Fx.FAR_SOUND: assert(e[2] == -14.0); events.append([5,e[1],e[3]])
	func spawn(kind: String, props: Dictionary) -> Entity:
		var e: Entity = super.spawn(kind,props)
		if e is Projectile: events.append([3,e.eid,e.mk])
		return e
	func stat(key: String) -> void:
		super.stat(key); events.append([2,key])
	func send_msg(team: int, kind: String, text: String, ping = null) -> void: events.append([4,team,kind == "alert",text,ping])
	func send_msg_to(peer: int, _kind: String, text: String) -> void: events.append([0,peer,text])

func support_profile(key: String) -> Array:
	var d: Dictionary = Defs.SUPPORT[key]; var fly := String(d.get("fly",key)); var mk := String(d.get("model","")); var muzzles := PackedVector3Array([Vector3.ZERO,Vector3.ZERO,Vector3.ZERO])
	var guns := String(d.get("guns","none" if fly == "watch" else "ac130"))
	if fly == "orbit":
		var i := 0
		for gun: String in Projectile.GUNSETS.get(guns,Projectile.AC_GUNS):
			var socket := VehicleSockets.point(mk if mk != "" else "ac130",gun)
			if socket == Vector3.INF: socket = VehicleSockets.point(mk if mk != "" else "ac130","mg" if gun == "ac25" else "gun")
			muzzles[i] = socket if socket != Vector3.INF else Vector3.ZERO; i += 1
	return [key,String(d.name),mk,int(d.team),int(d.cost),Defs.support_from(key),float(d.cooldown),float(d.get("r",14.0)),fly,bool(d.get("quiet",false)),float(d.get("leg",420.0)),float(d.get("alt",60.0)),float(d.get("speed",90.0)),float(d.get("sight",0.0)),float(d.get("stay",0.0)),int(d.get("bombs",4)),guns,muzzles]

func support_state(w: World) -> Array:
	var ready := [[],[]]
	for team in 2:
		for key: String in w.rules.support_ready[team]: ready[team].append([key,w.rules.support_ready[team][key]])
	return [ready,w.rules._support_q]

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64; MapDims.CELL = 8.0; Defs.MAP_HALF = 32.0
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var battle := preload("res://tests/fixtures/battle-stats.gd").new(); var projectile := preload("res://tests/fixtures/projectile-actor.gd").new()
	var count := 0; var accepted := 0; var rejected := 0; var shells := 0
	for key: String in Defs.SUPPORT:
		for trial in 4:
			var w := CallWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
			w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
			w.combat = Combat.new(w); w.combat.enable_native_collision(); w.fires = Fires.new(w)
			w.rules = Rules.new(w); w.battle = BattleStats.new(w); w._deferred_effects = DeferredEffects.new(false)
			w.time = 100.0; w.next_eid = 1000; add_child(w)
			var types := PackedByteArray(); var blocks := []
			var actors: RefCounted = ClassDB.instantiate("ActorStateCore"); var core: RefCounted = ClassDB.instantiate("SupportCallsCore")
			var structure: RefCounted = ClassDB.instantiate("StructureStateCore"); var shot: RefCounted = ClassDB.instantiate("ProjectileActorCore")
			var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore"); var random := SimulationRandom.new()
			for team in 2:
				for i in 2:
					var f: Structure = w.spawn("structure",{"skind":"fob","team":team,"pos":Vector3(i*20-10,0,team*20-10)})
					f.supply = 5.0 if trial == 1 else 5000.0; assert(structure.load_state(StructureState.capture(f))); types.append(1); blocks.append(structure.checkpoint())
			assert(actors.load_state(w.next_eid,types,blocks)); assert(core.load_state(support_state(w)))
			w.rng.seed = 917 + count; random.seed = w.rng.seed
			var profile := support_profile(key); var first := Defs.support_from(key); var cooldown := float(Defs.SUPPORT[key].cooldown)
			for step in 10:
				w.time = [first-0.01,first,first+0.01,first+cooldown,first+cooldown+1.0,first+cooldown+1.5,first+cooldown+2.0,first+cooldown+4.0,first+cooldown+10.0,first+cooldown+30.0][step]
				w.events.clear(); var native_events := []
				if step < 4:
					var team := maxi(0,int(Defs.SUPPORT[key].team)); team = 1-team if trial == 2 else team
					var peer := -1-team if trial == 1 else 7; var pos := Vector3(step*4.3-8.1,3.7,trial*7.1-10.4); var dir: Vector3 = [Vector3.ZERO,Vector3(1,2,3),Vector3.UP,Vector3(-1,0,2)][step]
					var result: Array = core.request(actors,ledger,random._backend,w.time,peer,team,pos,dir,profile,64,trial == 3); assert(result.size() == 2,"request "+key)
					var ok := true
					if trial == 3: w.rules.demo_support(key,pos,dir)
					else: ok = w.rules.call_support(peer,team,key,pos,dir)
					assert(ok == result[0],"admission "+key); native_events.append_array(result[1])
					if ok: accepted += 1
					else: rejected += 1
				w.rules._support_tick(); var update: Array = core.advance(actors,random._backend,w.time); assert(update.size() == 1); native_events.append_array(update[0])
				var label := "%s/%d/%d" % [key,trial,step]
				assert(native_events == w.events,"events "+label); assert(w.rng.state == random.state,"random "+label)
				assert(core.values() == support_state(w),"support queue "+label); assert(actors.next_id() == w.next_eid,"identities "+label)
				for e: Entity in w.entities.values():
					if e is Structure: assert(structure.restore(actors.actor_state(e.eid))); assert(structure.values() == StructureState.capture(e),"supply "+label)
					else: projectile.snapshot(e,shot); assert(actors.actor_state(e.eid) == shot.checkpoint(),"projectile "+label+"/"+str(e.eid)); shells += 1
				battle.compare_ledger(w.battle,ledger,label)
				for retained in [actors,core,ledger]: assert(retained.restore(retained.checkpoint()))
				count += 1
			w.free()
	assert(accepted > 0 and rejected > 0 and shells > 0,"support coverage")
	battle.free(); projectile.free()
	print("SUPPORT_CALLS passed states=",count," accepted=",accepted," rejected=",rejected); get_tree().quit()
