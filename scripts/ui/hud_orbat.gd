class_name HudOrbat
extends Control
## Order of battle: every unit you have, grouped (infantry, support teams,
## vehicles), each with its symbol, callsign, strength, what it's been told to
## do and how it's doing (in contact, pinned, casualties, low on ammo).
## Click a row to select the unit and look at it, Shift+click to add it to
## the selection, double-click to zoom in on it. Observers see both sides.

const ROW_H := 40.0
const HEAD_H := 30.0
const SEC_H := 22.0
const W := 284.0

var hud: Hud
var open := true
var _scroll := 0.0
var _content_h := 0.0
var _rows: Array = []  # [Rect2, kind ("sq"/"veh"), id, commandable]
var _head := Rect2()
var _hover := -1


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
	elif ev is InputEventMouseButton and ev.pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = clampf(_scroll + (-36.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 36.0), 0.0, maxf(0.0, _content_h - size.y))
			accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if _head.has_point(mb.position):
			toggle()
			accept_event()
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
	open = not open
	Settings.v["orbat"] = open
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
			if s.sid == id and s.life != Soldier.Life.DEAD and s.life != Soldier.Life.HIDDEN:
				c += s.position
				n += 1
		if n > 0:
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
		if v:
			at = v.position
		if mine or w.local_team < 0:
			if not add:
				inp.clear_selection()
			if id in inp.sel_vehicles:
				inp.sel_vehicles.erase(id)
			else:
				inp.sel_vehicles.append(id)
	Sfx.ui("click")
	if at != Vector3.INF and w.cam:
		w.cam.glide_to(at, 22.0 if dbl else -1.0)
		if w.director:
			w.director.active = false


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	var w := hud.world
	if w == null or w.input == null:
		return
	_rows.clear()
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
		if alive > 0:
			sqs.append(sid)
	var vehs := []
	for v in w.vehicles:
		if v.team in teams and v.vkind != "truck" and not v.gone:
			vehs.append(v)
	# header
	var title := "ORDER OF BATTLE"
	var sub := "%d units" % (sqs.size() + vehs.size())
	_head = Rect2(0, 0, W, HEAD_H)
	draw_style_box(UiKit.boxc(UiKit.PANEL, 7, UiKit.LINE, 1, 0.0, 8), Rect2(0, 0, W, HEAD_H if not open else size.y))
	UiKit.text(self, Vector2(12, 19), title, 11, UiKit.ACCENT, 700)
	UiKit.text(self, Vector2(18 + UiKit.text_width(title, 11, 700), 19), sub, 11, UiKit.DIM)
	var ok := Keys.label("orbat")
	if ok != "":
		UiKit.text(self, Vector2(W - 32 - UiKit.text_width(ok, 11, 700), 19), ok, 11, UiKit.DIM, 700)
	var cc := Vector2(W - 20, 15)
	var chev := PackedVector2Array([cc + Vector2(-4, -2), cc + Vector2(0, 2), cc + Vector2(4, -2)]) if open else PackedVector2Array([cc + Vector2(-2, -4), cc + Vector2(2, 0), cc + Vector2(-2, 4)])
	draw_polyline(chev, UiKit.DIM, 1.6, true)
	if not open:
		return
	draw_line(Vector2(10, HEAD_H), Vector2(W - 10, HEAD_H), UiKit.LINE, 1.0)
	# body (scrolling, clipped)
	var y := HEAD_H + 4.0 - _scroll
	var top := HEAD_H + 2.0
	var bottom := size.y - 6.0
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
			y = _section(y, "INFANTRY", top, bottom)
			for sid in mine_sqs:
				y = _squad_row(y, int(sid), by_sid[sid], top, bottom)
		if not support.is_empty():
			y = _section(y, "SUPPORT TEAMS", top, bottom)
			for sid in support:
				y = _squad_row(y, int(sid), by_sid[sid], top, bottom)
		if not tv.is_empty():
			y = _section(y, "VEHICLES", top, bottom)
			for v in tv:
				y = _vehicle_row(y, v, top, bottom)
	_content_h = y + _scroll + 8.0
	if _content_h > size.y:
		# scroll bar
		var frac := size.y / _content_h
		var bh := maxf(24.0, (size.y - HEAD_H - 8.0) * frac)
		var by := HEAD_H + 4.0 + (_scroll / maxf(1.0, _content_h - size.y)) * (size.y - HEAD_H - 8.0 - bh)
		draw_rect(Rect2(W - 5, by, 2, bh), Color(1, 1, 1, 0.25))


