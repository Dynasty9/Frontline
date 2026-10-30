extends "res://scripts/main.gd"

func _ready() -> void:
	super._ready()

func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world): return
	if int(world.settings.seed) != int(args.seed):
		push_error("Scenario ignored the requested seed")
		get_tree().quit(1)
		return
	if world.time < 1.0: return
	var positions: Array[Vector3] = []
	for unit in world.soldiers: positions.append(unit.position)
	print("SCENARIO SEED PASS seed=", world.settings.seed, " state=", hash(positions), " rng=", world.rng.state)
	get_tree().quit()
