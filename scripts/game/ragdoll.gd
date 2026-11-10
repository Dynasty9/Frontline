class_name Ragdoll
extends Node3D
## A dead soldier's body under real physics: eleven rigid bodies (pelvis,
## chest, head, upper and lower arms and legs) joined with anatomical limits -
## knees and elbows only bend one way, the neck and spine only so far. It
## starts from whatever pose he was in when he was hit and takes the impulse
## that killed him: a bullet knocks him back and he folds; a blast throws him,
## limbs flailing, and he tumbles to a stop - into a trench if that's where he
## lands. The physics runs at the simulation rate; the body is drawn
## interpolated between steps. Once it has settled the bodies go away and the
## model keeps the pose.

const ORDER = HumanoidRig.ORDER
const SPEC = HumanoidRig.SPEC
const LIMITS = HumanoidRig.LIMITS

var model  # SoldierModel
var bodies := {}
var _prev := {}
var _curr := {}
var t := 0.0
var _calm := 0.0
var done := false


## kind: 0 a bullet (impulse at the chest), 1 a blast (the whole body thrown),
## 2 he just slumps (bled out).
func setup(m, impulse: Vector3, kind: int, mat: PhysicsMaterial, layer: int, mask: int, travel := Vector3.ZERO) -> void:
	model = m
	m.ragdoll = self
	if m.gun:
		m.gun.visible = false
	# 1. bodies in the rest pose (every joint straight) around the pelvis as it is now
	var rest := {}
	for n in ORDER:
		var node: Node3D = m.get(n)
		var spec: Array = SPEC[n]
		var xf: Transform3D
		if spec[0] == "":
			xf = node.global_transform
		else:
			xf = (rest[spec[0]] as Transform3D) * Transform3D(Basis.IDENTITY, node.position)
		rest[n] = xf
		var b := RigidBody3D.new()
		b.mass = spec[4]
		b.physics_material_override = mat
		b.collision_layer = layer
		b.collision_mask = mask
		b.continuous_cd = true
		b.linear_damp = 0.05
		b.angular_damp = 0.9
		b.gravity_scale = 2.0  # the battlefield's gravity (blast arcs use 20 m/s²)
		var cs := CollisionShape3D.new()
		match String(spec[1]):
			"box":
				var bs := BoxShape3D.new()
				bs.size = spec[2]
				cs.shape = bs
			"sphere":
				var ss := SphereShape3D.new()
				ss.radius = (spec[2] as Vector3).x
				cs.shape = ss
			_:
				var cap := CapsuleShape3D.new()
				cap.radius = (spec[2] as Vector3).x
				cap.height = maxf((spec[2] as Vector3).y, cap.radius * 2.0 + 0.02)
				cs.shape = cap
		cs.position = spec[3]
		b.add_child(cs)
		b.transform = xf
		add_child(b)
		bodies[n] = b
	# 2. joints, set up in the rest pose so the limits are anatomical
	for n in ORDER:
		var spec2: Array = SPEC[n]
		if spec2[0] == "":
			continue
		var j := Generic6DOFJoint3D.new()
		j.transform = Transform3D((rest[spec2[0]] as Transform3D).basis, (rest[n] as Transform3D).origin)
		add_child(j)
		var lim: Array = LIMITS[n]
		j.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
		j.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
		j.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
		j.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, lim[0])
		j.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, lim[1])
		j.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, lim[2])
		j.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, lim[3])
		j.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, lim[4])
		j.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, lim[5])
		j.node_a = j.get_path_to(bodies[spec2[0]])
		j.node_b = j.get_path_to(bodies[n])
	# 3. now into the pose he was actually in, moving the way he was hit
	for n in ORDER:
		var b2: RigidBody3D = bodies[n]
		var node2: Node3D = m.get(n)
		b2.global_transform = node2.global_transform
		b2.linear_velocity = ImpactResponse.death_velocity(travel, impulse, kind, n)
		if kind == 1:
			# A blast turns the body around its centre; independent random limb
			# spins fight the constraints and make it look like a pinwheel.
			b2.angular_velocity = Vector3.UP.cross(impulse).limit_length(4.0)
		_prev[n] = b2.global_transform
		_curr[n] = b2.global_transform
	if OS.has_environment("FL_DEBUG_RAG"):
		print("RAG start kind=%d imp=%s hips=%s" % [kind, str(impulse.snapped(Vector3.ONE * 0.1)), str((bodies["hips"] as RigidBody3D).global_position.snapped(Vector3.ONE * 0.1))])


## Called every physics step: remember where each part was and is.
func capture() -> void:
	if done:
		return
	var vmax := 0.0
	for n in ORDER:
		var b: RigidBody3D = bodies[n]
		_prev[n] = _curr[n]
		_curr[n] = b.global_transform
		vmax = maxf(vmax, b.linear_velocity.length())
		vmax = maxf(vmax, b.angular_velocity.length() * 0.25)
	_calm = _calm + 1.0 / Engine.physics_ticks_per_second if vmax < 0.15 else 0.0


## Called every frame: draw the body between the last two physics steps.
func update(dt: float, alpha: float) -> void:
	if done:
		return
	if not is_instance_valid(model) or not model.is_inside_tree():
		_free()
		return
	t += dt
	for n in ORDER:
		var node: Node3D = model.get(n)
		node.global_transform = (_prev[n] as Transform3D).interpolate_with(_curr[n], alpha)
	if (t > 1.2 and _calm > 0.5) or t > 7.0:
		finish()


## Leave the body as it lies and drop the physics.
func finish() -> void:
	if done:
		return
	if OS.has_environment("FL_DEBUG_RAG"):
		print("RAG end t=%.2f hips=%s calm=%.2f" % [t, str((_curr["hips"] as Transform3D).origin.snapped(Vector3.ONE * 0.1)), _calm])
	if is_instance_valid(model):
		for n in ORDER:
			(model.get(n) as Node3D).global_transform = _curr[n]
		model.ragdoll = null
		model.ragdoll_done = true
	_free()


## A blast nearby throws what's left about again.
func push(from: Vector3, power: float) -> void:
	if done:
		return
	for n in ORDER:
		var b: RigidBody3D = bodies[n]
		var d := b.global_position - from
		var f := power / maxf(1.0, d.length())
		b.apply_central_impulse((d.normalized() + Vector3.UP * 0.6) * f * b.mass)
	t = minf(t, 3.0)
	_calm = 0.0


func _free() -> void:
	done = true
	queue_free()
