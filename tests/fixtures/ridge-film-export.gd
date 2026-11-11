extends "res://tests/fixtures/ridge-duel.gd"

# glTF has no Godot shader or MultiMesh representation. Keep one copy of
# each mesh and record the displayed world transforms alongside it.
enum PlatePose { ORIGINAL, SCORED, OPEN }

var destination := OS.get_environment("FL_RIG_CACHE")
var geometry: Node3D
var part_names: Array[String] = []
var sources: Array[Node3D] = []
var instance_ids := PackedInt32Array()
var plate_modes := PackedInt32Array()
var mesh_cache := {}
var material_cache := {}
var palette := {}
var vegetation := {}
var shots: Array[Dictionary] = []
var transforms: FileAccess
var camera_data: FileAccess


func _ready() -> void:
	super._ready()
	if destination.is_empty() or capture_fps != FPS:
		push_error("Set FL_RIG_CACHE to an output directory and pass --ridge-fps=30")
		get_tree().quit(1)
		return
	var error := DirAccess.make_dir_recursive_absolute(destination.path_join("ruts"))
	if error != OK:
		push_error("Cannot create the ridge film cache at " + destination)
		get_tree().quit(1)
		return
	transforms = FileAccess.open(destination.path_join("motion.f32"), FileAccess.WRITE)
	camera_data = FileAccess.open(destination.path_join("camera.f32"), FileAccess.WRITE)
	if not transforms or not camera_data:
		push_error("Cannot write ridge film poses to " + destination)
		get_tree().quit(1)
		return
	geometry = Node3D.new()
	shot_fired.connect(_record_shot)
	for i in tanks.size():
		var tank := tanks[i]
		for node in tank.model.find_children("*", "MeshInstance3D", true, false):
			var part := node as MeshInstance3D
			if part != tank.plate and part.mesh and part.visibility_range_begin == 0:
				_record_mesh("tank%d" % i, part, _copy_mesh(part.mesh, part.material_override))
		for belt in tank._vm.belts:
			var shoe := _copy_mesh(belt.multimesh.mesh, null)
			for link_id in belt.multimesh.instance_count:
				_record_mesh("shoe%d" % i, belt, shoe, link_id)
		# Both tear shapes share the plate mount. Only the current one is drawn.
		for mode in [PlatePose.SCORED, PlatePose.OPEN]:
			var plate := ImpactPlate.new()
			plate.fit(2 if mode == PlatePose.SCORED else 1)
			plate.take_hit()
			_record_mesh("scar%d" % i, tank.plate, _copy_mesh(plate.mesh, plate.material_override), -1, mode)
			plate.free()
	for child in get_children():
		if child is MeshInstance3D and child.material_override == ground_material:
			_add_mesh("RidgeGround", _copy_mesh(child.mesh, ground_material))
		elif child is Grass:
			_record_scatter(child)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	error = document.append_from_scene(geometry, state)
	if error == OK:
		error = document.write_to_filesystem(state, destination.path_join("stage.glb"))
	geometry.free()
	if error != OK:
		push_error("Cannot write ridge film glTF: " + error_string(error))
		get_tree().quit(1)


func _record_scatter(grass: Node3D) -> void:
	for child in grass.get_children():
		var scatter := child as MultiMeshInstance3D
		if not scatter:
			continue
		var key := String(scatter.name)
		var mesh := scatter.multimesh
		_add_mesh(key, _copy_mesh(mesh.mesh, scatter.material_override))
		var out := FileAccess.open(destination.path_join(key + ".f32"), FileAccess.WRITE)
		for i in mesh.instance_count:
			_write_transform(out, scatter.global_transform * mesh.get_instance_transform(i))
		vegetation[key] = mesh.instance_count


func _record_mesh(prefix: String, source: Node3D, mesh: Mesh, instance := -1, mode := PlatePose.ORIGINAL) -> void:
	var key := "%s_%d" % [prefix, part_names.size()]
	_add_mesh(key, mesh)
	part_names.append(key)
	sources.append(source)
	instance_ids.append(instance)
	plate_modes.append(mode)


