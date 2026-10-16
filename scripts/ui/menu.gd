extends Control
## Main menu and multiplayer lobby.

var name_edit: LineEdit
var ip_edit: LineEdit
var port_spin: SpinBox
var status: Label
var main_box: VBoxContainer
var lobby_box: VBoxContainer
var player_list: VBoxContainer
var team_opt: OptionButton
var ai_check: CheckBox
var ally_check: CheckBox
var drop_check: CheckBox
var start_btn: Button
var lobby_title: Label
var chat_log: RichTextLabel
var chat_edit: LineEdit


var join_row: HBoxContainer
var settings_panel: SettingsPanel
var manual: FieldManual
var backdrop: MenuScene
var op_panel: PanelContainer
var ms_panel: PanelContainer  # the missions
var _ms_key := ""
var _ms_cards := {}
var _ms_detail: VBoxContainer
var _op_side := 0  # 0 Coalition, 1 Rebels, -1 observe
var _side_cards := {}
var _mood_chips := {}
var _col: VBoxContainer
var hint: Label  # the networking hint, shown in the lobby
# online: the list of battles, the account, and the lobby's listing
var browse_panel: PanelContainer
var browse_list: VBoxContainer
var browse_msg: Label
var _browse_n := 0  # the latest refresh (an older answer arriving late is dropped)
var account_panel: PanelContainer
var acct_email: LineEdit
var acct_pass: LineEdit
var acct_callsign: LineEdit
var acct_msg: Label
var acct_btns: Array[Button] = []
var acct_btn: Button  # Sign in / Sign out, beside the callsign
var acct_tag: Label
var list_check: CheckBox
var online_label: Label
var _mm_busy := false  # Find Match is working through battles
var _mm_tries: Array = []  # lobby ids it has tried this time
var _mm_attempt := 0  # bumps with every join attempt, so stale timeouts do nothing

