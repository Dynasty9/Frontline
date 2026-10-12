class_name Drone
extends Entity
## FPV kamikaze drone. Climbs, cruises toward the target, then dives in.
## Soldiers hear it coming, try to shoot it down or dive away.

var operator: Soldier = null
var operator_id := 0
var target: Entity = null
var target_id := 0
var target_pos := Vector3.ZERO
var vel := Vector3.ZERO
var phase := 0
var dead := false
var diving := false
var life_t := 0.0
var warhead := 1.0

var model: Node3D
var rotors: Array = []
var buzz: AudioStreamPlayer3D
var _vis := true


func ekind() -> String:
	return "drone"


func display_name() -> String:
	return "FPV Drone"


func apply_props(d: Dictionary) -> void:
	if d.has("team"):
		team = d.team
	if d.has("pos"):
		position = d.pos
		net_pos = d.pos
	if d.has("operator"):
		operator_id = d.operator
	if d.has("target"):
		target_id = d.target


func get_props() -> Dictionary:
	return {"team": team, "pos": position, "operator": operator_id, "target": target_id}


func on_spawned() -> void:
	net_pos = position
	net_init = true
	if srv:
		target_pos = position
	if world.has_view:
		_build_model()


func exposed_points() -> Array:
	return [position]


func center_point() -> Vector3:
	return position


func hit_factor() -> float:
	return 0.3


func lose_control() -> void:
	if phase != 3:
		phase = 3
		operator = null
		diving = false


func sim(dt: float) -> void:
	if dead:
		return
	life_t += dt
	if operator and (operator.gone or operator.life != Soldier.Life.ALIVE):
		lose_control()
	if target and not target.gone:
		if target is Soldier and target.life == Soldier.Life.ALIVE:
			target_pos = target.center_point()
		elif target is Vehicle:
			target_pos = target.position + Vector3(0, 2.0, 0)
		else:
			target = null
	elif target != null:
		target = null
	var hd := Defs.flat(target_pos - position).length()
	match phase:
		0:
			vel = vel.lerp(Vector3(0, 6.0, 0) + Defs.flat(target_pos - position).normalized() * 6.0, 1.0 - exp(-dt * 3.0))
			if position.y > 6.5:
				phase = 1
		1:
			var want := Defs.flat(target_pos - position).normalized() * 21.0
			want.y = (7.5 - position.y) * 1.5
			vel = vel.lerp(want, 1.0 - exp(-dt * 2.5))
			if hd < 24.0:
				phase = 2
				diving = true
		2:
			var want2 := (target_pos - position).normalized() * 26.0
			vel = vel.lerp(want2, 1.0 - exp(-dt * 5.0))
			if position.distance_to(target_pos) < 1.4:
				detonate()
				return
		3:
			vel.y -= 6.0 * dt
			vel = vel.lerp(Vector3(vel.x, vel.y, vel.z) * 0.99, dt)
	var np := position + vel * dt
	var r := world.combat.ray(position, np)
	if not r.is_empty():
		position = r.position
		detonate()
		return
	position = np
	if vel.length() > 0.5:
		rotation.y = Defs.yaw_of(Defs.flat(vel)) if Defs.flat(vel).length() > 0.3 else rotation.y
	if position.y < 0.25 or life_t > 50.0 or not Defs.in_map(position, 0.0):
		detonate()


func detonate() -> void:
	if dead:
		return
	world.stat("drone_boom")
	dead = true
	world.combat.explode(position, {"dmg": 150.0 * warhead, "radius": 5.0, "fling": 9.0, "at": 340.0 * warhead, "top": true, "track": 0.3, "src": operator, "team": team, "size": 1.1, "struct_mult": 1.5})
	world.despawn(self)


func shot_down() -> void:
	if dead:
		return
	world.stat("drone_shot_down")
	dead = true
	world.fx_event([Fx.EXPLODE, position, 0.35])
	world.fx_event([Fx.DEBRIS, position, Color(0.15, 0.15, 0.15), 5])
	world.send_msg(1 - team if team >= 0 else -1, "info", "FPV drone shot down!")
	world.despawn(self)


func write_state(b: StreamPeerBuffer) -> void:
	put_v3(b, position)
	put_ang(b, rotation.y)
	b.put_u8((1 if diving else 0) | (2 if phase == 3 else 0))
	b.put_u8(vis_mask)


func read_state(b: StreamPeerBuffer) -> void:
	net_pos = get_v3(b)
	net_yaw = get_ang(b)
	var f := b.get_u8()
	diving = (f & 1) != 0
	vis_mask = b.get_u8()


func _process(dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(dt)
	if world:
		world.vp("drones", _t0)


func _view_process(dt: float) -> void:
	if not world.has_view or model == null:
		return
	if not srv:
		net_smooth(dt)
	var v := seen_by_local()
	if v != _vis:
		visible = v
		_vis = v
	for r in rotors:
		r.rotation.y += dt * 60.0
	model.rotation.x = lerpf(model.rotation.x, -0.6 if diving else -0.15, 1.0 - exp(-dt * 5.0))


func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var dark := Res.mat(Color(0.12, 0.12, 0.12))
	Res.mi(model, Res.box(Vector3(0.18, 0.08, 0.3)), dark, Vector3.ZERO, Vector3.ZERO, false)
	Res.mi(model, Res.cyl(0.05, 0.05, 0.28, 8), Res.mat(Color(0.35, 0.33, 0.25)), Vector3(0, -0.06, -0.05), Vector3(PI / 2, 0, 0), false)
	for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var off := Vector3(cos(a), 0, sin(a)) * 0.2
		var arm := Res.mi(model, Res.box(Vector3(0.03, 0.02, 0.28)), dark, off * 0.5, Vector3(0, -a + PI * 0.5, 0), false)
		arm.rotation.y = atan2(off.x, off.z)
		var rot := Node3D.new()
		rot.position = off + Vector3(0, 0.05, 0)
		model.add_child(rot)
		Res.mi(rot, Res.box(Vector3(0.24, 0.005, 0.03)), Res.mat(Color(0.3, 0.3, 0.3, 0.6)), Vector3.ZERO, Vector3.ZERO, false)
		rotors.append(rot)
	Res.mi(model, Res.sphere(0.025, 6), Res.mat(Color(1, 0.1, 0.1), 0.5, 5.0, true), Vector3(0, 0.05, -0.15), Vector3.ZERO, false)
	model.scale = Vector3.ONE * 1.6
	buzz = Sfx.make_drone_player()
	add_child(buzz)
