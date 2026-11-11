extends "res://scripts/main.gd"
## Film the same move order a player can give on the minimap, with its selection
## rings, destination marker and squad card visible in the recording.

var ordered := false

func _process(dt: float) -> void:
	if not args.has("roadside"):
		args.erase("nohud")
	super._process(dt)
	if ordered or not is_instance_valid(world) or world.time < 2.0 or not world.input:
		return
	if world.input.sel_squads.is_empty() or not world.input.can_command():
		return
	var start: Vector3 = world.input.selection_centre()
	world.input.order_at(start + Vector3(4.0, 0.0, -6.0))
	ordered = true
	if args.has("roadside"):
		# Film the same crossing at shoulder height from beside the road.
		args.erase("select-first")
		world.input.clear_selection()
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.global_position = start + Vector3(7.6, 1.65, -4.3)
		camera.fov = 48.0
		camera.look_at(start + Vector3(1.7, 1.1, -2.2))
		camera.make_current()