func _visible_row(y: float, h: float, top: float, bottom: float) -> bool:
	return y >= top - 1.0 and y + h <= bottom


func _team_header(y: float, t: int, top: float, bottom: float) -> float:
	if _visible_row(y, SEC_H, top, bottom):
		var tc: Color = Defs.TEAM_COLORS[t]
		draw_rect(Rect2(10, y + 6, 3, 12), tc)
		UiKit.text(self, Vector2(19, y + 16), String(Defs.TEAM_NAMES[t]).to_upper(), 11, tc.lightened(0.3), 700)
	return y + SEC_H


func _section(y: float, label: String, top: float, bottom: float) -> float:
	if _visible_row(y, SEC_H, top, bottom):
		UiKit.text(self, Vector2(12, y + 15), label, 10, UiKit.DIM, 700)
		draw_line(Vector2(16 + UiKit.text_width(label, 10, 700), y + 11), Vector2(W - 12, y + 11), Color(1, 1, 1, 0.06), 1.0)
	return y + SEC_H - 2.0


func _row_bg(r: Rect2, sel: bool, idx: int) -> void:
	if sel:
		draw_style_box(UiKit.boxc(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.13), 5, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.35), 1, 0.0), r)
		draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(2.5, r.size.y - 12)), UiKit.ACCENT)
	elif idx == _hover:
		draw_style_box(UiKit.boxc(Color(1, 1, 1, 0.06), 5, Color(0, 0, 0, 0), 0, 0.0), r)


func _squad_row(y: float, sid: int, mem: Array, top: float, bottom: float) -> float:
	var w := hud.world
	if not _visible_row(y, ROW_H, top, bottom):
		return y + ROW_H
	var r := Rect2(6, y, W - 14, ROW_H - 3)
	var team: int = mem[0].team
	var mine: bool = mem[0].owner_peer == w.local_peer
	var idx := _rows.size()
	_rows.append([r, "sq", sid, mine])
	_row_bg(r, sid in w.input.sel_squads, idx)
	var st: Dictionary = hud.squad_state(sid, mem)
	var sym: Array = MapSymbols.squad_symbol(mem)
	MapSymbols.nato(self, Vector2(r.position.x + 20, y + 19), 24.0, team == w.local_team or w.local_team < 0, team, sym[0], "", 1.0)
	var by := int(w.coop.sel_sq.get(sid, 0)) if w.coop else 0
	if by != 0:
		# a co-commander has it selected: a ring in his colour
		draw_arc(Vector2(r.position.x + 20, y + 19), 15.5, 0.0, TAU, 24, Net.player_color(by), 1.6, true)
	var cs := Squad.callsign_of(team, sid)
	var x0 := r.position.x + 40.0
	UiKit.text(self, Vector2(x0, y + 15), cs.to_upper(), 12, UiKit.TEXT, 700)
	var tag := String(sym[1])
	var tx := x0 + UiKit.text_width(cs.to_upper(), 12, 700) + 6.0
	if tag != "":
		UiKit.text(self, Vector2(tx, y + 15), tag, 10, UiKit.DIM, 700)
		tx += UiKit.text_width(tag, 10, 700) + 6.0
	if not mine and w.local_team >= 0:
		_owner_tag(r, Vector2(tx, y + 15), int(mem[0].owner_peer), r.end.x - 10.0 - mem.size() * 6.0)
	# strength: a pip per man
	var px := r.end.x - 6.0 - mem.size() * 6.0
	for s in mem:
		var pc := Color(0.9, 0.93, 0.88)
		if s.life == Soldier.Life.DOWNED:
			pc = UiKit.BAD
		elif s.life == Soldier.Life.DEAD:
			pc = Color(1, 1, 1, 0.14)
		draw_rect(Rect2(px, y + 7, 4, 8), pc)
		px += 6.0
	# what it's doing
	var ox := x0
	if st.glyph != "":
		MapSymbols.glyph(self, st.glyph, Vector2(x0 + 5, y + 28), 5.5, st.col, 1.0, false)
		ox += 14.0
	var line: String = st.text
	var maxw := r.end.x - ox - 52.0
	while line.length() > 4 and UiKit.text_width(line, 11) > maxw:
		line = line.substr(0, line.length() - 2)
	if line != st.text:
		line = line.strip_edges() + "…"
	UiKit.text(self, Vector2(ox, y + 32), line, 11, st.col)
	# alerts on the right
	var ax := r.end.x - 10.0
	if st.contact:
		_burst(Vector2(ax, y + 28))
		ax -= 16.0
	if st.pinned:
		MapSymbols.glyph(self, "pinned", Vector2(ax, y + 28), 6.0, UiKit.BAD, 1.0, false)
		ax -= 16.0
	if st.wounded > 0:
		MapSymbols.glyph(self, "medic", Vector2(ax, y + 28), 5.0, UiKit.BAD, 1.0, false)
		ax -= 14.0
	if st.low_ammo:
		MapSymbols.glyph(self, "noammo", Vector2(ax, y + 28), 5.5, UiKit.WARN, 1.0, false)
	return y + ROW_H


