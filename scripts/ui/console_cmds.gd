class_name ConsoleCmds
extends RefCounted
## The console's commands: each is a row in LIST and a c_<name>(args) below.
## Most of them answer "why is the game slow?": what each frame's time goes on
## (PerfProbe measures it), the stutters, the renderer, this computer, and a
## benchmark that tries each graphics setting off in turn and times it.
## The console is up from the launch, before the game's classes have compiled
## (GameScripts), so the battle is untyped here and none of them is named.

## [name, arguments, what it does]
const LIST := [
	["help", "[command]", "Lists the commands, or explains one."],
	["why", "", "Works out what's slowing the game down, from the last few seconds."],
	["bench", "[quick | stop]", "Turns each graphics setting down in turn and measures what it saves (about a minute; keep the camera still)."],
	["graph", "", "A panel graphing every frame of the last ten seconds, split into what the time went on, stutters marked."],
	["perf", "[0-3]", "The performance overlay: off, FPS, compact, full breakdown (F3 cycles it)."],
	["fps", "", "Shows or hides the frame-rate counter."],
	["top", "", "The costliest parts of the game: logic per tick and view scripts per frame, on average and at worst."],
	["hitches", "[clear | auto | MS]", "The latest stutters and what each one was (MS: count frames over that many ms)."],
	["render", "", "What's being drawn: draw calls for the scene, the shadows and the interface, objects, triangles, memory."],
	["sys", "", "This computer and how the game runs on it: graphics card, driver, CPU, memory, screen, renderer, caps."],
	["net", "", "The connection: round trip, packet loss, data in and out."],
	["errors", "", "Engine errors and warnings logged since the game started, by kind (a flood of them slows the game)."],
	["pause", "", "Pauses or resumes the battle (on your own): if the frame rate jumps, the game logic was the cost."],
	["draw", "[VIEW]", "Debug views: normal, overdraw (where see-through effects pile up), wireframe, unshaded, lighting, normals, shadows, ssao."],
	["set", "SETTING VALUE", "Changes a setting now, as Settings would (set shadows off, set grass 0, set scale 0.77)."],
	["settings", "[filter]", "The settings and their values."],
	["preset", "low | medium | high | ultra", "Applies a graphics preset."],
	["report", "", "Writes all of the above to a file and copies it to the clipboard, to share."],
	["clear", "", "Clears the console."],
	["close", "", "Closes the console (so do Esc and the console key)."],
]
const ALIASES := {"?": "help", "cls": "clear", "diag": "why", "diagnose": "why", "lag": "why", "exit": "close", "benchmark": "bench"}

## The benchmark's steps: [setting, the value it's tried at, what that is].
## Settings already there are skipped.
const BENCH := [
	["shadows", 0, "Shadows off"],
	["ssao", false, "Ambient occlusion off"],
	["ssil", false, "Indirect light (SSIL) off"],
	["gi", false, "Global illumination off"],
	["vol_fog", false, "Volumetric fog off"],
	["ssr", false, "Reflections off"],
	["glow", false, "Glow off"],
	["aa", 0, "Anti-aliasing off"],
	["dof", false, "Depth of field off"],
	["post", false, "Post-processing off"],
	["grass", 0, "Grass off"],
	["water", 0, "Water on Low"],
	["effects", 0, "Effects on Low"],
	["wildlife", 0, "Wildlife off"],
	["lod", 0, "Detail distance Near"],
	["aniso", 0, "Texture filtering off"],
	["scale", 0.5, "Render scale 50%"],
]

const DRAWS := {"normal": Viewport.DEBUG_DRAW_DISABLED, "overdraw": Viewport.DEBUG_DRAW_OVERDRAW, "wireframe": Viewport.DEBUG_DRAW_WIREFRAME,
	"unshaded": Viewport.DEBUG_DRAW_UNSHADED, "lighting": Viewport.DEBUG_DRAW_LIGHTING, "normals": Viewport.DEBUG_DRAW_NORMAL_BUFFER,
	"shadows": Viewport.DEBUG_DRAW_DIRECTIONAL_SHADOW_ATLAS, "ssao": Viewport.DEBUG_DRAW_SSAO}

const REPORT_PATH := "user://perf_report.txt"

var con: Console
var _bench := {}  # the benchmark under way
var _bench_last: Array = []  # the last one's results, for the report


func _init(c: Console) -> void:
	con = c


# --- running a line ----------------------------------------------------------------------------

func names() -> Array:
	var out := []
	for c in LIST:
		out.append(c[0])
	return out


## The command's row in LIST ([] if there's none by that name).
func find(name: String) -> Array:
	var n := String(ALIASES.get(name, name))
	for c in LIST:
		if c[0] == n:
			return c
	return []


func run(line: String) -> void:
	var parts := line.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	var c := find(parts[0].to_lower())
	if c.is_empty():
		con.bad("No command \"%s\". Type help for the list." % parts[0])
		return
	call("c_" + String(c[0]), parts.slice(1))


