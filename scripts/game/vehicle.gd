class_name Vehicle
extends Entity
## Tanks, technicals and supply trucks. Tanks smash through walls, small arms
## ricochet off their armour, and a blown track leaves them stranded.

const F_TRACK := 1
const F_FIRE := 2
const F_BLOCKED := 4

var vkind := "tank"
var vdef: Dictionary = {}
var turret_yaw := 0.0
var speed := 0.0
var velocity := Vector3.ZERO
var track_broken := false
var track_fix := 0.0
var path := PackedVector3Array()
var path_i := 0
var target: Entity = null
var forced_target: Entity = null
var cannon_t := 2.0
var mg_t := 0.0
var mg_burst := 0
var scan_t := 0.0
var smash_t := 0.0
var body: StaticBody3D
var flags := 0
var hp_frac := 1.0
var last_fire_t := -9.0
var _alert_t := 0.0
# trucks
var route := PackedVector3Array()
var route_i := 0
var dest_fob: Structure = null
var returning := false
var blocked_t := 0.0
var _stuck_p := Vector3.ZERO
var _stuck_t := 0.0
var _unstick_t := 0.0
var _unstick_dir := 1.0
var assault := false  # attack-move: halt to shoot whenever there's a target
var passengers: Array = []  # soldiers riding inside
var assault_dest := Vector3.INF
var _dis_t := 0.0
# helicopters
var heli_home: Structure = null
var heli_dest: Structure = null
var heli_phase := 0
var heli_t := 0.0
var rotor: Node3D

# view
var model: Node3D
var knock_v := Vector3.ZERO  # shoved by a blast: slides it across the ground (server)
var _last_blast: Array = []  # [pos, size, time] of the last explosion that hit it
# suspension (view): pitch, roll, heave and how fast each is changing
var _sus := Vector3.ZERO
var _sus_v := Vector3.ZERO
var _vel_s := Vector3.ZERO
var _vel_prev := Vector3.ZERO
var turret: Node3D
var tail_rotor: Node3D
var blades: Node3D
var blur: MeshInstance3D
var wheels: Array = []
var _last_pos := Vector3.ZERO
var _rotor_spd := 0.0
var burner: Node3D
var dust: GPUParticles3D
var _burn_state := -1
var ring: MeshInstance3D
var _vis := true


func ekind() -> String:
	return "vehicle"


func display_name() -> String:
	return vdef.get("name", "Vehicle")


func apply_props(d: Dictionary) -> void:
	if d.has("vkind"):
		vkind = d.vkind
	if d.has("team"):
		team = d.team
	if d.has("owner"):
		owner_peer = d.owner
	if d.has("pos"):
		position = d.pos
		net_pos = d.pos
	if d.has("yaw"):
		rotation.y = d.yaw
		net_yaw = d.yaw
	if d.has("max_hp"):
		max_hp = d.max_hp


func get_props() -> Dictionary:
	return {"vkind": vkind, "team": team, "owner": owner_peer, "pos": position, "yaw": rotation.y, "max_hp": max_hp}


func on_spawned() -> void:
	vdef = Defs.VEHICLES[vkind]
	if srv:
		max_hp = float(vdef.hp)
		hp = max_hp
		body = StaticBody3D.new()
		body.collision_layer = Defs.L_VEHICLE
		body.collision_mask = 0
		body.set_meta("eid", eid)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = _hull_size()
		cs.shape = bs
		cs.position = Vector3(0, bs.size.y * 0.5, 0)
		body.add_child(cs)
		add_child(body)
	net_pos = position
	net_yaw = rotation.y
	net_init = true
	if world.has_view:
		_build_model()


func _hull_size() -> Vector3:
	match vkind:
		"tank", "old_tank":
			return Vector3(3.4, 2.2, 6.4)
		"technical":
			return Vector3(2.0, 1.8, 4.6)
		"heli":
			return Vector3(2.2, 2.0, 6.0)
		"gunship":
			return Vector3(2.0, 2.2, 6.5)
		"humvee":
			return Vector3(2.2, 2.0, 4.8)
		"aa_tech":
			return Vector3(2.0, 1.9, 4.6)
	return Vector3(2.3, 2.6, 6.0)


func is_air() -> bool:
	return vkind in ["heli", "gunship"] and position.y > 3.0


func get_exclude() -> Array:
	return [body.get_rid()] if body else []


func exposed_points() -> Array:
	return [position + Vector3(0, 1.2, 0), position + Vector3(0, 1.8, 0), position + Defs.dir_of(rotation.y) * 2.0 + Vector3(0, 1.0, 0)]


func center_point() -> Vector3:
	return position + Vector3(0, 1.1, 0)


func hit_factor() -> float:
	return 2.0


func needs_repair() -> bool:
	return track_broken or hp < max_hp - 1.0


func repair(amount: float) -> void:
	hp = minf(max_hp, hp + amount * max_hp / 40.0)
	if track_broken:
		track_fix += amount
		if track_fix >= 6.0:
			track_broken = false
			track_fix = 0.0
			world.send_msg(team, "info", "%s track repaired." % display_name(), position)


func turret_pos() -> Vector3:
	if vkind == "gunship":
		return position + Vector3(0, 0.8, 0) + Defs.dir_of(rotation.y) * 2.3
	return position + Vector3(0, 2.0 if vkind in ["technical", "aa_tech", "humvee"] else 2.2, 0)


func barrel_tip() -> Vector3:
	return turret_pos() + Defs.dir_of(rotation.y + turret_yaw) * 4.2


# --- orders --------------------------------------------------------------------------

