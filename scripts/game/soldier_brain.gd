class_name SoldierBrain
extends RefCounted
## What a soldier does about what's going on around him, in priority order
## whenever he thinks:
##   1. reflexes, most urgent first - a grenade lands by him (throw himself on
##      it if that's the only way to save the men around him, throw it back if
##      there's time, kick it away if it's at his feet, get down if there's a
##      wall between him and it, or dive clear), a shell whistling in, a drone
##      diving on him, an enemy within arm's reach;
##   2. when he's free, the fight - an enemy in a house: stack beside the door,
##      cook a grenade, step into the doorway, throw it in, back against the
##      wall for the bang, then in with a mate before they recover; his special
##      weapons (mortar, launcher, drone, a grenade over a wall); his place
##      behind cover.
## Men busy with something that can't wait (a stretcher, crawling wounded,
## the tunnels) keep only the reflexes that save their own skin.

## Keep reflex priority explicit; per-man decisions need no tree dispatch.
static func think(s: Soldier) -> void:
	if s.task == "smother":
		return
	if busy(s):
		if s._react_grenade(true):
			s.bt_path = "dive from a grenade"
		elif s._react_shells(true):
			s.bt_path = "dive from a shell"
		return
	if grenade_close(s):
		if _native(s):
			_react_native(s)
			return
		if can_smother(s):
			smother(s)
			s.bt_path = "throw himself on it"
		elif can_throw_back(s):
			throw_back(s)
			s.bt_path = "pick it up"
		elif can_kick(s):
			kick(s)
			s.bt_path = "kick it away"
		elif wall_between(s):
			duck(s)
			s.bt_path = "get down behind it"
		else:
			dive_clear(s)
			s.bt_path = "dive clear"
		return
	if s._react_shells(false):
		s.bt_path = "shell incoming"
		return
	if drone(s) != BT.FAIL:
		s.bt_path = "drone diving"
		return
	if s.task != "man" and s.task != "pilot" and s._try_melee():
		s.bt_path = "hand to hand"
		return
	scavenge(s)
	if s.task != "":
		return
	if can_breach(s):
		breach(s)
	elif not s._try_mortar() and not s._try_rocket() and not s._try_drone() and not s._try_grenade():
		hold(s)
	sector(s)
	s.bt_path = "watch his sector"


static func ok(b: bool) -> int:
	return BT.OK if b else BT.FAIL


static func _pick(s: Soldier, arr: Array) -> String:
	return arr[s.world.rng.randi() % arr.size()]


# --- busy / duty ----------------------------------------------------------------

static func busy(s: Soldier) -> bool:
	return s.is_bearer() or s.task in ["stretcher", "limp", "tunnel", "retreat", "captor"] or (s.task == "rescue" and s.task_phase >= 1)


static func scavenge(s: Soldier) -> int:
	s._scavenge()
	return BT.FAIL


static func hold(s: Soldier) -> int:
	s._fight_think()
	return BT.OK


static func sector(s: Soldier) -> int:
	s._sector = s._sector_dir() if s.squad and s.squad.tactical() and not s.is_moving() else Vector3.ZERO
	return BT.OK


static func drone(s: Soldier) -> int:
	s._react_drones()
	return ok(s.dive_t > 0.0)


# --- grenades ------------------------------------------------------------------------

static func _native(s: Soldier) -> bool:
	return s.world.settings.get("rust_infantry", false) and ClassDB.class_exists("GrenadeReactionCore") and s.world.combat != null and s.world.combat._collision != null


static func _core(s: Soldier) -> RefCounted:
	if s._grenade_core == null:
		s._grenade_core = ClassDB.instantiate("GrenadeReactionCore")
	return s._grenade_core


static func _round(g: Projectile) -> Array:
	return [g.eid, g.position, g.fuse, g.held_by != null, g.gone, g.flying, _free(g), g.smothered_by != null, g.thrown_back]


static func _actor(s: Soldier) -> Array:
	return [s.eid, s.position, s.center_point(), s.rotation.y, s.team, s.suppression, s.posture, s.squad != null, s.mounted != null, s.riding != null, not s.wdef.is_empty()]


