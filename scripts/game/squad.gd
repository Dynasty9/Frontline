class_name Squad
extends RefCounted
## Server-side squad brain: shares enemy knowledge, plans rescues with
## covering fire and smoke, hands out build jobs and checks for surrender.

var world: World
var sid := 0
var team := 0
var owner := 0
var kind := ""
var members: Array = []
var known := {}  # eid -> {"e": Entity, "pos": Vector3, "t": float}
var heard: Array = []  # [pos, t] gunfire from unseen shooters
var order := "hold"
var order_pos := Vector3.ZERO
var order_n := 0  # bumped every time a commander (player or AI) gives this squad an order
var shown_order := ""  # what the order looks like on the map, when that differs from `order`
var facing := Vector3.FORWARD
var cover_fire_until := 0.0
var cover_fire_pos := Vector3.ZERO
var think_t := 0.0
var smoked := {}  # wounded eid -> time
var build_target: Entity = null
var tunnel_exit_pos := Vector3.INF
var fire_queue: Array = []  # mortar team fire mission: [[pos, kind], ...]
var bound_team := 0  # attack-move: which fire team is bounding forward
var bound_t := 0.0
var contact_t := -99.0
var alert_t := -99.0  # the last time the squad knew of (or heard) an enemy
# command and cohesion
var leader = null  # untyped: the man may be freed
var travel := false  # long move: the leader leads, the rest keep their place in the group
var travel_mode := 0
var final_slots := {}  # eid -> where each man ends up
var plan = null  # AttackPlan this squad is part of (untyped: shared between squads)
var breach_by: Soldier = null  # the man clearing a house for the squad (see SoldierBrain)
# battle drills and morale (see SquadBrain)
var morale := -1.0  # 0-100 (set from the side's base on the first tick)
var drill := ""  # under way: "contact", "displace", "withdraw", "rout" (or "")
var drill_t := 0.0
var drill_pos := Vector3.ZERO
var halt_dest := Vector3.ZERO  # where a move was going when contact stopped it
var halt_face := Vector3.FORWARD
var halt_mode := 0
var move_mode_ord := 0  # the pace of the last move order
var known_at_order := {}  # enemies already known when the move began
var impacts: Array = []  # [pos, time]: shells and bombs landing near us
var last_cas_t := -99.0
var displace_cd := 0.0
var pre_order: Array = []  # what it was doing before it displaced: [order, pos, facing, mode]
var ammo_t := 0.0
var bt_path := ""
var bt_cd := {}
var ambush := false  # defending and not yet seen: holding fire till they're close
var ambush_t := 0.0  # the first volley (until then)
var _offsets := {}  # eid -> Vector2(side, back) behind the leader
# how it moves and makes ground its own (see Tactics)
var technique := ""  # "" travelling, "bound" bounding overwatch
var ow_team := 0  # bounding: which fire team is moving (the other covers it)
var ow_t := 0.0
var ow_rbf_t := 0.0  # recon by fire: not before
var then_defend: Array = []  # [pos, face]: a hold order, once it's got there as a squad
var cleared := {}  # house (floor) eid -> when it was cleared
var bt_clear: Array = []
var clear_call: Array = []  # [man, time]: he calls "Clear!" once he's had a look
var ambush_plan = null  # AmbushPlan it's carrying out (untyped: may be dropped)
var halt_then: Array = []

const CALLSIGNS := [["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel"],
	["Lion", "Hawk", "Wolf", "Viper", "Scorpion", "Falcon", "Jackal", "Cobra"]]


static func callsign_of(team_i: int, sq_id: int) -> String:
	var names: Array = CALLSIGNS[1 if team_i == 1 else 0]
	return "%s %d" % [names[sq_id % names.size()], sq_id / names.size() + 1]


func callsign() -> String:
	return callsign_of(team, sid)


## The squad leader: takes the orders, leads the way, picks the spot. When he
## goes down the next man steps up.
func get_leader() -> Soldier:
	if leader != null and is_instance_valid(leader) and not leader.gone and leader.life == Soldier.Life.ALIVE and leader.squad == self:
		return leader
	var had := leader != null
	leader = null
	for m in members:
		if not m.gone and m.life == Soldier.Life.ALIVE and not m.is_bearer() and m.task in ["", "retreat"]:
			leader = m
			break
	if leader and had:
		world.stat("leader_succession")
		if team == 1:
			leader.say(_pick(["I lead now! Follow me!", "Brothers, on me!", "I'm in command!"]), true)
		else:
			leader.say(_pick(["Sarge is down, I've got command!", "On me! I'm taking the squad!", "I've got it, form on me!"]), true)
	return leader


