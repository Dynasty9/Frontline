class_name HNav
extends RefCounted
## Hierarchical A* (HPA*) over one of Nav's 1 m grids.
##
## The 1 m grid is cut into 16 m clusters (32 x 32 of them on a 512 m map). Wherever two neighbouring
## clusters share an open stretch of border there is an entrance (a pair of
## abstract nodes). Inside each cluster the true cost between its entrances is
## precomputed on a small local grid. Long paths are planned on this abstract
## graph (a few thousand nodes instead of a quarter of a million cells) and then refined
## cell by cell between consecutive waypoints.
##
## When walls go up or come down only the touched clusters are rebuilt.
##
## Costs stay inside the native AStar3D (no script callbacks): every intra-cluster
## edge runs through a "mid" node whose weight makes the two halves add up to
## the true cost. There are three copies of the graph: a plain one, and one per
## side whose weights are scaled by that side's danger map (the clusters its
## spotted enemies cover), so careful moves route around known fire.

const C := 16
const NC := MapDims.N / C
const PLAIN := 0

var grid: AStarGrid2D
var vehicle := false
var graphs: Array = []  # [plain, team 0 view, team 1 view]
var local: Array = []  # per cluster AStarGrid2D covering just that cluster
var cl_nodes: Array = []  # per cluster: Array of entrance node ids
var border_nodes := {}  # "a:b" (cluster ids, a < b) -> Array of node ids
var node_cell := {}  # entrance id -> Vector2i
var node_cl := {}  # any node id (entrances and mids) -> cluster index
var node_base := {}  # mid id -> base weight (before danger)
var mids := {}  # pair key -> mid id
var cl_mids: Array = []  # per cluster: Array of mid ids
var next_id := 1
var dirty := {}
var built := false
var danger: Array = [PackedFloat32Array(), PackedFloat32Array()]


func _init(g: AStarGrid2D, is_vehicle: bool) -> void:
	grid = g
	vehicle = is_vehicle
	for i in 3:
		graphs.append(AStar3D.new())
	for t in 2:
		danger[t].resize(NC * NC)
	for ci in NC * NC:
		cl_nodes.append([])
		cl_mids.append([])
		var lg := AStarGrid2D.new()
		lg.region = Rect2i((ci % NC) * C, (ci / NC) * C, C, C)
		lg.cell_size = Vector2(1, 1)
		lg.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		lg.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		lg.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		lg.update()
		local.append(lg)


func cluster_of(c: Vector2i) -> int:
	return clampi(c.y / C, 0, NC - 1) * NC + clampi(c.x / C, 0, NC - 1)


static func _key(a: int, b: int) -> int:
	return mini(a, b) * 2147483648 + maxi(a, b)  # (ids stay well under 2^31)


## Nav changed a cell's solidity / weight: mirror it and queue the cluster.
func mark_dirty(c: Vector2i) -> void:
	var ci := cluster_of(c)
	var lg: AStarGrid2D = local[ci]
	lg.set_point_solid(c, grid.is_point_solid(c))
	lg.set_point_weight_scale(c, grid.get_point_weight_scale(c))
	if built:
		dirty[ci] = true


func build() -> void:
	build_all([self])


## Whole graphs, for a new map: the slow part of starting a battle (tens of
## thousands of entrances on each, and a few hundred small searches inside
## every cluster to cost them). The infantry and vehicle graphs share
## nothing, so each is built on a thread of its own, and the searches, every
## cluster's on its own local grid, are shared out across all the threads.
## Each graph is still put together in one fixed order, so its ids, and every
## route planned on it, come out exactly as they would with no threads at all.
static func build_all(navs: Array) -> void:
	var t := WorkerThreadPool.add_group_task(func(i: int): (navs[i] as HNav)._prepare(), navs.size(), -1, true, "Nav: entrances")
	WorkerThreadPool.wait_for_group_task_completion(t)
	var per := NC * NC
	t = WorkerThreadPool.add_group_task(func(k: int): (navs[k / per] as HNav)._cluster_costs(k % per), navs.size() * per, -1, true, "Nav: entrance costs")
	WorkerThreadPool.wait_for_group_task_completion(t)
	t = WorkerThreadPool.add_group_task(func(i: int): (navs[i] as HNav)._link_all(), navs.size(), -1, true, "Nav: graph")
	WorkerThreadPool.wait_for_group_task_completion(t)


