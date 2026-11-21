class_name HudObjectives
extends Control
## A mission's objectives, top right: the operation, the mission clock and each
## objective with its letter (the same letter marks it on the ground and the
## minimap), what's left of it and whether it's done. When one is set, met or
## lost, a banner says so across the top of the screen with a radio chime.
## Out of a mission, in Play vs AI, the same panel carries the adviser's
## suggestions (Adviser), and under it whatever quiet word it has to say.
## Keys named in a mission's text ({action}) are shown as this player has
## them bound (Keys.fill).
## Objectives met or lost stay a few seconds, then fold into one line (3 DONE)
## so the list holds only what's still to do.

const W := 380.0

var hud: Hud
var need_h := 0.0  # how tall the panel is (the notifications go under it)
var _states := {}  # objective text -> state, to spot the changes
var _banners: Array = []  # [caption, text, colour, age, training]
var _drilled := {}  # (a drill mission) what's been reported done already
var _settled := {}  # objective text -> battle time it was met or lost
const FOLD_AFTER := 6.0  # seconds a finished objective stays in the list
var _drill0 := {}  # ...and how things stood when it started watching


## What the panel shows: the mission's objectives, else the adviser's
## (as a mission's info, marked "adviser"), else nothing.
static func shown(w: World) -> Dictionary:
	if not w.mission_info.is_empty():
		return w.mission_info
	if w.adviser != null and Adviser.on() and (not w.adviser.objs.is_empty() or w.adviser.current() != ""):
		return {"op": "Adviser", "title": "Suggested" if not w.adviser.objs.is_empty() else "", "objs": w.adviser.objs, "adviser": true}
	return {}


func _process(dt: float) -> void:
	var info: Dictionary = shown(hud.world)
	visible = not info.is_empty()
	if not visible:
		need_h = 0.0
		return
	var rdt := dt / maxf(0.0001, Engine.time_scale) if Engine.time_scale > 0.001 else 0.016
	if not info.get("adviser", false):
		_spot_changes(info)
		_report_drills(info)
	if not _banners.is_empty():
		_banners[0][3] = float(_banners[0][3]) + rdt
		if float(_banners[0][3]) > 4.2:
			_banners.pop_front()
	queue_redraw()


## A drill (Boot Camp) waiting for something only this screen sees: the
## camera moved, a squad picked up, the order of battle folded, the tactical
## map opened. Each is told to the server once, as an order ("drill").
func _report_drills(info: Dictionary) -> void:
	var watch: Array = info.get("watch", [])
	if watch.is_empty() or hud.world.local_team < 0:
		return
	var w := hud.world
	var cam := w.cam
	for what in watch:
		if _drilled.has(what) or not what in ["camera", "select", "orbat", "tactical"]:
			continue
		var did := false
		match String(what):
			"camera":
				if not _drill0.has("cam"):
					_drill0.cam = [cam.focus_pos, cam.yaw, cam.target_dist]
				var c0: Array = _drill0.cam
				# panned a good way, and turned or zoomed too
				var panned := Defs.flat(cam.focus_pos - (c0[0] as Vector3)).length() > 20.0
				var turned := absf(angle_difference(cam.yaw, float(c0[1]))) > 0.5
				var zoomed := absf(cam.target_dist - float(c0[2])) > float(c0[2]) * 0.3
				did = panned and (turned or zoomed)
			"select":
				for sid in w.input.sel_squads:
					did = true
			"orbat":
				if not _drill0.has("orbat"):
					_drill0.orbat = hud.orbat.open
				# folded away (or opened, if it started folded), then back
				if hud.orbat.open != bool(_drill0.orbat):
					_drill0.orbat_flip = true
				did = _drill0.get("orbat_flip", false) and hud.orbat.open == bool(_drill0.orbat)
			"tactical":
				did = hud.tactical
		if did:
			_drilled[what] = true
			w.send_cmd({"t": "drill", "what": what})


