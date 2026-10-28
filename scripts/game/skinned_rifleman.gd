class_name SkinnedRifleman
extends Node3D
## Retarget in rest space, then satisfy contacts on the receiving body. Mesh
## weights and bone lengths stay authored; only the pelvis translates.

var model_asset := "res://assets/local_mocap/character/Soldier.glb"
var native_player: AnimationPlayer
var _native_clip := ""
var native_socket := Transform3D.IDENTITY
var native_support_basis := Basis.IDENTITY
var native_fingers := {}
var native_rifle_arms := {}
var native_hit_clip: Animation
var native_hit_tracks: Array = []
var native_hit_time := INF
var native_hit_strength := 0.0
var native_sockets := {}
var magazine: RefCounted
var source: MocapCharacter
var visual: Node3D
var skeleton: Skeleton3D
var bones := {}
var mapping: Array[int] = []
var corrections: Array[Basis] = []
var target_rest: Array[Transform3D] = []
var weapon: Node3D
var socket := Transform3D.IDENTITY
var support_basis := Basis.IDENTITY
var reaction := ImpactResponse.new()
var dead := false
var ragdoll: SkinnedRagdoll
var ratio := 1.0
var feet := [{"locked": false, "point": Vector3.ZERO}, {"locked": false, "point": Vector3.ZERO}]
var foot_offsets: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var ground_y := 0.0
var kneel_weight := 0.0
var cover_weight := 0.0
var ground_height: Callable
var ground_normal: Callable
const TRANSITION_SECONDS := 0.24
var _pose_mode := -1
var _transition_duration := TRANSITION_SECONDS
var _transition_time := TRANSITION_SECONDS
var _transition_pose: Array[Transform3D] = []
var _transition_gun := Basis.IDENTITY
var grip_error := 0.0
var max_grip_error := 0.0
var foot_error := 0.0
var last_velocity := Vector3.ZERO
var motion_poses := {}
var limb_velocity := {}
var limb_spin := {}
var _last_position := Vector3.ZERO
var _socket_ready := false
var procedural_corrections := {}
var recoil := ImpactResponse.new()
var solve_contacts := true
var hold_weapon := true
var _activity_clip := ""
var _sling_socket := Transform3D.IDENTITY
var shovel: Node3D


func build(clips: Dictionary = MocapCharacter.CLIPS) -> bool:
	source = MocapCharacter.new()
	add_child(source)
	if not source.build(clips):
		return false
	source.visible = false
	if "--swat-units" in OS.get_cmdline_user_args():
		model_asset = "res://assets/local_mocap/mixamo/Swat.fbx"
	if not ResourceLoader.exists(model_asset):
		push_error("Character asset missing: " + model_asset)
		return false
	visual = (load(model_asset) as PackedScene).instantiate()
	add_child(visual)
	visual.rotation.y = PI if model_asset.ends_with(".fbx") else 0.0
	if model_asset.ends_with("Swat.fbx"):
		for mesh in visual.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material: StandardMaterial3D = mesh.mesh.surface_get_material(surface).duplicate()
				# FBX imports the supplied normal maps with zero strength.
				material.normal_scale = 1.0
				material.metallic = 0.0
				material.roughness = 0.85
				material.metallic_specular = 0.25
				mesh.set_surface_override_material(surface, material)

	skeleton = visual.find_children("*", "Skeleton3D", true, false)[0]
	for player in visual.find_children("*", "AnimationPlayer", true, false):
		player.free()
	for i in skeleton.get_bone_count():
		var name := String(skeleton.get_bone_name(i)).replace("mixamorig_", "").replace("mixamorig:", "")
		bones[name] = i
		var src := source.skeleton.find_bone(name)
		mapping.append(src)
		var rest := global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_rest(i)
		rest.basis = rest.basis.orthonormalized()
		target_rest.append(rest)
		var correction := Basis.IDENTITY
		if src >= 0:
			var sr := global_transform.affine_inverse() * source.skeleton.global_transform * source.skeleton.get_bone_global_rest(src)
			correction = sr.basis.orthonormalized().inverse() * rest.basis
		corrections.append(correction)
	ratio = target_rest[int(bones["Hips"])].origin.y / source.skeleton.get_bone_global_rest(int(source.bone_map["Hips"])).origin.y
	if model_asset.ends_with("Swat.fbx"):
		var source_hip := source.global_transform.affine_inverse() * source.skeleton.global_transform * source.skeleton.get_bone_global_rest(int(source.bone_map["Hips"]))
		ratio = target_rest[int(bones["Hips"])].origin.y / source_hip.origin.y
	weapon = source.weapon
	weapon.reparent(self)
	weapon.visible = true
	magazine = load("res://scripts/game/rifle_magazine.gd").new()
	magazine.setup(self)
	_last_position = global_position
	if OS.has_environment("FL_DEBUG_MOCAP"):
		print("SKINNED_RIFLEMAN bones=%d height_ratio=%.3f" % [bones.size(), ratio])
	return true


