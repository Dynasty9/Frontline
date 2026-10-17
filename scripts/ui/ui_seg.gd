class_name UiSeg
extends HBoxContainer
## A choice of two to six as a row of square segments, the chosen one filled
## with the accent (docs/UI.md, Options): ON | OFF, LOW | MEDIUM | HIGH |
## ULTRA, the five themes. Replaces drop-downs and switches for short choices.

signal changed(index: int)

var selected := -1
var _btns: Array[Button] = []


## A segmented choice of these labels, `sel` chosen.
static func make(items: Array, sel := 0, size := 11) -> UiSeg:
	var s := UiSeg.new()
	s.set_items(items, size)
	s.select(sel)
	return s


func _init() -> void:
	add_theme_constant_override("separation", -1)


func set_items(items: Array, size := 11) -> void:
	for b in _btns:
		b.queue_free()
	_btns.clear()
	var n := UiKit.box(Color(0, 0, 0, 0), 0, UiKit.LINE, 1, 0.0)
	_pad(n)
	var h := UiKit.box(Color(UiKit.TEXT.r, UiKit.TEXT.g, UiKit.TEXT.b, 0.05), 0, UiKit.RULE2, 1, 0.0)
	_pad(h)
	var on := UiKit.box(UiKit.ACCENT, 0, UiKit.ACCENT, 1, 0.0)
	_pad(on)
	for i in items.size():
		var b := Button.new()
		b.text = String(items[i]).to_upper()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 26)
		b.add_theme_font_override("font", UiKit.cond(600, 1))
		b.add_theme_font_size_override("font_size", size)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_stylebox_override("disabled", n)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", UiKit.FAINT)
		b.add_theme_color_override("font_hover_color", UiKit.TEXT)
		b.add_theme_color_override("font_pressed_color", UiKit.ON_ACCENT)
		b.add_theme_color_override("font_hover_pressed_color", UiKit.ON_ACCENT)
		b.add_theme_color_override("font_disabled_color", UiKit.LINE)
		var idx := i
		b.pressed.connect(func():
			select(idx)
			changed.emit(idx))
		add_child(b)
		_btns.append(b)
	select(selected)


func select(i: int) -> void:
	selected = i
	for j in _btns.size():
		_btns[j].set_pressed_no_signal(j == i)


func set_disabled(i: int, off: bool) -> void:
	if i >= 0 and i < _btns.size():
		_btns[i].disabled = off


func set_tooltip(t: String) -> void:
	tooltip_text = t
	for b in _btns:
		b.tooltip_text = t


static func _pad(sb: StyleBoxFlat) -> void:
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
