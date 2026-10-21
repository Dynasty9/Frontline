class_name Combat
extends RefCounted
## Server-side ballistics, line of sight, explosions and cover evaluation.
## All "is this cover?" answers come from raycasts against the real
## collision shapes of walls, crates, cars, wrecks, windows and vehicles.

const MASK := 2 | 4

var world: World
var _space: PhysicsDirectSpaceState3D
var _space_frame := -1
var _reveal := {}  # eid -> time


func _init(w: World) -> void:
	world = w


func space() -> PhysicsDirectSpaceState3D:
	var f := Engine.get_physics_frames()
	if f != _space_frame or _space == null:
		_space = world.get_world_3d().direct_space_state
		_space_frame = f
	return _space


var _q := PhysicsRayQueryParameters3D.new()
var _no_ex: Array[RID] = []


func ray(from: Vector3, to: Vector3, ex: Array = []) -> Dictionary:
	# one query object reused for every ray (hundreds a tick)
	_q.from = from
	_q.to = to
	_q.collision_mask = MASK
	if ex.is_empty():
		_q.exclude = _no_ex
	else:
		var t: Array[RID] = []
		t.assign(ex)
		_q.exclude = t
	return space().intersect_ray(_q)


func ent_of(col) -> Entity:
	if col == null or not (col is Object) or not col.has_meta("eid"):
		return null
	return world.entity(int(col.get_meta("eid")))


func smoke_blocks(a: Vector3, b: Vector3) -> bool:
	for p in world.projectiles:
		if p.ptype == "smoke" and p.smoke_r > 0.8:
			if Defs.seg_sphere(a, b, p.position + Vector3(0, 1.4, 0), p.smoke_r):
				return true
	# the smoke rolling off a big fire is as good as a screen
	for sm in world.fires.smokes:
		if Defs.seg_sphere(a, b, sm[0], sm[1]):
			return true
	return false


func clear_line(a: Vector3, b: Vector3, ex: Array = []) -> bool:
	if not ray(a, b, ex).is_empty():
		return false
	return not smoke_blocks(a, b)


func can_see(s: Soldier, e: Entity) -> bool:
	return can_see_from(s.scan_eye(), e, s.get_exclude())


func can_see_from(eye: Vector3, e: Entity, ex: Array) -> bool:
	var ex2 := ex + e.get_exclude()
	for pt in e.exposed_points():
		if clear_line(eye, pt, ex2):
			return true
	return false


func sees_structure(eye: Vector3, st: Entity) -> bool:
	var r := ray(eye, st.position + Vector3(0, 1.0, 0))
	if r.is_empty():
		return true
	var e := ent_of(r.collider)
	return e == st


# --- shooting ------------------------------------------------------------------------

