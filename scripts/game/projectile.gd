class_name Projectile
extends Entity
## Frag grenades (bounce, can be picked up and thrown back), smoke grenades
## (cloud blocks line of sight), rockets, mortar shells (high arc, whistle on
## the way down), guided anti-tank missiles and recoilless rounds - and the
## air support: bombing jets, A-10 gun runs, the AC-130 and its shells.

const GRAVITY := 18.0

var ptype := "frag":
	set(value):
		ptype = value
		if world and world.entities.get(eid) == self:
			world.refresh_smoke_projectile(self)
var vel := Vector3.ZERO
var fuse := 3.4
var thrower_id := 0
var by := 0  # (server) who called it in, if it's fire support (the kills are theirs)
var held_by: Soldier = null
var smothered_by: Soldier = null  # a man lying on it (see SoldierBrain)
var handler: Soldier = null  # the one man dealing with it (throwing it back, kicking it, lying on it)
var flying := true
var thrown_back := 0
var smoke_r := 0.0
var smoke_t := 0.0
var life_t := 0.0
var origin := Vector3.ZERO
var target := Vector3.ZERO
var shell_t := 3.0
var tgt_id := 0
var _whistled := false
# aircraft
var _fire_el := -1.0
var _hits: Array = []  # A-10: [arrive_time, pos]
var _next := {}  # AC-130: gun -> next shot time
var _brrt_at := -1.0
var _gun_smoke: GeometryInstance3D  # (GPU or CPU particles: see Vfx.part)
var _drone: AudioStreamPlayer
var _vm: VehicleModels
var mk := ""  # support aircraft: which model flies it
var _bombs0 := -1.0  # a bomb run: how many it started with
var guns := ""  # an orbiting gunship's weapons (GUNSETS)
var sight := 0.0  # a recon flight: how far either side of its track its camera sees (0: an ordinary sortie)
var stay := 0.0  # a recon pass: how far on it flies; an orbit: how long it stays on station (0: the default)
var _mark_t := 0.0

var model: Node3D
var smoke_fx: Node3D
var trail: GeometryInstance3D
var _vis := true
var _flight: RefCounted
var _shell_flight := false


func ekind() -> String:
	return "projectile"


func apply_props(d: Dictionary) -> void:
	if d.has("ptype"):
		ptype = d.ptype
	if d.has("team"):
		team = d.team
	if d.has("pos"):
		position = d.pos
		net_pos = d.pos
	if d.has("vel"):
		vel = d.vel
	if d.has("thrower"):
		thrower_id = d.thrower
	if d.has("by"):
		by = d.by
	if d.has("fuse"):
		fuse = d.fuse
	if d.has("origin"):
		origin = d.origin
	if d.has("target"):
		target = d.target
	if d.has("T"):
		shell_t = d.T
	if d.has("tgt"):
		tgt_id = d.tgt
	if d.has("mk"):
		mk = d.mk
	if d.has("guns"):
		guns = d.guns
	if d.has("sight"):
		sight = d.sight
	if d.has("stay"):
		stay = d.stay


func get_props() -> Dictionary:
	return {"ptype": ptype, "team": team, "pos": position, "vel": vel, "thrower": thrower_id, "fuse": fuse,
		"origin": origin, "target": target, "T": shell_t, "tgt": tgt_id, "mk": mk, "guns": guns, "sight": sight, "stay": stay}


func on_spawned() -> void:
	if srv and ClassDB.class_exists("ProjectileFlightCore") and ptype in ["frag", "smoke", "rocket", "recoilless", "mortar", "mortar_smoke", "grad", "arty", "ac105", "ac40", "ac25", "bomb"]:
		_flight = ClassDB.instantiate("ProjectileFlightCore")
	if ptype in ["grad", "arty", "ac105", "ac40", "ac25"]:
		position = origin
	_reset_flight()
	net_pos = position
	net_init = true
	if srv and ptype in ["rocket", "atgm", "recoilless"]:
		_warn_target()
	if world.has_view:
		_build_model()
		if ptype in ["rocket", "atgm", "recoilless", "sam"]:
			Sfx.play("launch", position, -2.0)


func sim(dt: float) -> void:
	if _shell_flight:
		var next: Vector4 = _flight.advance_shell(dt)
		assert(next.w >= 0.0, "Invalid native shell state")
		position = Vector3(next.x, next.y, next.z)
		life_t += dt
		if next.w == 1.0:
			_shell_impact()
		return
	if _flight and _native_flight(dt):
		return
	life_t += dt
	match ptype:
		"frag", "smoke":
			_ballistic(dt)
		"rocket", "recoilless":
			_rocket(dt)
		"atgm":
			_atgm(dt)
		"sam":
			_sam(dt)
		"mortar", "mortar_smoke", "grad", "arty", "ac105", "ac40", "ac25":
			_shell()
		"jet":
			_jet(dt)
		"a10":
			_a10(dt)
		"ac130":
			_ac130(dt)
		"bomb":
			_bomb(dt)


