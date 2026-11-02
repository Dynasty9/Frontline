extends "res://tests/mocap/skinned_demo.gd"

var proxy: SoldierModel
var driver: RefCounted
var stowed := false
var replaced := false
var interrupted := false

func _ready() -> void:
	super._ready()
	proxy = SoldierModel.new()
	add_child(proxy)
	proxy.build("rifleman", 0, 4)
	soldier.bind_procedural(proxy)
	proxy.root.hide()
	proxy.skinned = soldier
	load("res://scripts/game/mixamo_clips.gd").install(soldier, true)
	driver = load("res://scripts/game/rifle_animation_controller.gd").new()
	driver.setup(soldier)
	proxy.rifle_driver = null if "--reload-before" in OS.get_cmdline_user_args() else driver
	if "--crouch-reload" in OS.get_cmdline_user_args() and proxy.rifle_driver != null:
		proxy.pose(0.0, Soldier.Life.ALIVE, Soldier.Post.CROUCH, Soldier.Act.IDLE, 0.0, false, false)
		var left := soldier.joint("LeftFoot")
		var right := soldier.joint("RightFoot")
		driver.overlay_reload(0.5)
		assert(soldier.joint("LeftFoot").is_equal_approx(left))
		assert(soldier.joint("RightFoot").is_equal_approx(right))
		driver.action = ""
	caption.text = "Gameplay reload / captured hands + magazine / 2.2 seconds"

func _physics_process(dt: float) -> void:
	if proxy == null: return
	time += dt
	var reload := (time >= 1.0 and time < 3.2) or (time >= 5.0 and time < 5.7)
	var action := Soldier.Act.RELOAD if reload else Soldier.Act.IDLE
	var posture := Soldier.Post.CROUCH if "--crouch-reload" in OS.get_cmdline_user_args() else Soldier.Post.STAND
	proxy.pose(dt, Soldier.Life.ALIVE, posture, action, 0.0, false, false)
	if "--reload-before" in OS.get_cmdline_user_args():
		caption.text = "Before / procedural reload fallback"
	elif reload:
		var clip_time: float = driver.action_time
		if clip_time > 0.8 and clip_time < 1.0:
			assert(not soldier.magazine.mesh.visible)
			stowed = true
		if clip_time > 1.2 and clip_time < 1.4:
			assert(soldier.magazine.mesh.visible)
			replaced = true
	elif time > 5.8:
		assert(driver.action == "" and soldier.magazine.mesh.visible)
		interrupted = true
	if time >= 2.0 and time < 2.0 + dt:
		for side in ["Left", "Right"]:
			print("CONTACT ", side, " ankle=", soldier.joint(side + "Foot").origin, " toe=", soldier.joint(side + "ToeBase").origin, " knee=", soldier.joint(side + "Leg").origin, " sole=", soldier.target_rest[int(soldier.bones[side + "Foot"])].origin.y)
	if posture == Soldier.Post.CROUCH and time > 1.0:
		for side in ["Left", "Right"]:
			assert(soldier.joint(side + "ToeBase").origin.y >= -0.002)
			assert(soldier.joint(side + "ToeBase").origin.y < 0.02, "Stopped crouch left a foot in the air")
	var focus := Vector3(0, 0.8 if posture == Soldier.Post.CROUCH else 1.15, 0)
	camera.position = focus + Vector3(-1.8, 0.25, -2.8)
	camera.look_at(focus)
	if time > 7.0:
		if "--reload-before" not in OS.get_cmdline_user_args():
			assert(stowed and replaced and interrupted)
			print("GAMEPLAY RELOAD PASS stowed/replaced/interrupted")
		else:
			print("GAMEPLAY RELOAD baseline render complete")
		get_tree().quit()
