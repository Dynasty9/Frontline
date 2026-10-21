extends Node

var world: World
var failures := 0
var error_seen := false
var starts := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	Net.game_start.connect(_started)
	Net.net_error.connect(func(_message): error_seen = true)
	check(LocalServer.launch({"scenario": "stress", "stress_units": 20, "stress_scenery": 0, "stress_mode": "idle", "scenario_player": true, "ai_fill": false, "fixed_seed": 3}, 0) == OK, "Private server must launch")
	var deadline := Time.get_ticks_msec() + 120000
	while (world == null or world.client_loading() or world.soldiers.size() < 10) and Time.get_ticks_msec() < deadline and not error_seen:
		await get_tree().process_frame
	if world == null or world.soldiers.is_empty():
		check(false, "Private server did not replicate the world")
		_finish()
		return
	check(LocalServer.connected and not world.srv, "Local game must simulate in a separate process")
	var own: Soldier
	for soldier: Soldier in world.soldiers:
		if soldier.owner_peer == world.local_peer:
			own = soldier
			break
	check(own != null, "The launcher must own its troops")
	if own:
		var original := own.net_pos
		world.send_cmd({"t": "move", "squads": [own.sid], "pos": original + Vector3(25, 0, 0), "mode": 1})
		await get_tree().create_timer(4.0).timeout
		check(own.net_pos.distance_to(original) > 1.0, "Commands must reach the server and replicate movement")
		LocalServer.set_speed(0.0)
		await get_tree().create_timer(0.7).timeout
		var paused := own.net_pos
		await get_tree().create_timer(0.8).timeout
		check(own.net_pos.distance_to(paused) < 0.01, "Paused simulation must stop moving")
		LocalServer.set_speed(1.0)
		await get_tree().create_timer(1.5).timeout
		check(own.net_pos.distance_to(paused) > 0.1, "Paused server must accept resume while its clock is stopped")
	var before := world.soldiers.size()
	var old_pid := LocalServer.pid
	multiplayer.multiplayer_peer.close()
	Net._on_server_disconnected()
	deadline = Time.get_ticks_msec() + 30000
	while (starts < 2 or world.client_loading() or world.soldiers.size() < before) and Time.get_ticks_msec() < deadline and not error_seen:
		await get_tree().process_frame
	check(starts == 2 and LocalServer.pid == old_pid and world.soldiers.size() == before, "Reconnect must reclaim the same simulation without duplicating troops")
	var mine := 0
	for soldier: Soldier in world.soldiers:
		if soldier.owner_peer == world.local_peer:
			mine += 1
	check(mine > 0, "Reconnect must restore command ownership")
	LocalServer.stop()
	check(not OS.is_process_running(old_pid), "Leaving must stop the owned child")
	check(not error_seen, "The healthy session must not report a network error")
	check(LocalServer.launch({"scenario": "stress", "stress_units": 2, "stress_scenery": 0, "stress_mode": "idle", "ai_fill": false}, -1) == OK, "A new session must launch after leaving")
	deadline = Time.get_ticks_msec() + 120000
	while starts < 3 and Time.get_ticks_msec() < deadline and not error_seen:
		await get_tree().process_frame
	var crash_pid := LocalServer.pid
	check(crash_pid > 0, "The replacement child must exist")
	if crash_pid > 0:
		OS.kill(crash_pid)
		deadline = Time.get_ticks_msec() + 5000
		while not error_seen and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		check(error_seen and not LocalServer.connected, "A child crash must report failure and clear connection state")
	_finish()


func _started(settings: Dictionary) -> void:
	starts += 1
	if world:
		world.name = "OldWorld"
		world.queue_free()
	world = World.new()
	world.name = "World"
	world.settings = settings
	add_child(world)
	await world.build()


func _finish() -> void:
	LocalServer.stop()
	Net.leave()
	print("LOCAL_SERVER_TEST failures=%d starts=%d" % [failures, starts])
	get_tree().quit(1 if failures else 0)
