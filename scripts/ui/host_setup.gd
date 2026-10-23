class_name HostSetup
extends PanelContainer
## Setting up a battle to host: what kind (co-op against the AI, players
## against each other, or a mission together), who can find it, how many
## seats. Hosting opens the lobby, where all of it can still be changed but
## the password.
## Signal (docs/UI.md, Options): a row per setting, its name in faint capitals
## and its control beside it: segments for a short choice, an underlined mono
## field for text and numbers, a drop-down only for a long list.

signal host_requested(opts: Dictionary)
signal closed

const MODES := [
	["coop", "Co-op vs AI", "Everyone on one side against the AI commander."],
	["versus", "Versus", "Players pick sides; the AI can take one nobody plays."],
	["mission", "Mission", "A short operation with objectives, played together."],
]
const ACCESS := [
	["public", "Public", "Anyone can find it in the server browser, and Find Match sends players here."],
	["password", "Password", "In the server browser with a padlock: only players with the password get in, and Find Match leaves it alone."],
	["unlisted", "Unlisted", "Not listed online. Players on your network still see it; anyone else needs your address, and a forwarded UDP port."],
]
const LABEL_W := 150.0
const ROW_H := 30.0

var _mode := "coop"
var _side := 0
var _mission := ""
var _access := "public"

var _rows := {}  # key -> its row (shown or hidden with the mode)
var _name: LineEdit
var _mode_seg: UiSeg
var _mode_note: Label
var _side_seg: UiSeg
var _ms_opt: OptionButton
var _ms_note: Label
var _fill_seg: UiSeg
var _ally_seg: UiSeg
var _drop_seg: UiSeg
var _seats: UiSeg
var _mood: OptionButton
var _access_seg: UiSeg
var _access_note: Label
var _pw: LineEdit
var _port: LineEdit
var _err: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.frame(Color(-1, 0, 0), 22.0, 0.0, 14.0, 0.93))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var tl := UiKit.caps("Host a battle", 18, UiKit.TEXT, 600, 2)
	tl.custom_minimum_size = Vector2(0, 30)
	v.add_child(tl)

	# the battle: its name, its kind, and what goes with the kind (the side
	# for co-op, the mission, the AI for versus)
	v.add_child(UiKit.header("Battle"))
	_name = LineEdit.new()
	_name.max_length = 40
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row(v, "name", "Name", _name)
	var names: Array = []
	for m in MODES:
		names.append(String(m[1]))
	_mode_seg = UiSeg.make(names, 0)
	_mode_seg.changed.connect(func(i: int): Sfx.ui("click"); _pick_mode(String(MODES[i][0])))
	_row(v, "mode", "Mode", _mode_seg)
	_mode_note = _note(v, "mode_note")
	_side_seg = UiSeg.make([Defs.TEAM_NAMES[0], Defs.TEAM_NAMES[1]], 0)
	_side_seg.changed.connect(_pick_side)
	_row(v, "side", "Your side", _side_seg)
	_ms_opt = OptionButton.new()
	_ms_opt.custom_minimum_size = Vector2(0, 28)
	_ms_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for m in MissionList.playable():
		_ms_opt.add_item("%s  ·  %s, %d min" % [String(m.title), Defs.TEAM_NAMES[int(m.side)], int(m.mins)])
		_ms_opt.set_item_metadata(_ms_opt.item_count - 1, String(m.key))
	_ms_opt.item_selected.connect(func(i: int): _mission = String(_ms_opt.get_item_metadata(i)); _sync())
	_row(v, "mission", "Mission", _ms_opt)
	_ms_note = _note(v, "mission_note")
	_fill_seg = _switch(v, "fill", "AI fills empty side", true, "The AI takes a side nobody plays.")
	_ally_seg = _switch(v, "ally", "AI with the players", false, "An AI commander fights alongside the players too.")
	_drop_seg = _switch(v, "drop", "Join mid-battle", true, "Players can join a battle that's already under way.")
	var seats: Array = []
	for n in range(2, Net.MAX_PLAYERS + 1):
		seats.append(str(n))
	_seats = UiSeg.make(seats, seats.size() - 1)
	_seats.set_tooltip("How many players the battle takes, the host included.")
	_row(v, "seats", "Seats", _seats)
	_mood = OptionButton.new()
	for i in SettingsPanel.MOODS.size():
		_mood.add_item(SettingsPanel.MOOD_NAMES[i], i)
	_mood.custom_minimum_size = Vector2(240, 28)
	_row(v, "mood", "Time of day", _mood)

	# who can find it, and where they connect
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	v.add_child(UiKit.header("Access"))
	names = []
	for a in ACCESS:
		names.append(String(a[1]))
	_access_seg = UiSeg.make(names, 0)
	_access_seg.changed.connect(func(i: int): _pick_access(String(ACCESS[i][0])))
	_row(v, "access", "Who can join", _access_seg)
	_access_note = _note(v, "access_note")
	_pw = LineEdit.new()
	_pw.placeholder_text = "Password"
	_pw.max_length = 32
	_pw.custom_minimum_size = Vector2(240, 0)
	_row(v, "pw", "Password", _pw)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 14)
	_port = LineEdit.new()
	_port.text = str(Net.DEFAULT_PORT)
	_port.max_length = 5
	_port.custom_minimum_size = Vector2(70, 0)
	pr.add_child(_port)
	var pn := UiKit.label("UDP: forward it if your router turns out to be strict", 12, UiKit.FAINT)
	pn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(pn)
	_row(v, "port", "Port", pr)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)
	_err = UiKit.label("", 13, UiKit.BAD)
	_err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_err.custom_minimum_size = Vector2(400, 0)
	v.add_child(_err)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 10)
	v.add_child(br)
	var go := UiKit.primary_button("Host battle", 220, 40, 15)
	go.pressed.connect(func(): Sfx.ui("click"); _go())
	br.add_child(go)
	var back := UiKit.button("Back", "secondary", 110, 40)
	back.pressed.connect(func(): closed.emit())
	br.add_child(back)

	_mission = String(MissionList.playable()[0].key)
	_pick_mode(_mode)
	_pick_side(_side)
	_pick_access(_access)