var _costs: Array = []  # while building: each cluster's _pair_costs


## (On a worker thread.) The local grids, copied from the full one, and the
## entrances along every border.
func _prepare() -> void:
	for ci in NC * NC:
		var lg: AStarGrid2D = local[ci]
		var r: Rect2i = lg.region
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, z)
				lg.set_point_solid(c, grid.is_point_solid(c))
				lg.set_point_weight_scale(c, grid.get_point_weight_scale(c))
	for ci in NC * NC:
		var cx := ci % NC
		var cz := ci / NC
		if cx < NC - 1:
			_make_border(ci, ci + 1)
		if cz < NC - 1:
			_make_border(ci, ci + NC)
	# the workers each fill in only their own cluster's slot: resizing the
	# array is what isn't safe from several threads at once
	_costs.resize(NC * NC)


## (On a worker thread.)
func _cluster_costs(ci: int) -> void:
	_costs[ci] = _pair_costs(ci)


## (On a worker thread.) Every cluster's links, in order.
func _link_all() -> void:
	for ci in NC * NC:
		_intra(ci, _costs[ci])
	_costs = []
	built = true
	dirty.clear()


## Rebuild queued clusters (a few per call, so a collapsing house never stalls a tick).
func update(budget := 3) -> void:
	if not built:
		build()
		return
	var n := 0
	while not dirty.is_empty() and n < budget:
		var ci: int = dirty.keys()[0]
		dirty.erase(ci)
		_rebuild_cluster(ci)
		n += 1


func _rebuild_cluster(ci: int) -> void:
	var cx := ci % NC
	var cz := ci / NC
	var nbs := []
	if cx > 0:
		nbs.append(ci - 1)
	if cx < NC - 1:
		nbs.append(ci + 1)
	if cz > 0:
		nbs.append(ci - NC)
	if cz < NC - 1:
		nbs.append(ci + NC)
	for nb in nbs:
		_clear_border(mini(ci, nb), maxi(ci, nb))
	for nb in nbs:
		_make_border(mini(ci, nb), maxi(ci, nb))
	_intra(ci)
	for nb in nbs:
		_intra(nb)


# --- graph plumbing (all three copies move together) --------------------------------------

func _danger_f(gi: int, ci: int) -> float:
	if gi == PLAIN:
		return 1.0
	return 1.0 + float(danger[gi - 1][ci])


func _g_add(id: int, pos: Vector3, ci: int, base := 1.0) -> void:
	node_cl[id] = ci
	for gi in 3:
		(graphs[gi] as AStar3D).add_point(id, pos, base * _danger_f(gi, ci))


func _g_connect(a: int, b: int) -> void:
	for g in graphs:
		(g as AStar3D).connect_points(a, b)


func _g_remove(id: int) -> void:
	node_cl.erase(id)
	node_base.erase(id)
	for g in graphs:
		if (g as AStar3D).has_point(id):
			(g as AStar3D).remove_point(id)


## Joins a and b through a mid node so that walking a -> mid -> b costs `c`.
func _link(a: int, b: int, c: float, ci: int, temp) -> void:
	var g0: AStar3D = graphs[PLAIN]
	var pa := g0.get_point_position(a)
	var pb := g0.get_point_position(b)
	var l := pa.distance_to(pb)
	if l < 0.5:
		_g_connect(a, b)
		return
	# a -> m costs (l/2) * w_m, m -> b costs (l/2) * w_b (entrances weigh 1)
	var w := clampf(2.0 * c / l - 1.0, 0.05, 60.0)
	var m := next_id
	next_id += 1
	node_base[m] = w
	_g_add(m, (pa + pb) * 0.5, ci, w)
	_g_connect(a, m)
	_g_connect(m, b)
	if temp != null:
		temp.append(m)
	else:
		mids[_key(a, b)] = m
		(cl_mids[ci] as Array).append(m)


