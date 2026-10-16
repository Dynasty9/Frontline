class_name World
extends Node3D
## The battlefield. On the host it owns the simulation and replicates it; on
## clients it mirrors entities from spawn/snapshot RPCs. The node path
## (/root/Main/World) is identical on every peer so RPCs line up.

signal game_ended(winner: int)

var settings: Dictionary = {}
var srv := false
var has_view := true
var local_peer := 1
var local_team := 0
var time := 0.0
var entities := {}
var next_eid := 1
var ready_peers: Array = []
var known := {}  # peer -> {eid: true}: what each client has been told exists
var _reveal_t := 0.0
var tick_ms := 0.0
var prof := {}
var net_out_bps := 0.0
var net_in_bps := 0.0
var _net_out := 0.0
var _net_in := 0.0
var _net_in_t := 0.0
var _pend_spawn: Array = []
var _pend_despawn: Array = []
var _pend_props: Dictionary = {}
var _pend_fx: Array = []
var _snap_t := 0.0
var _team_t := 0.0

var nav: Nav
var combat: Combat
var rules: Rules
var fires: Fires  # (server) what's burning
var fx: Fx
var phys: PhysicsFx  # ragdolls, thrown chunks, tossed props (clients only)
var cam: RtsCamera
var input: PlayerInput
var hud: Hud
var coop: CoCommand  # what the other commanders on our side are doing (every peer: it relays too)
var squads := {}
var next_sid := 1
var commanders: Array = []
var mission: MissionDirector = null  # (server) the mission being played, if it is one
var mission_info: Dictionary = {}  # the mission's state as the HUD shows it (every peer)
var mission_rx_t := 0.0  # world time mission_info arrived (its clocks run on from there)
var team_info: Array = [{}, {}]
var roads: Array = [[], [], []]  # team 0 / team 1 supply tracks, [2] the map's own roads
var decor: Array = []  # street furniture and set dressing: [kind, pos, yaw, extra] (see Decor)
var town_rect := Rect2()  # where the streets are paved
var key_points: Array = []  # ground worth holding: [{"pos", "kind" ("town", "village", "woods")}] (server)
var _decor_node: Node3D
var terrain: TerrainMap
var water: WaterMap
var _painted_roads := -1
var _road_meshes: Array = [null, null, null]
var pings: Array = []  # [pos, expire, kind]
var winner := -1
var rng := RandomNumberGenerator.new()
var focused := false
var director: Director
var fog: FogView  # the fog of war drawn over the ground and the minimap (clients and a host with a view)
var atmo: Atmosphere
var view_team := -1  # whose fog of war we render (spectators can switch)

var soldiers: Array = []
var vehicles: Array = []
var structures: Array = []
var projectiles: Array = []
var drones: Array = []

const HCELL := 12.0
var _uhash := {}
const SCELL := 16.0
var _shash := {}


func _ready() -> void:
	srv = multiplayer.is_server()
	has_view = DisplayServer.get_name() != "headless"
	local_peer = multiplayer.get_unique_id()
	var pl: Dictionary = settings.get("players", {})
	local_team = int(pl[local_peer].team) if pl.has(local_peer) else -1
	view_team = local_team
	rng.seed = int(settings.get("seed", 1))
	terrain = TerrainMap.new(self)
	water = WaterMap.new(self)
	if has_view:
		_build_environment()
	fx = Fx.new()
	fx.name = "Fx"
	fx.world = self
	add_child(fx)
	coop = CoCommand.new()
	coop.name = "CoCommand"
	coop.world = self
	add_child(coop)
	if has_view:
		phys = PhysicsFx.new(self)
		phys.name = "Phys"
		add_child(phys)
	if srv:
		nav = Nav.new()
		nav.terrain = terrain
		combat = Combat.new(self)
		rules = Rules.new(self)
		fires = Fires.new(self)
		if String(settings.get("scenario", "")) != "":
			MapGen.new(self).scenario(String(settings.scenario))
		elif String(settings.get("mission", "")) != "":
			var mgen := MapGen.new(self)
			mgen.generate()
			mission = MissionDirector.new(self, String(settings.mission), mgen)
			mission.setup()
			set_mission_info(mission.info())
		else:
			MapGen.new(self).generate()
		terrain.tick(1 << 30)
		_water_view()
		var tn := Time.get_ticks_msec()
		nav.finalize()
		print("Hierarchical nav: %s infantry, %s vehicles (%d ms)" % [nav.hnav_i.stats(), nav.hnav_v.stats(), Time.get_ticks_msec() - tn])
		if OS.has_environment("FL_DEBUG_HPA"):
			nav.benchmark(rng)
		for t in settings.get("ai_teams", []):
			commanders.append(CommanderAI.new(self, int(t)))
		Net.player_left.connect(_on_player_left)
		Net.player_joined.connect(_on_player_joined)
	if has_view:
		cam = RtsCamera.new()
		cam.name = "Cam"
		cam.world = self
		add_child(cam)
		director = Director.new()
		director.name = "Director"
		director.world = self
		add_child(director)
		fog = FogView.new()
		fog.name = "FogView"
		fog.world = self
		add_child(fog)
		input = PlayerInput.new()
		input.name = "Input"
		input.world = self
		add_child(input)
		hud = Hud.new()
		hud.name = "Hud"
		hud.world = self
		add_child(hud)
		_try_focus()
	if not srv:
		_client_ready.rpc_id(1)


# --- environment ------------------------------------------------------------

func _build_environment() -> void:
	atmo = Atmosphere.new()
	atmo.name = "Atmosphere"
	add_child(atmo)
	atmo.setup(self)


func _try_focus() -> void:
	if focused or cam == null:
		return
	if not mission_info.is_empty() and mission_info.get("focus") != null and local_team >= 0:
		cam.focus(mission_info.focus)
		cam.set_heading(float(mission_info.get("fyaw", 0.0)))
		focused = true
		return
	for st in structures:
		if st.skind == "fob" and (st.team == local_team or local_team < 0):
			cam.focus(st.position + Vector3(0, 0, 10 if st.team == 0 else -10))
			if local_team == 1:
				cam.set_heading(PI)
			focused = true
			return


# --- entity lifecycle -----------------------------------------------------------

func _make(kind: String) -> Entity:
	match kind:
		"soldier":
			return Soldier.new()
		"structure":
			return Structure.new()
		"vehicle":
			return Vehicle.new()
		"projectile":
			return Projectile.new()
		"drone":
			return Drone.new()
	push_error("Unknown entity kind: " + kind)
	return Entity.new()


