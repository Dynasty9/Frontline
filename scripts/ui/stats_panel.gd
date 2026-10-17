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
## It moves like a debrief should: each tab comes in row by row, numbers count
## up with a tick, bars and dials fill, honours land one at a time with a glint,
## and the timeline's lines draw themselves across. All drawn; all real time,
## so a paused or fast-forwarded battle doesn't change how it feels.

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
var _shown_ms := 0  # when the panel itself last appeared
var _tw: Tween
var _title: Label
var _sub: Label
var _close: Button
var _hint: Label
var _bar: _TabBar
var _pages := {}


func _ready() -> void:
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
		tv.add_theme_constant_override("separation", 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(tv)
		_title = Label.new()
		_title.text = title
		_title.add_theme_font_override("font", UiFx.spaced(700, 4))
		_title.add_theme_font_size_override("font_size", 24)
		_title.add_theme_color_override("font_color", UiKit.TEXT)
		tv.add_child(_title)
		_sub = UiKit.label("", 13, UiKit.DIM)
		tv.add_child(_sub)
		_hint = Label.new()
		_hint.text = "RELEASE TAB TO RETURN"
		_hint.add_theme_font_override("font", UiFx.spaced(700, 2))
		_hint.add_theme_font_size_override("font_size", 11)
		_hint.add_theme_color_override("font_color", UiKit.DIM)
		_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(_hint)
		_close = Button.new()
		_close.text = "CLOSE   ESC"
		_close.focus_mode = Control.FOCUS_NONE
		_close.custom_minimum_size = Vector2(124, 34)
		_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_close.add_theme_font_override("font", UiFx.spaced(700, 2))
		_close.add_theme_font_size_override("font_size", 12)
		_close.add_theme_stylebox_override("normal", UiKit.box(Color(1, 1, 1, 0.02), 2, Color(1, 1, 1, 0.16), 1, 8.0))
		_close.add_theme_stylebox_override("hover", UiKit.box(UiFx.fade(UiKit.ACCENT, 0.16), 2, UiKit.ACCENT, 1, 8.0))
		_close.add_theme_stylebox_override("pressed", UiKit.box(UiFx.fade(UiKit.ACCENT, 0.3), 2, UiKit.ACCENT, 1, 8.0))
		_close.pressed.connect(func(): Sfx.ui("click"); closed.emit())
		top.add_child(_close)
	_bar = _TabBar.new()
	_bar.p = self
	_bar.custom_minimum_size = Vector2(0, 44)
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
		_shown_ms = Time.get_ticks_msec()
		_last_ms = _shown_ms
		reveal()
		queue_redraw()


## In fast (a peek, Tab held): a quick fade and settle, no fuss.
func pop_in() -> void:
	if _tw:
		_tw.kill()
	visible = true
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.975, 0.975)
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.set_ignore_time_scale(true)
	_tw.tween_property(self, "modulate:a", 1.0, 0.14)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.18)


func pop_out() -> void:
	if not visible:
		return
	if _tw:
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.set_ignore_time_scale(true)
	_tw.tween_property(self, "modulate:a", 0.0, 0.09)
	_tw.tween_callback(func(): visible = false; modulate.a = 1.0)


