class_name BattleStats
extends RefCounted
## The battle's record, kept on the host: who killed what, who lost what, what
## each commander spent and fielded, and how the two sides' strength rose and
## fell. It is the raw material of the after-action report (hold Tab in a
## battle, and the screen at the end). Everything is credited to the commander
## whose unit did it - a player's peer id, or a side's AI (-1 - team) - and to
## that side's totals; a unit nobody commands only counts for its side.

## What every commander's (and each side's) record counts.
const FIELDS := ["kills", "downs", "veh_kills", "bld_kills", "lost", "wounded", "captured", "veh_lost", "bld_lost",
	"shots", "hits", "dmg", "val_killed", "val_lost", "spent", "squads", "vehicles", "built", "research", "support",
	"captures", "towns", "prisoners", "revived", "delivered"]
## Strength over time: a sample this often (doubling, and thinning the old
## samples, whenever a long battle fills the record).
const SAMPLE_EVERY := 10.0
const MAX_SAMPLES := 240
const MAX_EVENTS := 90
## A soldier with no squad price to go by (crews, mechanised infantry that
## came with their carrier) is worth this much supply.
const MAN_VALUE := 20.0

var world: World
var players := {}  # owner -> record (FIELDS plus name, team, ai)
var sides: Array = []  # per side: FIELDS
var units := {}  # "s<sid>" / "v<eid>" -> {name, kind, team, owner, t0, t1, men, alive, kills, downs, veh_kills, lost}
var heroes := {}  # soldier eid -> {name, role, team, owner, unit, kills, veh, alive}
var timeline: Array = []  # [t, men0, men1, veh0, veh1, kills0, kills1, supply0, supply1]
var events: Array = []  # [t, team, kind, text]: FOBs and towns, vehicles lost, fire support
var every := SAMPLE_EVERY
var _sample_t := 0.0
var _blame: Array = []  # [owner, team] while a blast nobody fired goes off (fire support, a mine)


func _init(w: World) -> void:
	world = w
	for t in 2:
		sides.append(_blank())
	# every commander has a line in the report, even one who never fires a shot
	var pl: Dictionary = world.settings.get("players", {})
	for id in pl:
		joined(int(id), int(pl[id].team))
	for t in world.settings.get("ai_teams", []):
		joined(-1 - int(t), int(t))


func joined(owner: int, team: int) -> void:
	if team >= 0 and team <= 1:
		_rec(owner, team)


static func _blank() -> Dictionary:
	var r := {}
	for f in FIELDS:
		r[f] = 0.0
	return r


## A commander's record, started the first time they do anything.
func _rec(owner: int, team: int) -> Dictionary:
	if players.has(owner):
		return players[owner]
	var r := _blank()
	r["team"] = team
	r["ai"] = owner < 0
	r["name"] = _name_of(owner, team)
	players[owner] = r
	return r


func _name_of(owner: int, team: int) -> String:
	if owner > 0:
		var pl: Dictionary = Net.players.get(owner, world.settings.get("players", {}).get(owner, {}))
		return String(pl.get("name", "Player %d" % owner))
	if world.mission != null and team == world.mission.foe:
		return "Opposing forces"
	return "AI Commander"


func add(owner: int, team: int, field: String, n := 1.0) -> void:
	if team < 0 or team > 1:
		return
	var sd: Dictionary = sides[team]
	sd[field] += n
	if owner != 0:
		var r := _rec(owner, team)
		r[field] += n


func _unit_add(key: String, field: String, n := 1) -> void:
	if units.has(key):
		units[key][field] = int(units[key][field]) + n


## A round fired (every one: this is the hot path, so no allocations).
func shot(shooter: Entity, hit: bool) -> void:
	if shooter.team < 0 or shooter.team > 1:
		return
	add(shooter.owner_peer, shooter.team, "shots")
	if hit:
		add(shooter.owner_peer, shooter.team, "hits")


# --- who did it ----------------------------------------------------------------------------

