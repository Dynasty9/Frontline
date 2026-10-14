class_name Vfx
extends Node3D
## GPU particle effects. Explosions are layered (flash, fireball that cools
## into smoke, smoke column, dirt plume, sparks, bouncing debris, ground dust
## ring, heat-shimmer shockwave, scorch decal). Smoke sprites are lit like
## little volumes (sun + sky, self-shadowing from noise) and fade softly
## where they touch geometry. Particle counts follow Settings.fx_mult().

const CLASSES := {
	# scale, fireball n/life, smoke n/life, dirt n, sparks n, debris n, ring n, ejecta n, earth column n
	"s": {"k": 0.55, "fb": 8, "fbl": 0.8, "sm": 10, "sml": 4.5, "dirt": 14, "sp": 14, "deb": 10, "ring": 10, "ej": 8, "col": 0},
	"m": {"k": 1.0, "fb": 14, "fbl": 1.2, "sm": 20, "sml": 6.5, "dirt": 38, "sp": 30, "deb": 30, "ring": 18, "ej": 18, "col": 14},
	"l": {"k": 1.9, "fb": 24, "fbl": 1.9, "sm": 20, "sml": 8.0, "dirt": 36, "sp": 50, "deb": 56, "ring": 22, "ej": 30, "col": 26},
}
const MAX_RIGS := {"s": 22, "m": 16, "l": 10}
## Lingering plumes: [scale, column particles, column life, haze particles, haze life, seconds of emission]
const PLUMES := {"M": [1.0, 30, 13.0, 6, 16.0, 7.0], "L": [1.7, 52, 20.0, 10, 24.0, 16.0]}
const MAX_PLUMES := {"M": 8, "L": 6}
const SMALL_KINDS := ["dust", "smoke", "fire", "spark", "dirt_spurt", "brass"]

var world: World
var noise_tex: ImageTexture
var scorch_tex: ImageTexture
var smoke_mat: ShaderMaterial
var flash_mat: ShaderMaterial
var spark_mat: ShaderMaterial
var tracer_mat: ShaderMaterial
var wave_mat: ShaderMaterial
var debris_mat: StandardMaterial3D
var ejecta_mat: ShaderMaterial
var quad: QuadMesh
var _rigs := {"s": [], "m": [], "l": []}
var _small := {}  # kind -> [array, index]
var _waves: Array = []  # [mi, t, size]
var _wave_pool: Array = []
var _decals: Array = []  # [decal, t, life]
var _burners: Array = []  # [node, target, t, life]
var _smokes: Array = []
var _plumes := {"M": [], "L": []}  # [node, t, emit seconds, life] - smoke that hangs over a strike
var _late_clods: Array = []  # [pos, size, t] clods that land once the debris comes down
var _rig_check_t := 0.0


func _ready() -> void:
	quad = QuadMesh.new()
	quad.size = Vector2(1, 1)
	_make_textures()
	_make_materials()
	var col := GPUParticlesCollisionBox3D.new()
	col.size = Vector3((MapDims.HALF + 132.0) * 2.0, 20, (MapDims.HALF + 132.0) * 2.0)
	col.position = Vector3(0, -10.0, 0)
	add_child(col)
	for kind in SMALL_KINDS:
		_small[kind] = [[], 0]
	for i in 8:
		var w := MeshInstance3D.new()
		w.mesh = Res.sphere(1.0, 20)
		w.material_override = wave_mat
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.visible = false
		add_child(w)
		_wave_pool.append(w)


## Draws every effect once out of sight (under the ground, inside the view) so
## shaders and particle programs compile during loading, not mid-battle.
func prewarm(at: Vector3) -> void:
	var p := at + Vector3(0, -30.0, 0)
	for cls in ["s", "m", "l"]:
		var rig := _get_rig(cls)
		rig.global_position = p
		for key in rig.get_meta("layers"):
			_fire_layer(rig.get_meta("layers")[key], 1.0, 0.0)
	for kind in SMALL_KINDS:
		puff(kind, p)
	plume(p, 1.0)
	plume(p + Vector3(20, 0, 0), 2.4)
	var b := make_burner(1.0)
	add_child(b)
	b.global_position = p
	burn_for(b, 1.0, 1.0)
	var ss := make_smoke_screen()
	add_child(ss)
	ss.global_position = p
	set_smoke_screen(ss, 3.0)
	var tr := make_trail()
	add_child(tr)
	tr.global_position = p
	_shockwave(p, 1.0)
	scorch(p, 1.0)
	# hide everything again once compiled: the prewarm smoke would otherwise
	# drift up out of the ground as stray puffs
	get_tree().create_timer(0.6).timeout.connect(func():
		for cls in ["s", "m", "l"]:
			for r in _rigs[cls]:
				for key in r.get_meta("layers"):
					(r.get_meta("layers")[key] as GPUParticles3D).visible = false
		for kind in SMALL_KINDS:
			for e in _small[kind][0]:
				(e as GPUParticles3D).visible = false
		for cls in _plumes:
			for e in _plumes[cls]:
				e[1] = 9999.0
				for key in ["col", "haze"]:
					var ps: GPUParticles3D = (e[0] as Node3D).get_meta(key)
					ps.emitting = false
					ps.visible = false
		b.queue_free()
		ss.queue_free()
		tr.queue_free())


# --- textures & materials ------------------------------------------------------