func _process(_d: float) -> void:
	var now := Time.get_ticks_msec()
	dt = clampf((now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now
	if not is_visible_in_tree():
		return
	page_t += dt * (1.6 if peek else 1.0)
	if moving and _pages.has(tab):
		(_pages[tab] as Control).queue_redraw()
	if _bar.moving:
		_bar.queue_redraw()
	if now - _shown_ms < 800:
		queue_redraw()


## The frame: glass with its brackets, and an accent strip that runs out
## along the top as the panel opens.
func _draw() -> void:
	if embedded:
		return
	var k := UiFx.out_cubic((Time.get_ticks_msec() - _shown_ms) / 500.0)
	UiFx.panel(self, Rect2(Vector2.ZERO, size), 1.0, 18.0)
	var w := (size.x * 0.34) * k
	draw_rect(Rect2(24.0, 0.0, w, 2.0), UiKit.ACCENT)
	draw_rect(Rect2(24.0, 2.0, w, 10.0), UiFx.fade(UiKit.ACCENT, 0.06))
	draw_rect(Rect2(24.0 + w, 0.0, 3.0, 2.0), Color(1, 1, 1, 0.9 * (1.0 - k)))


# --- motion -----------------------------------------------------------------------------------

## How far in something is that starts `delay` seconds into the reveal (0-1, eased).
func appear(delay: float, dur := 0.35) -> float:
	var k := UiFx.span(page_t, delay, dur)
	if k < 1.0:
		moving = true
	return UiFx.out_cubic(k)


## A number counting up to `target` (from 0 when it first shows, from where it
## was when the figure changes), with a tick while it runs.
func num(key: String, target: float, delay := 0.0, dur := 0.9) -> float:
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
			_sub.text = "%s into the battle  ·  %s" % [UiKit.fmt_time(float(r.get("t", 0.0))), whose]
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
		bits.append("Left the battle")
	return "  ·  ".join(bits)


# --- the tab bar --------------------------------------------------------------------------------

## The tabs as spaced capitals with an accent underline that slides to the one
## that's open; the classified note sits on the right.
class _TabBar extends Control:
	const FS := 15
	var p: StatsPanel
	var note := ""
	var moving := false
	var _x := -1.0
	var _w := 0.0
	var _hover := -1
	var _rects: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_exited.connect(func(): _hover = -1; queue_redraw())

	func _draw() -> void:
		_rects.clear()
		var f := UiFx.spaced(700, 3)
		var base := size.y - 15.0
		var x := 2.0
		var tx := 0.0
		var tw := 0.0
		for i in StatsPanel.TABS.size():
			var lab := String(StatsPanel.TABS[i][1]).to_upper()
			var w := UiFx.width(f, lab, FS)
			_rects.append(Rect2(x - 12.0, 0.0, w + 24.0, size.y))
			var on: bool = StatsPanel.TABS[i][0] == p.tab
			var col := UiKit.TEXT if on else (Color(0.86, 0.87, 0.83) if i == _hover else UiKit.DIM)
			if i == _hover and not on:
				draw_rect(Rect2(x - 12.0, 4.0, w + 24.0, size.y - 8.0), Color(1, 1, 1, 0.035))
			draw_string(f, Vector2(x, base), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, col)
			if on:
				tx = x
				tw = w
			x += w + 38.0
		draw_line(Vector2(0, size.y - 1.0), Vector2(size.x, size.y - 1.0), Color(1, 1, 1, 0.08), 1.0)
		if _x < 0.0:
			_x = tx
			_w = tw
		var k := 1.0 - exp(-p.dt * 16.0)
		_x = lerpf(_x, tx, k)
		_w = lerpf(_w, tw, k)
		moving = absf(_x - tx) > 0.4 or absf(_w - tw) > 0.4
		if not moving:
			_x = tx
			_w = tw
		draw_rect(Rect2(_x - 4.0, size.y - 12.0, _w + 8.0, 11.0), UiFx.fade(UiKit.ACCENT, 0.07))
		draw_rect(Rect2(_x, size.y - 4.0, _w, 3.0), UiKit.ACCENT)
		if note != "":
			draw_string(UiFx.spaced(600, 1), Vector2(0, base), note.to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4.0, 11, UiKit.DIM)

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

	func txt(x: float, y: float, s: String, fs := 13, col := UiKit.TEXT, wt := 400, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
		draw_string(UiKit.font(wt), Vector2(x, y), s, align, w, fs, c(col))

	## Spaced capitals: headings, labels, tags.
	func cap(x: float, y: float, s: String, fs := 11, col := UiKit.DIM, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, sp := 2) -> void:
		draw_string(UiFx.spaced(700, sp), Vector2(x, y), s.to_upper(), align, w, fs, c(col))

	## The figures, in the scoreboard face.
	func big(x: float, y: float, s: String, fs := 20, col := UiKit.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
		draw_string(UiFx.digits(700), Vector2(x, y), s, align, w, fs, c(col))

	## Everything drawn next fades by `a` and slides in from (dx, dy).
	func slide(a: float, dx := 26.0, dy := 0.0) -> void:
		ink = a
		draw_set_transform(Vector2((1.0 - a) * dx, (1.0 - a) * dy))

	## ...or grows into place round `centre`.
	func zoom(centre: Vector2, s: float, a: float) -> void:
		ink = a
		draw_set_transform_matrix(Transform2D(0.0, Vector2(s, s), 0.0, centre * (1.0 - s)))

	func settle() -> void:
		ink = 1.0
		draw_set_transform(Vector2.ZERO)

	func waiting() -> bool:
		if not p.report.is_empty():
			return false
		var dots := ".".repeat(int(Time.get_ticks_msec() / 350) % 4)
		cap(0, 64, "Gathering reports from the field" + dots, 13, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER, size.x, 3)
		p.moving = true
		fit(120)
		return true

	## A section heading with a rule that wipes out after it.
	func head(x: float, y: float, s: String, w := 0.0, delay := 0.0) -> float:
		var a := p.appear(delay, 0.5)
		var f := UiFx.spaced(700, 3)
		var tw := UiFx.width(f, s.to_upper(), 12)
		ink = a
		cap(x, y + 13, s, 12, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3)
		if w > 0.0:
			var x0 := x + tw + 12.0
			line(Vector2(x0, y + 8), Vector2(x0 + (x + w - x0) * a, y + 8), Color(1, 1, 1, 0.1))
		ink = 1.0
		return y + 26.0

	## A side's name on a coloured slab, and how it ended for them.
	func side_label(x: float, y: float, t: int, extra := "", right := false, w := 0.0) -> void:
		var col := StatsPanel.side_col(t)
		var nm := String(Defs.TEAM_NAMES[t]).to_upper()
		var f := UiFx.spaced(700, 3)
		var nw := UiFx.width(f, nm, 16)
		if not right:
			rect(Rect2(x, y, 5, 20), col)
			rect(Rect2(x + 5, y, nw + 22, 20), UiFx.fade(col, 0.14))
			draw_string(f, Vector2(x + 14, y + 16), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c(col.lightened(0.4)))
			if extra != "":
				stamp(x + nw + 36.0, y + 2.0, extra, false)
		else:
			var rx := x + w
			rect(Rect2(rx - 5, y, 5, 20), col)
			rect(Rect2(rx - 27 - nw, y, nw + 22, 20), UiFx.fade(col, 0.14))
			draw_string(f, Vector2(rx - 16 - nw, y + 16), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c(col.lightened(0.4)))
			if extra != "":
				stamp(rx - nw - 36.0, y + 2.0, extra, true)

	## A boxed tag: VICTORIOUS, DEFEATED, or a count.
	func stamp(x: float, y: float, s: String, right: bool) -> void:
		var f := UiFx.spaced(700, 2)
		var w := UiFx.width(f, s, 10) + 14.0
		var col := UiKit.GOOD if s == "VICTORIOUS" else (UiKit.BAD if s == "DEFEATED" else UiKit.DIM)
		var r := Rect2(x - (w if right else 0.0), y, w, 16)
		draw_rect(r, c(UiFx.fade(col, 0.1)))
		draw_rect(r, c(UiFx.fade(col, 0.7)), false, 1.0)
		draw_string(f, Vector2(r.position.x + 7, y + 12), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c(col))

	func result_tag(t: int) -> String:
		if not bool(p.report.get("over", false)):
			return ""
		return "VICTORIOUS" if int(p.report.get("winner", -1)) == t else "DEFEATED"

	## A table's column headings.
	func columns(first: String, name_w: float, cols: Array, left_keys: Array) -> void:
		cap(10, 14, first, 10, UiKit.DIM)
		var x := name_w
		for col in cols:
			var key: String = col[0]
			cap(x, 14, String(col[1]), 10, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT if key in left_keys else HORIZONTAL_ALIGNMENT_RIGHT, float(col[2]) - 8.0, 1)
			if col.size() > 3 and String(col[3]) != "":
				tip(Rect2(x, 0, float(col[2]), 20), String(col[3]))
			x += float(col[2])
		line(Vector2(0, 22), Vector2(size.x, 22), Color(1, 1, 1, 0.07))


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
		if two:
			y2 = _right(lw + 36.0, 0.0, w - lw - 36.0)
		else:
			y2 = _right(0.0, y1 + 22.0, w)
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
		var ha := p.appear(0.0, 0.45)
		slide(ha, -30.0)
		side_label(x0, 0.0, a, result_tag(a))
		slide(ha, 30.0)
		side_label(x0, 0.0, b, result_tag(b), true, w)
		settle()
		var y := 36.0
		var ca := StatsPanel.side_col(a)
		var cb := StatsPanel.side_col(b)
		for i in ROWS.size():
			var row: Array = ROWS[i]
			var key: String = row[0]
			var d := 0.12 + i * 0.035
			var ra := p.appear(d, 0.4)
			slide(ra, 0.0, 10.0)
			var tva := _val(sa, key)
			var tvb := _val(sb, key) if kb else 0.0
			var va := p.num("a:" + key, tva, d, 0.9)
			var vb := p.num("b:" + key, tvb, d, 0.9) if kb else 0.0
			var better: int = row[2]
			var col_a := UiKit.TEXT
			var col_b := UiKit.TEXT if kb else UiKit.DIM
			var a_wins := false
			var b_wins := false
			if kb and better != 0 and tva != tvb:
				a_wins = (tva > tvb) == (better > 0)
				b_wins = not a_wins
				col_a = UiKit.TEXT if a_wins else UiKit.DIM
				col_b = UiKit.DIM if a_wins else UiKit.TEXT
			var r := Rect2(x0, y, w, ROW_H - 4.0)
			if hot(r):
				rect(r.grow_individual(6, 0, 6, 0), Color(1, 1, 1, 0.035))
			big(x0, y + 18, _fmt(sa, key, va), 20, col_a)
			cap(x0, y + 15, String(row[1]), 10, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER, w, 2)
			big(x0, y + 18, _fmt(sb, key, vb) if kb else "-", 20, col_b, HORIZONTAL_ALIGNMENT_RIGHT, w)
			# the split: it opens out from the middle and settles where the
			# two sides' shares fall
			var by := y + 25.0
			rect(Rect2(x0, by, w, 5), Color(1, 1, 1, 0.05))
			if kb and tva + tvb > 0.0:
				var kk := p.appear(d + 0.1, 0.8)
				var f := lerpf(0.5, tva / (tva + tvb), kk)
				var split := x0 + w * f
				var la := (split - x0) * kk
				var lb := (x0 + w - split) * kk
				if la > 1.0:
					rect(Rect2(split - la, by, la - 1.0, 5), UiFx.fade(ca, 0.95 if a_wins else 0.6))
					rect(Rect2(split - la, by, la - 1.0, 2), Color(1, 1, 1, 0.12))
				if lb > 1.0:
					rect(Rect2(split + 1.0, by, lb - 1.0, 5), UiFx.fade(cb, 0.95 if b_wins else 0.6))
					rect(Rect2(split + 1.0, by, lb - 1.0, 2), Color(1, 1, 1, 0.12))
				if kk < 1.0:
					rect(Rect2(split - la - 2.0, by - 2.0, 3.0, 9.0), Color(1, 1, 1, 0.7 * (1.0 - kk)))
					rect(Rect2(split + lb - 1.0, by - 2.0, 3.0, 9.0), Color(1, 1, 1, 0.7 * (1.0 - kk)))
				var wx := (split - la) if a_wins else (split + lb - 6.0)
				if a_wins or b_wins:
					rect(Rect2(wx, by - 3.0, 6.0, 11.0), UiFx.fade((ca if a_wins else cb).lightened(0.5), 0.5 * kk))
			elif tva > 0.0:
				var ko := p.appear(d + 0.1, 0.8)
				rect(Rect2(x0, by, w * 0.5 * ko, 5), UiFx.fade(ca, 0.45))
			tip(Rect2(x0, y, w, ROW_H - 4.0), String(row[3]))
			settle()
			y += ROW_H
		return y

	func _right(x0: float, y0: float, w: float) -> float:
		var y := head(x0, y0, "Honours", w, 0.2)
		var hs := _honours()
		if hs.is_empty():
			ink = p.appear(0.3)
			txt(x0, y + 14, "Nobody has distinguished themselves yet.", 13, UiKit.DIM)
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
			var d := 0.35 + i * 0.16
			var a := p.appear(d, 0.42)
			if a <= 0.0:
				continue
			if a > 0.02:
				p.cue("medal%d" % i, "ui_medal", -15.0 if mvp else -19.0, 1.0 + i * 0.05)
			var lift := 1.0 if hot(r) else 0.0
			if a >= 1.0 and lift > 0.0:
				ink = 1.0
				draw_set_transform(Vector2(0, -2))  # landed: it lifts under the mouse
			else:
				zoom(r.get_center(), lerpf(0.82, 1.0, UiFx.out_back(UiFx.span(p.page_t, d, 0.42))), a)
			var tc := StatsPanel.side_col(int(who.team))
			UiFx.card(self, r, ink, lift, UiFx.fade(UiKit.ACCENT, 0.45) if mvp else Color(1, 1, 1, 0.08))
			if mvp:
				# the MVP's card burns gold down its left edge
				var g := PackedVector2Array([r.position + Vector2(0, 8), r.position + Vector2(140, 0), r.position + Vector2(140, r.size.y), Vector2(r.position.x, r.end.y)])
				draw_polygon(g, PackedColorArray([c(UiFx.fade(UiKit.ACCENT, 0.2)), c(UiFx.fade(UiKit.ACCENT, 0.0)), c(UiFx.fade(UiKit.ACCENT, 0.0)), c(UiFx.fade(UiKit.ACCENT, 0.2))]))
			rect(Rect2(r.position.x, r.position.y + 10, 3, r.size.y - 20), tc)
			var ic := r.position + Vector2(38.0 if mvp else 30.0, r.size.y * 0.5)
			UiFx.insignia(self, String(KINDS.get(String(h[0]), "star")), ic, 26.0 if mvp else 19.0, UiKit.ACCENT if mvp else tc.lightened(0.15), ink)
			var tx := r.position.x + (78.0 if mvp else 60.0)
			var tw2 := r.size.x - (tx - r.position.x) - 10.0
			cap(tx, r.position.y + (24.0 if mvp else 20.0), String(h[0]), 11 if mvp else 10, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, tw2, 3)
			txt(tx, r.position.y + (50.0 if mvp else 39.0), String(who.name), 21 if mvp else 15, UiKit.TEXT, 700, HORIZONTAL_ALIGNMENT_LEFT, tw2)
			txt(tx, r.position.y + (70.0 if mvp else 55.0), String(h[2]), 13 if mvp else 12, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_LEFT, tw2)
			UiFx.shine(self, r, UiFx.span(p.page_t, d + 0.2, 0.75), ink)
			if UiFx.span(p.page_t, d + 0.2, 0.75) < 1.0:
				p.moving = true
			settle()
			tip(r, String(h[3]))
		if not hs.is_empty():
			y += 96.0 + ceilf((hs.size() - 1) / 2.0) * 72.0 + 6.0
		y = head(x0, y, "Distinguished soldiers", w, 0.6)
		var he: Array = (p.report.get("heroes", []) as Array).duplicate()
		he.sort_custom(func(a, b): return int(a.kills) + int(a.veh) * 3 > int(b.kills) + int(b.veh) * 3)
		if he.is_empty():
			ink = p.appear(0.7)
			txt(x0, y + 14, "No kills recorded yet.", 13, UiKit.DIM)
			settle()
			return y + 28.0
		for i in mini(he.size(), 8):
			var h2: Dictionary = he[i]
			var ra := p.appear(0.75 + i * 0.06, 0.4)
			slide(ra, 34.0)
			var rr := Rect2(x0, y, w, 36.0)
			if hot(rr):
				rect(rr, Color(1, 1, 1, 0.045))
			elif i % 2 == 0:
				rect(rr, Color(1, 1, 1, 0.022))
			var tc2 := StatsPanel.side_col(int(h2.team))
			# the rank in a little cut-cornered box
			var rb := Rect2(x0 + 8, y + 7, 24, 22)
			draw_polygon(UiFx.chamfer(rb, 5.0), PackedColorArray([c(UiFx.fade(tc2, 0.25)), c(UiFx.fade(tc2, 0.25)), c(UiFx.fade(tc2, 0.25)), c(UiFx.fade(tc2, 0.25)), c(UiFx.fade(tc2, 0.25)), c(UiFx.fade(tc2, 0.25))]))
			big(rb.position.x, y + 24, "%d" % (i + 1), 15, tc2.lightened(0.45), HORIZONTAL_ALIGNMENT_CENTER, rb.size.x)
			txt(x0 + 44, y + 16, String(h2.name), 14, UiKit.TEXT, 700)
			var unit := String(p.unit_names.get(String(h2.unit), ""))
			txt(x0 + 44, y + 31, String(h2.role) + ("  ·  " + unit if unit != "" else ""), 11, UiKit.DIM)
			var kills := StatsPanel.plural(float(h2.kills), "kill")
			if int(h2.veh) > 0:
				kills += ", " + StatsPanel.plural(float(h2.veh), "vehicle")
			txt(x0, y + 16, kills, 13, UiKit.TEXT, 600, HORIZONTAL_ALIGNMENT_RIGHT, w - 8.0)
			if bool(h2.alive):
				cap(x0, y + 31, "Alive", 9, UiKit.GOOD, HORIZONTAL_ALIGNMENT_RIGHT, w - 8.0)
			else:
				cap(x0, y + 31, "Killed in action", 9, UiKit.BAD, HORIZONTAL_ALIGNMENT_RIGHT, w - 8.0)
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
		ink = p.appear(0.0, 0.3)
		columns("Commander", name_w, cols, ["rating"])
		settle()
		var y := 28.0
		var sds: Array = p.report.sides
		for t in p.sides_in_order():
			var pl := p.players_of(t)
			if pl.is_empty():
				continue
			y += 6.0
			slide(p.appear(0.05 + _n * 0.06, 0.4), -24.0)
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
		var d := 0.1 + _n * 0.07
		_n += 1
		var a := p.appear(d, 0.42)
		slide(a, 40.0)
		var r := Rect2(0, y, w, ROW_H - 6.0)
		var me := id == p.me_id
		var key := "c%d_%d" % [id, int(cm.get("team", 0))]
		if not total:
			var on := id == p.pick
			UiFx.card(self, r, ink, 1.0 if hot(r) else 0.0, UiFx.fade(UiKit.ACCENT, 0.6) if on else Color(1, 1, 1, 0.06))
			if on:
				rect(Rect2(0, y, 4, ROW_H - 6.0), UiKit.ACCENT)
			_rows.append([r, id])
			rect(Rect2(10, y + 12, 3, ROW_H - 30.0), StatsPanel.side_col(int(cm.team)))
			txt(22, y + 22, String(cm.name), 16, UiKit.ACCENT if me else UiKit.TEXT, 700, HORIZONTAL_ALIGNMENT_LEFT, name_w - 30.0)
			cap(22, y + 39, p.who_tag(cm), 9, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, name_w - 30.0, 2)
			tip(Rect2(0, y, name_w, ROW_H), "Click for the breakdown.")
		else:
			line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.08))
			cap(22, y + 28, "Side total", 10, UiKit.DIM)
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
						UiFx.ring(self, Vector2(x + 16, cy - 5), 13.0, 3.5, shown / 100.0, rc, ink)
						big(x + 38, cy + 2, "%d" % int(round(shown)), 22, rc)
						cap(x + 70, cy - 1, UiKit.rating_word(rv), 9, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, cw - 72.0, 1)
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
				txt(x, cy, s, 14, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_RIGHT, cw - 10.0)
			else:
				big(x, cy + 1, s, 18, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, cw - 10.0)
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
		var d := maxf(0.25 + _n * 0.07, _d0)
		var y := head(0, y0, "Breakdown  ·  " + String(cm.name), w, d)
		var a := p.appear(d + 0.05, 0.5)
		slide(a, 0.0, 18.0)
		var box := Rect2(0, y, w, 214)
		UiFx.panel(self, box, ink, 12.0, Color(0.08, 0.095, 0.09, 0.9), Color(0.04, 0.05, 0.048, 0.92))
		var key := "d%d" % int(cm.id)
		var rv := BattleStats.rating(cm, side)
		var shown := p.num(key + "r", rv, d + 0.15, 1.4)
		var rc := UiKit.rating_col(shown)
		# the rating on a dial
		var dc := Vector2(86, y + 100)
		UiFx.ring(self, dc, 54.0, 8.0, shown / 100.0, rc, ink)
		big(dc.x - 60, dc.y + 14, "%d" % int(round(shown)), 46, rc, HORIZONTAL_ALIGNMENT_CENTER, 120)
		cap(dc.x - 60, dc.y + 34, UiKit.rating_word(rv), 10, rc, HORIZONTAL_ALIGNMENT_CENTER, 120, 2)
		cap(dc.x - 60, y + 30, "Rating", 9, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER, 120, 3)
		txt(dc.x - 70, y + 186, "Score  " + UiKit.fmt_num(p.num(key + "s", float(BattleStats.score(cm)), d + 0.2)), 13, UiKit.TEXT, 600, HORIZONTAL_ALIGNMENT_CENTER, 140)
		var tag := p.who_tag(cm)
		cap(dc.x - 70, y + 203, String(Defs.TEAM_NAMES[int(cm.team)]) + (("  ·  " + tag) if tag != "" else ""), 9, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER, 140, 1)
		# what the rating is made of
		var mx := 200.0
		var mw := clampf(w * 0.32, 230.0, 330.0)
		cap(mx, y + 30, "What the rating weighs", 10, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 2)
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
		var py := y + 54.0
		for i in parts.size():
			var pt: Array = parts[i]
			var fk := p.num(key + "p%d" % i, float(pt[2]), d + 0.3 + i * 0.18, 0.9)
			txt(mx, py, String(pt[0]), 13, UiKit.TEXT, 600)
			cap(mx, py, String(pt[1]), 9, UiKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT, mw, 1)
			UiFx.bar(self, Rect2(mx, py + 8, mw, 7), fk, UiKit.rating_col(float(pt[2]) * 100.0), ink, 1.0 - UiFx.span(p.page_t, d + 0.3 + i * 0.18, 0.9))
			txt(mx, py + 30, String(pt[3]), 11, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_LEFT, mw)
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
				cap(gxi, y + 30, String(groups[gi][0]), 10, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 2)
				line(Vector2(gxi, y + 38), Vector2(gxi + gw - 18.0, y + 38), Color(1, 1, 1, 0.07))
				var ly := y + 60.0
				var rows: Array = groups[gi][1]
				for ri in rows.size():
					var kv: Array = rows[ri]
					var la := p.appear(d + 0.25 + gi * 0.08 + ri * 0.04, 0.3)
					ink = a * la
					txt(gxi, ly, String(kv[0]), 12, UiKit.DIM)
					var vs := String(kv[1]) if kv[1] is String else UiKit.fmt_num(p.num(key + "g%d%d" % [gi, ri], float(kv[1]), d + 0.25 + gi * 0.08 + ri * 0.04, 0.7))
					big(gxi, ly + 1, vs, 16, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, gw - 18.0)
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
		ink = p.appear(0.0, 0.3)
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
			slide(p.appear(0.04 + mini(n, 18) * 0.035, 0.4), -24.0)
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
				var d := 0.08 + mini(n, 18) * 0.035
				n += 1
				slide(p.appear(d, 0.38), 34.0)
				var r := Rect2(0, y, w, 38)
				if hot(r):
					UiFx.card(self, r, ink, 1.0)
				elif i % 2 == 0:
					rect(r, Color(1, 1, 1, 0.025))
				var veh := String(u.kind) == "vehicle"
				var mine := int(u.owner) == p.me_id
				rect(Rect2(6, y + 10, 3, 18), StatsPanel.side_col(t))
				var nm := String(u.name) + ((" %d" % int(vno.get(String(u.key), 1))) if veh and int(seq.get(String(u.name), 0)) > 1 else "")
				txt(18, y + 17, nm, 14, UiKit.ACCENT if mine else UiKit.TEXT, 700, HORIZONTAL_ALIGNMENT_LEFT, name_w - 22.0)
				cap(18, y + 31, "Vehicle" if veh else String(u.kind), 9, UiKit.DIM, HORIZONTAL_ALIGNMENT_LEFT, name_w - 22.0, 1)
				var gone := float(u.t1) >= 0.0
				var x := name_w
				for col in cols:
					var cw := float(col[2])
					var ck: String = col[0]
					var s := ""
					match ck:
						"owner":
							txt(x, y + 24, String(p.names.get(int(u.owner), "-")), 13, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_LEFT, cw - 8.0)
						"kills", "downs", "veh", "lost":
							var field := "veh_kills" if ck == "veh" else ck
							var v := float(u.get(field, 0))
							s = UiKit.fmt_num(p.num("u%s%s" % [String(u.key), ck], v, d + 0.05, 0.7))
							big(x, y + 25, s, 17, UiKit.TEXT if v > 0.0 else UiFx.fade(UiKit.DIM, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, cw - 10.0)
						"men":
							if veh:
								txt(x, y + 24, "-", 13, UiKit.DIM, 400, HORIZONTAL_ALIGNMENT_RIGHT, cw - 10.0)
							else:
								# a pip a man, lit while he stands
								var most := maxi(int(u.men), int(u.alive))
								var pw := 5.0
								var px := x + cw - 10.0 - most * (pw + 2.0)
								for m in most:
									var lit := m < int(u.alive)
									rect(Rect2(px + m * (pw + 2.0), y + 14, pw, 11), Color(0.9, 0.93, 0.88, 0.9) if lit else Color(1, 1, 1, 0.12))
						"time":
							txt(x, y + 24, UiKit.fmt_time((float(u.t1) if gone else now) - float(u.t0)), 13, UiKit.DIM, 600, HORIZONTAL_ALIGNMENT_RIGHT, cw - 10.0)
						"status":
							var stc := UiKit.BAD if gone else UiKit.GOOD
							var st := ("Destroyed" if veh else "Wiped out") if gone else "In the field"
							var sf := UiFx.spaced(700, 1)
							var sw := UiFx.width(sf, st.to_upper(), 9) + 14.0
							var pr := Rect2(x + cw - 10.0 - sw, y + 11, sw, 17)
							rect(pr, UiFx.fade(stc, 0.13))
							draw_rect(pr, c(UiFx.fade(stc, 0.6)), false, 1.0)
							draw_string(sf, Vector2(pr.position.x + 7, y + 23.5), st.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, c(stc))
					x += cw
				settle()
				y += 40.0
			if us.size() > MAX_ROWS:
				txt(12, y + 16, "... and %d more" % (us.size() - MAX_ROWS), 12, UiKit.DIM)
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
			cap(0, 64, "The timeline fills in as the battle goes on", 13, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER, size.x, 3)
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
			rects.append(Rect2((ci % 2) * (cw + gap), 4.0 + (ci / 2) * (ch + gap), cw, ch))
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
		var k := UiFx.span(p.page_t, delay + 0.15, 1.5)
		if k < 1.0:
			p.moving = true
		return UiFx.in_out(k)

	func _chart(r: Rect2, spec: Array, tl: Array, t0: float, t1: float, hover_t: float, delay: float) -> void:
		var a := p.appear(delay, 0.4)
		slide(a, 0.0, 14.0)
		UiFx.panel(self, r, ink, 10.0, Color(0.07, 0.085, 0.08, 0.7), Color(0.035, 0.045, 0.042, 0.8))
		cap(r.position.x + 16, r.position.y + 24, String(spec[0]), 11, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 2)
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
			var gy := plot.end.y - plot.size.y * g / float(lines_n)
			line(Vector2(plot.position.x, gy), Vector2(plot.position.x + plot.size.x * a, gy), Color(1, 1, 1, 0.05 if g > 0 else 0.15))
			big(r.position.x + 4, gy + 4, UiKit.fmt_num(step * g), 11, UiKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 38)
		for g in 5:
			var gx := lerpf(plot.position.x, plot.end.x, g / 4.0)
			big(gx - 30, plot.end.y + 17, UiKit.fmt_time(lerpf(t0, t1, g / 4.0)), 11, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER, 60)
		var span := maxf(1.0, t1 - t0)
		var drawn := _drawn(delay)
		var t_cut := lerpf(t0, t1, drawn)
		# each side's line, its area washed in under it (your own side drawn last, on top)
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
			var area := pts.duplicate()
			area.append(Vector2(pts[pts.size() - 1].x, plot.end.y))
			area.append(Vector2(pts[0].x, plot.end.y))
			var cols := PackedColorArray()
			for q in area:
				var hk := clampf((plot.end.y - q.y) / maxf(1.0, plot.size.y), 0.0, 1.0)
				cols.append(c(Color(sc.r, sc.g, sc.b, 0.03 + 0.12 * hk)))
			if Geometry2D.triangulate_polygon(area).size() > 0:
				draw_polygon(area, cols)
			draw_polyline(pts, c(UiFx.fade(sc, 0.25)), 6.0, true)
			draw_polyline(pts, c(sc.lightened(0.15)), 2.0, true)
			if drawn < 1.0:
				var hp := pts[pts.size() - 1]
				draw_circle(hp, 6.0, c(UiFx.fade(sc, 0.3)))
				draw_circle(hp, 3.0, c(Color(1, 1, 1, 0.95)))
		# legend
		var lx := r.end.x - 14.0
		for t in [order[1], order[0]]:
			var nm := String(Defs.TEAM_NAMES[t]).to_upper()
			var known: bool = float(tl.back()[int(spec[1 + t])]) >= 0.0
			if not known:
				nm += "  (CLASSIFIED)"
			var f2 := UiFx.spaced(700, 1)
			var tw := UiFx.width(f2, nm, 10)
			lx -= tw
			draw_string(f2, Vector2(lx, r.position.y + 24), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c(StatsPanel.side_col(t).lightened(0.3) if known else UiKit.DIM))
			rect(Rect2(lx - 16, r.position.y + 17, 10, 3), StatsPanel.side_col(t))
			lx -= 30.0
		# the cursor: both sides' figures at that moment
		if hover_t >= 0.0 and drawn >= 1.0:
			var hx := plot.position.x + plot.size.x * (hover_t - t0) / span
			line(Vector2(hx, plot.position.y), Vector2(hx, plot.end.y), Color(1, 1, 1, 0.3))
			var row2 := _at(tl, hover_t)
			var ty := plot.position.y + 4.0
			var lines := []
			for t in order:
				var v2 := float(row2[int(spec[1 + t])])
				if v2 >= 0.0:
					lines.append([t, UiKit.fmt_num(v2)])
					var py := plot.end.y - plot.size.y * v2 / vmax
					draw_circle(Vector2(hx, py), 4.0, c(StatsPanel.side_col(t).lightened(0.3)))
			var bw := 96.0
			var bx := hx + 10.0 if hx + 10.0 + bw < plot.end.x else hx - 10.0 - bw
			var bh := 22.0 + 17.0 * lines.size()
			UiFx.card(self, Rect2(bx, ty, bw, bh), ink, 0.5)
			big(bx + 9, ty + 15, UiKit.fmt_time(hover_t), 11, UiKit.DIM)
			for li in lines.size():
				var tt: int = lines[li][0]
				rect(Rect2(bx + 9, ty + 24 + li * 17, 6, 6), StatsPanel.side_col(tt))
				big(bx + 21, ty + 32 + li * 17, String(lines[li][1]), 14, UiKit.TEXT)
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
	## popping up as the lines reach it; hover one to read it.
	func _events(r: Rect2, t0: float, t1: float, hover_t: float) -> void:
		var ev: Array = p.report.get("ev", [])
		var a := p.appear(0.3, 0.4)
		ink = a
		cap(r.position.x + 16, r.position.y + 14, "Events", 11, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 2)
		var px := _plot_x(r)
		var x0 := px.x
		var x1 := px.y
		var plot_w := x1 - x0
		var span := maxf(1.0, t1 - t0)
		var ly := r.position.y + 34.0
		line(Vector2(x0, ly), Vector2(x0 + (x1 - x0) * a, ly), Color(1, 1, 1, 0.14))
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
			var pop := UiFx.out_back(clampf((reach - et) / maxf(1.0, span) * 12.0, 0.0, 1.0))
			var cy := ly + (-8.0 if kind == "fob" or kind == "town" else (8.0 if kind == "sup" else 0.0))
			var sz := 5.0 * pop
			match kind:
				"fob", "town":
					draw_colored_polygon(PackedVector2Array([Vector2(ex, cy - sz), Vector2(ex + sz, cy), Vector2(ex, cy + sz), Vector2(ex - sz, cy)]), c(col.lightened(0.1)))
				"sup":
					draw_colored_polygon(PackedVector2Array([Vector2(ex, cy - sz * 0.9), Vector2(ex + sz * 0.9, cy + sz * 0.7), Vector2(ex - sz * 0.9, cy + sz * 0.7)]), c(col.lightened(0.25)))
				_:
					rect(Rect2(ex - sz * 0.6, cy - sz * 0.6, sz * 1.2, sz * 1.2), col.darkened(0.05))
			tip(Rect2(ex - 7, cy - 8, 14, 16), "%s  %s" % [UiKit.fmt_time(et), String(e[3])])
			var dd := absf(mouse.x - ex) + absf(mouse.y - cy) * 0.5
			if mouse.x >= 0.0 and dd < best_d and dd < 24.0:
				best_d = dd
				near = e
		if not near.is_empty():
			big(x0, ly + 28, UiKit.fmt_time(float(near[0])), 13, UiKit.ACCENT)
			txt(x0 + 46, ly + 28, String(near[3]), 13, UiKit.TEXT, 600)
		elif ev.is_empty():
			cap(x0, ly + 27, "Nothing of note yet", 10, UiKit.DIM)
		else:
			var kx := x0 + 6.0
			var ky := ly + 22.0
			var kc := Color(0.75, 0.76, 0.72)
			draw_colored_polygon(PackedVector2Array([Vector2(kx, ky - 5), Vector2(kx + 5, ky), Vector2(kx, ky + 5), Vector2(kx - 5, ky)]), c(kc))
			cap(kx + 11, ky + 4, "FOBs and towns", 9, UiKit.DIM)
			kx += 30.0 + UiFx.width(UiFx.spaced(700, 2), "FOBS AND TOWNS", 9)
			rect(Rect2(kx - 3, ky - 3, 6, 6), kc)
			cap(kx + 11, ky + 4, "Vehicles lost", 9, UiKit.DIM)
			kx += 30.0 + UiFx.width(UiFx.spaced(700, 2), "VEHICLES LOST", 9)
			draw_colored_polygon(PackedVector2Array([Vector2(kx, ky - 4), Vector2(kx + 4, ky + 3), Vector2(kx - 4, ky + 3)]), c(kc))
			cap(kx + 11, ky + 4, "Fire missions", 9, UiKit.DIM)
			kx += 30.0 + UiFx.width(UiFx.spaced(700, 2), "FIRE MISSIONS", 9)
			cap(kx, ky + 4, "(hover one to read it)", 9, UiFx.fade(UiKit.DIM, 0.6))
		if hover_t >= 0.0:
			var hx := x0 + plot_w * (hover_t - t0) / span
			line(Vector2(hx, ly - 12), Vector2(hx, ly + 12), Color(1, 1, 1, 0.25))
		settle()
