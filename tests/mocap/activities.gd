extends "res://tests/mocap/skinned_demo.gd"

var proxy: SoldierModel

func _ready() -> void:
	super._ready()
	proxy = SoldierModel.new()
	add_child(proxy)
	proxy.build("rifleman", 0, 4)
	soldier.bind_procedural(proxy)
	proxy.root.hide()
	proxy.skinned = soldier
	caption.text = "Hands-free poses / rifle attached to the back"

func _physics_process(dt: float) -> void:
	if not ready_to_run or proxy == null: return
	time += dt
	var acts := [Soldier.Act.IDLE_SMOKE, Soldier.Act.IDLE_CHAT, Soldier.Act.IDLE_SIT]
	var action: int = acts[mini(int(time / 4.0), 2)]
	proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, action, 0.0, false, false)
	if "--attachment-before" in OS.get_cmdline_user_args():
		soldier._seat_weapon(dt, proxy.gun)
		caption.text = "Before / hand socket incorrectly overrides the slung pose"
	else:
		assert(soldier.weapon.global_position.distance_to(proxy.gun.global_position) < 0.001)
	assert(proxy.weapon_slung and not proxy.ik_l and not proxy.ik_r)
	var focus := Vector3(0, 0.9, 0)
	camera.position = focus + Vector3(2.7, 0.7, 3.7)
	camera.look_at(focus)
	if time > 12.0:
		print("ACTIVITIES PASS smoke/chat/sit back attachment and free hands")
		get_tree().quit()
