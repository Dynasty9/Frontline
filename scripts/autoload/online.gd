extends Node
## Online services on top of Net: the matchmaker (the list of battles being
## hosted, and Find Match) and an optional account. None of it is needed to
## play. LAN and direct-address games never touch it, and when the matchmaker
## can't be reached the menu says so and everything else carries on.
##
## The matchmaker never carries game traffic: players still connect straight
## to the host over ENet. To get through home routers it does what voice and
## game clients do, "UDP hole punching". Each side asks a public STUN server
## which address and port its router shows the internet for its game socket;
## the matchmaker swaps those between host and joiner; both send packets at
## each other, so each router takes the other side's packets for replies and
## lets them in. A router that hands out a new port for every destination
## ("symmetric NAT": some mobile and campus networks) can't be punched through,
## and a host behind one needs a forwarded port.
##
## Battles on the same network are found without any of that: a host
## broadcasts a small beacon on the LAN every second or so, and the server
## browser listens for them, so friends at a LAN party (or two machines at
## home) see each other with no internet and no addresses typed in.
##
## Command line: --matchmaker=URL (or FL_MATCHMAKER), --account=PATH for the
## saved sign-in, --no-stun to skip the STUN check (offline tests).

signal account_changed
signal listing_changed  # listed, unlisted, or failed to list
signal join_progress(stage: String)  # a listed battle being joined: what's happening now
signal lan_changed  # a battle on this network appeared, changed or went away

const DEFAULT_URL := "https://matchmaker-production-a53e.up.railway.app"
const ACCOUNT_PATH := "user://account.cfg"
const STUN_SERVERS := [["stun.cloudflare.com", 3478], ["stun.l.google.com", 19302]]
const HEARTBEAT_S := 15.0
## Routers forget an idle UDP mapping after 30 s or more; a byte every 15 s
## keeps the hosting port's public face the one we told the matchmaker.
const KEEPALIVE_S := 15.0
const PUNCH_FOR_S := 4.0
const PUNCH_EVERY_S := 0.15
## The LAN beacons: where they're sent, how often, and how long a battle that
## has gone quiet stays in the list.
const LAN_PORT := 7787
const LAN_EVERY_S := 1.0
const LAN_FORGET_S := 4.0
const LAN_MAGIC := "FLBEACON"

var base_url := DEFAULT_URL
var account_path := ACCOUNT_PATH
var stun_enabled := true

# the account (callsign "" when signed out)
var callsign := ""
var email := ""
var _access := ""
var _access_until := 0.0  # unix seconds
var _refresh := ""
var _refreshing := false

# this machine's network, as STUN saw it from the hosting port
var nat := ""  # open, cone, strict, unknown ("" before the first check)
var _stun_ep := {}  # {"ip", "port"}: the hosting port's public face
var _stun_ips: Array = []  # [[ip, port]] of the STUN servers, resolved once

# the listing while hosting
var want_listed := false
var lobby_id := ""
var listing_error := ""
var _listing := false
var _lobby_token := ""
var _port := 0  # the port Online.host() hosted on (0 when not hosting through us)
var _dirty := false
var _relist_t := 0.0  # when to try listing again after it failed
var _hb_t := 0.0
var _ka_t := 0.0
var _punches: Array = []  # [ip, port, until, next]: joiners to punch towards
# one byte: ENet drops anything under its 2-byte header unread, so these never
# disturb a game in progress; routers only care that a packet went out
var _punch_pkt := PackedByteArray([0])

# the LAN: our beacon while hosting, and the browser's ear for everyone else's
var _lan_tx: PacketPeerUDP
var _lan_t := 0.0
var _lan_nonce := ""  # tells our beacon apart from everyone else's
var _lan_dirty := false
var _lan_rx: PacketPeerUDP
## Battles heard on this network: nonce -> the beacon, plus "address" (where
## it came from) and "seen" (when).
var lan_games := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_environment("FL_MATCHMAKER"):
		base_url = OS.get_environment("FL_MATCHMAKER")
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--matchmaker="):
			base_url = s.substr(13)
		elif s.begins_with("--account="):
			account_path = s.substr(10)
		elif s == "--no-stun":
			stun_enabled = false
	base_url = base_url.rstrip("/")
	_load_account()
	Net.session_closed.connect(_on_session_closed)
	Net.lobby_updated.connect(_changed)
	Net.game_start.connect(func(_s): _changed())
	Net.player_left.connect(func(_i, _t, _n): _changed())
	Net.player_joined.connect(func(_i, _t, _n): _changed())


