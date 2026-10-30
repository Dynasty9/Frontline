class_name HNav
extends RefCounted
## Hierarchical A* (HPA*) over one of Nav's 1 m grids.
##
## The 1 m grid is cut into 16 m clusters (32 x 32 of them on a 512 m map). Wherever two neighbouring
## clusters share an open stretch of border there is an entrance (a pair of
## abstract nodes). Inside each cluster the true cost between its entrances is
## precomputed on a small local grid (made from the full one when it's wanted,
## and the most recently used kept). Long paths are planned on this abstract
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
## Costs stay inside native search (no script callbacks): every intra-cluster
## edge runs through a "mid" node whose weight makes the two halves add up to
## the true cost. There are three copies of the graph: a plain one, and one per
## side whose weights are scaled by that side's danger map (the clusters its
## spotted enemies cover), so careful moves route around known fire. RouteGraph
## skips degree-two search states while retaining both edge costs and waypoints;
## platforms without the extension use the same graph through AStar3D.

static var C := 16
static var NC := 64
static var NCC := 4096
const PLAIN := 0
const UNKNOWN := -2.0  # a cost not worked out yet (-1 is "no way through")
## Each cluster's corner cell. The build's worker threads look a cluster's
## place up here rather than work it out with / and % (see build_all).
static var _corner: Array[Vector2i] = _corners()

var grid: Object
var _core: RefCounted
var _use_native := true

class NativeLocalGrid extends RefCounted:
	# Inspection tools keep the grid API; gameplay calls local_path directly.
	var core: RefCounted
	var source: Object
	var cluster: int
	func get_id_path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
		return core.local_path(cluster, a, b)
	func is_point_solid(c: Vector2i) -> bool:
		return source.is_point_solid(c)
	func get_point_weight_scale(c: Vector2i) -> float:
		return source.get_point_weight_scale(c)
var vehicle := false
var graphs: Array = []  # [plain, team 0 view, team 1 view]
var g_team: Array = []  # (the last two again)
## Small grids covering one cluster each, for the searches inside it. Kept
## for every cluster (4096 on a full map) they came to 77 MB a graph, copies
## of what the full grid holds, so a cluster's is made when it's wanted and
## the last CACHE_CELLS cells used are kept: a battle's paths keep to the ground it's
## fought over.
const CACHE_CELLS := 131072
var _local := {}  # cluster -> grid, least recently used first
## The full grid's cells as plain arrays (solid 1/0; weight), kept in step by
## mark_dirty: a cluster's grid is made from these far quicker than by asking
## the full grid cell by cell, and the build's worker threads can all read
## them (many threads reading one AStarGrid2D ran slower than one alone).
## They start as a new grid does (open, weight 1) and follow every cell Nav
## sets, from the first, so a new map never has to be read back cell by cell.
var _solid := PackedByteArray()
var _weight := PackedFloat32Array()
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
var terrain_revision := 0
var danger_revision := [0, 0]
var built := false
var danger: Array = [PackedFloat32Array(), PackedFloat32Array()]
# What a rebuild needs to tell what changed:
var ver := PackedInt32Array()  # per cluster: goes up whenever one of its cells really changes
var edge_ver := PackedInt32Array()  # per cluster side (left, right, top, bottom): the same, for the cells along that edge
var link_ver := PackedInt32Array()  # per cluster: its ver when its links were last worked out
var basis: Array = []  # per cluster: the entrance ids its costs are listed by
var costs: Array = []  # per cluster: the costs between them, as a square table (see _relink)
var _keys: Array = []  # while building: what each cluster's costs hang on (see _cluster_key)
var mid_f := PackedFloat64Array()  # per side, per cluster: the danger factor its mids carry
var danger_n := PackedInt32Array()  # per side, per cluster: goes up whenever its danger changes at all
var border_dn := {}  # _bkey -> Vector4i: the danger_n of each side when its entrances were last weighted