func display_name() -> String:
	if Defs.SQUADS.has(kind):
		return Defs.SQUADS[kind].name
	return "Squad"


func add(s: Soldier) -> void:
	if s in members:
		return
	members.append(s)
	s.squad = self
	s.sid = sid
	if world.battle:
		world.battle.squad_grew(self)
	if order_pos == Vector3.ZERO:
		order_pos = s.position


func remove(s: Soldier) -> void:
	members.erase(s)
	if s.squad == self:
		s.squad = null
		s.sid = 0


func alive_members() -> Array:
	var out := []
	for m in members:
		if is_instance_valid(m) and not m.gone and m.life == Soldier.Life.ALIVE:
			out.append(m)
	return out


func centroid() -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for m in members:
		if is_instance_valid(m) and not m.gone and m.life != Soldier.Life.DEAD and m.life != Soldier.Life.HIDDEN:
			c += m.position
			n += 1
	if n == 0:
		return order_pos
	return c / n


# --- knowledge ------------------------------------------------------------------------

func report(e: Entity) -> void:
	if e == null or e.gone:
		return
	known[e.eid] = {"e": e, "pos": e.position, "t": world.time}


func report_pos(p: Vector3) -> void:
	heard.append([p, world.time])
	if heard.size() > 8:
		heard.pop_front()


func in_combat() -> bool:
	for k in known.values():
		if world.time - float(k.t) < 8.0:
			return true
	return not heard.is_empty() and world.time - float(heard.back()[1]) < 6.0


## On a war footing: part of a planned attack, assaulting or defending, or
## enemies about lately. Men at a halt take a knee and watch their sectors
## instead of standing about.
func tactical() -> bool:
	return plan != null or order in ["assault", "attack", "defend"] or world.time - alert_t < 60.0


func threat_points(origin: Vector3, n: int) -> Array:
	var arr := []
	for k in known.values():
		if world.time - float(k.t) > 15.0:
			continue
		var e: Entity = k.e
		if e.gone:
			continue
		if e is Soldier and e.life != Soldier.Life.ALIVE:
			continue
		var p: Vector3 = k.pos
		arr.append([Defs.flat(p - origin).length_squared(), p])
	for h in heard:
		if world.time - float(h[1]) < 8.0:
			arr.append([Defs.flat(h[0] - origin).length_squared() + 400.0, h[0]])
	arr.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for i in mini(n, arr.size()):
		if arr[i][0] > 120.0 * 120.0:
			break
		out.append(arr[i][1] + Vector3(0, 1.5, 0))
	return out


func last_known_near(p: Vector3, r: float, max_age: float) -> Dictionary:
	var best := {}
	var bd := r
	for k in known.values():
		if world.time - float(k.t) > max_age:
			continue
		var e: Entity = k.e
		if e.gone or (e is Soldier and e.life != Soldier.Life.ALIVE):
			continue
		var d := Defs.flat(k.pos - p).length()
		if d < bd:
			bd = d
			best = k
	return best


func _nearest_threat(p: Vector3, r: float) -> Dictionary:
	var best := {}
	var bd := r
	for k in known.values():
		if world.time - float(k.t) > 10.0:
			continue
		var e: Entity = k.e
		if e.gone or (e is Soldier and e.life != Soldier.Life.ALIVE):
			continue
		var d := Defs.flat(k.pos - p).length()
		if d < bd:
			bd = d
			best = k
	return best


# --- orders --------------------------------------------------------------------------------

## Slots around `center`, each man snapped to the best cover within a few metres.
func formation(center: Vector3, face: Vector3, n: int, wide := false) -> Array:
	var out := []
	for sl in world.terrain.slots(center, face, n, wide):
		# a fighting position stays exactly where it is (it's beside a wall
		# by design); anything else is nudged onto open ground
		var fp: bool = sl.size() > 2 and not (sl[2] as Dictionary).is_empty()
		out.append(sl[0] if fp else world.nav.nearest_walkable(sl[0]))
	return out


