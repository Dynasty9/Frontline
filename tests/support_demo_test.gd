extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	TestRun.watch()
	for kind in ["wipeout", "airstrike", "ac130"]:
		var demo = load("res://scripts/ui/support_demo.gd").new()
		demo.settings = {"map_size": 1024, "seed": 7, "mood": "day"}
		demo.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(demo)
		await demo.prepare(kind)
		demo.set_physics_process(false)
		check(demo.projectiles.size() > 0, kind + " must launch a real aircraft")
		for step in 2100:
			demo._physics_process(1.0 / 60.0)
			if step % 60 == 0:
				await get_tree().process_frame
		check(not demo._active, kind + " must finish")
		check(demo.stats.get("support_" + kind, 0) == 1, kind + " must use the support command")
		if kind == "wipeout":
			check(demo.stats.get("a10_run", 0) == 1, "The gun run must actually fire")
		var damaged: bool = demo.vehicles.size() < 3
		for v in demo.vehicles:
			if v.hp < v.max_hp:
				damaged = true
		check(damaged, kind + " must damage the range targets")
		var original_terrain = demo.terrain
		var original_fx = demo.fx
		await demo.replay()
		check(demo.terrain == original_terrain, "Replay must keep the prepared terrain")
		check(demo.fx == original_fx, "Replay must keep warmed effect pools")
		check(demo.vehicles.size() == 3 and demo.projectiles.size() == 1, "Replay must reset targets and aircraft")
		check(demo.time == 0.0 and demo._active, "Replay must restart the sortie")
		demo.free()
		await get_tree().process_frame
	print("SUPPORT_DEMO_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

