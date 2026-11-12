extends Node
## The cinematic lighting's rules, without a battle: the presets and how saved
## settings take them up, the adaptive shadow fit, which lights get shadows,
## and the physical sky's moods. Run windowed, it also checks that the lens and
## eye passes compile and run on this graphics card.


func _ready() -> void:
	call_deferred("check")


func check() -> void:
	Settings.no_save = true
	_check_presets()
	_check_saved_settings()
	_check_shadow_fit()
	_check_light_picking()
	_check_sky()
	if DisplayServer.get_name() != "headless":
		await _check_passes()
	else:
		assert(not CinematicFx.supported())
	print("CINEMATIC LIGHTING passed: presets, saved settings, shadow fit, light shadows, sky")
	get_tree().quit()


func _check_presets() -> void:
	assert(Settings.PRESET_KEYS.size() == Settings.PRESETS.size())
	for p in Settings.PRESET_KEYS:
		assert(Settings.PRESETS.has(p))
		for k in Settings.PRESETS[p]:
			assert(Settings.v.has(k), "preset %s sets %s, which isn't a setting" % [p, k])
		for k in Settings.CINEMATIC_KEYS:
			assert(Settings.PRESETS[p].has(k), "preset %s leaves out %s" % [p, k])
	# Cinematic is Ultra with all of the cinematic lighting on top
	var ultra: Dictionary = Settings.PRESETS.ultra
	var cine: Dictionary = Settings.PRESETS.cinematic
	for k in ultra:
		if not k in Settings.CINEMATIC_KEYS and k != "terrain_reflections":
			assert(cine[k] == ultra[k], "Cinematic differs from Ultra in %s" % k)
	for k in Settings.CINEMATIC_KEYS:
		assert(bool(cine[k]), "Cinematic leaves %s off" % k)
		if k != "shadow_fit":
			assert(not bool(ultra[k]), "Ultra already has %s" % k)
	# the browser build hides what its renderer can't draw
	for k in ["light_shadows", "phys_sky", "lens", "shafts", "local_exp", "eye_adapt", "film"]:
		assert(k in SettingsPanel.NOT_ON_WEB)


## A settings file from before the cinematic lighting takes its preset's.
func _check_saved_settings() -> void:
	var saved := Settings.v.duplicate()
	var saved_preset := Settings.preset
	for preset in ["low", "cinematic"]:
		var cf := ConfigFile.new()
		cf.set_value("main", "preset", preset)
		cf.set_value("main", "cfg_version", 2)
		cf.set_value("main", "shadows", 2)
		var path := "user://cinematic_lighting_test.cfg"
		cf.save(path)
		for k in Settings.CINEMATIC_KEYS:
			Settings.v[k] = Settings.PRESETS.high[k]
		Settings._load(path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		for k in Settings.CINEMATIC_KEYS:
			assert(Settings.v[k] == Settings.PRESETS[preset][k], "a saved %s setup gets %s = %s" % [preset, k, Settings.v[k]])
	Settings.v = saved
	Settings.preset = saved_preset


func _check_shadow_fit() -> void:
	var cam := Camera3D.new()
	cam.fov = 48.0
	add_child(cam)
	# close in and looking down: the shadows reach no further than the view
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-45.0), 0.3, 0.0)), Vector3(0, 12, 12))
	var near := Atmosphere.fit_cascades(cam, 0.0, 0.0, 800.0, 4)
	assert(near.size() == 4)
	assert(near[0] < 200.0, "close in the shadows still reach %.0f m" % near[0])
	assert(near[1] > 0.0 and near[1] < near[2] and near[2] < near[3] and near[3] < 1.0)
	# zoomed out, further; looking at the horizon, the whole reach
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-60.0), 0.3, 0.0)), Vector3(0, 180, 100))
	var far := Atmosphere.fit_cascades(cam, 0.0, 0.0, 800.0, 4)
	assert(far[0] > near[0] and far[0] <= 800.0)
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-10.0), 0.3, 0.0)), Vector3(0, 8, 0))
	assert(is_equal_approx(Atmosphere.fit_cascades(cam, 0.0, 0.0, 800.0, 4)[0], 800.0))
	# Low shadows keep two cascades
	assert(Atmosphere.fit_cascades(cam, 0.0, 0.0, 140.0, 2).size() == 2)
	# mountains look further down into the valleys
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-45.0), 0.3, 0.0)), Vector3(0, 12, 12))
	assert(Atmosphere.fit_cascades(cam, 0.0, 400.0, 800.0, 4)[0] > near[0])
	cam.free()


func _check_light_picking() -> void:
	var lights: Array[OmniLight3D] = []
	for spec in [[8.0, 14.0, Vector3(5, 1, 0)], [2.0, 14.0, Vector3(10, 1, 0)], [9.0, 14.0, Vector3(400, 1, 0)],
			[0.1, 14.0, Vector3(1, 1, 0)], [6.0, 5.0, Vector3(2, 1, 0)], [7.0, 14.0, Vector3(3, 1, 0)]]:
		var l := OmniLight3D.new()
		l.light_energy = spec[0]
		l.omni_range = spec[1]
		add_child(l)
		l.global_position = spec[2]
		lights.append(l)
	lights[5].visible = false
	var picked := Atmosphere.pick_shadowed(lights, Vector3.ZERO, 2)
	# the bright near ones; not the far one, the spent one or the hidden one
	assert(picked.size() == 2 and picked[0] == lights[0] and picked[1] == lights[1], "picked %s" % [picked])
	assert(Atmosphere.pick_shadowed(lights, Vector3.ZERO, 6).size() == 3)
	for l in lights:
		l.free()


func _check_sky() -> void:
	for m in PhysicalSky.MOODS:
		assert(Atmosphere.MOODS.has(m))
		var mat := PhysicalSky.make(m)
		assert(float(mat.get_shader_parameter("sky_energy")) > 1.0)
	# midday keeps its photographed sky; cloud, rain and night their painted ones
	for m in ["day", "overcast", "rain", "night"]:
		assert(not PhysicalSky.MOODS.has(m))


## Windowed: the passes compile and run (a shader the driver refuses
## push_errors, which fails the run).
func _check_passes() -> void:
	if not CinematicFx.supported():
		return
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	var fx := CinematicFx.new()
	for k in ["shafts", "lens", "local_exposure", "eye", "film"]:
		fx.set(k, true)
	var p := PackedFloat32Array()
	p.resize(CinematicFx.PARAMS)
	p[6] = 1.0
	p[7] = 16.0 / 9.0
	p[11] = 1.0
	p[12] = 1.0
	p[13] = 0.3
	p[14] = 1.0
	p[15] = 2.0
	p[16] = 1.0
	p[17] = 1.0
	p[18] = 1.0
	p[19] = 1.0 / 30.0
	p[20] = 1.0
	p[22] = 0.4
	p[24] = 2.6
	p[25] = 0.7
	p[26] = 0.12
	fx.params = p
	var comp := Compositor.new()
	var effects: Array[CompositorEffect] = [fx]
	comp.compositor_effects = effects
	env.compositor = comp
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.position = Vector3(0, 0, -4)
	add_child(box)
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	assert(fx._ready_rd, "the cinematic passes didn't compile")
	env.queue_free()
	cam.queue_free()
	box.queue_free()
