extends "res://scripts/main.gd"
## Film the same move order a player can give on the minimap, with its selection
## rings, destination marker and squad card visible in the recording.

var ordered := false

func _process(dt: float) -> void:
	args.erase("nohud")
	super._process(dt)
	if ordered or not is_instance_valid(world) or world.time < 2.0 or not world.input:
		return
	if world.input.sel_squads.is_empty() or not world.input.can_command():
		return
	var pos: Vector3 = world.input.selection_centre() + Vector3(4.0, 0.0, -6.0)
	world.input.order_at(pos)
	ordered = true