func _init(g: Object, is_vehicle: bool, use_native := true) -> void:
	NCC = NC * NC
	_corner = _corners()
	grid = g
	_use_native = use_native
	vehicle = is_vehicle
	for i in 3:
		graphs.append(ClassDB.instantiate("RouteGraph") if ClassDB.class_exists("RouteGraph") else AStar3D.new())
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
	_solid.resize(MapDims.N * MapDims.N)
	_weight.resize(MapDims.N * MapDims.N)
	_weight.fill(1.0)


## Cluster ci's own grid, its cells as the full grid has them now.
func local_grid(ci: int) -> Object:
	if _core:
		var view := NativeLocalGrid.new()
		view.core = _core
		view.source = grid
		view.cluster = ci
		return view
	var cached: Object = _local.get(ci)
	if cached != null:
		# Dictionary insertion order keeps eviction independent of cache size.
		_local.erase(ci)
		_local[ci] = cached
		return cached
	if _local.size() >= CACHE_CELLS / (C * C):
		var old := -1
		for k: int in _local:
			old = k
			break
		_local.erase(old)
	var lg := _local_from(ci, _solid, _weight)
	_local[ci] = lg
	return lg


## A grid for cluster ci with the cells `solid` and `weight` (full-map arrays)
## give it. Only those unlike a fresh grid's (open, weight 1) need setting:
## walls, water and roads.
static func _local_from(ci: int, solid: PackedByteArray, weight: PackedFloat32Array) -> Object:
	var o := _corner[ci]
	var lg := make_grid(Rect2i(o, Vector2i(C, C)))
	var n := MapDims.N
	var x0 := o.x
	var z0 := o.y
	if lg.has_method("load_cells"):
		var cells := PackedByteArray()
		var weights := PackedFloat32Array()
		for z in range(z0, z0 + C):
			cells.append_array(solid.slice(z * n + x0, z * n + x0 + C))
			weights.append_array(weight.slice(z * n + x0, z * n + x0 + C))
		var valid: bool = lg.load_cells(cells, weights)
		assert(valid, "Invalid navigation cells")
		return lg
	for z in range(z0, z0 + C):
		var row := z * n
		for x in range(x0, x0 + C):
			if solid[row + x] != 0:
				lg.set_point_solid(Vector2i(x, z))
			var w := weight[row + x]
			if w != 1.0:
				lg.set_point_weight_scale(Vector2i(x, z), w)
	return lg


static func make_grid(region: Rect2i, cell_size := Vector2.ONE) -> Object:
	if ClassDB.class_exists("NavigationGridCore"):
		var core: RefCounted = ClassDB.instantiate("NavigationGridCore")
		if core.configure(region, cell_size):
			return core
		push_error("Invalid native navigation grid dimensions")
	var grid := AStarGrid2D.new()
	grid.region = region
	grid.cell_size = cell_size
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	return grid


func cluster_of(c: Vector2i) -> int:
	return clampi(c.y / C, 0, NC - 1) * NC + clampi(c.x / C, 0, NC - 1)


static func _corners() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for ci in NCC:
		out.append(Vector2i((ci % NC) * C, (ci / NC) * C))
	return out


static func _key(a: int, b: int) -> int:
	return mini(a, b) * 2147483648 + maxi(a, b)  # (ids stay well under 2^31)


## Nav changed a cell's solidity / weight: mirror it and queue the cluster.
## (Nav reports every cell it sets, from the start: see _solid.)
func mark_dirty(c: Vector2i) -> void:
	if _core:
		var valid: bool = _core.set_cell(c, grid.is_point_solid(c), grid.get_point_weight_scale(c))
		assert(valid, "Invalid hierarchical terrain edit")
		terrain_revision = _core.terrain_revision()
		return
	var ci := cluster_of(c)
	var solid: bool = grid.is_point_solid(c)
	var w: float = grid.get_point_weight_scale(c)
	var i := c.y * MapDims.N + c.x
	if (_solid[i] != 0) == solid and _weight[i] == w:
		return
	if built:
		# (most calls change nothing: a wall raised where the ground was already blocked)
		terrain_revision += 1
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
	_solid[i] = 1 if solid else 0
	_weight[i] = w
	var lg: Object = _local.get(ci)
	if lg != null:
		lg.set_point_solid(c, solid)
		lg.set_point_weight_scale(c, w)
	if built:
		dirty[ci] = true


