extends "res://tests/mocap/gameplay_stances.gd"

func _ready() -> void:
	super._ready()
	var worst_trigger := 0.0
	var worst_support := 0.0
	for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
		soldier.rotation.y = yaw
		proxy.rotation.y = yaw
		for posture in [Soldier.Post.LEAN_L, Soldier.Post.LEAN_R]:
			soldier._socket_ready = false
			assert(not soldier.native_fingers.is_empty())
			for index in soldier.native_fingers:
				soldier.skeleton.set_bone_pose_rotation(index, Quaternion(Vector3.RIGHT, 0.7))
			for frame in 120: proxy.pose(1.0 / 60.0, Soldier.Life.ALIVE, posture, Soldier.Act.SHOOT, 0.0, false, false)
			for index in soldier.native_fingers:
				assert(soldier.skeleton.get_bone_pose_rotation(index).is_equal_approx(soldier.native_fingers[index]), "Cover retained fingers from the preceding action")
			for direction in [Vector3.LEFT, Vector3.RIGHT]:
				soldier.hit(direction)
				soldier.fire_kick(1.0)
				for frame in 120:
					proxy.pose(1.0 / 60.0, Soldier.Life.ALIVE, posture, Soldier.Act.SHOOT, 0.0, false, false)
					var inverse := soldier.weapon.global_transform.affine_inverse()
					var trigger := inverse * soldier.joint("RightHandMiddle1").origin
					var support := inverse * soldier.joint("LeftHand").origin.lerp(soldier.joint("LeftHandMiddle1").origin, 0.65)
					worst_trigger = maxf(worst_trigger, trigger.distance_to(Vector3(0, -0.035, 0)))
					worst_support = maxf(worst_support, support.distance_to(Vector3(0, 0.055, 0.26)))
	print("COVER GRIP trigger=", worst_trigger, " support=", worst_support)
	assert(worst_trigger < 0.005, "Cover trigger hand detached from its calibrated grip")
	assert(worst_support < 0.005, "Cover support palm detached from the fore-end")
	get_tree().quit()

func _physics_process(_dt: float) -> void:
	pass