func _reset_flight() -> void:
	if not _flight:
		return
	_shell_flight = is_shell()
	var state := PackedFloat64Array([position.x, position.y, position.z, vel.x, vel.y, vel.z,
		origin.x, origin.y, origin.z, target.x, target.y, target.z, fuse, 1.0 if flying else 0.0,
		life_t, smoke_t, smoke_r, shell_t])
	var valid: bool = _flight.reset(ptype, state)
	assert(valid, "Invalid projectile flight state")


## Holders and impact effects stay in the adapter until their entity systems migrate.
func _native_flight(dt: float) -> bool:
	var holder := 0
	var held_position := Vector3.ZERO
	var collision := PackedVector3Array()
	if ptype in ["frag", "smoke"] and held_by != null:
		if not is_instance_valid(held_by) or held_by.gone or held_by.life != Soldier.Life.ALIVE:
			holder = 2
			held_by = null
		else:
			holder = 1
			held_position = held_by.position + Vector3(0, 1.3, 0) + Defs.dir_of(held_by.rotation.y) * 0.3
	var result := PackedFloat64Array()
	var combat := world.combat
	combat._sync_collision()
	if combat._collision:
		var excluded := PackedInt64Array()
		if ptype in ["rocket", "recoilless"]:
			var source := world.entity(thrower_id)
			if source:
				for rid: RID in source.get_exclude():
					if combat._rid_entities.has(rid):
						excluded.append(int(combat._rid_entities[rid]))
		result = _flight.advance_in_world(dt, holder, held_position, combat._collision, excluded)
	elif (holder == 0 and ptype in ["frag", "smoke"] and flying) or ptype in ["rocket", "recoilless"]:
		var sweep_velocity := vel
		var exclude: Array = []
		if ptype in ["rocket", "recoilless"]:
			sweep_velocity.y -= 1.5 * dt
			var source := world.entity(thrower_id)
			if source:
				exclude = source.get_exclude()
		var hit := world.combat.ray(position, position + sweep_velocity * dt, exclude)
		if not hit.is_empty():
			collision = PackedVector3Array([hit.position, hit.normal])
	if not combat._collision:
		result = _flight.advance(dt, holder, held_position, collision)
	if result.size() != 15:
		push_error("Invalid projectile state passed to Rust flight simulation")
		return false
	position = Vector3(result[0], result[1], result[2])
	vel = Vector3(result[3], result[4], result[5])
	fuse = result[6]
	flying = result[7] != 0.0
	life_t = result[8]
	smoke_t = result[9]
	smoke_r = result[10]
	if result[11] == 2.0:
		world.despawn(self)
	elif result[11] == 1.0:
		var impact := Vector3(result[12], result[13], result[14])
		if is_shell():
			_shell_impact()
		elif ptype == "frag":
			_frag_impact()
		elif ptype == "bomb":
			_bomb_impact(impact)
		else:
			_rocket_impact(impact)
	return true


## Ground-attack jet: flies straight over the target and releases a stick of
## high-drag bombs timed so they land across it.
func _jet(dt: float) -> void:
	position += vel * dt
	var dirn := Defs.flat(vel).normalized()
	var along := Defs.flat(position - target).dot(dirn)
	if _bombs0 < 0.0:
		_bombs0 = fuse
	if fuse > 0.0:
		# a stick 10 m apart, centred on the target
		var i := _bombs0 - fuse
		if along > -BOMB_THROW - 5.0 * (_bombs0 - 1.0) + i * 10.0:
			fuse -= 1.0
			world.spawn("projectile", {"ptype": "bomb", "team": team, "pos": position + Vector3(0, -1.4, 0), "vel": vel * 0.95, "thrower": thrower_id, "by": by})
	if sight > 0.0:
		_photograph(dt)
	if along > (stay if stay > 0.0 else 340.0):
		world.despawn(self)


const BOMB_DRAG := 1.25
## Where a bomb released at the jet's speed and height ends up (metres ahead).
const BOMB_THROW := 70.0


func _bomb(dt: float) -> void:
	vel = _bomb_step(vel, dt)
	var np := position + vel * dt
	if np.y <= 0.3:
		_bomb_impact(Vector3(np.x, 0.3, np.z))
		return
	position = np


func _bomb_impact(at: Vector3) -> void:
	var src: Entity = world.entity(thrower_id) if thrower_id != 0 else null
	world.combat.explode(at, {"dmg": 220.0, "radius": 10.0, "fling": 15.0, "at": 300.0, "top": true, "src": src, "team": team, "by": by, "size": 2.6, "track": 0.6, "struct_mult": 3.0})
	world.despawn(self)


static func _bomb_step(v: Vector3, dt: float) -> Vector3:
	v.y -= 9.8 * dt
	var k := exp(-BOMB_DRAG * dt)
	v.x *= k
	v.z *= k
	return v


