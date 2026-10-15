class_name Rules
extends RefCounted
## Game rules on the server: supply network + trucks, unit cap, placement,
## FOB capture, prisoners and intel, fog of war and victory.

const VC := 16.0

var world: World
var depots: Array = [null, null]
var upgrades: Array = [{}, {}]
var fob_names_used: Array = [0, 0]
var fob_order := 0
var _t_vis := 0.0
var _t_sec := 0.0


func _init(w: World) -> void:
	world = w


var support_ready := [{}, {}]  # per side: kind -> world time it is available again (none in the opening)


func support_left(team: int, kind: String) -> float:
	return float((support_ready[team] as Dictionary).get(kind, 300.0)) - world.time
var _support_q: Array = []  # [time, kind, team, data]


func call_support(peer: int, team: int, kind: String, pos: Vector3, dir := Vector3.ZERO) -> bool:
	if not Defs.SUPPORT.has(kind) or int(Defs.SUPPORT[kind].team) != team:
		return false
	var d: Dictionary = Defs.SUPPORT[kind]
	var left := support_left(team, kind)
	if left > 0.0:
		notify(peer, team, "%s not ready yet (%ds)." % [d.name, int(left)])
		return false
	if not spend(team, pos, int(d.cost)):
		notify(peer, team, "Not enough supply for the %s (%d)." % [String(d.name).to_lower(), int(d.cost)])
		return false
	support_ready[team][kind] = world.time + float(d.cooldown)
	if dir.length() < 0.1:
		dir = Vector3(0, 0, -1) if team == 0 else Vector3(0, 0, 1)
	_launch(kind, team, pos, Defs.flat(dir).normalized())
	return true


## An observer setting off any support anywhere, for show (no side, no cost).
func demo_support(kind: String, pos: Vector3, dir: Vector3) -> void:
	if not Defs.SUPPORT.has(kind):
		return
	if dir.length() < 0.1:
		dir = Vector3(1, 0, 0)
	_launch(kind, -1, pos, Defs.flat(dir).normalized())


func _launch(kind: String, team: int, pos: Vector3, dir: Vector3) -> void:
	pos.y = 0.0
	world.fx_event([Fx.SUPPORT, pos, float(Defs.SUPPORT[kind].get("r", 14.0))])
	world.stat("support_" + kind)
	var gr := Defs.grid_ref(pos)
	var foe := 1 - team if team >= 0 else -1
	var sd: Dictionary = Defs.SUPPORT[kind]
	var mk := String(sd.get("model", ""))
	var air_name := String(sd.name).get_slice(" ", 0) + " " + String(sd.name).get_slice(" ", 1)
	var warn: bool = not sd.get("quiet", false)
	match String(sd.get("fly", kind)):
		"jet":
			var start := pos - dir * 330.0 + Vector3(0, 34.0, 0)
			world.spawn("projectile", {"ptype": "jet", "team": team, "pos": start, "vel": dir * 95.0, "target": pos, "fuse": float(sd.get("bombs", 4)), "thrower": 0, "mk": mk})
			_sup_msg(team, foe, "%s inbound on %s." % [air_name, gr], "Enemy jet inbound!" if warn else "", pos)
			return
		"a10":
			var st := pos + dir * Projectile.A10_START
			st.y = Projectile.a10_alt(Projectile.A10_START)
			world.spawn("projectile", {"ptype": "a10", "team": team, "pos": st, "vel": dir * Projectile.A10_SPEED, "target": pos, "fuse": 0.0, "thrower": 0, "mk": mk})
			_sup_msg(team, foe, "%s inbound, gun run on %s. Danger close!" % [air_name, gr], "Enemy jet, low! Get down!", pos)
			return
		"orbit":
			world.spawn("projectile", {"ptype": "ac130", "team": team, "pos": pos + Vector3(Projectile.AC_R, Projectile.AC_ALT, 0), "vel": Vector3.ZERO, "target": pos, "fuse": world.rng.randf() * TAU,
				"thrower": 0, "mk": mk, "guns": String(sd.get("guns", "ac130"))})
			_sup_msg(team, foe, "%s on station over %s. Thirty seconds of fire." % [air_name, gr], "Enemy aircraft overhead!", pos)
			return
	match kind:
		"artillery":
			var back := Vector3(0, 0, 1) if team == 0 else (Vector3(0, 0, -1) if team == 1 else -dir)
			for i in 8:
				_support_q.append([world.time + 2.0 + i * 0.7, "arty", team, pos, 22.0, back * 380.0])
			_sup_msg(team, foe, "Shot, over. 155 on %s, eight rounds." % gr, "Incoming artillery!", pos)
		"barrage":
			var back2 := Vector3(0, 0, -1) if team == 1 else (Vector3(0, 0, 1) if team == 0 else -dir)
			for i in 16:
				_support_q.append([world.time + 1.5 + i * 0.28, "grad", team, pos, 20.0, back2 * 300.0])
			_sup_msg(team, foe, "Rocket barrage on %s. Keep your heads down." % gr, "Incoming rockets!", pos)
		"mortars", "smoke":
			var back3 := (Vector3(0, 0, -1) if team == 1 else Vector3(0, 0, 1)) if team >= 0 else -dir
			var n := 12 if kind == "mortars" else 6
			for i in n:
				_support_q.append([world.time + 1.0 + i * 0.45, "mortar" if kind == "mortars" else "mortar_smoke", team, pos, 15.0 if kind == "mortars" else 10.0, back3 * 130.0])
			_sup_msg(team, foe, ("Mortars firing on %s." if kind == "mortars" else "Smoke going down on %s.") % gr, "Incoming mortars!", pos)


