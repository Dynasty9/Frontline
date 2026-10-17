class_name Atmosphere
extends Node3D
## Everything about the look of the battlefield: sky, sun, time of day,
## ground, roads, post-processing, and how the graphics settings apply.

const MOODS := {
	"day": {"elev": 52.0, "azim": -35.0, "sun": Color(1.0, 0.95, 0.86), "energy": 2.1, "zenith": Color(0.22, 0.42, 0.74),
		"horizon": Color(0.68, 0.76, 0.84), "fog": Color(0.66, 0.72, 0.8), "fog_d": 0.0012, "ambient": 0.55, "soft": 0.6, "clouds": 0.35, "exposure": 1.0},
	"golden": {"elev": 24.0, "azim": -60.0, "sun": Color(1.0, 0.82, 0.62), "energy": 2.3, "zenith": Color(0.24, 0.39, 0.64),
		"horizon": Color(0.92, 0.78, 0.62), "fog": Color(0.8, 0.74, 0.66), "fog_d": 0.0016, "ambient": 0.45, "soft": 0.8, "clouds": 0.3, "exposure": 1.05},
	"dawn": {"elev": 12.0, "azim": 70.0, "sun": Color(1.0, 0.72, 0.58), "energy": 1.9, "zenith": Color(0.2, 0.3, 0.52),
		"horizon": Color(0.9, 0.7, 0.62), "fog": Color(0.72, 0.68, 0.68), "fog_d": 0.0021, "ambient": 0.5, "soft": 1.0, "clouds": 0.25, "exposure": 1.15},
	"dusk": {"elev": 9.0, "azim": -95.0, "sun": Color(1.0, 0.62, 0.42), "energy": 1.9, "zenith": Color(0.14, 0.19, 0.38),
		"horizon": Color(0.88, 0.58, 0.45), "fog": Color(0.48, 0.42, 0.44), "fog_d": 0.002, "ambient": 0.4, "soft": 1.2, "clouds": 0.2, "exposure": 1.2},
	"overcast": {"elev": 60.0, "azim": -20.0, "sun": Color(0.86, 0.89, 0.94), "energy": 0.9, "zenith": Color(0.5, 0.53, 0.58),
		"horizon": Color(0.72, 0.74, 0.76), "fog": Color(0.66, 0.68, 0.7), "fog_d": 0.0035, "ambient": 0.85, "soft": 7.0, "clouds": 0.0, "exposure": 1.1},
	"night": {"elev": 42.0, "azim": 125.0, "sun": Color(0.55, 0.66, 0.98), "energy": 0.26, "zenith": Color(0.008, 0.012, 0.03),
		"horizon": Color(0.045, 0.06, 0.1), "fog": Color(0.05, 0.065, 0.1), "fog_d": 0.0022, "ambient": 0.2, "soft": 0.5, "clouds": 0.12, "exposure": 1.6},
	"rain": {"elev": 58.0, "azim": 15.0, "sun": Color(0.74, 0.78, 0.84), "energy": 0.75, "zenith": Color(0.27, 0.3, 0.34),
		"horizon": Color(0.46, 0.49, 0.52), "fog": Color(0.42, 0.45, 0.48), "fog_d": 0.0038, "ambient": 0.8, "soft": 6.0, "clouds": 0.0, "exposure": 1.2},
	"hazy": {"elev": 38.0, "azim": 25.0, "sun": Color(1.0, 0.9, 0.76), "energy": 1.7, "zenith": Color(0.42, 0.52, 0.66),
		"horizon": Color(0.82, 0.8, 0.74), "fog": Color(0.8, 0.77, 0.7), "fog_d": 0.0042, "ambient": 0.65, "soft": 1.5, "clouds": 0.25, "exposure": 1.05},
}

var world: World
var mood := "golden"


## The battle's lighting mood: the one asked for, or one picked from the map
## seed (so the server knows it's raining without drawing anything).
static func pick_mood(settings: Dictionary) -> String:
	var pick := String(settings.get("mood", "random"))
	if not MOODS.has(pick):
		var r := RandomNumberGenerator.new()
		r.seed = int(settings.get("seed", 1)) * 7 + 3
		# weight the prettier moods a bit higher
		var bag := ["golden", "golden", "day", "day", "dawn", "dusk", "overcast", "hazy", "night", "rain"]
		pick = bag[r.randi() % bag.size()]
		if not MOODS.has(pick):
			pick = MOODS.keys()[0]
	return pick
var env: Environment
var we: WorldEnvironment
var sun: DirectionalLight3D
var rim: DirectionalLight3D
var sky_mat: ShaderMaterial
var ground: MeshInstance3D
var ground_mat: ShaderMaterial
var post_layer: CanvasLayer
var post_rect: ColorRect
var cam_attr: CameraAttributesPractical
var biome_img: Image
var biome_tex: ImageTexture
var detail_tex: ImageTexture
var road_mat: ShaderMaterial
var grass: Grass
var wildlife: Wildlife
var _d := {}
var _mood_asked := ""  # the Time of day setting as the battle began: changing it mid-battle switches the mood live


func setup(w: World) -> void:
	world = w
	mood = pick_mood(w.settings)
	_d = MOODS[mood]
	_mood_asked = String(Settings.get_v("mood"))
	_make_noise()
	_build_env()
	_build_ground()
	_build_post()
	grass = Grass.new()
	grass.name = "Grass"
	grass.atmo = self
	add_child(grass)
	grass.set_deform(deform_tex)
	wildlife = Wildlife.new()
	wildlife.name = "Wildlife"
	wildlife.world = world
	add_child(wildlife)
	Settings.changed.connect(apply_settings)
	apply_settings()
	if Sfx.enabled and world.has_view:
		_wind = Sfx.make_ambience("wind", WIND_DB.x)
		add_child(_wind)
		_rumble = Sfx.make_ambience("rumble", RUMBLE_DB.x)
		add_child(_rumble)
		Music.play_cue("battle")
	_setup_rain()


