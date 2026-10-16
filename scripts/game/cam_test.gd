extends Node
## --cam-test: drives the camera through its controls with made-up input and
## checks each one does what it says (prints CAMTEST ok / FAIL lines and a
## total, then quits). The camera needs a screen, so run it in a window (or
## off-screen with --offscreen), not headless:
##   godot --path . -- --mission=bridgehead --play --cam-test --offscreen

var world: World
var _fails := 0
var _n := 0


func _ready() -> void:
	_run()


func _check(what: String, ok: bool, detail := "") -> void:
	_n += 1
	if not ok:
		_fails += 1
	print("CAMTEST %s %s  %s" % ["ok  " if ok else "FAIL", what, detail])


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


## Waits until the camera has stopped moving (zoom eased in, jump finished):
## the camera steps by real time, capped per frame, so a slow window takes longer.
func _settle(cam: RtsCamera) -> void:
	var t := 0.0
	while t < 6.0 and (absf(cam.dist - cam.target_dist) > 0.02 or cam._gliding):
		await _wait(0.1)
		t += 0.1
	await _wait(0.1)


func _mb(btn: MouseButton, down: bool, at: Vector2, alt := false) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = btn
	e.pressed = down
	e.position = at
	e.alt_pressed = alt
	return e


func _mm(at: Vector2, rel: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.relative = rel
	return e


func _drag(cam: RtsCamera, a: Vector2, b: Vector2, alt := false) -> void:
	cam._unhandled_input(_mb(MOUSE_BUTTON_MIDDLE, true, a, alt))
	cam._unhandled_input(_mm(b, b - a))
	cam._unhandled_input(_mb(MOUSE_BUTTON_MIDDLE, false, b, alt))


func _run() -> void:
	await _wait(1.5)
	var cam := world.cam
	if world.director:
		world.director.active = false
	var vs := get_viewport().get_visible_rect().size
	var mid := vs * 0.5
	Settings.v["zoom_cursor"] = true
	Settings.v["mmb_mode"] = 0

	# a ray into the sky (tilted right up, the top of the screen is above the
	# horizon) lands far out ahead, not behind the camera
	cam.tilt = RtsCamera.TILT_MAX
	cam.target_dist = 40.0
	cam.dist = 40.0
	cam._apply()
	var up_ray := cam.cam.project_ray_normal(Vector2(mid.x, 0)).y
	var sky := cam.ground_point(Vector2(mid.x, 0))
	var fwd := Vector3(-sin(cam.yaw), 0, -cos(cam.yaw))
	_check("a ray into the sky lands ahead", up_ray > 0.0 and (sky - cam.focus_pos).dot(fwd) > 0.0, "pitch %.1f, ray %.3f up, lands %.0f m out" % [cam.pitch(), up_ray, (sky - cam.focus_pos).length()])
	# tilted right up and zoomed right in, the lens stays above the hedges
	cam.target_dist = RtsCamera.MIN_DIST
	cam.dist = RtsCamera.MIN_DIST
	cam._apply()
	_check("the camera stays above the ground clutter", cam.cam.global_position.y >= RtsCamera.MIN_HEIGHT - 0.05, "%.2f m up" % cam.cam.global_position.y)
	cam.tilt = 0.0
	cam.target_dist = 70.0
	cam.dist = 70.0
	cam._apply()

	# the wheel zooms toward the cursor: the spot under it stays under it, in and out
	var sp := Vector2(vs.x * 0.75, vs.y * 0.35)
	var g0 := cam.ground_point(sp)
	for i in 3:
		cam.zoom_step(-1, sp)
	await _settle(cam)
	_check("zooming in toward the cursor holds the spot", g0.distance_to(cam.ground_point(sp)) < 1.5 and cam.dist < 50.0, "drift %.2f m, zoom %.0f m" % [g0.distance_to(cam.ground_point(sp)), cam.dist])
	for i in 3:
		cam.zoom_step(1, sp)
	await _settle(cam)
	_check("zooming out from the cursor holds the spot", g0.distance_to(cam.ground_point(sp)) < 1.5, "drift %.2f m" % g0.distance_to(cam.ground_point(sp)))

	# a middle drag turns and tilts by default ...
	var y0 := cam.yaw
	var t0 := cam.tilt
	var f0 := cam.focus_pos
	_drag(cam, mid, mid + Vector2(100, -40))
	_check("middle drag turns and tilts", absf(cam.yaw - (y0 - 0.6)) < 0.01 and absf(cam.tilt - (t0 + 6.0)) < 0.01 and f0.distance_to(cam.focus_pos) < 0.01, "turned %.2f rad, tilted %.1f deg" % [cam.yaw - y0, cam.tilt - t0])
	# ... with Alt it grabs the map, and the grabbed spot follows the cursor
	var b := mid + Vector2(-260, 120)
	var held := cam.ground_point(mid)
	_drag(cam, mid, b, true)
	_check("Alt + middle drag grabs the map", held.distance_to(cam.ground_point(b)) < 0.5 and f0.distance_to(cam.focus_pos) > 1.0, "drift %.2f m" % held.distance_to(cam.ground_point(b)))
	# the setting swaps them
	Settings.v["mmb_mode"] = 1
	held = cam.ground_point(mid)
	y0 = cam.yaw
	_drag(cam, mid, b)
	_check("set to pan, a plain drag grabs the map", held.distance_to(cam.ground_point(b)) < 0.5 and absf(cam.yaw - y0) < 0.001, "drift %.2f m" % held.distance_to(cam.ground_point(b)))
	# grabbed up by the horizon, a short drag moves the map a short way, not hundreds of metres
	cam.tilt = RtsCamera.TILT_MAX
	cam.target_dist = 40.0
	cam.dist = 40.0
	cam._apply()
	f0 = cam.focus_pos
	_drag(cam, Vector2(mid.x, 4), Vector2(mid.x, 34))
	_check("a grab out by the horizon doesn't lurch", f0.distance_to(cam.focus_pos) < 4.0 and f0.distance_to(cam.focus_pos) > 0.1, "%.2f m for 30 px" % f0.distance_to(cam.focus_pos))
	cam.tilt = 0.0
	Settings.v["mmb_mode"] = 0

	# Backspace: back to the starting heading, the tilt level
	cam.reset_view()
	await _settle(cam)
	_check("reset turns back to the start", absf(wrapf(cam.yaw - cam.home_yaw, -PI, PI)) < 0.01 and absf(cam.tilt) < 0.01, "heading off by %.3f rad" % wrapf(cam.yaw - cam.home_yaw, -PI, PI))

	# Ctrl+F5 saves a view, F5 goes back to it
	cam.bookmark(5, true)
	var saved := cam.focus_pos
	var saved_dist := cam.target_dist
	cam.focus(saved + Vector3(200, 0, 0))
	cam.target_dist = 150.0
	cam.bookmark(5, false)
	await _settle(cam)
	_check("F5 goes back to the saved view", cam.focus_pos.distance_to(saved) < 0.5 and absf(cam.target_dist - saved_dist) < 0.01)

	# jumps glide: part way there after a moment, there in the end
	var to := saved + Vector3(-150, 0, 80)
	cam.glide_to(to)
	await _wait(0.12)
	var part := cam.focus_pos
	await _settle(cam)
	_check("a jump glides there", part.distance_to(saved) > 1.0 and part.distance_to(to) > 1.0 and cam.focus_pos.distance_to(to) < 0.5, "%.0f m along after 0.12 s" % part.distance_to(saved))

	# Ctrl+F: the camera keeps the selection in the middle until told to stop
	world.input.clear_selection()
	for s in world.soldiers:
		if s.owner_peer == world.local_peer and s.sid != 0 and s.life == Soldier.Life.ALIVE:
			world.input.sel_squads.append(s.sid)
			break
	cam.toggle_follow()
	await _wait(3.0)
	var c := world.input.selection_centre()
	_check("following keeps the selection in view", cam.follow and c != Vector3.INF and cam.focus_pos.distance_to(c) < 6.0, "%.1f m off" % cam.focus_pos.distance_to(c))
	cam.toggle_follow()
	_check("Ctrl+F again stops following", not cam.follow)

	# the turning minimap: a point maps back to the same ground, and the camera's heading is up
	var mm := world.hud.minimap
	Settings.v["minimap_rotate"] = true
	cam.yaw = 0.7
	mm._update_xf()
	var p := Vector3(123, 0, -77)
	_check("the turned minimap maps back to the same ground", mm._to_world(mm._pt(p)).distance_to(p) < 0.5)
	var up := mm._pt(cam.focus_pos + Vector3(-sin(cam.yaw), 0, -cos(cam.yaw)) * 50.0) - mm._pt(cam.focus_pos)
	_check("the turned minimap puts the view's heading up", up.normalized().dot(Vector2(0, -1)) > 0.99, str(up.normalized()))
	Settings.v["minimap_rotate"] = false

	print("CAMTEST %d/%d passed (%d fps)" % [_n - _fails, _n, Engine.get_frames_per_second()])
	get_tree().quit()
