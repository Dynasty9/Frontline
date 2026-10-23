extends Node
## Root: owns the menu and the World. Also understands a few command-line
## switches (after `--`) used for automated testing:
##   --aivai               host as spectator, both sides AI
##   --host [--players=N]  host and start (when N players have joined)
##   --join=IP             join a host
##   --team=N              the side to play (-1 spectator); a client registers with it
##   --list                with --host: list the battle on the matchmaker
##   --find-match          press Find Match (joins a listed battle, or hosts one)
##   --login=EMAIL:PASSWORD [--signup=CALLSIGN]   sign in (or create the account) first
##   (and Online's own: --matchmaker=URL --account=PATH --no-stun)
##   --timescale=X --quit-after=SECONDS --stats=SECONDS --verbose
##   --screenshot=PATH --shot-at=SECONDS --focus=X,Z --zoom=D
##   --sound-dump=DIR      write every synthesised sound and music sample to DIR as WAVs, then quit

var menu: Control
var world: World
var args := {}
var _quit_at := -1.0
## How much longer than --quit-after a test client waits for the host's world
## before it gives up and quits anyway (its summary then says waited=-1).
const CLIENT_WAIT := 300.0
var _stats_every := 0.0
var _stats_t := 0.0
var _shot_done := false
var _shot_i := 0
var _perf_t0 := 0
var _perf_frames := 0
var _curtains := false  # intro and loading screens (normal launches; tests skip them)
var _curtain_layer: CanvasLayer


func _ready() -> void:
	if "--startup-trace" in OS.get_cmdline_user_args():
		print("STARTUP main._ready at %d ms" % Time.get_ticks_msec())
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--"):
			var kv := s.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("offscreen") and DisplayServer.get_name() != "headless":
		# renders for tooling (model sheets): the window starts minimized (the
		# render copy's override.cfg) and is moved far off-screen before it's
		# restored, so it never appears over the desktop or takes the focus
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_position(Vector2i(-12000, -12000))
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_position(Vector2i(-12000, -12000))
	if args.has("sound-dump"):
		Sfx.dump(String(args["sound-dump"]))
		await Music.dump(String(args["sound-dump"]))
		get_tree().quit()
		return
	if args.has("soldier-sheet"):
		# a lineup of every kind of soldier, saved as an image (no menu, no game)
		var sheet: Node3D = preload("res://scripts/ui/soldier_sheet.gd").new()
		sheet.set("args", args)
		add_child(sheet)
		return
	add_child(preload("res://scripts/ui/perf_overlay.gd").new())
	menu = preload("res://scripts/ui/menu.gd").new()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	layer.add_child(menu)
	# --menu-cursor=X,Y: hold the map's cursor hill there (fractions of the screen; screenshots)
	if args.has("menu-cursor"):
		var mc := String(args["menu-cursor"]).split(",")
		TopoBackdrop.pin_cursor(Vector2(float(mc[0]), float(mc[1])))
	# --menu-clock=SECONDS: start the map that far into its drift and its colours
	if args.has("menu-clock"):
		TopoBackdrop.start_at(float(args["menu-clock"]))
	_curtains = args.is_empty() or args.has("curtain")
	_curtain_layer = CanvasLayer.new()
	_curtain_layer.layer = 120
	add_child(_curtain_layer)
	if _curtains:
		_intro()
	Net.game_start.connect(_on_game_start)
	Net.net_error.connect(func(m): return_to_menu(m))
	if args.has("name"):
		Net.my_name = args.name
	if args.has("mood"):
		Settings.v["mood"] = String(args.mood)
	if not args.is_empty():
		Settings.no_save = true
	if args.has("perf"):
		Settings.v["perf"] = int(args.perf)
	if args.has("preset"):
		Settings.apply_preset(String(args.preset), false)
	# --set=key:value,key:value overrides single settings (render A/B tests)
	if args.has("set"):
		for kv in String(args["set"]).split(","):
			var pair := kv.split(":")
			if pair.size() == 2:
				var cur = Settings.v.get(pair[0])
				Settings.v[pair[0]] = (pair[1] == "true") if cur is bool else (float(pair[1]) if cur is float else int(pair[1]))
		Settings.apply_global()
	if args.has("novsync"):
		Settings.v["vsync"] = false
		Settings.apply_global()
	if args.has("timescale"):
		Engine.time_scale = float(args.timescale)
		Engine.max_physics_steps_per_frame = 16
	if args.has("quit-after"):
		_quit_at = float(args["quit-after"])
	if args.has("stats"):
		_stats_every = float(args.stats)
	var port := int(args.get("port", Net.DEFAULT_PORT))
	if args.has("login"):
		await _test_login()
	if args.has("scenario"):
		# --play: command the Coalition side yourself instead of watching
		Net.host_game(port, 0 if args.has("play") else -1)
		if args.has("seed"):
			Net.set_setting("fixed_seed", int(args.seed))
		Net.set_setting("scenario", String(args.scenario))
		Net.set_setting("scenario_player", args.has("play"))
		Net.set_setting("ai_fill", false)
		Net.set_setting("debug_trucks", args.has("debug-trucks"))
		Net.set_setting("debug", true)
		Net.set_setting("debug_cover", args.has("debug-cover"))
		Net.set_setting("static", args.has("static"))
		Net.start_game()
	elif args.has("aivai"):
		Net.host_game(port, -1)
		if args.has("seed"):
			Net.set_setting("fixed_seed", int(args.seed))
		Net.set_setting("verbose", args.has("verbose"))
		Net.set_setting("debug_trucks", args.has("debug-trucks"))
		Net.start_game()
	elif args.has("mission") and not args.has("host"):
		# --play: command the force yourself; otherwise the mission plays itself
		var md := Missions.find(String(args.mission))
		Net.host_game(port, int(md.get("side", 0)) if args.has("play") else -1)
		Net.set_setting("mission", String(args.mission))
		Net.set_setting("mission_autoplay", args.has("autoplay") or not args.has("play"))
		if args.has("seed"):
			Net.set_setting("fixed_seed", int(args.seed))
		Net.set_setting("verbose", args.has("verbose"))
		Net.start_game()
	elif args.has("host"):
		if args.has("list"):
			await Online.host(port, int(args.get("team", 0)))
		else:
			Net.host_game(port, int(args.get("team", 0)))
		if args.has("mission"):
			Net.set_setting("mission", String(args.mission))
			Net.set_setting("mission_autoplay", args.has("autoplay"))
		Net.set_setting("ai_allies", args.has("ai-allies"))
		Net.set_setting("verbose", args.has("verbose"))
		Net.set_setting("debug_trucks", args.has("debug-trucks"))
		if not args.has("players"):
			Net.start_game()
		else:
			Net.lobby_updated.connect(_maybe_autostart)
	elif args.has("join") or args.has("find-match"):
		if args.has("team"):
			Net.join_team = int(args.team)
		if args.has("join"):
			Net.join_game(String(args.join), port)
		else:
			menu._find_match()


