extends "res://scripts/main.gd"
## Frame the participants already in the mission from a camera beside them.

@export_enum("Boats", "Flyover", "Infantry fighting vehicles", "Underwing") var view := 0
## Keep the ground camera with the rifle squads as the vehicles leave the foreground.
var opening_centre := Vector3.INF
@onready var lens: Camera3D = $Camera3D

func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world):
		return
	if view == 1 or view == 3:
		for plane in world.projectiles:
			if plane.ptype == "jet":
				var heading: Vector3 = plane.vel.slide(Vector3.UP).normalized()
				var right := heading.cross(Vector3.UP)
				if view == 3:
					# Leave the mountains in the gap below the wing so each release reads in silhouette.
					lens.position = plane.position + right * 6.6 - heading * 10.2 + Vector3.DOWN * 4.5
					lens.look_at(plane.position + heading + Vector3.DOWN * 2.8)
				else:
					# Keep the same side of the aircraft as the harbour passes underneath.
					var to_harbour: Vector3 = plane.target - plane.position
					var lead := maxf(32.0, to_harbour.dot(heading))
					var ahead := (heading * lead + Vector3.UP * to_harbour.y).normalized()
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
		if not opening_centre.is_finite():
			opening_centre = centre
		lens.position = opening_centre + Vector3(-4.6, 3.4, 17.8)
		lens.look_at(opening_centre.lerp(centre, 0.32) + Vector3(0, 1.1, -4.3))
	else:
		return
	lens.make_current()