const SIDES := [
	[0, "COALITION", "A regular army. Tanks, IFVs, Humvees, attack helicopters, air strikes and artillery. Fewer men, better kit, long supply lines."],
	[1, "REBELS", "An insurgent militia. Technicals, BTRs, RPGs, FPV drones and tunnels under the town. Cheap, many and hard to pin down."],
	[-1, "OBSERVE", "Two AI commanders fight it out. The director camera finds the action; take the camera any time."],
]
const MOODS := [["random", "Random"], ["dawn", "Dawn"], ["day", "Midday"], ["golden", "Golden hour"], ["dusk", "Dusk"], ["overcast", "Overcast"], ["hazy", "Hazy"], ["rain", "Rain"], ["night", "Night"]]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	visibility_changed.connect(_on_visibility)
	# darkening on the left so the menu reads over the 3D backdrop
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.02, 0.025, 0.02, 0.88), Color(0.02, 0.025, 0.02, 0.55), Color(0.02, 0.025, 0.02, 0.0)])
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_bottom = 1.0
	shade.offset_right = 760
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.anchor_bottom = 1.0
	margin.offset_right = 600
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	_col = col
	# the emblem and the wordmark, as on the splash
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)
	var em := Emblem.new()
	em.custom_minimum_size = Vector2(56, 56)
	em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(em)
	var fv := FontVariation.new()
	fv.base_font = UiKit.font(700)
	fv.spacing_glyph = 9
	var title := Label.new()
	title.text = "FRONTLINE"
	title.add_theme_font_override("font", fv)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	head.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.7)
	rule.custom_minimum_size = Vector2(470, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(rule)
	var tag := UiKit.label("SQUAD TACTICS  \u00b7  COMBINED ARMS  \u00b7  COMMAND", 13, UiKit.ACCENT, 700)
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	col.add_child(gap)

	# main screen: grouped entries, each saying what it does
	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 4)
	main_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(main_box)
	main_box.add_child(_section("COMMAND"))
	main_box.add_child(_big("Play vs AI", "Command one side against the AI commander", func(): _open_op(0)))
	main_box.add_child(_big("Missions", "Short operations with objectives, alone or in co-op", _open_missions))
	main_box.add_child(_big("Watch AI Battle", "Two AI commanders fight; the camera finds the action", func(): _open_op(-1)))
	main_box.add_child(_section("MULTIPLAYER"))
	main_box.add_child(_big("Find Match", "Join an open battle online, or host one for others to find", _find_match))
	main_box.add_child(_big("Host Multiplayer", "Co-op against the AI, or player against player", _host))
	main_box.add_child(_big("Join Game", "Browse the battles being hosted, or connect by address", _open_browser))
	main_box.add_child(_section("REFERENCE"))
	main_box.add_child(_big("Field Manual", "Every soldier, weapon, vehicle and work, with its numbers", func(): manual.visible = true))
	main_box.add_child(_big("Settings", "Graphics, display, interface and sound", func(): settings_panel.visible = true))
	main_box.add_child(_big("Quit", "Back to the desktop", func(): get_tree().quit()))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	main_box.add_child(gap2)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 8)
	who.add_child(_make_name_edit())
	acct_btn = _btn("Sign in", func():
		if Online.signed_in():
			Online.sign_out()
			_say("Signed out. You can still play online under any callsign.")
		else:
			_open_account())
	acct_btn.custom_minimum_size = Vector2(96, 34)
	who.add_child(acct_btn)
	acct_tag = UiKit.label("ACCOUNT", 11, UiKit.GOOD, 700)
	acct_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(acct_tag)
	main_box.add_child(_row("Callsign", who))

	# lobby
	lobby_box = VBoxContainer.new()
	lobby_box.add_theme_constant_override("separation", 10)
	lobby_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lobby_box.visible = false
	col.add_child(lobby_box)
	lobby_title = UiKit.label("", 22, UiKit.TEXT, 600)
	lobby_box.add_child(lobby_title)
	player_list = VBoxContainer.new()
	lobby_box.add_child(player_list)
	team_opt = OptionButton.new()
	team_opt.add_item("Coalition", 0)
	team_opt.add_item("Rebels", 1)
	team_opt.add_item("Spectator", 2)
	team_opt.custom_minimum_size = Vector2(200, 32)
	team_opt.item_selected.connect(func(i): Net.request_team.rpc_id(1, i if i < 2 else -1))
	lobby_box.add_child(_row("Your side", team_opt))
	ai_check = CheckBox.new()
	ai_check.text = "Fill an empty side with the AI"
	ai_check.button_pressed = true
	ai_check.toggled.connect(func(v): Net.set_setting("ai_fill", v))
	lobby_box.add_child(ai_check)
	ally_check = CheckBox.new()
	ally_check.text = "Add an AI commander to sides that have players"
	ally_check.toggled.connect(func(v): Net.set_setting("ai_allies", v))
	lobby_box.add_child(ally_check)
	drop_check = CheckBox.new()
	drop_check.text = "Let friends join while the battle is running"
	drop_check.button_pressed = true
	drop_check.toggled.connect(func(v): Net.set_setting("drop_in", v))
	lobby_box.add_child(drop_check)
	list_check = CheckBox.new()
	list_check.text = "List online, so Find Match can bring players here"
	list_check.toggled.connect(_on_list_toggled)
	lobby_box.add_child(list_check)
	online_label = UiKit.label("", 12, UiKit.DIM)
	online_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	online_label.custom_minimum_size = Vector2(460, 0)
	lobby_box.add_child(online_label)
	var chat_panel := PanelContainer.new()
	chat_panel.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.35), 6, UiKit.LINE, 1, 8.0))
	lobby_box.add_child(chat_panel)
	chat_log = RichTextLabel.new()
	chat_log.custom_minimum_size = Vector2(460, 110)
	chat_log.scroll_following = true
	chat_panel.add_child(chat_log)
	chat_edit = LineEdit.new()
	chat_edit.placeholder_text = "Say something..."
	chat_edit.text_submitted.connect(func(t): Net.send_lobby_chat(t); chat_edit.text = "")
	lobby_box.add_child(chat_edit)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	start_btn = _btn("Start Battle", func(): Net.start_game())
	start_btn.custom_minimum_size = Vector2(260, 40)
	brow.add_child(start_btn)
	brow.add_child(_btn("Leave", func(): Net.leave(); show_menu("")))
	lobby_box.add_child(brow)

	status = UiKit.label("", 14, UiKit.BAD)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(460, 0)
	col.add_child(status)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	hint = UiKit.label("Co-op: everyone picks the same side. Friends can also join by your address: forward UDP port %d, or play on a LAN or VPN." % Net.DEFAULT_PORT, 12, Color(0.75, 0.75, 0.7, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(460, 0)
	hint.visible = false
	col.add_child(hint)

	settings_panel = SettingsPanel.new()
	settings_panel.visible = false
	settings_panel.closed.connect(func(): settings_panel.visible = false)
	add_child(settings_panel)
	UiKit.fit_center(settings_panel, Vector2(700, 600))
	manual = FieldManual.new()
	manual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	manual.offset_left = 40
	manual.offset_right = -40
	manual.offset_top = 36
	manual.offset_bottom = -36
	manual.visible = false
	manual.closed.connect(func(): manual.visible = false)
	add_child(manual)

	_build_op_panel()
	_build_mission_panel()
	_build_browse_panel()
	_build_account_panel()
	var build := ("ALPHA V%s" % Updater.version) if Updater.is_release() else "DEV BUILD"
	var foot := UiKit.label("%s  \u00b7  GODOT %s  \u00b7  F4 FIELD MANUAL IN BATTLE" % [build, Engine.get_version_info().string.to_upper()], 11, Color(0.75, 0.75, 0.7, 0.45), 600)
	foot.anchor_left = 1.0
	foot.anchor_right = 1.0
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = -560
	foot.offset_right = -32
	foot.offset_top = -40
	foot.offset_bottom = -20
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(foot)

	Net.lobby_updated.connect(_refresh)
	Net.lobby_chat.connect(func(t): chat_log.append_text(t + "\n"))
	multiplayer.connected_to_server.connect(func(): _show_lobby())
	Online.listing_changed.connect(_refresh)
	Online.account_changed.connect(_on_account)
	Updater.changed.connect(_update_notice)
	_update_notice()
	_on_account()
	# a Join or Find Match link from the website: the one we were started with,
	# and any a second copy hands on while we run
	Links.link_opened.connect(open_link)
	if Links.pending != "":
		open_link.call_deferred(Links.pending)
		Links.pending = ""
	_on_visibility()


func _on_visibility() -> void:
	if is_visible_in_tree() and backdrop == null:
		backdrop = MenuScene.new()
		get_tree().root.add_child.call_deferred(backdrop)
	elif not is_visible_in_tree() and backdrop != null:
		backdrop.queue_free()
		backdrop = null


## A menu entry: the name and, under it, what it does. Hover slides in an
## accent bar.
func _big(text: String, sub: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = ""
	b.custom_minimum_size = Vector2(420, 54 if sub != "" else 44)
	b.focus_mode = Control.FOCUS_NONE
	var n := UiKit.box(Color(0, 0, 0, 0.0), 2, Color(0, 0, 0, 0), 0, 0.0)
	var h := UiKit.box(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.12), 2, UiKit.ACCENT, 0, 0.0)
	h.border_width_left = 3
	var pr := h.duplicate() as StyleBoxFlat
	pr.bg_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.22)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var l := UiKit.label(text, 21, Color(0.94, 0.93, 0.88), 600)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	if sub != "":
		var s := UiKit.label(sub, 12, Color(0.7, 0.71, 0.66), 400)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(s)
	b.mouse_entered.connect(func():
		l.add_theme_color_override("font_color", UiKit.ACCENT)
		create_tween().tween_property(v, "offset_left", 26.0, 0.12))
	b.mouse_exited.connect(func():
		l.add_theme_color_override("font_color", Color(0.94, 0.93, 0.88))
		create_tween().tween_property(v, "offset_left", 18.0, 0.12))
	b.pressed.connect(func(): Sfx.ui("click"); cb.call())
	return b


func _section(text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.custom_minimum_size = Vector2(0, 30)
	var l := UiKit.label(text, 11, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.8), 700)
	l.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(l)
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.08)
	r.custom_minimum_size = Vector2(320, 1)
	r.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(r)
	return h


