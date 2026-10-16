extends Node
## Connection + lobby management. The host is always the authoritative server
## (peer id 1). Team -1 means spectator.

signal lobby_updated
signal game_start(settings: Dictionary)
signal net_error(msg: String)
signal lobby_chat(text: String)
signal player_left(id: int, team: int, pname: String)
signal player_joined(id: int, team: int, pname: String)
## A player who left came back: `old_id` is the peer id they had before.
signal player_rejoined(id: int, old_id: int, team: int, pname: String)
signal session_closed  # left a lobby or a battle, or stopped hosting

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 8
## Bump when what host and client send each other changes, so the matchmaker
## only pairs players who can understand each other.
const NET_VERSION := 6
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

## Who we are to a host: a random token each copy of the game makes for
## itself, sent when it registers. A player who drops out and comes back with
## the same token gets their place back: their side, their colour and what's
## left of their force. The host never passes it on, so nobody else can claim
## a player's place.
var token := ""
var _tokens := {}  # (host) peer id -> token
## (host) Players who have left the battle, by token, in case they come back:
## {"peer": the id they had, "name", "team", "col"}.
var away := {}

## The battle we were last in as a client, to get back into it after a dropped
## connection, a crash or a restart: {"ip", "port", "lobby" (its matchmaker
## listing, "" if joined by address), "host" (its host's name), "token", "at"
## (unix time we were last in it)}, or {}. Kept in user://rejoin.cfg so it
## outlasts the game.
var rejoin := {}
const REJOIN_PATH := "user://rejoin.cfg"
## A battle left longer ago than this is taken to be over.
const REJOIN_FOR_S := 2 * 3600
var _rejoin_path := REJOIN_PATH
var _target := {}  # where the connection being made goes: {"ip", "port", "lobby"}
var _rejoining := false  # that connection is a try at getting back into Net.rejoin's battle
var _rejoin_t := 0  # (msec) when the record next says we're still in that battle


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_conn_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	token = Crypto.new().generate_random_bytes(16).hex_encode()
	# automated test runs (started with --switches) leave the player's record
	# alone, unless given one of their own with --rejoin-file=PATH
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rejoin-file="):
			_rejoin_path = a.substr(14)
			break
		if a.begins_with("--"):
			_rejoin_path = ""
	_load_rejoin()


func host_game(port := DEFAULT_PORT, team := 0) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	players.clear()
	players[1] = {"name": my_name, "team": team, "col": 0}
	_tokens.clear()
	away.clear()
	in_game = false
	# a fresh game: not the mission the last one was (if it was one)
	settings.erase("mission")
	settings.erase("mission_autoplay")
	lobby_updated.emit()
	return OK


## `local_port`: the UDP port to connect from (0 for any). The matchmaker's
## hole punching needs a known one: the port the router has already been
## shown, and the host told to expect. `lobby`: the matchmaker listing it came
## from, if it did (remembered for rejoining).
func join_game(ip: String, port := DEFAULT_PORT, local_port := 0, lobby := "") -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port, 0, 0, 0, local_port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	players.clear()
	in_game = false
	_target = {"ip": ip, "port": port, "lobby": lobby}
	return OK


func leave() -> void:
	if in_game and not multiplayer.is_server() and not rejoin.is_empty():
		_touch_rejoin()
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	_tokens.clear()
	away.clear()
	in_game = false
	_rejoining = false
	session_closed.emit()


# --- rejoining ------------------------------------------------------------------

## Whether there's a battle to get back into (see `rejoin`).
func can_rejoin() -> bool:
	return not rejoin.is_empty() and Time.get_unix_time_from_system() - float(rejoin.get("at", 0.0)) < REJOIN_FOR_S


## The next connection is a try at getting back into the battle we were last
## in: it goes as the player we were there, with that battle's token.
func begin_rejoin() -> void:
	if rejoin.is_empty():
		return
	token = String(rejoin.get("token", token))
	_rejoining = true


## That battle is over, or can't be reached: stop offering it.
func forget_rejoin() -> void:
	rejoin = {}
	_rejoining = false
	if _rejoin_path != "" and FileAccess.file_exists(_rejoin_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_rejoin_path))


func _load_rejoin() -> void:
	var cf := ConfigFile.new()
	if _rejoin_path == "" or cf.load(_rejoin_path) != OK:
		return
	if not (cf.has_section_key("rejoin", "ip") and cf.has_section_key("rejoin", "port") and cf.has_section_key("rejoin", "token")):
		return
	rejoin = {"ip": String(cf.get_value("rejoin", "ip")), "port": int(cf.get_value("rejoin", "port")),
		"lobby": String(cf.get_value("rejoin", "lobby", "")), "host": String(cf.get_value("rejoin", "host", "")),
		"token": String(cf.get_value("rejoin", "token")), "at": float(cf.get_value("rejoin", "at", 0.0))}


## The record says we were in that battle just now. Kept up while we play, so
## a crash late in a long battle still leaves a fresh one.
func _touch_rejoin() -> void:
	rejoin["at"] = Time.get_unix_time_from_system()
	_rejoin_t = Time.get_ticks_msec() + 60000
	_save_rejoin()


func _process(_dt: float) -> void:
	if in_game and not rejoin.is_empty() and Time.get_ticks_msec() >= _rejoin_t and not multiplayer.is_server():
		_touch_rejoin()


func _save_rejoin() -> void:
	if _rejoin_path == "":
		return
	var cf := ConfigFile.new()
	for k in rejoin:
		cf.set_value("rejoin", k, rejoin[k])
	cf.save(_rejoin_path)


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
	# and its nav takes it several seconds. A client's one link is to the host
	# (peer 1): the other players it hears of are relayed through the host and
	# have no ENet peer here to set
	if multiplayer.is_server() or id == 1:
		_long_timeout(id)