## What the next word of a command's arguments could be, for Tab.
func complete(cmd: String, args: PackedStringArray) -> Array:
	var c := find(cmd)
	if c.is_empty():
		return []
	match String(c[0]):
		"help":
			return names() if args.is_empty() else []
		"perf":
			return ["0", "1", "2", "3"]
		"bench":
			return ["quick", "stop"]
		"hitches":
			return ["clear", "auto"]
		"draw":
			return DRAWS.keys()
		"preset":
			return ["low", "medium", "high", "ultra"]
		"set", "settings":
			if args.is_empty():
				var keys := Settings.v.keys()
				keys.sort()
				return keys
			if String(c[0]) == "set" and args.size() == 1:
				return _values_of(args[0])
	return []


# --- help ---------------------------------------------------------------------------------------

func c_help(a: PackedStringArray) -> void:
	if not a.is_empty():
		var c := find(a[0].to_lower())
		if c.is_empty():
			con.bad("No command \"%s\"." % a[0])
			return
		con.head("%s %s" % [c[0], c[1]])
		con.out("  " + String(c[2]))
		return
	con.head("Commands (Tab completes; help COMMAND for one):")
	for c in LIST:
		con.out("  %s %s" % [(String(c[0]) + " " + String(c[1])).rpad(34), c[2]])
	con.dim("Lag? Start with why. Then bench measures each graphics setting, graph shows every frame, hitches lists the stutters.")


func c_clear(_a: PackedStringArray) -> void:
	con.clear()


func c_close(_a: PackedStringArray) -> void:
	con.close()


# --- panels ----------------------------------------------------------------------------------

func c_perf(a: PackedStringArray) -> void:
	var lvl := (int(Settings.get_v("perf")) + 1) % 4 if a.is_empty() else clampi(a[0].to_int(), 0, 3)
	Settings.set_v("perf", lvl)
	con.out("Performance overlay: %s." % Settings.LABELS.perf[lvl])


func c_fps(_a: PackedStringArray) -> void:
	var on := int(Settings.get_v("perf")) == 0
	Settings.set_v("perf", 1 if on else 0)
	con.out("Frame-rate counter %s." % ("on" if on else "off"))


func c_graph(_a: PackedStringArray) -> void:
	con.graph.visible = not con.graph.visible
	con.probe.detail = true
	if con.graph.visible:
		con.out("Frame graph on: each column is a frame, stacked by what its time went on; red marks a stutter. graph again hides it.")
	else:
		con.out("Frame graph off.")


# --- why ----------------------------------------------------------------------------------------

