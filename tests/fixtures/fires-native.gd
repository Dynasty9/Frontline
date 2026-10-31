extends "res://tests/fixtures/world-geometry.gd"

class FireWorld extends World:
	func _ready() -> void:
		set_process(false); set_physics_process(false)
	func fx_event(_event: Array) -> void: pass
	func send_msg(_team: int, _kind: String, _text: String, _ping = null) -> void: pass
	func say(_entity: Entity, _text: String) -> void: pass
	func push_props(_entity: Entity, _props: Dictionary) -> void: pass

class Trooper extends Soldier:
	func _ready() -> void:
		set_process(false); set_physics_process(false)

class Wall extends Structure:
	func _ready() -> void:
		set_process(false); set_physics_process(false)

func fire_values(f: Fires) -> Array:
	var burning := []
	for b: Array in f.burning: burning.append([b[0].eid, b[1], b[2]])
	return [burning, f.patches, f.hot, f.smokes, f.wet, f._t, f._beat]

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var soldier: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var ledger: RefCounted = ClassDB.instantiate("BattleStatsCore")
	var deferred: RefCounted = ClassDB.instantiate("DeferredEffectsCore")
	var visibility: RefCounted = ClassDB.instantiate("VisibilityCore")
	var fires: RefCounted = ClassDB.instantiate("FiresCore")
	var random := SimulationRandom.new()
	var compare := preload("res://tests/fixtures/battle-stats.gd").new()
	var infantry := preload("res://tests/fixtures/infantry-update.gd").new()
	var seen := {}
	for trial in 24:
		var w := FireWorld.new(); w.srv = true; w.has_view = false; w.settings = {"rust_infantry": false}
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w)
		w.nav = Nav.new(); w.nav.terrain = w.terrain
		w.combat = Combat.new(w); w.combat.enable_native_collision()
		w.fires = Fires.new(w); w.fires.wet = trial % 3 == 0
		w.battle = BattleStats.new(w); w._deferred_effects = DeferredEffects.new(false)
		w.town_rect = Rect2(-2, -2, 4, 4) if trial % 2 else Rect2()
		add_child(w)
		var initial_battle: RefCounted = ClassDB.instantiate("BattleStatsCore")
		assert(ledger.restore(initial_battle.checkpoint()))
		var initial_deferred: RefCounted = ClassDB.instantiate("DeferredEffectsCore")
		assert(deferred.restore(initial_deferred.checkpoint()))
		var qs: Array[SquadStateCore] = []
		for team in 2:
			var q := Squad.new(); q.world = w; q.sid = team + 1; q.team = team; q.owner = -1 - team; q.kind = "rifle_squad"
			w.squads[q.sid] = q
		var walls: Array[Structure] = []
		for index in Fires.FUEL.size():
			var st := Wall.new(); st.world = w; st.srv = true; st.eid = 100 + index
			st.skind = Fires.FUEL.keys()[index]; st.built = true; st.team = index % 3 - 1; st.owner_peer = -1 - maxi(st.team, 0)
			st.position = Vector3((index % 4) * 4.7 - 7, 0, (index / 4) * 6.1 - 7)
			st.size = Vector3(3, 2, 1); st.foot = Vector2(1.5, 0.5); st.radius = 1.6
			st.yaw = (index % 3) * 0.37; st.max_hp = 100; st.hp = 0.01 if index == trial % 12 else 100
			st.parts = [{"p": Vector3(0, 1, 0), "s": st.size, "r": 0.0, "nav": 3, "veh": 3, "cover": true, "col": true}]
			w.add_child(st); w._register(st); w._shash_add(st); w.nav.add_structure(st); w.terrain.structure_changed(st)
			assert(w.combat._collision.replace_body(st.eid, PackedFloat32Array([st.position.x, 1, st.position.z, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1.5, 1, 0.5, 0])))
			w.combat._collision_bodies[st.eid] = null; walls.append(st)
		for id in range(1, 17):
			var s := Trooper.new(); s.world = w; s.srv = true; s.eid = id; s.team = id % 2; s.owner_peer = -1 - s.team
			s.sname = "Fire test %d" % id; s.utype = "bearer" if id % 7 == 0 else "rifleman"; s.udef = Defs.UNITS[s.utype]
			s.wdef = Defs.WEAPONS.get(s.udef.weapon, {}); s.mag = 7; s.reserve = 23
			s.life = (id + trial) % 6; s.hp = 20 + id; s.bleed = 1.0 + id
			s.position = walls[(id + trial) % 12].position + Vector3(0.7, 0, 0.3)
			s.squad = w.squads[s.team + 1]; s.sid = s.squad.sid; s.squad.members.append(s)
			w.add_child(s); w._register(s)
		w._rebuild_uhash(); w.terrain.tick(4096); w.nav.finalize()
		var types := PackedByteArray(); var blocks := []; var profiles := []
		for e: Entity in w.entities.values():
			if e is Soldier:
				assert(soldier.load_state(InfantryState.capture(e))); types.append(0); blocks.append(soldier.checkpoint())
				profiles.append([e.eid, e.is_bearer(), int(e.wdef.ammo) if not e.wdef.is_empty() else -1, BattleStats.man_value(e), false, 0.0, String(e.udef.get("name", e.utype))])
			else:
				assert(structure.load_state(StructureState.capture(e))); types.append(1); blocks.append(structure.checkpoint())
				profiles.append([e.eid, false, -1, 0.0, e.is_player_building(), float(Defs.BUILDINGS.get(e.skind, {}).get("cost", 0)), ""])
		for q: Squad in w.squads.values():
			var native: SquadStateCore = ClassDB.instantiate("SquadStateCore"); assert(native.load_state(SquadState.capture(q))); qs.append(native)
		assert(actors.load_state(1000, types, blocks)); assert(geometry.restore(world_save(w)))
		assert(units.restore(spatial_save(w._uhash, 12.0))); assert(visibility.restore(w.combat._visibility.checkpoint()))
		assert(fires.configure(64, w.fires.wet))
		assert(fires.bind_state(actors, geometry, units, qs, ledger, deferred, visibility, random._backend, profiles))
		w.rng.seed = 91733 + trial; random.seed = w.rng.seed
		for st in walls:
			if st.eid % 3 == trial % 3 or st.hp < 1:
				w.fires.ignite(st, 0.9); assert(fires.ignite(st.eid, 0.9, 0.0))
		w.fires.start_patch(Vector3(4, 2, 5), 2.5, 15, 0); assert(fires.start_patch(Vector3(4, 2, 5), 2.5, 15, 0))
		for step in 192:
			var label := "%d/%d" % [trial, step]
			var dt: float = [0.1, 0.27, 0.5, 1.1][(step + trial) % 4]; w.time += dt
			if step % 13 == 0:
				var at := Vector3((step % 5) * 3 - 7, [0.0, 1.6, 2.0][trial % 3], 0)
				w.fires.blast(at, 2.7, 11.3); assert(fires.blast(at, 2.7, 11.3, w.time, w.town_rect))
			w.fires.tick(dt); assert(fires.tick(dt, w.time, w.town_rect))
			assert(w.rng.state == random.state, "fire RNG " + label)
			var expected := fire_values(w.fires); var actual: Array = fires.values()
			for group in expected.size(): assert(expected[group] == actual[group], "fire %s group %d: %s / %s" % [label, group, expected[group], actual[group]])
			for st in walls:
				if st.gone:
					seen.destruction = true; assert(actors.actor_state(st.eid).is_empty())
				else:
					assert(structure.restore(actors.actor_state(st.eid)))
					assert(structure.values() == StructureState.capture(st), "fire structure %s/%d" % [label, st.eid])
					if st.burnt: seen.charred = true
			for s: Soldier in w.soldiers:
				assert(soldier.restore(actors.actor_state(s.eid))); infantry.check_state(s, soldier, "fire soldier %s/%d" % [label, s.eid])
			for qcore in qs: assert(qcore.values() == SquadState.capture(w.squads[qcore.values()[0][0]]), "fire squad " + label)
			compare.compare_ledger(w.battle, ledger, "fire ledger " + label)
			assert(visibility.checkpoint() == w.combat._visibility.checkpoint(), "fire visibility " + label)
			assert(deferred.take_rubble() == w._deferred_effects.take_rubble())
			check_geometry(w, geometry, "fire " + label)
			w.terrain.tick(17); assert(geometry.tick_cover(17)); w.combat.finish_tick(); geometry.finish_tick()
			if step % 7 == 0:
				for retained in [actors, geometry, units, ledger, deferred, visibility, fires]:
					var bytes: PackedByteArray = retained.checkpoint(); assert(retained.restore(bytes) and retained.checkpoint() == bytes)
				for qcore in qs: assert(qcore.restore(qcore.checkpoint()))
		for key in w.stats: seen[key] = true
		w.free()
	for key in ["destruction", "charred", "fire_burns", "fire_flee", "killed", "downed", "grass_fire_spread"]: assert(seen.has(key), "unexercised " + key)
	compare.free(); infantry.free()
	print("FIRES_NATIVE passed states=", checks)
	get_tree().quit()
