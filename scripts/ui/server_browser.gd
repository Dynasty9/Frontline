class_name ServerBrowser
extends PanelContainer
## The server browser: every battle being hosted, online (the matchmaker's
## list) and on this network (their LAN beacons), in a table that can be
## searched, filtered and sorted, with the chosen battle's details beside it.
## Double-click a battle, or pick it and press Join. Direct Connect takes an
## address, for a battle that isn't listed anywhere.
## Signal (docs/UI.md): the battles are ruled rows on the sheet's ink, names in
## capitals, every figure and state in mono; the chosen one takes the accent.

signal join_requested(entry: Dictionary)
signal direct_requested(address: String, port: int, password: String)
signal host_requested
signal closed

const REFRESH_S := 10.0
const ROW_H := 36
## [key, header, width (0: takes the rest)]
const COLS := [["name", "Battle", 0], ["mode", "Mode", 230], ["players", "Players", 130], ["status", "Status", 150], ["link", "Link", 96]]
const MODE_FILTERS := [["", "All"], ["coop", "Co-op"], ["versus", "Versus"], ["mission", "Missions"]]

var _online: Array = []  # what the matchmaker listed last
var _online_err := ""
var _fetching := false
var _fetch_n := 0  # the latest refresh (an older answer arriving late is dropped)
var _fetched_at := -100.0
var _lan_ok := true
var _entries: Array = []  # online and LAN, merged: what the table shows before filtering
var _sel := ""  # the chosen battle's key
var _sort := ""  # "" for the browser's own order: joinable first, then the fullest
var _sort_desc := false
var _search := ""
var _mode := ""
var _hide_full := false
var _hide_running := false
var _hide_locked := false

