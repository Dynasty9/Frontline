class_name StatsPanel
extends PanelContainer
## The battle's figures in four tabs - Summary (the two sides head to head,
## honours, the soldiers who stood out), Commanders (each player's and AI's
## effectiveness, and what it is made of), Units (every squad and vehicle) and
## Timeline (strength, kills and supply over the battle). Hold Tab in a battle
## for your own side's so far (the enemy's figures are classified until it's
## over); the end-of-battle screen carries the whole after-action report, and
## the menu's Service Record opens it again for any battle on the record.
##
## Signal (docs/UI.md): flat ink with corner ticks, rules between rows, every
## figure in mono, counted bars, the sides marked by small squares in their
## colours. It moves like a display redrawing: each tab comes in row by row, a
## few pixels from where it belongs, numbers count up with a tick, bars and
## dials fill step by step, honours land one at a time, and the timeline's
## lines draw themselves across. All drawn; all real time, so a paused or
## fast-forwarded battle doesn't change how it feels; Reduce motion cuts it all.

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
# motion
var page_t := 0.0  # seconds since the current tab came in
var moving := false  # set while a page draws: something on it is still moving
var dt := 0.0  # this frame's real seconds
var _vals := {}  # numbers counting: key -> [from, to, start, duration]
var _cues := {}  # the reveal's one-off sounds, already played
var _last_ms := 0
var _tick_ms := 0
var _title: Label
var _sub: Label
var _close: Button
var _hint: Label
var _bar: _TabBar
var _pages := {}


func _ready() -> void:
	theme = UiKit.theme()
	var sb := StyleBoxEmpty.new()
	var pad := 0.0 if embedded else 24.0
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad - 2.0 if pad > 0.0 else 0.0
	sb.content_margin_bottom = pad - 4.0 if pad > 0.0 else 0.0
	add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)
	if not embedded:
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 14)
		vb.add_child(top)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 3)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(tv)
		_title = UiKit.caps(title, 18, UiKit.TEXT, 600, 2)
		tv.add_child(_title)
		# when, and whose figures: codes (T+04:31 · BOTH SIDES)
		_sub = UiKit.mono_label("", 12, UiKit.DIM)
		_sub.uppercase = true
		tv.add_child(_sub)
		_hint = UiKit.caps("Release Tab to return", 11, UiKit.FAINT)
		_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(_hint)
		_close = UiKit.button("Close   Esc", "secondary", 120, 32)
		_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_close.pressed.connect(func(): Sfx.ui("click"); closed.emit())
		top.add_child(_close)
	_bar = _TabBar.new()
	_bar.p = self
	_bar.custom_minimum_size = Vector2(0, 40)
	vb.add_child(_bar)
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
	visibility_changed.connect(_on_visibility)
	_on_visibility()


func show_tab(key: String) -> void:
	if not _pages.has(key):
		key = "summary"
	tab = key
	for k in _pages:
		var pg: Control = _pages[k]
		var holder: Control = pg.get_parent() if pg.get_parent() is ScrollContainer else pg
		holder.visible = k == key
		if holder is ScrollContainer and k == key:
			(holder as ScrollContainer).scroll_vertical = 0
	reveal()


## The current tab comes in again from the start.
func reveal() -> void:
	page_t = 0.0
	_vals.clear()
	_cues.clear()
	moving = true
	if _pages.has(tab):
		(_pages[tab] as Control).queue_redraw()
	if _bar:
		_bar.queue_redraw()


func _on_visibility() -> void:
	if is_visible_in_tree():
		_last_ms = Time.get_ticks_msec()
		reveal()


## In (a peek, Tab held, or opened from the menu): it cuts in, and its tab
## comes in row by row.
func pop_in() -> void:
	modulate.a = 1.0
	scale = Vector2.ONE
	visible = true


## ...and cuts out.
func pop_out() -> void:
	visible = false


func _process(_d: float) -> void:
	var now := Time.get_ticks_msec()
	dt = clampf((now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now
	if not is_visible_in_tree():
		return
	page_t += dt * (1.6 if peek else 1.0)
	if moving and _pages.has(tab):
		(_pages[tab] as Control).queue_redraw()


## The sheet: flat ink and its corner ticks.
func _draw() -> void:
	if embedded:
		return
	UiFx.panel(self, Rect2(Vector2.ZERO, size), 1.0)


# --- motion -----------------------------------------------------------------------------------

## How far in something is that starts `delay` seconds into the reveal (0-1):
## fast and exact, like a display redrawing (there at once with Reduce motion).
func appear(delay: float, dur := UiMotion.BASE) -> float:
	if UiMotion.reduced():
		return 1.0
	var k := UiFx.span(page_t, delay, dur)
	if k < 1.0:
		moving = true
	return UiFx.out_expo(k)


## A number counting up to `target` (from 0 when it first shows, from where it
## was when the figure changes), with a tick while it runs.
func num(key: String, target: float, delay := 0.0, dur := 0.9) -> float:
	if UiMotion.reduced():
		return target
	var v: Array = _vals.get(key, [])
	if v.is_empty():
		v = [0.0, target, delay, dur]
		_vals[key] = v
	elif absf(float(v[1]) - target) > 0.0001:
		var cur := _eval(v)
		v[0] = cur
		v[1] = target
		v[2] = page_t
		v[3] = 0.5
	var k := UiFx.span(page_t, float(v[2]), float(v[3]))
	if k < 1.0:
		moving = true
		if k > 0.0:
			_tick()
	return _eval(v)


func _eval(v: Array) -> float:
	return lerpf(float(v[0]), float(v[1]), UiFx.out_expo(UiFx.span(page_t, float(v[2]), float(v[3]))))


func _tick() -> void:
	var now := Time.get_ticks_msec()
	if peek or page_t > 2.4 or now - _tick_ms < 48:
		return
	_tick_ms = now
	Sfx.ui("ui_tick", -24.0, randf_range(0.94, 1.08))


## A sound that plays once per reveal (an honour landing).
func cue(key: String, sname: String, vol := -12.0, pitch := 1.0) -> void:
	if peek or _cues.has(key):
		return
	_cues[key] = true
	Sfx.ui(sname, vol, pitch)


# --- the report ---------------------------------------------------------------------------------

func set_report(r: Dictionary) -> void:
	var first := report.is_empty() and not r.is_empty()
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
			_sub.text = "T+%s  ·  %s" % [_clock(float(r.get("t", 0.0))), whose]
	if _hint:
		_hint.visible = peek
		_close.visible = not peek
	_bar.note = "" if r.is_empty() or bool(r.get("full", false)) else "Enemy figures classified until the battle is over"
	_bar.queue_redraw()
	if first:
		reveal()
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
# (counts, times and the rating's word and colour: UiKit.fmt_num, fmt_time, rating_word, rating_col)

## The battle clock as the HUD writes it: 04:31, or 1:04:31.
static func _clock(t: float) -> String:
	var s := maxi(0, int(t))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%02d:%02d" % [s / 60, s % 60]


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


static func plural(n: float, one: String, many := "") -> String:
	var i := int(round(n))
	return "%s %s" % [UiKit.fmt_num(i), one if i == 1 else (many if many != "" else one + "s")]


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
		bits.append("Left")
	return "  ·  ".join(bits)


# --- the tab bar --------------------------------------------------------------------------------

## The tabs as capitals, the open one in the accent and underlined (it cuts
## to the new one: a display doesn't glide); the classified note sits on the right.
class _TabBar extends Control:
	const FS := 13
	var p: StatsPanel
	var note := ""
	var _hover := -1
	var _rects: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_exited.connect(func(): _hover = -1; queue_redraw())

	func _draw() -> void:
		_rects.clear()
		var f := UiKit.cond(600, 2)
		var base := size.y - 14.0
		var x := 2.0
		for i in StatsPanel.TABS.size():
			var lab := String(StatsPanel.TABS[i][1]).to_upper()
			var w := UiFx.width(f, lab, FS)
			_rects.append(Rect2(x - 12.0, 0.0, w + 24.0, size.y))
			var on: bool = StatsPanel.TABS[i][0] == p.tab
			var col := UiKit.ACCENT if on else (UiKit.TEXT if i == _hover else UiKit.FAINT)
			draw_string(f, Vector2(x, base), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, col)
			x += w + 30.0
		draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), UiKit.LINE, 1.0)
		for i in StatsPanel.TABS.size():
			if StatsPanel.TABS[i][0] == p.tab:
				var ur: Rect2 = _rects[i]
				draw_rect(Rect2(ur.position.x + 12.0, size.y - 2.0, ur.size.x - 24.0, 2.0), UiKit.ACCENT)
		if note != "":
			draw_string(UiKit.cond(600, 1), Vector2(0, base), note.to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4.0, 11, UiKit.FAINT)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var h := -1
			for i in _rects.size():
				if (_rects[i] as Rect2).has_point(ev.position):
					h = i
			if h != _hover:
				_hover = h
				queue_redraw()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			for i in _rects.size():
				if (_rects[i] as Rect2).has_point(ev.position):
					var key: String = StatsPanel.TABS[i][0]
					if key != p.tab:
						Sfx.ui("click", -10.0)
						Sfx.ui("ui_whoosh", -22.0, 1.35)
						p.show_tab(key)
					return


