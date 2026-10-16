class_name CoCommand
extends Node
## Co-commanders: what the other players on your side are doing, as it
## happens. Each commander's game tells the host ten times a second (once a
## second while nothing changes) where its camera is looking, where the cursor
## is, what is selected and what is being lined up - a building being placed,
## a fire mission being aimed, an order being dragged out - and the host
## passes it on to that side only (and to observers). Pings ("enemy here",
## "attack here", "on my way") go the same way. The HUD draws it all
## (hud_coop.gd, hud_coop_roster.gd, the minimap and the order of battle).
##
## A real staff works like this: the officers in a command post can see each
## other's map markings and hear what each is calling for, so two of them
## don't drop a barrage on the same wood or send two squads into one house.

enum Mode { NONE, ORDER, ARMED, PLACE, SUPPORT, ABILITY }

const SEND_EVERY := 0.1  # seconds between presence packets while something changes
const BEAT_EVERY := 1.0  # ...and while nothing does
const STALE := 5.0  # seconds without a packet before a commander is taken as gone
const MAX_PACKET := 700

const PING_KINDS := ["look", "enemy", "attack", "defend", "danger", "help", "omw", "unit"]
const PING_TEXT := {"look": "Look here", "enemy": "Enemy spotted", "attack": "Attack here", "defend": "Defend here",
	"danger": "Danger, keep clear", "help": "Need support here", "omw": "On my way", "unit": "Watch this"}
## The glyph on each ping ("" for the danger triangle, drawn on its own).
const PING_GLYPH := {"look": "eye", "enemy": "fire", "attack": "assault", "defend": "defend", "danger": "",
	"help": "radio", "omw": "move", "unit": "eye"}
## What each ping means at a glance, whoever sent it.
const PING_COLORS := {"enemy": Color(1.0, 0.42, 0.34), "attack": Color(1.0, 0.56, 0.44), "defend": Color(0.55, 0.85, 1.0),
	"danger": Color(1.0, 0.8, 0.3), "help": Color(1.0, 0.8, 0.3)}
const PING_LIFE := 9.0
const PING_LIFE_ENEMY := 14.0
const PING_MAX := 3  # each commander's pings on the map at once
const PING_BURST := 4  # pings a commander may send in PING_WINDOW seconds
const PING_WINDOW := 3.0
## The ping wheel's spokes, clockwise from the top.
const WHEEL := ["attack", "omw", "help", "danger", "defend", "look"]
const SKETCH_LIFE := 14.0
const SKETCH_PTS := 64


## One commander's presence: what his screen shows and what he's doing.
class Presence:
	extends RefCounted
	var peer := 0
	var rx := 0  # msec it last arrived
	var focus := Vector3.ZERO
	var yaw := 0.0
	var dist := 55.0
	var tilt := 0.0
	var quad := PackedVector3Array()  # the ground his screen shows: top left, top right, bottom right, bottom left
	var cur := Vector3.ZERO  # his cursor on the ground
	var cur_on := false  # (off: over his interface, or out of the window)
	var on_map := false  # the cursor is on his minimap
	var tactical := false
	var mode := 0
	var kind := ""  # what is being placed / called / thrown, or the order being given
	var a := Vector3.ZERO  # where: the ghost, the aim point, the start of a drag
	var b := Vector3.ZERO  # the other end: a line's start, a drag's end, the run-in direction
	var ryaw := 0.0  # a building's heading
	var ok := true  # (placing) the spot is good
	var drag := false
	var idle := 0  # seconds since he last touched anything
	var sq := PackedInt32Array()
	var veh := PackedInt32Array()
	var st := 0
	var unit := 0
	# drawn from these: eased toward the packets, which come ten times a second
	var s_cur := Vector3.ZERO
	var s_focus := Vector3.ZERO
	var s_quad := PackedVector3Array()
	var s_a := Vector3.ZERO
	var s_b := Vector3.ZERO
	var fresh := true

	func encode() -> PackedByteArray:
		var buf := StreamPeerBuffer.new()
		buf.put_u8((1 if cur_on else 0) | (2 if on_map else 0) | (4 if tactical else 0) | (8 if ok else 0) | (16 if drag else 0))
		CoCommand._put_xz(buf, focus)
		buf.put_float(yaw)
		buf.put_float(dist)
		buf.put_float(tilt)
		for i in 4:
			CoCommand._put_xz(buf, quad[i] if i < quad.size() else focus)
		CoCommand._put_xz(buf, cur)
		buf.put_u8(mode)
		buf.put_utf8_string(kind.substr(0, 24))
		CoCommand._put_xz(buf, a)
		CoCommand._put_xz(buf, b)
		buf.put_float(ryaw)
		buf.put_u32(st)
		buf.put_u32(unit)
		var nsq := mini(sq.size(), 40)
		buf.put_u8(nsq)
		for i in nsq:
			buf.put_u32(sq[i])
		var nv := mini(veh.size(), 40)
		buf.put_u8(nv)
		for i in nv:
			buf.put_u32(veh[i])
		buf.put_u8(clampi(idle, 0, 255))
		return buf.data_array

	## False for a packet that doesn't parse (it's then ignored).
	func decode(data: PackedByteArray) -> bool:
		if data.size() < 90 or data.size() > CoCommand.MAX_PACKET:
			return false
		var buf := StreamPeerBuffer.new()
		buf.data_array = data
		var fl := buf.get_u8()
		cur_on = (fl & 1) != 0
		on_map = (fl & 2) != 0
		tactical = (fl & 4) != 0
		ok = (fl & 8) != 0
		drag = (fl & 16) != 0
		focus = CoCommand._get_xz(buf)
		yaw = buf.get_float()
		dist = clampf(buf.get_float(), RtsCamera.MIN_DIST, RtsCamera.MAX_DIST)
		tilt = clampf(buf.get_float(), RtsCamera.TILT_MIN, RtsCamera.TILT_MAX)
		quad.resize(4)
		for i in 4:
			quad[i] = CoCommand._get_xz(buf)
		cur = CoCommand._get_xz(buf)
		mode = buf.get_u8()
		var kl := buf.get_u32()
		if kl > 64 or buf.get_position() + kl > data.size():
			return false
		buf.seek(buf.get_position() - 4)
		kind = buf.get_utf8_string()
		a = CoCommand._get_xz(buf)
		b = CoCommand._get_xz(buf)
		ryaw = buf.get_float()
		st = buf.get_u32()
		unit = buf.get_u32()
		sq.clear()
		var nsq := buf.get_u8()
		if buf.get_position() + nsq * 4 + 1 > data.size():
			return false
		for i in nsq:
			sq.append(buf.get_u32())
		veh.clear()
		var nv := buf.get_u8()
		if buf.get_position() + nv * 4 + 1 > data.size():
			return false
		for i in nv:
			veh.append(buf.get_u32())
		idle = buf.get_u8()
		if not (is_finite(yaw) and is_finite(ryaw)):
			return false
		return true

	## Where his camera stands, over the ground (the minimap draws lines back to it).
	func eye() -> Vector3:
		var pitch := deg_to_rad(RtsCamera.pitch_for(dist, tilt))
		return s_focus + Defs.flat(Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3(0, 0, dist))


