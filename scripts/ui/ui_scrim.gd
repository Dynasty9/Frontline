class_name UiScrim
extends Control
## An edge scrim (docs/UI.md, Scrim): the ink fading in from an edge of the
## screen, so the HUD and the menus can sit straight on the scene without a
## box. It reaches `reach` pixels in from its edge and runs `span` pixels
## along it (0: the whole edge), fading out at the far end of the span too.

var edge := "top"  # top, bottom, left or right
var reach := 120.0
var span := 0.0
var strength := 1.0

static var _mask: ImageTexture


## A scrim on an edge, as a child of a full-screen parent.
static func make(on_edge: String, reach_px: float, span_px := 0.0, k := 1.0) -> UiScrim:
	var s := UiScrim.new()
	s.edge = on_edge
	s.reach = reach_px
	s.span = span_px
	s.strength = k
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## One alpha mask for every scrim: full at the edge (x = 0) easing to nothing
## across, and along the edge full until two thirds of the way, then fading.
static func _get_mask() -> ImageTexture:
	if _mask == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			var v := float(y) / 63.0
			var along := 1.0 - smoothstep(0.62, 1.0, v)
			for x in 64:
				var u := float(x) / 63.0
				var across := pow(1.0 - u, 1.7)
				img.set_pixel(x, y, Color(1, 1, 1, across * along))
		_mask = ImageTexture.create_from_image(img)
	return _mask


func _draw() -> void:
	var col := Color(UiKit.SCRIM.r, UiKit.SCRIM.g, UiKit.SCRIM.b, UiKit.SCRIM.a * strength)
	var m := _get_mask()
	var w := size.x
	var h := size.y
	var sp_v := span if span > 0.0 else h * 1.6  # (a whole edge: the fade along it falls past the end)
	var sp_h := span if span > 0.0 else w * 1.6
	# the mask's x runs across from the edge, its y along it: turn it to the edge
	match edge:
		"left":
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_texture_rect(m, Rect2(0, 0, reach, sp_v), false, col)
		"right":
			draw_set_transform(Vector2(w, 0), 0.0, Vector2(-1, 1))
			draw_texture_rect(m, Rect2(0, 0, reach, sp_v), false, col)
		"top":
			draw_set_transform(Vector2.ZERO, -PI * 0.5, Vector2(-1, 1))
			draw_texture_rect(m, Rect2(0, 0, reach, sp_h), false, col)
		"bottom":
			draw_set_transform(Vector2(0, h), -PI * 0.5, Vector2.ONE)
			draw_texture_rect(m, Rect2(0, 0, reach, sp_h), false, col)
	draw_set_transform(Vector2.ZERO)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