# --- the pages ---------------------------------------------------------------------------------

## A page draws itself from the panel's report; inside a ScrollContainer it
## asks for as much height as it drew. Everything goes through the helpers so
## a row can be faded (`ink`) and slid in as one.
class _Page extends Control:
	var p: StatsPanel
	var tips: Array = []  # [Rect2, text] for the tooltip under the mouse
	var ink := 1.0
	var mouse := Vector2(-1, -1)

	func _ready() -> void:
		resized.connect(queue_redraw)
		mouse_exited.connect(func(): mouse = Vector2(-1, -1); queue_redraw())

	## The start of every draw: false when there's nothing to show yet.
	func begin() -> bool:
		tips.clear()
		p.moving = false
		settle()
		return not waiting()

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
			mouse = ev.position
			tooltip_text = _get_tooltip(mouse)
			queue_redraw()

	func hot(r: Rect2) -> bool:
		return r.has_point(mouse)

	func c(col: Color) -> Color:
		return Color(col.r, col.g, col.b, col.a * ink)

	func rect(r: Rect2, col: Color) -> void:
		draw_rect(r, c(col))

	func line(a: Vector2, b: Vector2, col: Color, w := 1.0) -> void:
		draw_line(a, b, c(col), w)

	## Prose: the few sentences.
	func txt(x: float, y: float, s: String, fs := 13, col := UiKit.TEXT, wt := 400, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
		draw_string(UiKit.font(wt), Vector2(x, y), s, align, w, fs, c(col))

	## Capitals in the label face: headings, labels, names, tags.
	func cap(x: float, y: float, s: String, fs := 11, col := UiKit.FAINT, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, sp := 1) -> void:
		draw_string(UiKit.cond(600, sp), Vector2(x, y), s.to_upper(), align, w, fs, c(col))

	## The big figures, in heavy mono (a scoreboard).
	func big(x: float, y: float, s: String, fs := 20, col := UiKit.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
		draw_string(UiFx.digits(700), Vector2(x, y), s, align, w, fs, c(col))

	## Every other figure, code, time and state, in mono.
	func fig(x: float, y: float, s: String, fs := 12, col := UiKit.DIM, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
		draw_string(UiKit.mono(400), Vector2(x, y), s, align, w, fs, c(col))

	## A side's mark: a small square in its colour.
	func mark(x: float, y: float, t: int, s := 8.0) -> void:
		rect(Rect2(x, y, s, s), StatsPanel.side_col(t))

	## A hairline under a row.
	func rule_under(x: float, y: float, w: float) -> void:
		line(Vector2(x, floorf(y) + 0.5), Vector2(x + w, floorf(y) + 0.5), UiKit.LINE)

	## Everything drawn next fades by `a` and comes in from (dx, dy): a few
	## pixels, as a display draws a new line.
	func slide(a: float, dx := UiMotion.TRAVEL_MD, dy := 0.0) -> void:
		ink = a
		draw_set_transform(Vector2((1.0 - a) * dx, (1.0 - a) * dy))

	func settle() -> void:
		ink = 1.0
		draw_set_transform(Vector2.ZERO)

	func waiting() -> bool:
		if not p.report.is_empty():
			return false
		var dots := ".".repeat(int(Time.get_ticks_msec() / 350) % 4)
		cap(0, 64, "Gathering reports from the field" + dots, 12, UiKit.FAINT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 2)
		p.moving = true
		fit(120)
		return true

	## A section header: faint capitals, a count in mono if there is one, and a
	## rule running on to `w` (drawn across as it comes in).
	func head(x: float, y: float, s: String, w := 0.0, delay := 0.0, count := "") -> float:
		var a := p.appear(delay)
		ink = a
		var x0 := x + UiFx.width(UiKit.cond(600, 1), s.to_upper(), 11) + 8.0
		cap(x, y + 13, s, 11, UiKit.DIM)
		if count != "":
			fig(x0, y + 13, count, 11, UiKit.FAINT)
			x0 += UiFx.width(UiKit.mono(400), count, 11) + 8.0
		if w > 0.0:
			line(Vector2(x0, y + 9.5), Vector2(x0 + (x + w - x0) * a, y + 9.5), UiKit.LINE)
		ink = 1.0
		return y + 26.0

	## A side: its square, its name in capitals, and how it ended for them.
	func side_label(x: float, y: float, t: int, extra := "", right := false, w := 0.0) -> void:
		var nm := String(Defs.TEAM_NAMES[t]).to_upper()
		var f := UiKit.cond(600, 2)
		var nw := UiFx.width(f, nm, 15)
		if not right:
			mark(x, y + 6, t)
			draw_string(f, Vector2(x + 16, y + 15), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c(UiKit.TEXT))
			if extra != "":
				stamp(x + nw + 30.0, y + 1.0, extra, false)
		else:
			var rx := x + w
			mark(rx - 8, y + 6, t)
			draw_string(f, Vector2(rx - 16 - nw, y + 15), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c(UiKit.TEXT))
			if extra != "":
				stamp(rx - nw - 30.0, y + 1.0, extra, true)

	## A tag: how it ended (VICTORIOUS, DEFEATED) in a hairline square of its
	## colour, or a count, plain, in mono.
	func stamp(x: float, y: float, s: String, right: bool) -> void:
		var state := s == "VICTORIOUS" or s == "DEFEATED"
		if not state:
			var mf := UiKit.mono(400)
			var mw := UiFx.width(mf, s, 11)
			fig(x - (mw if right else 0.0), y + 13, s, 11, UiKit.DIM)
			return
		var f := UiKit.cond(600, 1)
		var w := UiFx.width(f, s, 11) + 12.0
		var col := UiKit.GOOD if s == "VICTORIOUS" else UiKit.BAD
		var r := Rect2(x - (w if right else 0.0), y, w, 18)
		draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), c(UiFx.fade(col, 0.5)), false, 1.0)
		draw_string(f, Vector2(r.position.x + 6, y + 13), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c(col))

	func result_tag(t: int) -> String:
		if not bool(p.report.get("over", false)):
			return ""
		return "VICTORIOUS" if int(p.report.get("winner", -1)) == t else "DEFEATED"

	## A table's column headings.
	func columns(first: String, name_w: float, cols: Array, left_keys: Array) -> void:
		cap(10, 14, first, 10, UiKit.FAINT)
		var x := name_w
		for col in cols:
			var key: String = col[0]
			cap(x, 14, String(col[1]), 10, UiKit.FAINT, HORIZONTAL_ALIGNMENT_LEFT if key in left_keys else HORIZONTAL_ALIGNMENT_RIGHT, float(col[2]) - 8.0, 1)
			if col.size() > 3 and String(col[3]) != "":
				tip(Rect2(x, 0, float(col[2]), 20), String(col[3]))
			x += float(col[2])
		rule_under(0, 22, size.x)


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
		["towns", "Towns taken", 1, "Towns and villages taken (each one's supply dump and trucks come with it)."],
		["revived", "Wounded saved", 1, "Times a medic or a medevac brought a wounded man back."],
		["delivered", "Supply delivered", 1, "Supply the trucks and helicopters brought to the FOBs."],
		["spent", "Supply spent", 0, "Supply spent on troops, vehicles, buildings, research and fire support."],
		["fielded", "Units fielded", 0, "Squads and vehicles trained or built."],
		["built", "Structures built", 0, "Buildings and defences completed."],
		["support", "Fire missions", 0, "Air and artillery support called in."],
	]
	const ROW_H := 38.0
	const STEP := 8.0  # the split bar: a step and the gap after it
	const KINDS := {"Most valuable": "star", "Most effective": "chevrons", "Marksman": "reticle", "Tank hunter": "tank",
		"Ground taken": "flag", "Lifesaver": "cross", "Engineer": "spade", "Captor": "lock"}

	func _draw() -> void:
		if not begin():
			return
		var w := size.x
		var two := w >= 780.0
		var lw := floorf(w * 0.54) if two else w
		var y1 := _h2h(0.0, lw)
		var y2 := 0.0
		# (kept off the edges by the honours' corner ticks)
		if two:
			y2 = _right(lw + 36.0, 4.0, w - lw - 40.0)
		else:
			y2 = _right(4.0, y1 + 22.0, w - 8.0)
		settle()
		fit(maxf(y1, y2) + 10.0)

	func _val(sd: Dictionary, key: String) -> float:
		match key:
			"acc":
				var a := StatsPanel.accuracy(sd)
				return a * 100.0 if a >= 0.0 else 0.0
			"fielded":
				return float(sd.get("squads", 0.0)) + float(sd.get("vehicles", 0.0))
		return float(sd.get(key, 0.0))

	func _fmt(sd: Dictionary, key: String, v: float) -> String:
		if key == "acc":
			return ("%d%%" % int(round(v))) if StatsPanel.accuracy(sd) >= 0.0 else "-"
		return UiKit.fmt_num(v)

	func _h2h(x0: float, w: float) -> float:
		var order := p.sides_in_order()
		var a: int = order[0]
		var b: int = order[1]
		var sds: Array = p.report.sides
		var sa: Dictionary = sds[a]
		var sb: Dictionary = sds[b]
		var kb := not sb.is_empty()
		var ha := p.appear(0.0)
		slide(ha, -8.0)
		side_label(x0, 0.0, a, result_tag(a))
		slide(ha, 8.0)
		side_label(x0, 0.0, b, result_tag(b), true, w)
		settle()
		var y := 36.0
		var ca := StatsPanel.side_col(a)
		var cb := StatsPanel.side_col(b)
		# the split bar's steps: as many as fit, 6 px with a 2 px gap
		var n := maxi(10, int((w + 2.0) / STEP))
		var bx := x0 + floorf((w - (n * STEP - 2.0)) * 0.5)
		for i in ROWS.size():
			var row: Array = ROWS[i]
			var key: String = row[0]
			var d := 0.05 + mini(i, 12) * 0.02
			var ra := p.appear(d)
			slide(ra, 0.0, UiMotion.TRAVEL_SM)
			var tva := _val(sa, key)
			var tvb := _val(sb, key) if kb else 0.0
			var va := p.num("a:" + key, tva, d, 0.9)
			var vb := p.num("b:" + key, tvb, d, 0.9) if kb else 0.0
			var better: int = row[2]
			var col_a := UiKit.TEXT
			var col_b := UiKit.TEXT if kb else UiKit.FAINT
			var a_wins := false
			var b_wins := false
			if kb and better != 0 and tva != tvb:
				a_wins = (tva > tvb) == (better > 0)
				b_wins = not a_wins
				col_a = UiKit.TEXT if a_wins else UiKit.DIM
				col_b = UiKit.DIM if a_wins else UiKit.TEXT
			var r := Rect2(x0, y, w, ROW_H - 4.0)
			if hot(r):
				rect(r.grow_individual(6, 0, 6, 0), UiKit.fa(UiKit.TEXT, 0.05))
			big(x0, y + 18, _fmt(sa, key, va), 19, col_a)
			cap(x0, y + 15, String(row[1]), 11, UiKit.FAINT, HORIZONTAL_ALIGNMENT_CENTER, w, 1)
			big(x0, y + 18, _fmt(sb, key, vb) if kb else "-", 19, col_b, HORIZONTAL_ALIGNMENT_RIGHT, w)
			# the split, in counted steps: each side's share lights outward
			# from where they meet, the side that did better at full strength;
			# where nothing's lit (yet, or at all) the row's rule runs on
			var by := y + 25.0
			var na := 0
			var lo := 0  # the steps lit, [lo, hi)
			var hi := 0
			if kb and tva + tvb > 0.0:
				na = roundi(n * tva / (tva + tvb))
				var lit := ceili(p.appear(d + 0.06, 0.5) * n)
				lo = maxi(0, na - lit)
				hi = mini(n, na + lit)
			elif tva > 0.0:
				na = int(n * 0.5)  # (the enemy's figure classified: ours, on its own)
				lo = maxi(0, na - ceili(p.appear(d + 0.06, 0.5) * n))
				hi = na
			for k in range(lo, hi):
				var sc: Color
				if not kb:
					sc = UiFx.fade(ca, 0.5)
				elif k < na:
					sc = UiFx.fade(ca, 0.55 if b_wins else 0.95)
				else:
					sc = UiFx.fade(cb, 0.55 if a_wins else 0.95)
				rect(Rect2(bx + k * STEP, by, STEP - 2.0, 5.0), sc)
			if lo > 0:
				line(Vector2(bx, by + 2.5), Vector2(bx + lo * STEP - 2.0, by + 2.5), UiKit.LINE)
			if hi < n:
				line(Vector2(bx + hi * STEP, by + 2.5), Vector2(bx + n * STEP - 2.0, by + 2.5), UiKit.LINE)
			tip(Rect2(x0, y, w, ROW_H - 4.0), String(row[3]))
			settle()
			y += ROW_H
		return y

	func _right(x0: float, y0: float, w: float) -> float:
		var hs := _honours()
		var y := head(x0, y0, "Honours", w, 0.1, ("%d" % hs.size()) if not hs.is_empty() else "")
		if hs.is_empty():
			ink = p.appear(0.15)
			txt(x0, y + 14, "Nobody has distinguished themselves yet.", 13, UiKit.FAINT)
			settle()
			y += 28.0
		var cw := floorf((w - 10.0) * 0.5)
		for i in hs.size():
			var h: Array = hs[i]
			var who: Dictionary = h[1]
			var mvp := i == 0
			var r: Rect2
			if mvp:
				r = Rect2(x0, y, w, 86.0)
			else:
				var j := i - 1
				r = Rect2(x0 + (j % 2) * (cw + 10.0), y + 96.0 + (j / 2) * 72.0, cw, 64.0)
			# one at a time: each lands a few pixels from its place, with its sound
			var d := 0.2 + i * 0.12
			var a := p.appear(d)
			if a <= 0.0:
				continue
			if a > 0.02:
				p.cue("medal%d" % i, "ui_medal", -15.0 if mvp else -19.0, 1.0 + i * 0.05)
			slide(a, 0.0, UiMotion.TRAVEL_SM)
			var tc := StatsPanel.side_col(int(who.team))
			# a card on the sheet; the highest honour's ticks in the accent
			UiFx.card(self, r, ink, 1.0 if mvp else 0.0)
			if hot(r):
				rect(r, UiKit.fa(UiKit.TEXT, 0.05))
			var ic := r.position + Vector2(38.0 if mvp else 30.0, r.size.y * 0.5)
			UiFx.insignia(self, String(KINDS.get(String(h[0]), "star")), ic, 26.0 if mvp else 19.0, UiKit.ACCENT if mvp else tc, ink)
			var tx := r.position.x + (78.0 if mvp else 60.0)
			var tw2 := r.size.x - (tx - r.position.x) - 10.0
			cap(tx, r.position.y + (24.0 if mvp else 20.0), String(h[0]), 11, UiKit.ACCENT if mvp else UiKit.FAINT, HORIZONTAL_ALIGNMENT_LEFT, tw2, 1)
			cap(tx, r.position.y + (50.0 if mvp else 39.0), String(who.name), 20 if mvp else 15, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, tw2, 1)
			fig(tx, r.position.y + (70.0 if mvp else 56.0), String(h[2]).to_upper(), 12, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, tw2)
			settle()
			tip(r, String(h[3]))
		if not hs.is_empty():
			y += 96.0 + ceilf((hs.size() - 1) / 2.0) * 72.0 + 6.0
		var he: Array = (p.report.get("heroes", []) as Array).duplicate()
		he.sort_custom(func(a, b): return int(a.kills) + int(a.veh) * 3 > int(b.kills) + int(b.veh) * 3)
		y = head(x0, y, "Distinguished soldiers", w, 0.3, ("%d" % mini(he.size(), 8)) if not he.is_empty() else "")
		if he.is_empty():
			ink = p.appear(0.35)
			txt(x0, y + 14, "No kills recorded yet.", 13, UiKit.FAINT)
			settle()
			return y + 28.0
		for i in mini(he.size(), 8):
			var h2: Dictionary = he[i]
			var ra := p.appear(0.35 + i * 0.02)
			slide(ra, UiMotion.TRAVEL_MD)
			var rr := Rect2(x0, y, w, 36.0)
			if hot(rr):
				rect(rr, UiKit.fa(UiKit.TEXT, 0.05))
			rule_under(x0, y + 36.0, w)
			# the rank, the side's square, the man
			fig(x0 + 4, y + 23, "%d" % (i + 1), 13, UiKit.FAINT, HORIZONTAL_ALIGNMENT_RIGHT, 16)
			mark(x0 + 30, y + 8, int(h2.team))
			cap(x0 + 46, y + 16, String(h2.name), 14, UiKit.TEXT)
			var unit := String(p.unit_names.get(String(h2.unit), ""))
			cap(x0 + 46, y + 31, String(h2.role) + ("  ·  " + unit if unit != "" else ""), 10, UiKit.FAINT)
			var kills := StatsPanel.plural(float(h2.kills), "kill")
			if int(h2.veh) > 0:
				kills += ", " + StatsPanel.plural(float(h2.veh), "vehicle")
			fig(x0, y + 16, kills.to_upper(), 12, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, w - 8.0)
			if bool(h2.alive):
				fig(x0, y + 31, "ALIVE", 10, UiKit.GOOD, HORIZONTAL_ALIGNMENT_RIGHT, w - 8.0)
			else:
				fig(x0, y + 31, "KIA", 10, UiKit.BAD, HORIZONTAL_ALIGNMENT_RIGHT, w - 8.0)
			settle()
			y += 38.0
		return y

	## [title, commander, figure, what it is for]
	func _honours() -> Array:
		var pl: Array = p.report.get("players", [])
		var out := []
		var b := _best(pl, func(c2): return float(BattleStats.score(c2)), 1.0)
		if not b.is_empty():
			out.append(["Most valuable", b, "%s points" % UiKit.fmt_num(BattleStats.score(b)), "The highest score: value destroyed, plus 100 a FOB taken, 50 a town, 15 a prisoner, 5 a man saved, 2 a structure built."])
		if pl.size() >= 2:
			var sds: Array = p.report.sides
			var e := _best(pl, func(c2): return BattleStats.rating(c2, sds[int(c2.team)]) if float(c2.val_killed) + float(c2.val_lost) >= 60.0 else -1.0, 0.0)
			if not e.is_empty():
				var rv := BattleStats.rating(e, sds[int(e.team)])
				out.append(["Most effective", e, "%s  ·  %d" % [UiKit.rating_word(rv), int(round(rv))], "The best rating: what they destroyed against what they lost, their marksmanship and their share of the fight."])
		var m := _best(pl, func(c2): return StatsPanel.accuracy(c2) if float(c2.shots) >= 100.0 else -1.0, 0.0)
		if not m.is_empty():
			out.append(["Marksman", m, "%s of %s rounds hit" % [StatsPanel.fmt_acc(m), UiKit.fmt_num(float(m.shots))], "The best accuracy (at least 100 rounds fired)."])
		var t := _best(pl, func(c2): return float(c2.veh_kills), 1.0)
		if not t.is_empty():
			out.append(["Tank hunter", t, StatsPanel.plural(float(t.veh_kills), "vehicle") + " destroyed", "The most enemy vehicles knocked out."])
		var g := _best(pl, func(c2): return float(c2.captures) + float(c2.get("towns", 0)), 1.0)
		if not g.is_empty():
			var gt := []
			if float(g.captures) > 0.0:
				gt.append(StatsPanel.plural(float(g.captures), "FOB"))
			if float(g.get("towns", 0)) > 0.0:
				gt.append(StatsPanel.plural(float(g.towns), "town"))
			out.append(["Ground taken", g, " and ".join(gt) + " taken", "The most FOBs and towns taken."])
		var l := _best(pl, func(c2): return float(c2.revived), 1.0)
		if not l.is_empty():
			out.append(["Lifesaver", l, StatsPanel.plural(float(l.revived), "wounded man", "wounded men") + " saved", "The most wounded brought back by medics and medevacs."])
		var en := _best(pl, func(c2): return float(c2.built), 3.0)
		if not en.is_empty():
			out.append(["Engineer", en, StatsPanel.plural(float(en.built), "structure") + " built", "The most buildings and defences completed."])
		var pr := _best(pl, func(c2): return float(c2.prisoners), 1.0)
		if not pr.is_empty():
			out.append(["Captor", pr, StatsPanel.plural(float(pr.prisoners), "prisoner") + " taken", "The most enemy soldiers taken prisoner."])
		return out.slice(0, 7)

	func _best(pl: Array, f: Callable, least: float) -> Dictionary:
		var best: Dictionary = {}
		var bv := least - 0.0001
		for c2 in pl:
			var v: float = f.call(c2)
			if v > bv:
				bv = v
				best = c2
		return best