# --- new operation -----------------------------------------------------------------------

## The operation panel: which side (or just watch) and the time of day.
func _build_op_panel() -> void:
	op_panel = _side_panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	op_panel.add_child(v)
	v.add_child(UiKit.label("NEW OPERATION", 13, UiKit.ACCENT, 700))
	v.add_child(UiKit.label("Choose your side", 24, UiKit.TEXT, 600))
	for sd in SIDES:
		var card := Button.new()
		card.toggle_mode = true
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(0, 86)
		var tc: Color = Defs.TEAM_COLORS[sd[0]] if int(sd[0]) >= 0 else UiKit.ACCENT
		var cn := UiKit.box(Color(1, 1, 1, 0.03), 4, Color(1, 1, 1, 0.07), 1, 0.0)
		var ch := UiKit.box(Color(tc.r, tc.g, tc.b, 0.08), 4, Color(tc.r, tc.g, tc.b, 0.5), 1, 0.0)
		var cp := UiKit.box(Color(tc.r, tc.g, tc.b, 0.14), 4, tc, 2, 0.0)
		cp.border_width_left = 4
		card.add_theme_stylebox_override("normal", cn)
		card.add_theme_stylebox_override("hover", ch)
		card.add_theme_stylebox_override("pressed", cp)
		card.add_theme_stylebox_override("hover_pressed", cp)
		var cv := VBoxContainer.new()
		cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cv.offset_left = 18
		cv.offset_right = -14
		cv.offset_top = 10
		cv.offset_bottom = -8
		cv.add_theme_constant_override("separation", 3)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cv)
		var nm := UiKit.label(String(sd[1]), 17, tc.lightened(0.25), 700)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(nm)
		var ds := UiKit.label(String(sd[2]), 13, Color(0.82, 0.82, 0.78))
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(ds)
		var sv: int = sd[0]
		card.pressed.connect(func(): _pick_side(sv))
		v.add_child(card)
		_side_cards[sv] = card
	v.add_child(UiKit.label("Time of day", 15, UiKit.DIM, 600))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	for m in MOODS:
		var c := Button.new()
		c.text = String(m[1])
		c.toggle_mode = true
		c.focus_mode = Control.FOCUS_NONE
		c.custom_minimum_size = Vector2(0, 30)
		var mk: String = m[0]
		c.pressed.connect(func(): _pick_mood(mk))
		flow.add_child(c)
		_mood_chips[mk] = c
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var go := Button.new()
	go.text = "DEPLOY"
	go.custom_minimum_size = Vector2(220, 44)
	go.add_theme_font_override("font", UiKit.font(700))
	go.add_theme_font_size_override("font_size", 17)
	var gn := UiKit.box(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.85), 4, UiKit.ACCENT, 0, 0.0)
	var gh := UiKit.box(UiKit.ACCENT.lightened(0.15), 4, UiKit.ACCENT, 0, 0.0)
	go.add_theme_stylebox_override("normal", gn)
	go.add_theme_stylebox_override("hover", gh)
	go.add_theme_stylebox_override("pressed", gh)
	go.add_theme_color_override("font_color", Color(0.08, 0.07, 0.05))
	go.add_theme_color_override("font_hover_color", Color(0.05, 0.04, 0.03))
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func(): Sfx.ui("click"); _deploy())
	row.add_child(go)
	row.add_child(_btn("Back", func(): op_panel.visible = false))


## The panels on the right of the menu take turns: opening one closes the rest.
func _close_panels() -> void:
	for p: Control in [op_panel, ms_panel, browse_panel, account_panel]:
		if p:
			p.visible = false