func _make_textures() -> void:
	var sz := 256
	var a := FastNoiseLite.new()
	a.noise_type = FastNoiseLite.TYPE_PERLIN
	a.frequency = 0.02
	a.fractal_type = FastNoiseLite.FRACTAL_FBM
	a.fractal_octaves = 5
	var b := FastNoiseLite.new()
	b.noise_type = FastNoiseLite.TYPE_CELLULAR
	b.frequency = 0.03
	b.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	b.fractal_type = FastNoiseLite.FRACTAL_FBM
	b.fractal_octaves = 3
	var c := FastNoiseLite.new()
	c.noise_type = FastNoiseLite.TYPE_SIMPLEX
	c.frequency = 0.05
	c.fractal_type = FastNoiseLite.FRACTAL_FBM
	c.fractal_octaves = 4
	c.seed = 7
	var ia := a.get_seamless_image(sz, sz, false, false, 0.2, true)
	var ib := b.get_seamless_image(sz, sz, false, false, 0.2, true)
	var ic := c.get_seamless_image(sz, sz, false, false, 0.2, true)
	var img := Image.create(sz, sz, false, Image.FORMAT_RGB8)
	for y in sz:
		for x in sz:
			img.set_pixel(x, y, Color(ia.get_pixel(x, y).r, 1.0 - ib.get_pixel(x, y).r, ic.get_pixel(x, y).r))
	img.generate_mipmaps()
	noise_tex = ImageTexture.create_from_image(img)
	# scorch mark: dark centre, ragged edge, soot streaks
	var ss := 128
	var simg := Image.create(ss, ss, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.frequency = 0.06
	n.fractal_octaves = 4
	for y in ss:
		for x in ss:
			var p := Vector2(x - ss * 0.5, y - ss * 0.5) / (ss * 0.5)
			var r := p.length()
			var ang := atan2(p.y, p.x)
			var streak := 0.5 + 0.5 * sin(ang * 9.0 + n.get_noise_2d(x * 0.5, y * 0.5) * 4.0)
			var edge := 0.62 + n.get_noise_2d(x, y) * 0.35 + streak * 0.12
			var al := clampf((edge - r) / 0.25, 0.0, 1.0)
			al *= 0.75 + 0.25 * (n.get_noise_2d(x * 3.0, y * 3.0) * 0.5 + 0.5)
			var cr := clampf(1.0 - r / 0.35, 0.0, 1.0)
			var v := 0.03 + 0.05 * (1.0 - al) + n.get_noise_2d(x * 4.0, y * 4.0) * 0.015
			simg.set_pixel(x, y, Color(v + 0.012, v + 0.008, v, al * (0.9 + cr * 0.1)))
	simg.generate_mipmaps()
	scorch_tex = ImageTexture.create_from_image(simg)
	_make_crater_textures()


var crater_tex: ImageTexture
var crater_nrm: ImageTexture
var _craters: Array = []
var _clods: MultiMeshInstance3D
var _clod_n := 0
const MAX_CLODS := 2400


## Crater decal: churned dark soil in a bowl with a raised, broken rim. The
## normal map gives the bowl its depth from above; the albedo darkens the
## exposed earth.
func _make_crater_textures() -> void:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var nrm := Image.create(n, n, false, Image.FORMAT_RGB8)
	var fn := FastNoiseLite.new()
	fn.frequency = 0.08
	fn.fractal_octaves = 4
	var hgt := PackedFloat32Array()
	hgt.resize(n * n)
	for y in n:
		for x in n:
			var p := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var nz := fn.get_noise_2d(x, y)
			var r := p.length() * (1.0 + nz * 0.12)
			var bowl := -(1.0 - clampf(r / 0.72, 0.0, 1.0) ** 2) * 0.9
			var rim := exp(-pow((r - 0.8) / 0.11, 2.0)) * 0.45
			hgt[y * n + x] = bowl + rim + nz * 0.08
	for y in n:
		for x in n:
			var p2 := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5) / (n * 0.5)
			var r2 := p2.length()
			var hx := hgt[y * n + mini(x + 1, n - 1)] - hgt[y * n + maxi(x - 1, 0)]
			var hy := hgt[mini(y + 1, n - 1) * n + x] - hgt[maxi(y - 1, 0) * n + x]
			var nv := Vector3(-hx * 3.0, -hy * 3.0, 1.0).normalized()
			nrm.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5))
			var nz2 := fn.get_noise_2d(x * 2.0 + 50.0, y * 2.0)
			var inner := 1.0 - smoothstep(0.55, 0.8, r2)
			var a := clampf((1.0 - smoothstep(0.82, 1.0, r2 + nz2 * 0.15)), 0.0, 1.0)
			var v := lerpf(0.2, 0.11, inner) + nz2 * 0.03
			img.set_pixel(x, y, Color(v * 1.15, v * 0.95, v * 0.72, a * (0.75 + 0.25 * inner)))
	img.generate_mipmaps()
	nrm.generate_mipmaps()
	crater_tex = ImageTexture.create_from_image(img)
	crater_nrm = ImageTexture.create_from_image(nrm)


## A permanent crater where a shell hit open ground, with clods of earth thrown around it.
func crater(p: Vector3, size: float) -> void:
	if world and world.terrain and world.terrain.deform_img:
		# the ground mesh is dug out by the terrain heights: just the thrown clods and the scorched grass
		_late_clods.append([p, size, 0.9 + 0.35 * size])
		if world.atmo and world.atmo.grass:
			world.atmo.grass.scar(p, 0.9 + 0.95 * size, 1.0)
		return
	var d := 1.4 + 1.5 * size
	var dc := Decal.new()
	dc.texture_albedo = crater_tex
	dc.texture_normal = crater_nrm
	dc.size = Vector3(d, 1.2, d)
	dc.upper_fade = 0.3
	dc.lower_fade = 0.3
	dc.normal_fade = 0.2
	dc.distance_fade_enabled = true
	dc.distance_fade_begin = 190.0
	dc.distance_fade_length = 40.0
	dc.cull_mask = 1
	add_child(dc)
	dc.global_position = Vector3(p.x, 0.0, p.z)
	dc.rotation.y = randf() * TAU
	_craters.append(dc)
	if _craters.size() > 260:
		_craters.pop_front().queue_free()
	# the clods land once the thrown earth has come back down
	_late_clods.append([p, size, 0.9 + 0.35 * size])
	if world and world.atmo and world.atmo.grass:
		world.atmo.grass.scar(p, 0.9 + 0.95 * size, 1.0)


func _add_clods(p: Vector3, size: float) -> void:
	if _clods == null:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var bm := SphereMesh.new()
		bm.radius = 0.5
		bm.height = 0.7
		bm.radial_segments = 6
		bm.rings = 3
		mm.mesh = bm
		mm.instance_count = MAX_CLODS
		mm.visible_instance_count = 0
		_clods = MultiMeshInstance3D.new()
		_clods.multimesh = mm
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 1.0
		_clods.material_override = m
		_clods.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(_clods)
	var mm2 := _clods.multimesh
	var cnt := int(12 + 16 * size * Settings.fx_mult())
	for i in cnt:
		var a := randf() * TAU
		# most close to the rim, a few thrown far out
		var r := (0.7 + 0.75 * size) * (randf_range(0.7, 1.6) if randf() < 0.75 else randf_range(1.6, 4.5))
		var s := randf_range(0.07, 0.22) * (0.7 + size * 0.4) * (1.0 if r < 3.0 * size else 0.6)
		var b := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)).scaled(Vector3(s, s, s))
		var slot := _clod_n % MAX_CLODS
		var cp := Vector3(p.x + cos(a) * r, 0.0, p.z + sin(a) * r)
		var gy: float = world.terrain.deform_at(cp) if world and world.terrain else 0.0
		mm2.set_instance_transform(slot, Transform3D(b, Vector3(cp.x, gy + s * 0.25, cp.z)))
		var k := randf_range(0.7, 1.1)
		mm2.set_instance_color(slot, Color(0.2 * k, 0.16 * k, 0.11 * k))
		_clod_n += 1
	mm2.visible_instance_count = mini(_clod_n, MAX_CLODS)


func _make_materials() -> void:
	smoke_mat = _shader_mat(SMOKE_SHADER)
	smoke_mat.set_shader_parameter("noise_tex", noise_tex)
	flash_mat = _shader_mat(FLASH_SHADER)
	spark_mat = _shader_mat(SPARK_SHADER)
	tracer_mat = _shader_mat(TRACER_SHADER)
	wave_mat = _shader_mat(WAVE_SHADER)
	ejecta_mat = _shader_mat(EJECTA_SHADER)
	debris_mat = StandardMaterial3D.new()
	debris_mat.vertex_color_use_as_albedo = true
	debris_mat.roughness = 0.95
	apply_lighting()


func _shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Copies the scene's sun / sky light into the smoke shader.
func apply_lighting() -> void:
	var at: Atmosphere = world.atmo if world else null
	if at == null or at.sun == null:
		return
	var sd := at.sun.global_transform.basis.z.normalized()
	# smoke takes the light's colour only partly: fully tinted it goes navy at
	# night and brick red at sunset
	var sc := _desat(at.sun.light_color, 0.45)
	var hz: Color = at.MOODS[at.mood].horizon
	var zn: Color = at.MOODS[at.mood].zenith
	var amb := _desat(hz.lerp(zn, 0.4), 0.55)
	var night := at.mood == "night"
	smoke_mat.set_shader_parameter("sun_dir", sd)
	smoke_mat.set_shader_parameter("sun_col", sc)
	smoke_mat.set_shader_parameter("sun_energy", at.sun.light_energy * (0.45 if night else 0.75))
	smoke_mat.set_shader_parameter("amb_col", amb)
	smoke_mat.set_shader_parameter("amb_energy", float(at.MOODS[at.mood].ambient) * (0.6 if night else 1.1))
	ejecta_mat.set_shader_parameter("light", sc * at.sun.light_energy * 0.45 + amb * float(at.MOODS[at.mood].ambient) * 0.7)


func _desat(c: Color, k: float) -> Color:
	var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
	return c.lerp(Color(l, l, l), k)


# --- particle helpers -------------------------------------------------------------

func _curve(pts: Array) -> CurveTexture:
	var c := Curve.new()
	for p in pts:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


