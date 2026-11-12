class_name BuildingWalls
extends RefCounted
## The faces and tops of walls. Work in a face kit (BuildingKit.on_face or
## at_point): x along the wall and centred on it, y up from its foot, z out of
## the face, the face itself at z = 0. `gaps` are the openings in it (Rect2s
## in x and y: windows, doorways) that a plinth, a band or a run of boards
## stops at, as they would on a real wall.
##
## A face is finished as its material is built (see BuildingMaterials):
##   render  a darker rendered plinth, a band under the eaves
##   brick   a base of darker (engineering) brick, concrete dressings
##   stone   dressed quoins at the corners, a stone base course
##   boards  lapped weatherboards (each lap a shadow line), corner boards
##   sheet   lapped corrugated sheets, a base angle and a top flashing
##   panels  precast panels with sealed joints


## Dresses a face `length` wide and `height` tall built in `material`, its
## surface tinted `col`. opts: "plinth" (height, 0 for none; default 0.34),
## "band" (height of a projecting band, e.g. under the eaves), "corners"
## (x of the corners the face turns: quoins, corner boards).
static func face(k: BuildingKit, length: float, height: float, material: String, col: Color, gaps: Array = [], opts := {}) -> void:
	var finish: String = BuildingMaterials.value(material, "finish", "render")
	var ph: float = opts.get("plinth", 0.34)
	if ph > 0.0:
		plinth(k, length, ph, material, col, gaps)
	match finish:
		"boards":
			boards(k, length, height, ph, material, col, gaps)
		"sheet":
			sheeting(k, length, height, material, col, gaps)
		"panels":
			joints(k, length, height, float(BuildingMaterials.value(material, "joints", 2.0)), col, gaps)
	if opts.has("band"):
		band(k, length, float(opts.band), material, col, gaps)
	for x: float in opts.get("corners", []):
		var side := signf(x) if x != 0.0 else 1.0
		match finish:
			"stone":
				quoins(k, x, height, side, col)
			"boards":
				k.plate(Vector3(0.12, height - ph, 0.03), Vector3(x - side * 0.06, ph + (height - ph) * 0.5, 0.015), BuildingMaterials.trim(material), BuildingMaterials.trim_color(material, col, -0.18), Vector3.ZERO, true)


## The base course along the foot of a face: proud of it and darker
## (splashed and damp, or a harder brick).
static func plinth(k: BuildingKit, length: float, h: float, material: String, col: Color, gaps: Array = []) -> void:
	var kind := BuildingMaterials.trim(material, "base")
	var tone: float = BuildingMaterials.value(material, "base_tone", -0.3)
	var c := BuildingMaterials.trim_color(material, col, tone) if kind == BuildingMaterials.surface(material) else Color(0.5, 0.49, 0.46)
	for run: Vector2 in runs(-length * 0.5, length * 0.5, 0.0, h, gaps):
		var w := run.y - run.x
		if w < 0.05:
			continue
		var x := (run.x + run.y) * 0.5
		k.box(Vector3(w, h, 0.05), Vector3(x, h * 0.5, 0.025), kind, c)


## A projecting band (a string course, the cornice under the eaves) at `y`.
static func band(k: BuildingKit, length: float, y: float, material: String, col: Color, gaps: Array = [], h := 0.12, depth := 0.04) -> void:
	var kind := BuildingMaterials.trim(material)
	var c := BuildingMaterials.trim_color(material, col, 0.12)
	for run: Vector2 in runs(-length * 0.5, length * 0.5, y - h * 0.5, y + h * 0.5, gaps):
		if run.y - run.x > 0.05:
			k.plate(Vector3(run.y - run.x, h, depth), Vector3((run.x + run.y) * 0.5, y, depth * 0.5), kind, c, Vector3.ZERO, true)


## Weatherboarding: each board laps over the one below, so every lap is a
## shadow line across the face.
static func boards(k: BuildingKit, length: float, height: float, from: float, material: String, col: Color, gaps: Array = []) -> void:
	var pitch: float = BuildingMaterials.value(material, "boards", 0.24)
	var c := col.darkened(0.22)
	var y := from + pitch
	while y < height - 0.05:
		for run: Vector2 in runs(-length * 0.5, length * 0.5, y - 0.01, y + 0.01, gaps):
			if run.y - run.x > 0.05:
				k.plate(Vector3(run.y - run.x, 0.022, 0.016), Vector3((run.x + run.y) * 0.5, y, 0.008), BuildingMaterials.surface(material), c)
		y += pitch


