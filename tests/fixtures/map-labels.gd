extends Node

class Overlay extends HudOverlay:
	var draws := 0
	func _draw() -> void:
		draws += 1
		_contact_burst(Vector2(40, 40), 1.0)
		var first := _contact_mesh
		_contact_burst(Vector2(80, 40), 0.5)
		assert(_contact_mesh == first, "Firing markers must reuse their triangulated geometry")
		assert(first.surface_get_array_len(0) == 16 and first.surface_get_array_index_len(0) == 42)

class PointerInput extends PlayerInput:
	var point := Vector2(20, 20)
	func _mouse() -> Vector2:
		return point

class PointerProbe extends HudPointerOverlay:
	var draws := 0
	var hint_point := Vector2.ZERO
	func _draw() -> void:
		draws += 1
		super._draw()
	func _hint(mp: Vector2, what: String, code: String, col: Color) -> void:
		hint_point = mp
		super._hint(mp, what, code, col)

class HudStub extends Hud:
	func _ready() -> void:
		pass
	func _process(_dt: float) -> void:
		pass

func _ready() -> void:
	var overlay := HudOverlay.new()
	overlay._groups[7] = {}
	overlay._label_epoch = 1
	var key := Vector2i(7, 0)
	var font := UiKit.cond(600, 1)
	var color := Color(0.8, 0.9, 0.7, 0.6)
	overlay._map_text(key, Vector2(100, 80), "ALPHA", font, 10, color)
	var label: HudOverlay.MapLabel = overlay._map_labels[key]
	var width := font.get_string_size("ALPHA", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	assert(label.position == Vector2(100 - width * 0.5, 80))
	assert(label.modulate == color and label.visible and label.show_behind_parent)
	overlay._label_epoch += 1
	overlay._map_text(key, Vector2(120, 90), "ALPHA", font, 10, Color.WHITE)
	assert(overlay._map_labels[key] == label and label.width == width)
	assert(label.position == Vector2(120 - width * 0.5, 90) and label.modulate == Color.WHITE)
	overlay._map_text(key, Vector2.ZERO, "LONGER CALLSIGN", UiKit.mono(400), 15, color)
	assert(label.text == "LONGER CALLSIGN" and label.font_size == 15 and label.face == UiKit.mono(400))
	assert(label.width == label.face.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
	overlay._finish_map_labels()
	assert(label.visible)
	overlay._label_epoch += 1
	overlay._finish_map_labels()
	assert(not label.visible)
	var footprint := Rect2(100, 100, 30, 20)
	overlay._clear_placed()
	overlay._place_rect(footprint)
	var offset := overlay._marker_offset(7, footprint)
	assert(offset == Vector2(0, -38))
	overlay._marker_offsets[7] = offset
	overlay._clear_placed()
	assert(overlay._marker_offset(7, footprint) == offset, "Clear counters keep their placement instead of jittering")
	overlay._place_rect(Rect2(footprint.position + offset, footprint.size))
	assert(overlay._marker_offset(7, footprint) == Vector2.ZERO, "New overlaps must find a clear placement")
	overlay._groups.clear()
	overlay._finish_map_labels()
	assert(overlay._map_labels.is_empty() and label.is_queued_for_deletion())
	assert(overlay._marker_offsets.is_empty(), "Removed squads must release their placement cache")
	await get_tree().process_frame
	overlay.free()
	var camera := Camera3D.new()
	add_child(camera)
	var refreshed := Overlay.new()
	add_child(refreshed)
	refreshed.refresh_for_view(0.0, camera)
	await get_tree().process_frame
	await get_tree().process_frame
	var before := refreshed.draws
	refreshed.refresh_for_view(0.01, camera)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(refreshed.draws == before, "A stationary overlay should retain its drawing between refreshes")
	refreshed.refresh_for_view(0.057, camera)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(refreshed.draws == before + 1, "Stationary status and animations still refresh at 15 Hz")
	camera.position.x = 1.0
	refreshed.refresh_for_view(0.0, camera)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(refreshed.draws == before + 2, "Camera motion must redraw immediately")
	refreshed.refresh_for_view(0.0, camera)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(refreshed.draws == before + 2, "Unchanged status must stay cached while the pointer layer draws independently")
	refreshed._input(InputEventKey.new())
	refreshed.refresh_for_view(0.0, camera)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(refreshed.draws == before + 3, "Selection and commands must redraw on input without waiting for the timer")
	before = refreshed.draws
	for i in 42:
		refreshed.refresh_for_view(1.0 / 42.0, camera)
		await get_tree().process_frame
		await get_tree().process_frame
	assert(refreshed.draws - before >= 14 and refreshed.draws - before <= 16, "Refresh cadence must retain elapsed time between uneven frames")
	before = refreshed.draws
	for i in 42:
		camera.h_offset = 0.2 if i % 2 == 0 else -0.2
		camera.v_offset = camera.h_offset
		refreshed.refresh_for_view(1.0 / 42.0, camera)
		await get_tree().process_frame
		await get_tree().process_frame
	assert(refreshed.draws - before >= 14 and refreshed.draws - before <= 16, "Blast shake must keep the status cadence instead of redrawing every frame")
	refreshed.free()
	var hud := HudStub.new()
	add_child(hud)
	hud.root = Control.new()
	hud.add_child(hud.root)
	var raster := SubViewport.new()
	raster.disable_3d = true
	raster.transparent_bg = true
	raster.gui_disable_input = true
	raster.render_target_update_mode = SubViewport.UPDATE_DISABLED
	hud.add_child(raster)
	var cached := Overlay.new()
	cached.hud = hud
	cached.raster = raster
	hud.overlay = cached
	raster.add_child(cached)
	cached.refresh_for_view(0.0, camera)
	assert(raster.size == Vector2i(get_viewport().get_visible_rect().size))
	assert(raster.render_target_update_mode == SubViewport.UPDATE_ONCE)
	await get_tree().process_frame
	await get_tree().process_frame
	before = cached.draws
	cached.refresh_for_view(0.01, camera)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(cached.draws == before, "Cached overlay pixels must be reused between updates")
	hud._input(InputEventKey.new())
	cached.refresh_for_view(0.0, camera)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(cached.draws == before + 1, "Main viewport input must invalidate the cached overlay")
	raster.size = Vector2i(20, 20)
	cached.refresh_for_view(0.0, camera)
	assert(raster.size == Vector2i(get_viewport().get_visible_rect().size), "The cache must follow viewport resizing")
	hud.root.hide()
	cached.refresh_for_view(0.1, camera)
	assert(raster.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Hidden HUDs must stop the extra viewport")
	hud.root.show()
	cached.refresh_for_view(0.0, camera)
	assert(raster.render_target_update_mode == SubViewport.UPDATE_ONCE, "Showing the HUD must refresh immediately")
	var world := World.new()
	hud.world = world
	world.cam = RtsCamera.new()
	world.cam.cam = camera
	var input := PointerInput.new()
	input.world = world
	input.ability = "smoke"
	world.input = input
	var pointer := PointerProbe.new()
	pointer.hud = hud
	hud.root.add_child(pointer)
	await get_tree().process_frame
	await get_tree().process_frame
	before = cached.draws
	var pointer_before := pointer.draws
	for i in 8:
		input.point += Vector2(5, 3)
		pointer.queue_redraw()
		cached.refresh_for_view(0.0, camera)
		await get_tree().process_frame
		await get_tree().process_frame
		assert(pointer.hint_point == input.point, "Ability feedback must follow the pointer each frame")
	assert(pointer.draws == pointer_before + 8 and cached.draws == before, "Pointer movement must not rebuild the cached army display")
	world.cam.free()
	input.free()
	world.free()
	hud.free()
	camera.free()
	print("MAP_LABELS passed")
	get_tree().quit()
