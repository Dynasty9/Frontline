extends "res://tests/mocap/skinned_demo.gd"
## Local asset inspection: animation playback and swept projectile impacts.

var clip_keys: Array[String] = []
var clip_paths := {}
var picker: ItemList
var timeline: HSlider
var speed_slider: HSlider
var status: Label
var clock_label: Label
var mode: OptionButton
var playing := true
var selected := "idle"
var updating_timeline := false
var targets: Array[Area3D] = []
var projectiles: Array[Dictionary] = []
var yaw := 0.45
var elevation := 0.18
var distance := 5.5
var orbiting := false
var hit_count := 0
var death_count := 0
var test_mode := false
var test_step := 0
var preview_source := false
var source_toggle: CheckButton
var contact_toggle: CheckButton
var inspector: Node3D
var model_stats: Label
var bone_picker: OptionButton
var inspection_mode: OptionButton
var bones_toggle: CheckButton
var names_toggle: CheckButton
var catalog_index := -1
var catalog_until := 0.0

func _animation_clips() -> Dictionary:
	if "--swat-units" in OS.get_cmdline_user_args(): return MocapCharacter.MIXAMO_CLIPS
	var clips := MocapCharacter.CLIPS.duplicate()
	_scan(MocapCharacter.BASE + "Animation/Rifle/Animation", clips)
	_scan(MocapCharacter.BASE + "Animation/Mobility", clips)
	return clips

func _scan(path: String, clips: Dictionary) -> void:
	for directory in DirAccess.get_directories_at(path):
		_scan(path.path_join(directory), clips)
	for file in DirAccess.get_files_at(path):
		if not file.ends_with(".fbx"): continue
		var relative := path.path_join(file).trim_prefix(MocapCharacter.BASE)
		var key := file.get_basename()
		clips[key] = relative
		clip_paths[key] = relative

