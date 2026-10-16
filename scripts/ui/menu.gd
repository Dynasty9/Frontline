extends Control
## Main menu, and the way into multiplayer: the server browser, hosting, the
## lobby, and the dialog that shows a join (or a host) getting there.

var name_edit: LineEdit
var status: Label
var main_box: VBoxContainer
var settings_panel: SettingsPanel
var manual: FieldManual
var backdrop: TopoBackdrop
var op_panel: PanelContainer
var ms_panel: PanelContainer  # the missions
var _ms_key := ""
var _ms_cards := {}
var _ms_detail: VBoxContainer
var _music_on := false
var _op_side := 0  # 0 Coalition, 1 Rebels, -1 observe
var _side_cards := {}
var _mood_chips := {}
var _col: VBoxContainer
var _margin: MarginContainer
# multiplayer: the server browser and the lobby (screens that take the place
# of the menu), setting up a battle to host, and the join dialog
var browser: ServerBrowser
var lobby: LobbyScreen
var host_panel: HostSetup
var dialog: JoinDialog
var _join_target := {}  # the battle being joined, to try again with a password
var account_panel: AccountPanel
var acct_card: PanelContainer  # top right: who you're signed in as, or how to sign in
var acct_name: Label
var acct_line: Label
var acct_badge: Label
var acct_primary: Button
var acct_secondary: Button
var rec_panel: PanelContainer  # the service record: career totals and every battle
var rec_title: Label
var rec_tiles: GridContainer
var rec_list: VBoxContainer
var rec_msg: Label
var rec_more: Button
var rec_view: StatsPanel  # one battle's after-action report, opened from the record
var _rec_before := ""  # the oldest battle shown (for "older battles")
var _rec_n := 0  # the latest load (an older answer arriving late is dropped)
# the rank and the insignia: the one worn on the account card, and the collection
var ins_btn: Button
var ins_tex: TextureRect
var rank_label: Label
var rank_bar: ProgressBar
var ins_panel: PanelContainer
var _ins_head: Dictionary = {}  # the collection's header: icon, name, rank, bar, xp, record
var _ins_tiles := {}  # id -> the tile's button
var _ins_counts := {}  # group -> its "7 / 50" label
var _ins_msg: Label
var _ins_load: Array = []  # tiles still waiting for their picture (a few are drawn each frame)
var _ins_pending := ""  # an insignia being put on, until the matchmaker answers
var _mm_busy := false  # Find Match is working through battles
var _mm_tries: Array = []  # lobby ids it has tried this time
var _attempt := 0  # bumps with every join (or host) attempt, so stale answers and timeouts do nothing
var notices: VBoxContainer  # the cards in the top right, under the account: a newer release, a battle to rejoin
var rejoin_card: PanelContainer  # back into the battle we dropped out of (while there is one)

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
	# the living map behind it all, darkened down the left so the menu reads
	backdrop = TopoBackdrop.new()
	backdrop.shade = 1.0
	add_child(backdrop)

	var margin := MarginContainer.new()
	_margin = margin
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
	main_box.add_child(_big("Server Browser", "Every battle being hosted, online and on your network", _open_browser))
	main_box.add_child(_big("Host a Battle", "Co-op against the AI, versus, or a mission with friends", func(): _open_host({})))
	main_box.add_child(_big("Find Match", "Straight into the best open battle, or host one to be found", _find_match))
	main_box.add_child(_section("REFERENCE"))
	main_box.add_child(_big("Field Manual", "Every soldier, weapon, vehicle and work, with its numbers", func(): manual.visible = true))
	main_box.add_child(_big("Settings", "Graphics, display, interface, controls and sound", func(): settings_panel.visible = true))
	main_box.add_child(_big("Quit", "Back to the desktop", func(): get_tree().quit()))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 14)
	main_box.add_child(gap2)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 8)
	who.add_child(_make_name_edit())
	main_box.add_child(_row("Callsign", who))

	status = UiKit.label("", 14, UiKit.BAD)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(460, 0)
	col.add_child(status)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

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
	_build_multiplayer()
	_build_account()
	_build_insignia_panel()
	# the join dialog stays over every panel
	move_child(dialog, -1)
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

	Online.account_changed.connect(_on_account)
	Online.record_changed.connect(_on_account)
	notices = VBoxContainer.new()
	notices.add_theme_constant_override("separation", 10)
	notices.anchor_left = 1.0
	notices.anchor_right = 1.0
	notices.offset_left = -540
	notices.offset_right = -32
	notices.offset_top = 196  # under the account card
	add_child(notices)
	for p: Control in [op_panel, ms_panel, host_panel, rec_panel, ins_panel]:
		p.visibility_changed.connect(_side_panels_changed)
	Updater.changed.connect(_update_notice)
	_update_notice()
	_on_account()
	# (the server browser and the lobby take the menu's place, and the corner)
	main_box.visibility_changed.connect(_refresh_rejoin)
	_refresh_rejoin()
	# a Join or Find Match link from the website: the one we were started with,
	# and any a second copy hands on while we run
	Links.link_opened.connect(open_link)
	if Links.pending != "":
		open_link.call_deferred(Links.pending)
		Links.pending = ""
	_on_visibility()


## The menu comes in as the title lifts away: the column glides in from the
## left and its entries follow one after another.
func arrive() -> void:
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_margin.position.x = -40.0
	tw.tween_property(_margin, "position:x", 0.0, 0.8)
	var items: Array = _col.get_children().slice(0, 3) + main_box.get_children()
	for i in items.size():
		var c: CanvasItem = items[i]
		c.modulate.a = 0.0
		tw.tween_property(c, "modulate:a", 1.0, 0.5).set_delay(0.12 + 0.035 * i)


## The menu's music starts again each time it comes back.
func _on_visibility() -> void:
	if is_visible_in_tree() and acct_card:
		_card_in.call_deferred()
	if is_visible_in_tree() and not _music_on:
		_music_on = true
		Music.play_cue("menu")
	elif not is_visible_in_tree():
		_music_on = false


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
	var go := UiKit.primary_button("DEPLOY", 220, 44, 17)
	go.pressed.connect(func(): Sfx.ui("click"); _deploy())
	row.add_child(go)
	row.add_child(_btn("Back", func(): op_panel.visible = false))


## The panels on the right of the menu take turns: opening one closes the rest.
func _close_panels() -> void:
	for p: Control in [op_panel, ms_panel, host_panel, account_panel, rec_panel, ins_panel]:
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
	for p: Control in [rec_view, account_panel, ins_panel, rec_panel, host_panel, ms_panel, op_panel]:
		if p and p.visible:
			p.visible = false
			get_viewport().set_input_as_handled()
			return
	if browser and browser.visible:
		_close_browser()
		get_viewport().set_input_as_handled()


# --- missions ------------------------------------------------------------------------------