func build() -> void:
	build_all([self])


## Whole graphs, for a new map: the slow part of starting a battle (tens of
## thousands of entrances on each, and a few hundred small searches inside
## every cluster to cost them). The infantry and vehicle graphs share
## nothing; searches on each cluster's own local grid are shared across workers.
## Graph assembly stays on the main thread for the native extension bindings.
## Each graph is still put together in one fixed order, so its ids, and every
## route planned on it, come out exactly as they would with no threads at all.
##
## Most clusters are much like others: open ground with its entrances in the
## same places (on a scenario's map nearly all of them; on a battle's, half).
## A search inside a cluster depends only on its cells and where in it the two
## entrances are, not on where the cluster is, so clusters alike in every cell
## and entrance, in either graph, are costed once and share the result.
##
## What the workers run keeps clear of a race in GDScript itself
## (godotengine/godot#124010). An operator on values whose type the compiler
## can't tell (untyped ones, or objects: `lg == null` was one) works out
## which routine to use the first time it runs and writes that into the
## function's code, and another thread on the same line at that moment can
## read it half-written and crash. In an exported game, whole-number / and %
## do the same. So whatever two workers may run at once keeps to typed values
## and never divides whole numbers: a cluster's corner comes from _corner,
## and each graph's clusters go to the workers as tasks of their own rather
## than numbered across both graphs and divided back out.
static func build_all(navs: Array) -> void:
	if ClassDB.class_exists("HierarchyCore") and navs.all(func(h: HNav) -> bool: return h._use_native):
		for h: HNav in navs:
			h._core = ClassDB.instantiate("HierarchyCore")
			var configured: bool = h._core.configure(MapDims.N, C)
			var loaded: bool = h._core.load_cells(h._solid, h._weight)
			assert(configured and loaded, "Invalid hierarchical terrain")
			for team in 2:
				var valid: bool = h._core.set_danger(team, h.danger[team])
				assert(valid, "Invalid initial danger map")
		if navs.size() == 2:
			var built_pair: bool = navs[0]._core.build_with(navs[1]._core)
			assert(built_pair, "Native hierarchy build failed")
		else:
			for h: HNav in navs:
				var built_one: bool = h._core.build()
				assert(built_one, "Native hierarchy build failed")
		for h: HNav in navs:
			h.built = true
			h._solid.clear()
			h._weight.clear()
			h._local.clear()
			h.dirty.clear()
		return
	# The extension bindings belong to the main thread; local-grid costing stays parallel.
	for h: HNav in navs:
		h._prepare()
	var tasks := PackedInt64Array()
	for h: HNav in navs:
		tasks.append(WorkerThreadPool.add_group_task(h._cluster_key, NCC, -1, true, "Nav: cluster keys"))
	for g in tasks:
		WorkerThreadPool.wait_for_group_task_completion(g)
	var first := {}  # key -> the cluster (nav * NCC + ci) costed for it
	var todo: Array[PackedInt32Array] = []  # per nav: the clusters to cost
	var alike := PackedInt32Array()  # cluster, and the one it shares with, in turn
	for i in navs.size():
		var keys: Array = (navs[i] as HNav)._keys
		var own := PackedInt32Array()
		for ci in NCC:
			var key: PackedByteArray = keys[ci]
			if key.is_empty():
				continue  # (costed already: nothing to cost)
			var slot := i * NCC + ci
			var was: int = first.get(key, -1)
			if was < 0:
				first[key] = slot
				own.append(ci)
			else:
				alike.append(slot)
				alike.append(was)
		todo.append(own)
	tasks.clear()
	for i in navs.size():
		var h: HNav = navs[i]
		var cls := todo[i]
		if not cls.is_empty():
			if ClassDB.class_exists("NavigationGridCore"):
				var batch: RefCounted = ClassDB.instantiate("NavigationGridCore")
				var origins: Array[Vector2i] = []
				var entrances: Array[PackedInt32Array] = []
				for ci in cls:
					origins.append(_corner[ci])
					var cells := PackedInt32Array()
					for id: int in h.cl_nodes[ci]:
						var p: Vector2i = h.node_cell[id]
						cells.append(p.x)
						cells.append(p.y)
					entrances.append(cells)
				var results: Array = batch.cluster_costs(MapDims.N, C, h._solid, h._weight, origins, entrances)
				assert(results.size() == cls.size(), "Native cluster cost calculation failed")
				for j in cls.size():
					h.costs[cls[j]] = results[j]
			else:
				tasks.append(WorkerThreadPool.add_group_task(func(j: int): h._cluster_costs(cls[j]), cls.size(), -1, true, "Nav: entrance costs"))
	for g in tasks:
		WorkerThreadPool.wait_for_group_task_completion(g)
	for q in range(0, alike.size(), 2):
		var d := alike[q]
		var r := alike[q + 1]
		(navs[d / NCC] as HNav).costs[d % NCC] = (navs[r / NCC] as HNav).costs[r % NCC]
	for h: HNav in navs:
		h._keys = []
	for h: HNav in navs:
		h._link_all()


