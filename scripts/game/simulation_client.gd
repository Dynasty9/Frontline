class_name SimulationClient
extends Node
## The same socket receives public render state from a local or remote Rust host.

signal received(kind: int, value: Variant)
signal failed(message: String)
signal map_received(data: Dictionary)
signal surface_received(rect: Rect2i, data: PackedByteArray)

const VERSION := Net.SIMULATION_VERSION
const AUTH := 0
const COMMAND := 1
const LOADED := 2
const ACK := 3
const REQUEST_REPORT := 4
const SEND_PRESENCE := 5
const MARK := 6
const SNAPSHOT := 16
const WELCOME := 17
const SPAWN := 18
const PROPS := 19
const DESPAWN := 20
const MAP := 21
const BASELINE_END := 22
const HUD := 23
const FX := 24
const MESSAGE := 25
const OVER := 26
const REPORT := 27
const BLOB := 28
const PLAYBACK := 29
const SURFACE := 30
const ROADS := 31
const PRESENCE := 32
const PING := 33
const SKETCH := 34
const DEED := 35
const MAX_PACKET := 65568
const MAX_RELAY_BYTES := 4 * 1024 * 1024
const MAX_RELAY_PACKETS := 32768
const MAX_MAP := 192 * 1024 * 1024
const FX_FIELDS := ["vvnsn", "vn", "ns", "vv", "vcn", "vvn", "vv", "sv", "vv", "v", "vnnn", "vnn", "v", "vn", "snv", "nvn", "vnn", "vvn", "nv", "nv"]

var world: World
var host: ENetConnection
var peer: ENetPacketPeer
var identity := 0
var team := -1
var connected := false
var playback_info := {}
var _token := ""
var _engine := ""
var _sequence := 0
var _tick := 0
var _fx_tick := 0
var _map_total := 0
var _map_data := PackedByteArray()
var _blob_data := PackedByteArray()
var _blob_kind := 0
var _blob_total := 0
var _side := 0
var surface_ready := false
var _surface_tiles := {}
var _roads_pending := false
var _relay := false
var _relay_at := 0
var _relay_pending: Array = []
var _relay_bytes := 0
var _worker: Node

func connect_worker(worker: Node, engine: String) -> Error:
	close()
	if not is_instance_valid(worker):
		return ERR_CANT_CONNECT
	_worker = worker
	_engine = engine
	connected = true
	_worker.open()
	return OK

func connect_relay(engine: String) -> Error:
	close()
	_engine = engine
	_relay = true
	_relay_at = Time.get_ticks_msec()
	connected = true
	Net.simulation_packet.connect(_relay_packet)
	Net.simulation_failed.connect(_error)
	return Net.rpc_id(1, "_simulation_open")

func _relay_packet(channel: int, data: PackedByteArray) -> void:
	# Godot can deliver a burst of RPCs before this client's next frame.
	if data.size() < 16 or data.size() > MAX_PACKET or _relay_pending.size() >= MAX_RELAY_PACKETS or _relay_bytes + data.size() > MAX_RELAY_BYTES:
		_error("The simulation relay exceeded its receive limit.")
		return
	_relay_pending.append([channel, data])
	_relay_bytes += data.size()

func connect_to(address: String, port: int, token: String, engine: String) -> Error:
	close()
	_token = token
	_engine = engine
	host = ENetConnection.new()
	var error := host.create_host(1, 3)
	if error != OK:
		return error
	peer = host.connect_to_host(address, port, 3)
	if peer == null:
		close()
		return ERR_CANT_CONNECT
	peer.set_timeout(32, 10000, 30000)
	return OK

func close() -> void:
	connected = false
	_worker = null
	identity = 0
	if _relay:
		Net.simulation_packet.disconnect(_relay_packet)
		Net.simulation_failed.disconnect(_error)
	_relay = false
	_relay_pending.clear()
	_relay_bytes = 0
	if host:
		if peer and peer.is_active():
			peer.peer_disconnect_now()
		host.destroy()
	host = null
	peer = null
	_sequence = 0
	_tick = 0
	_fx_tick = 0
	_map_total = 0
	_map_data.clear()
	_blob_data.clear()
	_blob_total = 0
	playback_info.clear()
	_side = 0
	surface_ready = false
	_surface_tiles.clear()
	_roads_pending = false

