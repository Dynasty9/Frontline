class_name RtsCamera
extends Node3D
## The commander's camera: an orbit round a point on the ground, with the
## controls players bring from other RTS games.
## Pan: WASD / arrows / screen edge (Shift: faster), or grab the map with the
## middle mouse. Zoom: wheel (toward the cursor) or + / -. Turn: Q / E, or drag
## with the middle mouse (up and down tilts). Tilt: Page Up / Page Down.
## Backspace squares the view up again. The middle-mouse drag turns the view
## by default, Alt+drag grabs the map (a setting swaps them).

## How far the camera pulls back (a bigger map wants a wider view).
const MAX_DIST := 210.0
const MIN_DIST := 12.0
## The player's tilt is added to the pitch that comes with the zoom (low and
## level close in, steep from high up), within these bounds.
const TILT_MIN := -26.0  # degrees: down towards a plan view
const TILT_MAX := 22.0  # up towards the horizon
const PITCH_MIN := -86.0
const PITCH_MAX := -20.0
## Never lower than this over the ground: close in, tilting up stops before
## the lens ends up in the hedges and the roofs.
const MIN_HEIGHT := 6.5
## Rays at or above the horizon are taken as meeting the ground this steeply
## (so an order given with the cursor in the sky lands far out, not behind us).
const MIN_RAY_DIP := 0.05

var world: World
var cam: Camera3D
var yaw := 0.0
var home_yaw := 0.0  # Backspace turns back to this: looking out from our own lines
var tilt := 0.0  # degrees, added to the zoom's pitch
var pitch_deg := NAN  # debug: a fixed pitch (model close-ups)
var dist := 55.0
var target_dist := 55.0
var focus_pos := Vector3.ZERO
var _shake := 0.0
var edge_pan := true
var user_moved := false
var _last_ms := 0
var _vel := Vector2.ZERO  # eased keyboard / edge pan, -1..1 on each screen axis

# the middle-mouse drag: turning the view, or holding a spot on the ground under the cursor
var _mmb := false
var _mmb_pan := false
var _grab := Vector3.ZERO
var _grab_far := false

# zooming toward the cursor: this ground point stays under that screen point until the zoom settles
var _zoom_anchor := Vector3.INF
var _zoom_screen := Vector2.ZERO

# a smooth jump (alerts, bases, groups, saved views)
var _gliding := false
var _g_t := 0.0
var _g_len := 0.3
var _g_pos := [Vector3.ZERO, Vector3.ZERO]
var _g_yaw := [0.0, 0.0]
var _g_tilt := [0.0, 0.0]
var _g_moves := false

## Following the selection (Ctrl+F): the camera keeps the selected units in view until you pan away.
var follow := false
var _follow_at := Vector3.INF
var _follow_t := 0.0

## Saved views (Ctrl+F5..F8 to save, F5..F8 to go back): key -> [focus, zoom, heading, tilt].
var bookmarks := {}


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = clampf(float(Settings.get_v("fov")), 35.0, 75.0)
	cam.near = 0.3
	cam.far = 700.0
	add_child(cam)
	cam.current = true
	_apply()


## Jumps straight there (the minimap, test framing).
func focus(p: Vector3) -> void:
	focus_pos = _clamp_map(p)
	_gliding = false
	_zoom_anchor = Vector3.INF
	_apply()


## Sets the heading the battle starts on, which Backspace comes back to.
func set_heading(y: float) -> void:
	yaw = y
	home_yaw = y


## Slides the view there instead of cutting, so you can see which way you went.
## Optionally to a zoom, a heading and a tilt as well.
func glide_to(p: Vector3, zoom := -1.0, heading := NAN, to_tilt := NAN) -> void:
	_g_pos = [focus_pos, _clamp_map(p)]
	_g_yaw = [yaw, yaw if is_nan(heading) else yaw + wrapf(heading - yaw, -PI, PI)]
	_g_tilt = [tilt, tilt if is_nan(to_tilt) else to_tilt]
	var far := Defs.flat(_g_pos[1] - focus_pos).length()
	_g_len = 0.22 + clampf(far / 900.0, 0.0, 0.38) + (0.12 if absf(_g_yaw[1] - yaw) > 0.5 else 0.0)
	_g_t = 0.0
	_gliding = true
	# a jump somewhere else ends a follow; turning on the spot (Backspace) doesn't
	_g_moves = far > 0.5
	if _g_moves:
		stop_follow()
	_zoom_anchor = Vector3.INF
	if zoom > 0.0:
		target_dist = clampf(zoom, MIN_DIST, MAX_DIST)
	user_moved = true


