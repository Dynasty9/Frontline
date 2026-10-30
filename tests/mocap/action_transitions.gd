extends "res://tests/mocap/gameplay_stances.gd"

func _ready() -> void:
	super._ready()
	var dt := 1.0 / 60.0
	for action in [Soldier.Act.THROW, Soldier.Act.COOK, Soldier.Act.BUILD, Soldier.Act.HEAL, Soldier.Act.CRAWL, Soldier.Act.CLIMB]:
		for frame in 90: proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.SHOOT, 0.0, false, true)
		var previous := soldier.weapon.global_position
		var largest := 0.0
		for frame in 120:
			proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.PRONE if action == Soldier.Act.CRAWL else Soldier.Post.STAND, action, 0.0, false, false)
			assert(soldier.weapon.visible, "Rifle disappeared during an unarmed activity")
			largest = maxf(largest, previous.distance_to(soldier.weapon.global_position))
			previous = soldier.weapon.global_position
		assert(soldier.weapon_stowed, "Activity left the rifle in the working hand")
		assert(soldier.joint("RightHand").origin.distance_to(soldier.weapon.global_position) > 0.15)
		for frame in 90:
			proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.SHOOT, 0.0, false, true)
			largest = maxf(largest, previous.distance_to(soldier.weapon.global_position))
			previous = soldier.weapon.global_position
		assert(not soldier.weapon_stowed)
		assert(soldier.joint("RightHand").origin.distance_to((soldier.weapon.global_transform * soldier.native_socket.affine_inverse()).origin) < 0.01)
		assert(largest < 0.25, "Equipment teleported during stow or draw")
		print("EQUIPMENT action=",action," max_step=",largest)
	for posture in [Soldier.Post.PRONE, Soldier.Post.LEAN_L, Soldier.Post.LEAN_R]:
		for frame in 240: proxy.pose(dt, Soldier.Life.ALIVE, posture, Soldier.Act.SHOOT, 0.0, false, true)
		var released := false
		var hidden := false
		var replaced := false
		for frame in 132:
			proxy.pose(dt, Soldier.Life.ALIVE, posture, Soldier.Act.RELOAD, 0.0, false, false)
			var distance := soldier.joint("LeftHand").origin.distance_to((soldier.weapon.global_transform * proxy.rifle_driver.support_grip).origin)
			released = released or distance > 0.15
			hidden = hidden or not soldier.magazine.mesh.visible
			replaced = replaced or (hidden and soldier.magazine.mesh.visible)
		assert(released and hidden and replaced, "Reload did not release, stow and replace the magazine")
		for frame in 90: proxy.pose(dt, Soldier.Life.ALIVE, posture, Soldier.Act.SHOOT, 0.0, false, true)
		assert(soldier.magazine.mesh.visible)
	for frame in 120:
		proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.DIVE, 0.0, false, false)
		assert(proxy.muzzle_world().y >= 0.035, "Dive drove muzzle underground")
	print("ACTION TRANSITIONS PASS stow/draw, prone/lean reload, dive clearance")
	get_tree().quit()

func _physics_process(_dt: float) -> void:
	pass