static func _mates(s: Soldier, g: Projectile, radius: float) -> Array:
	var out := []
	for other in s.world.soldiers_near(g.position, radius):
		out.append([other.eid, other.position, other.center_point(), other.team, other.life,
			other.dragged_by != null or other.task in ["rescue", "heal", "stretcher"] or other.mounted != null])
	return out


static func _react_native(s: Soldier) -> void:
	s.world.combat._sync_collision()
	var result: PackedInt64Array = _core(s).react(_actor(s), _round(s.bt_g), _mates(s, s.bt_g, 4.5), s.world.combat._collision, s.world.rng._backend)
	assert(result.size() == 2, "Invalid grenade reaction")
	match result[0]:
		0:
			smother(s)
			s.bt_path = "throw himself on it"
		1:
			throw_back(s)
			s.bt_path = "pick it up"
		2:
			kick(s)
			s.bt_path = "kick it away"
		3:
			var body = s.world.combat._collision_bodies.get(result[1])
			if is_instance_valid(body) and s.world.combat.ent_of(body) is Structure:
				duck(s)
				s.bt_path = "get down behind it"
			else:
				dive_clear(s)
				s.bt_path = "dive clear"
		_:
			dive_clear(s)
			s.bt_path = "dive clear"


static func _native_task(s: Soldier) -> bool:
	return _native(s) and s.world.nav != null and s.world.nav._planner != null


static func _task_native(s: Soldier, dt: float, kind: int) -> void:
	var g := s.task_ent as Projectile
	if not is_instance_valid(g):
		g = null
	var mount_pos := Vector3.ZERO
	var mount_rate := -1.0
	if is_instance_valid(s.mounted) and not s.mounted.gone and s.mounted.skind in ["mg_nest", "hmg_nest", "mortar_pit", "at_post"]:
		mount_pos = s.mounted.mount_pos()
		mount_rate = deg_to_rad(float({"mg_nest": 55.0, "hmg_nest": 35.0, "mortar_pit": 12.0, "at_post": 20.0}[s.mounted.skind]))
	var context := PackedFloat64Array([s.position.x, s.position.y, s.position.z, s.rotation.y, s.world.time, s.task_t, dt, mount_pos.x, mount_pos.y, mount_pos.z, mount_rate])
	var result: Array = _core(s).advance(kind, context, _round(g) if g != null else [], g != null and g.held_by == s, s.world.nav._planner)
	assert(result.size() == 3, "Invalid grenade task step")
	s.position = result[0]
	s.rotation.y = float(result[1])
	match int(result[2]):
		0:
			s.task = ""
			if kind == 0:
				s.task_ent = null
				s.posture = Soldier.Post.PRONE
				s.act = Soldier.Act.IDLE
		1:
			s.task = ""
			s._dive_from(g.position)
		2:
			s.posture = Soldier.Post.PRONE
			s.act = Soldier.Act.SMOTHER
		3:
			s.posture = Soldier.Post.PRONE
			s.act = Soldier.Act.DIVE
		4:
			s.posture = Soldier.Post.STAND
			s.task = ""
			s._begin_action("kick", 0.3, {"g": g, "v": kick_vel(s, g)})
		5:
			s.act = Soldier.Act.RUN
			s.posture = Soldier.Post.STAND
			g.pick_up(s)
			s.task = ""
			s._begin_action("pickup", 0.2, {"g": g})
		6:
			s.act = Soldier.Act.RUN
			s.posture = Soldier.Post.STAND


