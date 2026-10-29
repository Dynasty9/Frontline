extends "res://tests/mocap/controller.gd"
## Play the shared gameplay poses on collision terrain; inspect source clips separately.
var proxy: SoldierModel
var prone := false
var working := false
var firing := false
var activity := -1
var activity_left := 0.0
var actions: OptionButton
var shot_delay := 0.0

func _ready() -> void:
	super._ready()
	if not ready_to_run: return
	DisplayServer.window_set_title("Frontline Character Playground")
	for node in get_children():
		if node is WorldEnvironment:
			var sky := Sky.new()
			sky.sky_material = ProceduralSkyMaterial.new()
			node.environment.sky = sky
			node.environment.background_mode = Environment.BG_SKY
	proxy = SoldierModel.new()
	body.add_child(proxy)
	proxy.build("rifleman", 0, 4)
	soldier.bind_procedural(proxy)
	proxy.root.hide()
	proxy.skinned = soldier
	proxy.rifle_driver = driver
	for node in get_children():
		if node is CanvasLayer: node.queue_free()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_label(column, " FRONTLINE / CHARACTER PLAYGROUND ", 23)
	_label(column, "WASD move · Shift run · Space jump · C crouch · Z prone", 16)
	_label(column, "Hold left mouse: fire · R reload · F work / stop · G throw", 16)
	_label(column, " · H hit / ragdoll · Home reset", 16)
	_label(column, "Right-drag orbit · Wheel zoom · Moving cancels work", 16)
	_label(column, "Track, slopes and rough grass share render/collision geometry.", 14)
	status = _label(column, "", 16)
	actions = OptionButton.new()
	actions.add_item("Automatic gameplay controls", -1)
	for key in Soldier.Act: actions.add_item(key.capitalize().replace("_", " "), Soldier.Act[key])
	actions.item_selected.connect(func(index: int):
		activity = actions.get_item_id(index) if index > 0 else -1
		activity_left = INF
		working = false)
	column.add_child(actions)
	_label(column, "Action dropdown: pose previews; vehicles/partners are not simulated.", 12)
	mode = OptionButton.new()
	for label in ["H: Hit reaction", "H: Lethal ragdoll", "H: Heavy impact"]: mode.add_item(label)
	column.add_child(mode)
	var review := Button.new()
	review.text = "All source clips + gameplay cases / comments and approvals"
	review.pressed.connect(func(): get_tree().change_scene_to_file("res://tests/mocap/review.tscn"))
	column.add_child(review)
	_build_inspection_ui()
	_refresh_inspector()
	_surface(Vector3(-4, 0.4, 1), Vector3(3, 0.8, 0.4), Color("777265"))
	_surface(Vector3(-6, 0.65, -3), Vector3(1.4, 1.3, 1.4), Color("666347"))
	_reset_controller()
	if "--playground-test" in OS.get_cmdline_user_args(): call_deferred("_playground_test")
	print("PLAYGROUND ready")

func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		firing = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		firing = event.pressed
		if firing:
			_automatic()
			working = false
		get_viewport().set_input_as_handled()
		return
	var key := Keys.action_for(event, ["motion_work", "motion_prone", "motion_grenade", "motion_impact", "motion_reload"]) if event.is_pressed() and not event.is_echo() else ""
	match key:
		"motion_work":
			_automatic()
			working = not working
			if working:
				prone = false
				crouching = false
		"motion_prone":
			_automatic()
			prone = not prone
			crouching = prone
		"motion_grenade":
			activity = Soldier.Act.THROW
			activity_left = 1.2
		"motion_reload":
			activity = Soldier.Act.RELOAD
			activity_left = 2.3
		"motion_impact": _shoot(camera.unproject_position(soldier.joint("Spine2").origin))
	if key != "": get_viewport().set_input_as_handled()
	else:
		if event.is_pressed() and Keys.action_for(event, ["motion_crouch"]) != "": prone = false
		super._unhandled_input(event)

func _automatic() -> void:
	activity = -1
	if actions != null: actions.select(0)