## The missions: a card for each, the chosen one's briefing, and play it
## alone or host it for friends.
func _build_mission_panel() -> void:
	ms_panel = PanelContainer.new()
	ms_panel.add_theme_stylebox_override("panel", UiKit.frame(Color(-1, 0, 0), 22.0, 1.0, 14.0, 0.93))
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
	var go := UiKit.primary_button("PLAY SOLO", 200, 44, 16)
	go.pressed.connect(func(): Sfx.ui("click"); _mission_solo())
	row2.add_child(go)
	var co := _btn("Host Co-op", func(): Sfx.ui("click"); _mission_coop())
	co.custom_minimum_size = Vector2(150, 44)
	co.tooltip_text = "Host this mission for friends: it's listed in the server browser, and they share your force."
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
	var port := Net.DEFAULT_PORT
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


## Host the chosen mission for friends: the host setup, on that mission.
func _mission_coop() -> void:
	_open_host({"mode": "mission", "mission": _ms_key})


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


## Back to the menu: after a battle, leaving a lobby, or being disconnected
## (`msg` says why, in the dialog where it can't be missed).
func show_menu(msg: String) -> void:
	visible = true
	var was_lobby := lobby.visible
	lobby.visible = false
	main_box.visible = not browser.visible
	if _mm_busy and msg != "":
		# that battle wouldn't take us: Find Match tries the next
		_mm_next.call_deferred()
		return
	if msg == "":
		dialog.close()
		_join_target = {}
		return
	var joining := dialog.mode == JoinDialog.Mode.PROGRESS or dialog.mode == JoinDialog.Mode.PASSWORD
	dialog.fail("Couldn't join" if joining and not was_lobby else "Disconnected", msg)
	_join_target = {}


## A line under the menu: progress in the normal colour, problems in red.
func _say(msg: String, bad := false) -> void:
	status.text = msg
	status.add_theme_color_override("font_color", UiKit.BAD if bad else UiKit.DIM)


func _show_lobby() -> void:
	_mm_busy = false
	_attempt += 1
	_join_target = {}
	dialog.close()
	_close_panels()
	browser.visible = false
	main_box.visible = false
	status.text = ""
	lobby.visible = true
	lobby.modulate.a = 0.0
	create_tween().tween_property(lobby, "modulate:a", 1.0, 0.18)
	lobby.reset()


## The host told us who's in the lobby: that's when a join has worked (and
## not before - a host that wants a password, or is full, turns us away first).
func _on_lobby_updated() -> void:
	if Net.in_game or not visible or lobby.visible or multiplayer.is_server():
		return
	if Net.players.has(multiplayer.get_unique_id()) and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		if _join_target.is_empty():
			# a join the player had already cancelled got through after all
			Net.leave()
			return
		_show_lobby()


func _single_player(side := 0) -> void:
	var port := Net.DEFAULT_PORT
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
	var port := Net.DEFAULT_PORT
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


# --- multiplayer -----------------------------------------------------------------------

func _build_multiplayer() -> void:
	browser = ServerBrowser.new()
	browser.visible = false
	add_child(browser)
	_screen(browser)
	browser.closed.connect(_close_browser)
	browser.join_requested.connect(_join_entry)
	browser.direct_requested.connect(_join_direct)
	browser.host_requested.connect(func(): _open_host({}))
	lobby = LobbyScreen.new()
	lobby.visible = false
	add_child(lobby)
	_screen(lobby)
	lobby.leave_requested.connect(func():
		await Net.close_lobby()
		show_menu(""))
	host_panel = HostSetup.new()
	host_panel.visible = false
	host_panel.anchor_top = 0.5
	host_panel.anchor_bottom = 0.5
	host_panel.offset_left = 640
	host_panel.offset_right = 1260
	host_panel.offset_top = -305
	host_panel.offset_bottom = 315
	add_child(host_panel)
	host_panel.closed.connect(func(): host_panel.visible = false)
	host_panel.host_requested.connect(_host_with)
	dialog = JoinDialog.new()
	add_child(dialog)
	dialog.cancelled.connect(_on_dialog_cancel)
	dialog.password_entered.connect(_on_password)
	Net.password_needed.connect(_on_password_needed)
	Net.lobby_updated.connect(_on_lobby_updated)
	Net.game_start.connect(func(_s):
		# straight into a battle (dropping in, or the host starting): whatever
		# we were doing is done, and afterwards it's back to the menu proper,
		# not the screen we left from
		_mm_busy = false
		_attempt += 1
		dialog.close()
		browser.visible = false
		_join_target = {})
	multiplayer.connected_to_server.connect(func(): dialog.step("Connected: joining the lobby"))
	Online.join_progress.connect(func(st: String): dialog.step(st))