## Don't drop a peer for going silent for 45 s (map generation on the host,
## then its first frame of the new world if it has a window; a big first
## snapshot on the client). ENet only checks when it next resends, so the real
## limit lands somewhere between 45 and 90 s.
func _long_timeout(id: int) -> void:
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer:
		var pp: ENetPacketPeer = (mp as ENetMultiplayerPeer).get_peer(id)
		if pp:
			pp.set_timeout(64, 45000, 90000)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var tok := String(_tokens.get(id, ""))
	_tokens.erase(id)
	if players.has(id):
		var p: Dictionary = players[id]
		players.erase(id)
		if in_game and tok != "":
			# their place is kept for the rest of the battle
			away[tok] = {"peer": id, "name": String(p.name), "team": int(p.team), "col": int(p.get("col", -1))}
		player_left.emit(id, int(p.team), String(p.name))
		# everyone's list of who's in the battle loses them too, once ENet has
		# let go of the link (it tells us before it does, and a message sent
		# now would go to a peer it can no longer send to)
		_broadcast_lobby.call_deferred()


func _on_connected() -> void:
	# (players pick their side in the lobby, so they register with a name, and
	# the token that says who they are if they've been here before)
	_register.rpc_id(1, my_name, join_team, token)


func _on_conn_failed() -> void:
	var back := _rejoining
	var host := _rejoin_host()
	if back:
		forget_rejoin()
	leave()
	net_error.emit(("Couldn't get back into %s's battle: nobody answered. It may have ended." % host) if back else "Could not connect to host.")


func _on_server_disconnected() -> void:
	var was := in_game and can_rejoin()
	leave()
	net_error.emit("Lost connection to the host. You can rejoin while the battle lasts." if was else "Lost connection to host.")


func _rejoin_host() -> String:
	var h := String(rejoin.get("host", ""))
	return h if h != "" else "the host"


# --- lobby RPCs ---------------------------------------------------------------

## `team`: the side a test client asked for (-2: none, the lobby decides).
## `tok`: who they are (see `token`).
@rpc("any_peer", "call_remote", "reliable")
func _register(pname: String, team := -2, tok := "") -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	var clean := pname.strip_edges().substr(0, 20)
	if clean == "":
		clean = "Player %d" % (players.size() + 1)
	tok = tok.substr(0, 64)
	if tok != "":
		# the same player connecting again while we still hold their old link:
		# it died without a word (a crash, a pulled cable) and ENet won't notice
		# for a minute or more, so let it go now
		for pid in _tokens.keys():
			if _tokens[pid] == tok and int(pid) != id:
				_drop_stale(int(pid))
		_tokens[id] = tok
	if in_game and tok != "" and away.has(tok):
		# a player back in the battle they left: their own place, even when
		# the battle is closed to newcomers
		var was: Dictionary = away[tok]
		away.erase(tok)
		var col := int(was.col)
		for pid in players:
			if col < 0 or int(players[pid].get("col", -1)) == col:
				col = _free_color()
				break
		players[id] = {"name": clean, "team": int(was.team), "col": col}
		_broadcast_lobby()
		var rs: Dictionary = settings.duplicate(true)
		rs["players"] = players.duplicate(true)
		_start.rpc_id(id, rs)
		player_rejoined.emit(id, int(was.peer), int(was.team), clean)
		return
	if in_game:
		if not bool(settings.get("drop_in", true)):
			_kick.rpc_id(id, "That game has already started.")
			return
		# drop-in: put them on a side and hand them the running game
		var side := _pick_join_team()
		players[id] = {"name": clean, "team": side, "col": _free_color()}
		_broadcast_lobby()
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


## A link the host still holds for a player who has connected again. Their
## old place is given up (to a teammate or the AI, as if they'd left) so the
## new link can take it back.
func _drop_stale(pid: int) -> void:
	_on_peer_disconnected(pid)
	# and the link itself goes once this frame's messages are out: cut now,
	# ENet would keep a peer it can't send to until its next poll
	_cut.call_deferred(pid)


func _cut(pid: int) -> void:
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer and pid in multiplayer.get_peers():
		var pp: ENetPacketPeer = (mp as ENetMultiplayerPeer).get_peer(pid)
		if pp:
			pp.peer_disconnect_now()


@rpc("authority", "call_remote", "reliable")
func _kick(reason: String) -> void:
	if _rejoining:
		reason = "Couldn't get back into %s's battle: %s" % [_rejoin_host(), reason]
		forget_rejoin()
	leave()
	net_error.emit(reason)


func _broadcast_lobby() -> void:
	_sync_lobby.rpc(players, settings, in_game)


## `running`: the host's battle has started (a player dropping in or back
## hears this before the battle itself arrives).
@rpc("authority", "call_local", "reliable")
func _sync_lobby(p: Dictionary, s: Dictionary, running := false) -> void:
	players = p
	settings = s
	if _rejoining and not running:
		# we went back for a battle, but its host is in a lobby now: it's over
		forget_rejoin()
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
	away.clear()
	_start.rpc(s)


@rpc("authority", "call_local", "reliable")
func _start(s: Dictionary) -> void:
	in_game = true
	settings = s
	players = s.players
	if not multiplayer.is_server() and not _target.is_empty():
		# remembered, so we can get back in if we drop out
		_rejoining = false
		var hp: Dictionary = players.get(1, {})
		rejoin = {"ip": String(_target.ip), "port": int(_target.port), "lobby": String(_target.lobby),
			"host": String(hp.get("name", "")), "token": token}
		_touch_rejoin()
	game_start.emit(s)
