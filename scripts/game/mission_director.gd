class_name MissionDirector
extends RefCounted
## A mission, run on the server: the force on each side, the objectives, the
## scripted events (radio calls, counterattacks, reinforcements) and the end.
## The content - who is where and what happens when - lives in Missions; this
## is the machinery it runs on. Its state goes to every peer as a small
## dictionary (world.mission_info) for the HUD's objectives panel and markers.

enum {HIDDEN, ACTIVE, DONE, FAILED}

var world: World
var mg: MapGen
var key := ""
var def: Dictionary = {}
var side := 0  # the players' side
var foe := 1
var owners: Array = []  # who commands the players' force: the human peers on that side, or the AI
var autopilot := false  # nobody to command it (tests, or everyone left): the mission's own driver gives the orders
var objs: Array = []
var over := 0  # 0 running, 1 accomplished, 2 failed
var end_text := ""
var start_t := 0.0
var deadline := 0.0  # world time the mission fails at (0: no limit)
var deadline_text := ""
var support: Array = []  # the off-map support on call (empty: none)
var focus := Vector3.INF  # where the camera opens
var focus_yaw := 0.0
var feat := {}  # the map's features (see Missions.survey)
var content: Missions
var dirty := true
var _events: Array = []  # [world time, Callable]
var _eval_t := 0.0
var _send_t := 0.0
var _drive_t := 2.0
var _own_i := 0
var _letters := 0
var _ours := {}  # eid -> true: every man of the players' force, for the casualty count
var _theirs := {}  # eid -> true: every enemy, for the kill count


func _init(w: World, mission_key: String, gen: MapGen) -> void:
	world = w
	key = mission_key
	mg = gen
	def = Missions.find(key)
	side = int(def.get("side", 0))
	foe = 1 - side
	var pl: Dictionary = world.settings.get("players", {})
	for id in pl:
		if int(pl[id].team) == side:
			owners.append(int(id))
	if owners.is_empty():
		owners.append(-1 - side)
		autopilot = true
	if world.settings.get("mission_autoplay", false):
		autopilot = true
	content = Missions.new()


## Builds the mission on the freshly generated map.
func setup() -> void:
	feat = Missions.survey(world)
	start_t = world.time
	content.setup(self)
	if OS.has_environment("FL_DEBUG_MISSION"):
		print("MISSION %s side=%d owners=%s autopilot=%s focus=%s" % [key, side, str(owners), str(autopilot), str(focus)])
		for k in content.ctx:
			if content.ctx[k] is Vector3:
				print("MISSION   %s = %s" % [k, str((content.ctx[k] as Vector3).round())])


# --- building the mission (called by the content) ----------------------------------

## The next owner for a unit of the players' force: shared out in turn between
## the players, so in co-op each commands a part of it.
func next_owner() -> int:
	var o: int = owners[_own_i % owners.size()]
	_own_i += 1
	return o


func ai_owner(team: int) -> int:
	return -1 - team


## A squad of the players' force.
func squad(kind: String, pos: Vector3, dest := Vector3.INF) -> Squad:
	return world.rules.spawn_squad(kind, side, next_owner(), world.nav.nearest_walkable(pos), dest)


## An enemy squad (the enemy has no commander in a mission: the content tells
## it what to do, and its own drills do the rest).
func enemy(kind: String, pos: Vector3, dest := Vector3.INF) -> Squad:
	return world.rules.spawn_squad(kind, foe, ai_owner(foe), world.nav.nearest_walkable(pos), dest)


func vehicle(vkind: String, pos: Vector3, yaw: float, team: int, owner: int) -> Vehicle:
	var v: Vehicle = world.spawn("vehicle", {"vkind": vkind, "team": team, "owner": owner, "pos": pos, "yaw": yaw})
	return v


## A new objective (hidden until started). Ones with a place get a letter.
func add(id: String, text: String, kind: String, extra := {}) -> Dictionary:
	var o := {"id": id, "text": text, "kind": kind, "state": HIDDEN, "pos": Vector3.INF, "r": 30.0, "need": -1, "have": 0,
		"secs": 0.0, "prog": 0.0, "eids": [], "optional": false, "label": "", "lost_t": 0.0, "grace": 30.0, "frac": 0.75, "track": false}
	o.merge(extra, true)
	# a place gets a letter and a marker, unless another objective already marks it
	if o.pos is Vector3 and o.pos != Vector3.INF and o.get("mark", true):
		o.label = String.chr(65 + _letters)
		_letters += 1
	objs.append(o)
	return o


func obj(id: String) -> Dictionary:
	for o in objs:
		if o.id == id:
			return o
	return {}