func _vehicle_row(y: float, v, top: float, bottom: float) -> float:
	var w := hud.world
	if not _visible_row(y, ROW_H, top, bottom):
		return y + ROW_H
	var r := Rect2(6, y, W - 14, ROW_H - 3)
	var mine: bool = v.owner_peer == w.local_peer
	var idx := _rows.size()
	_rows.append([r, "veh", v.eid, mine])
	_row_bg(r, v.eid in w.input.sel_vehicles, idx)
	var vs: Array = MapSymbols.vehicle_symbol(v.vkind)
	MapSymbols.nato(self, Vector2(r.position.x + 20, y + 19), 24.0, v.team == w.local_team or w.local_team < 0, v.team, vs[0], "", 1.0)
	var by := int(w.coop.sel_veh.get(v.eid, 0)) if w.coop else 0
	if by != 0:
		draw_arc(Vector2(r.position.x + 20, y + 19), 15.5, 0.0, TAU, 24, Net.player_color(by), 1.6, true)
	var x0 := r.position.x + 40.0
	var vn := String(v.display_name()).to_upper()
	UiKit.text(self, Vector2(x0, y + 15), vn, 12, UiKit.TEXT, 700)
	if not mine and w.local_team >= 0:
		_owner_tag(r, Vector2(x0 + UiKit.text_width(vn, 12, 700) + 6.0, y + 15), int(v.owner_peer), r.end.x - 72.0)
	var hf: float = v.health_frac()
	var bx := r.end.x - 66.0
	draw_rect(Rect2(bx, y + 9, 58, 4), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(bx, y + 9, 58 * hf, 4), Color(1.0, 0.3, 0.25).lerp(UiKit.GOOD, hf))
	var txt := "Holding"
	var col := UiKit.DIM
	if (v.flags & Vehicle.F_TRACK) != 0:
		txt = "Immobilised - needs engineers"
		col = UiKit.BAD
	elif (v.flags & Vehicle.F_FIRE) != 0:
		txt = "Engaging"
		col = Color(1.0, 0.75, 0.45)
	elif hf < 0.4:
		txt = "Badly damaged"
		col = UiKit.BAD
	elif Defs.flat(v.position - v._last_pos).length() > 0.02:
		txt = "Moving"
		col = UiKit.TEXT
	UiKit.text(self, Vector2(x0, y + 32), txt, 11, col)
	return y + ROW_H


## Whose a unit is when it isn't yours: another commander's name in his colour
## (with his colour down the row's edge), or the AI's.
func _owner_tag(r: Rect2, at: Vector2, own: int, maxx := INF) -> void:
	if own > 0 and Net.players.has(own):
		var oc := Net.player_color(own)
		draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(2.5, r.size.y - 12)), oc)
		var nm := Net.player_name(own).to_upper()
		if nm.length() > 12:
			nm = nm.substr(0, 11) + "…"
		if at.x + UiKit.text_width(nm, 9, 700) > maxx:
			nm = hud.world.coop.initials(own) if hud.world.coop else nm.substr(0, 2)
		UiKit.text(self, at, nm, 9, oc, 700)
	else:
		UiKit.text(self, at, "AI" if own < 0 else "ALLY", 9, UiKit.DIM, 700)


func _burst(c: Vector2) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0 + t
		var rr := (5.5 if i % 2 == 0 else 2.6) + sin(t * 11.0) * 0.6
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	MapSymbols.poly(self, pts, Color(1.0, 0.58, 0.22, 0.95))
