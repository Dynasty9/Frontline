class_name TownGen
extends RefCounted
## Lays out the built-up parts of the map so they read like real places: a
## town on a street grid around a square (houses on lots facing the street,
## gardens behind them closed off by hedges and fences, sidewalks, street
## lights, power lines with drops to the houses, a playground, a park, shops
## near the middle), hamlets strung along the country road, farmsteads with
## orchards, and hedged fields laid out along the roads.
##
## Anything that matters to the fighting (walls, hedges, trees, cars, crates)
## is a structure. Street furniture goes into world.decor and is drawn by
## Decor on each client.

const ROAD_HW := 2.9
const CURB := 3.0  # curb line, from the street's centre line
const WALK := 4.8  # back of the sidewalk
const FRONT := 5.2  # lot frontage line
const S := 40.0  # between parallel streets
const REACH := 56.0  # the main streets run this far each way from the middle
const LOT_D := 14.5  # lot depth

var mg  # MapGen
var world
var rng: RandomNumberGenerator
var decor: Array = []  # [kind, pos, yaw, extra]
var center := Vector3.ZERO
var pieces: Array = []  # straight street pieces [a, b, main?]
var node_dirs := {}  # Vector2i (rounded node) -> {Vector2i direction: true}
var rect := Rect2()
var main_road := PackedVector3Array()  # HQ to HQ through the town
var cross_road := PackedVector3Array()  # edge to edge through the town
var hamlet := {}  # the first of the hamlets
var hamlets: Array = []  # {"c": centre, "d": road direction} of every village on the country roads
var poles: Array = []  # [base, yaw] of every utility pole (town and country)
var _fronts: Array = []  # front wall tops of houses, for the service drops
var _fence_keys := {}
var _depth := LOT_D  # depth of the lot being built (shallower where the block is crowded)
var _special := {}


func _init(m) -> void:
	mg = m
	world = m.world
	rng = m.rng


func _d(kind: String, p: Vector3, yaw := 0.0, extra = null) -> void:
	decor.append([kind, p, yaw, extra])


static func yaw_along(d: Vector3) -> float:
	return atan2(-d.z, d.x)  # local +x runs along d


static func _perp(d: Vector3) -> Vector3:
	return Vector3(-d.z, 0, d.x)


static func _key(p: Vector3) -> Vector2i:
	return Vector2i(int(round(p.x)), int(round(p.z)))


static func _dkey(d: Vector3) -> Vector2i:
	return Vector2i(int(round(d.x)), int(round(d.z)))


func _has_dir(node: Vector3, d: Vector3) -> bool:
	return (node_dirs.get(_key(node), {}) as Dictionary).has(_dkey(d))


