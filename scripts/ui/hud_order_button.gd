extends Button
## A stable command tile: pictogram above, action below, bound key in the corner.
var order := ""


func _ready() -> void:
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var active: bool = get_meta("on", false)
	var hover := is_hovered() and not disabled
	var danger := order in ["Retreat", "Fall back", "Cancel"]
	var col := UiKit.BAD if danger else (UiKit.ACCENT if active or hover else UiKit.TEXT)
	if disabled:
		col = UiKit.FAINT
	var ink := UiKit.fa(UiKit.ACCENT, 0.16) if active else UiKit.fa(UiKit.TEXT, 0.08 if hover else 0.025)
	draw_rect(Rect2(Vector2.ZERO, size), ink)
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), UiKit.ACCENT if active else UiKit.LINE, false)
	for child in get_children():
		if child is Control:
			child.modulate.a = 0.4 if disabled else 1.0
	var c := Vector2(18, 15)
	var w := 1.6
	match order:
		"Attack-move":
			draw_line(c + Vector2(-7, 6), c + Vector2(7, -6), col, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-1, -6), c + Vector2(7, -6), c + Vector2(7, 2)]), col, w, true)
		"Defend":
			draw_polyline(PackedVector2Array([c + Vector2(-7, -7), c + Vector2(7, -7), c + Vector2(6, 2), c + Vector2(0, 8), c + Vector2(-6, 2), c + Vector2(-7, -7)]), col, w, true)
		"Hold":
			draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), col, false, w)
		"Retreat", "Fall back", "Back":
			for x in [0, 7]:
				draw_polyline(PackedVector2Array([c + Vector2(x, -6), c + Vector2(x - 6, 0), c + Vector2(x, 6)]), col, w, true)
		"Grenade":
			draw_circle(c + Vector2(0, 2), 5.0, col, false, w, true)
			draw_line(c + Vector2(-2, -4), c + Vector2(3, -7), col, w, true)
			draw_line(c + Vector2(3, -7), c + Vector2(7, -3), col, w, true)
		"Smoke", "Mortar smoke", "Fire smoke":
			for x in [-5, 0, 5]:
				draw_arc(c + Vector2(x, 2), 5, PI, TAU, 12, col, w, true)
			draw_line(c + Vector2(-10, 6), c + Vector2(10, 6), col, w, true)
		"Dismount", "Exit here":
			draw_polyline(PackedVector2Array([c + Vector2(-2, -7), c + Vector2(-8, -7), c + Vector2(-8, 7), c + Vector2(-2, 7)]), col, w, true)
			draw_line(c + Vector2(-3, 0), c + Vector2(9, 0), col, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(4, -5), c + Vector2(9, 0), c + Vector2(4, 5)]), col, w, true)
		"Base":
			draw_polyline(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(0, -7), c + Vector2(8, 0), c + Vector2(6, 0), c + Vector2(6, 7), c + Vector2(-6, 7), c + Vector2(-6, 0)]), col, w, true)
		"Defenses":
			for i in 3:
				draw_rect(Rect2(c + Vector2(-9 + i * 6, -4), Vector2(5, 10)), col, false, w)
		_:
			draw_circle(c, 6, col, false, w, true)
			draw_line(c + Vector2(-10, 0), c + Vector2(10, 0), col, w, true)
			draw_line(c + Vector2(0, -10), c + Vector2(0, 10), col, w, true)
