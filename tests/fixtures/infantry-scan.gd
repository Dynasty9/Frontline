extends "res://tests/fixtures/vehicle-scan.gd"

class ContactSquad extends Squad:
	func report(e: Entity) -> void:
		world.reports.append([sid, e.eid])
		super.report(e)

func infantry_profile(s: Soldier) -> PackedFloat64Array:
	var weapon: Dictionary = s.cur_weapon()
	return PackedFloat64Array([int(s.is_bearer()), weapon.get("range", 50.0), int(weapon.get("ap", false))])

func _ready() -> void:
	MapDims.N = 128
	MapDims.SIZE = 128.0
	MapDims.HALF = 64.0
	MapDims.BIOME = 128
	Nav.N = 128
	Nav.H = 64.0
	HNav.C = 16
	HNav.NC = 8
	TerrainMap.N = 128
	TerrainMap.H = 64.0
	TerrainMap.DN = 256
	var layout := RandomNumberGenerator.new()
	layout.seed = 37193
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var search: RefCounted = ClassDB.instantiate("PerceptionSearch")
	var kinds := Defs.VEHICLES.keys()
	var infantry := Defs.UNITS.keys()
	checks = 0
	var observed := {}
	for trial in 48:
		var w := ScanWorld.new()
		w.has_view = false
		w.srv = true
		w.settings = {"rust_infantry": false, "gdscript_targeting": true}
		w.terrain = TerrainMap.new(w)
		w.perception = ClassDB.instantiate("PerceptionSearch")
		w.combat = ScanCombat.new(w)
		w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
		w.combat._visibility = ClassDB.instantiate("VisibilityCore")
		var visibility: RefCounted = ClassDB.instantiate("VisibilityCore")
		add_child(w)
		for i in Nav.N * Nav.N:
			w.terrain.woods[i] = int(i % 11 < 3)
			w.terrain.netted[i] = int(i % 13 < 4)
		assert(w.terrain._native.configure(Nav.N, [w.terrain.base, w.terrain.crater, w.terrain.rubble, w.terrain.woods, w.terrain.cov, w.terrain.cdir, w.terrain.solid, w.terrain.trench, w.terrain.netted], w.terrain.dh))
		var squads := []
		for i in 4:
			var sq := ContactSquad.new()
			sq.world = w
			sq.sid = 90 + i
			sq.team = i % 2
			squads.append(sq)
		for id in range(1, 25):
			var s := make_soldier(w, id, id % 2)
			s.utype = infantry[(id + trial) % infantry.size()]
			s.udef = Defs.UNITS[s.utype]
			s.wdef = Defs.WEAPONS.get(s.udef.weapon, {})
			s.position = Vector3(layout.randf_range(-60, 60), -0.3, layout.randf_range(-60, 60))
			s.life = Soldier.Life.ALIVE if id % 7 else Soldier.Life.DOWNED
			s.last_shot_t = 19.0 if id % 3 == 0 else -10.0
			s.posture = (trial + id) % 5
			s.rockets = id % 3
			s.at_cover = id % 3 != 0
			s.cover_type = id % 3
			s.cover_h = [0.0, 0.5, 0.8, 1.3][id % 4]
			s.cover_n = Vector3.FORWARD
			s.lean_dir = Vector3.LEFT
			s.peek_up = trial % 2 == 0
			s.blind = trial % 5 == 0
			s.squad = squads[id % 4]
			s.sid = s.squad.sid
			if id % 6 == 0: s.path = PackedVector3Array([s.position + Vector3.LEFT * 10])
			if id % 8 == 0: s._path_pending = true
			w.soldiers.append(s)
		var aircraft := PackedInt64Array()
		var armor := PackedInt64Array()
		for id in range(25, 33):
			var v := Carrier.new()
			v.world = w
			v.srv = true
			v.eid = id
			v.team = id % 2
			v.vkind = kinds[(trial * 3 + id) % kinds.size()]
			v.vdef = Defs.VEHICLES[v.vkind]
			v.hp = v.vdef.hp
			v.max_hp = v.vdef.hp
			v.position = Vector3(layout.randf_range(-60, 60), 14.0 if v.is_heli() else 0.0, layout.randf_range(-60, 60))
			v.rotation.y = layout.randf_range(-PI, PI)
			v.body = StaticBody3D.new()
			v.add_child(v.body)
			w.combat._rid_entities[v.body.get_rid()] = id
			w.add_child(v)
			w.vehicles.append(v)
			w.entities[id] = v
			if v.is_heli(): aircraft.append(id)
			armor.append(id)
			armor.append(v.vdef.get("armor", 1))
			collider(w.combat._collision, id, v.position + Vector3.UP, Vector3(1.3, 1.0, 2.7))
		for id in range(33, 36):
			var st := Mount.new()
			st.world = w
			st.eid = id
			st.team = id % 2
			st.skind = ["watchtower", "mg_nest", "hmg_nest"][id - 33]
			st.position = Vector3((id - 34) * 20, 0, -25)
			st.yaw = trial * 0.17
			st.radius = 3.0
			st.built = true
			st.variant = trial % 2
			w.add_child(st)
			w.entities[id] = st
			w.structures.append(st)
		for id in range(36, 39):
			var d := Drone.new()
			d.eid = id
			d.world = w
			d.team = id % 2
			d.position = Vector3((id - 37) * 15, 6, -10)
			d.phase = 0
			d.diving = trial % 2 == 0
			d.dead = trial % 7 == 0
			w.add_child(d)
			w.entities[id] = d
			w.drones.append(d)
		for s in w.soldiers:
			if s.eid % 4 == 0:
				s.mounted = w.entities[33 + s.eid % 3]
				s.task = "man"
				s.task_phase = 2
			if s.eid % 11 == 0: s.forced_target = w.entities[33]
			elif s.eid % 5 == 0: s.forced_target = w.entities[36]
			s.target = w.entities[25 + s.eid % 8]
		var blocks := []
		var types := PackedByteArray()
		for e: Entity in w.entities.values():
			if e is Vehicle:
				blocks.append(vehicle_bytes(e, vehicle))
				types.append(2)
			elif e is Soldier:
				blocks.append(soldier_bytes(e))
				types.append(0)
			elif e is Drone:
				blocks.append(drone_bytes(e, actors))
				types.append(4)
			else:
				assert(structure.load_state(StructureState.capture(e)))
				blocks.append(structure.checkpoint())
				types.append(1)
		assert(actors.load_state(100, types, blocks))
		for step in 16:
			w.time = 20.0 + step * 0.4
			if step % 4 == 0:
				w._rebuild_uhash()
				assert(search.rebuild_actors(actors, w.terrain._native, w.time, aircraft))
				collider(w.combat._collision, 99, Vector3(step * 1.7 - 10.0, 2, -10), Vector3(13, 4, 0.5))
			var smoke := PackedFloat64Array([0, 2, -8, 8 if step % 3 == 0 else 0])
			assert(w.combat._visibility.set_fires(smoke))
			assert(visibility.set_fires(smoke))
			for s in w.soldiers:
				w.reports.clear()
				w.stats.clear()
				s._scan_work()
				var result: Array = actors.scan_infantry(s.eid, w.time, infantry_profile(s), search, w.combat._collision, visibility, armor)
				assert(result.size() == 4)
				assert(result[0] == InfantryState.entity_id(s.target), "Target %d/%d/%d: %s vs %s" % [trial, step, s.eid, result, s.target])
				assert(result[3] == InfantryState.entity_ids(s.vis_targets), "Contacts %d/%d/%d" % [trial, step, s.eid])
				var reports := []
				for i in result[1]: reports.append([s.squad.sid, result[3][i]])
				assert(reports == w.reports, "Reports %d/%d/%d" % [trial, step, s.eid])
				assert(result[2] == w.stats.get("perception_blocked_reused", 0))
				compare_actor(s, actors, "scan %d/%d/%d" % [trial, step, s.eid])
				checks += 1
				if result[2] > 0: observed["cached"] = true
				if s.is_bearer(): observed["bearer"] = true
				if s.target is Drone: observed["drone"] = true
				if s.target is Structure: observed["building"] = true
				if s.target is Soldier: observed["soldier"] = true
				if s.target is Vehicle: observed["vehicle"] = true
				if s.mounted: observed["mounted"] = true
			if step == 7:
				var saved: PackedByteArray = actors.checkpoint()
				assert(actors.restore(saved) and actors.checkpoint() == saved)
		w.free()
	for key in ["cached", "bearer", "drone", "building", "soldier", "vehicle", "mounted"]:
		assert(observed.has(key), "Fixture must exercise " + key)
	print("INFANTRY_SCAN passed states=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
