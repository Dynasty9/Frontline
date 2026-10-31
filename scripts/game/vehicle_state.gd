class_name VehicleState extends RefCounted
## Import vehicle gameplay state; model, suspension and network interpolation caches stay in Godot.

static func optional_point(p: Vector3) -> PackedVector3Array:
	return PackedVector3Array() if p == Vector3.INF else PackedVector3Array([p])

static func optional_scalar(v: float) -> PackedFloat64Array:
	return PackedFloat64Array() if v == INF or v == -INF else PackedFloat64Array([v])

static func capture(v: Vehicle) -> Array:
	var cooldowns := []
	for key: String in v.bt_cd:
		cooldowns.append([key, float(v.bt_cd[key])])
	var resume := []
	if not v.brain_resume.is_empty():
		resume = [optional_point(v.brain_resume.dest), bool(v.brain_resume.assault), optional_point(v.brain_resume.assault_dest)]
	var flight := PackedFloat64Array()
	if v.flight != null:
		flight = PackedFloat64Array([v.flight.pitch, v.flight.roll, v.flight.yaw_rate])
	return [
		PackedInt64Array([v.eid, v._aim_target, InfantryState.entity_id(v.target), InfantryState.entity_id(v.forced_target), InfantryState.entity_id(v.dest_fob), InfantryState.entity_id(v.src_town), InfantryState.entity_id(v.heli_home), InfantryState.entity_id(v.heli_dest), InfantryState.entity_id(v.sling_cargo), InfantryState.entity_id(v.sling_target), InfantryState.entity_id(v.slung_by), v.team, v.owner_peer, v.vis_mask, v.seen_mask, v._path_revision, v.path_i, v.route_i, v.mg_burst, v.flags, v.smoke_left, v.cargo, v.heli_phase, v.atgm_left, v.sam_left, v._salvo, v.lift_phase, v._tries]),
		[v.vkind, v.brain_state],
		PackedFloat64Array([v.hp, v.max_hp, v.rotation.y, v.turret_yaw, v._traverse, v._stabilization_rate, v._aim_time, v.speed, v.track_fix, v.cannon_t, v.mg_t, v.scan_t, v.smash_t, v.last_fire_t, v._alert_t, v.smoke_cd, v.blocked_t, v._stuck_t, v._stuck_yaw, v._unstick_t, v._unstick_dir, v._dis_t, v.heli_t, v.flight_pitch, v.flight_roll, v.atgm_t, v.sam_t, v.arty_t, v._salvo_t, v._svc_t, v.lift_t, v._orbit, v._sling_t, v.brain_t, v.yaw_rate, v._sway, v._throttle, v._rudder, v._current_t, v._about, v._rejoin_t, v._astern_t, v.gs_orbit, v.rocket_t]),
		PackedByteArray([int(v.gone), int(v.track_broken), int(v.path_pending), int(v.returning), int(v.assault), int(v.brain_hold), int(v.brain_overruled), int(v._brain_order), int(v._rev), int(v._landing), int(v._grounded), int(v._astern), int(v._astern_stop)]),
		PackedVector3Array([v.position, v.velocity, v.knock_v, v._stuck_p, v._swing, v._current, v._astern_from]),
		[optional_point(v.path_destination), optional_point(v.assault_dest), optional_point(v._flight_hold), optional_point(v._salvo_at), optional_point(v.lift_dest), optional_point(v.uav_dest), optional_point(v.gs_dest), optional_point(v._tries_for)],
		[optional_scalar(v._lay_yaw), optional_scalar(v.face_yaw), optional_scalar(v._tries_t), optional_scalar(v._avoid_cap)],
		[v.path, v.route, PackedVector3Array(v.fire_queue), InfantryState.entity_ids(v.passengers)],
		cooldowns, resume, v._last_blast.duplicate(), flight, v.hit_by.duplicate(),
	]
