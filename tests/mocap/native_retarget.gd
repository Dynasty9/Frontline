extends "res://tests/mocap/skinned_demo.gd"

func _ready() -> void:
	super._ready()
	load("res://scripts/game/mixamo_clips.gd").install(soldier, true)
	var checked := 0
	for clip in soldier.native_player.get_animation_list():
		var animation := soldier.native_player.get_animation(clip)
		soldier.native_player.play(clip)
		for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
			soldier.native_player.seek(animation.length * fraction, true)
			for bone in soldier.skeleton.get_bone_count():
				if bone == int(soldier.bones["Hips"]): continue
				var rest := soldier.skeleton.get_bone_rest(bone).origin
				var pose := soldier.skeleton.get_bone_pose_position(bone)
				assert((soldier.skeleton.global_basis * (pose - rest)).length() < 0.00001, "Native clip changed receiving bone length: " + clip)
			checked += 1
	print("NATIVE RETARGET PASS sampled poses=", checked)
	var driver = load("res://scripts/game/rifle_animation_controller.gd").new()
	driver.setup(soldier)
	for frame in 120: driver.advance(1.0 / 60.0, Vector3.ZERO, false, true)
	camera.position = Vector3(-2.3, 1.6, -3.0)
	camera.look_at(Vector3(0, 1.0, 0))
	caption.text = "Receiving skeleton / rifle aiming idle"
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/native-retarget-" + ("swat" if "--swat-units" in OS.get_cmdline_user_args() else "original") + ".png")
	get_tree().quit()

func _physics_process(_dt: float) -> void:
	pass
