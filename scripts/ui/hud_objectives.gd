class_name HudObjectives
extends Control
## A mission's objectives, top right: the operation, the mission clock and each
## objective with its letter (the same letter marks it on the ground and the
## minimap), what's left of it and whether it's done. When one is set, met or
## lost, a banner says so across the top of the screen with a radio chime.

const W := 380.0

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


## The objectives on the right scrim (docs/UI.md, Layout): the operation and
## the mission clock, the mission's name, then a line per objective with its
## mark; no box.
func _draw_panel(info: Dictionary) -> void:
	var x0 := size.x - W - 14.0
	var y0 := 12.0 if int(Settings.get_v("perf")) < 1 else 34.0  # clear of the frame-rate readout
	var objs: Array = info.get("objs", [])
	# measure first: each objective's text wraps
	var rows := []
	var h := 50.0
	for o in objs:
		var lines: Array = MapSymbols.wrap(String(o[1]), 13, 400, W - 110.0)
		rows.append(lines)
		h += 6.0 + lines.size() * 17.0
	var left := float(info.get("left", -1.0))
	if left >= 0.0:
		left -= hud.world.time - hud.world.mission_rx_t if int(info.get("over", 0)) == 0 else 0.0
		h += 24.0
	need_h = h + y0 - 12.0
	# the operation, the mission and the clock
	var el := elapsed(info)
	UiKit.caps_at(self, Vector2(x0, y0 + 12), String(info.get("op", "")), 11, UiKit.ACCENT)
	var clock := "%02d:%02d" % [int(el) / 60, int(el) % 60]
	UiKit.mono_at(self, Vector2(x0 + W - UiKit.mono_w(clock, 13), y0 + 12), clock, 13, UiKit.TEXT)
	UiKit.caps_at(self, Vector2(x0, y0 + 34), String(info.get("title", "")), 17, UiKit.TEXT)
	UiKit.rule(self, Vector2(x0, y0 + 43.5), Vector2(x0 + W, y0 + 43.5))
	var y := y0 + 58.0
	for i in objs.size():
		var o: Array = objs[i]
		var st := int(o[2])
		var lines: Array = rows[i]
		var col := UiKit.TEXT
		var mark_col := UiKit.ACCENT
		match st:
			MissionDirector.DONE:
				col = UiKit.FAINT
				mark_col = UiKit.GOOD
			MissionDirector.FAILED:
				col = UiKit.BAD
				mark_col = UiKit.BAD
		if bool(o[7]) and st == MissionDirector.ACTIVE:
			col = UiKit.DIM
		# the mark: its letter in a diamond, a tick when it's done, a cross when lost
		var mc := Vector2(x0 + 9, y - 4)
		match st:
			MissionDirector.DONE:
				draw_polyline(PackedVector2Array([mc + Vector2(-5, 0), mc + Vector2(-2, 4), mc + Vector2(6, -5)]), mark_col, 1.6, true)
			MissionDirector.FAILED:
				draw_line(mc + Vector2(-4, -4), mc + Vector2(4, 4), mark_col, 1.6, true)
				draw_line(mc + Vector2(4, -4), mc + Vector2(-4, 4), mark_col, 1.6, true)
			_:
				if String(o[0]) != "":
					diamond(self, mc, 8.0, String(o[0]), mark_col, 1.0)
				else:
					# nowhere in particular (keep something alive, a timer): a square
					draw_rect(Rect2(mc - Vector2(4, 4), Vector2(8, 8)), mark_col, false, 1.2)
		var ly := y
		for ln in lines:
			UiKit.text(self, Vector2(x0 + 26, ly), String(ln), 13, col, 500 if st == MissionDirector.ACTIVE else 400)
			ly += 17.0
		if st == MissionDirector.DONE or st == MissionDirector.FAILED:
			# struck through, faintly
			var tw := minf(UiKit.text_width(String(lines[0]), 13, 400), W - 110.0)
			draw_line(Vector2(x0 + 26, y - 4), Vector2(x0 + 26 + tw, y - 4), UiKit.fa(col, 0.6), 1.0)
		var pt := String(o[6])
		if pt == "" and bool(o[7]) and st == MissionDirector.ACTIVE:
			UiKit.mono_at(self, Vector2(x0 + W - UiKit.mono_w("OPTIONAL", 10), y), "OPTIONAL", 10, UiKit.FAINT)
		if pt != "" and st == MissionDirector.ACTIVE:
			var pu := pt.to_upper()
			UiKit.mono_at(self, Vector2(x0 + W - UiKit.mono_w(pu, 12), y), pu, 12, UiKit.ACCENT if not pt.ends_with("contested") else UiKit.WARN)
		y += 6.0 + lines.size() * 17.0
	if left >= 0.0:
		left = maxf(0.0, left)
		var lc := UiKit.WARN if left > 60.0 else UiKit.BAD
		UiKit.caps_at(self, Vector2(x0, y + 8), "Time left", 11, lc)
		var tl := "%02d:%02d" % [int(left) / 60, int(left) % 60]
		UiKit.mono_at(self, Vector2(x0 + W - UiKit.mono_w(tl, 13), y + 8), tl, 13, lc)


## An objective set, met or lost, across the top of the screen: a band of ink
## ruled off in its colour, the word, then the objective; it flickers on.
func _draw_banner(b: Array) -> void:
	var age: float = b[3]
	var a := clampf((4.2 - age) / 0.2, 0.0, 1.0)
	if not UiMotion.reduced() and age < 0.12 and fmod(age, 0.12) >= 0.06:
		a = 0.0
	var col: Color = b[2]
	var cy := 150.0
	var cx := size.x * 0.5
	var text := String(b[1])
	var tw := UiKit.caps_w(text, 22)
	var bw := maxf(tw + 80.0, 360.0)
	var r := Rect2(cx - bw * 0.5, cy - 30, bw, 64)
	draw_rect(r, UiKit.fa(UiKit.INK, 0.82 * a))
	draw_line(r.position + Vector2(0, 0.5), Vector2(r.end.x, r.position.y + 0.5), UiKit.fa(col, a), 1.0)
	draw_line(Vector2(r.position.x, r.end.y - 0.5), r.end - Vector2(0, 0.5), UiKit.fa(col, a), 1.0)
	var cap := String(b[0])
	UiKit.caps_at(self, Vector2(cx - UiKit.caps_w(cap, 12) * 0.5, cy - 8), cap, 12, UiKit.fa(col, a))
	UiKit.caps_at(self, Vector2(cx - tw * 0.5, cy + 20), text, 22, UiKit.fa(UiKit.TEXT, a))


## Text set off a point: align 0 left of it, 0.5 centred on it, 1 right of it.
static func _at(ci: CanvasItem, p: Vector2, s: String, fs: int, col: Color, wt: int, align: float) -> void:
	UiKit.text(ci, Vector2(p.x - UiKit.text_width(s, fs, wt) * align, p.y), s, fs, col, wt)


## An objective's mark: a diamond with its letter (also used by the overlay
## and the minimap).
static func diamond(ci: CanvasItem, c: Vector2, s: float, letter: String, col: Color, a: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)])
	ci.draw_colored_polygon(pts, UiKit.fa(UiKit.INK, 0.85 * a))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(col.r, col.g, col.b, a), 1.2, true)
	if letter != "":
		var fs := int(maxf(9.0, s * 1.1))
		var f := UiKit.mono(400)
		var lw := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string(f, c + Vector2(-lw * 0.5, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, a))
