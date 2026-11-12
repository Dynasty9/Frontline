extends Node
## Cloud shadows on everything, without a battle: the setting and how saved
## settings take it up, every shader that should take the shade carrying the
## marks, what each lighting path compiles to, the setting recoding shaders,
## and the clouds drifting downwind. Run windowed, it also draws a sphere in
## and out of a cloud's shade, with and without the sun, to check that only
## the sunlight is cut.


func _ready() -> void:
	call_deferred("check")


func check() -> void:
	Settings.no_save = true
	_check_presets()
	_check_saved_settings()
	_check_marks()
	_check_paths()
	_check_refresh()
	_check_drift()
	if DisplayServer.get_name() != "headless":
		await _check_light()
	print("CLOUD SHADOWS passed: presets, saved settings, marks, lighting paths, refresh, drift")
	get_tree().quit()


func _check_presets() -> void:
	for p in Settings.PRESETS:
		assert(Settings.PRESETS[p].has("cloud_shadows"), "preset %s leaves out cloud shadows" % p)
	assert(not Settings.PRESETS.low.cloud_shadows and not Settings.PRESETS.medium.cloud_shadows)
	assert(Settings.PRESETS.high.cloud_shadows and Settings.PRESETS.ultra.cloud_shadows)
	assert(bool(Settings.v.cloud_shadows))


## A settings file from before the setting takes its preset's (a custom one the default).
func _check_saved_settings() -> void:
	var saved := Settings.v.duplicate()
	var saved_preset := Settings.preset
	var path := "user://cloud_shadows_test.cfg"
	# [the file's preset, the setting before it's read (the default is on), after]
	for case in [["low", true, false], ["high", false, true], ["custom", true, true]]:
		var cf := ConfigFile.new()
		cf.set_value("main", "preset", case[0])
		cf.set_value("main", "cfg_version", 2)
		cf.save(path)
		Settings.v.cloud_shadows = case[1]
		Settings._load(path)
		assert(bool(Settings.v.cloud_shadows) == case[2], "a %s settings file from before gets cloud shadows %s" % [case[0], case[2]])
	var cf2 := ConfigFile.new()
	cf2.set_value("main", "preset", "low")
	cf2.set_value("main", "cloud_shadows", true)
	cf2.save(path)
	Settings._load(path)
	assert(bool(Settings.v.cloud_shadows), "a choice once saved stands")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.v = saved
	Settings.preset = saved_preset


## Everything that stands in the sun (and the ground's own surfaces) reads the shade.
func _check_marks() -> void:
	var sources := {
		"surfaces": Mats.SURFACE_SHADER, "foliage": Mats.FOLIAGE_SHADER, "netting": Mats.NETTING_SHADER,
		"distant soldiers": Mats.DISTANT_SHADER, "grass": Grass.GRASS_SHADER, "bushes": Grass.BUSH_SHADER,
		"stones": Grass.STONE_SHADER, "ground": Atmosphere.GROUND_SHADER, "roads": Atmosphere.ROAD_SHADER,
		"distant forest": DistantForest.SHADER, "trench walls": TrenchNet.WALL_SHADER, "berms": TrenchNet.BERM_SHADER,
		"trench floors": TrenchNet.FLOOR_SHADER, "duckboards": TrenchNet.BOARD_SHADER,
	}
	for name in sources:
		var src: String = sources[name]
		assert(src.contains("// CLOUD_SHADOW") and src.contains("// CLOUD_FRAGMENT "), "the %s shader takes no cloud shade" % name)


func _check_paths() -> void:
	var src: String = Mats.SURFACE_SHADER
	var off := CloudShadow.shader(src, CloudShadow.CLEARCOAT, false)
	assert(not off.contains("cloud_") and not off.contains("void light()"), "off, the surfaces light as before")
	var lit := _per_pixel(true)
	var on := CloudShadow.shader(src, CloudShadow.CLEARCOAT, true)
	assert(on.contains("void light()") and on.contains("cloud_k = cloud_sun(wpos);") and on.contains("cloud_coat = vec2(CLEARCOAT"))
	assert(not on.contains("// CLOUD_"))
	# leaves and grass: light through them, and grass has no specular
	var grass := CloudShadow.shader(Grass.GRASS_SHADER, CloudShadow.BACKLIGHT | CloudShadow.NO_SPECULAR, true)
	assert(grass.contains("#define CLOUD_BACKLIGHT") and grass.contains("#define CLOUD_NO_SPECULAR") and not grass.contains("cloud_specular ="))
	# the ground lights itself, and keeps its clouds with the setting off
	var ground := CloudShadow.shader(Atmosphere.GROUND_SHADER, CloudShadow.OWN_LIGHT, false)
	assert(ground.contains("float cloud_sun(") and not ground.contains("CLOUD_ON") and ground.count("void light()") == 1)
	# the sun is told apart by the direction the atmosphere sets every frame: the
	# ground's own sun_direction waits for the terrain bake, which a flat map never runs
	assert(ground.contains("cloud_is_sun(LIGHT, VIEW_MATRIX)"))
	# per-vertex lighting (the browser): no light() of ours, the albedo and AO instead
	_per_pixel(false)
	var vl := CloudShadow.shader(src, CloudShadow.CLEARCOAT, true)
	assert(vl.contains("#define CLOUD_VERTEX_LIT") and vl.contains("AO /= cloud_d;") and not vl.contains("void light()"))
	var vl_ground := CloudShadow.shader(Atmosphere.GROUND_SHADER, CloudShadow.OWN_LIGHT, true)
	assert(vl_ground.contains("AO /= cloud_d;"))
	_per_pixel(lit)