func spawn(kind: String, props: Dictionary) -> Entity:
	var e := _make(kind)
	e.world = self
	e.eid = next_eid
	next_eid += 1
	e.srv = true
	e.apply_props(props)
	e.name = "E%d" % e.eid
	_register(e)
	add_child(e)
	e.on_spawned()
	if e is Structure:
		_shash_add(e)
		terrain.structure_changed(e, true)
	if not ready_peers.is_empty():
		_pend_spawn.append([e.eid, kind])
	return e


func _register(e: Entity) -> void:
	entities[e.eid] = e
	if e is Soldier:
		soldiers.append(e)
	elif e is Vehicle:
		vehicles.append(e)
	elif e is Structure:
		structures.append(e)
	elif e is Projectile:
		projectiles.append(e)
	elif e is Drone:
		drones.append(e)


func despawn(e: Entity) -> void:
	if e == null or e.gone:
		return
	e.gone = true
	entities.erase(e.eid)
	if e is Soldier:
		soldiers.erase(e)
		# out of his squad now: nothing may touch him once he's freed
		if e.squad and is_instance_valid(e.squad):
			e.squad.members.erase(e)
	elif e is Vehicle:
		vehicles.erase(e)
	elif e is Structure:
		structures.erase(e)
		_shash_remove(e)
		if terrain:
			terrain.structure_changed(e, false)
	elif e is Projectile:
		projectiles.erase(e)
	elif e is Drone:
		drones.erase(e)
	e.on_despawn()
	if srv and not ready_peers.is_empty():
		_pend_despawn.append(e.eid)
	# Keep the object alive for a while so stale references elsewhere can
	# still read `gone` instead of touching a freed instance.
	e.visible = false
	e.set_process(false)
	_graveyard.append([e, time + 240.0])
	remove_child.call_deferred(e)


var _graveyard: Array = []
var _grave_t := 0.0


func _sweep_graveyard() -> void:
	while not _graveyard.is_empty() and _graveyard[0][1] < time:
		var e = _graveyard.pop_front()[0]
		if is_instance_valid(e):
			if e.is_inside_tree():
				e.queue_free()
			else:
				e.free()


func _exit_tree() -> void:
	for it in _graveyard:
		if is_instance_valid(it[0]) and not it[0].is_inside_tree():
			it[0].free()
	_graveyard.clear()


func entity(id: int) -> Entity:
	return entities.get(id)


## Ground height at p: the duckboards, a metre down, inside a finished trench.
func ground_y(p: Vector3) -> float:
	if water and not water.deck.is_empty() and water.on_deck(p):
		return 0.06  # on a bridge deck, over the water
	for st in structures_near(p, 4.0):
		if st.skind == "trench" and st.built and TrenchNet.inside(st, p, 0.05):
			return TrenchNet.FLOOR_Y + 0.15
	return terrain.deform_at(p) if terrain else 0.0


## A machine gun placed on a trench goes into the trench as a gun bay: the spot
## on the trench line nearest `pos` (not right at its ends) and the heading
## square to the trench closest to the one asked for. {} if no trench is close.
func trench_mount_spot(pos: Vector3, yaw: float) -> Dictionary:
	var best := {}
	var bd := 1.7
	for st in structures_near(pos, 8.0):
		if st.skind != "trench" or st.gone:
			continue
		var sg := TrenchNet.seg_of(st)
		var a: Vector3 = Defs.flat(sg[0])
		var b: Vector3 = Defs.flat(sg[1])
		var ab := b - a
		var L := ab.length()
		if L < 2.0:
			continue
		var t := clampf((Defs.flat(pos) - a).dot(ab) / (L * L), 1.2 / L, 1.0 - 1.2 / L)
		var q := a + ab * t
		var d := Defs.flat(pos - q).length()
		if d < bd:
			bd = d
			var n := Vector3(-ab.z, 0, ab.x).normalized()
			if n.dot(Defs.dir_of(yaw)) < 0.0:
				n = -n
			best = {"pos": q, "yaw": Defs.yaw_of(n)}
	return best


func in_trench(p: Vector3) -> bool:
	for st in structures_near(p, 4.0):
		if st.skind == "trench" and st.built and TrenchNet.inside(st, p, 0.05):
			return true
	return false


## True when a shooter at `from` is looking along the trench bay that `p` is in
## (enfilade): the zig-zag keeps that to one short bay at a time.
func trench_enfiladed(p: Vector3, from: Vector3) -> bool:
	var to := Defs.flat(p - from)
	if to.length() < 1.0:
		return true
	to = to.normalized()
	for st in structures_near(p, 4.0):
		if st.skind == "trench" and st.built and TrenchNet.inside(st, p):
			var sg := TrenchNet.seg_of(st)
			var ax := Defs.flat(sg[1] - sg[0]).normalized()
			return absf(ax.dot(to)) > 0.95
	return false


