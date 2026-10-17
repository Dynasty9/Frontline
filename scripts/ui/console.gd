class_name Console
extends CanvasLayer
## The console: the key under Esc (` or ~ unless rebound) drops it down from
## the top of the screen, anywhere, the menus included. Typed commands bring
## up performance panels, work out why the game is slow, measure what each
## graphics setting costs, and change settings on the spot; `help` lists them
## (console_cmds.gd). Tab completes a command or its argument, Up and Down go
## through what was typed before, Esc or the key again closes it.

const HISTORY_PATH := "user://console_history.txt"
const HISTORY_KEEP := 60
const MAX_LINES := 600
const HEIGHT := 0.46  # of the screen
const SLIDE_S := 0.12

var main: Node  # main.gd: its world
var probe: PerfProbe
var cmds: ConsoleCmds
var graph: PerfGraph
var is_open := false

var _panel: Control
var _log: RichTextLabel
var _edit: LineEdit
var _hint: Label
var _find: LineEdit
var _find_row: HBoxContainer
var _find_status: Label
var _find_at := -1
var _font_size := 13
var _shown := 0.0  # how far down it has slid, 0..1
var _last_us := 0
var _history := PackedStringArray()
var _hist_i := -1  # browsing the history: which entry (-1: the line being typed)
var _typed := ""  # the line being typed, kept while browsing the history
var _greeted := false
var _capture: Array = []  # a command's output, while it's being collected (the test port, report)
var _capturing := 0
## --console=LINE;LINE [--console-at=SECONDS]: typed in once a battle has run
## that long (5 s unless set), for screenshots and tests; what they print goes
## to the terminal too, as CONSOLE lines
var _auto := PackedStringArray()
var _auto_at := 5.0
var _echo := false


func _ready() -> void:
	layer = 125  # over the interface and the loading screen
	process_mode = Node.PROCESS_MODE_ALWAYS
	cmds = ConsoleCmds.new(self)
	graph = PerfGraph.new()
	graph.probe = probe
	graph.visible = false
	add_child(graph)
	_build()
	_load_history()
	if main and main.args.has("console"):
		_auto = String(main.args.console).split(";", false)
		_auto_at = float(main.args.get("console-at", 5.0))