func order_move(p: Vector3) -> void:
	assault = false
	if vkind == "truck":
		return
	if vkind == "gunship":
		forced_target = null
		gs_dest = Vector3(p.x, 0.0, p.z)
		return
	forced_target = null
	path = world.nav.find_path(position, p, true, team, 0.5)
	path_i = 0
	_stuck_t = 0.0
	_stuck_p = position


## Attack-move: drive on, but halt for a steady shot whenever there's something in range.
func order_assault(p: Vector3) -> void:
	order_move(p)
	assault = true
	assault_dest = p


func is_tracked() -> bool:
	return vkind in ["tank", "old_tank"] or vdef.get("tracked", false)


## Fill the troop compartment with a fresh squad (IFVs and APCs come with one).
func embark_new_squad() -> void:
	var key := String(vdef.get("carry", ""))
	if key == "" or not Defs.SQUADS.has(key):
		return
	var sq: Squad = world.rules.spawn_squad(key, team, owner_peer, position)
	for s in sq.members:
		passengers.append(s)
		s.riding = self
		s.hide_in("vehicle", 9999.0, null)


## Ramp down: the section piles out behind the vehicle and goes to work.
func dismount() -> void:
	if passengers.is_empty():
		return
	var back := -Defs.dir_of(rotation.y)
	var side := back.cross(Vector3.UP)
	var sq: Squad = null
	var i := 0
	for s in passengers:
		if not is_instance_valid(s) or s.gone or s.life != Soldier.Life.HIDDEN:
			continue
		s.riding = null
		s.unhide(position + back * 3.6 + side * (i - 1.5) * 1.3)
		sq = s.squad
		i += 1
	passengers.clear()
	world.stat("dismount")
	if sq:
		var fwd := Defs.dir_of(rotation.y)
		var lead := sq.get_leader()
		if lead:
			lead.say("Dismount! Go, go, go!" if team == 0 else "Out! Everybody out!", true)
		if assault and assault_dest != Vector3.INF:
			sq.order_assault(assault_dest, fwd)
		else:
			sq.order_defend(position + fwd * 8.0, fwd)


func _dismount_check(dt: float) -> void:
	if passengers.is_empty():
		return
	_dis_t -= dt
	if _dis_t > 0.0:
		return
	_dis_t = 0.5
	var arrived := path_i >= path.size() and speed < 0.6
	var close := false
	if assault:
		for e in world.units_near(position, 70.0):
			if e.team != team and e.team >= 0 and e.visible_to_team(team) and (not (e is Soldier) or e.life == Soldier.Life.ALIVE):
				close = true
				break
	if arrived or close or hp < max_hp * 0.4:
		dismount()


func order_attack(t: Entity) -> void:
	forced_target = t
	if vkind == "gunship":
		gs_dest = Vector3(t.position.x, 0.0, t.position.z)
		return
	var d := Defs.flat(t.position - position)
	if d.length() > 45.0:
		path = world.nav.find_path(position, t.position - d.normalized() * 40.0, true, team, 0.2)
		path_i = 0


func order_stop() -> void:
	if vkind == "gunship":
		gs_dest = Vector3(position.x, 0.0, position.z)
	path = PackedVector3Array()
	path_i = 0
	forced_target = null


# --- simulation ----------------------------------------------------------------------

func sim(dt: float) -> void:
	cannon_t -= dt
	mg_t -= dt
	if knock_v.length_squared() > 0.0025:
		var np := position + knock_v * dt
		if world.nav.walkable(np) and Defs.in_map(np, 4.0):
			position = np
		else:
			knock_v = Vector3.ZERO
		knock_v = knock_v.move_toward(Vector3.ZERO, 7.0 * dt)
	if vkind == "truck":
		_truck_tick(dt)
	elif vkind == "heli":
		_heli_tick(dt)
	elif vkind == "gunship":
		_gunship_tick(dt)
	else:
		scan_t -= dt
		if scan_t <= 0.0:
			scan_t = 0.5
			_scan()
		_drive(dt)
		_dismount_check(dt)
		_turret_tick(dt)
		_fire_tick()
		smash_t -= dt
		if smash_t <= 0.0:
			smash_t = 0.15
			_smash()
	flags = (F_TRACK if track_broken else 0) | (F_FIRE if world.time - last_fire_t < 0.3 else 0) | (F_BLOCKED if blocked_t > 2.0 else 0)


func _steer(tgt: Vector3, dt: float, max_speed: float) -> bool:
	max_speed *= world.terrain.speed_mul(position, true, is_tracked())
	var to := Defs.flat(tgt - position)
	var d := to.length()
	if d < 1.5:
		return true
	var want := Defs.yaw_of(to)
	var err := wrapf(want - rotation.y, -PI, PI)
	var turn: float = float(vdef.turn) * dt
	rotation.y += clampf(err, -turn, turn)
	var target_speed := 0.0 if absf(err) > 0.7 else max_speed * cos(err)
	if d < 6.0:
		target_speed = minf(target_speed, max_speed * 0.5)
	speed = move_toward(speed, target_speed, 4.0 * dt)
	var fwd := Defs.dir_of(rotation.y)
	velocity = fwd * speed
	var np := position + velocity * dt
	if vkind == "truck" or world.nav.vkind_at(np) != Nav.SOLID:
		position = np
	else:
		# scrape along whatever we hit instead of stopping dead
		var sx := position + Vector3(velocity.x * dt, 0, 0)
		var sz := position + Vector3(0, 0, velocity.z * dt)
		if absf(velocity.x) > absf(velocity.z) and world.nav.vkind_at(sx) != Nav.SOLID:
			position = sx
		elif world.nav.vkind_at(sz) != Nav.SOLID:
			position = sz
		elif world.nav.vkind_at(sx) != Nav.SOLID:
			position = sx
		speed *= 0.6
	return false


