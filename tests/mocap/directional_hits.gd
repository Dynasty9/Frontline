extends "res://tests/mocap/gameplay_stances.gd"
## Close inspection of the same hit layer used by living gameplay riflemen.
const DIRECTIONS := [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
const LABELS := ["hit from left", "hit from right", "hit from front", "hit from rear"]
var hit_index := 0
var blast_started := false
var impact_wall: StaticBody3D
var wall_contact := false

func _ready() -> void:
	super._ready()
	impact_wall = _surface(Vector3(0, 1.3, 1.4), Vector3(4, 2.6, 0.2), Color("424e5c"))
	camera.position = Vector3(-2.8, 1.8, -3.5)
	camera.look_at(Vector3(0, 0.9, 0))
	caption.text = "DIRECTIONAL HITS / captured rifle pose"

func _physics_process(dt: float) -> void:
	time += dt
	if not soldier.dead:
		proxy.pose(dt, Soldier.Life.ALIVE, Soldier.Post.STAND, Soldier.Act.SHOOT, 0.0, false, false)
	if hit_index < DIRECTIONS.size() and time >= 1.0 + hit_index * 1.5:
		soldier.hit(DIRECTIONS[hit_index], 1.2)
		caption.text = "DIRECTIONAL HITS / " + LABELS[hit_index]
		hit_index += 1
	if time >= 7.5 and not blast_started:
		blast_started = true
		caption.text = "BLAST / captured pose to wall impact"
		soldier.kill(Vector3(0, 1.5, 6), 1)
		soldier.ragdoll.set_collision_layers(16, 1)
	if soldier.dead:
		for body in soldier.ragdoll.bodies.values():
			wall_contact = wall_contact or impact_wall in body.get_colliding_bodies()
	if time >= 12.0:
		assert(hit_index == 4 and soldier.dead and is_instance_valid(soldier.ragdoll) and wall_contact)
		print("DIRECTIONAL REPLAY PASS four scripted hits, blast handoff and wall contact")
		get_tree().quit()