func _build() -> void:
	_panel = Control.new()
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = HEIGHT
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	_panel.theme = UiKit.theme()
	add_child(_panel)
	# the theme's ink, nearly opaque (it's read over a moving battlefield), and
	# a rule along its bottom edge (both recoloured when the theme changes)
	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UiKit.box(UiKit.fa(UiKit.INK, 0.96), 0, Color(0, 0, 0, 0), 0, 0.0))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bg)
	var edge := ColorRect.new()
	edge.color = UiKit.RULE2
	edge.anchor_top = 1.0
	edge.anchor_right = 1.0
	edge.anchor_bottom = 1.0
	edge.offset_top = -1.0
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(edge)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14
	box.offset_right = -14
	box.offset_top = 8
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var tools := HFlowContainer.new()
	tools.add_theme_constant_override("h_separation", 8)
	box.add_child(tools)
	for entry in [["Copy all", _copy_all], ["Save text", save_text], ["Find", _show_find], ["Latest", _latest], ["Clear", clear], ["A-", func(): _zoom(-1)], ["A+", func(): _zoom(1)]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		tools.add_child(button)
	_find_row = HBoxContainer.new()
	_find_row.visible = false
	box.add_child(_find_row)
	_find = LineEdit.new()
	_find.placeholder_text = "Find in output (Enter: next, Shift+Enter: previous)"
	_find.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_find.text_changed.connect(func(_s: String): _find_at = -1; _find_next())
	_find_row.add_child(_find)
	_find_status = UiKit.mono_label("", 12, UiKit.DIM)
	_find_row.add_child(_find_status)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.focus_mode = Control.FOCUS_ALL
	_log.context_menu_enabled = true
	_log.deselect_on_focus_loss_enabled = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_override("normal_font", UiKit.mono(400))
	_log.add_theme_font_override("bold_font", UiKit.mono(700))
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.add_theme_font_size_override("bold_font_size", 13)
	_log.add_theme_color_override("default_color", UiKit.TEXT)
	box.add_child(_log)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var prompt := UiKit.mono_label(">", 15, UiKit.ACCENT)
	row.add_child(prompt)
	_edit = LineEdit.new()
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.add_theme_font_override("font", UiKit.mono(400))
	_edit.add_theme_font_size_override("font_size", 14)
	_edit.placeholder_text = "why, bench, graph, top, hitches, help..."
	_edit.context_menu_enabled = true
	_edit.focus_entered.connect(func(): _log.deselect())
	_edit.keep_editing_on_text_submit = true
	_edit.text_submitted.connect(_on_submit)
	_edit.text_changed.connect(func(_t: String): _hint.text = _hint_for(_edit.text))
	row.add_child(_edit)
	_hint = UiKit.mono_label(_hint_for(""), 12, UiKit.DIM)
	box.add_child(_hint)


# --- opening and closing ---------------------------------------------------------------------

func open() -> void:
	if is_open:
		return
	is_open = true
	Keys.console_open = true
	probe.detail = true
	_panel.visible = true
	_edit.grab_focus()
	if not _greeted:
		_greeted = true
		out("Frontline console. [b]why[/b] works out what's slowing the game down, [b]bench[/b] measures what each graphics setting costs, [b]graph[/b] and [b]perf 3[/b] bring up the panels. [b]help[/b] lists everything.", UiKit.ACCENT, true)
		out("Select output to copy it. Ctrl+Shift+C copies output; Ctrl+Shift+V pastes into the prompt. Ctrl+F finds, Ctrl+L clears, Esc closes.", UiKit.DIM)


func close() -> void:
	if not is_open:
		return
	is_open = false
	Keys.console_open = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus and _panel.is_ancestor_of(focus):
		focus.release_focus()
	_hist_i = -1


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _input(ev: InputEvent) -> void:
	if not ev is InputEventKey or not ev.pressed or Keys.capturing:
		return
	var k := ev as InputEventKey
	if not is_open:
		# (not while something else is being typed: a chat line, a callsign)
		if not k.echo and Keys.is_event(k, "console") and not get_viewport().gui_get_focus_owner() is LineEdit and not get_viewport().gui_get_focus_owner() is TextEdit:
			open()
			get_viewport().set_input_as_handled()
		return
	if _log.is_menu_visible() or _edit.is_menu_visible() or _find.is_menu_visible():
		return
	if k.keycode == KEY_ESCAPE and _find_row.visible:
		_find_row.hide()
		_edit.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if Keys.is_event(k, "console") or k.keycode == KEY_ESCAPE:
		if not k.echo:
			close()
		get_viewport().set_input_as_handled()
		return
	if k.ctrl_pressed or k.meta_pressed:
		match k.keycode:
			KEY_C:
				if (_edit.has_focus() and _edit.has_selection()) or _find.has_focus():
					return
				if not _log.get_selected_text().is_empty():
					DisplayServer.clipboard_set(_log.get_selected_text())
				elif k.shift_pressed:
					_copy_all()
				else:
					_set_line("")
					_hist_i = -1
					cmds.cancel()
					_edit.grab_focus()
			KEY_V:
				if _find.has_focus():
					return
				_edit.grab_focus()
				_edit.menu_option(LineEdit.MENU_PASTE)
			KEY_F:
				_show_find()
			KEY_L:
				clear()
			KEY_HOME:
				_log.get_v_scroll_bar().value = 0
			KEY_END:
				_latest()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				_zoom(1)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom(-1)
			KEY_0:
				_zoom(13 - _font_size)
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if _find.has_focus():
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			_find_next(k.shift_pressed)
			get_viewport().set_input_as_handled()
		return
	match k.keycode:
		KEY_TAB:
			if not _edit.has_focus() or k.shift_pressed:
				return
			_complete()
		KEY_UP:
			if not _edit.has_focus():
				return
			_browse(1)
		KEY_DOWN:
			if not _edit.has_focus():
				return
			_browse(-1)
		KEY_PAGEUP:
			_log.get_v_scroll_bar().value -= _log.size.y * 0.8
		KEY_PAGEDOWN:
			_log.get_v_scroll_bar().value += _log.size.y * 0.8
		_:
			return
	get_viewport().set_input_as_handled()


func _process(_dt: float) -> void:
	# it slides by the wall clock (the battle may be paused or sped up)
	var now := Time.get_ticks_usec()
	var rdt := clampf((now - _last_us) / 1e6, 0.0, 0.1) if _last_us > 0 else 0.016
	_last_us = now
	_shown = move_toward(_shown, 1.0 if is_open else 0.0, rdt / SLIDE_S)
	_panel.visible = _shown > 0.0
	if _panel.visible:
		var h := get_viewport().get_visible_rect().size.y * HEIGHT
		_panel.offset_top = -h * (1.0 - ease(_shown, 0.5))
		_panel.offset_bottom = _panel.offset_top
	# keep the keyboard while open (a click on the battlefield would take it)
	if is_open and not _edit.has_focus():
		var f := get_viewport().gui_get_focus_owner()
		if (f == null or not _panel.is_ancestor_of(f)) and not _log.is_menu_visible() and not _edit.is_menu_visible():
			_edit.grab_focus()
	cmds.process()
	if not _auto.is_empty() and probe.world() and probe.world().time >= _auto_at:
		open()
		_echo = true
		for l in _auto:
			_on_submit(l)
		_auto.clear()


# --- output ----------------------------------------------------------------------------------

## A line in the console, in a colour; `bb` keeps BBCode in the text ([b] and the like).
func out(text: String, col := Color(0, 0, 0, 0), bb := false) -> void:
	if _capturing > 0:
		_capture.append(_plain(text) if bb else text)
		return
	if _echo:
		print("CONSOLE " + (_plain(text) if bb else text))
	var t := text if bb else text.replace("[", "[lb]")
	if col.a > 0.0:
		t = "[color=#%s]%s[/color]" % [col.to_html(false), t]
	_log.append_text(t + "\n")
	while _log.get_paragraph_count() > MAX_LINES:
		_log.remove_paragraph(0)


func head(text: String) -> void:
	out(text, UiKit.ACCENT)


func good(text: String) -> void:
	out(text, UiKit.GOOD)


func warn(text: String) -> void:
	out(text, UiKit.WARN)


func bad(text: String) -> void:
	out(text, UiKit.BAD)


func dim(text: String) -> void:
	out(text, UiKit.DIM)


func clear() -> void:
	_log.clear()
	_find_at = -1
	_find_status.text = ""


static func _plain(bb: String) -> String:
	var re := RegEx.create_from_string("\\[/?[a-z]+(=[^\\]]*)?\\]")
	return re.sub(bb, "", true)


## Runs a line as if typed, and returns what it printed (the test port, report).
func run_captured(line: String) -> PackedStringArray:
	var prev := _capture
	_capture = []
	_capturing += 1
	cmds.run(line)
	var got := PackedStringArray(_capture)
	_capture = prev
	_capturing -= 1
	return got


func _copy_all() -> void:
	DisplayServer.clipboard_set(_log.get_parsed_text())


func save_text() -> void:
	var path := "user://console_%s_%d.txt" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_msec()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		bad("Could not save console text: " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(_log.get_parsed_text())
	file.close()
	good("Saved console text: " + ProjectSettings.globalize_path(path))


func _latest() -> void:
	_log.get_v_scroll_bar().value = _log.get_v_scroll_bar().max_value


func _zoom(delta: int) -> void:
	_font_size = clampi(_font_size + delta, 10, 24)
	_log.add_theme_font_size_override("normal_font_size", _font_size)
	_log.add_theme_font_size_override("bold_font_size", _font_size)
	_edit.add_theme_font_size_override("font_size", _font_size + 1)


func _show_find() -> void:
	_find_row.show()
	_find.grab_focus()
	_find.select_all()


func _find_next(backward := false) -> void:
	var query := _find.text
	if query.is_empty():
		_find_status.text = ""
		return
	var text := _log.get_parsed_text()
	var pos := -1
	if backward:
		if _find_at > 0:
			pos = text.rfindn(query, _find_at - 1)
		if pos < 0:
			pos = text.rfindn(query)
	else:
		pos = text.findn(query, _find_at + 1)
		if pos < 0:
			pos = text.findn(query)
	_find_at = pos
	if pos < 0:
		_find_status.text = "No matches"
	else:
		var paragraph := text.left(pos).count("\n")
		_log.scroll_to_paragraph(paragraph)
		_find_status.text = "Line %d" % (paragraph + 1)


# --- typing ----------------------------------------------------------------------------------

func _on_submit(text: String) -> void:
	var line := text.strip_edges()
	_edit.clear()
	_hist_i = -1
	_hint.text = _hint_for("")
	if line == "":
		return
	out("> " + line, UiKit.ACCENT)
	if _history.is_empty() or _history[_history.size() - 1] != line:
		_history.append(line)
		if _history.size() > HISTORY_KEEP:
			_history = _history.slice(_history.size() - HISTORY_KEEP)
		_save_history()
	_latest.call_deferred()
	cmds.run(line)


## Up (1) and Down (-1) through the lines typed before.
func _browse(dir: int) -> void:
	if _history.is_empty():
		return
	if _hist_i < 0:
		if dir < 0:
			return
		_typed = _edit.text
	var n := _hist_i + dir
	if n < 0:
		_hist_i = -1
		_set_line(_typed)
		return
	_hist_i = mini(n, _history.size() - 1)
	_set_line(_history[_history.size() - 1 - _hist_i])


func _set_line(s: String) -> void:
	_edit.text = s
	_edit.caret_column = s.length()
	_hint.text = _hint_for(s)


## Tab: the rest of a command's name, or of its argument. Several fit: as far
## as they agree, and they're listed.
func _complete() -> void:
	var text := _edit.text
	var parts := text.split(" ")
	var word := parts[parts.size() - 1]
	var options: Array = cmds.names() if parts.size() == 1 else cmds.complete(parts[0].to_lower(), parts.slice(1, parts.size() - 1))
	var fits := []
	for o in options:
		if String(o).begins_with(word.to_lower()):
			fits.append(String(o))
	if fits.is_empty():
		return
	var common: String = fits[0]
	for f in fits:
		while not String(f).begins_with(common):
			common = common.left(common.length() - 1)
	var before := " ".join(parts.slice(0, parts.size() - 1))
	var line := (before + " " if before != "" else "") + common + (" " if fits.size() == 1 else "")
	_set_line(line)
	if fits.size() > 1:
		dim("  " + "   ".join(fits))


## The line under the input: what the command being typed takes.
func _hint_for(text: String) -> String:
	var name := text.strip_edges().split(" ")[0].to_lower()
	var c: Array = cmds.find(name) if name != "" else []
	if c.is_empty():
		return "Tab completes   Up/Down history   Ctrl+F find   Ctrl+L clear   Ctrl+C copy/cancel   Esc closes"
	return "%s %s   %s" % [c[0], c[1], c[2]]


# --- history ---------------------------------------------------------------------------------

func _load_history() -> void:
	var f := FileAccess.open(HISTORY_PATH, FileAccess.READ)
	if f == null:
		return
	for l in f.get_as_text().split("\n", false):
		_history.append(l)


func _save_history() -> void:
	if Settings.no_save:
		return
	var f := FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_history) + "\n")
