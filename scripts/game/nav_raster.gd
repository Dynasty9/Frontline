class_name NavRaster
extends RefCounted
## Whole-map cell data. Only the small cluster grids need A* search storage.

var side: int
var solid := PackedByteArray()
var weight := PackedFloat32Array()
var regions := PackedInt32Array()
var region_parent := PackedInt32Array()

func _init(n: int) -> void:
	side = n
	solid.resize(n * n)
	weight.resize(n * n)
	weight.fill(1.0)

func is_in_boundsv(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < side and c.y < side

func is_point_solid(c: Vector2i) -> bool:
	return not is_in_boundsv(c) or solid[c.y * side + c.x] != 0

func set_point_solid(c: Vector2i, value: bool) -> void:
	assert(is_in_boundsv(c))
	var i := c.y * side + c.x
	var opened := solid[i] != 0 and not value
	solid[i] = 1 if value else 0
	if opened and not regions.is_empty():
		if regions[i] < 0:
			regions[i] = region_parent.size()
			region_parent.append(region_parent.size())
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = c + d
			if is_in_boundsv(q) and not is_point_solid(q):
				region_parent[_region_root(regions[q.y * side + q.x])] = _region_root(regions[i])

func get_point_weight_scale(c: Vector2i) -> float:
	assert(is_in_boundsv(c))
	return weight[c.y * side + c.x]

func set_point_weight_scale(c: Vector2i, value: float) -> void:
	assert(is_in_boundsv(c) and is_finite(value) and value >= 0.0)
	weight[c.y * side + c.x] = value

## The explicit --bench-nav diagnostic still compares against a flat search.
func reference_grid() -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, side, side)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for y in side:
		for x in side:
			var i := y * side + x
			if solid[i] != 0:
				grid.set_point_solid(Vector2i(x, y), true)
			if weight[i] != 1.0:
				grid.set_point_weight_scale(Vector2i(x, y), weight[i])
	return grid


## Closed passages can leave false positives, never reject a newly opened route.
## The hierarchy still checks the actual obstacles; openings merge these coarse regions.
func build_regions() -> void:
	regions.resize(side * side)
	regions.fill(-1)
	region_parent.clear()
	var pending := PackedInt32Array()
	for i in solid.size():
		if solid[i] != 0 or regions[i] >= 0:
			continue
		var label := region_parent.size()
		region_parent.append(label)
		regions[i] = label
		pending.append(i)
		while not pending.is_empty():
			var j := pending[pending.size() - 1]
			pending.resize(pending.size() - 1)
			var x := j % side
			var y := j / side
			for k in [j - 1 if x > 0 else -1, j + 1 if x < side - 1 else -1, j - side if y > 0 else -1, j + side if y < side - 1 else -1]:
				if k >= 0 and solid[k] == 0 and regions[k] < 0:
					regions[k] = label
					pending.append(k)


func _region_root(label: int) -> int:
	while region_parent[label] != label:
		region_parent[label] = region_parent[region_parent[label]]
		label = region_parent[label]
	return label


func disconnected(a: Vector2i, b: Vector2i) -> bool:
	if regions.is_empty():
		return false
	var ra := regions[a.y * side + a.x]
	var rb := regions[b.y * side + b.x]
	return ra < 0 or rb < 0 or _region_root(ra) != _region_root(rb)