func _open_op(side: int) -> void:
	_close_panels()
	_pick_side(side)
	_pick_mood(String(Settings.get_v("mood")))
	op_panel.visible = true
	op_panel.modulate.a = 0.0
	op_panel.offset_left = 670
	var tw := create_tween().set_parallel(true)
	tw.tween_property(op_panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(op_panel, "offset_left", 640.0, 0.18)


func _pick_side(side: int) -> void:
	_op_side = side
	for k in _side_cards:
		(_side_cards[k] as Button).set_pressed_no_signal(k == side)


func _pick_mood(m: String) -> void:
	if not _mood_chips.has(m):
		m = "random"
	Settings.set_v("mood", m)
	for k in _mood_chips:
		(_mood_chips[k] as Button).set_pressed_no_signal(k == m)


func _deploy() -> void:
	op_panel.visible = false
	if _op_side < 0:
		_observe()
	else:
		_single_player(_op_side)


func _unhandled_input(ev: InputEvent) -> void:
	if not (visible and ev is InputEventKey and ev.pressed and (ev as InputEventKey).keycode == KEY_ESCAPE):
		return
	for p: Control in [account_panel, browse_panel, ms_panel, op_panel]:
		if p and p.visible:
			p.visible = false
			get_viewport().set_input_as_handled()
			return


# --- missions ------------------------------------------------------------------------------

## The missions: a card for each, the chosen one's briefing, and play it
## alone or host it for friends.
func _build_mission_panel() -> void:
	ms_panel = PanelContainer.new()
	ms_panel.add_theme_stylebox_override("panel", UiKit.boxc(Color(0.035, 0.045, 0.045, 0.92), 6, UiKit.LINE, 1, 22.0, 10))
	ms_panel.anchor_top = 0.5
	ms_panel.anchor_bottom = 0.5
	ms_panel.offset_left = 640
	ms_panel.offset_right = 1260
	ms_panel.offset_top = -320
	ms_panel.offset_bottom = 330
	ms_panel.visible = false
	add_child(ms_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	ms_panel.add_child(v)
	v.add_child(UiKit.label("MISSIONS", 13, UiKit.ACCENT, 700))
	v.add_child(UiKit.label("Short operations, about five minutes each", 22, UiKit.TEXT, 600))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	v.add_child(list)
	for m in Missions.playable():
		var card := Button.new()
		card.toggle_mode = true
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(0, 52)
		var tc: Color = Defs.TEAM_COLORS[int(m.side)]
		card.add_theme_stylebox_override("normal", UiKit.box(Color(1, 1, 1, 0.03), 4, Color(1, 1, 1, 0.07), 1, 0.0))
		card.add_theme_stylebox_override("hover", UiKit.box(Color(tc.r, tc.g, tc.b, 0.08), 4, Color(tc.r, tc.g, tc.b, 0.5), 1, 0.0))
		var cp := UiKit.box(Color(tc.r, tc.g, tc.b, 0.14), 4, tc, 2, 0.0)
		cp.border_width_left = 4
		card.add_theme_stylebox_override("pressed", cp)
		card.add_theme_stylebox_override("hover_pressed", cp)
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 16
		row.offset_right = -14
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 0)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cv)
		var nm := UiKit.label(String(m.title), 17, Color(0.94, 0.93, 0.88), 700)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(nm)
		var op := UiKit.label(String(m.op).to_upper(), 10, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.75), 700)
		op.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(op)
		var tag := UiKit.label("%s  \u00b7  %d MIN" % [Defs.TEAM_NAMES[int(m.side)].to_upper(), int(m.mins)], 11, tc.lightened(0.3), 700)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tag)
		var key: String = m.key
		card.pressed.connect(func(): _pick_mission(key))
		list.add_child(card)
		_ms_cards[key] = card
	# the chosen mission's briefing
	var det := PanelContainer.new()
	det.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.28), 4, Color(1, 1, 1, 0.05), 1, 14.0))
	det.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(det)
	_ms_detail = VBoxContainer.new()
	_ms_detail.add_theme_constant_override("separation", 6)
	det.add_child(_ms_detail)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	v.add_child(row2)
	var go := Button.new()
	go.text = "PLAY SOLO"
	go.custom_minimum_size = Vector2(200, 44)
	go.add_theme_font_override("font", UiKit.font(700))
	go.add_theme_font_size_override("font_size", 16)
	go.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.85), 4, UiKit.ACCENT, 0, 0.0))
	go.add_theme_stylebox_override("hover", UiKit.box(UiKit.ACCENT.lightened(0.15), 4, UiKit.ACCENT, 0, 0.0))
	go.add_theme_stylebox_override("pressed", UiKit.box(UiKit.ACCENT.lightened(0.15), 4, UiKit.ACCENT, 0, 0.0))
	go.add_theme_color_override("font_color", Color(0.08, 0.07, 0.05))
	go.add_theme_color_override("font_hover_color", Color(0.05, 0.04, 0.03))
	go.focus_mode = Control.FOCUS_NONE
	go.pressed.connect(func(): Sfx.ui("click"); _mission_solo())
	row2.add_child(go)
	var co := _btn("Host Co-op", func(): Sfx.ui("click"); _mission_coop())
	co.custom_minimum_size = Vector2(150, 44)
	co.tooltip_text = "Open a lobby for this mission: friends join with Join Game and share your force."
	row2.add_child(co)
	row2.add_child(_btn("Back", func(): ms_panel.visible = false))


func _open_missions() -> void:
	_close_panels()
	if _ms_key == "":
		_ms_key = String(Missions.playable()[0].key)
	_pick_mission(_ms_key)
	ms_panel.visible = true
	ms_panel.modulate.a = 0.0
	ms_panel.offset_left = 670
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ms_panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(ms_panel, "offset_left", 640.0, 0.18)