## Shared by the client's placement ghost and the server's validation.
func placement_error(team: int, kind: String, pos: Vector3, yaw: float) -> String:
	if not Defs.BUILDINGS.has(kind):
		return "Unknown building."
	var def: Dictionary = Defs.BUILDINGS[kind]
	if not team in def.teams:
		return "Your side can't build that."
	if not Defs.in_map(pos, 8.0):
		return "Too close to the map edge."
	var half: Vector2 = def.size * 0.5
	if kind == "trench":
		half.x += TrenchNet.HALF_W
	var c := Vector2(pos.x, pos.z)
	if not water.is_empty():
		var b := Basis(Vector3.UP, yaw)
		for o in [Vector3.ZERO, Vector3(half.x, 0, half.y), Vector3(-half.x, 0, half.y), Vector3(half.x, 0, -half.y), Vector3(-half.x, 0, -half.y)]:
			var q: Vector3 = pos + b * o
			if water.wet_at(q) or water.on_deck(q):
				return "Can't build in the water." if kind != "dock" else "A dock stands on the shore, its jetty out over the water."
		if kind == "dock":
			# its jetty runs out over open water in front of it
			var f := Defs.dir_of(yaw)
			var wet_near := false
			var deep := false
			for k in range(int(half.y) + 1, int(half.y) + 28, 3):
				var q: Vector3 = pos + f * float(k)
				if float(k) <= half.y + 12.0 and water.wet_at(q):
					wet_near = true
				if water.deep_at(q):
					deep = true
					break
			if not (wet_near and deep):
				return "A dock must face open water: put it on the shore with its front to the sea or the river."
			if (team == 0 and pos.z < -40.0) or (team == 1 and pos.z > 40.0):
				return "Build docks on your own half of the map."
	elif kind == "dock":
		return "There's no water on this map."
	for st in structures_near(pos, 16.0):
		if st.skind == "floor" or (kind == "trench" and st.skind == "trench") or (st.skind == "trench" and kind in ["mg_nest", "hmg_nest"]):
			continue
		if Defs.obb_overlap(c, half - Vector2(0.12, 0.12), yaw, Vector2(st.position.x, st.position.z), st.foot - Vector2(0.12, 0.12), st.yaw):
			return "Blocked by %s." % st.display_name()
	if not kind in ["mines", "wire", "trench", "sandbags", "fob"] and team >= 0 and team <= 1:
		var fp := Vector3(pos.x, 0, pos.z)
		for poly in roads[team]:
			var pts: PackedVector3Array = poly
			for i in range(pts.size() - 1):
				if Defs.dist_point_segment(fp, Defs.flat(pts[i]), Defs.flat(pts[i + 1])) < half.length() + 3.0:
					return "That would block your own supply road."
	if kind == "dock":
		pass  # (see above: the shore, our half)
	elif kind == "fob":
		var near_own := false
		for st in structures:
			if st.skind != "fob" and st.skind != "depot":
				continue
			var d := Defs.flat(st.position - pos).length()
			if st.skind == "fob" and d < Defs.FOB_MIN_SPACING:
				return "Too close to another FOB."
			if st.team == team and st.built and d < Defs.FOB_EXPAND_RADIUS:
				near_own = true
		if not near_own:
			return "A new FOB must be within %d m of one of yours." % int(Defs.FOB_EXPAND_RADIUS)
	else:
		var ok := false
		for st in structures:
			if st.skind == "fob" and st.team == team and st.built and not st.wrecked and Defs.flat(st.position - pos).length() < Defs.BUILD_RADIUS:
				ok = true
				break
		if not ok:
			return "Must be within %d m of a working FOB." % int(Defs.BUILD_RADIUS)
	return ""


func push_props(e: Entity, d: Dictionary) -> void:
	if not srv or ready_peers.is_empty():
		return
	var cur: Dictionary = _pend_props.get(e.eid, {})
	cur.merge(d, true)
	_pend_props[e.eid] = cur


func fx_event(ev: Array) -> void:
	if has_view:
		fx.play(ev)
	if srv and not ready_peers.is_empty():
		_pend_fx.append(ev)


func say(e: Entity, text: String) -> void:
	fx_event([Fx.SAY, e.eid, text])


# --- server tick ------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if terrain:
		terrain.tick(2500)
	_grave_t -= dt
	if _grave_t <= 0.0:
		_grave_t = 5.0
		_sweep_graveyard()
	if not srv:
		time += dt
		_net_in_t += dt
		if _net_in_t >= 1.0:
			net_in_bps = _net_in / _net_in_t
			_net_in = 0.0
			_net_in_t = 0.0
		return
	time += dt
	var t0 := Time.get_ticks_usec()
	var tp := t0
	_flush()
	tp = _p("network", tp)
	nav.update_hier()
	tp = _p("pathing", tp)
	_rebuild_uhash()
	tp = _p("spatial hash", tp)
	for e in soldiers.duplicate():
		if not e.gone:
			e.sim(dt)
			if has_view:
				e.ip_capture()
	tp = _p("soldiers", tp)
	for e in structures.duplicate():
		if not e.gone:
			e.sim(dt)
	fires.tick(dt)
	tp = _p("structures", tp)
	for arr in [vehicles.duplicate(), projectiles.duplicate(), drones.duplicate()]:
		for e in arr:
			if not e.gone:
				e.sim(dt)
				if has_view and e is Vehicle:
					e.ip_capture()
	tp = _p("vehicles+projectiles", tp)
	for sq in squads.values():
		sq.tick(dt)
	tp = _p("squads", tp)
	rules.tick(dt)
	tp = _p("rules + fog", tp)
	for c in commanders:
		c.tick(dt)
	if mission:
		mission.tick(dt)
	tp = _p("AI commanders", tp)
	_snap_t -= dt
	if _snap_t <= 0.0:
		_snap_t = 1.0 / 15.0
		_send_snapshots()
	tp = _p("snapshots", tp)
	_team_t -= dt
	if _team_t <= 0.0:
		_team_t = 0.5
		team_info = rules.team_summary()
		for p in ready_peers:
			var view := view_of(p)
			if view < 0:
				rpc_id(p, "_rpc_team", team_info)
			else:
				var mine := [{}, {}]
				mine[view] = team_info[view]
				rpc_id(p, "_rpc_team", mine)
	_reveal_t -= dt
	if _reveal_t <= 0.0:
		_reveal_t = 0.4
		_reveal_pass()
	tick_ms = lerpf(tick_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)
	prof["TOTAL"] = tick_ms
	sim_usec += Time.get_ticks_usec() - t0
	net_out_bps = lerpf(net_out_bps, _net_out / maxf(dt, 0.001), 0.05)
	_net_out = 0.0


## Profiling helper: accumulates a smoothed per-tick cost for a named system.
## Client-side (view) profiling: microseconds per system, summed each frame.
var vprof := {}
var sim_usec := 0  # simulation time accumulated since the overlay last read it
var vprof_avg := {}
var _vprof_frames := 0
var _vprof_t := 0.0


func vp(key: String, since: int) -> void:
	vprof[key] = int(vprof.get(key, 0)) + Time.get_ticks_usec() - since


