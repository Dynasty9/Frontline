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
