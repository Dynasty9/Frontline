extends Node

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1


func _ready() -> void:
	var world := World.new()
	world.time = 1.0
	var squad := Squad.new()
	squad.world = world
	var man := Soldier.new()
	var combat := Combat.new(world)
	check(combat.find_cover(man, Vector3.ZERO, 30.0, [], false).is_empty(), "Quiet sectors must skip cover enumeration entirely")
	squad.add(man)
	check(not squad.in_combat(), "An undisturbed squad must remain out of combat")
	var enemy := Soldier.new()
	enemy.eid = 7
	enemy.position = Vector3(10, 0, 0)
	squad.report(enemy)
	check(squad.in_combat(), "A new contact must wake the squad immediately")
	var first := squad.sector_threats(man.position).duplicate()
	check(first == squad.threat_points(squad.centroid(), 3), "Shared briefing must use the normal threat ranking")
	enemy.position.x = 15
	world.time += 0.1
	squad.report(enemy)
	check(squad.sector_threats(man.position) == first, "Repeated sightings must reuse the brief assessment window")
	world.time += 0.2
	check(squad.sector_threats(man.position) != first, "Moving contacts must refresh after the assessment window")
	var separated := Vector3(40, 0, 0)
	check(squad.sector_threats(separated) == squad.threat_points(separated, 3), "A separated soldier must assess his own position")
	var newcomer := Soldier.new()
	newcomer.eid = 8
	newcomer.position = Vector3(0, 0, 8)
	squad.report(newcomer)
	check(squad.sector_threats(man.position).size() == 2, "A new enemy must invalidate the briefing immediately")
	world.time += 16.0
	check(squad.sector_threats(man.position).is_empty() and not squad.in_combat(), "Old contacts must expire")
	squad.report_pos(Vector3(8, 0, 0))
	check(squad.in_combat() and not squad.sector_threats(man.position).is_empty(), "The first heard shot must wake an empty briefing")
	var heard_briefing := squad.sector_threats(man.position).duplicate()
	world.time += 0.1
	squad.report_pos(Vector3(0, 0, 8))
	check(squad.sector_threats(man.position) == heard_briefing, "Sustained fire must share the same assessment window")
	world.time += 0.2
	check(squad.sector_threats(man.position) != heard_briefing, "Heard positions must refresh at the normal cadence")
	squad.remove(man)
	man.free()
	enemy.free()
	newcomer.free()
	world.free()
	print("SQUAD_ASSESSMENT_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