## A live grenade near him he hasn't reacted to yet (kept in s.bt_g).
static func grenade_close(s: Soldier) -> bool:
	s.bt_g = null
	if _native(s):
		var rounds := []
		for g: Projectile in s.world.projectiles:
			if g.ptype == "frag":
				rounds.append(_round(g))
		var result: Array = _core(s).notice(s.position, PackedInt64Array(s.seen_grenades.keys()), rounds, true)
		assert(result.size() == 2, "Invalid grenade notice")
		s.seen_grenades.clear()
		for id: int in result[1]:
			s.seen_grenades[id] = true
		if int(result[0]) == 0:
			return false
		s.say(_pick(s, ["GRENADE!", "Grenade! Get down!", "Frag!"]), true)
		s.bt_g = s.world.entity(int(result[0])) as Projectile
		assert(s.bt_g != null, "Missing noticed grenade")
		return true
	for g in s.world.projectiles:
		if g.ptype != "frag" or g.held_by != null or g.gone:
			continue
		var d := Defs.flat(g.position - s.position).length()
		if d > 7.5 or s.seen_grenades.has(g.eid):
			continue
		if g.flying and g.fuse > 2.2 and d > 4.0:
			continue  # still in the air, coming down well off
		if s.seen_grenades.size() > 24:
			s.seen_grenades.clear()  # old rounds are long gone
		s.seen_grenades[g.eid] = true
		s.say(_pick(s, ["GRENADE!", "Grenade! Get down!", "Frag!"]), true)
		s.bt_g = g
		return true
	return false


## Nobody else is already dealing with it.
static func _free(g: Projectile) -> bool:
	var h: Soldier = g.handler
	return h == null or not is_instance_valid(h) or h.gone or h.life != Soldier.Life.ALIVE or not (h.task in ["smother", "gkick", "grenade_pickup"] or h.act_kind in ["kick", "pickup", "rethrow"])


static func _g_dist(s: Soldier) -> float:
	var g: Projectile = s.bt_g
	return Defs.flat(g.position - s.position).length() if g != null else 99.0


## Throwing himself on it: only when it's too late to throw it, it's in the
## middle of his mates - a wounded man who can't get away, or a crowded trench
## bay - and he's the one right by it. Most men would dive; a few don't.
static func can_smother(s: Soldier) -> bool:
	var g: Projectile = s.bt_g
	if g == null or g.gone or g.smothered_by != null or not _free(g) or s.squad == null or s.mounted != null or s.riding != null:
		return false
	var d := _g_dist(s)
	if d > 3.2 or g.fuse < 0.5 or g.fuse > 2.6 or g.position.y > 0.7:
		return false
	var at_risk := 0
	var helpless := 0
	var from := g.position + Vector3(0, 0.35, 0)
	for o in s.world.soldiers_near(g.position, 4.5):
		if o == s or o.team != s.team or not (o.life == Soldier.Life.ALIVE or o.life == Soldier.Life.DOWNED):
			continue
		if not s.world.combat.ray(from, o.center_point()).is_empty():
			continue  # a wall between him and it
		at_risk += 1
		if o.life == Soldier.Life.DOWNED or o.dragged_by != null or o.task in ["rescue", "heal", "stretcher"] or o.mounted != null:
			helpless += 1
	if helpless == 0 and at_risk < 3:
		return false
	var p := 0.06 * at_risk + 0.22 * helpless
	if g.fuse > 1.8:
		p *= 0.5  # there may still be time to get it out
	return s.world.rng.randf() < minf(p, 0.55)


static func smother(s: Soldier) -> int:
	var g: Projectile = s.bt_g
	g.smothered_by = s
	g.handler = s
	s._clear_task()
	s.task = "smother"
	s.task_ent = g
	s.task_t = s.world.time
	s.stop_moving()
	s.at_cover = false
	s.peek_up = false
	s.blind = false
	s._face_now(Defs.flat(g.position - s.position))
	s.say(_pick(s, ["GRENADE! Get back!", "Get down! I've got it!", "Get away from it!"]), true)
	s.world.stat("smother")
	return BT.OK


