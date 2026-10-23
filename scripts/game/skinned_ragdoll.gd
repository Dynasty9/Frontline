class_name SkinnedRagdoll
extends Node3D
## Physics owns the same Skeleton3D that deforms the living character. Bodies
## begin at the current bone pose; there is no mesh swap or death-pose snap.

const PARTS := [
	["Hips", "", "Spine", 12.0, 0.12],
	["Spine2", "Hips", "Neck", 18.0, 0.16],
	["Head", "Spine2", "HeadTop_End", 5.0, 0.105],
	["LeftArm", "Spine2", "LeftForeArm", 2.5, 0.065],
	["LeftForeArm", "LeftArm", "LeftHand", 1.5, 0.055],
	["RightArm", "Spine2", "RightForeArm", 2.5, 0.065],
	["RightForeArm", "RightArm", "RightHand", 1.5, 0.055],
	["LeftUpLeg", "Hips", "LeftLeg", 8.0, 0.085],
	["LeftLeg", "LeftUpLeg", "LeftFoot", 4.0, 0.065],
	["LeftFoot", "LeftLeg", "LeftToeBase", 1.0, 0.065],
	["RightUpLeg", "Hips", "RightLeg", 8.0, 0.085],
	["RightLeg", "RightUpLeg", "RightFoot", 4.0, 0.065],
	["RightFoot", "RightLeg", "RightToeBase", 1.0, 0.065],
]
var actor: SkinnedRifleman
var bodies := {}
var anchors := {}
var bone_positions := {}
var bone_directions := {}
var follow_bones := {}
var weapon_body: RigidBody3D
var magazine_body: RigidBody3D
var handoff_error := 0.0
var contact_count := 0
var done := false
var elapsed := 0.0
var collision_layer := 2
var collision_mask := 1
var prop_query := PhysicsShapeQueryParameters3D.new()


