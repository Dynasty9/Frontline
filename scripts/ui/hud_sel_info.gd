class_name HudSelInfo
extends Control

var hud: Hud
var need_h := 120.0
var _rows: Array = []  # [Rect2, soldier eid] - click to command just him

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for r in _rows:
			if (r[0] as Rect2).has_point(ev.position):
				var s: Soldier = hud.world.entity(int(r[1])) as Soldier
				if s:
					hud.world.input.select_unit(s)
					if ev.double_click and hud.world.cam:
						hud.world.cam.glide_to(s.position)
				accept_event()
				return

func _draw() -> void:
	var w := hud.world
	var inp := w.input
	var y := 16.0
	_rows.clear()
	if inp.sel_unit != 0:
		var su: Soldier = w.entity(inp.sel_unit) as Soldier
		if su:
			_unit_detail(su)
			need_h = 96.0
			return
	if not inp.sel_squads.is_empty():
		var by_sid := {}
		for s in w.soldiers:
			if s.sid in inp.sel_squads and (s.owner_peer == w.local_peer or w.local_team < 0):
				if not by_sid.has(s.sid):
					by_sid[s.sid] = []
				by_sid[s.sid].append(s)
		if by_sid.size() == 1:
			_squad_detail(by_sid.values()[0])
			need_h = 66.0 + mini((by_sid.values()[0] as Array).size(), 6) * 21.0
			return
		var rows := 0
		for sid in inp.sel_squads:
			if not by_sid.has(sid) or rows >= 6:
				continue
			rows += 1
			var mem: Array = by_sid[sid]
			var sym := MapSymbols.squad_symbol(mem)
			MapSymbols.nato(self, Vector2(16, y + 8), 22.0, true, mem[0].team, sym[0])
			var cs := Squad.callsign_of(mem[0].team, int(sid))
			UiKit.text(self, Vector2(34, y + 12), cs.to_upper(), 12, UiKit.ACCENT, 600)
			UiKit.text(self, Vector2(38 + UiKit.text_width(cs.to_upper(), 12, 600), y + 12), _squad_name(mem), 11, UiKit.DIM)
			var alive := 0
			var mounted := false
			for s in mem:
				if _fit(s):
					alive += 1
				if s.riding != null:
					mounted = true
			if mounted:
				UiKit.text(self, Vector2(size.x - 124, y + 12), "MOUNTED", 10, UiKit.DIM, 600)
			UiKit.text(self, Vector2(size.x - 54, y + 12), "%d/%d" % [alive, mem.size()], 12, UiKit.TEXT if alive * 2 > mem.size() else UiKit.BAD, 600)
			var x := 190.0
			for s in mem:
				_pip(Vector2(x, y), s)
				x += 28.0
			y += 26.0
		need_h = y + 4.0
		return
	if not inp.sel_vehicles.is_empty():
		for id in inp.sel_vehicles:
			var v: Vehicle = w.entity(id)
			if v == null:
				continue
			UiKit.text(self, Vector2(4, y + 10), v.display_name(), 14, UiKit.TEXT, 600)
			_bar(Vector2(180, y), Vector2(160, 8), v.health_frac(), UiKit.GOOD)
			if (v.flags & Vehicle.F_TRACK) != 0:
				UiKit.text(self, Vector2(352, y + 10), "Track broken - engineers can repair", 12, UiKit.BAD)
			y += 24.0
		need_h = y + 4.0
		return
	var st: Structure = w.entity(inp.sel_structure) as Structure
	if st:
		_structure_info(st)
		need_h = 110.0
		return
	need_h = 30.0
	var e: Entity = hud._inspect if hud._inspect_t > 0.0 and hud._inspect and not hud._inspect.gone else null
	if e:
		UiKit.text(self, Vector2(4, 20), _describe(e), 14, UiKit.TEXT)