func _p(key: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	prof[key] = lerpf(float(prof.get(key, 0.0)), (now - since) / 1000.0, 0.05)
	return now


func _flush() -> void:
	if ready_peers.is_empty():
		_pend_spawn.clear()
		_pend_despawn.clear()
		_pend_props.clear()
		_pend_fx.clear()
		return
	if not _pend_spawn.is_empty():
		for p in ready_peers:
			var view := view_of(p)
			var kn: Dictionary = known.get(p, {})
			var arr := []
			for it in _pend_spawn:
				var e: Entity = entities.get(it[0])
				if e and not kn.has(e.eid) and can_know(e, view):
					arr.append([e.eid, it[1], e.get_props()])
					kn[e.eid] = true
			if not arr.is_empty():
				rpc_id(p, "_rpc_spawn", arr)
		_pend_spawn.clear()
	if not _pend_despawn.is_empty():
		for p in ready_peers:
			var kn: Dictionary = known.get(p, {})
			var ids := []
			for id in _pend_despawn:
				if kn.has(id):
					ids.append(id)
					kn.erase(id)
			if not ids.is_empty():
				rpc_id(p, "_rpc_despawn", ids)
		_pend_despawn.clear()
	if not _pend_props.is_empty():
		for p in ready_peers:
			var view := view_of(p)
			var kn: Dictionary = known.get(p, {})
			var d := {}
			for id in _pend_props:
				if not kn.has(id):
					continue
				var props: Dictionary = _pend_props[id]
				var e: Entity = entities.get(id)
				if e and view >= 0 and e.team >= 0 and e.team != view and props.has("queue"):
					props = props.duplicate()
					props.erase("queue")
					if props.is_empty():
						continue
				d[id] = props
			if not d.is_empty():
				rpc_id(p, "_rpc_props", d)
		_pend_props.clear()
	if not _pend_fx.is_empty():
		_to_ready("_rpc_fx", _pend_fx.duplicate())
		_pend_fx.clear()


func _to_ready(method: StringName, arg) -> void:
	for p in ready_peers:
		rpc_id(p, method, arg)


## Spectators see everything; players only learn about enemy units and
## buildings their side has actually spotted.
func view_of(p: int) -> int:
	return team_of_peer(p)


func can_know(e: Entity, view: int) -> bool:
	if view < 0 or e.team < 0 or e.team == view:
		return true
	if e is Projectile:
		return true
	if e is Structure:
		return ((e.seen_mask >> view) & 1) == 1
	return ((e.vis_mask >> view) & 1) == 1


func _reveal_pass() -> void:
	for p in ready_peers:
		var view := view_of(p)
		if view < 0:
			continue
		var kn: Dictionary = known.get(p, {})
		var arr := []
		for e in entities.values():
			if e.gone or kn.has(e.eid) or not can_know(e, view):
				continue
			arr.append([e.eid, e.ekind(), e.get_props()])
			kn[e.eid] = true
			if arr.size() >= 80:
				rpc_id(p, "_rpc_spawn", arr)
				arr = []
		if not arr.is_empty():
			rpc_id(p, "_rpc_spawn", arr)


func _send_snapshots() -> void:
	if ready_peers.is_empty():
		return
	var list := []
	for e in entities.values():
		if e.gone:
			continue
		if e.is_static():
			if not e.net_dirty and time < e.resend_t:
				continue
			e.net_dirty = false
			e.resend_t = time + 2.5 + randf() * 1.5
		list.append(e)
	var by_view := {}
	for p in ready_peers:
		var v := view_of(p)
		if not by_view.has(v):
			by_view[v] = _build_snapshot(list, v)
		for pk in by_view[v]:
			rpc_id(p, "_rpc_snap", pk)
			_net_out += pk.size()


## The team whose snapshot is being written (-1 = full view). Entities use it
## to hide private details such as an enemy FOB's supply.
var writing_view := -1


func _build_snapshot(list: Array, view: int) -> Array:
	writing_view = view
	var packets := []
	var b := StreamPeerBuffer.new()
	b.put_float(time)
	for e in list:
		var hidden: bool = view >= 0 and e.team >= 0 and e.team != view and not can_know(e, view)
		if hidden and e is Structure:
			continue
		b.put_u32(e.eid)
		if hidden:
			b.put_u8(0)  # zero-length record: this unit is no longer visible to you
		else:
			var lp := b.get_position()
			b.put_u8(0)
			e.write_state(b)
			var end := b.get_position()
			b.seek(lp)
			b.put_u8(end - lp - 1)
			b.seek(end)
		if b.get_position() > 1100:
			packets.append(b.data_array)
			b = StreamPeerBuffer.new()
			b.put_float(time)
	if b.get_position() > 4:
		packets.append(b.data_array)
	writing_view = -1
	return packets


# --- client RPCs ---------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _client_ready() -> void:
	if not srv:
		return
	var p := multiplayer.get_remote_sender_id()
	if p in ready_peers:
		return
	var view := view_of(p)
	var kn := {}
	known[p] = kn
	var arr := []
	for e in entities.values():
		if not can_know(e, view):
			continue
		arr.append([e.eid, e.ekind(), e.get_props()])
		kn[e.eid] = true
		if arr.size() >= 80:
			rpc_id(p, "_rpc_spawn", arr)
			arr = []
	if not arr.is_empty():
		rpc_id(p, "_rpc_spawn", arr)
	rpc_id(p, "_rpc_water", water.to_dict())
	rpc_id(p, "_rpc_roads", roads)
	rpc_id(p, "_rpc_decor", decor, town_rect)
	if not mission_info.is_empty():
		rpc_id(p, "_rpc_mission", mission_info)
	ready_peers.append(p)
	for e in entities.values():
		e.net_dirty = true


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn(arr: Array) -> void:
	for it in arr:
		var id: int = it[0]
		if entities.has(id):
			continue
		var e := _make(it[1])
		e.world = self
		e.eid = id
		e.srv = false
		e.apply_props(it[2])
		e.name = "E%d" % id
		_register(e)
		add_child(e)
		e.on_spawned()
		if e is Structure:
			_shash_add(e)
			terrain.structure_changed(e, true)
	if not focused:
		_try_focus()


@rpc("authority", "call_remote", "reliable")
func _rpc_despawn(ids: Array) -> void:
	for id in ids:
		var e: Entity = entities.get(id)
		if e:
			despawn(e)


@rpc("authority", "call_remote", "reliable")
func _rpc_props(d: Dictionary) -> void:
	for id in d:
		var e: Entity = entities.get(id)
		if e:
			e.apply_props(d[id])


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_snap(data: PackedByteArray) -> void:
	var n := data.size()
	_net_in += n
	if n < 4:
		return
	var b := StreamPeerBuffer.new()
	b.data_array = data
	b.get_float()
	while b.get_position() + 5 <= n:
		var id := b.get_u32()
		var ln := b.get_u8()
		var st := b.get_position()
		var e: Entity = entities.get(id)
		if e:
			if ln > 0:
				e.read_state(b)
			elif local_team >= 0:
				e.vis_mask &= ~(1 << local_team)
		b.seek(st + ln)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_fx(evs: Array) -> void:
	if not has_view:
		return
	for ev in evs:
		fx.play(ev)


@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _rpc_team(d: Array) -> void:
	team_info = d


@rpc("authority", "call_remote", "reliable")
func _rpc_msg(m: Array) -> void:
	_show_msg(m)


## The mission's state (objectives, clocks, the end), from the server.
func set_mission_info(d: Dictionary) -> void:
	mission_info = d
	mission_rx_t = time
	for p in ready_peers:
		rpc_id(p, "_rpc_mission", d)


@rpc("authority", "call_remote", "reliable")
func _rpc_mission(d: Dictionary) -> void:
	if OS.has_environment("FL_DEBUG_MISSION") and (d.get("objs", []) as Array).size() != (mission_info.get("objs", []) as Array).size():
		print("CLIENT mission %s: %d objectives, over=%d" % [String(d.get("key", "")), (d.get("objs", []) as Array).size(), int(d.get("over", 0))])
	mission_info = d
	mission_rx_t = time
	_try_focus()


@rpc("authority", "call_remote", "reliable")
func _rpc_water(d: Dictionary) -> void:
	water.from_dict(d)
	water.paint_kinds()
	water.carve()
	_water_view()


## (view) The water's surface, and everything that draws differently by it.
func _water_view() -> void:
	if not has_view or water.is_empty() or atmo == null:
		return
	atmo.build_water(water)
	if hud and hud.has_method("refresh_minimap"):
		hud.refresh_minimap()


@rpc("authority", "call_remote", "reliable")
func _rpc_roads(r: Array) -> void:
	roads = r
	_rebuild_roads()


@rpc("authority", "call_remote", "reliable")
func _rpc_decor(d: Array, r: Rect2) -> void:
	set_decor(d, r)


func set_decor(d: Array, r: Rect2) -> void:
	decor = d
	town_rect = r
	if not has_view or OS.has_environment("FL_NO_DECOR"):
		return
	if _decor_node:
		_decor_node.queue_free()
	_decor_node = Decor.new()
	add_child(_decor_node)
	_decor_node.build(self, decor)
	if atmo:
		atmo.set_town(town_rect)
		if atmo.grass:
			atmo.grass.request_rebuild(1.0)


@rpc("authority", "call_remote", "reliable")
func _rpc_over(w: int) -> void:
	winner = w
	game_ended.emit(w)
	if hud:
		hud.show_game_over(w)


# --- messages / roads / end of game ------------------------------------------------

## team = -1 sends to everyone. ping: Vector3 or null (shows a marker for 30 s).
func send_msg(team: int, kind: String, text: String, ping = null) -> void:
	var m := [team, kind, text, ping]
	_show_msg(m)
	for p in ready_peers:
		var pt := team_of_peer(p)
		if team < 0 or pt < 0 or pt == team:
			rpc_id(p, "_rpc_msg", m)


func send_msg_to(peer: int, kind: String, text: String) -> void:
	var m := [-1, kind, text, null]
	if peer == local_peer:
		_show_msg(m)
	elif peer in ready_peers:
		rpc_id(peer, "_rpc_msg", m)


func _show_msg(m: Array) -> void:
	var t: int = m[0]
	if t >= 0 and local_team >= 0 and t != local_team:
		return
	if not has_view:
		if settings.get("verbose", false):
			print("[%s] %s" % [m[1], m[2]])
		return
	if hud:
		hud.add_message(m[1], m[2])
	if m[3] != null:
		pings.append([m[3], time + 30.0, m[1]])


func set_roads(team: int, polys: Array) -> void:
	roads[team] = polys
	_rebuild_roads()
	for p in ready_peers:
		rpc_id(p, "_rpc_roads", roads)


func _rebuild_roads() -> void:
	# the ground under any road is road (fast, exposed)
	var sig := 0
	for t in 3:
		sig = sig * 31 + (roads[t] as Array).size()
		for poly in roads[t]:
			sig = sig * 7 + (poly as PackedVector3Array).size()
	if sig != _painted_roads and terrain:
		_painted_roads = sig
		for t in 3:
			terrain.paint_roads(roads[t], 2.4 if t == 2 else 1.8)
	if not has_view or atmo == null:
		return
	for t in 3:
		if _road_meshes[t]:
			_road_meshes[t].queue_free()
			_road_meshes[t] = null
		if (roads[t] as Array).is_empty():
			continue
		var mi := atmo.make_road_mesh(roads[t], t)
		add_child(mi)
		_road_meshes[t] = mi
		if OS.has_environment("FL_DEBUG_ROADS"):
			print("ROADS t=%d polys=%d aabb=%s" % [t, (roads[t] as Array).size(), str(mi.get_aabb())])
	if atmo.grass:
		atmo.grass.request_rebuild(1.0)


func declare_winner(t: int) -> void:
	if winner >= 0:
		return
	winner = t
	if mission:
		send_msg(-1, "system", ("Mission accomplished. " if mission.over == 1 else "Mission failed. ") + mission.end_text)
	else:
		send_msg(-1, "system", "%s win the battle!" % Defs.TEAM_NAMES[t])
	game_ended.emit(t)
	if hud:
		hud.show_game_over(t)
	for p in ready_peers:
		rpc_id(p, "_rpc_over", t)


# --- spatial queries ------------------------------------------------------------------

func _rebuild_uhash() -> void:
	_uhash.clear()
	for s in soldiers:
		if s.life == Soldier.Life.HIDDEN:
			continue
		_hadd(s)
	for v in vehicles:
		_hadd(v)


func _hadd(e: Entity) -> void:
	var k := Vector2i(floori(e.position.x / HCELL), floori(e.position.z / HCELL))
	var a = _uhash.get(k)
	if a == null:
		a = []
		_uhash[k] = a
	a.append(e)


## Soldiers (not hidden) and vehicles within r of p. Server only.
func units_near(p: Vector3, r: float) -> Array:
	var out := []
	var x0 := floori((p.x - r) / HCELL)
	var x1 := floori((p.x + r) / HCELL)
	var z0 := floori((p.z - r) / HCELL)
	var z1 := floori((p.z + r) / HCELL)
	var r2 := r * r
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var a = _uhash.get(Vector2i(x, z))
			if a == null:
				continue
			for e in a:
				if not e.gone and Defs.flat(e.position - p).length_squared() <= r2:
					out.append(e)
	return out


func soldiers_near(p: Vector3, r: float) -> Array:
	var out := []
	for e in units_near(p, r):
		if e is Soldier:
			out.append(e)
	return out


# shut doors (server): 1.5 m cells round each doorway -> the doors there
var door_cells := {}


func _door_keys(st: Structure) -> Array:
	var out := []
	var cx := floori(st.position.x / 1.5)
	var cz := floori(st.position.z / 1.5)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			out.append(Vector2i(cx + dx, cz + dz))
	return out


func add_door(st: Structure) -> void:
	for k in _door_keys(st):
		if not door_cells.has(k):
			door_cells[k] = []
		door_cells[k].append(st)


func remove_door(st: Structure) -> void:
	for k in _door_keys(st):
		var l: Array = door_cells.get(k, [])
		l.erase(st)
		if l.is_empty():
			door_cells.erase(k)


## The shut door a man at p heading dir is about to walk into, or null.
func door_in_way(p: Vector3, dir: Vector3) -> Structure:
	var l = door_cells.get(Vector2i(floori(p.x / 1.5), floori(p.z / 1.5)))
	if l == null:
		return null
	for st in l:
		if not st.gone and st.door_blocks(p, dir):
			return st
	return null


func vehicles_near(p: Vector3, r: float) -> Array:
	var out := []
	for v in vehicles:
		if Defs.flat(v.position - p).length() <= r:
			out.append(v)
	return out


func _shash_cells(e: Structure) -> Array:
	var r: float = e.radius
	var out := []
	for x in range(floori((e.position.x - r) / SCELL), floori((e.position.x + r) / SCELL) + 1):
		for z in range(floori((e.position.z - r) / SCELL), floori((e.position.z + r) / SCELL) + 1):
			out.append(Vector2i(x, z))
	return out


func _shash_add(e: Structure) -> void:
	e.hash_cells = _shash_cells(e)
	for k in e.hash_cells:
		var a = _shash.get(k)
		if a == null:
			a = []
			_shash[k] = a
		a.append(e)


func _shash_remove(e: Structure) -> void:
	for k in e.hash_cells:
		var a = _shash.get(k)
		if a:
			a.erase(e)
	e.hash_cells = []


func structures_near(p: Vector3, r: float) -> Array:
	var out := []
	var seen := {}
	for x in range(floori((p.x - r) / SCELL), floori((p.x + r) / SCELL) + 1):
		for z in range(floori((p.z - r) / SCELL), floori((p.z + r) / SCELL) + 1):
			var a = _shash.get(Vector2i(x, z))
			if a == null:
				continue
			for st in a:
				if not is_instance_valid(st) or st.gone or seen.has(st.eid):
					continue
				seen[st.eid] = true
				if Defs.flat(st.position - p).length() <= r + st.radius:
					out.append(st)
	return out


# --- squads -----------------------------------------------------------------------------

func new_squad(team: int, owner: int, kind: String) -> Squad:
	var sq := Squad.new()
	sq.world = self
	sq.sid = next_sid
	next_sid += 1
	sq.team = team
	sq.owner = owner
	sq.kind = kind
	squads[sq.sid] = sq
	return sq


func remove_squad(sq: Squad) -> void:
	squads.erase(sq.sid)


var recent_impacts: Array = []  # [pos, time] of shells and bombs, the last 40 s


## How many shells or bombs have landed within r of p in the last `secs`.
func impacts_near(p: Vector3, r: float, secs: float) -> int:
	var n := 0
	for im in recent_impacts:
		if time - float(im[1]) < secs and Defs.flat(im[0] - p).length() < r:
			n += 1
	return n


## A shell or bomb landing: squads near it note it (they get out of the
## impact area rather than sit in it - see SquadBrain).
func note_heavy_impact(p: Vector3) -> void:
	recent_impacts.append([p, time])
	while not recent_impacts.is_empty() and time - float(recent_impacts[0][1]) > 40.0:
		recent_impacts.pop_front()
	for sq in squads.values():
		if not sq.members.is_empty() and Defs.flat(sq.centroid() - p).length() < 45.0:
			sq.impacts.append([p, time])


# --- commands ------------------------------------------------------------------------------

func team_of_peer(peer: int) -> int:
	if peer < 0:
		return -1 - peer
	var pl = Net.players.get(peer)
	return int(pl.team) if pl else -1


func send_cmd(d: Dictionary) -> void:
	if srv:
		execute_cmd(local_peer, d)
	else:
		_rpc_cmd.rpc_id(1, d)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_cmd(d: Dictionary) -> void:
	if not srv:
		return
	execute_cmd(multiplayer.get_remote_sender_id(), d)


func _own_squads(peer: int, ids: Array) -> Array:
	var out := []
	for id in ids:
		var sq: Squad = squads.get(int(id))
		if sq and sq.owner == peer:
			out.append(sq)
	return out


func _own_vehicles(peer: int, ids: Array) -> Array:
	var out := []
	for id in ids:
		var v = entities.get(int(id))
		if v is Vehicle and v.owner_peer == peer:
			out.append(v)
	return out


func execute_cmd(peer: int, d: Dictionary) -> void:
	if String(d.get("t", "")) == "demo_support":
		if _demo_ok(peer):
			rules.demo_support(String(d.get("kind", "")), d.pos, d.get("dir", Vector3.ZERO))
		return
	var team := team_of_peer(peer)
	if team < 0 or winner >= 0:
		return
	var t: String = d.get("t", "")
	var sqs := _own_squads(peer, d.get("squads", []))
	var vehs := _own_vehicles(peer, d.get("vehicles", []))
	# a routed squad runs whatever it's told, until it has rallied
	for sq in sqs.duplicate():
		if sq.drill == "rout" and t != "retreat" and t != "unit":
			sqs.erase(sq)
			if peer > 0:
				send_msg_to(peer, "alert", "%s is routing - it won't take orders until it rallies." % sq.display_name())
	if not t in ["unit", "dismount"]:
		for sq in sqs:
			sq.order_n += 1
	match t:
		"move":
			var pos: Vector3 = d.pos
			var face: Vector3 = d.get("face", Vector3.ZERO)
			var mode: int = int(d.get("mode", 0))
			if face.length() < 0.1:
				var c := _centroid(sqs, vehs)
				face = Defs.flat(pos - c).normalized() if c.distance_to(pos) > 1.0 else Vector3.FORWARD
			var side := face.cross(Vector3.UP).normalized()
			var n := sqs.size()
			for i in n:
				sqs[i].order_move(pos + side * (i - (n - 1) / 2.0) * 13.0, face, mode)
			var m := vehs.size()
			for i in m:
				vehs[i].order_move(pos + side * (i - (m - 1) / 2.0) * 9.0 - face * (6.0 if n > 0 else 0.0))
		"assault", "defend":
			var apos: Vector3 = d.pos
			var aface: Vector3 = d.get("face", Vector3.ZERO)
			if aface.length() < 0.1:
				var ac := _centroid(sqs, vehs)
				aface = Defs.flat(apos - ac).normalized() if ac.distance_to(apos) > 1.0 else Vector3.FORWARD
			var aside := aface.cross(Vector3.UP).normalized()
			var an := sqs.size()
			for i in an:
				var sp: Vector3 = apos + aside * (i - (an - 1) / 2.0) * 13.0
				if t == "assault":
					sqs[i].order_assault(sp, aface, an == 1)
				else:
					sqs[i].order_defend(sp, aface)
			# several squads attacking together: one fixes the enemy, the rest flank
			if t == "assault" and an >= 2:
				AttackPlan.make(self, sqs, apos, aface)
			var am := vehs.size()
			for i in am:
				var vp: Vector3 = apos + aside * (i - (am - 1) / 2.0) * 9.0 - aface * (6.0 if an > 0 else 0.0)
				if t == "assault":
					vehs[i].order_assault(vp)
				else:
					vehs[i].order_move(vp)
		"dismount":
			for v in vehs:
				v.dismount()
		"unit":
			var us = entities.get(int(d.get("soldier", 0)))
			if us is Soldier and us.owner_peer == peer and us.team == team:
				us.unit_order(d)
		"attack":
			var tgt: Entity = entities.get(int(d.get("target", 0)))
			if tgt and tgt.is_hostile_to(team):
				for sq in sqs:
					sq.order_attack(tgt)
				for v in vehs:
					v.order_attack(tgt)
		"stop":
			for sq in sqs:
				sq.order_stop()
			for v in vehs:
				v.order_stop()
		"retreat":
			for sq in sqs:
				sq.order_retreat()
			for v in vehs:
				var f := rules.nearest_fob(team, v.position)
				if f:
					v.order_move(f.position + Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)))
		"build":
			if rules.try_place(peer, team, String(d.kind), d.pos, float(d.get("yaw", 0.0)), sqs) != null:
				coop.deed(peer, "Placed %s" % String(Defs.BUILDINGS[String(d.kind)].name), d.pos)
		"build_many":
			var first := true
			var laid := 0
			var at := Vector3.ZERO
			for it in d.get("items", []):
				var sz := Vector3.ZERO
				if it.size() > 2 and Defs.BUILDINGS.has(String(d.kind)):
					sz = Vector3(clampf(float(it[2]), 1.5, 8.0), 3.0, (Defs.BUILDINGS[String(d.kind)].size as Vector2).y)
				if rules.try_place(peer, team, String(d.kind), it[0], float(it[1]), sqs, first, sz) != null:
					first = false
					laid += 1
					at = it[0]
			if laid > 0:
				coop.deed(peer, "Laid %d × %s" % [laid, String(Defs.BUILDINGS[String(d.kind)].name)], at)
		"fire_mission":
			var kind := String(d.get("kind", "he"))
			var pit = entities.get(int(d.get("building", 0)))
			if pit is Structure and pit.team == team:
				pit.queue_fire(d.pos, kind, peer)
			for vid in d.get("vehicles", []):
				var av = entities.get(int(vid))
				if av is Vehicle and av.team == team and av.vdef.has("art") and av.fire_queue.size() < 3:
					var ad: Dictionary = av.vdef.art
					var dist: float = Defs.flat((d.pos as Vector3) - av.position).length()
					if dist < float(ad.get("min", 40.0)) or dist > float(ad.get("max", 240.0)):
						send_msg(team, "info", "%s: out of range (%d-%d m)." % [av.display_name(), int(ad.get("min", 40.0)), int(ad.get("max", 240.0))], av.position)
						continue
					av.fire_queue.append(d.pos)
					av.arty_t = minf(av.arty_t, time)
			for sq in sqs:
				sq.order_fire_mission(d.pos, kind)
		"work":
			var tgt: Entity = entities.get(int(d.get("target", 0)))
			if tgt and tgt.team == team:
				for sq in sqs:
					sq.order_work(tgt)
		"enter":
			var st = entities.get(int(d.get("target", 0)))
			if st is Structure and st.team == team:
				for sq in sqs:
					sq.order_enter(st)
		"sling":
			var sv = entities.get(int(d.get("target", 0)))
			if sv is Vehicle and sv.team == team:
				for v in vehs:
					if v.can_sling(sv):
						v.order_sling(sv)
						break
		"board":
			var bv = entities.get(int(d.get("target", 0)))
			if bv is Vehicle and bv.team == team:
				for sq in sqs:
					sq.order_board(bv)
		"throw":
			for sq in sqs:
				sq.order_throw(d.pos, String(d.get("kind", "frag")))
		"support":
			if rules.call_support(peer, team, String(d.get("kind", "")), d.pos, d.get("dir", Vector3.ZERO)):
				coop.deed(peer, "Called in %s" % String(Defs.SUPPORT[String(d.kind)].name), d.pos, true)
		"train", "research", "cancel", "rally", "tunnel_exit":
			var st = entities.get(int(d.get("building", 0)))
			if not (st is Structure) or st.team != team:
				return
			var queued: int = st.queue.size()
			match t:
				"train":
					st.queue_item(peer, String(d.item))
					if st.queue.size() > queued:
						coop.deed(peer, "Training %s at %s" % [Defs.item_name(String(d.item)), st.display_name()], st.position)
				"research":
					st.queue_research(peer, String(d.item))
					if st.queue.size() > queued:
						coop.deed(peer, "Researching %s" % Defs.item_name(String(d.item)), st.position, true)
				"cancel":
					st.cancel_last(peer)
				"rally":
					st.rally = d.pos
				"tunnel_exit":
					var ex = entities.get(int(d.get("exit", 0)))
					if ex is Structure:
						rules.tunnel_exit(st, ex, peer)
		"chat":
			var txt := String(d.get("text", "")).strip_edges().substr(0, 200)
			if txt == "":
				return
			var pname := "AI"
			if Net.players.has(peer):
				pname = String(Net.players[peer].name)
			if bool(d.get("team_only", false)):
				send_msg(team, "chat", "[TEAM] %s: %s" % [pname, txt])
			else:
				send_msg(-1, "chat", "%s: %s" % [pname, txt])


