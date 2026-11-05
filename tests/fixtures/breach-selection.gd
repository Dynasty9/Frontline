extends "res://tests/fixtures/infantry-breach.gd"


func _ready() -> void:
	assert(ClassDB.class_exists("BreachCore"))
	Nav.N = 64
	Nav.H = 32.0
	var worlds := [entry_world(false), entry_world(true)]
	for w in worlds:
		for id in range(12, 18):
			register(w, EntryWall.new(), id)
		w.nav = Nav.new()
		for z in Nav.N:
			for x in Nav.N:
				var index: int = z * Nav.N + x
				w.nav.cell_objs[index] = [[1, Nav.SOLID, Nav.FREE]] if (x + z) % 7 == 0 else []
				w.nav._recompute(index)
		w.nav.finalize()
	var selected := 0
	var geometry_checks := 0
	for trial in 2048:
		for w in worlds:
			w.time = 10.0
			w.trial = trial
			for house_id in [10, 11]:
				var h: Structure = w.entity(house_id)
				h.skind = "floor"
				h.position = Vector3((house_id - 10) * 16, 0, 0)
				h.size = Vector3(8, 0.2, 6)
				h.yaw = float(trial % 37) * 0.17
				h.gone = house_id == 10 and trial % 13 == 0
				for side in 3:
					var wall: Structure = w.entity(12 + (house_id - 10) * 3 + side)
					wall.skind = "house_wall"
					wall.variant = 2 if (trial + side) % 3 else 1
					wall.yaw = h.yaw + side * PI
					wall.position = h.position + Basis(Vector3.UP, h.yaw) * Vector3((side - 1) * 2, 0, 3)
					wall.gone = (trial + side) % 17 == 0
					wall.wrecked = (trial + side) % 19 == 0
			var s: Soldier = w.entity(1)
			s.position = Vector3(-9 + trial % 35, 0, 3 + (trial / 35) % 25)
			s.hold_pos = Vector3.ZERO if trial % 29 else Vector3(-50, 0, -50)
			s.bt_next_breach = 11.0 if trial % 11 == 0 else 0.0
			s.frags = 0 if trial % 23 == 0 else 2
			s.suppression = 60.0 if trial % 37 == 0 else 0.0
			s.wdef = Defs.WEAPONS.rifle
			s.mounted = w.entity(12) if trial % 41 == 0 else null
			s.task = "stretcher" if trial % 43 == 0 else ""
			s.bt_breach.clear()
			var q := Squad.new()
			q.world = w
			q.members = [s, w.entity(3)]
			s.squad = null if trial % 47 == 0 else q
			var mate: Soldier = w.entity(3)
			mate.life = Soldier.Life.ALIVE if trial % 5 else Soldier.Life.DOWNED
			mate.position = Vector3.ZERO if trial % 3 else Vector3(20, 0, 20)
			mate.task = "" if trial % 7 else "heal"
			mate.frags = trial % 2
			mate.mounted = w.entity(12) if trial % 4 == 0 else null
			if trial % 31 == 0:
				q.breach_by = mate
				mate.task = "breach"
			var enemy: Soldier = w.entity(7)
			enemy.position = w.entity(10 + trial % 2).position
			enemy.life = Soldier.Life.DEAD if trial % 53 == 0 else Soldier.Life.ALIVE
			q.known[7] = {"e": enemy, "t": -20.0 if trial % 59 == 0 else 10.0}
		var choices := []
		for w in worlds:
			choices.append(SoldierBrain.can_breach(w.entity(1)))
		assert(choices[0] == choices[1], "Breach choice %d" % trial)
		assert(worlds[0].entity(1).bt_next_breach == worlds[1].entity(1).bt_next_breach, "Check timer")
		if choices[0]:
			selected += 1
			var a: Array = worlds[0].entity(1).bt_breach
			var b: Array = worlds[1].entity(1).bt_breach
			assert(eid(a[0]) == eid(b[0]) and eid(a[2]) == eid(b[2]), "Selected contact")
			assert(eid(a[1][0]) == eid(b[1][0]), "Selected opening")
		for house_id in [10, 11]:
			var reference: Array = SoldierBrain.openings(worlds[0], worlds[0].entity(house_id))
			var native: Array = SoldierBrain.openings(worlds[1], worlds[1].entity(house_id))
			assert(reference.size() == native.size(), "Opening count %d" % trial)
			for i in reference.size():
				assert(eid(reference[i][0]) == eid(native[i][0]) and reference[i][3] == native[i][3])
				assert(reference[i][1] == native[i][1] and reference[i][2].distance_to(native[i][2]) < 0.000001, "Opening geometry %d" % trial)
			var h: Structure = worlds[0].entity(house_id)
			for offset in [Vector3.ZERO, Vector3(3.9, 0, 2.9), Vector3(4.1, 0, 0), Vector3(0, 0, 3.1)]:
				var p: Vector3 = h.position + Basis(Vector3.UP, h.yaw) * offset
				assert(eid(SoldierBrain.house_at(worlds[0], p)) == eid(SoldierBrain.house_at(worlds[1], p)), "House occupancy")
				geometry_checks += 1
	assert(selected > 100, "Fixture must actually choose breaches")
	for w in worlds:
		w.free()
	print("BREACH_SELECTION passed decisions=2048 geometry=%d" % geometry_checks)
	get_tree().quit()
