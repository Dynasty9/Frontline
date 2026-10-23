class_name World
extends Node3D
## The battlefield. On the host it owns the simulation and replicates it; on
## clients it mirrors entities from spawn/snapshot RPCs. The node path
## (/root/Main/World) is identical on every peer so RPCs line up.

signal game_ended(winner: int)
signal report_updated
## How far build() has got: what the loading screen says, and its share of the way.
signal build_stage(text: String, frac: float)

var settings: Dictionary = {}
var srv := false
var has_view := true
var local_peer := 1
var local_team := 0
var time := 0.0
const SIMULATION_STEP := 1.0 / 30.0
var _simulation_pending := 0.0
var _snapshot_time := 0.0
var entities := {}
var next_eid := 1
var ready_peers: Array = []
## (server) What each player who has left commanded, by the peer id they had:
## {"squads": {sid: true}, "vehicles": {eid: true}}. Teammates or the AI
## command it meanwhile; it goes back to them if they rejoin.
var away_forces := {}
var known := {}  # peer -> {eid: true}: what each client has been told exists
var _reveal_t := 0.0
var tick_ms := 0.0
var prof := {}
# Static scenery still participates in combat and fire, but has no building
# simulation. Keep the small working sets independent of the map's tree count.
var sim_structures: Array[Structure] = []
var fob_structures: Array[Structure] = []
var owned_structures: Array[Structure] = []
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
var battle: BattleStats = null  # (server) the record the after-action report is made from
var report: Dictionary = {}  # the latest after-action report this peer may see (BattleStats.report)
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
var _painted_roads: Array = [[], [], []]
var _road_meshes: Array = [null, null, null]
var pings: Array = []  # [pos, expire, kind]
var winner := -1
var rng := RandomNumberGenerator.new()
var focused := false
var director: Director
var structure_view: StructureView
var soldier_view: SoldierViewBatch
var fog: FogView  # the fog of war drawn over the ground and the minimap (clients and a host with a view)
var atmo: Atmosphere
var view_team := -1  # whose fog of war we render (spectators can switch)

var soldiers: Array = []
var vehicles: Array = []
var structures: Array = []
var _dirty_static := {}
var _static_cursor := 0
var _unrevealed := {}  # peer -> entities not yet known to that peer
var projectiles: Array = []
var smoke_projectiles: Array[Projectile] = []
var drones: Array = []

const HCELL := 12.0
var _uhash := {}
var perception_cells: Array[Vector2i] = []
var perception: RefCounted
var _spawn_states := {}
var loading_ms := {}
var _load_started := 0
var _local_loading := false
var _loading_notified := false


func client_loading() -> bool:
	return not srv and not loaded


const SCELL := 16.0
var _shash := {}
var _house_hash := {}


func _ready() -> void:
	_load_started = Time.get_ticks_msec()
	MapDims.configure(int(settings.get("map_size", 1024)))
	# Cache dimensions once per match; terrain queries must not dispatch a
	# chain of property getters for every cell lookup.
	Nav.N = MapDims.N
	Nav.H = MapDims.HALF
	TerrainMap.N = MapDims.N
	TerrainMap.H = MapDims.HALF
	TerrainMap.DN = MapDims.N * TerrainMap.DRES
	HNav.C = 16 if MapDims.N == 1024 else 32
	HNav.NC = MapDims.N / HNav.C
	TrenchNet.N = MapDims.N * TrenchNet.RES
	Defs.MAP_HALF = MapDims.HALF
	srv = multiplayer.is_server()
	# The loading curtain covers the scene; drawing partially built scenery
	# only delays construction on large maps. Processing and RPCs stay active.
	visible = srv
	_local_loading = srv and LocalServer.child
	has_view = DisplayServer.get_name() != "headless"
	local_peer = multiplayer.get_unique_id()
	var pl: Dictionary = settings.get("players", {})
	local_team = int(pl[local_peer].team) if pl.has(local_peer) else -1
	view_team = local_team
	rng.seed = int(settings.get("seed", 1))
	_load_mark("allocating terrain")
	# the host has its battle from the start; a client's comes from the host (see
	# Joining), out of sight under the loading screen: drawing it meanwhile only
	# slows the building down
	loaded = srv
	set_process(not srv)
	visible = srv
	terrain = TerrainMap.new(self)
	_load_mark("terrain ready")
	water = WaterMap.new(self)
	if has_view:
		_build_environment()
		if not srv and atmo.grass:
			atmo.grass.set_process(false)  # (grown once, on the finished ground: _load_done)
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


## True while build() is under way.
var building := false


## The battle itself, once the world is in the tree: the ground and all that
## stands on it, the routes, the AI commanders and the view. main.gd awaits it
## straight after adding the world. With a window it's laid out a stage at a
## time, a frame of the loading screen between stages (see _breathe);
## headless it runs from start to finish at once, as part of that frame.
func build() -> void:
	building = true
	_staged = srv and (OS.has_feature("web") or (has_view and String(settings.get("scenario", "")) == ""))
	var polled := get_tree().multiplayer_poll
	if _staged:
		# nothing ticks a world half built, and no-one's word reaches it: a
		# player who has loaded is answered (sent the battlefield) once it's
		# all there, as when it was built in one go
		process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().multiplayer_poll = false
	if srv:
		if ClassDB.class_exists("PerceptionSearch") and not settings.get("gdscript_perception", false):
			perception = ClassDB.instantiate("PerceptionSearch")
		nav = Nav.new()
		_load_mark("navigation grids ready")
		nav.terrain = terrain
		combat = Combat.new(self)
		rules = Rules.new(self)
		battle = BattleStats.new(self)
		fires = Fires.new(self)
		if String(settings.get("scenario", "")) != "":
			if settings.scenario == "stress" and settings.get("stress_generated", false):
				await MapGen.new(self).generate()
				for unit: Entity in soldiers.duplicate() + vehicles.duplicate():
					despawn(unit)
				for squad in squads.values():
					remove_squad(squad)
				StressBattle.populate(self)
			else:
				MapGen.new(self).scenario(String(settings.scenario))
		elif String(settings.get("mission", "")) != "":
			var mgen := MapGen.new(self)
			await mgen.generate()
			mission = MissionDirector.new(self, String(settings.mission), mgen)
			mission.setup()
			set_mission_info(mission.info())
		else:
			await MapGen.new(self).generate()
		_load_mark("map generated")
		await _breathe("Settling the ground", 0.56)
		terrain.tick(1 << 30)
		await _breathe("Charting the water", 0.6)
		_water_view()
		await _breathe("Plotting the routes", 0.62)
		var tn := Time.get_ticks_msec()
		nav.finalize()
		_load_mark("navigation ready")
		print("Hierarchical nav: %s infantry, %s vehicles (%d ms)" % [nav.hnav_i.stats(), nav.hnav_v.stats(), Time.get_ticks_msec() - tn])
		if OS.has_environment("FL_DEBUG_HPA"):
			nav.benchmark(rng)
		for t in settings.get("ai_teams", []):
			commanders.append(CommanderAI.new(self, int(t)))
		Net.player_left.connect(_on_player_left)
		Net.player_joined.connect(_on_player_joined)
		Net.player_rejoined.connect(_on_player_rejoined)
		await _breathe("Deploying forces", 0.7)
	if has_view:
		cam = RtsCamera.new()
		cam.name = "Cam"
		cam.world = self
		add_child(cam)
		if not srv:
			structure_view = StructureView.new()
			structure_view.world = self
			add_child(structure_view)
		soldier_view = SoldierViewBatch.new()
		soldier_view.world = self
		add_child(soldier_view)
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
	if _staged:
		get_tree().multiplayer_poll = polled
		_staged = false
	process_mode = Node.PROCESS_MODE_INHERIT
	building = false