## Who gets the credit for what src did: [owner, team, unit key, soldier eid],
## or [] for nobody (a falling wall, the wreck of his own truck).
func _who(src) -> Array:
	if src != null and is_instance_valid(src) and src is Entity:
		var e: Entity = src
		if e.team < 0 or e.team > 1:
			return []
		var key := ""
		var se := 0
		if e is Soldier:
			se = e.eid
			if (e as Soldier).sid != 0:
				key = "s%d" % (e as Soldier).sid
		elif e is Vehicle:
			key = "v%d" % e.eid
		return [e.owner_peer, e.team, key, se]
	return _blame


## A blast with no shooter (support called in, a mine, a burning wreck) is
## the work of whoever sent it.
func blame(owner: int, team: int) -> Array:
	return blame_hit([owner, team, "", 0] if team >= 0 and team <= 1 else [])


## Sets who is to blame for what happens next; returns who was before, for end_blame.
func blame_hit(by: Array) -> Array:
	var prev := _blame
	_blame = by
	return prev


func end_blame(prev: Array = []) -> void:
	_blame = prev


## The last enemy to hurt e is the one who gets the kill, even if he bleeds
## out a minute later.
func _mark(e: Entity, src) -> Array:
	var w := _who(src)
	if w.is_empty() or int(w[1]) == e.team:
		return []
	e.hit_by = w
	return w


# --- soldiers --------------------------------------------------------------------------------

func soldier_hit(s: Soldier, amount: float, src) -> void:
	var w := _mark(s, src)
	if not w.is_empty() and s.life == Soldier.Life.ALIVE:
		add(int(w[0]), int(w[1]), "dmg", minf(amount, maxf(s.hp, 0.0)))


func soldier_down(s: Soldier) -> void:
	if s.is_bearer():
		return
	add(s.owner_peer, s.team, "wounded")
	var w: Array = s.hit_by
	if not w.is_empty():
		add(int(w[0]), int(w[1]), "downs")
		_unit_add(String(w[2]), "downs")


## Called as he dies (his life not yet DEAD): a prisoner was already counted
## lost when he was taken.
func soldier_died(s: Soldier) -> void:
	if s.life == Soldier.Life.CAPTIVE or s.team < 0 or s.is_bearer():
		return
	var val := man_value(s)
	add(s.owner_peer, s.team, "lost")
	add(s.owner_peer, s.team, "val_lost", val)
	if s.sid != 0:
		_unit_add("s%d" % s.sid, "lost")
	if heroes.has(s.eid):
		heroes[s.eid].alive = false
	var w: Array = s.hit_by
	if w.is_empty():
		return
	add(int(w[0]), int(w[1]), "kills")
	add(int(w[0]), int(w[1]), "val_killed", val)
	_unit_add(String(w[2]), "kills")
	_hero(w, "kills")


func _hero(w: Array, field: String) -> void:
	var eid := int(w[3])
	if eid == 0:
		return
	var h: Dictionary = heroes.get(eid, {})
	if h.is_empty():
		var s = world.entity(eid)
		if not (s is Soldier):
			return
		h = {"name": s.sname, "role": String(Defs.UNITS.get(s.utype, {}).get("name", s.utype)), "team": s.team, "owner": s.owner_peer,
			"unit": String(w[2]), "kills": 0, "veh": 0, "alive": s.life != Soldier.Life.DEAD}
		heroes[eid] = h
	h[field] = int(h[field]) + 1


func revived(s: Soldier) -> void:
	add(s.owner_peer, s.team, "revived")


func prisoner(p: Soldier, captor: Soldier) -> void:
	var val := man_value(p)
	add(p.owner_peer, p.team, "captured")
	add(p.owner_peer, p.team, "val_lost", val)
	if p.sid != 0:
		_unit_add("s%d" % p.sid, "lost")
	add(captor.owner_peer, captor.team, "prisoners")
	add(captor.owner_peer, captor.team, "val_killed", val)


## What a man cost: his squad's price shared between its members.
static func man_value(s: Soldier) -> float:
	if s.squad != null and Defs.SQUADS.has(s.squad.kind):
		var d: Dictionary = Defs.SQUADS[s.squad.kind]
		if int(d.cost) > 0:
			return float(d.cost) / maxf(1.0, (d.members as Array).size())
	return MAN_VALUE


# --- vehicles and buildings ------------------------------------------------------------------