## A screen that takes the menu's place under the title: the server browser,
## the lobby.
func _screen(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 72
	c.offset_right = -72
	c.offset_top = 196
	c.offset_bottom = -56


func _open_browser() -> void:
	_close_panels()
	main_box.visible = false
	status.text = ""
	browser.visible = true
	browser.modulate.a = 0.0
	create_tween().tween_property(browser, "modulate:a", 1.0, 0.18)


func _close_browser() -> void:
	browser.visible = false
	main_box.visible = not lobby.visible


## The host setup, on the right of the menu (`preset`: a mode or mission to
## start from).
func _open_host(preset: Dictionary) -> void:
	_close_panels()
	_close_browser()
	host_panel.open(preset)
	host_panel.visible = true
	host_panel.modulate.a = 0.0
	host_panel.offset_left = 670
	var tw := create_tween().set_parallel(true)
	tw.tween_property(host_panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(host_panel, "offset_left", 640.0, 0.18)


## Host a battle as the host setup describes it (an empty `opts`: a public
## versus battle, as Find Match hosts when there's nothing to join). The
## router is checked first, then the lobby opens and the battle is listed.
func _host_with(opts: Dictionary) -> void:
	host_panel.visible = false
	_attempt += 1
	var attempt := _attempt
	if dialog.mode != JoinDialog.Mode.PROGRESS:
		dialog.begin("Hosting", String(opts.get("name", "")) if String(opts.get("name", "")) != "" else "Your battle")
	dialog.step("Checking your router")
	var mode := String(opts.get("mode", "versus"))
	var mk := String(opts.get("mission", "")) if mode == "mission" else ""
	var side := 0
	if mk != "":
		side = int(Missions.find(mk).side)
	elif mode == "coop":
		side = clampi(int(opts.get("side", 0)), 0, 1)
	var port := int(opts.get("port", Net.DEFAULT_PORT))
	var err: int = await Online.host(port, side, false, func(): return attempt == _attempt)
	if attempt != _attempt:
		# cancelled while the router was being checked (so nothing was hosted)
		return
	if err != OK:
		dialog.fail("Couldn't host", "Couldn't open UDP port %d (error %d): is another copy of the game hosting on it? Pick another port in the host setup." % [port, err])
		return
	var cfg := {
		"name": String(opts.get("name", "")),
		"mode": "versus" if mode == "versus" else "coop",
		"coop_side": side,
		"max_players": int(opts.get("max_players", Net.MAX_PLAYERS)),
		"mood": String(opts.get("mood", Settings.get_v("mood"))),
		"drop_in": bool(opts.get("drop_in", true)),
		"ai_fill": bool(opts.get("ai_fill", true)),
		"ai_allies": bool(opts.get("ai_allies", false)),
		"locked": String(opts.get("password", "")) != "",
	}
	if mk != "":
		cfg["mission"] = mk
	Net.configure(cfg)
	Net.password = String(opts.get("password", ""))
	if String(opts.get("access", "public")) != "unlisted":
		Online.list_game()
	_show_lobby()


## A battle from the server browser or a link: its password first, if it
## has one.
func _join_entry(e: Dictionary) -> void:
	_mm_busy = false
	_join_target = e.duplicate()
	Net.join_password = ""
	if bool(e.get("locked", false)):
		dialog.ask_password("Join %s" % String(e.get("name", "the battle")), false)
		return
	_join_now()


## Direct Connect: an address and port (and a password, in case).
func _join_direct(address: String, port: int, pw := "") -> void:
	_mm_busy = false
	_join_target = {"name": "%s:%d" % [address, port], "host": address, "address": address, "port": port, "direct": true}
	Net.join_password = pw
	_join_now()


func _on_password(pw: String) -> void:
	if _join_target.is_empty():
		dialog.close()
		return
	Net.join_password = pw
	_join_now()


## The host turned us away for a password: ask for it (or for the right one).
func _on_password_needed(wrong: bool) -> void:
	_attempt += 1
	if _join_target.is_empty():
		dialog.fail("Couldn't join", "That battle needs a password.")
		return
	dialog.ask_password("Join %s" % String(_join_target.get("name", "the battle")), wrong)


func _join_now() -> void:
	_attempt += 1
	var attempt := _attempt
	var e := _join_target
	dialog.begin("Joining", String(e.get("name", "the battle")))
	var address := String(e.get("address", ""))
	if address != "":
		# on this network, or by address: straight to the host
		dialog.step("Connecting to %s" % ("the host on your network" if bool(e.get("lan", false)) else address))
		var err := Net.join_game(address, int(e.get("port", Net.DEFAULT_PORT)))
		if err != OK:
			dialog.fail("Couldn't join", "Couldn't start connecting to %s (error %d)." % [address, err])
			return
	else:
		var r: Dictionary = await Online.join_listed(String(e.get("id", "")), func(): return attempt == _attempt)
		if attempt != _attempt:
			return
		if int(r.err) != OK:
			dialog.fail("Couldn't join", String(r.error))
			return
	_watch_connect(attempt, String(e.get("host", "the host")))


## Cancel in the dialog: stop joining (or looking, or hosting).
func _on_dialog_cancel() -> void:
	_attempt += 1
	_join_target = {}
	_mm_busy = false
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer and not lobby.visible and not Net.in_game:
		Net.leave()


# --- rejoining ---------------------------------------------------------------------------

## While the battle we were last in may still be going (Net.rejoin), a card
## in the corner says whose it was and how long ago we left, with Rejoin (and
## Forget, for a battle we don't mean to go back to).
func _refresh_rejoin() -> void:
	if notices == null:
		return
	if rejoin_card:
		rejoin_card.queue_free()
		rejoin_card = null
	if not Net.can_rejoin() or not main_box.visible:
		return
	var host := String(Net.rejoin.get("host", ""))
	var mins := int((Time.get_unix_time_from_system() - float(Net.rejoin.get("at", 0.0))) / 60.0)
	var when := "just now" if mins < 1 else ((("%d min" % mins) if mins < 90 else ("%d h" % int(mins / 60.0))) + " ago")
	rejoin_card = _notice("BATTLE IN PROGRESS", "You left %s %s." % [("%s's battle" % host) if host != "" else "a battle", when], false)
	var h: HBoxContainer = rejoin_card.get_child(0)
	h.add_child(_btn("Forget", func(): Net.forget_rejoin(); _refresh_rejoin()))
	var go := _btn("Rejoin", _rejoin)
	go.add_theme_color_override("font_color", UiKit.ACCENT)
	h.add_child(go)
	for b in h.get_children():
		if b is Button:
			(b as Button).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	notices.add_child(rejoin_card)


## Back into that battle as the player we were there: the host gives us our
## side, colour and surviving force back (no password: we were let in
## before). A listed battle goes through the matchmaker again (the host's
## router may need punching through afresh), else, or if it's no longer
## listed, straight to the address we had.
func _rejoin() -> void:
	if not Net.can_rejoin():
		_refresh_rejoin()
		return
	_close_panels()
	_mm_busy = false
	var r: Dictionary = Net.rejoin
	var host := String(r.get("host", ""))
	if host == "":
		host = "the host"
	var lobby_id := String(r.get("lobby", ""))
	_join_target = {"name": "%s's battle" % host, "host": host, "rejoin": true}
	Net.join_password = ""
	Net.begin_rejoin()
	_attempt += 1
	var attempt := _attempt
	dialog.begin("Rejoining", "%s's battle" % host)
	var err := FAILED
	if lobby_id != "":
		var j: Dictionary = await Online.join_listed(lobby_id, func(): return attempt == _attempt)
		if attempt != _attempt:
			return
		err = int(j.err)
	if err != OK:
		dialog.step("Connecting to %s" % String(r.ip))
		err = Net.join_game(String(r.ip), int(r.port), 0, lobby_id)
	if err != OK:
		Net.forget_rejoin()
		_refresh_rejoin()
		dialog.fail("Couldn't rejoin", "Couldn't start connecting to %s (error %d)." % [String(r.ip), err])
		_join_target = {}
		return
	_watch_connect(attempt, host)


# --- Find Match -----------------------------------------------------------------------

## Join the best open battle online, or if there is none, host one for others
## to find. Cancel in the dialog stops it.
func _find_match() -> void:
	if _mm_busy:
		return
	_close_panels()
	_mm_busy = true
	_mm_tries.clear()
	_join_target = {}
	_mm_next()


## One step of Find Match: ask the matchmaker for the best battle we haven't
## tried and join it. When there's none left (or a few hosts' routers wouldn't
## let us through) host one instead and wait to be found.
func _mm_next() -> void:
	if not _mm_busy:
		return
	_attempt += 1
	var attempt := _attempt
	dialog.begin("Find Match", "Looking for a battle")
	dialog.step("Asking the matchmaker for an open battle")
	var r: Dictionary = await Online.find_match(_mm_tries)
	if not _mm_busy or attempt != _attempt:
		return
	if not r.ok:
		_mm_busy = false
		dialog.fail("Find Match", "%s You can still host a battle, or join one by address in the server browser." % r.error)
		return
	var l: Variant = r.data.get("lobby")
	if not (l is Dictionary) or _mm_tries.size() >= 4:
		_mm_busy = false
		dialog.step("No open battles: hosting one for others to find")
		_host_with({})
		return
	_mm_tries.append(String(l.id))
	_join_target = (l as Dictionary).duplicate()
	Net.join_password = ""
	dialog.begin("Find Match", "Joining %s" % String(l.name))
	var j: Dictionary = await Online.join_listed(String(l.id), func(): return _mm_busy and attempt == _attempt)
	if not _mm_busy or attempt != _attempt:
		return
	if int(j.err) != OK:
		_mm_next()
		return
	_watch_connect(attempt, String(l.host))


## ENet takes a long while to give up on a host it can't reach. If we're not
## through in a few seconds, it isn't going to work: say so (or, finding a
## match, move on to the next battle).
func _watch_connect(attempt: int, host_name: String) -> void:
	await get_tree().create_timer(12.0, true, false, true).timeout
	if attempt != _attempt or lobby.visible or Net.in_game:
		return
	var mp := multiplayer.multiplayer_peer
	if mp is ENetMultiplayerPeer and mp.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var direct := bool(_join_target.get("direct", false))
	var port := int(_join_target.get("port", Net.DEFAULT_PORT))
	Net.leave()
	if bool(_join_target.get("rejoin", false)):
		# Rejoin: that battle is taken to be gone
		Net.forget_rejoin()
		_refresh_rejoin()
		dialog.fail("Couldn't rejoin", "Nobody answered at %s's battle. It may have ended." % host_name)
	elif _mm_busy:
		_mm_next()
	elif direct:
		dialog.fail("Couldn't join", "Nothing answered at %s. Check the address, and that the host has forwarded UDP port %d (or that you're both on the same network)." % [String(_join_target.get("name", "")), port])
	else:
		dialog.fail("Couldn't join", "Couldn't get through to %s. Their router may be blocking the way in (a strict one needs UDP port %d forwarded), or the battle has just closed." % [host_name, Net.DEFAULT_PORT])
	_join_target = {}


# --- a newer release -------------------------------------------------------------------

## The update notice in the corner: a newer release downloading, installed
## and waiting for a restart, or (where the game can't update itself) a link
## to the downloads. Playing online needs the same version as everyone else,
## so it's worth the space.
func _update_notice() -> void:
	var old := notices.get_node_or_null("UpdateNotice")
	if old:
		old.name = "OldNotice"
		old.queue_free()
	if Updater.state == Updater.State.NONE:
		return
	var bad: bool = Updater.state == Updater.State.FAILED
	var p := _notice("", "", bad)
	p.name = "UpdateNotice"
	notices.add_child(p)
	notices.move_child(p, 0)  # (above a battle to rejoin)
	var h: HBoxContainer = p.get_child(0)
	var v: VBoxContainer = h.get_child(0)
	var head: Label = v.get_child(0)
	var line: Label = v.get_child(1)
	var website := func(): OS.shell_open(Updater.WEBSITE_URL + "/#download")
	# that version's changelog on the website: what the update brings
	var whats_new := func(): OS.shell_open(Updater.WEBSITE_URL + "/changelog/#v" + Updater.latest)
	match Updater.state:
		Updater.State.AVAILABLE:
			head.text = "NEW VERSION"
			line.text = "Frontline v%s is out (you have v%s)." % [Updater.latest, Updater.version]
			h.add_child(_btn("What's new", whats_new))
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
			h.add_child(_btn("What's new", whats_new))
			h.add_child(_btn("Restart", func(): Updater.restart()))
		Updater.State.FAILED:
			head.text = "UPDATE FAILED"
			line.text = "Couldn't update to v%s: %s" % [Updater.latest, Updater.error]
			h.add_child(_btn("Download", website))
	for b in h.get_children():
		if b is Button:
			(b as Button).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if acct_card:
		_side_panels_changed()


## A card for the top right: a small heading over a line of text, with room
## on its right (the HBox, its first child) for buttons.
func _notice(head_text: String, text: String, bad: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(Color(0.035, 0.045, 0.045, 0.92), 4, UiKit.BAD if bad else UiKit.ACCENT, 1, 12.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UiKit.label(head_text, 11, UiKit.BAD if bad else UiKit.ACCENT, 700))
	var line := UiKit.label(text, 14, UiKit.TEXT, 600)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(line)
	return p


# --- links from the website -------------------------------------------------------------

## A frontline:// link (Links): join that battle, or press Find Match. Ignored
## in a battle, a lobby or while connecting, so a stray click never pulls
## anyone out of a game (or a host away from the one they're hosting). A
## sign-in from the website is Online's.
func open_link(url: String) -> void:
	var what: Array = Links.parse(url)
	if not visible or Net.in_game or what[0] == "sign-in":
		return
	if dialog.mode == JoinDialog.Mode.PROGRESS or dialog.mode == JoinDialog.Mode.PASSWORD:
		return  # already joining (or hosting) something
	var mp := multiplayer.multiplayer_peer
	if lobby.visible or (mp is ENetMultiplayerPeer and mp.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED):
		dialog.fail("Already in a lobby", "Leave this lobby first to join another battle.")
		return
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
	_attempt += 1
	var attempt := _attempt
	dialog.begin("Joining", "A battle from a link")
	dialog.step("Looking it up")
	var r: Dictionary = await Online.browse()
	if attempt != _attempt:
		return
	if not r.ok:
		dialog.fail("Couldn't join", String(r.error))
		return
	for l in r.data.get("lobbies", []):
		if l is Dictionary and String(l.get("id", "")) == id:
			_join_entry(l)
			return
	dialog.fail("Couldn't join", "That battle isn't listed any more, or it runs a different version of Frontline.")


## A panel on the right of the menu, where the new-operation panel sits.
func _side_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.frame(Color(-1, 0, 0), 22.0, 1.0, 14.0, 0.92))
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = 640
	p.offset_right = 1180
	p.offset_top = -270
	p.offset_bottom = 290
	p.visible = false
	add_child(p)
	return p


# --- the account ----------------------------------------------------------------------

## The account: a card top right that says who you are (or how to sign in),
## the sign-in form, and the service record.
func _build_account() -> void:
	acct_card = PanelContainer.new()
	UiFx.glass(acct_card, 12.0, 18.0)
	acct_card.anchor_left = 1.0
	acct_card.anchor_right = 1.0
	acct_card.offset_left = -440
	acct_card.offset_right = -32
	acct_card.offset_top = 32
	acct_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(acct_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	acct_card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_spaced("ACCOUNT", 11, UiKit.ACCENT, 3))
	acct_badge = _spaced("SIGNED IN", 11, UiKit.GOOD, 2)
	head.add_child(acct_badge)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 12)
	v.add_child(who)
	who.add_child(_make_ins_btn())
	ins_btn.custom_minimum_size = Vector2(58, 58)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 3)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_child(wv)
	acct_name = UiKit.label("", 22, UiKit.TEXT, 700)
	wv.add_child(acct_name)
	rank_label = UiKit.label("", 11, UiKit.ACCENT, 700)
	rank_label.mouse_filter = Control.MOUSE_FILTER_PASS
	wv.add_child(rank_label)
	rank_bar = _xp_bar(200)
	rank_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	wv.add_child(rank_bar)
	acct_line = UiKit.label("", 12, UiKit.DIM)
	acct_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	acct_line.custom_minimum_size = Vector2(370, 0)
	v.add_child(acct_line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	acct_primary = _btn("", func():
		Sfx.ui("click")
		if Online.signed_in():
			_open_record()
		else:
			_open_account())
	acct_primary.custom_minimum_size = Vector2(150, 34)
	# the one thing to do here, in the accent like Deploy
	acct_primary.add_theme_font_override("font", UiKit.font(700))
	acct_primary.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.85), 4, UiKit.ACCENT, 0, 6.0))
	acct_primary.add_theme_stylebox_override("hover", UiKit.box(UiKit.ACCENT.lightened(0.15), 4, UiKit.ACCENT, 0, 6.0))
	acct_primary.add_theme_stylebox_override("pressed", UiKit.box(UiKit.ACCENT.lightened(0.15), 4, UiKit.ACCENT, 0, 6.0))
	acct_primary.add_theme_color_override("font_color", Color(0.08, 0.07, 0.05))
	acct_primary.add_theme_color_override("font_hover_color", Color(0.05, 0.04, 0.03))
	acct_primary.add_theme_color_override("font_pressed_color", Color(0.05, 0.04, 0.03))
	acct_primary.focus_mode = Control.FOCUS_NONE
	row.add_child(acct_primary)
	acct_secondary = _btn("", func():
		Sfx.ui("click")
		if Online.signed_in():
			Online.sign_out()
			_close_panels()
			_say("Signed out. You can still play online under any callsign.")
		else:
			_open_account(true))
	acct_secondary.custom_minimum_size = Vector2(150, 34)
	row.add_child(acct_secondary)

	account_panel = AccountPanel.new()
	add_child(account_panel)
	UiKit.fit_center(account_panel, AccountPanel.SIZE)
	account_panel.signed_in.connect(func(): _say("Signed in as %s." % Online.callsign))
	_build_record_panel()