var _staged := false  # build() is waiting a frame between its stages
var _answer_ms := 0


## (a stage of a staged build, on the desktop) Has the window answer the
## system every quarter of a second while the stage lays out the town or the
## woods (several seconds, thousands of things put down): Windows marks a
## window that hasn't answered for five seconds Not Responding. Whatever input
## came in meanwhile is dropped. Nothing in the battle depends on it.
func _answer_window() -> void:
	var now := Time.get_ticks_msec()
	if now >= _answer_ms and not OS.has_feature("web"):
		_answer_ms = now + 250
		DisplayServer.force_process_and_drop_events()


## Between the stages of build() (and of MapGen.generate): tells the loading
## screen, and with a window waits a frame, so the loading bar moves and the
## window answers. Built in one go a battle took half a minute, all in one
## frame: a browser (which runs the game on the page's one thread) calls a page
## like that unresponsive, Windows marks the window Not Responding. The world
## doesn't tick meanwhile, and the stages build exactly what one go did.
## Headless this returns at once, so the build stays one piece; so it does
## for a --scenario test setup on the desktop (small, and its scripted events
## run on timers).
func _breathe(text: String, frac: float) -> void:
	build_stage.emit(text, frac)
	if _staged and is_inside_tree():
		await get_tree().process_frame


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
	if e is Vehicle and battle:
		battle.vehicle_fielded(e)
	if e is Structure:
		_shash_add(e)
		terrain.structure_changed(e, true)
	if not ready_peers.is_empty():
		_pend_spawn.append([e.eid, kind])
	if _staged:
		_answer_window()
	return e


func refresh_owned_structure(e: Structure) -> void:
	if not entities.has(e.eid) or e.gone:
		return
	if e.team >= 0:
		if not e in owned_structures:
			owned_structures.append(e)
	else:
		owned_structures.erase(e)


func _register(e: Entity) -> void:
	entities[e.eid] = e
	if e is Soldier:
		soldiers.append(e)
		if soldier_view:
			soldier_view.prepare(e.utype, e.team)
	elif e is Vehicle:
		vehicles.append(e)
	elif e is Structure:
		structures.append(e)
		refresh_owned_structure(e)
		mark_static_dirty(e)
		if e.skind in Structure.SIM_KINDS:
			sim_structures.append(e)
		if e.skind == "fob":
			fob_structures.append(e)
	elif e is Projectile:
		projectiles.append(e)
		refresh_smoke_projectile(e)
	elif e is Drone:
		drones.append(e)


func refresh_smoke_projectile(e: Projectile) -> void:
	if e.ptype == "smoke" and not e.gone:
		if not e in smoke_projectiles:
			smoke_projectiles.append(e)
	else:
		smoke_projectiles.erase(e)


func despawn(e: Entity) -> void:
	if e == null or e.gone:
		return
	e.gone = true
	entities.erase(e.eid)
	for pending: Dictionary in _unrevealed.values():
		pending.erase(e.eid)
	if e is Soldier:
		soldiers.erase(e)
		# out of his squad now: nothing may touch him once he's freed
		if e.squad and is_instance_valid(e.squad):
			e.squad.members.erase(e)
	elif e is Vehicle:
		vehicles.erase(e)
	elif e is Structure:
		if structure_view:
			structure_view.remove(e)
		structures.erase(e)
		owned_structures.erase(e)
		_dirty_static.erase(e.eid)
		sim_structures.erase(e)
		fob_structures.erase(e)
		_shash_remove(e)
		if terrain:
			terrain.structure_changed(e, false)
	elif e is Projectile:
		projectiles.erase(e)
		smoke_projectiles.erase(e)
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


## (view) An entity cleared away within the last few minutes, by its id (or null).
func gone_entity(eid: int) -> Entity:
	for i in range(_graveyard.size() - 1, -1, -1):
		var e = _graveyard[i][0]
		if is_instance_valid(e) and e.eid == eid:
			return e
	return null


func _sweep_graveyard() -> void:
	while not _graveyard.is_empty() and _graveyard[0][1] < time:
		var e = _graveyard.pop_front()[0]
		if is_instance_valid(e):
			if e.is_inside_tree():
				e.queue_free()
			else:
				e.free()


func _exit_tree() -> void:
	if _ground_task >= 0:
		# (left while the ground was still being laid out: it works on this world's maps)
		WorkerThreadPool.wait_for_task_completion(_ground_task)
		_ground_task = -1
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
		# a net goes up over whatever's to be hidden, and anything can go in under one
		if kind == "camo_net" or st.skind == "camo_net":
			if kind == "camo_net" and st.skind == "camo_net" and Defs.flat(st.position - pos).length() < 3.0:
				return "There's a net here already."
			continue
		if Defs.obb_overlap(c, half - Vector2(0.12, 0.12), yaw, Vector2(st.position.x, st.position.z), st.foot - Vector2(0.12, 0.12), st.yaw):
			return "Blocked by %s." % st.display_name()
	if not kind in ["mines", "wire", "trench", "sandbags", "fob", "camo_net"] and team >= 0 and team <= 1:
		var fp := Vector3(pos.x, 0, pos.z)
		for poly in roads[team]:
			var pts: PackedVector3Array = poly
			for i in range(pts.size() - 1):
				if Defs.dist_point_segment(fp, Defs.flat(pts[i]), Defs.flat(pts[i + 1])) < half.length() + 3.0:
					return "That would block your own supply road."
	if kind == "dock":
		pass  # (see above: the shore, our half)
	elif kind == "fob":
		# a town you hold is a foothold too: a FOB can go up near it
		var near_own := false
		for st in structures:
			if st.skind != "fob" and st.skind != "depot" and st.skind != "town":
				continue
			var d := Defs.flat(st.position - pos).length()
			if st.skind == "fob" and d < Defs.FOB_MIN_SPACING:
				return "Too close to another FOB."
			if st.team == team and st.built and d < Defs.FOB_EXPAND_RADIUS:
				near_own = true
		if not near_own:
			return "A new FOB must be within %d m of one of yours, or of a town you hold." % int(Defs.FOB_EXPAND_RADIUS)
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
	# Physical contacts need smaller steps than the battle AI and replication.
	var step := SIMULATION_STEP * Engine.time_scale
	if step <= 0.0: return
	_simulation_pending += dt
	while _simulation_pending + 1e-9 >= step:
		_simulation_pending = maxf(0.0, _simulation_pending - step)
		_simulate(step)


