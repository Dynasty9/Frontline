extends Node
## Exported-browser exercise of the real map author, worker, view, recording and replay controls.
var main: Node
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	start.call_deferred()

func wait_for_view() -> bool:
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline:
		if is_instance_valid(main.world) and not main.world.srv and main.world.loaded:
			return true
		await get_tree().process_frame
	return false

func start() -> void:
	check(OS.has_feature("web"), "This integration test requires a browser export")
	Settings.no_save = true
	Settings.apply_preset("low", false)
	check(LocalServer.launch({"scenario": "stress", "stress_units": 20, "stress_scenery": 0, "stress_mode": "idle", "scenario_player": true, "ai_fill": false, "fixed_seed": 3}, 0) == OK, "Browser worker must launch")
	if not await wait_for_view():
		check(false, "Browser worker did not load the visual world")
		finish()
		return
	check(LocalServer.pid == -1 and is_instance_valid(LocalServer.worker), "Browser match must run in a worker")
	check_fog_mask()
	var soldier: Node3D
	for unit: Node3D in main.world.soldiers:
		if unit.owner_peer == main.world.local_peer:
			soldier = unit
			break
	check(soldier != null, "Browser player must own troops")
	if soldier:
		check(soldier._native_view_motion, "Browser soldiers must use the batched native presentation path")
		var original: Vector3 = soldier.net_pos
		main.world.cam.focus(original)
		main.world.send_cmd({"t": "move", "squads": [soldier.sid], "pos": original + Vector3(25, 0, 0), "mode": 1})
		await get_tree().create_timer(5.0).timeout
		check(soldier.net_pos.distance_to(original) > 1.0, "Worker commands must produce movement targets")
		check(soldier.position.distance_to(original) > 1.0 and soldier.position.distance_to(soldier.net_pos) < 1.0, "The browser view must follow received movement targets")
	LocalServer.set_speed(0.0)
	await get_tree().create_timer(0.7).timeout
	var paused: float = main.world.time
	await get_tree().create_timer(0.5).timeout
	check(is_equal_approx(paused, main.world.time), "Worker pause must stop the simulation clock")
	var recording: String = LocalServer.recording
	main.return_to_menu("")
	var deadline := Time.get_ticks_msec() + 30000
	while not FileAccess.file_exists(recording) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(FileAccess.file_exists(recording), "Leaving must save the worker recording")
	check(LocalServer.play_replay(recording, 86400.0) == OK, "Browser recording must open for replay")
	if await wait_for_view():
		check(LocalServer.replay_status.get("verified", false), "Seeking to the end must independently verify the recording")
		check(main.world.local_team == -1, "Replay must be an observer view")
	else:
		check(false, "Browser replay did not load")
	if main.args.has("observer-source"):
		var viewer: Node = main.open_replay(String(main.args["observer-source"]))
		deadline = Time.get_ticks_msec() + 180000
		while (viewer.sequence < 0 or viewer.busy) and not viewer.failed and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		check(not viewer.failed and viewer.sequence >= 0, "Browser observer archive must load")
		if not viewer.failed and viewer.sequence >= 0:
			viewer.speed = 0
			check(viewer.manifest.format == 2 and not viewer.manifest.verified, "Observer archives must remain distinct from verified command recordings")
			for target in [float(viewer.manifest.duration), 0.0]:
				await viewer.seek(target)
				check(not viewer.failed and main.world.loaded and not main.world.srv and main.world.local_team == -1, "Browser observer seeks must restore a visual-only world")
		print("BROWSER_OBSERVER_TEST failures=%d" % failures)
	finish()

func check_fog_mask() -> void:
	var fog: RefCounted = ClassDB.instantiate("FogSightMask")
	var terrain: TerrainMap = main.world.terrain
	var eyes := PackedVector4Array([Vector4(0, 1000, 0, 56)])
	var mask: PackedByteArray = fog.raster(terrain._native, eyes, terrain.version)
	check(mask.size() == FogView.N * FogView.N and mask.count(255) > 100, "WebAssembly visual fog must sweep the terrain horizon")
	check(mask == fog.raster(terrain._native, eyes, terrain.version), "WebAssembly visual fog must retain cached observers")
	mask = fog.raster(terrain._native, PackedVector4Array(), terrain.version)
	check(mask.size() == FogView.N * FogView.N and mask.count(255) == 0, "Removed observers must leave no visible cells")
	print("BROWSER_FOG_TEST failures=%d" % failures)

func finish() -> void:
	LocalServer.set_speed(0.0)
	if is_instance_valid(main.world) and main.world.cam and not main.world.soldiers.is_empty():
		main.world.director.active = false
		main.world.cam.dist = 55.0
		main.world.cam.focus(main.world.soldiers[0].net_pos)
		await get_tree().create_timer(1.5, true, false, true).timeout
	print("BROWSER_SERVER_TEST failures=%d" % failures)
