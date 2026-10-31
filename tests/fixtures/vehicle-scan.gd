extends "res://tests/fixtures/vehicle-sling.gd"

class ScanWorld extends ActorWorld:
	var reports := []

class ReportingSquad extends Squad:
	func report(e: Entity) -> void:
		world.reports.append(sid)
		super.report(e)

class ScanCombat extends Combat:
	func _sync_collision() -> void:
		pass
	func ray(from: Vector3, to: Vector3, ex: Array = []) -> Dictionary:
		var ids := PackedInt64Array()
		for rid: RID in ex:
			if _rid_entities.has(rid): ids.append(_rid_entities[rid])
		var hit: PackedFloat64Array = _collision.ray(from, to, ids)
		return {} if hit.is_empty() else {"collider": world.entities.get(int(hit[0]))}
	func ent_of(col) -> Entity:
		return col

func scan_profile(v: Vehicle) -> PackedFloat64Array:
	return PackedFloat64Array([v.vdef.get("sight", 50.0), v.vdef.get("gun_h", 0.8 if v.base() == "attack_heli" else 2.2),
		int(v.vdef.cannon), int(v.base() == "attack_heli"), int(v.vdef.get("aa", false)), int(Defs.WEAPONS.get(String(v.vdef.mg), {}).get("ap", false))])

func collider(collision: RefCounted, id: int, p: Vector3, half: Vector3) -> void:
	assert(collision.replace_body(id, PackedFloat32Array([p.x, p.y, p.z, 1, 0, 0, 0, 1, 0, 0, 0, 1, half.x, half.y, half.z, 0])))

