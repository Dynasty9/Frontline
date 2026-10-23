extends Node3D
## Repeatable comparison: identical source clips, different visual rigs.

var legacy: SoldierModel
var retargeted: SoldierModel
var actor: MocapCharacter
var retarget: MocapRetarget
var wall: StaticBody3D
var camera: Camera3D
var title: Label
var subtitle: Label
var footer: Label
var time := 0.0
var _built := false
var hit_fired := false
var rag: Ragdoll
var shot := ""
var shot_at := 5.0
var duration := 26.0
var peak_handoff_error := 0.0
var wall_contact := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			shot = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--shot-at="):
			shot_at = float(arg.trim_prefix("--shot-at="))
		elif arg.begins_with("--duration="):
			duration = float(arg.trim_prefix("--duration="))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("111c2a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("bed6ee")
	environment.environment.ambient_light_energy = 0.65
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.light_energy = 2.2
	light.shadow_enabled = true
	add_child(light)
	_surface(Vector3(0, -0.15, 0), Vector3(24, 0.3, 18), Color("263441"))
	wall = _surface(Vector3(0, 1.2, 3), Vector3(2.0, 2.4, 0.35), Color("65717b"))
	wall.visible = false
	for x in [-2.6, 0.0, 2.6]:
		_surface(Vector3(x, 0.005, 0), Vector3(2.1, 0.01, 2.5), Color("354657"), false)
	legacy = SoldierModel.new()
	add_child(legacy)
	legacy.build("rifleman", 0, 37)
	legacy.position.x = 2.6
	retargeted = SoldierModel.new()
	add_child(retargeted)
	retargeted.build("rifleman", 0, 37)
	actor = MocapCharacter.new()
	add_child(actor)
	actor.position.x = -2.6
	if not actor.build():
		get_tree().quit(1)
		return
	retarget = MocapRetarget.new()
	if not retarget.bind(retargeted, actor):
		get_tree().quit(1)
		return
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0.8, 2.7, -10)
	camera.look_at(Vector3(0, 0.95, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.5
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	title = _label(canvas, Vector2(42, 28), 31, Color("edf4fc"))
	title.text = "FRONTLINE  /  MOTION CAPTURE TRIAL"
	subtitle = _label(canvas, Vector2(42, 77), 21, Color("89bfd7"))
	footer = _label(canvas, Vector2(42, 828), 18, Color("c3ceda"))
	footer.text = "MCO Demo Pack v2  •  Godot 4.7.2  •  Local evaluation — source assets excluded from Git"
	for item in [["CURRENT PROCEDURAL", 2.6], ["SAME MODEL + MOCAP", 0.0], ["SKINNED SAMPLE + MOCAP", -2.6]]:
		var label := Label3D.new()
		label.text = item[0]
		label.font_size = 42
		label.pixel_size = 0.003
		label.position = Vector3(item[1], 2.25, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		add_child(label)
	_built = true
	print("MOCAP_DEMO ready")


func _label(parent: Node, at: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _surface(at: Vector3, size: Vector3, color: Color, collide := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1 if collide else 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
	return body


func _physics_process(dt: float) -> void:
	if not _built:
		return
	time += dt
	var speed := 0.0
	var clip := ""
	var posture := Soldier.Post.STAND
	var action := Soldier.Act.SHOOT
	if time < 3.0:
		subtitle.text = "01  /  AIMING IDLE — compare weight, shoulders and hands"
	elif time < 7.0:
		speed = 1.4
		subtitle.text = "02  /  RIFLE WALK — in-place clips, shared speed-driven blending"
	elif time < 11.0:
		speed = 3.0
		subtitle.text = "03  /  RIFLE JOG — hips, knees and upper-body motion"
	elif time < 14.0:
		clip = "crouch"
		posture = Soldier.Post.CROUCH
		speed = 0.8
		action = Soldier.Act.WALK
		subtitle.text = "04  /  CROUCH WALK — sample is unarmed; rifle crouch needs the full set"
	elif time < 17.0:
		clip = "relax"
		action = Soldier.Act.IDLE
		subtitle.text = "05  /  AIM → RELAXED — authored transition"
	elif time < 20.0:
		subtitle.text = "06  /  HIT RESPONSE — procedural reaction layered over the retargeted pose"
		if not hit_fired:
			legacy.motion.react(Vector3.RIGHT, 1.0)
			retargeted.motion.react(Vector3.RIGHT, 1.0)
			hit_fired = true
	else:
		subtitle.text = "07  /  MOCAP → RAGDOLL — exact pose handoff, momentum and wall contact"
		if rag == null and not retargeted.ragdoll_done:
			_start_ragdoll()
	actor.advance(dt, speed, clip)
	actor.weapon.visible = clip != "crouch"
	retargeted.gun.visible = clip != "crouch" and not retargeted.ragdoll_done and not is_instance_valid(rag)
	legacy.pose(dt, Soldier.Life.ALIVE, posture, action, speed, false, false)
	if is_instance_valid(rag):
		for body in rag.bodies.values():
			if wall in (body as RigidBody3D).get_colliding_bodies():
				wall_contact = true
		rag.capture()
		rag.update(dt, 1.0)
	elif not retargeted.ragdoll_done:
		retarget.apply(dt)
	if time > duration:
		if OS.has_environment("FL_DEBUG_MOCAP"):
			print("BASELINE phase=%s thigh=%s target=%s hip=%s" % [legacy.phase, legacy.thigh_l.rotation, legacy.t_thl, legacy.hips.position])
		var p := retargeted.hips.global_position
		if duration > 24.0 and (not wall_contact or not p.is_finite() or p.y < -0.3 or p.z > 3.5):
			push_error("Mocap ragdoll failed collision bounds: %s" % p)
			get_tree().quit(1)
		else:
			print("MOCAP_DEMO complete handoff_error=%.6f wall_contact=%s" % [peak_handoff_error, wall_contact])
			get_tree().quit()


func _start_ragdoll() -> void:
	wall.visible = true
	var before := {}
	for key in HumanoidRig.ORDER:
		before[key] = (retargeted.get(key) as Node3D).global_transform
	rag = Ragdoll.new()
	add_child(rag)
	var material := PhysicsMaterial.new()
	material.friction = 0.85
	material.bounce = 0.03
	rag.setup(retargeted, Vector3(0, 3.2, 5.5), 1, material, 2, 1, Vector3(0, 0, 1.4))
	for body in rag.bodies.values():
		(body as RigidBody3D).contact_monitor = true
		(body as RigidBody3D).max_contacts_reported = 8
	for key in HumanoidRig.ORDER:
		var delta: float = (before[key] as Transform3D).origin.distance_to((rag.bodies[key] as RigidBody3D).global_position)
		peak_handoff_error = maxf(peak_handoff_error, delta)
	assert(peak_handoff_error < 0.001, "Ragdoll snapped away from the animated pose")
	print("MOCAP_DEMO ragdoll handoff_error=", peak_handoff_error)


func _process(_dt: float) -> void:
	if _built and shot != "" and time >= shot_at and DisplayServer.get_name() != "headless":
		var path := shot
		shot = ""
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
		print("MOCAP_DEMO screenshot ", path)