func _squad_detail(mem: Array) -> void:
	var cs := Squad.callsign_of(mem[0].team, mem[0].sid) if not mem.is_empty() else ""
	UiKit.text(self, Vector2(4, 16), cs.to_upper(), 13, UiKit.ACCENT, 600)
	UiKit.text(self, Vector2(12 + UiKit.text_width(cs.to_upper(), 13, 600), 16), _squad_name(mem), 12, UiKit.DIM)
	var alive := 0
	for s in mem:
		if _fit(s):
			alive += 1
	UiKit.text(self, Vector2(size.x - 120, 16), "%d / %d fighting" % [alive, mem.size()], 12, UiKit.DIM)
	# what it's doing, and where an attack has got to
	var st: Dictionary = hud.squad_state(mem[0].sid, mem)
	if int(st.morale) >= 0:
		# its nerve: steady, shaken, breaking, routed
		var mcol: Color = [Color(0.6, 0.85, 0.5), Color(1.0, 0.8, 0.35), Color(1.0, 0.52, 0.3), UiKit.BAD][int(st.mstate)]
		var mtxt: String = SquadBrain.STATE_NAMES[int(st.mstate)].to_upper()
		UiKit.text(self, Vector2(size.x - 132 - UiKit.text_width(mtxt, 11, 700), 16), mtxt, 11, mcol, 700)
	var ox := 4.0
	if String(st.glyph) != "":
		MapSymbols.glyph(self, st.glyph, Vector2(10, 35), 6.0, st.col, 1.0, false)
		ox = 22.0
	UiKit.text(self, Vector2(ox, 40), st.text, 12, st.col, 600)
	var o: Array = hud.orders.get(mem[0].sid, [])
	if not o.is_empty() and o[6] != null:
		_stepper(Vector2(size.x - 236, 30), String(o[6][0]))
	var y := 60.0
	var col_w := size.x * 0.5
	for i in mini(mem.size(), 12):
		var s: Soldier = mem[i]
		var x := 0.0 if i < 6 else col_w
		var yy := y + (i % 6) * 21.0
		if s.life == Soldier.Life.ALIVE and hud.world.input.can_command():
			var rr := Rect2(x, yy - 2, col_w - 6, 20)
			_rows.append([rr, s.eid])
			if rr.has_point(get_local_mouse_position()):
				draw_style_box(UiKit.boxc(Color(1, 1, 1, 0.07), 4, Color(0, 0, 0, 0), 0, 0.0), rr)
		_pip(Vector2(x + 2, yy), s, true)
		var nm := s.sname
		if (s.flags & Soldier.F_LEADER) != 0:
			nm = "SL  " + nm
		UiKit.text(self, Vector2(x + 30, yy + 12), nm, 13, UiKit.TEXT if s.life == Soldier.Life.ALIVE else UiKit.DIM)
		var dt := s.doing_text()
		if s.life == Soldier.Life.DEAD:
			dt = "KIA"
		var cat: String = s.doing_cat() if s.life != Soldier.Life.DEAD else "idle"
		UiKit.text(self, Vector2(x + 34 + UiKit.text_width(nm, 13), yy + 12), dt, 12, Hud.CAT_COLORS.get(cat, UiKit.DIM).darkened(0.05))

## PLAN > MOVE > ASSAULT > SECURE, the current step lit.
func _stepper(at: Vector2, phase: String) -> void:
	var steps := ["PLAN", "MOVE", "ASSAULT", "SECURE"]
	var cur := {"plan": 0, "move": 1, "fix": 1, "assault": 2, "fallback": 2}.get(phase, 3) as int
	var x := at.x
	for i in steps.size():
		var lab: String = steps[i]
		var tw := UiKit.text_width(lab, 10, 700)
		var r := Rect2(x, at.y, tw + 14, 18)
		var on := i == cur
		var done := i < cur
		var bg := Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.22) if on else (Color(1, 1, 1, 0.07) if done else Color(0, 0, 0, 0.25))
		var bd := UiKit.ACCENT if on else Color(1, 1, 1, 0.12)
		draw_style_box(UiKit.boxc(bg, 9, bd, 1, 0.0), r)
		var tc := UiKit.ACCENT if on else (UiKit.TEXT if done else UiKit.DIM)
		if phase == "fix" and i == 1 or phase == "fallback" and i == 2:
			tc = UiKit.BAD
		UiKit.text(self, Vector2(x + 7, at.y + 13), lab, 10, tc, 700)
		x += r.size.x + 4.0


