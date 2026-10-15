class_name VmAttack
extends RefCounted
## Procedural models: ground-attack jets - the A-10 and the A-164 Wipeout.
## Conventions as in VmPlane (read its header): local -Z is forward, y = 0 is
## the ground, metres; built in flight with the gear up, round the fuselage.
## Landing gear goes under a child Node3D named "Gear", hidden by default (the
## Field Manual and the model sheets show it, standing the aircraft on it).

## Every model key this file builds.
const KEYS: Array[String] = ["a10", "wipeout"]


## Builds the model for `key` into k; false if this file doesn't (yet) know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	return false
