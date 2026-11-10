extends Node
class Item extends Structure:
	func set_view_active(value: bool) -> void:
		view_active = value
func _ready() -> void:
	var results := []
	var scripts := [StructureView]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline-view="):
			scripts.push_front(load(arg.trim_prefix("--baseline-view=")))
	for script in scripts:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		add_child(viewport)
		var camera := Camera3D.new()
		camera.far = 1000.0
		camera.fov = 40.0
		viewport.add_child(camera)
		var world := World.new()
		var view = script.new()
		view.world = world
		var items := []
		for x in range(-600, 601, 8):
			for z in range(-600, 601, 8):
				var st := Item.new()
				st.eid = items.size() + 1
				st.position = Vector3(x, 0, z)
				st.view_active = false
				view.add(st)
				items.append(st)
		camera.position = Vector3(-240, 100, 100)
		camera.look_at(Vector3(-240, 0, 0))
		view.focus_at(Vector3(-240, 0, 0), camera)
		while view.warming():
			view._process(1.0 / 60.0)
		var missing := 0
		var visible := 0
		var peak := 0
		for frame in 240:
			var x := -240.0 + (frame + 1) * 2.0
			camera.position.x = x
			view.focus_at(Vector3(x, 0, 0), camera)
			view._process(1.0 / 60.0)
			var frame_missing := 0
			for st in items:
				if camera.is_position_in_frustum(st.position + Vector3.UP * 8):
					visible += 1
					if not st.view_active:
						frame_missing += 1
			missing += frame_missing
			peak = maxi(peak, frame_missing)
		results.append({"missing_object_frames": missing, "visible_object_frames": visible, "peak_missing": peak})
		for st in items:
			st.free()
		view.free()
		world.free()
		viewport.free()
	print("PAN_CHECK ", JSON.stringify(results))
	get_tree().quit()
