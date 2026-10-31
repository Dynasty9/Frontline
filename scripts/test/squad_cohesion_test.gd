extends Node

class Ground extends RefCounted:
	var has_view := false
	var settings := {}
	var nav := Nav.new()
	var terrain: TerrainMap
	var walls := []
	func structures_near(_p: Vector3, _r: float) -> Array:
		return walls

var checks := 0
func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		push_error(what)
		TestRun.fail()

func _ready() -> void:
	TestRun.watch()
	var w := Ground.new()
	w.terrain = TerrainMap.new(w)
	var c := Vector3(0.5, 0, 2.5)
	for blocked in [false, true]:
		if blocked:
			for x in range(-20, 21):
				var cell := w.nav.cell_of(Vector3(x, 0, 0))
				w.nav.ikind[cell.y * Nav.N + cell.x] = Nav.LOW
				w.terrain.solid[w.terrain.idx_of(Vector3(x, 0, 0))] = 1
				if w.terrain._native:
					w.terrain._native_import(PackedInt32Array([w.terrain.idx_of(Vector3(x, 0, 0))]))
			var wall := Structure.new()
			wall.skind = "low_wall"
			for x in range(-8, 9):
				for z in [-1.0, 1.5]:
					wall.anc_p.append(Vector3(x, 0, z))
					wall.anc_n.append(Vector3.FORWARD)
					wall.anc_h.append(1.0)
					wall.anc_k.append(Cover.OVER)
			wall.cover_pts = wall.anc_p
			w.walls.append(wall)
		for wide in [false, true]:
			for count in [1, 4, 8, 12]:
				var slots := w.terrain.slots(c, Vector3.FORWARD, count, wide)
				check(slots.size() == count, "one slot for each man")
				var used := []
				for sl in slots:
					check(w.terrain.group_spot(sl[0], c, 6.5 if wide else 5.5), "every slot stays in the squad's circle and on its side of the wall")
					for other in used:
						check(sl[0].distance_to(other) >= 0.8, "squad mates have room to stand")
					used.append(sl[0])
				check(slots == w.terrain.slots(c, Vector3.FORWARD, count, wide), "preview and order are deterministic")
	check(not w.terrain.group_spot(Vector3(0, 0, -1), c, 6.5), "nearby cover across a vaultable wall is rejected")
	check(w.terrain.group_spot(Vector3(2, 0, 2), c, 6.5), "nearby cover on the same side remains usable")
	check(w.terrain.group_spot(Vector3(0.5, 0, 0.6), c, 6.5, Vector3.FORWARD), "wall padding does not hide a valid near-side anchor")
	check(not w.terrain.group_spot(Vector3(0.5, 0, -0.6), c, 6.5, Vector3.BACK), "the far-side anchor remains across the wall")
	var wall_slots := w.terrain.slots(Vector3(0.5, 0, 0.5), Vector3.FORWARD, 8)
	for sl in wall_slots:
		check(sl[0].z > 0.9, "clicking the wall places the squad together on its sheltered side")
	for z in range(1, 20):
		var cell := w.nav.cell_of(Vector3(-1, 0, z))
		w.nav.ikind[cell.y * Nav.N + cell.x] = Nav.SOLID
		w.terrain.solid[w.terrain.idx_of(Vector3(-1, 0, z))] = 1
		if w.terrain._native:
			w.terrain._native_import(PackedInt32Array([w.terrain.idx_of(Vector3(-1, 0, z))]))
	for sl in w.terrain.slots(c, Vector3.FORWARD, 8, true):
		check(sl[0].x >= 0 and sl[0].z > 0.9, "an L-shaped corner keeps the squad in the same pocket")
	for wall in w.walls:
		wall.free()
	w.walls.clear()
	w.nav = Nav.new()
	w.terrain = TerrainMap.new(w)
	var tall := Structure.new()
	tall.skind = "tall_wall"
	tall.size = Vector3(6, 2.6, 0.5)
	tall._define_parts()
	tall._compute_cover_pts()
	w.walls.append(tall)
	var front := []
	for i in tall.anc_p.size():
		if tall.anc_n[i] == Vector3.FORWARD and tall.anc_k[i] != Cover.STACK:
			front.append(tall.anc_p[i])
	check(front.size() == 4, "six metre wall has four front-row places")
	var rear := Cover.best_near(w, Vector3(0, 0, 3), 6, Vector3(0, 0, -40), front, Vector3(0, 0, 3), 5.5)
	check(not rear.is_empty() and rear[2].k == Cover.STACK, "full front row sends the next soldier behind the same wall")
	check(rear[0].z > 2 and rear[0].z < 3 and absf(rear[0].x) < 2, "rear row stays close and inside the wall ends")
	for p in front:
		check(rear[0].distance_to(p) >= 1.4, "rear soldier does not overlap the front row")
	var empty := Cover.best_near(w, Vector3(0, 0, 3), 6, Vector3(0, 0, -40), [], Vector3(0, 0, 3), 5.5)
	check(empty[2].k != Cover.STACK, "free front-row cover is preferred")
	check(rear[2].mat < empty[2].mat, "rear row has a lower effective protection rating")
	check(Cover.SUPP[rear[2].mat] > Cover.SUPP[empty[2].mat], "near misses suppress the rear row more than the front")
	check(Cover.mat_of(tall) == Cover.HARD, "rear row does not change the wall's bullet resistance")
	tall.free()
	w.terrain = null
	print("SQUADCOHESION %d checks, %d failures" % [checks, TestRun.failures])
	TestRun.quit(get_tree())
