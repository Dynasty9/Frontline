class_name VehicleCargo
extends RefCounted
## Supports and restraints use declared load bounds; the load and any draped
## cover remain owned by the family and VehicleCloth.

static func pallet(k: VehicleModels, parent: Node3D, base: Vector3, size: Vector2, height := 0.1) -> void:
	for side: float in [-1.0, 0.0, 1.0]:
		for z: float in [-0.37, 0.0, 0.37]:
			k._box(parent, Vector3(size.x * 0.13, height * 0.50, size.y * 0.23), base + Vector3(side * size.x * 0.38, height * 0.40, z * size.y), "wood_dark")
		k._box(parent, Vector3(size.x * 0.13, height * 0.15, size.y), base + Vector3(side * size.x * 0.38, height * 0.075, 0), "wood")
	for i in 5:
		k._box(parent, Vector3(size.x, height * 0.35, size.y * 0.17), base + Vector3(0, height * 0.825, lerpf(-size.y * 0.4, size.y * 0.4, i / 4.0)), "wood")

static func restraints(k: VehicleModels, parent: Node3D, base: Vector3, size: Vector3, offsets: Array, width := 0.045, col := Color(0.28, 0.26, 0.2)) -> void:
	for z: float in offsets:
		k._box(parent, Vector3(size.x + 0.008, 0.007, width), base + Vector3(0, size.y + 0.004, z), "canvas_white", col, Vector3.ZERO, false)
		for side: float in [-1.0, 1.0]:
			var x := side * (size.x * 0.5 + 0.004)
			k._box(parent, Vector3(0.007, size.y, width), base + Vector3(x, size.y * 0.5, z), "canvas_white", col, Vector3.ZERO, false)
			var buckle := base + Vector3(x, minf(0.2, size.y * 0.3), z)
			for edge: float in [-1.0, 1.0]:
				k._box(parent, Vector3(0.022, width * 1.8, width * 0.16), buckle + Vector3(0, 0, edge * width * 0.6), "steel", Color(0.25, 0.26, 0.23))
				k._box(parent, Vector3(0.022, width * 0.16, width * 1.2), buckle + Vector3(0, edge * width * 0.82, 0), "steel", Color(0.25, 0.26, 0.23))
			VehicleFrames.tube(k, parent, buckle + Vector3(side * 0.018, 0, -width * 0.5), buckle + Vector3(side * 0.018, 0, width * 0.5), width * 0.13, "steel", null, 6, false)
			k._box(parent, Vector3(0.005, minf(size.y * 0.25, width * 3), width * 0.85), buckle + Vector3(side * 0.021, -width * 1.7, 0), "canvas_white", col, Vector3(0, 0, side * 0.12), false)
			VehicleBody.fastener(k, parent, base + Vector3(x, 0.03, z), Vector3(side, 0, 0), minf(0.012, width * 0.25))


## Ribbed cargo leaf. Layout, opening angle and stake posts remain authored;
## folded edges and stiffeners are constructed once for all flat-sided beds.
static func sideboard(k: VehicleModels, parent: Node3D, size: Vector3, center: Vector3, mat: String, col = null, rotation := Vector3.ZERO, axis := 2) -> void:
	VehicleDoors.leaf(k, parent, size, center, mat, col, rotation, axis)
	var mount := k._pivot(parent, center)
	mount.rotation = rotation
	var length := size.z if axis == 0 else size.x
	var count := maxi(2, ceili(length / 0.65))
	for i in range(1, count):
		var at := Vector3(0, 0, lerpf(-length * 0.5, length * 0.5, float(i) / count)) if axis == 0 else Vector3(lerpf(-length * 0.5, length * 0.5, float(i) / count), 0, 0)
		var rib := Vector3(size.x + 0.012, size.y * 0.88, 0.025) if axis == 0 else Vector3(0.025, size.y * 0.88, size.z + 0.012)
		k._add(mount, BevelMesh.make(rib, 0.004), mat, col, at)
	k._fold(mount)
