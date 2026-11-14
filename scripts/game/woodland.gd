class_name Woodland
extends RefCounted
## Cosmetic woodland strata follow real canopies without changing cover or gameplay RNG.

var meshes: Array[Mesh] = []
var materials: Array[ShaderMaterial] = []

func setup() -> void:
	meshes = [preload("res://assets/foliage/woodland/fern_02-0.res"), preload("res://assets/foliage/woodland/dead_tree_trunk_02-0.res"), _litter(), _fungi(), _butterfly(), preload("res://assets/foliage/woodland/fern_02-1.res"), preload("res://assets/foliage/woodland/tree_stump_01-0.res"), preload("res://assets/foliage/woodland/nettle_plant-0.res"), preload("res://assets/foliage/woodland/nettle_plant-4.res"), preload("res://assets/foliage/woodland/rock_moss_set_01-0.res"), preload("res://assets/foliage/woodland/rock_moss_set_01-2.res"), preload("res://assets/foliage/woodland/grass_medium_01-3.res"), preload("res://assets/foliage/woodland/grass_medium_01-4.res"), preload("res://assets/foliage/woodland/pine_sapling_small-0-leaves.res"), preload("res://assets/foliage/woodland/pine_sapling_small-0-trunk.res"), preload("res://assets/foliage/woodland/pine_sapling_small-1-leaves.res"), preload("res://assets/foliage/woodland/pine_sapling_small-1-trunk.res")]
	meshes.append(preload("res://assets/foliage/woodland/shrub_02-1.res"))
	var types := [0, 1, 2, 3, 4, 0, 1, 5, 5, 6, 6, 5, 5, 5, 1, 5, 1, 5]
	var scans := ["fern_02", "dead_tree_trunk_02", "", "", "", "fern_02", "tree_stump_01", "nettle_plant", "nettle_plant", "rock_moss_set_01", "rock_moss_set_01", "grass_medium_01", "grass_medium_01", "pine_sapling_small-twig", "pine_sapling_small-bark", "pine_sapling_small-twig", "pine_sapling_small-bark"]
	scans.append("shrub_02")
	var shader := CloudShadow.make(MapDims.shader(SHADER), CloudShadow.BACKLIGHT | CloudShadow.NO_SPECULAR | CloudShadow.FOLD)
	for i in meshes.size():
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("kind", types[i])
		if scans[i] != "":
			material.set_shader_parameter("surface", load("res://assets/foliage/woodland/%s-color.png" % scans[i]))
			material.set_shader_parameter("surface_map", load("res://assets/foliage/woodland/%s-surface.png" % scans[i]))
		elif i == 4:
			material.set_shader_parameter("surface", load("res://assets/foliage/woodland/small-tortoiseshell.jpg"))
		else:
			material.set_shader_parameter("surface", preload("res://assets/foliage/broadleaf.png"))
		materials.append(material)

