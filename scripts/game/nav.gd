class_name Nav
extends RefCounted
## Two 1 m grids over the whole map (MapDims): one for infantry (low walls are vaultable,
## wire is slow), one for vehicles (walls are smashable, tank traps solid).

const N := MapDims.N
const H := MapDims.HALF
const FREE := 0
const LOW := 1
const SLOW := 2
const SOLID := 3
const PAD_INF := 0.25
const PAD_VEH := 1.7

var inf := AStarGrid2D.new()
var veh := AStarGrid2D.new()
var ikind := PackedByteArray()
var vkind := PackedByteArray()
var cell_objs := {}  # idx -> Array of [eid, ikind, vkind]
var heat := PackedByteArray()  # per cell: how many fires burn close enough to hurt (see Fires); routes go round
var terrain: TerrainMap
var hnav_i = null  # hierarchical graphs over the two grids (see hnav.gd)
var hnav_v = null


func _init() -> void:
	for g in [inf, veh]:
		g.region = Rect2i(0, 0, N, N)
		g.cell_size = Vector2(1, 1)
		g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		g.update()
	ikind.resize(N * N)
	vkind.resize(N * N)
	heat.resize(N * N)
	hnav_i = HNav.new(inf, false)
	hnav_v = HNav.new(veh, true)
	# keep vehicles off the outer rim (every cell set is passed on to the
	# hierarchical graphs, which keep their own copy: see HNav._solid)
	for i in N:
		for j in [0, 1, 2, N - 3, N - 2, N - 1]:
			for c: Vector2i in [Vector2i(i, j), Vector2i(j, i)]:
				veh.set_point_solid(c, true)
				hnav_v.mark_dirty(c)


# --- boats --------------------------------------------------------------------------

const BR := 2  # metres per boat cell
var boat := AStarGrid2D.new()
var boat_n := 0
var has_boats := false
var boat_body := PackedInt32Array()  # which stretch of water each cell is (-1 land): the sea, the river, each pond


## Open water for boats, 2 m cells (built once the water's laid): deep water
## is open; shallows are open but dear (a boat only noses in to put men
## ashore); land and bridges (too low to pass under) are not.
func build_boat_grid(w) -> void:
	if w == null or w.is_empty():
		return
	boat_n = N / BR
	boat.region = Rect2i(0, 0, boat_n, boat_n)
	boat.cell_size = Vector2(BR, BR)
	boat.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	boat.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	boat.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	boat.update()
	boat.fill_solid_region(boat.region, true)
	var tb: PackedByteArray = terrain.base
	for bz in boat_n:
		var row := bz * BR * N
		for bx in boat_n:
			var i0 := row + bx * BR
			if tb[i0] < TerrainMap.WATER:
				continue
			var deep := 0
			var wet := 0
			for dz in BR:
				for dx in BR:
					var i := i0 + dz * N + dx
					var k: int = tb[i]
					if k == TerrainMap.WATER and not w.on_deck_i(i):
						deep += 1
						wet += 1
					elif k == TerrainMap.SHALLOW:
						wet += 1
			if wet == BR * BR:
				boat.set_point_solid(Vector2i(bx, bz), false)
				if deep < BR * BR:
					boat.set_point_weight_scale(Vector2i(bx, bz), 5.0)
	has_boats = true
	# label the separate bodies of water (a boat can't get from one to another)
	boat_body.resize(boat_n * boat_n)
	boat_body.fill(-1)
	var label := 0
	for i in boat_n * boat_n:
		if boat_body[i] >= 0 or boat.is_point_solid(Vector2i(i % boat_n, i / boat_n)):
			continue
		var stack := [i]
		boat_body[i] = label
		while not stack.is_empty():
			var j: int = stack.pop_back()
			var jx := j % boat_n
			var jz := j / boat_n
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(jx, jz) + d
				if q.x < 0 or q.y < 0 or q.x >= boat_n or q.y >= boat_n:
					continue
				var k: int = q.y * boat_n + q.x
				if boat_body[k] < 0 and not boat.is_point_solid(q):
					boat_body[k] = label
					stack.append(k)
		label += 1


