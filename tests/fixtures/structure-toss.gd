extends "res://tests/fixtures/world-geometry.gd"

class TossWorld extends World:
	func _ready() -> void:
		set_process(false); set_physics_process(false)
	func fx_event(_event: Array) -> void: pass

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64; Defs.MAP_HALF = 32.0
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var thrown := 0
	for trial in 64:
		var w := TossWorld.new(); w.srv = true; w.has_view = false; w.rng.seed = 73241 + trial
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain; w.nav.finalize()
		w.combat = Combat.new(w); w.combat.enable_native_collision(); add_child(w)
		var core: RefCounted = ClassDB.instantiate("WorldGeometryCore")
		var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
		var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
		var random := SimulationRandom.new(); random.seed = 73241 + trial
		assert(core.restore(world_save(w)))
		var st := Structure.new(); st.world = w; st.srv = true; st.eid = 1; st.skind = "car" if trial % 2 == 0 else "crates"
		st.variant = trial % 3; st.yaw = trial * 0.17; st.rotation.y = st.yaw
		if trial % 7 == 0: st.position.x = 26
		assert(structure.load_state(StructureState.capture(st))); assert(core.spawn_structure(actors, structure, PackedFloat64Array()) == 1)
		w._register(st); w.add_child(st); st.on_spawned(); w._shash_add(st); w.terrain.structure_changed(st); w.combat._sync_collision()
		if trial % 4 == 0:
			var block_st := Structure.new(); block_st.world = w; block_st.srv = true; block_st.eid = 2; block_st.skind = "barracks"; block_st.position = Vector3(8,0,0); block_st.size = Vector3(8,3,8)
			assert(structure.load_state(StructureState.capture(block_st))); assert(core.spawn_structure(actors, structure, PackedFloat64Array([9,6,1500])) == 2)
			w._register(block_st); w.add_child(block_st); block_st.on_spawned(); w._shash_add(block_st); w.terrain.structure_changed(block_st); w.combat._sync_collision()
		for step in 16:
			var p := st.position + Vector3(0.0 if step % 3 == 0 else (-1.7 if step % 2 == 0 else 1.7), 0.0, 0.0 if step % 3 == 0 else 0.37)
			var size: float = [0.0,0.3,1.0,1.6,2.3,3.7,8.0,20.0][step % 8]
			st.toss = null
			var result: Array = core.toss_structure(actors,1,p,size,random._backend)
			st.toss_from(p,size)
			assert(not result.is_empty() and result[0] == (st.toss != null), "toss gate %d/%d" % [trial,step])
			if st.toss != null:
				assert(result.slice(1) == st.toss, "toss flight %d/%d" % [trial,step]); thrown += 1
			assert(w.rng.state == random.state, "toss RNG %d/%d" % [trial,step])
			assert(structure.restore(actors.actor_state(1))); assert(structure.values() == StructureState.capture(st), "toss state %d/%d" % [trial,step])
			w.combat._sync_collision()
			check_geometry(w,core,"toss %d/%d" % [trial,step])
			for ray in 24:
				var a := st.position + Vector3(-8, float(ray % 6) * 0.37, (ray / 6) * 2.0 - 3.0)
				var b := st.position + Vector3(8, float(ray % 6) * 0.37, -(ray / 6) * 2.0 + 3.0)
				var hit: PackedFloat64Array = w.combat._collision.ray(a,b,PackedInt64Array())
				assert(core.ray(a,b) == (0 if hit.is_empty() else int(hit[0])), "toss ray %d/%d/%d" % [trial,step,ray])
			if step % 4 == 3:
				w.terrain.tick(43); assert(core.tick_cover(43)); check_geometry(w,core,"repair %d/%d" % [trial,step])
				var saved: PackedByteArray = core.checkpoint(); assert(core.restore(saved) and core.checkpoint() == saved)
		w.free()
	assert(thrown > 100)
	print("STRUCTURE_TOSS passed states=",checks," thrown=",thrown)
	get_tree().quit()