func _ramp(offsets: Array, colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _sys(amount: int, life: float, pm: ParticleProcessMaterial, mat: Material, mesh: Mesh = null) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(1, amount)
	p.lifetime = life
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.92
	p.randomness = 0.3
	p.local_coords = false
	p.process_material = pm
	p.draw_pass_1 = mesh if mesh else quad
	p.material_override = mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 60, 60))
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	return p


func _pm(dir: Vector3, spread: float, v0: float, v1: float, grav: Vector3, s0: float, s1: float) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = v0
	pm.initial_velocity_max = v1
	pm.gravity = grav
	pm.scale_min = s0
	pm.scale_max = s1
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.lifetime_randomness = 0.35
	return pm


# --- explosion rigs ----------------------------------------------------------------

func _build_rig(cls: String) -> Node3D:
	var c: Dictionary = CLASSES[cls]
	var k: float = c.k
	var rig := Node3D.new()
	add_child(rig)
	var layers := {}
	# 1. flash
	var pm := _pm(Vector3.UP, 0.0, 0.0, 0.0, Vector3.ZERO, 6.5 * k, 8.0 * k)
	pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.3)])
	pm.color_ramp = _ramp([0.0, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var fl := _sys(1, 0.09, pm, flash_mat)
	fl.explosiveness = 1.0
	layers["flash"] = fl
	# 2. fireball: hot billows that cool into dark smoke
	pm = _pm(Vector3.UP, 70.0, 3.5 * k, 9.0 * k, Vector3(0, 3.0, 0), 1.9 * k, 3.2 * k)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5 * k
	pm.damping_min = 7.0
	pm.damping_max = 11.0
	pm.angular_velocity_min = -50.0
	pm.angular_velocity_max = 50.0
	pm.scale_curve = _curve([Vector2(0, 0.3), Vector2(0.12, 0.85), Vector2(1, 1.15)])
	pm.color_ramp = _ramp([0.0, 0.05, 0.5, 1.0], [Color(0.11, 0.1, 0.09, 0.0), Color(0.11, 0.1, 0.09, 1.0), Color(0.15, 0.14, 0.13, 0.85), Color(0.22, 0.21, 0.2, 0.0)])
	var fb := _sys(c.fb, c.fbl, pm, smoke_mat)
	fb.explosiveness = 0.98
	fb.set_instance_shader_parameter("heat", 1.6)
	fb.set_instance_shader_parameter("heat_fade", 0.22)
	fb.set_instance_shader_parameter("density", 1.5)
	layers["fireball"] = fb
	# 3. smoke column drifting with the wind
	pm = _pm(Vector3.UP, 16.0, 1.2 * k, 4.2 * k, Vector3(0.38, 0.55, 0.16), 1.9 * k, 3.1 * k)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.7 * k
	pm.damping_min = 0.7
	pm.damping_max = 1.4
	pm.angular_velocity_min = -10.0
	pm.angular_velocity_max = 10.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 7.0
	pm.turbulence_influence_min = 0.015
	pm.turbulence_influence_max = 0.05
	pm.scale_curve = _curve([Vector2(0, 0.3), Vector2(0.25, 0.7), Vector2(1, 1.25)])
	pm.color_ramp = _ramp([0.0, 0.07, 0.3, 0.65, 1.0], [Color(0.12, 0.115, 0.11, 0.0), Color(0.13, 0.125, 0.12, 0.85), Color(0.2, 0.195, 0.19, 0.6), Color(0.3, 0.295, 0.29, 0.3), Color(0.38, 0.375, 0.37, 0.0)])
	pm.color_initial_ramp = _ramp([0.0, 1.0], [Color(0.8, 0.8, 0.8), Color(1.15, 1.12, 1.1)])
	var sm := _sys(c.sm, c.sml, pm, smoke_mat)
	sm.explosiveness = 0.75
	sm.set_instance_shader_parameter("heat", 0.35)
	sm.set_instance_shader_parameter("heat_fade", 0.08)
	sm.set_instance_shader_parameter("density", 1.0)
	layers["smoke"] = sm
	# 4. dirt plume thrown up from the ground
	pm = _pm(Vector3.UP, 16.0, 8.0 * k, 21.0 * sqrt(k), Vector3(0, -3.2, 0), 0.9 * k, 2.6 * k)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.45 * k
	pm.damping_min = 5.0
	pm.damping_max = 8.5
	pm.angular_velocity_min = -30.0
	pm.angular_velocity_max = 30.0
	pm.scale_curve = _curve([Vector2(0, 0.35), Vector2(0.3, 0.9), Vector2(1, 1.3)])
	pm.color_ramp = _ramp([0.0, 0.03, 0.4, 1.0], [Color(0.12, 0.095, 0.07, 0.0), Color(0.12, 0.095, 0.07, 1.0), Color(0.21, 0.18, 0.145, 0.8), Color(0.32, 0.29, 0.25, 0.0)])
	pm.color_initial_ramp = _ramp([0.0, 1.0], [Color(0.75, 0.75, 0.75), Color(1.25, 1.2, 1.15)])
	var dt := _sys(c.dirt, 3.4, pm, smoke_mat)
	dt.explosiveness = 0.97
	dt.set_instance_shader_parameter("density", 1.6)
	dt.set_instance_shader_parameter("erode", 1.5)
	layers["dirt"] = dt
	# 4b. heavy rounds: a fountain of earth thrown high that falls back to the ground
	if int(c.col) > 0:
		pm = _pm(Vector3.UP, 10.0, 11.0 * sqrt(k), 22.0 * sqrt(k), Vector3(0, -9.8, 0), 0.9 * k, 2.3 * k)
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.6 * k
		pm.damping_min = 0.4
		pm.damping_max = 1.4
		pm.angular_velocity_min = -40.0
		pm.angular_velocity_max = 40.0
		pm.scale_curve = _curve([Vector2(0, 0.45), Vector2(0.3, 1.0), Vector2(1, 1.7)])
		pm.color_ramp = _ramp([0.0, 0.04, 0.55, 1.0], [Color(0.09, 0.075, 0.055, 0.0), Color(0.1, 0.082, 0.06, 1.0), Color(0.17, 0.14, 0.11, 0.8), Color(0.3, 0.27, 0.23, 0.0)])
		pm.color_initial_ramp = _ramp([0.0, 1.0], [Color(0.8, 0.8, 0.8), Color(1.2, 1.15, 1.1)])
		var co := _sys(c.col, 3.6, pm, smoke_mat)
		co.explosiveness = 0.94
		co.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 70, 60))
		co.set_instance_shader_parameter("density", 1.5)
		co.set_instance_shader_parameter("erode", 1.4)
		layers["column"] = co
	# 5. sparks / hot fragments
	pm = _pm(Vector3.UP, 85.0, 12.0 * sqrt(k), 30.0 * sqrt(k), Vector3(0, -9.8, 0), 0.6, 1.3)
	pm.angle_min = 0.0
	pm.angle_max = 0.0
	pm.damping_min = 1.0
	pm.damping_max = 3.0
	pm.particle_flag_align_y = true
	pm.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	pm.collision_bounce = 0.35
	pm.collision_friction = 0.4
	pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	pm.color_ramp = _ramp([0.0, 1.0], [Color(1, 1, 1, 1), Color(1, 0.6, 0.3, 0)])
	var spm := QuadMesh.new()
	spm.size = Vector2(0.05, 0.9)
	var sp := _sys(c.sp, 0.9, pm, spark_mat, spm)
	sp.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	sp.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
	layers["sparks"] = sp
	# 6. debris chunks that bounce on the ground
	pm = _pm(Vector3.UP, 50.0, 5.0 * sqrt(k), 16.0 * sqrt(k), Vector3(0, -18.0, 0), 0.45 * sqrt(k), 1.7 * sqrt(k))
	pm.particle_flag_rotate_y = true
	pm.angular_velocity_min = -720.0
	pm.angular_velocity_max = 720.0
	pm.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	pm.collision_bounce = 0.25
	pm.collision_friction = 0.7
	pm.collision_use_scale = true
	pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(0.9, 1.0), Vector2(1, 0.0)])
	pm.scale_min = 0.35 * sqrt(k)
	pm.scale_max = 2.1 * sqrt(k)
	# clods of earth, mostly dark, with the odd lighter stone among them
	pm.color_ramp = _ramp([0.0, 1.0], [Color(0.2, 0.16, 0.12), Color(0.17, 0.14, 0.1)])
	pm.color_initial_ramp = _ramp([0.0, 0.55, 0.8, 0.9, 1.0], [Color(0.55, 0.5, 0.45), Color(0.8, 0.72, 0.62), Color(0.95, 0.85, 0.72), Color(1.6, 1.55, 1.5), Color(1.9, 1.85, 1.8)])
	var dm := SphereMesh.new()
	dm.radius = 0.09
	dm.height = 0.12
	dm.radial_segments = 5
	dm.rings = 2
	var db := _sys(c.deb, 5.5, pm, debris_mat, dm)
	db.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
	db.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	layers["debris"] = db
	# 6b. ejecta: streaks of earth flung out in a cone, trailing dust as they arc and fall
	pm = _pm(Vector3.UP, 30.0, 11.0 * sqrt(k), 24.0 * sqrt(k), Vector3(0, -15.0, 0), 0.8 * k, 1.5 * k)
	pm.angle_min = 0.0
	pm.angle_max = 0.0
	pm.damping_min = 0.6
	pm.damping_max = 1.6
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	pm.color_ramp = _ramp([0.0, 0.7, 1.0], [Color(0.06, 0.05, 0.04, 1.0), Color(0.14, 0.12, 0.1, 0.75), Color(0.25, 0.22, 0.18, 0.0)])
	var rib := RibbonTrailMesh.new()
	rib.shape = RibbonTrailMesh.SHAPE_CROSS
	rib.size = 0.38
	rib.sections = 6
	rib.section_length = 0.3
	rib.section_segments = 1
	var wc := Curve.new()
	wc.add_point(Vector2(0, 0.15))
	wc.add_point(Vector2(1, 1.0))
	rib.curve = wc
	var ej := _sys(c.ej, 1.6, pm, ejecta_mat, rib)
	ej.trail_enabled = true
	ej.trail_lifetime = 0.3
	ej.explosiveness = 1.0
	ej.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
	layers["ejecta"] = ej
	# 7. ground dust ring rolling outward
	pm = _pm(Vector3(1, 0, 0), 180.0, 7.0 * k, 11.0 * k, Vector3(0, 0.3, 0), 1.4 * k, 2.4 * k)
	pm.flatness = 1.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 1.2 * k
	pm.emission_ring_inner_radius = 0.6 * k
	pm.emission_ring_height = 0.1
	pm.damping_min = 6.0
	pm.damping_max = 9.0
	pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 1.0)])
	pm.color_ramp = _ramp([0.0, 0.1, 1.0], [Color(0.42, 0.38, 0.32, 0.0), Color(0.42, 0.38, 0.32, 0.42), Color(0.48, 0.44, 0.38, 0.0)])
	var rg := _sys(c.ring, 2.0, pm, smoke_mat)
	rg.explosiveness = 1.0
	rg.set_instance_shader_parameter("density", 0.9)
	layers["ring"] = rg
	for key in layers:
		rig.add_child(layers[key])
	rig.set_meta("layers", layers)
	rig.set_meta("t", -1000.0)
	return rig


