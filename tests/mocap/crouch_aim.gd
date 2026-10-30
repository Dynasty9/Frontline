extends "res://tests/mocap/skinned_demo.gd"

func _ready() -> void:
	super._ready()
	second = SkinnedRifleman.new()
	add_child(second)
	assert(second.build(_animation_clips()))
	var drivers: Array[RefCounted] = []
	for actor in [soldier, second]:
		load("res://scripts/game/mixamo_clips.gd").install(actor, true)
		var driver: RefCounted = load("res://scripts/game/rifle_animation_controller.gd").new()
		driver.setup(actor)
		drivers.append(driver)
	for mode in 5:
		var velocity: Vector3 = [Vector3.ZERO, Vector3(0, 0, -1.4), Vector3(1.4, 0, 0), Vector3.ZERO, Vector3.ZERO][mode]
		if mode == 3:
			for driver in drivers: driver.request_action("reloading")
		for frame in 120:
			drivers[0].advance(1.0 / 60.0, velocity, false, true)
			drivers[1].advance(1.0 / 60.0, velocity, true, true)
			if mode == 4:
				for driver in drivers: driver.overlay_reload(float(frame) / 119.0)
			var alignment := soldier.weapon.global_basis.z.normalized().dot(second.weapon.global_basis.z.normalized())
			if alignment < 0.999:
				push_error("Crouch pelvis changed rifle aim: " + str(alignment))
				get_tree().quit(1)
				return
	print("CROUCH AIM PASS idle, forward, lateral, reload, reload overlay and posture transition")
	get_tree().quit()

func _physics_process(_dt: float) -> void:
	pass
