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

# Atmospheric haze is scenery, not concealment. Keep its optical depth low at
# the command camera's focus, even when the player zooms all the way out.
# Fog of war and combat smoke have their own, unchanged gameplay rules.
const HAZE_STRENGTH := 0.25
const VOLUME_STRENGTH := 0.15
const HAZE_DISTANCE := 32.0

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
var _photo_sky: ShaderMaterial
var ground: MeshInstance3D
var ground_mat: ShaderMaterial
var post_layer: CanvasLayer
var post_rect: ColorRect
var cam_attr: CameraAttributesPractical
var biome_img: Image
var biome_tex: ImageTexture
var detail_tex: ImageTexture
var backdrop_tex: ImageTexture
var road_mat: ShaderMaterial
var grass: Grass
var mountain_clouds: Node3D
var forest: DistantForest
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
	mountain_clouds = preload("res://scripts/game/mountain_clouds.gd").new()
	add_child(mountain_clouds)
	mountain_clouds.setup(self)
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
	backdrop_tex = ImageTexture.create_from_image(backdrop_image(n.seed))


## Surveyed ridge groups are composed around the battle with gaps between their massifs.
static func backdrop_image(seed_value: int) -> Image:
	var forms: Resource = preload("res://assets/terrain/surveyed_alps.res")
	var names := ["mont_blanc", "matterhorn", "jungfrau"]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1907
	var massifs: Array[Dictionary] = []
	var count := rng.randi_range(5, 7)
	var phase := rng.randf() * TAU
	for i in count:
		var angle := phase + float(i) * TAU / count + rng.randf_range(-0.15, 0.15)
		var radius := rng.randf_range(700.0, 1100.0)
		var direction := Vector2(cos(angle), sin(angle))
		var reach := (MapDims.HALF + rng.randf_range(650.0, 1050.0)) / maxf(absf(direction.x), absf(direction.y))
		massifs.append({"center": direction * reach, "radius": radius, "angle": rng.randf() * TAU,
			"height": rng.randf_range(240.0, 370.0), "data": forms.get_meta(names[rng.randi_range(0, 2)])})
	# Lower overlapping ranges close the horizon without joining the main peaks into a wall.
	for i in 10:
		var angle := phase + (float(i) + 0.5) * TAU / 10.0
		var direction := Vector2(cos(angle), sin(angle))
		var reach := (MapDims.HALF + 1450.0) / maxf(absf(direction.x), absf(direction.y))
		massifs.append({"center": direction * reach, "radius": rng.randf_range(600.0, 950.0), "angle": rng.randf() * TAU,
			"height": rng.randf_range(100.0, 190.0), "data": forms.get_meta(names[rng.randi_range(0, 2)])})
	var noise := FastNoiseLite.new()
	noise.seed = seed_value + 1907
	noise.frequency = 0.025
	var values := PackedFloat32Array()
	values.resize(512 * 512)
	var span := MapDims.SIZE + 3600.0
	var origin := Vector2.ONE * (MapDims.HALF + 1800.0)
	# Touch only each stamp's footprint, rather than testing every mountain at every pixel.
	for massif: Dictionary in massifs:
		var center: Vector2 = massif.center
		var radius: float = massif.radius
		var angle: float = massif.angle
		var amplitude: float = massif.height
		var data: PackedFloat32Array = massif.data
		var lo := Vector2i(((center - Vector2.ONE * radius + origin) / span * 512.0).floor()).clamp(Vector2i.ZERO, Vector2i(511, 511))
		var hi := Vector2i(((center + Vector2.ONE * radius + origin) / span * 512.0).ceil()).clamp(Vector2i.ZERO, Vector2i(511, 511))
		for z in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var p := (Vector2(x, z) + Vector2.ONE * 0.5) / 512.0 * span - origin
				var q := ((p - center) / radius).rotated(angle)
				if q.length_squared() >= 1.0:
					continue
				var uv := (q * 0.5 + Vector2.ONE * 0.5) * 511.0
				var sx := int(uv.x)
				var sz := int(uv.y)
				var h := lerpf(lerpf(data[sz * 512 + sx], data[sz * 512 + sx + 1], uv.x - sx),
					lerpf(data[(sz + 1) * 512 + sx], data[(sz + 1) * 512 + sx + 1], uv.x - sx), uv.y - sz) * amplitude
				values[z * 512 + x] += h * h * h * h
	for z in 512:
		for x in 512:
			var h := clampf((pow(values[z * 512 + x], 0.25) + (noise.get_noise_2d(x, z) * 0.5 + 0.5) * 18.0) / 440.0, 0.0, 1.0)
			# Invert the shader's elevation curve to preserve the surveyed ridge profiles.
			var curved := pow(h, 1.0 / 2.2)
			values[z * 512 + x] = 0.18 + 0.70 * (0.5 - sin(asin(1.0 - 2.0 * curved) / 3.0))
	var img := Image.create_from_data(512, 512, false, Image.FORMAT_RF, values.to_byte_array())
	var catchment: Image = img.duplicate()
	catchment.resize(256, 256, Image.INTERPOLATE_BILINEAR)
	var elevations := catchment.get_data().to_float32_array()
	for i in elevations.size():
		elevations[i] = pow(smoothstep(0.18, 0.88, elevations[i]), 2.2) * 440.0
	var drainage := Landform.bake_drainage(elevations, 256, 4.0)
	catchment = Image.create_from_data(256, 256, false, Image.FORMAT_RF, drainage.to_byte_array())
	catchment.resize(512, 512, Image.INTERPOLATE_BILINEAR)
	drainage = catchment.get_data().to_float32_array()
	var packed := PackedFloat32Array()
	packed.resize(values.size() * 2)
	for i in values.size():
		packed[i * 2] = values[i]
		packed[i * 2 + 1] = drainage[i]
	img = Image.create_from_data(512, 512, false, Image.FORMAT_RGF, packed.to_byte_array())
	img.generate_mipmaps()
	return img


## 0..1 biome value at a world position (same data the ground shader uses).
func biome_at(p: Vector3) -> float:
	var u := int(floor(p.x + MapDims.BIOME * 0.5)) % MapDims.BIOME
	var v := int(floor(p.z + MapDims.BIOME * 0.5)) % MapDims.BIOME
	return biome_img.get_pixel(posmod(u, biome_img.get_width()), posmod(v, biome_img.get_height())).r


func grass_amount(p: Vector3) -> float:
	var habitat := 1.0
	if world.terrain.landform.peak > 1.0:
		var height := world.terrain.landform.height(p)
		var peak := world.terrain.landform.peak
		habitat *= 1.0 - smoothstep(peak * 0.36, peak * 0.52, height)
		habitat *= 1.0 - smoothstep(0.25, 0.5, world.terrain.slope_at(p))
	var b := biome_at(p)
	return (1.0 - smoothstep(0.62, 0.74, b)) * habitat



# --- environment ---------------------------------------------------------------------

func _apply_sky() -> void:
	if mood != "day":
		env.sky.sky_material = sky_mat
		return
	if _photo_sky == null:
		_photo_sky = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = PHOTO_SKY_SHADER
		_photo_sky.shader = shader
		_photo_sky.set_shader_parameter("panorama", preload("res://assets/sky/kloofendal_partly_cloudy_2k.hdr"))
	# The HDR's brightest pixel is the sun, at (1218, 239) in its 2048 x 1024 panorama.
	var longitude := (1218.5 / 2048.0) * TAU
	var latitude := (239.5 / 1024.0) * PI
	var photographed := Vector3(sin(longitude) * sin(latitude), cos(latitude), -cos(longitude) * sin(latitude))
	var lit := Basis.from_euler(Vector3(deg_to_rad(-float(_d.elev)), deg_to_rad(float(_d.azim)), 0)).z
	_photo_sky.set_shader_parameter("rotation", Basis(Quaternion(lit, photographed)))
	env.sky.sky_material = _photo_sky


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
	sky_mat.set_shader_parameter("night_cloud", Color(0.06, 0.06, 0.06).linear_to_srgb())
	sky_mat.set_shader_parameter("sun_col", _d.sun)
	sky_mat.set_shader_parameter("cloudiness", 1.0 if mood in ["overcast", "rain"] else (0.3 if mood == "day" else 0.55))
	sky_mat.set_shader_parameter("stars", 1.0 if mood == "night" else 0.0)
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	_apply_sky()
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
	env.fog_density = float(_d.fog_d) * HAZE_STRENGTH
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
	env.volumetric_fog_density = (0.0011 if mood != "hazy" else 0.003) * VOLUME_STRENGTH
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
	sun.directional_shadow_max_distance = 800.0
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


var deform_tex: Texture2DArray
var _deform_tiles: TerrainTexture
var _deform_t := 0.0
var _surface_baked := false
var _scenery_bake: SubViewport
var _scenery_material: ShaderMaterial
var _terrain_probe: ReflectionProbe
var GROUND_HALF := MapDims.HALF + 8.0
var GROUND_CHUNKS := ceili(GROUND_HALF * 2.0 / 64.0)
const GROUND_LOD := 170.0  # beyond this from the camera a chunk is drawn on a coarser grid