func _add_mesh(key: String, mesh: Mesh) -> void:
	var child := MeshInstance3D.new()
	child.mesh = mesh
	child.name = key
	geometry.add_child(child)
	child.owner = geometry


func _copy_mesh(original: Mesh, override: Material) -> Mesh:
	var key := "%d_%d" % [original.get_instance_id(), override.get_instance_id() if override else 0]
	if mesh_cache.has(key):
		return mesh_cache[key]
	var copy := ArrayMesh.new()
	for i in original.get_surface_count():
		var arrays := original.surface_get_arrays(i)
		if arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := override if override else original.surface_get_material(i)
		copy.surface_set_material(copy.get_surface_count() - 1, _gltf_material(material))
	mesh_cache[key] = copy
	return copy


func _gltf_material(material: Material) -> StandardMaterial3D:
	if material is StandardMaterial3D:
		return material
	if material_cache.has(material):
		return material_cache[material]
	var basic := StandardMaterial3D.new()
	var label := "paint_%03d" % material_cache.size()
	var params := {}
	if material is ShaderMaterial and material.shader == Mats.shader():
		for key in ["col_a", "col_b", "col_c", "col_d", "pattern", "rough", "metal", "vcolor_k", "worn_armour"]:
			var value = material.get_shader_parameter(key)
			if value is Color:
				params[key] = [value.r, value.g, value.b]
			elif value != null:
				params[key] = value
		basic.albedo_color = material.get_shader_parameter("col_a")
		basic.vertex_color_use_as_albedo = true
	elif material == ground_material:
		label = "TerrainSoil"
	elif material is ShaderMaterial:
		label = "TuftCards"
	basic.resource_name = label
	palette[label] = params
	material_cache[material] = basic
	return basic


func _record_shot(beat: int, muzzle: Vector3, contact: Vector3, ground: bool) -> void:
	shots.append({"time": float(beat) / FPS, "from": [muzzle.x, muzzle.y, muzzle.z],
		"to": [contact.x, contact.y, contact.z], "ground": ground})


func _process(dt: float) -> void:
	if not transforms or not camera_data:
		return
	super._process(dt)
	if sample_count % 6 == 1:
		marks.save_png(destination.path_join("ruts/%04d.png" % (sample_count - 1)))
	for i in sources.size():
		var source := sources[i]
		var pose := source.global_transform
		if instance_ids[i] >= 0:
			pose *= source.shoe_pose(instance_ids[i])
		elif plate_modes[i] != PlatePose.ORIGINAL:
			var plate := source as ImpactPlate
			if not plate.struck or (plate_modes[i] == PlatePose.OPEN) != plate.exposed:
				pose.basis = Basis.IDENTITY.scaled(Vector3.ONE * 0.00001)
		elif not source.is_visible_in_tree():
			pose.basis = Basis.IDENTITY.scaled(Vector3.ONE * 0.00001)
		_write_transform(transforms, pose)
	_write_transform(camera_data, camera.global_transform)
	camera_data.store_float(camera.fov)
	for tank in tanks:
		var at := tank.burner.global_position
		for value: float in [at.x, at.y, at.z, tank.burn_age]:
			camera_data.store_float(value)
	if outcome_logged:
		transforms.close()
		camera_data.close()
		var manifest := {"palette": palette, "objects": part_names, "vegetation": vegetation,
			"fps": FPS, "frames": sample_count, "shots": shots}
		FileAccess.open(destination.path_join("scene.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest))


func _write_transform(out: FileAccess, pose: Transform3D) -> void:
	for v: Vector3 in [pose.basis.x, pose.basis.y, pose.basis.z, pose.origin]:
		out.store_float(v.x)
		out.store_float(v.y)
		out.store_float(v.z)
