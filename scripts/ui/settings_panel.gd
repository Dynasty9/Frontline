class_name SettingsPanel
extends PanelContainer
## Graphics / display / audio settings. Every change applies live and is saved.
## Used by the main menu and the in-game Esc menu.

signal closed

const MOODS := ["random", "day", "golden", "dawn", "dusk", "overcast", "hazy", "night", "rain"]
const MOOD_NAMES := ["Random each battle", "Midday", "Golden hour", "Dawn", "Dusk", "Overcast", "Hazy", "Night", "Rain & thunder"]
const RES_NAMES := ["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440", "3840 x 2160"]

var _rows := {}  # key -> control
var _preset_btns := {}
var _syncing := false
var _tab := "graphics"
var _pages := {}
var _tab_btns := {}


func _ready() -> void:
	theme = UiKit.theme()
	custom_minimum_size = Vector2(700, 600)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var title := HBoxContainer.new()
	vb.add_child(title)
	var tl := UiKit.label("Settings", 22, UiKit.TEXT, 600)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(tl)
	var close := Button.new()
	close.text = "Done"
	close.custom_minimum_size = Vector2(90, 32)
	close.pressed.connect(func(): closed.emit())
	title.add_child(close)
	# quality presets
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 6)
	vb.add_child(pr)
	pr.add_child(UiKit.label("Quality", 14, UiKit.DIM))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(10, 0)
	pr.add_child(sp)
	for p in ["low", "medium", "high", "ultra"]:
		var b := Button.new()
		b.text = p.capitalize()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(92, 32)
		b.pressed.connect(func(): Settings.apply_preset(p); _sync())
		pr.add_child(b)
		_preset_btns[p] = b
	var custom := UiKit.label("", 13, UiKit.DIM)
	custom.name = "Custom"
	pr.add_child(custom)
	# tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	vb.add_child(tabs)
	for t in [["graphics", "Graphics"], ["lighting", "Lighting & Look"], ["display", "Display"], ["interface", "Interface"], ["audio", "Audio"]]:
		var b2 := Button.new()
		b2.text = t[1]
		b2.toggle_mode = true
		b2.custom_minimum_size = Vector2(0, 30)
		var key: String = t[0]
		b2.pressed.connect(func(): _show_tab(key))
		tabs.add_child(b2)
		_tab_btns[key] = b2
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", UiKit.box(UiKit.LINE, 0, Color(0, 0, 0, 0), 0, 0.0))
	vb.add_child(sep)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.custom_minimum_size = Vector2(0, 420)
	vb.add_child(stack)
	_pages["graphics"] = _page(stack, [
		["head", "", "Detail"],
		["option", "shadows", "Shadow quality", Settings.LABELS.shadows, "Sun shadow resolution, cascades and softness."],
		["option", "aniso", "Texture filtering", Settings.LABELS.aniso, "Anisotropic filtering keeps ground textures crisp at a glancing angle."],
		["option", "lod", "View distance / detail", Settings.LABELS.lod, "How far away models keep their full detail."],
		["option", "grass", "Vegetation", Settings.LABELS.grass, "Swaying grass blades across the battlefield."],
		["option", "effects", "Effects quality", Settings.LABELS.effects, "Particles per explosion, smoke density, debris."],
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
		["option", "resolution", "Window size", RES_NAMES, "Size of the window in windowed mode."],
		["check", "vsync", "VSync", null, "Locks the frame rate to the monitor to avoid tearing."],
		["option", "fps_cap", "Frame rate limit", Settings.LABELS.fps_cap, ""],
		["slider", "fov", "Field of view", [35.0, 75.0, 1.0], "Camera lens angle.", "deg"],
		["option", "perf", "Performance overlay (F3)", Settings.LABELS.perf, "From a simple FPS counter to a full breakdown of the frame."],
	])
	_pages["interface"] = _page(stack, [
		["slider", "ui_scale", "Interface scale", [0.8, 1.5, 0.05], ""],
		["check", "labels", "Unit activity labels", null, "Close up: each soldier's name and what he's doing. Further out: a status icon per man."],
		["check", "bubbles", "Speech bubbles", null, "Shouts, radio calls and the men's banter."],
		["check", "cover_preview", "Cover preview", null, "Pips under the cursor showing the cover each man will take (green heavy, yellow light, red exposed)."],
		["head", "", "Camera"],
		["option", "mmb_mode", "Middle mouse drag", Settings.LABELS.mmb_mode, "What dragging with the middle mouse button does. Holding Alt does the other."],
		["check", "zoom_cursor", "Zoom toward the cursor", null, "The mouse wheel zooms in on whatever is under the cursor. Off: on the middle of the screen."],
		["check", "edge_pan", "Edge scrolling", null, "Pan the camera with the mouse at the screen edge."],
		["slider", "cam_speed", "Camera speed", [0.5, 2.0, 0.05], "Hold Shift to pan faster."],
		["check", "shake", "Camera shake", null, "Explosions shake the camera."],
		["head", "", "Minimap"],
		["option", "minimap_size", "Minimap size", Settings.LABELS.minimap_size, ""],
		["check", "minimap_rotate", "Turn with the camera", null, "The minimap turns so that the way the camera faces is always up. Off: north is always up."],
	])
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


