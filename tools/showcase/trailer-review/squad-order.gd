extends "res://scripts/main.gd"
## Film the same move order a player can give on the minimap, with its selection
## rings, destination marker and squad card visible in the recording.

var ordered := false
var roadside: Camera3D
var squad: Variant  # Main loads before the game's squad class.
var origin: Vector3

func _process(dt: float) -> void:
	if not args.has("roadside"):
		args.erase("nohud")
	super._process(dt)
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
	roadside.global_position = origin + Vector3(2.8, 1.45, -7.3) + travel * 0.30
	roadside.look_at(origin + Vector3(0.7, 1.13, -1.8) + travel * 0.60)
