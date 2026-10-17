class_name SettingsPanel
extends PanelContainer
## Graphics, display, interface, controls and audio settings. Every change applies live and is saved.
## Used by the main menu and the in-game Esc menu.
## Signal (docs/UI.md, Options): a short choice is a row of segments (ON | OFF,
## LOW | MEDIUM | HIGH), a long one a drop-down, an amount a counted bar;
## the pages are tabs underlined in the accent.

signal closed

const MOODS := ["random", "day", "golden", "dawn", "dusk", "overcast", "hazy", "night", "rain"]
const MOOD_NAMES := ["Random each battle", "Midday", "Golden hour", "Dawn", "Dusk", "Overcast", "Hazy", "Night", "Rain & thunder"]
const RES_NAMES := ["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440", "3840 x 2160"]

var _rows := {}  # key -> control
var _presets: UiSeg
var _syncing := false
var _tab := "graphics"
var _pages := {}
var _tab_btns := {}
var _presets_row: Control  # the quality presets (not on the Controls page, where they mean nothing)


func _ready() -> void:
	theme = UiKit.theme()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var title := HBoxContainer.new()
	vb.add_child(title)
	var tl := UiKit.caps("Settings", 18, UiKit.TEXT, 600, 2)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	var close := UiKit.button("Done", "secondary", 90, 30)
	close.pressed.connect(func(): closed.emit())
	title.add_child(close)
	# quality presets
	var pr := HBoxContainer.new()
	_presets_row = pr
	pr.add_theme_constant_override("separation", 14)
	vb.add_child(pr)
	var ql := UiKit.caps("Quality", 11, UiKit.FAINT)
	ql.custom_minimum_size = Vector2(70, 0)
	pr.add_child(ql)
	_presets = UiSeg.make(["Low", "Medium", "High", "Ultra"], -1)
	_presets.changed.connect(func(i: int): Settings.apply_preset(["low", "medium", "high", "ultra"][i]); _sync())
	pr.add_child(_presets)
	var custom := UiKit.mono_label("", 11, UiKit.WARN)
	custom.name = "Custom"
	pr.add_child(custom)
	# tabs: capitals, the open one underlined in the accent
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 18)
	vb.add_child(tabs)
	var on := UiKit.underline(UiKit.ACCENT, 2.0, 6.0)
	var off := UiKit.bare()
	off.content_margin_left = 2
	off.content_margin_right = 2
	off.content_margin_top = 6
	off.content_margin_bottom = 6
	for t in [["graphics", "Graphics"], ["lighting", "Lighting & Look"], ["display", "Display"], ["interface", "Interface"], ["controls", "Controls"], ["audio", "Audio"]]:
		var b2 := Button.new()
		b2.text = String(t[1]).to_upper()
		b2.toggle_mode = true
		b2.focus_mode = Control.FOCUS_NONE
		b2.add_theme_font_override("font", UiKit.cond(600, 1))
		b2.add_theme_font_size_override("font_size", 12)
		for st in ["normal", "hover", "disabled", "focus"]:
			b2.add_theme_stylebox_override(st, off)
		b2.add_theme_stylebox_override("pressed", on)
		b2.add_theme_stylebox_override("hover_pressed", on)
		b2.add_theme_color_override("font_color", UiKit.FAINT)
		b2.add_theme_color_override("font_hover_color", UiKit.TEXT)
		b2.add_theme_color_override("font_pressed_color", UiKit.ACCENT)
		b2.add_theme_color_override("font_hover_pressed_color", UiKit.ACCENT)
		var key: String = t[0]
		b2.pressed.connect(func(): _show_tab(key))
		tabs.add_child(b2)
		_tab_btns[key] = b2
	var sep := ColorRect.new()
	sep.color = UiKit.LINE
	sep.custom_minimum_size = Vector2(0, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sep)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.custom_minimum_size = Vector2(0, 200)  # the pages scroll when the window is short
	vb.add_child(stack)
	_pages["graphics"] = _page(stack, [
		["head", "", "Detail"],
		["option", "shadows", "Shadow quality", Settings.LABELS.shadows, "Sun shadow resolution, cascades and softness."],
		["option", "aniso", "Texture filtering", Settings.LABELS.aniso, "Anisotropic filtering keeps ground textures crisp at a glancing angle."],
		["option", "lod", "View distance / detail", Settings.LABELS.lod, "How far away models keep their full detail."],
		["option", "grass", "Vegetation", Settings.LABELS.grass, "Swaying grass blades across the battlefield."],
		["option", "wildlife", "Wildlife", Settings.LABELS.wildlife, "Birds feeding in the fields and wheeling overhead, rats in town, hares, fish, ducks and dolphins, all taking fright at the fighting. Only round the camera; turn it down or off if it costs you frames."],
		["option", "effects", "Effects quality", Settings.LABELS.effects, "Particles per explosion, smoke density, debris."],
		["option", "water", "Water quality", Settings.LABELS.water, "Waves, reflections and the bed seen through the water. Low skips the see-through water, the costly part; High adds light dancing on the shallows and foam streaks in a blow; Ultra a finer swell."],
		["check", "decals", "Scorch marks & craters", null, "Burn marks left by explosions."],
		["check", "ragdolls", "Ragdoll physics", null, "The dead fall, tumble and are thrown by blasts under real physics; thrown earth and rubble bounce and roll."],
		["head", "", "Lighting"],
		["check", "ssao", "Ambient occlusion", null, "Contact shadows in corners, under soldiers and around sandbags."],
		["option", "ao_q", "Ambient occlusion quality", Settings.LABELS.ao_q, "More samples, less noise."],
		["check", "ssil", "Indirect light", null, "Light bouncing off nearby surfaces (screen-space)."],
		["check", "gi", "Global illumination", null, "SDFGI: full bounced lighting. Expensive."],
		["check", "ssr", "Screen-space reflections", null, "Puddles and wet ground reflect fire, flares and the sky."],
		["check", "vol_fog", "Volumetric fog & smoke", null, "Light shafts, haze and smoke screens you can't see through."],
		["head", "", "Anti-aliasing & upscaling"],
		["option", "aa", "Anti-aliasing", Settings.LABELS.aa, "MSAA + SMAA keeps textures sharp and steady while the camera moves; TAA is smoother when still but smears in motion."],
		["option", "upscaler", "Upscaler", Settings.LABELS.upscaler, "FSR 1 upscales when render scale is below 100%. FSR 2 is temporal: sharpest, with its own anti-aliasing."],
		["slider", "scale", "Render scale", [0.5, 1.0, 0.05], "Below 100% renders fewer pixels and upscales them."],
		["slider", "sharpen", "Sharpening", [0.0, 1.0, 0.05], "FSR sharpening strength."],
	])
	_pages["lighting"] = _page(stack, [
		["option", "mood", "Time of day & weather", MOOD_NAMES, "Lighting for the battle (applies immediately)."],
		["option", "look", "Colour grading", Settings.LABELS.look, "The film look laid over the scene."],
		["option", "tonemap", "Tonemapper", Settings.LABELS.tonemap, "How bright highlights (fire, sun) roll off."],
		["slider", "brightness", "Brightness", [0.6, 1.5, 0.05], "Overall exposure."],
		["slider", "contrast", "Contrast", [0.8, 1.25, 0.01], ""],
		["check", "glow", "Bloom", null, "Glow around fire, muzzle flashes and the sun."],
		["check", "post", "Film grain & vignette", null, "A subtle camera look."],
		["check", "dof", "Tilt-shift depth of field", null, "Softly blurs what is far from the camera's focus."],
	])
	_pages["display"] = _page(stack, [
		["option", "window", "Window mode", Settings.LABELS.window, ""],
		["option", "resolution", "Window size", RES_NAMES, "Size of the window in windowed mode, kept from one launch to the next. A size too big for the screen fills it instead. The interface grows with the window."],
		["check", "vsync", "VSync", null, "Locks the frame rate to the monitor to avoid tearing."],
		["option", "fps_cap", "Frame rate limit", Settings.LABELS.fps_cap, ""],
		["slider", "fov", "Field of view", [35.0, 75.0, 1.0], "Camera lens angle.", "deg"],
		["option", "perf", "Performance overlay", Settings.LABELS.perf, "From a simple FPS counter to a full breakdown of the frame. Its key (F3 to begin with) cycles it."],
	])
	_pages["interface"] = _page(stack, [
		["option", "ui_theme", "Theme", UiKit.theme_names(), "The interface's colours, and the colours the living map behind the menus turns through. Field Brass is the original; Night Vision, Thermal, Arctic and Dusk look at the war through other eyes."],
		["slider", "ui_scale", "Interface scale", [Settings.UI_SCALE_MIN, 2.0, 0.05], "How big the interface is drawn. At 100% it grows with the window, so it looks the same at any resolution; text and symbols stay sharp at any size. The top of the slider is the largest that still fits this window: a bigger window, or fullscreen, goes further."],
		["note", "ui_note", "", null, ""],
		["check", "labels", "Unit activity labels", null, "Close up: each soldier's name and what he's doing. Further out: a status icon per man."],
		["check", "bubbles", "Speech bubbles", null, "Shouts, radio calls and the men's banter."],
		["check", "cover_preview", "Cover preview", null, "Pips under the cursor showing the cover each man will take (green heavy, yellow light, red exposed)."],
		["check", "coop_show", "Co-commanders' views and cursors", null, "In co-op: where the other commanders on your side are looking, their cursors, what they've selected and what they're lining up, in their colours. (Pings and the Command Net show either way.)"],
		["check", "reduce_motion", "Reduce motion", null, "Panels cut straight in instead of typing or counting on, and warnings don't flicker."],
		["head", "", "Camera"],
		["option", "mmb_mode", "Middle mouse drag", Settings.LABELS.mmb_mode, "What dragging with the middle mouse button does. Holding Alt does the other."],
		["check", "zoom_cursor", "Zoom toward the cursor", null, "The mouse wheel zooms in on whatever is under the cursor. Off: on the middle of the screen."],
		["option", "scroll_mode", "Two-finger scroll", Settings.LABELS.scroll_mode, "What scrolling with two fingers on a trackpad or a Magic Mouse does. Pinching zooms either way, and holding Option turns and tilts the view instead."],
		["check", "edge_pan", "Edge scrolling", null, "Pan the camera with the mouse at the screen edge."],
		["slider", "cam_speed", "Camera speed", [0.5, 2.0, 0.05], "Hold the pan-faster key (Shift to begin with, see Controls) to go two and a half times as fast."],
		["check", "shake", "Camera shake", null, "Explosions shake the camera."],
		["head", "", "Minimap"],
		["option", "minimap_size", "Minimap size", Settings.LABELS.minimap_size, ""],
		["check", "minimap_rotate", "Turn with the camera", null, "The minimap turns so that the way the camera faces is always up. Off: north is always up."],
		["head", "", "Online"],
		["check", "error_reports", "Send error reports", null, "When something goes wrong in the game, or it crashes, tell the developers what failed and where: the game's version, your system and graphics card. Never your name, account, files or address."],
	])
	# every key, by category, rebindable (scripts/ui/controls_page.gd)
	var cp := ControlsPage.new()
	cp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(cp)
	_pages["controls"] = cp
	_pages["audio"] = _page(stack, [
		["head", "", "Volume"],
		["slider", "volume", "Master", [0.0, 1.0, 0.05], "Everything at once."],
		["slider", "vol_music", "Music", [0.0, 1.0, 0.05], "The theme in the menus and the score under the fighting."],
		["slider", "vol_effects", "Effects", [0.0, 1.0, 0.05], "Gunfire, explosions, engines and aircraft."],
		["slider", "vol_ambience", "Ambience", [0.0, 1.0, 0.05], "Wind, rain and thunder, and the distant battle."],
		["slider", "vol_ui", "Interface", [0.0, 1.0, 0.05], "Clicks, and the radio chimes when objectives change."],
		["head", "", "Options"],
		["check", "battle_music", "Music in battle", null, "Off: music only in the menus."],
		["check", "mute_bg", "Mute in the background", null, "Silence the game while another window has the focus."],
	])
	_show_tab("graphics")
	_sync()
	Settings.changed.connect(_sync)
	# a new window size changes how far the interface can grow
	get_viewport().size_changed.connect(_sync)
	visibility_changed.connect(func(): if visible: _sync())


