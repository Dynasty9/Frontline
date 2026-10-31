extends "res://tests/fixtures/infantry-vitals.gd"

class BuildingWorld extends Scene:
	var nearby := []
	var roofs := []
	var messages := []
	func soldiers_near(_p: Vector3, _r: float) -> Array:
		return nearby
	func structures_near(_p: Vector3, _r: float, _floors_only := false) -> Array:
		return roofs
	func send_msg(team_id: int, kind: String, text: String, _ping = null) -> void:
		messages.append([team_id, kind, text])
	func acting_owner(peer: int, _team_id: int) -> int:
		return peer

class BuildingRules extends Rules:
	var last := false
	var can_produce := true
	var captured := -1
	var repaired := 0
	var completed := []
	var notifications := []
	func fobs(_team_id: int, _include_wrecked := true) -> Array:
		return [null] if last else [null, null]
	func capture_fob(_s: Structure, team_id: int) -> void:
		captured = team_id
	func capture_town(_s: Structure, team_id: int) -> void:
		captured = team_id
	func on_fob_changed(_team_id: int) -> void:
		repaired += 1
	func has_cap(_team_id: int, _n: int) -> bool:
		return can_produce
	func notify(_peer: int, _team_id: int, text: String) -> void:
		notifications.append(text)
	func apply_upgrade(_team_id: int, key: String) -> void:
		completed.append(key)

class Building extends Structure:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _complete() -> void:
		# Terrain and presentation effects are tested separately; retain the real construction state transition.
		built = true
		progress = 1.0
		hp = max_hp

class ResupplySoldier extends Trooper:
	var supplied := 0.0
	func resupply(dt: float) -> void:
		supplied += dt

func compare_building(s: Structure, core: RefCounted, label: String) -> void:
	var expected := StructureState.capture(s)
	var actual: Array = core.values()
	assert(actual.size() == expected.size(), label)
	for group in expected.size():
		assert(expected[group] == actual[group], "%s group %d: %s / %s" % [label, group, expected[group], actual[group]])

