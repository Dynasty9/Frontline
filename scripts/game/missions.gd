class_name Missions
extends RefCounted
## The missions: short operations with objectives, each built around something
## the game does well, played alone or in co-op. Every one is set on the
## ordinary generated battlefield (a fixed seed, so the ground is always the
## same) and placed by its features - the river's bridges, the villages, the
## harbour - rather than by coordinates, so it still works if the map changes.
## MissionDirector runs them; this is the content: who is where, what the
## objectives are, and what happens as they're met. The catalogue, what the
## menu says about each, is MissionList.

## The map's features, for placing a mission: the town, the villages, the
## bridges over the river, the harbour, the coast and the river itself.
static func survey(world: World) -> Dictionary:
	var f := {"town": Vector3.ZERO, "villages": [], "bridges": [], "quay": [], "harbour": Vector3.INF, "fords": [], "ponds": []}
	for kp in world.key_points:
		match String(kp.kind):
			"town":
				f.town = kp.pos
			"village":
				f.villages.append(kp.pos)
			"harbour":
				f.harbour = kp.pos
	var w: WaterMap = world.water
	for br in w.bridges:
		var a: Vector3 = br[0]
		var b: Vector3 = br[1]
		var d := {"a": a, "b": b, "c": (a + b) * 0.5, "dir": Defs.flat(b - a).normalized(), "len": Defs.flat(b - a).length()}
		if br.size() > 3 and br[3] == "quay":
			f.quay.append(d)
		else:
			f.bridges.append(d)
	f.fords = w.fords.duplicate()
	for pd in w.ponds:
		f.ponds.append(pd.c)
	f["fobs"] = []
	for st in world.structures:
		if st.skind == "fob":
			f.fobs.append(st)
	if OS.has_environment("FL_DEBUG_MISSION"):
		print("SURVEY town=%s" % str(f.town.round()))
		print("SURVEY villages=%s" % str(f.villages.map(func(v): return v.round())))
		print("SURVEY bridges=%s" % str(f.bridges.map(func(b): return [b.c.round(), b.dir.snapped(Vector3.ONE * 0.01), roundf(b.len)])))
		print("SURVEY harbour=%s quay=%s" % [str(f.harbour.round()), str(f.quay.map(func(b): return b.c.round()))])
		if not w.coast.is_empty():
			print("SURVEY coast x: %s" % str([-300, -200, -100, 0, 100, 200, 300].map(func(z): return roundf(w.coast_x(z)))))
		print("SURVEY fords=%s ponds=%s" % [str(f.fords.map(func(v): return v.round())), str(f.ponds.map(func(v): return v.round()))])
	return f


var ctx := {}  # the mission's own state: its places and units
var _staged := {}  # (autopilot) squad / vehicle -> [the stage it was last ordered for, when]
var _now := 0.0  # world time, for the above


func setup(d: MissionDirector) -> void:
	# supply at the players' FOBs pays for the support on call, and nothing else
	for fb in d.feat.fobs:
		if fb.team == d.side:
			fb.supply = 0.0
	match d.key:
		"bridgehead":
			_bridgehead(d)
		"beachhead":
			_beachhead(d)
		"skyhook":
			_skyhook(d)
		"ambush":
			_ambush(d)
		"kingpin":
			_kingpin(d)
		_:
			d.focus = Vector3.ZERO
			d.add("look", "Look around", "timer", {"secs": 5.0})
			d.start("look", func(): d.win("Survey done."))


## Gives the players' force its orders when nobody is commanding it (tests,
## or everyone has left): roughly what a player would do.
func drive(d: MissionDirector) -> void:
	_now = d.world.time
	match d.key:
		"bridgehead":
			_drive_bridgehead(d)
		"beachhead":
			_drive_beachhead(d)
		"skyhook":
			_drive_skyhook(d)
		"ambush":
			_drive_ambush(d)
		"kingpin":
			_drive_kingpin(d)


# --- shared helpers ------------------------------------------------------------------

func _active(d: MissionDirector, id: String) -> bool:
	var o := d.obj(id)
	return not o.is_empty() and int(o.state) == MissionDirector.ACTIVE


func _done(d: MissionDirector, id: String) -> bool:
	var o := d.obj(id)
	return not o.is_empty() and int(o.state) == MissionDirector.DONE


## The point of a list nearest p (that passes ok, if given).
func _nearest(pts: Array, p: Vector3, ok := Callable()) -> Vector3:
	var best := Vector3.INF
	var bd := 1e9
	for q in pts:
		if ok.is_valid() and not ok.call(q):
			continue
		var dd := Defs.flat(q - p).length()
		if dd < bd:
			bd = dd
			best = q
	return best


## The river bridge furthest towards one end of the map (zs = 1: the south,
## the Coalition's end; -1: the north), leaving out the one in the middle.
func _lane_bridge(f: Dictionary, zs: float) -> Dictionary:
	var best: Dictionary = f.bridges[0] if not f.bridges.is_empty() else {}
	var bs := -1e9
	for b in f.bridges:
		var c: Vector3 = b.c
		var score := c.z * zs - (0.0 if absf(c.z) > 60.0 else 1000.0)
		if score > bs:
			bs = score
			best = b
	return best


## The houses (their floors) near a point, nearest first; whole ones only
## (a roof still on) if roofed.
func _houses(w: World, c: Vector3, r: float, roofed := true) -> Array:
	var roofs := {}
	if roofed:
		for st in w.structures:
			if st.skind == "roof" and Defs.flat(st.position - c).length() < r + 2.0:
				roofs[Vector2i(roundi(st.position.x * 4.0), roundi(st.position.z * 4.0))] = true
	var out := []
	for st in w.structures:
		if st.skind == "floor" and Defs.flat(st.position - c).length() < r:
			if roofed and not roofs.has(Vector2i(roundi(st.position.x * 4.0), roundi(st.position.z * 4.0))):
				continue
			out.append(st)
	out.sort_custom(func(a, b): return Defs.flat(a.position - c).length() < Defs.flat(b.position - c).length())
	return out


## The map road that passes nearest p (other than one to leave out).
func _road_near(w: World, p: Vector3, skip := PackedVector3Array()) -> PackedVector3Array:
	var best := PackedVector3Array()
	var bd := 1e9
	for pl in w.roads[2]:
		if not skip.is_empty() and pl == skip:
			continue
		for q in (pl as PackedVector3Array):
			var dd := Defs.flat(q - p).length()
			if dd < bd:
				bd = dd
				best = pl
	return best


