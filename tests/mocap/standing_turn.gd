extends "res://tests/mocap/skinned_demo.gd"

func _ready() -> void:
	super._ready()
	if not ready_to_run:
		return
	preload("res://scripts/game/mixamo_clips.gd").install(soldier, true)
	var driver = preload("res://scripts/game/rifle_animation_controller.gd").new()
	driver.setup(soldier)
	var seen := [false, false]
	for frame in 90:
		if frame >= 30 and frame < 45:
			soldier.rotation.y += PI / 15.0
		driver.advance(1.0 / 30.0, Vector3.ZERO, false, true)
		if driver.pivot_foot >= 0:
			seen[driver.pivot_foot] = true
			assert(soldier.feet[1 - driver.pivot_foot].locked, "one boot supports each turn step")
	assert(seen.all(func(v): return v) and driver.pivot_foot == -1, "both boots step and then settle")
	print("STANDING TURN PASS")
	get_tree().quit()

func _physics_process(_dt: float) -> void: pass
