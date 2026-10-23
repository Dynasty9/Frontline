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
	members[0].flags = Soldier.F_SHOOTING | Soldier.F_PINNED
	members[1].life = Soldier.Life.DOWNED
	members[2].life = Soldier.Life.DEAD
	members[3].visible = false
	overlay._build_groups({"sel_squads": []})
	var group: Dictionary = overlay._groups[7]
	assert(group.n == 1 and group.firing == 1 and group.supp == 1)
	assert(group.pips == [Color(0.92, 0.95, 0.9), Color(1, 0.32, 0.26), Color(0.32, 0.32, 0.3)])
	assert(group.symbol == ["inf", ""] and group.callsign == Squad.callsign_of(0, 7).to_upper())
	members[0].flags = 0
	overlay._groups_at = -1000
	overlay._build_groups({"sel_squads": [7]})
	assert(overlay._groups[7].firing == 0 and overlay._groups[7].supp == 0)
	assert(overlay._sel_sids.has(7))
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
