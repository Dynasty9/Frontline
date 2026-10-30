class_name UiDeckAction
extends Button
## Presentation only: the caller supplies an ID, icon and callback, never a World.
const DEFAULT_SIZE := Vector2(100, 46)
var action_id := ""
var icon_id := "target"
var dangerous := false
var active := false
var _theme_rev := -1
var caption: Label
var keycap: UiDeckKeycap
var value_label: Label


func _init() -> void:
	custom_minimum_size = DEFAULT_SIZE
	for state in ["normal", "disabled", "focus", "hover", "pressed", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	caption = UiKit.caps("", 11, UiKit.TEXT, 600, 0)
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.position = Vector2(8, 23)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	keycap = UiDeckKeycap.new()
	keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(keycap)
	keycap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	keycap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	keycap.offset_left = -6
	keycap.offset_right = -6
	keycap.offset_top = 5
	keycap.offset_bottom = 5
	keycap.hide()
	value_label = UiKit.mono_label("", 10, UiKit.DIM)
	value_label.clip_text = true
	value_label.position = Vector2(42, 7)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(value_label)
	resized.connect(_layout)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func configure(spec: Dictionary) -> void:
	action_id = spec.get("id", "")
	icon_id = spec.get("icon", "target")
	dangerous = spec.get("dangerous", false)
	active = spec.get("active", false)
	disabled = spec.get("disabled", false)
	caption.text = spec.get("label", "")
	var binding: String = spec.get("key", "")
	keycap.visible = not binding.is_empty()
	keycap.set_binding(binding)
	value_label.text = spec.get("value", "")
	value_label.visible = binding.is_empty() and not value_label.text.is_empty()
	tooltip_text = spec.get("tooltip", caption.text)
	if not binding.is_empty():
		tooltip_text += "\nShortcut: " + binding
	_sync_style()
	_layout.call_deferred()


func set_active(value: bool) -> void:
	if active != value:
		active = value
		_sync_style()


func _layout() -> void:
	caption.size = Vector2(maxf(1, size.x - 16), 22)
	value_label.size = Vector2(maxf(1, size.x - 48), 20)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _theme_rev != UiKit.theme_rev and caption and keycap and value_label:
		_sync_style()


func _sync_style() -> void:
	_theme_rev = UiKit.theme_rev
	caption.add_theme_color_override("font_color", UiKit.BAD if dangerous else (UiKit.ACCENT if active else UiKit.TEXT))
	value_label.add_theme_color_override("font_color", UiKit.DIM)
	keycap.set_active(active)
	queue_redraw()


func _draw() -> void:
	var hover := (is_hovered() or has_focus()) and not disabled
	var col := UiKit.BAD if dangerous else (UiKit.ACCENT if active or hover else UiKit.TEXT)
	if disabled:
		col = UiKit.FAINT
	var ink := UiKit.fa(UiKit.ACCENT, 0.10) if active else UiKit.fa(UiKit.TEXT, 0.06 if hover else 0.015)
	draw_rect(Rect2(Vector2.ZERO, size), ink)
	draw_line(Vector2(8, size.y - 1), Vector2(size.x - 8, size.y - 1), UiKit.LINE)
	if active:
		draw_rect(Rect2(0, 5, 2, size.y - 10), UiKit.ACCENT)
	if has_focus():
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), UiKit.ACCENT, false)
	for child: Control in [caption, keycap, value_label]:
		child.modulate.a = 0.4 if disabled else 1.0
	draw_set_transform(Vector2(3, 2), 0, Vector2(0.85, 0.85))
	UiDeckIcons.paint(self, icon_id, Vector2(18, 13), col)
	draw_set_transform(Vector2.ZERO)
