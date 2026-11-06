class_name BlastFlipbooks
extends Node3D
## Relightable fluid simulations, baked offline. A blast uses one surface;
## shrapnel and clods remain in GunFx's shared GPU rings.
const CAPACITY := {"dust": 28, "fuel": 12}
var vfx: Vfx
var _shader: Shader
var _pools := {"dust": [], "fuel": []}
var _textures := {}
var _clock := 0.0

class Blast:
	var mesh: MeshInstance3D
	var material: ShaderMaterial
	var start := -1000.0
	var life := 0.0
	var generation := 0

func _ready() -> void:
	_shader = load("res://scripts/shaders/blast_flipbook.gdshader")
	for kind in CAPACITY:
		var maps := []
		for suffix in ["positive", "negative", "motion", "bounds"]:
			# Low/medium effects never sample optical flow. Leave those two
			# large maps unloaded unless the player later raises the setting.
			maps.append(null if suffix == "motion" and Settings.fx_mult() <= 0.65 else load("res://assets/vfx/%s_%s.png" % [kind, suffix]))
		_textures[kind] = maps

func _new_blast(kind: String) -> Blast:
	var b := Blast.new()
	b.mesh = MeshInstance3D.new()
	b.mesh.mesh = vfx.quad
	b.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.mesh.visibility_range_end = 650.0
	var span := 21.0 if kind == "fuel" else 18.0
	var height := 7.0 if kind == "fuel" else 2.7
	# The vertex shader lifts and enlarges the shared unit quad. Give culling
	# and transparent sorting its real cloud center, with room to face the
	# camera and drift, instead of sorting every cloud at ground level.
	b.mesh.custom_aabb = AABB(Vector3(-span * 0.5, height - span * 0.5, -span * 0.5), Vector3.ONE * span)
	b.mesh.extra_cull_margin = 8.0
	# Each pooled surface owns its small set of uniforms. On Compatibility
	# this avoids rebuilding Mats' derived-material cache every animation tick.
	b.material = ShaderMaterial.new()
	b.material.shader = _shader
	b.material.set_shader_parameter("positive_map", _textures[kind][0])
	b.material.set_shader_parameter("negative_map", _textures[kind][1])
	b.material.set_shader_parameter("motion_map", _textures[kind][2])
	b.material.set_shader_parameter("bounds_map", _textures[kind][3])
	b.material.set_shader_parameter("fuel", 1.0 if kind == "fuel" else 0.0)
	b.material.set_shader_parameter("span", span)
	b.material.set_shader_parameter("center_height", height)
	b.mesh.material_override = b.material
	add_child(b.mesh)
	copy_light(b.material)
	return b

func burst(p: Vector3, size: float, kind: String, detail: float, ground := true) -> Blast:
	var key := "fuel" if kind == "fuel" or not ground else "dust"
	var pool: Array = _pools[key]
	var budget := maxi(4, int(CAPACITY[key] * Settings.fx_mult()))
	# Retain allocations when quality changes, but don't keep drawing or
	# reactivating the larger high-quality pool after the player lowers it.
	for index in range(budget, pool.size()):
		var excess: Blast = pool[index]
		excess.mesh.visible = false
		excess.start = -1000.0
	var b: Blast
	var oldest: Blast
	for index in mini(pool.size(), budget):
		var candidate: Blast = pool[index]
		if _clock - candidate.start >= candidate.life:
			b = candidate
			break
		if oldest == null or candidate.start < oldest.start:
			oldest = candidate
	if b == null:
		if pool.size() < budget:
			b = _new_blast(key)
			pool.append(b)
		else:
			b = oldest
	var scale_k := (0.32 if kind == "frag" else (0.60 if kind == "fuel" else 0.72)) * sqrt(maxf(size, 0.1))
	if not ground:
		scale_k *= 0.65
	b.start = _clock
	b.generation += 1
	b.life = (3.2 if kind == "frag" else (6.4 if kind == "fuel" else 5.0)) * randf_range(0.94, 1.06)
	if not ground:
		b.life *= 0.7
	b.mesh.global_position = p
	b.mesh.scale = Vector3.ONE * scale_k
	b.mesh.visible = true
	b.material.set_shader_parameter("fuel", 1.0 if kind == "fuel" else 0.0)
	b.material.set_shader_parameter("ground_dust", 1.0 if key == "dust" else 0.0)
	b.material.set_shader_parameter("age", 0.0)
	b.material.set_shader_parameter("duration", b.life)
	b.material.set_shader_parameter("mirror", -1.0 if randf() < 0.5 else 1.0)
	b.material.set_shader_parameter("interpolate", detail * Settings.fx_mult() > 0.45)
	var use_motion := detail * Settings.fx_mult() > 0.65
	if use_motion:
		if _textures[key][2] == null:
			_textures[key][2] = load("res://assets/vfx/%s_motion.png" % key)
		b.material.set_shader_parameter("motion_map", _textures[key][2])
	b.material.set_shader_parameter("motion_enabled", use_motion)
	var tint := Color(0.19, 0.18, 0.17) if kind == "fuel" else Color(0.55, 0.49, 0.40)
	var density := 1.0
	if not ground:
		tint = Color(0.62, 0.61, 0.59)
	elif kind != "fuel" and vfx.world:
		var terrain := vfx.world.terrain
		if terrain:
			var index := terrain.idx_of(p)
			if terrain.base[index] == TerrainMap.ROAD or terrain.rubble[index] > 0:
				tint = Color(0.55, 0.54, 0.51)
			elif terrain.base[index] == TerrainMap.MUD:
				tint = Color(0.34, 0.29, 0.23)
				density = 0.65
		if vfx.world.atmo and vfx.world.atmo.mood == "rain":
			tint = tint.darkened(0.18)
			density *= 0.65
	b.material.set_shader_parameter("tint", tint)
	b.material.set_shader_parameter("opacity", density)
	return b

func prewarm(at: Vector3) -> void:
	for kind in ["he", "fuel"]:
		var b := burst(at, 1.4, kind, 1.0)
		var generation := b.generation
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(b.mesh) and b.generation == generation:
				b.mesh.visible = false
				b.start = -1000.0
		)

func copy_light(material: ShaderMaterial) -> void:
	if vfx == null or vfx.smoke_mat == null:
		return
	for key in ["sun_dir", "sun_col", "sun_energy", "amb_col", "amb_energy"]:
		var value: Variant = vfx.smoke_mat.get_shader_parameter(key)
		if value != null:
			material.set_shader_parameter(key, value)

func apply_lighting() -> void:
	for pool: Array in _pools.values():
		for b: Blast in pool:
			copy_light(b.material)

func _process(dt: float) -> void:
	_clock += dt
	for key in CAPACITY:
		for b: Blast in _pools[key]:
			if not b.mesh.visible:
				continue
			var age := _clock - b.start
			if age >= b.life:
				b.mesh.visible = false
			else:
				b.material.set_shader_parameter("age", age)
