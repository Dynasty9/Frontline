class_name CommanderAI
extends RefCounted
## Computer opponent. It plays through the same command interface as a human
## player: placing buildings that engineers must build, training squads,
## expanding with new FOBs, defending and attacking FOBs, ambushing trucks.

var world: World
var team := 0
var peer := -1
var rng := RandomNumberGenerator.new()
var think_t := 4.0
var attack_target: Structure = null
var roles := {}  # sid -> {"role": String, "t": float}
var last_wave_t := 0.0
var expand_t := 150.0
var ambush_t := 160.0
var defense_t := 0.0
var obstacle_t := 240.0
var next_vehicle := ""
var _back_t := 0.0


func _init(w: World, t: int) -> void:
	world = w
	team = t
	peer = -1 - t
	rng.seed = int(w.settings.get("seed", 1)) + 101 * (t + 1)
	think_t = 3.0 + t


func tick(dt: float) -> void:
	think_t -= dt
	if think_t > 0.0:
		return
	think_t = 2.0
	if world.winner >= 0:
		return
	var sqs := _my_squads()
	_support()
	_economy(sqs)
	_production(sqs)
	_military(sqs)


## Calls in the side's off-map support on the densest group of spotted
## enemies, never danger-close to our own troops.
func _support() -> void:
	var kind := _support_kind()
	if kind == "":
		return
	var best := Vector3.INF
	var bs := 0.0
	for e in world.soldiers:
		if e.team == team or e.team < 0 or e.life != Soldier.Life.ALIVE or not e.visible_to_team(team):
			continue
		var n := 0.0
		var close := false
		for o in world.soldiers_near(e.position, 24.0):
			if o.team == team and o.life == Soldier.Life.ALIVE:
				close = true
				break
			if o.team >= 0 and o.team != team and o.life == Soldier.Life.ALIVE and Defs.flat(o.position - e.position).length() < 14.0:
				n += 1.0
		if close:
			continue
		for v in world.vehicles_near(e.position, 14.0):
			if v.team != team and v.team >= 0:
				n += 2.5
		for st in world.structures_near(e.position, 12.0):
			if st.team >= 0 and st.team != team and st.skind in ["hmg_nest", "mg_nest", "mortar_pit", "at_post", "bunker"]:
				n += 1.5
		if n > bs:
			bs = n
			best = e.position
	if bs >= 4.0:
		var hq: Structure = world.rules.depots[team]
		var dir := Defs.flat(best - hq.position).normalized() if hq and not hq.gone else Vector3.ZERO
		_cmd({"t": "support", "kind": kind, "pos": best, "dir": dir})


## Any off-map support that is ready and affordable ("" if none).
func _support_kind() -> String:
	var opts := Defs.supports_for(team)
	opts.shuffle()
	for k in opts:
		if world.rules.support_left(team, k) <= 0.0 and world.rules.supply_total(team) >= int(Defs.SUPPORT[k].cost) + 40:
			return k
	return ""


var _helped := {}  # plan -> when we last answered its call for help


## A planned attack that has gone firm against a stronger enemy calls for
## help, and the company answers: fire onto the position (if our own men are
## clear of it), and the nearest uncommitted squads go and join the attack.
func _reinforce(fighters: Array) -> void:
	var t := world.time
	var plans := []
	for sq in fighters:
		if sq.plan != null and not sq.plan.done and sq.plan.phase == "fix" and not sq.plan in plans:
			plans.append(sq.plan)
	for p in plans:
		var key: int = p.get_instance_id()
		if t < float(_helped.get(key, -1e9)) + 40.0:
			continue
		_helped[key] = t
		var tgt: Vector3 = p.fire_at
		var clear := true
		for o in world.soldiers_near(tgt, 22.0):
			if o.team == team and o.life == Soldier.Life.ALIVE:
				clear = false
				break
		if clear:
			var kind := _support_kind()
			if kind != "":
				_cmd({"t": "support", "kind": kind, "pos": tgt, "dir": p.axis})
		var sent := []
		for sq in _by_distance(fighters, p.objective):
			if sent.size() >= 2 or Defs.flat(sq.centroid() - p.objective).length() > 220.0:
				break
			if sq.plan != null or not roles.get(sq.sid, {}).get("role", "idle") in ["idle", "attack"]:
				continue
			roles[sq.sid] = {"role": "attack", "t": t}
			p.join(sq)
			sent.append(sq.sid)
		if not sent.is_empty():
			_radio({"t": "assault", "squads": sent, "pos": p.objective})
	if _helped.size() > 32:
		_helped.clear()


var _radio_t := 0.0


var _outpost_t := 0.0


