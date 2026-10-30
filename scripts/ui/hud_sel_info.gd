class_name HudSelInfo
extends Control
## What's selected, bottom centre, in Signal (docs/UI.md): a name and its type,
## one line of codes, then a cell per man (or a row per squad or vehicle, or a
## structure's state). The command deck supplies its housing.

var hud: Hud
var need_h := 120.0
var _rows: Array = []  # [Rect2, soldier eid] - click to command just him

const NAME_Y := 18.0  # the name line's baseline
const CODE_Y := 38.0  # the codes' baseline
const CELL_H := 34.0  # a man's cell


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
	_rows.clear()
	if inp.sel_unit != 0:
		var su: Soldier = w.entity(inp.sel_unit) as Soldier
		if su:
			_unit_detail(su)
			need_h = 92.0
			return
	if not inp.sel_squads.is_empty():
		var by_sid := {}
		for s in w.soldiers:
			if s.sid in inp.sel_squads and inp.is_mine(s):
				if not by_sid.has(s.sid):
					by_sid[s.sid] = []
				by_sid[s.sid].append(s)
		if by_sid.size() == 1:
			var mem: Array = by_sid.values()[0]
			_squad_detail(mem)
			need_h = 54.0 + ceili(mini(mem.size(), 12) / float(_cols())) * CELL_H
			return
		var y := 2.0
		var rows := 0
		for sid in inp.sel_squads:
			if not by_sid.has(sid) or rows >= 6:
				continue
			rows += 1
			var mem: Array = by_sid[sid]
			var sym := MapSymbols.squad_symbol(mem)
			MapSymbols.nato(self, Vector2(10, y + 12), 18.0, true, mem[0].team, sym[0])
			var x := 26.0 + UiKit.caps_at(self, Vector2(26, y + 17), Squad.callsign_of(mem[0].team, int(sid)), 13, UiKit.TEXT)
			x += 8.0 + UiKit.caps_at(self, Vector2(x + 8.0, y + 17), _squad_name(mem), 11, UiKit.FAINT)
			var alive := 0
			var hurt := 0
			var mounted := false
			for s in mem:
				if _fit(s):
					alive += 1
				elif s.life == Soldier.Life.DOWNED:
					hurt += 1
				if s.riding != null:
					mounted = true
			var st: Dictionary = hud.squad_state(int(sid), mem)
			UiKit.mono_at(self, Vector2(maxf(x + 16.0, size.x * 0.42), y + 17), String(st.code), 12, _code_col(st))
			if mounted:
				UiKit.mono_at(self, Vector2(size.x - 150, y + 17), "MOUNTED", 11, UiKit.FAINT)
			UiKit.mono_at(self, Vector2(size.x - 86, y + 17), "%d/%d" % [alive, mem.size()], 12, UiKit.TEXT if alive * 2 > mem.size() else UiKit.BAD)
			UiKit.pips(self, Vector2(size.x - 44, y + 8), alive, hurt, mem.size() - alive - hurt)
			UiKit.rule(self, Vector2(0, y + 25.5), Vector2(size.x, y + 25.5))
			y += 26.0
		need_h = y + 4.0
		return
	if inp.sel_vehicles.size() == 1:
		var selected_vehicle := w.entity(inp.sel_vehicles[0]) as Vehicle
		if selected_vehicle:
			_vehicle_detail(selected_vehicle)
			need_h = 140.0
			return
	if not inp.sel_vehicles.is_empty():
		var y2 := 2.0
		for id in inp.sel_vehicles:
			var v: Vehicle = w.entity(id)
			if v == null:
				continue
			var vx := UiKit.caps_at(self, Vector2(2, y2 + 17), v.display_name(), 13, UiKit.TEXT)
			var code := "TRACK BROKEN · NEEDS ENGINEERS" if (v.flags & Vehicle.F_TRACK) != 0 else ("ENGAGING" if (v.flags & Vehicle.F_FIRE) != 0 else "")
			if code != "":
				UiKit.mono_at(self, Vector2(maxf(vx + 16.0, size.x * 0.42), y2 + 17), code, 12, UiKit.BAD if (v.flags & Vehicle.F_TRACK) != 0 else UiKit.WARN)
			UiKit.steps(self, Vector2(size.x - 104, y2 + 9), v.health_frac() * 10.0, 10, _health_col(v.health_frac()), 8.0, 10.0)
			UiKit.rule(self, Vector2(0, y2 + 25.5), Vector2(size.x, y2 + 25.5))
			y2 += 26.0
		need_h = y2 + 4.0
		return
	var st2: Structure = w.entity(inp.sel_structure) as Structure
	if st2:
		need_h = _structure_info(st2)
		return
	need_h = 30.0
	var e: Entity = hud._inspect if hud._inspect_t > 0.0 and hud._inspect and not hud._inspect.gone else null
	if e:
		_describe(e)