func _sup_msg(team: int, foe: int, mine: String, theirs: String, pos: Vector3) -> void:
	if team >= 0:
		world.send_msg(team, "info", mine, pos)
	else:
		world.send_msg(-1, "info", mine, pos)
	if foe >= 0 and theirs != "":
		world.send_msg(foe, "alert", theirs, pos)


func _support_tick() -> void:
	for i in range(_support_q.size() - 1, -1, -1):
		var q: Array = _support_q[i]
		if world.time < float(q[0]):
			continue
		_support_q.remove_at(i)
		var pt: String = q[1]
		var team: int = q[2]
		var pos: Vector3 = q[3]
		var rad: float = q[4]
		var back: Vector3 = q[5]
		var a := world.rng.randf() * TAU
		var r := sqrt(world.rng.randf()) * rad
		var tgt := pos + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var side := back.normalized().cross(Vector3.UP)
		var origin := pos + back + side * world.rng.randf_range(-40, 40)
		origin.y = 3.0
		var speed: float = float({"grad": 140.0, "arty": 110.0}.get(pt, 60.0))
		var T: float = (4.5 if pt != "arty" else 6.0) + Defs.flat(tgt - origin).length() / float(speed)
		world.spawn("projectile", {"ptype": pt, "team": team, "pos": origin, "origin": origin, "target": tgt, "T": T, "thrower": 0})
		if pt in ["mortar", "mortar_smoke", "arty"] and world.rng.randf() < 0.5:
			world.fx_event([Fx.FAR_SOUND, "mortar" if pt != "arty" else "cannon", -14.0, pos])


func tick(dt: float) -> void:
	if not _support_q.is_empty():
		_support_tick()
	_t_vis -= dt
	if _t_vis <= 0.0:
		_t_vis = 0.4
		_visibility()
	_t_sec -= dt
	if _t_sec <= 0.0:
		_t_sec = 1.0
		_reserves()
		_prisoners()
		_check_victory()
		_danger_maps()
	_trucks(dt)


func random_name(team: int) -> String:
	var names: Array = Defs.NAMES[clampi(team, 0, 1)]
	return names[world.rng.randi() % names.size()]


func next_fob_name(team: int) -> String:
	var names: Array = Defs.FOB_NAMES[team]
	var n: String = names[fob_names_used[team] % names.size()]
	fob_names_used[team] += 1
	return n


## The vehicle tier a side has unlocked: 1 to start with, then each tier
## research raises it.
func tier(team: int) -> int:
	var t := 1
	for k in Defs.UPGRADES:
		var u: Dictionary = Defs.UPGRADES[k]
		if u.has("tier") and has_upgrade(team, k):
			t = maxi(t, int(u.tier))
	return t


## "" if the side may build `item` now, else the name of the research it needs.
func tier_needed(team: int, item: String) -> String:
	if not Defs.VEHICLES.has(item):
		return ""
	var want := int(Defs.VEHICLES[item].get("tier", 1))
	if want <= tier(team):
		return ""
	for k in Defs.UPGRADES:
		var u: Dictionary = Defs.UPGRADES[k]
		if int(u.get("tier", 0)) == want and team in u.teams:
			return String(u.name)
	return "tier %d" % want


func has_upgrade(team: int, key: String) -> bool:
	return team >= 0 and team <= 1 and upgrades[team].has(key)


func apply_upgrade(team: int, key: String) -> void:
	upgrades[team][key] = true
	for s in world.soldiers:
		if s.team != team:
			continue
		if key == "armor":
			s.base_hp *= 1.2
			s.max_hp *= 1.2
			s.hp *= 1.2
		elif key == "grenades" and not s.is_bearer():
			s.frags += 1
	world.send_msg(team, "info", "Research complete: %s." % Defs.UPGRADES[key].name)


## Warnings go only to the human who caused them (AI commanders get none).
func notify(peer: int, _team: int, text: String) -> void:
	if peer > 0:
		world.send_msg_to(peer, "warn", text)


## Spending comes from a single FOB, so this is what you can actually afford.
func max_fob_supply(team: int) -> int:
	var m := 0
	for f in fobs(team, false):
		m = maxi(m, int(f.supply))
	return m


# --- economy ------------------------------------------------------------------------

func fobs(team: int, include_wrecked := true) -> Array:
	var out := []
	for st in world.structures:
		if st.skind == "fob" and st.team == team and st.built and (include_wrecked or not st.wrecked):
			out.append(st)
	return out


func nearest_fob(team: int, pos: Vector3) -> Structure:
	var best: Structure = null
	var bd := 1e9
	for f in fobs(team):
		var d: float = Defs.flat(f.position - pos).length() + (60.0 if f.wrecked else 0.0)
		if d < bd:
			bd = d
			best = f
	return best


func supply_total(team: int) -> int:
	var n := 0
	for f in fobs(team):
		n += int(f.supply)
	return n