func _drive(dt: float) -> void:
	if track_broken or path_i >= path.size():
		speed = move_toward(speed, 0.0, 6.0 * dt)
		velocity = Defs.dir_of(rotation.y) * speed
		position += velocity * dt
		return
	# attack-move: halt for steady shots - but close in on men dug into a trench,
	# whom a round from range just bursts over
	var halt := 65.0 if vdef.cannon else 50.0
	if _target_ok() and target is Soldier and world.terrain.in_trench(target.position) and hp > max_hp * 0.45:
		halt = 32.0
	if assault and _target_ok() and Defs.flat(target.position - position).length() < halt:
		speed = move_toward(speed, 0.0, 6.0 * dt)
		velocity = Defs.dir_of(rotation.y) * speed
		position += velocity * dt
		_stuck_t = 0.0
		return
	# watchdog: hung up on something -> back off, turn, and plan again
	_stuck_t += dt
	if _unstick_t > 0.0:
		_unstick_t -= dt
		speed = move_toward(speed, -2.6, 8.0 * dt)
		rotation.y += _unstick_dir * float(vdef.turn) * 0.5 * dt
		velocity = Defs.dir_of(rotation.y) * speed
		var bp := position + velocity * dt
		if world.nav.vkind_at(bp) != Nav.SOLID:
			position = bp
		if _unstick_t <= 0.0:
			path = world.nav.find_path(position, path[path.size() - 1], true, team, 0.0)
			path_i = 0
			_stuck_t = 0.0
			_stuck_p = position
		return
	if _stuck_t > 3.0:
		if Defs.flat(position - _stuck_p).length() < 1.2:
			world.stat("veh_unstick")
			_unstick_t = 1.6
			_unstick_dir = 1.0 if world.rng.randf() < 0.5 else -1.0
		_stuck_t = 0.0
		_stuck_p = position
	if _steer(path[path_i], dt, float(vdef.speed)):
		path_i += 1
	# shove soldiers out of the way
	var front := position + Defs.dir_of(rotation.y) * 2.5
	for s in world.soldiers_near(front, 2.6):
		if s.life == Soldier.Life.HIDDEN or s.flinging:
			continue
		var push := Defs.flat(s.position - position)
		var side := Defs.dir_of(rotation.y).cross(Vector3.UP)
		var dir := side if push.dot(side) > 0.0 else -side
		var np: Vector3 = s.position + dir * 3.0 * dt
		if world.nav.walkable(np):
			s.position = np


func _smash() -> void:
	if speed < 0.5 and vkind != "tank" and vkind != "old_tank":
		return
	var hs := _hull_size()
	var half := Vector2(hs.x * 0.5, hs.z * 0.5 + 0.3)
	var c := Vector2(position.x, position.z)
	for st in world.structures_near(position, 5.0):
		if st.gone or not st.smashable:
			continue
		if st.team == team and st.is_player_building():
			continue
		if Defs.obb_overlap(c, half, rotation.y, Vector2(st.position.x, st.position.z), st.foot, st.yaw):
			if vkind in ["technical", "aa_tech", "humvee"] and st.skind in ["tall_wall", "house_wall", "concrete_wall"]:
				continue
			st.smash(self)
			world.stat("smash")
			if vkind == "technical":
				take_damage(15.0, null)


func _scan() -> void:
	var best: Entity = null
	var bs := -1e9
	var eye := turret_pos()
	var ex := get_exclude()
	for e in world.units_near(position, 72.0):
		if e.team == team or e.team < 0:
			continue
		if e is Soldier and e.life != Soldier.Life.ALIVE:
			continue
		var d: float = Defs.flat(e.position - position).length()
		var sc := 0.0
		if e is Vehicle and e.is_air():
			if vdef.get("aa", false):
				sc = 160.0 - d
			elif String(vdef.mg) in ["m2", "chaingun"]:
				sc = 20.0 - d
			else:
				continue
		elif e is Vehicle:
			sc = (110.0 if vdef.cannon else (70.0 if vkind == "gunship" else 40.0)) - d
		else:
			sc = 50.0 - d
			if e.rockets > 0:
				sc += 25.0
		if e == target:
			sc += 8.0
		if sc <= bs:
			continue
		if not world.combat.can_see_from(eye, e, ex):
			continue
		bs = sc
		best = e
	if best == null and vdef.cannon:
		for st in world.structures_near(position, 55.0):
			if st.team < 0 or st.team == team or not st.is_player_building() or st.skind in ["mines", "wire", "tank_trap", "trench"]:
				continue
			if not st.visible_to_team(team):
				continue
			if world.combat.sees_structure(eye, st):
				best = st
				break
	if forced_target and not forced_target.gone:
		var fd := Defs.flat(forced_target.position - position).length()
		if fd < 75.0:
			best = forced_target
	target = best
	for s in world.soldiers_near(position, 30.0):
		if s.team != team and s.team >= 0 and s.squad and s.life == Soldier.Life.ALIVE:
			s.squad.report(self)


func _target_ok() -> bool:
	if target == null or target.gone:
		return false
	if target is Soldier:
		return target.life == Soldier.Life.ALIVE
	if target is Drone:
		return not target.dead
	return true


func _turret_tick(dt: float) -> void:
	if not _target_ok():
		turret_yaw = move_toward(turret_yaw, 0.0, dt * 0.6)
		return
	var want := Defs.yaw_of(Defs.flat(target.position - position)) - rotation.y
	var rate := 1.2 if vdef.cannon else 3.0
	turret_yaw += clampf(wrapf(want - turret_yaw, -PI, PI), -rate * dt, rate * dt)