## Spare squads go forward to hold the villages, the town and the woods
## between our front and theirs, lying in wait - so the fighting is over the
## ground in between, not a march on the enemy's base.
func _outposts(fighters: Array) -> void:
	var t := world.time
	if t < _outpost_t or world.key_points.is_empty():
		return
	_outpost_t = t + 15.0
	var front := _front_fob()
	if front == null:
		return
	var ed := _enemy_dir()
	var held := []
	var idle := 0
	for sq in fighters:
		var r: Dictionary = roles.get(sq.sid, {})
		var role := String(r.get("role", "idle"))
		if role == "outpost":
			# relieved when it's been there a while, or it's been knocked about
			if t - float(r.t) > 300.0 or sq.alive_members().size() * 2 < sq.members.size() or sq.drill in ["rout", "withdraw"]:
				roles[sq.sid] = {"role": "idle", "t": t}
			else:
				held.append(r.pos)
		elif role == "idle" and sq.plan == null:
			idle += 1
	var wave := 3 if t < 600.0 else 4
	var want := clampi(idle - wave, 0, 1 + world.rules.fobs(team).size() / 2)
	if held.is_empty() and idle >= 2 and t > 90.0:
		want = maxi(want, 1)
	if held.size() >= want:
		return
	var best: Dictionary = {}
	var bs := -1e9
	for kp in world.key_points:
		var p: Vector3 = kp.pos
		var ahead := Defs.flat(p - front.position).dot(ed)
		if ahead < 25.0 or ahead > 190.0:
			continue
		var taken := false
		for h in held:
			if Defs.flat(h - p).length() < 40.0:
				taken = true
		for f in world.rules.fobs(1 - team):
			if Defs.flat(f.position - p).length() < 90.0:
				taken = true  # right under their base
		if taken:
			continue
		var side := absf(Defs.flat(p - front.position).dot(ed.cross(Vector3.UP)))
		var s := -ahead * 0.5 - side * 0.3 + float({"town": 40.0, "village": 30.0, "woods": 10.0}.get(kp.kind, 0.0))
		if s > bs:
			bs = s
			best = kp
	if best.is_empty():
		return
	for sq in _by_distance(fighters, best.pos):
		var role2 := String(roles.get(sq.sid, {}).get("role", "idle"))
		if role2 != "idle" or sq.plan != null or sq.drill != "" or sq.alive_members().size() < 2:
			continue
		roles[sq.sid] = {"role": "outpost", "t": t, "pos": best.pos}
		_cmd({"t": "defend", "squads": [sq.sid], "pos": world.nav.nearest_walkable(best.pos), "face": ed})
		world.stat("ai_outpost_%s" % best.kind)
		break


func _cmd(d: Dictionary) -> void:
	world.execute_cmd(peer, d)
	_radio(d)


## The order as it goes out over the command net to the squad leaders.
func _radio(d: Dictionary) -> void:
	var t: String = d.get("t", "")
	var verb: String = {"move": "move to", "assault": "assault", "defend": "dig in at", "retreat": "fall back", "support": "", "attack": "engage"}.get(t, "")
	if verb == "" or world.time < _radio_t:
		return
	var names := []
	for id in d.get("squads", []):
		names.append(Squad.callsign_of(team, int(id)))
	if not d.get("vehicles", []).is_empty():
		names.append("armour" if team == 0 else "the trucks")
	if names.is_empty():
		return
	_radio_t = world.time + 5.0
	var hq := "Six" if team == 0 else "Command"
	var where := (" " + Defs.grid_ref(d.pos)) if d.has("pos") and t != "retreat" else ""
	world.send_msg(team, "radio", "%s: %s, %s%s." % [hq, ", ".join(names), verb, where])


func _my_squads() -> Array:
	var out := []
	for sq in world.squads.values():
		if sq.owner == peer and sq.team == team:
			out.append(sq)
	return out


func _my_structs(kind := "", built_only := false) -> Array:
	var out := []
	for st in world.structures:
		if st.team != team:
			continue
		if kind != "" and st.skind != kind:
			continue
		if built_only and not st.built:
			continue
		out.append(st)
	return out


func _is_engineer_squad(sq: Squad) -> bool:
	for m in sq.members:
		if m.udef.get("engineer", false) and m.life == Soldier.Life.ALIVE:
			return true
	return false


## What's held back for the next FOB while one is due (more bases mean more
## supply trucks: whoever expands first pulls ahead).
func _fob_reserve() -> int:
	return 260 if _expansion_due() else 0


## Time for another FOB: one more every five minutes or so, up to what the
## map has room for.
func _expansion_due() -> bool:
	var n: int = world.rules.fobs(team).size()
	return world.time > expand_t and n < 3 + int(MapDims.HALF / 128.0) and n < 2 + int(world.time / 360.0)


func _enemy_dir() -> Vector3:
	return Vector3.FORWARD if team == 0 else Vector3.BACK


func _front_fob() -> Structure:
	var best: Structure = null
	var bz := -1e9
	for f in world.rules.fobs(team):
		var z: float = -f.position.z if team == 0 else f.position.z
		if z > bz:
			bz = z
			best = f
	return best


# --- economy ----------------------------------------------------------------------

