class_name VehicleMotion
extends RefCounted
## Field handling, not catalogue road speeds. Distances in metres, angular
## values in degrees here so crews' very different drives remain easy to tune.
## [traverse deg/s, traverse accel deg/s², hull deg/s, hull accel deg/s²,
##  acceleration m/s², brakes m/s², lateral grip m/s², reverse fraction]
const PROFILES := {
	"tank": [40.0, 55.0, 30.0, 35.0, 1.2, 4.0, 2.2, 0.32],
	"old_tank": [16.0, 24.0, 22.0, 24.0, 0.85, 3.4, 1.9, 0.22],
	"afv": [45.0, 75.0, 38.0, 55.0, 1.9, 5.0, 3.0, 0.35],
	"light_tracked": [40.0, 65.0, 48.0, 75.0, 2.2, 5.0, 3.0, 0.35],
	"car": [55.0, 90.0, 55.0, 90.0, 3.0, 6.5, 4.0, 0.4],
	"manual": [35.0, 65.0, 50.0, 75.0, 2.6, 6.0, 3.5, 0.35],
	"spaa": [75.0, 120.0, 38.0, 55.0, 1.9, 5.0, 3.0, 0.35],
	"arty": [10.0, 15.0, 26.0, 30.0, 1.1, 3.8, 2.0, 0.28],
	"util": [45.0, 70.0, 35.0, 45.0, 1.1, 4.0, 2.2, 0.25],
	"boat": [45.0, 65.0, 25.0, 30.0, 1.2, 3.0, 2.0, 0.3],
	"attack_heli": [60.0, 100.0, 40.0, 55.0, 5.0, 6.0, 3.0, 0.3],
	"lift_heli": [40.0, 65.0, 28.0, 35.0, 3.8, 5.0, 3.0, 0.3],
	"heavy_heli": [35.0, 55.0, 20.0, 25.0, 2.8, 4.0, 3.0, 0.3],
	"uav": [50.0, 80.0, 45.0, 65.0, 4.0, 5.0, 3.0, 0.3],
}
# Model-specific drives: older hydraulic tanks do not acquire like modern MBTs.
const OVERRIDES := {
	"old_tank": [16.0, 24.0], "varsuk": [30.0, 42.0],
	"slammer": [36.0, 48.0], "slammer_up": [34.0, 45.0], "kuma": [40.0, 55.0],
	"mora": [32.0, 48.0], "btr": [30.0, 50.0], "kamysh": [45.0, 70.0], "angara": [38.0, 52.0], "angara_k": [36.0, 48.0],
	"futura": [42.0, 60.0], "rhino": [28.0, 40.0], "rhino_up": [26.0, 38.0],
}

static func profile(kind: String, definition: Dictionary) -> Dictionary:
	var family := String(definition.get("base", kind))
	if kind == "old_tank":
		family = "old_tank"
	elif kind in ["technical", "aa_tech", "offroad_hmg", "offroad_at", "prowler_hmg", "qilin_mg", "mb4wd_lmg", "mb4wd_at", "gun_trawler"]:
		family = "manual"
	elif family == "lift_heli" and (int(definition.get("sling", -1)) >= 2 or float(definition.get("size", Vector3.ZERO).z) > 15.0):
		family = "heavy_heli"
	elif definition.get("tracked", false) and int(definition.get("weight", 1)) == 0:
		family = "light_tracked"
	elif family == "supply":
		family = "util"
	var p: Array = PROFILES.get(family, PROFILES.car)
	var drive: Array = OVERRIDES.get(kind, [p[0], p[1]])
	return {"traverse": deg_to_rad(float(drive[0])), "traverse_accel": deg_to_rad(float(drive[1])),
		"hull_turn": deg_to_rad(float(p[2])), "hull_accel": deg_to_rad(float(p[3])),
		"handling": [p[4], p[5], p[6], p[7]]}


## Motor accelerates, brakes before the bearing, and takes the shortest arc.
## Returns [angle, angular velocity]; neither depends on rendering or wall time.
static func slew(angle: float, velocity: float, wanted: float, rate: float, accel: float, dt: float, shortest_arc := true) -> Vector2:
	var error := wrapf(wanted - angle, -PI, PI) if shortest_arc else wanted - angle
	var demand := signf(error) * minf(rate, maxf(0.0, sqrt(2.0 * accel * absf(error)) - accel * dt))
	velocity = move_toward(velocity, demand, accel * dt)
	var step := velocity * dt
	if signf(step) == signf(error) and absf(step) >= absf(error):
		step = error
		velocity = 0.0
	return Vector2(wrapf(angle + step, -PI, PI), velocity)
