extends Node
## The light probes without a battle: the setting and its presets, saved
## settings taking it up, the probe reads going into the shaders that should
## have them (and only those), the structures' boxes laid into cubes (thin
## walls filled, windows left open), and a structure changing queueing the
## tiles round it.


func _ready() -> void:
	call_deferred("check")


func check() -> void:
	Settings.no_save = true
	_check_presets()
	_check_saved_settings()
	_check_shaders()
	_check_cubes()
	_check_changes()
	print("LIGHT PROBES passed: presets, saved settings, shaders, cubes, changes")
	get_tree().quit()


func _check_presets() -> void:
	for p in Settings.PRESETS:
		assert(Settings.PROBE_PRESETS.has(p), "preset %s leaves out the light probes" % p)
	var saved := Settings.v.duplicate()
	var saved_preset := Settings.preset
	Settings.apply_preset("low", false)
	assert(int(Settings.v.light_probes) == 0, "Low turns the probes off")
	Settings.apply_preset("medium", false)
	assert(int(Settings.v.light_probes) == 1, "Medium keeps only the sky's shade")
	Settings.apply_preset("high", false)
	assert(int(Settings.v.light_probes) == 2, "High has the whole grid")
	Settings.v = saved
	Settings.preset = saved_preset


## A settings file from before the setting takes no more than its preset's.
func _check_saved_settings() -> void:
	var saved := Settings.v.duplicate()
	var saved_preset := Settings.preset
	var path := "user://light_probes_test.cfg"
	for case in [["low", 0], ["medium", 1], ["high", 2], ["custom", 2]]:
		var cf := ConfigFile.new()
		cf.set_value("main", "preset", case[0])
		cf.set_value("main", "cfg_version", 2)
		cf.save(path)
		Settings.v.light_probes = 2
		Settings._load(path)
		assert(int(Settings.v.light_probes) == case[1], "a %s settings file from before gets light probes %d" % case)
	var cf2 := ConfigFile.new()
	cf2.set_value("main", "preset", "low")
	cf2.set_value("main", "light_probes", 2)
	cf2.save(path)
	Settings._load(path)
	assert(int(Settings.v.light_probes) == 2, "a choice once saved stands")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.v = saved
	Settings.preset = saved_preset


## The surfaces that stand in streets and rooms read the probes; grass and
## leaves (overdrawn many times, and lit through) don't.
func _check_shaders() -> void:
	for on in [false, true]:
		var s := CloudShadow.shader(Mats.SURFACE_SHADER, CloudShadow.CLEARCOAT | CloudShadow.PROBES, on)
		assert(s.contains("vec4 probe_light(") and s.contains("AO *= probe_k.x;") and s.contains("EMISSION += ALBEDO * probe_k.yzw;"))
		# the fill light opposite the sun is shut out with the sky, in the shared light model
		assert(s.contains("#define PROBE_LIGHT") and s.contains("probe_fill = probe_k.x;"))
		if on and not CloudShadow.vertex_lit():
			assert(s.contains("att *= probe_fill;"), "the shared light model dims the fill light")
		assert(not s.contains("// CLOUD_"), "every mark filled in")
		var g := CloudShadow.shader(Atmosphere.GROUND_SHADER, CloudShadow.OWN_LIGHT | CloudShadow.PROBES, on)
		assert(g.contains("probe_light(") and g.count("void light()") == 1)
		var grass := CloudShadow.shader(Grass.GRASS_SHADER, CloudShadow.BACKLIGHT | CloudShadow.NO_SPECULAR | CloudShadow.FOLD, on)
		assert(not grass.contains("probe_light(") and not grass.contains("#define PROBE_LIGHT"), "grass doesn't read the probes")
	assert(LightProbes.BAKE_SHADER.contains("shader_type canvas_item;"))
	# the atlas layout the pixels read is the one the bake writes
	assert(LightProbes.ATLAS == Vector2i(4096, 1536))
	assert(LightProbes.PIXEL.contains("vec2(4096.0, 1536.0)") and LightProbes.PIXEL.contains("layer * 512.0"))
	# High's decoder carries its weights: 10 inputs x 16 hidden, 16 out
	assert(LightProbes.PIXEL.contains("const float PROBE_W1[160] = float[160](") and LightProbes.PIXEL.contains("const float PROBE_W2[16]"))
	assert(LightProbes.PIXEL.get_slice("PROBE_W1[160] = float[160](", 1).get_slice(");", 0).split(",").size() == 160)


## A wall 4 m long, 3 m high and 0.4 m thick: the cubes it passes through, two
## deep (a thin wall fills every cube it touches), none past its ends; and two
## piers with a 1.3 m window between them leave the window's cubes open.
func _check_cubes() -> void:
	var lp := LightProbes.new()
	lp._vsz = 1.0
	var geo := PackedFloat32Array()
	geo.resize(LightProbes.TILE * LightProbes.TILE)
	var bytes := PackedByteArray()
	bytes.resize(LightProbes.TILE * LightProbes.TILE * LightProbes.VH)
	var wall := [Transform3D(Basis(), Vector3(10.0, 1.5, 10.0)), Vector3(2.0, 1.5, 0.2), 1.0, 0.4]
	assert(lp._rasterize(wall, 0.0, 0.0, geo, bytes))
	var at := func(x: int, y: int, z: int) -> int:
		return bytes[(y * LightProbes.TILE + z) * LightProbes.TILE + x]
	for x in range(8, 12):
		for y in range(0, 3):
			assert(at.call(x, y, 10) >> 4 == 15 and at.call(x, y, 9) >> 4 == 15, "the wall fills (%d, %d)" % [x, y])
	assert(at.call(7, 1, 10) == 0 and at.call(12, 1, 10) == 0 and at.call(10, 3, 10) == 0 and at.call(10, 1, 11) == 0, "nothing past the wall")
	assert(at.call(9, 1, 10) & 15 == roundi(0.4 / 0.8 * 15.0), "the cube keeps the wall's albedo")
	bytes.fill(0)
	for px in [-1.3, 1.3]:
		lp._rasterize([Transform3D(Basis(), Vector3(30.0 + px, 1.5, 20.0)), Vector3(0.65, 1.5, 0.2), 1.0, 0.4], 0.0, 0.0, geo, bytes)
	assert(at.call(30, 1, 20) == 0, "the window between the piers stays open")
	assert(at.call(28, 1, 20) != 0 and at.call(31, 1, 20) != 0)
	# turned a quarter, the same wall runs the other way
	bytes.fill(0)
	lp._rasterize([Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(10.0, 1.5, 10.0)), Vector3(2.0, 1.5, 0.2), 1.0, 0.4], 0.0, 0.0, geo, bytes)
	assert(at.call(10, 1, 8) != 0 and at.call(10, 1, 11) != 0 and at.call(12, 1, 10) == 0)
	lp.free()


## A structure appearing marks the tiles it reaches (with room for a tree's
## crown), and only once however often it's reported.
func _check_changes() -> void:
	var lp := LightProbes.new()
	lp._vsz = MapDims.SIZE / LightProbes.NV
	lp._ready_size = 0
	lp._tile_dirty.resize(LightProbes.TILES * LightProbes.TILES)
	var st := Structure.new()
	st.position = Vector3(-MapDims.HALF + 64.0 * lp._vsz + 1.0, 0, -MapDims.HALF + 10.0)
	st.radius = 1.0
	lp.structure_changed(st)
	lp.structure_changed(st)
	# it stands just inside tile (1, 0), within reach of tile (0, 0)
	assert(Array(lp._tile_queue) == [0, 1], "queued %s" % [lp._tile_queue])
	st.free()
	lp.free()
