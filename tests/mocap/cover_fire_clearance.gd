extends "res://tests/mocap/gameplay_stances.gd"

func _ready() -> void:
	super._ready()
	var failed := false
	for height in [0.7, 1.0, 1.2, 1.5]:
		proxy.cover_h = height
		proxy.over_wall = true
		var posture := Soldier.Post.CROUCH if height < Cover.KNEEL_MAX else Soldier.Post.STAND
		for frame in 120:
			proxy.pose(1.0 / 60.0, Soldier.Life.ALIVE, posture, Soldier.Act.SHOOT, 0.0, false, true)
		var muzzle := proxy.muzzle_world()
		print("COVER FIRE height=", height, " muzzle=", muzzle.y, " captured=", proxy._native_locomotion)
		var inverse := soldier.weapon.global_transform.affine_inverse()
		var trigger := inverse * soldier.joint("RightHandMiddle1").origin
		var support := inverse * soldier.joint("LeftHand").origin.lerp(soldier.joint("LeftHandMiddle1").origin, 0.65)
		if trigger.distance_to(Vector3(0, -0.035, 0)) > 0.005 or support.distance_to(Vector3(0, 0.055, 0.26)) > 0.005:
			failed = true
		if proxy._native_locomotion or muzzle.y < height + 0.02:
			failed = true
	if failed:
		push_error("Cover firing pose leaves the rifle behind the barrier")
	else:
		print("COVER FIRE CLEARANCE PASS")
	if shot != "" and DisplayServer.get_name() != "headless":
		_surface(Vector3(0, 0.75, -0.7), Vector3(2.5, 1.5, 0.15), Color("7c8790"))
		camera.position = Vector3(-3.2, 2.0, -2.3)
		camera.look_at(Vector3(0, 1.0, -0.3))
		caption.text = "Cover firing / 1.5 m barrier / muzzle %.2f m" % proxy.muzzle_world().y
		var output := shot
		shot = ""
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output)
	get_tree().quit(1 if failed else 0)

func _physics_process(_dt: float) -> void:
	pass
