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
var _blocked_sight := {}
var _collision: RefCounted
var _visibility: RefCounted
var _collision_dirty := {}
var _collision_bodies := {}
var _collision_rids := {}
var _rid_entities := {}
var _collision_excluded := PackedInt64Array()
var _collision_retired: Array[int] = []


func _init(w: World) -> void:
	world = w


func enable_native_collision() -> void:
	if ClassDB.class_exists("CollisionIndexCore") and not world.settings.get("gdscript_collision", false):
		_collision = ClassDB.instantiate("CollisionIndexCore")
		if ClassDB.class_exists("VisibilityCore"):
			_visibility = ClassDB.instantiate("VisibilityCore")
			for projectile: Projectile in world.smoke_projectiles:
				update_smoke(projectile)
			if world.fires:
				update_fire_smoke(world.fires.smokes)


func update_smoke(projectile: Projectile) -> void:
	if not _visibility:
		return
	if projectile.ptype != "smoke" or projectile.gone:
		_visibility.remove_projectile(projectile.eid)
		return
	var valid: bool = _visibility.set_projectile(projectile.eid, projectile.position + Vector3(0, 1.4, 0), projectile.smoke_r)
	assert(valid, "Invalid projectile smoke volume")


func update_fire_smoke(smokes: Array) -> void:
	if not _visibility:
		return
	var rows := PackedFloat64Array()
	for smoke: Array in smokes:
		var p: Vector3 = smoke[0]
		rows.append_array(PackedFloat64Array([p.x, p.y, p.z, smoke[1]]))
	var valid: bool = _visibility.set_fires(rows)
	assert(valid, "Invalid fire smoke volume")


func dirty_collision(eid: int) -> void:
	if _collision and not _collision_retired.has(eid):
		_collision_dirty[eid] = true


## A destroyed body still shields later shots in this tick, as in Godot's deferred removal.
func retire_collision(eid: int) -> void:
	_sync_collision()
	if _collision and _collision_bodies.has(eid):
		_collision_dirty.erase(eid)
		_collision_retired.append(eid)


func finish_tick() -> void:
	for eid in _collision_retired:
		remove_collision(eid)
	_collision_retired.clear()


func remove_collision(eid: int) -> void:
	_collision_dirty.erase(eid)
	if _collision:
		_collision.remove_body(eid)
	if _collision_rids.has(eid):
		_rid_entities.erase(_collision_rids[eid])
		_collision_rids.erase(eid)
	_collision_bodies.erase(eid)


func _use_godot_collision(reason: String) -> void:
	push_warning(reason + "; using Godot collision for this battle")
	_collision = null
	_collision_dirty.clear()
	_collision_bodies.clear()
	_collision_rids.clear()
	_rid_entities.clear()


func _sync_collision() -> void:
	if _collision_dirty.is_empty():
		return
	var pending := _collision_dirty
	_collision_dirty = {}
	for id: int in pending:
		var e := world.entity(id)
		if e == null or e.gone or not (e is Structure or e is Vehicle):
			remove_collision(id)
			continue
		var body: StaticBody3D = e.get("body")
		if body == null or not body.is_inside_tree() or (body.collision_layer & MASK) == 0:
			remove_collision(id)
			continue
		var rows := PackedFloat32Array()
		for owner: int in body.get_shape_owners():
			var shape = body.shape_owner_get_owner(owner)
			if not shape is CollisionShape3D or shape.disabled:
				continue
			if not shape.shape is BoxShape3D:
				_use_godot_collision("Native collision requires battlefield box geometry")
				return
			var changed := dirty_collision.bind(id)
			if not shape.shape.changed.is_connected(changed):
				shape.shape.changed.connect(changed)
			var t: Transform3D = shape.global_transform
			var h: Vector3 = shape.shape.size * 0.5
			rows.append_array(PackedFloat32Array([t.origin.x,t.origin.y,t.origin.z,t.basis.x.x,t.basis.x.y,t.basis.x.z,t.basis.y.x,t.basis.y.y,t.basis.y.z,t.basis.z.x,t.basis.z.y,t.basis.z.z,h.x,h.y,h.z,body.shape_owner_get_shape_index(owner, 0)]))
		if not _collision.replace_body(id, rows):
			_use_godot_collision("Invalid native battlefield collision geometry")
			return
		_collision_bodies[id] = body
		if _collision_rids.has(id):
			_rid_entities.erase(_collision_rids[id])
		_collision_rids[id] = body.get_rid()
		_rid_entities[body.get_rid()] = id