func spend(team: int, pos: Vector3, amount: int) -> bool:
	var arr := []
	for f in fobs(team, false):
		arr.append([Defs.flat(f.position - pos).length(), f])
	arr.sort_custom(func(a, b): return a[0] < b[0])
	for it in arr:
		if it[1].supply >= amount:
			it[1].supply -= amount
			it[1].net_dirty = true
			return true
	return false


func refund(team: int, pos: Vector3, amount: int) -> void:
	var f := nearest_fob(team, pos)
	if f:
		f.supply += amount
		f.net_dirty = true


func cap(team: int) -> int:
	return Defs.BASE_CAP + Defs.CAP_PER_FOB * fobs(team, false).size()


func used(team: int) -> int:
	var n := 0
	for s in world.soldiers:
		if s.team != team or s.is_bearer():
			continue
		if s.life == Soldier.Life.ALIVE or s.life == Soldier.Life.DOWNED or (s.life == Soldier.Life.HIDDEN and s.hidden_reason in ["tent", "tunnel_wait", "tunnel_travel"]):
			n += 1
	for v in world.vehicles:
		if v.team == team:
			n += int(v.vdef.cap)
	return n


func has_cap(team: int, n: int) -> bool:
	return used(team) + n <= cap(team)


# --- placement ----------------------------------------------------------------------

func try_place(peer: int, team: int, kind: String, pos: Vector3, yaw: float, sqs: Array, assign := true, size := Vector3.ZERO) -> Structure:
	if not Defs.BUILDINGS.has(kind):
		return null
	var def: Dictionary = Defs.BUILDINGS[kind]
	if not team in def.teams:
		return null
	var bay := 0
	if kind in ["mg_nest", "hmg_nest"]:
		var spot := world.trench_mount_spot(pos, yaw)
		if not spot.is_empty():
			pos = spot.pos
			yaw = float(spot.yaw)
			bay = 1
	var err := world.placement_error(team, kind, pos, yaw)
	if err != "":
		notify(peer, team, err)
		return null
	if not spend(team, pos, int(def.cost)):
		notify(peer, team, "Not enough supply at a nearby FOB for %s (%d)." % [def.name, def.cost])
		return null
	var props := {"skind": kind, "team": team, "owner": peer, "pos": pos, "yaw": yaw, "built": false, "progress": 0.0}
	if size != Vector3.ZERO:
		props["size"] = size
	if kind == "fob":
		props["sname"] = next_fob_name(team)
	if bay == 1:
		props["variant"] = 1
	var st: Structure = world.spawn("structure", props)
	if not assign:
		return st
	var builders := sqs
	if builders.is_empty():
		var bd := 1e9
		for sq in world.squads.values():
			if sq.owner != peer or sq.order == "build":
				continue
			var eng := false
			for m in sq.members:
				if m.udef.get("engineer", false):
					eng = true
			if not eng:
				continue
			var d: float = Defs.flat(sq.centroid() - pos).length()
			if d < bd:
				bd = d
				builders = [sq]
	for sq in builders:
		sq.order_work(st)
	return st


## Best spot for a mortar to shell: clusters of spotted enemies (ideally dug
## in) and enemy emplacements, never too close to our own troops.
func mortar_target(team: int, from: Vector3, rmin: float, rmax: float) -> Vector3:
	var best := Vector3.INF
	var bs := 6.0
	for s in world.soldiers:
		if s.team == team or s.team < 0 or s.life != Soldier.Life.ALIVE or not s.visible_to_team(team):
			continue
		var d: float = Defs.flat(s.position - from).length()
		if d < rmin or d > rmax:
			continue
		var n := 0
		var danger := false
		for o in world.soldiers_near(s.position, 12.0):
			if o.life != Soldier.Life.ALIVE:
				continue
			if o.team == team:
				if Defs.flat(o.position - s.position).length() < 8.0:
					danger = true
					break
				continue
			if Defs.flat(o.position - s.position).length() < 6.0:
				n += 1
		if danger:
			continue
		var sc := n * 6.0 + (8.0 if s.mounted else 0.0) + (4.0 if s.at_cover else 0.0) - d * 0.02
		if sc > bs:
			bs = sc
			best = s.position
	for st in world.structures:
		if st.team == team or st.team < 0 or not st.built or not st.skind in ["mg_nest", "hmg_nest", "mortar_pit", "at_post", "bunker", "watchtower"]:
			continue
		if ((st.seen_mask >> team) & 1) == 0:
			continue
		var d2: float = Defs.flat(st.position - from).length()
		if d2 < rmin or d2 > rmax:
			continue
		var sc2 := 16.0 - d2 * 0.02
		if sc2 > bs:
			bs = sc2
			best = st.position
	return best


# --- buildings / network ------------------------------------------------------------

func on_built(st: Structure) -> void:
	match st.skind:
		"fob":
			fob_order += 1
			world.stat("fob_built")
			st.completed_order = fob_order
			rebuild_network(st.team)
			world.send_msg(st.team, "info", "FOB %s completed! Unit cap +%d and a supply road is being laid." % [st.sname, Defs.CAP_PER_FOB], st.position)
		"medic_tent":
			st.bearer_t = 0.0
			world.send_msg(st.team, "info", "Medic tent ready. Stretcher bearers are standing by.")
		"sandbags", "wire", "mines", "tank_trap", "trench", "concrete_wall":
			pass
		_:
			world.send_msg(st.team, "info", "%s completed." % st.display_name())


func on_fob_changed(team: int) -> void:
	rebuild_network(team)


