extends "res://scripts/main.gd"
var subject
var camera: Camera3D
var elapsed := 0.0
var next_shot := 0.0
var shots := 0
var vault_frames := 0
var continued := false
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
		subject.position = Vector3(3,0,-4)
		subject.path = PackedVector3Array([Vector3(3,0,-10)])
		subject.path_i = 0
		subject._path_pending = false
		subject._stuck_p = subject.position
		subject._ip_moving = false
		subject.at_cover = false
		subject.posture = 0
		camera = Camera3D.new()
		camera.fov = 43
		world.add_child(camera)
		camera.position = Vector3(-1,2,-5)
		camera.look_at(Vector3(3,0.8,-7))
		camera.make_current()
	elapsed += dt
	world.time += dt
	subject.reload_t = 0
	subject._ip_moving = false
	var moving: bool = subject._move_tick(dt,1.4)
	subject._choose_act(moving)
	if subject.vaulting: vault_frames += 1
	continued = continued or (subject._view_vault and not subject.vaulting)
	if elapsed > 9.0:
		assert(vault_frames > 0 and subject.position.z < -9.4, "Actual soldier did not traverse low wall")
		assert(continued and not subject._view_vault and subject._view_vault_lift < 0.001, "Visual vault did not continue and settle")
		print("LIVE VAULT PASS frames=",vault_frames," end=",subject.position)
		get_tree().quit()
func capture() -> void:
	if subject == null or elapsed < next_shot: return
	next_shot = elapsed + 0.25
	if OS.has_environment("FL_CAPTURE_VAULT"):
		get_viewport().get_texture().get_image().save_png("res://build/context-audit/vault_%03d.png" % shots)
	shots += 1
