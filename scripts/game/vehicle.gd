class_name Vehicle
extends Entity
## Tanks, technicals and supply trucks. Tanks smash through walls, small arms
## ricochet off their armour, and a blown track leaves them stranded.

const F_TRACK := 1
const F_FIRE := 2
const F_BLOCKED := 4
const F_ELEV := 8  # gun laid up for indirect fire / launcher raised
const F_GROUND := 16  # a helicopter sitting on the ground (rotor idling)

var vkind := "tank"
var vdef: Dictionary = {}
var turret_yaw := 0.0
var _traverse := 0.0
var _aim_time := 0.0
var _aim_target := 0
var speed := 0.0
var velocity := Vector3.ZERO
var track_broken := false
var track_fix := 0.0
var path := PackedVector3Array()
var path_i := 0
var _path_revision := 0
var path_pending := false
var path_destination := Vector3.INF
var target: Entity = null
var forced_target: Entity = null
var cannon_t := 2.0
var mg_t := 0.0
var mg_burst := 0
var scan_t := 0.0
var smash_t := 0.0
var body: StaticBody3D
var flags := 0
var hp_frac := 1.0
var last_fire_t := -9.0
var _alert_t := 0.0
var smoke_cd := 0.0
var smoke_left := 2  # salvoes in the dischargers
# trucks
var route := PackedVector3Array()
var route_i := 0
var dest_fob: Structure = null
var src_town: Structure = null  # a town's truck: the town it carries supply from (else it runs from HQ)
var cargo := 0  # what it's carrying
var returning := false
var blocked_t := 0.0
var _stuck_p := Vector3.ZERO
var _stuck_t := 0.0
var _stuck_yaw := 0.0
var _unstick_t := 0.0
var _unstick_dir := 1.0
var assault := false  # attack-move: halt to shoot whenever there's a target
var passengers: Array = []  # soldiers riding inside
var assault_dest := Vector3.INF
var _dis_t := 0.0
# helicopters
var heli_home: Structure = null
var heli_dest: Structure = null
var heli_phase := 0
var heli_t := 0.0
var rotor: Node3D
var flight: HelicopterFlight
var flight_pitch := 0.0
var flight_roll := 0.0
var _flight_hold := Vector3.INF

# view
# missiles: ATGMs at armour, SAMs at aircraft (counts refilled by ammo trucks)
var atgm_left := 0
var atgm_t := 0.0
var sam_left := 0
var sam_t := 0.0
# artillery: fire missions queued by the player, the salvo in progress
var fire_queue: Array = []
var arty_t := 4.0
var _salvo := 0
var _salvo_t := 0.0
var _salvo_at := Vector3.INF
var _lay_yaw := INF  # where the gun is laid (turret yaw), INF: on the target
var _svc_t := 0.0
# troop-carrying helicopters and drones: where they've been sent
var lift_dest := Vector3.INF
var lift_phase := 0  # 0 ground, 1 climb, 2 cruise, 3 land, 4 unload, 5/6 sling, 7 hold
var lift_t := 0.0
var uav_dest := Vector3.INF
var _orbit := 0.0
var _elev_v := 0.0  # (view) barrel / launcher elevation
var model: Node3D
var knock_v := Vector3.ZERO  # shoved by a blast: slides it across the ground (server)
var _last_blast: Array = []  # [pos, size, time] of the last explosion that hit it
# sling loads (see _sling_tick): a lift helicopter carrying a vehicle on a cable
var sling_cargo: Vehicle = null  # (heli) what's hanging under it
var sling_target: Vehicle = null  # (heli) what it's going to pick up
var slung_by: Vehicle = null  # (cargo) the helicopter carrying it
var sling_eid := 0  # (heli, replicated) the load's entity, for the cables
var _sling_t := 0.0
var _swing := Vector3.ZERO
# suspension (view): pitch, roll, heave and how fast each is changing
var _sus := Vector3.ZERO
var _sus_v := Vector3.ZERO
var _gun_kick := 0.0  # (view) how far the turret is jolted back by its own gun
var _turret_rest := Vector3.INF
var _vel_s := Vector3.ZERO
var _vel_prev := Vector3.ZERO
var turret: Node3D
var tail_rotor: Node3D
var blades: Node3D
var blur: MeshInstance3D
var wheels: Array = []
var _last_pos := Vector3.ZERO
var _rotor_spd := 0.0
var burner: Node3D
var dust: GeometryInstance3D  # (GPU or CPU particles: see Vfx.part)
var _burn_state := -1
var ring: MeshInstance3D
var _vis := true
# the crew's behaviour tree (see VehicleBrain)
var bt_path := ""
var bt_cd := {}
var brain_state := ""  # "", "withdraw", "evade", "wait"
var brain_t := 0.0
var brain_resume: Dictionary = {}
var brain_hold := false  # waiting for the infantry: stop where it is
var face_yaw := INF  # at a halt: the way to turn the hull (front armour to the threat)
var brain_overruled := false  # told to fight on though badly damaged
var _brain_order := false


func ekind() -> String:
	return "vehicle"


func display_name() -> String:
	return vdef.get("name", "Vehicle")


func apply_props(d: Dictionary) -> void:
	if d.has("vkind"):
		vkind = d.vkind
	if d.has("team"):
		team = d.team
	if d.has("owner"):
		owner_peer = d.owner
	if d.has("pos"):
		position = d.pos
		net_pos = d.pos
	if d.has("yaw"):
		rotation.y = d.yaw
		net_yaw = d.yaw
	if d.has("max_hp"):
		max_hp = d.max_hp


func get_props() -> Dictionary:
	return {"vkind": vkind, "team": team, "owner": owner_peer, "pos": position, "yaw": rotation.y, "max_hp": max_hp}


func on_spawned() -> void:
	vdef = Defs.VEHICLES[vkind]
	if base() in ["attack_heli", "lift_heli"]:
		flight = HelicopterFlight.new()
	if srv:
		max_hp = float(vdef.hp)
		hp = max_hp
		body = StaticBody3D.new()
		body.collision_layer = Defs.L_VEHICLE
		body.collision_mask = 0
		body.set_meta("eid", eid)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = _hull_size()
		cs.shape = bs
		cs.position = Vector3(0, bs.size.y * 0.5, 0)
		body.add_child(cs)
		add_child(body)
	net_pos = position
	net_yaw = rotation.y
	net_init = true
	rearm()
	if base() in ["lift_heli", "uav"]:
		uav_dest = Vector3(position.x, 0.0, position.z)
	if world.has_view:
		_build_model()


func _hull_size() -> Vector3:
	return vdef.get("size", Vector3(2.3, 2.6, 6.0))


## What it is (see Defs.VEHICLES): "tank", "afv", "car", "spaa", "attack_heli",
## "lift_heli", "supply", ...
func base() -> String:
	return String(vdef.get("base", "tank"))


## 0 light (a pickup, a jeep), 1 medium (an APC, a truck), 2 heavy (a tank).
func weight() -> int:
	return int(vdef.get("weight", 1))


## A light vehicle with a roof gun: it can't push through a house wall.
func is_light() -> bool:
	return base() in ["car", "spaa", "ugv"] and weight() == 0


## A helicopter (flying or not).
func is_heli() -> bool:
	return vdef.get("air", false)


## Runs itself (the supply convoy and supply helicopters): not yours to command.
func is_auto() -> bool:
	return vdef.get("auto", false)


func is_air() -> bool:
	return is_heli() and position.y > 3.0


func is_boat() -> bool:
	return vdef.get("base", "") == "boat"


func is_moving() -> bool:
	return path_pending or path_i < path.size() or (is_heli() and velocity.length() > 0.5)


## Missiles back to a full load (built with them; an ammo truck refills them).
func rearm() -> void:
	var a: Array = vdef.get("atgm", [0, 0.0])
	atgm_left = int(a[0])
	var s: Array = vdef.get("sam", [0, 0.0])
	sam_left = int(s[0])


func get_exclude() -> Array:
	return [body.get_rid()] if body else []


func exposed_points() -> Array:
	return [position + Vector3(0, 1.2, 0), position + Vector3(0, 1.8, 0), position + Defs.dir_of(rotation.y) * 2.0 + Vector3(0, 1.0, 0)]


func center_point() -> Vector3:
	return position + Vector3(0, 1.1, 0)


## How easy it is to hit, against a man's 1.0: a truck or a tank is a barn
## door, a quad bike a man, a quadcopter drone a bird.
func hit_factor() -> float:
	return float(vdef.get("hit", 2.0))


func needs_repair() -> bool:
	return track_broken or hp < max_hp - 1.0


func repair(amount: float) -> void:
	hp = minf(max_hp, hp + amount * max_hp / 40.0)
	if track_broken:
		track_fix += amount
		if track_fix >= 6.0:
			track_broken = false
			track_fix = 0.0
			world.send_msg(team, "info", "%s track repaired." % display_name(), position)


func turret_pos() -> Vector3:
	if base() == "attack_heli":
		return position + Vector3(0, float(vdef.get("gun_h", 0.8)), 0) + Defs.dir_of(rotation.y) * 2.3
	return position + Vector3(0, float(vdef.get("gun_h", 2.2)), 0)


func barrel_tip() -> Vector3:
	return turret_pos() + Defs.dir_of(rotation.y + turret_yaw) * 4.2


# --- orders --------------------------------------------------------------------------

## The crew's own move (see VehicleBrain): doesn't count as a new order.
func drive_to(p: Vector3) -> void:
	_brain_order = true
	order_move(p)
	_brain_order = false


## An AI commander's orders wait while the crew takes a wreck back for repairs
## (a player's go through: it's their call).
func _crew_busy() -> bool:
	return brain_state == "withdraw" and owner_peer < 0 and not _brain_order


func order_move(p: Vector3) -> void:
	if _crew_busy():
		return
	assault = false
	if base() == "supply":
		return
	if base() == "attack_heli":
		forced_target = null
		gs_dest = Vector3(p.x, 0.0, p.z)
		return
	if base() == "lift_heli":
		lift_dest = _landing_spot(p)
		if lift_phase in [3, 4, 7]:
			lift_phase = 2 if position.y > 3.0 else 1
		return
	if base() == "uav":
		uav_dest = Vector3(p.x, 0.0, p.z)
		return
	forced_target = null
	if is_boat():
		path = world.nav.find_boat_path(position, p)
	else:
		_request_ground_path(p, 0.5)
	path_i = 0
	_stuck_t = 0.0
	_stuck_p = position
	if not _brain_order:
		if brain_state == "withdraw":
			brain_overruled = true  # sent back in damaged: the crew does as it's told
		brain_state = ""
		brain_hold = false
		brain_resume = {}


## Attack-move: drive on, but halt for a steady shot whenever there's something in range.
func order_assault(p: Vector3) -> void:
	if _crew_busy():
		return
	order_move(p)
	assault = true
	assault_dest = p


func is_tracked() -> bool:
	return vdef.get("tracked", false)


## How many men it can carry besides its crew (its own section's size unless
## the definition says otherwise).
func seats() -> int:
	if vdef.has("seats"):
		return int(vdef.seats)
	var key := String(vdef.get("carry", ""))
	if key != "" and Defs.SQUADS.has(key):
		return maxi(4, (Defs.SQUADS[key].members as Array).size())
	return 0


func seats_free() -> int:
	var n := 0
	for s in passengers:
		if is_instance_valid(s) and not s.gone:
			n += 1
	return seats() - n


## A soldier climbs in (he's hidden inside until it dismounts him).
func board(s: Soldier) -> bool:
	if seats_free() <= 0 or (is_heli() and position.y > 1.0) or gone:
		return false
	passengers.append(s)
	s.riding = self
	s.hide_in("vehicle", 9999.0, null)
	world.stat("boarded")
	return true


## Fill the troop compartment with a fresh squad (IFVs and APCs come with one).
func embark_new_squad() -> void:
	var key := String(vdef.get("carry", ""))
	if key == "" or not Defs.SQUADS.has(key):
		return
	var sq: Squad = world.rules.spawn_squad(key, team, owner_peer, position)
	for s in sq.members:
		passengers.append(s)
		s.riding = self
		s.hide_in("vehicle", 9999.0, null)


## The bank or beach a boat is lying off (within reach of wading), or INF.
func _shore() -> Vector3:
	var s := world.nav.nearest_walkable(position)
	return s if Defs.flat(s - position).length() < 15.0 else Vector3.INF


## Ramp down: the section piles out behind the vehicle and goes to work.
func dismount() -> void:
	if passengers.is_empty():
		return
	var back := -Defs.dir_of(rotation.y)
	var side := back.cross(Vector3.UP)
	if is_boat():
		# over the side and up the beach
		var shore := _shore()
		if shore == Vector3.INF:
			return
		var up := Defs.flat(shore - position).normalized()
		back = up
		side = up.cross(Vector3.UP)
	var sq: Squad = null
	var i := 0
	for s in passengers:
		if not is_instance_valid(s) or s.gone or s.life != Soldier.Life.HIDDEN:
			continue
		s.riding = null
		var at := position + back * 3.6 + side * (i - 1.5) * 1.3
		if is_boat():
			at = world.nav.nearest_walkable(_shore() + side * (i - 1.5) * 1.3)
		s.unhide(at)
		sq = s.squad
		i += 1
	passengers.clear()
	world.stat("dismount")
	if sq:
		var fwd := Defs.dir_of(rotation.y)
		var lead := sq.get_leader()
		if lead:
			lead.say("Dismount! Go, go, go!" if team == 0 else "Out! Everybody out!", true)
		if (assault or is_boat()) and assault_dest != Vector3.INF:
			sq.order_assault(assault_dest, fwd)
		else:
			sq.order_defend(position + fwd * 8.0, fwd)


func _dismount_check(dt: float) -> void:
	if passengers.is_empty() or base() == "lift_heli":
		return
	_dis_t -= dt
	if _dis_t > 0.0:
		return
	_dis_t = 0.5
	if is_boat():
		# boats put their men ashore where they stop by a bank or a beach -
		# at the end of a trip, not the moment they've climbed aboard
		if _landing and path_i >= path.size() and absf(speed) < 0.8 and _shore() != Vector3.INF:
			_landing = false
			dismount()
		return
	var arrived := path_i >= path.size() and speed < 0.6
	var close := false
	if assault:
		for e in world.units_near(position, 70.0):
			if e.team != team and e.team >= 0 and e.visible_to_team(team) and (not (e is Soldier) or e.life == Soldier.Life.ALIVE):
				close = true
				break
	if arrived or close or hp < max_hp * 0.4:
		dismount()


