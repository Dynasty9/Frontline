class_name LobbyScreen
extends PanelContainer
## The lobby: who is in the battle and on which side, the seats still open
## and anyone on their way in, who's ready, the battle's settings (the host
## changes them, everyone sees them), the chat, and a link to invite friends.
## A player arriving gets a chime and their row lights up, and a host who has
## alt-tabbed away gets the taskbar flashing.
## Signal (docs/UI.md): each side is a list on the sheet's ink under its
## marker, a seat to a ruled row with its states as mono codes; the settings
## are rows of a label and a control (the host's) or a code (everyone else's);
## the chat reads as a log.

signal leave_requested

const FLASH_S := 2.5
const ROW_H := 34

var _known := {}  # peer ids already in the lobby, to spot arrivals
var _arrived := {}  # peer id -> when they arrived (their row is lit for a moment)
var _fresh := true  # the first update of a lobby (everyone in it is "known")

var _tag: Label
var _title: Label
var _sub: Label
var _figs: HBoxContainer
var _cols: Array = []  # per side: {rows, count, note, join}
var _strip_spec: Label
var _spec_btn: Button
var _arr_box: HBoxContainer
var _arr_label: Label
var _chat: RichTextLabel
var _chat_edit: LineEdit
# the settings
var _set_rows := {}  # key -> the row
var _set_codes := {}  # key -> the value as a code (what everyone but the host sees)
var _mode_seg: UiSeg
var _mission_label: Label
var _side_seg: UiSeg
var _mood_opt: OptionButton
var _seats_seg: UiSeg
var _fill_seg: UiSeg
var _ally_seg: UiSeg
var _drop_seg: UiSeg
var _list_seg: UiSeg
var _invite_btn: Button
var _invite_note: Label
var _net_note: Label
# the bottom line
var _leave_btn: Button
var _wait_note: Label
var _ready_btn: Button
var _start_btn: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.frame(Color(-1, 0, 0), 22.0, 0.0, 14.0, 0.93))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)

	# the battle: what it is, what it's called, who hosts it, and its figures
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	v.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	_tag = UiKit.caps("", 11, UiKit.DIM)
	tv.add_child(_tag)
	_title = UiKit.caps("", 22, UiKit.TEXT, 600, 1)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(_title)
	_sub = UiKit.label("", 13, UiKit.FAINT)
	tv.add_child(_sub)
	_figs = HBoxContainer.new()
	_figs.add_theme_constant_override("separation", 22)
	_figs.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_figs)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The roster and settings may be taller than a short window. Keep the
	# Leave / Ready / Start line outside the scrolling part.
	UiKit.scroll_content(v, body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)

	# the two sides
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 28)
	sides.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sides)
	for t in 2:
		sides.add_child(_side_column(t))

	# spectators, and players on their way in
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 10)
	left.add_child(strip)
	var wl := UiKit.caps("Watching", 11, UiKit.FAINT)
	wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.add_child(wl)
	_strip_spec = UiKit.caps("", 12, UiKit.DIM)
	_strip_spec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strip_spec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_strip_spec.clip_text = true
	_strip_spec.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	strip.add_child(_strip_spec)
	_arr_box = HBoxContainer.new()
	_arr_box.add_theme_constant_override("separation", 8)
	var sp := JoinDialog.Spinner.new()
	sp.custom_minimum_size = Vector2(12, 12)
	sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_arr_box.add_child(sp)
	_arr_label = UiKit.mono_label("", 12, UiKit.ACCENT)
	_arr_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_arr_box.add_child(_arr_label)
	strip.add_child(_arr_box)
	_spec_btn = UiKit.button("", "secondary", 0, 28)
	_spec_btn.pressed.connect(func(): Sfx.ui("click"); Net.request_team.rpc_id(1, -1 if _my_team() >= 0 else _default_side()))
	strip.add_child(_spec_btn)

	# the chat, as a log: the time, who, what they said, and a line to type on
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	cv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(cv)
	cv.add_child(UiKit.header("Chat"))
	_chat = RichTextLabel.new()
	_chat.scroll_following = true
	_chat.selection_enabled = true
	_chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat.custom_minimum_size = Vector2(0, 90)
	_chat.add_theme_font_size_override("normal_font_size", 13)
	_chat.add_theme_constant_override("line_separation", 5)
	cv.add_child(_chat)
	_chat_edit = LineEdit.new()
	_chat_edit.placeholder_text = "Say something to the lobby (Enter to send)"
	_chat_edit.max_length = 200
	_chat_edit.custom_minimum_size = Vector2(0, 30)
	_chat_edit.text_submitted.connect(func(t: String):
		Net.send_lobby_chat(t)
		_chat_edit.text = "")
	cv.add_child(_chat_edit)

	body.add_child(VSeparator.new())
	body.add_child(_settings_panel())

	# leave, and who we're waiting for
	var rule := ColorRect.new()
	rule.color = UiKit.LINE
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rule)
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 14)
	v.add_child(bot)
	_leave_btn = UiKit.button("", "secondary", 140, 40)
	_leave_btn.pressed.connect(func():
		for b: Button in [_leave_btn, _start_btn, _ready_btn]:
			b.disabled = true
		leave_requested.emit())
	bot.add_child(_leave_btn)
	_wait_note = UiKit.label("", 13, UiKit.DIM)
	_wait_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wait_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wait_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wait_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot.add_child(_wait_note)
	# Ready is a player's one primary action: filled until pressed, then a
	# green outline saying they are
	_ready_btn = UiKit.primary_button("I'm ready", 240, 40, 15)
	_ready_btn.toggle_mode = true
	var rp := UiKit.box(UiKit.fa(UiKit.GOOD, 0.1), 0, UiKit.GOOD, 1, 6.0)
	_ready_btn.add_theme_stylebox_override("pressed", rp)
	_ready_btn.add_theme_stylebox_override("hover_pressed", rp)
	_ready_btn.add_theme_color_override("font_pressed_color", UiKit.GOOD)
	_ready_btn.add_theme_color_override("font_hover_pressed_color", UiKit.GOOD)
	_ready_btn.toggled.connect(func(on: bool): Sfx.ui("click"); Net.set_ready.rpc_id(1, on))
	bot.add_child(_ready_btn)
	_start_btn = UiKit.primary_button("Start battle", 240, 40, 15)
	_start_btn.pressed.connect(func(): Sfx.ui("click"); Net.start_game())
	bot.add_child(_start_btn)

	Net.lobby_updated.connect(refresh)
	Net.lobby_chat.connect(_on_chat)
	Online.listing_changed.connect(refresh)


