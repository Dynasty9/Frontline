extends "res://tests/mocap/viewer.gd"
## A collision-driven third-person test of the shared animation controller.
var body: CharacterBody3D
var driver: RefCounted
var crouching := false
var requested_jump := false
var controller_test := false
var checks := {}
var peak := 0.0
var max_ground := 0.0
var foot_penetration := 0.0
var jump_clearance := 0.0
var previous_interpolation := false

func _ready() -> void:
	previous_interpolation = get_tree().physics_interpolation
	get_tree().physics_interpolation = true
	super._ready()
	if soldier.native_player == null:
		push_error("Install the local Mixamo rifle clips before launching the controller.")
		get_tree().quit(1)
		return
	controller_test = "--controller-test" in OS.get_cmdline_user_args()
	driver = load("res://scripts/game/rifle_animation_controller.gd").new()
	driver.setup(soldier)
	for node in get_children():
		if node is StaticBody3D and node.position.y < 0.0:
			remove_child(node)
			node.queue_free()
		if node is StaticBody3D and node.position.z > 2.0:
			node.position = Vector3(4, 1.25, -3)
	var terrain: Node3D = load("res://tests/mocap/controller_terrain.gd").new()
	add_child(terrain)
	soldier.ground_height = _floor_height
	soldier.ground_normal = _floor_normal
	body = CharacterBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 1
	body.floor_snap_length = 0.35
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	add_child(body)
	soldier.reparent(body)
	for node in get_children():
		if node is CanvasLayer: node.queue_free()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 20)
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_label(column, "  FRONTLINE / PLAYABLE MOTION LAB  ", 23)
	_label(column, "  WASD Move · Shift Run · Space Jump · C / Ctrl Crouch  ", 16)
	_label(column, "  R Reload · Home Reset · Right-drag Camera · Wheel Zoom  ", 16)
	_label(column, "  Left-click character: projectile / ragdoll test  ", 16)
	_label(column, "  Follow the dirt track uphill; grass banks test uneven footing  ", 16)
	status = _label(column, "", 18)
	mode = OptionButton.new()
	for label in ["Hit reaction", "Lethal ragdoll", "Heavy impact"]: mode.add_item(label)
	column.add_child(mode)
	var back := Button.new()
	back.text = "Back to animation viewer"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://tests/mocap/viewer.tscn"))
	column.add_child(back)
	_build_inspection_ui()
	_refresh_inspector()
	yaw = 2.8
	distance = 5.2
	elevation = 0.35
	_update_camera()
	body.reset_physics_interpolation()
	camera.reset_physics_interpolation()
	print("CONTROLLER ready")

func _exit_tree() -> void:
	get_tree().physics_interpolation = previous_interpolation

func _input(event: InputEvent) -> void:
	if controller_test:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed: orbiting = false

func _unhandled_input(event: InputEvent) -> void:
	var action := Keys.action_for(event, ["motion_jump", "motion_crouch", "motion_reload", "motion_reset"]) if event.is_pressed() and not event.is_echo() else ""
	match action:
		"motion_jump": requested_jump = true
		"motion_crouch": crouching = not crouching
		"motion_reload": driver.request_action("reloading")
		"motion_reset": _reset_controller()
	if action != "": get_viewport().set_input_as_handled()
	else: super._unhandled_input(event)

func _reset_controller() -> void:
	if soldier.dead: soldier.revive()
	body.position = Vector3.ZERO
	body.position.y = _floor_height(Vector3.ZERO) + 0.02
	body.velocity = Vector3.ZERO
	soldier.position = Vector3.ZERO
	soldier.reset_motion()
	driver.reset()
	crouching = false
	body.reset_physics_interpolation()
	_update_camera()
	camera.reset_physics_interpolation()

