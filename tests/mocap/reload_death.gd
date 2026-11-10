extends "res://tests/mocap/gameplay_reload.gd"

var death_at := 1.3
var death_time := 0.0
var detached := false

func _ready() -> void:
	super._ready()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reload-death-at="): death_at = float(arg.get_slice("=", 1))
	camera.position = Vector3(-2.5, 2.0, -3.5)
	camera.look_at(Vector3(0, 0.7, 0))
	caption.text = "Reload interrupted by fatal hit / magazine release"

func _physics_process(dt: float) -> void:
	if proxy == null: return
	time += dt
	if not soldier.dead and stage == 0:
		proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.RELOAD if time > 1.0 else Soldier.Act.IDLE, 0.0, false, false)
		if time > 1.0 and driver.action_time >= death_at:
			var magazine_pose: Transform3D = soldier.magazine.mesh.global_transform
			detached = (death_at > 0.4 and death_at < 0.68) or (death_at >= 1.12 and death_at < 1.95)
			if "--reload-death-before" in OS.get_cmdline_user_args():
				soldier.magazine.detached_weight = 0.0
				detached = false
			soldier.kill(Vector3(0.2, 0, 0.8), 0)
			assert(soldier.magazine.mesh.global_transform.is_equal_approx(magazine_pose), "Magazine snapped at death")
			assert(is_instance_valid(soldier.ragdoll.get("magazine_body")) == detached, "Detached magazine did not receive its own body")
			death_time = time
			stage = 1
	if stage == 1 and time > death_time + 3.0:
		if detached:
			assert(soldier.magazine.mesh.global_position.distance_to(soldier.weapon.global_position) > 0.15, "Magazine remained fixed to the rifle")
			var mesh: MeshInstance3D = soldier.magazine.mesh
			var arrays := mesh.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for index in arrays[Mesh.ARRAY_INDEX]:
				assert((mesh.global_transform * vertices[index]).y > -0.01, "Magazine penetrated the ground")
		stage = 2
	if stage == 2 and time > death_time + 10.0:
		assert(not is_instance_valid(soldier.ragdoll))
		assert(soldier.magazine.mesh.get_parent() == soldier.magazine.receiver)
		soldier.revive()
		proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.IDLE, 0.0, false, false)
		assert(soldier.magazine.mesh.visible and soldier.magazine.mesh.transform.is_equal_approx(Transform3D.IDENTITY))
		print("RELOAD DEATH PASS phase=", death_at, " detached=", detached, " handoff/drop/cleanup/revive")
		get_tree().quit()
