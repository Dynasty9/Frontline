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
	# Match the menus: flat ink, open edges and a single quiet rule.
	# Alpha lets terrain remain perceptible without competing with small type.
	canvas.draw_rect(r, UiKit.fa(UiKit.INK, 0.92))
	canvas.draw_line(r.position, Vector2(r.end.x, r.position.y), UiKit.fa(UiKit.TEXT, 0.16))
	if accent:
		canvas.draw_line(r.position, r.position + Vector2(28, 0), UiKit.fa(UiKit.ACCENT, 0.65))