## The entrances along every border.
func _prepare() -> void:
	for cz in NC:
		for cx in NC:
			var ci := cz * NC + cx
			if cx < NC - 1:
				_make_border(ci, ci + 1, _border_picks(ci, ci + 1))
			if cz < NC - 1:
				_make_border(ci, ci + NC, _border_picks(ci, ci + NC))
	_keys.resize(NCC)


## (On a worker thread.) Everything cluster ci's costs hang on, as bytes:
## its cells (solid, weight) and its entrances' places in it, in the order
## they're listed (which decides which way round each pair is costed). An
## empty key: it has fewer than two entrances, so nothing to cost. The
## workers each fill in only their own cluster's slot: resizing the arrays is
## what isn't safe from several threads at once.
func _cluster_key(ci: int) -> void:
	var nodes: Array = cl_nodes[ci]
	basis[ci] = nodes.duplicate()
	if nodes.size() < 2:
		costs[ci] = _pair_costs(ci, null)  # (nothing to cost, so no grid to make)
		_keys[ci] = PackedByteArray()
		return
	var n := MapDims.N
	var x0 := _corner[ci].x
	var z0 := _corner[ci].y
	var key := PackedByteArray()
	var wts := PackedFloat32Array()
	for z in range(z0, z0 + C):
		key.append_array(_solid.slice(z * n + x0, z * n + x0 + C))
		wts.append_array(_weight.slice(z * n + x0, z * n + x0 + C))
	key.append_array(wts.to_byte_array())
	for id: int in nodes:
		var c: Vector2i = node_cell[id]
		# A 32 m cluster has more than 256 cells: one byte aliases different entrances.
		key.append(c.x - x0)
		key.append(c.y - z0)
	_keys[ci] = key


## (On a worker thread.) A cluster's grid of its own, for its costs alone.
func _cluster_costs(ci: int) -> void:
	costs[ci] = _pair_costs(ci, _local_from(ci, _solid, _weight))


## Every cluster's links, in order, on the main thread.
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
	if _core:
		var valid: bool = _core.update(budget)
		assert(valid, "Invalid native hierarchy update")
		return
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
	var lg: Object = null  # (made only if something needs searching)
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
				if lg == null:
					lg = local_grid(k)
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
		graphs[PLAIN].set_point_weight_scale(m, w)
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
		var g = g_team[t]
		for m: int in cl_mids[k]:
			g.set_point_weight_scale(m, float(node_base[m]) * f)


