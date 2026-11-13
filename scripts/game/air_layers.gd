class_name AirLayers
extends Node3D
## (view) The air between the camera and the far side of the battlefield, in
## layers, the way it lies on a real morning: mist hugging the ground, pooled
## in the hollows and along the water and torn into wisps by the wind; a haze
## aloft that the sun lights up, so where a cloud or a wood or a house stands
## in the sun's way it casts a shaft of shadow through it; and over each part
## of the map whatever the weather grid says is in the air there (WeatherGrid:
## the mist and rain the weather brings, the dust and the smoke the fighting
## raises).
##
## With volumetric fog (Settings "vol_fog", the desktop's renderer) it is one
## fog volume over the whole map with a fog shader of its own (AIR_SHADER),
## which reads the ground's height (the deformation tiles the ground draws
## with), the weather grid and a drifting noise for the wisps, and is lit by
## the sun through its shadows. Without it, and always in the browser (whose
## renderer has no volumetric fog), the plain fog stands in: the air at the
## camera's focus sets its density and colour, and a height fog lays the mist
## in the low ground (apply_env). Looks only: nothing here reaches the
## simulation (see WeatherGrid).

## Each mood's air: [mist's scale height (m), haze aloft (density a metre),
## how hard the sun lights the fog (its shafts), how much of the light the air
## throws on forward (fog anisotropy: low sun glows through the mist)].
const MOOD := {
	"day": [2.5, 0.0002, 0.8, 0.35],
	"golden": [3.0, 0.0005, 1.6, 0.6],
	"dawn": [4.0, 0.0006, 1.8, 0.62],
	"dusk": [3.5, 0.0005, 1.6, 0.6],
	"overcast": [4.0, 0.0003, 0.5, 0.3],
	"night": [3.5, 0.0004, 0.9, 0.5],
	"rain": [4.0, 0.0006, 0.4, 0.3],
	"hazy": [3.5, 0.0012, 1.4, 0.6],
}
## Densities (a metre) where the grid's channel is full: mist at the ground
## (a thin, dense band), and the far field's smoke, dust and rain (close up
## the smoke is SmokePlumes').
const MIST_D := 0.16
const SMOKE_D := 0.012
const DUST_D := 0.005
const RAIN_D := 0.003
## (sRGB) smoke a neutral grey with a little sky in it, dust a pale earth
const SMOKE_COL := Color(0.66, 0.67, 0.7)
const DUST_COL := Color(0.78, 0.73, 0.64)
## The volume reaches this far past the map's edge, thinning out to nothing.
const EDGE := 60.0
## How far the volumetric fog reaches from the camera (m): a little beyond
## what the command camera looks at, from close in to zoomed right out.
const LENGTH := Vector2(260.0, 760.0)

var atmo: Atmosphere
var world
var grid: WeatherGrid
var plumes: SmokePlumes  # the smoke hanging close up (volumetric fog only)
var volume: FogVolume
var mat: ShaderMaterial
var _mood := ""
var _haze := 0.0
var _mist_h := 6.0
## FL_DEBUG_AIR_AB: the GPU's time per frame with the layers and the caustics
## and without them, switched every two seconds in the same run (so another
## program's load falls on both alike); printed every twelve.
var _ab_on := OS.has_environment("FL_DEBUG_AIR_AB")
var _ab_state := 1
var _ab_t := 0.0
var _ab_skip := 0
var _ab_sum := [0.0, 0.0]
var _ab_n := [0, 0]
var _ab_switches := 0
## FL_DEBUG_AIR_FLIP=S: at S seconds of battle the battle stops still and the
## layers, plumes and caustics flip off and on every thirty frames, four times
## each, then the game quits: the same frozen moment with and without, for
## comparison pictures and flicker clips. Each block's first frame prints
## "AIR FLIP on|off <frame>".
var _flip_at := float(OS.get_environment("FL_DEBUG_AIR_FLIP")) if OS.has_environment("FL_DEBUG_AIR_FLIP") else -1.0
var _flip_frame := -1
var _debug_k := float(OS.get_environment("FL_DEBUG_AIR")) if OS.has_environment("FL_DEBUG_AIR") else 1.0  # thicken it all, to see where it lies


func setup(a: Atmosphere) -> void:
	atmo = a
	world = a.world
	name = "AirLayers"
	grid = WeatherGrid.new(world)
	if not Vfx.gl:
		_build_volume()
	apply_mood(atmo.mood)