## A side: its marker (a square in its colour, its name, how many are on it,
## a rule running on), what it is this battle, and its seats.
func _side_column(t: int) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size = Vector2(0, 220)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.custom_minimum_size = Vector2(0, 26)
	v.add_child(h)
	var sq := Mark.new()
	sq.col = Defs.TEAM_COLORS[t]
	sq.custom_minimum_size = Vector2(10, 10)
	sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sq)
	var nm := UiKit.caps(Defs.TEAM_NAMES[t], 15, UiKit.TEXT, 600, 2)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nm)
	var count := UiKit.mono_label("", 12, UiKit.DIM)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(count)
	var r := ColorRect.new()
	r.color = UiKit.LINE
	r.custom_minimum_size = Vector2(8, 1)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(r)
	var note := UiKit.label("", 12, UiKit.FAINT)
	note.custom_minimum_size = Vector2(0, 24)
	note.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	v.add_child(note)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	# A full co-op side must not push its Join button and the lobby footer
	# off screen. Only the roster scrolls; the side action stays beneath it.
	var roster := UiKit.scroll_content(v, rows)
	roster.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var jm := MarginContainer.new()
	jm.add_theme_constant_override("margin_top", 10)
	v.add_child(jm)
	var join := UiKit.button("Join the %s" % Defs.TEAM_NAMES[t], "secondary", 200, 30)
	join.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	join.pressed.connect(func(): Sfx.ui("click"); Net.request_team.rpc_id(1, t))
	jm.add_child(join)
	_cols.append({"rows": rows, "count": count, "note": note, "join": join})
	return v


