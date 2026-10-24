extends RefCounted
## The caller supplies movement in the rifleman's local frame. Input and
## collision belong to the caller, so RTS units can use the same pose driver.
const PRONE_CLIP := "mixamo_transition__Rifle_Kneel_To_Prone"
var prone_time := 0.0
const PACK := "mixamo_basic_shooter__"
const LOCOMOTION := ["rifle_aiming_idle", "walking", "rifle_run", "walking_backwards", "run_backwards", "strafe_left", "strafe_right"]
static var locomotion_graph: AnimationNodeBlendTree
static var foot_path_cache := {}
var foot_paths := {}
var locomotion_tree: AnimationTree
var blend_weights: Array[float] = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var actor: SkinnedRifleman
var phase := 0.0
var elapsed := 0.0
var crouch_weight := 0.0
var crouch_drop := 0.0
var _crouch_phase := INF
var _crouch_transform := Transform3D.IDENTITY
var _crouch_poses: Array[Transform3D] = []
var action := ""
var action_time := 0.0
var action_weight := 0.0
var state := "Idle"
var poses: Array[Transform3D] = []
var upper: Array[bool] = []
var loop_starts := {}
var phase_offsets := {}
var stride_lengths := {}
var blend_velocity := Vector3.ZERO
var diagonal_weight := 0.0
var pelvis_drop := 0.0
var contact_weights := [0.0, 0.0]
var slope_normals := [Vector3.UP, Vector3.UP]
var socket := Transform3D.IDENTITY
var support_grip := Transform3D.IDENTITY
var jump_count := 0
var reload_count := 0
var max_contact_change := 0.0
var worst_contact_time := 0.0
var contact_offsets := [Vector3.ZERO, Vector3.ZERO]
var contacts_sampled := false
var previous_support: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var previous_corrections := [Vector3.ZERO, Vector3.ZERO]
var plant_ready := [true, true]
var plant_weights := [0.0, 0.0]

func setup(character: SkinnedRifleman) -> void:
	actor = character
	poses.resize(actor.skeleton.get_bone_count())
	_crouch_poses.resize(poses.size())

	upper.resize(poses.size())
	for i in poses.size():
		var parent := i
		while parent >= 0:
			if parent == int(actor.bones["Spine"]): upper[i] = true
			parent = actor.skeleton.get_bone_parent(parent)
	socket = actor.native_socket
	for clip in LOCOMOTION:
		_sample(clip, 0.0)
		var start: Array[Transform3D] = []
		for i in poses.size(): start.append(actor.skeleton.get_bone_pose(i))
		loop_starts[clip] = start
		if clip == "rifle_aiming_idle":
			support_grip = (actor.joint("RightHand") * socket).affine_inverse() * actor.joint("LeftHand")
			# Seat the glove under this M4 handguard, within reach throughout the run.
			support_grip.origin += Vector3(0.0, 0.04, -0.03)
			continue
		var animation := actor.native_player.get_animation(PACK + clip)
		var travel: Vector3 = animation.get_meta("root_travel", Vector3.ZERO)
		var stride := (actor.skeleton.global_basis * travel).length()
		# shortcut: in-place clips need an authored stride when they replace these traveling clips.
		stride_lengths[clip] = stride if stride > 0.1 else 1.8
		# These packs start on different feet. Align the left swing apex before
		# blending directions or speeds so the legs do not cancel each other.
		var length := actor.native_player.get_animation(PACK + clip).length
		var peak_height := -INF
		for frame in 32:
			_sample(clip, length * float(frame) / 32.0)
			var height := actor.joint("LeftFoot").origin.y
			if height > peak_height:
				peak_height = height
				phase_offsets[clip] = float(frame) / 32.0
	if locomotion_graph == null: locomotion_graph = _locomotion_graph()
	locomotion_tree = AnimationTree.new()
	actor.add_child(locomotion_tree)
	locomotion_tree.anim_player = locomotion_tree.get_path_to(actor.native_player)
	locomotion_tree.tree_root = locomotion_graph
	locomotion_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	locomotion_tree.active = true
	if not foot_path_cache.has(actor.model_asset):
		var paths := {}
		for clip in LOCOMOTION:
			var points := PackedVector3Array()
			var length := actor.native_player.get_animation(PACK + clip).length
			for frame in 64:
				_sample(clip, length * frame / 64.0)
				for joint_name in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
					points.append(actor.to_local(actor.joint(joint_name).origin))
			paths[clip] = points
		foot_path_cache[actor.model_asset] = paths
	foot_paths = foot_path_cache[actor.model_asset]
	_sample("rifle_aiming_idle", 0.0)

