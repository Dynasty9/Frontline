extends RefCounted
## Mixamo clips stay in separate pack namespaces; matching filenames can differ.
static var libraries := {}
const ROOT := "res://assets/local_mocap/mixamo/"

static func files() -> Dictionary:
	var result := {}
	for folder in ["shooter", "basic_shooter", "activities"]:
		for file in DirAccess.get_files_at(ROOT + folder):
			file = file.trim_suffix(".remap")
			if file.to_lower().ends_with(".fbx"):
				result["mixamo_" + folder + "__" + file.get_basename().replace(" ", "_")] = ROOT + folder + "/" + file
	if ResourceLoader.exists(ROOT + "Rifle Kneel To Prone.fbx"):
		result["mixamo_transition__Rifle_Kneel_To_Prone"] = ROOT + "Rifle Kneel To Prone.fbx"
	return result

static func install(actor: SkinnedRifleman, gameplay := false) -> Dictionary:
	var paths := files()
	if gameplay:
		for key in paths.keys():
			if not key.begins_with("mixamo_basic_shooter__") and not key.begins_with("mixamo_activities__") and key != "mixamo_transition__Rifle_Kneel_To_Prone": paths.erase(key)
	actor.native_player = AnimationPlayer.new()
	actor.native_player.name = "MixamoClips"
	actor.add_child(actor.native_player)
	actor.native_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var cache_key := actor.model_asset + str(gameplay)
	var library: AnimationLibrary = libraries.get(cache_key)
	if library == null:
		library = AnimationLibrary.new()
		for key in paths:
			var scene := (load(paths[key]) as PackedScene).instantiate()
			var players := scene.find_children("*", "AnimationPlayer", true, false)
			var rigs := scene.find_children("*", "Skeleton3D", true, false)
			if players.is_empty() or rigs.is_empty():
				push_error("Mixamo animation missing: " + str(paths[key]))
				scene.free()
				continue
			var source: Skeleton3D = rigs[0]
			var player: AnimationPlayer = players[0]
			var animation: Animation
			if player.has_animation("mixamo_com"):
				animation = player.get_animation("mixamo_com").duplicate(true)
			else:
				for name in player.get_animation_list():
					if name != "RESET" and name != "Take 001":
						animation = player.get_animation(name).duplicate(true)
						break
			if animation == null:
				scene.free()
				continue
			for track in range(animation.get_track_count() - 1, -1, -1):
				var bone := String(animation.track_get_path(track).get_concatenated_subnames())
				var canonical := bone.replace("mixamorig_", "").replace("mixamorig:", "")
				if not actor.bones.has(canonical):
					animation.remove_track(track)
					continue
				var index: int = actor.bones[canonical]
				animation.track_set_path(track, NodePath(String(actor.get_path_to(actor.skeleton)) + ":" + String(actor.skeleton.get_bone_name(index))))
			# FBX may omit constant tracks. Restore every bone's defaults at each
			# clip so a reload cannot leave fingers in the previous aiming pose.
			for i in source.get_bone_count():
				var canonical := String(source.get_bone_name(i)).replace("mixamorig_", "").replace("mixamorig:", "")
				if not actor.bones.has(canonical): continue
				var target: int = actor.bones[canonical]
				var path := NodePath(String(actor.get_path_to(actor.skeleton)) + ":" + String(actor.skeleton.get_bone_name(target)))
				var rest := source.get_bone_rest(i)
				if animation.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
					var track := animation.add_track(Animation.TYPE_ROTATION_3D)
					animation.track_set_path(track, path)
					animation.rotation_track_insert_key(track, 0.0, rest.basis.get_rotation_quaternion())
				if animation.find_track(path, Animation.TYPE_POSITION_3D) < 0:
					var track := animation.add_track(Animation.TYPE_POSITION_3D)
					animation.track_set_path(track, path)
					animation.position_track_insert_key(track, 0.0, rest.origin)
			_retarget(animation, source, actor)
			animation.loop_mode = Animation.LOOP_LINEAR
			for action in ["transition", "reloading", "hit_reaction", "dying", "toss", "jump", "start", "stop", "turn", "Entering", "Exiting"]:
				if action in key: animation.loop_mode = Animation.LOOP_NONE
			library.add_animation(key, animation)
			scene.free()
		libraries[cache_key] = library
	actor.native_player.add_animation_library("", library)
	var hit_key := "mixamo_basic_shooter__hit_reaction"
	if library.has_animation(hit_key):
		actor.native_hit_clip = library.get_animation(hit_key)
		actor.native_hit_tracks.clear()
		for name in ["Spine", "Spine1", "Spine2", "Neck", "Head"]:
			var index: int = actor.bones[name]
			var path := NodePath(String(actor.get_path_to(actor.skeleton)) + ":" + String(actor.skeleton.get_bone_name(index)))
			var track := actor.native_hit_clip.find_track(path, Animation.TYPE_ROTATION_3D)
			if track >= 0:
				actor.native_hit_tracks.append([index, track, actor.native_hit_clip.rotation_track_interpolate(track, 0.0)])
	actor.native_player.play("mixamo_basic_shooter__rifle_aiming_idle", 0.0)
	actor.native_player.advance(0.0)
	actor.calibrate_native_weapon()
	var aim_socket := actor.native_socket
	for side in ["Left", "Right"]:
		for part in ["Shoulder", "Arm", "ForeArm", "Hand"]:
			var index: int = actor.bones[side + part]
			actor.native_rifle_arms[index] = actor.skeleton.get_bone_pose_rotation(index)
	for name in actor.bones:
		if "Hand" in name and not name.ends_with("Hand"):
			var index: int = actor.bones[name]
			actor.native_fingers[index] = actor.skeleton.get_bone_pose_rotation(index)
	actor.native_support_basis = (actor.joint("RightHand") * aim_socket).basis.inverse() * actor.joint("LeftHand").basis
	actor._socket_ready = false
	for key in paths:
		if "reloading" not in key: continue
		actor.native_player.play(key, 0.0)
		actor.native_player.advance(0.0)
		actor.calibrate_native_weapon()
		actor.native_sockets[key] = actor.native_socket
		actor.native_player.seek(0.4, true)
		actor.weapon.global_transform = actor.joint("RightHand") * actor.native_socket
		actor.magazine.calibrate()
	actor.native_socket = aim_socket
	actor.native_player.play("mixamo_basic_shooter__rifle_aiming_idle", 0.0)
	actor.native_player.advance(0.0)
	return paths