## Observer demo strikes: the host's own observer, or anyone watching an
## AI-only battle (never someone spectating a real match).
func _demo_ok(peer: int) -> bool:
	if team_of_peer(peer) >= 0:
		return false
	if peer == 1 or peer == multiplayer.get_unique_id() and srv:
		return true
	for id in Net.players:
		if int(Net.players[id].team) >= 0:
			return false
	return true


func _centroid(sqs: Array, vehs: Array) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for sq in sqs:
		c += sq.centroid()
		n += 1
	for v in vehs:
		c += v.position
		n += 1
	return c / maxf(1, n)


func _on_player_joined(id: int, team: int, pname: String) -> void:
	if mission:
		if team == mission.side:
			mission.player_joined(id)
		send_msg(-1, "system", "%s joined the mission." % pname)
		return
	var f: Structure = null
	for st in rules.fobs(team, false):
		if f == null or st.completed_order < f.completed_order:
			f = st
	if f:
		var fwd := Vector3.FORWARD if team == 0 else Vector3.BACK
		var side := Vector3.RIGHT * world_rng_side()
		rules.spawn_squad("rifle_squad" if team == 0 else "fighter_cell", team, id, f.position + fwd * 11.0 + side, f.position + fwd * 18.0 + side)
		rules.spawn_squad("engineer_team" if team == 0 else "digger_team", team, id, f.position - fwd * 10.0 + side)
	send_msg(-1, "system", "%s joined the battle on the %s side." % [pname, Defs.TEAM_NAMES[team]])


