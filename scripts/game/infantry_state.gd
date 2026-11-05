class_name InfantryState extends RefCounted
## Import complete gameplay state once; renderer snapshots use the smaller observation format.

const GOALS := ["", "slot", "cover", "task", "prison", "crawl"]
const HIDDEN := ["", "tunnel_wait", "vehicle", "tent", "tunnel_travel", "interrogation", "held"]

static func entity_id(e) -> int:
	return e.eid if is_instance_valid(e) and e is Entity else 0

static func entity_ids(entities: Array) -> PackedInt64Array:
	var ids := PackedInt64Array()
	for e in entities:
		var eid := entity_id(e)
		if eid != 0:
			ids.append(eid)
	return ids

static func opening(value: Array) -> Array:
	if value.is_empty():
		return []
	return [entity_id(value[0]), value[1], value[2], value[3]]

static func weapon_key(weapon: Dictionary) -> String:
	if weapon.is_empty():
		return ""
	for key: String in Defs.WEAPONS:
		if Defs.WEAPONS[key] == weapon:
			return key
	assert(false, "Infantry weapon must belong to the versioned definitions")
	return ""

static func action(s: Soldier) -> Array:
	var state := s._action_values()
	var kind: int = state[0]
	var raw: Array = state[2]
	# Old action dictionaries can retain unused keys; only the pending operation is state.
	state[2] = [raw[0] if kind in [2, 4, 5, 7, 8, 9, 10] else 0,
		raw[1] if kind in [1, 2, 3, 5, 11] else Vector3.ZERO,
		raw[2] if kind in [1, 11] else 0,
		raw[3] if kind in [1, 3] else 3.4,
		raw[4] if kind == 4 else Vector3.ZERO]
	if not state[3].is_empty():
		var queued: Array = state[3]
		state[3] = [0, queued[1], queued[2], queued[3], Vector3.ZERO]
	return state

static func capture(s: Soldier) -> Array:
	var breach := []
	if not s.bt_breach.is_empty():
		breach = [entity_id(s.bt_breach[0]), opening(s.bt_breach[1]), entity_id(s.bt_breach[2])]
	return [
		[s.eid, s.team, s.owner_peer, s.gone, s.vis_mask, s.seen_mask, s.utype, s.sname, s.sid,
			weapon_key(s.wdef), weapon_key(s.gun_override), s.hit_by.duplicate()],
		[s._vitals_state(), [s._motion_values(), s.path, entity_id(s.door_st)], s._weapon_state(),
			s._arsenal_state(), [s.frags, s.grenade_cd], PackedFloat64Array([s.scav_t, s.resupply_t]),
			[HIDDEN.find(s.hidden_reason), s.hidden_t, s._sim_prev], s._idle_values(), s._controller_values(),
			s._shock_state(), [entity_id(s.los_ent), s.los_t, s.los_ok], PackedInt64Array(s.seen_grenades.keys()),
			PackedInt64Array(s.heard_drones.keys()), action(s)],
		[s._path_pending, s._path_revision, s.goal, GOALS.find(s.goal_kind), s.move_mode, s.base_y,
			s.backwards, s.hold_pos, s.hold_face, s.leash, s.detached],
		[s.cover_type, s.cover_pos, s.at_cover, s.lean_dir, s.cover_threat, s.next_cover_eval,
			s.cover_n, s.cover_h, s.cover_mat, entity_id(s.cover_st), s.cover_ai, s._shifting],
		[s._controller_task(), entity_id(s.task_ent), entity_id(s.task_ent2), s.task_phase, s.task_t,
			s.task_pos, s.task_pos2, s.is_front, int(s.throw_kind == "smoke")],
		[entity_id(s.riding), entity_id(s.dragged_by), entity_id(s.rescue_claimed), entity_ids(s.carried_by),
			s.stretcher_claimed, entity_id(s.captor), entity_id(s.hidden_in), s.tent_dead, entity_id(s.home),
			entity_id(s.prison_dest), s.intel_left, s.intel_t],
		[s.bt_clear, s.bt_nofrag, breach, entity_id(s.bt_house), opening(s.bt_door), s.bt_next_breach,
			s.bt_cook_t0, entity_id(s.bt_breach_g), s.bt_wait, s.bt_reordered],
		[entity_id(s.mounted), entity_id(s._mount_target), s._mount_scan_t,
			PackedVector3Array() if s._pit_aim == Vector3.INF else PackedVector3Array([s._pit_aim]),
			1 if s._pit_kind == "smoke" else 2, s._pit_delay],
		[entity_id(s.target), entity_id(s.forced_target), entity_ids(s.vis_targets), s.cf_until, s.cf_pos,
			s.fteam, s.out_said, entity_id(s.drone_ctrl), s._sector, s._sep, s._shuffle, entity_id(s.bt_g),
			s._fire_flee_t, s.build_snd_t, s.loot, s.smokes],
		[s.posture, s.act, s.flags, s.doing, s.doing_ent, s._hit_dir, s._hit_kind],
	]
