class_name HudOrbat
extends Control
## Order of battle: every allied unit, grouped (infantry, support teams,
## vehicles), a line each (docs/UI.md, Row): its symbol, callsign, what it's
## doing as a code (MOV D8, PINNED · DEF E4) and its strength in pips. It sits
## in the Units drawer: a header, then rows with a rule under each.
## Click selects without moving the camera; Shift-click adds. Double-click
## or Enter focuses the unit and returns to battle. Observers see both sides.

const ROW_H := 40.0
const HEAD_H := 22.0
const SEC_H := 20.0
const W := 344.0

var hud: Hud
var open := true
var query := ""
var _terms := PackedStringArray()
var filter_kind := "all"
var _scroll := 0.0
var _content_h := 0.0
var _rows: Array = []  # [Rect2, kind ("sq"/"veh"), id, commandable]
var _entries: Array = []  # every result, including those outside the scroll window
var _cursor := 0
var _head := Rect2()
var _hover := -1


func set_query(value: String) -> void:
	query = value.strip_edges().to_lower()
	_terms = query.split(" ", false)
	_scroll = 0.0
	_cursor = 0
	_entries.clear()
	_rows.clear()
	queue_redraw()


func set_filter(value: String) -> void:
	filter_kind = value
	_scroll = 0.0
	_cursor = 0
	_entries.clear()
	_rows.clear()
	queue_redraw()


func move_cursor(step: int) -> void:
	if _entries.is_empty():
		return
	_cursor = clampi(_cursor + step, 0, _entries.size() - 1)
	var r: Rect2 = _entries[_cursor][0]
	if r.position.y - _scroll < HEAD_H:
		_scroll = r.position.y - HEAD_H
	elif r.end.y - _scroll > size.y:
		_scroll = r.end.y - size.y
	queue_redraw()


func activate_cursor() -> void:
	if _entries.is_empty():
		return
	var entry: Array = _entries[clampi(_cursor, 0, _entries.size() - 1)]
	_pick(String(entry[1]), int(entry[2]), bool(entry[3]), false, true)


func focus_selected() -> void:
	var inp = hud.world.input
	if not inp.sel_squads.is_empty():
		_pick("sq", int(inp.sel_squads[0]), true, false, true)
	elif not inp.sel_vehicles.is_empty():
		_pick("veh", int(inp.sel_vehicles[0]), true, false, true)


func matches_unit(search_text: String, category: String, attention: bool) -> bool:
	if filter_kind == "attention" and not attention:
		return false
	if filter_kind in ["infantry", "vehicles"] and category != filter_kind:
		return false
	var text := search_text.to_lower()
	for term in _terms:
		if not text.contains(term):
			return false
	return true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	open = bool(Settings.get_v("orbat"))


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := -1
		for i in _rows.size():
			if (_rows[i][0] as Rect2).has_point(ev.position):
				h = i
		if h != _hover:
			_hover = h
			queue_redraw()
	elif ev is InputEventPanGesture:
		# two fingers on a trackpad scroll the list
		_scroll = clampf(_scroll + (ev as InputEventPanGesture).delta.y * 30.0, 0.0, maxf(0.0, _content_h - size.y))
		accept_event()
	elif ev is InputEventMouseButton and ev.pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = clampf(_scroll + (-ROW_H if mb.button_index == MOUSE_BUTTON_WHEEL_UP else ROW_H), 0.0, maxf(0.0, _content_h - size.y))
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		for r in _rows:
			if (r[0] as Rect2).has_point(mb.position):
				_pick(String(r[1]), int(r[2]), bool(r[3]), mb.shift_pressed, mb.double_click)
				accept_event()
				return


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != -1:
		_hover = -1
		queue_redraw()


func content_h() -> float:
	return _content_h


func toggle() -> void:
	hud.set_workspace("battle")
	Sfx.ui("click")
	queue_redraw()


