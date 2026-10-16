class_name HudObjectives
extends Control
## A mission's objectives, top right: the operation, the mission clock and each
## objective with its letter (the same letter marks it on the ground and the
## minimap), what's left of it and whether it's done. When one is set, met or
## lost, a banner says so across the top of the screen with a radio chime.

const W := 360.0

var hud: Hud
var need_h := 0.0  # how tall the panel is (the notifications go under it)
var _states := {}  # objective text -> state, to spot the changes
var _banners: Array = []  # [caption, text, colour, age]


func _process(dt: float) -> void:
	var info: Dictionary = hud.world.mission_info
	visible = not info.is_empty()
	if not visible:
		need_h = 0.0
		return
	var rdt := dt / maxf(0.0001, Engine.time_scale) if Engine.time_scale > 0.001 else 0.016
	_spot_changes(info)
	if not _banners.is_empty():
		_banners[0][3] = float(_banners[0][3]) + rdt
		if float(_banners[0][3]) > 4.2:
			_banners.pop_front()
	queue_redraw()


func _spot_changes(info: Dictionary) -> void:
	for o in info.get("objs", []):
		var key := String(o[1])
		var st := int(o[2])
		var was := int(_states.get(key, -1))
		if was == st:
			continue
		_states[key] = st
		match st:
			MissionDirector.ACTIVE:
				_banner("NEW OBJECTIVE" if not bool(o[7]) else "OPTIONAL OBJECTIVE", key, UiKit.ACCENT, "objective")
			MissionDirector.DONE:
				_banner("OBJECTIVE COMPLETE", key, UiKit.GOOD, "objective_done")
			MissionDirector.FAILED:
				_banner("OBJECTIVE FAILED", key, UiKit.BAD, "objective_failed")


func _banner(cap: String, text: String, col: Color, snd: String) -> void:
	# a run of them at once (the start of a mission, one done and the next set):
	# each gets its turn
	_banners.append([cap, text, col, 0.0])
	if _banners.size() > 4:
		_banners.remove_at(1)
	Sfx.ui(snd)


## The mission clock: from the last update, run on locally.
func elapsed(info: Dictionary) -> float:
	var el := float(info.get("el", 0.0))
	if int(info.get("over", 0)) == 0:
		el += hud.world.time - hud.world.mission_rx_t
	return el


func _draw() -> void:
	var info: Dictionary = hud.world.mission_info
	if info.is_empty():
		return
	_draw_panel(info)
	if not _banners.is_empty():
		_draw_banner(_banners[0])


