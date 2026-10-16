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
## With an account, every battle fought goes on the player's service record
## at the end (its after-action report, kept by the matchmaker); one fought
## signed out or offline waits on this machine and goes up at the next sign-in.
##
## The account also carries a rank: battles played signed in earn XP, ranks
## unlock insignia (Insignia), and the player picks one to wear as their icon.
## The matchmaker keeps the count and times each battle on its own clock, from
## battle_begin() to battle_end().
##
## A player signs in on the website, not in the game: Sign in opens it in their
## browser, and once they've signed in (or made an account) there it hands the
## game a session of its own in a frontline:// link (Links). The link carries a
## random "state" the game made when it opened the page, and the game takes no
## sign-in it didn't ask for, so no other page can sign it in to someone
## else's account. Running from source, or against a matchmaker the website
## doesn't know, the game asks for the email and password itself instead.
##
## Command line: --matchmaker=URL (or FL_MATCHMAKER), --account=PATH for the
## saved sign-in, --no-stun to skip the STUN check (offline tests),
## --web-sign-in[=SITE] to sign in through the website (this one, or SITE)
## from source, --no-browser to print its address rather than open it. Test
## runs (any --flag) keep no service record unless given --record-battles.

signal account_changed  # signed in or out, renamed, or the rank or insignia changed
signal listing_changed  # listed, unlisted, or failed to list
signal battle_reported(report: Dictionary)  # {gained, rank_before, rank}: what the last battle earned
signal join_progress(stage: String)  # a listed battle being joined: what's happening now
signal lan_changed  # a battle on this network appeared, changed or went away
signal record_changed  # the latest battle saved, or battles waiting to be
signal web_sign_in_failed(error: String)  # the website's sign-in came back, and didn't work

const DEFAULT_URL := "https://matchmaker-production-a53e.up.railway.app"
const ACCOUNT_PATH := "user://account.cfg"
## Battles fought signed out (or when the matchmaker couldn't be reached),
## waiting to go on the record.
const PENDING_PATH := "user://pending_battles.json"
const MAX_PENDING := 10
## How long a sign-in on the website can take before the game stops waiting for it.
const WEB_SIGN_IN_S := 1800
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
var record_battles := true  # off for automated test runs (see _ready)
var pending_path := PENDING_PATH
var pending: Array = []  # service records not yet on the matchmaker
## The battle that just ended: state "saving", "saved", "waiting" (kept here
## until it can go up) or "" (nothing to record), and why it's waiting.
var last_record := {"state": "", "error": ""}
var _flushing := false

# the account (callsign "" when signed out)
var callsign := ""
var email := ""
var _access := ""
var _access_until := 0.0  # unix seconds
var _refresh := ""
var _refreshing := false
## Signing in on the website (see the top): an exported build on the live
## matchmaker does, unless told otherwise.
var web_sign_in := false
var website_url := ""  # "" for the real one (Updater.WEBSITE_URL)
var open_browser := true
var _web_state := ""  # the sign-in the website was opened for: only its link is taken
var _web_until := 0  # unix seconds
# the rank (from the matchmaker; kept with the sign-in so the menu has it at once)
var icon := Insignia.DEFAULT
var xp := 0
var rank := 0
var rank_xp := 0
var next_xp := 150  # -1 at the top rank
var fought := 0  # battles fought to the end (the matchmaker's "battles")
var wins := 0
var _battle_open := false

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
	var flags := false
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--"):
			flags = true
		if s.begins_with("--matchmaker="):
			base_url = s.substr(13)
		elif s.begins_with("--account="):
			account_path = s.substr(10)
		elif s.begins_with("--pending="):
			pending_path = s.substr(10)
		elif s == "--no-stun":
			stun_enabled = false
		elif s == "--no-browser":
			open_browser = false
	# a test run's battles aren't anybody's service record
	record_battles = not flags or "--record-battles" in OS.get_cmdline_user_args()
	base_url = base_url.rstrip("/")
	# the website signs players in to the live matchmaker only: running from
	# source, or against one of your own, the game asks for the password itself
	web_sign_in = OS.has_feature("template") and base_url == DEFAULT_URL
	for a in OS.get_cmdline_user_args():
		if a == "--web-sign-in" or a.begins_with("--web-sign-in="):
			web_sign_in = true
			website_url = a.substr(14).rstrip("/")
	_load_account()
	_load_pending()
	Links.link_opened.connect(_on_link)
	# started by the website's link (the game had closed since it opened the page)
	if Links.parse(Links.pending)[0] == "sign-in":
		_on_link.call_deferred(Links.pending)
		Links.pending = ""
	if signed_in() and not pending.is_empty() and record_battles:
		flush_pending.call_deferred()
	if signed_in():
		# the rank may have moved since (a battle played on another machine)
		refresh_me.call_deferred()
	Net.session_closed.connect(_on_session_closed)
	Net.lobby_updated.connect(_changed)
	Net.game_start.connect(func(_s): _changed())
	Net.player_left.connect(func(_i, _t, _n): _changed())
	Net.player_joined.connect(func(_i, _t, _n): _changed())
	Net.player_rejoined.connect(func(_i, _o, _t, _n): _changed())


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


