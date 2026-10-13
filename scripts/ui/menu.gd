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
	margin.offset_right = 620
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	var fv := FontVariation.new()
	fv.base_font = UiKit.font(700)
	fv.spacing_glyph = 7
	var title := Label.new()
	title.text = "FRONTLINE"
	title.add_theme_font_override("font", fv)
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_color_override("font_color", Color(0.97, 0.93, 0.82))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	col.add_child(title)
	var tag := UiKit.label("SQUAD TACTICS  -  SOLDIERS WHO THINK  -  SUPPLY LINES THAT BREAK", 13, UiKit.ACCENT, 600)
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	col.add_child(gap)

	# main screen
	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 6)
	main_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(main_box)
	main_box.add_child(_big("Play vs AI", "Command one side against the AI commander", _single_player))
	main_box.add_child(_big("Watch AI Battle", "Sit back: two AI commanders fight it out and the camera finds the action", _observe))
	main_box.add_child(_big("Host Multiplayer", "Co-op against the AI or player vs player", _host))
	main_box.add_child(_big("Join Game", "Connect to a battle hosted by a friend", func(): join_row.visible = not join_row.visible))
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
	main_box.add_child(_big("Field Manual", "Every soldier, weapon, vehicle and work, with its numbers", func(): manual.visible = true))
	main_box.add_child(_big("Settings", "Graphics, performance overlay, audio", func(): settings_panel.visible = true))
	main_box.add_child(_big("Quit", "", func(): get_tree().quit()))
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
	var hint := UiKit.label("Multiplayer: the host forwards UDP port %d (or plays on a LAN / VPN). Co-op: everyone picks the same side." % Net.DEFAULT_PORT, 12, Color(0.75, 0.75, 0.7, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(460, 0)
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


## Large left-aligned menu entry (its description is the tooltip).
func _big(text: String, sub: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = sub
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(360, 48)
	b.add_theme_font_override("font", UiKit.font(600))
	b.add_theme_font_size_override("font_size", 20)
	var n := UiKit.box(Color(0, 0, 0, 0.22), 4, Color(0, 0, 0, 0), 0, 0.0)
	n.content_margin_left = 20
	var h := UiKit.box(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.14), 4, UiKit.ACCENT, 0, 0.0)
	h.border_width_left = 3
	h.content_margin_left = 26
	var pr := h.duplicate() as StyleBoxFlat
	pr.bg_color = Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.25)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("hover_pressed", pr)
	b.add_theme_color_override("font_hover_color", UiKit.ACCENT)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Sfx.ui("click"); cb.call())
	return b


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
	status.text = msg


func _show_lobby() -> void:
	main_box.visible = false
	lobby_box.visible = true
	status.text = ""
	_refresh()


func _single_player() -> void:
	var port := int(port_spin.value)
	var err := ERR_CANT_CREATE
	for i in 5:
		err = Net.host_game(port + i)
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
	start_btn.text = "Start Battle (%s)" % mode if host else "Waiting for host..."