func _draw_panel(info: Dictionary) -> void:
	var x0 := size.x - W - 14.0
	var y0 := 12.0 if int(Settings.get_v("perf")) < 1 else 34.0  # clear of the frame-rate readout
	var objs: Array = info.get("objs", [])
	# measure first: each objective's text wraps
	var rows := []
	var h := 62.0
	for o in objs:
		var lines: Array = MapSymbols.wrap(String(o[1]), 14, 500, W - 120.0)
		rows.append(lines)
		h += 8.0 + lines.size() * 18.0
	var left := float(info.get("left", -1.0))
	if left >= 0.0:
		left -= hud.world.time - hud.world.mission_rx_t if int(info.get("over", 0)) == 0 else 0.0
		h += 26.0
	h += 6.0
	need_h = h + y0 - 12.0
	var r := Rect2(x0, y0, W, h)
	draw_style_box(UiKit.boxc(UiKit.PANEL, 8, UiKit.LINE, 1, 0.0), r)
	draw_rect(Rect2(x0, y0 + 8, 3, h - 16), UiKit.ACCENT)
	# the operation, the mission and the clock
	var el := elapsed(info)
	UiKit.text(self, Vector2(x0 + 16, y0 + 22), String(info.get("op", "")).to_upper(), 11, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.9), 700)
	_at(self, Vector2(x0 + W - 16, y0 + 22), "%02d:%02d" % [int(el) / 60, int(el) % 60], 13, UiKit.TEXT, 600, 1.0)
	UiKit.text(self, Vector2(x0 + 16, y0 + 46), String(info.get("title", "")), 19, UiKit.TEXT, 700)
	var y := y0 + 66.0
	for i in objs.size():
		var o: Array = objs[i]
		var st := int(o[2])
		var lines: Array = rows[i]
		var col := UiKit.TEXT
		var mark_col := UiKit.ACCENT
		match st:
			MissionDirector.DONE:
				col = Color(UiKit.DIM.r, UiKit.DIM.g, UiKit.DIM.b, 0.9)
				mark_col = UiKit.GOOD
			MissionDirector.FAILED:
				col = Color(UiKit.BAD.r, UiKit.BAD.g, UiKit.BAD.b, 0.75)
				mark_col = UiKit.BAD
		if bool(o[7]) and st == MissionDirector.ACTIVE:
			col = Color(0.8, 0.82, 0.78)
		# the mark: its letter in a diamond, a tick when it's done, a cross when lost
		var mc := Vector2(x0 + 26, y + 4)
		match st:
			MissionDirector.DONE:
				draw_polyline(PackedVector2Array([mc + Vector2(-6, 0), mc + Vector2(-2, 5), mc + Vector2(7, -6)]), mark_col, 2.5, true)
			MissionDirector.FAILED:
				draw_line(mc + Vector2(-5, -5), mc + Vector2(5, 5), mark_col, 2.5, true)
				draw_line(mc + Vector2(5, -5), mc + Vector2(-5, 5), mark_col, 2.5, true)
			_:
				if String(o[0]) != "":
					diamond(self, mc, 9.0, String(o[0]), mark_col, 1.0)
				else:
					# nowhere in particular (keep something alive, a timer): a ring
					draw_arc(mc, 6.0, 0, TAU, 20, mark_col, 2.0, true)
		var ly := y + 9.0
		for ln in lines:
			UiKit.text(self, Vector2(x0 + 46, ly), String(ln), 14, col, 500 if st == MissionDirector.ACTIVE else 400)
			ly += 18.0
		if st == MissionDirector.DONE or st == MissionDirector.FAILED:
			# struck through, faintly
			var tw := minf(UiKit.text_width(String(lines[0]), 14, 400), W - 120.0)
			draw_line(Vector2(x0 + 46, y + 4), Vector2(x0 + 46 + tw, y + 4), Color(col.r, col.g, col.b, 0.5), 1.0)
		var pt := String(o[6])
		if pt == "" and bool(o[7]) and st == MissionDirector.ACTIVE:
			_at(self, Vector2(x0 + W - 16, y + 8), "OPTIONAL", 10, Color(0.75, 0.77, 0.72, 0.8), 700, 1.0)
		if pt != "" and st == MissionDirector.ACTIVE:
			_at(self, Vector2(x0 + W - 16, y + 9), pt, 13, UiKit.ACCENT if not pt.ends_with("contested") else UiKit.WARN, 700, 1.0)
		y += 8.0 + lines.size() * 18.0
	if left >= 0.0:
		left = maxf(0.0, left)
		var lc := UiKit.WARN if left > 60.0 else UiKit.BAD
		UiKit.text(self, Vector2(x0 + 16, y + 14), "TIME LEFT", 11, Color(lc.r, lc.g, lc.b, 0.85), 700)
		_at(self, Vector2(x0 + W - 16, y + 14), "%d:%02d" % [int(left) / 60, int(left) % 60], 14, lc, 700, 1.0)


func _draw_banner(b: Array) -> void:
	var age: float = b[3]
	var a := clampf(minf(age * 4.0, (4.2 - age) * 2.0), 0.0, 1.0)
	var col: Color = b[2]
	var cy := 150.0
	var cx := size.x * 0.5
	var text := String(b[1])
	var tw := UiKit.text_width(text, 24, 700)
	var bw := maxf(tw + 80.0, 360.0)
	var slide := (1.0 - clampf(age * 4.0, 0.0, 1.0)) * 12.0
	var r := Rect2(cx - bw * 0.5, cy - 34 + slide, bw, 76)
	draw_style_box(UiKit.boxc(Color(0.03, 0.035, 0.03, 0.72 * a), 6, Color(col.r, col.g, col.b, 0.35 * a), 1, 0.0), r)
	draw_rect(Rect2(r.position.x, r.position.y, bw, 2), Color(col.r, col.g, col.b, a))
	_at(self, Vector2(cx, cy - 10 + slide), String(b[0]), 12, Color(col.r, col.g, col.b, a), 700, 0.5)
	_at(self, Vector2(cx, cy + 22 + slide), text, 24, Color(0.96, 0.95, 0.9, a), 700, 0.5)


## Text set off a point: align 0 left of it, 0.5 centred on it, 1 right of it.
static func _at(ci: CanvasItem, p: Vector2, s: String, fs: int, col: Color, wt: int, align: float) -> void:
	UiKit.text(ci, Vector2(p.x - UiKit.text_width(s, fs, wt) * align, p.y), s, fs, col, wt)


## An objective's mark: a diamond with its letter (also used by the overlay
## and the minimap).
static func diamond(ci: CanvasItem, c: Vector2, s: float, letter: String, col: Color, a: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	ci.draw_colored_polygon(pts, Color(0.04, 0.045, 0.04, 0.85 * a))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(col.r, col.g, col.b, a), maxf(1.5, s * 0.18), true)
	if letter != "":
		var fs := int(maxf(9.0, s * 1.1))
		_at(ci, c + Vector2(0, fs * 0.36), letter, fs, Color(col.r, col.g, col.b, a), 700, 0.5)
