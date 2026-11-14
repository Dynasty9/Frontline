class_name Adviser
extends RefCounted
## Play vs AI's adviser: what a staff officer would say to a new commander who
## has stopped, unsure what to do. It suggests where to go, in the missions'
## lettered style ("Take the village of Elmstead", nearest first), and now and
## then says a quiet word when something's going begging: supply piling up
## unspent, squads standing idle for minutes, a FOB under attack.
##
## It's this player's own: it runs wherever the player's view is (the host's
## or a client's), from what that player is sent (World.team_info, the towns),
## and changes nothing in the battle. It keeps out of an experienced player's
## way: every word waits a long while before it's said and is said only a few
## times a battle, the suggestions stop once the player holds a few towns, and
## Settings > Interface > Adviser turns the lot off.

const RETIRE_TOWNS := 4  # holding this many, the player knows what towns are for
const SUPPLY_HIGH := 400  # supply sitting at the FOBs that counts as unspent...
const SUPPLY_SECS := 90.0  # ...for this long
const IDLE_SECS := 120.0  # a squad of yours with no orders and nothing to shoot, this long
const SAY_SECS := 14.0  # how long a word stays up
## kind -> [seconds before it may be said again, times a battle at most]
const PACE := {"fob": [60.0, 4], "idle": [180.0, 3], "supply": [240.0, 3]}

var world: World
var team := 0
## the suggestions, as the HUD draws a mission's objectives:
## [letter, text, state, kind, pos, radius, progress, optional]
var objs: Array = []
var word := ""  # what it's saying now ("" nothing); {action} for keys, see Keys.fill
var word_kind := ""
var word_t := -1e9  # world time it was said
var said := {}  # kind -> times said
var _next := {}  # kind -> world time it may be said again
var _t := 0.0
var _towns: Array = []
var _picked := {}  # town eid -> letter, while suggested
var _taken := {}  # town eid -> world time it fell to us (shown done a moment)
var _rich_since := -1.0
var _idle := {}  # sid -> [order number, since]
var _fob_hp := {}  # eid -> hp last time


## Whether this battle wants one: the player commanding a side against the AI,
## not a mission, a scenario or a replay.
static func wanted(w: World) -> bool:
	if w.local_team < 0 or w.local_team > 1 or w.settings.get("replay", false):
		return false
	if String(w.settings.get("mission", "")) != "" or String(w.settings.get("scenario", "")) != "":
		return false
	return (1 - w.local_team) in (w.settings.get("ai_teams", []) as Array)


func _init(w: World) -> void:
	world = w
	team = w.local_team


static func on() -> bool:
	return bool(Settings.get_v("adviser"))


func tick() -> void:
	if not on():
		objs = []
		word = ""
		return
	if world.time < _t:
		return
	_t = world.time + 1.0
	if team >= world.team_info.size() or not (world.team_info[team] is Dictionary) or (world.team_info[team] as Dictionary).is_empty():
		return
	var ti: Dictionary = world.team_info[team]
	_suggest(ti)
	_watch_fobs(ti)
	_watch_idle(ti)
	_watch_supply(ti)


# --- where to go ------------------------------------------------------------------------

func _suggest(ti: Dictionary) -> void:
	if _towns.is_empty():
		for st in world.structures:
			if st.skind == "town":
				_towns.append(st)
	var held := 0
	for tn in _towns:
		if is_instance_valid(tn) and tn.team == team:
			held += 1
	if held >= RETIRE_TOWNS and _taken.is_empty():
		objs = []
		_picked.clear()
		return
	# from home: the middle of our FOBs (where the force comes from)
	var home := Vector3.ZERO
	var nf := 0
	for f in ti.get("fobs", []):
		var fe = world.entities.get(int(f[0]))
		if fe != null and is_instance_valid(fe):
			home += fe.position
			nf += 1
	if nf == 0:
		objs = []
		return
	home /= float(nf)
	# a suggested town that's ours now is shown done a moment, then makes way
	for eid in _picked.keys():
		var tn = world.entities.get(int(eid))
		if tn == null or not is_instance_valid(tn):
			_picked.erase(eid)
		elif tn.team == team and not _taken.has(eid):
			_taken[eid] = world.time
			world.stat("adviser_town_taken")
	for eid in _taken.keys():
		if world.time - float(_taken[eid]) > 8.0:
			_taken.erase(eid)
			_picked.erase(eid)
	# the nearest towns not ours: nobody's first, then the enemy's
	var cands := []
	for tn in _towns:
		if not is_instance_valid(tn) or tn.team == team or _picked.has(tn.eid):
			continue
		var dd := Defs.flat(tn.position - home).length() + (0.0 if tn.team < 0 else 250.0)
		cands.append([dd, tn])
	cands.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var used := {}
	for eid in _picked:
		used[String(_picked[eid])] = true
	for c in cands:
		if _picked.size() >= 2:
			break
		var letter := "A" if not used.has("A") else "B"
		used[letter] = true
		_picked[c[1].eid] = letter
		world.stat("adviser_suggest")
	var out := []
	for eid in _picked:
		var tn: Structure = world.entities[eid]
		var what := "town" if tn.variant == 1 else "village"
		var text := ("Take the %s of %s" % [what, tn.sname]) if tn.team < 0 or _taken.has(eid) else ("Take %s from the enemy" % tn.sname)
		if _taken.has(eid):
			text = "Take the %s of %s" % [what, tn.sname]
		var st := MissionDirector.DONE if _taken.has(eid) else MissionDirector.ACTIVE
		out.append([String(_picked[eid]), text, st, "clear", tn.position, 40.0, "", true])
	out.sort_custom(func(a, b): return String(a[0]) < String(b[0]))
	objs = out


