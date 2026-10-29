class_name UiDeckSurface
extends PanelContainer
## A theme-aware housing. Add one container child for arbitrary content.
@export var accented := false:
	set(value):
		accented = value
		queue_redraw()


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.bare(12))


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), accented)


static func paint(canvas: CanvasItem, r: Rect2, accent := false) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var cut := 8.0
	var p := PackedVector2Array([r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(0, cut), r.end - Vector2(cut, 0), Vector2(r.position.x, r.end.y), r.position + Vector2(0, cut)])
	var high := UiKit.fa(UiKit.INK.lightened(0.08), 0.97)
	var low := UiKit.fa(UiKit.INK, 0.98)
	canvas.draw_polygon(p, PackedColorArray([high, high, low, low, low, high]))
	var outline := p.duplicate()
	outline.append(p[0])
	canvas.draw_polyline(outline, UiKit.RULE2, 1.0, true)
	canvas.draw_line(r.position + Vector2(cut, 2), Vector2(r.end.x - 2, r.position.y + 2), UiKit.fa(UiKit.TEXT, 0.09))
	canvas.draw_rect(Rect2(r.position + Vector2(12, 0), Vector2(42, 2)), UiKit.ACCENT if accent else UiKit.RULE2)
