class_name NavalAI
extends RefCounted
## The AI commander's navy. Once it has a factory and the map has a coast it
## builds a Boat Dock on its own stretch of shore, and keeps a gunboat or two
## and a transport there:
##   - gunboats go after whatever of the enemy it can see near the water (men
##     on the beach, boats, trucks on the coast road) and otherwise patrol the
##     water off the front;
##   - the transport runs raids: it picks up an idle squad at the shore, takes
##     it round by water and lands it on a beach on the enemy's flank, near
##     whatever the commander is attacking, then comes back for more.
## Boats live on the water nav (Nav.find_boat_path); everything here is
## orders through the same command interface a player uses.

const TICK := 5.0


static func armed(v: Vehicle) -> bool:
	return String(v.vdef.get("mg", "")) != "" or v.vdef.get("cannon", false)


static func transport(v: Vehicle) -> bool:
	return v.seats() > 0


# --- the dock ---------------------------------------------------------------------------

static func dock_wanted(c, sup: int) -> bool:
	var w: WaterMap = c.world.water
	if w.coast.is_empty() or not c._my_structs("dock").is_empty() or c._my_structs("factory").is_empty():
		return false
	return c.world.time > 420.0 and sup > int(Defs.BUILDINGS.dock.cost) + 60 + c._fob_reserve()


## A spot on our stretch of the coast, the jetty out into the sea: [pos, yaw] or [].
static func dock_spot(c) -> Array:
	var w: WaterMap = c.world.water
	var front: Structure = c._front_fob()
	var H := MapDims.HALF
	var yaw := -PI * 0.5  # front (the jetty) to the east: the sea
	var best := []
	var bd := 1e9
	var zs := range(int(H * 0.12), int(H - 70.0), 12)
	for zi in zs:
		var z := float(zi) * (1.0 if c.team == 0 else -1.0)
		var p := TrenchNet.snap_pos(Vector3(w.coast_x(z) - 10.0, 0, z))
		var err: String = c.world.placement_error(c.team, "dock", p, yaw)
		if err != "":
			continue
		var d: float = absf(z - (front.position.z if front else z)) + c.rng.randf() * 10.0
		if d < bd:
			bd = d
			best = [p, yaw]
	return best


# --- production -----------------------------------------------------------------------------

## What to hold back from the barracks for the first boat out of an idle dock.
static func saving(c) -> int:
	for dk in c._my_structs("dock", true):
		if not dk.queue.is_empty():
			return 0
		for v in c.world.vehicles:
			if v.team == c.team and not v.gone and v.is_boat():
				return 0
		var k := _pick(c, true)
		if k == "":
			k = _pick(c, false)
		return int(Defs.VEHICLES[k].cost) if k != "" else 0
	return 0


## Queues boats at idle docks; returns the supply spent.
static func produce(c, sup: int, saving: int) -> int:
	var spent := 0
	for dk in c._my_structs("dock", true):
		if not dk.queue.is_empty():
			continue
		var n_arm := 0
		var n_tr := 0
		for v in c.world.vehicles:
			if v.team != c.team or v.gone or not v.is_boat():
				continue
			if armed(v):
				n_arm += 1
			if transport(v):
				n_tr += 1
		var want := ""
		if n_arm < 1 + int(c.world.time / 1000.0):
			want = _pick(c, true)
		if want == "" and n_tr < 1 and c.world.time > 520.0:
			want = _pick(c, false)
		if want != "" and sup - spent >= int(Defs.VEHICLES[want].cost) + saving:
			c._cmd({"t": "train", "building": dk.eid, "item": want})
			spent += int(Defs.VEHICLES[want].cost)
	return spent


## The best boat the side can build, armed (a gunboat) or a transport.
static func _pick(c, gun: bool) -> String:
	var best := ""
	var bs := -1.0
	for k in Defs.BUILDINGS.dock.produces[c.team]:
		if c.world.rules.tier_needed(c.team, k) != "":
			continue
		var d: Dictionary = Defs.VEHICLES[k]
		var is_armed := String(d.get("mg", "")) != ""
		if gun and not is_armed:
			continue
		if not gun and int(d.get("seats", 0)) == 0:
			continue
		var s := float(d.hp) if gun else float(d.get("seats", 0)) * 50.0 + (30.0 if is_armed else 0.0)
		if s > bs:
			bs = s
			best = k
	return best


# --- at sea ------------------------------------------------------------------------------------

