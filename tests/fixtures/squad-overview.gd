extends Node

func _ready() -> void:
	var world := World.new()
	var hud := Hud.new()
	hud.world = world
	var overlay := HudOverlay.new()
	overlay.hud = hud
	var members := []
	for i in 4:
		var s := Soldier.new()
		s.sid = 7
		s.team = 0
		s.utype = "rifleman"
		s.position = Vector3(i * 2, 0, 0)
		world.soldiers.append(s)
		members.append(s)
	members[0].flags = Soldier.F_SHOOTING | Soldier.F_PINNED | Soldier.F_LEADER
	members[1].life = Soldier.Life.DOWNED
	members[2].life = Soldier.Life.DEAD
	members[3].visible = false
	overlay._build_groups({"sel_squads": []})
	var group: Dictionary = overlay._groups[7]
	assert(group.n == 1 and group.firing == 1 and group.supp == 1)
	assert(group.lead == members[0] and group.c == members[0].position)
	assert(group.mem == members.slice(0, 3), "Visible membership retains soldier registration order")
	assert(group.pips == [Color(0.92, 0.95, 0.9), Color(1, 0.32, 0.26), Color(0.32, 0.32, 0.3)])
	assert(group.symbol == ["inf", ""] and group.callsign == Squad.callsign_of(0, 7).to_upper())
	var strength: ArrayMesh = group.pip_mesh
	members[0].flags = 0
	overlay._groups_at = -1000
	overlay._build_groups({"sel_squads": [7]})
	assert(overlay._groups[7].firing == 0 and overlay._groups[7].supp == 0)
	assert(overlay._groups[7].lead == null, "Losing a leader must clear the previous summary")
	assert(overlay._sel_sids.has(7))
	assert(overlay._groups[7].pip_mesh == strength, "Unchanged strength keeps its drawing mesh")
	members[1].life = Soldier.Life.ALIVE
	overlay._groups_at = -1000
	overlay._build_groups({"sel_squads": []})
	assert(overlay._groups[7].pip_mesh != strength, "Healing must change the colored strength indicator")
	assert(overlay._groups[7].n == 2 and overlay._groups[7].c == Vector3(1, 0, 0), "Only living visible members contribute to the centroid")
	members[0].flags = Soldier.F_SHOOTING
	overlay._groups_at = -1000
	overlay.prepare_groups({"sel_squads": [7]}, true)
	assert(overlay._groups[7].firing == 0 and overlay._sel_sids.has(7), "Squad rebuilding yields to a redraw while selection stays immediate")
	overlay.prepare_groups({"sel_squads": []}, true)
	assert(overlay._groups[7].firing == 1 and overlay._sel_sids.is_empty(), "Continuous camera redraws cannot postpone the overview more than one frame")
	members[0].flags = 0
	overlay._groups_at = -1000
	overlay.prepare_groups({"sel_squads": []}, false)
	assert(overlay._groups[7].firing == 0, "An idle drawing frame can prepare the next overview immediately")
	var squad := Squad.new()
	squad.members = members.duplicate()
	assert(squad.has_alive_members() == not squad.alive_members().is_empty())
	for s in members: s.life = Soldier.Life.DEAD
	assert(not squad.has_alive_members())
	members[1].life = Soldier.Life.DOWNED
	assert(not squad.has_alive_members())
	members[1].life = Soldier.Life.ALIVE
	members[1].gone = true
	assert(not squad.has_alive_members())
	members[1].gone = false
	assert(squad.has_alive_members())
	world.soldiers.clear()
	for s in members: s.free()
	assert(not squad.has_alive_members())
	overlay.free()
	hud.free()
	world.free()
	print("SQUAD_OVERVIEW passed")
	get_tree().quit()
