extends Node

class IndexedWorld extends World:
	var scenery_queries := 0
	func structures_near(p: Vector3, r: float, floors_only := false) -> Array:
		scenery_queries += 1
		return super.structures_near(p, r, floors_only)

func _ready() -> void:
	var w := IndexedWorld.new()
	w.time = 1000.0
	var q := Squad.new()
	q.world = w
	q.team = 0
	q.alert_t = -1000.0
	for i in 2:
		var s := Soldier.new()
		q.members.append(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = 371
	for i in 300:
		var st := Structure.new()
		st.world = w
		st.eid = i + 1
		st.skind = "fob" if i % 11 == 0 else "tree"
		st.team = i % 3 - 1
		st.vis_mask = 1 if i % 2 == 0 else 0
		st.position = Vector3(rng.randf_range(-500, 500), 0, rng.randf_range(-500, 500))
		st.radius = rng.randf_range(1, 20)
		w._register(st)
		w._shash_add(st)
		w.add_child(st)
	for i in 120:
		var dest := Vector3(rng.randf_range(60, 400), 0, rng.randf_range(-400, 400))
		var expected := false
		for st in w.structures_near(dest, 150.0):
			if st.team >= 0 and st.team != q.team and st.is_player_building() and st.visible_to_team(q.team):
				expected = true
		w.scenery_queries = 0
		assert(Tactics.bounding_wanted(q, dest, 0) == expected, "Indexed contacts must match the spatial-query reference")
		assert(w.scenery_queries == 0, "Tactical contact checks must not enumerate scenery")
	var target: Structure = w.structures[0]
	target.skind = "fob"
	target.team = 1
	target.vis_mask = 1
	target.position = Vector3(200, 0, 0)
	for st in w.structures:
		if st != target:
			st.team = -1
	assert(Tactics.bounding_wanted(q, target.position, 0))
	target.vis_mask = 0
	assert(not Tactics.bounding_wanted(q, target.position, 0), "Hidden buildings must not reveal contact")
	target.vis_mask = 1
	target.team = 0
	assert(not Tactics.bounding_wanted(q, target.position, 0), "Captured buildings must stop being hostile")
	target.team = -1
	assert(not Tactics.bounding_wanted(q, target.position, 0))
	target.team = 1
	target.gone = true
	assert(not Tactics.bounding_wanted(q, target.position, 0), "Destroyed contacts must not trigger bounding")
	for s in q.members:
		s.free()
	w.free()
	print("TACTICAL_CONTACTS passed")
	get_tree().quit()

