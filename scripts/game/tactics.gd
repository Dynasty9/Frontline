class_name Tactics
extends RefCounted
## How a squad gets about and makes ground its own, between the fights the
## battle drills (SquadBrain) handle:
##   - movement technique: out of contact it travels in its wedge; where
##     contact is likely it moves by bounding overwatch - one fire team
##     dashes to the next cover while the other, down and watching, covers it,
##     then they leapfrog - and the covering team fires a burst or two into
##     the hedge or house where the enemy was last heard (recon by fire);
##   - a squad that has to go a long way to hold somewhere gets there as a
##     squad first, and only then spreads out into its positions;
##   - clearing: a squad holding ground with houses on it clears them - two
##     men stack on the door, kick it in and go through, room by room ("Clear!")
##     - before it settles in;
##   - near ambush: caught at close range, a steady squad doesn't lie there to
##     be shot - it assaults straight into the ambush;
##   - stragglers: the last man of a squad attaches himself to the nearest
##     friendly squad;
##   - crews: men who bailed out of a knocked-out vehicle make for the nearest
##     FOB, to crew another.

const BOUND := 34.0  # how far a team bounds (metres; less in town)


static func _pick(q: Squad, arr: Array) -> String:
	return arr[q.world.rng.randi() % arr.size()]


# --- movement technique --------------------------------------------------------------

## Is contact likely on the way? Then it bounds instead of travelling.
static func bounding_wanted(q: Squad, dest: Vector3, mode: int) -> bool:
	if mode >= 1 or q.kind in ["crew", "r_crew"]:
		return false
	var mems := 0
	for m in q.members:
		if m.riding != null or m.mounted != null:
			return false
		if m.can_take_orders() and not m.detached:
			mems += 1
	if mems < 2:
		return false
	var c := q.centroid()
	if Defs.flat(dest - c).length() < BOUND + 8.0:
		return false
	if q.world.time - q.alert_t < 75.0:
		return true  # in touch with them lately
	# something of theirs our side has seen, near where we're going (or ahead of us)
	for p in [dest, c.lerp(dest, 0.5)]:
		for e in q.world.units_near(p, 170.0):
			if e.team == q.team or e.team < 0 or e.gone:
				continue
			if e is Soldier and e.life != Soldier.Life.ALIVE:
				continue
			if e is Vehicle and e.is_auto():
				continue
			if e.visible_to_team(q.team):
				return true
	for st in q.world.structures_near(dest, 150.0):
		if st.team >= 0 and st.team != q.team and st.is_player_building() and st.visible_to_team(q.team):
			return true
	return false


## The two fire teams, by who's free to move (the guns split between them).
static func _teams(q: Squad) -> Array:
	var mems := []
	for m in q.members:
		if m.can_take_orders() and not m.detached and m.task == "" and m.mounted == null:
			mems.append(m)
	mems.sort_custom(func(a, b): return a.eid < b.eid)
	var a := []
	var b := []
	for i in mems.size():
		(a if i % 2 == 0 else b).append(mems[i])
	return [a, b]


static func _centroid(ms: Array, fallback: Vector3) -> Vector3:
	if ms.is_empty():
		return fallback
	var c := Vector3.ZERO
	for m in ms:
		c += m.position
	return c / ms.size()


static func start_bounding(q: Squad) -> void:
	q.technique = "bound"
	q.ow_team = 0
	q.travel = false
	var t := _teams(q)
	var ed := SquadBrain.enemy_dir(q)
	for m in t[1]:
		m.cmd_halt(ed)  # Bravo goes firm and covers Alpha's first bound
	_bound_next(q)
	SquadBrain._say(q, ["Bounding overwatch! Alpha moving, Bravo cover!", "By teams - bound! Watch your sectors!", "Alpha go, Bravo cover!", "Leapfrog it up, one team covering!"]
		if q.team == 0 else ["Half of you cover, half move! Go!", "Move in pairs, cover each other!", "You go, we cover! Then us!"])
	q.world.stat("bounding")