## Diving onto it: his chest over it, his arms and knees tucked round it.
static func smother_tick(s: Soldier, dt: float) -> void:
	if _native_task(s):
		_task_native(s, dt, 0)
		return
	var g := s.task_ent as Projectile
	if g == null or g.gone or (g.held_by != null and g.held_by != s):
		s.task = ""
		s.task_ent = null
		s.posture = Soldier.Post.PRONE
		s.act = Soldier.Act.IDLE
		return
	var fwd := Defs.dir_of(s.rotation.y)
	var spot := Vector3(g.position.x, s.position.y, g.position.z) - fwd * 0.75
	var to := Defs.flat(spot - s.position)
	if to.length() > 0.06 and s.world.time - s.task_t < 1.0:
		s.act = Soldier.Act.DIVE
		s.posture = Soldier.Post.PRONE
		s.position += to.limit_length(6.5 * dt)
		return
	s.posture = Soldier.Post.PRONE
	s.act = Soldier.Act.SMOTHER


## The blast goes into him: it kills him, and what's left of it doesn't
## carry far.
static func smothered(g: Projectile) -> bool:
	var s: Soldier = g.smothered_by
	if s == null or not is_instance_valid(s) or s.gone or s.life != Soldier.Life.ALIVE or s.task != "smother":
		return false
	var covered := false
	if _native(s):
		var result = _core(s).covers_grenade(s.position, s.rotation.y, g.position)
		assert(result != null, "Invalid grenade covering pose")
		covered = bool(result)
	else:
		var chest := s.position + Defs.dir_of(s.rotation.y) * 0.75
		covered = Defs.flat(chest - g.position).length() <= 0.9
	if not covered:
		return false
	var src: Entity = g.world.entity(g.thrower_id)
	s.take_damage(900.0, src, Vector3.UP, "explosion")
	g.world.combat.explode(g.position, {"dmg": 32.0, "radius": 2.6, "fling": 0.0, "at": 0.0, "src": src, "team": g.team, "size": 0.55})
	g.world.send_msg(s.team, "info", "%s threw himself on a grenade to save his squad." % s.sname, s.position)
	g.world.stat("smother_saved")
	return true


static func can_throw_back(s: Soldier) -> bool:
	var g: Projectile = s.bt_g
	return g != null and not g.gone and _free(g) and _g_dist(s) < 3.8 and g.fuse > 1.8 and g.thrown_back < 1 and s.suppression < 75.0 \
		and not s.wdef.is_empty() and s.world.rng.randf() < 0.25


static func throw_back(s: Soldier) -> int:
	s.task = "grenade_pickup"
	s.task_ent = s.bt_g
	s.bt_g.handler = s
	s.stop_moving()
	s.world.stat("grenade_pickup")
	return BT.OK


## Lying on the ground a step or two away: a hard kick sends it skittering
## off, away from his mates and back towards whoever threw it.
static func can_kick(s: Soldier) -> bool:
	var g: Projectile = s.bt_g
	return g != null and not g.gone and _free(g) and g.position.y < 0.45 and _g_dist(s) <= 2.0 and g.fuse > 1.0 and s.suppression < 80.0 \
		and s.posture != Soldier.Post.PRONE and s.world.rng.randf() < 0.4


static func kick(s: Soldier) -> int:
	s._clear_task()
	s.task = "gkick"
	s.task_ent = s.bt_g
	s.bt_g.handler = s
	s.stop_moving()
	s.world.stat("grenade_kick")
	return BT.OK


static func gkick_tick(s: Soldier, dt: float) -> void:
	if _native_task(s):
		_task_native(s, dt, 1)
		return
	var g := s.task_ent as Projectile
	if g == null or g.gone or g.held_by != null or g.fuse < 0.35:
		s.task = ""
		if g != null and not g.gone:
			s._dive_from(g.position)
		return
	var to := Defs.flat(g.position - s.position)
	s.posture = Soldier.Post.STAND
	if to.length() < 0.7:
		s.task = ""
		s._begin_action("kick", 0.3, {"g": g, "v": kick_vel(s, g)})
		return
	s.act = Soldier.Act.RUN
	var np := s.position + to.normalized() * minf(to.length(), 5.5 * dt)
	if s.world.nav.walkable(np):
		s.position = np
	s._face(to, dt, 14.0)


