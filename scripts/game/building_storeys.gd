class_name BuildingStoreys
extends RefCounted
## The floor a house has over its ground floor. The ground floor is its walls
## (Structure "house_wall", each a piece of cover men fight from); the storey
## above is looks only, drawn with the house's roof (Structure "roof", its
## eaves that much higher), so it lifts off with the roof when men go in, and
## comes down with it when a wall under it is knocked out (Structure
## _bring_down_floors). Work in the house's own frame: x by z centred on it,
## y up from the ground floor's foot.

## Floor to floor.
const STOREY := 2.8
## The ground floor's height: where a storey over it starts.
const GROUND := 3.0
## A window up there: its size, and its sill over the floor.
const WINDOW := Vector2(1.1, 1.25)
const SILL := 0.85


## The storey over a ground floor `L` by `W`, from `y0` up to `y1`, in the
## house's `material` and colour, its woodwork `trim`: the floor slab (the
## ceiling of the rooms under it), walls on the ground floor's lines with
## windows in most bays, a string course at the floor and a band under the
## eaves. Curtains as the house hangs them; a lamp on in some rooms, unless
## the house is dark (`lamps` false: hit, or a ruin). True if a lamp is lit.
static func upper(k: BuildingKit, L: float, W: float, y0: float, y1: float, material: String, col: Color, trim: Color, rng: RandomNumberGenerator, lamps := true) -> bool:
	var h := y1 - y0
	k.box(Vector3(L - 0.4, 0.22, W - 0.4), Vector3(0, y0 - 0.1, 0), "plaster", Color(0.8, 0.78, 0.74))
	var lit := false
	var curtains: String = ["drapes", "drapes", "blind", "nets", ""][rng.randi() % 5]
	var fabric: Color = BuildingFurnishings.FABRICS[rng.randi() % BuildingFurnishings.FABRICS.size()]
	# (the long walls run across the corners, the ends fit between them, as
	# the walls under them are laid)
	var sides := [[Vector3(0, y0, -(W * 0.5 + 0.2)), PI, L], [Vector3(0, y0, W * 0.5 + 0.2), 0.0, L],
		[Vector3(-(L * 0.5 + 0.2), y0, 0), -PI * 0.5, W - 0.4], [Vector3(L * 0.5 + 0.2, y0, 0), PI * 0.5, W - 0.4]]
	for si in 4:
		var s: Array = sides[si]
		var fk := k.at_point(s[0], Vector3(0, s[1], 0))
		var len: float = s[2]
		var bays := maxi(1, int(round(len / 2.8)))
		var xs: Array[float] = []
		for i in bays:
			# (every bay of the front and back has its window, most of the ends)
			if rng.randf() < (0.92 if si < 2 else 0.55):
				xs.append((i + 0.5) * len / bays - len * 0.5)
		wall(fk, len, h, xs, material, col)
		for x in xs:
			var opts := {"material": material, "wall": col, "frame": trim, "curtains": curtains, "curtain": fabric}
			if rng.randf() < 0.3:
				opts["glazing"] = 0.85
				if lamps:
					opts["lit"] = true
					lit = true
			BuildingOpenings.window(fk, Vector3(x, SILL + WINDOW.y * 0.5, 0), WINDOW, opts)
	return lit


## A storey's wall `length` long and `h` tall in a face kit (its outer face
## at z = 0, 0.4 m deep behind it), a window at each of `xs`: the wall around
## them, a string course along the floor and a band under the eaves.
static func wall(k: BuildingKit, length: float, h: float, xs: Array[float], material: String, col: Color) -> void:
	var surf := BuildingMaterials.surface(material)
	var top := SILL + WINDOW.y
	var gaps: Array = []
	for x in xs:
		gaps.append(Rect2(x - WINDOW.x * 0.5, SILL, WINDOW.x, WINDOW.y))
	k.box(Vector3(length, SILL, 0.4), Vector3(0, SILL * 0.5, -0.2), surf, col)
	k.box(Vector3(length, h - top, 0.4), Vector3(0, top + (h - top) * 0.5, -0.2), surf, col)
	for run: Vector2 in BuildingWalls.runs(-length * 0.5, length * 0.5, SILL, top, gaps):
		if run.y - run.x > 0.02:
			k.box(Vector3(run.y - run.x, WINDOW.y, 0.4), Vector3((run.x + run.y) * 0.5, SILL + WINDOW.y * 0.5, -0.2), surf, col)
	BuildingWalls.face(k, length, h, material, col, gaps, {"plinth": 0.0, "band": h - 0.1})
	BuildingWalls.band(k, length, 0.07, material, col, [], 0.14, 0.05)