func _ready() -> void:
	var layout := RandomNumberGenerator.new()
	layout.seed = 37193
	var kinds := Defs.VEHICLES.keys()
	var buildings := PackedStringArray(Defs.BUILDINGS.keys())
	buildings.append("depot")
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var units: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var structures: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	checks = 0
	var observed := {}
	for trial in 264:
		var w := ScanWorld.new()
		w.has_view = false
		w.srv = true
		w.settings = {"rust_infantry": false}
		w.combat = ScanCombat.new(w)
		w.combat._collision = ClassDB.instantiate("CollisionIndexCore")
		w.combat._visibility = ClassDB.instantiate("VisibilityCore")
		var visibility: RefCounted = ClassDB.instantiate("VisibilityCore")
		add_child(w)
		assert(units.load_state(12.0, []))
		assert(structures.load_state(16.0, []))
		var squads := []
		for i in 3:
			var sq := ReportingSquad.new()
			sq.world = w
			sq.sid = 90 + i
			sq.team = 1
			squads.append(sq)
		var mode := trial % 12
		for id in range(1, 10):
			var v := Carrier.new()
			v.world = w
			v.srv = true
			v.eid = id
			v.team = 0 if id == 1 or mode >= 8 else ((id % 3) - 1)
			v.vkind = kinds[(trial + id - 1) % kinds.size()]
			v.vdef = Defs.VEHICLES[v.vkind].duplicate()
			v.hp = v.vdef.hp
			v.max_hp = v.vdef.hp
			v.position = Vector3(layout.randf_range(-65, 65), 14.0 if v.is_heli() else 0.0, layout.randf_range(-65, 65))
			v.rotation.y = layout.randf_range(-PI, PI)
			v.sam_left = trial % 3
			if id == 1:
				v.position = Vector3(0, 14 if v.is_heli() else 0, 0)
				if mode >= 8: v.vdef.cannon = true
			v.body = StaticBody3D.new()
			v.add_child(v.body)
			w.combat._rid_entities[v.body.get_rid()] = id
			w.add_child(v)
			w.vehicles.append(v)
			w.entities[id] = v
			if mode < 8: collider(w.combat._collision, id, v.position + Vector3.UP, Vector3(1.3, 1.0, 2.7))
		for id in range(10, 26):
			var s := make_soldier(w, id, 0 if mode >= 8 else id % 3 - 1)
			s.position = Vector3(layout.randf_range(-65, 65), -0.3, layout.randf_range(-65, 65))
			s.life = (trial + id) % 6
			s.posture = (trial + id) % 5
			s.rockets = id % 2
			s.at_cover = id % 3 != 0
			s.cover_type = id % 3
			s.cover_h = [0.0, 0.5, 0.8, 1.3][id % 4]
			s.cover_n = Vector3.FORWARD
			s.lean_dir = Vector3.LEFT
			s.peek_up = trial % 2 == 0
			s.blind = trial % 5 == 0
			s.squad = squads[id % 3]
			s.sid = s.squad.sid
			w.soldiers.append(s)
		for id in range(26, 32):
			var st := Mount.new()
			st.world = w
			st.eid = id
			st.team = 1
			st.skind = ["depot", "trench", "wire", "mg_nest", "hmg_nest", "floor"][id - 26]
			st.position = Vector3((id - 28) * 7, 0, -25)
			st.radius = 3.0
			st.size = Vector3(4, 2, 4)
			st.built = true
			st.variant = trial % 2
			st.vis_mask = 0 if mode == 10 else 1
			w.add_child(st)
			w.entities[id] = st
			w.structures.append(st)
			w._shash_add(st)
			assert(structures.insert(id, st.position, st.radius))
			collider(w.combat._collision, id, st.position + Vector3.UP, Vector3(2, 1, 2))
		for id in [13, 17, 21]: w.entities[id].mounted = w.entities[29 if trial % 2 else 30]
		var v: Vehicle = w.entities[1]
		v.target = w.entities[10 + trial % 16] if trial % 3 == 0 else null
		if mode == 11:
			v.forced_target = w.entities[11]
			v.forced_target.position = Vector3(74.99 if trial % 2 else 75.0, 0, 0)
		var blocks := []
		var types := PackedByteArray()
		var aircraft := PackedInt64Array()
		for e: Entity in w.entities.values():
			if e is Vehicle:
				blocks.append(vehicle_bytes(e, vehicle))
				types.append(2)
				if e.is_heli(): aircraft.append(e.eid)
			elif e is Soldier:
				blocks.append(soldier_bytes(e))
				types.append(0)
			else:
				assert(structure.load_state(StructureState.capture(e)))
				blocks.append(structure.checkpoint())
				types.append(1)
		assert(actors.load_state(100, types, blocks))
		w._rebuild_uhash()
		assert(units.rebuild_units(actors))
		for step in 16:
			w.time = step * 0.4
			w.reports.clear()
			w.stats.clear()
			if step % 4 == 0:
				collider(w.combat._collision, 99, Vector3(step * 1.7 - 10.0, 2, -10), Vector3(13, 4, 0.5))
			var smoke := PackedFloat64Array([0, 2, -8, 8 if step % 3 == 0 else 0])
			assert(w.combat._visibility.set_fires(smoke))
			assert(visibility.set_fires(smoke))
			v._scan()
			var result: Array = actors.scan_vehicle(1, scan_profile(v), units, structures, w.combat._collision, visibility, aircraft, buildings)
			assert(result.size() == 3)
			assert(result[0] == InfantryState.entity_id(v.target), "Target %d/%d: %s vs %s" % [trial, step, result, v.target])
			assert(result[1] == PackedInt64Array(w.reports), "Reports %d/%d" % [trial, step])
			assert(result[2] == w.stats.get("perception_blocked_reused", 0), "Obstruction reuse %d/%d" % [trial, step])
			compare_owned(v, actors, vehicle, "scan %d/%d" % [trial, step])
			if result[2] > 0: observed["cached"] = true
			if not w.reports.is_empty(): observed["reported"] = true
			if v.target is Soldier: observed["soldier"] = true
			if v.target is Vehicle: observed["air" if v.target.is_air() else "vehicle"] = true
			if v.target is Structure: observed["building"] = true
			if v.target == v.forced_target and v.target != null: observed["forced"] = true
			if v.target == null: observed["none"] = true
			if step == 7:
				var saved: PackedByteArray = actors.checkpoint()
				assert(actors.restore(saved) and actors.checkpoint() == saved)
		w.free()
	for key in ["cached", "reported", "soldier", "vehicle", "air", "building", "forced", "none"]:
		assert(observed.has(key), "Fixture must exercise " + key)
	print("VEHICLE_SCAN passed states=%d outcomes=%s" % [checks, observed])
	get_tree().quit()
