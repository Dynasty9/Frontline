extends "res://tests/mocap/gameplay_stances.gd"

func _ready() -> void:
	super._ready()
	for gradient in [Vector2.ZERO, Vector2(0.2, 0.15), Vector2(-0.2, -0.15)]:
		var normal := Vector3(-gradient.x, 1, -gradient.y).normalized()
		soldier.ground_height = func(point: Vector3) -> float: return gradient.x * point.x + gradient.y * point.z
		soldier.ground_normal = func(_point: Vector3) -> Vector3: return normal
		for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
			soldier.rotation.y = yaw
			proxy.rotation.y = yaw
			for posture in [Soldier.Post.LEAN_L, Soldier.Post.LEAN_R]:
				for frame in 120: proxy.pose(1.0 / 60.0, Soldier.Life.ALIVE, posture, Soldier.Act.SHOOT, 0.0, false, true)
				for side in ["Left", "Right"]:
					var foot := soldier.joint(side + "Foot")
					var rest: Basis = soldier.target_rest[int(soldier.bones[side + "Foot"])].basis
					assert((foot.basis * rest.inverse() * Vector3.UP).angle_to(normal) < 0.02)
					var toe := soldier.joint(side + "ToeBase").origin
					var clearance: float = toe.y - soldier.ground_height.call(toe)
					assert(clearance >= -0.002 and clearance < 0.025, "Cover toe misses terrain: " + str(clearance))
	var previous := soldier.joint("LeftFoot").origin
	for speed in [1.4, 0.0]:
		for frame in 120:
			proxy.pose(1.0 / 60.0, Soldier.Life.ALIVE, Soldier.Post.LEAN_R, Soldier.Act.SHOOT, speed, false, true)
			var foot := soldier.joint("LeftFoot").origin
			assert(foot.distance_to(previous) < 0.12, "Cover contact snapped on movement change")
			previous = foot
		assert(is_equal_approx(soldier.cover_weight, 0.0 if speed > 0.0 else 1.0))
	print("COVER CONTACTS PASS both feet, both lean sides, four headings, slopes and movement release")
	get_tree().quit()

func _physics_process(_dt: float) -> void:
	pass