func _aim_err() -> float:
	if not _target_ok():
		return PI
	var want := Defs.yaw_of(Defs.flat(target.position - position))
	return absf(wrapf(want - (rotation.y + turret_yaw), -PI, PI))


func _fire_tick() -> void:
	if not _target_ok():
		return
	var err := _aim_err()
	var dist := Defs.flat(target.position - position).length()
	if vdef.cannon and cannon_t <= 0.0 and err < 0.05:
		var worth := target is Vehicle or target is Structure
		if target is Soldier:
			var n := 0
			for o in world.soldiers_near(target.position, 5.0):
				if o.team == target.team and o.life == Soldier.Life.ALIVE:
					n += 1
			worth = n >= 2 or target.rockets > 0 or target.mounted != null or world.rng.randf() < 0.25
		if worth:
			_fire_cannon()
			cannon_t = 5.5
			return
	var mg: String = vdef.mg
	var mg_range := 70.0 if not (vkind in ["gunship", "aa_tech"] or (target is Vehicle and target.is_air())) else 105.0
	if mg != "" and mg_t <= 0.0 and err < 0.15 and dist < mg_range and not (target is Structure and vkind != "gunship") and not (target is Vehicle and vdef.armor >= 2 and target.vdef.armor >= 2 and mg != "chaingun"):
		var w: Dictionary = Defs.WEAPONS[mg]
		if mg_burst <= 0:
			mg_burst = world.rng.randi_range(w.burst.x, w.burst.y)
		mg_burst -= 1
		var muzzle := turret_pos() + Defs.dir_of(rotation.y + turret_yaw) * (0.8 if vkind in ["technical", "aa_tech", "humvee", "gunship"] else 2.0) + Vector3(0, 0.2 if vkind in ["technical", "aa_tech", "humvee"] else (-0.3 if vkind != "gunship" else -0.1), 0)
		var aim: Vector3 = target.exposed_points()[0] if target is Soldier else target.center_point()
		world.combat.fire_bullet(self, muzzle, aim, target, w, 1.0)
		last_fire_t = world.time
		mg_t = float(w.interval) if mg_burst > 0 else world.rng.randf_range(0.6, 1.3)


func _fire_cannon() -> void:
	var from := barrel_tip()
	var aim := target.center_point()
	if target is Soldier and world.terrain.in_trench(target.position) and not world.terrain.in_trench(position) and not world.trench_enfiladed(target.position, from):
		# a flat-trajectory round can't drop into a trench: it bursts on the lip
		# in front of the man, unless we're looking straight down the bay
		var to := Defs.flat(target.position - from).normalized()
		var k := 0.3
		while k < 3.0 and world.terrain.in_trench(target.position - to * k):
			k += 0.2
		aim = Vector3(target.position.x, 0.35, target.position.z) - to * (k + 0.35)
	var dist := from.distance_to(aim)
	aim += Vector3(world.rng.randf_range(-1, 1), world.rng.randf_range(-0.4, 0.4), world.rng.randf_range(-1, 1)) * dist * 0.012
	var dir := (aim - from).normalized()
	var r := world.combat.ray(from, aim + dir * 3.0, get_exclude())
	var hit_pos: Vector3 = r.position if not r.is_empty() else aim
	if hit_pos.y < 0.1:
		hit_pos.y = 0.1
	world.fx_event([Fx.CANNON, from, hit_pos, eid])
	world.stat("cannon")
	last_fire_t = world.time
	world.combat.explode(hit_pos, {"dmg": 160.0, "radius": 5.5, "fling": 10.0, "at": 320.0, "src": self, "team": team, "size": 1.4, "track": 0.3, "dir": dir, "struct_mult": 2.5})


# --- damage --------------------------------------------------------------------------

func bullet_hit(p: Vector3, dir: Vector3, w: Dictionary, _shooter) -> int:
	var armor := int(vdef.armor)
	var ap: bool = w.get("ap", false)
	if armor >= 2:
		if ap:
			take_damage(3.0, null)
		if world.rng.randf() < 0.3:
			var n := Defs.flat(p - position).normalized()
			world.fx_event([Fx.RICOCHET, p, dir.bounce(n) if n.length() > 0.1 else -dir])
			world.stat("ricochet")
		return 3
	# armor 0: soft skin (pickups, trucks); 1: light armour, rifles barely scratch it
	var mult := 1.0
	if armor == 0:
		mult = 1.0 if ap else 0.35
	else:
		mult = 0.45 if ap else 0.05
	if w.get("aa", false) and is_air():
		mult = 1.6
	take_damage(float(w.dmg) * mult, _shooter)
	return 3


