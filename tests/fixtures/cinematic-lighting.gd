extends Node
## The cinematic lighting's rules, without a battle: the presets and how saved
## settings take them up, the adaptive shadow fit, which lights get shadows,
## the physical sky's moods, which heat sources the heat haze keeps, how the
## rain soaks things and dries off, and what the motion blur asks of the
## engine. Run windowed, it also checks that the lens, eye, heat and motion
## blur passes compile and run on this graphics card.


func _ready() -> void:
	call_deferred("check")


func check() -> void:
	Settings.no_save = true
	_check_presets()
	_check_saved_settings()
	_check_shadow_fit()
	_check_light_picking()
	_check_sky()
	_check_heat_sources()
	_check_heat_pulses()
	_check_detached_fires()
	_check_exhaust_markers()
	_check_rain_wet()
	_check_motion_blur()
	if DisplayServer.get_name() != "headless":
		await _check_passes()
	else:
		assert(not CinematicFx.supported())
		assert(not SsgiFx.supported())
	print("CINEMATIC LIGHTING passed: presets, saved settings, shadow fit, light shadows, sky, heat haze, rain, motion blur")
	get_tree().quit()


## A battle that opens in the rain starts soaked; rain setting in wets things
## over WET_IN seconds, and they dry over DRY_OUT once it stops.
func _check_rain_wet() -> void:
	var atmo := Atmosphere.new()
	atmo.mood = "rain"
	atmo._wet_tick(0.1)
	assert(is_equal_approx(atmo.rain_wet, 1.0), "a battle opening in the rain starts soaked")
	atmo.mood = "golden"
	atmo._wet_tick(Atmosphere.DRY_OUT * 0.5)
	assert(is_equal_approx(atmo.rain_wet, 0.5), "half dry after half the drying time")
	atmo._wet_tick(Atmosphere.DRY_OUT)
	assert(atmo.rain_wet == 0.0)
	atmo.mood = "rain"
	atmo._wet_tick(Atmosphere.WET_IN * 0.25)
	assert(is_equal_approx(atmo.rain_wet, 0.25), "rain setting in wets things gradually")
	var fresh := Atmosphere.new()
	fresh.mood = "day"
	fresh._wet_tick(0.1)
	assert(fresh.rain_wet == 0.0, "a dry battle starts dry")
	atmo.free()
	fresh.free()
	RenderingServer.global_shader_parameter_set(&"rain_wet", 0.0)


