extends "res://tests/mocap/gameplay_stances.gd"

func _ready() -> void:
	super._ready()
	var driver: RefCounted = proxy.rifle_driver
	for flight_frames in [18, 42, 90]:
		driver.reset()
		for frame in 60: driver.advance(1.0 / 60.0, Vector3.ZERO, false, true)
		assert(driver.request_action("rifle_jump"))
		for frame in flight_frames:
			driver.advance(1.0 / 60.0, Vector3(0, 4.2 - frame * 0.2, 0), false, false)
			assert(driver.action == "rifle_jump", "Jump ended before physical landing")
			if frame >= 5: assert(driver.action_weight > 0.99, "Walking pose leaked into airborne jump")
		for frame in 12: driver.advance(1.0 / 60.0, Vector3.ZERO, false, true)
		assert(driver.action.is_empty(), "Jump did not recover after physical landing")
	print("JUMP TIMING PASS early, normal and delayed landings")
	get_tree().quit()

func _physics_process(_dt: float) -> void: pass