## Any squad-wide order pulls individually commanded men back into the squad.
func _regroup() -> void:
	plan = null
	shown_order = ""
	travel = false
	drill = ""
	ambush = false
	technique = ""
	then_defend = []
	if ambush_plan != null:
		ambush_plan.done = true
		ambush_plan = null
	for m in members:
		m.detached = false


func _assign(slots: Array, mems: Array) -> Array:
	var out := []
	var free := slots.duplicate()
	for m in mems:
		var bi := 0
		var bd := 1e9
		for i in free.size():
			var d: float = Defs.flat(free[i] - m.position).length()
			if d < bd:
				bd = d
				bi = i
		out.append(free[bi])
		free.remove_at(bi)
	return out


## tactical: it may choose to bound (see Tactics) rather than travel.
func order_move(pos: Vector3, face: Vector3, mode := 0, tactical := true) -> void:
	_regroup()
	order = "move"
	order_pos = pos
	facing = face if face.length() > 0.1 else Defs.flat(pos - centroid()).normalized()
	if facing.length() < 0.1:
		facing = Vector3.FORWARD
	build_target = null
	move_mode_ord = mode
	known_at_order = known.duplicate()
	var mems := []
	for m in members:
		if m.can_take_orders():
			mems.append(m)
	if mems.is_empty():
		return
	var slots := _assign(formation(pos, facing, mems.size()), mems)
	final_slots.clear()
	for i in mems.size():
		final_slots[mems[i].eid] = slots[i]
	if tactical and Tactics.bounding_wanted(self, pos, mode):
		Tactics.start_bounding(self)
		return
	var ld := get_leader()
	travel = ld != null and ld in mems and mems.size() > 1 and Defs.flat(pos - centroid()).length() > 26.0
	travel_mode = mode
	if travel:
		# the leader heads for his spot; the others keep their place in a compact group behind him
		ld.cmd_move(final_slots[ld.eid], mode, facing)
		_offsets.clear()
		var k := 0
		for m in mems:
			if m == ld:
				continue
			var angle := k * 2.399963
			var radius := minf(3.5, sqrt(float(k + 1)) * 1.4)
			_offsets[m.eid] = Vector2(cos(angle) * radius, 3.8 + sin(angle) * radius)
			k += 1
		_follow_tick()
	else:
		for i in mems.size():
			mems[i].cmd_move(slots[i], mode, facing)
	var sayer: Soldier = ld if ld else mems[0]
	sayer.say(_pick(["Moving!", "Move up!", "On me!", "Let's go!", "Copy, moving."]) if owner >= 0 else _pick(["Copy, moving to %s." % Defs.grid_ref(pos), "Roger, %s. On me!" % Defs.grid_ref(pos), "Moving to %s." % Defs.grid_ref(pos)]), true)


## Travelling in formation: every half second the men re-aim for their place
## behind the leader; laggards run, and the leader eases off if they fall behind.
func _follow_tick() -> void:
	var ld := get_leader()
	if ld == null:
		travel = false
		return
	var goal: Vector3 = final_slots.get(ld.eid, order_pos)
	if Defs.flat(goal - ld.position).length() < 9.0 or (not ld.is_moving() and ld.goal_kind != "slot"):
		travel = false
		for m in members:
			if m != ld and m.can_take_orders() and not m.detached and final_slots.has(m.eid):
				m.follow_to(final_slots[m.eid], travel_mode, facing)
		return
	var head: Vector3 = ld._last_dir if ld.is_moving() else Defs.flat(goal - ld.position).normalized()
	head = Defs.flat(head).normalized()
	if head.length() < 0.1:
		head = facing
	var side := head.cross(Vector3.UP)
	var max_lag := 0.0
	for m in members:
		if m == ld or not m.can_take_orders() or m.detached or not _offsets.has(m.eid):
			continue
		var o: Vector2 = _offsets[m.eid]
		var tgt := world.nav.nearest_walkable(ld.position + side * o.x - head * o.y)
		if not world.nav._line_free(ld.position, tgt, false):
			tgt = ld.position  # file through the same gap before spreading out again
		var lag := Defs.flat(tgt - m.position).length()
		max_lag = maxf(max_lag, lag)
		m.follow_to(tgt, 2 if lag > 9.0 else (maxi(travel_mode, 1) if lag > 3.5 else travel_mode), facing)
	# don't run off and leave them
	ld.move_mode = 0 if max_lag > 8.0 else travel_mode


