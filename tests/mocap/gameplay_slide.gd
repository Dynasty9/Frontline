extends "res://tests/mocap/gameplay_stances.gd"

var checked := false
var min_foot := INF
var max_foot := -INF

func _ready() -> void:
	super._ready()
	if "--swat-units" not in OS.get_cmdline_user_args(): proxy.rifle_driver = null

func _physics_process(dt: float) -> void:
	if proxy == null: return
	time += dt
	var cycle := fmod(time, 5.0)
	var sliding := cycle >= 1.0 and cycle < 3.0
	var action := Soldier.Act.SLIDE if sliding else Soldier.Act.WALK
	proxy.position.z -= 2.0 * dt
	soldier.position.z = proxy.position.z
	var posture := Soldier.Post.STAND if time < 5.0 else Soldier.Post.CROUCH
	proxy.pose(dt, Soldier.Life.ALIVE, posture, action, 2.0, false, false)
	for bone in ["Hips", "Head", "LeftFoot", "RightFoot", "LeftHand", "RightHand"]:
		var point := soldier.joint(bone).origin - soldier.position
		if time > 0.5 and previous.has(bone) and point.distance_to(previous[bone]) > max_joint_step:
			max_joint_step = point.distance_to(previous[bone])
			worst_bone = bone
			worst_time = time
		previous[bone] = point
	if cycle > 2.0 and cycle < 3.0:
		checked = true
		for bone in ["LeftFoot", "RightFoot"]:
			var height := soldier.joint(bone).origin.y
			min_foot = minf(min_foot, height)
			max_foot = maxf(max_foot, height)
	caption.text = "Gameplay / walk - feet-first slide - walk"
	camera.position = soldier.position + Vector3(-3, 1.5, -3.3)
	camera.look_at(soldier.position + Vector3(0, 0.65, 0))
	if time > 10.0:
		print("GAMEPLAY SLIDE feet=",min_foot,"..",max_foot," joint_step=",max_joint_step," bone=",worst_bone," time=",worst_time)
		if not checked or min_foot < 0.09 or max_foot > 0.3 or max_joint_step > 0.15:
			push_error("Slide boot height or transition failed")
			get_tree().quit(1)
			return
		print("GAMEPLAY SLIDE PASS boot clearance, height and transitions")
		get_tree().quit()
