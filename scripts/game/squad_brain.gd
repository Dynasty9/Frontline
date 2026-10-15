class_name SquadBrain
extends RefCounted
## A squad's battle drills, as a behaviour tree (see BT) walked twice a second,
## most urgent first:
##   - routed: a squad whose nerve has gone runs for the rear and won't take
##     orders until it has rallied;
##   - react to indirect fire: rounds landing on it and it isn't dug in - out
##     of the impact area, fast, sideways or back from the enemy, never into it;
##   - break contact: losing its nerve (or, for the AI, cut up and outnumbered) -
##     smoke between, then back by bounds to a rally point, one team firing
##     while the other moves;
##   - react to contact on the move: fired on, or a new enemy in sight, while
##     it's moving - down, return fire, the leader calls it (direction and
##     range); once it has the upper hand it carries on, by bounds while the
##     enemy is still about.
## Underneath it all runs morale (cohesion): casualties, fire it can't answer,
## tanks it can't fight and losing its leader wear it down; quiet, a leader,
## friends close by and a hole in the ground build it back. A shaken squad
## shoots worse and is pinned sooner; a breaking one pulls out; a broken one runs.

const STEADY := 55.0
const SHAKEN := 33.0  # below this the squad is breaking: it pulls out of the fight
const ROUT := 12.0  # below this it runs
const RALLY := 45.0  # a routed squad has pulled itself together

static var _tree: BT.Branch = null


static func tree() -> BT.Branch:
	if _tree == null:
		_tree = _build()
	return _tree


static func think(q: Squad) -> void:
	tree().tick(q)


static func _build() -> BT.Branch:
	return BT.sel("squad", [
		BT.seq("routed", [BT.cond("running", func(q): return q.drill == "rout"), BT.act("run, or rally", func(q): return rout_tick(q))]),
		BT.seq("rout", [BT.cond("nerve gone", func(q): return should_rout(q)), BT.act("run for it", func(q): return start_rout(q))]),
		BT.seq("indirect fire", [BT.cond("shells landing on us", func(q): return shells_on_us(q)), BT.act("out of the impact area", func(q): return displace(q))]),
		BT.seq("displacing", [BT.cond("displacing", func(q): return q.drill == "displace"), BT.act("get there, then hold", func(q): return displace_tick(q))]),
		BT.seq("break contact", [BT.cond("outmatched", func(q): return should_break(q)), BT.act("smoke, fall back by bounds", func(q): return start_withdraw(q))]),
		BT.seq("withdrawing", [BT.cond("withdrawing", func(q): return q.drill == "withdraw"), BT.act("back by bounds", func(q): return withdraw_tick(q))]),
		BT.seq("react to contact", [BT.cond("contact on the move", func(q): return contact_on_the_move(q)), BT.act("down, return fire, call it", func(q): return react_to_contact(q))]),
		BT.seq("carry on", [BT.cond("the upper hand", func(q): return can_resume(q)), BT.act("move on", func(q): return resume(q))]),
		BT.seq("clear the houses", [BT.cond("houses on our ground", func(q): return Tactics.can_clear(q)), BT.act("stack, kick, clear", func(q): return Tactics.start_clear(q))]),
	])


static func _pick(q: Squad, arr: Array) -> String:
	return arr[q.world.rng.randi() % arr.size()]


static func _speaker(q: Squad) -> Soldier:
	var ld := q.get_leader()
	if ld:
		return ld
	var a := q.alive_members()
	return a[0] if not a.is_empty() else null


static func _say(q: Squad, arr: Array) -> void:
	var s := _speaker(q)
	if s:
		s.say(_pick(q, arr), true)


static func avg_supp(alive: Array) -> float:
	if alive.is_empty():
		return 0.0
	var t := 0.0
	for m in alive:
		t += m.suppression
	return t / alive.size()


