extends "res://tests/mocap/gameplay_stances.gd"

func _ready() -> void:
	super._ready()
	for gradient in [Vector2(0.2, 0.15), Vector2(-0.2, 0.15), Vector2(0.2, -0.15), Vector2(-0.2, -0.15)]:
		var normal := Vector3(-gradient.x, 1, -gradient.y).normalized()
		soldier.ground_height = func(point: Vector3) -> float: return 0.5 + gradient.x * point.x + gradient.y * point.z
		soldier.ground_normal = func(_point: Vector3) -> Vector3: return normal
		soldier.position.y = 0.5
		for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
			soldier.rotation.y = yaw
			proxy.rifle_driver.reset()
			for frame in 240: proxy.pose(1.0 / 60.0, Soldier.Life.ALIVE, Soldier.Post.CROUCH, Soldier.Act.IDLE, 0.0, false, false)
			for side in ["Left", "Right"]:
				var foot := soldier.joint(side + "Foot")
				var rest: Basis = soldier.target_rest[int(soldier.bones[side + "Foot"])].basis
				var sole_up := foot.basis * rest.inverse() * Vector3.UP
				assert(sole_up.angle_to(normal) < 0.02, "Stationary crouch sole does not follow terrain slope")
	print("CROUCH SLOPE PASS both soles, four headings and four slopes")
	if not shot.is_empty():
		var platform := _surface(Vector3(0, 0.45, 0), Vector3(4, 0.1, 4), Color("526d77"))
		platform.basis = Basis(Quaternion(Vector3.UP, Vector3(0.2, 1, 0.15).normalized()))
		camera.position = Vector3(2.4, 1.5, -3)
		camera.look_at(Vector3(0, 1, 0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
	get_tree().quit()

func _physics_process(_dt: float) -> void:
	pass
