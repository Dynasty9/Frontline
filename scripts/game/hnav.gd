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
## When walls go up or come down only the touched clusters are rebuilt, and of
## those only what the change can reach: a border whose cells are as they were
## keeps its entrances, and a link whose two ends and ground are as they were
## keeps its cost. Most clusters queued for a rebuild turn out to have changed
## nowhere that matters (cover worked out again around a fallen wall re-marks
## every cell near it, and a sandbag only infantry notice still queues the
## vehicles' cluster), so most rebuilds now do next to nothing.
##
## Costs stay inside the native AStar3D (no script callbacks): every intra-cluster
## edge runs through a "mid" node whose weight makes the two halves add up to
## the true cost. There are three copies of the graph: a plain one, and one per
## side whose weights are scaled by that side's danger map (the clusters its
## spotted enemies cover), so careful moves route around known fire.

const C := 16
const NC := MapDims.N / C
const NCC := NC * NC
const PLAIN := 0
const UNKNOWN := -2.0  # a cost not worked out yet (-1 is "no way through")

var grid: AStarGrid2D
var vehicle := false
var graphs: Array = []  # [plain, team 0 view, team 1 view]
var g_team: Array[AStar3D] = []  # (the last two again)
var local: Array = []  # per cluster AStarGrid2D covering just that cluster
var cl_nodes: Array = []  # per cluster: Array of entrance node ids
var border_nodes := {}  # _bkey(a, b) (cluster ids, a < b) -> Array of node ids, a's and b's in turn
var border_picks := {}  # _bkey -> PackedInt32Array: where along the border its entrances are
var border_ver := {}  # _bkey -> Vector2i: the edge_ver of each side when it was laid out
var node_cell := {}  # entrance id -> Vector2i
var node_cl := {}  # any node id (entrances and mids) -> cluster index
var node_base := {}  # mid id -> base weight (before danger)
var mids := {}  # pair key -> mid id
var cl_mids: Array = []  # per cluster: Dictionary of its mid ids
var next_id := 1
var dirty := {}
var built := false
var danger: Array = [PackedFloat32Array(), PackedFloat32Array()]
# What a rebuild needs to tell what changed:
var ver := PackedInt32Array()  # per cluster: goes up whenever one of its cells really changes
var edge_ver := PackedInt32Array()  # per cluster side (left, right, top, bottom): the same, for the cells along that edge
var link_ver := PackedInt32Array()  # per cluster: its ver when its links were last worked out
var basis: Array = []  # per cluster: the entrance ids its costs are listed by
var costs: Array = []  # per cluster: the costs between them, as a square table (see _relink)
var mid_f := PackedFloat64Array()  # per side, per cluster: the danger factor its mids carry
var danger_n := PackedInt32Array()  # per side, per cluster: goes up whenever its danger changes at all
var border_dn := {}  # _bkey -> Vector4i: the danger_n of each side when its entrances were last weighted


func _init(g: AStarGrid2D, is_vehicle: bool) -> void:
	grid = g
	vehicle = is_vehicle
	for i in 3:
		graphs.append(AStar3D.new())
	g_team = [graphs[1], graphs[2]]
	for t in 2:
		danger[t].resize(NCC)
	ver.resize(NCC)
	edge_ver.resize(NCC * 4)
	link_ver.resize(NCC)
	mid_f.resize(2 * NCC)
	danger_n.resize(2 * NCC)
	basis.resize(NCC)
	costs.resize(NCC)
	for ci in NCC:
		cl_nodes.append([])
		cl_mids.append({})
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
	var solid := grid.is_point_solid(c)
	var w := grid.get_point_weight_scale(c)
	if built and (solid != lg.is_point_solid(c) or w != lg.get_point_weight_scale(c)):
		# (most calls change nothing: a wall raised where the ground was already blocked)
		ver[ci] += 1
		var x := c.x % C
		var z := c.y % C
		if x == 0:
			edge_ver[ci * 4] += 1
		elif x == C - 1:
			edge_ver[ci * 4 + 1] += 1
		if z == 0:
			edge_ver[ci * 4 + 2] += 1
		elif z == C - 1:
			edge_ver[ci * 4 + 3] += 1
	lg.set_point_solid(c, solid)
	lg.set_point_weight_scale(c, w)
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
	t = WorkerThreadPool.add_group_task(func(k: int): (navs[k / NCC] as HNav)._cluster_costs(k % NCC), navs.size() * NCC, -1, true, "Nav: entrance costs")
	WorkerThreadPool.wait_for_group_task_completion(t)
	t = WorkerThreadPool.add_group_task(func(i: int): (navs[i] as HNav)._link_all(), navs.size(), -1, true, "Nav: graph")
	WorkerThreadPool.wait_for_group_task_completion(t)