## Sets an objective going; done and failed (Callables) run when it ends.
func start(id: String, done := Callable(), failed := Callable()) -> void:
	var o := obj(id)
	if o.is_empty() or int(o.state) != HIDDEN:
		return
	o.state = ACTIVE
	o.prog = 0.0
	if done.is_valid():
		o["on_done"] = done
	if failed.is_valid():
		o["on_fail"] = failed
	dirty = true
	var ping = o.pos if o.pos is Vector3 and o.pos != Vector3.INF else null
	world.send_msg(side, "intel", ("New objective: %s" % o.text) if not o.optional else ("Optional: %s" % o.text), ping)


## A radio call to the players' side (who's talking goes at the front:
## "Overlord: ...").
func radio(text: String, ping = null) -> void:
	world.send_msg(side, "radio", text, ping)


## Runs cb in secs (game time) unless the mission has ended by then.
func after(secs: float, cb: Callable) -> void:
	_events.append([world.time + secs, cb])


func win(text: String) -> void:
	_finish(true, text)


func fail(text: String) -> void:
	_finish(false, text)


func alive(eid: int) -> bool:
	var e = world.entities.get(eid)
	if e == null or not is_instance_valid(e) or e.gone:
		return false
	if e is Soldier:
		return e.life == Soldier.Life.ALIVE or e.life == Soldier.Life.HIDDEN
	if e is Structure:
		return not e.wrecked and e.hp > 0.0
	return e.hp > 0.0


## Where a man really is: in the vehicle he's riding, if he's riding.
func where(s: Soldier) -> Vector3:
	if s.riding != null and is_instance_valid(s.riding):
		return s.riding.position
	return s.position


func ours(e: Entity) -> bool:
	return e.team == side and e.owner_peer in owners


## Men and vehicles of the players' force inside a circle (helicopters in the
## air don't hold ground).
func ours_in(c: Vector3, r: float) -> int:
	var n := 0
	for s in world.soldiers:
		if s.team == side and s.owner_peer in owners and (s.life == Soldier.Life.ALIVE or (s.life == Soldier.Life.HIDDEN and s.riding != null)):
			if Defs.flat(where(s) - c).length() <= r:
				n += 1
	for v in world.vehicles:
		if v.team == side and v.owner_peer in owners and not v.gone and v.hp > 0.0 and v.position.y < 3.0:
			if Defs.flat(v.position - c).length() <= r:
				n += 1
	return n


## Men of the players' force on their own feet inside a circle (not still
## sitting in a boat or a truck).
func afoot_in(c: Vector3, r: float) -> int:
	var n := 0
	for s in world.soldiers:
		if s.team == side and s.owner_peer in owners and s.life == Soldier.Life.ALIVE and s.riding == null:
			if Defs.flat(s.position - c).length() <= r:
				n += 1
	return n


## Enemy men (in the open, garrisoned or riding) and vehicles inside a circle.
func foes_in(c: Vector3, r: float) -> int:
	var n := 0
	for s in world.soldiers:
		if s.team == foe and (s.life == Soldier.Life.ALIVE or s.life == Soldier.Life.HIDDEN):
			if Defs.flat(where(s) - c).length() <= r:
				n += 1
	for v in world.vehicles:
		if v.team == foe and not v.gone and v.hp > 0.0 and v.position.y < 3.0 and not v.is_auto():
			if Defs.flat(v.position - c).length() <= r:
				n += 1
	return n


# --- running it ---------------------------------------------------------------------

func tick(dt: float) -> void:
	var i := 0
	while i < _events.size():
		if world.time >= float(_events[i][0]):
			var cb: Callable = _events[i][1]
			_events.remove_at(i)
			if over == 0 and cb.is_valid():
				cb.call()
		else:
			i += 1
	_eval_t -= dt
	if _eval_t <= 0.0:
		_eval_t = 0.5
		if over == 0:
			_evaluate(0.5)
	if autopilot and over == 0:
		_drive_t -= dt
		if _drive_t <= 0.0:
			_drive_t = 4.0
			content.drive(self)
	_send_t -= dt
	if _send_t <= 0.0 or dirty:
		_send_t = 1.0
		dirty = false
		world.set_mission_info(info())


