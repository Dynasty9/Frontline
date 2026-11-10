extends Node3D
## A small, repeatable visual and physics test without a battlefield or AI.
## Run this scene for 14 seconds: gait, hits, a wall collision and a tank wreck.

var soldier: SoldierModel
var tank: VehicleModels
var rag: Ragdoll
var wreck: RigidBody3D
var impact := ImpactResponse.new()
var time := 0.0
var stage := 0
var label: Label
var shot := ""
var shot_at := 8.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--shot-at="):
			shot_at = float(arg.trim_prefix("--shot-at="))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.15, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.85, 1.0)
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.8
	light.shadow_enabled = true
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(13, 9, 15)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.0
	_surface(Vector3(0, -0.25, 0), Vector3(28, 0.5, 28), Color(0.22, 0.25, 0.24))
	_surface(Vector3(-3.5, 1.25, -3.5), Vector3(4, 2.5, 0.5), Color(0.4, 0.42, 0.4))
	soldier = SoldierModel.new()
	add_child(soldier)
	soldier.build("rifleman", 0, 37)
	soldier.position = Vector3(-3.5, 0, 3.0)
	tank = VehicleModels.build("tank", 0, 37)
	add_child(tank.root)
	tank.root.position = Vector3(3, 0, 0)
	label = Label.new()
	label.position = Vector2(28, 24)
	label.add_theme_font_size_override("font_size", 25)
	add_child(label)
	print("MOTION_LAB started")


func _surface(at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)


func _physics_process(dt: float) -> void:
	time += dt
	if time < 6.0:
		var speed := 0.65 if time < 3.0 else 1.3
		soldier.position.z -= speed * dt
		soldier.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.WALK, speed, false, false)
	if stage == 0 and time >= 2.0:
		soldier.motion.react(Vector3.RIGHT, 0.8)
		impact.kick(Vector3(0.4, -0.55, 0.0))
		stage = 1
		print("MOTION_LAB live_hit")
	if stage == 1 and time >= 6.0:
		rag = Ragdoll.new()
		add_child(rag)
		var mat := PhysicsMaterial.new()
		mat.friction = 0.9
		mat.bounce = 0.05
		rag.setup(soldier, Vector3(0, 3, -5), 1, mat, 2, 1, Vector3(0, 0, -1.3))
		stage = 2
		print("MOTION_LAB blast")
	if is_instance_valid(rag):
		rag.capture()
		rag.update(dt, 1.0)
	if stage == 2 and time >= 9.0:
		# The same mass-scaled rigid-body response as battlefield wrecks.
		wreck = RigidBody3D.new()
		wreck.mass = 40000.0
		wreck.collision_layer = 2
		wreck.collision_mask = 1
		wreck.continuous_cd = true
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.2, 1.8, 5.5)
		shape.shape = box
		wreck.add_child(shape)
		add_child(wreck)
		wreck.position = Vector3(3, 0.95, 0)
		wreck.apply_impulse(Vector3(0.5, 0.7, -0.6) * wreck.mass, Vector3(1.3, 0, 1.0))
		stage = 3
		print("MOTION_LAB wreck")
	if wreck:
		tank.root.global_transform = wreck.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, -0.9, 0))
	else:
		var rock := impact.step(dt, 9.0)
		tank.root.rotation = Vector3(rock.x, 0, rock.y)
	label.text = "RIFLEMAN / TANK — SHARED MOTION PROTOTYPE\n" + ["Walk and weight transfer", "Directional hit recovery", "Blast → ragdoll → wall", "Heavy wreck settling"][stage]
	if time > 14.0:
		# Collision regression: the blast must not carry the torso through the
		# wall, and neither body may fall through the floor or diverge.
		var torso_pos := soldier.torso.global_position
		if not torso_pos.is_finite() or torso_pos.z < -3.55 or torso_pos.y < -0.3 or torso_pos.y > 2.5:
			push_error("Ragdoll escaped the lab collision bounds: %s" % torso_pos)
			get_tree().quit(1)
			return
		if not wreck.position.is_finite() or wreck.position.y < 0.5 or wreck.position.y > 2.0:
			push_error("Tank wreck failed to settle: %s" % wreck.position)
			get_tree().quit(1)
			return
		print("MOTION_LAB complete")
		get_tree().quit()


func _process(_dt: float) -> void:
	if shot != "" and time >= shot_at and DisplayServer.get_name() != "headless":
		var path := shot
		shot = ""
		await RenderingServer.frame_post_draw
		var picture := get_viewport().get_texture().get_image()
		picture.save_png(path)
		print("MOTION_LAB screenshot ", path)
