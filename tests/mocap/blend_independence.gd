extends "res://tests/mocap/skinned_demo.gd"

func _ready() -> void:
	super._ready()
	load("res://scripts/game/mixamo_clips.gd").install(soldier, true)
	var first = load("res://scripts/game/rifle_animation_controller.gd").new()
	first.setup(soldier)
	var other := SkinnedRifleman.new()
	add_child(other)
	assert(other.build())
	other.position.x = 4.0
	load("res://scripts/game/mixamo_clips.gd").install(other, true)
	var second = load("res://scripts/game/rifle_animation_controller.gd").new()
	second.setup(other)
	assert(first.locomotion_tree.tree_root == second.locomotion_tree.tree_root)
	for velocity in [Vector3(0,0,-2.4), Vector3(0,0,2.4), Vector3(-1.4,0,-1.4), Vector3(1.4,0,1.4)]:
		for frame in 60:
			first.advance(1.0 / 60.0, velocity, false, true)
			var poses: Array[Transform3D] = []
			for bone in soldier.skeleton.get_bone_count(): poses.append(soldier.skeleton.get_bone_pose(bone))
			var weight: float = first.locomotion_tree.get("parameters/walking_mix/blend_amount")
			second.advance(1.0 / 30.0, -velocity, true, true)
			assert(first.locomotion_tree.get("parameters/walking_mix/blend_amount") == weight)
			for bone in poses.size():
				assert(soldier.skeleton.get_bone_pose(bone).is_equal_approx(poses[bone]), "Shared blend graph changed another actor")
	first.reset()
	first.advance(1.0 / 60.0, Vector3.ZERO, false, true)
	assert(first.state == "Idle")
	print("BLEND INDEPENDENCE PASS shared graph, separate phases/weights/poses and return to idle")
	get_tree().quit()

func _physics_process(_dt: float) -> void: pass