func _settings_panel() -> Control:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(390, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var hd := UiKit.header("Battle settings")
	hd.custom_minimum_size = Vector2(0, 26)
	v.add_child(hd)
	_mode_seg = UiSeg.make(["Co-op vs AI", "Versus"], 1)
	_mode_seg.changed.connect(func(i: int): Net.set_setting("mode", "coop" if i == 0 else "versus"))
	_set_row(v, "mode", "Mode", _mode_seg)
	_mission_label = UiKit.mono_label("", 12, UiKit.TEXT)
	_set_row(v, "mission", "Mission", _mission_label)
	_side_seg = UiSeg.make([Defs.TEAM_NAMES[0], Defs.TEAM_NAMES[1]], 0)
	_side_seg.changed.connect(func(i: int): Net.set_setting("coop_side", i))
	_set_row(v, "side", "Players' side", _side_seg)
	_mood_opt = OptionButton.new()
	for i in SettingsPanel.MOODS.size():
		_mood_opt.add_item(SettingsPanel.MOOD_NAMES[i], i)
	_mood_opt.custom_minimum_size = Vector2(200, 26)
	_mood_opt.item_selected.connect(func(i: int): Net.set_setting("mood", SettingsPanel.MOODS[i]))
	_set_row(v, "mood", "Time of day", _mood_opt)
	var seats: Array = []
	for n in range(2, Net.MAX_PLAYERS + 1):
		seats.append(str(n))
	_seats_seg = UiSeg.make(seats, seats.size() - 1)
	_seats_seg.changed.connect(func(i: int): Net.set_setting("max_players", 2 + i))
	_set_row(v, "seats", "Seats", _seats_seg)
	_fill_seg = _switch(v, "fill", "AI fills empty side", "The AI takes a side nobody plays.", func(on: bool): Net.set_setting("ai_fill", on))
	_ally_seg = _switch(v, "ally", "AI with the players", "An AI commander fights alongside the players too.", func(on: bool): Net.set_setting("ai_allies", on))
	_drop_seg = _switch(v, "drop", "Join mid-battle", "Players can join a battle that's already under way.", func(on: bool): Net.set_setting("drop_in", on))
	_list_seg = _switch(v, "list", "Listed online", "In the server browser, for anyone to find.", func(on: bool):
		if on:
			Online.list_game()
		else:
			Online.unlist())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	v.add_child(gap)
	var ih := UiKit.header("Invite friends")
	ih.custom_minimum_size = Vector2(0, 26)
	v.add_child(ih)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 8)
	v.add_child(iv)
	_invite_btn = UiKit.button("Copy invite link", "secondary", 0, 30)
	_invite_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_invite_btn.pressed.connect(_copy_invite)
	iv.add_child(_invite_btn)
	_invite_note = UiKit.label("", 12, UiKit.FAINT)
	_invite_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(_invite_note)
	_net_note = UiKit.label("", 12, UiKit.DIM)
	_net_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(_net_note)
	return sc


