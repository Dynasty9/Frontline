extends "res://tests/mocap/gameplay_stances.gd"

func _physics_process(dt: float) -> void:
	time += dt
	var act := Soldier.Act.LIMP if time < 5.0 else (Soldier.Act.DAZED if time < 9.0 else Soldier.Act.IDLE)
	var speed := 0.65 if time > 1.0 and time < 4.0 else 0.0
	soldier.position += Vector3.FORWARD * speed * dt
	proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, act, speed, false, false)
	if time > 1.5 and time < 4.0:
		assert(soldier._activity_clip.ends_with("injured_walk"))
		assert(soldier._activity_clock > 0.1, "Equipment transition restarted the injured walk")
	if time > 6.0 and time < 9.0:
		assert(soldier._activity_clip.ends_with("injured_stumble_idle"))
		assert(soldier.weapon_stowed, "Injured pose is still dragging a rifle through the ground")
	if time > 10.0:
		assert(proxy._native_locomotion and not soldier.weapon_stowed, "Activity failed to return to rifle locomotion")
		print("INJURED ACTIONS PASS walking, idle, dazed and armed recovery")
		get_tree().quit()
	caption.text = "Captured injury / " + Soldier.Act.keys()[act]
	camera.position = soldier.position + Vector3(-2, 1.4, -3)
	camera.look_at(soldier.position + Vector3(0, 0.75, 0))