func pose(dt: float, speed: float, clip := "") -> void:
	if dead:
		if is_instance_valid(ragdoll):
			ragdoll.draw()
		return
	_begin_pose(0)
	if magazine != null: magazine.update(0.0, false)
	weapon.visible = true
	last_velocity = (global_position - _last_position) / maxf(dt, 0.001)
	_last_position = global_position
	source.advance(dt, speed, clip)
	_retarget_source()
	_apply_hit(dt)
	_blend_pose(dt)
	if solve_contacts:
		_ground_feet(speed, dt)
	weapon.visible = hold_weapon
	if hold_weapon:
		_seat_weapon(dt)


func _retarget_source(upper_body: Array[bool] = []) -> void:
	for i in skeleton.get_bone_count():
		if not upper_body.is_empty() and upper_body[i]: continue
		skeleton.set_bone_pose_position(i, skeleton.get_bone_rest(i).origin)
	for i in skeleton.get_bone_count():
		if not upper_body.is_empty() and upper_body[i]: continue
		if mapping[i] < 0:
			continue
		var src := source.skeleton.global_transform * source.skeleton.get_bone_global_pose(mapping[i])
		var current := world_pose(i)
		current.basis = src.basis.orthonormalized() * corrections[i]
		if i == int(bones["Hips"]):
			current.origin = global_position + (src.origin - source.global_position) * ratio
		set_world(i, current)


func world_pose(index: int) -> Transform3D:
	var p := skeleton.global_transform * skeleton.get_bone_global_pose(index)
	p.basis = p.basis.orthonormalized()
	return p


func set_world(index: int, p: Transform3D) -> void:
	var local := skeleton.global_transform.affine_inverse() * p
	local.basis = local.basis.orthonormalized()
	skeleton.set_bone_global_pose(index, local)


func joint(name: String) -> Transform3D:
	return world_pose(int(bones[name]))


## Analytic two-bone IK retains both lengths and the authored bend plane.
func solve_limb(a: String, b: String, c: String, goal: Vector3, pole: Vector3) -> void:
	var ia: int = bones[a]
	var ib: int = bones[b]
	var ic: int = bones[c]
	var pa := world_pose(ia)
	var pb := world_pose(ib)
	var pc := world_pose(ic)
	var upper := pa.origin.distance_to(pb.origin)
	var lower := pb.origin.distance_to(pc.origin)
	var offset := goal - pa.origin
	var distance := clampf(offset.length(), absf(upper - lower) + 0.001, upper + lower - 0.001)
	var axis := offset.normalized()
	var bend := pole - axis * pole.dot(axis)
	if bend.length_squared() < 0.001:
		bend = Vector3.RIGHT - axis * axis.x
	bend = bend.normalized()
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var elbow := pa.origin + axis * along + bend * sqrt(maxf(0.0, upper * upper - along * along))
	pa.basis = Basis(Quaternion((pb.origin - pa.origin).normalized(), (elbow - pa.origin).normalized())) * pa.basis
	set_world(ia, pa)
	pb = world_pose(ib)
	var endpoint := world_pose(ic)
	pb.basis = Basis(Quaternion((endpoint.origin - pb.origin).normalized(), (goal - pb.origin).normalized())) * pb.basis
	set_world(ib, pb)
	endpoint = world_pose(ic)
	endpoint.basis = pc.basis
	set_world(ic, endpoint)