## A ruled row of the settings: its name in faint capitals, then the host's
## control, or for everyone else the value as a code (a label is its own code).
func _set_row(v: VBoxContainer, key: String, label: String, w: Control) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _rule_box(Color(0, 0, 0, 0)))
	p.custom_minimum_size = Vector2(0, ROW_H)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var l := UiKit.caps(label, 11, UiKit.FAINT)
	l.custom_minimum_size = Vector2(130, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(w)
	if not (w is Label):
		var code := UiKit.mono_label("", 12, UiKit.TEXT)
		code.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(code)
		_set_codes[key] = code
	v.add_child(p)
	_set_rows[key] = p


## An on/off setting: OFF | ON, what it means in the tooltip.
func _switch(v: VBoxContainer, key: String, label: String, tip: String, cb: Callable) -> UiSeg:
	var s := UiSeg.make(["Off", "On"], 0)
	s.set_tooltip(tip)
	s.changed.connect(func(i: int): cb.call(i == 1))
	_set_row(v, key, label, s)
	(_set_rows[key] as Control).tooltip_text = tip
	return s


## A row's box: clear, with a rule along its foot.
func _rule_box(bg: Color) -> StyleBoxFlat:
	var sb := UiKit.box(bg, 0, UiKit.LINE, 0, 0.0)
	sb.border_width_bottom = 1
	sb.content_margin_left = 6
	sb.content_margin_right = 4
	return sb


## A new lobby: no chat from the last one, and nobody known yet.
func reset() -> void:
	_chat.clear()
	_known.clear()
	_arrived.clear()
	_fresh = true
	_ready_btn.set_pressed_no_signal(false)
	for b: Button in [_leave_btn, _start_btn, _ready_btn]:
		b.disabled = false
	refresh()


func _my_team() -> int:
	var me: Dictionary = Net.players.get(multiplayer.get_unique_id(), {})
	return int(me.get("team", -1)) if not me.is_empty() else -1


func _default_side() -> int:
	return Net.locked_side() if Net.locked_side() >= 0 else 0


func refresh() -> void:
	if not is_visible_in_tree() or Net.in_game:
		return
	var host := multiplayer.is_server()
	var me := multiplayer.get_unique_id()
	var s := Net.settings
	var mk := String(s.get("mission", ""))
	var mode := "mission" if mk != "" else String(s.get("mode", "versus"))
	var locked := Net.locked_side()
	var now := Time.get_ticks_msec() / 1000.0
	_spot_arrivals(now)

	# the header
	match mode:
		"coop":
			_tag.text = "Co-op vs AI  ·  %s" % Defs.TEAM_NAMES[locked]
		"mission":
			_tag.text = "Mission  ·  %s" % String(MissionList.find(mk).title)
		_:
			_tag.text = "Versus"
	_title.text = Net.battle_name()
	var host_name := String(Net.players[1].name) if Net.players.has(1) else "the host"
	_sub.text = "You are hosting this battle" if host else "Hosted by %s  ·  waiting in the lobby" % host_name
	for c in _figs.get_children():
		c.queue_free()
	var n := Net.players.size()
	var seats := Net.max_players()
	var open := maxi(0, seats - n)
	_fig("Players", "%d/%d" % [n, seats], UiKit.TEXT)
	_fig("Open", str(open) if open > 0 else "FULL", UiKit.TEXT if open > 0 else UiKit.BAD)
	if bool(s.get("locked", false)):
		_fig("Access", "PASSWORD", UiKit.WARN)
	if host and Online.hosting():
		var ls: Array = Online.listing_status()
		_fig("", String(ls[0]), UiKit.INTEL if bool(ls[2]) else UiKit.BAD)

	# the sides
	var on_side := [[], []]
	var specs: Array = []
	for id in Net.players:
		var t := int(Net.players[id].team)
		if t >= 0:
			on_side[t].append(id)
		else:
			specs.append(id)
	var ai := _ai_sides(mode, locked, on_side)
	for t in 2:
		var col: Dictionary = _cols[t]
		var rows: VBoxContainer = col.rows
		for c in rows.get_children():
			c.queue_free()
		var ids: Array = on_side[t]
		ids.sort()
		for id in ids:
			rows.add_child(_player_row(int(id), Net.players[id], host, now))
		var players_here := locked < 0 or locked == t
		if not (ai[t] as Array).is_empty():
			rows.add_child(_ai_row(ai[t]))
		if players_here and open > 0:
			# the seats left: a row each on the players' side (the last row
			# counting the rest), or a count when they can sit on either side
			if locked < 0:
				rows.add_child(_open_row("Open seats", "Either side", "%d OPEN" % open))
			else:
				var show := mini(open, 3)
				for i in show:
					var rest := open - i
					rows.add_child(_open_row("Open seats", "", "%d MORE" % rest) if i == show - 1 and rest > 1 else _open_row("Open seat", "", "OPEN"))
		# how many are on it: of the seats, where they're all on this side
		(col.count as Label).text = ("%d/%d" % [ids.size(), seats]) if locked == t else ("AI" if not players_here else str(ids.size()))
		var note := ""
		if mode == "coop":
			note = "The players' side" if t == locked else "Commanded by the AI"
		elif mode == "mission":
			note = "Your force" if t == locked else "The mission's enemy"
		else:
			note = "Pick a side: friends on the same one play co-op"
		(col.note as Label).text = note
		var jb: Button = col.join
		jb.visible = players_here and _my_team() != t and not Net.players.get(me, {}).is_empty()
		jb.disabled = false

	# spectators, arrivals
	var names: Array = []
	for id in specs:
		names.append(String(Net.players[id].name) + (" (you)" if id == me else ""))
	_strip_spec.text = ", ".join(names) if not names.is_empty() else "Nobody"
	_strip_spec.add_theme_color_override("font_color", UiKit.DIM if not names.is_empty() else UiKit.FAINT)
	_arr_box.visible = Net.arriving > 0
	_arr_label.text = "%d CONNECTING" % Net.arriving
	_spec_btn.text = "WATCH INSTEAD" if _my_team() >= 0 else "PLAY INSTEAD"
	_spec_btn.visible = not Net.players.get(me, {}).is_empty()

	_refresh_settings(host, mode, mk)
	_refresh_invite(host)

	# ready, start, leave
	var waiting: Array = []
	var others := 0
	for id in Net.players:
		if int(id) == 1:
			continue
		others += 1
		if not bool(Net.players[id].get("ready", false)):
			waiting.append(String(Net.players[id].name))
	_start_btn.visible = host
	_ready_btn.visible = not host
	_start_btn.text = "START MISSION" if mode == "mission" else "START BATTLE"
	_leave_btn.text = "CLOSE LOBBY" if host else "LEAVE"
	_leave_btn.tooltip_text = "Closes the battle for everyone in it." if host else ""
	var mine: Dictionary = Net.players.get(me, {})
	_ready_btn.set_pressed_no_signal(bool(mine.get("ready", false)))
	_ready_btn.text = "READY  ✓" if _ready_btn.button_pressed else "I'M READY"
	if host:
		if others == 0:
			_wait_note.text = "Just you so far. Invite friends, or start now: the AI fills in."
		elif waiting.is_empty():
			_wait_note.text = "Everyone's ready."
			_wait_note.add_theme_color_override("font_color", UiKit.GOOD)
		else:
			_wait_note.text = "Waiting on %s (you can start anyway)." % ", ".join(waiting)
		if others == 0 or not waiting.is_empty():
			_wait_note.add_theme_color_override("font_color", UiKit.DIM)
	else:
		_wait_note.text = "Waiting for %s to start the battle." % host_name if _ready_btn.button_pressed else "Press Ready when you're set."
		_wait_note.add_theme_color_override("font_color", UiKit.DIM)


## A figure in the header: its name in faint capitals, its value as a code.
func _fig(label: String, val: String, col: Color) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if label != "":
		var l := UiKit.caps(label, 11, UiKit.FAINT)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
	var vl := UiKit.mono_label(val, 15, col)
	vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(vl)
	_figs.add_child(h)


## Which sides the AI will command once the battle starts (the host's rules
## in Net.start_game), and how: [name, note], or [] for none.
func _ai_sides(mode: String, locked: int, on_side: Array) -> Array:
	var out := [[], []]
	if mode == "mission":
		out[1 - locked] = ["Mission enemy", ""]
		return out
	var fill := mode == "coop" or bool(Net.settings.get("ai_fill", true))
	var allies := bool(Net.settings.get("ai_allies", false))
	for t in 2:
		var humans := not (on_side[t] as Array).is_empty()
		if mode == "coop" and t != locked:
			out[t] = ["AI commander", ""]
		elif not humans and fill and (mode != "coop"):
			out[t] = ["AI commander", "Nobody on this side"]
		elif humans and allies:
			out[t] = ["AI commander", "Alongside the players"]
	return out


func _player_row(id: int, p: Dictionary, host: bool, now: float) -> Control:
	var me := id == multiplayer.get_unique_id()
	var row := PanelContainer.new()
	var bg := _rule_box(Color(0, 0, 0, 0))
	row.add_theme_stylebox_override("panel", bg)
	row.tooltip_text = "%s's colour in the battle: their cursor, view and pings on teammates' screens." % String(p.name)
	row.custom_minimum_size = Vector2(0, ROW_H)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	# their colour in the battle (cursor, view and pings on teammates'
	# screens), as the row's marker
	var sq := Mark.new()
	sq.col = Net.player_color(id)
	sq.custom_minimum_size = Vector2(8, 8)
	sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sq)
	# the insignia they wear, and their rank (signed-in players)
	var pic := String(p.get("icon", ""))
	if pic != "":
		var tr := TextureRect.new()
		tr.texture = Insignia.texture(pic, 128)
		tr.custom_minimum_size = Vector2(22, 22)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.mouse_filter = Control.MOUSE_FILTER_PASS
		tr.tooltip_text = "%s, rank %d. Wearing %s." % [Insignia.rank_name(int(p.get("rank", 0))), int(p.get("rank", 0)), String(Insignia.find(pic).get("n", ""))]
		h.add_child(tr)
	var nm := UiKit.caps(String(p.name), 13, UiKit.TEXT, 600, 1)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nm)
	# who they are and whether they're set, as codes (the host is always set)
	if id == 1:
		_code(h, "HOST", UiKit.DIM)
	if me:
		_code(h, "YOU", UiKit.ACCENT)
	if id != 1:
		var ready := bool(p.get("ready", false))
		_code(h, "READY" if ready else "NOT READY", UiKit.GOOD if ready else UiKit.FAINT)
	if host and id != 1:
		var k := UiKit.button("×", "quiet", 22, 22)
		k.tooltip_text = "Remove %s from the battle" % String(p.name)
		k.add_theme_font_override("font", UiKit.mono(400))
		k.add_theme_font_size_override("font_size", 15)
		k.add_theme_color_override("font_hover_color", UiKit.BAD)
		k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		k.pressed.connect(func(): Net.kick(id))
		h.add_child(k)
	# just arrived: the row lit (flickering on), then cut back
	var t0 := float(_arrived.get(id, -100.0))
	if now - t0 < FLASH_S:
		row.add_theme_stylebox_override("panel", _rule_box(UiKit.fa(UiKit.GOOD, 0.14)))
		var tw := row.create_tween()
		tw.tween_interval(FLASH_S - (now - t0))
		tw.tween_callback(func(): row.add_theme_stylebox_override("panel", bg))
		if now - t0 < 0.1:
			UiMotion.flicker(row, 2)
	return row


