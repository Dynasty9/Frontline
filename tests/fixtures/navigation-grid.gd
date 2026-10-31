extends Node


func _ready() -> void:
	assert(ClassDB.class_exists("NavigationGridCore"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 29471
	var queries := 0
	for trial in 48:
		var n: int = [8, 16, 32, 64][trial % 4]
		var origin := Vector2i(rng.randi_range(-400, 400), rng.randi_range(-400, 400))
		var region := Rect2i(origin, Vector2i(n, n))
		var native: RefCounted = ClassDB.instantiate("NavigationGridCore")
		assert(native.configure(region, Vector2(2, 3)))
		var engine := AStarGrid2D.new()
		engine.region = region
		engine.cell_size = Vector2(2, 3)
		engine.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		engine.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		engine.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		engine.update()
		var solid := PackedByteArray()
		var weights := PackedFloat32Array()
		for y in n:
			for x in n:
				var point := origin + Vector2i(x,y)
				var blocked := rng.randf() < 0.24 if trial % 3 else false
				var cost: float = [0.3, 1.0, 1.4, 2.5, 5.0][rng.randi() % 5] if trial % 2 else 1.0
				engine.set_point_solid(point, blocked)
				engine.set_point_weight_scale(point, cost)
				solid.append(int(blocked))
				weights.append(cost)
		assert(native.load_cells(solid, weights))
		var pairs: Array[Vector2i] = []
		for query in 80:
			var from := origin + Vector2i(rng.randi_range(0,n-1), rng.randi_range(0,n-1))
			var to := origin + Vector2i(rng.randi_range(0,n-1), rng.randi_range(0,n-1))
			var expected := engine.get_id_path(from, to)
			var actual: Array[Vector2i] = native.get_id_path(from, to)
			assert(actual == expected, "Grid path differs: trial=%d query=%d from=%s to=%s expected=%s actual=%s" % [trial, query, from, to, expected, actual])
			assert(native.get_point_path(from, to) == engine.get_point_path(from, to))
			assert(native.path_cost(from, to) == cost_of(engine, expected, from == to))
			if query < 8:
				pairs.append(from)
			queries += 1
			if query % 7 == 0:
				var blocked := not engine.is_point_solid(from)
				engine.set_point_solid(from, blocked)
				assert(native.set_point_solid(from, blocked))
				engine.set_point_weight_scale(to, 1.4)
				assert(native.set_point_weight_scale(to, 1.4))
		var costs: PackedFloat64Array = native.pair_costs(pairs)
		for i in pairs.size():
			for j in range(i + 1, pairs.size()):
				assert(costs[i * pairs.size() + j] == cost_of(engine, engine.get_id_path(pairs[i], pairs[j]), pairs[i] == pairs[j]))
		assert(not native.load_cells(PackedByteArray(), weights))
		assert(native.get_id_path(origin - Vector2i.ONE, origin).is_empty())
	print("NAVIGATION_GRID passed queries=", queries)
	get_tree().quit()


func cost_of(grid: AStarGrid2D, path: Array[Vector2i], same: bool) -> float:
	if same:
		return 0.0
	if path.is_empty():
		return -1.0
	var cost := 0.0
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		cost += (1.4142 if a.x != b.x and a.y != b.y else 1.0) * grid.get_point_weight_scale(b)
	return cost