func _blend_foot_paths() -> void:
	# Fully crouched legs replace this standing pose below.
	if crouch_weight == 1.0: return
	var weight := diagonal_weight
	if weight == 0.0: return
	var goals: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	for i in LOCOMOTION.size():
		if blend_weights[i] <= 0.0001: continue
		var clip: String = LOCOMOTION[i]
		var cycle := fposmod(phase + float(phase_offsets.get(clip, 0.0)), 1.0)
		if i == 0: cycle = fposmod(elapsed / actor.native_player.get_animation(PACK + clip).length, 1.0)
		var sample := cycle * 64.0
		var frame := int(sample)
		var points: PackedVector3Array = foot_paths[clip]
		for joint_index in 4:
			var point := points[frame * 4 + joint_index].lerp(points[((frame + 1) % 64) * 4 + joint_index], sample - frame)
			if i != 0: point = point.lerp(points[joint_index], smoothstep(0.9, 1.0, cycle))
			goals[joint_index] += point * blend_weights[i]
	for i in poses.size(): actor.skeleton.set_bone_pose(i, poses[i])
	# Blended joint rotations can collapse a diagonal swing toward the floor.
	for side in 2:
		var prefix := "Left" if side == 0 else "Right"
		var ankle := actor.joint(prefix + "Foot")
		var toe_direction := actor.joint(prefix + "ToeBase").origin - ankle.origin
		var pole := actor.joint(prefix + "Leg").origin - actor.joint(prefix + "UpLeg").origin
		actor.solve_limb(prefix + "UpLeg", prefix + "Leg", prefix + "Foot", ankle.origin.lerp(actor.to_global(goals[side]), weight), pole)
		var foot := actor.joint(prefix + "Foot")
		var turn := Quaternion(toe_direction.normalized(), (actor.global_basis * (goals[side + 2] - goals[side])).normalized())
		foot.basis = Basis(Quaternion.IDENTITY.slerp(turn, weight)) * ankle.basis
		actor.set_world(int(actor.bones[prefix + "Foot"]), foot)
		for suffix in ["UpLeg", "Leg", "Foot"]:
			var index: int = actor.bones[prefix + suffix]
			poses[index] = actor.skeleton.get_bone_pose(index)

static func _locomotion_graph() -> AnimationNodeBlendTree:
	var graph := AnimationNodeBlendTree.new()
	var previous := ""
	for clip in LOCOMOTION:
		for suffix in ["", "_start"]:
			var animation := AnimationNodeAnimation.new()
			animation.animation = PACK + clip
			graph.add_node(clip + suffix, animation)
			var seek := AnimationNodeTimeSeek.new()
			seek.explicit_elapse = false
			graph.add_node(clip + suffix + "_seek", seek)
			graph.connect_node(clip + suffix + "_seek", 0, clip + suffix)
		graph.add_node(clip + "_seam", AnimationNodeBlend2.new())
		graph.connect_node(clip + "_seam", 0, clip + "_seek")
		graph.connect_node(clip + "_seam", 1, clip + "_start_seek")
		if previous == "": previous = clip + "_seam"
		else:
			graph.add_node(clip + "_mix", AnimationNodeBlend2.new())
			graph.connect_node(clip + "_mix", 0, previous)
			graph.connect_node(clip + "_mix", 1, clip + "_seam")
			previous = clip + "_mix"
	graph.connect_node("output", 0, previous)
	return graph

