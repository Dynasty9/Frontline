class_name PerfProbe
extends Node
## Measures every frame, for the performance overlay (F3) and the console:
## how long it really took and what the time went on (the battle's game
## logic, the view's scripts, the renderer, the GPU), so a slow stretch or a
## single stutter can be pinned on something. It keeps the last ten seconds
## or so frame by frame, half-second averages per system, and a log of the
## stutters ("hitches"): frames that took far longer than the ones round them.
##
## It runs after everything else in the frame, so a frame's record holds that
## frame's game logic and scripts, and the time since the last one (which
## takes in the previous frame's drawing and the wait for the screen).
##
## Each battle starts the record afresh, from its second second: the frame
## that built it lasts several seconds and would swamp everything else.

const RING := 600  # frames kept one by one
const HITCH_KEEP := 40
const WINDOW_S := 0.5  # the averages cover this long
const PEAK_S := 5.0  # a system's worst frame is remembered this long

# frame by frame, in a ring: _fi is the next to write, `count` how many are filled
var f_ms := PackedFloat32Array()  # the whole frame, by the wall clock
var f_sim := PackedFloat32Array()  # game logic (the host's simulation ticks run within the frame)
var f_view := PackedFloat32Array()  # the view's scripts
var f_rcpu := PackedFloat32Array()  # the renderer's own CPU time
var f_gpu := PackedFloat32Array()
var f_ticks := PackedByteArray()  # simulation ticks run in the frame
var count := 0
var frames := 0  # frames recorded since the game started (a hitch's "n" is its number)
var _fi := 0

# the latest half second, averaged per frame
var frame_ms := 16.7
var sim_ms := 0.0
var view_ms := 0.0
var cpu_ms := 0.0  # renderer, CPU side
var gpu_ms := 0.0
var view_avg := {}  # view system -> ms per frame
var sim_avg := {}  # simulated system -> ms per tick
var ticks_per_frame := 1.0
var err_rate := 0.0  # errors and warnings logged a second
var median_ms := 16.7
var fps_min := 0.0
var fps_max := 0.0
var low1 := 0.0  # 1% low: the frame rate of the slowest frame in a hundred
## Each system's worst single frame lately: name -> Vector2(ms, when in s). (Vectors, not
## arrays or prefixed names: this runs for every system every frame, and allocates nothing.)
var view_peaks := {}
var sim_peaks := {}

## The latest stutters, oldest first: {n (frame), at (msec), t (battle time), ms, sim, view, rcpu, gpu,
## ticks, compiles, errors, nodes, views: [[system, ms]...], sims: [[system, ms]...], cause}.
var hitches: Array = []
var hitch_total := 0
var hitch_ms := 0.0  # 0: judged against the frames round it; else a fixed threshold

var errors := ErrorCount.new()

var main: Node  # main.gd, for its world
var measuring := false
## Each system frame by frame (their worst frames, and which of them a stutter
## was in), not just their sums every half second. It costs a little every
## frame, so it starts when someone looks: the console opening, the graph.
var detail := false
var _last_us := 0
var _now_ms := 0
var _now_s := 0.0
var _phys0 := 0
var _win_t := 0.0
var _win_n := 0
var _acc := {}  # view system -> usec this window
var _sim_acc := {}  # simulated system -> ms this window
var _acc_sim := 0.0
var _acc_view := 0.0
var _acc_rcpu := 0.0
var _acc_gpu := 0.0
var _acc_ms := 0.0
var _acc_ticks := 0
var _compiles0 := 0
var _errors0 := 0
var _err_win0 := 0
var _nodes0 := 0
var _sorted := PackedFloat32Array()
var _fview := {}  # this frame's view systems, usec (only kept for a hitch)
var _fsim := {}  # this frame's simulated systems, ms
var _world: Node3D = null  # the battle being measured (World: untyped, see world())