func _economy(sqs: Array) -> void:
	var r := world.rules
	var fobs: Array = r.fobs(team)
	if fobs.is_empty():
		return
	var engs := []
	for sq in sqs:
		if _is_engineer_squad(sq):
			engs.append(sq)
	# keep unfinished sites and damaged buildings staffed
	var unfinished := []
	for st in _my_structs():
		if st.needs_work() and st.skind != "depot":
			unfinished.append(st)
	for st in unfinished:
		var staffed := false
		for sq in engs:
			if sq.build_target == st:
				staffed = true
		if staffed:
			continue
		var best: Squad = null
		var bd := 1e9
		for sq in engs:
			if sq.build_target != null and not sq.build_target.gone and sq.build_target.needs_work():
				continue
			var d: float = Defs.flat(sq.centroid() - st.position).length()
			if d < bd:
				bd = d
				best = sq
		if best:
			_cmd({"t": "work", "squads": [best.sid], "target": st.eid})
	if engs.is_empty() or unfinished.size() >= 2:
		return
	var sup: int = r.supply_total(team)  # (spending draws on every FOB: see Rules.spend)
	var main: Structure = fobs[0]
	var front := _front_fob()
	var t := world.time
	var plan := []
	if _my_structs("barracks").is_empty():
		plan.append(["barracks", main, 12.0, 30.0])
	elif _my_structs("medic_tent").is_empty() and t > 70.0:
		plan.append(["medic_tent", main, 10.0, 28.0])
	elif _my_structs("factory").is_empty() and (t > 220.0 or sup > 500):
		plan.append(["factory", main, 14.0, 36.0])
	elif team == Defs.REBELS and _count_near(front, "tunnel", 40.0) == 0 and _my_structs("tunnel").size() < fobs.size() + 1 and t > 120.0:
		plan.append(["tunnel", front, 10.0, 30.0])
	elif _my_structs("research").is_empty() and t > 330.0 and sup > 300:
		plan.append(["research", main, 12.0, 34.0])
	elif _my_structs("helipad").is_empty() and not _my_structs("factory").is_empty() and t > 450.0 and sup > 350:
		plan.append(["helipad", main, 14.0, 36.0])
	var enemy_armor := false
	for v in world.vehicles:
		if v.team != team and v.team >= 0 and v.vkind != "truck" and v.visible_to_team(team):
			enemy_armor = true
	for f in fobs:
		if _count_near(f, "sandbags", 24.0) < 4 and t > 40.0:
			plan.append(["sandbags", f, 9.0, 20.0])
		if _count_near(f, "mg_nest", 30.0) < 1 and t > 100.0:
			plan.append(["mg_nest", f, 9.0, 18.0])
		if _count_near(f, "trench", 34.0) < 6 and t > 110.0:
			plan.append(["trench_line", f, 17.0, 0.0])
		if _count_near(f, "hmg_nest", 30.0) < 1 and t > 170.0:
			plan.append(["hmg_nest", f, 9.0, 18.0])
		if f == front and _count_near(f, "mortar_pit", 35.0) < 1 and t > 240.0:
			plan.append(["mortar_pit", f, 8.0, 18.0])
		if f == front and _count_near(f, "bunker", 30.0) < 1 and t > 320.0:
			plan.append(["bunker", f, 10.0, 22.0])
		if enemy_armor and _count_near(f, "at_post", 35.0) < 1:
			plan.append(["at_post", f, 10.0, 22.0])
		if _count_near(f, "watchtower", 30.0) < 1 and t > 260.0:
			plan.append(["watchtower", f, 8.0, 18.0])
	if team == Defs.REBELS and front and t > 200.0 and _my_structs("tunnel").size() < 2 + maxi(0, fobs.size() - 1) and _count_near(front, "tunnel", 30.0) > 0:
		plan.append(["tunnel", front, 45.0, 66.0])
	if t > obstacle_t and front:
		obstacle_t = t + rng.randf_range(80.0, 140.0)
		plan.append([["wire", "mines", "tank_trap"][rng.randi() % 3], front, 18.0, 34.0])
	if t > expand_t and sup > 300 and fobs.size() < 3 + int(MapDims.HALF / 128.0):  # (more ground, more bases)
		var spot := _expansion_spot()
		if spot != Vector3.INF:
			expand_t = t + rng.randf_range(120.0, 200.0)
			_place("fob", spot, Defs.yaw_of(_enemy_dir()), engs)
			return
		expand_t = t + 30.0
	if NavalAI.dock_wanted(self, sup):
		var ds := NavalAI.dock_spot(self)
		if not ds.is_empty():
			_place("dock", ds[0], ds[1], engs)
			return
	for p in plan:
		if p[0] == "trench_line":
			if sup > 150 + _fob_reserve() and _dig_line(p[1], float(p[2]), engs):
				return
			continue
		var def: Dictionary = Defs.BUILDINGS[p[0]]
		if not team in def.teams or sup < int(def.cost) + 40 + _fob_reserve():
			continue
		var anchor: Structure = p[1]
		if anchor == null:
			continue
		var pos := _find_spot(String(p[0]), anchor.position, float(p[2]), float(p[3]))
		if pos != Vector3.INF:
			# square to the front like everything else on the build grid
			var yaw := TrenchNet.snap_yaw(Defs.yaw_of(_enemy_dir()))
			_place(String(p[0]), pos, yaw, engs)
			return


## A zig-zag fire trench across the FOB's front, and a communication trench
## running back from its middle.
func _dig_line(f: Structure, dist: float, engs: Array) -> bool:
	if f == null:
		return false
	var fwd := _enemy_dir()
	var side := fwd.cross(Vector3.UP)
	var c := f.position + fwd * (dist + rng.randf_range(-2.0, 3.0))
	var half := rng.randf_range(13.0, 18.0)
	var items := []
	for it in TrenchNet.layout(c - side * half, c + side * half, true, 6.0, 9):
		if world.placement_error(team, "trench", it[0], it[1]) == "":
			items.append(it)
	if items.size() < 3:
		return false
	var mid := TrenchNet.snap_pos(c)
	for it in TrenchNet.layout(mid, mid - fwd * (dist - 8.0), false, 6.0, 2):
		if world.placement_error(team, "trench", it[0], it[1]) == "":
			items.append(it)
	var best: Squad = null
	for sq in engs:
		if best == null or Defs.flat(sq.centroid() - c).length() < Defs.flat(best.centroid() - c).length():
			best = sq
	_cmd({"t": "build_many", "kind": "trench", "items": items, "squads": [best.sid] if best else []})
	return true