func order_attack(t: Entity) -> void:
	_regroup()
	order = "attack"
	var c := centroid()
	var d := Defs.flat(t.position - c)
	var dist := d.length()
	var stand := 35.0 if not (t is Structure) else 30.0
	var pos := t.position - d.normalized() * minf(dist, stand) if dist > stand else c
	order_pos = pos
	facing = d.normalized() if dist > 0.1 else facing
	var mems := []
	for m in members:
		if m.can_take_orders():
			mems.append(m)
	if mems.is_empty():
		return
	var slots := _assign(formation(pos, facing, mems.size()), mems)
	for i in mems.size():
		mems[i].cmd_attack(t, slots[i])
	mems[0].say(_pick(["Engaging!", "Target spotted, moving in!", "Light 'em up!"]), true)


func order_stop() -> void:
	_regroup()
	order = "hold"
	order_pos = centroid()
	for m in members:
		m.cmd_stop()


func order_retreat() -> void:
	var f: Structure = world.rules.nearest_fob(team, centroid())
	if f == null:
		return
	_regroup()
	order = "move"
	shown_order = "retreat"
	order_pos = f.position
	facing = Defs.flat(centroid() - f.position).normalized()
	var i := 0
	for m in members:
		var off := Vector3(cos(i * 1.3), 0, sin(i * 1.3)) * 4.0
		m.cmd_retreat(world.nav.nearest_walkable(f.position + off))
		i += 1
	if not members.is_empty():
		members[0].say("Fall back! Fall back!", true)


func order_work(t: Entity) -> void:
	_regroup()
	order = "build"
	build_target = t
	order_pos = t.position
	for m in members:
		if m.can_take_orders():
			m.hold_pos = t.position
			m.start_build(t)
	if not members.is_empty():
		members[0].say(_pick(["On it.", "Get building!", "Let's get this up."]), true)


## Everyone who fits climbs into a friendly vehicle; it carries them until
## it's told to dismount (or arrives where it's sent).
func order_board(v: Vehicle) -> void:
	_regroup()
	order = "move"
	order_pos = v.position
	var free := v.seats_free()
	var n := 0
	for m in alive_members():
		if n >= free:
			break
		if m.can_take_orders():
			m.order_board(v)
			n += 1
	if n > 0:
		members[0].say(_pick(["Mount up!", "Everybody in!", "Load up, let's go!"]), true)


func order_enter(st: Structure) -> void:
	_regroup()
	if st.skind == "tunnel":
		order = "tunnel"
		for m in members:
			m.order_tunnel(st)
		return
	if st.skind == "bunker":
		order = "move"
		order_pos = st.position
		facing = st.front_dir()
		for m in members:
			m.cmd_garrison(st)
		if not members.is_empty():
			members[0].say(_pick(["Into the bunker!", "Get inside!", "Man the slits!"]), true)
		return
	if st.is_mount():
		var best: Soldier = null
		var bd := 1e9
		var pref := st.mount_pref()
		for m in alive_members():
			var d: float = Defs.flat(m.position - st.position).length()
			if m.utype in pref:
				d -= 20.0
			if d < bd and m.can_take_orders():
				bd = d
				best = m
		var face := st.front_dir()
		order_move(st.position - face * 2.0, face, 0)
		if best:
			best.start_man(st)
			st.gunner = best
		return
	if st.needs_work():
		order_work(st)
	else:
		order_move(st.position, facing, 0)


## Hold an area: spread out along a shallow arc facing `face`, every man in the
## best cover he can find there, and stay put instead of chasing.
func order_defend(pos: Vector3, face: Vector3, direct := false) -> void:
	if not direct and Defs.flat(pos - centroid()).length() > 45.0 and drill == "":
		# a long way off: get there as a squad first, then spread out
		order_move(pos, face, 0)
		then_defend = [pos, face]
		return
	_regroup()
	order = "defend"
	order_pos = pos
	facing = face if face.length() > 0.1 else Defs.flat(pos - centroid()).normalized()
	if facing.length() < 0.1:
		facing = Vector3.FORWARD
	build_target = null
	var mems := []
	for m in members:
		if m.can_take_orders():
			mems.append(m)
	if mems.is_empty():
		return
	var slots := _assign(formation(pos, facing, mems.size(), true), mems)
	for i in mems.size():
		mems[i].cmd_move(slots[i], 0, facing)
		mems[i].leash = 7.0
	# a fresh position the enemy doesn't know about: let them come close
	ambush = not in_combat()
	mems[0].say(_pick(["Dig in here!", "Hold this line!", "Find cover, watch your front!", "We hold here.", "Nobody gets past us."]), true)


