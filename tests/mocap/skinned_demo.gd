extends Node3D

var soldier: SkinnedRifleman
var camera: Camera3D
var caption: Label
var time := 0.0
var stage := 0
var travel_speed := 0.0
var ready_to_run := false
var duration := 34.0
var shot := ""
var shot_at := 2.0
var wall: StaticBody3D
var second: SkinnedRifleman

func _ready() -> void:
	Engine.physics_ticks_per_second = 120
	Engine.max_physics_steps_per_frame = 12
	Settings.no_save = true
	Settings.apply_preset("ultra", false)
	Settings.v["dof"] = false
	Settings.v["perf"] = 0
	Settings.apply_global()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="): duration = float(arg.trim_prefix("--duration="))
		if arg.begins_with("--screenshot="): shot = arg.trim_prefix("--screenshot=")
		if arg.begins_with("--shot-at="): shot_at = float(arg.trim_prefix("--shot-at="))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("111925")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b6cde1")
	env.environment.ambient_light_energy = 0.35
	env.environment.ssao_enabled = true
	env.environment.ssao_radius = 0.4
	env.environment.ssao_intensity = 1.2
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 130, 0)
	fill.light_color = Color("8db9e4")
	fill.light_energy = 0.6
	add_child(fill)
	_surface(Vector3(0,-0.12,-10),Vector3(50,0.24,70),Color("353c43"))
	soldier = SkinnedRifleman.new()
	add_child(soldier)
	if not soldier.build(_animation_clips()):
		get_tree().quit(1)
		return
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 40
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var title := Label.new()
	title.position = Vector2(42,28)
	title.add_theme_font_size_override("font_size",30)
	title.text = "FRONTLINE / SKINNED RIFLEMAN"
	canvas.add_child(title)
	caption = Label.new()
	caption.position = Vector2(42,76)
	caption.add_theme_font_size_override("font_size",22)
	caption.add_theme_color_override("font_color",Color("8cc4dd"))
	canvas.add_child(caption)
	var footer := Label.new()
	footer.position = Vector2(42,840)
	footer.text = "Mixamo character • MCO rifle motion • Rest-space retargeting + contact IK + skeletal physics"
	footer.add_theme_font_size_override("font_size",17)
	canvas.add_child(footer)
	ready_to_run = true
	print("SKIN_DEMO ready")

func _surface(at: Vector3, size: Vector3, color: Color, collide := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1 if collide else 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	if not collide: mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material_override = material
	if size.x > 40:
		var shader := Shader.new()
		shader.code = "shader_type spatial; varying vec3 wp; void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;} void fragment(){vec2 g=wp.xz/2.0;vec2 d=abs(fract(g-0.5)-0.5)/max(fwidth(g),vec2(0.0001));float line=1.0-clamp(min(d.x,d.y),0.0,1.0);ALBEDO=mix(vec3(0.035,0.045,0.055),vec3(0.07,0.085,0.10),line);ROUGHNESS=0.95;SPECULAR=0.2;}"
		var grid := ShaderMaterial.new()
		grid.shader = shader
		mesh.material_override = grid
	body.add_child(mesh)
	add_child(body)
	return body

func _physics_process(dt: float) -> void:
	if not ready_to_run: return
	time += dt
	var speed := 0.0
	caption.text = "01 / AIMING — stable trigger-hand socket and support-hand IK"
	if time >= 4 and time < 9:
		speed = 1.4
		caption.text = "02 / ADVANCE — shared rifle walk, planted feet and original skin weights"
	elif time >= 9 and time < 13:
		speed = 3.0
		caption.text = "03 / JOG — full-body motion with grounded steps"
	elif time >= 13 and time < 19:
		caption.text = "04 / TAKING HITS — directional recovery while maintaining the rifle grip"
		if stage == 0 and time > 14:
			soldier.hit(Vector3.RIGHT)
			stage = 1
		if stage == 1 and time > 16:
			soldier.hit(Vector3.BACK, 1.3)
			stage = 2
	elif time >= 19 and time < 26:
		caption.text = "05 / FATAL HIT — same skinned body, jointed ragdoll and dropped rifle"
		if not soldier.dead:
			soldier.kill(Vector3(0.1,0.0,0.8), 0)
	elif time >= 26:
		caption.text = "06 / BLAST — momentum, wall contact and settling"
		if second == null:
			second = SkinnedRifleman.new()
			add_child(second)
			second.build()
			second.position = soldier.position + Vector3(-2,0,0)
			second.pose(dt,0)
			second.last_velocity = Vector3.ZERO
			wall = _surface(second.position+Vector3(0,1.2,2.3),Vector3(3,2.4,0.35),Color("58616a"))
		if time > 27 and not second.dead:
			second.kill(Vector3(0,2.6,5.0))
		second.pose(dt,0)
		second.capture_motion(dt)
	travel_speed = move_toward(travel_speed, speed, dt * 3.0)
	if soldier.dead: travel_speed = 0.0
	soldier.position.z -= travel_speed * dt
	soldier.pose(dt,travel_speed)
	soldier.capture_motion(dt)
	var focus := soldier.position + Vector3(0,0.95,0)
	if second != null: focus = second.position + Vector3(0,0.85,0.8)
	camera.position = focus + Vector3(2.7,1.0,-4.2)
	camera.look_at(focus)
	if time > duration:
		if soldier.foot_error >= 0.01 or soldier.max_grip_error >= 0.015:
			push_error("Contact checks failed: foot=%s grip=%s" % [soldier.foot_error, soldier.max_grip_error])
			get_tree().quit(1)
			return
		print("SKIN_DEMO complete grip_error=",soldier.max_grip_error," foot_error=",soldier.foot_error)
		if second != null:
			print("SKIN_DEMO ragdoll contacts=",second.ragdoll.contact_count)
		get_tree().quit()

func _process(_dt: float) -> void:
	if ready_to_run and shot != "" and time >= shot_at and DisplayServer.get_name() != "headless":
		var path := shot
		shot = ""
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
		print("SKIN_DEMO screenshot ",path)


func _animation_clips() -> Dictionary:
	return MocapCharacter.CLIPS
