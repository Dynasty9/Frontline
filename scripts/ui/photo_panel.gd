class_name PhotoPanel
extends CanvasLayer
## Photo mode's panel (docs/UI.md): a sheet of flat ink with corner ticks at the
## right edge of the screen, its rows the lens, the light and the film, then
## the capture and the keys. The hide-interface key (F2 to begin with) puts it
## away for a clean look at the picture; the picture itself never has it in.
## Every value goes to PhotoMode, which owns them (none is a setting).

const W := 344.0
const LABEL_W := 92.0
const VALUE_W := 64.0
const STEPS := 18
const TOAST_MS := 6000
const FOCUS_SPAN := PhotoMode.FOCUS_MAX / PhotoMode.FOCUS_MIN  # the focus slider is logarithmic: as many steps from 1 m to 10 m as from 10 m to 100

var photo: PhotoMode
var root: Control
var sheet: PanelContainer
var _rows := {}  # key -> [the control, its value label (or null), the row]
var _status: Label
var _readout: Label
var _toast: PanelContainer
var _toast_head: Label
var _toast_file: Label
var _toast_where: Label
var _toast_show: Button
var _toast_ms := 0
var _toast_path := ""
var _syncing := false
var _scroll: ScrollContainer
var _body: VBoxContainer
## The camera-and-lens passes: [key, label, what it does].
const LENS := [
	["lens", "Flare", "Bright lights flare the lens: ghosts and a halo, streaks, glare on the dust on the glass."],
	["shafts", "Shafts", "Rays of light streaming past trees, ridges and smoke against a low sun."],
	["local_exp", "Local exp", "Keeps the detail in deep shade and in bright fire at once, as the eye does."],
	["eye_adapt", "Eye", "The eye's adaptation: dimmed by a flash, and colours draining towards grey in the dark."],
	["film", "Film", "Highlights bleed red into the film (halation), and fine detail is sharpened."],
	["heat_haze", "Haze", "Heat haze: the air shimmers over fires, wrecks, engines and exhausts, and round a blast."],
]


func _ready() -> void:
	layer = 6
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiKit.frame(Color(-1, 0, 0), 12.0))
	sheet.anchor_left = 1.0
	sheet.anchor_right = 1.0
	sheet.offset_left = -W - 22.0
	sheet.offset_right = -22.0
	sheet.offset_top = 22.0
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(sheet)
	# (it scrolls when the window is too short for all of it)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(_scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	vb.custom_minimum_size = Vector2(W, 0)
	_scroll.add_child(vb)
	_body = vb
	# the title: PHOTO MODE, and whether the battle is held (PAUSED) or goes on (LIVE)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var tl := UiKit.caps("Photo mode", 15, UiKit.TEXT, 600, 2)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	_status = UiKit.mono_label("", 11, UiKit.DIM)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_status)
	vb.add_child(head)
	_readout = UiKit.mono_label("", 11, UiKit.FAINT)
	vb.add_child(_readout)
	_section(vb, "Lens")
	_slider(vb, "fov", "Field of view", PhotoMode.FOV_MIN, PhotoMode.FOV_MAX, 1.0)
	if photo.has_dof():
		_slider(vb, "focus", "Focus", 0.0, 1.0, 0.01)
		_slider(vb, "blur", "Blur", 0.0, 1.0, 0.05)
	_section(vb, "Light")
	var names := []
	for m in PhotoMode.MOODS:
		var i := SettingsPanel.MOODS.find(m)
		names.append(SettingsPanel.MOOD_NAMES[i] if i >= 0 else String(m).capitalize())
	_option(vb, "mood", "Time of day", names)
	_slider(vb, "exposure", "Exposure", -PhotoMode.EXPOSURE_EV, PhotoMode.EXPOSURE_EV, 0.1)
	_section(vb, "Film")
	_option(vb, "look", "Grade", Settings.LABELS.look)
	_slider(vb, "contrast", "Contrast", 0.5, 1.5, 0.05)
	_slider(vb, "saturation", "Saturation", 0.0, 2.0, 0.05)
	_slider(vb, "vignette", "Vignette", 0.0, 1.0, 0.05)
	_slider(vb, "grain", "Grain", 0.0, 0.2, 0.01)
	_seg(vb, "show_fog", "Fog of war", ["Hide", "Show"])
	if photo.has_lens():
		_section(vb, "Camera and lens")
		vb.add_child(_lens_row())
	_section(vb, "Capture")
	# the picture's size beside the button that takes it
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	vb.add_child(crow)
	if photo.can_supersample():
		var sg := UiSeg.make(["1×", "2×"], 0)
		sg.set_tooltip("Supersample: draw the picture at twice the resolution and scale it down, for cleaner edges.")
		sg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sg.changed.connect(func(i: int):
			if not _syncing:
				photo.set_value("supersample", i == 1))
		crow.add_child(sg)
		_rows["supersample"] = [sg, null, crow]
	var cap := UiKit.primary_button("Capture", 0, 32, 13)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.pressed.connect(func(): photo.capture())
	crow.add_child(cap)
	_section(vb, "Keys")
	vb.add_child(_keys())
	# where the last picture went: bottom right, so it shows with the sheet put away too
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UiKit.frame(Color(-1, 0, 0), 10.0))
	_toast.anchor_left = 1.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_left = -W - 22.0
	_toast.offset_right = -22.0
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_top = -22.0
	_toast.offset_bottom = -22.0
	_toast.visible = false
	root.add_child(_toast)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 3)
	_toast.add_child(tv)
	var th := HBoxContainer.new()
	_toast_head = UiKit.caps("", 12, UiKit.GOOD, 600, 1)
	_toast_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(_toast_head)
	_toast_show = UiKit.button("Show", "quiet", 0, 20)
	_toast_show.pressed.connect(func(): OS.shell_show_in_file_manager(ProjectSettings.globalize_path(_toast_path)))
	th.add_child(_toast_show)
	tv.add_child(th)
	_toast_file = UiKit.mono_label("", 12, UiKit.TEXT)
	tv.add_child(_toast_file)
	_toast_where = UiKit.mono_label("", 11, UiKit.FAINT)
	_toast_where.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_toast_where.custom_minimum_size = Vector2(W, 0)
	tv.add_child(_toast_where)
	photo.changed.connect(_sync)
	photo.captured.connect(_on_captured)
	root.resized.connect(_fit)
	_sync()
	_fit.call_deferred()
	UiMotion.arrive(sheet, Vector2(1, 0))