func _evaluate(dt: float) -> void:
	_census()
	for o in objs.duplicate():
		if over != 0:
			return
		if int(o.state) != ACTIVE:
			continue
		var c: Vector3 = o.pos if o.pos is Vector3 else Vector3.INF
		var r: float = o.r
		match String(o.kind):
			"reach":
				if _held_by_us(o, c, r) >= maxi(1, int(o.need)):
					_complete(o)
			"clear":
				var e := foes_in(c, r)
				if e != int(o.have):
					o.have = e
					dirty = true
				if e <= maxi(0, int(o.need)) and _held_by_us(o, c, r) > 0:
					_complete(o)
			"hold":
				var f := _held_by_us(o, c, r)
				var e := foes_in(c, r)
				o.have = e
				if f > 0:
					o.prog = float(o.prog) + dt
					o.lost_t = 0.0
				elif e > 0:
					o.lost_t = float(o.lost_t) + dt
					if float(o.lost_t) >= float(o.grace):
						_failed(o)
						continue
				if float(o.prog) >= float(o.secs) and f > e:
					_complete(o)
			"guard":
				# held until the content says otherwise; lost if the enemy has
				# it to themselves for too long
				var f2 := _held_by_us(o, c, r)
				var e2 := foes_in(c, r)
				if e2 != int(o.have):
					o.have = e2
					dirty = true
				if f2 > 0:
					o.lost_t = 0.0
				elif e2 > 0:
					o.lost_t = float(o.lost_t) + dt
					if float(o.lost_t) >= float(o.grace):
						_failed(o)
						continue
			"destroy":
				var left := []
				for id in o.eids:
					if alive(int(id)):
						left.append(int(id))
				var have: int = (o.eids as Array).size() - left.size()
				if have != int(o.have):
					o.have = have
					dirty = true
				if o.track and not left.is_empty():
					o.pos = _centroid(left)
				var need: int = int(o.need) if int(o.need) > 0 else (o.eids as Array).size()
				if have >= need:
					_complete(o)
			"protect":
				var lost := 0
				var left2 := []
				for id in o.eids:
					if alive(int(id)):
						left2.append(int(id))
					else:
						lost += 1
				o.have = lost
				if o.track and not left2.is_empty():
					o.pos = _centroid(left2)
				if lost > maxi(0, int(o.need)):
					_failed(o)
			"timer":
				o.prog = float(o.prog) + dt
				if float(o.prog) >= float(o.secs):
					_complete(o)
			"deliver":
				var id0: int = int(o.eids[0]) if not (o.eids as Array).is_empty() else 0
				if not alive(id0):
					_failed(o)
					continue
				var v: Vehicle = world.entities[id0]
				if v.slung_by == null and v.position.y < 1.0 and Defs.flat(v.position - c).length() <= r:
					_complete(o)
			"extract":
				var tot := 0
				var inn := 0
				for s in world.soldiers:
					if s.team != side or not (s.owner_peer in owners):
						continue
					if s.life != Soldier.Life.ALIVE and not (s.life == Soldier.Life.HIDDEN and s.riding != null):
						continue
					tot += 1
					if Defs.flat(where(s) - c).length() <= r:
						inn += 1
				var need2 := maxi(1, ceili(tot * float(o.frac)))
				if inn != int(o.have) or need2 != int(o.need):
					o.have = inn
					o.need = need2
					dirty = true
				if tot > 0 and inn >= need2:
					_complete(o)
	if over != 0:
		return
	if deadline > 0.0 and world.time >= deadline:
		fail(deadline_text if deadline_text != "" else "Out of time.")
	elif world.time - start_t > 5.0 and _force_gone():
		fail("Your force has been wiped out.")


## The players' force in an objective's area: men on their feet only, for
## ground that has to be taken by infantry ("afoot"), else men and vehicles.
func _held_by_us(o: Dictionary, c: Vector3, r: float) -> int:
	return afoot_in(c, r) if o.get("afoot", false) else ours_in(c, r)


func _complete(o: Dictionary) -> void:
	o.state = DONE
	dirty = true
	world.stat("objective_done")
	world.send_msg(side, "info", "Objective complete: %s" % o.text)
	if o.has("on_done"):
		(o.on_done as Callable).call()


func _failed(o: Dictionary) -> void:
	o.state = FAILED
	dirty = true
	world.stat("objective_failed")
	if o.has("on_fail"):
		(o.on_fail as Callable).call()
	elif not o.optional:
		fail(String(o.get("fail_text", "Objective failed: %s." % o.text)))
	else:
		world.send_msg(side, "alert", "Objective failed: %s" % o.text)


func _centroid(ids: Array) -> Vector3:
	var c := Vector3.ZERO
	for id in ids:
		var e: Entity = world.entities[id]
		c += e.position
	c /= float(ids.size())
	c.y = 0.0
	return c


## Who has fought in it, both sides (for the casualty and kill counts).
func _census() -> void:
	for s in world.soldiers:
		if s.team == side and s.owner_peer in owners:
			_ours[s.eid] = true
		elif s.team == foe:
			_theirs[s.eid] = true


func _down(eid: int) -> bool:
	var e = world.entities.get(eid)
	if e == null or not is_instance_valid(e) or e.gone:
		return true
	return e.life == Soldier.Life.DEAD or e.life == Soldier.Life.SURRENDER or e.life == Soldier.Life.CAPTIVE


