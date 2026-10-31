class_name StructureState extends RefCounted
## Import building state and collision parts; scene objects and drawing caches stay in Godot.

static func capture(s: Structure) -> Array:
	var parts := []
	for p: Dictionary in s.parts:
		parts.append([p.p, p.s, float(p.r), int(p.nav), int(p.veh), bool(p.cover), bool(p.col), bool(p.get("door", false))])
	var cells: Array[Vector2i] = []
	for cell: Vector2i in s.hash_cells:
		cells.append(cell)
	var queue := []
	for q: Dictionary in s.queue:
		queue.append([String(q.item), float(q.t), float(q.total), int(q.owner), int(q.cost)])
	var rounds := []
	for round: Array in s.fire_queue:
		rounds.append([round[0], String(round[1]) == "smoke"])
	var optional := []
	for p: Vector3 in [s.zone_c, s.rally, s.hit_from]:
		optional.append(PackedVector3Array([p]) if p.is_finite() else PackedVector3Array())
	return [
		PackedInt64Array([s.eid, s.team, s.owner_peer, s.vis_mask, s.seen_mask, s.variant, s.cap_team, s.completed_order, InfantryState.entity_id(s.supply_parent), InfantryState.entity_id(s.truck), s.houses0, InfantryState.entity_id(s.gunner)]),
		[s.skind, s.sname, s.supply_status, s.prod_status, s.vk, s.fire_k],
		PackedFloat64Array([s.yaw, s.progress, s.hp, s.max_hp, s.radius, s.supply, s.cap_prog, s.truck_t, s._alert_t, s.zone_r, s.intact, s._house_t, s.queue_frac, s.bearer_t, s._tick_t, s.burn, s.fuel, s.fuel_max]),
		PackedByteArray([int(s.gone), int(s.built), int(s.smashable), int(s.indestructible), int(s.wrecked), int(s.manned), int(s.door_shut), int(s.burnt)]),
		[s.position, s.size, s.foot, s.tilt, parts, s.cover_pts, s.anc_p, s.anc_n, s.anc_h, s.anc_k, PackedInt32Array(s.nav_cells), cells, s.road],
		optional, queue, [InfantryState.entity_ids(s.inside), InfantryState.entity_ids(s.bearers)], rounds, s.hit_by.duplicate(),
	]