## The moving team dashes to cover a bound beyond the covering team (offset
## to one side, so the two aren't on one line); the last bound is the squad
## moving into its final places.
static func _bound_next(q: Squad) -> void:
	var t := _teams(q)
	var mover: Array = t[q.ow_team]
	var cover: Array = t[1 - q.ow_team]
	if mover.is_empty():
		mover = cover
		cover = []
	if mover.is_empty():
		return
	var cc := _centroid(cover, q.centroid())
	var to := Defs.flat(q.order_pos - cc)
	var urban: bool = q.world.town_rect.size.x > 8.0 and q.world.town_rect.grow(-4.0).has_point(Vector2(cc.x, cc.z))
	var leg := BOUND * (0.65 if urban else 1.0)
	if to.length() <= leg + 6.0:
		# the last bound: everyone into their places
		var td: Array = q.then_defend
		q.technique = ""
		q.order_move(q.order_pos, q.facing, 0, false)
		q.then_defend = td
		return
	var ed := SquadBrain.enemy_dir(q)
	var dir := to.normalized()
	var side := dir.cross(Vector3.UP) * (5.0 if q.ow_team == 0 else -5.0)
	var dest := q.world.nav.nearest_walkable(cc + dir * leg + side)
	# spread in a line across the front, each man in the best cover by his spot
	var slots := q._assign(q.formation(dest, ed, mover.size(), true), mover)
	for i in mover.size():
		mover[i].cmd_move(slots[i], 1, ed)
	q.ow_t = q.world.time + 22.0
	if q.world.rng.randf() < 0.5 and not mover.is_empty():
		mover[0].say(_pick(q, ["Moving!", "Going!", "On the move!", "Bounding!"]), false)


## Bounding overwatch, every half second while it lasts.
static func overwatch_tick(q: Squad) -> void:
	if q.technique != "bound":
		return
	if q.order != "move" or q.drill != "":
		q.technique = ""
		return
	var t := _teams(q)
	var mover: Array = t[q.ow_team]
	var cover: Array = t[1 - q.ow_team]
	var moving := false
	for m in mover:
		if m.is_moving():
			moving = true
			break
	if moving and q.world.time < q.ow_t:
		_recon_by_fire(q, cover)
		return
	# set: the covering team bounds through
	if not mover.is_empty() and q.world.rng.randf() < 0.45:
		mover[0].say(_pick(q, ["Set!", "Set! Move up!", "In position, go!", "Covering!"]), false)
	q.ow_team = 1 - q.ow_team
	_bound_next(q)


## The covering team fires a burst or two into where the enemy was last
## heard or seen and isn't in sight now: if anyone's lying in wait there, he
## either fires back - and gives himself away - or keeps his head down.
static func _recon_by_fire(q: Squad, cover: Array) -> void:
	if q.world.time < q.ow_rbf_t or cover.is_empty():
		return
	q.ow_rbf_t = q.world.time + 14.0
	var c := _centroid(cover, q.centroid())
	var spot := Vector3.INF
	for i in range(q.heard.size() - 1, -1, -1):
		var h: Array = q.heard[i]
		var d := Defs.flat(h[0] - c).length()
		if q.world.time - float(h[1]) < 60.0 and d > 25.0 and d < 150.0:
			spot = h[0]
			break
	if spot == Vector3.INF:
		for k in q.known.values():
			var age: float = q.world.time - float(k.t)
			var d2 := Defs.flat(k.pos - c).length()
			if age > 5.0 and d2 > 25.0 and d2 < 150.0:
				spot = k.pos
				break
	if spot == Vector3.INF:
		return
	for o in q.world.soldiers_near(spot, 14.0):
		if o.team == q.team and o.life == Soldier.Life.ALIVE:
			return  # friends over there
	var gunner: Soldier = null
	for m in cover:
		if m.wdef.is_empty() or m.utype in ["medic", "r_medic"] or m.suppression > 30.0:
			continue
		if gunner == null or m.utype in ["mg_gunner", "pkm"]:
			gunner = m
	if gunner == null or Defs.flat(spot - gunner.position).length() > float(gunner.wdef.get("range", 60.0)):
		return
	gunner.cf_pos = spot + Vector3(0, 0.6, 0)
	gunner.cf_until = q.world.time + 2.6
	if q.world.rng.randf() < 0.6:
		gunner.say(_pick(q, ["Recon by fire!", "Putting rounds in that treeline!", "Spraying it - see if they bite!", "Rounds into that house!"])
			if q.team == 0 else _pick(q, ["Shoot it up, see who's there!", "Fire into it!"]), false)
	q.world.stat("recon_by_fire")


## A squad told to hold somewhere a long way off gets there as a squad - in
## its wedge, or by bounds - and then spreads out into its positions.
static func then_defend_tick(q: Squad) -> void:
	if q.then_defend.is_empty() or q.technique != "":
		return
	if q.order != "move" or q.drill != "":
		return
	var td: Array = q.then_defend
	var alive := q.alive_members()
	if alive.is_empty():
		return
	var near := Defs.flat(td[0] - q.centroid()).length() < 12.0
	var still := true
	for m in alive:
		if m.is_moving():
			still = false
			break
	if near or (still and not q.travel):
		q.then_defend = []
		q.order_defend(td[0], td[1], true)


