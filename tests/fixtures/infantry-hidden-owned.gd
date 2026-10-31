extends "res://tests/fixtures/infantry-special.gd"

class HiddenWorld extends Scene:
	var messages := []
	func send_msg(team_id: int, kind: String, text: String, ping = null) -> void:
		messages.append([team_id, kind, text, ping])

func _ready() -> void:
	MapDims.N = 64
	MapDims.SIZE = 64.0
	MapDims.HALF = 32.0
	MapDims.BIOME = 64
	Defs.MAP_HALF = 32.0
	Nav.N = 64
	Nav.H = 32.0
	HNav.C = 16
	HNav.NC = 4
	HNav.NCC = 16
	HNav._corner = HNav._corners()
	TerrainMap.N = 64
	TerrainMap.H = 32.0
	TerrainMap.DN = 128
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var infantry: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var random := SimulationRandom.new()
	var helper := preload("res://tests/fixtures/infantry-update.gd").new()
	var seen := {}
	checks = 0
	for reason: String in ["", "tunnel_wait", "vehicle", "tent", "tunnel_travel", "interrogation", "held"]:
		for trial in 128:
			var w := HiddenWorld.new()
			w.has_view = false
			w.srv = true
			w.settings = {"rust_infantry": false}
			w.nav = SpecialRoutes.new()
			w.nav._planner = ClassDB.instantiate("PathPlannerCore")
			assert(w.nav._planner.configure(Nav.N))
			w.rules = Rules.new(w)
			add_child(w)
			w.rng.seed = 99371 + trial
			random.seed = 99371 + trial
			var q := Squad.new()
			q.world = w
			q.sid = 9
			q._centroid_t = 3.0
			w.squads[q.sid] = q
			var qcore: SquadStateCore = ClassDB.instantiate("SquadStateCore")
			var cores: Array[SquadStateCore] = [qcore]
			var s := make_soldier(w, 1, 0)
			var other := make_soldier(w, 2, 0)
			s.squad = q
			s.sid = q.sid
			q.members = [s]
			w.soldiers = [s, other]
			s.position = Vector3(trial % 7, -0.4, 3)
			s.wdef = {} if trial % 3 == 0 else Defs.WEAPONS.rifle
			s.life = Soldier.Life.HIDDEN
			s.hidden_reason = reason
			s.hidden_t = [-1.0, 0.0, 0.1, 0.2, 0.35, 1.0][trial % 6]
			s.task_pos = Vector3(-11, 0, 4)
			s.times_downed = trial % 5
			s.dragged_by = other
			s.rescue_claimed = other
			s.carried_by = [other]
			s.stretcher_claimed = true
			var shelter := Mount.new()
			shelter.world = w
			shelter.eid = 10
			shelter.skind = "medic_tent" if reason == "tent" else "tunnel"
			shelter.position = Vector3(5, 0, 0)
			shelter.rotation.y = [0.0, 1.3, -2.5][trial % 3]
			shelter.gone = trial % 7 == 0
			shelter.inside = [s, other]
			w.add_child(shelter)
			w.entities[10] = shelter
			s.hidden_in = shelter
			var v := Carrier.new()
			v.world = w
			v.eid = 20
			v.position = Vector3(10, 14, 3)
			v.gone = trial % 3 == 0
			w.add_child(v)
			w.entities[20] = v
			s.riding = v
			if trial % 5 != 0:
				for id in range(30, 33):
					var base := Mount.new()
					base.world = w
					base.eid = id
					base.skind = "fob"
					base.team = 0
					base.position = Vector3((id - 29) * 12, 0, 0)
					base.wrecked = id == 30 and trial % 2 == 0
					base.built = id != 31 or trial % 3 != 0
					w.add_child(base)
					w.entities[id] = base
					w.fob_structures.append(base)
			var blocks := []
			var kinds := PackedByteArray()
			for e: Entity in w.entities.values():
				if e.gone: continue
				if e is Soldier: blocks.append(soldier_bytes(e)); kinds.append(0)
				elif e is Structure:
					assert(structure.load_state(StructureState.capture(e)))
					blocks.append(structure.checkpoint()); kinds.append(1)
				else: blocks.append(vehicle_bytes(e, vehicle)); kinds.append(2)
			assert(actors.load_state(100, kinds, blocks) and qcore.load_state(SquadState.capture(q)))
			var retired := PackedByteArray()
			for step in 4:
				w.time = 10.0 + step * 0.1
				w.spoken.clear(); w.stats.clear(); w.effects.clear(); w.props.clear(); w.messages.clear(); w.nav.jobs.clear()
				var result := [[], PackedByteArray()]
				if not s.gone and s.life == Soldier.Life.HIDDEN:
					s._hidden(0.1)
					result = actors.advance_infantry_hidden(1, 0.1, "rifle", Defs.WEAPONS.rifle.mag, w.nav._planner, cores, random._backend)
				assert(result.size() == 2, "hidden %s/%d/%d" % [reason, trial, step])
				if not result[1].is_empty(): retired = result[1]
				assert(infantry.restore(retired if s.gone else actors.actor_state(1)))
				helper.check_state(s, infantry, "hidden %s/%d/%d" % [reason, trial, step]); checks += 1
				assert(qcore.values() == SquadState.capture(q), "hidden squad")
				assert(actors.actor_state(1).is_empty() == s.gone, "hidden removal")
				if not shelter.gone:
					assert(structure.restore(actors.actor_state(10)) and structure.values() == StructureState.capture(shelter), "hidden occupancy")
				var speech := []
				var stats := {}
				var jobs := []
				var props := []
				var messages := []
				for event: Array in result[0]:
					match int(event[0]):
						0: stats[event[1]] = stats.get(event[1], 0) + 1
						1:
							stats.revived = 1
							speech.append([1, ["Thanks, doc.", "I'm good, I'm good!", "Back in the fight.", "Ugh... let's go."][event[1]]])
							props.append([1, {"max_hp": s.max_hp}])
						2: jobs.append([1, event[3], false, 0, event[4]])
						3: messages.append([s.team, "info", "%s is patched up and limping back to base." % s.sname, null])
				assert(w.rng.state == random.state, "hidden random")
				assert(w.spoken == speech and w.stats == stats and w.props == props and w.messages == messages and w.effects.is_empty(), "hidden events %s/%d/%d" % [reason, trial, step])
				assert(w.nav.jobs.size() == jobs.size(), "hidden routes")
				for i in jobs.size(): assert(w.nav.jobs[i].slice(0, 5) == jobs[i])
				for key: String in stats: seen[key] = true
				if s.gone: seen.removed = true
				if step == 1: assert(actors.restore(actors.checkpoint()) and qcore.restore(qcore.checkpoint()))
			w.free()
	helper.free()
	for key in ["out_of_tent", "revived", "removed"]: assert(seen.has(key), "must exercise " + key)
	print("INFANTRY_HIDDEN_OWNED passed states=", checks)
	get_tree().quit()
