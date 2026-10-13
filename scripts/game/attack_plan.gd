class_name AttackPlan
extends RefCounted
## A deliberate attack, the way an infantry squad or platoon is taught to do it:
##
##  1. PLAN    - the leader halts, reads the ground and gives his orders.
##  2. MOVE    - the support element (the machine guns and a fire team, or a
##               whole squad) moves to a support-by-fire position with a view
##               of the objective; the assault element moves along a covered
##               route out to a flank, to an assault position close to it.
##  3. FIX     - support sets and opens fire; the assault element waits at its
##               assault position until the enemy's heads are down.
##  4. ASSAULT - the assault element closes in short rushes, buddy team by
##               buddy team, one moving while the other fires; grenades at the
##               last bound. As they get close, support shifts its fire beyond
##               the objective so it doesn't hit them, then lifts.
##  5. CONSOLIDATE - on the objective everyone takes up all-round defence and
##               the support element comes forward.
##
## Elements are lists of {sq, team}: a whole squad (team -1) when several squads
## attack together, or one fire team of a squad (team 0 / 1) when a squad
## attacks on its own. If the assault is cut up or pinned it falls back to the
## assault position and fights from there until it can go again.

var world
var team := 0
var objective := Vector3.ZERO
var axis := Vector3.FORWARD  # direction of the attack
var side := 1.0  # which flank the assault goes round (+1 right of the axis)
var support: Array = []  # [{sq, team}]
var assault: Array = []
var sbf := Vector3.ZERO  # support-by-fire position
var ap := Vector3.ZERO  # assault position
var phase := "plan"
var phase_t := 0.0
var fire_at := Vector3.ZERO
var support_set := false
var shifted := false
var _rush_group := 0
var _rush_t := 0.0
var _start_n := 0
var _pinned_t := 0.0
var _clear_t := 0.0
var _said := {}
var done := false
var _tick_t := -1.0
var _smoked := false


static func make(w, sqs: Array, obj: Vector3, face: Vector3) -> AttackPlan:
	if OS.has_environment("FL_NO_PLAN"):
		return null
	var live := []
	for sq in sqs:
		if sq.alive_members().size() > 0:
			live.append(sq)
	if live.is_empty():
		return null
	var p := AttackPlan.new()
	p.world = w
	p.team = live[0].team
	p.objective = obj
	var c := Vector3.ZERO
	for sq in live:
		c += sq.centroid()
	c /= live.size()
	var d := Defs.flat(obj - c)
	p.axis = d.normalized() if d.length() > 1.0 else (face if face.length() > 0.1 else Vector3.FORWARD)
	if live.size() >= 2:
		# the squad with the most firepower (or the one nearest the axis) is the base of fire
		var best = live[0]
		var bs := -1e9
		for sq in live:
			var sc := 0.0
			for m in sq.alive_members():
				sc += 3.0 if m.utype in ["mg_gunner", "pkm"] else 1.0
			sc -= Defs.flat(sq.centroid() - c).length() * 0.02
			if sc > bs:
				bs = sc
				best = sq
		p.support.append({"sq": best, "team": -1})
		for sq in live:
			if sq != best:
				p.assault.append({"sq": sq, "team": -1})
	else:
		var sq = live[0]
		var alive: Array = sq.alive_members()
		if alive.size() < 4:
			return null
		_split_fire_teams(sq)
		p.support.append({"sq": sq, "team": 0})
		p.assault.append({"sq": sq, "team": 1})
	for e in p.support + p.assault:
		e.sq.plan = p
	p._start_n = p._members(p.assault).size()
	p._choose_ground(c)
	return p


## Alpha: the automatic weapons and half the riflemen (the base of fire).
## Bravo: the leader and the rest (the assault). Medics and AT go with Bravo.
static func _split_fire_teams(sq) -> void:
	var alive: Array = sq.alive_members()
	var ld = sq.get_leader()
	var a := []
	var b := []
	for m in alive:
		if m.utype in ["mg_gunner", "pkm"]:
			a.append(m)
		elif m == ld or m.utype in ["medic", "r_medic", "at_soldier", "rpg"]:
			b.append(m)
	for m in alive:
		if m in a or m in b:
			continue
		if a.size() <= b.size():
			a.append(m)
		else:
			b.append(m)
	for m in a:
		m.fteam = 0
	for m in b:
		m.fteam = 1


