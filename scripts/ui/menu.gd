extends Control
## Main menu, and the way into multiplayer: the server browser, hosting, the
## lobby, and the dialog that shows a join (or a host) getting there.
##
## The menu is up before the game's own classes have compiled (they compile
## behind the title: GameScripts), so it names none of them: the Field Manual
## and a battle's after-action report are loaded by path, the first time
## they're opened.

var name_edit: LineEdit
var status: Label
var main_box: VBoxContainer
var settings_panel: SettingsPanel  # built the first time it's opened (open_settings)
var manual: Control  # the Field Manual (FieldManual), built the first time it's opened (open_manual)
var backdrop: TopoBackdrop
var op_panel: PanelContainer
var ms_panel: PanelContainer  # the missions
var _ms_key := ""
var _ms_cards := {}
var _ms_detail: VBoxContainer
var _music_on := false
var _op_side := 0  # 0 Coalition, 1 Rebels, -1 observe
var _map_size := 1024
var _side_cards := {}  # side -> its row in the choice
var _mood_seg: UiSeg  # the time of day and weather
var _col: VBoxContainer
var _items: Array[Button] = []  # the column's entries (each marker says whether its panel is open)
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
var acct_line: Label  # battles waiting to go on the record (only when there are some)
var acct_xp: Label
var acct_primary: Button
var acct_secondary: Button
var rec_panel: PanelContainer  # the service record: career totals and every battle
var rec_title: Label
var rec_tiles: GridContainer
var rec_list: VBoxContainer
var rec_msg: Label
var rec_more: Button
var rec_view: Control  # one battle's after-action report (StatsPanel), opened from the record
var _rec_before := ""  # the oldest battle shown (for "older battles")
var _rec_n := 0  # the latest load (an older answer arriving late is dropped)
# the rank and the insignia: the one worn on the account card, and the collection
var ins_btn: Button
var ins_tex: TextureRect
var rank_label: Label
var rank_bar: Range  # (a StepBar)
var ins_panel: PanelContainer
var _ins_head: Dictionary = {}  # the collection's header: icon, name, rank, bar, xp, record
var _ins_tiles := {}  # id -> the tile's button
var _ins_counts := {}  # group -> its "7/50" count in the group's header
var _ins_msg: Label
var _ins_load: Array = []  # tiles still waiting for their picture (a few are drawn each frame)
var _ins_pending := ""  # an insignia being put on, until the matchmaker answers
var _mm_busy := false  # Find Match is working through battles
var _mm_tries: Array = []  # lobby ids it has tried this time
var _attempt := 0  # bumps with every join (or host) attempt, so stale answers and timeouts do nothing
var notices: VBoxContainer  # the cards in the top right, under the account: a newer release, a battle to rejoin
var rejoin_card: PanelContainer  # back into the battle we dropped out of (while there is one)

## The sides to choose from: the side, its name, what it is (the row's
## tooltip) and the same in a line of codes.
const SIDES := [
	[0, "COALITION", "A regular army. Tanks, IFVs, Humvees, attack helicopters, air strikes and artillery. Fewer men, better kit, long supply lines.", "REGULAR ARMY \u00b7 ARMOUR \u00b7 AIR \u00b7 ARTILLERY"],
	[1, "REBELS", "An insurgent militia. Technicals, BTRs, RPGs, FPV drones and tunnels under the town. Cheap, many and hard to pin down.", "MILITIA \u00b7 TECHNICALS \u00b7 RPGS \u00b7 DRONES \u00b7 TUNNELS"],
	[-1, "OBSERVE", "Two AI commanders fight it out. The director camera finds the action; take the camera any time.", "AI VS AI \u00b7 DIRECTOR CAMERA"],
]
const MOODS := [["random", "Random"], ["dawn", "Dawn"], ["day", "Midday"], ["golden", "Golden"], ["dusk", "Dusk"], ["overcast", "Overcast"], ["hazy", "Hazy"], ["rain", "Rain"], ["night", "Night"]]
const ITEM_W := 520.0  # the column's entries (and the rules beside its section names)
## Ranks as codes (SSG III), from the names Insignia gives them in full.
const RANK_CODES := {"Recruit": "RCT", "Private": "PVT", "Corporal": "CPL", "Sergeant": "SGT", "Staff Sergeant": "SSG",
	"Master Sergeant": "MSG", "Lieutenant": "LT", "Captain": "CPT", "Major": "MAJ", "Colonel": "COL", "Brigadier General": "BG",
	"Major General": "MG", "Lieutenant General": "LTG", "General": "GEN", "General of the Army": "GA"}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	visibility_changed.connect(_on_visibility)
	# the living map behind it all, darkened down the left so the menu reads
	backdrop = TopoBackdrop.new()
	backdrop.shade = 1.0
	add_child(backdrop)

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

	# main screen (docs/UI.md, the column): the sections, an entry for each
	# thing to do, and the callsign at the foot of the column
	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 0)
	main_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	main_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(main_box)
	main_box.add_child(_section("Command"))
	main_box.add_child(_big("Play vs AI", "Command one side against the AI commander", func(): _open_op(0),
		func() -> bool: return op_panel.visible and _op_side >= 0))
	main_box.add_child(_big("Missions", "Short operations with objectives, alone or in co-op", _open_missions,
		func() -> bool: return ms_panel.visible))
	main_box.add_child(_big("Watch AI Battle", "Two AI commanders fight; the camera finds the action", func(): _open_op(-1),
		func() -> bool: return op_panel.visible and _op_side < 0))
	main_box.add_child(_section("Multiplayer"))
	if OS.has_feature("web"):
		# a battle between players runs over direct connections (and hole
		# punching) a browser can't make, so the browser build plays alone
		main_box.add_child(_big("Get the Desktop Game", "Multiplayer and co-op need the desktop build",
			func(): OS.shell_open(Updater.WEBSITE_URL + "/#download")))
	else:
		main_box.add_child(_big("Server Browser", "Every battle being hosted, online and on your network", _open_browser))
		main_box.add_child(_big("Host a Battle", "Co-op against the AI, versus, or a mission with friends", func(): _open_host({}),
			func() -> bool: return host_panel.visible))
		main_box.add_child(_big("Find Match", "Straight into the best open battle, or host one to be found", _find_match))
	main_box.add_child(_section("Reference"))
	main_box.add_child(_big("Field Manual", "Every soldier, weapon, vehicle and work, with its numbers", func(): open_manual(),
		func() -> bool: return manual != null and manual.visible))
	main_box.add_child(_big("Settings", "Graphics, display, interface, controls and sound", open_settings,
		func() -> bool: return settings_panel != null and settings_panel.visible))
	if not OS.has_feature("web"):  # (a browser tab is closed, not quit)
		main_box.add_child(_big("Quit", "Back to the desktop", func(): get_tree().quit()))
	var foot_gap := Control.new()
	foot_gap.custom_minimum_size = Vector2(0, 20)
	foot_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_box.add_child(foot_gap)
	main_box.add_child(_row("Callsign", _make_name_edit()))

	status = UiKit.label("", 13, UiKit.BAD)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(460, 0)
	col.add_child(status)

	_build_op_panel()
	_build_mission_panel()
	_build_multiplayer()
	_build_account()
	_build_insignia_panel()
	# the join dialog stays over every panel
	move_child(dialog, -1)
	for p: Control in [op_panel, ms_panel, host_panel]:
		p.visibility_changed.connect(_mark_items)
	# the corner: the build and version in mono, faint
	var build := ("ALPHA V%s" % Updater.version) if Updater.is_release() else "DEV BUILD"
	var vi := Engine.get_version_info()
	var mk := Keys.label("manual").to_upper()
	var foot := UiKit.mono_label("%s  \u00b7  GODOT %d.%d.%d%s" % [build, int(vi.major), int(vi.minor), int(vi.patch),
		("  \u00b7  %s FIELD MANUAL IN BATTLE" % mk) if mk != "" else ""], 11, UiKit.FAINT)
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
	notices.add_theme_constant_override("separation", 8)
	notices.anchor_left = 1.0
	notices.anchor_right = 1.0
	notices.offset_left = -640
	notices.offset_right = -32
	notices.offset_top = 100  # under the account
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