# --- clearing houses -----------------------------------------------------------------

## Holding ground with houses on it, in a fight (or with the enemy about):
## the houses get cleared, one at a time, before the squad settles in.
static func can_clear(q: Squad) -> bool:
	if q.order != "defend" or q.drill != "" or q.plan != null or q.ambush_plan != null or q.kind in ["crew", "r_crew"]:
		return false
	if q.world.time < float(q.bt_cd.get("clear", -1.0)):
		return false
	q.bt_cd["clear"] = q.world.time + 2.0
	var cl: Soldier = q.breach_by
	if cl != null and is_instance_valid(cl) and not cl.gone and cl.life == Soldier.Life.ALIVE and cl.task == "breach":
		return false
	var alive := q.alive_members()
	if alive.size() < 2 or SquadBrain.avg_supp(alive) > 25.0:
		return false
	if q.world.time - q.alert_t > 150.0 and not _enemy_about(q, 150.0):
		return false
	for st in q.world.structures_near(q.order_pos, 22.0):
		if st.skind != "floor" or st.gone or Defs.flat(st.position - q.order_pos).length() > 18.0:
			continue
		if q.world.time - float(q.cleared.get(st.eid, -1e9)) < 600.0:
			continue
		q.cleared[st.eid] = q.world.time
		if _friends_inside(q, st):
			continue
		var door := []
		var bd := 1e9
		for o in SoldierBrain.openings(q.world, st):
			if not o[3]:
				continue
			var d := Defs.flat(o[1] - q.centroid()).length()
			if d < bd:
				bd = d
				door = o
		if door.is_empty():
			continue
		# the point man and his buddy: riflemen, nearest the door
		var cands := []
		for m in alive:
			if m.can_take_orders() and m.task == "" and not m.detached and m.mounted == null and not m.wdef.is_empty() \
					and not m.utype in ["mg_gunner", "pkm", "medic", "r_medic", "mortar_gunner", "r_mortar", "fpv_op"]:
				cands.append(m)
		if cands.is_empty():
			return false
		cands.sort_custom(func(a, b): return Defs.flat(a.position - door[1]).length() < Defs.flat(b.position - door[1]).length())
		q.bt_clear = [st, door, cands[0], cands[1] if cands.size() > 1 else null]
		return true
	return false


static func start_clear(q: Squad) -> int:
	var h: Structure = q.bt_clear[0]
	var door: Array = q.bt_clear[1]
	var s: Soldier = q.bt_clear[2]
	var buddy: Soldier = q.bt_clear[3]
	SoldierBrain.start_clearing(s, h, door, buddy)
	q.world.stat("clear_house")
	return BT.OK


static func _enemy_about(q: Squad, r: float) -> bool:
	for e in q.world.units_near(q.order_pos, r):
		if e.team != q.team and e.team >= 0 and not e.gone and e.visible_to_team(q.team) and (not (e is Soldier) or e.life == Soldier.Life.ALIVE):
			return true
	return false


static func _friends_inside(q: Squad, h: Structure) -> bool:
	for s in q.world.soldiers_near(h.position, maxf(h.size.x, h.size.z) * 0.6 + 1.0):
		if s.team == q.team and s.life == Soldier.Life.ALIVE and SoldierBrain.house_at(q.world, s.position) == h:
			return true
	return false


## The man who went in calls it once he's had a look round.
static func clear_call_tick(q: Squad) -> void:
	if q.clear_call.is_empty() or q.world.time < float(q.clear_call[1]):
		return
	var s: Soldier = q.clear_call[0]
	q.clear_call = []
	if s == null or not is_instance_valid(s) or s.gone or s.life != Soldier.Life.ALIVE:
		return
	if s.vis_targets.is_empty():
		s.say(_pick(q, ["Clear!", "Room clear!", "Clear! Next room!", "Building clear!"]) if q.team == 0 else _pick(q, ["Empty!", "Nobody here!", "Clear!"]), true)
		q.world.stat("house_cleared")


# --- near ambush ---------------------------------------------------------------------

