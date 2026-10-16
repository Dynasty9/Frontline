extends CanvasLayer
## Performance overlay. F3 cycles: off -> FPS -> compact -> full breakdown.

const GRAPH_N := 240

var canvas: Control
var frames := PackedFloat32Array()
var _fi := 0
var _gpu_ms := 0.0
var _cpu_ms := 0.0
var _acc_t := 0.0
var _fps_min := 0.0
var _fps_max := 0.0
var _low1 := 0.0
var _measuring := false


func _ready() -> void:
	layer = 100
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_overlay)
	add_child(canvas)
	frames.resize(GRAPH_N)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(ev: InputEvent) -> void:
	# (F3 unless rebound; anywhere, the menus included)
	if ev is InputEventKey and ev.pressed and not ev.echo and not Keys.capturing and Keys.is_event(ev, "perf"):
		Settings.set_v("perf", (int(Settings.get_v("perf")) + 1) % 4)


var _view_frames := 0
var _view_avg := {}
var _sim_ms := 0.0
var _frame_ms := 0.0


func _world() -> World:
	return get_tree().root.get_node_or_null("Main/World") as World


func _process(dt: float) -> void:
	var lvl := int(Settings.get_v("perf"))
	if lvl >= 2 and not _measuring:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		_measuring = true
	var real_dt := dt / maxf(0.0001, Engine.time_scale) if Engine.time_scale > 0.0 else 1.0 / maxf(1.0, Engine.get_frames_per_second())
	frames[_fi] = real_dt * 1000.0
	_fi = (_fi + 1) % GRAPH_N
	_acc_t += real_dt
	_view_frames += 1
	if _acc_t > 0.5:
		_acc_t = 0.0
		var wv := _world()
		if wv:
			_view_avg = {}
			for k in wv.vprof:
				_view_avg[k] = float(wv.vprof[k]) / maxf(1.0, _view_frames) / 1000.0
			wv.vprof.clear()
			_sim_ms = float(wv.sim_usec) / maxf(1.0, _view_frames) / 1000.0
			wv.sim_usec = 0
		_frame_ms = 500.0 / maxf(1.0, _view_frames) if _view_frames > 0 else 0.0
		_view_frames = 0
		var sorted := frames.duplicate()
		sorted.sort()
		_low1 = 1000.0 / maxf(0.001, sorted[int(GRAPH_N * 0.99)])
		_fps_min = 1000.0 / maxf(0.001, sorted[GRAPH_N - 1])
		_fps_max = 1000.0 / maxf(0.001, sorted[0])
	if _measuring:
		var rid := get_viewport().get_viewport_rid()
		_cpu_ms = lerpf(_cpu_ms, RenderingServer.viewport_get_measured_render_time_cpu(rid), 0.1)
		_gpu_ms = lerpf(_gpu_ms, RenderingServer.viewport_get_measured_render_time_gpu(rid), 0.1)
	canvas.visible = lvl > 0
	if lvl > 0:
		canvas.queue_redraw()


func _font() -> Font:
	return ThemeDB.fallback_font