## Backspace: turn back to the starting heading and the zoom's own tilt.
func reset_view() -> void:
	glide_to(focus_pos, -1.0, home_yaw, 0.0)


func shake(amount: float) -> void:
	_shake = minf(1.2, _shake + amount)


## One notch of the wheel; toward a point on the screen when there is one.
func zoom_step(dir: int, at := Vector2(-1, -1)) -> void:
	target_dist = clampf(target_dist * (0.87 if dir < 0 else 1.15), MIN_DIST, MAX_DIST)
	user_moved = true
	_zoom_anchor = Vector3.INF
	# (mid-jump or following, the camera is already going somewhere: zoom on the middle)
	if at.x >= 0.0 and bool(Settings.get_v("zoom_cursor")) and not _gliding and not follow:
		var g := ground_point(at)
		# a spot out near the horizon would drag the view a long way: zoom on the centre instead
		if Defs.flat(g - focus_pos).length() < dist * 2.2:
			_zoom_anchor = g
			_zoom_screen = at


func toggle_follow() -> void:
	if follow:
		stop_follow()
		return
	_follow_at = world.input.selection_centre() if world.input else Vector3.INF
	if _follow_at == Vector3.INF:
		if world.hud:
			world.hud.flash("Select units for the camera to follow")
		return
	follow = true
	_follow_t = 0.0
	_gliding = false
	user_moved = true
	if world.hud:
		world.hud.flash("Camera following the selection  (Ctrl+F or pan to stop)")


func stop_follow() -> void:
	if not follow:
		return
	follow = false
	if world.hud:
		world.hud.flash("Camera stopped following")


## Saves the view on a function key, or goes back to it.
func bookmark(slot: int, save: bool) -> void:
	if save:
		bookmarks[slot] = [focus_pos, target_dist, yaw, tilt]
		if world.hud:
			world.hud.flash("View saved to F%d" % slot)
		return
	var b: Array = bookmarks.get(slot, [])
	if b.is_empty():
		if world.hud:
			world.hud.flash("No view saved on F%d  (Ctrl+F%d saves one)" % [slot, slot])
		return
	stop_follow()
	glide_to(b[0], float(b[1]), float(b[2]), float(b[3]))


func _typing() -> bool:
	return world.hud != null and world.hud.typing


