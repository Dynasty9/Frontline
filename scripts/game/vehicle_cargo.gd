class_name VehicleCargo
extends RefCounted
## Supports and restraints use declared load bounds; the load and any draped
## cover remain owned by the family and VehicleCloth.

static func pallet(k: VehicleModels, parent: Node3D, base: Vector3, size: Vector2, height := 0.1) -> void:
	for side: float in [-1.0, 0.0, 1.0]:
		k._box(parent, Vector3(size.x * 0.13, height * 0.65, size.y), base + Vector3(side * size.x * 0.38, height * 0.325, 0), "wood_dark")
	for i in 5:
		k._box(parent, Vector3(size.x, height * 0.35, size.y * 0.17), base + Vector3(0, height * 0.825, lerpf(-size.y * 0.4, size.y * 0.4, i / 4.0)), "wood")

static func restraints(k: VehicleModels, parent: Node3D, base: Vector3, size: Vector3, offsets: Array, width := 0.045, col := Color(0.28, 0.26, 0.2)) -> void:
	for z: float in offsets:
		k._box(parent, Vector3(size.x + 0.008, 0.007, width), base + Vector3(0, size.y + 0.004, z), "canvas_white", col, Vector3.ZERO, false)
		for side: float in [-1.0, 1.0]:
			var x := side * (size.x * 0.5 + 0.004)
			k._box(parent, Vector3(0.007, size.y, width), base + Vector3(x, size.y * 0.5, z), "canvas_white", col, Vector3.ZERO, false)
			var buckle := base + Vector3(x, minf(0.2, size.y * 0.3), z)
			k._box(parent, Vector3(0.022, width * 1.8, width * 1.35), buckle, "steel", Color(0.25, 0.26, 0.23))
			VehicleBody.fastener(k, parent, base + Vector3(x, 0.03, z), Vector3(side, 0, 0), minf(0.012, width * 0.25))