## Counts what the engine logs (errors and warnings, from any thread). A flood
## of them is a classic hidden cost: each is formatted, printed and written to
## the log. Nothing in here may print or push an error: it would come straight back.
class ErrorCount extends Logger:
	const MAX_KINDS := 24
	var mutex := Mutex.new()
	var errors := 0
	var warnings := 0
	var kinds: Array = []  # {text, where, warning, count}
	var _by := {}

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var warn := error_type == ERROR_TYPE_WARNING
		var text := rationale if rationale != "" else code
		var where := "%s (%s:%d)" % [function, file.get_file(), line]
		var sig := where + text
		mutex.lock()
		if warn:
			warnings += 1
		else:
			errors += 1
		var i: int = _by.get(sig, -1)
		if i >= 0:
			kinds[i].count += 1
		elif kinds.size() < MAX_KINDS:
			_by[sig] = kinds.size()
			kinds.append({"text": text, "where": where, "warning": warn, "count": 1})
		mutex.unlock()

	func total() -> int:
		mutex.lock()
		var n := errors + warnings
		mutex.unlock()
		return n

	func snapshot() -> Array:
		mutex.lock()
		var out := kinds.duplicate(true)
		mutex.unlock()
		return out


func _init() -> void:
	OS.add_logger(errors)


func _exit_tree() -> void:
	OS.remove_logger(errors)


func _ready() -> void:
	process_priority = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in [f_ms, f_sim, f_view, f_rcpu, f_gpu]:
		a.resize(RING)
	f_ms.fill(16.7)
	f_ticks.resize(RING)
	_sorted.resize(RING)
	# the renderer times itself (CPU and GPU) for the overlay and the console
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		measuring = true
	_phys0 = Engine.get_physics_frames()
	_compiles0 = _compiles()
	_nodes0 = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))


## The battle (World), if one's running. Untyped: this is up from the first frame,
## before the game's classes have compiled (GameScripts), so it names none of them.
func world() -> Node3D:
	var w: Node3D = main.world if main else null
	return w if is_instance_valid(w) else null


## Shader pipelines compiled so far (each can stall a frame while the driver builds it).
static func _compiles() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0 if _last_us > 0 else 16.7
	_last_us = now
	var phys := Engine.get_physics_frames()
	var ticks := phys - _phys0
	_phys0 = phys
	_now_ms = Time.get_ticks_msec()
	_now_s = _now_ms / 1000.0
	var sim := 0.0
	var view := 0.0
	var w := world()
	if w != _world:
		_world = w
		_restart()
	if w and (w.building or w.time < 1.0):
		# (the battle is still being built, or has only just been: leave its costs for later)
		if w.sim_usec > 0 or not w.vprof.is_empty() or not w.prof_raw.is_empty():
			_drop(w)
		_compiles0 = _compiles()
		_errors0 = errors.total()
		return
	# a stutter: far longer than the frames round it (or than the threshold set)
	var limit := hitch_ms if hitch_ms > 0.0 else maxf(median_ms * 2.0, median_ms + 20.0)
	var hitch := count > 30 and ms > limit and w != null
	if w:
		sim = w.sim_usec / 1000.0
		w.sim_usec = 0
		view = w.vp_usec / 1000.0
		w.vp_usec = 0
		if detail:
			_take(w, ticks, hitch)
	var rcpu := 0.0
	var gpu := 0.0
	if measuring:
		var rid := get_viewport().get_viewport_rid()
		rcpu = RenderingServer.viewport_get_measured_render_time_cpu(rid)
		gpu = RenderingServer.viewport_get_measured_render_time_gpu(rid)
	f_ms[_fi] = ms
	f_sim[_fi] = sim
	f_view[_fi] = view
	f_rcpu[_fi] = rcpu
	f_gpu[_fi] = gpu
	f_ticks[_fi] = mini(ticks, 255)
	_fi = (_fi + 1) % RING
	count = mini(count + 1, RING)
	frames += 1
	var comp := _compiles()
	var errs := errors.total()
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if hitch:
		_hitch(w, ms, sim, view, rcpu, gpu, ticks, comp - _compiles0, errs - _errors0, nodes - _nodes0)
		_fview.clear()
		_fsim.clear()
	_compiles0 = comp
	_errors0 = errs
	_nodes0 = nodes
	_acc_ms += ms
	_acc_sim += sim
	_acc_view += view
	_acc_rcpu += rcpu
	_acc_gpu += gpu
	_acc_ticks += ticks
	_win_n += 1
	_win_t += ms / 1000.0
	if _win_t >= WINDOW_S:
		if w:
			_take(w, -1, false)  # (each system's time this window, when it wasn't taken frame by frame)
		_close_window()


