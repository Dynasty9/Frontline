class_name VehicleBrain
extends RefCounted
## What a combat vehicle's crew does, as a behaviour tree (see BT), walked
## twice a second for tanks, IFVs, APCs and armed cars (aircraft, supply
## trucks and the guns have their own routines). Most urgent first:
##   - badly damaged, the crew pulls back to the nearest FOB to be patched up;
##   - a missile or rocket launched at it: smoke (see Vehicle.threatened), then
##     back out of the line of fire, front armour still towards the shooter,
##     and on with the job once it's clear;
##   - (the AI's) anti-tank teams ahead and no infantry of its own about: it
##     holds back and shoots from where it is - a tank driving into a town or
##     a wood alone is a dead tank;
##   - at a halt with armour or anti-tank weapons about, it turns its thick
##     front plate towards them.

static var _tree: BT.Branch = null


static func tree() -> BT.Branch:
	if _tree == null:
		_tree = _build()
	return _tree


static func think(v: Vehicle) -> void:
	tree().tick(v)


static func _build() -> BT.Branch:
	return BT.sel("crew", [
		BT.seq("pull back", [BT.cond("badly damaged", func(v): return should_withdraw(v)), BT.act("back to a FOB for repairs", func(v): return withdraw(v))]),
		BT.seq("pulling back", [BT.cond("pulling back", func(v): return v.brain_state == "withdraw"), BT.act("get there, get fixed", func(v): return withdraw_tick(v))]),
		BT.seq("evading", [BT.cond("evading", func(v): return v.brain_state == "evade"), BT.act("back out of the line of fire", func(v): return evade_tick(v))]),
		BT.seq("wait for the infantry", [BT.cond("anti-tank ahead, alone", func(v): return should_wait(v)), BT.act("hold back and overwatch", func(v): return hold(v))]),
		BT.act("carry on", func(v): return carry_on(v)),
	])


## Who has a crew that thinks like this.
static func applies(v: Vehicle) -> bool:
	return not v.is_air() and not v.is_auto() and not v.vdef.has("art") and v.base() in ["tank", "afv", "car", "spaa"]


static func _save_order(v: Vehicle) -> void:
	v.brain_resume = {"dest": v.path[v.path.size() - 1] if v.path_i < v.path.size() else Vector3.INF,
		"assault": v.assault, "assault_dest": v.assault_dest}


static func _resume(v: Vehicle) -> void:
	var r: Dictionary = v.brain_resume
	v.brain_state = ""
	v.brain_hold = false
	if r.is_empty():
		return
	if bool(r.get("assault", false)) and r.assault_dest != Vector3.INF:
		v.drive_to(r.assault_dest)
		v.assault = true
	elif r.dest != Vector3.INF:
		v.drive_to(r.dest)
	v.brain_resume = {}


static func _threat_near(v: Vehicle, r: float) -> Entity:
	var best: Entity = null
	var bd := r
	for e in v.world.units_near(v.position, r):
		if e.team == v.team or e.team < 0 or e.gone:
			continue
		var dangerous := false
		if e is Vehicle:
			dangerous = not e.is_air() and (e.vdef.get("cannon", false) or int(e.atgm_left) > 0)
		elif e is Soldier:
			dangerous = e.life == Soldier.Life.ALIVE and (e.rockets > 0 or e.utype in ["at_soldier", "rpg"])
		if not dangerous or not e.visible_to_team(v.team):
			continue
		var d: float = Defs.flat(e.position - v.position).length()
		if d < bd:
			bd = d
			best = e
	return best


# --- pulling back --------------------------------------------------------------------

static func should_withdraw(v: Vehicle) -> bool:
	if v.brain_state in ["withdraw", "evade"] or v.brain_overruled or v.track_broken or v.hp > v.max_hp * 0.35:
		return false
	var f: Structure = v.world.rules.nearest_fob(v.team, v.position)
	if f == null:
		return false
	var d := Defs.flat(f.position - v.position).length()
	# in a mission the nearest FOB is likely the far end of the map: the crew
	# fights it out where it is
	return d > 25.0 and (v.world.mission == null or d < 200.0)