func _count_near(f: Structure, kind: String, r: float) -> int:
	if f == null:
		return 0
	var n := 0
	for st in world.structures_near(f.position, r):
		if st.team == team and st.skind == kind:
			n += 1
	return n


func _place(kind: String, pos: Vector3, yaw: float, engs: Array) -> void:
	var best: Squad = null
	var bd := 1e9
	for sq in engs:
		if sq.build_target != null and not sq.build_target.gone and sq.build_target.needs_work():
			continue
		var d: float = Defs.flat(sq.centroid() - pos).length()
		if d < bd:
			bd = d
			best = sq
	if best == null and not engs.is_empty():
		best = engs[0]
	_cmd({"t": "build", "kind": kind, "pos": pos, "yaw": yaw, "squads": [best.sid] if best else []})


func _find_spot(kind: String, center: Vector3, rmin: float, rmax: float) -> Vector3:
	var fwd := _enemy_dir()
	# machine guns go into the trench line when there is one: a bay facing the enemy
	if kind in ["mg_nest", "hmg_nest"]:
		var cands := []
		for st in world.structures_near(center, rmax + 6.0):
			if st.skind == "trench" and st.team == team and st.built and absf(Defs.dir_of(st.yaw).dot(fwd)) < 0.5:
				cands.append(st)
		cands.shuffle()
		for st in cands:
			var spot: Dictionary = world.trench_mount_spot(st.position, Defs.yaw_of(fwd))
			if spot.is_empty():
				continue
			var taken := false
			for o in world.structures_near(spot.pos, 9.0):
				if o.skind in ["mg_nest", "hmg_nest"]:
					taken = true
					break
			if not taken and world.placement_error(team, kind, spot.pos, float(spot.yaw)) == "":
				return spot.pos
	for i in 20:
		var a := rng.randf_range(-PI, PI)
		if kind in ["sandbags", "mg_nest", "hmg_nest", "wire", "mines", "tank_trap", "watchtower", "trench", "bunker", "at_post"] or rmin >= 40.0:
			a = rng.randf_range(-1.1, 1.1)
		elif kind in ["barracks", "factory", "medic_tent", "research", "mortar_pit"]:
			a = rng.randf_range(PI * 0.5, PI * 1.5)
		var dir := fwd.rotated(Vector3.UP, a)
		var p := center + dir * rng.randf_range(rmin, rmax)
		var yaw := TrenchNet.snap_yaw(Defs.yaw_of(fwd))
		p = TrenchNet.snap_foot(p, kind, yaw)
		if world.placement_error(team, kind, p, yaw) == "":
			return p
	return Vector3.INF


func _expansion_spot() -> Vector3:
	var front := _front_fob()
	if front == null:
		return Vector3.INF
	var fwd := _enemy_dir()
	for i in 24:
		var dir := fwd.rotated(Vector3.UP, rng.randf_range(-0.9, 0.9))
		var p := front.position + dir * rng.randf_range(60.0, 105.0)
		p.x = clampf(p.x, -MapDims.HALF + 23.0, MapDims.HALF - 23.0)
		p = Vector3(snappedf(p.x, 0.5), 0, snappedf(p.z, 0.5))
		if world.placement_error(team, "fob", p, Defs.yaw_of(fwd)) == "":
			var danger := false
			for s in world.soldiers_near(p, 40.0):
				if s.team != team and s.team >= 0 and s.life == Soldier.Life.ALIVE:
					danger = true
					break
			if not danger:
				return p
	return Vector3.INF


# --- production --------------------------------------------------------------------

## What to build at the Factory next: something unlocked, weighted by what
## the fight needs - anti-armour when there is armour about, more armour as
## the game goes on, a support or logistics vehicle now and then.
func _pick_vehicle(enemy_armor: int) -> String:
	var r := world.rules
	var opts: Array = Defs.BUILDINGS.factory.produces[team]
	var picks := []
	var total := 0.0
	for k in opts:
		if r.tier_needed(team, k) != "":
			continue
		var d: Dictionary = Defs.VEHICLES[k]
		var w := 1.0
		match String(d.get("base", "")):
			"tank":
				w = 2.2 + enemy_armor * 0.6
			"afv":
				w = 2.4
			"car":
				w = 1.6 + (1.2 if int(d.get("atgm", [0])[0]) > 0 and enemy_armor > 0 else 0.0)
			"spaa":
				w = 0.3 + (3.0 if _enemy_air() else 0.0)
			"arty":
				w = 0.8
			"util":
				w = 0.5 if d.has("service") else 0.8
		w *= 1.0 + 0.25 * (int(d.get("tier", 1)) - 1)
		picks.append([k, w])
		total += w
	if picks.is_empty():
		return String(opts[0])
	var x := rng.randf() * total
	for p in picks:
		x -= float(p[1])
		if x <= 0.0:
			return String(p[0])
	return String(picks.back()[0])


## An unlocked helipad item of a kind: "supply", "attack_heli", "lift_heli", "uav".
func _air_pick(kind: String) -> String:
	var opts := []
	for k in Defs.BUILDINGS.helipad.produces[team]:
		var d: Dictionary = Defs.VEHICLES[k]
		if world.rules.tier_needed(team, k) != "":
			continue
		var is_kind: bool = d.get("supply", false) if kind == "supply" else (String(d.base) == kind and not d.get("supply", false))
		if is_kind:
			opts.append(k)
	return String(opts[rng.randi() % opts.size()]) if not opts.is_empty() else ""


