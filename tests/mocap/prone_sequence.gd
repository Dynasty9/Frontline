extends "res://tests/mocap/gameplay_stances.gd"

func _physics_process(dt: float) -> void:
	if time < 11.0 and time + dt >= 11.0: soldier.hit(Vector3.BACK)
	time += dt
	var posture := Soldier.Post.PRONE if time >= 1.0 and time < 20.0 else Soldier.Post.CROUCH
	var act := Soldier.Act.IDLE
	var speed := 0.0
	proxy.move_yaw = 0.0
	if time >= 4.0 and time < 6.0:
		act = Soldier.Act.CRAWL
		speed = 0.45
	elif time >= 8.0 and time < 10.0:
		act = Soldier.Act.CRAWL
		speed = 0.45
		proxy.move_yaw = PI
	elif time >= 12.0 and time < 14.0: act = Soldier.Act.SHOOT
	elif time >= 14.0 and time < 16.3: act = Soldier.Act.RELOAD
	elif time >= 17.0 and time < 17.6: act = Soldier.Act.THROW
	soldier.position += Vector3.FORWARD.rotated(Vector3.UP, proxy.move_yaw) * speed * dt
	proxy.pose(dt, 0, posture, act, speed, proxy.move_yaw != 0.0, act == Soldier.Act.SHOOT)
	caption.text = "Captured prone / " + ("Grenade throw" if act == Soldier.Act.THROW else proxy.rifle_driver.state)
	camera.position = soldier.position + Vector3(2.0, 1.05, -2.6)
	camera.look_at(soldier.position + Vector3(0, 0.35, 0))
	if time > 23.0: get_tree().quit()
