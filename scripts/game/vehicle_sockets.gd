class_name VehicleSockets
extends RefCounted
## Baked from model markers by tests/fixtures/vehicle-sockets.gd. Authority
## never constructs a rendered model to find a barrel. Tests keep this data in
## step with model geometry, including scaled and off-centre aircraft guns.
const DATA = preload("res://scripts/game/vehicle_socket_data.gd")

static func layout(kind: String) -> Dictionary:
	return DATA.LAYOUTS.get(kind, {})

static func point(kind: String, weapon: String, turret_yaw := 0.0) -> Vector3:
	var item: Dictionary = layout(kind).get(weapon, {})
	if item.is_empty():
		return Vector3.INF
	var p: Array = item.point
	var local := Vector3(float(p[0]), float(p[1]), float(p[2]))
	if item.has("pivot"):
		var v: Array = item.pivot
		var pivot := Vector3(float(v[0]), float(v[1]), float(v[2]))
		local = pivot + Basis(Vector3.UP, turret_yaw) * (local - pivot)
	return local
