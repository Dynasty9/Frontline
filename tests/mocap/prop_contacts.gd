extends "res://tests/mocap/skinned_demo.gd"

var rag: SkinnedRagdoll
var contacted_owner := false

func _ready() -> void:
	super._ready()
	soldier.pose(0.1, 0.0, "idle")
	soldier.kill(Vector3.ZERO, 2)
	rag = soldier.ragdoll
	rag.set_collision_layers(16, 1)
	for body in rag.bodies.values(): body.freeze = true
	rag.weapon_body.freeze = true
	rag.weapon_body.contact_monitor = true
	rag.weapon_body.max_contacts_reported = 8
	var hip_shape: CollisionShape3D = rag.bodies["Hips"].get_child(0)
	var gun_shape: CollisionShape3D = rag.weapon_body.get_child(0)
	rag.weapon_body.global_position = hip_shape.global_position - rag.weapon_body.global_basis * gun_shape.position
	camera.position = Vector3(3, 2.5, -4)
	camera.look_at(Vector3(0, 0.8, 0))
	caption.text = "Released rifle / overlap protection then owner collision"

func _physics_process(dt: float) -> void:
	if rag == null: return
	time += dt
	if time > 0.3 and stage == 0:
		assert(rag.weapon_body.get_collision_exceptions().has(rag.bodies["Hips"]), "Initial overlap protection removed too early")
		rag.weapon_body.global_position = Vector3(0, 4, 0)
		stage = 1
	if time > 0.6 and stage == 1:
		assert(rag.weapon_body.get_collision_exceptions().is_empty(), "Separated rifle still ignores its owner")
		rag.weapon_body.global_transform = Transform3D(Basis.IDENTITY, soldier.joint("Head").origin + Vector3(0, 0.6, -0.18))
		rag.weapon_body.freeze = false
		stage = 2
	if stage == 2:
		for body in rag.weapon_body.get_colliding_bodies():
			if body in rag.bodies.values(): contacted_owner = true
	if time > 3.0:
		assert(contacted_owner, "Dropped rifle passed through the owner")
		print("PROP CONTACTS PASS initial overlap / separated exceptions / owner collision")
		get_tree().quit()