## As tall as what's in it, or as the window allows (then it scrolls).
func _fit() -> void:
	if not is_instance_valid(_scroll):
		return
	var room := root.size.y - 44.0 - 24.0  # (the margins above and below, the sheet's padding)
	_scroll.custom_minimum_size = Vector2(W, minf(_body.get_combined_minimum_size().y, maxf(120.0, room)))


func toggle_sheet() -> void:
	sheet.visible = not sheet.visible


func _process(_dt: float) -> void:
	if sheet.visible:
		_readout.text = photo.readout()
	if _toast.visible and Time.get_ticks_msec() - _toast_ms > TOAST_MS and not _toast.get_global_rect().has_point(_toast.get_global_mouse_position()):
		_toast.visible = false


# --- rows ------------------------------------------------------------------------------------

func _section(parent: Control, text: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	parent.add_child(gap)
	parent.add_child(UiKit.header(text))


func _row(parent: Control, key: String, text: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.custom_minimum_size = Vector2(0, 22)
	var l := UiKit.caps(text, 11, UiKit.DIM)
	l.custom_minimum_size = Vector2(LABEL_W, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	parent.add_child(hb)
	hb.name = key
	return hb


## An amount as a counted bar (UiSteps) and its figure in mono.
func _slider(parent: Control, key: String, text: String, lo: float, hi: float, step: float) -> void:
	var hb := _row(parent, key, text)
	var sl := UiSteps.new()
	sl.count = STEPS
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sl)
	var vl := UiKit.mono_label("", 12, UiKit.TEXT)
	vl.custom_minimum_size = Vector2(VALUE_W, 0)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(vl)
	sl.value_changed.connect(func(v: float):
		if not _syncing:
			photo.set_value(key, _from_slider(key, v)))
	# let go, the keys go back to flying the camera (an arrow key would move both)
	sl.drag_ended.connect(func(_c: bool): sl.release_focus())
	_rows[key] = [sl, vl, hb]


## A long choice as a drop-down.
func _option(parent: Control, key: String, text: String, items: Array) -> void:
	var hb := _row(parent, key, text)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	for it in items:
		ob.add_item(String(it))
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.custom_minimum_size = Vector2(0, 26)
	ob.item_selected.connect(func(i: int):
		if not _syncing:
			photo.set_value(key, PhotoMode.MOODS[i] if key == "mood" else i))
	hb.add_child(ob)
	_rows[key] = [ob, null, hb]


## A short choice as segments; the second one is "on".
func _seg(parent: Control, key: String, text: String, items: Array) -> void:
	var hb := _row(parent, key, text)
	var sg := UiSeg.make(items, 0)
	sg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sg.changed.connect(func(i: int):
		if not _syncing:
			photo.set_value(key, i == 1))
	hb.add_child(sg)
	_rows[key] = [sg, null, hb]


## The camera-and-lens passes as a row of switches, each on or off on its own
## (squares like segments, the ones on filled with the accent).
func _lens_row() -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", -1)
	var n := UiKit.box(Color(0, 0, 0, 0), 0, UiKit.LINE, 1, 0.0)
	var h := UiKit.box(Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, 0.05), 0, UiKit.RULE2, 1, 0.0)
	var on := UiKit.box(UiKit.ACCENT, 0, UiKit.ACCENT, 1, 0.0)
	for sb: StyleBoxFlat in [n, h, on]:
		sb.content_margin_left = 9
		sb.content_margin_right = 9
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
	for it in LENS:
		var b := Button.new()
		b.text = String(it[1]).to_upper()
		b.tooltip_text = String(it[2])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", UiKit.cond(600, 1))
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", UiKit.FAINT)
		b.add_theme_color_override("font_hover_color", UiKit.TEXT)
		b.add_theme_color_override("font_pressed_color", UiKit.ON_ACCENT)
		b.add_theme_color_override("font_hover_pressed_color", UiKit.ON_ACCENT)
		var key: String = it[0]
		b.toggled.connect(func(pressed: bool):
			if not _syncing:
				photo.set_value(key, pressed))
		hb.add_child(b)
		_rows[key] = [b, null, hb]
	return hb


## The keys photo mode listens to, as the player has them bound.
## (two to a line, so the sheet fits a 900-line window without scrolling)
func _keys() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 2)
	var move := " ".join(PackedStringArray([Keys.label("cam_up"), Keys.label("cam_left"), Keys.label("cam_down"), Keys.label("cam_right")]))
	var n := 0
	for kv in [
		[move, "Move"],
		[_pair("photo_rise", "photo_sink"), "Up · down"],
		[_pair("photo_roll_left", "photo_roll_right"), "Roll"],
		[Keys.label("photo_level"), "Level"],
		["DRAG", "Look"],
		["WHEEL", "Zoom"],
		[_pair("cam_fast", "photo_slow"), "Fast · slow"],
		[Keys.label("photo_capture"), "Capture"],
		[Keys.label("hide_hud"), "Hide panel"],
		[_pair("photo_mode", "", "Esc"), "Close"],
	]:
		if String(kv[0]).strip_edges() == "":
			continue
		var k := UiKit.mono_label(String(kv[0]).to_upper(), 11, UiKit.DIM)
		k.custom_minimum_size = Vector2(56, 0)
		g.add_child(k)
		var a := UiKit.caps(String(kv[1]), 11, UiKit.FAINT)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(a)
		n += 1
	if n % 2 == 1:
		g.add_child(Control.new())
		g.add_child(Control.new())
	return g