## Send the player to the website to sign in, or to make an account (with a
## callsign to suggest). The page it opens hands the session back in a link
## (_on_link). Returns the address.
func open_web_sign_in(create := false, suggest := "") -> String:
	_web_state = Crypto.new().generate_random_bytes(16).hex_encode()
	_web_until = int(Time.get_unix_time_from_system()) + WEB_SIGN_IN_S
	_save_account()
	var url := (website_url if website_url != "" else Updater.WEBSITE_URL) + "/?sign-in=" + _web_state
	if create:
		url += "&create=1"
	if suggest != "":
		url += "&callsign=" + suggest.uri_encode()
	if open_browser and DisplayServer.get_name() != "headless":
		OS.shell_open(url)
	if OS.has_environment("FL_DEBUG_ONLINE") or not open_browser:
		print("ONLINE sign in at " + url)
	return url


## A frontline:// link: a sign-in from the website is ours (the menu has the rest).
func _on_link(url: String) -> void:
	var what: Array = Links.parse(url)
	if what[0] != "sign-in":
		return
	if _web_state == "" or what[1] != _web_state or Time.get_unix_time_from_system() > _web_until:
		# not the page this game opened, or one it has given up on
		web_sign_in_failed.emit("That sign-in is from an earlier try: press Sign in to start again.")
		return
	_web_state = ""
	_save_account()
	# the token is the game's own (the website keeps another), and spent at
	# once: what was in the link is no use to anyone after this
	var r: Dictionary = await _request(HTTPClient.METHOD_POST, "/auth/refresh", {"refresh_token": what[2]}, PackedStringArray(), 10.0, false)
	if r.ok:
		_take_session(r.data.get("session", {}))
		if OS.has_environment("FL_DEBUG_ONLINE"):
			print("ONLINE signed in through the website as %s" % callsign)
	else:
		web_sign_in_failed.emit(String(r.error) if int(r.code) != 401 else "The website's sign-in had run out: press Sign in to try again.")


func sign_out() -> void:
	if _access != "":
		_request(HTTPClient.METHOD_POST, "/auth/logout", null, PackedStringArray(), 5.0, true)
	_access = ""
	_refresh = ""
	_access_until = 0.0
	callsign = ""
	email = ""
	_battle_open = false
	_take_user({"icon": Insignia.DEFAULT, "xp": 0, "rank": 0, "rank_xp": 0, "next_xp": Insignia.rank_xp(1), "battles": 0, "wins": 0})
	_save_account()
	account_changed.emit()


func rename(new_callsign: String) -> Dictionary:
	var r: Dictionary = await api(HTTPClient.METHOD_PATCH, "/me", {"callsign": new_callsign.strip_edges()}, PackedStringArray(), 10.0, true)
	if r.ok:
		callsign = String(r.data.get("user", {}).get("callsign", new_callsign))
		Net.my_name = callsign
		_take_user(r.data.get("user", {}))
		_save_account()
		account_changed.emit()
	return r