## Where the enemy is from the squad: towards what it knows of, else its front.
static func enemy_dir(q: Squad) -> Vector3:
	var c := q.centroid()
	var d := Vector3.ZERO
	for p in q.threat_points(c, 3):
		d += Defs.flat(p - c).normalized()
	if d.length() < 0.1:
		return q.facing
	return d.normalized()


static func _near_fob(q: Squad, r: float) -> bool:
	var f: Structure = q.world.rules.nearest_fob(q.team, q.centroid())
	return f != null and Defs.flat(f.position - q.centroid()).length() < r


static func _enemies_near(q: Squad, r: float) -> int:
	var c := q.centroid()
	var n := 0
	for k in q.known.values():
		var e = k.e
		if e is Soldier and not e.gone and e.life == Soldier.Life.ALIVE and q.world.time - float(k.t) < 12.0 and Defs.flat(k.pos - c).length() < r:
			n += 1
	return n


# --- morale --------------------------------------------------------------------------

static func base_morale(q: Squad) -> float:
	return 78.0 if q.team == 0 else 72.0


static func state(morale: float, routed := false) -> int:
	if routed or morale < ROUT:
		return 3
	if morale < SHAKEN:
		return 2
	if morale < STEADY:
		return 1
	return 0


const STATE_NAMES := ["Steady", "Shaken", "Breaking", "Routed"]


static func _armour_threat(q: Squad, alive: Array) -> bool:
	for m in alive:
		if m.rockets > 0 or m.utype in ["at_soldier", "rpg"]:
			return false  # something to fight it with
	var c := q.centroid()
	for v in q.world.vehicles_near(c, 70.0):
		if v.team != q.team and v.team >= 0 and not v.gone and int(v.vdef.get("armor", 0)) >= 1 and v.visible_to_team(q.team):
			return true
	return false


static func _friends_near(q: Squad, r: float) -> int:
	var c := q.centroid()
	var n := 0
	for o in q.world.squads.values():
		if o == q or o.team != q.team or o.drill == "rout" or o.alive_members().is_empty():
			continue
		if Defs.flat(o.centroid() - c).length() < r:
			n += 1
	for v in q.world.vehicles_near(c, r):
		if v.team == q.team and not v.gone and int(v.vdef.get("armor", 0)) >= 1:
			n += 1  # a tank alongside steadies anyone
	return n


## Twice a second: fire it can't answer, enemy armour, no leader and being
## alone wear it down; out of contact (or barely shot at) with a leader and
## friends about it comes back, up to what it started with. Dug in, or behind
## something solid, it takes the strain better.
static func morale_tick(q: Squad, dt: float) -> void:
	var alive := q.alive_members()
	if alive.is_empty():
		return
	var supp := avg_supp(alive)
	var dug := 0
	for m in alive:
		if m._gy < -0.6 or (m.at_cover and m.cover_mat >= Cover.HARD):
			dug += 1
	var contact := q.in_combat()
	var drain := 0.0
	if supp > 30.0:
		drain += (supp - 30.0) / 70.0 * 1.4
	if _armour_threat(q, alive):
		drain += 0.9
	var ld = q.leader
	var led: bool = ld != null and is_instance_valid(ld) and not ld.gone and ld.life == Soldier.Life.ALIVE
	if not led:
		drain += 0.2
	if dug * 2 >= alive.size():
		drain *= 0.5
	elif q.plan != null and q.plan.support_set:
		drain *= 0.7  # going in under covering fire: the guns on their side steady them
	var friends := _friends_near(q, 45.0)
	if friends == 0 and contact:
		drain += 0.15
	var rec := 0.0
	if not contact:
		rec = 1.4 + (0.8 if _near_fob(q, 45.0) else 0.0)
	elif supp < 15.0:
		rec = 0.35
	if led:
		rec *= 1.25
	rec += 0.2 * mini(friends, 3)
	var b := base_morale(q)
	var m2 := q.morale - drain * dt
	if m2 < b:
		m2 = minf(b, m2 + rec * dt)
	elif not contact:
		m2 = maxf(b, m2 - 0.15 * dt)  # the elation of a won fight wears off
	q.morale = clampf(m2, 0.0, 100.0)


