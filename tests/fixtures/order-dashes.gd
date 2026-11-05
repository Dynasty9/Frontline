extends Node

func crosses(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false

func _ready() -> void:
	var rect := Rect2(0, 0, 100, 100)
	assert(HudOverlay._screen_span(Vector2(-50, 50), Vector2(150, 50), rect) == Vector2(0.25, 0.75))
	assert(HudOverlay._screen_span(Vector2(150, 50), Vector2(-50, 50), rect) == Vector2(0.25, 0.75))
	var outside := HudOverlay._screen_span(Vector2(-50, -10), Vector2(150, -10), rect)
	assert(outside.x > outside.y)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 100, 100)
	camera.look_at(Vector3.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	rect = get_viewport().get_visible_rect().grow(20)
	var original_count := 0
	var clipped_count := 0
	for projection in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
		camera.projection = projection
		camera.size = 150
		for sample in 80:
			var a := Vector3(rng.randf_range(-1500, 1500), 0.3, rng.randf_range(-300, 20))
			var b := Vector3(rng.randf_range(-1500, 1500), 0.3, rng.randf_range(-300, 20))
			var count := maxi(2, int(a.distance_to(b) / 2.5))
			var clipped := HudOverlay._ground_dashes(camera, a, b, count, rect)
			original_count += ceili(count * 0.5) * 2
			clipped_count += clipped.size()
			var match_at := 0
			for i in range(0, count, 2):
				var p0 := camera.unproject_position(a.lerp(b, float(i) / count))
				var p1 := camera.unproject_position(a.lerp(b, float(i + 1) / count))
				var retained := match_at < clipped.size() and clipped[match_at].distance_to(p0) < 0.01
				if retained:
					assert(clipped[match_at + 1].distance_to(p1) < 0.01, "Clipping must preserve dash length and phase")
					match_at += 2
				assert(retained or not crosses(p0, p1, rect), "A visible dash must never be clipped")
			assert(match_at == clipped.size(), "Clipped dashes remain in the original order")
	assert(clipped_count < original_count / 3, "Long offscreen orders must avoid most projections")
	print("ORDER_DASHES passed points=%d/%d" % [clipped_count, original_count])
	get_tree().quit()