## Attack-move: push towards `pos` in bounds, one fire team dashing from cover
## to cover while the other watches; on contact everyone goes to ground and
## fights it out, then the advance carries on. At the objective they dig in.
func order_assault(pos: Vector3, face: Vector3, deliberate := true) -> void:
	_regroup()
	order = "assault"
	order_pos = pos
	facing = face if face.length() > 0.1 else Defs.flat(pos - centroid()).normalized()
	if facing.length() < 0.1:
		facing = Vector3.FORWARD
	build_target = null
	bound_team = 0
	bound_t = 0.0
	contact_t = -99.0
	for m in members:
		if m.can_take_orders():
			m.forced_target = null
	# a squad of four or more plans a proper attack: one fire team fixes, the other flanks
	if deliberate:
		plan = AttackPlan.make(world, [self], pos, facing)
		if plan != null:
			return
	_next_bound()
	var lead := alive_members()
	if not lead.is_empty():
		lead[0].say(_pick(["Advance! Bounding, by teams!", "Move up, cover to cover!", "Let's push! Watch your sectors!", "Go, go! I'll cover!"]), true)


func _next_bound(leg_max := 14.0) -> void:
	var mems := []
	for m in members:
		if m.can_take_orders() and not m.detached:
			mems.append(m)
	if mems.is_empty():
		return
	var c := centroid()
	var to := Defs.flat(order_pos - c)
	var leg := minf(to.length(), leg_max)
	var dest := c + to.normalized() * leg if to.length() > 0.5 else order_pos
	var group := []
	for i in mems.size():
		if mems.size() <= 2 or i % 2 == bound_team:
			group.append(mems[i])
	var slots := _assign(formation(dest, facing, group.size()), group)
	for i in group.size():
		group[i].cmd_move(slots[i], 1, facing)
	bound_team = 1 - bound_team
	bound_t = world.time + 12.0
	if group.size() > 0 and mems.size() > 2 and world.rng.randf() < 0.35:
		group[0].say(_pick(["Moving!", "Covering!", "Set! Move up!", "Go!"]), false)


## Fire and movement: in contact the squad keeps closing in short rushes, one
## fire team dashing to the next cover while the other keeps the enemy's heads
## down. It only goes to ground when it's pinned or badly cut up.
func _assault_logic() -> void:
	if order != "assault":
		return
	if plan != null:
		plan.tick()
		return
	var alive := alive_members()
	if alive.is_empty():
		return
	var contact := in_combat()
	if contact:
		contact_t = world.time
	var supp := 0.0
	for m in alive:
		supp += m.supp_value()
	supp /= alive.size()
	if contact and (supp > 55.0 or alive.size() * 2 < members.size()):
		# pinned or bleeding: hold here, return fire, wait for support
		if world.time > bound_t:
			bound_t = world.time + 5.0
			if world.rng.randf() < 0.3:
				alive[0].say(_pick(["We're pinned!", "Can't move, too much fire!", "Hold here, return fire!"]), true)
		return
	var c := centroid()
	if Defs.flat(order_pos - c).length() < 7.0:
		order_defend(order_pos, facing)
		return
	var moving := false
	for m in alive:
		if not m.detached and m.goal_kind == "slot" and m.is_moving():
			moving = true
			break
	if moving and world.time < bound_t:
		return
	if contact:
		# the covering team lays down fire on what we know while the others rush
		cover_fire_pos = order_pos
		var near: Dictionary = _nearest_threat(c, 90.0)
		if not near.is_empty():
			cover_fire_pos = near.pos
		cover_fire_until = world.time + 6.0
	_next_bound(9.0 if contact else 14.0)


func has_mortar() -> bool:
	for m in alive_members():
		if int(m.udef.get("mortar", 0)) > 0:
			return true
	return false


func order_fire_mission(p: Vector3, kind: String) -> void:
	if not has_mortar():
		return
	fire_queue.clear()
	for i in 4:
		fire_queue.append([p, kind])
	for m in alive_members():
		if int(m.udef.get("mortar", 0)) > 0:
			m.say("Fire mission, %s. Copy!" % ("smoke" if kind == "smoke" else "HE"), true)
			m.mortar_cd = 0.0
			break


