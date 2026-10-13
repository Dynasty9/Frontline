extends Node
## Root: owns the menu and the World. Also understands a few command-line
## switches (after `--`) used for automated testing:
##   --aivai               host as spectator, both sides AI
##   --host [--players=N]  host and start (when N players have joined)
##   --join=IP             join a host
##   --team=N              team to request after joining (-1 spectator)
##   --timescale=X --quit-after=SECONDS --stats=SECONDS --verbose
##   --screenshot=PATH --shot-at=SECONDS --focus=X,Z --zoom=D

var menu: Control
var world: World
var args := {}
var _quit_at := -1.0
var _stats_every := 0.0
var _stats_t := 0.0
var _shot_done := false
var _shot_i := 0
var _perf_t0 := 0
var _perf_frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--"):
			var kv := s.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	add_child(preload("res://scripts/ui/perf_overlay.gd").new())
	menu = preload("res://scripts/ui/menu.gd").new()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	layer.add_child(menu)
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
		Engine.physics_ticks_per_second = 30
		Engine.max_physics_steps_per_frame = 16
	if args.has("quit-after"):
		_quit_at = float(args["quit-after"])
	if args.has("stats"):
		_stats_every = float(args.stats)
	var port := int(args.get("port", Net.DEFAULT_PORT))
	if args.has("scenario"):
		# --play: command the Coalition side yourself instead of watching
		Net.host_game(port, 0 if args.has("play") else -1)
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
	elif args.has("host"):
		Net.host_game(port, int(args.get("team", 0)))
		Net.set_setting("ai_allies", args.has("ai-allies"))
		Net.set_setting("verbose", args.has("verbose"))
		Net.set_setting("debug_trucks", args.has("debug-trucks"))
		if not args.has("players"):
			Net.start_game()
		else:
			Net.lobby_updated.connect(_maybe_autostart)
	elif args.has("join"):
		Net.join_game(String(args.join), port)
		if args.has("team"):
			multiplayer.connected_to_server.connect(func(): await get_tree().create_timer(0.3).timeout; Net.request_team.rpc_id(1, int(args.team)))


func _dump_structs() -> void:
	for st in world.structures:
		if not st.skind in ["floor", "tree"]:
			print("STRUCT %s t%d pos=%s yaw=%.2f size=%s built=%s wrecked=%s" % [st.skind, st.team, str(st.position.snapped(Vector3.ONE * 0.1)), st.yaw, str(st.size), str(st.built), str(st.wrecked)])


func _maybe_autostart() -> void:
	if not Net.in_game and Net.players.size() >= int(args.get("players", 2)):
		await get_tree().create_timer(1.0).timeout
		if not Net.in_game:
			Net.start_game()


func _on_game_start(s: Dictionary) -> void:
	menu.visible = false
	if world:
		world.name = "OldWorld"
		world.queue_free()
	world = World.new()
	world.name = "World"
	world.settings = s
	add_child(world)
	world.game_ended.connect(_on_game_ended)
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


var _fx_next := 2.0
var _trace_t := 0.0
var _trace_f: FileAccess = null
var _fx_i := 0


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


func return_to_menu(msg: String) -> void:
	if not args.has("timescale"):
		Engine.time_scale = 1.0
	if world:
		world.name = "OldWorld"
		world.queue_free()
		world = null
	Net.leave()
	menu.show_menu(msg)


func _process(_dt: float) -> void:
	if world == null:
		# --manual=category[,entry[,side]]: open the field manual on a page
		if args.has("manual") and menu and menu.manual and not has_meta("manual_open") and Time.get_ticks_msec() > 800:
			set_meta("manual_open", true)
			var mp := String(args["manual"]).split(",")
			menu.manual.open(mp[0], mp[1] if mp.size() > 1 else "", int(mp[2]) if mp.size() > 2 else -1)
		if args.has("menu-shot") and Time.get_ticks_msec() > float(args.get("shot-at", 2.5)) * 1000.0 and not _shot_done:
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
			get_viewport().get_texture().get_image().save_png(String(args.get("perf-shot", "user://perf.png")))
			get_tree().quit()
	if args.has("fx-demo"):
		_fx_demo()
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
		# --place=trench [--place-from=x,z]: preview building (a line) at the cursor
		if args.has("place") and world.input.place_kind == "" and not world.input.sel_squads.is_empty():
			world.input.start_place(String(args.place))
			if args.has("place-from"):
				var pf := String(args["place-from"]).split(",")
				world.input.place_a = TrenchNet.snap_pos(Vector3(float(pf[0]), 0, float(pf[1])))
				world.input.place_drag = true
	# --blast-at=x,z,size,time: a real explosion there (physics / ragdoll tests);
	# x,z of "f,dx" means dx metres beside the camera's focus
	if args.has("blast-at") and world.srv and not has_meta("blasted"):
		var ba := String(args["blast-at"]).split(",")
		if world.time >= float(ba[3]):
			set_meta("blasted", true)
			var bsz := float(ba[2])
			var bp := Vector3(float(ba[0]), 0.3, float(ba[1]))
			if ba[0] == "f" and world.cam:
				bp = world.cam.focus_pos + Vector3(float(ba[1]), 0.3, 0)
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
	# --focus-struct=kind[,n]: the camera on the nth structure of a kind
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
					break
				want2 -= 1
		world.set_meta("struct_focused", true)
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
	if args.has("manual") and world.hud and world.hud.manual and world.time > 1.0 and not has_meta("manual_open"):
		set_meta("manual_open", true)
		var mq := String(args["manual"]).split(",")
		world.hud.manual.open(mq[0], mq[1] if mq.size() > 1 else "", int(mq[2]) if mq.size() > 2 else -1)
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
	if args.has("select-all") and world.input and world.time > float(args.get("shot-at", 8.0)) - 1.5 and world.input.sel_squads.is_empty():
		for s in world.soldiers:
			if s.owner_peer == world.local_peer and s.sid != 0 and not s.sid in world.input.sel_squads:
				world.input.sel_squads.append(s.sid)
		for v in world.vehicles:
			if v.owner_peer == world.local_peer and not v.eid in world.input.sel_vehicles:
				world.input.sel_vehicles.append(v.eid)
	if _quit_at > 0.0 and world.time >= _quit_at:
		_quit_at = -1.0
		if args.has("dump-structs"):
			_dump_structs()
		if world.srv:
			print("FINAL ", world.debug_stats())
		else:
			var counts := {}
			var enemy := 0
			for e in world.entities.values():
				counts[e.ekind()] = int(counts.get(e.ekind(), 0)) + 1
				if e.team >= 0 and e.team != world.local_team:
					enemy += 1
			counts["ENEMY_KNOWN"] = enemy
			print("CLIENT entities=%d %s time=%.1f team_info=%s" % [world.entities.size(), str(counts), world.time, str(world.team_info[0].get("supply", -1))])
		get_tree().quit()