## Can this helicopter lift that vehicle on its sling?
func can_sling(v: Vehicle) -> bool:
	return base() == "lift_heli" and int(vdef.get("sling", -1)) >= 0 and v != null and v != self and not v.gone and v.team == team \
		and not v.is_heli() and not v.is_boat() and not v.is_auto() and v.weight() <= int(vdef.sling) and v.slung_by == null and sling_cargo == null


## Go and pick that vehicle up on the sling (it's hooked from the hover, then
## waits, hanging, for the order to take it somewhere).
func order_sling(v: Vehicle) -> void:
	if not can_sling(v):
		return
	sling_target = v
	lift_dest = Vector3.INF
	_sling_t = 0.0
	lift_phase = 5 if position.y > 3.0 else 1
	world.stat("sling_order")


func _request_ground_path(destination: Vector3, care: float) -> void:
	_path_revision += 1
	path_pending = true
	path_destination = destination
	var revision := _path_revision
	path = PackedVector3Array()
	path_i = 0
	world.nav.request_path(self, destination, true, team, care, func(points: PackedVector3Array):
		if revision != _path_revision:
			return
		path_pending = false
		if gone or hp <= 0.0:
			return
		path = points
		path_i = 0)


func order_attack(t: Entity) -> void:
	forced_target = t
	if base() == "attack_heli":
		gs_dest = Vector3(t.position.x, 0.0, t.position.z)
		return
	var d := Defs.flat(t.position - position)
	if d.length() > 45.0:
		if is_boat():
			path = world.nav.find_boat_path(position, t.position - d.normalized() * 40.0)
		else:
			_request_ground_path(t.position - d.normalized() * 40.0, 0.2)
		path_i = 0


func order_stop() -> void:
	_path_revision += 1
	path_pending = false
	path_destination = Vector3.INF
	world.nav.cancel_path(eid)
	if base() == "lift_heli" and not is_auto():
		sling_target = null
		lift_dest = Vector3.INF
		_flight_hold = position
		lift_phase = 7 if position.y > 0.6 else 0
	if base() == "uav":
		uav_dest = Vector3(position.x, 0.0, position.z)
	if base() == "attack_heli":
		gs_dest = Vector3(position.x, 0.0, position.z)
	path = PackedVector3Array()
	path_i = 0
	forced_target = null


# --- simulation ----------------------------------------------------------------------

func sim(dt: float) -> void:
	if slung_by != null:
		if not is_instance_valid(slung_by) or slung_by.gone or slung_by.sling_cargo != self:
			_drop_from_sling()
		return  # hanging under a helicopter: it does nothing of its own
	cannon_t -= dt
	mg_t -= dt
	if knock_v.length_squared() > 0.0025:
		var np := position + knock_v * dt
		if world.nav.walkable(np) and Defs.in_map(np, 4.0):
			position = np
		else:
			knock_v = Vector3.ZERO
		knock_v = knock_v.move_toward(Vector3.ZERO, 7.0 * dt)
	var b := base()
	if b == "supply":
		_truck_tick(dt)
	elif b == "lift_heli":
		if vdef.get("supply", false):
			_heli_tick(dt)
		else:
			_lift_tick(dt)
	elif b == "attack_heli":
		_gunship_tick(dt)
	elif b == "uav":
		_uav_tick(dt)
	elif b == "boat":
		scan_t -= dt
		if scan_t <= 0.0:
			scan_t = 0.5
			_scan()
		_boat_drive(dt)
		_dismount_check(dt)
		_turret_tick(dt)
		_fire_tick()
	else:
		scan_t -= dt
		if scan_t <= 0.0:
			scan_t = 0.5
			_scan()
			if VehicleBrain.applies(self):
				VehicleBrain.think(self)
		var hull_yaw := rotation.y
		_drive(dt)
		if b == "tank" and _target_ok():
			turret_yaw = wrapf(turret_yaw - wrapf(rotation.y - hull_yaw, -PI, PI), -PI, PI)
		_dismount_check(dt)
		if vdef.has("art"):
			_arty_tick(dt)
		if _lay_yaw == INF or not vdef.has("art"):
			_turret_tick(dt)
		_fire_tick()
		if vdef.has("service"):
			_service_tick(dt)
		smash_t -= dt
		if smash_t <= 0.0:
			smash_t = 0.15
			_smash()
	var laid := _salvo > 0 or (vdef.has("art") and world.time - last_fire_t < 4.0)
	var grounded := is_heli() and position.y < 0.6
	flags = (F_TRACK if track_broken else 0) | (F_FIRE if world.time - last_fire_t < 0.3 else 0) | (F_BLOCKED if blocked_t > 2.0 else 0) \
		| (F_ELEV if laid else 0) | (F_GROUND if grounded else 0)


# --- driving ----------------------------------------------------------------------------
#
# A vehicle follows its route the way a driver does: it steers for a point some
# way down the road (further the faster it goes), slows for the bends ahead and
# brakes to stop where it's going. Wheeled vehicles steer like cars - a real
# turning circle from their wheelbase and steering lock, no turning on the spot;
# tracked ones skid-steer - they can pivot where they stand, but turn wider the
# faster they go. Weight decides how hard they accelerate and brake and how
# fast they can take a bend. A spot close behind is backed into rather than
# reached by driving round in a circle, and a vehicle keeps its distance behind
# another on its line rather than driving into it.

var yaw_rate := 0.0  # how fast it's turning (rad/s, + to the left)
var _rev := false  # backing up to where it's going


## [acceleration, braking (m/s²), cornering grip (m/s² sideways), reverse speed (fraction)]
func _handling() -> Array:
	match weight():
		0:
			return [3.0, 6.5, 4.0, 0.4]
		1:
			return [1.9, 5.0, 3.0, 0.35]
	return [1.2, 4.0, 2.2, 0.32]


func _wheelbase() -> float:
	return maxf(2.2, _hull_size().z * 0.58)


## The front wheels' full lock (wheeled vehicles).
func _max_steer() -> float:
	return 0.62 if weight() == 0 else 0.5


## The point `ld` metres from the vehicle along pts (from index i on), or the last point.
func _lookahead(pts: PackedVector3Array, i: int, ld: float) -> Vector3:
	var prev := Defs.flat(position)
	for j in range(i, pts.size()):
		var q := Defs.flat(pts[j])
		var dq := q.distance_to(Defs.flat(position))
		if dq >= ld:
			var dp := prev.distance_to(Defs.flat(position))
			var k := clampf((ld - dp) / maxf(dq - dp, 0.001), 0.0, 1.0)
			return prev.lerp(q, k)
		prev = q
	return Defs.flat(pts[pts.size() - 1])


## How fast it may close on a vehicle ahead going the same way (m/s): it
## follows at a gap rather than run into the back of it.
func _traffic_limit(fwd: Vector3, vmax: float) -> float:
	var lim := vmax
	var look := 6.0 + absf(speed) * 1.8
	var side := fwd.cross(Vector3.UP)
	var me := _hull_size()
	for v in world.vehicles_near(position + fwd * look * 0.5, look):
		if v == self or v.gone or v.is_air() or v.position.y > 1.0:
			continue
		if Defs.dir_of(v.rotation.y).dot(fwd) < 0.3 or absf(v.speed) < 0.8:
			continue  # oncoming, or standing: steered round (see _avoid)
		var rel := Defs.flat(v.position - position)
		var ahead := rel.dot(fwd)
		if ahead <= 0.0:
			continue
		var oh: Vector3 = v._hull_size()
		if absf(rel.dot(side)) > (me.x + oh.x) * 0.5 + 0.8:
			continue
		var gap := ahead - (me.z + oh.z) * 0.5
		lim = minf(lim, maxf(absf(v.speed) * 0.9, (gap - 2.5) * 0.9))
	return lim


var _avoid_cap := INF


## A vehicle standing in the way, or coming the other way, is driven round:
## the point it steers for moves off to the side - right of an oncoming one,
## the roomier side of a standing one - far enough to clear it, and it slows
## while it passes.
func _avoid(la: Vector3, fwd: Vector3) -> Vector3:
	_avoid_cap = INF
	var side := fwd.cross(Vector3.UP)  # (to the right)
	var me := _hull_size()
	var look := 8.0 + absf(speed) * 1.5
	var best := INF
	var out := la
	for v in world.vehicles_near(position + fwd * look * 0.5, look):
		if v == self or v.gone or v.is_air() or v.position.y > 1.0:
			continue
		var rel := Defs.flat(v.position - position)
		var ahead := rel.dot(fwd)
		if ahead <= 0.5 or ahead > look or ahead > best:
			continue
		var standing: bool = absf(v.speed) < 0.8
		if not standing and Defs.dir_of(v.rotation.y).dot(fwd) > 0.3:
			continue  # going our way: followed instead
		var lat := rel.dot(side)
		var clear: float = (me.x + v._hull_size().x) * 0.5 + 1.0
		if absf(lat) > clear:
			continue
		var go := 1.0
		if standing:
			go = -signf(lat) if absf(lat) > 0.3 else 1.0
			var past := position + fwd * ahead + side * go * clear
			# (a boat's room is open water - which is no way at all for anything on wheels)
			if (not world.nav.boat_ok(past)) if is_boat() else world.nav.vkind_at(past) == Nav.SOLID:
				go = -go
			_avoid_cap = 3.0
		best = ahead
		out = Defs.flat(position) + fwd * maxf(ahead, 4.0) + side * (lat + go * clear)
	return out


## Drives along pts from index i (see above); returns the index it has got to,
## pts.size() once it's there.
func _follow(pts: PackedVector3Array, i: int, dt: float, vmax: float, may_reverse := true, lane := 0.0) -> int:
	var n := pts.size()
	var h: Array = _handling()
	if i >= n:
		_coast(dt)
		return i
	# past the points it has reached (or driven by)
	while i < n - 1:
		var pi := Defs.flat(pts[i])
		var seg := Defs.flat(pts[i + 1]) - pi
		if Defs.flat(position).distance_to(pi) < 2.5 or (seg.length() > 0.01 and (Defs.flat(position) - pi).dot(seg) > 0.0):
			i += 1
		else:
			break
	var to_end := Defs.flat(pts[n - 1] - position).length()
	if i >= n - 1 and to_end < 1.8:
		_coast(dt)
		return n if absf(speed) < 0.4 else i
	vmax *= world.terrain.speed_mul(position, true, is_tracked())
	# a long vehicle looks further down the road (and doesn't weave at a crawl)
	var ld0 := maxf(4.0, _wheelbase() * 1.4)
	var ld := clampf(ld0 + absf(speed) * 0.9, ld0, 16.0)
	var la := _lookahead(pts, i, ld)
	if lane != 0.0:
		# keep to the right-hand side of the road
		var rd := _lookahead(pts, i, ld + 2.5) - la
		if rd.length() > 0.1:
			la += rd.normalized().cross(Vector3.UP) * lane
	if not _rev:
		la = _avoid(la, Defs.dir_of(rotation.y))
	var to := la - Defs.flat(position)
	var err := wrapf(Defs.yaw_of(to) - rotation.y, -PI, PI)
	# close behind: back into it (tracks or wheels) rather than drive round in a loop
	if may_reverse:
		if not _rev and absf(err) > 2.1 and to_end < 30.0:
			_rev = true
		elif _rev and (absf(err) < 1.2 or to_end > 40.0):
			_rev = false
	else:
		_rev = false
	var e := wrapf(err - PI, -PI, PI) if _rev else err  # measured from the way it's travelling
	# the arc that runs through the point it's steering for - but a point
	# abaft the beam is steered for as hard as one abeam: sin(e) dwindles
	# back to nothing as it comes round dead astern, and a driver (or a
	# coxswain) with where he's going right behind him puts the wheel over
	# and comes round, rather than keep on away from it
	var kappa := 2.0 * (sin(e) if absf(e) < PI * 0.5 else signf(e)) / maxf(to.length(), 1.0)
	var v_t: float = vmax * (float(h[3]) if _rev else 1.0)
	# slow for the bend ahead, and to stop where it's going
	var far := _lookahead(pts, i, 18.0) - Defs.flat(position)
	var bend := absf(wrapf(Defs.yaw_of(far) - rotation.y - (PI if _rev else 0.0), -PI, PI))
	var k_ahead := maxf(absf(kappa), 2.0 * sin(minf(bend, PI * 0.5)) / 18.0)
	v_t = minf(v_t, sqrt(float(h[2]) / maxf(k_ahead, 0.0005)))
	v_t = minf(v_t, sqrt(2.0 * float(h[1]) * maxf(0.0, to_end - 1.5)) + 0.3)
	var pivot := false
	if is_tracked():
		# skid steer: pivot on the spot for a sharp turn, wider turns at speed
		if absf(e) > 0.9:
			pivot = true
			v_t = minf(v_t, 0.8)
		var ymax: float = float(vdef.turn) * (1.0 - 0.45 * clampf(absf(speed) / maxf(vmax, 0.1), 0.0, 1.0))
		var turn := clampf(signf(e) * float(vdef.turn) * 0.75 if pivot else kappa * absf(speed), -ymax, ymax)
		yaw_rate = move_toward(yaw_rate, turn, float(vdef.turn) * dt) if base() == "tank" else turn
	else:
		# steered wheels: no tighter than full lock; slow right down for a hairpin
		var wb := _wheelbase()
		var kmax := tan(_max_steer()) / wb
		if absf(e) > 1.0:
			# the road doubles back: round on full lock, as fast as the tyres hold it
			v_t = minf(v_t, sqrt(float(h[2]) / kmax))
		yaw_rate = clampf(kappa, -kmax, kmax) * absf(speed)
	if not _rev:
		v_t = minf(minf(v_t, _avoid_cap), _traffic_limit(Defs.dir_of(rotation.y), v_t))
	var want := -v_t if _rev else v_t
	var rate: float = float(h[0]) if absf(want) > absf(speed) and signf(want) == signf(speed + want * 0.001) else float(h[1])
	speed = move_toward(speed, want, rate * dt)
	rotation.y += yaw_rate * dt
	_move_by(Defs.dir_of(rotation.y) * speed, dt)
	return i


## Rolling to a stop where it is.
func _coast(dt: float) -> void:
	speed = move_toward(speed, 0.0, float(_handling()[1]) * dt)
	yaw_rate = move_toward(yaw_rate, 0.0, 2.0 * dt)
	_move_by(Defs.dir_of(rotation.y) * speed, dt)


