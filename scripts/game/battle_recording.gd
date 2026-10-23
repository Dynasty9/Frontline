class_name BattleRecording
extends Node
## The observer's state, plus tick-ordered inputs kept for future validation.
## Watching never re-simulates combat and never awards progress.

const FORMAT := 1
const CHUNK_SECONDS := 2.0
const MAX_BYTES := 256 * 1024 * 1024
var world: World
var folder := ""
var manifest := {}
var checkpoint := {}
var initial_map := {}
var frames: Array = []
var commands: Array = []
var events: Array = []
var births: Array = []
var deaths: Array = []
var props := {}
var tick := 0
var sequence := 0
var sample_at := 0.0
var static_at := 0.0
var stopped := false
var bytes := 0
var replay_id := ""
var replay_token := ""
var uploading := false
var uploaded := 0
var retry_at := 0
var detached := false

func _ready() -> void:
	var main := get_tree().root.get_node("Main")
	folder = String(main.args.get("record-replay", "user://replays/%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]))
	if folder == "1":
		folder = "user://replays/%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		stopped = true
		push_warning("Could not create the replay folder.")
		return
	manifest = {"format": FORMAT, "protocol": Net.NET_VERSION, "version": Updater.version,
		"name": String(world.settings.get("name", "")).strip_edges() if not String(world.settings.get("name", "")).is_empty() else "Frontline battle", "verified": false, "chunks": [], "duration": 0.0, "status": "live"}
	checkpoint = capture()
	initial_map = {"map_size": MapDims.N, "n": checkpoint.entities.size(), "water": world.water.to_dict().duplicate(true), "roads": world.roads.duplicate(true),
		"decor": world.decor.duplicate(true), "town": world.town_rect, "kinds": world.terrain.base.duplicate()}
	_save_manifest()

func capture() -> Dictionary:
	var records: Array = []
	var entities: Array = []
	for e in world.entities.values():
		if not e.gone:
			records.append([e.eid, e.ekind(), e.get_props().duplicate(true)])
			entities.append(e)
	return {"time": world.time, "entities": records, "snapshots": world._build_snapshot(entities, -1),
		"team": world.team_info.duplicate(true), "mission": world.mission_info.duplicate(true), "winner": world.winner,
		"report": world.report.duplicate(true), "roads": world.roads.duplicate(true)}

func before_tick() -> void:
	tick += 1

func changed(id: int, values: Dictionary) -> void:
	if stopped:
		return
	if not props.has(id):
		props[id] = {}
	(props[id] as Dictionary).merge(values.duplicate(true), true)

func after_tick() -> void:
	if stopped or world.time < sample_at:
		return
	sample_at = world.time + 0.1
	var moving: Array = []
	var include_static := world.time >= static_at
	if include_static:
		static_at = world.time + 1.0
	for e in world.entities.values():
		if not e.gone and (not e.is_static() or include_static):
			moving.append(e)
	frames.append({"time": world.time, "spawn": births, "despawn": deaths, "props": props,
		"fx": events, "snapshots": world._build_snapshot(moving, -1), "team": world.team_info.duplicate(true),
		"mission": world.mission_info.duplicate(true), "winner": world.winner, "report": world.report.duplicate(true)})
	births = []; deaths = []; props = {}; events = []
	if world.time - float(checkpoint.time) >= CHUNK_SECONDS or world.winner >= 0:
		flush(world.winner >= 0)

func order(peer: int, command: Dictionary) -> void:
	if not stopped:
		commands.append({"tick": tick, "order": commands.size(), "peer": peer, "command": command.duplicate(true)})

func flush(final := false) -> void:
	if stopped or (frames.is_empty() and not final):
		return
	var content := {"format": FORMAT, "protocol": Net.NET_VERSION, "checkpoint": checkpoint,
		"frames": frames, "commands": commands, "seed": world.settings.get("seed", 1),
		"tick": tick, "rng_state": world.rng.state}
	if sequence == 0:
		content["settings"] = world.settings.duplicate(true)
		content["map"] = initial_map
	var raw := var_to_bytes(content)
	var body := {"sequence": sequence, "start": checkpoint.time, "end": world.time, "final": final,
		"size": raw.size(), "data": Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_ZSTD))}
	var json := JSON.stringify(body)
	bytes += json.length()
	if bytes > MAX_BYTES or json.length() > 12 * 1024 * 1024 - 1024 or world.time > 14400:
		stopped = true
		manifest.status = "interrupted"
		_save_manifest()
		push_warning("Recording reached its size or duration limit; the saved part is still watchable.")
		return
	var file := FileAccess.open(folder.path_join("%d.json" % sequence), FileAccess.WRITE)
	if file == null:
		stopped = true
		push_warning("Could not save the replay chunk.")
		return
	file.store_string(json)
	if file.get_error() != OK:
		stopped = true
		push_warning("The replay could not be saved: check available disk space.")
		return
	file.close()
	manifest.chunks.append({"sequence": sequence, "start": checkpoint.time, "end": world.time})
	manifest.duration = world.time
	manifest.status = "complete" if final else "live"
	_save_manifest()
	sequence += 1
	frames = []; commands = []
	stopped = final
	if not final:
		checkpoint = capture()

func _save_manifest() -> void:
	var f := FileAccess.open(folder.path_join("index.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(manifest))

func _process(_dt: float) -> void:
	if detached and not uploading and (uploaded >= sequence or replay_id.is_empty()):
		queue_free()
		return
	if uploading or Time.get_ticks_msec() < retry_at or sequence <= uploaded:
		return
	# A private, LAN-only, or unlisted game stays on this machine.
	if replay_id.is_empty() and (Online.lobby_id.is_empty() or bool(Net.settings.get("locked", false))):
		return
	_upload()

func _upload() -> void:
	uploading = true
	var previous_uploaded := uploaded
	if replay_id.is_empty():
		var r: Dictionary = await Online._request(HTTPClient.METHOD_POST, "/replays",
			{"lobby": Online.lobby_id, "format": FORMAT, "protocol": Net.NET_VERSION, "version": Updater.version},
			PackedStringArray(["X-Lobby-Token: " + Online._lobby_token]), 15.0, false)
		if r.get("ok", false):
			var data: Dictionary = r.get("data", {})
			replay_id = String(data.get("id", ""))
			replay_token = String(data.get("token", ""))
	if not replay_id.is_empty():
		var body = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("%d.json" % uploaded)))
		var r: Dictionary = await Online._request(HTTPClient.METHOD_POST, "/replays/%s/chunks" % replay_id, body,
			PackedStringArray(["Authorization: Bearer " + replay_token]), 30.0, false)
		if r.get("ok", false):
			uploaded += 1
	uploading = false
	retry_at = Time.get_ticks_msec() + (5000 if uploaded == previous_uploaded else 0)

func _exit_tree() -> void:
	flush(true)


func finish() -> void:
	flush(true)
	stopped = true
	detached = true
	reparent(Online)