static func tick(c, boats: Array) -> void:
	if c.world.time < float(c.get_meta("naval_t", 0.0)):
		return
	c.set_meta("naval_t", c.world.time + TICK)
	var roles: Dictionary = c.get_meta("boat_roles", {})
	# one boat that can carry men runs the raids (the unarmed one if there is
	# one); the rest are gunboats
	var ferry: Vehicle = null
	for v in boats:
		if not v.gone and transport(v) and (ferry == null or (armed(ferry) and not armed(v)) or (armed(ferry) == armed(v) and v.eid < ferry.eid)):
			ferry = v
	for v in boats:
		if v.gone:
			continue
		if v == ferry:
			_raid(c, v, roles)
		else:
			_patrol(c, v, roles)
	for id in roles.keys():
		if c.world.entity(int(id)) == null:
			roles.erase(id)
	c.set_meta("boat_roles", roles)


## A gunboat: after anything of theirs it can see near the water, else off
## the front on patrol.
static func _patrol(c, v: Vehicle, roles: Dictionary) -> void:
	var w: World = c.world
	var best: Entity = null
	var bd := 260.0
	for e in w.units_near(v.position, 260.0):
		if e.team == c.team or e.team < 0 or e.gone or not e.visible_to_team(c.team):
			continue
		if e is Soldier and e.life != Soldier.Life.ALIVE:
			continue
		if e is Vehicle and e.is_air():
			continue
		var wp: Vector3 = w.nav.nearest_boat(e.position, 45.0)
		if wp == Vector3.INF:
			continue  # inland: out of reach of its guns
		var d := Defs.flat(e.position - v.position).length()
		if d < bd:
			bd = d
			best = e
	var r: Dictionary = roles.get(v.eid, {})
	if best:
		var spot: Vector3 = w.nav.nearest_boat(best.position + Defs.flat(v.position - best.position).normalized() * 35.0, 45.0)
		if spot != Vector3.INF and (String(r.get("role", "")) != "hunt" or w.time - float(r.get("t", 0.0)) > 15.0):
			v.order_assault(spot)
			roles[v.eid] = {"role": "hunt", "t": w.time}
			w.stat("ai_boat_hunt")
		return
	if v.path_i < v.path.size() and w.time - float(r.get("t", 0.0)) < 50.0:
		return
	# patrol off the front: the stretch of water level with our front line
	var front: Structure = c._front_fob()
	var ed: Vector3 = c._enemy_dir()
	var z: float = (front.position.z if front else 0.0) + ed.z * c.rng.randf_range(30.0, 110.0)
	var cand := Vector3.INF
	if not w.water.coast.is_empty():
		cand = w.nav.nearest_boat(Vector3(w.water.coast_x(z) + c.rng.randf_range(25.0, 70.0), 0, z), 60.0)
	var path: PackedVector3Array = w.nav.find_boat_path(v.position, cand) if cand != Vector3.INF else PackedVector3Array()
	if path.is_empty() and not w.water.rivers.is_empty():
		# (it's on the river)
		var best_p := Vector3.INF
		for p in w.water.rivers[0].pts:
			if best_p == Vector3.INF or absf(p.z - z) < absf(best_p.z - z):
				best_p = p
		cand = w.nav.nearest_boat(best_p, 30.0)
	if cand != Vector3.INF:
		v.order_assault(cand)
		roles[v.eid] = {"role": "patrol", "t": w.time}


