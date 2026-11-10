extends Node3D
## Controlled effects in the actual showroom battlefield, with its terrain,
## scenery, lighting, depth buffer and camera. No combat outcomes are staged.
var args := {}
var output := ""
var mode := "blast-close"
var label := "CURRENT BUILD"
var legacy := false
var field: World
var capture_fps := 24
var resume_frame := 0
var cloud_shader := ""

func _ready() -> void:
	TestRun.watch()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): output = arg.get_slice("=", 1)
		if arg.begins_with("--clip="): mode = arg.get_slice("=", 1)
		if arg.begins_with("--label="): label = arg.get_slice("=", 1)
		if arg == "--legacy-effects": legacy = true
		if arg == "--preview": capture_fps = 12
		if arg.begins_with("--resume-frame="): resume_frame = maxi(0, int(arg.get_slice("=", 1)))
		if arg.begins_with("--cloud-shader="): cloud_shader = arg.get_slice("=", 1)
	if resume_frame > 0 and (mode != "battlefield-effects" or resume_frame != 16 * capture_fps):
		push_error("Resume is supported only at the fresh stone shot, 16 seconds into battlefield-effects.")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	seed(712)
	# Fixed, supported game settings keep the comparison legible and reproducible.
	Settings.v.grass = 1
	Settings.v.effects = 2
	Settings.v.post = false
	Settings.v.decals = true
	field = World.new()
	field.settings = {"scenario": "showroom", "seed": 712, "mood": "day", "map_size": 1024, "players": {}, "ai_teams": []}
	add_child(field)
	await field.build()
	while field.cam == null or field.building:
		await get_tree().process_frame
	field.set_process(false)
	field.set_physics_process(false)
	field.cam.set_process(false)
	field.input.set_process(false)
	field.hud.visible = false
	# Matched shader-only comparisons use an explicitly recorded historical
	# source file while retaining the same stage, assets and particle schedule.
	if not cloud_shader.is_empty():
		var comparison := Shader.new()
		comparison.code = FileAccess.get_file_as_string(cloud_shader)
		field.fx.vfx.blasts._shader = comparison
		for pool: Array in field.fx.vfx.blasts._pools.values():
			for blast: BlastFlipbooks.Blast in pool:
				blast.material.shader = comparison
	var camera := field.cam.cam
	camera.fov = 48.0
	var target := Vector3(4, field.ground_y(Vector3(4, 0, 12)), 12)
	camera.global_position = target + (Vector3(25, 52, 30) if mode == "blast-rts" else Vector3(8, 15, 18))
	camera.look_at(target + Vector3(0, 2.3, 0))
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var caption := Label.new()
	caption.position = Vector2(22, 18)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	caption.text = label + " / " + ("RTS CAMERA" if mode == "blast-rts" else "GROUND BURST") + "\nControlled HE effect in the game world · 24 fps, normal speed"
	canvas.add_child(caption)
	print("BLAST_WORLD_WARMUP")
	# Drain prewarm effects and let the terrain/grass upload before recording.
	for i in 48:
		await RenderingServer.frame_post_draw
	seed(712)
	print("BLAST_WORLD_RECORDING")
	if mode == "blast-cover":
		await _cover(camera, caption)
		_finish()
		return
	if mode == "battlefield-effects":
		await _showcase(camera, caption)
		_finish()
		return
	for frame in 192:
		if frame == 24:
			if legacy:
				field.fx.call("_explode", target + Vector3.UP * 0.1, 1.4)
			else:
				field.fx.call("_explode", target + Vector3.UP * 0.1, 1.4, "he")
		if legacy:
			# Preserve the baseline particle lifetimes during slow offline
			# rendering; its pool's wall clock otherwise hides them too soon.
			for pool: Array in field.fx.vfx._rigs.values():
				for rig: Node3D in pool:
					if rig.has_meta("shown"):
						rig.set_meta("t", Time.get_ticks_msec() / 1000.0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("%04d.png" % frame))
	_finish()


func _finish() -> void:
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	print("BLAST_WORLD_CLIP %s complete" % mode)
	get_tree().quit()


func _cover(camera: Camera3D, caption: Label) -> void:
	var tank := _ground(30, -2)
	var wall := _ground(-30, 24)
	for frame in 8 * capture_fps:
		var at_tank := frame < 4 * capture_fps
		var target := tank if at_tank else wall
		_frame_subject(camera, target, Vector3(8, 5, 11) if at_tank else Vector3(4, 3, 7), 1.2)
		caption.text = label + " / " + ("TANK ARMOR" if at_tank else "STONE COVER")
		caption.text += "\nActual battlefield · matched camera and effects · normal speed"
		if frame == capture_fps / 2 or frame == int(4.5 * capture_fps):
			seed(712)
			field.fx.call("_explode", target + Vector3(0, 0.1, 0 if at_tank else -0.35), 2.0 if at_tank else 1.4, "fuel" if at_tank else "he")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join("%04d.png" % frame))