## The Settings, over the menu: built the first time they're opened.
func open_settings() -> void:
	if settings_panel == null:
		settings_panel = SettingsPanel.new()
		settings_panel.visible = false
		settings_panel.closed.connect(func(): settings_panel.visible = false)
		add_child(settings_panel)
		UiKit.fit_center(settings_panel, Vector2(700, 600))
		_cover_menu(settings_panel)
	settings_panel.visible = true


## The Field Manual, over the menu, on a page if one's given (a category, an
## entry, a side: FieldManual.open). It shows the game's own soldiers and
## vehicles, so it's built the first time it's opened, once those have
## compiled (which this waits for, in the first seconds after the launch).
func open_manual(cat := "", key := "", side := -1) -> void:
	if manual == null:
		manual = GameScripts.load_script(GameScripts.FIELD_MANUAL).new()
		manual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		manual.offset_left = 40
		manual.offset_right = -40
		manual.offset_top = 36
		manual.offset_bottom = -36
		manual.visible = false
		manual.closed.connect(func(): manual.visible = false)
		add_child(manual)
		_cover_menu(manual)
	if cat != "":
		manual.open(cat, key, side)
	else:
		manual.visible = true


## The Field Manual and Settings cover the menu while they're open, account
## card, notices and footer too (added after them, those would sit on top),
## and light their entry's marker.
func _cover_menu(p: Control) -> void:
	p.visibility_changed.connect(_over_menu.bind(p))
	p.visibility_changed.connect(_mark_items)


## The menu comes in as the title lifts away: the wordmark fades up where the
## title left it, then the entries arrive one after another from the left.
func arrive() -> void:
	var tw := create_tween().set_parallel(true)
	var head: Array = _col.get_children().slice(0, 3)
	for i in head.size():
		var c: CanvasItem = head[i]
		c.modulate.a = 0.0
		tw.tween_property(c, "modulate:a", 1.0, 0.5).set_delay(0.12 + 0.035 * i)
	UiMotion.stagger(main_box.get_children(), Vector2(-1, 0), 0.3)


## The menu's music starts again each time it comes back.
func _on_visibility() -> void:
	if is_visible_in_tree() and acct_card:
		_card_in.call_deferred()
	if is_visible_in_tree() and not _music_on:
		_music_on = true
		Music.play_cue("menu")
	elif not is_visible_in_tree():
		_music_on = false


## A menu entry (docs/UI.md, the column): a square marker and the name in
## capitals. Under the cursor the row lights and what the entry does types on
## beside it; while its panel is open (`open` says so) the marker fills with
## the accent and the name turns accent.
func _big(text: String, sub: String, cb: Callable, open := Callable()) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(ITEM_W, 34)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.focus_mode = Control.FOCUS_NONE
	var n := UiKit.bare()
	var h := UiKit.box(UiKit.fa(UiKit.TEXT, 0.05), 0, Color(0, 0, 0, 0), 0, 0.0)
	for st in ["normal", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, n)
	for st in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, h)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24
	row.offset_right = -10
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var l := UiKit.caps(text, 17, UiKit.TEXT, 600, 1)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	var s := UiKit.label("", 12, UiKit.DIM)
	s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.clip_text = true
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(s)
	b.set_meta("name", l)
	b.set_meta("open", open)
	b.draw.connect(func():
		# the marker: a hollow square, filled while the entry's panel is open
		var y := roundf(b.size.y * 0.5) - 4.0
		if b.get_meta("on", false):
			b.draw_rect(Rect2(6, y, 9, 9), UiKit.ACCENT)
		else:
			b.draw_rect(Rect2(6.5, y + 0.5, 8, 8), UiKit.TEXT if b.is_hovered() else UiKit.RULE2, false, 1.0))
	b.mouse_entered.connect(func(): UiMotion.type_on(s, sub))
	b.mouse_exited.connect(func(): s.text = "")
	b.pressed.connect(func(): Sfx.ui("click"); cb.call())
	_items.append(b)
	return b


## The column's markers: which entry's panel is open.
func _mark_items() -> void:
	for b: Button in _items:
		var f: Callable = b.get_meta("open")
		var on := f.is_valid() and bool(f.call())
		b.set_meta("on", on)
		(b.get_meta("name") as Label).add_theme_color_override("font_color", UiKit.ACCENT if on else UiKit.TEXT)
		b.queue_redraw()