func _ready() -> void:
	var w := BuildingWorld.new()
	w.srv = true
	w.has_view = false
	add_child(w)
	var rules := BuildingRules.new(w)
	w.rules = rules
	w.battle = BattleStats.new(w)
	var core: RefCounted = ClassDB.instantiate("StructureStateCore")
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var layout := RandomNumberGenerator.new()
	layout.seed = 3719
	var kinds := ["fob", "town", "barracks", "research", "car", "tree", "house_wall", "ammo_cache", "low_wall", "roof", "bunker", "wreck"]
	checks = 0
	for trial in 192:
		for operation in 6:
			var s := Building.new()
			s.eid = 7
			s.world = w
			s.srv = false
			s.skind = kinds[trial % kinds.size()]
			s.team = trial % 3 - 1
			s.owner_peer = trial % 5 - 2
			s.position = Vector3(layout.randf_range(-30, 30), 0.7, layout.randf_range(-30, 30))
			s.yaw = layout.randf_range(-PI, PI)
			s.size = Vector3(5.1, 3.0, 7.9)
			s.variant = trial % 10
			s.progress = [0.0, 0.33, 0.99, 1.0][trial % 4]
			s.built = trial % 3 != 0
			s.hp = [0.0, 20.0, 49.9, 70.0, 100.0][trial % 5]
			s.max_hp = 100.0
			s.sname = "Village — 北"
			s.radius = 5.7
			s.foot = Vector2(2.55, 3.95)
			s.parts = [s._part(Vector3(0, 1.05, 0.08), Vector3(1.8, 2.1, 0.08), 0, 0, false, true), s._part(Vector3(2, 1, 0), Vector3(2, 2, 0.5), 3, 2)]
			s.parts[0].door = true
			s.door_shut = true
			s.cover_pts = PackedVector3Array([Vector3.ONE, Vector3.LEFT])
			s.anc_p = PackedVector3Array([Vector3(3, 0, 2), Vector3(2, 0, -3)])
			s.anc_n = PackedVector3Array([Vector3.RIGHT, Vector3.FORWARD])
			s.anc_h = PackedFloat32Array([0.7, 1.2])
			s.anc_k = PackedByteArray([2, 5])
			s.nav_cells = [7, 3, 7]
			s.hash_cells = [Vector2i(1, -3), Vector2i(-2, 4)]
			s.wrecked = trial % 2 == 0
			s.supply = 137.3
			s.cap_prog = [0.0, 33.3, 98.9, 99.9][trial % 4]
			s.cap_team = (trial + 1) % 3 - 1
			s.completed_order = trial + 11
			s.road = PackedVector3Array([Vector3.LEFT, Vector3.FORWARD])
			s.truck_t = 1.3
			s.supply_status = "contested"
			s._alert_t = 31.0
			s.zone_c = Vector3.ZERO
			s.zone_r = 120.0
			s.houses0 = trial % 5 - 1
			s.intact = [0.0, 0.5, 0.99, 1.0][trial % 4]
			s._house_t = [0.1, 0.5, 0.6, 10.0][trial % 4]
			s._tick_t = [0.0, 0.01, 0.1, 0.49][trial % 4]
			s.queue_frac = 0.37
			s.prod_status = "cap" if trial % 3 else ""
			s.rally = Vector3(1, 0, 3) if trial % 3 else Vector3.INF
			s.bearer_t = 3.7
			s.tilt = Vector2(0.13, -0.37)
			s.vk = "tank"
			s.burn = 0.7 if trial % 2 else 0.0
			s.burnt = trial % 7 == 0
			s.fire_k = "roof"
			s.fuel = 43.7
			s.fuel_max = 70.0
			s.fire_queue = [[Vector3(1, 0, 3), "he"], [Vector3(-3, 0, 1), "smoke"]]
			s.hit_by = [-2, 1, "rifleman", 13]
			s.hit_from = Vector3(3, 0, -7)
			w.add_child(s)
			w.time = 30.0 + trial * 0.13
			w.messages.clear()
			w.props.clear()
			rules.captured = -1
			rules.repaired = 0
			rules.last = trial % 2 == 0
			rules.notifications.clear()
			rules.completed.clear()
			w.nearby.clear()
			w.roofs.clear()
			if operation in [3, 4]:
				s.skind = "fob" if operation == 3 else "town"
				s.team = trial % 2 if operation == 3 else trial % 3 - 1
				s.built = true
				for team_id in 2:
					var n: int = [0, 2, 8][(trial + team_id) % 3]
					for i in n:
						var man := ResupplySoldier.new()
						man.eid = 100 + team_id * 10 + i
						man.team = team_id
						man.udef = Defs.UNITS.rifleman
						w.nearby.append(man)
				for i in trial % 5:
					var roof := Building.new()
					roof.skind = "roof"
					roof.position = Vector3(i, 0, i)
					w.roofs.append(roof)
			if operation == 5:
				s.skind = "research" if trial % 2 else "barracks"
				s.team = trial % 2
				s.built = true
				if trial % 7:
					var item: String = Defs.UPGRADES.keys()[0] if s.skind == "research" else Defs.SQUADS.keys()[0]
					var remaining: float = [0.01, 0.1, 7.3][trial % 3] if s.skind == "research" else 7.3
					s.queue = [{"item": item, "t": remaining, "total": 10.0, "owner": 123, "cost": 77}]
				rules.can_produce = trial % 3 != 0
			assert(core.load_state(StructureState.capture(s)), "load %d/%d" % [trial, operation])
			compare_building(s, core, "initial")
			var k := clampi(s.variant, 0, 1)
			var economy := PackedFloat64Array([Defs.TOWN_STOCK[k], Defs.TOWN_YIELD[k], Defs.TOWN_PACE[k]])
			match operation:
				0:
					var pos := s.position + Basis(Vector3.UP, s.yaw) * Vector3(0.3, 0, 0.6)
					var dir := Basis(Vector3.UP, s.yaw) * Vector3.FORWARD
					var queries: Array = core.queries(pos, dir)
					assert(s.front_dir().distance_to(queries[0]) < 0.000001)
					assert(s.exit_pos().distance_to(queries[1]) < 0.00001)
					assert(queries.slice(2) == [s.needs_work(), s.fire_kind(), s.door_blocks(pos, dir), s.town_yield_factor()])
					s.open_door(null, false)
					assert(core.open_door() == 1)
				1:
					var was := s.burnt
					s.char_out()
					assert(core.char_out() == int(not was))
				2:
					var amount: float = [0.0, 0.07, 1.7, 100.0][trial % 4]
					var build_time := PackedFloat64Array([float(Defs.BUILDINGS[s.skind].time)]) if Defs.BUILDINGS.has(s.skind) else PackedFloat64Array()
					var built_before := s.built
					var worked := s.add_work(amount)
					assert(core.add_work(amount, build_time) == PackedByteArray([int(worked), int(not built_before and s.built), int(rules.repaired > 0)]))
				3, 4:
					var dt: float = [0.03, 0.1, 0.5][trial % 3]
					var next_tick := s._tick_t - dt
					var due := next_tick <= 0.0
					var recount := operation == 4 and due and s._house_t <= 0.5
					var stage: int = core.begin_tick(dt, economy)
					assert(stage == (1 if operation == 3 else (3 if recount else 2)) if due else stage == 0)
					var result := PackedInt32Array()
					if due:
						var counts := PackedInt32Array([0, 0])
						for man: Soldier in w.nearby:
							counts[man.team] += 1
						if recount:
							assert(core.count_houses(w.roofs.size()) >= 0)
						result = core.fob_capture(counts, rules.last) if operation == 3 else core.town_capture(counts, w.time, economy)
						s.net_dirty = false
					s.sim(dt)
					if due:
						assert(result[1] == int(not w.messages.is_empty()))
						assert(result[3] == rules.captured)
						for man: ResupplySoldier in w.nearby:
							assert(man.supplied == (0.5 if result[4] and man.team == s.team else 0.0))
				5:
					var dt := 0.13
					var old_size := s.queue.size()
					var first: Dictionary = s.queue[0].duplicate() if old_size else {}
					assert(core.begin_tick(dt, economy) == 4)
					var result: Array = core.produce(dt, rules.can_produce)
					s.sim(dt)
					assert(result[1] == (not rules.notifications.is_empty()))
					assert(result[2].is_empty() == (s.queue.size() == old_size))
					if not result[2].is_empty():
						assert(result[2] == [first.item, first.t - dt, first.total, first.owner, first.cost])
			compare_building(s, core, "case %d/%d" % [trial, operation])
			var saved: PackedByteArray = core.checkpoint()
			assert(actors.load_state(8, PackedByteArray([1]), [saved]))
			assert(actors.actor_state(7) == saved)
			assert(core.restore(saved) and core.checkpoint() == saved)
			var invalid := saved.duplicate()
			invalid[4] = 2
			assert(not core.restore(invalid) and core.checkpoint() == saved)
			for man in w.nearby:
				man.free()
			for roof in w.roofs:
				roof.free()
			s.free()
			checks += 1
	print("STRUCTURE_STATE passed cases=%d" % checks)
	get_tree().quit()