## What the browser build can't do: its renderer (WebGL 2) has no
## screen-space lighting, upscaling or depth of field, and the page decides
## the game's size and when it draws.
const NOT_ON_WEB := ["ssao", "ao_q", "ssil", "gi", "ssr", "vol_fog", "upscaler", "sharpen", "dof", "resolution", "vsync"]
## Settings only a Mac has a use for: elsewhere a trackpad scrolls like a wheel.
const ONLY_ON_MAC := ["scroll_mode"]


static func _for_web(rows: Array) -> Array:
	var out := []
	for r in rows:
		if String(r[1]) in NOT_ON_WEB:
			continue
		if r[0] == "head" and not out.is_empty() and out.back()[0] == "head":
			out.pop_back()  # a heading with nothing left under it
		out.append(r)
	if not out.is_empty() and out.back()[0] == "head":
		out.pop_back()
	return out


func _page(parent: Control, rows: Array) -> Control:
	if OS.has_feature("web"):
		rows = _for_web(rows)
	if OS.get_name() != "macOS":
		rows = rows.filter(func(r: Array) -> bool: return not (String(r[1]) in ONLY_ON_MAC))
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(g)
	for r in rows:
		var kind: String = r[0]
		var key: String = r[1]
		if kind == "head":
			# a section: its name in faint capitals and a rule running on from it
			var hl := UiKit.caps(String(r[2]), 11, UiKit.FAINT)
			hl.custom_minimum_size = Vector2(0, 30)
			hl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			g.add_child(hl)
			var rule := VBoxContainer.new()
			rule.alignment = BoxContainer.ALIGNMENT_END
			var line := ColorRect.new()
			line.color = UiKit.LINE
			line.custom_minimum_size = Vector2(0, 1)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rule.add_child(line)
			var under := Control.new()
			under.custom_minimum_size = Vector2(0, 6)
			rule.add_child(under)
			g.add_child(rule)
			continue
		if kind == "note":
			# a quiet line under the setting above it (shown when it has something to say)
			var gap := Control.new()
			g.add_child(gap)
			var nl := UiKit.label("", 12, UiKit.FAINT)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size = Vector2(220, 0)
			nl.set_meta("gap", gap)
			g.add_child(nl)
			_rows[key] = nl
			continue
		var lbl := UiKit.caps(r[2], 12, UiKit.DIM)
		lbl.custom_minimum_size = Vector2(250, 26)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.tooltip_text = r[4]
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		g.add_child(lbl)
		var c: Control
		match kind:
			"option":
				var pick := func(i: int): _apply(key, MOODS[i] if key == "mood" else (UiKit.THEME_KEYS[i] if key == "ui_theme" else i))
				if _short(r[3]):
					var sg := UiSeg.make(r[3], -1)
					sg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
					sg.changed.connect(pick)
					c = sg
				else:
					var ob := OptionButton.new()
					for item in r[3]:
						ob.add_item(item)
					ob.custom_minimum_size = Vector2(240, 28)
					ob.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
					ob.item_selected.connect(pick)
					c = ob
			"check":
				var cb := UiSeg.make(["Off", "On"], -1)
				cb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				cb.changed.connect(func(i: int): _apply(key, i == 1))
				cb.set_meta("check", true)
				c = cb
			"slider":
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", 12)
				var sl := UiSteps.new()
				sl.min_value = r[3][0]
				sl.max_value = r[3][1]
				sl.step = r[3][2]
				sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var vl := UiKit.mono_label("", 12, UiKit.TEXT)
				vl.custom_minimum_size = Vector2(46, 0)
				var deg: bool = r.size() > 5 and r[5] == "deg"
				hb.set_meta("deg", deg)
				sl.value_changed.connect(func(v):
					vl.text = ("%d°" % int(v)) if deg else "%d%%" % int(round(v * 100.0))
					if not sl.has_meta("held"):
						_apply(key, v))
				if key == "ui_scale":
					# this panel is redrawn at the new scale too: apply it when the
					# slider is let go, or it would slide out from under the mouse
					sl.drag_started.connect(func(): sl.set_meta("held", true))
					sl.drag_ended.connect(func(_changed: bool): sl.remove_meta("held"); _apply(key, sl.value))
				hb.add_child(sl)
				hb.add_child(vl)
				hb.set_meta("slider", sl)
				hb.set_meta("val", vl)
				c = hb
		if c is UiSeg:
			(c as UiSeg).set_tooltip(r[4])
		else:
			c.tooltip_text = r[4]
		g.add_child(c)
		_rows[key] = c
	return sc


