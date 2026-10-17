extends Control
## --ui-gallery=PATH [--gallery-theme=KEY] [--gallery-scene=PATH.png]: every
## Signal component (docs/UI.md) in each of its states on one screen, saved as
## PATH and quit. A screenshot per theme shows the whole kit at once and
## catches a component that has drifted from the reference. With a scene image
## behind it, the scrims and the world marks are shown over a battlefield.

var args := {}
var _frames := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if args.has("gallery-theme"):
		UiKit.apply_theme(String(args["gallery-theme"]), get_tree())
	theme = UiKit.theme()
	var bg := ColorRect.new()
	bg.color = UiKit.INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scene := TextureRect.new()
	if args.has("gallery-scene"):
		var img := Image.load_from_file(String(args["gallery-scene"]))
		if img:
			scene.texture = ImageTexture.create_from_image(img)
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.anchor_left = 0.62
	scene.anchor_right = 1.0
	scene.anchor_bottom = 1.0
	add_child(scene)
	var scene_ui := Control.new()
	scene_ui.anchor_left = 0.62
	scene_ui.anchor_right = 1.0
	scene_ui.anchor_bottom = 1.0
	scene_ui.clip_contents = true
	add_child(scene_ui)
	scene_ui.add_child(UiScrim.make("top", 130.0))
	scene_ui.add_child(UiScrim.make("left", 300.0, 420.0))
	scene_ui.add_child(UiScrim.make("bottom", 260.0))
	var marks := _Marks.new()
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_ui.add_child(marks)
	var status := HBoxContainer.new()
	status.position = Vector2(20, 18)
	status.add_theme_constant_override("separation", 14)
	scene_ui.add_child(status)
	for p in [["Sup", "615"], ["Units", "8/26"], ["FOB", "1"]]:
		status.add_child(UiKit.caps(p[0], 11, UiKit.FAINT))
		status.add_child(UiKit.mono_label(p[1], 15, UiKit.TEXT))
	status.add_child(UiKit.mono_label("T+04:31", 15, UiKit.TEXT))

	var cols := HBoxContainer.new()
	cols.position = Vector2(40, 36)
	cols.add_theme_constant_override("separation", 44)
	add_child(cols)
	var c1 := _col(cols, 380)
	var c2 := _col(cols, 380)

	c1.add_child(UiKit.caps("Frontline · interface kit · %s" % UiKit.THEMES[UiKit.theme_key].name, 12, UiKit.ACCENT))
	c1.add_child(UiKit.header("Voices"))
	for v in [["Label", UiKit.caps("Order of battle", 11, UiKit.TEXT)], ["Name", UiKit.caps("Foxtrot 1", 13, UiKit.TEXT, 600, 1)],
			["Figure", UiKit.mono_label("615  8/26  T+04:31", 15, UiKit.TEXT)], ["Code", UiKit.mono_label("MOV D8 · 4/5 · AMMO 80%", 12, UiKit.DIM)],
			["Prose", UiKit.label("Throws smoke at the cursor.", 13, UiKit.DIM)]]:
		var hb := HBoxContainer.new()
		var t := UiKit.mono_label(String(v[0]).to_upper(), 11, UiKit.FAINT)
		t.custom_minimum_size = Vector2(80, 0)
		hb.add_child(t)
		hb.add_child(v[1])
		c1.add_child(hb)
	c1.add_child(UiKit.header("Actions"))
	var br := HFlowContainer.new()
	br.add_theme_constant_override("h_separation", 8)
	br.add_theme_constant_override("v_separation", 8)
	c1.add_child(br)
	br.add_child(UiKit.primary_button("Start battle", 0, 32, 13))
	br.add_child(UiKit.button("Watch"))
	br.add_child(UiKit.button("Copy link", "quiet"))
	br.add_child(UiKit.button("Leave", "danger"))
	var dis := UiKit.button("Waiting")
	dis.disabled = true
	br.add_child(dis)
	var tg := Button.new()
	tg.text = "TOGGLED"
	tg.toggle_mode = true
	tg.button_pressed = true
	br.add_child(tg)
	c1.add_child(UiKit.header("Tags"))
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	c1.add_child(tags)
	for t2 in [["You", UiKit.ACCENT], ["Ready", UiKit.GOOD], ["Not ready", UiKit.WARN], ["Defeated", UiKit.BAD], ["Listed", UiKit.INTEL], ["Coalition", Defs.TEAM_COLORS[0]], ["Rebels", Defs.TEAM_COLORS[1]], ["4/8", UiKit.DIM]]:
		tags.add_child(UiKit.chip(t2[0], t2[1]))
	c1.add_child(UiKit.header("Options"))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 8)
	c1.add_child(g)
	g.add_child(UiKit.caps("Theme", 11, UiKit.DIM))
	g.add_child(UiSeg.make(["Brass", "Night", "Thermal", "Arctic", "Dusk"], UiKit.THEME_KEYS.find(UiKit.theme_key)))
	g.add_child(UiKit.caps("Labels", 11, UiKit.DIM))
	g.add_child(UiSeg.make(["Off", "On"], 1))
	g.add_child(UiKit.caps("Scale", 11, UiKit.DIM))
	var st := UiSteps.new()
	st.min_value = 0.6
	st.max_value = 2.0
	st.step = 0.05
	st.value = 1.3
	g.add_child(st)
	g.add_child(UiKit.caps("Callsign", 11, UiKit.DIM))
	var le := LineEdit.new()
	le.text = "COMMANDER"
	le.custom_minimum_size = Vector2(200, 0)
	g.add_child(le)
	g.add_child(UiKit.caps("Map", 11, UiKit.DIM))
	var ob := OptionButton.new()
	for it in ["Crossroads", "River town", "Coast"]:
		ob.add_item(it)
	g.add_child(ob)
	g.add_child(UiKit.caps("Switch", 11, UiKit.DIM))
	var cb := CheckButton.new()
	cb.button_pressed = true
	cb.text = "Edge scrolling"
	g.add_child(cb)
	g.add_child(UiKit.caps("Box", 11, UiKit.DIM))
	var ck := CheckBox.new()
	ck.button_pressed = true
	ck.text = "Players can join mid-battle"
	g.add_child(ck)

	c2.add_child(UiKit.header("ORBAT", "05"))
	var rows := _Rows.new()
	rows.custom_minimum_size = Vector2(360, 5 * UiKit.ROW_H)
	c2.add_child(rows)
	c2.add_child(UiKit.header("Orders"))
	var keys := _Keys.new()
	keys.custom_minimum_size = Vector2(360, 82)
	c2.add_child(keys)
	c2.add_child(UiKit.header("Comms"))
	for ln in [["04:20", "Bravo 1", "Contact east, two technicals.", UiKit.ACCENT], ["04:31", "▲ Caution", "Supply low · FOB Alpha · 40", UiKit.WARN], ["04:33", "▲ Warning", "HQ under attack · armour F3", UiKit.BAD]]:
		var hb2 := HBoxContainer.new()
		var tm := UiKit.mono_label(ln[0], 12, UiKit.FAINT if ln[3] == UiKit.ACCENT else ln[3])
		tm.custom_minimum_size = Vector2(46, 0)
		hb2.add_child(tm)
		var nm := UiKit.caps(ln[1], 12, ln[3], 600, 1)
		nm.custom_minimum_size = Vector2(88, 0)
		hb2.add_child(nm)
		hb2.add_child(UiKit.label(ln[2], 13, UiKit.TEXT if ln[3] == UiKit.ACCENT else ln[3]))
		c2.add_child(hb2)
	c2.add_child(UiKit.header("Panel and tooltip"))
	var pc := PanelContainer.new()
	var pv := VBoxContainer.new()
	pc.add_child(pv)
	pv.add_child(UiKit.caps("Paused", 12, UiKit.ACCENT))
	pv.add_child(UiKit.mono_label("OP SCARLET LANTERN · COALITION", 12, UiKit.FAINT))
	c2.add_child(pc)
	var pc2 := PanelContainer.new()
	pc2.add_theme_stylebox_override("panel", UiKit.frame_hot(10.0))
	pc2.add_child(UiKit.label("Accent ticks: a selected region.", 13, UiKit.DIM))
	c2.add_child(pc2)