func request_action(next: String) -> bool:
	if actor.dead or action != "": return false
	action = next
	action_time = 0.0
	if next == "rifle_jump": jump_count += 1
	if next == "reloading": reload_count += 1
	return true

func reset() -> void:
	_crouch_phase = INF
	prone_time = 0.0
	action = ""
	phase = 0.0
	blend_velocity = Vector3.ZERO
	diagonal_weight = 0.0
	crouch_weight = 0.0
	crouch_drop = 0.0
	pelvis_drop = 0.0
	contacts_sampled = false
	contact_offsets = [Vector3.ZERO, Vector3.ZERO]
	contact_weights = [0.0, 0.0]
	slope_normals = [Vector3.UP, Vector3.UP]
	for foot in actor.feet: foot.locked = false
	plant_ready = [true, true]
	plant_weights = [0.0, 0.0]

func _sample(clip: String, seconds: float) -> void:
	actor.native_player.play(PACK + clip, 0.0)
	actor.native_player.seek(seconds, true)

func _locomotion_pose() -> void:
	var count := 0
	for weight in blend_weights:
		if weight > 0.0001: count += 1
	var total := 0.0
	for i in LOCOMOTION.size():
		var clip: String = LOCOMOTION[i]
		var weight := blend_weights[i] if blend_weights[i] > 0.0001 else 0.0
		total += weight
		if count > 1 and i > 0:
			locomotion_tree.set("parameters/" + clip + "_mix/blend_amount", weight / total if total > 0.0 else 0.0)
		if weight == 0.0: continue
		var animation := actor.native_player.get_animation(PACK + clip)
		var cycle := fposmod(phase + float(phase_offsets.get(clip, 0.0)), 1.0)
		var seconds := fposmod(elapsed, animation.length) if i == 0 else cycle * animation.length
		var seam := smoothstep(0.90, 1.0, cycle) if i != 0 else 0.0
		# One clip needs no blend graph; mixed clips share one native skeleton update.
		if count == 1:
			_sample(clip, seconds)
			for bone in poses.size():
				var sample := actor.skeleton.get_bone_pose(bone)
				poses[bone] = sample.interpolate_with(loop_starts[clip][bone], seam) if seam > 0.0 else sample
			return
		locomotion_tree.set("parameters/" + clip + "_seek/seek_request", seconds)
		locomotion_tree.set("parameters/" + clip + "_start_seek/seek_request", 0.0)
		locomotion_tree.set("parameters/" + clip + "_seam/blend_amount", seam)
	locomotion_tree.advance(0.0)
	for bone in poses.size(): poses[bone] = actor.skeleton.get_bone_pose(bone)

