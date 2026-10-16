class_name StatsPanel
extends PanelContainer
## The battle's figures in four tabs - Summary (the two sides head to head,
## honours, the soldiers who stood out), Commanders (each player's and AI's
## effectiveness, and what it is made of), Units (every squad and vehicle) and
## Timeline (strength, kills and supply over the battle). Hold Tab in a battle
## for your own side's so far (the enemy's figures are classified until it's
## over); the end-of-battle screen carries the whole after-action report, and
## the menu's Service Record opens it again for any battle on the record.

signal closed

const TABS := [["summary", "Summary"], ["commanders", "Commanders"], ["units", "Units"], ["timeline", "Timeline"]]

var me_id := 0  # whose report it is: their commander id in that battle, and side
var me_team := -1
var title := "BATTLE STATISTICS"
var fixed_sub := ""  # a battle from the record says when it was, not how long it's been going
var embedded := false  # part of the end-of-battle screen: no frame, title or close button
var report: Dictionary = {}
var tab := "summary"
var pick := 0  # the commander whose detail card is open (0: you, or the best)
var peek := false  # shown while Tab is held (not pinned open)
var names := {}  # commander id -> name
var unit_names := {}  # unit key -> callsign
var _title: Label
var _sub: Label
var _note: Label
var _close: Button
var _hint: Label
var _tab_btns := {}
var _pages := {}


func _ready() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new() if embedded else UiKit.box(Color(0.045, 0.055, 0.05, 0.96), 10, UiKit.LINE, 1, 18.0, 18))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	if not embedded:
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		vb.add_child(top)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(tv)
		_title = UiKit.label(title, 22, UiKit.TEXT, 700)
		tv.add_child(_title)
		_sub = UiKit.label("", 13, UiKit.DIM)
		tv.add_child(_sub)
		_hint = UiKit.label("Release Tab to return", 12, UiKit.DIM)
		_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(_hint)
		_close = Button.new()
		_close.text = "Close"
		_close.focus_mode = Control.FOCUS_NONE
		_close.custom_minimum_size = Vector2(84, 32)
		_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_close.pressed.connect(func(): Sfx.ui("click"); closed.emit())
		top.add_child(_close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vb.add_child(tabs)
	var grp := ButtonGroup.new()
	for t in TABS:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_group = grp
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(128, 34)
		b.add_theme_font_size_override("font_size", 15)
		var key: String = t[0]
		b.pressed.connect(func(): Sfx.ui("click"); show_tab(key))
		tabs.add_child(b)
		_tab_btns[key] = b
	_note = UiKit.label("", 12, UiKit.DIM)
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.size_flags_vertical = Control.SIZE_FILL
	tabs.add_child(_note)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.08)
	line.custom_minimum_size = Vector2(0, 1)
	vb.add_child(line)
	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.clip_contents = true
	vb.add_child(body)
	for t in TABS:
		var key: String = t[0]
		var pg: _Page
		match key:
			"summary":
				pg = _Summary.new()
			"commanders":
				pg = _Commanders.new()
			"units":
				pg = _Units.new()
			_:
				pg = _Timeline.new()
		pg.p = self
		pg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pg.mouse_filter = Control.MOUSE_FILTER_PASS
		if key == "timeline":
			pg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			pg.mouse_filter = Control.MOUSE_FILTER_STOP
			body.add_child(pg)
			_pages[key] = pg
			continue
		var sc := ScrollContainer.new()
		sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.add_child(pg)
		body.add_child(sc)
		_pages[key] = pg
	show_tab(tab)


func show_tab(key: String) -> void:
	if not _pages.has(key):
		key = "summary"
	tab = key
	for k in _pages:
		var pg: Control = _pages[k]
		var holder: Control = pg.get_parent() if pg.get_parent() is ScrollContainer else pg
		holder.visible = k == key
		if k == key:
			pg.queue_redraw()
		if _tab_btns.has(k):
			(_tab_btns[k] as Button).set_pressed_no_signal(k == key)


func set_report(r: Dictionary) -> void:
	report = r
	# a report from the service record says whose it was
	if r.has("me"):
		me_id = int(r.me)
		me_team = int(r.get("me_team", me_team))
	if _title:
		_title.text = title
	names.clear()
	for c in r.get("players", []):
		names[int(c.id)] = String(c.name)
	unit_names.clear()
	for u in r.get("units", []):
		unit_names[String(u.key)] = String(u.name)
	if pick == 0 or not names.has(pick):
		pick = me_id if names.has(me_id) else _top_scorer()
	if _sub:
		if fixed_sub != "":
			_sub.text = fixed_sub
		elif r.is_empty():
			_sub.text = "Gathering reports from the field..."
		else:
			var whose: String = "Both sides" if bool(r.get("full", false)) else (String(Defs.TEAM_NAMES[int(r.get("view", 0))]) + " figures")
			_sub.text = "%s into the battle  ·  %s" % [fmt_time(float(r.get("t", 0.0))), whose]
	if _hint:
		_hint.visible = peek
		_close.visible = not peek
	if _note:
		_note.text = "" if r.is_empty() or bool(r.get("full", false)) else "The enemy's figures are classified until the battle is over"
	for k in _pages:
		(_pages[k] as Control).queue_redraw()


func _top_scorer() -> int:
	var best := 0
	var bs := -1
	for c in report.get("players", []):
		var s := BattleStats.score(c)
		if s > bs:
			bs = s
			best = int(c.id)
	return best


## The side shown first (on the left): your own, or the Coalition for observers.
func first_side() -> int:
	return me_team if me_team >= 0 else 0


func sides_in_order() -> Array:
	return [first_side(), 1 - first_side()]


func known(t: int) -> bool:
	var sd: Array = report.get("sides", [{}, {}])
	return not (sd[t] as Dictionary).is_empty()


func players_of(t: int) -> Array:
	var out := []
	for c in report.get("players", []):
		if int(c.team) == t:
			out.append(c)
	out.sort_custom(func(a, b): return BattleStats.score(a) > BattleStats.score(b))
	return out


# --- formatting ------------------------------------------------------------------------------

static func fmt_num(v: float) -> String:
	var n := int(round(v))
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func fmt_time(t: float) -> String:
	var s := maxi(0, int(t))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


