extends "res://tests/fixtures/infantry-special.gd"

class QuietRound extends Projectile:
	func _ready() -> void: pass

class QuietDrone extends Drone:
	func _ready() -> void: pass

func _ready() -> void:
	MapDims.N = 32
	MapDims.SIZE = 32.0
	MapDims.HALF = 16.0
	MapDims.BIOME = 32
	Nav.N = 32
	Nav.H = 16.0
	HNav.C = 16
	HNav.NC = 2
	HNav.NCC = 4
	HNav._corner = HNav._corners()
	TerrainMap.N = 32
	TerrainMap.H = 16.0
	TerrainMap.DN = 64
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var projectile: RefCounted = ClassDB.instantiate("ProjectileActorCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var qcore: RefCounted = ClassDB.instantiate("SquadStateCore")
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/projectile-actor.gd").new()
	var cues := ["GRENADE!", "Grenade! Get down!", "Frag!", "GRENADE! Get back!", "Get down! I've got it!", "Get away from it!", "Incoming!", "INCOMING!", "Mortars! Get down!", "Drone! Drone!", "I hear a drone!", "FPV inbound!"]
	var seen := {}
	checks = 0
	for mode in 5:
		for trial in 128:
			var w: World = ground_world()
			var nav := SpecialRoutes.new()
			nav._planner = w.nav._planner
			w.nav = nav
			w.settings = {"rust_infantry": false}
			w.combat = ScanCombat.new(w)
			w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
			w.rng.seed = 12893 + trial
			random.seed = 12893 + trial
			var q := Squad.new()
			q.world = w
			q.sid = 9
			var mount := Mount.new()
			mount.world = w
			mount.eid = 20
			mount.skind = "watchtower"
			mount.position = Vector3(0.7, 0, 0)
			w.add_child(mount)
			w.entities[20] = mount
			if trial % 5 == 0: collider(w.combat._collision, 20, Vector3(0.7, 1, 0), Vector3(0.1, 2, 2))
			for id in range(1, 4):
				var s := make_soldier(w, id, 0)
				s.position = Vector3.ZERO if id == 1 else Vector3(0, 0, (id - 2) * 0.4)
				s.squad = q if trial % 11 else null
				s.sid = 9 if s.squad else 0
				s.wdef = Defs.WEAPONS.rifle if trial % 7 else {}
				s.life = Soldier.Life.DOWNED if id == 2 else Soldier.Life.ALIVE
				s.posture = (trial + id) % 3
				s.suppression = [0.0, 74.99, 75.0, 79.99, 80.0][trial % 5]
				s.say_cd = 7.0 if trial % 3 else 0.0
				s.path = PackedVector3Array([Vector3(12, 0, 0)])
				s.at_cover = true
				s.peek_up = true
				s.blind = true
				for past in range(80, 80 + trial % 27): s.seen_grenades[past] = true
				for past in range(80, 80 + trial % 18): s.heard_drones[past] = true
				w.soldiers.append(s)
				q.members.append(s)
			var s: Soldier = w.entities[1]
			s.task = ["rescue", "breach", "man", "pilot", "stretcher", ""][trial % 6]
			s.task_ent = w.entities[2]
			s.task_ent2 = w.entities[3]
			s.backwards = true
			s.base_y = 4.25 if s.task == "man" else 0.0
			s.mounted = mount if s.task == "man" else null
			w.entities[2].dragged_by = s
			w.entities[2].rescue_claimed = s
			q.breach_by = s
			w.entities[3].task = "grenade_pickup" if trial % 3 == 0 else ""
			for id in range(10, 13):
				var p := QuietRound.new()
				p.world = w
				p.eid = id
				p.ptype = "mortar" if mode in [2, 3] else "frag"
				p.position = Vector3([0.0, 1.0, 1.2, 2.0, 3.2, 3.8, 7.5, 7.5001][(trial + id) % 8], [0.0, 0.45, 0.7, 0.71][trial % 4], 0)
				p.target = Vector3([0.0, 4.49, 4.5, 7.99, 8.0, 14.0, 14.01][(trial + id) % 7], 0, 0)
				p.fuse = [0.49, 0.5, 1.0, 1.01, 1.8, 1.81, 2.2, 2.6, 2.61][(trial + id) % 9]
				p.shell_t = 3.0
				p.life_t = [1.39, 1.4, 1.41, 3.01][(trial + id) % 4]
				p.flying = trial % 2 == 0
				p.thrown_back = trial % 2
				p.handler = w.entities[3] if trial % 5 == 0 else null
				p.smothered_by = w.entities[2] if trial % 13 == 0 else null
				p.held_by = s if trial % 17 == 0 else null
				w.add_child(p)
				w.entities[id] = p
				w.projectiles.append(p)
			for id in range(30, 33):
				var d := QuietDrone.new()
				d.world = w
				d.eid = id
				d.team = (trial + id) % 3 - 1
				d.position = Vector3([0.0, 4.0, 8.99, 9.0, 44.99, 45.0, 45.01][(trial + id) % 7], 0.0 if trial % 3 else 20.0, 0)
				d.target_pos = Vector3([0.0, 5.49, 5.5][trial % 3], 0, 0)
				d.diving = trial % 2 == 0
				d.dead = (trial + id) % 7 == 0
				w.add_child(d)
				w.entities[id] = d
				w.drones.append(d)
			var kinds := PackedByteArray()
			var blocks := []
			for e: Entity in w.entities.values():
				if e is Soldier:
					kinds.append(0)
					blocks.append(soldier_bytes(e))
				elif e is Structure:
					kinds.append(1)
					assert(structure.load_state(StructureState.capture(e)))
					blocks.append(structure.checkpoint())
				elif e is Projectile:
					kinds.append(3)
					helper.start(e, projectile)
					blocks.append(projectile.checkpoint())
				else:
					kinds.append(4)
					var flight: RefCounted = ClassDB.instantiate("DroneFlightCore")
					assert(flight.reset(e.position, e.rotation.y))
					var bytes: PackedByteArray = flight.checkpoint()
					bytes[8] = e.phase
					bytes[9] = int(e.diving)
					bytes[10] = int(e.dead)
					bytes.encode_float(35, e.target_pos.x)
					bytes.encode_float(39, e.target_pos.y)
					bytes.encode_float(43, e.target_pos.z)
					blocks.append(actors.drone_checkpoint(PackedInt64Array([e.eid, e.team, 0, 0, 0, 0]), e.warhead, bytes))
			assert(actors.load_state(100, kinds, blocks))
			assert(qcore.load_state(SquadState.capture(q)))
			assert(units.load_state(12.0, []) and units.rebuild_units(actors))
			w._rebuild_uhash()
			for step in 6:
				s = w.entities[1 if step % 2 == 0 else 3]
				w.time = 10.0 + step * 0.11
				w.spoken.clear()
				w.stats.clear()
				w.nav.cancelled.clear()
				var expected := false
				var leaf := 0
				match mode:
					0:
						expected = SoldierBrain.grenade_close(s)
						if expected:
							if SoldierBrain.can_smother(s):
								SoldierBrain.smother(s)
								leaf = 1
							elif SoldierBrain.can_throw_back(s):
								SoldierBrain.throw_back(s)
								leaf = 2
							elif SoldierBrain.can_kick(s):
								SoldierBrain.kick(s)
								leaf = 3
							elif SoldierBrain.wall_between(s):
								SoldierBrain.duck(s)
								leaf = 4
							else:
								SoldierBrain.dive_clear(s)
								leaf = 5
					1:
						expected = s._react_grenade()
						leaf = 5 if expected else 0
					2, 3:
						expected = s._react_shells(mode == 3)
						leaf = 6 if expected else 0
					4:
						s._react_drones()
						expected = s.dive_t > 0.0
						leaf = 7 if expected else 0
				var result: Array = actors.react_infantry(s.eid, mode, w.time, not s.wdef.is_empty(), qcore if s.squad else null, units, w.nav._planner, w.combat._collision, random._backend)
				assert(result.size() == 5 and result[0] == expected and result[2] == leaf, "reaction %d/%d/%d: %s / %s,%s" % [mode, trial, step, result, expected, leaf])
				seen[leaf] = true
				for other: Soldier in w.soldiers:
					compare_actor(other, actors, "%d/%d/%d/%d" % [mode, trial, step, other.eid])
					checks += 1
				for p: Projectile in w.projectiles:
					helper.start(p, projectile)
					assert(projectile.checkpoint() == actors.actor_state(p.eid), "round %d/%d/%d" % [mode, trial, step])
				assert(SquadState.capture(q) == qcore.values())
				assert(w.rng.state == random.state, "random %d/%d/%d" % [mode, trial, step])
				assert(w.nav.cancelled == ([s.eid] if result[1] else []))
				var spoken := []
				for cue: int in result[3]: spoken.append([s.eid, cues[cue]])
				assert(w.spoken == spoken)
				var stats := {}
				for key: String in result[4]: stats[key] = stats.get(key, 0) + 1
				assert(w.stats == stats)
				if step == 2: assert(actors.restore(actors.checkpoint()) and qcore.restore(qcore.checkpoint()))
			w.free()
	helper.free()
	for leaf in 8: assert(seen.has(leaf), "uncovered leaf %d" % leaf)
	print("INFANTRY_REFLEX passed states=", checks)
	get_tree().quit()
