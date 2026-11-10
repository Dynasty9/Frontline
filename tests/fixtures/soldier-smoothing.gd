extends Node

class ViewSoldier extends Soldier:
	var detailed := false
	func _view_process(dt: float, blend := -1.0, _motion_done := false) -> void:
		net_smooth(dt, blend)
		visible = seen_by_local()
		view_lod = not detailed
	func on_despawn() -> void:
		pass

func viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(192, 192)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var camera := Camera3D.new()
	vp.add_child(camera)
	camera.position = Vector3(1006, 28, -993)
	camera.look_at(Vector3(1002, 21, -1000))
	var light := DirectionalLight3D.new()
	vp.add_child(light)
	light.rotation_degrees = Vector3(-40, -30, 0)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.5
	vp.add_child(environment)
	return vp

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_position(Vector2i(-20000, -20000))
	var world := World.new()
	world.view_team = 0
	world.simulation_client = SimulationClient.new()
	var view := SoldierViewBatch.new()
	view.world = world
	world.soldier_view = view
	var gpu := viewport()
	gpu.add_child(view)
	view.set_process(false)
	view.prepare("rifleman", 1)
	view._warmup.clear()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 1.6, 2.3)
	var arrays := box.surface_get_arrays(0)
	var colors := PackedColorArray()
	colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	colors.fill(Color(0.4, 0.6, 0.2))
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	view.poses[0] = mesh
	var s := ViewSoldier.new()
	s.world = world
	s.eid = 1
	s.utype = "rifleman"
	s.team = 1
	s.vis_mask = 1
	s.view_lod = true
	s.net_init = true
	s.position = Vector3(1000, 20, -1000)
	s.net_pos = s.position + Vector3(4, 3, -2)
	s.rotation.y = 3.0
	s.net_yaw = -2.4
	world.add_child(s)
	world._register(s)
	view._process(0.0)
	assert(view._active.size() == 1)
	var start := s.transform
	var initial_group: SoldierViewBatch.DrawGroup = view._active[0]
	for blend in [0.0, 0.5, 1.0]:
		var transform := Transform3D(Basis(Vector3.UP, lerp_angle(s.rotation.y, s.net_yaw, blend)), s.position.lerp(s.net_pos, blend))
		check_bounds(initial_group, transform)
	var cpu := viewport()
	var reference := MeshInstance3D.new()
	reference.mesh = mesh
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; void fragment() { ALBEDO = COLOR.rgb; ROUGHNESS = 0.9; }"
	material.shader = shader
	reference.material_override = material
	cpu.add_child(reference)
	var elapsed := 0.0
	for dt in [0.0, 0.016, 0.05, 0.1]:
		elapsed += dt
		view._process(dt)
		assert(is_equal_approx(view._age, elapsed), "Frames between updates must not rebuild the batch")
		var blend := 1.0 - exp(-14.0 * elapsed)
		var expected := start.origin.lerp(s.net_pos, blend)
		assert(s.position.distance_to(expected) < 0.001)
		reference.position = expected
		reference.rotation.y = lerp_angle(3.0, -2.4, blend)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var actual := gpu.get_texture().get_image()
			var wanted := cpu.get_texture().get_image()
			var difference := 0.0
			var lit := 0
			for y in 192:
				for x in 192:
					var a := actual.get_pixel(x, y)
					var b := wanted.get_pixel(x, y)
					difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
					lit += int(b.r > 0.05)
			assert(lit > 100, "The comparison must contain a visible model")
			print("SMOOTHING dt=%.3f difference=%.6f" % [dt, difference / (192 * 192 * 3)])
			if dt == 0.1 or difference / (192 * 192 * 3) >= 0.005:
				var pair := Image.create(384, 192, false, wanted.get_format())
				pair.blit_rect(wanted, Rect2i(0, 0, 192, 192), Vector2i.ZERO)
				pair.blit_rect(actual, Rect2i(0, 0, 192, 192), Vector2i(192, 0))
				pair.save_png("res://build/soldier-smoothing.png")
			assert(difference / (192 * 192 * 3) < 0.005, "GPU translation, yaw and lighting must match CPU smoothing")
	# A packet must invalidate even when only visibility changes.
	view.motion_changed()
	var due := view._motion_frame
	view.motion_changed()
	assert(view._motion_frame == due, "Continuous packets must not postpone an already queued refresh")
	view._process(0.016)
	assert(view._age > 0.0, "Routine motion uploads should leave packet decoding on its own frame")
	await get_tree().process_frame
	await get_tree().process_frame
	world.hud = Hud.new()
	world.hud.overlay = HudOverlay.new()
	world.hud.overview_frame = Engine.get_process_frames()
	view._process(0.016)
	assert(view._age > 0.0 and view._motion_frame >= 0, "Routine batch uploads yield to HUD drawing or preparation")
	await get_tree().process_frame
	world.hud.overview_frame = Engine.get_process_frames()
	view._process(0.016)
	assert(view._age > 0.0 and view._motion_frame >= 0, "The roster can use the frame after summary preparation")
	await get_tree().process_frame
	world.hud.overview_frame = Engine.get_process_frames()
	view._process(0.016)
	assert(view._age == 0.0 and view._motion_frame < 0, "Continuous HUD work cannot defer routine motion more than two frames")
	var packet := StreamPeerBuffer.new()
	packet.put_float(0.0)
	packet.put_u32(s.eid)
	packet.put_u8(0)
	world._rpc_snap(packet.data_array)
	view._process(0.016)
	assert(initial_group.mm.visible_instance_count == 0 and not s.visible)
	s.vis_mask = 1
	view._process(0.016)
	assert(view._active.size() == 1 and s.visible, "Fog changes must appear in the same frame")
	s.net_pos += Vector3(20, 100, 0)
	view.motion_changed()
	view._process(0.016)
	assert(s.position == s.net_pos and view._age == 0.0, "Teleports retain the immediate CPU and GPU snap")
	var group: SoldierViewBatch.DrawGroup = view._active[0]
	check_bounds(group, s.transform)
	s.detailed = true
	view._process(0.016)
	assert(group.mm.visible_instance_count == 0)
	s.detailed = false
	view._process(0.016)
	world.despawn(s)
	view._process(0.016)
	assert(view._active.is_empty(), "Despawn must remove the cached model immediately")
	await get_tree().process_frame
	s.free()
	world.hud.overlay.free()
	world.hud.free()
	world.hud = null
	world.simulation_client.free()
	view.free()
	world.free()
	print("SOLDIER_SMOOTHING passed")
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()


func check_bounds(group: SoldierViewBatch.DrawGroup, transform: Transform3D) -> void:
	for vertex: Vector3 in group.mm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert(group.mm.custom_aabb.grow(0.001).has_point(transform * vertex - group.origin), "Swept and teleported model vertices must stay inside their bounds")
