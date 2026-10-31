extends "res://tests/fixtures/vehicle-loss-world.gd"

class CombatBuilding extends Structure:
	func _complete() -> void:
		super()
		world.work_events.append(["completed",eid,skind])
	func add_work(amount: float) -> bool:
		var was_wrecked := wrecked
		var worked := super(amount)
		if was_wrecked and not wrecked: world.work_events.append(["restored",eid])
		return worked
	func _ready() -> void:
		super(); set_process(false); set_physics_process(false)

class Repairable extends Destructible:
	func repair(amount: float) -> void:
		var broken := track_broken
		super(amount)
		if broken and not track_broken: world.work_events.append(["track",eid])

class CombatDrone extends Drone:
	func _ready() -> void:
		set_process(false); set_physics_process(false)

class ShotWorld extends FireWorld:
	var bullet_fx: Array = []
	var work_events: Array = []
	var cries: Array = []
	var spoken: Array = []
	func say(entity: Entity, text: String) -> void:
		var cue := ["MEDIC!", "I'm hit! Medic!", "Help me!", "Medic! Over here!", "Argh! I'm hit!", "Somebody help!"].find(text)
		if cue >= 0: cries.append([entity.eid,cue])
		if text != "Man down!" and not text.ends_with(" is hit!") and text != "We've got wounded!" and not (text.begins_with("Medic! ") and text.ends_with(" is down!")):
			spoken.append([entity.eid,text])
	func fx_event(event: Array) -> void:
		if event[0] == Fx.SHOT: bullet_fx.append(["shot",event[1],event[2],event[3],event[4],event[5]])
		elif event[0] == Fx.RICOCHET: bullet_fx.append(["ricochet",event[1],event[2]])
		elif event[0] == Fx.SOUND and event[1] == "build": work_events.append(["sound",event[2]])

func _ready() -> void:
	run(0)

func blast_ledger_equal(expected: Array, actual: Array) -> bool:
	if expected.size() != actual.size(): return false
	var normalized := expected.duplicate(true)
	# Godot's power function can round blast damage one ulp from the pinned Rust math.
	for group in [0,1]:
		if expected[group].size() != actual[group].size(): return false
		for row in expected[group].size():
			var a: PackedFloat64Array = expected[group][row][4] if group == 0 else expected[group][row]
			var b: PackedFloat64Array = actual[group][row][4] if group == 0 else actual[group][row]
			if a.size() != b.size() or not is_finite(a[11]) or not is_finite(b[11]) or absf(a[11] - b[11]) > 1e-10: return false
			a[11] = b[11]
			if group == 0: normalized[group][row][4] = a
			else: normalized[group][row] = a
	return normalized == actual

