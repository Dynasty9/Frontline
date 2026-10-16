extends Node
## Connection + lobby management. The host is always the authoritative server
## (peer id 1). Team -1 means spectator.

signal lobby_updated
signal game_start(settings: Dictionary)
signal net_error(msg: String)
signal lobby_chat(text: String, system: bool)  # system: joins, leaves and the like
signal player_left(id: int, team: int, pname: String)
signal player_joined(id: int, team: int, pname: String)
signal session_closed  # left a lobby or a battle, or stopped hosting
## The host wants a password before letting us in (`wrong`: we offered one
## and it wasn't it). We've already been disconnected: set join_password and
## join again.
signal password_needed(wrong: bool)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 8
## Bump when what host and client send each other changes, so the matchmaker
## only pairs players who can understand each other.
const NET_VERSION := 5
## Each commander's colour: his cursor, his view and his pings on his
## teammates' screens. Handed out in the lobby so it stays the same all battle
## (and "I'm the pink one" works over voice). Clear of the sides' blue and red.
const PLAYER_COLORS := [Color(0.38, 0.95, 0.72), Color(1.0, 0.5, 0.82), Color(0.74, 0.62, 1.0), Color(0.8, 0.98, 0.38),
	Color(0.4, 0.9, 1.0), Color(1.0, 0.86, 0.46), Color(1.0, 0.64, 0.5), Color(0.62, 0.78, 1.0)]
## A fresh lobby. "mode": "versus" (players pick sides, the AI fills an empty
## one) or "coop" (every player on "coop_side", the AI commands the other);
## a "mission" setting overrides both. "name" is what the server browser
## shows ("" for "<host>'s battle").
const DEFAULT_SETTINGS := {"ai_fill": true, "ai_allies": false, "drop_in": true, "mode": "versus", "coop_side": 0, "max_players": MAX_PLAYERS, "name": ""}

## peer_id -> {"name": String, "team": int, "ready": bool, "col": int (into PLAYER_COLORS)}
var players := {}
var settings := DEFAULT_SETTINGS.duplicate()
var my_name := "Commander"
var in_game := false
## The lobby's password while hosting ("" for none). It never leaves this
## machine: joiners send theirs and the host compares.
var password := ""
## The password to offer the next host we join.
var join_password := ""
## The side a test client asked for with --team (-2: none). It goes with the
## registration rather than as a request_team after it, so a host that starts
## as soon as everyone is in (--players=N) can't start before it lands.
var join_team := -2
## Players who have connected but not yet said who they are, so the lobby
## can show them arriving (host: peer id -> true; everyone: how many).
var _arriving := {}
var arriving := 0
var _turned_away := {}  # host: peers refused (full, closed, kicked), whatever they send next
var _closing := false  # the host is closing the lobby: no starting now
var _debug := OS.has_environment("FL_DEBUG_NET")  # print the lobby handshake


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
	players[1] = {"name": my_name, "team": team, "ready": true, "col": 0}
	in_game = false
	# a fresh game: nothing carried over from the last one (a mission, a
	# password, a name)
	settings = DEFAULT_SETTINGS.duplicate()
	password = ""
	_turned_away.clear()
	_arriving.clear()
	arriving = 0
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
	password = ""
	_arriving.clear()
	arriving = 0
	session_closed.emit()


## The host closes its lobby: everyone in it is told why before the line is
## cut (a bare disconnect would read as the host's game crashing).
func close_lobby() -> void:
	if multiplayer.is_server() and not in_game and players.size() > 1:
		_closing = true
		_kick.rpc("%s closed the lobby." % String(players[1].name if players.has(1) else my_name))
		await get_tree().create_timer(0.3, true, false, true).timeout
		_closing = false
	leave()


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


func _dbg(msg: String) -> void:
	if _debug:
		print("NET %s" % msg)


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


# --- connection callbacks ---------------------------------------------------

func _on_peer_connected(id: int) -> void:
	# (the client registers itself with _register once connected) - and the
	# link survives the host going quiet for a while: laying out a 1 km map
	# and its nav takes it several seconds
	_long_timeout(id)
	_dbg("peer %d connected" % id)
	if multiplayer.is_server():
		# someone is coming in: the lobby shows them arriving until they say
		# who they are (or give up, or are turned away)
		_arriving[id] = true
		if not in_game:
			_broadcast_lobby()
		get_tree().create_timer(30.0, true, false, true).timeout.connect(func():
			# still hasn't said who they are: not a player of this game
			if _arriving.erase(id) and multiplayer.is_server():
				_drop_later(id)
				if not in_game:
					_broadcast_lobby())


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
	var was_arriving := _arriving.erase(id)
	if players.has(id):
		var p: Dictionary = players[id]
		players.erase(id)
		player_left.emit(id, int(p.team), String(p.name))
		if not in_game:
			_broadcast_lobby()
			_announce("%s left." % String(p.name), true)
	elif was_arriving and not in_game:
		_broadcast_lobby()


