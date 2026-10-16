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
	margin.add_theme_constant_override("margin_top", 80)
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
	gap.custom_minimum_size = Vector2(0, 18)
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
	main_box.add_child(_big("Host Multiplayer", "Co-op against the AI, or player against player", _host))
	main_box.add_child(_big("Join Game", "Connect to a battle a friend is hosting", func(): join_row.visible = not join_row.visible))
	join_row = HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 6)
	join_row.visible = false
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.custom_minimum_size = Vector2(190, 36)
	port_spin = SpinBox.new()
	port_spin.min_value = 1024
	port_spin.max_value = 65535
	port_spin.value = Net.DEFAULT_PORT
	join_row.add_child(ip_edit)
	join_row.add_child(port_spin)
	join_row.add_child(_btn("Connect", _join))
	main_box.add_child(join_row)
	main_box.add_child(_section("REFERENCE"))
	main_box.add_child(_big("Field Manual", "Every soldier, weapon, vehicle and work, with its numbers", func(): manual.visible = true))
	main_box.add_child(_big("Settings", "Graphics, display, interface and sound", func(): settings_panel.visible = true))
	main_box.add_child(_big("Quit", "Back to the desktop", func(): get_tree().quit()))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	main_box.add_child(gap2)
	main_box.add_child(_row("Callsign", _make_name_edit()))

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
	hint = UiKit.label("Multiplayer: the host forwards UDP port %d (or plays on a LAN / VPN). Co-op: everyone picks the same side." % Net.DEFAULT_PORT, 12, Color(0.75, 0.75, 0.7, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(460, 0)
	hint.visible = false
	col.add_child(hint)

	settings_panel = SettingsPanel.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -330
	settings_panel.offset_right = 330
	settings_panel.offset_top = -300
	settings_panel.offset_bottom = 300
	settings_panel.visible = false
	settings_panel.closed.connect(func(): settings_panel.visible = false)
	add_child(settings_panel)
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
	var foot := UiKit.label("ALPHA BUILD  \u00b7  GODOT %s  \u00b7  F4 FIELD MANUAL IN BATTLE" % Engine.get_version_info().string.to_upper(), 11, Color(0.75, 0.75, 0.7, 0.45), 600)
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
	b.custom_minimum_size = Vector2(420, 58 if sub != "" else 44)
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
	op_panel = PanelContainer.new()
	op_panel.add_theme_stylebox_override("panel", UiKit.boxc(Color(0.035, 0.045, 0.045, 0.9), 6, UiKit.LINE, 1, 22.0, 10))
	op_panel.anchor_top = 0.5
	op_panel.anchor_bottom = 0.5
	op_panel.offset_left = 640
	op_panel.offset_right = 1180
	op_panel.offset_top = -270
	op_panel.offset_bottom = 290
	op_panel.visible = false
	add_child(op_panel)
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


func _open_op(side: int) -> void:
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
	if visible and ev is InputEventKey and ev.pressed and (ev as InputEventKey).keycode == KEY_ESCAPE:
		for p in [op_panel, ms_panel]:
			if p and p.visible:
				p.visible = false
				get_viewport().set_input_as_handled()


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
	op_panel.visible = false
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
	return name_edit


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
	status.text = msg


func _show_lobby() -> void:
	main_box.visible = false
	lobby_box.visible = true
	hint.visible = true
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


func _host() -> void:
	var err := Net.host_game(int(port_spin.value))
	if err != OK:
		status.text = "Could not host on port %d (error %d). Is it already in use?" % [int(port_spin.value), err]
		return
	_show_lobby()


func _join() -> void:
	var err := Net.join_game(ip_edit.text.strip_edges(), int(port_spin.value))
	if err != OK:
		status.text = "Could not connect (error %d)." % err
		return
	status.text = "Connecting to %s..." % ip_edit.text


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
	start_btn.disabled = not host
	var mode := "Co-op vs AI" if (counts[0] == 0 or counts[1] == 0) else "Player vs Player"
	start_btn.text = ("Start Battle (%s)" % mode if mk == "" else "Start Mission (%d players)" % (counts[0] + counts[1])) if host else "Waiting for host..."