## --login=EMAIL:PASSWORD (with --signup=CALLSIGN to create the account first).
func _test_login() -> void:
	var cred := String(args.login).split(":", true, 1)
	var r: Dictionary
	if args.has("signup"):
		r = await Online.sign_up(cred[0], cred[1] if cred.size() > 1 else "", String(args.signup))
	else:
		r = await Online.sign_in(cred[0], cred[1] if cred.size() > 1 else "")
	print("LOGIN ok=%s callsign=%s %s" % [str(r.ok), Online.callsign, String(r.error)])


func _dump_structs() -> void:
	for st in world.structures:
		if not st.skind in ["floor", "tree"]:
			print("STRUCT %s t%d pos=%s yaw=%.2f size=%s built=%s wrecked=%s" % [st.skind, st.team, str(st.position.snapped(Vector3.ONE * 0.1)), st.yaw, str(st.size), str(st.built), str(st.wrecked)])


func _maybe_autostart() -> void:
	if not Net.in_game and Net.players.size() >= int(args.get("players", 2)):
		await get_tree().create_timer(1.0).timeout
		if not Net.in_game:
			Net.start_game()


func _curtain(mode: String) -> Curtain:
	for c in _curtain_layer.get_children():
		c.queue_free()
	var cur := Curtain.new()
	cur.mode = mode
	_curtain_layer.add_child(cur)
	return cur


## The title carries on from the boot splash (the same picture), wakes the
## map and hands it to the menu, which lies on the same map: only the title
## gives way to the menu.
func _intro() -> void:
	var cur := _curtain("intro")
	# --intro-at=SECONDS (with --curtain): hold the title at that moment (screenshots;
	# 0 is the boot splash, which is rendered this way)
	if args.has("intro-at"):
		cur.hold_at = float(args["intro-at"])
		TopoBackdrop.hold(cur.hold_at)
	while is_instance_valid(cur) and not cur.title_done():
		await get_tree().process_frame
	if is_instance_valid(cur):
		menu.arrive()
		cur.finish(1.8)


func _mission_text(s: Dictionary) -> Array:
	var pl: Dictionary = s.get("players", {})
	var me: int = multiplayer.get_unique_id()
	var team := int(pl[me].team) if pl.has(me) else -1
	var what := ""
	var side := ""
	if String(s.get("mission", "")) != "":
		var md := Missions.find(String(s.mission))
		side = Defs.TEAM_NAMES[int(md.side)]
		return [String(md.title), [["SIDE", side], ["FORCE", String(md.force)], ["AREA", String(md.area)], ["CONDITIONS", "Assessing"]], String(md.op), String(md.brief)]
	if String(s.get("scenario", "")) != "":
		what = "Scenario: %s" % String(s.scenario).capitalize()
	elif team < 0:
		what = "Observe: two AI commanders fight for the town"
	else:
		var humans := 0
		for id in pl:
			if int(pl[id].team) >= 0:
				humans += 1
		what = ("Command the %s against the AI" % Defs.TEAM_NAMES[team]) if humans <= 1 else ("%d commanders, %s" % [humans, "co-op" if s.get("ai_fill", true) else "head to head"])
	side = Defs.TEAM_NAMES[team] if team >= 0 else "Observer"
	return [what, [["SIDE", side], ["AREA", "A crossroads town and its farmland, %d x %d m" % [int(MapDims.SIZE), int(MapDims.SIZE)]], ["CONDITIONS", "Assessing"]]]


func _on_game_start(s: Dictionary) -> void:
	var cur: Curtain = null
	if _curtains:
		cur = _curtain("loading")
		var mt := _mission_text(s)
		cur.brief(int(s.get("seed", 1)), String(mt[0]), mt[1], String(mt[2]) if mt.size() > 2 else "", String(mt[3]) if mt.size() > 3 else "")
		cur.set_stage("Surveying the ground", 0.14)
		if multiplayer.is_server():
			# let it reach the screen before the long build (clients build at once:
			# their world is small and the host's state is on its way)
			await get_tree().process_frame
			await get_tree().process_frame
	menu.visible = false
	Settings.set_ui_menu(false)
	if world:
		world.name = "OldWorld"
		world.queue_free()
	world = World.new()
	world.name = "World"
	world.settings = s
	add_child(world)
	world.game_ended.connect(_on_game_ended)
	# a headless client says which after-action report it was sent (multiplayer tests)
	if not world.srv and DisplayServer.get_name() == "headless":
		world.report_updated.connect(func():
			var r: Dictionary = world.report
			var sd: Array = r.get("sides", [{}, {}])
			print("CLIENT report t=%.0f full=%s commanders=%d units=%d samples=%d enemy_known=%s" % [float(r.get("t", 0.0)), str(r.get("full", false)),
				(r.get("players", []) as Array).size(), (r.get("units", []) as Array).size(), (r.get("tl", []) as Array).size(),
				str(not (sd[1 - maxi(0, world.local_team)] as Dictionary).is_empty())]))
	if cur and is_instance_valid(cur):
		_warm_up(cur)
	if args.has("focus") and world.cam:
		var f := String(args.focus).split(",")
		world.cam.focus(Vector3(float(f[0]), 0, float(f[1])))
		world.focused = true
		if world.director:
			world.director.active = false
	if args.has("pitch") and world.cam:
		world.cam.pitch_deg = float(args["pitch"])
	if args.has("cam-yaw") and world.cam:
		world.cam.yaw = float(args["cam-yaw"])
	if args.has("zoom") and world.cam:
		world.cam.target_dist = float(args.zoom)
		world.cam.dist = float(args.zoom)
	# --coop-demo[=N]: N made-up co-commanders on your side, at work beside you;
	# --bot-presence: this (test) client's presence is made up and really sent
	if args.has("coop-demo"):
		world.coop.start_demo(int(args["coop-demo"]))
	if args.has("bot-presence"):
		world.coop.start_bot()
	# --keys-test: the key bindings end to end (matching, rebinding, the Controls page)
	if args.has("keys-test") and world.cam:
		var kt: Node = preload("res://scripts/game/keys_test.gd").new()
		kt.set("world", world)
		world.add_child(kt)
	# --cam-test: drive the camera through its controls and check each one
	if args.has("cam-test") and world.cam:
		var ct: Node = preload("res://scripts/game/cam_test.gd").new()
		ct.set("world", world)
		world.add_child(ct)