## A section of the column: its name in capitals and a rule running on.
func _section(text: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	v.add_child(gap)
	var h := UiKit.header(text)
	h.custom_minimum_size = Vector2(ITEM_W, 0)
	v.add_child(h)
	return v


# --- new operation -----------------------------------------------------------------------

## The operation panel (docs/UI.md, the work area): which side (or just
## watch), the time of day and weather, and Deploy.
func _build_op_panel() -> void:
	op_panel = _side_panel(1260, -190, 190)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	op_panel.add_child(v)
	v.add_child(UiKit.caps("New operation", 12, UiKit.ACCENT))
	v.add_child(_gap(18))
	v.add_child(UiKit.header("Side"))
	v.add_child(_gap(4))
	for sd in SIDES:
		var sv: int = sd[0]
		var row := _choice_row(String(sd[1]), String(sd[3]), Defs.TEAM_COLORS[sv] if sv >= 0 else UiKit.DIM)
		row.tooltip_text = String(sd[2])
		row.pressed.connect(func(): _pick_side(sv))
		v.add_child(row)
		_side_cards[sv] = row
	v.add_child(_gap(26))
	v.add_child(UiKit.header("Time and weather"))
	v.add_child(_gap(12))
	var names := []
	for m in MOODS:
		names.append(m[1])
	_mood_seg = UiSeg.make(names, 0, 11)
	_mood_seg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for i in MOODS.size():
		var mk: String = MOODS[i][0]
		(_mood_seg.get_child(i) as Button).tooltip_text = "A different time and weather each battle" if mk == "random" else String(Curtain.MOOD_TEXT.get(mk, ""))
	_mood_seg.changed.connect(func(i: int): _pick_mood(String(MOODS[i][0])))
	v.add_child(_mood_seg)
	if not OS.has_feature("web"):
		v.add_child(UiKit.label("Battlefield size", 15, UiKit.DIM, 600))
		var dimensions := OptionButton.new()
		for metres in [1024, 2048, 3072]:
			dimensions.add_item("%d x %d m" % [metres, metres], metres)
		dimensions.item_selected.connect(func(index: int): _map_size = dimensions.get_item_id(index))
		v.add_child(dimensions)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	var back := UiKit.button("Back", "quiet")
	back.pressed.connect(func(): op_panel.visible = false)
	var go := UiKit.primary_button("Deploy", 200, 40, 15)
	go.pressed.connect(func(): Sfx.ui("click"); _deploy())
	v.add_child(_actions(back, [go]))


## A gap of `h` pixels in a column.
func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


## A work area's actions along its foot (docs/UI.md): the way back quiet on
## the left, the rest on the right, the main one last.
func _actions(back: Button, rest: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(back)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	for b: Button in rest:
		row.add_child(b)
	return row


## A row of a choice (docs/UI.md, Row): a square marker in its colour, filled
## when it's the one chosen, the name in capitals and a line of codes, on a
## rule; `tail` (a figure) sits at its right end. The chosen row's name turns
## accent and an accent edge marks it.
func _choice_row(title: String, code: String, mark: Color, tail := "") -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 36)
	var n := UiKit.bare()
	var hv := UiKit.box(UiKit.fa(UiKit.TEXT, 0.05), 0, Color(0, 0, 0, 0), 0, 0.0)
	var on := UiKit.box(UiKit.fa(UiKit.ACCENT, 0.1), 0, Color(0, 0, 0, 0), 0, 0.0)
	for st in ["normal", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 30
	row.offset_right = -10
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var nm := UiKit.caps(title, 15, UiKit.TEXT, 600, 1)
	nm.custom_minimum_size = Vector2(124, 0)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nm)
	var cl := UiKit.mono_label(code, 11, UiKit.DIM)
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.clip_text = true
	cl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cl)
	if tail != "":
		var tl := UiKit.mono_label(tail, 12, UiKit.TEXT)
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tl)
	b.set_meta("name", nm)
	b.draw.connect(func():
		var y := b.size.y
		b.draw_rect(Rect2(0, y - 1.0, b.size.x, 1.0), UiKit.LINE)
		var my := roundf(y * 0.5) - 4.0
		if b.button_pressed:
			b.draw_rect(Rect2(0, 0, 2, y - 1.0), UiKit.ACCENT)
			b.draw_rect(Rect2(12, my, 9, 9), mark)
		else:
			b.draw_rect(Rect2(12.5, my + 0.5, 8, 8), mark, false, 1.0))
	return b


## A choice's row chosen or not (without its signal).
func _set_row(b: Button, on: bool) -> void:
	b.set_pressed_no_signal(on)
	(b.get_meta("name") as Label).add_theme_color_override("font_color", UiKit.ACCENT if on else UiKit.TEXT)
	b.queue_redraw()


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
	_settle(op_panel)
	UiMotion.arrive(op_panel, Vector2(1, 0))


func _pick_side(side: int) -> void:
	_op_side = side
	for k in _side_cards:
		_set_row(_side_cards[k], k == side)
	_mark_items()


func _pick_mood(m: String) -> void:
	var i := -1
	for j in MOODS.size():
		if String(MOODS[j][0]) == m:
			i = j
	if i < 0:
		m = "random"
		i = 0
	Settings.set_v("mood", m)
	_mood_seg.select(i)


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

## The missions: a row for each, the chosen one's briefing, and play it
## alone or host it for friends.
func _build_mission_panel() -> void:
	ms_panel = _side_panel(1260, -320, 330)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	ms_panel.add_child(v)
	v.add_child(UiKit.caps("Missions", 12, UiKit.ACCENT))
	v.add_child(_gap(18))
	v.add_child(UiKit.header("Operations", "%d" % MissionList.playable().size()))
	v.add_child(_gap(4))
	for m in MissionList.playable():
		# the side it's fought from by its marker, the operation as a code
		var op := String(m.op).to_upper().replace("OPERATION ", "OP ")
		var card := _choice_row(String(m.title), op, Defs.TEAM_COLORS[int(m.side)], "%d MIN" % int(m.mins))
		card.tooltip_text = "%s  \u00b7  %s" % [Defs.TEAM_NAMES[int(m.side)], String(m.blurb)]
		var key: String = m.key
		card.pressed.connect(func(): _pick_mission(key))
		v.add_child(card)
		_ms_cards[key] = card
	# the chosen mission's briefing: prose under a rule, then its facts
	v.add_child(_gap(26))
	v.add_child(UiKit.header("Briefing"))
	v.add_child(_gap(10))
	# (in a scroll, so a long briefing, or one picked while the panel shows,
	# scrolls rather than stretching the panel)
	var bsc := ScrollContainer.new()
	bsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(bsc)
	_ms_detail = VBoxContainer.new()
	_ms_detail.add_theme_constant_override("separation", 8)
	_ms_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bsc.add_child(_ms_detail)
	var back := UiKit.button("Back", "quiet")
	back.pressed.connect(func(): ms_panel.visible = false)
	var rest := []
	if not OS.has_feature("web"):
		var co := UiKit.button("Host co-op", "secondary", 150, 40)
		co.pressed.connect(func(): Sfx.ui("click"); _mission_coop())
		co.tooltip_text = "Host this mission for friends: it's listed in the server browser, and they share your force."
		rest.append(co)
	var go := UiKit.primary_button("Play solo", 180, 40, 15)
	go.pressed.connect(func(): Sfx.ui("click"); _mission_solo())
	rest.append(go)
	v.add_child(_actions(back, rest))