func _move_by(v: Vector3, dt: float) -> void:
	velocity = v
	var np := position + velocity * dt
	if is_boat():
		np.y = WaterMap.LEVEL
		_grounded = not world.nav.boat_ok(np)
		if not _grounded:
			position = np
		else:
			# aground / against the bank: it takes the way off her
			speed *= 0.4
			_sway *= 0.4
			yaw_rate *= 0.5
		return
	if base() == "supply" or world.nav.vkind_at(np) != Nav.SOLID:
		position = np
	else:
		# scrape along whatever we hit instead of stopping dead
		var sx := position + Vector3(velocity.x * dt, 0, 0)
		var sz := position + Vector3(0, 0, velocity.z * dt)
		if absf(velocity.x) > absf(velocity.z) and world.nav.vkind_at(sx) != Nav.SOLID:
			position = sx
		elif world.nav.vkind_at(sz) != Nav.SOLID:
			position = sz
		elif world.nav.vkind_at(sx) != Nav.SOLID:
			position = sx
		speed *= 0.6


func _drive(dt: float) -> void:
	if track_broken or path_i >= path.size() or brain_hold:
		_coast(dt)
		_stuck_t = 0.0
		_face(dt)
		return
	# attack-move: halt for steady shots - but close in on men dug into a trench,
	# whom a round from range just bursts over
	var halt := 65.0 if vdef.cannon else 50.0
	if _target_ok() and target is Soldier and world.terrain.in_trench(target.position) and hp > max_hp * 0.45:
		halt = 32.0
	if assault and _target_ok() and Defs.flat(target.position - position).length() < halt:
		_coast(dt)
		_stuck_t = 0.0
		_face(dt)
		return
	# watchdog: hung up on something -> back off, turn, and plan again
	_stuck_t += dt
	if _unstick_t > 0.0:
		_unstick_t -= dt
		speed = move_toward(speed, -2.6, 8.0 * dt)
		rotation.y += _unstick_dir * float(vdef.turn) * 0.5 * dt
		velocity = Defs.dir_of(rotation.y) * speed
		var bp := position + velocity * dt
		if world.nav.vkind_at(bp) != Nav.SOLID:
			position = bp
		if _unstick_t <= 0.0:
			_request_ground_path(path[path.size() - 1], 0.0)
			path_i = 0
			_stuck_t = 0.0
			_stuck_p = position
		return
	if _stuck_t > 3.0:
		# (a tank pivoting on the spot is going somewhere, if not anywhere yet)
		if Defs.flat(position - _stuck_p).length() < 1.2 and absf(wrapf(rotation.y - _stuck_yaw, -PI, PI)) < 0.5:
			world.stat("veh_unstick")
			_unstick_t = 1.6
			_unstick_dir = 1.0 if world.rng.randf() < 0.5 else -1.0
		_stuck_t = 0.0
		_stuck_p = position
		_stuck_yaw = rotation.y
	path_i = _follow(path, path_i, dt, float(vdef.speed))
	# shove soldiers out of the way
	var front := position + Defs.dir_of(rotation.y) * 2.5
	for s in world.soldiers_near(front, 2.6):
		if s.life == Soldier.Life.HIDDEN or s.flinging:
			continue
		var push := Defs.flat(s.position - position)
		var side := Defs.dir_of(rotation.y).cross(Vector3.UP)
		var dir := side if push.dot(side) > 0.0 else -side
		var np: Vector3 = s.position + dir * 3.0 * dt
		if world.nav.walkable(np):
			s.position = np


## Standing still: a tracked hull turns on the spot to put its front plate
## (the thickest armour) towards the threat the crew's watching (see VehicleBrain).
func _face(dt: float) -> void:
	if face_yaw == INF or track_broken or not is_tracked() or absf(speed) > 0.5:
		return
	var e := wrapf(face_yaw - rotation.y, -PI, PI)
	if absf(e) < 0.12:
		return
	var step := clampf(e, -float(vdef.turn) * 0.6 * dt, float(vdef.turn) * 0.6 * dt)
	rotation.y += step
	if base() != "tank":
		turret_yaw -= step  # tanks stabilize across every driving manoeuvre in sim()


func _smash() -> void:
	if speed < 0.5 and weight() < 2:
		return
	var hs := _hull_size()
	var half := Vector2(hs.x * 0.5, hs.z * 0.5 + 0.3)
	var c := Vector2(position.x, position.z)
	for st in world.structures_near(position, 5.0):
		if st.gone or not st.smashable:
			continue
		if st.team == team and st.is_player_building():
			continue
		if Defs.obb_overlap(c, half, rotation.y, Vector2(st.position.x, st.position.z), st.foot, st.yaw):
			if is_light() and st.skind in ["tall_wall", "house_wall", "concrete_wall"]:
				continue
			st.smash(self)
			world.stat("smash")
			if is_light() and int(vdef.armor) == 0:
				take_damage(15.0, null)  # a pickup doesn't ram walls for free


func _scan() -> void:
	var best: Entity = null
	var bs := -1e9
	var eye := turret_pos()
	var ex := get_exclude()
	for e in world.units_near(position, maxf(72.0, float(vdef.get("sight", 50.0)) + 20.0)):
		if e.team == team or e.team < 0:
			continue
		if e is Soldier and e.life != Soldier.Life.ALIVE:
			continue
		var d: float = Defs.flat(e.position - position).length()
		var sc := 0.0
		if e is Vehicle and e.is_air():
			if vdef.get("aa", false) or sam_left > 0:
				sc = 160.0 - d
			elif Defs.WEAPONS.get(String(vdef.mg), {}).get("ap", false):
				sc = 20.0 - d  # a heavy MG or a cannon will have a go at a helicopter
			else:
				continue
		elif e is Vehicle:
			sc = (110.0 if vdef.cannon else (70.0 if base() == "attack_heli" else 40.0)) - d
		else:
			sc = 50.0 - d
			if e.rockets > 0:
				sc += 25.0
		if e == target:
			sc += 8.0
		if sc <= bs:
			continue
		if not world.combat.can_see_from(eye, e, ex):
			continue
		bs = sc
		best = e
	if best == null and vdef.cannon:
		for st in world.structures_near(position, 55.0):
			if st.team < 0 or st.team == team or not st.is_player_building() or st.skind in ["mines", "wire", "tank_trap", "trench", "camo_net", "hesco", "barricade"]:
				continue
			if not st.visible_to_team(team):
				continue
			if world.combat.sees_structure(eye, st):
				best = st
				break
	if forced_target and not forced_target.gone:
		var fd := Defs.flat(forced_target.position - position).length()
		if fd < 75.0:
			best = forced_target
	target = best
	for s in world.soldiers_near(position, 30.0):
		if s.team != team and s.team >= 0 and s.squad and s.life == Soldier.Life.ALIVE:
			s.squad.report(self)


func _target_ok() -> bool:
	if not is_instance_valid(target) or target.gone:
		return false
	if target is Soldier:
		return target.life == Soldier.Life.ALIVE
	if target is Drone:
		return not target.dead
	return true


func _turret_tick(dt: float) -> void:
	if base() == "tank":
		var has_target := _target_ok()
		var want := Defs.yaw_of(Defs.flat(target.position - position)) - rotation.y if has_target else 0.0
		var err := wrapf(want - turret_yaw, -PI, PI)
		# The traverse motor builds speed, then brakes before reaching the gunner's bearing.
		var rate := 0.7 if has_target else 0.35
		_traverse = move_toward(_traverse, signf(err) * minf(rate, sqrt(2.0 * absf(err))), dt)
		var step := _traverse * dt
		if signf(step) == signf(err) and absf(step) >= absf(err):
			step = err
			_traverse = 0.0
		turret_yaw = wrapf(turret_yaw + step, -PI, PI)
		var target_id := target.eid if has_target else 0
		if target_id != _aim_target:
			_aim_time = 0.0
			_aim_target = target_id
		# Hold a firing solution briefly; crossing a target during a slew isn't a shot.
		if has_target and _aim_err() < 0.025 and absf(_traverse) < 0.12:
			_aim_time += dt
		else:
			_aim_time = 0.0
		return
	if not _target_ok():
		turret_yaw = move_toward(turret_yaw, 0.0, dt * 0.6)
		return
	var want := Defs.yaw_of(Defs.flat(target.position - position)) - rotation.y
	var rate := 1.2 if vdef.cannon else 3.0
	turret_yaw += clampf(wrapf(want - turret_yaw, -PI, PI), -rate * dt, rate * dt)


func _aim_err() -> float:
	if not _target_ok():
		return PI
	var want := Defs.yaw_of(Defs.flat(target.position - position))
	return absf(wrapf(want - (rotation.y + turret_yaw), -PI, PI))


func _fire_tick() -> void:
	if not _target_ok():
		return
	var err := _aim_err()
	var dist := Defs.flat(target.position - position).length()
	if _try_missiles(err, dist):
		return
	if vdef.cannon and cannon_t <= 0.0 and err < 0.05 and (base() != "tank" or _aim_time >= 0.3):
		var worth := target is Vehicle or target is Structure
		if target is Soldier:
			var n := 0
			for o in world.soldiers_near(target.position, 5.0):
				if o.team == target.team and o.life == Soldier.Life.ALIVE:
					n += 1
			worth = n >= 2 or target.rockets > 0 or target.mounted != null or world.rng.randf() < 0.25
		if worth:
			_fire_cannon()
			cannon_t = float(vdef.get("gun", {}).get("cd", 5.5))
			return
	var mg: String = vdef.mg
	var gs := base() == "attack_heli"
	var mg_range := 70.0 if not (gs or base() == "spaa" or (target is Vehicle and target.is_air())) else 105.0
	if mg != "" and mg_t <= 0.0 and err < 0.15 and dist < mg_range and not (target is Structure and not gs) and not (target is Vehicle and vdef.armor >= 2 and target.vdef.armor >= 2 and mg != "chaingun"):
		var w: Dictionary = Defs.WEAPONS[mg]
		if mg_burst <= 0:
			mg_burst = world.rng.randi_range(w.burst.x, w.burst.y)
		mg_burst -= 1
		var roof := is_light() or gs
		var muzzle := turret_pos() + Defs.dir_of(rotation.y + turret_yaw) * (0.8 if roof else 2.0) + Vector3(0, (-0.1 if gs else 0.2) if roof else -0.3, 0)
		var aim: Vector3 = target.exposed_points()[0] if target is Soldier else target.center_point()
		world.combat.fire_bullet(self, muzzle, aim, target, w, 1.0)
		last_fire_t = world.time
		mg_t = float(w.interval) if mg_burst > 0 else world.rng.randf_range(0.6, 1.3)


## Guided missiles: an ATGM at armour or a bunker, a SAM at anything flying.
func _try_missiles(err: float, dist: float) -> bool:
	if target is Vehicle and target.is_air():
		if sam_left > 0 and world.time > sam_t and dist < float(vdef.get("sam_range", 160.0)):
			_launch("sam", target)
			sam_left -= 1
			sam_t = world.time + float((vdef.sam as Array)[1])
			return true
		return false
	if atgm_left > 0 and world.time > atgm_t and err < 0.4 and dist > 22.0 and dist < float(vdef.get("atgm_range", 125.0)):
		var worth: bool = target is Vehicle or (target is Structure and target.skind in ["bunker", "mg_nest", "hmg_nest", "at_post", "watchtower"])
		if worth:
			_launch("atgm", target)
			atgm_left -= 1
			atgm_t = world.time + float((vdef.atgm as Array)[1])
			return true
	return false


func _launch(kind: String, t: Entity) -> void:
	var fwd := Defs.dir_of(rotation.y + turret_yaw)
	var from := turret_pos() + fwd * 1.0 + Vector3(0, 0.45, 0)
	var aim := t.center_point()
	var v := ((aim - from).normalized() + Vector3(0, 0.3 if kind == "atgm" else 0.5, 0)).normalized() * (26.0 if kind == "atgm" else 38.0)
	world.spawn("projectile", {"ptype": kind, "team": team, "pos": from, "vel": v, "thrower": eid, "tgt": t.eid, "target": aim})
	world.fx_event([Fx.LAUNCH, from, v.normalized()])
	world.stat("veh_" + kind)
	last_fire_t = world.time


# --- self-propelled artillery ---------------------------------------------------------

## Halted, it lays its gun (or raises its launcher) on spotted enemies in
## range - or on the player's fire missions - and fires a salvo, then reloads.
func _arty_tick(dt: float) -> void:
	var a: Dictionary = vdef.art
	if _salvo > 0:
		var want := Defs.yaw_of(Defs.flat(_salvo_at - position)) - rotation.y
		turret_yaw += clampf(wrapf(want - turret_yaw, -PI, PI), -dt * 0.9, dt * 0.9)
		_lay_yaw = want
		_salvo_t -= dt
		if _salvo_t <= 0.0 and absf(wrapf(want - turret_yaw, -PI, PI)) < 0.06:
			_fire_shell(a)
			_salvo -= 1
			_salvo_t = float(a.get("gap", 0.8))
			if _salvo <= 0:
				_lay_yaw = INF
		return
	if path_pending or path_i < path.size() or world.time < arty_t:
		return
	var tp := Vector3.INF
	if not fire_queue.is_empty():
		tp = fire_queue.pop_front()
	else:
		tp = world.rules.mortar_target(team, position, float(a.get("min", 40.0)), float(a.get("max", 230.0)))
	if tp == Vector3.INF:
		arty_t = world.time + 2.0
		return
	_salvo_at = tp
	_salvo = int(a.get("salvo", 3))
	_salvo_t = float(a.get("lay", 2.0))
	arty_t = world.time + float(a.get("cd", 18.0))
	world.stat("arty_mission")


func _fire_shell(a: Dictionary) -> void:
	var fwd := Defs.dir_of(rotation.y + turret_yaw)
	var from := position + Vector3(0, float(vdef.get("gun_h", 2.2)) + 1.2, 0) + fwd * float(a.get("muzzle", 4.0))
	var d := Defs.flat(_salvo_at - from).length()
	var scatter := float(a.get("scatter", 3.0)) + d * 0.025
	var ang := world.rng.randf() * TAU
	var r := sqrt(world.rng.randf()) * scatter
	var tp := Vector3(_salvo_at.x + cos(ang) * r, 0.05, _salvo_at.z + sin(ang) * r)
	var shell := String(a.get("shell", "arty"))
	world.spawn("projectile", {"ptype": shell, "team": team, "pos": from, "origin": from, "target": tp, "T": 2.6 + d / 45.0, "thrower": eid})
	if shell == "grad":
		world.fx_event([Fx.LAUNCH, from, (fwd + Vector3(0, 1.2, 0)).normalized()])
	else:
		world.fx_event([Fx.MORTAR, from])
		recoil(-fwd)
	last_fire_t = world.time
	world.stat("arty_round")