func run(mode: int) -> void:
	var shoot := mode == 1
	var wounded := mode == 2
	var fighting := mode == 3
	var breaching := mode == 4
	var building := mode == 5
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64; Defs.MAP_HALF = 32.0
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var combat: RefCounted = ClassDB.instantiate("VehicleLossWorldCore")
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var soldier: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore")
	var deferred: RefCounted = ClassDB.instantiate("DeferredEffectsCore")
	var visibility: RefCounted = ClassDB.instantiate("VisibilityCore")
	var fires: RefCounted = ClassDB.instantiate("FiresCore")
	var network: RefCounted = ClassDB.instantiate("SupplyNetworkCore")
	var random := SimulationRandom.new()
	var compare := preload("res://tests/fixtures/battle-stats.gd").new()
	var infantry := preload("res://tests/fixtures/infantry-blast.gd").new()
	var birth := preload("res://tests/fixtures/vehicle-loss.gd").new()
	var actor_compare := preload("res://tests/fixtures/actors.gd").new()
	var firing := preload("res://tests/fixtures/infantry-fire.gd").new()
	var weapons := []
	for key: String in Defs.WEAPONS:
		var weapon: Dictionary = Defs.WEAPONS[key]
		if not weapon.has("burst"): continue
		var burst: Vector2i = weapon.burst
		weapons.append([key,PackedFloat64Array([weapon.ammo,weapon.get("mag",30),weapon.get("reload",2.0),burst.x,burst.y,weapon.acc,weapon.range,weapon.dmg,int(weapon.get("aa",false)),Cover.pen_class(weapon),0.08 if weapon.snd == "hmg" else 0.045 if weapon.snd == "mg" else 0.03,weapon.get("he",-1.0),int(weapon.get("airburst",false)),weapon.interval,weapon.supp,int(weapon.get("ap",false))]),String(weapon.snd)])
	var seen := {}
	for trial in 64:
		var w := ShotWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry":false}
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.combat = Combat.new(w); w.combat.enable_native_collision(); w.fires = Fires.new(w)
		w.rules = Rules.new(w); w.rules.upgrades = [{},{}]; w.battle = BattleStats.new(w); w._deferred_effects = DeferredEffects.new(false)
		if shoot and trial % 3 == 0: w.rules.upgrades = [{"optics":true},{"optics":true}]
		if fighting and trial % 3 == 0: w.rules.upgrades = [{"optics":true},{"optics":true}]
		if wounded and trial % 3 < 2:
			var key := "medicine" if trial % 3 == 0 else "optics"
			w.rules.upgrades[0][key] = true; w.rules.upgrades[1][key] = true
		w.time = 100.0; w.next_eid = 1000; w.next_sid = 7; add_child(w)
		for pair in [[ledger,"BattleStatsCore"],[deferred,"DeferredEffectsCore"]]:
			var empty: RefCounted = ClassDB.instantiate(pair[1]); assert(pair[0].restore(empty.checkpoint()))
		for side in 2:
			var q := Squad.new(); q.world = w; q.sid = side + 1; q.team = side; q.owner = 7 + side; q.kind = "rifle_squad"; w.squads[q.sid] = q
		for id in range(1,13):
			var s := Trooper.new(); s.world = w; s.srv = true; s.eid = id; s.team = id % 2; s.owner_peer = 7 + s.team
			s.utype = "rifleman"; s.udef = Defs.UNITS[s.utype]; s.wdef = Defs.WEAPONS[s.udef.weapon]; s.sname = "Combat %d" % id
			s.position = Vector3((id % 4) * 3.1 - 4.2,0,(id / 4) * 2.3 - 3.7); s.posture = id % 3
			s.hp = 20.0 if trial % 5 == 0 else 100.0; s.times_downed = trial % 4; s.mag = 7; s.reserve = 23
			s.squad = w.squads[s.team + 1]; s.sid = s.squad.sid; s.squad.members.append(s)
			w.add_child(s); w._register(s)
		for index in 2:
			var v := Repairable.new(); v.world = w; v.srv = true; v.eid = 40 + index; v.team = index; v.owner_peer = 7 + index
			v.vkind = ["truck","tank","rhib","heli"][(trial + index) % 4]
			v.vdef = Defs.VEHICLES[v.vkind]; v.max_hp = v.vdef.hp; v.hp = v.max_hp
			v.position = Vector3(-3 + index * 7,0,-3); v.rotation.y = trial * 0.137
			w.add_child(v); w._register(v); v.on_spawned(); w.combat.dirty_collision(v.eid)
			if shoot: v.hp = 2.0 if trial % 3 == 0 else 40.0
			var passenger: Soldier = w.entities[index + 1]; passenger.riding = v; passenger.life = Soldier.Life.HIDDEN; v.passengers.append(passenger)
		var kinds := ["depot","fob","fob","town","house_wall","ammo_cache","tree","car","crates","wire","camo_net","tunnel","mg_nest","barracks"]
		if fighting and trial % 8 in [3,4]: kinds.append("low_wall")
		if breaching: kinds.append_array(["floor","house_wall"])
		if building: kinds.append(["fob","medic_tent","sandbags","camo_net","barracks","concrete_wall","research","wire"][trial / 8])
		for index in kinds.size():
			var st := CombatBuilding.new(); st.world = w; st.srv = true; st.eid = 100 + index; st.skind = kinds[index]
			st.team = 0 if index < 4 or index > 10 else -1; st.owner_peer = 7 if st.team == 0 else 0
			st.position = [Vector3(-24,0,-20),Vector3(-10,0,0),Vector3(9,0,0),Vector3(24,0,20)][index] if index < 4 else Vector3((index % 4) * 2.9 - 3.7,0,(index / 4) * 2.1 - 3)
			st.yaw = (trial % 7) * 0.137; st.rotation.y = st.yaw; st.sname = "Combat base %d" % index
			st.completed_order = index; st.supply = 120.0; st.door_shut = index == 4; st.variant = 2 if index == 4 else trial % 2
			if index == 4: st.size = Vector3(7.3,2.3,1.0)
			if fighting and index == 14: st.position = Vector3(14,0,-18); st.yaw = 0.0; st.rotation.y = 0.0; st.size = Vector3(7.2,0.8,0.35)
			if breaching and index >= 14:
				st.position = Vector3(16,0,-18 if index == 14 else -14); st.yaw = 0.0; st.rotation.y = 0.0
				st.size = Vector3(8,0.1,8) if index == 14 else Vector3(8,2.3,0.35)
				st.variant = 0 if index == 14 else 2; st.door_shut = index == 15 and trial % 2 == 0
			if building and index == 14:
				st.position = Vector3(16,0,-18); st.built = trial % 8 == 3
				st.progress = 1.0 if st.built else 1.0 - 0.05 / float(Defs.BUILDINGS.get(st.skind,{}).get("time",10.0))
			w.add_child(st); w._register(st); st.on_spawned(); w._shash_add(st); w.terrain.structure_changed(st); w.combat.dirty_collision(st.eid)
			if index > 0: st.hp = minf(st.hp,90.0 if trial % 2 else 500.0)
			if index == 0: w.rules.depots[0] = st
			if index == 3: w.rules.town_list.append(st)
		var dr := CombatDrone.new(); dr.world = w; dr.srv = true; dr.eid = 60; dr.team = 1; dr.position = Vector3(1,1,0); dr.operator = w.entities[5]
		w.add_child(dr); w._register(dr); dr.on_spawned()
		w._rebuild_uhash(); w.terrain.tick(100000); w.nav.finalize(); w.combat._sync_collision()
		if wounded:
			var s: Soldier = w.entities[3]; var carrier: Soldier = w.entities[4]
			s.life = Soldier.Life.DOWNED; s.hp = 0.0; s.posture = Soldier.Post.PRONE; s.downed_t = 90.0
			s.bleed_max = 50.0; s.bleed = 0.001 if trial % 4 == 0 else 35.0
			s.scream_t = 0.0; s.pistol_t = 0.0; s.crawl_t = 0.0
			if trial % 8 in [1,5]:
				s.carried_by = [carrier]
				if trial % 8 == 5: carrier.life = Soldier.Life.DEAD; carrier.hp = 0.0
			if trial % 8 in [2,6]:
				s.dragged_by = carrier; carrier.task = "rescue" if trial % 8 == 2 else "fight"; carrier.task_ent = s
			if trial % 8 == 3:
				s.goal_kind = "crawl"; s.goal = s.position + Vector3(-2,0,3)
				s.path = PackedVector3Array([s.position,s.goal]); s.path_i = 1
			w._rebuild_uhash()
		if fighting:
			var s: Soldier = w.entities[3]
			s.position = Vector3(14,0,-18); w.entities[4].position = Vector3(14,0,-8)
			w.entities[5].position = Vector3(12,0,-19); w.entities[7].position = Vector3(12,0,-20)
			s.target = w.entities[4]; s.vis_targets = [s.target]; s.last_shot_t = -10.0
			s.wdef = Defs.WEAPONS[["rifle","smg","lmg","ak"][(trial >> 3) % 4]]
			s.mag = trial % 9; s.reserve = 23; s.stamina = 0.2 + 0.1 * (trial % 8)
			s.suppression = [0.0,24.0,65.0,91.0][trial % 4]
			s._sep = Vector3(0.1,0,-0.2) if trial % 3 == 0 else Vector3.ZERO
			if trial % 8 in [1,2]:
				s.goal_kind = "slot"; s.goal = s.position + Vector3(-4,0,3)
				s.path = PackedVector3Array([s.position,s.goal]); s.path_i = 1; s.move_mode = trial % 3
			elif trial % 8 in [3,4]:
				var wall: Structure = w.entities[114]
				s.cover_st = wall; s.cover_ai = 0; s.position = wall.anc_p[0]; s.cover_pos = s.position
				s.at_cover = true; s.cover_type = Soldier.Cov.LOW; s.cover_h = wall.anc_h[0]; s.cover_mat = Cover.anchor_mat(wall,0)
				s.cover_n = wall.anc_n[0]; s.cover_threat = s.cover_n; s.target.position = s.position + s.cover_n * 9.0
				s.suppression = 42.0; s.mag = 30; s.reserve = 0
				s.peek_up = true; s.peek_t = 0.2; s._peek_from = 98.0; s._up_supp = 0.0
			elif trial % 8 in [5,6]:
				s.task = "escort"; s.task_ent = w.entities[7]; s.task_ent2 = w.entities[5]
				s.task_ent2.task = "rescue" if trial % 8 == 5 else ""; s.task_ent2.task_ent = s.task_ent
			elif trial % 8 == 7:
				s.target = null; s.vis_targets.clear(); s.suppression = 0.0; s.calm_t = 12.0
			w._rebuild_uhash()
		if breaching:
			var s: Soldier = w.entities[3]; var wall: Structure = w.entities[115]; var house: Structure = w.entities[114]
			var c := Vector3(16,0,-14); var n := Vector3.BACK
			s.task = "breach"; s.task_ent = wall; s.task_ent2 = w.entities[4]; s.task_phase = trial % 5
			s.task_t = 40.0 if trial % 11 == 0 else 99.0; s.bt_wait = 99.0
			s.bt_house = house; s.bt_door = [wall,c,n,true]; s.bt_clear = trial % 3 == 0; s.bt_nofrag = trial % 7 == 0
			s.bt_reordered = trial % 13 == 0; s.bt_cook_t0 = 99.0 if trial % 4 == 0 else -1.0
			s.task_pos = c + Vector3(1.55,0,0.5); s.task_pos2 = c + n * 0.8
			s.position = s.task_pos2 if s.task_phase == 2 else s.task_pos
			if s.task_phase == 0 and trial % 2 == 0: s.position += Vector3(1.7,0,0)
			s.frags = 1; s.mag = 7; s.reserve = 23; s.last_shot_t = -10.0
			s.target = w.entities[4]; s.target.position = Vector3(16,0,-18); s.vis_targets = [s.target]
			s.squad.breach_by = s; s.squad.known[s.target.eid] = {"e":s.target,"pos":s.target.position,"t":99.0}
			if s.task_phase == 3 and trial % 2 == 0:
				var grenade := Projectile.new(); grenade.eid = 90; grenade.gone = true; w.add_child(grenade); grenade.set_process(false); grenade.set_physics_process(false)
				s.bt_breach_g = grenade; s.position = c + n
			w._rebuild_uhash()
		if building:
			var s: Soldier = w.entities[3]
			s.task = "build"; s.task_ent = w.entities[114]; s.udef = s.udef.duplicate(); s.udef.build = 3.4
			if trial % 8 == 1:
				s.task_ent = w.entities[101]; s.task_ent.wrecked = true; s.task_ent.hp = s.task_ent.max_hp * 0.4995
				s.task_ent.burn = 0.6; s.task_ent.fuel = 90.0; s.task_ent.fuel_max = 90.0
			elif trial % 8 == 2:
				s.task_ent = w.entities[40]; s.task_ent.hp = s.task_ent.max_hp * 0.9
				s.task_ent.track_broken = true; s.task_ent.track_fix = 5.95
			elif trial % 8 == 3:
				s.task_ent.hp = s.task_ent.max_hp
				if trial % 16 == 3: w.entities[5].task = "build"; w.entities[5].task_ent = s.task_ent
			s.position = s.task_ent.position + Vector3(0.4,0,3.0); s.task_pos = s.position
			s.squad.build_target = s.task_ent; s.squad.order = "build"
			if trial % 8 in [4,5]:
				s.target = w.entities[4]; s.target.position = s.position + Vector3(0,0,9.0)
				s.vis_targets = [s.target]; s.last_shot_t = -10.0
				s.suppression = 65.0 if trial % 8 == 4 else 0.0
			elif trial % 8 in [6,7]:
				s.task_pos += Vector3(4,0,0)
				if trial % 8 == 7:
					s.goal_kind = "task"; s.goal = s.task_pos; s.path = PackedVector3Array([s.position,s.goal]); s.path_i = 1
			w._rebuild_uhash(); w.combat._sync_collision()
		var types := PackedByteArray(); var blocks := []; var vehicles := []; var men := []; var buildings := []
		for e: Entity in w.entities.values():
			if e is Soldier:
				assert(soldier.load_state(InfantryState.capture(e)),"initial soldier %d/%d" % [trial,e.eid]); types.append(0); blocks.append(soldier.checkpoint())
			elif e is Vehicle:
				assert(vehicle.load_state(VehicleState.capture(e))); types.append(2); blocks.append(vehicle.checkpoint())
				vehicles.append([e.eid,e.display_name(),e.base(),e.is_heli(),e.is_auto(),int(e.vdef.get("crew",-1)),float(e.vdef.get("cost",0)),false,false,e.weight(),e._hull_size(),int(e.vdef.armor),float(e._toss_class()[0]),e.hit_factor()])
			elif e is Drone:
				types.append(4); blocks.append(actor_compare.drone_bytes(e,actors))
			else:
				assert(structure.load_state(StructureState.capture(e))); types.append(1); blocks.append(structure.checkpoint())
		for kind in ["rifleman","crewman","r_crewman"]:
			var d: Dictionary = Defs.UNITS[kind]; var weapon: Dictionary = Defs.WEAPONS.get(d.weapon,{})
			men.append([kind,bool(d.get("bearer",false)),int(weapon.get("ammo",-1)),BattleStats.man_value(w.entities[1]) if kind == "rifleman" else BattleStats.MAN_VALUE,float(weapon.get("range",-1)),String(d.name)])
		for kind in Defs.BUILDINGS: buildings.append([kind,true,float(Defs.BUILDINGS[kind].get("cost",0))])
		assert(actors.load_state(w.next_eid,types,blocks)); assert(geometry.restore(world_save(w))); assert(units.restore(spatial_save(w._uhash,12.0)))
		assert(visibility.restore(w.combat._visibility.checkpoint())); assert(fires.configure(64,false))
		assert(network.load_state(PackedInt64Array([100,0]),PackedInt64Array([103]),w.rules.fob_order,w.roads,w._painted_roads))
		w.rng.seed = 7317 + trial; random.seed = w.rng.seed
		var qs: Array[SquadStateCore] = []
		for q: Squad in w.squads.values():
			var qc: SquadStateCore = ClassDB.instantiate("SquadStateCore"); assert(qc.load_state(SquadState.capture(q))); qs.append(qc)
		var impacts := []
		var chat := PackedFloat64Array(w.last_chat)
		var next: int = w.next_sid
		var initial: RefCounted = ClassDB.instantiate("VehicleLossWorldCore")
		assert(combat.gunfire_restore(initial.gunfire_checkpoint()))
		for step in (12 if shoot or wounded or fighting or breaching or building else 3):
			if wounded and w.entities[3].life != Soldier.Life.DOWNED: break
			if breaching and (w.entities[3].task != "breach" or w.entities[3].act_t > 0.0): break
			if building and w.entities[3].task != "build": break
			var dt: float = [0.05,0.1,0.25,0.5][trial % 4]
			if wounded or fighting or breaching or building: w.time += dt
			elif shoot: w.time += 0.17
			elif step == 2: w.time += 1.6
			var config := [next,w.time,w.town_rect,[PackedStringArray(Defs.NAMES[0]),PackedStringArray(Defs.NAMES[1])],[birth.loadout("crewman"),birth.loadout("r_crewman")],vehicles,men,buildings]
			var p: Vector3 = [Vector3.ZERO,Vector3(-10,0,0),Vector3(9,0,0),Vector3(3,2,0)][trial % 4]
			var source: Entity = w.entities[5] if step == 0 else null
			var data := {"radius":12.0,"fling":8.0,"size":[0.55,1.0,2.7,6.0][trial % 4],"at":120.0 if trial % 3 == 0 else 0.0,"top":trial % 2 == 0,"src":source,"by":8,"team":1}
			if trial % 5: data.dmg = 180.0 if step == 0 else 1200.0
			var input := [p,data.get("dmg"),data.radius,data.fling,data.size,data.at,0.3,data.top,null,1.0,1.0,InfantryState.entity_id(source),8,1]
			var result: Array
			if fighting or breaching or building:
				var s: Soldier = w.entities[3]
				var fighting_input := [s.eid,dt,weapons,firing.gun_profile(s.mounted) if s.mounted else PackedFloat64Array(),chat,w.rules.has_upgrade(s.team,"optics")]
				if building:
					var duration = Defs.BUILDINGS.get(s.task_ent.skind,{}).get("time") if s.task_ent is Structure else null
					fighting_input.append_array([float(s.udef.get("build",1.0)),duration])
					result = combat.advance_build(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,fighting_input,network,impacts)
				else: result = combat.advance_breach(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,fighting_input,network,impacts) if breaching else combat.advance_fighting(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,fighting_input,network,impacts)
				assert(result.size() == (8 if building else 7),"fighting result %d/%d" % [trial,step])
				w.bullet_fx.clear(); w.spoken.clear(); w.work_events.clear()
				if building: s._build_tick(dt)
				elif breaching: SoldierBrain.breach_tick(s,dt)
				elif s.task == "escort": s._escort_tick(dt)
				else: s._fight_tick_work(dt)
				assert(result[4] == w.bullet_fx,"fighting bullet effects %d/%d" % [trial,step])
				assert(result[5] == w.spoken,"fighting speech %d/%d: %s / %s" % [trial,step,result[5],w.spoken])
				if building:
					assert(result[7] == w.work_events,"construction effects %d/%d: %s / %s" % [trial,step,result[7],w.work_events])
					for event: Array in result[7]: seen[event[0]] = true
				chat = result[6]; assert(chat == PackedFloat64Array(w.last_chat),"fighting chat %d/%d" % [trial,step])
				assert(combat.gunfire_reveals() == w.combat._reveal,"fighting reveal %d/%d" % [trial,step])
				assert(combat.gunfire_restore(combat.gunfire_checkpoint()))
				if not w.bullet_fx.is_empty(): seen.shot = true
				if s.reload_t > 0.0: seen.reload = true
				if s.task == "escort": seen.escort = true
				if s.idle_act != 0: seen.idle = true
			elif wounded:
				var s: Soldier = w.entities[3]
				result = combat.advance_wounded(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,[s.eid,dt,w.rules.has_upgrade(s.team,"medicine"),w.rules.has_upgrade(s.team,"optics")],network,impacts)
				assert(result.size() == 6,"wounded result %d/%d" % [trial,step])
				w.bullet_fx.clear(); w.cries.clear(); s._downed(dt)
				assert(result[4] == w.bullet_fx,"wounded bullet effects %d/%d" % [trial,step])
				assert(result[5] == w.cries,"wounded cries %d/%d" % [trial,step])
				assert(combat.gunfire_reveals() == w.combat._reveal,"wounded reveal %d/%d" % [trial,step])
				assert(combat.gunfire_restore(combat.gunfire_checkpoint()))
			elif shoot:
				var shooter: Entity = w.entity([5,40,104][step % 3]); shooter = shooter if shooter else w.entity(5)
				var target: Entity = w.entity([6,3,40,41,60,104,105,0][(step + trial) % 8])
				var weapon: Dictionary = Defs.WEAPONS[["rifle","m2","chaingun","zu23","bushmaster","gmg"][(trial + step) % 6]]
				var muzzle := shooter.center_point() if step % 2 else Vector3(-15,1.3,-4)
				var aim := target.center_point() if target else Vector3(5,0,5)
				var accuracy := 8.0 if step % 3 == 0 else 0.7
				var values := PackedFloat64Array([weapon.acc,weapon.range,weapon.dmg,int(weapon.get("aa",false)),Cover.pen_class(weapon),0.08 if weapon.snd == "hmg" else 0.045 if weapon.snd == "mg" else 0.03,weapon.get("he",-1.0),int(weapon.get("airburst",false)),accuracy,int(w.rules.has_upgrade(shooter.team,"optics")),int(weapon.get("ap",false)),weapon.supp])
				result = combat.fire_bullet(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,[shooter.eid,InfantryState.entity_id(target),muzzle,aim,values,String(weapon.snd)],network,impacts)
				assert(result.size() == 5,"bullet result %d/%d" % [trial,step])
				w.bullet_fx.clear(); w.combat._fire_bullet_reference(shooter,muzzle,aim,target,weapon,accuracy)
				assert(result[4] == w.bullet_fx,"bullet effects %d/%d" % [trial,step])
				assert(combat.gunfire_reveals() == w.combat._reveal,"bullet reveal %d/%d" % [trial,step])
				assert(combat.gunfire_restore(combat.gunfire_checkpoint()))
			else:
				result = combat.explode(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,input,network,impacts) if step < 2 else combat.flush_deferred(actors,geometry,units,qs,fires,ledger,deferred,visibility,random._backend,config,network,impacts)
			var label := "blast %d/%d" % [trial,step]
			assert(result.size() == (8 if building else 7 if fighting or breaching else 6 if wounded else 5 if shoot else 4),"combat result " + label)
			if mode == 0:
				if step < 2: w.combat.explode(p,data)
				else: w._run_deferred_effects()
			w.combat._sync_collision()
			assert(w.rng.state == random.state,"explosion RNG " + label + ": %d / %d" % [w.rng.state,random.state])
			var identities := PackedInt64Array()
			for e: Entity in w.entities.values(): identities.append(e.eid); identities.append(0 if e is Soldier else 1 if e is Structure else 2 if e is Vehicle else 4)
			assert(actors.identities() == identities and actors.next_id() == w.next_eid,"explosion registry " + label)
			next = result[0]; impacts = result[3]; qs.clear()
			assert(w.next_sid == next and w.squads.size() == result[1].size(),"explosion squad births " + label)
			assert(impacts == w.recent_impacts,"explosion impacts " + label)
			for bytes: PackedByteArray in result[1]:
				var qc: SquadStateCore = ClassDB.instantiate("SquadStateCore"); assert(qc.restore(bytes)); qs.append(qc)
				assert(qc.values() == SquadState.capture(w.squads[qc.values()[0][0]]),"explosion squad " + label)
			for e: Entity in w.entities.values():
				if e is Soldier:
					infantry.check_blast_actor(e,actors,label + "/%d" % e.eid)
				elif e is Vehicle:
					assert(vehicle.restore(actors.actor_state(e.eid))); assert(vehicle.values() == VehicleState.capture(e),"explosion vehicle " + label)
				elif e is Drone: actor_compare.compare_drone(e,actors,label)
				else:
					assert(structure.restore(actors.actor_state(e.eid))); assert(structure.values() == StructureState.capture(e),"explosion structure %s/%d" % [label,e.eid])
			assert(blast_ledger_equal(compare.ledger(w.battle),ledger.values()),"combat ledger " + label)
			if trial == 0 and step == 0:
				var wrong: Array = ledger.values(); var counters: PackedFloat64Array = wrong[1][0]
				counters[11] += 1e-8; wrong[1][0] = counters
				assert(not blast_ledger_equal(compare.ledger(w.battle),wrong),"ledger must reject changed damage")
				wrong = ledger.values(); counters = wrong[1][0]; counters[9] += 1; wrong[1][0] = counters
				assert(not blast_ledger_equal(compare.ledger(w.battle),wrong),"ledger must reject changed shot counts")
			assert(fires.values() == fire_values(w.fires),"explosion fires " + label)
			assert(network.values() == [PackedInt64Array([100,0]),PackedInt64Array([103]),w.rules.fob_order,w.roads,w._painted_roads],"explosion network " + label)
			if mode == 0 and step == 2: assert(deferred.take_rubble() == w._deferred_effects.take_rubble(),"explosion rubble " + label)
			var pending: Array = deferred.pending(); assert(pending.size() == w._deferred_effects._pending.size(),"explosion deferred " + label)
			for i in pending.size():
				var e: Array = w._deferred_effects._pending[i]; var d: Dictionary = e[3]
				assert(e[0] == pending[i][0] and e[1] == pending[i][1] and e[2] == pending[i][2][0][1],"explosion deadline " + label)
				assert(pending[i][2][0][2] == PackedFloat64Array([d.dmg,d.radius,d.fling,d.get("at",0.0),0.3,d.size,1.0]),"explosion delayed blast " + label)
			check_geometry(w,geometry,label)
			for key: String in result[2]: seen[key] = true
			for retained in [actors,geometry,units,ledger,deferred,visibility,fires,network]: assert(retained.restore(retained.checkpoint()))
			w.combat.finish_tick(); geometry.finish_tick(); check_geometry(w,geometry,label + " end")
		w.free()
	for key in (["completed","restored","track","sound","fob_built"] if building else ["breach_door_kick","breach_frag_in","room_entry"] if breaching else ["shot","reload","escort","idle","shift_along"] if fighting else ["killed","pistol_while_down","crawl_to_cover"] if wounded else ["penetration","through_hit","ricochet","vehicle_destroyed","drone_shot_down"] if shoot else ["vehicle_destroyed","drone_shot_down","door_kicked","cache_cook_off","at_hit"]): assert(seen.has(key),"unexercised combat " + key)
	compare.free(); infantry.free(); birth.free(); actor_compare.free(); firing.free()
	print("BUILD_WORLD passed states=" if building else "BREACH_WORLD passed states=" if breaching else "FIGHTING_WORLD passed states=" if fighting else "WOUNDED_WORLD passed states=" if wounded else "BULLET_WORLD passed states=" if shoot else "WORLD_COMBAT passed states=",checks)
	get_tree().quit()