static func accuracy(r: Dictionary) -> float:
	var sh := float(r.get("shots", 0.0))
	return float(r.get("hits", 0.0)) / sh if sh > 0.0 else -1.0


static func fmt_acc(r: Dictionary) -> String:
	var a := accuracy(r)
	return "%d%%" % int(round(a * 100.0)) if a >= 0.0 else "-"


static func kd(r: Dictionary) -> String:
	var k := float(r.get("kills", 0.0))
	var d := float(r.get("lost", 0.0)) + float(r.get("captured", 0.0))
	if k <= 0.0 and d <= 0.0:
		return "-"
	return "%.1f" % (k / maxf(1.0, d))


## Supply value destroyed against lost, as "2.4 : 1" (or "1 : 1.8").
static func exchange(r: Dictionary) -> String:
	var a := float(r.get("val_killed", 0.0))
	var b := float(r.get("val_lost", 0.0))
	if a <= 0.0 and b <= 0.0:
		return "-"
	if b <= 0.0:
		return "no losses"
	if a <= 0.0:
		return "0 : 1"
	return ("%.1f : 1" % (a / b)) if a >= b else ("1 : %.1f" % (b / a))


static func rating_col(v: float) -> Color:
	if v >= 70.0:
		return UiKit.GOOD
	if v >= 55.0:
		return Color(0.8, 0.9, 0.5)
	if v >= 40.0:
		return UiKit.WARN
	return UiKit.BAD


static func plural(n: float, one: String, many := "") -> String:
	var i := int(round(n))
	return "%s %s" % [fmt_num(i), one if i == 1 else (many if many != "" else one + "s")]


static func side_col(t: int) -> Color:
	return Defs.TEAM_COLORS[clampi(t, 0, 1)]


## A commander's name and what kind of commander they are.
func who_tag(c: Dictionary) -> String:
	var bits := []
	if int(c.id) == me_id:
		bits.append("You")
	if bool(c.get("ai", false)):
		bits.append("AI")
	if bool(c.get("left", false)):
		bits.append("Left the battle")
	return "  ·  ".join(bits)


# --- the pages ---------------------------------------------------------------------------------