## Moves what each system has cost since last time out of the world: into the
## window's sums, and frame by frame (`detail`) into the systems' worst frames
## and, for a stutter, into its record.
func _take(w: Node3D, ticks: int, hitch: bool) -> void:
	for k in w.vprof:
		var us: int = w.vprof[k]
		if us == 0:
			continue
		w.vprof[k] = 0
		_acc[k] = int(_acc.get(k, 0)) + us
		if ticks >= 0 and detail:
			var vk: Vector2 = view_peaks.get(k, Vector2.ZERO)
			if us / 1000.0 >= vk.x or _now_s - vk.y > PEAK_S:
				view_peaks[k] = Vector2(us / 1000.0, _now_s)
		if hitch:
			_fview[k] = us
	for k in w.prof_raw:
		var pm: float = w.prof_raw[k]
		if pm == 0.0:
			continue
		w.prof_raw[k] = 0.0
		_sim_acc[k] = float(_sim_acc.get(k, 0.0)) + pm
		if ticks > 0 and detail:
			var per_tick := pm / ticks
			var sk: Vector2 = sim_peaks.get(k, Vector2.ZERO)
			if per_tick >= sk.x or _now_s - sk.y > PEAK_S:
				sim_peaks[k] = Vector2(per_tick, _now_s)
		if hitch:
			_fsim[k] = pm


## A new battle, or back to the menu: the record starts again.
func _restart() -> void:
	count = 0
	f_ms.fill(16.7)
	hitches.clear()
	view_peaks.clear()
	sim_peaks.clear()
	_acc.clear()
	_sim_acc.clear()
	_acc_ms = 0.0
	_acc_sim = 0.0
	_acc_view = 0.0
	_acc_rcpu = 0.0
	_acc_gpu = 0.0
	_acc_ticks = 0
	_win_n = 0
	_win_t = 0.0
	median_ms = 16.7


## Sets what the battle measured back to zero, unread.
static func _drop(w: Node3D) -> void:
	w.sim_usec = 0
	w.vp_usec = 0
	for k in w.vprof:
		w.vprof[k] = 0
	for k in w.prof_raw:
		w.prof_raw[k] = 0.0


func _close_window() -> void:
	var n := float(maxi(1, _win_n))
	frame_ms = _acc_ms / n
	sim_ms = _acc_sim / n
	view_ms = _acc_view / n
	cpu_ms = _acc_rcpu / n
	gpu_ms = _acc_gpu / n
	ticks_per_frame = _acc_ticks / n
	var errs := errors.total()
	err_rate = (errs - _err_win0) / maxf(0.001, _win_t)
	_err_win0 = errs
	view_avg.clear()
	for k in _acc:
		view_avg[k] = _acc[k] / n / 1000.0
	sim_avg.clear()
	for k in _sim_acc:
		sim_avg[k] = float(_sim_acc[k]) / maxf(1.0, _acc_ticks)
	_acc.clear()
	_sim_acc.clear()
	_acc_ms = 0.0
	_acc_sim = 0.0
	_acc_view = 0.0
	_acc_rcpu = 0.0
	_acc_gpu = 0.0
	_acc_ticks = 0
	_win_n = 0
	_win_t = 0.0
	# the frame-rate spread over the frames kept
	for i in RING:
		_sorted[i] = f_ms[i] if i < count else 0.0
	_sorted.sort()
	var lo := RING - count
	median_ms = _sorted[lo + (count >> 1)]
	fps_min = 1000.0 / maxf(0.001, _sorted[RING - 1])
	fps_max = 1000.0 / maxf(0.001, _sorted[lo])
	low1 = 1000.0 / maxf(0.001, _sorted[lo + int((count - 1) * 0.99)])


