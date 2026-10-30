extends "res://tests/mocap/skinned_demo.gd"

class UncachedDriver:
	extends "res://scripts/game/rifle_animation_controller.gd"
	func advance(dt: float, velocity: Vector3, crouching: bool, grounded: bool, reload_progress := -1.0) -> void:
		_crouch_phase = INF
		super.advance(dt, velocity, crouching, grounded, reload_progress)

func _ready() -> void:
	super._ready()
	second = SkinnedRifleman.new()
	add_child(second)
	assert(second.build(_animation_clips()))
	for actor in [soldier, second]:
		load("res://scripts/game/mixamo_clips.gd").install(actor, true)
		actor.ground_height = func(point: Vector3) -> float: return 0.15 * point.x
		actor.ground_normal = func(_point: Vector3) -> Vector3: return Vector3(-0.15,1,0).normalized()
	var cached = load("res://scripts/game/rifle_animation_controller.gd").new()
	var reference := UncachedDriver.new()
	cached.setup(soldier)
	reference.setup(second)
	var max_position := 0.0
	var max_joint := 0.0
	var max_basis := 0.0
	var worst := ""
	for frame in 720:
		var velocity := Vector3(0,0,-1.4) if (frame < 90 or frame >= 480) else Vector3.ZERO
		var crouching := frame >= 30 and frame < 600
		for actor in [soldier, second]:
			actor.position += velocity / 60.0
			actor.rotation.y = 0.4 * sin(frame / 90.0) if frame < 180 or frame >= 420 else 0.4 * sin(180.0 / 90.0)
		if frame == 240:
			cached.request_action("reloading")
			reference.request_action("reloading")
		if frame == 450:
			cached.reset()
			reference.reset()
		cached.advance(1.0/60.0, velocity, crouching, true)
		reference.advance(1.0/60.0, velocity, crouching, true)
		for bone in soldier.skeleton.get_bone_count():
			max_joint = maxf(max_joint, soldier.world_pose(bone).origin.distance_to(second.world_pose(bone).origin))
			var actual := soldier.skeleton.get_bone_pose(bone)
			var expected := second.skeleton.get_bone_pose(bone)
			max_position = maxf(max_position, (soldier.skeleton.global_basis * (actual.origin - expected.origin)).length())
			for axis in 3:
				var difference := actual.basis[axis].distance_to(expected.basis[axis])
				if difference > max_basis:
					max_basis = difference
					worst = str(frame) + ":" + soldier.skeleton.get_bone_name(bone)
	print("CROUCH CACHE positions=", max_position, " bases=", max_basis, " worst=", worst, " world_joint=", max_joint)
	# World-space retarget roundoff can change IK orientation slightly; bound skin joints to 0.5 mm and axes to 0.1 degree.
	assert(max_position < 0.00002 and max_joint < 0.0005 and max_basis < 0.00175, "Crouch cache changed poses across movement, turn, reload or reset")
	print("CROUCH CACHE PASS 720 slope/turn/movement/reload/reset/stance samples")
	get_tree().quit()

func _physics_process(_dt: float) -> void: pass
