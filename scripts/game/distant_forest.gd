class_name DistantForest
extends Node3D
## Only scenery beyond the playable boundary: two triangles per distant tree.

const CELL := 256.0
const SPACING := 8.0
var tree_count := 0

func setup(atmo: Atmosphere) -> void:
	if atmo.world.terrain.landform.peak <= 1.0:
		return
	visible = int(Settings.get_v("lod")) >= 1
	var shader := Shader.new()
	shader.code = MapDims.shader(SHADER.replace("// BACKDROP_HEIGHT", Atmosphere.BACKDROP_HEIGHT))
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("backdrop_tex", atmo.backdrop_tex)
	material.set_shader_parameter("sea_x", atmo.ground_mat.get_shader_parameter("sea_x"))
	material.set_shader_parameter("snow_line", maxf(25.0, atmo.world.terrain.landform.peak * 0.55))
	material.set_shader_parameter("atlas", preload("res://assets/foliage/fir_impostor.png"))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(atmo.world.settings.get("seed", 1)) * 7919
	var noise := FastNoiseLite.new()
	noise.seed = int(rng.seed)
	noise.frequency = 0.006
	var cells := {}
	var reach := MapDims.HALF + 1400.0
	var n := ceili(reach * 2.0 / SPACING)
	for z in n:
		for x in n:
			var p := Vector3(-reach + (x + rng.randf()) * SPACING, 0, -reach + (z + rng.randf()) * SPACING)
			var edge := maxf(absf(p.x), absf(p.z)) - MapDims.HALF
			if edge < 48.0 or edge > 1370.0 or noise.get_noise_2d(p.x, p.z) < -0.06:
				continue
			var cell := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
			if not cells.has(cell):
				cells[cell] = []
			(cells[cell] as Array).append([p, Color(rng.randf_range(0.7, 1.25), rng.randf(), rng.randf(), rng.randf())])
	var quad := QuadMesh.new()
	quad.size = Vector2(16, 16)
	for cell: Vector2i in cells:
		var entries: Array = cells[cell]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = entries.size()
		var origin := Vector3(cell.x * CELL, 0, cell.y * CELL)
		for i in entries.size():
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, entries[i][0] - origin))
			mm.set_instance_custom_data(i, entries[i][1])
		mm.custom_aabb = AABB(Vector3(-16, -5, -16), Vector3(CELL + 32, 470, CELL + 32))
		var mesh := MultiMeshInstance3D.new()
		mesh.multimesh = mm
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position = origin
		add_child(mesh)
		tree_count += entries.size()

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D backdrop_tex : filter_linear_mipmap, repeat_disable;
uniform float sea_x = 1000000000.0;
uniform float snow_line = 100.0;
varying float shade;
// BACKDROP_HEIGHT
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	float h = backdrop(center.xz);
	float slope = length(vec2(backdrop(center.xz + vec2(4,0)) - backdrop(center.xz - vec2(4,0)), backdrop(center.xz + vec2(0,4)) - backdrop(center.xz - vec2(0,4)))) / 8.0;
	float size = INSTANCE_CUSTOM.r;
	// Bare cliff faces and the alpine treeline stay open.
	if (h < 2.0 || h > 190.0 + INSTANCE_CUSTOM.b * 35.0 || slope > 0.75 || center.x > sea_x - 40.0) { size = 0.0; }
	center.y = h + 7.2 * size;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 point = center + right * VERTEX.x * size + up * VERTEX.y * size;
	MODELVIEW_MATRIX = VIEW_MATRIX;
	VERTEX = point;
	NORMAL = vec3(0.0, 1.0, 0.0);
	float tile = floor(INSTANCE_CUSTOM.g * 3.99);
	UV = (UV + vec2(mod(tile, 2.0), floor(tile / 2.0))) * 0.5;
	shade = 0.65 + INSTANCE_CUSTOM.a * 0.30;
}
void fragment() {
	vec4 leaf = texture(atlas, UV);
	ALBEDO = leaf.rgb * shade * 0.65;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.26;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""