func _members(elems: Array) -> Array:
	var out := []
	for e in elems:
		if e.sq.plan != self:
			continue
		for m in e.sq.alive_members():
			if m.detached or not m.can_take_orders() and m.task != "":
				continue
			if int(e.team) >= 0 and m.fteam != int(e.team):
				continue
			out.append(m)
	return out


func _centroid(ms: Array) -> Vector3:
	if ms.is_empty():
		return objective
	var c := Vector3.ZERO
	for m in ms:
		c += m.position
	return c / ms.size()


## Picks the support-by-fire position (back along the axis, in cover, with a
## view of the objective) and the flank to assault from: the side with more
## cover and concealment and less known enemy fire.
func _choose_ground(start: Vector3) -> void:
	var dist := Defs.flat(objective - start).length()
	var back := clampf(dist * 0.55, 28.0, 60.0)
	if dist < 32.0:
		back = dist
	var lat := axis.cross(Vector3.UP)
	var best := -1e9
	# which side each element already stands on: the assault flanks on its own
	# side and the base of fire sets up on the other, so their routes don't cross
	var spread := (_centroid(_members(assault)) - _centroid(_members(support))).dot(lat)
	for s in [-1.0, 1.0]:
		var cand: Vector3 = objective - axis * 16.0 + lat * float(s) * 22.0
		cand = world.nav.nearest_walkable(cand)
		var sc := clampf(spread * float(s) / 6.0, -3.0, 3.0)
		if not Defs.in_map(cand, 8.0):
			sc -= 100.0
		sc += float(world.terrain.cover_vs(cand, objective)) * 2.0
		var mid := start.lerp(cand, 0.5)
		if world.terrain.kind_at(mid) == TerrainMap.WOODS:
			sc += 2.0
		sc += float(world.terrain.cover_vs(mid, objective))
		# keep away from where we know the enemy is shooting from
		for e in support + assault:
			for k in e.sq.known.values():
				var kp: Vector3 = k.pos
				if Defs.flat(kp - objective).length() < 50.0:
					sc -= 8.0 / maxf(4.0, Defs.flat(kp - cand).length()) * 4.0
		sc += world.rng.randf_range(0.0, 0.6)
		if sc > best:
			best = sc
			side = s
	ap = world.nav.nearest_walkable(objective - axis * 16.0 + lat * side * 22.0)
	# already trading fire: the element in contact is the base of fire, right
	# where it is - it doesn't get up and walk forward to set up
	var sc0 := _centroid(_members(support))
	if _contact() and Defs.flat(objective - sc0).length() < 80.0:
		sbf = sc0
		return
	# otherwise the best covered spot back along the axis (off to the other
	# side, so its fire crosses the assault's path at an angle) that can see
	# the objective
	sbf = world.nav.nearest_walkable(objective - axis * back - lat * side * minf(10.0, back * 0.2))
	var bsc := -1e9
	for r in [28.0, 38.0, 48.0, 58.0]:
		if r > dist + 4.0:
			continue
		for deg in [0.0, 12.0, 24.0, 36.0]:
			var dirc: Vector3 = (-axis).rotated(Vector3.UP, deg_to_rad(float(deg)) * -side)
			var cand: Vector3 = world.nav.nearest_walkable(objective + dirc * r)
			if not Defs.in_map(cand, 6.0):
				continue
			var sc: float = float(world.terrain.cover_vs(cand, objective)) * 3.0 - float(r) * 0.03 - float(deg) * 0.01
			if world.terrain.kind_at(cand) == TerrainMap.WOODS:
				sc += 1.0
			if not world.combat.clear_line(cand + Vector3(0, 1.4, 0), objective + Vector3(0, 1.0, 0)):
				sc -= 2.5  # can't see it from there
			if sc > bsc:
				bsc = sc
				sbf = cand


func _fire_target() -> Vector3:
	var pts := []
	for e in support + assault:
		for k in e.sq.known.values():
			if Defs.flat((k.pos as Vector3) - objective).length() < 45.0 and world.time - float(k.t) < 30.0:
				pts.append(k.pos)
	if pts.is_empty():
		return objective + Vector3(0, 0.5, 0)
	var c := Vector3.ZERO
	for p in pts:
		c += p
	return c / pts.size()