func _open_missions() -> void:
	_close_panels()
	if _ms_key == "":
		_ms_key = String(MissionList.playable()[0].key)
	_pick_mission(_ms_key)
	ms_panel.visible = true
	_settle(ms_panel)
	UiMotion.arrive(ms_panel, Vector2(1, 0))


func _pick_mission(key: String) -> void:
	_ms_key = key
	for k in _ms_cards:
		_set_row(_ms_cards[k], k == key)
	for c in _ms_detail.get_children():
		c.queue_free()
	var m := MissionList.find(key)
	var bl := UiKit.label(String(m.blurb), 15, UiKit.TEXT, 500)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ms_detail.add_child(bl)
	var br := UiKit.label(String(m.brief), 13, UiKit.DIM)
	br.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ms_detail.add_child(br)
	_ms_detail.add_child(_gap(4))
	# the facts: a label in faint capitals, its value in mono
	for kv in [["Side", Defs.TEAM_NAMES[int(m.side)].to_upper()], ["Force", m.force], ["Area", m.area],
			["Conditions", Curtain.MOOD_TEXT.get(String(m.mood), "")]]:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 12)
		var k := UiKit.caps(String(kv[0]), 11, UiKit.FAINT)
		k.custom_minimum_size = Vector2(96, 0)
		r.add_child(k)
		var val := UiKit.mono_label(String(kv[1]), 12, UiKit.TEXT)
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(val)
		_ms_detail.add_child(r)


func _mission_solo() -> void:
	var m := MissionList.find(_ms_key)
	ms_panel.visible = false
	if not OS.has_feature("web"):
		var local_err := LocalServer.launch({"mission": _ms_key, "ai_fill": true}, int(m.side))
		status.text = "Starting simulation..." if local_err == OK else "Could not start the mission (error %d)." % local_err
		return
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
	# a mono line over a rule (the theme's field), the accent while it's edited
	name_edit.custom_minimum_size = Vector2(220, 30)
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


## A field with its label: faint capitals beside the field's underline.
func _row(label: String, w: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var l := UiKit.caps(label, 11, UiKit.FAINT)
	l.custom_minimum_size = Vector2(24, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	h.add_child(w)
	return h


## `p` over everything else on the menu while it shows, under the join dialog.
func _over_menu(p: Control) -> void:
	if p.visible:
		move_child(p, -1)
		move_child(dialog, -1)


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
	UiMotion.arrive(lobby, Vector2(0, 1))
	lobby.reset()


## The host told us who's in the lobby: that's when a join has worked (and
## not before - a host that wants a password, or is full, turns us away first).
func _on_lobby_updated() -> void:
	if LocalServer.starting or Net.in_game or not visible or lobby.visible or multiplayer.is_server():
		return
	if Net.players.has(multiplayer.get_unique_id()) and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		if _join_target.is_empty():
			# a join the player had already cancelled got through after all
			Net.leave()
			return
		_show_lobby()


func _single_player(side := 0) -> void:
	if not OS.has_feature("web"):
		var local_err := LocalServer.launch({"ai_fill": true, "map_size": _map_size}, side)
		status.text = "Starting simulation..." if local_err == OK else "Could not start a local game (error %d)." % local_err
		return
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
	if not OS.has_feature("web"):
		var local_err := LocalServer.launch({"ai_fill": true, "map_size": _map_size}, -1)
		status.text = "Starting simulation..." if local_err == OK else "Could not start (error %d)." % local_err
		return
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
	host_panel.set_meta("place", [-305.0, 315.0])
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
	var layout := func():
		UiMotion.finish_arrive(c)
		# Leave more of a narrow window for the screen, not the decorative
		# margins. These are logical pixels, after the interface scale.
		var inset := clampf((size.x - 1200.0) * 0.5, 16.0, 72.0)
		c.offset_left = inset
		c.offset_right = -inset
		c.offset_top = clampf(size.y - 540.0, 16.0, 196.0)
		c.offset_bottom = -minf(56.0, size.y * 0.065)
	resized.connect(layout)
	layout.call()


func _open_browser() -> void:
	_close_panels()
	main_box.visible = false
	status.text = ""
	browser.visible = true
	UiMotion.arrive(browser, Vector2(0, 1))


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
	_settle(host_panel)
	UiMotion.arrive(host_panel, Vector2(1, 0))


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
		side = int(MissionList.find(mk).side)
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

## While the battle we were last in may still be going (Net.rejoin), a line
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
	var when := "JUST NOW" if mins < 1 else ((("%d MIN" % mins) if mins < 90 else ("%d H" % int(mins / 60.0))) + " AGO")
	rejoin_card = _notice("Battle in progress", ("%s \u00b7 LEFT %s" % [host.to_upper(), when]) if host != "" else "LEFT %s" % when, false)
	rejoin_card.tooltip_text = "You left %s %s. It may still be going: rejoin as the player you were." % [("%s's battle" % host) if host != "" else "a battle", when.to_lower()]
	var h: HBoxContainer = rejoin_card.get_meta("row")
	var forget := UiKit.button("Forget", "quiet", 0, 26)
	forget.pressed.connect(func(): Net.forget_rejoin(); _refresh_rejoin())
	h.add_child(forget)
	var go := UiKit.primary_button("Rejoin", 0, 26, 12)
	go.pressed.connect(_rejoin)
	h.add_child(go)
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
## so it's worth the space: one line of codes and its buttons.
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
	var h: HBoxContainer = p.get_meta("row")
	var line: Label = p.get_meta("code")
	var ver := "V%s" % Updater.latest
	var website := func(): OS.shell_open(Updater.WEBSITE_URL + "/#download")
	# that version's changelog on the website: what the update brings
	var whats_new := func(): OS.shell_open(Updater.WEBSITE_URL + "/changelog/#v" + Updater.latest)
	match Updater.state:
		Updater.State.AVAILABLE:
			line.text = "%s OUT" % ver
			p.tooltip_text = "Frontline v%s is out (you have v%s)." % [Updater.latest, Updater.version]
			h.add_child(_notice_btn("What's new", whats_new))
			h.add_child(_notice_btn("Download", website))
		Updater.State.DOWNLOADING:
			# the percentage ticks along while the menu shows it
			var t := Timer.new()
			t.wait_time = 0.25
			t.autostart = true
			t.timeout.connect(func(): line.text = "%s DOWNLOADING %d%%" % [ver, int(Updater.progress() * 100.0)])
			p.add_child(t)
			line.text = "%s DOWNLOADING" % ver
			(p.get_meta("sep") as Control).visible = false  # (nothing to press meanwhile)
			p.tooltip_text = "Downloading Frontline v%s." % Updater.latest
		Updater.State.READY:
			line.text = "%s READY" % ver
			p.tooltip_text = "Frontline v%s is installed. Restart to play it." % Updater.latest
			h.add_child(_notice_btn("What's new", whats_new))
			var go := UiKit.primary_button("Restart", 0, 26, 12)
			go.pressed.connect(func(): Updater.restart())
			h.add_child(go)
		Updater.State.FAILED:
			line.text = "%s UPDATE FAILED" % ver
			p.set_meta("why", "Couldn't update to v%s: %s" % [Updater.latest, Updater.error])
			h.add_child(_notice_btn("Download", website))
	# why it failed, in words, under the line
	if p.has_meta("why"):
		var why := UiKit.label(String(p.get_meta("why")), 12, UiKit.DIM)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		why.custom_minimum_size = Vector2(420, 0)
		(p.get_child(0) as VBoxContainer).add_child(why)
	if acct_card:
		_side_panels_changed()


## A line for the top right, under the account (docs/UI.md, the corner): a
## label in capitals and a code in mono (bad: in red), then a rule and room
## for buttons. The row they go in, and the code, are its metas "row" and "code".
func _notice(head_text: String, code: String, bad: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.bare())
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(h)
	if head_text != "":
		var hl := UiKit.caps(head_text, 11, UiKit.FAINT)
		hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(hl)
	var cl := UiKit.mono_label(code, 12, UiKit.BAD if bad else UiKit.ACCENT)
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cl)
	var sep := UiKit.mono_label("\u00b7", 12, UiKit.FAINT)
	sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sep)
	p.set_meta("row", h)
	p.set_meta("code", cl)
	p.set_meta("sep", sep)
	return p


