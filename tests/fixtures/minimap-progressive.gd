extends Node

class TrackedMap extends HudMinimap:
	var draws := {}
	func _draw_content(phase := -1) -> void:
		var frame := Engine.get_process_frames()
		if not draws.has(frame):
			draws[frame] = []
		draws[frame].append(phase)

func _ready() -> void:
	var world := World.new()
	var hud := Hud.new()
	hud.world = world
	var map := TrackedMap.new()
	map.hud = hud
	map.size = Vector2(240, 240)
	map.prepare_layers()
	add_child(map)
	map.refresh_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	map.draws.clear()
	for i in 12:
		map.refresh_layers()
		await get_tree().process_frame
	await get_tree().process_frame
	var totals := [0, 0, 0, 0, 0]
	for phases: Array in map.draws.values():
		var expensive := 0
		for phase: int in phases:
			totals[phase] += 1
			if phase < 4:
				expensive += 1
		assert(expensive <= 1, "Expensive minimap layers must not refresh together")
	for i in 4:
		assert(totals[i] == 3, "Every layer must get an equal share of frames")
	assert(totals[4] == 12, "Camera and pointer indicators must update every frame")
	map.hide()
	var phase := map._phase
	map.refresh_layers()
	assert(map._phase == phase, "Hidden minimaps must not consume update slots")
	map.show()
	map.size = Vector2(320, 320)
	for i in 4:
		map.refresh_layers()
		await get_tree().process_frame
	Settings.no_save = true
	Settings.set_v("minimap_rotate", true)
	world.cam = RtsCamera.new()
	world.cam.yaw = 0.5
	map.draws.clear()
	map.refresh_layers()
	await get_tree().process_frame
	await get_tree().process_frame
	var rotated := []
	for phases: Array in map.draws.values(): rotated.append_array(phases)
	rotated.sort()
	assert(rotated == [0, 1, 2, 3, 4], "Rotation must update all layers in the same coordinate system")
	world.cam.free()
	world.cam = null
	map.free()
	hud.free()
	world.free()
	print("MINIMAP_PROGRESSIVE passed")
	get_tree().quit()