const TERRAIN_MATERIALS := ["rock_face_03", "aerial_rocks_02", "aerial_grass_rock", "snow_02", "forest_leaves_02"]
static var _material_arrays: Array[Texture2DArray] = []


static func terrain_materials() -> Array[Texture2DArray]:
	if _material_arrays.is_empty():
		# One sampler per channel set leaves room for water and deformation on WebGL 2.
		for suffix in ["color_height", "surface"]:
			var images: Array[Image] = []
			for name in TERRAIN_MATERIALS:
				var texture: Texture2D = load("res://assets/terrain/%s_%s.png" % [name, suffix])
				images.append(texture.get_image())
			var gravel_path := "res://assets/town/gravelly_sand_color.jpg" if suffix == "color_height" else "res://assets/town/gravelly_sand_surface.png"
			var gravel: Texture2D = load(gravel_path)
			var grains := gravel.get_image()
			grains.convert(Image.FORMAT_RGBA8)
			images.append(grains)
			var array := Texture2DArray.new()
			var error := array.create_from_images(images)
			assert(error == OK, "Terrain material layers must share size, format and mipmaps")
			_material_arrays.append(array)
	return _material_arrays


func _build_ground() -> void:
	_blank_mask = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_R8))
	ground = MeshInstance3D.new()
	ground.mesh = _ground_ring(GROUND_HALF, MapDims.HALF + 1800.0)
	ground_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MapDims.shader(GROUND_SHADER.replace("// BACKDROP_HEIGHT", BACKDROP_HEIGHT))
	ground_mat.shader = sh
	ground_mat.set_shader_parameter("vertex_lit", ProjectSettings.get_setting_with_override("rendering/shading/overrides/force_vertex_shading"))
	ground_mat.set_shader_parameter("biome_tex", biome_tex)
	ground_mat.set_shader_parameter("detail_tex", detail_tex)
	ground_mat.set_shader_parameter("backdrop_tex", backdrop_tex)
	var materials := terrain_materials()
	ground_mat.set_shader_parameter("material_colors", materials[0])
	ground_mat.set_shader_parameter("material_surfaces", materials[1])
	ground_mat.set_shader_parameter("meadow_grass", preload("res://assets/town/leafy_grass_color.jpg"))
	ground_mat.set_shader_parameter("cloud_strength", float(_d.clouds))
	ground_mat.set_shader_parameter("sun_tint", _d.sun)
	ground_mat.set_shader_parameter("air_color", _d.fog)
	ground_mat.set_shader_parameter("wet", 1.0 if mood == "rain" else 0.0)
	ground_mat.set_shader_parameter("trench_mask", _blank_mask)
	ground.material_override = ground_mat
	ground.custom_aabb = AABB(Vector3(-MapDims.HALF - 1800.0, -5.0, -MapDims.HALF - 1800.0), Vector3(MapDims.SIZE + 3600.0, 517.0, MapDims.SIZE + 3600.0))
	ground.layers = 5 | Res.GROUND_DECAL_LAYER  # terrain capture plus ground-only decals
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	# the battlefield itself: chunks of fine grid (culled one by one), all
	# sharing one mesh; the shader lifts or sinks each vertex to the ground height
	if world.terrain and world.terrain.deform_img:
		_deform_tiles = TerrainTexture.new(world.terrain.deform_img)
	else:
		_deform_tiles = TerrainTexture.new(Image.create(TerrainTexture.TILE, TerrainTexture.TILE, false, Image.FORMAT_RH))
	deform_tex = _deform_tiles.texture
	ground_mat.set_shader_parameter("deform_tex", deform_tex)
	Mats.set_ground_maps(deform_tex, null)
	var step := 0.5 if int(Settings.get_v("lod")) >= 1 else 1.0
	var cs := GROUND_HALF * 2.0 / GROUND_CHUNKS
	var cm := _grid_mesh(cs, step)
	# far off, a chunk is drawn on a 2 m grid (the craters there are specks)
	var cm_far := _grid_mesh(cs, maxf(step, 4.0))
	for cx in GROUND_CHUNKS:
		for cz in GROUND_CHUNKS:
			var center := Vector3(-GROUND_HALF + (cx + 0.5) * cs, 0, -GROUND_HALF + (cz + 0.5) * cs)
			var bounds := _ground_chunk_bounds(center, cs)
			for far in [false, true]:
				var mi := MeshInstance3D.new()
				mi.mesh = cm_far if far else cm
				mi.material_override = ground_mat
				mi.layers = 5 | Res.GROUND_DECAL_LAYER
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				mi.position = center
				mi.custom_aabb = bounds
				if far:
					mi.visibility_range_begin = GROUND_LOD
				else:
					mi.visibility_range_end = GROUND_LOD
				add_child(mi)
	trench_net = TrenchNet.new(world)
	add_child(trench_net)
	trench_net.set_detail(detail_tex)
	road_mat = ShaderMaterial.new()
	var rs := Shader.new()
	rs.code = Mats.code(MapDims.shader(ROAD_SHADER.replace("// STREET_SURFACE", Mats.ASPHALT_SHADER)))
	road_mat.shader = rs
	road_mat.set_shader_parameter("detail_tex", detail_tex)
	road_mat.set_shader_parameter("paving_noise", preload("res://assets/town/aerial_asphalt_01_color.jpg"))
	road_mat.set_shader_parameter("street_detail", preload("res://assets/town/road_damaged_clean_color.jpg"))
	road_mat.set_shader_parameter("street_noise", Mats.noise_tex())
	road_mat.set_shader_parameter("gravel_color", preload("res://assets/town/gravelly_sand_color.jpg"))
	road_mat.set_shader_parameter("gravel_surface", preload("res://assets/town/gravelly_sand_surface.png"))
	road_mat.set_shader_parameter("paving_surface", preload("res://assets/town/road_damaged_clean_surface.png"))
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
	rain.amount = int(4500 * Settings.fx_mult())
	rain.lifetime = 1.6
	rain.preprocess = 1.6
	rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.65)
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
	var smat := ShaderMaterial.new()
	var splash_shader := Shader.new()
	splash_shader.code = MapDims.shader(SPLASH_SHADER)
	smat.shader = splash_shader
	smat.set_shader_parameter("deform_tex", deform_tex)
	smat.set_shader_parameter("water_level", WaterMap.LEVEL)
	splash.material_override = smat
	splash.local_coords = false
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	splash.visibility_aabb = AABB(Vector3(-50, -5, -50), Vector3(100, 517, 100))
	if Vfx.gl:
		splash.amount = int(splash.amount * 0.35)
	_splash = Vfx.part(splash)
	add_child(_splash)
	if Sfx.enabled:
		_rain_snd = Sfx.make_ambience("rain", -11.0)
		add_child(_rain_snd)


func _rain_tick(dt: float) -> void:
	var f := world.cam.focus_pos
	_rain.global_position = world.cam.cam.global_position + Vector3(0, 15, 0)
	_splash.global_position = Vector3(f.x, 0, f.z)
	# Individual splash vertices find the ground; distant droplets are subpixel.
	var nearby := world.cam.cam.global_position.distance_to(Vector3(f.x, world.ground_y(f), f.z)) < 140.0
	Vfx.set_emitting(_splash, nearby)
	_splash.visible = nearby
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
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float a = (1.0 - x) * smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.6, UV.y);
	ALBEDO = vec3(0.7, 0.75, 0.82) * a * 0.9;
	ALPHA = a * 0.18;
}
"""


const SPLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2DArray deform_tex : filter_linear, repeat_disable;
uniform float water_level = -0.45;
// TERRAIN_TEXTURE_HELPER
varying float visibility;
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	float height = terrain_height(deform_tex, (center.xz + __MAP_HALF__) / __MAP_SIZE__);
	center.y += max(water_level, height) + 0.05;
	visibility = (1.0 - smoothstep(40.0, 120.0, distance(CAMERA_POSITION_WORLD, center)))
		* (1.0 - step(__MAP_HALF__, max(abs(center.x), abs(center.z))));
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(center, 1.0));
	VERTEX *= scale;
}
void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(0.65, 0.72, 0.78);
	ALPHA = (1.0 - smoothstep(0.1, 1.0, radius)) * 0.26 * visibility;
}
"""


# --- night: illumination flares drifting down over the fighting ----------------

static var _flare_canopy_mesh: ArrayMesh
var _flare_t := 3.0
var _flares: Array = []  # [root, light, age, life, glow, trail, canopy]


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
		root.position.y = maxf(world.ground_y(root.position) + 0.15, root.position.y - dt * 1.3)
		root.position += Fires.WIND * dt * 0.6
		# The canopy and its lines sway together about the suspended charge.
		root.rotation.z = sin(age * 1.4) * 0.08
		var fade := clampf((life - age) / 3.0, 0.0, 1.0) * clampf(age * 2.0, 0.0, 1.0)
		var l: OmniLight3D = f[1]
		l.light_energy = fade * (7.0 + 1.0 * sin(age * 23.0) + 0.6 * sin(age * 37.0))
		(f[4] as MeshInstance3D).scale = Vector3.ONE * (0.65 + 0.06 * sin(age * 31.0)) * fade
		if age >= life and is_instance_valid(f[5]):
			for emitter: GeometryInstance3D in (f[5] as Node3D).get_children():
				Vfx.set_emitting(emitter, false)
		if age > life + 4.0:
			root.queue_free()
			_flares.remove_at(i)