func simulation_fraction() -> float:
	if Engine.time_scale <= 0.0: return 0.0
	var between_ticks := Engine.get_physics_interpolation_fraction() * Engine.time_scale / Engine.physics_ticks_per_second
	return clampf((_simulation_pending + between_ticks) / (SIMULATION_STEP * Engine.time_scale), 0.0, 1.0)


func _simulate(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	# (a client loading works through the cover map under the loading screen
	# instead, by the time it takes rather than by the tick: _load_tick)
	if terrain and loaded:
		terrain.tick(2500)
	_grave_t -= dt
	if _grave_t <= 0.0:
		_grave_t = 5.0
		_sweep_graveyard()
	if not srv:
		time = minf(time + dt, _snapshot_time + 0.1)
		_net_in_t += dt
		if _net_in_t >= 1.0:
			net_in_bps = _net_in / _net_in_t
			_net_in = 0.0
			_net_in_t = 0.0
		return
	# A private battle begins once its renderer has built the initial world.
	# Network flushing continues, so loading never advances combat unseen.
	if _local_loading:
		_flush()
		return
	time += dt
	var tp := _p("terrain + cleanup", t0)
	_flush()
	tp = _p("network", tp)
	nav.update_hier()
	tp = _p("navigation rebuild", tp)
	nav.process_paths()
	tp = _p("pathing", tp)
	_rebuild_uhash()
	tp = _p("spatial hash", tp)
	for e in soldiers.duplicate():
		if not e.gone:
			e.sim(dt)
			if has_view:
				e.ip_capture()
	tp = _p("soldiers", tp)
	for e in sim_structures.duplicate():
		if not e.gone:
			e.sim(dt)
	tp = _p("structures", tp)
	fires.tick(dt)
	tp = _p("fire", tp)
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
	battle.tick(dt)
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
	tp = _p("team + reveal", tp)
	tick_ms = lerpf(tick_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)
	prof["TOTAL"] = tick_ms
	sim_usec += Time.get_ticks_usec() - t0
	if measure_ticks:
		var elapsed := (Time.get_ticks_usec() - t0) / 1000.0
		measured_ticks.append(elapsed)
		if elapsed > float(measured_worst_tick.get("total_ms", 0.0)):
			measured_worst_tick = {"time": time, "total_ms": elapsed, "systems_ms": _measured_tick_systems.duplicate()}
	net_out_bps = lerpf(net_out_bps, _net_out / maxf(dt, 0.001), 0.05)
	_net_out = 0.0


## Profiling helper: accumulates a smoothed per-tick cost for a named system.
## Client-side (view) profiling: microseconds per system, summed each frame.
## PerfProbe takes these and sets them back to zero: the totals every frame,
## each system's own every half second (every frame once someone's looking).
var vprof := {}
var measure_ticks := false
var measure_details := false
var measured_ticks: Array[float] = []
var measured_systems := {}
var measured_worst_tick := {}
var _measured_tick_systems := {}
var measured_details := {}
var measured_detail_max := {}
var measured_views := {}


func detail(key: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	var elapsed := (now - since) / 1000.0
	measured_details[key] = float(measured_details.get(key, 0.0)) + elapsed
	measured_detail_max[key] = maxf(float(measured_detail_max.get(key, 0.0)), elapsed)
	return now
var vp_usec := 0
var prof_raw := {}
var sim_usec := 0  # simulation time accumulated since the overlay last read it
var vprof_avg := {}
var _vprof_frames := 0
var _vprof_t := 0.0


func vp(key: String, since: int) -> void:
	var elapsed := Time.get_ticks_usec() - since
	vprof[key] = int(vprof.get(key, 0)) + elapsed
	vp_usec += elapsed
	if measure_ticks:
		measured_views[key] = float(measured_views.get(key, 0.0)) + elapsed / 1000.0


func _p(key: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	var ms := (now - since) / 1000.0
	prof[key] = lerpf(float(prof.get(key, 0.0)), ms, 0.05)
	prof_raw[key] = float(prof_raw.get(key, 0.0)) + ms
	if measure_ticks:
		measured_systems[key] = float(measured_systems.get(key, 0.0)) + ms
		_measured_tick_systems[key] = ms
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
				if e and not kn.has(e.eid):
					if can_know(e, view):
						arr.append(_initial_spawn(e, view))
						kn[e.eid] = true
					else:
						(_unrevealed[p] as Dictionary)[e.eid] = e
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
		# Unreliable events must fit a datagram even during a whole platoon's
		# opening volley. Reserve space for RPC and Variant array headers.
		var batch: Array = []
		var bytes := 64
		for event in _pend_fx:
			var size := var_to_bytes(event).size()
			if bytes + size > 1200 and not batch.is_empty():
				_to_ready("_rpc_fx", batch)
				batch = []
				bytes = 64
			batch.append(event)
			bytes += size
		if not batch.is_empty():
			_to_ready("_rpc_fx", batch)
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
		var arr := []
		for e: Entity in _take_reveals(p, view):
			arr.append(_initial_spawn(e, view))
			if arr.size() >= 80:
				rpc_id(p, "_rpc_spawn", arr)
				arr = []
		if not arr.is_empty():
			rpc_id(p, "_rpc_spawn", arr)


func _take_reveals(peer: int, view: int) -> Array:
	var out := []
	var pending: Dictionary = _unrevealed.get(peer, {})
	var kn: Dictionary = known.get(peer, {})
	for e: Entity in pending.values():
		if e.gone or kn.has(e.eid):
			pending.erase(e.eid)
		elif can_know(e, view):
			pending.erase(e.eid)
			kn[e.eid] = true
			out.append(e)
	return out


func _initial_spawn(e: Entity, view: int) -> Array:
	var state := StreamPeerBuffer.new()
	writing_view = view
	e.write_state(state)
	writing_view = -1
	var props := e.get_props()
	if view >= 0 and e.team >= 0 and e.team != view:
		props.erase("queue")
		props.erase("supply")
	return [e.eid, e.ekind(), props, state.data_array]


func mark_static_dirty(e: Entity) -> void:
	if srv and not e.gone and not ready_peers.is_empty():
		_dirty_static[e.eid] = e


func _snapshot_entities() -> Array:
	var list := []
	for e in soldiers + vehicles + projectiles + drones:
		if e.gone:
			continue
		if e.is_static():
			if not e.net_dirty and time < e.resend_t:
				continue
			e.net_dirty = false
			e.resend_t = time + 2.5 + randf() * 1.5
		list.append(e)
	# Changed buildings go immediately; unchanged scenery is refreshed over
	# three seconds, rather than scanning the whole map fifteen times a second.
	var selected := _dirty_static.duplicate()
	_dirty_static.clear()
	for i in ceili(structures.size() / 45.0):
		if structures.is_empty():
			break
		_static_cursor %= structures.size()
		var e: Entity = structures[_static_cursor]
		_static_cursor += 1
		selected[e.eid] = e
	for e: Entity in selected.values():
		if not e.gone:
			e.net_dirty = false
			list.append(e)
	return list


func _send_snapshots() -> void:
	if ready_peers.is_empty():
		return
	var list := _snapshot_entities()
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
func _client_loaded() -> void:
	if srv and multiplayer.get_remote_sender_id() in ready_peers:
		Net._long_timeout(multiplayer.get_remote_sender_id(), false)
		if LocalServer.child:
			if _local_loading:
				for job: Array in nav._path_jobs.values():
					job[6] = Time.get_ticks_msec()
			_local_loading = false

@rpc("any_peer", "call_remote", "reliable")
func _client_ready() -> void:
	if not srv:
		return
	var p := multiplayer.get_remote_sender_id()
	# only players the lobby let in (not a peer that never said who it was)
	if p in ready_peers or not Net.players.has(p):
		return
	var t0 := Time.get_ticks_usec()
	var view := view_of(p)
	var kn := {}
	known[p] = kn
	_unrevealed[p] = {}
	var recs := []
	for e in entities.values():
		if not can_know(e, view):
			(_unrevealed[p] as Dictionary)[e.eid] = e
			continue
		recs.append(_join_rec(e, view))
		kn[e.eid] = true
	# the battlefield as it stands, packed small (see Joining): the ground first,
	# so the client lays its water out while the rest comes in, then everything
	# on it, then word that that's all there is
	var sent := 0
	var pk := _pack({"n": recs.size(), "water": water.to_dict(), "roads": roads, "decor": decor, "town": town_rect, "kinds": terrain.base})
	rpc_id(p, "_rpc_join_map", pk)
	sent += (pk[1] as PackedByteArray).size()
	for i in range(0, recs.size(), JOIN_PACK):
		pk = _pack(recs.slice(i, i + JOIN_PACK))
		rpc_id(p, "_rpc_join_ents", pk)
		sent += (pk[1] as PackedByteArray).size()
	rpc_id(p, "_rpc_join_end")
	if OS.has_environment("FL_DEBUG_NET"):
		print("JOIN sent peer %d %d entities in %d kB (%.1f ms)" % [p, recs.size(), sent / 1024, (Time.get_ticks_usec() - t0) / 1000.0])
	if not mission_info.is_empty():
		rpc_id(p, "_rpc_mission", mission_info)
	if winner >= 0:
		# (joining, or back, after it was decided: the after-action report and
		# the end screen)
		rpc_id(p, "_rpc_report", battle.report(-1))
		rpc_id(p, "_rpc_over", winner)
	ready_peers.append(p)


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn(arr: Array) -> void:
	for it in arr:
		_queue_ent(int(it[0]), String(it[1]), it[2], it[3] if it.size() > 3 else PackedByteArray())
	if loaded and not focused:
		_try_focus()


@rpc("authority", "call_remote", "reliable")
func _rpc_despawn(ids: Array) -> void:
	for id in ids:
		_spawn_states.erase(id)
		var e: Entity = entities.get(id)
		if e:
			despawn(e)
		elif _load_rec.has(id):
			# gone before we got round to building it
			(_load_rec[id] as Array)[1] = ""
			_load_rec.erase(id)


@rpc("authority", "call_remote", "reliable")
func _rpc_props(d: Dictionary) -> void:
	for id in d:
		var e: Entity = entities.get(id)
		if e:
			var moved: bool = e is Structure and structure_view != null and (d[id] as Dictionary).has("pos")
			if moved:
				structure_view.remove(e)
				e.set_view_active(false)
			e.apply_props(d[id])
			if moved:
				structure_view.add(e)
		elif _load_rec.has(id):
			# (still waiting to be built: it's built as it is now)
			((_load_rec[id] as Array)[2] as Dictionary).merge(d[id], true)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_snap(data: PackedByteArray) -> void:
	var started := Time.get_ticks_usec()
	var n := data.size()
	_net_in += n
	if n < 4:
		return
	var b := StreamPeerBuffer.new()
	b.data_array = data
	# Loading time and a slow host must not advance the client's battle clock.
	var snapshot_time := b.get_float()
	if not is_finite(snapshot_time) or snapshot_time < 0.0:
		return
	_snapshot_time = snapshot_time
	time = _snapshot_time
	while b.get_position() + 5 <= n:
		var id := b.get_u32()
		var ln := b.get_u8()
		var st := b.get_position()
		if st + ln > n:
			return
		var e: Entity = entities.get(id)
		if e:
			if ln > 0:
				e.read_state(b)
			elif local_team >= 0:
				e.vis_mask &= ~(1 << local_team)
		elif _load_rec.has(id):
			_spawn_states[id] = data.slice(st, st + ln)
		b.seek(st + ln)
	vp("snapshot decode", started)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_fx(evs: Array) -> void:
	# (nobody sees them under the loading screen, and a crater dug meanwhile
	# would be dug into ground still being laid out: _lay_ground)
	if not has_view or not loaded:
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
	# (while loading, they're laid with the rest of the ground: _ground_done)
	if loaded:
		_rebuild_roads()


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
	_record()
	if hud:
		hud.show_game_over(w)


# --- joining (client) ------------------------------------------------------------------
# A client's world starts empty; the host sends it the battle as it stands once
# it says it's ready (_client_ready): the ground's shapes and kinds, then every
# entity it may know of, in a few compressed messages, then word that that's
# all. The client lays the ground out on a worker thread while the rest comes
# in, then builds what stands on it a slice at a time, then works out the cover
# map; the loading screen stays up meanwhile (main.gd), so the battle isn't
# built in a few huge frames after it's shown, and the connection is answered
# every frame, so the stream doesn't stall behind the building. Whatever the
# host sends meanwhile (new entities, changes, removals) queues up behind it.

const ENT_KINDS := ["soldier", "structure", "vehicle", "projectile", "drone"]
const JOIN_PACK := 400  # entities in each message of the join stream
const JOIN_MAX := 1 << 28  # (bytes) more than any battle unpacks to
const LOAD_SLICE_US := 45000  # building per frame under the loading screen (it still moves, at 15 fps or so)

## The battle as the host had it when we came in is all here and built (the
## host's is from the start).
var loaded := false
var load_frac := 0.0  # (client) how far it has got, 0..1
var _join_n := 0  # how many entities the host is sending
var _join_ground := false  # the ground has come
var _join_end := false  # and everything else
var _join_kinds := PackedByteArray()  # the host's ground kinds, until laid
var _load_q: Array = []  # [eid, kind ("" once gone), props], to build in the order they came
var _load_i := 0
var _load_rec := {}  # eid -> its record in _load_q, while it waits
var _load_step := 0
var _load_built := 0
var _load_cells := 0  # cover cells to work out after the building
var _cover_batch := 512  # and how many at a time (as many as take about a third of a slice)
var _cover_min := -1  # (or at least as many as TerrainMap shares out over its worker threads, if it does)
var _load_t0 := 0
var _load_marks: Array = []  # (FL_DEBUG_NET) when each stage was done
var _ground_task := -1
var _ground_water: WaterMap  # the water laid out off the main thread, then handed over


## One entity as the join stream carries it: [eid, its kind (ENT_KINDS), props].
## A structure leaves out what a new one has anyway: most of the map is trees,
## walls and floors that nothing has touched, and the client starts from the
## same defaults.
func _join_rec(e: Entity, view: int) -> Array:
	var initial := _initial_spawn(e, view)
	var d: Dictionary = initial[2]
	if e is Structure:
		var def := _struct_defaults()
		for k in def:
			if d.has(k) and typeof(d[k]) == typeof(def[k]) and d[k] == def[k]:
				d.erase(k)
	var ki := ENT_KINDS.find(e.ekind())
	return [e.eid, ki if ki >= 0 else e.ekind(), d, initial[3]]


static var _sdef := {}


static func _struct_defaults() -> Dictionary:
	if _sdef.is_empty():
		var s := Structure.new()
		_sdef = s.get_props()
		s.free()
	return _sdef


## A value packed for the join stream: [its size, zstd-compressed bytes].
static func _pack(v: Variant) -> Array:
	var raw := var_to_bytes(v)
	return [raw.size(), raw.compress(FileAccess.COMPRESSION_ZSTD)]


static func _unpack(pk: Array) -> Variant:
	if pk.size() != 2 or not pk[1] is PackedByteArray or int(pk[0]) <= 0 or int(pk[0]) > JOIN_MAX:
		return null
	return bytes_to_var((pk[1] as PackedByteArray).decompress(int(pk[0]), FileAccess.COMPRESSION_ZSTD))


@rpc("authority", "call_remote", "reliable")
func _rpc_join_map(pk: Array) -> void:
	var d = _unpack(pk)
	if not d is Dictionary:
		push_error("The host's map didn't unpack.")
		return
	_join_n = int(d.get("n", 0))
	water.from_dict(d.get("water", {}))
	roads = d.get("roads", [[], [], []])
	decor = d.get("decor", [])
	town_rect = d.get("town", Rect2())
	_join_kinds = d.get("kinds", PackedByteArray())
	_join_ground = true
	_load_mark("map")


@rpc("authority", "call_remote", "reliable")
func _rpc_join_ents(pk: Array) -> void:
	var arr = _unpack(pk)
	if not arr is Array:
		push_error("The host's entities didn't unpack.")
		return
	for it in arr:
		var k = it[1]
		_queue_ent(int(it[0]), ENT_KINDS[int(k)] if k is int else String(k), it[2], it[3])


@rpc("authority", "call_remote", "reliable")
func _rpc_join_end() -> void:
	_join_end = true
	_load_mark("stream")


## (client) An entity the host has told us of: built at once in a running
## battle; while we're loading, it waits its turn behind the rest.
func _queue_ent(id: int, kind: String, props: Dictionary, state := PackedByteArray()) -> void:
	if entities.has(id) or _load_rec.has(id):
		return
	_spawn_states[id] = state
	if loaded:
		_build_ent(id, kind, props)
		return
	var rec := [id, kind, props]
	_load_q.append(rec)
	_load_rec[id] = rec


func _build_ent(id: int, kind: String, props: Dictionary) -> void:
	var e := _make(kind)
	e.world = self
	e.eid = id
	e.srv = false
	e.apply_props(props)
	e.name = "E%d" % id
	_register(e)
	add_child(e)
	if e is Structure and structure_view != null:
		e.defer_view = true
	e.on_spawned()
	if _spawn_states.has(id):
		var data: PackedByteArray = _spawn_states[id]
		_spawn_states.erase(id)
		if not data.is_empty():
			var buffer := StreamPeerBuffer.new()
			buffer.data_array = data
			e.read_state(buffer)
		elif local_team >= 0:
			e.vis_mask &= ~(1 << local_team)
	if e is Structure:
		_shash_add(e)
		terrain.structure_changed(e, true)
		if structure_view:
			structure_view.add(e)


func _process(_dt: float) -> void:
	if not srv and not loaded:
		_load_tick()


## (client) A frame's worth of loading: the ground (and, meanwhile, the set
## dressing), then the entities and the cover map a slice at a time.
func _load_tick() -> void:
	var t0 := Time.get_ticks_usec()
	if _load_t0 == 0:
		_load_t0 = t0
	match _load_step:
		0:
			if not _join_ground:
				_load_stage("Waiting for the host", 0.0)
				return
			_lay_ground()
			_load_step = 1
			_load_stage("Laying out the town", 0.03)
		1:
			# (the street furniture stands on nothing the ground's work touches)
			set_decor(decor, town_rect)
			_load_mark("decor")
			_load_step = 2
			_load_stage("Charting the water", 0.1)
		2:
			if _ground_task >= 0 and not WorkerThreadPool.is_task_completed(_ground_task):
				_load_stage("Charting the water", 0.1 + 0.08 * minf(1.0, (t0 - _load_t0) / 4000000.0))
				return
			_ground_done()
			_load_step = 3
			_load_stage("Moving in", 0.2)
		3:
			while _load_i < _load_q.size() and Time.get_ticks_usec() - t0 < LOAD_SLICE_US:
				var rec: Array = _load_q[_load_i]
				_load_i += 1
				if String(rec[1]) == "":
					continue
				_load_rec.erase(rec[0])
				_build_ent(int(rec[0]), String(rec[1]), rec[2])
				_load_built += 1
			if _load_i >= _load_q.size():
				_load_q.clear()
				_load_i = 0
				if _join_end:
					if _load_cells == 0:
						_load_mark("entities")
					_load_cells = maxi(1, terrain._queue.size() - terrain._qhead)
					_load_step = 4
			_load_stage("Moving in", 0.2 + 0.7 * minf(1.0, float(_load_built) / maxf(1.0, _join_n)))
		4:
			if _load_i < _load_q.size():
				_load_step = 3  # (more came in meanwhile)
				return
			# the cover every wall and hedge gives, worked out as the host did
			# when it laid the map out: in batches as big as fit the frame (a
			# big batch may be shared out over the worker threads)
			if _cover_min < 0:
				_cover_min = int(terrain.get_script().get_script_constant_map().get("THREAD_CELLS", 0))
			while terrain._qhead < terrain._queue.size() and Time.get_ticks_usec() - t0 < LOAD_SLICE_US:
				var c0 := Time.get_ticks_usec()
				terrain.tick(maxi(_cover_batch, _cover_min))
				var took := maxi(1, Time.get_ticks_usec() - c0)
				_cover_batch = clampi(int(_cover_batch * (LOAD_SLICE_US / 3.0) / took), 128, 1 << 16)
			var left: int = terrain._queue.size() - terrain._qhead
			_load_stage("Taking cover", 0.9 + 0.1 * (1.0 - float(left) / _load_cells))
			if terrain._queue.is_empty():
				_load_done()


func _load_stage(text: String, frac: float) -> void:
	load_frac = frac
	# (the loading screen runs from where the client's empty world left it to
	# where main.gd's warm-up takes over)
	build_stage.emit(text, 0.14 + 0.58 * frac)


func _load_mark(what: String) -> void:
	loading_ms[what] = Time.get_ticks_msec() - _load_started
	if settings.has("perf_at") and not LocalServer.session.is_empty():
		LocalServer._write(".load" if srv else ".view-load", loading_ms)
	if _load_t0 == 0:
		_load_t0 = Time.get_ticks_usec()
	_load_marks.append("%s %.1f s" % [what, (Time.get_ticks_usec() - _load_t0) / 1000000.0])


## (client) The ground as the host has it: the water's shapes rasterized into
## the ground kinds and carved into the ground heights, and over that the kinds
## the host ended up with (a bridge deck or a paved square is road there
## because of the order its map was laid out in, which the shapes alone don't
## tell). Seconds of work, done on a worker thread while the rest comes in and
## the street furniture goes up; nothing else touches the ground meanwhile
## (entities wait to be built, effects aren't played, the cover map and the
## roads wait). The water is laid out by a WaterMap of its own, handed over
## when it's done, since the view reads the real one's decks every frame. (The
## carving says when it's done itself: Atmosphere takes the new heights to the
## view and the physics ground.)
func _lay_ground() -> void:
	_ground_water = WaterMap.new(self)
	_ground_water.from_dict(water.to_dict())
	_ground_task = WorkerThreadPool.add_task(_ground_job, false, "Laying out the ground")


func _ground_job() -> void:
	var w := _ground_water
	if not w.is_empty():
		w.paint_kinds()
	var tm := terrain
	var k := _join_kinds
	if k.size() == tm.base.size():
		for i in k.size():
			if tm.base[i] != k[i]:
				tm.base[i] = k[i]
				tm._refresh_cell(i)
	if not w.is_empty():
		w.carve()


func _ground_done() -> void:
	if _ground_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_ground_task)
		_ground_task = -1
	var w := _ground_water
	_ground_water = null
	_join_kinds = PackedByteArray()
	if w and not w.is_empty():
		water.deck = w.deck
		water.mask = w.mask
		water.version += w.version
	terrain.version += 1
	_load_mark("ground")
	_rebuild_roads()
	_water_view()


func _load_done() -> void:
	_try_focus()
	if soldier_view != null and soldier_view.warming():
		return
	if structure_view != null and structure_view.warming():
		return
	loaded = true
	_load_mark("client ready")
	if is_inside_tree() and multiplayer.get_unique_id() != 1:
		_client_loaded.rpc_id(1)
		Net._long_timeout(1, false)
	set_process(false)
	visible = true  # (main.gd's warm-up draws its first frames behind the loading screen)
	_load_rec.clear()
	_load_mark("cover")
	if atmo and atmo.grass:
		atmo.grass.set_process(true)
		atmo.grass.request_rebuild(0.2)
	if hud and hud.has_method("refresh_minimap"):
		hud.refresh_minimap()
	_try_focus()
	_load_stage("Ready", 1.0)
	if OS.has_environment("FL_DEBUG_NET"):
		print("JOIN loaded %d entities: %s" % [entities.size(), ", ".join(_load_marks)])


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
	var changed_view := false
	for t in 3:
		var current: Array = roads[t]
		var previous: Array = _painted_roads[t]
		var changed := current != previous
		if terrain and changed:
			# A captured town adds a supply route; the island's existing roads stay put.
			var added := []
			for poly: PackedVector3Array in current:
				if not poly in previous:
					added.append(poly)
			if not added.is_empty():
				terrain.paint_roads(added, 2.4 if t == 2 else 1.8)
			_painted_roads[t] = current.duplicate()
		if not has_view or atmo == null:
			continue
		if not changed and (_road_meshes[t] != null or current.is_empty()):
			continue
		changed_view = true
		if _road_meshes[t]:
			_road_meshes[t].queue_free()
			_road_meshes[t] = null
		if current.is_empty():
			continue
		var mi := atmo.make_road_mesh(current, t)
		add_child(mi)
		_road_meshes[t] = mi
		if OS.has_environment("FL_DEBUG_ROADS"):
			print("ROADS t=%d polys=%d aabb=%s" % [t, current.size(), str(mi.get_aabb())])
	if changed_view and atmo.grass:
		atmo.grass.request_rebuild(1.0)


func declare_winner(t: int) -> void:
	if winner >= 0:
		return
	winner = t
	if mission:
		send_msg(-1, "system", ("Mission accomplished. " if mission.over == 1 else "Mission failed. ") + mission.end_text)
	else:
		send_msg(-1, "system", "%s win the battle!" % Defs.TEAM_NAMES[t])
	# everyone gets the whole after-action report, then the end
	report = battle.report(-1)
	for p in ready_peers:
		rpc_id(p, "_rpc_report", report)
	game_ended.emit(t)
	_record()
	if hud:
		hud.show_game_over(t)
	for p in ready_peers:
		rpc_id(p, "_rpc_over", t)


## The battle goes on this player's service record (if they keep one; nothing
## for an observer).
func _record() -> void:
	Online.record_battle(BattleStats.service_record(self))


## Asks the host for the after-action report as it stands (it answers with
## _rpc_report and report_updated fires).
func request_report() -> void:
	if srv:
		report = battle.report(local_team)
		report_updated.emit()
	else:
		_rpc_report_req.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_report_req() -> void:
	if not srv:
		return
	var p := multiplayer.get_remote_sender_id()
	if p in ready_peers:
		rpc_id(p, "_rpc_report", battle.report(team_of_peer(p)))


@rpc("authority", "call_remote", "reliable")
func _rpc_report(d: Dictionary) -> void:
	report = d
	report_updated.emit()


# --- spatial queries ------------------------------------------------------------------

func _rebuild_uhash() -> void:
	if perception_cells.is_empty():
		for x in range(-8, 9):
			for z in range(-8, 9):
				perception_cells.append(Vector2i(x, z))
		perception_cells.sort_custom(func(a: Vector2i, b: Vector2i): return a.length_squared() < b.length_squared())
	_uhash.clear()
	var contact_meta := PackedInt32Array()
	var contact_values := PackedFloat64Array()
	var contact_count := 0
	if perception:
		contact_meta.resize((soldiers.size() + vehicles.size()) * 3)
		contact_values.resize(contact_meta.size())
	for s: Soldier in soldiers:
		if s.life == Soldier.Life.HIDDEN:
			continue
		_hadd(s)
		if perception and s.team >= 0 and (s.life == Soldier.Life.ALIVE or (s.life == Soldier.Life.DOWNED and time - s.last_shot_t <= 2.0)):
			var factor := terrain.concealment(s.position)
			if time - s.last_shot_t > 8.0 and not s.is_moving() and (s.at_cover or s.posture == Soldier.Post.PRONE):
				factor *= 0.7
			contact_meta[contact_count] = s.eid
			contact_meta[contact_count + 1] = s.team
			contact_meta[contact_count + 2] = 0
			contact_values[contact_count] = s.position.x
			contact_values[contact_count + 1] = s.position.z
			contact_values[contact_count + 2] = factor
			contact_count += 3
	for v: Vehicle in vehicles:
		_hadd(v)
		if perception and not v.gone:
			var factor := 0.5 if not v.is_air() and terrain.netted[terrain.idx_of(v.position)] > 0 else 1.0
			contact_meta[contact_count] = v.eid
			contact_meta[contact_count + 1] = v.team
			contact_meta[contact_count + 2] = 1
			contact_values[contact_count] = v.position.x
			contact_values[contact_count + 1] = v.position.z
			contact_values[contact_count + 2] = factor
			contact_count += 3
	if perception:
		contact_meta.resize(contact_count)
		contact_values.resize(contact_count)
		perception.rebuild(contact_meta, contact_values)


func _hadd(e: Entity) -> void:
	var k := Vector2i(floori(e.position.x / HCELL), floori(e.position.z / HCELL))
	var a = _uhash.get(k)
	if a == null:
		a = []
		_uhash[k] = a
	a.append(e)


## Soldiers (not hidden) and vehicles within r of p. Server only.
func units_near(p: Vector3, r: float, enemy_of := -1) -> Array:
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
			for e: Entity in a:
				if e.gone or (enemy_of >= 0 and (e.team == enemy_of or e.team < 0)):
					continue
				var ep := e.position
				var dx := ep.x - p.x
				var dz := ep.z - p.z
				if dx * dx + dz * dz <= r2:
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
		if e.skind == "floor":
			if not _house_hash.has(k):
				_house_hash[k] = []
			(_house_hash[k] as Array).append(e)


func _shash_remove(e: Structure) -> void:
	for k in e.hash_cells:
		var a = _shash.get(k)
		if a:
			a.erase(e)
		if _house_hash.has(k):
			(_house_hash[k] as Array).erase(e)
			if (_house_hash[k] as Array).is_empty():
				_house_hash.erase(k)
	e.hash_cells = []


func structures_near(p: Vector3, r: float, floors_only := false) -> Array:
	var index := _house_hash if floors_only else _shash
	var out := []
	var seen := {}
	for x in range(floori((p.x - r) / SCELL), floori((p.x + r) / SCELL) + 1):
		for z in range(floori((p.z - r) / SCELL), floori((p.z + r) / SCELL) + 1):
			var a = index.get(Vector2i(x, z))
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
	# Spread squad planning across the half-second without consuming combat RNG.
	sq.think_t = fmod(float(sq.sid) * 0.309016994, 0.5)
	next_sid += 1
	sq.team = team
	sq.owner = owner
	sq.kind = kind
	squads[sq.sid] = sq
	if battle:
		battle.squad_formed(sq)
	return sq


func remove_squad(sq: Squad) -> void:
	squads.erase(sq.sid)
	if battle:
		battle.squad_gone(sq)


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


## Human commanders share every unit on their side. The AI keeps its own
## allocation, so it cannot silently take over a human commander's troops.
## Check the team as well as ownership: neither client-supplied IDs nor an
## old owner field can grant command of an enemy or neutral unit.
func can_command_unit(peer: int, unit_team: int, owner: int) -> bool:
	var team := team_of_peer(peer)
	return team in [0, 1] and unit_team == team and (peer > 0 or owner == peer)


func _command_squads(peer: int, ids: Array) -> Array:
	var out := []
	for id in ids:
		var sq: Squad = squads.get(int(id))
		if sq and can_command_unit(peer, sq.team, sq.owner) and not sq in out:
			out.append(sq)
	return out


func _command_vehicles(peer: int, ids: Array) -> Array:
	var out := []
	for id in ids:
		var v = entities.get(int(id))
		if v is Vehicle and not v.is_auto() and can_command_unit(peer, v.team, v.owner_peer) and not v in out:
			out.append(v)
	return out


## An explicit human order takes an AI-controlled unit out of the strategic
## AI's allocation. Keep human owners unchanged for attribution and rejoining;
## every allied player can still command the unit, regardless of that owner.
func take_command(peer: int, sqs: Array, vehs: Array) -> void:
	if peer <= 0:
		return
	for sq in sqs:
		if sq.owner < 0 and can_command_unit(peer, sq.team, sq.owner):
			give_squad(sq, peer)
	for v in vehs:
		if v.owner_peer < 0 and can_command_unit(peer, v.team, v.owner_peer):
			give_vehicle(v, peer)


func execute_cmd(peer: int, d: Dictionary) -> void:
	if not srv:
		return
	if String(d.get("t", "")) == "demo_support":
		if _demo_ok(peer):
			rules.demo_support(String(d.get("kind", "")), d.pos, d.get("dir", Vector3.ZERO))
		return
	var team := team_of_peer(peer)
	if not team in [0, 1] or winner >= 0:
		return
	var t: String = d.get("t", "")
	var sqs := _command_squads(peer, d.get("squads", []))
	var vehs := _command_vehicles(peer, d.get("vehicles", []))
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
			take_command(peer, sqs, vehs)
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
			take_command(peer, sqs, vehs)
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
			take_command(peer, [], vehs)
			for v in vehs:
				v.dismount()
		"unit":
			var us = entities.get(int(d.get("soldier", 0)))
			if us is Soldier and can_command_unit(peer, us.team, us.owner_peer):
				if us.squad:
					take_command(peer, [us.squad], [])
				elif peer > 0 and us.owner_peer < 0:
					us.owner_peer = peer
					push_props(us, {"owner": peer})
				us.unit_order(d)
		"attack":
			var tgt: Entity = entities.get(int(d.get("target", 0)))
			if tgt and tgt.is_hostile_to(team):
				take_command(peer, sqs, vehs)
				for sq in sqs:
					sq.order_attack(tgt)
				for v in vehs:
					v.order_attack(tgt)
		"stop":
			take_command(peer, sqs, vehs)
			for sq in sqs:
				sq.order_stop()
			for v in vehs:
				v.order_stop()
		"retreat":
			take_command(peer, sqs, vehs)
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
			for av in vehs:
				if av.vdef.has("art") and av.fire_queue.size() < 3:
					var ad: Dictionary = av.vdef.art
					var dist: float = Defs.flat((d.pos as Vector3) - av.position).length()
					if dist < float(ad.get("min", 40.0)) or dist > float(ad.get("max", 240.0)):
						send_msg(team, "info", "%s: out of range (%d-%d m)." % [av.display_name(), int(ad.get("min", 40.0)), int(ad.get("max", 240.0))], av.position)
						continue
					take_command(peer, [], [av])
					av.fire_queue.append(d.pos)
					av.arty_t = minf(av.arty_t, time)
			take_command(peer, sqs, [])
			for sq in sqs:
				sq.order_fire_mission(d.pos, kind)
		"work":
			var tgt: Entity = entities.get(int(d.get("target", 0)))
			if tgt and tgt.team == team:
				take_command(peer, sqs, [])
				for sq in sqs:
					sq.order_work(tgt)
		"enter":
			var st = entities.get(int(d.get("target", 0)))
			if st is Structure and st.team == team:
				take_command(peer, sqs, [])
				for sq in sqs:
					sq.order_enter(st)
		"sling":
			var sv = entities.get(int(d.get("target", 0)))
			if sv is Vehicle and sv.team == team:
				for v in vehs:
					if v.can_sling(sv):
						take_command(peer, [], [v, sv])
						v.order_sling(sv)
						break
		"board":
			var bv = entities.get(int(d.get("target", 0)))
			if bv is Vehicle and bv.team == team:
				take_command(peer, sqs, [])
				for sq in sqs:
					sq.order_board(bv)
		"throw":
			take_command(peer, sqs, [])
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
	if LocalServer.child and LocalServer.disconnected_peer != 0:
		var old := LocalServer.disconnected_peer
		for sq in squads.values():
			if sq.owner == old:
				sq.owner = id
		for e: Entity in entities.values():
			if e.owner_peer == old:
				e.owner_peer = id
				push_props(e, {"owner": id})
		if mission:
			mission.owner_changed(old, id)
		LocalServer.disconnected_peer = 0
		return
	battle.joined(id, team)
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


## Who takes over a side's forces when one of its commanders goes: another
## player on that side, or else the AI.
func heir_of(team: int) -> int:
	var heir := 0
	for pid in Net.players:
		if int(Net.players[pid].team) == team:
			heir = int(pid)
	return heir if heir != 0 else -1 - team


## Who commands for `peer`: the peer, while they're here; while they're away,
## whoever took over their forces.
func acting_owner(peer: int, team: int) -> int:
	if peer <= 0 or Net.players.has(peer):
		return peer
	return heir_of(team)


## A squad or vehicle that came for a player who has left (one they had
## queued, say): it's theirs again if they come back.
func hold_for(peer: int, e: Variant) -> void:
	var keep: Dictionary = away_forces.get(peer, {})
	if keep.is_empty():
		return
	if e is Squad:
		keep.squads[(e as Squad).sid] = true
	elif e is Vehicle:
		keep.vehicles[(e as Vehicle).eid] = true
		for m in (e as Vehicle).passengers:
			if is_instance_valid(m) and m.squad:
				keep.squads[m.squad.sid] = true


func give_squad(sq: Squad, to: int) -> void:
	sq.owner = to
	for m in sq.members:
		m.owner_peer = to
		push_props(m, {"owner": to})


func give_vehicle(v: Vehicle, to: int) -> void:
	v.owner_peer = to
	push_props(v, {"owner": to})


func _on_player_left(id: int, team: int, pname: String) -> void:
	ready_peers.erase(id)
	known.erase(id)
	_unrevealed.erase(id)
	if LocalServer.child:
		return  # the authenticated launcher can reclaim exactly these forces
	if team < 0:
		send_msg(-1, "system", "%s left the game." % pname)
		return
	var new_owner := heir_of(team)
	var heir := maxi(new_owner, 0)  # (0: nobody left, the AI takes over)
	var keep := {"squads": {}, "vehicles": {}}
	for sq in squads.values():
		if sq.owner == id:
			keep.squads[sq.sid] = true
			give_squad(sq, new_owner)
	for v in vehicles:
		if v.owner_peer == id:
			keep.vehicles[v.eid] = true
			give_vehicle(v, new_owner)
	away_forces[id] = keep
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


## A player back after a dropped connection, a crash or a restart. Whatever of
## their force is still fighting comes back to them from whoever held it, and
## an AI that only stood in for a side left without commanders hands back
## command too (with all it was holding).
func _on_player_rejoined(id: int, old_id: int, team: int, pname: String) -> void:
	if LocalServer.child:
		_on_player_joined(id, team, pname)
		return
	var keep: Dictionary = away_forces.get(old_id, {})
	away_forces.erase(old_id)
	battle.rejoined(old_id, id, team)
	stat("rejoined")
	if team < 0:
		send_msg(-1, "system", "%s is back, watching." % pname)
		return
	var back := 0
	for sid in keep.get("squads", {}):
		var sq: Squad = squads.get(int(sid))
		if sq and sq.team == team and sq.has_alive_members():
			give_squad(sq, id)
			back += 1
	for eid in keep.get("vehicles", {}):
		var v = entities.get(int(eid))
		if v is Vehicle and not v.gone and v.team == team:
			give_vehicle(v, id)
			back += 1
	for i in back:
		stat("rejoin_returned")
	# what they had queued is still on its way to them
	for st in structures:
		for q in st.queue:
			if int(q.owner) == old_id:
				q.owner = id
	if mission:
		mission.player_rejoined(id, back > 0)
		send_msg(-1, "system", "%s is back in the mission." % pname)
		return
	var ai := -1 - team
	var stood_down := false
	if not team in settings.get("ai_teams", []):
		for c in commanders.duplicate():
			if c.team == team:
				commanders.erase(c)
				stood_down = true
	if stood_down:
		for sq in squads.values():
			if sq.team == team and sq.owner == ai:
				give_squad(sq, id)
		for v in vehicles:
			if v.team == team and v.owner_peer == ai and not v.is_auto():
				give_vehicle(v, id)
		stat("rejoin_ai_stood_down")
		send_msg(-1, "system", "%s is back and takes command from the AI." % pname)
	elif back > 0:
		send_msg(-1, "system", "%s is back and takes command of their forces again." % pname)
	else:
		send_msg(-1, "system", "%s is back in the battle." % pname)


# --- debugging -----------------------------------------------------------------------------

var stats := {}


func stat(key: String) -> void:
	stats[key] = int(stats.get(key, 0)) + 1


func debug_stats() -> String:
	var c := [{}, {}]
	var own := [{}, {}]  # whose soldiers: a player's peer id, or "ai"
	for s in soldiers:
		if s.team < 0 or s.team > 1:
			continue
		var k: String = Soldier.Life.keys()[s.life]
		c[s.team][k] = int(c[s.team].get(k, 0)) + 1
		var o := str(s.owner_peer) if s.owner_peer > 0 else "ai"
		own[s.team][o] = int(own[s.team].get(o, 0)) + 1
	var out := "t=%.0f ents=%d" % [time, entities.size()]
	for t in 2:
		var ti: Dictionary = rules.team_summary()[t] if rules else {}
		out += " | %s %s own=%s veh=%d sup=%d inc=%d/min fobs=%d towns=%d" % [Defs.TEAM_NAMES[t], str(c[t]), str(own[t]), _count_veh(t), int(ti.get("supply", 0)), int(ti.get("inc", 0)),
			(ti.get("fobs", []) as Array).size(), (ti.get("towns", []) as Array).size()]
		var bl := {}
		for st in structures:
			if st.team == t and st.skind != "depot" and st.skind != "town":
				var key: String = st.skind + ("" if st.built else "*")
				bl[key] = int(bl.get(key, 0)) + 1
		out += " bld=%s" % str(bl)
		# each squad's nerve (and the drill it's in)
		var mor := []
		for sq in squads.values():
			if sq.team == t and sq.has_alive_members():
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
		for tn in rules.town_list:
			out += "\n   town %s t%d stock=%d intact=%.2f cap=%d/%d truck=%s status=%s road=%d" % [tn.sname, tn.team, int(tn.supply), tn.intact, int(tn.cap_prog), tn.cap_team, str(tn.truck != null), tn.supply_status, tn.road.size()]
	return out


func _count_veh(t: int) -> int:
	var n := 0
	for v in vehicles:
		if v.team == t and v.vkind != "truck":
			n += 1
	return n