## The fog volume over the map, and its shader (Forward+ only).
func _build_volume() -> void:
	mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MapDims.shader(AIR_SHADER.replace("// CLOUD_SHADOW", CloudShadow.PATTERN))
	mat.shader = sh
	var wn := FastNoiseLite.new()
	wn.seed = 23
	wn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wn.frequency = 0.06
	wn.fractal_type = FastNoiseLite.FRACTAL_FBM
	wn.fractal_octaves = 3
	var wisps := NoiseTexture3D.new()
	wisps.width = 64
	wisps.height = 32
	wisps.depth = 64
	wisps.seamless = true
	wisps.noise = wn
	mat.set_shader_parameter("wisps", wisps)
	plumes = SmokePlumes.new()
	add_child(plumes)
	plumes.setup(world, wisps)
	mat.set_shader_parameter("weather", grid.tex)
	mat.set_shader_parameter("wind", Vector2(Fires.WIND.x, Fires.WIND.z).normalized())
	mat.set_shader_parameter("mist_d", MIST_D)
	mat.set_shader_parameter("smoke_d", SMOKE_D)
	mat.set_shader_parameter("dust_d", DUST_D)
	mat.set_shader_parameter("rain_d", RAIN_D)
	mat.set_shader_parameter("edge", EDGE)
	volume = FogVolume.new()
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	volume.material = mat
	add_child(volume)
	_fit_volume()


## The volume from below the riverbeds to well above the highest ground.
func _fit_volume() -> void:
	if volume == null:
		return
	var peak: float = world.terrain.landform.peak if world.terrain and world.terrain.landform else 0.0
	var lo := -12.0
	var hi := maxf(peak, 0.0) + 320.0
	volume.size = Vector3(MapDims.SIZE + EDGE * 2.0, hi - lo, MapDims.SIZE + EDGE * 2.0)
	volume.position = Vector3(0.0, (hi + lo) * 0.5, 0.0)


## The ground has arrived (or changed a lot): the grid's hollows and the
## volume's reach follow it.
func survey() -> void:
	grid.survey()
	_fit_volume()
	if mat and atmo.deform_tex:
		mat.set_shader_parameter("deform_tex", atmo.deform_tex)
	if mat and world.water and not world.water.is_empty() and world.water.mask:
		# the water, softened over a few metres: the mist lies along it
		var near := (world.water.mask as Image).duplicate() as Image
		while near.get_width() > 256:
			near.shrink_x2()
		mat.set_shader_parameter("water_near", ImageTexture.create_from_image(near))


func apply_mood(m: String) -> void:
	_mood = m
	grid.mood = m
	var a: Array = MOOD.get(m, MOOD.day)
	_mist_h = float(a[0])
	_haze = float(a[1])
	atmo.sun.light_volumetric_fog_energy = float(a[2])
	atmo.env.volumetric_fog_anisotropy = float(a[3])
	# (the skylight in the air too: turned from the sun the mist is lit blue-grey
	# by the sky rather than going dark)
	atmo.env.volumetric_fog_ambient_inject = 0.3
	if mat == null:
		return
	var fog: Color = atmo._d.fog
	# (sRGB colours, as the moods' are: the mist near white, cooler at night;
	# the haze the colour of the mood's air; smoke a sooty grey, dust the
	# colour of dry earth)
	var night := m == "night"
	mat.set_shader_parameter("mist_col", Color(0.42, 0.48, 0.6) if night else fog.lerp(Color(0.95, 0.96, 0.98), 0.6))
	mat.set_shader_parameter("haze_col", fog.lerp(Color(0.92, 0.92, 0.92), 0.35))
	mat.set_shader_parameter("smoke_col", SMOKE_COL)
	mat.set_shader_parameter("dust_col", DUST_COL)
	mat.set_shader_parameter("rain_col", Color(0.55, 0.58, 0.62))
	mat.set_shader_parameter("mist_h", _mist_h)
	mat.set_shader_parameter("haze_d", _haze)


func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	if not grid.surveyed and world.loaded:
		survey()  # (a flat scenario map with no water never bakes a surface)
	grid.wet = maxf(atmo.rain_wet, 0.0)
	grid.tick(dt)
	if _ab_on:
		_ab(dt / maxf(Engine.time_scale, 0.0001))
	if _flip_at >= 0.0:
		_flip()
	if volume:
		var vol: bool = Settings.get_v("vol_fog") and _ab_state != 0
		volume.visible = vol
		if vol:
			mat.set_shader_parameter("drift", grid.drift)
			mat.set_shader_parameter("strength", strength() * _debug_k)
	if plumes:
		plumes.tick(dt, volume != null and volume.visible)
	if world:
		world.vp("air layers", t0)


