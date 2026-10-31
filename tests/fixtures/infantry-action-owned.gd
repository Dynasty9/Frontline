extends "res://tests/fixtures/infantry-reflex.gd"

class ActionWorld extends ActorWorld:
	var spawn_id := 100
	var spawned := []
	func spawn(kind: String, data: Dictionary) -> Entity:
		var e: Entity = QuietDrone.new() if kind == "drone" else QuietRound.new()
		e.world = self
		e.srv = true
		e.eid = spawn_id
		spawn_id += 1
		e.apply_props(data)
		entities[e.eid] = e
		add_child(e)
		spawned.append(e)
		if e is Drone: e.on_spawned()
		elif e.ptype == "rocket": e._warn_target()
		return e

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
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/projectile-actor.gd").new()
	var launch_helper := preload("res://tests/fixtures/vehicle-launch.gd").new()
	var seen := {}
	checks = 0
	for mode in 12:
		for trial in 64:
			var w := ActionWorld.new()
			w.srv = true
			w.has_view = false
			w.settings = {"rust_infantry": false}
			w.nav = SpecialRoutes.new()
			w.nav._planner = ClassDB.instantiate("PathPlannerCore")
			assert(w.nav._planner.configure(Nav.N))
			w.terrain = TerrainMap.new(w)
			w.combat = Combat.new(w)
			w.battle = BattleStats.new(w)
			w.rules = Rules.new(w)
			add_child(w)
			w.rng.seed = 43853 + trial
			random.seed = 43853 + trial
			var qs := []
			var cores: Array[SquadStateCore] = []
			for team in 2:
				var q := Squad.new()
				q.world = w
				q.sid = 9 + team
				q.team = team
				q.morale = 75.0
				qs.append(q)
				w.squads[q.sid] = q
				cores.append(ClassDB.instantiate("SquadStateCore"))
			var stocks := PackedInt64Array()
			for id in [1, 7, 8]:
				var s := make_soldier(w, id, 0 if id == 1 else 1)
				s.position = Vector3.ZERO if id == 1 else Vector3(([1.0, 2.4, 2.401][trial % 3] if mode == 8 else 15.0) + (id - 7) * 2.0, 0, 0)
				s.squad = qs[s.team]
				s.sid = s.squad.sid
				s.squad.members.append(s)
				s.posture = trial % 5
				s.rotation.y = [0.0, 1.3, -2.5][trial % 3]
				s.hp = [1.0, 45.0, 100.0][trial % 3] if id == 7 else 100.0
				s.times_downed = trial % 3 if id == 7 else 0
				s.say_cd = 5.0 if trial % 2 else 0.0
				s.path = PackedVector3Array([Vector3(12, 0, 12)])
				w.soldiers.append(s)
				stocks.append_array(PackedInt64Array([id, s.wdef.ammo, int(s.is_bearer())]))
			var s: Soldier = w.entities[1]
			qs[0].known[7] = {"e": w.entities[7], "pos": Vector3(20, 0, 10), "t": 5.0}
			var v := Carrier.new()
			v.world = w
			v.srv = true
			v.eid = 10
			v.team = 1
			v.vkind = ["tank", "ifv", "blackfoot", "technical"][trial % 4]
			v.vdef = Defs.VEHICLES[v.vkind]
			v.position = Vector3(35, trial % 7 if v.is_heli() else 0, 0)
			v.velocity = Vector3(1.3, 0, -0.7)
			v.smoke_left = 2
			v.smoke_cd = 20.0 if trial % 7 == 0 else 0.0
			v.brain_state = "withdraw" if trial % 3 == 0 else ""
			v.owner_peer = -2
			w.add_child(v)
			w.entities[10] = v
			w.vehicles.append(v)
			var defenses := [[10, v.base(), PackedByteArray([int(v.is_heli()), int(v.is_auto()), int(v.vdef.has("art")), int(v.is_tracked())]), int(v.vdef.get("armor", 0)), v.vdef.get("gun_h", 2.0)]]
			var st := Mount.new()
			st.world = w
			st.srv = true
			st.eid = 20
			st.skind = "house_wall"
			st.position = Vector3(10, 0, 0)
			st.door_shut = trial % 2 == 0
			w.add_child(st)
			w.entities[20] = st
			var p := QuietRound.new()
			p.world = w
			p.srv = true
			p.eid = 30
			p.ptype = "frag"
			p.position = Vector3([0.7, 1.4, 1.401][trial % 3], 0.05, 0)
			p.held_by = s if mode in [5, 6] else (w.entities[7] if trial % 5 == 0 else null)
			p.thrower_id = [7, 1, 99][trial % 3]
			p.fuse = 1.1
			p.handler = s
			w.add_child(p)
			w.entities[30] = p
			s.act_kind = ["cook", "throw", "throw", "throw_in", "kick", "pickup", "rethrow", "door_kick", "melee", "launch", "mortar", "launch_drone"][mode]
			s.act_t = 0.1 if trial % 7 == 0 else 0.0
			match mode:
				0: s.act_data = {}
				1, 2, 3: s.act_data = {"pos": Vector3(20.7, 0.06, -3.2), "kind": "smoke" if mode == 2 else "frag", "fuse": 1.2}
				4: s.act_data = {"g": p, "v": Vector3(8.1, 3, -0.4)}
				5: s.act_data = {"g": p}
				6: s.act_data = {"g": p, "pos": Vector3(20.7, 0.06, -3.2)}
				7: s.act_data = {"door": st, "pos": st.position}
				8, 11: s.act_data = {"target": w.entities[7]}
				9: s.act_data = {"target": v}
				10: s.act_data = {"pos": Vector3(20.7, 0.06, -3.2), "kind": "smoke" if trial % 2 == 0 else "he"}
			if mode == 0 and trial % 3 != 0: s._queued_throw = {"pos": Vector3(19, 0, 0), "kind": "frag", "fuse": 1.8}
			var blocks := []
			var kinds := PackedByteArray()
			for e: Entity in w.entities.values():
				if e is Soldier: kinds.append(0); blocks.append(soldier_bytes(e))
				elif e is Vehicle:
					kinds.append(2); assert(vehicle.load_state(VehicleState.capture(e))); blocks.append(vehicle.checkpoint())
				elif e is Structure:
					kinds.append(1); assert(structure.load_state(StructureState.capture(e))); blocks.append(structure.checkpoint())
				else:
					kinds.append(3); helper.start(e, projectile); blocks.append(projectile.checkpoint())
			assert(actors.load_state(100, kinds, blocks))
			for i in 2: assert(cores[i].load_state(SquadState.capture(qs[i])))
			assert(units.load_state(12.0, []) and units.rebuild_units(actors))
			w._rebuild_uhash()
			for step in 4:
				w.time = 10.0 + step
				w.spoken.clear(); w.stats.clear(); w.effects.clear(); w.nav.jobs.clear(); w.nav.cancelled.clear(); w.spawned.clear()
				s._action_tick(0.0)
				if s.act_t <= 0.0: s._action_done()
				var result: Array = actors.complete_infantry_action(1, w.time, 1.0, stocks, defenses, cores, units, w.nav._planner, random._backend)
				assert(result.size() == 4, "action %d/%d/%d" % [mode, trial, step])
				for other: Soldier in w.soldiers:
					compare_actor(other, actors, "action %d/%d/%d/%d" % [mode, trial, step, other.eid]); checks += 1
				for i in 2: assert(cores[i].values() == SquadState.capture(qs[i]), "action squad")
				assert(vehicle.restore(actors.actor_state(10)))
				compare_vehicle(v, vehicle, "action vehicle %d/%d/%d" % [mode, trial, step])
				assert(structure.restore(actors.actor_state(20)) and structure.values() == StructureState.capture(st))
				launch_helper.compare_projectile(p, actors, helper)
				var spawn_ids := []
				var effects := []
				var stats := {}
				var spoken := []
				if result[2] >= 0: spoken.append([1, ["Frag out!", "Grenade out!", "Fire in the hole!", "Throwing it back!"][result[2]]])
				for key: String in result[1]: stats[key] = stats.get(key, 0) + 1
				for event: Array in result[0]:
					match int(event[0]):
						0: spawn_ids.append(event[1])
						1: effects.append([Fx.LAUNCH, event[1], event[2], 1])
						2: effects.append([Fx.MORTAR, event[1]])
						3: effects.append([Fx.SOUND, "door_kick", st.position + Vector3.UP])
						4:
							var victim: Soldier = w.entities[event[1]]
							var hit: Array = event[3]
							if hit[2] >= 0: spoken.append([victim.eid, ["I'm hit!", "Argh!", "Took one!", "Hit! I'm hit!"][hit[2]]])
							if hit[3] != 0: spoken.append([hit[3], ["Man down!", "%s is hit!" % victim.sname, "We've got wounded!", "Medic! %s is down!" % victim.sname][hit[4]]])
							if hit[0] in [2, 3]: stats["downed" if hit[0] == 2 else "killed"] = 1
							effects.append([Fx.MELEE, event[2]])
						5: effects.append([Fx.SOUND, "launch", v.position])
				assert(spawn_ids == Array(InfantryState.entity_ids(w.spawned)))
				for e: Entity in w.spawned:
					if e is Projectile: launch_helper.compare_projectile(e, actors, helper)
					else: assert(drone_bytes(e, actors) == actors.actor_state(e.eid))
				assert(actors.next_id() == w.spawn_id)
				assert(w.rng.state == random.state, "action random %d/%d/%d" % [mode, trial, step])
				assert(w.spoken == spoken, "action speech %d/%d/%d: %s / %s" % [mode, trial, step, w.spoken, spoken])
				assert(w.stats == stats, "action stats %d/%d/%d: %s / %s" % [mode, trial, step, w.stats, stats])
				# Damage has its own hit/death effects; compare action-only events here.
				if mode != 8: assert(w.effects == effects, "action effects %d/%d/%d: %s / %s" % [mode, trial, step, w.effects, effects])
				if not spawn_ids.is_empty(): seen[s.act_kind if not s.act_kind.is_empty() else str(mode)] = true
				for key: String in stats: seen[key] = true
				if step == 1:
					assert(actors.restore(actors.checkpoint()))
					for core in cores: assert(core.restore(core.checkpoint()))
			w.free()
	helper.free(); launch_helper.free()
	for key in ["kicked", "throwback", "door_kicked", "veh_smoke", "veh_evade", "mortar_round"]: assert(seen.has(key), "must exercise " + key)
	print("INFANTRY_ACTION_OWNED passed states=", checks)
	get_tree().quit()