func _enemy_air() -> bool:
	for v in world.vehicles:
		if v.team != team and v.team >= 0 and v.is_heli() and v.visible_to_team(team):
			return true
	return false


func _production(sqs: Array) -> void:
	var r := world.rules
	var sup: int = r.supply_total(team)  # (spending draws on every FOB: see Rules.spend)
	# the dock's first boats come before anything else (they're cheap, and the
	# defences and the next FOB would otherwise eat every round of supply)
	sup -= NavalAI.produce(self, sup, 0)
	var eng_n := 0
	var counts := {}
	for sq in sqs:
		counts[sq.kind] = int(counts.get(sq.kind, 0)) + 1
		if _is_engineer_squad(sq):
			eng_n += 1
	var enemy_armor := 0
	for v in world.vehicles:
		if v.team != team and v.team >= 0 and not v.is_auto() and v.visible_to_team(team):
			enemy_armor += 1
	# save up for a vehicle once we have a factory and few vehicles
	var my_veh := 0
	for v in world.vehicles:
		if v.team == team and v.owner_peer == peer and not v.is_auto():
			my_veh += 1
	var factories := _my_structs("factory", true)
	var saving := 0
	# unit cap held back for the vehicle being saved for: otherwise the
	# barracks fill every free slot with infantry and it never rolls out
	var room := 0
	if not factories.is_empty() and my_veh < 1 + int(world.time / 420.0) and factories[0].queue.is_empty():
		if next_vehicle == "":
			next_vehicle = _pick_vehicle(enemy_armor)
		saving = int(Defs.VEHICLES[next_vehicle].cost)
		room = int(Defs.VEHICLES[next_vehicle].cap)
		if sup >= saving + _fob_reserve() and r.has_cap(team, room):
			_cmd({"t": "train", "building": factories[0].eid, "item": next_vehicle})
			sup -= saving
			saving = 0
			room = 0
			next_vehicle = ""
	# a FOB further forward comes before more men, once one's due - and so
	# does the factory (on a big map the barracks would otherwise spend every
	# last round of supply on infantry, and no armour would ever roll out)
	saving += _fob_reserve()
	if factories.is_empty() and _my_structs("factory").is_empty() and world.time > 200.0:
		saving += int(Defs.BUILDINGS.factory.cost)
	elif NavalAI.dock_wanted(self, 9999) and world.time > 600.0:
		saving += int(Defs.BUILDINGS.dock.cost) / 2
	var boat_save := NavalAI.saving(self)
	if sqs.size() < 3:
		saving = 0
		room = 0
	for b in _my_structs("barracks", true):
		if b.queue.size() >= 2 or not r.has_cap(team, 6 + room):
			continue
		var key := _pick_squad(counts, eng_n, enemy_armor)
		var def: Dictionary = Defs.SQUADS[key]
		if sup >= int(def.cost) + 30 + saving + boat_save:
			_cmd({"t": "train", "building": b.eid, "item": key})
			sup -= int(def.cost)
			counts[key] = int(counts.get(key, 0)) + 1
	for hp in _my_structs("helipad", true):
		if not hp.queue.is_empty():
			continue
		var n := {"supply": 0, "attack_heli": 0, "lift": 0, "uav": 0}
		for v in world.vehicles:
			if v.team != team or v.gone:
				continue
			if v.vdef.get("supply", false):
				n.supply += 1
			elif v.base() == "attack_heli":
				n.attack_heli += 1
			elif v.base() == "lift_heli":
				n.lift += 1
			elif v.base() == "uav":
				n.uav += 1
		var want := ""
		if n.supply < 1:
			want = _air_pick("supply")
		elif n.attack_heli < 1 + int(world.time / 900.0):
			want = _air_pick("attack_heli")
		elif n.uav < 1 and world.time > 600.0:
			want = _air_pick("uav")
		elif n.lift < 1 and world.time > 500.0:
			want = _air_pick("lift_heli")
		if want != "" and sup >= int(Defs.VEHICLES[want].cost) + 80 + saving:
			_cmd({"t": "train", "building": hp.eid, "item": want})
			sup -= int(Defs.VEHICLES[want].cost)
	for rs in _my_structs("research", true):
		if not rs.queue.is_empty():
			continue
		for k in Defs.UPGRADES:
			var u: Dictionary = Defs.UPGRADES[k]
			if not team in u.teams or r.has_upgrade(team, k):
				continue
			if u.has("requires") and not r.has_upgrade(team, String(u.requires)):
				continue
			if u.has("tier") and world.time < 300.0 * float(u.tier):
				continue
			if sup > int(u.cost) + 200:
				_cmd({"t": "research", "building": rs.eid, "item": k})
				break


