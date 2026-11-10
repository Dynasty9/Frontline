extends "res://tests/mocap/skinned_demo.gd"

var correct: RigidBody3D
var reversed: RigidBody3D

func _ready() -> void:
	super._ready()
	soldier.pose(0.1, 0.0, "idle")
	soldier.kill(Vector3.ZERO, 2)
	var knee_rid := RID()
	for child in soldier.ragdoll.get_children():
		if child is Generic6DOFJoint3D and child.get_node(child.node_b) == soldier.ragdoll.bodies["RightLeg"]:
			knee_rid = child.get_rid()
	assert(knee_rid.is_valid())
	var low := PhysicsServer3D.generic_6dof_joint_get_param(knee_rid, 0, PhysicsServer3D.G6DOF_JOINT_ANGULAR_LOWER_LIMIT)
	var high := PhysicsServer3D.generic_6dof_joint_get_param(knee_rid, 0, PhysicsServer3D.G6DOF_JOINT_ANGULAR_UPPER_LIMIT)
	correct = _hinge(Vector3(5, 3, 0), low, high)
	reversed = _hinge(Vector3(7, 3, 0), -high, -low)

func _hinge(at: Vector3, low: float, high: float) -> RigidBody3D:
	var parent := StaticBody3D.new()
	add_child(parent)
	parent.position = at
	parent.collision_layer = 0
	var body := RigidBody3D.new()
	body.gravity_scale = 0.0
	body.collision_layer = 0
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	add_child(body)
	body.global_transform = Transform3D(Basis(Vector3.RIGHT, 1.5), at)
	var joint := Generic6DOFJoint3D.new()
	add_child(joint)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(body)
	var rid := joint.get_rid()
	PhysicsServer3D.joint_make_generic_6dof(rid, parent.get_rid(), Transform3D.IDENTITY, body.get_rid(), Transform3D.IDENTITY)
	for axis in 3:
		PhysicsServer3D.generic_6dof_joint_set_flag(rid, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_LINEAR_LIMIT, true)
		PhysicsServer3D.generic_6dof_joint_set_param(rid, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_LOWER_LIMIT, 0.0)
		PhysicsServer3D.generic_6dof_joint_set_param(rid, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_UPPER_LIMIT, 0.0)
		PhysicsServer3D.generic_6dof_joint_set_flag(rid, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_ANGULAR_LIMIT, true)
		PhysicsServer3D.generic_6dof_joint_set_param(rid, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_LOWER_LIMIT, low if axis == 0 else -0.04)
		PhysicsServer3D.generic_6dof_joint_set_param(rid, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_UPPER_LIMIT, high if axis == 0 else 0.04)
	return body

func _physics_process(dt: float) -> void:
	time += dt
	if time < 1.0: return
	var kept := correct.global_basis.get_euler().x
	var snapped := reversed.global_basis.get_euler().x
	assert(absf(kept - 1.5) < 0.01, "Configured knee rejects valid captured flexion")
	assert(absf(snapped - 1.5) > 0.5, "Control did not reproduce reversed hinge limits")
	print("HINGE DIRECTION PASS captured=1.5 retained=", kept, " reversed=", snapped)
	get_tree().quit()
