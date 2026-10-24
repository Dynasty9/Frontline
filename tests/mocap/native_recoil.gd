extends "res://tests/mocap/skinned_demo.gd"

var driver: RefCounted
var shots := 0

func _ready() -> void:
	super._ready()
	load("res://scripts/game/mixamo_clips.gd").install(soldier, true)
	driver = load("res://scripts/game/rifle_animation_controller.gd").new()
	driver.setup(soldier)
	assert(soldier.native_hit_clip != null and soldier.native_hit_tracks.size() == 5)
	driver.advance(0.0, Vector3.ZERO, false, true)
	var idle_pose: Array[Transform3D] = []
	for bone in soldier.skeleton.get_bone_count(): idle_pose.append(soldier.skeleton.get_bone_pose(bone))
	var started := Time.get_ticks_usec()
	for frame in 10000: soldier._apply_hit(1.0 / 60.0)
	print("IDLE HIT 10000 updates usec=", Time.get_ticks_usec() - started)
	for bone in idle_pose.size():
		assert(soldier.skeleton.get_bone_pose(bone).is_equal_approx(idle_pose[bone]), "An inactive hit layer changed the captured pose")
	for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
		soldier.rotation.y = yaw
		driver.advance(0.0, Vector3.ZERO, false, true)
		var before := soldier.weapon.global_transform
		var grip := before.affine_inverse() * soldier.joint("LeftHand")
		var foot := soldier.joint("LeftFoot")
		soldier.recoil.offset = Vector3.ZERO
		soldier.recoil.velocity = Vector3.ZERO
		soldier.fire_kick(1.0)
		soldier.apply_native_recoil(1.0 / 12.0, soldier.native_socket)
		var after := soldier.joint("RightHand") * soldier.native_socket
		print("RECOIL yaw=", yaw, " muzzle_rise=", after.basis.z.normalized().y - before.basis.z.normalized().y)
		assert(after.basis.z.normalized().y > before.basis.z.normalized().y + 0.02, "Rifle muzzle did not rise")
		assert((after.affine_inverse() * soldier.joint("LeftHand")).is_equal_approx(grip), "Recoil separated the support grip")
		assert(soldier.joint("LeftFoot").is_equal_approx(foot), "Recoil moved a planted foot")
		for frame in 120: driver.advance(1.0 / 60.0, Vector3.ZERO, false, true)
		assert(soldier.recoil.offset.length() < 0.00001 and soldier.recoil.velocity.length() < 0.0001)
		for direction in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			soldier.reaction.offset = Vector3.ZERO
			soldier.reaction.velocity = Vector3.ZERO
			soldier.native_hit_time = INF
			driver.advance(0.0, Vector3.ZERO, false, true)
			var head := soldier.joint("Head").origin
			soldier.hit(direction, 1.0)
			var frontal: float = direction.dot(soldier.global_basis.z.normalized())
			assert(soldier.native_hit_strength > 0.3 if frontal > 0.99 else soldier.native_hit_strength < 0.001, "Authored flinch must match the incoming direction")
			soldier._apply_hit(1.0 / 12.0)
			assert((soldier.joint("Head").origin - head).dot(direction) > 0.01, "Hit reaction moved against the projectile: " + str(direction) + " yaw=" + str(yaw))
		soldier.reaction.offset = Vector3.ZERO
		soldier.reaction.velocity = Vector3.ZERO
	soldier.rotation.y = 0.0
	soldier.reset_motion()
	soldier.hit(Vector3.BACK)
	driver.advance(0.08, Vector3.ZERO, false, true)
	var flinch_time := soldier.native_hit_time
	var flinch_strength := soldier.native_hit_strength
	for direction in [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD]:
		soldier.hit(direction)
		assert(soldier.native_hit_time == flinch_time and soldier.native_hit_strength == flinch_strength, "A repeated hit restarted or erased the active flinch")
	for frame in 120: driver.advance(1.0 / 60.0, Vector3.ZERO, false, true)
	assert(soldier.native_hit_time >= soldier.native_hit_clip.length and soldier.reaction.offset.length() < 0.00001)
	soldier.hit(Vector3.BACK)
	assert(soldier.native_hit_time == 0.0, "A recovered flinch did not retrigger")
	soldier.reset_motion()
	assert(is_inf(soldier.native_hit_time))
	# All captured entry points must consume firing events, not leave a stale spring for another stance.
	for mode in 3:
		soldier.fire_kick(1.0)
		if mode == 0: driver.advance(1.0 / 60.0, Vector3.ZERO, false, true)
		elif mode == 1: driver.advance_prone(1.0 / 60.0)
		else: soldier.pose_native(1.0 / 60.0, driver.PACK + "rifle_aiming_idle")
		assert(soldier.recoil.offset.z > 0.0 and soldier.recoil.velocity.z < 0.5)
		soldier.recoil.offset = Vector3.ZERO
		soldier.recoil.velocity = Vector3.ZERO
	print("NATIVE RECOIL PASS four headings, muzzle rise, support grip, planted foot, recovery, three captured pose paths and 16 directional hit cases")
	soldier.rotation.y = 0.0
	driver.reset()
	camera.position = Vector3(-2.4, 1.6, -2.8)
	camera.look_at(Vector3(0, 1.25, 0))
	caption.text = "Captured rifle pose / three-shot bursts / grips stay attached"

func _physics_process(dt: float) -> void:
	if driver == null: return
	time += dt
	var target := int(time / 0.15)
	if target > shots:
		shots = target
		if target % 12 < 3: soldier.fire_kick(1.0)
	driver.advance(dt, Vector3.ZERO, false, true)
	if time > 6.0: get_tree().quit()