## The velocity buffer is drawn only while the blur wants it, and the camera's
## own movement blurs only on "Objects + camera", never with Reduce motion.
func _check_motion_blur() -> void:
	assert(Settings.LABELS.motion_blur.size() == 3)
	assert(int(Settings.PRESETS.cinematic.motion_blur) == 1, "Cinematic blurs moving things, not the commander's pans")
	for p in ["low", "medium", "high", "ultra"]:
		assert(int(Settings.PRESETS[p].motion_blur) == 0)
	var fx := CinematicFx.new()
	assert(not fx.motion_blur and not fx.needs_motion_vectors)
	fx = null


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
	for k in ["light_shadows", "phys_sky", "lens", "shafts", "local_exp", "eye_adapt", "film", "heat_haze", "motion_blur", "ssgi"]:
		assert(k in SettingsPanel.NOT_ON_WEB)
	# bounce light: off up to Medium, then more of it the higher the preset
	var last := -1
	for p in Settings.PRESET_KEYS:
		var q := int(Settings.PRESETS[p].ssgi)
		assert(q >= last and q <= 2, "bounce light goes up with the presets (%s: %d)" % [p, q])
		last = q
	assert(int(Settings.PRESETS.medium.ssgi) == 0 and int(Settings.PRESETS.high.ssgi) == 1 and int(Settings.PRESETS.ultra.ssgi) == 2)


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
	# a setup saved before bounce light takes its preset's; a custom one stays without
	for preset in ["high", "ultra", "custom"]:
		var cf := ConfigFile.new()
		cf.set_value("main", "preset", preset)
		cf.set_value("main", "cfg_version", 2)
		var path := "user://bounce_light_test.cfg"
		cf.save(path)
		Settings.v.ssgi = 2
		Settings._load(path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var want: int = int(Settings.PRESETS[preset].ssgi) if Settings.PRESETS.has(preset) else 0
		assert(int(Settings.v.ssgi) == want, "a saved %s setup gets bounce light %d" % [preset, int(Settings.v.ssgi)])
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
	for k in ["shafts", "lens", "local_exposure", "eye", "film", "heat_haze"]:
		fx.set(k, true)
	# a column of hot air in front of the box
	var hh := HeatHaze.new()
	hh.on = true
	var hc := Camera3D.new()
	add_child(hc)
	hh.begin(hc)
	hh.add(Vector3(0, 0.4, -3.0), 0.5, Vector3.UP, 2.0, 1.0, 2.0, 0.3)
	fx.heat = hh.finish()
	fx.heat_time = 1.5
	hc.free()
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


## The heat haze keeps what the camera can see, near enough to show, and when
## there's more than the heat pass takes, the ones that would show the most.
func _check_heat_sources() -> void:
	var cam := Camera3D.new()
	cam.fov = 48.0
	add_child(cam)
	cam.global_transform = Transform3D.IDENTITY  # at the origin, looking down -Z
	var hh := HeatHaze.new()
	hh.begin(cam)
	hh.add(Vector3(0, 0, -30), 0.6, Vector3.UP, 2.0, 1.0, 2.0, 0.3)  # in view: kept
	hh.add(Vector3(0, 0, 30), 0.6, Vector3.UP, 2.0, 1.0, 2.0, 0.3)  # behind the camera
	hh.add(Vector3(200, 0, -30), 0.6, Vector3.UP, 2.0, 1.0, 2.0, 0.3)  # far off to the side
	hh.add(Vector3(0, 0, -900), 0.6, Vector3.UP, 2.0, 1.0, 2.0, 0.3)  # too far to see
	hh.add(Vector3(2, 0, -30), 0.6, Vector3.UP, 2.0, 0.0, 2.0, 0.3)  # cold
	var out := hh.finish()
	assert(out.size() == HeatHaze.STRIDE, "kept %d floats" % out.size())
	assert(is_equal_approx(out[2], -30.0) and is_equal_approx(out[8], 1.0))
	# a big battle: only the strongest HeatHaze.MAX go to the heat pass
	hh.begin(cam)
	var n := HeatHaze.MAX + 20
	for i in n:
		hh.add(Vector3(float(i % 9) - 4.0, 0, -40), 0.6, Vector3.UP, 2.0, 0.05 + 0.01 * i, 2.0, 0.3)
	out = hh.finish()
	assert(out.size() == HeatHaze.MAX * HeatHaze.STRIDE, "kept %d" % (out.size() / HeatHaze.STRIDE))
	var weakest := INF
	for i in HeatHaze.MAX:
		weakest = minf(weakest, out[i * HeatHaze.STRIDE + 8])
	assert(weakest >= 0.05 + 0.01 * 20 - 0.001, "kept a source of strength %.2f over stronger ones" % weakest)
	# a fire's hot air stands over it, leaning downwind; a bigger fire's is wider
	hh.begin(cam)
	hh.add_fire(Vector3(0, 0, -30), Vector3(0.55, 0.45, 0.55), 1.0)
	hh.add_fire(Vector3(0, 0, -30), Vector3(3.0, 0.25, 3.0), 1.0)
	out = hh.finish()
	assert(out.size() == 2 * HeatHaze.STRIDE)
	assert(out[1] > 1.0 and out[4] * Fires.WIND.x > 0.0 and out[5] > 0.9, "a fire's column %s" % [out.slice(0, 8)])
	assert(out[HeatHaze.STRIDE + 3] > out[3])
	cam.free()


## Blasts and muzzles: a pulse only while the haze is on, in at once and gone
## once its time is up.
func _check_heat_pulses() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	var hh := HeatHaze.new()
	hh.blast(Vector3(0, 0, -30), 1.4)
	assert(hh.pulses() == 0, "a pulse kept with the haze off")
	hh.on = true
	hh.blast(Vector3(0, 0, -30), 1.4)
	assert(hh.pulses() == 1)
	assert(HeatHaze.pulse_strength(0.0, 1.0) == 0.0 and HeatHaze.pulse_strength(1.0, 1.0) == 0.0)
	assert(HeatHaze.pulse_strength(0.06, 1.0) > HeatHaze.pulse_strength(0.5, 1.0))
	assert(HeatHaze.pulse_strength(0.5, 1.0) > HeatHaze.pulse_strength(0.9, 1.0))
	hh.begin(cam)
	hh._tick_pulses(0.05)
	assert(hh.finish().size() == HeatHaze.STRIDE, "a fresh blast's heat isn't in view")
	for i in 30:
		hh.begin(cam)
		hh._tick_pulses(0.05)
	assert(hh.pulses() == 0, "a blast's heat outlived it")
	for i in HeatHaze.PULSES + 5:
		hh.blast(Vector3(0, 0, -30), 1.0)
	assert(hh.pulses() == HeatHaze.PULSES)
	hh.clear()
	assert(hh.pulses() == 0)
	cam.free()


## The models note the mouths of their exhausts, pointing the way the gas
## leaves: an Apache's turbines blow out and back.
func _check_exhaust_markers() -> void:
	var k := VehicleModels.build("gunship", 0, 1)
	assert(k.exhausts.size() >= 2, "the Apache notes %d exhausts" % k.exhausts.size())
	for e in k.exhausts:
		var out := e.basis.y.normalized()
		assert(out.z > 0.3, "an exhaust blows %s, not back" % out)
		assert(absf(e.origin.x) > 0.3 and e.origin.y > 1.0, "an exhaust's mouth at %s" % e.origin)
	k.root.free()


## A fire on something taken out of the tree (a destroyed vehicle, kept a
## while after it's cleared away) adds no heat, and reading where it is mustn't
## raise an engine error every frame.
func _check_detached_fires() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	var vfx := Vfx.new()
	var holder := Node3D.new()
	for i in 2:
		var h := Node3D.new()
		h.position = Vector3(0, 0, -30)
		h.set_meta("fire", 1.0)
		h.set_meta("ext", Vector3(0.55, 0.45, 0.55))
		holder.add_child(h)
		vfx._burners.append(h)
	var hh := HeatHaze.new()
	hh.begin(cam)
	vfx.heat_sources(hh)
	assert(hh.finish().is_empty(), "fires outside the tree gave off heat")
	add_child(holder)
	hh.begin(cam)
	vfx.heat_sources(hh)
	assert(hh.finish().size() == 2 * HeatHaze.STRIDE, "fires back in the tree gave off no heat")
	holder.free()
	vfx.free()
	cam.free()
