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
		var world := World.new()
		var rig := RtsCamera.new()
		rig.world = world
		world.cam = rig
		viewport.add_child(rig)
		rig.set_process(false)
		rig.edge_pan = false
		rig.dist = sqrt(20000.0)
		rig.target_dist = rig.dist
		rig.pitch_deg = -45.0
		var camera := rig.cam
		camera.far = 1000.0
		camera.fov = 40.0
		var hud := Hud.new()
		hud.world = world
		var minimap := HudMinimap.new()
		minimap.hud = hud
		minimap.size = Vector2(240, 240)
		minimap._update_xf()
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
		rig.focus(Vector3(-240, 0, 0))
		view.focus_at(Vector3(-240, 0, 0), camera)
		while view.warming():
			view._process(1.0 / 60.0)
		# Compare the old immediate click from exactly the same warmed starting view.
		rig.focus(Vector3(240, 0, 0))
		var instant_missing := 0
		for st in items:
			if camera.is_position_in_frustum(st.position + Vector3.UP * 8) and not st.view_active:
				instant_missing += 1
		rig.focus(Vector3(-240, 0, 0))
		minimap._look(minimap._pt(Vector3(240, 0, 0)))
		assert(rig.focus_pos == Vector3(-240, 0, 0), "Minimap must not teleport")
		var missing := 0
		var visible := 0
		var peak := 0
		for frame in 400:
			var before := rig.focus_pos
			rig._last_ms = Time.get_ticks_msec() - 16
			rig._view_process(0.016)
			assert(rig.focus_pos.distance_to(before) <= 2.4, "Minimap glide must respect the speed cap")
			view.focus_at(rig.focus_pos, camera)
			view._process(1.0 / 60.0)
			var frame_missing := 0
			for st in items:
				if camera.is_position_in_frustum(st.position + Vector3.UP * 8):
					visible += 1
					if not st.view_active:
						frame_missing += 1
			missing += frame_missing
			peak = maxi(peak, frame_missing)
			if not rig._gliding:
				break
		results.append({"instant_click_missing": instant_missing, "missing_object_frames": missing, "visible_object_frames": visible, "peak_missing": peak})
		assert(not rig._gliding and rig.focus_pos.distance_to(Vector3(240, 0, 0)) < 0.1, "Minimap pan must arrive")
		if script == StructureView:
			assert(missing == 0, "Scenery must be ready before entering view during a minimap pan")
		minimap.free()
		hud.free()
		for st in items:
			st.free()
		view.free()
		world.free()
		viewport.free()
	print("PAN_CHECK ", JSON.stringify(results))
	get_tree().quit()