func _place(ms: Array, at: Vector3, face: Vector3, mode: int, wide := true) -> void:
	if ms.is_empty():
		return
	var slots: Array = world.terrain.slots(at, face, ms.size(), wide)
	var free := []
	for sl in slots:
		free.append(world.nav.nearest_walkable(sl[0]))
	for m in ms:
		var bi := 0
		var bd := 1e9
		for i in free.size():
			var d: float = Defs.flat(free[i] - m.position).length()
			if d < bd:
				bd = d
				bi = i
		m.cmd_move(free[bi], mode, face)
		m.leash = 4.5
		free.remove_at(bi)


func _arrived(ms: Array, frac := 0.6) -> bool:
	if ms.is_empty():
		return true
	var n := 0
	for m in ms:
		if not (m.goal_kind == "slot" and m.is_moving()):
			n += 1
	return n >= ceili(ms.size() * frac)


func _say(key: String, ms: Array, lines: Array) -> void:
	if _said.has(key) or ms.is_empty():
		return
	_said[key] = true
	var who = ms[0]
	for m in ms:
		if (m.flags & Soldier.F_LEADER) != 0:
			who = m
	who.say(lines[world.rng.randi() % lines.size()], true)


func _contact() -> bool:
	for e in support + assault:
		if e.sq.in_combat():
			return true
	return false


# --- the attack ------------------------------------------------------------------------

func tick() -> void:
	if done or world.time - _tick_t < 0.45:
		return
	_tick_t = world.time
	var sup := _members(support)
	var asl := _members(assault)
	if asl.is_empty() and sup.is_empty():
		_finish(false)
		return
	var t: float = world.time
	fire_at = _fire_target()
	match phase:
		"plan":
			if phase_t == 0.0:
				phase_t = t
				var lr := "right" if side > 0.0 else "left"
				var whole: bool = int(support[0].team) < 0
				_say("plan", sup + asl, [
					("%s, base of fire on the objective! %s, with me, we go %s!" % [_name(support), _name(assault), lr]) if whole else ("Alpha, base of fire! Bravo on me, we flank %s!" % lr),
					"Listen up: guns set up there and fix them, the rest of us hook round the %s!" % lr,
					"Support by fire from that position. Assault team, %s flank, on me!" % lr])
				for m in sup + asl:
					m.stop_moving()
			elif t - phase_t > 2.0:
				# outnumbered: an attack would be suicide - fix them from cover and wait for help
				var foes := _known_defenders()
				if foes > 0 and (sup.size() + asl.size()) < foes * 1.4:
					_set_phase("fix")
					_say("fix", sup + asl, ["Too many of them! We hold here and fix them, need support!", "They outnumber us! Go firm, keep them pinned!", "Can't take that alone. Base of fire, everyone, call it in!"])
					_place(sup + asl, _centroid(sup + asl), axis, 1 if _contact() else 0, true)
					return
				_set_phase("move")
				var mode := 1 if _contact() else 0
				_place(sup, sbf, Defs.flat(fire_at - sbf).normalized(), mode, true)
				_place(asl, ap, Defs.flat(objective - ap).normalized(), 0, true)
		"move":
			# now we can see what we're up against
			var foes3 := _known_defenders()
			if foes3 > 0 and (sup.size() + asl.size()) < foes3 * 1.2 and not _said.has("fix"):
				_set_phase("fix")
				_say("fix", sup + asl, ["Too many of them! Go firm, keep them pinned!", "Contact, too many! Base of fire, everyone!", "Can't take that alone. Hold and suppress!"])
				_place(sup + asl, _centroid(sup + asl), axis, 2, true)
				return
			if not support_set and (_arrived(sup) or t - phase_t > 40.0):
				support_set = true
				_say("set", sup, ["Base of fire set!", "Guns up! Firing!", "Alpha set, engaging!", "Set! Suppressing!"])
			if support_set:
				_suppress(sup, fire_at)
			if support_set and (_arrived(asl) or t - phase_t > 50.0):
				_set_phase("assault")
				_rush_t = 0.0
				_say("go", asl, ["Assault! Go, go, go!", "Bravo, move! Covering fire!", "On my mark... move!"])
		"assault":
			var ac := _centroid(asl)
			var to_obj := Defs.flat(objective - ac).length()
			# support shifts its fire beyond the objective as the assault closes, then lifts
			if to_obj > 24.0:
				_suppress(sup, fire_at)
			elif to_obj > 11.0:
				if not shifted:
					shifted = true
					_say("shift", sup, ["Shift fire! Shift fire!", "Shifting! Watch the friendlies!", "Lift and shift!"])
				_suppress(sup, objective + Defs.flat(objective - ac).normalized() * 18.0 - axis.cross(Vector3.UP) * side * 8.0)
			# cut up or pinned: back to the assault position, fight from there
			var supp := 0.0
			for m in asl:
				supp += m.supp_value()
			supp /= maxf(1.0, asl.size())
			_pinned_t = _pinned_t + 0.5 if supp > 70.0 else 0.0
			if asl.size() * 10 < _start_n * 4 or _pinned_t > 10.0:
				_set_phase("fallback")
				_say("fallback", asl, ["Fall back to the assault position!", "Too hot! Back, back!", "Pull back! Regroup!"])
				_place(asl, ap, Defs.flat(objective - ap).normalized(), 2, true)
				return
			if to_obj < 7.0 or (to_obj < 20.0 and _enemy_near_objective() == 0):
				_clear_t += 0.5
				if _clear_t > 2.0 or to_obj < 7.0:
					_finish(true)
					return
			else:
				_clear_t = 0.0
			_rushes(asl, to_obj)
		"fix":
			_suppress(sup + asl, fire_at)
			# reinforced, or they've been whittled down: go
			var foes2 := _known_defenders()
			if foes2 == 0 or (sup.size() + asl.size()) >= foes2 * 1.4:
				_said.erase("plan")
				_set_phase("plan")
				phase_t = 0.0
			elif t - phase_t > 120.0:
				_finish(false)
		"fallback":
			_suppress(sup, fire_at)
			_suppress(asl, fire_at)
			if t - phase_t > 20.0:
				var supp2 := 0.0
				for m in asl:
					supp2 += m.supp_value()
				supp2 /= maxf(1.0, asl.size())
				if supp2 < 40.0 and asl.size() * 10 >= _start_n * 4:
					_set_phase("assault")
					shifted = false
					_said.erase("shift")
					_say("again", asl, ["Again! Move!", "Second try, go!", "They're down, go now!"])
				elif t - phase_t > 60.0:
					_finish(false)


