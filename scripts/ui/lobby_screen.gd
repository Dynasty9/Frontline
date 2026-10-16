class_name LobbyScreen
extends PanelContainer
## The lobby: who is in the battle and on which side, the seats still open
## and anyone on their way in, who's ready, the battle's settings (the host
## changes them, everyone sees them), the chat, and a link to invite friends.
## A player arriving gets a chime and their row lights up, and a host who has
## alt-tabbed away gets the taskbar flashing.

signal leave_requested

const FLASH_S := 2.5

var _known := {}  # peer ids already in the lobby, to spot arrivals
var _arrived := {}  # peer id -> when they arrived (their row is lit for a moment)
var _fresh := true  # the first update of a lobby (everyone in it is "known")

var _tag: Label
var _title: Label
var _sub: Label
var _chips: HBoxContainer
var _cols: Array = []  # per side: {rows, name, count, note, join}
var _strip_spec: Label
var _spec_btn: Button
var _arr_box: HBoxContainer
var _arr_label: Label
var _chat: RichTextLabel
var _chat_edit: LineEdit
# the settings
var _set_rows := {}  # key -> the row
var _mode_opt: OptionButton
var _mission_label: Label
var _side_opt: OptionButton
var _mood_opt: OptionButton
var _seats_opt: OptionButton
var _fill_chk: CheckBox
var _ally_chk: CheckBox
var _drop_chk: CheckBox
var _list_chk: CheckBox
var _invite_btn: Button
var _invite_note: Label
var _net_note: Label
# the bottom line
var _leave_btn: Button
var _wait_note: Label
var _ready_btn: Button
var _start_btn: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.boxc(Color(0.035, 0.045, 0.045, 0.94), 6, UiKit.LINE, 1, 20.0, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)

	# the battle: what it is, what it's called, who hosts it
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	_tag = UiKit.label("", 13, UiKit.ACCENT, 700)
	tv.add_child(_tag)
	_title = UiKit.label("", 26, UiKit.TEXT, 600)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(_title)
	_sub = UiKit.label("", 13, UiKit.DIM)
	tv.add_child(_sub)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 6)
	_chips.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_chips)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)

	# the two sides
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 12)
	left.add_child(sides)
	for t in 2:
		sides.add_child(_side_column(t))

	# spectators, and players on their way in
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 10)
	left.add_child(strip)
	_strip_spec = UiKit.label("", 13, UiKit.DIM)
	_strip_spec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strip_spec.clip_text = true
	_strip_spec.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	strip.add_child(_strip_spec)
	_arr_box = HBoxContainer.new()
	_arr_box.add_theme_constant_override("separation", 8)
	var sp := JoinDialog.Spinner.new()
	sp.custom_minimum_size = Vector2(16, 16)
	sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_arr_box.add_child(sp)
	_arr_label = UiKit.label("", 13, UiKit.ACCENT, 600)
	_arr_box.add_child(_arr_label)
	strip.add_child(_arr_box)
	_spec_btn = Button.new()
	_spec_btn.custom_minimum_size = Vector2(0, 30)
	_spec_btn.focus_mode = Control.FOCUS_NONE
	_spec_btn.pressed.connect(func(): Sfx.ui("click"); Net.request_team.rpc_id(1, -1 if _my_team() >= 0 else _default_side()))
	strip.add_child(_spec_btn)

	# the chat
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.3), 4, Color(1, 1, 1, 0.06), 1, 10.0))
	cp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(cp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cp.add_child(cv)
	_chat = RichTextLabel.new()
	_chat.bbcode_enabled = true
	_chat.scroll_following = true
	_chat.selection_enabled = true
	_chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat.custom_minimum_size = Vector2(0, 90)
	_chat.add_theme_font_size_override("normal_font_size", 14)
	_chat.add_theme_font_size_override("bold_font_size", 14)
	_chat.add_theme_font_override("bold_font", UiKit.font(700))
	cv.add_child(_chat)
	_chat_edit = LineEdit.new()
	_chat_edit.placeholder_text = "Say something to the lobby (Enter to send)"
	_chat_edit.max_length = 200
	_chat_edit.custom_minimum_size = Vector2(0, 34)
	_chat_edit.text_submitted.connect(func(t: String):
		Net.send_lobby_chat(t)
		_chat_edit.text = "")
	cv.add_child(_chat_edit)

	body.add_child(_settings_panel())

	# leave, and who we're waiting for
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 12)
	v.add_child(bot)
	_leave_btn = Button.new()
	_leave_btn.custom_minimum_size = Vector2(130, 44)
	_leave_btn.pressed.connect(func():
		for b: Button in [_leave_btn, _start_btn, _ready_btn]:
			b.disabled = true
		leave_requested.emit())
	bot.add_child(_leave_btn)
	_wait_note = UiKit.label("", 14, UiKit.DIM)
	_wait_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wait_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wait_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wait_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot.add_child(_wait_note)
	_ready_btn = Button.new()
	_ready_btn.toggle_mode = true
	_ready_btn.focus_mode = Control.FOCUS_NONE
	_ready_btn.custom_minimum_size = Vector2(240, 44)
	_ready_btn.add_theme_font_override("font", UiKit.font(700))
	_ready_btn.add_theme_font_size_override("font_size", 16)
	var rp := UiKit.box(Color(UiKit.GOOD.r, UiKit.GOOD.g, UiKit.GOOD.b, 0.2), 5, UiKit.GOOD, 2, 6.0)
	_ready_btn.add_theme_stylebox_override("pressed", rp)
	_ready_btn.add_theme_stylebox_override("hover_pressed", rp)
	_ready_btn.add_theme_color_override("font_pressed_color", UiKit.GOOD)
	_ready_btn.add_theme_color_override("font_hover_pressed_color", UiKit.GOOD)
	_ready_btn.toggled.connect(func(on: bool): Sfx.ui("click"); Net.set_ready.rpc_id(1, on))
	bot.add_child(_ready_btn)
	_start_btn = UiKit.primary_button("START BATTLE", 240, 44, 17)
	_start_btn.pressed.connect(func(): Sfx.ui("click"); Net.start_game())
	bot.add_child(_start_btn)

	Net.lobby_updated.connect(refresh)
	Net.lobby_chat.connect(_on_chat)
	Online.listing_changed.connect(refresh)


