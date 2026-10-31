extends "res://tests/fixtures/infantry-reflex.gd"

const CUES := [
	["GRENADE!", "Grenade! Get down!", "Frag!", "GRENADE! Get back!", "Get down! I've got it!", "Get away from it!", "Incoming!", "INCOMING!", "Mortars! Get down!", "Drone! Drone!", "I hear a drone!", "FPV inbound!"],
	["Grabbing ammo.", "Taking his mags.", "He won't need these."],
	["Reloading!", "Changing mag!", "Cover me, reloading!"],
	["Rocket out! Backblast clear!", "RPG!", "Drone up.", "Target's out of range!", "Rounds out!", "Firing for effect!", "Hang it!"],
	["Cooking one!", "Two... three...", "Hold it, hold it..."],
	["Frag out!", "Grenade out!", "Fire in the hole!"],
	["They're in the house! Stacking on the door!", "Enemy inside! I'll frag the room!", "Cover me, grenade through the door!", "Got one in the building! Moving to the door!"],
	["Out of ammo!"],
	["Falling back for ammo!", "Back to the ammo cache!"]
]

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
	var projectile: RefCounted = ClassDB.instantiate("ProjectileActorCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var structures: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var qcore: RefCounted = ClassDB.instantiate("SquadStateCore")
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/projectile-actor.gd").new()
	var seen := {}
	checks = 0
	for mode in 9:
		for trial in 64:
			var w: World = ground_world()
			var nav := SpecialRoutes.new()
			nav._planner = w.nav._planner
			w.nav = nav
			w.fires = Fires.new(w)
			w.water = WaterMap.new(w)
			w.rules = Rules.new(w)
			w.settings = {"rust_infantry": false, "gdscript_cover_search": true}
			w.combat = ScanCombat.new(w)
			w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
			w.combat._visibility = ClassDB.instantiate("VisibilityCore")
			w.rng.seed = 41771 + trial
			random.seed = 41771 + trial
			var q := Squad.new()
			q.sid = 9
			q.world = w
			q.order = "defend" if trial % 2 else "move"
			q.ambush = trial % 17 == 0
			var bearers := PackedInt64Array()
			for id in range(1, 8):
				var s := make_soldier(w, id, 0 if id < 7 else 1)
				s.position = Vector3.ZERO if id == 1 else Vector3(-id * 2.0, 0, id * 0.5)
				s.squad = q if id < 7 and trial % 13 else null
				s.sid = 9 if s.squad else 0
				s.vis_mask = 3
				s.frags = 0
				if id == 1 and trial % 19 == 0:
					s.udef = Defs.UNITS.bearer
					s.utype = "bearer"
					s.wdef = {}
					bearers.append(id)
				if id == 7:
					s.position = Vector3([1.89, 1.9, 1.91][trial % 3] if mode == 2 else (80.0 if mode == 5 else 15.0), 0, 0)
					s.posture = trial % 3
					s.at_cover = trial % 2 == 0
					s.cover_mat = Cover.HARD
					q.known[7] = {"e": s, "pos": s.position, "t": 10.0}
				else: q.members.append(s)
				w.soldiers.append(s)
			if trial % 3 == 0: q.members.reverse()
			for id in range(20, 23):
				var st := Mount.new()
				st.world = w
				st.eid = id
				st.skind = ["floor", "house_wall", "ammo_cache"][id - 20]
				st.size = Vector3(8, 0.1, 8) if id == 20 else Vector3(0.3, 3, 8)
				st.position = Vector3(15 if id == 20 else (11 if id == 21 else -30), 0, 0)
				st.radius = 6.0
				st.variant = 1 + trial % 2
				st.yaw = PI * 0.5 if id == 21 else 0.0
				st.team = 0 if id == 22 else -1
				w.add_child(st)
				w.entities[id] = st
				w.structures.append(st)
				w._shash_add(st)
			var v := Carrier.new()
			v.world = w
			v.eid = 10
			v.team = 1
			v.vkind = "tank"
			v.vdef = Defs.VEHICLES.tank
			v.position = Vector3(50, 0, 12)
			v.vis_mask = 3
			w.add_child(v)
			w.entities[10] = v
			w.vehicles.append(v)
			var p := QuietRound.new()
			p.world = w
			p.eid = 30
			p.ptype = "mortar" if mode == 1 else "frag"
			p.position = Vector3([0.0, 2.0, 5.0][trial % 3], 0.1, 0)
			p.target = p.position
			p.fuse = [0.4, 0.7, 1.8, 2.5][trial % 4]
			p.flying = true
			p.shell_t = 3.0
			p.life_t = 2.5
			w.add_child(p)
			if mode <= 1:
				w.entities[30] = p
				w.projectiles.append(p)
			var s: Soldier = w.entities[1]
			s.task = ["", "retreat", "rescue", "man", "pilot", "smother"][trial % 6] if mode <= 1 else ""
			s.task_phase = trial % 3
			s.frags = 4 if mode in [4, 8] else 0
			s.rockets = 4 if mode == 6 else 0
			s.drones_left = 4 if mode == 7 else 0
			s.mortar_rounds = 4 if mode == 5 else 0
			s.suppression = [0.0, 50.0, 50.01, 70.01][trial % 4]
			s.say_cd = 5.0 if trial % 2 else 0.0
			s.vis_targets = [v] if mode == 6 else ([w.entities[7]] if trial % 3 == 0 else [])
			s.bt_next_breach = 1000.0 if mode == 8 else 0.0
			s.next_cover_eval = 1000.0 if trial % 5 else 0.0
			s.hold_pos = Vector3(2, 0, -1)
			s.hold_face = Vector3.RIGHT
			if trial % 11 == 0 and not s.wdef.is_empty(): s.gun_override = Defs.WEAPONS.lmg
			s.mag = 0 if mode == 3 else 7
			s.reserve = 0 if mode == 3 else 23
			if mode == 3:
				w.entities[2].life = Soldier.Life.DEAD
				w.entities[2].loot = 71
				w.entities[2].position = Vector3([1.0, 10.0, 40.0][trial % 3], 0, 0)
			var kinds := PackedByteArray()
			var blocks := []
			for e: Entity in w.entities.values():
				if e is Soldier: kinds.append(0); blocks.append(soldier_bytes(e))
				elif e is Structure:
					kinds.append(1)
					assert(structure.load_state(StructureState.capture(e)))
					blocks.append(structure.checkpoint())
				elif e is Vehicle:
					kinds.append(2)
					assert(vehicle.load_state(VehicleState.capture(e)))
					blocks.append(vehicle.checkpoint())
				else:
					kinds.append(3)
					helper.start(e, projectile)
					blocks.append(projectile.checkpoint())
			assert(actors.load_state(100, kinds, blocks))
			assert(qcore.load_state(SquadState.capture(q)))
			assert(units.load_state(12.0, []) and units.rebuild_units(actors))
			w._rebuild_uhash()
			var cells := []
			for cell in w._shash: cells.append([cell, InfantryState.entity_ids(w._shash[cell])])
			assert(structures.load_state(16.0, cells))
			for step in 8:
				w.time = 10.0 + step * [0.1, 0.75, 3.1, 20.0][trial % 4]
				w.spoken.clear(); w.stats.clear(); w.nav.jobs.clear(); w.nav.cancelled.clear()
				var weapon := s.cur_weapon()
				var stock := PackedFloat64Array() if s.wdef.is_empty() else PackedFloat64Array([s.wdef.ammo, weapon.ammo, weapon.mag, weapon.reload])
				var input := [w.time, stock, PackedFloat64Array() if weapon.is_empty() else PackedFloat64Array([weapon.range, weapon.ammo]), s.is_bearer(), PackedInt64Array(), PackedInt64Array([10, v.vdef.armor]), bearers]
				SoldierBrain.think(s)
				var result: Array = actors.think_infantry(1, input, qcore if s.squad else null, w.fires.hot, w.water.deck, w.terrain._native, w.nav._planner, units, structures, w.combat._collision, w.combat._visibility, random._backend)
				assert(result.size() == 5, "decision %d/%d/%d" % [mode, trial, step])
				for other: Soldier in w.soldiers:
					compare_actor(other, actors, "decision %d/%d/%d/%d" % [mode, trial, step, other.eid])
					checks += 1
				if mode <= 1:
					helper.start(p, projectile)
					assert(projectile.checkpoint() == actors.actor_state(30), "shared grenade %d/%d/%d" % [mode, trial, step])
				assert(qcore.values() == SquadState.capture(q), "squad %d/%d/%d: %s / %s" % [mode, trial, step, SquadState.capture(q), qcore.values()])
				assert(random.state == w.rng.state, "random %d/%d/%d" % [mode, trial, step])
				var spoken := []
				for cue: Array in result[0]: spoken.append([1, CUES[cue[0]][cue[1]]])
				assert(spoken == w.spoken, "speech %d/%d/%d: %s / %s" % [mode, trial, step, w.spoken, spoken])
				var stats := {}
				for key: String in result[1]: stats[key] = stats.get(key, 0) + 1
				assert(stats == w.stats, "stats %d/%d/%d: %s / %s" % [mode, trial, step, w.stats, stats])
				assert(w.nav.cancelled == ([1] if result[3] else []), "cancel %d/%d/%d" % [mode, trial, step])
				if not result[2].is_empty():
					assert(w.nav.jobs.size() == 1 and w.nav.jobs[0][1] == result[2][2] and w.nav.jobs[0][4] == result[2][3])
				else: assert(w.nav.jobs.is_empty())
				for key: String in stats: seen[key] = true
				if step == 3: assert(actors.restore(actors.checkpoint()) and qcore.restore(qcore.checkpoint()))
			w.free()
	helper.free()
	for key in ["dive", "melee", "scavenge", "resupply_body", "resupply_cache", "breach", "rocket", "drone_launch", "frag_auto", "frag_cooked"]: assert(seen.has(key), "must exercise " + key)
	print("INFANTRY_DECISION passed states=", checks)
	get_tree().quit()
