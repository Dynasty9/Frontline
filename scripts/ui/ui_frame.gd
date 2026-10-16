class_name UiFrame
extends StyleBox
## The panels' frame, in the living map's language: a dark glass fill, a
## hairline edge, and short brackets on the corners in the theme's accent, like
## the crosses on the map's grid, with a faint glow in the accent round it.
## It takes the theme's colours as it draws, so a new theme reaches every
## framed panel at once.

var bg := Color(-1, 0, 0)  # the fill (r < 0: the theme's panel colour)
var opacity := -1.0  # with the theme's colour: this opaque instead of the theme's own
var glow := 1.0
var arm := 12.0  # how far each bracket runs along its edges
var _flat := StyleBoxFlat.new()
var _rev := -1


func _sync() -> void:
	if _rev == UiKit.theme_rev:
		return
	_rev = UiKit.theme_rev
	var a := UiKit.ACCENT
	var fill := UiKit.PANEL if bg.r < 0.0 else bg
	if bg.r < 0.0 and opacity >= 0.0:
		fill.a = opacity
	_flat.bg_color = fill
	_flat.border_color = UiKit.LINE
	_flat.set_border_width_all(1)
	_flat.set_corner_radius_all(3)
	_flat.anti_aliasing = true
	_flat.shadow_color = Color(a.r * 0.35, a.g * 0.35, a.b * 0.35, 0.22 * glow) if glow > 0.0 else Color(0, 0, 0, 0)
	_flat.shadow_size = int(14.0 * glow)
	_flat.shadow_offset = Vector2(0, 2)


func _draw(ci: RID, r: Rect2) -> void:
	_sync()
	_flat.draw(ci, r)
	var a := UiKit.ACCENT
	var col := Color(a.r, a.g, a.b, 0.8)
	var k := minf(arm, minf(r.size.x, r.size.y) * 0.3)
	var w := 2.0
	var p0 := r.position
	var p1 := r.end
	for c in [[p0, 1.0, 1.0], [Vector2(p1.x, p0.y), -1.0, 1.0], [Vector2(p0.x, p1.y), 1.0, -1.0], [p1, -1.0, -1.0]]:
		var o: Vector2 = c[0]
		var sx: float = c[1]
		var sy: float = c[2]
		RenderingServer.canvas_item_add_rect(ci, Rect2(o.x if sx > 0.0 else o.x - k, o.y if sy > 0.0 else o.y - w, k, w), col)
		RenderingServer.canvas_item_add_rect(ci, Rect2(o.x if sx > 0.0 else o.x - w, o.y if sy > 0.0 else o.y - k, w, k), col)


func _get_draw_rect(r: Rect2) -> Rect2:
	return r.grow(14.0 * glow + 2.0)