func _page(parent: Control, rows: Array) -> Control:
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
			var hl := UiKit.label(String(r[2]).to_upper(), 12, UiKit.ACCENT, 600)
			hl.custom_minimum_size = Vector2(0, 26)
			hl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			g.add_child(hl)
			g.add_child(Control.new())
			continue
		var lbl := UiKit.label(r[2], 14)
		lbl.custom_minimum_size = Vector2(250, 0)
		lbl.tooltip_text = r[4]
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		g.add_child(lbl)
		var c: Control
		match kind:
			"option":
				var ob := OptionButton.new()
				for item in r[3]:
					ob.add_item(item)
				ob.custom_minimum_size = Vector2(220, 30)
				ob.item_selected.connect(func(i): _apply(key, MOODS[i] if key == "mood" else i))
				c = ob
			"check":
				var cb := CheckButton.new()
				cb.toggled.connect(func(on): _apply(key, on))
				c = cb
			"slider":
				var hb := HBoxContainer.new()
				var sl := HSlider.new()
				sl.min_value = r[3][0]
				sl.max_value = r[3][1]
				sl.step = r[3][2]
				sl.custom_minimum_size = Vector2(170, 24)
				sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var vl := UiKit.label("", 13, UiKit.DIM)
				vl.custom_minimum_size = Vector2(46, 0)
				var deg: bool = r.size() > 5 and r[5] == "deg"
				hb.set_meta("deg", deg)
				sl.value_changed.connect(func(v): vl.text = ("%d°" % int(v)) if deg else "%d%%" % int(round(v * 100.0)); _apply(key, v))
				hb.add_child(sl)
				hb.add_child(vl)
				hb.set_meta("slider", sl)
				hb.set_meta("val", vl)
				c = hb
		c.tooltip_text = r[4]
		g.add_child(c)
		_rows[key] = c
	return sc


func _show_tab(key: String) -> void:
	_tab = key
	for k in _pages:
		_pages[k].visible = k == key
		_tab_btns[k].button_pressed = k == key


func _apply(key: String, v) -> void:
	if _syncing:
		return
	Settings.set_v(key, v)


func _sync() -> void:
	_syncing = true
	for p in _preset_btns:
		_preset_btns[p].button_pressed = Settings.preset == p
	var cl := find_child("Custom", true, false) as Label
	if cl:
		cl.text = "  (custom)" if Settings.preset == "custom" else ""
	for key in _rows:
		var c: Control = _rows[key]
		var v = Settings.get_v(key)
		if c is OptionButton:
			if key == "mood":
				(c as OptionButton).select(maxi(0, MOODS.find(String(v))))
			else:
				(c as OptionButton).select(int(v))
		elif c is CheckButton:
			(c as CheckButton).button_pressed = bool(v)
		elif c.has_meta("slider"):
			var sl: HSlider = c.get_meta("slider")
			sl.value = float(v)
			(c.get_meta("val") as Label).text = ("%d°" % int(v)) if c.get_meta("deg", false) else "%d%%" % int(round(float(v) * 100.0))
	_syncing = false
