class_name SquadState extends RefCounted
## Import shared squad state once, including cached decisions and stable plan identities.

static func plan_id(plan, plans: Dictionary) -> int:
	if plan == null:
		return 0
	assert(plans.has(plan), "Every referenced plan must have a stable import identity")
	return int(plans[plan])

static func pairs(d: Dictionary) -> Array:
	var out := []
	for key in d:
		out.append([key, d[key]])
	return out

static func contacts(d: Dictionary) -> Array:
	var out := []
	for key in d:
		out.append([int(key), d[key].pos, float(d[key].t)])
	return out

static func capture(q: Squad, plans: Dictionary = {}) -> Array:
	var buildings := []
	for pair: Array in q._building_contacts:
		buildings.append([InfantryState.entity_id(pair[0]), InfantryState.entity_id(pair[1])])
	var rounds := []
	for round: Array in q.fire_queue:
		rounds.append([round[0], String(round[1]) == "smoke"])
	var cooldowns := []
	for key in q.bt_cd:
		cooldowns.append([String(key), float(q.bt_cd[key])])
	var clear := []
	if not q.bt_clear.is_empty():
		clear = [InfantryState.entity_id(q.bt_clear[0]), InfantryState.opening(q.bt_clear[1]), InfantryState.entity_id(q.bt_clear[2]), InfantryState.entity_id(q.bt_clear[3])]
	var call := []
	if not q.clear_call.is_empty():
		call = [InfantryState.entity_id(q.clear_call[0]), q.clear_call[1]]
	return [
		[q.sid, q.team, q.owner, q.kind, InfantryState.entity_ids(q.members), InfantryState.entity_id(q.leader), plan_id(q.plan, plans), plan_id(q.ambush_plan, plans), InfantryState.entity_id(q.build_target), InfantryState.entity_id(q.breach_by), q.order_n],
		[q.order, q.shown_order, q.drill, q.technique],
		PackedFloat64Array([q._combat_cache_t, q._centroid_t, q._briefing_t, q._buildings_t, q.cover_fire_until, q.think_t, q.bound_t, q.contact_t, q.alert_t, q.morale, q.drill_t, q.last_cas_t, q.displace_cd, q.ammo_t, q.ambush_t, q.ow_t, q.ow_rbf_t]),
		PackedVector3Array([q._centroid, q.order_pos, q.facing, q.cover_fire_pos, q.drill_pos, q.halt_dest, q.halt_face]),
		PackedInt32Array([int(q._combat_cache), int(q.travel), int(q.ambush), q.bound_team, q.travel_mode, q.halt_mode, q.move_mode_ord, q.ow_team]),
		[contacts(q.known), contacts(q.known_at_order), q.heard.duplicate(true), q.impacts.duplicate(true), PackedVector3Array(q._briefing), buildings],
		[pairs(q.smoked), pairs(q.cleared), pairs(q.final_slots), pairs(q._offsets), cooldowns],
		rounds,
		[PackedVector3Array([q.tunnel_exit_pos]) if q.tunnel_exit_pos.is_finite() else PackedVector3Array(), q.pre_order.duplicate(), PackedVector3Array(q.then_defend), PackedVector3Array(q.halt_then), clear, call],
	]