# --- Commanders: the table and the selected commander's breakdown ---------------------------------

class _Commanders extends _Page:
	## [key, header, width, tooltip]
	const COLS := [
		["rating", "RATING", 150, "How well they fought, 0-100: mostly what they destroyed against what they lost (by supply value), then marksmanship and their share of their side's fight."],
		["score", "SCORE", 66, "Value destroyed, plus 100 a FOB taken, 50 a town, 15 a prisoner, 5 a man saved, 2 a structure built."],
		["kills", "KILLS", 54, "Enemy soldiers killed."],
		["lost", "LOSSES", 62, "Own soldiers killed or captured."],
		["kd", "K/D", 48, "Kills for every man lost."],
		["veh", "VEHICLES", 76, "Enemy vehicles destroyed / own vehicles lost."],
		["acc", "ACCURACY", 78, "Rounds that hit what they were aimed at."],
		["ex", "EXCHANGE", 80, "Supply value destroyed against supply value lost."],
		["spent", "SPENT", 64, "Supply spent."],
		["fielded", "FIELDED", 66, "Squads and vehicles trained or built."],
	]
	const DROP := ["fielded", "spent", "kd", "score", "ex"]  # what goes first when it's narrow
	const ROW_H := 54.0
	var _rows: Array = []  # [Rect2, commander id]
	var _n := 0  # rows drawn so far (their stagger)
	var _d0 := 0.0  # when the breakdown last changed commander (it comes in again from then)

	func _cols(w: float) -> Array:
		var cols := COLS.duplicate()
		var total := 0.0
		for col in cols:
			total += float(col[2])
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
		_rows.clear()
		_n = 0
		if not begin():
			return
		var w := size.x
		var cols := _cols(w)
		var name_w := w
		for col in cols:
			name_w -= float(col[2])
		ink = p.appear(0.0)
		columns("Commander", name_w, cols, ["rating"])
		settle()
		var y := 28.0
		var sds: Array = p.report.sides
		for t in p.sides_in_order():
			var pl := p.players_of(t)
			if pl.is_empty():
				continue
			y += 6.0
			slide(p.appear(0.03 + _n * 0.03), -UiMotion.TRAVEL_MD)
			side_label(4, y, t, result_tag(t))
			settle()
			y += 30.0
			for c2 in pl:
				y = _row(c2, sds[t], y, w, name_w, cols, false)
			if pl.size() > 1 and p.known(t):
				var tot: Dictionary = (sds[t] as Dictionary).duplicate()
				tot["name"] = "Side total"
				tot["id"] = 0
				tot["team"] = t
				y = _row(tot, sds[t], y, w, name_w, cols, true)
		y += 16.0
		y = _detail(y, w)
		settle()
		fit(y + 8.0)

	func _row(cm: Dictionary, side: Dictionary, y: float, w: float, name_w: float, cols: Array, total: bool) -> float:
		var id := int(cm.get("id", 0))
		var d := 0.06 + mini(_n, 10) * 0.03
		_n += 1
		var a := p.appear(d)
		slide(a, UiMotion.TRAVEL_MD)
		var r := Rect2(0, y, w, ROW_H - 6.0)
		var me := id == p.me_id
		var key := "c%d_%d" % [id, int(cm.get("team", 0))]
		if not total:
			# the one whose breakdown is open: washed with the accent behind a 2 px edge
			var on := id == p.pick
			if on:
				rect(r, UiKit.fa(UiKit.ACCENT, 0.08))
				rect(Rect2(0, y, 2, r.size.y), UiKit.ACCENT)
			elif hot(r):
				rect(r, UiKit.fa(UiKit.TEXT, 0.05))
			rule_under(0, r.end.y, w)
			_rows.append([r, id])
			mark(14, y + 12, int(cm.team))
			cap(30, y + 21, String(cm.name), 15, UiKit.ACCENT if me else UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, name_w - 38.0)
			fig(30, y + 38, p.who_tag(cm).to_upper(), 10, UiKit.FAINT, HORIZONTAL_ALIGNMENT_LEFT, name_w - 38.0)
			tip(Rect2(0, y, name_w, ROW_H), "Click for the breakdown.")
		else:
			cap(30, y + 28, "Side total", 10, UiKit.FAINT)
			rule_under(0, r.end.y, w)
		var x := name_w
		var cy := y + 30.0
		for col in cols:
			var cw := float(col[2])
			var ck: String = col[0]
			var s := ""
			match ck:
				"rating":
					if not total:
						var rv := BattleStats.rating(cm, side)
						var shown := p.num(key + "r", rv, d + 0.1, 1.1)
						var rc := UiKit.rating_col(shown)
						UiFx.ring(self, Vector2(x + 14, cy - 5), 12.0, 2.0, shown / 100.0, rc, ink)
						big(x + 34, cy + 1, "%d" % int(round(shown)), 19, rc)
						cap(x + 62, cy - 1, UiKit.rating_word(rv), 10, UiKit.FAINT, HORIZONTAL_ALIGNMENT_LEFT, cw - 64.0, 1)
					x += cw
					continue
				"score":
					s = UiKit.fmt_num(p.num(key + "s", float(BattleStats.score(cm)), d + 0.1))
				"kills":
					s = UiKit.fmt_num(p.num(key + "k", float(cm.kills), d + 0.1))
				"lost":
					s = UiKit.fmt_num(p.num(key + "l", float(cm.lost) + float(cm.captured), d + 0.1))
				"kd":
					s = StatsPanel.kd(cm)
				"veh":
					s = "%d / %d" % [int(cm.veh_kills), int(cm.veh_lost)]
				"acc":
					var ac := StatsPanel.accuracy(cm)
					s = ("%d%%" % int(round(p.num(key + "a", ac * 100.0, d + 0.1)))) if ac >= 0.0 else "-"
				"ex":
					s = StatsPanel.exchange(cm)
				"spent":
					s = UiKit.fmt_num(p.num(key + "p", float(cm.spent), d + 0.1))
				"fielded":
					s = UiKit.fmt_num(float(cm.squads) + float(cm.vehicles))
			if total:
				fig(x, cy, s, 13, UiKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT, cw - 10.0)
			else:
				fig(x, cy, s, 15, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, cw - 10.0)
			x += cw
		settle()
		return y + ROW_H

	## The picked commander: their rating taken apart, and everything they did.
	func _detail(y0: float, w: float) -> float:
		var cm: Dictionary = {}
		for pc in p.report.get("players", []):
			if int(pc.id) == p.pick:
				cm = pc
		if cm.is_empty():
			return y0
		var side: Dictionary = (p.report.sides as Array)[int(cm.team)]
		var d := maxf(0.12 + mini(_n, 10) * 0.03, _d0)
		var y := head(0, y0, "Breakdown  ·  " + String(cm.name), w, d)
		var a := p.appear(d + 0.03)
		slide(a, 0.0, UiMotion.TRAVEL_MD)
		# its region marked by corner ticks, on the sheet's own ink
		var box := Rect2(0, y, w, 214)
		UiKit.ticks(self, box.grow(-1.0), c(UiKit.RULE2), UiKit.TICK_ARM, 0.0)
		var key := "d%d" % int(cm.id)
		var rv := BattleStats.rating(cm, side)
		var shown := p.num(key + "r", rv, d + 0.15, 1.4)
		var rc := UiKit.rating_col(shown)
		# the rating on a dial
		var dc := Vector2(86, y + 100)
		UiFx.ring(self, dc, 54.0, 4.0, shown / 100.0, rc, ink)
		big(dc.x - 60, dc.y + 14, "%d" % int(round(shown)), 44, rc, HORIZONTAL_ALIGNMENT_CENTER, 120)
		cap(dc.x - 60, dc.y + 34, UiKit.rating_word(rv), 11, rc, HORIZONTAL_ALIGNMENT_CENTER, 120, 1)
		cap(dc.x - 60, y + 30, "Rating", 10, UiKit.FAINT, HORIZONTAL_ALIGNMENT_CENTER, 120, 1)
		var sc := UiKit.fmt_num(p.num(key + "s", float(BattleStats.score(cm)), d + 0.2))
		var scw := UiFx.width(UiKit.mono(400), sc, 13)
		var sw := UiFx.width(UiKit.cond(600, 1), "SCORE", 11) + 8.0 + scw
		cap(dc.x - sw * 0.5, y + 186, "Score", 11, UiKit.FAINT)
		fig(dc.x + sw * 0.5 - scw, y + 186, sc, 13, UiKit.TEXT)
		var tag := p.who_tag(cm)
		cap(dc.x - 70, y + 203, String(Defs.TEAM_NAMES[int(cm.team)]) + (("  ·  " + tag) if tag != "" else ""), 10, UiKit.FAINT, HORIZONTAL_ALIGNMENT_CENTER, 140, 1)
		# what the rating is made of
		var mx := 200.0
		var mw := clampf(w * 0.32, 230.0, 330.0)
		cap(mx, y + 30, "What the rating weighs", 11, UiKit.DIM)
		var vk := float(cm.val_killed)
		var vl := float(cm.val_lost)
		var sh := float(cm.shots)
		var sk := float(side.get("val_killed", 0.0))
		var rp := BattleStats.rating_parts(cm, side)
		var parts := [
			["Exchange", "60%", rp[0], "%s destroyed : %s lost  (%s)" % [UiKit.fmt_num(vk), UiKit.fmt_num(vl), StatsPanel.exchange(cm)]],
			["Marksmanship", "20%", rp[1], ("%s of %s rounds hit" % [StatsPanel.fmt_acc(cm), UiKit.fmt_num(sh)]) if sh > 0.0 else "No rounds fired"],
			["Share of the fight", "20%", rp[2], ("%d%% of all their side destroyed" % int(round(vk / sk * 100.0))) if sk > 0.0 else "Nothing destroyed on this side yet"],
		]
		var py := y + 56.0
		for i in parts.size():
			var pt: Array = parts[i]
			var pd := d + 0.15 + i * 0.08
			var fk := p.num(key + "p%d" % i, float(pt[2]), pd, 0.9)
			cap(mx, py, String(pt[0]), 12, UiKit.TEXT)
			fig(mx, py, String(pt[1]), 11, UiKit.FAINT, HORIZONTAL_ALIGNMENT_RIGHT, mw)
			UiFx.bar(self, Rect2(mx, py + 8, mw, 7), fk, UiKit.rating_col(float(pt[2]) * 100.0), ink)
			fig(mx, py + 30, String(pt[3]).to_upper(), 11, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, mw)
			py += 50.0
		# everything they did
		var gx := mx + mw + 36.0
		var gw := (w - gx - 16.0) / 3.0
		var groups := [
			["Combat", [["Killed", cm.kills], ["Wounded", cm.downs], ["Vehicles", cm.veh_kills], ["Buildings", cm.bld_kills], ["Prisoners", cm.prisoners], ["FOBs / towns", "%d / %d" % [int(cm.captures), int(cm.get("towns", 0))]]]],
			["Losses", [["Killed", cm.lost], ["Wounded", cm.wounded], ["Captured", cm.captured], ["Vehicles", cm.veh_lost], ["Buildings", cm.bld_lost], ["Saved", cm.revived]]],
			["Logistics", [["Spent", cm.spent], ["Squads", cm.squads], ["Vehicles", cm.vehicles], ["Research", cm.research], ["Built", cm.built], ["Fire missions", cm.support]]],
		]
		if gw >= 96.0:
			for gi in groups.size():
				var gxi := gx + gi * gw
				# a header: the group's name and a rule running on
				var gn := String(groups[gi][0])
				cap(gxi, y + 30, gn, 11, UiKit.DIM)
				var rx := gxi + UiFx.width(UiKit.cond(600, 1), gn.to_upper(), 11) + 8.0
				line(Vector2(rx, y + 26.5), Vector2(gxi + gw - 18.0, y + 26.5), UiKit.LINE)
				var ly := y + 58.0
				var rows: Array = groups[gi][1]
				for ri in rows.size():
					var kv: Array = rows[ri]
					var rd := d + 0.12 + gi * 0.04 + ri * 0.02
					ink = a * p.appear(rd)
					cap(gxi, ly, String(kv[0]), 11, UiKit.FAINT)
					var vs := String(kv[1]) if kv[1] is String else UiKit.fmt_num(p.num(key + "g%d%d" % [gi, ri], float(kv[1]), rd, 0.7))
					fig(gxi, ly, vs, 14, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, gw - 18.0)
					ly += 24.0
				ink = a
		settle()
		return y + box.size.y

	func _gui_input(ev: InputEvent) -> void:
		super(ev)
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			for r in _rows:
				if (r[0] as Rect2).has_point(ev.position) and p.pick != int(r[1]):
					p.pick = int(r[1])
					Sfx.ui("click", -10.0)
					Sfx.ui("ui_whoosh", -24.0, 1.5)
					# the breakdown comes in again for the new commander
					for k in p._vals.keys():
						if String(k).begins_with("d"):
							p._vals.erase(k)
					_d0 = p.page_t - 0.2
					p.moving = true
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
		["men", "STRENGTH", 96, "Men still standing, of the most it had."],
		["time", "IN ACTION", 80, "How long it has been in the field."],
		["status", "STATUS", 112, ""],
	]
	const MAX_ROWS := 60

	func _draw() -> void:
		if not begin():
			return
		var w := size.x
		var cols := COLS.duplicate()
		var fixed := 0.0
		for col in cols:
			fixed += float(col[2])
		if w - fixed < 200.0:
			cols.remove_at(0)  # no room for whose it is
			fixed -= 150.0
		var name_w := w - fixed
		ink = p.appear(0.0)
		columns("Unit", name_w, cols, ["owner"])
		settle()
		var y := 28.0
		var now := float(p.report.get("t", 0.0))
		var n := 0
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
			slide(p.appear(0.03 + mini(n, 12) * 0.02), -UiMotion.TRAVEL_MD)
			side_label(4, y, t, "%d FIELDED  ·  %d IN ACTION" % [us.size(), alive])
			settle()
			y += 30.0
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
				var d := 0.05 + mini(n, 12) * 0.02
				n += 1
				slide(p.appear(d), UiMotion.TRAVEL_MD)
				var r := Rect2(0, y, w, 38)
				if hot(r):
					rect(r, UiKit.fa(UiKit.TEXT, 0.05))
				rule_under(0, r.end.y, w)
				var veh := String(u.kind) == "vehicle"
				var mine := int(u.owner) == p.me_id or p.me_team < 0  # (an observer's are all his to look at)
				mark(8, y + 9, t)
				var nm := String(u.name) + ((" %d" % int(vno.get(String(u.key), 1))) if veh and int(seq.get(String(u.name), 0)) > 1 else "")
				# your own units in full strength, the others' (a co-commander's, the enemy's) a step down
				cap(24, y + 17, nm, 14, UiKit.TEXT if mine else UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, name_w - 28.0)
				cap(24, y + 31, "Vehicle" if veh else String(u.kind), 10, UiKit.FAINT, HORIZONTAL_ALIGNMENT_LEFT, name_w - 28.0)
				var gone := float(u.t1) >= 0.0
				var x := name_w
				for col in cols:
					var cw := float(col[2])
					var ck: String = col[0]
					var s := ""
					match ck:
						"owner":
							cap(x, y + 24, String(p.names.get(int(u.owner), "-")), 12, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, cw - 8.0)
						"kills", "downs", "veh", "lost":
							var field := "veh_kills" if ck == "veh" else ck
							var v := float(u.get(field, 0))
							s = UiKit.fmt_num(p.num("u%s%s" % [String(u.key), ck], v, d + 0.05, 0.7))
							fig(x, y + 24, s, 15, UiKit.TEXT if v > 0.0 else UiKit.FAINT, HORIZONTAL_ALIGNMENT_RIGHT, cw - 10.0)
						"men":
							if veh:
								fig(x, y + 24, "-", 13, UiKit.FAINT, HORIZONTAL_ALIGNMENT_RIGHT, cw - 10.0)
							else:
								# a pip a man, lit while he stands
								var most := maxi(int(u.men), int(u.alive))
								var pw := most * 5.0 - 2.0
								UiKit.pips(self, Vector2(x + cw - 10.0 - pw, y + 14), int(u.alive), 0, most - int(u.alive), 11.0, ink)
						"time":
							fig(x, y + 24, UiKit.fmt_time((float(u.t1) if gone else now) - float(u.t0)), 13, UiKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT, cw - 10.0)
						"status":
							# a state, as a code in its colour
							var st := ("Destroyed" if veh else "Wiped out") if gone else "In field"
							fig(x, y + 24, st.to_upper(), 12, UiKit.BAD if gone else UiKit.GOOD, HORIZONTAL_ALIGNMENT_RIGHT, cw - 10.0)
					x += cw
				settle()
				y += 40.0
			if us.size() > MAX_ROWS:
				fig(24, y + 16, "+%d MORE" % (us.size() - MAX_ROWS), 12, UiKit.FAINT)
				y += 26.0
		fit(y + 8.0)


