extends "res://tests/mocap/gameplay_stances.gd"

func _ready() -> void:
	super._ready()
	var driver = proxy.rifle_driver
	for sample in 12:
		driver.advance(1.0 / 60.0, Vector3(0, 0, -1.4), false, true)
		var before: Array[Transform3D] = []
		for bone in soldier.skeleton.get_bone_count(): before.append(soldier.skeleton.get_bone_pose(bone))
		soldier.source.player.play("crouch", 0.0)
		soldier.source._clip = "crouch"
		soldier.source.player.seek(soldier.source.player.get_animation("crouch").length * sample / 12.0, true)
		soldier.source.advance(0.0, 1.4, "crouch")
		soldier._retarget_source()
		var expected: Array[Transform3D] = []
		for bone in before.size(): expected.append(soldier.skeleton.get_bone_pose(bone))
		for bone in before.size(): soldier.skeleton.set_bone_pose(bone, before[bone])
		soldier._retarget_source(driver.upper)
		for bone in before.size():
			var wanted: Transform3D = before[bone] if driver.upper[bone] else expected[bone]
			assert(soldier.skeleton.get_bone_pose(bone).is_equal_approx(wanted), "Selective retarget changed a retained pose")
	print("LOWER RETARGET PASS 12 crouch phases, equivalent legs and untouched upper body")
	get_tree().quit()

func _physics_process(_dt: float) -> void: pass
