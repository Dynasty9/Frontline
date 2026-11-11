class_name VehicleMarkings
extends RefCounted
## Surface-projected paint, lettering and wear patches. Family adapters own
## projection and symbols; this owns triangulation and consistent facing.

static func polygons(k: VehicleModels, parent: Node3D, outlines: Array, project: Callable, outward: Vector3, col, material := "paint", omit_wreck := true, divisions := 1) -> void:
	if omit_wreck and k.burnt:
		return
	var surface := VehicleSurface.new(project, outward)
	for points in outlines:
		var outline := PackedVector2Array(points)
		if outline.size() < 3 or Geometry2D.triangulate_polygon(outline).is_empty():
			continue
		k._add(parent, surface.patch(outline, 0.0, 0.0, divisions), material, col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, false)
