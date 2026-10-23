extends "res://tests/mocap/skinned_demo.gd"

var proxy: SoldierModel
var max_joint_step := 0.0
var previous: Dictionary = {}
var minimum_head := INF
var worst_bone := ""
var worst_time := 0.0
var captured_prone_checked := false

func _ready() -> void:
	super._ready()
	proxy = SoldierModel.new()
	add_child(proxy)
	proxy.build("rifleman", 0, 4)
	soldier.bind_procedural(proxy)
	proxy.root.hide()
	proxy.skinned = soldier
	load("res://scripts/game/mixamo_clips.gd").install(soldier, true)
	proxy.rifle_driver = load("res://scripts/game/rifle_animation_controller.gd").new()
	proxy.rifle_driver.setup(soldier)

func _physics_process(dt: float) -> void:
	if proxy == null: return
	time += dt
	var posture := Soldier.Post.STAND
	if time >= 2.0 and time < 4.0: posture = Soldier.Post.CROUCH
	elif time >= 4.0 and time < 7.0: posture = Soldier.Post.PRONE
	elif time >= 7.2 and time < 7.4: posture = Soldier.Post.CROUCH
	elif time >= 7.4 and time < 8.2: posture = Soldier.Post.PRONE
	proxy.pose(dt, Soldier.Life.ALIVE, posture, Soldier.Act.SHOOT, 0.0, false, false)
	caption.text = "Gameplay stance / " + ["standing", "kneeling", "prone"][posture]
	for bone in ["Hips", "Head", "LeftFoot", "RightFoot", "LeftHand", "RightHand"]:
		var point := soldier.joint(bone).origin
		if time > 1.0 and previous.has(bone):
			var distance := point.distance_to(previous[bone])
			if distance > max_joint_step:
				max_joint_step = distance
				worst_bone = bone
				worst_time = time
		previous[bone] = point
	if time > 2.8 and time < 4.0:
		assert(proxy._native_locomotion, "Stationary crouch lost its captured rifle pose")
		assert(soldier.joint("Hips").origin.y < 0.65, "Stationary crouch did not settle into cover")
		var palm := soldier.joint("LeftHand").origin.lerp(soldier.joint("LeftHandMiddle1").origin, 0.65)
		var contact := soldier.weapon.global_transform.affine_inverse() * palm
		assert(contact.y > 0.04 and contact.y < 0.08 and contact.z > 0.20 and contact.z < 0.30, "Crouched support hand missed the handguard")
	if time > 6.5 and time < 7.0:
		assert(proxy._native_prone and soldier.joint("Head").origin.y > 0.23)
		captured_prone_checked = true
	minimum_head = minf(minimum_head, soldier.joint("Head").origin.y)
	camera.position = Vector3(-3.0, 1.5, -3.3)
	camera.look_at(Vector3(0, 0.65, 0))
	if time > 10.0:
		print("GAMEPLAY STANCES maximum joint step=", max_joint_step, " minimum head=", minimum_head, " bone=", worst_bone, " time=", worst_time)
		if max_joint_step > 0.15 or minimum_head < 0.1 or not captured_prone_checked:
			push_error("Gameplay stance discontinuity or head penetration")
			get_tree().quit(1)
			return
		print("GAMEPLAY STANCES PASS including interrupted transitions")
		get_tree().quit()