func _ground_feet(speed: float, dt: float) -> void:
	var goals: Array[Vector3] = []
	var lower_pelvis := 0.0
	for side in 2:
		var prefix := "Left" if side == 0 else "Right"
		var ankle := joint(prefix + "Foot")
		var sample_point: Vector3 = feet[side].point if feet[side].locked else ankle.origin
		var height: float = ground_height.call(sample_point) if ground_height.is_valid() else ground_y
		var floor_height := height + target_rest[int(bones[prefix + "Foot"])].origin.y
		var src_index: int = source.bone_map[prefix + "Foot"]
		var src := source.skeleton.get_bone_global_pose(src_index).origin
		var src_rest := source.skeleton.get_bone_global_rest(src_index).origin
		var planted := speed < 0.2 or src.y < src_rest.y + 0.045
		var state: Dictionary = feet[side]
		if planted and not state.locked:
			state.point = Vector3(ankle.origin.x, floor_height, ankle.origin.z)
		state.locked = planted
		var goal := ankle.origin
		if planted:
			goal = state.point
			goal.y = floor_height
		else:
			goal.y = maxf(goal.y, floor_height + maxf(0.0, src.y - src_rest.y) * ratio)
		if goal.distance_to(ankle.origin) > 0.35:
			state.locked = false
			goal.x = ankle.origin.x
			goal.z = ankle.origin.z
		# Release a stretched plant over several frames instead of snapping to the moving clip.
		var offset := Vector2(goal.x - ankle.origin.x, goal.z - ankle.origin.z)
		foot_offsets[side] = foot_offsets[side].move_toward(offset, dt * 4.0)
		goal.x = ankle.origin.x + foot_offsets[side].x
		goal.z = ankle.origin.z + foot_offsets[side].y
		var hip := joint(prefix + "UpLeg").origin
		var knee := joint(prefix + "Leg").origin
		var length := hip.distance_to(knee) + knee.distance_to(ankle.origin) - 0.004
		var horizontal := Vector2(goal.x - hip.x, goal.z - hip.z).length_squared()
		var reach_y := sqrt(maxf(0.01, length * length - horizontal))
		lower_pelvis = maxf(lower_pelvis, hip.y - goal.y - reach_y)
		goals.append(goal)
	if lower_pelvis > 0.0:
		var pelvis := joint("Hips")
		pelvis.origin.y -= minf(lower_pelvis, 0.2)
		set_world(int(bones["Hips"]), pelvis)
	for side in 2:
		var prefix := "Left" if side == 0 else "Right"
		solve_limb(prefix + "UpLeg", prefix + "Leg", prefix + "Foot", goals[side], global_basis * Vector3.FORWARD)
		if feet[side].locked:
			var foot := joint(prefix + "Foot")
			foot.basis = global_basis * target_rest[int(bones[prefix + "Foot"])].basis
			set_world(int(bones[prefix + "Foot"]), foot)
			foot_error = maxf(foot_error, foot.origin.distance_to(goals[side]))