## Points every step metres along a polyline, from its start.
func _resample(pl: PackedVector3Array, step: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	if pl.is_empty():
		return out
	out.append(pl[0])
	var carry := 0.0
	for i in pl.size() - 1:
		var a := pl[i]
		var b := pl[i + 1]
		var seg := Defs.flat(b - a).length()
		var t := step - carry
		while t <= seg:
			out.append(a.lerp(b, t / maxf(seg, 0.001)))
			t += step
		carry = seg - (t - step)
	if Defs.flat(out[out.size() - 1] - pl[pl.size() - 1]).length() > step * 0.4:
		out.append(pl[pl.size() - 1])
	return out


func _walk(d: MissionDirector, p: Vector3) -> Vector3:
	return d.world.nav.nearest_walkable(p)


## Squads of the players' force that can take an order (not all riding).
func _my_squads(d: MissionDirector) -> Array:
	var out := []
	for sq in d.world.squads.values():
		if sq.team != d.side or not (sq.owner in d.owners):
			continue
		var up := false
		for m in sq.alive_members():
			if m.riding == null:
				up = true
		if up:
			out.append(sq)
	return out


## (autopilot) Orders a squad or vehicle once per stage: a fresh order every
## few seconds would keep restarting its plans. Once a stage has gone on a
## while it orders them again (a squad that went firm, or ran, gets going).
func _once(key: String, stage: String, again := 45.0) -> bool:
	var was: Array = _staged.get(key, ["", 0.0])
	if was[0] == stage and (again <= 0.0 or _now - float(was[1]) < again):
		return false
	_staged[key] = [stage, _now]
	return true


## (autopilot) Calls in support where a player would, once it's ready.
func _call(d: MissionDirector, kind: String, pos: Vector3) -> void:
	if kind in d.support and d.world.rules.support_left(d.side, kind) <= 0.0:
		d.world.rules.call_support(d.owners[0], d.side, kind, pos)


func _live(v) -> bool:
	return v != null and is_instance_valid(v) and not v.gone and v.hp > 0.0


## The enemy's support, called in by the mission (it has no commander to).
func _enemy_support(d: MissionDirector, kind: String, pos: Vector3) -> void:
	d.world.rules.support_ready[d.foe][kind] = 0.0
	for fb in d.feat.fobs:
		if fb.team == d.foe:
			fb.supply = maxf(fb.supply, 400.0)
	d.world.rules.call_support(d.ai_owner(d.foe), d.foe, kind, pos)


## Off-map support for the players: on call now, paid from this much supply.
func _support(d: MissionDirector, kinds: Array, supply: float) -> void:
	d.support = kinds
	for k in kinds:
		d.world.rules.support_ready[d.side][k] = 0.0
	for fb in d.feat.fobs:
		if fb.team == d.side:
			fb.supply = supply
			fb.net_dirty = true
			break


# --- 1. Bridgehead -------------------------------------------------------------------
# A Coalition platoon clears a village on the river, takes the bridge beyond it
# and holds it against the counterattack: house clearing, a deliberate attack,
# then a defence against infantry and armour coming over the bridge and the ford.

func _bridgehead(d: MissionDirector) -> void:
	var f := d.feat
	var br := _lane_bridge(f, 1.0)
	var c: Vector3 = br.c
	var east: Vector3 = br.a if br.a.x > br.b.x else br.b
	var west: Vector3 = br.b if br.a.x > br.b.x else br.a
	var nv := _nearest(f.villages, c, func(v): return v.x > c.x + 30.0)
	var fv := _nearest(f.villages, c, func(v): return v.x < c.x - 30.0)
	var e := Defs.flat(nv - c).normalized()  # from the bridge out through the village: our way in
	var n := Vector3(-e.z, 0, e.x)
	var start := nv + e * 125.0
	ctx = {"c": c, "east": east, "west": west, "nv": nv, "fv": fv, "e": e, "n": n}
	d.focus = start - e * 18.0
	d.focus_yaw = Defs.yaw_of(-e)
	# the platoon, at the end of the lane
	d.squad("rifle_squad", start + n * 12.0, start + n * 12.0 - e * 4.0)
	d.squad("rifle_squad", start - n * 12.0, start - n * 12.0 - e * 4.0)
	d.squad("mg_team", start + n * 3.0 + e * 6.0, start + n * 3.0 + e * 2.0)
	d.squad("at_team", start - n * 4.0 + e * 7.0, start - n * 4.0 + e * 3.0)
	var ifv := d.vehicle("marshall", _walk(d, start + e * 18.0), Defs.yaw_of(-e), d.side, d.next_owner())
	ifv.embark_new_squad()
	ctx.ifv = ifv
	# the Rebels in the village: a cell at each end, a PKM on the flank, a technical
	var houses := _houses(d.world, nv, 45.0)
	var h0: Vector3 = houses[0].position if houses.size() > 0 else nv
	d.enemy("fighter_cell", h0 + e * 4.0).order_defend(h0 + e * 4.0, e)
	d.enemy("pkm_team", nv - n * 16.0 + e * 6.0).order_defend(nv - n * 16.0 + e * 6.0, e)
	var tech := d.vehicle("technical", _walk(d, nv - e * 10.0), Defs.yaw_of(e), d.foe, d.ai_owner(d.foe))
	tech.order_stop()
	# and a gun team on the bridge itself, covering the men wiring it
	d.enemy("pkm_team", east + e * 10.0).order_defend(east + e * 8.0, e)
	_support(d, ["artillery"], 650.0)

	d.add("village", "Clear the village", "clear", {"pos": nv, "r": 42.0})
	d.add("bridge", "Seize the bridge", "clear", {"pos": c + e * 6.0, "r": 26.0})
	d.add("hold", "Hold the bridge until the tanks arrive", "hold", {"pos": east + e * 6.0, "r": 40.0, "secs": 120.0, "grace": 30.0,
		"fail_text": "The Rebels have retaken the bridge."})
	d.add("marshall", "Keep the Marshall in the fight", "protect", {"eids": [ifv.eid], "optional": true})
	d.radio("Overlord: Rebels hold the village at %s and the bridge behind it. Clear the village, then take that bridge before they blow it." % Defs.grid_ref(nv), nv)
	d.start("marshall")
	d.start("village", func():
		d.radio("Overlord: Village is clear. Push on to the bridge, they're wiring it now.", c)
		d.start("bridge", func(): _bridgehead_hold(d)))


func _bridgehead_hold(d: MissionDirector) -> void:
	var c: Vector3 = ctx.c
	var e: Vector3 = ctx.e
	var n: Vector3 = ctx.n
	var west: Vector3 = ctx.west
	var east: Vector3 = ctx.east
	var fv: Vector3 = ctx.fv
	d.radio("Overlord: Bridge is ours. Enemy column forming up in the village across the river. Dig in on this bank: the tanks are two minutes out.", c)
	d.start("hold", func():
		# the armour comes up the lane, and that's that
		for i in 2:
			var tk := d.vehicle("tank", _walk(d, east + e * (170.0 + i * 16.0) + n * (i * 6.0 - 3.0)), Defs.yaw_of(-e), d.side, d.ai_owner(d.side))
			tk.order_assault(east + e * (14.0 + i * 8.0))
		d.radio("Lancer 6: Tanks on the bridge. Good work, we have it from here.")
		d.after(6.0, func(): d.win("The bridge is ours, intact, and the armour is across.")))
	# the counterattack: infantry over the bridge at once, then a BTR, then a
	# cell wading the ford to come in on the flank, and mortars
	var fo := fv if fv != Vector3.INF else west - e * 120.0
	var q := d.enemy("fighter_cell", fo)
	q.order_assault(east + e * 10.0, e)
	var rq := d.enemy("rpg_team", fo - e * 8.0 + n * 6.0)
	rq.order_assault(east + e * 6.0, e)
	d.after(40.0, func():
		var btr := d.vehicle("btr", _walk(d, fo - e * 20.0), Defs.yaw_of(e), d.foe, d.ai_owner(d.foe))
		btr.embark_new_squad()
		btr.order_assault(east + e * 20.0)
		d.radio("Overlord: BTR heading for the bridge. Get your AT up.", west))
	var ford := _nearest(d.feat.fords, c)
	if ford != Vector3.INF and Defs.flat(ford - c).length() < 260.0:
		d.after(60.0, func():
			var fq := d.enemy("fighter_cell", ford - e * 40.0)
			fq.order_assault(east + e * 12.0, e)
			d.radio("Overlord: Movement at the ford, %s. They're coming round your flank." % Defs.grid_ref(ford), ford))
	d.after(80.0, func(): _enemy_support(d, "mortars", east + e * 10.0))
	# and help for us: a squad and an AT team from the second platoon, at the run
	d.after(20.0, func():
		var start: Vector3 = ctx.nv + e * 120.0
		var r1 := d.squad("rifle_squad", start + n * 6.0)
		r1.order_move(east + e * 14.0 + n * 8.0, -e, 2)
		var r2 := d.squad("at_team", start - n * 6.0)
		r2.order_move(east + e * 12.0 - n * 8.0, -e, 2)
		d.radio("2nd Platoon: Sending you a squad and an AT team up the lane. Hold on.", start))


func _drive_bridgehead(d: MissionDirector) -> void:
	var stage := ""
	var at := Vector3.ZERO
	if _active(d, "village"):
		stage = "village"
		at = ctx.nv
	elif _active(d, "bridge"):
		stage = "bridge"
		at = ctx.c + ctx.e * 6.0
	elif _active(d, "hold"):
		stage = "hold"
		at = ctx.east + ctx.e * 10.0
	if stage == "":
		return
	if stage == "village":
		_call(d, "artillery", ctx.nv - ctx.e * 6.0)
	var i := 0
	for sq in _my_squads(d):
		if _once("sq%d" % sq.sid, stage):
			var p: Vector3 = at + ctx.n * (i % 3 - 1) * 12.0
			if stage == "hold":
				sq.order_defend(p, -ctx.e)
			else:
				sq.order_assault(p, -ctx.e)
		i += 1
	var ifv = ctx.get("ifv")
	if _live(ifv) and _once("ifv", stage):
		ifv.order_assault(at + ctx.e * (14.0 if stage == "hold" else 0.0))


# --- 2. Beachhead -------------------------------------------------------------------
# Boats: RHIBs run a landing party onto the beach under a patrol ship's guns;
# enemy speedboats come out to meet them; the AA trucks die and the air comes in.

func _beachhead(d: MissionDirector) -> void:
	var f := d.feat
	var w := d.world
	var wm: WaterMap = w.water
	var h: Vector3 = f.harbour
	if h == Vector3.INF:
		h = Vector3(wm.coast_x(0.0) - 6.0, 0, 0)
	var zb := h.z + 145.0
	var beach := Vector3(wm.coast_x(zb) - 12.0, 0, zb)
	var z0 := h.z + 290.0
	var sea0 := Vector3(minf(wm.coast_x(z0) + 95.0, MapDims.HALF - 20.0), 0, z0)
	ctx = {"h": h, "beach": beach, "sea0": sea0}
	d.focus = sea0 + Vector3(-50, 0, -40)
	d.focus_yaw = Defs.yaw_of(Defs.flat(h - sea0).normalized())
	# the landing party, already in the boats, and the patrol ship
	var boats := []
	var loads := [["rifle_squad"], ["rifle_squad"], ["mg_team", "at_team"]]
	for i in loads.size():
		var p := w.nav.nearest_boat(sea0 + Vector3(-i * 14.0, 0, i * 18.0))
		var rh := d.vehicle("rhib", p, Defs.yaw_of(Defs.flat(beach - p)), d.side, d.next_owner())
		for kind in loads[i]:
			var sq := d.squad(kind, _walk(d, beach))
			for m in sq.members:
				rh.board(m)
		boats.append(rh)
	var ship := d.vehicle("patrol_ship", w.nav.nearest_boat(sea0 + Vector3(14, 0, -30)), Defs.yaw_of(Defs.flat(h - sea0)), d.side, d.next_owner())
	ctx.boats = boats
	ctx.ship = ship
	# the defence: a cell dug in behind the beach, the harbour held, two AA trucks
	# inland of it and two boats in it
	var inland := Vector3(-1, 0, 0)
	# the beach is watched from a sandbagged post up the shore towards the harbour
	var post := h + inland * 24.0 + Vector3(0, 0, 52.0)
	d.enemy("pkm_team", post).order_defend(post, Vector3(0.6, 0, 0.8).normalized())
	for k in 3:
		mgen_sandbags(d, post + Vector3(2, 0, (k - 1) * 4.4) + Vector3(0, 0, 2))
	d.enemy("fighter_cell", h + inland * 14.0 + Vector3(0, 0, 10)).order_defend(h + inland * 12.0, -inland)
	var aa := []
	for p in [h + inland * 26.0 + Vector3(0, 0, 30), h + inland * 30.0 + Vector3(0, 0, -24)]:
		var v := d.vehicle("aa_tech", _walk(d, p), Defs.yaw_of(-inland), d.foe, d.ai_owner(d.foe))
		v.order_stop()
		aa.append(v.eid)
	var mb := d.vehicle("motorboat", w.nav.nearest_boat(h + Vector3(36, 0, -26)), PI * 0.5, d.foe, d.ai_owner(d.foe))
	var sb := d.vehicle("speedboat_hmg", w.nav.nearest_boat(h + Vector3(54, 0, 24)), PI * 0.5, d.foe, d.ai_owner(d.foe))
	# the boats come out once they've seen the landing (by then the RHIBs should
	# be on the sand; the patrol ship is there to meet them)
	d.after(22.0, func():
		if _live(mb):
			mb.order_assault(sea0 + Vector3(-20, 0, -90))
		if _live(sb):
			sb.order_assault(sea0 + Vector3(-10, 0, -70))
		d.radio("Neptune: Two enemy boats coming out of the harbour. Engaging.", h + Vector3(40, 0, 0)))
	ctx.aa = aa
	_support(d, ["artillery"], 320.0)

	d.add("land", "Land on the beach", "reach", {"pos": beach, "r": 30.0, "need": 4, "afoot": true})
	d.add("aa", "Destroy the two AA guns", "destroy", {"eids": aa, "pos": (h + inland * 28.0)})
	d.add("harbour", "Clear the harbour", "clear", {"pos": h + inland * 8.0, "r": 42.0, "afoot": true})
	d.add("hold", "Hold the harbour until the landing craft are in", "hold", {"pos": h + inland * 8.0, "r": 50.0, "secs": 90.0, "afoot": true,
		"grace": 30.0, "fail_text": "The Rebels have retaken the harbour."})
	d.add("boats", "Sink the enemy boats", "destroy", {"eids": [mb.eid, sb.eid], "optional": true, "track": true, "pos": h + Vector3(40, 0, 0)})
	d.radio("Overlord: Two AA guns cover the harbour and our helicopters can't get in. Land on the beach at %s, find the guns and kill them." % Defs.grid_ref(beach), beach)
	d.start("boats", func(): d.radio("Neptune: Enemy boats are on the bottom. Coast is clear."))
	d.start("land", func():
		d.radio("Overlord: Feet dry. The AA guns are just inland of the harbour, %s. Bring the patrol ship in close: once they're spotted its guns can reach them from the water." % Defs.grid_ref(h + inland * 28.0), h + inland * 28.0)
		d.start("aa", func(): _beachhead_air(d)))


func _beachhead_air(d: MissionDirector) -> void:
	var h: Vector3 = ctx.h
	var beach: Vector3 = ctx.beach
	d.radio("Overlord: AA is down! Blackfoot and a Ghost Hawk with reinforcements inbound from the sea. A-10 on call.", h)
	_support(d, ["a10"], 300.0)
	d.dirty = true
	# an attack helicopter over the harbour, and a squad flown in to the beach
	var hx := MapDims.HALF - 12.0
	var gs := d.vehicle("blackfoot", Vector3(hx, 0, h.z + 60.0), PI * 0.5, d.side, d.ai_owner(d.side))
	gs.order_move(h + Vector3(-30, 0, 0))
	var gh := d.vehicle("ghosthawk", Vector3(hx, 0, beach.z + 30.0), PI * 0.5, d.side, d.next_owner())
	var sq := d.squad("rifle_squad", _walk(d, beach))
	for m in sq.members:
		gh.board(m)
	gh.order_move(beach + Vector3(-30, 0, -10))
	d.start("harbour", func():
		d.radio("Overlord: Harbour's clear. Landing craft are ninety seconds out: hold the quay till they're in.", h)
		d.start("hold", func(): d.win("The harbour is ours, and the battalion is coming ashore.")))
	# the Rebels in the town send what they have down the road to the harbour
	var road := Vector3(-1, 0, 0)
	var src := _walk(d, h + road * 190.0)
	d.after(20.0, func():
		for i in 2:
			var t := d.vehicle("technical", _walk(d, src + Vector3(0, 0, i * 12.0 - 6.0)), Defs.yaw_of(-road), d.foe, d.ai_owner(d.foe))
			t.order_assault(h + road * 10.0 + Vector3(0, 0, i * 10.0 - 5.0))
		var q := d.enemy("fighter_cell", src + road * 10.0)
		q.order_assault(h + road * 8.0, -road)
		d.radio("Overlord: Two technicals and a cell coming down the road from the town to the harbour.", src))
	d.after(55.0, func():
		var q2 := d.enemy("fighter_cell", src + Vector3(0, 0, 30))
		q2.order_assault(h + road * 14.0 + Vector3(0, 0, 20), -road))


func mgen_sandbags(d: MissionDirector, p: Vector3) -> void:
	d.mg._try("sandbags", TrenchNet.snap_pos(p), PI * 0.5, d.foe)


func _drive_beachhead(d: MissionDirector) -> void:
	var beach: Vector3 = ctx.beach
	var h: Vector3 = ctx.h
	# each boat to its own stretch of the beach (one that can't put its men
	# ashore where it stopped tries a little further along)
	for i in ctx.boats.size():
		var rh = ctx.boats[i]
		if _live(rh) and not rh.passengers.is_empty() and _once("rhib%d" % rh.eid, "land", 20.0):
			var tries := int(_staged.get("rhib_try%d" % i, 0))
			_staged["rhib_try%d" % i] = tries + 1
			rh.order_move(beach + Vector3(-6, 0, (i - 1) * 14.0 + tries * 9.0))
	# the patrol ship closes the harbour, where its guns reach the AA trucks
	var ship = ctx.ship
	if _live(ship) and _once("ship", "cover", 0.0):
		ship.order_assault(d.world.nav.nearest_boat(Vector3(d.world.water.coast_x(h.z + 10.0) + 26.0, 0, h.z + 10.0)))
	var stage := ""
	var at := Vector3.ZERO
	if _active(d, "aa") or _active(d, "land"):
		stage = "aa"
		var aa_pos := Vector3.ZERO
		var n := 0
		for id in ctx.aa:
			if d.alive(int(id)):
				aa_pos += d.world.entities[int(id)].position
				n += 1
		at = aa_pos / n if n > 0 else h
		stage += str(n)
	elif _active(d, "harbour") or _active(d, "hold"):
		stage = "harbour"
		at = h + Vector3(-8, 0, 0)
	if stage == "":
		return
	if stage.begins_with("aa") and _done(d, "land"):
		_call(d, "artillery", at)
	var i := 0
	for sq in _my_squads(d):
		if _once("sq%d" % sq.sid, stage):
			sq.order_assault(at + Vector3(0, 0, (i % 3 - 1) * 12.0), Vector3(-1, 0, 0))
		i += 1


# --- 3. Sky Hook ---------------------------------------------------------------------
# Sling loading: a Mohawk hooks a Wiesel-type Nyx, carries it over the river and
# sets it down at a cut-off outpost before an armoured column gets there.

func _skyhook(d: MissionDirector) -> void:
	var f := d.feat
	var w := d.world
	var br := _lane_bridge(f, -1.0)
	var c: Vector3 = br.c
	var nv := _nearest(f.villages, c, func(v): return v.x > c.x + 30.0)
	var fv := _nearest(f.villages, c, func(v): return v.x < c.x - 30.0)
	if fv == Vector3.INF:
		fv = c + Vector3(-130, 0, 0)
	var e := Defs.flat(nv - c).normalized()
	var north := Vector3(0, 0, -1)
	var west := Vector3(-1, 0, 0)
	var op := fv
	var pad := _walk(d, nv + e * 70.0)
	ctx = {"op": op, "pad": pad, "c": c, "e": e}
	d.focus = pad + Vector3(-30, 0, 0)
	d.focus_yaw = Defs.yaw_of(west)
	# the lift: the Mohawk on its pad, the Nyx beside it, a reserve squad
	d.mg._spawn("helipad", pad, 0.0, d.side, {"built": true})
	var mh := d.vehicle("mohawk", pad, Defs.yaw_of(west), d.side, d.next_owner())
	var nyx := d.vehicle("nyx_at", _walk(d, pad + Vector3(0, 0, 20)), Defs.yaw_of(west), d.side, d.next_owner())
	nyx.order_stop()
	d.squad("rifle_squad", pad + Vector3(14, 0, -10), pad + Vector3(10, 0, -12))
	ctx.mh = mh
	ctx.nyx = nyx
	# Outpost Kilo: sandbags across its north side, a squad and a gun in it
	for k in 5:
		d.mg._try("sandbags", TrenchNet.snap_pos(op + north * 16.0 + west * ((k - 2) * 4.6)), 0.0, d.side)
	var nest := d.mg._try("hmg_nest", TrenchNet.snap_pos(op + north * 19.0 + west * 13.0), 0.0, d.side, {"built": true})
	if nest:
		d.mg._crew(nest, d.next_owner())
	var g1 := d.squad("rifle_squad", op + north * 10.0)
	g1.order_defend(op + north * 12.0, north)
	var g2 := d.squad("mg_team", op + north * 12.0 - west * 10.0)
	g2.order_defend(op + north * 14.0 - west * 10.0, north)
	# the column, forming up to the north
	var c0 := op + north * 240.0
	ctx.c0 = c0
	var col := []
	ctx.col = col
	_support(d, ["artillery"], 320.0)

	d.add("deliver", "Sling the Nyx to Outpost Kilo", "deliver", {"eids": [nyx.eid], "pos": op, "r": 34.0,
		"fail_text": "The Nyx has been lost."})
	d.add("kilo", "Don't let Kilo fall", "guard", {"pos": op, "r": 40.0, "grace": 25.0, "mark": false, "fail_text": "Outpost Kilo has been overrun."})
	d.add("column", "Stop the armoured column", "destroy", {"eids": [], "need": 2, "pos": op + north * 60.0})
	d.radio("Kilo: Overlord, Kilo. Armour forming up a click north of us and we've got nothing that can touch it. Requesting anti-armour, over.", op)
	d.after(6.0, func(): d.radio("Overlord: Kilo, help is on the way by air. Mohawk, hook that Nyx and get it over the river.", pad))
	d.start("deliver", func():
		d.radio("Kilo: Nyx is on the ground. Thanks for the lift.", op))
	d.start("kilo")
	# the column moves at 1:20 whatever happens, its armour a minute behind
	d.after(80.0, func(): _skyhook_column(d, 1))
	d.after(140.0, func(): _skyhook_column(d, 2))


func _skyhook_column(d: MissionDirector, wave: int) -> void:
	var c0: Vector3 = ctx.c0
	var op: Vector3 = ctx.op
	var north := Vector3(0, 0, -1)
	var o := d.obj("column")
	if wave == 1:
		var t := d.vehicle("technical", _walk(d, c0), Defs.yaw_of(-north), d.foe, d.ai_owner(d.foe))
		t.order_assault(op + north * 20.0)
		o.eids.append(t.eid)
		var q := d.enemy("fighter_cell", c0 + Vector3(0, 0, -16))
		q.order_assault(op + north * 14.0, -north)
		d.radio("Kilo: Contact north! A technical and infantry coming down the road. Armour behind them.", c0)
		d.start("column", func():
			d.win("The column is burning on the road north of Kilo. The outpost holds."))
	else:
		var btr := d.vehicle("btr", _walk(d, c0 + Vector3(-8, 0, -10)), Defs.yaw_of(-north), d.foe, d.ai_owner(d.foe))
		btr.order_assault(op + north * 24.0)
		var tk := d.vehicle("btr", _walk(d, c0 + Vector3(10, 0, -24)), Defs.yaw_of(-north), d.foe, d.ai_owner(d.foe))
		tk.order_assault(op + north * 30.0)
		o.eids.append(btr.eid)
		o.eids.append(tk.eid)
		d.radio("Kilo: Two BTRs behind them! Where's that Nyx?", c0)
	d.dirty = true


func _drive_skyhook(d: MissionDirector) -> void:
	var mh = ctx.mh
	var nyx = ctx.nyx
	var op: Vector3 = ctx.op
	if OS.has_environment("FL_DEBUG_MISSION") and _live(mh):
		print("SKYHOOK t=%.0f mohawk=%s phase=%d cargo=%s nyx=%s" % [d.world.time, str(mh.position.round()), mh.lift_phase, str(mh.sling_cargo != null), str(nyx.position.round()) if _live(nyx) else "dead"])
	if _active(d, "deliver") and _live(mh) and _live(nyx):
		if nyx.slung_by == null and mh.sling_cargo == null and mh.sling_target == null:
			mh.order_sling(nyx)
		elif mh.sling_cargo == nyx and _once("mh", "carry", 0.0):
			mh.order_move(op + Vector3(8, 0, 6))
		return
	# the Nyx takes up a firing position just inside the outpost, looking up
	# the road (its missiles outrange anything the column has)
	if _done(d, "deliver") and _live(nyx) and _once("nyx", "fight", 0.0):
		nyx.order_move(op + Vector3(0, 0, -6))
	# the one fire mission is saved for the armour (and kept clear of Kilo),
	# and the Nyx is told to go for the nearest of the column (as a player
	# would right-click it): it finds itself a firing position
	if _active(d, "column"):
		var near_v = null
		var nd := 1e9
		for id in d.obj("column").eids:
			if not d.alive(int(id)):
				continue
			var v = d.world.entities.get(int(id))
			var dv := Defs.flat(v.position - op).length()
			if v.weight() < 1:
				continue  # technicals are for the guns; the missiles are for armour
			if dv > 80.0 and dv < 180.0:
				_call(d, "artillery", v.position)
			if dv < nd:
				nd = dv
				near_v = v
		# shoot and scoot: missiles from long range, and back off before the
		# armour's guns can reach it while it reloads
		if near_v != null and _live(nyx):
			if nd < 75.0 and _once("nyx_back", "back%d" % int(_now / 12.0), 0.0):
				nyx.order_move(op + Vector3(0, 0, 22))
			elif nd >= 75.0 and nd < 140.0 and _once("nyx_atk%d" % near_v.eid, "atk", 20.0):
				nyx.order_attack(near_v)
	for sq in _my_squads(d):
		if _once("sq%d" % sq.sid, "kilo"):
			sq.order_defend(op + Vector3(0, 0, -10), Vector3(0, 0, -1))
	if _live(mh) and _done(d, "deliver") and _once("mh", "home", 0.0):
		mh.order_move(ctx.pad)


# --- 4. Ambush Alley (Rebels) -------------------------------------------------------
# The other side of it: a near ambush from the woods above a lane on a convoy
# that drives through the kill zone, then breaking contact before the QRF.

func _ambush(d: MissionDirector) -> void:
	var f := d.feat
	var w := d.world
	# the village up the lane on the Rebels' side of the map, east of the road
	var ev := _nearest(f.villages, Vector3(160, 0, -200), func(v): return v.x > 60.0 and v.z < 0.0)
	if ev == Vector3.INF:
		ev = _nearest(f.villages, Vector3(160, 0, -200))
	var lane := _road_near(w, ev)
	var pts := _resample(lane, 4.0)
	# run it from the village out to the main road (the lane starts at the main
	# road and ends just past the village)
	if Defs.flat(pts[0] - ev).length() > Defs.flat(pts[pts.size() - 1] - ev).length():
		pts.reverse()
	var i0 := 0
	for i in pts.size():
		if Defs.flat(pts[i] - ev).length() < Defs.flat(pts[i0] - ev).length():
			i0 = i
	var route := PackedVector3Array()
	for i in range(i0, pts.size()):
		route.append(pts[i])
	# on along the main road towards the Coalition's end
	var junction := route[route.size() - 1]
	var main := _resample(_road_near(w, junction, lane), 4.0)
	var j0 := 0
	for i in main.size():
		if Defs.flat(main[i] - junction).length() < Defs.flat(main[j0] - junction).length():
			j0 = i
	var lane_n := route.size()
	var dirz := 1 if main.size() > 1 and main[main.size() - 1].z > main[0].z else -1
	var k := j0
	var run := 0
	while k >= 0 and k < main.size() and run < 100:
		route.append(main[k])
		k += dirz
		run += 1
	# the kill zone: well down the lane, out of sight of the village
	var ki := clampi(int(lane_n * 0.72), 1, route.size() - 2)
	var kz := route[ki]
	var t := Defs.flat(route[mini(ki + 3, route.size() - 1)] - route[maxi(ki - 3, 0)]).normalized()
	var n := Vector3(-t.z, 0, t.x)
	if n.z > 0.0:
		n = -n  # the ambush sits on the Rebels' side of the lane
	var ap := _walk(d, kz + n * 36.0)
	var rp := _walk(d, ap + n * 150.0 - t * 30.0)
	var start := _walk(d, ap + n * 120.0)
	ctx = {"route": route, "kz": kz, "t": t, "n": n, "ap": ap, "rp": rp, "convoy": []}
	d.focus = start - n * 30.0
	d.focus_yaw = Defs.yaw_of(-n)
	# the woods above the lane, and a ditch line of scrub along it
	d.mg._woods(ap + n * 4.0, 14)
	d.mg._woods(ap - t * 26.0 + n * 6.0, 8)
	# the IED, dug into the lane the night before: it opens the ambush
	d.mg._spawn("mines", TrenchNet.snap_pos(kz + t * 6.0), Defs.yaw_of(t), d.side, {"built": true})
	# the ambush party
	d.squad("fighter_cell", start + t * 12.0, start + t * 12.0 - n * 4.0)
	d.squad("rpg_team", start - t * 12.0, start - t * 12.0 - n * 4.0)
	d.squad("rpg_team", start + t * 2.0, start + t * 2.0 - n * 4.0)
	d.squad("pkm_team", start - t * 4.0 + n * 6.0, start - t * 4.0 + n * 2.0)
	ctx.wp = [1, 1, 1, 1]
	_support(d, ["mortars"], 260.0)

	d.add("position", "Get into the woods above the lane", "reach", {"pos": ap, "r": 26.0, "need": 6})
	d.add("depart", "The convoy leaves the village", "timer", {"secs": 100.0})
	d.add("convoy", "Destroy the convoy", "destroy", {"eids": [], "need": 3, "pos": kz, "track": true})
	d.add("exfil", "Break contact: back to the rally point", "extract", {"pos": rp, "r": 30.0, "frac": 0.6})
	d.radio("Cell leader: The convoy leaves the village at %s when the light goes. Into the woods above the lane, and nobody fires before the RPGs." % Defs.grid_ref(route[0]), ap)
	d.start("position", func(): d.radio("Cell leader: In position. Wait for it... let the lead car into the bend."))
	d.start("depart", func(): _ambush_go(d))


func _ambush_go(d: MissionDirector) -> void:
	# the convoy pulls out of the village, nose to tail
	var route: PackedVector3Array = ctx.route
	var kinds := ["hunter_hmg", "hemtt", "humvee", "marshall"]
	var fwd := Defs.flat(route[mini(4, route.size() - 1)] - route[0]).normalized()
	for i in kinds.size():
		var v := d.vehicle(kinds[i], _walk(d, route[0] - fwd * (i * 16.0)), Defs.yaw_of(fwd), d.foe, d.ai_owner(d.foe))
		v.embark_new_squad()
		ctx.convoy.append(v)
		d.obj("convoy").eids.append(v.eid)
	d.radio("Lookout: They're moving! Four vehicles, a Hunter in front.", ctx.route[0])
	d.start("convoy", func():
		d.radio("Cell leader: That's enough, they'll have called it in. Back to the rally point, move!", ctx.rp)
		d.deadline = d.world.time + 150.0
		d.deadline_text = "The reaction force has cut you off."
		d.dirty = true
		d.start("exfil", func(): d.win("The convoy is burning and the cell has melted away into the dusk.")))
	_convoy_tick(d)
	# the quick reaction force: a Pawnee and a Hunter full of riflemen from the
	# main road, a minute and a half after the shooting starts
	d.after(45.0, func():
		var qrf := d.vehicle("hunter_hmg", _walk(d, ctx.kz - ctx.t * 220.0 - ctx.n * 10.0), Defs.yaw_of(ctx.t), d.foe, d.ai_owner(d.foe))
		qrf.embark_new_squad()
		qrf.order_assault(ctx.ap)
		var hx: float = clampf(ctx.kz.x, -MapDims.HALF + 20.0, MapDims.HALF - 20.0)
		var heli := d.vehicle("pawnee", Vector3(hx, 0, MapDims.HALF - 30.0), 0.0, d.foe, d.ai_owner(d.foe))
		heli.order_move(ctx.ap)
		d.radio("Lookout: Helicopter coming up from the south, and a Hunter on the main road. QRF!", ctx.kz))


## Drives the convoy down its route a few points at a time, through the kill
## zone whatever happens (that's the drill: drive out of an ambush); one that
## reaches the end of the route has got away.
func _convoy_tick(d: MissionDirector) -> void:
	_now = d.world.time
	var route: PackedVector3Array = ctx.route
	var escaped := 0
	for i in ctx.convoy.size():
		var v = ctx.convoy[i]
		if not _live(v):
			continue
		var wi: int = ctx.wp[i]
		if wi >= route.size() - 1 and Defs.flat(v.position - route[route.size() - 1]).length() < 14.0:
			escaped += 1
			continue
		# keep the interval: don't run up the back of the one in front
		if i > 0 and _live(ctx.convoy[i - 1]) and Defs.flat(ctx.convoy[i - 1].position - v.position).length() < 12.0 and wi > 2:
			continue
		var target := mini(wi + 6, route.size() - 1)
		if Defs.flat(v.position - route[wi]).length() < 10.0 or v.path.is_empty() or _once("cv%d" % i, "wp%d" % wi, 0.0):
			while wi < route.size() - 1 and Defs.flat(v.position - route[wi]).length() < 12.0:
				wi += 1
			ctx.wp[i] = wi
			target = mini(wi + 6, route.size() - 1)
			v.order_move(route[target])
	if escaped >= 2:
		d.fail("The convoy got through.")
		return
	d.after(1.5, func(): _convoy_tick(d))


func _drive_ambush(d: MissionDirector) -> void:
	var ap: Vector3 = ctx.ap
	var n: Vector3 = ctx.n
	var t: Vector3 = ctx.t
	var stage := "ambush"
	if _active(d, "exfil"):
		stage = "exfil"
	var i := 0
	for sq in _my_squads(d):
		if _once("sq%d" % sq.sid, stage):
			if stage == "exfil":
				sq.order_move(ctx.rp + t * (i % 3 - 1) * 8.0, n, 2)
			else:
				sq.order_defend(ap + t * (i % 4 - 1.5) * 9.0, -n)
		i += 1


# --- 5. Kingpin ------------------------------------------------------------------------
# A night raid on a house in the town: a checkpoint on the main street, a
# breach, a high-value target, and a run back to the vehicles.

func _kingpin(d: MissionDirector) -> void:
	var f := d.feat
	var w := d.world
	var town: Vector3 = f.town
	# the main street: the road that runs furthest north and south through the town
	var main := PackedVector3Array()
	var span := 0.0
	for pl in w.roads[2]:
		var a: PackedVector3Array = pl
		var zmin := 1e9
		var zmax := -1e9
		var near_town := false
		for p in a:
			zmin = minf(zmin, p.z)
			zmax = maxf(zmax, p.z)
			if Defs.flat(p - town).length() < 60.0:
				near_town = true
		if near_town and zmax - zmin > span:
			span = zmax - zmin
			main = a
	main = _resample(main, 4.0)
	# the target house: a whole one in the north of the town, off the main street
	var want := town + Vector3(18, 0, -55)
	var hs := _houses(w, want, 60.0)
	var hv: Vector3 = hs[0].position if not hs.is_empty() else want
	var street := _nearest(Array(main), hv)
	var south := Vector3(0, 0, 1)
	var cp := _nearest(Array(main), hv + south * 75.0)
	var start := _nearest(Array(main), hv + south * 220.0)
	ctx = {"hv": hv, "cp": cp, "start": start, "street": street}
	d.focus = start + south * 12.0
	d.focus_yaw = Defs.yaw_of(-south)
	# the raid
	d.squad("rifle_squad", start + Vector3(8, 0, 0), start + Vector3(8, 0, -4))
	d.squad("rifle_squad", start + Vector3(-8, 0, 0), start + Vector3(-8, 0, -4))
	d.squad("mg_team", start + south * 6.0, start + south * 2.0)
	var vh := []
	for i in 2:
		var v := d.vehicle("hunter_hmg", _walk(d, start + south * (16.0 + i * 12.0)), Defs.yaw_of(-south), d.side, d.next_owner())
		v.order_stop()
		vh.append(v)
	ctx.vh = vh
	# the checkpoint: sandbags and a burnt-out car across the street, a cell and a PKM
	var sd := Vector3(1, 0, 0)
	for k in 3:
		d.mg._try("sandbags", TrenchNet.snap_pos(cp + sd * ((k - 1) * 4.4) + south * 2.0), 0.0, d.foe)
	d.mg._try("wreck", cp + sd * 8.0 - south * 3.0, 0.4, -1, {"variant": 1})
	d.enemy("fighter_cell", cp - south * 4.0).order_defend(cp, south)
	d.enemy("rpg_team", cp - south * 8.0 - sd * 9.0).order_defend(cp - south * 4.0 - sd * 9.0, south)
	# and a gun in a house looking down the street behind it
	var watch := _houses(w, (cp + hv) * 0.5, 30.0)
	var wp: Vector3 = watch[0].position if not watch.is_empty() else (cp + hv) * 0.5 + sd * 12.0
	d.enemy("pkm_team", wp).order_defend(wp, south)
	# the house: his bodyguard inside and next door, and the man himself
	var guard := d.enemy("fighter_cell", hv)
	guard.order_defend(hv, south)
	var hvt: Soldier = w.spawn("soldier", {"utype": "fighter", "team": d.foe, "owner": d.ai_owner(d.foe), "pos": _walk(d, hv), "yaw": 0.0,
		"squad": guard.sid, "name": "Commander Rashid Kassem"})
	guard.add(hvt)
	ctx.hvt = hvt
	# the drone comes on station two minutes in
	_support(d, ["greyhawk"], 260.0)
	w.rules.support_ready[d.side]["greyhawk"] = w.time + 120.0
	d.after(120.0, func(): d.radio("Overlord: Greyhawk is on station over the town. Call it in if you need it."))

	d.add("checkpoint", "Clear the checkpoint", "clear", {"pos": cp, "r": 24.0})
	d.add("hvt", "Kill or capture Commander Kassem", "destroy", {"eids": [hvt.eid], "pos": hv})
	d.add("exfil", "Get back to the Hunters", "extract", {"pos": start, "r": 30.0, "frac": 0.75})
	d.radio("Overlord: Kassem is in the house at %s. Checkpoint on the main street first. Quiet as you can." % Defs.grid_ref(hv), hv)
	d.start("checkpoint", func():
		d.radio("Overlord: Checkpoint down. The house is seventy metres up the street, doors barred. Breach it.", hv)
		d.start("hvt", func(): _kingpin_out(d)))


func _kingpin_out(d: MissionDirector) -> void:
	d.radio("Overlord: Jackpot, Kassem is down. The whole town is waking up: get back to the Hunters, now!", ctx.start)
	d.deadline = d.world.time + 150.0
	d.deadline_text = "The Rebels have cut the road out of town."
	d.dirty = true
	d.start("exfil", func(): d.win("Kassem is off the board and the raid is out of the town."))
	# everyone in town comes running, and two technicals from the north
	var north := Vector3(0, 0, -1)
	var hv: Vector3 = ctx.hv
	for i in 2:
		var q := d.enemy("fighter_cell", hv + north * 90.0 + Vector3(i * 30.0 - 15.0, 0, 0))
		q.order_assault(ctx.cp + Vector3(i * 14.0 - 7.0, 0, 0), -north)
	d.after(25.0, func():
		for i in 2:
			var t := d.vehicle("technical", _walk(d, hv + north * 140.0 + Vector3(i * 14.0, 0, 0)), Defs.yaw_of(-north), d.foe, d.ai_owner(d.foe))
			t.order_assault(ctx.start - north * 30.0))


## (FL_DEBUG_MISSION) Every squad and vehicle on the field, and Kassem, each
## time the autopilot thinks: where they are, their orders, plans and drills.
func _kp_trace(d: MissionDirector) -> void:
	var w := d.world
	var line := "KP t=%.0f" % w.time
	for sq in w.squads.values():
		var al: Array = sq.alive_members()
		if al.is_empty():
			continue
		var ph: String = String(sq.plan.phase) if sq.plan != null else "-"
		line += " | %s%d %s %d/%d @%s %s/%s dr=%s m=%d" % ["C" if sq.team == d.side else "R", sq.sid, sq.kind, al.size(), sq.members.size(), str(sq.centroid().round()), sq.order, ph, sq.drill, int(sq.morale)]
	for v in w.vehicles:
		if not v.gone and v.hp > 0.0:
			line += " | V%d %s t%d @%s hp=%d" % [v.eid, v.vkind, v.team, str(v.position.round()), int(v.hp)]
	var h = ctx.get("hvt")
	if h != null and is_instance_valid(h):
		line += " | HVT @%s life=%d seen=%s" % [str(h.position.round()), h.life, str(h.visible_to_team(d.side))]
	print(line)


func _drive_kingpin(d: MissionDirector) -> void:
	if OS.has_environment("FL_DEBUG_MISSION"):
		_kp_trace(d)
	var stage := ""
	if _active(d, "checkpoint"):
		stage = "cp"
	elif _active(d, "hvt"):
		stage = "hvt"
	elif _active(d, "exfil"):
		stage = "exfil"
	if stage == "":
		return
	var start: Vector3 = ctx.start
	var south := Vector3(0, 0, 1)
	if stage == "exfil":
		# everyone back to the Hunters at a run, the crews of any wreck too
		# (they count): a run doesn't stop to trade shots
		var i := 0
		for sq in _my_squads(d):
			if _once("sq%d" % sq.sid, stage, 20.0):
				sq.order_move(start + Vector3((i % 3 - 1) * 8.0, 0, 0), -south, 2)
			i += 1
		# the Hunters hold the street just short of them, guns to the north,
		# covering the run back and waiting for the technicals
		for v in ctx.vh:
			if _live(v) and _once("vh%d" % v.eid, stage):
				v.order_assault(_walk(d, start - south * 40.0))
		_kp_drone(d, stage, start)
		return
	var at := _kp_target(d, stage)
	var force := []
	for sq in _my_squads(d):
		if sq.kind != "crew":  # a wreck's crew goes back to crew another
			force.append(sq)
	_kp_assault(d, force, at, stage)
	_kp_drone(d, stage, at)
	_kp_hunters(d, stage, at, force)


## (autopilot) The whole force goes in as one, the way a player sends it
## (every squad selected, one assault order): a platoon attack, one squad
## fixing the enemy while the rest go round a flank (see AttackPlan). Ordered
## squad by squad, each plans an attack of its own, finds itself outnumbered
## and goes firm, and they sit there. The order stands while the attack goes
## on; it's given again once the attack is over and the job isn't done, or
## when the enemy has moved on. A long way off (after Kassem, who has run),
## they close at a run first and attack from there.
func _kp_assault(d: MissionDirector, force: Array, at: Vector3, stage: String) -> void:
	if force.is_empty():
		return
	var was: Array = _staged.get("kp_force", ["", -1e9, Vector3.INF])
	var going := false
	var c := Vector3.ZERO
	for sq in force:
		c += sq.centroid()
		if sq.plan != null and not sq.plan.done:
			going = true
	c /= force.size()
	var moved := Defs.flat(at - (was[2] as Vector3)).length() > 25.0
	if was[0] == stage and (_now - float(was[1]) < 20.0 or (going and not moved)):
		return
	_staged["kp_force"] = [stage, _now, at]
	var order := {"t": "assault", "pos": at}
	var far := Defs.flat(at - c).length()
	if stage == "hvt" and far > 100.0 and Defs.flat(at - (ctx.hv as Vector3)).length() > 25.0:
		order = {"t": "move", "pos": _walk(d, at + Defs.flat(c - at).normalized() * 70.0), "mode": 2}
	_kp_order(d, force, order)


## (autopilot) One order to every squad of the force at once, as a commander
## gives it with them all selected (World.execute_cmd); in co-op each
## commander gives it to his own share.
func _kp_order(d: MissionDirector, force: Array, cmd: Dictionary) -> void:
	var by_owner := {}
	for sq in force:
		if not by_owner.has(sq.owner):
			by_owner[sq.owner] = []
		by_owner[sq.owner].append(sq.sid)
	for o in by_owner:
		var c := cmd.duplicate()
		c["squads"] = by_owner[o]
		d.world.execute_cmd(int(o), c)


## (autopilot) What the force goes for: the enemy we know is holding the
## checkpoint, then Kassem - in the house, or wherever he went: under fire his
## bodyguard pulls out and takes him with it. It follows him where he was
## seen; if nobody saw him go, it finds the house empty and casts about for
## him from there (a stand-in for players sweeping the streets around it).
func _kp_target(d: MissionDirector, stage: String) -> Vector3:
	var known := _kp_known(d)
	if stage == "cp":
		var c := Vector3.ZERO
		var n := 0
		for id in known:
			var p: Vector3 = known[id].pos
			if Defs.flat(p - ctx.cp).length() < 30.0:
				c += p
				n += 1
		return c / n if n > 0 else ctx.cp
	var hv: Vector3 = ctx.hv
	var h = ctx.hvt
	if not is_instance_valid(h) or not d.alive(h.eid):
		return hv
	var gone: bool = Defs.flat(h.position - hv).length() > 15.0
	if gone and d.afoot_in(hv, 12.0) > 0:
		ctx.empty = true
	if h.visible_to_team(d.side):
		return h.position
	if known.has(h.eid):
		return known[h.eid].pos
	# his bodyguard, seen on the move
	var c2 := Vector3.ZERO
	var n2 := 0
	for id in known:
		var e = known[id].e
		if is_instance_valid(e) and e.squad == h.squad and Defs.flat((known[id].pos as Vector3) - hv).length() > 15.0:
			c2 += known[id].pos
			n2 += 1
	if n2 > 0:
		return c2 / n2
	if gone and ctx.get("empty", false):
		return h.position
	return hv


## Enemies our side knows of (seen in the last half minute and still on
## their feet): eid -> {e, pos, t}, the latest report of each.
func _kp_known(d: MissionDirector, secs := 30.0) -> Dictionary:
	var out := {}
	for sq in d.world.squads.values():
		if sq.team != d.side:
			continue
		for id in sq.known:
			var k: Dictionary = sq.known[id]
			var e = k.e
			if not is_instance_valid(e) or e.gone or not (e is Soldier) or e.life != Soldier.Life.ALIVE or _now - float(k.t) > secs:
				continue
			if not out.has(id) or float(k.t) > float(out[id].t):
				out[id] = k
	return out


## (autopilot) Has the attack stuck? A plan of ours gone firm against too
## many of them, or thrown back to its start line: that's when a player calls
## for fire, or brings the guns up. Returns where it's fixed on (or INF).
func _kp_stuck(force: Array) -> Vector3:
	for sq in force:
		var p = sq.plan
		if p != null and not p.done and String(p.phase) in ["fix", "fallback"]:
			return p.fire_at
	return Vector3.INF


## (autopilot) The Greyhawk, once it's on station, where a player would want
## it: on an attack that has stuck, on Kassem if he's seen running, or on
## whatever is chasing the raid out of town. Never on his house while he's in
## it: fire from above that it can't answer breaks his bodyguard, and when it
## runs it takes him along, as far as the edge of the map. Never with our own
## men close to the spot either (they'd take cover from it themselves).
func _kp_drone(d: MissionDirector, stage: String, at: Vector3) -> void:
	if ctx.get("drone", false) or not "greyhawk" in d.support or d.world.rules.support_left(d.side, "greyhawk") > 0.0:
		return
	var aim := Vector3.INF
	if stage == "exfil":
		# the enemy nearest the rally point: the technicals, or the cells on our heels
		var bd := 1e9
		for sq in d.world.squads.values():
			if sq.team != d.side:
				continue
			for id in sq.known:
				var k: Dictionary = sq.known[id]
				var e = k.e
				if not is_instance_valid(e) or e.gone or _now - float(k.t) > 8.0 or (e is Soldier and e.life != Soldier.Life.ALIVE) or (e is Vehicle and e.hp <= 0.0):
					continue
				var dd := Defs.flat((k.pos as Vector3) - at).length()
				if dd < bd and dd < 160.0:
					bd = dd
					aim = k.pos
	else:
		aim = _kp_stuck(_my_squads(d))
		var h = ctx.hvt
		if stage == "hvt" and is_instance_valid(h) and d.alive(h.eid):
			var out: bool = Defs.flat(h.position - (ctx.hv as Vector3)).length() > 15.0
			if out and h.visible_to_team(d.side):
				aim = h.position
			elif not out and aim != Vector3.INF and Defs.flat(aim - (ctx.hv as Vector3)).length() < 30.0:
				aim = Vector3.INF
	if aim == Vector3.INF:
		return
	for s in d.world.soldiers_near(aim, 30.0):
		if s.team == d.side and s.life == Soldier.Life.ALIVE:
			return
	ctx.drone = d.world.rules.call_support(d.owners[0], d.side, "greyhawk", aim)


## (autopilot) The Hunters: a fire base out of the RPGs' reach (they sit just
## beyond the checkpoint) while the infantry takes it - brought up close if
## the attack sticks and nobody has seen an RPG for a while, and kept there -
## then up the street behind the assault on the house, their .50s in range of
## wherever it's going, and after Kassem himself if he's seen running. Never
## up to where an RPG gunner has been seen lately.
func _kp_hunters(d: MissionDirector, stage: String, at: Vector3, force: Array) -> void:
	var start: Vector3 = ctx.start
	var cp: Vector3 = ctx.cp
	var back := Defs.flat(start - at).normalized()
	var fb := cp + Vector3(0, 0, 85.0)
	if stage == "cp" and (ctx.get("guns_up", false) or _kp_stuck(force) != Vector3.INF) and not _kp_rpgs(d, cp, 110.0):
		ctx.guns_up = true
		fb = at + back * 50.0
	elif stage == "hvt" and not _kp_rpgs(d, at + back * 55.0, 90.0):
		fb = at + back * 55.0
	fb = _walk(d, fb)
	var h = ctx.hvt
	var chase: bool = stage == "hvt" and is_instance_valid(h) and d.alive(h.eid) and h.visible_to_team(d.side) \
		and Defs.flat(h.position - (ctx.hv as Vector3)).length() > 15.0 and not _kp_rpgs(d, h.position, 90.0)
	for v in ctx.vh:
		if not _live(v):
			continue
		if chase:
			if _once("vh%d" % v.eid, "chase", 10.0):
				v.order_attack(h)
		elif _once("vh%d" % v.eid, "%s%s" % [stage, str((fb / 20.0).round())]):
			v.order_assault(fb)


## Is an RPG gunner with rockets left known to be about (seen in the last
## minute, still on his feet) within r of a point?
func _kp_rpgs(d: MissionDirector, p: Vector3, r: float) -> bool:
	var known := _kp_known(d, 60.0)
	for id in known:
		var e = known[id].e
		if e.rockets > 0 and Defs.flat((known[id].pos as Vector3) - p).length() < r:
			return true
	return false
