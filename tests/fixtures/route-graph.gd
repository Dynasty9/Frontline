extends Node

func cost(graph: AStar3D, path: PackedInt64Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		assert(graph.are_points_connected(path[i - 1], path[i]))
		total += graph.get_point_position(path[i - 1]).distance_to(graph.get_point_position(path[i])) * graph.get_point_weight_scale(path[i])
	return total

func _ready() -> void:
	assert(ClassDB.class_exists("RouteGraph"))
	var native = ClassDB.instantiate("RouteGraph")
	var reference := AStar3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 731
	var width := 24
	for i in width * width:
		var p := Vector3(i % width, 0, i / width) * 16.0
		for graph in [reference, native]:
			graph.add_point(i, p, 1.0)
	var mid := width * width
	for i in width * width:
		for other in [i + 1 if i % width + 1 < width else -1, i + width if i + width < width * width else -1]:
			if other < 0:
				continue
			var p := reference.get_point_position(i).lerp(reference.get_point_position(other), 0.5)
			var weight := rng.randf_range(1.0, 6.0)
			for graph in [reference, native]:
				graph.add_point(mid, p, weight)
				graph.connect_points(i, mid)
				graph.connect_points(mid, other)
			mid += 1
	assert(native.get_point_count() == reference.get_point_count())
	var queries := []
	for i in 300:
		queries.append(Vector2i(rng.randi_range(0, mid - 1), rng.randi_range(0, mid - 1)))
	for phase in 3:
		if phase == 1:
			for id in range(width * width, mid, 7):
				for graph in [reference, native]:
					graph.set_point_weight_scale(id, 11.0)
		elif phase == 2:
			for id in range(width * width, mid, 9):
				for graph in [reference, native]:
					graph.remove_point(id)
		for query: Vector2i in queries:
			if not reference.has_point(query.x) or not reference.has_point(query.y):
				continue
			var expected := reference.get_id_path(query.x, query.y)
			var actual: PackedInt64Array = native.get_id_path(query.x, query.y)
			assert(expected.is_empty() == actual.is_empty())
			if not actual.is_empty():
				assert(actual[0] == query.x and actual[-1] == query.y)
				assert(absf(cost(reference, expected) - cost(reference, actual)) < 0.01, "Contraction must retain direction-dependent route costs")
	# Recycled slots, moving existing points, duplicate links and disconnected goals.
	for graph in [reference, native]:
		graph.add_point(mid + 1, Vector3.ZERO, 1.0)
		graph.add_point(mid + 2, Vector3.ONE, 2.0)
		graph.connect_points(mid + 1, mid + 2)
		graph.connect_points(mid + 1, mid + 2)
		graph.add_point(mid + 2, Vector3(4, 0, 0), 3.0)
	assert(native.get_id_path(mid + 1, mid + 2) == reference.get_id_path(mid + 1, mid + 2))
	assert(native.get_id_path(0, mid + 1).is_empty())
	assert(native.get_id_path(-1, 0).is_empty())
	print("ROUTE_GRAPH passed")
	get_tree().quit()
