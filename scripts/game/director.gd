class_name Director
extends Node
## Observer tools: a cinematic auto-camera that cuts between the hottest
## fighting, time controls (single player / observer only) and a choice of
## whose fog of war to watch through.

const SPEEDS := [0.0, 0.25, 0.5, 1.0, 2.0, 4.0]
const SHOT_MIN := 9.0
const SHOT_MAX := 15.0

var world: World
var active := false
var speed_i := 3
var hot: Array = []  # [pos, weight, real_time]
var _target := Vector3.INF
var _shot_left := 0.0
var _orbit := 0.12
var _zoom := 42.0
var _last_ms := 0
var _subject: Entity = null


func _ready() -> void:
	_last_ms = Time.get_ticks_msec()
	if world.local_team < 0:
		active = true


func can_control_time() -> bool:
	return LocalServer.connected or (world.srv and world.ready_peers.is_empty())


func speed() -> float:
	return SPEEDS[speed_i]


func set_speed_index(i: int) -> void:
	if not can_control_time():
		return
	speed_i = clampi(i, 0, SPEEDS.size() - 1)
	if LocalServer.connected:
		LocalServer.set_speed(SPEEDS[speed_i])
	Engine.time_scale = maxf(0.0001, SPEEDS[speed_i]) if speed_i > 0 else 0.0


func toggle_pause() -> void:
	if not can_control_time():
		return
	if speed_i == 0:
		set_speed_index(3)
	else:
		set_speed_index(0)


func cycle_view() -> void:
	if world.local_team >= 0:
		return
	world.view_team = world.view_team + 1
	if world.view_team > 1:
		world.view_team = -1


## Called for every visual event (shots, explosions...) so the camera knows where the action is.
func note(pos: Vector3, weight: float) -> void:
	hot.append([pos, weight, Time.get_ticks_msec() / 1000.0])
	if hot.size() > 400:
		hot = hot.slice(200)


## A strike is about to land here: cut to it now and hold the shot through the impact.
func cue(pos: Vector3, hold: float) -> void:
	if not active:
		return
	_subject = null
	_target = Defs.flat(pos)
	_zoom = randf_range(38.0, 50.0)
	_orbit = randf_range(0.04, 0.08) * (1.0 if randf() < 0.5 else -1.0)
	_shot_left = hold


func _real_dt() -> float:
	var now := Time.get_ticks_msec()
	var dt := (now - _last_ms) / 1000.0
	_last_ms = now
	return clampf(dt, 0.0, 0.1)


func _process(_dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(_dt)
	if world:
		world.vp("director", _t0)


func _view_process(_dt: float) -> void:
	var dt := _real_dt()
	if not active or world.cam == null:
		return
	var cam := world.cam
	if cam.user_moved:
		active = false
		cam.user_moved = false
		return
	_shot_left -= dt
	if _shot_left <= 0.0 or _target == Vector3.INF:
		_pick_shot()
	if _subject and not _subject.gone and _subject.visible:
		_target = _target.lerp(Defs.flat(_subject.position), 1.0 - exp(-dt * 1.5))
	var k := 1.0 - exp(-dt * 0.9)
	cam.focus_pos = cam.focus_pos.lerp(_target, k)
	cam.target_dist = lerpf(cam.target_dist, _zoom, 1.0 - exp(-dt * 0.6))
	cam.yaw += _orbit * dt


func _pick_shot() -> void:
	_shot_left = randf_range(SHOT_MIN, SHOT_MAX)
	_orbit = randf_range(0.05, 0.14) * (1.0 if randf() < 0.5 else -1.0)
	_zoom = randf_range(24.0, 48.0)
	var now := Time.get_ticks_msec() / 1000.0
	var live := []
	for h in hot:
		if now - float(h[2]) < 10.0:
			live.append(h)
	hot = live
	_subject = null
	if live.is_empty():
		# quiet battlefield: drift over a random squad or building
		var pool := []
		for s in world.soldiers:
			if s.life == Soldier.Life.ALIVE and s.visible:
				pool.append(s)
		if pool.is_empty():
			_target = world.cam.focus_pos
			return
		_subject = pool[randi() % pool.size()]
		_target = Defs.flat(_subject.position)
		_zoom = randf_range(30.0, 55.0)
		return
	var best := Vector3.ZERO
	var bs := -1.0
	for i in mini(live.size(), 60):
		var c: Array = live[randi() % live.size()]
		var sc := 0.0
		for h in live:
			var d := Defs.flat(h[0] - c[0]).length()
			if d < 25.0:
				sc += float(h[1]) * (1.0 - d / 25.0) * (1.0 - (now - float(h[2])) / 10.0)
		# prefer a new location over staying put
		if _target != Vector3.INF and Defs.flat(c[0] - _target).length() < 15.0:
			sc *= 0.7
		if sc > bs:
			bs = sc
			best = c[0]
	_target = Defs.flat(best)
	# follow a soldier near the action for a more personal shot
	var near := []
	for s in world.soldiers:
		if s.life == Soldier.Life.ALIVE and s.visible and Defs.flat(s.position - _target).length() < 18.0:
			near.append(s)
	if not near.is_empty() and randf() < 0.6:
		_subject = near[randi() % near.size()]
		_zoom = randf_range(18.0, 32.0)
