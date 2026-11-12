class_name DistantForest
extends Node3D
## Only scenery beyond the playable boundary: two triangles per distant tree.

const CELL := 256.0
const SPACING := 5.0
var tree_count := 0
var coverage: Image
var material: ShaderMaterial
static var _atlas: Texture2DArray

static func atlas_texture() -> Texture2DArray:
	if _atlas == null:
		var source := preload("res://assets/foliage/fir_impostor.png").get_image()
		if source.is_compressed():
			source.decompress()
		var images: Array[Image] = []
		for row in 5:
			for column in 4:
				var tile := source.get_region(Rect2i(column * 256, row * 256, 256, 256))
				tile.fix_alpha_edges()
				tile.generate_mipmaps()
				images.append(tile)
		_atlas = Texture2DArray.new()
		var error := _atlas.create_from_images(images)
		assert(error == OK, "Distant tree atlas layers must share size and mipmaps")
	return _atlas

static func coverage_image(seed_value: int, reach: float) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	# Broad, ragged stands: seen edge-on from across the valley, small round patches
	# foreshorten into thin parallel stripes.
	noise.frequency = 0.003
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = 180.0
	noise.domain_warp_frequency = 0.004
	var img := Image.create(256, 256, false, Image.FORMAT_R8)
	for z in 256:
		for x in 256:
			var p := (Vector2(x, z) + Vector2.ONE * 0.5) / 256.0 * reach * 2.0 - Vector2.ONE * reach
			var edge := maxf(absf(p.x), absf(p.y)) - MapDims.HALF
			var density := smoothstep(-0.06, 0.18, noise.get_noise_2d(p.x, p.y))
			density *= smoothstep(48.0, 80.0, edge) * (1.0 - smoothstep(1300.0, 1370.0, edge))
			img.set_pixel(x, z, Color(density, 0, 0))
	return img