func fire_bullet(shooter: Entity, muzzle: Vector3, aim: Vector3, tgt: Entity, w: Dictionary, accm := 1.0) -> void:
	var dist := muzzle.distance_to(aim)
	var hit := false
	if tgt:
		var p: float = float(w.acc) * accm
		p *= clampf(1.25 - dist / float(w.range), 0.1, 1.0)
		p *= tgt.hit_factor()
		if shooter is Soldier:
			p *= 1.0 - shooter.suppression * 0.0065
		if world.rules.has_upgrade(shooter.team, "optics"):
			p *= 1.15
		if tgt is Soldier:
			p *= world.terrain.hit_mul(tgt.position, muzzle)
			# a man in a trench is only really exposed to fire from along his bay
			# (enfilade); from the front the parapet takes most of it
			if tgt._gy < -0.6 and not world.trench_enfiladed(tgt.position, muzzle):
				p *= 0.45
		if tgt is Vehicle and tgt.is_air() and not w.get("aa", false):
			p *= 0.4
		if tgt is Drone:
			p = (0.08 if String(w.snd) == "hmg" else (0.045 if String(w.snd) == "mg" else 0.03)) * clampf(1.3 - dist / 40.0, 0.3, 1.0)
		hit = world.rng.randf() < p
		if hit and smoke_blocks(muzzle, aim):
			hit = false
	var dir := (aim - muzzle).normalized()
	var end := aim
	if not hit:
		var side := dir.cross(Vector3.UP).normalized()
		var mr := world.rng.randf_range(0.5, 2.0) * (0.6 + dist / 60.0)
		end = aim + side * world.rng.randf_range(-1.0, 1.0) * mr + Vector3.UP * world.rng.randf_range(-0.5, 0.9) * mr * 0.6
		end = muzzle + (end - muzzle).normalized() * minf(dist * 1.5 + 6.0, float(w.range) * 1.4)
	var r := ray(muzzle, end, shooter.get_exclude())
	var impact := 0
	var soft_tgt := tgt is Soldier or tgt is Drone
	var dmg_k := 1.0
	if not r.is_empty():
		var hp: Vector3 = r.position
		var ent := ent_of(r.collider)
		# what's in the way may not stop it: a hedge, a car door, a plaster wall
		var through := false
		var in_way := muzzle.distance_to(hp) < dist - 0.35
		if ent is Structure and (soft_tgt or tgt == null) and (in_way or not hit):
			var m := Cover.mat_of(ent)
			if world.rng.randf() < Cover.PASS[m][Cover.pen_class(w)]:
				through = true
				dmg_k = Cover.PASS_DMG[m]
				ent.take_damage(float(w.dmg) * 0.05, shooter)
				if world.settings.get("debug", false):
					world.stat("t%d_pen" % shooter.team)
				if not hit:
					_through_hits(shooter, hp, end, w, dmg_k)
		if hit and soft_tgt and in_way and not through:
			hit = false
		if through and hit:
			pass  # it carries on into the man behind it
		elif not hit or not soft_tgt:
			end = hp
			impact = Fx.HIT_DIRT
			hit = false
			if ent is Vehicle:
				impact = ent.bullet_hit(hp, dir, w, shooter)
			elif ent is Structure:
				ent.take_damage(float(w.dmg) * 0.05, shooter)
				impact = Fx.surface_of(ent, hp)
	if end.y < 0.0:
		var t := muzzle.y / maxf(0.001, muzzle.y - end.y)
		end = muzzle.lerp(end, t)
		if impact == 0:
			impact = 1
	if hit:
		if tgt is Soldier:
			var dmg := float(w.dmg) * world.rng.randf_range(0.8, 1.2) * dmg_k
			if world.rng.randf() < 0.08:
				dmg *= 2.5
			tgt.take_damage(dmg, shooter, dir, "bullet")
			impact = 2
		elif tgt is Drone:
			tgt.shot_down()
			impact = 3
	world.battle.shot(shooter, hit)
	if world.settings.get("debug", false):
		world.stat("t%d_shots" % shooter.team)
		if tgt:
			world.stat("t%d_aimed" % shooter.team)
		if hit:
			world.stat("t%d_hits" % shooter.team)
		if not r.is_empty() and tgt is Soldier and not hit:
			world.stat("t%d_blocked" % shooter.team)
	if w.has("he") and (impact != 0 or hit or end.y < 0.2):
		var hep: Vector3 = tgt.center_point() if hit and tgt and not (tgt is Drone) else end
		if w.get("airburst", false) and tgt is Soldier and world.terrain.in_trench(tgt.position) and Defs.flat(end - tgt.position).length() < 3.0:
			# programmed airburst: the round bursts right over the trench
			hep = Vector3(tgt.position.x, 1.4, tgt.position.z) + Vector3(world.rng.randf_range(-0.8, 0.8), 0, world.rng.randf_range(-0.8, 0.8))
		explode(hep, {"dmg": float(w.dmg) * 1.6, "radius": float(w.he), "fling": 4.0, "at": 0.0, "src": shooter, "team": shooter.team, "size": 0.38, "struct_mult": 1.5, "veh_mult": 0.1})
	_suppress(muzzle, end, shooter.team, float(w.supp), tgt if hit else null)
	var now := world.time
	if now > float(_reveal.get(shooter.eid, 0.0)):
		_reveal[shooter.eid] = now + 1.5
		for s in world.soldiers_near(shooter.position, 75.0):
			if s.team != shooter.team and s.team >= 0 and s.squad and s.life == Soldier.Life.ALIVE:
				s.squad.report(shooter)
	world.fx_event([Fx.SHOT, muzzle, end, impact, String(w.snd), shooter.eid])