## (On a worker thread.) The local grids, copied from the full one, and the
## entrances along every border.
func _prepare() -> void:
	for ci in NCC:
		var lg: AStarGrid2D = local[ci]
		var r: Rect2i = lg.region
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, z)
				lg.set_point_solid(c, grid.is_point_solid(c))
				lg.set_point_weight_scale(c, grid.get_point_weight_scale(c))
	for ci in NCC:
		var cx := ci % NC
		var cz := ci / NC
		if cx < NC - 1:
			_make_border(ci, ci + 1, _border_picks(ci, ci + 1))
		if cz < NC - 1:
			_make_border(ci, ci + NC, _border_picks(ci, ci + NC))


## (On a worker thread.) The workers each fill in only their own cluster's
## slot: resizing the array is what isn't safe from several threads at once.
func _cluster_costs(ci: int) -> void:
	basis[ci] = (cl_nodes[ci] as Array).duplicate()
	costs[ci] = _pair_costs(ci)


## (On a worker thread.) Every cluster's links, in order.
func _link_all() -> void:
	for ci in NCC:
		_intra(ci)
		link_ver[ci] = ver[ci]
		for t in 2:
			mid_f[t * NCC + ci] = 1.0 + float(danger[t][ci])
	built = true
	dirty.clear()


## Rebuild queued clusters (a few per call, so a collapsing house never stalls a tick).
func update(budget := 3) -> void:
	if not built:
		build()
		return
	var n := 0
	while not dirty.is_empty() and n < budget:
		var ci := 0
		for k: int in dirty:
			ci = k  # (the one queued longest)
			break
		dirty.erase(ci)
		_rebuild_cluster(ci)
		n += 1


## The cluster's borders with its four neighbours are laid out again and the
## five clusters' links brought up to date. The result is exactly the graph
## that clearing the borders and remaking every link would give (that is how
## it used to be done, at several milliseconds a cluster): the same entrances,
## listed in the same order, linked at the same costs.
func _rebuild_cluster(ci: int) -> void:
	var cx := ci % NC
	var cz := ci / NC
	var nbs := PackedInt32Array()
	if cx > 0:
		nbs.append(ci - 1)
	if cx < NC - 1:
		nbs.append(ci + 1)
	if cz > 0:
		nbs.append(ci - NC)
	if cz < NC - 1:
		nbs.append(ci + NC)
	# each cluster's entrances as listed before (its costs are kept in that order)
	var before: Array = [(cl_nodes[ci] as Array).duplicate()]
	for nb in nbs:
		before.append((cl_nodes[nb] as Array).duplicate())
	for nb in nbs:
		var a := mini(ci, nb)
		var b := maxi(ci, nb)
		var bk := _bkey(a, b)
		var ev := _edge_vers(a, b)
		if border_ver[bk] != ev:
			border_ver[bk] = ev
			var picks := _border_picks(a, b)
			if picks != border_picks[bk]:
				_clear_border(a, b)
				_make_border(a, b, picks)
				continue
		# the same entrances, kept: made afresh, they would take today's danger
		var dn := _danger_ns(a, b)
		if border_dn[bk] != dn:
			border_dn[bk] = dn
			for id: int in border_nodes[bk]:
				var k: int = node_cl[id]
				for t in 2:
					g_team[t].set_point_weight_scale(id, 1.0 + float(danger[t][k]))
	# The order the entrances are listed in decides which way round each pair
	# is costed, so it follows the old way: this cluster's border by border,
	# and in each neighbour the ones on this border moved to the end.
	var own: Array = []
	for nb in nbs:
		var bn: Array = border_nodes[_bkey(mini(ci, nb), maxi(ci, nb))]
		var s := 0 if ci < nb else 1
		var theirs: Array = cl_nodes[nb]
		for q in range(s, bn.size(), 2):
			own.append(bn[q])
		for q in range(1 - s, bn.size(), 2):
			theirs.erase(bn[q])
		for q in range(1 - s, bn.size(), 2):
			theirs.append(bn[q])
	cl_nodes[ci] = own
	_relink(ci, before[0])
	for i in nbs.size():
		_relink(nbs[i], before[i + 1])


