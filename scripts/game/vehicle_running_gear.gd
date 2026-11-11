class_name VehicleRunningGear
extends RefCounted
## Underbody assemblies never register wheels. The family retains wheel pivots,
## track envelopes and vehicle-specific suspension layouts.

static func frame(k: VehicleModels, parent: Node3D, center: Vector3, half_width: float, length: float, rail: Vector2, crossmembers: Array) -> void:
	for side: float in [-1.0, 1.0]:
		var at := center + Vector3(side * half_width, 0, 0)
		k._box(parent, Vector3(rail.x * 0.22, rail.y, length), at + Vector3(side * rail.x * 0.39, 0, 0), "metal_dark")
		for edge: float in [-1.0, 1.0]:
			k._box(parent, Vector3(rail.x, rail.y * 0.16, length), at + Vector3(0, edge * rail.y * 0.42, 0), "metal_dark")
	for z: float in crossmembers:
		k._box(parent, Vector3(half_width * 2, rail.y * 0.55, rail.x), Vector3(center.x, center.y, z), "metal_dark")
		for side: float in [-1.0, 1.0]:
			k._box(parent, Vector3(rail.x * 1.6, rail.y * 0.16, rail.x * 1.8), Vector3(center.x + side * (half_width - rail.x * 0.3), center.y, z), "metal_dark")
			VehicleBody.fastener(k, parent, Vector3(center.x + side * half_width, center.y + rail.y * 0.52, z), Vector3.UP, 0.012)

static func axle(k: VehicleModels, parent: Node3D, center: Vector3, width: float, radius: float, spring_span := 0.0, spring_length := 0.85) -> void:
	VehicleFrames.tube(k, parent, center - Vector3.RIGHT * width * 0.5, center + Vector3.RIGHT * width * 0.5, radius, "metal_dark", null, 10)
	k._add(parent, Res.sphere(radius * 2.3, 12), "metal_dark", null, center, Vector3.ZERO, Vector3(1, 0.9, 0.85))
	k._cyl(parent, radius * 1.7, radius * 1.7, radius * 0.3, center + Vector3(0, 0, -radius * 1.8), Vector3(PI / 2, 0, 0), "steel", Color(0.18, 0.19, 0.18), 10, false)
	for i in 8:
		var angle := TAU * i / 8.0
		VehicleBody.fastener(k, parent, center + Vector3(cos(angle) * radius * 1.35, sin(angle) * radius * 1.35, -radius * 1.97), Vector3.FORWARD, radius * 0.13)
	k._cyl(parent, radius * 0.8, radius * 0.7, radius * 0.8, center + Vector3(0, 0, radius * 2.0), Vector3(PI / 2, 0, 0), "metal_dark", null, 10)
	k._cyl(parent, radius, radius, radius * 0.2, center + Vector3(0, 0, radius * 2.4), Vector3(PI / 2, 0, 0), "steel", null, 10, false)
	if spring_span > 0:
		for side: float in [-1.0, 1.0]:
			for leaf in 3:
				var length := spring_length * (1.0 - leaf * 0.15)
				var c := center + Vector3(side * spring_span, radius + 0.025 + leaf * 0.012, 0)
				VehicleFrames.beam(k, parent, c + Vector3(0, 0.035, -length * 0.5), c, 0.07, 0.01, "metal_dark")
				VehicleFrames.beam(k, parent, c, c + Vector3(0, 0.035, length * 0.5), 0.07, 0.01, "metal_dark")
			for z in [-spring_length * 0.4, spring_length * 0.4]:
				k._box(parent, Vector3(0.1, 0.045, 0.035), center + Vector3(side * spring_span, radius + 0.07, z), "steel", Color(0.20, 0.21, 0.19))
