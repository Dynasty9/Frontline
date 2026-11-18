extends Node3D
## Controlled offline showroom using actual World, Structure and Decor builders.
## Stock medium preset and materials; no gameplay-rule edits. Fixed-step capture only.
var field: World
var camera: Camera3D
var output := ""
var groups := ["hq"]
var label := "AFTER"
var fps := 15
var sample := false
const SPOT := Vector3(45, 0, 60)
func _ready() -> void:
	TestRun.watch()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--groups="): groups = Array(arg.get_slice("=", 1).split(","))
		if arg.begins_with("--frames="): output = arg.get_slice("=", 1)
		if arg.begins_with("--label="): label = arg.get_slice("=", 1)
		if arg == "--sample": sample = true
	Online.record_battles = false
	seed(712)
	Settings.apply_preset("medium", false)
	field = World.new()
	field.settings = {"scenario": "showroom", "seed": 712, "mood": "day", "map_size": 1024, "players": {}, "ai_teams": []}
	add_child(field)
	await field.build()
	while field.cam == null or field.building: await get_tree().process_frame
	field.cam.focus_pos = SPOT
	field.focused = true
	field.cam.set_process(false)
	field.input.set_process(false)
	field.hud.visible = false
	if field.director: field.director.active = false
	camera = field.cam.cam
	camera.fov = 50
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var caption := Label.new()
	caption.position = Vector2(18, 16)
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(caption)
	for group: String in groups:
		var at := Vector3(SPOT.x, field.ground_y(SPOT), SPOT.z)
		var subject: Node3D
		field.next_eid = 12000
		var close_radius := 25.0
		var command_radius := 50.0
		var start := -0.45
		var finish := 0.60
		var focus := at + Vector3(0, 1.6, -1)
		var snapshot := {}
		if group == "square":
			var entries: Array = [["statue", at, 0.0, 0], ["stall", at + Vector3(-3.5, 0, -4.0), 0.0, 0], ["stall", at + Vector3(0, 0, -4.0), 0.0, 1], ["stall", at + Vector3(3.5, 0, -4.0), 0.0, 2]]
			var decor := Decor.new()
			field.add_child(decor)
			decor.build(field, entries)
			subject = decor
			close_radius = 16.0
			command_radius = 35.0
			snapshot = {"entries": entries, "statue_obstacle": Decor.BREAKABLE.statue, "stall_obstacle": Decor.BREAKABLE.stall}
		else:
			var s: Structure = field.spawn("structure", {"skind": "depot" if group == "hq" else "medic_tent", "team": 0, "owner": -1, "pos": at, "yaw": 0.0, "built": true})
			subject = s
			snapshot = {"parts": s.parts, "foot": s.foot, "radius": s.radius, "size": s.size, "indestructible": s.indestructible}
			if group == "hospital":
				close_radius = 12.0
				command_radius = 35.0
				start = -1.75
				finish = -0.8
				focus = at + Vector3(-0.4, 1.3, 0)
		var folder := output.path_join(group)
		DirAccess.make_dir_recursive_absolute(folder)
		FileAccess.open(folder.path_join("collision.json"), FileAccess.WRITE).store_string(JSON.stringify(snapshot, "  "))
		camera.global_position = focus + Vector3(sin(start), 0.95, -cos(start)).normalized() * command_radius
		camera.look_at(focus)
		field.cam.focus_pos = at
		field.structure_view.focus_at(at, camera)
		if subject is Structure: subject.set_view_active(true)
		print("ENV ART ready ", group, " focus=", field.cam.focus_pos)
		for warm in 20: await RenderingServer.frame_post_draw
		if subject is Structure: assert(subject.model != null and subject.view_active, "Capture subject must be resident and visible")
		var count := 2 if sample else fps * 5
		for frame in count:
			var close := frame > 0 if sample else frame >= fps
			if close:
				var u := 0.5 if sample else float(frame - fps) / float(fps * 4 - 1)
				var angle := lerpf(start, finish, u)
				camera.global_position = focus + Vector3(sin(angle), 0.44, -cos(angle)).normalized() * close_radius
				camera.look_at(focus)
			caption.text = "%s · %s · %s" % [label, {"hq":"HQ COMPOUND", "square":"MEMORIAL & MARKET", "hospital":"FIELD HOSPITAL"}[group], "CLOSE ORBIT" if close else "COMMAND VIEW"]
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(folder.path_join("frame-%04d.png" % frame))
		print("ENV ART ", group, " complete frames=", count, " drawn=", Engine.get_frames_drawn())
		if subject is Structure: field.despawn(subject)
		else: subject.queue_free()
		await get_tree().process_frame
	if Music._task >= 0:
		WorkerThreadPool.wait_for_task_completion(Music._task)
		Music._task = -1
	TestRun.quit(get_tree())