func advance(dt: float, velocity: Vector3, crouching: bool, grounded: bool, reload_progress := -1.0) -> void:
	if actor.dead:
		if is_instance_valid(actor.ragdoll): actor.ragdoll.draw()
		return
	elapsed += dt
	blend_velocity = blend_velocity.lerp(velocity, 1.0 - exp(-12.0 * dt))
	var speed := Vector2(blend_velocity.x, blend_velocity.z).length()
	diagonal_weight = smoothstep(0.0, 0.15, minf(absf(blend_velocity.x), absf(blend_velocity.z)) / maxf(speed, 0.001))
	crouch_weight = move_toward(crouch_weight, 1.0 if crouching and grounded else 0.0, dt * 5.0)
	var moving := clampf(speed / 1.4, 0.0, 1.0)
	var run := clampf((speed - 1.4) / 2.0, 0.0, 1.0)
	var denominator := maxf(absf(blend_velocity.x) + absf(blend_velocity.z), 0.001)
	var forward := moving * maxf(-blend_velocity.z, 0.0) / denominator
	var backward := moving * maxf(blend_velocity.z, 0.0) / denominator
	var left := moving * maxf(-blend_velocity.x, 0.0) / denominator
	var right := moving * maxf(blend_velocity.x, 0.0) / denominator
	var stride := Vector2(right * float(stride_lengths.strafe_right) - left * float(stride_lengths.strafe_left), backward * lerpf(stride_lengths.walking_backwards, stride_lengths.run_backwards, run) - forward * lerpf(stride_lengths.walking, stride_lengths.rifle_run, run)).length()
	if moving > 0.0001: phase += dt * speed * moving / maxf(stride, 0.0001)
	blend_weights[0] = 1.0 - moving
	blend_weights[1] = forward * (1.0 - run)
	blend_weights[2] = forward * run
	blend_weights[3] = backward * (1.0 - run)
	blend_weights[4] = backward * run
	blend_weights[5] = left
	blend_weights[6] = right
	_locomotion_pose()
	_blend_foot_paths()
	state = "Run" if run > 0.5 else ("Move" if speed > 0.1 else "Idle")
	if crouch_weight > 0.0:
		# The sample pack has an unarmed crouch walk. Borrow only its pelvis
		# and legs; preserve the rifle animation above the waist.
		var hips: int = actor.bones["Hips"]
		var spine: int = actor.bones["Spine"]
		var aim_basis := poses[hips].basis * poses[spine].basis
		# A stopped crouch keeps its captured phase; reuse only the pre-contact local pose.
		if _crouch_phase != phase or _crouch_transform != actor.global_transform:
			actor.source.player.play("crouch", 0.0)
			actor.source._clip = "crouch"
			var length := actor.source.player.get_animation("crouch").length
			actor.source.player.seek(fmod(phase, 1.0) * length, true)
			actor.source.advance(0.0, speed, "crouch")
			actor._retarget_source(upper)
			for i in poses.size():
				if not upper[i]: _crouch_poses[i] = actor.skeleton.get_bone_pose(i)
			_crouch_phase = phase
			_crouch_transform = actor.global_transform
		for i in poses.size():
			if not upper[i]: poses[i] = poses[i].interpolate_with(_crouch_poses[i], crouch_weight)
		# Local upper-body poses would otherwise inherit the unarmed pelvis lean.
		poses[spine].basis = poses[hips].basis.inverse() * aim_basis
		state = "Crouch walk" if speed > 0.1 else "Crouch"
	if reload_progress >= 0.0:
		action = "reloading"
		action_time = clampf(reload_progress, 0.0, 1.0) * actor.native_player.get_animation(PACK + action).length
	var target_socket := actor.native_socket
	if action != "":
		if reload_progress < 0.0: action_time += dt
		var animation := actor.native_player.get_animation(PACK + action)
		var length := animation.length
		var t := minf(action_time, length)
		_sample(action, t)
		var action_hips := actor.skeleton.get_bone_pose(int(actor.bones["Hips"])).basis
		action_weight = minf(smoothstep(0.0, 0.18, t), 1.0 - smoothstep(length - 0.22, length, t))
		for i in poses.size():
			if action == "reloading" and not upper[i]: continue
			var sample := actor.skeleton.get_bone_pose(i)
			if action == "reloading" and i == int(actor.bones["Spine"]):
				sample.basis = poses[int(actor.bones["Hips"])].basis.inverse() * action_hips * sample.basis
			# The collision body supplies jump height, avoiding double root lift.
			if action == "rifle_jump" and i == int(actor.bones["Hips"]): sample.origin = poses[i].origin
			poses[i] = poses[i].interpolate_with(sample, action_weight)
		target_socket = actor.native_socket.interpolate_with(actor.native_sockets.get(PACK + action, actor.native_socket), action_weight)
		state = "Reload" if action == "reloading" else "Jump"
		if action_time >= length:
			action = ""
			action_weight = 0.0
	for i in poses.size(): actor.skeleton.set_bone_pose(i, poses[i])
	actor._blend_pose(dt)
	# Settle into cover at rest; retain the authored leg clearance while walking.
	var settle := 0.12 * crouch_weight * (1.0 - smoothstep(0.05, 0.35, Vector2(velocity.x, velocity.z).length()))
	crouch_drop = move_toward(crouch_drop, settle, dt * 0.4)
	if crouch_drop > 0.0:
		var pelvis := actor.joint("Hips")
		pelvis.origin.y -= crouch_drop
		actor.set_world(int(actor.bones["Hips"]), pelvis)
	if grounded and action != "rifle_jump":
		_contacts(speed, dt)
	else:
		for foot in actor.feet: foot.locked = false
		plant_ready = [true, true]
		plant_weights = [0.0, 0.0]
		contacts_sampled = false
		contact_offsets = [Vector3.ZERO, Vector3.ZERO]
		contact_weights = [0.0, 0.0]
		pelvis_drop = 0.0
	actor._apply_hit(dt)
	socket = socket.interpolate_with(target_socket, 1.0 - exp(-20.0 * dt))
	actor.apply_native_recoil(dt, socket)
	actor.weapon.global_transform = actor.joint("RightHand") * socket
	# Keep the captured grip through locomotion blends; actions release it gradually.
	var hand := actor.joint("LeftHand")
	var grip_weight := (1.0 - action_weight) * smoothstep(0.0, actor._transition_duration, actor._transition_time)
	var grip := hand.interpolate_with(actor.weapon.global_transform * support_grip, grip_weight)
	var pole := actor.joint("LeftForeArm").origin - actor.joint("LeftArm").origin
	actor.solve_limb("LeftArm", "LeftForeArm", "LeftHand", grip.origin, pole)
	hand = actor.joint("LeftHand")
	hand.basis = grip.basis
	actor.set_world(int(actor.bones["LeftHand"]), hand)
	actor.weapon.visible = true
	actor.magazine.update(action_time, action == "reloading")
	actor.last_velocity = actor.global_basis * velocity