## A man of the squad hit: wounded hurts, killed hurts more, the leader most.
static func casualty(q: Squad, s: Soldier) -> void:
	var hit := 0.0
	if s.life == Soldier.Life.DOWNED:
		hit = 7.0
	elif s.life == Soldier.Life.DEAD:
		hit = 4.0 if s.times_downed > 0 or s.downed_t > 0.0 else 10.0
	if q.leader == s or (q.leader == null and q.members.find(s) == 0):
		hit += 6.0
	q.morale = maxf(0.0, q.morale - hit)
	q.last_cas_t = q.world.time


# --- routed --------------------------------------------------------------------------

static func should_rout(q: Squad) -> bool:
	return q.morale < ROUT and not q.alive_members().is_empty() and (q.in_combat() or q.world.time - q.last_cas_t < 20.0)


static func start_rout(q: Squad) -> int:
	q.order_retreat()
	if q.order != "move":  # nowhere to run to: back, away from them
		var c := q.centroid()
		q.order_move(q.world.nav.nearest_walkable(c - enemy_dir(q) * 90.0), -enemy_dir(q), 2)
	q.drill = "rout"
	q.drill_t = q.world.time
	q.shown_order = "rout"
	_say(q, ["Run! Get out of here!", "We can't hold! Go, go!", "Leave it! Run!", "Fall back! Fall back!"])
	q.world.send_msg(q.team, "alert", "%s is routing!" % q.display_name(), q.centroid())
	q.world.stat("squad_rout")
	return BT.OK


static func rout_tick(q: Squad) -> int:
	# the fear wears off out of contact, or back among friends
	if q.morale > RALLY or (q.morale > 30.0 and not q.in_combat() and _near_fob(q, 40.0)):
		q.drill = ""
		var c := q.centroid()
		q.order_defend(q.world.nav.nearest_walkable(c), enemy_dir(q))
		_say(q, ["Alright... alright. On me, form up!", "Get a grip! Form on me!", "Enough running. We hold here."])
		q.world.send_msg(q.team, "info", "%s has rallied." % q.display_name(), c)
		q.world.stat("squad_rally")
	return BT.OK


# --- react to indirect fire ----------------------------------------------------------------

static func shells_on_us(q: Squad) -> bool:
	if q.drill in ["rout", "withdraw", "displace"] or q.world.time < q.displace_cd:
		return false
	if q.plan != null and String(q.plan.phase) == "assault":
		return false  # going in: push through it
	var c := q.centroid()
	var keep := []
	var n := 0
	for im in q.impacts:
		if q.world.time - float(im[1]) < 20.0:
			keep.append(im)
			if Defs.flat(im[0] - c).length() < 32.0:
				n += 1
	q.impacts = keep
	if n < 2:
		return false
	# dug in: stay down in the hole and let it pass over
	var alive := q.alive_members()
	var dug := 0
	for m in alive:
		if m._gy < -0.6:
			dug += 1
	return not alive.is_empty() and dug * 2 < alive.size()


static func displace(q: Squad) -> int:
	var c := q.centroid()
	var ic := Vector3.ZERO
	for im in q.impacts:
		ic += im[0]
	ic /= maxf(1.0, q.impacts.size())
	var ed := enemy_dir(q)
	var best := Vector3.INF
	var bs := -1e9
	for i in 12:
		var a := TAU * i / 12.0
		var dir := Vector3(sin(a), 0, cos(a))
		var p := q.world.nav.nearest_walkable(c + dir * 55.0)
		if not Defs.in_map(p, 10.0):
			continue
		var s := Defs.flat(p - ic).length() - maxf(0.0, dir.dot(ed)) * 45.0
		s += float(q.world.terrain.cov[q.world.terrain.idx_of(p)]) * 4.0
		if s > bs:
			bs = s
			best = p
	if best == Vector3.INF:
		return BT.FAIL
	q.pre_order = [q.order, q.order_pos, q.facing, q.move_mode_ord]
	q.order_move(best, ed, 2)
	q.drill = "displace"
	q.drill_t = q.world.time
	q.drill_pos = best
	q.displace_cd = q.world.time + 45.0
	q.shown_order = "displace"
	_say(q, ["Incoming! Out of the impact area, move!", "They've got us zeroed! Move, move!", "Arty! Get out of here, go!", "Shells! Move it, move it!"])
	q.world.send_msg(q.team, "info", "%s is moving out of the shellfire." % q.display_name(), best)
	q.world.stat("displace")
	return BT.OK