static func _retarget(animation: Animation, source: Skeleton3D, actor: SkinnedRifleman) -> void:
	var source_space := source.transform
	var parent := source.get_parent() as Node3D
	while parent != null:
		source_space = parent.transform * source_space
		parent = parent.get_parent() as Node3D
	source_space = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * source_space
	var target_space := actor.global_transform.affine_inverse() * actor.skeleton.global_transform
	var space := target_space.basis.inverse() * source_space.basis
	var source_bones := {}
	var corrections := {}
	for i in source.get_bone_count():
		var name := String(source.get_bone_name(i)).replace("mixamorig_", "").replace("mixamorig:", "")
		if not actor.bones.has(name): continue
		source_bones[name] = i
		var target: int = actor.bones[name]
		corrections[i] = (source_space.basis * source.get_bone_global_rest(i).basis).orthonormalized().inverse() * (target_space.basis * actor.skeleton.get_bone_global_rest(target).basis).orthonormalized()
	var source_hips: int = source_bones["Hips"]
	var source_height := (source_space * source.get_bone_global_rest(source_hips)).origin.y
	var motion_scale := actor.target_rest[int(actor.bones["Hips"])].origin.y / source_height
	for track in animation.get_track_count():
		var name := String(animation.track_get_path(track).get_concatenated_subnames()).replace("mixamorig_", "").replace("mixamorig:", "")
		if not source_bones.has(name): continue
		var src: int = source_bones[name]
		var target: int = actor.bones[name]
		var rest := actor.skeleton.get_bone_rest(target)
		var kind := animation.track_get_type(track)
		if kind == Animation.TYPE_ROTATION_3D:
			var parent_correction: Basis = corrections.get(source.get_bone_parent(src), source_space.basis.orthonormalized().inverse() * target_space.basis.orthonormalized())
			for frame in animation.track_get_key_count(track):
				var rotation: Quaternion = animation.track_get_key_value(track, frame)
				animation.track_set_key_value(track, frame, (parent_correction.inverse() * Basis(rotation) * corrections[src]).get_rotation_quaternion())
		elif kind == Animation.TYPE_POSITION_3D:
			var base := source.get_bone_rest(src).origin
			if name == "Hips" and animation.track_get_key_count(track) > 1:
				var travel: Vector3 = animation.track_get_key_value(track, animation.track_get_key_count(track) - 1) - animation.track_get_key_value(track, 0)
				travel.y = 0.0
				animation.set_meta("root_travel", space * travel * motion_scale)
			for frame in animation.track_get_key_count(track):
				var offset := Vector3.ZERO
				if name == "Hips":
					var position: Vector3 = animation.track_get_key_value(track, frame)
					offset = space * Vector3(0, position.y - base.y, 0) * motion_scale
				# Animation translations must not replace the receiving body's limb lengths.
				animation.track_set_key_value(track, frame, rest.origin + offset)
