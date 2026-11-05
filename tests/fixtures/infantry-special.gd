extends "res://tests/fixtures/infantry-fire.gd"

class SpecialRoutes extends RecordedRoutes:
	var cancelled := []
	func cancel_path(id: int) -> void:
		cancelled.append(id)

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
	var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var qcore: RefCounted = ClassDB.instantiate("SquadStateCore")
	var random := SimulationRandom.new()
	var seen := {}
	checks = 0
	for mode in 4:
		for trial in 128:
			var w: World = ground_world()
			var nav := SpecialRoutes.new()
			nav._planner = w.nav._planner
			w.nav = nav
			w.settings = {"rust_infantry": false}
			w.rules = Rules.new(w)
			w.water = WaterMap.new(w)
			w.combat = ScanCombat.new(w)
			w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
			w.combat._visibility = ClassDB.instantiate("VisibilityCore")
			w.rng.seed = 27839 + trial
			random.seed = 27839 + trial
			var q := Squad.new()
			q.world = w
			q.sid = 9
			q.ambush = trial % 17 == 0
			if trial % 2 == 0:
				q.fire_queue = [[Vector3([24.99, 25.0, 140.0, 140.01][(trial / 2) % 4], 3, 0), "smoke"], [Vector3(100, 0, 20), "he"]]
			var bearers := PackedInt64Array()
			for id in range(1, 9):
				var s := make_soldier(w, id, trial % 2 if id == 1 else (trial + id) % 3 - 1)
				s.utype = "bearer" if id == 8 and trial % 5 == 0 else "rifleman"
				s.udef = Defs.UNITS[s.utype]
				s.wdef = Defs.WEAPONS.get(s.udef.weapon, {})
				if s.is_bearer(): bearers.append(id)
				s.position = Vector3.ZERO if id == 1 else Vector3([1.89, 1.9, 1.91][(trial + id) % 3] if mode == 0 else [24.99, 25.0, 50.0, 80.0, 149.99, 150.0, 229.99, 230.01][trial % 8] + (id % 3) * 1.1, 0, (id / 3) * 0.2)
				s.life = Soldier.Life.ALIVE if id == 1 else (Soldier.Life.DOWNED if (trial + id) % 7 == 0 else Soldier.Life.ALIVE)
				s.flinging = id != 1 and (trial + id) % 5 == 0
				s.vis_mask = (trial + id) % 4
				s.at_cover = id % 2 == 0
				w.soldiers.append(s)
			var armor := PackedInt64Array()
			for id in [10, 11, 12]:
				var v := Carrier.new()
				v.world = w
				v.eid = id
				v.team = (trial + id) % 3 - 1
				v.vkind = ["tank", "btr", "truck"][id - 10]
				v.vdef = Defs.VEHICLES[v.vkind]
				v.position = Vector3([30.0, 59.99, 60.0, 69.99, 70.0, 74.99, 75.0, 150.0, 230.0][(trial + id) % 9], 0, (id - 10) * 5.0)
				v.vis_mask = (trial + id) % 4
				v.hp = 100.0
				v.body = StaticBody3D.new()
				v.add_child(v.body)
				w.combat._rid_entities[v.body.get_rid()] = id
				w.add_child(v)
				w.entities[id] = v
				w.vehicles.append(v)
				armor.append_array(PackedInt64Array([id, v.vdef.armor]))
				q.known[id] = {"e": v, "pos": v.position, "t": [3.99, 4.0, 4.01, 10.0][(trial + id) % 4]}
				collider(w.combat._collision, id, v.position + Vector3(0, 1.2, 0), Vector3(1.3, 1.2, 2.0))
			for id in [20, 21]:
				var st := Mount.new()
				st.world = w
				st.eid = id
				st.team = (trial + id) % 3 - 1
				st.skind = ["bunker", "watchtower", "mg_nest", "house_wall"][(trial + id) % 4]
				st.position = Vector3(59.99 if id == 20 else -60.0, 0, 0)
				st.built = trial % 5 != 0
				st.seen_mask = (trial + id) % 4
				w.add_child(st)
				w.entities[id] = st
				w.structures.append(st)
				if st.team >= 0: w.owned_structures.append(st)
				if trial % 3 == 0: collider(w.combat._collision, id, Vector3(20, 1, id - 20), Vector3(0.3, 2, 7))
			if trial % 2 == 0: w.owned_structures.reverse()
			var owned := InfantryState.entity_ids(w.owned_structures)
			var s: Soldier = w.entities[1]
			s.squad = q if trial % 13 else null
			s.sid = 9 if s.squad else 0
			s.rockets = trial % 4
			s.drones_left = trial % 3
			if trial % 7 == 0:
				s.drone_ctrl = Drone.new()
				s.drone_ctrl.eid = 99
				s.add_child(s.drone_ctrl)
			s.mortar_rounds = trial % 5
			s.rocket_cd = 11.0 if trial % 7 == 0 else 0.0
			s.drone_cd = 11.0 if trial % 11 == 0 else 0.0
			s.mortar_cd = 11.0 if trial % 17 == 0 else 0.0
			s.melee_cd = 11.0 if trial % 19 == 0 else 0.0
			s.say_cd = 7.0 if trial % 3 == 0 else 0.0
			s.wdef = {} if trial % 11 == 0 else Defs.WEAPONS.rifle
			s._gy = -0.33
			s._gy_t = 11.0 if trial % 3 == 0 else 0.0
			s.path = PackedVector3Array([Vector3(20, 0, 20)]) if trial % 13 == 0 else PackedVector3Array()
			s.vis_targets = [w.entities[10], w.entities[11]] if trial % 3 == 0 else []
			s.forced_target = w.entities[20] if trial % 4 == 0 else null
			q.members = [s]
			var kinds := PackedByteArray()
			var blocks := []
			for e: Entity in w.entities.values():
				if e is Soldier:
					kinds.append(0)
					blocks.append(soldier_bytes(e))
				elif e is Vehicle:
					kinds.append(2)
					assert(vehicle.load_state(VehicleState.capture(e)))
					blocks.append(vehicle.checkpoint())
				else:
					kinds.append(1)
					assert(structure.load_state(StructureState.capture(e)))
					blocks.append(structure.checkpoint())
			assert(actors.load_state(100, kinds, blocks))
			assert(qcore.load_state(SquadState.capture(q)))
			w._rebuild_uhash()
			if trial % 7 == 0:
				w._uhash.clear()
				for e: Entity in w.soldiers + w.vehicles:
					var p := e.position
					if e.eid == 2: e.position += Vector3(24, 0, 0)
					w._hadd(e)
					e.position = p
			var cells := []
			for cell in w._uhash:
				cells.append([cell, InfantryState.entity_ids(w._uhash[cell])])
			assert(units.load_state(12.0, cells))
			for step in 8:
				w.time = 10.0 + step * [0.1, 2.1, 6.1, 20.1][trial % 4]
				w.spoken.clear()
				w.stats.clear()
				w.nav.cancelled.clear()
				var targets: Array = actors.fire_targets(s.team, s.position, PackedFloat64Array([30, 130, 230]), owned, units, armor, bearers)
				var mortar: Vector3 = w.rules.mortar_target(s.team, s.position, 30, 130)
				assert(targets.size() == 2 and targets[0] == (mortar if mortar != Vector3.INF else null))
				assert(targets[1] == InfantryState.entity_id(w.rules.fpv_target(s.team, s.position, 230)))
				var expected: bool
				match mode:
					0: expected = s._try_melee()
					1: expected = s._try_rocket()
					2: expected = s._try_drone()
					_: expected = s._try_mortar()
				var result: Array = actors.try_infantry_special(1, mode, w.time, not s.wdef.is_empty(), qcore if s.squad else null,
					owned, units, w.terrain._native, w.water.deck, w.combat._collision, w.combat._visibility, armor, bearers, random._backend)
				assert(result.size() == 3 and result[0] == expected, "decision %d/%d/%d" % [mode, trial, step])
				seen["%d/%s" % [mode, expected]] = true
				for other: Soldier in w.soldiers:
					compare_actor(other, actors, "%d/%d/%d/%d" % [mode, trial, step, other.eid])
					checks += 1
				assert(SquadState.capture(q) == qcore.values(), "squad %d/%d/%d" % [mode, trial, step])
				assert(w.rng.state == random.state, "random %d/%d/%d" % [mode, trial, step])
				assert(w.nav.cancelled == ([1] if expected else []))
				var stats := { ["melee", "rocket", "drone_launch"][mode]: 1 } if expected and mode < 3 else {}
				assert(w.stats == stats)
				var cue: int = result[2]
				var speech: Array = [] if cue < 0 else [[1, ["Rocket out! Backblast clear!", "RPG!", "Drone up.", "Target's out of range!", "Rounds out!", "Firing for effect!", "Hang it!"][cue]]]
				assert(w.spoken == speech, "speech %d/%d/%d" % [mode, trial, step])
				if step == 3:
					assert(actors.restore(actors.checkpoint()) and qcore.restore(qcore.checkpoint()))
			w.free()
	for mode in 4:
		for result in [true, false]: assert(seen.has("%d/%s" % [mode, result]))
	print("INFANTRY_SPECIAL passed states=", checks)
	get_tree().quit()
