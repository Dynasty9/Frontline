extends "res://tests/mocap/gameplay_stances.gd"
var previous_joints := {}
var worst := 0.0
var transition_bone := ""
var worst_at := 0.0
var hip_speed := 0.0
var previous_plants := {}
var plant_distance := 0.0
var plant_seconds := 0.0

func _ready() -> void:
	super._ready()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--physics-hz="): Engine.physics_ticks_per_second = int(arg.get_slice("=", 1))
func _physics_process(dt: float) -> void:
	time += dt
	var velocity := Vector3.ZERO
	if time > 1.5 and time < 3.5: velocity = Vector3(0, 0, -1)
	elif time > 5.0 and time < 6.0: velocity = Vector3(1, 0, 0)
	elif time >= 6.0 and time < 7.0: velocity = Vector3(-1, 0, 0)
	soldier.position += velocity * dt
	proxy.rifle_driver.advance(dt, velocity, true, true)
	for bone in ["Hips", "LeftFoot", "RightFoot", "LeftLeg", "RightLeg"]:
		var at := soldier.joint(bone).origin - soldier.global_position
		if previous_joints.has(bone) and time > 1:
			var step := at.distance_to(previous_joints[bone])
			if bone == "Hips": hip_speed = maxf(hip_speed, step / dt)
			if step > worst:
				worst = step
				transition_bone = bone
				worst_at = time
		previous_joints[bone] = at
	for side in 2:
		var bone := "LeftFoot" if side == 0 else "RightFoot"
		var point := soldier.joint(bone).origin
		var planted: bool = soldier.feet[side].locked and proxy.rifle_driver.plant_weights[side] > 0.99
		if planted and previous_plants.has(side) and time > 2.0:
			plant_distance += Vector2(point.x - previous_plants[side].x, point.z - previous_plants[side].z).length()
			plant_seconds += dt
		if planted: previous_plants[side] = point
		else: previous_plants.erase(side)
	camera.position = soldier.global_position + Vector3(2.2, 1.4, -3.4)
	camera.look_at(soldier.global_position + Vector3(0, 0.7, 0))
	if time > 8:
		print("CROUCH PLANTED speed=", plant_distance / maxf(plant_seconds, 0.001))
		print("CROUCH TRANSITIONS step=", worst, " bone=", transition_bone, " time=", worst_at, " hip_speed=", hip_speed)
		assert(hip_speed < 1.0, "Crouch start or reversal snapped the pelvis")
		assert(plant_seconds > 1.0 and plant_distance / plant_seconds < 0.002, "Crouched planted feet slid")
		assert(worst / dt < 4.5, "Crouch transition snapped a leg joint")
		get_tree().quit()