func _pick_mission(key: String) -> void:
	_ms_key = key
	for k in _ms_cards:
		(_ms_cards[k] as Button).set_pressed_no_signal(k == key)
	for c in _ms_detail.get_children():
		c.queue_free()
	var m := Missions.find(key)
	var bl := UiKit.label(String(m.blurb), 15, UiKit.TEXT, 600)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ms_detail.add_child(bl)
	var br := UiKit.label(String(m.brief), 13, Color(0.8, 0.81, 0.77))
	br.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ms_detail.add_child(br)
	for kv in [["FORCE", m.force], ["AREA", m.area], ["CONDITIONS", Curtain.MOOD_TEXT.get(String(m.mood), "")]]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		var k := UiKit.label(String(kv[0]), 11, Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.85), 700)
		k.custom_minimum_size = Vector2(96, 0)
		r.add_child(k)
		var val := UiKit.label(String(kv[1]), 13, Color(0.88, 0.88, 0.84))
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(val)
		_ms_detail.add_child(r)


func _mission_solo() -> void:
	var m := Missions.find(_ms_key)
	ms_panel.visible = false
	var port := int(port_spin.value)
	var err := ERR_CANT_CREATE
	for i in 5:
		err = Net.host_game(port + i, int(m.side))
		if err == OK:
			break
	if err != OK:
		status.text = "Could not start the mission (error %d)." % err
		return
	Net.set_setting("mission", _ms_key)
	Net.start_game()


func _mission_coop() -> void:
	var m := Missions.find(_ms_key)
	ms_panel.visible = false
	var err := Net.host_game(int(port_spin.value), int(m.side))
	if err != OK:
		status.text = "Could not host on port %d (error %d). Is it already in use?" % [int(port_spin.value), err]
		return
	Net.set_setting("mission", _ms_key)
	_show_lobby()


## The emblem from the splash: the triangle with the red dot.
class Emblem extends Control:
	func _draw() -> void:
		var s := minf(size.x, size.y) * 0.5
		var c := size * 0.5
		var pts := PackedVector2Array([c + Vector2(-s, s * 0.78), c + Vector2(0, -s * 0.82), c + Vector2(s, s * 0.78), c + Vector2(-s, s * 0.78)])
		draw_polyline(pts, Color(0.87, 0.8, 0.63), maxf(2.5, s * 0.13), true)
		draw_circle(c + Vector2(0, s * 0.2), s * 0.2, Color(0.84, 0.32, 0.24))


func _make_name_edit() -> LineEdit:
	name_edit = LineEdit.new()
	name_edit.text = Net.my_name
	name_edit.max_length = 20
	name_edit.custom_minimum_size = Vector2(240, 34)
	name_edit.text_changed.connect(func(t): Net.my_name = t if t.strip_edges() != "" else "Commander")
	# signed in, the callsign belongs to the account: changing it here renames it
	name_edit.text_submitted.connect(func(_t): _rename())
	name_edit.focus_exited.connect(_rename)
	return name_edit


func _rename() -> void:
	var want := name_edit.text.strip_edges()
	if not Online.signed_in() or want == Online.callsign or want == "":
		return
	_say("Renaming...")
	var r: Dictionary = await Online.rename(want)
	if r.ok:
		_say("You are now %s." % Online.callsign)
	else:
		name_edit.text = Online.callsign
		Net.my_name = Online.callsign
		_say(String(r.error), true)


func _row(label: String, w: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := UiKit.label(label, 14, UiKit.DIM)
	l.custom_minimum_size = Vector2(110, 0)
	h.add_child(l)
	h.add_child(w)
	return h


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 36)
	b.pressed.connect(cb)
	return b


func show_menu(msg: String) -> void:
	visible = true
	main_box.visible = true
	lobby_box.visible = false
	hint.visible = false
	if _mm_busy and msg != "":
		# that battle wouldn't take us: Find Match tries the next
		_mm_next.call_deferred()
		return
	_say(msg, true)


## A line under the menu: progress in the normal colour, problems in red.
func _say(msg: String, bad := false) -> void:
	status.text = msg
	status.add_theme_color_override("font_color", UiKit.BAD if bad else UiKit.DIM)


func _show_lobby() -> void:
	_mm_busy = false
	_mm_attempt += 1
	main_box.visible = false
	lobby_box.visible = true
	hint.visible = true
	browse_panel.visible = false
	status.text = ""
	_refresh()


func _single_player(side := 0) -> void:
	var port := int(port_spin.value)
	var err := ERR_CANT_CREATE
	for i in 5:
		err = Net.host_game(port + i, side)
		if err == OK:
			break
	if err != OK:
		status.text = "Could not start a local game (error %d)." % err
		return
	Net.set_setting("ai_fill", true)
	Net.start_game()


func _observe() -> void:
	var port := int(port_spin.value)
	var err := ERR_CANT_CREATE
	for i in 5:
		err = Net.host_game(port + i, -1)
		if err == OK:
			break
	if err != OK:
		status.text = "Could not start (error %d)." % err
		return
	Net.set_setting("ai_fill", true)
	Net.start_game()


## Host, listed online (untick it in the lobby to keep the battle to friends
## who have your address).
func _host() -> void:
	var port := int(port_spin.value)
	_say("Setting up the battle...")
	var err: int = await Online.host(port)
	if err != OK:
		_say("Could not host on port %d (error %d). Is it already in use?" % [port, err], true)
		return
	_show_lobby()