static func kick_vel(s: Soldier, g: Projectile) -> Vector3:
	if _native(s):
		var thrower: Entity = s.world.entity(g.thrower_id)
		var from = thrower.position if thrower != null and not thrower.gone and thrower.team != s.team else null
		var result = _core(s).kick_velocity(_actor(s), _round(g), _mates(s, g, 6.0), from)
		assert(result is Vector3, "Invalid grenade kick velocity")
		return result
	var dir := Defs.flat(g.position - s.position).normalized()
	if dir.length() < 0.5:
		dir = Defs.dir_of(s.rotation.y)
	# away from his mates
	var mates := Vector3.ZERO
	for o in s.world.soldiers_near(g.position, 6.0):
		if o != s and o.team == s.team and o.life == Soldier.Life.ALIVE:
			mates += Defs.flat(o.position - g.position)
	if mates.length() > 0.1:
		dir = (dir - mates.normalized() * 0.6).normalized()
	# and back where it came from
	var src: Entity = s.world.entity(g.thrower_id)
	if src != null and not src.gone and src.team != s.team:
		dir = (dir + Defs.flat(src.position - g.position).normalized() * 0.7).normalized()
	return dir * 9.0 + Vector3(0, 3.0, 0)


## Is there something solid between him and it? Then down behind it, not up
## and running across the open.
static func wall_between(s: Soldier) -> bool:
	var g: Projectile = s.bt_g
	if g == null or g.gone or _g_dist(s) < 1.2:
		return false
	var r: Dictionary = s.world.combat.ray(g.position + Vector3(0, 0.35, 0), s.center_point())
	return not r.is_empty() and s.world.combat.ent_of(r.collider) is Structure


static func duck(s: Soldier) -> int:
	var g: Projectile = s.bt_g
	s.hit_dirt_t = maxf(s.hit_dirt_t, g.fuse + 0.4)
	s.stop_moving()
	s.peek_up = false
	s.blind = false
	s.world.stat("grenade_duck")
	return BT.OK


static func dive_clear(s: Soldier) -> int:
	var g: Projectile = s.bt_g
	s._dive_from(g.position if g != null else s.position)
	return BT.OK


## A grenade thrown at men in hard cover close by is cooked first - held a
## second or so after the spoon flies - so it goes off before they can throw
## it back. How long he holds it.
static func cook_time(s: Soldier, target: Entity, d: float) -> float:
	if _native(s):
		var hard_cover: bool = target is Soldier and target.at_cover and target.cover_mat >= Cover.HARD
		var result = _core(s).cook_time(s.team, d, hard_cover, s.world.rng._backend)
		assert(result != null, "Invalid grenade cook time")
		return float(result)
	if d > 20.0:
		return 0.0
	var p := 0.3 if s.team == 1 else 0.45
	if target is Soldier and (target as Soldier).at_cover and (target as Soldier).cover_mat >= Cover.HARD:
		p += 0.25
	if s.world.rng.randf() > p:
		return 0.0
	return s.world.rng.randf_range(0.8, 1.4)


# --- clearing a house ---------------------------------------------------------------

## The house (its floor) that p is in, or null.
static func house_at(w: World, p: Vector3) -> Structure:
	for st in w.structures_near(p, 9.0, true):
		if st.skind != "floor" or st.gone:
			continue
		var l: Vector3 = Basis(Vector3.UP, -st.yaw) * (p - st.position)
		if absf(l.x) < st.size.x * 0.5 and absf(l.z) < st.size.z * 0.5:
			return st
	return null


## Its doorways and windows: [wall, centre, outward normal, is a door].
static func openings(w: World, house: Structure) -> Array:
	var out := []
	var reach := maxf(house.size.x, house.size.z) * 0.5 + 1.5
	for st in w.structures_near(house.position, reach):
		if st.skind != "house_wall" or st.gone or st.wrecked or not (st.variant in [1, 2]):
			continue
		var l: Vector3 = Basis(Vector3.UP, -house.yaw) * (st.position - house.position)
		if absf(l.x) > house.size.x * 0.5 + 0.6 or absf(l.z) > house.size.z * 0.5 + 0.6:
			continue
		var n: Vector3 = Basis(Vector3.UP, st.yaw) * Vector3(0, 0, 1)
		if n.dot(Defs.flat(st.position - house.position)) < 0.0:
			n = -n
		out.append([st, Defs.flat(st.position), Defs.flat(n).normalized(), st.variant == 2])
	return out


