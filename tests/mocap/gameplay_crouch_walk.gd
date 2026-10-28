extends "res://tests/mocap/gameplay_stances.gd"

func _ready() -> void:
	super._ready()
	if "--swat-units" in OS.get_cmdline_user_args():
		assert(soldier.source.character.scene_file_path == "res://assets/local_mocap/mixamo/Swat.fbx")
		assert(soldier.source.player.has_animation("crouch"))

var moving_crouch_seen := false
var stationary_crouch_seen := false
var reload_seen := false

func _physics_process(dt: float) -> void:
	if proxy == null: return
	time += dt
	var crouching := time >= 2.0 and time < 8.5
	var moving := (time >= 1.0 and time < 4.0) or time >= 7.2
	var reload := time >= 5.0 and time < 7.2
	var speed := 1.2 if moving else 0.0
	var posture := Soldier.Post.CROUCH if crouching else Soldier.Post.STAND
	var action := Soldier.Act.RELOAD if reload else (Soldier.Act.WALK if moving else Soldier.Act.IDLE)
	var travel := Vector3.FORWARD * speed * dt
	proxy.position += travel
	soldier.position += travel
	proxy.pose(dt, Soldier.Life.ALIVE, posture, action, speed, false, false)
	if time > 2.5 and time < 4.0:
		moving_crouch_seen = proxy._native_locomotion and proxy.rifle_driver.crouch_weight > 0.99
	if time > 4.5 and time < 5.0: stationary_crouch_seen = proxy._native_locomotion and proxy.rifle_driver.crouch_drop > 0.115 and proxy.rifle_driver.blend_velocity.length() < 0.01
	if reload: reload_seen = proxy.rifle_driver.action == "reloading"
	for bone in ["Hips", "Head", "LeftFoot", "RightFoot", "LeftHand", "RightHand"]:
		var point := soldier.joint(bone).origin - soldier.position
		if time > 1.0 and previous.has(bone):
			var distance := point.distance_to(previous[bone])
			if distance > max_joint_step:
				max_joint_step = distance
				worst_bone = bone
				worst_time = time
		previous[bone] = point
	caption.text = "Gameplay / " + ("crouch walk" if crouching and moving else ("crouched reload" if reload else ("stationary crouch" if crouching else "standing movement")))
	camera.position = soldier.position + Vector3(-3, 1.5, -3.3)
	camera.look_at(soldier.position + Vector3(0, 0.7, 0))
	if time > 10.0:
		print("GAMEPLAY CROUCH native=", moving_crouch_seen, " stationary_crouch=", stationary_crouch_seen, " reload=", reload_seen, " joint_step=", max_joint_step, " bone=", worst_bone, " time=", worst_time)
		if not moving_crouch_seen or not stationary_crouch_seen or not reload_seen or max_joint_step > 0.15:
			push_error("Gameplay crouch route or transition failed")
			get_tree().quit(1)
			return
		print("GAMEPLAY CROUCH PASS moving, stop, reload, restart and stand")
		get_tree().quit()