func _card_in() -> void:
	await get_tree().process_frame
	if acct_card.visible:
		UiFx.slide_in(acct_card, 70.0, 0.5, 0.35)


## The account card (and the notices under it) give way to the panels that
## open on the right, which reach up into that corner.
func _side_panels_changed() -> void:
	var busy := false
	for p: Control in [op_panel, ms_panel, host_panel, rec_panel, ins_panel]:
		if p and p.visible:
			busy = true
	if acct_card:
		acct_card.visible = not busy
	if notices:
		notices.visible = not busy


func _spaced(text: String, fs: int, col: Color, spacing: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiFx.spaced(700, spacing))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


func _open_account(create := false) -> void:
	_close_panels()
	account_panel.open(create, name_edit.text)


func _on_account() -> void:
	var on := Online.signed_in()
	acct_badge.visible = on
	var waiting := Online.pending.size()
	if on:
		acct_name.text = Online.callsign if Online.callsign != "" else "Signed in"
		acct_line.text = Online.email
		if waiting > 0:
			acct_line.text += "  \u00b7  %d %s going on your record" % [waiting, "battle" if waiting == 1 else "battles"]
		acct_primary.text = "Service Record"
		acct_secondary.text = "Sign out"
	else:
		acct_name.text = "Not signed in"
		acct_line.text = "Sign in to keep your callsign, earn ranks and insignia, and keep a service record of every battle you fight."
		if waiting > 0:
			acct_line.text = "%d %s waiting for your service record: sign in to keep %s." % [waiting, "battle" if waiting == 1 else "battles", "it" if waiting == 1 else "them"]
		# players sign in with GitHub, on the website: the first time makes the account
		acct_primary.text = "Sign in with GitHub" if Online.web_sign_in else "Sign in"
		acct_secondary.text = "Create account"
	acct_secondary.visible = on or not Online.web_sign_in
	if on and Online.callsign != "":
		name_edit.text = Online.callsign
	name_edit.tooltip_text = ("Signed in as %s. Change it here to rename your account." % Online.email) if on else ""
	ins_tex.texture = Insignia.texture(Online.icon if on else Insignia.DEFAULT, 128)
	ins_tex.modulate = Color.WHITE if on else Color(1, 1, 1, 0.45)
	ins_btn.tooltip_text = ("Wearing %s. Open your insignia to pick another." % String(Insignia.find(Online.icon).get("n", ""))) if on else "Insignia: sign in to earn ranks and choose one."
	rank_label.text = ("%s  \u00b7  RANK %d" % [Insignia.rank_name(Online.rank).to_upper(), Online.rank]) if on else "RANKS AND INSIGNIA: CLICK THE PATCH"
	rank_label.add_theme_color_override("font_color", UiKit.ACCENT if on else UiKit.DIM)
	rank_label.tooltip_text = ("Rank %d of %d  \u00b7  %s" % [Online.rank, Insignia.MAX_RANK, _xp_text()]) if on else "Sign in and every battle you play earns XP towards the next rank."
	rank_bar.visible = on
	_set_bar(rank_bar)
	if ins_panel and ins_panel.visible:
		_refresh_insignia()
	if rec_panel and rec_panel.visible and not on:
		rec_panel.visible = false