func _on_connected() -> void:
	_dbg("connected to the host, registering as %s" % my_name)
	# (players pick their side in the lobby; only a test client says one now)
	_register.rpc_id(1, my_name, join_password, join_team)


func _on_conn_failed() -> void:
	_dbg("connection failed")
	leave()
	net_error.emit("The host didn't answer. The battle may have closed, or their router is blocking the way in.")


func _on_server_disconnected() -> void:
	leave()
	net_error.emit("Lost connection to host.")


# --- lobby RPCs ---------------------------------------------------------------

## `team`: the side a test client asked for (-2: none, the lobby decides).
@rpc("any_peer", "call_remote", "reliable")
## `pw`: the password they offer; `team`: the side a test client asked for
## (-2: none, the lobby decides).
func _register(pname: String, pw: String, team := -2) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	_arriving.erase(id)
	_dbg("%d registers as %s (in game: %s)" % [id, pname, in_game])
	if players.has(id) or _turned_away.has(id):
		return
	# (spaces either end are a slip of the copy and paste, not the password)
	if password != "" and pw.strip_edges() != password.strip_edges():
		_ask_password.rpc_id(id, pw.strip_edges() != "")
		_drop_later(id)
		if not in_game:
			_broadcast_lobby()
		return
	if players.size() >= max_players():
		_turn_away(id, "That battle is full.")
		return
	if in_game and not bool(settings.get("drop_in", true)):
		_turn_away(id, "That battle has already started, and the host isn't letting anyone join mid-battle.")
		return
	var clean := _unique_name(pname)
	if in_game:
		# drop-in: put them on a side and hand them the running game
		var side := _pick_join_team()
		players[id] = {"name": clean, "team": side, "ready": true, "col": _free_color()}
		# everyone else learns who they are; they get the whole game at once
		_sync_to_players(id)
		var s: Dictionary = settings.duplicate(true)
		s["players"] = players.duplicate(true)
		_start.rpc_id(id, s)
		player_joined.emit(id, side, clean)
		return
	players[id] = {"name": clean, "team": _pick_join_team(), "ready": false, "col": _free_color()}
	if team >= -1:
		_put_on_team(id, team)
	_broadcast_lobby()
	_announce("%s joined." % clean, true)


## A callsign no one else in the battle has: with two "Commander"s in one
## lobby, nobody can tell which is which.
func _unique_name(pname: String) -> String:
	var base := pname.strip_edges().substr(0, 20)
	if base == "":
		base = "Player"
	var taken := {}
	for pid in players:
		taken[String(players[pid].name).to_lower()] = true
	var out := base
	var n := 2
	while taken.has(out.to_lower()):
		out = "%s %d" % [base.substr(0, 17), n]
		n += 1
	return out


## What the battle is called in the server browser and the lobby.
func battle_name() -> String:
	var n := String(settings.get("name", "")).strip_edges()
	if n != "":
		return n
	return "%s's battle" % (String(players[1].name) if players.has(1) else my_name)


## Seats in this battle, the host's included.
func max_players() -> int:
	return clampi(int(settings.get("max_players", MAX_PLAYERS)), 1, MAX_PLAYERS)


## Say why, then cut the line if they haven't already gone.
func _turn_away(id: int, reason: String) -> void:
	_turned_away[id] = true
	_kick.rpc_id(id, reason)
	_drop_later(id)
	if not in_game:
		_broadcast_lobby()


func _drop_later(id: int) -> void:
	await get_tree().create_timer(2.0, true, false, true).timeout
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer and multiplayer.is_server() and not players.has(id) and id in multiplayer.get_peers():
		(mp as ENetMultiplayerPeer).disconnect_peer(id)


## The side a mission is played from (-1: not a mission).
func mission_side() -> int:
	var mk := String(settings.get("mission", ""))
	if mk == "":
		return -1
	return int(Missions.find(mk).get("side", 0))


