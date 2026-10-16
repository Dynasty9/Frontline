class_name ServerBrowser
extends PanelContainer
## The server browser: every battle being hosted, online (the matchmaker's
## list) and on this network (their LAN beacons), in a table that can be
## searched, filtered and sorted, with the chosen battle's details beside it.
## Double-click a battle, or pick it and press Join. Direct Connect takes an
## address, for a battle that isn't listed anywhere.

signal join_requested(entry: Dictionary)
signal direct_requested(address: String, port: int, password: String)
signal host_requested
signal closed

const REFRESH_S := 10.0
## [key, header, width (0: takes the rest)]
const COLS := [["name", "BATTLE", 0], ["mode", "MODE", 170], ["players", "PLAYERS", 112], ["status", "STATUS", 150], ["link", "CONNECTION", 104]]
const MODE_FILTERS := [["", "All modes"], ["coop", "Co-op vs AI"], ["versus", "Versus"], ["mission", "Missions"]]

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
var _summary: Label
var _updated: Label
var _heads := {}  # column key -> Button
var _head_box: HBoxContainer
var _scroll: ScrollContainer
var _detail: VBoxContainer
var _join_btn: Button
var _join_note: Label
var _addr: LineEdit
var _port: SpinBox
var _pw: LineEdit
var _tick: Timer


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.boxc(Color(0.035, 0.045, 0.045, 0.94), 6, UiKit.LINE, 1, 20.0, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	# the title, and how busy it is out there
	var top := HBoxContainer.new()
	v.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	tv.add_child(UiKit.label("SERVER BROWSER", 13, UiKit.ACCENT, 700))
	tv.add_child(UiKit.label("Join a battle", 24, UiKit.TEXT, 600))
	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_END
	sv.add_theme_constant_override("separation", 1)
	top.add_child(sv)
	_summary = UiKit.label("", 15, UiKit.TEXT, 600)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sv.add_child(_summary)
	_updated = UiKit.label("", 12, UiKit.DIM)
	_updated.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sv.add_child(_updated)

	# search and filters
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 12)
	v.add_child(fr)
	var search := LineEdit.new()
	search.placeholder_text = "Search battles and hosts"
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(250, 34)
	search.text_changed.connect(func(t: String):
		_search = t.strip_edges().to_lower()
		_render())
	fr.add_child(search)
	var mo := OptionButton.new()
	for i in MODE_FILTERS.size():
		mo.add_item(String(MODE_FILTERS[i][1]), i)
	mo.custom_minimum_size = Vector2(150, 34)
	mo.item_selected.connect(func(i: int):
		_mode = String(MODE_FILTERS[i][0])
		_render())
	fr.add_child(mo)
	fr.add_child(_filter("Hide full", func(on: bool): _hide_full = on))
	fr.add_child(_filter("Hide running", func(on: bool): _hide_running = on))
	fr.add_child(_filter("Hide passworded", func(on: bool): _hide_locked = on))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fr.add_child(gap)
	fr.add_child(_btn("Refresh", refresh, 100))

	# the table, and the chosen battle beside it
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var tbl := PanelContainer.new()
	tbl.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.25), 4, Color(1, 1, 1, 0.05), 1, 4.0))
	tbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(tbl)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 0)
	tbl.add_child(tcol)
	_head_box = HBoxContainer.new()
	_head_box.add_theme_constant_override("separation", 0)
	_head_box.custom_minimum_size = Vector2(0, 30)
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 12)
	hm.add_theme_constant_override("margin_right", 12)
	hm.add_child(_head_box)
	tcol.add_child(hm)
	for c in COLS:
		var hb := Button.new()
		hb.flat = true
		hb.focus_mode = Control.FOCUS_NONE
		hb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		hb.add_theme_font_override("font", UiKit.font(700))
		hb.add_theme_font_size_override("font_size", 11)
		hb.add_theme_color_override("font_color", UiKit.DIM)
		hb.add_theme_color_override("font_hover_color", UiKit.ACCENT)
		hb.add_theme_color_override("font_pressed_color", UiKit.ACCENT)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			hb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		_size_cell(hb, int(c[2]))
		var key: String = c[0]
		hb.pressed.connect(func(): _sort_by(key))
		_head_box.add_child(hb)
		_heads[key] = hb
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.07)
	rule.custom_minimum_size = Vector2(0, 1)
	tcol.add_child(rule)
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
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(_list)
	_empty = UiKit.label("", 14, UiKit.DIM)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.custom_minimum_size = Vector2(0, 120)
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv.add_child(_empty)

	var det := PanelContainer.new()
	det.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.25), 4, Color(1, 1, 1, 0.05), 1, 16.0))
	det.custom_minimum_size = Vector2(300, 0)
	body.add_child(det)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	det.add_child(dv)
	var dscroll := ScrollContainer.new()
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(dscroll)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(_detail)
	_join_note = UiKit.label("", 12, UiKit.DIM)
	_join_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_join_note)
	_join_btn = UiKit.primary_button("JOIN BATTLE", 0, 44, 16)
	_join_btn.pressed.connect(func(): Sfx.ui("click"); _join_selected())
	dv.add_child(_join_btn)

	# connect by address, or host instead
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 8)
	v.add_child(bot)
	var dl := UiKit.label("Direct connect", 14, UiKit.DIM, 600)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot.add_child(dl)
	_addr = LineEdit.new()
	_addr.placeholder_text = "Host address (IP)"
	_addr.custom_minimum_size = Vector2(190, 36)
	_addr.text_submitted.connect(func(_t): _direct())
	bot.add_child(_addr)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = Net.DEFAULT_PORT
	_port.custom_minimum_size = Vector2(100, 36)
	_port.tooltip_text = "The host's UDP port (7777 unless they changed it)"
	bot.add_child(_port)
	_pw = LineEdit.new()
	_pw.placeholder_text = "Password, if any"
	_pw.secret = true
	_pw.custom_minimum_size = Vector2(150, 36)
	_pw.text_submitted.connect(func(_t): _direct())
	bot.add_child(_pw)
	bot.add_child(_btn("Connect", _direct, 100))
	var gap2 := Control.new()
	gap2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(gap2)
	bot.add_child(_btn("Host a Battle", func(): host_requested.emit(), 140))
	bot.add_child(_btn("Back", func(): closed.emit(), 100))

	_tick = Timer.new()
	_tick.wait_time = 1.0
	_tick.timeout.connect(_on_tick)
	add_child(_tick)
	visibility_changed.connect(_on_visibility)
	Online.lan_changed.connect(_merge)
	_heads_text()
	_show_detail()
	_on_visibility()