func _straight(a: Vector3, b: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := maxi(1, int(ceil(a.distance_to(b) / 3.0)))
	for i in n + 1:
		out.append(a.lerp(b, float(i) / n))
	return out


## Paved things are road as far as the fighting goes: quick to cross, no cover.
func _pave(p: Vector3, yaw: float, size: Vector3) -> void:
	if world.terrain:
		world.terrain.paint_box(p, Vector2(size.x * 0.5, size.z * 0.5), yaw, TerrainMap.ROAD)


func _reserve(p: Vector3, half: Vector2, yaw: float) -> void:
	mg.placed.append([Vector2(p.x, p.z), half, yaw])


# --- the street plan ---------------------------------------------------------------

func plan_town(c: Vector3) -> void:
	center = c
	rect = Rect2(c.x - REACH, c.z - REACH, REACH * 2.0, REACH * 2.0)
	# the two main streets cross in the middle; side streets close some of the blocks
	for ax: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var stops := [-REACH, -S, 0.0, S, REACH]
		for i in 4:
			pieces.append([c + ax * stops[i], c + ax * stops[i + 1], true])
	var ring := []
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			ring.append([Vector3(0, 0, sz), Vector3(sx, 0, sz)])
			ring.append([Vector3(sx, 0, 0), Vector3(sx, 0, sz)])
	for i in range(ring.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Array = ring[i]
		ring[i] = ring[j]
		ring[j] = t
	var k := rng.randi_range(4, 6)
	for i in k:
		pieces.append([c + (ring[i][0] as Vector3) * S, c + (ring[i][1] as Vector3) * S, false])
	for pc in pieces:
		var d: Vector3 = ((pc[1] as Vector3) - (pc[0] as Vector3)).normalized()
		for e in [[pc[0], d], [pc[1], -d]]:
			var key := _key(e[0])
			if not node_dirs.has(key):
				node_dirs[key] = {}
			node_dirs[key][_dkey(e[1])] = true


## Country roads in from both HQs and both map edges, joining the main streets
## where they leave town; a hamlet sits on the longer side of the cross road -
## on a big map one on each side, and a village on the road between each HQ
## and the town as well.
func build_roads(hq0: Vector3, hq1: Vector3) -> Array:
	var c := center
	var edge := MapDims.HALF + 4.0
	var big := MapDims.HALF > 200.0
	var s_end := c + Vector3(0, 0, REACH)
	var n_end := c - Vector3(0, 0, REACH)
	var w_end := c - Vector3(REACH, 0, 0)
	var e_end := c + Vector3(REACH, 0, 0)
	var south := [Vector3(hq0.x + 14.0, 0, edge), hq0 + Vector3(14.0, 0, -12.0)]
	if big:
		var vs := TrenchNet.snap_pos((south.back() as Vector3).lerp(s_end + Vector3(0, 0, 14), 0.5))
		hamlets.append({"c": vs, "d": Vector3.FORWARD})
		mg._wobble(south, south.back(), vs + Vector3(0, 0, 20))
		for o in [20.0, 7.0, -7.0, -20.0]:
			south.append(vs + Vector3(0, 0, o))
	mg._wobble(south, south.back(), s_end + Vector3(0, 0, 14))
	south.append(s_end + Vector3(0, 0, 14))
	south.append(s_end)
	var north := [n_end, n_end - Vector3(0, 0, 14)]
	if big:
		var vn := TrenchNet.snap_pos((north.back() as Vector3).lerp(hq1 + Vector3(-14.0, 0, 12.0), 0.5))
		hamlets.append({"c": vn, "d": Vector3.FORWARD})
		mg._wobble(north, north.back(), vn + Vector3(0, 0, 20))
		for o in [20.0, 7.0, -7.0, -20.0]:
			north.append(vn + Vector3(0, 0, o))
	mg._wobble(north, north.back(), hq1 + Vector3(-14.0, 0, 12.0))
	north.append(hq1 + Vector3(-14.0, 0, 12.0))
	north.append(Vector3(hq1.x - 14.0, 0, -edge))
	main_road = mg._smooth(south)
	main_road.append_array(_straight(s_end, n_end).slice(1))
	main_road.append_array(mg._smooth(north).slice(1))
	# the cross road, with a straight run through a hamlet on its longer side
	var west := [Vector3(-edge, 0, c.z + rng.randf_range(-22, 22))]
	var east := [e_end, e_end + Vector3(14, 0, 0)]
	var east_far := Vector3(edge, 0, c.z + rng.randf_range(-22, 22))
	var on_west := (w_end.x + edge) > (edge - e_end.x)
	if on_west or big:
		var hx := (-edge + w_end.x) * 0.5
		var h := TrenchNet.snap_pos(Vector3(hx, 0, lerpf((west[0] as Vector3).z, c.z, 0.55)))
		hamlets.append({"c": h, "d": Vector3.RIGHT})
		mg._wobble(west, west[0], h - Vector3(20, 0, 0))
		for o in [-20.0, -7.0, 7.0, 20.0]:
			west.append(h + Vector3(o, 0, 0))
		mg._wobble(west, west.back(), w_end - Vector3(14, 0, 0))
	else:
		mg._wobble(west, west[0], w_end - Vector3(14, 0, 0))
	west.append(w_end - Vector3(14, 0, 0))
	west.append(w_end)
	if not on_west or big:
		var hx2 := (e_end.x + edge) * 0.5
		var h2 := TrenchNet.snap_pos(Vector3(hx2, 0, lerpf(c.z, east_far.z, 0.45)))
		hamlets.append({"c": h2, "d": Vector3.RIGHT})
		mg._wobble(east, east.back(), h2 - Vector3(20, 0, 0))
		for o in [-20.0, -7.0, 7.0, 20.0]:
			east.append(h2 + Vector3(o, 0, 0))
		mg._wobble(east, east.back(), east_far)
	else:
		mg._wobble(east, east.back(), east_far)
	east.append(east_far)
	if not hamlets.is_empty():
		hamlet = hamlets[0]
	cross_road = mg._smooth(west)
	cross_road.append_array(_straight(w_end, e_end).slice(1))
	cross_road.append_array(mg._smooth(east).slice(1))
	var roads := [main_road, cross_road]
	for pc in pieces:
		if not pc[2]:
			roads.append(_straight(pc[0], pc[1]))
	return roads


# --- streetscape ------------------------------------------------------------------

func streetscape() -> void:
	# sidewalks and curbs along both sides of every piece of street
	for pc in pieces:
		var a: Vector3 = pc[0]
		var b: Vector3 = pc[1]
		var d := (b - a).normalized()
		var L := a.distance_to(b)
		var yaw := yaw_along(d)
		for s: float in [-1.0, 1.0]:
			var n := _perp(d) * s
			var t0 := WALK if _has_dir(a, n) else 0.0
			var t1 := L - WALK if _has_dir(b, n) else L
			var mid := a + d * (t0 + t1) * 0.5
			var ws := Vector3(t1 - t0, 0.12, WALK - CURB)
			var wp := mid + n * (CURB + WALK) * 0.5
			_d("walk", wp, yaw, ws)
			_pave(wp, yaw, ws)
			_d("curb", mid + n * (CURB + 0.09), yaw, Vector3(t1 - t0, 0.17, 0.18))
	# corners and junctions
	for key in node_dirs:
		var dirs: Dictionary = node_dirs[key]
		var p := Vector3(key.x, 0, key.y)
		if dirs.size() >= 2 and not (dirs.size() == 2 and (dirs.has(Vector2i(1, 0)) and dirs.has(Vector2i(-1, 0)) or dirs.has(Vector2i(0, 1)) and dirs.has(Vector2i(0, -1)))):
			_d("junction", p, 0.0, Vector3(ROAD_HW * 2.0 + 0.1, 0.02, ROAD_HW * 2.0 + 0.1))
		for sx: int in [-1, 1]:
			for sz: int in [-1, 1]:
				var hx: bool = dirs.has(Vector2i(sx, 0))
				var hz: bool = dirs.has(Vector2i(0, sz))
				var m := (CURB + WALK) * 0.5
				var w := WALK - CURB
				if hx and hz:
					var cp := p + Vector3(sx * m, 0, sz * m)
					_d("walk", cp, 0.0, Vector3(w, 0.12, w))
					_pave(cp, 0.0, Vector3(w, 0.12, w))
					_d("curb", p + Vector3(sx * m, 0, sz * (CURB + 0.09)), 0.0, Vector3(w, 0.17, 0.18))
					_d("curb", p + Vector3(sx * (CURB + 0.09), 0, sz * m), PI * 0.5, Vector3(w, 0.17, 0.18))
				elif not hx and not hz and dirs.has(Vector2i(-sx, 0)) and dirs.has(Vector2i(0, -sz)):
					# the outside of a bend
					var r1 := p + Vector3(sx * WALK * 0.5, 0, sz * m)
					_d("walk", r1, 0.0, Vector3(WALK, 0.12, w))
					var r2 := p + Vector3(sx * m, 0, sz * CURB * 0.5)
					_d("walk", r2, PI * 0.5, Vector3(CURB, 0.12, w))
					_pave(r1, 0.0, Vector3(WALK, 0.12, w))
					_d("curb", p + Vector3(sx * CURB * 0.5, 0, sz * (CURB + 0.09)), 0.0, Vector3(CURB, 0.17, 0.18))
					_d("curb", p + Vector3(sx * (CURB + 0.09), 0, sz * CURB * 0.5), PI * 0.5, Vector3(CURB, 0.17, 0.18))
	# zebra crossings round the central crossroads
	for d4: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		_d("zebra", center + d4 * 7.0, yaw_along(d4), ROAD_HW * 2.0 - 0.4)
	_street_lights()
	_town_poles()
	_street_bits()


func _street_lights() -> void:
	var flip := 1.0
	for pc in pieces:
		var a: Vector3 = pc[0]
		var b: Vector3 = pc[1]
		var d := (b - a).normalized()
		var L := a.distance_to(b)
		var t := 8.0
		while t < L - 3.0:
			var n := _perp(d) * flip
			flip = -flip
			if (t < 7.0 and _has_dir(a, n)) or (L - t < 7.0 and _has_dir(b, n)):
				t += 17.0
				continue
			var p := a + d * t + n * 4.3
			_d("lamp", p, yaw_along(-n))
			_reserve(p, Vector2(0.3, 0.3), 0.0)
			t += 17.0


## Wooden utility poles down one side of each main street (and some side
## streets), wired pole to pole; houses get a drop from the nearest pole.
func _town_poles() -> void:
	for pc in pieces:
		if not pc[2] and rng.randf() < 0.4:
			continue
		var a: Vector3 = pc[0]
		var b: Vector3 = pc[1]
		var d := (b - a).normalized()
		var n := _perp(d) * (1.0 if pc[2] else -1.0)
		var L := a.distance_to(b)
		var prev = null
		var t := 3.5
		while t < L - 2.0:
			var p := a + d * t + n * 4.55
			var clash := false
			for e in decor:
				if e[0] == "lamp" and (e[1] as Vector3).distance_to(p) < 2.5:
					clash = true
					break
			if clash:
				p += d * 3.0
			if _has_dir(a, n) and t < 6.0 or _has_dir(b, n) and L - t < 6.0:
				t += 26.0
				continue
			var pole := [p, yaw_along(d), n]
			poles.append(pole)
			_d("pole", p, yaw_along(d))
			_reserve(p, Vector2(0.3, 0.3), 0.0)
			if prev != null:
				_d("wire", prev[0], prev[1], [p, pole[1]])
			prev = pole
			t += 26.0


func _street_bits() -> void:
	for pc in pieces:
		var a: Vector3 = pc[0]
		var b: Vector3 = pc[1]
		var d := (b - a).normalized()
		var L := a.distance_to(b)
		# a fire hydrant on some sidewalks
		if rng.randf() < 0.6:
			var n := _perp(d) * (1.0 if rng.randf() < 0.5 else -1.0)
			_d("hydrant", a + d * (L * 0.5 + rng.randf_range(-4, 4)) + n * 4.3, yaw_along(d))
		# side streets stop at the main street
		if not pc[2]:
			for e in [[b, d], [a, -d]]:
				var node: Vector3 = e[0]
				var dir: Vector3 = e[1]
				if (node_dirs.get(_key(node), {}) as Dictionary).size() >= 3:
					var right := dir.cross(Vector3.UP)
					_d("sign_stop", node - dir * 6.0 + right * 4.2, Defs.yaw_of(-dir))
	# the town's name on the way in
	for d4: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var end := center + d4 * (REACH + 3.0)
		var right2 := (-d4).cross(Vector3.UP)
		_d("sign_town", end + right2 * 5.0, Defs.yaw_of(d4))
	# a bus stop on one of the main street's outer stretches
	var outer := []
	for pc in pieces:
		if pc[2] and ((pc[0] as Vector3).distance_to(center) > S - 1.0 or (pc[1] as Vector3).distance_to(center) > S - 1.0):
			outer.append(pc)
	if not outer.is_empty():
		var pc2: Array = outer[rng.randi() % outer.size()]
		var d2: Vector3 = ((pc2[1] as Vector3) - (pc2[0] as Vector3)).normalized()
		var n2 := _perp(d2) * (1.0 if rng.randf() < 0.5 else -1.0)
		var bp: Vector3 = (pc2[0] as Vector3).lerp(pc2[1], 0.5) + n2 * 5.6
		_d("bus_stop", bp, yaw_along(d2) + (PI if n2.dot(_perp(d2)) < 0 else 0.0))
		_reserve(bp, Vector2(1.9, 1.2), yaw_along(d2))
		_d("bin", bp + d2 * 2.4 - n2 * 0.9, 0.0)


# --- lots ----------------------------------------------------------------------------

func lots() -> void:
	# the square: a corner of the central crossroads
	var q := Vector3(1.0 if rng.randf() < 0.5 else -1.0, 0, 1.0 if rng.randf() < 0.5 else -1.0)
	var pc_ := center + Vector3(q.x * (WALK + 10.0), 0, q.z * (WALK + 10.0))
	_reserve(pc_, Vector2(10.3, 10.3), 0.0)
	_square(pc_, q)
	# then every street's lots, main streets first so the corner houses face them
	var order := pieces.duplicate()
	order.sort_custom(func(x, y): return int(x[2]) > int(y[2]))
	var specials := ["playground", "park", "parking", "garden", "garden", "ruin"]
	for i in range(specials.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: String = specials[i]
		specials[i] = specials[j]
		specials[j] = t
	var lot_i := 0
	for pc in order:
		var a: Vector3 = pc[0]
		var b: Vector3 = pc[1]
		var d := (b - a).normalized()
		var L := a.distance_to(b)
		for s: float in [-1.0, 1.0]:
			var n := _perp(d) * s
			var t0 := FRONT + 0.6 if _has_dir(a, n) else 0.5
			var t1 := L - FRONT - 0.6 if _has_dir(b, n) else L - 0.5
			var t := t0
			while t1 - t >= 9.0:
				var W := minf(rng.randf_range(11.0, 15.0), t1 - t)
				if t1 - t - W < 9.0:
					W = t1 - t
				W = minf(W, 17.0)
				var front := a + d * (t + W * 0.5) + n * FRONT
				var near := front.distance_to(center) < 36.0
				_depth = LOT_D
				for dep_try in [LOT_D, 11.0, 9.4]:
					_depth = dep_try
					if _lot_free(front, n, d, W):
						break
				var kind := "house"
				lot_i += 1
				if near and pc[2] and rng.randf() < 0.6:
					kind = "shop"
				elif lot_i % 4 == 2 and not specials.is_empty() and W >= 11.0:
					kind = specials.pop_back()
					if kind in ["playground", "park"] and W < 13.0:
						specials.append(kind)
						kind = "house"
				match kind:
					"house":
						_lot_house(front, n, d, W, false)
					"shop":
						_lot_house(front, n, d, W, true)
					"playground":
						_playground(front, n, d, W)
					"park":
						_park(front, n, d, W)
					"parking":
						_parking(front, n, d, W)
					"garden":
						_allotment(front, n, d, W)
					"ruin":
						_ruin_lot(front, n, d, W)
				t += W + rng.randf_range(0.0, 1.0)
	_drops()
	_water_tower()


func _lot_free(front: Vector3, n: Vector3, d: Vector3, W: float) -> bool:
	var lc := front + n * _depth * 0.5
	return mg._is_free(lc, Vector2(W * 0.5 - 0.4, _depth * 0.5 - 0.4), yaw_along(d), 0.0, false)


func _lot_house(front: Vector3, n: Vector3, d: Vector3, W: float, shop: bool) -> void:
	var axis := atan2(n.x, n.z)  # local +z points away from the street
	var w := clampf(W - rng.randf_range(1.8, 3.0), 6.5, 13.0)
	var setback := rng.randf_range(0.2, 0.5) if shop else rng.randf_range(1.2, 2.4)
	var dep := rng.randf_range(9.0, 10.5) if shop else rng.randf_range(7.0, 8.6)
	dep = minf(dep, _depth - setback - 0.6)
	var side := 0.0
	var drive := not shop and W >= 12.5 and rng.randf() < 0.4
	if drive:
		w = minf(w, W - 4.4)
		side = (W - w) * 0.5 - 0.7
		if rng.randf() < 0.5:
			side = -side
	var hc := front + n * (setback + dep * 0.5) + d * side
	if not mg._house(hc, w, dep, axis, 1.0, false, 0.18 if shop else 0.25):
		return
	_fronts.append(hc - n * dep * 0.5 + Vector3(0, 2.85, 0))
	var yaw_d := yaw_along(d)
	if shop:
		_d("awning", hc - n * dep * 0.5, axis, Vector3(w - 0.6, 0, rng.randi() % 5))
	# the garden behind: hedge (or a wall) along the back, fences down the sides
	var back := front + n * _depth
	var kind := rng.randf()
	var segs := maxi(1, int(round(W / 4.0)))
	var sl := W / segs
	for k in segs:
		if rng.randf() < 0.12:
			continue
		var bp := back + d * ((k + 0.5) * sl - W * 0.5) - n * 0.5
		if kind < 0.7:
			mg._try("low_wall", bp, yaw_d, -1, {"size": Vector3(sl, 1.0, 0.5), "variant": 1})
		elif kind < 0.88:
			mg._try("low_wall", bp, yaw_d, -1, {"size": Vector3(sl, 1.0, 0.5), "variant": 0})
	var style := rng.randi() % 3
	for e: float in [-1.0, 1.0]:
		var sp := front + d * (W * 0.5 * e) + n * (_depth * 0.5 + (setback + dep) * 0.5)
		var flen := _depth - (setback + dep)
		var key := _key(sp)
		if flen > 1.5 and not _fence_keys.has(key):
			_fence_keys[key] = true
			_d("fence", sp, yaw_along(n), Vector3(flen - 0.6, 1.1, style))
	if not shop:
		# a low front fence with a gate, a mailbox, a tree or a vegetable patch behind
		if rng.randf() < 0.55:
			var gate := clampf(side * -0.3, -W * 0.3, W * 0.3)
			var lw := (W * 0.5 + gate) - 0.8
			var rw := (W * 0.5 - gate) - 0.8
			if lw > 0.8:
				_d("fence", front + n * 0.35 + d * (-W * 0.5 + lw * 0.5), yaw_d, Vector3(lw, 0.85, style))
			if rw > 0.8:
				_d("fence", front + n * 0.35 + d * (W * 0.5 - rw * 0.5), yaw_d, Vector3(rw, 0.85, style))
		if rng.randf() < 0.4:
			_d("mailbox", front + n * 0.5 + d * (W * 0.5 - 1.2), axis)
		var yard := _depth - setback - dep
		if yard > 3.0:
			var yc := front + n * (setback + dep + yard * 0.5)
			var r := rng.randf()
			if r < 0.4:
				mg._try("tree", yc + d * rng.randf_range(-W * 0.3, W * 0.3), 0.0, -1)
			elif r < 0.65:
				_d("garden", yc + d * rng.randf_range(-W * 0.2, W * 0.2), yaw_d, Vector3(minf(W - 3.0, 6.0), 0, minf(yard - 1.0, 3.0)))
			elif r < 0.85:
				_d("clothesline", yc, yaw_d)
	if drive:
		var dc := front + n * (setback + 2.6) + d * (-signf(side) * (W * 0.5 - 1.8))
		_d("drive", front + n * (setback + 2.6) * 0.5 + d * (-signf(side) * (W * 0.5 - 1.8)), axis, Vector3(2.6, 0, setback + 2.6))
		if rng.randf() < 0.75:
			mg._try("car", dc, axis + (PI if rng.randf() < 0.5 else 0.0), -1, {"variant": rng.randi() % 5})


func _square(c: Vector3, q: Vector3) -> void:
	var size := Vector3(20.0, 0.1, 20.0)
	_d("pave", c, 0.0, size)
	_pave(c, 0.0, size)
	if rng.randf() < 0.55:
		_d("fountain", c)
		_reserve(c, Vector2(2.6, 2.6), 0.0)
	else:
		_d("statue", c, rng.randf() * TAU)
		_reserve(c, Vector2(1.2, 1.2), 0.0)
	for i in 4:
		var a := PI * 0.25 + i * PI * 0.5
		var off := Vector3(cos(a), 0, sin(a)) * 5.2
		_d("bench", c + off, Defs.yaw_of(-off))
		_d("lamp_deco", c + Vector3(signf(cos(a)) * 8.6, 0, signf(sin(a)) * 8.6))
	# trees in the far corner, planters and a flag along the edges
	var far := c + Vector3(q.x * 6.4, 0, q.z * 6.4)
	mg._try("tree", far, 0.0, -1)
	for i in 3:
		var e := c + Vector3(q.x * 9.0, 0, -q.z * 5.4 + q.z * i * 5.4)
		_d("planter", e)
		var e2 := c + Vector3(-q.x * 5.4 + q.x * i * 5.4, 0, q.z * 9.0)
		_d("planter", e2)
	_d("bin", c + Vector3(-q.x * 6.0, 0, -q.z * 8.6))
	_d("flagpole", c + Vector3(-q.x * 8.6, 0, q.z * 3.6))
	# market stalls along one side, bollards where it meets the streets
	for i in 3:
		_d("stall", c + Vector3(q.x * (1.8 - i * 3.0), 0, q.z * 7.6), PI if q.z > 0 else 0.0, rng.randi() % 4)
	for i in 6:
		_d("bollard", c + Vector3(-q.x * 9.6, 0, -8.0 + i * 3.2))
		_d("bollard", c + Vector3(-8.0 + i * 3.2, 0, -q.z * 9.6))
	_d("transformer", c + Vector3(q.x * 9.0, 0, q.z * 9.0), 0.0)


func _playground(front: Vector3, n: Vector3, d: Vector3, W: float) -> void:
	if not _lot_free(front, n, d, W):
		return
	var yaw := yaw_along(d)
	var c := front + n * _depth * 0.5
	_reserve(c, Vector2(W * 0.5, _depth * 0.5), yaw)
	_d("soft", c, yaw, Vector3(W - 1.0, 0, _depth - 1.0))
	# a green railing all round, with the gate on the street
	_d("fence", front + n * 0.3 + d * (-W * 0.25 - 0.5), yaw, Vector3(W * 0.5 - 1.6, 1.0, 2))
	_d("fence", front + n * 0.3 + d * (W * 0.25 + 0.5), yaw, Vector3(W * 0.5 - 1.6, 1.0, 2))
	_d("fence", front + n * (_depth - 0.3), yaw, Vector3(W - 0.4, 1.0, 2))
	for e: float in [-1.0, 1.0]:
		_d("fence", front + d * (W * 0.5 - 0.3) * e + n * _depth * 0.5, yaw_along(n), Vector3(_depth - 0.6, 1.0, 2))
	var lx := W * 0.5 - 3.2
	_d("swing", c + d * (-lx + 0.8) + n * 3.5, yaw)
	_d("slide", c + d * (lx - 1.2) + n * 3.2, yaw_along(n) + PI)
	_d("climber", c + d * (lx - 1.5) - n * 2.4, yaw)
	_d("sandbox", c + d * (-lx + 1.5) - n * 2.6, yaw)
	_d("seesaw", c + n * 0.4, yaw_along(n))
	_d("roundabout", c - n * 3.8 + d * 0.5)
	_d("bench", front + n * 1.4 + d * (W * 0.25), Defs.yaw_of(n))
	_d("bench", front + n * 1.4 - d * (W * 0.25), Defs.yaw_of(n))
	_d("bin", front + n * 1.2)
	mg._try("tree", c + d * (lx + 1.6) + n * (_depth * 0.5 - 1.6), 0.0, -1)
	mg._try("tree", c - d * (lx + 1.6) + n * (_depth * 0.5 - 1.6), 0.0, -1)


func _park(front: Vector3, n: Vector3, d: Vector3, W: float) -> void:
	if not _lot_free(front, n, d, W):
		return
	var yaw := yaw_along(d)
	var c := front + n * _depth * 0.5
	_reserve(c, Vector2(W * 0.5, _depth * 0.5), yaw)
	_d("path", c, yaw_along(n), Vector3(_depth, 0, 1.6))
	_d("path", c, yaw, Vector3(W - 1.0, 0, 1.6))
	_d("statue", c, yaw, 1)
	for e: float in [-1.0, 1.0]:
		_d("bench", c + d * 3.2 * e + n * 1.6, Defs.yaw_of(-n))
		_d("lamp_deco", c + d * (W * 0.5 - 1.5) * e - n * (_depth * 0.5 - 1.5))
	for i in rng.randi_range(4, 6):
		var tp := c + d * rng.randf_range(-W * 0.42, W * 0.42) + n * rng.randf_range(-_depth * 0.4, _depth * 0.4)
		if absf((tp - c).dot(d)) > 1.6 and absf((tp - c).dot(n)) > 1.6:
			mg._try("tree", tp, 0.0, -1)
	var segs := maxi(1, int(round(W / 4.0)))
	for k in segs:
		if k == segs / 2:
			continue
		mg._try("low_wall", front + n * 0.5 + d * ((k + 0.5) * W / segs - W * 0.5), yaw, -1, {"size": Vector3(W / segs, 1.0, 0.5), "variant": 1})
	_d("bin", front + n * 1.0 + d * 1.6)


func _parking(front: Vector3, n: Vector3, d: Vector3, W: float) -> void:
	if not _lot_free(front, n, d, W):
		return
	var c := front + n * 5.5
	var size := Vector3(W - 1.0, 0, 11.0)
	_reserve(c, Vector2(W * 0.5, 5.6), yaw_along(d))
	_d("lot_pave", c, yaw_along(d), Vector3(W - 1.0, signf(n.dot(_perp(d))), 11.0))
	_pave(c, yaw_along(d), size)
	var slots := int((W - 1.0) / 2.6)
	for i in slots:
		if rng.randf() < 0.5:
			var cp := c + d * ((i + 0.5) * 2.6 - (W - 1.0) * 0.5) + n * 2.4
			mg._try("car", cp, atan2(n.x, n.z) + rng.randf_range(-0.05, 0.05), -1, {"variant": rng.randi() % 5})


func _allotment(front: Vector3, n: Vector3, d: Vector3, W: float) -> void:
	if not _lot_free(front, n, d, W):
		return
	var yaw := yaw_along(d)
	var c := front + n * _depth * 0.5
	_reserve(c, Vector2(W * 0.5, _depth * 0.5), yaw)
	for i in 2:
		_d("garden", c + n * (-3.0 + i * 5.0) + d * rng.randf_range(-1, 1), yaw, Vector3(W - 3.0, 0, 3.6))
	_d("fence", front + n * 0.3, yaw, Vector3(W - 0.6, 1.0, 1))
	mg._try("crates", c + d * (W * 0.5 - 1.8) + n * (_depth * 0.5 - 1.5), yaw, -1, {"variant": 0})
	if rng.randf() < 0.6:
		mg._try("tree", c - d * (W * 0.5 - 1.8) + n * (_depth * 0.5 - 1.8), 0.0, -1)


func _ruin_lot(front: Vector3, n: Vector3, d: Vector3, W: float) -> void:
	if not _lot_free(front, n, d, W):
		return
	var c := front + n * 5.0
	_reserve(c, Vector2(W * 0.5, _depth * 0.5), yaw_along(d))
	for i in rng.randi_range(2, 4):
		world.spawn("structure", {"skind": "rubble", "pos": c + d * rng.randf_range(-W * 0.35, W * 0.35) + n * rng.randf_range(-3, 4), "yaw": rng.randf() * TAU, "size": Vector3(rng.randf_range(2.0, 3.6), 0, rng.randf_range(1.2, 2.0))})
	if rng.randf() < 0.6:
		mg._try("low_wall", front + n * 0.6, yaw_along(d), -1, {"size": Vector3(minf(W - 2.0, 6.0), 1.0, 0.5), "variant": 0})


## Every house within reach of a pole gets its service wire.
func _drops() -> void:
	for fp in _fronts:
		var best = null
		var bd := 26.0
		for pl in poles:
			var dd: float = Defs.flat((pl[0] as Vector3) - fp).length()
			if Defs.flat(fp - (pl[0] as Vector3)).dot(pl[2]) < 0.5:
				continue  # across the street: that house is fed from its own side
			if dd < bd:
				bd = dd
				best = pl
		if best != null:
			_d("drop", (best[0] as Vector3) + Vector3(0, 7.0, 0), 0.0, fp)


func _water_tower() -> void:
	for i in 24:
		var a := rng.randf() * TAU
		var p := TrenchNet.snap_pos(center + Vector3(cos(a), 0, sin(a)) * rng.randf_range(REACH - 6.0, REACH + 10.0))
		if mg._is_free(p, Vector2(3.2, 3.2), 0.0, 0.5) and _road_dist(p) > 8.0:
			_d("water_tower", p, TrenchNet.snap_yaw(a))
			_reserve(p, Vector2(3.0, 3.0), 0.0)
			return


# --- the countryside ---------------------------------------------------------------

func _road_dist(p: Vector3) -> float:
	var best := 1e9
	for poly in world.roads[2]:
		var pts: PackedVector3Array = poly
		for i in range(0, pts.size() - 1):
			best = minf(best, Defs.dist_point_segment(Vector3(p.x, 0, p.z), pts[i], pts[i + 1]))
	return best


## A handful of houses either side of the straight run of the road through
## each village.
func hamlet_houses() -> void:
	for hm in hamlets:
		_hamlet(hm)


func _hamlet(hm: Dictionary) -> void:
	var h: Vector3 = hm.c
	var d: Vector3 = hm.d
	for s: float in [-1.0, 1.0]:
		var n := _perp(d) * s
		var t := -19.0
		while t < 15.0:
			var W := rng.randf_range(11.0, 14.0)
			if rng.randf() < 0.8:
				_depth = LOT_D
				_lot_house(h + d * (t + W * 0.5) + n * 6.0, n, d, W, false)
			t += W + rng.randf_range(0.5, 3.0)
	# old lamps on wooden posts, a bench and a phone-pole bus stop
	for i in 3:
		_d("lamp", h + d * (-15.0 + i * 15.0) + _perp(d) * 4.6 * (1.0 if i % 2 == 0 else -1.0), yaw_along(-_perp(d) * (1.0 if i % 2 == 0 else -1.0)), 1)
	_d("bench", h + _perp(d) * 4.7 + d * 4.0, Defs.yaw_of(-_perp(d)))


## Farmsteads off the country roads: farmhouse and barn round a yard, hay,
## a fenced road frontage and an orchard behind.
func farms(k: int) -> void:
	var made := 0
	for attempt in 40 + k * 12:
		if made >= k:
			return
		var poly: PackedVector3Array = main_road if rng.randf() < 0.5 else cross_road
		var i := rng.randi_range(4, poly.size() - 5)
		var p := poly[i]
		if rect.grow(16.0).has_point(Vector2(p.x, p.z)) or not Defs.in_map(p, 22.0):
			continue
		var by_village := false
		for hm in hamlets:
			if p.distance_to(hm.c) < 45.0:
				by_village = true
		if by_village:
			continue
		var t := TrenchNet.snap_dir(poly[i + 2] - poly[i - 2])
		var n := _perp(t) * (1.0 if rng.randf() < 0.5 else -1.0)
		var axis := atan2(n.x, n.z)
		var base := TrenchNet.snap_pos(p + n * 9.0)
		var hc := base + n * 4.5 - t * 7.0
		var bc := base + n * 6.5 + t * 8.0
		if _road_dist(hc) < 9.0 or _road_dist(bc) < 10.0:
			continue
		if not mg._is_free(hc, Vector2(6, 5), axis, 1.0) or not mg._is_free(bc, Vector2(8, 6), axis, 1.0):
			continue
		mg._house(hc, rng.randf_range(9.0, 11.0), 8.0, axis, 1.0, false, 0.2)
		_fronts.append(hc - n * 4.0 + Vector3(0, 2.85, 0))
		mg._house(bc, 13.0, 10.0, axis, 1.0, false, 0.35)
		_d("fence", base - n * 2.0 + t * 1.0, yaw_along(t), Vector3(30.0, 1.1, 1))
		for j in rng.randi_range(2, 4):
			_d("hay", base + n * rng.randf_range(12.0, 15.0) + t * (rng.randf_range(-4, 4)), yaw_along(t) + rng.randf_range(-0.3, 0.3), rng.randi_range(1, 3))
		mg._try("crates", bc - n * 6.0 - t * 2.0, yaw_along(t), -1, {"variant": 1})
		if rng.randf() < 0.7:
			mg._try("car", base + n * 2.0 + t * 1.0, axis + PI * 0.5, -1, {"variant": 4})
		# an orchard in rows behind
		var oc := base + n * 22.0
		for r in 3:
			for c in 4:
				if rng.randf() < 0.85:
					mg._try("tree", oc + n * r * 5.0 + t * (c * 5.0 - 7.5) + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)), 0.0, -1, {"variant": 1})
		_d("pole", base - n * 4.4 + t * 9.0, yaw_along(t), 1)
		poles.append([base - n * 4.4 + t * 9.0, yaw_along(t), n])
		made += 1


## A power line along each country road on the verge, pole every ~34 m.
func country_power() -> void:
	for poly in [main_road, cross_road]:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var along := 0.0
		var next := 10.0
		var prev = null
		for i in range(1, poly.size()):
			var seg: float = Defs.flat(poly[i] - poly[i - 1]).length()
			along += seg
			if along < next:
				continue
			next = along + 34.0
			var t: Vector3 = Defs.flat(poly[mini(i + 1, poly.size() - 1)] - poly[maxi(i - 1, 0)]).normalized()
			var p: Vector3 = poly[i] + _perp(t) * side * 4.6
			if rect.grow(2.0).has_point(Vector2(p.x, p.z)) or not Defs.in_map(p, 3.0) or not mg._is_free(p, Vector2(0.3, 0.3), 0.0, 0.3, true):
				prev = null
				continue
			var pole := [p, yaw_along(t), _perp(t) * side]
			_d("pole", p, pole[1])
			_reserve(p, Vector2(0.3, 0.3), 0.0)
			poles.append(pole)
			if prev != null and (prev[0] as Vector3).distance_to(p) < 46.0:
				_d("wire", prev[0], prev[1], [p, pole[1]])
			prev = pole
	# run the country lines into the town: join each line's last pole outside
	# town to the nearest town pole
	pass


## Hedged fields along the roads: a hedge parallel to the road a little way
## off, and one running away from it, both square to the road.
func fields(k: int) -> void:
	var made := 0
	for attempt in 60 + k * 6:
		if made >= k:
			return
		var poly: PackedVector3Array = main_road if rng.randf() < 0.5 else cross_road
		var i := rng.randi_range(3, poly.size() - 4)
		var p := poly[i]
		if rect.grow(10.0).has_point(Vector2(p.x, p.z)):
			continue
		var t := TrenchNet.snap_dir(poly[i + 2] - poly[i - 2])
		var n := _perp(t) * (1.0 if rng.randf() < 0.5 else -1.0)
		var start := TrenchNet.snap_pos(p + n * rng.randf_range(9.0, 14.0))
		var len1 := int(rng.randf_range(6, 12))
		var variant := 1 if rng.randf() < 0.8 else 0
		var put := 0
		for s in len1:
			if rng.randf() < 0.13:
				continue
			var hp := start + t * (s * 4.0)
			if _road_dist(hp) > 6.0 and mg._try("low_wall", hp, yaw_along(t), -1, {"size": Vector3(4.0, 1.0, 0.5), "variant": variant}) != null:
				put += 1
		if rng.randf() < 0.7:
			var end := start + t * ((len1 if rng.randf() < 0.5 else 0) * 4.0 - 2.0)
			for s in int(rng.randf_range(4, 10)):
				if rng.randf() < 0.12:
					continue
				var hp2 := end + n * (2.0 + s * 4.0)
				if mg._try("low_wall", hp2, yaw_along(n), -1, {"size": Vector3(4.0, 1.0, 0.5), "variant": variant}) != null:
					put += 1
		if put > 0:
			made += 1


## Abandoned cars on the verges and burnt-out armour off the road.
func roadside(cars: int, wrecks: int) -> void:
	for attempt in 30 + (cars + wrecks) * 4:
		if cars <= 0 and wrecks <= 0:
			return
		var poly: PackedVector3Array = main_road if rng.randf() < 0.5 else cross_road
		var i := rng.randi_range(3, poly.size() - 4)
		var p := poly[i]
		if rect.has_point(Vector2(p.x, p.z)):
			continue
		var t := Defs.flat(poly[i + 1] - poly[i - 1]).normalized()
		var n := _perp(t) * (1.0 if rng.randf() < 0.5 else -1.0)
		if cars > 0:
			if mg._try("car", p + n * 3.8, yaw_along(t) + PI * 0.5 + rng.randf_range(-0.25, 0.25), -1, {"variant": rng.randi() % 5}) != null:
				cars -= 1
		elif wrecks > 0:
			if mg._try("wreck", p + n * rng.randf_range(8.0, 14.0), rng.randf() * TAU, -1) != null:
				wrecks -= 1


## Keep the scattered scenery out of town and off the roads; hand the street
## furniture to the world.
func finish() -> void:
	mg.clear.append([rect.get_center(), REACH + 4.0])
	for hm in hamlets:
		mg.clear.append([Vector2(hm.c.x, hm.c.z), 24.0])
	for poly in world.roads[2]:
		var arr: PackedVector3Array = poly
		for k in range(0, arr.size(), 2):
			mg.clear.append([Vector2(arr[k].x, arr[k].z), 3.6])
	world.set_decor(decor, rect)
