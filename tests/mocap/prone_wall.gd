extends "res://tests/mocap/gameplay_stances.gd"
var man: Soldier
var barrier: StaticBody3D
var crossed := 0.0
var blocked := false
var opened := false
var wall_angle := 0.0
var facing := 0.0
func _ready() -> void:
	super._ready()
	man = Soldier.new()
	add_child(man)
	man.set_process(false)
	barrier = StaticBody3D.new()
	barrier.collision_layer = Defs.L_COVER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 2.5, 0.2)
	shape.shape = box
	barrier.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = box.size
	mesh.mesh = cube
	barrier.add_child(mesh)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wall-angle="): wall_angle = float(arg.trim_prefix("--wall-angle="))
		if arg.begins_with("--facing="): facing = float(arg.trim_prefix("--facing="))
	man.rotation.y = facing
	proxy.rotation.y = facing
	soldier.rotation.y = facing
	barrier.rotation.y = facing + wall_angle
	barrier.position = Basis(Vector3.UP, facing + wall_angle) * Vector3(0, 1.25, -0.85)
	add_child(barrier)
	caption.text = "Crouch to prone / wall clearance"
func _physics_process(dt: float) -> void:
	if man == null: return
	time += dt
	if time > 4.0: barrier.position.x = 6.0
	man.posture = Soldier.Post.CROUCH if time < 1.0 else Soldier.Post.PRONE
	man.act = Soldier.Act.CRAWL if time > 2.0 and time < 3.0 else Soldier.Act.IDLE
	man._posture_sanity(dt)
	if time > 2.0 and time < 3.0: assert(man.act != Soldier.Act.CRAWL, "Blocked prone retained a crawling pose")
	proxy.pose(dt, Soldier.Life.ALIVE, man.posture, Soldier.Act.IDLE, 0.0, false, false)
	if time >= 1.0 and time < 3.5:
		blocked = man.posture == Soldier.Post.CROUCH
		for name in ["Hips", "Spine", "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]:
			crossed = maxf(crossed, 0.1 - (soldier.joint(name).origin - barrier.position).dot(barrier.basis.z))
	if time > 7.5: opened = man.posture == Soldier.Post.PRONE and proxy._native_prone
	camera.position = Vector3(-3.0, 1.8, 2.8)
	camera.look_at(Vector3(0, 0.65, 0))
	if time > 8.0:
		print("PRONE WALL crossed=", crossed, " blocked=", blocked, " opened=", opened)
		if crossed > 0.01 or not blocked or not opened:
			push_error("Prone entry crossed a wall or failed to resume in clear space")
			get_tree().quit(1)
		else:
			print("PRONE WALL PASS")
			get_tree().quit()
