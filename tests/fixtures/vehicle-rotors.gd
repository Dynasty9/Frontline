extends Node

func _ready() -> void:
	TestRun.watch()
	for kind in ["heli", "gunship", "ghosthawk", "ghosthawk_stub", "huron", "mohawk", "kajman", "taru", "taru_lift", "hummingbird", "pawnee", "m900", "hellcat", "blackfoot", "orca", "orca_armed", "falcon"]:
		for wreck in [false, true]:
			var k := VehicleModels.build(kind, 0, 3, wreck)
			assert(k.rotor != null and k.blades != null, kind + " must retain the main rotor and blade switch")
			assert(k.blades.get_parent() == k.rotor)
			assert(k.blur == null if wreck else k.blur != null)
			if k.blur:
				assert(k.blur.get_parent() == k.rotor and not k.blur.visible)
				k.blades.hide()
				assert(k.rotor.visible, "Hiding blades must not hide the articulated hub")
			for extra: Node3D in k.rotors:
				assert(extra.get_node_or_null("Blades") != null)
				assert(extra.get_node_or_null("Blur") == null if wreck else extra.get_node_or_null("Blur") != null)
			if kind in ["huron", "kajman", "taru", "taru_lift"]:
				assert(k.rotors.size() == 1, kind + " must retain its second rotor")
			k.root.free()
	# Cached airfoils must have finite normals, including the thin trailing edge.
	var profiles := 0
	for key: String in VehicleModels._cache:
		if not key.begins_with("rotor_airfoil_"):
			continue
		profiles += 1
		var mesh: ArrayMesh = VehicleModels._cache[key]
		var arrays := Mats._arrays(mesh, 0)
		for vector: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
			assert(vector.is_finite() and vector.length() > 0.9)
	assert(profiles > 10)
	var material := Mats.get_mat(VehicleMaterials.key("rotor", "aircraft"))
	assert(material.get_shader_parameter("metal") == 0.0)
	assert(material.get_shader_parameter("rough") >= 0.75)
	print("VEHICLE_ROTORS passed")
	TestRun.quit(get_tree())