func _pick_squad(counts: Dictionary, eng_n: int, enemy_armor: int) -> String:
	if team == Defs.ARMY:
		if eng_n < 1 or (eng_n < 2 and world.time > 400.0):
			return "engineer_team"
		var roll := rng.randf()
		if enemy_armor > 0 and int(counts.get("at_team", 0)) < enemy_armor + 1 and roll < 0.5:
			return "at_team"
		if roll < 0.5:
			return "rifle_squad"
		if roll < 0.62 and int(counts.get("mortar_team", 0)) < 2:
			return "mortar_team"
		if roll < 0.75:
			return "mg_team"
		return "at_team" if roll < 0.87 else "rifle_squad"
	if eng_n < 1 or (eng_n < 2 and world.time > 400.0):
		return "digger_team"
	var roll2 := rng.randf()
	if enemy_armor > 0 and int(counts.get("rpg_team", 0)) < enemy_armor + 1 and roll2 < 0.45:
		return "rpg_team"
	if roll2 < 0.4:
		return "fighter_cell"
	if roll2 < 0.48 and int(counts.get("r_mortar_team", 0)) < 2:
		return "r_mortar_team"
	if roll2 < 0.62:
		return "pkm_team"
	if roll2 < 0.8:
		return "fpv_team"
	return "rpg_team"


# --- military ----------------------------------------------------------------------

func _military(sqs: Array) -> void:
	var r := world.rules
	var fobs: Array = r.fobs(team)
	if fobs.is_empty():
		return
	var t := world.time
	for sid in roles.keys():
		if not world.squads.has(sid):
			roles.erase(sid)
	var fighters := []
	for sq in sqs:
		if _is_engineer_squad(sq) and sq.kind in ["engineer_team", "digger_team"]:
			continue
		if sq.alive_members().is_empty() or sq.kind in ["crew", "r_crew"]:
			continue  # (a crew that bailed out is on its way back to the vehicle park)
		fighters.append(sq)
	# retreat battered squads
	for sq in fighters:
		var alive: int = sq.alive_members().size()
		var total: int = maxi(1, sq.members.size())
		if alive * 1.0 / total < 0.34 and roles.get(sq.sid, {}).get("role", "") != "retreat":
			roles[sq.sid] = {"role": "retreat", "t": t}
			_cmd({"t": "retreat", "squads": [sq.sid]})
	# defence: answer threats near our FOBs
	for f in fobs:
		var threat := 0
		for s in world.soldiers_near(f.position, 45.0):
			if s.team != team and s.team >= 0 and s.life == Soldier.Life.ALIVE and s.visible_to_team(team):
				threat += 1
		if threat >= 2 and t > defense_t:
			defense_t = t + 20.0
			var sent := 0
			for sq in _by_distance(fighters, f.position):
				if sent >= 2 or Defs.flat(sq.centroid() - f.position).length() > 120.0:
					break
				roles[sq.sid] = {"role": "defend", "t": t}
				_cmd({"t": "defend", "squads": [sq.sid], "pos": f.position + _enemy_dir() * 8.0, "face": _enemy_dir()})
				sent += 1
	# garrison: one squad per FOB
	var defenders := {}
	for sq in fighters:
		var role: Dictionary = roles.get(sq.sid, {})
		if role.get("role", "") == "garrison" and role.has("fob"):
			defenders[role.fob] = sq
	for f in fobs:
		if defenders.has(f.eid):
			continue
		for sq in _by_distance(fighters, f.position):
			if roles.has(sq.sid) and roles[sq.sid].role != "idle":
				continue
			roles[sq.sid] = {"role": "garrison", "t": t, "fob": f.eid}
			var bunker: Structure = null
			for st in world.structures_near(f.position, 30.0):
				if st.team == team and st.skind == "bunker" and st.built:
					bunker = st
			if bunker:
				_cmd({"t": "enter", "squads": [sq.sid], "target": bunker.eid})
			else:
				var spot: Vector3 = f.position + _enemy_dir() * 9.0 + Vector3(rng.randf_range(-6, 6), 0, 0)
				_cmd({"t": "defend", "squads": [sq.sid], "pos": spot, "face": _enemy_dir()})
			break
	_reinforce(fighters)
	_outposts(fighters)
	# pick a target
	if attack_target == null or attack_target.gone or attack_target.team == team:
		attack_target = _pick_target()
	var attackers := []
	for sq in fighters:
		var role2: String = roles.get(sq.sid, {}).get("role", "idle")
		if role2 == "attack":
			# an attack under way is left to run: re-sending the wave order used to
			# restart every plan from scratch every 25 s, before it could go in
			if sq.plan != null and not sq.plan.done:
				continue
			if sq.order == "assault" and t - float(roles[sq.sid].t) < 90.0:
				continue
			attackers.append(sq)
		elif role2 == "idle":
			attackers.append(sq)
		elif role2 in ["defend", "retreat"] and t - float(roles[sq.sid].t) > 45.0:
			roles[sq.sid] = {"role": "idle", "t": t}
	var vehs := []
	var back := []
	var drones := []
	var boats := []
	var fbase := _front_fob()
	for v in world.vehicles:
		if v.team != team or v.owner_peer != peer or v.is_auto() or v.gone:
			continue
		var vb: String = v.base()
		if vb == "boat":
			boats.append(v)  # (the navy has its own orders: see NavalAI)
		elif vb == "uav":
			drones.append(v)
		elif vb == "arty" or v.vdef.has("service"):
			back.append(v)
		elif vb == "lift_heli" and v.passengers.is_empty():
			continue  # an empty troop helicopter waits at the pad
		else:
			vehs.append(v)
	NavalAI.tick(self, boats)
	# guns and support vehicles keep station behind the front
	if fbase and t > _back_t:
		_back_t = t + 30.0
		var ed := _enemy_dir()
		for i in back.size():
			var bv: Vehicle = back[i]
			var spot: Vector3 = fbase.position - ed * (24.0 if bv.base() == "arty" else 10.0) + ed.cross(Vector3.UP) * (i - back.size() * 0.5) * 9.0
			if Defs.flat(bv.position - spot).length() > 14.0 and bv.path_i >= bv.path.size():
				_cmd({"t": "move", "vehicles": [bv.eid], "pos": spot})
	# drones circle over whatever we're attacking, or ahead of the front
	for dv in drones:
		var over: Vector3 = attack_target.position if attack_target else (fbase.position + _enemy_dir() * 45.0 if fbase else dv.position)
		if Defs.flat(dv.uav_dest - over).length() > 25.0:
			_cmd({"t": "move", "vehicles": [dv.eid], "pos": over})
	var wave := 3 if t < 600.0 else 4
	if attack_target and (attackers.size() >= wave or (attackers.size() >= 2 and t - last_wave_t > 200.0)):
		if t - last_wave_t > 25.0:
			last_wave_t = t
			var ids := []
			for sq in attackers:
				if _try_tunnel(sq, attack_target.position):
					continue
				roles[sq.sid] = {"role": "attack", "t": t}
				ids.append(sq.sid)
			var dir := Defs.flat(attack_target.position - _centroid(attackers)).normalized()
			var dest: Vector3 = attack_target.position - dir * 4.0
			_cmd({"t": "assault", "squads": ids, "pos": dest, "face": dir})
			var vids := []
			for v in vehs:
				vids.append(v.eid)
			if not vids.is_empty():
				_cmd({"t": "assault", "vehicles": vids, "pos": attack_target.position - dir * 25.0, "face": dir})
	elif not vehs.is_empty() and t - last_wave_t > 60.0:
		var f2 := _front_fob()
		if f2:
			var vids2 := []
			for v in vehs:
				if v.path_i >= v.path.size() and Defs.flat(v.position - f2.position).length() > 30.0:
					vids2.append(v.eid)
			if not vids2.is_empty():
				_cmd({"t": "move", "vehicles": vids2, "pos": f2.position + _enemy_dir() * 15.0})
	# lay an ambush on a road they use (their supply trucks, their squads)
	var lying := 0
	for sid in roles.keys():
		if roles[sid].role != "ambush":
			continue
		var asq: Squad = world.squads.get(sid)
		if asq == null or asq.ambush_plan == null or asq.ambush_plan.done:
			if asq == null or asq.drill != "withdraw":
				roles[sid] = {"role": "idle", "t": t}
				# (the next one a while after this one's over)
				ambush_t = maxf(ambush_t, t + (rng.randf_range(90.0, 150.0) if team == Defs.REBELS else rng.randf_range(160.0, 240.0)))
		else:
			lying += 1
	if t > ambush_t and lying == 0:
		ambush_t = t + 40.0
		var site := _ambush_site()
		if not site.is_empty():
			var free := []
			for sq in attackers:
				if roles.get(sq.sid, {}).get("role", "idle") == "idle" and sq.plan == null and sq.drill == "" and sq.alive_members().size() >= 3:
					free.append(sq)
			if free.size() >= 2 or (free.size() == 1 and fighters.size() >= 4):
				# the squad with a gun or rockets, nearest the site
				var best: Squad = null
				var bs := -1e9
				for sq in free:
					var s := -Defs.flat(sq.centroid() - site[0]).length() * 0.05
					for m in sq.alive_members():
						if m.utype in ["mg_gunner", "pkm"]:
							s += 6.0
						elif m.rockets > 0:
							s += 3.0
					if s > bs:
						bs = s
						best = sq
				if best:
					roles[best.sid] = {"role": "ambush", "t": t}
					AmbushPlan.make(world, best, site[0], site[1], site[2])
					world.stat("ai_ambush")
	_tunnel_progress()


