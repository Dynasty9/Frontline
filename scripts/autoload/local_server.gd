extends Node
## Godot prepares the battlefield once; a private Rust process owns every match tick.

var pid := -1
var session := ""
var token := ""
var starting := false
var connected := false
var child := false
var disconnected_peer := 0
var recording := ""
var replaying := false
var networked := false
var replay_status := {}
var startup_ms := {}
var client: Node
var worker: Node
var _generating := false
var _started_ms := 0
var _next_poll := 0
var _heartbeat_at := 0
var _team := 0
var _config := {}
var _settings := {}
var _server := ""
var _retry_at := 0
var _retries := 0
var _retiring: Array = []
var _admissions := {}
var _relays := {}
var _connection := {}
var _relay_waiting := {}
var _admission_revision := 0
var broadcast: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func executable() -> String:
	var name := "frontline-server.exe" if OS.get_name() == "Windows" else "frontline-server"
	if not OS.has_feature("template"):
		var override := OS.get_environment("FRONTLINE_SERVER")
		if not override.is_empty() and FileAccess.file_exists(override):
			return override
		for folder in ["res://bin/native", "res://bin/native/macos", "res://native/target/release", "res://native/target/debug"]:
			var candidate := ProjectSettings.globalize_path(folder.path_join(name))
			if FileAccess.file_exists(candidate):
				return candidate
	var bundled := OS.get_executable_path().get_base_dir().path_join(name)
	if OS.get_name() == "macOS":
		bundled = OS.get_executable_path().get_base_dir().get_base_dir().path_join("Helpers/" + name)
	return bundled if FileAccess.file_exists(bundled) else ""

func launch(options: Dictionary, team: int, lobby := false) -> int:
	if OS.has_feature("web"):
		if lobby or not ClassDB.class_exists("ActorStateCore"):
			return ERR_UNAVAILABLE
		stop()
		Net.leave()
		var error := _new_worker(true)
		if error != OK:
			return error
		Net.host_offline(team)
		Net.settings = options.duplicate(true)
		Net.settings["simulation_export"] = ""
		Net.start_game()
		starting = true
		return OK
	var server := executable()
	if server.is_empty() or not ClassDB.class_exists("ActorStateCore"):
		return ERR_FILE_NOT_FOUND
	stop()
	if not lobby:
		Net.leave()
	networked = lobby
	_server = server
	_team = team
	token = Crypto.new().generate_random_bytes(24).hex_encode()
	for folder in ["user://local_servers", "user://replays"]:
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		if error != OK:
			return error
	session = ProjectSettings.globalize_path("user://local_servers".path_join(token))
	recording = ProjectSettings.globalize_path("user://replays".path_join("battle-" + token + ".flrp"))
	_config = options.duplicate(true)
	if networked:
		for id: int in Net.players:
			admit_player(id, 0, false)
	var main := get_tree().root.get_node("Main")
	var args: Dictionary = main.args if "args" in main else {}
	if (networked and Online.record_battles) or args.has("record-replay"):
		_admissions[-1] = {"peer": -1, "team": -1, "name": "Battle recorder", "token": Crypto.new().generate_random_bytes(24).hex_encode()}
	_config.merge({"team": team, "name": Net.my_name, "version": Net.NET_VERSION, "parent_pid": OS.get_process_id()}, true)
	if not _write(".json", _config):
		return ERR_CANT_CREATE
	var argv := PackedStringArray(["--headless", "--log-file", session + ".log"])
	if not OS.has_feature("template"):
		argv.append_array(["--path", ProjectSettings.globalize_path("res://")])
	argv.append_array(["--", "--managed-server=" + session])
	pid = OS.create_process(OS.get_executable_path(), argv, false)
	if pid <= 0:
		stop()
		return ERR_CANT_FORK
	_generating = true
	starting = true
	_started_ms = Time.get_ticks_msec()
	startup_ms = {}
	return OK

func start_child(path: String) -> void:
	child = true
	session = path
	Engine.max_fps = Engine.physics_ticks_per_second
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path + ".json"))
	if not parsed is Dictionary or int(parsed.get("version", -1)) != Net.NET_VERSION:
		_fail_child("Incompatible battlefield generator configuration")
		return
	_config = parsed
	Net.my_name = String(_config.name)
	Net.host_offline(int(_config.team))
	if _config.get("players") is Dictionary:
		Net.players.clear()
		for id: String in _config.players:
			Net.players[int(id)] = _config.players[id]
	Net.settings = _config.duplicate(true)
	for key in ["team", "name", "version", "benchmark_output", "parent_pid", "child_pid"]:
		Net.settings.erase(key)
	Net.settings["simulation_export"] = session + ".initial"
	Net.game_start.connect(func(settings: Dictionary):
		if not _write(".settings", settings):
			_fail_child("Could not save battlefield settings"))
	Net.start_game.call_deferred()

