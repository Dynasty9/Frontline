extends Node

class TrackedMap extends HudMinimap:
	var draws := {}
	func _draw_content(phase := -1) -> void:
		var frame := Engine.get_process_frames()
		if not draws.has(frame):
			draws[frame] = []
		draws[frame].append(phase)

class TrackedCamera extends RtsCamera:
	var casts := 0
	func ground_point(screen: Vector2) -> Vector3:
		casts += 1
		return Vector3(screen.x, 0, screen.y) + cam.position

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
	var tracked := TrackedCamera.new()
	tracked.cam = Camera3D.new()
	add_child(tracked.cam)
	world.cam = tracked
	var corners := map._view_corners(world, Vector2(1280, 720)).duplicate()
	for i in 8:
		assert(map._view_corners(world, Vector2(1280, 720)) == corners)
	assert(tracked.casts == 4, "Stationary minimap views must reuse terrain intersections")
	tracked.cam.position.x += 10
	assert(map._view_corners(world, Vector2(1280, 720))[0].x == corners[0].x + 10)
	assert(tracked.casts == 8, "Moving the camera must immediately update its minimap wedge")
	tracked.cam.fov += 5
	map._view_corners(world, Vector2(1280, 720))
	assert(tracked.casts == 12, "Projection changes invalidate ground intersections")
	map._view_corners(world, Vector2(1600, 900))
	assert(tracked.casts == 16, "Resizing the viewport invalidates ground intersections")
	world.has_view = false
	world.terrain = TerrainMap.new(world)
	map._view_corners(world, Vector2(1600, 900))
	world.terrain.version += 1
	map._view_corners(world, Vector2(1600, 900))
	assert(tracked.casts == 24, "Changing the ground invalidates the minimap wedge")
	tracked.cam.free()
	tracked.free()
	world.cam = null
	map.free()
	hud.free()
	world.free()
	print("MINIMAP_PROGRESSIVE passed")
	get_tree().quit()