## Replicated condition and static capabilities, useful to a commander on host or client.
func _vehicle_detail(v: Vehicle) -> void:
	var title := v.display_name()
	while title.length() > 3 and UiKit.caps_w(title, 17) > size.x - 60:
		title = title.left(title.length() - 2).trim_suffix("…") + "…"
	UiKit.caps_at(self, Vector2(0, NAME_Y), title, 17, UiKit.TEXT)
	UiKit.mono_at(self, Vector2(size.x - 42, NAME_Y), "%d%%" % roundi(v.health_frac() * 100), 12, _health_col(v.health_frac()))
	var state := "IMMOBILISED · NEEDS ENGINEERS" if (v.flags & Vehicle.F_TRACK) != 0 else ("ENGAGING" if (v.flags & Vehicle.F_FIRE) != 0 else "READY")
	UiKit.caps_at(self, Vector2(0, CODE_Y), state, 11, UiKit.WARN if v.flags & (Vehicle.F_TRACK | Vehicle.F_FIRE) else UiKit.DIM)
	UiKit.rule(self, Vector2(0, 49), Vector2(size.x, 49))
	_row(72, "Position", Defs.grid_ref(v.position))
	_row(92, "Armour", ["LIGHT", "MEDIUM", "HEAVY"][clampi(int(v.vdef.get("armor", 0)), 0, 2)])
	_row(112, "Top speed", "%d KM/H" % roundi(float(v.vdef.get("speed", 0)) * 3.6))
	if size.x > 420:
		var lines := MapSymbols.wrap(String(v.vdef.get("desc", "")), 12, 400, size.x - 240)
		for i in mini(3, lines.size()):
			UiKit.text(self, Vector2(240, 72 + i * 18), lines[i], 12, UiKit.DIM)


## How many men's cells fit across.
func _cols() -> int:
	return clampi(int(size.x / 112.0), 2, 6)


## A state code's colour: dim unless it needs the commander.
func _code_col(st: Dictionary) -> Color:
	if int(st.get("mstate", 0)) >= 3 or String(st.code).begins_with("ROUTING") or String(st.code).begins_with("FALL BACK"):
		return UiKit.BAD
	if bool(st.pinned):
		return UiKit.WARN
	return UiKit.DIM


static func _health_col(f: float) -> Color:
	return UiKit.GOOD if f > 0.6 else (UiKit.WARN if f > 0.3 else UiKit.BAD)


