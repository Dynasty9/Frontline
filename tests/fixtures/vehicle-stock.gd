extends Node
## Parked cars and hulks are copied from a stock of finished models, by look,
## and the first of a look is built a piece at a time (VehicleModels.Build).
## None of that may change a model: a look must say everything a seed changes,
## a copy must be the model it copies, and a model built in pieces (its distant
## mesh worked out on a worker) must be the model built at once.

const CARS := ["hatchback", "suv", "offroad", "mb4wd", "hatchback_sport"]


func _ready() -> void:
	TestRun.watch()
	# 1. Every seed with the same look builds the same model.
	var looks := 0
	for kind: String in CARS:
		for is_burnt: bool in [false, true]:
			var seen := {}
			for seed in range(1, 9):
				var look := VehicleModels.look(kind, -1, seed, is_burnt)
				if look == "":
					return fail("%s has no look" % kind)
				var k := VehicleModels.build(kind, -1, seed, is_burnt)
				var sig := signature(k.root)
				k.root.free()
				if seen.has(look) and seen[look] != sig:
					return fail("%s seeds with the look %s build different models" % [kind, look])
				seen[look] = sig
			if not is_burnt and seen.size() < 2:
				return fail("%s's look never changes with its seed" % kind)
			looks += seen.size()
	for kind: String in ["tank", "old_tank"]:
		var first := ""
		for seed in [3, 41, 977]:
			var k := VehicleModels.build(kind, -1, seed, true)
			var sig := signature(k.root)
			k.root.free()
			if first != "" and sig != first:
				return fail("burnt-out %s hulks differ by seed" % kind)
			first = sig
	if VehicleModels.look("tank", 0, 3, false) != "" or VehicleModels.look("tank", -1, 3, false) != "":
		return fail("a painted tank has a look: its seed and team mark it")

	# 2. A copy is the model it copies, its moving parts its own.
	for spec: Array in [["mb4wd", 5, false], ["tank", 7, true], ["old_tank", 7, true]]:
		var k := VehicleModels.build(spec[0], -1, spec[1], spec[2])
		var c := k.copy()
		if signature(c.root) != signature(k.root):
			return fail("a copy of %s isn't the same model" % spec[0])
		if k.turret and (c.turret == null or not c.root.is_ancestor_of(c.turret) or signature(c.turret) != signature(k.turret) or c.turret == k.turret):
			return fail("a copy of %s turns the original's turret" % spec[0])
		if c.engine_deck != k.engine_deck:
			return fail("a copy of %s lost its engine deck" % spec[0])
		k.root.free()
		c.root.free()
	VehicleModels.stock("test/look", VehicleModels.build("suv", -1, 2))
	var s1 := VehicleModels.stocked("test/look")
	var s2 := VehicleModels.stocked("test/look")
	if s1 == null or s1.root == s2.root or signature(s1.root) != signature(s2.root):
		return fail("the stock doesn't hand out copies")
	s1.root.free()
	s2.root.free()

	# 3. Built a piece at a time, a frame apart, it's the model built at once.
	var worst := 0
	var pieces := 0
	for spec: Array in [["hatchback", 11, false], ["mb4wd", 12, false], ["tank", 13, true]]:
		Mats._baked.clear()  # (each distant mesh made afresh: on the worker, then at once)
		var b := VehicleModels.start(spec[0], -1, spec[1], spec[2])
		var frames := 0
		while true:
			var t := Time.get_ticks_usec()
			var finished := b.step(2000)
			worst = maxi(worst, Time.get_ticks_usec() - t)
			pieces += 1
			if finished:
				break
			frames += 1
			if frames > 20000:
				return fail("a piecewise %s never finishes" % spec[0])
			await get_tree().process_frame
		Mats._baked.clear()
		var whole := VehicleModels.build(spec[0], -1, spec[1], spec[2])
		if signature(b.k.root) != signature(whole.root):
			return fail("%s built in pieces isn't the model built at once" % spec[0])
		b.k.root.free()
		whole.root.free()
	print("VEHICLE_STOCK passed: %d looks, copies, %d pieces (slowest %.1f ms)" % [looks, pieces, worst / 1000.0])
	get_tree().quit()


## Everything about a model that draws: its nodes in order, where they are,
## their meshes' data, materials, shadows, distances and instance values.
func signature(n: Node) -> String:
	var out := PackedStringArray()
	_sign(n, out)
	return "\n".join(out)


func _sign(n: Node, out: PackedStringArray) -> void:
	var line := n.get_class()
	if n is Node3D:
		line += " %s %s" % [var_to_str((n as Node3D).transform), (n as Node3D).visible]
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		line += " shadow=%d range=%s-%s over=%s overlay=%s" % [gi.cast_shadow, gi.visibility_range_begin, gi.visibility_range_end, _mat(gi.material_override), _mat(gi.material_overlay)]
		for p: Dictionary in gi.get_property_list():
			if String(p.name).begins_with("instance_shader_parameters/"):
				line += " %s=%s" % [p.name, var_to_str(gi.get(p.name))]
		line += " meta=%s" % var_to_str(gi.get_meta(&"inst_vals", {}))
		line += " proxy=%s" % gi.has_meta(&"shadow_proxy")
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh := (n as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			line += " [%d %s %s]" % [si, hash(var_to_bytes(mesh.surface_get_arrays(si))), _mat(mesh.surface_get_material(si))]
			var lods = RenderingServer.mesh_get_surface(mesh.get_rid(), si).get("lods", [])
			line += " lods=%d" % hash(var_to_bytes(lods))
	out.append(line)
	for c in n.get_children():
		_sign(c, out)


func _mat(m: Material) -> String:
	return "-" if m == null else str(m.get_instance_id())


func fail(message: String) -> void:
	push_error(message)
	print("VEHICLE_STOCK failed: ", message)
	get_tree().quit(1)