## A notice's button: small, an outline in capitals.
func _notice_btn(text: String, cb: Callable) -> Button:
	var b := UiKit.button(text, "secondary", 0, 26)
	b.pressed.connect(cb)
	return b


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


## A panel on the right of the menu, where the new-operation panel sits (the
## work area: flat ink, marked by the accent's corner ticks), reaching from
## the column to `right` and from `top` to `bottom` about the middle.
func _side_panel(right: float, top: float, bottom: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.frame_hot(26.0, 0.9))
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = 640
	p.offset_right = right
	p.offset_top = top
	p.offset_bottom = bottom
	p.set_meta("place", [top, bottom])
	p.visible = false
	add_child(p)
	return p


## A panel on the right that has just opened, back at its place a frame later.
## Wrapped lines are measured only once they're laid out showing (until then
## each is a letter wide and thousands of pixels tall), and a panel they've
## stretched never shrinks back on its own; it's kept unseen until it's back.
func _settle(p: Control) -> void:
	var place: Array = p.get_meta("place", [])
	if place.is_empty():
		return
	p.modulate.a = 0.0
	await get_tree().process_frame
	p.offset_top = float(place[0])
	p.offset_bottom = float(place[1])
	p.modulate.a = 1.0


# --- the account ----------------------------------------------------------------------

## The account: a line top right that says who you are (or how to sign in),
## the sign-in form, and the service record.
func _build_account() -> void:
	acct_card = PanelContainer.new()
	acct_card.add_theme_stylebox_override("panel", UiKit.bare())
	acct_card.anchor_left = 1.0
	acct_card.anchor_right = 1.0
	acct_card.offset_left = -640
	acct_card.offset_right = -32
	acct_card.offset_top = 30
	acct_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(acct_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	acct_card.add_child(v)
	# one line: the patch worn, the callsign with the rank and XP under it,
	# then what there is to do (signed out: NOT SIGNED IN and Sign in)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	row.add_child(_make_ins_btn())
	ins_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 2)
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(wv)
	acct_name = UiKit.caps("", 15, UiKit.TEXT, 600, 1)
	wv.add_child(acct_name)
	var rk := HBoxContainer.new()
	rk.add_theme_constant_override("separation", 8)
	wv.add_child(rk)
	rank_label = UiKit.mono_label("", 11, UiKit.DIM)
	rank_label.mouse_filter = Control.MOUSE_FILTER_PASS
	rk.add_child(rank_label)
	rank_bar = _xp_bar(10)
	rank_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rk.add_child(rank_bar)
	acct_xp = UiKit.mono_label("", 11, UiKit.FAINT)
	acct_xp.mouse_filter = Control.MOUSE_FILTER_PASS
	rk.add_child(acct_xp)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(4, 0)
	row.add_child(gap)
	acct_primary = UiKit.button("", "secondary", 0, 30)
	acct_primary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	acct_primary.pressed.connect(func():
		Sfx.ui("click")
		if Online.signed_in():
			_open_record()
		else:
			_open_account())
	row.add_child(acct_primary)
	acct_secondary = UiKit.button("", "quiet", 0, 30)
	acct_secondary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	acct_secondary.pressed.connect(func():
		Sfx.ui("click")
		if Online.signed_in():
			Online.sign_out()
			_close_panels()
			_say("Signed out. You can still play online under any callsign.")
		else:
			_open_account(true))
	row.add_child(acct_secondary)
	# battles waiting to go on the record, when there are any
	acct_line = UiKit.label("", 12, UiKit.DIM)
	acct_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(acct_line)

	account_panel = AccountPanel.new()
	add_child(account_panel)
	UiKit.fit_center(account_panel, AccountPanel.SIZE)
	account_panel.signed_in.connect(func(): _say("Signed in as %s." % Online.callsign))
	_build_record_panel()


func _card_in() -> void:
	await get_tree().process_frame
	if acct_card.visible:
		UiFx.slide_in(acct_card, 70.0, 0.5, 0.35)


## The account line (and the notices under it) give way to the panels that
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


func _open_account(create := false) -> void:
	_close_panels()
	account_panel.open(create, name_edit.text)


