extends Node

class Recorder extends "res://scripts/game/socket_recording.gd":
	func _ready() -> void:
		_open_recording("Socket recording fixture")
		manifest.format = 2

func _ready() -> void:
	var recorder := Recorder.new()
	recorder.folder = "user://socket-recording-fixture-%d" % Time.get_ticks_usec()
	recorder.settings = {"seed": 3, "simulation_connection": {"token": "DO_NOT_RECORD"}, "password": "DO_NOT_RECORD"}
	add_child(recorder)
	var kinds := PackedByteArray()
	kinds.resize(1024 * 1024)
	var craters := kinds.duplicate()
	var surface := PackedFloat32Array()
	surface.resize(4 * 1024 * 1024)
	recorder.initial_map = {"map_size": 1024, "n": 1, "kinds": kinds, "landform": PackedFloat32Array(),
		"surface": surface.to_byte_array().compress(FileAccess.COMPRESSION_ZSTD), "craters": craters.compress(FileAccess.COMPRESSION_ZSTD),
		"roads": [[], [], []], "decor": [], "town": Rect2(),
		"water": {"coast": {}, "rivers": [], "ponds": [], "fords": [], "bridges": []}}
	var soldier := Soldier.new()
	soldier.team = 0
	var b := StreamPeerBuffer.new()
	soldier.write_state(b)
	var props: Dictionary = SimulationClient._props(JSON.parse_string(JSON.stringify(SimulationInitial.plain(soldier.get_props()))))
	recorder._received(SimulationClient.SPAWN, [1, "soldier", props, b.data_array])
	recorder._baseline = true
	recorder._received(SimulationClient.HUD, {"teams": [{}, {}], "mission": {}})
	var original: Dictionary = recorder.checkpoint
	recorder._received(SimulationClient.PROPS, [1, {"name": "Renamed"}])
	assert(original.entities[0][2].name != "Renamed", "Cached checkpoints must remain immutable")
	var tile_kinds := PackedByteArray()
	tile_kinds.resize(1024)
	var tile_craters := tile_kinds.duplicate()
	tile_craters[5] = 1
	var tile_heights := PackedFloat32Array()
	tile_heights.resize(4096)
	tile_heights[10] = -0.5
	b.clear()
	b.put_data(SimulationInitial.header("FLVT"))
	for n in [0, 0, 32, 32]: b.put_u32(n)
	for block in [tile_kinds, tile_craters, tile_heights.to_byte_array()]: b.put_data(SimulationInitial.block(block))
	recorder._surface_received(Rect2i(0, 0, 32, 32), b.data_array)
	recorder._received(SimulationClient.FX, [[16.0, Vector3.ZERO, 2.0, 15.0], [19.0, 1.0, Vector3.ONE]])
	soldier.position = Vector3(12, 0, 8)
	b.clear()
	soldier.write_state(b)
	var snapshot := StreamPeerBuffer.new()
	snapshot.put_float(2.0)
	snapshot.put_u32(1)
	snapshot.put_u8(b.get_size())
	snapshot.put_data(b.data_array)
	recorder._received(SimulationClient.SNAPSHOT, snapshot.data_array)
	recorder._sample()
	recorder.flush()
	recorder._finish_encoding(true)
	assert(recorder.sequence == 1 and recorder.checkpoint.entities[0][2].name == "Renamed")
	var player: Node = load("res://scripts/game/replay_player.gd").new()
	var first: Dictionary = player.decode(JSON.parse_string(FileAccess.get_file_as_string(recorder.folder.path_join("0.json"))))
	assert(not first.is_empty() and first.format == 2 and first.frames.size() == 1)
	assert(player._valid_map(first.map))
	assert(first.map._surface.size() == 4 * 1024 * 1024)
	assert(first.frames[0]._terrain[0][2][5] == 1 and first.frames[0]._terrain[0][3][10] == -0.5)
	assert(first.frames[0].fx[1][0] == 19 and first.frames[0].fx[1][1] is int)
	assert(first.checkpoint.entities[0][2].team is int)
	assert(not str(first).contains("DO_NOT_RECORD"))
	assert(not first.settings.has("simulation_connection"))
	var invalid: Dictionary = first.frames[0].duplicate(true)
	invalid.terrain.tiles[0][0] = 18469
	assert(not player._valid_state(invalid, false))
	invalid = first.frames[0].duplicate(true)
	invalid.terrain.tiles[0][1] = PackedByteArray([1, 2, 3])
	assert(not player._valid_state(invalid, false))
	assert(not player._valid_props("soldier", {"team": 0.5}, false))
	assert(not player._valid_fx([19.0, 0.5, Vector3.ZERO]))
	recorder._received(SimulationClient.DESPAWN, [1])
	recorder._sample()
	recorder.flush(true)
	var last: Dictionary = player.decode(JSON.parse_string(FileAccess.get_file_as_string(recorder.folder.path_join("1.json"))))
	assert(not last.is_empty() and last.checkpoint.terrain.tiles.size() == 1 and last.frames[0].despawn == [1])
	assert(recorder.capture().entities.is_empty())
	assert(recorder.manifest.status == "complete" and not recorder.manifest.verified)
	player.source = recorder.folder
	assert(not (await player.fetch_json("")).is_empty())
	var invalid_file := FileAccess.open(recorder.folder.path_join("invalid.json"), FileAccess.WRITE)
	invalid_file.store_string("<html>Unavailable</html>")
	invalid_file.close()
	assert((await player.fetch_json("/chunks/invalid")).is_empty())
	recorder.free()
	player.free()
	soldier.free()
	print("SOCKET_RECORDING passed")
	while Music._task >= 0: await get_tree().process_frame
	get_tree().quit()
