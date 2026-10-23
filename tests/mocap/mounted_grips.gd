extends "res://tests/mocap/skinned_demo.gd"

var proxy: SoldierModel
var gun: Dictionary
var max_error := 0.0
var emplacement: Structure
var leg_penetration := 0.0
var leg_clearance := INF
var kind := "m2"
var platform_height := 0.45
var finger_error := 0.0

func _ready() -> void:
	super._ready()
	proxy = SoldierModel.new()
	add_child(proxy)
	proxy.build("rifleman", 0, 4)
	soldier.bind_procedural(proxy)
	proxy.root.hide()
	proxy.skinned = soldier
	load("res://scripts/game/mixamo_clips.gd").install(soldier, true)
	soldier.native_player.play("mixamo_basic_shooter__reloading", 0.0)
	soldier.native_player.seek(0.8, true)
	proxy.crew = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gun="): kind = arg.trim_prefix("--gun=")
	assert(WeaponModels.GUNS.has(kind))
	var heavy := kind in ["m2", "dshk"]
	platform_height = 0.45 if heavy else 0.5
	emplacement = Structure.new()
	emplacement.skind = "hmg_nest" if heavy else "mg_nest"
	emplacement.team = 1 if kind in ["pkm", "dshk"] else 0
	emplacement.position.z = 1.1 if heavy else 0.95
	gun = WeaponModels.build(kind)
	add_child(gun.root)
	gun.root.position = emplacement.position + emplacement.mg_pivot_local()
	_surface(Vector3(0, platform_height * 0.5, 0.05), Vector3(1.2, platform_height, 0.9), Color("535846"))
	emplacement._mg = gun
	caption.text = "Mounted " + kind.to_upper() + " / moving grip anchors"

func _physics_process(dt: float) -> void:
	if proxy == null: return
	time += dt
	var angle := sin(time * 0.7) * Structure.MG_ARC
	gun.traverse.rotation.y = angle
	gun.body.position.z = maxf(0.0, sin(time * 24.0)) * 0.025
	proxy.transform = emplacement.crew_stance(0.0)
	soldier.global_transform = proxy.global_transform
	proxy.crew_r = gun.body.global_transform * gun.grip_r
	proxy.crew_l = gun.body.global_transform * gun.grip_l
	proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.CROUCH, Soldier.Act.SHOOT, 0.0, false, true)
	if "--mounted-before" in OS.get_cmdline_user_args():
		proxy.crew = false
		soldier.pose_procedural(proxy, 0.0)
		proxy.crew = true
	if time > 1.0:
		for index in soldier.native_fingers:
			finger_error = maxf(finger_error, soldier.skeleton.get_bone_pose_rotation(index).angle_to(soldier.native_fingers[index]))
		for side in ["Left", "Right"]:
			for bone in ["Leg", "Foot", "ToeBase"]:
				var point := soldier.joint(side + bone).origin
				if point.y < platform_height and absf(point.x) < 0.6 and absf(point.z - 0.05) < 0.45:
					leg_penetration = maxf(leg_penetration, minf(platform_height - point.y, minf(0.6 - absf(point.x), 0.45 - absf(point.z - 0.05))))
			for segment in [["UpLeg", "Leg"], ["Leg", "Foot"], ["Foot", "ToeBase"]]:
				var start := soldier.joint(side + segment[0]).origin
				var end := soldier.joint(side + segment[1]).origin
				for sample in 9:
					var point := start.lerp(end, float(sample) / 8.0)
					var nearest := point.clamp(Vector3(-0.6, 0, -0.4), Vector3(0.6, platform_height, 0.5))
					leg_clearance = minf(leg_clearance, point.distance_to(nearest))
			var palm := soldier.joint(side + "Hand").origin.lerp(soldier.joint(side + "HandMiddle1").origin, 0.65)
			var target: Vector3 = proxy.crew_l if side == "Left" else proxy.crew_r
			max_error = maxf(max_error, palm.distance_to(target))
	camera.position = Vector3(-2.5, 2.0, 3.5)
	camera.look_at(Vector3(0, 0.95, 0.5))
	if time > 7.0:
		print(kind, " MOUNTED GRIPS maximum palm error=", max_error, " leg penetration=", leg_penetration, " segment clearance=", leg_clearance, " finger error=", finger_error)
		if "--mounted-before" not in OS.get_cmdline_user_args():
			if max_error >= 0.01 or leg_penetration > 0.0 or leg_clearance <= 0.07 or finger_error > 0.001:
				push_error("Mounted grip, finger recovery or platform clearance failed")
				get_tree().quit(1)
				return
			print("MOUNTED GRIPS PASS")
		get_tree().quit()

func _exit_tree() -> void:
	if is_instance_valid(emplacement): emplacement.free()