# --- the service record ------------------------------------------------------------------

## Every battle fought signed in: the career's totals over the top, the
## battles newest first; open one for its after-action report.
func _build_record_panel() -> void:
	rec_panel = PanelContainer.new()
	UiFx.glass(rec_panel, 16.0, 24.0)
	rec_panel.anchor_top = 0.5
	rec_panel.anchor_bottom = 0.5
	rec_panel.offset_left = 640
	rec_panel.offset_right = 1300
	rec_panel.offset_top = -330
	rec_panel.offset_bottom = 340
	rec_panel.visible = false
	add_child(rec_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	rec_panel.add_child(v)
	v.add_child(_spaced("SERVICE RECORD", 13, UiKit.ACCENT, 4))
	rec_title = _spaced("", 26, UiKit.TEXT, 3)
	v.add_child(rec_title)
	rec_tiles = GridContainer.new()
	rec_tiles.columns = 3
	rec_tiles.add_theme_constant_override("h_separation", 8)
	rec_tiles.add_theme_constant_override("v_separation", 8)
	v.add_child(rec_tiles)
	v.add_child(_spaced("BATTLES", 11, UiKit.DIM, 3))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 4)
	sc.add_child(lv)
	rec_list = VBoxContainer.new()
	rec_list.add_theme_constant_override("separation", 4)
	lv.add_child(rec_list)
	rec_more = _btn("Older battles", func(): Sfx.ui("click"); _load_battles(false))
	rec_more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lv.add_child(rec_more)
	rec_msg = UiKit.label("", 13, UiKit.DIM)
	rec_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rec_msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	row.add_child(_btn("Close", func(): rec_panel.visible = false))
	# a battle's report opens over everything, the menu dimmed behind it
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.01, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	add_child(dim)
	rec_view = StatsPanel.new()
	rec_view.title = "AFTER-ACTION REPORT"
	rec_view.visible = false
	rec_view.closed.connect(func(): rec_view.visible = false)
	rec_view.visibility_changed.connect(func(): dim.visible = rec_view.visible)
	add_child(rec_view)
	UiKit.fit_center(rec_view, Vector2(1180, 820), 30.0)


