extends Node3D
## Controlled 30 Hz recordings of real effect code. See tools/showcase/stages.json.
const CAPTURE_FPS := 30
var field: World
var camera: Camera3D
var output := ""
var mode := "armaments"
var label := "CURRENT BUILD"
var legacy := false
var elevation := -1.0
var night_lighting := false

func _ready() -> void:
	TestRun.watch()
	Settings.v.effects = 2
	Settings.v.decals = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): output = arg.get_slice("=", 1)
		if arg.begins_with("--clip="): mode = arg.get_slice("=", 1)
		if arg.begins_with("--label="): label = arg.get_slice("=", 1)
		if arg == "--legacy-effects": legacy = true
		if arg == "--night": night_lighting = true
		if arg.begins_with("--elevation="): elevation = float(arg.get_slice("=", 1))
		if arg.begins_with("--quality="): Settings.v.effects = clampi(int(arg.get_slice("=", 1)), 0, 2)
	seed(712)
	Sfx._ensure()
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
	field = load("res://tests/fixtures/effects-field.gd").new()
	add_child(field)
	var night := mode == "flares"
	var impacts := mode == "impacts"
	var dark := night or night_lighting
	var env := Environment.new()
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.075, 0.105, 0.16) if dark else Color(0.36, 0.47, 0.57)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.51, 0.7) if dark else Color(0.7, 0.78, 0.85)
	env.ambient_light_energy = 0.65 if dark else 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.65 if dark else 1.8
	sun.shadow_enabled = true
	add_child(sun)
	var atmo := Atmosphere.new()
	atmo.world = field
	atmo.mood = "night" if dark else "day"
	atmo.sun = sun
	field.atmo = atmo
	add_child(atmo)
	atmo.set_process(false)
	field.fx.vfx.apply_lighting()
	# Keep the airborne close-up free of the finite range platform edge.
	if not night:
		Res.mi(self, Res.box(Vector3(180, 0.4, 180)), Res.mat(Color(0.24, 0.21, 0.16)), Vector3(0, -0.21, 0))
	# Ten-metre marks show the plume's scale without a staged combat scene.
	for x in ([] if night else range(-30, 31, 10)):
		Res.mi(self, Res.box(Vector3(0.04, 0.01, 50)), Res.mat(Color(0.4, 0.37, 0.3)), Vector3(x, 0.01, 0))
	camera = Camera3D.new()
	camera.fov = 32.0 if night else 38.0
	camera.position = Vector3(10, 40, 16) if night else Vector3(0, 28, 50)
	if not night and elevation >= 0.0:
		var angle := deg_to_rad(clampf(elevation, 5.0, 85.0))
		var distance := Vector2(24.0, 50.0).length()
		camera.position = Vector3(0, 4.0 + distance * sin(angle), distance * cos(angle))
	add_child(camera)
	camera.look_at(Vector3(0, 37, 0) if night else Vector3(0, 4, 0))
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var caption := Label.new()
	caption.position = Vector2(22, 18)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(caption)
	var target_labels: Array[Label3D] = []
	if not night and not impacts:
		for i in 3:
			var text := Label3D.new()
			text.text = ["GRENADE", "~110 mm HE", "FUEL"][i]
			text.font_size = 36
			text.pixel_size = 0.022
			text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			text.position = Vector3((i - 1) * 16, 0.3, 8)
			add_child(text)
			target_labels.append(text)
	for frame in 12 * CAPTURE_FPS:
		caption.text = label + (" / ILLUMINATION FLARE\nMoonlit close-up: cloth canopy, suspension lines and drifting smoke" if night else " / ARMAMENT EFFECTS\nGrenade / HE ground burst / fuel explosion · ground marks: 10 m")
		if not night and not impacts and mode != "explosions" and frame >= 180:
			caption.text = label + " / TRACERS AND IMPACTS\nMachine-gun rounds · dirt / stone / metal · normal simulation speed"
			if frame == 180:
				for i in 3:
					target_labels[i].text = ["DIRT", "STONE", "METAL"][i]
					target_labels[i].position.z = 20.0
		if night:
			if frame == 15: atmo._spawn_flare(Vector3.ZERO)
			atmo._flare_t = 999.0
			atmo._flares_tick(1.0 / CAPTURE_FPS)
			if not atmo._flares.is_empty():
				var charge: Node3D = atmo._flares[0][0]
				camera.position = charge.position + Vector3(5, 3, 8)
				camera.look_at(charge.position + Vector3.UP * 2.1)
		elif impacts:
			var material_index := mini(frame / 120, 2)
			var p := Vector3(material_index * 12.0 - 12.0, 0.12, 15.0)
			camera.position = p + Vector3(2.6, 1.8, 4.2)
			camera.look_at(p + Vector3.UP * 0.35)
			caption.text = label + " / " + ["DIRT", "STONE", "METAL"][material_index] + " IMPACTS\nControlled close-up / normal simulation speed"
			if frame % 18 == 6:
				var from := p + Vector3(-9, 1.4, 10)
				seed(712 + frame)
				var delay := field.fx.gunfx.round_flight(from, p, "mg", 0, 40.0)
				field.fx.gunfx.impact([Fx.HIT_DIRT, Fx.HIT_STONE, Fx.HIT_METAL][material_index], p, (from - p).normalized(), 1.0, 40.0, delay)
		elif frame in ([30, 150, 270] if mode == "explosions" else [20, 50, 80]):
			var i := int((frame - 30) / 120) if mode == "explosions" else int((frame - 20) / CAPTURE_FPS)
			var p := Vector3((i - 1) * 16, 0.1, 0)
			var size: float = [1.0, 1.4, 2.0][i]
			if legacy: field.fx.vfx.explode(p, size)
			else: field.fx._explode(p, size, ["frag", "he", "fuel"][i])
		elif mode != "explosions" and frame >= 180 and frame % 8 == 0:
			var i := int(frame / 8) % 3
			var p := Vector3((i - 1) * 16, 0.15, 15)
			var from := p + Vector3(-25, 1.4, 30)
			# Use the game's weapon speed, tracer share and daylight brightness.
			# A separate seed per shot keeps the comparison's inputs matched.
			seed(712 + frame)
			var delay := field.fx.gunfx.round_flight(from, p, "mg", 0, 40.0)
			field.fx.gunfx.impact([Fx.HIT_DIRT, Fx.HIT_STONE, Fx.HIT_METAL][i], p, (from - p).normalized(), 1.0, 40.0, delay)
		if legacy:
			# Slow offline readback must not let the old wall-clock pool
			# cleanup truncate particle programs advancing at fixed simulation Hz.
			for pool: Array in field.fx.vfx._rigs.values():
				for rig: Node3D in pool:
					if rig.has_meta("shown"):
						rig.set_meta("t", Time.get_ticks_msec() / 1000.0)
		await RenderingServer.frame_post_draw
		if not output.is_empty():
			get_viewport().get_texture().get_image().save_png(output.path_join("%04d.png" % frame))
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	print("EFFECTS_CLIP %s %s frames=%d" % [label, mode, 12 * CAPTURE_FPS])
	get_tree().quit()
