class_name UiDeckIcons
extends RefCounted
## Semantic IDs shared by navigation, actions and the component workbench.
const IDS := ["attack", "defend", "hold", "back", "grenade", "smoke", "exit", "build", "defenses", "target", "units", "layers", "support"]


static func paint(canvas: CanvasItem, icon_id: String, c: Vector2, col: Color) -> void:
	var w := 1.6
	match icon_id:
		"attack":
			canvas.draw_line(c + Vector2(-7, 6), c + Vector2(7, -6), col, w, true)
			canvas.draw_polyline(PackedVector2Array([c + Vector2(-1, -6), c + Vector2(7, -6), c + Vector2(7, 2)]), col, w, true)
		"defend":
			canvas.draw_polyline(PackedVector2Array([c + Vector2(-7, -7), c + Vector2(7, -7), c + Vector2(6, 2), c + Vector2(0, 8), c + Vector2(-6, 2), c + Vector2(-7, -7)]), col, w, true)
		"hold":
			canvas.draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), col, false, w)
		"back":
			for x in [0, 7]:
				canvas.draw_polyline(PackedVector2Array([c + Vector2(x, -6), c + Vector2(x - 6, 0), c + Vector2(x, 6)]), col, w, true)
		"grenade":
			canvas.draw_circle(c + Vector2(0, 2), 5.0, col, false, w, true)
			canvas.draw_line(c + Vector2(-2, -4), c + Vector2(3, -7), col, w, true)
			canvas.draw_line(c + Vector2(3, -7), c + Vector2(7, -3), col, w, true)
		"smoke":
			for x in [-5, 0, 5]:
				canvas.draw_arc(c + Vector2(x, 2), 5, PI, TAU, 12, col, w, true)
			canvas.draw_line(c + Vector2(-10, 6), c + Vector2(10, 6), col, w, true)
		"exit":
			canvas.draw_polyline(PackedVector2Array([c + Vector2(-2, -7), c + Vector2(-8, -7), c + Vector2(-8, 7), c + Vector2(-2, 7)]), col, w, true)
			canvas.draw_line(c + Vector2(-3, 0), c + Vector2(9, 0), col, w, true)
			canvas.draw_polyline(PackedVector2Array([c + Vector2(4, -5), c + Vector2(9, 0), c + Vector2(4, 5)]), col, w, true)
		"build":
			canvas.draw_polyline(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(0, -7), c + Vector2(8, 0), c + Vector2(6, 0), c + Vector2(6, 7), c + Vector2(-6, 7), c + Vector2(-6, 0)]), col, w, true)
		"defenses":
			for i in 3:
				canvas.draw_rect(Rect2(c + Vector2(-9 + i * 6, -4), Vector2(5, 10)), col, false, w)
		"target":
			canvas.draw_arc(c, 7, 0, TAU, 24, col, 1.4, true)
			for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				canvas.draw_line(c + d * 5, c + d * 11, col, 1.4, true)
		"units":
			for x in [-8.0, 0.0, 8.0]:
				var p: Vector2 = c + Vector2(x, -2 if x == 0.0 else 1)
				canvas.draw_circle(p + Vector2(0, -4), 2.5, col, false, 1.4, true)
				canvas.draw_polyline(PackedVector2Array([p + Vector2(-4, 7), p + Vector2(-4, 3), p + Vector2(4, 3), p + Vector2(4, 7)]), col, 1.4, true)
		"layers":
			for row in 3:
				var y := c.y - 7.0 + row * 7.0
				canvas.draw_line(Vector2(c.x - 9, y), Vector2(c.x + 9, y), col, 1.4, true)
				var x := c.x + (-3.0 if row == 1 else 4.0)
				canvas.draw_rect(Rect2(x - 1.5, y - 3, 3, 6), col)
		"support":
			canvas.draw_line(c + Vector2(0, -4), c + Vector2(0, 9), col, 1.4, true)
			canvas.draw_circle(c + Vector2(0, -5), 2, col)
			canvas.draw_arc(c + Vector2(0, -5), 6, -PI * 0.8, -PI * 0.2, 14, col, 1.4, true)
			canvas.draw_arc(c + Vector2(0, -5), 10, -PI * 0.8, -PI * 0.2, 18, col, 1.4, true)
			canvas.draw_line(c + Vector2(-6, 9), c + Vector2(6, 9), col, 1.4, true)
		_:
			canvas.draw_circle(c, 6, col, false, w, true)
			canvas.draw_line(c + Vector2(-10, 0), c + Vector2(10, 0), col, w, true)
			canvas.draw_line(c + Vector2(0, -10), c + Vector2(0, 10), col, w, true)
