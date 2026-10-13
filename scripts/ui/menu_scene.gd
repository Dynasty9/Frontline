class_name MenuScene
extends Node3D
## Living backdrop behind the main menu: a slow orbit around a sandbagged
## .50 cal position at golden hour, a burning wreck, smoke on the horizon and
## distant shelling. Built from the same parts as the battlefield.

var cam: Camera3D
var vfx: Vfx
var gun: Node3D
var _t := 0.0
var _next_boom := 1.5
var _next_burst := 0.6
var _burst_left := 0
var _shot_t := 0.0
var _tracers: Array = []  # [mi, from, to, t]
var _flash: MeshInstance3D
var _flash_t := 0.0
var _light: OmniLight3D
var _rng := RandomNumberGenerator.new()
var _soldiers: Array = []
var _mg := {}
var _gunner: SoldierModel
var _aim := 0.0  # where the gun is being laid (relative to its mount)


func _ready() -> void:
	_rng.seed = 7
	_env()
	_ground()
	vfx = Vfx.new()
	add_child(vfx)
	vfx.smoke_mat.set_shader_parameter("sun_dir", Vector3(-0.62, 0.42, 0.66).normalized())
	vfx.smoke_mat.set_shader_parameter("sun_col", Color(1.0, 0.8, 0.6))
	vfx.smoke_mat.set_shader_parameter("sun_energy", 1.7)
	vfx.smoke_mat.set_shader_parameter("amb_col", Color(0.62, 0.62, 0.66))
	vfx.smoke_mat.set_shader_parameter("amb_energy", 0.55)
	_props()
	cam = Camera3D.new()
	cam.fov = 48.0
	cam.near = 0.1
	cam.far = 600.0
	var ca := CameraAttributesPractical.new()
	ca.dof_blur_far_enabled = true
	ca.dof_blur_far_distance = 32.0
	ca.dof_blur_far_transition = 30.0
	ca.dof_blur_amount = 0.05
	cam.attributes = ca
	add_child(cam)
	cam.current = true
	_place_cam()
	if Sfx.enabled:
		for it in [["wind", -17.0], ["rumble", -15.0]]:
			var ap := AudioStreamPlayer.new()
			ap.stream = Sfx.streams[it[0]]
			ap.volume_db = it[1]
			ap.autoplay = true
			add_child(ap)


func _env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = Atmosphere.SKY_SHADER
	sm.shader = sh
	sm.set_shader_parameter("zenith", Color(0.24, 0.36, 0.6))
	sm.set_shader_parameter("horizon", Color(0.95, 0.76, 0.58))
	sm.set_shader_parameter("ground_col", Color(0.24, 0.23, 0.2))
	sm.set_shader_parameter("sun_col", Color(1.0, 0.78, 0.55))
	sm.set_shader_parameter("cloudiness", 0.6)
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.86, 0.72, 0.58)
	env.fog_density = 0.0028
	env.fog_sun_scatter = 0.25
	env.fog_sky_affect = 0.6
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.0
	env.volumetric_fog_enabled = bool(Settings.get_v("vol_fog"))
	env.volumetric_fog_density = 0.0045
	env.volumetric_fog_albedo = Color(0.9, 0.85, 0.8)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 120.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, -48, 0)
	sun.light_color = Color(1.0, 0.8, 0.6)
	sun.light_energy = 2.4
	sun.light_angular_distance = 0.8
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 80.0
	sun.light_volumetric_fog_energy = 1.4
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 132, 0)
	rim.light_color = Color(0.6, 0.72, 0.95)
	rim.light_energy = 0.3
	add_child(rim)


