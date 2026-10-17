extends Node
## The test port (--test-port=N; 0 takes any free port): a test drives the game
## from outside over a local socket, one JSON object per line each way. It loads
## a battle, gives orders as a player would, steps time and asks what happened.
## The client and the tests are in tests/; docs/DEVELOPMENT.md lists the commands.
##
## Game time moves only when the test says so. The game must run with
## --fixed-fps 30 (an engine switch, before the --): every frame is then exactly
## one 1/30 s tick, as in play, however long the frame really takes. Between
## commands this node holds the frame, so nothing happens while the test thinks,
## and a seed replays the same battle every time.
##
## It listens on 127.0.0.1 only, and only when asked. Exported builds leave this
## file out (export_presets.cfg).

const TPS := 30
## Nobody connected this long after it started listening: give up.
const CONNECT_WAIT_MSEC := 60000
## What a query of structures leaves out unless asked for by kind: the map's
## countless trees and floors.
const SCENERY := ["tree", "floor"]

var main: Node  # main.gd: its world, and start_local to load a game
var _server := TCPServer.new()
var _peer: StreamPeerTCP = null
var _inbuf := PackedByteArray()
var _queue: Array = []  # requests received, not yet run
var _t_listen := 0
var _quitting := false
## A request waiting on frames to run: a step (until _steps reaches 0) or a
## load (until the new world is up).
var _waiting: Dictionary = {}
var _steps := 0
var _phys0 := 0
var _old_world: Node = null


func _ready() -> void:
	# after everything else in the frame, so a reply sees the frame's work done
	process_priority = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	var err := _server.listen(int(main.args["test-port"]), "127.0.0.1")
	if err != OK:
		print("TESTPORT can't listen on port %s (error %d)" % [str(main.args["test-port"]), err])
		_give_up()
		return
	print("TESTPORT listening 127.0.0.1:%d" % _server.get_local_port())
	_t_listen = Time.get_ticks_msec()


func _give_up() -> void:
	_quitting = true
	TestRun.fail()
	TestRun.quit(get_tree())


func _process(dt: float) -> void:
	if _quitting:
		return
	# (the engine keeps --fixed-fps to itself: tell it by the frame, which is
	# then exactly a tick whatever the clock says)
	if absf(dt - 1.0 / TPS) > 1e-6:
		print("TESTPORT needs the engine switch --fixed-fps %d before the -- (one tick per frame; this frame was %.4f s)" % [TPS, dt])
		_give_up()
		return
	if not _waiting.is_empty():
		if String(_waiting.get("cmd", "")) == "step":
			_steps -= 1
			if _steps > 0:
				return
			_reply(_waiting, _stepped())
		else:
			if not _world_ok() or main.world == _old_world:
				return
			_reply(_waiting, _loaded())
		_waiting = {}
	_serve()


## Answers requests until one needs frames to run (a step, a load) or the test
## hangs up. This holds the frame, which is what keeps game time still.
func _serve() -> void:
	while not _quitting:
		if _peer == null:
			if _server.is_connection_available():
				_peer = _server.take_connection()
				_peer.set_no_delay(true)
			elif Time.get_ticks_msec() - _t_listen > CONNECT_WAIT_MSEC:
				print("TESTPORT nobody connected")
				_give_up()
				return
			else:
				OS.delay_msec(5)
				continue
		_peer.poll()
		if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			# the test hung up: the run is over
			_quitting = true
			TestRun.quit(get_tree())
			return
		_read()
		while not _queue.is_empty():
			if _run(_queue.pop_front()):
				return
		OS.delay_msec(1)


func _read() -> void:
	var n := _peer.get_available_bytes()
	if n <= 0:
		return
	var got: Array = _peer.get_data(n)
	_inbuf.append_array(got[1])
	var nl := _inbuf.find(10)
	while nl >= 0:
		var line := _inbuf.slice(0, nl).get_string_from_utf8().strip_edges()
		_inbuf = _inbuf.slice(nl + 1)
		if line != "":
			var req: Variant = JSON.parse_string(line)
			_queue.append(req if req is Dictionary else {"cmd": "", "bad": line})
		nl = _inbuf.find(10)


## Runs one request. True when it needs frames to run before its reply.
func _run(req: Dictionary) -> bool:
	var cmd := String(req.get("cmd", ""))
	if req.has("bad"):
		_reply(req, {"ok": false, "error": "not a JSON object: %s" % String(req.bad).left(200)})
		return false
	match cmd:
		"step":
			if not _world_ok():
				_reply(req, {"ok": false, "error": "no game loaded"})
				return false
			_steps = int(req.ticks) if req.has("ticks") else roundi(float(req.get("seconds", 0.0)) * TPS)
			_phys0 = Engine.get_physics_frames()
			if _steps <= 0:
				_reply(req, _stepped())
				return false
			_waiting = req
			return true
		"load":
			var a: Variant = _load_args(req)
			if a is String:
				_reply(req, {"ok": false, "error": a})
				return false
			_old_world = main.world
			main.start_local(a)
			if _world_ok() and main.world != _old_world:
				_reply(req, _loaded())
				return false
			_waiting = req  # (the new world arrives on a later frame)
			return true
		"quit":
			_reply(req, {})
			_quitting = true
			TestRun.quit(get_tree())
			return true
	var r: Variant = _answer(cmd, req)
	if r == null:
		# a script error cut the command short (it's counted, and in "errors")
		var last: String = TestRun.recent.back() if not TestRun.recent.is_empty() else "?"
		r = {"ok": false, "error": "script error running %s: %s" % [cmd, last]}
	_reply(req, r)
	return false