func _ballistic(dt: float) -> void:
	if held_by:
		if held_by.gone or held_by.life != Soldier.Life.ALIVE:
			held_by = null
			flying = true
			vel = Vector3.ZERO
		else:
			position = held_by.position + Vector3(0, 1.3, 0) + Defs.dir_of(held_by.rotation.y) * 0.3
	elif flying:
		var np := position + vel * dt
		vel.y -= GRAVITY * dt
		var r := world.combat.ray(position, np)
		if not r.is_empty():
			var n: Vector3 = r.normal
			vel = vel.bounce(n) * 0.35
			np = r.position + n * 0.06
		if np.y <= 0.06:
			np.y = 0.06
			if vel.y < 0.0:
				vel.y = -vel.y * 0.25
				vel.x *= 0.5
				vel.z *= 0.5
			if absf(vel.y) < 1.2 and Vector2(vel.x, vel.z).length() < 0.7:
				flying = false
				vel = Vector3.ZERO
		position = np
	if ptype == "frag":
		fuse -= dt
		if fuse <= 0.0:
			_frag_impact()
	else:
		if not flying or life_t > 1.6:
			smoke_t += dt
			if smoke_t < 22.0:
				smoke_r = minf(6.5, smoke_t * 2.6)
			else:
				smoke_r = maxf(0.0, smoke_r - dt * 1.5)
			if smoke_t > 27.0:
				world.despawn(self)


func _frag_impact() -> void:
	if not SoldierBrain.smothered(self):
		world.combat.explode(position, {"dmg": 150.0, "radius": 6.0, "fling": 9.0, "at": 0.0, "src": world.entity(thrower_id), "team": team, "by": by, "size": 1.0})
	world.despawn(self)


func _rocket(dt: float) -> void:
	vel.y -= 1.5 * dt
	var np := position + vel * dt
	var src: Entity = world.entity(thrower_id)
	var ex: Array = src.get_exclude() if src else []
	var r := world.combat.ray(position, np, ex)
	var boom := Vector3.INF
	if not r.is_empty():
		boom = r.position
	elif np.y <= 0.05:
		boom = Vector3(np.x, 0.1, np.z)
	elif life_t > 2.5:
		boom = np
	if boom != Vector3.INF:
		_rocket_impact(boom)
		return
	position = np


func _rocket_impact(boom: Vector3) -> void:
	var src := world.entity(thrower_id)
	var at := 450.0 if ptype == "recoilless" else 380.0
	world.combat.explode(boom, {"dmg": 110.0, "radius": 4.0, "fling": 8.0, "at": at, "dir": vel.normalized(), "track": 0.25 if ptype == "recoilless" else 0.2, "src": src, "team": team, "by": by, "size": 1.0, "struct_mult": 2.0})
	world.despawn(self)


func shell_pos(k: float) -> Vector3:
	if ptype in ["ac105", "ac40", "ac25"]:
		return origin.lerp(target, k)  # straight down from the gunship
	var apex := 10.0 + Defs.flat(target - origin).length() * (0.25 if ptype != "arty" else 0.32)
	return origin.lerp(target, k) + Vector3(0, apex * 4.0 * k * (1.0 - k), 0)


func is_shell() -> bool:
	return ptype in ["mortar", "mortar_smoke", "grad", "arty", "ac105", "ac40", "ac25"]


## Mortar shells follow a fixed high arc to their (already scattered) impact point.
func _shell() -> void:
	var k := life_t / maxf(0.1, shell_t)
	if k < 1.0:
		position = shell_pos(k)
		return
	_shell_impact()


func _shell_impact() -> void:
	var src: Entity = world.entity(thrower_id) if thrower_id != 0 else null
	match ptype:
		"grad":
			world.combat.explode(target, {"dmg": 150.0, "radius": 7.0, "fling": 10.0, "at": 120.0, "top": true, "src": src, "team": team, "by": by, "size": 1.6, "struct_mult": 2.0})
			world.despawn(self)
			return
		"arty":
			world.combat.explode(target, {"dmg": 230.0, "radius": 10.0, "fling": 14.0, "at": 220.0, "top": true, "src": src, "team": team, "by": by, "size": 2.3, "struct_mult": 3.0})
			world.despawn(self)
			return
		"ac105":
			world.combat.explode(target, {"dmg": 220.0, "radius": 8.5, "fling": 13.0, "at": 300.0, "top": true, "src": src, "team": team, "by": by, "size": 2.0, "struct_mult": 2.5})
			world.despawn(self)
			return
		"ac40":
			world.combat.explode(target, {"dmg": 95.0, "radius": 3.8, "fling": 6.0, "at": 140.0, "top": true, "src": src, "team": team, "by": by, "size": 0.85, "struct_mult": 1.5})
			world.despawn(self)
			return
		"ac25":
			world.combat.explode(target, {"dmg": 50.0, "radius": 1.8, "fling": 0.0, "at": 70.0, "top": true, "src": src, "team": team, "by": by, "size": 0.38, "struct_mult": 1.0})
			world.despawn(self)
			return
	if ptype == "mortar":
		world.combat.explode(target, {"dmg": 130.0, "radius": 6.5, "fling": 9.0, "at": 80.0, "top": true, "src": src, "team": team, "by": by, "size": 1.2, "struct_mult": 2.0})
	else:
		world.spawn("projectile", {"ptype": "smoke", "team": team, "pos": target + Vector3(0, 0.2, 0), "vel": Vector3.ZERO, "thrower": thrower_id, "fuse": 0.0, "by": by})
	world.despawn(self)