# --- noise textures shared by the ground shader and grass placement -------------

func _make_noise() -> void:
	var n := FastNoiseLite.new()
	n.seed = int(world.settings.get("seed", 1)) % 100000
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	biome_img = world.terrain.biome_img if world.terrain else n.get_seamless_image(512, 512, false, false, 0.1, true)
	biome_tex = ImageTexture.create_from_image(biome_img)
	var d := FastNoiseLite.new()
	d.seed = n.seed + 11
	d.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	d.frequency = 0.035
	d.fractal_type = FastNoiseLite.FRACTAL_FBM
	d.fractal_octaves = 5
	var di := d.get_seamless_image(256, 256, false, false, 0.1, true)
	di.generate_mipmaps()
	detail_tex = ImageTexture.create_from_image(di)


## 0..1 biome value at a world position (same data the ground shader uses).
func biome_at(p: Vector3) -> float:
	var u := int(floor(p.x + MapDims.BIOME * 0.5)) % MapDims.BIOME
	var v := int(floor(p.z + MapDims.BIOME * 0.5)) % MapDims.BIOME
	return biome_img.get_pixel(posmod(u, 512), posmod(v, 512)).r


func grass_amount(p: Vector3) -> float:
	var b := biome_at(p)
	return 1.0 - smoothstep(0.62, 0.74, b)


# --- environment ---------------------------------------------------------------------

func _build_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	sky_mat.shader = sh
	sky_mat.set_shader_parameter("zenith", _d.zenith)
	sky_mat.set_shader_parameter("horizon", _d.horizon)
	sky_mat.set_shader_parameter("ground_col", Color(0.24, 0.23, 0.2))
	sky_mat.set_shader_parameter("sun_col", _d.sun)
	sky_mat.set_shader_parameter("cloudiness", 1.0 if mood in ["overcast", "rain"] else 0.55)
	sky_mat.set_shader_parameter("stars", 1.0 if mood == "night" else 0.0)
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(_d.ambient)
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = float(_d.exposure)
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.6)
	env.set_glow_level(5, 0.4)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = _d.fog
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.12
	env.fog_density = float(_d.fog_d)
	env.fog_sky_affect = 0.35
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.ssil_radius = 6.0
	env.ssil_intensity = 0.9
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.25
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.4
	env.sdfgi_energy = 0.9
	env.volumetric_fog_density = 0.0011 if mood != "hazy" else 0.003
	env.volumetric_fog_albedo = (_d.fog as Color).lerp(Color(0.9, 0.9, 0.9), 0.55)
	env.volumetric_fog_anisotropy = 0.35
	env.volumetric_fog_length = 260.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.4
	env.volumetric_fog_sky_affect = 0.15
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.05 if mood in ["golden", "dusk", "dawn"] else 1.1
	we = WorldEnvironment.new()
	we.environment = env
	cam_attr = CameraAttributesPractical.new()
	we.camera_attributes = cam_attr
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-float(_d.elev), float(_d.azim), 0)
	sun.light_color = _d.sun
	sun.light_energy = float(_d.energy)
	sun.light_angular_distance = float(_d.soft)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.85
	sun.light_volumetric_fog_energy = 0.8
	add_child(sun)
	# cool fill from the opposite side so silhouettes read against the ground
	rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25.0, float(_d.azim) + 180.0, 0)
	rim.light_color = Color(0.6, 0.72, 0.95)
	rim.light_energy = 0.28 if mood != "overcast" else 0.12
	rim.shadow_enabled = false
	rim.light_specular = 0.3
	rim.light_volumetric_fog_energy = 0.0
	add_child(rim)


var trench_net: TrenchNet
var _blank_mask: ImageTexture


## Every shader that draws the ground surface skips the trench holes.
func set_trench_mask(t: Texture2D) -> void:
	for m in [ground_mat, road_mat]:
		if m:
			Mats.set_shared(m, &"trench_mask", t)
	Mats.set_ground_maps(null, t)
	if grass:
		grass.set_trench_mask(t)


var deform_tex: ImageTexture
var _deform_t := 0.0
const GROUND_HALF := MapDims.HALF + 8.0  # the fine, deformable ground covers the map; a ring of plain ground beyond
const GROUND_CHUNKS := int(GROUND_HALF * 2.0 / 33.0)  # about 33 m chunks, culled one by one
const GROUND_LOD := 170.0  # beyond this from the camera a chunk is drawn on a coarser grid


func _build_ground() -> void:
	_blank_mask = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_R8))
	ground = MeshInstance3D.new()
	ground.mesh = _ground_ring(GROUND_HALF, MapDims.HALF + 132.0)
	ground_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MapDims.shader(GROUND_SHADER)
	ground_mat.shader = sh
	ground_mat.set_shader_parameter("biome_tex", biome_tex)
	ground_mat.set_shader_parameter("detail_tex", detail_tex)
	ground_mat.set_shader_parameter("cloud_strength", float(_d.clouds))
	ground_mat.set_shader_parameter("sun_tint", _d.sun)
	ground_mat.set_shader_parameter("wet", 1.0 if mood == "rain" else 0.0)
	ground_mat.set_shader_parameter("trench_mask", _blank_mask)
	ground.material_override = ground_mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	# the battlefield itself: chunks of fine grid (culled one by one), all
	# sharing one mesh; the shader lifts or sinks each vertex to the ground height
	if world.terrain and world.terrain.deform_img:
		deform_tex = ImageTexture.create_from_image(world.terrain.deform_img)
	else:
		deform_tex = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RF))
	ground_mat.set_shader_parameter("deform_tex", deform_tex)
	Mats.set_ground_maps(deform_tex, null)
	var step := 0.5 if int(Settings.get_v("lod")) >= 1 else 1.0
	var cs := GROUND_HALF * 2.0 / GROUND_CHUNKS
	var cm := _grid_mesh(cs, step)
	# far off, a chunk is drawn on a 2 m grid (the craters there are specks)
	var cm_far := _grid_mesh(cs, maxf(step, 2.0))
	for cx in GROUND_CHUNKS:
		for cz in GROUND_CHUNKS:
			for far in [false, true]:
				var mi := MeshInstance3D.new()
				mi.mesh = cm_far if far else cm
				mi.material_override = ground_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.position = Vector3(-GROUND_HALF + (cx + 0.5) * cs, 0, -GROUND_HALF + (cz + 0.5) * cs)
				# room for the displacement in the culling box
				mi.extra_cull_margin = 2.0
				if far:
					mi.visibility_range_begin = GROUND_LOD
					mi.visibility_range_begin_margin = 8.0
				else:
					mi.visibility_range_end = GROUND_LOD
					mi.visibility_range_end_margin = 8.0
				add_child(mi)
	trench_net = TrenchNet.new(world)
	add_child(trench_net)
	trench_net.set_detail(detail_tex)
	road_mat = ShaderMaterial.new()
	var rs := Shader.new()
	rs.code = Mats.code(MapDims.shader(ROAD_SHADER))
	road_mat.shader = rs
	road_mat.set_shader_parameter("detail_tex", detail_tex)
	# see-through (its edges fade into the verges), so it draws with the smoke
	# and fire: before them, or it paints over every blast on a road
	road_mat.render_priority = -1
	road_mat.set_shader_parameter("trench_mask", _blank_mask)
	road_mat.set_shader_parameter("deform_tex", deform_tex)
	road_mat.set_shader_parameter("wet", 1.0 if mood == "rain" else 0.0)