## A spot marked for the whole side.
class Ping:
	extends RefCounted
	var peer := 0
	var kind := "look"
	var pos := Vector3.ZERO
	var eid := 0  # an enemy (or one of ours) it's stuck to, followed while he's in sight
	var born := 0  # msec
	var life := 9.0
	var text := ""


## A line drawn on the map for the whole side.
class Sketch:
	extends RefCounted
	var peer := 0
	var pts := PackedVector3Array()
	var born := 0  # msec


var world: World
var peers := {}  # peer -> Presence: the other commanders on your side (never yourself)
var sketches: Array = []  # Sketch, oldest first
var deeds := {}  # peer -> [[text, pos, msec], ...]: what he has committed lately, newest last
var sel_sq := {}  # sid -> the co-commander who has that squad selected
var sel_veh := {}  # vehicle eid -> the co-commander who has it selected
var pings: Array = []  # Ping, oldest first
var last_ping_t := -1.0  # world time the newest ping came in (Space jumps to it)
var last_ping_pos := Vector3.INF
var flash := {}  # peer -> msec his last ping came in (the roster lights up)
var stats := {}  # packets sent / relayed / taken in, pings in and out (tests)
var _send_t := 0.0
var _beat_t := 0.0
var _last_data := PackedByteArray()
var _input_ms := 0
var _last_ms := 0
var _ping_log := {}  # (server) peer -> msec of his recent pings
var _my_pings: Array = []  # msec of my own recent pings: the same limit, before they go
## --coop-demo (made-up teammates, drawn as if they'd sent it) and --bot-presence
## (a test client sending made-up presence for real): [peer, home, heading, phase]
var _puppets: Array = []
var _bot := false
var _puppet_pinged := {}


static func _put_xz(buf: StreamPeerBuffer, p: Vector3) -> void:
	buf.put_float(p.x if is_finite(p.x) else 0.0)
	buf.put_float(p.z if is_finite(p.z) else 0.0)


static func _get_xz(buf: StreamPeerBuffer) -> Vector3:
	var x := buf.get_float()
	var z := buf.get_float()
	if not (is_finite(x) and is_finite(z)):
		return Vector3.ZERO
	var lim := MapDims.HALF * 2.0
	return Vector3(clampf(x, -lim, lim), 0.0, clampf(z, -lim, lim))


func _ready() -> void:
	_input_ms = Time.get_ticks_msec()
	_last_ms = _input_ms
	if world.srv:
		Net.player_left.connect(_on_player_left)


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion or ev is InputEventMouseButton or ev is InputEventKey:
		_input_ms = Time.get_ticks_msec()