func vehicle_hit(v: Vehicle, amount: float, src) -> void:
	var w := _mark(v, src)
	if not w.is_empty():
		add(int(w[0]), int(w[1]), "dmg", minf(amount, maxf(v.hp, 0.0)))


func vehicle_destroyed(v: Vehicle) -> void:
	if v.team < 0 or v.team > 1:
		return
	var val := float(v.vdef.get("cost", 0))
	add(v.owner_peer, v.team, "veh_lost")
	add(v.owner_peer, v.team, "val_lost", val)
	var u: Dictionary = units.get("v%d" % v.eid, {})
	if not u.is_empty():
		u.t1 = world.time
		u.alive = 0
	_event(v.team, "veh", "%s %s lost" % [Defs.TEAM_NAMES[v.team], v.display_name()])
	var w: Array = v.hit_by
	if w.is_empty():
		return
	add(int(w[0]), int(w[1]), "veh_kills")
	add(int(w[0]), int(w[1]), "val_killed", val)
	_unit_add(String(w[2]), "veh_kills")
	_hero(w, "veh")


func vehicle_fielded(v: Vehicle) -> void:
	if v.team < 0 or v.team > 1 or v.is_auto() or v.vkind == "truck":
		return
	units["v%d" % v.eid] = {"name": v.display_name(), "kind": "vehicle", "team": v.team, "owner": v.owner_peer, "t0": world.time, "t1": -1.0,
		"men": 0, "alive": 1, "kills": 0, "downs": 0, "veh_kills": 0, "lost": 0}


func structure_hit(st: Structure, src) -> void:
	_mark(st, src)


## A building of a side's own knocked down (or a FOB wrecked).
func building_destroyed(st: Structure) -> void:
	if st.team < 0 or st.team > 1:
		return
	var val := float(Defs.BUILDINGS.get(st.skind, {}).get("cost", 0))
	add(st.owner_peer, st.team, "bld_lost")
	add(st.owner_peer, st.team, "val_lost", val)
	if st.skind == "fob":
		_event(st.team, "fob", "FOB %s wrecked" % st.sname)
	var w: Array = st.hit_by
	if w.is_empty():
		return
	add(int(w[0]), int(w[1]), "bld_kills")
	add(int(w[0]), int(w[1]), "val_killed", val)


func built(st: Structure) -> void:
	add(st.owner_peer, st.team, "built")
	if st.skind == "fob":
		_event(st.team, "fob", "FOB %s established" % st.sname)


func fob_captured(f: Structure, new_team: int) -> void:
	add(_taker(f.position, Defs.FOB_RADIUS, new_team), new_team, "captures")
	_event(new_team, "fob", "%s captured FOB %s" % [Defs.TEAM_NAMES[new_team], f.sname])


func town_captured(tn: Structure, new_team: int) -> void:
	add(_taker(tn.zone_c, tn.zone_r, new_team), new_team, "towns")
	_event(new_team, "town", "%s took %s" % [Defs.TEAM_NAMES[new_team], tn.sname])


## The men standing on it took it: the credit goes to whoever commands most of them.
func _taker(p: Vector3, r: float, team: int) -> int:
	var count := {}
	for s in world.soldiers_near(p, r):
		if s.team == team and s.life == Soldier.Life.ALIVE:
			count[s.owner_peer] = int(count.get(s.owner_peer, 0)) + 1
	var by := 0
	for o in count:
		if by == 0 or int(count[o]) > int(count[by]):
			by = int(o)
	return by


# --- supply and production ------------------------------------------------------------------

func spent(owner: int, team: int, amount: float) -> void:
	add(owner, team, "spent", amount)


func fielded(owner: int, team: int, item: String) -> void:
	if Defs.SQUADS.has(item):
		add(owner, team, "squads")
	elif Defs.UPGRADES.has(item):
		add(owner, team, "research")
	else:
		add(owner, team, "vehicles")


func squad_formed(sq: Squad) -> void:
	if sq.team < 0 or sq.team > 1:
		return
	units["s%d" % sq.sid] = {"name": Squad.callsign_of(sq.team, sq.sid), "kind": sq.display_name(), "team": sq.team, "owner": sq.owner,
		"t0": world.time, "t1": -1.0, "men": 0, "alive": 0, "kills": 0, "downs": 0, "veh_kills": 0, "lost": 0}


