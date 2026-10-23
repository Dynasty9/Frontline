extends "res://tests/mocap/skinned_demo.gd"
var worst_overlap := 0.0
var worst_pair := ""
var overlap_time := 0.0
var sample_pose := "idle"
var impact_at := 1.0
var impact_kind := 1
var worst_separation := 0.0
var early_separation := 0.0
var early_joint := ""
var early_time := 0.0
var early_overlap := 0.0
var early_overlap_pair := ""
var early_overlap_time := 0.0
var initial_overlap := 0.0
var initial_pair := ""
var separation_joint := ""
var separation_time := 0.0
var proxy: SoldierModel
var unit: Soldier
var physics_fx: PhysicsFx
var bone_lengths: Array[float] = []
var max_stretch := 0.0
var stretch_bone := ""
var settled_skin_offset := 0.0
var wall_impact := false
var barrier: StaticBody3D
var wall_contact := false
var wall_penetration := 0.0
var wall_part := ""
var wall_time := 0.0
var native_driver: RefCounted

class WorldStub extends RefCounted:
	var cam = null
	var events := {}
	func stat(key: String) -> void:
		events[key] = int(events.get(key, 0)) + 1


func _ready() -> void:
	super._ready()
	wall_impact = "--wall-impact" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--physics-hz="): Engine.physics_ticks_per_second = int(arg.get_slice("=", 1))
		if arg.begins_with("--ragdoll-pose="): sample_pose = arg.get_slice("=", 1)
		if arg.begins_with("--impact-at="): impact_at = float(arg.get_slice("=", 1))
		if arg.begins_with("--impact-kind="): impact_kind = int(arg.get_slice("=", 1))
	if sample_pose == "rifle_run":
		load("res://scripts/game/mixamo_clips.gd").install(soldier, true)
		native_driver = load("res://scripts/game/rifle_animation_controller.gd").new()
		native_driver.setup(soldier)
		native_driver.advance(0.0, Vector3.ZERO, false, true)
	elif sample_pose in ["gameplay_prone", "gameplay_crouch", "gameplay_lean", "gameplay_peek"]:
		proxy = SoldierModel.new()
		add_child(proxy)
		proxy.build("rifleman", 0, 4)
		soldier.bind_procedural(proxy)
		proxy.root.hide()
		proxy.skinned = soldier
		load("res://scripts/game/mixamo_clips.gd").install(soldier, true)
		proxy.rifle_driver = load("res://scripts/game/rifle_animation_controller.gd").new()
		proxy.rifle_driver.setup(soldier)
		unit = Soldier.new()
		unit.model = proxy
		physics_fx = PhysicsFx.new(WorldStub.new())
		Settings.v["ragdolls"] = true
		for child in get_children():
			if child is StaticBody3D: child.collision_layer = PhysicsFx.L_GROUND
	elif sample_pose == "prone":
		load("res://scripts/game/mixamo_clips.gd").install(soldier)
		var clip := "mixamo_transition__Rifle_Kneel_To_Prone"
		soldier.native_player.play(clip)
		soldier.native_player.seek(1.9, true)
		soldier._native_clip = clip
		soldier.pose_native(0.0, clip)
	else:
		soldier.pose(0.1, 0.0, sample_pose)
		if sample_pose == "crouch":
			soldier.source.player.seek(0.7, true)
			soldier.pose(0.0, 0.0, sample_pose)
			assert(soldier.joint("Hips").origin.y < 0.95, "Crouch starting pose was not applied")
	if sample_pose in ["jog", "rifle_run"]:
		soldier.position.x = -2.0
		soldier.rotation.y = -PI * 0.5
		soldier._last_position = soldier.global_position
	camera.position = Vector3(3, 2.6, -4)
	camera.look_at(Vector3(0, 0.65, 0))
	if sample_pose in ["jog", "rifle_run"]:
		camera.position = Vector3(7, 4, -8)
		camera.look_at(Vector3(1, 0.65, 0))
	if wall_impact:
		camera.position = Vector3(4, 2, -4)
		camera.look_at(Vector3(1, 0.8, 0.8))
	caption.text = "RAGDOLL / " + sample_pose + " / " + ["bullet", "blast", "collapse"][impact_kind]
	barrier = _surface(Vector3(0, 2 if wall_impact else 1, 1.3), Vector3(12, 4, 0.2) if wall_impact else Vector3(4, 2, 0.2), Color("424e5c"))
	if proxy != null: barrier.collision_layer = Defs.L_COVER