# --- who's who ------------------------------------------------------------------------------

func color(peer: int) -> Color:
	return Net.player_color(peer)


func pname(peer: int) -> String:
	return Net.player_name(peer)


## Two letters for a badge: the initials of a two-word name, else its first two.
func initials(peer: int) -> String:
	var n := pname(peer).strip_edges()
	var parts := n.split(" ", false)
	if parts.size() >= 2:
		return (parts[0].substr(0, 1) + parts[1].substr(0, 1)).to_upper()
	return n.substr(0, 2).to_upper() if n != "" else "?"


## What a commander is doing right now, in a few words ("" when nothing in
## particular); `where` adds the grid square.
func activity(p: Presence, where := false) -> String:
	var at := ("  ·  " + Defs.grid_ref(p.a)) if where else ""
	match p.mode:
		Mode.PLACE:
			var bn := String(Defs.BUILDINGS.get(p.kind, {}).get("name", p.kind.capitalize()))
			if p.drag:
				return ("Digging a trench line" if p.kind == "trench" else "Laying a line of %s" % bn.to_lower()) + at
			return "Placing %s" % bn + at
		Mode.SUPPORT:
			return "Aiming %s" % String(Defs.SUPPORT.get(p.kind, {}).get("name", p.kind)) + at
		Mode.ABILITY:
			return String({"frag": "Throwing a grenade", "smoke": "Throwing smoke", "mortar_he": "Mortar fire mission",
				"pit_he": "Mortar fire mission", "mortar_smoke": "Mortar smoke mission", "pit_smoke": "Mortar smoke mission",
				"arty_he": "Artillery fire mission"}.get(p.kind, "Targeting")) + at
		Mode.ORDER:
			return String({"assault": "Ordering an attack", "defend": "Ordering a defence"}.get(p.kind, "Giving a move order")) + at
		Mode.ARMED:
			return "Attack-move: picking the spot" if p.kind == "assault" else "Defend: picking the spot"
	return ""


func _count(key: String) -> void:
	stats[key] = int(stats.get(key, 0)) + 1


## One line for the tests: the counters and what each co-commander was last doing.
func summary() -> String:
	var out := str(stats)
	for p in list():
		out += " | %s(%d) %s sq=%d veh=%d idle=%d at %s" % [pname(p.peer), p.peer, Mode.keys()[clampi(p.mode, 0, Mode.size() - 1)],
			p.sq.size(), p.veh.size(), p.idle, Defs.grid_ref(p.focus)]
	return out


## The other commanders on your side, in a steady order.
func list() -> Array:
	var ids := peers.keys()
	ids.sort()
	var out := []
	for id in ids:
		out.append(peers[id])
	return out


# --- the local commander's presence -------------------------------------------------------

