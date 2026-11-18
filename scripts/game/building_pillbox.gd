class_name BuildingPillbox
extends RefCounted

## The Coalition's concrete bunker, dressed as a cast-in-place pillbox: a roof
## slab thick enough to stop a mortar round, stepped out over the walls to
## throw the rain clear; a hood over every firing slit to shade it and turn
## rounds off, a sill sloped to drain and cheeks splayed at its ends; on the
## roof a parapet of bags along the front, the escape hatch, a periscope, a
## vent cowl; spouts at the back with the rain's streaks under them. The walls
## themselves are the structure's parts (they're what stops the bullets).

const STEEL := Color(0.2, 0.2, 0.19)
const OLIVE := Color(0.3, 0.32, 0.25)
const ARMY_PAINT := "wire_military"  # (the army's dull olive on steel: nothing to catch the light)
const SLAB_TOP := 2.82  # the roof slab's top, over the parts' roof (2.2 to 2.56)
## How the dugout's mound of earth (WorksModels.roof_soil) is laid on the slab
## as a burst layer of turf: drawn in, so the slab's lip shows round it, and thin.
const TURF := Vector3(0.86, 0.42, 0.86)


## How deep the turf is on the slab at `p` (x, z) for that mound `variant`.
static func turf_depth(p: Vector2, variant: int) -> float:
	return maxf(0.0, WorksModels.roof_soil_height(Vector2(p.x / TURF.x, p.y / TURF.z), variant) * TURF.y)


## An embrasure, `k` on the wall's outer face at the ground (x along the wall,
## z out of it): a slit `length` long from `sill` to `head` high.
static func embrasure(k: BuildingKit, length: float, col: Color, sill := 1.1, head := 1.65) -> void:
	var w := length + 0.34
	# the hood: cast with the wall, its lip a little lower than its root
	k.box(Vector3(w, 0.13, 0.38), Vector3(0, head + 0.14, 0.17), "precast", col, Vector3(0.1, 0, 0))
	# the sill, sloped out and down to drain (and to throw a round off downwards)
	k.box(Vector3(w, 0.1, 0.3), Vector3(0, sill - 0.08, 0.12), "precast", col.darkened(0.05), Vector3(0.3, 0, 0))
	# the cheeks, splayed so the gunner can traverse
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.12, head - sill + 0.16, 0.3), Vector3(sx * (length * 0.5 + 0.1), (sill + head) * 0.5, 0.12), "precast", col, Vector3(0, sx * 0.45, 0))
	# steel angle cast in round the opening
	for y: float in [sill, head]:
		k.box(Vector3(length + 0.1, 0.07, 0.1), Vector3(0, y, 0.03), "metal_dark", STEEL)


## The roof, `k` at the bunker's middle on the ground: the slab and what's on
## it, through or on the turf of mound `variant` (the structure lays the turf).
## Bag rows for the parapet go into `bags` (the structure lays them too).
static func roof(k: BuildingKit, col: Color, variant: int, rng: RandomNumberGenerator, bags: Array) -> void:
	var y := SLAB_TOP
	k.box(Vector3(6.2, 0.26, 6.2), Vector3(0, y - 0.13, 0), "precast", col)
	# the parapet: two bags high along the front at the slab's lip, a row
	# behind it on the turf, and down the front half of each side
	bags.append({"p": Vector3(0, y + 0.12, -2.72), "s": Vector3(5.8, 0.24, 0.48), "r": rng.randf_range(-0.01, 0.01)})
	bags.append({"p": Vector3(0, y + 0.36, -2.72), "s": Vector3(5.3, 0.24, 0.48), "r": rng.randf_range(-0.01, 0.01)})
	bags.append({"p": Vector3(0, y + turf_depth(Vector2(0, -2.24), variant) + 0.1, -2.24), "s": Vector3(5.0, 0.24, 0.48), "r": 0.0})
	for sx: float in [-1.0, 1.0]:
		bags.append({"p": Vector3(sx * 2.72, y + 0.12, -0.95), "s": Vector3(2.1, 0.24, 0.48), "r": PI * 0.5})
	# the escape hatch: a steel lid on a kerb standing clear of the turf, a bar
	# to lift it by
	var hatch := Vector3(1.35, y, 1.3)
	var kerb := turf_depth(Vector2(hatch.x, hatch.z), variant) + 0.1
	k.box(Vector3(1.0, kerb, 1.0), hatch + Vector3(0, kerb * 0.5, 0), "precast", col.darkened(0.06))
	k.box(Vector3(0.8, 0.04, 0.8), hatch + Vector3(0, kerb + 0.02, 0), "fence_metal", OLIVE.darkened(0.2))
	k.box(Vector3(0.36, 0.03, 0.03), hatch + Vector3(0, kerb + 0.07, 0.25), "metal_dark", STEEL)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.03, 0.05, 0.03), hatch + Vector3(sx * 0.17, kerb + 0.045, 0.25), "metal_dark", STEEL)
	# the periscope up through the slab behind the parapet, its window to the front
	var scope := Vector3(-1.2, y, -1.75)
	var up := turf_depth(Vector2(scope.x, scope.z), variant) + 0.5
	k.cyl(0.06, 0.06, up, scope + Vector3(0, up * 0.5, 0), ARMY_PAINT, OLIVE)
	k.box(Vector3(0.18, 0.15, 0.24), scope + Vector3(0, up + 0.06, -0.02), ARMY_PAINT, OLIVE)
	k.plate(Vector3(0.13, 0.07, 0.01), scope + Vector3(0, up + 0.07, -0.145), "glass", Color(0.12, 0.14, 0.14))
	# the vent: a mushroom cowl over the fresh-air shaft
	var vent := Vector3(1.9, y, -0.3)
	var stalk := turf_depth(Vector2(vent.x, vent.z), variant) + 0.4
	k.cyl(0.1, 0.1, stalk, vent + Vector3(0, stalk * 0.5, 0), "metal_dark", STEEL)
	k.cyl(0.04, 0.22, 0.12, vent + Vector3(0, stalk + 0.06, 0), "metal_dark", STEEL)
	# rain off the roof: spouts at the back, where it falls away from the slits
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(0.1, 0.08, 0.4), Vector3(sx * 2.05, 2.62, 3.15), "metal_dark", STEEL)


## Where the rain has run down a wall from the slab above: a dark streak at
## each of `xs` along the face, `k` on the wall's outer face (x along it, z
## out), from the slab's underside down `reach` (a range) and as dark as
## `strength` (a range): long and dark under the spouts, faint where the
## drips come off the drip edge.
static func streaks(k: BuildingKit, xs: Array, reach: Vector2, strength: Vector2, tone: Callable, rng: RandomNumberGenerator) -> void:
	for x: float in xs:
		var length := rng.randf_range(reach.x, reach.y)
		var sw := rng.randf_range(0.3, 0.45)
		var dark := rng.randf_range(strength.x, strength.y)
		var cx := x + rng.randf_range(-0.08, 0.08)
		BuildingWeathering.stain(k, Rect2(cx - sw * 0.5, 2.2 - length, sw, length), "precast", tone, Color(0.42, 0.42, 0.4), func(u: float, v: float) -> float:
			var across := 1.0 - absf(u * 2.0 - 1.0)
			return across * pow(v, 0.6) * dark, 4, 6, 7)