## Caught at close range by more fire than lying down will survive, a steady
## squad assaults straight into the ambush - the drill is to get out of the
## killing zone, and the only way out is through them.
static func near_ambush(q: Squad, threat: Dictionary) -> bool:
	if threat.is_empty() or q.morale < SquadBrain.STEADY or q.kind in ["crew", "r_crew"]:
		return false
	var alive := q.alive_members()
	if alive.size() < 3:
		return false
	var c := q.centroid()
	if Defs.flat(threat.pos - c).length() > 32.0:
		return false
	var them := 0
	for k in q.known.values():
		if q.world.time - float(k.t) < 4.0 and Defs.flat(k.pos - c).length() < 60.0:
			them += 1
	if them > alive.size():
		return false  # too many of them to go through
	q.order_assault(q.world.nav.nearest_walkable(threat.pos), Defs.flat(threat.pos - c).normalized(), false)
	SquadBrain._say(q, ["Near ambush! Assault through! Go, go, go!", "Ambush! Into them, move!", "Get out of the kill zone - assault!"]
		if q.team == 0 else ["Ambush! At them!", "Charge them! Go!"])
	q.world.send_msg(q.team, "alert", "%s ambushed - assaulting through!" % q.display_name(), c)
	q.world.stat("near_ambush_assault")
	return true


# --- stragglers and crews ------------------------------------------------------------

## The last man standing of a squad attaches himself to the nearest friendly
## squad rather than fight on alone.
static func straggler_tick(q: Squad) -> void:
	if q.world.time < float(q.bt_cd.get("straggle", -1.0)) or q.kind in ["crew", "r_crew"]:
		return
	q.bt_cd["straggle"] = q.world.time + 2.0
	var alive := q.alive_members()
	if alive.size() != 1 or q.members.size() < 2:
		return
	for m in q.members:
		if not m.gone and (m.life == Soldier.Life.DOWNED or m.life == Soldier.Life.HIDDEN):
			return  # there's still someone to look after
	var s: Soldier = alive[0]
	if s.task != "" or s.mounted != null or s.riding != null or not s.can_take_orders():
		return
	var best: Squad = null
	var bd := 80.0
	for o in q.world.squads.values():
		if o == q or o.owner != q.owner or o.team != q.team or o.kind in ["crew", "r_crew"] or o.drill == "rout" or o.members.size() >= 9:
			continue
		var oa: Array = o.alive_members()
		if oa.size() < 2:
			continue
		var d: float = Defs.flat(o.centroid() - s.position).length()
		if d < bd:
			bd = d
			best = o
	if best == null:
		return
	var old := q.display_name()
	q.remove(s)
	best.add(s)
	var lead: Soldier = best.get_leader()
	var at: Vector3 = lead.position if lead else best.centroid()
	s.hold_pos = q.world.nav.nearest_walkable(at + Defs.flat(s.position - at).normalized() * 3.0)
	s.hold_face = best.facing
	s.leash = 7.0
	s.at_cover = false
	s.next_cover_eval = 0.0
	s.go_to(s.hold_pos, "slot", 1)
	s.say(_pick(q, ["I'm all that's left! I'm with you!", "They got my whole squad... I'm with you guys.", "Mind if I tag along?"]) if q.team == 0
		else _pick(q, ["My brothers are dead! I fight with you!", "I'm with you now!"]), true)
	if lead:
		lead.say(_pick(q, ["Get in here! Take the left.", "On me. Watch our flank.", "Good to have you."]), false)
	q.world.send_msg(q.team, "info", "The last man of %s has joined %s." % [old, best.display_name()], s.position)
	q.world.stat("straggler_joined")


## A crew that bailed out heads back to the nearest FOB (unless someone has
## given it other orders); once there the men go back to the vehicle park.
static func crew_tick(q: Squad) -> void:
	if not q.kind in ["crew", "r_crew"] or q.world.time < float(q.bt_cd.get("crew", -1.0)):
		return
	q.bt_cd["crew"] = q.world.time + 1.0
	var alive := q.alive_members()
	if alive.is_empty():
		return
	var c := q.centroid()
	var f: Structure = q.world.rules.nearest_fob(q.team, c)
	if f == null:
		return
	var own := q.order_n == int(q.bt_cd.get("crew_n", q.order_n))
	if Defs.flat(f.position - c).length() < 16.0 and not q.in_combat():
		var refund: int = int(q.bt_cd.get("refund", 0))
		f.supply += refund
		f.net_dirty = true
		q.world.send_msg(q.team, "info", "%s is back at %s - they'll crew the next one." % [q.display_name(), f.display_name()], f.position)
		q.world.stat("crew_home")
		for m in q.members.duplicate():
			if is_instance_valid(m) and not m.gone and m.life == Soldier.Life.ALIVE:
				q.remove(m)
				q.world.despawn(m)
		return
	if own and q.drill == "" and (q.order != "move" or Defs.flat(q.order_pos - f.position).length() > 20.0):
		q.order_move(q.world.nav.nearest_walkable(f.position + Defs.flat(c - f.position).normalized() * 8.0), Defs.flat(f.position - c).normalized(), 2)
		q.bt_cd["crew_n"] = q.order_n