func setup(atmo: Atmosphere) -> void:
	if atmo.world.terrain.landform.peak <= 1.0:
		return
	var shader := Shader.new()
	shader.code = MapDims.shader(SHADER.replace("// BACKDROP_HEIGHT", Atmosphere.BACKDROP_HEIGHT))
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("backdrop_tex", atmo.backdrop_tex)
	if atmo.water_view:
		material.set_shader_parameter("river_tips", atmo.water_view.river_tips)
	material.set_shader_parameter("sea_x", atmo.ground_mat.get_shader_parameter("sea_x"))
	material.set_shader_parameter("scenery_coast_phase", atmo.ground_mat.get_shader_parameter("scenery_coast_phase"))
	material.set_shader_parameter("snow_line", maxf(150.0, atmo.world.terrain.landform.peak * 0.55))
	material.set_shader_parameter("atlas", atlas_texture())
	var air: Variant = atmo.ground_mat.get_shader_parameter("terrain_air")
	set_air(atmo.ground_mat.get_shader_parameter("air_color"), float(air) if air != null else 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(atmo.world.settings.get("seed", 1)) * 7919
	var cells := {}
	var reach := MapDims.HALF + 1400.0
	coverage = coverage_image(int(rng.seed), reach)
	atmo.ground_mat.set_shader_parameter("forest_cover", ImageTexture.create_from_image(coverage))
	var n := ceili(reach * 2.0 / SPACING)
	for z in n:
		for x in n:
			var p := Vector3(-reach + (x + rng.randf()) * SPACING, 0, -reach + (z + rng.randf()) * SPACING)
			var edge := maxf(absf(p.x), absf(p.z)) - MapDims.HALF
			var uv := (Vector2(p.x, p.z) + Vector2.ONE * reach) / (reach * 2.0)
			var density := coverage.get_pixel(clampi(int(uv.x * 256.0), 0, 255), clampi(int(uv.y * 256.0), 0, 255)).r
			if edge < 48.0 or edge > 1370.0 or rng.randf() >= density:
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
	apply_settings()

## The ground's distance haze, so far stands fade with the slopes they grow on.
func set_air(color: Variant, density: float) -> void:
	if material:
		if color != null:
			material.set_shader_parameter("air_color", color)
		material.set_shader_parameter("terrain_air", density)


func apply_settings() -> void:
	visible = int(Settings.get_v("lod")) >= 1
	var shadows := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if int(Settings.get_v("shadows")) >= 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for chunk: MultiMeshInstance3D in get_children():
		chunk.cast_shadow = shadows

func set_lighting(bake: Texture2D, toward_sun: Vector3) -> void:
	if material:
		material.set_shader_parameter("scenery_bake", bake)
		material.set_shader_parameter("sun_direction", toward_sun)

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2DArray atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D backdrop_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D scenery_bake : hint_default_white, filter_linear, repeat_disable;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform float sea_x = 1000000000.0;
uniform float snow_line = 100.0;
uniform float terrain_air = 0.0;
uniform vec3 air_color : source_color = vec3(0.5, 0.6, 0.7);
varying float shade;
varying float haze;
varying vec3 frames;
varying vec2 lighting;
// BACKDROP_HEIGHT
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	float h = backdrop(center.xz);
	float slope = length(vec2(backdrop(center.xz + vec2(16,0)) - backdrop(center.xz - vec2(16,0)), backdrop(center.xz + vec2(0,16)) - backdrop(center.xz - vec2(0,16)))) / 32.0;
	float size = INSTANCE_CUSTOM.r;
	// Bare cliff faces and the alpine treeline stay open.
	float habitat = forest_habitat(center.xz, h, slope);
	if (habitat < INSTANCE_CUSTOM.b) { size = 0.0; }
	size *= mix(0.65, 1.0, habitat);
	center.y = h;
	lighting = textureLod(scenery_bake, (center.xz + __MAP_HALF__ + 1800.0) / (__MAP_SIZE__ + 3600.0), 0.0).rb;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	// The image is captured around the physical crown centre at every elevation.
	center.y += 7.2 * size;
	vec3 point = center + right * VERTEX.x * size + up * VERTEX.y * size;
	vec3 toward_camera = normalize(INV_VIEW_MATRIX[3].xyz - center);
	float elevation = clamp(atan(toward_camera.y, length(toward_camera.xz)) / (PI * 0.125), 0.0, 4.0);
	MODELVIEW_MATRIX = VIEW_MATRIX;
	VERTEX = point;
	NORMAL = vec3(0.0, 1.0, 0.0);
	float tile = floor(INSTANCE_CUSTOM.g * 3.99);
	frames = vec3(floor(elevation) * 4.0 + tile, min(floor(elevation) + 1.0, 4.0) * 4.0 + tile, fract(elevation));
	shade = 0.65 + INSTANCE_CUSTOM.a * 0.30;
	// The same thin air the ground beneath fades into (Atmosphere's ground shader),
	// or every distant stand reads as a dark stipple on pale, hazed slopes.
	float optical_depth = max(0.0, distance(CAMERA_POSITION_WORLD, center) - 500.0) * terrain_air;
	haze = min(0.48, 1.0 - exp(-optical_depth * exp(-max(center.y, 0.0) / 520.0)));
	haze *= smoothstep(__MAP_HALF__, __MAP_HALF__ + 200.0, max(abs(center.x), abs(center.z)));
}
void fragment() {
	vec4 low = texture(atlas, vec3(UV, frames.x));
	vec4 high = texture(atlas, vec3(UV, frames.y));
	if (OUTPUT_IS_SRGB) {
		low.rgb = mix(low.rgb / 12.92, pow((low.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), low.rgb));
		high.rgb = mix(high.rgb / 12.92, pow((high.rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), high.rgb));
	}
	float alpha = mix(low.a, high.a, frames.z);
	vec4 leaf = vec4(mix(low.rgb * low.a, high.rgb * high.a, frames.z) / max(alpha, 0.001), alpha);
	ALBEDO = leaf.rgb * shade * 0.65 * (1.0 - haze);
	EMISSION = air_color * haze * 0.65;
	if (OUTPUT_IS_SRGB) {
		ALBEDO = mix(ALBEDO * 12.92, 1.055 * pow(max(ALBEDO, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), ALBEDO));
	}
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.26;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	AO = lighting.r;
}
void light() {
	float shadow = 1.0;
	if (LIGHT_IS_DIRECTIONAL && dot(LIGHT, normalize((VIEW_MATRIX * vec4(sun_direction, 0.0)).xyz)) > 0.95) {
		shadow = lighting.g;
	}
	DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI * shadow;
}
"""
