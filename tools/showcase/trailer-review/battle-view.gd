extends "res://scripts/main.gd"
## Frame the participants already in the mission from a camera beside them.

@export_enum("Boats", "Flyover", "Infantry fighting vehicles") var view := 0
@onready var lens: Camera3D = $Camera3D

func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world):
		return
	if view == 1:
		for plane in world.projectiles:
			if plane.ptype == "jet":
				var ahead: Vector3 = plane.position.direction_to(plane.target)
				var right := ahead.cross(Vector3.UP).normalized()
				lens.position = plane.position - ahead * 24.0 + right * 9.5 + Vector3.UP * 3.0
				lens.look_at(plane.position + ahead * 18.0)
				lens.make_current()
				return
		return
	var lead: Node3D
	var others: Array[Vector3] = []
	for vehicle in world.vehicles:
		if view == 0:
			if vehicle.vkind == "patrol_ship":
				lead = vehicle
			elif vehicle.team == 1 and vehicle.is_boat():
				others.append(vehicle.position)
		elif vehicle.vkind == "ifv":
			others.append(vehicle.position)
	if others.is_empty():
		return
	var centre := Vector3.ZERO
	for point in others:
		centre += point
	centre /= others.size()
	if view == 0 and is_instance_valid(lead):
		var ahead := lead.position.direction_to(centre)
		var right := ahead.cross(Vector3.UP).normalized()
		lens.position = lead.position - ahead * 22.0 + right * 11.0 + Vector3.UP * 12.0
		lens.look_at(lead.position.lerp(centre, 0.42))
	elif view == 2:
		lens.position = centre + Vector3(-0.8, 4.6, 16.4)
		lens.look_at(centre + Vector3(0, 0.9, -5.6))
	else:
		return
	lens.make_current()
