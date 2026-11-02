extends "res://tests/mocap/skinned_demo.gd"

func _ready() -> void:
	super._ready()
	load("res://scripts/game/mixamo_clips.gd").install(soldier, true)
	var driver = load("res://scripts/game/rifle_animation_controller.gd").new()
	driver.setup(soldier)
	driver.advance(0.0, Vector3.ZERO, false, true)
	var reference := soldier.weapon.global_transform.affine_inverse() * soldier.joint("LeftHand").origin.lerp(soldier.joint("LeftHandMiddle1").origin, 0.65)
	print("GRIP palm=", reference)
	# The M4 handguard underside is 7.1 cm above the imported weapon origin.
	assert(reference.y > 0.04 and reference.y < 0.08, "Support palm misses the M4 handguard")
	assert(reference.z > 0.20 and reference.z < 0.30, "Support palm misses the fore-end")
	for velocity in [Vector3.ZERO, Vector3(0,0,-1.4), Vector3(0,0,-3.4), Vector3(0,0,3.4), Vector3(-2,0,0), Vector3(2,0,0), Vector3(-1.4,0,-1.4), Vector3(1.4,0,-1.4), Vector3(-1.4,0,1.4), Vector3(1.4,0,1.4)]:
		driver.reset()
		var worst := 0.0
		for frame in 180:
			driver.advance(1.0/60.0, velocity, false, true)
			var palm := soldier.joint("LeftHand").origin.lerp(soldier.joint("LeftHandMiddle1").origin, 0.65)
			worst = maxf(worst, palm.distance_to(soldier.weapon.global_transform * reference))
		print("GRIP velocity=", velocity, " support_drift=", worst)
		assert(worst < 0.007, "Locomotion detached the support grip")
	driver.reset()
	_check_prone_hits(driver)
	driver.reset()
	driver.request_action("reloading")
	var release := 0.0
	for frame in 120:
		driver.advance(1.0 / 60.0, Vector3.ZERO, false, true)
		release = maxf(release, soldier.joint("LeftHand").origin.distance_to((soldier.weapon.global_transform * driver.support_grip).origin))
	var forearm := soldier.joint("LeftHand").origin.distance_to(soldier.joint("LeftForeArm").origin)
	if release < forearm * 0.5:
		push_error("Support IK prevented the reload hand release")
		get_tree().quit(1)
		return
	print("NATIVE GRIP PASS ten movement cases and reload release=", release)
	get_tree().quit()

func _physics_process(_dt: float) -> void:
	pass


func _check_prone_hits(driver) -> void:
	var worst := 0.0
	for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
		soldier.rotation.y = yaw
		driver.reset()
		for frame in 180: driver.advance_prone(1.0 / 60.0)
		var references := {}
		for side in ["Left", "Right"]:
			references[side] = soldier.weapon.global_transform.affine_inverse() * _palm(side)
		for direction in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			soldier.hit(direction)
			soldier.fire_kick(1.0)
			for frame in 120:
				driver.advance_prone(1.0 / 60.0)
				for side in references:
					worst = maxf(worst, _palm(side).distance_to(soldier.weapon.global_transform * references[side]))
			assert(soldier.reaction.offset.length() < 0.00001, "Prone hit did not recover")
	assert(worst < 0.001, "Prone hit or recoil detached a palm from the rifle")
	print("PRONE GRIP PASS 16 directional hits, both palms and recovery; drift=", worst)
	soldier.rotation.y = 0.0

func _palm(side: String) -> Vector3:
	return soldier.joint(side + "Hand").origin.lerp(soldier.joint(side + "HandMiddle1").origin, 0.65)