func _code(h: HBoxContainer, text: String, col: Color) -> void:
	var l := UiKit.mono_label(text, 11, col)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)


## A seat that isn't a player's: its marker, a name in capitals, a faint note
## and a code at the end.
func _seat_row(mark: Mark, name_text: String, name_col: Color, note: String, code: String, code_col: Color) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _rule_box(Color(0, 0, 0, 0)))
	row.custom_minimum_size = Vector2(0, ROW_H)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	mark.custom_minimum_size = Vector2(8, 8)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(mark)
	var nm := UiKit.caps(name_text, 13, name_col, 600, 1)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nm)
	var nl := UiKit.caps(note, 11, UiKit.FAINT)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nl)
	_code(h, code, code_col)
	return row


## [name, note]
func _ai_row(ai: Array) -> Control:
	var m := Mark.new()
	m.col = UiKit.INTEL
	m.hollow = true
	return _seat_row(m, String(ai[0]), UiKit.DIM, String(ai[1]), "AI", UiKit.INTEL)


func _open_row(text: String, note: String, code: String) -> Control:
	var m := Mark.new()
	m.col = UiKit.RULE2
	m.hollow = true
	return _seat_row(m, text, UiKit.FAINT, note, code, UiKit.FAINT)


## New faces since the last update: a chime, their row lit, and the taskbar
## flashing if the game isn't in front.
func _spot_arrivals(now: float) -> void:
	var me := multiplayer.get_unique_id()
	var fresh := false
	for id in Net.players:
		if not _known.has(id):
			if not _fresh and id != me:
				_arrived[id] = now
				fresh = true
			_known[id] = true
	for id in _known.keys():
		if not Net.players.has(id):
			_known.erase(id)
	_fresh = false
	if fresh:
		Sfx.ui("objective")
		if DisplayServer.get_name() != "headless" and not get_window().has_focus():
			DisplayServer.window_request_attention()


