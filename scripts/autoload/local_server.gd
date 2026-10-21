extends Node
## Owns the private simulation process. The child binds only to loopback and
## accepts the launcher token; it never advertises a battle to the matchmaker.

var pid := -1
var session := ""
var token := ""
var starting := false
var connected := false
var child := false
var parent_pid := -1
var _started_ms := 0
var _next_poll := 0
var _team := 0
var _config := {}
var _heartbeat_ms := 0
var _port := 0
var _retry_ms := 0
var _retries := 0
var disconnected_peer := 0
var _lease_value := ""
var _lease_seen_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Net.game_start.connect(func(_s):
		if pid > 0:
			starting = false
			connected = true
			_retries = 0
			_retry_ms = 0)
	Net.net_error.connect(func(message): _debug("network error: " + message))


func launch(options: Dictionary, team: int) -> int:
	if OS.has_feature("web"):
		return ERR_UNAVAILABLE
	stop()
	Net.leave()
	_team = team
	token = Crypto.new().generate_random_bytes(24).hex_encode()
	var folder := "user://local_servers"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	session = ProjectSettings.globalize_path(folder.path_join(token))
	var cfg := options.duplicate(true)
	cfg["parent_pid"] = OS.get_process_id()
	cfg["token"] = token
	cfg["version"] = Net.NET_VERSION
	cfg["team"] = team
	cfg["name"] = Net.my_name
	var file := FileAccess.open(session + ".json", FileAccess.WRITE)
	if file == null:
		return ERR_CANT_CREATE
	file.store_string(JSON.stringify(cfg))
	file.close()
	_write(".heartbeat", {"sequence": Time.get_ticks_msec()})
	var argv := PackedStringArray(["--headless", "--log-file", session + ".log"])
	if not OS.has_feature("template"):
		argv.append_array(["--path", ProjectSettings.globalize_path("res://")])
	argv.append_array(["--", "--managed-server=" + session])
	if options.has("perf_at"):
		argv.append("--perf-at=" + str(options.perf_at))
		argv.append("--perf-duration=" + str(options.get("perf_duration", 10)))
		argv.append("--perf-json=" + session + ".perf.json")
	pid = OS.create_process(OS.get_executable_path(), argv, false)
	_debug("launched pid=%d executable=%s" % [pid, OS.get_executable_path()])
	if pid <= 0:
		stop()
		return ERR_CANT_FORK
	cfg["child_pid"] = pid
	_write(".json", cfg)
	starting = true
	connected = false
	_started_ms = Time.get_ticks_msec()
	return OK


func start_child(path: String) -> void:
	_debug("child starting")
	child = true
	# The headless process has no frames to draw. An uncapped idle loop would
	# consume a core even while waiting for its client to finish loading.
	Engine.max_fps = Engine.physics_ticks_per_second
	session = path
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path + ".json"))
	if not parsed is Dictionary or int(parsed.get("version", -1)) != Net.NET_VERSION:
		_fail_child("Incompatible local server configuration")
		return
	_config = parsed
	token = String(_config.token)
	parent_pid = int(_config.parent_pid)
	var port := 20000 + int(Crypto.new().generate_random_bytes(2).decode_u16(0)) % 30000
	var err := ERR_CANT_CREATE
	for offset in 32:
		err = Net.host_game(port + offset, -1, "127.0.0.1")
		if err == OK:
			port += offset
			break
	if err != OK:
		_fail_child("Could not bind a private server port")
		return
	Net.settings = _config.duplicate(true)
	for key in ["parent_pid", "child_pid", "token", "version", "team", "name", "benchmark_output"]:
		Net.settings.erase(key)
	Net.settings["local_server"] = true
	Net.settings["drop_in"] = false
	Net.settings["ai_fill"] = bool(_config.get("ai_fill", true))
	Net.lobby_updated.connect(_client_registered)
	_write(".ready", {"port": port, "version": Net.NET_VERSION})
	_debug("child listening on %d" % port)
	_started_ms = Time.get_ticks_msec()


func _client_registered() -> void:
	_debug("registered players=%d" % Net.players.size())
	if not Net.in_game and Net.players.size() == 2:
		Net.start_game.call_deferred()


func authorize(candidate: String, version: int) -> bool:
	_debug("authorize child=%s token_match=%s version=%d players=%d" % [child, candidate == token, version, Net.players.size()])
	return not child or (candidate == token and version == Net.NET_VERSION)


func requested_team() -> int:
	return int(_config.get("team", 0))


