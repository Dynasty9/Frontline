extends Node3D
## Distant orographic cloud banks; bounded volumes leave the battlefield clear.

var material := ShaderMaterial.new()


func setup(atmo: Atmosphere) -> void:
	material.shader = preload("res://scripts/game/mountain_clouds.gdshader")
	material.set_shader_parameter("noise_tex", atmo.detail_tex)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(atmo.world.settings.get("seed", 1)) + 1907
	var phase := rng.randf() * TAU
	for i in 8:
		var angle := phase + i * TAU / 8.0
		var direction := Vector2(cos(angle), sin(angle))
		var reach := (MapDims.HALF + 850.0) / maxf(absf(direction.x), absf(direction.y))
		var bank := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		bank.mesh = box
		bank.material_override = material
		bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bank.position = Vector3(direction.x * reach, rng.randf_range(290.0, 390.0), direction.y * reach)
		bank.scale = Vector3(1100.0, rng.randf_range(150.0, 230.0), 650.0)
		bank.rotation.y = -angle
		add_child(bank)
	apply_settings(atmo)


func apply_settings(atmo: Atmosphere) -> void:
	var quality := clampi(int(Settings.get_v("mountain_clouds")), 0, 4)
	visible = quality > 0
	material.set_shader_parameter("steps", [8, 8, 12, 20, 32][quality])
	material.set_shader_parameter("detail", quality >= 3)
	material.set_shader_parameter("still", bool(Settings.get_v("reduce_motion")))
	var mood: Dictionary = Atmosphere.MOODS[atmo.mood]
	material.set_shader_parameter("lit_color", (mood.sun as Color) * (0.11 if atmo.mood == "night" else 0.95))
	material.set_shader_parameter("shade_color", (mood.fog as Color) * 0.65)
	var sunlight := Basis.from_euler(Vector3(deg_to_rad(-float(mood.elev)), deg_to_rad(float(mood.azim)), 0.0)).z
	material.set_shader_parameter("sun_direction", sunlight)
	material.set_shader_parameter("coverage", 0.42 if atmo.mood in ["rain", "overcast"] else 0.57)
