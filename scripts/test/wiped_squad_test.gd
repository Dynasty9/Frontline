extends Node
## Force the casualty instead of depending on a particular combat balance.

func _ready() -> void:
	TestRun.watch()
	for won in [false, true]:
		var world := World.new()
		var squad := Squad.new()
		squad.world = world
		world.squads[squad.sid] = squad
		var man := Soldier.new()
		man.life = Soldier.Life.DEAD
		squad.add(man)
		var plan := AttackPlan.new()
		plan.world = world
		plan.assault = [{"sq": squad, "team": -1}]
		squad.plan = plan
		squad.tick(0.5)
		assert(squad.members.is_empty(), "a wiped squad releases its dead")
		assert(squad.plan == null, "a wiped squad leaves the attack")
		assert(not world.squads.has(squad.sid), "the squad is struck off")
		assert(world.stats.get("plan_squad_lost", 0) == 1)
		man.free()
		plan._finish(won)
		assert(plan.done, "the attack finishes after the bodies have been freed")
		world.free()
	print("WIPEDSQUAD passed")
	TestRun.quit(get_tree())