func _btn(text: String, cb: Callable, w := 110.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 36)
	b.pressed.connect(cb)
	return b


func _filter(text: String, set_it: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool):
		set_it.call(on)
		_render())
	return c


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


func _status_line() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var s := ""
	if _fetching and _fetched_at < 0.0:
		s = "Looking for battles..."
	elif _online_err != "":
		s = "Can't reach the matchmaker: showing battles on your network only"
	else:
		var ago := int(now - _fetched_at)
		s = "Updated %s · refreshes by itself" % ("just now" if ago < 2 else "%d s ago" % ago)
	if not _lan_ok:
		s += " · LAN search off (another copy of the game has it)"
	_updated.text = s
	_updated.add_theme_color_override("font_color", UiKit.WARN if _online_err != "" else UiKit.DIM)


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


## [what kind of battle, a detail line]
static func mode_text(e: Dictionary) -> Array:
	var side := clampi(int(e.get("side", 0)), 0, 1)
	var teams: Array = e.get("teams", [0, 0]) if e.get("teams") is Array else [0, 0]
	match String(e.get("mode", "")):
		"coop":
			return ["Co-op vs AI", "as the %s" % Defs.TEAM_NAMES[side]]
		"versus":
			return ["Versus", "%d v %d" % [int(teams[0]) if teams.size() > 0 else 0, int(teams[1]) if teams.size() > 1 else 0]]
		"mission":
			return ["Mission", String(e.get("mission", ""))]
	return ["Battle", ""]


## [text, colour, sort rank]
static func status_of(e: Dictionary) -> Array:
	if int(e.get("players", 0)) >= int(e.get("max_players", 8)):
		return ["Full", UiKit.BAD, 3]
	if not bool(e.get("in_game", false)):
		return ["In the lobby", UiKit.GOOD, 0]
	if bool(e.get("drop_in", true)):
		return ["Running · drop-in", UiKit.ACCENT, 1]
	return ["Running · closed", UiKit.DIM, 2]