var _fx_next := 2.0
var _trace_t := 0.0
var _tf_t := 0.0
var _trace_f: FileAccess = null
var _fx_i := 0
var _sd_next := 2.0
var _sd_i := 0


## Visual test: rounds fired at each kind of surface in a row across the
## camera's focus - earth, stone, sandbags, wood, leaves, steel, a man - from
## a little way off (no damage). --shot-demo=hmg fires that gun only;
## --shot-demo-every=1.5 fires a volley at all of them at once that often;
## --shot-demo-cannon also fires a tank gun now and then.
func _shot_demo() -> void:
	if world.time < _sd_next or world.cam == null:
		return
	var guns := ["rifle", "mg", "hmg", "smg"]
	var snd: String = String(args["shot-demo"]) if String(args["shot-demo"]) != "1" else guns[(_sd_i / 21) % guns.size()]
	var every := float(args.get("shot-demo-every", 0.09 if snd in ["mg", "hmg", "minigun", "ac"] else 0.13))
	_sd_next = world.time + every
	var kinds := [Fx.HIT_DIRT, Fx.HIT_STONE, Fx.HIT_SAND, Fx.HIT_WOOD, Fx.HIT_LEAVES, Fx.HIT_METAL, Fx.HIT_FLESH]
	var c := world.cam.focus_pos
	var pick: Array = range(kinds.size()) if every > 0.5 else [_sd_i % kinds.size(), (_sd_i + 3) % kinds.size()]
	for i: int in pick:
		var x := (i - 3) * 2.2
		var to := c + Vector3(x + randf_range(-0.3, 0.3), 0.0 if i == 0 else randf_range(0.6, 1.2), -3.0 + randf_range(-0.3, 0.3))
		var from := c + Vector3(x * 0.4 + (4.0 if i % 2 == 0 else -4.0), 1.3, 6.0)
		world.fx.play([Fx.SHOT, from, to, kinds[i], snd, -1])
	_sd_i += 1
	if args.has("shot-demo-cannon") and (every > 0.5 or _sd_i % 40 == 0):
		if _sd_i % 2 == 0:
			world.fx.play([Fx.CANNON, c + Vector3(7, 2.3, 4), c + Vector3(-8, 0.5, -30)])
		else:
			world.fx.play([Fx.LAUNCH, c + Vector3(6, 1.5, 3), Vector3(-0.3, 0.05, -1).normalized()])


## Visual test: fires explosions of every size near the camera focus (no damage).
func _fx_demo() -> void:
	if world.time < _fx_next:
		return
	var sizes := [1.0, 1.4, 0.4, 2.0, 1.2]
	var sz: float = float(args["fx-demo"]) if String(args["fx-demo"]) != "1" else sizes[_fx_i % sizes.size()]
	var c := world.cam.focus_pos if world.cam else Vector3.ZERO
	var off := Vector3(-6 + (_fx_i % 3) * 6.0, 0.0, -3 + (_fx_i % 2) * 5.0)
	world.fx.play([Fx.EXPLODE, c + off, sz])
	_fx_i += 1
	_fx_next = world.time + float(args.get("fx-every", 2.5))


func _on_game_ended(w: int) -> void:
	if world == null:
		return
	if world.srv and (args.has("stats") or args.has("quit-on-win")):
		print("WINNER %s at t=%.0f" % [Defs.TEAM_NAMES[w], world.time])
		print("FINAL ", world.debug_stats())
		print("REPORT ", world.battle.summary())
	if args.has("quit-on-win"):
		get_tree().quit()


var _def_step := 0
var _pit_id := 0


## Test helper: lay a trench line by "dragging", build a mortar pit, then call a fire mission.
func _bot_defense() -> void:
	var fob: Structure = null
	for st in world.structures:
		if st.skind == "fob" and st.team == world.local_team:
			fob = st
	if fob == null:
		return
	var fwd := Vector3.FORWARD if world.local_team == 0 else Vector3.BACK
	if _def_step == 0 and world.time > 3.0:
		_def_step = 1
		var items := []
		var a := fob.position + fwd * 22.0 + Vector3(-12, 0, 0)
		for i in 4:
			items.append([a + Vector3(6.0 * (i + 0.5), 0, 0), 0.0])
		world.send_cmd({"t": "build_many", "kind": "trench", "items": items, "squads": []})
		print("BOT: trench line of 4 ordered")
	elif _def_step == 1 and world.time > 5.0:
		_def_step = 2
		for i in 12:
			var p := fob.position - fwd * 14.0 + Vector3(-10.0 + i * 2.0, 0, 0)
			if world.placement_error(world.local_team, "mortar_pit", p, 0.0) == "":
				world.send_cmd({"t": "build", "kind": "mortar_pit", "pos": p, "yaw": 0.0, "squads": []})
				print("BOT: mortar pit ordered at ", p)
				break
	elif _def_step == 2:
		for st in world.structures:
			if st.skind == "mortar_pit" and st.team == world.local_team and st.built and st.gunner != null:
				_pit_id = st.eid
				_def_step = 3
				print("BOT: mortar pit built and crewed at t=%.0f" % world.time)
				world.send_cmd({"t": "fire_mission", "building": _pit_id, "pos": fob.position + fwd * 120.0, "kind": "he"})
				print("BOT: fire mission called")


