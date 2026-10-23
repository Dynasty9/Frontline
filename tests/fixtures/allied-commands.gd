extends Node
## A small field using the real command dispatcher, selection and unit orders.
## It skips map generation and simulation, not the authority or ENet RPC path.

class StraightNav extends Nav:
	func nearest_walkable(p: Vector3, _vehicle := false) -> Vector3:
		return p

	func find_path(from: Vector3, to: Vector3, _vehicle := false, _team := -1, _care := 0.0) -> PackedVector3Array:
		return PackedVector3Array([from, to])


class SuppliedRules extends Rules:
	func spend(_team: int, _pos: Vector3, _amount: int) -> bool:
		return true


class Field extends World:
	func _ready() -> void:
		has_view = false
		set_process(false)
		set_physics_process(false)

	func placement_error(_team: int, _kind: String, _pos: Vector3, _yaw: float) -> String:
		return ""

	func spawn(_kind: String, props: Dictionary) -> Entity:
		var st := Structure.new()
		st.world = self
		st.team = props.team
		st.position = props.pos
		st.skind = props.skind
		add_child(st)
		return st


var field: Field
var checks := 0
var failures := 0
var _remote := 0
var _mode := "local"


func _ready() -> void:
	TestRun.watch()
	var port := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--command-mode="):
			_mode = arg.get_slice("=", 1)
		if arg.begins_with("--port="):
			port = int(arg.get_slice("=", 1))
	# The fixture's ENet connection is separate from the lobby autoload, which
	# otherwise starts its own registration protocol when a client connects.
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, get_path())
	if _mode != "local":
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(port) if _mode == "host" else peer.create_client("127.0.0.1", port)
		_check("ENet starts", err == OK)
		api.multiplayer_peer = peer
		if _mode == "host":
			api.peer_connected.connect(_joined)
	_build_field()
	if _mode == "local":
		_local_checks()
		_finish()
	elif _mode == "host":
		print("ALLIED COMMANDS listening ", port)
	get_tree().create_timer(90.0).timeout.connect(func():
		_check("completed before timeout", false)
		_finish())


func _build_field() -> void:
	Net.players = {1: {"team": 0, "name": "Host"}, 2: {"team": 0, "name": "Ally"}, 3: {"team": 1, "name": "Enemy"}, 4: {"team": -1, "name": "Observer"}}
	field = Field.new()
	field.name = "World"
	field.srv = _mode != "client"
	field.local_peer = 1
	field.local_team = 0
	field.nav = StraightNav.new()
	field.rules = SuppliedRules.new(field)
	field.battle = BattleStats.new(field)
	add_child(field)
	field.input = PlayerInput.new()
	field.input.world = field
	field.add_child(field.input)
	field.input.set_process(false)
	# Empty squads exercise actual move/stop orders without pathfinding the
	# individual formation. Soldiers separately exercise individual orders.
	for spec in [[1, 0, 1], [2, 1, 3], [3, 0, -1], [4, -1, 1]]:
		var sq := field.new_squad(int(spec[1]), int(spec[2]), "rifle_squad")
		_check("stable squad id", sq.sid == int(spec[0]))
	for spec in [[101, 0, 1], [102, 1, 3], [103, 0, -1], [104, -1, 1], [105, 0, 1]]:
		var v := Vehicle.new()
		v.eid = spec[0]
		v.team = spec[1]
		v.owner_peer = spec[2]
		v.world = field
		field.add_child(v)
		field.entities[v.eid] = v
		field.vehicles.append(v)
	field.entities[103].brain_state = "withdraw"
	field.entities[105].vdef = {"auto": true}
	for spec in [[201, 0, 1, 1], [202, 1, 3, 2], [203, 0, -1, 3], [204, -1, 1, 4]]:
		var s := Soldier.new()
		s.eid = spec[0]
		s.team = spec[1]
		s.owner_peer = spec[2]
		s.sid = spec[3]
		s.world = field
		s.position = Vector3(float(s.eid - 202) * 2.0, 0, 0)
		field.add_child(s)
		field.entities[s.eid] = s
		field.soldiers.append(s)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
		TestRun.fail()
		print("FAIL ", label)


func _move(x := 30.0) -> Dictionary:
	# Forged identity fields must not override the RPC's actual sender.
	return {"t": "move", "peer": 3, "team": 1, "squads": [1, 2, 3, 4, 1, 999],
		"vehicles": [101, 102, 103, 104, 105, 101, 999], "pos": Vector3(x, 0, 45), "face": Vector3.FORWARD}