func _side_column(t: int) -> Control:
	var tc: Color = Defs.TEAM_COLORS[t]
	var p := PanelContainer.new()
	var sb := UiKit.box(Color(tc.r, tc.g, tc.b, 0.06), 4, Color(tc.r, tc.g, tc.b, 0.35), 1, 12.0)
	sb.border_width_top = 3
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 236)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var nm := UiKit.label(Defs.TEAM_NAMES[t].to_upper(), 17, tc.lightened(0.3), 700)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nm)
	var count := UiKit.label("", 11, UiKit.DIM, 700)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(count)
	var note := UiKit.label("", 12, UiKit.DIM)
	v.add_child(note)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(rows)
	var join := Button.new()
	join.text = "Join the %s" % Defs.TEAM_NAMES[t]
	join.focus_mode = Control.FOCUS_NONE
	join.custom_minimum_size = Vector2(0, 32)
	join.pressed.connect(func(): Sfx.ui("click"); Net.request_team.rpc_id(1, t))
	v.add_child(join)
	_cols.append({"rows": rows, "count": count, "note": note, "join": join})
	return p


func _settings_panel() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.25), 4, Color(1, 1, 1, 0.05), 1, 16.0))
	p.custom_minimum_size = Vector2(340, 0)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(UiKit.label("BATTLE SETTINGS", 12, UiKit.ACCENT, 700))
	_mode_opt = OptionButton.new()
	_mode_opt.add_item("Co-op vs AI", 0)
	_mode_opt.add_item("Versus", 1)
	_mode_opt.item_selected.connect(func(i: int): Net.set_setting("mode", "coop" if i == 0 else "versus"))
	_set_row(v, "mode", "Mode", _mode_opt)
	_mission_label = UiKit.label("", 14, UiKit.TEXT, 600)
	_set_row(v, "mission", "Mission", _mission_label)
	_side_opt = OptionButton.new()
	for t in 2:
		_side_opt.add_item(Defs.TEAM_NAMES[t], t)
	_side_opt.item_selected.connect(func(i: int): Net.set_setting("coop_side", i))
	_set_row(v, "side", "Players' side", _side_opt)
	_mood_opt = OptionButton.new()
	for i in SettingsPanel.MOODS.size():
		_mood_opt.add_item(SettingsPanel.MOOD_NAMES[i], i)
	_mood_opt.item_selected.connect(func(i: int): Net.set_setting("mood", SettingsPanel.MOODS[i]))
	_set_row(v, "mood", "Time of day", _mood_opt)
	_seats_opt = OptionButton.new()
	for n in range(2, Net.MAX_PLAYERS + 1):
		_seats_opt.add_item("%d players" % n, n)
	_seats_opt.item_selected.connect(func(i: int): Net.set_setting("max_players", _seats_opt.get_item_id(i)))
	_set_row(v, "seats", "Seats", _seats_opt)
	_fill_chk = _check(v, "fill", "AI takes a side nobody plays", func(on: bool): Net.set_setting("ai_fill", on))
	_ally_chk = _check(v, "ally", "AI commands alongside players", func(on: bool): Net.set_setting("ai_allies", on))
	_drop_chk = _check(v, "drop", "Players can join mid-battle", func(on: bool): Net.set_setting("drop_in", on))
	_list_chk = _check(v, "list", "Listed in the server browser", func(on: bool):
		if on:
			Online.list_game()
		else:
			Online.unlist())
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.07)
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	v.add_child(UiKit.label("INVITE FRIENDS", 12, UiKit.ACCENT, 700))
	_invite_btn = Button.new()
	_invite_btn.text = "Copy invite link"
	_invite_btn.custom_minimum_size = Vector2(0, 34)
	_invite_btn.pressed.connect(_copy_invite)
	v.add_child(_invite_btn)
	_invite_note = UiKit.label("", 12, UiKit.DIM)
	_invite_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_invite_note)
	_net_note = UiKit.label("", 12, UiKit.DIM)
	_net_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_net_note)
	return p