## Which body of water p is in (-1: none).
func water_body(p: Vector3) -> int:
	if not has_boats:
		return -1
	var c := boat_cell(p)
	return boat_body[c.y * boat_n + c.x]


func boat_cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(floori((p.x + H) / BR), 0, boat_n - 1), clampi(floori((p.z + H) / BR), 0, boat_n - 1))


func boat_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * BR - H, WaterMap.LEVEL, (c.y + 0.5) * BR - H)


## Can a boat be here?
func boat_ok(p: Vector3) -> bool:
	return has_boats and not boat.is_point_solid(boat_cell(p))


## Open water all the way from a to b, for a hull `half_w` metres either side
## of her keel (checked a cell apart down the middle and both sides).
func boat_line(a: Vector3, b: Vector3, half_w := 0.0) -> bool:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var dist := d.length()
	if dist < 0.01:
		return boat_ok(a)
	var side := Vector3(-d.z, 0.0, d.x) / dist * half_w
	for k in int(dist / BR) + 1:
		var p := a + d * minf(k * BR / dist, 1.0)
		if not boat_ok(p) or (half_w > 0.0 and (not boat_ok(p + side) or not boat_ok(p - side))):
			return false
	return boat_ok(b)


## The nearest water a boat can reach to p (within r metres) - in that body
## of water, if one is given - or INF.
func nearest_boat(p: Vector3, r := 60.0, body := -1) -> Vector3:
	if not has_boats:
		return Vector3.INF
	var c := boat_cell(p)
	if not boat.is_point_solid(c) and (body < 0 or boat_body[c.y * boat_n + c.x] == body):
		return boat_center(c)
	for k in range(1, int(r / BR) + 1):
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for dz in range(-k, k + 1):
			for dx in [-k, k] if absi(dz) != k else range(-k, k + 1):
				var q := c + Vector2i(dx, dz)
				if q.x < 0 or q.y < 0 or q.x >= boat_n or q.y >= boat_n or boat.is_point_solid(q):
					continue
				if body >= 0 and boat_body[q.y * boat_n + q.x] != body:
					continue
				var d := float(dx * dx + dz * dz)
				if d < bd:
					bd = d
					best = q
		if best.x >= 0:
			return boat_center(best)
	return Vector3.INF


## A boat's way across the water to (the water nearest) `to`; empty if
## there's none (another river, a lake, a bridge in the way).
func find_boat_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := nearest_boat(from, 30.0)
	if a == Vector3.INF:
		return out
	var b := nearest_boat(to, 160.0, water_body(a))  # (on the water it's on)
	if a == Vector3.INF or b == Vector3.INF:
		return out
	var pts := boat.get_point_path(boat_cell(a), boat_cell(b))
	for i in pts.size():
		if i % 3 != 0 and i != pts.size() - 1:
			continue  # (every 6 m is plenty to steer by)
		out.append(Vector3(pts[i].x + BR * 0.5 - H, WaterMap.LEVEL, pts[i].y + BR * 0.5 - H))
	return out


## Builds the abstract graphs once the map is laid out.
func finalize() -> void:
	HNav.build_all([hnav_i, hnav_v])


## Re-links clusters whose walls changed, a few a tick, infantry's first (a road
## being laid or a village flattened dirties dozens at once). Counted, not
## timed: if how much gets re-linked each tick hung on how fast this computer
## is, one seed would route men differently from one run to the next. (It was
## a 1.2 ms budget, when one cluster took several ms in GDScript, so in effect
## it was one a tick, now and then two. A repair now redoes only what changed,
## well under a millisecond as a rule.)
func update_hier(clusters := 1) -> void:
	for i in clusters:
		if not hnav_i.dirty.is_empty():
			hnav_i.update(1)
		elif not hnav_v.dirty.is_empty():
			hnav_v.update(1)
		else:
			return


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(clampi(floori(p.x + H), 0, N - 1), clampi(floori(p.z + H), 0, N - 1))