func _set_phase(p: String) -> void:
	phase = p
	phase_t = world.time
	world.stat("plan_" + p)
	if p == "fix" and not _said.has("fix_msg"):
		# the company net hears it: whoever commands this side can send help
		_said["fix_msg"] = true
		world.send_msg(team, "alert", "%s: outnumbered at %s, gone firm. Need fires or reinforcements!" % [_name(support + assault), Defs.grid_ref(objective)], objective)
	if OS.has_environment("FL_DEBUG_PLAN"):
		print("PLAN t=%.1f %s phase=%s sup=%d asl=%d obj=%s sbf=%s ap=%s side=%.0f" % [world.time, _name(support + assault), p, _members(support).size(), _members(assault).size(), str(objective.snapped(Vector3.ONE)), str(sbf.snapped(Vector3.ONE)), str(ap.snapped(Vector3.ONE)), side])


func _suppress(ms: Array, at: Vector3) -> void:
	for m in ms:
		m.cf_until = world.time + 1.5
		m.cf_pos = at


## How many enemies we know are holding the objective.
func _known_defenders() -> int:
	var seen := {}
	for e in support + assault:
		for id in e.sq.known:
			var k: Dictionary = e.sq.known[id]
			if Defs.flat((k.pos as Vector3) - objective).length() < 30.0 and world.time - float(k.t) < 25.0 and k.e is Soldier and not k.e.gone and k.e.life == Soldier.Life.ALIVE:
				seen[id] = true
	return seen.size()


func _enemy_near_objective() -> int:
	var n := 0
	for s in world.soldiers_near(objective, 18.0):
		if s.team != team and s.team >= 0 and s.life == Soldier.Life.ALIVE:
			n += 1
	return n