func space() -> PhysicsDirectSpaceState3D:
	var f := Engine.get_physics_frames()
	if f != _space_frame or _space == null:
		_space = world.get_world_3d().direct_space_state
		_space_frame = f
	return _space


var _q := PhysicsRayQueryParameters3D.new()
var _no_ex: Array[RID] = []


func ray(from: Vector3, to: Vector3, ex: Array = []) -> Dictionary:
	if _collision:
		_sync_collision()
		if _collision:
			_collision_excluded.clear()
			for rid: RID in ex:
				if _rid_entities.has(rid):
					_collision_excluded.append(int(_rid_entities[rid]))
			var hit: PackedFloat64Array = _collision.ray(from, to, _collision_excluded)
			if hit.is_empty():
				return {}
			var body: StaticBody3D = _collision_bodies[int(hit[0])]
			return {"collider": body, "collider_id": body.get_instance_id(), "rid": body.get_rid(), "shape": int(hit[1]), "position": Vector3(hit[2],hit[3],hit[4]), "normal": Vector3(hit[5],hit[6],hit[7])}
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
	if _visibility:
		return _visibility.smoke_blocks(a, b)
	for p: Projectile in world.smoke_projectiles:
		if p.smoke_r > 0.8:
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
	return can_see_from(s.scan_eye(), e, s.get_exclude(), s._path_pending or not s.is_moving())


## One numeric scan keeps sight checks and target priorities in the simulation.
func scan_targets(s: Soldier, candidates: Array) -> PackedInt64Array:
	if not _visibility or not _collision or world.settings.get("gdscript_targeting", false):
		return PackedInt64Array()
	_sync_collision()
	if not _collision:
		return PackedInt64Array()
	# Per contact: id, kind, infantry flags or armour, point count, exclusion count.
	var contacts := PackedInt64Array()
	var points := PackedVector3Array()
	var excluded := PackedInt64Array()
	var exclude := s.get_exclude()
	for i in mini(7, candidates.size()):
		var e: Entity = candidates[i][1]
		var first := excluded.size()
		for rid: RID in exclude + e.get_exclude():
			if _rid_entities.has(rid):
				excluded.append(int(_rid_entities[rid]))
		var exposed := e.exposed_points()
		points.append(e.position)
		points.append_array(PackedVector3Array(exposed))
		var kind := 0
		var flags := 0
		if e is Soldier:
			kind = 1
			flags = int(e.life == Soldier.Life.DOWNED) | (int(e.utype in ["mg_gunner", "pkm"]) << 1)
		elif e is Vehicle:
			kind = 2
			flags = int(e.vdef.get("armor", 1))
		contacts.append_array(PackedInt64Array([e.eid, kind, flags, exposed.size(), excluded.size() - first]))
	var drone_meta := PackedInt64Array()
	var drone_positions := PackedVector3Array()
	for d: Drone in world.drones:
		drone_meta.append_array(PackedInt64Array([d.eid, d.team, int(d.dead), int(d.diving)]))
		drone_positions.append(d.position)
	var w := s.cur_weapon()
	var forced: Entity = s.forced_target if is_instance_valid(s.forced_target) and not s.forced_target.gone else null
	var mounted: bool = s.task == "man" and s.task_phase == 2 and s.mounted != null and s.mounted.skind in ["mg_nest", "hmg_nest"]
	var observer := [s.position, s.scan_eye(), s.team,
		s.target.eid if is_instance_valid(s.target) else 0, forced.eid if forced else 0,
		forced.position if forced is Structure else null, s.mounted.front_dir() if mounted else null,
		float(w.get("range", 50.0)), s.rockets > 0, bool(w.get("ap", false)), s._path_pending or not s.is_moving()]
	var result: PackedInt64Array = _visibility.scan_contacts(_collision, observer, contacts, points, excluded, drone_meta, drone_positions)
	assert(not result.is_empty(), "Invalid infantry scan")
	for i in result[2]:
		world.stat("perception_blocked_reused")
	return result