## Whether a choice is short enough to lay out as segments: five or fewer,
## and narrow enough to sit beside its label.
static func _short(items: Array) -> bool:
	if items.size() > 5:
		return false
	var w := 0.0
	for it in items:
		w += UiKit.caps_w(String(it), 11) + 21.0
	return w <= 400.0


func _show_tab(key: String) -> void:
	_tab = key
	for k in _pages:
		_pages[k].visible = k == key
		_tab_btns[k].button_pressed = k == key
	if _presets_row:
		_presets_row.visible = key != "controls"


func _apply(key: String, v) -> void:
	if _syncing:
		return
	Settings.set_v(key, v)


func _sync() -> void:
	_syncing = true
	_presets.select(["low", "medium", "high", "ultra"].find(Settings.preset))
	var cl := find_child("Custom", true, false) as Label
	if cl:
		cl.text = "CUSTOM" if Settings.preset == "custom" else ""
	for key in _rows:
		var c: Control = _rows[key]
		var v = Settings.get_v(key)
		if c is OptionButton or (c is UiSeg and not c.has_meta("check")):
			var i := int(v) if not (key in ["mood", "ui_theme"]) else 0
			if key == "mood":
				i = maxi(0, MOODS.find(String(v)))
			elif key == "ui_theme":
				i = maxi(0, UiKit.THEME_KEYS.find(String(v)))
			if c is OptionButton:
				(c as OptionButton).select(i)
			else:
				(c as UiSeg).select(i)
		elif c is UiSeg:
			(c as UiSeg).select(1 if bool(v) else 0)
		elif c.has_meta("slider"):
			var sl: UiSteps = c.get_meta("slider")
			if key == "ui_scale":
				sl.max_value = Settings.ui_scale_max()  # as far as this window allows
			sl.value = float(v)
			(c.get_meta("val") as Label).text = ("%d°" % int(v)) if c.get_meta("deg", false) else "%d%%" % int(round(sl.value * 100.0))
		elif key == "ui_note":
			# in the menus a big scale stops where they fill the window: say so,
			# or the slider looks as if it does nothing
			var big: bool = Settings.ui_menu and Settings.ui_factor() < Settings.ui_base() * float(Settings.get_v("ui_scale")) - 0.01
			c.text = "The menus already fill the window. The battle interface is drawn at this size." if big else ""
			c.visible = big
			(c.get_meta("gap") as Control).visible = big
	_syncing = false