## A round that went through soft cover can still find someone sheltering
## behind it (a burst into a hedge, through a car, a wall a machine gun is
## chewing up).
func _through_hits(shooter: Entity, hp: Vector3, end: Vector3, w: Dictionary, dmg_k: float) -> void:
	var dir := (end - hp).normalized()
	var far := hp + dir * 3.0
	for s in world.soldiers_near((hp + far) * 0.5, 2.0):
		if s.team == shooter.team or s.life != Soldier.Life.ALIVE:
			continue
		if Defs.dist_point_segment(s.center_point(), hp, far) > 0.45:
			continue
		if world.rng.randf() < 0.35:
			s.take_damage(float(w.dmg) * dmg_k * world.rng.randf_range(0.8, 1.2), shooter, dir, "bullet")
			world.stat("through_hit")
		return


func _suppress(a: Vector3, b: Vector3, team: int, amount: float, hit_tgt: Entity) -> void:
	var mid := (a + b) * 0.5
	var half := a.distance_to(b) * 0.5 + 3.0
	for s in world.soldiers_near(mid, half):
		if s.team == team or s.life != Soldier.Life.ALIVE or s == hit_tgt:
			continue
		var d := Defs.dist_point_segment(s.position + Vector3(0, 1.0, 0), a, b)
		if d < 3.0:
			s.add_suppression(amount * (1.0 - d / 3.0), a)


func melee_hit(a: Soldier, b) -> void:
	if b == null or not (b is Soldier) or b.gone or b.life != Soldier.Life.ALIVE:
		return
	if Defs.flat(b.position - a.position).length() > 2.4:
		return
	b.take_damage(world.rng.randf_range(45.0, 75.0), a, (b.position - a.position).normalized(), "melee")
	b.suppression = minf(100.0, b.suppression + 40.0)
	world.fx_event([Fx.MELEE, b.position + Vector3(0, 1.2, 0)])


func throw_grenade(s: Soldier, pos: Vector3, kind: String, fuse := 3.4) -> Projectile:
	var from := s.position + Vector3(0, 1.7, 0) + Defs.dir_of(s.rotation.y) * 0.3
	return world.spawn("projectile", {"ptype": kind, "team": s.team, "pos": from, "vel": ballistic_vel(from, pos), "thrower": s.eid, "fuse": fuse if kind == "frag" else 1.0})


## A short, flat throw from the shoulder: in through a doorway or a window,
## under the lintel, rather than lobbed high over a wall.
func throw_grenade_low(s: Soldier, pos: Vector3, fuse := 3.4) -> Projectile:
	var from := s.position + Vector3(0, 1.45, 0) + Defs.dir_of(s.rotation.y) * 0.35
	var t := clampf(Defs.flat(pos - from).length() / 11.0, 0.3, 0.75)
	var v := (pos - from) / t + Vector3(0, 0.5 * Projectile.GRAVITY * t, 0)
	return world.spawn("projectile", {"ptype": "frag", "team": s.team, "pos": from, "vel": v, "thrower": s.eid, "fuse": fuse})


func ballistic_vel(from: Vector3, to: Vector3) -> Vector3:
	var dist := Defs.flat(to - from).length()
	var t := clampf(dist / 14.0, 0.6, 1.7)
	return (to - from) / t + Vector3(0, 0.5 * Projectile.GRAVITY * t, 0)


func fire_rocket(s: Soldier, t: Entity) -> void:
	var from := s.eye_pos() + Defs.dir_of(s.rotation.y) * 0.7 + Vector3(0, 0.1, 0)
	var aim := t.center_point()
	var dist := from.distance_to(aim)
	if t is Vehicle:
		aim += t.velocity * (dist / 60.0)
	aim += Vector3(world.rng.randf_range(-1, 1), world.rng.randf_range(-0.5, 0.5), world.rng.randf_range(-1, 1)) * dist * 0.025
	var dir := (aim - from).normalized()
	world.spawn("projectile", {"ptype": "rocket", "team": s.team, "pos": from, "vel": dir * 60.0, "thrower": s.eid})
	world.fx_event([Fx.LAUNCH, from, dir, s.eid])