## The commands that answer at once.
func _answer(cmd: String, req: Dictionary) -> Variant:
	match cmd:
		"hello":
			return {"version": Updater.version, "net": Net.NET_VERSION, "tps": TPS, "headless": DisplayServer.get_name() == "headless"}
		"errors":
			return {"count": TestRun.script_errors, "recent": TestRun.recent}
	if not _world_ok():
		return {"ok": false, "error": "no game loaded" if cmd in ["order", "query", "stats", "hash"] else "unknown command: %s" % cmd}
	var w: World = main.world
	match cmd:
		"order":
			return _order(w, req)
		"query":
			return _query(w, req)
		"stats":
			return {"t": w.time, "counters": w.stats, "report": w.battle.summary()}
		"hash":
			return {"t": w.time, "hash": _hash(w), "entities": w.entities.size()}
	return {"ok": false, "error": "unknown command: %s" % cmd}


## A load request as start_local's switches: one of scenario, mission or
## battle (AI against AI), and seed, play, autoplay, static, verbose...
func _load_args(req: Dictionary) -> Variant:
	var a := {}
	for k in req:
		var key := String(k).replace("_", "-")
		if key in ["cmd", "id"]:
			continue
		var v: Variant = req[k]
		if v is bool:
			if v:
				a[key] = "1"
		else:
			a[key] = str(int(v)) if v is float and v == floorf(v) else str(v)
	if a.has("battle"):
		a.erase("battle")
		a["aivai"] = "1"
	var what := int(a.has("scenario")) + int(a.has("mission")) + int(a.has("aivai"))
	if what != 1:
		return "load one of: scenario, mission, battle"
	# (find falls back to a mission: a mistyped key mustn't quietly play that one)
	if a.has("mission") and String(Missions.find(String(a.mission)).key) != String(a.mission):
		return "no such mission: %s" % a.mission
	a.erase("listen")  # (a test's game is always offline)
	return a


func _loaded() -> Dictionary:
	var w: World = main.world
	return {"t": w.time, "seed": int(w.settings.get("seed", 0)), "soldiers": w.soldiers.size(), "vehicles": w.vehicles.size(),
		"structures": w.structures.size(), "squads": w.squads.size()}


func _stepped() -> Dictionary:
	var w: World = main.world
	return {"t": w.time, "ticks": Engine.get_physics_frames() - _phys0, "winner": w.winner}


## A battle is loaded once it's built (with a window it's built over several
## frames: see World._breathe).
func _world_ok() -> bool:
	return main.world != null and is_instance_valid(main.world) and main.world.is_inside_tree() and main.world.srv and not main.world.building


## An order, as a commander gives it (World.execute_cmd): "t" is the order and
## the rest its fields, positions as {"v3": [x, z]} or {"v3": [x, y, z]}. It's
## given as team 0's or team 1's AI (which owns a scenario's squads too), or as
## "peer" (1: you, in a game loaded with play).
func _order(w: World, req: Dictionary) -> Dictionary:
	var d: Dictionary = _decode(req)
	var peer := int(d.get("peer", -1 - int(d.get("team", 0))))
	for k in ["cmd", "id", "peer", "team"]:
		d.erase(k)
	# what the order reaches: squads or vehicles listed but not this commander's are ignored
	var sqs: int = w._own_squads(peer, d.get("squads", [])).size()
	var vehs: int = w._own_vehicles(peer, d.get("vehicles", [])).size()
	w.execute_cmd(peer, d)
	return {"t": w.time, "squads": sqs, "vehicles": vehs}


func _decode(v: Variant) -> Variant:
	if v is Dictionary:
		if v.size() == 1 and v.has("v3"):
			var p: Array = v.v3
			return Vector3(float(p[0]), 0.0, float(p[1])) if p.size() == 2 else Vector3(float(p[0]), float(p[1]), float(p[2]))
		var out := {}
		for k in v:
			out[k] = _decode(v[k])
		return out
	if v is Array:
		var out := []
		for x in v:
			out.append(_decode(x))
		return out
	return v