func world_rng_side() -> float:
	return rng.randf_range(-12.0, 12.0)


func _on_player_left(id: int, team: int, pname: String) -> void:
	ready_peers.erase(id)
	known.erase(id)
	if team < 0:
		send_msg(-1, "system", "%s left the game." % pname)
		return
	var heir := 0
	for pid in Net.players:
		if int(Net.players[pid].team) == team:
			heir = int(pid)
	var new_owner := heir if heir != 0 else -1 - team
	for sq in squads.values():
		if sq.owner == id:
			sq.owner = new_owner
			for m in sq.members:
				m.owner_peer = new_owner
				push_props(m, {"owner": new_owner})
	for v in vehicles:
		if v.owner_peer == id:
			v.owner_peer = new_owner
			push_props(v, {"owner": new_owner})
	if mission:
		mission.owner_changed(id, new_owner)
		send_msg(-1, "system", "%s left the mission." % pname)
		return
	if heir == 0:
		var has_ai := false
		for c in commanders:
			if c.team == team:
				has_ai = true
		if not has_ai:
			commanders.append(CommanderAI.new(self, team))
		send_msg(-1, "system", "%s left. The AI takes over their forces." % pname)
	else:
		send_msg(-1, "system", "%s left. %s takes command of their forces." % [pname, String(Net.players[heir].name)])