func _pick(kind: String, id: int, mine: bool, add: bool, dbl: bool) -> void:
	var w := hud.world
	var inp = w.input
	if inp == null:
		return
	var at := Vector3.INF
	if kind == "sq":
		var c := Vector3.ZERO
		var n := 0
		for s in w.soldiers:
			if s.sid == id and not s.gone and s.life != Soldier.Life.DEAD:
				c += s.riding.position if is_instance_valid(s.riding) else s.position
				n += 1
		if n == 0:
			return
		at = c / n
		if mine or w.local_team < 0:
			if not add:
				inp.clear_selection()
			if id in inp.sel_squads:
				inp.sel_squads.erase(id)
			else:
				inp.sel_squads.append(id)
	else:
		var v = w.entity(id)
		if v == null or v.gone:
			return
		at = v.position
		if mine or w.local_team < 0:
			if not add:
				inp.clear_selection()
			if id in inp.sel_vehicles:
				inp.sel_vehicles.erase(id)
			else:
				inp.sel_vehicles.append(id)
	Sfx.ui("click")
	if hud.squad_search:
		hud.squad_search.release_focus()
	if dbl and at != Vector3.INF and w.cam:
		w.cam.glide_to(at, 32.0)
		hud.set_workspace("battle")
		if w.director:
			w.director.active = false


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	var started := Time.get_ticks_usec()
	_draw_content()
	if hud and hud.world:
		hud.world.vp("roster drawing", started)


func _draw_content() -> void:
	var w := hud.world
	if w == null or w.input == null:
		return
	_rows.clear()
	_entries.clear()
	_scroll = clampf(_scroll, 0.0, maxf(0.0, _content_h - size.y))
	var lt: int = w.local_team
	var teams: Array = [lt] if lt >= 0 else [0, 1]
	# gather: squads by sid, vehicles
	var by_sid := {}
	for s in w.soldiers:
		if s.sid == 0 or s.team < 0 or not s.team in teams:
			continue
		if not by_sid.has(s.sid):
			by_sid[s.sid] = []
		by_sid[s.sid].append(s)
	var sqs := []
	for sid in by_sid:
		var mem: Array = by_sid[sid]
		var alive := 0
		for s in mem:
			if s.life == Soldier.Life.ALIVE or s.life == Soldier.Life.HIDDEN or s.life == Soldier.Life.DOWNED:
				alive += 1
		var search_text := Squad.callsign_of(mem[0].team, int(sid))
		var symbol: Array = MapSymbols.squad_symbol(mem)
		search_text += " " + String(symbol[0]) + " " + String(symbol[1])
		if not query.is_empty():
			for soldier in mem:
				search_text += " " + String(soldier.udef.get("name", ""))
		var attention := false
		if not query.is_empty() or filter_kind == "attention":
			var state: Dictionary = hud.squad_state(int(sid), mem)
			search_text += " " + String(state.code) + (" low ammo" if state.low_ammo else "")
			attention = state.pinned or state.low_ammo or int(state.wounded) > 0 or int(state.mstate) >= 3
		if alive > 0 and matches_unit(search_text, "infantry", attention):
			sqs.append(sid)
	var vehs := []
	for v in w.vehicles:
		if v.team in teams and v.vkind != "truck" and not v.gone and matches_unit(String(v.display_name()), "vehicles", v.health_frac() < 0.6 or (v.flags & Vehicle.F_TRACK) != 0):
			vehs.append(v)
	# One hierarchy: result count, section, unit name, then its status.
	_head = Rect2(0, 0, W, HEAD_H)
	var x := UiKit.caps_at(self, Vector2(0, 15), "Results", 11, UiKit.DIM)
	x += 8.0 + UiKit.mono_at(self, Vector2(x + 8.0, 15), "%02d" % (sqs.size() + vehs.size()), 11, UiKit.TEXT)
	UiKit.rule(self, Vector2(x + 10.0, 11.5), Vector2(W, 11.5))
	if not open:
		return
	if sqs.is_empty() and vehs.is_empty():
		UiKit.caps_at(self, Vector2(0, HEAD_H + 24), "No matching units", 12, UiKit.DIM)
		_scroll = 0.0
		_content_h = HEAD_H + 42.0
		return
	# body (scrolling, clipped)
	var y := HEAD_H + 2.0 - _scroll
	var top := HEAD_H
	var bottom := size.y - 2.0
	for t in teams:
		var mine_sqs := []
		var support := []
		for sid in sqs:
			var mem: Array = by_sid[sid]
			if mem[0].team != t:
				continue
			var sym: Array = MapSymbols.squad_symbol(mem)
			if String(sym[1]) != "" or mem.size() <= 2:
				support.append(sid)
			else:
				mine_sqs.append(sid)
		var tv := []
		for v in vehs:
			if v.team == t:
				tv.append(v)
		if teams.size() > 1:
			y = _team_header(y, t, top, bottom)
		if not mine_sqs.is_empty():
			y = _section(y, "Infantry", top, bottom)
			for sid in mine_sqs:
				y = _squad_row(y, int(sid), by_sid[sid], top, bottom)
		if not support.is_empty():
			y = _section(y, "Support", top, bottom)
			for sid in support:
				y = _squad_row(y, int(sid), by_sid[sid], top, bottom)
		if not tv.is_empty():
			y = _section(y, "Vehicles", top, bottom)
			for v in tv:
				y = _vehicle_row(y, v, top, bottom)
	_content_h = y + _scroll + 4.0
	if _content_h > size.y:
		# scroll bar: a hairline at the edge
		var frac := size.y / _content_h
		var bh := maxf(24.0, (size.y - HEAD_H - 4.0) * frac)
		var by := HEAD_H + 2.0 + (_scroll / maxf(1.0, _content_h - size.y)) * (size.y - HEAD_H - 4.0 - bh)
		draw_rect(Rect2(W + 3, by, 2, bh), UiKit.RULE2)