func _join() -> void:
	_mm_busy = false
	browse_panel.visible = false
	var err := Net.join_game(ip_edit.text.strip_edges(), int(port_spin.value))
	if err != OK:
		_say("Could not connect (error %d)." % err, true)
		return
	_say("Connecting to %s..." % ip_edit.text)


func _on_list_toggled(on: bool) -> void:
	if on:
		Online.list_game()
	else:
		Online.unlist()


# --- Find Match -----------------------------------------------------------------------

## Join the best open battle online, or if there is none, host one for others
## to find. Pressed again while it's looking, it stops.
func _find_match() -> void:
	if _mm_busy:
		_mm_busy = false
		_mm_attempt += 1
		Net.leave()
		_say("Stopped looking.")
		return
	_mm_busy = true
	_mm_tries.clear()
	_mm_next()


## One step of Find Match: ask the matchmaker for the best battle we haven't
## tried and join it. When there's none left (or a few hosts' routers wouldn't
## let us through) host one instead and wait to be found.
func _mm_next() -> void:
	if not _mm_busy:
		return
	_mm_attempt += 1
	var attempt := _mm_attempt
	_say("Looking for a battle...")
	var r: Dictionary = await Online.find_match(_mm_tries)
	if not _mm_busy or attempt != _mm_attempt:
		return
	if not r.ok:
		_mm_busy = false
		_say("%s Host a battle, or join one by address." % r.error, true)
		return
	var l: Variant = r.data.get("lobby")
	if not (l is Dictionary) or _mm_tries.size() >= 4:
		_mm_busy = false
		_say("No open battles. Hosting one for others to find...")
		_host()
		return
	_mm_tries.append(String(l.id))
	_say("Joining %s..." % String(l.name))
	var j: Dictionary = await Online.join_listed(String(l.id))
	if not _mm_busy or attempt != _mm_attempt:
		return
	if int(j.err) != OK:
		_mm_next()
		return
	_watch_connect(attempt, String(l.host))


## ENet takes a long while to give up on a host it can't reach. If we're not
## through in a few seconds, punching didn't work: drop it and move on.
func _watch_connect(attempt: int, host_name: String) -> void:
	await get_tree().create_timer(12.0, true, false, true).timeout
	if attempt != _mm_attempt or lobby_box.visible or Net.in_game:
		return
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return
	Net.leave()
	if _mm_busy:
		_mm_next()
	else:
		_say("Couldn't get through to %s's router. Try another battle." % host_name, true)


# --- a newer release -------------------------------------------------------------------

## The update notice in the corner: a newer release downloading, installed
## and waiting for a restart, or (where the game can't update itself) a link
## to the downloads. Playing online needs the same version as everyone else,
## so it's worth the space.
func _update_notice() -> void:
	var old := get_node_or_null("UpdateNotice")
	if old:
		old.queue_free()
	if Updater.state == Updater.State.NONE:
		return
	var p := PanelContainer.new()
	p.name = "UpdateNotice"
	var bad: bool = Updater.state == Updater.State.FAILED
	p.add_theme_stylebox_override("panel", UiKit.box(Color(0.035, 0.045, 0.045, 0.92), 4, UiKit.BAD if bad else UiKit.ACCENT, 1, 12.0))
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -440
	p.offset_right = -32
	p.offset_top = 44
	add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var head := UiKit.label("", 11, UiKit.BAD if bad else UiKit.ACCENT, 700)
	v.add_child(head)
	var line := UiKit.label("", 14, UiKit.TEXT, 600)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(line)
	var website := func(): OS.shell_open(Updater.WEBSITE_URL + "/#download")
	match Updater.state:
		Updater.State.AVAILABLE:
			head.text = "NEW VERSION"
			line.text = "Frontline v%s is out (you have v%s)." % [Updater.latest, Updater.version]
			h.add_child(_btn("Download", website))
		Updater.State.DOWNLOADING:
			head.text = "UPDATING"
			# the percentage ticks along while the menu shows it
			var t := Timer.new()
			t.wait_time = 0.25
			t.autostart = true
			t.timeout.connect(func(): line.text = "Downloading Frontline v%s... %d%%" % [Updater.latest, int(Updater.progress() * 100.0)])
			p.add_child(t)
			line.text = "Downloading Frontline v%s..." % Updater.latest
		Updater.State.READY:
			head.text = "UPDATE READY"
			line.text = "Frontline v%s is installed. Restart to play it." % Updater.latest
			h.add_child(_btn("Restart", func(): Updater.restart()))
		Updater.State.FAILED:
			head.text = "UPDATE FAILED"
			line.text = "Couldn't update to v%s: %s" % [Updater.latest, Updater.error]
			h.add_child(_btn("Download", website))
	for b in h.get_children():
		if b is Button:
			(b as Button).size_flags_vertical = Control.SIZE_SHRINK_CENTER


# --- links from the website -------------------------------------------------------------

## A frontline:// link (Links): join that battle, or press Find Match. Ignored
## in a battle, a lobby or while connecting, so a stray click never pulls
## anyone out of a game (or a host away from the one they're hosting).
func open_link(url: String) -> void:
	if not visible or Net.in_game:
		return
	var mp := multiplayer.multiplayer_peer
	if lobby_box.visible or (mp is ENetMultiplayerPeer and mp.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED):
		_say("You're already in a lobby: leave it first to join another battle.", true)
		return
	var what: Array = Links.parse(url)
	match String(what[0]):
		"find-match":
			if not _mm_busy:
				_find_match()
		"join":
			_join_by_id(String(what[1]))


