class_name Delegation
extends RefCounted
## Command by intent. A commander who can't watch every squad tells a group
## what he wants done - hold this sector, take that objective, screen this
## line, wait in reserve here, ambush that road - and his deputy (the XO)
## carries it out: placing the squads, giving their orders, re-giving them
## when the fight knocks them off, and reporting back on the net. It uses the
## same drills the AI commander does (AttackPlan, AmbushPlan, the squads' own
## defend and assault orders), so a delegated platoon fights the way the AI's
## does.
##
## The units stay the player's (and every allied player can still order
## them): ordering one directly takes it back, and so does Take back. A
## delegated unit is never part of the AI commander's allocation - that only
## ever looks at the AI's own units - so the two never fight over a squad.
##
## Server only. The side's intents go out in its team summary ("dg") for the
## map and the order of battle.

const KINDS := ["hold", "take", "screen", "reserve", "ambush"]
const NAMES := {"hold": "Hold sector", "take": "Take objective", "screen": "Screen", "reserve": "Reserve", "ambush": "Ambush"}
const TICK := 1.0
const SPREAD := {"hold": 18.0, "take": 13.0, "screen": 34.0, "reserve": 14.0, "ambush": 50.0}

var world: World
var intents := {}  # id -> intent (see _make)
var of_squad := {}  # sid -> intent id
var of_vehicle := {}  # eid -> intent id
var _next := 1
var _t := 0.0


func _init(w: World) -> void:
	world = w


# --- giving and taking back ----------------------------------------------------------

## Hands squads and vehicles to the XO with an intent. They leave whatever
## intent they had before.
func assign(peer: int, team: int, kind: String, sqs: Array, vehs: Array, pos: Vector3, face: Vector3) -> int:
	if not kind in KINDS or (sqs.is_empty() and vehs.is_empty()):
		return 0
	release(sqs, vehs, "")
	if face.length() < 0.1:
		var c := _centroid(sqs, vehs)
		face = Defs.flat(pos - c).normalized() if Defs.flat(pos - c).length() > 1.0 else (Vector3.FORWARD if team == 0 else Vector3.BACK)
	face = Defs.flat(face).normalized()
	if kind == "take":
		# an objective on a town means its square: that's where the flag is won
		for tn in world.rules.towns():
			if tn.zone_c != Vector3.INF and Defs.flat(tn.zone_c - pos).length() < 30.0:
				pos = tn.zone_c
				break
	pos = world.nav.nearest_walkable(pos)
	var it := {"id": _next, "kind": kind, "team": team, "peer": peer, "pos": pos, "face": face,
		"squads": [], "vehicles": [], "phase": "", "t": world.time, "slot": {}, "line": {}, "tries": 0,
		"target": pos, "said": {}, "wait": {}}
	_next += 1
	for sq in sqs:
		it.squads.append(sq.sid)
		of_squad[sq.sid] = it.id
		# a plan or an ambush it was carrying out for someone else is over
		_drop_plans(sq)
	for v in vehs:
		it.vehicles.append(v.eid)
		of_vehicle[v.eid] = it.id
	intents[it.id] = it
	_start(it)
	var names := _names(it)
	world.send_msg(team, "radio", "XO: %s - %s, %s. Wilco." % [", ".join(names), String(NAMES[kind]).to_lower(), Defs.grid_ref(pos)], pos)
	world.stat("delegate_" + kind)
	return it.id


## Takes units back from the XO (an order of your own, or Take back). `why`
## is said on the net when it isn't "".
func release(sqs: Array, vehs: Array, why: String) -> Array:
	var names := []
	var team := -1
	for sq in sqs:
		var id: int = of_squad.get(sq.sid, 0)
		if id == 0:
			continue
		of_squad.erase(sq.sid)
		var it: Dictionary = intents.get(id, {})
		if not it.is_empty():
			it.squads.erase(sq.sid)
			team = int(it.team)
		names.append(sq.callsign())
	for v in vehs:
		var id: int = of_vehicle.get(v.eid, 0)
		if id == 0:
			continue
		of_vehicle.erase(v.eid)
		var it: Dictionary = intents.get(id, {})
		if not it.is_empty():
			it.vehicles.erase(v.eid)
			team = int(it.team)
		names.append(v.display_name())
	_drop_empty()
	if why != "" and not names.is_empty() and team >= 0:
		world.send_msg(team, "radio", "XO: %s %s." % [", ".join(names), why])
	if not names.is_empty():
		world.stat("delegate_released")
	return names