## A transport: load an idle squad at the shore, land it on the enemy's flank.
static func _raid(c, v: Vehicle, roles: Dictionary) -> void:
	var w: World = c.world
	var r: Dictionary = roles.get(v.eid, {"role": "idle", "t": 0.0})
	var phase := String(r.get("role", "idle"))
	match phase:
		"idle":
			if w.time < float(r.get("t", 0.0)):
				return
			# a squad doing nothing, near enough to the water to walk down to it
			var pick: Squad = null
			var pd := 300.0
			# a reserve squad: one doing nothing, out at an outpost, or - if
			# there are plenty - one of the squads garrisoning the FOBs
			var garrisons := 0
			for sq in w.squads.values():
				if sq.team == c.team and sq.owner == c.peer and String(c.roles.get(sq.sid, {}).get("role", "")) == "garrison":
					garrisons += 1
			var ok_roles := ["idle", "outpost", "garrison"] if garrisons >= 3 else ["idle", "outpost"]
			for sq in w.squads.values():
				if sq.team != c.team or sq.owner != c.peer or sq.plan != null or sq.drill != "" or not sq.kind in ["rifle_squad", "fighter_cell", "mech_team", "mech_cell", "at_team", "rpg_team", "mg_team", "pkm_team"]:
					continue  # (riflemen and the like: the engineers have building to do)
				if not String(c.roles.get(sq.sid, {}).get("role", "idle")) in ok_roles or sq.alive_members().size() < 3 or sq.alive_members().size() > v.seats() + 2:
					continue
				var wp: Vector3 = w.nav.nearest_boat(sq.centroid(), 200.0, w.nav.water_body(v.position))
				if wp == Vector3.INF:
					continue
				var d := Defs.flat(sq.centroid() - wp).length() + Defs.flat(wp - v.position).length() * 0.2
				if d < pd:
					pd = d
					pick = sq
			if pick == null:
				roles[v.eid] = {"role": "idle", "t": w.time + 30.0}
				return
			var pickup: Vector3 = w.nav.nearest_boat(pick.centroid(), 220.0, w.nav.water_body(v.position))
			if pickup == Vector3.INF or w.nav.find_boat_path(v.position, pickup).is_empty():
				roles[v.eid] = {"role": "idle", "t": w.time + 60.0}
				return
			c.roles[pick.sid] = {"role": "raid", "t": w.time}
			v.order_move(pickup)
			roles[v.eid] = {"role": "pickup", "t": w.time, "sq": pick.sid}
			w.stat("ai_raid_pickup")
		"pickup":
			var sq: Squad = w.squads.get(int(r.sq))
			if sq == null or sq.alive_members().is_empty():
				roles[v.eid] = {"role": "home", "t": w.time}
				return
			if v.path_i >= v.path.size() and absf(v.speed) < 0.8 and String(r.get("boarding", "")) == "":
				sq.order_board(v)
				r["boarding"] = "yes"
				roles[v.eid] = r
			var aboard := 0
			for s in v.passengers:
				if is_instance_valid(s) and not s.gone:
					aboard += 1
			var left := sq.alive_members().size()  # (still ashore: the ones aboard are hidden)
			if aboard > 0 and (left == 0 or w.time - float(r.t) > 110.0):
				_launch(c, v, roles, sq)
			elif w.time - float(r.t) > 170.0:
				c.roles[sq.sid] = {"role": "idle", "t": w.time}
				roles[v.eid] = {"role": "home", "t": w.time}
		"raid":
			if v.passengers.is_empty():
				# they're ashore: back to the dock for the next lot
				roles[v.eid] = {"role": "home", "t": w.time}
				w.stat("ai_raid_landed")
			elif v.path_i >= v.path.size() and absf(v.speed) < 0.5 and w.time - float(r.t) > 20.0:
				v.dismount()
		"home":
			var docks: Array = c._my_structs("dock", true)
			if not docks.is_empty():
				var dk: Structure = docks[0]
				var spot: Vector3 = w.nav.nearest_boat(dk.position + dk.front_dir() * (dk.size.z * 0.5 + 18.0), 40.0)
				if spot != Vector3.INF:
					v.order_move(spot)
			roles[v.eid] = {"role": "idle", "t": w.time + c.rng.randf_range(150.0, 260.0)}


## Away with them: to a beach near something worth hitting - what we're
## attacking, or an enemy FOB or village near the water - not right under
## his guns; the men go in on it once ashore.
static func _launch(c, v: Vehicle, roles: Dictionary, sq: Squad) -> void:
	var w: World = c.world
	var body: int = w.nav.water_body(v.position)
	var goals := []
	if c.attack_target and not c.attack_target.gone:
		goals.append(c.attack_target.position)
	for f in w.rules.fobs(1 - c.team):
		goals.append(f.position)
	for kp in w.key_points:
		goals.append(kp.pos)
	var front: Structure = c._front_fob()
	var best := Vector3.INF
	var tgt := Vector3.INF
	var bs := 1e9
	for g in goals:
		var land: Vector3 = w.nav.nearest_boat(g, 200.0, body)
		if land == Vector3.INF:
			continue
		var s := Defs.flat(land - g).length() + (Defs.flat(g - front.position).length() * 0.3 if front else 0.0)
		for e in w.units_near(land, 45.0):
			if e.team != c.team and e.team >= 0 and e.visible_to_team(c.team):
				s += 60.0  # not straight into them
		if s < bs and not w.nav.find_boat_path(v.position, land).is_empty():
			bs = s
			best = land
			tgt = g
	if best == Vector3.INF:
		# nowhere to go: put them back ashore
		v.dismount()
		c.roles[sq.sid] = {"role": "idle", "t": w.time}
		roles[v.eid] = {"role": "home", "t": w.time}
		return
	v.order_move(best)
	v.assault_dest = tgt  # (the men go in on it once ashore: see Vehicle.dismount)
	c.roles[sq.sid] = {"role": "attack", "t": w.time}
	roles[v.eid] = {"role": "raid", "t": w.time}
	w.stat("ai_raid_launch")