## One squad in full: its name, its nerve and strength, a line of codes (and
## where an attack has got to), then a cell per man.
func _squad_detail(mem: Array) -> void:
	var cs := Squad.callsign_of(mem[0].team, mem[0].sid) if not mem.is_empty() else ""
	var alive := 0
	for s in mem:
		if _fit(s):
			alive += 1
	var st: Dictionary = hud.squad_state(mem[0].sid, mem)
	var x := UiKit.caps_at(self, Vector2(0, NAME_Y), cs, 17, UiKit.TEXT)
	var type_name := _squad_name(mem)
	if size.x > x + UiKit.caps_w(type_name, 11) + 150:
		x += 10.0 + UiKit.caps_at(self, Vector2(x + 10.0, NAME_Y), type_name, 11, UiKit.FAINT)
	# right: its nerve, then how many are still fighting
	var rx := size.x - UiKit.mono_w("%d/%d" % [alive, mem.size()], 12)
	UiKit.mono_at(self, Vector2(rx, NAME_Y), "%d/%d" % [alive, mem.size()], 12, UiKit.TEXT if alive * 2 > mem.size() else UiKit.BAD)
	if int(st.morale) >= 0:
		var mcol: Color = [UiKit.GOOD, UiKit.WARN, Color(1.0, 0.62, 0.35), UiKit.BAD][int(st.mstate)]
		var mtxt: String = SquadBrain.STATE_NAMES[int(st.mstate)].to_upper()
		var mx := rx - 16.0 - UiKit.mono_w(mtxt, 12)
		if mx > x + 12:
			UiKit.mono_at(self, Vector2(mx, NAME_Y), mtxt, 12, mcol)
	# the codes: what it's doing, then what most of the men are doing, then the attack's steps
	var line: String = st.code
	var common := _common_doing(mem)
	if common != "" and not (bool(st.pinned) and common.to_lower().contains("pinned")):
		line += " · " + common.to_upper()
	while line.length() > 3 and UiKit.mono_w(line, 12) > size.x - 8:
		line = line.left(line.length() - 2).trim_suffix("…") + "…"
	var cx := UiKit.mono_at(self, Vector2(0, CODE_Y), line, 12, _code_col(st))
	var o: Array = hud.orders.get(mem[0].sid, [])
	if not o.is_empty() and o[6] != null and size.x >= cx + 312:
		_stepper(Vector2(maxf(cx + 24.0, size.x - 300.0), CODE_Y), String(o[6][0]))
	# the men
	var cols := _cols()
	var cw := size.x / cols
	var y0 := CODE_Y + 12.0
	UiKit.rule(self, Vector2(0, y0 - 0.5), Vector2(size.x, y0 - 0.5))
	var mouse := get_local_mouse_position()
	for i in mini(mem.size(), 12):
		var s: Soldier = mem[i]
		var c := Rect2((i % cols) * cw, y0 + (i / cols) * CELL_H, cw, CELL_H)
		if s.life == Soldier.Life.ALIVE and hud.world.input.can_command():
			_rows.append([c, s.eid])
			if c.has_point(mouse):
				draw_rect(c, UiKit.fa(UiKit.TEXT, 0.05))
		_man(c, s, common)
		if i % cols != cols - 1:
			UiKit.rule(self, Vector2(c.end.x - 6.5, c.position.y + 5), Vector2(c.end.x - 6.5, c.end.y - 5))


## What most of the squad is doing ("" if nothing stands out): said once on
## the squad's line instead of on every man's.
func _common_doing(mem: Array) -> String:
	var n := {}
	var alive := 0
	for s in mem:
		if s.life != Soldier.Life.ALIVE:
			continue
		alive += 1
		var d: String = s.doing_text()
		if d != "":
			n[d] = int(n.get(d, 0)) + 1
	var best := ""
	var bn := 0
	for d in n:
		if int(n[d]) > bn:
			bn = int(n[d])
			best = d
	return best if alive > 1 and bn * 2 > alive else ""


## A man's cell: a pip for his state, his name, his role, and what he's doing
## when it isn't what the squad is.
func _man(c: Rect2, s: Soldier, common: String) -> void:
	var col := UiKit.TEXT
	match s.life:
		Soldier.Life.DOWNED:
			col = UiKit.BAD if int(Time.get_ticks_msec() / 300) % 2 == 0 else UiKit.fa(UiKit.BAD, 0.4)
		Soldier.Life.DEAD:
			col = UiKit.RULE2
		Soldier.Life.HIDDEN:
			col = UiKit.INTEL
		_:
			if s.health_frac() < 0.5:
				col = UiKit.WARN
	draw_rect(Rect2(c.position.x, c.position.y + 6, 3, 22), col)
	var sup := s.supp_value() if s.life == Soldier.Life.ALIVE else 0.0
	if sup > 25.0:
		draw_rect(Rect2(c.position.x + 5, c.position.y + 6, 2, 22), UiKit.BAD if sup >= 60.0 else UiKit.WARN)
	var x := c.position.x + 11.0
	var nm := s.sname
	var dead := s.life == Soldier.Life.DEAD
	UiKit.caps_at(self, Vector2(x, c.position.y + 16), nm, 12, UiKit.FAINT if dead else UiKit.TEXT)
	var role := "SL" if (s.flags & Soldier.F_LEADER) != 0 else _role(s)
	var dt := s.doing_text()
	var code := role
	var cc := UiKit.FAINT
	if dead:
		code = "KIA"
		cc = UiKit.BAD
	elif s.life == Soldier.Life.DOWNED:
		code = "DOWN"
		cc = UiKit.BAD
	elif dt != "" and dt != common:
		code = role + " · " + dt.to_upper()
		cc = Hud.CAT_COLORS.get(s.doing_cat(), UiKit.DIM)
	elif s.life == Soldier.Life.ALIVE and s.ammo_fraction() < 0.25:
		code = role + " · LOW AMMO"
		cc = UiKit.WARN
	var maxw := c.size.x - 18.0
	while code.length() > 3 and UiKit.mono_w(code, 11) > maxw:
		code = code.substr(0, code.length() - 2)
	UiKit.mono_at(self, Vector2(x, c.position.y + 29), code, 11, cc)


