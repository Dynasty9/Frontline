class_name MapGen
extends RefCounted
## Builds the battlefield on the server: HQs and starting FOBs at the north
## and south edges; between them a town, villages and farms on the country
## roads (TownGen), hedged fields, old trenches and woods - as much of each as
## the map's size has room for (MapDims).

var world: World
var rng: RandomNumberGenerator
var placed: Array = []  # [Vector2 center, Vector2 half, yaw] (add with _place)
var doors_shut := -1  # houses' doors: -1 some shut (most), 1 all shut, 0 all open
var clear: Array = []  # [Vector2 center, radius] (add with _keep_clear)
## The same, filed by the 16 m square their middles are in, so a look for room
## (_is_free) goes through only what's near it; the few big ones (a town, a
## yard) are looked through every time.
const GRID := 16.0
const BIG := 12.0  # (half diagonal, radius) bigger than this is filed as big
var _placed_at := {}  # Vector2i -> [placed entries]
var _placed_big: Array = []
var _clear_at := {}
var _clear_big: Array = []


func _place(e: Array) -> void:
	placed.append(e)
	if (e[1] as Vector2).length() > BIG:
		_placed_big.append(e)
		return
	var key := Vector2i(floori(e[0].x / GRID), floori(e[0].y / GRID))
	var a = _placed_at.get(key)
	if a == null:
		a = []
		_placed_at[key] = a
	a.append(e)


## Takes back the last thing placed.
func _unplace_last() -> void:
	var e: Array = placed.pop_back()
	if (e[1] as Vector2).length() > BIG:
		_placed_big.pop_back()
	else:
		(_placed_at[Vector2i(floori(e[0].x / GRID), floori(e[0].y / GRID))] as Array).pop_back()


func _keep_clear(e: Array) -> void:
	clear.append(e)
	if float(e[1]) > BIG:
		_clear_big.append(e)
		return
	var key := Vector2i(floori(e[0].x / GRID), floori(e[0].y / GRID))
	var a = _clear_at.get(key)
	if a == null:
		a = []
		_clear_at[key] = a
	a.append(e)


func _init(w: World) -> void:
	world = w
	rng = w.rng


func generate() -> void:
	var r := world.rules
	var H := MapDims.HALF
	var k := H / 128.0  # how much bigger than the original 256 m field each way
	var area := k * k
	# nothing asks the way until the ground's laid out: the routes hear of
	# each cell it changes once, when it's done (see TerrainMap.hold_nav)
	world.terrain.hold_nav()
	var d0 := _spawn("depot", Vector3(0, 0, H - 12.0), 0.0, 0)
	var d1 := _spawn("depot", Vector3(0, 0, -(H - 12.0)), PI, 1)
	r.depots = [d0, d1]
	var fx0 := roundf(rng.randf_range(-40.0, 40.0) * k)
	var fx1 := roundf(rng.randf_range(-40.0, 40.0) * k)
	var f0 := _spawn("fob", Vector3(fx0, 0, H - 42.0), 0.0, 0, {"sname": r.next_fob_name(0), "supply": float(Defs.START_SUPPLY)})
	var f1 := _spawn("fob", Vector3(fx1, 0, -(H - 42.0)), PI, 1, {"sname": r.next_fob_name(1), "supply": float(Defs.START_SUPPLY)})
	r.register_start_fob(f0)
	r.register_start_fob(f1)
	for st in [d0, d1, f0, f1]:
		st.seen_mask = 3  # start locations are common knowledge
	for p in [d0.position, d1.position]:
		_keep_clear([Vector2(p.x, p.z), 26.0])
	for f in [f0, f1]:
		_keep_clear([Vector2(f.position.x, f.position.z), 30.0])
	# keep the lane between HQ and starting FOB open
	for t in 2:
		var a: Vector3 = [d0, d1][t].position
		var b: Vector3 = [f0, f1][t].position
		for i in 5:
			var p := a.lerp(b, i / 4.0)
			_keep_clear([Vector2(p.x, p.z), 10.0])

	await world._breathe("Surveying the rivers", 0.18)
	_lay_water()
	await world._breathe("Laying out the town", 0.26)
	# the town, its roads and everything that hangs off them (see TownGen)
	var tg := TownGen.new(self)
	tg.plan_town(TrenchNet.snap_pos(Vector3(rng.randf_range(-26, 26), 0, rng.randf_range(-8, 8))))
	world.roads[2] = tg.build_roads(d0.position, d1.position)
	_lanes(tg)
	await world._breathe("Laying out the town", 0.32)
	_roads_meet_water(tg)
	await world._breathe("Weathering the mountain ridges", 0.34)
	var sites := [[tg.center, minf(85.0 * k, 130.0)], [d0.position, 60.0], [d1.position, 60.0], [f0.position, 55.0], [f1.position, 55.0]]
	for hamlet in tg.hamlets:
		sites.append([hamlet.c, 42.0])
	# Campaign routes retain the geology and woodland density they were authored against.
	world.terrain.landform.generate(int(world.settings.get("seed", 1)), world.roads, world.water, sites, String(world.settings.get("mission", "")) == "")
	world.terrain.install_landform(world.terrain.landform.heights)
	world._rebuild_roads()
	await world._breathe("Laying out the town", 0.38)
	tg.streetscape()
	tg.lots()
	tg.hamlet_houses()
	await world._breathe("Farms and fields", 0.44)
	tg.farms(int(rng.randi_range(2, 3) * area * 0.6))
	tg.country_power()
	tg.fields(int(rng.randi_range(7, 10) * area * 0.6))
	tg.roadside(int(rng.randi_range(3, 5) * k), int(rng.randi_range(2, 3) * k))
	if String(world.settings.get("mission", "")) == "":
		_towns(tg)  # (a mission's ground is fought for on the mission's terms)
	tg.finish()
	# the ground worth fighting for, for the AI commanders
	world.key_points.append({"pos": tg.center, "kind": "town"})
	for hm in tg.hamlets:
		world.key_points.append({"pos": hm.c, "kind": "village"})
	await world._breathe("Hedges, woods and old trenches", 0.48)
	for i in int(rng.randi_range(3, 4) * area * 0.6):
		_hedgerow()
	for i in int(rng.randi_range(1, 2) * k):
		_try("wreck", Vector3(rng.randf_range(-(H - 28.0), H - 28.0), 0, rng.randf_range(-(H - 68.0), H - 68.0)), rng.randf() * TAU, -1)
	for i in int(rng.randi_range(2, 3) * k):
		_crate_cluster(Vector3(rng.randf_range(-(H - 23.0), H - 23.0), 0, rng.randf_range(-(H - 58.0), H - 58.0)))
	# old fighting positions across the middle, where the line has run before
	for i in int(rng.randi_range(3, 5) * k):
		_old_position(Vector3(rng.randf_range(-(H - 38.0), H - 38.0), 0, rng.randf_range(-35.0, 35.0) * k))
	for i in int(rng.randi_range(7, 10) * area * 0.85):
		_woods(Vector3(rng.randf_range(-(H - 13.0), H - 13.0), 0, rng.randf_range(-(H - 28.0), H - 28.0)), rng.randi_range(6, 14) if String(world.settings.get("mission", "")) != "" else rng.randi_range(12, 26))
	for i in int(40 * area * 0.75):
		_try("tree", Vector3(rng.randf_range(-(H - 8.0), H - 8.0), 0, rng.randf_range(-(H - 10.0), H - 10.0)), 0.0, -1)

	world.terrain.release_nav()
	await world._breathe("Mustering the forces", 0.53)
	# starting forces (a mission brings its own: see MissionDirector)
	if String(world.settings.get("mission", "")) != "":
		r.rebuild_network(0)
		r.rebuild_network(1)
		return
	var owners := [[], []]
	var pl: Dictionary = world.settings.get("players", {})
	for id in pl:
		var t := int(pl[id].team)
		if t >= 0:
			owners[t].append(int(id))
	for t in world.settings.get("ai_teams", []):
		owners[int(t)].append(-1 - int(t))
	for t in 2:
		var f: Structure = [f0, f1][t]
		var fwd := Vector3.FORWARD if t == 0 else Vector3.BACK
		var i := 0
		for o in owners[t]:
			var side: Vector3 = Vector3.RIGHT * (i * 14.0 - (owners[t].size() - 1) * 7.0)
			r.spawn_squad("rifle_squad" if t == 0 else "fighter_cell", t, o, f.position + fwd * 11.0 + side, f.position + fwd * 18.0 + side)
			r.spawn_squad("engineer_team" if t == 0 else "digger_team", t, o, f.position - fwd * 10.0 + side + Vector3(4, 0, 0))
			i += 1
	r.rebuild_network(0)
	r.rebuild_network(1)


# --- country lanes and villages ----------------------------------------------------------

