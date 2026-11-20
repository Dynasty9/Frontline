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
## a brick-on-edge course over a creasing, a saddleback stone, field stones
## on edge (cock_and_hen), or a cast cap with drips under its overhang.
## Returns the height of its top.
static func coping(k: BuildingKit, length: float, width: float, y: float, material: String, col: Color) -> float:
	var kind := BuildingMaterials.trim(material, "cap")
	match BuildingMaterials.value(material, "finish", "render"):
		"rubble":
			return cock_and_hen(k, length, width, y, col)
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


## How many ways a field-stone wall's top of one length is laid: each wall
## takes one (from its kit's generator), so neighbours seldom match.
const CROWN_LAYOUTS := 6
## (the tallest a stone on edge stands over the wall's top)
const CROWN_H := 0.25
static var _crowns := {}


## The top of a field-stone wall, as a waller finishes one: field stones set
## on edge across it, packed tight, a tall one (the cock) and one or two
## shorter (hens) in turn, each knocked in leaning a little as the one before
## it leans, their feet bedded in darker mortar. So the top is more stones of
## the wall's own kind with a ragged skyline, not a lid laid over it. The
## whole run is one cached mesh per length, width and layout (a wall costs
## one part), each stone its own shade in its vertex colours, drawn in the
## `fieldstone_cap` surface: field stone without the face's joints, since each
## piece here is a stone of its own. Returns the height of its top.
static func cock_and_hen(k: BuildingKit, length: float, width: float, y: float, col: Color) -> float:
	var layout := k.rng.randi() % CROWN_LAYOUTS
	var key := "%.2f|%.2f|%d|%s|%s" % [length, width, layout, col.to_html(false), Mats.per_material]
	var mesh: ArrayMesh = _crowns.get(key)
	if mesh == null:
		mesh = _crown(length, width, col, layout)
		_crowns[key] = mesh
	k.part_with(mesh, Mats.vc_variant(Mats.get_mat("fieldstone_cap")), Transform3D(Basis.IDENTITY, Vector3(0, y, 0)), Color(1, 1, 1))
	return y + CROWN_H


## (cock_and_hen's mesh, in a frame on the wall's top: x along it, z across)
static func _crown(length: float, width: float, col: Color, layout: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%.2f|%.2f|%d" % [length, width, layout])
	var p: Dictionary = Mats._preset("fieldstone_cap")
	var ca: Color = p.col_a
	var cb: Color = p.col_b
	var cc: Color = p.col_c
	var base := Mats.tint_for("fieldstone_cap", col)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	# the mortar the stones are bedded in, swept up between them in a low
	# ridge: under the stones' feet, so it shows only in the joints
	var mortar := _vc(base, Color(cb.r * 0.9 / ca.r, cb.g * 0.9 / ca.g, cb.b * 0.9 / ca.b))
	var hw := width * 0.5 - 0.045
	var x0 := -length * 0.5
	var x1 := length * 0.5
	var bed := [Vector2(-hw, -0.01), Vector2(-hw, 0.025), Vector2(0.0, 0.045), Vector2(hw, 0.025), Vector2(hw, -0.01)]
	for i in bed.size() - 1:
		var a: Vector2 = bed[i]
		var b: Vector2 = bed[i + 1]
		var face := [Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), Vector3(x0, b.y, b.x)]
		_solid(v, n, c, mortar, face, [[0, 1, 2, 3]], Vector3(0, -1, 0), 0.0)
	# the stones, end to end; the first and last stop flush with the wall's
	# ends, so walls laid in a line run on unbroken
	var x := x0
	var lean := r.randf_range(-0.08, 0.08)
	var hens := 0
	while x < x1 - 0.02:
		var cock := hens >= 2 or (hens >= 1 and r.randf() < 0.55)
		var t := r.randf_range(0.12, 0.22) if cock else r.randf_range(0.08, 0.15)
		var h := r.randf_range(0.2, CROWN_H) if cock else r.randf_range(0.11, 0.17)
		if r.randf() < 0.1:
			# now and then a big block of a stone, set in where it fitted
			t = r.randf_range(0.22, 0.32)
			h = r.randf_range(0.16, 0.22)
		var last := x1 - x - t < 0.08
		if last:
			t = x1 - x  # (the last fills out to the end)
		# (the stones at the ends stand upright and square to them)
		var end := last or x == x0
		hens = 0 if cock else hens + 1
		lean = clampf(lean * 0.85 + r.randf_range(-0.025, 0.025), -0.12, 0.12)
		var w := width + r.randf_range(-0.03, 0.07)
		# each its own shade, as the face's stones are (Mats pattern 24): grey
		# to brown, now and then a warmer one, lighter or darker
		var stone := ca.lerp(cc, r.randf())
		var tone := r.randf()
		if tone > 0.82:
			stone = stone.lerp(Color(ca.r * 1.05, ca.g * 0.95, ca.b * 0.82), 0.6)
		var shade := 0.72 + 0.34 * tone
		var tint := _vc(base, Color(stone.r * shade / ca.r, stone.g * shade / ca.g, stone.b * shade / ca.b))
		var twist := r.randf_range(-0.07, 0.07)
		var xf := Transform3D(Basis(Vector3.UP, 0.0 if end else twist) * Basis(Vector3.BACK, 0.0 if end else -lean), Vector3(x + t * 0.5, 0.0, r.randf_range(-0.015, 0.015)))
		_stone(v, n, c, tint, xf, t - 0.006, w, h, r, end)
		x += t
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(mesh, arrays)
	return mesh


