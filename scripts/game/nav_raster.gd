class_name NavRaster
extends RefCounted
## Whole-map cell data. Only the small cluster grids need A* search storage.

var side: int
var solid := PackedByteArray()
var weight := PackedFloat32Array()

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
	solid[c.y * side + c.x] = 1 if value else 0

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
