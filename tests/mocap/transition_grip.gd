extends "res://tests/mocap/gameplay_stances.gd"

func _ready() -> void:
	super._ready()
	var worst := 0.0
	var worst_case := ""
	var right_error := 0.0
	for act in [Soldier.Act.COOK, Soldier.Act.WINDED, Soldier.Act.SMOTHER, Soldier.Act.KICK, Soldier.Act.IDLE_LOOK]:
		for phase in [Soldier.Act.WALK, act, Soldier.Act.SHOOT]:
			for frame in 90:
				proxy.pose(1.0 / 60.0, Soldier.Life.ALIVE, Soldier.Post.STAND, phase, 1.2 if phase == Soldier.Act.WALK else 0.0, false, true)
				if soldier.weapon_stowed or soldier.equip_time < 0.45: continue
				var palm := soldier.joint("LeftHand").origin.lerp(soldier.joint("LeftHandMiddle1").origin, 0.65)
				var error := palm.distance_to(soldier.weapon.global_transform * Vector3(0, 0.055, 0.26))
				var wrist: Transform3D = soldier.weapon.global_transform * proxy.rifle_driver.socket.affine_inverse()
				if proxy._native_locomotion: right_error = maxf(right_error, wrist.origin.distance_to(soldier.joint("RightHand").origin))
				if error > worst:
					worst = error
					worst_case = str([act, phase, frame])
	print("TRANSITION GRIP error=", worst, " case=", worst_case)
	assert(right_error < 0.001, "Trigger hand detached during recovery")
	assert(worst < 0.025, "Held rifle lost the support palm during an action boundary")
	print("TRANSITION GRIP PASS five actions, entry and exit, every frame")
	get_tree().quit()

func _physics_process(_dt: float) -> void: pass
