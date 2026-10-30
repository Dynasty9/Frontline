extends Node3D
## Render and collision share the same triangles, including the rolling slope.
const HALF := 20.0
const STEP := 0.5

static func height_at(x: float, z: float) -> float:
	var hill := 1.5 * smoothstep(1.0, 6.0, -z) * (1.0 - smoothstep(10.0, 16.0, -z))
	var rough := smoothstep(0.5, 3.0, absf(x)) * 0.18 * sin(x * 1.3) * sin(z * 1.1)
	var bank := 0.7 * exp(-pow((x - 6.0) / 3.0, 2.0) - pow((z + 5.0) / 5.0, 2.0))
	return hill + rough + bank

func _ready() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := int(HALF / STEP)
	for z in range(-cells, cells):
		for x in range(-cells, cells):
			var a := Vector3(x * STEP, height_at(x * STEP, z * STEP), z * STEP)
			var b := Vector3((x + 1) * STEP, height_at((x + 1) * STEP, z * STEP), z * STEP)
			var c := Vector3(x * STEP, height_at(x * STEP, (z + 1) * STEP), (z + 1) * STEP)
			var d := Vector3((x + 1) * STEP, height_at((x + 1) * STEP, (z + 1) * STEP), (z + 1) * STEP)
			for vertex in [a, b, c, b, d, c]: surface.add_vertex(vertex)
	surface.generate_normals()
	var geometry := surface.commit()
	var visual := MeshInstance3D.new()
	visual.mesh = geometry
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; varying vec3 wp; void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){float path=1.0-smoothstep(1.3,2.0,abs(wp.x));float grain=fract(sin(dot(floor(wp.xz*35.0),vec2(12.9898,78.233)))*43758.5453);vec3 grass=mix(vec3(0.085,0.115,0.055),vec3(0.15,0.18,0.09),grain);ALBEDO=mix(grass,vec3(0.23,0.20,0.15)*(0.85+grain*0.2),path);ROUGHNESS=0.95;}"
	material.shader = shader
	visual.material_override = material
	add_child(visual)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = geometry.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)