func _get_rig(cls: String) -> Node3D:
	var arr: Array = _rigs[cls]
	var now := Time.get_ticks_msec() / 1000.0
	var life: float = CLASSES[cls].sml
	var oldest: Node3D = null
	for r in arr:
		if now - float(r.get_meta("t")) > life + 0.5:
			return r
		if oldest == null or float(r.get_meta("t")) < float(oldest.get_meta("t")):
			oldest = r
	if arr.size() < MAX_RIGS[cls]:
		var nr := _build_rig(cls)
		arr.append(nr)
		return nr
	return oldest


func _fire_layer(p: GPUParticles3D, ratio: float, seed_v: float) -> void:
	p.visible = true
	p.amount_ratio = clampf(ratio, 0.05, 1.0)
	p.set_instance_shader_parameter("seed", seed_v)
	p.restart()
	p.emitting = true


## Full explosion at `p`. size: ~0.4 drone pop, 1 grenade/rocket, 1.4 tank shell, 2+ vehicle / bomb.
func explode(p: Vector3, size: float) -> void:
	var cls := "s" if size < 0.75 else ("m" if size < 1.6 else "l")
	var rig := _get_rig(cls)
	rig.global_position = p
	rig.set_meta("t", Time.get_ticks_msec() / 1000.0)
	rig.set_meta("shown", true)
	var layers: Dictionary = rig.get_meta("layers")
	var fx := Settings.fx_mult()
	var ground := p.y < 1.6
	var sv := randf() * 100.0
	(layers.flash as GPUParticles3D).position = Vector3(0, 0.9 * float(CLASSES[cls].k), 0)
	_fire_layer(layers.flash, 1.0, sv)
	_fire_layer(layers.fireball, fx, sv)
	_fire_layer(layers.smoke, fx, sv + 1.0)
	_fire_layer(layers.sparks, fx, sv)
	if ground:
		_fire_layer(layers.dirt, fx, sv + 2.0)
		_fire_layer(layers.debris, fx, sv)
		_fire_layer(layers.ejecta, fx, sv)
		if layers.has("column"):
			_fire_layer(layers.column, fx * clampf(size / 2.0, 0.5, 1.0), sv + 4.0)
		if size >= 0.9 and not OS.has_environment("FL_NO_PLUMES"):
			plume(p, size)
		if fx > 0.5 or size >= 1.0:
			_fire_layer(layers.ring, fx, sv + 3.0)
		if Settings.get_v("decals"):
			scorch(Vector3(p.x, 0.0, p.z), 2.4 * size + 1.0)

	if fx >= 0.6:
		_shockwave(p + Vector3(0, 0.3, 0), size)


func _shockwave(p: Vector3, size: float) -> void:
	if _wave_pool.is_empty():
		return
	var w: MeshInstance3D = _wave_pool.pop_back()
	w.visible = true
	w.global_position = p
	w.scale = Vector3.ONE * 0.1
	_waves.append([w, 0.0, size])


func scorch(p: Vector3, d: float) -> void:
	var dc: Decal
	if _decals.size() >= 70:
		var old: Array = _decals.pop_front()
		dc = old[0]
	else:
		dc = Decal.new()
		dc.texture_albedo = scorch_tex
		dc.upper_fade = 0.4
		dc.lower_fade = 0.4
		dc.distance_fade_enabled = true
		dc.distance_fade_begin = 170.0
		dc.distance_fade_length = 40.0
		add_child(dc)
	dc.size = Vector3(d, 1.0, d)
	dc.global_position = p
	dc.rotation.y = randf() * TAU
	dc.modulate = Color(1, 1, 1, 1)
	_decals.append([dc, 0.0, 150.0])


# --- small pooled emitters (impacts, launch smoke, muzzle smoke) ---------------

