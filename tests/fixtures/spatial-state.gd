extends "res://tests/fixtures/actors.gd"

func load_actors(w: World, core: RefCounted) -> void:
	var kinds := PackedByteArray()
	var blocks := []
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	for e: Entity in w.entities.values():
		if e.gone:
			continue
		if e is Soldier:
			kinds.append(0)
			blocks.append(soldier_bytes(e))
		elif e is Structure:
			assert(structure.load_state(StructureState.capture(e)))
			kinds.append(1)
			blocks.append(structure.checkpoint())
	assert(core.load_state(1000, kinds, blocks))

func check_ids(expected: Array, actual: Array, label: String) -> void:
	assert(actual.size() == 1, label)
	assert(InfantryState.entity_ids(expected) == actual[0], "%s: %s / %s" % [label, InfantryState.entity_ids(expected), actual])

func _ready() -> void:
	var layout := RandomNumberGenerator.new()
	layout.seed = 37193
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var structures: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var doors: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	checks = 0
	for trial in 64:
		var w := ActorWorld.new()
		w.srv = true
		w.has_view = false
		add_child(w)
		assert(units.load_state(12.0, []))
		assert(structures.load_state(16.0, []))
		assert(doors.load_state(1.5, []))
		var men: Array[Soldier] = []
		var buildings: Array[Structure] = []
		for i in 64:
			var s := make_soldier(w, i + 1, i % 3 - 1)
			s.position = Vector3(layout.randf_range(-60, 60), layout.randf_range(-1, 1), layout.randf_range(-60, 60))
			s.life = i % 6
			men.append(s)
			w.soldiers.append(s)
		for i in 24:
			var s := Mount.new()
			s.eid = 101 + i
			s.world = w
			s.skind = ["floor", "house_wall", "tree"][i % 3]
			s.position = Vector3(layout.randf_range(-40, 40), 0, layout.randf_range(-40, 40))
			s.yaw = layout.randf_range(-PI, PI)
			s.radius = layout.randf_range(0.5, 20.0)
			s.door_shut = s.skind == "house_wall"
			w.entities[s.eid] = s
			w.structures.append(s)
			w.add_child(s)
			w._shash_add(s)
			assert(structures.insert(s.eid, s.position, s.radius))
			if s.door_shut:
				w.add_door(s)
				assert(doors.insert_door(s.eid, s.position))
			buildings.append(s)
		w._rebuild_uhash()
		load_actors(w, actors)
		assert(units.rebuild_units(actors))
		for phase in 4:
			if phase == 1:
				# Queries use current positions but keep the buckets from the beginning of the step.
				for s in men:
					s.position += Vector3(17.3, 0, -9.7)
				var st := buildings[1]
				w._shash_remove(st)
				w.remove_door(st)
				assert(structures.remove(st.eid) and doors.remove(st.eid))
				st.position += Vector3(-21.1, 0, 7.3)
				st.yaw += 0.37
				w._shash_add(st)
				w.add_door(st)
				assert(structures.insert(st.eid, st.position, st.radius) and doors.insert_door(st.eid, st.position))
			if phase == 2:
				men[4].gone = true
				w.soldiers.erase(men[4])
				var st := buildings[2]
				w._shash_remove(st)
				w.structures.erase(st)
				st.gone = true
				assert(structures.remove(st.eid))
			load_actors(w, actors)
			if phase == 3:
				w._rebuild_uhash()
				assert(units.rebuild_units(actors))
			for query in 32:
				var p := Vector3(layout.randf_range(-70, 70), layout.randf_range(-2, 2), layout.randf_range(-70, 70))
				var radius: float = [0.0, 1.0, 4.0, 12.0, 32.0, 100.0][query % 6]
				var enemy := query % 3 - 1
				var label := "%d/%d/%d" % [trial, phase, query]
				check_ids(w.units_near(p, radius, enemy), units.units_near(actors, p, radius, enemy), label + " units")
				check_ids(w.structures_near(p, radius), structures.structures_near(actors, p, radius, false), label + " structures")
				check_ids(w.structures_near(p, radius, true), structures.structures_near(actors, p, radius, true), label + " floors")
				var st := buildings[1 + (query % 8) * 3]
				var to := Basis(Vector3.UP, st.yaw)
				var dp := st.position + to * Vector3(0.3, 0, 0.6)
				var dir := to * (Vector3.FORWARD if query % 2 else Vector3.BACK)
				assert(doors.door_in_way(actors, dp, dir) == InfantryState.entity_id(w.door_in_way(dp, dir)), label + " doors")
				checks += 1
			for spec: Array in [[units, 12.0], [structures, 16.0], [doors, 1.5]]:
				var grid: RefCounted = spec[0]
				var saved: PackedByteArray = grid.checkpoint()
				assert(grid.load_state(float(spec[1]), grid.cells()) and grid.checkpoint() == saved)
				assert(grid.restore(saved) and grid.checkpoint() == saved)
				var bad := saved.duplicate()
				bad[4] = 2
				assert(not grid.restore(bad) and grid.checkpoint() == saved)
				assert(not grid.load_state(0.0, []) and grid.checkpoint() == saved)
		w.free()
	print("SPATIAL_STATE passed cases=%d" % checks)
	get_tree().quit()
