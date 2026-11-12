extends "res://scripts/main.gd"
## Select the Mohawk on the pad, then click the Nyx through the normal player input.

var lift: Node3D
var cargo: Node3D
var ordered := false


func _ready() -> void:
	super._ready()
	args.erase("nohud")


func _process(dt: float) -> void:
	super._process(dt)
	if ordered or not is_instance_valid(world) or world.time < 1.4 or not world.input or not world.cam:
		return
	if not is_instance_valid(lift) or not is_instance_valid(cargo):
		for vehicle in world.vehicles:
			if vehicle.vkind == "mohawk":
				lift = vehicle
			elif vehicle.vkind == "nyx_at":
				cargo = vehicle
	if not is_instance_valid(lift) or not is_instance_valid(cargo):
		return
	if not lift.eid in world.input.sel_vehicles:
		world.cam.focus(lift.position.lerp(cargo.position, 0.48))
		world.input._click_select(world.cam.cam.unproject_position(lift.position + Vector3.UP), false, false)
	elif world.time >= 2.95:
		var screen: Vector2 = world.cam.cam.unproject_position(cargo.position + Vector3.UP * 0.7)
		if world.input.pick(screen) == cargo:
			world.input._order(screen, false)
			ordered = lift.sling_target == cargo
