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
	main.start_local({"scenario": String(main.args.get("replay-scenario", "attack")), "seed": "3", "play": "0"})
	while not main.world or main.world.building:
		await get_tree().process_frame
	var world: World = main.world
	if main.args.has("replay-upload-test"):
		var listing: Dictionary = await Online._request(HTTPClient.METHOD_POST, "/lobbies", {"port": 7917, "host": "Replay integration test", "name": "Live recording test", "in_game": true}, PackedStringArray(), 10, false)
		check(listing.ok, "creates test lobby")
		Online.lobby_id = listing.data.id
		Online._lobby_token = listing.data.token
	world.execute_cmd(1, {"t": "move", "squads": [1], "pos": Vector3(0, 0, -20)})
	while world.time < 22:
		await get_tree().physics_frame
	world.recording.flush()
	world.recording.flush(true)
	check(world.recording.manifest.status == "complete", "finishes at an exact chunk boundary")
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
	for target in [15.0, 3.0, 21.0, 0.0]:
		await player.seek(target)
		check(not player.failed, "seek succeeds at %s" % target)
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
	print("REPLAY TEST complete: record, commands, forward seek, rewind, state, validation")
	TestRun.quit(get_tree())
