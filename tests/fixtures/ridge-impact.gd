extends MeshInstance3D
## A breakaway prop for the film. Layers are art settings for a dent or a tear.
var plies_left: int
var struck := false
var exposed := false

func fit(plies: int) -> void:
	plies_left = plies
	var steel := StandardMaterial3D.new()
	steel.vertex_color_use_as_albedo = true
	steel.vertex_color_is_srgb = true
	steel.roughness = 0.80
	steel.metallic = 0.25
	steel.render_priority = -1
	steel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = steel
	visible = false

func take_hit() -> void:
	plies_left = maxi(0, plies_left - 1)
	struck = true
	visible = true
	exposed = plies_left == 0
	_shape()

func _shape() -> void:
	var skin := SurfaceTool.new()
	skin.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 4 if exposed else 5
	var steps := 32
	for ring in rings:
		for j in steps:
			var angle := TAU * j / steps
			var direction := Vector2(cos(angle), sin(angle))
			var uneven := 1.0 + 0.11 * sin(3.0 * angle + 0.8) + 0.055 * cos(8.0 * angle + 1.6)
			var radius: float = [1.56, 1.24, 1.0, 0.61, 0.015][ring]
			var xy := direction * Vector2(0.16,0.092) * uneven * radius
			var depth := 0.003
			var shade := Color("393930")
			if exposed:
				# One lip peels out. Most of the torn edge stays dark.
				if ring == 0:
					shade.a = 0.0
				elif ring == 1:
					shade = Color("302f28")
				elif ring == 2:
					var peeled := pow(maxf(0.0, cos(angle - 0.82)), 6.0)
					depth += 0.012 + 0.064 * peeled
					shade = Color("524c3f").lerp(Color("897b66"), peeled)
				else:
					depth = -0.063
					shade = Color("24221e")
			else:
				# The first hit strips a narrow streak of paint. A few raised
				# scratches catch the sun on just one edge of the groove.
				xy.x *= 1.38
				xy.y = xy.y * 0.27 * (1.05 + 0.38 * direction.x) + xy.x * 0.18
				if ring == 0:
					shade.a = 0.0
				elif ring == 1:
					shade = Color("4d4c3f", 0.55)
				elif ring == 2:
					depth = 0.008
					shade = Color("746d59") if direction.y > 0.25 and j % 6 != 0 else Color("504e42")
				else:
					shade = Color("47473f")
			skin.set_color(shade)
			skin.add_vertex(Vector3(xy.x, xy.y, depth))
	for i in (rings - 1):
		for j in steps:
			var a := i * steps + j
			var b := i * steps + (j + 1) % steps
			for index: int in [a, a + steps, b, b, a + steps, b + steps]:
				skin.add_index(index)
	if not exposed:
		for j in range(1, steps - 1):
			for index: int in [0, j + 1, j]:
				skin.add_index((rings - 1) * steps + index)
	skin.generate_normals()
	mesh = skin.commit()