func _physics_process(dt: float) -> void:
	if body == null: return
	time += dt
	if body.position.y < -6.0: _reset_controller()
	var input := Vector2(float(Keys.held("cam_right")) - float(Keys.held("cam_left")), float(Keys.held("cam_down")) - float(Keys.held("cam_up"))).limit_length()
	var running := Keys.held("cam_fast")
	if controller_test:
		input = _test_input()
		running = (time >= 2.5 and time < 4.5) or (time >= 8.5 and time < 12.0)
	var speed := 1.0 if crouching else (3.4 if running else 1.4)
	var heading := PI - yaw
	if not soldier.dead: body.rotation.y = lerp_angle(body.rotation.y, heading, 1.0 - exp(-12.0 * dt))
	var desired := Basis(Vector3.UP, heading) * Vector3(input.x, 0, input.y) * speed
	# Movement is relative to the camera; A/D remain rifle-facing strafes.
	body.velocity.x = move_toward(body.velocity.x, desired.x, dt * 7.0)
	body.velocity.z = move_toward(body.velocity.z, desired.z, dt * 7.0)
	if soldier.dead:
		body.velocity.x = 0.0
		body.velocity.z = 0.0
	if requested_jump:
		if body.is_on_floor() and not crouching and driver.request_action("rifle_jump"):
			body.velocity.y = 4.2
		requested_jump = false
	if not body.is_on_floor(): body.velocity.y -= dt * 12.0
	var collision: CollisionShape3D = body.get_child(0)
	var capsule: CapsuleShape3D = collision.shape
	capsule.height = move_toward(capsule.height, 1.3 if crouching else 1.8, dt * 3.0)
	collision.position.y = capsule.height * 0.5
	body.move_and_slide()
	soldier.ground_y = body.global_position.y
	peak = maxf(peak, body.position.y)
	driver.advance(dt, soldier.global_basis.inverse() * body.velocity, crouching, body.is_on_floor())
	soldier.capture_motion(dt)
	if controller_test and not soldier.dead:
		var floor_y := _floor_height(body.global_position)
		if body.is_on_floor(): max_ground = maxf(max_ground, floor_y)
		if time > 10.0 and time < 12.0 and body.is_on_floor() and floor_y < 0.2: checks.descended = true
		if driver.action == "rifle_jump": jump_clearance = maxf(jump_clearance, body.position.y - floor_y)
		if body.is_on_floor() and driver.action != "rifle_jump":
			for prefix in ["Left", "Right"]:
				var ankle := soldier.joint(prefix + "Foot").origin
				var sole_y: float = ankle.y - soldier.target_rest[int(soldier.bones[prefix + "Foot"])].origin.y
				foot_penetration = maxf(foot_penetration, _floor_height(ankle) - sole_y)
		if driver.action == "reloading" and driver.action_time > 0.75 and driver.action_time < 1.05:
			checks.stowed = not soldier.magazine.mesh.visible
		if driver.action == "reloading" and driver.action_time > 1.2:
			checks.replacement = soldier.magazine.mesh.visible
	for area in targets:
		area.collision_layer = 0 if soldier.dead else 4
		if soldier.dead: continue
		var a := soldier.joint(area.get_meta("bone")).origin
		var end: String = area.get_meta("end")
		var b := soldier.joint(end).origin if soldier.bones.has(end) else a + Vector3.UP * 0.22
		area.global_position = (a + b) * 0.5
		area.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		area.get_child(0).shape.height = maxf(a.distance_to(b), area.get_child(0).shape.radius * 2.0)
	_step_projectiles(dt)
	status.text = "  %s · %.1f m/s" % [driver.state, Vector2(body.velocity.x, body.velocity.z).length()]
	_update_camera()
	if controller_test and time > 16.0 and not checks.has("impact"):
		checks.impact = true
		mode.select(1)
		_shoot(camera.unproject_position(soldier.joint("Spine2").origin))
	if controller_test and time > 17.0 and not checks.has("reset"):
		checks.reset = soldier.dead
		_reset_controller()
	if controller_test and time > 18.0:
		if driver.jump_count != 1 or driver.reload_count != 1 or peak < 0.5 or not body.is_on_floor() or not checks.get("reset", false) or max_ground < 0.8 or jump_clearance < 0.4 or foot_penetration > 0.02 or driver.max_contact_change > 0.12 or not checks.get("descended", false) or not checks.get("stowed", false) or not checks.get("replacement", false):
			push_error("Controller checks failed: height=%s feet=%s jump=%s contact_change=%s at=%s checks=%s" % [max_ground, foot_penetration, jump_clearance, driver.max_contact_change, driver.worst_contact_time, checks])
			get_tree().quit(1)
		else:
			print("CONTROLLER PASS jump=", driver.jump_count, " reload=", driver.reload_count, " peak=", peak, " landed=true ragdoll=true reset=true ground=", max_ground, " foot_penetration=", foot_penetration, " contact_change=", driver.max_contact_change, " at=", driver.worst_contact_time, " stowed=true replacement=true")
			get_tree().quit()

func _test_input() -> Vector2:
	if time < 1.0: return Vector2.ZERO
	if time < 4.5: return Vector2(0, -1)
	if time < 5.5: return Vector2(1, -1).normalized()
	if time < 6.5:
		if not checks.has("jump"):
			_test_key("motion_jump")
			checks.jump = true
		return Vector2(-1, 0)
	if time < 8.5:
		if not checks.has("crouch"):
			_test_key("motion_crouch")
			checks.crouch = true
		return Vector2(0, 1)
	crouching = false
	if time < 12.0: return Vector2(0, 1)
	if not checks.has("reload"):
		_test_key("motion_reload")
		checks.reload = true
	return Vector2.ZERO

func _update_camera() -> void:
	if body == null:
		super._update_camera()
		return
	var focus := body.global_position + Vector3(0, 1.0, 0)
	camera.position = focus + Vector3(sin(yaw), elevation, -cos(yaw)).normalized() * distance
	var query := PhysicsRayQueryParameters3D.create(focus, camera.position, 1)
	var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty(): camera.position = obstruction.position + obstruction.normal * 0.2
	camera.look_at(focus)
	camera.h_offset = -0.35

func _test_key(action: String) -> void:
	var event := InputEventKey.new()
	event.keycode = Keys.binds[action][0]
	event.pressed = true
	_unhandled_input(event)
	event.pressed = false
	_unhandled_input(event)

func _floor_hit(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point - Vector3.UP * 4.0, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _floor_height(point: Vector3) -> float:
	var hit := _floor_hit(point)
	return hit.position.y if not hit.is_empty() else point.y

func _floor_normal(point: Vector3) -> Vector3:
	var hit := _floor_hit(point)
	return hit.normal if not hit.is_empty() else Vector3.UP