func explosion_hit(pos: Vector3, d: Dictionary) -> void:
	var dist := Defs.flat(position - pos).length()
	var bsize := float(d.get("size", 1.0))
	_last_blast = [pos, bsize, world.time]
	# a big blast close by shoves it bodily - a pickup a lot, a tank hardly at all
	if not is_air() and bsize >= 1.2:
		var pw := bsize * clampf(1.0 - dist / (4.0 + bsize * 3.0), 0.0, 1.0)
		if pw > 0.0:
			var away := Defs.flat(position - pos)
			away = away.normalized() if away.length() > 0.1 else Defs.dir_of(world.rng.randf() * TAU)
			knock_v += away * pw * float(_toss_class()[0])
	var at: float = d.get("at", 0.0)
	var armor := int(vdef.armor)
	var dmg := 0.0
	if at > 0.0 and dist < 4.5:
		var dir: Vector3 = d.get("dir", Defs.flat(position - pos).normalized())
		var fwd := Defs.dir_of(rotation.y)
		var facing := -Defs.flat(dir).normalized().dot(fwd)
		var mult := 1.0
		var top: bool = d.get("top", false)
		world.stat("at_hit")
		if armor >= 2 and not top:
			if facing > 0.7:
				mult = 0.6
				if world.rng.randf() < 0.25:
					world.stat("at_bounce")
					world.fx_event([Fx.RICOCHET, pos, Vector3.UP])
					world.send_msg(team, "info", "Round bounced off the %s's armour!" % display_name().to_lower())
					return
			elif facing < -0.6:
				mult = 1.35
		elif armor < 2:
			mult = 1.5
		dmg = at * mult
		var side_hit := absf(facing) < 0.6
		if vkind != "truck" and not track_broken and world.rng.randf() < float(d.get("track", 0.3)) * (1.5 if side_hit else 1.0):
			track_broken = true
			world.stat("track_broken")
			world.fx_event([Fx.DEBRIS, position + Vector3(0, 0.5, 0), Color(0.1, 0.1, 0.1), 8])
			world.send_msg(team, "alert", "Our %s %s at %s! It's stuck until engineers repair it." % [display_name().to_lower(), "threw a track" if is_tracked() else "lost a wheel", Defs.grid_ref(position)], position)
	else:
		var r: float = float(d.get("radius", 5.0)) + 2.0
		dmg = float(d.get("dmg", 100.0)) * maxf(0.0, 1.0 - dist / r) * (0.12 if armor >= 2 else 0.8) * float(d.get("veh_mult", 1.0))
	if dmg > 0.0:
		take_damage(dmg, d.get("src"))


func take_damage(amount: float, _src) -> void:
	if gone or not srv or hp <= 0.0:
		return
	if OS.has_environment("FL_DEBUG_DMG"):
		print("DMG %s hp=%.0f -%.1f from %s t=%.1f" % [vkind, hp, amount, _src.display_name() if _src else "?", world.time])
	hp -= amount
	if world.time > _alert_t and vkind != "truck" and amount > 50.0:
		_alert_t = world.time + 20.0
		world.send_msg(team, "alert", "%s under fire at %s!" % [display_name(), Defs.grid_ref(position)], position)
	if hp <= 0.0:
		_destroyed()


func _destroyed() -> void:
	world.stat("vehicle_destroyed")
	# whoever was inside scrambles out of the burning wreck - not all of them
	for s in passengers:
		if is_instance_valid(s) and not s.gone and s.life == Soldier.Life.HIDDEN:
			s.riding = null
			s.unhide(position + Vector3(world.rng.randf_range(-2.5, 2.5), 0, world.rng.randf_range(-2.5, 2.5)))
			s.take_damage(world.rng.randf_range(30.0, 150.0), null, Vector3.UP, "explosion")
	passengers.clear()
	world.fx_event([Fx.EXPLODE, position + Vector3(0, 1.0, 0), 2.0])
	world.fx_event([Fx.DEBRIS, position + Vector3(0, 1.5, 0), Color(0.15, 0.15, 0.14), 16])
	for s in world.soldiers_near(position, 7.0):
		s.flinch_from(position, Defs.flat(s.position - position).length(), 7.0)
	if vkind == "truck":
		world.rules.truck_lost(self)
	else:
		world.send_msg(team, "alert", "%s destroyed at %s." % [display_name(), Defs.grid_ref(position)], position)
	var wreck_kind := "rubble" if vkind in ["heli", "gunship"] else "wreck"
	if vkind in ["heli", "gunship"]:
		world.send_msg(team, "alert", "%s shot down at %s!" % [display_name(), Defs.grid_ref(position)], position)
		world.send_msg(1 - team, "info", "Enemy %s shot down!" % display_name().to_lower(), position)
	var p := Vector3(position.x, 0.0, position.z)
	var y := rotation.y
	var props := {"skind": wreck_kind, "pos": p, "yaw": y, "variant": {"tank": 6, "old_tank": 7, "heli": 9, "gunship": 9}.get(vkind, 8)}
	if wreck_kind == "wreck":
		var hs := _hull_size()
		var plan := _toss_plan(p, y)
		props["vk"] = vkind
		props["size"] = Vector3(hs.x, maxf(hs.y, 1.2), hs.z)
		props["pos"] = plan[0]
		props["yaw"] = plan[1]
		props["tilt"] = plan[2]
		if (plan[3] as Vector3).length() > 0.3:
			props["toss"] = [p, y, plan[3], plan[4]]
	var w := world
	world.despawn(self)
	var wst = w.spawn("structure", props)
	if props.has("toss"):
		w.get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(wst) and not wst.gone:
				wst.toss = null
				w.push_props(wst, {"toss": null}))


## How a blast moves this kind of vehicle: [shove (m/s per unit of blast),
## launch speed range, throw speed range, chance of landing on its side or roof].
func _toss_class() -> Array:
	match vkind:
		"tank", "old_tank":
			return [0.3, Vector2(0.8, 2.2), Vector2(0.2, 0.8), 0.0]
		"ifv", "btr", "apc":
			return [0.9, Vector2(1.5, 4.5), Vector2(0.5, 2.5), 0.15]
	return [2.2, Vector2(3.0, 9.0), Vector2(2.0, 6.0), 0.45]