## The battle we host changed: tell the matchmaker and the LAN soon.
func _changed() -> void:
	_dirty = true
	_lan_dirty = true


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- talking to the matchmaker ---------------------------------------------------------

## One call to the matchmaker: {ok, code, data, error}. A stale sign-in is
## refreshed first, or once on a 401, and the call repeated.
func api(method: int, path: String, body: Variant = null, headers := PackedStringArray(), timeout := 10.0, signed := false) -> Dictionary:
	if signed and _refresh != "" and Time.get_unix_time_from_system() > _access_until - 60.0:
		await _refresh_session()
	var r: Dictionary = await _request(method, path, body, headers, timeout, signed)
	if signed and int(r.code) == 401 and _refresh != "":
		var renewed: bool = await _refresh_session()
		if renewed:
			r = await _request(method, path, body, headers, timeout, signed)
	return r


func _request(method: int, path: String, body: Variant, headers: PackedStringArray, timeout: float, signed: bool) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = timeout
	add_child(req)
	var h := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	h.append_array(headers)
	if signed and _access != "":
		h.append("Authorization: Bearer " + _access)
	var err := req.request(base_url + path, h, method, "" if body == null else JSON.stringify(body))
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "data": {}, "error": "Can't reach the matchmaker."}
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": 0, "data": {}, "error": "Can't reach the matchmaker."}
	var code: int = res[1]
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	var d: Dictionary = parsed if parsed is Dictionary else {}
	var ok := code >= 200 and code < 300
	return {"ok": ok, "code": code, "data": d, "error": "" if ok else String(d.get("error", "The matchmaker refused (%d)." % code))}


## {ok, data: {accounts: "off" | "supabase" | ..., lobbies, players}}
func check() -> Dictionary:
	return await api(HTTPClient.METHOD_GET, "/health", null, PackedStringArray(), 6.0)


func browse() -> Dictionary:
	return await api(HTTPClient.METHOD_GET, "/lobbies?version=%d" % Net.NET_VERSION)


## The best open battle for us ({data.lobby}, null when there's none to join).
## `exclude`: lobby ids already tried.
func find_match(exclude: Array) -> Dictionary:
	return await api(HTTPClient.METHOD_POST, "/match", {"version": str(Net.NET_VERSION), "exclude": exclude})


# --- the account ------------------------------------------------------------------------

func signed_in() -> bool:
	return _refresh != ""


func sign_in(mail: String, password: String) -> Dictionary:
	var r: Dictionary = await api(HTTPClient.METHOD_POST, "/auth/login", {"email": mail.strip_edges(), "password": password})
	if r.ok:
		_take_session(r.data.get("session", {}))
	return r


## With email confirmation switched on in Supabase there is no session yet:
## {ok, confirm: true} and the player signs in after clicking the link.
func sign_up(mail: String, password: String, new_callsign: String) -> Dictionary:
	var r: Dictionary = await api(HTTPClient.METHOD_POST, "/auth/signup", {"email": mail.strip_edges(), "password": password, "callsign": new_callsign.strip_edges()})
	if r.ok:
		if r.data.get("session") is Dictionary:
			_take_session(r.data.session)
		else:
			r["confirm"] = true
	return r


func sign_out() -> void:
	if _access != "":
		_request(HTTPClient.METHOD_POST, "/auth/logout", null, PackedStringArray(), 5.0, true)
	_access = ""
	_refresh = ""
	_access_until = 0.0
	callsign = ""
	email = ""
	_save_account()
	account_changed.emit()


func rename(new_callsign: String) -> Dictionary:
	var r: Dictionary = await api(HTTPClient.METHOD_PATCH, "/me", {"callsign": new_callsign.strip_edges()}, PackedStringArray(), 10.0, true)
	if r.ok:
		callsign = String(r.data.get("user", {}).get("callsign", new_callsign))
		Net.my_name = callsign
		_save_account()
		account_changed.emit()
	return r