func _pair(a: String, b: String, extra := "") -> String:
	var parts := PackedStringArray()
	for s in [Keys.label(a), Keys.label(b) if b != "" else "", extra]:
		if s != "":
			parts.append(s)
	return " / ".join(parts)


# --- values ----------------------------------------------------------------------------------

func _to_slider(key: String, v: float) -> float:
	if key == "focus":
		return log(v / PhotoMode.FOCUS_MIN) / log(FOCUS_SPAN)
	return v


func _from_slider(key: String, v: float) -> float:
	if key == "focus":
		return PhotoMode.FOCUS_MIN * pow(FOCUS_SPAN, v)
	return v


static func figure(key: String, v: float) -> String:
	match key:
		"fov":
			return "%d°" % roundi(v)
		"focus":
			return ("%.1f M" % v) if v < 10.0 else "%d M" % roundi(v)
		"blur":
			return "OFF" if v <= 0.001 else "%d%%" % roundi(v * 100.0)
		"exposure":
			return "%+.1f EV" % v
		"grain":
			return "%d%%" % roundi(v / 0.2 * 100.0)
	return "%d%%" % roundi(v * 100.0)


func _sync() -> void:
	_syncing = true
	for key in _rows:
		var c: Control = _rows[key][0]
		var v: Variant = photo.get(key)
		if c is UiSteps:
			(c as UiSteps).set_value_no_signal(_to_slider(key, float(v)))
			c.queue_redraw()
			(_rows[key][1] as Label).text = figure(key, float(v))
		elif c is OptionButton:
			(c as OptionButton).select(PhotoMode.MOODS.find(String(v)) if key == "mood" else int(v))
		elif c is UiSeg:
			(c as UiSeg).select(1 if bool(v) else 0)
		elif c is Button and key in PhotoMode.LENS_KEYS:
			(c as Button).set_pressed_no_signal(bool(photo.lens_fx.get(key, false)))
	# the fog of war's row only when there's a fog of war on the ground to hide
	if _rows.has("show_fog"):
		var fog_row := _rows.show_fog[2] as Control
		var fog_on: bool = photo.world.fog != null and photo.world.fog.active
		if fog_row.visible != fog_on:
			fog_row.visible = fog_on
			_fit.call_deferred()
	if photo.held != "":
		_status.text = "PAUSED"
		_status.add_theme_color_override("font_color", UiKit.DIM)
	else:
		_status.text = "LIVE"
		_status.add_theme_color_override("font_color", UiKit.ACCENT)
	_readout.text = photo.readout()
	_syncing = false


func _on_captured(path: String, where: String) -> void:
	_toast_ms = Time.get_ticks_msec()
	_toast_path = path
	_toast.visible = true
	if path == "":
		_toast_head.text = "NOT SAVED"
		_toast_head.add_theme_color_override("font_color", UiKit.BAD)
		_toast_file.text = ""
		_toast_where.text = where
		_toast_show.visible = false
	else:
		_toast_head.text = "SAVED"
		_toast_head.add_theme_color_override("font_color", UiKit.GOOD)
		_toast_file.text = "%s  %d×%d" % [path.get_file(), photo.last_size.x, photo.last_size.y]
		_toast_where.text = where if OS.has_feature("web") else where.get_base_dir()
		_toast_show.visible = not OS.has_feature("web")
	UiMotion.flicker(_toast)
