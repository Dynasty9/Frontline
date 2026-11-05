extends Node

var world: World
var failures := 0
var starts := 0
var port := 7985
var role := "host"
var output := ""
var children: Array[int] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
		if arg.begins_with("--role="): role = arg.trim_prefix("--role=")
		if arg.begins_with("--result="): output = arg.trim_prefix("--result=")
	Net.game_start.connect(_started)
	Net.net_error.connect(func(message: String): check(false, message))
	if role == "host":
		await _host()
	else:
		await _client()
	_finish()

func _started(settings: Dictionary) -> void:
	starts += 1
	check(settings.has("simulation_connection"), "Lobby must start a Rust view")
	check(not Net.settings.has("simulation_connection"), "Broadcast lobby must not contain private connection tickets")
	if world:
		world.name = "OldWorld"
		world.queue_free()
	world = World.new()
	world.name = "World"
	world.settings = settings
	add_child(world)
	await world.build()

func _loaded(expected := 1) -> bool:
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and failures == 0:
		if starts >= expected and world and world.loaded and not world.soldiers.is_empty():
			check(not world.srv and world.simulation_client != null, "Godot must not simulate lobby battles")
			return true
		await get_tree().process_frame
	check(false, "Lobby simulation did not finish loading")
	return false

func _spawn_client(which: String) -> Array:
	var path := ProjectSettings.globalize_path("user://native-lobby-%d-%s" % [OS.get_process_id(), which])
	var args := PackedStringArray(["--headless", "--max-fps", "120", "--path", ProjectSettings.globalize_path("res://"), "--log-file", path + ".log", "res://tests/native_lobby_test.tscn", "--", "--port=%d" % port, "--role=" + which, "--result=" + path + ".json"])
	var pid := OS.create_process(OS.get_executable_path(), args, false)
	check(pid > 0, "Lobby fixture client must start")
	children.append(pid)
	return [pid, path]

func _wait_client(child: Array) -> void:
	var deadline := Time.get_ticks_msec() + 150000
	while OS.is_process_running(int(child[0])) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(not OS.is_process_running(int(child[0])), "Lobby fixture client timed out")
	var path := String(child[1])
	var result = JSON.parse_string(FileAccess.get_file_as_string(path + ".json")) if FileAccess.file_exists(path + ".json") else null
	check(result is Dictionary and int(result.get("failures", -1)) == 0, "Lobby client failed: " + path + ".log")
	var log := FileAccess.get_file_as_string(path + ".log")
	check(not "SCRIPT ERROR" in log and not "ERROR:" in log, "Lobby client reported script errors: " + path + ".log")

func _host() -> void:
	check(Net.host_game(port, 0, "127.0.0.1") == OK, "Lobby must bind its test port")
	Net.configure({"scenario": "stress", "stress_units": 20, "stress_scenery": 0, "stress_mode": "idle", "scenario_player": true, "ai_fill": false, "fixed_seed": 3})
	var first := _spawn_client("returning")
	var deadline := Time.get_ticks_msec() + 30000
	while Net.players.size() < 2 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(Net.players.size() == 2, "Client must enter the lobby")
	Net.start_game()
	if not await _loaded(): return
	check(LocalServer.networked and LocalServer.pid > 0, "Lobby must own a separate Rust process")
	Net._broadcast_lobby()
	var late := _spawn_client("late")
	await _wait_client(first)
	await _wait_client(late)
	check(int(world.coop.stats.get("pings_in", 0)) == 1, "Only the friendly commander's ping should reach the host")
	check(int(world.coop.stats.get("sketches_in", 0)) == 1, "Only the friendly commander's sketch should reach the host")
	check(int(world.coop.stats.get("taken", 0)) >= 1, "Friendly screen presence must reach the host")
	var pid := LocalServer.pid
	var recording := LocalServer.recording
	var generation := FileAccess.get_file_as_string(LocalServer.session + ".log")
	check(not "SCRIPT ERROR" in generation and not "ERROR:" in generation, "Lobby battlefield generator must complete without errors")
	LocalServer.stop()
	deadline = Time.get_ticks_msec() + 30000
	while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(not OS.is_process_running(pid), "Lobby server must finish its recording")
	var verified := []
	check(OS.execute(LocalServer.executable(), PackedStringArray(["verify", recording]), verified, true) == 0 and "REPLAY_VERIFIED" in "".join(verified), "Lobby commands and reconnects must independently replay")

func _client() -> void:
	Net.my_name = "Lobby " + role
	Net.join_team = 1
	check(Net.join_game("127.0.0.1", port) == OK, "Client must connect to the lobby")
	if role == "returning":
		var deadline := Time.get_ticks_msec() + 30000
		while not Net.settings.get("preparing", false) and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		check(bool(Net.settings.get("preparing", false)), "Lobby must announce map preparation")
		Net.leave()
		await get_tree().create_timer(0.5).timeout
		check(Net.join_game("127.0.0.1", port) == OK, "A connection lost during map preparation must recover")
	if not await _loaded(): return
	check(bool(world.settings.simulation_connection.get("relay", false)), "Remote view must use the established lobby connection")
	check(not world.settings.simulation_connection.has("token"), "Remote player must never receive host or other player tickets")
	var mine: Soldier
	# The baseline can precede the fixed tick that records a returning commander's admission.
	var ownership_deadline := Time.get_ticks_msec() + 5000
	while mine == null and Time.get_ticks_msec() < ownership_deadline:
		for soldier: Soldier in world.soldiers:
			if soldier.owner_peer == world.local_peer or (role == "late" and soldier.team == world.local_team):
				mine = soldier
				break
		if mine == null:
			await get_tree().process_frame
	check(mine != null, "Admitted player must be able to command friendly troops")
	if mine:
		var original := mine.net_pos
		world.coop.ping("look", original, mine.eid)
		world.coop.sketch(PackedVector3Array([original, original + Vector3(10, 0, 0)]))
		world.send_cmd({"t": "move", "squads": [mine.sid], "pos": original + Vector3(30, 0, 0), "mode": 1})
		# Screen presence is expendable; the headless fixture sends the normal heartbeat too.
		var until := Time.get_ticks_msec() + 3000
		while Time.get_ticks_msec() < until:
			check(world.simulation_client.send_presence(CoCommand.Presence.new().encode()) == OK, "Screen presence must enter the relay")
			await get_tree().create_timer(0.1).timeout
		check(mine.net_pos.distance_to(original) > 1.0, "Remote commands must move server-owned troops")
	if role == "returning":
		var old_peer := world.local_peer
		var old_ids := []
		for soldier: Soldier in world.soldiers:
			if soldier.owner_peer == old_peer: old_ids.append(soldier.eid)
		world.simulation_client.close()
		Net.leave()
		await get_tree().create_timer(0.7).timeout
		Net.begin_rejoin()
		check(Net.join_game("127.0.0.1", port) == OK, "Returning player must reconnect")
		if not await _loaded(2): return
		await get_tree().create_timer(0.5).timeout
		check(world.local_peer != old_peer, "Reconnect must exercise a new ENet identity")
		for id: int in old_ids:
			var entity: Entity = world.entity(id)
			check(entity != null and entity.owner_peer == world.local_peer, "Reconnect must reclaim original troops")
	Net.leave()

func _finish() -> void:
	LocalServer.stop()
	Net.leave()
	for pid: int in children:
		if OS.is_process_running(pid): OS.kill(pid)
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify({"failures": failures, "starts": starts}))
	print("NATIVE_LOBBY_TEST role=%s failures=%d starts=%d" % [role, failures, starts])
	get_tree().quit(1 if failures else 0)
