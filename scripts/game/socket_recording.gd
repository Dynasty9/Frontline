extends BattleRecording
## An omniscient render stream, cached as data without another battlefield or simulation.

var connection := {}
var settings := {}
var client: SimulationClient
var _records := {}
var _states := {}
var _packets: Array = []
var _surface := {}
var _surface_changes := {}
var _time := 0.0
var _team: Array = [{}, {}]
var _mission := {}
var _report := {}
var _winner := -1
var _roads: Array = [[], [], []]
var _baseline := false

func _ready() -> void:
	_open_recording(String(settings.get("name", "")))
	manifest.format = 2
	if stopped:
		return
	client = SimulationClient.new()
	client.received.connect(_received)
	client.map_received.connect(func(data: Dictionary): initial_map = data; _roads = data.roads)
	client.surface_received.connect(_surface_received)
	client.failed.connect(_interrupted)
	add_child(client)
	if client.connect_to(connection.address, int(connection.port), connection.token, connection.engine) != OK:
		_interrupted("Could not connect the battle recorder.")

func _interrupted(message: String) -> void:
	flush(true)
	stopped = true
	manifest.status = "interrupted"
	_save_manifest()
	push_warning(message)
	if client:
		client.close()

func _surface_received(rect: Rect2i, data: PackedByteArray) -> void:
	var tile := [data.size(), data.compress(FileAccess.COMPRESSION_ZSTD)]
	_surface[rect.position] = tile
	_surface_changes[rect.position] = tile

func _received(kind: int, value: Variant) -> void:
	if stopped:
		return
	match kind:
		SimulationClient.SPAWN:
			var id: int = value[0]
			_records[id] = value.slice(0, 3)
			_states[id] = value[3]
			dirty_static(id)
			if _baseline:
				births.append(value.slice(0, 3))
				_packets.append(_snapshot([id]))
		SimulationClient.SNAPSHOT:
			if not _cache_snapshot(value):
				_interrupted("Invalid state in the battle recording stream.")
				return
			_packets.append(value)
		SimulationClient.PROPS:
			var id := int(value[0])
			if _records.has(id):
				var record: Array = _records[id].duplicate()
				var updated: Dictionary = record[2].duplicate()
				updated.merge(value[1], true)
				record[2] = updated
				_records[id] = record
				dirty_static(id)
				if not props.has(id):
					props[id] = {}
				(props[id] as Dictionary).merge(value[1], true)
		SimulationClient.DESPAWN:
			for id: int in value:
				_records.erase(id)
				_states.erase(id)
				dirty_static(id)
			deaths.append_array(value)
		SimulationClient.ROADS:
			_roads = value
		SimulationClient.HUD:
			_team = value.get("teams", _team)
			_mission = value.get("mission", _mission)
			if _baseline and checkpoint.is_empty():
				initial_map.n = _records.size()
				checkpoint = capture()
				_reset_frame()
				_save_manifest()
		SimulationClient.FX:
			events.append_array(value)
		SimulationClient.REPORT:
			_report = value
		SimulationClient.OVER:
			_winner = int(value)
			_sample()
			flush(true)
		SimulationClient.BASELINE_END:
			_baseline = true
			client.loaded()

func _cache_snapshot(data: PackedByteArray) -> bool:
	if data.size() < 4 or not is_finite(data.decode_float(0)):
		return false
	_time = maxf(_time, data.decode_float(0))
	tick = roundi(_time * 60.0)
	var offset := 4
	while offset < data.size():
		if data.size() - offset < 5:
			return false
		var id := data.decode_u32(offset)
		var count := int(data[offset + 4])
		offset += 5
		if not _records.has(id) or count != (_states[id] as PackedByteArray).size() or data.size() - offset < count:
			return false
		_states[id] = data.slice(offset, offset + count)
		dirty_static(id)
		offset += count
	return true

func _snapshot(ids: Array) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_float(_time)
	for id: int in ids:
		var state: PackedByteArray = _states[id]
		b.put_u32(id)
		b.put_u8(state.size())
		b.put_data(state)
	return b.data_array

func capture() -> Dictionary:
	for block: int in dirty_blocks:
		var records := []
		var packets := []
		var ids := []
		var size := 4
		for id in range(block * 64, (block + 1) * 64):
			if not _records.has(id):
				continue
			records.append(_records[id])
			var count: int = (_states[id] as PackedByteArray).size() + 5
			if size + count > 2000:
				packets.append(_snapshot(ids))
				ids = []
				size = 4
			ids.append(id)
			size += count
		if not ids.is_empty():
			packets.append(_snapshot(ids))
		static_blocks[block] = {"entities": records, "snapshots": packets}
	dirty_blocks.clear()
	var records := []
	var packets := []
	for block: Dictionary in static_blocks.values():
		records.append_array(block.entities)
		for packet: PackedByteArray in block.snapshots:
			var current := packet.duplicate()
			current.encode_float(0, _time)
			packets.append(current)
	return {"time": _time, "entities": records, "snapshots": packets, "team": _team,
		"mission": _mission, "report": _report, "winner": _winner, "roads": _roads,
		"terrain": {"side": initial_map.map_size, "tiles": _surface.values()}}

func _reset_frame() -> void:
	births = []; deaths = []; props = {}; events = []; _packets = []; _surface_changes = {}

func _sample() -> void:
	if checkpoint.is_empty():
		return
	frames.append({"time": _time, "spawn": births, "despawn": deaths, "props": props, "fx": events,
		"snapshots": _packets, "team": _team, "mission": _mission, "report": _report,
		"winner": _winner, "roads": _roads, "terrain": {"side": initial_map.map_size, "tiles": _surface_changes.values()}})
	_reset_frame()

func _process(dt: float) -> void:
	super._process(dt)
	if stopped and client:
		client.close()
		client.queue_free()
		client = null
	if stopped or checkpoint.is_empty() or _time < sample_at:
		return
	sample_at = _time + 0.1 - fmod(_time, 0.1)
	_sample()
	if _time - float(checkpoint.time) >= CHUNK_SECONDS:
		flush()

func flush(final := false) -> void:
	_finish_encoding(true)
	if stopped or checkpoint.is_empty() or (frames.is_empty() and not final):
		return
	if final and (not _packets.is_empty() or not births.is_empty() or not deaths.is_empty() or not props.is_empty() or not events.is_empty() or not _surface_changes.is_empty()):
		_sample()
	var content := {"format": 2, "protocol": Net.NET_VERSION, "checkpoint": checkpoint,
		"frames": frames, "commands": [], "seed": int(settings.get("seed", 1)), "tick": tick, "rng_state": 0}
	if sequence == 0:
		# Only public presentation data belongs here; never serialize connection or lobby tickets.
		content["settings"] = {"seed": int(settings.get("seed", 1))}
		content["map"] = initial_map
	_encode_chunk(content, _time, final)
	if not stopped:
		checkpoint = capture()

func finish() -> void:
	if client:
		client.close()
		client.queue_free()
		client = null
	super.finish()