func order_throw(p: Vector3, kind: String) -> void:
	var best: Soldier = null
	var bd := 1e9
	for m in alive_members():
		if not m.can_take_orders():
			continue
		if kind == "smoke" and m.smokes <= 0 or kind == "frag" and m.frags <= 0:
			continue
		var d: float = Defs.flat(m.position - p).length()
		if d < bd:
			bd = d
			best = m
	if best:
		best.cmd_throw(p, kind)


func on_member_down(s: Soldier) -> void:
	SquadBrain.casualty(self, s)
	if s.life == Soldier.Life.DOWNED:
		for m in alive_members():
			if Defs.flat(m.position - s.position).length() < 30.0:
				m.say(_pick(["Man down!", "%s is hit!" % s.sname, "We've got wounded!", "Medic! %s is down!" % s.sname]), true)
				break


func on_build_done(t: Entity) -> void:
	if build_target == t:
		build_target = null
		order = "hold"
		for m in alive_members():
			if m.task == "build":
				return
		if not members.is_empty():
			members[0].say(_pick(["Done here.", "Construction complete.", "That should hold."]))


# --- tick ---------------------------------------------------------------------------------

func tick(dt: float) -> void:
	think_t -= dt
	if think_t > 0.0:
		return
	think_t = 0.5
	var keep := []
	for m in members:
		if is_instance_valid(m) and not m.gone and m.squad == self:
			keep.append(m)
	members = keep
	var any := false
	for m in members:
		if m.life == Soldier.Life.ALIVE or m.life == Soldier.Life.DOWNED or m.life == Soldier.Life.HIDDEN:
			any = true
			break
	if not any:
		# wiped out: struck off. It lets go of its dead (their bodies are
		# cleared away in time, and freed) and of any plan it was part of, so
		# whatever still holds the squad - an attack the squads beside it carry
		# on with, ordering every squad in it when it ends - finds nobody here.
		if plan != null:
			world.stat("plan_squad_lost")
		for m in members:
			m.squad = null
		members = []
		plan = null
		if ambush_plan != null:
			ambush_plan.done = true
			ambush_plan = null
		world.remove_squad(self)
		return
	for id in known.keys():
		var k: Dictionary = known[id]
		if world.time - float(k.t) > 20.0 or k.e.gone:
			known.erase(id)
	if not known.is_empty() or (not heard.is_empty() and world.time - float(heard.back()[1]) < 10.0):
		alert_t = world.time
	get_leader()
	if morale < 0.0:
		morale = SquadBrain.base_morale(self)
	SquadBrain.morale_tick(self, 0.5)
	if ambush_plan != null:
		ambush_plan.tick()
		if ambush_plan != null and ambush_plan.done:
			ambush_plan = null
	else:
		SquadBrain.ambush_tick(self)
	SquadBrain.think(self)
	Tactics.crew_tick(self)
	Tactics.straggler_tick(self)
	Tactics.overwatch_tick(self)
	Tactics.then_defend_tick(self)
	Tactics.clear_call_tick(self)
	if drill == "rout":
		_surrender_logic()
		return
	if travel and order == "move":
		_follow_tick()
	_rescue_logic()
	_surrender_logic()
	_medic_logic()
	_engineer_logic()
	_assault_logic()
	SquadBrain.share_ammo(self)


## Morale as it shows: 0 steady, 1 shaken, 2 breaking, 3 routed.
func morale_state() -> int:
	return SquadBrain.state(morale if morale >= 0.0 else 75.0, drill == "rout")


## How well a squad in that state shoots.
func acc_mult() -> float:
	return [1.0, 0.85, 0.7, 0.45][morale_state()]


## How much fire it takes to pin a man of it.
func pin_at() -> float:
	return [60.0, 52.0, 44.0, 30.0][morale_state()]


func _pick(arr: Array) -> String:
	return arr[world.rng.randi() % arr.size()]