func _take_session(s: Dictionary) -> void:
	_access = String(s.get("access_token", ""))
	_refresh = String(s.get("refresh_token", ""))
	_access_until = Time.get_unix_time_from_system() + float(s.get("expires_in", 3600))
	var u: Dictionary = s.get("user", {})
	email = String(u.get("email", email))
	if String(u.get("callsign", "")) != "":
		callsign = String(u.callsign)
	if callsign != "":
		Net.my_name = callsign
	_save_account()
	account_changed.emit()


func _refresh_session() -> bool:
	if _refreshing:
		while _refreshing:
			await get_tree().process_frame
		return _access != ""
	_refreshing = true
	var r: Dictionary = await _request(HTTPClient.METHOD_POST, "/auth/refresh", {"refresh_token": _refresh}, PackedStringArray(), 10.0, false)
	_refreshing = false
	if r.ok:
		_take_session(r.data.get("session", {}))
		return true
	if int(r.code) == 401:
		# the refresh token is spent or revoked: signed out
		sign_out()
	return false


func _load_account() -> void:
	var cf := ConfigFile.new()
	if cf.load(account_path) != OK:
		return
	_refresh = String(cf.get_value("account", "refresh_token", ""))
	email = String(cf.get_value("account", "email", ""))
	callsign = String(cf.get_value("account", "callsign", "")) if _refresh != "" else ""
	if callsign != "":
		Net.my_name = callsign


func _save_account() -> void:
	var cf := ConfigFile.new()
	if _refresh != "":
		cf.set_value("account", "refresh_token", _refresh)
		cf.set_value("account", "email", email)
		cf.set_value("account", "callsign", callsign)
	cf.save(account_path)


# --- STUN -------------------------------------------------------------------------------

## Which address and port this machine's router shows the internet for local
## UDP `port`, asked of two public STUN servers. The same answer from both
## means the router keeps one public port per socket and can be punched
## through ("cone"); different answers mean it picks a new port for every
## destination ("strict"). Borrows the port, so it must run before ENet binds
## it. {ok, ip, port, nat}
func probe(port: int) -> Dictionary:
	var out := {"ok": false, "ip": "", "port": 0, "nat": "unknown"}
	if not stun_enabled:
		return out
	var servers: Array = await _stun_servers()
	if servers.is_empty():
		return out
	var udp := PacketPeerUDP.new()
	if udp.bind(port) != OK:
		return out
	var reqs := []
	var tx := {}  # transaction id (hex) -> server index
	for i in servers.size():
		var r := PackedByteArray([0x00, 0x01, 0x00, 0x00, 0x21, 0x12, 0xA4, 0x42])
		for k in 12:
			r.append(randi() % 256)
		reqs.append(r)
		tx[r.slice(8, 20).hex_encode()] = i
	var seen := {}  # server index -> [ip, port]
	var t0 := Time.get_ticks_msec()
	var resend := 0
	while Time.get_ticks_msec() - t0 < 1600 and seen.size() < servers.size():
		if Time.get_ticks_msec() >= resend:
			# it's UDP: ask again every few hundred ms until each one answers
			resend = Time.get_ticks_msec() + 350
			for i in servers.size():
				if not seen.has(i):
					udp.set_dest_address(String(servers[i][0]), int(servers[i][1]))
					udp.put_packet(reqs[i])
		while udp.get_available_packet_count() > 0:
			var m := _stun_parse(udp.get_packet())
			if not m.is_empty() and tx.has(m.tx):
				seen[tx[m.tx]] = [m.ip, m.port]
		await get_tree().process_frame
	udp.close()
	if seen.is_empty():
		return out
	var first: Array = seen.values()[0]
	out.ok = true
	out.ip = String(first[0])
	out.port = int(first[1])
	var ports := {}
	for v in seen.values():
		ports[v[1]] = true
	if ports.size() > 1:
		out.nat = "strict"
	elif out.ip in IP.get_local_addresses() and out.port == port:
		out.nat = "open"
	elif seen.size() > 1:
		out.nat = "cone"
	return out


