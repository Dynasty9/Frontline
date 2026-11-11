class_name VehicleDoors
extends RefCounted
## Closed access leaves share edge treatment and hardware. The caller supplies
## its surface and anchors; opening animation remains owned by the vehicle.

const STYLES := {
	"light": {"sheet": 0.012, "pin": 0.010, "grip": 0.009},
	"utility": {"sheet": 0.020, "pin": 0.014, "grip": 0.012},
	"armored": {"sheet": 0.035, "pin": 0.019, "grip": 0.014},
}

static func closed(k: VehicleModels, parent: Node3D, surface: VehicleSurface, outline: PackedVector2Array, hinges: Array[Vector2], handle: Vector2, mat: String, col = null, style := "utility", divisions := 0) -> void:
	assert(STYLES.has(style))
	var spec: Dictionary = STYLES[style]
	var thickness: float = spec.sheet
	VehicleBody.fitted(k, parent, surface, outline, mat, col, thickness, divisions, style == "armored")
	for uv in hinges:
		hinge(k, parent, surface.point(uv, thickness), surface.normal(uv), _up(surface, uv), spec.pin, mat, col)
	pull(k, parent, surface.point(handle, thickness), surface.normal(handle), _up(surface, handle).cross(surface.normal(handle)), 0.14, spec.grip)

static func _up(surface: VehicleSurface, uv: Vector2) -> Vector3:
	return (surface.point(uv + Vector2(0, 0.001)) - surface.point(uv - Vector2(0, 0.001))).normalized()

## Independent fittings also serve storage lids, tailgates and cabin ramps.
static func hinge(k: VehicleModels, parent: Node3D, at: Vector3, normal: Vector3, axis: Vector3, radius := 0.014, mat := "paint", col = null) -> void:
	var tangent := axis.cross(normal).normalized()
	var pin := at + normal * radius
	VehicleFrames.tube(k, parent, pin - axis * radius * 2.8, pin + axis * radius * 2.8, radius * 0.52, "steel", null, 8, false)
	for i in 3:
		var middle := pin + axis * (i - 1) * radius * 1.7
		VehicleFrames.tube(k, parent, middle - axis * radius * 0.72, middle + axis * radius * 0.72, radius, mat, col, 8, false)
		var foot := middle + tangent * radius * (2.2 if i == 1 else -2.2) - normal * radius
		VehicleFrames.beam(k, parent, middle - normal * radius * 0.6, foot, radius * 1.3, radius * 0.65, mat, col)
		VehicleBody.fastener(k, parent, foot, normal, radius * 0.38)

static func pull(k: VehicleModels, parent: Node3D, at: Vector3, normal: Vector3, along: Vector3, length := 0.14, radius := 0.012, mat := "metal_dark", col = null) -> void:
	var a := at - along.normalized() * length * 0.5
	var b := at + along.normalized() * length * 0.5
	var rise := normal.normalized() * radius * 2.7
	for p in [a, b]:
		VehicleFrames.tube(k, parent, p, p + rise, radius, mat, col, 6, false)
		VehicleBody.fastener(k, parent, p, normal, radius * 0.8)
	VehicleFrames.tube(k, parent, a + rise, b + rise, radius, mat, col, 8, false)

static func rectangle(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector2, rotation: Vector3, mat: String, col = null, style := "utility") -> void:
	var basis := Basis.from_euler(rotation)
	var surface := VehicleSurface.plane(center - basis.x * size.x * 0.5 - basis.y * size.y * 0.5, basis.x * size.x, basis.y * size.y)
	var hinge_x := 0.92 if basis.x.z < 0.0 else 0.08
	closed(k, parent, surface, PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), [Vector2(hinge_x, 0.2), Vector2(hinge_x, 0.8)], Vector2(1.0 - hinge_x, 0.72), mat, col, style)
