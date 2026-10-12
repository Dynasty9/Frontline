class_name HudToasts
extends Control
## Fading notifications, newest on top.

var hud: Hud
var items: Array = []  # [kind, text, age, life]

func push(kind: String, text: String) -> void:
	for it in items:
		if it[1] == text:
			it[2] = 0.0
			return
	items.push_front([kind, text, 0.0, 9.0 if kind in ["alert", "intel"] else 6.0])
	if items.size() > 5:
		items.pop_back()

func tick(dt: float) -> void:
	for i in range(items.size() - 1, -1, -1):
		items[i][2] += dt
		if items[i][2] > items[i][3]:
			items.remove_at(i)
	queue_redraw()

func _draw() -> void:
	var y := 0.0
	for it in items:
		var age: float = it[2]
		var a := clampf(minf(age * 5.0, (float(it[3]) - age) * 1.2), 0.0, 1.0)
		var col: Color = Hud.MSG_COLORS.get(it[0], Color.WHITE)
		var txt: String = it[1]
		var lines := _wrap(txt, size.x - 34.0)
		var h := 12.0 + lines.size() * 17.0
		var slide := (1.0 - clampf(age * 5.0, 0.0, 1.0)) * 24.0
		var r := Rect2(slide, y, size.x, h)
		draw_style_box(UiKit.boxc(Color(0.05, 0.06, 0.055, 0.72 * a), 6, Color(1, 1, 1, 0.06 * a), 1, 0.0), r)
		draw_rect(Rect2(r.position + Vector2(0, 5), Vector2(3, h - 10)), Color(col.r, col.g, col.b, a))
		var ly := y + 19.0
		for ln in lines:
			UiKit.text(self, Vector2(slide + 14, ly), ln, 13, Color(col.r, col.g, col.b, a) if it[0] != "system" else Color(0.85, 0.85, 0.8, a))
			ly += 17.0
		y += h + 6.0

func _wrap(t: String, wmax: float) -> Array:
	return MapSymbols.wrap(t, 13, 400, wmax)
