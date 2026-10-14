class_name VmCiv
extends RefCounted
## Procedural models: FIA, Syndikat and civilian ground vehicles (Offroad, MB 4WD, Truck, Van, Quadbike, Hatchback, SUV, Kart, Tractor, ED-1 mini UGV).
## Conventions as in VehicleModels: local -Z is forward, y = 0 is the ground,
## metres; parts via k._add / k._box / k._cyl, lofted solids via
## VehicleModels.loft / extrude_x / solid (cache keys must be unique per shape).

## Every model key this file builds (the Field Manual's model pages list them).
const KEYS: Array[String] = []


## Builds the model for `key` into k; false if this file doesn't know it.
static func build(k: VehicleModels, key: String, team: int, seed: int) -> bool:
	match key:
		"":
			pass
	return false