func _ground() -> void:
	var n := FastNoiseLite.new()
	n.seed = 31
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 4
	var bimg := n.get_seamless_image(512, 512, false, false, 0.1, true)
	var d := FastNoiseLite.new()
	d.seed = 42
	d.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	d.frequency = 0.035
	d.fractal_octaves = 5
	var dimg := d.get_seamless_image(256, 256, false, false, 0.1, true)
	dimg.generate_mipmaps()
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(500, 500)
	g.mesh = pm
	var gm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = Atmosphere.GROUND_SHADER
	gm.shader = sh
	gm.set_shader_parameter("biome_tex", ImageTexture.create_from_image(bimg))
	gm.set_shader_parameter("detail_tex", ImageTexture.create_from_image(dimg))
	gm.set_shader_parameter("cloud_strength", 0.25)
	g.material_override = gm
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	# grass and bushes from the battlefield's own meshes
	var gr := Grass.new()
	var clump := gr._make_clump()
	var bush := gr._make_bush()
	var gmat := ShaderMaterial.new()
	var gs := Shader.new()
	gs.code = Grass.GRASS_SHADER
	gmat.shader = gs
	var bmat := ShaderMaterial.new()
	var bs := Shader.new()
	bs.code = Grass.BUSH_SHADER
	bmat.shader = bs
	gr.free()
	var xf := []
	var cd := []
	var bx := []
	var bc := []
	for i in 9000:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 55.0
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if p.length() < 4.2 or (p - Vector3(7, 0, -5)).length() < 3.8:
			continue
		var s := _rng.randf_range(0.8, 1.35)
		xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.4), s)), p))
		cd.append(Color(0.9, _rng.randf(), 0, 0))
		if _rng.randf() < 0.01:
			bx.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.6)), p))
			bc.append(Color(_rng.randf(), _rng.randf(), 0, 0))
	_mm(clump, gmat, xf, cd, false)
	_mm(bush, bmat, bx, bc, true)