func build(grass: Grass, cell: Vector2i, nodes: Array) -> void:
	var origin := Vector3(cell.x * Grass.CHUNK, 0, cell.y * Grass.CHUNK)
	var trees: Array[Vector3] = []
	for tree in grass.atmo.world.structures_near(origin + Vector3(16, 0, 16), 32.0):
		if tree.skind == "tree" and (int(tree.variant) & 16) == 0:
			trees.append(tree.position)
	if trees.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell) + int(grass.atmo.world.settings.get("seed", 1)) + 81731
	var transforms := []
	var colors := []
	for i in meshes.size():
		transforms.append([])
		colors.append([])
	for i in (1200 if grass.level == 2 else 400):
		var p := origin + Vector3(rng.randf() * Grass.CHUNK, 0, rng.randf() * Grass.CHUNK)
		if absf(p.x) >= grass.HALF or absf(p.z) >= grass.HALF or grass._is_blocked(p) or grass.atmo.grass_amount(p) <= 0.1:
			continue
		var distance := INF
		for tree: Vector3 in trees:
			distance = minf(distance, Vector2(p.x - tree.x, p.z - tree.z).length())
		if distance < 0.65 or distance > 6.0:
			continue
		var patch := grass._shrub_noise.get_noise_2d(p.x * 2.5, p.z * 2.5)
		if rng.randf() > smoothstep(-0.4, 0.25, patch):
			continue
		var choice := rng.randf()
		var kind := 0 if rng.randf() < 0.4 else 5
		if choice > 0.97 and transforms[4].is_empty():
			kind = 4
		elif choice > 0.965 and distance < 3.0:
			kind = 3
		elif choice > 0.94 and distance > 2.5 and transforms[13].size() + transforms[15].size() < 4:
			kind = 13 if rng.randf() < 0.5 else 15
		elif choice > 0.92 and transforms[6].is_empty():
			kind = 6
		elif choice > 0.88 and transforms[1].is_empty() and distance > 2.4:
			kind = 1
		elif choice > 0.85 and transforms[9].size() + transforms[10].size() < 3:
			kind = 9 if rng.randf() < 0.5 else 10
		elif choice > 0.78:
			kind = 2
		elif choice > 0.6:
			kind = 11 if rng.randf() < 0.5 else 12
		elif choice > 0.55:
			kind = 17
		elif choice > 0.48:
			kind = 7 if rng.randf() < 0.65 else 8
		var damp := grass.atmo.meadow_moisture(p)
		if kind in [0, 3, 5] and damp < 0.25:
			continue
		var yaw := rng.randf() * TAU
		var scale := rng.randf_range(0.7, 1.4)
		if kind == 1:
			scale = rng.randf_range(0.65, 1.0)
		elif kind in [9, 10]:
			scale = rng.randf_range(0.22, 0.5)
		elif kind in [13, 15]:
			scale = rng.randf_range(1.1, 1.8)
		elif kind == 5:
			scale = rng.randf_range(1.2, 2.0)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale * rng.randf_range(0.8, 1.15), scale))
		var bounds := meshes[kind].get_aabb()
		var clear := true
		# Sample the complete footprint, including the ends of four-metre fallen trunks.
		for x in range(floori(bounds.position.x * scale), ceili(bounds.end.x * scale) + 1):
			for z in range(floori(bounds.position.z * scale), ceili(bounds.end.z * scale) + 1):
				if grass._is_blocked(p + Basis(Vector3.UP, yaw) * Vector3(x, 0, z)):
					clear = false
		if not clear:
			continue
		if kind == 1:
			p.y -= 0.55 * scale  # heavy wood settles into litter; thin broken twigs do not prop it up
		if kind in [9, 10]:
			p.y -= 0.3 * scale
		transforms[kind].append(Transform3D(basis, p))
		colors[kind].append(Color(rng.randf(), rng.randf(), damp, 0))
		if kind in [13, 15]:
			transforms[kind + 1].append(Transform3D(basis, p))
			colors[kind + 1].append(colors[kind].back())
	# Plants root beside solid deadwood and stones, rather than through their tops.
	var obstacles := []
	for kind in [1, 6, 9, 10]:
		for pose: Transform3D in transforms[kind]:
			obstacles.append([pose.affine_inverse(), meshes[kind].get_aabb()])
	for kind in [0, 3, 5, 7, 8, 11, 12, 13, 15, 17]:
		for index in range(transforms[kind].size() - 1, -1, -1):
			var pose: Transform3D = transforms[kind][index]
			for obstacle: Array in obstacles:
				var local: Vector3 = obstacle[0] * pose.origin
				var bounds: AABB = obstacle[1]
				if local.x < bounds.position.x or local.x > bounds.end.x or local.z < bounds.position.z or local.z > bounds.end.z:
					continue
				transforms[kind].remove_at(index)
				colors[kind].remove_at(index)
				if kind in [13, 15]:
					transforms[kind + 1].remove_at(index)
					colors[kind + 1].remove_at(index)
				break
	# Broad root skirts bury the seam where a tree's vertical trunk meets the soil.
	for tree: Vector3 in trees:
		if floori(tree.x / Grass.CHUNK) != cell.x or floori(tree.z / Grass.CHUNK) != cell.y or grass._is_blocked(tree) or grass.atmo.grass_amount(tree) <= 0.1:
			continue
		var scale := rng.randf_range(0.55, 0.8)
		transforms[6].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, 0.24, scale)), Vector3(tree.x, -0.04, tree.z)))
		colors[6].append(Color(rng.randf(), 0, 0.5, 1))
	for i in meshes.size():
		if transforms[i].is_empty():
			continue
		# Reserve fauna placements even when hidden, so weather and Wildlife settings
		# do not change the random sequence and rearrange plants, rocks or deadwood.
		if i == 4 and (grass.atmo.mood not in ["day", "golden"] or int(Settings.get_v("wildlife")) == 0):
			continue
		materials[i].set_shader_parameter("deform_tex", grass.mat.get_shader_parameter("deform_tex"))
		materials[i].set_shader_parameter("trench_mask", grass.mat.get_shader_parameter("trench_mask"))
		materials[i].set_shader_parameter("scar", grass.scar_tex)
		var node := grass._mm(meshes[i], materials[i], transforms[i], colors[i], 95.0 if i in [1, 6, 9, 10, 13, 14, 15, 16] else 65.0)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i in [1, 6, 9, 10, 13, 14, 15, 16] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Wind and butterfly flight move beyond the imported mesh bounds.
		node.extra_cull_margin = 1.5
		nodes.append(node)