## Where the wreck ends up and how it gets there: [pos, yaw, tilt (pitch, roll),
## launch velocity, spin]. Killed by a blast it's thrown away from it - a pickup
## can land on its side or its roof; killed otherwise it just stops.
func _toss_plan(p: Vector3, y: float) -> Array:
	var rng := world.rng
	if _last_blast.is_empty() or world.time - float(_last_blast[2]) > 0.6:
		return [p, y, Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.04, 0.04)), Vector3.ZERO, Vector3.ZERO]
	var cls := _toss_class()
	var bp: Vector3 = _last_blast[0]
	var bsize: float = _last_blast[1]
	var away := Defs.flat(p - bp)
	var dist := away.length()
	away = away.normalized() if dist > 0.1 else Defs.dir_of(rng.randf() * TAU)
	var pw := clampf(bsize * (1.0 - dist / (5.0 + bsize * 3.0)) / 2.6, 0.12, 1.0)
	var up: float = lerpf((cls[1] as Vector2).x, (cls[1] as Vector2).y, pw)
	var out: float = lerpf((cls[2] as Vector2).x, (cls[2] as Vector2).y, pw)
	var t_air := 2.0 * up / 19.6
	var dest := p + away * out * t_air
	if not Defs.in_map(dest, 4.0) or not world.nav.walkable(dest):
		dest = p
	var pitch := rng.randf_range(-0.06, 0.06)
	var roll := rng.randf_range(-0.07, 0.07)
	var r := rng.randf()
	var flip := float(cls[3]) * pw
	if r < flip:
		roll = PI
	elif r < flip * 2.0:
		roll = PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)
	var dyaw := rng.randf_range(-1.0, 1.0) * pw
	var axis := away.cross(Vector3.UP).normalized()
	var spin := -axis * (absf(roll) + 0.6) / maxf(t_air, 0.35) + Vector3.UP * dyaw / maxf(t_air, 0.35)
	return [dest, y + dyaw, Vector2(pitch, roll), away * out + Vector3.UP * up, spin]


## A blast close by rocks the hull on its suspension.
func blast_jolt(p: Vector3, bsize: float) -> void:
	var away := Defs.flat(position - p)
	var dist := away.length()
	var pw := bsize * clampf(1.0 - dist / (5.0 + bsize * 5.0), 0.0, 1.0) * (0.45 if vkind in ["tank", "old_tank"] else 1.0)
	if pw <= 0.0:
		return
	away = away.normalized() if dist > 0.1 else Vector3.FORWARD
	var fwd := Defs.dir_of(rotation.y)
	var side := fwd.cross(Vector3.UP)
	_sus_v += Vector3(-away.dot(fwd), -away.dot(side), 0.6) * pw * 1.6


## The main gun's kick rocks the hull back from the shot.
func recoil(dir: Vector3) -> void:
	var fwd := Defs.dir_of(rotation.y)
	var side := fwd.cross(Vector3.UP)
	var k := 0.9 if vkind in ["tank", "old_tank"] else 0.5
	_sus_v += Vector3(dir.dot(fwd), dir.dot(side), 0.0) * k


## Hull on springs: it squats when it pulls away, dips its nose when it stops,
## leans out of turns, pitches over trenches and craters and rocks back to level.
func _suspension(dt: float) -> void:
	if dt <= 0.0:
		return
	var fwd := Defs.dir_of(rotation.y)
	var side := fwd.cross(Vector3.UP)
	var vel := Defs.flat(position - _last_pos) / dt
	if vel.length() > 30.0:
		vel = Vector3.ZERO  # a snap correction, not driving
	_vel_s = _vel_s.lerp(vel, 1.0 - exp(-dt * 6.0))
	var acc := (_vel_s - _vel_prev) / dt
	_vel_prev = _vel_s
	var heavy := vkind in ["tank", "old_tank", "ifv"]
	var kp := 0.011 if heavy else 0.02
	var tgt := Vector3(clampf(acc.dot(fwd) * kp, -0.08, 0.08), clampf(acc.dot(side) * kp * 0.9, -0.07, 0.07), 0.0)
	var hs := _hull_size()
	var hf := _ground_h(position + fwd * hs.z * 0.38)
	var hr := _ground_h(position - fwd * hs.z * 0.38)
	tgt.x += atan2(hf - hr, hs.z * 0.76)
	tgt.z += (hf + hr) * 0.5
	var spring := 55.0 if heavy else 80.0
	var damp := 8.0 if heavy else 6.5
	_sus_v += ((tgt - _sus) * spring - _sus_v * damp) * dt
	_sus += _sus_v * dt
	_sus = Vector3(clampf(_sus.x, -0.35, 0.35), clampf(_sus.y, -0.35, 0.35), clampf(_sus.z, -0.6, 0.5))
	var rumble := 0.0
	if _vel_s.length() > 1.0:
		var tt := Time.get_ticks_msec() / 1000.0
		rumble = (sin(tt * 31.0 + eid) * 0.5 + sin(tt * 47.0) * 0.5) * (0.004 if heavy else 0.006) * minf(_vel_s.length() / 6.0, 1.0)
	var sus := Transform3D(Basis.from_euler(Vector3(_sus.x + rumble, 0.0, _sus.y + rumble * 0.6)), Vector3(0, _sus.z, 0))
	model.transform = (ip_offset() if srv else Transform3D.IDENTITY) * sus


## How far the ground drops under a point: into a trench, or a crater.
func _ground_h(p: Vector3) -> float:
	if world.in_trench(p):
		return -0.3 if is_tracked() else -0.55
	return world.terrain.deform_at(p) * 0.85 if world.terrain else 0.0


# --- attack helicopter ------------------------------------------------------------------

const GS_ALT := 14.0
var gs_dest := Vector3.INF
var gs_orbit := 0.0
var rocket_t := 6.0