# --- support vehicles -----------------------------------------------------------------

## Repair, ammunition and medical vehicles look after everything near them.
func _service_tick(dt: float) -> void:
	_svc_t -= dt
	if _svc_t > 0.0 or speed > 1.0:
		return
	_svc_t = 1.0
	match String(vdef.service):
		"repair":
			for v in world.vehicles_near(position, 13.0):
				if v != self and v.team == team and v.needs_repair():
					v.repair(1.4)
					world.stat("veh_repaired")
		"ammo":
			for s in world.soldiers_near(position, 13.0):
				if s.team == team and s.life == Soldier.Life.ALIVE:
					s.resupply(1.0)
			for v in world.vehicles_near(position, 13.0):
				if v != self and v.team == team:
					v.rearm()
		"medical":
			for s in world.soldiers_near(position, 11.0):
				if s.team != team:
					continue
				if s.life == Soldier.Life.DOWNED and s.dragged_by == null and s.carried_by.is_empty() and world.rng.randf() < 0.22:
					s.revive()
					world.stat("veh_medevac_revive")
				elif s.life == Soldier.Life.ALIVE and s.hp < s.max_hp:
					s.hp = minf(s.max_hp, s.hp + 5.0)


# --- troop-carrying helicopters -------------------------------------------------------

## Every rotorcraft phase uses the same dynamics, including vertical flight.
func _fly_to(goal: Vector3, dt: float, face := INF) -> bool:
	flight.step(self, goal, dt, face)
	flight_pitch = flight.pitch
	flight_roll = flight.roll
	return flight.settled(self, goal)


func _flight_ground(p: Vector3) -> float:
	return maxf(0.0, world.ground_y(p)) + 0.15


const LIFT_ALT := 16.0


## Somewhere to put down near p: open ground, nothing built on it.
func _landing_spot(p: Vector3) -> Vector3:
	for ring in [0.0, 6.0, 11.0, 16.0]:
		var n := 1 if ring == 0.0 else 8
		for i in n:
			var q: Vector3 = Vector3(p.x, 0.0, p.z) + Vector3(cos(i * TAU / n), 0, sin(i * TAU / n)) * ring
			if not Defs.in_map(q, 8.0) or world.nav.vkind_at(q) != Nav.FREE:
				continue
			var clear := true
			for st in world.structures_near(q, 6.0):
				if not st.gone and st.skind != "floor" and Defs.flat(st.position - q).length() < st.radius + 4.0:
					clear = false
					break
			if clear:
				return q
	return Vector3(p.x, 0.0, p.z)


const SLING_ROPE := 7.0  # from the hook under the helicopter to the top of the load


## Height of the ground under the load (where it would sit if let go).
func _cargo_h() -> float:
	return 0.0 if sling_cargo == null else sling_cargo._hull_size().y


func _hook(v: Vehicle) -> void:
	sling_target = null
	sling_cargo = v
	sling_eid = v.eid
	v.slung_by = self
	v.path = PackedVector3Array()
	v.path_i = 0
	v.speed = 0.0
	v.velocity = Vector3.ZERO
	v.assault = false
	_swing = Vector3.ZERO
	lift_phase = 1
	world.stat("sling_hooked")
	if not is_auto():
		world.send_msg(team, "info", "%s has %s on the sling." % [display_name(), v.display_name()], position)


## Set the load down where it hangs (on the ground under it).
func _release_sling() -> void:
	var v := sling_cargo
	sling_cargo = null
	sling_eid = 0
	if v == null or v.gone:
		return
	v.slung_by = null
	v.position = world.nav.nearest_walkable(Vector3(v.position.x, 0, v.position.z), true)
	v.velocity = Vector3.ZERO
	world.stat("sling_delivered")
	if not is_auto():
		world.send_msg(team, "info", "%s set down at %s." % [v.display_name(), Defs.grid_ref(v.position)], v.position)


## (cargo) The helicopter's gone (shot down, say): it falls.
func _drop_from_sling() -> void:
	var h := position.y
	slung_by = null
	position = world.nav.nearest_walkable(Vector3(position.x, 0, position.z), true)
	velocity = Vector3.ZERO
	if h > 3.0:
		take_damage(max_hp * clampf(h / 30.0, 0.15, 0.9), null)
		world.fx_event([Fx.DEBRIS, position + Vector3(0, 0.5, 0), Color(0.3, 0.28, 0.24), 10])
		world.fx_event([Fx.SOUND, "thud", position])
	world.stat("sling_dropped")


## (heli) The load hangs under the hook, trailing a little behind as it flies
## and swinging when it turns or stops.
func _sling_tick(dt: float) -> void:
	var v := sling_cargo
	if v == null:
		return
	if v.gone:
		sling_cargo = null
		sling_eid = 0
		return
	var trail := -velocity * 0.09
	_swing = _swing.lerp(trail, 1.0 - exp(-dt * 1.6))
	var hang := position + Vector3(_swing.x, -SLING_ROPE - v._hull_size().y, _swing.z)
	v.position = hang
	v.rotation.y = lerp_angle(v.rotation.y, rotation.y, 1.0 - exp(-dt * 0.8))
	v.velocity = velocity


## Lifts off when sent somewhere, flies there, puts down on clear ground and
## the troops pile out; then it flies home to the pad. Door gunners fire at
## whatever they can see on the way.
func _lift_tick(dt: float) -> void:
	_sling_tick(dt)
	scan_t -= dt
	if scan_t <= 0.0:
		scan_t = 0.5
		_scan()
	if _target_ok() and position.y > 3.0:
		turret_yaw = Defs.yaw_of(Defs.flat(target.position - position)) - rotation.y  # door guns cover all round
		_fire_tick()
	match lift_phase:
		0:
			_fly_to(Vector3(position.x, _flight_ground(position), position.z), dt)
			if lift_dest != Vector3.INF and Defs.flat(lift_dest - position).length() > 0.7:
				lift_phase = 1
		1:
			var climb := Vector3(position.x, LIFT_ALT, position.z)
			if _fly_to(climb, dt):
				if sling_target != null:
					lift_phase = 5
				elif lift_dest != Vector3.INF:
					lift_phase = 2
		2:
			var cruise := Vector3(lift_dest.x, LIFT_ALT, lift_dest.z)
			if _fly_to(cruise, dt):
				lift_phase = 3
		3:
			if sling_cargo != null:
				var drop := Vector3(lift_dest.x, _flight_ground(lift_dest) + _cargo_h() + SLING_ROPE, lift_dest.z)
				if _fly_to(drop, dt):
					_sling_t += dt
					if _sling_t > 1.2:
						_release_sling()
						lift_dest = Vector3.INF
						lift_phase = 1
				return
			var touchdown := Vector3(lift_dest.x, _flight_ground(lift_dest), lift_dest.z)
			if _fly_to(touchdown, dt):
				lift_dest = Vector3.INF
				if not passengers.is_empty():
					dismount()
					lift_t = 3.0
					lift_phase = 4
				else:
					lift_phase = 0
		5:
			var tv := sling_target
			if tv == null or tv.gone or not can_sling(tv):
				sling_target = null
				lift_phase = 1
				return
			if _fly_to(Vector3(tv.position.x, LIFT_ALT, tv.position.z), dt):
				_sling_t = 0.0
				lift_phase = 6
		6:
			var tv := sling_target
			if tv == null or tv.gone or not can_sling(tv):
				sling_target = null
				lift_phase = 1
				return
			var hover := tv.position + Vector3(0, tv._hull_size().y + SLING_ROPE, 0)
			if _fly_to(hover, dt):
				_sling_t += dt
				if _sling_t > 1.5:
					_hook(tv)
			else:
				_sling_t = 0.0
		4:
			_fly_to(Vector3(position.x, _flight_ground(position), position.z), dt)
			lift_t -= dt
			if lift_t <= 0.0:
				lift_phase = 0
				var home := heli_home if heli_home and not heli_home.gone and heli_home.team == team else null
				if home and Defs.flat(home.position - position).length() > 20.0:
					lift_dest = _landing_spot(home.position)
		7:
			_fly_to(_flight_hold, dt)


# --- drones -----------------------------------------------------------------------------

## A drone circles the spot it's sent to, high up, spotting for its side (and
## the armed ones fire missiles at what they find).
func _uav_tick(dt: float) -> void:
	scan_t -= dt
	if scan_t <= 0.0:
		scan_t = 0.5
		_scan()
	var alt := float(vdef.get("alt", 20.0))
	var c := uav_dest if uav_dest != Vector3.INF else Vector3(position.x, 0, position.z)
	var rad := float(vdef.get("orbit", 16.0))
	var spd := float(vdef.speed)
	var to_c := Defs.flat(c - position)
	var want: Vector3
	if to_c.length() > rad * 1.6:
		want = c
	else:
		_orbit += dt * spd / maxf(rad, 4.0)
		want = c + Vector3(cos(_orbit), 0, sin(_orbit)) * rad
	var fl := Defs.flat(want - position)
	velocity = velocity.move_toward(fl.normalized() * minf(spd, fl.length() * 1.5), 6.0 * dt)
	position += velocity * dt
	position.y = move_toward(position.y, alt, 4.0 * dt)
	if velocity.length() > 0.3:
		rotation.y = lerp_angle(rotation.y, Defs.yaw_of(velocity), minf(1.0, 3.0 * dt))
	if _target_ok():
		turret_yaw = Defs.yaw_of(Defs.flat(target.position - position)) - rotation.y
		_fire_tick()


func _fire_cannon() -> void:
	var from := barrel_tip()
	var aim := target.center_point()
	if target is Soldier and world.terrain.in_trench(target.position) and not world.terrain.in_trench(position) and not world.trench_enfiladed(target.position, from):
		# a flat-trajectory round can't drop into a trench: it bursts on the lip
		# in front of the man, unless we're looking straight down the bay
		var to := Defs.flat(target.position - from).normalized()
		var k := 0.3
		while k < 3.0 and world.terrain.in_trench(target.position - to * k):
			k += 0.2
		aim = Vector3(target.position.x, 0.35, target.position.z) - to * (k + 0.35)
	var dist := from.distance_to(aim)
	aim += Vector3(world.rng.randf_range(-1, 1), world.rng.randf_range(-0.4, 0.4), world.rng.randf_range(-1, 1)) * dist * 0.012
	var dir := (aim - from).normalized()
	var r := world.combat.ray(from, aim + dir * 3.0, get_exclude())
	var hit_pos: Vector3 = r.position if not r.is_empty() else aim
	if hit_pos.y < 0.1:
		hit_pos.y = 0.1
	world.fx_event([Fx.CANNON, from, hit_pos, eid])
	world.stat("cannon")
	last_fire_t = world.time
	var g: Dictionary = vdef.get("gun", {})
	world.combat.explode(hit_pos, {"dmg": float(g.get("dmg", 160.0)), "radius": float(g.get("radius", 5.5)), "fling": 10.0, "at": float(g.get("at", 320.0)), "src": self, "team": team,
		"size": float(g.get("size", 1.4)), "track": 0.3, "dir": dir, "struct_mult": 2.5})


# --- damage --------------------------------------------------------------------------

func bullet_hit(p: Vector3, dir: Vector3, w: Dictionary, _shooter) -> int:
	var armor := int(vdef.armor)
	var ap: bool = w.get("ap", false)
	if armor >= 2:
		if ap:
			take_damage(3.0, null)
		if world.rng.randf() < 0.3:
			var n := Defs.flat(p - position).normalized()
			world.fx_event([Fx.RICOCHET, p, dir.bounce(n) if n.length() > 0.1 else -dir])
			world.stat("ricochet")
		return 3
	# armor 0: soft skin (pickups, trucks); 1: light armour, rifles barely scratch it
	var mult := 1.0
	if armor == 0:
		mult = 1.0 if ap else 0.35
	else:
		mult = 0.45 if ap else 0.05
	if w.get("aa", false) and is_air():
		mult = 1.6
	take_damage(float(w.dmg) * mult, _shooter)
	return 3


func explosion_hit(pos: Vector3, d: Dictionary) -> void:
	var dist := Defs.flat(position - pos).length()
	var bsize := float(d.get("size", 1.0))
	_last_blast = [pos, bsize, world.time]
	# a big blast close by shoves it bodily - a pickup a lot, a tank hardly at all
	if not is_air() and bsize >= 1.2:
		var pw := bsize * clampf(1.0 - dist / (4.0 + bsize * 3.0), 0.0, 1.0)
		if pw > 0.0:
			var away := Defs.flat(position - pos)
			away = away.normalized() if away.length() > 0.1 else Defs.dir_of(world.rng.randf() * TAU)
			knock_v += away * pw * float(_toss_class()[0])
	var at: float = d.get("at", 0.0)
	var armor := int(vdef.armor)
	var dmg := 0.0
	if at > 0.0 and dist < 4.5:
		var dir: Vector3 = d.get("dir", Defs.flat(position - pos).normalized())
		var fwd := Defs.dir_of(rotation.y)
		var facing := -Defs.flat(dir).normalized().dot(fwd)
		var mult := 1.0
		var top: bool = d.get("top", false)
		world.stat("at_hit")
		if armor >= 2 and not top:
			if facing > 0.7:
				mult = 0.6
				if world.rng.randf() < 0.25:
					world.stat("at_bounce")
					world.fx_event([Fx.RICOCHET, pos, Vector3.UP])
					world.send_msg(team, "info", "Round bounced off the %s's armour!" % display_name().to_lower())
					return
			elif facing < -0.6:
				mult = 1.35
		elif armor < 2:
			mult = 1.5
		dmg = at * mult
		var side_hit := absf(facing) < 0.6
		if base() != "supply" and not is_heli() and not is_boat() and not track_broken and world.rng.randf() < float(d.get("track", 0.3)) * (1.5 if side_hit else 1.0):
			track_broken = true
			world.stat("track_broken")
			world.fx_event([Fx.DEBRIS, position + Vector3(0, 0.5, 0), Color(0.1, 0.1, 0.1), 8])
			world.send_msg(team, "alert", "Our %s %s at %s! It's stuck until engineers repair it." % [display_name().to_lower(), "threw a track" if is_tracked() else "lost a wheel", Defs.grid_ref(position)], position)
	else:
		var r: float = float(d.get("radius", 5.0)) + 2.0
		dmg = float(d.get("dmg", 100.0)) * maxf(0.0, 1.0 - dist / r) * (0.12 if armor >= 2 else 0.8) * float(d.get("veh_mult", 1.0))
	if dmg > 0.0:
		take_damage(dmg, d.get("src"))