## Beside the opening outside, back to the wall, on the side nearer him.
static func _stack_spot(s: Soldier, o: Array) -> Vector3:
	var c: Vector3 = o[1]
	var n: Vector3 = o[2]
	var along := Vector3(n.z, 0, -n.x)
	var side := 1.0 if (s.position - c).dot(along) >= 0.0 else -1.0
	var half := 0.95 if o[3] else 0.65
	return s.world.nav.nearest_walkable(c + n * 0.5 + along * side * (half + 0.6))


static func _anyone_inside(s: Soldier, h: Structure) -> Soldier:
	if s.squad == null:
		return null
	for k in s.squad.known.values():
		var e = k.e
		if e is Soldier and not e.gone and e.life == Soldier.Life.ALIVE and s.world.time - float(k.t) < 30.0 and house_at(s.world, e.position) == h:
			return e
	return null


## An enemy his squad has seen in a house nearby, the way in he's best placed
## to use, and nobody else from his squad already on it (kept in s.bt_breach).
static func can_breach(s: Soldier) -> bool:
	if s.world.time < s.bt_next_breach:
		return false
	s.bt_next_breach = s.world.time + 1.5
	if s.frags <= 0 or s.squad == null or s.suppression > 50.0 or s.mounted != null or s.is_bearer() or s.cur_weapon().is_empty():
		return false
	var cl: Soldier = s.squad.breach_by
	if cl != null and is_instance_valid(cl) and cl != s and not cl.gone and cl.life == Soldier.Life.ALIVE and cl.task == "breach":
		return false
	var mine := house_at(s.world, s.position)
	for contact in s.squad.building_contacts():
		var e: Soldier = contact[0]
		var h: Structure = contact[1]
		if not is_instance_valid(e) or not is_instance_valid(h) or e.gone or h.gone or e.life != Soldier.Life.ALIVE:
			continue
		if h == mine:
			continue
		if Defs.flat(h.position - s.position).length() > 30.0 or Defs.flat(h.position - s.hold_pos).length() > 32.0:
			continue
		var best := []
		var bd := 1e9
		for o in openings(s.world, h):
			var dd := Defs.flat(_stack_spot(s, o) - s.position).length() + (0.0 if o[3] else 3.0)
			if dd < bd:
				bd = dd
				best = o
		if best.is_empty() or bd > 26.0:
			continue
		# the man of his squad best placed to do it
		for m in s.squad.members:
			if m != s and m.life == Soldier.Life.ALIVE and m.task == "" and m.frags > 0 and m.mounted == null \
					and Defs.flat(m.position - best[1]).length() < bd - 3.0:
				return false
		s.bt_breach = [h, best, e]
		return true
	return false


static func breach(s: Soldier, clear := false) -> int:
	var h: Structure = s.bt_breach[0]
	var o: Array = s.bt_breach[1]
	s._clear_task()
	s.bt_clear = clear
	s.bt_nofrag = false
	s.task = "breach"
	s.task_ent = o[0]
	s.task_ent2 = s.bt_breach[2]
	s.task_phase = 0
	s.task_t = s.world.time
	s.squad.breach_by = s
	s.bt_house = h
	s.bt_door = o
	s.bt_cook_t0 = -1.0
	s.bt_breach_g = null
	s.bt_reordered = false
	s.task_pos = _stack_spot(s, o)
	s.at_cover = false
	s.peek_up = false
	s.go_to(s.task_pos, "task", 2 if s._danger() else 1)
	if clear:
		return BT.OK
	s.say(_pick(s, ["They're in the house! Stacking on the door!", "Enemy inside! I'll frag the room!", "Cover me, grenade through the door!", "Got one in the building! Moving to the door!"]), true)
	s.world.stat("breach")
	return BT.OK


