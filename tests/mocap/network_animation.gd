extends "res://scripts/main.gd"
## Run a headless --host --players=2 and rendered --join client on the same port.
const AT := Vector3(0, 0, 45)
const VIEW_OFFSET := Vector3(3, 3, -3)
var target_id := 0
var announced := false
var requested_hit := false
var hit_seen := false
var flinch_seen := false
var flinch_rewound := false
var last_flinch_time := 0.0
var crouch_seen := false
var requested_stand := false
var requested_cover := false
var cover_seen := false
var cover_foot_error := 0.0
var requested_stop := false
var stationary_crouch_seen := false
var diagonal_seen := false
var grip_error := 0.0
var pose_time := 0.0
var death_time := 0.0
var finish_at := INF
var inspection: Camera3D

func _ready() -> void:
	super._ready()
	if args.has("host"):
		Net.set_setting("scenario", "motion")
		Net.set_setting("ai_fill", false)
		Net.set_setting("fixed_seed", 3)

func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(world): return
	if world.srv:
		var moving = world.entity(target_id)
		if moving is Soldier and moving.life == Soldier.Life.ALIVE and not requested_cover and (not requested_stop or requested_stand):
			moving.position += (Vector3(-1.4, 0, -1.4) if requested_stand else Vector3(0, 0, -1.2)) * dt
		if world.time >= finish_at: get_tree().quit()
		return
	if world.soldiers.is_empty(): return
	if not announced:
		announced = true
		Settings.v["ragdolls"] = true
		inspection = Camera3D.new()
		inspection.fov = 35.0
		world.add_child(inspection)
		inspection.position = AT + VIEW_OFFSET
		inspection.look_at(AT + Vector3.UP)
		inspection.make_current()
		world.cam.set_process(false)
		world.cam.cam.position = Vector3(300, 80, 300)
		_client_ready.rpc_id(1)
	inspection.make_current()
	var unit = world.entity(target_id)
	if not unit is Soldier or unit.model == null or unit.model.skinned == null: return
	var skin: SkinnedRifleman = unit.model.skinned
	var focus: Vector3 = skin.joint("Hips").origin + Vector3.UP * 0.2 if skin.dead else unit.position + Vector3.UP
	inspection.position = focus - Vector3.UP + VIEW_OFFSET
	inspection.look_at(focus)
	pose_time += dt
	if unit.model.rifle_driver != null:
		crouch_seen = crouch_seen or (unit.posture == Soldier.Post.CROUCH and unit.model.rifle_driver.crouch_weight > 0.99)
		var driver = unit.model.rifle_driver
		if unit.posture == Soldier.Post.CROUCH and driver.crouch_drop > 0.115 and driver.blend_velocity.length() < 0.01:
			stationary_crouch_seen = true
			grip_error = maxf(grip_error, skin.joint("LeftHand").origin.distance_to((skin.weapon.global_transform * driver.support_grip).origin))
		if unit.posture == Soldier.Post.STAND and driver.crouch_weight < 0.01 and not requested_hit:
			diagonal_seen = diagonal_seen or (absf(driver.blend_velocity.x) > 0.3 and absf(driver.blend_velocity.z) > 0.3)
			grip_error = maxf(grip_error, skin.joint("LeftHand").origin.distance_to((skin.weapon.global_transform * driver.support_grip).origin))
	hit_seen = hit_seen or skin.reaction.velocity.length() > 0.01 or skin.reaction.offset.length() > 0.001
	if requested_hit and not skin.dead and skin.native_hit_strength > 0.01 and skin.native_hit_time < skin.native_hit_clip.length:
		flinch_seen = flinch_seen or skin.native_hit_time > 0.02
		flinch_rewound = flinch_rewound or skin.native_hit_time + 0.001 < last_flinch_time
		last_flinch_time = skin.native_hit_time
	if unit.posture == Soldier.Post.LEAN_R and skin.cover_weight > 0.99 and pose_time > 8.5 and not requested_hit:
		var fingers_match := not skin.native_fingers.is_empty()
		for index in skin.native_fingers:
			fingers_match = fingers_match and skin.skeleton.get_bone_pose_rotation(index).is_equal_approx(skin.native_fingers[index])
		cover_seen = cover_seen or fingers_match
		var palm := skin.joint("LeftHand").origin.lerp(skin.joint("LeftHandMiddle1").origin, 0.65)
		grip_error = maxf(grip_error, palm.distance_to(skin.weapon.global_transform * Vector3(0, 0.055, 0.26)))
		for side in ["Left", "Right"]:
			var toe := skin.joint(side + "ToeBase").origin
			var height: float = skin.ground_height.call(toe) if skin.ground_height.is_valid() else skin.ground_y
			cover_foot_error = maxf(cover_foot_error, absf(toe.y - height))
	if pose_time > 2.0 and not requested_stop:
		requested_stop = true
		_crouch_stop.rpc_id(1)
	if pose_time > 4.0 and not requested_stand:
		requested_stand = true
		_stand_move.rpc_id(1)
	if pose_time > 7.0 and not requested_cover:
		get_viewport().get_texture().get_image().save_png("res://build/network-animation-diagonal.png")
		requested_cover = true
		_cover.rpc_id(1)
	if pose_time > 10.0 and not requested_hit:
		get_viewport().get_texture().get_image().save_png("res://build/network-animation-cover.png")
		requested_hit = true
		_strike.rpc_id(1)
	if unit.life == Soldier.Life.DEAD:
		death_time += dt
		if death_time > 2.0:
			var corpse_framed := true
			for bone in ["Hips", "Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]:
				var point := skin.joint(bone).origin
				corpse_framed = corpse_framed and not inspection.is_position_behind(point) and get_viewport().get_visible_rect().grow(-16).has_point(inspection.unproject_position(point))
			print("NETWORK RAGDOLL framed=", corpse_framed)
			var passed := corpse_framed and crouch_seen and stationary_crouch_seen and diagonal_seen and cover_seen and cover_foot_error < 0.025 and grip_error < 0.007 and hit_seen and flinch_seen and not flinch_rewound and skin.dead and is_instance_valid(skin.ragdoll)
			print("NETWORK FLINCH seen=", flinch_seen, " rewound=", flinch_rewound)
			print("NETWORK COVER fingers=", cover_seen, " foot_error=", cover_foot_error)
			print("NETWORK ANIMATION crouch=",crouch_seen," stationary_crouch=",stationary_crouch_seen," diagonal=",diagonal_seen," grip=",grip_error," hit=",hit_seen," ragdoll=",skin.dead," pass=",passed)
			print("NETWORK DETAIL visible=",unit.visible," life=",unit.life," stats=",world.stats," body_reference=",skin.ragdoll," active_distance=",inspection.global_position.distance_to(unit.global_position))
			if passed: get_viewport().get_texture().get_image().save_png("res://build/network-animation-client.png")
			_finished.rpc_id(1)
			get_tree().quit(0 if passed else 1)

@rpc("any_peer", "call_remote", "reliable")
func _client_ready() -> void:
	if not world.srv or target_id != 0: return
	var unit = world.spawn("soldier", {"utype":"rifleman", "team":0, "pos":AT, "dpose":[Soldier.Post.CROUCH, Soldier.Act.WALK, Soldier.Life.ALIVE, 1.2]})
	target_id = unit.eid
	_target.rpc_id(multiplayer.get_remote_sender_id(), target_id)

@rpc("authority", "call_remote", "reliable")
func _target(id: int) -> void:
	target_id = id

@rpc("any_peer", "call_remote", "reliable")
func _crouch_stop() -> void:
	if not world.srv: return
	var unit = world.entity(target_id)
	if not unit is Soldier: return
	requested_stop = true
	unit.debug_pose[1] = Soldier.Act.IDLE
	unit.debug_pose[3] = 0.0

@rpc("any_peer", "call_remote", "reliable")
func _stand_move() -> void:
	if not world.srv: return
	var unit = world.entity(target_id)
	if not unit is Soldier: return
	requested_stand = true
	unit.debug_pose[0] = Soldier.Post.STAND
	unit.debug_pose[1] = Soldier.Act.WALK
	unit.debug_pose[3] = Vector2(1.4, 1.4).length()

@rpc("any_peer", "call_remote", "reliable")
func _cover() -> void:
	if not world.srv: return
	var unit = world.entity(target_id)
	if not unit is Soldier: return
	requested_cover = true
	unit.debug_pose[0] = Soldier.Post.LEAN_R
	unit.debug_pose[1] = Soldier.Act.SHOOT
	unit.debug_pose[3] = 0.0

@rpc("any_peer", "call_remote", "reliable")
func _strike() -> void:
	if not world.srv: return
	var unit = world.entity(target_id)
	var direction: Vector3 = unit.global_basis.z.normalized()
	world.fx_event([Fx.UNIT_HIT, target_id, direction, 1.0])
	await get_tree().create_timer(0.08).timeout
	world.fx_event([Fx.UNIT_HIT, target_id, direction, 1.0])
	await get_tree().create_timer(1.0).timeout
	unit.debug_pose.clear()
	unit._hit_kind = "bullet"
	unit._hit_dir = Vector3.RIGHT
	unit._die()

@rpc("any_peer", "call_remote", "reliable")
func _finished() -> void:
	if world.srv: finish_at = world.time + 5.0
