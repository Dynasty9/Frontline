extends "res://tests/fixtures/infantry-fire.gd"

func _ready() -> void:
	MapDims.N = 128
	MapDims.SIZE = 128.0
	MapDims.HALF = 64.0
	MapDims.BIOME = 128
	Nav.N = 128
	Nav.H = 64.0
	HNav.C = 16
	HNav.NC = 8
	HNav.NCC = 64
	HNav._corner = HNav._corners()
	TerrainMap.N = 128
	TerrainMap.H = 64.0
	TerrainMap.DN = 256
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var structures: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var random := SimulationRandom.new()
	var seen := {}
	checks = 0
	for mode in 3:
		for trial in 256:
			var w: World = ground_world()
			w.settings = {"rust_infantry": false}
			w.rules = Rules.new(w)
			w.rng.seed = trial + 19371
			random.seed = trial + 19371
			assert(units.load_state(12.0, []) and structures.load_state(16.0, []))
			for id in range(1, 7):
				var s := make_soldier(w, id, trial % 2 if id == 1 else id % 2)
				s.position = Vector3.ZERO if id == 1 else Vector3((id - 3) * 1.1, 0, [0.0, 20.0, 40.0, 3.0][trial % 4])
				s.life = Soldier.Life.ALIVE if id == 1 or (trial % 5 == 0 and id % 3 == 0) else Soldier.Life.DEAD
				s.loot = 0 if trial % 4 == 3 else id * 17
				w.soldiers.append(s)
			for id in range(8, 11):
				var st := Mount.new()
				st.world = w
				st.eid = id
				st.team = trial % 2 if trial % 11 else 1 - trial % 2
				st.skind = "fob" if id < 10 else "ammo_cache"
				st.position = Vector3(([10.0, 60.0, 90.0, 150.0] if id == 8 else ([65.0, 20.0, 120.0, 200.0] if id == 9 else [8.0, 30.0, 70.0, 120.0]))[trial % 4], 0, 0)
				st.radius = 2.0
				if id == 8 and trial % 8 == 2: st.position.x = 55.0
				st.built = trial % 3 != 0
				st.wrecked = id == 8 and trial % 2 == 0
				w.add_child(st)
				w.entities[id] = st
				w.structures.append(st)
				if id < 10: w.fob_structures.append(st)
				w._shash_add(st)
				assert(structures.insert(id, st.position, st.radius))
			var s: Soldier = w.entities[1]
			s.utype = "rifleman" if trial % 2 else "mg_gunner"
			s.udef = Defs.UNITS[s.utype]
			s.wdef = Defs.WEAPONS[s.udef.weapon]
			if mode == 0 and trial % 17 == 0: s.wdef = {}
			if trial % 13 == 0:
				var mount := Mount.new()
				mount.skind = "hmg_nest"
				s.gun_override = mount.mount_weapon()
				mount.free()
			s.mag = 0 if trial % 3 == 0 else trial % 20
			s.reserve = trial % 80
			s.say_cd = 3.0 if trial % 2 == 0 else 0.0
			s.scav_t = 11.0 if trial % 7 == 0 else 0.0
			s.resupply_t = 11.0 if trial % 9 == 0 else 0.0
			s.low_ammo_said = true
			s.out_said = true
			s.task = "retreat" if trial % 5 == 0 else ""
			if mode == 2:
				s.task = "resupply"
				s.task_ent = w.entities.get([0, 2, 3, 8, 10][trial % 5])
				s.hold_pos = Vector3(20, 0, 0) if trial % 2 else Vector3.ZERO
				s.task_ent2 = w.entities[4]
				s.backwards = true
				s.at_cover = true
				s.next_cover_eval = 20.0
				s.act = Soldier.Act.WALK
				if trial % 4 == 0:
					s.reserve = int(s.wdef.ammo) - s.mag - 3
			var blocks := []
			var types := PackedByteArray()
			for e: Entity in w.entities.values():
				if e is Soldier:
					blocks.append(soldier_bytes(e))
					types.append(0)
				else:
					assert(structure.load_state(StructureState.capture(e)))
					blocks.append(structure.checkpoint())
					types.append(1)
			assert(actors.load_state(100, types, blocks))
			assert(units.rebuild_units(actors))
			w._rebuild_uhash()
			for step in (1 if mode == 2 else 4):
				w.time = 10.0 + step * 2.1
				w.stats.clear()
				w.spoken.clear()
				w.nav.jobs.clear()
				var spoken := []
				var stats := {}
				if mode == 0:
					s._scavenge()
					var weapon: Dictionary = s.cur_weapon()
					var stock := PackedFloat64Array() if s.wdef.is_empty() else PackedFloat64Array([s.wdef.ammo, weapon.get("ammo", 0), weapon.get("mag", 30), weapon.get("reload", 2.0)])
					var result: Array = actors.scavenge_infantry(1, w.time, stock, units, random._backend)
					assert(result.size() == 4)
					if result[0] != 0:
						stats.scavenge = 1
						seen["scavenged"] = true
					if result[2] >= 0: spoken.append([1, ["Grabbing ammo.", "Taking his mags.", "He won't need these."][result[2]]])
					if result[3] >= 0: spoken.append([1, ["Reloading!", "Changing mag!", "Cover me, reloading!"][result[3]]])
				elif mode == 1:
					var chosen: bool = s._seek_resupply()
					var result: Array = actors.seek_infantry_supply(1, w.time, units, structures, random._backend)
					assert(result.size() == 5 and chosen == (result[0] >= 0))
					if chosen:
						var source: String = ["body", "cache", "fob"][result[0]]
						stats["resupply_" + source] = 1
						seen[source] = true
						assert(result[1] == InfantryState.entity_id(s.task_ent) and result[2] == s._path_revision)
						assert(w.nav.jobs.size() == 1 and [result[3], result[4]] == [w.nav.jobs[0][1], w.nav.jobs[0][4]])
						if result[0] != 0: spoken.append([1, "Back to the ammo cache!" if result[0] == 1 else "Falling back for ammo!"])
					else:
						seen["wait"] = true
						assert(w.nav.jobs.is_empty())
				else:
					s._resupply_tick(1.0 / 30.0)
					var result: Array = actors.arrive_infantry_supply(1, int(s.wdef.ammo), w.nav._planner)
					assert(result.size() == 5)
					if result[1]: spoken.append([1, "Got ammo."])
					seen["missing" if result[0] else "arrived"] = true
					var route: Array = result[4]
					if route.is_empty(): assert(w.nav.jobs.is_empty())
					else: assert(w.nav.jobs.size() == 1 and route == [s._path_revision, w.nav.jobs[0][1], w.nav.jobs[0][4]])
				assert(w.spoken == spoken, "Speech %d/%d/%d: %s / %s" % [mode, trial, step, w.spoken, spoken])
				assert(w.stats == stats, "Stats %d/%d/%d: %s / %s" % [mode, trial, step, w.stats, stats])
				assert(random.state == w.rng.state, "Random cursor %d/%d/%d" % [mode, trial, step])
				for member in w.soldiers:
					compare_actor(member, actors, "logistics %d/%d/%d/%d" % [mode, trial, step, member.eid])
					checks += 1
				if step == 1:
					var saved: PackedByteArray = actors.checkpoint()
					assert(actors.restore(saved) and actors.checkpoint() == saved)
			w.nav.jobs.clear()
			w.free()
	for key in ["scavenged", "body", "cache", "fob", "wait", "missing", "arrived"]: assert(seen.has(key), "Fixture must exercise " + key)
	print("INFANTRY_LOGISTICS passed states=%d outcomes=%s" % [checks, seen])
	get_tree().quit()