func center(c: Vector2i) -> Vector3:
	return Vector3(c.x - H + 0.5, 0.0, c.y - H + 0.5)


func kind_at(p: Vector3) -> int:
	var c := cell_of(p)
	return ikind[c.y * N + c.x]


func vkind_at(p: Vector3) -> int:
	var c := cell_of(p)
	return vkind[c.y * N + c.x]


func walkable(p: Vector3) -> bool:
	return kind_at(p) != SOLID


func add_structure(st: Structure) -> void:
	for part in st.nav_parts():
		_raster(st, part)


func remove_structure(st: Structure) -> void:
	var touched := {}
	for idx in st.nav_cells:
		touched[idx] = true
	st.nav_cells.clear()
	for idx in touched:
		var a: Array = cell_objs.get(idx, [])
		for i in range(a.size() - 1, -1, -1):
			if a[i][0] == st.eid:
				a.remove_at(i)
		if a.is_empty():
			cell_objs.erase(idx)
		_recompute(idx)


func _raster(st: Structure, part: Dictionary) -> void:
	var c: Vector2 = part.c
	var h: Vector2 = part.h
	var yaw: float = part.yaw
	var ik: int = part.i
	var vk: int = part.v
	if ik == FREE and vk == FREE:
		return
	var pad := PAD_VEH if vk != FREE else PAD_INF
	var ex := absf(cos(yaw)) * (h.x + pad) + absf(sin(yaw)) * (h.y + pad)
	var ez := absf(sin(yaw)) * (h.x + pad) + absf(cos(yaw)) * (h.y + pad)
	var x0 := clampi(floori(c.x - ex + H), 0, N - 1)
	var x1 := clampi(floori(c.x + ex + H), 0, N - 1)
	var z0 := clampi(floori(c.y - ez + H), 0, N - 1)
	var z1 := clampi(floori(c.y + ez + H), 0, N - 1)
	var hi := h + Vector2(PAD_INF, PAD_INF)
	var hv := h + Vector2(PAD_VEH, PAD_VEH)
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var p := Vector2(x - H + 0.5, z - H + 0.5)
			var in_i := ik != FREE and Defs.point_in_obb(p, c, hi, yaw)
			var in_v := vk != FREE and Defs.point_in_obb(p, c, hv, yaw)
			if not in_i and not in_v:
				continue
			var idx := z * N + x
			var a = cell_objs.get(idx)
			if a == null:
				a = []
				cell_objs[idx] = a
			a.append([st.eid, ik if in_i else FREE, vk if in_v else FREE])
			st.nav_cells.append(idx)
			_recompute(idx)


func _recompute(idx: int) -> void:
	var ik := 0
	var vk := 0
	for o in cell_objs.get(idx, []):
		ik = maxi(ik, o[1])
		vk = maxi(vk, o[2])
	if terrain and terrain.base[idx] == TerrainMap.WATER and not terrain.world.water.on_deck_i(idx):
		ik = SOLID  # deep water: nobody walks or drives through it (boats have their own grid)
		vk = SOLID
	ikind[idx] = ik
	vkind[idx] = vk
	var c := Vector2i(idx % N, idx / N)
	var ti := terrain.nav_weight(idx, false) if terrain else 1.0
	var tv := terrain.nav_weight(idx, true) if terrain else 1.0
	if heat[idx] > 0:
		# a fire: men go well round it if there's any way round at all, and
		# drivers would rather not
		ti *= 8.0
		tv *= 2.5
	inf.set_point_solid(c, ik == SOLID)
	inf.set_point_weight_scale(c, [1.0, 4.0, 7.0, 1.0][ik] * ti)
	var rim := c.x < 3 or c.y < 3 or c.x >= N - 3 or c.y >= N - 3
	veh.set_point_solid(c, vk == SOLID or rim)
	veh.set_point_weight_scale(c, (1.0 if vk == FREE else 9.0) * tv)
	if hnav_i:
		hnav_i.mark_dirty(c)
	if hnav_v:
		hnav_v.mark_dirty(c)