func _exit_tree() -> void:
	close()

func _error(message: String) -> void:
	close()
	failed.emit(message)

static func packet(kind: int, sequence: int, payload: PackedByteArray) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(16)
	data[0] = 70
	data[1] = 76
	data[2] = 78
	data[3] = 80
	data.encode_u16(4, VERSION)
	data[6] = kind
	data.encode_u64(8, sequence)
	data.append_array(payload)
	return data

func _send(kind: int, payload: PackedByteArray, sequence := 0) -> Error:
	if not connected or payload.size() + 16 > MAX_PACKET:
		return ERR_UNAVAILABLE
	if is_instance_valid(_worker):
		return _worker.send(packet(kind, sequence, payload))
	if _relay:
		if kind == SEND_PRESENCE:
			return Net.rpc_id(1, "_simulation_presence_up", packet(kind, sequence, payload))
		return Net.rpc_id(1, "_simulation_up", packet(kind, sequence, payload))
	if peer == null:
		return ERR_UNAVAILABLE
	return peer.send(1 if kind == SEND_PRESENCE else 0, packet(kind, sequence, payload), 0 if kind == SEND_PRESENCE else ENetPacketPeer.FLAG_RELIABLE)

func send_presence(data: PackedByteArray) -> Error:
	return _send(SEND_PRESENCE, data)

func send_mark(mark: Dictionary) -> Error:
	return _send(MARK, JSON.stringify(SimulationInitial.plain(mark), "", true, true).to_utf8_buffer())

func send_command(command: Dictionary) -> Error:
	return _send(COMMAND, JSON.stringify(SimulationInitial.plain(command), "", true, true).to_utf8_buffer())

func loaded() -> Error:
	return _send(LOADED, PackedByteArray())

func request_report() -> Error:
	return _send(REQUEST_REPORT, PackedByteArray())

func _process(_delta: float) -> void:
	if is_instance_valid(_worker):
		var started := Time.get_ticks_usec()
		for _i in 256:
			var data: PackedByteArray = _worker.read()
			if data.is_empty():
				break
			if not _receive(data.slice(1), int(data[0])):
				_error("The simulation sent an invalid packet.")
				return
			if Time.get_ticks_usec() - started >= 2000:
				break
		flush_surface()
		return
	if _relay:
		if identity == 0 and Time.get_ticks_msec() - _relay_at > 30000:
			_error("The simulation did not answer.")
			return
		var started := Time.get_ticks_usec()
		var ack := _sequence
		var consumed := 0
		while consumed < mini(256, _relay_pending.size()):
			var packet: Array = _relay_pending[consumed]
			consumed += 1
			_relay_bytes -= (packet[1] as PackedByteArray).size()
			if not _receive(packet[1], packet[0]):
				_error("The simulation sent an invalid packet.")
				return
			if not _relay:
				return  # A received event can close the battle.
			if Time.get_ticks_usec() - started >= 2000:
				break
		if consumed > 0:
			_relay_pending = _relay_pending.slice(consumed)
		if _sequence > ack:
			_send(ACK, PackedByteArray(), _sequence)
		flush_surface()
		return
	if host == null:
		return
	var started := Time.get_ticks_usec()
	var ack := _sequence
	for _i in 256:
		var event := host.service(0)
		match int(event[0]):
			ENetConnection.EVENT_NONE:
				break
			ENetConnection.EVENT_ERROR, ENetConnection.EVENT_DISCONNECT:
				_error("The simulation connection closed.")
				return
			ENetConnection.EVENT_CONNECT:
				connected = true
				_send(AUTH, JSON.stringify({"token": _token, "engine": _engine}).to_utf8_buffer())
			ENetConnection.EVENT_RECEIVE:
				var data: PackedByteArray = peer.get_packet()
				if not _receive(data, int(event[3])):
					_error("The simulation sent an invalid packet.")
					return
		if Time.get_ticks_usec() - started >= 2000:
			break
	if _sequence > ack:
		_send(ACK, PackedByteArray(), _sequence)
	if host:
		host.flush()
	flush_surface()

