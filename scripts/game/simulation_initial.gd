class_name SimulationInitial
extends RefCounted
## Transfer a generated battlefield before its first tick. Rust owns every later change.

static func header(magic: String, version := 1) -> PackedByteArray:
	var data := magic.to_utf8_buffer()
	data.append_array(PackedByteArray([version, 0, 2, 0]))
	return data

static func block(data: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(4)
	result.encode_u32(0, data.size())
	result.append_array(data)
	return result

static func spatial(grid: Dictionary, size: float) -> PackedByteArray:
	var index: RefCounted = ClassDB.instantiate("SpatialIndexCore")
	var cells := []
	for key: Vector2i in grid:
		if not grid[key].is_empty():
			cells.append([key, InfantryState.entity_ids(grid[key])])
	if not index.load_state(size, cells):
		return PackedByteArray()
	return index.checkpoint()

static func navigation(nav: Nav) -> PackedByteArray:
	var data := header("FLNS", 2)
	for state: PackedByteArray in [nav._planner.checkpoint(), nav.hnav_i._core.checkpoint(), nav.hnav_v._core.checkpoint(), nav.hnav_t._core.checkpoint()]:
		data.append_array(block(state))
	data.append(nav._hier_next)
	return data

static func geometry(w: World) -> PackedByteArray:
	var data := header("FLWG")
	for state: PackedByteArray in [w.terrain._native.checkpoint(), navigation(w.nav), w.combat._collision.checkpoint(), spatial(w._shash, 16.0), spatial(w.door_cells, 1.5)]:
		if state.is_empty():
			return PackedByteArray()
		data.append_array(block(state))
	data.append_array(block(w.water.deck))
	var retired := StreamPeerBuffer.new()
	retired.put_u32(w.combat._collision_retired.size())
	for id: int in w.combat._collision_retired:
		retired.put_u32(id)
	data.append_array(retired.data_array)
	return data

static func plain(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[String(key)] = plain(value[key])
		return result
	if value is Array or value is PackedVector3Array or value is PackedVector2Array or value is PackedStringArray:
		var result := []
		for item: Variant in value:
			result.append(plain(item))
		return result
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is Color:
		return [value.r, value.g, value.b, value.a]
	return value

static func text(out: StreamPeerBuffer, value: String) -> void:
	out.put_data(block(value.to_utf8_buffer()))

static func counters(out: StreamPeerBuffer, values: Dictionary) -> void:
	for key: String in BattleStats.FIELDS:
		out.put_double(float(values[key]))

static func ledger(b: BattleStats) -> PackedByteArray:
	var out := StreamPeerBuffer.new()
	out.put_data(header("FLBS"))
	out.put_u32(b.players.size())
	for id: int in b.players:
		out.put_32(id)
		text(out, String(b.players[id].name))
	out.put_u32(b.players.size())
	for id: int in b.players:
		var p: Dictionary = b.players[id]
		out.put_32(id)
		out.put_8(int(p.team))
		out.put_u8(int(p.ai))
		text(out, String(p.name))
		counters(out, p)
	for side: Dictionary in b.sides:
		counters(out, side)
	out.put_u32(b.units.size())
	for key: String in b.units:
		var u: Dictionary = b.units[key]
		for value: String in [key, String(u.name), String(u.kind)]:
			text(out, value)
		out.put_8(int(u.team))
		out.put_32(int(u.owner))
		out.put_double(float(u.t0))
		out.put_double(float(u.t1))
		for field: String in ["men", "alive", "kills", "downs", "veh_kills", "lost"]:
			out.put_u32(int(u[field]))
	out.put_u32(b.heroes.size())
	for id: int in b.heroes:
		var h: Dictionary = b.heroes[id]
		out.put_u32(id)
		for field: String in ["name", "role", "unit"]:
			text(out, String(h[field]))
		out.put_8(int(h.team))
		out.put_32(int(h.owner))
		out.put_u32(int(h.kills))
		out.put_u32(int(h.veh))
		out.put_u8(int(h.alive))
	out.put_u32(b.timeline.size())
	for row: Array in b.timeline:
		for value: Variant in row:
			out.put_double(float(value))
	out.put_u32(b.events.size())
	for event: Array in b.events:
		out.put_double(float(event[0]))
		out.put_8(int(event[1]))
		text(out, String(event[2]))
		text(out, String(event[3]))
	out.put_double(b.every)
	out.put_double(b._sample_t)
	out.put_u8(0) # No damage callback can be in progress before the first tick.
	return out.data_array

static func capture(w: World) -> PackedByteArray:
	if w.time != 0.0 or w.mission != null or not w.commanders.is_empty() or not w.projectiles.is_empty() or not w.drones.is_empty() or not w.fires.burning.is_empty() or not w.fires.patches.is_empty() or not w.rules._support_q.is_empty():
		push_error("Initial simulation export must precede all simulation and mission updates")
		return PackedByteArray()
	w._rebuild_uhash()
	w.combat._sync_collision()
	var actors: RefCounted = ClassDB.instantiate("ActorStateCore")
	var soldier: RefCounted = ClassDB.instantiate("InfantryStateCore")
	var vehicle: RefCounted = ClassDB.instantiate("VehicleStateCore")
	var structure: RefCounted = ClassDB.instantiate("StructureStateCore")
	var kinds := PackedByteArray()
	var blocks := []
	for e: Entity in w.entities.values():
		var core: RefCounted
		var values: Array
		if e is Soldier:
			core = soldier
			values = InfantryState.capture(e)
			kinds.append(0)
		elif e is Vehicle:
			core = vehicle
			values = VehicleState.capture(e)
			kinds.append(2)
		elif e is Structure:
			core = structure
			values = StructureState.capture(e)
			kinds.append(1)
		else:
			return PackedByteArray()
		if not core.load_state(values):
			push_error("Cannot export entity %d (%s)" % [e.eid, e.get_class()])
			return PackedByteArray()
		blocks.append(core.checkpoint())
	if not actors.load_state(w.next_eid, kinds, blocks):
		return PackedByteArray()
	var network: RefCounted = ClassDB.instantiate("SupplyNetworkCore")
	if not network.load_state(InfantryState.entity_ids(w.rules.depots), InfantryState.entity_ids(w.rules.town_list), w.rules.fob_order, w.roads, w._painted_roads):
		return PackedByteArray()
	var water: RefCounted = ClassDB.instantiate("WaterRaster")
	if not water.configure(MapDims.N, w.water.to_dict()):
		return PackedByteArray()
	var peers := []
	for id: int in w.settings.get("players", {}):
		var p: Dictionary = w.settings.players[id]
		peers.append([id, int(p.team), String(p.get("name", "Player %d" % id))])
	var meta := {"host": w.local_peer, "players": peers, "ai": w.settings.get("ai_teams", []),
		"mission": String(w.settings.get("mission", "")), "autoplay": bool(w.settings.get("mission_autoplay", false)),
		"scenario": String(w.settings.get("scenario", "")) != "", "wet": w.fires.wet,
		"town": [w.town_rect.position.x, w.town_rect.position.y, w.town_rect.size.x, w.town_rect.size.y],
		"landmarks": w.key_points, "upgrades": [w.rules.upgrades[0].keys(), w.rules.upgrades[1].keys()],
		"support": [SquadState.pairs(w.rules.support_ready[0]), SquadState.pairs(w.rules.support_ready[1])],
		"fob_names": w.rules.fob_names_used,
		"presentation": {"decor": w.decor, "mood": Atmosphere.pick_mood(w.settings)}}
	var out := StreamPeerBuffer.new()
	out.put_data(header("FLIN"))
	out.put_data(block(FileAccess.get_file_as_bytes("res://native/content.json")))
	out.put_data(block(JSON.stringify(plain(meta), "", true, true).to_utf8_buffer()))
	out.put_u64(w.rng.seed)
	out.put_u64(w.rng.state)
	out.put_u64(w.next_sid)
	for data: PackedByteArray in [geometry(w), actors.checkpoint(), network.checkpoint(), ledger(w.battle), water.checkpoint()]:
		if data.is_empty():
			return PackedByteArray()
		out.put_data(block(data))
	out.put_u32(w.squads.size())
	var squad: RefCounted = ClassDB.instantiate("SquadStateCore")
	for q: Squad in w.squads.values():
		if q.plan != null or q.ambush_plan != null or not squad.load_state(SquadState.capture(q)):
			push_error("Cannot export an active attack plan as an initial deployment")
			return PackedByteArray()
		out.put_data(block(squad.checkpoint()))
	return out.data_array

static func save(w: World, path: String) -> Error:
	var data := capture(w)
	if data.is_empty():
		return ERR_INVALID_DATA
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(data)
	return file.get_error()
