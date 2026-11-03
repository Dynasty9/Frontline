extends Node

class Strength extends Control:
	var reference := false
	var pips: Array = []
	var mesh: ArrayMesh
	var elapsed := 0

	func _draw() -> void:
		var started := Time.get_ticks_usec()
		for row in 20:
			var alpha := float(row + 1) / 20.0
			var origin := Vector2(10.25 + row * 0.17, 8.25 + row * 10.37)
			if reference:
				var x := origin.x
				for color: Color in pips:
					draw_rect(Rect2(x - 0.5, origin.y - 0.5, 5, 4), Color(0, 0, 0, 0.6 * alpha))
					draw_rect(Rect2(x, origin.y, 4, 3), Color(color.r, color.g, color.b, alpha))
					x += 5.0
			else:
				draw_mesh(mesh, null, Transform2D(0.0, origin), Color(1, 1, 1, alpha))
		elapsed += Time.get_ticks_usec() - started

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_position(Vector2i(-20000, -20000))
	var views: Array[SubViewport] = []
	var controls: Array[Strength] = []
	for reference in [true, false]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(256, 224)
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		views.append(viewport)
		var control := Strength.new()
		control.reference = reference
		for i in 32:
			control.pips.append([Color(0.92, 0.95, 0.9), Color(1, 0.32, 0.26), Color(0.32, 0.32, 0.3)][i % 3])
		control.mesh = HudOverlay._strength_mesh(control.pips)
		var arrays := control.mesh.surface_get_arrays(0)
		assert((arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array).size() == control.pips.size() * 8)
		assert((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() == control.pips.size() * 12)
		viewport.add_child(control)
		controls.append(control)
	for frame in 120:
		for control in controls:
			control.queue_redraw()
		await get_tree().process_frame
	for control in controls:
		print("SQUAD_STRENGTH reference=%s total_ms=%.3f" % [control.reference, control.elapsed / 1000.0])
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var reference := views[0].get_texture().get_image()
		var actual := views[1].get_texture().get_image()
		var difference := 0.0
		var visible_pixels := 0
		for y in 224:
			for x in 256:
				var a := actual.get_pixel(x, y)
				var b := reference.get_pixel(x, y)
				difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)
				visible_pixels += int(b.a > 0.1)
		var pair := Image.create(512, 224, false, reference.get_format())
		pair.blit_rect(reference, Rect2i(0, 0, 256, 224), Vector2i.ZERO)
		pair.blit_rect(actual, Rect2i(0, 0, 256, 224), Vector2i(256, 0))
		pair.save_png("res://build/squad-strength.png")
		print("SQUAD_STRENGTH pixel_difference=%.6f" % (difference / (256 * 224 * 4)))
		assert(visible_pixels > 2000)
		assert(difference / (256 * 224 * 4) < 0.002, "Strength colors, borders, opacity and subpixel placement must match")
	assert(HudOverlay._strength_mesh([]).get_surface_count() == 0)
	print("SQUAD_STRENGTH passed")
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()