static func displace_tick(q: Squad) -> int:
	var moving := false
	for m in q.alive_members():
		if m.is_moving():
			moving = true
			break
	if (moving and q.world.time - q.drill_t < 40.0) or q.world.time - q.drill_t < 12.0:
		return BT.FAIL  # (the wounded, the medics and the rest carry on meanwhile)
	# out of it: once it has lifted, back to what they were doing
	q.drill = ""
	var pre: Array = q.pre_order
	var o := String(pre[0]) if not pre.is_empty() else ""
	var hot := not pre.is_empty() and q.world.impacts_near(pre[1], 35.0, 15.0) > 0
	if o == "move" and not hot:
		q.order_move(pre[1], pre[2], int(pre[3]))
	elif o == "assault":
		q.order_assault(pre[1], pre[2], false)  # an attack goes on, shells or no shells
	elif o == "defend" and not hot:
		q.order_defend(pre[1], pre[2])
		_say(q, ["It's lifted. Back to the line!", "Back to your positions!"])
	else:
		q.order_defend(q.drill_pos, enemy_dir(q))
	return BT.FAIL


# --- break contact ---------------------------------------------------------------------

static func should_break(q: Squad) -> bool:
	if q.drill in ["rout", "withdraw"] or q.shown_order == "retreat" or not q.in_combat():
		return false
	var alive := q.alive_members()
	if alive.is_empty():
		return false
	if q.plan != null and q.morale >= 22.0:
		return false  # the attack has its own fall-back
	if q.order == "defend" and _near_fob(q, 40.0):
		return false  # holding our own base: there's no further back
	for m in alive:
		if m.mounted != null:
			return q.morale < ROUT + 6.0  # a crew stays on its gun till the very end
	if q.morale < SHAKEN:
		return true
	if q.owner >= 0 or q.members.size() < 4 or q.order == "defend":
		return false  # a player's squad (or a team, or a line) that still has its nerve stays until told
	return alive.size() * 2 <= q.members.size() and _enemies_near(q, 110.0) >= alive.size() * 2


static func start_withdraw(q: Squad) -> int:
	var c := q.centroid()
	var ed := enemy_dir(q)
	var rally := c - ed * 75.0
	var f: Structure = q.world.rules.nearest_fob(q.team, c)
	if f and Defs.flat(f.position - c).length() < 220.0 and Defs.flat(f.position - c).normalized().dot(-ed) > 0.2:
		rally = f.position + ed * 12.0
	rally = q.world.nav.nearest_walkable(rally)
	q._regroup()
	q.order = "withdraw"
	q.order_pos = rally
	q.facing = ed
	q.shown_order = "retreat"
	q.drill = "withdraw"
	q.drill_t = q.world.time
	q.bound_team = 0
	q.bound_t = 0.0
	_smoke_screen(q, ed)
	var near: Dictionary = q._nearest_threat(c, 150.0)
	if not near.is_empty():
		q.cover_fire_pos = near.pos
		q.cover_fire_until = q.world.time + 6.0
	_say(q, ["Break contact! Smoke out, fall back by teams!", "Pull back! Bounding back, go!", "Too many of them! Fall back, covering fire!"])
	q.world.send_msg(q.team, "info", "%s is breaking contact." % q.display_name(), c)
	q.world.stat("break_contact")
	return BT.OK