## A page draws itself from the panel's report; inside a ScrollContainer it
## asks for as much height as it drew.
class _Page extends Control:
	var p: StatsPanel
	var tips: Array = []  # [Rect2, text] for the tooltip under the mouse

	func _ready() -> void:
		resized.connect(queue_redraw)

	func fit(h: float) -> void:
		if absf(custom_minimum_size.y - h) > 0.5:
			custom_minimum_size.y = h

	func tip(r: Rect2, t: String) -> void:
		tips.append([r, t])

	func _get_tooltip(at: Vector2) -> String:
		for t in tips:
			if (t[0] as Rect2).has_point(at):
				return String(t[1])
		return ""

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			tooltip_text = _get_tooltip(ev.position)

	func waiting() -> bool:
		if not p.report.is_empty():
			return false
		UiKit.text(self, Vector2(0, 60), "Gathering reports from the field...", 15, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		fit(120)
		return true

	func head(x: float, y: float, s: String, w := 0.0) -> float:
		UiKit.text(self, Vector2(x, y + 12), s.to_upper(), 11, UiKit.ACCENT, 700)
		if w > 0.0:
			var tw := UiKit.text_width(s.to_upper(), 11, 700)
			draw_line(Vector2(x + tw + 10, y + 8), Vector2(x + w, y + 8), Color(1, 1, 1, 0.07), 1.0)
		return y + 24.0

	func txt(x: float, y: float, s: String, fs := 13, col := UiKit.TEXT, wt := 400, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
		var f := UiKit.font(wt)
		draw_string(f, Vector2(x, y), s, align, w, fs, col)

	func side_label(x: float, y: float, t: int, extra := "") -> void:
		var c := StatsPanel.side_col(t)
		draw_rect(Rect2(x, y + 1, 4, 16), c)
		var nm := String(Defs.TEAM_NAMES[t]).to_upper()
		txt(x + 12, y + 14, nm, 14, c.lightened(0.35), 700)
		if extra != "":
			txt(x + 22 + UiKit.text_width(nm, 14, 700), y + 14, extra, 11, UiKit.DIM, 600)

	func result_tag(t: int) -> String:
		if not bool(p.report.get("over", false)):
			return ""
		return "VICTORIOUS" if int(p.report.get("winner", -1)) == t else "DEFEATED"


# --- Summary: head to head, honours, distinguished soldiers ---------------------------------------

class _Summary extends _Page:
	## [field, label, which way is better (1 more, -1 fewer, 0 neither), tooltip]
	const ROWS := [
		["kills", "Enemy killed", 1, "Enemy soldiers killed."],
		["downs", "Enemy wounded", 1, "Times an enemy soldier was put down wounded (some were saved, some bled out)."],
		["lost", "Men lost", -1, "Own soldiers killed."],
		["captured", "Men captured", -1, "Own soldiers taken prisoner."],
		["veh_kills", "Vehicles destroyed", 1, "Enemy vehicles knocked out."],
		["veh_lost", "Vehicles lost", -1, "Own vehicles knocked out."],
		["bld_kills", "Buildings destroyed", 1, "Enemy buildings and defences knocked down (wrecked FOBs too)."],
		["val_killed", "Value destroyed", 1, "What everything destroyed or captured cost the enemy, in supply."],
		["acc", "Accuracy", 1, "Rounds that hit what they were aimed at."],
		["prisoners", "Prisoners taken", 1, "Enemy soldiers who surrendered and were taken."],
		["captures", "FOBs captured", 1, "Enemy FOBs taken over."],
		["revived", "Wounded saved", 1, "Times a medic or a medevac brought a wounded man back."],
		["delivered", "Supply delivered", 1, "Supply the trucks and helicopters brought to the FOBs."],
		["spent", "Supply spent", 0, "Supply spent on troops, vehicles, buildings, research and fire support."],
		["fielded", "Units fielded", 0, "Squads and vehicles trained or built."],
		["built", "Structures built", 0, "Buildings and defences completed."],
		["support", "Fire missions", 0, "Air and artillery support called in."],
	]

	func _draw() -> void:
		tips.clear()
		if waiting():
			return
		var w := size.x
		var two := w >= 780.0
		var lw := floorf(w * 0.55) if two else w
		var y1 := _h2h(0.0, lw)
		var y2 := 0.0
		if two:
			y2 = _right(lw + 32.0, 0.0, w - lw - 32.0)
		else:
			y2 = _right(0.0, y1 + 20.0, w)
		fit(maxf(y1, y2) + 10.0)

	func _val(sd: Dictionary, key: String) -> float:
		match key:
			"acc":
				var a := StatsPanel.accuracy(sd)
				return a * 100.0 if a >= 0.0 else 0.0
			"fielded":
				return float(sd.get("squads", 0.0)) + float(sd.get("vehicles", 0.0))
		return float(sd.get(key, 0.0))

	func _fmt(sd: Dictionary, key: String) -> String:
		if key == "acc":
			return StatsPanel.fmt_acc(sd)
		return StatsPanel.fmt_num(_val(sd, key))

	func _h2h(x0: float, w: float) -> float:
		var order := p.sides_in_order()
		var a: int = order[0]
		var b: int = order[1]
		var sds: Array = p.report.sides
		var sa: Dictionary = sds[a]
		var sb: Dictionary = sds[b]
		var kb := not sb.is_empty()
		side_label(x0, 0.0, a, result_tag(a))
		var cb := StatsPanel.side_col(b)
		var nb := String(Defs.TEAM_NAMES[b]).to_upper()
		var tb := result_tag(b)
		txt(x0, 14, nb, 14, cb.lightened(0.35), 700, HORIZONTAL_ALIGNMENT_RIGHT, w - 12.0)
		draw_rect(Rect2(x0 + w - 4.0, 1, 4, 16), cb)
		if tb != "":
			txt(x0, 14, tb, 11, UiKit.DIM, 600, HORIZONTAL_ALIGNMENT_RIGHT, w - 22.0 - UiKit.text_width(nb, 14, 700))
		var y := 34.0
		var ca := StatsPanel.side_col(a)
		for row in ROWS:
			var key: String = row[0]
			var va := _val(sa, key)
			var vb := _val(sb, key) if kb else -1.0
			var better: int = row[2]
			var col_a := UiKit.TEXT
			var col_b := UiKit.TEXT if kb else UiKit.DIM
			if kb and better != 0 and va != vb:
				var a_wins := (va > vb) == (better > 0)
				col_a = UiKit.TEXT if a_wins else UiKit.DIM
				col_b = UiKit.DIM if a_wins else UiKit.TEXT
			txt(x0, y + 15, _fmt(sa, key), 16, col_a, 600)
			txt(x0, y + 14, String(row[1]), 12, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_CENTER, w)
			txt(x0, y + 15, _fmt(sb, key) if kb else "-", 16, col_b, 600, HORIZONTAL_ALIGNMENT_RIGHT, w)
			var by := y + 23.0
			draw_rect(Rect2(x0, by, w, 4), Color(1, 1, 1, 0.05))
			if kb and va + vb > 0.0:
				var f := va / (va + vb)
				var split := x0 + w * f
				if f > 0.0:
					draw_rect(Rect2(x0, by, maxf(0.0, split - x0 - 1.0), 4), Color(ca.r, ca.g, ca.b, 0.8))
				if f < 1.0:
					draw_rect(Rect2(split + 1.0, by, maxf(0.0, x0 + w - split - 1.0), 4), Color(cb.r, cb.g, cb.b, 0.8))
			tip(Rect2(x0, y, w, 30), String(row[3]))
			y += 34.0
		return y

	func _right(x0: float, y0: float, w: float) -> float:
		var y := head(x0, y0, "Honours", w)
		var hs := _honours()
		if hs.is_empty():
			txt(x0, y + 12, "Nobody has distinguished themselves yet.", 13, UiKit.DIM)
			y += 26.0
		var cw := floorf((w - 8.0) * 0.5)
		for i in hs.size():
			var h: Array = hs[i]
			var c: Dictionary = h[1]
			var r := Rect2(x0 + (i % 2) * (cw + 8.0), y + (i / 2) * 64.0, cw, 56.0)
			draw_style_box(UiKit.boxc(Color(1, 1, 1, 0.035), 6, Color(1, 1, 1, 0.06), 1, 0.0), r)
			draw_rect(Rect2(r.position + Vector2(0, 8), Vector2(3, r.size.y - 16)), StatsPanel.side_col(int(c.team)))
			txt(r.position.x + 12, r.position.y + 17, String(h[0]).to_upper(), 10, UiKit.ACCENT, 700)
			txt(r.position.x + 12, r.position.y + 35, String(c.name), 14, UiKit.TEXT, 700, HORIZONTAL_ALIGNMENT_LEFT, cw - 18.0)
			txt(r.position.x + 12, r.position.y + 50, String(h[2]), 12, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_LEFT, cw - 18.0)
			tip(r, String(h[3]))
		y += ceilf(hs.size() / 2.0) * 64.0 + 12.0
		y = head(x0, y, "Distinguished soldiers", w)
		var he: Array = (p.report.get("heroes", []) as Array).duplicate()
		he.sort_custom(func(a, b): return int(a.kills) + int(a.veh) * 3 > int(b.kills) + int(b.veh) * 3)
		if he.is_empty():
			txt(x0, y + 12, "No kills recorded yet.", 13, UiKit.DIM)
			return y + 26.0
		for i in mini(he.size(), 8):
			var h2: Dictionary = he[i]
			var rr := Rect2(x0, y, w, 34.0)
			if i % 2 == 0:
				draw_rect(rr, Color(1, 1, 1, 0.025))
			draw_rect(Rect2(x0, y + 8, 3, 18), StatsPanel.side_col(int(h2.team)))
			txt(x0 + 12, y + 22, "%d" % (i + 1), 12, UiKit.DIM, 600)
			txt(x0 + 34, y + 16, String(h2.name), 13, UiKit.TEXT, 700)
			var unit := String(p.unit_names.get(String(h2.unit), ""))
			txt(x0 + 34, y + 30, String(h2.role) + ("  ·  " + unit if unit != "" else ""), 11, UiKit.DIM)
			var kills := StatsPanel.plural(float(h2.kills), "kill")
			if int(h2.veh) > 0:
				kills += ", " + StatsPanel.plural(float(h2.veh), "vehicle")
			txt(x0, y + 16, kills, 13, UiKit.TEXT, 600, HORIZONTAL_ALIGNMENT_RIGHT, w - 8.0)
			txt(x0, y + 30, "Alive" if bool(h2.alive) else "Killed in action", 11, UiKit.GOOD if bool(h2.alive) else UiKit.BAD, 600, HORIZONTAL_ALIGNMENT_RIGHT, w - 8.0)
			y += 36.0
		return y

	## [title, commander, figure, what it is for]
	func _honours() -> Array:
		var pl: Array = p.report.get("players", [])
		var out := []
		var b := _best(pl, func(c): return float(BattleStats.score(c)), 1.0)
		if not b.is_empty():
			out.append(["Most valuable", b, "%s points" % StatsPanel.fmt_num(BattleStats.score(b)), "The highest score: value destroyed, plus 100 a FOB taken, 15 a prisoner, 5 a man saved, 2 a structure built."])
		if pl.size() >= 2:
			var sds: Array = p.report.sides
			var e := _best(pl, func(c): return BattleStats.rating(c, sds[int(c.team)]) if float(c.val_killed) + float(c.val_lost) >= 60.0 else -1.0, 0.0)
			if not e.is_empty():
				var rv := BattleStats.rating(e, sds[int(e.team)])
				out.append(["Most effective", e, "%s  ·  %d" % [BattleStats.rating_word(rv), int(round(rv))], "The best rating: what they destroyed against what they lost, their marksmanship and their share of the fight."])
		var m := _best(pl, func(c): return StatsPanel.accuracy(c) if float(c.shots) >= 100.0 else -1.0, 0.0)
		if not m.is_empty():
			out.append(["Marksman", m, "%s of %s rounds hit" % [StatsPanel.fmt_acc(m), StatsPanel.fmt_num(float(m.shots))], "The best accuracy (at least 100 rounds fired)."])
		var t := _best(pl, func(c): return float(c.veh_kills), 1.0)
		if not t.is_empty():
			out.append(["Tank hunter", t, StatsPanel.plural(float(t.veh_kills), "vehicle") + " destroyed", "The most enemy vehicles knocked out."])
		var g := _best(pl, func(c): return float(c.captures), 1.0)
		if not g.is_empty():
			out.append(["Ground taken", g, StatsPanel.plural(float(g.captures), "FOB") + " captured", "The most enemy FOBs taken."])
		var l := _best(pl, func(c): return float(c.revived), 1.0)
		if not l.is_empty():
			out.append(["Lifesaver", l, StatsPanel.plural(float(l.revived), "wounded man", "wounded men") + " saved", "The most wounded brought back by medics and medevacs."])
		var en := _best(pl, func(c): return float(c.built), 3.0)
		if not en.is_empty():
			out.append(["Engineer", en, StatsPanel.plural(float(en.built), "structure") + " built", "The most buildings and defences completed."])
		var pr := _best(pl, func(c): return float(c.prisoners), 1.0)
		if not pr.is_empty():
			out.append(["Captor", pr, StatsPanel.plural(float(pr.prisoners), "prisoner") + " taken", "The most enemy soldiers taken prisoner."])
		return out.slice(0, 6)

	func _best(pl: Array, f: Callable, least: float) -> Dictionary:
		var best: Dictionary = {}
		var bv := least - 0.0001
		for c in pl:
			var v: float = f.call(c)
			if v > bv:
				bv = v
				best = c
		return best


# --- Commanders: the table and the selected commander's breakdown ---------------------------------

class _Commanders extends _Page:
	## [key, header, width, tooltip]
	const COLS := [
		["rating", "RATING", 150, "How well they fought, 0-100: mostly what they destroyed against what they lost (by supply value), then marksmanship and their share of their side's fight."],
		["score", "SCORE", 66, "Value destroyed, plus 100 a FOB taken, 15 a prisoner, 5 a man saved, 2 a structure built."],
		["kills", "KILLS", 54, "Enemy soldiers killed."],
		["lost", "LOSSES", 62, "Own soldiers killed or captured."],
		["kd", "K/D", 48, "Kills for every man lost."],
		["veh", "VEHICLES", 76, "Enemy vehicles destroyed / own vehicles lost."],
		["acc", "ACCURACY", 76, "Rounds that hit what they were aimed at."],
		["ex", "EXCHANGE", 80, "Supply value destroyed against supply value lost."],
		["spent", "SPENT", 64, "Supply spent."],
		["fielded", "FIELDED", 66, "Squads and vehicles trained or built."],
	]
	const DROP := ["fielded", "spent", "kd", "score", "ex"]  # what goes first when it's narrow
	const ROW_H := 46.0
	var _rows: Array = []  # [Rect2, commander id]

	func _cols(w: float) -> Array:
		var cols := COLS.duplicate()
		var total := 0.0
		for c in cols:
			total += float(c[2])
		for k in DROP:
			if w - total >= 190.0:
				break
			for i in cols.size():
				if cols[i][0] == k:
					total -= float(cols[i][2])
					cols.remove_at(i)
					break
		return cols

	func _draw() -> void:
		tips.clear()
		_rows.clear()
		if waiting():
			return
		var w := size.x
		var cols := _cols(w)
		var name_w := w
		for c in cols:
			name_w -= float(c[2])
		# header
		txt(10, 14, "COMMANDER", 10, UiKit.DIM, 700)
		var x := name_w
		for c in cols:
			txt(x, 14, String(c[1]), 10, UiKit.DIM, 700, HORIZONTAL_ALIGNMENT_RIGHT if c[0] != "rating" else HORIZONTAL_ALIGNMENT_LEFT, float(c[2]) - 8.0)
			tip(Rect2(x, 0, float(c[2]), 20), String(c[3]))
			x += float(c[2])
		var y := 24.0
		var sds: Array = p.report.sides
		for t in p.sides_in_order():
			var pl := p.players_of(t)
			if pl.is_empty():
				continue
			y += 6.0
			side_label(4, y, t, result_tag(t))
			y += 26.0
			for c in pl:
				y = _row(c, sds[t], y, w, name_w, cols, false)
			if pl.size() > 1 and p.known(t):
				var tot: Dictionary = (sds[t] as Dictionary).duplicate()
				tot["name"] = "Side total"
				tot["id"] = 0
				tot["team"] = t
				y = _row(tot, sds[t], y, w, name_w, cols, true)
		y += 14.0
		y = _detail(y, w)
		fit(y + 6.0)

	func _row(c: Dictionary, side: Dictionary, y: float, w: float, name_w: float, cols: Array, total: bool) -> float:
		var id := int(c.get("id", 0))
		var r := Rect2(0, y, w, ROW_H - 4.0)
		var me := id == p.me_id
		if id == p.pick and not total:
			draw_style_box(UiKit.boxc(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.1), 6, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.4), 1, 0.0), r)
		elif total:
			draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.08), 1.0)
		else:
			draw_style_box(UiKit.boxc(Color(1, 1, 1, 0.03), 6, Color(0, 0, 0, 0), 0, 0.0), r)
		if not total:
			_rows.append([r, id])
			draw_rect(Rect2(0, y + 9, 3, ROW_H - 22.0), StatsPanel.side_col(int(c.team)))
			txt(12, y + 19, String(c.name), 15, UiKit.ACCENT if me else UiKit.TEXT, 700, HORIZONTAL_ALIGNMENT_LEFT, name_w - 20.0)
			txt(12, y + 35, p.who_tag(c), 11, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_LEFT, name_w - 20.0)
			tip(Rect2(0, y, name_w, ROW_H), "Click for the breakdown.")
		else:
			txt(12, y + 25, "Side total", 13, UiKit.DIM, 600)
		var x := name_w
		var cy := y + 26.0
		for col in cols:
			var cw := float(col[2])
			var key: String = col[0]
			var s := ""
			match key:
				"rating":
					if not total:
						var rv := BattleStats.rating(c, side)
						var rc := StatsPanel.rating_col(rv)
						draw_rect(Rect2(x, cy - 4, 46, 5), Color(1, 1, 1, 0.08))
						draw_rect(Rect2(x, cy - 4, 46.0 * rv / 100.0, 5), rc)
						txt(x + 54, cy, "%d" % int(round(rv)), 15, rc, 700)
						txt(x + 80, cy, BattleStats.rating_word(rv), 11, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_LEFT, cw - 82.0)
					x += cw
					continue
				"score":
					s = StatsPanel.fmt_num(BattleStats.score(c))
				"kills":
					s = StatsPanel.fmt_num(float(c.kills))
				"lost":
					s = StatsPanel.fmt_num(float(c.lost) + float(c.captured))
				"kd":
					s = StatsPanel.kd(c)
				"veh":
					s = "%d / %d" % [int(c.veh_kills), int(c.veh_lost)]
				"acc":
					s = StatsPanel.fmt_acc(c)
				"ex":
					s = StatsPanel.exchange(c)
				"spent":
					s = StatsPanel.fmt_num(float(c.spent))
				"fielded":
					s = StatsPanel.fmt_num(float(c.squads) + float(c.vehicles))
			txt(x, cy, s, 14, UiKit.DIM if total else UiKit.TEXT, 600 if not total else 400, HORIZONTAL_ALIGNMENT_RIGHT, cw - 8.0)
			x += cw
		return y + ROW_H

	## The picked commander: their rating taken apart, and everything they did.
	func _detail(y0: float, w: float) -> float:
		var c: Dictionary = {}
		for pc in p.report.get("players", []):
			if int(pc.id) == p.pick:
				c = pc
		if c.is_empty():
			return y0
		var side: Dictionary = (p.report.sides as Array)[int(c.team)]
		var y := head(0, y0, "Breakdown  ·  " + String(c.name), w)
		var box := Rect2(0, y, w, 196)
		draw_style_box(UiKit.boxc(Color(1, 1, 1, 0.03), 8, Color(1, 1, 1, 0.07), 1, 0.0), box)
		var rv := BattleStats.rating(c, side)
		var rc := StatsPanel.rating_col(rv)
		# the rating, big
		var lx := 18.0
		txt(lx, y + 30, "RATING", 10, UiKit.DIM, 700)
		txt(lx, y + 74, "%d" % int(round(rv)), 46, rc, 700)
		txt(lx + 6 + UiKit.text_width("%d" % int(round(rv)), 46, 700), y + 74, BattleStats.rating_word(rv), 15, rc, 600)
		txt(lx, y + 100, "Score  " + StatsPanel.fmt_num(BattleStats.score(c)), 13, UiKit.TEXT, 600)
		txt(lx, y + 118, "Side  " + String(Defs.TEAM_NAMES[int(c.team)]), 12, UiKit.DIM)
		var tag := p.who_tag(c)
		if tag != "":
			txt(lx, y + 136, tag, 12, UiKit.DIM)
		# what the rating is made of
		var mx := 210.0
		var mw := clampf(w * 0.33, 230.0, 330.0)
		txt(mx, y + 30, "WHAT THE RATING WEIGHS", 10, UiKit.DIM, 700)
		var vk := float(c.val_killed)
		var vl := float(c.val_lost)
		var sh := float(c.shots)
		var sk := float(side.get("val_killed", 0.0))
		var rp := BattleStats.rating_parts(c, side)
		var parts := [
			["Exchange  (60%)", rp[0], "%s destroyed : %s lost  (%s)" % [StatsPanel.fmt_num(vk), StatsPanel.fmt_num(vl), StatsPanel.exchange(c)]],
			["Marksmanship  (20%)", rp[1], ("%s of %s rounds hit" % [StatsPanel.fmt_acc(c), StatsPanel.fmt_num(sh)]) if sh > 0.0 else "No rounds fired"],
			["Share of the fight  (20%)", rp[2], ("%d%% of all their side destroyed" % int(round(vk / sk * 100.0))) if sk > 0.0 else "Nothing destroyed on this side yet"],
		]
		var py := y + 50.0
		for pt in parts:
			txt(mx, py, String(pt[0]), 12, UiKit.TEXT, 600)
			draw_rect(Rect2(mx, py + 7, mw, 6), Color(1, 1, 1, 0.07))
			draw_rect(Rect2(mx, py + 7, mw * float(pt[1]), 6), StatsPanel.rating_col(float(pt[1]) * 100.0))
			txt(mx, py + 28, String(pt[2]), 11, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_LEFT, mw)
			py += 46.0
		# everything they did
		var gx := mx + mw + 34.0
		var gw := (w - gx - 14.0) / 3.0
		var groups := [
			["Combat", [["Killed", c.kills], ["Wounded", c.downs], ["Vehicles", c.veh_kills], ["Buildings", c.bld_kills], ["Prisoners", c.prisoners], ["FOBs taken", c.captures]]],
			["Losses", [["Killed", c.lost], ["Wounded", c.wounded], ["Captured", c.captured], ["Vehicles", c.veh_lost], ["Buildings", c.bld_lost], ["Saved", c.revived]]],
			["Logistics", [["Spent", c.spent], ["Squads", c.squads], ["Vehicles", c.vehicles], ["Research", c.research], ["Built", c.built], ["Fire missions", c.support]]],
		]
		if gw >= 96.0:
			for gi in groups.size():
				var gxi := gx + gi * gw
				txt(gxi, y + 30, String(groups[gi][0]).to_upper(), 10, UiKit.DIM, 700)
				var ly := y + 52.0
				for kv in groups[gi][1]:
					txt(gxi, ly, String(kv[0]), 12, UiKit.DIM)
					txt(gxi, ly, StatsPanel.fmt_num(float(kv[1])), 13, UiKit.TEXT, 600, HORIZONTAL_ALIGNMENT_RIGHT, gw - 16.0)
					ly += 22.0
		return y + box.size.y

	func _gui_input(ev: InputEvent) -> void:
		super(ev)
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			for r in _rows:
				if (r[0] as Rect2).has_point(ev.position):
					p.pick = int(r[1])
					Sfx.ui("click")
					queue_redraw()
					return