func play_replay(source: String, seconds := 0.0) -> int:
	if OS.has_feature("web"):
		if not FileAccess.file_exists(source):
			return ERR_FILE_NOT_FOUND
		stop()
		Net.leave()
		var error := _new_worker(false)
		if error != OK:
			return error
		replaying = true
		starting = true
		_settings = {"replay": true, "players": {1: {"team": -1, "name": "Observer"}}}
		worker.start.call_deferred(FileAccess.get_file_as_bytes(source), true, maxi(0, roundi(seconds * 60.0)))
		return OK
	var server := executable()
	if server.is_empty() or not FileAccess.file_exists(source):
		return ERR_FILE_NOT_FOUND
	stop()
	Net.leave()
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://local_servers"))
	if error != OK:
		return error
	_server = server
	replaying = true
	_team = -1
	token = Crypto.new().generate_random_bytes(24).hex_encode()
	session = ProjectSettings.globalize_path("user://local_servers".path_join(token))
	_settings = {"replay": true, "players": {1: {"team": -1, "name": "Observer"}}}
	var config := {"bind": "127.0.0.1:0", "players": [{"peer": 1, "team": -1, "name": "Observer", "token": token}],
		"ready": session + ".ready", "stop": session + ".stop", "speed": session + ".speed", "error": session + ".error", "lease": session + ".heartbeat", "seek": maxi(0, roundi(seconds * 60.0))}
	# Keep the seek position exact until the viewer has installed its baseline.
	if not _write(".server", config) or not _write(".speed", {"speed": 0.0}):
		stop()
		return ERR_CANT_CREATE
	pid = OS.create_process(_server, PackedStringArray(["play", ProjectSettings.globalize_path(source), session + ".server"]), false)
	if pid <= 0:
		stop()
		return ERR_CANT_FORK
	starting = true
	_started_ms = Time.get_ticks_msec()
	return OK

func authorize(_candidate: String, _version: int) -> bool:
	return not child

func requested_team() -> int:
	return int(_config.get("team", 0))

func set_speed(value: float) -> void:
	if is_instance_valid(worker) and connected:
		worker.set_speed(value)
	if pid > 0 and connected:
		_write(".speed", {"speed": clampf(value, 0.0, 4.0)})

func _new_worker(save_recording: bool) -> Error:
	if save_recording:
		var error := DirAccess.make_dir_recursive_absolute("user://replays")
		if error != OK:
			return error
		recording = "user://replays/battle-" + Crypto.new().generate_random_bytes(16).hex_encode() + ".flrp"
	worker = GameScripts.load_script("res://scripts/game/browser_server.gd").new()
	worker.recording = recording if save_recording else ""
	worker.available.connect(_worker_ready)
	worker.failed.connect(_fail)
	add_child(worker)
	return OK

func generated(bytes: PackedByteArray, settings: Dictionary) -> void:
	if not is_instance_valid(worker):
		return
	if bytes.is_empty():
		_fail("Could not prepare the battlefield for the simulation.")
		return
	_settings = settings.duplicate(true)
	_settings.erase("simulation_export")
	worker.start(bytes, false, 0)

func _worker_ready(metadata: Dictionary) -> void:
	if not metadata.get("engine") is String or not int(metadata.get("side", 0)) in [1024, 2048, 3072] or not int(metadata.get("team", -2)) in [-1, 0, 1]:
		_fail("Invalid browser simulation metadata.")
		return
	_team = int(metadata.team)
	_settings.map_size = int(metadata.side)
	if replaying:
		if not metadata.get("replay") is Dictionary:
			_fail("Invalid replay metadata.")
			return
		replay_status = metadata.replay
		_settings.mood = String(metadata.get("mood", "clear"))
	_settings.simulation_connection = {"worker": true, "engine": metadata.engine, "peer": int(metadata.peer), "team": _team}
	starting = false
	connected = true
	Net.host_offline(_team)
	Net._start(_settings)

func reconnect() -> bool:
	if child or pid <= 0 or _generating or not OS.is_process_running(pid) or _retries >= 10:
		return false
	_retries += 1
	connected = false
	starting = true
	_started_ms = Time.get_ticks_msec()
	_retry_at = _started_ms + mini(1000 * _retries, 5000)
	return true

func client_loaded() -> void:
	if _config.has("perf_at") and not replaying and not session.is_empty() and _retries == 0:
		startup_ms["client_ready"] = Time.get_ticks_msec() - _started_ms
		_write(".startup", startup_ms)
	_retries = 0

