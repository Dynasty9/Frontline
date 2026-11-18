extends Node
## The light probes without a battle: the setting and its presets, saved
## settings taking it up, the probe reads going into the shaders that should
## have them (and only those), the structures' boxes laid into cubes (thin
## walls filled, windows left open, crowns marked as leaves), a structure
## changing queueing the tiles round it, and fires and lamps queueing the
## tiles their glow reaches when they come, go, move or change.


func _ready() -> void:
	call_deferred("check")


func check() -> void:
	Settings.no_save = true
	_check_presets()
	_check_saved_settings()
	_check_shaders()
	_check_cubes()
	_check_changes()
	_check_local_lights()
	_check_relight()
	_check_damage()
	_check_occluders()
	print("LIGHT PROBES passed: presets, saved settings, shaders, cubes, changes, local lights")
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
		assert(not grass.contains("probe_light(") and not grass.contains("#define PROBE_LIGHT"), "plain grass doesn't read the probes")
		# the meadow's and the wood's grass and undergrowth read them once a vertex
		var vgrass := CloudShadow.shader(Grass.GRASS_SHADER, CloudShadow.BACKLIGHT | CloudShadow.NO_SPECULAR | CloudShadow.FOLD | CloudShadow.PROBES_VERTEX, on)
		assert(vgrass.contains("probe_v_k = probe_vk.x;") and vgrass.contains("AO *= probe_v_k;") and not vgrass.contains("AO *= probe_k.x;"), "grass reads the probes per vertex")
		assert(vgrass.find("probe_v_k = probe_vk.x;") < vgrass.find("void fragment()"), "in vertex()")
		var fern := CloudShadow.shader(Woodland.SHADER, CloudShadow.BACKLIGHT | CloudShadow.NO_SPECULAR | CloudShadow.FOLD | CloudShadow.PROBES_VERTEX, on)
		assert(fern.contains("AO *= probe_v_k;"), "the wood's undergrowth reads them too")
		assert(not vgrass.contains("__LOCAL__") and not s.contains("__LOCAL__"), "every placeholder filled in")
	var px := LightProbes.PIXEL
	# reflections shut in with the sky: the probes' bands in the reflected direction
	# take the sky out of a reflection (RADIANCE), the room's own light in its place
	var use := LightProbes.PIXEL_USE
	assert(use.contains("RADIANCE = vec4(probe_lb * PROBE_SPEC_ROOM, 1.0 - probe_so);") and use.contains("reflect(-probe_v, probe_n)"))
	# light leaks: a pixel leaves out the probes with a wall between, on High
	assert(px.contains("global uniform sampler2DArray probe_voxels") and px.contains("col = probe_side(col, p, base, ps, t_lo, t_hi);"))
	# the fires' glow, from the atlas's bottom block
	assert(px.contains("ll = lc * lc * 8.0;") and LightProbes.BAKE_SHADER.contains("vec3 local_light(vec3 o)"))
	# leaves: the crowns' cubes are told apart and send on green light
	assert(LightProbes.BAKE_SHADER.contains("bool leafy(float dn)") and LightProbes.BAKE_SHADER.contains("lh = LEAF * "))
	# the crowns' share of what shuts a probe in goes in the bounce block's alpha,
	# and the shade it makes comes back green, per pixel and per blade
	assert(LightProbes.BAKE_SHADER.contains("fsum / max(wsum, 0.001)"))
	assert(LightProbes.PIXEL.contains("vec3 probe_canopy(float fill, float leaf)"))
	assert(LightProbes.PIXEL_USE.contains("ALBEDO *= probe_canopy(") and LightProbes.VERTEX_FRAGMENT.contains("ALBEDO *= probe_v_t;"))
	# the skinned soldiers read the probes too, through their own copy of the imported material
	var skin_src := LightProbes.SKIN_SHADER
	var skin := LightProbes.inject(skin_src)
	assert(skin.contains("vec4 probe_light(") and skin.contains("AO *= probe_k.x;") and skin.contains("RADIANCE = vec4("))
	var std := StandardMaterial3D.new()
	std.albedo_color = Color(0.5, 0.6, 0.7)
	var sm := LightProbes.skin_material(std)
	assert(sm.get_shader_parameter("albedo") == Color(0.5, 0.6, 0.7), "the soldier keeps his colour")
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
	# a tree's crown is laid as leaves (the tracer tints what comes through it green),
	# a wall never is
	var tree := Structure.new()
	tree.skind = "tree"
	tree.position = Vector3(20.0, 0.0, 20.0)
	tree.variant = 0
	var crown: Array = lp._boxes(tree)
	assert(not crown.is_empty(), "a tree has a crown")
	for box: Array in crown:
		if (box[0] as Transform3D).origin.y > 3.0:
			assert(is_equal_approx(float(box[2]), LightProbes.FOLIAGE), "a crown is leaves")
	bytes.fill(0)
	for box: Array in crown:
		lp._rasterize(box, 0.0, 0.0, geo, bytes)
	assert(at.call(20, 4, 20) >> 4 == roundi(LightProbes.FOLIAGE * 15.0) and at.call(20, 0, 20) == 0, "leaves up in the crown, none at the foot")
	assert(roundi(LightProbes.FOLIAGE * 15.0) != 15 and roundi(LightProbes.FOLIAGE * 15.0) != roundi(LightProbes.ROOF * 15.0))
	tree.burnt = true
	assert(lp._boxes(tree).is_empty(), "a burnt tree has no leaves")
	tree.free()
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


