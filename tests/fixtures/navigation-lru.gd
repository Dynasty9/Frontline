extends Node

class ReferenceNav extends HNav:
	var _uses := 0
	func local_grid(ci: int) -> Object:
		_uses += 1
		var e: Variant = _local.get(ci)
		if e != null:
			e[1] = _uses
			return e[0]
		if _local.size() >= CACHE_CELLS / (C * C):
			var old := -1
			var oldest := _uses
			for k: int in _local:
				if int(_local[k][1]) < oldest:
					oldest = int(_local[k][1])
					old = k
			_local.erase(old)
		var lg := _local_from(ci, _solid, _weight)
		_local[ci] = [lg, _uses]
		return lg

func _ready() -> void:
	check_raster()
	for cluster in [16, 32]:
		check_cache(cluster)
	print("NAV_LRU passed")
	get_tree().quit()

func check_cache(cluster: int) -> void:
	MapDims.N = 1024
	HNav.C = cluster
	HNav.NC = MapDims.N / cluster
	var capacity := HNav.CACHE_CELLS / (cluster * cluster)
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, 1024, 1024)
	grid.update()
	var old := ReferenceNav.new(grid, false)
	var current := HNav.new(grid, false)
	var random := RandomNumberGenerator.new()
	random.seed = 826
	for i in capacity:
		old.local_grid(i)
		current.local_grid(i)
	for i in 1800:
		var ci := random.randi_range(0, 1023)
		old.local_grid(ci)
		current.local_grid(ci)
		assert(old._local.size() == current._local.size())
		for key in old._local:
			assert(current._local.has(key), "LRU eviction changed")
	var cell := Vector2i(4, 7)
	current.local_grid(0)
	grid.set_point_solid(cell, true)
	grid.set_point_weight_scale(cell, 2.5)
	current.mark_dirty(cell)
	assert(current.local_grid(0).is_point_solid(cell))
	assert(current.local_grid(0).get_point_weight_scale(cell) == 2.5)
	for i in range(1, capacity + 2):
		current.local_grid(i)
	assert(not current._local.has(0))
	assert(current.local_grid(0).is_point_solid(cell) and current.local_grid(0).get_point_weight_scale(cell) == 2.5)
	current.built = true
	grid.set_point_weight_scale(cell, 1.4)
	current.mark_dirty(cell)
	var revision := current.terrain_revision
	current.mark_dirty(cell)
	assert(current.terrain_revision == revision, "An unchanged fractional cost must not invalidate routes because of float precision")
	for i in range(1, capacity + 2):
		current.local_grid(i)
	assert(current.local_grid(0).get_point_weight_scale(cell) == grid.get_point_weight_scale(cell), "Eviction must preserve the original cost precision")

	for repeat in 3:
		for nav in [old, current]:
			var start := Time.get_ticks_usec()
			for i in 2500:
				nav.local_grid(i % 1024)
			print("NAV_LRU cluster=%d reference=%s ms=%.3f" % [cluster, nav == old, (Time.get_ticks_usec() - start) / 1000.0])

func check_raster() -> void:
	var raster := NavRaster.new(32)
	var reference := raster.reference_grid()
	var random := RandomNumberGenerator.new()
	random.seed = 491
	for i in 2000:
		var cell := Vector2i(random.randi_range(0, 31), random.randi_range(0, 31))
		var solid := random.randf() < 0.3
		var weight := random.randf_range(0.3, 8.0)
		for grid in [raster, reference]:
			grid.set_point_solid(cell, solid)
			grid.set_point_weight_scale(cell, weight)
	var restored := raster.reference_grid()
	for y in 32:
		for x in 32:
			var cell := Vector2i(x, y)
			assert(raster.is_point_solid(cell) == reference.is_point_solid(cell))
			assert(raster.get_point_weight_scale(cell) == reference.get_point_weight_scale(cell))
			assert(restored.is_point_solid(cell) == reference.is_point_solid(cell))
			assert(restored.get_point_weight_scale(cell) == reference.get_point_weight_scale(cell))
	assert(not raster.is_in_boundsv(Vector2i(-1, 0)) and raster.is_point_solid(Vector2i(-1, 0)))
	assert(not raster.is_in_boundsv(Vector2i(32, 0)) and raster.is_point_solid(Vector2i(32, 0)))