## Join a listed battle by its id. The list asked for is this build's version
## only, so a battle running another version reads as not found.
func _join_by_id(id: String) -> void:
	_close_panels()
	_say("Finding the battle...")
	var r: Dictionary = await Online.browse()
	if not r.ok:
		_say(String(r.error), true)
		return
	for l in r.data.get("lobbies", []):
		if l is Dictionary and String(l.get("id", "")) == id:
			_join_listed(l)
			return
	_say("That battle isn't listed any more, or it runs a different version of Frontline.", true)


# --- the list of battles --------------------------------------------------------------

func _build_browse_panel() -> void:
	browse_panel = _side_panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	browse_panel.add_child(v)
	v.add_child(UiKit.label("ONLINE", 13, UiKit.ACCENT, 700))
	v.add_child(UiKit.label("Join a battle", 24, UiKit.TEXT, 600))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	browse_list = VBoxContainer.new()
	browse_list.add_theme_constant_override("separation", 6)
	browse_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(browse_list)
	browse_msg = UiKit.label("", 13, UiKit.DIM)
	browse_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	browse_list.add_child(browse_msg)
	v.add_child(UiKit.label("Or connect by address", 15, UiKit.DIM, 600))
	join_row = HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 6)
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.custom_minimum_size = Vector2(190, 36)
	ip_edit.text_submitted.connect(func(_t): _join())
	port_spin = SpinBox.new()
	port_spin.min_value = 1024
	port_spin.max_value = 65535
	port_spin.value = Net.DEFAULT_PORT
	join_row.add_child(ip_edit)
	join_row.add_child(port_spin)
	join_row.add_child(_btn("Connect", _join))
	v.add_child(join_row)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_btn("Refresh", _refresh_browser))
	row.add_child(_btn("Back", func(): browse_panel.visible = false))
	v.add_child(row)


## A panel on the right of the menu, where the new-operation panel sits.
func _side_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.boxc(Color(0.035, 0.045, 0.045, 0.9), 6, UiKit.LINE, 1, 22.0, 10))
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = 640
	p.offset_right = 1180
	p.offset_top = -270
	p.offset_bottom = 290
	p.visible = false
	add_child(p)
	return p


func _open_browser() -> void:
	_close_panels()
	browse_panel.visible = true
	browse_panel.modulate.a = 0.0
	create_tween().tween_property(browse_panel, "modulate:a", 1.0, 0.18)
	_refresh_browser()


func _refresh_browser() -> void:
	_browse_n += 1
	var n := _browse_n
	for c in browse_list.get_children():
		if c != browse_msg:
			c.queue_free()
	browse_msg.text = "Looking for battles..."
	var r: Dictionary = await Online.browse()
	if n != _browse_n:
		return
	if not r.ok:
		browse_msg.text = "%s You can still connect by address." % r.error
		return
	var ls: Array = r.data.get("lobbies", [])
	browse_msg.text = "Nobody is hosting right now. Find Match hosts a battle for others to find." if ls.is_empty() else ""
	for l in ls:
		if l is Dictionary:
			browse_list.add_child(_battle_row(l))


func _battle_row(l: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.03), 4, Color(1, 1, 1, 0.07), 1, 10.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nm := UiKit.label(String(l.get("name", "Battle")), 16, UiKit.TEXT, 600)
	nm.clip_text = true
	v.add_child(nm)
	var full := int(l.get("players", 0)) >= int(l.get("max_players", 8))
	var running := bool(l.get("in_game", false))
	var closed := running and not bool(l.get("drop_in", true))
	var where := ("in battle" + (", closed" if closed else "")) if running else "in the lobby"
	var sub := "%s%s  ·  %d/%d players  ·  %s" % [String(l.get("host", "")), "  ✓" if bool(l.get("verified", false)) else "",
		int(l.get("players", 0)), int(l.get("max_players", 8)), where]
	if String(l.get("nat", "")) == "strict":
		sub += "  ·  strict router"
	v.add_child(UiKit.label(sub, 12, UiKit.DIM))
	var b := _btn("Join", func(): _join_listed(l))
	b.disabled = full or closed
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return card


func _join_listed(l: Dictionary) -> void:
	_mm_busy = false
	_mm_attempt += 1
	var attempt := _mm_attempt
	browse_panel.visible = false
	_say("Joining %s..." % String(l.get("name", "")))
	var r: Dictionary = await Online.join_listed(String(l.id))
	if attempt != _mm_attempt:
		return
	if int(r.err) != OK:
		_say(String(r.error), true)
		return
	_watch_connect(attempt, String(l.get("host", "the host")))


# --- the account ----------------------------------------------------------------------

