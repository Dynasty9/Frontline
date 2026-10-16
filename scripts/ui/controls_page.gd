class_name ControlsPage
extends VBoxContainer
## Settings > Controls: every action the keys do, by category, each with two
## bindings. Click one and press the new key (a combination with Ctrl, Shift
## or Alt, or a mouse side button); Esc cancels, right-click clears it. A key
## another action already has is moved, with a line saying so and an Undo.
## Each row can go back to its default, and everything can at once. The search
## box finds an action by its name or its key. The mouse's own controls are
## listed at the end for reference.

const COL_W := 136.0

var _search: LineEdit
var _list: VBoxContainer
var _msg: Label
var _undo: Button
var _reset_all: Button
var _reset_armed := 0  # msec the "reset everything" button was first pressed (a second press does it)
var _rows := {}  # id -> {"row", "btns": [Button, Button], "reset": Button, "cat"}
var _cat_heads := {}  # category -> its header row
var _capture := []  # [id, slot] while waiting for a key
var _pending_mod := KEY_NONE  # a modifier pressed on its own: bound if let go without another key
var _snapshot := {}  # the bindings before the last change (Undo)


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	_search = LineEdit.new()
	_search.placeholder_text = "Search actions or keys..."
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size = Vector2(0, 32)
	_search.text_changed.connect(func(_t): _filter())
	top.add_child(_search)
	_reset_all = Button.new()
	_reset_all.text = "Reset all to defaults"
	_reset_all.custom_minimum_size = Vector2(180, 32)
	_reset_all.focus_mode = Control.FOCUS_NONE
	_reset_all.pressed.connect(_on_reset_all)
	top.add_child(_reset_all)
	var hint := UiKit.label("Click a key to change it, then press the new one (with Ctrl, Shift or Alt if you like). Esc cancels, right-click clears.", 12, UiKit.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	add_child(mrow)
	_msg = UiKit.label("", 12, UiKit.WARN, 600)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(_msg)
	_undo = Button.new()
	_undo.text = "Undo"
	_undo.custom_minimum_size = Vector2(70, 26)
	_undo.focus_mode = Control.FOCUS_NONE
	_undo.visible = false
	_undo.pressed.connect(_on_undo)
	mrow.add_child(_undo)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	_build()
	Keys.changed.connect(_refresh)
	visibility_changed.connect(func(): if not is_visible_in_tree(): _stop_capture())
	_refresh()


func _exit_tree() -> void:
	_stop_capture()


# --- the list --------------------------------------------------------------------------------

func _build() -> void:
	for cat in Keys.CATEGORIES:
		var head := _band(_head_row(cat, true))
		_list.add_child(head)
		_cat_heads[cat] = head
		for a in Keys.ACTIONS:
			if a[2] != cat:
				continue
			_list.add_child(_action_row(a))
	var mh := _band(_head_row("Mouse", false))
	_list.add_child(mh)
	_cat_heads["Mouse"] = mh
	for m in Keys.MOUSE:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		var l := UiKit.label(m[0], 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var v := UiKit.label(m[1], 13, UiKit.DIM, 600)
		v.custom_minimum_size = Vector2(COL_W * 2.0 + 8.0, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(v)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(64, 0)
		r.add_child(gap)
		var w := _band(r)
		w.set_meta("text", ("%s %s" % [m[0], m[1]]).to_lower())
		_list.add_child(w)


## A row on a band, so every other one can be shaded (see _filter).
func _band(r: Control) -> PanelContainer:
	var w := PanelContainer.new()
	w.add_theme_stylebox_override("panel", BAND[0])
	w.add_child(r)
	w.set_meta("band", true)
	return w


const BAND_PAD := 3.0
static var BAND: Array = [_band_box(Color(0, 0, 0, 0)), _band_box(Color(1, 1, 1, 0.035))]


static func _band_box(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(4)
	sb.content_margin_left = BAND_PAD + 3.0
	sb.content_margin_right = BAND_PAD
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	return sb


func _head_row(cat: String, cols: bool) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.custom_minimum_size = Vector2(0, 30)
	var hl := UiKit.label(cat.to_upper(), 12, UiKit.ACCENT, 600)
	hl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.size_flags_vertical = Control.SIZE_FILL
	hb.add_child(hl)
	for t in (["Key", "Second key"] if cols else ["", ""]):
		var cl := UiKit.label(t, 11, UiKit.DIM, 600)
		cl.custom_minimum_size = Vector2(COL_W, 0)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		cl.size_flags_vertical = Control.SIZE_FILL
		hb.add_child(cl)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(64, 0)
	hb.add_child(gap)
	return hb


func _action_row(a: Array) -> Control:
	var id: String = a[0]
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var l := UiKit.label(a[1], 14)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.tooltip_text = String(a[6])
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	r.add_child(l)
	var btns := []
	for slot in 2:
		var b := Button.new()
		b.custom_minimum_size = Vector2(COL_W, 30)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 13)
		var s: int = slot
		b.pressed.connect(func(): _start_capture(id, s))
		b.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
				_clear(id, s)
				accept_event())
		r.add_child(b)
		btns.append(b)
	var rs := Button.new()
	rs.text = "Reset"
	rs.tooltip_text = "Back to the default"
	rs.custom_minimum_size = Vector2(64, 30)
	rs.focus_mode = Control.FOCUS_NONE
	rs.add_theme_font_size_override("font_size", 12)
	rs.pressed.connect(func(): _snap(); Keys.reset(id); _say("“%s” is back to its default." % Keys.title(id), false))
	r.add_child(rs)
	var w := _band(r)
	_rows[id] = {"row": w, "btns": btns, "reset": rs, "cat": String(a[2])}
	return w


## Every row's keys as they are now: the one being rebound waits, changed ones stand out.
func _refresh() -> void:
	for id in _rows:
		var rw: Dictionary = _rows[id]
		var d := Keys.defaults(id)
		for slot in 2:
			var b: Button = rw.btns[slot]
			var code := Keys.get_bind(id, slot)
			var waiting: bool = _capture.size() == 2 and _capture[0] == id and int(_capture[1]) == slot
			if waiting:
				b.text = "Press a key..."
				b.add_theme_color_override("font_color", UiKit.ACCENT)
				b.add_theme_stylebox_override("normal", UiKit.box(Color(0.24, 0.22, 0.15, 0.95), 5, UiKit.ACCENT, 1, 6.0))
				continue
			b.remove_theme_stylebox_override("normal")
			var nm := Keys.name_of(code)
			b.text = nm if nm != "" else "—"
			var changed: bool = code != d[slot]
			b.add_theme_color_override("font_color", UiKit.DIM if nm == "" else (UiKit.ACCENT if changed else UiKit.TEXT))
			var dn := Keys.name_of(d[slot])
			b.tooltip_text = ("Default: %s" % (dn if dn != "" else "none")) + "\nClick to change, right-click to clear."
		(rw.reset as Button).disabled = Keys.is_default(id)
	_filter()


func _filter() -> void:
	var q := _search.text.strip_edges().to_lower() if _search else ""
	var shown := {}
	for id in _rows:
		var rw: Dictionary = _rows[id]
		var hay := ("%s %s %s %s" % [Keys.title(id), rw.cat, Keys.label(id, true), id]).to_lower()
		var on := q == "" or q in hay
		(rw.row as Control).visible = on
		if on:
			shown[rw.cat] = true
	for r in _list.get_children():
		if r.has_meta("text"):
			var on2 := q == "" or q in String(r.get_meta("text"))
			r.visible = on2
			if on2:
				shown["Mouse"] = true
	for cat in _cat_heads:
		(_cat_heads[cat] as Control).visible = shown.has(cat)
	# every other row shaded, starting again under each heading
	var odd := false
	for r in _list.get_children():
		if not r.visible:
			continue
		if _cat_heads.values().has(r):
			odd = false
			continue
		(r as Control).add_theme_stylebox_override("panel", BAND[1 if odd else 0])
		odd = not odd


# --- rebinding -------------------------------------------------------------------------------

func _start_capture(id: String, slot: int) -> void:
	_capture = [id, slot]
	_pending_mod = KEY_NONE
	Keys.capturing = true
	_say("Press the new key for “%s”  (Esc cancels)." % Keys.title(id), false)
	_refresh()


func _stop_capture() -> void:
	if _capture.is_empty():
		return
	_capture = []
	_pending_mod = KEY_NONE
	Keys.capturing = false
	_refresh()


func _input(ev: InputEvent) -> void:
	if _capture.is_empty() or not is_visible_in_tree():
		return
	if ev is InputEventKey:
		var k := ev as InputEventKey
		get_viewport().set_input_as_handled()
		if k.echo:
			return
		var key := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		if k.pressed:
			if key == KEY_ESCAPE:
				_stop_capture()
				_say("", false)
				return
			if key in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
				_pending_mod = key  # it may be meant on its own (pan faster): see the release
				return
			_assign(Keys.code_of(k))
		elif key == _pending_mod:
			# a modifier pressed and let go on its own: that's the key
			_assign(key)
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2:
				get_viewport().set_input_as_handled()
				_assign(Keys.code_of(mb))
			MOUSE_BUTTON_MIDDLE:
				get_viewport().set_input_as_handled()
				_say("The middle button turns and grabs the camera: pick another.", true)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				# a click somewhere else calls it off (and goes on to whatever it was on)
				_stop_capture()
				_say("", false)


func _assign(code: int) -> void:
	if _capture.size() != 2:
		return
	var id: String = _capture[0]
	var slot: int = _capture[1]
	_capture = []
	_pending_mod = KEY_NONE
	Keys.capturing = false
	if code == Keys.get_bind(id, slot):
		_refresh()
		_say("", false)
		return
	_snap()
	# the same key in this action's other slot: it only needs it once
	if Keys.get_bind(id, 1 - slot) == code:
		Keys.binds[id][1 - slot] = Keys.NONE
	var taken := Keys.clashes(id, code)
	for c in taken:
		Keys.binds[c[0]][int(c[1])] = Keys.NONE
	Keys.set_bind(id, slot, code)
	if taken.is_empty():
		_say("“%s” is now %s." % [Keys.title(id), Keys.name_of(code)], false, true)
	else:
		var names := []
		for c in taken:
			names.append("“%s”" % Keys.title(c[0]))
		_say("%s was on %s, which has nothing on it now." % [Keys.name_of(code), ", ".join(names)], true, true)


func _clear(id: String, slot: int) -> void:
	_stop_capture()
	if Keys.get_bind(id, slot) == Keys.NONE:
		return
	_snap()
	Keys.set_bind(id, slot, Keys.NONE)
	_say("Cleared a key from “%s”." % Keys.title(id), false, true)


func _on_reset_all() -> void:
	var now := Time.get_ticks_msec()
	if now - _reset_armed > 3000:
		# a second press within three seconds does it
		_reset_armed = now
		_reset_all.text = "Click again to reset all"
		get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(_reset_all): _reset_all.text = "Reset all to defaults")
		return
	_reset_armed = 0
	_reset_all.text = "Reset all to defaults"
	_stop_capture()
	_snap()
	Keys.reset_all()
	_say("Every key is back to its default.", false, true)


func _snap() -> void:
	_snapshot = Keys.binds.duplicate(true)


func _on_undo() -> void:
	if _snapshot.is_empty():
		return
	Keys.binds = _snapshot.duplicate(true)
	_snapshot = {}
	Keys.save()
	Keys.changed.emit()
	_say("Undone.", false)


func _say(text: String, warn: bool, undo := false) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", UiKit.WARN if warn else UiKit.DIM)
	_undo.visible = undo and not _snapshot.is_empty()
