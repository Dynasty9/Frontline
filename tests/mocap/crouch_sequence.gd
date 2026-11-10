extends "res://tests/mocap/gameplay_stances.gd"

func _physics_process(dt: float) -> void:
	time += dt
	var crouched := time >= 1.0 and time < 5.0 or time >= 7.0 and time < 10.0
	var posture := Soldier.Post.CROUCH if crouched else Soldier.Post.STAND
	var act := Soldier.Act.IDLE
	var speed := 0.0
	if time >= 3.0 and time < 3.6: act = Soldier.Act.THROW
	elif time >= 7.0 and time < 8.5:
		act = Soldier.Act.WALK
		speed = 0.7
	soldier.position += Vector3.FORWARD * speed * dt
	proxy.pose(dt, 0, posture, act, speed, false, false)
	caption.text = "Captured kneel / " + ("Grenade throw" if act == Soldier.Act.THROW else proxy.rifle_driver.state)
	camera.position = soldier.position + Vector3(-2.0, 1.4, -2.8)
	camera.look_at(soldier.position + Vector3(0, 0.75, 0))
	if time > 12.0: get_tree().quit()