func squad_grew(sq: Squad) -> void:
	var u: Dictionary = units.get("s%d" % sq.sid, {})
	if not u.is_empty():
		u.men = maxi(int(u.men), sq.members.size())


func squad_gone(sq: Squad) -> void:
	var u: Dictionary = units.get("s%d" % sq.sid, {})
	if not u.is_empty():
		u.t1 = world.time
		u.alive = 0


func support_called(owner: int, team: int, kind: String) -> void:
	add(owner, team, "support")
	_event(team, "sup", String(Defs.SUPPORT[kind].name))


func delivered(team: int, amount: float) -> void:
	if team >= 0 and team <= 1:
		var sd: Dictionary = sides[team]
		sd.delivered += amount


func _event(team: int, kind: String, text: String) -> void:
	if events.size() >= MAX_EVENTS and kind != "fob" and kind != "town":
		return
	events.append([world.time, team, kind, text])


# --- over time --------------------------------------------------------------------------------

func tick(dt: float) -> void:
	_sample_t -= dt
	if _sample_t > 0.0:
		return
	_sample_t = every
	_sample()


func _sample() -> void:
	timeline.append(_row())
	if timeline.size() > MAX_SAMPLES:
		var keep := []
		for i in timeline.size():
			if i % 2 == 0 or i == timeline.size() - 1:
				keep.append(timeline[i])
		timeline = keep
		every *= 2.0


## Where the two sides stand right now: [t, men0, men1, veh0, veh1, kills0, kills1, supply0, supply1].
func _row() -> Array:
	var men := [0, 0]
	for s in world.soldiers:
		if s.team < 0 or s.team > 1 or s.is_bearer():
			continue
		if s.life == Soldier.Life.ALIVE or s.life == Soldier.Life.DOWNED or (s.life == Soldier.Life.HIDDEN and not s.hidden_reason in ["held", "interrogation"]):
			men[s.team] += 1
	var veh := [0, 0]
	for v in world.vehicles:
		if v.team >= 0 and v.team <= 1 and v.hp > 0.0 and v.vkind != "truck":
			veh[v.team] += 1
	return [world.time, men[0], men[1], veh[0], veh[1], int(sides[0].kills), int(sides[1].kills),
		world.rules.supply_total(0), world.rules.supply_total(1)]


## How many of each squad are still standing (the record only sees deaths).
func _refresh_units() -> void:
	for sq in world.squads.values():
		var u: Dictionary = units.get("s%d" % sq.sid, {})
		if u.is_empty():
			continue
		var n := 0
		for m in sq.members:
			if is_instance_valid(m) and not m.gone and (m.life == Soldier.Life.ALIVE or m.life == Soldier.Life.DOWNED or m.life == Soldier.Life.HIDDEN):
				n += 1
		u.alive = n
		u.men = maxi(int(u.men), sq.members.size())
		u.owner = sq.owner


# --- the report ---------------------------------------------------------------------------------