func _physics_process(dt: float) -> void:
	if not ready_to_run: return
	time += dt
	if sample_pose in ["jog", "rifle_run"] and not soldier.dead:
		soldier.position.x += dt * 3.0
		if native_driver != null: native_driver.advance(dt, Vector3(0, 0, -3), false, true)
		else: soldier.pose(dt, 3.0, "jog")
		soldier.capture_motion(dt)
	if proxy != null and not soldier.dead:
		var posture := Soldier.Post.PRONE
		if sample_pose == "gameplay_crouch": posture = Soldier.Post.CROUCH
		elif sample_pose in ["gameplay_lean", "gameplay_peek"]: posture = Soldier.Post.LEAN_R
		proxy.pose(dt, Soldier.Life.ALIVE, posture, Soldier.Act.SHOOT, 0.0, false, sample_pose == "gameplay_peek")
	if time >= impact_at and stage == 0:
		if "--without-animation-momentum" in OS.get_cmdline_user_args(): soldier.capture_motion(0.0)
		var impulse := Vector3(0.7, 1.5, 3.0) if impact_kind == 1 else Vector3(0, 0, 0.8)
		if wall_impact: impulse = Vector3(0, 1.5, 6)
		for side in ["Left", "Right"]:
			var thigh := soldier.joint(side + "Leg").origin - soldier.joint(side + "UpLeg").origin
			var shin := soldier.joint(side + "Foot").origin - soldier.joint(side + "Leg").origin
			print("RAGDOLL captured knee ", side, " flexion=", thigh.angle_to(shin))
		for index in soldier.skeleton.get_bone_count():
			bone_lengths.append(soldier.skeleton.get_bone_pose_position(index).length())
		if proxy != null:
			var before: Array[Transform3D] = []
			for index in soldier.skeleton.get_bone_count(): before.append(soldier.world_pose(index))
			physics_fx.ragdoll(unit, impulse, impact_kind)
			proxy.pose(dt, Soldier.Life.DEAD, Soldier.Post.PRONE, Soldier.Act.IDLE, 0.0, false, false)
			assert(soldier.dead and physics_fx.world.events.get("skinned_ragdoll", 0) == 1)
			for index in before.size():
				assert(soldier.world_pose(index).is_equal_approx(before[index]), "Gameplay death changed the captured bone pose")
		else:
			soldier.kill(impulse, impact_kind)
		var mass_center := Vector3.ZERO
		var total_mass := 0.0
		for body in soldier.ragdoll.bodies.values():
			mass_center += body.get_child(0).global_position * body.mass
			total_mass += body.mass
		mass_center /= total_mass
		for name in soldier.ragdoll.bodies:
			var body: RigidBody3D = soldier.ragdoll.bodies[name]
			var spin: Vector3 = soldier.limb_spin.get(name, Vector3.ZERO)
			var expected: Vector3 = soldier.last_velocity + soldier.limb_velocity.get(name, Vector3.ZERO) + spin.cross(body.global_basis * body.get_child(0).position)
			if impact_kind != 2: expected += impulse * (1.0 if impact_kind == 1 or name == "Spine2" else 0.15)
			if impact_kind == 1: expected += (Vector3.UP.cross(impulse) * 0.35).cross(body.get_child(0).global_position - mass_center)
			assert(soldier.ragdoll.bodies[name].linear_velocity.is_equal_approx(expected), "Death kind lost before body initialization: " + name)
			if impact_kind != 1: assert(body.angular_velocity.is_equal_approx(spin))
		# Battlefield callers replace the viewer's collision layer after build.
		if proxy == null: soldier.ragdoll.set_collision_layers(16, 1)
		for body in soldier.ragdoll.bodies.values():
			assert((body.collision_mask & 16) != 0, "Layer override disabled self-collision")
		var initial_gap := 0.0
		var floor_overlap := 0.0
		var floor_part := ""
		for name in soldier.ragdoll.bodies:
			var shape: CollisionShape3D = soldier.ragdoll.bodies[name].get_child(0)
			var half: float = shape.shape.height * 0.5 - shape.shape.radius
			var lowest: float = minf((shape.global_transform * Vector3(0, half, 0)).y, (shape.global_transform * Vector3(0, -half, 0)).y) - shape.shape.radius
			if -lowest > floor_overlap:
				floor_overlap = -lowest
				floor_part = name
		var velocity_gap := 0.0
		if sample_pose in ["gameplay_lean", "gameplay_peek"]:
			assert(floor_overlap < 0.02, "Cover death started with feet below the floor")
		var velocity_joint := ""
		var initial_joint := ""
		for part in SkinnedRagdoll.PARTS:
			if part[1] == "": continue
			var anchor: Vector3 = soldier.ragdoll.bodies[part[1]].global_transform * (soldier.ragdoll.anchors[part[0]] as Vector3)
			var gap := anchor.distance_to(soldier.ragdoll.bodies[part[0]].global_position)
			var parent: RigidBody3D = soldier.ragdoll.bodies[part[1]]
			var child: RigidBody3D = soldier.ragdoll.bodies[part[0]]
			var parent_velocity := parent.linear_velocity + parent.angular_velocity.cross(anchor - parent.global_transform * parent.get_child(0).position)
			var child_velocity := child.linear_velocity + child.angular_velocity.cross(child.global_position - child.global_transform * child.get_child(0).position)
			var mismatch := parent_velocity.distance_to(child_velocity)
			if mismatch > velocity_gap:
				velocity_gap = mismatch
				velocity_joint = part[0]
			if gap > initial_gap:
				initial_gap = gap
				initial_joint = part[0]
		print("RAGDOLL initial anchor gap=", initial_gap, " joint=", initial_joint)
		print("RAGDOLL initial anchor velocity mismatch=", velocity_gap, " joint=", velocity_joint)
		if impact_kind == 1 and "--without-animation-momentum" in OS.get_cmdline_user_args():
			assert(velocity_gap < 0.001, "Blast spin pulled connected joint anchors apart at handoff")
		print("RAGDOLL initial floor overlap=", floor_overlap, " part=", floor_part)
		assert(initial_gap < 0.001, "Ragdoll anchors disagree at creation")
		assert(soldier.ragdoll.handoff_error < 0.001)
		stage = 1
	if soldier.dead and is_instance_valid(soldier.ragdoll):
		var rag := soldier.ragdoll
		rag.draw()
		if wall_impact:
			for body in rag.bodies.values():
				if barrier in body.get_colliding_bodies(): wall_contact = true
				var shape: CollisionShape3D = body.get_child(0)
				var half: float = shape.shape.height * 0.5 - shape.shape.radius
				var a := shape.global_transform * Vector3(0, -half, 0)
				var b := shape.global_transform * Vector3(0, half, 0)
				if maxf(absf(a.x), absf(b.x)) + shape.shape.radius >= 6.0 or maxf(a.y, b.y) + shape.shape.radius >= 4.0:
					push_error("Wall probe escaped the measured face")
					get_tree().quit(1)
					return
				var penetration: float = maxf(a.z, b.z) + shape.shape.radius - 1.2
				if penetration > wall_penetration:
					wall_penetration = penetration
					wall_part = str(rag.bodies.find_key(body))
					wall_time = time - impact_at
		for index in bone_lengths.size():
			if index == int(soldier.bones["Hips"]): continue
			var stretch := absf(soldier.skeleton.get_bone_pose_position(index).length() - bone_lengths[index])
			if stretch > max_stretch:
				max_stretch = stretch
				stretch_bone = soldier.skeleton.get_bone_name(index)
		if proxy != null:
			assert(rag.bodies["Hips"].global_position.y > -0.2, "Gameplay ragdoll missed the ground layer")
		for part in SkinnedRagdoll.PARTS:
			if part[1] == "": continue
			var anchor: Vector3 = rag.bodies[part[1]].global_transform * (soldier.ragdoll.anchors[part[0]] as Vector3)
			var gap := anchor.distance_to(rag.bodies[part[0]].global_position)
			if time <= impact_at + 1.0:
				if gap > early_separation:
					early_separation = gap
					early_joint = part[0]
					early_time = time - impact_at
			elif gap > worst_separation:
				worst_separation = gap
				separation_joint = part[0]
				separation_time = time - impact_at
		# Track impact transients separately from the tighter settled bounds.
		if time > impact_at + 1.0:
			for name in rag.bodies:
				settled_skin_offset = maxf(settled_skin_offset, soldier.joint(name).origin.distance_to(rag.bodies[name].global_position))
		for i in SkinnedRagdoll.PARTS.size():
			for j in range(i + 1, SkinnedRagdoll.PARTS.size()):
				var a: Array = SkinnedRagdoll.PARTS[i]
				var b: Array = SkinnedRagdoll.PARTS[j]
				if a[1] == b[0] or b[1] == a[0]: continue
				var sa: CollisionShape3D = rag.bodies[a[0]].get_child(0)
				var sb: CollisionShape3D = rag.bodies[b[0]].get_child(0)
				var ha: float = sa.shape.height * 0.5 - sa.shape.radius
				var hb: float = sb.shape.height * 0.5 - sb.shape.radius
				var points := Geometry3D.get_closest_points_between_segments(sa.global_transform * Vector3(0, -ha, 0), sa.global_transform * Vector3(0, ha, 0), sb.global_transform * Vector3(0, -hb, 0), sb.global_transform * Vector3(0, hb, 0))
				var overlap: float = sa.shape.radius + sb.shape.radius - points[0].distance_to(points[1])
				if rag.elapsed == 0.0 and overlap > initial_overlap:
					initial_overlap = overlap
					initial_pair = a[0] + "/" + b[0]
				if rag.elapsed > 0.0 and time <= impact_at + 1.0 and overlap > early_overlap:
					early_overlap = overlap
					early_overlap_pair = a[0] + "/" + b[0]
					early_overlap_time = time - impact_at
				if time > impact_at + 1.0 and overlap > worst_overlap:
					worst_overlap = overlap
					worst_pair = a[0] + "/" + b[0]
					overlap_time = time - impact_at
	if time > 8.0:
		if wall_impact:
			print("RAGDOLL wall_contact=", wall_contact, " maximum_wall_penetration=", wall_penetration, " body=", wall_part, " after_impact=", wall_time)
			if not wall_contact or wall_penetration >= 0.04:
				push_error("Ragdoll missed or penetrated the wall")
				get_tree().quit(1)
				return
		print("RAGDOLL initial overlap=", initial_overlap, " pair=", initial_pair, " worst_overlap_after_impact=", overlap_time)
		print("RAGDOLL first-second overlap=", early_overlap, " pair=", early_overlap_pair, " after_impact=", early_overlap_time)
		print("RAGDOLL early joint=", early_joint, " after_impact=", early_time)
		print("RAGDOLL skin stretch=", max_stretch, " bone=", stretch_bone, " settled skin offset=", settled_skin_offset)
		print("RAGDOLL overlap=", worst_overlap, " pair=", worst_pair, " joint_separation=", worst_separation, " joint=", separation_joint, " after_impact=", separation_time, " first_second_separation=", early_separation)
		if "--assert-ragdoll" in OS.get_cmdline_user_args() and (initial_overlap > 0.04 or early_overlap > 0.04 or early_separation > 0.06 or worst_overlap > 0.04 or worst_separation > 0.05 or max_stretch > 0.001 or settled_skin_offset > 0.05):
			push_error("Ragdoll bounds exceeded: early_overlap=%s early_gap=%s overlap=%s joint_gap=%s skin_offset=%s stretch=%s" % [early_overlap, early_separation, worst_overlap, worst_separation, settled_skin_offset, max_stretch])
			get_tree().quit(1)
		else: get_tree().quit()


func _exit_tree() -> void:
	if is_instance_valid(physics_fx): physics_fx.free()
	if is_instance_valid(unit): unit.free()
