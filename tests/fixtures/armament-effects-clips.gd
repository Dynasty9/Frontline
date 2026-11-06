extends Node3D
## Controlled 12 Hz recordings of real effect code. See tools/showcase/stages.json.
var field: World
var camera: Camera3D
var output := ""
var mode := "armaments"
var label := "CURRENT BUILD"
var legacy := false

func _ready() -> void:
	TestRun.watch()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): output = arg.get_slice("=", 1)
		if arg.begins_with("--clip="): mode = arg.get_slice("=", 1)
		if arg.begins_with("--label="): label = arg.get_slice("=", 1)
		if arg == "--legacy-effects": legacy = true
	seed(712)
	DirAccess.make_dir_recursive_absolute(output)
	field = load("res://tests/fixtures/effects-field.gd").new()
	add_child(field)
	var night := mode == "flares"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.025, 0.045) if night else Color(0.36, 0.47, 0.57)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.51, 0.7) if night else Color(0.7, 0.78, 0.85)
	env.ambient_light_energy = 0.2 if night else 0.65
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.22 if night else 1.8
	sun.shadow_enabled = true
	add_child(sun)
	var atmo := Atmosphere.new()
	atmo.world = field
	atmo.mood = "night" if night else "day"
	atmo.sun = sun
	field.atmo = atmo
	add_child(atmo)
	atmo.set_process(false)
	field.fx.vfx.apply_lighting()
	Res.mi(self, Res.box(Vector3(180, 0.4, 180)), Res.mat(Color(0.24, 0.21, 0.16)), Vector3(0, -0.21, 0))
	# Ten-metre marks show the plume's scale without a staged combat scene.
	for x in range(-30, 31, 10):
		Res.mi(self, Res.box(Vector3(0.04, 0.01, 50)), Res.mat(Color(0.4, 0.37, 0.3)), Vector3(x, 0.01, 0))
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0 if night else 38.0
	camera.position = Vector3(10, 40, 16) if night else Vector3(12, 22, 40)
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
	if not night:
		for i in 3:
			var text := Label3D.new()
			text.text = ["GRENADE", "~110 mm HE", "FUEL"][i]
			text.font_size = 36
			text.pixel_size = 0.022
			text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			text.position = Vector3((i - 1) * 16, 0.3, 8)
			add_child(text)
	for frame in 144:
		var t := float(frame) / 12.0
		caption.text = label + (" / ILLUMINATION FLARE\nParachute descent, wind drift, sparks and lingering smoke" if night else " / ARMAMENT EFFECTS\nGrenade / HE ground burst / fuel explosion · ground marks: 10 m")
		if night:
			if frame == 6: atmo._spawn_flare(Vector3.ZERO)
			atmo._flare_t = 999.0
			atmo._flares_tick(1.0 / 12.0)
			if not atmo._flares.is_empty():
				var charge: Node3D = atmo._flares[0][0]
				camera.position = charge.position + Vector3(10, 4, 16)
				camera.look_at(charge.position + Vector3.UP)
		elif frame in [8, 20, 32]:
			var i := int((frame - 8) / 12)
			var p := Vector3((i - 1) * 16, 0.1, 0)
			var size: float = [1.0, 1.4, 2.0][i]
			if legacy: field.fx.vfx.explode(p, size)
			else: field.fx.vfx.call("explode", p, size, ["frag", "he", "fuel"][i])
		elif frame >= 72 and frame % 3 == 0:
			var i := int(frame / 3) % 3
			var p := Vector3((i - 1) * 16, 0.15, 15)
			var from := p + Vector3(-6, 1.4, 7)
			field.fx.gunfx.tracer(from, p, GunFx.TRACER_HOT, 3.5, 0.035, 140.0)
			field.fx.gunfx.impact([Fx.HIT_DIRT, Fx.HIT_STONE, Fx.HIT_METAL][i], p, (from - p).normalized(), 1.0, 40.0, from.distance_to(p) / 140.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("%04d.png" % frame))
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	print("EFFECTS_CLIP %s %s frames=144" % [label, mode])
	get_tree().quit()
