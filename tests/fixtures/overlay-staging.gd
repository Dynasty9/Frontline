extends Node

class HudStub extends Hud:
	var roster_frames := []
	func _refresh_roster(due: bool, busy: bool) -> void:
		var requested := due or _roster_pending
		super._refresh_roster(due, busy)
		if requested and not _roster_pending:
			roster_frames.append(Engine.get_process_frames())
	func _ready() -> void:
		pass
	func _process(_dt: float) -> void:
		pass

class Overlay extends HudOverlay:
	var overlay_frames := []
	var group_frames := []
	func refresh_for_view(dt: float, camera: Camera3D, defer_start := false) -> bool:
		var changed := super.refresh_for_view(dt, camera, defer_start)
		if changed:
			overlay_frames.append(Engine.get_process_frames())
		return changed
	func _build_groups(inp, rebuild := true) -> void:
		var previous := _groups_at
		super._build_groups(inp, rebuild)
		if previous != _groups_at:
			group_frames.append(Engine.get_process_frames())
	var phases := []
	var strength := 1.0
	func _draw_content(phase: int) -> void:
		phases.append(phase)
		_ink.draw_rect(Rect2(10 + phase * 40, 10, 30, 30), Color(strength, 0, 0))

func _ready() -> void:
	var hud := HudStub.new()
	add_child(hud)
	hud.root = Control.new()
	hud.add_child(hud.root)
	var camera := Camera3D.new()
	add_child(camera)
	var raster := SubViewport.new()
	raster.disable_3d = true
	raster.transparent_bg = true
	raster.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hud.add_child(raster)
	var overlay := Overlay.new()
	overlay.hud = hud
	overlay.raster = raster
	raster.add_child(overlay)
	overlay.prepare_layers()
	overlay.refresh_for_view(0.0, camera)
	assert(raster.render_target_update_mode == SubViewport.UPDATE_ONCE)
	await settled()
	assert(overlay.phases == [0, 1, 2], "Initial drawing must prepare every layer")
	check_pixels(raster, 1.0)
	overlay.phases.clear()
	overlay.strength = 0.5
	assert(not overlay.refresh_for_view(0.067, camera, true), "Routine summaries can defer starting an overlay")
	await settled()
	assert(overlay.phases.is_empty())
	for phase in 3:
		overlay.refresh_for_view(0.0 if phase == 0 else 0.016, camera, phase > 0)
		assert(raster.render_target_update_mode == (SubViewport.UPDATE_ONCE if phase == 2 else SubViewport.UPDATE_DISABLED))
		await settled()
		assert(overlay.phases == [phase], "Only one layer should prepare each stationary frame")
		overlay.phases.clear()
		check_pixels(raster, 0.5 if phase == 2 else 1.0)
	for change in 4:
		overlay.refresh_for_view(0.1, camera)
		await settled()
		assert(overlay._next_phase == 1)
		overlay.phases.clear()
		match change:
			0: camera.position.x += 1
			1: camera.fov += 1
			2: overlay._input(InputEventKey.new())
			3: raster.size = Vector2i(20, 20)
		overlay.refresh_for_view(0.0, camera, true)
		assert(overlay._next_phase == -1 and raster.render_target_update_mode == SubViewport.UPDATE_ONCE)
		await settled()
		assert(overlay.phases == [0, 1, 2], "Camera, projection, input and resize must cancel partial preparation")
		overlay.phases.clear()
	overlay.refresh_for_view(0.1, camera)
	await settled()
	hud.root.hide()
	assert(not overlay.refresh_for_view(0.016, camera))
	assert(overlay._next_phase == -1 and raster.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	hud.root.show()
	overlay.phases.clear()
	overlay.refresh_for_view(0.0, camera)
	await settled()
	assert(overlay.phases == [0, 1, 2], "Showing the interface must restore all layers immediately")
	# Run the actual HUD coordinator: routine work never overlaps staged layers.
	var world := World.new()
	world.input = PlayerInput.new()
	world.cam = RtsCamera.new()
	world.cam.cam = camera
	hud.world = world
	hud.overlay = overlay
	hud.orbat = HudOrbat.new()
	overlay.overlay_frames.clear()
	for frame in 30:
		if frame % 6 == 0:
			overlay._groups_at = -1000
		hud._refresh_overview(1.0 / 60.0, frame % 6 == 0)
		await settled()
	assert(overlay.overlay_frames.size() >= 9 and overlay.group_frames.size() >= 4 and hud.roster_frames.size() >= 4, "All three workloads must keep making progress")
	for frame in overlay.group_frames:
		assert(not frame in overlay.overlay_frames and not frame in hud.roster_frames)
	for frame in hud.roster_frames:
		assert(not frame in overlay.overlay_frames, "Queued roster work must not pile onto staged drawing")
	var groups_before := overlay.group_frames.size()
	var roster_before := hud.roster_frames.size()
	var layers_before := overlay.overlay_frames.size()
	for frame in 16:
		overlay._groups_at = -1000
		hud._refresh_overview(0.3, true)
		await settled()
	assert(overlay.group_frames.size() > groups_before and hud.roster_frames.size() > roster_before and overlay.overlay_frames.size() > layers_before, "Very slow frames must not starve summaries, roster or overlay")
	hud.orbat.free()
	world.input.free()
	world.cam.free()
	world.free()
	hud.free()
	camera.free()
	print("OVERLAY_STAGING passed")
	get_tree().quit()

func settled() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func check_pixels(raster: SubViewport, strength: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := raster.get_texture().get_image()
	for phase in 3:
		assert(absf(image.get_pixel(20 + phase * 40, 20).r - strength) < 0.01, "Partially prepared commands must not change displayed pixels")