func set_speed(value: float) -> void:
	if pid > 0 and connected:
		_write(".speed", {"speed": clampf(value, 0.0, 4.0)})


func reconnect() -> bool:
	if child or pid <= 0 or _port <= 0 or not OS.is_process_running(pid) or _retries >= 5:
		return false
	_retries += 1
	connected = false
	starting = true
	_started_ms = Time.get_ticks_msec()
	_retry_ms = _started_ms + 1000
	return true


func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _next_poll:
		return
	_next_poll = now + 200
	if child:
		# On Windows is_process_running only knows children spawned by this
		# process. Observe advancing content with a monotonic clock: filesystem
		# timestamps can be cached or jump when the wall clock is corrected.
		var lease := FileAccess.get_file_as_string(session + ".heartbeat") if FileAccess.file_exists(session + ".heartbeat") else ""
		if lease != _lease_value or _lease_seen_ms == 0:
			_lease_value = lease
			_lease_seen_ms = now
		if FileAccess.file_exists(session + ".stop") or now - _lease_seen_ms > 600000:
			_debug("child exit: launcher lease expired or stopped")
			get_tree().quit()
		elif FileAccess.file_exists(session + ".speed"):
			var speed = JSON.parse_string(FileAccess.get_file_as_string(session + ".speed"))
			DirAccess.remove_absolute(session + ".speed")
			if speed is Dictionary:
				Engine.time_scale = clampf(float(speed.get("speed", 1.0)), 0.0, 4.0)
		return
	if pid <= 0:
		return
	if now >= _heartbeat_ms:
		_heartbeat_ms = now + 1000
		_write(".heartbeat", {"sequence": now})
	if not OS.is_process_running(pid):
		var log_path := session + ".log"
		pid = -1
		starting = false
		connected = false
		Net.net_error.emit("The local simulation stopped. Log: " + log_path)
		return
	if not starting:
		return
	if _retry_ms > 0 and now >= _retry_ms:
		_retry_ms = 0
		Net.join_team = _team
		if Net.join_game("127.0.0.1", _port) != OK and not reconnect():
			stop()
			Net.net_error.emit("Could not reconnect to the local simulation.")
		return
	if Time.get_ticks_msec() - _started_ms > 600000:
		stop()
		Net.net_error.emit("The local simulation did not become ready within ten minutes.")
		return
	if FileAccess.file_exists(session + ".error"):
		var msg := FileAccess.get_file_as_string(session + ".error")
		stop()
		Net.net_error.emit(msg)
		return
	if FileAccess.file_exists(session + ".ready"):
		var ready = JSON.parse_string(FileAccess.get_file_as_string(session + ".ready"))
		if not ready is Dictionary:
			return
		DirAccess.remove_absolute(session + ".ready")
		if int(ready.get("version", -1)) != Net.NET_VERSION:
			stop()
			Net.net_error.emit("The local simulation version does not match the game.")
			return
		Net.join_team = _team
		_port = int(ready.port)
		var err := Net.join_game("127.0.0.1", _port)
		_debug("connecting port=%d result=%d" % [int(ready.port), err])
		if err != OK:
			stop()
			Net.net_error.emit("Could not connect to the local simulation.")


func _write(suffix: String, value: Dictionary) -> void:
	var file := FileAccess.open(session + suffix + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(value))
		file.close()
		var err := DirAccess.rename_absolute(session + suffix + ".tmp", session + suffix)
		if err != OK:
			_debug("session write failed for %s: %d" % [suffix, err])


func _fail_child(message: String) -> void:
	push_error(message)
	var file := FileAccess.open(session + ".error", FileAccess.WRITE)
	if file:
		file.store_string(message)
	get_tree().quit(1)


func stop() -> void:
	if child:
		return
	if pid > 0 and OS.is_process_running(pid):
		_write(".stop", {})
		# The process is owned by this session. Killing it also handles an
		# unresponsive simulation during quit; no save is in progress here.
		OS.kill(pid)
	pid = -1
	starting = false
	connected = false
	_port = 0
	_retry_ms = 0
	_retries = 0
	if not session.is_empty():
		for suffix in [".json", ".ready", ".error", ".stop", ".speed", ".heartbeat"]:
			if FileAccess.file_exists(session + suffix):
				DirAccess.remove_absolute(session + suffix)
	token = ""
	session = ""


func _exit_tree() -> void:
	stop()


func _debug(message: String) -> void:
	if OS.has_environment("FL_DEBUG_LOCAL_SERVER"):
		print("LOCAL_SERVER ", message)
