class_name VehicleCloth
extends RefCounted

## A cloth shell with a sloping crown and gathered side folds. The displacement
## is deterministic and stays in model space; straps remain separate geometry.
static func load_cover(k: VehicleModels, base: Vector3, size: Vector3, col := Color(0.30, 0.32, 0.23), pallet := true) -> void:
	if pallet:
		k._box(k.root, Vector3(size.x - 0.06, 0.12, size.z - 0.06), base + Vector3(0, 0.06, 0), "wood")
	var rings: Array[PackedVector3Array] = []
	for i in 25:
		var z := (float(i) / 24.0 - 0.5) * (size.z - 0.08)
		var ripple := sin(float(i) * 0.45) * 0.014 + sin(float(i) * 0.9) * 0.004
		var w := size.x * 0.5 - 0.05
		var h := size.y
		rings.append(PackedVector3Array([Vector3(-w, 0.14, z), Vector3(-w + ripple, h * 0.72, z), Vector3(-w * 0.75, h - 0.035 + ripple, z), Vector3(0, h + ripple * 0.35, z), Vector3(w * 0.75, h - 0.035 - ripple, z), Vector3(w - ripple, h * 0.72, z), Vector3(w, 0.14, z)]))
	var shell := VehicleModels.solid(rings, "shared_tarp_%s" % str(size))
	var arrays := shell.surface_get_arrays(0)
	var smooth := SurfaceTool.new()
	smooth.begin(Mesh.PRIMITIVE_TRIANGLES)
	smooth.set_smooth_group(0)
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		smooth.add_vertex(vertex)
	smooth.index()
	smooth.generate_normals()
	k._add(k.root, smooth.commit(), "canvas_white", col, base)
	for index in [6, 18]:
		var cross_section: PackedVector3Array = rings[index]
		for j in 6:
			VehicleFrames.tube(k, k.root, base + cross_section[j] + Vector3(0, 0.012, 0), base + cross_section[j + 1] + Vector3(0, 0.012, 0), 0.012, "webbing", Color(0.18, 0.19, 0.13), 6, false)


