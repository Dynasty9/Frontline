class_name UiMapGridFrame
extends RefCounted
## Coordinate rails use the scenario's radio grid, never invented geolocation.
static func paint(canvas: CanvasItem, map: Rect2, divisions: int, rotating := false) -> void:
	canvas.draw_rect(map.grow(1), UiKit.RULE2, false, 1)
	var tick := 4.0
	for i in range(divisions + 1):
		var f := float(i) / divisions
		var x := map.position.x + f * map.size.x
		var y := map.position.y + f * map.size.y
		for edge in [map.position.y, map.end.y]:
			canvas.draw_line(Vector2(x, edge - tick), Vector2(x, edge + tick), UiKit.RULE2)
		for edge in [map.position.x, map.end.x]:
			canvas.draw_line(Vector2(edge - tick, y), Vector2(edge + tick, y), UiKit.RULE2)
	if not rotating:
		for i in divisions:
			var f := (i + 0.5) / divisions
			var x := map.position.x + f * map.size.x
			var y := map.position.y + f * map.size.y
			var letter := String.chr(65 + i)
			var number := "%02d" % (i + 1)
			_center(canvas, Vector2(x, map.position.y - 10), letter)
			_center(canvas, Vector2(x, map.end.y + 11), letter)
			_center(canvas, Vector2(map.position.x - 12, y), number)
			_center(canvas, Vector2(map.end.x + 12, y), number)
	# Four registration marks anchor the map, rather than a heavy enclosing bevel.
	for corner in [map.position, Vector2(map.end.x, map.position.y), map.end, Vector2(map.position.x, map.end.y)]:
		var direction := Vector2(1 if corner.x == map.position.x else -1, 1 if corner.y == map.position.y else -1)
		canvas.draw_line(corner, corner + Vector2(direction.x * 8, 0), UiKit.TEXT, 1.5)
		canvas.draw_line(corner, corner + Vector2(0, direction.y * 8), UiKit.TEXT, 1.5)


static func _center(canvas: CanvasItem, at: Vector2, text: String) -> void:
	UiKit.mono_at(canvas, at + Vector2(-UiKit.mono_w(text, 9) * 0.5, 3), text, 9, UiKit.DIM, false)