func _mm(mesh: Mesh, m: Material, xf: Array, cd: Array, shadow: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_custom_data(i, cd[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _props() -> void:
	# sandbag ring with a .50 cal
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	for row in 6:
		var n := 22 - row
		for i in n:
			var a := PI * 0.15 + (float(i) + (0.5 if row % 2 == 1 else 0.0)) / 22.0 * PI * 1.4
			var r := 2.9 - row * 0.03
			var p := Vector3(cos(a) * r, 0.09 + row * 0.17, sin(a) * r)
			var b := Basis(Vector3.UP, -a + PI * 0.5 + _rng.randf_range(-0.08, 0.08)).scaled(Vector3(0.6, 0.21, 0.36))
			xf.append(Transform3D(b, p))
			var k := _rng.randf_range(0.8, 1.1)
			cols.append(Color(k, k, k * _rng.randf_range(0.9, 1.05)))
			xf.append(Transform3D(b, p * 1.13))
			cols.append(Color(k * 0.95, k, k))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Structure._pillow()
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mats.get_mat("bag")
	add_child(mmi)
	# the .50 cal: an M2HB on its M3 tripod, on a platform of bags behind the
	# wall, crewed by a gunner kneeling behind the grips
	_mg = WeaponModels.build("m2")
	gun = _mg.root
	gun.position = Vector3(0.2, 0.45 + float(_mg.h), -1.4)
	gun.rotation.y = 0.5
	add_child(gun)
	Mats.merge_static(_mg.root, [_mg.traverse], false, false, true)
	for n in [_mg.traverse, _mg.elev, _mg.body]:
		Mats.merge_static(n, [], false, false, true)
	var pxf: Array[Transform3D] = []
	var pcol: Array[Color] = []
	for i in 6:
		var pp := gun.position + Basis(Vector3.UP, 0.5) * Vector3((i % 3 - 1) * 0.42, -float(_mg.h) - 0.32 + (i / 3) * 0.21, 0.05)
		pxf.append(Transform3D(Basis(Vector3.UP, 0.5).scaled(Vector3(0.44, 0.22, 0.6)), pp))
		pcol.append(Color(0.95, 0.95, 0.9))
	var pmm := MultiMesh.new()
	pmm.transform_format = MultiMesh.TRANSFORM_3D
	pmm.use_colors = true
	pmm.mesh = Structure._pillow()
	pmm.instance_count = pxf.size()
	for i in pxf.size():
		pmm.set_instance_transform(i, pxf[i])
		pmm.set_instance_color(i, pcol[i])
	var pmi := MultiMeshInstance3D.new()
	pmi.multimesh = pmm
	pmi.material_override = Mats.get_mat("bag")
	add_child(pmi)
	var body: Node3D = _mg.body
	_flash = MeshInstance3D.new()
	_flash.mesh = vfx.quad
	_flash.material_override = vfx.flash_mat
	_flash.position = _mg.muzzle
	_flash.scale = Vector3.ONE * 0.9
	_flash.visible = false
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(_flash)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.7, 0.35)
	_light.omni_range = 7.0
	_light.light_energy = 0.0
	_light.position = _mg.muzzle
	body.add_child(_light)
	# the crew: the gunner on the gun, a rifleman either side
	_gunner = SoldierModel.new()
	_gunner.build("mg_gunner", 0, 41)
	add_child(_gunner)
	for i in 2:
		var sm := SoldierModel.new()
		sm.build("rifleman", 0, 40 + i * 2)
		add_child(sm)
		sm.position = [Vector3(-1.4, 0, -0.6), Vector3(1.6, 0, -0.4)][i]
		sm.rotation.y = [0.2, 0.8][i]
		_soldiers.append([sm, [Soldier.Post.CROUCH, Soldier.Post.STAND][i], [Soldier.Act.SHOOT, Soldier.Act.IDLE][i]])
	# a burning wreck and a tank holding the line
	var wreck := VehicleModels.build("old_tank", -1, 3, true)
	add_child(wreck.root)
	wreck.root.position = Vector3(-11, 0, -14)
	wreck.root.rotation = Vector3(0, 0.9, 0.05)
	if wreck.turret:
		wreck.turret.rotation.y = 1.1
	var bn := vfx.make_burner(1.3)
	bn.position = Vector3(-11, 1.4, -14)
	add_child(bn)
	vfx.set_burning(bn, 1.0, 1.0)
	var tank := VehicleModels.build("tank", 0, 1)
	add_child(tank.root)
	tank.root.position = Vector3(9, 0, 6)
	tank.root.rotation.y = 2.4
	if tank.turret:
		tank.turret.rotation.y = -1.9
	var tech := VehicleModels.build("technical", 1, 2, true)
	add_child(tech.root)
	tech.root.position = Vector3(16, 0, -20)
	tech.root.rotation = Vector3(0.0, -0.6, 0.12)
	# trees
	for i in 7:
		var tp := Vector3(_rng.randf_range(-30, -12), 0, _rng.randf_range(6, 26))
		_tree(tp)
	for i in 5:
		_tree(Vector3(_rng.randf_range(18, 34), 0, _rng.randf_range(-6, 16)))
	# smoke on the horizon
	for p in [Vector3(-60, 0, -90), Vector3(45, 0, -110), Vector3(110, 0, -40)]:
		var b2 := vfx.make_burner(2.2)
		b2.position = p
		add_child(b2)
		vfx.set_burning(b2, 0.3, 1.0)


func _part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _tree(p: Vector3) -> void:
	var t := Node3D.new()
	t.position = p
	add_child(t)
	var h := _rng.randf_range(4.5, 6.5)
	var trunk := _part(t, Res.cyl(0.14, 0.3, h, 8), Mats.get_mat("bark"), Vector3(0, h * 0.5, 0))
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var leaf := Color(0.2, 0.32, 0.14).lerp(Color(0.3, 0.33, 0.14), _rng.randf())
	for i in _rng.randi_range(5, 8):
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(0.3, 1.5)
		var lm := _part(t, Res.sphere(_rng.randf_range(1.0, 1.9), 12), Mats.foliage(), Vector3(cos(a) * d, h - 0.4 + _rng.randf_range(-0.6, 1.8), sin(a) * d))
		lm.scale = Vector3(1, _rng.randf_range(0.7, 0.95), 1)
		lm.set_instance_shader_parameter("tint", leaf.darkened(_rng.randf_range(0.0, 0.2)))


func _place_cam() -> void:
	var a := -0.6 + _t * 0.035
	var r := 13.5 + sin(_t * 0.07) * 1.5
	cam.position = Vector3(sin(a) * r, 3.4 + sin(_t * 0.11) * 0.6, cos(a) * r)
	cam.look_at(Vector3(-1.5, 1.1, -2.0), Vector3.UP)


func _process(dt: float) -> void:
	_t += dt
	_place_cam()
	for s in _soldiers:
		(s[0] as SoldierModel).pose(dt, Soldier.Life.ALIVE, s[1], s[2], 0.0, false, s[2] == Soldier.Act.SHOOT and _burst_left > 0)
	_crew_gun(dt)
	# distant shelling
	_next_boom -= dt
	if _next_boom <= 0.0:
		_next_boom = _rng.randf_range(1.8, 4.5)
		var a := _rng.randf_range(-2.6, -0.6)
		var r := _rng.randf_range(40.0, 85.0)
		var bp := Vector3(cos(a) * r, 0.2, sin(a) * r)
		vfx.explode(bp, _rng.randf_range(1.0, 2.0))
		Sfx.play("explosion", bp, -4.0)
	# the .50 cal fires in bursts
	_next_burst -= dt
	if _next_burst <= 0.0 and _burst_left <= 0:
		_burst_left = _rng.randi_range(5, 10)
		_next_burst = _rng.randf_range(2.0, 4.0)
		_aim = _rng.randf_range(-0.35, 0.35)
	if _burst_left > 0:
		_shot_t -= dt
		if _shot_t <= 0.0:
			_shot_t = 0.11
			_burst_left -= 1
			_flash.visible = true
			_flash.set_instance_shader_parameter("rot", _rng.randf() * TAU)
			_flash_t = 0.045
			_light.light_energy = 3.0
			Sfx.play("hmg", _flash.global_position, -10.0)
			if _burst_left % 2 == 0:
				var from := _flash.global_position
				var dir := -(_mg.body as Node3D).global_basis.z
				_tracer(from, from + dir * 120.0 + Vector3(_rng.randf_range(-2, 2), _rng.randf_range(-1, 3), _rng.randf_range(-2, 2)))
	_flash_t -= dt
	if _flash_t <= 0.0:
		_flash.visible = false
	_light.light_energy = maxf(0.0, _light.light_energy - dt * 40.0)
	for i in range(_tracers.size() - 1, -1, -1):
		var tr: Array = _tracers[i]
		tr[3] += dt
		var mi: MeshInstance3D = tr[0]
		var from: Vector3 = tr[1]
		var to: Vector3 = tr[2]
		var k: float = tr[3] * 380.0 / from.distance_to(to)
		if k >= 1.0:
			mi.queue_free()
			_tracers.remove_at(i)
			continue
		mi.global_position = from.lerp(to, k)
		mi.look_at(to, Vector3.UP)


## The gun traverses to where it's laid and bucks while firing; the gunner
## kneels behind its grips and moves round with it, hands on the spades.
func _crew_gun(dt: float) -> void:
	if _mg.is_empty():
		return
	var tr: Node3D = _mg.traverse
	var body: Node3D = _mg.body
	tr.rotation.y = lerp_angle(tr.rotation.y, _aim, 1.0 - exp(-dt * 3.0))
	if _burst_left > 0:
		body.position.z = _rng.randf_range(0.01, 0.03)
	else:
		body.position.z = lerpf(body.position.z, 0.0, 1.0 - exp(-dt * 15.0))
	var gb := Basis(Vector3.UP, gun.rotation.y + tr.rotation.y)
	var gpos := gun.position + gb * Vector3(0, 0, (_mg.grip_r as Vector3).z + 0.5 + body.position.z * 0.8)
	gpos.y = 0.0
	_gunner.transform = Transform3D(gb, gpos)
	_gunner.crew = true
	_gunner.crew_r = body.global_transform * (_mg.grip_r as Vector3)
	_gunner.crew_l = body.global_transform * (_mg.grip_l as Vector3)
	_gunner.pose(dt, Soldier.Life.ALIVE, Soldier.Post.CROUCH, Soldier.Act.SHOOT if _burst_left > 0 else Soldier.Act.IDLE, 0.0, false, _burst_left > 0)


func _tracer(from: Vector3, to: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Res.box(Vector3(0.03, 0.03, 2.4))
	mi.material_override = vfx.tracer_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = from
	_tracers.append([mi, from, to, 0.0])