func _spot_changes(info: Dictionary) -> void:
	for o in info.get("objs", []):
		var key := String(o[1])
		var st := int(o[2])
		var was := int(_states.get(key, -1))
		if was == st:
			continue
		_states[key] = st
		if st == MissionDirector.DONE or st == MissionDirector.FAILED:
			_settled[key] = hud.world.time if was >= 0 and hud != null else -1e9
		match st:
			MissionDirector.ACTIVE:
				_banner("NEW OBJECTIVE" if not bool(o[7]) else "OPTIONAL OBJECTIVE", key, UiKit.ACCENT, "objective", info.get("key", "") == "bootcamp")
			MissionDirector.DONE:
				_banner("OBJECTIVE COMPLETE", key, UiKit.GOOD, "objective_done", info.get("key", "") == "bootcamp")
			MissionDirector.FAILED:
				_banner("OBJECTIVE FAILED", key, UiKit.BAD, "objective_failed", info.get("key", "") == "bootcamp")


func _banner(cap: String, text: String, col: Color, snd: String, training := false) -> void:
	# a run of them at once (the start of a mission, one done and the next set):
	# each gets its turn
	# Training advances as soon as the player acts. Never ask them to carry
	# out an old instruction while the objective panel has already moved on.
	if training:
		_banners.clear()
	_banners.append([cap, text, col, 0.0, training])
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
	var info: Dictionary = shown(hud.world)
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
	var adv := bool(info.get("adviser", false))
	var folded := 0
	var lost := 0
	for o in objs:
		if _folded(o):
			folded += 1
			if int(o[2]) == MissionDirector.FAILED:
				lost += 1
			rows.append([])
			continue
		var lines: Array = MapSymbols.wrap(Keys.fill(String(o[1])), 13, 400, W - 110.0)
		rows.append(lines)
		h += 6.0 + lines.size() * 17.0
	if folded > 0:
		h += 22.0
	var left := float(info.get("left", -1.0))
	if left >= 0.0:
		left -= hud.world.time - hud.world.mission_rx_t if int(info.get("over", 0)) == 0 else 0.0
		h += 24.0
	# the adviser's word, under its suggestions
	var word: String = Keys.fill(hud.world.adviser.current()) if adv else ""
	var word_lines: Array = MapSymbols.wrap(word, 13, 400, W - 26.0) if word != "" else []
	if not word_lines.is_empty():
		h += 26.0 + word_lines.size() * 17.0
	need_h = h + y0 - 12.0
	# the operation, the mission and the clock (the adviser: the key that turns it off)
	UiKit.caps_at(self, Vector2(x0, y0 + 12), String(info.get("op", "")), 11, UiKit.ACCENT if not adv else UiKit.DIM)
	if not adv:
		var el := elapsed(info)
		var clock := "%02d:%02d" % [int(el) / 60, int(el) % 60]
		UiKit.mono_at(self, Vector2(x0 + W - UiKit.mono_w(clock, 13), y0 + 12), clock, 13, UiKit.TEXT)
	else:
		var off := "SETTINGS \u203a INTERFACE"
		UiKit.mono_at(self, Vector2(x0 + W - UiKit.mono_w(off, 10), y0 + 12), off, 10, UiKit.FAINT)
	UiKit.caps_at(self, Vector2(x0, y0 + 34), String(info.get("title", "")), 17, UiKit.TEXT)
	UiKit.rule(self, Vector2(x0, y0 + 43.5), Vector2(x0 + W, y0 + 43.5))
	var y := y0 + 58.0
	if folded > 0:
		var ft := "%d DONE" % (folded - lost) + (" · %d LOST" % lost if lost > 0 else "")
		draw_polyline(PackedVector2Array([Vector2(x0 + 4, y - 4), Vector2(x0 + 7, y), Vector2(x0 + 15, y - 9)]), UiKit.fa(UiKit.GOOD, 0.6), 1.4, true)
		UiKit.mono_at(self, Vector2(x0 + 26, y), ft, 11, UiKit.FAINT)
		y += 22.0
	for i in objs.size():
		var o: Array = objs[i]
		var st := int(o[2])
		var lines: Array = rows[i]
		if lines.is_empty():
			continue
		var col := UiKit.TEXT
		var mark_col := UiKit.ACCENT
		match st:
			MissionDirector.DONE:
				col = UiKit.FAINT
				mark_col = UiKit.GOOD
			MissionDirector.FAILED:
				col = UiKit.BAD
				mark_col = UiKit.BAD
		if bool(o[7]) and st == MissionDirector.ACTIVE and not adv:
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
		if pt == "" and bool(o[7]) and st == MissionDirector.ACTIVE and not adv:
			UiKit.mono_at(self, Vector2(x0 + W - UiKit.mono_w("OPTIONAL", 10), y), "OPTIONAL", 10, UiKit.FAINT)
		if pt != "" and st == MissionDirector.ACTIVE:
			var pu := pt.to_upper()
			var contested := pt.ends_with("contested") or pt == "clear area"
			UiKit.mono_at(self, Vector2(x0 + W - UiKit.mono_w(pu, 12), y), pu, 12, UiKit.WARN if contested else UiKit.ACCENT)
		y += 6.0 + lines.size() * 17.0
	if left >= 0.0:
		left = maxf(0.0, left)
		var lc := UiKit.WARN if left > 60.0 else UiKit.BAD
		UiKit.caps_at(self, Vector2(x0, y + 8), "Time left", 11, lc)
		var tl := "%02d:%02d" % [int(left) / 60, int(left) % 60]
		UiKit.mono_at(self, Vector2(x0 + W - UiKit.mono_w(tl, 13), y + 8), tl, 13, lc)
		y += 24.0
	if not word_lines.is_empty():
		# a quiet word: a tick of the accent, then the line, dim
		UiKit.rule(self, Vector2(x0, y + 2.5), Vector2(x0 + W, y + 2.5))
		draw_rect(Rect2(x0, y + 1.0, 3, 3), UiKit.ACCENT)
		var wy := y + 22.0
		for ln in word_lines:
			UiKit.text(self, Vector2(x0, wy), String(ln), 13, UiKit.TEXT if wy == y + 22.0 else UiKit.DIM, 400)
			wy += 17.0


