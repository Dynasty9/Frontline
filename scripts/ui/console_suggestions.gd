class_name ConsoleSuggestions
extends PanelContainer
## A scrollable command palette. Completing only edits the prompt: commands
## still need a separate Enter so a fuzzy match never runs by surprise.

var console: Console
var list: ItemList
var title: Label
var options: Array[String] = []
var start := 0
var end := 0
var caret := -1
var dismissed := false
var chosen := false


func _ready() -> void:
	anchor_top = 1.0
	anchor_bottom = 1.0
	anchor_right = 1.0
	offset_left = 14
	offset_right = -14
	add_theme_stylebox_override("panel", UiKit.box(UiKit.INK, 0, UiKit.RULE2, 1, 8.0))
	var box := VBoxContainer.new()
	add_child(box)
	title = UiKit.mono_label("", 12, UiKit.DIM)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.focus_mode = Control.FOCUS_NONE
	list.add_theme_font_override("font", UiKit.mono(400))
	list.add_theme_font_size_override("font_size", 14)
	list.item_clicked.connect(func(index: int, _pos: Vector2, button: int):
		if button == MOUSE_BUTTON_LEFT:
			accept(index))
	box.add_child(list)
	hide()


func _process(_dt: float) -> void:
	if console.is_open and console._edit.has_focus() and caret != console._edit.caret_column:
		refresh()
	visible = console.is_open and console._edit.has_focus() and not dismissed
	if visible:
		size.y = minf(minf(230.0, 52.0 + options.size() * 26.0), get_viewport().get_visible_rect().size.y * (1.0 - Console.HEIGHT) - 12.0)


## Prefixes rank ahead of partial spellings and small typos.
static func score(word: String, query: String) -> int:
	if query.is_empty() or word == query:
		return 0
	if word.begins_with(query):
		return 10 + word.length() - query.length()
	var found := word.find(query)
	if found >= 0:
		return 30 + found
	var at := 0
	for letter in word:
		if at < query.length() and letter == query[at]:
			at += 1
	if at == query.length():
		return 60 + word.length() - query.length()
	var previous: Array[int] = []
	for j in range(query.length() + 1):
		previous.append(j)
	for i in range(word.length()):
		var current: Array[int] = [i + 1]
		for j in range(query.length()):
			current.append(mini(mini(current[j] + 1, previous[j + 1] + 1), previous[j] + (0 if word[i] == query[j] else 1)))
		previous = current
	var distance := previous[query.length()]
	return 100 + distance if distance <= (2 if query.length() >= 4 else 1) else -1


func refresh() -> void:
	caret = console._edit.caret_column
	dismissed = false
	chosen = false
	var text := console._edit.text
	start = caret
	while start > 0 and text[start - 1] != " ":
		start -= 1
	end = caret
	while end < text.length() and text[end] != " ":
		end += 1
	var before := text.left(start).split(" ", false)
	var query := text.substr(start, caret - start).to_lower()
	var candidates: Array = console.cmds.names() if before.is_empty() else console.cmds.complete(before[0].to_lower(), before.slice(1))
	var ranked: Array = []
	for candidate in candidates:
		var rank := score(String(candidate).to_lower(), query)
		if rank >= 0:
			ranked.append([rank, String(candidate)])
	ranked.sort_custom(func(a: Array, b: Array): return a[1] < b[1] if a[0] == b[0] else a[0] < b[0])
	options.clear()
	list.clear()
	for match_row in ranked:
		var word: String = match_row[1]
		options.append(word)
		var command: Array = console.cmds.find(word) if before.is_empty() or before[0].to_lower() == "help" else []
		var label := word
		if not command.is_empty():
			label = "%s %s  -  %s" % [word, command[1], command[2]]
		list.add_item(label)
		list.set_item_tooltip(list.item_count - 1, label)
	if not options.is_empty():
		list.select(0)
		list.ensure_current_is_visible()
	title.text = "%d matches | Up/Down choose | Tab inserts | Ctrl+Up/Down history | Esc dismisses" % options.size() if not options.is_empty() else "No suggestions | Enter runs your input | Esc dismisses"
	visible = console.is_open and console._edit.has_focus()


func dismiss() -> void:
	dismissed = true
	hide()


func move_selection(direction: int) -> void:
	if options.is_empty():
		return
	var selected := list.get_selected_items()
	var index := int(selected[0]) if not selected.is_empty() else 0
	list.select(wrapi(index + direction, 0, options.size()))
	list.ensure_current_is_visible()
	chosen = true


func complete() -> void:
	if dismissed:
		refresh()
	var selected := list.get_selected_items()
	if not selected.is_empty():
		accept(selected[0])


func accept(index: int) -> void:
	if index < 0 or index >= options.size():
		return
	var word := options[index]
	var suffix := console._edit.text.substr(end)
	var replacement := console._edit.text.left(start) + word
	var next_caret := replacement.length() + 1
	console._set_line(replacement + (" " if suffix.is_empty() else suffix))
	console._edit.caret_column = next_caret
	console._edit.grab_focus()
	refresh()
