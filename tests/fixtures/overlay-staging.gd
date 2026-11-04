extends Node

class HudStub extends Hud:
	func _ready() -> void:
		pass
	func _process(_dt: float) -> void:
		pass

class Overlay extends HudOverlay:
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
	for phase in 3:
		overlay.refresh_for_view(0.067 if phase == 0 else 0.016, camera)
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
		overlay.refresh_for_view(0.0, camera)
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
