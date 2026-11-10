extends "res://tests/mocap/gameplay_stances.gd"
const ACTIONS := [Soldier.Act.IDLE_CHAT, Soldier.Act.IDLE_LAUGH, Soldier.Act.IDLE_STRETCH, Soldier.Act.IDLE_LOOK]
const CLIPS := ["Talking", "Laughing", "Arm_Stretching", "Rifle_Idle"]
func _physics_process(dt: float) -> void:
	time += dt
	var cycle := int(time / 7.0)
	var local_time := fmod(time, 7.0)
	if cycle >= ACTIONS.size():
		print("RELAXED ACTIONS PASS captured chat, laugh, stretch, armed lookout and recovery")
		get_tree().quit()
		return
	var act: int = ACTIONS[cycle] if local_time < 5.0 else Soldier.Act.IDLE
	proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, act, 0.0, false, false)
	if local_time > 2.0 and local_time < 5.0:
		assert(soldier._activity_clip == "mixamo_activities__" + CLIPS[cycle], "Relaxed action did not use its captured motion")
		assert(soldier._activity_clock > 0.5, "Equipment transition restarted the activity")
		assert(soldier.weapon_stowed == (act != Soldier.Act.IDLE_LOOK), "Activity used the wrong weapon attachment")
		if act == Soldier.Act.IDLE_LOOK:
			var palm := soldier.joint("LeftHand").origin.lerp(soldier.joint("LeftHandMiddle1").origin, 0.65)
			var grip := soldier.weapon.global_transform.affine_inverse() * palm
			assert(grip.distance_to(Vector3(0, 0.06, 0.25)) < 0.045, "Lookout hand missed the rifle grip")
	if local_time > 6.5:
		assert(proxy._native_locomotion and not soldier.weapon_stowed, "Activity failed to recover to armed idle")
	for side in ["Left", "Right"]:
		assert(soldier.joint(side + "Foot").origin.y > 0.06, "Relaxed activity pushed a foot through the floor")
	caption.text = "Captured idle / " + Soldier.Act.keys()[act]
	camera.position = Vector3(-2, 1.4, -3)
	camera.look_at(Vector3(0, 0.8, 0))