func _spawn_flare(p: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(p.x, world.ground_y(p) + 36.0, p.z)
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
	chute.mesh = _flare_canopy()
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.70, 0.68, 0.61)
	cloth.roughness = 0.95
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.vertex_color_use_as_albedo = true
	chute.material_override = cloth
	chute.position = Vector3(0, 2.4, 0)
	root.add_child(chute)
	# Suspension lines meet the cloth rim and stay attached as it sways.
	for i in 8:
		var a := i * TAU / 8.0
		var seam := pow(absf(sin(a * 6.0)), 2.0)
		var radius := 0.9 * (1.0 - 0.035 * seam)
		var end := Vector3(cos(a) * radius, 2.4 + 0.045 * seam, sin(a) * radius)
		var line := Res.mi(root, Res.cyl(0.003, 0.003, end.length(), 4), Mats.get_mat("canvas_white"), end * 0.5)
		line.quaternion = Quaternion(Vector3.UP, end.normalized())
	var tr: Node3D
	if world.fx and world.fx.vfx:
		tr = world.fx.vfx.make_flare_trail()
		root.add_child(tr)
	_flares.append([root, l, 0.0, randf_range(20.0, 26.0), glow, tr, chute])


## A sewn canopy has a rounded crown and scalloped gores, open underneath.
## One shared mesh replaces a flattened sphere, including when seen from below.
static func _flare_canopy() -> ArrayMesh:
	if _flare_canopy_mesh:
		return _flare_canopy_mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 8:
		for segment in 48:
			for corner in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var theta := float(ring + corner.x) / 8.0 * PI * 0.5
				var phi := float(segment + corner.y) / 48.0 * TAU
				var seam := pow(absf(sin(phi * 6.0)), 2.0)
				var radius := 0.9 * sin(theta) * (1.0 - 0.035 * seam)
				var y := 0.48 * cos(theta) + 0.045 * pow(sin(theta), 6.0) * seam
				var tint := 0.92 + 0.08 * seam
				surface.set_color(Color(tint, tint, tint))
				surface.set_uv(Vector2(phi / TAU, theta / (PI * 0.5)))
				surface.add_vertex(Vector3(cos(phi) * radius, y, sin(phi) * radius))
	surface.generate_normals()
	_flare_canopy_mesh = surface.commit()
	return _flare_canopy_mesh


## Switches the lighting mood live (Settings > Time of day).
func apply_mood(m: String) -> void:
	if not MOODS.has(m):
		return
	mood = m
	_d = MOODS[m]
	_surface_baked = false
	sky_mat.set_shader_parameter("zenith", _d.zenith)
	sky_mat.set_shader_parameter("horizon", _d.horizon)
	sky_mat.set_shader_parameter("sun_col", _d.sun)
	sky_mat.set_shader_parameter("cloudiness", 1.0 if mood in ["overcast", "rain"] else (0.3 if mood == "day" else 0.55))
	sky_mat.set_shader_parameter("stars", 1.0 if mood == "night" else 0.0)
	_apply_sky()
	env.ambient_light_energy = float(_d.ambient)
	ground_mat.set_shader_parameter("wet", 1.0 if mood == "rain" else 0.0)
	Mats.set_shared(road_mat, &"wet", 1.0 if mood == "rain" else 0.0)
	_setup_rain()
	env.tonemap_exposure = float(_d.exposure) * float(Settings.get_v("brightness"))
	env.fog_light_color = _d.fog
	_apply_haze(world.cam.dist if world.cam else HAZE_DISTANCE)
	env.volumetric_fog_albedo = (_d.fog as Color).lerp(Color(0.9, 0.9, 0.9), 0.55)
	_apply_look()
	sun.rotation_degrees = Vector3(-float(_d.elev), float(_d.azim), 0)
	sun.light_color = _d.sun
	sun.light_energy = float(_d.energy)
	rim.rotation_degrees = Vector3(-25.0, float(_d.azim) + 180.0, 0)
	rim.light_energy = 0.28 if mood != "overcast" else 0.12
	ground_mat.set_shader_parameter("cloud_strength", float(_d.clouds))
	ground_mat.set_shader_parameter("sun_tint", _d.sun)
	ground_mat.set_shader_parameter("air_color", _d.fog)
	if mountain_clouds:
		mountain_clouds.apply_settings(self)
	if water_view:
		water_view.apply_mood(_d, mood)
	if world.fx and world.fx.vfx:
		world.fx.vfx.apply_lighting()


func apply_settings() -> void:
	var s := Settings
	ground_mat.set_shader_parameter("terrain_detail", int(s.get_v("lod")) >= 1)
	if forest:
		forest.apply_settings()
	# the battle's own mood stands (the host's choice, or a mission's) until
	# the player changes the setting while it's on
	var want := String(s.get_v("mood"))
	if want != _mood_asked:
		_mood_asked = want
		if MOODS.has(want) and want != mood:
			apply_mood(want)
	if mountain_clouds:
		mountain_clouds.apply_settings(self)
	_update_terrain_probe()
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
			sun.directional_shadow_max_distance = 800.0
			sun.light_angular_distance = minf(float(_d.soft), 1.0)
		3:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			sun.directional_shadow_max_distance = 1200.0
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
	_apply_haze(world.cam.dist)
	if not Settings.get_v("dof"):
		return
	# gentle tilt-shift: keep the focus plane at the camera's target
	var d := world.cam.dist
	cam_attr.dof_blur_far_distance = d * 1.35
	cam_attr.dof_blur_far_transition = d * 0.9
	cam_attr.dof_blur_near_distance = d * 0.55
	cam_attr.dof_blur_near_transition = d * 0.3


## No lower clamp: distant command cameras otherwise look through an ever
## thicker veil. Mood still sets the colour and relative amount of haze.
static func haze_distance_factor(distance: float) -> float:
	return minf(1.0, HAZE_DISTANCE / maxf(1.0, distance))


## Capture immutable terrain once; moving units and water never enter the capture.
func _update_terrain_probe(refresh := false) -> void:
	var enabled := bool(Settings.get_v("terrain_reflections"))
	if not enabled:
		if is_instance_valid(_terrain_probe):
			_terrain_probe.queue_free()
			_terrain_probe = null
		return
	if not _surface_baked:
		return
	if refresh and is_instance_valid(_terrain_probe):
		_terrain_probe.queue_free()
		_terrain_probe = null
	if not is_instance_valid(_terrain_probe):
		_terrain_probe = ReflectionProbe.new()
		_terrain_probe.size = Vector3(MapDims.SIZE * 2.0, 1200.0, MapDims.SIZE * 2.0)
		_terrain_probe.position = Vector3(0, 4, 0)
		_terrain_probe.max_distance = MapDims.SIZE + 1800.0
		_terrain_probe.cull_mask = 4
		_terrain_probe.enable_shadows = false
		_terrain_probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		_terrain_probe.update_mode = ReflectionProbe.UPDATE_ONCE
		add_child(_terrain_probe)


func _apply_haze(distance: float) -> void:
	var k := haze_distance_factor(distance)
	var volume_k := k
	var terrain_air := 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_height_density = 0.0
	if bool(Settings.get_v("alpine_haze")) and world != null and world.terrain and world.terrain.landform.peak > 1.0:
		var downward := absf(sin(world.cam.rotation.x)) if world.cam else 0.0
		k = maxf(k, 0.45 * pow(1.0 - downward, 2.0))
		# Sky tint separates distant ranges; keep the low valley veil out of the overhead view.
		env.fog_aerial_perspective = 0.38 * (1.0 - downward)
		terrain_air = float(_d.fog_d) * 0.48 * pow(1.0 - downward, 2.0)
		env.fog_height = 18.0
		env.fog_height_density = 0.0012 * pow(1.0 - downward, 2.0)
	if ground_mat:
		ground_mat.set_shader_parameter("terrain_air", terrain_air)
	env.fog_density = float(_d.fog_d) * HAZE_STRENGTH * k
	env.volumetric_fog_density = (0.0011 if mood != "hazy" else 0.003) * VOLUME_STRENGTH * volume_k


## Builds the road strip mesh for a team (called by World when roads change).
func set_town(r: Rect2) -> void:
	Mats.set_shared(road_mat, &"town", Vector4(r.position.x, r.position.y, r.end.x, r.end.y))


