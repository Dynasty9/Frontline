extends Node3D
## Controlled effects in the actual showroom battlefield, with its terrain,
## scenery, lighting, depth buffer and camera. No combat outcomes are staged.
var args := {}
var output := ""
var mode := "blast-close"
var label := "CURRENT BUILD"
var legacy := false
var field: World

func _ready() -> void:
	TestRun.watch()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): output = arg.get_slice("=", 1)
		if arg.begins_with("--clip="): mode = arg.get_slice("=", 1)
		if arg.begins_with("--label="): label = arg.get_slice("=", 1)
		if arg == "--legacy-effects": legacy = true
	DirAccess.make_dir_recursive_absolute(output)
	seed(712)
	# Fixed, supported game settings keep the comparison legible and reproducible.
	Settings.v.grass = 1
	Settings.v.effects = 2
	Settings.v.post = false
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
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	print("BLAST_WORLD_CLIP %s frames=192" % mode)
	get_tree().quit()