## A fire's light (an OmniLight3D in the probe_light group) queues the tiles its
## glow reaches; the same fire flickering on queues nothing more; moved, it
## queues them again; put out, it queues them once more (to clear them), and
## then it's gone from the tracer's list.
func _check_local_lights() -> void:
	var lp := LightProbes.new()
	lp._vsz = MapDims.SIZE / LightProbes.NV
	lp._ready_size = 0
	lp._local_mat = ShaderMaterial.new()
	lp._local_dirty.resize(LightProbes.TILES * LightProbes.TILES)
	lp.world = null
	add_child(lp)
	var tw := LightProbes.TILE * lp._vsz
	# in the middle of tile (3, 2), 4 m range: its glow stays in the tile
	var fire := OmniLight3D.new()
	fire.omni_range = 4.0
	fire.light_energy = 3.0
	fire.add_to_group(&"probe_light")
	add_child(fire)
	fire.global_position = Vector3(-MapDims.HALF + tw * 3.5, 1.0, -MapDims.HALF + tw * 2.5)
	var tile := 2 * LightProbes.TILES + 3
	lp._gather_lights()
	assert(Array(lp._local_queue) == [tile], "the fire's tile queued: %s" % [lp._local_queue])
	assert(int(lp._local_mat.get_shader_parameter("light_count")) == 1)
	lp._local_queue.clear()
	lp._local_dirty.fill(0)
	# flicker: a tenth up and down, nothing to trace again
	for e in [3.3, 2.7, 3.2, 2.9]:
		fire.light_energy = e
		lp._gather_lights()
	assert(lp._local_queue.is_empty(), "a flicker traces nothing again")
	# moved a whole tile east: the old tile (to clear it) and the new
	fire.global_position += Vector3(tw, 0, 0)
	lp._gather_lights()
	assert(Array(lp._local_queue) == [tile, tile + 1], "moved: %s" % [lp._local_queue])
	lp._local_queue.clear()
	lp._local_dirty.fill(0)
	# put out: its steady glow fades below the mark and its tile is cleared
	fire.light_energy = 0.0
	for i in 12:
		lp._gather_lights()
	assert(Array(lp._local_queue) == [tile + 1], "put out: %s" % [lp._local_queue])
	assert(int(lp._local_mat.get_shader_parameter("light_count")) == 0)
	# lights past LOCAL_MAX: only the nearest count
	var many: Array[OmniLight3D] = []
	for i in LightProbes.LOCAL_MAX + 4:
		var l := OmniLight3D.new()
		l.light_energy = 2.0
		l.add_to_group(&"probe_light")
		add_child(l)
		l.global_position = Vector3(i * 3.0, 1.0, 0.0)
		many.append(l)
	lp._gather_lights()
	assert(int(lp._local_mat.get_shader_parameter("light_count")) == LightProbes.LOCAL_MAX)
	for l in many:
		l.free()
	fire.free()
	lp.free()


class _Atmo extends Node:
	var sun := DirectionalLight3D.new()
	var _d := {"sun": Color(1.0, 0.9, 0.8), "energy": 1.0, "zenith": Color(0.3, 0.5, 0.9), "horizon": Color(0.7, 0.8, 0.9), "ambient": 0.6}