func _refresh_settings(host: bool, mode: String, mk: String) -> void:
	var s := Net.settings
	var mission := mode == "mission"
	(_set_rows.mode as Control).visible = not mission
	(_set_rows.mission as Control).visible = mission
	_mission_label.text = String(MissionList.find(mk).title).to_upper() if mission else ""
	_mode_seg.select(0 if mode == "coop" else 1)
	(_set_codes.mode as Label).text = "CO-OP VS AI" if mode == "coop" else "VERSUS"
	(_set_rows.side as Control).visible = mode == "coop"
	var side := clampi(int(s.get("coop_side", 0)), 0, 1)
	_side_seg.select(side)
	(_set_codes.side as Label).text = Defs.TEAM_NAMES[side].to_upper()
	(_set_rows.mood as Control).visible = not mission
	var mood := String(s.get("mood", Settings.get_v("mood") if host else "random"))
	var mi := maxi(0, SettingsPanel.MOODS.find(mood))
	_mood_opt.select(mi)
	(_set_codes.mood as Label).text = String(SettingsPanel.MOOD_NAMES[mi]).to_upper()
	var seats := Net.max_players()
	for i in Net.MAX_PLAYERS - 1:
		_seats_seg.set_disabled(i, 2 + i < Net.players.size())
	_seats_seg.select(seats - 2)
	(_set_codes.seats as Label).text = str(seats)
	(_set_rows.fill as Control).visible = mode == "versus"
	_on_off("fill", _fill_seg, bool(s.get("ai_fill", true)))
	(_set_rows.ally as Control).visible = not mission
	_on_off("ally", _ally_seg, bool(s.get("ai_allies", false)))
	_on_off("drop", _drop_seg, bool(s.get("drop_in", true)))
	(_set_rows.list as Control).visible = host and Online.hosting()
	_on_off("list", _list_seg, Online.want_listed)
	# the host changes them; everyone else reads them
	for key in _set_codes:
		var row: Control = _set_rows[key]
		var h: HBoxContainer = row.get_child(0)
		h.get_child(1).visible = host
		(_set_codes[key] as Label).visible = not host


