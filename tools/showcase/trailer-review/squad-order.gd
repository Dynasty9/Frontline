extends "res://scripts/main.gd"
## Show a player order beside the Sky Hook landing pad, then follow the same
## squad on the ground as the mission helicopter lifts behind them.

var ordered := false
var framed := false
var roadside: Camera3D
var squad: Variant  # Main loads before the game's squad class.
var origin: Vector3

func _process(dt: float) -> void:
	if not args.has("roadside"):
		args.erase("nohud")
	super._process(dt)
	if not framed and is_instance_valid(world) and world.input and world.cam and not world.input.sel_squads.is_empty():
		var centre: Vector3 = world.input.selection_centre()
		world.cam.focus(centre + Vector3(2, 0, -3))
		framed = true
	if ordered:
		if is_instance_valid(roadside) and is_instance_valid(squad):
			_follow_crossing()
		return
	if not is_instance_valid(world) or world.time < 2.0 or not world.input:
		return
	if world.input.sel_squads.is_empty() or not world.input.can_command():
		return
	var start: Vector3 = world.input.selection_centre()
	world.input.order_at(start + Vector3(4.0, 0.0, -6.0))
	ordered = true
	if args.has("roadside"):
		origin = start
		squad = world.squads.get(world.input.sel_squads[0])
		if not is_instance_valid(squad):
			return
		args.erase("select-first")
		world.input.clear_selection()
		roadside = Camera3D.new()
		world.add_child(roadside)
		roadside.fov = 42.0
		_follow_crossing()
		roadside.make_current()


func _follow_crossing() -> void:
	# Back away more slowly than the squad advances so the lead riflemen fill the frame.
	var travel := Defs.flat(squad.centroid() - origin)
	roadside.global_position = origin + Vector3(3.5, 0, -8.0) + travel * 0.55
	roadside.global_position.y = world.ground_y(roadside.global_position) + 1.45
	roadside.look_at(origin + Vector3(1.65, 1.1, -2.2) + travel * 0.72)
