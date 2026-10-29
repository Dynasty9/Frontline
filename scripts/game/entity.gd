class_name Entity
extends Node3D
## Base for everything the server replicates. The server simulates in sim();
## clients receive props on spawn and compact state in snapshots.

var world: World
var eid := 0
var team := -1:
	set(value):
		team = value
		if world != null and self is Structure:
			world.refresh_owned_structure(self)
var owner_peer := 0
var hp := 100.0
var max_hp := 100.0
var srv := false
var gone := false
var vis_mask := 0
var seen_mask := 0
var net_dirty := true:
	set(value):
		net_dirty = value
		if value and world != null and self is Structure:
			world.mark_static_dirty(self)
var resend_t := 0.0
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var net_init := false
var selected := false
var hit_by: Array = []  # (server) the last enemy to hurt it: [owner, team, unit, soldier eid] (see BattleStats)


func _ready() -> void:
	if srv and (self is Structure or self is Vehicle):
		set_notify_transform(true)
		set_notify_local_transform(true)
	# Entity frame callbacks only draw; authority advances them through sim().
	if world != null and not world.has_view:
		set_process(false)


func _notification(what: int) -> void:
	if (what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED) and srv and world != null and world.combat:
		world.combat.dirty_collision(eid)


func ekind() -> String:
	return ""


func apply_props(_d: Dictionary) -> void:
	pass


func get_props() -> Dictionary:
	return {}


func on_spawned() -> void:
	pass


func on_despawn() -> void:
	pass


func sim(_dt: float) -> void:
	pass


func write_state(_b: StreamPeerBuffer) -> void:
	pass


func read_state(_b: StreamPeerBuffer) -> void:
	pass


func is_static() -> bool:
	return false


func get_exclude() -> Array:
	return []


func exposed_points() -> Array:
	return [position + Vector3(0, 1.0, 0)]


func center_point() -> Vector3:
	return position + Vector3(0, 1.0, 0)


func hit_factor() -> float:
	return 1.0


func is_hostile_to(t: int) -> bool:
	return team >= 0 and t >= 0 and team != t


func display_name() -> String:
	return ekind()


## True if the local player's team can currently see this entity (fog of war).
func seen_by_local() -> bool:
	var lt := world.view_team
	if lt < 0 or team < 0 or team == lt:
		return true
	return ((vis_mask >> lt) & 1) == 1


func visible_to_team(t: int) -> bool:
	if team == t or team < 0:
		return true
	return ((vis_mask >> t) & 1) == 1


# --- smooth motion on the host -------------------------------------------------------
# The simulation steps 30 times a second; drawn as it is, anything moving
# would jump in 30 Hz steps at 100+ fps. The host draws each unit between its
# last two simulated transforms instead (clients smooth the network stream).
var _ip_a := Transform3D.IDENTITY
var _ip_b := Transform3D.IDENTITY
var _ip_moving := false


func ip_capture() -> void:
	_ip_a = _ip_b
	_ip_b = transform
	if _ip_a.origin.distance_squared_to(_ip_b.origin) > 16.0:
		_ip_a = _ip_b  # a jump (spawn, teleport): no blur across it
	_ip_moving = not _ip_a.is_equal_approx(_ip_b)


## The offset that puts a child model where the unit "is" this frame.
func ip_offset() -> Transform3D:
	if not _ip_moving:
		return Transform3D.IDENTITY
	var g := _ip_a.interpolate_with(_ip_b, Engine.get_physics_interpolation_fraction())
	return transform.affine_inverse() * g


func net_smooth(dt: float, blend := -1.0) -> void:
	if not net_init:
		return
	if blend < 0.0:
		blend = 1.0 - exp(-dt * 14.0)
	var next_pos := net_pos if position.distance_to(net_pos) > 8.0 else position.lerp(net_pos, blend)
	var next_rotation := rotation
	next_rotation.y = lerp_angle(rotation.y, net_yaw, blend)
	# Unchanged transforms still dirty every child model in the scene tree.
	if next_pos != position:
		position = next_pos
	if next_rotation != rotation:
		rotation = next_rotation


static func put_v3(b: StreamPeerBuffer, p: Vector3) -> void:
	b.put_float(p.x)
	b.put_float(p.y)
	b.put_float(p.z)


static func get_v3(b: StreamPeerBuffer) -> Vector3:
	var x := b.get_float()
	var y := b.get_float()
	var z := b.get_float()
	return Vector3(x, y, z)


static func put_ang(b: StreamPeerBuffer, a: float) -> void:
	b.put_u16(int(wrapf(a, 0.0, TAU) / TAU * 65535.0) & 0xFFFF)


static func get_ang(b: StreamPeerBuffer) -> float:
	return float(b.get_u16()) / 65535.0 * TAU