static func _quad(st: SurfaceTool, points: Array, uv: Array, color := Color.WHITE) -> void:
	for index in [0, 2, 1, 0, 3, 2]:
		st.set_normal(Vector3.UP)
		st.set_color(color)
		st.set_uv(uv[index])
		st.add_vertex(points[index])

const UVS := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]

static func _litter() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 731
	for i in 18:
		var center := Vector3(rng.randf_range(-0.65, 0.65), 0.003 + i * 0.0004, rng.randf_range(-0.65, 0.65))
		var angle := rng.randf() * TAU
		var side := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.02, 0.035)
		var along := Vector3(-sin(angle), 0.04, cos(angle)) * rng.randf_range(0.045, 0.075)
		_quad(st, [center-side-along, center+side-along, center+side+along, center-side+along], [Vector2(0.42, 0.24), Vector2(0.72, 0.24), Vector2(0.72, 0.005), Vector2(0.42, 0.005)])
	return st.commit()

static func _fungi() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5519
	for i in 3:
		var radius := rng.randf_range(0.035, 0.075)
		var height := rng.randf_range(0.055, 0.12)
		var p := Vector3(rng.randf_range(-0.17, 0.17), 0, rng.randf_range(-0.13, 0.13))
		var lean := Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.012, 0.012))
		var profiles := [
			[Vector2(0.012, 0), Vector2(0.007, height * 0.5), Vector2(0.009, height)],
			[Vector2(0.001, height + radius * 0.26), Vector2(radius * 0.35, height + radius * 0.4), Vector2(radius * 0.75, height + radius * 0.27), Vector2(radius, height), Vector2(radius * 0.94, height - radius * 0.08), Vector2(radius * 0.4, height - radius * 0.12), Vector2(0.008, height * 0.85)]
		]
		for component in profiles.size():
			var profile: Array = profiles[component]
			for ring in profile.size() - 1:
				for segment in 16:
					for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
						var section: Vector2 = profile[ring + corner.y]
						var angle := TAU * (segment + corner.x) / 16.0
						var ripple := 1.0 + sin(angle * 5.0 + i) * 0.045
						var point := Vector3(cos(angle) * section.x * ripple, section.y, sin(angle) * section.x * ripple)
						point += Vector3(lean.x, 0, lean.y) * (section.y / height)
						st.set_color(Color(float(component), float(i) / 3.0, 0, 1))
						st.set_uv(Vector2(float(segment + corner.x) / 16.0, section.x / radius))
						st.set_smooth_group(0)
						st.add_vertex(p + point)
	st.generate_normals()
	return st.commit()