func _build_small(kind: String) -> GPUParticles3D:
	var pm: ParticleProcessMaterial
	var p: GPUParticles3D
	match kind:
		"dust":
			pm = _pm(Vector3.UP, 35.0, 0.6, 2.2, Vector3(0.2, 0.4, 0.1), 0.35, 0.8)
			pm.damping_min = 2.0
			pm.damping_max = 3.0
			pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 1.0)])
			pm.color_ramp = _ramp([0.0, 0.1, 1.0], [Color(0.5, 0.45, 0.37, 0.0), Color(0.5, 0.45, 0.37, 0.6), Color(0.55, 0.5, 0.43, 0.0)])
			p = _sys(5, 1.1, pm, smoke_mat)
		"dirt_spurt":
			pm = _pm(Vector3.UP, 20.0, 3.0, 6.0, Vector3(0, -12.0, 0), 0.2, 0.45)
			pm.scale_curve = _curve([Vector2(0, 0.6), Vector2(1, 1.0)])
			pm.color_ramp = _ramp([0.0, 0.1, 1.0], [Color(0.25, 0.2, 0.14, 0.0), Color(0.25, 0.2, 0.14, 1.0), Color(0.3, 0.26, 0.2, 0.0)])
			p = _sys(6, 0.7, pm, smoke_mat)
			p.set_instance_shader_parameter("density", 1.3)
		"smoke":
			pm = _pm(Vector3.UP, 40.0, 1.0, 3.0, Vector3(0.4, 0.7, 0.2), 1.0, 1.9)
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = 0.4
			pm.damping_min = 1.5
			pm.damping_max = 2.5
			pm.scale_curve = _curve([Vector2(0, 0.35), Vector2(1, 1.0)])
			pm.color_ramp = _ramp([0.0, 0.08, 1.0], [Color(0.55, 0.53, 0.5, 0.0), Color(0.55, 0.53, 0.5, 0.6), Color(0.6, 0.58, 0.55, 0.0)])
			p = _sys(9, 3.2, pm, smoke_mat)
		"fire":
			pm = _pm(Vector3.UP, 40.0, 1.0, 3.5, Vector3(0, 3.0, 0), 0.7, 1.3)
			pm.damping_min = 3.0
			pm.damping_max = 4.0
			pm.scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1.0)])
			pm.color_ramp = _ramp([0.0, 0.1, 1.0], [Color(0.2, 0.18, 0.16, 0.0), Color(0.2, 0.18, 0.16, 1.0), Color(0.3, 0.28, 0.26, 0.0)])
			p = _sys(8, 0.9, pm, smoke_mat)
			p.set_instance_shader_parameter("heat", 1.2)
			p.set_instance_shader_parameter("heat_fade", 0.6)
		"brass":
			pm = _pm(Vector3.UP, 25.0, 2.5, 4.0, Vector3(0, -9.8, 0), 0.8, 1.2)
			pm.particle_flag_rotate_y = true
			pm.angular_velocity_min = -900.0
			pm.angular_velocity_max = 900.0
			pm.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
			pm.collision_bounce = 0.35
			pm.collision_friction = 0.5
			var bm := BoxMesh.new()
			bm.size = Vector3(0.018, 0.018, 0.06)
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.85, 0.62, 0.28)
			bmat.metallic = 0.9
			bmat.roughness = 0.3
			p = _sys(3, 1.6, pm, bmat, bm)
			p.draw_order = GPUParticles3D.DRAW_ORDER_INDEX
		_:  # spark
			pm = _pm(Vector3.UP, 55.0, 4.0, 11.0, Vector3(0, -9.8, 0), 0.4, 0.9)
			pm.angle_min = 0.0
			pm.angle_max = 0.0
			pm.particle_flag_align_y = true
			pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.0)])
			pm.color_ramp = _ramp([0.0, 1.0], [Color(1, 1, 1, 1), Color(1, 0.6, 0.3, 0)])
			var spm := QuadMesh.new()
			spm.size = Vector2(0.03, 0.4)
			p = _sys(10, 0.35, pm, spark_mat, spm)
			p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 14, 16))
	add_child(p)
	return p


func puff(kind: String, pos: Vector3, dir := Vector3.UP) -> void:
	var entry: Array = _small.get(kind, [])
	if entry.is_empty():
		return
	var arr: Array = entry[0]
	var cap := 24 if kind in ["dust", "spark", "dirt_spurt", "brass"] else 12
	var p: GPUParticles3D
	if arr.size() < cap:
		p = _build_small(kind)
		arr.append(p)
	else:
		p = arr[entry[1]]
		entry[1] = (entry[1] + 1) % arr.size()
	p.global_position = pos
	# rotate the emitter so its local up follows `dir`
	if dir.length() > 0.01 and absf(dir.normalized().dot(Vector3.UP)) < 0.98:
		p.global_basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
	else:
		p.global_basis = Basis()
	_fire_layer(p, Settings.fx_mult(), randf() * 50.0)


# --- persistent emitters: burning wrecks, vehicle smoke, smoke screens ----------

## Continuous fire + smoke for burning vehicles and wrecks. Returns a holder whose
## children are the emitters; call set_burning(holder, fire, smoke) to tune.
func make_burner(size: float) -> Node3D:
	var h := Node3D.new()
	var pm := _pm(Vector3.UP, 25.0, 0.8, 2.2, Vector3(0, 3.5, 0), 0.9 * size, 1.6 * size)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6 * size
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.angular_velocity_min = -60.0
	pm.angular_velocity_max = 60.0
	pm.scale_curve = _curve([Vector2(0, 0.6), Vector2(0.5, 1.0), Vector2(1, 0.4)])
	pm.color_ramp = _ramp([0.0, 0.15, 1.0], [Color(0.15, 0.13, 0.12, 0.0), Color(0.15, 0.13, 0.12, 1.0), Color(0.15, 0.14, 0.13, 0.0)])
	var fire := _sys(int(14 * size), 0.9, pm, smoke_mat)
	fire.one_shot = false
	fire.explosiveness = 0.0
	fire.set_instance_shader_parameter("heat", 1.5)
	fire.set_instance_shader_parameter("heat_fade", 0.75)
	fire.set_instance_shader_parameter("density", 1.2)
	fire.name = "Fire"
	h.add_child(fire)
	pm = _pm(Vector3.UP, 12.0, 2.0, 4.0, Vector3(0.6, 0.6, 0.3), 1.4 * size, 2.6 * size)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5 * size
	pm.damping_min = 0.3
	pm.damping_max = 0.8
	pm.angular_velocity_min = -15.0
	pm.angular_velocity_max = 15.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 5.0
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.05
	pm.scale_curve = _curve([Vector2(0, 0.3), Vector2(1, 1.0)])
	pm.color_ramp = _ramp([0.0, 0.1, 0.6, 1.0], [Color(0.07, 0.065, 0.06, 0.0), Color(0.07, 0.065, 0.06, 0.85), Color(0.16, 0.15, 0.14, 0.5), Color(0.28, 0.27, 0.26, 0.0)])
	var smk := _sys(int(22 * size), 7.0, pm, smoke_mat)
	smk.one_shot = false
	smk.explosiveness = 0.0
	smk.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(60, 50, 60))
	smk.name = "Smoke"
	smk.set_instance_shader_parameter("density", 1.1)
	h.add_child(smk)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.omni_range = 7.0 * size
	l.light_energy = 0.0
	l.position = Vector3(0, 1.0, 0)
	l.name = "Glow"
	h.add_child(l)
	h.set_meta("fire", 0.0)
	_burners.append(h)
	return h


var _timed: Array = []  # [holder, t, fire_secs, smoke_secs]


## Burns for `fire_s` seconds, then smoulders for `smoke_s` more and frees itself.
func burn_for(h: Node3D, fire_s: float, smoke_s: float) -> void:
	_timed.append([h, 0.0, fire_s, smoke_s])
	set_burning(h, 1.0, 1.0)