## The account as the matchmaker has it now: rank, XP and insignia.
func refresh_me() -> void:
	if not signed_in():
		return
	var r: Dictionary = await api(HTTPClient.METHOD_GET, "/me", null, PackedStringArray(), 10.0, true)
	if r.ok and signed_in():
		_take_user(r.data.get("user", {}))
		_save_account()
		account_changed.emit()


## Wear an insignia (it must be unlocked: the matchmaker checks). {ok, error}
func set_icon(id: String) -> Dictionary:
	if not signed_in():
		return {"ok": false, "code": 0, "data": {}, "error": "Sign in to choose your insignia."}
	var r: Dictionary = await api(HTTPClient.METHOD_PATCH, "/me", {"icon": id}, PackedStringArray(), 10.0, true)
	if r.ok:
		_take_user(r.data.get("user", {}))
		_save_account()
		account_changed.emit()
	return r


## A battle the player is in has begun: start the matchmaker's clock on it.
## Signed out, nothing is counted.
func battle_begin() -> void:
	if not signed_in():
		return
	_battle_open = true
	var r: Dictionary = await api(HTTPClient.METHOD_POST, "/me/battle", {}, PackedStringArray(), 10.0, true)
	if OS.has_environment("FL_DEBUG_ONLINE"):
		print("ONLINE battle begun: %s %s" % [str(r.ok), String(r.error)])
	if not r.ok:
		_battle_open = false


## The battle is over for us: "win", "loss", or "left" before the end.
## `seconds` is how long it ran in game time. The matchmaker answers with the
## XP it was worth, and battle_reported carries that to the end screen.
func battle_end(result: String, seconds: float) -> void:
	if not _battle_open:
		return
	_battle_open = false
	var before := rank
	var r: Dictionary = await api(HTTPClient.METHOD_POST, "/me/battle/end", {"result": result, "seconds": seconds}, PackedStringArray(), 10.0, true)
	if OS.has_environment("FL_DEBUG_ONLINE"):
		print("ONLINE battle ended (%s, %.0f s): %s %s" % [result, seconds, str(r.data), String(r.error)])
	if not r.ok:
		battle_reported.emit({"error": r.error})
		return
	_take_user(r.data.get("user", {}))
	_save_account()
	account_changed.emit()
	battle_reported.emit({"gained": int(r.data.get("gained", 0)), "rank_before": int(r.data.get("rank_before", before)), "rank": rank})


func battle_open() -> bool:
	return _battle_open


## The rank and insignia fields of the matchmaker's user (any it leaves out
## stay as they were).
func _take_user(u: Dictionary) -> void:
	if u.get("icon") is String and not Insignia.find(String(u.icon)).is_empty():
		icon = String(u.icon)
	if u.has("xp"):
		xp = int(u.xp)
		rank = int(u.get("rank", Insignia.rank_for(xp)))
		rank_xp = int(u.get("rank_xp", Insignia.rank_xp(rank)))
		next_xp = int(u.next_xp) if u.get("next_xp") != null else -1
	fought = int(u.get("battles", fought))
	wins = int(u.get("wins", wins))
	Net.set_insignia(icon if signed_in() else "", rank if signed_in() else -1)


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
	_take_user(u)
	_save_account()
	account_changed.emit()
	if not pending.is_empty() and not _refreshing:
		flush_pending.call_deferred()


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
	# a sign-in on the website survives the game closing: its link starts it again
	_web_state = String(cf.get_value("sign_in", "state", ""))
	_web_until = int(cf.get_value("sign_in", "until", 0))
	_refresh = String(cf.get_value("account", "refresh_token", ""))
	email = String(cf.get_value("account", "email", ""))
	callsign = String(cf.get_value("account", "callsign", "")) if _refresh != "" else ""
	if callsign != "":
		Net.my_name = callsign
	if _refresh != "":
		_take_user(cf.get_value("account", "rank", {}))


func _save_account() -> void:
	var cf := ConfigFile.new()
	if _refresh != "":
		cf.set_value("account", "refresh_token", _refresh)
		cf.set_value("account", "email", email)
		cf.set_value("account", "callsign", callsign)
		cf.set_value("account", "rank", {"icon": icon, "xp": xp, "rank": rank, "rank_xp": rank_xp, "next_xp": next_xp if next_xp >= 0 else null, "battles": fought, "wins": wins})
	if _web_state != "":
		cf.set_value("sign_in", "state", _web_state)
		cf.set_value("sign_in", "until", _web_until)
	cf.save(account_path)