static func withdraw(v: Vehicle) -> int:
	var f: Structure = v.world.rules.nearest_fob(v.team, v.position)
	v.brain_state = "withdraw"
	v.brain_t = v.world.time
	v.brain_resume = {}
	v.assault = false
	v.brain_hold = false
	v.drive_to(v.world.nav.nearest_walkable(f.position + Defs.flat(v.position - f.position).normalized() * 12.0, true))
	if not v.is_auto():
		v.world.send_msg(v.team, "alert", "%s badly damaged - pulling back to %s for repairs." % [v.display_name(), f.display_name()], v.position)
	v.world.stat("veh_withdraw")
	return BT.OK


static func withdraw_tick(v: Vehicle) -> int:
	# the FOB's mechanics work on it once it's in (engineers and a repair
	# truck do it faster)
	var f: Structure = v.world.rules.nearest_fob(v.team, v.position)
	if f and absf(v.speed) < 0.5 and Defs.flat(f.position - v.position).length() < 26.0:
		v.repair(0.15)
	if v.hp > v.max_hp * 0.8:
		v.brain_state = ""  # patched up: back to work when told
		v.world.stat("veh_patched_up")
		if not v.is_auto():
			v.world.send_msg(v.team, "info", "%s patched up and ready." % v.display_name(), v.position)
	_watch(v)
	return BT.OK


# --- evading -------------------------------------------------------------------------

## A launch at it (after the smoke): back off out of the line of fire.
static func on_threat(v: Vehicle, from: Vector3) -> void:
	if not applies(v) or v.brain_state in ["withdraw", "evade"] or v.track_broken or int(v.vdef.get("armor", 0)) < 1:
		return
	_save_order(v)
	var away := Defs.flat(v.position - from).normalized()
	var side := away.cross(Vector3.UP) * (1.0 if v.world.rng.randf() < 0.5 else -1.0)
	var spot := v.world.nav.nearest_walkable(v.position + away * 16.0 + side * 6.0, true)
	v.brain_state = "evade"
	v.brain_t = v.world.time
	v.brain_hold = false
	v.assault = false
	v.drive_to(spot)
	v.world.stat("veh_evade")


static func evade_tick(v: Vehicle) -> int:
	if v.path_i >= v.path.size() or v.world.time - v.brain_t > 9.0:
		_resume(v)
	_watch(v)
	return BT.OK


# --- waiting for the infantry --------------------------------------------------------

static func should_wait(v: Vehicle) -> bool:
	if v.owner_peer >= 0 or not v.assault or v.path_i >= v.path.size() or v.world.time < float(v.bt_cd.get("push_on", -1.0)):
		return false
	var fwd := Defs.dir_of(v.rotation.y)
	var at: Entity = null
	for e in v.world.soldiers_near(v.position + fwd * 30.0, 45.0):
		if e.team != v.team and e.team >= 0 and e.life == Soldier.Life.ALIVE and (e.rockets > 0 or e.utype in ["at_soldier", "rpg"]) \
				and e.visible_to_team(v.team) and Defs.flat(e.position - v.position).dot(fwd) > 0.0:
			at = e
			break
	if at == null:
		return false
	for s in v.world.soldiers_near(v.position, 35.0):
		if s.team == v.team and s.life == Soldier.Life.ALIVE and s.riding == null:
			return false  # infantry with it: they deal with the anti-tank teams
	return true


static func hold(v: Vehicle) -> int:
	if v.brain_state != "wait":
		v.brain_state = "wait"
		v.brain_t = v.world.time
		v.world.stat("veh_wait_infantry")
	elif v.world.time - v.brain_t > 45.0:
		# nobody's coming: push on regardless
		v.bt_cd["push_on"] = v.world.time + 60.0
		v.brain_state = ""
		v.brain_hold = false
		return BT.OK
	v.brain_hold = true
	_watch(v)
	return BT.OK


# --- the rest of the time ------------------------------------------------------------

static func carry_on(v: Vehicle) -> int:
	if v.brain_state == "wait":
		v.brain_state = ""  # the infantry have caught up, or the threat has gone
	v.brain_hold = false
	if v.brain_overruled and v.hp > v.max_hp * 0.8:
		v.brain_overruled = false
	_watch(v)
	return BT.FAIL


## At a halt with armour or anti-tank weapons about: the thick front plate
## towards the nearest of them (Vehicle._face turns the hull).
static func _watch(v: Vehicle) -> void:
	v.face_yaw = INF
	if not v.is_tracked() or int(v.vdef.get("armor", 0)) < 2:
		return
	var th := _threat_near(v, 120.0)
	if th:
		v.face_yaw = Defs.yaw_of(Defs.flat(th.position - v.position))
