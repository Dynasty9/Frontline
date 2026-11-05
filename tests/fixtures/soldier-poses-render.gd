extends Node

class AtlasView extends SoldierViewBatch:
	var originals := {}
	func _make_atlas(base: int) -> void:
		for frame in 15:
			originals[base + frame] = poses[base + frame]
		var early := _group_for(base, Vector2i.ZERO)
		super._make_atlas(base)
		assert(early.mm.mesh == poses[base] and early.node.material_override == _atlases[base])

func viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.mesh_lod_threshold = 1
	add_child(vp)
	var camera := Camera3D.new()
	vp.add_child(camera)
	camera.fov = 45
	camera.position = Vector3(1003.4, 23.4, -996.8)
	camera.look_at(Vector3(1000.7, 21.55, -1000.3))
	var light := DirectionalLight3D.new()
	vp.add_child(light)
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 2.0
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08, 0.09, 0.1)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 2.0
	vp.add_child(environment)
	return vp

func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	var world := World.new()
	var view := AtlasView.new()
	view.world = world
	var gpu := viewport()
	gpu.add_child(view)
	view.set_process(false)
	view.prepare("rifleman", 0)
	while not view._warmup.is_empty():
		var pose: Array = view._warmup.pop_front()
		view._make_pose(pose[0], pose[1], pose[2], pose[3], pose[4])
		await get_tree().process_frame
	var group := view._group_for(0, Vector2i(15, -16))
	group.mm.custom_aabb = AABB(Vector3(-11, -4, -11), Vector3(86, 40, 86))
	var start := Transform3D(Basis(Vector3.UP, 0.7), Vector3(1000, 20, -1000) - group.origin)
	group.mm.set_instance_transform(0, start)
	group.mm.set_instance_custom_data(0, Color(2, 1, -1, 0.5))
	group.mm.visible_instance_count = 1
	var cpu := viewport()
	var reference := MultiMeshInstance3D.new()
	reference.multimesh = MultiMesh.new()
	reference.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	reference.multimesh.custom_aabb = group.mm.custom_aabb
	reference.multimesh.instance_count = 1
	var blend := 1.0 - exp(-14.0 * 0.03)
	reference.position = group.origin
	reference.multimesh.set_instance_transform(0, Transform3D(Basis(Vector3.UP, 0.7 + 0.5 * blend), start.origin + Vector3(2, 1, -1) * blend))
	reference.lod_bias = 0.25
	cpu.add_child(reference)
	var pair := Image.create(512 * 5, 256 * 3, false, Image.FORMAT_RGB8)
	for posture in 3:
		for frame in 5:
			var index := posture * 5 + frame
			reference.multimesh.mesh = view.originals[index]
			world.time = float(frame - 1) / 8.0 if frame > 0 else 0.0
			view._set_animation(0.03)
			group.mm.set_instance_color(0, Color(1, 1, 1, float(posture * 8 + (1 if frame > 0 else 0)) / 255.0))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var wanted := cpu.get_texture().get_image()
			var actual := gpu.get_texture().get_image()
			wanted.convert(Image.FORMAT_RGB8)
			actual.convert(Image.FORMAT_RGB8)
			var a := wanted.get_data()
			var b := actual.get_data()
			var changed := 0
			var error := 0
			var lit := 0
			for i in a.size():
				changed += int(a[i] != b[i])
				error += absi(int(a[i]) - int(b[i]))
				lit += int(absi(int(a[i]) - int(a[i % 3])) > 8)
			assert(lit > 100, "The comparison must contain visible geometry")
			pair.blit_rect(wanted, Rect2i(0, 0, 256, 256), Vector2i(frame * 512, posture * 256))
			pair.blit_rect(actual, Rect2i(0, 0, 256, 256), Vector2i(frame * 512 + 256, posture * 256))
			print("SOLDIER_POSE_RENDER pose=", index, " changed=", changed, " average_byte_error=", float(error) / a.size())
			assert(float(error) / a.size() < 1.275, "Animated poses must retain CPU geometry, yaw, translation and lighting")
	pair.save_png("res://build/soldier-poses-" + RenderingServer.get_current_rendering_method() + ".png")
	view.free()
	world.free()
	Sfx._ensure()
	while Music._task >= 0:
		await get_tree().process_frame
	get_tree().quit()