func ground_kneel(dt: float, planted: bool, mounted := false) -> void:
	kneel_weight = move_toward(kneel_weight, 1.0 if planted else 0.0, dt * 6.0)
	var weight := kneel_weight * smoothstep(0.0, _transition_duration, _transition_time)
	if weight <= 0.0: return
	for prefix in ["Left", "Right"]:
		var ankle := joint(prefix + "Foot")
		var knee := joint(prefix + "Leg").origin
		var hip := joint(prefix + "UpLeg").origin
		var goal := ankle.origin
		if mounted and prefix == "Left":
			# Keep the supporting boot beside the gunner, clear of the tripod platform.
			goal = global_position + global_basis * Vector3(-0.3, 0, 0.05)
			knee = hip + global_basis * Vector3(-1, 0, -0.1)
		var floor_y: float = ground_height.call(goal) if ground_height.is_valid() else ground_y
		var desired := ankle.basis
		if prefix == "Left":
			# The forward foot supports his weight; the trailing knee stays folded.
			desired = global_basis * target_rest[int(bones[prefix + "Foot"])].basis
			goal.y = floor_y + target_rest[int(bones[prefix + "Foot"])].origin.y
		else:
			var toe_offset := joint(prefix + "ToeBase").origin - ankle.origin
			var toe_clearance := target_rest[int(bones[prefix + "ToeBase"])].origin.y
			goal.y = floor_y + toe_clearance - toe_offset.y
		goal = ankle.origin.lerp(goal, weight)
		solve_limb(prefix + "UpLeg", prefix + "Leg", prefix + "Foot", goal, knee - hip)
		var corrected := joint(prefix + "Foot")
		corrected.basis = ankle.basis.slerp(desired, weight)
		set_world(int(bones[prefix + "Foot"]), corrected)


func ground_cover(dt: float, planted: bool) -> void:
	cover_weight = move_toward(cover_weight, 1.0 if planted else 0.0, dt * 6.0)
	var weight := cover_weight * smoothstep(0.0, _transition_duration, _transition_time)
	for prefix in ["Left", "Right"]:
		var ankle := joint(prefix + "Foot")
		var hip := joint(prefix + "UpLeg").origin
		var knee := joint(prefix + "Leg").origin
		var goal := ankle.origin
		var height: float = ground_height.call(goal) if ground_height.is_valid() else ground_y
		var normal: Vector3 = ground_normal.call(goal) if ground_normal.is_valid() else Vector3.UP
		goal.y = height + target_rest[int(bones[prefix + "Foot"])].origin.y / maxf(normal.y, 0.2)
		# The procedural rig's leg proportions must not push the receiving boots underground.
		solve_limb(prefix + "UpLeg", prefix + "Leg", prefix + "Foot", ankle.origin.lerp(goal, weight), knee - hip)
		var foot := joint(prefix + "Foot")
		var planted_basis := Basis(Quaternion(Vector3.UP, normal)) * global_basis * target_rest[int(bones[prefix + "Foot"])].basis
		foot.basis = ankle.basis.slerp(planted_basis, weight)
		set_world(int(bones[prefix + "Foot"]), foot)