func _build_post() -> void:
	post_layer = CanvasLayer.new()
	post_layer.layer = 1
	add_child(post_layer)
	post_rect = ColorRect.new()
	post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = POST_SHADER
	m.shader = sh
	post_rect.material = m
	post_layer.add_child(post_rect)


# --- rain: streaks around the camera, splashes, lightning and thunder ---------

var _rain: GeometryInstance3D  # (GPU or CPU particles: see Vfx.part)
var _splash: GeometryInstance3D
var _rain_snd: AudioStreamPlayer
var _bolt_t := 12.0
var _flash := 0.0
var _thunder_t := -1.0


func _setup_rain() -> void:
	var want := mood == "rain" and world.has_view
	if not want:
		if _rain:
			_rain.queue_free()
			_splash.queue_free()
			_rain = null
			_splash = null
		if _rain_snd:
			_rain_snd.queue_free()
			_rain_snd = null
		return
	if _rain:
		return
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(55, 1, 55)
	pm.direction = Vector3(0.12, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 26.0
	pm.initial_velocity_max = 32.0
	pm.gravity = Vector3.ZERO
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	var rain := GPUParticles3D.new()
	rain.amount = int(14000 * Settings.fx_mult())
	rain.lifetime = 1.6
	rain.preprocess = 1.6
	rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 1.2)
	rain.draw_pass_1 = q
	var rm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = RAIN_SHADER
	rm.shader = sh
	rain.material_override = rm
	rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	rain.local_coords = false
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.visibility_aabb = AABB(Vector3(-70, -60, -70), Vector3(140, 80, 140))
	if Vfx.gl:
		rain.amount = int(rain.amount * 0.35)  # (CPU particles in the browser: see Vfx.part)
	_rain = Vfx.part(rain)
	add_child(_rain)
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp.emission_box_extents = Vector3(40, 0.02, 40)
	sp.direction = Vector3.UP
	sp.spread = 40.0
	sp.initial_velocity_min = 0.6
	sp.initial_velocity_max = 1.4
	sp.gravity = Vector3(0, -9.8, 0)
	sp.scale_min = 0.6
	sp.scale_max = 1.2
	var splash := GPUParticles3D.new()
	splash.amount = int(2500 * Settings.fx_mult())
	splash.lifetime = 0.25
	splash.process_material = sp
	var sq := QuadMesh.new()
	sq.size = Vector2(0.08, 0.08)
	splash.draw_pass_1 = sq
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(0.8, 0.85, 0.9, 0.45)
	splash.material_override = smat
	splash.local_coords = false
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	splash.visibility_aabb = AABB(Vector3(-50, -2, -50), Vector3(100, 6, 100))
	if Vfx.gl:
		splash.amount = int(splash.amount * 0.35)
	_splash = Vfx.part(splash)
	add_child(_splash)
	if Sfx.enabled:
		_rain_snd = Sfx.make_ambience("rain", -11.0)
		add_child(_rain_snd)


func _rain_tick(dt: float) -> void:
	var f := world.cam.focus_pos
	_rain.global_position = Vector3(f.x, 34.0, f.z)
	_splash.global_position = Vector3(f.x, 0.05, f.z)
	# lightning: a double flash lighting the clouds, thunder a moment later
	_bolt_t -= dt
	if _bolt_t <= 0.0:
		_bolt_t = randf_range(14.0, 38.0)
		_flash = 1.0
		_thunder_t = randf_range(0.6, 2.8)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 4.0)
		var k := _flash * (0.6 + 0.4 * sin(_flash * 40.0))
		sun.light_energy = float(_d.energy) + k * 3.5
		env.background_energy_multiplier = 1.0 + k * 2.5
	elif sun.light_energy != float(_d.energy):
		sun.light_energy = float(_d.energy)
		env.background_energy_multiplier = 1.0
	if _thunder_t > 0.0:
		_thunder_t -= dt
		if _thunder_t <= 0.0 and world.cam:
			Sfx.play("thunder", world.cam.cam.global_position + Vector3(randf_range(-40, 40), 30, randf_range(-40, 40)), 6.0, 1.0, &"Ambience")