# --- Units: every squad and vehicle ----------------------------------------------------------------

class _Units extends _Page:
	const COLS := [
		["owner", "COMMANDER", 150, ""],
		["kills", "KILLS", 54, "Enemy soldiers killed."],
		["downs", "WOUNDED", 74, "Enemy soldiers put down wounded."],
		["veh", "VEHICLES", 72, "Enemy vehicles destroyed."],
		["lost", "LOSSES", 62, "Own men killed or captured."],
		["men", "STRENGTH", 78, "Men still standing, of the most it had."],
		["time", "IN ACTION", 80, "How long it has been in the field."],
		["status", "STATUS", 100, ""],
	]
	const MAX_ROWS := 60

	func _draw() -> void:
		tips.clear()
		if waiting():
			return
		var w := size.x
		var cols := COLS.duplicate()
		var fixed := 0.0
		for c in cols:
			fixed += float(c[2])
		if w - fixed < 200.0:
			cols.remove_at(0)  # no room for whose it is
			fixed -= 150.0
		var name_w := w - fixed
		txt(10, 14, "UNIT", 10, UiKit.DIM, 700)
		var x := name_w
		for c in cols:
			txt(x, 14, String(c[1]), 10, UiKit.DIM, 700, HORIZONTAL_ALIGNMENT_RIGHT if c[0] != "owner" else HORIZONTAL_ALIGNMENT_LEFT, float(c[2]) - 8.0)
			if String(c[3]) != "":
				tip(Rect2(x, 0, float(c[2]), 20), String(c[3]))
			x += float(c[2])
		var y := 24.0
		var now := float(p.report.get("t", 0.0))
		for t in p.sides_in_order():
			var us := []
			for u in p.report.get("units", []):
				if int(u.team) == t:
					us.append(u)
			if us.is_empty():
				continue
			us.sort_custom(func(a, b):
				var sa := int(a.kills) + int(a.veh_kills) * 3
				var sb := int(b.kills) + int(b.veh_kills) * 3
				return sa > sb if sa != sb else float(a.t0) < float(b.t0))
			y += 6.0
			var alive := 0
			for u in us:
				if float(u.t1) < 0.0:
					alive += 1
			side_label(4, y, t, "%d FIELDED  ·  %d STILL IN ACTION" % [us.size(), alive])
			y += 26.0
			# vehicles of one kind get a number each, in the order they arrived
			var seq := {}
			var vno := {}
			var by_t := us.duplicate()
			by_t.sort_custom(func(a, b): return float(a.t0) < float(b.t0))
			for u in by_t:
				if String(u.kind) == "vehicle":
					seq[String(u.name)] = int(seq.get(String(u.name), 0)) + 1
					vno[String(u.key)] = int(seq[String(u.name)])
			for i in mini(us.size(), MAX_ROWS):
				var u: Dictionary = us[i]
				var r := Rect2(0, y, w, 36)
				if i % 2 == 0:
					draw_style_box(UiKit.boxc(Color(1, 1, 1, 0.03), 5, Color(0, 0, 0, 0), 0, 0.0), r)
				var veh := String(u.kind) == "vehicle"
				var mine := int(u.owner) == p.me_id
				draw_rect(Rect2(0, y + 9, 3, 18), StatsPanel.side_col(t))
				var nm := String(u.name) + ((" %d" % int(vno.get(String(u.key), 1))) if veh and int(seq.get(String(u.name), 0)) > 1 else "")
				txt(12, y + 16, nm, 13, UiKit.ACCENT if mine else UiKit.TEXT, 700, HORIZONTAL_ALIGNMENT_LEFT, name_w - 16.0)
				txt(12, y + 30, "Vehicle" if veh else String(u.kind), 11, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_LEFT, name_w - 16.0)
				var gone := float(u.t1) >= 0.0
				x = name_w
				for c in cols:
					var cw := float(c[2])
					var s := ""
					var col := UiKit.TEXT
					var al := HORIZONTAL_ALIGNMENT_RIGHT
					match String(c[0]):
						"owner":
							s = String(p.names.get(int(u.owner), "-"))
							col = UiKit.DIM
							al = HORIZONTAL_ALIGNMENT_LEFT
						"kills":
							s = StatsPanel.fmt_num(float(u.kills))
						"downs":
							s = StatsPanel.fmt_num(float(u.downs))
						"veh":
							s = StatsPanel.fmt_num(float(u.veh_kills))
						"lost":
							s = StatsPanel.fmt_num(float(u.lost))
						"men":
							s = "-" if veh else "%d / %d" % [int(u.alive), maxi(int(u.men), int(u.alive))]
							col = UiKit.DIM if veh else UiKit.TEXT
						"time":
							s = StatsPanel.fmt_time((float(u.t1) if gone else now) - float(u.t0))
						"status":
							if gone:
								s = "Destroyed" if veh else "Wiped out"
								col = UiKit.BAD
							else:
								s = "In the field"
								col = UiKit.GOOD
					if s == "0":
						col = Color(UiKit.DIM.r, UiKit.DIM.g, UiKit.DIM.b, 0.7)
					txt(x, y + 23, s, 13, col, 600 if c[0] != "owner" else 400, al, cw - 8.0)
					x += cw
				y += 38.0
			if us.size() > MAX_ROWS:
				txt(12, y + 16, "... and %d more" % (us.size() - MAX_ROWS), 12, UiKit.DIM)
				y += 26.0
		fit(y + 8.0)