## Clearing a house the squad is moving into: the same stack and entry, but
## the grenade only goes in if someone's known to be inside.
static func start_clearing(s: Soldier, h: Structure, o: Array, buddy: Soldier) -> void:
	s.bt_breach = [h, o, null]
	breach(s, true)
	s.say(_pick(s, ["Clearing that house!", "I'll take the door - on me!", "Stack up, we clear it!", "Checking the building!"]), true)
	if buddy and buddy != s and buddy.can_take_orders() and buddy.task == "":
		# his buddy stacks behind him
		var c: Vector3 = o[1]
		var n: Vector3 = o[2]
		var along := Vector3(n.z, 0, -n.x)
		var side := 1.0 if (s.task_pos - c).dot(along) >= 0.0 else -1.0
		buddy.hold_pos = s.world.nav.nearest_walkable(s.task_pos + along * side * 0.9 + n * 0.3)
		buddy.hold_face = -n
		buddy.leash = 2.0
		buddy.at_cover = false
		buddy.go_to(buddy.hold_pos, "slot", 1)


static func end_breach(s: Soldier) -> void:
	s.task = ""
	s.task_ent = null
	s.task_ent2 = null
	s.task_phase = 0
	if s.squad and s.squad.breach_by == s:
		s.squad.breach_by = null


## Where the grenade goes: towards the man inside, but into the room, through
## the opening (not off the far wall of a big house).
static func _room_target(s: Soldier, h: Structure) -> Vector3:
	var o: Array = s.bt_door
	var c: Vector3 = o[1]
	var n: Vector3 = o[2]
	var along := Vector3(n.z, 0, -n.x)
	var e: Soldier = s.task_ent2 if s.task_ent2 is Soldier and not s.task_ent2.gone and s.task_ent2.life == Soldier.Life.ALIVE else _anyone_inside(s, h)
	var t := (e.position if e else h.position) - c
	var depth := clampf(t.dot(-n), 1.2, 3.6)
	var lat := clampf(t.dot(along), -1.4, 1.4)
	return c - n * depth + along * lat + Vector3(0, 0.06, 0)