## A STUN binding success: {tx, ip, port} from its (XOR-)MAPPED-ADDRESS, or {}.
func _stun_parse(p: PackedByteArray) -> Dictionary:
	const COOKIE := [0x21, 0x12, 0xA4, 0x42]
	if p.size() < 20 or p[0] != 0x01 or p[1] != 0x01 or p[4] != 0x21 or p[5] != 0x12 or p[6] != 0xA4 or p[7] != 0x42:
		return {}
	var end := mini(p.size(), 20 + ((p[2] << 8) | p[3]))
	var tid := p.slice(8, 20).hex_encode()
	var plain := {}
	var i := 20
	while i + 4 <= end:
		var kind := (p[i] << 8) | p[i + 1]
		var n := (p[i + 2] << 8) | p[i + 3]
		var v := i + 4
		if v + n > end:
			break
		# IPv4 only: what ENet is given to punch towards
		if (kind == 0x0020 or kind == 0x0001) and n >= 8 and p[v + 1] == 0x01:
			var port := (p[v + 2] << 8) | p[v + 3]
			var ip := [p[v + 4], p[v + 5], p[v + 6], p[v + 7]]
			if kind == 0x0020:
				port ^= 0x2112
				for k in 4:
					ip[k] = int(ip[k]) ^ int(COOKIE[k])
			var d := {"tx": tid, "ip": "%d.%d.%d.%d" % ip, "port": port}
			if kind == 0x0020:
				return d
			plain = d
		i = v + ((n + 3) & ~3)
	return plain


func _stun_servers() -> Array:
	if not _stun_ips.is_empty():
		return _stun_ips
	var ids := []
	for s in STUN_SERVERS:
		ids.append(IP.resolve_hostname_queue_item(String(s[0]), IP.TYPE_IPV4))
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		var waiting := false
		for id in ids:
			if IP.get_resolve_item_status(id) == IP.RESOLVER_STATUS_WAITING:
				waiting = true
		if not waiting:
			break
		await get_tree().process_frame
	var out := []
	for i in ids.size():
		if IP.get_resolve_item_status(ids[i]) == IP.RESOLVER_STATUS_DONE:
			var a := IP.get_resolve_item_address(ids[i])
			if a != "":
				out.append([a, int(STUN_SERVERS[i][1])])
		IP.erase_resolve_item(ids[i])
	_stun_ips = out
	return out


# --- hosting a listed battle ---------------------------------------------------------------

## Host a battle, and put it on the matchmaker if `listed`. The port is shown
## to STUN first, before ENet takes it, so players can be punched through to
## it. Returns Net.host_game's error (ERR_SKIP if `still_wanted` says the
## player gave up while the router was being checked).
func host(port: int, team := 0, listed := true, still_wanted := Callable()) -> int:
	var me: Dictionary = await probe(port)
	if still_wanted.is_valid() and not still_wanted.call():
		return ERR_SKIP
	nat = String(me.nat)
	_stun_ep = {"ip": me.ip, "port": me.port} if me.ok else {}
	if OS.has_environment("FL_DEBUG_ONLINE"):
		print("ONLINE host port %d: stun %s, nat %s" % [port, str(_stun_ep), nat])
	var err := Net.host_game(port, team)
	if err != OK:
		return err
	_port = port
	_ka_t = 0.0
	if listed:
		list_game()
	return OK


func hosting() -> bool:
	return _port > 0 and multiplayer.multiplayer_peer is ENetMultiplayerPeer and multiplayer.is_server()