func _ab(real_dt: float) -> void:
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	if _ab_skip > 0:
		_ab_skip -= 1
	else:
		_ab_sum[_ab_state] += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		_ab_n[_ab_state] += 1
	_ab_t += real_dt
	if _ab_t < 2.0:
		return
	_ab_t = 0.0
	_ab_skip = 6
	_show(1 - _ab_state)
	_ab_switches += 1
	if _ab_switches % 6 == 0 and _ab_n[0] > 0 and _ab_n[1] > 0:
		print("AIR A/B gpu: off %.2f ms (%d frames), on %.2f ms (%d frames)" % [_ab_sum[0] / _ab_n[0], _ab_n[0], _ab_sum[1] / _ab_n[1], _ab_n[1]])


## With (1) or without (0) everything this adds: the volume and plumes, the
## water's caustics, and (for the flip) the fog settings as they were before.
func _show(state: int) -> void:
	_ab_state = state
	var wv: WaterView = atmo.water_view
	if wv and wv.mat:
		wv.mat.set_shader_parameter("caustic_k", wv._caustic_k * state)
		if wv.caustics:
			wv.caustics.visible = state == 1 and wv._caustic_k > 0.0 and int(Settings.get_v("water")) >= 2
	if _flip_frame >= 0:
		if state == 1:
			apply_mood(_mood)
		else:
			atmo.sun.light_volumetric_fog_energy = 0.8
			atmo.env.volumetric_fog_anisotropy = 0.35
			atmo.env.volumetric_fog_ambient_inject = 0.0
			atmo.env.volumetric_fog_length = LENGTH.x


func _flip() -> void:
	if _flip_frame < 0:
		if world.time < _flip_at:
			return
		Engine.time_scale = 0.0
		_flip_frame = Engine.get_process_frames()
	var n := Engine.get_process_frames() - _flip_frame
	if n >= 240:
		get_tree().quit()
		return
	var state := 1 if (n / 30) % 2 == 0 else 0
	if n % 30 == 0:
		_show(state)
		print("AIR FLIP %s %d" % ["on" if state == 1 else "off", n])


## A blast (fx.gd's _explode): smoke and dust in the grid, and close up a
## plume of its own.
func blast(p: Vector3, size: float, wet: bool, above_ground: float) -> void:
	grid.blast(p, size, wet, above_ground)
	if plumes and not wet and above_ground < 25.0:
		plumes.blast(p, size)


## How much of the layers is drawn: all of it close in, thinning as the camera
## pulls back, so the air never veils the battle the player is looking at
## (haze is scenery, not concealment; see Atmosphere.HAZE_STRENGTH). Gentler
## than the plain haze's falloff, since the layers lie low and the camera
## looks down through them.
func strength() -> float:
	var d: float = world.cam.dist if world.cam else Atmosphere.HAZE_DISTANCE
	return clampf(90.0 / maxf(d, 1.0), 0.45, 1.0)


## The plain fog's share (Atmosphere._apply_haze, after its own): the air at
## the camera's focus thickens and tints the distance fog, and a height fog
## lays the mist in the ground below it. It stands in for the volume where
## there isn't one, and only lays the low mist in the far distance (beyond the
## volume's reach) where there is.
func apply_env(env: Environment) -> void:
	if world.cam == null:
		return
	var focus: Vector3 = world.cam.focus_pos
	var air := grid.sample(focus)
	var vol: bool = volume != null and volume.visible
	var s := strength()
	var mist := air.x
	var murk := air.w * 1.4 + air.z
	var fog: Color = atmo._d.fog
	env.fog_light_color = fog
	if _flip_frame >= 0 and _ab_state == 0:
		return  # (flipped off: the plain fog as it was)
	if not vol:
		env.fog_density += (mist * 0.0008 + murk * 0.0014 + air.y * 0.001 + _haze * 0.4) * s
		var tint: Color = SMOKE_COL.lerp(DUST_COL, air.z / maxf(murk, 0.001))
		env.fog_light_color = fog.lerp(tint, clampf(murk * 0.8, 0.0, 0.6))
	else:
		env.volumetric_fog_length = clampf(world.cam.dist * 2.4, LENGTH.x, LENGTH.y)
	# the mist lying along the valley floor
	# (drawn per pixel, this band stays a few metres thick however far off it
	# lies, where the volume's cells have grown too coarse to hold it)
	var valley: float = float((WeatherGrid.MOOD_AIR.get(_mood, WeatherGrid.MOOD_AIR.day) as Array)[1]) + grid.wet * 0.25
	var hd := valley * 0.12 * s * grid.relief
	if hd > env.fog_height_density:
		env.fog_height = grid.floor_y + _mist_h
		env.fog_height_density = hd


## The --stats line: how much is in the air.
func stats_text() -> String:
	var t := grid.totals()
	return "AIR mist=%.2f rain=%.2f dust=%.3f smoke=%.3f plumes=%d" % [t.x, t.y, t.z, t.w, plumes.count() if plumes else 0]