## A short code for a man's job.
static func _role(s: Soldier) -> String:
	if s.udef.get("medic", false):
		return "MED"
	var u := String(s.utype)
	return {"rifleman": "RFL", "engineer": "ENG", "mg_gunner": "MG", "at_soldier": "AT", "fighter": "FTR", "digger": "DIG", "pkm": "MG",
		"rpg": "RPG", "fpv_op": "FPV", "mortar_gunner": "MOR", "r_mortar": "MOR", "crewman": "CRW", "r_crewman": "CRW", "bearer": "STR"}.get(u, u.substr(0, 3).to_upper())


## PLAN › MOVE › ASSAULT › SECURE, the current step in the accent.
func _stepper(at: Vector2, phase: String) -> void:
	var steps := ["PLAN", "MOVE", "ASSAULT", "SECURE"]
	var cur := {"plan": 0, "move": 1, "fix": 1, "assault": 2, "fallback": 2}.get(phase, 3) as int
	var x := at.x
	for i in steps.size():
		var tc := UiKit.ACCENT if i == cur else (UiKit.DIM if i < cur else UiKit.FAINT)
		if phase == "fix" and i == 1 or phase == "fallback" and i == 2:
			tc = UiKit.BAD
		x += UiKit.mono_at(self, Vector2(x, at.y), steps[i], 11, tc)
		if i < steps.size() - 1:
			x += 6.0 + UiKit.mono_at(self, Vector2(x + 6.0, at.y), "›", 11, UiKit.FAINT) + 6.0


func _unit_detail(s: Soldier) -> void:
	var x := UiKit.caps_at(self, Vector2(0, NAME_Y), s.sname, 17, UiKit.TEXT)
	UiKit.caps_at(self, Vector2(x + 10.0, NAME_Y), String(s.udef.get("name", s.utype)), 11, UiKit.FAINT)
	var dt := s.doing_text() if s.doing_text() != "" else "Waiting for orders"
	UiKit.mono_at(self, Vector2(0, CODE_Y), "DIRECT COMMAND · " + dt.to_upper(), 12, Hud.CAT_COLORS.get(s.doing_cat(), UiKit.DIM))
	UiKit.rule(self, Vector2(0, CODE_Y + 11.5), Vector2(size.x, CODE_Y + 11.5))
	var y := CODE_Y + 30.0
	var hx := UiKit.caps_at(self, Vector2(0, y), "Health", 11, UiKit.FAINT) + 10.0
	UiKit.steps(self, Vector2(hx, y - 10), s.health_frac() * 10.0, 10, _health_col(s.health_frac()), 8.0, 10.0)
	var ax := hx + 110.0
	ax += UiKit.caps_at(self, Vector2(ax, y), "Ammo", 11, UiKit.FAINT) + 10.0
	UiKit.steps(self, Vector2(ax, y - 10), s.ammo_fraction() * 10.0, 10, UiKit.TEXT, 8.0, 10.0)
	var cov := hud.world.terrain.describe(s.position) if hud.world.terrain else ""
	if cov != "":
		UiKit.mono_at(self, Vector2(ax + 120.0, y), cov.to_upper(), 11, UiKit.DIM)


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


## Something looked at (not selected): its name, its side and its state.
func _describe(e: Entity) -> void:
	var x := UiKit.caps_at(self, Vector2(0, NAME_Y), e.display_name(), 15, UiKit.TEXT)
	if e.team >= 0:
		draw_rect(Rect2(x + 10.0, NAME_Y - 9, 7, 7), Defs.TEAM_COLORS[e.team])
		x += 22.0 + UiKit.caps_at(self, Vector2(x + 22.0, NAME_Y), Defs.TEAM_NAMES[e.team], 11, UiKit.FAINT)
	if e is Soldier:
		var states := ["", "WOUNDED · BLEEDING OUT", "KIA", "SURRENDERING", "PRISONER", ""]
		var t: String = states[e.life]
		if t != "":
			UiKit.mono_at(self, Vector2(x + 14.0, NAME_Y), t, 12, UiKit.BAD)


## A row of the structure panel: a label and its value as a code.
func _row(y: float, label: String, value: String, col := UiKit.DIM) -> float:
	UiKit.caps_at(self, Vector2(0, y), label, 11, UiKit.FAINT)
	UiKit.mono_at(self, Vector2(96, y), value, 12, col)
	return y + 18.0