## A rough stone on edge, `t` thick along the wall, `w` across it and `h`
## tall, placed by `xf`: its foot sunk in the bed, its sides up to its
## shoulders, then rounding over to a crown that runs across the wall,
## narrower than its foot and off its middle, each corner pushed about a
## little. Shaded round rather than in flat facets, so it reads as a worn
## field stone however it's seen; fourteen triangles (no underside: it's
## bedded).
static func _stone(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, col: Color, xf: Transform3D, t: float, w: float, h: float, r: RandomNumberGenerator, square := false) -> void:
	var tx := t * 0.5
	var tz := w * 0.5
	var cz := r.randf_range(-0.15, 0.15) * tz
	var kz := r.randf_range(0.5, 0.78)
	# (each end its own shoulder and thickness: a stone is seldom square)
	var sh := [h * r.randf_range(0.45, 0.8), h * r.randf_range(0.45, 0.8)]
	var th := [r.randf_range(0.8, 1.0 if square else 1.12), r.randf_range(0.8, 1.0 if square else 1.12)]
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var pts := []
	for s: Vector2 in corners:
		pts.append(xf * Vector3(s.x * tx * float(th[0 if s.y < 0.0 else 1]) * r.randf_range(0.94, 1.0 if square else 1.04), -0.04, s.y * tz + r.randf_range(-0.02, 0.02)))
	for s: Vector2 in corners:
		pts.append(xf * Vector3(s.x * tx * float(th[0 if s.y < 0.0 else 1]) * r.randf_range(0.94, 1.0 if square else 1.03), float(sh[0 if s.y < 0.0 else 1]) + r.randf_range(-0.015, 0.015), s.y * tz * r.randf_range(0.88, 1.0) + cz * 0.3))
	var rx := r.randf_range(-0.2, 0.2) * tx
	pts.append(xf * Vector3(rx, h - r.randf_range(0.0, 0.05), -tz * kz + cz))
	pts.append(xf * Vector3(rx, h - r.randf_range(0.0, 0.05), tz * kz + cz))
	_solid(v, n, c, col, pts, [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7], [5, 6, 9, 8], [7, 4, 8, 9], [4, 5, 8], [6, 7, 9]],
		xf * Vector3(0, h * 0.4, cz * 0.4), 0.65)


## Faces (three or four corner indices into `pts`) of a solid round
## `inside`, coloured `col`, every face turned away from `inside`. `smooth`
## blends each corner's normal from its own face's toward the average of the
## faces meeting there: 0 flat facets, 1 shaded round.
static func _solid(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, col: Color, pts: Array, faces: Array, inside: Vector3, smooth: float) -> void:
	var normals := []
	var corner := []
	corner.resize(pts.size())
	corner.fill(Vector3.ZERO)
	for f: Array in faces:
		var a: Vector3 = pts[f[0]]
		var b: Vector3 = pts[f[1]]
		var d: Vector3 = pts[f[2]]
		var e: Vector3 = pts[f[3]] if f.size() > 3 else d
		var fn := (d - a).cross(e - b) if f.size() > 3 else (b - a).cross(d - a)
		var mid := (a + b + d + e) * 0.25 if f.size() > 3 else (a + b + d) / 3.0
		if fn.dot(mid - inside) < 0.0:
			fn = -fn
		fn = fn.normalized()
		normals.append(fn)
		for i: int in f:
			corner[i] += fn
	for fi in faces.size():
		var f: Array = faces[fi]
		var fn: Vector3 = normals[fi]
		var tris := [[f[0], f[1], f[2]]]
		if f.size() > 3:
			tris.append([f[0], f[2], f[3]])
		for tri: Array in tris:
			var i0: int = tri[0]
			var i1: int = tri[1]
			var i2: int = tri[2]
			var p0: Vector3 = pts[i0]
			var e1: Vector3 = (pts[i1] as Vector3) - p0
			var e2: Vector3 = (pts[i2] as Vector3) - p0
			if e1.cross(e2).length_squared() < 1e-12:
				continue
			# (wound the way Godot draws front faces: see BuildingKit._tri)
			if e1.cross(e2).dot(fn) > 0.0:
				var sw := i1
				i1 = i2
				i2 = sw
			for i: int in [i0, i1, i2]:
				v.append(pts[i])
				n.append(fn.lerp((corner[i] as Vector3).normalized(), smooth).normalized())
				c.append(col)


## A tint (a multiplier on the surface's own colour) as a baked part's
## vertex colour holds it: linear light outside the browser, scaled down for
## the merged material to restore (see Mats.VC_K, BuildingWeathering.stain).
static func _vc(base: Color, mul: Color) -> Color:
	var t := Color(base.r * mul.r, base.g * mul.g, base.b * mul.b)
	if not Mats.per_material:
		t = t.srgb_to_linear()
	return Color(t.r / Mats.VC_K, t.g / Mats.VC_K, t.b / Mats.VC_K)


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