## Thin grey wisps behind a mortar or artillery shell so its arc can be followed.
func make_shell_trail(heavy := false) -> GPUParticles3D:
	var pm := _pm(Vector3.UP, 30.0, 0.1, 0.4, Vector3(0.2, 0.25, 0.1), 0.35 if not heavy else 0.6, 0.6 if not heavy else 1.0)
	pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 1.6)])
	pm.color_ramp = _ramp([0.0, 0.1, 1.0], [Color(0.75, 0.74, 0.72, 0.0), Color(0.72, 0.71, 0.7, 0.42), Color(0.8, 0.8, 0.8, 0.0)])
	var p := _sys(60 if heavy else 40, 1.3 if heavy else 0.9, pm, smoke_mat)
	p.one_shot = false
	p.explosiveness = 0.0
	p.emitting = true
	p.set_instance_shader_parameter("density", 0.9)
	p.visibility_aabb = AABB(Vector3(-200, -60, -200), Vector3(400, 260, 400))
	return p


## Rolling cloud left by a gun firing from an aircraft (toggle `emitting`).
func make_gun_smoke() -> GPUParticles3D:
	var pm := _pm(Vector3.UP, 60.0, 0.5, 2.0, Vector3(0, 0.3, 0), 1.2, 2.2)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 2.0)])
	pm.color_ramp = _ramp([0.0, 0.08, 1.0], [Color(0.55, 0.54, 0.52, 0.0), Color(0.5, 0.49, 0.47, 0.55), Color(0.62, 0.61, 0.6, 0.0)])
	var p := _sys(220, 2.6, pm, smoke_mat)
	p.one_shot = false
	p.explosiveness = 0.0
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-300, -80, -300), Vector3(600, 260, 600))
	return p


## Rocket / missile exhaust trail (continuous, world space).
func make_trail() -> GPUParticles3D:
	var pm := _pm(Vector3.UP, 180.0, 0.1, 0.5, Vector3(0.2, 0.5, 0.1), 0.35, 0.6)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 1.0)])
	pm.color_ramp = _ramp([0.0, 0.05, 1.0], [Color(0.75, 0.74, 0.72, 0.0), Color(0.75, 0.74, 0.72, 0.6), Color(0.8, 0.79, 0.77, 0.0)])
	var t := _sys(70, 1.6, pm, smoke_mat)
	t.one_shot = false
	t.explosiveness = 0.0
	t.randomness = 0.1
	t.fixed_fps = 0
	t.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 40, 120))
	t.set_instance_shader_parameter("heat", 0.9)
	t.set_instance_shader_parameter("heat_fade", 0.06)
	t.set_instance_shader_parameter("density", 0.8)
	t.emitting = true
	return t


func set_burning(h: Node3D, fire: float, smoke: float) -> void:
	if h == null or not is_instance_valid(h):
		return
	var f := h.get_node("Fire") as GPUParticles3D
	var s := h.get_node("Smoke") as GPUParticles3D
	var fx := Settings.fx_mult()
	f.emitting = fire > 0.02
	if f.emitting:
		f.amount_ratio = clampf(fire * fx, 0.05, 1.0)
	s.emitting = smoke > 0.02
	if s.emitting:
		s.amount_ratio = clampf(smoke * fx, 0.05, 1.0)
	h.set_meta("fire", fire)
	if f.emitting or s.emitting:
		f.visible = true
		s.visible = true
		if h.has_meta("off_at"):
			h.remove_meta("off_at")
	elif f.visible and not h.has_meta("off_at"):
		# hide once the last of the smoke has drifted away
		h.set_meta("off_at", Time.get_ticks_msec() / 1000.0 + s.lifetime + 1.0)


## Dust kicked up behind a moving vehicle (continuous; emitting follows speed).
func make_dust(size: float) -> GPUParticles3D:
	var pm := _pm(Vector3.UP, 50.0, 0.4, 1.4, Vector3(0.3, 0.35, 0.1), 0.9 * size, 1.8 * size)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.1 * size, 0.1, 0.4)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.angular_velocity_min = -20.0
	pm.angular_velocity_max = 20.0
	pm.scale_curve = _curve([Vector2(0, 0.3), Vector2(1, 1.0)])
	pm.color_ramp = _ramp([0.0, 0.15, 1.0], [Color(0.52, 0.47, 0.38, 0.0), Color(0.52, 0.47, 0.38, 0.45), Color(0.56, 0.52, 0.45, 0.0)])
	var d := _sys(int(26 * size), 2.6, pm, smoke_mat)
	d.one_shot = false
	d.explosiveness = 0.0
	d.emitting = false
	d.set_instance_shader_parameter("density", 0.8)
	d.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 12, 40))
	return d


## Thick white smoke screen (grenade / mortar smoke); FogVolume adds real
## volumetric density when volumetric fog is on.
func make_smoke_screen() -> Node3D:
	var h := Node3D.new()
	var pm := _pm(Vector3.UP, 70.0, 0.3, 1.2, Vector3(0.25, 0.25, 0.12), 2.6, 4.2)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.0
	pm.damping_min = 0.5
	pm.damping_max = 1.0
	pm.angular_velocity_min = -10.0
	pm.angular_velocity_max = 10.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_scale = 5.0
	pm.turbulence_influence_min = 0.01
	pm.turbulence_influence_max = 0.04
	pm.scale_curve = _curve([Vector2(0, 0.3), Vector2(0.3, 0.9), Vector2(1, 1.0)])
	pm.color_ramp = _ramp([0.0, 0.1, 0.7, 1.0], [Color(0.85, 0.85, 0.83, 0.0), Color(0.85, 0.85, 0.83, 0.85), Color(0.82, 0.82, 0.8, 0.6), Color(0.8, 0.8, 0.78, 0.0)])
	var s := _sys(60, 6.0, pm, smoke_mat)
	s.one_shot = false
	s.explosiveness = 0.0
	s.name = "Smoke"
	s.visibility_aabb = AABB(Vector3(-15, -2, -15), Vector3(30, 20, 30))
	s.set_instance_shader_parameter("density", 1.0)
	s.emitting = false
	h.add_child(s)
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fv.size = Vector3(2, 2, 2)
	var fm := FogMaterial.new()
	fm.density = 0.0
	fm.albedo = Color(0.9, 0.9, 0.88)
	fm.edge_fade = 0.9
	fm.height_falloff = 0.15
	fv.material = fm
	fv.name = "Fog"
	h.add_child(fv)
	return h


func set_smoke_screen(h: Node3D, r: float) -> void:
	var s := h.get_node("Smoke") as GPUParticles3D
	var fv := h.get_node("Fog") as FogVolume
	s.emitting = r > 0.3
	if s.emitting:
		(s.process_material as ParticleProcessMaterial).emission_sphere_radius = maxf(0.6, r * 0.7)
		s.amount_ratio = clampf(Settings.fx_mult() * 1.2, 0.3, 1.0)
	var vol: bool = Settings.get_v("vol_fog")
	fv.visible = vol and r > 0.3
	if fv.visible:
		fv.size = Vector3(r * 2.4, r * 1.3, r * 2.4)
		fv.position = Vector3(0, r * 0.45, 0)
		(fv.material as FogMaterial).density = clampf(r / 6.5, 0.0, 1.0) * 0.07


# --- per-frame ---------------------------------------------------------------------

