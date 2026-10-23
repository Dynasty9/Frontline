extends Node
var main: Node

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("REPLAY TEST: " + message)
		TestRun.fail()

func _run() -> void:
	main.args["record-replay"] = "user://replay-test-%d" % Time.get_ticks_msec()
	main.start_local({"scenario": String(main.args.get("replay-scenario", "attack")), "seed": "3", "play": "0", "map-size": str(main.args.get("map-size", 1024))})
	while not main.world or main.world.building:
		await get_tree().process_frame
	var world: World = main.world
	if main.args.has("replay-upload-test"):
		var listing: Dictionary = await Online._request(HTTPClient.METHOD_POST, "/lobbies", {"port": 7917, "host": "Replay integration test", "name": "Live recording test", "in_game": true}, PackedStringArray(), 10, false)
		check(listing.ok, "creates test lobby: " + String(listing.get("error", "")))
		if not listing.ok:
			TestRun.quit(get_tree())
			return
		Online.lobby_id = listing.data.id
		Online._lobby_token = listing.data.token
	_check_capture(world)
	var st: Structure = world.structures[0]
	var hp := st.hp
	st.hp *= 0.5
	st.net_dirty = true
	_check_capture(world)
	st.hp = hp
	st.net_dirty = true
	world.push_props(st, {"hp": hp})
	var transient: Entity = world.spawn("structure", {"skind": "low_wall", "pos": Vector3(80, 0, 80)})
	_check_capture(world)
	world.despawn(transient)
	_check_capture(world)
	world.execute_cmd(1, {"t": "move", "squads": [1], "pos": Vector3(0, 0, -20)})
	while world.time < 22:
		await get_tree().physics_frame
	_check_capture(world)
	world.recording.flush()
	world.recording.flush(true)
	check(world.recording.manifest.status == "complete", "finishes at an exact chunk boundary")
	check(world.recording.sequence >= 11, "publishes two-second chunks")
	if main.args.has("replay-upload-test"):
		var deadline := Time.get_ticks_msec() + 40000
		while world.recording.uploaded < world.recording.sequence and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		check(world.recording.uploaded == world.recording.sequence, "all chunks uploaded")
		print("REPLAY UPLOADED " + world.recording.replay_id)
	var path: String = world.recording.folder
	var player: Node = main.open_replay(path)
	while player.busy:
		await get_tree().process_frame
	check(not player.failed and player.sequence == 0, "opens first chunk")
	if player.failed:
		TestRun.quit(get_tree())
		return
	player.speed = 0
	check(player.downloaded.size() == player.manifest.chunks.size(), "loads the complete replay before playback")
	player.source = path.path_join("unavailable")
	for target in [15.0, 3.0, 21.0, 0.0]:
		await player.seek(target)
		check(not player.failed, "seek succeeds at %s" % target)
		check(MapDims.N == int(main.args.get("map-size", 1024)), "seek restores recorded map dimensions")
		check(is_equal_approx(main.world.time, target), "seek restores the clock")
		var states: Array = [player.chunk.checkpoint]
		for state in player.chunk.frames:
			if float(state.time) <= target:
				states.append(state)
		var positions := {}
		for state in states:
			for packet in state.snapshots:
				var buffer := StreamPeerBuffer.new()
				buffer.data_array = packet
				buffer.get_float()
				while buffer.get_available_bytes() > 0:
					var id := buffer.get_u32()
					var length := buffer.get_u8()
					var start := buffer.get_position()
					if main.world.entities.get(id) is Soldier:
						positions[id] = Entity.get_v3(buffer)
					buffer.seek(start + length)
		for id in positions:
			check(main.world.entities[id].net_pos.is_equal_approx(positions[id]), "soldier state matches recording after seek")
		check(not main.world.srv and main.world.local_team == -1, "viewer has no authority")
	var first: Dictionary = player.decode(await player.fetch_json("/chunks/0"))
	check(not first.commands.is_empty() and first.commands[0].command.t == "move", "tick-ordered commands recorded")
	check(player.decode({"size": 999999999, "data": "AA=="}).is_empty(), "rejects oversized decoding")
	check(not player._valid_state({"time": 0}, true), "rejects malformed state")
	check(not player._valid_props("soldier", {"pos": Vector3.ZERO, "utype": "missing-unit"}, true), "rejects unknown unit")
	check(not player._valid_fx([0, "wrong"]), "rejects malformed effect")
	check(not player._valid_map({"kinds": PackedByteArray()}), "rejects malformed map")
	player.source = path
	var live_manifest: Dictionary = player.manifest.duplicate(true)
	live_manifest.status = "live"
	var index := FileAccess.open(path.path_join("index.json"), FileAccess.WRITE)
	index.store_string(JSON.stringify(live_manifest))
	index.close()
	player.follow_live = true
	await player._refresh()
	check(player.position >= float(live_manifest.duration) - 1, "live playback catches up after loading")
	player.speed = 1
	player.playing.pressed.emit()
	player.position = 3
	await player._refresh()
	check(player.position == 3 and not player.follow_live, "pause keeps the chosen live moment")
	player.source = path.path_join("unavailable")
	player.downloaded.clear()
	check(not await player._download_recording() and player.failed, "incomplete downloads do not start playback")
	print("REPLAY TEST complete: record, commands, forward seek, rewind, state, validation")
	TestRun.quit(get_tree())

func _check_capture(world: World) -> void:
	var cached := world.recording.capture()
	var records := {}
	for record: Array in cached.entities:
		records[record[0]] = record
	var live := []
	for e in world.entities.values():
		if not e.gone:
			live.append(e)
			check(records.get(e.eid) == [e.eid, e.ekind(), e.get_props()], "cached checkpoint props match live entity %d" % e.eid)
	check(records.size() == live.size(), "checkpoint drops despawned structures")
	check(_packet_records(cached.snapshots) == _packet_records(world._build_snapshot(live, -1)), "cached checkpoint bytes match complete observer snapshot")

func _packet_records(packets: Array) -> Dictionary:
	var result := {}
	for packet: PackedByteArray in packets:
		var offset := 4
		while offset < packet.size():
			var id := packet.decode_u32(offset)
			var size := packet[offset + 4]
			result[id] = packet.slice(offset + 5, offset + 5 + size)
			offset += 5 + size
	return result