func _seat_weapon(dt: float, authored_gun: Node3D = null, minimum_muzzle_y := -INF) -> void:
	var hand_pose := joint("RightHand")
	if not _socket_ready:
		if native_player != null:
			# Cover poses use the same calibrated hand attachment as captured rifle motion.
			socket = native_socket
			# Fallback poses restore this rig's own finger lengths.
			socket.origin = hand_pose.affine_inverse() * joint("RightHandMiddle1").origin + socket.basis.y * 0.035
			support_basis = native_support_basis
		else:
			var grip := hand_pose.origin.lerp(joint("RightHandMiddle1").origin, 0.65)
			var aim := Transform3D(global_basis * Basis(Vector3.UP, PI), grip + Vector3.UP * 0.035)
			socket = hand_pose.affine_inverse() * aim
			support_basis = aim.basis.inverse() * joint("LeftHand").basis
		_socket_ready = true
	if authored_gun != null:
		# Unsupported sample actions still have an authored gameplay aim axis.
		# Match that axis through the hand socket instead of inheriting wrist roll.
		hand_pose.basis = authored_gun.global_basis * Basis(Vector3.UP, PI) * socket.basis.inverse()
		set_world(int(bones["RightHand"]), hand_pose)
	if _transition_time < _transition_duration:
		var weight := smoothstep(0.0, _transition_duration, _transition_time)
		var desired := (hand_pose * socket).basis
		hand_pose.basis = _transition_gun.slerp(desired, weight) * socket.basis.inverse()
		set_world(int(bones["RightHand"]), hand_pose)
	var gun_pose := hand_pose * socket
	gun_pose.origin += global_basis * recoil.step(dt)
	# The receiving arms differ from the procedural rig; keep the barrel above its cover.
	gun_pose.origin.y = maxf(gun_pose.origin.y, minimum_muzzle_y - (gun_pose.basis * Vector3(0, 0.03, 0.6)).y)
	var left := joint("LeftHand")
	left.basis = gun_pose.basis * support_basis
	set_world(int(bones["LeftHand"]), left)
	var finger_offset := (joint("LeftHandMiddle1").origin - left.origin) * 0.65
	var right_goal := hand_pose.origin + gun_pose.origin - (hand_pose * socket).origin
	# Different shoulder widths can put an otherwise valid socket just beyond
	# the support arm's reach. Move the held assembly, then solve both arms;
	# never stretch a forearm or let either hand detach from its grip.
	for iteration in 3:
		var shifted := false
		var support := gun_pose * Vector3(0, 0.055, 0.26) - finger_offset
		for side in ["Left", "Right"]:
			var shoulder := joint(side + "Arm").origin
			var elbow := joint(side + "ForeArm").origin
			var wrist := joint(side + "Hand").origin
			var reach := shoulder.distance_to(elbow) + elbow.distance_to(wrist) - 0.008
			var goal := support if side == "Left" else right_goal
			var delta := goal - shoulder
			if delta.length() > reach:
				var shift := shoulder + delta.normalized() * reach - goal
				gun_pose.origin += shift
				right_goal += shift
				shifted = true
		if not shifted: break
	solve_limb("RightArm", "RightForeArm", "RightHand", right_goal, global_basis * Vector3(1,-0.5,0.2))
	weapon.global_transform = joint("RightHand") * socket
	var support := weapon.global_transform * Vector3(0, 0.055, 0.26)
	solve_limb("LeftArm", "LeftForeArm", "LeftHand", support - finger_offset, global_basis * Vector3(-1, -0.5, 0.2))
	grip_error = joint("LeftHand").origin.distance_to(support - finger_offset)
	max_grip_error = maxf(max_grip_error, grip_error)



func hit(direction: Vector3, strength := 1.0) -> void:
	reaction.kick(Vector3(direction.z, direction.x * 0.25, -direction.x) * strength * 2.5)
	# Further impacts add momentum without rewinding or erasing the current flinch.
	if native_hit_clip != null and native_hit_time < native_hit_clip.length and native_hit_strength > 0.0:
		return
	native_hit_time = 0.0
	# This clip recoils backward; do not play it against side or rear impacts.
	var frontal := maxf(0.0, direction.normalized().dot(global_basis.z.normalized()))
	native_hit_strength = clampf(strength, 0.0, 1.0) * 0.35 * frontal * frontal


func kill(impulse: Vector3, kind := 1) -> void:
	if dead:
		return
	dead = true
	ragdoll = SkinnedRagdoll.new()
	get_parent().add_child(ragdoll)
	ragdoll.build(self, last_velocity, impulse, kind)


func capture_motion(dt: float) -> void:
	if dead: return
	if dt <= 0.0 or dt > 0.1:
		motion_poses.clear()
		limb_velocity.clear()
		limb_spin.clear()
		return
	var skeleton_world := skeleton.global_transform
	for part in SkinnedRagdoll.PARTS:
		_sample_motion(part[0], skeleton_world * skeleton.get_bone_global_pose(int(bones[part[0]])), dt)
	_sample_motion("weapon", weapon.global_transform, dt)
	if magazine.mesh != null and magazine.mesh.visible:
		_sample_motion("magazine", magazine.mesh.global_transform, dt)
	else:
		motion_poses.erase("magazine")
		limb_velocity.erase("magazine")
		limb_spin.erase("magazine")
	if shovel != null and shovel.visible:
		_sample_motion("tool", shovel.global_transform, dt)
	else:
		motion_poses.erase("tool")
		limb_velocity.erase("tool")
		limb_spin.erase("tool")