# --- Timeline: the battle over time ------------------------------------------------------------------

class _Timeline extends _Page:
	## [title, column of side 0, column of side 1]
	const CHARTS := [["Men in the field", 1, 2], ["Vehicles", 3, 4], ["Enemy killed (running total)", 5, 6], ["Supply in hand", 7, 8]]
	var _mouse := Vector2(-1, -1)

	func _ready() -> void:
		super()
		mouse_exited.connect(func(): _mouse = Vector2(-1, -1); queue_redraw())

	func _gui_input(ev: InputEvent) -> void:
		super(ev)
		if ev is InputEventMouseMotion:
			_mouse = ev.position
			queue_redraw()

	func _draw() -> void:
		tips.clear()
		if waiting():
			return
		var tl: Array = p.report.get("tl", [])
		if tl.size() < 2:
			txt(0, 60, "The timeline fills in as the battle goes on.", 15, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_CENTER, size.x)
			return
		var t1 := float(tl.back()[0])
		var t0 := float(tl[0][0])
		var gap := 26.0
		var lane := 64.0
		var cw := (size.x - gap) * 0.5
		var ch := (size.y - lane - gap - 8.0) * 0.5
		var rects := []
		for ci in CHARTS.size():
			rects.append(Rect2((ci % 2) * (cw + gap), (ci / 2) * (ch + gap), cw, ch))
		var strip := Rect2(0, ch * 2.0 + gap + 4.0, size.x, lane)
		# the moment under the mouse, in whichever chart (or the events strip) it's over
		var hover_t := -1.0
		if _mouse.x >= 0.0:
			for r in rects + [strip]:
				var pl := _plot_x(r)
				if (r as Rect2).has_point(_mouse) and _mouse.x >= pl.x and _mouse.x <= pl.y:
					hover_t = lerpf(t0, t1, (_mouse.x - pl.x) / (pl.y - pl.x))
		for ci in CHARTS.size():
			_chart(rects[ci], CHARTS[ci], tl, t0, t1, hover_t)
		_events(strip, t0, t1, hover_t)

	## Where a chart's (or the strip's) time axis starts and ends.
	func _plot_x(r: Rect2) -> Vector2:
		return Vector2(r.position.x + 46.0, r.end.x - 10.0)

	func _chart(r: Rect2, spec: Array, tl: Array, t0: float, t1: float, hover_t: float) -> void:
		draw_style_box(UiKit.boxc(Color(1, 1, 1, 0.025), 8, Color(1, 1, 1, 0.06), 1, 0.0), r)
		txt(r.position.x + 14, r.position.y + 22, String(spec[0]).to_upper(), 11, UiKit.ACCENT, 700)
		var plot := Rect2(r.position.x + 46, r.position.y + 36, r.size.x - 56, r.size.y - 62)
		var vmax := 1.0
		for row in tl:
			for c in [int(spec[1]), int(spec[2])]:
				vmax = maxf(vmax, float(row[c]))
		# grid lines on whole, round numbers (these are counts of men and crates)
		var step := _step(vmax / 4.0)
		var lines_n := int(ceilf(vmax / step - 0.001))
		vmax = step * lines_n
		for g in lines_n + 1:
			var gy := plot.end.y - plot.size.y * g / float(lines_n)
			draw_line(Vector2(plot.position.x, gy), Vector2(plot.end.x, gy), Color(1, 1, 1, 0.05 if g > 0 else 0.14), 1.0)
			txt(r.position.x + 4, gy + 4, StatsPanel.fmt_num(step * g), 10, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_RIGHT, 36)
		for g in 5:
			var tt := lerpf(t0, t1, g / 4.0)
			var gx := lerpf(plot.position.x, plot.end.x, g / 4.0)
			txt(gx - 30, plot.end.y + 16, StatsPanel.fmt_time(tt), 10, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_CENTER, 60)
		var span := maxf(1.0, t1 - t0)
		# each side's line, its area washed in under it (your own side drawn last, on top)
		var order := p.sides_in_order()
		for k in [1, 0]:
			var t: int = order[k]
			var col := int(spec[1 + t])
			var pts := PackedVector2Array()
			for row in tl:
				var v := float(row[col])
				if v < 0.0:
					continue
				pts.append(Vector2(plot.position.x + plot.size.x * (float(row[0]) - t0) / span, plot.end.y - plot.size.y * v / vmax))
			if pts.size() < 2:
				continue
			var sc := StatsPanel.side_col(t)
			var area := pts.duplicate()
			area.append(Vector2(pts[pts.size() - 1].x, plot.end.y))
			area.append(Vector2(pts[0].x, plot.end.y))
			var cols := PackedColorArray()
			cols.resize(area.size())
			cols.fill(Color(sc.r, sc.g, sc.b, 0.08))
			if Geometry2D.triangulate_polygon(area).size() > 0:
				draw_polygon(area, cols)
			draw_polyline(pts, sc, 2.0, true)
		# legend
		var lx := r.end.x - 12.0
		for t in [order[1], order[0]]:
			var nm := String(Defs.TEAM_NAMES[t])
			var known: bool = float(tl.back()[int(spec[1 + t])]) >= 0.0
			if not known:
				nm += " (classified)"
			var tw := UiKit.text_width(nm, 11, 600)
			lx -= tw
			txt(lx, r.position.y + 22, nm, 11, StatsPanel.side_col(t).lightened(0.3) if known else UiKit.DIM, 600)
			draw_rect(Rect2(lx - 14, r.position.y + 15, 9, 3), StatsPanel.side_col(t))
			lx -= 28.0
		# the cursor: both sides' figures at that moment
		if hover_t >= 0.0:
			var hx := plot.position.x + plot.size.x * (hover_t - t0) / span
			draw_line(Vector2(hx, plot.position.y), Vector2(hx, plot.end.y), Color(1, 1, 1, 0.3), 1.0)
			var row := _at(tl, hover_t)
			var ty := plot.position.y + 4.0
			var lines := []
			for t in order:
				var v := float(row[int(spec[1 + t])])
				if v >= 0.0:
					lines.append([t, StatsPanel.fmt_num(v)])
			var bw := 92.0
			var bx := hx + 8.0 if hx + 8.0 + bw < plot.end.x else hx - 8.0 - bw
			var bh := 20.0 + 16.0 * lines.size()
			draw_style_box(UiKit.boxc(Color(0.03, 0.035, 0.03, 0.92), 5, Color(1, 1, 1, 0.12), 1, 0.0), Rect2(bx, ty, bw, bh))
			txt(bx + 8, ty + 14, StatsPanel.fmt_time(hover_t), 10, UiKit.DIM, 600)
			for li in lines.size():
				var t: int = lines[li][0]
				draw_rect(Rect2(bx + 8, ty + 24 + li * 16, 6, 6), StatsPanel.side_col(t))
				txt(bx + 20, ty + 31 + li * 16, String(lines[li][1]), 12, UiKit.TEXT, 600)

	## The sample nearest to time t.
	func _at(tl: Array, t: float) -> Array:
		var best: Array = tl[0]
		for row in tl:
			if absf(float(row[0]) - t) < absf(float(best[0]) - t):
				best = row
		return best

	## A round step at or above v between grid lines: 1, 2, 5, 10, 20, 50...
	func _step(v: float) -> float:
		if v <= 1.0:
			return 1.0
		var e := pow(10.0, floorf(log(v) / log(10.0)))
		for m in [1.0, 2.0, 5.0, 10.0]:
			if m * e >= v - 0.0001:
				return m * e
		return 10.0 * e

	## FOBs, vehicles lost and fire missions along the bottom; hover one to read it.
	func _events(r: Rect2, t0: float, t1: float, hover_t: float) -> void:
		var ev: Array = p.report.get("ev", [])
		txt(r.position.x + 14, r.position.y + 14, "EVENTS", 11, UiKit.ACCENT, 700)
		var px := _plot_x(r)
		var x0 := px.x
		var x1 := px.y
		var plot_w := x1 - x0
		var span := maxf(1.0, t1 - t0)
		var ly := r.position.y + 34.0
		draw_line(Vector2(x0, ly), Vector2(x1, ly), Color(1, 1, 1, 0.12), 1.0)
		var near := []
		var best_d := 1e9
		for e in ev:
			var ex := x0 + plot_w * (float(e[0]) - t0) / span
			var t := int(e[1])
			var c := StatsPanel.side_col(t)
			var kind := String(e[2])
			var cy := ly + (-7.0 if kind == "fob" else (7.0 if kind == "sup" else 0.0))
			match kind:
				"fob":
					MapSymbols.poly(self, PackedVector2Array([Vector2(ex, cy - 5), Vector2(ex + 5, cy), Vector2(ex, cy + 5), Vector2(ex - 5, cy)]), c)
				"sup":
					MapSymbols.poly(self, PackedVector2Array([Vector2(ex, cy - 4), Vector2(ex + 4, cy + 3), Vector2(ex - 4, cy + 3)]), c.lightened(0.2))
				_:
					draw_rect(Rect2(ex - 3, cy - 3, 6, 6), c.darkened(0.1))
			tip(Rect2(ex - 6, cy - 7, 12, 14), "%s  %s" % [StatsPanel.fmt_time(float(e[0])), String(e[3])])
			var d := absf(_mouse.x - ex) + absf(_mouse.y - cy) * 0.5
			if _mouse.x >= 0.0 and d < best_d and d < 24.0:
				best_d = d
				near = e
		if not near.is_empty():
			txt(x0, ly + 26, "%s   %s" % [StatsPanel.fmt_time(float(near[0])), String(near[3])], 12, UiKit.TEXT, 600)
		elif ev.is_empty():
			txt(x0, ly + 26, "Nothing of note yet.", 12, UiKit.DIM)
		else:
			# the key
			var kx := x0 + 6.0
			var ky := ly + 22.0
			var kc := Color(0.75, 0.76, 0.72)
			MapSymbols.poly(self, PackedVector2Array([Vector2(kx, ky - 5), Vector2(kx + 5, ky), Vector2(kx, ky + 5), Vector2(kx - 5, ky)]), kc)
			txt(kx + 10, ky + 4, "FOBs", 12, UiKit.DIM)
			kx += 24.0 + UiKit.text_width("FOBs", 12)
			draw_rect(Rect2(kx - 3, ky - 3, 6, 6), kc)
			txt(kx + 10, ky + 4, "Vehicles lost", 12, UiKit.DIM)
			kx += 24.0 + UiKit.text_width("Vehicles lost", 12)
			MapSymbols.poly(self, PackedVector2Array([Vector2(kx, ky - 4), Vector2(kx + 4, ky + 3), Vector2(kx - 4, ky + 3)]), kc)
			txt(kx + 10, ky + 4, "Fire missions", 12, UiKit.DIM)
			txt(kx + 24 + UiKit.text_width("Fire missions", 12), ky + 4, "(hover one to read it)", 12, Color(UiKit.DIM.r, UiKit.DIM.g, UiKit.DIM.b, 0.7))
		if hover_t >= 0.0:
			var hx := x0 + plot_w * (hover_t - t0) / span
			draw_line(Vector2(hx, ly - 12), Vector2(hx, ly + 12), Color(1, 1, 1, 0.25), 1.0)