func _ground(x: float, z: float) -> Vector3:
	var p := Vector3(x, 0, z)
	p.y = field.ground_y(p)
	return p


func _frame_subject(camera: Camera3D, target: Vector3, offset: Vector3, lift := 0.8) -> void:
	camera.global_position = target + offset
	camera.look_at(target + Vector3.UP * lift)
	field.cam.focus_pos = target
	field.cam.dist = offset.length()


func _showcase(camera: Camera3D, caption: Label) -> void:
	# Real battlefield geometry and effects; only the camera and event schedule
	# are controlled. Explicit cuts keep each effect readable at embedded size.
	field.atmo.set_process(false)
	var soil := _ground(4, 12)
	var dirt := _ground(4, 6)
	var fuel := _ground(30, -2)
	var stone := _ground(-30, 24) + Vector3(0, 0.6, 0.27)
	# The showroom SUV faces 0.5 radians; hit its visible steel door panel,
	# outside the skin, rather than emitting chips from inside the body.
	var car_basis := Basis(Vector3.UP, 0.5)
	var metal := _ground(-30, 8) + car_basis * Vector3(0.99, 0.8, 0.1)
	var previous_phase := -1
	var viewport_rid := get_viewport().get_viewport_rid()
	if resume_frame > 0:
		RenderingServer.viewport_set_active(viewport_rid, false)
	for frame in 28 * capture_fps:
		if frame == resume_frame:
			RenderingServer.viewport_set_active(viewport_rid, true)
			if resume_frame > 0:
				print("BATTLEFIELD_RESUME frame=", frame)
		var t := float(frame) / capture_fps
		var phase := 0
		for cut in [4.0, 9.0, 14.0, 16.0, 18.0, 20.0]:
			if t >= cut:
				phase += 1
		if phase != previous_phase:
			previous_phase = phase
			caption.text = ["GRENADE / fragments and ground dust", "~110 mm HE / earth fans and falling clods", "FUEL / fire through rising smoke", "TRACERS / dirt impacts", "TRACERS / stone impacts", "TRACERS / metal impacts", "ILLUMINATION FLARE / descent over the battlefield"][phase]
			caption.text += "\nActual game terrain · controlled effects · normal speed"
			match phase:
				0: _frame_subject(camera, soil, Vector3(5, 7, 9))
				1: _frame_subject(camera, soil, Vector3(6, 10, 13), 2.3)
				2: _frame_subject(camera, fuel, Vector3(11, 13, 17), 3.0)
				3: _frame_subject(camera, dirt, Vector3(3, 2.4, 4.8), 0.25)
				4: _frame_subject(camera, stone, Vector3(2.8, 1.8, 4.8), 0.2)
				5: _frame_subject(camera, metal, car_basis * Vector3(5, 2, 3), 0.2)
				6:
					field.atmo.apply_mood("night")
					field.atmo._flare_t = 999.0
					field.atmo._spawn_flare(soil)
		if frame in [int(0.75 * capture_fps), int(4.5 * capture_fps), int(9.5 * capture_fps)]:
			seed(712 + phase)
			field.fx.call("_explode", (fuel if phase == 2 else soil) + Vector3.UP * 0.1, [1.0, 1.4, 2.0][phase], ["frag", "he", "fuel"][phase])
		if phase in [3, 4, 5] and frame % (capture_fps / 4) == 0:
			seed(712 + frame)
			var p: Vector3 = [dirt + Vector3.UP * 0.08, stone, metal][phase - 3]
			p += (car_basis * Vector3.BACK if phase == 5 else Vector3.RIGHT) * randf_range(-0.18, 0.18)
			# A 35 m flight lets the real 780 m/s tracer cross a recorded frame.
			# At a 12 m range it can finish entirely between two 24 Hz frames.
			var approach := car_basis * Vector3(12, 1.4, 3) if phase == 5 else Vector3(-9, 1.4, 12)
			var from := p + approach.normalized() * 35.0
			var distance := camera.global_position.distance_to(p)
			var delay := field.fx.gunfx.round_flight(from, p, "mg", 0, distance)
			field.fx.gunfx.impact([Fx.HIT_DIRT, Fx.HIT_STONE, Fx.HIT_METAL][phase - 3], p, (from - p).normalized(), 1.0, distance, delay)
		if phase == 6:
			field.atmo._flares_tick(1.0 / capture_fps)
			var charge: Node3D = field.atmo._flares[0][0]
			# Look down across the charge so the illuminated terrain stays in
			# view behind the canopy and trail, instead of a plain black sky.
			var offset := Vector3(9, 6, 13) if t >= 23.0 else Vector3(24, 18, 32)
			_frame_subject(camera, charge.global_position, offset, 0.8)
		if frame < resume_frame:
			# Replay the same fixed-step event schedule after an interrupted
			# recording, without rasterizing frames already kept. Resume only
			# at a shot cut whose effects start fresh; GPU particle history
			# from an invisible shot is not reconstructed by this replay.
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output.path_join("%04d.png" % frame))