func _check_orders(peer: int) -> void:
	# The fixture disables physics ticks; deliver the queued routes as the next tick would.
	field.nav.process_paths()
	_check("allied human squad accepts the move", field.squads[1].order == "move")
	_check("allied squad owner stays unchanged", field.squads[1].owner == 1)
	_check("duplicate squad IDs are ordered once", field.squads[1].order_n == 1)
	_check("enemy squad is untouched", field.squads[2].order == "hold" and field.squads[2].order_n == 0)
	_check("neutral squad is untouched even with a matching owner", field.squads[4].order_n == 0)
	_check("AI squad accepts the move and leaves AI control", field.squads[3].order == "move" and field.squads[3].owner == peer)
	_check("allied vehicle accepts the move", not field.entities[101].path.is_empty())
	_check("allied vehicle owner stays unchanged", field.entities[101].owner_peer == 1)
	_check("autonomous supply vehicle is not commandeered", field.entities[105].path.is_empty())
	_check("enemy vehicle is untouched", field.entities[102].path.is_empty())
	_check("neutral vehicle is untouched even with a matching owner", field.entities[104].path.is_empty())
	_check("damaged AI vehicle obeys human order", not field.entities[103].path.is_empty() and field.entities[103].brain_overruled)
	_check("damaged AI vehicle leaves AI control", field.entities[103].owner_peer == peer and field.entities[103].brain_state == "")


func _local_checks() -> void:
	field.execute_cmd(2, _move())
	_check_orders(2)
	# Ownership alone is never authority, including inconsistent stale data.
	_check("matching owner cannot command the enemy", not field.can_command_unit(1, 1, 1))
	_check("AI cannot take human units", not field.can_command_unit(-1, 0, 1))
	_check("AI can command its own units", field.can_command_unit(-1, 0, -1))
	for peer in [0, 4, 999]:
		field.execute_cmd(peer, _move(90.0))
		_check("unknown or observer peer %d cannot issue orders" % peer, field.squads[1].order_n == 1)
	field.srv = false
	field.execute_cmd(1, _move(90.0))
	_check("client cannot execute authoritative orders locally", field.squads[1].order_n == 1)
	field.srv = true
	field.execute_cmd(2, {"t": "unit", "soldier": 201, "o": "stop"})
	field.execute_cmd(2, {"t": "unit", "soldier": 202, "o": "stop"})
	_check("allied individual soldier accepts orders", field.entities[201].detached)
	_check("enemy individual soldier refuses orders", not field.entities[202].detached)
	# An AI soldier's whole squad is handed over, and the changed owners are
	# queued for replication through the existing reliable property path.
	var sq: Squad = field.squads[3]
	sq.owner = -1
	sq.members = [field.entities[203]]
	field.entities[203].squad = sq
	field.ready_peers = [2]
	field.execute_cmd(2, {"t": "unit", "soldier": 203, "o": "stop"})
	_check("individual command hands AI squad to humans", sq.owner == 2 and field.entities[203].owner_peer == 2)
	_check("AI handoff is replicated", field._pend_props.get(203, {}).get("owner", 0) == 2)
	field.ready_peers.clear()
	_selection_checks()
	_builder_checks()
	_tunnel_checks()


func _selection_checks() -> void:
	var inp := field.input
	field.local_peer = 2
	for id in [201, 203, 101, 103]:
		_check("allied unit %d is selectable" % id, inp.is_mine(field.entities[id]))
	for id in [202, 204, 102, 104, 105]:
		_check("non-commandable unit %d is not selectable" % id, not inp.is_mine(field.entities[id]))
	inp.sel_squads = [1, 2, 3]
	_check("selected soldiers include all allies, not enemies", inp.selected_soldiers() == [field.entities[201], field.entities[203]])
	inp.select_unit(field.entities[201])
	_check("allied soldier can be picked individually", inp.sel_unit == 201)
	inp.select_unit(field.entities[202])
	_check("enemy individual selection is refused", inp.sel_unit == 201)
	# Exercise the actual click and drag paths, not only the shared predicate.
	field.cam = RtsCamera.new()
	field.add_child(field.cam)
	field.cam.set_process(false)
	field.entities[201].position.x = -12.0
	field.entities[203].position.x = 12.0
	for v in field.vehicles:
		v.position.z = 12.0
	var screen := field.cam.cam.unproject_position(field.entities[201].position + Vector3(0, 0.9, 0))
	inp._click_select(screen, false, false)
	_check("click selects another commander's squad", inp.sel_squads == [1])
	inp._click_select(screen, false, true)
	_check("double click includes allied squads", 1 in inp.sel_squads and 3 in inp.sel_squads and not 2 in inp.sel_squads)
	inp._box_select(Vector2.ZERO, get_viewport().get_visible_rect().size, false)
	_check("drag selects all allied squads only", inp.sel_squads == [1, 3])
	_check("drag selects all allied vehicles only", inp.sel_vehicles == [101, 103])
	Keys.reset_all(false)
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	key.ctrl_pressed = true
	inp._key(key)
	inp.clear_selection()
	key.ctrl_pressed = false
	inp._key(key)
	_check("control group recalls allied squads and vehicles", inp.sel_squads == [1, 3] and inp.sel_vehicles == [101, 103])
	var hud := Hud.new()
	hud.world = field
	var roster := HudOrbat.new()
	roster.hud = hud
	roster._pick("sq", 1, inp.is_mine(field.entities[201]), false, false)
	_check("order-of-battle row selects another commander's squad", inp.sel_squads == [1])
	roster._pick("veh", 101, inp.is_mine(field.entities[101]), true, false)
	_check("order-of-battle row adds another commander's vehicle", inp.sel_vehicles == [101])
	roster.free()
	hud.free()
	field.local_team = -1
	_check("observer can inspect enemies", inp.is_mine(field.entities[202]))
	_check("observer still cannot command", not inp.can_command() and inp.selected_soldiers().is_empty())
	field.local_team = 0


