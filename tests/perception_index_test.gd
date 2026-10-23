extends Node

var failures := 0


func _ready() -> void:
	var w := World.new()
	w.has_view = false
	w.time = 30.0
	w.terrain = TerrainMap.new(w)
	w.rng.seed = 4719
	for i in 350:
		var s := Soldier.new()
		s.world = w
		s.eid = i + 1
		s.team = i % 3 - 1
		s.position = Vector3(w.rng.randf_range(-110, 110), 0, w.rng.randf_range(-110, 110))
		s.life = [Soldier.Life.ALIVE, Soldier.Life.DOWNED, Soldier.Life.DEAD, Soldier.Life.HIDDEN][i % 4]
		s.posture = Soldier.Post.PRONE if i % 5 == 0 else Soldier.Post.STAND
		s.last_shot_t = 29.0 if i % 7 == 0 else 0.0
		w.soldiers.append(s)
		w.entities[s.eid] = s
		w.add_child(s)
		var idx := w.terrain.idx_of(s.position)
		w.terrain.netted[idx] = 1 if i % 9 == 0 else 0
		w.terrain.trench[idx] = 1 if i % 11 == 0 else 0
	for i in 24:
		var vehicle := Vehicle.new()
		vehicle.world = w
		vehicle.eid = 1000 + i
		vehicle.team = i % 3 - 1
		vehicle.vkind = "gunship" if i % 4 == 0 else "tank"
		vehicle.vdef = Defs.VEHICLES[vehicle.vkind]
		vehicle.position = Vector3(w.rng.randf_range(-110, 110), 20.0 if i % 4 == 0 else 0.0, w.rng.randf_range(-110, 110))
		w.vehicles.append(vehicle)
		w.entities[vehicle.eid] = vehicle
		w.add_child(vehicle)
		w.terrain.netted[w.terrain.idx_of(vehicle.position)] = i % 2
	var native_search: RefCounted
	if ClassDB.class_exists("PerceptionSearch"):
		native_search = ClassDB.instantiate("PerceptionSearch")
		w.perception = native_search
	w._rebuild_uhash()
	w.perception = null
	for s: Soldier in w.soldiers:
		if s.team < 0:
			continue
		var expected := []
		for e: Entity in w.soldiers + w.vehicles:
			if e.team < 0 or e.team == s.team:
				continue
			var r := maxf(s.sight_range(), 85.0)
			if e is Soldier:
				if e.life not in [Soldier.Life.ALIVE, Soldier.Life.DOWNED] or (e.life == Soldier.Life.DOWNED and w.time - e.last_shot_t > 2.0):
					continue
				r = s.sight_range() * w.terrain.concealment(e.position)
				if w.time - e.last_shot_t > 8.0 and not e.is_moving() and (e.at_cover or e.posture == Soldier.Post.PRONE):
					r *= 0.7
			elif not e.is_air() and w.terrain.netted[w.terrain.idx_of(e.position)] > 0:
				r *= 0.5
			var distance := Defs.flat(s.position - e.position).length_squared()
			if distance <= r * r:
				expected.append([distance, e])
		expected.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1].eid < b[1].eid))
		if expected.size() > 7:
			expected.resize(7)
		var actual := s.scan_candidates()
		var actual_ids := actual.map(func(item): return item[1].eid)
		var expected_ids := expected.map(func(item): return item[1].eid)
		if actual_ids != expected_ids:
			failures += 1
			push_error("Perception differs from exhaustive search for %d" % s.eid)
		if native_search:
			w.perception = native_search
			var native_ids := s.scan_candidates().map(func(item): return item[1].eid)
			w.perception = null
			if native_ids != expected_ids:
				failures += 1
				push_error("Native perception differs from exhaustive search for %d" % s.eid)
	# World owns the test soldiers; it never entered the scene tree.
	w.free()
	print("PERCEPTION_INDEX_TEST native=%s failures=%d" % [native_search != null, failures])
	get_tree().quit(1 if failures else 0)
