class_name BuildingKit
extends RefCounted
## Where a building's construction goes, and in whose coordinates. The shared
## components (BuildingWalls, BuildingRoofs, BuildingOpenings, BuildingFittings,
## BuildingWire) take a kit and place their parts in its frame: metres, +y up,
## and for anything mounted on a face, +x along the face and +z out of it.
##
## A kit writes either nodes (a MeshInstance3D per part under its root, which
## Mats.merge_static merges with the rest of the model, or which stay apart
## when they have to move: a door leaf on its hinges) or straight into a
## Mats.Bake (the scenery a town has thousands of: house walls, street
## furniture), so one component builds both. Parts always carry one of our
## procedural surfaces (a Mats preset) and a colour tint, never a flat colour,
## so Structure._skin leaves them as they are.
##
## Parts a building has by the hundred (a window frame, a louvre, a gutter run)
## are cached as one mesh per shape (see shape()), so a town bakes one part per
## frame, not a dozen boxes, and trims too thin to show a chamfer use plain
## boxes (plate()), a quarter of the vertices of a bevelled one.

class Sink:
	var root: Node3D
	var bake: Mats.Bake
	var at := Transform3D.IDENTITY
	var parts := 0  # how many parts have gone in (tests and the inventory count them)
	## Every part casts a shadow, whatever it asks: a model merged on its own
	## (a roof) makes one mesh per surface and shadow setting, so a few tiny
	## shadowless parts would cost it a draw call each for nothing.
	var cast_all := false


var sink: Sink
var frame := Transform3D.IDENTITY
var rng: RandomNumberGenerator
## A side's disruptive paint over what this kit builds (Camo.painted), or -1:
## a base's buildings are painted over, a town's are not.
var paint := -1

static var _shapes := {}
static var _plates := {}


## A kit making MeshInstance3D nodes under `parent`.
static func nodes(parent: Node3D, random: RandomNumberGenerator = null) -> BuildingKit:
	var k := BuildingKit.new()
	k.sink = Sink.new()
	k.sink.root = parent
	k.rng = random if random != null else _still()
	return k


## A kit writing into `bake`, its parts placed in a holder at `at` (Decor
## builds each piece of a chunk in its own holder).
static func baked(bake: Mats.Bake, random: RandomNumberGenerator = null, at := Transform3D.IDENTITY) -> BuildingKit:
	var k := BuildingKit.new()
	k.sink = Sink.new()
	k.sink.bake = bake
	k.sink.at = at
	k.rng = random if random != null else _still()
	return k


## A generator for callers that give none: the same look every time.
static func _still() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 0x6b17
	return r


## The same kit (same output, same generator) working in a frame placed by
## `xf` in this one's.
func moved(xf: Transform3D) -> BuildingKit:
	var k := BuildingKit.new()
	k.sink = sink
	k.rng = rng
	k.frame = frame * xf
	k.paint = paint
	return k


func at_point(p: Vector3, rot := Vector3.ZERO) -> BuildingKit:
	return moved(Mats.place(p, rot))


## A frame on a face: origin `p`, +z out along `out` (levelled), +x along
## the face, +y up.
func on_face(p: Vector3, out: Vector3) -> BuildingKit:
	var z := Vector3(out.x, 0.0, out.z).normalized()
	if z.is_zero_approx():
		z = Vector3.BACK
	return moved(Transform3D(Basis(Vector3.UP.cross(z), Vector3.UP, z), p))


## Where a point in this kit's frame lies in the sink's (the model's) space.
func to_model(p: Vector3) -> Vector3:
	return frame * p


# --- parts ------------------------------------------------------------------------------

## A mesh under the surface `kind`, placed by `xf` in the kit's frame, tinted
## to `col` (or the surface's own colour), casting a shadow or not.
func part(mesh: Mesh, kind: String, xf: Transform3D, col: Variant = null, shadow := true) -> void:
	sink.parts += 1
	if paint >= 0:
		kind = Camo.painted(kind, paint)
	shadow = shadow or sink.cast_all
	var tint := Mats.tint_for(kind, col) if col is Color else Color(1, 1, 1)
	var placed := frame * xf
	if sink.bake != null:
		sink.bake.part(mesh, Mats.get_mat(kind), placed, tint if tint != Color(1, 1, 1) else null, shadow, sink.at)
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = placed
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sink.root.add_child(mi)
	Mats.apply(mi, kind, tint)