func register_start_fob(f: Structure) -> void:
	fob_order += 1
	f.completed_order = fob_order


func rebuild_network(team: int) -> void:
	var depot: Structure = depots[team]
	if depot == null:
		return
	var list := fobs(team)
	list.sort_custom(func(a, b): return a.completed_order < b.completed_order)
	var nodes := [depot]
	var polys := []
	for f in list:
		var best: Structure = depot
		var bd := 1e9
		for n in nodes:
			var d: float = Defs.flat(n.position - f.position).length()
			if d < bd:
				bd = d
				best = n
		f.supply_parent = best
		var start := best.position + Defs.flat(f.position - best.position).normalized() * (best.radius * 0.6)
		var path := world.nav.find_path(start, f.position, true)
		var poly := PackedVector3Array()
		poly.append(world.nav.nearest_walkable(start, true))
		poly.append_array(path)
		f.road = poly
		_bulldoze(poly)
		polys.append(poly)
		nodes.append(f)
	world.set_roads(team, polys)


func _bulldoze(poly: PackedVector3Array) -> void:
	for i in range(poly.size() - 1):
		var a := poly[i]
		var b := poly[i + 1]
		for st in world.structures_near((a + b) * 0.5, a.distance_to(b) * 0.5 + 4.0):
			if st.team >= 0 or not st.smashable or st.gone:
				continue
			if Defs.dist_point_segment(Defs.flat(st.position), Defs.flat(a), Defs.flat(b)) < 2.6 + st.foot.length() * 0.5:
				world.despawn(st)


func route_to(f: Structure) -> PackedVector3Array:
	var chain := []
	var cur: Structure = f
	var guard := 0
	while cur and cur.skind == "fob" and guard < 24:
		chain.push_front(cur)
		cur = cur.supply_parent
		guard += 1
	var out := PackedVector3Array()
	if cur == null or cur.skind != "depot":
		return out
	for c in chain:
		out.append_array(c.road)
	return out


func _trucks(dt: float) -> void:
	for st in world.structures:
		if st.skind != "fob" or not st.built or st.team < 0:
			continue
		if st.truck and st.truck.gone:
			st.truck = null
		if st.truck:
			continue
		st.truck_t -= dt
		if st.truck_t > 0.0:
			continue
		var route := route_to(st)
		if route.size() < 2:
			st.truck_t = 8.0
			continue
		var v: Vehicle = world.spawn("vehicle", {"vkind": "truck", "team": st.team, "owner": -1 - st.team, "pos": route[0], "yaw": Defs.yaw_of(route[1] - route[0])})
		v.route = route
		v.route_i = 1
		v.dest_fob = st
		st.truck = v
		st.supply_status = "Truck en route"


func truck_arrived(v: Vehicle) -> void:
	var f := v.dest_fob
	if f and not f.gone and f.team == v.team:
		f.supply += Defs.SUPPLY_PER_TRUCK[v.team]
		world.stat("truck_delivered")
		f.net_dirty = true
		f.supply_status = "OK"
		world.fx_event([Fx.DELIVER, f.position + Vector3(0, 4, 0), Defs.SUPPLY_PER_TRUCK[v.team], v.team])


func truck_home(v: Vehicle) -> void:
	var f := v.dest_fob
	if f and not f.gone:
		f.truck = null
		f.truck_t = 4.0
	world.despawn(v)


func truck_lost(v: Vehicle) -> void:
	var f := v.dest_fob
	if f and not f.gone:
		f.truck = null
		f.truck_t = 28.0
		f.supply_status = "Truck destroyed"
		world.stat("truck_lost")
		world.send_msg(v.team, "alert", "Supply truck to FOB %s destroyed at %s! The road is being ambushed." % [f.sname, Defs.grid_ref(v.position)], v.position)


func truck_blocked(v: Vehicle) -> void:
	var f := v.dest_fob
	if f and not f.gone and f.supply_status != "Road blocked":
		f.supply_status = "Road blocked"
		world.send_msg(v.team, "alert", "Supply road to FOB %s is blocked at %s!" % [f.sname, Defs.grid_ref(v.position)], v.position)


func capture_fob(f: Structure, new_team: int) -> void:
	var old := f.team
	world.stat("fob_captured")
	f.team = new_team
	f.owner_peer = -1 - new_team
	f.supply_parent = null
	f.road = PackedVector3Array()
	f.truck = null
	f.truck_t = 6.0
	f.supply_status = "OK"
	f.queue.clear()
	f.net_dirty = true
	world.push_props(f, {"team": new_team, "owner": f.owner_peer})
	world.send_msg(new_team, "info", "We captured %s!" % f.display_name(), f.position)
	world.send_msg(old, "alert", "We lost %s!" % f.display_name(), f.position)
	rebuild_network(old)
	rebuild_network(new_team)
	_check_victory()


func _check_victory() -> void:
	if world.winner >= 0 or world.time < 10.0:
		return
	for t in 2:
		if fobs(t).is_empty():
			world.declare_winner(1 - t)
			return


# --- squads --------------------------------------------------------------------------

