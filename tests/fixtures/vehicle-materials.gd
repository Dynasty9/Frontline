extends Node
## Audit the actual baked roster, including both palettes, wrecks and parked cars.
var surfaces := 0
var maps := {}

func _ready() -> void:
	TestRun.watch()
	var keys: Array = Defs.VEHICLES.keys()
	for list in [VehicleModels.family_keys(), VmCore.KEYS, VmGunship.KEYS, VmAttack.KEYS, VmFighter.KEYS]:
		for key: String in list:
			if key not in keys:
				keys.append(key)
	for team in 2:
		for kind: String in keys:
			var model := VehicleModels.build(kind, team, 3)
			_audit(model.root, false)
			model.root.free()
	for kind in ["tank", "heli", "patrol_ship"]:
		var wreck := VehicleModels.build(kind, 0, 3, true)
		_audit(wreck.root, true)
		wreck.root.free()
	for variant in 5:
		var car := VehicleModels.build_car(variant, Color(0.36, 0.16, 0.12))
		_audit(car.root, false)
		car.root.free()
	# A non-finite hood vertex destroys texture projection and its normal.
	var hood: ArrayMesh = VehicleModels._cache["boat_pwc_hood"]
	var hood_arrays := Mats._arrays(hood, 0)
	for attribute in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL]:
		for vector: Vector3 in hood_arrays[attribute]:
			assert(vector.is_finite(), "Water scooter hood must have finite vertices and normals")
	# The environment still owns its original presets, and opaque glass must
	# reflect as a dielectric rather than turning into dark chrome.
	assert(Mats.get_mat("paint").get_shader_parameter("vehicle_surface") != true)
	var glass := Mats.get_mat(VehicleMaterials.key("glass", "armor"))
	assert(glass.get_shader_parameter("metal") == 0.0)
	assert(glass.get_shader_parameter("bump") == 0.0)
	assert(maps.size() == 8, "All eight shared maps should be used by the roster")
	# Transparent cab glazing must not enter the opaque chassis bake. Each
	# window has a matching distant fallback, and wrecks have no intact panes.
	for family in [VmNato.KEYS, VmIndep.KEYS, VmCsat.KEYS, VmCiv.KEYS]:
		for kind: String in family:
			if not (kind.begins_with("hemtt") or kind.begins_with("zamak") or kind.begins_with("tempest") or kind.begins_with("offroad") or kind.begins_with("hatchback") or kind == "suv"):
				continue
			for wreck in [false, true]:
				var model := VehicleModels.build(kind, 0, 3, wreck)
				var near_panes := 0
				var far_panes := 0
				for child in model.root.get_children():
					if child is MeshInstance3D and child.material_override in [VehicleCab.glass_near, VehicleCab.glass_far]:
						var mat := child.material_override as StandardMaterial3D
						if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
							assert(child.visibility_range_end == 100.0)
							near_panes += 1
						else:
							assert(child.visibility_range_begin == 100.0)
							far_panes += 1
				assert(near_panes == far_panes, kind + " has mismatched glass LODs")
				assert(near_panes == 0 if wreck else near_panes >= 4, kind + " has missing glazing or intact wreck windows")
				assert(model.wheels.size() >= 4)
				model.root.free()
	print("VEHICLE_MATERIALS passed models=%d surfaces=%d maps=%d" % [keys.size() * 2 + 8, surfaces, maps.size()])
	TestRun.quit(get_tree())

func _audit(node: Node, wreck: bool) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var material := mi.get_active_material(i) as ShaderMaterial
				# Rotor blur, lights and the one-surface distance LOD have their
				# own shaders; all physical surfaces must use the shared library.
				if material == null or material.shader != Mats.shader():
					continue
				surfaces += 1
				assert(material.get_shader_parameter("vehicle_surface") == true)
				assert(material.get_shader_parameter("local_space") == true)
				var texture: Texture2D = material.get_shader_parameter("surface_map")
				assert(texture != null and texture.get_width() == 512)
				if not maps.has(texture.resource_path):
					assert(texture.get_image().has_mipmaps(), "Detail maps need mipmaps at RTS distances")
				maps[texture.resource_path] = true
				if wreck:
					assert(material.get_shader_parameter("rough") > 0.9)
	for child in node.get_children():
		_audit(child, wreck)