## A missile or rocket coming at it: armour fires its smoke dischargers - a
## wall of smoke between it and the shooter - and the crew calls it.
func threatened(from: Vector3) -> void:
	if not srv or gone or int(vdef.get("armor", 0)) < 1 or is_air() or smoke_left <= 0 or world.time < smoke_cd:
		return
	smoke_cd = world.time + 25.0
	smoke_left -= 1
	var to := Defs.flat(from - position).normalized()
	var top := position + Vector3(0, float(vdef.get("gun_h", 2.0)) + 0.3, 0)
	for i in 4:
		var dir := to.rotated(Vector3.UP, (i - 1.5) * 0.32)
		var land := position + dir * world.rng.randf_range(11.0, 16.0)
		world.spawn("projectile", {"ptype": "smoke", "team": team, "pos": top, "vel": world.combat.ballistic_vel(top, land), "thrower": eid, "fuse": 0.0})
	world.fx_event([Fx.SOUND, "launch", position])
	world.stat("veh_smoke")
	if not is_auto():
		world.send_msg(team, "info", "%s popped smoke - missile inbound!" % display_name(), position)
	VehicleBrain.on_threat(self, from)


func take_damage(amount: float, _src) -> void:
	if gone or not srv or hp <= 0.0:
		return
	if world.battle:
		world.battle.vehicle_hit(self, amount, _src)
	if OS.has_environment("FL_DEBUG_DMG"):
		print("DMG %s hp=%.0f -%.1f from %s t=%.1f" % [vkind, hp, amount, _src.display_name() if _src else "?", world.time])
	hp -= amount
	if world.time > _alert_t and not is_auto() and amount > 50.0:
		_alert_t = world.time + 20.0
		world.send_msg(team, "alert", "%s under fire at %s!" % [display_name(), Defs.grid_ref(position)], position)
	if hp <= 0.0:
		_destroyed()


func _destroyed() -> void:
	world.stat("vehicle_destroyed")
	if world.battle:
		world.battle.vehicle_destroyed(self)
	if sling_cargo != null and is_instance_valid(sling_cargo) and not sling_cargo.gone:
		var load := sling_cargo
		sling_cargo = null
		load._drop_from_sling()
	if slung_by != null and is_instance_valid(slung_by):
		slung_by.sling_cargo = null
		slung_by.sling_eid = 0
	if is_boat():
		_sink()
		return
	# whoever was inside scrambles out of the burning wreck - not all of them
	# (the men who knocked it out get the ones who don't)
	var was: Array = world.battle.blame_hit(hit_by) if world.battle else []
	for s in passengers:
		if is_instance_valid(s) and not s.gone and s.life == Soldier.Life.HIDDEN:
			s.riding = null
			s.unhide(position + Vector3(world.rng.randf_range(-2.5, 2.5), 0, world.rng.randf_range(-2.5, 2.5)))
			s.take_damage(world.rng.randf_range(30.0, 150.0), null, Vector3.UP, "explosion")
	if world.battle:
		world.battle.end_blame(was)
	passengers.clear()
	world.fx_event([Fx.EXPLODE, position + Vector3(0, 1.0, 0), 2.0])
	world.fx_event([Fx.DEBRIS, position + Vector3(0, 1.5, 0), Color(0.15, 0.15, 0.14), 16])
	for s in world.soldiers_near(position, 7.0):
		s.flinch_from(position, Defs.flat(s.position - position).length(), 7.0)
	if base() == "supply":
		world.rules.truck_lost(self)
	else:
		world.send_msg(team, "alert", "%s destroyed at %s." % [display_name(), Defs.grid_ref(position)], position)
	var wreck_kind := "rubble" if is_heli() else "wreck"
	if is_heli():
		world.send_msg(team, "alert", "%s shot down at %s!" % [display_name(), Defs.grid_ref(position)], position)
		world.send_msg(1 - team, "info", "Enemy %s shot down!" % display_name().to_lower(), position)
	var p := Vector3(position.x, 0.0, position.z)
	var y := rotation.y
	var props := {"skind": wreck_kind, "pos": p, "yaw": y, "variant": 9 if is_heli() else (6 if weight() >= 2 else 8)}
	if wreck_kind == "wreck":
		var hs := _hull_size()
		var plan := _toss_plan(p, y)
		props["vk"] = vkind
		props["size"] = Vector3(hs.x, maxf(hs.y, 1.2), hs.z)
		props["pos"] = plan[0]
		props["yaw"] = plan[1]
		props["tilt"] = plan[2]
		if (plan[3] as Vector3).length() > 0.3:
			props["toss"] = [p, y, plan[3], plan[4]]
	_bail_out(-hp)
	var w := world
	world.despawn(self)
	var wst = w.spawn("structure", props)
	if props.has("toss"):
		w.get_tree().create_timer(3.0).timeout.connect(wst.finish_toss)


## A boat going down: a blast, debris, and she founders (Vfx.sink); whoever's
## aboard swims for the nearest bank (if it's near enough to make).
func _sink() -> void:
	var shore := world.nav.nearest_walkable(position)
	var near := Defs.flat(shore - position).length() < 60.0
	for s in passengers:
		if is_instance_valid(s) and not s.gone and s.life == Soldier.Life.HIDDEN:
			s.riding = null
			s.unhide(world.nav.nearest_walkable(shore + Vector3(world.rng.randf_range(-3, 3), 0, world.rng.randf_range(-3, 3))))
			s.take_damage(world.rng.randf_range(30.0, 110.0) if near else 999.0, null, Vector3.UP, "explosion")
	passengers.clear()
	world.fx_event([Fx.EXPLODE, position + Vector3(0, 1.4, 0), 1.6 if weight() >= 2 else 1.1])  # (above the water: fire, not spray)
	world.fx_event([Fx.DEBRIS, position + Vector3(0, 1.0, 0), Color(0.3, 0.3, 0.3), 12])
	world.fx_event([Fx.SINK, eid, position])  # (she goes down on every screen that can see her)
	world.send_msg(team, "alert", "%s sunk at %s!" % [display_name(), Defs.grid_ref(position)], position)
	world.stat("boat_sunk")
	world.despawn(self)


# --- on the water --------------------------------------------------------------------------
#
# A boat isn't driven like a car: nothing grips the road. Her hull slides
# through the water, so in a turn she skids - her bow inside the circle she's
# making, her stern swinging out - and the skid costs her way. There are no
# brakes: the water's drag takes her way off, hard when she's fast and hardly
# at all once she's slow, and to stop she goes astern. Her rudder (or her
# jets) turns her only with water going past it - her own way, or the wash
# when the engines are going ahead, which is how a coxswain turns a boat lying
# stopped - and going astern she hardly steers. Engines, helm and hull all
# answer after a moment, a big hull's after a long one, so he puts the helm
# over before the turn and meets her with opposite helm as she comes round.
# A river carries her down with it.

## [thrust at full ahead (m/s²), how hard the water stops her sliding sideways
## (1/s), how long she takes to answer the helm (s), how long the engines take
## to answer the throttle (s), the helm to go hard over from amidships (s), how
## hard she'll turn at speed (m/s² sideways)]: light boats quick in all of it,
## a patrol ship slower, a deep displacement hull slowest of all
const HULL := [[2.8, 2.6, 0.35, 0.5, 0.5, 5.0], [2.0, 1.8, 0.7, 0.9, 0.8, 3.6], [0.85, 1.1, 1.5, 2.2, 1.6, 2.4]]
const HULL_DISPLACEMENT := [0.7, 0.7, 2.6, 3.0, 2.5, 1.2]

var _sway := 0.0  # how fast she's sliding sideways through the water (m/s, + to her left)
var _throttle := 0.0  # her engines as they've answered: -1 full astern .. 1 full ahead
var _rudder := 0.0  # her helm as it's answered: -1 hard right .. 1 hard left
var _current := Vector3.ZERO  # the way the water's moving where she is (a river's current)
var _current_t := 0.0
var _about := 0.0  # the way she's coming about (+1 to the left; 0: the nearer way)
var _landing := false  # under way with men aboard: they go ashore where it stops
var _grounded := false  # her last move would have put her on the bank (see _move_by)
var _rejoin_t := 0.0
var _astern := false  # going astern off the bank (see _back_off)
var _astern_t := 0.0
var _astern_from := Vector3.ZERO  # where she began
var _astern_stop := false  # backed off far enough: taking the way off her
var _tries := 0  # how many times she's gone astern to try again for...
var _tries_for := Vector3.INF  # ...this spot
var _tries_t := -INF  # (when she last did)


func _hull_k() -> Array:
	return HULL_DISPLACEMENT if vdef.get("displacement", false) else HULL[clampi(weight(), 0, 2)]


## The radius of the circle she turns in hard over, going slow: about her own
## length for a boat or a patrol ship on jets, half as much again for a
## displacement hull with one screw and a rudder.
func _turn_radius() -> float:
	return _hull_size().z * (1.6 if vdef.get("displacement", false) else (0.81 if weight() == 0 else 1.06))


## How close behind her a spot has to be for her to back into it rather than
## come about for it: closer than she'd swing out coming about - a few metres
## for an RHIB, which spins round in her own length and runs in bow first;
## fifty for a patrol ship, whose loop would be 150 m and more.
func _back_in() -> float:
	return 2.0 * _turn_radius()


## The water's drag on her at `u` m/s ahead (or astern): mostly growing with
## the square of her speed, so it takes her way off hard when she's fast and
## barely at all when she's slow (and a transom shoved through the water is
## draggier still).
func _drag(u: float) -> float:
	var x := u / float(vdef.speed)
	return float(_hull_k()[0]) * (0.8 * x * absf(x) + 0.2 * x) * (2.5 if u < 0.0 else 1.0)


## The water going past her rudder: her way through it, and the wash of her
## screws (or jets) going ahead, which counts for most when she's slow.
func _rudder_flow(u: float) -> float:
	var vmax := float(vdef.speed)
	var wash := 0.35 * vmax * maxf(_throttle, 0.0) * clampf(1.0 - u / (0.5 * vmax), 0.0, 1.0)
	return (u if u >= 0.0 else u * 0.5) + wash


## One tick of her through the water (see above): the engines and the helm
## coming round to their orders, thrust against drag, the hull skidding in a
## turn and - `carried` - the current taking her with it.
func _hull_tick(dt: float, throttle: float, helm: float, carried := true) -> void:
	var k: Array = _hull_k()
	_throttle = move_toward(_throttle, clampf(throttle, -1.0, 1.0), dt / float(k[3]))
	_rudder = move_toward(_rudder, clampf(helm, -1.0, 1.0), dt / float(k[4]))
	var u := speed
	var thrust: float = float(k[0]) * (_throttle if _throttle > 0.0 else _throttle * 0.5)
	# the helm turns her as fast as the water past it will - and at speed no
	# harder than the hull will take
	var turn := _rudder * _rudder_flow(u) / _turn_radius()
	var most: float = float(k[5]) / maxf(absf(u), 1.0)
	yaw_rate += (clampf(turn, -most, most) - yaw_rate) * (1.0 - exp(-dt / float(k[2])))
	# her way carries on as the hull swings: she skids, the water stops the
	# slide, and the slide costs her way
	u += (thrust - _drag(u) + yaw_rate * _sway) * dt
	_sway = (_sway - yaw_rate * u * dt) / (1.0 + float(k[1]) * dt)
	speed = u
	rotation.y += yaw_rate * dt
	var fwd := Defs.dir_of(rotation.y)
	var through := fwd * speed + Vector3.UP.cross(fwd) * _sway
	# (the current carries her where there's water to carry her; against the
	# bank it just holds her there)
	if carried and _current != Vector3.ZERO and world.nav.boat_ok(position + (through + _current) * dt):
		through += _current
	_move_by(through, dt)


## The coxswain: helm and engines to take her on for `to` at `want` m/s
## (stern first, going astern, if it's less than nothing). He steers by the
## way she's really going - skid, current and all - not where her bow points.
func _con(dt: float, to: Vector3, want: float) -> void:
	var astern := want < 0.0
	var me := Defs.flat(position)
	var ground := Defs.flat(velocity)
	var course := rotation.y + (PI if astern else 0.0)
	if ground.length() > 1.0 and (ground.dot(Defs.dir_of(rotation.y)) < 0.0) == astern:
		course = Defs.yaw_of(ground)
	var e := wrapf(Defs.yaw_of(to - me) - course, -PI, PI)
	var turn := 0.0  # the rate of turn he wants
	if absf(e) < PI * 0.5:
		turn = 2.0 * sin(e) * maxf(ground.length(), 1.0) / maxf(me.distance_to(to), 1.0)
	else:
		turn = (_about if _about != 0.0 and not astern else signf(e)) * 10.0  # (hard over)
	# the helm that gives her that: a touch more while she gathers the turn,
	# less - or the other way, meeting her - as she comes up to it
	var flow := _rudder_flow(speed)
	var helm := (2.0 * turn - yaw_rate) * _turn_radius() / flow if absf(flow) > 0.3 else _rudder
	# and the engines: what holds that speed against the drag, more to gather
	# way, astern to take it off
	var vmax := float(vdef.speed)
	var hold := _drag(want) / float(_hull_k()[0]) * (2.0 if astern else 1.0)
	_hull_tick(dt, hold + (want - speed) * 3.0 / vmax, helm)


## Lying to: the way taken off her with the engines - the water alone would
## let her drift on at a crawl for minutes - and her helm left where it was,
## so she carries on round the turn she was in as she slows; stopped, she
## keeps her station on her engines.
func _lie_to(dt: float) -> void:
	var throttle := 0.0
	if absf(speed) > 0.05:
		throttle = -signf(speed) * minf(1.0, absf(speed) * 3.0 / float(vdef.speed) + 0.15)
	elif _throttle == 0.0:
		speed = 0.0
	_hull_tick(dt, throttle, _rudder, absf(speed) > 1.0)


## How far down her route she looks to steer by: further the faster she's
## going and the slower she answers.
func _boat_ld() -> float:
	var k: Array = _hull_k()
	return clampf(0.8 * _hull_size().z + absf(speed) * (1.0 + float(k[2]) + float(k[4])), 8.0, 45.0)


