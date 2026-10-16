class_name HostSetup
extends PanelContainer
## Setting up a battle to host: what kind (co-op against the AI, players
## against each other, or a mission together), who can find it, how many
## seats. Hosting opens the lobby, where all of it can still be changed but
## the password.

signal host_requested(opts: Dictionary)
signal closed

const MODES := [
	["coop", "CO-OP VS AI", "Everyone on one side against the AI commander"],
	["versus", "VERSUS", "Players pick sides; the AI can take one nobody plays"],
	["mission", "MISSION", "A short operation with objectives, played together"],
]
const ACCESS := [
	["public", "Public", "Anyone can find it in the server browser, and Find Match sends players here."],
	["password", "Password", "In the server browser with a padlock: only players with the password get in, and Find Match leaves it alone."],
	["unlisted", "Unlisted", "Not listed online. Players on your network still see it; anyone else needs your address, and a forwarded UDP port."],
]

var _mode := "coop"
var _side := 0
var _mission := ""
var _access := "public"

var _name: LineEdit
var _mode_cards := {}
var _side_box: HBoxContainer
var _side_btns := {}
var _ms_box: VBoxContainer
var _ms_opt: OptionButton
var _ms_note: Label
var _fill_check: CheckBox
var _ally_check: CheckBox
var _drop_check: CheckBox
var _seats: OptionButton
var _mood: OptionButton
var _mood_row: Control
var _access_btns := {}
var _access_note: Label
var _pw: LineEdit
var _port: SpinBox
var _err: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.boxc(Color(0.035, 0.045, 0.045, 0.94), 6, UiKit.LINE, 1, 22.0, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 11)
	add_child(v)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	v.add_child(hv)
	hv.add_child(UiKit.label("HOST A BATTLE", 13, UiKit.ACCENT, 700))
	hv.add_child(UiKit.label("Set up your battle", 24, UiKit.TEXT, 600))

	_name = LineEdit.new()
	_name.max_length = 40
	_name.custom_minimum_size = Vector2(0, 36)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_row("Name", _name))

	# the kind of battle
	var mr := HBoxContainer.new()
	mr.add_theme_constant_override("separation", 8)
	v.add_child(mr)
	for m in MODES:
		var key: String = m[0]
		var card := _card(String(m[1]), String(m[2]), UiKit.ACCENT)
		card.pressed.connect(func(): Sfx.ui("click"); _pick_mode(key))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mr.add_child(card)
		_mode_cards[key] = card

	# what goes with it: the side for co-op, the mission, the AI for versus
	_side_box = HBoxContainer.new()
	_side_box.add_theme_constant_override("separation", 8)
	for t in 2:
		var tc: Color = Defs.TEAM_COLORS[t]
		var b := Button.new()
		b.text = Defs.TEAM_NAMES[t]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 34)
		var pr := UiKit.box(Color(tc.r, tc.g, tc.b, 0.22), 5, tc, 1, 6.0)
		pr.border_width_left = 4
		b.add_theme_stylebox_override("pressed", pr)
		b.add_theme_stylebox_override("hover_pressed", pr)
		b.add_theme_color_override("font_pressed_color", tc.lightened(0.4))
		var side := t
		b.pressed.connect(func(): _pick_side(side))
		_side_box.add_child(b)
		_side_btns[t] = b
	v.add_child(_row("Your side", _side_box))
	_ms_box = VBoxContainer.new()
	_ms_box.add_theme_constant_override("separation", 4)
	_ms_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ms_opt = OptionButton.new()
	_ms_opt.custom_minimum_size = Vector2(0, 34)
	for m in Missions.playable():
		_ms_opt.add_item("%s  ·  %s, %d min" % [String(m.title), Defs.TEAM_NAMES[int(m.side)], int(m.mins)])
		_ms_opt.set_item_metadata(_ms_opt.item_count - 1, String(m.key))
	_ms_opt.item_selected.connect(func(i: int): _mission = String(_ms_opt.get_item_metadata(i)); _sync())
	_ms_box.add_child(_ms_opt)
	_ms_note = UiKit.label("", 12, UiKit.DIM)
	_ms_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ms_box.add_child(_ms_note)
	v.add_child(_row("Mission", _ms_box))
	_fill_check = CheckBox.new()
	_fill_check.text = "The AI takes a side nobody plays"
	_fill_check.button_pressed = true
	v.add_child(_fill_check)

	# seats and the time of day
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 10)
	_seats = OptionButton.new()
	for n in range(2, Net.MAX_PLAYERS + 1):
		_seats.add_item("%d players" % n, n)
	_seats.select(_seats.item_count - 1)
	_seats.custom_minimum_size = Vector2(130, 34)
	sr.add_child(_seats)
	_mood = OptionButton.new()
	for i in SettingsPanel.MOODS.size():
		_mood.add_item(SettingsPanel.MOOD_NAMES[i], i)
	_mood.custom_minimum_size = Vector2(190, 34)
	var tl := UiKit.label("Time of day", 14, UiKit.DIM)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mood_row = HBoxContainer.new()
	(_mood_row as HBoxContainer).add_theme_constant_override("separation", 10)
	_mood_row.add_child(tl)
	_mood_row.add_child(_mood)
	sr.add_child(_mood_row)
	v.add_child(_row("Seats", sr))

	# who can find it
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 6)
	for a in ACCESS:
		var b := Button.new()
		b.text = String(a[1])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(104, 34)
		var key: String = a[0]
		b.pressed.connect(func(): _pick_access(key))
		ar.add_child(b)
		_access_btns[key] = b
	_pw = LineEdit.new()
	_pw.placeholder_text = "Password"
	_pw.max_length = 32
	_pw.custom_minimum_size = Vector2(150, 34)
	_pw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ar.add_child(_pw)
	v.add_child(_row("Who can join", ar))
	_access_note = UiKit.label("", 12, UiKit.DIM)
	_access_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var an := MarginContainer.new()
	an.add_theme_constant_override("margin_left", 120)
	an.add_child(_access_note)
	v.add_child(an)

	var opts := HFlowContainer.new()
	opts.add_theme_constant_override("h_separation", 18)
	_drop_check = CheckBox.new()
	_drop_check.text = "Players can join mid-battle"
	_drop_check.button_pressed = true
	opts.add_child(_drop_check)
	_ally_check = CheckBox.new()
	_ally_check.text = "An AI commander fights alongside the players too"
	opts.add_child(_ally_check)
	v.add_child(opts)

	var pr2 := HBoxContainer.new()
	pr2.add_theme_constant_override("separation", 10)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = Net.DEFAULT_PORT
	_port.custom_minimum_size = Vector2(110, 32)
	pr2.add_child(_port)
	var pn := UiKit.label("UDP: forward it if your router turns out to be strict", 12, UiKit.DIM)
	pn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr2.add_child(pn)
	v.add_child(_row("Port", pr2))

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	_err = UiKit.label("", 13, UiKit.BAD)
	_err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_err)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 10)
	v.add_child(br)
	var go := UiKit.primary_button("HOST BATTLE", 220, 44, 17)
	go.pressed.connect(func(): Sfx.ui("click"); _go())
	br.add_child(go)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(110, 44)
	back.pressed.connect(func(): closed.emit())
	br.add_child(back)

	_mission = String(Missions.playable()[0].key)
	_pick_mode(_mode)
	_pick_side(_side)
	_pick_access(_access)


