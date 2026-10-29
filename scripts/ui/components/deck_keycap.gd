class_name UiDeckKeycap
extends PanelContainer
## A bounded key hint; the complete binding remains in its tooltip.
var caption: Label
var active := false
var _theme_rev := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	caption = UiKit.mono_label("", 11, UiKit.TEXT)
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	_sync_style()


func set_binding(binding: String, max_width := 54.0) -> void:
	caption.text = binding.to_upper()
	var natural_width := UiKit.mono_w(caption.text, 11)
	caption.custom_minimum_size.x = minf(max_width, natural_width) if max_width > 0 else natural_width
	tooltip_text = binding
	reset_size()


func set_active(value: bool) -> void:
	if active != value:
		active = value
		_sync_style()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _theme_rev != UiKit.theme_rev and caption:
		_sync_style()


func _sync_style() -> void:
	_theme_rev = UiKit.theme_rev
	var sb := UiKit.box(UiKit.ACCENT if active else Color.TRANSPARENT, 0, UiKit.ACCENT if active else UiKit.RULE2, 1, 0)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	add_theme_stylebox_override("panel", sb)
	caption.add_theme_color_override("font_color", UiKit.ON_ACCENT if active else UiKit.TEXT)