## Brings one cluster's links up to date after its entrances moved or its
## ground changed, as if they were all made afresh. `before` is how its
## entrances were listed when its links were last worked out. A pair keeps its
## link when neither end is new, the ground is as it was, and it is still
## costed the same way round (from the entrance listed first: the two ways
## round can differ by a hair). The other pairs are costed again, from what is
## already known where possible: costs[k] keeps every cost worked out on the
## cluster's ground as it stands, both ways round, indexed by basis[k].
func _relink(k: int, before: Array) -> void:
	_fresh_danger(k)
	var nodes: Array = cl_nodes[k]
	var regrid := link_ver[k] != ver[k]
	if not regrid and nodes == before:
		return
	var n := nodes.size()
	var at := PackedInt32Array()  # each entrance's place in `before` (-1: new, or the ground changed)
	at.resize(n)
	at.fill(-1)
	var bp := PackedInt32Array()  # and in the basis
	bp.resize(n)
	var bas: Array = basis[k]
	var cm: PackedFloat64Array = costs[k]
	costs[k] = PackedFloat64Array()  # (so that writing to cm doesn't copy it)
	var fresh := regrid
	if not regrid:
		for i in n:
			at[i] = before.find(nodes[i])
			bp[i] = bas.find(nodes[i])
			fresh = fresh or bp[i] < 0
	if fresh:
		# the ground changed, or there are new entrances: a new basis, today's
		# entrances, keeping what's still known
		var nm := PackedFloat64Array()
		nm.resize(n * n)
		nm.fill(UNKNOWN)
		if not regrid:
			var nb := bas.size()
			for i in n:
				if bp[i] < 0:
					continue
				for j in n:
					if bp[j] >= 0:
						nm[i * n + j] = cm[bp[i] * nb + bp[j]]
		for i in n:
			bp[i] = i
		cm = nm
		bas = nodes.duplicate()
		basis[k] = bas
	var nbas := bas.size()
	var lg: AStarGrid2D = local[k]
	for i in n:
		var oi := at[i]
		var row := bp[i] * nbas
		var a: int = nodes[i]
		var ca: Vector2i = node_cell[a]
		for j in range(i + 1, n):
			var oj := at[j]
			if oi >= 0 and oj > oi:
				continue  # (linked at this cost already)
			var b: int = nodes[j]
			var cb: Vector2i = node_cell[b]
			var c := cm[row + bp[j]]
			if c == UNKNOWN:
				c = _local_cost(lg, ca, cb)
				cm[row + bp[j]] = c
			if oi >= 0 and oj >= 0 and c == cm[bp[j] * nbas + bp[i]]:
				continue  # (turned round, but linked at this cost the other way)
			_set_link(a, b, ca, cb, c, k)
	costs[k] = cm
	link_ver[k] = ver[k]


## Linking a pair of the cluster's entrances (a listed before b) at cost c,
## as _link would make it, changing only what differs.
func _set_link(a: int, b: int, ca: Vector2i, cb: Vector2i, c: float, k: int) -> void:
	var mk := _key(a, b)
	var m: int = mids.get(mk, 0)
	if c < 0.0:
		if m != 0:
			mids.erase(mk)
			(cl_mids[k] as Dictionary).erase(m)
			_g_remove(m)
		return
	var pa := Vector3(ca.x + 0.5, 0, ca.y + 0.5)
	var pb := Vector3(cb.x + 0.5, 0, cb.y + 0.5)
	var l := pa.distance_to(pb)
	if l < 0.5:
		_g_connect(a, b)
		return
	var w := clampf(2.0 * c / l - 1.0, 0.05, 60.0)
	if m == 0:
		_link(a, b, c, k, null)
	elif w != float(node_base[m]):
		node_base[m] = w
		(graphs[PLAIN] as AStar3D).set_point_weight_scale(m, w)
		for t in 2:
			g_team[t].set_point_weight_scale(m, w * mid_f[t * NCC + k])  # (today's: see _fresh_danger)


## Made afresh, the cluster's mids would take today's danger: set_danger
## only passes on a change of 0.05 or more.
func _fresh_danger(k: int) -> void:
	for t in 2:
		var f := 1.0 + float(danger[t][k])
		if mid_f[t * NCC + k] == f:
			continue
		mid_f[t * NCC + k] = f
		var g := g_team[t]
		for m: int in cl_mids[k]:
			g.set_point_weight_scale(m, float(node_base[m]) * f)


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
		(cl_mids[ci] as Dictionary)[m] = true