# --- entrances ---------------------------------------------------------------------------

func _bkey(a: int, b: int) -> String:
	return "%d:%d" % [a, b]


func _clear_border(a: int, b: int) -> void:
	var k := _bkey(a, b)
	for id in border_nodes.get(k, []):
		# its intra links go with it
		var ci: int = node_cl.get(id, -1)
		if ci >= 0:
			for other in cl_nodes[ci]:
				var mk := _key(id, other)
				if mids.has(mk):
					var m: int = mids[mk]
					mids.erase(mk)
					(cl_mids[ci] as Array).erase(m)
					_g_remove(m)
		_g_remove(id)
		node_cell.erase(id)
		for cj in [a, b]:
			(cl_nodes[cj] as Array).erase(id)
	border_nodes.erase(k)


func _add_node(c: Vector2i, ci: int) -> int:
	var id := next_id
	next_id += 1
	_g_add(id, Vector3(c.x + 0.5, 0, c.y + 0.5), ci)
	node_cell[id] = c
	(cl_nodes[ci] as Array).append(id)
	return id


## Finds the open stretches of the border between clusters a and b (b is the
## right or lower neighbour) and links them.
func _make_border(a: int, b: int) -> void:
	var side_by_side := b == a + 1
	var ax := (a % NC) * C
	var az := (a / NC) * C
	var ids := []
	var run_start := -1
	for i in C + 1:
		var open := false
		if i < C:
			var ca := Vector2i(ax + C - 1, az + i) if side_by_side else Vector2i(ax + i, az + C - 1)
			var cb := Vector2i(ax + C, az + i) if side_by_side else Vector2i(ax + i, az + C)
			open = not grid.is_point_solid(ca) and not grid.is_point_solid(cb)
		if open and run_start < 0:
			run_start = i
		elif not open and run_start >= 0:
			var run_end := i - 1
			var picks := []
			if run_end - run_start < 6:
				picks.append((run_start + run_end) / 2)
			else:
				picks.append(run_start + 2)
				picks.append(run_end - 2)
			# and wherever a road (a cheap stretch) crosses the border, so routes can follow it
			var cheap_start := -1
			for j in range(run_start, run_end + 2):
				var cheap := false
				if j <= run_end:
					var cj := Vector2i(ax + C, az + j) if side_by_side else Vector2i(ax + j, az + C)
					cheap = grid.get_point_weight_scale(cj) < 0.95
				if cheap and cheap_start < 0:
					cheap_start = j
				elif not cheap and cheap_start >= 0:
					var mid := (cheap_start + j - 1) / 2
					var near := false
					for q in picks:
						if absi(int(q) - mid) < 3:
							near = true
					if not near:
						picks.append(mid)
					cheap_start = -1
			for p in picks:
				var pa := Vector2i(ax + C - 1, az + p) if side_by_side else Vector2i(ax + p, az + C - 1)
				var pb := Vector2i(ax + C, az + p) if side_by_side else Vector2i(ax + p, az + C)
				var na := _add_node(pa, a)
				var nb := _add_node(pb, b)
				_g_connect(na, nb)
				ids.append(na)
				ids.append(nb)
			run_start = -1
	border_nodes[_bkey(a, b)] = ids


## True costs between every pair of entrances inside one cluster. `costs` is
## what _pair_costs found for it, if that has been worked out already.
func _intra(ci: int, costs := PackedFloat64Array()) -> void:
	for m in cl_mids[ci]:
		_g_remove(m)
	for id in cl_nodes[ci]:
		for other in cl_nodes[ci]:
			mids.erase(_key(id, other))
	cl_mids[ci] = []
	if costs.is_empty():
		costs = _pair_costs(ci)
	var nodes: Array = cl_nodes[ci]
	var k := 0
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			var c := costs[k]
			k += 1
			if c >= 0.0:
				_link(nodes[i], nodes[j], c, ci, null)


