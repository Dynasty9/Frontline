extends "res://tests/mocap/gameplay_stances.gd"
var hand_start := Vector3.ZERO
var hand_travel := 0.0
var worst_sling := 0.0
func _physics_process(dt: float) -> void:
	if proxy == null: return
	time += dt
	var action := Soldier.Act.BUILD if time < 4.0 else (Soldier.Act.IDLE_SMOKE if time < 8.0 else Soldier.Act.IDLE)
	proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, action, 0.0, false, false)
	if time < 8.0:
		var clip := "mixamo_activities__Digging" if action == Soldier.Act.BUILD else "mixamo_activities__Smoking"
		assert(soldier.native_player.current_animation == clip, "Activity did not use the downloaded clip")
		assert(proxy.weapon_slung and not proxy.ik_l and not proxy.ik_r)
		var expected := soldier.joint("Spine2") * soldier._sling_socket
		worst_sling = maxf(worst_sling, expected.origin.distance_to(soldier.weapon.global_position))
		assert(worst_sling < 0.001 and soldier.weapon.visible, "Slung rifle detached from torso")
	var point := soldier.joint("RightHand").origin
	if time > 0.1: hand_travel += point.distance_to(hand_start)
	hand_start = point
	caption.text = "Captured digging / smoking / return to rifle"
	camera.position = Vector3(3, 1.7, 3)
	camera.look_at(Vector3(0, 0.9, 0))
	if time > 11.0:
		assert(hand_travel > 1.0 and proxy._native_locomotion, "Activity froze or failed to return to rifle")
		print("NATIVE ACTIVITIES PASS hand_travel=",hand_travel," sling_error=",worst_sling)
		get_tree().quit()