func _reset_controller() -> void:
	super._reset_controller()
	prone = false
	working = false
	firing = false
	_automatic()
	if proxy != null:
		proxy.last_act = -1
		proxy.act_time = 0.0

func _movement_speed(running: bool) -> float:
	return 0.45 if prone else super._movement_speed(running)

func _animate_character(dt: float) -> void:
	if proxy == null or soldier.dead: return
	if driver.action == "rifle_jump" or not body.is_on_floor():
		super._animate_character(dt)
		return
	var velocity := soldier.global_basis.inverse() * body.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.15: working = false
	var posture := Soldier.Post.PRONE if prone else (Soldier.Post.CROUCH if crouching else Soldier.Post.STAND)
	var act := Soldier.Act.IDLE
	if speed > 0.1: act = Soldier.Act.CRAWL if prone else (Soldier.Act.RUN if speed > 2.0 else Soldier.Act.WALK)
	if firing: act = Soldier.Act.SHOOT
	if working: act = Soldier.Act.BUILD
	if activity >= 0:
		act = activity
		activity_left -= dt
		if activity_left <= 0.0: _automatic()
	proxy.move_yaw = atan2(-velocity.x, -velocity.z) if speed > 0.1 else 0.0
	proxy.pose(dt, Soldier.Life.ALIVE, posture, act, speed, velocity.z > 0.1, firing)
	shot_delay -= dt
	if firing and shot_delay <= 0.0 and not soldier.weapon_stowed:
		soldier.fire_kick(0.8)
		_fire_trace()
		shot_delay = 0.12
	driver.state = Soldier.Act.keys()[act] + (" / prone" if prone else "")

func _fire_trace() -> void:
	var muzzle := soldier.weapon.global_transform * Vector3(0, 0.03, 0.6)
	var end := muzzle + soldier.weapon.global_basis.z * 18.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, end, 1))
	if not hit.is_empty(): end = hit.position
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.012, maxf(0.01, muzzle.distance_to(end)))
	tracer.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0.8, 0.35)
	tracer.material_override = material
	add_child(tracer)
	tracer.global_position = (muzzle + end) * 0.5
	if muzzle.distance_to(end) > 0.01: tracer.look_at(end)
	get_tree().create_timer(0.045).timeout.connect(tracer.queue_free)

func _playground_test() -> void:
	await get_tree().create_timer(0.5).timeout
	var start := body.position
	var move := InputEventKey.new()
	move.keycode = Keys.binds["cam_up"][0]
	move.physical_keycode = move.keycode
	move.pressed = true
	Input.parse_input_event(move)
	await get_tree().create_timer(0.8).timeout
	assert(body.position.distance_to(start) > 0.4 and proxy.last_act == Soldier.Act.WALK)
	move.pressed = false
	Input.parse_input_event(move)
	await get_tree().create_timer(0.4).timeout
	_test_key("motion_jump")
	await get_tree().create_timer(0.2).timeout
	assert(not body.is_on_floor() and driver.action == "rifle_jump")
	await get_tree().create_timer(1.0).timeout
	_test_key("motion_work")
	await get_tree().create_timer(1.2).timeout
	assert(working and soldier.weapon_stowed and proxy.last_act == Soldier.Act.BUILD)
	_test_key("motion_work")
	_test_key("motion_prone")
	await get_tree().create_timer(1.2).timeout
	assert(prone and proxy.last_act == Soldier.Act.IDLE)
	_test_key("motion_reload")
	await get_tree().create_timer(0.5).timeout
	assert(proxy.last_act == Soldier.Act.RELOAD)
	firing = true
	await get_tree().create_timer(0.5).timeout
	_reset_controller()
	assert(not prone and not working and not soldier.dead)
	assert(actions.item_count == Soldier.Act.size() + 1 and clip_keys.size() > 100)
	print("PLAYGROUND PASS work, prone, reload, reset and complete action catalog")
	get_tree().quit()

func _collision_height() -> float:
	return 0.6 if prone else super._collision_height()
