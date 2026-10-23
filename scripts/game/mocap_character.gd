class_name MocapCharacter
extends Node3D
## Local evaluation adapter for the MotusMan v55 source rig. One AnimationTree
## blends the shared clips; the server would supply speed, never bone transforms.

const BASE := "res://assets/local_mocap/FBX/"
const CLIPS := {
	"idle": "Animation/Rifle/Animation/Root_Motion/W2_Stand_Aim_Idle_v2.fbx",
	"walk": "Animation/Rifle/Animation/In-Place/W2_Walk_Aim_F_Loop_IPC.fbx",
	"jog": "Animation/Rifle/Animation/In-Place/W2_Jog_Aim_F_Loop_IPC.fbx",
	"relax": "Animation/Rifle/Animation/Root_Motion/W2_Stand_Aim_To_Relaxed.fbx",
	"relaxed": "Animation/Rifle/Animation/Root_Motion/W2_Stand_Relaxed_Idle_v2.fbx",
	"crouch": "Animation/Mobility/IPC/MOB1_CrouchWalk_F_IPC.fbx",
}

static var shared_library: AnimationLibrary

var skeleton: Skeleton3D
var player: AnimationPlayer
var tree: AnimationTree
var character: Node3D
var weapon: Node3D
var hand := -1
var bone_map := {}
var rest_global := {}
var _clip := ""
var weapon_socket := Transform3D.IDENTITY


func build(clips: Dictionary = CLIPS) -> bool:
	var asset := BASE + "MotusMan/MotusMan_v55.fbx"
	if not ResourceLoader.exists(asset):
		push_error("Run tests/mocap/prepare_assets.py with the demo ZIP, then import the project.")
		return false
	character = (load(asset) as PackedScene).instantiate()
	for camera in character.find_children("*", "Camera3D", true, false):
		camera.free()
	add_child(character)
	character.rotation.y = PI  # the vendor faces +Z; Frontline faces -Z
	skeleton = character.find_children("*", "Skeleton3D", true, false)[0]
	for i in skeleton.get_bone_count():
		bone_map[skeleton.get_bone_name(i)] = i
		rest_global[skeleton.get_bone_name(i)] = skeleton.get_bone_global_rest(i)
	# The FBX contains old absolute texture paths. Bind the supplied texture
	# explicitly instead of depending on the artist's original folder layout.
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(BASE + "MotusMan/MotusMan_v55.fbm/MCG_diff.jpg")
	material.roughness = 0.72
	for mesh in character.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material
	for old in character.find_children("*", "AnimationPlayer", true, false):
		(old as AnimationPlayer).stop()
		old.queue_free()
	player = AnimationPlayer.new()
	player.name = "Clips"
	add_child(player)
	var library: AnimationLibrary = shared_library if clips == CLIPS else null
	if library == null:
		library = AnimationLibrary.new()
		for key in clips:
			var source := (load(BASE + clips[key]) as PackedScene).instantiate()
			var players := source.find_children("*", "AnimationPlayer", true, false)
			if players.is_empty():
				push_error("No animation in " + clips[key])
				source.free()
				return false
			var imported: AnimationPlayer = players[0]
			var source_skeleton: Skeleton3D = source.find_children("*", "Skeleton3D", true, false)[0]
			var animation: Animation
			for name in imported.get_animation_list():
				if name != "RESET":
					animation = imported.get_animation(name).duplicate(true)
					break
			if animation == null:
				source.free()
				return false
			for track in range(animation.get_track_count() - 1, -1, -1):
				var path := animation.track_get_path(track)
				var bone := String(path.get_concatenated_subnames())
				if not bone_map.has(bone):
					animation.remove_track(track)
					continue
				animation.track_set_path(track, NodePath(String(get_path_to(skeleton)) + ":" + bone))
				if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and bone == "Hips":
					# In-place locomotion keeps body bob, but never moves the entity.
					var rest: Vector3 = skeleton.get_bone_rest(int(bone_map[bone])).origin
					for k in animation.track_get_key_count(track):
						var value: Vector3 = animation.track_get_key_value(track, k)
						value.x = rest.x
						value.z = rest.z
						animation.track_set_key_value(track, k, value)
			# FBX removes constant tracks. Carry those constants across too, or
			# fingers/shoulders silently inherit the target mesh's T pose.
			for bone_name in bone_map:
				var source_index := source_skeleton.find_bone(bone_name)
				if source_index < 0:
					continue
				var path := NodePath(String(get_path_to(skeleton)) + ":" + bone_name)
				var rest := source_skeleton.get_bone_rest(source_index)
				if animation.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
					var track := animation.add_track(Animation.TYPE_ROTATION_3D)
					animation.track_set_path(track, path)
					animation.rotation_track_insert_key(track, 0.0, rest.basis.get_rotation_quaternion())
				if animation.find_track(path, Animation.TYPE_POSITION_3D) < 0 and bone_name != "Hips":
					var track := animation.add_track(Animation.TYPE_POSITION_3D)
					animation.track_set_path(track, path)
					animation.position_track_insert_key(track, 0.0, rest.origin)
			animation.loop_mode = Animation.LOOP_NONE if key == "relax" else Animation.LOOP_LINEAR
			library.add_animation(key, animation)
			source.free()
		if clips == CLIPS:
			shared_library = library
	player.add_animation_library("", library)
	var blend := AnimationNodeBlendSpace1D.new()
	blend.min_space = 0.0
	blend.max_space = 3.0
	for entry in [["idle", 0.0], ["walk", 1.4], ["jog", 3.0]]:
		var node := AnimationNodeAnimation.new()
		node.animation = entry[0]
		blend.add_blend_point(node, entry[1], -1, entry[0])
	tree = AnimationTree.new()
	tree.name = "Locomotion"
	add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.tree_root = blend
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var gun_asset := (load(BASE + "Animation/Rifle/M4/M4_Rifle_01.fbx") as PackedScene).instantiate()
	weapon = gun_asset
	for camera in weapon.find_children("*", "Camera3D", true, false):
		camera.free()
	add_child(weapon)
	var gun_material := StandardMaterial3D.new()
	gun_material.albedo_texture = load(BASE + "Animation/Rifle/M4/M4_Rifle_01.fbm/M4DF2048.jpg")
	gun_material.roughness = 0.68
	gun_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	gun_material.normal_enabled = true
	gun_material.normal_texture = load(BASE + "Animation/Rifle/M4/M4_Rifle_01.fbm/M4NM2048.jpg")
	gun_material.ao_enabled = true
	gun_material.ao_texture = load(BASE + "Animation/Rifle/M4/M4_Rifle_01.fbm/M4AO2048.jpg")
	for mesh in weapon.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = gun_material
	hand = skeleton.find_bone("RightHandMiddle1")
	_calibrate_weapon_socket()
	if OS.has_environment("FL_DEBUG_MOCAP"):
		print("MOCAP loaded bones=%d clips=%d hand=%d" % [skeleton.get_bone_count(), library.get_animation_list().size(), hand])
	return true


