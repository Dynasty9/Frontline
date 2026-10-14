class_name RtsCamera
extends Node3D
## Pan (WASD / arrows / screen edge), zoom (wheel), rotate (Q/E or middle drag).

## How far out the camera pulls back (a bigger map wants a wider view).
const MAX_DIST := 160.0

var world: World
var cam: Camera3D
var yaw := 0.0
var pitch_deg := NAN  # debug: a fixed pitch (model close-ups)
var dist := 55.0
var target_dist := 55.0
var focus_pos := Vector3.ZERO
var _shake := 0.0
var _rot_drag := false
var edge_pan := true
var user_moved := false
var _last_ms := 0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = clampf(float(Settings.get_v("fov")), 35.0, 75.0)
	cam.near = 0.3
	cam.far = 700.0
	add_child(cam)
	cam.current = true
	_apply()


func focus(p: Vector3) -> void:
	focus_pos = Vector3(p.x, 0, p.z)
	_apply()


func shake(amount: float) -> void:
	_shake = minf(1.2, _shake + amount)


func _typing() -> bool:
	return world.hud != null and world.hud.typing


func _process(_scaled_dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(_scaled_dt)
	if world:
		world.vp("camera", _t0)


func _view_process(_scaled_dt: float) -> void:
	# use real time so the camera still works while the game is paused or slowed
	var now := Time.get_ticks_msec()
	var dt := clampf((now - _last_ms) / 1000.0, 0.0, 0.1) if _last_ms > 0 else 0.016
	_last_ms = now
	var move := Vector2.ZERO
	if not _typing():
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move.x += 1.0
		if Input.is_key_pressed(KEY_Q):
			yaw += dt * 1.6
		if Input.is_key_pressed(KEY_E):
			yaw -= dt * 1.6
	if edge_pan and get_window().has_focus():
		var mp := get_viewport().get_mouse_position()
		var vs := get_viewport().get_visible_rect().size
		if mp.x >= 0 and mp.y >= 0 and mp.x <= vs.x and mp.y <= vs.y:
			if mp.x < 4:
				move.x -= 1.0
			elif mp.x > vs.x - 5:
				move.x += 1.0
			if mp.y < 4:
				move.y -= 1.0
			elif mp.y > vs.y - 5:
				move.y += 1.0
	if move != Vector2.ZERO or (not _typing() and (Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_E))):
		user_moved = true
	var spd := (12.0 + dist * 1.1) * float(Settings.get_v("cam_speed"))
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	focus_pos += (right * move.x - fwd * move.y) * spd * dt
	focus_pos.x = clampf(focus_pos.x, -Defs.MAP_HALF, Defs.MAP_HALF)
	focus_pos.z = clampf(focus_pos.z, -Defs.MAP_HALF, Defs.MAP_HALF)
	dist = lerpf(dist, target_dist, 1.0 - exp(-dt * 10.0))
	_shake = maxf(0.0, _shake - dt * 2.0)
	_apply()


func _apply() -> void:
	var k := clampf((dist - 12.0) / (MAX_DIST - 12.0), 0.0, 1.0)
	var pitch := deg_to_rad(lerpf(-38.0, -66.0, k) if is_nan(pitch_deg) else pitch_deg)
	position = focus_pos
	rotation = Vector3(pitch, yaw, 0)
	cam.position = Vector3(0, 0, dist)
	if _shake > 0.0:
		cam.h_offset = randf_range(-1, 1) * _shake * 0.4
		cam.v_offset = randf_range(-1, 1) * _shake * 0.4
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP and not mb.shift_pressed:
			target_dist = clampf(target_dist * 0.88, 12.0, MAX_DIST)
			user_moved = true
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and not mb.shift_pressed:
			target_dist = clampf(target_dist * 1.14, 12.0, MAX_DIST)
			user_moved = true
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_rot_drag = mb.pressed
			user_moved = true
	elif ev is InputEventMouseMotion and _rot_drag:
		yaw -= (ev as InputEventMouseMotion).relative.x * 0.006


func ground_point(screen: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector3(o.x, 0, o.z)
	var t := -o.y / d.y
	return o + d * t
