extends "res://tests/mocap/skinned_demo.gd"

var fallback: SoldierModel
var last_mode := -1
var switch_delta := 0.0
var last_hip := Vector3.ZERO
var step_checked := false
var hit_stances := 0

func _ready() -> void:
	super._ready()
	duration = 14.0
	fallback = SoldierModel.new()
	add_child(fallback)
	fallback.build("rifleman", 0, 37)
	fallback.visible = false
	soldier.bind_procedural(fallback)
	soldier.ground_height = _height
	_surface(Vector3(1, 0.06, -5), Vector3(2, 0.12, 20), Color("526d77"))

func _height(at: Vector3) -> float:
	return 0.12 if at.x > 0 and at.x < 2 else 0.0

func _physics_process(dt: float) -> void:
	if not ready_to_run: return
	time += dt
	var mode := 0
	var posture := Soldier.Post.STAND
	var speed := 0.0
	caption.text = "CONTACT TEST / one boot on a 12 cm step"
	if time >= 4 and time < 6:
		mode = 1
		posture = Soldier.Post.CROUCH
		caption.text = "STANCE TRANSITION / rifle kneel"
	elif time >= 6 and time < 8:
		mode = 1
		posture = Soldier.Post.PRONE
		caption.text = "STANCE TRANSITION / prone rifle pose"
	elif time >= 8 and time < 10:
		caption.text = "STANCE TRANSITION / return to captured aiming"
	elif time >= 10:
		speed = 1.4
		caption.text = "CONTACT TEST / walking along the step"
	soldier.position.z -= speed * dt
	soldier.position.y = 0.06
	fallback.position = soldier.position
	if (time >= 4.8 and hit_stances == 0) or (time >= 6.8 and hit_stances == 1):
		soldier.hit(Vector3.RIGHT if hit_stances == 0 else Vector3.LEFT, 1.0)
		hit_stances += 1
	fallback.pose(dt, Soldier.Life.ALIVE, posture, Soldier.Act.SHOOT, speed, false, false)
	if mode == 1: soldier.pose_procedural(fallback, dt, posture)
	else: soldier.pose(dt, speed)
	var hip := soldier.joint("Hips").origin
	if last_mode >= 0 and mode != last_mode:
		switch_delta = maxf(switch_delta, hip.distance_to(last_hip))
	last_mode = mode
	last_hip = hip
	if not step_checked and time > 2:
		var difference := absf(soldier.joint("LeftFoot").origin.y - soldier.joint("RightFoot").origin.y)
		if difference < 0.10:
			push_error("Independent foot heights were not applied: " + str(difference))
			get_tree().quit(1)
		step_checked = true
	camera.position = soldier.position + Vector3(3, 2.6, -4.6)
	camera.look_at(soldier.position + Vector3(0, 0.8, 0))
	if time >= duration:
		print("STANCE_CONTACTS foot=", soldier.foot_error, " grip=", soldier.max_grip_error, " switch_delta=", switch_delta)
		if soldier.foot_error > 0.015 or soldier.max_grip_error > 0.015 or switch_delta > 0.12:
			push_error("Stance/contact regression")
			get_tree().quit(1)
		else: get_tree().quit()
