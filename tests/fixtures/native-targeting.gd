extends Node3D

class Scene extends World:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

class Observer extends Soldier:
	var candidates: Array[Entity] = []
	func scan_candidates() -> Array:
		var result := []
		for e in candidates:
			var d := e.position - position
			result.append([d.x * d.x + d.z * d.z, e])
		return result


func register(w: World, e: Entity, id: int) -> void:
	e.world = w
	e.eid = id
	e.srv = true
	w._register(e)
	w.add_child(e)


func add_body(v: Vehicle, size: Vector3) -> void:
	v.body = StaticBody3D.new()
	v.body.collision_layer = Combat.MASK
	v.body.set_meta("eid", v.eid)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	v.body.add_child(shape)
	v.add_child(v.body)
	v.world.combat.dirty_collision(v.eid)


func benchmark(s: Observer) -> void:
	s.position = Vector3.ZERO
	s.udef = {}
	s.mounted = null
	s.forced_target = null
	s.path = PackedVector3Array()
	s._path_pending = false
	var samples := [[], []]
	for round in 8:
		for i in ([0, 1] if round % 2 == 0 else [1, 0]):
			s.world.settings.gdscript_targeting = i == 0
			var start := Time.get_ticks_usec()
			for scan in 1000:
				s._scan_work()
			if round > 1:
				samples[i].append((Time.get_ticks_usec() - start) / 1000.0)
	print("TARGETING_BENCH scans=1000 gdscript_ms=", samples[0], " rust_ms=", samples[1])


func outcome(s: Soldier, current: Entity, legacy: bool) -> Array:
	s.world.settings.gdscript_targeting = legacy
	s.target = current
	s.squad.known.clear()
	var state := s.world.rng.state
	s._scan_work()
	assert(s.world.rng.state == state, "Acquiring contacts must not draw gameplay randomness")
	var ids := PackedInt64Array()
	for e in s.vis_targets:
		ids.append(e.eid)
	return [s.target.eid if s.target else 0, ids, s.squad.known.keys()]


func _ready() -> void:
	var w := Scene.new()
	w.srv = true
	w.has_view = false
	w.combat = Combat.new(w)
	w.fires = Fires.new(w)
	add_child(w)
	w.combat.enable_native_collision()
	assert(w.combat._visibility != null)
	var rng := RandomNumberGenerator.new()
	rng.seed = 51397
	var s := Observer.new()
	s.team = 0
	register(w, s, 1)
	s.squad = Squad.new()
	s.squad.world = w
	s.squad.members = [s]
	for i in 8:
		var e: Entity = Soldier.new() if i < 5 else Vehicle.new()
		e.team = 1
		register(w, e, i + 10)
		if e is Vehicle:
			add_body(e, Vector3(3, 4, 4))
		s.candidates.append(e)
	for i in 4:
		var d := Drone.new()
		register(w, d, i + 30)
	var mount := Structure.new()
	mount.skind = "mg_nest"
	register(w, mount, 40)
	var forced_structure := Structure.new()
	register(w, forced_structure, 41)
	for i in 24:
		var block := Vehicle.new()
		register(w, block, 100 + i)
		block.position = Vector3(rng.randf_range(-50, 50), 0, rng.randf_range(-50, 50))
		block.rotation.y = rng.randf_range(-PI, PI)
		add_body(block, Vector3(3, 4, 5))
	await get_tree().physics_frame
	await get_tree().process_frame
	for trial in 600:
		w.time = trial * 0.3
		s.position = Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20))
		s.wdef = {"range": 20.0 + trial % 60, "ap": trial % 4 == 0}
		s.udef = {"bearer": trial % 29 == 0}
		s.rockets = trial % 3
		s.posture = trial % 5
		s.life = Soldier.Life.DOWNED if trial % 17 == 0 else Soldier.Life.ALIVE
		s.at_cover = trial % 2 == 0
		s.cover_type = trial % 4
		s.cover_h = [0.0, 0.5, 1.0, 1.5][trial % 4]
		s.cover_n = Vector3.RIGHT
		s.lean_dir = Vector3.LEFT
		s.peek_up = trial % 3 == 0
		s.blind = trial % 7 == 0
		s.path = PackedVector3Array([Vector3.ZERO]) if trial % 2 else PackedVector3Array()
		s.path_i = 0
		s._path_pending = trial % 5 == 0
		s.mounted = mount if trial % 3 == 0 else null
		s.task = "man" if s.mounted else ""
		s.task_phase = trial % 4
		mount.yaw = rng.randf_range(-PI, PI)
		for i in s.candidates.size():
			var e := s.candidates[i]
			e.position = Vector3(rng.randf_range(-50, 50), 0, rng.randf_range(-50, 50))
			if e is Soldier:
				e.life = Soldier.Life.DOWNED if (trial + i) % 7 == 0 else Soldier.Life.ALIVE
				e.utype = "mg_gunner" if (trial + i) % 4 == 0 else "rifleman"
				e.posture = (trial + i) % 5
				e.at_cover = trial % 2 == 0
				e.cover_type = (trial + i) % 4
				e.cover_h = 0.5 + i * 0.25
				e.cover_n = Vector3.FORWARD
				e.peek_up = trial % 3 == 0
				e.blind = trial % 9 == 0
				e.lean_dir = Vector3.RIGHT
			else:
				e.vdef = {"armor": (trial + i) % 4}
		for i in w.drones.size():
			var d: Drone = w.drones[i]
			d.position = Vector3(rng.randf_range(-38, 38), rng.randf_range(0, 20), rng.randf_range(-38, 38))
			d.team = (trial + i) % 3 - 1
			d.dead = (trial + i) % 9 == 0
			d.diving = (trial + i) % 5 == 0
		forced_structure.position = Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))
		forced_structure.gone = trial % 9 == 0
		s.forced_target = [null, s.candidates[trial % 8], w.drones[trial % 4], forced_structure][trial % 4]
		w.fires.smokes = [[Vector3.ZERO, 4.0], [Vector3(15, 1, 10), 5.0]] if trial % 2 else []
		w.combat.update_fire_smoke(w.fires.smokes)
		var current: Entity = s.candidates[trial % 8] if trial % 3 else null
		var expected := outcome(s, current, true)
		assert(outcome(s, current, false) == expected, "Target acquisition differs at trial %d" % trial)
		assert(outcome(s, current, false) == expected, "Repeated target acquisition differs at trial %d" % trial)
		if trial % 31 == 0:
			var collision: PackedByteArray = w.combat._collision.checkpoint()
			var visibility: PackedByteArray = w.combat._visibility.checkpoint()
			assert(w.combat._collision.restore(collision) and w.combat._visibility.restore(visibility))
			assert(outcome(s, current, false) == expected, "Restored contact geometry differs")
	if "--targeting-bench" in OS.get_cmdline_user_args():
		benchmark(s)
	w.free()
	print("NATIVE_TARGETING passed scans=600")
	get_tree().quit()