## A smoke grenade between the squad and the enemy, from whoever has one.
static func _smoke_screen(q: Squad, ed: Vector3) -> void:
	var c := q.centroid()
	var best: Soldier = null
	var bd := 1e9
	for m in q.alive_members():
		if m.smokes <= 0 or not m.can_take_orders() or m.task != "":
			continue
		var d := -Defs.flat(m.position - c).dot(ed)
		if d < bd:
			bd = d
			best = m
	if best:
		best.cmd_throw(best.position + ed * 14.0, "smoke")


static func withdraw_tick(q: Squad) -> int:
	var alive := q.alive_members()
	if alive.is_empty():
		return BT.OK
	var c := q.centroid()
	var ed := enemy_dir(q)
	q.facing = ed
	var there := Defs.flat(q.order_pos - c).length() < 8.0
	if there or (q.world.time - q.drill_t > 25.0 and not q.in_combat()) or q.world.time - q.drill_t > 120.0:
		q.drill = ""
		q.order_defend(q.order_pos if there else q.world.nav.nearest_walkable(c), ed)
		_say(q, ["We're clear! Count off, check your ammo!", "Hold here! Reload, watch your front!", "Alright, we're out. Get your breath."])
		q.world.stat("withdraw_done")
		return BT.OK
	# one team moves back while the other keeps their heads down
	var moving := false
	for m in alive:
		if not m.detached and m.goal_kind == "slot" and m.is_moving():
			moving = true
			break
	if moving and q.world.time < q.bound_t:
		return BT.OK
	var near: Dictionary = q._nearest_threat(c, 150.0)
	if not near.is_empty():
		q.cover_fire_pos = near.pos
		q.cover_fire_until = q.world.time + 6.0
	q._next_bound(20.0)
	return BT.OK


# --- react to contact -------------------------------------------------------------------

static func contact_on_the_move(q: Squad) -> bool:
	if q.order != "move" or q.drill != "" or q.plan != null or q.shown_order != "" or q.move_mode_ord >= 2:
		return false
	var c := q.centroid()
	if Defs.flat(q.order_pos - c).length() < 15.0:
		return false
	var alive := q.alive_members()
	if alive.is_empty():
		return false
	for m in q.members:
		if m.riding != null:
			return false  # mounted: the driver's problem
	if avg_supp(alive) > 28.0:
		return true  # fired on
	for id in q.known:
		if q.known_at_order.has(id):
			continue
		var k: Dictionary = q.known[id]
		var e = k.e
		if q.world.time - float(k.t) > 2.0 or e.gone or (e is Soldier and e.life != Soldier.Life.ALIVE):
			continue
		if Defs.flat(k.pos - c).length() < 220.0:
			return true  # a new enemy in sight
	return false


static func react_to_contact(q: Squad) -> int:
	var c := q.centroid()
	var ed := enemy_dir(q)
	q.halt_then = q.then_defend
	if Tactics.near_ambush(q, q._nearest_threat(c, 40.0)):
		return BT.OK
	q.technique = ""
	q.halt_dest = q.order_pos
	q.halt_face = q.facing
	q.halt_mode = q.move_mode_ord
	q.travel = false
	q.order = "hold"
	q.shown_order = "contact"
	q.drill = "contact"
	q.drill_t = q.world.time
	for m in q.members:
		if m.can_take_orders() and not m.detached and m.task == "":
			m.cmd_halt(ed)
	var near: Dictionary = q._nearest_threat(c, 250.0)
	var tp: Vector3 = near.pos if not near.is_empty() else c + ed * 100.0
	if not near.is_empty():
		q.cover_fire_pos = near.pos
		q.cover_fire_until = q.world.time + 8.0
	var s := _speaker(q)
	if s:
		var rng := maxi(25, int(round(Defs.flat(tp - s.position).length() / 25.0) * 25.0))
		var dirn := Defs.compass(s.position, tp)
		s.say(_pick(q, ["Contact! %s, %d metres!" % [dirn.capitalize(), rng], "Contact %s! %d metres, return fire!" % [dirn, rng],
			"Enemy %s, %d metres! Get down!" % [dirn, rng]]), true)
	q.world.stat("react_to_contact")
	return BT.OK