## A mesh under a material of its own rather than a surface preset (leaf
## cards: flowers in a window box), tinted to `col`.
func part_with(mesh: Mesh, mat: ShaderMaterial, xf: Transform3D, col: Color, shadow := true) -> void:
	sink.parts += 1
	shadow = shadow or sink.cast_all
	var placed := frame * xf
	if sink.bake != null:
		sink.bake.part(mesh, mat, placed, col, shadow, sink.at)
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = placed
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sink.root.add_child(mi)
	Mats.set_material(mi, mat)
	Mats.set_inst(mi, &"tint", col)


## A box with chamfered edges (Res.box), centred on `p`.
func box(size: Vector3, p: Vector3, kind: String, col: Variant = null, rot := Vector3.ZERO, shadow := true) -> void:
	part(Res.box(size), kind, Mats.place(p, rot), col, shadow)


## A trim, sheet or bar too thin for a chamfer to show: a plain box.
func plate(size: Vector3, p: Vector3, kind: String, col: Variant = null, rot := Vector3.ZERO, shadow := false) -> void:
	part(plain(size), kind, Mats.place(p, rot), col, shadow)


func cyl(r_top: float, r_bottom: float, h: float, p: Vector3, kind: String, col: Variant = null, rot := Vector3.ZERO, segs := 8, shadow := true) -> void:
	part(Res.cyl(r_top, r_bottom, h, segs), kind, Mats.place(p, rot), col, shadow)


func prism(size: Vector3, p: Vector3, kind: String, col: Variant = null, rot := Vector3.ZERO, shadow := true) -> void:
	part(Res.prism(size), kind, Mats.place(p, rot), col, shadow)


## A round bar from `a` to `b` (a pole, a pipe, a guy, a rail).
func rod(a: Vector3, b: Vector3, r: float, kind: String, col: Variant = null, segs := 6, shadow := true) -> void:
	var d := b - a
	var ln := d.length()
	if ln < 0.0005:
		return
	part(Res.cyl(r, r, ln, segs), kind, Transform3D(aim(d), (a + b) * 0.5), col, shadow)


## A square member from `a` to `b`, `w` across and `d` deep, its width kept
## level (a rafter, a brace, a barge board), plain when it's thin.
func beam(a: Vector3, b: Vector3, w: float, d: float, kind: String, col: Variant = null, shadow := true) -> void:
	var dv := b - a
	var ln := dv.length()
	if ln < 0.0005:
		return
	var y := dv / ln
	var side := Vector3.UP.cross(y) if absf(y.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	side = side.normalized()
	var z := side.cross(y).normalized()
	var s := Vector3(w, ln, d)
	part(Res.box(s) if minf(w, d) >= 0.04 else plain(s), kind, Transform3D(Basis(side, y, z), (a + b) * 0.5), col, shadow)


## A plain square bar from `a` to `b` (a square downpipe, a strap, a stay).
func bar(a: Vector3, b: Vector3, w: float, d: float, kind: String, col: Variant = null, shadow := true) -> void:
	var dv := b - a
	var ln := dv.length()
	if ln < 0.0005:
		return
	part(plain(Vector3(w, ln, d)), kind, Transform3D(aim(dv), (a + b) * 0.5), col, shadow)


## A ring (a handle, a fan guard, a dish's rim) in the xz plane: a torus a
## twelfth of the triangles of Res.torus's, for parts this small.
static func ring(inner: float, outer: float) -> TorusMesh:
	var key := "ring|%.3f|%.3f" % [inner, outer]
	var m: TorusMesh = _plates.get(key)
	if m == null:
		m = TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 12
		m.ring_segments = 4
		_plates[key] = m
	return m


## Turns +y onto `direction`.
static func aim(direction: Vector3) -> Basis:
	var y := direction.normalized()
	if y.is_zero_approx():
		return Basis.IDENTITY
	if y.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, y))


## A plain (unchamfered) box, cached by size.
static func plain(size: Vector3) -> BoxMesh:
	var key := "%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	var m: BoxMesh = _plates.get(key)
	if m == null:
		m = BoxMesh.new()
		m.size = size
		_plates[key] = m
	return m


