extends Node
## Exercise building lifecycle changes that must not make the index stale.

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	var w := World.new()
	w.has_view = false
	for kind in ["structure", "soldier", "vehicle", "projectile", "drone"]:
		var entity := w._make(kind)
		entity.world = w
		add_child(entity)
		check(not entity.is_processing(), "Headless entities must not run view callbacks: " + kind)
		entity.free()
	var floor_a := add_structure(w, "floor", -1)
	var scenery := add_structure(w, "tree", -1)
	w._shash_add(scenery)
	var floor_b := add_structure(w, "floor", -1)
	floor_a.radius = 12.0
	floor_b.position = Vector3(10, 0, 5)
	floor_b.radius = 6.0
	for st in [floor_a, floor_b]:
		w._shash_add(st)
	for x in range(-20, 21, 5):
		for z in range(-20, 21, 5):
			var pos := Vector3(x, 0, z)
			var expected := w.structures_near(pos, 9.0).filter(func(st): return st.skind == "floor")
			check(w.structures_near(pos, 9.0, true) == expected, "House queries must preserve spatial filtering and candidate order")
	w.despawn(floor_a)
	check(not floor_a in w.structures_near(Vector3.ZERO, 20.0, true), "Despawn must remove the house index entry")
	w._shash_remove(floor_b)
	floor_b.position = Vector3(150, 0, 150)
	w._shash_add(floor_b)
	check(w.structures_near(Vector3.ZERO, 20.0, true).is_empty() and w.structures_near(floor_b.position, 9.0, true) == [floor_b], "Relocated houses must leave their old cells")
	w.despawn(floor_b)
	check(w._house_hash.is_empty(), "Removing the last house must clear empty buckets")
	w.despawn(scenery)
	var rules := Rules.new(w)
	for i in 1000:
		add_structure(w, "tree", -1)
	var town := add_structure(w, "town", -1)
	var fob := add_structure(w, "fob", 0)
	fob.built = false
	check(w.sim_structures.size() == 2, "Scenery must not enter the building tick list")
	check(rules.fobs(0).is_empty(), "An unfinished FOB must not supply capacity")
	fob.built = true
	check(rules.cap(0) == Defs.BASE_CAP + Defs.CAP_PER_FOB, "Completion must immediately supply capacity")
	var start := Time.get_ticks_usec()
	for i in 1000:
		var old := []
		for st in w.structures:
			if st.skind == "fob" and st.team == 0 and st.built:
				old.append(st)
		check(old == [fob], "Reference scan must find the same FOB")
	var scan_usec := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	for i in 1000:
		check(rules.fobs(0) == [fob], "Indexed scan must find the same FOB")
	print("FOB_LOOKUP_BENCH scenery=1000 calls=1000 before_ms=%.2f after_ms=%.2f" % [scan_usec / 1000.0, (Time.get_ticks_usec() - start) / 1000.0])
	fob.team = 1
	check(rules.fobs(0).is_empty() and rules.fobs(1) == [fob], "Capture must immediately transfer the FOB")
	fob.wrecked = true
	check(rules.fobs(1) == [fob] and rules.fobs(1, false).is_empty(), "Wreck filtering must remain live")
	check(w.owned_structures == [fob], "Neutral scenery must not enter the owned-building index")
	town.team = 0
	check(town in w.owned_structures, "Capture must immediately add a neutral building to owned queries")
	town.team = -1
	check(not town in w.owned_structures, "Neutralisation must remove a building from owned queries")
	town.team = 0
	check(town in w.sim_structures, "A captured neutral town must still tick")
	w.despawn(fob)
	check(not fob in w.owned_structures, "Despawn must remove the owned-building entry")
	check(w.fob_structures.is_empty() and not fob in w.sim_structures, "Despawn must remove both indexes")
	await get_tree().process_frame
	w._exit_tree()
	w.free()
	check_nav_dirty()
	print("STRUCTURE_INDEX_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)


func add_structure(w: World, kind: String, side: int) -> Structure:
	var st := Structure.new()
	st.world = w
	st.eid = w.entities.size() + 1
	st.skind = kind
	st.team = side
	w._register(st)
	w.add_child(st)
	return st


func check_nav_dirty() -> void:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, MapDims.N, MapDims.N)
	grid.update()
	var nav := HNav.new(grid, false)
	# Only exercise invalidation; graph construction is covered by game runs.
	nav.built = true
	var cell := Vector2i(20, 20)
	var cluster := nav.cluster_of(cell)
	nav.mark_dirty(cell)
	check(nav.dirty.is_empty(), "Unchanged terrain must not schedule a rebuild")
	grid.set_point_weight_scale(cell, 2.0)
	nav.mark_dirty(cell)
	check(nav.dirty.has(cluster), "Movement cost changes must schedule a rebuild")
	nav.mark_dirty(cell)
	check(nav.dirty.has(cluster), "An unchanged notification must not discard pending work")
	nav.dirty.clear()
	grid.set_point_solid(cell, true)
	nav.mark_dirty(cell)
	check(nav.dirty.has(cluster), "Blocked cells must schedule a rebuild")
	nav.dirty.clear()
	grid.set_point_solid(cell, false)
	nav.mark_dirty(cell)
	check(nav.dirty.has(cluster), "Reopened cells must schedule a rebuild")