## Bound a chunk by its own geology and the allowed deformation.
func _ground_chunk_bounds(center: Vector3, size: float) -> AABB:
	# Godot measures visibility ranges from the AABB centre. A map-wide
	# 512 m height allowance put that centre above even the near-detail range,
	# so small craters disappeared into the coarse grid at ground level.
	var low := 0.0
	var high := 0.0
	var form: Landform = world.terrain.landform
	if not form.heights.is_empty():
		low = INF
		var start := Vector2(center.x - size * 0.5 + form.half, center.z - size * 0.5 + form.half) / Landform.STEP
		var end := Vector2(center.x + size * 0.5 + form.half, center.z + size * 0.5 + form.half) / Landform.STEP
		# Include neighbouring geology samples: bilinear heights cannot exceed
		# their extrema. This runs at map setup, not every frame or explosion.
		for z in range(maxi(0, floori(start.y) - 1), mini(form.n, ceili(end.y) + 2)):
			for x in range(maxi(0, floori(start.x) - 1), mini(form.n, ceili(end.x) + 2)):
				var h := form.heights[z * form.n + x]
				low = minf(low, h)
				high = maxf(high, h)
		if maxf(absf(center.x), absf(center.z)) + size * 0.5 >= MapDims.HALF:
			low = minf(low, 0.0)
	# Craters clamp to -1.4/+0.55 m; the outer 8 m apron can reach sea floor.
	return AABB(Vector3(-size * 0.5, low - 4.0, -size * 0.5), Vector3(size, high - low + 5.0, size))


## A square of ground `size` across in quads of `step` metres, centred on its origin.
func _grid_mesh(size: float, step: float) -> ArrayMesh:
	var n := int(round(size / step))
	# The map width is not necessarily a multiple of the requested spacing.
	# Both detail levels must end at exactly the same chunk boundary.
	step = size / n
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