## A finished objective that has had its moment: off the list.
func _folded(o: Array) -> bool:
	var st := int(o[2])
	if st != MissionDirector.DONE and st != MissionDirector.FAILED:
		return false
	return hud.world.time - float(_settled.get(String(o[1]), -1e9)) > FOLD_AFTER


## A short label above a readable instruction. Long key bindings and training
## directions wrap within the viewport instead of extending beyond its edges.
func _draw_banner(b: Array) -> void:
	var age: float = b[3]
	var training := bool(b[4])
	var a := 1.0 if UiMotion.reduced() else clampf((4.2 - age) / UiMotion.QUICK, 0.0, 1.0)
	if not UiMotion.reduced():
		if training:
			a *= clampf(age / UiMotion.QUICK, 0.0, 1.0)
		elif age < 0.12 and fmod(age, 0.12) >= 0.06:
			a = 0.0
	var col: Color = b[2]
	var cx := size.x * 0.5
	var bw := minf(680.0, size.x - 32.0)
	var lines := MapSymbols.wrap(Keys.fill(String(b[1])), 18, 500, bw - 40.0)
	var r := Rect2(cx - bw * 0.5, 120.0, bw, 44.0 + lines.size() * 24.0)
	draw_rect(r, UiKit.fa(UiKit.INK, 0.9 * a))
	draw_line(r.position + Vector2(0, 0.5), Vector2(r.end.x, r.position.y + 0.5), UiKit.fa(col, a), 1.0)
	draw_line(Vector2(r.position.x, r.end.y - 0.5), r.end - Vector2(0, 0.5), UiKit.fa(col, a), 1.0)
	var cap := String(b[0])
	UiKit.caps_at(self, Vector2(cx - UiKit.caps_w(cap, 12) * 0.5, r.position.y + 22), cap, 12, UiKit.fa(col, a))
	var y := r.position.y + 48.0
	for line in lines:
		var text := String(line)
		UiKit.text(self, Vector2(cx - UiKit.text_width(text, 18, 500) * 0.5, y), text, 18, UiKit.fa(UiKit.TEXT, a), 500)
		y += 24.0


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