func terrain_changed(idx: int) -> void:
	_recompute(idx)


## A fire takes hold (d = 1) or goes out (d = -1) over the ground within r
## of p: routes planned from now on go round it.
func stamp_heat(p: Vector3, r: float, d: int) -> void:
	var c := cell_of(p)
	var ri := int(ceil(r))
	for z in range(maxi(0, c.y - ri), mini(N, c.y + ri + 1)):
		for x in range(maxi(0, c.x - ri), mini(N, c.x + ri + 1)):
			if Vector2(x + 0.5 - H - p.x, z + 0.5 - H - p.z).length() > r:
				continue
			var idx := z * N + x
			var was := heat[idx] > 0
			heat[idx] = clampi(heat[idx] + d, 0, 255)
			if (heat[idx] > 0) != was:
				_recompute(idx)


func _nearest_free(g: AStarGrid2D, c: Vector2i) -> Vector2i:
	for r in range(1, 10):
		for dx in range(-r, r + 1):
			for dz in [-r, r]:
				var a := Vector2i(c.x + dx, c.y + dz)
				if g.is_in_boundsv(a) and not g.is_point_solid(a):
					return a
				var b := Vector2i(c.x + dz, c.y + dx)
				if g.is_in_boundsv(b) and not g.is_point_solid(b):
					return b
	return c


func nearest_walkable(p: Vector3, vehicle := false) -> Vector3:
	var g := veh if vehicle else inf
	var c := cell_of(p)
	if not g.is_point_solid(c):
		return p
	return center(_nearest_free(g, c))


## `team` and `care` (0 = shortest, 1+ = keep well clear of known enemy fire)
## feed the tactical cost of the hierarchical planner used for longer trips.
func find_path(from: Vector3, to: Vector3, vehicle := false, team := -1, care := 0.0) -> PackedVector3Array:
	var g := veh if vehicle else inf
	var a := cell_of(from)
	var b := cell_of(to)
	var end_exact := true
	if g.is_point_solid(a):
		a = _nearest_free(g, a)
	if g.is_point_solid(b):
		b = _nearest_free(g, b)
		end_exact = false
	var out := PackedVector3Array()
	if a == b:
		out.append(to if end_exact or Defs.flat(center(b) - to).length() < 1.7 else center(b))
		return out
	var ids: Array[Vector2i] = []
	var h: HNav = hnav_v if vehicle else hnav_i
	var span := maxi(absi(a.x - b.x), absi(a.y - b.y))
	if h and h.built and (span > 40 or (care > 0.0 and span > 20)):
		ids = _hier_path(h, g, a, b, team, care)
	if ids.is_empty():
		ids = g.get_id_path(a, b, true)
	if ids.is_empty():
		return out
	var pts: Array = []
	for c in ids:
		pts.append(center(c))
	if end_exact and ids[ids.size() - 1] == b:
		pts[pts.size() - 1] = Vector3(to.x, 0.0, to.z)
	elif not end_exact and ids[ids.size() - 1] == b and Defs.flat(center(b) - to).length() < 1.7:
		# goal sits in a padded cell next to a wall (e.g. a cover spot): finish with a short direct step
		pts.append(Vector3(to.x, 0.0, to.z))
	# string-pull smoothing through free cells
	var i := 0
	var last := pts.size() - 1
	while i < last:
		var j := mini(last, i + 14)
		while j > i + 1 and not _line_free(pts[i], pts[j], vehicle):
			j -= 1
		out.append(pts[j])
		i = j
	return out


