extends Node
## Real ENet delivery of the existing report/over RPCs. The victory rules are
## tested through complete battles in victory.test.mjs; this isolates delivery.
class Field extends World:
	func _ready() -> void:
		has_view = false
		set_process(false)
		set_physics_process(false)
	func _record() -> void:
		pass  # local test peers never write service records

var field: Field
var mode := "host"
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void:
	TestRun.watch()
	var port := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--command-mode="): mode = arg.get_slice("=", 1)
		if arg.begins_with("--port="): port = int(arg.get_slice("=", 1))
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, get_path())
	var peer := ENetMultiplayerPeer.new()
	check((peer.create_server(port) if mode == "host" else peer.create_client("127.0.0.1", port)) == OK, "ENet starts")
	api.multiplayer_peer = peer
	field = Field.new()
	field.name = "World"
	field.srv = mode == "host"
	field.local_team = -1
	field.rules = Rules.new(field)
	field.battle = BattleStats.new(field)
	add_child(field)
	field.game_ended.connect(_ended)
	if mode == "host":
		print("OUTCOME REPLICATION listening ", port)
	else:
		api.connected_to_server.connect(func(): _ready_for_report.rpc_id(1))
	get_tree().create_timer(90.0).timeout.connect(func(): check(false, "report timed out"); _finish())

@rpc("any_peer", "call_remote", "reliable")
func _ready_for_report() -> void:
	if mode != "host": return
	var id := multiplayer.get_remote_sender_id()
	field.winner = 0
	field.rules.victory.end_reason = "Rebels ran out of resolve."
	var report := field.battle.report(-1)
	field.rpc_id(id, "_rpc_report", report)
	field.rpc_id(id, "_rpc_over", 0)

func _ended(winner: int) -> void:
	check(winner == 0, "winner reaches client")
	check(field.report.get("outcome", "") == "Rebels ran out of resolve.", "reason arrives before the result opens")
	check(BattleStats.trim_report(field.report).get("outcome", "") == field.report.get("outcome", ""), "client retains reason in saved report")
	_received.rpc_id(1, failures)
	await get_tree().create_timer(0.2).timeout
	_finish()

@rpc("any_peer", "call_remote", "reliable")
func _received(remote_failures: int) -> void:
	check(remote_failures == 0, "client verified report")
	_finish()

func _finish() -> void:
	print("OUTCOME REPLICATION %s failures=%d" % [mode, failures])
	get_tree().quit(1 if failures > 0 or TestRun.script_errors > 0 else 0)