## How fast she should be going down her route (from point i): for the bends
## ahead - looked for as far off as she'd need to slow for them, which with no
## brakes is a long way - and to stop where she's going (astern, once the
## engines have come round).
func _passage_speed(pts: PackedVector3Array, i: int) -> float:
	var k: Array = _hull_k()
	var me := Defs.flat(position)
	var stop := 0.4 * float(k[0])
	var to_end := me.distance_to(Defs.flat(pts[pts.size() - 1]))
	var v := minf(float(vdef.speed), sqrt(2.0 * stop * maxf(0.0, to_end - 2.0 - absf(speed) * float(k[3]))) + 0.4)
	var heading := rotation.y + (PI if _rev else 0.0)
	var d := 16.0
	var far := speed * speed / (2.0 * stop) + 16.0
	while d < far * 1.5 and d <= 128.0:
		var bend := absf(wrapf(Defs.yaw_of(_lookahead(pts, i, d) - me) - heading, -PI, PI))
		# (the curve through it from here - round hard over for one abaft her beam)
		var kappa := 1.0 / _turn_radius() if bend > PI * 0.5 else 2.0 * sin(bend) / d
		var v_bend := sqrt(float(k[5]) / maxf(kappa, 0.0005))
		v = minf(v, sqrt(v_bend * v_bend + 2.0 * stop * maxf(0.0, d - 16.0)))
		d *= 2.0
	return v


## On her way down her route from point path_i: past the points she's reached
## or gone by, then steering for one some way down it at the speed for the
## water ahead (and no more than `cap`). Returns the point she's got to,
## path.size() once she's there.
func _under_way(dt: float, cap := INF) -> int:
	var pts := path
	var n := pts.size()
	var i := path_i
	var me := Defs.flat(position)
	var reach := maxf(2.5, _hull_size().z * 0.2)
	while i < n - 1:
		var pi := Defs.flat(pts[i])
		var seg := Defs.flat(pts[i + 1]) - pi
		if me.distance_to(pi) < reach or (seg.length() > 0.01 and (me - pi).dot(seg) > 0.0):
			i += 1
		else:
			break
	var to_end := me.distance_to(Defs.flat(pts[n - 1]))
	if i >= n - 1 and to_end < reach and Defs.flat(velocity).length() < 0.6:
		return n
	var la := _lookahead(pts, i, _boat_ld())
	if not world.nav.boat_line(position, la):
		la = Defs.flat(pts[i])  # (where her route rounds a point of land she doesn't cut the corner over it)
	# close behind her she backs into it, rather than come about for it
	var err := wrapf(Defs.yaw_of(la - me) - rotation.y, -PI, PI)
	if not _rev and absf(err) > 2.1 and to_end < _back_in():
		_rev = true
	elif _rev and (absf(err) < 1.2 or to_end > _back_in() + 10.0):
		_rev = false
	var fwd := Defs.dir_of(rotation.y)
	var want := _passage_speed(pts, i)
	if _rev:
		want = -minf(want, float(vdef.speed) * 0.3)
	else:
		la = _avoid(la, fwd)
		want = minf(minf(minf(want, cap), _avoid_cap), _traffic_limit(fwd, want))
	_con(dt, la, want)
	return i


## Under way: down her route - on an attack, fighting at a steady speed (or
## lying to) when there's something in range. A hull with a big turning
## circle comes about the way she has the sea room for (_choose_about) and
## picks her route up further on once she's round (_rejoin); one that runs
## onto the bank goes astern off it (_back_off).
func _boat_drive(dt: float) -> void:
	position.y = WaterMap.LEVEL
	_current_t -= dt
	if _current_t <= 0.0:
		_current_t = 0.5
		_current = world.water.current_at(position) if world.water else Vector3.ZERO
	if path_i >= path.size():
		_astern = false
		_tries = 0
		_lie_to(dt)
		return
	if not passengers.is_empty():
		_landing = true
	if OS.has_environment("FL_DEBUG_BOAT") and fmod(world.time, 2.0) < dt:
		_debug_boat("")
	if _astern:
		_back_off(dt)
		return
	# on an attack she fights at a steady speed rather than stop dead for the
	# shot, as a tank would: a boat lying stopped is a sitting target, her
	# guns are stabilised, and stopping a big hull and getting her going
	# again takes the best part of a minute. But she doesn't steam away from
	# a fight: with the enemy abaft her beam she lies to and fights it out.
	var cap := INF
	if assault and _target_ok() and Defs.flat(target.position - position).length() < (70.0 if vdef.cannon else 58.0):
		var bearing := wrapf(Defs.yaw_of(Defs.flat(target.position - position)) - rotation.y, -PI, PI)
		cap = float(vdef.speed) * 0.4 if absf(bearing) < PI * 0.5 else 0.0
	# watchdog: hung up on something without touching the bank - or just not
	# quite settling where she's going (a big hull is hard to put exactly on
	# a spot: close is there)
	_stuck_t = 0.0 if cap == 0.0 else _stuck_t + dt
	if _stuck_t > 4.0:
		if Defs.flat(position - _stuck_p).length() < 1.5:
			if _near_end():
				path_i = path.size()
				return
			world.stat("boat_unstick")
			_tried_for()
			_go_astern()
			return
		_stuck_t = 0.0
		_stuck_p = position
	_rejoin_t -= dt
	if _rejoin_t <= 0.0:
		_rejoin_t = 1.0
		_rejoin()
	_choose_about()
	path_i = _under_way(dt, cap)
	if _grounded and speed > 0.5 and path_i < path.size():
		# run onto the bank: close to where she's going, that's as far in as
		# she gets, and she's there (a boat landing men runs in till she
		# touches); short of it, she doesn't sit on the sand but goes astern
		if _near_end():
			path_i = path.size()
		else:
			world.stat("boat_aground")
			if OS.has_environment("FL_DEBUG_BOAT"):
				_debug_boat(" aground")
			_tried_for()
			_go_astern()


## (FL_DEBUG_BOAT) where she is, how she's going, and how far down her route.
func _debug_boat(what: String) -> void:
	print("BOAT t=%.1f %s %d at %s heading %.2f speed %.1f sliding %.1f turning %.2f engines %.2f helm %.2f point %d/%d of a route to %s%s%s" % [
		world.time, vkind, eid, Defs.flat(position).snapped(Vector3.ONE * 0.1), wrapf(rotation.y, -PI, PI), speed, _sway, yaw_rate,
		_throttle, _rudder, path_i, path.size(), Defs.flat(path[path.size() - 1]).snapped(Vector3.ONE), " (astern)" if _astern else "", what])


## Close to where she's going: within 10 m, or most of her length for a big
## hull - and further each time she's had to go astern and try again for the
## same spot (as close in as she'll get is close enough), up to a few times
## that: further off she's still on her way, working round in narrow water.
func _near_end() -> bool:
	var end := path[path.size() - 1]
	var tries := mini(_tries, 3) if end.is_equal_approx(_tries_for) else 0
	return Defs.flat(end - position).length() < maxf(10.0, _hull_size().z * 0.6) * (1 + tries)


## Another go astern to try again for where she's going (a nudge against the
## bank a moment after the last isn't another try: she's working round).
func _tried_for() -> void:
	var end := path[path.size() - 1]
	if not end.is_equal_approx(_tries_for):
		_tries = 1
	elif world.time - _tries_t > 6.0:
		_tries += 1
	_tries_for = end
	_tries_t = world.time


## Having come about (or been pushed off her route), a hull with a big
## turning circle can find the next point of her route out of her reach:
## astern of her, or inside the circle she turns in, so that steering for it
## only takes her round again - back to where the route began. A coxswain
## picks his route up further on instead: the furthest point of it ahead of
## him, wide enough of his turning circle to make for, with open water for
## the turn onto it and the run in.
func _rejoin() -> void:
	var n := path.size()
	var me := Defs.flat(position)
	# (within as far as she looks ahead to steer, she's on her route; and
	# backing into a spot astern, there's nothing ahead to pick up)
	if path_i >= n - 1 or _rev or me.distance_to(Defs.flat(path[path_i])) < _boat_ld():
		return
	var fwd := Defs.dir_of(rotation.y)
	var r := _turn_radius()
	if _in_reach(Defs.flat(path[path_i]) - me, fwd, r):
		return
	var tries := 0
	for j in range(mini(n - 1, path_i + 24), path_i, -1):
		var rel := Defs.flat(path[j]) - me
		if rel.length() > 150.0 or not _in_reach(rel, fwd, r):
			continue
		if _can_come_round(signf(wrapf(Defs.yaw_of(rel) - rotation.y, -PI, PI)), Defs.flat(path[j]), PI):
			path_i = j
			world.stat("boat_rejoin")
			return
		tries += 1
		if tries >= 6:
			return


## Coming about for a point abaft her beam, she goes round on full lock, the
## nearer way for her course - and a big hull's turning circle is a lot of
## water. With the shore in the way of coming round that side, the coxswain
## brings her round the other way, out to sea, if that way's clear.
func _choose_about() -> void:
	var err := wrapf(Defs.yaw_of(_lookahead(path, path_i, _boat_ld()) - Defs.flat(position)) - rotation.y, -PI, PI)
	# (close behind her she backs into it instead: see _under_way)
	if absf(err) < PI * 0.5 or _rev or (absf(err) > 2.1 and Defs.flat(path[path.size() - 1] - position).length() < _back_in()):
		_about = 0.0
	elif _about == 0.0:
		# round towards her course a few turning circles on - not the point
		# she's just missed, which may lie dead astern and either way round
		var course := _lookahead(path, path_i, _turn_radius() * 3.0)
		var ce := wrapf(Defs.yaw_of(course - Defs.flat(position)) - rotation.y, -PI, PI)
		var s := signf(ce) if absf(ce) < 3.0 else signf(err)
		_about = s
		if not _can_come_round(s, course, TAU) and _can_come_round(-s, course, TAU):
			_about = -s
			world.stat("boat_about_seaward")
			if OS.has_environment("FL_DEBUG_BOAT"):
				_debug_boat(" comes about the other way, for sea room")


## Can she come round on full lock to that side (+1 left, -1 right) till
## she's pointing at `to`, and then run in to it, in open water all the way
## for her beam? (Not if she'd go round more than `most` radians first: a
## point inside her turning circle she never comes to point at.)
func _can_come_round(side: float, to: Vector3, most: float) -> bool:
	var r := _turn_radius()
	var me := Defs.flat(position)
	var c := me + Vector3.UP.cross(Defs.dir_of(rotation.y)) * side * r  # what she turns about
	var hw := _hull_size().x * 0.5
	var step := minf(4.0 / r, 0.3)  # (about 4 m of the turn at a time)
	var p := me
	var a := 0.0
	while a < most:
		var off := wrapf(Defs.yaw_of(to - p) - (rotation.y + side * a), -PI, PI)
		if absf(off) < PI * 0.5 and (absf(off) <= step or signf(off) != side):
			# round: she straightens up and runs in (the last length of it
			# may be close by the bank: that's a spot she comes alongside)
			var run := to - p
			var by := to - run.normalized() * minf(run.length(), _hull_size().z)
			return world.nav.boat_line(p, by, hw) and world.nav.boat_line(by, to)
		a += step
		var arm := (me - c).rotated(Vector3.UP, side * a)
		p = c + arm
		var out := arm.normalized() * hw
		if not world.nav.boat_ok(p) or not world.nav.boat_ok(p + out) or not world.nav.boat_ok(p - out):
			return false
	return false


## Can she steer straight for a point `rel` off her bow: ahead of her beam,
## and outside the circle she turns in on that side?
static func _in_reach(rel: Vector3, fwd: Vector3, r: float) -> bool:
	var f := rel.dot(fwd)
	var l := absf(rel.dot(fwd.cross(Vector3.UP)))
	return f > 0.0 and f * f + l * l > 2.0 * r * l


## Off the bank she has run onto, or whatever she's hung up on: astern, on
## a fresh course from where she is.
func _go_astern() -> void:
	path = world.nav.find_boat_path(position, path[path.size() - 1])
	path_i = 0
	_about = 0.0
	_astern = true
	_astern_t = 12.0
	_astern_from = position
	_astern_stop = false
	_stuck_t = 0.0
	_stuck_p = position


## Going astern, swinging her bow round towards her course as she goes: far
## enough to get clear of the bank (a fair way, for a big hull), then till
## she points near enough the way she's going to go ahead for it - or till
## her stern touches too. Then, the way off her, she plans her course again
## from there.
func _back_off(dt: float) -> void:
	_astern_t -= dt
	var r := _turn_radius()
	var aim := 0.0
	if not path.is_empty():
		aim = wrapf(Defs.yaw_of(_lookahead(path, 0, r * 2.0) - Defs.flat(position)) - rotation.y, -PI, PI)
	var backed := Defs.flat(position - _astern_from).length()
	if backed > r * 1.5 or (backed > maxf(3.0, r * 0.3) and absf(aim) < 0.7) or _astern_t <= 0.0:
		_astern_stop = true
	var vmax := float(vdef.speed)
	var want := 0.0 if _astern_stop else -vmax * 0.3
	# (going astern the helm works the other way round, and not for much)
	var flow := _rudder_flow(speed)
	var helm := clampf(aim * 2.0, -1.0, 1.0) * absf(speed) / flow if absf(flow) > 0.3 else _rudder
	_hull_tick(dt, _drag(want) / float(_hull_k()[0]) * 2.0 + (want - speed) * 3.0 / vmax, helm)
	if path.is_empty() or (_astern_stop and absf(speed) < 0.3) or (_grounded and speed < 0.0) or _astern_t < -8.0:
		_astern = false
		if not path.is_empty():
			path = world.nav.find_boat_path(position, path[path.size() - 1])
			path_i = 0
		_stuck_t = 0.0
		_stuck_p = position