func _on_account() -> void:
	var on := Online.signed_in()
	var waiting := Online.pending.size()
	acct_name.text = (Online.callsign if Online.callsign != "" else "Signed in") if on else "Not signed in"
	acct_name.add_theme_font_size_override("font_size", 15 if on else 12)
	acct_name.add_theme_color_override("font_color", UiKit.TEXT if on else UiKit.FAINT)
	acct_line.text = ""
	if waiting > 0:
		var n := "%d %s" % [waiting, "battle" if waiting == 1 else "battles"]
		acct_line.text = ("%s going on your record" % n) if on else "%s waiting for your record: sign in to keep %s." % [n, "it" if waiting == 1 else "them"]
	acct_line.visible = acct_line.text != ""
	acct_card.tooltip_text = ("Signed in as %s." % Online.email) if on else "Sign in to keep your callsign, earn ranks and insignia, and keep a service record of every battle you fight."
	if on:
		acct_primary.text = "RECORD"
		acct_primary.tooltip_text = "Your service record: every battle you've fought signed in"
		acct_secondary.text = "SIGN OUT"
	else:
		# players sign in with GitHub, on the website: the first time makes the account
		acct_primary.text = "SIGN IN WITH GITHUB" if Online.web_sign_in else "SIGN IN"
		acct_primary.tooltip_text = ""
		acct_secondary.text = "CREATE ACCOUNT"
	acct_secondary.visible = on or not Online.web_sign_in
	if on and Online.callsign != "":
		name_edit.text = Online.callsign
	name_edit.tooltip_text = ("Signed in as %s. Change it here to rename your account." % Online.email) if on else ""
	ins_tex.texture = Insignia.texture(Online.icon if on else Insignia.DEFAULT, 128)
	ins_tex.modulate = Color.WHITE if on else Color(1, 1, 1, 0.45)
	ins_btn.tooltip_text = ("Wearing %s. Open your insignia to pick another." % String(Insignia.find(Online.icon).get("n", ""))) if on else "Insignia: sign in to earn ranks and choose one."
	rank_label.text = _rank_code(Online.rank) if on else ""
	rank_label.tooltip_text = ("%s  \u00b7  rank %d of %d  \u00b7  %s" % [Insignia.rank_name(Online.rank), Online.rank, Insignia.MAX_RANK, _xp_text()]) if on else ""
	acct_xp.text = _xp_text() if on else ""
	acct_xp.tooltip_text = rank_label.tooltip_text
	rank_label.get_parent().visible = on
	_set_bar(rank_bar)
	if ins_panel and ins_panel.visible:
		_refresh_insignia()
	if rec_panel and rec_panel.visible and not on:
		rec_panel.visible = false


## A rank as a code: SSG III for Staff Sergeant III, GEN for General.
static func _rank_code(r: int) -> String:
	var n := Insignia.rank_name(r)
	var grade := ""
	var sp := n.rfind(" ")
	if sp > 0 and n.substr(sp + 1) in ["I", "II", "III", "IV", "V"]:
		grade = n.substr(sp)
		n = n.substr(0, sp)
	return String(RANK_CODES.get(n, n.to_upper())) + grade


# --- the service record ------------------------------------------------------------------

## Every battle fought signed in: the career's totals over the top, the
## battles newest first; open one for its after-action report.
func _build_record_panel() -> void:
	rec_panel = _side_panel(1300, -330, 340)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	rec_panel.add_child(v)
	v.add_child(UiKit.caps("Service record", 12, UiKit.ACCENT))
	v.add_child(_gap(6))
	rec_title = UiKit.caps("", 22, UiKit.TEXT, 600, 2)
	v.add_child(rec_title)
	v.add_child(_gap(16))
	# the career: a label over its figure, no boxes
	rec_tiles = GridContainer.new()
	rec_tiles.columns = 3
	rec_tiles.add_theme_constant_override("h_separation", 24)
	rec_tiles.add_theme_constant_override("v_separation", 14)
	v.add_child(rec_tiles)
	v.add_child(_gap(22))
	v.add_child(UiKit.header("Battles"))
	v.add_child(_gap(4))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 6)
	sc.add_child(lv)
	rec_list = VBoxContainer.new()
	rec_list.add_theme_constant_override("separation", 0)
	lv.add_child(rec_list)
	rec_more = UiKit.button("Older battles", "quiet")
	rec_more.pressed.connect(func(): Sfx.ui("click"); _load_battles(false))
	rec_more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lv.add_child(rec_more)
	rec_msg = UiKit.label("", 13, UiKit.DIM)
	rec_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rec_msg)
	v.add_child(_gap(10))
	var close := UiKit.button("Close", "quiet")
	close.pressed.connect(func(): rec_panel.visible = false)
	v.add_child(_actions(close, []))


func _open_record() -> void:
	if not Online.signed_in():
		_open_account()
		return
	_close_panels()
	rec_panel.visible = true
	_settle(rec_panel)
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
		["WON", float(won), func(v: float) -> String: return "%d \u00b7 %d%%" % [int(round(v)), int(round(100.0 * v / maxf(1.0, n)))], ""],
		["KILLS", kills, func(v: float) -> String: return UiKit.fmt_num(v), ""],
		["K/D", kills / maxf(1.0, lost), func(v: float) -> String: return "%.1f" % v, ""],
		["AVG RATING", rv, func(v: float) -> String: return "%d" % int(round(v)), UiKit.rating_word(rv) if n > 0 else ""],
		["TIME IN BATTLE", float(c.get("seconds", 0)), func(v: float) -> String: return UiKit.fmt_time(v), ""],
	]
	for i in tiles.size():
		var t: Array = tiles[i]
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lh := HBoxContainer.new()
		lh.add_theme_constant_override("separation", 8)
		tv.add_child(lh)
		lh.add_child(UiKit.caps(String(t[0]), 11, UiKit.FAINT))
		if String(t[3]) != "":
			lh.add_child(UiKit.caps(String(t[3]), 11, UiKit.rating_col(rv)))
		var val := UiKit.mono_label("", 24, UiKit.rating_col(rv) if t[0] == "AVG RATING" and n > 0 else UiKit.TEXT)
		tv.add_child(val)
		if c.is_empty() or n == 0:
			val.text = "-"
		else:
			UiFx.count(val, float(t[1]), t[2], 1.0, 0.1 + i * 0.07)
		rec_tiles.add_child(tv)


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
		UiMotion.arrive(row, Vector2(0, 1), mini(i, 7) * UiMotion.STAGGER, UiMotion.TRAVEL_SM)
	if not bs.is_empty():
		_rec_before = String(bs.back().get("played_at", ""))
	rec_more.visible = bool(r.data.get("more", false))
	var waiting := Online.pending.size()
	rec_msg.text = ""
	if rec_list.get_child_count() == 0 and bs.is_empty():
		rec_msg.text = "No battles on your record yet. Every battle you fight while signed in goes on it."
	if waiting > 0:
		rec_msg.text += ("  " if rec_msg.text != "" else "") + "%d more waiting to go up (they will when the matchmaker can be reached)." % waiting