var _bot_step := 0


## Test helper: issue a few real commands as the local player.
func _bot_cmds() -> void:
	var mine := {}
	var eng := []
	for s in world.soldiers:
		if s.owner_peer == world.local_peer and s.sid != 0:
			mine[s.sid] = true
			if Defs.UNITS[s.utype].get("engineer", false) and not s.sid in eng:
				eng.append(s.sid)
	if _bot_step == 0 and world.time > 4.0 and not mine.is_empty():
		_bot_step = 1
		var riflemen := []
		for sid in mine:
			if not sid in eng:
				riflemen.append(sid)
		world.send_cmd({"t": "move", "squads": riflemen, "pos": Vector3(0, 0, 40), "face": Vector3.FORWARD})
		print("BOT: move sent for ", riflemen)
	elif _bot_step == 1 and world.time > 6.0:
		_bot_step = 2
		var fob: Structure = null
		for st in world.structures:
			if st.skind == "fob" and st.team == world.local_team:
				fob = st
		if fob:
			for i in 12:
				var p := fob.position + Vector3(-12.0 + i * 2.0, 0, -14.0 - (i % 3) * 3.0)
				if world.placement_error(world.local_team, "sandbags", p, 0.0) == "":
					world.send_cmd({"t": "build", "kind": "sandbags", "pos": p, "yaw": 0.0, "squads": eng})
					print("BOT: build sandbags at ", p)
					break
	elif _bot_step == 2 and world.time > 8.0:
		_bot_step = 3
		world.send_cmd({"t": "chat", "text": "hello from %s" % Net.my_name})
	elif _bot_step == 3 and world.time > 10.0:
		_bot_step = 4
		var fwd := Vector3.FORWARD if world.local_team == 0 else Vector3.BACK
		var ids := mine.keys()
		world.send_cmd({"t": "defend", "squads": ids, "pos": Vector3(0, 0, 30) * (-fwd.z), "face": fwd})
		print("BOT: defend sent")
	elif _bot_step == 4 and world.time > 16.0:
		_bot_step = 5
		var fwd2 := Vector3.FORWARD if world.local_team == 0 else Vector3.BACK
		world.send_cmd({"t": "assault", "squads": mine.keys(), "pos": fwd2 * 20.0, "face": fwd2})
		print("BOT: assault sent")
	elif _bot_step == 5 and world.time > 24.0:
		_bot_step = 6
		for s in world.soldiers:
			if s.owner_peer == world.local_peer and s.life == Soldier.Life.ALIVE:
				world.send_cmd({"t": "unit", "soldier": s.eid, "o": "move", "pos": s.position + Vector3(6, 0, 0), "face": Vector3.ZERO})
				world.send_cmd({"t": "unit", "soldier": s.eid, "o": "throw", "pos": s.position + Vector3(10, 0, -15), "kind": "smoke"})
				print("BOT: unit orders sent to ", s.sname)
				break
	elif _bot_step == 6 and world.time > 30.0:
		_bot_step = 7
		var squads_ok := 0
		for sid in mine:
			var sq = world.squads.get(sid) if world.srv else null
			if sq:
				squads_ok += 1
				print("BOT: squad %d order=%s" % [sid, sq.order])
		world.send_cmd({"t": "retreat", "squads": mine.keys()})
		print("BOT: retreat sent")


## After the build: hold the loading screen while the first frames render
## (and compile their shaders) behind it, then fade into the battlefield.
func _warm_up(cur: Curtain) -> void:
	if world.atmo:
		cur.add_line("CONDITIONS", String(Curtain.MOOD_TEXT.get(world.atmo.mood, world.atmo.mood.capitalize())))
	cur.set_stage("Deploying forces", 0.72)
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	while Engine.get_frames_drawn() < f0 + 24 or Time.get_ticks_msec() - t0 < 1100:
		if not is_instance_valid(cur):
			return
		var k := clampf(float(Engine.get_frames_drawn() - f0) / 24.0, 0.0, 1.0)
		cur.set_stage("Final checks" if k > 0.6 else "Deploying forces", 0.72 + 0.28 * k)
		await get_tree().process_frame
	if is_instance_valid(cur):
		cur.set_stage("Ready", 1.0)
		cur.finish(2.2)


func return_to_menu(msg: String) -> void:
	if _curtains:
		_intro()
	if not args.has("timescale"):
		Engine.time_scale = 1.0
	if world:
		world.name = "OldWorld"
		world.queue_free()
		world = null
	Net.leave()
	Settings.set_ui_menu(true)
	menu.show_menu(msg)


var _ms_i := -1
var _ms_t := 0.0


## --model-sheet=key1,key2,... (or a family: nato, csat, indep, civ, heli,
## plane, boat, all) --sheet-dir=DIR [--side=0|1] [--sheet-yaw=radians]:
## puts each model on the Field Manual's turntable in turn and saves the
## preview as DIR/KEY.png, then quits. For checking models as they're built.
func _model_sheet_tick() -> void:
	var spec := String(args["model-sheet"])
	var keys: Array[String] = []
	match spec:
		"nato":
			keys.assign(VmNato.KEYS)
		"csat":
			keys.assign(VmCsat.KEYS)
		"indep":
			keys.assign(VmIndep.KEYS)
		"civ":
			keys.assign(VmCiv.KEYS)
		"heli":
			keys.assign(VmHeli.KEYS)
		"plane":
			keys.assign(VmPlane.KEYS)
		"boat":
			keys.assign(VmBoat.KEYS)
		"all":
			keys = VehicleModels.family_keys()
		_:
			for k in spec.split(","):
				keys.append(k)
	var now := Time.get_ticks_msec() / 1000.0
	if _ms_i >= 0 and now < _ms_t:
		return
	if _ms_i >= 0 and _ms_i < keys.size():
		var img := get_viewport().get_texture().get_image()
		var w := img.get_width()
		var h := img.get_height()
		var r := Rect2i(int(w * 0.3425), int(h * 0.102), int(w * 0.6235), int(h * 0.467))
		img.get_region(r).save_png(String(args.get("sheet-dir", "user://")).path_join(keys[_ms_i] + ".png"))
	_ms_i += 1
	if _ms_i >= keys.size():
		get_tree().quit()
		return
	menu.manual.open("model", keys[_ms_i], int(args.get("side", 0)))
	if args.has("sheet-yaw"):
		menu.manual._yaw = float(args["sheet-yaw"])
		menu.manual._idle_t = 99.0
	_ms_t = now + 1.4