## Buddy rushes: half the assault element dashes forward (3 to 5 seconds up,
## then down in cover) while the other half fires, then they swap.
func _rushes(asl: Array, to_obj: float) -> void:
	var t: float = world.time
	var groups := [[], []]
	for i in asl.size():
		groups[i % 2].append(asl[i])
	var mover: Array = groups[_rush_group]
	var cover: Array = groups[1 - _rush_group]
	_suppress(cover, fire_at)
	if t < _rush_t and not _arrived(mover, 0.75):
		return
	if t < _rush_t - 3.0:
		return
	_rush_group = 1 - _rush_group
	mover = groups[_rush_group]
	if mover.is_empty():
		mover = groups[1 - _rush_group]
	var mc := _centroid(mover)
	var leg := minf(9.0, maxf(Defs.flat(objective - mc).length() - 2.0, 2.0))
	var dir := Defs.flat(objective - mc).normalized()
	# open ground ahead and they're shooting: smoke first
	if not _smoked and to_obj > 22.0 and _enemy_near_objective() > 0:
		for m in asl:
			if m.smokes > 0:
				_smoked = true
				var sp := ac_pos(asl).lerp(objective, 0.45)
				m.cmd_throw(sp, "smoke")
				m.say(["Smoke out!", "Popping smoke!", "Smoke! Wait for it..."][world.rng.randi() % 3], true)
				_rush_t = t + 3.0
				return
	_place(mover, mc + dir * leg, dir, 2, false)
	for m in mover:
		m.cf_until = 0.0
	_rush_t = t + 6.0
	# last bound: grenades first
	if to_obj < 26.0:
		for m in mover:
			if m.frags > 0 and _enemy_near_objective() > 0:
				m.cmd_throw(objective + Vector3(world.rng.randf_range(-4, 4), 0, world.rng.randf_range(-4, 4)), "frag")
				break
	if world.rng.randf() < 0.4:
		mover[0].say(["I'm up!", "Moving!", "Covering!", "Up! He sees me! Down!", "Go!"][world.rng.randi() % 5], false)


func ac_pos(ms: Array) -> Vector3:
	return _centroid(ms)


func _finish(won: bool) -> void:
	if done:
		return
	done = true
	world.stat("plan_won" if won else "plan_failed")
	if OS.has_environment("FL_DEBUG_PLAN"):
		print("PLAN t=%.1f %s %s" % [world.time, _name(support + assault), "WON" if won else "FAILED"])
	var sqs := []
	for e in support + assault:
		if not e.sq in sqs and e.sq.plan == self:
			sqs.append(e.sq)
	for sq in sqs:
		sq.plan = null
	if won:
		_say("won", _members(assault) + _members(support), ["Objective secure! Consolidate!", "Clear! Set up security, three-sixty!", "We've got it! Dig in!"])
		var i := 0
		var lat := axis.cross(Vector3.UP)
		for sq in sqs:
			sq.order_defend(objective + lat * (i - (sqs.size() - 1) * 0.5) * 12.0, axis)
			i += 1
	else:
		for sq in sqs:
			sq.order_defend(sq.centroid(), axis)


## A fresh squad sent to help: it joins the assault and moves up to the men
## already in contact. With the odds evened the plan re-forms and goes in.
func join(sq) -> void:
	for e in support + assault:
		if e.sq == sq:
			return
	sq.order_assault(objective, axis, false)
	sq.plan = self
	var el := {"sq": sq, "team": -1}
	assault.append(el)
	_start_n += sq.alive_members().size()
	var ms := _members([el])
	var at: Vector3 = ap
	if phase == "fix":
		at = _centroid(_members(support + assault)) - axis * 6.0
	_place(ms, world.nav.nearest_walkable(at), axis, 1, true)
	_say("join", ms, ["Moving up to support you!", "Reinforcements coming in!", "We're on our way, hold on!"])
	world.stat("plan_reinforced")


func _name(elems: Array) -> String:
	if elems.is_empty():
		return ""
	return Squad.callsign_of(team, elems[0].sq.sid)


## For the map: [phase, objective, support position, assault position, side].
func info() -> Array:
	return [phase, objective, sbf, ap, side]
