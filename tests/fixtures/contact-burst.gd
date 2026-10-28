extends Node

class Burst extends HudOverlay:
	var reference := false
	var elapsed := 0
	func _draw() -> void:
		var start := Time.get_ticks_usec()
		for i in 200:
			var c := Vector2(20 + i % 20 * 28, 20 + i / 20 * 28)
			if reference:
				var t := Time.get_ticks_msec() / 1000.0
				var r := 6.5 + sin(t * 11.0) * 1.3
				var pts := PackedVector2Array()
				for j in 16:
					var ang := TAU * j / 16.0 + t
					pts.append(c + Vector2(cos(ang), sin(ang)) * (r if j % 2 == 0 else r * 0.45))
				MapSymbols.poly(self, pts, Color(1.0, 0.55, 0.2, 0.95))
			else:
				_contact_burst(c, 1.0)
		_contact_burst(Vector2.INF, 1.0)
		_contact_burst(Vector2(30000, 0), 1.0)
		# This must stay in its own coordinates after the final transformed star.
		draw_rect(Rect2(10, 310, 550, 4), Color.WHITE)
		elapsed += Time.get_ticks_usec() - start

func _ready() -> void:
	var burst := Burst.new()
	add_child(burst)
	for reference in [true, false]:
		burst.reference = reference
		burst.elapsed = 0
		for i in 60:
			burst.queue_redraw()
			await get_tree().process_frame
		print("CONTACT_BURST reference=%s ms=%.3f" % [reference, burst.elapsed / 1000.0])
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://build/contact-burst-%s.png" % reference)
	var shape = HudOverlay._contact_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(shape.size() == 16)
	assert(HudOverlay._contact_mesh.surface_get_array_index_len(0) == 42)
	for step in 100:
		var t := step * 0.373
		var r := 6.5 + sin(t * 11.0) * 1.3
		var c := Vector2(step * 1.3, step * 0.7)
		var transform := Transform2D(t, Vector2(r, r), 0.0, c)
		for j in 16:
			var angle := TAU * j / 16.0 + t
			var expected := c + Vector2(cos(angle), sin(angle)) * (r if j % 2 == 0 else r * 0.45)
			var point := Vector2(shape[j].x, shape[j].y)
			assert(expected.distance_to(transform * point) < 0.00004)
	print("CONTACT_BURST passed")
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()