const RAIN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float a = (1.0 - x) * smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.6, UV.y);
	ALBEDO = vec3(0.7, 0.75, 0.82) * a * 0.9;
	ALPHA = a * 0.7;
}
"""


# --- night: illumination flares drifting down over the fighting ----------------

var _flare_t := 3.0
var _flares: Array = []  # [root, light, age, life]


func _flares_tick(dt: float) -> void:
	_flare_t -= dt
	if _flare_t <= 0.0 and _flares.size() < 3:
		_flare_t = randf_range(5.0, 11.0)
		var p := world.cam.focus_pos
		if world.director and not world.director.hot.is_empty():
			var now := Time.get_ticks_msec() / 1000.0
			var recent := []
			for h in world.director.hot:
				if now - float(h[2]) < 25.0:
					recent.append(h[0])
			if not recent.is_empty():
				p = recent[randi() % recent.size()]
		_spawn_flare(p + Vector3(randf_range(-25, 25), 0, randf_range(-25, 25)))
	for i in range(_flares.size() - 1, -1, -1):
		var f: Array = _flares[i]
		f[2] += dt
		var root: Node3D = f[0]
		var age: float = f[2]
		var life: float = f[3]
		root.position.y = maxf(6.0, root.position.y - dt * 1.3)
		root.position.x += sin(age * 0.7) * dt * 0.8
		var fade := clampf((life - age) / 3.0, 0.0, 1.0) * clampf(age * 2.0, 0.0, 1.0)
		var l: OmniLight3D = f[1]
		l.light_energy = fade * (7.0 + 1.0 * sin(age * 23.0) + 0.6 * sin(age * 37.0))
		(f[4] as MeshInstance3D).scale = Vector3.ONE * (1.6 + 0.2 * sin(age * 31.0)) * fade
		if age > life:
			root.queue_free()
			_flares.remove_at(i)


func _spawn_flare(p: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(p.x, 36.0, p.z)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.86, 0.62)
	l.omni_range = 70.0
	l.omni_attenuation = 0.9
	l.light_energy = 0.0
	l.shadow_enabled = _flares.size() < 2 and int(Settings.get_v("shadows")) >= 2
	l.light_volumetric_fog_energy = 2.0
	root.add_child(l)
	var glow := MeshInstance3D.new()
	glow.mesh = world.fx.vfx.quad if world.fx and world.fx.vfx else QuadMesh.new()
	glow.material_override = world.fx.vfx.flash_mat if world.fx and world.fx.vfx else null
	Mats.set_inst(glow, &"rays", 0.5)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	var chute := MeshInstance3D.new()
	chute.mesh = Res.sphere(0.9, 10)
	chute.material_override = Mats.get_mat("canvas_white")
	chute.scale = Vector3(1, 0.45, 1)
	chute.position = Vector3(0, 2.4, 0)
	root.add_child(chute)
	if world.fx and world.fx.vfx:
		var tr := world.fx.vfx.make_trail()
		Vfx.set_ratio(tr, 0.5)
		root.add_child(tr)
	_flares.append([root, l, 0.0, randf_range(20.0, 26.0), glow])


## Switches the lighting mood live (Settings > Time of day).
func apply_mood(m: String) -> void:
	if not MOODS.has(m):
		return
	mood = m
	_d = MOODS[m]
	sky_mat.set_shader_parameter("zenith", _d.zenith)
	sky_mat.set_shader_parameter("horizon", _d.horizon)
	sky_mat.set_shader_parameter("sun_col", _d.sun)
	sky_mat.set_shader_parameter("cloudiness", 1.0 if mood in ["overcast", "rain"] else 0.55)
	sky_mat.set_shader_parameter("stars", 1.0 if mood == "night" else 0.0)
	env.ambient_light_energy = float(_d.ambient)
	ground_mat.set_shader_parameter("wet", 1.0 if mood == "rain" else 0.0)
	Mats.set_shared(road_mat, &"wet", 1.0 if mood == "rain" else 0.0)
	_setup_rain()
	env.tonemap_exposure = float(_d.exposure) * float(Settings.get_v("brightness"))
	env.fog_light_color = _d.fog
	env.fog_density = float(_d.fog_d)
	env.volumetric_fog_albedo = (_d.fog as Color).lerp(Color(0.9, 0.9, 0.9), 0.55)
	_apply_look()
	sun.rotation_degrees = Vector3(-float(_d.elev), float(_d.azim), 0)
	sun.light_color = _d.sun
	sun.light_energy = float(_d.energy)
	rim.rotation_degrees = Vector3(-25.0, float(_d.azim) + 180.0, 0)
	rim.light_energy = 0.28 if mood != "overcast" else 0.12
	ground_mat.set_shader_parameter("cloud_strength", float(_d.clouds))
	ground_mat.set_shader_parameter("sun_tint", _d.sun)
	if water_view:
		water_view.apply_mood(_d, mood)
	if world.fx and world.fx.vfx:
		world.fx.vfx.apply_lighting()


func apply_settings() -> void:
	var s := Settings
	# the battle's own mood stands (the host's choice, or a mission's) until
	# the player changes the setting while it's on
	var want := String(s.get_v("mood"))
	if want != _mood_asked:
		_mood_asked = want
		if MOODS.has(want) and want != mood:
			apply_mood(want)
	env.ssao_enabled = s.get_v("ssao")
	env.ssr_enabled = s.get_v("ssr")
	env.ssr_max_steps = 48 if int(s.get_v("ao_q")) >= 2 else 24
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.4
	env.tonemap_mode = [Environment.TONE_MAPPER_AGX, Environment.TONE_MAPPER_ACES, Environment.TONE_MAPPER_FILMIC, Environment.TONE_MAPPER_REINHARDT][clampi(int(s.get_v("tonemap")), 0, 3)]
	env.tonemap_exposure = float(_d.exposure) * float(s.get_v("brightness"))
	_apply_look()
	if world.cam and world.cam.cam:
		world.cam.cam.fov = clampf(float(s.get_v("fov")), 35.0, 75.0)
		world.cam.edge_pan = bool(s.get_v("edge_pan"))
	env.ssil_enabled = s.get_v("ssil")
	env.sdfgi_enabled = s.get_v("gi")
	env.volumetric_fog_enabled = s.get_v("vol_fog")
	env.glow_enabled = s.get_v("glow")
	var sh := int(s.get_v("shadows"))
	sun.shadow_enabled = sh > 0
	match sh:
		1:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 140.0
			sun.light_angular_distance = 0.0
		2:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = 220.0
			sun.light_angular_distance = minf(float(_d.soft), 1.0)
		3:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = 260.0
			sun.light_angular_distance = float(_d.soft)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		[RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][sh])
	RenderingServer.environment_set_volumetric_fog_volume_size(128 if sh >= 3 else 96, 96 if sh >= 3 else 64)
	post_layer.visible = s.get_v("post")
	cam_attr.dof_blur_far_enabled = s.get_v("dof")
	cam_attr.dof_blur_near_enabled = s.get_v("dof")
	cam_attr.dof_blur_amount = 0.06
	if grass:
		grass.apply_settings()
	if wildlife:
		wildlife.apply_settings()


## Colour grading: the chosen look on top of the time of day, plus the
## player's contrast slider.
func _apply_look() -> void:
	var lk: Array = Settings.LOOKS[clampi(int(Settings.get_v("look")), 0, Settings.LOOKS.size() - 1)]
	env.adjustment_enabled = true
	env.adjustment_brightness = float(lk[0])
	env.adjustment_contrast = float(lk[1]) * float(Settings.get_v("contrast"))
	var sat := float(lk[2])
	if int(Settings.get_v("look")) == 0:
		sat = 1.05 if mood in ["golden", "dusk", "dawn"] else 1.1
	env.adjustment_saturation = sat
	if post_rect and post_rect.material:
		(post_rect.material as ShaderMaterial).set_shader_parameter("tint", lk[3])


func _process(_dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(_dt)
	if world:
		world.vp("atmosphere", _t0)


## Ambience levels (dB): wind from close in to zoomed right out; the distant
## battle from a lull to the thick of it.
const WIND_DB := Vector2(-19.0, -15.0)
const RUMBLE_DB := Vector2(-14.0, -6.0)

var _wind: AudioStreamPlayer
var _rumble: AudioStreamPlayer
var _activity := 0.0


func _view_process(_dt: float) -> void:
	_update_deform(_dt)
	if world.cam == null:
		return
	if _wind:
		var z := clampf((world.cam.dist - 15.0) / 60.0, 0.0, 1.0)
		_wind.volume_db = lerpf(WIND_DB.x, WIND_DB.y, z)
		var act := 0.0
		if world.director:
			var now := Time.get_ticks_msec() / 1000.0
			for i in range(world.director.hot.size() - 1, maxi(-1, world.director.hot.size() - 60), -1):
				var h: Array = world.director.hot[i]
				if now - float(h[2]) < 8.0:
					act += float(h[1])
		_activity = lerpf(_activity, clampf(act / 12.0, 0.0, 1.0), 1.0 - exp(-_dt * 0.8))
		_rumble.volume_db = lerpf(RUMBLE_DB.x, RUMBLE_DB.y, _activity)
		Music.heat = _activity
	if mood == "night":
		_flares_tick(_dt / maxf(0.0001, Engine.time_scale) if Engine.time_scale > 0.001 else 0.0)
	if _rain:
		_rain_tick(_dt / maxf(0.0001, Engine.time_scale) if Engine.time_scale > 0.001 else 0.016)
	# the camera climbs as it zooms out: thin the fog so the battlefield stays crisp
	var fk := clampf(45.0 / maxf(10.0, world.cam.dist), 0.35, 1.0)
	env.fog_density = float(_d.fog_d) * fk
	env.volumetric_fog_density = (0.0011 if mood != "hazy" else 0.003) * fk
	if not Settings.get_v("dof"):
		return
	# gentle tilt-shift: keep the focus plane at the camera's target
	var d := world.cam.dist
	cam_attr.dof_blur_far_distance = d * 1.35
	cam_attr.dof_blur_far_transition = d * 0.9
	cam_attr.dof_blur_near_distance = d * 0.55
	cam_attr.dof_blur_near_transition = d * 0.3


## Builds the road strip mesh for a team (called by World when roads change).
func set_town(r: Rect2) -> void:
	Mats.set_shared(road_mat, &"town", Vector4(r.position.x, r.position.y, r.end.x, r.end.y))


## A square of ground `size` across in quads of `step` metres, centred on its origin.
func _grid_mesh(size: float, step: float) -> ArrayMesh:
	var n := int(round(size / step))
	var v := PackedVector3Array()
	var nr := PackedVector3Array()
	var idx := PackedInt32Array()
	v.resize((n + 1) * (n + 1))
	nr.resize((n + 1) * (n + 1))
	for z in n + 1:
		for x in n + 1:
			v[z * (n + 1) + x] = Vector3(-size * 0.5 + x * step, 0, -size * 0.5 + z * step)
			nr[z * (n + 1) + x] = Vector3.UP
	idx.resize(n * n * 6)
	var k := 0
	for z in n:
		for x in n:
			var a := z * (n + 1) + x
			var b := a + 1
			var c := a + (n + 1)
			var d := c + 1
			idx[k] = a
			idx[k + 1] = b
			idx[k + 2] = c
			idx[k + 3] = b
			idx[k + 4] = d
			idx[k + 5] = c
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Flat ground outside the battlefield: a square ring around it.
func _ground_ring(inner: float, outer: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rects := [Rect2(-outer, -outer, outer * 2.0, outer - inner), Rect2(-outer, inner, outer * 2.0, outer - inner),
		Rect2(-outer, -inner, outer - inner, inner * 2.0), Rect2(inner, -inner, outer - inner, inner * 2.0)]
	for r in rects:
		var a := Vector3(r.position.x, 0, r.position.y)
		var b := Vector3(r.end.x, 0, r.position.y)
		var c := Vector3(r.end.x, 0, r.end.y)
		var d := Vector3(r.position.x, 0, r.end.y)
		for p in [a, b, c, a, c, d]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	return st.commit()


# --- water ---------------------------------------------------------------------------

var water_view: WaterView
var water_tex: ImageTexture


## The surface of the rivers, ponds and sea (see WaterView), and the shores on
## the ground.
func build_water(w: WaterMap) -> void:
	if w.mask == null:
		return
	water_tex = ImageTexture.create_from_image(w.mask)
	var sea_x: float = (float(w.coast.x) + 30.0) if not w.coast.is_empty() else 1e9
	ground_mat.set_shader_parameter("water_mask", water_tex)
	ground_mat.set_shader_parameter("sea_x", sea_x)
	if water_view == null:
		water_view = WaterView.new(world)
		add_child(water_view)
	water_view.build(w, detail_tex)
	water_view.apply_mood(_d, mood)
	if grass:
		grass.request_rebuild(0.5)


## New shell holes go up to the GPU (a few times a second at most).
func _update_deform(dt: float) -> void:
	_deform_t -= dt
	var tm = world.terrain
	if tm == null or tm.deform_img == null or tm.deform_dirty.size == Vector2i.ZERO or _deform_t > 0.0:
		return
	_deform_t = 0.22
	deform_tex.update(tm.deform_img)
	if world.phys:
		world.phys.update_deform(tm.deform_dirty)
	tm.deform_dirty = Rect2i()


func make_road_mesh(polys: Array, team: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 2.9 if team == 2 else 2.4
	var y := Vector3(0, 0.02 if team == 2 else 0.026 + team * 0.004, 0)
	for poly in polys:
		var src: PackedVector3Array = poly
		# drop near-duplicate points
		var pts := PackedVector3Array()
		for p in src:
			if pts.is_empty() or Defs.flat(p - pts[pts.size() - 1]).length() > 0.3:
				pts.append(Vector3(p.x, 0, p.z))
		if pts.size() < 2:
			continue
		# one continuous strip with mitred joints (no gaps or spikes on curves)
		var lefts := PackedVector3Array()
		var rights := PackedVector3Array()
		var vs := PackedFloat32Array()
		var along := 0.0
		for i in pts.size():
			var d_in := (pts[i] - pts[maxi(i - 1, 0)]).normalized() if i > 0 else (pts[1] - pts[0]).normalized()
			var d_out := (pts[mini(i + 1, pts.size() - 1)] - pts[i]).normalized() if i < pts.size() - 1 else d_in
			var tang := (d_in + d_out).normalized()
			if tang.length() < 0.01:
				tang = d_out
			var side := tang.cross(Vector3.UP).normalized()
			var miter := 1.0 / maxf(0.5, side.dot(d_out.cross(Vector3.UP).normalized()))
			if i > 0:
				along += Defs.flat(pts[i] - pts[i - 1]).length()
			lefts.append(pts[i] - side * hw * miter + y)
			rights.append(pts[i] + side * hw * miter + y)
			vs.append(along)
		for i in pts.size() - 1:
			var q := [lefts[i], rights[i], rights[i + 1], lefts[i + 1]]
			var uv := [Vector2(0, vs[i]), Vector2(1, vs[i]), Vector2(1, vs[i + 1]), Vector2(0, vs[i + 1])]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_normal(Vector3.UP)
				st.set_uv(uv[idx])
				st.add_vertex(q[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = road_mat
	Mats.set_inst(mi, &"country", 1.0 if team == 2 else 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


const SKY_SHADER := """
shader_type sky;
uniform vec3 zenith : source_color;
uniform vec3 horizon : source_color;
uniform vec3 ground_col : source_color;
uniform vec3 sun_col : source_color;
uniform float cloudiness = 0.5;
uniform float stars = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; } return v; }

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), 0.5));
	if (h < 0.0) {
		col = mix(horizon * 0.9, ground_col, clamp(-h * 3.0, 0.0, 1.0));
	}
	vec3 L = LIGHT0_DIRECTION;
	float sd = max(dot(d, L), 0.0);
	col += sun_col * (pow(sd, 1200.0) * 40.0 + pow(sd, 18.0) * 0.45 + pow(sd, 3.0) * 0.12);
	if (h > 0.0 && stars > 0.0) {
		vec3 sd3 = normalize(d) * 420.0;
		vec3 cell = floor(sd3);
		float sh = hash(cell.xy + cell.z * 17.13);
		vec3 fp = fract(sd3) - 0.5;
		float star = step(0.985, sh) * smoothstep(0.32, 0.0, length(fp));
		float tw = 0.6 + 0.4 * sin(TIME * (2.0 + sh * 5.0) + sh * 40.0);
		col += vec3(0.85, 0.9, 1.0) * star * tw * stars * 3.0 * smoothstep(0.0, 0.25, h);
		float band = fbm(vec2(d.x * 3.0 + d.z, d.y * 6.0) * 2.0);
		col += vec3(0.04, 0.05, 0.08) * smoothstep(0.55, 0.9, band) * stars * smoothstep(0.1, 0.5, h);
	}
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.18) * 1.2;
		float c = fbm(uv * 1.6);
		c = smoothstep(1.0 - cloudiness - 0.15, 1.0 - cloudiness + 0.35, c) * smoothstep(0.0, 0.2, h);
		vec3 cl = mix(horizon * 0.95, vec3(1.0), 0.55) * (0.75 + 0.5 * sd);
		cl = mix(cl, sun_col, 0.18 * sd);
		col = mix(col, cl, c * 0.85);
	}
	COLOR = col;
}
"""

const GROUND_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;

uniform sampler2D biome_tex : filter_linear, repeat_enable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 grass_a : source_color = vec3(0.14, 0.2, 0.07);
uniform vec3 grass_b : source_color = vec3(0.24, 0.29, 0.1);
uniform vec3 dry : source_color = vec3(0.36, 0.33, 0.19);
uniform vec3 dirt : source_color = vec3(0.3, 0.26, 0.2);
uniform vec3 mud : source_color = vec3(0.19, 0.16, 0.12);
uniform vec3 sun_tint : source_color = vec3(1.0);
uniform float cloud_strength = 0.3;
uniform float bump = 1.4;
uniform float wet = 0.0;
uniform sampler2D trench_mask : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D deform_tex : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D water_mask : hint_default_transparent, filter_linear, repeat_disable;
uniform float sea_x = 1e9;

varying vec3 wpos;
varying float puddle;

float dfm(vec2 p) {
	return textureLod(deform_tex, (p + __MAP_HALF__) / __MAP_SIZE__, 0.0).r;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (abs(wpos.x) < __MAP_HALF__ && abs(wpos.z) < __MAP_HALF__) {
		float d = dfm(wpos.xz);
		VERTEX.y += d;
		wpos.y += d;
	} else if (wpos.x > sea_x) {
		// past the edge of the map the sea runs on to the horizon
		float d = -3.2 * smoothstep(sea_x, sea_x + 30.0, wpos.x);
		VERTEX.y += d;
		wpos.y += d;
	}
}

float hgt(vec2 p) {
	return texture(detail_tex, p / 9.0).r * 0.6 + texture(detail_tex, p / 2.3 + 0.31).r * 0.4;
}

void fragment() {
	vec2 p = wpos.xz;
	if (texture(trench_mask, (p + __MAP_HALF__) / __MAP_SIZE__).r > 0.5) {
		discard;
	}
	float b = texture(biome_tex, (p + __BIOME_HALF__) / __BIOME__).r;
	float d1 = texture(detail_tex, p / 41.0).r;
	float d2 = texture(detail_tex, p / 7.0 + 0.37).r;
	float d3 = texture(detail_tex, p / 1.7 + 0.71).r;
	float dirt_m = smoothstep(0.62, 0.74, b + (d1 - 0.5) * 0.18);
	float dry_m = smoothstep(0.42, 0.66, d1 * 0.55 + b * 0.55);
	vec3 grass = mix(grass_a, grass_b, smoothstep(0.25, 0.75, d2));
	vec3 col = mix(grass, dry, dry_m * 0.7);
	vec3 soil = mix(dirt, mud, smoothstep(0.3, 0.8, d1) * 0.6);
	soil *= 0.9 + 0.2 * d2;
	col = mix(col, soil, dirt_m);
	col *= 0.9 + 0.2 * d3;
	float edge = max(abs(p.x), abs(p.y));
	col *= mix(1.0, 0.45, smoothstep(__MAP_HALF__, __MAP_HALF__ + 22.0, edge));
	puddle = wet * smoothstep(0.6, 0.66, d1 * 0.7 + d2 * 0.3 + dirt_m * 0.12);
	col *= 1.0 - wet * 0.3;
	col = mix(col, col * 0.35 + vec3(0.01, 0.012, 0.015), puddle);
	// the shore: sand along the sea, a muddy bank along fresh water, the
	// bed darker and wet under the water
	vec4 wm = texture(water_mask, (p + __MAP_HALF__) / __MAP_SIZE__);
	if (abs(p.x) >= __MAP_HALF__ || abs(p.y) >= __MAP_HALF__) {
		wm = p.x > sea_x ? vec4(1.0, 1.0, 1.0, 1.0) : vec4(0.0);
	}
	// (linear colours, like the rest: pale sand, dark wet mud)
	vec3 sand = vec3(0.38, 0.31, 0.19) * (0.88 + 0.24 * d2) * (0.92 + 0.16 * d3);
	vec3 bank = mix(vec3(0.032, 0.025, 0.016), vec3(0.06, 0.047, 0.03), d3) * (0.9 + 0.2 * d2);
	vec3 shore_col = mix(bank, sand, wm.b);
	col = mix(col, shore_col, smoothstep(0.0, 0.7, wm.g));
	// the sand the surf runs over stays dark and wet
	float wet_sand = smoothstep(0.5, 0.92, wm.g) * wm.b * (1.0 - wm.a);
	col *= 1.0 - wet_sand * (0.38 + 0.08 * d3);
	// (the water over it darkens the sea's sand as it deepens: see WaterView)
	col = mix(col, shore_col * mix(0.5, 0.85, wm.b), wm.a);
	// shell holes: churned dark earth in the bowl, dry thrown soil on the rim
	float hd = dfm(p);
	float bowl = smoothstep(-0.03, -0.35, hd) * (1.0 - wm.g);
	float lip = smoothstep(0.02, 0.12, hd) * (1.0 - wm.g);
	// (linear colours: freshly turned earth is dark, the bottom blackened)
	vec3 churn = mix(vec3(0.042, 0.032, 0.023), vec3(0.075, 0.056, 0.038), d3) * (0.85 + 0.3 * d2);
	col = mix(col, churn, clamp(bowl * 1.1, 0.0, 1.0));
	col = mix(col, vec3(0.018, 0.016, 0.014), smoothstep(-0.3, -0.75, hd) * 0.55);
	col = mix(col, mix(dirt, vec3(0.085, 0.066, 0.047), 0.6) * (0.85 + 0.3 * d3), lip * 0.75);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.96, 0.82, dirt_m), 0.55, wet * 0.5);
	ROUGHNESS = mix(ROUGHNESS, 0.45, max(wm.a * 0.8, wet_sand * 0.6));
	ROUGHNESS = mix(ROUGHNESS, 0.16, puddle);
	SPECULAR = mix(0.25, 0.38, wet);
	float e = 0.12;
	float hc = hgt(p);
	float hx = hgt(p + vec2(e, 0.0));
	float hz = hgt(p + vec2(0.0, e));
	float bm = bump * mix(0.6, 1.4, dirt_m) * (1.0 + bowl * 1.5);
	vec3 n = normalize(vec3((hc - hx) * bm / e * 0.1, 1.0, (hc - hz) * bm / e * 0.1));
	// the crater's own slopes
	float de = 0.25;
	float gx = (dfm(p + vec2(de, 0.0)) - dfm(p - vec2(de, 0.0))) / (2.0 * de);
	float gz = (dfm(p + vec2(0.0, de)) - dfm(p - vec2(0.0, de))) / (2.0 * de);
	n = normalize(n + vec3(-gx, 0.0, -gz));
	n = normalize(mix(n, vec3(0.0, 1.0, 0.0), puddle * 0.9));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}

void light() {
	float cloud = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		vec2 cp = wpos.xz / 512.0 * 1.7 + vec2(TIME * 0.0016, TIME * 0.0007);
		float c = texture(biome_tex, cp).r;
		cloud = 1.0 - cloud_strength * smoothstep(0.48, 0.72, c);
	}
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR / PI * cloud;
	if (wet > 0.0) {
		vec3 hv = normalize(LIGHT + VIEW);
		float sp = pow(clamp(dot(NORMAL, hv), 0.0, 1.0), mix(16.0, 60.0, puddle));
		SPECULAR_LIGHT += sp * ATTENUATION * LIGHT_COLOR * wet * (0.03 + puddle * 0.2) * cloud;
	}
}
"""