func is_delegated_squad(sid: int) -> bool:
	return of_squad.has(sid)


## The intent a squad is carrying out ("" when it's yours to command).
func kind_of_squad(sid: int) -> String:
	var it: Dictionary = intents.get(of_squad.get(sid, 0), {})
	return String(it.get("kind", ""))


func is_delegated_vehicle(eid: int) -> bool:
	return of_vehicle.has(eid)


## For the team summary: [id, kind, pos, face, squads, vehicles, phase, target].
func summary(team: int) -> Array:
	var out := []
	for it in intents.values():
		if int(it.team) == team:
			out.append([it.id, it.kind, it.pos, it.face, (it.squads as Array).duplicate(), (it.vehicles as Array).duplicate(), it.phase, it.target])
	return out


# --- running -------------------------------------------------------------------------

func tick(dt: float) -> void:
	if intents.is_empty():
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = TICK
	for it in intents.values():
		_prune(it)
		if (it.squads as Array).is_empty() and (it.vehicles as Array).is_empty():
			continue
		match String(it.kind):
			"hold":
				_hold(it)
			"take":
				_take(it)
			"screen":
				_screen(it)
			"reserve":
				_reserve(it)
			"ambush":
				_ambush(it)
	_drop_empty()


## The first orders: where everyone goes.
func _start(it: Dictionary) -> void:
	match String(it.kind):
		"hold", "reserve":
			_deploy(it, it.pos)
			it.phase = "hold" if it.kind == "hold" else "ready"
		"screen":
			_deploy(it, it.pos)
			it.phase = "screen"
		"take":
			_assault(it)
		"ambush":
			for sid in it.squads:
				_lay_ambush(it, world.squads.get(sid))
			for eid in it.vehicles:
				var v: Vehicle = world.entity(eid) as Vehicle
				if v:
					_vmove(it, v, it.pos - it.face * 70.0)
			it.phase = "set"
	it.t = world.time


## Squads in a line across the facing, each with its slot; vehicles a little
## behind them (or out on the flanks, for a screen).
func _deploy(it: Dictionary, at: Vector3) -> void:
	var face: Vector3 = it.face
	var lat := face.cross(Vector3.UP).normalized()
	var sqs := _squads(it)
	var gap: float = SPREAD.get(String(it.kind), 16.0)
	var n := sqs.size()
	for i in n:
		var p: Vector3 = world.nav.nearest_walkable(at + lat * (i - (n - 1) / 2.0) * gap)
		it.slot[sqs[i].sid] = p
		_defend(sqs[i], p, face)
	var vs := _vehicles(it)
	var m := vs.size()
	for i in m:
		var vp: Vector3
		if it.kind == "screen":
			var side := -1.0 if i % 2 == 0 else 1.0
			vp = at + lat * side * ((n + 1) / 2.0 + i / 2) * gap
		else:
			vp = at - face * 14.0 + lat * (i - (m - 1) / 2.0) * 10.0
		it.slot[-v_key(vs[i])] = vp
		_vmove(it, vs[i], vp)


# --- the intents ---------------------------------------------------------------------

## Hold the sector: every squad keeps its piece of the line. One knocked off it
## (it displaced, withdrew, or chased) is sent back once it has collected
## itself; one too cut up to hold goes back to refit and back to you.
func _hold(it: Dictionary) -> void:
	for sq in _squads(it):
		if _battered(it, sq):
			continue
		var slot: Vector3 = it.slot.get(sq.sid, it.pos)
		if sq.plan != null or sq.drill != "" or sq.ambush_plan != null:
			continue
		if sq.order != "defend" or Defs.flat(sq.order_pos - slot).length() > 12.0:
			if sq.then_defend.is_empty() or Defs.flat((sq.then_defend[0] as Vector3) - slot).length() > 12.0:
				_defend(sq, slot, it.face)
				world.stat("delegate_reoccupy")
	_keep_vehicles(it)
	_report_contact(it, it.pos, 70.0)