## The light moving on: a new mood queues the bounce alone of the bricks with
## something in reach (not their cubes or sky share); the sun swinging a degree
## queues nothing, two and a half queue them again; the light dimming as a whole
## only changes the reference the bounce is read against.
func _check_relight() -> void:
	LightProbes._ensure_globals()
	var lp := LightProbes.new()
	var atmo := _Atmo.new()
	lp.atmo = atmo
	lp._vsz = MapDims.SIZE / LightProbes.NV
	lp._ready_size = 0
	lp._bake_mat = ShaderMaterial.new()
	for a: PackedByteArray in [lp._tile_full, lp._tile_dug, lp._light_dirty, lp._brick_dirty]:
		a.resize(LightProbes.TILES * LightProbes.TILES)
	atmo.sun.rotation_degrees = Vector3(-30.0, 40.0, 0.0)
	var t := 5 * LightProbes.TILES + 5
	lp._tile_full[t] = 1  # a house in tile (5, 5): the 3 x 3 bricks round it are in reach
	lp.relight()
	assert(lp._light_queue.size() == 9 and lp._light_queue.has(t) and lp._brick_queue.is_empty(), "relight queues bounce only: %s" % [lp._light_queue])
	assert(is_equal_approx(lp._baked_share, float(lp._light_now()[4])))
	lp._light_queue.clear()
	lp._light_dirty.fill(0)
	atmo.sun.rotation_degrees = Vector3(-31.0, 40.0, 0.0)
	lp._follow_light()
	assert(lp._light_queue.is_empty(), "a degree of sun traces nothing again")
	atmo.sun.rotation_degrees = Vector3(-32.5, 40.0, 0.0)
	lp._follow_light()
	assert(lp._light_queue.size() == 9, "two and a half degrees trace the bounce again")
	lp._light_queue.clear()
	lp._light_dirty.fill(0)
	var was: Vector3 = lp._ref
	atmo._d.energy = 0.5
	atmo._d.ambient = 0.3
	lp._follow_light()
	assert(lp._light_queue.is_empty(), "the light dimming as a whole traces nothing again")
	assert(lp._ref.is_equal_approx(was * 0.5), "the bounce dims with it: %s -> %s" % [was, lp._ref])
	assert(LightProbes.BAKE_SHADER.contains("lb / light_ref") and LightProbes.PIXEL.contains("probe_ref.rgb"))
	atmo.sun.free()
	atmo.free()
	lp.free()


## Battle damage: a crater out in the open makes its tile one the tracer traces
## (its bowl shuts out some sky) and queues it once its heights are in; an open
## door's leaf stops being a wall.
func _check_damage() -> void:
	var lp := LightProbes.new()
	lp._vsz = MapDims.SIZE / LightProbes.NV
	lp._ready_size = 0
	for a: PackedByteArray in [lp._tile_full, lp._tile_dug, lp._brick_dirty]:
		a.resize(LightProbes.TILES * LightProbes.TILES)
	var t := 7 * LightProbes.TILES + 3
	assert(not lp._in_reach(t), "open ground: nothing to trace")
	var m := TerrainMap.DN / float(LightProbes.NV)
	var cell := Vector2i(roundi((3.5 * LightProbes.TILE) * m), roundi((7.5 * LightProbes.TILE) * m))
	lp.terrain_changed(Rect2i(cell, Vector2i(4, 4)))
	assert(lp._tile_dug[t] == 1 and lp._in_reach(t) and lp._in_reach(t + 1), "a crater's tile and its neighbours are traced")
	assert(lp._late.size() == 1 and int(lp._late[0][1]) == t, "queued once its heights are in")
	var st := Structure.new()
	st.skind = "house_wall"
	st.parts = [{"p": Vector3(0, 1.5, 0), "s": Vector3(4.0, 3.0, 0.3)}, {"p": Vector3(0, 1.0, 0.1), "s": Vector3(0.9, 2.0, 0.05), "door": true}]
	st.door_shut = true
	assert(lp._boxes(st).size() == 2)
	st.door_shut = false
	assert(lp._boxes(st).size() == 1, "an open door's leaf lets the light through")
	st.free()
	lp.free()


## Vehicles and men: a tank's footprint reaches past its hull, a helicopter in
## the air casts none, a man standing shades more than one lying, and the
## pixels read the map.
func _check_occluders() -> void:
	var tank := LightProbes.vehicle_print(Vector3(3.6, 2.4, 7.5), 0.0)
	assert(not tank.is_empty() and (tank[0] as Vector2).x >= 1.8 + 1.0 and (tank[0] as Vector2).y <= 3.75 + 1.5)
	assert(is_equal_approx(float(tank[1]), LightProbes.OCC_VEHICLE))
	assert((tank[2] as Vector2).x < 1.0 and (tank[2] as Vector2).y < 1.0, "a soft edge round the hull")
	assert(LightProbes.vehicle_print(Vector3(3, 3, 12), 20.0).is_empty(), "a helicopter in the air shades nothing")
	assert(float(LightProbes.vehicle_print(Vector3(3, 3, 12), 2.0)[1]) < float(tank[1]), "less off the ground")
	assert(float(LightProbes.man_print(false, false)[1]) > float(LightProbes.man_print(true, false)[1]))
	assert(float(LightProbes.man_print(false, false)[1]) < float(tank[1]), "a man's pool is fainter than a tank's")
	assert(LightProbes.OCC_SHADER.contains("blend_mul") and LightProbes.OCC_SHADER.contains("exp(-3.0 * d)"), "rounded, darkest at the contact line")
	var px := LightProbes._pixel()
	assert(px.contains("probe_occ_rect") and px.contains("#define PROBE_OCC_HEIGHT %.2f" % LightProbes.OCC_HEIGHT) and not px.contains("__OCC_HEIGHT__"))