## Once the enemy's fire has slackened - or they've gone - the squad carries on.
static func can_resume(q: Squad) -> bool:
	if q.drill != "contact" or q.world.time - q.drill_t < 8.0:
		return false
	var alive := q.alive_members()
	if alive.is_empty() or avg_supp(alive) > 18.0:
		return false
	var seen := false
	for k in q.known.values():
		var e = k.e
		if q.world.time - float(k.t) < 6.0 and not e.gone and not (e is Soldier and e.life != Soldier.Life.ALIVE):
			seen = true
			break
	return not seen or q.world.time - q.drill_t > 25.0


static func resume(q: Squad) -> int:
	var dest := q.halt_dest
	q.drill = ""
	if not q._nearest_threat(q.centroid(), 160.0).is_empty():
		# still about: on by bounds, one team covering the other
		q.order_assault(dest, q.halt_face, false)
	else:
		q.order_move(dest, q.halt_face, q.halt_mode)
		q.then_defend = q.halt_then
	q.world.stat("contact_resume")
	return BT.OK


# --- fire discipline ---------------------------------------------------------------------

## How close they let them come before they open up.
const AMBUSH_R := 38.0


## A squad lying in wait holds its fire until the enemy is close (or several
## of them are in the open and coming on), then the leader springs it and
## everyone fires at once. Fired on first, or hit, it fires back at once.
static func ambush_tick(q: Squad) -> void:
	if not q.ambush:
		return
	var alive := q.alive_members()
	if alive.is_empty():
		q.ambush = false
		return
	var spring := avg_supp(alive) > 8.0 or q.world.time - q.last_cas_t < 3.0
	var close := 999.0
	var seen := 0
	for m in alive:
		if m.target != null and m._target_valid(m.target) and not (m.target is Structure):
			seen += 1
			close = minf(close, Defs.flat(m.target.position - m.position).length())
		if m.forced_target != null:
			spring = true
	if close < AMBUSH_R or (seen >= 3 and close < AMBUSH_R * 1.4):
		spring = true
	if not spring:
		return
	q.ambush = false
	if seen > 0:
		q.ambush_t = q.world.time + 4.0
		_say(q, ["FIRE!", "Now! Open fire!", "Hit them!", "Light them up!"] if q.team == 0 else ["NOW! Fire!", "Kill them!", "Fire, fire!"])
		q.world.stat("ambush")


# --- the everyday business ---------------------------------------------------------------

## Men short of ammunition get some from a mate beside them: a magazine, or a
## belt's worth for the gun.
static func share_ammo(q: Squad) -> void:
	if q.world.time < q.ammo_t:
		return
	q.ammo_t = q.world.time + 5.0
	var alive := q.alive_members()
	for m in alive:
		if m.wdef.is_empty() or int(m.wdef.ammo) >= 9000 or m.task != "" or m.suppression > 70.0:
			continue
		var full := int(m.wdef.ammo)
		if m.total_ammo() > full * 0.3:
			continue
		for d in alive:
			if d == m or d.wdef.is_empty() or int(d.wdef.ammo) >= 9000 or d.task != "":
				continue
			var dfull := int(d.wdef.ammo)
			if d.total_ammo() < dfull * 0.6 or d.reserve < int(dfull * 0.2) or Defs.flat(d.position - m.position).length() > 9.0:
				continue
			d.reserve -= int(dfull * 0.15)
			m.reserve += int(full * 0.15)
			m.out_said = false
			m.low_ammo_said = false
			m.say(_pick(q, ["Ammo! Throw me a mag!", "I'm low! Mags!", "Anyone got a mag?"]), false)
			d.say(_pick(q, ["Here, catch!", "Mag! Make it count!", "Take these."]), false)
			q.world.stat("ammo_shared")
			if m.mag <= 0:
				m._start_reload()
			break