static func _butterfly() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Trace the photographed wing; texture coordinates retain the real markings.
	var outline := [Vector2(208, 327), Vector2(207, 280), Vector2(207, 213), Vector2(211, 150), Vector2(218, 94), Vector2(237, 83), Vector2(268, 111), Vector2(290, 145), Vector2(315, 174), Vector2(344, 180), Vector2(365, 197), Vector2(389, 207), Vector2(413, 215), Vector2(418, 244), Vector2(420, 273), Vector2(431, 297), Vector2(436, 324), Vector2(417, 339), Vector2(389, 352), Vector2(350, 361), Vector2(305, 360), Vector2(257, 348)]
	for side in [-1.0, 1.0]:
		for i in range(1, outline.size() - 1):
			var triangle := [outline[0], outline[i], outline[i + 1]]
			if side < 0.0:
				triangle.reverse()
			for pixel: Vector2 in triangle:
				var offset: Vector2 = pixel - outline[0]
				var span := maxf(0.0, offset.dot(Vector2(0.274, -0.962))) * 0.00012
				var along: float = offset.dot(Vector2(0.962, 0.274)) * 0.00012 - 0.008
				st.set_normal(Vector3.UP)
				st.set_color(Color(1, 0, 0))
				st.set_uv(pixel / Vector2(593, 526))
				st.add_vertex(Vector3((span + 0.001) * side, 0, along))
	var body := [Vector2(-0.014, 0.0003), Vector2(-0.011, 0.0025), Vector2(-0.004, 0.0022), Vector2(0.006, 0.0015), Vector2(0.015, 0.0001)]
	for ring in body.size() - 1:
		for segment in 8:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var section: Vector2 = body[ring + corner.y]
				var angle := TAU * (segment + corner.x) / 8.0
				st.set_normal(Vector3(cos(angle), sin(angle), 0))
				st.set_color(Color(0, 0, 0))
				st.set_uv(Vector2.ZERO)
				st.add_vertex(Vector3(cos(angle) * section.y, sin(angle) * section.y + 0.001, section.x))
	for side in [-1.0, 1.0]:
		var base := Vector3(side * 0.001, 0.002, -0.013)
		var tip := Vector3(side * 0.005, 0.005, -0.025)
		_quad(st, [base - Vector3(0.00015, 0, 0), base + Vector3(0.00015, 0, 0), tip + Vector3(0.0003, 0, 0), tip - Vector3(0.0003, 0, 0)], UVS, Color(0, 0, 0))
	return st.commit()

const SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D surface : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2DArray deform_tex : filter_linear, repeat_disable;
uniform sampler2D trench_mask : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D scar : hint_default_black, filter_linear, repeat_disable;
uniform int kind = 0;
// TERRAIN_TEXTURE_HELPER
// CLOUD_SHADOW
varying vec3 wpos;
varying float variation;
varying float damp;
varying float burnt;
varying float root_light;
void vertex() {
	root_light = smoothstep(0.0, 0.35, VERTEX.y);
	variation = INSTANCE_CUSTOM.r;
	damp = INSTANCE_CUSTOM.b;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float scale = max(length(MODEL_MATRIX[1].xyz), 0.05);
	if (kind == 0 || kind == 5) {
		float gust = sin(TIME * 1.3 + origin.x * 0.2 + origin.z * 0.13) + sin(TIME * 2.7 + origin.z) * 0.3;
		VERTEX.x += gust * 0.045 * VERTEX.y * VERTEX.y;
		VERTEX.z += gust * 0.025 * VERTEX.y;
	}
	if (kind == 4) {
		float time = TIME * mix(0.85, 1.15, INSTANCE_CUSTOM.g) + variation * 50.0;
		float phase = time * 30.0;
		float fold = 0.35 + sin(phase) * 0.85;
		VERTEX.y += abs(VERTEX.x) * sin(fold) * COLOR.r;
		VERTEX.x *= mix(1.0, cos(fold), COLOR.r);
		vec2 velocity = vec2(cos(time * 0.8) * 0.44 + cos(time * 1.7) * 0.17, -sin(time * 0.65) * 0.36);
		float heading = atan(velocity.x, velocity.y);
		VERTEX.xz = mat2(vec2(cos(heading), -sin(heading)), vec2(sin(heading), cos(heading))) * VERTEX.xz;
		VERTEX += vec3(sin(time * 0.8) * 0.55 + sin(time * 1.7) * 0.1, 0.8 + sin(time * 1.7) * 0.18, cos(time * 0.65) * 0.55);
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = (wpos.xz + __MAP_HALF__) / __MAP_SIZE__;
	float height = terrain_height(deform_tex, uv);
	burnt = textureLod(scar, uv, 0.0).r;
	if (textureLod(trench_mask, uv, 0.0).r > 0.3 || height - terrain_geology(deform_tex, uv) < -0.12 || (kind == 4 && burnt > 0.1)) VERTEX *= 0.0;
	VERTEX.y += height / scale;
	wpos.y += height;
}
void fragment() {
	vec4 photograph = texture(surface, UV);
	if (OUTPUT_IS_SRGB) photograph.rgb = mix(photograph.rgb / 12.92, pow((photograph.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), photograph.rgb));
	vec3 col = photograph.rgb;
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.25;
	if (kind == 0 || kind == 2 || kind == 5) {
		ALPHA = photograph.a;
	}
	if (kind == 0 || kind == 5) col *= mix(vec3(0.62,0.76,0.55), vec3(0.88,0.92,0.72), variation) * mix(0.6, 1.0, root_light);
	if (kind == 1) col *= mix(vec3(0.55,0.52,0.43), vec3(0.8,0.83,0.65), variation);
	if (kind == 6) col *= mix(vec3(0.9), vec3(0.6,0.7,0.57), damp);
	if (kind == 2) col = vec3(dot(col, vec3(0.3,0.5,0.2))) * mix(vec3(0.5,0.38,0.22), vec3(0.8,0.58,0.32), variation);
	if (kind == 3) {
		float top = smoothstep(-0.1, 0.5, (INV_VIEW_MATRIX * vec4(NORMAL,0.0)).y);
		float grain = sin(UV.x * 173.0 + sin(UV.y * 59.0)) * 0.5 + 0.5;
		float gills = pow(abs(sin(UV.x * 150.8)), 4.0);
		vec3 stem = vec3(0.25, 0.19, 0.11) * (0.85 + grain * 0.15);
		vec3 cap = mix(vec3(0.075, 0.035, 0.012), vec3(0.2, 0.105, 0.04), COLOR.g + UV.y * 0.3);
		cap *= 0.85 + grain * 0.15;
		col = mix(stem, mix(vec3(0.18, 0.13, 0.075) * (0.65 + gills * 0.35), cap, top), COLOR.r);
	}
	if (kind == 4) {
		vec3 wing = photograph.rgb * 0.8;
		if (!FRONT_FACING) wing = mix(vec3(dot(wing, vec3(0.3, 0.5, 0.2))), wing, 0.25) * vec3(0.45, 0.4, 0.32);
		col = mix(vec3(0.012, 0.009, 0.006), wing, COLOR.r);
	}
	col *= 1.0 - burnt * 0.85;
	if (OUTPUT_IS_SRGB) col = mix(col * 12.92, 1.055 * pow(max(col,vec3(0.0)),vec3(1.0/2.4)) - 0.055, step(vec3(0.0031308),col));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	if (kind == 0 || kind == 1 || kind == 5 || kind == 6) {
		vec4 detail = texture(surface_map, UV);
		NORMAL_MAP = vec3(detail.rg, 1.0);
		NORMAL_MAP_DEPTH = kind == 1 || kind == 6 ? 0.85 : 0.4;
		ROUGHNESS = clamp(detail.a, 0.65, 1.0);
		AO = detail.b * mix(0.75, 1.0, root_light);
		AO_LIGHT_AFFECT = 0.5;
	}
	BACKLIGHT = kind == 0 || kind == 5 ? vec3(0.05,0.08,0.02) : vec3(0.0);
	if (kind == 0 || kind == 2 || kind == 4 || kind == 5) {
		vec3 normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		normal.y = abs(normal.y);
		NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);
	}
	// CLOUD_FRAGMENT cloud_sun(wpos)
}
"""