## Put the battle we're hosting on the matchmaker's list (and keep it there
## until unlist(), the session closing, or the matchmaker forgetting it, in
## which case it's listed again).
func list_game() -> void:
	want_listed = true
	if lobby_id != "" or _listing or not hosting():
		return
	_listing = true
	listing_error = ""
	listing_changed.emit()
	var body := _state()
	body["port"] = _port
	body["host"] = Net.my_name
	body["version"] = str(Net.NET_VERSION)
	body["nat"] = nat if nat != "" else "unknown"
	body["lan"] = lan_ip()
	if not _stun_ep.is_empty():
		body["punch"] = _stun_ep
	var r: Dictionary = await api(HTTPClient.METHOD_POST, "/lobbies", body, PackedStringArray(), 10.0, signed_in())
	if not r.ok and int(r.code) in [401, 503] and signed_in():
		# the account didn't check out (expired, or this server has none):
		# list it under the typed callsign instead
		r = await api(HTTPClient.METHOD_POST, "/lobbies", body)
	_listing = false
	if not r.ok:
		# a blip (the matchmaker restarting, the network): try again shortly,
		# so a battle never stays off the list because of one bad moment
		listing_error = String(r.error)
		_relist_t = _now() + 15.0
		listing_changed.emit()
		return
	var id := String(r.data.get("id", ""))
	var token := String(r.data.get("token", ""))
	if not want_listed or not hosting():
		# stopped hosting (or unticked the box) while we were listing
		_request(HTTPClient.METHOD_DELETE, "/lobbies/" + id, null, PackedStringArray(["X-Lobby-Token: " + token]), 5.0, false)
		return
	lobby_id = id
	_lobby_token = token
	_hb_t = _now()
	_share_invite()
	listing_changed.emit()
	_poll_loop(id)


func unlist() -> void:
	want_listed = false
	if lobby_id == "":
		return
	_request(HTTPClient.METHOD_DELETE, "/lobbies/" + lobby_id, null, PackedStringArray(["X-Lobby-Token: " + _lobby_token]), 5.0, false)
	lobby_id = ""
	_lobby_token = ""
	_share_invite()
	listing_changed.emit()


## Everyone in the lobby hears the listing's id, so any of them can copy an
## invite link for their friends.
func _share_invite() -> void:
	if hosting() and String(Net.settings.get("invite", "")) != lobby_id:
		Net.set_setting("invite", lobby_id)


## The matchmaker forgot the listing (it restarted, or we were silent too
## long): list it afresh.
func _relist(id: String) -> void:
	if lobby_id != id:
		return
	lobby_id = ""
	_lobby_token = ""
	_share_invite()
	if want_listed:
		list_game()


## The host's long poll: the matchmaker answers the moment a player asks to
## join, with the endpoint their router showed STUN, and we start punching.
func _poll_loop(id: String) -> void:
	while lobby_id == id:
		var r: Dictionary = await _request(HTTPClient.METHOD_POST, "/lobbies/%s/poll?wait=20" % id, null, PackedStringArray(["X-Lobby-Token: " + _lobby_token]), 30.0, false)
		if lobby_id != id:
			return
		if r.ok:
			for j in r.data.get("joins", []):
				if j is Dictionary:
					if OS.has_environment("FL_DEBUG_ONLINE"):
						print("ONLINE punching towards %s:%d" % [String(j.get("ip", "")), int(j.get("port", 0))])
					_punches.append([String(j.get("ip", "")), int(j.get("port", 0)), _now() + PUNCH_FOR_S, 0.0])
		elif int(r.code) == 404:
			_relist(id)
			return
		else:
			await get_tree().create_timer(5.0, true, false, true).timeout


func _heartbeat(id: String) -> void:
	var r: Dictionary = await _request(HTTPClient.METHOD_POST, "/lobbies/%s/heartbeat" % id, _state(), PackedStringArray(["X-Lobby-Token: " + _lobby_token]), 10.0, false)
	if int(r.code) == 404:
		_relist(id)


## What the server browser shows about the battle we're hosting: sent with
## every check-in, and in the LAN beacon.
func _state() -> Dictionary:
	var teams := [0, 0]
	var specs := 0
	for id in Net.players:
		var t := int(Net.players[id].team)
		if t >= 0:
			teams[t] += 1
		else:
			specs += 1
	var mk := String(Net.settings.get("mission", ""))
	return {
		"players": maxi(1, Net.players.size()),
		"max_players": Net.max_players(),
		"in_game": Net.in_game,
		"drop_in": bool(Net.settings.get("drop_in", true)),
		"name": Net.battle_name(),
		"mode": "mission" if mk != "" else String(Net.settings.get("mode", "versus")),
		"mission": String(Missions.find(mk).title) if mk != "" else "",
		"side": Net.locked_side(),
		"teams": teams,
		"spectators": specs,
		"locked": Net.password != "",
	}


## The address the internet sees for the port we host on ("" before STUN
## has answered, or if it couldn't).
func public_address() -> String:
	return String(_stun_ep.get("ip", ""))