func advance_prone(dt: float) -> void:
	action = ""
	state = "Prone"
	prone_time += dt
	var length := actor.native_player.get_animation(PRONE_CLIP).length
	actor.native_player.play(PRONE_CLIP, 0.0)
	actor.native_player.seek(minf(prone_time, length), true)
	actor._blend_pose(dt)
	actor._apply_hit(dt)
	actor.apply_native_recoil(dt, actor.native_socket)
	actor.weapon.global_transform = actor.joint("RightHand") * actor.native_socket
	var hand := actor.joint("LeftHand")
	var grip := hand
	grip.origin += actor.weapon.global_basis.y * 0.065 * smoothstep(length - 0.3, length, prone_time)
	var pole := actor.joint("LeftForeArm").origin - actor.joint("LeftArm").origin
	actor.solve_limb("LeftArm", "LeftForeArm", "LeftHand", grip.origin, pole)
	hand = actor.joint("LeftHand")
	hand.basis = grip.basis
	actor.set_world(int(actor.bones["LeftHand"]), hand)
	actor.weapon.visible = true
	actor.magazine.update(0.0, false)
	actor.last_velocity = Vector3.ZERO

func overlay_reload(progress: float) -> void:
	# Preserve the grounded crouch; only the captured upper body handles the rifle.
	for i in poses.size(): poses[i] = actor.skeleton.get_bone_pose(i)
	var previous_weapon := actor.weapon.global_transform
	var clip := PACK + "reloading"
	var length := actor.native_player.get_animation(clip).length
	action = "reloading"
	action_time = clampf(progress, 0.0, 1.0) * length
	var weight := minf(smoothstep(0.0, 0.18, action_time), 1.0 - smoothstep(length - 0.22, length, action_time))
	_sample("reloading", action_time)
	var action_hips := actor.skeleton.get_bone_pose(int(actor.bones["Hips"])).basis
	for i in poses.size():
		var target := actor.skeleton.get_bone_pose(i)
		if i == int(actor.bones["Spine"]):
			target.basis = poses[int(actor.bones["Hips"])].basis.inverse() * action_hips * target.basis
		actor.skeleton.set_bone_pose(i, poses[i].interpolate_with(target, weight) if upper[i] else poses[i])
	var reload_socket: Transform3D = actor.native_sockets.get(clip, actor.native_socket)
	actor.weapon.global_transform = previous_weapon.interpolate_with(actor.joint("RightHand") * reload_socket, weight)
	actor.magazine.update(action_time, true)