func _row(label: String, w: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	# lined up with the first line of what it labels
	var l := UiKit.label(label, 14, UiKit.DIM)
	l.custom_minimum_size = Vector2(110, 34)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(l)
	h.add_child(w)
	return h


## A choice card: a name and what it means, the chosen one lit in `col`.
func _card(title: String, sub: String, col: Color) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 76)
	card.add_theme_stylebox_override("normal", UiKit.box(Color(1, 1, 1, 0.03), 4, Color(1, 1, 1, 0.07), 1, 0.0))
	card.add_theme_stylebox_override("hover", UiKit.box(Color(col.r, col.g, col.b, 0.08), 4, Color(col.r, col.g, col.b, 0.5), 1, 0.0))
	var cp := UiKit.box(Color(col.r, col.g, col.b, 0.14), 4, col, 2, 0.0)
	cp.border_width_left = 4
	card.add_theme_stylebox_override("pressed", cp)
	card.add_theme_stylebox_override("hover_pressed", cp)
	var cv := VBoxContainer.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv.offset_left = 14
	cv.offset_right = -10
	cv.offset_top = 9
	cv.offset_bottom = -6
	cv.add_theme_constant_override("separation", 3)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cv)
	var nm := UiKit.label(title, 14, col.lightened(0.2), 700)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(nm)
	var ds := UiKit.label(sub, 12, Color(0.8, 0.8, 0.76))
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(ds)
	return card


## Open it, on the choices given (`mode`, `mission`), or as last time.
func open(preset := {}) -> void:
	if preset.has("mode"):
		_mode = String(preset.mode)
	if preset.has("mission"):
		_mission = String(preset.mission)
	_name.placeholder_text = "%s's battle" % Net.my_name
	var mi := SettingsPanel.MOODS.find(String(Settings.get_v("mood")))
	_mood.select(maxi(0, mi))
	_err.text = ""
	_pick_mode(_mode)


func _pick_mode(m: String) -> void:
	_mode = m
	for k in _mode_cards:
		(_mode_cards[k] as Button).set_pressed_no_signal(k == m)
	_sync()


func _pick_side(t: int) -> void:
	_side = t
	for k in _side_btns:
		(_side_btns[k] as Button).set_pressed_no_signal(k == t)


func _pick_access(a: String) -> void:
	_access = a
	for k in _access_btns:
		(_access_btns[k] as Button).set_pressed_no_signal(k == a)
	for x in ACCESS:
		if String(x[0]) == a:
			_access_note.text = String(x[2])
	_pw.visible = a == "password"
	if a == "password":
		_pw.grab_focus.call_deferred()
	_err.text = ""


## Show what goes with the chosen mode.
func _sync() -> void:
	var mission := _mode == "mission"
	_side_box.get_parent().visible = _mode == "coop"
	_ms_box.get_parent().visible = mission
	_fill_check.visible = _mode == "versus"
	_ally_check.visible = not mission
	_mood_row.visible = not mission
	if mission:
		for i in _ms_opt.item_count:
			if String(_ms_opt.get_item_metadata(i)) == _mission:
				_ms_opt.select(i)
		var md := Missions.find(_mission)
		_ms_note.text = String(md.blurb)


func _go() -> void:
	if _access == "password" and _pw.text.strip_edges() == "":
		_err.text = "Choose a password for your friends to type, or make the battle Public."
		_pw.grab_focus()
		return
	_err.text = ""
	host_requested.emit({
		"name": _name.text.strip_edges(),
		"mode": _mode,
		"side": _side,
		"mission": _mission if _mode == "mission" else "",
		"max_players": _seats.get_selected_id(),
		"mood": SettingsPanel.MOODS[maxi(0, _mood.selected)],
		"access": _access,
		"password": _pw.text.strip_edges() if _access == "password" else "",
		"drop_in": _drop_check.button_pressed,
		"ai_fill": _fill_check.button_pressed,
		"ai_allies": _ally_check.button_pressed,
		"port": int(_port.value),
	})