func spawn_squad(key: String, team: int, owner: int, pos: Vector3, dest := Vector3.INF) -> Squad:
	var def: Dictionary = Defs.SQUADS[key]
	var sq := world.new_squad(team, owner, key)
	var face := Vector3.FORWARD if team == 0 else Vector3.BACK
	if dest != Vector3.INF and Defs.flat(dest - pos).length() > 1.0:
		face = Defs.flat(dest - pos).normalized()
	var i := 0
	for ut in def.members:
		var off := Vector3((i % 3 - 1) * 1.4, 0, (i / 3) * 1.4)
		var p := world.nav.nearest_walkable(pos + off)
		var s: Soldier = world.spawn("soldier", {"utype": ut, "team": team, "owner": owner, "pos": p, "yaw": Defs.yaw_of(face), "squad": sq.sid, "name": random_name(team)})
		sq.add(s)
		i += 1
	sq.order_pos = pos
	sq.facing = face
	if dest != Vector3.INF:
		sq.order_move(dest, face, 0)
	return sq


func rejoin_squad(s: Soldier) -> void:
	var owner := s.owner_peer
	if owner > 0 and not Net.players.has(owner):
		owner = -1 - s.team
		s.owner_peer = owner
		world.push_props(s, {"owner": owner})
	var best: Squad = null
	var bd := 90.0
	for sq in world.squads.values():
		if sq.owner != owner or sq.team != s.team or sq.members.size() >= 6:
			continue
		var d: float = Defs.flat(sq.centroid() - s.position).length()
		if d < bd:
			bd = d
			best = sq
	if best == null:
		best = world.new_squad(s.team, owner, "rifle_squad" if s.team == 0 else "fighter_cell")
		best.order_pos = s.position
	best.add(s)
	s.hold_pos = best.order_pos if Defs.flat(best.order_pos - s.position).length() < 40.0 else s.position
	s.at_cover = false
	s.next_cover_eval = 0.0
	if Defs.flat(s.hold_pos - s.position).length() > 3.0:
		s.go_to(s.hold_pos, "slot", 0)


func find_casualty(team: int, pos: Vector3, r: float) -> Soldier:
	var best: Soldier = null
	var bd := r
	for s in world.soldiers:
		if s.team != team or s.is_bearer() or s.stretcher_claimed or not s.carried_by.is_empty() or s.dragged_by:
			continue
		var d: float = Defs.flat(s.position - pos).length()
		if s.life == Soldier.Life.DOWNED and world.time - s.downed_t > 6.0 and s.rescue_claimed == null:
			d -= 30.0
		elif s.life == Soldier.Life.DEAD and world.time - s.dead_t < 240.0:
			pass
		else:
			continue
		if d < bd:
			bd = d
			best = s
	return best


func fpv_target(team: int, pos: Vector3, r: float) -> Entity:
	var best: Entity = null
	var bs := -1e9
	for v in world.vehicles:
		if v.team == team or v.team < 0 or not (v.visible_to_team(team) or Defs.flat(v.position - pos).length() < 150.0):
			continue
		var d: float = Defs.flat(v.position - pos).length()
		if d > r:
			continue
		var sc := 120.0 - d * 0.2 + (40.0 if v.vdef.armor >= 2 else 0.0)
		if sc > bs:
			bs = sc
			best = v
	for s in world.soldiers:
		if s.team == team or s.team < 0 or s.life != Soldier.Life.ALIVE or s.is_bearer() or not (s.visible_to_team(team) or Defs.flat(s.position - pos).length() < 150.0):
			continue
		var d: float = Defs.flat(s.position - pos).length()
		if d > r or d < 25.0:
			continue
		var n := 0
		for o in world.soldiers_near(s.position, 5.0):
			if o.team == s.team and o.life == Soldier.Life.ALIVE:
				n += 1
		var sc2 := n * 12.0 - d * 0.15 + (25.0 if s.mounted else 0.0)
		if n < 2 and not s.mounted:
			continue
		if sc2 > bs:
			bs = sc2
			best = s
	return best


# --- tunnels -------------------------------------------------------------------------

func tunnel_exit(st: Structure, ex: Structure, peer: int) -> void:
	if st.skind != "tunnel" or ex.skind != "tunnel" or not ex.built or ex.team != st.team:
		return
	var dist := Defs.flat(ex.position - st.position).length()
	var tt := 1.0 if st == ex else 3.0 + dist / (28.0 if has_upgrade(st.team, "deep_tunnels") else 14.0)
	var moved := 0
	for s in st.inside.duplicate():
		if s.gone or s.owner_peer != peer:
			continue
		s.hidden_reason = "tunnel_travel"
		s.hidden_t = tt + world.rng.randf() * 1.5
		s.task_pos = ex.position + Vector3(world.rng.randf_range(-3, 3), 0, world.rng.randf_range(-3, 3))
		if s.squad:
			s.squad.order_pos = ex.position
		moved += 1
	if moved > 0:
		world.send_msg(st.team, "info", "%d soldiers moving through the tunnels to %s." % [moved, Defs.grid_ref(ex.position)])


# --- prisoners & intel -----------------------------------------------------------------

var _reserve_t := [0.0, 0.0]