## One battle on the record, a ruled row: the side it was fought on (its
## marker), how it ended, what it was and when, and how you did in figures.
## Open it for its after-action report.
func _record_row(b: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.focus_mode = Control.FOCUS_NONE
	var won := String(b.get("result", "")) == "victory"
	var side := clampi(int(b.get("side", 0)), 0, 1)
	var side_col: Color = Defs.TEAM_COLORS[side]
	var hv := UiKit.box(UiKit.fa(UiKit.TEXT, 0.05), 0, Color(0, 0, 0, 0), 0, 0.0)
	for st in ["normal", "disabled", "focus"]:
		btn.add_theme_stylebox_override(st, UiKit.bare())
	for st in ["hover", "pressed", "hover_pressed"]:
		btn.add_theme_stylebox_override(st, hv)
	btn.draw.connect(func():
		var y := btn.size.y
		btn.draw_rect(Rect2(0, y - 1.0, btn.size.x, 1.0), UiKit.LINE)
		btn.draw_rect(Rect2(8, roundf(y * 0.5) - 4.0, 9, 9), side_col))
	btn.tooltip_text = "Open the after-action report"
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 30
	h.offset_right = -10
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(h)
	var res := UiKit.caps("Victory" if won else "Defeat", 11, UiKit.GOOD if won else UiKit.BAD)
	res.custom_minimum_size = Vector2(62, 0)
	res.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(res)
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	left.add_child(UiKit.caps(String(b.get("title", "Battle")), 14, UiKit.TEXT, 600, 1))
	left.add_child(UiKit.mono_label("%s  \u00b7  %s  \u00b7  %s" % [_when(String(b.get("played_at", ""))).to_upper().replace(",", ""),
		Defs.TEAM_NAMES[side].to_upper(), UiKit.fmt_time(float(b.get("duration_s", 0)))], 11, UiKit.FAINT))
	var kv := VBoxContainer.new()
	kv.alignment = BoxContainer.ALIGNMENT_CENTER
	kv.add_theme_constant_override("separation", 1)
	h.add_child(kv)
	var kl := UiKit.mono_label("%d KILLED \u00b7 %d LOST" % [int(b.get("kills", 0)), int(b.get("lost", 0))], 12, UiKit.TEXT)
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kv.add_child(kl)
	var vk := int(b.get("veh_kills", 0))
	var sub := UiKit.mono_label(("%d VEHICLES" % vk) if vk > 0 else ("SCORE %s" % UiKit.fmt_num(float(b.get("score", 0)))), 11, UiKit.FAINT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kv.add_child(sub)
	var rv := float(b.get("rating", 0))
	var rt := VBoxContainer.new()
	rt.alignment = BoxContainer.ALIGNMENT_CENTER
	rt.add_theme_constant_override("separation", 0)
	rt.custom_minimum_size = Vector2(70, 0)
	h.add_child(rt)
	var rl := UiKit.mono_label("%d" % int(round(rv)), 20, UiKit.rating_col(rv))
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rt.add_child(rl)
	var rw := UiKit.caps(UiKit.rating_word(rv), 10, UiKit.FAINT)
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
	if rec_view == null:
		_make_rec_view()
	rec_view.fixed_sub = heading
	rec_view.show_tab("summary")
	rec_view.set_report(rep)
	rec_view.visible = true


## A battle's report opens over everything, the menu dimmed behind it (just
## above the record it's opened from). It's the battle's own after-action report
## (StatsPanel), so it's built the first time one's opened: GameScripts.
func _make_rec_view() -> void:
	var dim := ColorRect.new()
	dim.color = UiKit.fa(UiKit.INK, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	add_child(dim)
	move_child(dim, rec_panel.get_index() + 1)
	rec_view = GameScripts.load_script(GameScripts.STATS_PANEL).new()
	rec_view.title = "AFTER-ACTION REPORT"
	rec_view.visible = false
	rec_view.closed.connect(func(): rec_view.visible = false)
	rec_view.visibility_changed.connect(func(): dim.visible = rec_view.visible)
	add_child(rec_view)
	move_child(rec_view, dim.get_index() + 1)
	UiKit.fit_center(rec_view, Vector2(1180, 820), 30.0)


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
	ins_btn.add_theme_stylebox_override("normal", UiKit.bare(2.0))
	ins_btn.add_theme_stylebox_override("hover", UiKit.box(UiKit.fa(UiKit.TEXT, 0.05), 0, UiKit.RULE2, 1, 2.0))
	ins_btn.add_theme_stylebox_override("pressed", UiKit.box(UiKit.fa(UiKit.TEXT, 0.05), 0, UiKit.ACCENT, 1, 2.0))
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


## The way through a rank as a counted bar of `steps` steps.
func _xp_bar(steps: int, sw := 5.0, h := 6.0) -> StepBar:
	var bar := StepBar.new()
	bar.count = steps
	bar.step_w = sw
	bar.step_h = h
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return bar


## How far through the rank the player is (full at the top rank).
func _set_bar(bar: Range) -> void:
	var top := Online.next_xp < 0
	bar.max_value = 1.0 if top else maxf(1.0, Online.next_xp - Online.rank_xp)
	bar.value = (1.0 if top else float(Online.xp - Online.rank_xp)) if Online.signed_in() else 0.0


func _xp_text() -> String:
	if Online.next_xp < 0:
		return "%s XP \u00b7 TOP RANK" % Insignia.thousands(Online.xp)
	return "%s/%s XP" % [Insignia.thousands(Online.xp - Online.rank_xp), Insignia.thousands(Online.next_xp - Online.rank_xp)]


## The collection: who you are and how far you've come, then every insignia
## by group. The unlocked can be worn; the rest are shown, locked, with what
## unlocks them.
func _build_insignia_panel() -> void:
	ins_panel = _side_panel(1300, -330, 340)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	ins_panel.add_child(v)
	v.add_child(UiKit.caps("Insignia", 12, UiKit.ACCENT))
	v.add_child(_gap(12))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	var big := _ins_rect(Insignia.DEFAULT, 92)
	head.add_child(big)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(hv)
	var nm := UiKit.caps("", 22, UiKit.TEXT, 600, 2)
	hv.add_child(nm)
	var rk := UiKit.mono_label("", 12, UiKit.ACCENT)
	hv.add_child(rk)
	var bar := _xp_bar(30, 7.0, 8.0)
	hv.add_child(bar)
	var xpl := UiKit.mono_label("", 11, UiKit.DIM)
	xpl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(xpl)
	var rec := UiKit.mono_label("", 11, UiKit.FAINT)
	rec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(rec)
	var sign := UiKit.button("Sign in", "secondary", 0, 30)
	sign.pressed.connect(func(): Sfx.ui("click"); _open_account())
	sign.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sign)
	_ins_head = {"icon": big, "name": nm, "rank": rk, "bar": bar, "xp": xpl, "record": rec, "sign": sign}
	v.add_child(_gap(16))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for g in Insignia.GROUPS:
		# each group: a header with how many are unlocked, what they're for, the patches
		if list.get_child_count() > 0:
			list.add_child(_gap(8))
		var gh := UiKit.header(String(g[1]), "0/0")
		_ins_counts[g[0]] = gh.get_node("Count")
		list.add_child(gh)
		var gb := UiKit.label(String(g[2]), 12, UiKit.FAINT)
		gb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(gb)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 5)
		flow.add_theme_constant_override("v_separation", 5)
		list.add_child(flow)
		for e: Dictionary in Insignia.all():
			if Insignia.group(String(e.id)) == g[0]:
				flow.add_child(_ins_tile(e))
	v.add_child(_gap(12))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	var close := UiKit.button("Close", "quiet")
	close.pressed.connect(func(): ins_panel.visible = false)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(close)
	_ins_msg = UiKit.label("", 13, UiKit.DIM)
	_ins_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ins_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ins_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ins_msg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_ins_msg)


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
	_settle(ins_panel)
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
	(h.rank as Label).visible = on
	(h.bar as Control).visible = on
	if on:
		(h.name as Label).text = Online.callsign
		(h.rank as Label).text = "%s \u00b7 RANK %d/%d" % [_rank_code(rank), rank, Insignia.MAX_RANK]
		var nxt := "" if Online.next_xp < 0 else " \u00b7 %s TO %s" % [Insignia.thousands(Online.next_xp - Online.xp), _rank_code(rank + 1)]
		(h.xp as Label).text = _xp_text() + nxt
		(h.record as Label).text = ("%d BATTLES \u00b7 %d WON \u00b7 WEARING %s" % [Online.fought, Online.wins, String(Insignia.find(worn).get("n", ""))]).to_upper()
	else:
		(h.name as Label).text = "Not signed in"
		(h.xp as Label).text = "Sign in and play: every battle earns XP, and a win half as much again."
		(h.record as Label).text = "Fifty ranks from Recruit to General of the Army, each with its own patch."
	# figures in mono while signed in; signed out, the two lines are sentences
	for l: Label in [h.xp, h.record]:
		l.add_theme_font_override("font", UiKit.mono() if on else UiKit.font())
		l.add_theme_font_size_override("font_size", 11 if on else 12)
	_set_bar(h.bar as Range)
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
		# square tiles on a hairline: the one worn edged in the accent, the
		# locked ones sunk into the ink
		var bg := UiKit.fa(UiKit.TEXT, 0.03) if open else UiKit.fa(UiKit.INK, 0.5)
		var edge := UiKit.ACCENT if sel else (UiKit.LINE if open else UiKit.fa(UiKit.LINE, 0.5))
		var hov := UiKit.boxc(UiKit.fa(UiKit.TEXT, 0.07 if open else 0.04), 0, UiKit.ACCENT if sel else (UiKit.RULE2 if open else UiKit.LINE), 2 if sel else 1, 0.0)
		t.add_theme_stylebox_override("normal", UiKit.boxc(bg, 0, edge, 2 if sel else 1, 0.0))
		t.add_theme_stylebox_override("hover", hov)
		t.add_theme_stylebox_override("pressed", hov)
		(t.get_node("Pic") as TextureRect).modulate = Color.WHITE if open else Color(0.5, 0.5, 0.5, 0.55)
		(t.get_node("Lock") as Control).visible = not open
		var how := "Wearing it." if sel else Insignia.unlock_text(id)
		if open and not sel:
			how += " Click to wear it." if on else " Sign in to wear it."
		t.tooltip_text = "%s\n%s\n%s" % [String(e.n), String(e.d), how]
	for g in Insignia.GROUPS:
		(_ins_counts[g[0]] as Label).text = "%d/%d" % [int(have.get(g[0], 0)), int(total.get(g[0], 0))]


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


