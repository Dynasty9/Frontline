extends "res://scripts/main.gd"
const AT := Vector3(40, 0, 40)
var subject: Node3D
var started := -1.0
var saw_walk := false
var saw_prone := false
var inspection: Camera3D
var skin_seen := false
var skin_prone := false
var plants := {}
var plant_distance := 0.0
var plant_seconds := 0.0
var previous_joints := {}
var max_joint_step := 0.0
var worst_joint := ""
var worst_time := 0.0
var soldier_script: Script

func _ready() -> void:
	super._ready()
	soldier_script = GameScripts.load_script("res://scripts/game/soldier.gd")
	RenderingServer.frame_post_draw.connect(_measure_skin)

func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world) or not world.loaded or not world.srv: return
	if subject == null:
		world.spawn("structure", {"skind":"tall_wall", "pos":AT + Vector3(0,0,-0.85), "size":Vector3(4,2.5,0.2)})
		subject = world.spawn("soldier", {"utype":"rifleman", "team":0, "pos":AT})
		subject.hold_pos = AT
		subject.next_cover_eval = INF
		subject._sector = Vector3.FORWARD
		started = world.time
		if DisplayServer.get_name() != "headless":
			inspection = Camera3D.new()
			inspection.fov = 40
			world.add_child(inspection)
			inspection.position = AT + Vector3(-3,1.8,2.8)
			inspection.look_at(AT + Vector3(0,0.65,0.4))
			inspection.make_current()
		return
	if inspection != null: inspection.make_current()
	subject.suppression = 80.0 if world.time - started > 1.0 else 20.0
	subject._supp_t = world.time
	subject.next_cover_eval = INF
	saw_walk = saw_walk or subject.act == soldier_script.Act.WALK
	saw_prone = saw_prone or subject.posture == soldier_script.Post.PRONE
	if world.time - started > 8.0:
		var distance := subject.position.distance_to(AT)
		var passed := saw_walk and saw_prone and distance > 0.6 and distance < 1.2
		if inspection != null and args.has("skinned-units"):
			passed = passed and skin_seen and skin_prone and plant_seconds > 0.05 and plant_distance / plant_seconds < 0.005 and max_joint_step < 0.08
		print("GAME BACKSTEP skin=", skin_seen, " captured_prone=", skin_prone, " planted_speed=", plant_distance / maxf(plant_seconds, 0.001), " max_joint_step=", max_joint_step, " joint=", worst_joint, " time=", worst_time)
		print("GAME BACKSTEP walked=", saw_walk, " prone=", saw_prone, " distance=", distance, " pass=", passed)
		if not passed: TestRun.fail()
		TestRun.quit(get_tree())


func _measure_skin() -> void:
	if not is_instance_valid(subject): return
	var dt := get_process_delta_time()
	if subject.model != null and subject.model.skinned != null:
		skin_seen = true
		skin_prone = skin_prone or subject.model._native_prone
		var skin = subject.model.skinned
		for side in 2:
			var prefix := "Left" if side == 0 else "Right"
			var point: Vector3 = skin.joint(prefix + "Foot").origin
			var driver = subject.model.rifle_driver
			var forefoot := clampf((driver.blend_velocity.length() - 1.4) / 2.0, 0.0, 1.0)
			point = point.lerp(skin.joint(prefix + "ToeBase").origin, lerpf(forefoot, 1.0, driver.diagonal_weight))
			var planted: bool = subject.model._native_locomotion and skin.feet[side].locked and subject.model.rifle_driver.plant_weights[side] > 0.99
			if planted and plants.has(side) and subject._prone_back_speed > 0.02:
				plant_distance += Vector2(point.x - plants[side].x, point.z - plants[side].z).length()
				plant_seconds += dt
			if planted: plants[side] = point
			else: plants.erase(side)
		for bone in ["Hips", "Head", "LeftFoot", "RightFoot"]:
			var point: Vector3 = skin.joint(bone).origin
			if previous_joints.has(bone) and world.time - started > 1.0:
				var step := point.distance_to(previous_joints[bone])
				if step > max_joint_step:
					max_joint_step = step
					worst_joint = bone
					worst_time = world.time - started
			previous_joints[bone] = point
