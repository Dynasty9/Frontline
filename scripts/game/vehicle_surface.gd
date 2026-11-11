class_name VehicleSurface
extends RefCounted
## An authored surface maps a 2D domain to positions. Geometry stays local to
## its parent; callers own silhouette, domain scale and outward direction.

var sample: Callable
var outward: Vector3
# A surface adapter is immutable during a build. Shared pane/edge samples are
# cached only for its lifetime, never globally across vehicle dimensions.
var _positions := {}
var _normals := {}

func _init(sampler: Callable, facing: Vector3) -> void:
	sample = sampler
	outward = facing.normalized()

static func plane(origin: Vector3, across: Vector3, up: Vector3) -> VehicleSurface:
	return VehicleSurface.new(func(q: Vector2) -> Vector3: return origin + across * q.x + up * q.y, across.cross(up))

static func quad(corners: Array, inside: Vector3) -> VehicleSurface:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var d: Vector3 = corners[3]
	var n := (b - a).cross(d - a).normalized()
	if n.dot(a - inside) < 0.0:
		n = -n
	return VehicleSurface.new(func(q: Vector2) -> Vector3: return a.lerp(b, q.x).lerp(d.lerp(c, q.x), q.y), n)

func normal(q: Vector2) -> Vector3:
	if _normals.has(q):
		return _normals[q]
	var du: Vector3 = sample.call(q + Vector2(0.0001, 0)) - sample.call(q - Vector2(0.0001, 0))
	var dv: Vector3 = sample.call(q + Vector2(0, 0.0001)) - sample.call(q - Vector2(0, 0.0001))
	var n := du.cross(dv).normalized()
	if n.is_zero_approx():
		n = outward
	elif n.dot(outward) < 0.0:
		n = -n
	_normals[q] = n
	return n

func point(q: Vector2, lift := 0.0) -> Vector3:
	if not _positions.has(q):
		_positions[q] = sample.call(q)
	var p: Vector3 = _positions[q]
	return p if is_zero_approx(lift) else p + normal(q) * lift

## Triangulated authored outline, with optional subdivisions on curved skins.
## No name-only cache: distinct geometry can never borrow another model's pane.
func patch(outline: PackedVector2Array, lift := 0.0, depth := 0.0, divisions := 0) -> ArrayMesh:
	assert(outline.size() >= 3)
	var indices := Geometry2D.triangulate_polygon(outline)
	assert(not indices.is_empty(), "Surface outline must be simple and nondegenerate")
	var data := [[], [], []]
	for i in range(0, indices.size(), 3):
		_triangle(data, outline[indices[i]], outline[indices[i + 1]], outline[indices[i + 2]], lift, clampi(divisions, 0, 3), false)
		if depth > 0.0:
			_triangle(data, outline[indices[i]], outline[indices[i + 1]], outline[indices[i + 2]], lift - depth, clampi(divisions, 0, 3), true)
	if depth > 0.0:
		var center := Vector2.ZERO
		for q in outline:
			center += q
		center /= outline.size()
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			var steps := 1 << clampi(divisions, 0, 3)
			for j in steps:
				var u := a.lerp(b, float(j) / steps)
				var v := a.lerp(b, float(j + 1) / steps)
				var mid := (u + v) * 0.5
				var n := (point(v) - point(u)).cross(normal(mid)).normalized()
				if n.dot(point(mid) - point(center)) < 0.0:
					n = -n
				_quad(data, point(u, lift), point(v, lift), point(v, lift - depth), point(u, lift - depth), n)
	return _mesh(data)

func _triangle(data: Array, a: Vector2, b: Vector2, c: Vector2, lift: float, divisions: int, reverse: bool) -> void:
	if divisions > 0:
		var ab := (a + b) * 0.5
		var bc := (b + c) * 0.5
		var ca := (c + a) * 0.5
		_triangle(data, a, ab, ca, lift, divisions - 1, reverse)
		_triangle(data, ab, b, bc, lift, divisions - 1, reverse)
		_triangle(data, ca, bc, c, lift, divisions - 1, reverse)
		_triangle(data, ab, bc, ca, lift, divisions - 1, reverse)
		return
	var n := normal((a + b + c) / 3.0) * (-1.0 if reverse else 1.0)
	var order := [a, b, c]
	if (point(b) - point(a)).cross(point(c) - point(a)).dot(n) > 0.0:
		order = [a, c, b] # Godot's front faces wind clockwise.
	for q: Vector2 in order:
		(data[0] as Array).append(point(q, lift))
		(data[1] as Array).append(normal(q) * (-1.0 if reverse else 1.0))
		(data[2] as Array).append(q)

static func _quad(data: Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var corners := [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		corners = [a, c, b, a, d, c]
	for p: Vector3 in corners:
		(data[0] as Array).append(p)
		(data[1] as Array).append(normal)
		(data[2] as Array).append(Vector2.ZERO)

static func _mesh(data: Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(data[0])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(data[1])
	if not data[2].is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(data[2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	Mats.keep_arrays(mesh, arrays)
	return mesh

## A rectangular domain with rectangular apertures. Split only at authored
## opening edges; generate front/back skins and jambs without runtime CSG.
func shell(region: Rect2, openings: Array[Rect2], depth: float) -> ArrayMesh:
	var xs: Array[float] = [region.position.x, region.end.x]
	var ys: Array[float] = [region.position.y, region.end.y]
	for hole in openings:
		assert(region.encloses(hole) and hole.size.x > 0.0 and hole.size.y > 0.0)
		for x in [hole.position.x, hole.end.x]:
			if x not in xs:
				xs.append(x)
		for y in [hole.position.y, hole.end.y]:
			if y not in ys:
				ys.append(y)
	xs.sort()
	ys.sort()
	var data := [[], [], []]
	for i in xs.size() - 1:
		for j in ys.size() - 1:
			var mid := Vector2((xs[i] + xs[i + 1]) * 0.5, (ys[j] + ys[j + 1]) * 0.5)
			var empty := false
			for hole in openings:
				if hole.has_point(mid):
					empty = true
			if empty:
				continue
			var outline := PackedVector2Array([Vector2(xs[i], ys[j]), Vector2(xs[i + 1], ys[j]), Vector2(xs[i + 1], ys[j + 1]), Vector2(xs[i], ys[j + 1])])
			var arrays := Mats._arrays(patch(outline, 0.0, depth), 0)
			(data[0] as Array).append_array(arrays[Mesh.ARRAY_VERTEX])
			(data[1] as Array).append_array(arrays[Mesh.ARRAY_NORMAL])
			(data[2] as Array).append_array(arrays[Mesh.ARRAY_TEX_UV])
	return _mesh(data)