func _set_row(v: VBoxContainer, key: String, label: String, w: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UiKit.label(label, 13, UiKit.DIM)
	l.custom_minimum_size = Vector2(108, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.custom_minimum_size.y = maxf(w.custom_minimum_size.y, 30)
	h.add_child(w)
	v.add_child(h)
	_set_rows[key] = h


func _check(v: VBoxContainer, key: String, text: String, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	v.add_child(c)
	_set_rows[key] = c
	return c


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
			_tag.text = "CO-OP VS AI  ·  %s" % Defs.TEAM_NAMES[locked].to_upper()
		"mission":
			_tag.text = "MISSION  ·  %s" % String(Missions.find(mk).title).to_upper()
		_:
			_tag.text = "VERSUS"
	_title.text = Net.battle_name()
	var host_name := String(Net.players[1].name) if Net.players.has(1) else "the host"
	_sub.text = "You are hosting this battle" if host else "Hosted by %s  ·  waiting in the lobby" % host_name
	for c in _chips.get_children():
		c.queue_free()
	var n := Net.players.size()
	var seats := Net.max_players()
	var open := maxi(0, seats - n)
	_chips.add_child(UiKit.chip("%d / %d PLAYERS" % [n, seats], UiKit.ACCENT))
	_chips.add_child(UiKit.chip(("%d OPEN SEAT%s" % [open, "" if open == 1 else "S"]) if open > 0 else "FULL", UiKit.GOOD if open > 0 else UiKit.BAD))
	if bool(s.get("locked", false)):
		_chips.add_child(UiKit.chip("PASSWORD", UiKit.WARN))
	if host and Online.hosting():
		var ls: Array = Online.listing_status()
		_chips.add_child(UiKit.chip(String(ls[0]), UiKit.INTEL if bool(ls[2]) else UiKit.BAD))

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
		if String(ai[t]) != "":
			rows.add_child(_ai_row(String(ai[t])))
		if players_here and open > 0:
			# the seats left: a row each on the players' side (the last row
			# counting the rest), or a count when they can sit on either side
			if locked < 0:
				rows.add_child(_open_row("%d open seat%s, on either side" % [open, "" if open == 1 else "s"]))
			else:
				var show := mini(open, 3)
				for i in show:
					var rest := open - i
					rows.add_child(_open_row("%d more open seats" % rest if i == show - 1 and rest > 1 else "Open seat"))
		(col.count as Label).text = "%d PLAYER%s" % [ids.size(), "" if ids.size() == 1 else "S"]
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
	_strip_spec.text = ("Watching: %s" % ", ".join(names)) if not names.is_empty() else "Nobody watching"
	_arr_box.visible = Net.arriving > 0
	_arr_label.text = "%d player%s connecting..." % [Net.arriving, "" if Net.arriving == 1 else "s"]
	_spec_btn.text = "Watch instead" if _my_team() >= 0 else "Play instead"
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
	_leave_btn.text = "Close lobby" if host else "Leave"
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


## Which sides the AI will command once the battle starts (the host's rules
## in Net.start_game), and how: "" for none.
func _ai_sides(mode: String, locked: int, on_side: Array) -> Array:
	var out := ["", ""]
	if mode == "mission":
		out[1 - locked] = "Mission enemy forces"
		return out
	var fill := mode == "coop" or bool(Net.settings.get("ai_fill", true))
	var allies := bool(Net.settings.get("ai_allies", false))
	for t in 2:
		var humans := not (on_side[t] as Array).is_empty()
		if mode == "coop" and t != locked:
			out[t] = "AI commander"
		elif not humans and fill and (mode != "coop"):
			out[t] = "AI commander (nobody on this side)"
		elif humans and allies:
			out[t] = "AI commander, alongside the players"
	return out


func _player_row(id: int, p: Dictionary, host: bool, now: float) -> Control:
	var me := id == multiplayer.get_unique_id()
	var row := PanelContainer.new()
	var bg := UiKit.box(Color(1, 1, 1, 0.04) if not me else Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.07), 3, Color(0, 0, 0, 0), 0, 6.0)
	bg.content_margin_left = 10
	bg.content_margin_right = 6
	row.add_theme_stylebox_override("panel", bg)
	row.custom_minimum_size = Vector2(0, 36)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	var ready := id == 1 or bool(p.get("ready", false))
	var dot := Dot.new()
	dot.on = ready
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	var nm := UiKit.label(String(p.name), 15, UiKit.TEXT, 600)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(nm)
	if id == 1:
		h.add_child(_tag_chip("HOST", UiKit.ACCENT))
	if me:
		h.add_child(_tag_chip("YOU", UiKit.INTEL))
	var st := UiKit.label("HOSTING" if id == 1 else ("READY" if ready else "NOT READY"), 11, UiKit.GOOD if ready else UiKit.DIM, 700)
	st.custom_minimum_size = Vector2(74, 0)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(st)
	if host and id != 1:
		var k := Button.new()
		k.text = "×"
		k.flat = true
		k.focus_mode = Control.FOCUS_NONE
		k.tooltip_text = "Remove %s from the battle" % String(p.name)
		k.custom_minimum_size = Vector2(26, 26)
		k.add_theme_font_size_override("font_size", 18)
		k.add_theme_color_override("font_color", UiKit.DIM)
		k.add_theme_color_override("font_hover_color", UiKit.BAD)
		k.pressed.connect(func(): Net.kick(id))
		h.add_child(k)
	# just arrived: lit up, fading back over a couple of seconds
	var t0 := float(_arrived.get(id, -100.0))
	if now - t0 < FLASH_S:
		var lit := 1.0 - (now - t0) / FLASH_S
		var hb: StyleBoxFlat = bg.duplicate()
		var base := bg.bg_color
		hb.bg_color = base.lerp(Color(UiKit.GOOD.r, UiKit.GOOD.g, UiKit.GOOD.b, 0.3), lit)
		row.add_theme_stylebox_override("panel", hb)
		var tw := row.create_tween()
		tw.tween_property(hb, "bg_color", base, FLASH_S * lit)
	return row


func _tag_chip(text: String, col: Color) -> Control:
	var c := UiKit.chip(text, col)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


func _ai_row(text: String) -> Control:
	var row := PanelContainer.new()
	var bg := UiKit.box(Color(1, 1, 1, 0.02), 3, Color(1, 1, 1, 0.06), 1, 6.0)
	bg.content_margin_left = 10
	row.add_theme_stylebox_override("panel", bg)
	row.custom_minimum_size = Vector2(0, 36)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	var ic := UiKit.label("AI", 11, UiKit.INTEL, 700)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UiKit.label(text, 14, Color(0.75, 0.78, 0.74))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return row


func _open_row(text: String) -> Control:
	var row := PanelContainer.new()
	var bg := UiKit.box(Color(0, 0, 0, 0), 3, Color(1, 1, 1, 0.1), 1, 6.0)
	bg.content_margin_left = 10
	row.add_theme_stylebox_override("panel", bg)
	row.custom_minimum_size = Vector2(0, 32)
	var l := UiKit.label(text, 13, Color(0.6, 0.62, 0.57, 0.8))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


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
	_mission_label.text = String(Missions.find(mk).title) if mission else ""
	_mode_opt.select(0 if mode == "coop" else 1)
	(_set_rows.side as Control).visible = mode == "coop"
	_side_opt.select(clampi(int(s.get("coop_side", 0)), 0, 1))
	(_set_rows.mood as Control).visible = not mission
	var mood := String(s.get("mood", Settings.get_v("mood") if host else "random"))
	_mood_opt.select(maxi(0, SettingsPanel.MOODS.find(mood)))
	var seats := Net.max_players()
	for i in _seats_opt.item_count:
		var n := _seats_opt.get_item_id(i)
		_seats_opt.set_item_disabled(i, n < Net.players.size())
		if n == seats:
			_seats_opt.select(i)
	_fill_chk.visible = mode == "versus"
	_fill_chk.set_pressed_no_signal(bool(s.get("ai_fill", true)))
	_ally_chk.visible = not mission
	_ally_chk.set_pressed_no_signal(bool(s.get("ai_allies", false)))
	_drop_chk.set_pressed_no_signal(bool(s.get("drop_in", true)))
	_list_chk.visible = host and Online.hosting()
	_list_chk.set_pressed_no_signal(Online.want_listed)
	for w: Control in [_mode_opt, _side_opt, _mood_opt, _seats_opt]:
		(w as OptionButton).disabled = not host
	for c: CheckBox in [_fill_chk, _ally_chk, _drop_chk]:
		c.disabled = not host


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
	_invite_btn.text = "Copied: paste it to a friend"
	get_tree().create_timer(2.5).timeout.connect(func():
		if is_instance_valid(_invite_btn):
			_invite_btn.text = "Copy invite link")


func _on_chat(text: String, system: bool) -> void:
	var safe := text.replace("[", "[lb]")
	if system:
		_chat.append_text("[color=#%s]» %s[/color]\n" % [UiKit.INTEL.darkened(0.15).to_html(false), safe])
		return
	var i := safe.find(": ")
	if i > 0:
		_chat.append_text("[b]%s[/b]%s\n" % [safe.substr(0, i), safe.substr(i)])
	else:
		_chat.append_text(safe + "\n")


## Ready or not, as a dot: filled green, or an empty ring.
class Dot extends Control:
	var on := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		if on:
			draw_circle(c, r, UiKit.GOOD)
		else:
			draw_arc(c, r - 0.75, 0.0, TAU, 16, UiKit.DIM, 1.5, true)