## A setting's row: its name in faint capitals, the control beside it.
func _row(v: VBoxContainer, key: String, label: String, w: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.custom_minimum_size = Vector2(0, ROW_H)
	var l := UiKit.caps(label, 11, UiKit.FAINT)
	l.custom_minimum_size = Vector2(LABEL_W, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(w)
	v.add_child(h)
	_rows[key] = h
	return h


## A line of prose under the row above it, lined up with its control.
func _note(v: VBoxContainer, key: String) -> Label:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(LABEL_W) + 12)
	m.add_theme_constant_override("margin_bottom", 2)
	var l := UiKit.label("", 12, UiKit.FAINT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# (a wrapping label wants a width, or it's measured a word to a line and
	# stretches the panel)
	l.custom_minimum_size = Vector2(360, 0)
	m.add_child(l)
	v.add_child(m)
	_rows[key] = m
	return l


## An on/off setting: OFF | ON, what it means in the tooltip.
func _switch(v: VBoxContainer, key: String, label: String, on: bool, tip: String) -> UiSeg:
	var s := UiSeg.make(["Off", "On"], 1 if on else 0)
	s.set_tooltip(tip)
	_row(v, key, label, s)
	return s


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
	for i in MODES.size():
		if String(MODES[i][0]) == m:
			_mode_seg.select(i)
			_mode_note.text = String(MODES[i][2])
	_sync()


func _pick_side(t: int) -> void:
	_side = t
	_side_seg.select(t)


func _pick_access(a: String) -> void:
	_access = a
	for i in ACCESS.size():
		if String(ACCESS[i][0]) == a:
			_access_seg.select(i)
			_access_note.text = String(ACCESS[i][2])
	(_rows.pw as Control).visible = a == "password"
	if a == "password":
		_pw.grab_focus.call_deferred()
	_err.text = ""


## Show what goes with the chosen mode.
func _sync() -> void:
	var mission := _mode == "mission"
	(_rows.side as Control).visible = _mode == "coop"
	(_rows.mission as Control).visible = mission
	(_rows.mission_note as Control).visible = mission
	(_rows.fill as Control).visible = _mode == "versus"
	(_rows.ally as Control).visible = not mission
	(_rows.mood as Control).visible = not mission
	if mission:
		for i in _ms_opt.item_count:
			if String(_ms_opt.get_item_metadata(i)) == _mission:
				_ms_opt.select(i)
		var md := MissionList.find(_mission)
		_ms_note.text = String(md.blurb)


func _go() -> void:
	if _access == "password" and _pw.text.strip_edges() == "":
		_err.text = "Choose a password for your friends to type, or make the battle Public."
		_pw.grab_focus()
		return
	_err.text = ""
	var pt := _port.text.strip_edges()
	host_requested.emit({
		"name": _name.text.strip_edges(),
		"mode": _mode,
		"side": _side,
		"mission": _mission if _mode == "mission" else "",
		"max_players": 2 + maxi(0, _seats.selected),
		"mood": SettingsPanel.MOODS[maxi(0, _mood.selected)],
		"access": _access,
		"password": _pw.text.strip_edges() if _access == "password" else "",
		"drop_in": _drop_seg.selected == 1,
		"ai_fill": _fill_seg.selected == 1,
		"ai_allies": _ally_seg.selected == 1,
		"port": clampi(int(pt), 1024, 65535) if pt.is_valid_int() else Net.DEFAULT_PORT,
	})