## What's on the field: "what" is world, squads, soldiers, vehicles or
## structures, narrowed by "team", "kind" and "ids".
func _query(w: World, req: Dictionary) -> Dictionary:
	var what := String(req.get("what", "world"))
	var team := int(req.get("team", -9))
	var kind := String(req.get("kind", ""))
	var ids := {}
	for id in req.get("ids", []):
		ids[int(id)] = true
	var out := []
	match what:
		"world":
			return {"t": w.time, "winner": w.winner, "seed": int(w.settings.get("seed", 0)), "scenario": String(w.settings.get("scenario", "")),
				"mission": String(w.settings.get("mission", "")), "soldiers": w.soldiers.size(), "vehicles": w.vehicles.size(),
				"structures": w.structures.size(), "squads": w.squads.size(), "supply": [w.rules.supply_total(0), w.rules.supply_total(1)],
				"mission_info": _plain(w.mission_info)}
		"squads":
			for sq in w.squads.values():
				if (team == -9 or sq.team == team) and (kind == "" or sq.kind == kind) and (ids.is_empty() or ids.has(sq.sid)):
					var alive: Array = sq.alive_members()
					out.append({"id": sq.sid, "kind": sq.kind, "name": sq.display_name(), "team": sq.team, "owner": sq.owner, "order": sq.order,
						"drill": sq.drill, "morale": roundi(sq.morale), "men": sq.members.size(), "alive": alive.size(),
						"pos": _xz(sq.centroid()) if not sq.members.is_empty() else null})
		"soldiers":
			for s in w.soldiers:
				if (team == -9 or s.team == team) and (kind == "" or s.utype == kind) and (ids.is_empty() or ids.has(s.eid)):
					out.append({"id": s.eid, "type": s.utype, "team": s.team, "squad": s.sid, "life": Soldier.Life.keys()[s.life],
						"hp": snappedf(s.hp, 0.1), "pos": _xz(s.position), "posture": Soldier.Post.keys()[s.posture], "task": s.task,
						"riding": s.riding.eid if is_instance_valid(s.riding) else 0})
		"vehicles":
			for v in w.vehicles:
				if (team == -9 or v.team == team) and (kind == "" or v.vkind == kind) and (ids.is_empty() or ids.has(v.eid)):
					out.append({"id": v.eid, "kind": v.vkind, "team": v.team, "owner": v.owner_peer, "hp": snappedf(v.hp, 0.1),
						"max_hp": v.max_hp, "pos": _xz(v.position), "passengers": v.passengers.size()})
		"structures":
			for st in w.structures:
				if (team == -9 or st.team == team) and (st.skind == kind if kind != "" else not st.skind in SCENERY) and (ids.is_empty() or ids.has(st.eid)):
					out.append({"id": st.eid, "kind": st.skind, "team": st.team, "built": st.built, "progress": snappedf(st.progress, 0.01),
						"wrecked": st.wrecked, "hp": snappedf(st.hp, 0.1), "pos": _xz(st.position), "yaw": snappedf(st.yaw, 0.01)})
		_:
			return {"ok": false, "error": "query what? world, squads, soldiers, vehicles or structures"}
	return {"t": w.time, what: out}


func _xz(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.z, 0.01)]


## Something JSON can carry: vectors as arrays, objects left out.
func _plain(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v:
			out[str(k)] = _plain(v[k])
		return out
	if v is Array:
		var out := []
		for x in v:
			out.append(_plain(x))
		return out
	if v is Vector3:
		return [v.x, v.y, v.z]
	if v is Vector2:
		return [v.x, v.y]
	if v is Object:
		return null
	return v


## A fingerprint of the simulation: every entity's place and state, every
## squad, the clock and the dice. Two runs from one seed must agree on it tick
## for tick; where they part is where something escaped the seed.
func _hash(w: World) -> String:
	var parts := PackedStringArray()
	parts.append("%.4f|%d|%d" % [w.time, w.next_eid, w.rng.state])
	var eids: Array = w.entities.keys()
	eids.sort()
	for eid in eids:
		var e: Entity = w.entities[eid]
		var s := "%d:%s:%d:%.3f,%.3f,%.3f:%.2f" % [eid, e.ekind(), e.team, e.position.x, e.position.y, e.position.z, e.hp]
		if e is Soldier:
			s += ":%d:%d" % [e.life, e.posture]
		elif e is Structure:
			s += ":%s:%.2f:%s" % [str(e.built), e.progress, str(e.wrecked)]
		parts.append(s)
	for sq in w.squads.values():
		parts.append("s%d:%d:%s:%.2f" % [sq.sid, sq.members.size(), sq.drill, sq.morale])
	return "\n".join(parts).md5_text()


func _reply(req: Dictionary, r: Dictionary) -> void:
	if not r.has("ok"):
		r["ok"] = true
	r["errors"] = TestRun.script_errors
	if req.has("id"):
		r["id"] = req.id
	if _peer:
		_peer.put_data((JSON.stringify(_plain(r)) + "\n").to_utf8_buffer())