## The crew - those who live through it - bail out of the hatches, burnt and
## shaken, and run for the nearest FOB to crew another (Tactics.crew_tick).
## A catastrophic kill (ammunition going up) leaves few.
func _bail_out(overkill: float) -> void:
	if is_heli() or is_auto() or base() in ["supply", "uav", "ugv", "attack_heli", "lift_heli", "boat"]:
		return
	var n: int = int(vdef.get("crew", {"tank": 3, "afv": 3, "car": 2, "spaa": 2}.get(base(), 2)))
	var p_live := 0.2 if overkill > max_hp * 0.35 else 0.6
	var sq: Squad = null
	for i in n:
		if world.rng.randf() > p_live:
			continue
		if sq == null:
			sq = world.new_squad(team, owner_peer, "crew" if team == 0 else "r_crew")
		var off := Defs.dir_of(rotation.y + PI * 0.5) * (1.7 if i % 2 == 0 else -1.7) + Defs.dir_of(rotation.y) * (i - 1) * 1.3
		var sp := world.nav.nearest_walkable(position + off)
		var s: Soldier = world.spawn("soldier", {"utype": "crewman" if team == 0 else "r_crewman", "team": team, "owner": owner_peer, "pos": sp,
			"yaw": rotation.y, "squad": sq.sid, "name": world.rules.random_name(team)})
		sq.add(s)
		s.hp = s.max_hp * world.rng.randf_range(0.35, 0.85)  # burnt, cut, concussed
	if sq == null:
		world.stat("crew_lost")
		return
	sq.order_pos = position
	sq.bt_cd["refund"] = int(float(vdef.get("cost", 0)) * 0.12 * sq.members.size() / maxf(1.0, n))
	sq.bt_cd["crew_n"] = sq.order_n
	(sq.members[0] as Soldier).say("Bail out! Bail out!" if team == 0 else "Out! Get out, it's burning!", true)
	if not is_auto():
		world.send_msg(team, "alert", "%s crew bailed out - %d of %d made it." % [display_name(), sq.members.size(), n], position)
	world.stat("crew_bailout")
	Tactics.crew_tick(sq)


## How a blast moves this kind of vehicle: [shove (m/s per unit of blast),
## launch speed range, throw speed range, chance of landing on its side or roof].
func _toss_class() -> Array:
	match weight():
		2:
			return [0.3, Vector2(0.8, 2.2), Vector2(0.2, 0.8), 0.0]
		1:
			return [0.9, Vector2(1.5, 4.5), Vector2(0.5, 2.5), 0.15]
	return [2.2, Vector2(3.0, 9.0), Vector2(2.0, 6.0), 0.45]


## Where the wreck ends up and how it gets there: [pos, yaw, tilt (pitch, roll),
## launch velocity, spin]. Killed by a blast it's thrown away from it - a pickup
## can land on its side or its roof; killed otherwise it just stops.
func _toss_plan(p: Vector3, y: float) -> Array:
	var rng := world.rng
	if _last_blast.is_empty() or world.time - float(_last_blast[2]) > 0.6:
		return [p, y, Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.04, 0.04)), Vector3.ZERO, Vector3.ZERO]
	var cls := _toss_class()
	var bp: Vector3 = _last_blast[0]
	var bsize: float = _last_blast[1]
	var away := Defs.flat(p - bp)
	var dist := away.length()
	away = away.normalized() if dist > 0.1 else Defs.dir_of(rng.randf() * TAU)
	var pw := clampf(bsize * (1.0 - dist / (5.0 + bsize * 3.0)) / 2.6, 0.12, 1.0)
	var up: float = lerpf((cls[1] as Vector2).x, (cls[1] as Vector2).y, pw)
	var out: float = lerpf((cls[2] as Vector2).x, (cls[2] as Vector2).y, pw)
	var t_air := 2.0 * up / 19.6
	var dest := p + away * out * t_air
	if not Defs.in_map(dest, 4.0) or not world.nav.walkable(dest):
		dest = p
	var pitch := rng.randf_range(-0.06, 0.06)
	var roll := rng.randf_range(-0.07, 0.07)
	var r := rng.randf()
	var flip := float(cls[3]) * pw
	if r < flip:
		roll = PI
	elif r < flip * 2.0:
		roll = PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0)
	var dyaw := rng.randf_range(-1.0, 1.0) * pw
	var axis := away.cross(Vector3.UP).normalized()
	var spin := -axis * (absf(roll) + 0.6) / maxf(t_air, 0.35) + Vector3.UP * dyaw / maxf(t_air, 0.35)
	return [dest, y + dyaw, Vector2(pitch, roll), away * out + Vector3.UP * up, spin]


## A blast close by rocks the hull on its suspension.
func blast_jolt(p: Vector3, bsize: float) -> void:
	var away := Defs.flat(position - p)
	var dist := away.length()
	var pw := bsize * clampf(1.0 - dist / (5.0 + bsize * 5.0), 0.0, 1.0) * (0.45 if weight() >= 2 else 1.0)
	if pw <= 0.0:
		return
	away = away.normalized() if dist > 0.1 else Vector3.FORWARD
	var fwd := Defs.dir_of(rotation.y)
	var side := fwd.cross(Vector3.UP)
	_sus_v += Vector3(-away.dot(fwd), -away.dot(side), 0.6) * pw * 1.6


## A gun on the turret fired (view): the turret jolts back on its ring, `k`
## metres, and settles.
func gun_kick(k: float) -> void:
	if turret:
		_gun_kick = minf(_gun_kick + k, 0.32)


## The main gun's kick rocks the hull back from the shot.
func recoil(dir: Vector3) -> void:
	var fwd := Defs.dir_of(rotation.y)
	var side := fwd.cross(Vector3.UP)
	var k := 0.9 if weight() >= 2 else 0.5
	_sus_v += Vector3(dir.dot(fwd), dir.dot(side), 0.0) * k


## Hull on springs: it squats when it pulls away, dips its nose when it stops,
## leans out of turns, pitches over trenches and craters and rocks back to level.
func _suspension(dt: float) -> void:
	if dt <= 0.0:
		return
	var fwd := Defs.dir_of(rotation.y)
	var side := fwd.cross(Vector3.UP)
	var vel := Defs.flat(position - _last_pos) / dt
	if vel.length() > 30.0:
		vel = Vector3.ZERO  # a snap correction, not driving
	_vel_s = _vel_s.lerp(vel, 1.0 - exp(-dt * 6.0))
	var acc := (_vel_s - _vel_prev) / dt
	_vel_prev = _vel_s
	var heavy := weight() >= 2 or (weight() == 1 and is_tracked())
	var kp := 0.011 if heavy else 0.02
	var tgt := Vector3(clampf(acc.dot(fwd) * kp, -0.08, 0.08), clampf(acc.dot(side) * kp * 0.9, -0.07, 0.07), 0.0)
	var hs := _hull_size()
	var hf := _ground_h(position + fwd * hs.z * 0.38)
	var hr := _ground_h(position - fwd * hs.z * 0.38)
	tgt.x += atan2(hf - hr, hs.z * 0.76)
	tgt.z += (hf + hr) * 0.5
	var spring := 55.0 if heavy else 80.0
	var damp := 8.0 if heavy else 6.5
	_sus_v += ((tgt - _sus) * spring - _sus_v * damp) * dt
	_sus += _sus_v * dt
	_sus = Vector3(clampf(_sus.x, -0.35, 0.35), clampf(_sus.y, -0.35, 0.35), clampf(_sus.z, -0.6, 0.5))
	var rumble := 0.0
	if _vel_s.length() > 1.0:
		var tt := Time.get_ticks_msec() / 1000.0
		rumble = (sin(tt * 31.0 + eid) * 0.5 + sin(tt * 47.0) * 0.5) * (0.004 if heavy else 0.006) * minf(_vel_s.length() / 6.0, 1.0)
	var sus := Transform3D(Basis.from_euler(Vector3(_sus.x + rumble, 0.0, _sus.y + rumble * 0.6)), Vector3(0, _sus.z, 0))
	var pose := (ip_offset() if srv else Transform3D.IDENTITY) * sus
	if model.transform != pose:
		model.transform = pose


## How far the ground drops under a point: into a trench, or a crater.
func _ground_h(p: Vector3) -> float:
	if world.water and world.water.on_deck(p):
		return 0.06
	if world.in_trench(p):
		return -0.3 if is_tracked() else -0.55
	return world.terrain.deform_at(p) * 0.85 if world.terrain else 0.0


# --- attack helicopter ------------------------------------------------------------------

const GS_ALT := 14.0
var gs_dest := Vector3.INF
var gs_orbit := 0.0
var rocket_t := 6.0


## Flies straight to its orders, then circles whatever it is fighting at
## 60-75 m, nose on the target: chain gun bursts and rocket salvos.
func _gunship_tick(dt: float) -> void:
	scan_t -= dt
	rocket_t -= dt
	if scan_t <= 0.0:
		scan_t = 0.4
		_scan()
	var want := Vector3(position.x, GS_ALT, position.z)
	var has_t := _target_ok()
	if has_t:
		var tp := target.position
		var to := Defs.flat(position - tp)
		var ang := atan2(to.z, to.x) + dt * 0.22
		var rad := clampf(to.length(), 60.0, 75.0)
		want = tp + Vector3(cos(ang), 0.0, sin(ang)) * rad
		if gs_dest != Vector3.INF and Defs.flat(tp - gs_dest).length() > 110.0:
			want = gs_dest
	elif gs_dest != Vector3.INF:
		want = gs_dest
	want.y = GS_ALT if hp > max_hp * 0.25 else GS_ALT * 0.7
	var face := Defs.yaw_of(Defs.flat(target.position - position)) if has_t else INF
	_fly_to(want, dt, face)
	_turret_tick(dt)
	_fire_tick()
	if has_t and rocket_t <= 0.0 and _aim_err() < 0.35:
		var dist := Defs.flat(target.position - position).length()
		var worth := target is Vehicle or target is Structure
		if target is Soldier:
			var n := 0
			for o in world.soldiers_near(target.position, 6.0):
				if o.team == target.team and o.life == Soldier.Life.ALIVE:
					n += 1
			worth = n >= 3
		if worth and dist < 100.0 and int(vdef.get("rockets", 4)) > 0:
			rocket_t = 9.0
			_rocket_salvo()


func _rocket_salvo() -> void:
	var fwd := Defs.dir_of(rotation.y)
	var side := fwd.cross(Vector3.UP)
	for i in int(vdef.get("rockets", 4)):
		var from := position + Vector3(0, 1.2, 0) + side * (1.0 if i % 2 == 0 else -1.0) * 1.1 + fwd * 1.0
		var aim: Vector3 = target.center_point() + Vector3(world.rng.randf_range(-2.5, 2.5), 0, world.rng.randf_range(-2.5, 2.5))
		var v := (aim - from).normalized() * 75.0
		world.spawn("projectile", {"ptype": "rocket", "team": team, "pos": from, "vel": v, "thrower": eid})
		world.fx_event([Fx.LAUNCH, from, v.normalized()])
	last_fire_t = world.time


# --- helicopters ------------------------------------------------------------------------

const HELI_ALT := 15.0


func _heli_tick(dt: float) -> void:
	var home := heli_home if heli_home and not heli_home.gone and heli_home.team == team else null
	match heli_phase:
		0:  # waiting on the pad, then pick the FOB that needs supply most
			_fly_to(Vector3(position.x, _flight_ground(position), position.z), dt)
			heli_t -= dt
			if heli_t > 0.0:
				return
			heli_dest = null
			var low := 1e9
			for f in world.rules.fobs(team):
				var need: float = f.supply + Defs.flat(f.position - position).length() * 0.5
				if need < low:
					low = need
					heli_dest = f
			if heli_dest == null:
				heli_t = 5.0
				return
			heli_phase = 1
		1, 4:  # climb
			if _fly_to(Vector3(position.x, HELI_ALT, position.z), dt):
				heli_phase += 1
		2, 5:  # cruise
			var goal: Vector3
			if heli_phase == 2:
				if heli_dest == null or heli_dest.gone or heli_dest.team != team:
					heli_phase = 5
					return
				goal = heli_dest.position + Vector3(9.0, 0, 0)
			else:
				goal = home.position if home else world.rules.depots[team].position + Vector3(0, 0, -12)
			goal.y = HELI_ALT
			if _fly_to(goal, dt):
				_flight_hold = Vector3(goal.x, _flight_ground(goal), goal.z)
				heli_phase += 1
		3, 6:  # land
			_flight_hold.y = _flight_ground(_flight_hold)
			if _fly_to(_flight_hold, dt):
				if heli_phase == 3:
					heli_t = 3.0
					heli_phase = 7
				else:
					heli_phase = 0
					heli_t = 12.0
		7:  # unloading
			_flight_hold.y = _flight_ground(_flight_hold)
			_fly_to(_flight_hold, dt)
			heli_t -= dt
			if heli_t <= 0.0:
				if heli_dest and not heli_dest.gone and heli_dest.team == team:
					var load := int(vdef.get("load", 80))
					heli_dest.supply += load
					heli_dest.net_dirty = true
					world.fx_event([Fx.DELIVER, heli_dest.position + Vector3(0, 4, 0), load, team])
					world.stat("heli_delivered")
					world.rules.note_income(team, load)
				heli_phase = 4


# --- trucks ---------------------------------------------------------------------------

func _truck_tick(dt: float) -> void:
	if route_i >= route.size():
		if not returning:
			world.rules.truck_arrived(self)
			returning = true
			route.reverse()
			route_i = 1
			speed = 0.0
			return
		world.rules.truck_home(self)
		return
	var tgt := route[route_i]
	if _road_blocked():
		blocked_t += dt
		speed = 0.0
		velocity = Vector3.ZERO
		if blocked_t > 5.0:
			world.rules.truck_blocked(self)
		return
	blocked_t = 0.0
	route_i = _follow(route, route_i, dt, float(vdef.speed), false, 1.6)


func _road_blocked() -> bool:
	if route.size() < 2:
		return false
	# down the road, not out of the windscreen (it may be swinging round to
	# turn back), and not among its own base's buildings at either end
	var nxt := route[clampi(route_i, 0, route.size() - 1)]
	if Defs.flat(route[route.size() - 1] - position).length() < 14.0 or Defs.flat(route[0] - position).length() < 14.0:
		return false
	var dir := Defs.flat(nxt - position)
	var ahead := position + (dir.normalized() if dir.length() > 0.5 else Defs.dir_of(rotation.y)) * 4.0
	for st in world.structures_near(ahead, 3.0):
		if st.team < 0 or st.gone or st.team == team:
			continue  # (its own side's buildings by the road don't stop it: the enemy's roadblocks do)
		if st.skind in ["tank_trap", "concrete_wall", "hesco", "ammo_cache", "barracks", "factory", "research", "medic_tent"] and Defs.flat(st.position - ahead).length() < st.radius + 1.5:
			return true
	for v in world.vehicles_near(ahead, 3.0):
		if v != self and v.team != team:
			return true
	return false


# --- replication -------------------------------------------------------------------------