## The report as `view` may see it (-1: everything). Until the battle is over
## a side sees only its own figures: what the enemy has lost, fielded and
## spent is for the intelligence officers.
func report(view: int) -> Dictionary:
	_refresh_units()
	var full := view < 0 or world.winner >= 0
	var pl := []
	for o in players:
		var r: Dictionary = players[o]
		if full or int(r.team) == view:
			var c := r.duplicate()
			c["id"] = int(o)
			c["left"] = int(o) > 0 and not Net.players.has(int(o))
			pl.append(c)
	var sd := [sides[0].duplicate(), sides[1].duplicate()]
	if not full:
		sd[1 - view] = {}
	var un := []
	for k in units:
		var u: Dictionary = units[k]
		if full or int(u.team) == view:
			var c2 := u.duplicate()
			c2["key"] = k
			un.append(c2)
	var he := []
	for t in 2:
		if not full and t != view:
			continue
		var best := []
		for eid in heroes:
			var h: Dictionary = heroes[eid]
			if int(h.team) == t:
				best.append(h)
		best.sort_custom(func(a, b): return int(a.kills) + int(a.veh) * 3 > int(b.kills) + int(b.veh) * 3)
		he.append_array(best.slice(0, 8))
	# the record runs right up to now
	var tl: Array = timeline.duplicate()
	if tl.is_empty() or world.time - float(tl.back()[0]) > 1.0:
		tl.append(_row())
	var ev := events
	if not full:
		# their strength and stocks are unknown; what we've killed of theirs we know
		var foe := 1 - view
		for i in tl.size():
			var r2: Array = (tl[i] as Array).duplicate()
			r2[1 + foe] = -1
			r2[3 + foe] = -1
			r2[7 + foe] = -1
			tl[i] = r2
		ev = []
		for e in events:
			if int(e[1]) == view or String(e[2]) != "sup":
				ev.append(e)
	var res := {"t": world.time, "over": world.winner >= 0, "winner": world.winner, "full": full, "view": view, "every": every,
		"players": pl, "sides": sd, "units": un, "heroes": he, "tl": tl, "ev": ev}
	if not world.mission_info.is_empty():
		res["mission"] = true
	return res


## One line per commander, for the headless test runs.
func summary() -> String:
	var out := []
	for o in players:
		var r: Dictionary = players[o]
		out.append("%s(%s) kills=%d downs=%d veh=%d/%d lost=%d shots=%d hits=%d val=%d/%d spent=%d fielded=%d built=%d caps=%d towns=%d pris=%d rating=%d" % [
			r.name, Defs.TEAM_NAMES[int(r.team)], int(r.kills), int(r.downs), int(r.veh_kills), int(r.veh_lost), int(r.lost), int(r.shots), int(r.hits),
			int(r.val_killed), int(r.val_lost), int(r.spent), int(r.squads) + int(r.vehicles), int(r.built), int(r.captures), int(r.towns), int(r.prisoners),
			int(round(rating(r, sides[int(r.team)])))])
	for t in 2:
		var s: Dictionary = sides[t]
		out.append("%s kills=%d lost=%d veh=%d/%d bld=%d/%d val=%d/%d delivered=%d" % [Defs.TEAM_NAMES[t], int(s.kills), int(s.lost), int(s.veh_kills), int(s.veh_lost),
			int(s.bld_kills), int(s.bld_lost), int(s.val_killed), int(s.val_lost), int(s.delivered)])
	return "\n   ".join(out)


# --- the service record --------------------------------------------------------------------------

## The battle as this player's service record keeps it (Online.record_battle):
## what kind of battle, which side, how it ended, their own figures and the
## after-action report, trimmed, so it can be opened again from the menu.
## {} for an observer, or before the end.
static func service_record(w: World) -> Dictionary:
	var r: Dictionary = w.report
	if r.is_empty() or not bool(r.get("full", false)) or w.local_team < 0 or w.winner < 0:
		return {}
	var me: Dictionary = {}
	for c in r.get("players", []):
		if int(c.id) == w.local_peer:
			me = c
	if me.is_empty():
		return {}
	var mine := me.duplicate()
	mine["rating"] = snappedf(rating(me, (r.sides as Array)[w.local_team]), 0.1)
	mine["score"] = score(me)
	var humans := 0
	var sides_manned := {}
	var pl: Dictionary = w.settings.get("players", {})
	for id in pl:
		var t := int(pl[id].team)
		if t >= 0:
			humans += 1
			sides_manned[t] = true
	var mode := "skirmish"
	var title := "Battle vs the AI"
	if not w.mission_info.is_empty():
		mode = "mission"
		title = String(w.mission_info.get("title", "Mission"))
	elif sides_manned.size() >= 2:
		mode = "pvp"
		title = "Player vs player"
	elif humans >= 2:
		mode = "coop"
		title = "Co-op vs the AI"
	var rep := trim_report(r)
	rep["me"] = w.local_peer
	rep["me_team"] = w.local_team
	return {"game_version": Updater.version, "mode": mode, "mission": String(w.settings.get("mission", "")), "title": title,
		"side": w.local_team, "result": "victory" if w.winner == w.local_team else "defeat", "duration": snappedf(float(r.get("t", 0.0)), 0.1),
		"me": compact(mine), "report": rep}


