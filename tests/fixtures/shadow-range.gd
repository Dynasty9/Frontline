extends Node

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var checked := 0
	for size in [Vector2i(1280, 720), Vector2i(600, 900), Vector2i(2560, 720)]:
		viewport.size = size
		for fov in [35.0, 48.0, 75.0]:
			camera.fov = fov
			for height in [7.0, 50.0, 130.0, 400.0]:
				camera.position = Vector3(0, height, 80)
				for pitch in [-86.0, -55.0, -20.0, 10.0]:
					camera.rotation_degrees = Vector3(pitch, 20, 8)
					var limit := Atmosphere.fitted_shadow_distance(camera, 800.0, 0.85)
					assert(limit > 0.0 and limit <= 800.0)
					for y in 9:
						for x in 9:
							var pixel := Vector2(size) * Vector2(x, y) / 8.0
							var origin := camera.project_ray_origin(pixel)
							var ray := camera.project_ray_normal(pixel)
							if ray.y >= -0.001:
								assert(limit == 800.0, "Horizon views retain the configured range")
							elif limit < 800.0:
								var receiver := origin + ray * ((-8.0 - origin.y) / ray.y)
								assert(camera.global_position.distance_to(receiver) < limit * 0.85, "No visible receiver enters the fade")
					checked += 1
	camera.position = Vector3(0, 100, 80)
	camera.rotation_degrees = Vector3(-60, 0, 0)
	camera.fov = 48
	viewport.size = Vector2i(1280, 720)
	var range := Atmosphere.fitted_shadow_distance(camera, 800.0, 0.85)
	assert(range < 400.0, "A command view should release distant shadow work")
	assert(Atmosphere.fitted_shadow_distance(camera, 140.0, 0.85) == 140.0)
	var world := World.new()
	var atmosphere := Atmosphere.new()
	atmosphere.sun = DirectionalLight3D.new()
	atmosphere.sun.shadow_enabled = true
	atmosphere.sun.directional_shadow_max_distance = 800
	atmosphere.sun.directional_shadow_fade_start = 0.85
	atmosphere._fit_shadows()
	atmosphere.world = world
	atmosphere._fit_shadows()
	world.cam = RtsCamera.new()
	atmosphere._fit_shadows()
	assert(atmosphere.sun.directional_shadow_max_distance == 800.0, "Loading retains the preset until the camera exists")
	world.cam.cam = camera
	atmosphere._fit_shadows()
	assert(atmosphere.sun.directional_shadow_max_distance == range)
	camera.position.x += 100
	atmosphere._fit_shadows()
	assert(atmosphere.sun.directional_shadow_max_distance == range, "A pan retains stable cascades")
	atmosphere._terrain_probe = ReflectionProbe.new()
	atmosphere._fit_shadows()
	assert(atmosphere.sun.directional_shadow_max_distance == 800.0, "Secondary terrain reflections retain the original coverage")
	atmosphere._terrain_probe.free()
	atmosphere._terrain_probe = null
	atmosphere._fit_shadows()
	assert(atmosphere.sun.directional_shadow_max_distance == range)
	camera.rotation_degrees.x = -20
	atmosphere._fit_shadows()
	assert(atmosphere.sun.directional_shadow_max_distance == 800.0, "Tilting toward the horizon expands coverage immediately")
	camera.position.y = -10
	assert(Atmosphere.fitted_shadow_distance(camera, 800, 0.85) == 800)
	atmosphere.sun.free()
	atmosphere.free()
	world.cam.free()
	world.free()
	print("SHADOW_RANGE passed ", checked)
	get_tree().quit()