func _on_off(key: String, seg: UiSeg, on: bool) -> void:
	seg.select(1 if on else 0)
	(_set_codes[key] as Label).text = "ON" if on else "OFF"


func _refresh_invite(host: bool) -> void:
	var link := _invite_link()
	_invite_btn.visible = link != ""
	var locked := bool(Net.settings.get("locked", false))
	var pw := " Tell them the password too." if locked else ""
	if link != "":
		_invite_note.text = "A friend who opens it gets this battle's page on the Frontline website, where Join starts the game and brings them here. It's in the server browser too.%s" % pw
	elif host:
		var lan := Online.lan_ip()
		var pub := Online.public_address()
		var port := Online.hosted_port() if Online.hosted_port() > 0 else Net.DEFAULT_PORT
		var t := "Not listed online, so there's no link to send. Players on your network see the battle in their server browser."
		if lan != "":
			t += " By address: %s on your network" % lan
			t += (", or %s from outside with UDP port %d forwarded." % [pub, port]) if pub != "" else "."
		_invite_note.text = t + pw
	else:
		_invite_note.text = "This battle isn't listed online: friends need the host's address to join."
	_net_note.visible = host and Online.hosting()
	_net_note.text = Online.router_text() if host else ""
	var ls: Array = Online.listing_status() if host and Online.hosting() else []
	if not ls.is_empty() and not bool(ls[2]):
		_net_note.text = String(ls[1]) + " " + _net_note.text
		_net_note.add_theme_color_override("font_color", UiKit.BAD)
	else:
		_net_note.add_theme_color_override("font_color", UiKit.WARN if Online.nat == "strict" else UiKit.DIM)


## The website's page for this battle ("" while it isn't listed). The host
## knows its listing; everyone else hears its id in the lobby settings.
func _invite_link() -> String:
	if multiplayer.is_server():
		return Online.invite_link()
	var id := String(Net.settings.get("invite", ""))
	return "" if id == "" else "%s/?join=%s" % [Updater.WEBSITE_URL, id]


func _copy_invite() -> void:
	var link := _invite_link()
	if link == "":
		return
	DisplayServer.clipboard_set(link)
	Sfx.ui("click")
	_invite_btn.text = "COPIED: PASTE IT TO A FRIEND"
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(_invite_btn):
			_invite_btn.text = "COPY INVITE LINK")


## A line of the log: the time in mono, who said it in capitals, what they
## said as prose (the lobby's own news in the intel colour).
func _on_chat(text: String, system: bool) -> void:
	var tm := Time.get_time_string_from_system().substr(0, 5)
	_chat.push_font(UiKit.mono(400), 12)
	_chat.push_color(UiKit.FAINT)
	_chat.add_text(tm + "   ")
	_chat.pop()
	_chat.pop()
	var i := text.find(": ")
	if system:
		_chat.push_color(UiKit.INTEL)
		_chat.add_text(text)
		_chat.pop()
	elif i > 0:
		_chat.push_font(UiKit.cond(600, 1), 13)
		_chat.push_color(UiKit.DIM)
		_chat.add_text(text.substr(0, i).to_upper() + "   ")
		_chat.pop()
		_chat.pop()
		_chat.add_text(text.substr(i + 2))
	else:
		_chat.add_text(text)
	_chat.newline()


## A seat's marker: a small square, filled in a colour (a side, a player), or
## an outline (the AI, a seat still open).
class Mark extends Control:
	var col := Color.WHITE
	var hollow := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if hollow:
			draw_rect(r.grow(-0.5), col, false, 1.0)
		else:
			draw_rect(r, col)
