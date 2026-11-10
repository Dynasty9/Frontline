extends "res://scripts/main.gd"

var subject
var tower
var elapsed := 0.0
var previous_position := Vector3.ZERO
var maximum_step := 0.0
var captured := false
var contact_samples := 0
var contact_error := 0.0
var review_camera: Camera3D
var joints := {}
var joint_step := 0.0

func _ready() -> void:
	super._ready()
	RenderingServer.frame_post_draw.connect(capture)

func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world) or not world.loaded: return
	if subject == null:
		world.set_physics_process(false)
		for man in world.soldiers:
			if man.team == 0 and man.utype == "rifleman":
				subject = man
				break
		tower = world.spawn("structure", {"skind": "watchtower", "pos": Vector3(12, 0, 0), "yaw": 0.7, "team": 0, "built": true})
		subject.start_man(tower)
		subject.path = PackedVector3Array()
		subject._path_pending = false
		subject.position = tower.ladder_pos(0.0)
		previous_position = subject.position
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.fov = 45
		camera.position = tower.position + Basis(Vector3.UP, tower.yaw) * Vector3(5, 5.5, 8)
		camera.look_at(tower.position + Vector3(0, 3.2, 0))
		camera.make_current()
		review_camera = camera
	review_camera.position = subject.position + Basis(Vector3.UP, tower.yaw) * Vector3(3, 2, 5)
	review_camera.look_at(subject.position + Vector3(0, 1, 0))
	elapsed += dt
	world.time += dt
	subject._ip_moving = false
	if subject.task_phase < 2: subject._man_tick(dt)
	maximum_step = maxf(maximum_step, subject.position.distance_to(previous_position))
	previous_position = subject.position
	if subject.act == subject.Act.CLIMB and subject.position.y <= tower.position.y + 3.3:
		assert(absf(angle_difference(subject.rotation.y, tower.yaw)) < 0.01)
		assert(subject.position.distance_to(tower.ladder_pos((subject.position.y - tower.position.y) / 3.3)) < 0.01)
	if subject.act == subject.Act.WALK:
		var local: Vector3 = Basis(Vector3.UP, tower.yaw).inverse() * (subject.position - tower.position)
		assert(local.z <= 1.01 and local.y >= 4.24, "Climber stood before reaching platform")
	if elapsed > 6.0:
		assert(subject.task_phase == 2 and subject.position.distance_to(tower.mount_pos()) < 0.01, "Climber missed platform")
		assert(maximum_step < 0.25, "Climber teleported onto platform")
		if contact_samples > 0 and contact_error >= 0.01:
			push_error("Ladder contact missed rung: %s" % contact_error)
			get_tree().quit(1)
			return
		if joint_step >= 0.25:
			push_error("Ladder pose snapped: %s" % joint_step)
			get_tree().quit(1)
			return
		if contact_samples > 0:
			print("LADDER CONTACT samples=", contact_samples, " max error=", contact_error, " max joint step=", joint_step)
		else:
			print("LADDER CONTACT skipped: headless run checks the simulation path only")
		print("LIVE LADDER PASS rotated approach, ascent and platform exit; max step=", maximum_step)
		get_tree().quit()

func capture() -> void:
	if subject != null and subject.model != null and subject.model.skinned != null:
		for bone in ["Hips", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]:
			var point: Vector3 = subject.model.skinned.joint(bone).origin
			if joints.has(bone) and elapsed > 0.3 and point.distance_to(joints[bone]) > joint_step:
				joint_step = point.distance_to(joints[bone])
			joints[bone] = point
	if subject != null and subject.model != null and subject.model.skinned != null and elapsed > 0.5 and elapsed < 3.5:
		var skin = subject.model.skinned
		var phase: float = fmod(skin._activity_clock / skin.native_player.get_animation(skin._activity_clip).length, 1.0)
		for name in skin.ladder_contacts:
			var hand: bool = name.ends_with("Hand")
			var left: bool = name.begins_with("Left")
			var side := "Left" if left else "Right"
			var start := (0.9 if left else 0.4) if hand else (0.8 if left else 0.3)
			var planted_phase := fposmod(phase - start, 1.0)
			if planted_phase < 0.25 or planted_phase > (0.4 if hand else 0.30): continue
			var point: Vector3 = skin.joint(name).origin.lerp(skin.joint(side + ("HandMiddle1" if hand else "ToeBase")).origin, 0.65)
			if not hand: point.y -= 0.045
			var target: Vector3 = tower.position + Basis(Vector3.UP, tower.yaw) * skin.ladder_contacts[name].point
			contact_error = maxf(contact_error, point.distance_to(target))
			contact_samples += 1
	if subject == null or captured or elapsed < 4.55: return
	captured = true
	if OS.has_environment("FL_CAPTURE_LADDER"):
		get_viewport().get_texture().get_image().save_png("res://build/captured-actions/game-ladder.png")

