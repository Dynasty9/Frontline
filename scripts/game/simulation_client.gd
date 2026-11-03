class_name SimulationClient
extends Node
## The same socket receives public render state from a local or remote Rust host.

signal received(kind: int, value: Variant)
signal failed(message: String)

const VERSION := Net.SIMULATION_VERSION
const AUTH := 0
const COMMAND := 1
const LOADED := 2
const ACK := 3
const REQUEST_REPORT := 4
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
const MAX_PACKET := 65568
const MAX_MAP := 64 * 1024 * 1024
const FX_FIELDS := ["vvnsn", "vn", "ns", "vv", "vcn", "vvn", "vv", "sv", "vv", "v", "vnnn", "vnn", "v", "vn", "snv", "nvn", "vnn", "vvn", "nv"]

var world: World
var host: ENetConnection
var peer: ENetPacketPeer
var identity := 0
var team := -1
var connected := false
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
	if host:
		if peer:
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
	if not connected or peer == null or payload.size() + 16 > MAX_PACKET:
		return ERR_UNAVAILABLE
	return peer.send(0, packet(kind, sequence, payload), ENetPacketPeer.FLAG_RELIABLE)

func send_command(command: Dictionary) -> Error:
	return _send(COMMAND, JSON.stringify(SimulationInitial.plain(command), "", true, true).to_utf8_buffer())

func loaded() -> Error:
	return _send(LOADED, PackedByteArray())

func request_report() -> Error:
	return _send(REQUEST_REPORT, PackedByteArray())

func _process(_delta: float) -> void:
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

static func _block(b: StreamPeerBuffer, limit: int) -> PackedByteArray:
	if b.get_available_bytes() < 4:
		return PackedByteArray()
	var size := b.get_u32()
	if size > limit or size > b.get_available_bytes():
		return PackedByteArray()
	return b.get_data(size)[1]

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
			if inner not in [HUD, REPORT] or total <= 0 or total > 16 * 1024 * 1024 or offset != _blob_data.size() or offset + payload.size() - 9 > total:
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
			if world:
				world._rpc_props({int(d[0]): _props(d[1])})
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
			if world and d.get("teams") is Array:
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
				world._rpc_team(d.teams)
			if world and d.get("mission") is Dictionary:
				var m: Dictionary = d.mission
				m.focus = _point(m.focus)
				for objective: Array in m.get("objs", []):
					if objective[4] is Array:
						objective[4] = _point(objective[4])
				world._rpc_mission(m)
			received.emit(kind, d)
		OVER:
			var winner = JSON.parse_string(payload.get_string_from_utf8())
			if not winner is float or int(winner) < 0 or int(winner) > 1:
				return false
			if world:
				world._rpc_over(int(winner))
			received.emit(kind, winner)
		REPORT:
			var report = JSON.parse_string(payload.get_string_from_utf8())
			if not report is Dictionary:
				return false
			if world:
				world._rpc_report(report)
			received.emit(kind, report)
		_:
			return false
	return true

func _install_map() -> bool:
	if _map_data.slice(0, 8) != SimulationInitial.header("FLVM"):
		return false
	var b := StreamPeerBuffer.new()
	b.data_array = _map_data
	b.seek(8)
	var d = JSON.parse_string(_block(b, 16 * 1024 * 1024).get_string_from_utf8())
	var kinds := _block(b, 3072 * 3072)
	var heights := _block(b, 4 * 770 * 770).to_float32_array()
	if not d is Dictionary or b.get_available_bytes() != 0:
		return false
	var side := int(d.get("side", 0))
	if side < 2 or side > 3072 or kinds.size() != side * side or not Landform.valid(heights, side):
		return false
	for river: Dictionary in d.water.rivers:
		var points := PackedVector3Array()
		for p: Array in river.pts:
			points.append(_point(p))
		river.pts = points
	for pond: Dictionary in d.water.ponds:
		pond.c = _point(pond.c)
	for i in d.water.fords.size():
		d.water.fords[i] = _point(d.water.fords[i])
	for bridge: Array in d.water.bridges:
		bridge[0] = _point(bridge[0])
		bridge[1] = _point(bridge[1])
	for roads: Array in d.roads:
		for i in roads.size():
			var points := PackedVector3Array()
			for p: Array in roads[i]:
				points.append(_point(p))
			roads[i] = points
	for entry: Array in d.decor:
		entry[1] = _point(entry[1])
	if world:
		if MapDims.N != side:
			return false
		world._join_landform = heights
		world._join_kinds = kinds
		world.water.from_dict(d.water)
		world.roads = d.roads
		world.decor = d.decor
		world.town_rect = Rect2(float(d.town[0]), float(d.town[1]), float(d.town[2]), float(d.town[3]))
		world._join_ground = true
		world._load_mark("map")
	received.emit(MAP, {"side": side, "kinds": kinds.size(), "heights": heights.size()})
	return true
