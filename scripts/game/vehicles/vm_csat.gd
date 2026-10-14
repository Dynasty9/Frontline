class_name VmCsat
extends RefCounted
## Procedural models: CSAT ground vehicles (Ifrit, Qilin, Marid, Kamysh, Varsuk, Futura, Angara, Tigris, Sochor, Tempest).
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
