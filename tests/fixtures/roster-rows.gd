extends Node

var draws := 0

func refresh(roster: HudOrbat) -> void:
	roster.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame


func _ready() -> void:
	var world := World.new()
	world.local_team = 0
	world.input = PlayerInput.new()
	world.input.world = world
	var hud := Hud.new()
	hud.world = world
	var members: Array[Soldier] = []
	for i in 5:
		var s := Soldier.new()
		s.sid = 7
		s.team = 0
		s.utype = "rifleman"
		members.append(s)
		world.soldiers.append(s)
	var roster := HudOrbat.new()
	roster.hud = hud
	roster.size = Vector2(320, 300)
	add_child(roster)
	roster.open = true
	await refresh(roster)
	var line: HudOrbat.SquadLine = roster._squad_lines[7]
	line.draw.connect(func(): draws += 1)
	assert(line.visible and line.state.alive == 5 and line.state.hurt == 0)
	assert(roster._rows.size() == 1 and roster._rows[0][2] == 7)
	await refresh(roster)
	members[0].position.x += 10
	await refresh(roster)
	assert(draws == 0, "Unchanged labels and movement retain their drawing commands")
	world.input.sel_squads.append(7)
	await refresh(roster)
	assert(draws == 1 and line.state.selected)
	members[0].life = Soldier.Life.DOWNED
	await refresh(roster)
	assert(draws == 2 and line.state.hurt == 1 and line.state.alive == 4)
	for s in members: s.flags = Soldier.F_LOWAMMO
	await refresh(roster)
	assert(draws == 3 and String(line.state.code).contains("LOW AMMO"))
	roster._hover = 0
	await refresh(roster)
	assert(draws == 3, "Hover only changes the row background")
	roster._scroll = 80
	await refresh(roster)
	assert(not line.visible and roster._rows.is_empty())
	roster._scroll = 0
	await refresh(roster)
	assert(line.visible and roster._rows.size() == 1)
	var original_atlas := MapSymbols.atlas
	MapSymbols.atlas = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	var atlas_before := draws
	await refresh(roster)
	assert(draws == atlas_before + 1, "Rebuilding the symbol atlas must refresh retained icons")
	MapSymbols.atlas = original_atlas
	await refresh(roster)
	roster.open = false
	await refresh(roster)
	assert(not line.visible)
	roster.open = true
	await refresh(roster)
	assert(line.visible)
	# Theme refresh recursively invalidates every CanvasItem, including retained rows.
	var before := draws
	UiKit._recolour(roster, [], {})
	await refresh(roster)
	assert(draws == before + 1)
	world.soldiers.clear()
	await refresh(roster)
	assert(roster._squad_lines.is_empty() and not is_instance_valid(line))
	roster.free()
	hud.free()
	world.input.free()
	world.free()
	for s in members: s.free()
	print("ROSTER_ROWS passed")
	get_tree().quit()