func _process(dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(dt)
	if world:
		world.vp("vfx", _t0)


func _view_process(dt: float) -> void:
	_tick_plumes(dt)
	for i in range(_late_clods.size() - 1, -1, -1):
		var lc: Array = _late_clods[i]
		lc[2] -= dt
		if lc[2] <= 0.0:
			_add_clods(lc[0], lc[1])
			_late_clods.remove_at(i)
	for i in range(_waves.size() - 1, -1, -1):
		var w: Array = _waves[i]
		w[1] += dt
		var k: float = w[1] / 0.32
		var mi: MeshInstance3D = w[0]
		if k >= 1.0:
			mi.visible = false
			_wave_pool.append(mi)
			_waves.remove_at(i)
			continue
		mi.scale = Vector3.ONE * (0.5 + 9.0 * float(w[2]) * sqrt(k))
		mi.set_instance_shader_parameter("wave_t", k)
	for i in range(_decals.size() - 1, -1, -1):
		var d: Array = _decals[i]
		d[1] += dt
		var a := clampf((float(d[2]) - d[1]) / 30.0, 0.0, 1.0)
		var dc: Decal = d[0]
		dc.modulate.a = a
		if a <= 0.0:
			dc.queue_free()
			_decals.remove_at(i)
	for i in range(_timed.size() - 1, -1, -1):
		var tb: Array = _timed[i]
		if not is_instance_valid(tb[0]):
			_timed.remove_at(i)
			continue
		tb[1] += dt
		var fire := clampf(1.0 - (tb[1] - tb[2] * 0.6) / (tb[2] * 0.4), 0.0, 1.0)
		var smk := clampf(1.0 - (tb[1] - tb[2]) / maxf(1.0, tb[3]), 0.0, 1.0)
		set_burning(tb[0], fire, maxf(smk, 0.25 if fire > 0.0 else 0.0))
		if tb[1] > tb[2] + tb[3] + 8.0:
			tb[0].queue_free()
			_timed.remove_at(i)
	var t := Time.get_ticks_msec() / 1000.0
	for i in range(_burners.size() - 1, -1, -1):
		if not is_instance_valid(_burners[i]):
			_burners.remove_at(i)
			continue
		var h: Node3D = _burners[i]
		var l := h.get_node("Glow") as OmniLight3D
		var f := float(h.get_meta("fire"))
		l.light_energy = f * (2.2 + 0.8 * sin(t * 17.0 + i) + 0.5 * sin(t * 29.0)) if f > 0.02 else 0.0
		l.visible = f > 0.02
		if h.has_meta("off_at") and t > float(h.get_meta("off_at")):
			h.remove_meta("off_at")
			(h.get_node("Fire") as GPUParticles3D).visible = false
			(h.get_node("Smoke") as GPUParticles3D).visible = false
	_rig_check_t -= dt
	if _rig_check_t <= 0.0:
		_rig_check_t = 0.5
		for cls in _rigs:
			var life: float = CLASSES[cls].sml + 1.0
			for r in _rigs[cls]:
				if t - float(r.get_meta("t")) > life and r.has_meta("shown"):
					r.remove_meta("shown")
					for key in r.get_meta("layers"):
						(r.get_meta("layers")[key] as GPUParticles3D).visible = false


# --- shaders --------------------------------------------------------------------

const SMOKE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.3);
uniform vec3 sun_col : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_energy = 1.5;
uniform vec3 amb_col : source_color = vec3(0.5, 0.55, 0.62);
uniform float amb_energy = 0.6;
uniform float softness = 1.4;
instance uniform float heat = 0.0;
instance uniform float heat_fade = 0.3;
instance uniform float density = 1.0;
instance uniform float seed = 0.0;
instance uniform float erode = 1.0;

varying float age;
varying float rnd;
varying vec3 lv;
varying vec2 rcs;