# --- graph plumbing (all three copies move together) --------------------------------------

## (Each team's copy weighs a node by that side's danger where it stands.)
func _g_add(id: int, pos: Vector3, ci: int, base := 1.0) -> void:
	node_cl[id] = ci
	graphs[PLAIN].add_point(id, pos, base)
	g_team[0].add_point(id, pos, base * (1.0 + float(danger[0][ci])))
	g_team[1].add_point(id, pos, base * (1.0 + float(danger[1][ci])))


func _g_connect(a: int, b: int) -> void:
	graphs[PLAIN].connect_points(a, b)
	g_team[0].connect_points(a, b)
	g_team[1].connect_points(a, b)


func _g_remove(id: int) -> void:
	node_cl.erase(id)
	node_base.erase(id)
	for g in graphs:
		if g.has_point(id):
			g.remove_point(id)


## Joins a and b through a mid node so that walking a -> mid -> b costs `c`.
func _link(a: int, b: int, c: float, ci: int, temp) -> void:
	var g0 = graphs[PLAIN]
	var pa: Vector3 = g0.get_point_position(a)
	var pb: Vector3 = g0.get_point_position(b)
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
	var ax := _corner[a].x
	var az := _corner[a].y
	# (the cells along it, a's side and b's, read from the mirror of the full
	# grid: as indices, the first pair and the step from one pair to the next)
	var n := MapDims.N
	var ia := az * n + ax + C - 1 if side_by_side else (az + C - 1) * n + ax
	var ib := ia + 1 if side_by_side else ia + n
	var step := n if side_by_side else 1
	var out := PackedInt32Array()
	var run_start := -1
	for i in C + 1:
		var open := false
		if i < C:
			open = _solid[ia + i * step] == 0 and _solid[ib + i * step] == 0
		if open and run_start < 0:
			run_start = i
		elif not open and run_start >= 0:
			var run_end := i - 1
			var picks := []
			# (halves by >> 1, not / 2, on the workers: see build_all)
			if run_end - run_start < 6:
				picks.append((run_start + run_end) >> 1)
			else:
				picks.append(run_start + 2)
				picks.append(run_end - 2)
			# and wherever a road (a cheap stretch) crosses the border, so routes can follow it
			var cheap_start := -1
			for j in range(run_start, run_end + 2):
				var cheap := false
				if j <= run_end:
					cheap = _weight[ib + j * step] < 0.95
				if cheap and cheap_start < 0:
					cheap_start = j
				elif not cheap and cheap_start >= 0:
					var mid := (cheap_start + j - 1) >> 1
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
	var ax := _corner[a].x
	var az := _corner[a].y
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
## found (for a new graph: nothing is linked yet). It's _link, pair by pair,
## with what _link looks up for each (positions, danger) worked out once: the
## same nodes, ids and weights, added to each graph in the same order.
func _intra(ci: int) -> void:
	var cm: PackedFloat64Array = costs[ci]
	var nodes: Array = cl_nodes[ci]
	var n := nodes.size()
	if n < 2:
		return
	var g0 = graphs[PLAIN]
	var g1 = g_team[0]
	var g2 = g_team[1]
	var f1 := 1.0 + float(danger[0][ci])
	var f2 := 1.0 + float(danger[1][ci])
	var own: Dictionary = cl_mids[ci]
	var pos := PackedVector3Array()
	pos.resize(n)
	for i in n:
		var c: Vector2i = node_cell[nodes[i]]
		pos[i] = Vector3(c.x + 0.5, 0, c.y + 0.5)
	for i in n:
		var a: int = nodes[i]
		var pa := pos[i]
		for j in range(i + 1, n):
			var c := cm[i * n + j]
			if c < 0.0:
				continue
			var b: int = nodes[j]
			var pb := pos[j]
			var l := pa.distance_to(pb)
			if l < 0.5:
				g0.connect_points(a, b)
				g1.connect_points(a, b)
				g2.connect_points(a, b)
				continue
			var w := clampf(2.0 * c / l - 1.0, 0.05, 60.0)
			var m := next_id
			next_id += 1
			node_base[m] = w
			node_cl[m] = ci
			var pm := (pa + pb) * 0.5
			g0.add_point(m, pm, w)
			g1.add_point(m, pm, w * f1)
			g2.add_point(m, pm, w * f2)
			g0.connect_points(a, m)
			g1.connect_points(a, m)
			g2.connect_points(a, m)
			g0.connect_points(m, b)
			g1.connect_points(m, b)
			g2.connect_points(m, b)
			mids[mini(a, b) * 2147483648 + maxi(a, b)] = m
			own[m] = true


