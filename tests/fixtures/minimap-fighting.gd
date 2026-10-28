extends Node

class FightingMap extends HudMinimap:
	func _draw_content(_phase := -1) -> void:
		_draw_fighting(hud.world, 1.0)

func _ready() -> void:
	var world := World.new()
	var hud := Hud.new()
	hud.world = world
	var map := FightingMap.new()
	map.hud = hud
	map.size = Vector2(240, 240)
	add_child(map)
	var ok := true
	for metres in [2048, 3072]:
		MapDims.configure(metres)
		var base := -MapDims.HALF + 12.0
		for pos in [Vector3(base + 24, 0, base), Vector3(base, 0, base + 1536), Vector3(base + 25, 0, base)]:
			var s := Soldier.new()
			s.position = pos
			s.flags = Soldier.F_SHOOTING
			world.soldiers.append(s)
		map.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		ok = ok and map._fight.size() == 2
		world.soldiers[0].visible = false
		world.soldiers[2].life = Soldier.Life.DEAD
		map.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		ok = ok and map._fight.size() == 1 and map._fight.values()[0] == world.soldiers[1].position
		for s in world.soldiers: s.free()
		world.soldiers.clear()
	map.free()
	hud.free()
	world.free()
	MapDims.configure(1024)
	print("MINIMAP_FIGHTING passed=", ok)
	get_tree().quit(0 if ok else 1)