## [text, colour, sort rank, what it means]
static func link_of(e: Dictionary) -> Array:
	if bool(e.get("lan", false)):
		return ["LAN", UiKit.INTEL, 0, "On your network: a direct connection."]
	match String(e.get("nat", "unknown")):
		"open":
			return ["Direct", UiKit.GOOD, 1, "The host takes connections directly."]
		"cone":
			return ["Good", UiKit.GOOD, 2, "The game gets you through both routers by hole punching."]
		"strict":
			return ["Strict", UiKit.WARN, 4, "This host's router can't be punched through: you'll only get in if they've forwarded UDP port 7777."]
	return ["Unknown", UiKit.DIM, 3, "The host's router couldn't be checked. It usually works."]


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
		b.text = String(c[1]) + (("  ▼" if _sort_desc else "  ▲") if _sort == String(c[0]) else "")
		b.add_theme_color_override("font_color", UiKit.ACCENT if _sort == String(c[0]) else UiKit.DIM)


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
	_summary.text = "%d battle%s · %d player%s" % [n, "" if n == 1 else "s", players, "" if players == 1 else "s"]
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


func _row(e: Dictionary) -> Button:
	var key := String(e.key)
	var ok := joinable(e)
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 52)
	b.button_pressed = key == _sel
	b.set_meta("key", key)
	var n := UiKit.box(Color(1, 1, 1, 0.025), 3, Color(0, 0, 0, 0), 0, 0.0)
	var h := UiKit.box(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.07), 3, Color(0, 0, 0, 0), 0, 0.0)
	var p := UiKit.box(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.15), 3, UiKit.ACCENT, 0, 0.0)
	p.border_width_left = 3
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var fade := 1.0 if ok else 0.55
	# battle: its name (and a padlock), who hosts it
	var nv := _cell(row, int(COLS[0][2]))
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 6)
	nr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nv.add_child(nr)
	if bool(e.get("locked", false)):
		var lk := LockIcon.new()
		lk.custom_minimum_size = Vector2(12, 14)
		lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lk.modulate.a = fade
		nr.add_child(lk)
	var nm := UiKit.label(String(e.get("name", "Battle")), 15, Color(UiKit.TEXT, fade), 600)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nr.add_child(nm)
	var host := String(e.get("host", ""))
	if bool(e.get("verified", false)):
		host += "  ✓"
	_sub(nv, host, Color(UiKit.DIM, fade))
	# mode
	var mt := mode_text(e)
	var mv := _cell(row, int(COLS[1][2]))
	_main(mv, String(mt[0]), Color(UiKit.TEXT, fade))
	if String(mt[1]) != "":
		_sub(mv, String(mt[1]), Color(UiKit.DIM, fade))
	# players: a count and a bar
	var pv := _cell(row, int(COLS[2][2]))
	var np := int(e.get("players", 0))
	var mp := maxi(1, int(e.get("max_players", 8)))
	_main(pv, "%d / %d" % [np, mp], Color(UiKit.TEXT, fade))
	var bar := Fill.new()
	bar.frac = clampf(float(np) / float(mp), 0.0, 1.0)
	bar.col = UiKit.BAD if np >= mp else UiKit.ACCENT
	bar.custom_minimum_size = Vector2(72, 4)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.modulate.a = fade
	pv.add_child(bar)
	# status, connection
	var st := status_of(e)
	_main(_cell(row, int(COLS[3][2])), String(st[0]), st[1])
	var lk2 := link_of(e)
	var lv := _cell(row, int(COLS[4][2]))
	_main(lv, String(lk2[0]), Color(lk2[1], fade))
	b.tooltip_text = String(lk2[3])
	b.pressed.connect(func(): _select(key))
	b.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb and mb.pressed and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			_select(key)
			_join_selected())
	return b


func _cell(row: HBoxContainer, w: int) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_theme_constant_override("separation", 3)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.clip_contents = true
	_size_cell(c, w)
	row.add_child(c)
	return c


func _main(c: Control, text: String, col: Color) -> void:
	var l := UiKit.label(text, 14, col, 600)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	c.add_child(l)