# --- debugging -----------------------------------------------------------------------------

var stats := {}


func stat(key: String) -> void:
	stats[key] = int(stats.get(key, 0)) + 1


func debug_stats() -> String:
	var c := [{}, {}]
	for s in soldiers:
		if s.team < 0 or s.team > 1:
			continue
		var k: String = Soldier.Life.keys()[s.life]
		c[s.team][k] = int(c[s.team].get(k, 0)) + 1
	var out := "t=%.0f ents=%d" % [time, entities.size()]
	for t in 2:
		var ti: Dictionary = rules.team_summary()[t] if rules else {}
		out += " | %s %s veh=%d sup=%d fobs=%d" % [Defs.TEAM_NAMES[t], str(c[t]), _count_veh(t), int(ti.get("supply", 0)), (ti.get("fobs", []) as Array).size()]
		var bl := {}
		for st in structures:
			if st.team == t and st.skind != "depot":
				var key: String = st.skind + ("" if st.built else "*")
				bl[key] = int(bl.get(key, 0)) + 1
		out += " bld=%s" % str(bl)
		# each squad's nerve (and the drill it's in)
		var mor := []
		for sq in squads.values():
			if sq.team == t and not sq.alive_members().is_empty():
				mor.append("%d%s" % [int(sq.morale), ("/" + sq.drill) if sq.drill != "" else ""])
		out += " mor=%s" % ",".join(mor)
	out += "\n   events=%s" % str(stats)
	if settings.get("debug", false):
		for d in drones:
			out += "\n   drone%d phase=%d pos=%s tgt=%s life=%.1f dead=%s" % [d.eid, d.phase, str(d.position.snapped(Vector3.ONE * 0.1)), str(d.target_pos.round()), d.life_t, str(d.dead)]
		for v in vehicles:
			if v.vkind != "truck":
				out += "\n   %s%d t%d pos=%s hp=%d track=%s tgt=%s path=%d/%d" % [v.vkind, v.eid, v.team, str(v.position.round()), int(v.hp), str(v.track_broken), v.target.display_name() if v.target and not v.target.gone else "-", v.path_i, v.path.size()]
		for s in soldiers:
			out += "
   %s %s t%d %s pos=%s post=%s cov=%s at=%s h=%.2f m=%d up=%s bl=%s task=%s goal=%s supp=%d ammo=%d hp=%d tgt=%s vis=%d" % [s.utype, s.sname, s.team, Soldier.Life.keys()[s.life], str(s.position.snapped(Vector3.ONE * 0.1)), Soldier.Post.keys()[s.posture], Soldier.Cov.keys()[s.cover_type], str(s.at_cover), s.cover_h, s.cover_mat, str(s.peek_up), str(s.blind), s.task, s.goal_kind, int(s.suppression), s.total_ammo(), int(s.hp), s.target.display_name() if s.target and not s.target.gone else "-", s.vis_targets.size()]
	if settings.get("debug_trucks", false):
		for v in vehicles:
			if v.vkind == "truck":
				out += "\n   truck%d t%d pos=%s route %d/%d ret=%s blocked=%.1f speed=%.1f" % [v.eid, v.team, str(v.position.round()), v.route_i, v.route.size(), str(v.returning), v.blocked_t, v.speed]
		for st in structures:
			if st.skind == "fob":
				out += "\n   fob %s t%d truck=%s truck_t=%.1f status=%s road=%d" % [st.sname, st.team, str(st.truck != null), st.truck_t, st.supply_status, st.road.size()]
	return out


func _count_veh(t: int) -> int:
	var n := 0
	for v in vehicles:
		if v.team == t and v.vkind != "truck":
			n += 1
	return n
