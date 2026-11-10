extends "res://tests/mocap/gameplay_stances.gd"

func _ready() -> void:
	super._ready()
	assert(proxy.get_script().resource_path == "res://scripts/game/soldier_model.gd", "A duplicate named class is shadowing SoldierModel")
	for state in [Soldier.Life.DOWNED, Soldier.Life.DEAD]:
		proxy.pose(1.0 / 60.0, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.IDLE, 0.0, false, false)
		soldier.kill(Vector3(0, 0, 0.8), 0)
		var body := soldier.ragdoll
		for frame in 5:
			proxy.pose(1.0 / 60.0, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.IDLE, 0.0, false, false)
			if not soldier.dead or soldier.ragdoll != body or body.done:
				push_error("Old alive state undid death: target=%s frame=%s last_life=%s dead=%s done=%s" % [state, frame, proxy._last_life, soldier.dead, body.done])
				get_tree().quit(1)
				return
		proxy.pose(1.0 / 60.0, state, Soldier.Post.STAND, Soldier.Act.IDLE, 0.0, false, false)
		assert(soldier.dead, "Death snapshot removed its ragdoll")
		proxy.pose(1.0 / 60.0, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.IDLE, 0.0, false, false)
		assert(not soldier.dead and body.done, "Confirmed revival failed to release the ragdoll")
	print("DEATH EVENT ORDER PASS delayed downed/dead snapshots and confirmed revival")
	get_tree().quit()

func _physics_process(_dt: float) -> void: pass
