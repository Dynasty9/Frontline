extends "res://tests/fixtures/infantry-vitals.gd"


func compare_shock(a: Soldier, b: Soldier, label: String) -> void:
	for key in ["position", "rotation", "fling_v", "dive_dir"]:
		assert((a.get(key) as Vector3).distance_to(b.get(key)) < 0.00001, "%s %s ref=%s rust=%s" % [label, key, a.get(key), b.get(key)])
	for key in ["dazed_t", "flinch_t", "task_t", "suppression", "say_cd"]:
		assert(absf(float(a.get(key)) - float(b.get(key))) < 0.000000001, "%s %s ref=%s rust=%s" % [label, key, a.get(key), b.get(key)])
	for key in ["flinging", "life", "posture", "act", "task", "at_cover", "next_cover_eval", "path", "dragged_by", "carried_by"]:
		if key in ["dragged_by", "carried_by"]:
			assert((a.dragged_by == null) == (b.dragged_by == null) and a.carried_by.size() == b.carried_by.size(), label)
		else:
			assert(a.get(key) == b.get(key), "%s %s" % [label, key])
	assert(a.world.rng.state == b.world.rng.state, "Random cursor " + label)
	assert(a.world.spoken == b.world.spoken and a.world.stats == b.world.stats, "Shock events " + label)
	outcomes[a.act] = true
	checks += 1


func _ready() -> void:
	assert(ClassDB.class_exists("InfantryShockCore"))
	Nav.N = 128
	Nav.H = 64.0
	var worlds := [make_world(false), make_world(true)]
	for w in worlds:
		w.nav = Nav.new()
		for z in Nav.N:
			for x in Nav.N:
				w.nav.ikind[z * Nav.N + x] = Nav.SOLID if x % 7 == 0 else x % 3
		w.nav.finalize()
	for trial in 512:
		var pair: Array[Soldier] = []
		var mounts: Array[Mount] = []
		for w in worlds:
			w.rng.seed = 731 + trial
			w.stats.clear()
			w.spoken.clear()
			var s := make_soldier(w, 1, trial % 2)
			s.life = trial % 6
			s.posture = trial % 5
			s.position = Vector3(trial % 17 - 8, 0, (trial / 17) % 17 - 8)
			s.rotation.y = trial * 0.031
			s.at_cover = true
			s.next_cover_eval = 12.0
			s.task = ["", "rescue", "stretcher"][trial % 3]
			s.task_phase = (trial / 3) % 2
			s.task_t = 0.2
			s.act_t = 0.4 if trial % 7 == 0 else 0.0
			s.dive_t = 0.4 if trial % 11 == 0 else 0.0
			s.suppression = float(trial % 70)
			s.path = PackedVector3Array([Vector3(20, 0, 20)])
			if trial % 17 == 0:
				s.carried_by.append(s)
			if trial % 19 == 0:
				s.dragged_by = s
			if trial % 30 == 0:
				s.dazed_t = 2.0
				var mount := Mount.new()
				mount.skind = ["mg_nest", "hmg_nest", "mortar_pit", "at_post"][(trial / 30) % 4]
				w.add_child(mount)
				mount.position += s.position - mount.mount_pos()
				if trial % 90 == 0:
					mount.position.x += 3.0
				s.mounted = mount
				mounts.append(mount)
			pair.append(s)
		for tick in 180:
			for s in pair:
				s.world.time = tick / 30.0
				if tick == 0 or tick == 80:
					var center := s.position if trial % 2 else s.position - Vector3(1.3, 0, 0.7)
					s.fling_from(center, [0.8, 1.0, 3.0, 10.0, 20.0][(trial / 6) % 5])
				if tick % 11 == 0:
					s.flinch_from(Vector3.ZERO, float(trial % 9), 10.0)
				if s.flinging:
					s._fling_tick([1.0 / 30.0, 0.02, 0.08][trial % 3])
				elif s.dazed_t > 0.0:
					s._dazed_tick(1.0 / 30.0)
			compare_shock(pair[0], pair[1], "trial=%d tick=%d" % [trial, tick])
			if tick == 20 and pair[1]._shock_core:
				var saved: PackedByteArray = pair[1]._shock_core.checkpoint()
				assert(pair[1]._shock_core.restore(saved))
		for s in pair:
			s.world.entities.erase(s.eid)
			s.free()
		for mount in mounts:
			mount.free()
	assert(outcomes.has(Soldier.Act.FLUNG) and outcomes.has(Soldier.Act.DAZED) and outcomes.has(Soldier.Act.FLINCH))
	for w in worlds:
		w.free()
	print("INFANTRY_SHOCK passed steps=%d" % checks)
