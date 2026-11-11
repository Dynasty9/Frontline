extends Node
## Reproducible build/geometry report. Capture before and after with the same
## engine, model order and machine; build times include cold shared caches.
func _ready() -> void:
	TestRun.watch()
	var output := "/tmp/vehicle-metrics.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vehicle-metrics-out="):
			output = arg.trim_prefix("--vehicle-metrics-out=")
	var keys: Array[String] = []
	for list in [Defs.VEHICLES.keys(), VehicleModels.family_keys(), VmCore.KEYS, VmGunship.KEYS, VmAttack.KEYS, VmFighter.KEYS]:
		for key: String in list:
			if key not in keys:
				keys.append(key)
	keys.sort()
	var result := {}
	for key in keys:
		var started := Time.get_ticks_usec()
		var model := VehicleModels.build(key, 0, 3)
		var row := {"build_usec": Time.get_ticks_usec() - started, "meshes": 0, "surfaces": 0, "vertices": 0, "nodes": 0, "wheels": model.wheels.size(), "rotors": model.rotors.size()}
		_count(model.root, row)
		result[key] = row
		model.root.free()
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t", true))
	print("VEHICLE_METRICS ", result.size())
	get_tree().quit()

func _count(node: Node, result: Dictionary) -> void:
	result.nodes += 1
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		if mesh:
			result.meshes += 1
			result.surfaces += mesh.get_surface_count()
			for i in mesh.get_surface_count():
				var arrays := Mats._arrays(mesh, i)
				if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
					result.vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for child in node.get_children():
		_count(child, result)
