extends Node

func _ready() -> void:
	TestRun.watch()
	var outline := PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(1.7, 1), Vector2(0.2, 1)])
	for facing in [1.0, -1.0]:
		var surface := VehicleSurface.plane(Vector3.ZERO, Vector3(facing, 0, 0), Vector3.UP)
		var mesh := surface.patch(outline, 0.02, 0.02)
		check_mesh(mesh)
		assert(is_equal_approx(mesh.get_aabb().size.z, 0.02))
		var shell := surface.shell(Rect2(0, 0, 2, 2), [Rect2(0.4, 0.4, 1.2, 1.2)], 0.1)
		check_mesh(shell)
		var verts: PackedVector3Array = shell.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		# No front/back triangle covers the opening centre.
		for i in range(0, verts.size(), 3):
			var a := Vector2(verts[i].x * facing, verts[i].y)
			var b := Vector2(verts[i + 1].x * facing, verts[i + 1].y)
			var c := Vector2(verts[i + 2].x * facing, verts[i + 2].y)
			if absf((b - a).cross(c - a)) > 0.00001:
				assert(not Geometry2D.point_is_inside_triangle(Vector2(1, 1), a, b, c), "Shell must contain a genuine opening")
	var curved := VehicleSurface.new(func(q: Vector2) -> Vector3: return Vector3(q.x, q.y, 0.2 * q.x * q.x), Vector3.BACK)
	var bent := curved.patch(outline, 0, 0, 2)
	check_mesh(bent)
	for p: Vector3 in bent.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert(absf(p.z - 0.2 * p.x * p.x) < 0.00001)
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k._baking = true
	VehicleBody.fitted(k, k.root, curved, outline, "paint", Color.OLIVE, 0.02, 2)
	assert(k.root.get_child_count() == 0, "Opaque construction must enter the existing bake")
	assert(k.wheels.is_empty() and k.turret == null)
	k.root.free()
	for burnt in [false, true]:
		k = VehicleModels.new()
		k.root = Node3D.new()
		k._baking = true
		k.burnt = burnt
		VehicleGlazing.polygon(k, k.root, curved, outline, true)
		assert(k.root.get_child_count() == (0 if burnt else 2), "Clear glazing must preserve near/far and wreck contracts")
		k.root.free()
	# The same profile reuses a mesh; a changed dimension or cap policy cannot.
	var profile := [Vector2(0.4, -1), Vector2(0.4, 1)]
	var tube := VehicleProfiles.revolve(profile, 12)
	assert(tube == VehicleProfiles.revolve(profile, 12))
	var wider := VehicleProfiles.revolve([Vector2(0.8, -1), Vector2(0.8, 1)], 12)
	assert(wider != tube and wider.get_aabb().size.x > tube.get_aabb().size.x * 1.9)
	check_mesh(tube)
	# Fitted seals stay a single low-cost opaque mesh, including curved edges.
	k = VehicleModels.new()
	k.root = Node3D.new()
	k._baking = true
	VehicleBody.boundary(k, k.root, curved, outline, 0.01, 0.005, false, 2)
	assert(k.root.get_child_count() == 0)
	var parts: Array = k._parts[k.root]
	assert(parts.size() == 1)
	check_mesh(parts[0][0])
	assert(parts[0][0].surface_get_array_len(0) <= 400)
	k.root.free()
	print("VEHICLE_SURFACES passed")
	get_tree().quit()

func check_mesh(mesh: ArrayMesh) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert(vs.size() > 0 and vs.size() == ns.size())
	for i in range(0, vs.size(), 3):
		var cross := (vs[i + 1] - vs[i]).cross(vs[i + 2] - vs[i])
		assert(cross.length_squared() > 1e-15)
		assert(cross.dot(ns[i] + ns[i + 1] + ns[i + 2]) < 0, "Every triangle must face its outward normals")
	for p in vs:
		assert(p.is_finite())
