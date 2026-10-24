extends "res://tests/mocap/prone_wall.gd"
var prior := Vector3.ZERO
var filtered_speed := 0.0
var plants := {}
var planted_distance := 0.0
var planted_seconds := 0.0
var joint_previous := {}
var max_step := 0.0
var reached_prone := false
var max_crossing := 0.0
func _ready() -> void:
	super._ready()
	caption.text = "Back away / plant feet / lower into prone"
func _physics_process(dt: float) -> void:
	if man == null: return
	time += dt
	man.posture = Soldier.Post.PRONE if time > 1.0 and man._prepare_prone(dt) else Soldier.Post.CROUCH
	var velocity := (man.position - prior) / dt
	prior = man.position
	man.act = Soldier.Act.WALK if velocity.length() > 0.01 else Soldier.Act.IDLE
	man._posture_sanity(dt)
	proxy.global_transform = man.global_transform
	soldier.global_transform = man.global_transform
	proxy.move_yaw = PI
	filtered_speed = lerpf(filtered_speed, velocity.length(), 1.0 - exp(-dt * 8.0))
	proxy.pose(dt, Soldier.Life.ALIVE, man.posture, man.act, filtered_speed, true, false)
	for name in ["Hips", "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]:
		var point := soldier.joint(name).origin
		if time > 1.0 and joint_previous.has(name): max_step = maxf(max_step, point.distance_to(joint_previous[name]))
		joint_previous[name] = point
		max_crossing = maxf(max_crossing, 0.1 - (point - barrier.position).dot(barrier.basis.z))
	for side in 2:
		var point := soldier.joint("LeftFoot" if side == 0 else "RightFoot").origin
		var planted: bool = proxy._native_locomotion and soldier.feet[side].locked and proxy.rifle_driver.plant_weights[side] > 0.99
		if planted and plants.has(side) and velocity.length() > 0.02:
			planted_distance += Vector2(point.x - plants[side].x, point.z - plants[side].z).length()
			planted_seconds += dt
		if planted: plants[side] = point
		else: plants.erase(side)
	reached_prone = reached_prone or proxy._native_prone
	camera.position = Vector3(-3, 1.8, 2.8)
	camera.look_at(Vector3(0, 0.65, 0.4))
	if time > 8.0:
		print("BACKSTEP position=", man.position, " prone=", reached_prone, " crossing=", max_crossing, " plant_speed=", planted_distance / maxf(planted_seconds, 0.001), " plant_seconds=", planted_seconds, " joint_step=", max_step)
		if not reached_prone or max_crossing > 0.01 or planted_seconds < 0.05 or planted_distance / planted_seconds > 0.002 or max_step > 0.08:
			push_error("Backstep clearance, foot plant or transition continuity failed")
			get_tree().quit(1)
		else:
			print("PRONE BACKSTEP PASS")
			get_tree().quit()