func flush_surface() -> void:
	if not world or not surface_ready:
		return
	if _roads_pending:
		_roads_pending = false
		world._rebuild_roads()
	var started := Time.get_ticks_usec()
	for _i in 4:
		if _surface_tiles.is_empty():
			break
		var key := Vector2i.ZERO
		for candidate: Vector2i in _surface_tiles:
			key = candidate
			break
		var tile: Array = _surface_tiles[key]
		_surface_tiles.erase(key)
		if not world.terrain.import_surface(tile[0], tile[1], tile[2], tile[3]):
			_error("Invalid simulation surface tile.")
			return
		if Time.get_ticks_usec() - started >= 1000:
			break

static func _props(d: Dictionary) -> Dictionary:
	for key: String in ["pos", "size", "vel", "origin", "target", "zc"]:
		if d.get(key) is Array and d[key].size() == 3:
			d[key] = _point(d[key])
	if d.get("tilt") is Array and d.tilt.size() == 2:
		d.tilt = Vector2(float(d.tilt[0]), float(d.tilt[1]))
	if d.get("toss") is Array and d.toss.size() == 4:
		for index in [0, 2, 3]:
			d.toss[index] = _point(d.toss[index])
	return d

static func _point(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func _valid_point(value: Variant) -> bool:
	return value is Array and value.size() == 3 and value.all(func(v: Variant) -> bool: return v is float and is_finite(v) and absf(v) <= 100000)

static func decode_decor(entries: Variant) -> bool:
	if not entries is Array or entries.size() > 200000:
		return false
	for entry in entries:
		if not entry is Array or entry.size() != 4 or not entry[0] is String or not _valid_point(entry[1]) or not entry[2] is float or not is_finite(entry[2]):
			return false
		entry[1] = _point(entry[1])
		if entry[0] == "wire":
			if not entry[3] is Array or entry[3].size() != 2 or not _valid_point(entry[3][0]) or not entry[3][1] is float or not is_finite(entry[3][1]):
				return false
			entry[3][0] = _point(entry[3][0])
		elif entry[0] in ["walk", "curb", "junction", "awning", "fence", "garden", "soft", "drive", "path", "pave", "lot_pave", "drop"]:
			if not _valid_point(entry[3]):
				return false
			entry[3] = _point(entry[3])
		elif entry[3] != null and (not entry[3] is float or not is_finite(entry[3])):
			return false
	return true

static func _block(b: StreamPeerBuffer, limit: int) -> PackedByteArray:
	if b.get_available_bytes() < 4:
		return PackedByteArray()
	var size := b.get_u32()
	if size > limit or size > b.get_available_bytes():
		return PackedByteArray()
	return b.get_data(size)[1]

static func _expanded(data: PackedByteArray, expected: int) -> PackedByteArray:
	if data.size() < 12 or data.slice(0, 8) != SimulationInitial.header("FLZB") or data.decode_u32(8) != expected:
		return PackedByteArray()
	var b := StreamPeerBuffer.new()
	b.data_array = data
	b.seek(12)
	var result := PackedByteArray()
	while result.size() < expected:
		var count := mini(65536, expected - result.size())
		var compressed := _block(b, 65536 + 1024)
		if compressed.is_empty():
			return PackedByteArray()
		var chunk := compressed.decompress(count, FileAccess.COMPRESSION_DEFLATE)
		if chunk.size() != count:
			return PackedByteArray()
		result.append_array(chunk)
	return result if b.get_available_bytes() == 0 else PackedByteArray()

static func _valid_surface(kinds: PackedByteArray, craters: PackedByteArray, heights: PackedFloat32Array, cells: int) -> bool:
	if not ClassDB.class_exists("TerrainCore"):
		return false
	var native: RefCounted = ClassDB.instantiate("TerrainCore")
	return bool(native.valid_surface(kinds, craters, heights, cells))

static func decode_roads(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	var total := 0
	for roads: Variant in value:
		if not roads is Array or roads.size() > 100000:
			return false
		for i in roads.size():
			if not roads[i] is Array or roads[i].size() > 1000000:
				return false
			total += roads[i].size()
			if total > 1000000:
				return false
			var points := PackedVector3Array()
			for p: Variant in roads[i]:
				if not _valid_point(p):
					return false
				points.append(_point(p))
			roads[i] = points
	return true

func _receive(data: PackedByteArray, channel: int) -> bool:
	if data.size() < 16 or data.size() > MAX_PACKET or data.slice(0, 4).get_string_from_utf8() != "FLNP" or data.decode_u16(4) != VERSION or data[7] != 0:
		return false
	var kind := int(data[6])
	var sequence := data.decode_u64(8)
	var payload := data.slice(16)
	if channel != 0:
		if channel == 2 and kind == FX:
			if sequence < _fx_tick:
				return true
			_fx_tick = sequence
			return _dispatch(FX, payload)
		if kind == PRESENCE and channel == 1:
			return _dispatch(kind, payload)
		if kind != SNAPSHOT or channel != 1:
			return false
		if sequence < _tick:
			return true
		_tick = sequence
		if world:
			world._rpc_snap(payload)
		received.emit(kind, payload)
		return true
	if sequence != _sequence + 1:
		return false
	_sequence = sequence
	return _dispatch(kind, payload)

func _dispatch(kind: int, payload: PackedByteArray) -> bool:
	match kind:
		SNAPSHOT:
			# The host's recorder receives reliable snapshots through the same decoder.
			if payload.size() < 4 or not is_finite(payload.decode_float(0)):
				return false
			if world:
				world._rpc_snap(payload)
			received.emit(kind, payload)
		PRESENCE:
			if payload.size() < 101 or payload.size() > 704 or payload.decode_s32(0) <= 0:
				return false
			var data := payload.slice(4)
			if not CoCommand.Presence.new().decode(data):
				return false
			if world and world.coop:
				world.coop._store(payload.decode_s32(0), data)
			received.emit(kind, payload)
		PING, SKETCH, DEED:
			var data = JSON.parse_string(payload.get_string_from_utf8())
			if not data is Array or data.size() != (2 if kind == SKETCH else 4) or not data[0] is float or data[0] <= 0 or data[0] != int(data[0]):
				return false
			if kind == SKETCH:
				if not data[1] is Array or data[1].size() < 2 or data[1].size() > 64:
					return false
				var points := PackedVector2Array()
				for p in data[1]:
					if not p is Array or p.size() != 2 or not p.all(func(v: Variant) -> bool: return v is float and is_finite(v) and absf(v) <= 100000):
						return false
					points.append(Vector2(p[0], p[1]))
				if world and world.coop:
					world.coop._add_sketch(int(data[0]), points)
			else:
				if not data[1] is String or data[1].length() > 1000 or not data[2] is Array or data[2].size() != 3 or not data[2].all(func(v: Variant) -> bool: return v is float and is_finite(v) and absf(v) <= 100000):
					return false
				if kind == PING:
					if not data[1] in CoCommand.PING_KINDS or not data[3] is float or data[3] < 0 or data[3] > 4294967295 or data[3] != int(data[3]):
						return false
					if world and world.coop:
						world.coop._add_ping(int(data[0]), data[1], _point(data[2]), int(data[3]))
				else:
					if not data[3] is bool:
						return false
					if world and world.coop:
						world.coop._add_deed(int(data[0]), data[1], _point(data[2]), data[3])
			received.emit(kind, data)
		SURFACE:
			var tile := decode_surface(payload, _side)
			if tile.is_empty():
				return false
			var rect: Rect2i = tile[0]
			if world:
				_surface_tiles[rect.position] = tile
			surface_received.emit(rect, payload)
			received.emit(kind, rect)
		ROADS:
			var roads = JSON.parse_string(payload.get_string_from_utf8())
			if not decode_roads(roads):
				return false
			if world:
				world.roads = roads
				_roads_pending = true
			received.emit(kind, roads)
		FX:
			var effects = JSON.parse_string(payload.get_string_from_utf8())
			if not effects is Array or effects.size() > 256:
				return false
			for event in effects:
				if not event is Array or event.is_empty() or not event[0] is float:
					return false
				var id := int(event[0])
				if id < 0 or id >= FX_FIELDS.size() or event[0] != id or event.size() != FX_FIELDS[id].length() + 1:
					return false
				for i in range(1, event.size()):
					var field: String = FX_FIELDS[id][i - 1]
					var value: Variant = event[i]
					if field == "n":
						if not value is float or not is_finite(value):
							return false
					elif field == "s":
						if not value is String or value.length() > 1000:
							return false
					else:
						if not value is Array or value.size() != (4 if field == "c" else 3) or not value.all(func(v: Variant) -> bool: return v is float and is_finite(v) and absf(v) <= 100000):
							return false
						event[i] = Color(value[0], value[1], value[2], value[3]) if field == "c" else _point(value)
			if world:
				world._rpc_fx(effects)
			received.emit(kind, effects)
		MESSAGE:
			var message = JSON.parse_string(payload.get_string_from_utf8())
			if not message is Array or message.size() != 4 or not message[0] is float or not message[1] is String or not message[2] is String:
				return false
			if message[3] != null:
				if not message[3] is Array or message[3].size() != 3:
					return false
				message[3] = _point(message[3])
			if world:
				world._rpc_msg(message)
			received.emit(kind, message)
		BLOB:
			if payload.size() < 9:
				return false
			var inner := int(payload[0])
			var total := payload.decode_u32(1)
			var offset := payload.decode_u32(5)
			if inner not in [HUD, REPORT, ROADS] or total <= 0 or total > 16 * 1024 * 1024 or offset != _blob_data.size() or offset + payload.size() - 9 > total:
				return false
			if _blob_total != 0 and (_blob_total != total or _blob_kind != inner):
				return false
			_blob_kind = inner
			_blob_total = total
			_blob_data.append_array(payload.slice(9))
			if _blob_data.size() == total:
				var data := _blob_data
				_blob_data = PackedByteArray()
				_blob_total = 0
				return _dispatch(inner, data)
		WELCOME:
			var d = JSON.parse_string(payload.get_string_from_utf8())
			if not d is Dictionary or String(d.get("engine", "")) != _engine:
				return false
			identity = int(d.peer)
			team = int(d.team)
			if world:
				world.local_peer = identity
				world.local_team = team
				world.view_team = team
				world._join_n = int(d.entities)
			received.emit(kind, d)
		MAP:
			if payload.size() < 8:
				return false
			var total := payload.decode_u32(0)
			var offset := payload.decode_u32(4)
			if total <= 0 or total > MAX_MAP or offset != _map_data.size() or offset + payload.size() - 8 > total or (_map_total != 0 and _map_total != total):
				return false
			_map_total = total
			_map_data.append_array(payload.slice(8))
			if _map_data.size() == total:
				if not _install_map():
					return false
				_map_data.clear()
				_map_total = 0
		SPAWN:
			if payload.size() < 21 or payload.slice(0, 8) != SimulationInitial.header("FLOB"):
				return false
			var b := StreamPeerBuffer.new()
			b.data_array = payload
			b.seek(8)
			var id := b.get_u32()
			var entity_kind := b.get_u8()
			var p = JSON.parse_string(_block(b, 65536).get_string_from_utf8())
			var state := _block(b, 255)
			if id <= 0 or entity_kind >= World.ENT_KINDS.size() or not p is Dictionary or b.get_available_bytes() != 0:
				return false
			var expected: int = [31, 15 if p.get("skind") == "town" else 14, 28, 14, 16][entity_kind]
			if state.size() != expected:
				return false
			var record := [id, World.ENT_KINDS[entity_kind], _props(p), state]
			if world:
				world._rpc_spawn([record])
			received.emit(kind, record)
		PROPS:
			var d = JSON.parse_string(payload.get_string_from_utf8())
			if not d is Array or d.size() != 2 or not d[1] is Dictionary:
				return false
			d[1] = _props(d[1])
			if world:
				world._rpc_props({int(d[0]): d[1]})
			received.emit(kind, d)
		DESPAWN:
			if payload.size() % 4 != 0:
				return false
			var ids := []
			for i in range(0, payload.size(), 4):
				ids.append(payload.decode_u32(i))
			if world:
				world._rpc_despawn(ids)
			received.emit(kind, ids)
		BASELINE_END:
			if not payload.is_empty() or _map_total != 0:
				return false
			if world:
				world._rpc_join_end()
			received.emit(kind, null)
		HUD:
			var d = JSON.parse_string(payload.get_string_from_utf8())
			if not d is Dictionary:
				return false
			if d.get("teams") is Array:
				for t: Dictionary in d.teams:
					if t.is_empty():
						continue
					var squads := {}
					for id: String in t.sq:
						var q: Array = t.sq[id]
						q[1] = _point(q[1])
						q[2] = _point(q[2])
						if q[4] is Array:
							for index in [1, 2, 3]:
								q[4][index] = _point(q[4][index])
						squads[int(id)] = q
					t.sq = squads
					for contact: Array in t.intel:
						contact[0] = _point(contact[0])
					for i in t.marks.size():
						var mark: Array = t.marks[i]
						t.marks[i] = Vector4(float(mark[0]), float(mark[1]), float(mark[2]), float(mark[3]))
				if world:
					world._rpc_team(d.teams)
			if d.get("mission") is Dictionary:
				var m: Dictionary = d.mission
				m.focus = _point(m.focus)
				for objective: Array in m.get("objs", []):
					if objective[4] is Array:
						objective[4] = _point(objective[4])
				if world:
					world._rpc_mission(m)
			received.emit(kind, d)
		OVER:
			var winner = JSON.parse_string(payload.get_string_from_utf8())
			if not winner is float or int(winner) < 0 or int(winner) > 1:
				return false
			if world and world.settings.get("replay", false):
				world.winner = int(winner)
			elif world:
				world._rpc_over(int(winner))
			received.emit(kind, winner)
		REPORT:
			var report = JSON.parse_string(payload.get_string_from_utf8())
			if not report is Dictionary:
				return false
			if world:
				world._rpc_report(report)
			received.emit(kind, report)
		PLAYBACK:
			var status = JSON.parse_string(payload.get_string_from_utf8())
			if not status is Dictionary or not status.get("position") is float or not status.get("duration") is float or not status.get("verified") is bool or not status.get("concluded") is bool:
				return false
			if not is_finite(status.position) or not is_finite(status.duration) or status.position < 0 or status.duration < status.position or status.duration > 86400:
				return false
			playback_info = status
			received.emit(kind, status)
		_:
			return false
	return true

func _install_map() -> bool:
	if _side != 0 or _map_data.slice(0, 8) != SimulationInitial.header("FLVM", 2):
		return false
	var b := StreamPeerBuffer.new()
	b.data_array = _map_data
	b.seek(8)
	var d = JSON.parse_string(_block(b, 16 * 1024 * 1024).get_string_from_utf8())
	var kinds := _block(b, 3072 * 3072)
	var geology := _block(b, 4 * 770 * 770)
	if not d is Dictionary or not d.get("side") is float or not is_finite(d.side) or d.side != int(d.side) or geology.size() % 4 != 0:
		return false
	var heights := geology.to_float32_array()
	var side := int(d.get("side", 0))
	if side < 2 or side > 3072 or kinds.size() != side * side or not Landform.valid(heights, side):
		return false
	var raw := _expanded(_block(b, MAX_MAP), side * side * 16)
	if raw.size() != side * side * 16:
		return false
	var surface := raw.to_float32_array()
	var craters := _expanded(_block(b, MAX_MAP), side * side)
	if b.get_available_bytes() != 0 or not _valid_surface(kinds, craters, surface, side * side):
		return false
	if not decode_water(d.get("water"), side) or not d.get("town") is Array or d.town.size() != 4 or not d.town.all(func(v): return v is float and is_finite(v) and absf(v) <= 100000):
		return false
	if not decode_roads(d.get("roads")):
		return false
	if not decode_decor(d.get("decor")):
		return false
	if world:
		if MapDims.N != side:
			return false
		world._join_landform = heights
		world._join_kinds = kinds
		world._join_surface = surface
		world._join_craters = craters
		world.water.from_dict(d.water)
		world.roads = d.roads
		world.decor = d.decor
		world.town_rect = Rect2(float(d.town[0]), float(d.town[1]), float(d.town[2]), float(d.town[3]))
		world._join_ground = true
		if d.get("mood") is String and Atmosphere.MOODS.has(d.mood):
			world.settings.mood = d.mood
			if world.atmo:
				world.atmo.apply_mood(d.mood)
		world._load_mark("map")
	_side = side
	if not map_received.get_connections().is_empty():
		map_received.emit({"map_size": side, "water": d.water, "roads": d.roads, "decor": d.decor,
			"town": Rect2(float(d.town[0]), float(d.town[1]), float(d.town[2]), float(d.town[3])),
			"kinds": kinds, "landform": heights, "surface": surface.to_byte_array().compress(FileAccess.COMPRESSION_ZSTD),
			"craters": craters.compress(FileAccess.COMPRESSION_ZSTD)})
	received.emit(MAP, {"side": side, "kinds": kinds.size(), "heights": heights.size()})
	return true

static func decode_surface(payload: PackedByteArray, side: int) -> Array:
	if side < 2 or side > 3072 or payload.size() < 36 or payload.size() > 18468 or payload.slice(0, 8) != SimulationInitial.header("FLVT"):
		return []
	var b := StreamPeerBuffer.new()
	b.data_array = payload
	b.seek(8)
	var rect := Rect2i(b.get_u32(), b.get_u32(), b.get_u32(), b.get_u32())
	if rect.position.x < 0 or rect.position.y < 0 or rect.position.x % 32 != 0 or rect.position.y % 32 != 0 or rect.size.x < 1 or rect.size.y < 1 or rect.size.x > 32 or rect.size.y > 32 or rect.end.x > side or rect.end.y > side:
		return []
	if rect.size != Vector2i(mini(32, side - rect.position.x), mini(32, side - rect.position.y)):
		return []
	var cells := rect.size.x * rect.size.y
	var kinds := _block(b, cells)
	var craters := _block(b, cells)
	var raw := _block(b, cells * 16)
	if raw.size() != cells * 16:
		return []
	var heights := raw.to_float32_array()
	if b.get_available_bytes() != 0 or not _valid_surface(kinds, craters, heights, cells):
		return []
	return [rect, kinds, craters, heights]

static func decode_water(water: Variant, side: int) -> bool:
	if not water is Dictionary or not water.get("coast") is Dictionary:
		return false
	for key in ["rivers", "ponds", "fords", "bridges"]:
		if not water.get(key) is Array or water[key].size() > 4096:
			return false
	var total := 0
	for river: Variant in water.rivers:
		if not river is Dictionary or not river.get("pts") is Array or river.pts.size() > 65536:
			return false
		total += river.pts.size()
		if total > 65536:
			return false
		var points := PackedVector3Array()
		for p: Variant in river.pts:
			if not _valid_point(p):
				return false
			points.append(_point(p))
		river.pts = points
	for pond: Variant in water.ponds:
		if not pond is Dictionary or not _valid_point(pond.get("c")):
			return false
		pond.c = _point(pond.c)
	for i in water.fords.size():
		if not _valid_point(water.fords[i]):
			return false
		water.fords[i] = _point(water.fords[i])
	for bridge: Variant in water.bridges:
		if not bridge is Array or bridge.size() != 4 or not _valid_point(bridge[0]) or not _valid_point(bridge[1]) or not bridge[3] in ["bridge", "quay"]:
			return false
		bridge[0] = _point(bridge[0])
		bridge[1] = _point(bridge[1])
	if not ClassDB.class_exists("WaterRaster"):
		return false
	var native: RefCounted = ClassDB.instantiate("WaterRaster")
	return bool(native.configure(side, water))