## HQ reserves: a side that is down to its last few soldiers gets a free squad
## from HQ now and then, so one lost clash doesn't end the battle on the spot.
func _reserves() -> void:
	if String(world.settings.get("scenario", "")) != "" or world.time < 120.0:
		return
	for t in 2:
		if world.time < float(_reserve_t[t]) or depots[t] == null or depots[t].gone:
			continue
		var alive := 0
		for sl in world.soldiers:
			if sl.team == t and sl.life == Soldier.Life.ALIVE:
				alive += 1
		if alive >= 6:
			continue
		_reserve_t[t] = world.time + 75.0
		var owner := -1 - t
		var pl: Dictionary = world.settings.get("players", {})
		for id in pl:
			if int(pl[id].team) == t:
				owner = int(id)
				break
		var hq: Structure = depots[t]
		var fwd := Vector3.FORWARD if t == 0 else Vector3.BACK
		spawn_squad("rifle_squad" if t == 0 else "fighter_cell", t, owner, hq.position + fwd * 14.0, hq.position + fwd * 22.0)
		world.send_msg(t, "info", "Reserves have arrived at HQ.", hq.position)


func _prisoners() -> void:
	for s in world.soldiers:
		if s.gone:
			continue
		match s.life:
			Soldier.Life.SURRENDER:
				if not _captor_ok(s):
					s.captor = null
					if _friend_near(s, 6.0):
						_free(s)
						continue
					var c := _find_captor(s)
					if c:
						s.captor = c
						c.start_captor(s)
			Soldier.Life.CAPTIVE:
				if not _captor_ok(s):
					s.captor = null
					s.life = Soldier.Life.SURRENDER
					s.stop_moving()
				elif s.intel_left > 0 and world.time > s.intel_t:
					s.intel_left -= 1
					s.intel_t = world.time + 10.0
					_give_intel(s, "march")
			Soldier.Life.HIDDEN:
				if (s.hidden_reason == "interrogation" or s.hidden_reason == "held") and s.intel_left > 0 and world.time > s.intel_t:
					s.intel_left -= 1
					s.intel_t = world.time + 7.0
					_give_intel(s, s.hidden_reason)


func _captor_ok(s: Soldier) -> bool:
	var c := s.captor
	return c != null and not c.gone and c.life == Soldier.Life.ALIVE and c.task == "captor" and c.task_ent == s


func _friend_near(s: Soldier, r: float) -> bool:
	for o in world.soldiers_near(s.position, r):
		if o != s and o.team == s.team and o.life == Soldier.Life.ALIVE and not o.is_bearer():
			return true
	return false


func _find_captor(s: Soldier) -> Soldier:
	var best: Soldier = null
	var bd := 35.0
	for o in world.soldiers_near(s.position, 35.0):
		if o.team == s.team or o.team < 0 or o.life != Soldier.Life.ALIVE or o.task != "" or o.is_bearer() or o.wdef.is_empty():
			continue
		var d: float = Defs.flat(o.position - s.position).length()
		if d < bd:
			bd = d
			best = o
	return best


func _free(s: Soldier) -> void:
	s.life = Soldier.Life.ALIVE
	s.act = Soldier.Act.IDLE
	s.wdef = Defs.WEAPONS.get(s.udef.weapon, {})
	if not s.wdef.is_empty():
		s.mag = int(s.wdef.mag)
		s.reserve = int(s.wdef.mag)
	s.say("Thanks! Get me out of here!", true)
	world.stat("prisoner_freed")
	world.send_msg(s.team, "info", "%s has been freed!" % s.sname, s.position)
	rejoin_squad(s)


func _prison_dest(team: int, pos: Vector3) -> Structure:
	var best: Structure = null
	var bd := 1e9
	for st in world.structures:
		if st.team != team or not st.built:
			continue
		var ok: bool = st.skind == "fob" or (team == Defs.REBELS and st.skind == "tunnel")
		if not ok:
			continue
		var d: float = Defs.flat(st.position - pos).length() - (40.0 if st.skind == "tunnel" else 0.0)
		if d < bd:
			bd = d
			best = st
	if best == null:
		best = depots[team]
	return best


func take_prisoner(p: Soldier, c: Soldier) -> void:
	p.life = Soldier.Life.CAPTIVE
	world.stat("prisoner_taken")
	p.captor = c
	var dest := _prison_dest(c.team, p.position)
	p.prison_dest = dest
	p.go_to(dest.position, "prison", 0)
	if c.team == Defs.ARMY:
		p.intel_left = 3
		p.intel_t = world.time + 6.0
	world.send_msg(c.team, "info", "%s took a prisoner. Escorting him to %s." % [c.sname, dest.display_name()], p.position)


func prisoner_arrived(p: Soldier) -> void:
	var c := p.captor
	p.captor = null
	if c and not c.gone and c.task == "captor":
		c._return_to_hold()
	var dest := p.prison_dest
	if dest and dest.skind == "tunnel":
		p.intel_left = 4
		p.intel_t = world.time + 4.0
		p.hide_in("interrogation", 34.0, dest)
		world.send_msg(dest.team, "intel", "Prisoner %s has been taken into the tunnels for interrogation." % p.sname)
	else:
		p.hide_in("held", 8.0 + p.intel_left * 10.0, dest)
	world.send_msg(p.team, "alert", "%s has been taken prisoner by the enemy." % p.sname)


func prisoner_done(p: Soldier) -> void:
	world.despawn(p)