## Nobody left to do it: every man of the force dead, captured or down (a
## ship or a helicopter on its own can't take ground).
func _force_gone() -> bool:
	for s in world.soldiers:
		if s.team == side and s.owner_peer in owners and (s.life == Soldier.Life.ALIVE or s.life == Soldier.Life.HIDDEN):
			return false
	return true


func _finish(ok: bool, text: String) -> void:
	if over != 0:
		return
	over = 1 if ok else 2
	end_text = text
	for o in objs:
		if int(o.state) == ACTIVE and ok and String(o.kind) in ["protect", "guard"]:
			o.state = DONE
	_census()
	world.stat("mission_won" if ok else "mission_lost")
	world.set_mission_info(info())
	world.declare_winner(side if ok else foe)


# --- players coming and going -----------------------------------------------------------

## A friend dropping in takes over a share of the force: every other squad (and
## vehicle) of whoever has the most.
func player_joined(id: int) -> void:
	var ai := ai_owner(side)
	if ai in owners:
		owners.erase(ai)
		owners.append(id)
		autopilot = bool(world.settings.get("mission_autoplay", false))
		_hand_over(ai, id, 1)
		return
	owners.append(id)
	var count := {}
	for sq in world.squads.values():
		if sq.team == side and sq.owner in owners:
			count[sq.owner] = int(count.get(sq.owner, 0)) + 1
	var big := 0
	var bn := 0
	for o in count:
		if int(count[o]) > bn:
			bn = int(count[o])
			big = int(o)
	if bn >= 2:
		_hand_over(big, id, 2)


## A player back in the mission (the World has handed back whatever of their
## units still fight). If everyone had gone, the AI's whole force is theirs
## again; if nothing of theirs is left, they take a share like a newcomer.
func player_rejoined(id: int, got_back: bool) -> void:
	if ai_owner(side) in owners or not got_back:
		player_joined(id)
	elif not id in owners:
		owners.append(id)
	dirty = true


## Moves units from one owner to another: all of them (every = 1) or every other one (2).
func _hand_over(from: int, to: int, every: int) -> void:
	var i := 0
	for sq in world.squads.values():
		if sq.owner != from:
			continue
		i += 1
		if i % every != 0:
			continue
		sq.owner = to
		for m in sq.members:
			m.owner_peer = to
			world.push_props(m, {"owner": to})
	i = 0
	for v in world.vehicles:
		if v.owner_peer != from or v.team != side:
			continue
		i += 1
		if i % every != 0:
			continue
		v.owner_peer = to
		world.push_props(v, {"owner": to})


## Someone left: whoever inherits their units now commands part of the force
## (the AI, driving it with the mission's own orders, if nobody is left).
func owner_changed(old: int, new_owner: int) -> void:
	owners.erase(old)
	if not new_owner in owners:
		owners.append(new_owner)
	if new_owner < 0:
		autopilot = true
	dirty = true


# --- what the HUD gets ------------------------------------------------------------------

func info() -> Dictionary:
	var ol := []
	for o in objs:
		if int(o.state) == HIDDEN:
			continue
		var p = o.pos if o.pos is Vector3 and o.pos != Vector3.INF and o.get("mark", true) else null
		ol.append([String(o.label), String(o.text), int(o.state), String(o.kind), p, float(o.r), _prog_text(o), bool(o.optional)])
	var lost := 0
	for id in _ours:
		if _down(int(id)):
			lost += 1
	var kills := 0
	for id in _theirs:
		if _down(int(id)):
			kills += 1
	return {"key": key, "title": String(def.get("title", key)), "op": String(def.get("op", "")), "side": side, "over": over, "end": end_text,
		"el": world.time - start_t, "left": (deadline - world.time) if deadline > 0.0 else -1.0, "objs": ol, "sup": support,
		"focus": focus if focus != Vector3.INF else null, "fyaw": focus_yaw, "lost": [lost, _ours.size()], "kills": kills}


func _prog_text(o: Dictionary) -> String:
	match String(o.kind):
		"hold":
			var left := maxf(0.0, float(o.secs) - float(o.prog))
			var t := "%d:%02d" % [int(left) / 60, int(left) % 60]
			if int(o.state) == ACTIVE and int(o.have) > 0:
				t += "  contested"
			return t
		"timer":
			var left2 := maxf(0.0, float(o.secs) - float(o.prog))
			return "%d:%02d" % [int(left2) / 60, int(left2) % 60]
		"destroy":
			var need: int = int(o.need) if int(o.need) > 0 else (o.eids as Array).size()
			return "%d/%d" % [mini(int(o.have), need), need]
		"extract":
			return "%d/%d" % [int(o.have), maxi(1, int(o.need))]
		"clear":
			if int(o.state) == ACTIVE and int(o.have) > 0 and int(o.have) <= 4:
				return "%d left" % int(o.have)
		"guard":
			if int(o.state) == ACTIVE and int(o.have) > 0:
				return "contested"
	return ""