func _clamp_map(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -MapDims.HALF, MapDims.HALF), 0.0, clampf(p.z, -MapDims.HALF, MapDims.HALF))


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
	var turn := 0.0
	var lift := 0.0
	var zoom := 0.0
	var fast := false
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
			turn += 1.0
		if Input.is_key_pressed(KEY_E):
			turn -= 1.0
		if Input.is_key_pressed(KEY_PAGEUP):
			lift += 1.0
		if Input.is_key_pressed(KEY_PAGEDOWN):
			lift -= 1.0
		if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
			zoom -= 1.0
		if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
			zoom += 1.0
		fast = Input.is_key_pressed(KEY_SHIFT)
	if edge_pan and not _mmb and get_window().has_focus():
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
	move = move.limit_length(1.0)
	if move != Vector2.ZERO:
		# any pan of your own takes the camera back from a jump, a follow or a cursor zoom
		_gliding = false
		_zoom_anchor = Vector3.INF
		stop_follow()
	if move != Vector2.ZERO or turn != 0.0 or lift != 0.0 or zoom != 0.0:
		user_moved = true
	# ease in and out over a few frames: starts and stops read as a glide, not a jolt
	_vel = _vel.lerp(move, 1.0 - exp(-dt * 14.0))
	if move == Vector2.ZERO and _vel.length_squared() < 0.0001:
		_vel = Vector2.ZERO
	var spd := (12.0 + dist * 1.1) * float(Settings.get_v("cam_speed")) * (2.5 if fast else 1.0)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	focus_pos += (right * _vel.x - fwd * _vel.y) * spd * dt
	yaw += turn * dt * 1.6
	tilt = clampf(tilt + lift * dt * 45.0, TILT_MIN, TILT_MAX)
	if zoom != 0.0:
		target_dist = clampf(target_dist * exp(zoom * dt * 1.8), MIN_DIST, MAX_DIST)
		_zoom_anchor = Vector3.INF
	if _gliding:
		_g_t = minf(1.0, _g_t + dt / _g_len)
		var e := 1.0 - pow(1.0 - _g_t, 3.0)
		if _g_moves:
			focus_pos = (_g_pos[0] as Vector3).lerp(_g_pos[1], e)
		yaw = lerpf(_g_yaw[0], _g_yaw[1], e)
		tilt = lerpf(_g_tilt[0], _g_tilt[1], e)
		_gliding = _g_t < 1.0
	if follow:
		_follow_t -= dt
		if _follow_t <= 0.0:
			# where the selection is, a few times a second (it walks; the camera eases after it)
			_follow_t = 0.1
			_follow_at = world.input.selection_centre() if world.input else Vector3.INF
			if _follow_at == Vector3.INF:
				stop_follow()
		if follow:
			focus_pos = focus_pos.lerp(_follow_at, 1.0 - exp(-dt * 3.5))
	focus_pos = _clamp_map(focus_pos)
	dist = lerpf(dist, target_dist, 1.0 - exp(-dt * 10.0))
	_shake = maxf(0.0, _shake - dt * 2.0)
	_apply()
	if _zoom_anchor != Vector3.INF:
		# keep the spot that was under the cursor there while the zoom eases in
		var g := ground_point(_zoom_screen)
		focus_pos = _clamp_map(focus_pos + Defs.flat(_zoom_anchor - g))
		_apply()
		if absf(dist - target_dist) < 0.02:
			_zoom_anchor = Vector3.INF


## The pitch in degrees: the zoom's own, plus the player's tilt.
func pitch() -> float:
	if not is_nan(pitch_deg):
		return pitch_deg
	var k := clampf((dist - MIN_DIST) / (MAX_DIST - MIN_DIST), 0.0, 1.0)
	var p := clampf(lerpf(-38.0, -66.0, k) + tilt, PITCH_MIN, PITCH_MAX)
	return minf(p, -rad_to_deg(asin(clampf(MIN_HEIGHT / maxf(dist, 0.1), 0.0, 1.0))))


func _apply() -> void:
	position = focus_pos
	rotation = Vector3(deg_to_rad(pitch()), yaw, 0)
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
			zoom_step(-1, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and not mb.shift_pressed:
			zoom_step(1, mb.position)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mmb = mb.pressed
			if mb.pressed:
				# the setting picks what a plain drag does; Alt does the other
				_mmb_pan = (int(Settings.get_v("mmb_mode")) == 1) != mb.alt_pressed
				_gliding = false
				_zoom_anchor = Vector3.INF
				if _mmb_pan:
					_grab = ground_point(mb.position)
					_grab_far = Defs.flat(_grab - focus_pos).length() > dist * 2.5
					stop_follow()
			user_moved = true
	elif ev is InputEventMouseMotion and _mmb:
		var mm := ev as InputEventMouseMotion
		if _mmb_pan and not _grab_far:
			# the spot grabbed stays under the cursor, like dragging a paper map
			var g := ground_point(mm.position)
			focus_pos = _clamp_map(focus_pos + Defs.flat(_grab - g))
		elif _mmb_pan:
			# grabbed out by the horizon, where a pixel is many metres: pan at the
			# scale of the middle of the screen instead, so the map doesn't lurch
			var mpp := dist * 2.0 * tan(deg_to_rad(cam.fov * 0.5)) / maxf(1.0, get_viewport().get_visible_rect().size.y)
			var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
			var right := Vector3(cos(yaw), 0, -sin(yaw))
			focus_pos = _clamp_map(focus_pos + (fwd * mm.relative.y - right * mm.relative.x) * mpp)
		else:
			yaw -= mm.relative.x * 0.006
			tilt = clampf(tilt - mm.relative.y * 0.15, TILT_MIN, TILT_MAX)
		_apply()


func ground_point(screen: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	d.y = minf(d.y, -MIN_RAY_DIP)
	var t := -o.y / d.y
	return Vector3(o.x + d.x * t, 0.0, o.z + d.z * t)
