class_name BevelMesh
extends ArrayMesh
## A box with chamfered edges and corners (see Res.box). The thin bevels catch
## the light along every edge, which is most of what makes a hard-surface model
## read as machined metal and moulded kit instead of a toy block.

var size := Vector3.ONE


static func make(s: Vector3, b: float) -> BevelMesh:
	var h := s * 0.5
	var i := h - Vector3(b, b, b)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	# the six faces
	for a in 3:
		for sa in [-1.0, 1.0]:
			var u := (a + 1) % 3
			var v := (a + 2) % 3
			var n := Vector3.ZERO
			n[a] = sa
			var pts: Array[Vector3] = []
			for c in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				var p := Vector3.ZERO
				p[a] = sa * h[a]
				p[u] = float(c[0]) * i[u]
				p[v] = float(c[1]) * i[v]
				pts.append(p)
			_poly(pts, n, verts, norms, uvs, idx)
	# the twelve edge chamfers
	for a in 3:
		for c in range(a + 1, 3):
			var k := 3 - a - c
			for sa in [-1.0, 1.0]:
				for sc in [-1.0, 1.0]:
					var n2 := Vector3.ZERO
					n2[a] = sa
					n2[c] = sc
					var pts2: Array[Vector3] = []
					for e in [[true, -1.0], [true, 1.0], [false, 1.0], [false, -1.0]]:
						var p2 := Vector3.ZERO
						p2[a] = sa * (h[a] if e[0] else i[a])
						p2[c] = sc * (i[c] if e[0] else h[c])
						p2[k] = float(e[1]) * i[k]
						pts2.append(p2)
					_poly(pts2, n2.normalized(), verts, norms, uvs, idx)
	# the eight corners
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var pts3: Array[Vector3] = [Vector3(sx * h.x, sy * i.y, sz * i.z), Vector3(sx * i.x, sy * h.y, sz * i.z), Vector3(sx * i.x, sy * i.y, sz * h.z)]
				_poly(pts3, Vector3(sx, sy, sz).normalized(), verts, norms, uvs, idx)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := BevelMesh.new()
	m.size = s
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## A convex polygon facing `n`, fanned into triangles wound the way Godot draws
## front faces.
static func _poly(pts: Array[Vector3], n: Vector3, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array) -> void:
	var base := verts.size()
	var an := n.abs()
	for p in pts:
		verts.append(p)
		norms.append(n)
		if an.y >= an.x and an.y >= an.z:
			uvs.append(Vector2(p.x, p.z))
		elif an.x >= an.z:
			uvs.append(Vector2(p.z, p.y))
		else:
			uvs.append(Vector2(p.x, p.y))
	var flip := (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(n) > 0.0
	for t in range(1, pts.size() - 1):
		idx.append(base)
		if flip:
			idx.append(base + t + 1)
			idx.append(base + t)
		else:
			idx.append(base + t)
			idx.append(base + t + 1)
