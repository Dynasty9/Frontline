extends "res://scripts/main.gd"
## Place one parked vehicle in an ordinary offline scenario, using the
## actual terrain, lighting and game camera. Standard screenshot flags apply.
var _showcase_spawned := false

func _process(dt: float) -> void:
	super._process(dt)
	if _showcase_spawned or world == null or not world.is_node_ready():
		return
	_showcase_spawned = true
	var coords := String(args.get("showcase-pos", "-20,-10")).split(",")
	var x := float(coords[0])
	var z := float(coords[1])
	var vehicle: Node3D = world.spawn("vehicle", {"vkind": String(args.get("showcase-vehicle", "truck")), "team": 0, "owner": -1, "pos": Vector3(x, world.ground_y(Vector3(x, 0, z)), z), "yaw": 0.0})
	# A supply truck without a route immediately returns home and despawns.
	vehicle.route = PackedVector3Array([vehicle.position + Vector3(0, 0, -100)])
	# Keep the review vehicle parked without modifying the shared definition.
	vehicle.vdef = vehicle.vdef.duplicate()
	vehicle.vdef["speed"] = 0.0
	world.cam.focus(vehicle.position)
	print("VEHICLE_WORLD_SHOWCASE spawned at ", vehicle.position)