## Take the objective: a deliberate attack (one squad fixes, the others flank)
## or, alone, the squad's own fire-and-movement; then consolidate on it and
## hold it. An attack that fails is re-formed and sent in again, a few times.
func _take(it: Dictionary) -> void:
	var sqs := _squads(it)
	if it.phase == "held":
		_hold(it)
		return
	var busy := false
	for sq in sqs:
		if sq.plan != null or sq.order == "assault" or sq.drill in ["contact", "displace"]:
			busy = true
	var enemy := _enemy_count(int(it.team), it.pos, 40.0)
	var near := 0
	for sq in sqs:
		if Defs.flat(sq.centroid() - it.pos).length() < 35.0:
			near += 1
	if busy and world.time - float(it.t) < 360.0:
		return
	if enemy == 0 and (near > 0 or sqs.is_empty()):
		it.phase = "held"
		it.t = world.time
		_deploy(it, it.pos)
		world.send_msg(int(it.team), "radio", "XO: objective %s taken - %s consolidating." % [Defs.grid_ref(it.pos), ", ".join(_names(it))], it.pos)
		world.stat("delegate_taken")
		return
	if world.time - float(it.t) < 25.0:
		return  # let them collect themselves before going again
	if int(it.tries) >= 3:
		it.phase = "held"
		it.kind = "hold"
		it.pos = world.nav.nearest_walkable(_centroid(sqs, []) if not sqs.is_empty() else it.pos)
		it.t = world.time
		_deploy(it, it.pos)
		world.send_msg(int(it.team), "radio", "XO: the attack on %s has stalled. %s holding at %s." % [Defs.grid_ref(it.target), ", ".join(_names(it)), Defs.grid_ref(it.pos)], it.pos)
		world.stat("delegate_stalled")
		return
	_assault(it)
	world.send_msg(int(it.team), "radio", "XO: %s going in again on %s." % [", ".join(_names(it)), Defs.grid_ref(it.pos)], it.pos)


func _assault(it: Dictionary) -> void:
	var sqs: Array = []
	for sq in _squads(it):
		if not _battered(it, sq):
			sqs.append(sq)
	var pos: Vector3 = it.pos
	var c := _centroid(sqs, _vehicles(it))
	var face: Vector3 = Defs.flat(pos - c).normalized() if Defs.flat(pos - c).length() > 2.0 else it.face
	var lat := face.cross(Vector3.UP).normalized()
	var n := sqs.size()
	for i in n:
		var sq: Squad = sqs[i]
		sq.order_n += 1
		sq.order_assault(pos + lat * (i - (n - 1) / 2.0) * 13.0, face, n == 1)
	if n >= 2:
		AttackPlan.make(world, sqs, pos, face)
	var vs := _vehicles(it)
	for i in vs.size():
		var v: Vehicle = vs[i]
		v.order_assault(pos + lat * (i - (vs.size() - 1) / 2.0) * 9.0 - face * 18.0)
	it.phase = "attack"
	it.tries = int(it.tries) + 1
	it.t = world.time


## Screen: a thin line well out in front, there to see the enemy coming and
## warn of it, not to stop him. A squad that's pressed by more than it can
## hold falls back a bound to the next line - twice - and then holds.
func _screen(it: Dictionary) -> void:
	var face: Vector3 = it.face
	for sq in _squads(it):
		if _battered(it, sq):
			continue
		var slot: Vector3 = it.slot.get(sq.sid, it.pos)
		var line: int = int(it.line.get(sq.sid, 0))
		var alive: int = sq.alive_members().size()
		var c: Vector3 = sq.centroid()
		var press := _enemy_count(int(it.team), c, 70.0)
		if line < 2 and press > 0 and (press >= alive or _pinned(sq) or world.time - sq.last_cas_t < 4.0) and sq.drill != "rout":
			slot = world.nav.nearest_walkable(slot - face * 45.0)
			it.slot[sq.sid] = slot
			it.line[sq.sid] = line + 1
			sq.order_n += 1
			sq.order_move(slot, face, 1)
			sq.then_defend = [slot, face]
			_say(it, "fallback%d_%d" % [sq.sid, line], "XO: %s pressed by %d - falling back to the next screen line." % [sq.callsign(), press], slot)
			world.stat("delegate_screen_fallback")
			continue
		if sq.plan != null or sq.drill != "" or not sq.then_defend.is_empty():
			continue
		if sq.order != "defend" or Defs.flat(sq.order_pos - slot).length() > 12.0:
			_defend(sq, slot, face)
	_keep_vehicles(it)
	_report_contact(it, it.pos, 120.0)