## Flies straight to its orders, then circles whatever it is fighting at
## 40-55 m, nose on the target: chain gun bursts and rocket salvos.
func _gunship_tick(dt: float) -> void:
	scan_t -= dt
	rocket_t -= dt
	if scan_t <= 0.0:
		scan_t = 0.4
		_scan()
	var want := Vector3(position.x, GS_ALT, position.z)
	var has_t := _target_ok()
	if has_t:
		var tp := target.position
		var to := Defs.flat(position - tp)
		var ang := atan2(to.z, to.x) + dt * 0.22
		var rad := clampf(to.length(), 60.0, 75.0)
		want = tp + Vector3(cos(ang), 0.0, sin(ang)) * rad
		if gs_dest != Vector3.INF and Defs.flat(tp - gs_dest).length() > 110.0:
			want = gs_dest
	elif gs_dest != Vector3.INF:
		want = gs_dest
	want.y = GS_ALT if hp > max_hp * 0.25 else GS_ALT * 0.7
	var flat := Defs.flat(want - position)
	var spd := float(vdef.speed)
	var vd := flat.normalized() * minf(spd, flat.length() * 0.8)
	velocity = velocity.move_toward(vd, 8.0 * dt)
	position += velocity * dt
	position.y = move_toward(position.y, want.y, 5.0 * dt)
	var face := (target.position - position) if has_t else velocity
	if Defs.flat(face).length() > 0.5:
		rotation.y = lerp_angle(rotation.y, Defs.yaw_of(Defs.flat(face)), minf(1.0, 2.2 * dt))
	_turret_tick(dt)
	_fire_tick()
	if has_t and rocket_t <= 0.0 and _aim_err() < 0.35:
		var dist := Defs.flat(target.position - position).length()
		var worth := target is Vehicle or target is Structure
		if target is Soldier:
			var n := 0
			for o in world.soldiers_near(target.position, 6.0):
				if o.team == target.team and o.life == Soldier.Life.ALIVE:
					n += 1
			worth = n >= 3
		if worth and dist < 100.0:
			rocket_t = 9.0
			_rocket_salvo()


func _rocket_salvo() -> void:
	var fwd := Defs.dir_of(rotation.y)
	var side := fwd.cross(Vector3.UP)
	for i in 4:
		var from := position + Vector3(0, 1.2, 0) + side * (1.0 if i % 2 == 0 else -1.0) * 1.1 + fwd * 1.0
		var aim: Vector3 = target.center_point() + Vector3(world.rng.randf_range(-2.5, 2.5), 0, world.rng.randf_range(-2.5, 2.5))
		var v := (aim - from).normalized() * 75.0
		world.spawn("projectile", {"ptype": "rocket", "team": team, "pos": from, "vel": v, "thrower": eid})
		world.fx_event([Fx.LAUNCH, from, v.normalized()])
	last_fire_t = world.time


# --- helicopters ------------------------------------------------------------------------

const HELI_ALT := 15.0


func _heli_tick(dt: float) -> void:
	var home := heli_home if heli_home and not heli_home.gone and heli_home.team == team else null
	match heli_phase:
		0:  # waiting on the pad, then pick the FOB that needs supply most
			heli_t -= dt
			if heli_t > 0.0:
				return
			heli_dest = null
			var low := 1e9
			for f in world.rules.fobs(team):
				var need: float = f.supply + Defs.flat(f.position - position).length() * 0.5
				if need < low:
					low = need
					heli_dest = f
			if heli_dest == null:
				heli_t = 5.0
				return
			heli_phase = 1
		1, 4:  # climb
			position.y = minf(HELI_ALT, position.y + 6.0 * dt)
			if position.y >= HELI_ALT - 0.1:
				heli_phase += 1
		2, 5:  # cruise
			var goal: Vector3
			if heli_phase == 2:
				if heli_dest == null or heli_dest.gone or heli_dest.team != team:
					heli_phase = 5
					return
				goal = heli_dest.position + Vector3(9.0, 0, 0)
			else:
				goal = home.position if home else world.rules.depots[team].position + Vector3(0, 0, -12)
			var to := Defs.flat(goal - position)
			var want := Defs.yaw_of(to)
			rotation.y += clampf(wrapf(want - rotation.y, -PI, PI), -float(vdef.turn) * dt, float(vdef.turn) * dt)
			speed = move_toward(speed, float(vdef.speed) if to.length() > 25.0 else maxf(3.0, to.length() * 0.6), 6.0 * dt)
			velocity = Defs.flat(to).normalized() * speed
			position += velocity * dt
			if to.length() < 1.5:
				speed = 0.0
				velocity = Vector3.ZERO
				heli_phase += 1
		3, 6:  # land
			position.y = maxf(0.15, position.y - 5.0 * dt)
			if position.y <= 0.16:
				if heli_phase == 3:
					heli_t = 3.0
					heli_phase = 7
				else:
					heli_phase = 0
					heli_t = 12.0
		7:  # unloading
			heli_t -= dt
			if heli_t <= 0.0:
				if heli_dest and not heli_dest.gone and heli_dest.team == team:
					heli_dest.supply += 80
					heli_dest.net_dirty = true
					world.fx_event([Fx.DELIVER, heli_dest.position + Vector3(0, 4, 0), 80, team])
					world.stat("heli_delivered")
				heli_phase = 4


# --- trucks ---------------------------------------------------------------------------

func _truck_tick(dt: float) -> void:
	if route_i >= route.size():
		if not returning:
			world.rules.truck_arrived(self)
			returning = true
			route.reverse()
			route_i = 1
			speed = 0.0
			return
		world.rules.truck_home(self)
		return
	var tgt := route[route_i]
	if _road_blocked():
		blocked_t += dt
		speed = 0.0
		velocity = Vector3.ZERO
		if blocked_t > 5.0:
			world.rules.truck_blocked(self)
		return
	blocked_t = 0.0
	if Defs.flat(tgt - position).length() < 2.0:
		route_i += 1
		return
	_steer(tgt, dt, float(vdef.speed))


