extends Node

func _ready() -> void:
	var world := World.new()
	var squad := Squad.new()
	squad.world = world
	squad.sid = 1
	world.squads[squad.sid] = squad
	var man := Soldier.new()
	man.world = world
	squad.add(man)
	var plan := AttackPlan.new()
	plan.world = world
	plan.assault = [{"sq": squad, "team": -1}]
	squad.plan = plan
	# Force the lifecycle boundary instead of relying on one battle's casualties.
	man.life = Soldier.Life.DEAD
	squad.think_t = 0.0
	squad.tick(0.5)
	assert(world.stats.get("plan_squad_lost", 0) == 1)
	assert(not world.squads.has(squad.sid))
	assert(squad.members.is_empty() and squad.plan == null and man.squad == null)
	man.free()
	plan._finish(false)
	assert(plan.done and world.stats.get("plan_failed", 0) == 1)
	world.free()
	print("ATTACK_LIFECYCLE passed")
	get_tree().quit()
