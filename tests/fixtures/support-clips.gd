extends Node3D
## A matched take of each real call-in on a textured daylight range.

func _ready() -> void:
	TestRun.watch()
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not Defs.SUPPORT.has(args[0]):
		push_error("Pass a support ID and a take label after --")
		get_tree().quit(2)
		return
	var kind := args[0]
	var label := args[1]
	get_window().size = Vector2i(960, 540)
	Settings.v.effects = 2
	Settings.v.post = false
	Settings.v.grass = 1
	seed(712)
	var demo = preload("res://scripts/ui/support_demo.gd").new()
	demo.settings = {"map_size": 1024, "seed": 712, "scenario": "support_preview", "mood": "day"}
	demo.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(demo)
	# Use the same ground, mountains, daylight and haze as a live battlefield.
	demo.atmo = Atmosphere.new()
	demo.add_child(demo.atmo)
	demo.atmo.setup(demo)
	demo.fx.vfx.apply_lighting()
	var caption := Label.new()
	caption.text = label + "   /   " + String(Defs.SUPPORT[kind].name)
	caption.position = Vector2(22, 18)
	caption.add_theme_font_size_override("font_size", 25)
	caption.add_theme_constant_override("outline_size", 6)
	add_child(caption)
	await demo.prepare(kind)
	for item in [["sandbags", Vector3(3, 0, 6)], ["bunker", Vector3(-26, 0, -21)], ["watchtower", Vector3(31, 0, -29)]]:
		demo.spawn("structure", {"skind": item[0], "pos": item[1], "team": -1})
	for i in 24:
		var angle := float(i) * 2.4
		var radius := 55.0 + float(i % 7) * 12.0
		demo.spawn("structure", {"skind": "tree", "pos": Vector3(cos(angle), 0, sin(angle)) * radius, "team": -1, "variant": i % 3})
	# The observer's off-map support queue normally advances in Rules.tick.
	# The small manual range steps only projectiles, terrain and fires.
	var frames := 288 if Defs.SUPPORT[kind].shape == "strafe" else 240
	# The armed drone's first impact lands near the end of a ten-second
	# take. Include the next arrival and its dust clearing in both takes.
	if kind == "greyhawk":
		frames = 384
	# Trim the incoming off-map travel from the recording while the game
	# simulates it normally, leaving the arrivals and the settling dust.
	var preroll := 0
	if Defs.SUPPORT[kind].shape == "circle":
		preroll = 144
		if kind == "artillery":
			preroll = 240
			frames = 192
	for i in preroll + frames:
		demo.rules._support_tick()
		await RenderingServer.frame_post_draw
	print("SUPPORT_CLIP ", kind, " frames=", frames, " launches=", demo.stats.get("support_" + kind, 0))
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	get_tree().quit()