func _open_record() -> void:
	if not Online.signed_in():
		_open_account()
		return
	_close_panels()
	rec_panel.visible = true
	UiFx.slide_in(rec_panel, 40.0, 0.32)
	Sfx.ui("ui_whoosh", -16.0)
	rec_title.text = Online.callsign.to_upper()
	_rec_tiles({})
	_load_battles(true)
	var n := _rec_n
	var r: Dictionary = await Online.career()
	if n != _rec_n or not rec_panel.visible:
		return
	if r.ok:
		_rec_tiles(r.data.get("career", {}))


## The career at a glance: battles, won, kills, K/D, average rating, time.
func _rec_tiles(c: Dictionary) -> void:
	for ch in rec_tiles.get_children():
		ch.queue_free()
	var n := int(c.get("battles", 0))
	var won := int(c.get("victories", 0))
	var lost := float(c.get("lost", 0))
	var kills := float(c.get("kills", 0))
	var rv := float(c.get("rating", 0))
	# [label, value (-1: none yet), how to write it, a word under it]
	var tiles := [
		["BATTLES", float(n), func(v: float) -> String: return "%d" % int(round(v)), ""],
		["WON", float(won), func(v: float) -> String: return "%d  (%d%%)" % [int(round(v)), int(round(100.0 * v / maxf(1.0, n)))], ""],
		["KILLS", kills, func(v: float) -> String: return StatsPanel.fmt_num(v), ""],
		["K/D", kills / maxf(1.0, lost), func(v: float) -> String: return "%.1f" % v, ""],
		["AVG RATING", rv, func(v: float) -> String: return "%d" % int(round(v)), BattleStats.rating_word(rv) if n > 0 else ""],
		["TIME IN BATTLE", float(c.get("seconds", 0)), func(v: float) -> String: return StatsPanel.fmt_time(v), ""],
	]
	for i in tiles.size():
		var t: Array = tiles[i]
		var p := PanelContainer.new()
		UiFx.glass(p, 7.0, 10.0)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		p.add_child(tv)
		tv.add_child(_spaced(String(t[0]), 9, UiKit.DIM, 2))
		var val := Label.new()
		val.add_theme_font_override("font", UiFx.digits(700))
		val.add_theme_font_size_override("font_size", 24)
		val.add_theme_color_override("font_color", StatsPanel.rating_col(rv) if t[0] == "AVG RATING" and n > 0 else UiKit.TEXT)
		tv.add_child(val)
		if c.is_empty() or n == 0:
			val.text = "-"
		else:
			UiFx.count(val, float(t[1]), t[2], 1.0, 0.1 + i * 0.07)
		if String(t[3]) != "":
			tv.add_child(_spaced(String(t[3]), 9, StatsPanel.rating_col(rv), 2))
		rec_tiles.add_child(p)
		if not c.is_empty():
			UiFx.slide_in(p, 0.0, 0.3, i * 0.05)


func _load_battles(fresh: bool) -> void:
	if fresh:
		_rec_n += 1
		_rec_before = ""
		for ch in rec_list.get_children():
			ch.queue_free()
	var n := _rec_n
	rec_more.visible = false
	rec_msg.add_theme_color_override("font_color", UiKit.DIM)
	rec_msg.text = "Loading your battles..."
	var r: Dictionary = await Online.battles(_rec_before)
	if n != _rec_n or not rec_panel.visible:
		return
	if not r.ok:
		rec_msg.add_theme_color_override("font_color", UiKit.BAD)
		rec_msg.text = String(r.error)
		return
	var bs: Array = r.data.get("battles", [])
	for i in bs.size():
		var row := _record_row(bs[i])
		rec_list.add_child(row)
		UiFx.slide_in(row, 36.0, 0.34, 0.12 + mini(i, 12) * 0.045)
	if not bs.is_empty():
		_rec_before = String(bs.back().get("played_at", ""))
	rec_more.visible = bool(r.data.get("more", false))
	var waiting := Online.pending.size()
	rec_msg.text = ""
	if rec_list.get_child_count() == 0 and bs.is_empty():
		rec_msg.text = "No battles on your record yet. Every battle you fight while signed in goes on it."
	if waiting > 0:
		rec_msg.text += ("  " if rec_msg.text != "" else "") + "%d more waiting to go up (they will when the matchmaker can be reached)." % waiting