## One cached mesh made of several pieces: `build` returns them as
## [mesh, transform] pairs and is called only the first time `key` is asked
## for. The pieces are joined in script (no read-back from the renderer) and
## the result remembers its arrays for the bake (Mats.keep_arrays).
static func shape(key: String, build: Callable) -> ArrayMesh:
	var m: ArrayMesh = _shapes.get(key)
	if m != null:
		return m
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	for piece: Array in build.call():
		var mesh: Mesh = piece[0]
		var xf: Transform3D = piece[1]
		var fa := Mats._flat(mesh, 0)
		v.append_array(xf * (fa[0] as PackedVector3Array))
		n.append_array(Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * (fa[1] as PackedVector3Array))
	m = _commit(v, n)
	_shapes[key] = m
	return m


## (for shape(): a piece of box at `p`, turned by `rot`)
static func piece(size: Vector3, p: Vector3, rot := Vector3.ZERO, bevel := false) -> Array:
	return [Res.box(size) if bevel else plain(size), Mats.place(p, rot)]


## A flat-sided solid: the convex `outline` (x, y; either winding) extruded
## `depth` along z, centred on z = 0 (a gable, a gusset, a shard of glass).
## Cached by `key`.
static func extrusion(key: String, outline: PackedVector2Array, depth: float) -> ArrayMesh:
	var m: ArrayMesh = _shapes.get("x|" + key)
	if m != null:
		return m
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := Vector2.ZERO
	for p in outline:
		c += p
	c /= outline.size()
	var hz := depth * 0.5
	var count := outline.size()
	for i in count:
		var a := outline[i]
		var b := outline[(i + 1) % count]
		_tri(v, n, Vector3(c.x, c.y, hz), Vector3(a.x, a.y, hz), Vector3(b.x, b.y, hz), Vector3.BACK)
		_tri(v, n, Vector3(c.x, c.y, -hz), Vector3(a.x, a.y, -hz), Vector3(b.x, b.y, -hz), Vector3.FORWARD)
		var e := b - a
		var side := Vector3(e.y, -e.x, 0.0).normalized()
		if side.dot(Vector3(a.x - c.x, a.y - c.y, 0.0)) < 0.0:
			side = -side
		_tri(v, n, Vector3(a.x, a.y, hz), Vector3(b.x, b.y, hz), Vector3(b.x, b.y, -hz), side)
		_tri(v, n, Vector3(a.x, a.y, hz), Vector3(b.x, b.y, -hz), Vector3(a.x, a.y, -hz), side)
	m = _commit(v, n)
	_shapes["x|" + key] = m
	return m


## A round wire, pipe or rope along `points` (not cached: every run is its
## own), `sides` round, its frame carried along so it doesn't twist.
static func tube_mesh(points: PackedVector3Array, r: float, sides := 4) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var ref := Vector3.UP
	var rings: Array = []
	for i in points.size():
		var t := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		if absf(t.dot(ref)) > 0.95:
			ref = Vector3.RIGHT
		var x := ref.cross(t).normalized()
		var y := t.cross(x)
		ref = y
		var ring := []
		for s in sides:
			var a := TAU * s / sides
			ring.append(x * cos(a) + y * sin(a))
		rings.append(ring)
	for i in points.size() - 1:
		for s in sides:
			var s2 := (s + 1) % sides
			var a0: Vector3 = rings[i][s]
			var a1: Vector3 = rings[i][s2]
			var b0: Vector3 = rings[i + 1][s]
			var b1: Vector3 = rings[i + 1][s2]
			_tri(v, n, points[i] + a0 * r, points[i + 1] + b0 * r, points[i + 1] + b1 * r, (a0 + b0 + b1).normalized())
			_tri(v, n, points[i] + a0 * r, points[i + 1] + b1 * r, points[i] + a1 * r, (a0 + b1 + a1).normalized())
	return _commit(v, n)


## A triangle wound the way Godot draws front faces, whichever way it came.
static func _tri(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		v.append_array([a, c, b])
	else:
		v.append_array([a, b, c])
	n.append_array([normal, normal, normal])


static func _commit(v: PackedVector3Array, n: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(m, arrays)
	return m