func c_why(_a: PackedStringArray) -> void:
	var p := con.probe
	var r := p.recent(5.0)
	if int(r.frames) < 20:
		con.warn("Not enough frames measured yet: try again in a few seconds.")
		return
	var w := p.world()
	var ms: float = r.ms
	var fps := 1000.0 / maxf(0.01, ms)
	var sim: float = r.sim
	var view: float = r.view
	var rcpu: float = r.rcpu
	var gpu: float = r.gpu
	var cpu := sim + view + rcpu
	var rest := maxf(0.0, ms - cpu)
	con.head("The last %.0f seconds: %.0f FPS on average (%.1f ms a frame), 1%% low %.0f FPS, the worst frame %.0f ms." % [ms * float(r.frames) / 1000.0, fps, ms, r.low1, r.worst])
	con.out("  Each frame: game logic %.1f ms, view scripts %.1f ms, the renderer %.1f ms, the rest %.1f ms (engine, waiting on the GPU or the screen). GPU %s." % [sim, view, rcpu, rest, ("%.1f ms" % gpu) if p.measuring else "not measured"])
	var refresh := DisplayServer.screen_get_refresh_rate() if DisplayServer.get_name() != "headless" else -1.0
	var vsync := bool(Settings.get_v("vsync"))
	var capped := false
	if Engine.max_fps > 0 and fps >= Engine.max_fps * 0.93:
		capped = true
		con.good("- Held at %d FPS by the frame rate limit in Settings (set fps_cap 0 lifts it)." % Engine.max_fps)
	elif vsync and refresh > 0.0 and absf(fps - refresh) < refresh * 0.06:
		capped = true
		con.good("- Held at your screen's %.0f Hz by vsync: the most it can show. Any lag you feel is stutters or the network (below)." % refresh)
	elif vsync and refresh > 0.0 and absf(fps - refresh * 0.5) < refresh * 0.04:
		con.warn("- Vsync halves the frame rate when a frame misses the screen's refresh (%.0f Hz down to %.0f): set vsync off and it would run at whatever the frames take." % [refresh, fps])
	# what holds it back
	if not capped:
		if p.measuring and gpu > cpu and gpu > ms * 0.7:
			var vs := _win_px()
			var sc := float(Settings.get_v("scale"))
			con.bad("- The graphics card is the limit: %.1f ms to draw each frame. Lower graphics settings help; bench measures which saves the most." % gpu)
			con.out("  It draws %d x %d pixels (the window at %d%% render scale)%s." % [vs.x * sc, vs.y * sc, roundi(sc * 100.0), "; set scale 0.77 renders fewer and scales up" if sc > 0.8 else ""])
		else:
			var parts := [["game logic", sim], ["view scripts", view], ["the renderer (CPU)", rcpu], ["the rest", rest]]
			parts.sort_custom(func(x, y): return float(x[1]) > float(y[1]))
			var top: String = parts[0][0]
			con.bad("- The processor is the limit, and the biggest share of it is %s: %.1f ms of each %.1f ms frame." % [top, parts[0][1], ms])
			match top:
				"game logic":
					con.out("  " + _sim_line(w, r))
				"view scripts":
					con.out("  Most of it: %s." % _top_text(p.view_avg, 4))
				"the renderer (CPU)":
					con.out("  %d draw calls, %d of them for shadows. Shadows, grass and effects multiply them (render has the detail)." % [_draws(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE) + _draws(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW) + _draws(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS), _draws(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW)])
				_:
					con.out("  Time outside the game's own measures: the engine's physics and animation, the driver, or waiting for the GPU. bench shows whether the graphics settings move it.")
	# the battle's simulation, which has to keep up with the clock
	if w and w.srv:
		var share: float = w.tick_ms * Engine.physics_ticks_per_second / 1000.0
		if share > 0.9:
			con.bad("- The battle's simulation can't keep up: %.1f ms a tick, %d ticks a second, %.0f%% of real time. The game slows and stutters to catch up." % [w.tick_ms, Engine.physics_ticks_per_second, share * 100.0])
		elif share > 0.4:
			con.warn("- The battle's simulation takes %.0f%% of real time (%.1f ms a tick): %s." % [share * 100.0, w.tick_ms, _top_text(_no_total(w.prof), 3)])
		if float(r.ticks) > 1.5:
			con.warn("- %.1f simulation ticks a frame: each frame catches up on more than one tick, which makes frames uneven." % r.ticks)
	# stutters
	var recent := []
	var now := Time.get_ticks_msec()
	for h in p.hitches:
		if now - int(h.at) < 60000:
			recent.append(h)
	if not recent.is_empty():
		var worst := 0.0
		var kinds := {}
		for h in recent:
			worst = maxf(worst, float(h.ms))
			var k := _hitch_kind(h)
			kinds[k] = int(kinds.get(k, 0)) + 1
		var ks := kinds.keys()
		ks.sort_custom(func(x, y): return int(kinds[x]) > int(kinds[y]))
		var txt := []
		for k in ks:
			txt.append("%d %s" % [kinds[k], k])
		con.warn("- %d stutter%s in the last minute (the worst %.0f ms): %s. hitches lists each one." % [recent.size(), "" if recent.size() == 1 else "s", worst, ", ".join(txt)])
	if p.err_rate >= 1.0:
		con.bad("- The engine is logging %.0f errors and warnings a second, and each one is slow to write. errors lists them." % p.err_rate)
	if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		con.warn("- Drawing on an integrated graphics chip (%s). If this computer has a separate graphics card, set Frontline to use it (Windows: Settings > Display > Graphics)." % RenderingServer.get_video_adapter_name())
	if Engine.time_scale > 1.01:
		con.warn("- The battle is running at %.1fx speed: every frame simulates more." % Engine.time_scale)
	var nl := _net_line()
	if nl != "":
		con.out("- " + nl)
	con.dim("bench measures each graphics setting (about a minute), graph shows every frame, top the costliest parts, report writes it all to a file.")


func _sim_line(w: Node3D, r: Dictionary) -> String:
	if w == null:
		return "No battle running."
	if not w.srv:
		return "(The host runs the battle; this is your copy following it.)"
	return "%.1f ms a tick at %d ticks a second, %.1f ticks a frame. Most of it: %s. %s" % [w.tick_ms, Engine.physics_ticks_per_second, r.ticks, _top_text(_no_total(w.prof), 4), _units(w)]


func _units(w: Node3D) -> String:
	var alive := 0
	for s in w.soldiers:
		if s.life == s.Life.ALIVE:
			alive += 1
	return "(%d soldiers alive, %d vehicles, %d projectiles in flight.)" % [alive, w.vehicles.size(), w.projectiles.size()]


static func _no_total(d: Dictionary) -> Dictionary:
	var o := d.duplicate()
	o.erase("TOTAL")
	return o


## "fx 3.1 ms, soldiers 2.0 ms" from {name: ms}, the biggest first.
static func _top_text(d: Dictionary, n: int) -> String:
	var ks := d.keys()
	ks.sort_custom(func(x, y): return float(d[x]) > float(d[y]))
	var out := []
	for k in ks.slice(0, n):
		out.append("%s %.1f ms" % [k, d[k]])
	return ", ".join(out) if not out.is_empty() else "nothing measured"


static func _hitch_kind(h: Dictionary) -> String:
	var c := String(h.cause)
	if c.begins_with("game logic"):
		return "in the game logic"
	if c.begins_with("view scripts"):
		return "in the view scripts"
	if "shader compile" in c:
		return "compiling shaders"
	if "engine error" in c:
		return "with engine errors"
	if c.begins_with("GPU"):
		return "on the GPU"
	return "outside the game's scripts"


# --- top, hitches, render, errors ---------------------------------------------------------------