func _contacts(speed: float, dt: float) -> void:
	var goals: Array[Vector3] = []
	var poles: Array[Vector3] = []
	var lower_pelvis := 0.0
	var follow := 1.0 - exp(-16.0 * dt)
	for side in 2:
		var prefix := "Left" if side == 0 else "Right"
		var ankle := actor.joint(prefix + "Foot")
		# Running rolls over the forefoot instead of pinning the ankle in space.
		var forefoot := clampf((speed - 1.4) / 2.0, 0.0, 1.0)
		var toe := actor.joint(prefix + "ToeBase").origin
		# Preserve diagonal toe contact while the ankle rolls over it.
		var support := ankle.origin.lerp(toe, lerpf(forefoot, 1.0, diagonal_weight))
		var support_speed := Vector2(support.x - previous_support[side].x, support.z - previous_support[side].z).length() / maxf(dt, 0.001) if contacts_sampled else 0.0
		previous_support[side] = support
		var foot: Dictionary = actor.feet[side]
		var sole_height: float = actor.target_rest[int(actor.bones[prefix + "Foot"])].origin.y
		var lift := ankle.origin.y - actor.global_position.y - sole_height
		var toe_lift: float = toe.y - actor.global_position.y - actor.target_rest[int(actor.bones[prefix + "ToeBase"])].origin.y
		var support_lift := lerpf(lift, toe_lift, forefoot)
		var stance := 1.0 - smoothstep(0.015, 0.12, lift)
		var idle := 1.0 - smoothstep(0.05, 0.35, speed)
		contact_weights[side] = lerpf(contact_weights[side], maxf(stance, idle * crouch_weight), follow)
		if idle > 0.0:
			if not foot.locked: foot.point = support
			foot.locked = true
		elif support_lift > 0.065:
			foot.locked = false
			plant_ready[side] = true
		# A low swing foot is not planted until its world motion slows near landing.
		elif plant_ready[side] and ((support_lift < 0.025 and support_speed < maxf(0.8, speed * 0.75)) or (diagonal_weight > 0.99 and toe_lift < 0.005)):
			foot.point = support
			foot.locked = true
			plant_ready[side] = false
			# The new anchor has zero error, so acquiring it needs no correction fade.
			plant_weights[side] = 1.0
		# Earlier diagonal toe contact needs more travel before stretch release.
		var separation := Vector2(support.x - foot.point.x, support.z - foot.point.z).length()
		if idle == 0.0 and separation > lerpf(0.28, 0.40, diagonal_weight): foot.locked = false
		plant_weights[side] = move_toward(plant_weights[side], 1.0 if foot.locked else 0.0, dt * 12.0)
		var goal := ankle.origin
		# Keep planted support fixed until release rather than sliding toward the next pose.
		goal.x += (foot.point.x - support.x) * plant_weights[side]
		goal.z += (foot.point.z - support.z) * plant_weights[side]
		var floor_y: float = actor.ground_height.call(goal) if actor.ground_height.is_valid() else actor.ground_y
		# Keep a fast swing clear of the ground before it decelerates into contact.
		var swing_clearance := 0.045 * smoothstep(maxf(0.8, speed * 0.75), maxf(1.4, speed * 1.5), support_speed) if not foot.locked else 0.0
		goal.y = floor_y + sole_height + maxf(lift, swing_clearance) * (1.0 - idle * crouch_weight)
		var offset: Vector3 = (goal - ankle.origin)
		# Follow a planted toe quickly; ease released feet back to the authored swing.
		var correction_speed := lerpf(4.0, 6.0, diagonal_weight) if foot.locked else 3.0
		if not foot.locked: correction_speed = lerpf(correction_speed, 1.2, crouch_weight)
		# Bound release distance per pose update so sparse updates do not add a large jump to the swing.
		var correction_step := dt * correction_speed if foot.locked else minf(dt * correction_speed, 0.08)
		var horizontal_offset := Vector2(contact_offsets[side].x, contact_offsets[side].z).move_toward(Vector2(offset.x, offset.z), correction_step)
		contact_offsets[side] = (contact_offsets[side] as Vector3).lerp(offset, follow)
		contact_offsets[side].x = horizontal_offset.x
		contact_offsets[side].z = horizontal_offset.y
		goal = ankle.origin + contact_offsets[side]
		# Ground clearance remains a hard constraint, unlike the contact weight.
		floor_y = actor.ground_height.call(goal) if actor.ground_height.is_valid() else actor.ground_y
		goal.y = maxf(goal.y, floor_y + sole_height)
		var normal: Vector3 = actor.ground_normal.call(goal) if actor.ground_normal.is_valid() else Vector3.UP
		slope_normals[side] = (slope_normals[side] as Vector3).slerp(normal, follow).normalized()
		var hip := actor.joint(prefix + "UpLeg").origin
		var knee := actor.joint(prefix + "Leg").origin
		var length := hip.distance_to(knee) + knee.distance_to(ankle.origin) - 0.004
		var horizontal := Vector2(goal.x - hip.x, goal.z - hip.z).length_squared()
		lower_pelvis = maxf(lower_pelvis, hip.y - goal.y - sqrt(maxf(0.01, length * length - horizontal)))
		goals.append(goal)
		poles.append(knee - hip)
	pelvis_drop = lerpf(pelvis_drop, minf(lower_pelvis, 0.25), follow)
	var pelvis := actor.joint("Hips")
	pelvis.origin.y -= pelvis_drop
	actor.set_world(int(actor.bones["Hips"]), pelvis)
	for side in 2:
		var prefix := "Left" if side == 0 else "Right"
		var before := actor.joint(prefix + "Foot")
		actor.solve_limb(prefix + "UpLeg", prefix + "Leg", prefix + "Foot", goals[side], poles[side])
		var ankle := actor.joint(prefix + "Foot")
		# Apply the slope to the authored toe-off rotation, not a replacement
		# rest pose. Fade it through the contact phase rather than flipping it.
		var tilt := Quaternion.IDENTITY.slerp(Quaternion(Vector3.UP, slope_normals[side]), contact_weights[side])
		# A stopped crouch plants both soles instead of freezing a lifted swing foot.
		var flat_weight := (1.0 - smoothstep(0.05, 0.35, speed)) * crouch_weight
		var foot_basis := before.basis.slerp(actor.global_basis * actor.target_rest[int(actor.bones[prefix + "Foot"])].basis, flat_weight)
		ankle.basis = Basis(tilt) * foot_basis
		actor.set_world(int(actor.bones[prefix + "Foot"]), ankle)
		var correction := ankle.origin - before.origin
		if contacts_sampled and correction.distance_to(previous_corrections[side]) > max_contact_change:
			max_contact_change = correction.distance_to(previous_corrections[side])
			worst_contact_time = elapsed
		previous_corrections[side] = correction
	contacts_sampled = true
