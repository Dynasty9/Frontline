extends "res://tests/mocap/skinned_demo.gd"

func _ready() -> void:
	super._ready()
	load("res://scripts/game/mixamo_clips.gd").install(soldier, true)
	var driver = load("res://scripts/game/rifle_animation_controller.gd").new()
	driver.setup(soldier)
	if soldier.model_asset.ends_with("Soldier.glb"):
		assert(driver.stride_lengths.walking > 1.5 and driver.stride_lengths.walking < 1.6)
		assert(driver.stride_lengths.rifle_run > 2.5 and driver.stride_lengths.rifle_run < 2.7)
	else:
		assert(driver.stride_lengths.walking > 1.3 and driver.stride_lengths.walking < 1.4)
		assert(driver.stride_lengths.rifle_run > 2.2 and driver.stride_lengths.rifle_run < 2.4)
	var cases := [Vector3(0,0,-1.4), Vector3(0,0,-3.4), Vector3(0,0,1.4), Vector3(0,0,3.4), Vector3(-2,0,0), Vector3(2,0,0), Vector3(0,0,-2.4), Vector3(0,0,2.4)]
	var drift_limits := [0.4, 0.85, 0.6, 0.3, 0.8, 0.35]
	# Backward heel plants permit toe roll; the planted-support bounds below measure sliding.
	var toe_limits := [1.0, 0.05, 1.5, 0.14, 1.8, 1.15, 0.65, 0.5]
	var planted_limits := [0.02, 0.005, 0.01, 0.01, 0.02, 0.005, 0.01, 0.005]
	for index in cases.size():
		var velocity: Vector3 = cases[index]
		var authored: Dictionary = driver.stride_lengths.duplicate()
		var measured := _sliding(driver, velocity)
		var toes := _sliding(driver, velocity, "ToeBase")
		var planted := _sliding(driver, velocity, "Support", true)
		for clip in driver.stride_lengths: driver.stride_lengths[clip] = 1.8
		var previous := _sliding(driver, velocity)
		driver.stride_lengths = authored
		print("STRIDE velocity=", velocity, " near_floor_ankle old=", previous, " authored=", measured, " toe=", toes, " planted=", planted)
		# A running ankle moves as the foot rolls over its planted forefoot.
		if velocity.length() <= 1.4:
			assert(measured < drift_limits[index], "Near-floor walking ankle drift exceeded the locomotion regression limit")
		assert(toes < toe_limits[index], "Near-floor toe drift exceeded the locomotion regression limit")
		assert(planted < planted_limits[index], "Fully weighted support point slid too quickly")
	print("STRIDE PASS eight directional/speed samples including mixed walk/run")
	var diagonals := [Vector3(-1.4,0,-1.4), Vector3(1.4,0,-1.4), Vector3(-1.4,0,1.4), Vector3(1.4,0,1.4)]
	var contact_limits := [0.002, 0.002, 0.002, 0.002]
	for i in diagonals.size():
		var contact_speed := _sliding(driver, diagonals[i], "ToeBase", false, 0.005)
		print("DIAGONAL velocity=", diagonals[i], " grounded_toe=", contact_speed)
		assert(contact_speed < contact_limits[i], "Diagonal ground-contact toe drift regressed")
	driver.reset()
	driver.max_contact_change = 0.0
	for frame in 480:
		var velocity := Vector3.FORWARD.rotated(Vector3.UP, TAU * frame / 480.0) * 2.0
		soldier.position += velocity / 60.0
		driver.advance(1.0 / 60.0, velocity, false, true)
	print("TURN contact_change=", driver.max_contact_change)
	assert(driver.max_contact_change < 0.12, "Turning across cardinal/diagonal boundaries snapped a foot correction")
	# Low pose rates must not fling a released foot back to the sampled clip.
	driver.reset()
	soldier.position = Vector3.ZERO
	var previous_joints := {}
	var max_joint_step := 0.0
	for frame in 240:
		var velocity := Vector3.FORWARD.rotated(Vector3.UP, TAU * (frame + 1) / 240.0) * 2.0
		soldier.position += velocity / 30.0
		driver.advance(1.0 / 30.0, velocity, false, true)
		for bone in ["LeftFoot", "RightFoot", "LeftLeg", "RightLeg"]:
			var at := soldier.joint(bone).origin - soldier.global_position
			if previous_joints.has(bone) and frame > 30:
				max_joint_step = maxf(max_joint_step, at.distance_to(previous_joints[bone]))
			previous_joints[bone] = at
	print("TURN 30Hz max_joint_step=", max_joint_step)
	assert(max_joint_step < 0.28, "Low-rate turn leg movement regressed")
	for side in 2:
		var name := "LeftFoot" if side == 0 else "RightFoot"
		soldier.feet[side].locked = true
		soldier.feet[side].point = soldier.joint(name).origin + Vector3.RIGHT
	driver.plant_weights = [1.0, 1.0]
	driver._contacts(2.0, 1.0 / 60.0)
	assert(not soldier.feet[0].locked and not soldier.feet[1].locked, "Overstretched moving plant did not release")
	driver.advance(1.0 / 60.0, Vector3.UP, false, false)
	assert(not soldier.feet[0].locked and not soldier.feet[1].locked)
	assert(driver.plant_weights == [0.0, 0.0])
	driver.reset()
	assert(driver.plant_ready == [true, true])
	get_tree().quit()

func _sliding(driver, velocity: Vector3, bone_suffix := "Foot", locked_only := false, clearance := 0.035) -> float:
	driver.reset()
	driver.blend_velocity = velocity
	soldier.position = Vector3.ZERO
	var previous: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var low := [false, false]
	var distance := 0.0
	var seconds := 0.0
	for frame in 360:
		soldier.position += velocity / 60.0
		driver.advance(1.0 / 60.0, velocity, false, true)
		for side in 2:
			var prefix := "Left" if side == 0 else "Right"
			var name := prefix + ("Foot" if bone_suffix == "Support" else bone_suffix)
			var at := soldier.joint(name).origin
			var sole: float = soldier.target_rest[int(soldier.bones[name])].origin.y
			if bone_suffix == "Support":
				var forefoot := clampf((velocity.length() - 1.4) / 2.0, 0.0, 1.0)
				at = at.lerp(soldier.joint(prefix + "ToeBase").origin, forefoot)
				sole = lerpf(sole, soldier.target_rest[int(soldier.bones[prefix + "ToeBase"])].origin.y, forefoot)
			var planted := at.y - sole < clearance
			if locked_only: planted = planted and soldier.feet[side].locked and driver.plant_weights[side] > 0.99
			if frame > 120 and planted and low[side]:
				var step := at - previous[side]
				step.y = 0.0
				distance += step.length()
				seconds += 1.0 / 60.0
			previous[side] = at
			low[side] = planted
	assert(seconds > 0.2, "No planted samples")
	return distance / seconds

func _physics_process(_dt: float) -> void:
	pass