func can_see_from(eye: Vector3, e: Entity, ex: Array, cache_obstruction := true) -> bool:
	var ex2 := ex + e.get_exclude()
	var pts := e.exposed_points()
	if _visibility and _collision:
		_sync_collision()
		if _collision:
			_collision_excluded.clear()
			for rid: RID in ex2:
				if _rid_entities.has(rid):
					_collision_excluded.append(int(_rid_entities[rid]))
			var result: int = _visibility.can_see(_collision, eye, e.eid, PackedVector3Array(pts), _collision_excluded, cache_obstruction)
			if result == 2:
				world.stat("perception_blocked_reused")
			assert(result >= 0, "Invalid native visibility query")
			return result == 1
	# Walking changes the exact sight line every tick; recording those misses costs more than casting.
	if not cache_obstruction:
		if _collision:
			for pt: Vector3 in pts:
				if ray(eye, pt, ex2).is_empty() and not smoke_blocks(eye, pt):
					return true
			return false
		# One target shares the origin and exclusions across all exposed points.
		_q.from = eye
		_q.collision_mask = MASK
		var excluded: Array[RID] = []
		excluded.assign(ex2)
		_q.exclude = excluded
		var sight_space := space()
		for pt: Vector3 in pts:
			_q.to = pt
			if sight_space.intersect_ray(_q).is_empty() and not smoke_blocks(eye, pt):
				return true
		return false
	var key := [eye, e.get_instance_id()]
	var previous: Array = _blocked_sight.get(key, [])
	if not previous.is_empty() and pts == previous[0] and ex2 == previous[1] and _blockers_unchanged(previous[2]):
		_blocked_sight.erase(key)
		_blocked_sight[key] = previous
		world.stat("perception_blocked_reused")
		return false
	var blockers := {}
	var cacheable := true
	for pt in pts:
		var hit := ray(eye, pt, ex2)
		if hit.is_empty():
			if not smoke_blocks(eye, pt):
				_blocked_sight.erase(key)
				return true
			cacheable = false
		elif cacheable:
			var body = hit.collider
			if not body is StaticBody3D:
				cacheable = false
				continue
			var shape = body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
			if not shape is CollisionShape3D or not shape.shape is BoxShape3D:
				cacheable = false
				continue
			if not blockers.has(shape):
				blockers[shape] = [body, shape, shape.global_transform, shape.shape, shape.shape.size, shape.shape.margin]
	# An unchanged wall crossing every ray proves obstruction without a timeout.
	# Smoke still needs fresh checks as its clouds grow and drift.
	if cacheable and not blockers.is_empty():
		if not _blocked_sight.has(key) and _blocked_sight.size() >= 4096:
			var oldest = null
			for old in _blocked_sight:
				oldest = old
				break
			_blocked_sight.erase(oldest)
		_blocked_sight[key] = [pts, ex2, blockers.values()]
	else:
		_blocked_sight.erase(key)
	return false


func _blockers_unchanged(blockers: Array) -> bool:
	for blocker: Array in blockers:
		var body = blocker[0]
		var shape = blocker[1]
		if not is_instance_valid(body) or not is_instance_valid(shape) or not shape.is_inside_tree():
			return false
		if not body.can_process() or (body.collision_layer & MASK) == 0 or shape.disabled or shape.get_parent() != body:
			return false
		if shape.global_transform != blocker[2] or shape.shape != blocker[3] or shape.shape.size != blocker[4] or shape.shape.margin != blocker[5]:
			return false
	return true


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
	# Men can use cover near their assigned place without vaulting away from the squad.
	var grouped := s.squad != null and not s.detached and not prone
	if grouped:
		radius = minf(radius, 3.0)
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
		var candidate: Vector3 = st.anc_p[c[2]] if st != null else c[2]
		if grouped and not world.terrain.group_spot(candidate, anchor, radius, st.anc_n[c[2]] if st != null else Vector3.ZERO):
			continue
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
		if st != null and st.anc_k[int(ev.ai)] == Cover.STACK:
			sc -= 2.5  # Keep the front row preferred when it has room.
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
