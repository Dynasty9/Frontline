class_name UiFrame
extends StyleBox
## The panels' frame in Signal (docs/UI.md): flat ink and four corner ticks
## standing just off its corners. No border, no glow, no rounded corners: the
## ticks say where the region is, the ink keeps it legible. It takes the
## theme's colours as it draws, so a new theme reaches every framed panel at once.

var bg := Color(-1, 0, 0)  # the fill (r < 0: the theme's panel ink)
var opacity := -1.0  # with the theme's ink: this opaque instead of the panel's own
var glow := 0.0  # > 0: the ticks in the accent (a selected or primary region)
var arm := UiKit.TICK_ARM  # how far each tick runs along its edges
var ticks := true
var _fill := Color()
var _tick := Color()
var _rev := -1


func _sync() -> void:
	if _rev == UiKit.theme_rev:
		return
	_rev = UiKit.theme_rev
	_fill = UiKit.PANEL if bg.r < 0.0 else bg
	if bg.r < 0.0 and opacity >= 0.0:
		_fill.a = opacity
	_tick = UiKit.ACCENT if glow > 0.0 else UiKit.RULE2


func _draw(ci: RID, r: Rect2) -> void:
	_sync()
	if _fill.a > 0.0:
		RenderingServer.canvas_item_add_rect(ci, r, _fill)
	if not ticks:
		return
	var a := minf(arm, minf(r.size.x, r.size.y) * 0.3)
	var g := r.grow(UiKit.TICK_GAP * 0.5)
	var p0 := g.position
	var p1 := g.end
	for c in [[p0, 1.0, 1.0], [Vector2(p1.x, p0.y), -1.0, 1.0], [Vector2(p0.x, p1.y), 1.0, -1.0], [p1, -1.0, -1.0]]:
		var o: Vector2 = c[0]
		var sx: float = c[1]
		var sy: float = c[2]
		RenderingServer.canvas_item_add_rect(ci, Rect2(o.x if sx > 0.0 else o.x - a, o.y if sy > 0.0 else o.y - 1.0, a, 1.0), _tick)
		RenderingServer.canvas_item_add_rect(ci, Rect2(o.x if sx > 0.0 else o.x - 1.0, o.y if sy > 0.0 else o.y - a, 1.0, a), _tick)


func _get_draw_rect(r: Rect2) -> Rect2:
	return r.grow(UiKit.TICK_GAP)
