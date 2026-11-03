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
var client: Node
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

func launch(options: Dictionary, team: int) -> int:
	if OS.has_feature("web"):
		return ERR_UNAVAILABLE
	var server := executable()
	if server.is_empty() or not ClassDB.class_exists("ActorStateCore"):
		return ERR_FILE_NOT_FOUND
	stop()
	Net.leave()
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
	Net.settings = _config.duplicate(true)
	for key in ["team", "name", "version", "benchmark_output", "parent_pid", "child_pid"]:
		Net.settings.erase(key)
	Net.settings["simulation_export"] = session + ".initial"
	Net.game_start.connect(func(settings: Dictionary):
		if not _write(".settings", settings):
			_fail_child("Could not save battlefield settings"))
	Net.start_game.call_deferred()

func authorize(_candidate: String, _version: int) -> bool:
	return not child

func requested_team() -> int:
	return int(_config.get("team", 0))

func set_speed(value: float) -> void:
	if pid > 0 and connected:
		_write(".speed", {"speed": clampf(value, 0.0, 4.0)})

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
		var config := {"bind": "127.0.0.1:0", "players": [{"peer": 1, "team": _team, "name": Net.my_name, "token": token}],
			"ready": session + ".ready", "stop": session + ".stop", "speed": session + ".speed", "error": session + ".error", "lease": session + ".heartbeat"}
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
		_settings["simulation_connection"] = {"address": address[0], "port": int(address[1]), "token": token, "engine": ready.engine, "peer": 1, "team": _team}
		# The recording now owns the initial checkpoint; don't leave the large handoff behind.
		if FileAccess.file_exists(session + ".initial"):
			DirAccess.remove_absolute(session + ".initial")
		starting = false
		connected = true
		Net.host_offline(_team)
		Net._start(_settings)

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
	for suffix in [".json", ".settings", ".initial", ".server", ".ready", ".stop", ".speed", ".heartbeat"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func stop() -> void:
	if child:
		return
	if is_instance_valid(client):
		client.close()
	client = null
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
	_generating = false
	_retry_at = 0
	_retries = 0
	token = ""
	session = ""

func _exit_tree() -> void:
	stop()