## Reserve: wait out of the fight, and go where it's needed - a squad of ours
## near by that's pinned, bleeding or stuck at the fix of an attack - joining
## its attack if it has one. When that fight is over, back to the waiting
## place.
func _reserve(it: Dictionary) -> void:
	var team: int = it.team
	var sqs := _squads(it)
	if it.phase == "committed":
		var calm: bool = _enemy_count(team, it.target, 55.0) == 0
		var planning := false
		for sq in sqs:
			if sq.plan != null:
				planning = true
		var waited := world.time - float(it.t)
		if (calm and not planning and waited > 30.0) or waited > 300.0:
			it.phase = "ready"
			it.t = world.time
			_deploy(it, it.pos)
			world.send_msg(team, "radio", "XO: %s back in reserve at %s." % [", ".join(_names(it)), Defs.grid_ref(it.pos)], it.pos)
		return
	for sq in sqs:
		if sq.plan == null and sq.drill == "" and sq.then_defend.is_empty() and (sq.order != "defend" or Defs.flat(sq.order_pos - (it.slot.get(sq.sid, it.pos) as Vector3)).length() > 12.0):
			_defend(sq, it.slot.get(sq.sid, it.pos), it.face)
	_keep_vehicles(it)
	if world.time - float(it.t) < 6.0:
		return
	# who needs help?
	var best: Squad = null
	var bs := -1e9
	for f in world.squads.values():
		if f.team != team or of_squad.get(f.sid, 0) == it.id or not f.has_alive_members():
			continue
		var fc: Vector3 = f.centroid()
		var d := Defs.flat(fc - it.pos).length()
		if d > 260.0 or not f.in_combat():
			continue
		var need := 0.0
		if _pinned(f):
			need += 2.0
		if world.time - f.last_cas_t < 15.0:
			need += 1.5
		if f.plan != null and not f.plan.done and f.plan.phase == "fix":
			need += 2.0
		if f.alive_members().size() * 2 < f.members.size():
			need += 1.0
		if need < 2.0:
			continue
		var s := need * 60.0 - d
		if s > bs:
			bs = s
			best = f
	if best == null:
		return
	var tgt: Vector3 = best.centroid()
	var th: Dictionary = best._nearest_threat(tgt, 120.0)
	if not th.is_empty():
		tgt = th.pos
	var fresh: Array = []
	for sq in sqs:
		if not _battered(it, sq) and sq.drill == "":
			fresh.append(sq)
	if fresh.is_empty() and _vehicles(it).is_empty():
		return
	it.phase = "committed"
	it.t = world.time
	if best.plan != null and not best.plan.done:
		tgt = best.plan.objective
		for sq in fresh:
			sq.order_n += 1
			best.plan.join(sq)
	else:
		var face: Vector3 = Defs.flat(tgt - _centroid(fresh, [])).normalized() if not fresh.is_empty() else it.face
		var lat := face.cross(Vector3.UP).normalized()
		for i in fresh.size():
			fresh[i].order_n += 1
			fresh[i].order_assault(tgt + lat * (i - (fresh.size() - 1) / 2.0) * 13.0, face, fresh.size() == 1)
		if fresh.size() >= 2:
			AttackPlan.make(world, fresh, tgt, face)
	for v in _vehicles(it):
		v.order_assault(tgt)
	it.target = tgt
	world.send_msg(team, "radio", "XO: reserve committed - %s moving up to support %s at %s." % [", ".join(_names(it)), best.callsign(), Defs.grid_ref(tgt)], tgt)
	world.stat("delegate_reserve_committed")