const ROAD_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, specular_schlick_ggx;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform float wet = 0.0;
uniform sampler2D trench_mask : hint_default_black, filter_linear, repeat_disable;
uniform vec4 town = vec4(0.0);  // min x, min z, max x, max z: streets here are asphalt
uniform sampler2D deform_tex : hint_default_black, filter_linear, repeat_disable;
instance uniform float country = 0.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	if (texture(trench_mask, (wpos.xz + __MAP_HALF__) / __MAP_SIZE__).r > 0.5) {
		discard;
	}
	// a shell hole punches through the road surface
	if (texture(deform_tex, (wpos.xz + __MAP_HALF__) / __MAP_SIZE__).r < -0.07) {
		discard;
	}
	float x = UV.x;
	float n = texture(detail_tex, wpos.xz / 3.0).r;
	float n2 = texture(detail_tex, wpos.xz / 11.0 + 0.5).r;
	float n3 = texture(detail_tex, wpos.xz / 0.6 + 0.2).r;
	float ruts = smoothstep(0.075, 0.0, abs(x - 0.3)) + smoothstep(0.075, 0.0, abs(x - 0.7));
	vec3 gravel = mix(vec3(0.15, 0.135, 0.11), vec3(0.1, 0.09, 0.072), n);
	vec3 dirt = mix(vec3(0.14, 0.11, 0.075), vec3(0.09, 0.07, 0.048), n);
	vec3 col = mix(dirt, gravel, country);
	float peb = smoothstep(0.6, 0.72, n3);
	col = mix(col, col * 1.25 + 0.02, peb * (0.25 + 0.3 * country));
	col = mix(col, col * 0.58, ruts * 0.75);
	// grass down the middle and at the verges
	float mid = smoothstep(0.11, 0.0, abs(x - 0.5)) * country;
	float verge = 1.0 - smoothstep(0.06, 0.2, min(x, 1.0 - x));
	float grass = clamp(mid * (0.55 + 0.6 * n2) + verge * (0.45 + 0.9 * (n2 - 0.5)), 0.0, 1.0);
	col = mix(col, vec3(0.085, 0.11, 0.04) * (0.8 + 0.4 * n), grass * 0.85);
	col *= 0.88 + 0.24 * n2;
	float pud = wet * smoothstep(0.5, 0.7, ruts * 0.7 + n2 * 0.55);
	col *= 1.0 - wet * 0.22;
	col = mix(col, col * 0.4, pud);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.75, ruts * 0.5), 0.1, pud);
	SPECULAR = mix(0.12, 0.45, pud);
	float edge = smoothstep(0.0, 0.14 + 0.1 * n, x) * smoothstep(1.0, 0.86 - 0.1 * n, x);
	ALPHA = edge;
	// in town: patched asphalt between the curbs, a dashed centre line
	float paved = step(town.x, wpos.x) * step(wpos.x, town.z) * step(town.y, wpos.z) * step(wpos.z, town.w) * country;
	if (paved > 0.5) {
		vec3 asph = vec3(0.085, 0.085, 0.082) * (0.82 + 0.36 * n) * (0.9 + 0.2 * n2);
		float rpx = max(length(fwidth(wpos.xz)), 1e-4);
		float crack = smoothstep(0.018, 0.0, abs(n3 - 0.5)) * smoothstep(0.45, 0.6, n2) * smoothstep(1.5, 5.0, 0.3 / rpx);
		asph = mix(asph, asph * 0.5, crack);
		float patch = smoothstep(0.64, 0.67, texture(detail_tex, wpos.xz / 7.0 + 0.3).r);
		asph = mix(asph, asph * 0.72 + vec3(0.004), patch * 0.7);
		float dash = step(abs(x - 0.5), 0.011) * step(fract(UV.y / 7.0), 0.5);
		asph = mix(asph, vec3(0.78, 0.74, 0.6) * (0.75 + 0.25 * n), dash * 0.8);
		float wear = smoothstep(0.08, 0.0, abs(x - 0.27)) + smoothstep(0.08, 0.0, abs(x - 0.73));
		asph = mix(asph, asph * 0.85, wear * 0.4);
		float pud2 = wet * smoothstep(0.55, 0.75, n2 * 0.8 + crack);
		asph *= 1.0 - wet * 0.3;
		ALBEDO = mix(asph, asph * 0.4, pud2);
		ROUGHNESS = mix(0.82 - wet * 0.3, 0.06, pud2);
		SPECULAR = mix(0.3, 0.55, pud2);
		ALPHA = 1.0;
	}
}
"""

const POST_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.32;
uniform float grain = 0.022;
uniform float fringe = 0.0012;
uniform vec3 tint = vec3(1.0);
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c);
	vec3 col;
	col.r = texture(screen_tex, uv + c * fringe * r * 2.0).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * fringe * r * 2.0).b;
	col *= tint;
	col *= 1.0 - vignette * smoothstep(0.35, 0.95, r);
	float n = fract(sin(dot(uv * vec2(1931.0, 1087.0) + fract(TIME * 7.13) * 91.7, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
"""