func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_poll or child:
		return
	_next_poll = now + 200
	for i in range(_retiring.size() - 1, -1, -1):
		var old: Array = _retiring[i]
		if not OS.is_process_running(int(old[0])):
			_cleanup(String(old[1]))
			_retiring.remove_at(i)
	if pid <= 0:
		return
	if now >= _heartbeat_at:
		_heartbeat_at = now + 1000
		_write(".heartbeat", {"sequence": now})
	if FileAccess.file_exists(session + ".error"):
		_fail(FileAccess.get_file_as_string(session + ".error"))
		return
	if _generating:
		if OS.is_process_running(pid):
			if now - _started_ms > 600000:
				_fail("The battlefield did not finish generating within ten minutes.")
			return
		startup_ms["generated"] = now - _started_ms
		pid = -1
		if not FileAccess.file_exists(session + ".initial") or not FileAccess.file_exists(session + ".settings"):
			_fail("Could not prepare the battlefield. Log: " + session + ".log")
			return
		var settings = JSON.parse_string(FileAccess.get_file_as_string(session + ".settings"))
		if not settings is Dictionary or not settings.get("players") is Dictionary:
			_fail("Invalid generated battlefield settings.")
			return
		_settings = settings
		_settings.erase("simulation_export")
		var players := {}
		for id: String in _settings.players:
			players[int(id)] = _settings.players[id]
		_settings.players = players
		_team = int(players[1].team)
		var config := {"bind": "127.0.0.1:0", "players": _admissions.values() if networked else [{"peer": 1, "team": _team, "name": Net.my_name, "token": token}],
			"ready": session + ".ready", "stop": session + ".stop", "speed": session + ".speed", "error": session + ".error", "lease": session + ".heartbeat"}
		if not networked and _admissions.has(-1):
			config.players.append(_admissions[-1])
		if networked:
			for id: int in Net.players:
				admit_player(id, 0, false)
			config.players = _admissions.values()
			config["admissions"] = session + ".admissions"
		if _config.has("perf_at"):
			config["profile"] = {"path": session + ".perf.json", "warmup": _config.perf_at, "duration": _config.get("perf_duration", 10.0)}
		if not _write(".server", config):
			_fail("Could not save simulation configuration.")
			return
		pid = OS.create_process(_server, PackedStringArray(["serve", session + ".initial", session + ".server", recording]), false)
		_generating = false
		if pid <= 0:
			_fail("Could not start the Rust simulation.")
		else:
			_config["child_pid"] = pid
			_write(".json", _config)
		return
	if not OS.is_process_running(pid):
		pid = -1
		_fail("The local simulation stopped. Recording: " + recording)
		return
	if networked and not _relay_waiting.is_empty():
		_open_relays()
	if not starting:
		return
	if now < _retry_at:
		return
	if now - _started_ms > 600000:
		_fail("The local simulation did not become ready within ten minutes.")
		return
	if FileAccess.file_exists(session + ".ready"):
		var ready = JSON.parse_string(FileAccess.get_file_as_string(session + ".ready"))
		if not ready is Dictionary:
			return
		if int(ready.get("version", -1)) != Net.SIMULATION_VERSION or not ready.get("address") is String or not ready.get("engine") is String:
			_fail("The local simulation version does not match the game.")
			return
		var address: PackedStringArray = String(ready.address).rsplit(":", true, 1)
		if address.size() != 2:
			_fail("Invalid local simulation address.")
			return
		if replaying:
			if not ready.get("replay") is Dictionary or not int(ready.get("side", 0)) in [1024, 2048, 3072]:
				_fail("Invalid replay battlefield metadata.")
				return
			_settings.map_size = int(ready.side)
			if ready.get("mood") is String:
				_settings.mood = ready.mood
			replay_status = ready.replay
		startup_ms["server_ready"] = now - _started_ms
		_connection = {"address": address[0], "port": int(address[1]), "engine": ready.engine}
		if _admissions.has(-1) and not is_instance_valid(broadcast):
			broadcast = GameScripts.load_script("res://scripts/game/socket_recording.gd").new()
			broadcast.settings = {"name": _settings.get("name", ""), "seed": _settings.get("seed", 1)}
			broadcast.connection = _connection.duplicate()
			broadcast.connection["token"] = _admissions[-1].token
			if networked:
				broadcast.broadcast_started.connect(_publish_admissions)
			add_child(broadcast)
		_settings["simulation_connection"] = {"address": address[0], "port": int(address[1]), "token": token, "engine": ready.engine, "peer": 1, "team": _team}
		# The recording now owns the initial checkpoint; don't leave the large handoff behind.
		if FileAccess.file_exists(session + ".initial"):
			DirAccess.remove_absolute(session + ".initial")
		starting = false
		connected = true
		if networked:
			for id: int in Net.players:
				admit_player(id, 0, false)
			if not _publish_admissions():
				return
			if _retries == 0:
				for id: int in Net.players:
					if id != 1:
						Net._start.rpc_id(id, player_settings(id))
			Net._start(player_settings(1))
		else:
			Net.host_offline(_team)
			Net._start(_settings)