## Ambush: each squad lays its own on the road (a killing zone each, side by
## side along it), springs it, gets out, and - while the intent stands - lays
## it again a little later.
func _ambush(it: Dictionary) -> void:
	for sq in _squads(it):
		if _battered(it, sq):
			continue
		if sq.ambush_plan != null or sq.drill in ["withdraw", "rout"]:
			it.wait.erase(sq.sid)
			continue
		if not it.wait.has(sq.sid):
			it.wait[sq.sid] = world.time + 25.0
		elif world.time > float(it.wait[sq.sid]) and sq.drill == "" and sq.plan == null:
			it.wait.erase(sq.sid)
			_lay_ambush(it, sq)
			world.stat("delegate_ambush_relaid")
	_keep_vehicles(it)


func _lay_ambush(it: Dictionary, sq: Squad) -> void:
	if sq == null or sq.alive_members().size() < 2:
		return
	var i: int = (it.squads as Array).find(sq.sid)
	var site := _road_site(it.pos, it.face)
	var along: Vector3 = site[1]
	# side by side along the road: the second one's killing zone beyond the first's
	var k := 0.0 if i <= 0 else (float((i + 1) / 2) * (1.0 if i % 2 == 1 else -1.0))
	var kz: Vector3 = (site[0] as Vector3) + along * k * SPREAD.ambush
	sq.order_n += 1
	sq.then_defend = []
	AmbushPlan.make(world, sq, kz, along, site[2])
	it.slot[sq.sid] = kz


