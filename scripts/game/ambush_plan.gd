class_name AmbushPlan
extends RefCounted
## A deliberate ambush on a road, the way it's taught:
##   1. MOVE    - the squad moves to a rally point back from the road, out of
##                sight of it.
##   2. OCCUPY  - from there into position, quietly: the assault line along the
##                road 20-30 metres back, in whatever cover and concealment
##                there is; the machine gun at one end, firing down the length
##                of the killing zone (an L); one man out on the far flank as
##                security, watching the way they'll come.
##   3. WAIT    - nobody fires. They let the enemy walk (or drive) into the
##                killing zone; it's sprung when they're in it - or at once
##                if the ambush is found.
##   4. SPRING  - the leader opens fire and everyone fires into the killing
##                zone at once; the anti-tank men take the vehicles.
##   5. WITHDRAW - after a short, violent burst - before the enemy can recover
##                and bring his weight down on them - smoke, and back by bounds
##                to the rally point (insurgents simply melt away).
## An ambush nobody walks into is given up after a few minutes.

const KZ_HALF := 22.0  # the killing zone: this far either side of its centre, along the road
const STANDOFF := 24.0  # the assault line, back from the road
const WAIT_MAX := 260.0
const FIRE_MAX := 28.0

var world: World
var sq: Squad
var kz := Vector3.ZERO  # the killing zone's centre, on the road
var road := Vector3.FORWARD  # along the road
var side := Vector3.RIGHT  # from the road towards the ambush line
var rally := Vector3.ZERO
var mg_end := 1.0  # which end of the killing zone the gun sits at
var phase := "move"
var t0 := 0.0
var fire_t := 0.0
var quiet_t := 0.0
var done := false
var caught := 0  # enemies in the killing zone when it was sprung


static func make(w: World, q: Squad, kz_pos: Vector3, along: Vector3, toward: Vector3) -> AmbushPlan:
	var p := AmbushPlan.new()
	p.world = w
	p.sq = q
	p.kz = kz_pos
	p.road = Defs.flat(along).normalized()
	p.side = Defs.flat(toward).normalized()
	p.rally = w.nav.nearest_walkable(kz_pos + p.side * (STANDOFF + 30.0))
	# the gun at the end with more cover round it
	var best := -1e9
	for e in [-1.0, 1.0]:
		var gp: Vector3 = kz_pos + p.side * STANDOFF * 0.75 + p.road * e * (KZ_HALF + 8.0)
		var s := 1.0 - w.terrain.concealment(gp) + float(w.terrain.cov[w.terrain.idx_of(gp)]) * 0.2
		if s > best:
			best = s
			p.mg_end = e
	p.t0 = w.time
	q.order_move(p.rally, -p.side, 0)
	q.ambush_plan = p
	q.shown_order = "ambush"
	var ld := q.get_leader()
	if ld:
		ld.say(["We hit them on the road. Move quiet.", "Ambush on the road - nobody fires till I do.", "Into the ambush position. Silence from here."][w.rng.randi() % 3]
			if q.team == 0 else ["We wait for them by the road. Quiet now.", "We'll hit them on the road. Follow me."][w.rng.randi() % 2], true)
	w.stat("ambush_set_out")
	return p


func info() -> Array:
	return [phase, kz, road, side]


func tick() -> void:
	if done:
		return
	var alive := sq.alive_members()
	if alive.is_empty() or sq.drill in ["rout", "withdraw"]:
		done = true
		return

	match phase:
		"move":
			var near := Defs.flat(rally - sq.centroid()).length() < 14.0
			var still := true
			for m in alive:
				if m.is_moving():
					still = false
					break
			if _engaged(alive):
				_give_up("bumped into them on the way")
			elif near or (still and world.time - t0 > 20.0 and not sq.travel and sq.technique == ""):
				_occupy(alive)
			elif world.time - t0 > 150.0:
				_give_up("couldn't get into position")
		"wait":
			_wait(alive)
		"spring":
			_fire(alive)


## In a fight of its own on the way (not just gunfire somewhere): the ambush
## is off - they know we're here.
func _engaged(alive: Array) -> bool:
	if SquadBrain.avg_supp(alive) > 15.0 or world.time - sq.last_cas_t < 5.0:
		return true
	var c := sq.centroid()
	for k in sq.known.values():
		if world.time - float(k.t) < 4.0 and Defs.flat(k.pos - c).length() < 70.0:
			return true
	return false