func _give_intel(p: Soldier, mode: String) -> void:
	var about := p.team
	var to_team := 1 - p.team
	var facts := []
	var fl := fobs(about)
	for f in fl:
		var n := 0
		for s in world.soldiers_near(f.position, 25.0):
			if s.team == about and s.life == Soldier.Life.ALIVE:
				n += 1
		facts.append(["fob%d" % f.eid, "%s at %s has %d supply and %d men guarding it." % [f.display_name(), Defs.grid_ref(f.position), int(f.supply), n], f.position])
	for st in world.structures:
		if st.team != about or not st.built:
			continue
		var f := nearest_fob(about, st.position)
		var where := ("%s of %s" % [Defs.compass(f.position, st.position), f.display_name()]) if f and Defs.flat(f.position - st.position).length() < 80.0 else ("at " + Defs.grid_ref(st.position))
		match st.skind:
			"mg_nest":
				facts.append(["mg%d" % st.eid, "There's an MG nest %s." % where, st.position])
			"hmg_nest":
				facts.append(["hm%d" % st.eid, "There's a .50 cal %s. Don't go near it." % where, st.position])
			"mortar_pit":
				facts.append(["mp%d" % st.eid, "Our mortars are dug in %s." % where, st.position])
			"bunker":
				facts.append(["bk%d" % st.eid, "There's a bunker %s." % where, st.position])
			"at_post":
				facts.append(["at%d" % st.eid, "An anti-tank post covers the approach %s." % where, st.position])
			"trench":
				facts.append(["tr%d" % st.eid, "The trenches are %s." % where, st.position])
			"watchtower":
				facts.append(["wt%d" % st.eid, "We have a watchtower %s." % where, st.position])
			"mines":
				facts.append(["mn%d" % st.eid, "There are mines at %s. Watch your step." % Defs.grid_ref(st.position), st.position])
			"tunnel":
				facts.append(["tn%d" % st.eid, "One of the tunnel entrances is at %s." % Defs.grid_ref(st.position), st.position])
			"barracks", "factory":
				if not st.queue.is_empty():
					facts.append(["pq%d_%s" % [st.eid, st.queue[0].item], "They're making %s at the %s %s." % [Defs.item_name(String(st.queue[0].item)), st.display_name().to_lower(), where], st.position])
			"medic_tent":
				facts.append(["mt%d" % st.eid, "Our medic tent is %s." % where, st.position])
	for f in fl:
		if f.truck and not f.truck.gone:
			facts.append(["tr%d" % f.truck.eid, "A supply truck is driving to %s right now. It's at %s." % [f.display_name(), Defs.grid_ref(f.truck.position)], f.truck.position])
	var men := 0
	var veh := 0
	for s in world.soldiers:
		if s.team == about and s.life == Soldier.Life.ALIVE and not s.is_bearer():
			men += 1
	for v in world.vehicles:
		if v.team == about and v.vkind != "truck":
			veh += 1
	facts.append(["army", "We've only got about %d men and %d vehicles left." % [men, veh], null])
	for c in world.commanders:
		if c.team == about and c.attack_target and not c.attack_target.gone:
			facts.append(["plan%d" % c.attack_target.eid, "They're planning to hit %s." % c.attack_target.display_name(), c.attack_target.position])
	var given: Array = p.get_meta("given", [])
	var pool := []
	for fct in facts:
		if not fct[0] in given:
			pool.append(fct)
	if pool.is_empty():
		pool = facts
	var pick: Array = pool[world.rng.randi() % pool.size()]
	world.stat("intel")
	given.append(pick[0])
	p.set_meta("given", given)
	var openers := ["Okay, okay! ", "Please... ", "I'll talk! ", "Fine. ", "Don't hurt me! ", ""]
	var tag := "Interrogation" if mode == "interrogation" else "Prisoner"
	world.send_msg(to_team, "intel", "[%s] %s: \"%s%s\"" % [tag, p.sname, openers[world.rng.randi() % openers.size()], pick[1]], pick[2])


# --- danger maps (tactical pathing) -------------------------------------------------------

## For each side, how hard every 16 m cluster is covered by enemies it can see.
## Careful moves (and every retreat) route around the hot clusters.
func _danger_maps() -> void:
	var nav: Nav = world.nav
	if nav == null or nav.hnav_i == null:
		return
	for t in 2:
		var dm := PackedFloat32Array()
		dm.resize(HNav.NC * HNav.NC)
		for s in world.soldiers:
			if s.team == t or s.team < 0 or s.life != Soldier.Life.ALIVE or not s.visible_to_team(t):
				continue
			var w := 2.0 if s.utype in ["mg_gunner", "pkm"] else 1.0
			_threat(dm, s.position, 42.0, w)
		for v in world.vehicles:
			if v.team == t or v.team < 0 or v.is_auto() or not v.visible_to_team(t):
				continue
			_threat(dm, v.position, 60.0, 3.0 if v.vdef.get("cannon", false) else 2.0)
		for st in world.structures:
			if st.team == t or st.team < 0 or not st.built or not ((st.seen_mask >> t) & 1):
				continue
			if st.skind in ["mg_nest", "hmg_nest", "bunker", "at_post"]:
				_threat(dm, st.position, 55.0, 3.0)
		for i in dm.size():
			dm[i] = minf(dm[i], 4.0)
		nav.hnav_i.set_danger(t, dm)
		nav.hnav_v.set_danger(t, dm)