## On a big map, lanes branch off the main road to a village in each quarter
## (mirrored between the sides, so neither gets more cover to fight from);
## on the west side the lane runs on over the river to a farming village on
## the far bank (the bridge comes with it - see _roads_meet_water).
func _lanes(tg) -> void:
	var H := MapDims.HALF
	if H < 300.0:
		return
	var w: WaterMap = world.water
	var main: PackedVector3Array = tg.main_road
	var river_x := -H * 0.48
	if not w.rivers.is_empty():
		var pts: PackedVector3Array = w.rivers[0].pts
		river_x = pts[pts.size() / 2].x
	var east_x := (w.coast_x(0.0) - 70.0) if not w.coast.is_empty() else H - 90.0
	var zs := rng.randf_range(H * 0.36, H * 0.58)
	for side in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var z: float = sz * (zs + rng.randf_range(-25.0, 25.0))
			# where the lane leaves the main road
			var j := main[0]
			for p in main:
				if absf(p.z - z) < absf(j.z - z):
					j = p
			var vx: float = lerpf(j.x, east_x if side > 0.0 else river_x, rng.randf_range(0.5, 0.62))
			var v := TrenchNet.snap_pos(Vector3(vx, 0, z + rng.randf_range(-20.0, 20.0)))
			# not in a pond
			for pd in w.ponds:
				if Defs.flat(v - pd.c).length() < float(pd.r) + 45.0:
					v.z += signf(v.z - pd.c.z) * (float(pd.r) + 50.0 - absf(v.z - pd.c.z))
			var d := Vector3(side, 0, 0)
			var pts := [j + d * 4.0]
			_wobble(pts, pts[0], v - d * 30.0)
			for o in [-30.0, -20.0, -7.0, 7.0, 20.0, 30.0]:
				pts.append(v + d * o)
			if side < 0.0 and not w.rivers.is_empty():
				# on across the river to a farming village on the far bank
				var v2 := TrenchNet.snap_pos(Vector3(lerpf(river_x, -H, 0.5), 0, v.z + rng.randf_range(-30.0, 30.0)))
				_wobble(pts, pts.back(), v2 - d * 30.0)
				for o in [-30.0, -20.0, -7.0, 7.0, 20.0, 34.0]:
					pts.append(v2 + d * o)
				tg.hamlets.append({"c": v2, "d": d})
			world.roads[2].append(_smooth(pts))
			tg.hamlets.append({"c": v, "d": d})


# --- towns -----------------------------------------------------------------------------

## The town and every village are worth holding: each gets a supply dump by
## its main street, flying the colours of whoever holds it - nobody, to begin
## with - and a name. (Their own random numbers: the rest of the map comes out
## the same with them or without.)
func _towns(tg) -> void:
	var nr := RandomNumberGenerator.new()
	nr.seed = int(world.settings.get("seed", 1)) * 7919 + 101
	var names := []
	for k in 2:
		var l: Array = (Defs.TOWN_NAMES[k] as Array).duplicate()
		for i in range(l.size() - 1, 0, -1):
			var j := nr.randi() % (i + 1)
			var t = l[i]
			l[i] = l[j]
			l[j] = t
		names.append(l)
	# the town's on its square where the flagpole stood, facing the main street;
	# its ground is the crossroads and the blocks round it
	if tg.square != Vector3.INF:
		var q: Vector3 = tg.square_q
		tg.decor.erase(tg.square_flag)
		_town_dump(tg.square + Vector3(-q.x * 7.4, 0, q.z * 2.6), Defs.yaw_of(Vector3(-q.x, 0, 0)), 1, String(names[1][0]), tg.center + q * 6.0)
	var vi := 0
	for hm in tg.hamlets:
		var spot := _dump_spot(tg, hm.c, hm.d)
		_town_dump(spot[0], float(spot[1]), 0, String(names[0][vi % names[0].size()]), hm.c)
		vi += 1


func _town_dump(p: Vector3, yaw: float, k: int, nm: String, zc: Vector3) -> Structure:
	var st := _spawn("town", p, yaw, -1, {"variant": k, "sname": nm, "zc": zc, "zr": float(Defs.TOWN_RADIUS[k])})
	st.seen_mask = 3  # everyone knows where the towns are, and who holds them
	world.rules.town_list.append(st)
	if OS.has_environment("FL_DEBUG_TOWNS"):
		print("TOWN %s %s dump=%s zone=%s r=%d" % [nm, Defs.TOWN_KINDS[k], str(p.round()), str(zc.round()), int(Defs.TOWN_RADIUS[k])])
	return st


## Where a village's dump goes: on the verge of its street, as near the
## middle as there's room, clear of the lamps and the bench, its front to the
## road (where the lorry pulls up). [pos, yaw]
func _dump_spot(tg, c: Vector3, d: Vector3) -> Array:
	var n := Vector3(-d.z, 0, d.x)
	var half := Vector2(1.8, 1.2)
	for off in [4.7, 6.6, 8.4]:
		for t in [-7.0, 7.0, 0.0, -11.0, 11.0, -24.0, 24.0, -30.0, 30.0]:
			for s in [1.0, -1.0]:
				var p: Vector3 = c + d * t + n * (s * off)
				var yaw := Defs.yaw_of(-n * s)
				if not _is_free(p, half, yaw, 0.3, false) or tg._road_dist(p, off) < off - 0.6:
					continue
				var crowded := false
				for e in tg.decor:
					if String(e[0]) in ["lamp", "bench", "pole", "bus_stop", "hydrant", "mailbox", "bin", "sign_town", "sign_stop"] and Defs.flat((e[1] as Vector3) - p).length() < 2.8:
						crowded = true
						break
				if not crowded:
					return [p, yaw]
	return [c + n * 4.7, Defs.yaw_of(-n)]


# --- water ---------------------------------------------------------------------------

## The sea along the east edge (a beach; a harbour where the cross road meets
## it), a river down the west flank (a bridge where the road crosses, a ford
## in each half) and a pond in each half. Symmetric enough between the sides
## that neither starts behind a moat. (The small map stays dry.)
func _lay_water() -> void:
	var w: WaterMap = world.water
	var H := MapDims.HALF
	if H < 300.0 or world.settings.get("dry", false):
		return
	w.coast = {"x": H - rng.randf_range(150.0, 172.0), "s": rng.randf() * 100.0}
	var x0 := -H * rng.randf_range(0.44, 0.52)
	var ph := rng.randf() * TAU
	var amp := rng.randf_range(24.0, 36.0)
	var pts := PackedVector3Array()
	var z := -H - 24.0
	while z <= H + 24.0:
		pts.append(Vector3(x0 + amp * sin(z * 0.0125 + ph) + 11.0 * sin(z * 0.033 + ph * 2.0), 0, z))
		z += 10.0
	w.rivers = [{"pts": pts, "w": rng.randf_range(18.0, 24.0)}]
	for s in [-1.0, 1.0]:
		var fz: float = s * H * rng.randf_range(0.32, 0.55)
		var best := pts[0]
		for p in pts:
			if absf(p.z - fz) < absf(best.z - fz):
				best = p
		w.fords.append(best)
	for s in [-1.0, 1.0]:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var px := rng.randf_range(90.0, 190.0) * side
		if side < 0.0:
			px = maxf(px, x0 + 80.0)
		w.ponds.append({"c": Vector3(px, 0, s * rng.randf_range(H * 0.32, H * 0.55)), "r": rng.randf_range(15.0, 24.0), "s": rng.randf() * 50.0})
	w.paint_kinds()


## The roads stop at the sea (with a harbour quay out into it) and cross the
## river on bridges.
func _roads_meet_water(tg) -> void:
	var w: WaterMap = world.water
	if w.is_empty():
		return
	var roads: Array = world.roads[2]
	for ri in roads.size():
		var pl: PackedVector3Array = roads[ri]
		var keep := PackedVector3Array()
		var cut := false
		for p in pl:
			if p.x > w.coast_x(p.z) - 24.0:
				cut = true
				continue
			keep.append(p)
		if cut and keep.size() >= 2:
			roads[ri] = keep
			if pl == tg.cross_road:
				tg.cross_road = keep
			# the harbour: a concrete quay out into the sea at the road's end
			var end: Vector3 = keep[keep.size() - 1]
			var shore := w.coast_x(end.z)
			var a := Vector3(shore - 8.0, 0, end.z)
			var b := Vector3(shore + 26.0, 0, end.z)
			w.bridges.append([a, b, 4.5, "quay"])
			world.key_points.append({"pos": a, "kind": "harbour"})
	# bridges: where a road runs over water, a deck from bank to bank
	for pl in roads:
		var pts: PackedVector3Array = pl
		var run_a := Vector3.INF
		var last := Vector3.INF
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var steps := maxi(1, int(Defs.flat(b - a).length()))
			for k in steps:
				var p := a.lerp(b, float(k) / steps)
				if w.wet_at(p):
					if run_a == Vector3.INF:
						run_a = p
					last = p
				elif run_a != Vector3.INF and Defs.flat(p - last).length() > 3.0:
					var d := Defs.flat(last - run_a).normalized()
					w.bridges.append([run_a - d * 4.0, last + d * 4.0, 3.9, "bridge"])
					world.key_points.append({"pos": (run_a + last) * 0.5, "kind": "bridge"})
					run_a = Vector3.INF
	w.paint_kinds()
	for br in w.bridges:
		var a: Vector3 = br[0]
		var b: Vector3 = br[1]
		var d := Defs.flat(b - a)
		_spawn("bridge", (a + b) * 0.5, Defs.yaw_of(d), -1, {"size": Vector3(float(br[2]) * 2.0, 0, d.length()), "variant": 1 if br.size() > 3 and br[3] == "quay" else 0})
		_place([Vector2((a.x + b.x) * 0.5, (a.z + b.z) * 0.5), Vector2(float(br[2]) + 1.0, d.length() * 0.5 + 1.0), Defs.yaw_of(d)])
	w.carve()
	world.nav.build_boat_grid(w)
	if OS.has_environment("FL_DEBUG_WATER"):
		print("WATER coast x=%.0f river x0=%.0f fords=%s ponds=%s bridges=%s" % [float(w.coast.x), (w.rivers[0].pts as PackedVector3Array)[60].x,
			str(w.fords), str(w.ponds.map(func(p): return p.c)), str(w.bridges.map(func(b): return [(b[0] + b[1]) * 0.5, b[3]]))])