## Guided missile: lofts for a top attack and steers onto the target.
func _atgm(dt: float) -> void:
	var tgt: Entity = world.entity(tgt_id)
	if tgt and not tgt.gone:
		# the operator steers it onto what he can see: smoke in between and it
		# flies on blind to where he last had it
		if fmod(life_t, 0.25) < dt:
			var op: Entity = world.entity(thrower_id)
			if op != null and not op.gone and world.combat.smoke_blocks(op.position + Vector3(0, 1.5, 0), tgt.center_point()):
				tgt_id = 0
				world.stat("atgm_lost_in_smoke")
		if tgt_id != 0:
			target = tgt.center_point()
	var to := target - position
	var aim := target
	if Defs.flat(to).length() > 16.0:
		aim += Vector3(0, minf(9.0, Defs.flat(to).length() * 0.18), 0)
	var want := (aim - position).normalized()
	var cur := vel.normalized()
	var ang := cur.angle_to(want)
	if ang > 0.001:
		cur = cur.slerp(want, clampf(2.2 * dt / ang, 0.0, 1.0))
	var spd := minf(48.0, vel.length() + 20.0 * dt)
	vel = cur * spd
	var np := position + vel * dt
	var src: Entity = world.entity(thrower_id)
	var r := world.combat.ray(position, np, src.get_exclude() if src else [])
	var boom := Vector3.INF
	if not r.is_empty():
		boom = r.position
	elif np.y <= 0.05:
		boom = Vector3(np.x, 0.1, np.z)
	elif life_t > 7.0 or position.distance_to(target) < 0.8:
		boom = np
	if boom != Vector3.INF:
		world.combat.explode(boom, {"dmg": 90.0, "radius": 3.5, "fling": 7.0, "at": 520.0, "dir": vel.normalized(), "top": vel.y < -0.3, "track": 0.25, "src": src, "team": team, "by": by, "size": 1.1, "struct_mult": 2.0})
		world.despawn(self)
		return
	position = np


## Surface-to-air missile: fast, it turns hard onto the aircraft and bursts
## beside it on a proximity fuse.
func _sam(dt: float) -> void:
	var tgt: Entity = world.entity(tgt_id)
	if tgt and not tgt.gone:
		target = tgt.center_point()
	var want := (target - position).normalized()
	var cur := vel.normalized()
	var ang := cur.angle_to(want)
	if ang > 0.001:
		cur = cur.slerp(want, clampf(4.2 * dt / ang, 0.0, 1.0))
	var spd := minf(95.0, vel.length() + 50.0 * dt)
	vel = cur * spd
	var np := position + vel * dt
	var src: Entity = world.entity(thrower_id)
	var near := tgt != null and not tgt.gone and np.distance_to(target) < 3.2
	if near or life_t > 6.0 or np.y < 0.1:
		world.combat.explode(target if near else np, {"dmg": 60.0, "radius": 4.0, "fling": 2.0, "at": 620.0 if near else 0.0, "src": src, "team": team, "by": by, "size": 0.9, "struct_mult": 0.5})
		world.despawn(self)
		return
	position = np


## Whatever armour it's coming at sees the launch (and pops smoke).
func _warn_target() -> void:
	var tgt: Entity = world.entity(tgt_id) if tgt_id != 0 else null
	if tgt is Vehicle:
		tgt.threatened(position)
		return
	var dir := vel.normalized()
	for v in world.vehicles_near(position + dir * 40.0, 45.0):
		if v.team == team or v.gone:
			continue
		var to: Vector3 = v.position - position
		if to.length() < 100.0 and to.normalized().dot(dir) > 0.97:
			v.threatened(position)
			return


func pick_up(s: Soldier) -> void:
	held_by = s
	flying = false
	vel = Vector3.ZERO
	_reset_flight()


## Kicked away along the ground.
func kick(s: Soldier, v: Vector3) -> void:
	flying = true
	vel = v
	thrown_back += 1
	position.y = maxf(position.y, 0.15)
	smothered_by = null
	_reset_flight()


func release_throw(s: Soldier, pos: Vector3) -> void:
	held_by = null
	flying = true
	team = s.team
	thrower_id = s.eid
	thrown_back += 1
	var from := s.position + Vector3(0, 1.7, 0)
	position = from
	vel = world.combat.ballistic_vel(from, pos)
	_reset_flight()


func write_state(b: StreamPeerBuffer) -> void:
	put_v3(b, position)
	b.put_u8(int(clampf(smoke_r * 20.0, 0.0, 255.0)))
	b.put_u8(1 if flying else 0)


func read_state(b: StreamPeerBuffer) -> void:
	net_pos = get_v3(b)
	smoke_r = b.get_u8() / 20.0
	flying = b.get_u8() == 1


