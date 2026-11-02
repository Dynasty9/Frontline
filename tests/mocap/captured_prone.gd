extends "res://tests/mocap/gameplay_stances.gd"

func _physics_process(_dt: float) -> void: pass

func _ready() -> void:
	super._ready()
	var previous := Vector3.ZERO
	var traveled := 0.0
	for frame in 600:
		var moving := frame >= 180 and frame < 420
		proxy.pose(1.0 / 60.0, Soldier.Life.ALIVE, Soldier.Post.PRONE, Soldier.Act.CRAWL if moving else Soldier.Act.IDLE, 0.45 if moving else 0.0, false, false)
		assert(proxy._native_prone, "Prone fell back to procedural motion")
		assert(not soldier.weapon_stowed, "Captured rifle crawl incorrectly slung the weapon")
		var hand := soldier.joint("LeftHand").origin
		if frame > 240 and frame < 400: traveled += hand.distance_to(previous)
		previous = hand
		if frame == 360: assert(proxy.rifle_driver.prone_clip.ends_with("Prone_Forward"), "Crawl loop was not selected")
		if frame == 590: assert(proxy.rifle_driver.prone_clip.ends_with("Prone_Idle"), "Crawl did not settle into idle")
		assert(soldier.joint("Head").origin.y > 0.1, "Prone head penetrated the ground")
	assert(traveled > 0.05, "Crawl was frozen at a single pose")
	proxy.move_yaw = PI
	proxy.pose(1.0 / 60.0, 0, Soldier.Post.PRONE, Soldier.Act.CRAWL, 0.45, true, false)
	assert(proxy.rifle_driver.prone_clip.ends_with("Prone_Backwards_Start"), "Backward crawl skipped its captured start")
	for frame in 240: proxy.pose(1.0 / 60.0, 0, Soldier.Post.PRONE, Soldier.Act.CRAWL, 0.45, true, false)
	assert(proxy.rifle_driver.prone_clip.ends_with("Moving_Backward_In_Prone_Position"), "Backward crawl used forward or procedural motion")
	proxy.pose(1.0 / 60.0, 0, Soldier.Post.PRONE, Soldier.Act.IDLE, 0.0, false, false)
	assert(proxy.rifle_driver.prone_clip.ends_with("Prone_Backwards_Stop"), "Backward crawl skipped its stop")
	for frame in 180: proxy.pose(1.0 / 60.0, 0, Soldier.Post.PRONE, Soldier.Act.IDLE, 0.0, false, false)
	assert(proxy.rifle_driver.prone_clip.ends_with("Prone_Idle"))
	for frame in 120: proxy.pose(1.0 / 60.0, 0, Soldier.Post.PRONE, Soldier.Act.SHOOT, 0.0, false, true)
	assert(proxy.rifle_driver.prone_clip.ends_with("Prone_Firing_Rifle"), "Prone firing did not use its captured clip")
	for frame in 120: proxy.pose(1.0 / 60.0, 0, Soldier.Post.PRONE, Soldier.Act.RELOAD, 0.0, false, false)
	assert(proxy.rifle_driver.prone_clip.ends_with("Prone_Reloading"), "Prone reload did not use its captured clip")
	for frame in 36: proxy.pose(1.0 / 60.0, 0, Soldier.Post.PRONE, Soldier.Act.THROW, 0.0, false, false)
	assert(soldier._activity_clip == "mixamo_prone__Throw_Grenade", "Prone throw used a standing overlay")
	proxy.pose(1.0 / 60.0, 0, Soldier.Post.PRONE, Soldier.Act.IDLE, 0.0, false, false)
	assert(proxy.rifle_driver.prone_clip.ends_with("Prone_Idle"), "Throw recovery replayed the kneel-to-prone entry")
	proxy.pose(1.0 / 60.0, 0, Soldier.Post.CROUCH, Soldier.Act.IDLE, 0.0, false, false)
	assert(proxy.rifle_driver.state == "Prone recovery", "Get-up did not use captured recovery")
	for frame in 240: proxy.pose(1.0 / 60.0, 0, Soldier.Post.CROUCH, Soldier.Act.IDLE, 0.0, false, false)
	assert(proxy.rifle_driver.prone_clip.is_empty(), "Recovery never returned control to locomotion")
	print("CAPTURED PRONE PASS entry, moving rifle crawl, stop to idle, animated limbs")
	get_tree().quit()