## The cost of walking between each pair of the cluster's entrances (-1: no
## way through), in the order _intra links them. Only reads the graph, and
## searches only this cluster's own grid, so clusters can be done side by side.
func _pair_costs(ci: int) -> PackedFloat64Array:
	var nodes: Array = cl_nodes[ci]
	var lg: AStarGrid2D = local[ci]
	var out := PackedFloat64Array()
	for i in nodes.size():
		for j in range(i + 1, nodes.size()):
			out.append(_local_cost(lg, node_cell[nodes[i]], node_cell[nodes[j]]))
	return out


func _local_cost(lg: AStarGrid2D, a: Vector2i, b: Vector2i) -> float:
	if a == b:
		return 0.0
	if lg.is_point_solid(a) or lg.is_point_solid(b):
		return -1.0
	var p: Array[Vector2i] = lg.get_id_path(a, b)
	if p.is_empty():
		return -1.0
	var c := 0.0
	for k in range(1, p.size()):
		var d := 1.4142 if (p[k].x != p[k - 1].x and p[k].y != p[k - 1].y) else 1.0
		c += d * lg.get_point_weight_scale(p[k])
	return c


# --- danger ------------------------------------------------------------------------------

## Each side's danger map (0..4 per cluster); reweights only the clusters that changed.
func set_danger(team: int, values: PackedFloat32Array) -> void:
	var old: PackedFloat32Array = danger[team]
	danger[team] = values
	if not built:
		return
	var g: AStar3D = graphs[team + 1]
	for ci in NC * NC:
		if absf(old[ci] - values[ci]) < 0.05:
			continue
		var f := 1.0 + values[ci]
		for id in cl_nodes[ci]:
			g.set_point_weight_scale(id, f)
		for m in cl_mids[ci]:
			g.set_point_weight_scale(m, float(node_base.get(m, 1.0)) * f)


# --- queries -----------------------------------------------------------------------------

## Abstract route from a to b (both free cells). Returns the waypoint cells,
## or an empty array if they are not connected. Any care > 0 plans on the
## team's danger-weighted graph.
func route(a: Vector2i, b: Vector2i, team: int, care: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not built:
		build()
	var gi := team + 1 if care > 0.0 and team >= 0 and team < 2 else PLAIN
	var g: AStar3D = graphs[gi]
	var ca := cluster_of(a)
	var cb := cluster_of(b)
	var s_id := next_id
	var g_id := next_id + 1
	next_id += 2
	var temp := []
	_g_add(s_id, Vector3(a.x + 0.5, 0, a.y + 0.5), ca)
	_g_add(g_id, Vector3(b.x + 0.5, 0, b.y + 0.5), cb)
	var la: AStarGrid2D = local[ca]
	var lb: AStarGrid2D = local[cb]
	for id in cl_nodes[ca]:
		var c := _local_cost(la, a, node_cell[id])
		if c >= 0.0:
			_link(s_id, id, c, ca, temp)
	for id in cl_nodes[cb]:
		var c2 := _local_cost(lb, b, node_cell[id])
		if c2 >= 0.0:
			_link(g_id, id, c2, cb, temp)
	if ca == cb:
		var c3 := _local_cost(la, a, b)
		if c3 >= 0.0:
			_link(s_id, g_id, c3, ca, temp)
	var ids := g.get_id_path(s_id, g_id)
	for id in ids:
		if id == s_id:
			out.append(a)
		elif id == g_id:
			out.append(b)
		elif node_cell.has(id):
			out.append(node_cell[id])
	for m in temp:
		_g_remove(m)
	_g_remove(s_id)
	_g_remove(g_id)
	return out


func stats() -> String:
	return "%d entrances, %d nodes" % [node_cell.size(), (graphs[PLAIN] as AStar3D).get_point_count()]
