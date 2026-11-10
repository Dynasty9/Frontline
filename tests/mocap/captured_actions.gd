extends "res://tests/mocap/gameplay_stances.gd"

const CLIPS := ["Climbing_Ladder", "Carrying_Idle", "Carrying_Turn", "Carrying_Walk", "Carrying_Run", "Carrying_Stop", "Being_Carried_Start", "Being_Carried_Loop", "Being_Carried_Stop", "Rifle_Punch", "Rifle_Turn_And_Kick"]
var max_step := 0.0

func _ready() -> void:
	super._ready()
	for x in [-0.3, 0.3]: _surface(Vector3(x, 2.4, -0.3), Vector3(0.04, 4.8, 0.04), Color("69756a"), false)
	for rung in 16: _surface(Vector3(0, 0.2 + rung * 0.3, -0.3), Vector3(0.6, 0.035, 0.035), Color("69756a"), false)
	for name in CLIPS:
		var key: String = "mixamo_activities__" + name
		assert(soldier.native_player.has_animation(key), "Missing new clip: " + key)
		var clip := soldier.native_player.get_animation(key)
		assert(clip.length > 0.1 and clip.get_track_count() > 20)
		for frame in 12:
			soldier.native_player.play(key)
			soldier.native_player.seek(clip.length * frame / 12.0, true)
			for bone in ["Hips", "Head", "LeftFoot", "RightFoot", "LeftHand", "RightHand"]:
				assert(soldier.joint(bone).origin.is_finite(), "Invalid pose in " + key)
	soldier._pose_mode = -1

func _physics_process(dt: float) -> void:
	time += dt
	var melee := time >= 3.0 and time < 3.55
	var climb := time >= 6.0 and time < 6.0 + Soldier.LADDER_SECONDS
	var act := Soldier.Act.MELEE if melee else Soldier.Act.CLIMB if climb else Soldier.Act.IDLE
	soldier.position.y = clampf((time - 6.0) / Soldier.LADDER_SECONDS, 0.0, 1.0) * 4.25
	proxy.position.y = soldier.position.y
	proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, act, 0.0, false, false)
	if melee:
		assert(soldier._activity_clip.ends_with("Rifle_Punch"))
		var palm := soldier.joint("LeftHand").origin.lerp(soldier.joint("LeftHandMiddle1").origin, 0.65)
		assert((soldier.weapon.global_transform.affine_inverse() * palm).distance_to(Vector3(0, 0.055, 0.26)) < 0.045, "Melee lost support grip")
	if climb:
		assert(soldier._activity_clip.ends_with("Climbing_Ladder"))
		assert(soldier.joint("Hips").origin.y - soldier.position.y < 1.2, "Ladder root motion applied twice")
	for bone in ["Hips", "Head", "LeftFoot", "RightFoot", "LeftHand", "RightHand"]:
		var point := soldier.joint(bone).origin - soldier.position
		if time > 1.0 and previous.has(bone) and point.distance_to(previous[bone]) > max_step:
			max_step = point.distance_to(previous[bone])
			worst_bone = bone
			worst_time = time
		previous[bone] = point
	caption.text = "Captured gameplay / " + Soldier.Act.keys()[act]
	camera.position = soldier.position + Vector3(-2.4, 1.6, -3.5)
	camera.look_at(soldier.position + Vector3(0, 0.9, 0))
	if time > 8.5 + Soldier.LADDER_SECONDS:
		assert(proxy._native_locomotion and not soldier.weapon_stowed, "Failed armed recovery")
		if max_step >= 0.18:
			push_error('Captured action snap: %s at %s step %s' % [worst_bone, worst_time, max_step])
			get_tree().quit(1)
			return
		print("CAPTURED ACTIONS PASS 11 clips, melee grip, ladder elevation, armed recovery; max step=", max_step)
		get_tree().quit()