void vertex() {
	mat4 mw = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float ang = INSTANCE_CUSTOM.x;
	mw = mw * mat4(vec4(cos(ang), -sin(ang), 0.0, 0.0), vec4(sin(ang), cos(ang), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	float bs = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mw * mat4(vec4(bs, 0.0, 0.0, 0.0), vec4(0.0, bs, 0.0, 0.0), vec4(0.0, 0.0, bs, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	age = INSTANCE_CUSTOM.y;
	rcs = vec2(cos(ang), sin(ang));
	rnd = fract(sin(float(INSTANCE_ID) * 12.9898 + seed * 78.233) * 43758.5453);
	lv = normalize((VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	vec2 nuv = UV * 0.5 + vec2(rnd * 5.31, rnd * 9.17);
	vec3 t1 = texture(noise_tex, nuv + vec2(age * 0.07, age * 0.05)).rgb;
	vec3 t2 = texture(noise_tex, nuv * 2.03 + vec2(-age * 0.1, age * 0.08) + 0.37).rgb;
	float billow = t1.g * 0.6 + t2.g * 0.4;
	float fb = t1.r * 0.55 + t2.b * 0.45;
	float n = mix(fb, billow, 0.5);
	float edge = r + (0.5 - n) * (0.85 + age * 0.75 * erode);
	float shape = 1.0 - smoothstep(0.34, 0.99, edge);
	shape *= mix(1.0, smoothstep(0.15, 0.6, billow), clamp(age * 0.8, 0.0, 0.6));
	float a = shape * COLOR.a * density;
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	float scene_z = -vp.z / vp.w;
	a *= clamp((scene_z + VERTEX.z) / softness, 0.0, 1.0);
	float nz = sqrt(max(0.0, 1.0 - min(r * r, 1.0)));
	vec3 ns = normalize(vec3(p * 0.85 + vec2(t1.r - 0.5, t2.r - 0.5) * 0.9, nz + 0.3));
	vec3 nv = vec3(rcs.x * ns.x + rcs.y * ns.y, -rcs.y * ns.x + rcs.x * ns.y, ns.z);
	float diff = clamp(dot(nv, lv) * 0.62 + 0.38, 0.0, 1.0);
	float occl = mix(0.38, 1.0, smoothstep(0.2, 0.8, n));
	vec3 col = COLOR.rgb * (sun_col * sun_energy * diff * occl + amb_col * amb_energy * (0.55 + 0.45 * n));
	float back = pow(clamp(-lv.z, 0.0, 1.0), 3.0) * (1.0 - shape) * shape * 2.0;
	col += sun_col * sun_energy * back * 0.35 * COLOR.rgb;
	float h = heat * pow(clamp(1.0 - age / max(heat_fade * (0.55 + 0.9 * rnd), 0.01), 0.0, 1.0), 1.4);
	float hn = clamp(h * (n * 1.7 - 0.35) * (1.3 - r * 0.9), 0.0, 1.4);
	vec3 fire = mix(vec3(0.22, 0.03, 0.005), vec3(0.95, 0.3, 0.04), smoothstep(0.08, 0.45, hn));
	fire = mix(fire, vec3(1.0, 0.62, 0.22), smoothstep(0.45, 0.85, hn));
	fire = mix(fire, vec3(1.0, 0.86, 0.6), smoothstep(1.0, 1.35, hn));
	fire *= 0.7 + 3.2 * hn;
	// soot: the cooling edge of the fire goes dark before it turns grey
	col *= mix(1.0, 0.45, clamp(h * 1.5, 0.0, 1.0) * (1.0 - smoothstep(0.05, 0.3, hn)));
	col = mix(col, fire, smoothstep(0.04, 0.3, hn));
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

const FLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 col : source_color = vec3(1.0, 0.72, 0.38);
uniform float intensity = 7.0;
instance uniform float rot = 0.0;
instance uniform float rays = 1.0;
void vertex() {
	mat4 mw = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float ang = INSTANCE_CUSTOM.x + rot;
	mw = mw * mat4(vec4(cos(ang), -sin(ang), 0.0, 0.0), vec4(sin(ang), cos(ang), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	float bs = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mw * mat4(vec4(bs, 0.0, 0.0, 0.0), vec4(0.0, bs, 0.0, 0.0), vec4(0.0, 0.0, bs, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float star = pow(abs(cos(a * 2.5)), 10.0) * rays;
	float g = exp(-r * r * 10.0) * 1.4 + star * exp(-r * 3.2) * 0.8 + exp(-r * 4.0) * 0.25;
	g *= 1.0 - smoothstep(0.75, 1.0, r);
	vec3 c = mix(col, vec3(1.0, 0.95, 0.85), exp(-r * r * 25.0));
	float dz = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	float soft = clamp((-vp.z / vp.w + VERTEX.z) / 2.5, 0.0, 1.0);
	ALBEDO = c * intensity * g * COLOR.a * soft;
	ALPHA = clamp(g * COLOR.a * soft, 0.0, 1.0);
}
"""

const SPARK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 hot : source_color = vec3(1.0, 0.62, 0.25);
uniform float intensity = 9.0;
void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float core = (1.0 - smoothstep(0.0, 1.0, x)) * smoothstep(0.0, 0.35, UV.y) * (1.0 - smoothstep(0.65, 1.0, UV.y));
	ALBEDO = mix(hot, vec3(1.0, 0.9, 0.7), COLOR.g * 0.5) * intensity * core * COLOR.a;
	ALPHA = clamp(core * COLOR.a, 0.0, 1.0);
}
"""

const TRACER_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 col : source_color = vec3(1.0, 0.55, 0.22);
uniform float intensity = 6.0;
void fragment() {
	ALBEDO = col * intensity;
	ALPHA = 1.0;
}
"""

const WAVE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
instance uniform float wave_t = 0.0;
void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float rim = pow(1.0 - facing, 2.0) * smoothstep(0.0, 0.25, facing);
	float k = 1.0 - wave_t;
	vec2 off = NORMAL.xy * rim * k * 0.03;
	vec3 c = textureLod(screen_tex, SCREEN_UV - off, 0.0).rgb;
	ALBEDO = c;
	ALPHA = clamp(rim * 3.0, 0.0, 1.0) * k;
}
"""


const EJECTA_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, particle_trails;
uniform vec3 light = vec3(1.0, 0.95, 0.9);
void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float a = smoothstep(0.0, 0.7, across) * COLOR.a;
	ALBEDO = COLOR.rgb * light;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""


# --- lingering plumes ------------------------------------------------------------------
# A strike leaves smoke behind: a column that keeps billowing up out of the
# crater for a while, swelling and leaning downwind as it rises, and a haze of
# dust and smoke that rolls out along the ground and hangs there. Several hits
# close together feed the same plume, so a barrage builds one great drifting
# cloud over the target instead of a row of puffs. The emitters work in world
# space, so moving one to a new strike never cuts off the smoke already up.

func _build_plume(cls: String) -> Node3D:
	var spec: Array = PLUMES[cls]
	var k: float = spec[0]
	var h := Node3D.new()
	add_child(h)
	var pm := _pm(Vector3.UP, 24.0, 0.9 * k, 2.6 * k, Vector3(0.2, 0.22, 0.08), 2.0 * k, 3.4 * k)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.1 * k
	pm.damping_min = 0.16
	pm.damping_max = 0.26
	pm.angular_velocity_min = -7.0
	pm.angular_velocity_max = 7.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.6
	pm.turbulence_noise_scale = 9.0
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.06
	pm.scale_curve = _curve([Vector2(0, 0.45), Vector2(0.2, 1.0), Vector2(0.6, 1.9), Vector2(1, 2.7)])
	pm.color_ramp = _ramp([0.0, 0.06, 0.25, 0.6, 1.0], [Color(0.12, 0.105, 0.09, 0.0), Color(0.13, 0.115, 0.1, 0.78), Color(0.21, 0.2, 0.19, 0.56), Color(0.32, 0.315, 0.31, 0.28), Color(0.42, 0.42, 0.41, 0.0)])
	pm.color_initial_ramp = _ramp([0.0, 1.0], [Color(0.82, 0.82, 0.82), Color(1.18, 1.14, 1.1)])
	var col := _sys(spec[1], spec[2], pm, smoke_mat)
	col.one_shot = false
	col.explosiveness = 0.0
	col.randomness = 0.6
	col.visibility_aabb = AABB(Vector3(-45, -5, -45), Vector3(90, 70, 90))
	col.set_instance_shader_parameter("density", 0.85)
	col.set_instance_shader_parameter("erode", 1.2)
	pm = _pm(Vector3(1, 0, 0), 180.0, 0.4 * k, 1.5 * k, Vector3(0.12, 0.012, 0.05), 3.0 * k, 5.0 * k)
	pm.flatness = 1.0
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 2.4 * k
	pm.emission_ring_inner_radius = 0.6 * k
	pm.emission_ring_height = 0.3
	pm.damping_min = 0.12
	pm.damping_max = 0.2
	pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(0.3, 1.0), Vector2(1, 1.8)])
	pm.color_ramp = _ramp([0.0, 0.1, 0.6, 1.0], [Color(0.32, 0.29, 0.25, 0.0), Color(0.33, 0.3, 0.26, 0.24), Color(0.38, 0.36, 0.33, 0.14), Color(0.42, 0.41, 0.39, 0.0)])
	var hz := _sys(spec[3], spec[4], pm, smoke_mat)
	hz.one_shot = false
	hz.explosiveness = 0.0
	hz.randomness = 0.5
	hz.visibility_aabb = AABB(Vector3(-45, -5, -45), Vector3(90, 20, 90))
	hz.set_instance_shader_parameter("density", 0.6)
	hz.set_instance_shader_parameter("erode", 0.8)
	hz.position = Vector3(0, 0.6, 0)
	h.add_child(col)
	h.add_child(hz)
	h.set_meta("col", col)
	h.set_meta("haze", hz)
	return h


func plume(p: Vector3, size: float) -> void:
	var cls := "L" if size >= 1.8 else "M"
	var spec: Array = PLUMES[cls]
	var emit: float = spec[5] * clampf(size / (2.3 if cls == "L" else 1.3), 0.6, 1.3)
	var life: float = spec[2]
	var ground := Vector3(p.x, 0.4 if p.y > -5.0 else p.y, p.z)  # (prewarm happens under the map)
	# another hit right next to a plume still going: feed that one
	for e in _plumes.L + _plumes.M:
		if float(e[1]) < float(e[2]) and (e[0] as Node3D).global_position.distance_to(ground) < 7.0:
			e[1] = minf(float(e[1]), float(e[2]) * 0.25)
			e[2] = maxf(float(e[2]), emit)
			return
	var arr: Array = _plumes[cls]
	var pick = null
	var oldest = null
	for e in arr:
		if float(e[1]) > float(e[2]) + float(e[3]):
			pick = e
			break
		if oldest == null or float(e[1]) > float(oldest[1]):
			oldest = e
	if pick == null and arr.size() < int(MAX_PLUMES[cls]):
		pick = [_build_plume(cls), 0.0, emit, life]
		arr.append(pick)
	elif pick == null:
		pick = oldest  # its smoke already up keeps drifting: the emitters work in world space
	var node: Node3D = pick[0]
	node.global_position = ground
	pick[1] = 0.0
	pick[2] = emit
	pick[3] = life
	var fx := Settings.fx_mult()
	for key in ["col", "haze"]:
		var ps: GPUParticles3D = node.get_meta(key)
		ps.visible = true
		ps.amount_ratio = clampf(fx, 0.1, 1.0)
		ps.set_instance_shader_parameter("seed", randf() * 100.0)
		ps.emitting = true


func _tick_plumes(dt: float) -> void:
	var fx := clampf(Settings.fx_mult(), 0.1, 1.0)
	for cls in _plumes:
		for e in _plumes[cls]:
			e[1] = float(e[1]) + dt
			var t: float = e[1]
			var emit: float = e[2]
			var node: Node3D = e[0]
			var col: GPUParticles3D = node.get_meta("col")
			var hz: GPUParticles3D = node.get_meta("haze")
			if t < emit:
				# thick at first, thinning to a wisp before it stops
				col.amount_ratio = clampf(fx * maxf(0.12, exp(-t / (emit * 0.45))), 0.05, 1.0)
				hz.emitting = t < emit * 0.4
			elif col.emitting:
				col.emitting = false
				hz.emitting = false
			elif t > emit + float(e[3]) + 1.0 and col.visible:
				col.visible = false
				hz.visible = false
