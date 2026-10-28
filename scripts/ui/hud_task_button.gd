extends Button
## Small, labelled tools stay recognizable without relying on an icon alone.
var kind := "battle"
var caption := "View"


func _ready() -> void:
	custom_minimum_size = Vector2(58, 48)
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool): queue_redraw())


func _draw() -> void:
	var active := button_pressed
	var col := UiKit.ACCENT if active else (UiKit.TEXT if is_hovered() else UiKit.DIM)
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.PANEL)
	if active or is_hovered():
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.fa(UiKit.ACCENT if active else UiKit.TEXT, 0.12 if active else 0.05))
	if active:
		draw_rect(Rect2(8, size.y - 2, size.x - 16, 2), UiKit.ACCENT)
	var c := Vector2(size.x * 0.5, 17)
	match kind:
		"battle":
			draw_arc(c, 7, 0, TAU, 24, col, 1.4, true)
			for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_line(c + d * 5, c + d * 11, col, 1.4, true)
		"squads":
			for x in [-8.0, 0.0, 8.0]:
				var p: Vector2 = c + Vector2(x, -2 if x == 0.0 else 1)
				draw_circle(p + Vector2(0, -4), 2.5, col, false, 1.4, true)
				draw_polyline(PackedVector2Array([p + Vector2(-4, 7), p + Vector2(-4, 3), p + Vector2(4, 3), p + Vector2(4, 7)]), col, 1.4, true)
		"map":
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var p: Vector2 = c + d * 8
				draw_polyline(PackedVector2Array([p - Vector2(d.x * 5, 0), p, p - Vector2(0, d.y * 5)]), col, 1.4, true)
			draw_line(c + Vector2(-3, 3), c + Vector2(3, -3), col, 1.4, true)
		"fires":
			draw_line(c + Vector2(0, -4), c + Vector2(0, 9), col, 1.4, true)
			draw_circle(c + Vector2(0, -5), 2, col)
			draw_arc(c + Vector2(0, -5), 6, -PI * 0.8, -PI * 0.2, 14, col, 1.4, true)
			draw_arc(c + Vector2(0, -5), 10, -PI * 0.8, -PI * 0.2, 18, col, 1.4, true)
			draw_line(c + Vector2(-6, 9), c + Vector2(6, 9), col, 1.4, true)
	var width := UiKit.caps_w(caption, 9)
	UiKit.caps_at(self, Vector2((size.x - width) * 0.5, 39), caption, 9, col)
