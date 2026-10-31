extends Node


func _ready() -> void:
	assert(ClassDB.class_exists("HierarchyCore"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 82743
	var queries := 0
	for trial in 8:
		MapDims.N = 128 if trial >= 6 else (64 if trial < 3 else 96)
		HNav.C = 32 if trial >= 6 else 16
		HNav.NC = MapDims.N / HNav.C
		var grid := NavRaster.new(MapDims.N)
		var reference := HNav.new(grid, false, false)
		var core: RefCounted = ClassDB.instantiate("HierarchyCore")
		assert(core.configure(MapDims.N, HNav.C))
		for z in MapDims.N:
			for x in MapDims.N:
				var cell := Vector2i(x, z)
				var blocked := rng.randf() < 0.08 if trial % 3 else false
				var weight: float = [0.3, 0.95, 1.0, 1.4, 2.5][rng.randi() % 5] if trial % 3 else 1.0
				grid.set_point_solid(cell, blocked)
				grid.set_point_weight_scale(cell, weight)
				reference.mark_dirty(cell)
		assert(core.load_cells(grid.solid, grid.weight))
		reference.build()
		assert(core.build())
		var dangers := PackedFloat32Array()
		dangers.resize(HNav.NC * HNav.NC)
		for edit in 30:
			if edit % 5 == 0:
				var checkpoint: PackedByteArray = core.checkpoint()
				assert(core.restore(checkpoint))
				var bad := checkpoint.duplicate()
				bad[4] = 2
				assert(not core.restore(bad))
				assert(core.checkpoint() == checkpoint)
			assert(core.counts() == Vector2i(reference.node_cell.size(), reference.graphs[0].get_point_count()), "Hierarchy counts trial=%d edit=%d" % [trial, edit])
			for query in 12:
				var from := Vector2i(rng.randi_range(0, MapDims.N - 1), rng.randi_range(0, MapDims.N - 1))
				var to := Vector2i(rng.randi_range(0, MapDims.N - 1), rng.randi_range(0, MapDims.N - 1))
				var team := query % 3 - 1
				var expected := reference.route(from, to, team, 1.0)
				var actual: Array[Vector2i] = core.route(from, to, team, 1.0)
				assert(expected == actual, "Hierarchy route trial=%d edit=%d from=%s to=%s expected=%s actual=%s" % [trial, edit, from, to, expected, actual])
				queries += 1
			dangers[edit % dangers.size()] = rng.randf_range(0.0, 4.0) if edit % 2 else 0.025
			reference.set_danger(edit % 2, dangers.duplicate())
			assert(core.set_danger(edit % 2, dangers))
			for change in 18:
				var cell := Vector2i(rng.randi_range(0, MapDims.N - 1), rng.randi_range(0, MapDims.N - 1))
				grid.set_point_solid(cell, not grid.is_point_solid(cell))
				grid.set_point_weight_scale(cell, rng.randf_range(0.3, 3.0))
				reference.mark_dirty(cell)
				assert(core.set_cell(cell, grid.is_point_solid(cell), grid.get_point_weight_scale(cell)))
			assert(core.revisions() == PackedInt64Array([reference.terrain_revision, reference.danger_revision[0], reference.danger_revision[1]]))
			assert(core.pending_clusters() == PackedInt32Array(reference.dirty.keys()))
			reference.update(3)
			assert(core.update(3))
	check_cluster_keys()
	print("HIERARCHY passed queries=", queries)
	get_tree().quit()


func check_cluster_keys() -> void:
	MapDims.N = 64
	HNav.C = 32
	HNav.NC = 2
	var reference := HNav.new(NavRaster.new(64), false, false)
	reference.cl_nodes[0] = [1, 2]
	reference.cl_nodes[1] = [3, 4]
	reference.node_cell = {1: Vector2i(0, 6), 2: Vector2i(31, 6), 3: Vector2i(32, 14), 4: Vector2i(63, 14)}
	reference._keys.resize(4)
	reference._cluster_key(0)
	reference._cluster_key(1)
	assert(reference._keys[0] != reference._keys[1], "Large cluster keys must preserve both entrance coordinates")
