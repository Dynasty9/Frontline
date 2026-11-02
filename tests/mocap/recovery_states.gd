extends "res://tests/mocap/gameplay_stances.gd"

func _physics_process(_dt: float) -> void: pass

func _ready() -> void:
	super._ready()
	for posture in [Soldier.Post.STAND, Soldier.Post.CROUCH, Soldier.Post.PRONE]:
		for speed in [0.0, 1.0]:
			for frame in 90: proxy.pose(1.0 / 60.0, 0, posture, Soldier.Act.IDLE, 0.0, false, false)
			for frame in 60:
				proxy.pose(1.0 / 60.0, 0, posture, Soldier.Act.THROW, speed, false, false)
				var expected := "mixamo_prone__Throw_Grenade" if posture == Soldier.Post.PRONE and soldier.native_player.has_animation("mixamo_prone__Throw_Grenade") else "mixamo_basic_shooter__toss_grenade"
				assert(soldier._activity_clip == expected, "Throw did not use the installed stance-specific toss")
				assert(soldier.grenade_prop != null and soldier.grenade_prop.visible == proxy.nade.visible, "Grenade visibility disagrees with release timing")
				for side in ["Left", "Right"]:
					var foot := soldier.joint(side + "Foot").origin
					assert(Vector2(foot.x, foot.z).length() < (1.5 if posture == Soldier.Post.PRONE else 0.7), "Throw displaced a planted leg")
	for frame in 180: proxy.pose(1.0 / 60.0, 0, Soldier.Post.PRONE, Soldier.Act.CRAWL, 0.45, false, false)
	for side in ["Left", "Right"]:
		var hand := soldier.joint(side + "Hand").origin
		var shoulder := soldier.joint(side + "Arm").origin
		assert(hand.z < shoulder.z - 0.05 and hand.y > 0.0, "Crawl hand folded behind the body or underground")
	for direction in 8:
		proxy.rifle_driver.reset()
		var velocity := Vector3.FORWARD.rotated(Vector3.UP, direction * PI / 4)
		for frame in 180: proxy.rifle_driver.advance(1.0 / 60.0, velocity, true, true)
		for frame in 180: proxy.rifle_driver.advance(1.0 / 60.0, Vector3.ZERO, true, true)
		for side in ["Left", "Right"]:
			for part in ["Foot", "ToeBase"]:
				var index: int = soldier.bones[side + part]
				var sole := soldier.joint(side + part).basis * soldier.target_rest[index].basis.inverse() * Vector3.UP
				assert(sole.y > 0.98, "Stopped crouch retained an inverted ankle or curled toe")
	print("RECOVERY PASS stationary/moving throws, grenade release, crawl reaches, eight directional crouch stops")
	get_tree().quit()