func hosted_port() -> int:
	return _port


## This machine's address on its home network, for players behind the same
## router (most routers can't loop a connection back in through their own
## public address).
func lan_ip() -> String:
	for a: String in IP.get_local_addresses():
		var o := a.split(".")
		if o.size() == 4 and (o[0] == "10" or (o[0] == "192" and o[1] == "168") or (o[0] == "172" and int(o[1]) >= 16 and int(o[1]) <= 31)):
			return a
	return ""


func _on_session_closed() -> void:
	unlist()
	_port = 0
	_punches.clear()
	if _lan_tx:
		_lan_tx.close()
		_lan_tx = null


func _process(_dt: float) -> void:
	var now := _now()
	if lobby_id != "" and (now >= _hb_t + HEARTBEAT_S or (_dirty and now >= _hb_t + 1.0)):
		_hb_t = now
		_dirty = false
		_heartbeat(lobby_id)
	if _lan_rx:
		_lan_hear(now)
	if not hosting():
		_punches.clear()
		return
	if want_listed and lobby_id == "" and not _listing and listing_error != "" and now >= _relist_t:
		list_game()
	if now >= _lan_t or (_lan_dirty and now >= _lan_t - LAN_EVERY_S + 0.25):
		_lan_t = now + LAN_EVERY_S
		_lan_dirty = false
		_lan_beacon()
	var enet: ENetConnection = (multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
	if enet == null:
		return
	if not _stun_ep.is_empty() and now >= _ka_t:
		_ka_t = now + KEEPALIVE_S
		for s in _stun_ips:
			enet.socket_send(String(s[0]), int(s[1]), _punch_pkt)
	for i in range(_punches.size() - 1, -1, -1):
		var p: Array = _punches[i]
		if now > float(p[2]):
			_punches.remove_at(i)
		elif now >= float(p[3]):
			p[3] = now + PUNCH_EVERY_S
			enet.socket_send(String(p[0]), int(p[1]), _punch_pkt)


# --- joining a listed battle --------------------------------------------------------------

## Join a battle from the matchmaker. Show our router a port, have the
## matchmaker pass it to the host (who starts punching towards it), then
## connect from that same port to wherever the matchmaker says. {err, error, via}
## `still_wanted` is asked after every wait: the player may have cancelled
## (err ERR_SKIP), and then nothing is connected.
func join_listed(id: String, still_wanted := Callable()) -> Dictionary:
	var gave_up := {"err": ERR_SKIP, "error": "", "via": ""}
	join_progress.emit("Checking your connection")
	var local := 0
	for i in 8:
		var p := 20000 + randi() % 40000
		var u := PacketPeerUDP.new()
		if u.bind(p) == OK:
			u.close()
			local = p
			break
	var me := {"ok": false}
	if local > 0:
		me = await probe(local)
	if still_wanted.is_valid() and not still_wanted.call():
		return gave_up
	join_progress.emit("Asking the host to open the way in")
	var r: Dictionary = await api(HTTPClient.METHOD_POST, "/lobbies/%s/join" % id, {"ip": me.ip, "port": me.port} if me.ok else {})
	if still_wanted.is_valid() and not still_wanted.call():
		return gave_up
	if not r.ok:
		return {"err": FAILED, "error": r.error, "via": ""}
	var c: Dictionary = r.data.get("connect", {})
	join_progress.emit("Connecting to the host")
	# a moment for the host's first punches to leave its router
	await get_tree().create_timer(0.3, true, false, true).timeout
	if still_wanted.is_valid() and not still_wanted.call():
		return gave_up
	var err := Net.join_game(String(c.get("address", "")), int(c.get("port", 0)), local)
	if OS.has_environment("FL_DEBUG_ONLINE"):
		print("ONLINE joining %s:%d from port %d (stun %s:%d) via %s" % [String(c.get("address", "")), int(c.get("port", 0)), local, me.get("ip", ""), int(me.get("port", 0)), String(c.get("via", ""))])
	return {"err": err, "error": "" if err == OK else "Could not connect (error %d)." % err, "via": String(c.get("via", ""))}


## Where players can find the battle we're hosting, for the lobby screen:
## [tag, one line, all well].
func listing_status() -> Array:
	if lobby_id != "":
		return ["LISTED ONLINE", "Anyone can find it in the server browser%s." % (", with the password" if Net.password != "" else ""), true]
	if _listing:
		return ["LISTING", "Putting the battle on the server browser...", true]
	if want_listed and listing_error != "":
		return ["NOT LISTED", "Couldn't list it online: %s" % listing_error, false]
	return ["UNLISTED", "Only players on your network, or with your address, can find it.", true]


## What STUN said about this router, for the host: whether players will get in.
func router_text() -> String:
	match nat:
		"open":
			return "Your connection takes players directly."
		"cone":
			return "Players get in through your router by hole punching."
		"strict":
			return "Your router is strict (symmetric NAT): forward UDP port %d or some players won't get in." % _port
		"unknown":
			return "Couldn't check your router: forwarding UDP port %d makes sure players get in." % _port
	return ""


## A link that brings a friend straight into the battle we're listing: the
## website's page for it, whose Join button opens the game ("" when unlisted).
func invite_link() -> String:
	if lobby_id == "":
		return ""
	return "%s/?join=%s" % [Updater.WEBSITE_URL, lobby_id]


# --- the LAN ----------------------------------------------------------------------------

## The host's beacon: what the battle is and which port it's on, broadcast to
## the local network (and to this machine, for a second copy of the game).
func _lan_beacon() -> void:
	if _lan_tx == null:
		_lan_tx = PacketPeerUDP.new()
		_lan_tx.set_broadcast_enabled(true)
		if _lan_tx.bind(0) != OK:
			_lan_tx = null
			return
		_lan_nonce = "%08x%08x" % [randi(), randi()]
	var b := _state()
	b["v"] = Net.NET_VERSION
	b["n"] = _lan_nonce
	b["port"] = _port
	b["host"] = String(Net.players[1].name) if Net.players.has(1) else Net.my_name
	b["id"] = lobby_id
	var pkt := (LAN_MAGIC + JSON.stringify(b)).to_utf8_buffer()
	for to in ["255.255.255.255", "127.0.0.1"]:
		_lan_tx.set_dest_address(to, LAN_PORT)
		_lan_tx.put_packet(pkt)


## Listen for battles on this network (the server browser, while it's open).
## False when the port is taken: another copy of the game is listening.
func lan_listen(on: bool) -> bool:
	if not on:
		if _lan_rx:
			_lan_rx.close()
			_lan_rx = null
		if not lan_games.is_empty():
			lan_games.clear()
			lan_changed.emit()
		return true
	if _lan_rx:
		return true
	_lan_rx = PacketPeerUDP.new()
	if _lan_rx.bind(LAN_PORT) != OK:
		_lan_rx = null
		return false
	return true


func _lan_hear(now: float) -> void:
	var changed := false
	while _lan_rx.get_available_packet_count() > 0:
		var pkt := _lan_rx.get_packet()
		var from := _lan_rx.get_packet_ip()
		var txt := pkt.get_string_from_utf8()
		if not txt.begins_with(LAN_MAGIC):
			continue
		var d: Variant = JSON.parse_string(txt.substr(LAN_MAGIC.length()))
		if not (d is Dictionary) or int(d.get("v", 0)) != Net.NET_VERSION or String(d.get("n", "")) == _lan_nonce:
			continue
		var key := String(d.get("n", ""))
		var old: Dictionary = lan_games.get(key, {})
		# the same beacon reaches a copy on the same machine twice (broadcast
		# and loopback): either address works, so keep the first
		d["address"] = String(old.get("address", from))
		d["seen"] = now
		if old.is_empty() or _beacon_differs(old, d):
			changed = true
		lan_games[key] = d
	for k in lan_games.keys():
		if now - float(lan_games[k].seen) > LAN_FORGET_S:
			lan_games.erase(k)
			changed = true
	if changed:
		lan_changed.emit()


func _beacon_differs(a: Dictionary, b: Dictionary) -> bool:
	for k in ["name", "players", "max_players", "in_game", "drop_in", "mode", "mission", "side", "teams", "locked", "id"]:
		if str(a.get(k)) != str(b.get(k)):
			return true
	return false
