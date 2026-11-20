extends "res://scripts/main.gd"

var tank
var near_wall
var far_wall
var roof
var slab
var rail
var start_time := 0.0


func _process(dt: float) -> void:
	super._process(dt)
	if not world or not world.rules or world.time < 0.05:
		return
	if not tank:
		_setup_drive()
		start_time = world.time
	if world.time - start_time < 6.5:
		return
	set_process(false)
	assert(near_wall.gone and far_wall.gone and roof.gone and not slab.gone, "the hull breaches both walls and leaves the floor")
	assert(not rail.gone and tank.position.z < 34.0 and tank.position.z >= 28.6, "the whole hull stops at the bridge parapet")
	print("TRACKED_CONTACT passed")
	get_tree().quit()


func _setup_drive() -> void:
	tank = world.spawn("vehicle", {"vkind": "tank", "pos": Vector3(-310, 0, 47), "team": 0, "owner": 1})
	# Lay the route first. Even an order issued before the structures existed
	# must respect geometry encountered on the way.
	tank.path = PackedVector3Array([Vector3(-310, 0, 21)])
	tank.scan_t = 60.0
	near_wall = _structure("house_wall", 40.0, Vector3(7, 0, 0.4))
	far_wall = _structure("house_wall", 35.0, Vector3(7, 0, 0.4))
	roof = _structure("roof", 37.5, Vector3(7, 3, 5))
	slab = _structure("floor", 37.5, Vector3(7, 0.06, 5))
	rail = world.spawn("structure", {"skind": "bridge", "pos": Vector3(-310, 0, 20), "yaw": PI * 0.5, "size": Vector3(12, 0.5, 18)})


func _structure(kind: String, z: float, size: Vector3):
	return world.spawn("structure", {"skind": kind, "pos": Vector3(-310, 0, z), "size": size})
