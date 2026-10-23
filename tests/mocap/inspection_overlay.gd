extends Node3D
## Inspection drawing uses the live skeleton, including physical ragdoll poses.
var skeleton: Skeleton3D
var model: Node3D
var meshes: Array[MeshInstance3D] = []
var original_overrides: Array[Material] = []
var original_overlays: Array[Material] = []
var lines := ImmediateMesh.new()
var drawing := MeshInstance3D.new()
var labels: Array[Label3D] = []
var show_bones := false
var show_names := false
var selected_bone := -1
var mesh_mode := 0
var triangles := 0
var vertices := 0
var surfaces := 0
var wire: ShaderMaterial

func _ready() -> void:
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, wireframe, depth_draw_never; uniform vec3 line_color = vec3(0.08, 0.3, 0.36); void vertex(){ POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0); POSITION.z += 0.00002 * POSITION.w; } void fragment(){ ALBEDO = line_color; }"
	wire = ShaderMaterial.new()
	wire.shader = shader
	drawing.mesh = lines
	drawing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.render_priority = 10
	drawing.material_override = material
	add_child(drawing)

func bind_model(root: Node3D, rig: Skeleton3D) -> void:
	_restore()
	for label in labels: label.queue_free()
	labels.clear()
	model = root
	skeleton = rig
	meshes.clear()
	original_overrides.clear()
	original_overlays.clear()
	triangles = 0
	vertices = 0
	surfaces = 0
	selected_bone = -1
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node
		if mesh.mesh == null: continue
		meshes.append(mesh)
		original_overrides.append(mesh.material_override)
		original_overlays.append(mesh.material_overlay)
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var count: int = arrays[Mesh.ARRAY_VERTEX].size()
			vertices += count
			surfaces += 1
			if mesh.mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += (indices.size() if not indices.is_empty() else count) / 3
	for i in skeleton.get_bone_count():
		var label := Label3D.new()
		label.text = String(skeleton.get_bone_name(i)).replace("mixamorig_", "")
		label.font_size = 24
		label.outline_size = 6
		label.pixel_size = 0.0015
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = Color("ffdb88")
		label.visible = false
		add_child(label)
		labels.append(label)
	apply_mesh_mode(mesh_mode)

func _restore() -> void:
	for i in meshes.size():
		if not is_instance_valid(meshes[i]): continue
		meshes[i].material_override = original_overrides[i]
		meshes[i].material_overlay = original_overlays[i]
		meshes[i].visible = true

func apply_mesh_mode(mode: int) -> void:
	mesh_mode = mode
	wire.set_shader_parameter("line_color", Vector3(0.15, 0.85, 0.95) if mode == 2 else Vector3(0.08, 0.3, 0.36))
	_restore()
	for mesh in meshes:
		if mode == 1: mesh.material_overlay = wire
		if mode == 2: mesh.material_override = wire
		if mode == 3: mesh.visible = false

func _process(_dt: float) -> void:
	if not is_instance_valid(skeleton): return
	lines.clear_surfaces()
	var enabled := show_bones or mesh_mode == 3
	drawing.visible = enabled
	if enabled: lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in skeleton.get_bone_count():
		var pose := skeleton.global_transform * skeleton.get_bone_global_pose(i)
		var parent := skeleton.get_bone_parent(i)
		var name := String(skeleton.get_bone_name(i))
		var clean := name.replace("mixamorig_", "").replace("mixamorig:", "")
		var major := clean in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "RightShoulder", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftHand", "RightHand", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]
		labels[i].visible = (enabled and show_names and major) or i == selected_bone
		labels[i].global_position = pose.origin + Vector3(0.025, 0.015, 0)
		if not enabled: continue
		var color := Color("ffc65c") if i == selected_bone else Color("55e9cc")
		if i != selected_bone and "Right" in name: color = Color("ee90df")
		lines.surface_set_color(color)
		if parent >= 0:
			lines.surface_add_vertex(pose.origin)
			lines.surface_add_vertex((skeleton.global_transform * skeleton.get_bone_global_pose(parent)).origin)
		for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			lines.surface_add_vertex(pose.origin - axis * 0.012)
			lines.surface_add_vertex(pose.origin + axis * 0.012)
	if enabled: lines.surface_end()