func _unit_detail(s: Soldier) -> void:
	UiKit.text(self, Vector2(4, 16), s.sname.to_upper(), 13, UiKit.ACCENT, 600)
	var ut := String(s.udef.get("name", s.utype)).capitalize()
	UiKit.text(self, Vector2(10 + UiKit.text_width(s.sname.to_upper(), 13, 600), 16), ut, 12, UiKit.DIM)
	_pip(Vector2(4, 30), s)
	UiKit.text(self, Vector2(34, 43), s.doing_text() if s.doing_text() != "" else "Waiting for orders", 13, Hud.CAT_COLORS.get(s.doing_cat(), UiKit.DIM))
	UiKit.text(self, Vector2(4, 68), "Health", 11, UiKit.DIM, 600)
	_bar(Vector2(52, 62), Vector2(120, 6), s.health_frac(), Color(1.0, 0.3, 0.25).lerp(UiKit.GOOD, s.health_frac()))
	UiKit.text(self, Vector2(186, 68), "Ammo", 11, UiKit.DIM, 600)
	_bar(Vector2(224, 62), Vector2(120, 6), s.ammo_fraction(), Color(0.45, 0.7, 1.0))
	var cov := hud.world.terrain.describe(s.position) if hud.world.terrain else ""
	UiKit.text(self, Vector2(4, 88), "Under your direct command  -  " + cov, 12, UiKit.DIM)

func _squad_name(mem: Array) -> String:
	if mem.is_empty():
		return "Squad"
	var sq = hud.world.squads.get(mem[0].sid)
	if sq != null and Defs.SQUADS.has(sq.kind):
		return Defs.SQUADS[sq.kind].name
	# clients don't keep squad objects: the closest roster that fits
	var types := {}
	for s in mem:
		types[s.utype] = true
	var best := "Squad"
	var best_d := 99
	for k in Defs.SQUADS:
		var ok := true
		for ut in Defs.SQUADS[k].members:
			if not types.has(ut):
				ok = false
		var d := absi((Defs.SQUADS[k].members as Array).size() - mem.size())
		if ok and d < best_d:
			best = Defs.SQUADS[k].name
			best_d = d
	return best

## Fit to fight: standing, or out of sight inside a vehicle or a bunker.
static func _fit(s: Soldier) -> bool:
	return s.life == Soldier.Life.ALIVE or s.life == Soldier.Life.HIDDEN

func _describe(e: Entity) -> String:
	if e is Soldier:
		var states := ["", "wounded - bleeding out", "KIA", "surrendering", "prisoner", ""]
		return "%s   %s   %s" % [e.display_name(), Defs.TEAM_NAMES[e.team] if e.team >= 0 else "", states[e.life]]
	if e is Structure:
		var t := e.display_name()
		if e.team >= 0:
			t += "   (%s)" % Defs.TEAM_NAMES[e.team]
		return t
	return e.display_name()

