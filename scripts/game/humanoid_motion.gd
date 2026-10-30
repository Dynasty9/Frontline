class_name HumanoidMotion
extends RefCounted
## Shared secondary motion, independent of clothes and weapons. Authored clips
## can supply the gait later; weight shifts and hit recovery still layer over it.

var hit := ImpactResponse.new()
var _speed := 0.0
var _yaw := 0.0
var _ready := false
var _lean := Vector3.ZERO


func react(direction: Vector3, strength: float) -> void:
	var d := direction.normalized()
	hit.kick(Vector3(d.z, d.x * 0.35, -d.x) * clampf(strength, 0.0, 1.0) * 3.0)


func apply(m, dt: float, speed: float, posture: int, act: int) -> void:
	var reaction := hit.step(dt)
	# The Field Manual poses previews before attaching them to its viewport.
	var yaw: float = m.global_rotation.y if m.is_inside_tree() else m.rotation.y
	if not _ready:
		_yaw = yaw
		_speed = speed
		_ready = true
	var elapsed := maxf(dt, 0.001)
	var acceleration := clampf((speed - _speed) / elapsed, -8.0, 8.0)
	var turn := clampf(wrapf(yaw - _yaw, -PI, PI) / elapsed, -3.0, 3.0)
	_speed = speed
	_yaw = yaw
	var target := Vector3(-acceleration * 0.014, -turn * 0.025, turn * minf(speed, 4.0) * 0.018)
	_lean = _lean.lerp(target, 1.0 - exp(-elapsed * 9.0))
	if posture == Soldier.Post.PRONE or m.crew:
		return
	if act in [Soldier.Act.IDLE, Soldier.Act.WALK, Soldier.Act.RUN, Soldier.Act.SHOOT, Soldier.Act.RELOAD]:
		m.t_torso += _lean + reaction
		m.t_head -= (_lean + reaction) * 0.35
		if speed > 0.25:
			# Weight crosses onto the supporting leg; shoulders counter the pelvis.
			var weight := sin(m.phase) * minf(speed / 2.0, 1.0)
			m.t_hips_p.x += weight * 0.018
			m.t_hips_r.z += weight * 0.025
			m.t_torso.z -= weight * 0.04