func build(character: SkinnedRifleman, travel: Vector3, impulse: Vector3, kind := 1) -> void:
	actor = character
	top_level = true
	var poses := {}
	var rests := {}
	var material := PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = 0.02
	for part in PARTS:
		var name: String = part[0]
		poses[name] = actor.joint(name)
		var follow: String = "Spine2" if name == "Hips" else ("Head" if name == "Spine2" else part[2])
		follow_bones[name] = follow
		if actor.bones.has(follow):
			bone_directions[name] = (poses[name] as Transform3D).affine_inverse() * actor.joint(follow).origin
		bone_positions[name] = actor.skeleton.get_bone_pose_position(int(actor.bones[name]))
		var rest: Transform3D = actor.global_transform * actor.target_rest[int(actor.bones[name])]
		rests[name] = rest
		var end: Vector3 = actor.global_transform * actor.target_rest[int(actor.bones[part[2]])].origin if actor.bones.has(part[2]) else rest.origin + Vector3.UP * 0.22
		var segment := end - rest.origin
		var body := RigidBody3D.new()
		body.mass = part[3]
		body.physics_material_override = material
		body.collision_layer = collision_layer
		body.collision_mask = collision_mask | collision_layer
		body.continuous_cd = true
		body.linear_damp = 0.12
		body.angular_damp = 0.8
		body.contact_monitor = true
		body.max_contacts_reported = 8
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		# Spine2 sits near the shoulders; its collider must also cover the
		# abdomen, otherwise a thigh can enter the gap above the pelvis.
		var start := rest.origin
		if name == "Spine2": start = (rests["Hips"] as Transform3D).origin + actor.global_basis.y * 0.1
		segment = end - start
		capsule.radius = part[4]
		capsule.height = maxf(segment.length(), capsule.radius * 2.0 + 0.01)
		shape.shape = capsule
		shape.position = rest.basis.inverse() * ((start + end) * 0.5 - rest.origin)
		shape.basis = Basis(Quaternion(Vector3.UP, (rest.basis.inverse() * segment).normalized()))
		body.add_child(shape)
		add_child(body)
		body.global_transform = rest
		bodies[name] = body
	for part in PARTS:
		if part[1] == "":
			continue
		var name: String = part[0]
		var joint := Generic6DOFJoint3D.new()
		add_child(joint)
		joint.global_transform = Transform3D(actor.global_basis.orthonormalized(), (rests[name] as Transform3D).origin)
		var limits := Vector3(0.35, 0.25, 0.25)
		var low := -limits
		var high := limits
		if name in ["LeftArm", "RightArm"]:
			low = Vector3(-1.1,-2.2,-2.2)
			high = -low
		elif name.ends_with("ForeArm"):
			low = Vector3(-0.08, -0.03 if name.begins_with("Left") else -2.4, -0.08)
			high = Vector3(0.08, 2.4 if name.begins_with("Left") else 0.03, 0.08)
		elif name.ends_with("UpLeg"):
			low = Vector3(-1.7,-0.4,-0.65)
			high = Vector3(1.2,0.4,0.65)
		elif name.ends_with("Leg"):
			low = Vector3(-0.03,-0.04,-0.04)
			high = Vector3(2.4,0.04,0.04)
		elif name.ends_with("Foot"):
			# A planted crouch flexes the ankle farther than the torso joints.
			low = Vector3(-0.6, -0.25, -0.25)
			high = -low
		elif name == "Head":
			low = Vector3(-0.65,-0.8,-0.5)
			high = -low
		joint.node_a = joint.get_path_to(bodies[part[1]])
		joint.node_b = joint.get_path_to(bodies[name])
		# Shoulder/spine bones between simulated parts move the attachment point.
		# Match their captured positions without redefining anatomical angle limits.
		var parent_pose: Transform3D = poses[part[1]]
		var child_pose: Transform3D = poses[name]
		var parent_rest: Transform3D = rests[part[1]]
		var child_rest: Transform3D = rests[name]
		var parent_anchor := parent_pose.affine_inverse() * child_pose.origin
		anchors[name] = parent_anchor
		var frame_a := Transform3D(parent_rest.basis.inverse() * actor.global_basis, parent_anchor)
		var frame_b := Transform3D(child_rest.basis.inverse() * actor.global_basis, Vector3.ZERO)
		if name.ends_with("ForeArm") or (name.ends_with("Leg") and not name.ends_with("UpLeg")):
			var upper := (child_pose.origin - parent_pose.origin).normalized()
			var lower := (actor.joint(part[2]).origin - child_pose.origin).normalized()
			var hinge := upper.cross(lower)
			if hinge.length_squared() > 0.0001:
				# Calibrate the hinge to the captured bend plane, not the rig's bone roll.
				hinge = hinge.normalized()
				var parent_frame := Basis(hinge, upper, hinge.cross(upper))
				var child_frame := Basis(hinge, lower, hinge.cross(lower))
				frame_a.basis = parent_pose.basis.inverse() * parent_frame
				frame_b.basis = child_pose.basis.inverse() * child_frame
				# Godot's angular limits use the opposite sign to this frame's rotation.
				var lateral := 0.08 if name.ends_with("ForeArm") else 0.04
				low = Vector3(-2.4, -lateral, -lateral)
				high = Vector3(0.03, lateral, lateral)
		var rid := joint.get_rid()
		PhysicsServer3D.joint_make_generic_6dof(rid, bodies[part[1]].get_rid(), frame_a, bodies[name].get_rid(), frame_b)
		PhysicsServer3D.joint_disable_collisions_between_bodies(rid, true)
		for axis in 3:
			PhysicsServer3D.generic_6dof_joint_set_flag(rid, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_LINEAR_LIMIT, true)
			PhysicsServer3D.generic_6dof_joint_set_flag(rid, axis, PhysicsServer3D.G6DOF_JOINT_FLAG_ENABLE_ANGULAR_LIMIT, true)
			PhysicsServer3D.generic_6dof_joint_set_param(rid, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_LOWER_LIMIT, 0.0)
			PhysicsServer3D.generic_6dof_joint_set_param(rid, axis, PhysicsServer3D.G6DOF_JOINT_LINEAR_UPPER_LIMIT, 0.0)
			PhysicsServer3D.generic_6dof_joint_set_param(rid, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_LOWER_LIMIT, low[axis])
			PhysicsServer3D.generic_6dof_joint_set_param(rid, axis, PhysicsServer3D.G6DOF_JOINT_ANGULAR_UPPER_LIMIT, high[axis])

	# Connected capsules meet at the joint and intentionally overlap there.
	# Every other pair must collide so limbs cannot pass through the torso.
	for part in PARTS:
		if part[1] != "": bodies[part[0]].add_collision_exception_with(bodies[part[1]])
	var blast_center := Vector3.ZERO
	var total_mass := 0.0
	for name in bodies:
		var body: RigidBody3D = bodies[name]
		blast_center += (poses[name] * body.get_child(0).position) * body.mass
		total_mass += body.mass
	blast_center /= total_mass
	var blast_spin := Vector3.UP.cross(impulse) * 0.35 if kind == 1 else Vector3.ZERO
	for name in bodies:
		var body: RigidBody3D = bodies[name]
		body.global_transform = poses[name]
		body.linear_velocity = ImpactResponse.death_velocity(travel, impulse, kind, "torso" if name == "Spine2" else name)
		body.angular_velocity = actor.limb_spin.get(name, Vector3.ZERO)
		body.linear_velocity += actor.limb_velocity.get(name, Vector3.ZERO) + body.angular_velocity.cross(body.global_basis * body.get_child(0).position)
		# A whole-body spin needs matching tangential motion at each limb's center of mass.
		body.linear_velocity += blast_spin.cross(body.global_transform * body.get_child(0).position - blast_center)
		body.angular_velocity += blast_spin
		handoff_error = maxf(handoff_error, body.global_position.distance_to((poses[name] as Transform3D).origin))
	# The rifle is a separate object after the trigger hand releases it.
	weapon_body = RigidBody3D.new()
	weapon_body.mass = 3.5
	weapon_body.collision_layer = collision_layer
	weapon_body.collision_mask = collision_mask | collision_layer
	weapon_body.continuous_cd = true
	weapon_body.physics_material_override = material
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.09, 0.18, 0.8)
	shape.shape = box
	shape.position.z = 0.18
	weapon_body.add_child(shape)
	add_child(weapon_body)
	weapon_body.global_transform = actor.weapon.global_transform
	actor.weapon.reparent(weapon_body)
	weapon_body.linear_velocity = ImpactResponse.death_velocity(travel, impulse * 0.7, kind, "weapon")
	weapon_body.angular_velocity = actor.limb_spin.get("weapon", Vector3.ZERO)
	weapon_body.linear_velocity += actor.limb_velocity.get("weapon", Vector3.ZERO) + weapon_body.angular_velocity.cross(weapon_body.global_basis * shape.position)
	if kind == 1: weapon_body.angular_velocity += Vector3(1.2, 0.7, 0.4)
	# Ignore the initial grip overlap; restore each collision after separation.
	for body in bodies.values(): weapon_body.add_collision_exception_with(body)
	if actor.magazine.mesh != null and actor.magazine.mesh.visible and actor.magazine.detached_weight > 0.001:
		var mesh: MeshInstance3D = actor.magazine.mesh
		magazine_body = RigidBody3D.new()
		magazine_body.mass = 0.45
		magazine_body.physics_material_override = material
		magazine_body.collision_layer = collision_layer
		magazine_body.collision_mask = collision_mask | collision_layer
		magazine_body.continuous_cd = true
		add_child(magazine_body)
		magazine_body.global_transform = Transform3D(mesh.global_basis.orthonormalized(), mesh.global_position)
		var local := magazine_body.global_transform.affine_inverse() * mesh.global_transform
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var bounds := AABB(local * vertices[indices[0]], Vector3.ZERO)
		# The split mesh retains unused rifle vertices; only indexed vertices belong to the magazine.
		for index in indices: bounds = bounds.expand(local * vertices[index])
		var magazine_shape := CollisionShape3D.new()
		var magazine_box := BoxShape3D.new()
		magazine_box.size = bounds.size.max(Vector3.ONE * 0.005)
		magazine_shape.shape = magazine_box
		magazine_shape.position = bounds.get_center()
		magazine_body.add_child(magazine_shape)
		mesh.reparent(magazine_body)
		magazine_body.angular_velocity = actor.limb_spin.get("magazine", Vector3.ZERO)
		magazine_body.linear_velocity = ImpactResponse.death_velocity(travel, impulse, kind, "magazine") + actor.limb_velocity.get("magazine", Vector3.ZERO) + magazine_body.angular_velocity.cross(magazine_body.global_basis * magazine_shape.position)
		magazine_body.add_collision_exception_with(weapon_body)
		for body in bodies.values(): magazine_body.add_collision_exception_with(body)
	if OS.has_environment("FL_DEBUG_MOCAP"):
		print("SKIN_RAGDOLL handoff_error=", handoff_error)