func _pip(p: Vector2, s: Soldier, small := false) -> void:
	var col := Color(0.3, 0.85, 0.35)
	var h := s.health_frac()
	match s.life:
		Soldier.Life.ALIVE:
			col = Color(1.0, 0.3, 0.25).lerp(Color(0.35, 0.82, 0.4), h)
		Soldier.Life.DOWNED:
			col = Color(1.0, 0.15, 0.12) if int(Time.get_ticks_msec() / 300) % 2 == 0 else Color(0.45, 0.06, 0.05)
		Soldier.Life.DEAD:
			col = Color(0.25, 0.25, 0.25)
		Soldier.Life.HIDDEN:
			col = Color(0.35, 0.5, 0.8)
		_:
			col = Color(0.9, 0.9, 0.9)
	var sz := Vector2(22, 16)
	draw_style_box(UiKit.boxc(col, 3, Color(0, 0, 0, 0.4), 1, 0.0), Rect2(p, sz))
	var ic := s.utype.substr(0, 2).to_upper()
	if s.udef.get("medic", false):
		ic = "+"
	draw_string(UiKit.font(600), p + Vector2(3, 12.5), ic, HORIZONTAL_ALIGNMENT_CENTER, 16, 10, Color(0, 0, 0, 0.75))
	if s.life == Soldier.Life.ALIVE:
		_bar(p + Vector2(0, sz.y + 1), Vector2(sz.x, 2), s.ammo_fraction(), Color(0.45, 0.7, 1.0))
		var sup := s.supp_value()
		if sup >= 60.0:
			draw_rect(Rect2(p - Vector2(2, 2), sz + Vector2(4, 4)), Color(1, 0.25, 0.2), false, 1.5)
		elif sup > 25.0:
			draw_rect(Rect2(p - Vector2(1, 1), sz + Vector2(2, 2)), Color(1, 0.7, 0.25), false, 1.0)

func _bar(p: Vector2, sz: Vector2, f: float, col: Color) -> void:
	draw_rect(Rect2(p, sz), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(p, Vector2(sz.x * clampf(f, 0.0, 1.0), sz.y)), col)

func _structure_info(st: Structure) -> void:
	var y := 18.0
	UiKit.text(self, Vector2(4, y), st.display_name(), 17, UiKit.TEXT, 600)
	if st.team >= 0:
		UiKit.text(self, Vector2(10 + UiKit.text_width(st.display_name(), 17, 600), y), Defs.TEAM_NAMES[st.team], 12, Defs.TEAM_COLORS[st.team].lightened(0.3))
	y += 12.0
	_bar(Vector2(4, y), Vector2(260, 6), st.hp / maxf(1.0, st.max_hp), UiKit.GOOD)
	y += 26.0
	if not st.built:
		UiKit.text(self, Vector2(4, y), "Under construction %d%%  -  select soldiers and right-click it to help build" % int(st.progress * 100.0), 13, UiKit.WARN)
		_bar(Vector2(4, y + 8), Vector2(260, 5), st.progress, UiKit.WARN)
		return
	if st.skind == "fob":
		var txt := "Supply %d" % int(st.supply)
		if st.wrecked:
			txt += "   WRECKED - repair to 50% to restore"
		UiKit.text(self, Vector2(4, y), txt, 13, UiKit.TEXT)
		y += 20.0
		if st.cap_prog > 0.0 and st.cap_team >= 0:
			UiKit.text(self, Vector2(4, y), "Being captured by %s" % Defs.TEAM_NAMES[st.cap_team], 13, UiKit.BAD)
			_bar(Vector2(4, y + 8), Vector2(260, 5), st.cap_prog / 100.0, Defs.TEAM_COLORS[st.cap_team])
		return
	if not st.queue_items.is_empty():
		UiKit.text(self, Vector2(4, y), "Training", 12, UiKit.DIM, 600)
		var x := 70.0
		for i in st.queue_items.size():
			var nm := Defs.item_name(String(st.queue_items[i]))
			UiKit.text(self, Vector2(x, y), nm, 12, UiKit.TEXT if i == 0 else UiKit.DIM)
			x += UiKit.text_width(nm, 12) + 14.0
		_bar(Vector2(4, y + 8), Vector2(260, 5), st.queue_frac, Color(0.5, 0.8, 1.0))
		if st.prod_status == "cap":
			UiKit.text(self, Vector2(4, y + 32), "Paused: unit cap reached. Build another FOB.", 12, UiKit.BAD)
	elif st.skind == "tunnel":
		UiKit.text(self, Vector2(4, y), "%d soldiers inside. Right-click with a squad selected to send them in." % st.inside_n, 13, UiKit.TEXT)
	elif Defs.BUILDINGS.has(st.skind):
		UiKit.text(self, Vector2(4, y), Defs.BUILDINGS[st.skind].desc, 13, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8)