func _ready() -> void:
	RenderingServer.set_debug_generate_wireframes(true)
	super._ready()
	if not ready_to_run: return
	for node in get_children():
		if node is CanvasLayer: node.queue_free()
	for arg in OS.get_cmdline_user_args():
		if arg == "--viewer-test": test_mode = true
		if arg in ["--source-preview", "--source-model"]: preview_source = true
	_surface(Vector3(0, 1.25, 2.1), Vector3(4, 2.5, 0.25), Color("424e5c"))
	for part in SkinnedRagdoll.PARTS:
		var area := Area3D.new()
		area.collision_layer = 4
		area.collision_mask = 0
		area.set_meta("bone", part[0])
		area.set_meta("end", part[2])
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = part[4]
		shape.shape = capsule
		area.add_child(shape)
		add_child(area)
		targets.append(area)
	if ResourceLoader.exists("res://assets/local_mocap/mixamo/basic_shooter/rifle aiming idle.fbx"):
		soldier.pose(0.0, 0.0, "idle")
		var mixamo: Dictionary = load("res://scripts/game/mixamo_clips.gd").install(soldier)
		clip_paths.merge(mixamo)
	inspector = load("res://tests/mocap/inspection_overlay.gd").new()
	add_child(inspector)
	_build_ui()
	_build_inspection_ui()
	_update_camera()
	_select_clip(clip_keys.find("mixamo_basic_shooter__rifle_aiming_idle" if "--swat-units" in OS.get_cmdline_user_args() else "W2_Stand_Aim_Idle_v2"))
	if "--record-catalog" in OS.get_cmdline_user_args():
		_catalog_next()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-clip="):
			_select_clip(clip_keys.find(arg.trim_prefix("--preview-clip=")))
	if "--inspection-preview" in OS.get_cmdline_user_args() or "--inspect-model" in OS.get_cmdline_user_args():
		bones_toggle.button_pressed = true
		inspection_mode.select(1)
		inspector.apply_mesh_mode(1)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--inspection-mode="):
			var selected_mode := clampi(int(arg.trim_prefix("--inspection-mode=")), 0, 3)
			inspection_mode.select(selected_mode)
			inspector.apply_mesh_mode(selected_mode)
		if arg == "--bone-names": names_toggle.button_pressed = true
		if arg == "--no-bones": bones_toggle.button_pressed = false
	print("VIEWER ready clips=", clip_keys.size())

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 20
	panel.offset_top = 20
	panel.offset_right = 350
	panel.offset_bottom = -20
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	_label(column, "FRONTLINE / MOTION LAB", 22)
	_label(column, "Click the character to shoot.\nRight-drag to orbit / Wheel to zoom", 15)
	_label(column, "AVAILABLE SAMPLE CLIPS", 14)
	if soldier.native_player != null:
		var control := Button.new()
		control.text = "Play character â€” movement / jump / reload"
		control.pressed.connect(func(): get_tree().change_scene_to_file("res://tests/mocap/controller.tscn"))
		column.add_child(control)
	picker = ItemList.new()
	picker.custom_minimum_size = Vector2(290, 220)
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker.add_theme_font_size_override("font_size", 14)
	clip_keys.assign(clip_paths.keys())
	clip_keys.sort()
	for key in clip_keys:
		picker.add_item(key.trim_prefix("W2_").trim_prefix("MOB1_").replace("_", " "))
		picker.set_item_tooltip(picker.item_count - 1, clip_paths[key])
	column.add_child(picker)
	picker.item_selected.connect(_select_clip)
	var pause := Button.new()
	pause.text = "Pause / Resume"
	pause.pressed.connect(func(): playing = not playing)
	column.add_child(pause)
	clock_label = _label(column, "", 14)
	timeline = HSlider.new()
	timeline.step = 0.001
	timeline.value_changed.connect(_scrub)
	column.add_child(timeline)
	_label(column, "Playback speed (0.1x - 2x)", 14)
	speed_slider = HSlider.new()
	speed_slider.min_value = 0.1
	speed_slider.max_value = 2.0
	speed_slider.step = 0.1
	speed_slider.value = 1.0
	column.add_child(speed_slider)
	source_toggle = CheckButton.new()
	source_toggle.text = "Original mocap mannequin"
	source_toggle.button_pressed = preview_source
	source_toggle.toggled.connect(func(on: bool):
		preview_source = on
		_reset_actor()
	)
	column.add_child(source_toggle)
	var contacts := CheckButton.new()
	contact_toggle = contacts
	contacts.text = "Foot contact correction"
	contacts.button_pressed = true
	contacts.toggled.connect(func(on: bool): soldier.solve_contacts = on)
	column.add_child(contacts)
	_label(column, "PROJECTILE RESPONSE", 14)
	mode = OptionButton.new()
	mode.add_item("Hit reaction (stay alive)")
	mode.add_item("Fatal shot -> ragdoll")
	mode.add_item("Heavy impact -> wall")
	column.add_child(mode)
	var reset := Button.new()
	reset.text = "Reset character / Replay clip"
	reset.pressed.connect(_reset_actor)
	column.add_child(reset)
	status = _label(column, "Ready", 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(column, "Preview normalizes horizontal root motion.\nMobility clips are unarmed.\nSource mannequin: animation inspection only.", 12)

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _select_clip(index: int) -> void:
	if index < 0: index = 0
	selected = clip_keys[index]
	source_toggle.disabled = _is_native()
	contact_toggle.disabled = _is_native()
	contact_toggle.tooltip_text = "Native Mixamo previews preserve the captured feet." if _is_native() else ""
	if _is_native() and preview_source:
		source_toggle.button_pressed = false
	picker.select(index)
	picker.ensure_current_is_visible()
	_reset_actor()

func _reset_actor() -> void:
	if soldier.dead: soldier.revive()
	soldier.position = Vector3.ZERO
	soldier.rotation = Vector3.ZERO
	soldier.reset_motion()
	for state in soldier.feet: state.locked = false
	soldier.source.tree.active = false
	var player := _active_player()
	player.play(selected, 0.0)
	if _is_native(): soldier._native_clip = selected
	else: soldier.source._clip = selected
	player.seek(0.0, true)
	soldier.hold_weapon = not selected.begins_with("MOB1_") and not selected.begins_with("mixamo_activities__")
	soldier.visual.visible = not preview_source
	soldier.source.visible = preview_source
	if _is_native(): soldier.pose_native(0.0, selected)
	else: soldier.pose(0.0, _clip_speed(), selected)
	soldier.weapon.visible = soldier.hold_weapon
	if preview_source: soldier.source.update_weapon()
	status.text = "Playing: " + selected
	for projectile in projectiles: projectile.mesh.queue_free()
	projectiles.clear()
	_refresh_inspector()

func _scrub(value: float) -> void:
	if updating_timeline or soldier.dead: return
	soldier.capture_motion(0.0)
	playing = false
	_active_player().seek(value, true)
	for state in soldier.feet: state.locked = false
	if _is_native(): soldier.pose_native(0.0, selected)
	else: soldier.pose(0.0, _clip_speed(), selected)

func _clip_speed() -> float:
	if "Jog" in selected: return 3.0
	if "Walk" in selected: return 1.4
	return 0.0

func _physics_process(dt: float) -> void:
	if not ready_to_run or picker == null: return
	time += dt
	var step := dt * speed_slider.value if playing else 0.0
	_pose_preview(step)
	soldier.capture_motion(dt)
	soldier.weapon.visible = soldier.hold_weapon
	if preview_source: soldier.source.update_weapon()
	if not soldier.dead:
		for area in targets:
			area.collision_layer = 0 if preview_source else 4
			var a := soldier.joint(area.get_meta("bone")).origin
			var end: String = area.get_meta("end")
			var b := soldier.joint(end).origin if soldier.bones.has(end) else a + Vector3.UP * 0.22
			area.global_position = (a + b) * 0.5
			area.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
			var capsule: CapsuleShape3D = area.get_child(0).shape
			capsule.height = maxf(a.distance_to(b), capsule.radius * 2.0)
	else:
		for area in targets: area.collision_layer = 0
	_step_projectiles(dt)
	updating_timeline = true
	var animation := _active_player().get_animation(selected)
	timeline.max_value = animation.length
	timeline.value = _active_player().current_animation_position
	clock_label.text = "%.2f / %.2f s     %.1fx" % [timeline.value, animation.length, speed_slider.value]
	updating_timeline = false
	if test_mode: _test_sequence()
	if catalog_index >= 0 and time >= catalog_until:
		_catalog_next()
	if ("--source-preview" in OS.get_cmdline_user_args() or "--inspection-preview" in OS.get_cmdline_user_args()) and time > 3.0: get_tree().quit()

func _pose_preview(step: float) -> void:
	if _is_native(): soldier.pose_native(step, selected)
	else: soldier.pose(step, _clip_speed(), selected)

func _catalog_next() -> void:
	catalog_index += 1
	if catalog_index == clip_keys.size():
		print("CATALOG PASS clips=", catalog_index)
		get_tree().quit()
		return
	_select_clip(catalog_index)
	var seconds := maxf(2.0, _active_player().get_animation(selected).length) + 0.4
	catalog_until = time + seconds
	print("CATALOG %.2f %.2f %s" % [time, catalog_until, selected])
	status.text = "CLIP %d / %d — %s\nIsolated playback; not proof of gameplay routing" % [catalog_index + 1, clip_keys.size(), selected]


func _input(event: InputEvent) -> void:
	# Automated screen-ray tests must not receive clicks intended for another
	# window while they render. Interactive viewer input is unchanged.
	if test_mode:
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		orbiting = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: orbiting = event.pressed
		if not event.pressed: return
		if event.button_index == MOUSE_BUTTON_LEFT: _shoot(event.position)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(2.5, distance - 0.4)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(12.0, distance + 0.4)
		_update_camera()
	elif event is InputEventMouseMotion and orbiting:
		yaw -= event.relative.x * 0.008
		elevation = clampf(elevation + event.relative.y * 0.006, -0.1, 1.1)
		_update_camera()

func _update_camera() -> void:
	var focus := Vector3(0, 0.95, 0)
	camera.position = focus + Vector3(sin(yaw), elevation, -cos(yaw)).normalized() * distance
	camera.look_at(focus)
	camera.h_offset = -0.65

func _shoot(screen: Vector2) -> void:
	if preview_source:
		status.text = "Switch off Original mocap mannequin to test impacts."
		return
	var direction := camera.project_ray_normal(screen)
	var origin := camera.project_ray_origin(screen) + direction * 0.25
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.025
	sphere.height = 0.05
	mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffcd72")
	mesh.material_override = material
	add_child(mesh)
	mesh.global_position = origin
	projectiles.append({"mesh": mesh, "direction": direction, "life": 2.0, "mode": mode.selected})

func _step_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[i]
		var mesh: MeshInstance3D = projectile.mesh
		var next: Vector3 = mesh.global_position + projectile.direction * 32.0 * dt
		var query := PhysicsRayQueryParameters3D.create(mesh.global_position, next, 7)
		query.collide_with_areas = true
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		projectile.life -= dt
		if not result.is_empty():
			_impact(result, projectile.direction, projectile.mode)
		if not result.is_empty() or projectile.life <= 0:
			mesh.queue_free()
			projectiles.remove_at(i)
		else: mesh.global_position = next

func _impact(result: Dictionary, direction: Vector3, response: int) -> void:
	var collider: CollisionObject3D = result.collider
	if collider is Area3D and collider.has_meta("bone") and not soldier.dead:
		hit_count += 1
		status.text = "Hit: " + String(collider.get_meta("bone"))
		soldier.hit(direction, 1.2)
		if response > 0:
			soldier.last_velocity = Vector3.ZERO
			soldier.kill(direction * (5.0 if response == 2 else 0.8) + Vector3.UP * (1.5 if response == 2 else 0.0), 1 if response == 2 else 0)
			death_count += 1
			status.text += " - ragdoll (Reset to replay)"
	elif collider is RigidBody3D:
		collider.apply_impulse(direction * (35.0 if response == 2 else 6.0), result.position - collider.global_position)
		status.text = "Physical impact on ragdoll"
	else:
		status.text = "Miss - projectile hit the environment"

func _test_sequence() -> void:
	# Exercise the same selection, screen-ray and swept-hit paths as the UI.
	if time > 1 and test_step == 0:
		bones_toggle.button_pressed = true
		inspection_mode.select(1)
		inspector.apply_mesh_mode(1)
		for index in clip_keys.size():
			_select_clip(index)
			if _is_native(): soldier.pose_native(0.05, selected)
			else: soldier.pose(0.05, _clip_speed(), selected)
		if soldier.native_player != null:
			_select_clip(clip_keys.find("mixamo_transition__Rifle_Kneel_To_Prone"))
			soldier.native_player.seek(1.9, true)
			soldier._transition_time = soldier._transition_duration
			soldier.pose_native(0.0, selected)
			if soldier.joint("Hips").origin.y > 0.35:
				push_error("Mixamo prone clip is not lowering the body; check take selection")
				get_tree().quit(1)
				return
		_select_clip(clip_keys.find("mixamo_basic_shooter__rifle_aiming_idle" if "--swat-units" in OS.get_cmdline_user_args() else "W2_Stand_Aim_Idle_v2"))
		test_step = 1
	if time > 2 and test_step == 1:
		_shoot(camera.unproject_position(soldier.joint("Spine2").origin))
		test_step = 2
	if time > 3 and test_step == 2:
		mode.select(2)
		_shoot(camera.unproject_position(soldier.joint("Spine2").origin))
		test_step = 3
	if time > 6 and test_step == 3:
		if hit_count != 2 or death_count != 1 or not soldier.dead:
			push_error("VIEWER projectile regression: hits=%d deaths=%d dead=%s" % [hit_count, death_count, soldier.dead])
			get_tree().quit(1)
			return
		_reset_actor()
		preview_source = true
		_reset_actor()
		if inspector.triangles <= 0 or inspector.skeleton != soldier.source.skeleton:
			push_error("Source inspection failed")
			get_tree().quit(1)
			return
		inspector.apply_mesh_mode(2)
		inspector.apply_mesh_mode(3)
		preview_source = false
		_reset_actor()
		inspector.apply_mesh_mode(1)
		if inspector.triangles <= 0 or inspector.skeleton != soldier.skeleton:
			push_error("Skinned inspection failed")
			get_tree().quit(1)
			return
		test_step = 4
	if soldier.native_player != null:
		if time > 7 and test_step == 4:
			_select_clip(clip_keys.find("mixamo_basic_shooter__rifle_aiming_idle"))
			test_step = 5
		if time > 7.5 and test_step == 5:
			mode.select(1)
			_shoot(camera.unproject_position(soldier.joint("Spine2").origin))
			test_step = 6
		if time > 8.5 and test_step == 6:
			if hit_count != 3 or death_count != 2 or not soldier.dead:
				push_error("Native animation ragdoll handoff failed")
				get_tree().quit(1)
				return
			_reset_actor()
			test_step = 7
	if time > 7 and (soldier.native_player == null or test_step == 7):
		print("VIEWER PASS clips=%d hits=%d deaths=%d reset=%s" % [clip_keys.size(), hit_count, death_count, not soldier.dead])
		get_tree().quit()


func _build_inspection_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -350
	panel.offset_right = -20
	panel.offset_top = 20
	panel.offset_bottom = 360
	canvas.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	_label(column, "MODEL INSPECTOR", 19)
	inspection_mode = OptionButton.new()
	for label in ["Shaded mesh", "Shaded + triangles", "Wireframe only", "Skeleton only"]:
		inspection_mode.add_item(label)
	inspection_mode.item_selected.connect(inspector.apply_mesh_mode)
	column.add_child(inspection_mode)
	bones_toggle = CheckButton.new()
	bones_toggle.text = "Skeleton / joints (X-ray)"
	bones_toggle.toggled.connect(func(on: bool): inspector.show_bones = on)
	column.add_child(bones_toggle)
	names_toggle = CheckButton.new()
	names_toggle.text = "Major bone names"
	names_toggle.toggled.connect(func(on: bool): inspector.show_names = on)
	column.add_child(names_toggle)
	_label(column, "Highlight a bone", 14)
	bone_picker = OptionButton.new()
	bone_picker.clip_text = true
	bone_picker.item_selected.connect(func(index: int): inspector.selected_bone = index - 1)
	column.add_child(bone_picker)
	model_stats = _label(column, "", 15)
	_label(column, "Character mesh only / base LOD
Cyan: left / Pink: right
Gold: selected bone
Weapon and stage excluded from counts", 12)

func _refresh_inspector() -> void:
	if inspector == null or bone_picker == null: return
	var rig: Skeleton3D = soldier.source.skeleton if preview_source else soldier.skeleton
	var root: Node3D = soldier.source.character if preview_source else soldier.visual
	inspector.bind_model(root, rig)
	bone_picker.clear()
	bone_picker.add_item("None")
	for i in rig.get_bone_count(): bone_picker.add_item(rig.get_bone_name(i))
	model_stats.text = "%d bones\n%d triangles / %d vertices\n%d meshes / %d surfaces" % [rig.get_bone_count(), inspector.triangles, inspector.vertices, inspector.meshes.size(), inspector.surfaces]


func _is_native() -> bool:
	return selected.begins_with("mixamo_") and soldier.native_player != null

func _active_player() -> AnimationPlayer:
	return soldier.native_player if _is_native() else soldier.source.player