func c_top(_a: PackedStringArray) -> void:
	var p := con.probe
	var w := p.world()
	var worst := (" and the worst in the last %.0f s" % PerfProbe.PEAK_S) if not p.view_peaks.is_empty() else ""
	if w and w.srv:
		con.head("Game logic, ms per tick, on average%s (%d ticks a second: %.1f ms would be all of it)" % [worst, Engine.physics_ticks_per_second, 1000.0 / Engine.physics_ticks_per_second])
		_table(_no_total(w.prof), p.sim_peaks, 1.0)
		con.out("  %s %6.2f" % ["all of it".rpad(24), w.tick_ms])
	elif w:
		con.dim("(The host runs the battle's game logic.)")
	con.head("View scripts, ms per frame, on average%s" % worst)
	if p.view_avg.is_empty():
		con.dim("  nothing measured yet (only in a battle)")
	else:
		_table(p.view_avg, p.view_peaks, 1.0)
		con.out("  %s %6.2f" % ["all of them".rpad(24), p.view_ms])
	con.out("Renderer (CPU) %.2f ms, GPU %.2f ms, the whole frame %.2f ms." % [p.cpu_ms, p.gpu_ms, p.frame_ms])
	if worst == "" and w:
		con.dim("(Each part's worst frame is kept from when the console first opens: top again in a few seconds has them.)")


func _table(d: Dictionary, peaks: Dictionary, scale: float) -> void:
	var ks := d.keys()
	ks.sort_custom(func(x, y): return float(d[x]) > float(d[y]))
	for k in ks:
		var v: float = float(d[k]) * scale
		var bar := "#".repeat(clampi(roundi(v * 4.0), 0, 30))
		var line := "  %s %6.2f  %s" % [String(k).rpad(24), v, ("worst %6.2f  " % PerfProbe.peak(peaks, String(k))) if not peaks.is_empty() else ""] + bar
		if v >= 4.0:
			con.warn(line)
		else:
			con.out(line)


func c_hitches(a: PackedStringArray) -> void:
	var p := con.probe
	if not a.is_empty():
		match a[0].to_lower():
			"clear":
				p.hitches.clear()
				con.out("Stutter log cleared.")
				return
			"auto":
				p.hitch_ms = 0.0
				con.out("A stutter is now a frame over twice the usual and at least 20 ms more.")
				return
			_:
				if a[0].is_valid_float():
					p.hitch_ms = maxf(1.0, a[0].to_float())
					con.out("A stutter is now any frame over %.0f ms (hitches auto goes back)." % p.hitch_ms)
					return
	var rule := ("over %.0f ms" % p.hitch_ms) if p.hitch_ms > 0.0 else "over twice the usual frame and 20 ms more"
	if p.hitches.is_empty():
		con.good("No stutters in a battle yet (frames %s)." % rule)
		return
	con.head("The latest stutters (%d in all; frames %s):" % [p.hitch_total, rule])
	for h in p.hitches.slice(maxi(0, p.hitches.size() - 15)):
		con.warn("  %s  %4.0f ms (usually %.0f): %s" % [_clock(float(h.t)), h.ms, h.median, h.cause])
		var views := []
		for v in h.views:
			views.append("%s %.1f" % [v[0], v[1]])
		var sims := []
		for s in h.sims:
			sims.append("%s %.1f" % [s[0], s[1]])
		con.dim("         logic %.1f%s  scripts %.1f%s  renderer %.1f  GPU %.1f  ticks %d" % [h.sim, (" (" + ", ".join(sims) + ")") if not sims.is_empty() else "",
			h.view, (" (" + ", ".join(views) + ")") if not views.is_empty() else "", h.rcpu, h.gpu, h.ticks])


static func _clock(t: float) -> String:
	if t < 0.0:
		return "  -  "
	return "%d:%02d" % [floori(t / 60.0), int(t) % 60]


func _draws(kind: int) -> int:
	return RenderingServer.viewport_get_render_info(con.get_viewport().get_viewport_rid(), kind, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)