func _col(parent: Control, w: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(w, 0)
	v.add_theme_constant_override("separation", 10)
	parent.add_child(v)
	return v


func _process(_dt: float) -> void:
	_frames += 1
	if _frames == 30 and args.has("ui-gallery"):
		get_viewport().get_texture().get_image().save_png(String(args["ui-gallery"]))
		TestRun.quit(get_tree())


class _Rows:
	extends Control
	func _draw() -> void:
		var data := [["Bravo 1", "DEF E8", 5, 0, 0, ""], ["Foxtrot 1", "MOV D8", 4, 0, 1, "sel"], ["Alpha 3", "FALL BACK E1", 1, 1, 3, "bad"], ["Golf 2", "PINNED E4", 3, 1, 1, "warn"], ["Charlie 1", "BUILD E5", 4, 0, 0, ""]]
		for i in data.size():
			var d: Array = data[i]
			var y := i * UiKit.ROW_H
			if d[5] == "sel":
				draw_rect(Rect2(0, y, size.x, UiKit.ROW_H - 1), UiKit.fa(UiKit.ACCENT, 0.16))
			MapSymbols.nato_vec(self, Vector2(11, y + UiKit.ROW_H * 0.5), 16.0, true, 0, "inf")
			var nc := UiKit.ACCENT if d[5] == "sel" else UiKit.TEXT
			UiKit.text_f(self, UiKit.cond(600, 1), Vector2(28, y + 17), String(d[0]).to_upper(), 13, nc, HORIZONTAL_ALIGNMENT_LEFT, -1, false)
			var cc := UiKit.ACCENT if d[5] == "sel" else (UiKit.BAD if d[5] == "bad" else (UiKit.WARN if d[5] == "warn" else UiKit.DIM))
			UiKit.text_f(self, UiKit.mono(), Vector2(140, y + 17), d[1], 12, cc, HORIZONTAL_ALIGNMENT_LEFT, -1, false)
			UiKit.pips(self, Vector2(size.x - 28, y + 8), d[2], d[3], d[4])
			UiKit.rule(self, Vector2(0, y + UiKit.ROW_H - 0.5), Vector2(size.x, y + UiKit.ROW_H - 0.5))


class _Keys:
	extends Control
	func _draw() -> void:
		var data := [["X", "Attack"], ["D", "Defend"], ["H", "Hold"], ["T", "Smoke"], ["G", "Grenade"], ["B", "Build"], ["F", "Base of fire"], ["V", "Defences"], ["R", "Retreat"]]
		for i in data.size():
			var x := (i % 3) * 122.0
			var y := (i / 3) * 26.0
			var on := i == 0
			var w := UiKit.key(self, Vector2(x, y + 4), data[i][0], on)
			var c := UiKit.ACCENT if on else (UiKit.BAD if data[i][0] == "R" else UiKit.TEXT)
			UiKit.text_f(self, UiKit.cond(600, 1), Vector2(x + w + 8, y + 16), String(data[i][1]).to_upper(), 12, c, HORIZONTAL_ALIGNMENT_LEFT, -1, false)


class _Marks:
	extends Control
	func _draw() -> void:
		var r := Rect2(size.x * 0.25, size.y * 0.42, 110, 44)
		UiKit.ticks(self, r, UiKit.ACCENT)
		UiKit.text_f(self, UiKit.cond(600, 1), r.position + Vector2(0, r.size.y + 22), "FOXTROT 1", 12, UiKit.ACCENT)
		UiKit.text_f(self, UiKit.mono(), r.position + Vector2(0, r.size.y + 36), "MOV D8", 11, UiKit.DIM)
		var a := r.position + Vector2(r.size.x, r.size.y * 0.5)
		var b := a + Vector2(150, 70)
		draw_dashed_line(a, b, UiKit.ACCENT, 1.2, 5.0)
		draw_polyline(PackedVector2Array([b + Vector2(0, -6), b + Vector2(6, 0), b + Vector2(0, 6), b + Vector2(-6, 0), b + Vector2(0, -6)]), UiKit.ACCENT, 1.2)
		UiKit.text_f(self, UiKit.mono(), b + Vector2(12, 4), "D8 · 140M", 12, UiKit.ACCENT)