func _threat(dm: PackedFloat32Array, p: Vector3, r: float, w: float) -> void:
	var cs := float(HNav.C)
	var hh := MapDims.HALF
	var x0 := clampi(floori((p.x + hh - r) / cs), 0, HNav.NC - 1)
	var x1 := clampi(floori((p.x + hh + r) / cs), 0, HNav.NC - 1)
	var z0 := clampi(floori((p.z + hh - r) / cs), 0, HNav.NC - 1)
	var z1 := clampi(floori((p.z + hh + r) / cs), 0, HNav.NC - 1)
	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			var c := Vector3(cx * cs - hh + cs * 0.5, 0, cz * cs - hh + cs * 0.5)
			var d := Defs.flat(c - p).length()
			if d < r:
				dm[cz * HNav.NC + cx] += w * (1.0 - 0.5 * d / r)


# --- fog of war ------------------------------------------------------------------------

func _visibility() -> void:
	var cells := [{}, {}]
	for s in world.soldiers:
		if s.team < 0 or s.team > 1:
			continue
		if s.life == Soldier.Life.ALIVE:
			_add_obs(cells[s.team], s.position, s.sight_range())
		elif s.life == Soldier.Life.DOWNED:
			_add_obs(cells[s.team], s.position, 22.0)
	for v in world.vehicles:
		if v.team >= 0 and v.team <= 1:
			_add_obs(cells[v.team], v.position, float(v.vdef.get("sight", 50.0)))
	for st in world.structures:
		if st.team < 0 or st.team > 1 or not st.built:
			continue
		var r := 30.0
		match st.skind:
			"fob", "depot":
				r = 50.0
			"watchtower":
				r = 80.0
			"mines", "wire", "tank_trap", "sandbags", "trench":
				continue
		_add_obs(cells[st.team], st.position, r)
	for d in world.drones:
		if d.team >= 0 and d.team <= 1:
			_add_obs(cells[d.team], d.position, 40.0)
	for s in world.soldiers:
		_vis_ent(s, cells)
	for v in world.vehicles:
		_vis_ent(v, cells)
	for d in world.drones:
		_vis_ent(d, cells)
	for st in world.structures:
		if st.team >= 0:
			_vis_ent(st, cells)


func _add_obs(cells: Dictionary, p: Vector3, r: float) -> void:
	var o := [p, r * r]
	for x in range(floori((p.x - r) / VC), floori((p.x + r) / VC) + 1):
		for z in range(floori((p.z - r) / VC), floori((p.z + r) / VC) + 1):
			var k := Vector2i(x, z)
			var a = cells.get(k)
			if a == null:
				a = []
				cells[k] = a
			a.append(o)


func _vis_ent(e: Entity, cells: Array) -> void:
	var m := 0
	var k := Vector2i(floori(e.position.x / VC), floori(e.position.z / VC))
	for t in 2:
		if e.team == t:
			m |= 1 << t
			continue
		var obs = cells[t].get(k)
		if obs == null:
			continue
		for o in obs:
			if Defs.flat(o[0] - e.position).length_squared() <= o[1]:
				m |= 1 << t
				break
	if e is Structure and e.skind == "mines":
		m = 1 << e.team
	elif e is Soldier and e.life == Soldier.Life.HIDDEN and e.team >= 0:
		m = 1 << e.team
	if m != e.vis_mask:
		e.vis_mask = m
		e.net_dirty = true
	if e is Structure:
		var sm: int = e.seen_mask | m
		if sm != e.seen_mask:
			e.seen_mask = sm
			e.net_dirty = true


# --- HUD summary -------------------------------------------------------------------------

func team_summary() -> Array:
	var out := []
	for t in 2:
		var fl := []
		var sup := 0
		for f in fobs(t):
			var status: String = "Wrecked" if f.wrecked else f.supply_status
			fl.append([f.eid, f.sname, int(f.supply), status])
			sup += int(f.supply)
		# every squad's current orders, for the map graphics: sid -> [order, where, facing, order number]
		var sq := {}
		for s in world.squads.values():
			if s.team != t or s.alive_members().is_empty():
				continue
			var pl = null
			if s.plan != null:
				var role := "assault"
				for e in s.plan.support:
					if e.sq == s and int(e.team) < 0:
						role = "support"
				pl = s.plan.info() + [role]
			var shown: String = s.shown_order if s.shown_order != "" else ("defend" if not s.then_defend.is_empty() and s.order == "move" else ("bound" if s.technique == "bound" else s.order))
			sq[s.sid] = [shown, s.order_pos, s.facing, s.order_n, pl, int(maxf(s.morale, 0.0)), s.drill]
		# intelligence: every enemy the team knows about, freshest report each
		var intel := {}
		for s in world.squads.values():
			if s.team != t:
				continue
			for id in s.known:
				var k: Dictionary = s.known[id]
				var e = k.e
				if e == null or e.gone or (e is Soldier and e.life != Soldier.Life.ALIVE):
					continue
				var age: float = world.time - float(k.t)
				if age > 90.0 or (intel.has(id) and float(intel[id][2]) <= age):
					continue
				var kind := "inf"
				if e is Vehicle:
					kind = String(MapSymbols.vehicle_symbol(e.vkind)[0])
				elif e is Structure:
					kind = "post"
				intel[id] = [k.pos, kind, age]
		var il := intel.values()
		if il.size() > 80:
			il = il.slice(0, 80)
		out.append({"supply": sup, "units": used(t), "cap": cap(t), "fobs": fl, "up": upgrades[t].keys(), "sup": (support_ready[t] as Dictionary).duplicate(), "sq": sq, "intel": il})
	return out
