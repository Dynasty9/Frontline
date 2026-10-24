extends "res://tests/mocap/skinned_demo.gd"

class WorldStub extends RefCounted:
	var cam = null
	func stat(_key: String) -> void: pass

var actors: Array[SkinnedRifleman] = []
var units: Array[Soldier] = []
var models: Array[SoldierModel] = []
var physics_fx: PhysicsFx
var samples: Array[float] = []
var duplicate_checked := false

func _ready() -> void:
	super._ready()
	Settings.v["ragdolls"] = true
	physics_fx = PhysicsFx.new(WorldStub.new())
	for child in get_children():
		if child is StaticBody3D: child.collision_layer = PhysicsFx.L_GROUND
	for index in PhysicsFx.MAX_RAGDOLLS + 1:
		var actor := soldier if index == 0 else SkinnedRifleman.new()
		if index > 0:
			add_child(actor)
			assert(actor.build(_animation_clips()))
		actor.position = Vector3((index % 4) * 2.5 - 4, 0, (index / 4) * 2.5 - 4)
		actor.pose(0.1, 0.0, "idle")
		actors.append(actor)
		var model := SoldierModel.new()
		model.skinned = actor
		models.append(model)
		var unit := Soldier.new()
		unit.model = model
		units.append(unit)
	camera.position = Vector3(13, 12, -16)
	camera.look_at(Vector3.ZERO)
	caption.text = "Ragdoll budget / 16 active bodies + replacement"

func _physics_process(dt: float) -> void:
	if physics_fx == null: return
	time += dt
	if time >= 2.0 and stage == 0:
		for index in PhysicsFx.MAX_RAGDOLLS:
			physics_fx.ragdoll(units[index], Vector3(0.3, 1.5, 1.2), 1)
		assert(physics_fx.ragdolls.size() == PhysicsFx.MAX_RAGDOLLS)
		stage = 1
	if time >= 4.0 and stage == 1:
		physics_fx.ragdoll(units[-1], Vector3(0.3, 1.5, 1.2), 1)
		assert(actors[0].ragdoll.done and actors[0].weapon.get_parent() == actors[0])
		stage = 2
	if time >= 4.2 and not duplicate_checked:
		physics_fx.ragdoll(units[-1], Vector3(0.3, 1.5, 1.2), 1)
		if physics_fx.ragdolls.size() != PhysicsFx.MAX_RAGDOLLS:
			push_error("Duplicate death evicted another active ragdoll: " + str(physics_fx.ragdolls.size()))
			get_tree().quit(1)
			return
		duplicate_checked = true
	if time > 2.3 and time < 9.0:
		samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if time > 14.0:
		for actor in actors:
			assert(not is_instance_valid(actor.ragdoll))
			assert(actor.weapon.get_parent() == actor)
		samples.sort()
		print("RAGDOLL BUDGET PASS eviction/duplicate/cleanup; physics ms p50=", samples[samples.size() / 2], " p95=", samples[int(samples.size() * 0.95)], " max=", samples[-1])
		get_tree().quit()

func _exit_tree() -> void:
	if is_instance_valid(physics_fx): physics_fx.free()
	for unit in units: unit.free()
	for model in models: model.free()
