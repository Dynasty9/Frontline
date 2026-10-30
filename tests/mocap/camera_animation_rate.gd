extends Node3D

class PoseCounter extends SoldierModel:
	var calls := 0
	func pose(_dt: float, _life: int, _posture: int, _act: int, _speed: float, _backwards: bool, _lean_shoot: bool) -> void:
		calls += 1

func _ready() -> void:
	var world := World.new()
	world.cam = RtsCamera.new()
	var distant := Camera3D.new()
	add_child(distant)
	distant.position = Vector3(200, 2, 4)
	distant.look_at(Vector3(200, 1, 0))
	world.cam.cam = distant
	var close := Camera3D.new()
	add_child(close)
	close.position = Vector3(0, 2, 4)
	close.look_at(Vector3(0, 1, 0))
	var man := Soldier.new()
	man.world = world
	man.srv = true
	man.life = Soldier.Life.DOWNED
	man.model = PoseCounter.new()
	man.ring = MeshInstance3D.new()
	man.add_child(man.model)
	man.add_child(man.ring)
	add_child(man)
	man.set_process(false)
	close.make_current()
	for frame in 12: man._view_process(1.0 / 60.0)
	assert(man.model.calls == 12, "Close-up camera must pose every frame")
	distant.make_current()
	for frame in 12: man._view_process(1.0 / 60.0)
	assert(man.model.calls == 14, "Off-screen animation should retain its lower update rate")
	close.make_current()
	man._view_process(1.0 / 60.0)
	assert(man.model.calls == 15, "Returning to close-up must resume immediately")
	world.cam.free()
	world.free()
	print("CAMERA ANIMATION RATE PASS close=12 offscreen=2 resumed=1")
	get_tree().quit()