## Mortar round: lands on a high arc after a delay, scattered by range.
func fire_mortar(src: Soldier, from: Vector3, tgt: Vector3, kind: String) -> void:
	var d := Defs.flat(tgt - from).length()
	var scatter := 1.2 + d * 0.03
	var ang := world.rng.randf() * TAU
	var r := sqrt(world.rng.randf()) * scatter
	var tp := Vector3(tgt.x + cos(ang) * r, 0.05, tgt.z + sin(ang) * r)
	var flight := 2.4 + d / 40.0
	world.spawn("projectile", {"ptype": "mortar" if kind != "smoke" else "mortar_smoke", "team": src.team, "pos": from,
		"origin": from, "target": tp, "T": flight, "thrower": src.eid})
	world.fx_event([Fx.MORTAR, from])
	world.stat("mortar_round")


## AT post: guided missile (Coalition) or recoilless round (Rebels).
func fire_at(src: Soldier, from: Vector3, t: Entity, guided: bool) -> void:
	var aim := t.center_point()
	var dist := from.distance_to(aim)
	if guided:
		var dir := ((aim - from).normalized() + Vector3(0, 0.3, 0)).normalized()
		world.spawn("projectile", {"ptype": "atgm", "team": src.team, "pos": from, "vel": dir * 26.0, "thrower": src.eid, "tgt": t.eid, "target": aim})
		world.fx_event([Fx.LAUNCH, from, dir])
	else:
		if t is Vehicle:
			aim += t.velocity * (dist / 90.0)
		aim += Vector3(world.rng.randf_range(-1, 1), world.rng.randf_range(-0.3, 0.3), world.rng.randf_range(-1, 1)) * dist * 0.012
		var dir2 := (aim - from).normalized()
		world.spawn("projectile", {"ptype": "recoilless", "team": src.team, "pos": from, "vel": dir2 * 90.0, "thrower": src.eid})
		world.fx_event([Fx.LAUNCH, from, dir2])
	world.stat("at_launch")


func launch_drone(s: Soldier, t: Entity) -> Drone:
	var d: Drone = world.spawn("drone", {"team": s.team, "pos": s.position + Vector3(0, 1.0, 0) + Defs.dir_of(s.rotation.y) * 0.8, "operator": s.eid, "target": t.eid})
	d.operator = s
	d.target = t
	if world.rules.has_upgrade(s.team, "warheads"):
		d.warhead = 1.5
	return d


## d keys: dmg, radius, fling, at (anti-armour), src, team, size, track, dir, top,
## by (who called it in, when no src fired it: fire support, a mine)
func explode(pos: Vector3, d: Dictionary) -> void:
	var was: Array = world.battle.blame(int(d.get("by", 0)), int(d.get("team", -1))) if d.get("src") == null else []
	_explode(pos, d)
	if d.get("src") == null:
		world.battle.end_blame(was)


