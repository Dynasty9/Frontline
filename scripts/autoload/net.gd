extends Node
## Connection + lobby management. The host is always the authoritative server
## (peer id 1). Team -1 means spectator.

signal lobby_updated
signal game_start(settings: Dictionary)
signal net_error(msg: String)
signal lobby_chat(text: String)
signal player_left(id: int, team: int, pname: String)
signal player_joined(id: int, team: int, pname: String)
signal session_closed  # left a lobby or a battle, or stopped hosting

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 8
## Bump when what host and client send each other changes, so the matchmaker
## only pairs players who can understand each other.
const NET_VERSION := 3
## Each commander's colour: his cursor, his view and his pings on his
## teammates' screens. Handed out in the lobby so it stays the same all battle
## (and "I'm the pink one" works over voice). Clear of the sides' blue and red.
const PLAYER_COLORS := [Color(0.38, 0.95, 0.72), Color(1.0, 0.5, 0.82), Color(0.74, 0.62, 1.0), Color(0.8, 0.98, 0.38),
	Color(0.4, 0.9, 1.0), Color(1.0, 0.86, 0.46), Color(1.0, 0.64, 0.5), Color(0.62, 0.78, 1.0)]

var players := {}  # peer_id -> {"name": String, "team": int, "col": int (into PLAYER_COLORS)}
var settings := {"ai_fill": true, "ai_allies": false, "drop_in": true}
var my_name := "Commander"
var in_game := false
## The side a test client asked for with --team (-2: none). It goes with the
## registration rather than as a request_team after it, so a host that starts
## as soon as everyone is in (--players=N) can't start before it lands.
var join_team := -2


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_conn_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port := DEFAULT_PORT, team := 0) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	players.clear()
	players[1] = {"name": my_name, "team": team, "col": 0}
	in_game = false
	# a fresh game: not the mission the last one was (if it was one)
	settings.erase("mission")
	settings.erase("mission_autoplay")
	lobby_updated.emit()
	return OK


## `local_port`: the UDP port to connect from (0 for any). The matchmaker's
## hole punching needs a known one: the port the router has already been
## shown, and the host told to expect.
func join_game(ip: String, port := DEFAULT_PORT, local_port := 0) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port, 0, 0, 0, local_port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	players.clear()
	in_game = false
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	in_game = false
	session_closed.emit()


## A player's colour (see PLAYER_COLORS).
func player_color(id: int) -> Color:
	var p: Dictionary = players.get(id, {})
	var i := int(p.get("col", -1))
	if i < 0:
		i = posmod(id, PLAYER_COLORS.size())
	return PLAYER_COLORS[i % PLAYER_COLORS.size()]


func player_name(id: int) -> String:
	var p: Dictionary = players.get(id, {})
	return String(p.get("name", "Commander"))


## The first colour nobody has yet.
func _free_color() -> int:
	var used := {}
	for id in players:
		used[int(players[id].get("col", -1))] = true
	for i in PLAYER_COLORS.size():
		if not used.has(i):
			return i
	return players.size() % PLAYER_COLORS.size()


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


# --- connection callbacks ---------------------------------------------------

func _on_peer_connected(id: int) -> void:
	# (the client registers itself with _register once connected) - and the
	# link survives the host going quiet for a while: laying out a 1 km map
	# and its nav takes it several seconds
	_long_timeout(id)


## Don't drop a peer for going silent for under a minute (map generation on
## the host, a big first snapshot on the client).
func _long_timeout(id: int) -> void:
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer:
		var pp: ENetPacketPeer = (mp as ENetMultiplayerPeer).get_peer(id)
		if pp:
			pp.set_timeout(64, 45000, 90000)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if players.has(id):
		var p: Dictionary = players[id]
		players.erase(id)
		player_left.emit(id, int(p.team), String(p.name))
		if not in_game:
			_broadcast_lobby()


func _on_connected() -> void:
	# (players pick their side in the lobby, so they register with a name alone)
	if join_team >= -1:
		_register.rpc_id(1, my_name, join_team)
	else:
		_register.rpc_id(1, my_name)


func _on_conn_failed() -> void:
	leave()
	net_error.emit("Could not connect to host.")


func _on_server_disconnected() -> void:
	leave()
	net_error.emit("Lost connection to host.")


# --- lobby RPCs ---------------------------------------------------------------