## Corrugated cladding: the laps between sheets, a base angle along the foot,
## a flashing along the top.
static func sheeting(k: BuildingKit, length: float, height: float, material: String, col: Color, gaps: Array = []) -> void:
	var pitch: float = BuildingMaterials.value(material, "sheets", 1.05)
	var n := maxi(1, int(round(length / pitch)))
	for i in range(1, n):
		var x := -length * 0.5 + i * length / n
		for run: Vector2 in vertical_runs(x, 0.0, height, gaps):
			k.plate(Vector3(0.035, run.y - run.x, 0.012), Vector3(x, (run.x + run.y) * 0.5, 0.006), "corrugated", col.darkened(0.25))
	var tc := BuildingMaterials.trim_color(material, col)
	for run: Vector2 in runs(-length * 0.5, length * 0.5, 0.0, 0.08, gaps):
		k.plate(Vector3(run.y - run.x, 0.07, 0.04), Vector3((run.x + run.y) * 0.5, 0.035, 0.02), "steel", tc)
	k.plate(Vector3(length + 0.02, 0.09, 0.05), Vector3(0, height - 0.045, 0.025), "steel", tc, Vector3.ZERO, true)


## The sealed joints between precast panels.
static func joints(k: BuildingKit, length: float, height: float, spacing: float, col: Color, gaps: Array = []) -> void:
	var n := maxi(1, int(round(length / spacing)))
	for i in range(1, n):
		var x := -length * 0.5 + i * length / n
		for run: Vector2 in vertical_runs(x, 0.02, height - 0.02, gaps):
			k.plate(Vector3(0.022, run.y - run.x, 0.008), Vector3(x, (run.x + run.y) * 0.5, 0.003), "precast", col.darkened(0.35))


## Dressed corner stones up a corner at `x`, long and short in turn, laid
## inwards from it (`side` is the way out of the face).
static func quoins(k: BuildingKit, x: float, height: float, side: float, col: Color) -> void:
	var y := 0.0
	var i := 0
	while y + 0.26 < height:
		var w := 0.44 if i % 2 == 0 else 0.28
		k.box(Vector3(w, 0.26, 0.035), Vector3(x - side * w * 0.5, y + 0.15, 0.0175), "stone", col.lightened(0.1))
		y += 0.3
		i += 1


## The cap on top of a wall `width` thick whose top is at `y`, in `material`:
## a brick-on-edge course over a creasing, a saddleback stone, or a cast cap
## with drips under its overhang. Returns the height of its top.
static func coping(k: BuildingKit, length: float, width: float, y: float, material: String, col: Color) -> float:
	var kind := BuildingMaterials.trim(material, "cap")
	match BuildingMaterials.value(material, "finish", "render"):
		"brick":
			k.plate(Vector3(length + 0.05, 0.025, width + 0.05), Vector3(0, y + 0.012, 0), "concrete", Color(0.42, 0.41, 0.39), Vector3.ZERO, true)
			k.box(Vector3(length, 0.11, width), Vector3(0, y + 0.08, 0), "brick", col.darkened(0.12))
			return y + 0.135
		"stone":
			var sc := col.darkened(0.1)
			k.box(Vector3(length + 0.06, 0.08, width + 0.08), Vector3(0, y + 0.04, 0), "stone", sc)
			k.prism(Vector3(width + 0.04, 0.07, length + 0.04), Vector3(0, y + 0.115, 0), "stone", sc.lightened(0.06), Vector3(0, PI * 0.5, 0))
			return y + 0.15
	var c := BuildingMaterials.trim_color(material, col, 0.06)
	k.box(Vector3(length + 0.06, 0.08, width + 0.08), Vector3(0, y + 0.04, 0), kind, c)
	for s: float in [-1.0, 1.0]:
		k.plate(Vector3(length + 0.06, 0.014, 0.014), Vector3(0, y - 0.004, s * (width * 0.5 + 0.024)), kind, c.darkened(0.2))
	return y + 0.08


## A square pier at `x` (a gate post, the end of a garden wall), `size` its
## footprint, `h` tall, under a cap.
static func pier(k: BuildingKit, x: float, size: Vector2, h: float, material: String, col: Color) -> void:
	k.box(Vector3(size.x, h, size.y), Vector3(x, h * 0.5, 0), BuildingMaterials.surface(material), col)
	var pk := k.at_point(Vector3(x, 0, 0))
	coping(pk, size.x, size.y, h, material, col)


## The stretches of [x0, x1] a band from y0 to y1 runs along, between the gaps.
static func runs(x0: float, x1: float, y0: float, y1: float, gaps: Array) -> Array[Vector2]:
	var out: Array[Vector2] = [Vector2(x0, x1)]
	for g: Rect2 in gaps:
		if g.end.y <= y0 or g.position.y >= y1:
			continue
		var next: Array[Vector2] = []
		for r in out:
			if g.end.x <= r.x or g.position.x >= r.y:
				next.append(r)
				continue
			if g.position.x > r.x:
				next.append(Vector2(r.x, g.position.x))
			if g.end.x < r.y:
				next.append(Vector2(g.end.x, r.y))
		out = next
	return out


## The stretches of [y0, y1] a vertical line at `x` runs up, between the gaps.
static func vertical_runs(x: float, y0: float, y1: float, gaps: Array) -> Array[Vector2]:
	var flipped: Array = []
	for g: Rect2 in gaps:
		flipped.append(Rect2(g.position.y, g.position.x, g.size.y, g.size.x))
	return runs(y0, y1, x - 0.02, x + 0.02, flipped)