func _builder_checks() -> void:
	# The nearest available engineer belongs to another human commander. The
	# closer enemy engineer must never be auto-assigned to our construction.
	var ally: Soldier = field.entities[201]
	var enemy: Soldier = field.entities[202]
	ally.udef = {"engineer": true}
	enemy.udef = {"engineer": true}
	field.squads[1].members = [ally]
	field.squads[2].members = [enemy]
	var placed := field.rules.try_place(2, 0, "sandbags", enemy.position, 0.0, [])
	_check("another commander's engineer is auto-assigned", placed != null and field.squads[1].build_target == placed and ally.task == "build")
	_check("enemy engineer is not assigned", field.squads[2].build_target == null and enemy.task != "build")
	_check("human engineer attribution is preserved", ally.owner_peer == 1)
	# The same path takes an AI engineering squad out of strategic AI control.
	field.squads[1].owner = -1
	ally.owner_peer = -1
	field.squads[1].order = "hold"
	field.rules.try_place(2, 0, "sandbags", enemy.position, 0.0, [])
	_check("auto-assigned AI engineers hand over", field.squads[1].owner == 2 and ally.owner_peer == 2)


func _tunnel_checks() -> void:
	var entry := Structure.new()
	entry.skind = "tunnel"
	entry.team = 0
	entry.inside = [field.entities[201], field.entities[202]]
	# Same tunnel avoids the unrelated upgrade and travel-time calculation.
	entry.built = true
	field.rules.tunnel_exit(entry, entry, 2)
	_check("allied tunnel passenger obeys another commander", field.entities[201].hidden_reason == "tunnel_travel")
	_check("enemy tunnel passenger is never commanded", field.entities[202].hidden_reason == "")
	entry.free()


func _joined(peer: int) -> void:
	_remote = peer
	Net.players[peer] = {"team": 0, "name": "Client"}
	_begin_client.rpc_id(peer)


@rpc("authority", "call_remote", "reliable")
func _begin_client() -> void:
	field.local_peer = multiplayer.get_unique_id()
	Net.players[field.local_peer] = {"team": 0, "name": "Client"}
	_check("client can select host troops", field.input.is_mine(field.entities[201]))
	field.send_cmd(_move())
	field.send_cmd({"t": "unit", "soldier": 201, "o": "stop", "peer": 3})
	field.send_cmd({"t": "unit", "soldier": 202, "o": "stop", "peer": 3})
	_verify_remote.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _verify_remote() -> void:
	_check("verification came from connected client", multiplayer.get_remote_sender_id() == _remote)
	_check_orders(_remote)
	_check("remote client ordered host soldier", field.entities[201].detached)
	_check("forged peer did not order enemy soldier", not field.entities[202].detached)
	Net.players[_remote].team = -1
	_observer_round.rpc_id(_remote)


@rpc("authority", "call_remote", "reliable")
func _observer_round() -> void:
	# The observer deliberately claims to be host/another team in the packet.
	var d := _move(90.0)
	d.peer = 1
	d.team = 0
	field.send_cmd(d)
	field.send_cmd({"t": "unit", "soldier": 203, "o": "stop", "peer": 1, "team": 0})
	_verify_observer.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _verify_observer() -> void:
	_check("observer cannot order host squads", field.squads[1].order_n == 1)
	_check("observer cannot order individual soldiers", not field.entities[203].detached)
	_finish_client.rpc_id(_remote)
	await get_tree().create_timer(0.5).timeout
	_finish()


@rpc("authority", "call_remote", "reliable")
func _finish_client() -> void:
	_finish()


func _finish() -> void:
	print("ALLIED COMMANDS %s %d/%d passed" % [_mode, checks - failures, checks])
	TestRun.quit(get_tree())