func _rescue_logic() -> void:
	for w in members:
		if w.life != Soldier.Life.DOWNED or not w.carried_by.is_empty():
			continue
		if w.rescue_claimed and not w.rescue_claimed.gone and w.rescue_claimed.life == Soldier.Life.ALIVE and w.rescue_claimed.task == "rescue" and w.rescue_claimed.task_ent == w:
			if cover_fire_until < world.time + 1.0:
				var d2 := _nearest_threat(w.position, 55.0)
				if not d2.is_empty():
					cover_fire_until = world.time + 3.0
					cover_fire_pos = d2.pos
			continue
		w.rescue_claimed = null
		var cands := []
		for m in alive_members():
			if m == w or m.is_bearer() or m.suppression > 78.0 or not (m.task == "" or m.task == "escort" or m.task == "build"):
				continue
			if Defs.flat(m.position - w.position).length() > 55.0:
				continue
			cands.append(m)
		if cands.is_empty():
			continue
		var danger := _nearest_threat(w.position, 55.0)
		if not danger.is_empty():
			var newly := cover_fire_until < world.time
			cover_fire_until = world.time + 7.0
			cover_fire_pos = danger.pos
			if newly:
				cands[0].say(_pick(["Covering fire!", "Suppress them!", "Lay it down, get him out!"]), true)
				for m in alive_members():
					m.next_cover_eval = world.time + 2.0
			if not smoked.has(w.eid) or world.time - float(smoked[w.eid]) > 30.0:
				var thrower: Soldier = null
				var td := 35.0
				for m in cands:
					var d: float = Defs.flat(m.position - w.position).length()
					if m.smokes > 0 and d < td:
						td = d
						thrower = m
				if thrower:
					smoked[w.eid] = world.time
					var to_enemy := Defs.flat(danger.pos - w.position)
					var sp: Vector3 = w.position + to_enemy.normalized() * minf(5.0, to_enemy.length() * 0.4)
					thrower.cmd_throw(sp, "smoke")
					cands.erase(thrower)
					if cands.is_empty():
						continue
			if newly:
				continue  # give the covering fire a moment before running out
		var rescuer: Soldier = null
		for m in cands:
			if m.udef.get("medic", false) and Defs.flat(m.position - w.position).length() < 45.0:
				rescuer = m
				break
		if rescuer == null:
			var bd := 1e9
			for m in cands:
				var d: float = Defs.flat(m.position - w.position).length()
				if d < bd:
					bd = d
					rescuer = m
		rescuer.start_rescue(w)
		cands.erase(rescuer)
		if not danger.is_empty() and not cands.is_empty():
			var esc: Soldier = null
			var ed := 1e9
			for m in cands:
				if m.task != "":
					continue
				var d: float = Defs.flat(m.position - rescuer.position).length()
				if d < ed:
					ed = d
					esc = m
			if esc:
				esc.start_escort(w, rescuer)


func _surrender_logic() -> void:
	var alive := alive_members()
	if alive.size() != 1 or members.size() < 2:
		return
	var s: Soldier = alive[0]
	if s.task != "" or s.suppression < 45.0 or s.is_bearer():
		return
	for o in world.soldiers_near(s.position, 25.0):
		if o != s and o.team == team and o.life == Soldier.Life.ALIVE:
			return
	var enemy_close := false
	for o in world.soldiers_near(s.position, 40.0):
		if o.team != team and o.team >= 0 and o.life == Soldier.Life.ALIVE:
			enemy_close = true
			break
	if not enemy_close:
		return
	if world.rng.randf() < 0.035:
		s.surrender()


func _medic_logic() -> void:
	if in_combat():
		return
	for medic in alive_members():
		if not medic.udef.get("medic", false) or medic.task != "":
			continue
		for m in alive_members():
			if m != medic and m.hp < m.max_hp * 0.7 and m.task == "":
				medic.start_heal(m)
				return


func _engineer_logic() -> void:
	if in_combat() and _nearest_threat(centroid(), 30.0).size() > 0:
		return
	for m in alive_members():
		if m.task != "" or m.is_moving():
			continue
		var is_eng: bool = m.udef.get("engineer", false)
		if not is_eng and order != "build":
			continue
		var best: Entity = null
		var bd := 60.0 if is_eng else 18.0
		for st in world.structures_near(m.position, bd):
			if st.team != team or not st.needs_work() or st.skind == "depot":
				continue
			var d: float = Defs.flat(st.position - m.position).length()
			if d < bd:
				bd = d
				best = st
		if best == null and is_eng:
			for v in world.vehicles_near(m.position, 25.0):
				if v.team == team and v.needs_repair():
					best = v
					break
		if best:
			m.start_build(best)