func _hitch(w: Node3D, ms: float, sim: float, view: float, rcpu: float, gpu: float, ticks: int, compiles: int, errs: int, nodes: int) -> void:
	hitch_total += 1
	var h := {"n": frames - 1, "at": _now_ms, "t": w.time, "ms": ms, "median": median_ms, "sim": sim, "view": view, "rcpu": rcpu,
		"gpu": gpu, "ticks": ticks, "compiles": compiles, "errors": errs, "nodes": nodes, "views": _top(_fview, 0.001), "sims": _top(_fsim, 1.0)}
	h.cause = cause_of(h)
	hitches.append(h)
	if hitches.size() > HITCH_KEEP:
		hitches.pop_front()


## The biggest three of {key: amount}, as [[key, ms]...] (amount * scale = ms).
static func _top(d: Dictionary, scale: float) -> Array:
	var out := []
	for k in d:
		out.append([k, float(d[k]) * scale])
	out.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	return out.slice(0, 3)


## What a stutter most likely was, in a few words.
static func cause_of(h: Dictionary) -> String:
	var ms: float = h.ms
	var why := []
	var sim: float = h.sim
	var view: float = h.view
	if sim > ms * 0.3:
		var s := "game logic %.0f ms" % sim
		if int(h.ticks) > 1:
			s += " (%d ticks caught up at once)" % int(h.ticks)
		if not (h.sims as Array).is_empty():
			s += ", most of it %s" % h.sims[0][0]
		why.append(s)
	if view > ms * 0.3:
		why.append("view scripts %.0f ms, most of it %s" % [view, h.views[0][0] if not (h.views as Array).is_empty() else "?"])
	if int(h.compiles) > 0:
		why.append("%d shader compile%s" % [h.compiles, "" if int(h.compiles) == 1 else "s"])
	if int(h.errors) > 0:
		why.append("%d engine error%s logged" % [h.errors, "" if int(h.errors) == 1 else "s"])
	if float(h.gpu) > ms * 0.6:
		why.append("GPU %.0f ms" % h.gpu)
	if absi(int(h.nodes)) > 150:
		why.append("%+d nodes" % h.nodes)
	if why.is_empty():
		return "outside the game's scripts (drawing, the driver, the OS or another program)"
	return "; ".join(why)


## A frame `back` frames ago (0 the latest) from one of the rings.
func at(ring: PackedFloat32Array, back: int) -> float:
	return ring[(_fi - 1 - back + RING * 2) % RING]


## Averages over the latest `secs` seconds of frames:
## {frames, ms, sim, view, rcpu, gpu, ticks, worst, low1}.
func recent(secs: float) -> Dictionary:
	var n := 0
	var tot := 0.0
	var r := {"sim": 0.0, "view": 0.0, "rcpu": 0.0, "gpu": 0.0, "ticks": 0.0, "worst": 0.0}
	var list := []
	while n < count and tot < secs * 1000.0:
		var i := (_fi - 1 - n + RING * 2) % RING
		var ms: float = f_ms[i]
		tot += ms
		r.sim += f_sim[i]
		r.view += f_view[i]
		r.rcpu += f_rcpu[i]
		r.gpu += f_gpu[i]
		r.ticks += f_ticks[i]
		r.worst = maxf(r.worst, ms)
		list.append(ms)
		n += 1
	var nf := float(maxi(1, n))
	for k in ["sim", "view", "rcpu", "gpu", "ticks"]:
		r[k] = float(r[k]) / nf
	r.frames = n
	r.ms = tot / nf
	list.sort()
	r.low1 = 1000.0 / maxf(0.001, float(list[int((n - 1) * 0.99)])) if n > 0 else 0.0
	return r


## The worst a system has cost in a single frame lately, in ms (from view_peaks or sim_peaks).
static func peak(peaks: Dictionary, key: String) -> float:
	var p: Vector2 = peaks.get(key, Vector2.ZERO)
	return p.x if Time.get_ticks_msec() / 1000.0 - p.y <= PEAK_S else 0.0