## Sets per-pixel (true) or per-vertex lighting for the shaders made next; returns what it was.
func _per_pixel(on: bool) -> bool:
	var key := "rendering/shading/overrides/force_vertex_shading"
	var was := not bool(ProjectSettings.get_setting_with_override(key))
	ProjectSettings.set_setting(key, not on)
	return was


func _check_refresh() -> void:
	var was := bool(Settings.v.cloud_shadows)
	Settings.v.cloud_shadows = false
	CloudShadow.refresh()
	var sh := CloudShadow.make(Mats.DISTANT_SHADER)
	assert(not sh.code.contains("cloud_sun"))
	Settings.v.cloud_shadows = true
	CloudShadow.refresh()
	assert(sh.code.contains("cloud_sun(wpos)"), "turning the setting on recodes the shaders")
	# changed in the menu, where nothing refreshes them: the next shader made catches the rest up
	Settings.v.cloud_shadows = false
	CloudShadow.make(Mats.DISTANT_SHADER)
	assert(not sh.code.contains("cloud_sun"), "a shader made after a change recodes the older ones")
	Settings.v.cloud_shadows = true
	CloudShadow.refresh()
	Settings.v.cloud_shadows = false
	CloudShadow.refresh()
	assert(not sh.code.contains("cloud_sun"))
	Settings.v.cloud_shadows = was
	CloudShadow.refresh()


## The shade travels with the wind that carries the smoke, at about half a metre a second.
func _check_drift() -> void:
	CloudShadow.set_sky(null, 0.35)
	var o0: Vector2 = CloudShadow._offset
	CloudShadow.tick(10.0)
	# (the offset wraps round the pattern's edge)
	var step: Vector2 = (CloudShadow._offset - o0 + Vector2(0.5, 0.5)).posmod(1.0) - Vector2(0.5, 0.5)
	var moved := -step / CloudShadow.SCALE
	var wind := Vector2(Fires.WIND.x, Fires.WIND.z).normalized()
	assert(moved.normalized().dot(wind) > 0.999, "the clouds drift downwind")
	assert(absf(moved.length() / 10.0 - 0.53) < 0.05, "at %.2f m/s" % (moved.length() / 10.0))
	for i in 2000:
		CloudShadow.tick(1.0)
	assert(CloudShadow._offset.x >= 0.0 and CloudShadow._offset.x < 1.0 and CloudShadow._offset.y >= 0.0 and CloudShadow._offset.y < 1.0)
	CloudShadow.set_sky(null, 0.0)


## A sphere on the shared surface shader, drawn in full shade and in none, lit
## by the sun and then by the sky alone: the shade takes some of the sunlight
## and none of the skylight.
func _check_light() -> void:
	var was := bool(Settings.v.cloud_shadows)
	Settings.v.cloud_shadows = true
	CloudShadow.refresh()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.4, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.6)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	add_child(sun)
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	ball.material_override = Mats.get_mat("plain")
	add_child(ball)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.2, 3.0), Vector3.ZERO)
	var shade := Image.create(4, 4, false, Image.FORMAT_L8)
	shade.fill(Color.WHITE)  # cloud everywhere
	var pattern := ImageTexture.create_from_image(shade)
	var lit: Array[float] = []  # sunlit in the open, sunlit in shade, sky alone in the open, in shade
	for sunny in [true, false]:
		sun.visible = sunny
		for strength in [0.0, 0.35]:
			CloudShadow.set_sky(pattern, strength)
			CloudShadow.set_sun(sun)
			for frame in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			lit.append(img.get_pixel(img.get_width() / 2, img.get_height() / 2).get_luminance())
	var sun_open := lit[0]
	var sun_shade := lit[1]
	var sky_open := lit[2]
	var sky_shade := lit[3]
	print("CLOUD SHADOWS light: sun %.3f -> %.3f in shade, sky alone %.3f -> %.3f" % [sun_open, sun_shade, sky_open, sky_shade])
	assert(sun_shade < sun_open * 0.95, "the shade dims the sunlit side")
	assert(absf(sky_shade - sky_open) < 0.01, "the shade leaves the skylight alone")
	CloudShadow.set_sky(null, 0.0)
	for n in [we, sun, ball, camera]:
		n.free()
	Settings.v.cloud_shadows = was
	CloudShadow.refresh()
