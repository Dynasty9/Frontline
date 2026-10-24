extends "res://tests/mocap/skinned_demo.gd"

func _ready() -> void:
	super._ready()
	_check_motion_sampling()
	_check_character_sampling()
	var dt := 1.0 / 30.0
	var travel := Vector3(0, 0, 2)
	soldier.pose(0.1, 0.0, "idle")
	soldier.capture_motion(dt)
	soldier.position += travel * dt
	soldier.capture_motion(dt)
	for velocity in soldier.limb_velocity.values():
		assert(velocity.length() < 0.0001, "Root travel counted as limb motion")
	var arm := soldier.joint("RightForeArm")
	arm.origin += Vector3(0.02, 0, 0)
	arm.basis = Basis(Vector3.BACK, 0.1) * arm.basis
	soldier.set_world(int(soldier.bones["RightForeArm"]), arm)
	soldier.capture_motion(dt)
	assert(soldier.limb_velocity["RightForeArm"].distance_to(Vector3(0.6, 0, 0)) < 0.001)
	assert(soldier.limb_spin["RightForeArm"].distance_to(Vector3(0, 0, 3)) < 0.001)
	soldier.last_velocity = travel
	soldier.hit(Vector3.RIGHT)
	soldier.fire_kick(1.0)
	soldier.reaction.step(dt)
	soldier.recoil.step(dt)
	assert(soldier.reaction.offset != Vector3.ZERO and soldier.recoil.offset != Vector3.ZERO)
	soldier.kill(Vector3.ZERO, 2)
	var body: RigidBody3D = soldier.ragdoll.bodies["RightForeArm"]
	var expected := travel + Vector3(0.6, 0, 0) + Vector3(0, 0, 3).cross(body.global_basis * body.get_child(0).position)
	assert(body.linear_velocity.distance_to(expected) < 0.001, "Animated COM momentum lost at death")
	assert(body.angular_velocity.distance_to(Vector3(0, 0, 3)) < 0.001)
	assert(soldier.ragdoll.weapon_body.linear_velocity.distance_to(travel) < 0.001)
	soldier.revive()
	assert(soldier.motion_poses.is_empty() and soldier.limb_velocity.is_empty() and soldier.limb_spin.is_empty())
	assert(soldier.last_velocity == Vector3.ZERO)
	assert(soldier.reaction.offset == Vector3.ZERO and soldier.reaction.velocity == Vector3.ZERO)
	assert(soldier.recoil.offset == Vector3.ZERO and soldier.recoil.velocity == Vector3.ZERO)
	soldier.hit(Vector3.LEFT)
	soldier.fire_kick(1.0)
	soldier.position += Vector3(4, 0, 2)
	soldier.foot_offsets[0] = Vector2(0.2, 0.1)
	soldier.feet[0].locked = true
	soldier.reset_motion()
	assert(soldier.foot_offsets == [Vector2.ZERO, Vector2.ZERO] and not soldier.feet[0].locked, "Reset retained an old foot plant")
	soldier.pose(dt, 0.0, "idle")
	assert(soldier.last_velocity == Vector3.ZERO, "Reset teleport became physical travel")
	assert(soldier.reaction.step(dt) == Vector3.ZERO and soldier.recoil.step(dt) == Vector3.ZERO, "Live reset retained an impact")
	soldier.capture_motion(dt)
	soldier.capture_motion(0.0)
	assert(soldier.motion_poses.is_empty(), "Scrubbing retained stale motion")
	print("RAGDOLL MOMENTUM PASS root travel, limb translation/rotation, COM velocity, weapon, revive/live impact reset and teleport")
	get_tree().quit()

func _check_motion_sampling() -> void:
	# Scaled props still produce the same spin as normalizing both poses each frame.
	var previous := Transform3D.IDENTITY
	for frame in 120:
		var pose := Transform3D(Basis.from_euler(Vector3(frame * 0.01, frame * 0.02, frame * -0.007)).scaled(Vector3(1.1, 0.9, 1.3)), Vector3(frame * 0.01, 0, 0))
		soldier._sample_motion("probe", pose, 1.0 / 60.0)
		if frame > 0:
			var rotation := (pose.basis.orthonormalized() * previous.basis.orthonormalized().inverse()).get_rotation_quaternion()
			var expected_spin := (rotation.get_axis() * wrapf(rotation.get_angle(), -PI, PI) * 60.0).limit_length(12.0)
			assert(soldier.limb_spin["probe"].distance_to(expected_spin) < 0.001, "Cached motion orientation changed spin")
			assert(soldier.limb_velocity["probe"].distance_to(Vector3(0.6, 0, 0)) < 0.001)
		previous = pose
	soldier.capture_motion(0.0)
func _check_character_sampling() -> void:
	var initial := soldier.transform
	var max_spin_error := 0.0
	for frame in 120:
		soldier.rotation.y = frame * 0.01
		soldier.position += Vector3(0.01, 0, 0.02)
		soldier.pose(1.0 / 60.0, 2.4)
		for part in SkinnedRagdoll.PARTS:
			soldier._sample_motion("reference_" + part[0], soldier.joint(part[0]), 1.0 / 60.0)
		soldier.capture_motion(1.0 / 60.0)
		if frame == 0: continue
		for part in SkinnedRagdoll.PARTS:
			var name: String = part[0]
			max_spin_error = maxf(max_spin_error, soldier.limb_spin[name].distance_to(soldier.limb_spin["reference_" + name]))
			assert(soldier.limb_velocity[name].distance_to(soldier.limb_velocity["reference_" + name]) < 0.00001)
	assert(max_spin_error < 0.001, "Direct skeleton sampling changed animated death spin")
	print("MOTION SAMPLING spin_error=", max_spin_error)
	soldier.transform = initial
	soldier.reset_motion()