## The cost of walking between each pair of the cluster's entrances (-1: no
## way through), as an n x n table: [i * n + j] is from entrance i to entrance
## j, worked out for i < j (the way round _intra links them). Only reads the
## graph, and searches only lg, this cluster's own grid, so clusters can be
## done side by side. With fewer than two entrances there's nothing to search
## and lg may be null (it isn't checked for null: see build_all).
func _pair_costs(ci: int, lg: Object) -> PackedFloat64Array:
	var nodes: Array = cl_nodes[ci]
	var n := nodes.size()
	var out := PackedFloat64Array()
	out.resize(n * n)
	out.fill(UNKNOWN)
	if n < 2:
		return out
	if lg.has_method("pair_costs"):
		var cells: Array[Vector2i] = []
		for id: int in nodes:
			cells.append(node_cell[id])
		return lg.pair_costs(cells)
	for i in n:
		for j in range(i + 1, n):
			out[i * n + j] = _local_cost(lg, node_cell[nodes[i]], node_cell[nodes[j]])
	return out


func _local_cost(lg: Object, a: Vector2i, b: Vector2i) -> float:
	if lg.has_method("path_cost"):
		return lg.path_cost(a, b)
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
	if _core:
		var valid: bool = _core.set_danger(team, values)
		assert(valid, "Invalid native danger map")
		danger[team] = values
		danger_revision[team] = _core.danger_revision(team)
		return
	var old: PackedFloat32Array = danger[team]
	danger[team] = values
	if not built:
		return
	var g = graphs[team + 1]
	for ci in NCC:
		if old[ci] != values[ci]:
			danger_n[team * NCC + ci] += 1
		if absf(old[ci] - values[ci]) < 0.05:
			continue
		danger_revision[team] += 1
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
	if _core:
		return _core.route(a, b, team, care)
	var out: Array[Vector2i] = []
	if not built:
		build()
		if _core:
			return _core.route(a, b, team, care)
	var gi := team + 1 if care > 0.0 and team >= 0 and team < 2 else PLAIN
	var g = graphs[gi]
	var ca := cluster_of(a)
	var cb := cluster_of(b)
	var s_id := next_id
	var g_id := next_id + 1
	next_id += 2
	var temp := []
	_g_add(s_id, Vector3(a.x + 0.5, 0, a.y + 0.5), ca)
	_g_add(g_id, Vector3(b.x + 0.5, 0, b.y + 0.5), cb)
	var la := local_grid(ca)
	var lb := local_grid(cb)
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
	var ids: PackedInt64Array = g.get_id_path(s_id, g_id)
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
	if _core:
		var counts: Vector2i = _core.counts()
		return "%d entrances, %d nodes" % [counts.x, counts.y]
	return "%d entrances, %d nodes" % [node_cell.size(), graphs[PLAIN].get_point_count()]


func has_work() -> bool:
	if _core:
		return _core.has_work()
	return not dirty.is_empty()


func local_path(ci: int, a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	return _core.local_path(ci, a, b) if _core else local_grid(ci).get_id_path(a, b)
