extends Node

class DotsMap extends HudMinimap:
	var elapsed := 0
	var reference := false
	func _draw_content(phase := -1) -> void:
		if phase == -1 or phase == 2:
			var started := Time.get_ticks_usec()
			if reference:
				_reference(clampf(size.x / 240.0, 0.85, 1.35))
			else:
				_draw_units(hud.world, clampf(size.x / 240.0, 0.85, 1.35))
			elapsed += Time.get_ticks_usec() - started
			# Vehicles and aircraft must still cover the infantry dots.
			_ink.draw_rect(Rect2(110, 110, 20, 20), Color(0.8, 0.7, 0.2))
	func _reference(sc: float) -> void:
		var r := 1.3 * sc
		for s: Soldier in hud.world.soldiers:
			if not s.visible or s.life == Soldier.Life.HIDDEN or s.life == Soldier.Life.DEAD:
				continue
			var color: Color
			var radius := r
			if s.selected:
				color = Color.WHITE
				radius *= 1.3
			elif s.team < 0:
				color = Color(0.9, 0.9, 0.85)
			else:
				color = Defs.TEAM_COLORS[s.team].lightened(0.4 if s.team == hud.world.local_team else 0.12)
			if s.life == Soldier.Life.DOWNED:
				color.a = 0.55
			var p := _pt(s.position)
			_ink.draw_rect(Rect2(p - Vector2(radius + 0.9, radius + 0.9), Vector2(radius * 2.0 + 1.8, radius * 2.0 + 1.8)), Color(0, 0, 0, 0.65))
			_ink.draw_rect(Rect2(p - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), color)

func compare(views: Array[SubViewport], stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var expected := views[0].get_texture().get_image()
	var actual := views[1].get_texture().get_image()
	var error := 0.0
	var visible_pixels := 0
	for y in 256:
		for x in 256:
			var a := actual.get_pixel(x, y)
			var b := expected.get_pixel(x, y)
			error += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)
			visible_pixels += int(b.r > 0.2)
	var pair := Image.create(512, 256, false, expected.get_format())
	pair.blit_rect(expected, Rect2i(0, 0, 256, 256), Vector2i.ZERO)
	pair.blit_rect(actual, Rect2i(0, 0, 256, 256), Vector2i(256, 0))
	pair.save_png("res://build/minimap-dots-%s.png" % stage)
	print("MINIMAP_DOTS pixel_difference=%.6f" % (error / (256 * 256 * 4)))
	assert(visible_pixels > 300)
	assert(error / (256 * 256 * 4) < 0.001, "Retained dots must preserve colors, opacity, order, clipping and fractional positions")

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_position(Vector2i(-20000, -20000))
	MapDims.configure(3072)
	var probe: RefCounted = ClassDB.instantiate("MinimapDots")
	var points := PackedVector3Array([Vector3(15, 27, 1.3)])
	var colors := PackedColorArray([Color(0.2, 0.4, 0.7, 0.55)])
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_2D
	batch.use_colors = true
	batch.instance_count = 4
	var encoded: PackedFloat32Array = probe.encode(points, colors, 4)
	assert(encoded.size() == 48 and encoded[3] == 15 and encoded[7] == 27)
	assert(is_equal_approx(encoded[0], 2.2))
	batch.buffer = encoded
	if DisplayServer.get_name() != "headless":
		assert(batch.get_instance_transform_2d(0).origin == Vector2(15, 27))
		assert(is_equal_approx(batch.get_instance_transform_2d(0).x.x, 2.2))
		# Compatibility quantizes instance colors; the rendered comparison checks the result.
		var readback := batch.get_instance_color(1)
		for channel in 4:
			assert(absf(readback[channel] - colors[0][channel]) <= 1.0 / 255.0)
	assert(probe.encode(points, PackedColorArray(), 4).is_empty())
	assert(probe.encode(PackedVector3Array([Vector3(0, 0, NAN)]), colors, 4).is_empty())
	assert(probe.encode(points, colors, 1).is_empty())
	assert(probe.encode(points, colors, 262145).is_empty())
	assert(probe.encode(PackedVector3Array(), PackedColorArray(), 0).is_empty())
	var world := World.new()
	world.local_team = 0
	var hud := Hud.new()
	hud.world = world
	for i in 500:
		var soldier := Soldier.new()
		soldier.eid = i + 1
		soldier.team = i % 3 - 1
		soldier.position = Vector3((i % 25) * 125.37 - 1550, 0, (i / 25) * 150.19 - 1510)
		soldier.selected = i % 7 == 0
		soldier.life = Soldier.Life.DOWNED if i % 11 == 0 else Soldier.Life.ALIVE
		world.soldiers.append(soldier)
	var views: Array[SubViewport] = []
	var maps: Array[DotsMap] = []
	for retained in [false, true]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(256, 256)
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		views.append(viewport)
		var map := DotsMap.new()
		map.reference = not retained
		map.hud = hud
		map.position = Vector2(8, 8)
		map.size = Vector2(240, 240)
		if retained:
			map.prepare_layers()
		viewport.add_child(map)
		maps.append(map)
	await get_tree().process_frame
	await get_tree().process_frame
	await compare(views, "initial")
	var first: RefCounted = maps[1]._dots
	for frame in 120:
		for s: Soldier in world.soldiers:
			s.position.x += 0.11
		maps[0].queue_redraw()
		maps[1]._layers[1].queue_redraw()
		await get_tree().process_frame
	assert(maps[1]._dots == first, "Movement must reuse the existing batch")
	for map in maps:
		print("MINIMAP_DOTS retained=%s total_ms=%.3f" % [not map._layers.is_empty(), map.elapsed / 1000.0])
	for i in 500:
		var s: Soldier = world.soldiers[i]
		s.selected = i % 5 == 0
		s.visible = i % 3 != 0
		s.life = [Soldier.Life.DEAD, Soldier.Life.HIDDEN, Soldier.Life.ALIVE, Soldier.Life.DOWNED][i % 4]
	for map in maps:
		map._xf = Transform2D(0.2, Vector2(15, -20))
		map.size = Vector2(210, 210)
		map.queue_redraw()
		for layer in map._layers:
			layer.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await compare(views, "changed")
	for s: Soldier in world.soldiers:
		s.free()
	world.soldiers.clear()
	maps[0].queue_redraw()
	maps[1]._layers[1].queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await compare(views, "empty")
	assert(maps[1]._dot_batch.visible_instance_count == 0, "Despawn must empty the batch")
	views[0].free()
	views[1].free()
	hud.free()
	world.free()
	MapDims.configure(1024)
	print("MINIMAP_DOTS passed")
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()
