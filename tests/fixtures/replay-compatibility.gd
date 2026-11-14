extends Node

const ReplayPlayer = preload("res://scripts/game/replay_player.gd")

func _ready() -> void:
	TestRun.watch()
	var player := ReplayPlayer.new()
	assert(Net.NET_VERSION == 14, "Live multiplayer must retain its current protocol")
	for protocol in [13, 13.0, 14, 14.0]:
		assert(player._supports_replay_protocol(protocol))
	for protocol in [12, 15, 13.5, "13", null, true]:
		assert(not player._supports_replay_protocol(protocol))

	var old := _content(13)
	var body := _body(old)
	var decoded: Dictionary = player.decode(body)
	assert(not decoded.is_empty(), "v2.0.0's protocol-13 archive must decode")
	assert(decoded.protocol == 13, "Keep the archive's original protocol metadata")
	assert(decoded.checkpoint.snapshots[0].size() == old.checkpoint.snapshots[0].size() + 6)
	assert(decoded.frames[0].snapshots[0].size() == old.frames[0].snapshots[0].size() + 12)
	_check_packet(decoded.checkpoint.snapshots[0], [1, 2], [34, 31])
	_check_packet(decoded.frames[0].snapshots[0], [1, 3, 2], [34, 34, 31])
	assert(decoded.checkpoint.snapshots[0].slice(9, 37) == _vehicle_bytes(false), "Old vehicle fields remain byte-for-byte intact")
	assert(decoded.checkpoint.snapshots[0].slice(37, 43) == PackedByteArray([0, 128, 0, 0, 0, 0]))
	assert(decoded.checkpoint.snapshots[0].slice(48) == _soldier_bytes(), "The following entity must not be consumed as aim")
	assert(player.decode(body).checkpoint.snapshots == decoded.checkpoint.snapshots, "Repeated seeks must not append the aim twice")

	# Exercise the real vehicle reader with an adjacent entity still in the packet.
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = decoded.checkpoint.snapshots[0]
	buffer.seek(9)
	var vehicle := Vehicle.new()
	vehicle.aim_offset = Vector3.ONE
	vehicle.read_state(buffer)
	assert(buffer.get_position() == 43)
	assert(buffer.get_u32() == 2 and buffer.get_u8() == 31)
	assert(vehicle.net_pos == Vector3(1, 2, 3))
	assert(vehicle.aim_offset == Vector3.INF, "An old recording has no recorded aim target")
	vehicle.free()

	var current := _content(14)
	decoded = player.decode(_body(current))
	assert(decoded.checkpoint.snapshots == current.checkpoint.snapshots, "Current aim bytes must not change")
	assert(decoded.frames[0].snapshots == current.frames[0].snapshots)
	buffer.data_array = decoded.checkpoint.snapshots[0]
	buffer.seek(9)
	vehicle = Vehicle.new()
	vehicle.read_state(buffer)
	assert(vehicle.aim_offset.is_equal_approx(Vector3(12.3, -4.5, 6.7)))
	vehicle.free()

	# Accept exactly the known archive schemas, not arbitrary short or mixed packets.
	for protocol in [12, 15, 13.5, "13"]:
		var invalid := old.duplicate(true)
		invalid.protocol = protocol
		assert(player.decode(_body(invalid)).is_empty())
	var invalid := _content(13)
	invalid.checkpoint.snapshots = [_packet([[1, _vehicle_bytes(true)], [2, _soldier_bytes()]])]
	assert(player.decode(_body(invalid)).is_empty(), "Protocol 13 must have 28-byte vehicles")
	invalid = _content(14)
	invalid.checkpoint.snapshots = [_packet([[1, _vehicle_bytes(false)], [2, _soldier_bytes()]])]
	assert(player.decode(_body(invalid)).is_empty(), "Protocol 14 must have 34-byte vehicles")
	invalid = _content(13)
	invalid.checkpoint.snapshots[0] = invalid.checkpoint.snapshots[0].slice(0, -1)
	assert(player.decode(_body(invalid)).is_empty(), "Truncated records stay invalid")
	invalid = _content(13)
	invalid.frames[0].snapshots = [_packet([[99, _vehicle_bytes(false)]])]
	assert(player.decode(_body(invalid)).is_empty(), "Unknown entity IDs stay invalid")
	player.manifest = {"protocol": 14}
	assert(player.decode(body).is_empty(), "Chunk and manifest protocols must agree")
	player.manifest = {"protocol": 13.0}
	assert(not player.decode(body).is_empty(), "JSON manifest numbers are accepted")
	player.free()
	print("REPLAY_COMPATIBILITY passed")
	TestRun.quit(get_tree())

func _content(protocol: int) -> Dictionary:
	var vehicle := _vehicle_bytes(protocol == 14)
	var checkpoint := {
		"time": 0.0, "team": [{}, {}], "mission": {}, "report": {}, "winner": -1,
		"entities": [[1, "vehicle", {"pos": Vector3(1, 2, 3)}], [2, "soldier", {"pos": Vector3.ZERO}]],
		"snapshots": [_packet([[1, vehicle], [2, _soldier_bytes()]])], "roads": [[], [], []]}
	var frame := {
		"time": 1.0, "team": [{}, {}], "mission": {}, "report": {}, "winner": -1,
		"spawn": [[3, "vehicle", {"pos": Vector3(1, 2, 3)}]], "despawn": [], "props": {}, "fx": [],
		"snapshots": [_packet([[1, vehicle], [3, vehicle], [2, _soldier_bytes()]])]}
	return {"format": 1, "protocol": protocol, "checkpoint": checkpoint, "frames": [frame]}

func _body(value: Dictionary) -> Dictionary:
	var raw := var_to_bytes(value)
	return {"size": raw.size(), "data": Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_ZSTD))}

func _vehicle_bytes(current: bool) -> PackedByteArray:
	# The exact v2.0.0 write_state layout: 28 bytes, before aim was recorded.
	var b := StreamPeerBuffer.new()
	Entity.put_v3(b, Vector3(1, 2, 3))
	Entity.put_ang(b, 0.5)
	Entity.put_ang(b, 0.75)
	b.put_u8(200)
	b.put_u8(3)
	b.put_u8(3)
	b.put_8(0)
	b.put_u32(7)
	Entity.put_ang(b, 0.1)
	Entity.put_ang(b, -0.2)
	assert(b.data_array.size() == 28)
	if current:
		b.put_16(123)
		b.put_16(-45)
		b.put_16(67)
	return b.data_array

func _soldier_bytes() -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(31)
	return result

func _packet(records: Array) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_float(0.0)
	for record: Array in records:
		b.put_u32(record[0])
		b.put_u8(record[1].size())
		b.put_data(record[1])
	return b.data_array

func _check_packet(packet: PackedByteArray, ids: Array, lengths: Array) -> void:
	var offset := 4
	for i in ids.size():
		assert(packet.decode_u32(offset) == ids[i])
		assert(packet[offset + 4] == lengths[i])
		offset += 5 + lengths[i]
	assert(offset == packet.size(), "Every record stays framed through the end of the packet")