## The defensive works, in the order --scenario=works lays them out.
const WORKS := ["sandbags", "hesco", "barricade", "concrete_wall", "wire", "tank_trap", "mines", "ammo_cache", "mg_nest", "hmg_nest", "mortar_pit", "at_post", "bunker", "watchtower", "camo_net"]


## Small hand-built test setups used by automated checks (--scenario=NAME).
func scenario(sname: String) -> void:
	var r := world.rules
	var d0 := _spawn("depot", Vector3(0, 0, 116), 0.0, 0)
	var d1 := _spawn("depot", Vector3(0, 0, -116), PI, 1)
	r.depots = [d0, d1]
	var f0 := _spawn("fob", Vector3(60, 0, 95), 0.0, 0, {"sname": r.next_fob_name(0), "supply": 2000.0})
	var f1 := _spawn("fob", Vector3(60, 0, -95), PI, 1, {"sname": r.next_fob_name(1), "supply": 2000.0})
	r.register_start_fob(f0)
	r.register_start_fob(f1)
	var a := 1 if world.settings.get("scenario_player", false) else -1
	var b := -2
	match sname:
		"stress": StressBattle.populate(world)
		"air":
			var hp2 := _spawn("helipad", Vector3(0, 0, 60), 0.0, 0)
			var gs: Vehicle = world.spawn("vehicle", {"vkind": "gunship", "team": 0, "owner": a, "pos": Vector3(0, 20, 50), "yaw": 0.0})
			gs.order_move(Vector3(0, 0, -20))
			world.spawn("vehicle", {"vkind": "humvee", "team": 0, "owner": a, "pos": Vector3(12, 0, 20), "yaw": 0.0}).order_move(Vector3(12, 0, -10))
			world.spawn("vehicle", {"vkind": "aa_tech", "team": 1, "owner": b, "pos": Vector3(-20, 0, -60), "yaw": PI}).order_move(Vector3(-15, 0, -45))
			world.spawn("vehicle", {"vkind": "technical", "team": 1, "owner": b, "pos": Vector3(20, 0, -55), "yaw": PI}).order_stop()
			for i in 2:
				r.spawn_squad("fighter_cell", 1, b, Vector3(-10 + i * 20, 0, -40))
		"support":
			for i in 3:
				r.spawn_squad("fighter_cell", 1, b, Vector3(-12 + i * 12, 0, -30))
			r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, 40))
			r.support_ready = [{"airstrike": 0.0, "a10": 0.0, "wipeout": 0.0, "ac130": 0.0, "blackfish": 0.0, "artillery": 0.0}, {"barrage": 0.0, "mortars": 0.0}]
			r.call_support(-1, 0, "airstrike", Vector3(0, 0, -30))
			r.call_support(-2, 1, "barrage", Vector3(30, 0, 30))
		"recon":
			# getting eyes on: a Coalition squad at a manned watchtower, three
			# Rebel cells out beyond its sight (the west one inside the tower's
			# reach only with a lookout up it), a recon pass across them, and a
			# Rebel spotter plane and drone over the Coalition; FL_DEBUG_VISION=1
			# prints what each side sees as it goes
			_spawn("watchtower", Vector3(-40, 0, 64), 0.0, 0, {"built": true})
			r.spawn_squad("rifle_squad", 0, a, Vector3(-36, 0, 60))
			r.spawn_squad("rifle_squad", 0, a, Vector3(10, 0, 70))
			for p in [Vector3(-60, 0, -40), Vector3(0, 0, -50), Vector3(60, 0, -40)]:
				r.spawn_squad("fighter_cell", 1, b, p)
			world.spawn("vehicle", {"vkind": "technical", "team": 1, "owner": b, "pos": Vector3(30, 0, -70), "yaw": PI}).order_stop()
			r.support_ready = [{"gryphon_recon": 0.0, "greyhawk_watch": 0.0}, {"caesar_spotter": 0.0, "fenghuang_watch": 0.0}]
			r.call_support(-1, 0, "gryphon_recon", Vector3(0, 0, -45), Vector3(1, 0, 0))
			r.call_support(-2, 1, "fenghuang_watch", Vector3(0, 0, 60))
			r.call_support(-2, 1, "caesar_spotter", Vector3(0, 0, 40))
		"showroom":
			var kinds := ["tank", "old_tank", "technical", "truck"]
			for i in kinds.size():
				var v: Vehicle = world.spawn("vehicle", {"vkind": kinds[i], "team": 0, "owner": a, "pos": Vector3(-14 + i * 9.0, 0, 0), "yaw": 0.4})
				v.order_stop()
			_spawn("barracks", Vector3(-20, 0, -22), 0.0, 0)
			_spawn("research", Vector3(-38, 0, -22), 0.0, 0)
			_spawn("fob", Vector3(42, 0, -34), 0.0, 0, {"sname": "Showroom"})
			_spawn("factory", Vector3(0, 0, -24), 0.0, 0)
			_spawn("medic_tent", Vector3(18, 0, -20), 0.0, 0)
			_spawn("bunker", Vector3(-22, 0, 16), 0.0, 0)
			_spawn("bunker", Vector3(-8, 0, 18), 0.0, 1)
			_spawn("hmg_nest", Vector3(5, 0, 16), 0.0, 0)
			_spawn("mortar_pit", Vector3(14, 0, 16), 0.0, 0)
			_spawn("watchtower", Vector3(24, 0, 14), 0.0, 0)
			for i in 3:
				_spawn("trench", Vector3(-12 + i * 6.0, 0, 28), 0.0, 0)
				_spawn("sandbags", Vector3(10 + i * 4.2, 0, 26), 0.0, 0, {"size": Vector3(4, 1, 0.9)})
			_spawn("wreck", Vector3(30, 0, -2), 0.7, -1, {"variant": 0})
			_spawn("wreck", Vector3(30, 0, -14), 2.1, -1, {"variant": 1})
			for i in 4:
				_spawn("tree", Vector3(-36 + i * 4.0, 0, -6 + (i % 2) * 5.0), 0.0, -1)
			_spawn("house_wall", Vector3(36, 0, 20), 0.0, -1, {"size": Vector3(6, 0, 0.4), "variant": 1})
			_spawn("house_wall", Vector3(36, 0, 28), 0.0, -1, {"size": Vector3(6, 2, 0.4)})
			_spawn("low_wall", Vector3(-30, 0, 30), 0.0, -1, {"size": Vector3(4, 1, 0.5), "variant": 2})
			_spawn("low_wall", Vector3(-30, 0, 24), 0.0, -1, {"size": Vector3(4, 1, 0.5), "variant": 0})
			_spawn("car", Vector3(-30, 0, 8), 0.5, -1, {"variant": 1})
		"works":
			# every defensive work both sides can build, finished, in a row facing
			# south (the camera): the Coalition's in front, the Rebels' behind -
			# lines of the linear works, a short zig-zag of trench at the end
			for tm in 2:
				var x := -46.0
				var z := 10.0 - tm * 18.0
				for k in WORKS:
					if not tm in Defs.BUILDINGS[k].teams:
						continue
					var w: float = Defs.BUILDINGS[k].size.x
					var n := 2 if k in ["sandbags", "concrete_wall", "wire", "hesco", "barricade"] else (3 if k == "tank_trap" else 1)
					for i in n:
						x += w * 0.5 + (0.6 if k == "tank_trap" and i > 0 else 0.0)
						_spawn(k, Vector3(x, 0, z), PI, tm, {"built": true})
						if k == "camo_net":
							_spawn("car", Vector3(x, 0, z), PI * 0.8, -1, {"variant": 2})  # something to hide under it
						x += w * 0.5
					x += 3.0
				_trench_line(Vector3(x, 0, z - 1.0), Vector3(x + 16.0, 0, z - 1.0), tm)
		"cache":
			# the ammo cache and the camouflage net at work. Out of the way, a rifle
			# squad with its pouches empty beside a cache (blown up at 12 s: it
			# cooks off). At the front, a rifle squad looking at two Rebel cells
			# 34 m off - inside a man's sight, outside half of it - one under a net,
			# one in the open. FL_DEBUG_WORKS=1 prints what the Coalition sees
			# before the shooting starts, and who has filled up.
			var cache := _spawn("ammo_cache", Vector3(70, 0, 48), 0.0, 0, {"built": true})
			var sq := r.spawn_squad("rifle_squad", 0, a, Vector3(70, 0, 52))
			for m in sq.members:
				m.mag = 0
				m.reserve = 0
			var eyes := r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, 12))
			_spawn("camo_net", Vector3(-6, 0, -22), 0.0, 1, {"built": true})
			var hid := r.spawn_squad("fighter_cell", 1, b, Vector3(-6, 0, -22))
			var open := r.spawn_squad("fighter_cell", 1, b, Vector3(16, 0, -22))
			for q in [eyes, hid, open]:
				q.order_defend(q.centroid(), Vector3(0, 0, -1 if q == eyes else 1))
			if OS.has_environment("FL_DEBUG_WORKS"):
				world.get_tree().create_timer(2.5, true, true).timeout.connect(func():
					var n := [0, 0, 0, 0]  # under the net / of them seen, in the open / of them seen
					for m in hid.members + open.members:
						var k := 0 if world.terrain.net_cover(m.position) < 1.0 else 2
						n[k] += 1
						n[k + 1] += m.vis_mask & 1
					print("WORKS t=2.5 under_net=%d seen=%d  in_open=%d seen=%d" % n))
				world.get_tree().create_timer(8.0, true, true).timeout.connect(func():
					var full := 0
					for m in sq.members:
						if is_instance_valid(m) and m.ammo_fraction() > 0.9:
							full += 1
					print("WORKS t=8 resupplied=%d/%d cache_left=%.0f" % [full, sq.members.size(), cache.supply]))
			world.get_tree().create_timer(12.0, true, true).timeout.connect(func():
				if is_instance_valid(cache) and not cache.gone:
					cache.take_damage(9999.0))
		"guns":
			# the crew-served guns side by side, each crewed: M240B and M2HB nests,
			# PKM and DShKM nests, and a machine-gun bay of each side in a trench
			var row := [["mg_nest", 0], ["hmg_nest", 0], ["mg_nest", 1], ["hmg_nest", 1]]
			for i in row.size():
				var st := _spawn(String(row[i][0]), Vector3(-16 + i * 10.0, 0, 0), PI, int(row[i][1]), {"built": true})
				_crew(st, a if int(row[i][1]) == 0 else b)
			_trench_line(Vector3(-18, 0, 16), Vector3(18, 0, 16), 0, false)
			for i in 4:
				var sp := world.trench_mount_spot(Vector3(-13.5 + i * 9.0, 0, 16), PI)
				if sp.is_empty():
					continue
				var bay := _spawn(["mg_nest", "hmg_nest"][i % 2], sp.pos, float(sp.yaw), 0 if i < 2 else 1, {"built": true, "variant": 1})
				_crew(bay, a if i < 2 else b)
			# something for each side's guns to shoot at, out in front
			r.spawn_squad("fighter_cell", 1, b, Vector3(-10, 0, 38), Vector3(-10, 0, 46))
			r.spawn_squad("rifle_squad", 0, a, Vector3(10, 0, 38), Vector3(10, 0, 46))
		"drone":
			r.spawn_squad("fpv_team", 1, b, Vector3(0, 0, -105))
			var tank: Vehicle = world.spawn("vehicle", {"vkind": "tank", "team": 0, "owner": a, "pos": Vector3(0, 0, 0), "yaw": 0.0})
			tank.order_stop()
			r.spawn_squad("rifle_squad", 0, a, Vector3(10, 0, 5))
		"cover":
			for i in 3:
				_spawn("low_wall", Vector3(-6 + i * 4.2, 0, -12), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			_spawn("tall_wall", Vector3(14, 0, -12), 0.0, -1, {"size": Vector3(4, 2.6, 0.5)})
			_spawn("crates", Vector3(-14, 0, -12), 0.0, -1, {"variant": 1})
			_spawn("car", Vector3(-20, 0, -12), PI * 0.5, -1, {"variant": 1})
			r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, -6), Vector3(0, 0, -10))
			r.spawn_squad("fighter_cell", 1, b, Vector3(0, 0, -60), Vector3(0, 0, -52))
		"tank":
			_spawn("low_wall", Vector3(0, 0, -20), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			_spawn("tall_wall", Vector3(4.2, 0, -20), 0.0, -1, {"size": Vector3(4, 2.6, 0.5)})
			var t2: Vehicle = world.spawn("vehicle", {"vkind": "tank", "team": 0, "owner": a, "pos": Vector3(2, 0, 0), "yaw": 0.0})
			t2.order_move(Vector3(2, 0, -45))
			r.spawn_squad("rpg_team", 1, b, Vector3(-30, 0, -50))
			r.spawn_squad("fighter_cell", 1, b, Vector3(20, 0, -55))
		"defense":
			for i in 4:
				_spawn("trench", Vector3(-12 + i * 6.0, 0, -10), 0.0, 0)
			_spawn("hmg_nest", Vector3(-20, 0, -7), 0.0, 0)
			_spawn("mortar_pit", Vector3(0, 0, 14), 0.0, 0)
			var bk := _spawn("bunker", Vector3(18, 0, -7), 0.0, 0)
			_spawn("at_post", Vector3(6, 0, -3), 0.0, 0)
			r.spawn_squad("rifle_squad", 0, a, Vector3(-4, 0, 0), Vector3(-3, 0, -10))
			var sq2 := r.spawn_squad("rifle_squad", 0, a, Vector3(14, 0, 4))
			sq2.order_enter(bk)
			r.spawn_squad("mg_team", 0, a, Vector3(-18, 0, -2))
			r.spawn_squad("mortar_team", 0, a, Vector3(3, 0, 17))
			r.spawn_squad("at_team", 0, a, Vector3(7, 0, 1))
			for i in 3:
				r.spawn_squad("fighter_cell", 1, b, Vector3(-25 + i * 25, 0, -95), Vector3(-25 + i * 25, 0, -18))
			var tech: Vehicle = world.spawn("vehicle", {"vkind": "technical", "team": 1, "owner": b, "pos": Vector3(35, 0, -100), "yaw": PI})
			tech.order_move(Vector3(15, 0, -25))
			var otk: Vehicle = world.spawn("vehicle", {"vkind": "old_tank", "team": 1, "owner": b, "pos": Vector3(-35, 0, -105), "yaw": PI})
			otk.order_move(Vector3(-10, 0, -28))
		"trenches":
			# a Rebel trench system: zig-zag front line, a second line, communication
			# trenches between them, MG nests and a bunker; a Coalition armoured assault
			_trench_line(Vector3(-36, 0, -28), Vector3(36, 0, -28), 1)
			_trench_line(Vector3(-24, 0, -52), Vector3(24, 0, -52), 1)
			_trench_line(Vector3(-12, 0, -28), Vector3(-12, 0, -52), 1, false)
			_trench_line(Vector3(12, 0, -28), Vector3(12, 0, -52), 1, false)
			# a gun bay in the front line, and a sandbagged .50 behind it
			var bay2 := world.trench_mount_spot(Vector3(-22, 0, -28), PI)
			if not bay2.is_empty():
				_spawn("mg_nest", bay2.pos, float(bay2.yaw), 1, {"variant": 1})
			_spawn("hmg_nest", Vector3(24, 0, -33), PI, 1)
			_spawn("bunker", Vector3(0, 0, -58), PI, 1)
			_spawn("wire", Vector3(-15, 0, -16), 0.0, 1)
			_spawn("wire", Vector3(-8, 0, -15), 0.0, 1)
			_spawn("wire", Vector3(8, 0, -16), 0.0, 1)
			world.terrain.tick(1 << 30)
			for i in 3:
				var dq := r.spawn_squad("fighter_cell" if i != 1 else "rpg_team", 1, b, Vector3(-20 + i * 20, 0, -40))
				dq.order_defend(Vector3(-20 + i * 20, 0, -28), Vector3(0, 0, 1))
			var pq := r.spawn_squad("pkm_team", 1, b, Vector3(4, 0, -48))
			pq.order_defend(Vector3(4, 0, -52), Vector3(0, 0, 1))
			if not world.settings.get("static", false):
				for i in 2:
					var tk: Vehicle = world.spawn("vehicle", {"vkind": "tank", "team": 0, "owner": a, "pos": Vector3(-14 + i * 28, 0, 70), "yaw": 0.0})
					tk.order_assault(Vector3(-14 + i * 28, 0, -30))
				for i in 2:
					var ifv: Vehicle = world.spawn("vehicle", {"vkind": "ifv", "team": 0, "owner": a, "pos": Vector3(-6 + i * 12, 0, 80), "yaw": 0.0})
					ifv.embark_new_squad()
					ifv.order_assault(Vector3(-6 + i * 12, 0, -22))
				for i in 2:
					var aq := r.spawn_squad("rifle_squad", 0, a, Vector3(-10 + i * 20, 0, 82))
					aq.order_assault(Vector3(-10 + i * 20, 0, -30), Vector3(0, 0, -1))
		"attack":
			# a deliberate attack: two rifle squads and a gun team against a
			# fighter cell holding a walled farmyard
			for i in 3:
				_spawn("low_wall", Vector3(-8 + i * 4.2, 0, -40), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			_spawn("sandbags", Vector3(6, 0, -41), 0.0, 1)
			_spawn("low_wall", Vector3(-12, 0, -44), PI * 0.5, -1, {"size": Vector3(4, 1, 0.5)})
			for i in 5:
				_try("tree", Vector3(-34 + i * 3.0, 0, -12 - i * 4.0), 0.0, -1)
				_try("tree", Vector3(30 + i * 2.0, 0, -6 - i * 5.0), 0.0, -1)
			_spawn("crates", Vector3(-24, 0, 6), 0.4, -1, {"variant": 1})
			_spawn("low_wall", Vector3(18, 0, 8), 0.0, -1, {"size": Vector3(4, 1, 0.5), "variant": 1})
			var dq1 := r.spawn_squad("fighter_cell", 1, b, Vector3(-4, 0, -44))
			dq1.order_defend(Vector3(-2, 0, -42), Vector3(0, 0, 1))
			var sqa := []
			for i in 2:
				sqa.append(r.spawn_squad("rifle_squad", 0, a, Vector3(-10 + i * 20, 0, 30)))
			sqa.append(r.spawn_squad("mg_team", 0, a, Vector3(0, 0, 34)))
			if not world.settings.get("static", false):
				var ids := []
				for sq in sqa:
					ids.append(sq.sid)
				world.execute_cmd(a, {"t": "assault", "squads": ids, "pos": Vector3(-2, 0, -42), "face": Vector3(0, 0, -1)})
		"solo":
			# one squad attacks on its own: fire team Alpha fixes, Bravo flanks
			_spawn("sandbags", Vector3(0, 0, -36), 0.0, 1)
			_spawn("low_wall", Vector3(-6, 0, -36), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			for i in 5:
				_try("tree", Vector3(-26 + i * 3.0, 0, -6 - i * 5.0), 0.0, -1)
			var dq2 := r.spawn_squad("fighter_cell", 1, b, Vector3(-2, 0, -39))
			dq2.order_defend(Vector3(-2, 0, -37), Vector3(0, 0, 1))
			var sq2 := r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, 30))
			if not world.settings.get("static", false):
				world.execute_cmd(a, {"t": "assault", "squads": [sq2.sid], "pos": Vector3(-2, 0, -37), "face": Vector3(0, 0, -1)})
		"poses":
			# animation gallery: every stance frozen in a row, three-quarter view
			var P := Soldier.Post
			var A := Soldier.Act
			var rows := [
				[[P.STAND, A.IDLE, 0, 0.0], [P.STAND, A.SHOOT, 0, 0.0], [P.STAND, A.RELOAD, 0, 0.0], [P.STAND, A.WALK, 0, 1.6], [P.STAND, A.RUN, 0, 4.8], [P.STAND, A.THROW, 0, 0.0]],
				[[P.CROUCH, A.IDLE, 0, 0.0], [P.CROUCH, A.SHOOT, 0, 0.0], [P.CROUCH, A.WALK, 0, 1.5], [P.LEAN_L, A.SHOOT, 0, 0.0], [P.LEAN_R, A.SHOOT, 0, 0.0], [P.CROUCH, A.RELOAD, 0, 0.0]],
				[[P.PRONE, A.IDLE, 0, 0.0], [P.PRONE, A.SHOOT, 0, 0.0], [P.PRONE, A.CRAWL, 0, 1.0], [P.STAND, A.IDLE, 2, 0.0], [P.STAND, A.IDLE, 2, 0.0], [P.STAND, A.IDLE, 2, 0.0]],
				[[P.STAND, A.SHOOT, 0, 0.0, Soldier.F_OVERWALL], [P.STAND, A.IDLE, 0, 0.0, Soldier.F_OVERWALL], [P.PRONE, A.CRAWL, 0, 0.75], [P.CROUCH, A.IDLE, 0, 0.0], [P.STAND, A.SHOOT, 0, 0.0, Soldier.F_OVERWALL], [P.PRONE, A.CRAWL, 0, 0.75]],
			]
			# a low wall in front of the over-the-wall men
			for wx in [-7.5, -4.5, 4.5]:
				_spawn("low_wall", Vector3(wx, 0, 8.0 - 0.75), 0.0, -1, {"size": Vector3(2.6, 1, 0.5)})
			# fighting from cover, each man behind a wall of the height he's posed
			# for: kneeling over it, ducked behind it, standing over a chest-high
			# one, prone behind a low one, firing blind, reloading down behind it
			var F := Soldier.F_OVERWALL
			var cov := [[P.CROUCH, A.SHOOT, 0, 0.0, F, 0.92, 1], [P.CROUCH, A.IDLE, 0, 0.0, 0, 0.92, 1], [P.STAND, A.SHOOT, 0, 0.0, F, 1.32, 1],
				[P.PRONE, A.SHOOT, 0, 0.0, F, 0.48, 1], [P.CROUCH, A.SHOOT, 0, 0.0, 0, 1.0, 2], [P.CROUCH, A.RELOAD, 0, 0.0, 0, 1.0, 1]]
			for ci in cov.size():
				var c: Array = cov[ci]
				var h: float = c[5]
				var z := 16.0
				_spawn("low_wall", Vector3(-7.5 + ci * 3.0, 0, z - Cover.offset(h) - 0.25), 0.0, -1, {"size": Vector3(2.4, h - 0.08, 0.5)})
				var code := clampi(int(round(h / 0.04)), 1, 63) | (int(c[6]) << 6)
				world.spawn("soldier", {"utype": "rifleman", "team": 0 if ci % 2 == 0 else 1, "owner": a, "pos": Vector3(-7.5 + ci * 3.0, 0, z), "yaw": 0.0,
					"name": "C%d" % ci, "dpose": [c[0], c[1], c[2], c[3], c[4], code]})
			# gaits (walk, jog, sprint, crouched walk, low rush, walking while
			# firing off to the side) and the grenade reflexes (kick, lying on
			# it, cooking it standing and kneeling, the throw)
			var gaits := [
				[[P.STAND, A.WALK, 0, 1.5], [P.STAND, A.RUN, 0, 3.4], [P.STAND, A.RUN, 0, 5.3], [P.CROUCH, A.WALK, 0, 1.6], [P.CROUCH, A.RUN, 0, 3.6], [P.STAND, A.SHOOT, 0, 1.5, Soldier.F_SHOOTING, 0, 1.4]],
				[[P.STAND, A.KICK, 0, 0.0], [P.PRONE, A.SMOTHER, 0, 0.0], [P.STAND, A.COOK, 0, 0.0], [P.CROUCH, A.COOK, 0, 0.0], [P.STAND, A.THROW, 0, 0.0], [P.CROUCH, A.SHOOT, 0, 1.2, Soldier.F_SHOOTING, 0, -1.4]],
			]
			for gi in gaits.size():
				for ci in gaits[gi].size():
					world.spawn("soldier", {"utype": "rifleman", "team": 0 if ci % 2 == 0 else 1, "owner": a, "pos": Vector3(-7.5 + ci * 3.0, 0, -8.0 - gi * 4.0), "yaw": 2.3, "name": "G%d%d" % [gi, ci], "dpose": gaits[gi][ci]})
			for ri in rows.size():
				var row: Array = rows[ri]
				for ci in row.size():
					var ut := "rifleman" if ri != 1 or ci != 2 else "mg_gunner"
					world.spawn("soldier", {"utype": ut, "team": 0 if ci % 2 == 0 else 1, "owner": a, "pos": Vector3(-7.5 + ci * 3.0, 0, -4.0 + ri * 4.0), "yaw": 2.3 if ri < 3 else 0.35, "name": "P%d%d" % [ri, ci], "dpose": row[ci]})
		"roster":
			# every vehicle both sides can field, facing each other across the
			# middle: ground vehicles push in, artillery stays back and shoots,
			# helicopters and drones fly over (a test of every behaviour)
			var cols := [0, 0]
			for k in Defs.VEHICLES:
				var d: Dictionary = Defs.VEHICLES[k]
				var tm := int(d.team)
				if tm < 0 or tm > 1 or d.get("auto", false):
					continue
				var side := 1.0 if tm == 0 else -1.0
				var i: int = cols[tm]
				cols[tm] = i + 1
				var x := -96.0 + float(i % 17) * 12.0
				var z := side * (40.0 + float(i / 17) * 14.0)
				var owner := a if tm == 0 else b
				var v: Vehicle = world.spawn("vehicle", {"vkind": k, "team": tm, "owner": owner, "pos": Vector3(x, 0, z), "yaw": 0.0 if tm == 0 else PI})
				v.heli_home = f0 if tm == 0 else f1
				v.embark_new_squad()
				if String(d.base) == "arty":
					continue
				if d.get("air", false):
					v.order_move(Vector3(x * 0.5, 0, -side * 30.0))
				else:
					v.order_assault(Vector3(x * 0.6, 0, side * 6.0))
		"lean":
			for i in 3:
				_spawn("tall_wall", Vector3(-14 + i * 14.0, 0, -10), 0.0, -1, {"size": Vector3(6, 2.6, 0.5)})
			r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, 0), Vector3(0, 0, -6))
			r.spawn_squad("fighter_cell", 1, b, Vector3(0, 0, -55), Vector3(0, 0, -45))
		"heli":
			var pad := _spawn("helipad", Vector3(30, 0, 100), 0.0, 0, {"built": true})
			pad.queue_item(a, "heli")
			f0.supply = 100.0
		"tunnel":
			var t1 := _spawn("tunnel", Vector3(-20, 0, -60), 0.0, 1, {"built": true})
			var t2 := _spawn("tunnel", Vector3(30, 0, 10), 0.0, 1, {"built": true})
			var sq := r.spawn_squad("fighter_cell", 1, b, Vector3(-20, 0, -50))
			sq.order_enter(t1)
			# the scenario may be torn down before it fires
			world.get_tree().create_timer(12.0, true, true).timeout.connect(func():
				if is_instance_valid(r) and is_instance_valid(t1) and is_instance_valid(t2) and not t1.gone and not t2.gone:
					r.tunnel_exit(t1, t2, b))
		"grenade":
			for i in 2:
				_spawn("low_wall", Vector3(-2 + i * 4.2, 0, -16), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, 0), Vector3(0, 0, -6))
			r.spawn_squad("fighter_cell", 1, b, Vector3(0, 0, -40), Vector3(0, 0, -20))
		"sling":
			# sling loads: a Mohawk picks up a Humvee and carries it 150 m; a
			# Taru does the same with a BTR
			var mh = world.spawn("vehicle", {"vkind": "mohawk", "team": 0, "owner": a, "pos": Vector3(-20, 0, 40), "yaw": PI})
			var hv = world.spawn("vehicle", {"vkind": "humvee", "team": 0, "owner": a, "pos": Vector3(-20, 0, 10), "yaw": PI})
			var tr = world.spawn("vehicle", {"vkind": "taru_lift", "team": 1, "owner": b, "pos": Vector3(170, 0, -60), "yaw": 0.0})
			var bt = world.spawn("vehicle", {"vkind": "btr", "team": 1, "owner": b, "pos": Vector3(170, 0, -30), "yaw": 0.0})
			if not world.settings.get("static", false):
				world.get_tree().create_timer(1.0, true, true).timeout.connect(func():
					mh.order_sling(hv)
					tr.order_sling(bt))
				world.get_tree().create_timer(16.0, true, true).timeout.connect(func():
					mh.order_move(Vector3(-60, 0, -120))
					tr.order_move(Vector3(220, 0, 60)))
				for k in 10:
					world.get_tree().create_timer(4.0 + k * 5.0, true, true).timeout.connect(func():
						if OS.has_environment("FL_DEBUG_SLING"):
							print("SLING t=%.0f mohawk=%s ph=%d humvee=%s btr=%s" % [world.time, mh.position.snapped(Vector3.ONE * 0.1), mh.lift_phase, hv.position.snapped(Vector3.ONE * 0.1), bt.position.snapped(Vector3.ONE * 0.1)]))
		"naval":
			# boats on the sea: a Coalition RHIB lands a squad on the coast the
			# Rebels hold, its patrol ship covering it; Rebel boats come out to fight
			_lay_water()
			var w: WaterMap = world.water
			w.carve()
			world.nav.build_boat_grid(w)
			var dz := 70.0
			var dk := _spawn("dock", Vector3(w.coast_x(dz) - 9.0, 0, dz), -PI * 0.5, 0, {"built": true})
			if OS.has_environment("FL_DEBUG_WATER"):
				print("NAVALSC dock=%s rhib_at=%s" % [dk.position, Vector3(w.coast_x(dz) + 30.0, 0, dz - 10.0)])
			dk.built = true
			var rh = world.spawn("vehicle", {"vkind": "rhib", "team": 0, "owner": a, "pos": world.nav.nearest_boat(Vector3(w.coast_x(dz) + 30.0, 0, dz - 10.0)), "yaw": PI})
			var rq := r.spawn_squad("rifle_squad", 0, a, Vector3(w.coast_x(dz) - 20.0, 0, dz))
			for m in rq.members:
				rh.board(m)
			world.spawn("vehicle", {"vkind": "patrol_ship", "team": 0, "owner": a, "pos": world.nav.nearest_boat(Vector3(w.coast_x(30.0) + 60.0, 0, 30.0)), "yaw": PI})
			var sb = world.spawn("vehicle", {"vkind": "speedboat_hmg", "team": 1, "owner": b, "pos": world.nav.nearest_boat(Vector3(w.coast_x(-90.0) + 50.0, 0, -90.0)), "yaw": 0.0})
			var mb = world.spawn("vehicle", {"vkind": "motorboat", "team": 1, "owner": b, "pos": world.nav.nearest_boat(Vector3(w.coast_x(-110.0) + 30.0, 0, -110.0)), "yaw": 0.0})
			var bq := r.spawn_squad("fighter_cell", 1, b, Vector3(w.coast_x(-30.0) - 18.0, 0, -30.0))
			bq.order_defend(Vector3(w.coast_x(-30.0) - 18.0, 0, -30.0), Vector3(1, 0, 0))
			if not world.settings.get("static", false):
				world.get_tree().create_timer(2.0, true, true).timeout.connect(func():
					# the beach up the coast from the Rebels' cell, under the patrol
					# ship's guns: an open boat run in on the cell itself is shot to
					# pieces by its rifles before it touches the sand (a raid lands
					# away from them too: NavalAI._launch)
					rh.order_move(Vector3(w.coast_x(40.0) - 4.0, 0, 40.0))
					sb.order_assault(Vector3(w.coast_x(40.0) + 40.0, 0, 40.0))
					mb.order_assault(Vector3(w.coast_x(20.0) + 25.0, 0, 20.0)))
		"tactics":
			# a rifle squad sent 120 m up to hold a hamlet, with the enemy
			# reported about: it bounds there by teams and clears the houses
			doors_shut = 1
			_house(Vector3(-6, 0, -82), 8.0, 6.0, 0.0, 1.0, false, 0.0)
			_house(Vector3(9, 0, -84), 7.0, 6.0, 0.0, 1.0, false, 0.0)
			doors_shut = -1
			for i in 4:
				_try("tree", Vector3(-30 + i * 2.5, 0, -40 - i * 4.0), 0.0, -1)
			_spawn("low_wall", Vector3(14, 0, -45), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			var tq := r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, -2))
			var tm := r.spawn_squad("mg_team", 0, a, Vector3(6, 0, 0))
			for q2 in [tq, tm]:
				q2.alert_t = 1.0  # shots heard up ahead
				q2.heard.append([Vector3(-20, 0, -110), 1.0])
			if not world.settings.get("static", false):
				world.get_tree().create_timer(1.5, true, true).timeout.connect(func():
					tq.alert_t = world.time
					tm.alert_t = world.time
					tq.order_defend(Vector3(0, 0, -80), Vector3(0, 0, -1))
					tm.order_defend(Vector3(14, 0, -76), Vector3(0, 0, -1)))
		"town":
			# a village between the lines, nobody's yet, its dump half full: a rifle
			# squad goes up and takes it, then the village lorry runs the supply to
			# FOB Alpha - until a Rebel cell comes to take it back
			for i in 3:
				_house(Vector3(-24 + i * 13.0, 0, -32), 8.0, 6.0, 0.0, -1.0, false, 0.0)
			_house(Vector3(-16, 0, -6), 8.0, 6.0, 0.0, 1.0, false, 0.0)
			var tn := _town_dump(Vector3(4.7, 0, -19), Defs.yaw_of(Vector3(-1, 0, 0)), 0, "Testvale", Vector3(0, 0, -19))
			tn.supply = 100.0
			var road := PackedVector3Array()
			for i in 26:
				road.append(Vector3(0, 0, 100 - i * 9.0))
			world.roads[2] = [road]
			world._rebuild_roads()
			var tq := r.spawn_squad("rifle_squad", 0, a, Vector3(-6, 0, 40))
			var rq := r.spawn_squad("fighter_cell", 1, b, Vector3(10, 0, -150))
			if not world.settings.get("static", false):
				world.get_tree().create_timer(1.0, true, true).timeout.connect(func():
					tq.order_defend(Vector3(0, 0, -19), Vector3(0, 0, -1)))
				world.get_tree().create_timer(75.0, true, true).timeout.connect(func():
					if is_instance_valid(r) and is_instance_valid(world) and world.winner < 0:
						world.execute_cmd(b, {"t": "assault", "squads": [rq.sid], "pos": Vector3(0, 0, -19), "face": Vector3(0, 0, 1)}))
		"fire":
			# what burns and how it spreads: a wood, a hedgerow, a crate dump, parked
			# cars, a watchtower and a house, a fighter cell dug in among them. The
			# edge of the wood, the hedge and the crates are alight from the start,
			# and a rifle squad comes up to find the cell burnt out of its cover.
			_woods(Vector3(-22, 0, -30), 12)
			for i in 6:
				_spawn("low_wall", Vector3(-4 + i * 4.1, 0, -18), 0.0, -1, {"size": Vector3(4, 1, 0.9), "variant": 1})
			var cr := _spawn("crates", Vector3(12, 0, -26), 0.3, -1, {"variant": 1})
			_spawn("crates", Vector3(15, 0, -23.5), -0.2, -1, {"variant": 0})
			_spawn("car", Vector3(20, 0, -29), PI * 0.5, -1, {"variant": 1})
			_spawn("car", Vector3(24, 0, -29.5), PI * 0.5, -1, {"variant": 3})
			_spawn("watchtower", Vector3(5, 0, -33), 0.0, 1)
			_house(Vector3(32, 0, -44), 8.0, 6.0, 0.0, 1.0, false, 0.0)
			var cell := r.spawn_squad("fighter_cell", 1, b, Vector3(-14, 0, -26))
			cell.order_defend(Vector3(-14, 0, -24), Vector3(0, 0, 1))
			r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, 30), Vector3(0, 0, 0))
			# the upwind edge of the wood: the wind carries it through the trees
			var trees: Array = world.structures.filter(func(st): return st.skind == "tree")
			trees.sort_custom(func(p, q): return p.position.dot(Fires.WIND) < q.position.dot(Fires.WIND))
			for i in mini(2, trees.size()):
				world.fires.ignite(trees[i], 0.6)
			for st in world.structures:
				if st.skind == "low_wall" and st.position.x < 0.0:
					world.fires.ignite(st, 0.5)
				if st.skind == "roof":
					world.fires.ignite(st, 0.4)
			world.fires.ignite(cr, 0.8)
			world.fires.start_patch(Vector3(2, 0, -24), 2.5, 22.0, 0)
		"breach":
			# a fighter cell holed up in a house (doors shut); a rifle squad sent to clear it
			doors_shut = 1
			_house(Vector3(0, 0, -30), 8.0, 6.0, 0.0, 1.0, false, 0.0)
			_house(Vector3(14, 0, -32), 7.0, 6.0, 0.0, 1.0, false, 0.0)
			doors_shut = -1
			var hq := r.spawn_squad("fighter_cell", 1, b, Vector3(0, 0, -30))
			hq.order_defend(Vector3(0, 0, -30), Vector3(0, 0, 1))
			for i in 3:
				_spawn("low_wall", Vector3(-8 + i * 4.2, 0, -8), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			for i in 4:
				_try("tree", Vector3(-16 + i * 1.5, 0, -14 - i * 3.0), 0.0, -1)
			var sqb := []
			for i in 2:
				sqb.append(r.spawn_squad("rifle_squad", 0, a, Vector3(-8 + i * 16, 0, 2)))
			sqb.append(r.spawn_squad("mg_team", 0, a, Vector3(0, 0, 4)))
			if not world.settings.get("static", false):
				var ids2 := []
				for sq in sqb:
					ids2.append(sq.sid)
				world.execute_cmd(a, {"t": "assault", "squads": ids2, "pos": Vector3(0, 0, -30), "face": Vector3(0, 0, -1)})
		"gdrill":
			# grenade drill: frags with all sorts of fuses land among a squad
			# crowded round a wounded man (the reflexes, over and over)
			_spawn("low_wall", Vector3(8, 0, -2), 0.0, -1, {"size": Vector3(4, 1, 0.5)})
			var gq := r.spawn_squad("rifle_squad", 0, a, Vector3(0, 0, 0))
			gq.order_defend(Vector3(0, 0, 0), Vector3(0, 0, -1))
			for di in 2:
				var tm: Soldier = world.spawn("soldier", {"utype": "rifleman", "team": 0, "owner": a, "pos": Vector3(1.2 - di * 2.4, 0, 0.6), "yaw": 0.0, "name": "W%d" % di})
				tm.call_deferred("_go_down")
			for gi in 14:
				world.get_tree().create_timer(4.0 + gi * 4.5, true, true).timeout.connect(func():
					if not is_instance_valid(world) or world.winner >= 0:
						return
					# by one of the wounded if any are still lying there, else among the squad
					var c := Vector3.INF
					var hurt := []
					var up := []
					for s in world.soldiers:
						if s.team == 0 and s.life == Soldier.Life.DOWNED:
							hurt.append(s)
						elif s.team == 0 and s.life == Soldier.Life.ALIVE:
							up.append(s)
					if not hurt.is_empty():
						c = hurt[world.rng.randi() % hurt.size()].position
					elif not up.is_empty():
						c = up[world.rng.randi() % up.size()].position
					else:
						return
					var off := Vector3(world.rng.randf_range(-1.5, 1.5), 0, world.rng.randf_range(-1.5, 1.5))
					world.spawn("projectile", {"ptype": "frag", "team": 1, "pos": c + off + Vector3(0, 0.3, 0), "vel": Vector3(0, 0.5, 0), "thrower": 0,
						"fuse": world.rng.randf_range(1.2, 3.4)}))
		_:
			push_error("Unknown scenario: %s" % sname)
	r.rebuild_network(0)
	r.rebuild_network(1)


## A machine gunner for a scenario's emplacement, already on the gun.
func _crew(st: Structure, owner: int) -> void:
	var ut := "pkm" if st.team == 1 else "mg_gunner"
	var s: Soldier = world.spawn("soldier", {"utype": ut, "team": st.team, "owner": owner, "pos": st.mount_pos() * Vector3(1, 0, 1), "yaw": st.yaw})
	s.start_man(st)


func _trench_line(a: Vector3, b: Vector3, team: int, zig := true) -> void:
	for it in TrenchNet.layout(a, b, zig):
		_spawn("trench", it[0], it[1], team, {"size": Vector3(it[2], 3.0, 3.2)})


func _spawn(kind: String, pos: Vector3, yaw: float, team: int, extra := {}) -> Structure:
	pos.y += world.terrain.landform.height(pos)
	var props := {"skind": kind, "pos": pos, "yaw": yaw, "team": team}
	props.merge(extra, true)
	var st: Structure = world.spawn("structure", props)
	_place([Vector2(pos.x, pos.z), st.foot, yaw])
	return st


func _foot_of(kind: String, extra: Dictionary) -> Vector2:
	if extra.has("size"):
		var s: Vector3 = extra.size
		return Vector2(s.x * 0.5, s.z * 0.5)
	match kind:
		"wreck":
			return Vector2(1.9, 3.3)
		"car":
			return Vector2(1.0, 2.2)
		"crates":
			return Vector2(1.3, 0.7)
		"tree":
			return Vector2(0.6, 0.6)
	if Defs.BUILDINGS.has(kind):
		var s2: Vector2 = Defs.BUILDINGS[kind].size
		return s2 * 0.5
	return Vector2(1, 1)


func _is_free(pos: Vector3, half: Vector2, yaw: float, margin := 0.6, use_clear := true) -> bool:
	if not Defs.in_map(pos, 6.0):
		return false
	if not world.terrain.landform.fits(pos, half, yaw):
		return false
	if not world.water.is_empty():
		# not in the water, nor on a bridge
		var b := Basis(Vector3.UP, yaw)
		for o in [Vector3.ZERO, Vector3(half.x, 0, half.y), Vector3(-half.x, 0, half.y), Vector3(half.x, 0, -half.y), Vector3(-half.x, 0, -half.y)]:
			var q: Vector3 = pos + b * o
			if world.water.wet_at(q) or world.water.on_deck(q) or world.terrain.deform_at(q) < -0.3:
				return false
	var c := Vector2(pos.x, pos.z)
	if use_clear:
		var hl := half.length()
		for cl in _clear_big:
			if c.distance_to(cl[0]) < cl[1] + hl:
				return false
		# (the rest are no bigger than BIG: only those filed within reach can be in the way)
		var reach := hl + BIG + 1.0
		for gx in range(floori((c.x - reach) / GRID), floori((c.x + reach) / GRID) + 1):
			for gz in range(floori((c.y - reach) / GRID), floori((c.y + reach) / GRID) + 1):
				var a = _clear_at.get(Vector2i(gx, gz))
				if a == null:
					continue
				for cl in a:
					if c.distance_to(cl[0]) < cl[1] + hl:
						return false
	var h := half + Vector2(margin, margin)
	for p in _placed_big:
		if c.distance_to(p[0]) > h.length() + p[1].length() + 1.0:
			continue
		if Defs.obb_overlap(c, h, yaw, p[0], p[1], p[2]):
			return false
	var reach2 := h.length() + BIG + 2.0
	for gx in range(floori((c.x - reach2) / GRID), floori((c.x + reach2) / GRID) + 1):
		for gz in range(floori((c.y - reach2) / GRID), floori((c.y + reach2) / GRID) + 1):
			var a = _placed_at.get(Vector2i(gx, gz))
			if a == null:
				continue
			for p in a:
				if c.distance_to(p[0]) > h.length() + p[1].length() + 1.0:
					continue
				if Defs.obb_overlap(c, h, yaw, p[0], p[1], p[2]):
					return false
	return true


func _try(kind: String, pos: Vector3, yaw: float, team: int, extra := {}) -> Structure:
	if kind == "tree" and world.terrain.landform.height(pos) > world.terrain.landform.peak * 0.58 and world.terrain.landform.peak > 1.0:
		return null
	var half := _foot_of(kind, extra)
	if not _is_free(pos, half, yaw):
		return null
	return _spawn(kind, pos, yaw, team, extra)


func _wobble(pts: Array, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var n := int(d.length() / 28.0)
	var side := d.normalized().cross(Vector3.UP)
	for k in range(1, n + 1):
		var t := float(k) / (n + 1)
		pts.append(a.lerp(b, t) + side * rng.randf_range(-7.0, 7.0))


## Catmull-Rom through the control points, a point every ~3 m.
func _smooth(pts: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := pts.size()
	for i in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		var k := maxi(1, int(p1.distance_to(p2) / 3.0))
		for j in k:
			var t := float(j) / k
			var t2 := t * t
			var t3 := t2 * t
			var p := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			p.x = clampf(p.x, -(MapDims.HALF - 1.0), MapDims.HALF - 1.0)
			p.z = clampf(p.z, -(MapDims.HALF + 6.0), MapDims.HALF + 6.0)
			out.append(Vector3(p.x, 0, p.z))
	out.append(pts[n - 1])
	return out


## A roofless house of wall sections, its front (door) towards the street.
## Returns false if there's no room.
func _house(c: Vector3, w: float, d: float, axis: float, street_side: float, yard := true, ruin_p := 0.35) -> bool:
	var half := Vector2(w * 0.5 + 0.3, d * 0.5 + 0.3)
	if not _is_free(c, half, axis, 1.0):
		return false
	var b := Basis(Vector3.UP, axis)
	var color := rng.randi() % Structure.HOUSE_COLORS.size()
	var ruined := rng.randf() < ruin_p
	_spawn("floor", c, axis, -1, {"size": Vector3(w, 0.06, d)})
	_unplace_last()
	_place([Vector2(c.x, c.z), half, axis])
	# four walls: front faces the street
	var sides := [
		[Vector3(0, 0, -d * 0.5), w, 0.0],
		[Vector3(0, 0, d * 0.5), w, 0.0],
		[Vector3(-w * 0.5, 0, 0), d - 0.4, PI * 0.5],
		[Vector3(w * 0.5, 0, 0), d - 0.4, PI * 0.5],
	]
	var door_side := 0 if street_side > 0 else 1
	if rng.randf() < 0.3:
		door_side = 2 + rng.randi() % 2
	for si in 4:
		var s: Array = sides[si]
		var L: float = s[1]
		var segs := maxi(1, int(round(L / 2.8)))
		var seg_len := L / segs
		var door_i := rng.randi() % segs if si == door_side else -1
		for k in segs:
			var local_off := (k + 0.5) * seg_len - L * 0.5
			var lp: Vector3 = s[0] + (Vector3(local_off, 0, 0) if s[2] == 0.0 else Vector3(0, 0, local_off))
			var wp: Vector3 = c + b * lp
			# turned so the wall's local +z faces out of the house (the model
			# dresses that face: sills, frames, shutters, the door step)
			var yaw: float = axis + s[2] + (PI if si == 0 or si == 2 else 0.0)
			if ruined and rng.randf() < 0.3:
				if rng.randf() < 0.6:
					world.spawn("structure", {"skind": "rubble", "pos": wp, "yaw": yaw + rng.randf_range(-0.2, 0.2), "size": Vector3(seg_len * 0.9, 0, 1.2)})
				continue
			var variant := 0
			if k == door_i:
				variant = 2
			elif seg_len > 2.0 and rng.randf() < 0.5:
				variant = 1
			# most front doors are shut (decided from where it stands: the map's
			# random numbers stay as they were)
			var shut := variant == 2 and (doors_shut == 1 or (doors_shut < 0 and posmod(int(absf(wp.x) * 7.3 + absf(wp.z) * 13.1), 10) < 7))
			world.spawn("structure", {"skind": "house_wall", "pos": wp, "yaw": yaw, "variant": variant, "size": Vector3(seg_len, float(color), 0.4), "door": shut})
	# a roof on every house still standing: tiled and pitched, or flat
	if not ruined:
		world.spawn("structure", {"skind": "roof", "pos": c, "yaw": axis, "size": Vector3(w, 3.0, d), "variant": color * 2 + (1 if rng.randf() < 0.4 else 0)})
	if rng.randf() < 0.5:
		var ip := c + b * Vector3(rng.randf_range(-w * 0.25, w * 0.25), 0, rng.randf_range(-d * 0.2, d * 0.2))
		world.spawn("structure", {"skind": "crates", "pos": ip, "yaw": axis + rng.randf_range(-0.4, 0.4), "variant": 0})
	if ruined and rng.randf() < 0.6:
		var ip2 := c + b * Vector3(rng.randf_range(-w * 0.25, w * 0.25), 0, rng.randf_range(-d * 0.25, d * 0.25))
		world.spawn("structure", {"skind": "rubble", "pos": ip2, "yaw": rng.randf() * TAU, "size": Vector3(2.2, 0, 1.4)})
	# yard wall behind the house
	if yard and rng.randf() < 0.55:
		var back := -street_side
		var yc := c + b * Vector3(0, 0, back * (d * 0.5 + 5.0))
		var segs2 := int(w / 4.0)
		for k in segs2:
			if rng.randf() < 0.25:
				continue
			var lp2 := Vector3((k + 0.5) * 4.0 - segs2 * 2.0, 0, 0)
			_try("low_wall", yc + b * lp2, axis, -1, {"size": Vector3(4.0, 1.0, 0.5), "variant": 0 if rng.randf() < 0.7 else 2})
	return true


func _hedgerow() -> void:
	# field walls run on the same 1 m / 45 degree grid as everything built
	var p := TrenchNet.snap_pos(Vector3(rng.randf_range(-(MapDims.HALF - 18.0), MapDims.HALF - 18.0), 0, rng.randf_range(-(MapDims.HALF - 53.0), MapDims.HALF - 53.0)))
	var yaw := TrenchNet.snap_yaw(rng.randf() * PI)
	if rng.randf() < 0.6:
		yaw = 0.0 if rng.randf() < 0.5 else PI * 0.5
	var dir := Vector3(cos(yaw), 0, -sin(yaw))
	var n := rng.randi_range(4, 10)
	var variant := 1 if rng.randf() < 0.55 else 0
	for i in n:
		if rng.randf() < 0.12:
			continue
		var c := p + dir * (i - n * 0.5) * 4.0
		_try("low_wall", c, yaw, -1, {"size": Vector3(4.0, 1.0, 0.5), "variant": variant})


func _crate_cluster(c: Vector3) -> void:
	for i in rng.randi_range(1, 4):
		var p := c + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
		_try("crates", p, rng.randf() * TAU, -1, {"variant": rng.randi() % 2})


func _old_position(c: Vector3) -> void:
	c = TrenchNet.snap_pos(c)
	var yaw := TrenchNet.snap_yaw(rng.randf_range(-0.4, 0.4) + (0.0 if rng.randf() < 0.7 else PI * 0.5))
	var dir := Vector3(cos(yaw), 0, -sin(yaw))
	if rng.randf() < 0.5:
		var n := rng.randi_range(2, 4)
		var items := TrenchNet.layout(c, c + dir * n * 6.0, rng.randf() < 0.6)
		for it in items:
			if not _is_free(it[0], Vector2(float(it[2]) * 0.5 + TrenchNet.HALF_W, 1.6), it[1]):
				return
		for it in items:
			_spawn("trench", it[0], it[1], -1, {"size": Vector3(it[2], 3.0, 3.2)})
	else:
		for i in rng.randi_range(2, 4):
			_try("sandbags", c + dir * i * 4.2, yaw, -1)
		_try("sandbags", c - dir * 2.5 + dir.cross(Vector3.UP) * 2.0, yaw + PI * 0.5, -1)


func _woods(c: Vector3, n: int) -> void:
	if n >= 9:
		world.key_points.append({"pos": c, "kind": "woods"})
	for i in n:
		var p := c + Vector3(rng.randf_range(-11, 11), 0, rng.randf_range(-11, 11))
		_try("tree", p, 0.0, -1)