# --- the service record ---------------------------------------------------------------------

## The battle just fought, for the player's service record (see
## BattleStats.service_record): straight onto the matchmaker when signed in,
## otherwise kept here until they are.
func record_battle(rec: Dictionary) -> void:
	if rec.is_empty() or not record_battles:
		last_record = {"state": "", "error": ""}
		record_changed.emit()
		return
	if not signed_in():
		_wait(rec, "")
		return
	last_record = {"state": "saving", "error": ""}
	record_changed.emit()
	var r: Dictionary = await save_battle(rec)
	if r.ok:
		last_record = {"state": "saved", "error": "", "id": String(r.data.get("id", ""))}
		record_changed.emit()
	else:
		_wait(rec, String(r.error))


func _wait(rec: Dictionary, why: String) -> void:
	pending.append(rec)
	while pending.size() > MAX_PENDING:
		pending.pop_front()
	_save_pending()
	last_record = {"state": "waiting", "error": why}
	record_changed.emit()


func save_battle(rec: Dictionary) -> Dictionary:
	return await api(HTTPClient.METHOD_POST, "/me/battles", rec, PackedStringArray(), 20.0, true)


## Puts the battles waiting here on the record, oldest first; stops at the
## first the matchmaker won't take (the rest wait for next time). A battle it
## refuses outright (a bad record, 400) is dropped rather than retried forever.
func flush_pending() -> void:
	if _flushing or not signed_in() or not record_battles:
		return
	_flushing = true
	while not pending.is_empty() and signed_in():
		var r: Dictionary = await save_battle(pending[0])
		if not r.ok and int(r.code) != 400:
			break
		pending.pop_front()
		_save_pending()
		if last_record.state == "waiting" and pending.is_empty():
			last_record = {"state": "saved", "error": "", "id": String(r.data.get("id", ""))}
	_flushing = false
	record_changed.emit()


## Newest first: {data: {battles: [...], more}}. before: the played_at of the
## last one already shown.
func battles(before := "", limit := 20) -> Dictionary:
	var q := "/me/battles?limit=%d" % limit
	if before != "":
		q += "&before=" + before.uri_encode()
	return await api(HTTPClient.METHOD_GET, q, null, PackedStringArray(), 10.0, true)


## One battle with its after-action report: {data: {battle}}.
func battle(id: String) -> Dictionary:
	return await api(HTTPClient.METHOD_GET, "/me/battles/" + id.uri_encode(), null, PackedStringArray(), 15.0, true)


## The whole service record's totals: {data: {career}}.
func career() -> Dictionary:
	return await api(HTTPClient.METHOD_GET, "/me/career", null, PackedStringArray(), 15.0, true)


func _load_pending() -> void:
	var f := FileAccess.open(pending_path, FileAccess.READ)
	if f == null:
		return
	var v: Variant = JSON.parse_string(f.get_as_text())
	if v is Array:
		pending = v


func _save_pending() -> void:
	if pending.is_empty():
		if FileAccess.file_exists(pending_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(pending_path))
		return
	var f := FileAccess.open(pending_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(pending))


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
## public address). Home routers hand out 192.168.x.x (or 10.x.x.x); the
## 172.16-31 range is mostly virtual adapters (WSL, Hyper-V, Docker) that no
## one else on the network can reach, so it's only taken when there's nothing
## better.
func lan_ip() -> String:
	var best := ""
	var best_rank := 3
	for a: String in IP.get_local_addresses():
		var o := a.split(".")
		if o.size() != 4:
			continue
		var rank := 3
		if o[0] == "192" and o[1] == "168":
			rank = 0
		elif o[0] == "10":
			rank = 1
		elif o[0] == "172" and int(o[1]) >= 16 and int(o[1]) <= 31:
			rank = 2
		if rank < best_rank:
			best_rank = rank
			best = a
	return best


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
	var err := Net.join_game(String(c.get("address", "")), int(c.get("port", 0)), local, id)
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