func _sample_motion(name: String, pose: Transform3D, dt: float) -> void:
	# Travel is supplied by gameplay; retain only motion around the actor root.
	pose.origin -= global_position
	# Store a unit basis once; its transpose is the inverse next frame.
	pose.basis = pose.basis.orthonormalized()
	if motion_poses.has(name):
		var previous: Transform3D = motion_poses[name]
		limb_velocity[name] = ((pose.origin - previous.origin) / dt).limit_length(8.0)
		var rotation := (pose.basis * previous.basis.transposed()).get_rotation_quaternion()
		var angle := wrapf(rotation.get_angle(), -PI, PI)
		limb_spin[name] = (rotation.get_axis() * angle / dt).limit_length(12.0)
	motion_poses[name] = pose


func bind_procedural(model) -> void:
	var old_l: Vector3 = model.arm_l.rotation
	var old_r: Vector3 = model.arm_r.rotation
	model.arm_l.rotation.z = -PI * 0.5
	model.arm_r.rotation.z = PI * 0.5
	for key in MocapRetarget.MAP:
		var name: String = MocapRetarget.MAP[key]
		var node: Node3D = model.get(key)
		var rest := global_basis.inverse() * node.global_basis
		procedural_corrections[key] = rest.inverse() * target_rest[int(bones[name])].basis
	model.arm_l.rotation = old_l
	model.arm_r.rotation = old_r
	var slung: Transform3D = model.torso.global_transform * Transform3D(Basis.from_euler(Vector3(0.8, PI * 0.5, 0)) * Basis(Vector3.UP, PI), Vector3(0, 0.32, 0.2))
	_sling_socket = (global_transform * target_rest[int(bones["Spine2"])]).affine_inverse() * slung


