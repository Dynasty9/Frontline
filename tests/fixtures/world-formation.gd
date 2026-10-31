extends "res://tests/fixtures/world-geometry.gd"

class FormationWorld extends World:
	func _ready() -> void:
		set_process(false); set_physics_process(false)
	func fx_event(_event: Array) -> void: pass

func _ready() -> void:
	MapDims.N = 64; MapDims.SIZE = 64.0; MapDims.HALF = 32.0; MapDims.BIOME = 64; Defs.MAP_HALF = 32.0
	Nav.N = 64; Nav.H = 32.0; HNav.C = 16; HNav.NC = 4; HNav.NCC = 16; HNav._corner = HNav._corners()
	TerrainMap.N = 64; TerrainMap.H = 32.0; TerrainMap.DN = 128
	var placements := 0; var anchors := 0
	for trial in 24:
		var w := FormationWorld.new(); w.srv = true; w.has_view = false
		w.terrain = TerrainMap.new(w); w.water = WaterMap.new(w); w.nav = Nav.new(); w.nav.terrain = w.terrain; w.nav.finalize()
		w.combat = Combat.new(w); w.combat.enable_native_collision(); add_child(w)
		var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
		var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
		var geometry: RefCounted = ClassDB.instantiate("WorldGeometryCore")
		var kinds := ["hesco","trench","crates","house_wall","low_wall","car","rubble","bunker"]
		var blocks := []; var types := PackedByteArray()
		for index in kinds.size():
			var st := Structure.new(); st.world = w; st.srv = true; st.eid = index + 1; st.skind = kinds[index]; st.team = trial % 2
			st.size = Vector3(5.3,1.7,3.1); st.variant = trial % 3; st.built = (trial + index) % 7 != 0
			st.position = Vector3((index % 4) * 5.13 - 8.0,0.0,(index / 4) * 6.79 - 4.0); st.yaw = trial * 0.317; st.rotation.y = st.yaw
			w._register(st); w.add_child(st); st.on_spawned(); w._shash_add(st); w.terrain.structure_changed(st)
			assert(structure.load_state(StructureState.capture(st))); blocks.append(structure.checkpoint()); types.append(1)
		w.terrain.tick(73 if trial % 3 == 0 else 10000); w.combat._sync_collision()
		assert(actors.load_state(1000,types,blocks)); assert(geometry.restore(world_save(w)))
		for step in 64:
			var angle := step * 0.271; var face := Vector3(-sin(angle),0,-cos(angle))
			if step % 13 == 0: face = Vector3.ZERO
			var center := Vector3((step % 7) - 3.17,0,(step % 5) - 2.13)
			if step % 11 == 0: center.x = 30.7
			var count := step % 12; var wide := step % 2 == 0
			var expected := w.terrain.slots(center,face,count,wide)
			var actual: Array = geometry.formation_slots(actors,center,face,count,wide)
			assert(actual == expected,"formation %d/%d expected=%s actual=%s" % [trial,step,expected,actual])
			placements += count
			for slot in actual:
				if not slot[2].is_empty(): anchors += 1
			checks += 1
			if step % 8 == 7:
				var saved: PackedByteArray = geometry.checkpoint(); assert(geometry.restore(saved) and geometry.checkpoint() == saved)
		w.free()
	assert(anchors > 100)
	print("WORLD_FORMATION passed states=",checks," placements=",placements," anchors=",anchors)
	get_tree().quit()
