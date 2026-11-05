extends "res://tests/fixtures/infantry-motion.gd"


func _ready() -> void:
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	MapDims.BIOME = 64
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	HNav.NCC = 16
	HNav._corner = HNav._corners()
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	var worlds := [make_world(), make_world()]
	for mode in 2:
		var w: World = worlds[mode]
		w.settings.rust_infantry = mode == 1
		make_soldier(w, 0, Vector3.ZERO, PackedVector3Array())
		add_structure(w, 3, "mg_nest", Vector3.ZERO, 0.0)
		for eid in range(101, 109):
			var other := Trooper.new()
			other.world = w
			other.eid = eid
			other.srv = true
			w.entities[eid] = other
			w.add_child(other)
		for i in w.nav.ikind.size():
			if i % 13 == 0:
				w.nav.ikind[i] = Nav.SOLID
			w.nav.inf.set_point_solid(Vector2i(i % Nav.N, i / Nav.N), w.nav.ikind[i] == Nav.SOLID)
		assert(w.nav._planner.load_cells(w.nav.ikind, w.nav.vkind, w.nav.heat))
		for i in w.terrain.dh.size():
			w.terrain.dh[i] = -0.05 * (i % 7)
		w.terrain.sync_deformation()
	var rng := RandomNumberGenerator.new()
	rng.seed = 18731
	for trial in 512:
		var p := Vector3(rng.randf_range(-5, 5), rng.randf_range(-1, 1), rng.randf_range(-5, 5))
		var offset := Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9))
		var normal := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		for w: World in worlds:
			w.rng.seed = trial + 931
			w.time = 0.0
			var s: Soldier = w.entity(100)
			s.position = p
			s.rotation.y = trial * 0.37 - 8.0
			s.life = trial % 6
			s.posture = trial % 5
			s.task = ["", "stretcher", "captor", "rescue"][trial % 4]
			s.dragged_by = w.entity(101) if trial % 17 == 0 else null
			s._gy = -0.1
			s._gy_t = 0.0 if trial % 3 == 0 else -1.0
			s.base_y = 0.06 if trial % 7 == 0 else 0.0
			s.at_cover = trial % 2 == 0
			s.cover_pos = p + offset
			s.cover_n = Vector3.ZERO if trial % 11 == 0 else normal
			s.cover_type = trial % 4
			s.peek_up = trial % 5 == 0
			s.last_shot_t = [0.0, -0.5, -1.0, -1.2, -99.0][trial % 5]
			s._sector = Vector3.ZERO if trial % 13 == 0 else -normal
			s.target = w.entity(101) if trial % 7 < 3 else null
			s.mounted = w.entity(3) if trial % 3 == 0 else null
			var mount: Structure = w.entity(3)
			mount.skind = ["mg_nest", "hmg_nest", "mortar_pit", "at_post"][trial % 4]
			mount.position += p - mount.mount_pos() + (Vector3(2, 0, 0) if trial % 6 == 0 else Vector3.ZERO)
		for tick in 30:
			var dt: float = [1.0 / 30.0, 1.0 / 60.0, 0.1, 0.0][trial % 4]
			var positions := []
			for i in 8:
				positions.append(p + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)))
			for w: World in worlds:
				w.time += dt
				w._uhash.clear()
				var s: Soldier = w.entity(100)
				w._hadd(s)
				for i in 8:
					var other: Soldier = w.entity(101 + i)
					other.position = s.position if i == 0 and tick % 3 == 0 else positions[i]
					other.life = (trial + i + tick) % 6
					other.team = i % 2
					other.gone = (trial + i) % 11 == 0
					w._hadd(other)
					if i == 7:
						other.position += Vector3(12, 0, 0)
				s._compute_sep_work()
				s._stationary_tick(dt)
			var a: Soldier = worlds[0].entity(100)
			var b: Soldier = worlds[1].entity(100)
			compare(a, b, "stationary trial=%d tick=%d" % [trial, tick])
			assert(a._sep.distance_to(b._sep) < 0.000001, "Separation direction trial=%d tick=%d" % [trial, tick])
			assert(a._shuffle == b._shuffle, "Stationary animation trial=%d tick=%d" % [trial, tick])
			if tick % 7 == 0:
				var saved: PackedByteArray = b._motion_core.checkpoint()
				assert(b._motion_core.restore(saved) and b._motion_core.checkpoint() == saved)
	print("INFANTRY_STATIONARY passed steps=", checks)
	for w: World in worlds:
		w.free()
	get_tree().quit()