func _text(p: Vector2, s: String, col := Color(1, 1, 1, 0.92), size := 13) -> void:
	canvas.draw_string_outline(_font(), p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.7))
	canvas.draw_string(_font(), p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _fps_col(fps: float) -> Color:
	if fps >= 55.0:
		return Color(0.55, 1.0, 0.55)
	if fps >= 30.0:
		return Color(1.0, 0.85, 0.4)
	return Color(1.0, 0.45, 0.4)


func _draw_overlay() -> void:
	var lvl := int(Settings.get_v("perf"))
	var vs := canvas.get_viewport_rect().size
	var fps := Engine.get_frames_per_second()
	var ft := 1000.0 / maxf(1.0, fps)
	if lvl == 1:
		var s := "%d FPS  %.1f ms" % [fps, ft]
		var w := _font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_text(Vector2(vs.x - w - 14, 22), s, _fps_col(fps), 14)
		return
	var pw := 330.0 if lvl == 2 else 560.0
	var x := vs.x - pw
	var y := 40.0
	var panel_h := 150.0 if lvl == 2 else 590.0
	canvas.draw_rect(Rect2(x - 10, y - 18, pw, panel_h), Color(0.02, 0.03, 0.02, 0.8))
	canvas.draw_rect(Rect2(x - 10, y - 18, pw, panel_h), Color(0.5, 0.55, 0.4, 0.5), false, 1.0)
	_text(Vector2(x, y), "%d FPS   %.2f ms" % [fps, ft], _fps_col(fps), 18)
	y += 18
	_text(Vector2(x, y), "min %d  max %d  1%% low %d" % [_fps_min, _fps_max, _low1], Color(0.8, 0.8, 0.75), 12)
	y += 20
	var view_ms := 0.0
	for k in _view_avg:
		view_ms += float(_view_avg[k])
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var objs := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var vmem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	# frame breakdown bar
	var other := maxf(0.0, ft - _sim_ms - view_ms - _cpu_ms)
	var parts := [["game logic (simulation)", _sim_ms, Color(1.0, 0.75, 0.35)], ["game view scripts", view_ms, Color(0.4, 0.75, 1.0)],
		["render CPU", _cpu_ms, Color(0.75, 0.55, 1.0)], ["engine / sync / idle", other, Color(0.45, 0.45, 0.45)]]
	var total := 0.0
	for pt in parts:
		total += float(pt[1])
	var bw := 310.0
	var bx := x
	var scale := bw / maxf(maxf(total, ft), 16.7)
	for pt in parts:
		var w2: float = float(pt[1]) * scale
		canvas.draw_rect(Rect2(bx, y, w2, 10), pt[2])
		bx += w2
	canvas.draw_line(Vector2(x + 16.7 * scale, y - 2), Vector2(x + 16.7 * scale, y + 12), Color(1, 1, 1, 0.6), 1.0)
	y += 26
	# GPU runs alongside the CPU: separate bar on the same scale
	canvas.draw_rect(Rect2(x, y + 2, _gpu_ms * scale, 6), Color(0.45, 1.0, 0.6))
	y += 8
	for pt in parts:
		canvas.draw_rect(Rect2(x, y - 9, 9, 9), pt[2])
		_text(Vector2(x + 14, y), "%s  %.2f ms" % [pt[0], pt[1]], Color(0.9, 0.9, 0.85), 12)
		y += 16
	canvas.draw_rect(Rect2(x, y - 9, 9, 9), Color(0.45, 1.0, 0.6))
	_text(Vector2(x + 14, y), "GPU  %.2f ms  (%s-bound)" % [_gpu_ms, "GPU" if _gpu_ms > ft - other * 0.5 and _gpu_ms > _sim_ms + view_ms + _cpu_ms else "CPU"], Color(0.9, 0.9, 0.85), 12)
	y += 16
	_text(Vector2(x, y), "draw calls %d   objects %d   tris %.0fk" % [draws, objs, prims / 1000.0], Color(0.85, 0.85, 0.8), 12)
	y += 16
	if lvl == 2:
		return
	_text(Vector2(x, y), "video memory %.0f MB   static %.0f MB" % [vmem, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0], Color(0.85, 0.85, 0.8), 12)
	y += 16
	_text(Vector2(x, y), "nodes %d   physics bodies %d" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)], Color(0.85, 0.85, 0.8), 12)
	y += 22
	# frame time graph
	var gh := 70.0
	canvas.draw_rect(Rect2(x, y, 310, gh), Color(0, 0, 0, 0.35))
	var gmax := 40.0
	for ref in [16.7, 33.3]:
		var ry: float = y + gh - ref / gmax * gh
		canvas.draw_line(Vector2(x, ry), Vector2(x + 310, ry), Color(1, 1, 1, 0.18), 1.0)
		_text(Vector2(x + 312 - 40, ry - 2), "%.0f ms" % ref, Color(1, 1, 1, 0.4), 10)
	var prev := Vector2.ZERO
	for i in GRAPH_N:
		var v: float = frames[(_fi + i) % GRAPH_N]
		var pt2 := Vector2(x + float(i) / (GRAPH_N - 1) * 310.0, y + gh - clampf(v / gmax, 0.0, 1.0) * gh)
		if i > 0:
			canvas.draw_line(prev, pt2, _fps_col(1000.0 / maxf(0.01, v)), 1.2)
		prev = pt2
	y += gh + 18
	var w := _world()
	if w == null:
		_text(Vector2(x, y), "(no battle running)", Color(0.7, 0.7, 0.65), 12)
		return
	var y0 := y
	if w.srv:
		_text(Vector2(x, y), "SIMULATION (host) ms per tick", Color(1.0, 0.85, 0.5), 12)
		y += 16
		var keys := w.prof.keys()
		keys.sort_custom(func(a, b): return float(w.prof[a]) > float(w.prof[b]))
		for k in keys:
			var ms: float = w.prof[k]
			canvas.draw_rect(Rect2(x + 150, y - 9, minf(100.0, ms * 40.0), 8), Color(1.0, 0.75, 0.35, 0.8))
			_text(Vector2(x, y), "%s" % k, Color(0.85, 0.85, 0.8), 12)
			_text(Vector2(x + 105, y), "%.2f" % ms, Color(1, 1, 1, 0.9), 12)
			y += 15
	var y1 := y
	y = y0
	var vx := x + 275.0
	_text(Vector2(vx, y), "VIEW scripts ms per frame", Color(0.55, 0.85, 1.0), 12)
	y += 16
	var vkeys := _view_avg.keys()
	vkeys.sort_custom(func(a, b): return float(_view_avg[a]) > float(_view_avg[b]))
	var vsum := 0.0
	for k in vkeys:
		var ms2: float = _view_avg[k]
		vsum += ms2
		canvas.draw_rect(Rect2(vx + 150, y - 9, minf(110.0, ms2 * 25.0), 8), Color(0.45, 0.75, 1.0, 0.8))
		_text(Vector2(vx, y), "%s" % k, Color(0.85, 0.85, 0.8), 12)
		_text(Vector2(vx + 105, y), "%.2f" % ms2, Color(1, 1, 1, 0.9), 12)
		y += 15
	_text(Vector2(vx, y), "sum", Color(0.7, 0.8, 0.9), 12)
	_text(Vector2(vx + 105, y), "%.2f" % vsum, Color(1, 1, 1, 0.9), 12)
	y = maxf(y + 15, y1) + 6
	var counts := {}
	for e in w.entities.values():
		counts[e.ekind()] = int(counts.get(e.ekind(), 0)) + 1
	var alive := 0
	for s in w.soldiers:
		if s.life == Soldier.Life.ALIVE:
			alive += 1
	_text(Vector2(x, y), "entities %d  (soldiers %d alive / %d, vehicles %d, structures %d, projectiles %d)" % [w.entities.size(), alive, w.soldiers.size(), w.vehicles.size(), w.structures.size(), w.projectiles.size()], Color(0.85, 0.85, 0.8), 11)
	y += 15
	if w.fx:
		_text(Vector2(x, y), "effects: %s" % w.fx.stats_text(), Color(0.85, 0.85, 0.8), 11)
		y += 15
	_text(Vector2(x, y), "network: out %.1f KB/s  in %.1f KB/s  peers %d" % [w.net_out_bps / 1024.0, w.net_in_bps / 1024.0, w.ready_peers.size()], Color(0.85, 0.85, 0.8), 11)
	y += 15
	_text(Vector2(x, y), "time scale %.2fx" % Engine.time_scale, Color(0.85, 0.85, 0.8), 11)