func pose_procedural(model, dt: float, posture := -1) -> void:
	if dead: return
	# A posture change must blend from the corrected skin, including contact IK.
	# A slide changes the whole body even when the gameplay posture remains crouched.
	_begin_pose(20 + posture if model.last_act == Soldier.Act.SLIDE else (3 + posture if posture >= 0 else 1))
	if magazine != null: magazine.update(0.0, false)
	last_velocity = (global_position - _last_position) / maxf(dt, 0.001)
	_last_position = global_position
	for state in feet: state.locked = false
	# Contact IK leaves local counter-rotations on feet and spine. Clear those
	# before transferring a crouch/prone pose, so the soles follow the shins.
	for name in ["Spine", "Spine1", "Neck", "LeftShoulder", "RightShoulder", "LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
		if bones.has(name):
			var index: int = bones[name]
			skeleton.set_bone_pose_rotation(index, skeleton.get_bone_rest(index).basis.get_rotation_quaternion())
	for i in skeleton.get_bone_count():
		skeleton.set_bone_pose_position(i, skeleton.get_bone_rest(i).origin)
	# Weapon grips must not inherit the last reload's open fingers.
	if model.crew or (model.gun.visible and not model.weapon_slung):
		for index in native_fingers:
			skeleton.set_bone_pose_rotation(index, native_fingers[index])
	# Unsupported sample actions retain the gameplay pose on this same skin.
	for key in MocapRetarget.MAP:
		var name: String = MocapRetarget.MAP[key]
		var index: int = bones[name]
		var node: Node3D = model.get(key)
		var p := world_pose(index)
		p.basis = node.global_basis * (procedural_corrections[key] as Basis)
		if key == "hips":
			p.origin = global_position + (node.global_position - global_position) * ratio
		set_world(index, p)
	if posture in [Soldier.Post.LEAN_L, Soldier.Post.LEAN_R] and model.gun.visible and not model.weapon_slung and not model.crew:
		# Keep the captured rifle hold while the torso leans around cover.
		for index in native_rifle_arms:
			skeleton.set_bone_pose_rotation(index, native_rifle_arms[index])
	_apply_hit(dt)
	_blend_pose(dt)
	if model.crew:
		var spine := joint("Spine")
		spine.basis = Basis(global_basis.x.normalized(), -0.22) * spine.basis
		set_world(int(bones["Spine"]), spine)
		# Mounted grips belong to the gun; solve this skin's lengths after pose blending.
		for side in ["Left", "Right"]:
			var hand := joint(side + "Hand")
			hand.basis = global_basis * target_rest[int(bones[side + "Hand"])].basis
			set_world(int(bones[side + "Hand"]), hand)
			var palm_offset := (joint(side + "HandMiddle1").origin - hand.origin) * 0.65
			var target: Vector3 = model.crew_l if side == "Left" else model.crew_r
			var outward := -1.0 if side == "Left" else 1.0
			solve_limb(side + "Arm", side + "ForeArm", side + "Hand", target - palm_offset, global_basis * Vector3(outward, -0.5, 0.2))
	weapon.visible = model.gun.visible
	if weapon.visible:
		if model.weapon_slung:
			# A back-mounted rifle must not pull either hand out of the activity pose.
			weapon.global_transform = model.gun.global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		else:
			_seat_weapon(dt, model.gun, global_position.y + model.cover_h + 0.05 if model.over_wall else -INF)


func revive() -> void:
	if not dead: return
	if is_instance_valid(ragdoll): ragdoll.finish()
	dead = false
	reset_motion()
	_pose_mode = -1
	_transition_time = _transition_duration
	_socket_ready = false
	for state in feet: state.locked = false


func reset_motion() -> void:
	foot_offsets = [Vector2.ZERO, Vector2.ZERO]
	for foot in feet: foot.locked = false
	motion_poses.clear()
	limb_velocity.clear()
	limb_spin.clear()
	last_velocity = Vector3.ZERO
	_last_position = global_position
	reaction.offset = Vector3.ZERO
	reaction.velocity = Vector3.ZERO
	native_hit_time = INF
	recoil.offset = Vector3.ZERO
	recoil.velocity = Vector3.ZERO


func fire_kick(strength: float) -> void:
	recoil.kick(Vector3(0, 0, minf(strength, 1.5) * 0.5))


func _begin_pose(mode: int) -> void:
	if shovel != null: shovel.visible = mode == 21
	if mode == _pose_mode: return
	foot_offsets = [Vector2.ZERO, Vector2.ZERO]
	if _pose_mode >= 0:
		# Lowering or lifting the whole body needs longer than an aiming crossfade.
		_transition_duration = 0.65 if mode >= 3 or _pose_mode >= 3 else TRANSITION_SECONDS
		_transition_pose.resize(skeleton.get_bone_count())
		for i in skeleton.get_bone_count():
			_transition_pose[i] = skeleton.get_bone_pose(i)
		_transition_gun = weapon.global_basis.orthonormalized()
		_transition_time = 0.0
	_pose_mode = mode


func _blend_pose(dt: float) -> void:
	if _transition_time >= _transition_duration: return
	_transition_time = minf(_transition_time + dt, _transition_duration)
	var weight := smoothstep(0.0, _transition_duration, _transition_time)
	# Blend rotations and pelvis height before solving contacts. Blending the
	# final IK result would pull planted feet and hands away from their anchors.
	for i in skeleton.get_bone_count():
		var target := skeleton.get_bone_pose(i)
		skeleton.set_bone_pose(i, _transition_pose[i].interpolate_with(target, weight))


func _apply_hit(dt: float) -> void:
	# Every living stance receives the same impact layer before the hands are
	# seated on the rifle. Crouching or going prone must not swallow the hit.
	var hit := reaction.step(dt)
	if native_hit_clip != null and native_hit_time < native_hit_clip.length:
		native_hit_time += dt
		var t := minf(native_hit_time, native_hit_clip.length)
		var weight := native_hit_strength * smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(native_hit_clip.length - 0.12, native_hit_clip.length, t))
		# Add the captured flinch without replacing locomotion, grips or planted feet.
		for entry in native_hit_tracks:
			var rotation: Quaternion = native_hit_clip.rotation_track_interpolate(entry[1], t)
			var delta: Quaternion = entry[2].inverse() * rotation
			skeleton.set_bone_pose_rotation(entry[0], skeleton.get_bone_pose_rotation(entry[0]) * Quaternion.IDENTITY.slerp(delta, weight))
	if hit.is_zero_approx(): return
	for name in ["Spine", "Spine1", "Spine2"]:
		var index: int = bones[name]
		var current := world_pose(index)
		current.basis = Basis.from_euler(hit / 3.0) * current.basis
		set_world(index, current)


