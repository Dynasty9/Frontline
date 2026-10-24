class_name ImpactResponse
extends RefCounted
## A critically damped spring for flesh and suspension. Impacts add velocity;
## the exact solution stays stable when distant units are posed less often.

var offset := Vector3.ZERO
var velocity := Vector3.ZERO


func kick(impulse: Vector3, limit := 3.0) -> void:
	velocity = (velocity + impulse).limit_length(limit)


func step(dt: float, frequency := 12.0) -> Vector3:
	var t := maxf(dt, 0.0)
	var j := velocity + offset * frequency
	var decay := exp(-frequency * t)
	offset = (offset + j * t) * decay
	velocity = (velocity - j * frequency * t) * decay
	return offset


## The event supplies a change in velocity, not an impulse in newton-seconds.
## Preserve travel velocity on every limb, then apply the hit to the torso.
static func death_velocity(travel: Vector3, hit: Vector3, kind: int, part: String) -> Vector3:
	if kind == 2:
		return travel
	if kind == 1:
		return travel + hit
	return travel + hit * (1.0 if part == "torso" else 0.15)