func _process(dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(dt)
	if world:
		world.vp("projectiles", _t0)


func _view_process(dt: float) -> void:
	if not world.has_view or model == null:
		return
	if ptype == "jet" or ptype == "bomb":
		if not srv:
			if ptype == "bomb":
				vel = _bomb_step(vel, dt)
			net_pos += vel * dt
			position = position.lerp(net_pos, 1.0 - exp(-dt * 10.0)) if position.distance_to(net_pos) < 25.0 else net_pos
		var fw := vel.normalized()
		if absf(fw.y) < 0.98:
			model.look_at(model.global_position + fw, Vector3.UP)
		if _vm:
			for pv in _vm.wheels:
				(pv as Node3D).rotate_object_local(Vector3(0, 0, 1), dt * 40.0)  # the propeller
		return
	if ptype == "a10":
		_a10_view(dt)
		return
	if ptype == "ac130":
		_ac130_view(dt)
		return
	if is_shell():
		if not srv:
			life_t += dt
			position = shell_pos(clampf(life_t / maxf(0.1, shell_t), 0.0, 1.0))
		if not _whistled and shell_t - life_t < (2.0 if ptype == "arty" else 1.4) and ptype in ["mortar", "grad", "arty"]:
			_whistled = true
			if ptype == "arty":
				Sfx.play("arty_whistle", target, 6.0, 1.0)
			else:
				Sfx.play("whistle", target, 2.0 if ptype == "mortar" else 4.0, 1.0 if ptype == "mortar" else 0.8)
		var k := clampf(life_t / maxf(0.1, shell_t), 0.0, 1.0)
		var nxt := shell_pos(minf(1.0, k + 0.02))
		if nxt.distance_to(position) > 0.01:
			model.look_at(nxt, Vector3.UP if absf((nxt - position).normalized().y) < 0.98 else Vector3.RIGHT)
		return
	if not srv:
		position = position.lerp(net_pos, 1.0 - exp(-dt * 20.0)) if position.distance_to(net_pos) < 15.0 else net_pos
	if ptype in ["rocket", "atgm", "recoilless", "sam"] and vel.length() > 0.1:
		var fwd := vel.normalized()
		if absf(fwd.dot(Vector3.UP)) < 0.98:
			model.look_at(model.global_position + fwd, Vector3.UP)
		if not srv:
			net_pos += vel * dt
	if smoke_fx:
		world.fx.vfx.set_smoke_screen(smoke_fx, smoke_r)


func on_despawn() -> void:
	if _gun_smoke and is_instance_valid(_gun_smoke):
		Vfx.set_emitting(_gun_smoke, false)
		var gs := _gun_smoke
		get_tree().create_timer(3.0).timeout.connect(gs.queue_free)
		_gun_smoke = null
	# let the exhaust trail drift away instead of vanishing with the rocket
	if trail and is_instance_valid(trail) and world.fx and world.fx.vfx:
		var gp := trail.global_position
		trail.reparent(world.fx.vfx)
		trail.global_position = gp
		Vfx.set_emitting(trail, false)
		get_tree().create_timer(2.0).timeout.connect(trail.queue_free)
		trail = null


func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	match ptype:
		"frag":
			Res.mi(model, Res.sphere(0.07, 8), Res.mat(Color(0.2, 0.25, 0.15)), Vector3.ZERO, Vector3.ZERO, false)
		"smoke":
			Res.mi(model, Res.cyl(0.05, 0.05, 0.16, 8), Res.mat(Color(0.5, 0.5, 0.45)), Vector3.ZERO, Vector3.ZERO, false)
			if world.fx and world.fx.vfx:
				smoke_fx = world.fx.vfx.make_smoke_screen()
				smoke_fx.position = Vector3(0, 0.6, 0)
				add_child(smoke_fx)
		"jet":
			_vm = VehicleModels.build(mk if mk != "" else "jet", team if team >= 0 else 0, eid)
			model.add_child(_vm.root)
			if _vm.wheels.is_empty():
				Sfx.play("jet", position + vel.normalized() * 160.0, 6.0)
			else:
				add_child(Sfx.make_loop_player("prop", 30.0, 2.0))  # a light plane droning over
		"bomb":
			Res.mi(model, Res.cyl(0.16, 0.16, 1.5, 10), Mats.get_mat("gunmetal_w"), Vector3.ZERO, Vector3(PI / 2, 0, 0), false)
			Res.mi(model, Res.box(Vector3(0.7, 0.05, 0.35)), Mats.get_mat("gunmetal_w"), Vector3(0, 0, 0.75), Vector3.ZERO, false)
			Res.mi(model, Res.box(Vector3(0.05, 0.7, 0.35)), Mats.get_mat("gunmetal_w"), Vector3(0, 0, 0.75), Vector3.ZERO, false)
		"grad":
			Res.mi(model, Res.cyl(0.07, 0.07, 1.6, 8), Res.mat(Color(0.3, 0.32, 0.26)), Vector3.ZERO, Vector3(PI / 2, 0, 0), false)
			Res.mi(model, Res.sphere(0.16, 6), Res.mat(Color(1.0, 0.7, 0.3), 0.5, 7.0, true), Vector3(0, 0, 0.85), Vector3.ZERO, false)
			if world.fx and world.fx.vfx:
				trail = world.fx.vfx.make_trail()
				add_child(trail)
		"mortar", "mortar_smoke", "arty":
			# drawn a little larger than life, trailing wisps, so the arc reads from the air
			var big := ptype == "arty"
			Res.mi(model, Res.cyl(0.11 if big else 0.08, 0.06, 0.9 if big else 0.6, 8), Res.mat(Color(0.25, 0.27, 0.2) if ptype != "mortar_smoke" else Color(0.6, 0.6, 0.55)), Vector3.ZERO, Vector3(PI / 2, 0, 0), false)
			Res.mi(model, Res.sphere(0.09 if big else 0.07, 6), Res.mat(Color(1.0, 0.75, 0.4), 0.5, 4.0, true), Vector3(0, 0, 0.4 if big else 0.3), Vector3.ZERO, false)
			if world.fx and world.fx.vfx:
				trail = world.fx.vfx.make_shell_trail(big)
				add_child(trail)
		"ac105":
			Res.mi(model, Res.cyl(0.12, 0.09, 0.8, 8), Res.mat(Color(0.22, 0.22, 0.2)), Vector3.ZERO, Vector3(PI / 2, 0, 0), false)
			if world.fx and world.fx.vfx:
				trail = world.fx.vfx.make_shell_trail(true)
				add_child(trail)
		"ac40", "ac25":
			# tracer: a glowing streak raining down from the orbit
			var ln := 7.0 if ptype == "ac40" else 4.5
			var tm := StandardMaterial3D.new()
			tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			tm.albedo_color = Color(1.0, 0.45, 0.2) if ptype == "ac40" else Color(1.0, 0.75, 0.35)
			tm.emission_enabled = true
			tm.emission = tm.albedo_color
			tm.emission_energy_multiplier = 9.0
			Res.mi(model, Res.cyl(0.07 if ptype == "ac40" else 0.05, 0.07 if ptype == "ac40" else 0.05, ln, 6), tm, Vector3(0, 0, ln * 0.5), Vector3(PI / 2, 0, 0), false)
		"a10":
			_vm = VehicleModels.build(mk if mk != "" else "a10", team if team >= 0 else 0, eid)
			model.add_child(_vm.root)
			Sfx.play_far("jet", -2.0, 0.82)
			if world.fx and world.fx.vfx:
				_gun_smoke = world.fx.vfx.make_gun_smoke()
				world.fx.vfx.add_child(_gun_smoke)
		"ac130":
			_vm = VehicleModels.build(mk if mk != "" else "ac130", team if team >= 0 else 0, eid)
			model.add_child(_vm.root)
			_drone = AudioStreamPlayer.new()
			_drone.bus = &"Effects"
			if Sfx.enabled:
				_drone.stream = Sfx.stream("prop")
				_drone.volume_db = -30.0
				_drone.autoplay = true
			add_child(_drone)
		"rocket", "atgm", "recoilless", "sam":
			Res.mi(model, Res.cyl(0.06, 0.06, 0.8, 8), Res.mat(Color(0.3, 0.32, 0.25)), Vector3.ZERO, Vector3(PI / 2, 0, 0), false)
			Res.mi(model, Res.sphere(0.12, 6), Res.mat(Color(1.0, 0.7, 0.3), 0.5, 6.0, true), Vector3(0, 0, 0.45), Vector3.ZERO, false)
			if world.fx and world.fx.vfx:
				trail = world.fx.vfx.make_trail()
				add_child(trail)



# --- eyes in the sky -------------------------------------------------------------------

const JET_SIGHT := 70.0  # a strike jet: the pilot and his targeting pod, a broad swath under him
const GUNRUN_SIGHT := 55.0  # low and busy on a gun run, he sees less of it
const ORBIT_SIGHT := 70.0  # an orbiting gunship or drone: its sensor turret, staring at the circle
const BELOW_SIGHT := 40.0  # and the ground it's flying over
const PHOTO_EVERY := 0.45
const PHOTO_LINGER := 6.0  # how long a recon pass's pictures go on showing what was there


## Support aircraft spot for their side as they fly (see Vision): a fast jet
## the ground round it, a gun run less, an orbiting gunship the circle its
## sensor turret watches while it's on station, and the ground below it. A
## recon flight's camera sees a broad strip either side of its track.
func add_eyes(out: PackedVector3Array) -> void:
	match ptype:
		"jet":
			if Defs.in_map(position, -40.0):
				out.append(Vector3(position.x, position.z, sight if sight > 0.0 else JET_SIGHT))
		"a10":
			if Defs.in_map(position, -40.0):
				out.append(Vector3(position.x, position.z, GUNRUN_SIGHT))
		"ac130":
			if life_t > 2.0 and life_t < on_station():
				out.append(Vector3(target.x, target.z, sight if sight > 0.0 else ORBIT_SIGHT))
			out.append(Vector3(position.x, position.z, BELOW_SIGHT))


## Which way an aircraft is flying, on the ground (an orbit's comes from its
## circle: clients aren't sent its velocity).
func heading() -> Vector3:
	if ptype == "ac130":
		return Defs.flat(_ac_pos(life_t + 0.1) - _ac_pos(life_t)).normalized()
	return Defs.flat(vel).normalized()


## A recon pass leaves its pictures behind: the strip it has flown over goes
## on showing for a few seconds while they're read (Rules.add_mark).
func _photograph(dt: float) -> void:
	_mark_t -= dt
	if _mark_t > 0.0 or team < 0 or not Defs.in_map(position, -sight):
		return
	_mark_t = PHOTO_EVERY
	world.rules.add_mark(team, position, sight, PHOTO_LINGER)


# --- A-10 gun run ----------------------------------------------------------------------

const A10_SPEED := 58.0
const A10_START := -420.0
const A10_FIRE_AT := -50.0  # along-track distance from the target where the burst starts
const A10_BURST := 1.0
const A10_STRIP := 18.0  # the rounds walk +-18 m through the target, ahead of the diving jet


static func a10_alt(along: float) -> float:
	if along < -160.0:
		return lerpf(62.0, 27.0, clampf((along - A10_START) / (-160.0 - A10_START), 0.0, 1.0))
	if along < 0.0:
		return lerpf(27.0, 21.0, (along + 160.0) / 160.0)
	return 21.0 + along * 0.42


## Comes in low along `vel`, nose down, and walks a two-second burst of 30 mm
## through the target; the BRRRT reaches the ground after the shells do.
func _a10(dt: float) -> void:
	var dirn := Defs.flat(vel).normalized()
	position += dirn * A10_SPEED * dt
	var along := Defs.flat(position - target).dot(dirn)
	position.y = a10_alt(along)
	vel = dirn * A10_SPEED + Vector3(0, (a10_alt(along + 1.0) - a10_alt(along)) * A10_SPEED, 0)
	if along >= A10_FIRE_AT and _fire_el < A10_BURST:
		if _fire_el < 0.0:
			_fire_el = 0.0
			world.stat("a10_run")
		var side := dirn.cross(Vector3.UP)
		var n := int(round(30.0 * dt + world.rng.randf() * 0.5))
		for i in n:
			var k := clampf(_fire_el / A10_BURST, 0.0, 1.0)
			var aim := target + dirn * lerpf(-A10_STRIP, A10_STRIP, k) + side * world.rng.randf_range(-3.0, 3.0) + dirn * world.rng.randf_range(-2.0, 2.0)
			aim.y = 0.15
			_hits.append([world.time + position.distance_to(aim) / 950.0, aim])
		_fire_el += dt
	for i in range(_hits.size() - 1, -1, -1):
		var h: Array = _hits[i]
		if world.time >= float(h[0]):
			_hits.remove_at(i)
			world.combat.explode(h[1], {"dmg": 75.0, "radius": 2.6, "fling": 5.0, "at": 170.0, "top": true, "src": null, "team": team, "by": by, "size": 0.68, "struct_mult": 1.6})
	if along > 420.0:
		world.despawn(self)


func _a10_view(dt: float) -> void:
	var dirn := Defs.flat(vel).normalized()
	if not srv:
		net_pos += dirn * A10_SPEED * dt
		position = position.lerp(net_pos, 1.0 - exp(-dt * 10.0)) if position.distance_to(net_pos) < 25.0 else net_pos
	var along := Defs.flat(position - target).dot(dirn)
	if not srv:
		position.y = a10_alt(along)
	var fw := (dirn * A10_SPEED + Vector3(0, (a10_alt(along + 1.0) - a10_alt(along)) * A10_SPEED, 0)).normalized()
	if absf(fw.y) < 0.98:
		model.look_at(model.global_position + fw, Vector3.UP)
	var firing := along >= A10_FIRE_AT and along < A10_FIRE_AT + A10_BURST * A10_SPEED
	var nose := position + fw * 7.6 + Vector3(0, -0.3, 0)
	if _vm and _vm.mg_tip and is_instance_valid(_vm.mg_tip) and _vm.mg_tip.is_inside_tree():
		nose = _vm.mg_tip.global_position  # the model's own gun muzzle
	if _gun_smoke:
		Vfx.set_emitting(_gun_smoke, firing)
		_gun_smoke.global_position = nose
	if firing:
		if _brrt_at < 0.0:
			# the shells (950 m/s) arrive well before the sound (343 m/s)
			_brrt_at = Time.get_ticks_msec() / 1000.0 + 0.55
		if randf() < 0.7 and world.fx:
			var k := clampf((along - A10_FIRE_AT) / (A10_BURST * A10_SPEED), 0.0, 1.0)
			var side := dirn.cross(Vector3.UP)
			var aim := target + dirn * lerpf(-A10_STRIP, A10_STRIP, k) + side * randf_range(-3.0, 3.0)
			world.fx._tracer(nose, aim, 3.5, 1.4)
			world.fx._flash(nose, 0.04, 2.2)
	if _brrt_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= _brrt_at:
		_brrt_at = 1e9
		Sfx.play_far("brrt", 2.0, 1.0, maxf(0.0, (world.cam.focus_pos.distance_to(target) if world.cam else 0.0) - 40.0))


# --- AC-130 ----------------------------------------------------------------------------

const AC_R := 165.0
const AC_ALT := 88.0
const AC_SPEED := 52.0
const AC_ON_STATION := 26.0
const AC_GUNS := {
	"ac105": {"every": 3.4, "burst": 1, "gap": 0.0, "T": 2.6, "spread": 2.5, "snd": "ac105", "vol": 5.0},
	"ac40": {"every": 2.3, "burst": 3, "gap": 0.38, "T": 1.8, "spread": 2.2, "snd": "ac40", "vol": 0.0},
	"ac25": {"every": 3.8, "burst": 14, "gap": 0.07, "T": 1.35, "spread": 3.2, "snd": "", "vol": 0.0},
}


## How long an orbit stays over the target (a drone keeping watch, longer).
func on_station() -> float:
	return stay if stay > 0.0 else AC_ON_STATION


func _ac_pos(t: float) -> Vector3:
	var a := fuse - t * AC_SPEED / AC_R  # a left-hand orbit: the target off the port wing, where the guns are
	return target + Vector3(cos(a) * AC_R, AC_ALT, sin(a) * AC_R)


## Other orbiting aircraft's weapons: a VTOL gunship's 30 mm and rockets, an
## armed drone's guided missiles (they come down like shells, steeply).
const GUNSETS := {
	"blackfish": {
		"ac105": {"every": 5.2, "burst": 1, "gap": 0.0, "T": 2.4, "spread": 2.8, "snd": "ac105", "vol": 4.0},
		"ac40": {"every": 2.6, "burst": 3, "gap": 0.4, "T": 1.7, "spread": 2.4, "snd": "ac40", "vol": 0.0},
		"ac25": {"every": 3.2, "burst": 16, "gap": 0.06, "T": 1.3, "spread": 3.4, "snd": "", "vol": 0.0},
	},
	"xian": {
		"ac25": {"every": 2.6, "burst": 10, "gap": 0.09, "T": 1.3, "spread": 3.0, "snd": "", "vol": 0.0},
		"grad": {"every": 5.0, "burst": 4, "gap": 0.25, "T": 1.6, "spread": 4.5, "snd": "", "vol": 0.0},
	},
	"greyhawk": {
		"ac40": {"every": 4.2, "burst": 1, "gap": 0.0, "T": 2.0, "spread": 1.2, "snd": "", "vol": 0.0},
	},
	"none": {},  # an unarmed drone keeping watch
}


## Orbits the target in a slow pylon turn for AC_ON_STATION seconds. Every gun
## fires on its own rhythm; the report is heard at once, the rounds take one to
## three seconds to come down.
func _ac130(dt: float) -> void:
	position = _ac_pos(life_t)
	vel = (_ac_pos(life_t + 0.1) - position) / 0.1
	if life_t < 3.0 or life_t > on_station():
		if life_t > on_station() + 8.0:
			world.despawn(self)
		return
	var gset: Dictionary = GUNSETS.get(guns, AC_GUNS)
	for g in gset:
		var gd: Dictionary = gset[g]
		if not _next.has(g):
			_next[g] = [life_t + world.rng.randf_range(0.0, float(gd.every)), 0]
		var nx: Array = _next[g]
		if life_t < float(nx[0]):
			continue
		var aim := _ac_aim()
		var spread: float = gd.spread
		aim += Vector3(world.rng.randf_range(-spread, spread), 0, world.rng.randf_range(-spread, spread))
		aim.y = 0.15
		var muzzle := position + Vector3(0, -1.5, 0)
		world.spawn("projectile", {"ptype": g, "team": team, "pos": muzzle, "origin": muzzle, "target": aim, "T": float(gd.T) * world.rng.randf_range(0.9, 1.1), "thrower": 0, "by": by})
		if String(gd.snd) != "":
			world.fx_event([Fx.FAR_SOUND, String(gd.snd), float(gd.vol), target])
		elif int(nx[1]) == 0:
			world.fx_event([Fx.FAR_SOUND, "ac25", 0.0, target])
		nx[1] = int(nx[1]) + 1
		if int(nx[1]) >= int(gd.burst):
			nx[1] = 0
			nx[0] = life_t + float(gd.every) * world.rng.randf_range(0.8, 1.2)
		else:
			nx[0] = life_t + float(gd.gap)


## Something worth shooting near the target: soldiers and vehicles of the other
## side (any side, for an observer's demo), else the ground near the centre.
func _ac_aim() -> Vector3:
	var cands := []
	for s in world.soldiers_near(target, 38.0):
		if s.life == Soldier.Life.ALIVE and (team < 0 or s.team != team):
			cands.append(s.position)
	for v in world.vehicles_near(target, 40.0):
		if team < 0 or v.team != team:
			cands.append(v.position)
			cands.append(v.position)
	if not cands.is_empty():
		return cands[world.rng.randi() % cands.size()]
	var a := world.rng.randf() * TAU
	var r := sqrt(world.rng.randf()) * 25.0
	return target + Vector3(cos(a) * r, 0, sin(a) * r)


func _ac130_view(dt: float) -> void:
	if not srv:
		life_t += dt
		position = _ac_pos(life_t)
	var fw := (_ac_pos(life_t + 0.1) - _ac_pos(life_t)).normalized()
	if absf(fw.y) < 0.98:
		model.look_at(model.global_position + fw, Vector3.UP)
		model.rotate_object_local(Vector3(0, 0, 1), 0.42)  # banked left into the turn, the guns on the target
	if _vm:
		for w in _vm.wheels:
			(w as Node3D).rotate_object_local(Vector3(0, 0, 1), dt * 40.0)
	if _drone:
		var d := world.cam.cam.global_position.distance_to(position) if world.cam else 200.0
		var fade := clampf(minf(life_t / 3.0, (on_station() + 8.0 - life_t) / 4.0), 0.0, 1.0)
		_drone.volume_db = linear_to_db(maxf(0.0005, fade * clampf(1.0 - (d - 60.0) / 400.0, 0.15, 1.0) * 0.35))