func draw() -> void:
	if done or not is_instance_valid(actor): return
	for part in PARTS:
		var body: RigidBody3D = bodies[part[0]]
		var index: int = actor.bones[part[0]]
		var pose := body.global_transform
		if part[1] != "":
			# Solver drift must not change limb lengths in the rendered skin.
			actor.skeleton.set_bone_pose_position(index, bone_positions[part[0]])
			pose.origin = actor.world_pose(index).origin
		var follow: String = follow_bones[part[0]]
		if bodies.has(follow):
			var direction: Vector3 = pose.basis * (bone_directions[part[0]] as Vector3)
			var target: Vector3 = bodies[follow].global_position - pose.origin
			if direction.length_squared() > 0.000001 and target.length_squared() > 0.000001:
				pose.basis = Basis(Quaternion(direction.normalized(), target.normalized())) * pose.basis
		actor.set_world(index, pose)
		contact_count += body.get_contact_count()


func _physics_process(dt: float) -> void:
	if not is_instance_valid(actor):
		queue_free()
		return
	elapsed += dt
	_release_contacts(weapon_body)
	if is_instance_valid(magazine_body): _release_contacts(magazine_body)
	draw()
	if elapsed > 9.0: finish()


func _release_contacts(prop: RigidBody3D) -> void:
	var ignored := prop.get_collision_exceptions()
	if ignored.is_empty(): return
	var shape: CollisionShape3D = prop.get_child(0)
	prop_query.shape = shape.shape
	prop_query.transform = shape.global_transform
	prop_query.collision_mask = collision_layer
	prop_query.exclude = [prop.get_rid()]
	prop_query.margin = 0.02
	var overlaps := get_world_3d().direct_space_state.intersect_shape(prop_query, 32)
	# A saturated query cannot prove that an ignored part is clear.
	if overlaps.size() == 32: return
	for body in ignored:
		var touching := false
		for overlap in overlaps:
			if overlap.collider == body:
				touching = true
				break
		if not touching: prop.remove_collision_exception_with(body)


func capture() -> void:
	pass


func update(_dt: float, _alpha: float) -> void:
	draw()


func finish() -> void:
	if done: return
	draw()
	done = true
	if is_instance_valid(actor) and is_instance_valid(actor.weapon):
		actor.weapon.reparent(actor)
		if is_instance_valid(magazine_body): actor.magazine.mesh.reparent(actor.magazine.receiver)
	queue_free()


func set_collision_layers(layer: int, mask: int) -> void:
	collision_layer = layer
	collision_mask = mask
	for body in bodies.values():
		body.collision_layer = layer
		body.collision_mask = mask | layer
	weapon_body.collision_layer = layer
	weapon_body.collision_mask = mask | layer
	if is_instance_valid(magazine_body):
		magazine_body.collision_layer = layer
		magazine_body.collision_mask = mask | layer