## `team`: the side a test client asked for (-2: none, the lobby decides).
@rpc("any_peer", "call_remote", "reliable")
func _register(pname: String, team := -2) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var clean := pname.strip_edges().substr(0, 20)
	if clean == "":
		clean = "Player %d" % (players.size() + 1)
	if in_game:
		if not bool(settings.get("drop_in", true)):
			_kick.rpc_id(id, "That game has already started.")
			return
		# drop-in: put them on a side and hand them the running game
		var side := _pick_join_team()
		players[id] = {"name": clean, "team": side, "col": _free_color()}
		_sync_lobby.rpc(players, settings)
		var s: Dictionary = settings.duplicate(true)
		s["players"] = players.duplicate(true)
		_start.rpc_id(id, s)
		player_joined.emit(id, side, clean)
		return
	players[id] = {"name": clean, "team": mission_side() if mission_side() >= 0 else 0, "col": _free_color()}
	if team >= -1:
		_put_on_team(id, team)
	_broadcast_lobby()
	_lobby_msg.rpc("%s joined." % clean)


## The side a mission is played from (-1: not a mission).
func mission_side() -> int:
	var mk := String(settings.get("mission", ""))
	if mk == "":
		return -1
	return int(Missions.find(mk).get("side", 0))


func _pick_join_team() -> int:
	if mission_side() >= 0:
		return mission_side()
	var n := [0, 0]
	for pid in players:
		var t := int(players[pid].team)
		if t >= 0:
			n[t] += 1
	if n[0] > 0 and n[1] == 0:
		return 0
	if n[1] > 0 and n[0] == 0:
		return 1
	return 0 if n[0] <= n[1] else 1


@rpc("authority", "call_remote", "reliable")
func _kick(reason: String) -> void:
	leave()
	net_error.emit(reason)


func _broadcast_lobby() -> void:
	_sync_lobby.rpc(players, settings)


@rpc("authority", "call_local", "reliable")
func _sync_lobby(p: Dictionary, s: Dictionary) -> void:
	players = p
	settings = s
	lobby_updated.emit()


@rpc("any_peer", "call_local", "reliable")
func request_team(team: int) -> void:
	if not multiplayer.is_server() or in_game:
		return
	var id := _sender()
	if players.has(id):
		_put_on_team(id, team)
		_broadcast_lobby()


func _put_on_team(id: int, team: int) -> void:
	players[id].team = clampi(team, -1, 1)
	if mission_side() >= 0 and players[id].team >= 0:
		players[id].team = mission_side()  # a mission is co-op: everyone on its side


func set_setting(key: String, value) -> void:
	if not multiplayer.is_server():
		return
	settings[key] = value
	_broadcast_lobby()


func send_lobby_chat(text: String) -> void:
	if text.strip_edges() == "":
		return
	_lobby_msg.rpc("%s: %s" % [my_name, text.strip_edges().substr(0, 200)])


@rpc("any_peer", "call_local", "reliable")
func _lobby_msg(text: String) -> void:
	lobby_chat.emit(text)


func start_game() -> void:
	if not multiplayer.is_server():
		return
	var s: Dictionary = settings.duplicate(true)
	s["seed"] = int(s.get("fixed_seed", randi()))
	s["mood"] = String(Settings.get_v("mood"))
	var humans := [false, false]
	for id in players:
		var t := int(players[id].team)
		if t >= 0:
			humans[t] = true
	var ai := []
	for t in 2:
		if not humans[t] and bool(s.get("ai_fill", true)):
			ai.append(t)
		elif humans[t] and bool(s.get("ai_allies", false)):
			ai.append(t)
	s["ai_teams"] = ai
	var mk := String(s.get("mission", ""))
	if mk != "":
		# a mission: its own ground, weather and enemy (no AI commander), and
		# every player on its side
		var md := Missions.find(mk)
		s["seed"] = int(s.fixed_seed) if s.has("fixed_seed") else int(md.get("seed", s.seed))
		s["mood"] = String(md.get("mood", s.mood))
		s["ai_teams"] = []
		for id in players:
			if int(players[id].team) >= 0:
				players[id].team = int(md.get("side", 0))
	s["players"] = players.duplicate(true)
	_start.rpc(s)


@rpc("authority", "call_local", "reliable")
func _start(s: Dictionary) -> void:
	in_game = true
	settings = s
	players = s.players
	game_start.emit(s)