func admit_player(id: int, reclaim := 0, publish := true) -> void:
	if not networked or not Net.players.has(id):
		return
	if not _admissions.has(id):
		var p: Dictionary = Net.players[id]
		var admission := {"peer": id, "team": int(p.team), "name": String(p.name), "token": token if id == 1 else Crypto.new().generate_random_bytes(24).hex_encode()}
		if reclaim > 0:
			admission["reclaim"] = reclaim
		_admissions[id] = admission
	if publish and not _generating:
		_publish_admissions()

func _publish_admissions() -> bool:
	_admission_revision += 1
	if _write(".admissions", {"players": _admissions.values(), "revision": _admission_revision,
		"broadcast": broadcast.replay_id if is_instance_valid(broadcast) else ""}):
		return true
	_fail("Could not update simulation admissions.")
	return false

func remove_player(id: int) -> void:
	if _relays.has(id):
		_relays[id].close()
		_relays[id].queue_free()
		_relays.erase(id)
	_admissions.erase(id)
	_relay_waiting.erase(id)
	if networked and not _generating:
		_publish_admissions()

func player_settings(id: int) -> Dictionary:
	var result := _settings.duplicate(true)
	result.players = Net.players.duplicate(true)
	var config := _connection.duplicate()
	config.merge({"peer": id, "team": int(Net.players[id].team)})
	if id == 1:
		config["token"] = token
	else:
		config = {"relay": true, "engine": _connection.engine, "peer": id, "team": config.team}
	result.simulation_connection = config
	return result

func open_relay(id: int) -> void:
	if not networked or not connected or id == 1 or not _admissions.has(id) or _relays.has(id):
		return
	_relay_waiting[id] = true

func _open_relays() -> void:
	if not FileAccess.file_exists(session + ".admitted"):
		return
	var applied = JSON.parse_string(FileAccess.get_file_as_string(session + ".admitted"))
	if not applied is Dictionary or int(applied.get("revision", -1)) != _admission_revision:
		return
	for id: int in _relay_waiting.keys():
		_relay_waiting.erase(id)
		_start_relay(id)

func _start_relay(id: int) -> void:
	var relay: Node = GameScripts.load_script("res://scripts/game/simulation_relay.gd").new()
	add_child(relay)
	var config := _connection.duplicate()
	config["token"] = _admissions[id].token
	var error: Error = relay.start(id, config)
	if error != OK:
		relay.queue_free()
		Net._simulation_failed.rpc_id(id, "Could not connect to the simulation.")
		return
	_relays[id] = relay

func relay_packet(id: int, data: PackedByteArray, presence := false) -> void:
	if _relays.has(id):
		_relays[id].receive(data, presence)

func _write(suffix: String, value: Dictionary) -> bool:
	var file := FileAccess.open(session + suffix + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "", true, true))
	file.close()
	return DirAccess.rename_absolute(session + suffix + ".tmp", session + suffix) == OK

func _fail_child(message: String) -> void:
	push_error(message)
	var file := FileAccess.open(session + ".error", FileAccess.WRITE)
	if file:
		file.store_string(message)
	get_tree().quit(1)

func _fail(message: String) -> void:
	stop()
	Net.net_error.emit(message)

func _cleanup(path: String) -> void:
	for suffix in [".json", ".settings", ".initial", ".server", ".ready", ".stop", ".speed", ".heartbeat", ".admissions", ".admitted"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func stop() -> void:
	if child:
		return
	if is_instance_valid(broadcast):
		broadcast.finish()
		broadcast = null
	for relay: Node in _relays.values():
		relay.close()
		relay.queue_free()
	_relays.clear()
	_admissions.clear()
	_connection.clear()
	_relay_waiting.clear()
	_admission_revision = 0
	networked = false
	if is_instance_valid(client):
		client.close()
	client = null
	if is_instance_valid(worker):
		# The worker finishes its recording after the old view has gone away.
		worker.available.disconnect(_worker_ready)
		worker.failed.disconnect(_fail)
		worker.failed.connect(func(message: String): Net.net_error.emit(message))
		worker.stop()
		worker = null
	if pid > 0 and OS.is_process_running(pid):
		if _generating:
			OS.kill(pid)
		else:
			# Finishing the recording may outlive the window; never kill a replay write.
			_write(".stop", {})
		_retiring.append([pid, session])
	elif not session.is_empty():
		_cleanup(session)
	pid = -1
	starting = false
	connected = false
	replaying = false
	replay_status = {}
	_generating = false
	_retry_at = 0
	_retries = 0
	token = ""
	session = ""

func _exit_tree() -> void:
	stop()