func advance(dt: float, speed: float, clip := "") -> void:
	if clip == "":
		if _clip != "":
			player.stop()
			tree.active = true
		tree.set("parameters/blend_position", speed)
		tree.advance(dt)
	else:
		tree.active = false
		if _clip != clip:
			player.play(clip, 0.2)
		player.advance(dt)
	_clip = clip
	update_weapon()


func _calibrate_weapon_socket() -> void:
	# The supplied notes identify RightHandMiddle1 as the animated attachment.
	# Calibrate its imported axes once in the aiming reference. The trigger
	# knuckle sits lower than the support knuckle; their line is not the barrel.
	tree.active = false
	player.play("idle", 0.0)
	player.advance(0.0)
	_clip = "idle"
	var grip := skeleton.global_transform * skeleton.get_bone_global_pose(hand)
	var left := skeleton.global_transform * skeleton.get_bone_global_pose(int(bone_map["LeftHandMiddle1"])).origin
	var span := left - grip.origin
	var horizontal := Vector3(span.x, 0.0, span.z)
	var pitch := atan2(span.y, horizontal.length()) - atan2(0.045, 0.26)
	var direction := horizontal.normalized() * cos(pitch) + Vector3.UP * sin(pitch)
	var orientation := Basis.looking_at(direction, Vector3.UP, true)
	weapon_socket = grip.affine_inverse() * Transform3D(orientation, grip.origin + orientation.y * 0.035)
	update_weapon()


func update_weapon() -> void:
	if hand < 0:
		return
	# Retain authored roll and pitch through lowering, walking and jogging.
	# Re-aiming between the hands each frame would change the attachment.
	weapon.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(hand) * weapon_socket