func _explode(pos: Vector3, d: Dictionary) -> void:
	var dmg: float = d.get("dmg", 120.0)
	var r: float = d.get("radius", 5.0)
	if d.get("top", false) and r >= 3.5:
		world.note_heavy_impact(pos)
	var fling: float = d.get("fling", 8.0)
	var src = d.get("src")
	var fr := r * 2.4
	var blast_in_trench := world.terrain.in_trench(pos)
	for s in world.soldiers_near(pos, fr):
		if s.life == Soldier.Life.HIDDEN:
			continue
		var c: Vector3 = s.center_point()
		var dist := pos.distance_to(c)
		if dist < r:
			var rb := ray(pos + Vector3(0, 0.35, 0), c)
			var blocked := not rb.is_empty()
			var bk := 0.25
			if blocked and ent_of(rb.collider) is Structure:
				bk = Cover.BLAST[Cover.mat_of(ent_of(rb.collider))]
			# dug in: only a round that lands in the trench itself really hurts
			var sheltered: bool = world.terrain.in_trench(s.position) and not (blast_in_trench and dist < r * 0.6)
			if sheltered:
				blocked = true
			var f := pow(1.0 - dist / r, 1.2)
			var dd := dmg * f * ((0.25 if sheltered else bk) if blocked else 1.0) * (0.5 if sheltered else 1.0) * world.terrain.blast_mul(s.position)
			if OS.has_environment("FL_DEBUG_BLAST") and world.terrain.in_trench(s.position):
				print("BLAST on %s dist=%.1f pos=%s blast_in_trench=%s blocked=%s sheltered=%s dd=%.0f hp=%.0f" % [s.sname, dist, str(pos.snapped(Vector3.ONE * 0.1)), str(blast_in_trench), str(blocked), str(sheltered), dd, s.hp])
			if s.posture == Soldier.Post.PRONE and s.life == Soldier.Life.ALIVE:
				dd *= 0.55
			if dd > 3.0:
				s.take_damage(dd, src, (c - pos).normalized(), "explosion")
			if not blocked and dist < r * 0.8 and fling > 0.0:
				s.fling_from(pos, fling * (1.0 - dist / (r * 0.8)) + 2.0)
		if dist < fr:
			s.flinch_from(pos, dist, fr)
	for v in world.vehicles_near(pos, r + 4.0):
		v.explosion_hit(pos, d)
	for st in world.structures_near(pos, r + 1.0):
		if st.gone:
			continue
		var sd: float = Defs.flat(st.position - pos).length() - st.radius * 0.5
		if sd < r:
			var f2 := clampf(1.0 - sd / r, 0.2, 1.0)
			var mult := 1.0
			if st.skind in ["wire", "mines"]:
				mult = 6.0
			st.hit_from = pos
			st.take_damage(dmg * f2 * mult * float(d.get("struct_mult", 1.0)), src)
	for dr in world.drones.duplicate():
		if dr.position.distance_to(pos) < r and not dr.dead:
			dr.shot_down()
	# heavy blasts throw cars and crates across the ground
	var bsize := float(d.get("size", 1.0))
	if bsize >= 1.6:
		for st in world.structures_near(pos, r + 6.0):
			if not st.gone and st.skind in ["car", "crates"]:
				st.toss_from(pos, bsize)
	# the flash and the burning fragments may set what's close alight
	world.fires.blast(pos, bsize, r)
	world.fx_event([Fx.EXPLODE, pos, float(d.get("size", 1.0))])
	world.terrain.add_crater(pos, float(d.get("size", 1.0)))


# --- cover ----------------------------------------------------------------------------

