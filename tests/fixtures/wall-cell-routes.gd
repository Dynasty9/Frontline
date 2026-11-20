extends Node
## A man standing in a wall's nav cell - beside the wall, not in it, as at a
## window or pressed into a corner by a blast - sets off on his own side of it.
## (Routes used to start from the nearest free cell by grid order alone, which
## here is through the wall: his first step was blocked, he asked for the same
## route again, and stood there for the rest of the battle.)

func _ready() -> void:
	MapDims.N = 64
	MapDims.HALF = 32.0
	MapDims.SIZE = 64.0
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	var w := World.new()
	w.srv = true
	w.settings = {"seed": 3}
	w.terrain = TerrainMap.new(w)
	w.water = WaterMap.new(w)
	w.nav = Nav.new()
	w.nav.terrain = w.terrain
	# a wall 10 m long and half a metre thick, from x -5 to 5 along z 0.25..0.75:
	# its cells (z 0..1) are solid, though the wall fills only the middle of them
	var wall := Structure.new()
	wall.world = w
	wall.eid = 10
	wall.skind = "tall_wall"
	wall.size = Vector3(10, 2.6, 0.5)
	wall.position = Vector3(0, 0, 0.5)
	wall._define_parts()
	w.entities[wall.eid] = wall
	w.nav.add_structure(wall)
	w.nav.finalize()
	var spot := Vector3(0.3, 0, 0.88)
	assert(w.nav.kind_at(spot) == Nav.SOLID and w.nav._foot_clear(spot), "He stands in the wall's cell, clear of the wall")
	var goal := Vector3(0.3, 0, 8.0)
	var route := w.nav.find_path(spot, goal)
	assert(not route.is_empty(), "There's a way")
	assert(w.nav.can_step(spot, route[0]), "and its first step is one he can take (to %s)" % route[0])
	assert(route[0].z > 0.75, "on his own side of the wall")

	var man := Soldier.new()
	man.world = w
	man.eid = 11
	man.hp = 100.0
	man.position = spot
	w.add_child(man)
	man.go_to(goal, "slot", 1)
	for i in 300:
		w.nav.process_paths()
		man._move_tick(1.0 / 30.0, 3.0)
	assert(Defs.flat(man.position - goal).length() < 1.0, "He walks off to where he was sent (got to %s)" % man.position)
	wall.free()
	w.free()
	print("WALL_CELL_ROUTES passed")
	get_tree().quit()