## A structure or a town: its name and side, its state as a counted bar, and
## a few label and code rows. Returns the height drawn.
func _structure_info(st: Structure) -> float:
	var w := hud.world
	var lt := w.local_team
	var x := UiKit.caps_at(self, Vector2(0, NAME_Y), st.display_name(), 17, UiKit.TEXT)
	if st.team >= 0:
		draw_rect(Rect2(x + 10.0, NAME_Y - 9, 7, 7), Defs.TEAM_COLORS[st.team])
		UiKit.caps_at(self, Vector2(x + 22.0, NAME_Y), Defs.TEAM_NAMES[st.team], 11, UiKit.FAINT)
	var y := CODE_Y
	if st.skind == "town":
		# a town can't be knocked down, only its houses: how much of it stands
		var k := clampi(st.variant, 0, 1)
		y = _row(y, "Holder", Defs.TEAM_NAMES[st.team].to_upper() if st.team >= 0 else "NOBODY")
		y = _row(y, "Houses", "%d%% STANDING" % int(round(st.intact * 100.0)))
		y = _row(y, "Gives", "%d/M · %d AT FULL STRENGTH" % [int(round(st.town_rate())), int(Defs.TOWN_YIELD[k])])
		if st.team == lt and lt >= 0:
			var to := "NO FOB IN REACH"
			for tn in (w.team_info[lt] as Dictionary).get("towns", []):
				if int(tn[0]) == st.eid and String(tn[5]) != "":
					to = "TRUCKS TO " + String(tn[5]).to_upper()
			y = _row(y, "Dump", "%d/%d · %s" % [int(st.supply), int(Defs.TOWN_STOCK[k]), to])
		else:
			y = _row(y, "To take", "MEN IN THE %dM RING · NONE OF THEIRS" % int(st.zone_r))
		if st.cap_prog > 0.0 and st.cap_team >= 0:
			var who: String = "US" if st.cap_team == lt else Defs.TEAM_NAMES[st.cap_team].to_upper()
			y = _row(y, "Taking", "%s %d%%" % [who, int(st.cap_prog)], UiKit.GOOD if st.cap_team == lt else UiKit.BAD)
		return y + 4.0
	UiKit.caps_at(self, Vector2(0, y), "State", 11, UiKit.FAINT)
	var f := st.hp / maxf(1.0, st.max_hp)
	UiKit.steps(self, Vector2(96, y - 10), f * 20.0, 20, _health_col(f), 6.0, 10.0)
	y += 20.0
	if not st.built:
		y = _row(y, "Building", "%d%% · SELECT MEN AND RIGHT-CLICK IT TO HELP" % int(st.progress * 100.0), UiKit.WARN)
		return y + 4.0
	if st.skind == "fob":
		y = _row(y, "Supply", str(int(st.supply)), UiKit.TEXT)
		if st.wrecked:
			y = _row(y, "Wrecked", "REPAIR TO 50% TO RESTORE", UiKit.BAD)
		if st.cap_prog > 0.0 and st.cap_team >= 0:
			y = _row(y, "Captured", "%s %d%%" % [Defs.TEAM_NAMES[st.cap_team].to_upper(), int(st.cap_prog)], UiKit.BAD)
		return y + 4.0
	if not st.queue_items.is_empty():
		var q := []
		for it in st.queue_items:
			q.append(Defs.item_name(String(it)).to_upper())
		y = _row(y, "Training", " · ".join(q), UiKit.TEXT)
		UiKit.steps(self, Vector2(96, y - 10), st.queue_frac * 20.0, 20, UiKit.ACCENT, 6.0, 6.0)
		y += 12.0
		if st.prod_status == "cap":
			y = _row(y, "Paused", "UNIT CAP · BUILD ANOTHER FOB", UiKit.BAD)
	elif st.skind == "tunnel":
		y = _row(y, "Inside", "%d · RIGHT-CLICK WITH A SQUAD TO SEND THEM IN" % st.inside_n)
	elif st.skind == "ammo_cache" and st.team == lt:
		var left := st.supply / Structure.CACHE_STOCK
		y = _row(y, "Stores", "%d%% · REFILLS MEN WITHIN %dM" % [int(round(left * 100.0)), int(Structure.CACHE_REACH)], UiKit.TEXT if left > 0.25 else UiKit.WARN)
	elif Defs.BUILDINGS.has(st.skind):
		UiKit.text(self, Vector2(0, y), Defs.BUILDINGS[st.skind].desc, 13, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8)
		y += 18.0
	return y + 4.0
