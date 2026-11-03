extends Node

var client: SimulationClient
var spawns := 0
var snapshots := 0
var map_received := false
var began := 0
var chat_received := false
var report_received := false
var fx_received := 0

func _ready() -> void:
	call_deferred("start")

func start() -> void:
	check_packets()
	var path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--socket-ready="):
			path = arg.trim_prefix("--socket-ready=")
	assert(not path.is_empty())
	var ready: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var address: PackedStringArray = String(ready.address).rsplit(":", true, 1)
	client = SimulationClient.new()
	add_child(client)
	client.failed.connect(func(message):
		push_error(message)
		get_tree().quit(1))
	client.received.connect(on_packet)
	assert(client.connect_to(address[0], int(address[1]), "1".repeat(48), String(ready.engine)) == OK)
	began = Time.get_ticks_msec()

func on_packet(kind: int, value: Variant) -> void:
	match kind:
		SimulationClient.WELCOME:
			assert(value.peer == 7 and value.team == 0)
		SimulationClient.MAP:
			assert(value.side == 64 and value.kinds == 4096)
			map_received = true
		SimulationClient.SPAWN:
			assert(value[2].pos is Vector3)
			assert(value[3] is PackedByteArray)
			spawns += 1
		SimulationClient.BASELINE_END:
			assert(map_received and spawns > 0)
			assert(client.loaded() == OK)
			assert(client.send_command({"t": "chat", "text": "Socket command from Godot", "team_only": true}) == OK)
			assert(client.request_report() == OK)
		SimulationClient.MESSAGE:
			if "Socket command from Godot" in value[2]:
				chat_received = true
		SimulationClient.REPORT:
			assert(value is Dictionary and value.has("players"))
			report_received = true
		SimulationClient.FX:
			fx_received += value.size()
		SimulationClient.SNAPSHOT:
			snapshots += 1
			if client._tick >= 32 and chat_received and report_received and fx_received > 0:
				print("RUST_SOCKET passed spawns=%d snapshots=%d tick=%d" % [spawns, snapshots, client._tick])
				get_tree().quit()

func check_packets() -> void:
	var decor = JSON.parse_string('[["fence",[1,2,3],0,[4,1,2]],["wire",[0,0,0],1,[[5,0,0],2]],["lamp",[0,0,0],0,1]]')
	assert(SimulationClient.decode_decor(decor))
	assert(decor[0][1] is Vector3 and decor[0][3] is Vector3 and decor[1][3][0] is Vector3 and decor[2][3] == 1)
	assert(not SimulationClient.decode_decor(JSON.parse_string('[["fence",[0,0,0],0,1]]')))
	assert(not SimulationClient.decode_decor(JSON.parse_string('[["wire",[0,0,0],0,[[1,2],0]]]')))
	var probe := SimulationClient.new()
	var report := {"padding": "x".repeat(70000)}
	var bytes := JSON.stringify(report).to_utf8_buffer()
	var observed := []
	probe.received.connect(func(kind, value): observed.append([kind, value]))
	var offset := 0
	while offset < bytes.size():
		var chunk := PackedByteArray()
		chunk.resize(9)
		chunk[0] = SimulationClient.REPORT
		chunk.encode_u32(1, bytes.size())
		chunk.encode_u32(5, offset)
		chunk.append_array(bytes.slice(offset, mini(offset + 16000, bytes.size())))
		assert(probe._dispatch(SimulationClient.BLOB, chunk))
		offset += 16000
	assert(observed.size() == 1 and observed[0] == [SimulationClient.REPORT, report])
	assert(not probe._dispatch(SimulationClient.BLOB, PackedByteArray([27, 1, 0, 0, 0, 1, 0, 0, 0, 1])))
	assert(probe._dispatch(SimulationClient.FX, JSON.stringify([[0, [1, 2, 3], [4, 5, 6], 2, "rifle", 17], [4, [0, 0, 0], [0.2, 0.3, 0.4, 1], 8]]).to_utf8_buffer()))
	assert(observed.back()[1][0][1] is Vector3 and observed.back()[1][1][2] is Color)
	assert(not probe._dispatch(SimulationClient.FX, "[[0]]".to_utf8_buffer()))
	assert(not probe._dispatch(SimulationClient.FX, "[[1,2,3]]".to_utf8_buffer()))
	assert(not probe._dispatch(SimulationClient.FX, "[[7,[],[0,0,0]]]".to_utf8_buffer()))
	assert(not probe._dispatch(SimulationClient.FX, "[[1.5,[0,0,0],1]]".to_utf8_buffer()))
	assert(not probe._receive(SimulationClient.packet(SimulationClient.SNAPSHOT, 1, PackedByteArray()), 2))
	probe.free()

func _process(_delta: float) -> void:
	if began > 0 and Time.get_ticks_msec() - began > 15000:
		push_error("Rust socket fixture timed out")
		get_tree().quit(1)