func _build_account_panel() -> void:
	account_panel = PanelContainer.new()
	account_panel.add_theme_stylebox_override("panel", UiKit.boxc(Color(0.035, 0.045, 0.045, 0.95), 6, UiKit.LINE, 1, 22.0, 10))
	account_panel.set_anchors_preset(Control.PRESET_CENTER)
	account_panel.offset_left = -240
	account_panel.offset_right = 240
	account_panel.offset_top = -185
	account_panel.offset_bottom = 185
	account_panel.visible = false
	add_child(account_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	account_panel.add_child(v)
	v.add_child(UiKit.label("ACCOUNT", 13, UiKit.ACCENT, 700))
	v.add_child(UiKit.label("Sign in", 24, UiKit.TEXT, 600))
	var blurb := UiKit.label("You don't need an account to play online. One keeps your callsign yours: no one else can register it, and battles you host show a tick so players know it's you.", 13, UiKit.DIM)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(blurb)
	acct_email = LineEdit.new()
	acct_email.placeholder_text = "Email"
	acct_pass = LineEdit.new()
	acct_pass.placeholder_text = "Password (8 characters or more)"
	acct_pass.secret = true
	acct_pass.text_submitted.connect(func(_t): _acct_go(false))
	acct_callsign = LineEdit.new()
	acct_callsign.placeholder_text = "Callsign (new accounts only)"
	acct_callsign.max_length = 20
	for e: LineEdit in [acct_email, acct_pass, acct_callsign]:
		e.custom_minimum_size = Vector2(0, 36)
		v.add_child(e)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	acct_btns = [_btn("Sign in", func(): _acct_go(false)), _btn("Create account", func(): _acct_go(true))]
	acct_btns[1].custom_minimum_size = Vector2(150, 36)
	for b in acct_btns:
		row.add_child(b)
	row.add_child(_btn("Close", func(): account_panel.visible = false))
	acct_msg = UiKit.label("", 13, UiKit.DIM)
	acct_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(acct_msg)


func _open_account() -> void:
	_close_panels()
	account_panel.visible = true
	acct_callsign.text = name_edit.text if name_edit.text != "Commander" else ""
	acct_msg.text = ""
	for b in acct_btns:
		b.disabled = false
	# say so up front if this matchmaker has no accounts (or can't be reached)
	var r: Dictionary = await Online.check()
	if not account_panel.visible:
		return
	if not r.ok:
		acct_msg.text = String(r.error)
	elif String(r.data.get("accounts", "off")) == "off":
		acct_msg.text = "This matchmaker doesn't have accounts switched on. You can play online under any callsign."
		for b in acct_btns:
			b.disabled = true


func _acct_go(create: bool) -> void:
	for b in acct_btns:
		b.disabled = true
	acct_msg.text = "Creating the account..." if create else "Signing in..."
	var r: Dictionary
	if create:
		r = await Online.sign_up(acct_email.text, acct_pass.text, acct_callsign.text)
	else:
		r = await Online.sign_in(acct_email.text, acct_pass.text)
	for b in acct_btns:
		b.disabled = false
	if not r.ok:
		acct_msg.text = String(r.error)
	elif r.get("confirm", false):
		acct_msg.text = "Check your email for the confirmation link, then sign in here."
	else:
		acct_pass.text = ""
		account_panel.visible = false
		_say("Signed in as %s." % Online.callsign)


func _on_account() -> void:
	var on := Online.signed_in()
	acct_btn.text = "Sign out" if on else "Sign in"
	acct_tag.visible = on
	if on and Online.callsign != "":
		name_edit.text = Online.callsign
	name_edit.tooltip_text = ("Signed in as %s. Change it here to rename your account." % Online.email) if on else ""


func _refresh() -> void:
	if not lobby_box.visible:
		return
	for c in player_list.get_children():
		c.queue_free()
	var host := multiplayer.is_server()
	lobby_title.text = "Lobby (%s)" % ("you are hosting" if host else "connected")
	var counts := [0, 0]
	for id in Net.players:
		var p: Dictionary = Net.players[id]
		var t := int(p.team)
		if t >= 0:
			counts[t] += 1
		var l := UiKit.label("", 15)
		var side: String = Defs.TEAM_NAMES[t] if t >= 0 else "Spectator"
		l.text = "%s%s  -  %s" % [p.name, " (host)" if id == 1 else "", side]
		l.add_theme_color_override("font_color", Defs.TEAM_COLORS[t] if t >= 0 else Color(0.7, 0.7, 0.7))
		player_list.add_child(l)
	var mk := String(Net.settings.get("mission", ""))
	if mk != "":
		lobby_title.text = "Mission: %s  (%s)" % [String(Missions.find(mk).title), "you are hosting" if host else "connected"]
	ai_check.visible = mk == ""
	ally_check.visible = mk == ""
	var me: Dictionary = Net.players.get(multiplayer.get_unique_id(), {})
	if not me.is_empty():
		var mt := int(me.team)
		team_opt.select(mt if mt >= 0 else 2)
	ai_check.disabled = not host
	ally_check.disabled = not host
	drop_check.disabled = not host
	drop_check.set_pressed_no_signal(bool(Net.settings.get("drop_in", true)))
	ai_check.set_pressed_no_signal(bool(Net.settings.get("ai_fill", true)))
	ally_check.set_pressed_no_signal(bool(Net.settings.get("ai_allies", false)))
	# the online listing: only for a battle hosted from the menu (not a
	# single-player one), and only the host sees it
	var online := host and Online.hosting()
	list_check.visible = online
	list_check.set_pressed_no_signal(Online.want_listed)
	online_label.visible = online
	online_label.text = Online.listing_text() if online else ""
	start_btn.disabled = not host
	var mode := "Co-op vs AI" if (counts[0] == 0 or counts[1] == 0) else "Player vs Player"
	start_btn.text = ("Start Battle (%s)" % mode if mk == "" else "Start Mission (%d players)" % (counts[0] + counts[1])) if host else "Waiting for host..."