# --- Timeline: the battle over time ------------------------------------------------------------------

class _Timeline extends _Page:
	## [title, column of side 0, column of side 1]
	const CHARTS := [["Men in the field", 1, 2], ["Vehicles", 3, 4], ["Enemy killed (running total)", 5, 6], ["Supply in hand", 7, 8]]

	func _draw() -> void:
		if not begin():
			return
		var tl: Array = p.report.get("tl", [])
		if tl.size() < 2:
			ink = p.appear(0.0)
			cap(0, 64, "The timeline fills in as the battle goes on", 12, UiKit.FAINT, HORIZONTAL_ALIGNMENT_CENTER, size.x, 2)
			settle()
			return
		var t1 := float(tl.back()[0])
		var t0 := float(tl[0][0])
		var gap := 22.0
		var lane := 66.0
		var cw := (size.x - gap) * 0.5
		var ch := (size.y - lane - gap - 10.0) * 0.5
		var rects := []
		for ci in CHARTS.size():
			rects.append(Rect2(floorf((ci % 2) * (cw + gap)), floorf(4.0 + (ci / 2) * (ch + gap)), floorf(cw), floorf(ch)))
		var strip := Rect2(0, ch * 2.0 + gap + 10.0, size.x, lane)
		# the moment under the mouse, in whichever chart (or the events strip) it's over
		var hover_t := -1.0
		if mouse.x >= 0.0:
			for r in rects + [strip]:
				var pl := _plot_x(r)
				if (r as Rect2).has_point(mouse) and mouse.x >= pl.x and mouse.x <= pl.y:
					hover_t = lerpf(t0, t1, (mouse.x - pl.x) / (pl.y - pl.x))
		for ci in CHARTS.size():
			_chart(rects[ci], CHARTS[ci], tl, t0, t1, hover_t, 0.05 + ci * 0.1)
		_events(strip, t0, t1, hover_t)
		settle()

	## Where a chart's (or the strip's) time axis starts and ends.
	func _plot_x(r: Rect2) -> Vector2:
		return Vector2(r.position.x + 48.0, r.end.x - 12.0)

	## How far along the battle the lines have drawn themselves.
	func _drawn(delay: float) -> float:
		if UiMotion.reduced():
			return 1.0
		var k := UiFx.span(p.page_t, delay + 0.1, 1.0)
		if k < 1.0:
			p.moving = true
		return UiFx.in_out(k)

	func _chart(r: Rect2, spec: Array, tl: Array, t0: float, t1: float, hover_t: float, delay: float) -> void:
		var a := p.appear(delay)
		slide(a, 0.0, UiMotion.TRAVEL_SM)
		# the chart's region: corner ticks on the sheet's ink, no box
		UiKit.ticks(self, r.grow(-1.0), c(UiKit.RULE2), UiKit.TICK_ARM, 0.0)
		cap(r.position.x + 16, r.position.y + 24, String(spec[0]), 11, UiKit.DIM)
		var plot := Rect2(r.position.x + 48, r.position.y + 38, r.size.x - 60, r.size.y - 64)
		var vmax := 1.0
		for row in tl:
			for col in [int(spec[1]), int(spec[2])]:
				vmax = maxf(vmax, float(row[col]))
		# grid lines on whole, round numbers (these are counts of men and crates)
		var step := _step(vmax / 4.0)
		var lines_n := int(ceilf(vmax / step - 0.001))
		vmax = step * lines_n
		for g in lines_n + 1:
			var gy := floorf(plot.end.y - plot.size.y * g / float(lines_n)) + 0.5
			line(Vector2(plot.position.x, gy), Vector2(plot.position.x + plot.size.x * a, gy), UiFx.fade(UiKit.LINE, 0.45) if g > 0 else UiKit.LINE)
			fig(r.position.x + 4, gy + 4, UiKit.fmt_num(step * g), 10, UiKit.FAINT, HORIZONTAL_ALIGNMENT_RIGHT, 38)
		for g in 5:
			var gx := lerpf(plot.position.x, plot.end.x, g / 4.0)
			fig(gx - 30, plot.end.y + 17, UiKit.fmt_time(lerpf(t0, t1, g / 4.0)), 10, UiKit.FAINT, HORIZONTAL_ALIGNMENT_CENTER, 60)
		var span := maxf(1.0, t1 - t0)
		var drawn := _drawn(delay)
		var t_cut := lerpf(t0, t1, drawn)
		# each side's line, thin, in its colour (your own side drawn last, on top)
		var order := p.sides_in_order()
		for kk in [1, 0]:
			var t: int = order[kk]
			var col := int(spec[1 + t])
			var pts := PackedVector2Array()
			var prev: Array = []
			for row in tl:
				var v := float(row[col])
				if v < 0.0:
					continue
				var rt := float(row[0])
				if rt > t_cut:
					# the line's head, partway to the next sample
					if not prev.is_empty() and rt > float(prev[0]):
						var f := (t_cut - float(prev[0])) / (rt - float(prev[0]))
						var hv := lerpf(float(prev[col]), v, f)
						pts.append(Vector2(plot.position.x + plot.size.x * (t_cut - t0) / span, plot.end.y - plot.size.y * hv / vmax))
					break
				pts.append(Vector2(plot.position.x + plot.size.x * (rt - t0) / span, plot.end.y - plot.size.y * v / vmax))
				prev = row
			if pts.size() < 2:
				continue
			var sc := StatsPanel.side_col(t)
			draw_polyline(pts, c(sc), 1.5, true)
			if drawn < 1.0:
				# the line's head as it draws: a small square
				var hp := pts[pts.size() - 1]
				rect(Rect2(hp - Vector2(2.5, 2.5), Vector2(5, 5)), sc)
		# legend: each side's square and name
		var lx := r.end.x - 14.0
		for t in [order[1], order[0]]:
			var nm := String(Defs.TEAM_NAMES[t]).to_upper()
			var known: bool = float(tl.back()[int(spec[1 + t])]) >= 0.0
			if not known:
				nm += "  (CLASSIFIED)"
			var f2 := UiKit.cond(600, 1)
			var tw := UiFx.width(f2, nm, 10)
			lx -= tw
			draw_string(f2, Vector2(lx, r.position.y + 24), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c(UiKit.DIM if known else UiKit.FAINT))
			mark(lx - 13, r.position.y + 16, t, 7.0)
			lx -= 30.0
		# the cursor: both sides' figures at that moment
		if hover_t >= 0.0 and drawn >= 1.0:
			var hx := floorf(plot.position.x + plot.size.x * (hover_t - t0) / span) + 0.5
			line(Vector2(hx, plot.position.y), Vector2(hx, plot.end.y), UiKit.RULE2)
			var row2 := _at(tl, hover_t)
			var ty := plot.position.y + 4.0
			var lines := []
			for t in order:
				var v2 := float(row2[int(spec[1 + t])])
				if v2 >= 0.0:
					lines.append([t, UiKit.fmt_num(v2)])
					var py := plot.end.y - plot.size.y * v2 / vmax
					rect(Rect2(hx - 3.0, py - 3.0, 6, 6), StatsPanel.side_col(t))
			# the readout: on ink, its corners ticked
			var bw := 96.0
			var bx := hx + 10.0 if hx + 10.0 + bw < plot.end.x else hx - 10.0 - bw
			var bh := 22.0 + 17.0 * lines.size()
			var br := Rect2(floorf(bx), floorf(ty), bw, bh)
			rect(br, UiKit.PANEL)
			UiKit.ticks(self, br, c(UiKit.RULE2), 5.0, 0.0)
			fig(br.position.x + 9, ty + 15, UiKit.fmt_time(hover_t), 11, UiKit.FAINT)
			for li in lines.size():
				var tt: int = lines[li][0]
				mark(br.position.x + 9, ty + 24 + li * 17, tt, 6.0)
				fig(br.position.x + 21, ty + 32 + li * 17, String(lines[li][1]), 13, UiKit.TEXT)
		settle()

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

	## FOBs and towns, vehicles lost and fire missions along the bottom, each
	## cutting in as the lines reach it; hover one to read it.
	func _events(r: Rect2, t0: float, t1: float, hover_t: float) -> void:
		var ev: Array = p.report.get("ev", [])
		var a := p.appear(0.15)
		ink = a
		cap(r.position.x + 16, r.position.y + 14, "Events", 11, UiKit.DIM)
		var px := _plot_x(r)
		var x0 := px.x
		var x1 := px.y
		var plot_w := x1 - x0
		var span := maxf(1.0, t1 - t0)
		var ly := floorf(r.position.y + 34.0) + 0.5
		line(Vector2(x0, ly), Vector2(x0 + (x1 - x0) * a, ly), UiKit.LINE)
		var reach := lerpf(t0, t1, _drawn(0.05))
		var near := []
		var best_d := 1e9
		for e in ev:
			var et := float(e[0])
			if et > reach:
				continue
			var ex := x0 + plot_w * (et - t0) / span
			var t := int(e[1])
			var col := StatsPanel.side_col(t)
			var kind := String(e[2])
			var cy := ly + (-8.0 if kind == "fob" or kind == "town" else (8.0 if kind == "sup" else 0.0))
			var sz := 5.0
			match kind:
				"fob", "town":
					draw_colored_polygon(PackedVector2Array([Vector2(ex, cy - sz), Vector2(ex + sz, cy), Vector2(ex, cy + sz), Vector2(ex - sz, cy)]), c(col))
				"sup":
					draw_colored_polygon(PackedVector2Array([Vector2(ex, cy - sz * 0.9), Vector2(ex + sz * 0.9, cy + sz * 0.7), Vector2(ex - sz * 0.9, cy + sz * 0.7)]), c(col))
				_:
					rect(Rect2(ex - sz * 0.6, cy - sz * 0.6, sz * 1.2, sz * 1.2), col)
			tip(Rect2(ex - 7, cy - 8, 14, 16), "%s  %s" % [UiKit.fmt_time(et), String(e[3])])
			var dd := absf(mouse.x - ex) + absf(mouse.y - cy) * 0.5
			if mouse.x >= 0.0 and dd < best_d and dd < 24.0:
				best_d = dd
				near = e
		if not near.is_empty():
			fig(x0, ly + 28, UiKit.fmt_time(float(near[0])), 12, UiKit.ACCENT)
			txt(x0 + 46, ly + 28, String(near[3]), 13, UiKit.TEXT)
		elif ev.is_empty():
			cap(x0, ly + 27, "Nothing of note yet", 10, UiKit.FAINT)
		else:
			# the key to the marks
			var kx := x0 + 6.0
			var ky := ly + 22.0
			var kc := UiKit.DIM
			var kf := UiKit.cond(600, 1)
			draw_colored_polygon(PackedVector2Array([Vector2(kx, ky - 5), Vector2(kx + 5, ky), Vector2(kx, ky + 5), Vector2(kx - 5, ky)]), c(kc))
			cap(kx + 11, ky + 4, "FOBs and towns", 10, UiKit.FAINT)
			kx += 30.0 + UiFx.width(kf, "FOBS AND TOWNS", 10)
			rect(Rect2(kx - 3, ky - 3, 6, 6), kc)
			cap(kx + 11, ky + 4, "Vehicles lost", 10, UiKit.FAINT)
			kx += 30.0 + UiFx.width(kf, "VEHICLES LOST", 10)
			draw_colored_polygon(PackedVector2Array([Vector2(kx, ky - 4), Vector2(kx + 4, ky + 3), Vector2(kx - 4, ky + 3)]), c(kc))
			cap(kx + 11, ky + 4, "Fire missions", 10, UiKit.FAINT)
			kx += 30.0 + UiFx.width(kf, "FIRE MISSIONS", 10)
			txt(kx, ky + 4, "(hover one to read it)", 11, UiKit.FAINT)
		if hover_t >= 0.0:
			var hx := floorf(x0 + plot_w * (hover_t - t0) / span) + 0.5
			line(Vector2(hx, ly - 12), Vector2(hx, ly + 12), UiKit.RULE2)
		settle()
