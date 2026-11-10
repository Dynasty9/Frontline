extends "res://scripts/main.gd"

var subject
var tower
var elapsed := 0.0
var previous_position := Vector3.ZERO
var maximum_step := 0.0
var captured := false

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
		camera.fov = 35
		camera.position = tower.position + Vector3(7, 4.2, 9)
		camera.look_at(tower.position + Vector3(0, 2.6, 0))
		camera.make_current()
	elapsed += dt
	world.time += dt
	subject._ip_moving = false
	if subject.task_phase < 2: subject._man_tick(dt)
	maximum_step = maxf(maximum_step, subject.position.distance_to(previous_position))
	previous_position = subject.position
	if subject.act == subject.Act.CLIMB:
		assert(absf(angle_difference(subject.rotation.y, tower.yaw)) < 0.01)
		assert(subject.position.distance_to(tower.ladder_pos((subject.position.y - tower.position.y) / 4.25)) < 0.01)
	if elapsed > 6.0:
		assert(subject.task_phase == 2 and subject.position.distance_to(tower.mount_pos()) < 0.01, "Climber missed platform")
		assert(maximum_step < 0.25, "Climber teleported onto platform")
		print("LIVE LADDER PASS rotated approach, ascent and platform exit; max step=", maximum_step)
		get_tree().quit()

func capture() -> void:
	if subject == null or captured or elapsed < 2.2: return
	captured = true
	if OS.has_environment("FL_CAPTURE_LADDER"):
		get_viewport().get_texture().get_image().save_png("res://build/captured-actions/game-ladder.png")