var _list: VBoxContainer
var _empty: Label
var _n_battles: Label
var _n_players: Label
var _updated: Label
var _heads := {}  # column key -> Button
var _head_box: HBoxContainer
var _scroll: ScrollContainer
var _detail: VBoxContainer
var _join_btn: Button
var _join_note: Label
var _addr: LineEdit
var _port: LineEdit
var _pw: LineEdit
var _tick: Timer


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.frame(Color(-1, 0, 0), 22.0, 0.0, 14.0, 0.93))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	# the title, and how busy it is out there
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 22)
	v.add_child(top)
	top.add_child(UiKit.caps("Server browser", 18, UiKit.TEXT, 600, 2))
	_updated = UiKit.mono_label("", 11, UiKit.FAINT)
	_updated.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_updated.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_updated.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_updated)
	_n_battles = _figure(top, "Battles")
	_n_players = _figure(top, "Players")

	# search and filters: the mode is one choice, what to hide any of three
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 26)
	v.add_child(fr)
	var search := LineEdit.new()
	search.placeholder_text = "Search battles and hosts"
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(280, 30)
	search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	search.text_changed.connect(func(t: String):
		_search = t.strip_edges().to_lower()
		_render())
	fr.add_child(search)
	var names: Array = []
	for m in MODE_FILTERS:
		names.append(String(m[1]))
	var mo := UiSeg.make(names, 0)
	mo.changed.connect(func(i: int):
		_mode = String(MODE_FILTERS[i][0])
		_render())
	fr.add_child(_labelled("Mode", mo))
	fr.add_child(_labelled("Hide", _toggles([
		["Full", func(on: bool): _hide_full = on],
		["Running", func(on: bool): _hide_running = on],
		["Password", func(on: bool): _hide_locked = on],
	])))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fr.add_child(gap)
	var rf := UiKit.button("Refresh", "secondary", 100, 30)
	rf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rf.pressed.connect(refresh)
	fr.add_child(rf)

	# the table, and the chosen battle beside it (a rule between, no boxes)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 0)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(tcol)
	_head_box = HBoxContainer.new()
	_head_box.add_theme_constant_override("separation", 0)
	_head_box.custom_minimum_size = Vector2(0, 28)
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 12)
	hm.add_theme_constant_override("margin_right", 12)
	hm.add_child(_head_box)
	tcol.add_child(hm)
	for c in COLS:
		# a column's header: faint capitals; the one it's sorted by in the accent
		var hb := Button.new()
		hb.flat = true
		hb.focus_mode = Control.FOCUS_NONE
		hb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		hb.add_theme_font_override("font", UiKit.cond(600, 1))
		hb.add_theme_font_size_override("font_size", 11)
		hb.add_theme_color_override("font_color", UiKit.FAINT)
		hb.add_theme_color_override("font_hover_color", UiKit.TEXT)
		hb.add_theme_color_override("font_pressed_color", UiKit.ACCENT)
		hb.add_theme_color_override("font_hover_pressed_color", UiKit.ACCENT)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			hb.add_theme_stylebox_override(st, UiKit.bare())
		_size_cell(hb, int(c[2]))
		var key: String = c[0]
		hb.pressed.connect(func(): _sort_by(key))
		_head_box.add_child(hb)
		_heads[key] = hb
	tcol.add_child(_hrule(UiKit.RULE2))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# the scroll bar always keeps its room, so the rows line up with the
	# headers whether the list is long or short
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tcol.add_child(_scroll)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 0)
	_scroll.add_child(lv)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(_list)
	_empty = UiKit.label("", 14, UiKit.DIM)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.custom_minimum_size = Vector2(0, 140)
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv.add_child(_empty)

	body.add_child(VSeparator.new())
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	dv.custom_minimum_size = Vector2(330, 0)
	body.add_child(dv)
	var dh := UiKit.header("Details")
	dh.custom_minimum_size = Vector2(0, 28)
	dv.add_child(dh)
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(dscroll)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 0)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(_detail)
	_join_note = UiKit.label("", 12, UiKit.DIM)
	_join_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_join_note)
	_join_btn = UiKit.primary_button("Join battle", 0, 42, 15)
	_join_btn.pressed.connect(func(): Sfx.ui("click"); _join_selected())
	dv.add_child(_join_btn)

	# connect by address (one line of fields), or host instead
	v.add_child(_hrule(UiKit.LINE))
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 12)
	v.add_child(bot)
	var dl := UiKit.caps("Direct connect", 11, UiKit.FAINT)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot.add_child(dl)
	_addr = LineEdit.new()
	_addr.placeholder_text = "Host address (IP)"
	_addr.custom_minimum_size = Vector2(220, 30)
	_addr.text_submitted.connect(func(_t): _direct())
	bot.add_child(_addr)
	var colon := UiKit.mono_label(":", 13, UiKit.FAINT)
	colon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot.add_child(colon)
	_port = LineEdit.new()
	_port.text = str(Net.DEFAULT_PORT)
	_port.max_length = 5
	_port.custom_minimum_size = Vector2(64, 30)
	_port.tooltip_text = "The host's UDP port (7777 unless they changed it)"
	_port.text_submitted.connect(func(_t): _direct())
	bot.add_child(_port)
	_pw = LineEdit.new()
	_pw.placeholder_text = "Password, if any"
	_pw.secret = true
	_pw.custom_minimum_size = Vector2(170, 30)
	_pw.text_submitted.connect(func(_t): _direct())
	bot.add_child(_pw)
	var go := UiKit.button("Join", "secondary", 80, 30)
	go.pressed.connect(_direct)
	bot.add_child(go)
	var gap2 := Control.new()
	gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(gap2)
	var hb2 := UiKit.button("Host a battle", "secondary", 0, 30)
	hb2.pressed.connect(func(): host_requested.emit())
	bot.add_child(hb2)
	var back := UiKit.button("Back", "secondary", 90, 30)
	back.pressed.connect(func(): closed.emit())
	bot.add_child(back)

	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.timeout.connect(_on_tick)
	add_child(_tick)
	visibility_changed.connect(_on_visibility)
	Online.lan_changed.connect(_merge)
	_heads_text()
	_show_detail()
	_on_visibility()