func _visible_row(y: float, h: float, top: float, bottom: float) -> bool:
	return y >= top - 1.0 and y + h <= bottom


func _team_header(y: float, t: int, top: float, bottom: float) -> float:
	if _visible_row(y, SEC_H, top, bottom):
		var tc: Color = Defs.TEAM_COLORS[t]
		draw_rect(Rect2(0, y + 7, 7, 7), tc)
		UiKit.caps_at(self, Vector2(13, y + 15), Defs.TEAM_NAMES[t], 11, tc.lightened(0.25))
	return y + SEC_H


func _section(y: float, label: String, top: float, bottom: float) -> float:
	if _visible_row(y, SEC_H, top, bottom):
		UiKit.caps_at(self, Vector2(0, y + 15), label, 10, UiKit.FAINT)
	return y + SEC_H


## A row's ground: the selected one washed with the accent fading out across
## it, the one under the cursor faintly lit; a rule under every one.
func _row_bg(r: Rect2, sel: bool, idx: int, keyboard := false) -> void:
	if sel or keyboard:
		var a := UiKit.fa(UiKit.ACCENT, 0.22)
		var b := UiKit.fa(UiKit.ACCENT, 0.05)
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([a, b, b, a]))
	elif idx == _hover:
		draw_rect(r, UiKit.fa(UiKit.TEXT, 0.05))
	UiKit.rule(self, Vector2(r.position.x, r.end.y - 0.5), Vector2(r.end.x, r.end.y - 0.5))


## A code's colour: dim unless it needs the commander.
func _code_col(st: Dictionary, sel: bool) -> Color:
	var code := String(st.code)
	if int(st.get("mstate", 0)) >= 3 or code.begins_with("ROUTING") or code.contains("FALL BACK"):
		return UiKit.BAD
	if bool(st.pinned):
		return UiKit.WARN
	return UiKit.ACCENT if sel else UiKit.DIM