## Scenery beyond the playable boundary; its shader blends into the level map edge.
func _ground_ring(inner: float, outer: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rects := [Rect2(-outer, -outer, outer * 2.0, outer - inner), Rect2(-outer, inner, outer * 2.0, outer - inner),
		Rect2(-outer, -inner, outer - inner, inner * 2.0), Rect2(inner, -inner, outer - inner, inner * 2.0)]
	var spacing := 8.0 if int(Settings.get_v("lod")) >= 1 else 16.0
	for r in rects:
		var nx := ceili(r.size.x / spacing)
		var nz := ceili(r.size.y / spacing)
		for z in nz:
			for x in nx:
				var lo: Vector2 = r.position + r.size * Vector2(float(x) / nx, float(z) / nz)
				var hi: Vector2 = r.position + r.size * Vector2(float(x + 1) / nx, float(z + 1) / nz)
				var a := Vector3(lo.x, 0, lo.y)
				var b := Vector3(hi.x, 0, lo.y)
				var c := Vector3(hi.x, 0, hi.y)
				var d := Vector3(lo.x, 0, hi.y)
				for p in [a, b, c, a, c, d]:
					st.set_normal(Vector3.UP)
					st.add_vertex(p)
	st.index()
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
	ground_mat.set_shader_parameter("river_tips", water_view.river_tips)
	if world.terrain.landform.peak > 1.0:
		water_view.mat.set_shader_parameter("fresh_tint", Color(0.1, 0.32, 0.30))
		water_view.mat.set_shader_parameter("fresh_absorb", Vector3(0.85, 0.32, 0.28))
	water_view.apply_mood(_d, mood)
	if grass:
		grass.request_rebuild(0.5)


## A cached horizon map lets distant cliffs shade their valleys without shadow-map draw calls.
func _bake_scenery() -> void:
	if _scenery_bake == null:
		_scenery_bake = SubViewport.new()
		_scenery_bake.name = "SceneryLighting"
		_scenery_bake.size = Vector2i(512, 512)
		_scenery_bake.disable_3d = true
		add_child(_scenery_bake)
		_scenery_material = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = MapDims.shader(SCENERY_BAKE_SHADER.replace("// BACKDROP_HEIGHT", BACKDROP_HEIGHT))
		_scenery_material.shader = shader
		var rect := ColorRect.new()
		rect.size = Vector2(512, 512)
		rect.material = _scenery_material
		_scenery_bake.add_child(rect)
		ground_mat.set_shader_parameter("scenery_bake", _scenery_bake.get_texture())
	_scenery_material.set_shader_parameter("backdrop_tex", backdrop_tex)
	if water_view:
		_scenery_material.set_shader_parameter("river_tips", water_view.river_tips)
	_scenery_material.set_shader_parameter("deform_tex", deform_tex)
	_scenery_material.set_shader_parameter("sea_x", ground_mat.get_shader_parameter("sea_x"))
	_scenery_material.set_shader_parameter("snow_line", maxf(25.0, world.terrain.landform.peak * 0.55) if world.terrain.landform.peak > 1.0 else 10000.0)
	_scenery_material.set_shader_parameter("sun_direction", sun.basis.z)
	_scenery_bake.render_target_update_mode = SubViewport.UPDATE_ONCE


## New shell holes go up to the GPU (a few times a second at most).
func _update_deform(dt: float) -> void:
	_deform_t -= dt
	var tm = world.terrain
	if tm == null or tm.deform_img == null:
		return
	if not _surface_baked and not tm.landform.heights.is_empty():
		# Joining clients install their geology after the view is constructed.
		for child in get_children():
			if child is MeshInstance3D and child != ground and child.material_override == ground_mat:
				child.custom_aabb = _ground_chunk_bounds(child.position, GROUND_HALF * 2.0 / GROUND_CHUNKS)
		ground_mat.set_shader_parameter("surface_bake", ImageTexture.create_from_image(tm.landform.bake_surface(sun.basis.z)))
		ground_mat.set_shader_parameter("sun_direction", sun.basis.z)
		_surface_baked = true
		_bake_scenery()
		if forest == null:
			forest = DistantForest.new()
			add_child(forest)
			forest.setup(self)
		forest.set_lighting(_scenery_bake.get_texture(), sun.basis.z)
		_update_terrain_probe(true)
		var post := post_rect.material as ShaderMaterial
		post.set_shader_parameter("fringe", 0.00015)
		post.set_shader_parameter("grain", 0.006)
		post.set_shader_parameter("vignette", 0.15)
	if not tm.deform_dirty.is_empty() and _deform_t <= 0.0:
		ground_mat.set_shader_parameter("snow_line", maxf(25.0, tm.landform.peak * 0.55) if tm.landform.peak > 1.0 else 10000.0)
		_deform_t = 0.22
		for rect: Rect2i in tm.deform_dirty:
			_deform_tiles.mark_dirty(rect)
			if world.phys:
				world.phys.update_deform(rect)
		tm.deform_dirty.clear()
	_deform_tiles.flush()


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
	mi.layers = 1 | Res.GROUND_DECAL_LAYER
	Mats.set_inst(mi, &"country", 1.0 if team == 2 else 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


const PHOTO_SKY_SHADER := """
shader_type sky;
uniform sampler2D panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform mat3 rotation;
void sky() {
	vec3 d = rotation * EYEDIR;
	vec2 uv = vec2(atan(d.x, -d.z) / TAU, acos(clamp(d.y, -1.0, 1.0)) / PI);
	vec3 sky = min(texture(panorama, vec2(fract(uv.x), uv.y)).rgb, vec3(16.0));
	COLOR = mix(sky, vec3(0.14, 0.16, 0.12), 1.0 - smoothstep(-0.20, -0.02, EYEDIR.y));
}
"""

const SKY_SHADER := """
shader_type sky;
uniform vec3 zenith : source_color;
uniform vec3 horizon : source_color;
uniform vec3 ground_col : source_color;
uniform vec3 sun_col : source_color;
uniform vec3 night_cloud : source_color;
uniform float cloudiness = 0.5;
uniform float stars = 0.0;

// Bounded arithmetic keeps neighboring cloud cells continuous on both renderers.
float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
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
		vec3 cl = mix(horizon * 0.95, mix(vec3(1.0), night_cloud, stars), 0.55) * (0.75 + 0.5 * sd);
		cl = mix(cl, sun_col, 0.18 * sd);
		col = mix(col, cl, c * 0.85);
	}
	COLOR = col;
}
"""

const BACKDROP_HEIGHT := WaterView.SCENERY_COAST + WaterView.SCENERY_RIVERS + """
float backdrop(vec2 p) {
	float edge = max(abs(p.x), abs(p.y)) - __MAP_HALF__;
	float shore = scenery_shore(p, sea_x);
	float coast = 1.0 - smoothstep(shore - 90.0, shore, p.x);
	vec2 uv = (p + __MAP_HALF__ + 1800.0) / (__MAP_SIZE__ + 3600.0);
	float mountain = textureLod(backdrop_tex, uv, 0.0).r;
	float hills = pow(smoothstep(0.18, 0.88, mountain), 2.2) * 440.0;
	float land = hills * smoothstep(8.0, 380.0, edge) * coast * (1.0 - step(9999.0, snow_line))
		* (1.0 - smoothstep(1450.0, 1800.0, edge))
		- 3.2 * smoothstep(shore, shore + 30.0, p.x);
	float into = scenery_river_into(p);
	return mix(land, min(land, scenery_river_bed(into)), smoothstep(-5.0, 0.0, into));
}
float forest_habitat(vec2 p, float height, float gradient) {
	float treeline = max(150.0, snow_line * 1.5);
	return smoothstep(2.0, 8.0, height) * (1.0 - smoothstep(treeline - 35.0, treeline - 12.0, height))
		* (1.0 - smoothstep(0.50, 0.75, gradient))
		* (1.0 - smoothstep(scenery_shore(p, sea_x) - 60.0, scenery_shore(p, sea_x) - 40.0, p.x));
}

"""

const SCENERY_BAKE_SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D backdrop_tex : filter_linear, repeat_disable;
uniform sampler2DArray deform_tex : filter_linear, repeat_disable;
uniform float sea_x = 1e9;
uniform float snow_line = 100.0;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
// TERRAIN_TEXTURE_HELPER
// BACKDROP_HEIGHT
float height_at(vec2 p) {
	if (max(abs(p.x), abs(p.y)) < __MAP_HALF__) {
		return terrain_height(deform_tex, (p + __MAP_HALF__) / __MAP_SIZE__);
	}
	return backdrop(p);
}
void fragment() {
	vec2 p = UV * (__MAP_SIZE__ + 3600.0) - (__MAP_HALF__ + 1800.0);
	float h = height_at(p);
	float occlusion = 0.0;
	float basin = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.78539816;
		vec2 direction = vec2(cos(angle), sin(angle));
		float horizon = 0.0;
		float distance = 16.0;
		for (int j = 0; j < 6; j++) {
			float rise = height_at(p + direction * distance) - h;
			horizon = max(horizon, rise / distance);
			if (j == 0) { basin += rise; }
			distance *= 2.0;
		}
		occlusion += horizon / sqrt(1.0 + horizon * horizon);
	}
	float horizontal = length(sun_direction.xz);
	vec2 toward_sun = sun_direction.xz / max(horizontal, 0.001);
	float sun_slope = sun_direction.y / max(horizontal, 0.001);
	float sun_horizon = 0.0;
	float distance = 12.0;
	for (int i = 0; i < 18; i++) {
		sun_horizon = max(sun_horizon, (height_at(p + toward_sun * distance) - h - 1.5) / distance);
		distance *= 1.38;
	}
	float sunlight = 1.0 - smoothstep(sun_slope - 0.035, sun_slope + 0.035, sun_horizon);
	COLOR = vec4(1.0 - occlusion / 8.0 * 0.75, clamp(0.5 + basin / 128.0, 0.0, 1.0), sunlight, 1.0);
}
"""

const GROUND_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;

uniform bool vertex_lit = false;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 air_color : source_color = vec3(0.5, 0.6, 0.7);
uniform float terrain_air = 0.0;
uniform bool terrain_detail = true;
uniform sampler2D surface_bake : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D scenery_bake : hint_default_white, filter_linear, repeat_disable;
uniform sampler2DArray material_colors : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray material_surfaces : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D biome_tex : filter_linear, repeat_enable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D backdrop_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D forest_cover : hint_default_black, filter_linear, repeat_disable;
uniform vec3 grass_a : source_color = vec3(0.24, 0.29, 0.19);
uniform vec3 grass_b : source_color = vec3(0.32, 0.36, 0.24);
uniform vec3 dry : source_color = vec3(0.36, 0.33, 0.19);
uniform vec3 dirt : source_color = vec3(0.3, 0.26, 0.2);
uniform vec3 mud : source_color = vec3(0.19, 0.16, 0.12);
uniform vec3 sun_tint : source_color = vec3(1.0);
uniform float cloud_strength = 0.3;
uniform float bump = 0.85;
uniform float snow_line = 10000.0;
uniform float wet = 0.0;
uniform sampler2D trench_mask : hint_default_black, filter_linear, repeat_disable;
uniform sampler2DArray deform_tex : filter_linear, repeat_disable;
// TERRAIN_TEXTURE_HELPER
uniform sampler2D water_mask : hint_default_transparent, filter_linear, repeat_disable;
uniform float sea_x = 1e9;

varying vec3 wpos;
varying float puddle;
varying float terrain_sun;
varying float rock_damp;

// BACKDROP_HEIGHT

float dfm(vec2 p) {
	if (max(abs(p.x), abs(p.y)) >= __MAP_HALF__) { return backdrop(p); }
	return terrain_height(deform_tex, (p + __MAP_HALF__) / __MAP_SIZE__);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The browser lights vertices, so displaced mountains need their slope here too.
	if (vertex_lit) {
		float spacing = max(abs(wpos.x), abs(wpos.z)) >= __MAP_HALF__ ? 16.0 : 1.0;
		float dx = dfm(wpos.xz + vec2(spacing, 0.0)) - dfm(wpos.xz - vec2(spacing, 0.0));
		float dz = dfm(wpos.xz + vec2(0.0, spacing)) - dfm(wpos.xz - vec2(0.0, spacing));
		NORMAL = normalize(vec3(-dx, 2.0 * spacing, -dz));
	}
	if (abs(wpos.x) < __MAP_HALF__ && abs(wpos.z) < __MAP_HALF__) {
		float d = dfm(wpos.xz);
		VERTEX.y += d;
		wpos.y += d;
	} else {
		float d = backdrop(wpos.xz);
		VERTEX.y += d;
		wpos.y += d;
	}
}

float hgt(vec2 p) {
	return texture(detail_tex, p / 9.0).r * 0.6 + texture(detail_tex, p / 2.3 + 0.31).r * 0.4;
}

vec4 surface_color(float layer, vec3 p, vec3 weights) {
	vec4 x = texture(material_colors, vec3(p.zy, layer));
	vec4 y = texture(material_colors, vec3(p.xz, layer));
	vec4 z = texture(material_colors, vec3(p.xy, layer));
	if (OUTPUT_IS_SRGB) {
		x.rgb = mix(x.rgb / 12.92, pow((x.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), x.rgb));
		y.rgb = mix(y.rgb / 12.92, pow((y.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), y.rgb));
		z.rgb = mix(z.rgb / 12.92, pow((z.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), z.rgb));
	}
	return x * weights.x + y * weights.y + z * weights.z;
}

// Normal XY, baked crevice visibility and roughness share one linear-data texture.
vec2 surface_data(float layer, vec3 p, vec3 weights, vec3 geometric, out vec3 mapped) {
	vec4 x = texture(material_surfaces, vec3(p.zy, layer));
	vec4 y = texture(material_surfaces, vec3(p.xz, layer));
	vec4 z = texture(material_surfaces, vec3(p.xy, layer));
	vec2 nx = x.rg * 2.0 - 1.0;
	vec2 ny = y.rg * 2.0 - 1.0;
	vec2 nz = z.rg * 2.0 - 1.0;
	// A flat detail map must preserve the terrain normal, including negative faces.
	vec3 tx = vec3(geometric.x * sqrt(max(0.0, 1.0 - dot(nx, nx))), geometric.y + nx.y, geometric.z + nx.x);
	vec3 ty = vec3(geometric.x + ny.x, geometric.y * sqrt(max(0.0, 1.0 - dot(ny, ny))), geometric.z + ny.y);
	vec3 tz = vec3(geometric.x + nz.x, geometric.y + nz.y, geometric.z * sqrt(max(0.0, 1.0 - dot(nz, nz))));
	mapped = normalize(tx * weights.x + ty * weights.y + tz * weights.z);
	return x.ba * weights.x + y.ba * weights.y + z.ba * weights.z;
}

vec3 surface_relief(vec3 normal, float height, float strength) {
	vec3 dx = dFdx(wpos); vec3 dy = dFdy(wpos);
	vec3 face = normalize(cross(dx, dy));
	face *= sign(dot(face, normal));
	vec3 r1 = cross(dy, face); vec3 r2 = cross(face, dx);
	float det = dot(dx, r1);
	vec3 gradient = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
	return normalize(normal - gradient * strength / max(abs(det), 0.000001));
}

// Photographed grass follows sheltered soil and exposed dry patches beyond the town too.
vec3 meadow_color(vec2 p, float dryness) {
	vec3 blades = texture(meadow_grass, p * 0.5).rgb;
	if (OUTPUT_IS_SRGB) {
		blades = mix(blades / 12.92, pow((blades + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), blades));
	}
	return blades * mix(vec3(0.18, 0.35, 0.25), vec3(0.36, 0.48, 0.50), dryness);
}

// Fine rounded grains share the sand's warm palette; mountain scree reads as giant chips here.
vec3 shore_gravel_color(vec2 p) {
	vec3 scan = texture(material_colors, vec3(p * 0.65, 5.0)).rgb;
	if (OUTPUT_IS_SRGB) {
		scan = mix(scan / 12.92, pow((scan + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), scan));
	}
	float luma = dot(scan, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(luma), scan, 0.4) * vec3(1.12, 1.09, 1.02);
}

float height_blend(float bed, float deposit, float coverage) {
	vec2 relief = vec2(bed * 0.36 + 1.0 - coverage, deposit * 0.36 + coverage);
	vec2 weight = max(relief - max(relief.x, relief.y) + 0.18, vec2(0.0));
	return weight.y / max(0.001, weight.x + weight.y);
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
		wm = p.x > scenery_shore(p, sea_x) ? vec4(1.0, 1.0, 1.0, 1.0) : scenery_river_mask(p);
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
	float geology = terrain_geology(deform_tex, (p + __MAP_HALF__) / __MAP_SIZE__);
	if (max(abs(p.x), abs(p.y)) >= __MAP_HALF__) { geology = dfm(p); }
	float hd = dfm(p) - geology;
	float bowl = smoothstep(-0.03, -0.35, hd) * (1.0 - wm.g);
	float lip = smoothstep(0.02, 0.12, hd) * (1.0 - wm.g);
	// (linear colours: freshly turned earth is dark, the bottom blackened)
	vec3 churn = mix(vec3(0.042, 0.032, 0.023), vec3(0.075, 0.056, 0.038), d3) * (0.85 + 0.3 * d2);
	col = mix(col, churn, clamp(bowl * 1.1, 0.0, 1.0));
	col = mix(col, vec3(0.018, 0.016, 0.014), smoothstep(-0.3, -0.75, hd) * 0.55);
	col = mix(col, mix(dirt, vec3(0.085, 0.066, 0.047), 0.6) * (0.85 + 0.3 * d3), lip * 0.75);
	// Sample distant slopes across their mesh spacing, not within one height texel.
	float normal_step = edge >= __MAP_HALF__ ? 16.0 : 1.0;
	float rx = (dfm(p + vec2(normal_step, 0.0)) - dfm(p - vec2(normal_step, 0.0))) / (2.0 * normal_step);
	float rz = (dfm(p + vec2(0.0, normal_step)) - dfm(p - vec2(0.0, normal_step))) / (2.0 * normal_step);
	float slope = length(vec2(rx, rz));
	// Standing water cannot flatten the normals of a steep cliff.
	puddle *= 1.0 - smoothstep(0.08, 0.25, slope);
	vec3 geometric = normalize(vec3(-rx, 1.0, -rz));
	vec3 weights = pow(abs(geometric), vec3(4.0));
	weights /= weights.x + weights.y + weights.z;
	// Metre-scale scree and broad bedrock share a palette, rather than fading into grey noise.
	vec2 warp = vec2(texture(detail_tex, p / 5000.0).r, texture(detail_tex, p / 5000.0 + 0.43).r);
	float region = smoothstep(0.25, 0.72, texture(detail_tex, p / 2300.0 + warp * 0.35).r);
	float patch = smoothstep(0.30, 0.68, texture(detail_tex, p / 620.0 + warp * 0.18).r);
	float seams = texture(detail_tex, vec2(p.x * 0.0005 + p.y * 0.00025, wpos.y * 0.0018) + warp * 0.12).r;
	// Warp the projection in three dimensions so the same slab does not repeat up every face.
	vec3 fracture_warp = vec3(
		texture(detail_tex, wpos.zy / 900.0 + 0.17).r,
		texture(detail_tex, wpos.xz / 1100.0 + 0.53).r,
		texture(detail_tex, wpos.xy / 800.0 + 0.81).r) - vec3(0.5);
	vec3 rock_uv = (wpos + fracture_warp * 22.0) / 48.0;
	vec3 scree_uv = wpos / 16.0 + 0.37;
	vec3 moss_uv = wpos / 18.0;
	vec4 rock_sample = surface_color(0.0, rock_uv, weights);
	vec3 secondary_uv = rock_uv * 2.31 + vec3(0.37, 0.61, 0.23);
	float secondary_mix = smoothstep(0.25, 0.72, patch) * 0.55;
	if (terrain_detail) {
		rock_sample = mix(rock_sample, surface_color(0.0, secondary_uv, weights), secondary_mix);
	}
	vec4 scree_sample = surface_color(1.0, scree_uv, weights);
	float debris_luma = dot(scree_sample.rgb, vec3(0.2126, 0.7152, 0.0722));
	scree_sample.rgb = mix(vec3(debris_luma), scree_sample.rgb, 0.18) * vec3(0.90, 0.97, 1.03);
	vec4 moss_sample = surface_color(2.0, moss_uv, weights);
	float macro = texture(detail_tex, p / 190.0 + 0.19).r;
	vec4 surface = texture(surface_bake, (p + __MAP_HALF__) / __MAP_SIZE__);
	vec3 habitat_bake = surface.rgb;
	float flow = surface.a;
	vec3 scenery = texture(scenery_bake, (p + __MAP_HALF__ + 1800.0) / (__MAP_SIZE__ + 3600.0)).rgb;
	if (edge >= __MAP_HALF__) {
		habitat_bake = scenery;
		flow = texture(backdrop_tex, (p + __MAP_HALF__ + 1800.0) / (__MAP_SIZE__ + 3600.0)).g;
	}
	// Tilted beds break across the face; sheltered seams weather darker than exposed ribs.
	float bedding = sin(wpos.y * 0.32 + p.x * 0.045 + p.y * 0.025 + (seams - 0.5) * 12.0);
	float mineral = smoothstep(0.2, 0.85, bedding) * smoothstep(0.28, 0.65, patch);
	float shelter = smoothstep(0.48, 0.68, habitat_bake.g);
	float weathered = smoothstep(0.32, 0.72, seams * 0.55 + patch * 0.25 + shelter * 0.20);
	float scree = clamp((1.0 - smoothstep(0.3, 1.15, slope)) * mix(0.15, 0.95, patch)
		+ shelter * patch * 0.35, 0.0, 1.0);
	// Loose debris persists below rock walls, especially in concave sheltered ground.
	float talus = smoothstep(0.12, 0.45, slope) * (1.0 - smoothstep(0.85, 1.5, slope));
	talus *= smoothstep(4.0, 22.0, geology) * (1.0 - smoothstep(snow_line * 0.65, snow_line, geology));
	talus *= smoothstep(0.25, 0.72, shelter * 0.55 + patch * 0.25 + macro * 0.2);
	float drainage = texture(detail_tex, p / 310.0 + vec2(warp.y, warp.x) * 0.7).r;
	talus *= smoothstep(0.40, 0.66, drainage + (macro - 0.5) * 0.32);
	talus *= height_blend(rock_sample.a, scree_sample.a, 0.65);
	scree = max(scree, talus);
	float stone = dot(rock_sample.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 rock = mix(vec3(stone), rock_sample.rgb, 0.45) * vec3(1.04, 1.10, 1.18);
	rock = mix(rock, scree_sample.rgb * vec3(1.04, 1.06, 1.07), scree * 0.7);
	rock *= mix(vec3(0.58, 0.67, 0.78), vec3(1.28, 1.17, 0.98), region);
	rock *= mix(1.12, 0.65, weathered);
	rock = mix(rock, scree_sample.rgb * vec3(1.01, 1.04, 1.07), talus * 0.8);
	rock = mix(rock, rock * vec3(1.45, 1.40, 1.29), mineral * 0.65);
	rock *= mix(0.86, 1.14, smoothstep(0.25, 0.75, macro));
	// Weathering follows the baked downhill catchments rather than arbitrary stripes.
	float runoff = smoothstep(0.1, 0.65, flow);
	runoff *= smoothstep(0.55, 1.2, slope) * mix(0.25, 0.85, patch);
	rock *= mix(vec3(1.0), vec3(0.56, 0.61, 0.63), runoff);
	rock_damp = smoothstep(0.12, 0.7, flow) * 0.7;
	rock_damp *= mix(0.42, 1.0, shelter) * smoothstep(0.35, 1.0, slope);
	rock_damp *= 1.0 - smoothstep(snow_line * 0.75, snow_line * 1.1, geology);
	rock *= mix(vec3(1.0), vec3(0.27, 0.34, 0.38), rock_damp);
	float rock_height = mix(rock_sample.a, scree_sample.a, scree * 0.7);
	float grass_detail = dot(moss_sample.rgb, vec3(0.2126, 0.7152, 0.0722));
	float alpine_soil = clamp(0.52 + (habitat_bake.g - 0.5) * 1.3 + geometric.z * 0.18 - slope * 0.14, 0.0, 1.0);
	float alpine_dry = smoothstep(0.25, 0.85, 1.0 - alpine_soil + (patch - 0.5) * 0.12);
	vec3 moss = mix(vec3(0.05, 0.078, 0.025), vec3(0.115, 0.12, 0.06), alpine_dry) * (0.60 + grass_detail * 1.6);
	// Broad soil pockets connect the meadow colours; fine noise only supplies texture.
	float meadow = smoothstep(0.25, 0.72, region * 0.15 + patch * 0.2 + alpine_soil * 0.65);
	float turf = (1.0 - smoothstep(0.35, 0.9, slope)) * (1.0 - smoothstep(0.65, 1.0, geology / max(snow_line, 1.0)));
	vec3 dry_turf = vec3(0.135, 0.132, 0.065) * (0.65 + grass_detail * 1.3);
	vec3 rich_turf = moss * vec3(0.88, 1.0, 0.91);
	moss = mix(moss, mix(dry_turf, rich_turf, meadow), turf * 0.72);
	moss *= mix(0.93, 1.07, patch);
	float meadow_turf = turf * (1.0 - dirt_m);
	if (meadow_turf > 0.001) {
		float meadow_dry = alpine_dry * 0.75 + texture(detail_tex, p / 180.0).r * 0.25;
		moss = mix(moss, meadow_color(p, meadow_dry), meadow_turf * 0.85);
	}
	vec3 rock_n; vec3 scree_n; vec3 moss_n;
	vec2 rock_data = surface_data(0.0, rock_uv, weights, geometric, rock_n);
	if (terrain_detail) {
		vec3 secondary_n;
		vec2 secondary_data = surface_data(0.0, secondary_uv, weights, geometric, secondary_n);
		rock_data = mix(rock_data, secondary_data, secondary_mix);
		rock_n = normalize(mix(rock_n, secondary_n, secondary_mix));
	}
	vec2 scree_data = surface_data(1.0, scree_uv, weights, geometric, scree_n);
	vec2 moss_data = surface_data(2.0, moss_uv, weights, geometric, moss_n);
	rock_data = mix(rock_data, scree_data, scree * 0.7);
	rock_n = normalize(mix(rock_n, scree_n, scree * 0.7));
	float elevation = smoothstep(0.0, snow_line, geology);
	vec3 baked = habitat_bake;
	terrain_sun = min(baked.b, scenery.b);
	float cavity = (baked.g - 0.5) * 2.0;
	float sky = baked.r;
	float cover = smoothstep(0.18, 1.05, slope + elevation * 0.32 + (0.5 - alpine_soil) * 0.32
		+ (patch - 0.5) * 0.24 + (rock_height - 0.5) * 0.35);
	cover = max(cover, talus * 0.95);
	float exposed = height_blend(moss_sample.a, rock_height, cover);
	// Needle litter and sheltered undergrowth connect the same stands as the tree cards.
	if (terrain_detail && max(abs(p.x), abs(p.y)) >= __MAP_HALF__) {
		float woodland = texture(forest_cover, (p + __MAP_HALF__ + 1400.0) / (__MAP_SIZE__ + 2800.0)).r;
		woodland *= forest_habitat(p, geology, slope);
		if (woodland > 0.001) {
			vec3 litter_uv = wpos / 3.0;
			vec4 litter = surface_color(4.0, litter_uv, weights);
			vec3 litter_n;
			vec2 litter_data = surface_data(4.0, litter_uv, weights, geometric, litter_n);
			float litter_blend = height_blend(moss_sample.a, litter.a, woodland * 0.9);
			float litter_luma = dot(litter.rgb, vec3(0.2126, 0.7152, 0.0722));
			vec3 floor_color = mix(vec3(litter_luma), litter.rgb, 0.25) * vec3(0.26, 0.30, 0.19);
			moss = mix(moss, floor_color, litter_blend);
			moss_data = mix(moss_data, litter_data, litter_blend);
			moss_n = normalize(mix(moss_n, litter_n, litter_blend));
		}
		exposed *= 1.0 - woodland * 0.85;
	}
	vec3 alpine = mix(moss, rock, exposed);
	float clean = (1.0 - wm.g) * (1.0 - wm.a) * (1.0 - clamp(bowl, 0.0, 1.0));
	col = mix(col, alpine, clean);
	// Broad deposits feather into sand before the wash line, rather than tracing a rocky stripe.
	float shore_stone = smoothstep(0.05, 0.6, wm.g) * (1.0 - smoothstep(0.65, 1.0, wm.g));
	shore_stone *= wm.b * (1.0 - wm.a) * (1.0 - step(9999.0, snow_line));
	shore_stone *= mix(0.18, 0.7, smoothstep(0.25, 0.75, patch * 0.6 + d1 * 0.4));
	vec3 shore_normal = geometric;
	float shore_roughness = 0.9;
	if (shore_stone > 0.001) {
		col = mix(col, shore_gravel_color(p) * (1.0 - wet_sand * 0.25), shore_stone);
		vec4 grain = texture(material_surfaces, vec3(p * 0.65, 5.0));
		vec3 grain_n = grain.rgb * 2.0 - 1.0;
		shore_normal = normalize(geometric + vec3(grain_n.x, 0.0, grain_n.y) * 0.18);
		shore_roughness = clamp(grain.a, 0.65, 1.0);
	}
	// Connected snowfields collect in sheltered bowls, leaving dark ribs and cliff faces.
	float local_snow_line = max(abs(p.x), abs(p.y)) >= __MAP_HALF__ ? max(150.0, snow_line * 1.5) : snow_line;
	float snow_field = (geology - local_snow_line) / 35.0 + cavity * 0.8 - geometric.x * 0.25 + (d1 - 0.5) * 0.3;
	snow_field -= min(3.0, max(0.0, slope - 0.75)) * 0.18;
	// Snow catches behind ribs and in surface depressions; exposed faces retain bare rock.
	float lee = clamp(dot(geometric.xz, normalize(vec2(0.8, 0.6))) + cavity, -1.0, 1.0);
	snow_field += smoothstep(0.08, 0.6, flow) * 0.65 + (macro - 0.5) * 0.45 + lee * 0.18 + (0.5 - rock_height) * 0.22;
	float snow = height_blend(rock_height, 0.6, smoothstep(-0.16, 0.20, snow_field));
	snow *= 1.0 - smoothstep(0.85, 2.1, slope);
	float scoured = smoothstep(0.46, 0.72, rock_sample.a * 0.38 + macro * 0.38 + patch * 0.24);
	snow *= 1.0 - scoured * smoothstep(0.22, 0.95, slope) * mix(0.88, 0.25, flow);
	snow = height_blend(rock_sample.a, scree_sample.a, snow);
	snow *= clean;
	// Wind ripples are resolved only while they cover several pixels.
	float snow_phase = dot(p, vec2(0.8, 0.6)) * 1.3 + (macro - 0.5) * 7.0 + patch * 9.0;
	float snow_resolved = 1.0 - smoothstep(0.5, 2.5, fwidth(snow_phase));
	float snow_ripple = sin(snow_phase) * snow_resolved * smoothstep(0.18, 0.65, macro) * 0.65;
	snow_ripple += sin(snow_phase * 0.47 + macro * 6.0) * (1.0 - smoothstep(0.5, 2.5, fwidth(snow_phase * 0.47))) * 0.35;
	vec3 snow_color = mix(vec3(0.65, 0.75, 0.84), vec3(0.88, 0.90, 0.92), smoothstep(-0.3, 0.6, lee + macro));
	vec3 snow_n = geometric;
	vec2 snow_data = vec2(1.0, mix(0.68, 0.94, macro));
	if (terrain_detail && snow > 0.001) {
		// Metre-scale powder and dirty melt edges stay separate from broad wind drifts.
		vec3 snow_uv = wpos / 2.0;
		vec4 powder = surface_color(3.0, snow_uv, weights);
		snow_data = surface_data(3.0, snow_uv, weights, geometric, snow_n);
		snow_color = min(powder.rgb * 1.8, vec3(0.9)) * mix(vec3(0.82, 0.90, 1.0), vec3(1.0), smoothstep(-0.3, 0.6, lee + macro));
		float melt = (1.0 - smoothstep(0.0, 0.7, snow_field)) * smoothstep(0.2, 0.8, rock_height);
		snow_color *= mix(vec3(1.0), vec3(0.64, 0.62, 0.59), melt * 0.55);
	}
	col = mix(col, snow_color * (0.94 + d3 * 0.06 + snow_ripple * 0.018), snow);
	vec2 material_data = mix(moss_data, rock_data, exposed);
	// Combine photographic crevices with broad shelter; do not bake a second direct-light shadow.
	float crevice = clamp(rock_data.x * mix(1.0, 0.72, shelter), 0.25, 1.0);
	float material_ao = mix(moss_data.x, crevice, exposed);
	AO = sky * mix(1.0, max(0.25, mix(material_ao, snow_data.x, snow)), clean);
	AO_LIGHT_AFFECT = 0.25;
	col *= mix(vec3(0.72, 0.80, 0.90), vec3(1.0), sky);

	// Thin low-altitude air separates ranges without whitening their sunlit faces.
	float optical_depth = max(0.0, distance(CAMERA_POSITION_WORLD, wpos) - 500.0) * terrain_air;
	float aerial = min(0.48, 1.0 - exp(-optical_depth * exp(-max(wpos.y, 0.0) / 520.0)));
	aerial *= smoothstep(__MAP_HALF__, __MAP_HALF__ + 200.0, edge);
	ALBEDO = col * (1.0 - aerial);
	EMISSION = air_color * aerial * 0.65;
	// Surface blends above are linear; Compatibility expects sRGB material output.
	if (OUTPUT_IS_SRGB) {
		ALBEDO = mix(ALBEDO * 12.92, 1.055 * pow(max(ALBEDO, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), ALBEDO));
	}
	ROUGHNESS = mix(mix(0.96, 0.82, dirt_m), clamp(material_data.y, 0.55, 1.0), clean);
	ROUGHNESS = mix(ROUGHNESS, clamp(snow_data.y + snow_ripple * 0.06, 0.6, 1.0), snow);
	rock_damp *= exposed * clean * (1.0 - snow);
	ROUGHNESS = mix(ROUGHNESS, 0.28, rock_damp);
	ROUGHNESS = mix(ROUGHNESS, 0.55, wet * 0.5);
	ROUGHNESS = mix(ROUGHNESS, mix(shore_roughness, 0.45, wet_sand), shore_stone);
	ROUGHNESS = mix(ROUGHNESS, 0.45, max(wm.a * 0.8, wet_sand * 0.6));
	ROUGHNESS = mix(ROUGHNESS, 0.16, puddle);
	SPECULAR = mix(0.25, 0.38, wet);
	float e = 0.12;
	float hc = hgt(p);
	float hx = hgt(p + vec2(e, 0.0));
	float hz = hgt(p + vec2(0.0, e));
	float bm = bump * mix(0.6, 1.4, dirt_m) * (1.0 + bowl * 1.5);
	vec3 n = normalize(vec3((hc - hx) * bm / e * 0.1, 1.0, (hc - hz) * bm / e * 0.1));
	// Small craters need the height field's quarter-metre spacing. Sampling
	// two metres either side can skip their walls and shade a dug bowl flat.
	float de = mix(max(2.0, normal_step), 0.25, smoothstep(0.002, 0.03, abs(hd)));
	float gx = (dfm(p + vec2(de, 0.0)) - dfm(p - vec2(de, 0.0))) / (2.0 * de);
	float gz = (dfm(p + vec2(0.0, de)) - dfm(p - vec2(0.0, de))) / (2.0 * de);
	n = normalize(n + vec3(-gx, 0.0, -gz));
	vec3 mapped = normalize(mix(moss_n, rock_n, exposed));
	n = normalize(mix(n, mapped, 0.85 * clean * (1.0 - snow)));
	n = surface_relief(n, mineral * 0.28, exposed * clean * (1.0 - snow) * smoothstep(0.3, 1.0, slope));
	n = normalize(mix(n, normalize(mix(geometric, snow_n, 0.6)), snow * 0.9));
	n = surface_relief(n, snow_ripple * 0.065 + scree_sample.a * 0.025, snow);
	n = normalize(mix(n, shore_normal, shore_stone));
	n = normalize(mix(n, vec3(0.0, 1.0, 0.0), puddle * 0.9));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
}

void light() {
	float cloud = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		vec2 cp = wpos.xz / 512.0 * 1.7 + vec2(TIME * 0.0016, TIME * 0.0007);
		float c = texture(biome_tex, cp).r;
		cloud = 1.0 - cloud_strength * smoothstep(0.48, 0.72, c);
		if (dot(LIGHT, normalize((VIEW_MATRIX * vec4(sun_direction, 0.0)).xyz)) > 0.95) {
			cloud *= terrain_sun;
		}
	}
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR / PI * cloud;
	// shortcut: Compatibility produces bright facets with this seepage lobe; retain colour and roughness until its lighting path is fixed.
	if (wet > 0.0 || (!OUTPUT_IS_SRGB && rock_damp > 0.0)) {
		vec3 hv = normalize(LIGHT + VIEW);
		float sp = pow(clamp(dot(NORMAL, hv), 0.0, 1.0), mix(16.0, 60.0, puddle));
		SPECULAR_LIGHT += sp * ATTENUATION * LIGHT_COLOR * (wet * (0.03 + puddle * 0.2) + (OUTPUT_IS_SRGB ? 0.0 : rock_damp * 0.045)) * cloud;
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
uniform sampler2DArray deform_tex : filter_linear, repeat_disable;
// TERRAIN_TEXTURE_HELPER
instance uniform float country = 0.0;
uniform sampler2D paving_noise : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D street_noise : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_surface : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_surface : filter_linear_mipmap_anisotropic, repeat_enable;
// STREET_SURFACE
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = terrain_geology(deform_tex, (wpos.xz + __MAP_HALF__) / __MAP_SIZE__);
	VERTEX.y += h; wpos.y += h;
}
void fragment() {
	if (texture(trench_mask, (wpos.xz + __MAP_HALF__) / __MAP_SIZE__).r > 0.5) {
		discard;
	}
	// a shell hole punches through the road surface
	if (terrain_height(deform_tex, (wpos.xz + __MAP_HALF__) / __MAP_SIZE__) - terrain_geology(deform_tex, (wpos.xz + __MAP_HALF__) / __MAP_SIZE__) < -0.07) {
		discard;
	}
	float x = UV.x;
	float n = texture(detail_tex, wpos.xz / 3.0).r;
	float n2 = texture(detail_tex, wpos.xz / 11.0 + 0.5).r;
	float n3 = texture(detail_tex, wpos.xz / 0.6 + 0.2).r;
	float road_wear = texture(street_noise, wpos.xz * 0.009 + 0.21).r;
	float wander = (road_wear - 0.5) * 0.10;
	float rut_width = mix(0.045, 0.095, n);
	float ruts = (smoothstep(rut_width, 0.0, abs(x - 0.3 - wander)) + smoothstep(rut_width, 0.0, abs(x - 0.7 - wander))) * mix(0.35, 1.0, smoothstep(0.2, 0.7, n2));
	vec3 gravel = texture(gravel_color, wpos.xz * 0.5).rgb;
	if (OUTPUT_IS_SRGB) { gravel = mix(gravel / 12.92, pow((gravel + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), gravel)); }
	gravel *= 0.48 + n * 0.24;
	vec3 dirt = mix(vec3(0.14, 0.11, 0.075), vec3(0.09, 0.07, 0.048), n);
	vec3 col = mix(dirt, gravel, country);
	float peb = smoothstep(0.6, 0.72, n3);
	col = mix(col, col * 1.25 + 0.02, peb * (0.25 + 0.3 * country));
	col = mix(col, col * 0.58, ruts * 0.75);
	// grass down the middle and at the verges
	float mid = smoothstep(0.11, 0.0, abs(x - 0.5)) * country;
	float verge = 1.0 - smoothstep(0.06, 0.2, min(x, 1.0 - x));
	float grass = clamp(mid * smoothstep(0.28, 0.62, road_wear) + verge * (0.45 + 0.9 * (n2 - 0.5)), 0.0, 1.0);
	col = mix(col, vec3(0.085, 0.11, 0.04) * (0.8 + 0.4 * n), grass * 0.85);
	col *= mix(0.65, 1.20, smoothstep(0.25, 0.70, road_wear));
	float pud = wet * smoothstep(0.5, 0.7, ruts * 0.7 + n2 * 0.55);
	col *= 1.0 - wet * 0.22;
	col = mix(col, col * 0.4, pud);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.75, ruts * 0.5), 0.1, pud);
	SPECULAR = mix(0.12, 0.45, pud);
	float edge = smoothstep(0.0, 0.14 + 0.1 * n, x) * smoothstep(1.0, 0.86 - 0.1 * n, x);
	ALPHA = edge;
	vec4 gravel_data = texture(gravel_surface, wpos.xz * 0.5);
	mat3 ground_basis = ground_surface_basis(wpos);
	vec3 gravel_n = gravel_data.rgb * 2.0 - 1.0;
	gravel_n.xy *= 0.24;
	NORMAL = normalize((VIEW_MATRIX * vec4(ground_basis * gravel_n, 0.0)).xyz);
	// in town: patched asphalt between the curbs, a dashed centre line
	vec2 inside = min(wpos.xz - town.xy, town.zw - wpos.xz);
	float distance = min(inside.x, inside.y);
	float broken_edge = (texture(street_noise, wpos.xz * 0.65).r - 0.5) * 0.6;
	float paved = smoothstep(-0.3, 0.35, distance + broken_edge) * country * step(1.0, town.z - town.x);
	if (paved > 0.001) {
		vec3 asph = street_surface(paving_noise, street_noise, wpos.xz);
		if (OUTPUT_IS_SRGB) { asph = mix(asph / 12.92, pow((asph + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), asph)); }
		float dash = step(abs(x - 0.5), 0.011) * step(fract(UV.y / 7.0), 0.5);
		asph = mix(asph, vec3(0.78, 0.74, 0.6) * (0.75 + 0.25 * n), dash * 0.8 * smoothstep(0.6, 0.95, paved));
		float wear = smoothstep(0.08, 0.0, abs(x - 0.27)) + smoothstep(0.08, 0.0, abs(x - 0.73));
		asph = mix(asph, asph * 0.85, wear * 0.4);
		float pud2 = wet * smoothstep(0.55, 0.75, n2 * 0.8);
		asph *= 1.0 - wet * 0.3;
		ALBEDO = mix(col, mix(asph, asph * 0.4, pud2), paved);
		vec4 surface = texture(paving_surface, wpos.xz / 2.2);
		vec3 normal = surface.rgb * 2.0 - 1.0;
		normal.xy *= 0.18;
		NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(ground_basis * normal, 0.0)).xyz, paved));
		ROUGHNESS = mix(ROUGHNESS, mix(clamp(surface.a, 0.65, 1.0) - wet * 0.3, 0.06, pud2), paved);
		SPECULAR = mix(SPECULAR, mix(0.3, 0.55, pud2), paved);
		ALPHA = mix(edge, 1.0, paved);
	}
	if (OUTPUT_IS_SRGB) { ALBEDO = mix(ALBEDO * 12.92, 1.055 * pow(max(ALBEDO, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), ALBEDO)); }
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
