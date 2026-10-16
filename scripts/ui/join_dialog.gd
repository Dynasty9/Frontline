class_name JoinDialog
extends Control
## The box in the middle of the menu while something network-y happens:
## joining a battle (each step ticked off as it's done, so a player can see
## it's getting somewhere and where it stuck), the password a battle asks for,
## and what went wrong when it does. Dims the menu behind it.

signal cancelled
signal password_entered(pw: String)

enum Mode { HIDDEN, PROGRESS, PASSWORD, FAILED }

var mode := Mode.HIDDEN
var _panel: PanelContainer
var _title: Label
var _sub: Label
var _steps: VBoxContainer
var _msg: Label
var _pw_box: VBoxContainer
var _pw_edit: LineEdit
var _ok_btn: Button
var _cancel_btn: Button
var _step_rows: Array = []  # [HBoxContainer, Spinner, Label]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.035, 0.045, 0.045, 0.97), 6, UiKit.LINE, 1, 24.0, 14))
	add_child(_panel)
	UiKit.fit_center(_panel, Vector2(500, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	_sub = UiKit.label("", 12, UiKit.ACCENT, 700)
	v.add_child(_sub)
	_title = UiKit.label("", 22, UiKit.TEXT, 600)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_steps = VBoxContainer.new()
	_steps.add_theme_constant_override("separation", 6)
	v.add_child(_steps)
	_msg = UiKit.label("", 14, UiKit.DIM)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(440, 0)
	v.add_child(_msg)
	_pw_box = VBoxContainer.new()
	_pw_box.add_theme_constant_override("separation", 6)
	v.add_child(_pw_box)
	_pw_edit = LineEdit.new()
	_pw_edit.secret = true
	_pw_edit.placeholder_text = "Password"
	_pw_edit.custom_minimum_size = Vector2(0, 38)
	_pw_edit.text_submitted.connect(func(_t): _ok())
	_pw_box.add_child(_pw_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	_cancel_btn = Button.new()
	_cancel_btn.custom_minimum_size = Vector2(120, 38)
	_cancel_btn.pressed.connect(_cancel)
	row.add_child(_cancel_btn)
	_ok_btn = UiKit.primary_button("Join", 130, 38)
	_ok_btn.pressed.connect(_ok)
	row.add_child(_ok_btn)


## Start afresh: `what` over the title (JOINING, HOSTING...), and no steps yet.
func begin(what: String, title: String) -> void:
	mode = Mode.PROGRESS
	visible = true
	_sub.text = what.to_upper()
	_sub.add_theme_color_override("font_color", UiKit.ACCENT)
	_title.text = title
	_title.visible = true
	for c in _steps.get_children():
		c.queue_free()
	_step_rows.clear()
	_steps.visible = true
	_msg.text = ""
	_msg.visible = false
	_pw_box.visible = false
	_ok_btn.visible = false
	_cancel_btn.text = "Cancel"
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.15)


## The next step: the one before it is done.
func step(text: String) -> void:
	if mode != Mode.PROGRESS:
		return
	if not _step_rows.is_empty() and String((_step_rows[-1][2] as Label).text) == text:
		return
	_finish_last()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var sp := Spinner.new()
	sp.custom_minimum_size = Vector2(18, 18)
	sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sp)
	var l := UiKit.label(text + "...", 15, UiKit.TEXT)
	h.add_child(l)
	_steps.add_child(h)
	_step_rows.append([h, sp, l])


func _finish_last() -> void:
	if _step_rows.is_empty():
		return
	var last: Array = _step_rows[-1]
	(last[1] as Spinner).done = true
	var l: Label = last[2]
	l.text = l.text.trim_suffix("...")
	l.add_theme_color_override("font_color", UiKit.DIM)


## The battle wants a password. `wrong`: the one given wasn't it.
func ask_password(title: String, wrong: bool) -> void:
	mode = Mode.PASSWORD
	visible = true
	_sub.text = "PASSWORD REQUIRED"
	_sub.add_theme_color_override("font_color", UiKit.ACCENT)
	_title.text = title
	_title.visible = true
	_steps.visible = false
	_msg.visible = true
	_msg.text = "That wasn't the password. Check it with the host and try again." if wrong else "The host has set a password for this battle. Ask them for it."
	_msg.add_theme_color_override("font_color", UiKit.BAD if wrong else UiKit.DIM)
	_pw_box.visible = true
	_pw_edit.text = ""
	_ok_btn.visible = true
	_ok_btn.text = "Join"
	_cancel_btn.text = "Cancel"
	_pw_edit.grab_focus.call_deferred()


## It didn't work: `head` over the title (and `title`, if it's changed),
## and why, in red, until the player closes it.
func fail(head: String, why: String, title := "") -> void:
	if mode == Mode.PROGRESS:
		_finish_last()
		if not _step_rows.is_empty():
			# the step it got stuck on gets a cross, not a tick
			(_step_rows[-1][1] as Spinner).failed = true
			var l: Label = _step_rows[-1][2]
			l.add_theme_color_override("font_color", UiKit.BAD)
	else:
		_steps.visible = false
	mode = Mode.FAILED
	visible = true
	_sub.text = head.to_upper()
	_sub.add_theme_color_override("font_color", UiKit.BAD)
	if title != "":
		_title.text = title
	_title.visible = _title.text != ""
	_msg.visible = true
	_msg.text = why
	_msg.add_theme_color_override("font_color", UiKit.BAD)
	_pw_box.visible = false
	_ok_btn.visible = false
	_cancel_btn.text = "Close"


func close() -> void:
	mode = Mode.HIDDEN
	visible = false
	_title.text = ""


func _ok() -> void:
	if mode != Mode.PASSWORD:
		return
	var pw := _pw_edit.text
	if pw == "":
		_msg.text = "Type the password first."
		_msg.add_theme_color_override("font_color", UiKit.BAD)
		return
	password_entered.emit(pw)


func _cancel() -> void:
	var was := mode
	close()
	if was != Mode.FAILED:
		cancelled.emit()


func _unhandled_input(ev: InputEvent) -> void:
	if visible and ev is InputEventKey and ev.pressed and (ev as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_cancel()


## A turning arc while a step is under way, a tick once it's done (or a
## cross, where it failed).
class Spinner extends Control:
	var done := false
	var failed := false:
		set(v):
			failed = v
			queue_redraw()
	var _a := 0.0

	func _process(dt: float) -> void:
		if not done:
			_a = fmod(_a + dt * 7.0, TAU)
		queue_redraw()
		if done:
			set_process(false)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		if failed:
			draw_line(c + Vector2(-r, -r) * 0.7, c + Vector2(r, r) * 0.7, UiKit.BAD, 2.2, true)
			draw_line(c + Vector2(-r, r) * 0.7, c + Vector2(r, -r) * 0.7, UiKit.BAD, 2.2, true)
			return
		if done:
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.7, 0.0), c + Vector2(-r * 0.15, r * 0.6), c + Vector2(r * 0.8, -r * 0.6)]), UiKit.GOOD, 2.2, true)
			return
		draw_arc(c, r, 0.0, TAU, 24, Color(1, 1, 1, 0.12), 2.0, true)
		draw_arc(c, r, _a, _a + 1.9, 16, UiKit.ACCENT, 2.2, true)
