extends Node

func _ready() -> void:
	var world := World.new()
	var input := PlayerInput.new()
	input.world = world
	for i in 3:
		var s := Soldier.new()
		s.eid = i + 1
		s.sid = 7 if i < 2 else 8
		s.team = 0
		world.soldiers.append(s)
		world.entities[s.eid] = s
	input.sel_squads = [7, 0, 99]
	input._update_selection()
	assert(input.sel_squads == [7])
	assert(world.soldiers[0].selected and world.soldiers[1].selected and not world.soldiers[2].selected)
	world.soldiers[2].sid = 7
	input._update_selection()
	assert(world.soldiers[2].selected)
	input.sel_squads.clear()
	input.sel_unit = 2
	input._update_selection()
	assert(not world.soldiers[0].selected and world.soldiers[1].selected and not world.soldiers[2].selected)
	world.soldiers[1].life = Soldier.Life.DOWNED
	input._update_selection()
	assert(input.sel_unit == 0 and input._marked_soldiers.is_empty())
	input.sel_squads = [7]
	input._update_selection()
	assert(world.soldiers[1].selected)
	world.local_team = 1
	input._update_selection()
	assert(input.sel_squads.is_empty() and not world.soldiers[0].selected)
	world.local_team = 0
	input.sel_squads = [7]
	input._update_selection()
	var removed: Soldier = world.soldiers.pop_back()
	world.entities.erase(removed.eid)
	removed.free()
	for s in world.soldiers: s.life = Soldier.Life.DEAD
	input._update_selection()
	assert(input.sel_squads.is_empty() and input._marked_soldiers.is_empty())
	for s in world.soldiers: s.free()
	world.soldiers.clear()
	world.entities.clear()
	input.free()
	world.free()
	print("SELECTION_CACHE passed")
	get_tree().quit()
