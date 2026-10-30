extends "res://tests/mocap/skinned_demo.gd"

class ReferenceDriver:
	extends "res://scripts/game/rifle_animation_controller.gd"
	func _blend_foot_paths() -> void:
		var saved := crouch_weight
		crouch_weight = 0.0
		super._blend_foot_paths()
		crouch_weight = saved

func _ready() -> void:
	super._ready()
	second = SkinnedRifleman.new()
	add_child(second)
	assert(second.build(_animation_clips()))
	for actor in [soldier, second]: load("res://scripts/game/mixamo_clips.gd").install(actor, true)
	var optimized = load("res://scripts/game/rifle_animation_controller.gd").new()
	var reference := ReferenceDriver.new()
	optimized.setup(soldier)
	reference.setup(second)
	var max_position := 0.0
	var max_basis := 0.0
	for frame in 360:
		var velocity := Vector3.FORWARD.rotated(Vector3.UP, TAU * frame / 360.0) * 1.4
		for actor in [soldier, second]: actor.position += velocity / 60.0
		var crouching := frame >= 40 and frame < 260
		optimized.advance(1.0 / 60.0, velocity, crouching, true)
		reference.advance(1.0 / 60.0, velocity, crouching, true)
		for bone in soldier.skeleton.get_bone_count():
			var actual := soldier.skeleton.get_bone_pose(bone)
			var expected := second.skeleton.get_bone_pose(bone)
			max_position = maxf(max_position, actual.origin.distance_to(expected.origin))
			for axis in 3: max_basis = maxf(max_basis, actual.basis[axis].distance_to(expected.basis[axis]))
	if max_position >= 0.00002 or max_basis >= 0.00002:
		push_error("Crouch comparison position=%s basis=%s" % [max_position, max_basis])
		get_tree().quit(1)
		return
	print("CROUCH FOOT PATHS PASS 360 turning/stance samples position=", max_position, " basis=", max_basis)
	get_tree().quit()

func _physics_process(_dt: float) -> void: pass