## Abstract route, then each leg refined on the cluster's own small grid.
func _hier_path(h: HNav, g: AStarGrid2D, a: Vector2i, b: Vector2i, team: int, care: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var wps: Array[Vector2i] = h.route(a, b, team, care)
	if wps.size() < 2:
		return out
	out.append(wps[0])
	for k in range(1, wps.size()):
		var p := wps[k - 1]
		var q := wps[k]
		if p == q:
			continue
		if absi(p.x - q.x) <= 1 and absi(p.y - q.y) <= 1:
			out.append(q)
			continue
		var cp := h.cluster_of(p)
		var seg: Array[Vector2i] = []
		if cp == h.cluster_of(q):
			seg = h.local_grid(cp).get_id_path(p, q)
		if seg.is_empty():
			seg = g.get_id_path(p, q)
		if seg.is_empty():
			out.clear()
			return out
		for j in range(1, seg.size()):
			out.append(seg[j])
	return out


func _line_free(a: Vector3, b: Vector3, vehicle: bool) -> bool:
	var d := b - a
	var steps := int(d.length() / 0.5) + 1
	var arr := vkind if vehicle else ikind
	# (smoothing mustn't cut back through a fire the route went round - unless
	# it starts in one, when the way out is the way out)
	var ca := cell_of(a)
	var mind_fire := not vehicle and heat[ca.y * N + ca.x] == 0
	for s in range(1, steps):
		var p := a + d * (float(s) / steps)
		var c := cell_of(p)
		if arr[c.y * N + c.x] != FREE:
			return false
		if mind_fire and heat[c.y * N + c.x] > 0:
			return false
	return true


## Debug: compare hierarchical and flat routes on random trips.
func benchmark(rng: RandomNumberGenerator) -> void:
	for vehicle in [false, true]:
		var g := veh if vehicle else inf
		var h: HNav = hnav_v if vehicle else hnav_i
		var n := 0
		var ratio := 0.0
		var worst := 0.0
		var t_flat := 0
		var t_hier := 0
		var fails := 0
		var on_road := 0
		var cells := 0
		var road_total := 0
		if terrain:
			for i in N * N:
				road_total += 1 if terrain.base[i] == TerrainMap.ROAD else 0
		for k in 150:
			var a := Vector2i(rng.randi_range(4, N - 5), rng.randi_range(4, N - 5))
			var b := Vector2i(rng.randi_range(4, N - 5), rng.randi_range(4, N - 5))
			if g.is_point_solid(a) or g.is_point_solid(b):
				continue
			var t0 := Time.get_ticks_usec()
			var f: Array[Vector2i] = g.get_id_path(a, b)
			var t1 := Time.get_ticks_usec()
			var hp := _hier_path(h, g, a, b, -1, 0.0)
			var t2 := Time.get_ticks_usec()
			t_flat += t1 - t0
			t_hier += t2 - t1
			if f.is_empty():
				continue
			if hp.is_empty():
				fails += 1
				continue
			var lf := _plen(f)
			var lh := _plen(hp)
			if terrain:
				for c in hp:
					on_road += 1 if terrain.base[c.y * N + c.x] == TerrainMap.ROAD else 0
					cells += 1
			n += 1
			ratio += lh / maxf(lf, 1.0)
			worst = maxf(worst, lh / maxf(lf, 1.0))
		print("HPA %s: %d trips, length x%.3f avg (worst x%.2f), %d fails, flat %.2f ms/trip, hier %.2f ms/trip, %.0f%% of path on roads (roads are %.0f%% of the map)" % ["veh" if vehicle else "inf", n, ratio / maxf(n, 1), worst, fails, t_flat / 1000.0 / maxf(n, 1), t_hier / 1000.0 / maxf(n, 1), 100.0 * on_road / maxf(1, cells), 100.0 * road_total / float(N * N)])


func _plen(p: Array[Vector2i]) -> float:
	var l := 0.0
	for i in range(1, p.size()):
		l += Vector2(p[i] - p[i - 1]).length()
	return l