## The best place within `radius` of `anchor` for s to fight from against the
## threats: a fighting position on something solid (see Cover) - preferring
## what stops the most, where he can shoot back, close by and not taken - or
## a fold in the ground (a crater, a rubble heap, the woods).
func find_cover(s: Soldier, anchor: Vector3, radius: float, threats: Array, prone: bool) -> Dictionary:
	# Without an approach to shelter from, no candidate can pass the protection
	# test. Keep his existing quiet-sector behaviour without surveying the town.
	if threats.is_empty():
		return {}
	var cands := []
	var r2 := radius * radius
	for st in world.structures_near(anchor, radius + 4.0):
		if not st.provides_cover() or st.burn > 0.0:
			continue  # (nobody gets down behind something that's on fire)
		for i in st.anc_p.size():
			var p: Vector3 = st.anc_p[i]
			var d2 := Defs.flat(p - anchor).length_squared()
			if d2 <= r2 and not world.fires.hot_at(p):
				cands.append([d2 + Defs.flat(p - s.position).length_squared() * 0.3, st, i])
	# ground cover too: craters, rubble heaps, woods
	var tm: TerrainMap = world.terrain
	var ri := int(radius)
	var ac := tm.idx_of(anchor)
	var ax := ac % TerrainMap.N
	var az := ac / TerrainMap.N
	if not threats.is_empty():
		for z in range(maxi(0, az - ri), mini(TerrainMap.N, az + ri + 1), 2):
			for x in range(maxi(0, ax - ri), mini(TerrainMap.N, ax + ri + 1), 2):
				var i := z * TerrainMap.N + x
				if tm.cov[i] < 2 or tm.solid[i] > 0 or tm.trench[i] > 0:
					continue
				if tm.crater[i] == 0 and tm.rubble[i] == 0 and tm.woods[i] == 0:
					continue  # cells beside walls: the wall's own positions are better
				var p2 := tm.center(i)
				var d3 := Defs.flat(p2 - anchor).length_squared()
				if d3 <= r2 and world.nav.walkable(p2) and not world.fires.hot_at(p2):
					cands.append([d3 + Defs.flat(p2 - s.position).length_squared() * 0.3 + 4.0, null, p2])
	if cands.is_empty():
		return {}
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var best := {}
	var best_s := -1e9
	var w := s.cur_weapon()
	var rng_w: float = float(w.get("range", 50.0)) if not w.is_empty() else 50.0
	var unarmed := w.is_empty() or s.is_bearer()
	var evals := 0
	for c in cands:
		if evals >= 20:
			break
		var ev: Dictionary
		var st = c[1]
		if st != null:
			var ai: int = c[2]
			if not Cover.reachable(world, st.anc_p[ai]):
				continue
			evals += 1
			ev = Cover.evaluate(world, st, ai, threats, prone) if not threats.is_empty() else {}
			if ev.is_empty():
				continue
		else:
			var p2: Vector3 = c[2]
			var ti := tm.idx_of(p2)
			# a crater's lip, a heap of rubble or the trees: lie or kneel in it
			var gh := 0.45 if tm.crater[ti] > 0 else (0.75 if tm.rubble[ti] > 0 else 0.0)
			var tdir := Defs.flat(threats[0] - p2).normalized()
			ev = {"type": Soldier.Cov.LOW, "prot": 0.45 if gh == 0.0 else 0.7, "fire": true, "lean": Vector3.ZERO,
				"tdir": tdir, "pos": p2, "n": tdir if gh > 0.0 else Vector3.ZERO,
				"h": gh, "mat": Cover.SOFT if gh == 0.0 else Cover.HARD, "st": null, "ai": -1}
		var p: Vector3 = ev.pos
		var sc: float = float(ev.prot) * 10.0 + [0.0, 1.8, 3.4, 4.2][int(ev.mat)]
		match int(ev.type):
			Soldier.Cov.LOW:
				sc += 1.0 if prone else (4.0 if ev.fire else 1.5)
			Soldier.Cov.LEAN:
				sc += 3.5
			Soldier.Cov.HIDE:
				sc += 4.0 if (prone or unarmed) else 0.0
		if prone and float(ev.h) > 0.0 and Cover.stance(float(ev.h)) == Cover.PRONE:
			sc += 1.5  # crawling: a low lip is just the thing
		sc -= Defs.flat(p - anchor).length() * 0.35
		sc -= Defs.flat(p - s.position).length() * 0.12
		if st != null and st == s.cover_st and int(ev.ai) == s.cover_ai:
			sc += 2.5  # where he already is: no shuffling about
		if not prone and not threats.is_empty() and Defs.flat(threats[0] - p).length() > rng_w:
			sc -= 3.0
		if _claimed(p, s):
			sc -= 12.0
		if world.ground_y(p) < -0.1:
			sc += 6.0  # inside a dug trench: far better than lying behind anything
		if sc > best_s:
			best_s = sc
			best = ev
	if world.settings.get("debug_cover", false):
		print("COVER %s anchor=%s threats=%d cands=%d best=%s mat=%s h=%s" % [s.sname, str(anchor.round()), threats.size(), cands.size(),
			str(best.get("type", -1)), str(best.get("mat", -1)), str(best.get("h", -1))])
	if best.is_empty() or float(best.prot) <= 0.0:
		return {}
	return best


## Share of the threats (enemy eye points) a spot is hidden from, at height h.
func prot_at(p: Vector3, threats: Array, h: float) -> float:
	if threats.is_empty():
		return 0.0
	var g := world.ground_y(p)
	var n := 0
	for th in threats:
		var r := ray(p + Vector3(0, g + h, 0), th)
		if not r.is_empty() and p.distance_to(r.position) < 3.5:
			n += 1
	return float(n) / threats.size()


## Is that spot someone else's - a man standing on it, or one already on
## his way there (his squad mates are checked wherever they are)?
func _claimed(p: Vector3, s: Soldier) -> bool:
	if s.squad:
		for o in s.squad.members:
			if o != s and o.life == Soldier.Life.ALIVE and Defs.flat(o.cover_pos - p).length() < 1.0 and (o.at_cover or o.goal_kind == "cover"):
				return true
	for o in world.soldiers_near(p, 1.3):
		if o == s or o.team != s.team or o.life != Soldier.Life.ALIVE:
			continue
		if Defs.flat(o.cover_pos - p).length() < 1.0 or Defs.flat(o.position - p).length() < 0.8:
			return true
	return false