func apply_native_recoil(dt: float, weapon_socket: Transform3D) -> void:
	var kick := recoil.step(dt).z
	if is_zero_approx(kick): return
	# Rotate the captured arms and rifle together so recoil cannot separate either grip.
	var axis := (joint("RightHand") * weapon_socket).basis.x.normalized()
	var spine := joint("Spine2")
	spine.basis = Basis(axis, -kick * 3.0) * spine.basis
	set_world(int(bones["Spine2"]), spine)


func pose_native(dt: float, clip: String) -> void:
	if dead:
		if is_instance_valid(ragdoll): ragdoll.draw()
		return
	_begin_pose(2)
	if _native_clip != clip:
		native_player.play(clip, 0.0)
		_native_clip = clip
	native_player.advance(dt)
	_apply_hit(dt)
	_blend_pose(dt)
	apply_native_recoil(dt, native_sockets.get(clip, native_socket))
	# These previews preserve the captured limbs, including hand releases in
	# reloads and transitions. Weapon placement follows one fixed hand socket.
	var hand_pose := joint("RightHand")
	weapon.global_transform = hand_pose * native_sockets.get(clip, native_socket)
	weapon.visible = hold_weapon
	magazine.update(native_player.current_animation_position, "reloading" in clip)
	last_velocity = Vector3.ZERO


func pose_activity(dt: float, clip: String) -> void:
	_begin_pose(21 if clip.ends_with("Digging") else 20)
	if _activity_clip != clip or native_player.current_animation != clip:
		native_player.play(clip, 0.0)
		_activity_clip = clip
	native_player.advance(dt)
	_apply_hit(dt)
	_blend_pose(dt)
	_ground_feet(0.0, dt)
	# The sling follows the captured torso, leaving both hands free.
	weapon.global_transform = joint("Spine2") * _sling_socket
	weapon.visible = true
	if clip.ends_with("Digging"):
		if shovel == null:
			shovel = Node3D.new()
			add_child(shovel)
			var shaft := MeshInstance3D.new()
			var handle := CylinderMesh.new()
			handle.top_radius = 0.014
			handle.bottom_radius = 0.014
			handle.height = 1.1
			shaft.mesh = handle
			var wood := StandardMaterial3D.new()
			wood.albedo_color = Color(0.22, 0.13, 0.06)
			wood.roughness = 0.85
			shaft.material_override = wood
			shovel.add_child(shaft)
			var blade := MeshInstance3D.new()
			var spade := BoxMesh.new()
			spade.size = Vector3(0.2, 0.28, 0.025)
			blade.mesh = spade
			blade.position.y = -0.64
			var steel := StandardMaterial3D.new()
			steel.albedo_color = Color(0.13, 0.15, 0.14)
			steel.metallic = 0.65
			steel.roughness = 0.6
			blade.material_override = steel
			shovel.add_child(blade)
		var right := joint("RightHandMiddle1").origin
		var left := joint("LeftHandMiddle1").origin
		var up := (right - left).normalized()
		var forward := global_basis.z.slide(up).normalized()
		if forward.length_squared() < 0.01: forward = global_basis.x.slide(up).normalized()
		shovel.global_transform = Transform3D(Basis(up.cross(forward).normalized(), up, forward), right - up * 0.22)
	magazine.update(0.0, false)
	last_velocity = Vector3.ZERO


func calibrate_native_weapon() -> void:
	var hand_pose := joint("RightHand")
	var right := joint("RightHandMiddle1").origin
	var left := joint("LeftHandMiddle1").origin
	var span := left - right
	var horizontal := Vector3(span.x, 0, span.z)
	var pitch := atan2(span.y, horizontal.length()) - atan2(0.045, 0.26)
	var forward := horizontal.normalized() * cos(pitch) + Vector3.UP * sin(pitch)
	var orientation := Basis.looking_at(forward, Vector3.UP, true)
	native_socket = hand_pose.affine_inverse() * Transform3D(orientation, right + orientation.y * 0.035)