func _process(_dt: float) -> void:
	if args.has("startup-trace") and Time.get_ticks_msec() < 9000:
		print("FRAME t=%d ms frames=%d dt=%.0f ms" % [Time.get_ticks_msec(), Engine.get_frames_drawn(), _dt * 1000.0])
	if world == null:
		# --manual=category[,entry[,side]]: open the field manual on a page
		if args.has("manual") and menu and menu.manual and not has_meta("manual_open") and Time.get_ticks_msec() > 800:
			set_meta("manual_open", true)
			var mp := String(args["manual"]).split(",")
			menu.manual.open(mp[0], mp[1] if mp.size() > 1 else "", int(mp[2]) if mp.size() > 2 else -1)
		if args.has("model-sheet") and menu and menu.manual and Engine.get_frames_drawn() > 20:
			_model_sheet_tick()
		if args.has("menu-op") and menu and menu.op_panel and not has_meta("op_open") and Engine.get_frames_drawn() > 5:
			set_meta("op_open", true)
			menu._open_op(int(args["menu-op"]))
		# --menu-update=X.Y.Z[,available|downloading|ready|failed]: the update
		# notice, as if GitHub had that release (screenshots)
		if args.has("menu-update") and not has_meta("update_shown") and Engine.get_frames_drawn() > 5:
			set_meta("update_shown", true)
			var mu := String(args["menu-update"]).split(",")
			var st: int = ["available", "downloading", "ready", "failed"].find(mu[1] if mu.size() > 1 else "available") + 1
			Updater.pretend(mu[0], st)
		# --menu-panel=browse|account|record|settings: the list of online battles, the sign-in panel,
		# the service record (signed in), the settings
		if args.has("menu-panel") and menu and menu.browse_panel and not has_meta("panel_open") and Engine.get_frames_drawn() > 5:
			set_meta("panel_open", true)
			if String(args["menu-panel"]) == "account":
				menu._open_account()
			elif String(args["menu-panel"]) == "record":
				menu._open_record()
			elif String(args["menu-panel"]) == "settings":
				menu.settings_panel.visible = true
				menu.settings_panel._show_tab(String(args.get("settings-tab", "interface")))
			else:
				menu._open_browser()
		# --open-battle (with --menu-panel=record): open the newest battle's after-action report
		if args.has("open-battle") and menu and menu.rec_list and menu.rec_list.get_child_count() > 0 and not has_meta("battle_open"):
			set_meta("battle_open", true)
			(menu.rec_list.get_child(0) as Button).pressed.emit()
		# --menu-missions[=KEY]: open the Missions panel (on that mission)
		if args.has("menu-missions") and menu and menu.ms_panel and not has_meta("ms_open") and Engine.get_frames_drawn() > 5:
			set_meta("ms_open", true)
			if String(args["menu-missions"]) != "1":
				menu._ms_key = String(args["menu-missions"])
			menu._open_missions()
		# (the first frame can take seconds to arrive: count frames drawn, not time)
		if args.has("menu-shot") and Engine.get_frames_drawn() > 30 and Time.get_ticks_msec() > float(args.get("shot-at", 2.5)) * 1000.0 and not _shot_done:
			_shot_done = true
			get_viewport().get_texture().get_image().save_png(String(args["menu-shot"]))
			get_tree().quit()
		return
	# --trace=path.csv: every half second, where each man is and what he's doing
	# (for plotting squad movement and posture over a fight)
	if args.has("trace") and world.srv and world.time >= _trace_t:
		_trace_t = world.time + 0.5
		if _trace_f == null:
			_trace_f = FileAccess.open(String(args["trace"]), FileAccess.WRITE)
			_trace_f.store_line("t,eid,team,sid,x,z,yaw,life,posture,act,task,goal,cover,supp,phase,role")
			var sf := FileAccess.open(String(args["trace"]) + ".structs", FileAccess.WRITE)
			for st in world.structures:
				if not st.gone:
					sf.store_line("%s,%.2f,%.2f,%.2f,%.2f,%.2f" % [st.skind, st.position.x, st.position.z, st.yaw, st.size.x, st.size.z])
			sf.close()
		for s in world.soldiers:
			if s.gone:
				continue
			var ph := ""
			var role := ""
			if s.squad and s.squad.plan:
				var inf: Array = s.squad.plan.info()
				ph = str(inf[0])
				role = "asl"
				for el in s.squad.plan.support:
					if el.sq == s.squad:
						role = "sup"
			_trace_f.store_line("%.1f,%d,%d,%d,%.2f,%.2f,%.2f,%d,%d,%d,%s,%s,%d,%d,%s,%s" % [world.time, s.eid, s.team, s.squad.sid if s.squad else -1, s.position.x, s.position.z, s.rotation.y, s.life, s.posture, s.act, s.task, s.goal_kind, (s.cover_type if s.at_cover else -1), int(s.suppression), ph, role])
		_trace_f.flush()
	if _stats_every > 0.0 and world.srv and world.time >= _stats_t:
		_stats_t = world.time + _stats_every
		print(world.debug_stats())
	if args.has("screenshot") and not _shot_done and world.time >= float(args.get("shot-at", 8.0)) + _shot_i * float(args.get("shot-every", 0.5)):
		var path := String(args.screenshot)
		var count := int(args.get("shots", 1))
		if count > 1:
			path = path.get_basename() + "_%d.png" % _shot_i
		var img := get_viewport().get_texture().get_image()
		img.save_png(path)
		print("screenshot saved ", path)
		if args.has("dump-structs"):
			_dump_structs()
		_shot_i += 1
		# --stats-tab=all: the next shot is of the next tab
		if String(args.get("stats-tab", "")) == "all" and world.hud:
			var key: String = StatsPanel.TABS[_shot_i % StatsPanel.TABS.size()][0]
			for sp in [world.hud.stats_panel, world.hud.aar_panel]:
				if sp != null and is_instance_valid(sp) and sp.is_visible_in_tree():
					sp.show_tab(key)
		if _shot_i >= count:
			_shot_done = true
			if not args.has("quit-after"):
				get_tree().quit()
	if args.has("perf-at"):
		var pt := float(args["perf-at"])
		if world.time >= pt and Engine.time_scale != 1.0:
			Engine.time_scale = 1.0
			_perf_t0 = Time.get_ticks_msec()
			_perf_frames = Engine.get_frames_drawn()
		elif _perf_t0 > 0 and Time.get_ticks_msec() - _perf_t0 > 10000:
			var fps := float(Engine.get_frames_drawn() - _perf_frames) / ((Time.get_ticks_msec() - _perf_t0) / 1000.0)
			# report once: with the clock cleared, a failure below can't repeat
			# all of this every frame until something kills the run
			_perf_t0 = 0
			var alive := 0
			for s in world.soldiers:
				if s.life != Soldier.Life.DEAD:
					alive += 1
			print("PERF fps=%.1f server_tick_ms=%.2f entities=%d soldiers_alive=%d total_soldiers=%d vehicles=%d" % [fps, world.tick_ms, world.entities.size(), alive, world.soldiers.size(), world.vehicles.size()])
			if OS.has_environment("FL_DEBUG_NODES"):
				var counts := {}
				var owners := {}
				var stack: Array = [world]
				while not stack.is_empty():
					var n: Node = stack.pop_back()
					var cls := n.get_class()
					if n is VisualInstance3D and (n as VisualInstance3D).is_visible_in_tree():
						counts[cls] = int(counts.get(cls, 0)) + 1
						# who owns it: the nearest ancestor with a script
						var o: Node = n.get_parent()
						while o and o.get_script() == null:
							o = o.get_parent()
						var on := (o.get_script() as Script).resource_path.get_file() if o else "?"
						owners[on] = int(owners.get(on, 0)) + 1
					for c in n.get_children():
						stack.append(c)
				print("VISIBLE INSTANCES ", counts)
				var dead_mi := 0
				var dead_n := 0
				var baked := 0
				for so in world.soldiers:
					if so.life == Soldier.Life.DEAD and so.model:
						dead_n += 1
						if so.model._baked:
							baked += 1
						var st2: Array = [so.model]
						while not st2.is_empty():
							var nn: Node = st2.pop_back()
							if nn is MeshInstance3D and (nn as MeshInstance3D).is_visible_in_tree():
								dead_mi += 1
							for cc in nn.get_children():
								st2.append(cc)
				print("CORPSES n=%d baked=%d meshes=%d" % [dead_n, baked, dead_mi])
				var why := {}
				for so in world.soldiers:
					if so.life == Soldier.Life.DEAD and so.model and not so.model._baked:
						var k := "act=%s rag=%s done=%s vis=%s still=%d" % [Soldier.Act.keys()[so.act], str(so.model.ragdoll != null), str(so.model.ragdoll_done), str(so.visible), so.model._still]
						why[k] = int(why.get(k, 0)) + 1
				print("UNBAKED ", why)
				print("BY OWNER ", owners)
			# a headless run draws nothing, so there's no picture to keep (asking
			# for one only gets an error), just the numbers above
			var img: Image = get_viewport().get_texture().get_image() if DisplayServer.get_name() != "headless" else null
			if img:
				img.save_png(String(args.get("perf-shot", "user://perf.png")))
			get_tree().quit()
	if args.has("fx-demo"):
		_fx_demo()
	if args.has("shot-demo"):
		_shot_demo()
	if args.has("open-settings") and world.hud and world.time > 1.0 and not world.hud.settings_panel.visible and not has_meta("opened"):
		set_meta("opened", true)
		world.hud.settings_panel.visible = true
	if args.has("smoke-demo") and world.srv and world.time > 1.0 and not has_meta("smoked"):
		set_meta("smoked", true)
		var c := world.cam.focus_pos if world.cam else Vector3.ZERO
		world.spawn("projectile", {"ptype": "smoke", "team": 0, "pos": c + Vector3(4, 0.2, 0), "vel": Vector3.ZERO, "thrower": 0, "fuse": 0.0})
	if args.has("model-test") and world.cam and not has_meta("modeled"):
		set_meta("modeled", true)
		var x := -12.0
		for mk in String(args["model-test"]).split(","):
			var vm := VehicleModels.build(mk, 0, 7)
			world.add_child(vm.root)
			vm.root.position = world.cam.focus_pos + Vector3(x, float(args.get("model-y", 1.5)), 0)
			x += 24.0
	if args.has("demo-support") and world.srv and world.cam and world.time > float(args.get("demo-at", 2.0)) and not has_meta("demoed"):
		set_meta("demoed", true)
		var ddir := Defs.flat(world.cam.cam.global_transform.basis.x).normalized()
		world.rules.demo_support(String(args["demo-support"]), world.cam.focus_pos, ddir)
	if args.has("bot-cmds"):
		_bot_cmds()
	if args.has("bot-defense"):
		_bot_defense()
	if args.has("cursor") and world.input:
		var cv := String(args.cursor).split(",")
		var vsz := get_viewport().get_visible_rect().size
		world.input.debug_mouse = Vector2(float(cv[0]) * vsz.x, float(cv[1]) * vsz.y)
		if args.has("order-mode"):
			world.input.order_mode = String(args["order-mode"])
		# --ping-wheel: hold the ping wheel open, the cursor on one of its spokes
		if args.has("ping-wheel") and not world.input.pinging:
			world.input.pinging = true
			world.input.ping_at = world.input.debug_mouse + Vector2(-48, 46)
			world.input._ping_ms = 0
		# --place=trench [--place-from=x,z]: preview building (a line) at the cursor
		if args.has("place") and world.input.place_kind == "" and not world.input.sel_squads.is_empty():
			world.input.start_place(String(args.place))
			if args.has("place-from"):
				var pf := String(args["place-from"]).split(",")
				world.input.place_a = TrenchNet.snap_pos(Vector3(float(pf[0]), 0, float(pf[1])))
				world.input.place_drag = true
	# --blast-at=x,z,size,time: a real explosion there (physics / ragdoll tests);
	# x,z of "f,dx" means dx metres beside the camera's focus, "v:kind,dx" beside
	# the first vehicle of that kind (sinking a boat on a headless host)
	if args.has("blast-at") and world.srv and not has_meta("blasted"):
		var ba := String(args["blast-at"]).split(",")
		if world.time >= float(ba[3]):
			set_meta("blasted", true)
			var bsz := float(ba[2])
			var bp := Vector3(float(ba[0]), 0.3, float(ba[1]))
			if ba[0] == "f" and world.cam:
				bp = world.cam.focus_pos + Vector3(float(ba[1]), 0.3, 0)
			elif ba[0].begins_with("v:"):
				for v in world.vehicles:
					if v.vkind == ba[0].substr(2):
						bp = Vector3(v.position.x + float(ba[1]), 0.3, v.position.z)
						break
			world.combat.explode(bp, {"dmg": 160.0 * bsz, "radius": 4.0 + bsz * 3.0, "fling": 8.0 + bsz * 4.0, "at": 300.0, "top": true, "src": null, "team": -1, "size": bsz})
	# --focus-town[=dx,dz]: the camera on the middle of town (offset in metres)
	if args.has("focus-town") and world.cam and world.time > 1.0 and not world.has_meta("town_focused") and world.town_rect.size.x > 0.0:
		var off := Vector3.ZERO
		if String(args["focus-town"]).contains(","):
			var ft := String(args["focus-town"]).split(",")
			off = Vector3(float(ft[0]), 0, float(ft[1]))
		var tc := world.town_rect.get_center()
		world.cam.focus(Vector3(tc.x, 0, tc.y) + off)
		world.focused = true
		if world.director:
			world.director.active = false
		world.set_meta("town_focused", true)
	# --focus-struct=kind[,n]: the camera on the nth structure of a kind (--select-struct: selected too)
	if args.has("focus-struct") and world.cam and world.time > 1.0 and not world.has_meta("struct_focused"):
		var fs := String(args["focus-struct"]).split(",")
		var want2 := int(fs[1]) if fs.size() > 1 else 0
		for st in world.structures:
			if st.skind == fs[0]:
				if want2 == 0:
					world.cam.focus(st.position)
					world.focused = true
					if world.director:
						world.director.active = false
					if args.has("select-struct") and world.input:
						world.input.sel_structure = st.eid
					break
				want2 -= 1
		world.set_meta("struct_focused", true)
	# --focus-vehicle=kind: the camera on the first vehicle of a kind (and with
	# it while it lives: a boat sinking, a convoy on the road)
	if args.has("focus-vehicle") and world.cam and world.time > 1.0 and not world.has_meta("veh_focused"):
		for v in world.vehicles:
			if v.vkind == String(args["focus-vehicle"]):
				world.cam.focus(v.position)
				world.focused = true
				if world.director:
					world.director.active = false
				world.set_meta("veh_focused", true)
				break
	# --focus-decor=kind[,n]: the camera on the nth piece of street furniture of a kind
	if args.has("focus-decor") and world.cam and world.time > 1.0 and not world.has_meta("decor_focused") and not world.decor.is_empty():
		var fd := String(args["focus-decor"]).split(",")
		var want := int(fd[1]) if fd.size() > 1 else 0
		for e in world.decor:
			if String(e[0]) == fd[0]:
				if want == 0:
					world.cam.focus(e[1])
					world.focused = true
					if world.director:
						world.director.active = false
					break
				want -= 1
		world.set_meta("decor_focused", true)
	# --manual=category[,entry[,side]] in a battle: the field manual open on that page
	if args.has("manual") and world.hud and world.hud.manual and world.time > 1.0 and not has_meta("manual_open_battle"):
		set_meta("manual_open_battle", true)
		var mq := String(args["manual"]).split(",")
		world.hud.manual.open(mq[0], mq[1] if mq.size() > 1 else "", int(mq[2]) if mq.size() > 2 else -1)
	# --test-fire: every armed man (and every gunner on a gun) fires straight
	# ahead a few times a second through the real firing path (muzzle tests);
	# --test-fire=ground puts the rounds into the ground 25 m out (impacts);
	# --test-fire-every=0.3 fires that often instead
	if args.has("test-fire") and world.srv and world.time > 2.0 and world.time >= _tf_t:
		_tf_t = world.time + float(args.get("test-fire-every", 0.09))
		var tf_drop := 2.4 if String(args["test-fire"]) == "ground" else 0.0
		for s in world.soldiers:
			if s.life != Soldier.Life.ALIVE or s.cur_weapon().is_empty():
				continue
			s.mag = maxi(s.mag, 5)
			s._shoot(s.eye_pos() + Defs.dir_of(s.rotation.y) * 40.0 + Vector3(0, -tf_drop, 0), null, false, false)
		for v in world.vehicles:
			var vmg: String = v.vdef.get("mg", "")
			if v.gone or vmg == "":
				continue
			var vd := Defs.dir_of(v.rotation.y + v.turret_yaw)
			world.combat.fire_bullet(v, v.turret_pos() + vd * 1.5, v.turret_pos() + vd * 40.0, null, Defs.WEAPONS[vmg], 1.0)
	# --pan=vx,vz: drift the camera (metres per second) - shimmer tests
	if args.has("pan") and world.cam and world.time > 1.5:
		var pv := String(args["pan"]).split(",")
		world.cam.focus(world.cam.focus_pos + Vector3(float(pv[0]), 0, float(pv[1])) * get_process_delta_time())
	# --follow=team[,n]: keep the camera on that side's nth infantry squad (tactics review)
	if args.has("follow") and world.cam and world.time > 0.5:
		var fw := String(args["follow"]).split(",")
		var want3 := int(fw[1]) if fw.size() > 1 else 0
		var sids := world.squads.keys()
		sids.sort()
		for sid in sids:
			var sq = world.squads[sid]
			if sq.team != int(fw[0]) or sq.members.is_empty():
				continue
			if want3 > 0:
				want3 -= 1
				continue
			var c := Vector3.ZERO
			var n := 0
			for m in sq.members:
				if is_instance_valid(m) and m.life == Soldier.Life.ALIVE:
					c += m.position
					n += 1
			if n > 0:
				world.cam.focus(world.cam.focus_pos.lerp(c / n, 0.08) if world.time > 1.0 else c / n)
				world.focused = true
				if world.director:
					world.director.active = false
			break
	# --focus-fob=team: keep the camera on that side's first FOB (base screenshots)
	if args.has("focus-fob") and world.cam and world.time > 1.0 and not world.has_meta("fob_focused"):
		for st in world.structures:
			if st.skind == "fob" and st.team == int(args["focus-fob"]):
				world.cam.focus(st.position + Vector3(0, 0, -8.0 if st.team == 0 else 8.0))
				world.focused = true
				if world.director:
					world.director.active = false
				world.set_meta("fob_focused", true)
				break
	# --select-first: just the first of your squads (squad card tests); --tactical: the map view
	if args.has("select-first") and world.input and world.time > 1.0 and world.input.sel_squads.is_empty():
		for s in world.soldiers:
			if s.owner_peer == world.local_peer and s.sid != 0:
				world.input.sel_squads.append(s.sid)
				break
	if args.has("nohud") and world.hud and world.hud.root.visible:
		world.hud.root.visible = false
	if args.has("tactical") and world.hud and not world.hud.tactical and not has_meta("tac"):
		set_meta("tac", true)
		world.hud.toggle_tactical()
	# --coop-watch[=N]: watch the Nth --coop-demo commander's view live
	if args.has("coop-watch") and world.cam and world.time > 1.0 and not has_meta("coop_watched"):
		var wid := 9001 + int(args["coop-watch"])
		if world.coop.peers.has(wid):
			set_meta("coop_watched", true)
			world.cam.toggle_shadow(wid)
	# --hud-panel=settings|help|menu|log: open one of the battle's panels (layout checks)
	if args.has("hud-panel") and world.hud and world.time > 1.0 and not has_meta("hud_panel"):
		set_meta("hud_panel", true)
		var hp: Control = {"settings": world.hud.settings_panel, "help": world.hud.help_panel, "menu": world.hud.menu_panel, "log": world.hud.log_panel}.get(String(args["hud-panel"]))
		if hp:
			hp.visible = true
			if hp is SettingsPanel:
				(hp as SettingsPanel)._show_tab(String(args.get("settings-tab", "interface")))
	if args.has("select-all") and world.input and world.time > float(args.get("shot-at", 8.0)) - 1.5 and world.input.sel_squads.is_empty():
		for s in world.soldiers:
			if s.owner_peer == world.local_peer and s.sid != 0 and not s.sid in world.input.sel_squads:
				world.input.sel_squads.append(s.sid)
		for v in world.vehicles:
			if v.owner_peer == world.local_peer and not v.eid in world.input.sel_vehicles:
				world.input.sel_vehicles.append(v.eid)
	# --report-at=SECONDS: ask the host for the battle statistics then (a client's view of them)
	if args.has("report-at") and not has_meta("report_asked") and world.time >= float(args["report-at"]):
		set_meta("report_asked", true)
		world.request_report()
	# --end-at=SECONDS: call the battle there (for the side ahead on what it has
	# destroyed), back at normal speed; --stats-tab=summary|commanders|units|timeline opens the
	# battle statistics a second before the screenshot (after-action report tests)
	if args.has("end-at") and world.srv and world.winner < 0 and world.time >= float(args["end-at"]):
		var sd: Array = world.battle.sides
		world.declare_winner(0 if float(sd[0].val_killed) >= float(sd[1].val_killed) else 1)
		Engine.time_scale = 1.0  # the end screens run in real time: shoot them at a real pace
	if args.has("stats-tab") and world.hud and world.winner < 0 and not has_meta("stats_open") and world.time > float(args.get("shot-at", 8.0)) - 1.0:
		set_meta("stats_open", true)
		world.hud.open_stats(String(args["stats-tab"]))
	if args.has("stats-tab") and world.hud and world.winner >= 0 and not has_meta("aar_tab") and world.hud.aar_panel != null:
		set_meta("aar_tab", true)
		world.hud.aar_panel.show_tab(String(args["stats-tab"]))
	# a client's --quit-after counts from when the host's world reached it: the
	# host only answers once it has laid out the map (and, with a window, drawn
	# its first frame - a minute or more off-screen), and a client counting from
	# its own empty world can give up before it has been sent anything
	if not world.srv and not world.has_meta("world_at") and not world.entities.is_empty():
		world.set_meta("world_at", world.time)
	var run_t := world.time
	if not world.srv:
		run_t = world.time - float(world.get_meta("world_at", CLIENT_WAIT))
	if _quit_at > 0.0 and run_t >= _quit_at:
		_quit_at = -1.0
		if args.has("dump-structs"):
			_dump_structs()
		if world.srv:
			print("FINAL ", world.debug_stats())
			print("REPORT ", world.battle.summary())
		else:
			var counts := {}
			var enemy := 0
			for e in world.entities.values():
				counts[e.ekind()] = int(counts.get(e.ekind(), 0)) + 1
				if e.team >= 0 and e.team != world.local_team:
					enemy += 1
			counts["ENEMY_KNOWN"] = enemy
			print("CLIENT entities=%d %s time=%.1f team_info=%s waited=%.1f" % [world.entities.size(), str(counts), world.time, str(world.team_info[0].get("supply", -1)), float(world.get_meta("world_at", -1.0))])
		if not world.coop.peers.is_empty() or int(world.coop.stats.get("sent", 0)) > 0:
			print("COOP ", world.coop.summary())
		if not Engine.get_write_movie_path().is_empty():
			# Movie audio needs a final mix after playback stops to release its stream references.
			get_tree().paused = true
			Music.set_process(false)
			Sfx.enabled = false
			for type in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
				for player in get_tree().root.find_children("*", type, true, false):
					player.stop()
					player.stream = null
			await get_tree().process_frame
			await get_tree().process_frame
		get_tree().quit()