static func breach_tick(s: Soldier, dt: float) -> void:
	var wall := s.task_ent as Structure
	var h: Structure = s.bt_house
	if wall == null or wall.gone or h == null or h.gone or s.world.time - s.task_t > 45.0:
		end_breach(s)
		return
	var o: Array = s.bt_door
	var c: Vector3 = o[1]
	var n: Vector3 = o[2]
	match s.task_phase:
		0:
			# to the door, low and fast the last few metres
			var moving := s._move_tick(dt, s._speed())
			s._weapon_tick(dt, moving, "normal")
			if Defs.flat(s.task_pos - s.position).length() < 5.0:
				s.posture = Soldier.Post.CROUCH
			s._choose_act(moving)
			if _anyone_inside(s, h) == null and not s.bt_clear:
				end_breach(s)  # they've gone, or they're dead
				return
			# (right up against the wall the last few centimetres don't matter)
			var near := Defs.flat(s.task_pos - s.position).length() < 0.9
			if not moving and not near:
				if s.world.time - s.task_t > 20.0:
					end_breach(s)
					return
				s.go_to(s.task_pos, "task", 1)
				return
			if near:
				s.stop_moving()
				s.task_phase = 1
				s.bt_wait = s.world.time + s.world.rng.randf_range(0.5, 0.9)
		1:
			# stacked beside the door, back to the wall: a breath, pin out
			s.posture = Soldier.Post.CROUCH
			s.act = Soldier.Act.IDLE
			s._face(Defs.flat(c - s.position).normalized(), dt, 8.0)
			if s.world.time < s.bt_wait:
				return
			s.task_phase = 2
			var e := _anyone_inside(s, h)
			# (nobody cooks a grenade with a shut door still to kick in)
			var shut := wall.door_shut
			if s.bt_clear and (e == null or s.frags <= 0):
				s.bt_nofrag = true  # nobody known to be in there: in with the rifle up
			var ck := 0.0 if shut or s.bt_nofrag else cook_time(s, e, 3.0)
			if ck > 0.0:
				s.bt_cook_t0 = s.world.time
				s._begin_action("cook", ck, {})
			s.task_pos2 = s.world.nav.nearest_walkable(c + n * (0.8 if shut else 1.25))
			s.go_to(s.task_pos2, "task", 1)
		2:
			# step into the doorway and throw it in
			var moving2 := s._move_tick(dt, s._speed())
			s.posture = Soldier.Post.STAND
			s._choose_act(moving2)
			if not moving2 or Defs.flat(s.task_pos2 - s.position).length() < 0.5:
				s.stop_moving()
				if wall.door_shut:
					# kick the door in, then the frag
					s._begin_action("door_kick", 0.45, {"door": wall, "pos": c})
					s.world.stat("breach_door_kick")
					return
				if s.bt_nofrag:
					s.task_phase = 4
					s.bt_wait = s.world.time + s.world.rng.randf_range(0.2, 0.5)
					return
				var fuse := 3.4
				if s.bt_cook_t0 >= 0.0:
					fuse = maxf(1.3, 3.4 - (s.world.time - s.bt_cook_t0))
				s.frags -= 1
				s.world.stat("breach_frag_in")
				s.task_phase = 3
				s.bt_wait = s.world.time + 4.5
				s._begin_action("throw_in", 0.4, {"pos": _room_target(s, h), "kind": "frag", "fuse": fuse})
				s.say(_pick(s, ["Frag out!", "Fire in the hole!", "Grenade in!"]), true)
		3:
			# back against the wall beside the door till it goes off
			var back := Defs.flat(s.position - s.task_pos).length()
			if s.bt_breach_g != null and back > 0.9 and not s.is_moving():
				s.go_to(s.task_pos, "task", 2)
			elif back <= 0.9 and s.is_moving():
				s.stop_moving()
			var moving3 := s._move_tick(dt, s._speed())
			s.posture = Soldier.Post.CROUCH
			s._choose_act(moving3)
			var g: Projectile = s.bt_breach_g
			var bang := s.bt_breach_g != null and (not is_instance_valid(g) or g.gone)
			if bang or s.world.time > s.bt_wait:
				s.task_phase = 4
				s.bt_wait = s.world.time + s.world.rng.randf_range(0.15, 0.4)
		4:
			# in, while they're still reeling - and a mate right behind him
			s.posture = Soldier.Post.CROUCH
			if s.world.time < s.bt_wait:
				return
			if s.bt_reordered:
				# the squad's moving on: after them
				end_breach(s)
				s.go_to(s.hold_pos, "slot", 1)
				return
			var inside := s.world.nav.nearest_walkable(c - n * 2.2)
			s.say(_pick(s, ["Go! Go! Go!", "Moving in!", "In! In!", "Clear the room!"]), true)
			if s.bt_clear and s.squad:
				s.squad.clear_call = [s, s.world.time + 2.5]
			end_breach(s)
			s.hold_pos = inside
			s.hold_face = -n
			s.leash = 2.5
			s.at_cover = false
			s.next_cover_eval = 0.0
			s.go_to(inside, "slot", 2)
			s.world.stat("room_entry")
			var buddy: Soldier = null
			var bd := 14.0
			if s.squad:
				for m in s.squad.members:
					if m == s or m.life != Soldier.Life.ALIVE or m.task != "" or m.mounted != null:
						continue
					var d := Defs.flat(m.position - c).length()
					if d < bd:
						bd = d
						buddy = m
			if buddy:
				var along := Vector3(n.z, 0, -n.x)
				var p2 := s.world.nav.nearest_walkable(c - n * 2.0 + along * 1.4)
				buddy.hold_pos = p2
				buddy.hold_face = -n
				buddy.leash = 2.5
				buddy.at_cover = false
				buddy.next_cover_eval = 0.0
				buddy.go_to(p2, "slot", 2)
				buddy.say(_pick(s, ["Right behind you!", "With you!", "Going in!"]), true)
