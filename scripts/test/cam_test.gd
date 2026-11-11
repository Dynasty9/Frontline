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
		TestRun.fail()
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


## Two fingers scrolling on a trackpad (`delta` as a Mac gives it: the way the view moves).
func _pan(at: Vector2, delta: Vector2, alt := false, shift := false) -> InputEventPanGesture:
	var e := InputEventPanGesture.new()
	e.position = at
	e.delta = delta
	e.alt_pressed = alt
	e.shift_pressed = shift
	return e


func _pinch(at: Vector2, factor: float) -> InputEventMagnifyGesture:
	var e := InputEventMagnifyGesture.new()
	e.position = at
	e.factor = factor
	return e


func _drag(cam: RtsCamera, a: Vector2, b: Vector2, alt := false) -> void:
	cam._unhandled_input(_mb(MOUSE_BUTTON_MIDDLE, true, a, alt))
	cam._unhandled_input(_mm(b, b - a))
	cam._unhandled_input(_mb(MOUSE_BUTTON_MIDDLE, false, b, alt))


func _run() -> void:
	await _wait(1.5)
	var cam := world.cam
	# An embedded window can report the pointer parked at its top-left corner.
	cam.edge_pan = false
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

	# a Mac's trackpad: two fingers grab the map, the spot in the middle of the
	# screen going where they go (the other way to the scroll's delta)
	cam.target_dist = 70.0
	cam.dist = 70.0
	cam._apply()
	Settings.v["scroll_mode"] = 0
	var px := RtsCamera.TRACKPAD_PT * DisplayServer.screen_get_scale()
	held = cam.ground_point(mid)
	y0 = cam.yaw
	cam._unhandled_input(_pan(mid, Vector2(3, -2)))
	var under := mid - Vector2(3, -2) * px
	_check("two fingers grab the map", held.distance_to(cam.ground_point(under)) < 0.5 and absf(cam.yaw - y0) < 0.001, "drift %.2f m" % held.distance_to(cam.ground_point(under)))
	# ... with Option they turn and tilt, as a middle drag does
	y0 = cam.yaw
	t0 = cam.tilt
	f0 = cam.focus_pos
	cam._unhandled_input(_pan(mid, Vector2(-1, 0.5), true))
	var want_tilt := clampf(t0 + 0.5 * px * 0.15, RtsCamera.TILT_MIN, RtsCamera.TILT_MAX)
	_check("Option and two fingers turn and tilt", absf(cam.yaw - (y0 - px * 0.006)) < 0.01 and absf(cam.tilt - want_tilt) < 0.01 and f0.distance_to(cam.focus_pos) < 0.01,
		"turned %.2f rad, tilted %.1f deg" % [cam.yaw - y0, cam.tilt - t0])
	cam.tilt = 0.0
	cam._apply()
	# ... with Shift they're left to whatever is being placed
	f0 = cam.focus_pos
	var d0 := cam.target_dist
	cam._unhandled_input(_pan(mid, Vector2(2, 2), false, true))
	_check("Shift and two fingers leave the camera alone", f0.distance_to(cam.focus_pos) < 0.01 and absf(cam.target_dist - d0) < 0.01)
	# set to zoom, scrolling down zooms out, like the wheel turned toward you
	Settings.v["scroll_mode"] = 1
	cam._unhandled_input(_pan(mid, Vector2(0, 3)))
	_check("set to zoom, two fingers zoom", cam.target_dist > d0 * 1.1 and f0.distance_to(cam.focus_pos) < 0.01, "%.0f m to %.0f m" % [d0, cam.target_dist])
	Settings.v["scroll_mode"] = 0
	await _settle(cam)
	# a pinch zooms toward the spot between the fingers, which stays under them
	g0 = cam.ground_point(sp)
	d0 = cam.dist
	for i in 6:
		cam._unhandled_input(_pinch(sp, 1.08))
	await _settle(cam)
	_check("a pinch zooms in toward the fingers", g0.distance_to(cam.ground_point(sp)) < 1.5 and cam.dist < d0 * 0.75, "drift %.2f m, zoom %.0f m to %.0f m" % [g0.distance_to(cam.ground_point(sp)), d0, cam.dist])

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

	# Use the same input dispatch as a player, including Escape before deselection.
	var actor: Soldier = world.input.selected_soldiers()[0]
	world.input.select_unit(actor)
	var mount_key := InputEventKey.new()
	mount_key.keycode = KEY_F9
	mount_key.pressed = true
	world.input._key(mount_key)
	_check("an individual has a rear camera", cam.mount_label == &"Behind" and cam.mount_subject == actor)
	world.input._key(mount_key)
	_check("cycle to the aerial mount", cam.mount_label == &"Aerial" and cam.cam.global_position.is_equal_approx(cam.mount_marker.global_position))
	world.input._key(mount_key)
	_check("cycle returns to the commander", cam.mount_label == &"" and cam.cam.rotation.is_zero_approx())
	world.input._key(mount_key)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	world.input._key(escape)
	_check("Escape leaves the mount and keeps the unit selected", cam.mount_label == &"" and world.input.sel_unit == actor.eid)
	world.input._key(mount_key)
	world.input.clear_selection()
	cam._apply()
	_check("a changed selection releases the mount", cam.mount_label == &"")

	# A wheeled vehicle advertises its own running gear and drops the camera on despawn.
	var truck := world.spawn("vehicle", {"vkind": "humvee", "team": actor.team, "pos": actor.position + Vector3(4, 0, 4)}) as Vehicle
	world.input.sel_vehicles.append(truck.eid)
	world.input._key(mount_key)
	var truck_mounts := truck.camera_mounts()
	_check("wheeled vehicle exposes wheels and hides absent mounts", cam.mount_subject == truck and truck_mounts.has(&"Wheels") and not truck_mounts.has(&"Tracks") and not truck_mounts.has(&"Barrel"))
	# A wheel camera can follow the same vehicle on a road or on a sling.
	truck.position.y = world.ground_y(truck.position)
	truck._last_pos = truck.position - Vector3.RIGHT
	truck._view_process(1.0 / 30.0)
	_check("moving wheels on the ground emit dust", truck.dust != null and Vfx.is_emitting(truck.dust))
	var wheel_angle: float = truck.wheels[0].rotation.x
	truck.position += Defs.dir_of(truck.rotation.y) * 0.35 + Vector3.UP * 6.0
	truck._view_process(1.0 / 30.0)
	_check("a lifted vehicle stops shedding wheel dust", truck.dust != null and not Vfx.is_emitting(truck.dust))
	_check("carried wheels stay still", is_equal_approx(truck.wheels[0].rotation.x, wheel_angle))
	for _i in 45:
		truck._suspension(1.0 / 30.0, false)
	_check("airborne suspension settles without following the ground below", absf(truck._sus.z) < 0.01)
	truck.hide()
	cam._apply()
	_check("a hidden subject releases the camera", cam.mount_label == &"")
	truck.show()
	world.input._key(mount_key)
	world.despawn(truck)
	cam._apply()
	_check("despawning releases the object camera", cam.mount_label == &"")
	world.input.clear_selection()

	for fixture in [["heli", &"Cabin side"], ["rhib", &"Bow"], ["rhib", &"Waterline"], ["speedboat_hmg", &"Stern quarter"], ["patrol_ship", &"Stern quarter"], ["patrol_ship", &"Bridge roof"], ["mohawk", &"Sling load"], ["mohawk", &"Cargo door"], ["taru_lift", &"Cargo door"], ["rhib", &"Starboard"], ["rhib", &"Helm"], ["tank", &"Periscope"], ["old_tank", &"Periscope"]]:
		var vehicle := world.spawn("vehicle", {"vkind": fixture[0], "team": actor.team, "pos": actor.position}) as Vehicle
		_check("%s has its own exterior camera" % fixture[0], vehicle.camera_mounts().has(fixture[1]))
		if fixture[1] == &"Helm":
			var helm := vehicle.model.get_node_or_null("Coxswain")
			_check("the RHIB has a seated helmsman", helm != null and helm.get_child_count() > 0 and helm.get_child(0) is MeshInstance3D)
		if fixture[1] in [&"Waterline", &"Stern quarter", &"Sling load"]:
			world.input.sel_vehicles.append(vehicle.eid)
			vehicle.model.rotation.z = 0.32
			cam.cycle_mount(fixture[1])
			var view := cam.cam.global_basis
			var marker: Marker3D = vehicle.camera_mounts()[fixture[1]]
			_check("%s keeps the horizon level while the vehicle banks" % fixture[1], is_zero_approx(view.x.y) and view.z.is_equal_approx(marker.global_basis.orthonormalized().z))
			cam.leave_mount()
			world.input.clear_selection()
		if fixture[1] == &"Sling load":
			var load_vehicle := world.spawn("vehicle", {"vkind": "nyx_at", "team": actor.team, "pos": vehicle.position}) as Vehicle
			load_vehicle.position += Vector3(1, -8, 2)
			vehicle.sling_eid = load_vehicle.eid
			vehicle._sling_view()
			var spans := vehicle._cables.multimesh
			var cable := spans.get_instance_transform(0)
			var cable_top := vehicle.to_global(cable * (Vector3.DOWN * 0.5))
			_check("the cable stays against the banking fuselage", cable_top.distance_to(vehicle.model.to_global(vehicle._vm.sling_eye)) < 0.002)
			var joined := true
			for i in range(1, 5):
				var strap := spans.get_instance_transform(i)
				var foot := load_vehicle.model.to_local(vehicle.to_global(strap * (Vector3.UP * 0.5)))
				joined = joined and foot.y > 0.0 and foot.y < 1.2 and absf(foot.x) < 0.91 and absf(foot.z) < 1.77
			_check("all four strap ends reach the Nyx body", joined)
			world.despawn(load_vehicle)
			vehicle._sling_view()
			_check("a released load clears the entire sling", not vehicle._cables.visible)

		if fixture[1] == &"Periscope":
			world.input.sel_vehicles.append(vehicle.eid)
			for _i in vehicle.camera_mounts().size():
				world.input._key(mount_key)
				if cam.mount_label == &"Periscope":
					break
			_check("periscope frames the turret view", cam.mount_label == &"Periscope" and cam._eyepiece.visible and cam.cam.global_transform.is_equal_approx(cam.mount_marker.global_transform.orthonormalized()))
			world.input._key(escape)
			if fixture[0] == "tank":
				var belt = vehicle._vm.belts[0]
				var phase: float = belt.phase
				vehicle.position.y += 8.0
				vehicle._belt_origin = (vehicle.global_transform * vehicle.ip_offset()).origin + Vector3(0, 0, 0.45)
				vehicle.always_animate_tracks = true
				vehicle._view_process(1.0 / 30.0)
				_check("airborne tracks hold their phase and leave no prints", is_equal_approx(belt.phase, phase) and belt.printed_end == -1)
			_check("leaving the periscope restores the commander lens", not cam._eyepiece.visible and cam.cam.fov == float(Settings.get_v("fov")))
			world.input.clear_selection()
		world.despawn(vehicle)

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
	TestRun.quit(get_tree())