## The side every player fights on, in a mission or a co-op battle (-1 when
## players pick their own).
func locked_side() -> int:
	if mission_side() >= 0:
		return mission_side()
	if String(settings.get("mode", "versus")) == "coop":
		return clampi(int(settings.get("coop_side", 0)), 0, 1)
	return -1


func _pick_join_team() -> int:
	if locked_side() >= 0:
		return locked_side()
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
	_dbg("turned away: %s" % reason)
	leave()
	net_error.emit(reason)


@rpc("authority", "call_remote", "reliable")
func _ask_password(wrong: bool) -> void:
	_dbg("the host wants a password (wrong: %s)" % wrong)
	leave()
	password_needed.emit(wrong)


## Everyone in the lobby hears who's in it. Only those let in: someone still
## at the door (a password to give, a full battle) learns nothing.
func _broadcast_lobby() -> void:
	_sync_to_players(-1)


func _sync_to_players(skip: int) -> void:
	var n := _arriving.size()
	for pid in players:
		if pid != 1 and pid != skip:
			_sync_lobby.rpc_id(pid, players, settings, n)
	_sync_lobby(players, settings, n)


@rpc("authority", "call_local", "reliable")
func _sync_lobby(p: Dictionary, s: Dictionary, n_arriving: int) -> void:
	players = p
	settings = s
	arriving = n_arriving
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
	if locked_side() >= 0 and players[id].team >= 0:
		players[id].team = locked_side()  # co-op: everyone on the one side


## Ready or not: the host sees who is still getting set before starting.
@rpc("any_peer", "call_local", "reliable")
func set_ready(on: bool) -> void:
	if not multiplayer.is_server() or in_game:
		return
	var id := _sender()
	if players.has(id):
		players[id].ready = on
		_broadcast_lobby()


## The host removes a player from the lobby.
func kick(id: int) -> void:
	if not multiplayer.is_server() or in_game or id == 1 or not players.has(id):
		return
	var pname := String(players[id].name)
	players.erase(id)
	_turned_away[id] = true
	_kick.rpc_id(id, "The host removed you from the battle.")
	_drop_later(id)
	_broadcast_lobby()
	_announce("%s was removed by the host." % pname, true)


## Everyone playing moves to the side a co-op battle (or mission) is fought
## from: the host changed it, or the mode.
func _herd_to_locked_side() -> void:
	var t := locked_side()
	if t < 0:
		return
	for id in players:
		if int(players[id].team) >= 0:
			players[id].team = t


## The host's choices for the lobby, all at once.
func configure(values: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	settings.merge(values, true)
	_herd_to_locked_side()
	_broadcast_lobby()


func set_setting(key: String, value) -> void:
	if not multiplayer.is_server():
		return
	settings[key] = value
	if key in ["mode", "coop_side", "mission"]:
		_herd_to_locked_side()
	_broadcast_lobby()


## Chat goes through the host, which puts the sender's name on it and passes
## it to everyone in the lobby.
func send_lobby_chat(text: String) -> void:
	var t := text.strip_edges().substr(0, 200)
	if t != "":
		_chat_up.rpc_id(1, t)


@rpc("any_peer", "call_local", "reliable")
func _chat_up(text: String) -> void:
	var id := _sender()
	if not multiplayer.is_server() or not players.has(id):
		return
	_announce("%s: %s" % [String(players[id].name), text.strip_edges().substr(0, 200)], false)


## The host tells everyone in the lobby (system: a join, a leave, not chat).
func _announce(text: String, system: bool) -> void:
	for pid in players:
		if pid != 1:
			_lobby_msg.rpc_id(pid, text, system)
	_lobby_msg(text, system)


@rpc("authority", "call_remote", "reliable")
func _lobby_msg(text: String, system: bool) -> void:
	lobby_chat.emit(text, system)


func start_game() -> void:
	if not multiplayer.is_server() or _closing or in_game:
		return
	var s: Dictionary = settings.duplicate(true)
	s["seed"] = int(s.get("fixed_seed", randi()))
	# the lobby's time of day, if it picked one, else this player's setting
	s["mood"] = String(s.get("mood", Settings.get_v("mood")))
	if String(s.get("mode", "versus")) == "coop":
		# co-op: the AI always commands the side nobody plays
		s["ai_fill"] = true
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
	# to the players: anyone still at the door gets the game when they're let in
	for pid in players:
		if pid != 1:
			_start.rpc_id(pid, s)
	_start(s)


@rpc("authority", "call_local", "reliable")
func _start(s: Dictionary) -> void:
	_dbg("battle starting")
	in_game = true
	settings = s
	players = s.players
	game_start.emit(s)