## A figure on the title line: its name in faint capitals, the number in mono.
func _figure(parent: Control, label: String) -> Label:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UiKit.caps(label, 11, UiKit.FAINT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var n := UiKit.mono_label("0", 15, UiKit.TEXT)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(n)
	parent.add_child(h)
	return n


## A control with its name before it in faint capitals.
func _labelled(label: String, c: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := UiKit.caps(label, 11, UiKit.FAINT)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(c)
	return h


## Segments that each turn on and off by themselves (what to hide: any of
## them at once), drawn like a UiSeg's: [text, setter taking on/off].
func _toggles(items: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", -1)
	var n := _seg_box(Color(0, 0, 0, 0), UiKit.LINE)
	var hv := _seg_box(UiKit.fa(UiKit.TEXT, 0.05), UiKit.RULE2)
	var on := _seg_box(UiKit.ACCENT, UiKit.ACCENT)
	for it in items:
		var b := Button.new()
		b.text = String(it[0]).to_upper()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 26)
		b.add_theme_font_override("font", UiKit.cond(600, 1))
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", UiKit.FAINT)
		b.add_theme_color_override("font_hover_color", UiKit.TEXT)
		b.add_theme_color_override("font_pressed_color", UiKit.ON_ACCENT)
		b.add_theme_color_override("font_hover_pressed_color", UiKit.ON_ACCENT)
		var set_it: Callable = it[1]
		b.toggled.connect(func(o: bool):
			set_it.call(o)
			_render())
		h.add_child(b)
	return h


func _seg_box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := UiKit.box(bg, 0, border, 1, 0.0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func _hrule(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A table cell: a fixed width, or (0) the rest of the row.
func _size_cell(c: Control, w: int) -> void:
	if w > 0:
		c.custom_minimum_size.x = w
		c.size_flags_horizontal = Control.SIZE_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size.x = 120


func _on_visibility() -> void:
	if is_visible_in_tree():
		_lan_ok = Online.lan_listen(true)
		_tick.start()
		# the header leaves the scroll bar's room too
		var sb := _scroll.get_v_scroll_bar()
		(_head_box.get_parent() as MarginContainer).add_theme_constant_override("margin_right", 12 + int(sb.get_combined_minimum_size().x))
		refresh()
	else:
		Online.lan_listen(false)
		_tick.stop()


func _on_tick() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not _fetching and now - _fetched_at >= REFRESH_S:
		refresh()
	_status_line()


## When the list was last fetched, as a code; or, when something's wrong, why,
## in a sentence.
func _status_line() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var s := ""
	var prose := _online_err != "" or not _lan_ok
	if _fetching and _fetched_at < 0.0:
		s = "SEARCHING..."
	elif _online_err != "":
		s = "Can't reach the matchmaker: showing battles on your network only"
	else:
		var ago := int(now - _fetched_at)
		s = "UPDATED %s · AUTO" % ("NOW" if ago < 2 else "%d S AGO" % ago)
	if not _lan_ok:
		s += " · LAN search off (another copy of the game has it)"
	_updated.text = s
	_updated.add_theme_font_override("font", UiKit.font(400) if prose else UiKit.mono(400))
	_updated.add_theme_font_size_override("font_size", 12 if prose else 11)
	_updated.add_theme_color_override("font_color", UiKit.WARN if prose else UiKit.FAINT)


## Ask the matchmaker for the list again (the LAN keeps itself up to date).
func refresh() -> void:
	_fetch_n += 1
	var n := _fetch_n
	_fetching = true
	_status_line()
	var r: Dictionary = await Online.browse()
	if n != _fetch_n:
		return
	_fetching = false
	_fetched_at = Time.get_ticks_msec() / 1000.0
	if r.ok:
		_online = r.data.get("lobbies", [])
		_online_err = ""
	else:
		_online_err = String(r.error)
	_merge()
	_status_line()


## The online list and the LAN's, as one. A battle that's listed online and
## also on our network is joined over the LAN (no router in the way).
func _merge() -> void:
	var out: Array = []
	var by_id := {}
	for l in _online:
		if not (l is Dictionary):
			continue
		var e: Dictionary = (l as Dictionary).duplicate()
		e["key"] = "o:" + String(e.get("id", ""))
		e["lan"] = false
		out.append(e)
		by_id[String(e.get("id", ""))] = e
	for k in Online.lan_games:
		var g: Dictionary = Online.lan_games[k]
		var id := String(g.get("id", ""))
		if id != "" and by_id.has(id):
			var o: Dictionary = by_id[id]
			o["lan"] = true
			o["address"] = String(g.get("address", ""))
			o["port"] = int(g.get("port", Net.DEFAULT_PORT))
			continue
		var e: Dictionary = g.duplicate()
		e["key"] = "l:" + String(k)
		e["lan"] = true
		e["verified"] = false
		e["age"] = -1
		out.append(e)
	_entries = out
	_render()


# --- what a battle is ----------------------------------------------------------------------

static func joinable(e: Dictionary) -> bool:
	return int(e.get("players", 0)) < int(e.get("max_players", 8)) and (not bool(e.get("in_game", false)) or bool(e.get("drop_in", true)))


## [what kind of battle, a detail code]
static func mode_text(e: Dictionary) -> Array:
	var side := clampi(int(e.get("side", 0)), 0, 1)
	var teams: Array = e.get("teams", [0, 0]) if e.get("teams") is Array else [0, 0]
	match String(e.get("mode", "")):
		"coop":
			return ["Co-op vs AI", Defs.TEAM_NAMES[side]]
		"versus":
			return ["Versus", "%d v %d" % [int(teams[0]) if teams.size() > 0 else 0, int(teams[1]) if teams.size() > 1 else 0]]
		"mission":
			return ["Mission", String(e.get("mission", ""))]
	return ["Battle", ""]


## [code, colour, sort rank]
static func status_of(e: Dictionary) -> Array:
	if int(e.get("players", 0)) >= int(e.get("max_players", 8)):
		return ["FULL", UiKit.BAD, 3]
	if not bool(e.get("in_game", false)):
		return ["LOBBY", UiKit.GOOD, 0]
	if bool(e.get("drop_in", true)):
		return ["LIVE · DROP-IN", UiKit.ACCENT, 1]
	return ["LIVE · CLOSED", UiKit.DIM, 2]


## [code, colour, sort rank, what it means]
static func link_of(e: Dictionary) -> Array:
	if bool(e.get("lan", false)):
		return ["LAN", UiKit.INTEL, 0, "On your network: a direct connection."]
	match String(e.get("nat", "unknown")):
		"open":
			return ["DIRECT", UiKit.GOOD, 1, "The host takes connections directly."]
		"cone":
			return ["GOOD", UiKit.GOOD, 2, "The game gets you through both routers by hole punching."]
		"strict":
			return ["STRICT", UiKit.WARN, 4, "This host's router can't be punched through: you'll only get in if they've forwarded UDP port 7777."]
	return ["UNKNOWN", UiKit.DIM, 3, "The host's router couldn't be checked. It usually works."]


func _find(key: String) -> Dictionary:
	for e in _entries:
		if String(e.key) == key:
			return e
	return {}


# --- the table -------------------------------------------------------------------------------

func _passes(e: Dictionary) -> bool:
	if _hide_full and int(e.get("players", 0)) >= int(e.get("max_players", 8)):
		return false
	if _hide_running and bool(e.get("in_game", false)):
		return false
	if _hide_locked and bool(e.get("locked", false)):
		return false
	if _mode != "" and String(e.get("mode", "")) != _mode:
		return false
	if _search != "":
		var hay := ("%s %s %s" % [e.get("name", ""), e.get("host", ""), e.get("mission", "")]).to_lower()
		if not _search in hay:
			return false
	return true


func _sort_key(e: Dictionary) -> Variant:
	match _sort:
		"name":
			return String(e.get("name", "")).to_lower()
		"mode":
			return String(mode_text(e)[0]) + String(mode_text(e)[1])
		"players":
			return int(e.get("players", 0))
		"status":
			return int(status_of(e)[2])
		"link":
			return int(link_of(e)[2])
	return 0


func _less(a: Dictionary, b: Dictionary) -> bool:
	if _sort == "":
		var ja := joinable(a)
		if ja != joinable(b):
			return ja
		if int(a.get("players", 0)) != int(b.get("players", 0)):
			return int(a.get("players", 0)) > int(b.get("players", 0))
		return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0
	var ka: Variant = _sort_key(a)
	var kb: Variant = _sort_key(b)
	if ka == kb:
		return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0
	return ka > kb if _sort_desc else ka < kb


func _sort_by(key: String) -> void:
	Sfx.ui("click")
	if _sort == key:
		if _sort_desc == (key == "players"):
			_sort_desc = not _sort_desc
		else:
			_sort = ""  # a third click: back to the browser's own order
	else:
		_sort = key
		_sort_desc = key == "players"
	_heads_text()
	_render()


func _heads_text() -> void:
	for c in COLS:
		var b: Button = _heads[c[0]]
		b.text = String(c[1]).to_upper() + (("  ▼" if _sort_desc else "  ▲") if _sort == String(c[0]) else "")
		b.add_theme_color_override("font_color", UiKit.ACCENT if _sort == String(c[0]) else UiKit.FAINT)


func _render() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var shown: Array = []
	var players := 0
	for e in _entries:
		players += int(e.get("players", 0))
		if _passes(e):
			shown.append(e)
	shown.sort_custom(_less)
	var still := false
	for e in shown:
		still = still or String(e.key) == _sel
	if not still:
		_sel = ""
	for e in shown:
		_list.add_child(_row(e))
	var n := _entries.size()
	_n_battles.text = str(n)
	_n_players.text = str(players)
	_empty.visible = shown.is_empty()
	if n == 0:
		if _fetching and _fetched_at < 0.0:
			_empty.text = "Looking for battles..."
		elif _online_err != "":
			_empty.text = "%s\nBattles on your network still show up here, and Direct Connect works." % _online_err
		else:
			_empty.text = "Nobody is hosting right now.\nHost a battle and it shows up here for everyone, straight away."
	else:
		_empty.text = "No battles match your search and filters (%d hidden)." % n
	_show_detail()


## A battle's row: ruled underneath; the cursor washes it, and the chosen one
## takes the accent's wash and a 2 px edge.
func _row(e: Dictionary) -> Button:
	var key := String(e.key)
	var ok := joinable(e)
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.button_pressed = key == _sel
	b.set_meta("key", key)
	var n := _row_box(Color(0, 0, 0, 0))
	var h := _row_box(UiKit.fa(UiKit.TEXT, 0.05))
	var p := _row_box(UiKit.fa(UiKit.ACCENT, 0.12))
	p.border_color = UiKit.ACCENT
	p.border_width_bottom = 0
	p.border_width_left = 2
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	# (a battle that can't be joined is drawn faded)
	var fade := 1.0 if ok else 0.5
	b.set_meta("fade", fade)
	# battle: its name (and a padlock), who hosts it
	var nv := _cell(row, int(COLS[0][2]))
	if bool(e.get("locked", false)):
		var lk := LockIcon.new()
		lk.custom_minimum_size = Vector2(10, 12)
		lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lk.modulate.a = fade
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nv.add_child(lk)
	var nm := _code(nv, String(e.get("name", "Battle")), 13, UiKit.fa(UiKit.ACCENT if key == _sel else UiKit.TEXT, fade), true)
	b.set_meta("name", nm)
	var host := String(e.get("host", ""))
	if bool(e.get("verified", false)):
		host += "  ✓"
	var hl := _code(nv, host, 11, UiKit.fa(UiKit.FAINT, fade), true)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.clip_text = true
	hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# mode, and what goes with it (the side, the sides' numbers, the mission)
	var mt := mode_text(e)
	var mv := _cell(row, int(COLS[1][2]))
	_code(mv, String(mt[0]), 12, UiKit.fa(UiKit.DIM, fade), true)
	if String(mt[1]) != "":
		_code(mv, String(mt[1]).to_upper(), 11, UiKit.fa(UiKit.FAINT, fade), false)
	# players: a count, and a step per seat
	var pv := _cell(row, int(COLS[2][2]))
	var np := int(e.get("players", 0))
	var mp := maxi(1, int(e.get("max_players", 8)))
	var cl := _code(pv, "%d/%d" % [np, mp], 12, UiKit.fa(UiKit.TEXT, fade), false)
	cl.custom_minimum_size.x = 34
	var seats := Seats.new()
	seats.filled = np
	seats.total = mp
	seats.col = UiKit.BAD if np >= mp else UiKit.ACCENT
	seats.custom_minimum_size = Vector2(Seats.STEP * mp, 8)
	seats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seats.modulate.a = fade
	seats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(seats)
	# status, connection: codes in the colour of what they mean
	var st := status_of(e)
	_code(_cell(row, int(COLS[3][2])), String(st[0]), 11, st[1], false)
	var lk2 := link_of(e)
	_code(_cell(row, int(COLS[4][2])), String(lk2[0]), 11, UiKit.fa(lk2[1], fade), false)
	b.tooltip_text = String(lk2[3])
	b.pressed.connect(func(): _select(key))
	b.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb and mb.pressed and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			_select(key)
			_join_selected())
	return b


func _row_box(bg: Color) -> StyleBoxFlat:
	var sb := UiKit.box(bg, 0, UiKit.LINE, 0, 0.0)
	sb.border_width_bottom = 1
	return sb


func _cell(row: HBoxContainer, w: int) -> HBoxContainer:
	var c := HBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.clip_contents = true
	_size_cell(c, w)
	row.add_child(c)
	return c


## A name in capitals or a code in mono, centred on the row.
func _code(c: Control, text: String, fs: int, col: Color, caps: bool) -> Label:
	var l := UiKit.caps(text, fs, col, 600, 1) if caps else UiKit.mono_label(text, fs, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.add_child(l)
	return l


func _select(key: String) -> void:
	_sel = key
	for b in _list.get_children():
		if b is Button:
			var on := String(b.get_meta("key", "")) == key
			(b as Button).set_pressed_no_signal(on)
			var nm: Label = b.get_meta("name", null)
			if nm:
				nm.add_theme_color_override("font_color", UiKit.fa(UiKit.ACCENT if on else UiKit.TEXT, float(b.get_meta("fade", 1.0))))
	_show_detail()


# --- the chosen battle -----------------------------------------------------------------------

func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var e := _find(_sel)
	if e.is_empty():
		var l := UiKit.label("Pick a battle to see who's in it.\n\nDouble-click one to join it straight away.", 13, UiKit.FAINT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(l)
		_join_btn.disabled = true
		_join_btn.text = "JOIN BATTLE"
		_join_note.text = ""
		return
	var nm := UiKit.caps(String(e.get("name", "")), 18, UiKit.TEXT, 600, 1)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(nm)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	hr.add_child(UiKit.caps("Hosted by", 11, UiKit.FAINT))
	var hl := UiKit.caps(String(e.get("host", "?")) + ("  ✓" if bool(e.get("verified", false)) else ""), 11, UiKit.DIM)
	if bool(e.get("verified", false)):
		hl.tooltip_text = "Signed in: this callsign belongs to their account."
		hl.mouse_filter = Control.MOUSE_FILTER_PASS
	hr.add_child(hl)
	_detail.add_child(hr)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_detail.add_child(gap)
	var st := status_of(e)
	_fact("Status", String(st[0]), st[1])
	if bool(e.get("locked", false)):
		_fact("Access", "PASSWORD", UiKit.WARN)
	var mt := mode_text(e)
	_fact("Mode", String(mt[0]).to_upper() + ("" if String(mt[1]) == "" else " · " + String(mt[1]).to_upper()))
	# who's on which side, and who the AI is
	var side := clampi(int(e.get("side", -1)), -1, 1)
	var mode := String(e.get("mode", ""))
	var teams: Array = e.get("teams", [0, 0]) if e.get("teams") is Array else [0, 0]
	for t in 2:
		var n := int(teams[t]) if teams.size() > t else 0
		var what := "%d PLAYER%s" % [n, "" if n == 1 else "S"]
		if mode in ["coop", "mission"] and side >= 0 and t != side:
			what = "AI" if mode == "coop" else "MISSION ENEMY"
		_fact(Defs.TEAM_NAMES[t], what, UiKit.TEXT, Defs.TEAM_COLORS[t])
	if int(e.get("spectators", 0)) > 0:
		_fact("Watching", str(int(e.spectators)))
	var np := int(e.get("players", 0))
	var mp := int(e.get("max_players", 8))
	_fact("Seats", "%d/%d · %d OPEN" % [np, mp, maxi(0, mp - np)])
	var lk := link_of(e)
	_fact("Link", String(lk[0]), lk[1])
	var why := UiKit.label(String(lk[3]), 12, UiKit.FAINT)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(why)
	var age := int(e.get("age", -1))
	if age >= 0:
		_fact("Up for", "%d MIN" % maxi(1, age / 60) if age >= 60 else "<1 MIN")
	var ok := joinable(e)
	_join_btn.disabled = not ok
	_join_btn.text = ("JOIN WITH PASSWORD" if bool(e.get("locked", false)) else "JOIN BATTLE") if ok else ("FULL" if np >= mp else "CLOSED")
	if not ok:
		_join_note.text = "Every seat is taken." if np >= mp else "The battle is under way and the host isn't letting anyone join mid-battle."
	elif bool(e.get("in_game", false)):
		_join_note.text = "Already under way: you'll drop straight into the fighting."
	else:
		_join_note.text = "You'll wait in the lobby until the host starts."


## A ruled row of the details: a faint label (with a marker square in a
## side's colour, for a side) and its value as a code.
func _fact(k: String, val: String, col := UiKit.TEXT, mark := Color(0, 0, 0, 0)) -> void:
	var p := PanelContainer.new()
	var sb := UiKit.box(Color(0, 0, 0, 0), 0, UiKit.LINE, 0, 0.0)
	sb.border_width_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(0, 30)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	p.add_child(r)
	if mark.a > 0.0:
		var sq := ColorRect.new()
		sq.color = mark
		sq.custom_minimum_size = Vector2(8, 8)
		sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(sq)
	var l := UiKit.caps(k, 11, UiKit.FAINT)
	l.custom_minimum_size = Vector2(96 if mark.a <= 0.0 else 80, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(l)
	var vl := UiKit.mono_label(val, 12, col)
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(vl)
	_detail.add_child(p)


## Choose the first battle whose name has `text` in it (test renders).
## False until the list has one.
func pick(text: String) -> bool:
	for b in _list.get_children():
		var e := _find(String(b.get_meta("key", "")))
		if not e.is_empty() and text.to_lower() in String(e.get("name", "")).to_lower():
			_select(String(e.key))
			return true
	return false


func _join_selected() -> void:
	var e := _find(_sel)
	if e.is_empty() or not joinable(e):
		return
	join_requested.emit(e)


## "1.2.3.4", or "1.2.3.4:7790" (which overrides the port field).
func _direct() -> void:
	var a := _addr.text.strip_edges()
	if a == "":
		_addr.grab_focus()
		return
	var pt := _port.text.strip_edges()
	var port := clampi(int(pt), 1024, 65535) if pt.is_valid_int() else Net.DEFAULT_PORT
	var parts := a.split(":")
	if parts.size() == 2 and parts[1].is_valid_int():
		a = parts[0]
		port = int(parts[1])
	Sfx.ui("click")
	direct_requested.emit(a, port, _pw.text)


## A padlock, square: the battle wants a password.
class LockIcon extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var col := UiKit.WARN
		var sw := w * 0.6
		draw_rect(Rect2((w - sw) * 0.5, 0.5, sw, h * 0.5), col, false, 1.0)
		draw_rect(Rect2(0, h * 0.45, w, h * 0.55), col)


## A step per seat, the taken ones filled: how full a battle is.
class Seats extends Control:
	const STEP := 6.0
	var filled := 0
	var total := 8
	var col := UiKit.ACCENT

	func _draw() -> void:
		UiKit.steps(self, Vector2(0, (size.y - 8.0) * 0.5), filled, total, col, STEP - 2.0, 8.0)