func write_state(b: StreamPeerBuffer) -> void:
	put_v3(b, position)
	put_ang(b, rotation.y)
	put_ang(b, turret_yaw)
	b.put_u8(int(clampf(hp / maxf(1.0, max_hp), 0.0, 1.0) * 255.0))
	b.put_u8(flags)
	b.put_u8(vis_mask)
	b.put_8(team)
	b.put_u32(sling_eid)
	put_ang(b, flight_pitch)
	put_ang(b, flight_roll)


func read_state(b: StreamPeerBuffer) -> void:
	net_pos = get_v3(b)
	net_yaw = get_ang(b)
	turret_yaw = lerp_angle(turret_yaw, get_ang(b), 0.5)
	hp_frac = b.get_u8() / 255.0
	flags = b.get_u8()
	vis_mask = b.get_u8()
	team = b.get_8()
	sling_eid = b.get_u32()
	flight_pitch = wrapf(get_ang(b), -PI, PI)
	flight_roll = wrapf(get_ang(b), -PI, PI)


func health_frac() -> float:
	return clampf(hp / maxf(1.0, max_hp), 0.0, 1.0) if srv else hp_frac


# --- view --------------------------------------------------------------------------------

func _process(dt: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_view_process(dt)
	if world:
		world.vp("vehicles", _t0)


func _view_process(dt: float) -> void:
	if not world.has_view or model == null:
		return
	if not srv:
		net_smooth(dt)
	var v := seen_by_local()
	if v != _vis:
		visible = v
		_vis = v
	if turret:
		var facing := turret.rotation
		facing.y = turret_yaw
		if turret.rotation != facing:
			turret.rotation = facing
		if _gun_kick > 0.0:
			if _turret_rest == Vector3.INF:
				_turret_rest = turret.position
			# slammed back by the shot, then run out again over half a second
			_gun_kick = maxf(0.0, _gun_kick * exp(-dt * 7.0) - dt * 0.01)
			turret.position = _turret_rest + Basis(Vector3.UP, turret_yaw) * Vector3(0, 0, _gun_kick)
	if _vm and _vm.elev:
		# laid for indirect fire: the barrel (or the launcher) goes up
		var want_e := float(vdef.get("elev", 0.6)) if (flags & F_ELEV) != 0 else 0.0
		_elev_v = move_toward(_elev_v, want_e, dt * 0.5)
		var elevation := _vm.elev.rotation
		elevation.x = _elev_v
		if _vm.elev.rotation != elevation:
			_vm.elev.rotation = elevation
	if rotor:
		var want := 30.0 if position.y > 0.3 or (flags & F_FIRE) != 0 else (9.0 if (flags & F_GROUND) == 0 or base() != "lift_heli" else 14.0)
		_rotor_spd = move_toward(_rotor_spd, want, dt * 12.0)
		rotor.rotation.y += dt * _rotor_spd
		if tail_rotor:
			tail_rotor.rotation.x += dt * _rotor_spd * 2.6
		for i in _vm.rotors.size():
			var xr: Node3D = _vm.rotors[i]
			xr.rotation.y += dt * _rotor_spd * (-1.0 if i % 2 == 0 else 1.0)
			var xb := xr.get_node_or_null("Blur")
			if xb:
				xb.visible = _rotor_spd > 18.0
				var xbl := xr.get_node_or_null("Blades")
				if xbl:
					xbl.visible = not xb.visible
		if blur:
			var fast := _rotor_spd > 18.0
			blur.visible = fast
			blades.visible = not fast
	if not rotor and _vm and not _vm.rotors.is_empty():
		for i in _vm.rotors.size():
			(_vm.rotors[i] as Node3D).rotation.y += dt * 30.0 * (-1.0 if i % 2 == 0 else 1.0)
	if flight and model and dt > 0.0:
		model.rotation.x = lerp_angle(model.rotation.x, flight_pitch, 1.0 - exp(-dt * 10.0))
		model.rotation.z = lerp_angle(model.rotation.z, flight_roll, 1.0 - exp(-dt * 10.0))
	elif rotor and model and dt > 0.0:
		# Rotary drones keep their own orbit guidance and view treatment.
		var mv2 := position - _last_pos
		var fs := mv2.dot(Defs.dir_of(rotation.y)) / dt
		var ss := mv2.dot(Defs.dir_of(rotation.y).cross(Vector3.UP)) / dt
		model.rotation.x = lerpf(model.rotation.x, clampf(-fs * 0.012, -0.3, 0.3), 1.0 - exp(-dt * 3.0))
		model.rotation.z = lerpf(model.rotation.z, clampf(ss * 0.012, -0.3, 0.3), 1.0 - exp(-dt * 3.0))
	if dust and dt > 0.0:
		var spd2 := Defs.flat(position - _last_pos).length() / dt
		var want_dust := spd2 > 2.0
		if want_dust != Vfx.is_emitting(dust):
			Vfx.set_emitting(dust, want_dust)
	if is_boat() and model:
		_boat_view(dt)
	elif not rotor and not flight and model:
		_suspension(dt)
	if not wheels.is_empty():
		var mv := position - _last_pos
		var fwd := Defs.dir_of(rotation.y)
		var spd := mv.dot(fwd)
		if spd != 0.0 and absf(spd) < 2.0:
			for w in wheels:
				w.rotation.x -= spd / 0.42
		_steer_wheels(dt, spd)
	_last_pos = position
	if burner:
		var hf := health_frac()
		var st := 0
		if hf < 0.2:
			st = 3
		elif hf < 0.4:
			st = 2
		elif (flags & F_TRACK) != 0 or hf < 0.6:
			st = 1
		if st != _burn_state:
			_burn_state = st
			world.fx.vfx.set_burning(burner, [0.0, 0.0, 0.0, 0.8][st], [0.0, 0.25, 0.6, 1.0][st])
	_sling_view()
	if ring:
		ring.visible = selected
		if selected and position.y > 0.5:
			ring.global_position = Vector3(position.x, 0.06, position.z)


var _cables: MeshInstance3D


## (view) Four strops from the load's corners up to a hook, a cable from the
## hook to the belly of the helicopter.
func _sling_view() -> void:
	var v = world.entity(sling_eid) if sling_eid != 0 else null
	if v == null or not (v is Vehicle) or not visible:
		if _cables:
			_cables.visible = false
		return
	if _cables == null:
		_cables = MeshInstance3D.new()
		_cables.mesh = ImmediateMesh.new()
		_cables.top_level = true
		_cables.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.08, 0.08, 0.08)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cables.material_override = m
		add_child(_cables)
	_cables.visible = true
	_cables.global_transform = Transform3D.IDENTITY
	var im: ImmediateMesh = _cables.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var belly: Vector3 = global_position + Vector3(0, -0.6, 0)
	var hs: Vector3 = v._hull_size()
	var top: Vector3 = v.global_position + Vector3(0, hs.y, 0)
	var hook: Vector3 = top + Vector3(0, 2.4, 0)
	im.surface_add_vertex(belly)
	im.surface_add_vertex(hook)
	var b := Basis(Vector3.UP, v.rotation.y)
	for c in [Vector3(hs.x * 0.4, 0, hs.z * 0.38), Vector3(-hs.x * 0.4, 0, hs.z * 0.38), Vector3(hs.x * 0.4, 0, -hs.z * 0.38), Vector3(-hs.x * 0.4, 0, -hs.z * 0.38)]:
		im.surface_add_vertex(hook)
		im.surface_add_vertex(top + b * c)
	im.surface_end()


var spray: GeometryInstance3D
var _ride := Vector3.ZERO  # (view) how the swell has her: heave, pitch, roll


## (view) Afloat: sitting at her draft and riding the swell the player sees
## (see WaterView.height_at) - the bow lifting to each wave, rolling as it
## passes under - the bow coming up as she gets on the plane, heeling into her
## turns; a wake astern, spray off the bow when she's going hard.
func _boat_view(dt: float) -> void:
	var t := world.time + float(eid % 23) * 0.7
	var vmax := maxf(1.0, float(vdef.speed))
	var sp := velocity.length() if srv else (Defs.flat(position - _last_pos).length() / maxf(dt, 0.001))
	var k := clampf(sp / vmax, 0.0, 1.0)
	var light := 1.0 if weight() == 0 else (0.6 if weight() == 1 else 0.25)
	var hs := _hull_size()
	var fwd := Defs.dir_of(rotation.y)
	var side := fwd.cross(Vector3.UP)
	var wv: WaterView = world.atmo.water_view if world.atmo else null
	var ride := Vector3.ZERO
	if wv:
		var hb := wv.height_at(position + fwd * hs.z * 0.4)
		var ha := wv.height_at(position - fwd * hs.z * 0.4)
		var hp := wv.height_at(position - side * hs.x * 0.45)
		var hsb := wv.height_at(position + side * hs.x * 0.45)
		ride = Vector3((hb + ha + hp + hsb) * 0.25, atan2(hb - ha, hs.z * 0.8), atan2(hsb - hp, hs.x * 0.9))
	# (a heavy hull answers the waves slowly)
	_ride = _ride.lerp(ride, 1.0 - exp(-dt * (6.0 if weight() == 0 else (4.0 if weight() == 1 else 2.2))))
	var bob := 0.025 * sin(t * 1.25) * (1.6 - light * 0.6)  # (still water: the odd ripple)
	model.position.y = -float(vdef.get("draft", 0.4)) + _ride.x + bob + k * 0.12 * light
	model.rotation.x = lerpf(model.rotation.x, _ride.y + k * 0.08 * light + 0.01 * sin(t * 0.9), 1.0 - exp(-dt * 4.0))
	var yr := wrapf(rotation.y - _last_yaw, -PI, PI) / maxf(dt, 0.001)
	_last_yaw = rotation.y
	# a planing hull banks into a turn; a deep displacement hull heels out of it
	var heel := yr * k * 0.35 * light * (-0.6 if vdef.get("displacement", false) else 1.0)
	model.rotation.z = lerpf(model.rotation.z, _ride.z + clampf(heel, -0.25, 0.25) + 0.012 * sin(t * 0.7), 1.0 - exp(-dt * 3.0))
	if wv:
		var lv := Vector3(position.x, WaterMap.LEVEL, position.z)
		wv.wake(eid, lv - fwd * hs.z * 0.46, lv + fwd * hs.z * 0.42, hs.x * 0.5, sp, k, visible)
	# spray thrown off the bows of a light boat going hard
	if spray == null and weight() < 2 and world.fx and world.fx.vfx:
		spray = world.fx.vfx.make_spray(clampf(hs.x / 2.6, 0.8, 1.4))
		spray.position = Vector3(0, -position.y + WaterMap.LEVEL + 0.15, -hs.z * 0.22)
		add_child(spray)
	if spray:
		var on := k > 0.45 and visible
		if on != Vfx.is_emitting(spray):
			Vfx.set_emitting(spray, on)


## (view) She's going down: her model (and her fire) go to the effects to
## sink (see Vfx.sink), and the vehicle itself is left to be cleared away.
func sink_view() -> void:
	if model == null or world.fx == null or world.fx.vfx == null:
		return
	var m := model
	model = null
	remove_child(m)
	var b := burner
	burner = null
	if b:
		remove_child(b)
	if spray:
		Vfx.set_emitting(spray, false)
	world.fx.vfx.sink(m, b, transform, _hull_size())


var _vm: VehicleModels = null
var _steer_k: Array = []  # per wheel: how much of the steering it takes (front axles)
var _steer_v := 0.0
var _last_yaw := 0.0


## Front wheels turn into the bend (wheeled vehicles), from how fast it's
## turning for how fast it's going.
func _steer_wheels(dt: float, step: float) -> void:
	if is_tracked() or is_air() or dt <= 0.0:
		return
	if _steer_k.size() != wheels.size():
		_steer_k.clear()
		var wb := _wheelbase()
		var inv := global_transform.affine_inverse()
		for w in wheels:
			var lz: float = (inv * (w as Node3D).global_position).z if (w as Node3D).is_inside_tree() else 0.0
			_steer_k.append(clampf((-lz - wb * 0.1) / (wb * 0.4), 0.0, 1.0))
	var yr := wrapf(rotation.y - _last_yaw, -PI, PI) / dt
	_last_yaw = rotation.y
	var v := absf(step) / dt
	var want := 0.0
	if v > 0.4:
		want = clampf(atan(yr * _wheelbase() / v) * signf(step), -_max_steer(), _max_steer())
	_steer_v = lerpf(_steer_v, want, 1.0 - exp(-dt * 8.0))
	for i in wheels.size():
		var k: float = _steer_k[i]
		if k > 0.0:
			var wheel := wheels[i] as Node3D
			var facing := wheel.rotation
			facing.y = _steer_v * k
			if wheel.rotation != facing:
				wheel.rotation = facing


## Where a shot leaves this vehicle's model right now (view): the tip of the
## machine gun, or of the main gun. INF when there's no model to ask.
func muzzle_world(main_gun := false) -> Vector3:
	if _vm == null or model == null or not model.is_visible_in_tree():
		return Vector3.INF
	var tip: Node3D = _vm.gun_tip if main_gun else _vm.mg_tip
	return tip.global_position if tip else Vector3.INF


func _build_model() -> void:
	var tc: Color = Defs.TEAM_COLORS[team] if team >= 0 else Color.WHITE
	var k := VehicleModels.build(vkind, team, eid)
	model = k.root
	add_child(model)
	turret = k.turret
	_vm = k
	rotor = k.rotor
	tail_rotor = k.tail_rotor
	blades = k.blades
	blur = k.blur
	wheels = k.wheels
	if rotor:
		add_child(Sfx.make_loop_player("rotor", 18.0, 0.0 if base() == "attack_heli" else -3.0))
	elif is_boat():
		pass  # (a wake, not dust: see _boat_view)
	elif world.fx and world.fx.vfx:
		dust = world.fx.vfx.make_dust(1.3 if weight() >= 2 else 1.0)
		dust.position = Vector3(0, 0.2, _hull_size().z * 0.5)
		add_child(dust)
	if world.fx and world.fx.vfx:
		burner = world.fx.vfx.make_burner(1.0 if weight() >= 2 else 0.7)
		burner.position = Vector3(0, 1.6, 1.2) if base() != "lift_heli" else Vector3(0, 2.3, 0.6)
		add_child(burner)
	var hs := _hull_size()
	ring = Res.mi(self, Res.plane(maxf(hs.x, hs.z) * 1.22), Res.ring_mat(tc), Vector3(0, 0.06, 0), Vector3.ZERO, false)
	ring.visible = false