## The after-action report cut down for keeping: every commander and both
## sides, the units that did the most on each side, the timeline thinned to
## 80 samples and the last 60 events, numbers rounded.
static func trim_report(r: Dictionary) -> Dictionary:
	var out := {}
	for k in ["t", "over", "winner", "full", "view", "every", "mission"]:
		if r.has(k):
			out[k] = r[k]
	out["players"] = compact(r.get("players", []))
	out["sides"] = compact(r.get("sides", [{}, {}]))
	out["heroes"] = compact(r.get("heroes", []))
	var keep := []
	for t in 2:
		var us := []
		for u in r.get("units", []):
			if int(u.team) == t:
				us.append(u)
		us.sort_custom(func(a, b): return int(a.kills) + int(a.veh_kills) * 3 > int(b.kills) + int(b.veh_kills) * 3)
		keep.append_array(us.slice(0, 30))
	out["units"] = compact(keep)
	var tl: Array = r.get("tl", [])
	if tl.size() > 80:
		var step := int(ceil(tl.size() / 80.0))
		var thin := []
		for i in tl.size():
			if i % step == 0 or i == tl.size() - 1:
				thin.append(tl[i])
		tl = thin
	out["tl"] = compact(tl)
	out["ev"] = compact((r.get("ev", []) as Array).slice(-60))
	return out


## Whole numbers as ints, the rest to a decimal place (a smaller report).
static func compact(v: Variant) -> Variant:
	if v is float:
		return int(round(v)) if absf(v - round(v)) < 0.001 else snappedf(v, 0.1)
	if v is Array:
		var a := []
		for x in v:
			a.append(compact(x))
		return a
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = compact(v[k])
		return d
	return v


# --- what the numbers mean (shared with the stats screen) ---------------------------------------

## How well a commander fought, 0-100: mostly what they destroyed against what
## they lost (by supply value - a 4:1 exchange is as good as it gets, 1:4 as
## bad), then how well their men shot and their share of their side's fight.
## A commander who has hardly fought sits near the middle.
static func rating(r: Dictionary, side: Dictionary) -> float:
	var pt := rating_parts(r, side)
	return 100.0 * (0.6 * pt[0] + 0.2 * pt[1] + 0.2 * pt[2])


## The rating's three parts, each 0-1: [exchange, marksmanship, share of the fight].
## Most rounds are fired to keep heads down, so one in seven finding its
## target is already good shooting.
static func rating_parts(r: Dictionary, side: Dictionary) -> Array:
	var vk := float(r.get("val_killed", 0.0))
	var vl := float(r.get("val_lost", 0.0))
	var ex := (vk + 60.0) / (vl + 60.0)
	var exchange := clampf(0.5 + 0.25 * log(ex) / log(2.0), 0.0, 1.0)
	var shots := float(r.get("shots", 0.0))
	var acc := clampf((float(r.get("hits", 0.0)) / shots) / 0.15, 0.0, 1.0) if shots >= 30.0 else 0.5
	var sk := float(side.get("val_killed", 0.0))
	var share := clampf(vk / sk, 0.0, 1.0) if sk > 0.0 else 0.5
	return [exchange, acc, share]


static func rating_word(v: float) -> String:
	if v >= 85.0:
		return "Outstanding"
	if v >= 70.0:
		return "Effective"
	if v >= 55.0:
		return "Capable"
	if v >= 40.0:
		return "Mixed"
	if v >= 25.0:
		return "Costly"
	return "Ineffective"


## Points: what they destroyed, plus ground taken (FOBs and towns), prisoners,
## saving men and building (a little: a line of sandbags is not a battle won).
static func score(r: Dictionary) -> int:
	return int(round(float(r.get("val_killed", 0.0)) + 100.0 * float(r.get("captures", 0.0)) + 50.0 * float(r.get("towns", 0.0)) + 15.0 * float(r.get("prisoners", 0.0))
		+ 5.0 * float(r.get("revived", 0.0)) + 2.0 * float(r.get("built", 0.0))))