## One battle on the record: how it ended, what it was, when, and how you did.
func _record_row(b: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 60)
	btn.focus_mode = Control.FOCUS_NONE
	var won_it := String(b.get("result", "")) == "victory"
	var res_col := UiKit.GOOD if won_it else UiKit.BAD
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	btn.draw.connect(func():
		var hot := 1.0 if btn.is_hovered() else 0.0
		UiFx.card(btn, Rect2(Vector2.ZERO, btn.size), 1.0, hot, UiFx.fade(res_col, 0.35) if hot > 0.0 else Color(1, 1, 1, 0.07))
		btn.draw_rect(Rect2(btn.size.x - 4.0, 8.0, 3.0, btn.size.y - 16.0), UiFx.fade(res_col, 0.7)))
	btn.mouse_entered.connect(btn.queue_redraw)
	btn.mouse_exited.connect(btn.queue_redraw)
	btn.tooltip_text = "Open the after-action report"
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -14
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(h)
	var won := String(b.get("result", "")) == "victory"
	var bar := ColorRect.new()
	bar.color = Defs.TEAM_COLORS[clampi(int(b.get("side", 0)), 0, 1)]
	bar.custom_minimum_size = Vector2(3, 0)
	h.add_child(bar)
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	left.add_child(top)
	top.add_child(UiKit.label("VICTORY" if won else "DEFEAT", 12, UiKit.GOOD if won else UiKit.BAD, 700))
	top.add_child(UiKit.label(String(b.get("title", "Battle")), 15, UiKit.TEXT, 600))
	left.add_child(UiKit.label("%s  \u00b7  %s  \u00b7  %s" % [_when(String(b.get("played_at", ""))), Defs.TEAM_NAMES[clampi(int(b.get("side", 0)), 0, 1)],
		StatsPanel.fmt_time(float(b.get("duration_s", 0)))], 11, UiKit.DIM))
	var kv := VBoxContainer.new()
	kv.alignment = BoxContainer.ALIGNMENT_CENTER
	kv.add_theme_constant_override("separation", 0)
	h.add_child(kv)
	var kl := UiKit.label("%d killed  /  %d lost" % [int(b.get("kills", 0)), int(b.get("lost", 0))], 13, UiKit.TEXT, 600)
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kv.add_child(kl)
	var vk := int(b.get("veh_kills", 0))
	var sub := UiKit.label(("%d vehicles destroyed" % vk) if vk > 0 else ("score %s" % StatsPanel.fmt_num(float(b.get("score", 0)))), 11, UiKit.DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kv.add_child(sub)
	var rv := float(b.get("rating", 0))
	var rt := VBoxContainer.new()
	rt.alignment = BoxContainer.ALIGNMENT_CENTER
	rt.add_theme_constant_override("separation", 0)
	rt.custom_minimum_size = Vector2(76, 0)
	h.add_child(rt)
	var rl := UiKit.label("%d" % int(round(rv)), 22, StatsPanel.rating_col(rv), 700)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rt.add_child(rl)
	var rw := UiKit.label(BattleStats.rating_word(rv), 10, UiKit.DIM)
	rw.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rt.add_child(rw)
	for c in h.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var id := String(b.get("id", ""))
	var heading := "%s  \u00b7  %s  \u00b7  %s" % [String(b.get("title", "Battle")), _when(String(b.get("played_at", ""))), "Victory" if won else "Defeat"]
	btn.pressed.connect(func(): Sfx.ui("click"); _open_battle(id, heading))
	return btn


func _open_battle(id: String, heading: String) -> void:
	rec_msg.add_theme_color_override("font_color", UiKit.DIM)
	rec_msg.text = "Opening the report..."
	var r: Dictionary = await Online.battle(id)
	if not r.ok:
		rec_msg.add_theme_color_override("font_color", UiKit.BAD)
		rec_msg.text = String(r.error)
		return
	rec_msg.text = ""
	var b: Dictionary = r.data.get("battle", {})
	var rep: Dictionary = b.get("report", {})
	if rep.is_empty() or (rep.get("players", []) as Array).is_empty():
		rec_msg.text = "That battle's report wasn't kept."
		return
	rec_view.fixed_sub = heading
	rec_view.show_tab("summary")
	rec_view.set_report(rep)
	rec_view.visible = true


## "16 Oct 2026, 21:04" in this computer's time, from the matchmaker's UTC.
func _when(iso: String) -> String:
	if iso.length() < 19:
		return iso
	var t := Time.get_unix_time_from_datetime_string(iso.substr(0, 19)) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(t)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s %d, %02d:%02d" % [int(d.day), months[clampi(int(d.month) - 1, 0, 11)], int(d.year), int(d.hour), int(d.minute)]


# --- the insignia ----------------------------------------------------------------------

## The insignia worn, beside the callsign: it opens the collection.
func _make_ins_btn() -> Button:
	ins_btn = Button.new()
	ins_btn.custom_minimum_size = Vector2(40, 40)
	ins_btn.focus_mode = Control.FOCUS_NONE
	ins_btn.add_theme_stylebox_override("normal", UiKit.box(Color(1, 1, 1, 0.03), 5, Color(1, 1, 1, 0.08), 1, 2.0))
	ins_btn.add_theme_stylebox_override("hover", UiKit.box(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.12), 5, UiKit.ACCENT, 1, 2.0))
	ins_btn.add_theme_stylebox_override("pressed", UiKit.box(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.2), 5, UiKit.ACCENT, 1, 2.0))
	ins_tex = _ins_rect(Insignia.DEFAULT, 36)
	ins_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ins_tex.offset_left = 2
	ins_tex.offset_top = 2
	ins_tex.offset_right = -2
	ins_tex.offset_bottom = -2
	ins_btn.add_child(ins_tex)
	ins_btn.pressed.connect(func(): Sfx.ui("click"); _open_insignia())
	return ins_btn


## An insignia as a picture `px` across ("" for none yet).
func _ins_rect(id: String, px: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Insignia.texture(id, 128) if id != "" else null
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tr


func _xp_bar(w: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(w, 5)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.add_theme_stylebox_override("background", UiKit.box(Color(1, 1, 1, 0.08), 3, Color(0, 0, 0, 0), 0, 0.0))
	bar.add_theme_stylebox_override("fill", UiKit.box(UiKit.ACCENT, 3, Color(0, 0, 0, 0), 0, 0.0))
	return bar


## How far through the rank the player is (full at the top rank).
func _set_bar(bar: ProgressBar) -> void:
	var top := Online.next_xp < 0
	bar.max_value = 1.0 if top else maxf(1.0, Online.next_xp - Online.rank_xp)
	bar.value = (1.0 if top else float(Online.xp - Online.rank_xp)) if Online.signed_in() else 0.0


func _xp_text() -> String:
	if Online.next_xp < 0:
		return "%s XP  \u00b7  TOP RANK" % Insignia.thousands(Online.xp)
	return "%s / %s XP" % [Insignia.thousands(Online.xp - Online.rank_xp), Insignia.thousands(Online.next_xp - Online.rank_xp)]


## The collection: who you are and how far you've come, then every insignia
## by group. The unlocked can be worn; the rest are shown, locked, with what
## unlocks them.
func _build_insignia_panel() -> void:
	ins_panel = PanelContainer.new()
	UiFx.glass(ins_panel, 16.0, 24.0)
	ins_panel.anchor_top = 0.5
	ins_panel.anchor_bottom = 0.5
	ins_panel.offset_left = 640
	ins_panel.offset_right = 1300
	ins_panel.offset_top = -330
	ins_panel.offset_bottom = 340
	ins_panel.visible = false
	add_child(ins_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	ins_panel.add_child(v)
	v.add_child(_spaced("INSIGNIA", 13, UiKit.ACCENT, 4))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var big := _ins_rect(Insignia.DEFAULT, 92)
	head.add_child(big)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 3)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(hv)
	var nm := UiKit.label("", 24, UiKit.TEXT, 600)
	hv.add_child(nm)
	var rk := UiKit.label("", 13, UiKit.ACCENT, 700)
	hv.add_child(rk)
	var bar := _xp_bar(330)
	hv.add_child(bar)
	var xpl := UiKit.label("", 12, UiKit.DIM)
	hv.add_child(xpl)
	var rec := UiKit.label("", 12, UiKit.DIM)
	rec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(rec)
	var sign := _btn("Sign in", func(): Sfx.ui("click"); _open_account())
	sign.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sign)
	_ins_head = {"icon": big, "name": nm, "rank": rk, "bar": bar, "xp": xpl, "record": rec, "sign": sign}
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for g in Insignia.GROUPS:
		var gh := HBoxContainer.new()
		gh.add_theme_constant_override("separation", 10)
		gh.custom_minimum_size = Vector2(0, 26)
		var gl := UiKit.label(String(g[1]).to_upper(), 11, UiKit.ACCENT, 700)
		gl.size_flags_vertical = Control.SIZE_SHRINK_END
		gh.add_child(gl)
		var gc := UiKit.label("", 11, UiKit.DIM, 600)
		gc.size_flags_vertical = Control.SIZE_SHRINK_END
		gh.add_child(gc)
		_ins_counts[g[0]] = gc
		list.add_child(gh)
		var gb := UiKit.label(String(g[2]), 12, UiKit.DIM)
		gb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(gb)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 5)
		flow.add_theme_constant_override("v_separation", 5)
		list.add_child(flow)
		for e: Dictionary in Insignia.all():
			if Insignia.group(String(e.id)) == g[0]:
				flow.add_child(_ins_tile(e))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	_ins_msg = UiKit.label("", 13, UiKit.DIM)
	_ins_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ins_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ins_msg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_ins_msg)
	foot.add_child(_btn("Close", func(): ins_panel.visible = false))