func _sub(c: Control, text: String, col: Color) -> void:
	var l := UiKit.label(text, 12, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.add_child(l)


func _select(key: String) -> void:
	_sel = key
	for b in _list.get_children():
		if b is Button:
			(b as Button).set_pressed_no_signal(String(b.get_meta("key", "")) == key)
	_show_detail()


# --- the chosen battle -----------------------------------------------------------------------

func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var e := _find(_sel)
	if e.is_empty():
		var l := UiKit.label("Pick a battle to see who's in it.\n\nDouble-click one to join it straight away.", 14, UiKit.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(l)
		_join_btn.disabled = true
		_join_btn.text = "JOIN BATTLE"
		_join_note.text = ""
		return
	var nm := UiKit.label(String(e.get("name", "")), 20, UiKit.TEXT, 600)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(nm)
	var host := "Hosted by %s" % String(e.get("host", "?"))
	var hl := UiKit.label(host + ("  ✓" if bool(e.get("verified", false)) else ""), 13, UiKit.DIM)
	if bool(e.get("verified", false)):
		hl.tooltip_text = "Signed in: this callsign belongs to their account."
		hl.mouse_filter = Control.MOUSE_FILTER_PASS
	_detail.add_child(hl)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	_detail.add_child(chips)
	var st := status_of(e)
	chips.add_child(UiKit.chip(String(st[0]).to_upper(), st[1]))
	if bool(e.get("locked", false)):
		chips.add_child(UiKit.chip("PASSWORD", UiKit.WARN))
	if bool(e.get("lan", false)):
		chips.add_child(UiKit.chip("ON YOUR NETWORK", UiKit.INTEL))
	var mt := mode_text(e)
	_fact("MODE", String(mt[0]) + ("" if String(mt[1]) == "" else " (%s)" % mt[1]))
	# who's on which side, and who the AI is
	var side := clampi(int(e.get("side", -1)), -1, 1)
	var mode := String(e.get("mode", ""))
	var teams: Array = e.get("teams", [0, 0]) if e.get("teams") is Array else [0, 0]
	for t in 2:
		var n := int(teams[t]) if teams.size() > t else 0
		var what := "%d player%s" % [n, "" if n == 1 else "s"]
		if mode in ["coop", "mission"] and side >= 0 and t != side:
			what = "the AI" if mode == "coop" else "the mission's enemy"
		_fact(Defs.TEAM_NAMES[t].to_upper(), what, Defs.TEAM_COLORS[t].lightened(0.3))
	if int(e.get("spectators", 0)) > 0:
		_fact("WATCHING", str(int(e.spectators)))
	var np := int(e.get("players", 0))
	var mp := int(e.get("max_players", 8))
	_fact("SEATS", "%d of %d taken, %d open" % [np, mp, maxi(0, mp - np)])
	var lk := link_of(e)
	_fact("CONNECTION", String(lk[3]), lk[1])
	var age := int(e.get("age", -1))
	if age >= 0:
		_fact("UP FOR", "%d min" % maxi(1, age / 60) if age >= 60 else "under a minute")
	var ok := joinable(e)
	_join_btn.disabled = not ok
	_join_btn.text = ("JOIN WITH PASSWORD" if bool(e.get("locked", false)) else "JOIN BATTLE") if ok else ("FULL" if np >= mp else "CLOSED")
	if not ok:
		_join_note.text = "Every seat is taken." if np >= mp else "The battle is under way and the host isn't letting anyone join mid-battle."
	elif bool(e.get("in_game", false)):
		_join_note.text = "Already under way: you'll drop straight into the fighting."
	else:
		_join_note.text = "You'll wait in the lobby until the host starts."


func _fact(k: String, val: String, col := UiKit.TEXT) -> void:
	var r := VBoxContainer.new()
	r.add_theme_constant_override("separation", 0)
	r.add_child(UiKit.label(k, 10, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.8), 700))
	var l := UiKit.label(val, 13, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(l)
	_detail.add_child(r)


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


## "1.2.3.4", or "1.2.3.4:7790" (which overrides the port box).
func _direct() -> void:
	var a := _addr.text.strip_edges()
	if a == "":
		_addr.grab_focus()
		return
	var port := int(_port.value)
	var parts := a.split(":")
	if parts.size() == 2 and parts[1].is_valid_int():
		a = parts[0]
		port = int(parts[1])
	Sfx.ui("click")
	direct_requested.emit(a, port, _pw.text)


## A padlock: the battle wants a password.
class LockIcon extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var col := UiKit.WARN
		draw_arc(Vector2(w * 0.5, h * 0.45), w * 0.3, PI, TAU, 10, col, 1.6, true)
		draw_line(Vector2(w * 0.2, h * 0.45), Vector2(w * 0.2, h * 0.5), col, 1.6)
		draw_line(Vector2(w * 0.8, h * 0.45), Vector2(w * 0.8, h * 0.5), col, 1.6)
		draw_rect(Rect2(0, h * 0.48, w, h * 0.52), col)


## A thin bar: how full a battle is.
class Fill extends Control:
	var frac := 0.0
	var col := UiKit.ACCENT

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), col)