func _squad_row(y: float, sid: int, mem: Array, top: float, bottom: float) -> float:
	var w := hud.world
	var mine: bool = w.input.is_mine(mem[0])
	_entries.append([Rect2(0, y + _scroll, W, ROW_H), "sq", sid, mine])
	var keyboard := _entries.size() - 1 == _cursor and hud.squad_search.has_focus()
	if not _visible_row(y, ROW_H, top, bottom):
		return y + ROW_H
	var r := Rect2(0, y, W, ROW_H)
	var team: int = mem[0].team
	var idx := _rows.size()
	var sel: bool = sid in w.input.sel_squads
	_rows.append([r, "sq", sid, mine])
	_row_bg(r, sel, idx, keyboard)
	var st: Dictionary = hud.squad_state(sid, mem)
	var sym: Array = MapSymbols.squad_symbol(mem)
	MapSymbols.nato(self, Vector2(11, y + ROW_H * 0.5), 17.0, team == w.local_team or w.local_team < 0, team, sym[0], "", 1.0)
	var by := int(w.coop.sel_sq.get(sid, 0)) if w.coop else 0
	if by != 0:
		# a co-commander has it selected: his colour down the row's edge
		draw_rect(Rect2(0, y + 3, 2, ROW_H - 6), Net.player_color(by))
	var x := 26.0 + UiKit.caps_at(self, Vector2(26, y + 17), Squad.callsign_of(team, sid), 14, UiKit.ACCENT if sel else UiKit.TEXT)
	var tag := String(sym[1])
	if tag != "":
		x += 5.0 + UiKit.caps_at(self, Vector2(x + 5.0, y + 17), tag, 10, UiKit.FAINT)
	# strength: a pip per man, at the end
	var alive := 0
	var hurt := 0
	for s in mem:
		if s.life == Soldier.Life.DOWNED:
			hurt += 1
		elif s.life != Soldier.Life.DEAD:
			alive += 1
	var pw := mem.size() * 5.0 - 2.0
	UiKit.pips(self, Vector2(W - pw - 2.0, y + 8), alive, hurt, mem.size() - alive - hurt)
	# what it's doing, as a code, cut to fit
	var cx := 26.0
	var code := String(st.code)
	if st.low_ammo:
		code += " · LOW AMMO"
	var maxw := W - cx - 12.0
	while code.length() > 3 and UiKit.mono_w(code, 11) > maxw:
		code = code.substr(0, code.length() - 2)
	UiKit.mono_at(self, Vector2(cx, y + 33), code, 11, _code_col(st, sel))
	return y + ROW_H


func _vehicle_row(y: float, v, top: float, bottom: float) -> float:
	var w := hud.world
	var mine: bool = w.input.is_mine(v)
	_entries.append([Rect2(0, y + _scroll, W, ROW_H), "veh", v.eid, mine])
	var keyboard := _entries.size() - 1 == _cursor and hud.squad_search.has_focus()
	if not _visible_row(y, ROW_H, top, bottom):
		return y + ROW_H
	var r := Rect2(0, y, W, ROW_H)
	var idx := _rows.size()
	var sel: bool = v.eid in w.input.sel_vehicles
	_rows.append([r, "veh", v.eid, mine])
	_row_bg(r, sel, idx, keyboard)
	var vs: Array = MapSymbols.vehicle_symbol(v.vkind)
	MapSymbols.nato(self, Vector2(11, y + ROW_H * 0.5), 17.0, v.team == w.local_team or w.local_team < 0, v.team, vs[0], "", 1.0)
	var by := int(w.coop.sel_veh.get(v.eid, 0)) if w.coop else 0
	if by != 0:
		draw_rect(Rect2(0, y + 3, 2, ROW_H - 6), Net.player_color(by))
	# A long vehicle name must never run into its health readout.
	var name: String = v.display_name()
	var limit := W - 26.0 - 52.0
	if UiKit.caps_w(name, 14) > limit:
		while name.length() > 1 and UiKit.caps_w(name + "…", 14) > limit:
			name = name.left(-1)
		name += "…"
	UiKit.caps_at(self, Vector2(26, y + 17), name, 14, UiKit.ACCENT if sel else UiKit.TEXT)
	var hf: float = v.health_frac()
	UiKit.steps(self, Vector2(W - 40, y + 8), hf * 6.0, 6, UiKit.GOOD if hf > 0.6 else (UiKit.WARN if hf > 0.3 else UiKit.BAD), 5.0, 9.0)
	var code := "HOLD"
	var col := UiKit.ACCENT if sel else UiKit.DIM
	if (v.flags & Vehicle.F_TRACK) != 0:
		code = "IMMOBILISED"
		col = UiKit.BAD
	elif (v.flags & Vehicle.F_FIRE) != 0:
		code = "ENGAGING"
		col = UiKit.WARN
	elif hf < 0.4:
		code = "BADLY DAMAGED"
		col = UiKit.BAD
	elif Defs.flat(v.position - v._last_pos).length() > 0.02:
		code = "MOVING"
	UiKit.mono_at(self, Vector2(26, y + 33), code, 11, col)
	return y + ROW_H
