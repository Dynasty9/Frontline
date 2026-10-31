extends "res://tests/fixtures/infantry-reflex.gd"

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
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/projectile-actor.gd").new()
	var seen := {}
	checks = 0
	for mode in 3:
		for trial in 128:
			var w: World = ground_world()
			var nav := SpecialRoutes.new()
			nav._planner = w.nav._planner
			w.nav = nav
			w.settings = {"rust_infantry": false}
			w.combat = ScanCombat.new(w)
			w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
			w.rng.seed = 31253 + trial
			random.seed = 31253 + trial
			for id in range(1, 4):
				var s := make_soldier(w, id, 0 if id < 3 else 1)
				s.position = Vector3.ZERO if id == 1 else Vector3((id - 1) * 2.0, 0, 1.3)
				s.rotation.y = [-1.7, 0.0, 1.3][trial % 3]
				s.life = Soldier.Life.DOWNED if id == 2 and trial % 3 == 0 else Soldier.Life.ALIVE
				s.posture = trial % 3
				s.path = PackedVector3Array([Vector3(12, 0, 0)])
				s.act = Soldier.Act.HEAL
				s.at_cover = true
				s.peek_up = true
				s.blind = true
				w.soldiers.append(s)
			var mount := Mount.new()
			mount.world = w
			mount.eid = 20
			mount.skind = ["watchtower", "mortar_pit", "at_post"][trial % 3]
			mount.position = Vector3.ZERO
			w.add_child(mount)
			w.entities[20] = mount
			var p := QuietRound.new()
			p.world = w
			p.eid = 10
			p.ptype = "frag"
			p.position = Vector3([0.0, 0.69, 0.7, 0.89, 0.9, 3.1][trial % 6], 0.05, (trial % 3) * 0.2)
			p.fuse = [0.349, 0.35, 0.699, 0.7, 1.9][trial % 5]
			p.flying = trial % 2 == 0
			p.vel = Vector3(1, 2, 3)
			p.thrower_id = 3 if trial % 3 else 2
			p.handler = w.entities[1]
			p.held_by = w.entities[2] if trial % 7 == 0 else (w.entities[1] if trial % 11 == 0 else null)
			p.gone = trial % 13 == 0
			w.add_child(p)
			w.entities[10] = p
			var s: Soldier = w.entities[1]
			s.task = ["smother", "gkick", "grenade_pickup"][mode]
			s.task_ent = p if trial % 17 else null
			s.task_t = 10.0
			s.mounted = mount if trial % 4 == 0 else null
			if trial % 5 == 0:
				var cell: Vector2i = w.nav.cell_of(Vector3(1, 0, 0))
				w.nav.ikind[cell.y * Nav.N + cell.x] = Nav.SOLID
				assert(w.nav._planner.load_cells(w.nav.ikind, w.nav.vkind, w.nav.heat))
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
				elif not e.gone:
					kinds.append(3)
					helper.start(e, projectile)
					blocks.append(projectile.checkpoint())
			assert(actors.load_state(100, kinds, blocks))
			assert(units.load_state(12.0, []) and units.rebuild_units(actors))
			w._rebuild_uhash()
			var dt: float = [1.0/30.0, 0.1, 0.3][trial % 3]
			for step in 20:
				w.time = 10.0 + step * dt
				w.stats.clear()
				w.nav.cancelled.clear()
				if s.task in ["smother", "gkick", "grenade_pickup"]:
					match mode:
						0: SoldierBrain.smother_tick(s, dt)
						1: SoldierBrain.gkick_tick(s, dt)
						2: s._gpick_tick(dt)
					var result: Array = actors.advance_infantry_grenade_task(1, dt, w.time, PackedFloat64Array(), units, w.nav._planner, random._backend)
					assert(result.size() == 2)
					assert(w.nav.cancelled == ([1] if result[0] else []))
					assert(w.stats == ({"dive": 1} if result[1] else {}))
					seen["%d/%s/%d" % [mode, s.task, s.act]] = true
				for other: Soldier in w.soldiers:
					compare_actor(other, actors, "%d/%d/%d/%d" % [mode, trial, step, other.eid])
					checks += 1
				if not p.gone:
					helper.start(p, projectile)
					assert(projectile.checkpoint() == actors.actor_state(10), "round %d/%d/%d" % [mode, trial, step])
				assert(w.rng.state == random.state)
				if step == 9: assert(actors.restore(actors.checkpoint()))
			w.free()
	helper.free()
	assert(seen.has("0/smother/34") and seen.has("1//33") and seen.has("2//21"))
	print("INFANTRY_GRENADE_OWNED passed states=", checks)
	get_tree().quit()