func _road_blocked() -> bool:
	var ahead := position + Defs.dir_of(rotation.y) * 4.0
	for st in world.structures_near(ahead, 3.0):
		if st.team < 0 or st.gone:
			continue
		if st.skind in ["tank_trap", "concrete_wall", "barracks", "factory", "research", "medic_tent"] and Defs.flat(st.position - ahead).length() < st.radius + 1.5:
			return true
	for v in world.vehicles_near(ahead, 3.0):
		if v != self and v.team != team:
			return true
	return false


# --- replication -------------------------------------------------------------------------

func write_state(b: StreamPeerBuffer) -> void:
	put_v3(b, position)
	put_ang(b, rotation.y)
	put_ang(b, turret_yaw)
	b.put_u8(int(clampf(hp / maxf(1.0, max_hp), 0.0, 1.0) * 255.0))
	b.put_u8(flags)
	b.put_u8(vis_mask)
	b.put_8(team)


func read_state(b: StreamPeerBuffer) -> void:
	net_pos = get_v3(b)
	net_yaw = get_ang(b)
	turret_yaw = lerp_angle(turret_yaw, get_ang(b), 0.5)
	hp_frac = b.get_u8() / 255.0
	flags = b.get_u8()
	vis_mask = b.get_u8()
	team = b.get_8()


func health_frac() -> float:
	return clampf(hp / maxf(1.0, max_hp), 0.0, 1.0) if srv else hp_frac


# --- view --------------------------------------------------------------------------------

func _process(dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(dt)
	if world:
		world.vp("vehicles", _t0)


func _view_process(dt: float) -> void:
	if not world.has_view or model == null:
		return
	if not srv:
		net_smooth(dt)
	var v := seen_by_local()
	if v != _vis:
		visible = v
		_vis = v
	if turret:
		turret.rotation.y = turret_yaw
	if rotor:
		var want := 30.0 if position.y > 0.3 or (flags & F_FIRE) != 0 else 9.0
		_rotor_spd = move_toward(_rotor_spd, want, dt * 12.0)
		rotor.rotation.y += dt * _rotor_spd
		if tail_rotor:
			tail_rotor.rotation.x += dt * _rotor_spd * 2.6
		if blur:
			var fast := _rotor_spd > 18.0
			blur.visible = fast
			blades.visible = not fast
	if rotor and model and dt > 0.0:
		var mv2 := position - _last_pos
		var fs := mv2.dot(Defs.dir_of(rotation.y)) / dt
		var ss := mv2.dot(Defs.dir_of(rotation.y).cross(Vector3.UP)) / dt
		model.rotation.x = lerpf(model.rotation.x, clampf(-fs * 0.012, -0.3, 0.3), 1.0 - exp(-dt * 3.0))
		model.rotation.z = lerpf(model.rotation.z, clampf(ss * 0.012, -0.3, 0.3), 1.0 - exp(-dt * 3.0))
	if dust and dt > 0.0:
		var spd2 := Defs.flat(position - _last_pos).length() / dt
		var want_dust := spd2 > 2.0
		if want_dust != dust.emitting:
			dust.emitting = want_dust
	if not rotor and model:
		_suspension(dt)
	if not wheels.is_empty():
		var mv := position - _last_pos
		var fwd := Defs.dir_of(rotation.y)
		var spd := mv.dot(fwd)
		if absf(spd) < 2.0:
			for w in wheels:
				w.rotation.x -= spd / 0.42
	_last_pos = position
	if burner:
		var hf := health_frac()
		var st := 0
		if hf < 0.2:
			st = 3
		elif hf < 0.4:
			st = 2
		elif (flags & F_TRACK) != 0 or hf < 0.6:
			st = 1
		if st != _burn_state:
			_burn_state = st
			world.fx.vfx.set_burning(burner, [0.0, 0.0, 0.0, 0.8][st], [0.0, 0.25, 0.6, 1.0][st])
	if ring:
		ring.visible = selected
		if selected and position.y > 0.5:
			ring.global_position = Vector3(position.x, 0.06, position.z)


var _vm: VehicleModels = null


## Where a shot leaves this vehicle's model right now (view): the tip of the
## machine gun, or of the main gun. INF when there's no model to ask.
func muzzle_world(main_gun := false) -> Vector3:
	if _vm == null or model == null or not model.is_visible_in_tree():
		return Vector3.INF
	var tip: Node3D = _vm.gun_tip if main_gun else _vm.mg_tip
	return tip.global_position if tip else Vector3.INF


func _build_model() -> void:
	var tc: Color = Defs.TEAM_COLORS[team] if team >= 0 else Color.WHITE
	var k := VehicleModels.build(vkind, team, eid)
	model = k.root
	add_child(model)
	turret = k.turret
	_vm = k
	rotor = k.rotor
	tail_rotor = k.tail_rotor
	blades = k.blades
	blur = k.blur
	wheels = k.wheels
	if rotor:
		add_child(Sfx.make_loop_player("rotor", 18.0, 0.0 if vkind == "gunship" else -3.0))
	elif world.fx and world.fx.vfx:
		dust = world.fx.vfx.make_dust(1.3 if vkind in ["tank", "old_tank"] else 1.0)
		dust.position = Vector3(0, 0.2, _hull_size().z * 0.5)
		add_child(dust)
	if world.fx and world.fx.vfx:
		burner = world.fx.vfx.make_burner(1.0 if vkind in ["tank", "old_tank"] else 0.7)
		burner.position = Vector3(0, 1.6, 1.2) if vkind != "heli" else Vector3(0, 2.3, 0.6)
		add_child(burner)
	var hs := _hull_size()
	ring = Res.mi(self, Res.plane(maxf(hs.x, hs.z) * 1.22), Res.ring_mat(tc), Vector3(0, 0.06, 0), Vector3.ZERO, false)
	ring.visible = false