# --- a quiet word -------------------------------------------------------------------------

func _say(kind: String, text: String) -> void:
	var p: Array = PACE[kind]
	if world.time < float(_next.get(kind, 0.0)) or int(said.get(kind, 0)) >= int(p[1]):
		return
	# one at a time: a newer word waits for the last to have been read
	if word != "" and world.time - word_t < SAY_SECS and word_kind != kind and kind != "fob":
		return
	_next[kind] = world.time + float(p[0])
	said[kind] = int(said.get(kind, 0)) + 1
	word = text
	word_kind = kind
	word_t = world.time
	world.stat("adviser_" + kind)


## What it's saying, while it's still up ("" when nothing is).
func current() -> String:
	if not on() or word == "" or world.time - word_t > SAY_SECS:
		return ""
	return word


func _watch_fobs(ti: Dictionary) -> void:
	for f in ti.get("fobs", []):
		var eid := int(f[0])
		var fe = world.entities.get(eid)
		if fe == null or not is_instance_valid(fe) or fe.wrecked:
			continue
		var was := float(_fob_hp.get(eid, fe.hp))
		_fob_hp[eid] = fe.hp
		if fe.hp < was - 5.0:
			_say("fob", "FOB %s is under attack. {jump_alert} takes you there: send a squad to it with {defend}." % String(f[1]))


func _watch_idle(ti: Dictionary) -> void:
	var orders: Dictionary = ti.get("sq", {})
	var delegated := {}
	for it in ti.get("dg", []):
		for sid in it[4]:
			delegated[int(sid)] = true
	# my squads: those with a man of mine standing on his own feet
	var mine := {}
	var busy := {}
	for s in world.soldiers:
		if s.team != team or s.owner_peer != world.local_peer or s.sid == 0 or s.life != Soldier.Life.ALIVE:
			continue
		if s.riding != null:
			busy[s.sid] = true
		if (s.flags & (Soldier.F_SHOOTING | Soldier.F_SUPP | Soldier.F_PINNED)) != 0:
			busy[s.sid] = true
		mine[s.sid] = true
	var n := 0
	for sid in mine:
		var o: Array = orders.get(sid, [])
		var idle := not o.is_empty() and String(o[0]) in ["hold", "stop"] and not busy.has(sid) and not delegated.has(sid)
		var was: Array = _idle.get(sid, [-1, world.time])
		if not idle or int(o[3]) != int(was[0]):
			_idle[sid] = [int(o[3]) if not o.is_empty() else -1, world.time]
			continue
		if world.time - float(was[1]) >= IDLE_SECS:
			n += 1
	for sid in _idle.keys():
		if not mine.has(sid):
			_idle.erase(sid)
	if n > 0:
		var who := "A squad has" if n == 1 else "%d squads have" % n
		_say("idle", "%s stood idle for two minutes. Select and right-click to move, {attack_move} to push, or {delegate} to hand them to your XO." % who)


func _watch_supply(ti: Dictionary) -> void:
	var sup := int(ti.get("supply", 0))
	var full := int(ti.get("units", 0)) >= int(ti.get("cap", 1 << 30))
	if sup < SUPPLY_HIGH or full:
		_rich_since = -1.0
		return
	if _rich_since < 0.0:
		_rich_since = world.time
	elif world.time - _rich_since >= SUPPLY_SECS:
		_say("supply", "%d supply is sitting unspent. Train squads at a barracks or factory, or have engineers build: select one and use the command card." % sup)
		_rich_since = world.time


## For the test port: what it's suggesting and saying.
func state() -> Dictionary:
	return {"on": on(), "objs": objs.duplicate(true), "word": current(), "kind": word_kind if current() != "" else "", "said": said.duplicate()}
