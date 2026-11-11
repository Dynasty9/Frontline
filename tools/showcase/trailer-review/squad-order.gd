extends "res://scripts/main.gd"
## Show a player order beside the Sky Hook landing pad, then follow the same
## squad on the ground as the mission helicopter lifts behind them.

var ordered := false
var framed := false
var roadside: Camera3D
var leader: Node3D

func _process(dt: float) -> void:
	if not args.has("roadside"):
		args.erase("nohud")
	super._process(dt)
	if not framed and is_instance_valid(world) and world.input and world.cam and not world.input.sel_squads.is_empty():
		var centre: Vector3 = world.input.selection_centre()
		world.cam.focus(centre + Vector3(2, 0, -3))
		framed = true
	if ordered:
		if is_instance_valid(roadside) and is_instance_valid(leader):
			_follow_crossing()
		return
	if not is_instance_valid(world) or world.time < 2.0 or not world.input:
		return
	if world.input.sel_squads.is_empty() or not world.input.can_command():
		return
	var start: Vector3 = world.input.selection_centre()
	world.input.order_at(start + Vector3(1.4, 0.0, -5.6))
	ordered = true
	if args.has("roadside"):
		var squad: Variant = world.squads.get(world.input.sel_squads[0])
		if not is_instance_valid(squad):
			return
		leader = squad.get_leader()
		if not is_instance_valid(leader):
			return
		args.erase("select-first")
		world.input.clear_selection()
		roadside = Camera3D.new()
		world.add_child(roadside)
		roadside.fov = 48.0
		_follow_crossing()
		roadside.make_current()


func _follow_crossing() -> void:
	# Track the leader past the hedge and tilt up as the Mohawk clears the pad.
	var lift := smoothstep(2.73, 4.13, world.time)
	roadside.global_position = leader.global_position + Vector3(1.6, 1.38, -3.15)
	roadside.look_at(leader.global_position + Vector3(-0.22, lerpf(1.36, 1.90, lift), 0.45))