## A small padlock on the insignia not yet unlocked: square, like everything
## else (a shackle over a body with a slot for the key), on a dark edge.
class LockGlyph extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var body := Rect2(w * 0.1, h * 0.46, w * 0.8, h * 0.5)
		var arch := PackedVector2Array([Vector2(w * 0.28, h * 0.46), Vector2(w * 0.28, h * 0.12), Vector2(w * 0.72, h * 0.12), Vector2(w * 0.72, h * 0.46)])
		draw_polyline(arch, Color(0, 0, 0, 0.85), 4.0)
		draw_polyline(arch, UiKit.DIM, 2.0)
		draw_rect(body.grow(1.0), Color(0, 0, 0, 0.85))
		draw_rect(body, UiKit.DIM)
		draw_rect(Rect2(w * 0.45, h * 0.6, w * 0.1, h * 0.2), UiKit.INK)


## A counted bar that only shows (docs/UI.md, Meter): `count` square steps
## filled with the accent to the value, as far through a rank as the player is.
class StepBar extends Range:
	var count := 10
	var step_w := 5.0
	var step_h := 6.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		value_changed.connect(func(_v): queue_redraw())
		changed.connect(queue_redraw)

	func _get_minimum_size() -> Vector2:
		return Vector2(count * (step_w + 2.0) - 2.0, step_h)

	func _draw() -> void:
		var span := max_value - min_value
		var frac := 0.0 if span <= 0.0 else (value - min_value) / span
		UiKit.steps(self, Vector2(0, (size.y - step_h) * 0.5), frac * count, count, UiKit.ACCENT, step_w, step_h)