# --- entrances ---------------------------------------------------------------------------

static func _bkey(a: int, b: int) -> int:
	return a * NCC + b


## The edge versions of the two sides of the border between a and b (b the
## right or lower neighbour): while they stand, so does the border.
func _edge_vers(a: int, b: int) -> Vector2i:
	if b == a + 1:
		return Vector2i(edge_ver[a * 4 + 1], edge_ver[b * 4])
	return Vector2i(edge_ver[a * 4 + 3], edge_ver[b * 4 + 2])


## The danger_n of the two clusters either side of a border, both sides' views.
func _danger_ns(a: int, b: int) -> Vector4i:
	return Vector4i(danger_n[a], danger_n[NCC + a], danger_n[b], danger_n[NCC + b])


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
					(cl_mids[ci] as Dictionary).erase(m)
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


## Where the entrances go on the border between clusters a and b (b is the
## right or lower neighbour): in each open stretch of it, one in the middle
## of a short one, two in from the ends of a long one.
func _border_picks(a: int, b: int) -> PackedInt32Array:
	var side_by_side := b == a + 1
	var ax := (a % NC) * C
	var az := (a / NC) * C
	var out := PackedInt32Array()
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
				out.append(p)
			run_start = -1
	return out


## The entrances at `picks` on the border between a and b, linked across it.
func _make_border(a: int, b: int, picks: PackedInt32Array) -> void:
	var side_by_side := b == a + 1
	var ax := (a % NC) * C
	var az := (a / NC) * C
	var ids := []
	for p in picks:
		var pa := Vector2i(ax + C - 1, az + p) if side_by_side else Vector2i(ax + p, az + C - 1)
		var pb := Vector2i(ax + C, az + p) if side_by_side else Vector2i(ax + p, az + C)
		var na := _add_node(pa, a)
		var nb := _add_node(pb, b)
		_g_connect(na, nb)
		ids.append(na)
		ids.append(nb)
	var bk := _bkey(a, b)
	border_nodes[bk] = ids
	border_picks[bk] = picks
	border_ver[bk] = _edge_vers(a, b)
	border_dn[bk] = _danger_ns(a, b)


## Links every pair of entrances inside one cluster, at the costs _pair_costs
## found (for a new graph: nothing is linked yet).
func _intra(ci: int) -> void:
	var cm: PackedFloat64Array = costs[ci]
	var nodes: Array = cl_nodes[ci]
	var n := nodes.size()
	for i in n:
		for j in range(i + 1, n):
			var c := cm[i * n + j]
			if c >= 0.0:
				_link(nodes[i], nodes[j], c, ci, null)


## The cost of walking between each pair of the cluster's entrances (-1: no
## way through), as an n x n table: [i * n + j] is from entrance i to entrance
## j, worked out for i < j (the way round _intra links them). Only reads the
## graph, and searches only this cluster's own grid, so clusters can be done
## side by side.
func _pair_costs(ci: int) -> PackedFloat64Array:
	var nodes: Array = cl_nodes[ci]
	var lg: AStarGrid2D = local[ci]
	var n := nodes.size()
	var out := PackedFloat64Array()
	out.resize(n * n)
	out.fill(UNKNOWN)
	for i in n:
		for j in range(i + 1, n):
			out[i * n + j] = _local_cost(lg, node_cell[nodes[i]], node_cell[nodes[j]])
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
	var prev := p[0]
	for k in range(1, p.size()):
		var q := p[k]
		c += (1.4142 if (q.x != prev.x and q.y != prev.y) else 1.0) * lg.get_point_weight_scale(q)
		prev = q
	return c


# --- danger ------------------------------------------------------------------------------

## Each side's danger map (0..4 per cluster); reweights only the clusters that changed.
func set_danger(team: int, values: PackedFloat32Array) -> void:
	var old: PackedFloat32Array = danger[team]
	danger[team] = values
	if not built:
		return
	var g: AStar3D = graphs[team + 1]
	for ci in NCC:
		if old[ci] != values[ci]:
			danger_n[team * NCC + ci] += 1
		if absf(old[ci] - values[ci]) < 0.05:
			continue
		var f := 1.0 + values[ci]
		for id in cl_nodes[ci]:
			g.set_point_weight_scale(id, f)
		for m in cl_mids[ci]:
			g.set_point_weight_scale(m, float(node_base.get(m, 1.0)) * f)
		mid_f[team * NCC + ci] = f


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
