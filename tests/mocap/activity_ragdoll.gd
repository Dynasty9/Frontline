extends "res://tests/mocap/gameplay_stances.gd"
var drop_started := false
var start_height := 0.0
func _physics_process(dt: float) -> void:
	if proxy == null: return
	time += dt
	if time < 2.0:
		proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.BUILD, 0.0, false, false)
	elif not drop_started:
		drop_started = true
		start_height = soldier.shovel.global_position.y
		soldier.kill(Vector3(0.6, 0, 0), 0)
		assert(soldier.ragdoll.tool_body != null and soldier.shovel.get_parent() == soldier.ragdoll.tool_body)
	elif time > 6.0:
		assert(soldier.shovel.global_position.y < start_height - 0.1, "Released shovel did not fall")
		assert(soldier.shovel.global_position.y > -0.1, "Released shovel passed through the floor")
		print("ACTIVITY RAGDOLL PASS released shovel and rifle, grounded tool height=",soldier.shovel.global_position.y)
		get_tree().quit()
