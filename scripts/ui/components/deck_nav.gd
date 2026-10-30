class_name UiDeckNav
extends Button
## Small, labelled tools stay recognizable without relying on an icon alone.
@export var icon_id := "target":
	set(value):
		icon_id = value
		queue_redraw()
@export var caption := "View":
	set(value):
		caption = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(maxf(72, custom_minimum_size.x), maxf(32, custom_minimum_size.y))
	toggle_mode = true
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool): queue_redraw())


func _draw() -> void:
	var active := button_pressed
	var hover := (is_hovered() or has_focus()) and not disabled
	var col := UiKit.FAINT if disabled else (UiKit.ACCENT if active else (UiKit.TEXT if hover else UiKit.DIM))
	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), UiKit.LINE)
	if (active or hover) and not disabled:
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.fa(UiKit.ACCENT if active else UiKit.TEXT, 0.12 if active else 0.05))
	if active:
		draw_rect(Rect2(8, size.y - 2, size.x - 16, 2), UiKit.ACCENT)
	# Center each icon/label group from its actual font metrics. All icons share
	# the same 20 px slot and baseline, including at the smallest map setting.
	var font := UiKit.cond(600, 1)
	var fs := 11
	var label_width := UiKit.caps_w(caption, fs)
	var start := floorf((size.x - label_width - 26) * 0.5)
	UiDeckIcons.paint(self, icon_id, Vector2(start + 10, floorf(size.y * 0.5)), col)
	var baseline := floorf((size.y - font.get_height(fs)) * 0.5 + font.get_ascent(fs))
	UiKit.caps_at(self, Vector2(start + 26, baseline), caption, fs, col, false)



func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()