## One insignia in the collection. Its picture is drawn a few frames later
## (_process), so opening the collection never stalls the menu.
func _ins_tile(e: Dictionary) -> Button:
	var id := String(e.id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(54, 54)
	b.focus_mode = Control.FOCUS_NONE
	var tr := _ins_rect("", 46)
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 4
	tr.offset_top = 4
	tr.offset_right = -4
	tr.offset_bottom = -4
	tr.name = "Pic"
	b.add_child(tr)
	var lock := LockGlyph.new()
	lock.name = "Lock"
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.anchor_left = 1.0
	lock.anchor_right = 1.0
	lock.offset_left = -16
	lock.offset_top = 4
	lock.offset_right = -4
	lock.offset_bottom = 19
	b.add_child(lock)
	b.pressed.connect(func(): _pick_insignia(id))
	_ins_tiles[id] = b
	_ins_load.append(id)
	return b


func _open_insignia() -> void:
	_close_panels()
	_ins_msg.text = ""
	_refresh_insignia()
	ins_panel.visible = true
	UiFx.slide_in(ins_panel, 40.0, 0.32)
	Sfx.ui("ui_whoosh", -16.0)
	if Online.signed_in():
		Online.refresh_me()


func _process(_dt: float) -> void:
	# the collection's pictures, a few each frame while it's open
	if ins_panel and ins_panel.visible and not _ins_load.is_empty():
		for i in mini(8, _ins_load.size()):
			var id: String = _ins_load.pop_front()
			var t: Button = _ins_tiles[id]
			(t.get_node("Pic") as TextureRect).texture = Insignia.texture(id, 128)


## The collection as it stands: what's unlocked, what's worn.
func _refresh_insignia() -> void:
	var on := Online.signed_in()
	var rank := Online.rank if on else 0
	var worn := _ins_pending if _ins_pending != "" else (Online.icon if on else "")
	var h := _ins_head
	(h.icon as TextureRect).texture = Insignia.texture(worn if worn != "" else Insignia.DEFAULT, 128)
	(h.icon as TextureRect).modulate = Color.WHITE if on else Color(1, 1, 1, 0.45)
	(h.sign as Button).visible = not on
	if on:
		(h.name as Label).text = Online.callsign
		(h.rank as Label).text = "%s  \u00b7  RANK %d OF %d" % [Insignia.rank_name(rank).to_upper(), rank, Insignia.MAX_RANK]
		var nxt := "" if Online.next_xp < 0 else "  \u00b7  %s to %s" % [Insignia.thousands(Online.next_xp - Online.xp), Insignia.rank_name(rank + 1)]
		(h.xp as Label).text = _xp_text() + nxt
		(h.record as Label).text = "%d battles, %d won  \u00b7  wearing %s" % [Online.fought, Online.wins, String(Insignia.find(worn).get("n", ""))]
	else:
		(h.name as Label).text = "Not signed in"
		(h.rank as Label).text = "RANKS AND INSIGNIA"
		(h.xp as Label).text = "Sign in and play: every battle earns XP, and a win half as much again."
		(h.record as Label).text = "Fifty ranks from Recruit to General of the Army, each with its own patch."
	_set_bar(h.bar as ProgressBar)
	var have := {}
	var total := {}
	for e: Dictionary in Insignia.all():
		var id := String(e.id)
		var g := Insignia.group(id)
		var open := Insignia.unlocked(id, rank)
		total[g] = int(total.get(g, 0)) + 1
		if open:
			have[g] = int(have.get(g, 0)) + 1
		var t: Button = _ins_tiles[id]
		var sel := id == worn
		var bg := Color(1, 1, 1, 0.04) if open else Color(0, 0, 0, 0.25)
		var edge := UiKit.ACCENT if sel else Color(1, 1, 1, 0.07)
		var hov := UiKit.boxc(Color(UiKit.ACCENT.r, UiKit.ACCENT.g, UiKit.ACCENT.b, 0.14 if open else 0.05), 5, UiKit.ACCENT if sel or open else Color(1, 1, 1, 0.18), 2 if sel else 1, 0.0)
		t.add_theme_stylebox_override("normal", UiKit.boxc(bg, 5, edge, 2 if sel else 1, 0.0))
		t.add_theme_stylebox_override("hover", hov)
		t.add_theme_stylebox_override("pressed", hov)
		(t.get_node("Pic") as TextureRect).modulate = Color.WHITE if open else Color(0.5, 0.5, 0.5, 0.55)
		(t.get_node("Lock") as Control).visible = not open
		var how := "Wearing it." if sel else Insignia.unlock_text(id)
		if open and not sel:
			how += " Click to wear it." if on else " Sign in to wear it."
		t.tooltip_text = "%s\n%s\n%s" % [String(e.n), String(e.d), how]
	for g in Insignia.GROUPS:
		(_ins_counts[g[0]] as Label).text = "%d / %d UNLOCKED" % [int(have.get(g[0], 0)), int(total.get(g[0], 0))]


## Put an insignia on: shown at once, and taken back if the matchmaker says no.
func _pick_insignia(id: String) -> void:
	var e := Insignia.find(id)
	if not Online.signed_in():
		_ins_msg.text = "Sign in to wear an insignia. Every account starts with the ten starter patches."
		return
	if not Insignia.unlocked(id, Online.rank):
		_ins_msg.text = "%s: %s" % [String(e.n), Insignia.unlock_text(id)]
		return
	if id == Online.icon or _ins_pending != "":
		return
	Sfx.ui("click")
	_ins_pending = id
	_ins_msg.text = "Wearing %s." % String(e.n)
	_refresh_insignia()
	var r: Dictionary = await Online.set_icon(id)
	_ins_pending = ""
	if not r.ok:
		_ins_msg.text = String(r.error)
	_refresh_insignia()
	_on_account()


## A small padlock on the insignia not yet unlocked.
class LockGlyph extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var body := Rect2(w * 0.1, h * 0.44, w * 0.8, h * 0.52)
		var c := Vector2(w * 0.5, h * 0.44)
		draw_arc(c, w * 0.26, PI, TAU, 12, Color(0.05, 0.05, 0.05, 0.9), 4.2, true)
		draw_arc(c, w * 0.26, PI, TAU, 12, Color(0.86, 0.84, 0.76), 2.0, true)
		draw_rect(body.grow(1.2), Color(0.05, 0.05, 0.05, 0.9))
		draw_rect(body, Color(0.86, 0.84, 0.76))
		draw_circle(Vector2(w * 0.5, h * 0.66), w * 0.08, Color(0.2, 0.2, 0.18))