const AIR_SHADER := """
shader_type fog;

uniform sampler2DArray deform_tex : filter_linear, repeat_disable;
uniform sampler2D weather : filter_linear, repeat_disable;
uniform sampler2D water_near : hint_default_transparent, filter_linear, repeat_disable;
uniform sampler3D wisps : filter_linear, repeat_enable;
uniform vec2 drift = vec2(0.0);  // the weather grid's drift downwind (m)
uniform vec2 wind = vec2(0.92, 0.38);
uniform float strength = 1.0;  // how much of it the camera's distance lets through
uniform float mist_d = 0.03;
uniform float mist_h = 6.0;
uniform float haze_d = 0.0005;
uniform float smoke_d = 0.03;
uniform float dust_d = 0.028;
uniform float rain_d = 0.003;
uniform float edge = 60.0;
uniform vec3 mist_col : source_color = vec3(0.9);
uniform vec3 haze_col : source_color = vec3(0.8);
uniform vec3 smoke_col : source_color = vec3(0.3);
uniform vec3 dust_col : source_color = vec3(0.6, 0.5, 0.36);
uniform vec3 rain_col : source_color = vec3(0.55);
// CLOUD_SHADOW
// TERRAIN_TEXTURE_HELPER

void fog() {
	vec3 p = WORLD_POSITION;
	float g = terrain_height(deform_tex, (p.xz + __MAP_HALF__) / __MAP_SIZE__);
	float h = max(p.y - g, 0.0);
	vec4 w = texture(weather, (p.xz - drift + __MAP_HALF__) / __MAP_SIZE__);
	// wisps: a broad drift of thicker and thinner air, and finer curls in it,
	// carried along by the wind
	float n1 = texture(wisps, p * vec3(0.006, 0.02, 0.006) - vec3(wind.x, -0.15, wind.y) * TIME * 0.0035).r;
	float n2 = texture(wisps, p * vec3(0.025, 0.06, 0.025) - vec3(wind.x, 0.1, wind.y) * TIME * 0.012).r;
	float wisp = smoothstep(0.3, 0.72, n1) * 1.3 + (n2 - 0.5) * 0.6;
	wisp = clamp(wisp, 0.0, 1.6);
	// (smoke and dust hang in puffs and rags a few metres across, rising as they go)
	float rag = smoothstep(0.35, 0.7, texture(wisps, p * vec3(0.06, 0.09, 0.06) - vec3(wind.x, 0.4, wind.y) * TIME * 0.03).r);
	// the mist, thinning upward from the ground; the haze, clear of the ground
	// and fading out aloft; smoke billowing higher than dust
	// the mist: a thin band, lying where the ground is lower than round about
	// (and along the water), so it fills the valley and the hollows and leaves
	// the rises clear
	float mist = 0.0;
	if (h < mist_h * 6.0 && w.r > 0.002) {
		vec2 uv = (p.xz + __MAP_HALF__) / __MAP_SIZE__;
		float o = 36.0 / __MAP_SIZE__;
		float around = (terrain_height(deform_tex, uv + vec2(o, 0.0)) + terrain_height(deform_tex, uv - vec2(o, 0.0))
			+ terrain_height(deform_tex, uv + vec2(0.0, o)) + terrain_height(deform_tex, uv - vec2(0.0, o))) * 0.25;
		float hollow = clamp((around - g) / 5.0, 0.0, 1.0);
		float lie = 0.12 + 1.4 * max(hollow, texture(water_near, uv).a);
		mist = mist_d * w.r * lie * exp(-h / mist_h) * wisp;
	}
	float haze = haze_d * smoothstep(8.0, 40.0, h) * exp(-max(h - 40.0, 0.0) / 220.0) * (0.6 + 0.8 * n1);
	float smoke = smoke_d * w.a * exp(-h / 14.0) * (0.05 + wisp * 0.3 + rag * 1.3);
	float dust = dust_d * w.b * exp(-h / 8.0) * (0.05 + wisp * 0.3 + rag * 1.3);
	float rain = rain_d * w.g * exp(-h / 150.0);
	float total = mist + haze + smoke + dust + rain;
	vec2 inside = vec2(__MAP_HALF__ + edge) - abs(p.xz);
	DENSITY = total * strength * clamp(min(inside.x, inside.y) / edge, 0.0, 1.0);
	vec3 col = (mist_col * mist + haze_col * haze + smoke_col * smoke + dust_col * dust + rain_col * rain) / max(total, 1e-6);
	// under a cloud the air isn't sunlit: follow the sun's ray down to the
	// ground's shadow pattern, so the clouds cast shafts through the haze
	vec3 to_sun = cloud_sun_disc.xyz;
	float shade = cloud_sun(p - to_sun * (h / max(to_sun.y, 0.2)));
	ALBEDO = col * mix(1.0, shade, 0.75);
}
"""