func _process(_dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	# real time: presence and pings keep going while the game is paused or slowed
	var now := Time.get_ticks_msec()
	var rdt := clampf((now - _last_ms) / 1000.0, 0.0, 0.25)
	_last_ms = now
	_send_t -= rdt
	_beat_t -= rdt
	if _send_t <= 0.0:
		_send_t = SEND_EVERY
		_send_tick()
	if not _puppets.is_empty():
		_puppet_tick()
	if world.has_view:
		_smooth(rdt)
	_prune(now)
	world.vp("co-command", t0)


func _send_tick() -> void:
	# a client waits until the host's world is up and talking to it
	if not world.srv and world.entities.is_empty():
		return
	var p: Presence = null
	if _bot and not _puppets.is_empty():
		if _puppets[0][1] == Vector3.INF:
			return
		p = _puppet_presence(0)
	elif world.has_view and world.cam and world.input and world.hud:
		p = _capture()
	if p == null:
		return
	var data := p.encode()
	if data == _last_data and _beat_t > 0.0:
		return
	_beat_t = BEAT_EVERY
	_last_data = data
	_count("sent")
	if world.srv:
		_relay(world.local_peer, data)
	else:
		_rpc_presence.rpc_id(1, data)


## What this commander's screen shows and what he's doing with it.
func _capture() -> Presence:
	var p := Presence.new()
	var cam := world.cam
	var inp := world.input
	p.focus = cam.focus_pos
	p.yaw = cam.yaw
	p.dist = cam.target_dist
	p.tilt = cam.tilt
	var vs := get_viewport().get_visible_rect().size
	for sp in [Vector2(0, 0), Vector2(vs.x, 0), vs, Vector2(0, vs.y)]:
		p.quad.append(cam.ground_point(sp))
	var mp := inp._mouse()
	# what's being lined up sits on the ground under the mouse, as his own preview
	# does, even with the cursor over a panel
	var gp := cam.ground_point(mp)
	if Rect2(Vector2.ZERO, vs).has_point(mp):
		var hc := get_viewport().gui_get_hovered_control()
		if hc == null or inp.debug_mouse.x >= 0.0:
			p.cur = cam.ground_point(mp)
			p.cur_on = true
		elif hc == world.hud.minimap:
			# pointing at something on the minimap: that's where he's looking
			p.cur = world.hud.minimap._to_world(world.hud.minimap.get_local_mouse_position())
			p.cur_on = true
			p.on_map = true
	p.tactical = world.hud.tactical
	if inp.place_kind != "":
		p.mode = Mode.PLACE
		p.kind = inp.place_kind
		p.a = Defs.flat(inp.ghost.position) if inp.ghost else gp
		p.ryaw = inp.place_yaw
		p.ok = inp.ghost_err == ""
		p.drag = inp.place_drag
		p.b = inp.place_a
	elif inp.ability.begins_with("support:") or inp.ability.begins_with("demo:"):
		p.mode = Mode.SUPPORT
		p.kind = inp.ability.get_slice(":", 1)
		p.drag = inp.ab_drag
		p.a = inp.ab_gp if inp.ab_drag else gp
		p.b = p.a + inp.support_dir() * 10.0
	elif inp.ability != "":
		p.mode = Mode.ABILITY
		p.kind = inp.ability
		p.a = gp
	elif inp.rmb:
		p.mode = Mode.ORDER
		p.kind = inp.order_mode if inp.order_mode != "" else ("assault" if inp.rmb_ctrl else "move")
		p.a = inp.rmb_gp
		p.b = gp
		p.drag = mp.distance_to(inp.rmb_start) > 18.0
	elif inp.order_mode != "":
		p.mode = Mode.ARMED
		p.kind = inp.order_mode
		p.a = gp
	p.sq = PackedInt32Array(inp.sel_squads)
	p.veh = PackedInt32Array(inp.sel_vehicles)
	p.st = inp.sel_structure
	p.unit = inp.sel_unit
	p.idle = int((Time.get_ticks_msec() - _input_ms) / 1000)
	return p


# --- the network ------------------------------------------------------------------------------

## Whether a peer may see a commander of `team` at work: his own side, and
## observers. (Never the enemy: where you're looking gives your plan away.)
func _sees(viewer: int, team: int) -> bool:
	var vt := world.team_of_peer(viewer)
	return vt < 0 or vt == team


func _relay(from: int, data: PackedByteArray) -> void:
	var ft := world.team_of_peer(from)
	for p in world.ready_peers:
		if p != from and _sees(p, ft):
			_rpc_presence_of.rpc_id(p, from, data)
			_count("relayed")
	if from != world.local_peer and world.has_view and _sees(world.local_peer, ft):
		_store(from, data)


@rpc("any_peer", "call_remote", "unreliable_ordered", 4)
func _rpc_presence(data: PackedByteArray) -> void:
	if not world.srv:
		return
	var from := multiplayer.get_remote_sender_id()
	if not from in world.ready_peers or data.size() > MAX_PACKET:
		return
	_relay(from, data)


@rpc("authority", "call_remote", "unreliable_ordered", 4)
func _rpc_presence_of(from: int, data: PackedByteArray) -> void:
	if from != world.local_peer:
		_store(from, data)


func _store(from: int, data: PackedByteArray) -> void:
	var p: Presence = peers.get(from)
	var fresh := p == null
	if fresh:
		p = Presence.new()
		p.peer = from
	if not p.decode(data):
		_count("bad")
		return
	_count("taken")
	p.rx = Time.get_ticks_msec()
	if fresh:
		_snap(p)
		peers[from] = p


## A commander gone (left, or silent too long).
@rpc("authority", "call_remote", "reliable")
func _rpc_gone(peer: int) -> void:
	peers.erase(peer)
	if world.cam and world.cam.shadow == peer:
		world.cam.stop_shadow()


func _on_player_left(id: int, _team: int, _pname: String) -> void:
	peers.erase(id)
	_ping_log.erase(id)
	for p in world.ready_peers:
		if p != id:
			_rpc_gone.rpc_id(p, id)
	if world.cam and world.cam.shadow == id:
		world.cam.stop_shadow()


func _prune(now: int) -> void:
	for id in peers.keys():
		if now - (peers[id] as Presence).rx > int(STALE * 1000.0):
			peers.erase(id)
			if world.cam and world.cam.shadow == id:
				world.cam.stop_shadow()
	for i in range(pings.size() - 1, -1, -1):
		var pg: Ping = pings[i]
		if now - pg.born > int(pg.life * 1000.0):
			pings.remove_at(i)
	for i in range(sketches.size() - 1, -1, -1):
		if now - (sketches[i] as Sketch).born > int(SKETCH_LIFE * 1000.0):
			sketches.remove_at(i)


func _snap(p: Presence) -> void:
	p.s_cur = p.cur
	p.s_focus = p.focus
	p.s_quad = p.quad.duplicate()
	p.s_a = p.a
	p.s_b = p.b


## Eases each commander's cursor and view toward the last packet, so they glide
## at the screen's frame rate rather than hop ten times a second.
func _smooth(dt: float) -> void:
	var k := 1.0 - exp(-dt * 14.0)
	sel_sq.clear()
	sel_veh.clear()
	for p in peers.values():
		var pr: Presence = p
		for sid in pr.sq:
			sel_sq[sid] = pr.peer
		for id in pr.veh:
			sel_veh[id] = pr.peer
		if pr.s_quad.size() != pr.quad.size():
			_snap(pr)
			continue
		# a jump across the map snaps rather than sweeping over everything between
		if Defs.flat(pr.s_focus - pr.focus).length() > 120.0:
			_snap(pr)
			continue
		pr.s_focus = pr.s_focus.lerp(pr.focus, k)
		pr.s_cur = pr.s_cur.lerp(pr.cur, k) if Defs.flat(pr.s_cur - pr.cur).length() < 120.0 else pr.cur
		pr.s_a = pr.s_a.lerp(pr.a, k) if Defs.flat(pr.s_a - pr.a).length() < 60.0 else pr.a
		pr.s_b = pr.s_b.lerp(pr.b, k) if Defs.flat(pr.s_b - pr.b).length() < 60.0 else pr.b
		for i in pr.quad.size():
			pr.s_quad[i] = pr.s_quad[i].lerp(pr.quad[i], k)


# --- pings ------------------------------------------------------------------------------------

## Whether the local commander may mark something now (the host holds him to
## the same limit; checking here first keeps his own marks honest).
func _may_mark() -> bool:
	var now := Time.get_ticks_msec()
	while not _my_pings.is_empty() and now - int(_my_pings[0]) > int(PING_WINDOW * 1000.0):
		_my_pings.pop_front()
	if _my_pings.size() >= PING_BURST:
		if world.hud:
			world.hud.flash("Easy on the pings")
		return false
	_my_pings.append(now)
	return true


## (server) Whether a commander's mark gets through: a few a second at most,
## so nobody can flood his side's screens.
func _mark_ok(from: int) -> bool:
	var now := Time.get_ticks_msec()
	var recent: Array = _ping_log.get(from, [])
	while not recent.is_empty() and now - int(recent[0]) > int(PING_WINDOW * 1000.0):
		recent.pop_front()
	if recent.size() >= PING_BURST:
		return false
	recent.append(now)
	_ping_log[from] = recent
	return true


## The local commander marks a spot (or a unit) for his side.
func ping(kind: String, pos: Vector3, eid := 0) -> void:
	if not kind in PING_KINDS or not _may_mark():
		return
	pos = Defs.flat(pos)
	_add_ping(world.local_peer, kind, pos, eid)
	if world.srv:
		_ping_from(world.local_peer, kind, pos, eid)
	else:
		_rpc_ping_req.rpc_id(1, kind, pos, eid)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_ping_req(kind: String, pos: Vector3, eid: int) -> void:
	if world.srv:
		_ping_from(multiplayer.get_remote_sender_id(), kind, pos, eid)


## (server) A ping from `from`: checked, then passed to his side.
func _ping_from(from: int, kind: String, pos: Vector3, eid: int) -> void:
	var team := world.team_of_peer(from)
	if not kind in PING_KINDS or not (is_finite(pos.x) and is_finite(pos.z)) or not _mark_ok(from):
		return
	pos = Vector3(clampf(pos.x, -MapDims.HALF, MapDims.HALF), 0.0, clampf(pos.z, -MapDims.HALF, MapDims.HALF))
	# only something his side can see right now may be marked
	var e: Entity = world.entity(eid) if eid != 0 else null
	if e and team >= 0 and e.team >= 0 and e.team != team and ((e.vis_mask >> team) & 1) == 0:
		eid = 0
	elif e == null:
		eid = 0
	for p in world.ready_peers:
		if p != from and _sees(p, team):
			_rpc_ping.rpc_id(p, from, kind, pos, eid)
	if from != world.local_peer and world.has_view and _sees(world.local_peer, team):
		_add_ping(from, kind, pos, eid)


@rpc("authority", "call_remote", "reliable")
func _rpc_ping(from: int, kind: String, pos: Vector3, eid: int) -> void:
	if kind in PING_KINDS:
		_add_ping(from, kind, pos, eid)


func _add_ping(from: int, kind: String, pos: Vector3, eid: int) -> void:
	if not world.has_view:
		_count("pings_out" if from == world.local_peer else "pings_in")
		return
	var pg := Ping.new()
	pg.peer = from
	pg.kind = kind
	pg.pos = pos
	pg.eid = eid
	pg.born = Time.get_ticks_msec()
	pg.life = PING_LIFE_ENEMY if kind == "enemy" else PING_LIFE
	pg.text = _ping_text(pg)
	# a commander's own oldest mark makes way for his newest
	var mine := 0
	for i in range(pings.size() - 1, -1, -1):
		if (pings[i] as Ping).peer == from:
			mine += 1
			if mine >= PING_MAX:
				pings.remove_at(i)
	pings.append(pg)
	last_ping_t = world.time
	last_ping_pos = pos
	flash[from] = pg.born
	_count("pings_out" if from == world.local_peer else "pings_in")
	if from != world.local_peer:
		Sfx.ui("ping_alert" if kind in ["enemy", "danger", "help"] else "ping")
		if world.hud:
			world.hud.add_message("ping", "%s: %s (%s)" % [pname(from), pg.text, Defs.grid_ref(pos)])
	else:
		Sfx.ui("ping")


## What a ping says: the kind, and what it's on.
func _ping_text(pg: Ping) -> String:
	var t: String = PING_TEXT.get(pg.kind, "Look here")
	var e: Entity = world.entity(pg.eid) if pg.eid != 0 else null
	if e == null or e.gone:
		return t
	if pg.kind == "enemy":
		return "%s: %s" % [t, e.display_name()]
	if e is Soldier and (e as Soldier).sid != 0 and e.team == world.local_team:
		return "%s: %s" % [t, Squad.callsign_of(e.team, (e as Soldier).sid)]
	return "%s: %s" % [t, e.display_name()]


## Where a ping is now: on the unit it marks while he can be seen, else where it was put.
func ping_pos(pg: Ping) -> Vector3:
	if pg.eid != 0:
		var e: Entity = world.entity(pg.eid)
		if e and not e.gone and e.visible and e.seen_by_local():
			pg.pos = Defs.flat(e.position)
	return pg.pos


## The ping that suits what's under the cursor: an enemy in sight is
## "enemy spotted", one of ours "watch this", open ground "look here".
func context_ping(e: Entity) -> String:
	if e == null or not (e is Soldier or e is Vehicle or e is Structure):
		return "look"
	if e.is_hostile_to(world.local_team) and e.seen_by_local():
		return "enemy"
	if e.team == world.local_team and not e is Structure:
		return "unit"
	return "look"


# --- sketches ---------------------------------------------------------------------------------

## The local commander draws on the map for his side (Alt+right-drag): a
## route, an axis of advance, a line to hold. Up to SKETCH_PTS points.
func sketch(pts: PackedVector3Array) -> void:
	if pts.size() < 2 or not _may_mark():
		return
	var flat := _flat2(pts)
	_add_sketch(world.local_peer, flat)
	if world.srv:
		_sketch_from(world.local_peer, flat)
	else:
		_rpc_sketch_req.rpc_id(1, flat)


## A line on the ground as map points (x, z), at most SKETCH_PTS of them.
static func _flat2(pts: PackedVector3Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in mini(pts.size(), SKETCH_PTS):
		out.append(Vector2(pts[i].x, pts[i].z))
	return out


@rpc("any_peer", "call_remote", "reliable")
func _rpc_sketch_req(pts: PackedVector2Array) -> void:
	if world.srv:
		_sketch_from(multiplayer.get_remote_sender_id(), pts)


## (server) A sketch from `from`: checked, then passed to his side.
func _sketch_from(from: int, pts: PackedVector2Array) -> void:
	if pts.size() < 2 or pts.size() > SKETCH_PTS or not _mark_ok(from):
		return
	for i in pts.size():
		var q := pts[i]
		if not (is_finite(q.x) and is_finite(q.y)):
			return
		pts[i] = Vector2(clampf(q.x, -MapDims.HALF, MapDims.HALF), clampf(q.y, -MapDims.HALF, MapDims.HALF))
	var team := world.team_of_peer(from)
	for p in world.ready_peers:
		if p != from and _sees(p, team):
			_rpc_sketch.rpc_id(p, from, pts)
	if from != world.local_peer and world.has_view and _sees(world.local_peer, team):
		_add_sketch(from, pts)


@rpc("authority", "call_remote", "reliable")
func _rpc_sketch(from: int, pts: PackedVector2Array) -> void:
	if pts.size() >= 2 and pts.size() <= SKETCH_PTS:
		_add_sketch(from, pts)


func _add_sketch(from: int, pts: PackedVector2Array) -> void:
	_count("sketches_out" if from == world.local_peer else "sketches_in")
	if not world.has_view:
		return
	var sk := Sketch.new()
	sk.peer = from
	sk.born = Time.get_ticks_msec()
	for q in pts:
		sk.pts.append(Vector3(q.x, 0.0, q.y))
	var mine := 0
	for i in range(sketches.size() - 1, -1, -1):
		if (sketches[i] as Sketch).peer == from:
			mine += 1
			if mine >= PING_MAX:
				sketches.remove_at(i)
	sketches.append(sk)
	flash[from] = sk.born
	last_ping_t = world.time
	last_ping_pos = sk.pts[sk.pts.size() - 1]
	if from != world.local_peer:
		Sfx.ui("ping")


# --- what they've committed -------------------------------------------------------------------

## (server) Something a commander has done for good - put down a building,
## called in fire support, set a squad training, started research - told to
## the rest of his side, so they know where the supply went. `loud` ones
## (fire support, research) show as a notification, the rest in the log.
func deed(peer: int, text: String, pos: Vector3, loud := false) -> void:
	if peer <= 0:
		return
	var team := world.team_of_peer(peer)
	for p in world.ready_peers:
		if p != peer and _sees(p, team):
			_rpc_deed.rpc_id(p, peer, text, pos, loud)
	if peer != world.local_peer and _sees(world.local_peer, team):
		_add_deed(peer, text, pos, loud)


@rpc("authority", "call_remote", "reliable")
func _rpc_deed(peer: int, text: String, pos: Vector3, loud: bool) -> void:
	_add_deed(peer, text.substr(0, 120), pos, loud)


func _add_deed(peer: int, text: String, pos: Vector3, loud: bool) -> void:
	_count("deeds_in")
	var l: Array = deeds.get(peer, [])
	l.append([text, Defs.flat(pos), Time.get_ticks_msec()])
	if l.size() > 8:
		l.pop_front()
	deeds[peer] = l
	if world.hud:
		world.hud.add_message("ping", "%s: %s (%s)" % [pname(peer), text, Defs.grid_ref(pos)], loud)


## His latest committed action, if it was in the last `secs`: [text, pos, age] or [].
func last_deed(peer: int, secs: float) -> Array:
	var l: Array = deeds.get(peer, [])
	if l.is_empty():
		return []
	var d: Array = l.back()
	var age := (Time.get_ticks_msec() - int(d[2])) / 1000.0
	return [d[0], d[1], age] if age < secs else []


# --- made-up commanders, for testing ------------------------------------------------------

## --coop-demo=N: N made-up commanders on your side, each with a squad of his
## own, looking about near you, lining things up and pinging. For screenshots
## and for trying the interface alone. (Host only: they're given real squads.)
func start_demo(n: int) -> void:
	if not world.srv or world.local_team < 0 or world.cam == null:
		return
	var names := ["Rook", "Viper", "Kestrel", "Nomad"]
	var t := world.local_team
	var fob: Structure = null
	for s in world.structures:
		if s.skind == "fob" and s.team == t:
			fob = s
			break
	var home := world.cam.focus_pos
	var fwd := Vector3.FORWARD if t == 0 else Vector3.BACK
	for i in clampi(n, 1, 4):
		var id := 9001 + i
		Net.players[id] = {"name": names[i], "team": t, "col": i + 1}
		var side := fwd.cross(Vector3.UP) * (34.0 if i % 2 == 0 else -34.0) * (1 + i / 2)
		var spot := home + side + fwd * 14.0
		if fob:
			world.rules.spawn_squad("rifle_squad" if t == 0 else "fighter_cell", t, id, fob.position + side * 0.5 + fwd * 8.0, spot + fwd * 6.0)
		_puppets.append([id, spot, world.cam.yaw, i * 7.3])


## --bot-presence (a client, usually headless): this game's presence is made
## up the way --coop-demo's is and really sent, to test the whole path.
func start_bot() -> void:
	_bot = true
	_puppets = [[world.local_peer, Vector3.INF, 0.0, 3.1]]


func _puppet_tick() -> void:
	if _bot:
		var pp: Array = _puppets[0]
		if pp[1] == Vector3.INF:
			# looking out from our own FOB
			for s in world.structures:
				if s.skind == "fob" and s.team == world.local_team:
					var fwd := Vector3.FORWARD if s.team == 0 else Vector3.BACK
					pp[1] = s.position + fwd * 26.0
					pp[2] = 0.0 if s.team == 0 else PI
					break
		if pp[1] == Vector3.INF:
			return
		_puppet_pings(0, true)
		return
	for i in _puppets.size():
		var p := _puppet_presence(i)
		var old: Presence = peers.get(p.peer)
		if old:
			p.s_cur = old.s_cur
			p.s_focus = old.s_focus
			p.s_quad = old.s_quad
			p.s_a = old.s_a
			p.s_b = old.s_b
		else:
			_snap(p)
		p.rx = Time.get_ticks_msec()
		peers[p.peer] = p
		_puppet_pings(i, false)


## A made-up commander at time t: his view drifts about the ground he's
## watching, his cursor wanders over it, and every so often he lines
## something up (a trench line, a fire mission, an assault).
func _puppet_presence(i: int) -> Presence:
	var pp: Array = _puppets[i]
	var p := Presence.new()
	p.peer = int(pp[0])
	var home: Vector3 = pp[1]
	var heading: float = pp[2]
	var t := _puppet_time() + float(pp[3])
	var fwd := Defs.dir_of(heading)
	var right := fwd.cross(Vector3.UP).normalized()
	p.focus = home + right * sin(t * 0.11) * 10.0 + fwd * cos(t * 0.08) * 6.0
	p.yaw = heading + sin(t * 0.05) * 0.25
	p.dist = 58.0
	p.quad = _view_quad(p.focus, p.yaw, p.dist, 0.0)
	p.cur = p.focus + right * sin(t * 0.7) * 11.0 + fwd * (cos(t * 0.53) * 7.0 + 4.0)
	p.cur_on = true
	for sq in (world.squads.values() if world.srv else []):
		if sq.owner == p.peer:
			p.sq.append(sq.sid)
	if p.sq.is_empty():
		for s in world.soldiers:
			if s.owner_peer == p.peer and s.sid != 0 and not s.sid in p.sq:
				p.sq.append(s.sid)
	var ph := fmod(t, 24.0)
	if ph > 6.0 and ph < 11.0:
		p.mode = Mode.PLACE
		p.kind = "trench"
		p.a = p.cur
		p.b = p.cur - right * 16.0
		p.drag = true
		p.ryaw = heading
	elif ph > 11.0 and ph < 16.0:
		var sups := Defs.supports_for(maxi(0, world.team_of_peer(p.peer)))
		p.mode = Mode.SUPPORT
		p.kind = "artillery" if "artillery" in sups else (String(sups[0]) if not sups.is_empty() else "")
		p.a = p.cur
		p.b = p.a + fwd * 10.0
	elif ph > 16.0 and ph < 20.0:
		# dragging an assault out: pressed back there, the cursor setting the facing
		p.mode = Mode.ORDER
		p.kind = "assault"
		p.a = p.cur - fwd * 9.0
		p.b = p.cur
		p.drag = true
	elif ph > 20.0:
		p.mode = Mode.ARMED
		p.kind = "defend"
		p.a = p.cur
	p.idle = 0
	return p


func _puppet_time() -> float:
	return Time.get_ticks_msec() / 1000.0 if _bot else world.time


## Each made-up commander pings now and then: an enemy he can see (or a spot
## ahead), a danger area, his way forward.
func _puppet_pings(i: int, send: bool) -> void:
	var pp: Array = _puppets[i]
	var t := _puppet_time() + float(pp[3])
	var slot := int(t / 8.0)
	var key := "%d:%d" % [int(pp[0]), slot]
	if _puppet_pinged.has(key) or fmod(t, 8.0) < 2.5:
		return
	_puppet_pinged[key] = true
	var home: Vector3 = pp[1]
	var fwd := Defs.dir_of(float(pp[2]))
	var right := fwd.cross(Vector3.UP).normalized()
	var kinds := ["enemy", "sketch", "danger", "omw", "attack", "defend", "help"]
	var kind: String = kinds[(slot + i) % kinds.size()]
	var pos := home + fwd * 40.0 + right * sin(t) * 15.0
	var eid := 0
	if kind == "sketch":
		# a hooking axis of advance, out round a flank and in
		var bend := 1.0 if i % 2 == 0 else -1.0
		var line := PackedVector3Array()
		for k in 12:
			var f := k / 11.0
			line.append(home + fwd * (6.0 + f * 46.0) + right * bend * sin(f * PI) * 16.0)
		if send:
			sketch(line)
		else:
			_add_sketch(int(pp[0]), _flat2(line))
		# and what he has committed lately
		if world.srv and not send:
			deed(int(pp[0]), "Called in 155 mm Artillery" if i % 2 == 1 else "Laid 6 × Trench", home + fwd * 30.0, i % 2 == 1)
		return
	if kind == "enemy":
		var best := 1e9
		for e in world.soldiers:
			if e.team >= 0 and e.team != world.local_team and e.life == Soldier.Life.ALIVE and e.seen_by_local():
				var d := Defs.flat(e.position - home).length()
				if d < best:
					best = d
					eid = e.eid
					pos = e.position
		if eid == 0:
			kind = "look"
	if send:
		ping(kind, pos, eid)
	else:
		_add_ping(int(pp[0]), kind, pos, eid)


## The patch of ground a 16:9 screen shows from an RTS camera set this way
## (a made-up commander's view; real ones send their own).
func _view_quad(focus: Vector3, yaw: float, dist: float, tilt: float) -> PackedVector3Array:
	var pitch := deg_to_rad(RtsCamera.pitch_for(dist, tilt))
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var eye := focus + basis * Vector3(0, 0, dist)
	var fov := deg_to_rad(clampf(float(Settings.get_v("fov")), 35.0, 75.0))
	var th := tan(fov * 0.5)
	var tw := th * 16.0 / 9.0
	var out := PackedVector3Array()
	for uv in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var d := (basis * Vector3(uv.x * tw, uv.y * th, -1.0)).normalized()
		d.y = minf(d.y, -RtsCamera.MIN_RAY_DIP)
		var k := -eye.y / d.y
		out.append(Vector3(eye.x + d.x * k, 0.0, eye.z + d.z * k))
	return out