## Rebels: if a squad is near one tunnel entrance and another entrance is much
## closer to where it is going, send it through the network.
func _try_tunnel(sq: Squad, dest: Vector3) -> bool:
	if team != Defs.REBELS:
		return false
	var tunnels := _my_structs("tunnel", true)
	if tunnels.size() < 2:
		return false
	var c := sq.centroid()
	var entry: Structure = null
	var ed := 40.0
	var exit: Structure = null
	var xd := 1e9
	for tn in tunnels:
		var d1: float = Defs.flat(tn.position - c).length()
		if d1 < ed:
			ed = d1
			entry = tn
		var d2: float = Defs.flat(tn.position - dest).length()
		if d2 < xd:
			xd = d2
			exit = tn
	if entry == null or exit == null or entry == exit:
		return false
	if Defs.flat(dest - c).length() - xd < 40.0:
		return false
	roles[sq.sid] = {"role": "tunnel", "t": world.time, "from": entry.eid, "to": exit.eid, "sent": false}
	_cmd({"t": "enter", "squads": [sq.sid], "target": entry.eid})
	return true


func _tunnel_progress() -> void:
	for sid in roles.keys():
		var r: Dictionary = roles[sid]
		if r.role != "tunnel":
			continue
		var sq: Squad = world.squads.get(sid)
		if sq == null:
			continue
		var alive := 0
		var inside := 0
		var travelling := 0
		for m in sq.members:
			if m.gone or m.life == Soldier.Life.DEAD or m.life == Soldier.Life.DOWNED:
				continue
			alive += 1
			if m.life == Soldier.Life.HIDDEN:
				if m.hidden_reason == "tunnel_wait":
					inside += 1
				elif m.hidden_reason == "tunnel_travel":
					travelling += 1
		if not r.sent and alive > 0 and inside == alive:
			_cmd({"t": "tunnel_exit", "building": r.from, "exit": r.to})
			r.sent = true
			world.stat("ai_tunnel_trip")
		elif r.sent and inside == 0 and travelling == 0:
			roles[sid] = {"role": "idle", "t": world.time}
		elif world.time - float(r.t) > 60.0:
			if inside > 0:
				_cmd({"t": "tunnel_exit", "building": r.from, "exit": r.from})
			roles[sid] = {"role": "idle", "t": world.time}