## Into position: the gun at one end, the assault line, a man on the flank.
func _occupy(alive: Array) -> void:
	var gun: Array = []
	var line: Array = []
	var guard: Soldier = null
	for m in alive:
		if not m.can_take_orders() or m.mounted != null:
			continue
		if m.utype in ["mg_gunner", "pkm"] and gun.is_empty():
			gun.append(m)
		else:
			line.append(m)
	if line.size() >= 4:
		# the man furthest from the gun's end watches the far approach
		line.sort_custom(func(a, b): return Defs.flat(a.position - kz).dot(road) * mg_end < Defs.flat(b.position - kz).dot(road) * mg_end)
		guard = line.pop_front()
	var face := -side
	var lc: Vector3 = world.nav.nearest_walkable(kz + side * STANDOFF)
	var slots: Array = sq._assign(sq.formation(lc, face, line.size(), true), line)
	for i in line.size():
		_post(line[i], slots[i], face)
	if not gun.is_empty():
		# down the length of the killing zone: the short leg of the L
		var gp: Vector3 = world.nav.nearest_walkable(kz + side * STANDOFF * 0.75 + road * mg_end * (KZ_HALF + 8.0))
		_post(gun[0], gp, Defs.flat(kz - gp).normalized())
	if guard:
		var sp: Vector3 = world.nav.nearest_walkable(kz + side * (STANDOFF + 6.0) - road * mg_end * (KZ_HALF + 16.0))
		_post(guard, sp, -road * mg_end)
	sq.order = "defend"
	sq.order_pos = lc
	sq.facing = face
	sq.ambush = true
	sq.shown_order = "ambush"
	phase = "wait"
	t0 = world.time
	world.stat("ambush_laid")


func _post(m: Soldier, p: Vector3, face: Vector3) -> void:
	m.cmd_move(p, 0, face)
	m.leash = 3.0



## Lying in wait: sprung when they're in the killing zone, or the moment the
## ambush is found.
func _wait(alive: Array) -> void:
	sq.ambush = true
	var found := SquadBrain.avg_supp(alive) > 8.0 or world.time - sq.last_cas_t < 3.0
	var inside := 0
	var vehicle := false
	var close := false
	for e in world.units_near(kz, KZ_HALF + 30.0):
		if e.team == sq.team or e.team < 0 or e.gone:
			continue
		if e is Soldier and e.life != Soldier.Life.ALIVE:
			continue
		if e is Vehicle and e.is_air():
			continue
		var rel := Defs.flat(e.position - kz)
		if absf(rel.dot(road)) < KZ_HALF and absf(rel.dot(side)) < 12.0:
			inside += 1
			if e is Vehicle:
				vehicle = true
		for m in alive:
			if Defs.flat(e.position - m.position).length() < 14.0:
				close = true  # walked right into one of us
	if found or close or vehicle or inside >= 2 or (inside >= 1 and world.time - quiet_t > 4.0 and quiet_t > 0.0):
		_spring(alive, inside)
		return
	if inside == 1 and quiet_t <= 0.0:
		quiet_t = world.time  # let the rest of them come on into it
	elif inside == 0:
		quiet_t = 0.0
	if world.time - t0 > WAIT_MAX:
		_give_up("nobody came")


func _spring(alive: Array, inside: int) -> void:
	phase = "spring"
	caught = inside
	fire_t = world.time
	quiet_t = 0.0
	sq.ambush = false
	sq.ambush_t = world.time + 4.0  # the first volley, at men who didn't know they were there
	sq.cover_fire_pos = kz
	sq.cover_fire_until = world.time + 6.0
	SquadBrain._say(sq, ["FIRE!", "Now! Open fire!", "Hit them!", "Light them up!"] if sq.team == 0 else ["NOW! Kill them!", "Allahu akbar! Fire!", "Fire, fire!"])
	world.send_msg(sq.team, "info", "%s sprang its ambush." % sq.display_name(), kz)
	world.stat("ambush_sprung")
	for i in inside:
		world.stat("ambush_caught")


## A short, violent burst of fire into the killing zone; then away before
## they can bring their weight down.
func _fire(alive: Array) -> void:
	var live := 0
	for e in world.units_near(kz, KZ_HALF + 25.0):
		if e.team != sq.team and e.team >= 0 and not e.gone and (not (e is Soldier) or e.life == Soldier.Life.ALIVE) and not (e is Vehicle and e.is_air()):
			live += 1
	if live > 0:
		quiet_t = world.time
		if world.time - fire_t < 12.0:
			sq.cover_fire_pos = kz
			sq.cover_fire_until = world.time + 2.0
	var over := world.time - fire_t > FIRE_MAX or (world.time - quiet_t > 6.0 and world.time - fire_t > 8.0)
	if not over:
		return
	done = true
	sq.ambush_plan = null
	SquadBrain._say(sq, ["Cease fire! Pull back to the rally point!", "That's it - break contact, go!", "Done! Smoke, back by teams!"]
		if sq.team == 0 else ["Enough! Go, go - scatter!", "Back! Back to the rally point!", "Melt away! Go!"])
	if sq.team == Defs.REBELS:
		# insurgents don't hang about: everyone back at a run
		SquadBrain._smoke_screen(sq, -side)
		sq.order_move(rally, -side, 2)
	else:
		SquadBrain.start_withdraw(sq)
	world.stat("ambush_withdraw")


func _give_up(_why: String) -> void:
	done = true
	sq.ambush_plan = null
	sq.ambush = false
	sq.shown_order = ""
	world.stat("ambush_abandoned")
