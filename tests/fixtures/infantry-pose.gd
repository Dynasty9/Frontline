extends "res://tests/fixtures/infantry-aim.gd"


func _ready() -> void:
	var worlds := [make_world(false), make_world(true)]
	var checks := 0
	for life in 6:
		for posture in 5:
			for cover in 4:
				for mount in 4:
					for height in [-0.2, 0.0, 0.4, 0.619999, 0.62, 0.799999, 0.8, 1.119999, 1.12, 1.6]:
						for phase in 4:
							var results := []
							for w in worlds:
								var s: Soldier = w.entity(1)
								s.life = life
								s.posture = posture
								s.position = Vector3(13.375, -2.75, -48.25)
								s.at_cover = checks % 3 != 0
								s.cover_type = cover
								s.cover_h = height
								s.cover_n = Vector3(0.3, 0.0, -0.7).normalized()
								s.lean_dir = Vector3(-0.7, 0.0, -0.3).normalized()
								s.peek_up = phase % 2 == 0
								s.blind = phase >= 2
								s.path = PackedVector3Array([Vector3.ZERO]) if checks % 5 != 0 else PackedVector3Array()
								s.path_i = 0
								s._path_pending = checks % 7 == 0
								s.move_mode = checks % 3
								s._gy = -1.0 if checks % 2 else 0.0
								s.mounted = w.entity(5) if mount > 0 else null
								if s.mounted:
									s.mounted.skind = "trench" if mount == 1 else "mg_nest"
									s.mounted.variant = 1 if mount == 3 else 0
								results.append([s.eye_pos(), s.scan_eye(), s.exposed_points(), s.center_point(), s.hit_factor(), s._over_post(false), s._over_post(true), s._aim_point(s), w.rng.state])
							assert(results[0] == results[1], "Combat pose trial=%d ref=%s rust=%s" % [checks, results[0], results[1]])
							assert(worlds[1].entity(1)._pose_core != null, "Exercise Rust geometry")
							checks += 1
	var core: RefCounted = ClassDB.instantiate("InfantryPoseCore")
	assert(core.query([], 0) == null and core.query(["invalid"], 0) == null)
	var centers := []
	for w in worlds:
		var s: Soldier = w.entity(1)
		s.mounted = w.entity(5)
		s.mounted.free()
		w.entities.erase(5)
		centers.append(s.center_point())
		s.mounted = null
	assert(centers[0] == centers[1], "A removed mount must not break body-center queries")
	for w in worlds:
		w.free()
	print("INFANTRY_POSE passed cases=", checks)
	get_tree().quit()
