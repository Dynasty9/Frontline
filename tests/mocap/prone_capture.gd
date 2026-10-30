extends "res://tests/mocap/skinned_demo.gd"
const CLIP := "mixamo_transition__Rifle_Kneel_To_Prone"
func _ready() -> void:
	super._ready()
	load("res://scripts/game/mixamo_clips.gd").install(soldier, true)
	caption.text = "Captured kneel to prone / original rifle socket"
func _physics_process(dt: float) -> void:
	if not ready_to_run: return
	time += dt
	soldier.pose_native(dt, CLIP)
	camera.position = Vector3(-3, 1.5, -3.3)
	camera.look_at(Vector3(0, 0.65, 0))
	if time > 5.0:
		print("PRONE CAPTURE head=", soldier.joint("Head").origin, " hips=", soldier.joint("Hips").origin, " length=", soldier.native_player.get_animation(CLIP).length)
		get_tree().quit()