func c_render(_a: PackedStringArray) -> void:
	var rid := con.get_viewport().get_viewport_rid()
	con.head("What the last frame drew        objects   triangles   draw calls")
	var tot := [0, 0, 0]
	for row in [["the scene", RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE], ["shadows", RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW],
			["the interface", RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS]]:
		var o := RenderingServer.viewport_get_render_info(rid, row[1], RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
		var pr := RenderingServer.viewport_get_render_info(rid, row[1], RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var d := RenderingServer.viewport_get_render_info(rid, row[1], RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		tot[0] += o
		tot[1] += pr
		tot[2] += d
		con.out("  %s %9d %11s %12d" % [String(row[0]).rpad(28), o, _k(pr), d])
	con.out("  %s %9d %11s %12d" % ["in all".rpad(28), tot[0], _k(tot[1]), tot[2]])
	var vs := _win_px()
	var sc := float(Settings.get_v("scale"))
	con.out("Drawn at %d x %d (render scale %d%%), %s. Renderer %.2f ms on the CPU, %.2f ms on the GPU." % [vs.x * sc, vs.y * sc, roundi(sc * 100.0),
		Settings.LABELS.aa[clampi(int(Settings.get_v("aa")), 0, 7)], con.probe.cpu_ms, con.probe.gpu_ms])
	con.out("Video memory %.0f MB (textures %.0f MB, buffers %.0f MB). Nodes %d, physics bodies awake %d." % [Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
	var w := con.probe.world()
	if w and w.fx:
		con.out("Effects: %s." % w.fx.stats_text().strip_edges())


## The window's size in pixels (what the 3D view is drawn at, before the render scale).
func _win_px() -> Vector2:
	return Vector2(con.get_tree().root.size)


static func _k(n: int) -> String:
	return ("%.1fM" % (n / 1e6)) if n >= 1000000 else (("%.0fk" % (n / 1000.0)) if n >= 1000 else str(n))


func c_errors(_a: PackedStringArray) -> void:
	var e := con.probe.errors
	var kinds := e.snapshot()
	if kinds.is_empty():
		con.good("No engine errors or warnings logged since the game started.")
		return
	kinds.sort_custom(func(x, y): return int(x.count) > int(y.count))
	con.head("Logged since the game started: %d errors, %d warnings (%.1f a second lately). The most frequent:" % [e.errors, e.warnings, con.probe.err_rate])
	for k in kinds.slice(0, 12):
		var line := "  %6dx  %s%s  (%s)" % [k.count, "warning: " if k.warning else "", String(k.text).left(110), k.where]
		if k.warning:
			con.warn(line)
		else:
			con.bad(line)


# --- the computer and the connection ------------------------------------------------------------

func c_sys(_a: PackedStringArray) -> void:
	con.head("Frontline %s on Godot %s, %s %s (%s)" % [Updater.version, Engine.get_version_info().string, OS.get_name(), OS.get_version(), Engine.get_architecture_name()])
	var mem := OS.get_memory_info()
	con.out("  Processor     %s, %d threads" % [OS.get_processor_name(), OS.get_processor_count()])
	con.out("  Memory        %.1f GB, %.1f GB free; the game uses %.0f MB" % [float(mem.get("physical", -1)) / 1073741824.0, float(mem.get("free", -1)) / 1073741824.0,
		OS.get_static_memory_usage() / 1048576.0])
	var gtype: String = {RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU: "integrated", RenderingDevice.DEVICE_TYPE_DISCRETE_GPU: "dedicated",
		RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU: "virtual", RenderingDevice.DEVICE_TYPE_CPU: "software"}.get(RenderingServer.get_video_adapter_type(), "")
	var drv := OS.get_video_adapter_driver_info()
	if RenderingServer.get_video_adapter_name() == "":
		con.out("  Graphics      (none: no window)")
	else:
		con.out("  Graphics      %s (%s%s)%s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), (", " + gtype) if gtype != "" else "",
			(", driver %s" % " ".join(drv)) if not drv.is_empty() else ""])
	con.out("  Renderer      %s on %s%s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name(), " (the browser's)" if OS.has_feature("web") else ""])
	if DisplayServer.get_name() != "headless":
		var scr := DisplayServer.screen_get_size()
		var vs := _win_px()
		con.out("  Screen        %d x %d at %.0f Hz; window %d x %d, %s" % [scr.x, scr.y, DisplayServer.screen_get_refresh_rate(), vs.x, vs.y,
			Settings.LABELS.window[clampi(int(Settings.get_v("window")), 0, 2)].to_lower()])
	con.out("  Frame rate    vsync %s, limit %s, render scale %d%% (%s)" % ["on" if Settings.get_v("vsync") else "off",
		("%d FPS" % Engine.max_fps) if Engine.max_fps > 0 else "none", roundi(float(Settings.get_v("scale")) * 100.0), Settings.LABELS.upscaler[clampi(int(Settings.get_v("upscaler")), 0, 2)]])
	con.out("  Simulation    %d ticks a second, up to %d a frame, battle speed %.2fx" % [Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame, Engine.time_scale])
	con.out("  Graphics      preset %s; shadows %s, grass %s, effects %s, water %s, anti-aliasing %s" % [Settings.preset, _lab("shadows"), _lab("grass"), _lab("effects"), _lab("water"), _lab("aa")])


func _lab(key: String) -> String:
	var l: Array = Settings.LABELS.get(key, [])
	var v := int(Settings.get_v(key))
	return String(l[v]) if v >= 0 and v < l.size() else str(Settings.get_v(key))


func c_net(_a: PackedStringArray) -> void:
	var mp := con.multiplayer.multiplayer_peer
	if not mp is ENetMultiplayerPeer:
		con.out("Offline: nothing goes over the network in this game.")
		return
	var w := con.probe.world()
	var enet := mp as ENetMultiplayerPeer
	if con.multiplayer.is_server():
		var peers := con.multiplayer.get_peers()
		con.head("Hosting for %d player%s. Sending %.1f KB/s." % [peers.size(), "" if peers.size() == 1 else "s", (w.net_out_bps / 1024.0) if w else 0.0])
		for id in peers:
			var pp := enet.get_peer(id)
			if pp:
				con.out("  %s  %s" % [Net.player_name(id).rpad(20), _peer_text(pp)])
	else:
		var pp := enet.get_peer(1)
		con.head("Connected to the host: %s" % (_peer_text(pp) if pp else "(no connection)"))
		if w:
			con.out("  Receiving %.1f KB/s." % (w.net_in_bps / 1024.0))
	var nl := _net_line()
	if nl != "":
		con.warn(nl)


static func _peer_text(pp: ENetPacketPeer) -> String:
	return "round trip %d ms (varies by %d), packet loss %.1f%%" % [pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME), pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE),
		pp.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) * 100.0 / ENetPacketPeer.PACKET_LOSS_SCALE]


## A word on the connection if it's the trouble: a slow or lossy link to the host.
func _net_line() -> String:
	var mp := con.multiplayer.multiplayer_peer
	if not mp is ENetMultiplayerPeer or con.multiplayer.is_server():
		return ""
	var pp := (mp as ENetMultiplayerPeer).get_peer(1)
	if pp == null:
		return ""
	var rtt := pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
	var loss := pp.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) * 100.0 / ENetPacketPeer.PACKET_LOSS_SCALE
	if rtt < 150 and loss < 2.0:
		return ""
	return "The connection to the host is slow: a %d ms round trip, %.1f%% of packets lost. Orders take that long to arrive, and units jump when updates go missing." % [rtt, loss]


# --- changing things ----------------------------------------------------------------------------

func c_pause(_a: PackedStringArray) -> void:
	var w := con.probe.world()
	if w == null or w.director == null:
		con.bad("No battle to pause.")
		return
	if not w.director.can_control_time():
		con.bad("Only a battle you're playing alone can be paused (it would stop everyone).")
		return
	w.director.toggle_pause()
	con.out("Battle %s." % ("paused: the frame rate now is the cost of drawing it alone" if w.director.speed_i == 0 else "resumed"))


func c_draw(a: PackedStringArray) -> void:
	var mode := a[0].to_lower() if not a.is_empty() else "normal"
	if not DRAWS.has(mode):
		con.bad("draw takes one of: %s." % ", ".join(DRAWS.keys()))
		return
	if mode == "wireframe":
		RenderingServer.set_debug_generate_wireframes(true)
	con.get_viewport().debug_draw = DRAWS[mode]
	con.out("Drawing %s.%s" % [mode, "" if mode == "normal" else " (draw normal goes back)"])
	if RenderingServer.get_current_rendering_method() == "gl_compatibility" and mode in ["lighting", "normals", "shadows", "ssao"]:
		con.warn("(This renderer can't show that one.)")


## What `set KEY` can take: its choices, on and off, or nothing to list.
func _values_of(key: String) -> Array:
	if Settings.LABELS.has(key):
		var out := []
		for l in Settings.LABELS[key]:
			out.append(String(l).to_lower().replace(" ", "_"))
		return out
	if Settings.v.get(key) is bool:
		return ["on", "off"]
	return []


func c_set(a: PackedStringArray) -> void:
	if a.size() < 2:
		con.bad("set SETTING VALUE, for example set shadows off. settings lists them.")
		return
	if not _bench.is_empty():
		con.bad("Not while the benchmark runs (bench stop ends it).")
		return
	var key := a[0].to_lower()
	if not Settings.v.has(key):
		con.bad("No setting \"%s\". settings lists them." % key)
		return
	var cur: Variant = Settings.v[key]
	var val: Variant = _parse(key, " ".join(a.slice(1)), cur)
	if typeof(val) == TYPE_NIL:
		var opts := _values_of(key)
		con.bad("%s can't be \"%s\"%s." % [key, " ".join(a.slice(1)), (": try " + ", ".join(opts)) if not opts.is_empty() else ""])
		return
	Settings.set_v(key, val)
	con.out("%s: %s (was %s)." % [key, _show(key, val), _show(key, cur)])


## A typed value as the setting's own kind (null: it isn't one).
static func _parse(key: String, s: String, cur: Variant) -> Variant:
	var t := s.strip_edges().to_lower()
	if cur is bool:
		if t in ["on", "true", "yes", "1"]:
			return true
		if t in ["off", "false", "no", "0"]:
			return false
		return null
	if cur is int:
		if Settings.LABELS.has(key):
			var labels: Array = Settings.LABELS[key]
			var flat := t.replace("_", "").replace(" ", "")
			var hits := []
			for i in labels.size():
				var l := String(labels[i]).to_lower().replace(" ", "")
				if l == flat:
					return i
				if l.begins_with(flat):
					hits.append(i)
			if hits.size() == 1:
				return hits[0]
			if t.is_valid_int() and t.to_int() >= 0 and t.to_int() < labels.size():
				return t.to_int()
			return null
		return t.to_int() if t.is_valid_int() else null
	if cur is float:
		if t.ends_with("%") and t.trim_suffix("%").is_valid_float():
			return t.trim_suffix("%").to_float() / 100.0
		return t.to_float() if t.is_valid_float() else null
	return s.strip_edges()


static func _show(key: String, v: Variant) -> String:
	if v is int and Settings.LABELS.has(key) and v >= 0 and v < Settings.LABELS[key].size():
		return "%s (%d)" % [Settings.LABELS[key][v], v]
	if v is bool:
		return "on" if v else "off"
	return str(v)


func c_settings(a: PackedStringArray) -> void:
	var f := a[0].to_lower() if not a.is_empty() else ""
	var keys := Settings.v.keys()
	keys.sort()
	con.head("Settings (preset %s)%s:" % [Settings.preset, (" matching \"%s\"" % f) if f != "" else ""])
	for k in keys:
		if f != "" and not f in String(k):
			continue
		var opts := _values_of(k)
		con.out("  %s %s %s" % [String(k).rpad(16), _show(k, Settings.v[k]).rpad(24), ("[" + " ".join(opts) + "]") if opts.size() > 2 else ""])


func c_preset(a: PackedStringArray) -> void:
	var p := a[0].to_lower() if not a.is_empty() else ""
	if not Settings.PRESETS.has(p):
		con.bad("preset low, medium, high or ultra.")
		return
	if not _bench.is_empty():
		con.bad("Not while the benchmark runs (bench stop ends it).")
		return
	Settings.apply_preset(p)
	con.out("Graphics preset: %s." % p)


# --- the benchmark ------------------------------------------------------------------------------
# Each step turns one thing down, lets the game settle, then times the frames.
# A battle changes as it goes, so your own settings are measured again every
# few steps and each step is set against them as they were at its moment; and
# the middle frame is taken rather than the average, so the stutter a setting
# causes while it rebuilds (water, grass) doesn't count against it.

const BENCH_EVERY := 3  # steps between measures of your own settings


func c_bench(a: PackedStringArray) -> void:
	var arg := a[0].to_lower() if not a.is_empty() else ""
	if arg == "stop":
		if _bench.is_empty():
			con.out("No benchmark is running.")
		else:
			_bench_end("Benchmark stopped; your settings are back as they were.")
		return
	if not _bench.is_empty():
		con.warn("The benchmark is already running (bench stop ends it).")
		return
	var quick := arg == "quick"
	var tries := []
	for b in BENCH:
		var cur: Variant = Settings.v.get(b[0])
		if b[0] == "scale":
			if float(cur) > 0.55:
				tries.append(b)
		elif cur != b[1]:
			tries.append(b)
	var w := con.probe.world()
	if w and w.hud and w.hud.root.visible:
		tries.append(["(hud)", null, "Interface hidden"])
	if w and w.director and w.director.can_control_time() and w.director.speed_i != 0:
		tries.append(["(pause)", null, "Battle paused"])
	var steps := [["", null, "Your settings"]]
	for i in tries.size():
		steps.append(tries[i])
		if (i + 1) % BENCH_EVERY == 0 or i == tries.size() - 1:
			steps.append(["", null, "Your settings"])
	var settle := 0.4 if quick else 0.8
	var measure := 0.8 if quick else 2.0
	_bench = {"steps": steps, "i": -1, "settle": settle, "measure": measure, "orig": Settings.v.duplicate(), "no_save": Settings.no_save,
		"results": [], "phase": "", "until": 0, "ms": [], "gpu": [], "world": w, "speed": w.director.speed_i if w and w.director else 3}
	Settings.no_save = true  # (whatever happens meanwhile, the settings tried never reach the player's file)
	# uncapped, so a saving shows in the frame time and not only on the GPU
	Settings.v.vsync = false
	Settings.v.fps_cap = 0
	Settings.apply_global()
	con.head("Benchmarking %d things, about %d seconds. Keep the camera still; bench stop ends it." % [tries.size(), roundi(steps.size() * (settle + measure))])
	con.dim("  (vsync and the frame limit are off while it runs, so every saving shows)")
	_bench_next()


## Called every frame by the console.
func process() -> void:
	if _bench.is_empty():
		return
	var now := Time.get_ticks_msec()
	if con.probe.world() != _bench.world:
		_bench_end("The battle changed, so the benchmark stopped; your settings are back as they were.")
		return
	if _bench.phase == "settle":
		if now >= int(_bench.until):
			_bench.phase = "measure"
			_bench.until = now + int(float(_bench.measure) * 1000.0)
			_bench.ms = []
			_bench.gpu = []
		return
	var p := con.probe
	_bench.ms.append(p.at(p.f_ms, 0))
	_bench.gpu.append(p.at(p.f_gpu, 0))
	if now < int(_bench.until):
		return
	var step: Array = _bench.steps[_bench.i]
	var res := {"label": step[2], "key": step[0], "at": now / 1000.0, "ms": _median(_bench.ms), "gpu": _median(_bench.gpu)}
	_bench.results.append(res)
	if step[0] == "":
		con.dim("  %s %6.1f ms a frame (%.0f FPS), GPU %.1f ms" % [String(res.label).rpad(28), res.ms, 1000.0 / maxf(0.01, res.ms), res.gpu])
	else:
		con.out("  %s %6.1f ms a frame, GPU %5.1f ms" % [String(res.label).rpad(28), res.ms, res.gpu])
	_bench_next()


static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return float(s[s.size() >> 1])


func _bench_next() -> void:
	_bench_undo()
	_bench.i = int(_bench.i) + 1
	var steps: Array = _bench.steps
	if int(_bench.i) >= steps.size():
		_bench_done()
		return
	var step: Array = steps[_bench.i]
	var w: Node3D = _bench.world
	match String(step[0]):
		"":
			pass
		"(hud)":
			w.hud.root.visible = false
		"(pause)":
			w.director.set_speed_index(0)
		_:
			Settings.v[step[0]] = step[1]
			Settings.apply_global()
			Settings.changed.emit()
	_bench.phase = "settle"
	_bench.until = Time.get_ticks_msec() + int(float(_bench.settle) * 1000.0)


## Puts back what the current step changed.
func _bench_undo() -> void:
	if int(_bench.i) < 0 or int(_bench.i) >= (_bench.steps as Array).size():
		return
	var step: Array = _bench.steps[_bench.i]
	var w: Variant = _bench.world  # (it may have been freed: the battle ended)
	match String(step[0]):
		"":
			pass
		"(hud)":
			if is_instance_valid(w) and w.hud:
				w.hud.root.visible = true
		"(pause)":
			if is_instance_valid(w) and w.director:
				w.director.set_speed_index(int(_bench.speed))
		_:
			Settings.v[step[0]] = _bench.orig[step[0]]
			Settings.apply_global()
			Settings.changed.emit()


## Your settings as they measured at a moment: between the measures either side of it.
static func _base_at(bases: Array, t: float) -> Vector2:
	var before: Dictionary = bases[0]
	var after: Dictionary = bases[bases.size() - 1]
	for b in bases:
		if float(b.at) <= t:
			before = b
		else:
			after = b
			break
	var span := float(after.at) - float(before.at)
	var k := clampf((t - float(before.at)) / span, 0.0, 1.0) if span > 0.0 else 0.0
	return Vector2(lerpf(before.ms, after.ms, k), lerpf(before.gpu, after.gpu, k))


func _bench_done() -> void:
	var bases := []
	var tried := []
	for r in _bench.results:
		if r.key == "":
			bases.append(r)
		else:
			tried.append(r)
	for r in tried:
		var b := _base_at(bases, float(r.at))
		r.save = b.x - float(r.ms)
		r.gsave = b.y - float(r.gpu)
		r.base = b.x
	tried.sort_custom(func(x, y): return float(x.save) > float(y.save))
	var lo := INF
	var hi := 0.0
	var sum := 0.0
	var gsum := 0.0
	for b in bases:
		lo = minf(lo, b.ms)
		hi = maxf(hi, b.ms)
		sum += b.ms
		gsum += b.gpu
	var base := sum / bases.size()
	_bench_last = [base, gsum / bases.size(), tried]
	_bench_end("")
	con.head("What each saves, the most first (your settings: %.1f ms a frame, %.0f FPS, GPU %.1f ms):" % [base, 1000.0 / maxf(0.01, base), gsum / bases.size()])
	var worth := []
	var insights := []
	for r in tried:
		var save: float = r.save
		var pct := save / maxf(0.01, float(r.base)) * 100.0
		var line := "  %s %s   GPU %+.1f ms" % [String(r.label).rpad(28), ("saves %5.1f ms a frame (%3.0f%%)" % [save, pct]) if save > 0.05 else "no saving".rpad(29), -float(r.gsave)]
		var big := save >= maxf(0.5, float(r.base) * 0.05)
		if big:
			con.good(line)
		elif save > 0.05:
			con.out(line)
		else:
			con.dim(line)
		if not big:
			continue
		if String(r.key).begins_with("("):
			insights.append(r)
		else:
			worth.append(r.label)
	if hi - lo > base * 0.15:
		con.warn("Your settings measured between %.1f and %.1f ms over the run: the battle changed as it went, so differences under a millisecond or two are noise. bench again with the camera still for a firmer answer." % [lo, hi])
	for r in insights:
		if r.key == "(pause)":
			con.out("Pausing saved %.1f ms: that much of each frame is the battle itself, its logic and everything moving in it (why and top say what)." % r.save)
		else:
			con.out("Hiding the interface (F2) saved %.1f ms: the interface's own drawing." % r.save)
	if worth.is_empty():
		con.out("No graphics setting makes much difference here: the time goes on the game itself (why and top say where). Your settings are back as they were.")
	else:
		con.out("Worth turning down: %s. set or Settings changes them; your settings are back as they were." % ", ".join(worth.slice(0, 4)))


func _bench_end(msg: String) -> void:
	_bench_undo()
	for k in _bench.orig:
		Settings.v[k] = _bench.orig[k]
	Settings.no_save = bool(_bench.no_save)
	Settings.apply_global()
	Settings.changed.emit()
	_bench = {}
	if msg != "":
		con.out(msg)


# --- the report ---------------------------------------------------------------------------------

func c_report(_a: PackedStringArray) -> void:
	var text := PackedStringArray(["Frontline performance report, %s" % Time.get_datetime_string_from_system(false, true), ""])
	for c in ["sys", "why", "top", "render", "net", "hitches", "errors"]:
		text.append("== %s ==" % c)
		text.append_array(con.run_captured(c))
		text.append("")
	if not _bench_last.is_empty():
		text.append("== the last bench ==")
		text.append("Your settings: %.1f ms a frame, GPU %.1f ms" % [_bench_last[0], _bench_last[1]])
		for r in _bench_last[2]:
			text.append("  %s saves %.1f ms a frame, GPU %.1f ms" % [String(r.label).rpad(28), r.save, r.gsave])
	var all := "\n".join(text)
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f == null:
		con.bad("Couldn't write %s." % REPORT_PATH)
		return
	f.store_string(all)
	f.close()
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(all)
	con.good("Written to %s, and copied to the clipboard." % ProjectSettings.globalize_path(REPORT_PATH))
