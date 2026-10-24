extends "res://tests/mocap/skinned_demo.gd"
class WorldStub extends RefCounted:
	var cam: RtsCamera
	func stat(_key: String) -> void: pass
func _ready() -> void:
	super._ready()
	Settings.v["ragdolls"] = true
	var stub := WorldStub.new()
	stub.cam = RtsCamera.new()
	stub.cam.cam = Camera3D.new()
	add_child(stub.cam.cam)
	stub.cam.cam.position = Vector3(300,30,300)
	camera.position = Vector3(0,2,-4)
	camera.look_at(Vector3(0,1,0))
	camera.make_current()
	var unit := Soldier.new()
	add_child(unit)
	unit.set_process(false)
	var model := SoldierModel.new()
	unit.model = model
	model.skinned = soldier
	var fx := PhysicsFx.new(stub)
	soldier.pose(0.1,0.0,"idle")
	fx.ragdoll(unit,Vector3(0,0,0.8),0)
	var passed := soldier.dead and is_instance_valid(soldier.ragdoll)
	print("ACTIVE CAMERA RAGDOLL created=",passed)
	if soldier.dead: soldier.revive()
	stub.cam.cam.make_current()
	fx.ragdoll(unit,Vector3(0,0,0.8),0)
	passed = passed and not soldier.dead
	print("ACTIVE CAMERA RAGDOLL distant_suppressed=",not soldier.dead)
	unit.model = null
	model.free()
	fx.free()
	stub.cam.free()
	get_tree().quit(0 if passed else 1)
func _physics_process(_dt: float) -> void: pass