## [killing zone, along the road, towards the ambush line] for an ambush
## asked for at p: on the nearest road if there's one close by, along it;
## otherwise across the way they're facing. The ambushers lie on the side
## the commander dragged from (the side they'll be facing from).
func _road_site(p: Vector3, face: Vector3) -> Array:
	var best_d := 40.0
	var best := []
	for team_roads in world.roads:
		for pl in team_roads:
			var poly: PackedVector3Array = pl
			for j in range(1, poly.size()):
				var a: Vector3 = poly[j - 1]
				var b: Vector3 = poly[j]
				var ab := Defs.flat(b - a)
				if ab.length() < 0.5:
					continue
				var u := clampf(Defs.flat(p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				var q: Vector3 = a + (b - a) * u
				var d := Defs.flat(p - q).length()
				if d < best_d:
					best_d = d
					best = [q, ab.normalized()]
	var toward := -Defs.flat(face).normalized()
	if best.is_empty():
		return [p, face.cross(Vector3.UP).normalized(), toward]
	var along: Vector3 = best[1]
	var n := along.cross(Vector3.UP).normalized()
	var side := n if n.dot(toward) >= 0.0 else -n
	if not world.nav.walkable((best[0] as Vector3) + side * AmbushPlan.STANDOFF) and world.nav.walkable((best[0] as Vector3) - side * AmbushPlan.STANDOFF):
		side = -side
	return [best[0], along, side]


# --- shared ----------------------------------------------------------------------------

## A squad too cut up to carry on goes back to refit, and back to you.
func _battered(it: Dictionary, sq: Squad) -> bool:
	if sq.alive_members().size() * 3 >= sq.members.size() or sq.members.size() < 3:
		return false
	sq.order_n += 1
	sq.order_retreat()
	of_squad.erase(sq.sid)
	it.squads.erase(sq.sid)
	world.send_msg(int(it.team), "radio", "XO: %s is too cut up to carry on - pulling back to refit. Back under your command." % sq.callsign(), sq.centroid())
	world.stat("delegate_refit")
	return true


func _defend(sq: Squad, p: Vector3, face: Vector3) -> void:
	sq.order_n += 1
	sq.order_defend(p, face)


func _vmove(it: Dictionary, v: Vehicle, p: Vector3) -> void:
	var q := world.nav.nearest_walkable(p)
	it.slot[-v_key(v)] = q
	v.order_move(q)


## Vehicles drift back to their places once they've finished what they were doing.
func _keep_vehicles(it: Dictionary) -> void:
	for v in _vehicles(it):
		var spot = it.slot.get(-v_key(v))
		if spot == null or v.path_i < v.path.size() or v.brain_state != "":
			continue
		if Defs.flat(v.position - (spot as Vector3)).length() > 18.0:
			v.order_move(spot)


## Vehicles' slots share the dictionary with squads' (keyed by -eid - 1, so
## they never meet a squad id).
static func v_key(v: Vehicle) -> int:
	return v.eid + 1


## Once in a while, what the line can see of the enemy, on the net (with the
## place, so the alert key goes there).
func _report_contact(it: Dictionary, at: Vector3, r: float) -> void:
	var n := _enemy_count(int(it.team), at, r)
	if n < 2:
		return
	_say(it, "contact%d" % int(world.time / 45.0), "XO: %s reports contact - %d enemy near %s." % [_names(it)[0] if not _names(it).is_empty() else "the line", n, Defs.grid_ref(at)], at)


func _say(it: Dictionary, key: String, text: String, at: Vector3) -> void:
	if it.said.has(key):
		return
	it.said[key] = world.time
	if it.said.size() > 24:
		it.said.clear()
		it.said[key] = world.time
	world.send_msg(int(it.team), "radio", text, at)


## Enemy soldiers (a vehicle counts as three) the side can see within r of p.
func _enemy_count(team: int, p: Vector3, r: float) -> int:
	var n := 0
	for s in world.soldiers_near(p, r):
		if s.team >= 0 and s.team != team and s.life == Soldier.Life.ALIVE and s.visible_to_team(team):
			n += 1
	for v in world.vehicles_near(p, r):
		if v.team >= 0 and v.team != team and not v.gone and v.visible_to_team(team):
			n += 3
	return n


func _pinned(sq: Squad) -> bool:
	var alive: Array = sq.alive_members()
	if alive.is_empty():
		return false
	var p := 0
	for m in alive:
		if (m.flags & Soldier.F_PINNED) != 0:
			p += 1
	return p * 2 >= alive.size()


func _drop_plans(sq: Squad) -> void:
	if sq.ambush_plan != null:
		sq.ambush_plan.done = true
		sq.ambush_plan = null
		sq.shown_order = ""
	sq.then_defend = []


## Units gone, dead, or no longer a player's (they went to the AI when their
## commander left) are no longer delegated.
func _prune(it: Dictionary) -> void:
	for sid in (it.squads as Array).duplicate():
		var sq: Squad = world.squads.get(sid)
		if sq == null or not sq.has_alive_members() or sq.owner <= 0 or sq.team != int(it.team):
			it.squads.erase(sid)
			of_squad.erase(sid)
	for eid in (it.vehicles as Array).duplicate():
		var v = world.entities.get(eid)
		if not (v is Vehicle) or v.gone or v.owner_peer <= 0 or v.team != int(it.team):
			it.vehicles.erase(eid)
			of_vehicle.erase(eid)


func _drop_empty() -> void:
	for id in intents.keys():
		var it: Dictionary = intents[id]
		if (it.squads as Array).is_empty() and (it.vehicles as Array).is_empty():
			intents.erase(id)


func _squads(it: Dictionary) -> Array:
	var out := []
	for sid in it.squads:
		var sq: Squad = world.squads.get(sid)
		if sq:
			out.append(sq)
	return out


func _vehicles(it: Dictionary) -> Array:
	var out := []
	for eid in it.vehicles:
		var v = world.entities.get(eid)
		if v is Vehicle and not v.gone:
			out.append(v)
	return out


func _names(it: Dictionary) -> Array:
	var out := []
	for sq in _squads(it):
		out.append(sq.callsign())
	for v in _vehicles(it):
		out.append(v.display_name())
	return out


func _centroid(sqs: Array, vehs: Array) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for sq in sqs:
		c += sq.centroid()
		n += 1
	for v in vehs:
		c += v.position
		n += 1
	return c / maxf(1, n)