func _centroid(sqs: Array) -> Vector3:
	var c := Vector3.ZERO
	for sq in sqs:
		c += sq.centroid()
	return c / maxf(1, sqs.size())


func _by_distance(sqs: Array, p: Vector3) -> Array:
	var arr := sqs.duplicate()
	arr.sort_custom(func(a, b): return Defs.flat(a.centroid() - p).length() < Defs.flat(b.centroid() - p).length())
	return arr


func _pick_target() -> Structure:
	var front := _front_fob()
	var from: Vector3 = front.position if front else Vector3.ZERO
	var best: Structure = null
	var bd := 1e9
	for st in world.structures:
		if st.skind != "fob" or st.team == team or st.team < 0 or not st.built:
			continue
		var known: bool = ((st.seen_mask >> team) & 1) == 1 or st.completed_order <= 2
		if not known:
			continue
		var d: float = Defs.flat(st.position - from).length()
		if d < bd:
			bd = d
			best = st
	return best


## Where to lay an ambush: a straight stretch of a road the enemy uses (his
## supply track, or the map's roads), between the fronts, with cover or
## concealment to lie in on one side, well clear of his bases and ours.
## [killing zone centre, along the road, towards the ambush line] or [].
func _ambush_site() -> Array:
	var enemy := 1 - team
	var front := _front_fob()
	if front == null:
		return []
	var ed := _enemy_dir()
	var best := []
	var bs := -1e9
	var polys: Array = (world.roads[enemy] as Array) + (world.roads[2] as Array)
	var supply_n := (world.roads[enemy] as Array).size()
	for pi in polys.size():
		var pl: PackedVector3Array = polys[pi]
		if pl.size() < 3:
			continue
		var walked := 0.0
		for i in range(1, pl.size() - 1):
			walked += Defs.flat(pl[i] - pl[i - 1]).length()
			if walked < 8.0:
				continue  # a candidate every 8 m or so
			walked = 0.0
			var p: Vector3 = pl[i]
			var ahead := Defs.flat(p - front.position).dot(ed)
			if ahead < 30.0 or ahead > 230.0:
				continue
			var a := _along_road(pl, i, -1, 18.0)
			var b := _along_road(pl, i, 1, 18.0)
			var along := Defs.flat(b - a)
			if along.length() < 30.0:
				continue
			along = along.normalized()
			# straight enough to see down: no sharp bend through the killing zone
			if Defs.flat(p - a).normalized().dot(Defs.flat(b - p).normalized()) < 0.9:
				continue
			var clear := true
			for f in world.rules.fobs(enemy) + world.rules.fobs(team):
				if Defs.flat(f.position - p).length() < 70.0:
					clear = false
					break
			for d in world.rules.depots:
				if d and Defs.flat(d.position - p).length() < 120.0:
					clear = false
			if not clear:
				continue
			var n := along.cross(Vector3.UP)
			for sgn in [-1.0, 1.0]:
				var side: Vector3 = n * sgn
				var lp: Vector3 = p + side * AmbushPlan.STANDOFF
				if not world.nav.walkable(lp):
					continue
				# concealment and cover along the line; our side of the road preferred
				var s := 0.0
				for k in [-12.0, 0.0, 12.0]:
					var q: Vector3 = lp + along * k
					s += (1.0 - world.terrain.concealment(q)) * 3.0 + float(world.terrain.cov[world.terrain.idx_of(q)]) * 0.6
				s += 2.0 if side.dot(-ed) > 0.0 else 0.0
				s += 3.0 if pi < supply_n else 0.0  # their trucks are sure to come down it
				s -= ahead * 0.01 + rng.randf() * 0.8
				if s > bs:
					bs = s
					best = [p, along, side]
	return best


## The point `dist` metres along the polyline from point i (dir -1 back, 1 on).
static func _along_road(pl: PackedVector3Array, i: int, dir: int, dist: float) -> Vector3:
	var d := 0.0
	var j := i
	while j + dir >= 0 and j + dir < pl.size():
		d += Defs.flat(pl[j + dir] - pl[j]).length()
		j += dir
		if d >= dist:
			break
	return pl[j]


func _ambush_spot() -> Vector3:
	var enemy := 1 - team
	var polys: Array = world.roads[enemy]
	if polys.is_empty():
		return Vector3.INF
	var poly: PackedVector3Array = polys[rng.randi() % polys.size()]
	if poly.size() < 4:
		return Vector3.INF
	var p := poly[poly.size() / 2]
	for st in world.structures_near(p, 35.0):
		if st.skind == "fob" and st.team == enemy:
			return Vector3.INF
	var side := Defs.flat(poly[poly.size() / 2 + 1] - p).normalized().cross(Vector3.UP)
	return p + side * 12.0
