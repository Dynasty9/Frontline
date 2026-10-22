extends Node

func _ready() -> void:
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	var world := World.new()
	world.has_view = false
	world.nav = Nav.new()
	world.rng.seed = 4
	var caught := Soldier.new()
	caught.world = world
	caught.eid = 1
	caught.hp = 100.0
	caught.position = Vector3(1, 0, 0)
	var safe := Soldier.new()
	safe.world = world
	safe.eid = 2
	safe.hp = 100.0
	safe.position = Vector3(20, 0, 0)
	for man in [caught, safe]:
		world.add_child(man)
		world._hadd(man)
	var fires := Fires.new(world)
	# Put him inside a burning patch rather than hoping combat leads him there.
	fires._patch_beat([Vector3.ZERO, 3.0, 10.0, 2])
	assert(caught.hp < 100.0 and safe.hp == 100.0)
	assert(world.stats.get("fire_burns", 0) == 1 and world.stats.get("fire_flee", 0) == 1)
	assert(caught.is_moving() and caught.move_mode == 2 and caught.goal.x > caught.position.x)
	assert(not safe.is_moving())
	world.free()
	print("FIRE_ESCAPE passed")
	get_tree().quit()
