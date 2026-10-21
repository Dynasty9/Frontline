class_name Mats
extends RefCounted
## Procedural surface materials: one uber-shader with a pattern switch
## (brick, plaster, concrete, sandbags, wood, camouflage, worn paint, ...).
## Patterns are evaluated in world space (or object space for things that
## move) and get bump-mapped relief, grime near the ground and per-object
## variation. Per-instance tint comes from an instance uniform.

const PLAIN := 0
const BRICK := 1
const PLASTER := 2
const CONCRETE := 3
const SANDBAG := 4
const WOOD := 5
const CAMO := 6
const PAINT := 7
const EARTH := 8
const CORRUGATED := 9
const CANVAS := 10
const STONE := 11
const BARK := 12
const TRACK := 13
const SKIN := 14
const TILES := 15
const HESCO := 16

static var _shader: Shader
static var _cache := {}


static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = TerrainTexture.shader(SURFACE_SHADER)
	return _shader


## kind: a preset name (see _preset). Returns a shared material.
static func get_mat(kind: String) -> ShaderMaterial:
	if _cache.has(kind):
		return _cache[kind]
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.set_shader_parameter("noise_tex", noise_tex())
	var p := _preset(kind)
	for k in p:
		m.set_shader_parameter(k, p[k])
	_cache[kind] = m
	return m


## Paving - sidewalks, kerbs, the square, crossings, car parks: the material
## with holes where the ground under it has been cratered or dug out, so a
## shell hole in the square is a hole (and a man lying in it can be seen).
static var _paving := {}
static var _crater_tex: Texture2DArray = null
static var _trench_tex: Texture2D = null


static func paving(kind: String) -> ShaderMaterial:
	if _paving.has(kind):
		return _paving[kind]
	var m := get_mat(kind).duplicate() as ShaderMaterial
	m.set_shader_parameter("crater_cut", true)
	m.set_shader_parameter("crater_half", MapDims.HALF)
	if _crater_tex:
		m.set_shader_parameter("crater_tex", _crater_tex)
	if _trench_tex:
		m.set_shader_parameter("trench_tex", _trench_tex)
	_paving[kind] = m
	return m


## The ground's deformation and trench masks (the atmosphere hands them over
## as they're made and remade); paving materials, and merged copies of them,
## cut their holes from these.
static func set_ground_maps(crater: Texture2DArray, trench: Texture2D) -> void:
	if crater:
		_crater_tex = crater
	if trench:
		_trench_tex = trench
	var mats: Array = _paving.values()
	for v in _vc_cache.values():
		if v.get_shader_parameter("crater_cut") == true:
			mats.append(v)
	for m in mats:
		m.set_shader_parameter("crater_half", MapDims.HALF)
		if crater:
			m.set_shader_parameter("crater_tex", crater)
		if trench:
			m.set_shader_parameter("trench_tex", trench)


## Applies a material to a mesh instance with an optional per-instance tint.
static func apply(mi: GeometryInstance3D, kind: String, tint := Color(1, 1, 1)) -> GeometryInstance3D:
	mi.material_override = get_mat(kind)
	if tint != Color(1, 1, 1):
		mi.set_instance_shader_parameter("tint", tint)
	return mi


## Tint that turns the preset's base colour into `c` (keeps per-part colours).
static func tint_for(kind: String, c: Color) -> Color:
	var b: Color = _preset(kind).get("col_a", Color(0.6, 0.6, 0.6))
	return Color(clampf(c.r / maxf(b.r, 0.02), 0.25, 2.5), clampf(c.g / maxf(b.g, 0.02), 0.25, 2.5), clampf(c.b / maxf(b.b, 0.02), 0.25, 2.5))


static var _foliage: ShaderMaterial
static var _noise: ImageTexture


## A tileable value-noise texture with mipmaps (16 features across): the
## procedural surfaces read their fine noise from it, so the GPU filters it.
static func noise_tex() -> ImageTexture:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
		n.fractal_type = FastNoiseLite.FRACTAL_NONE
		n.frequency = 1.0 / 16.0
		n.seed = 1234
		var img := n.get_seamless_image(256, 256, false, false, 0.1, true)
		img.convert(Image.FORMAT_L8)
		img.generate_mipmaps()
		_noise = ImageTexture.create_from_image(img)
	return _noise


## Lumpy, wind-swayed leaf clusters with translucency (instance uniform tint).
static func foliage() -> ShaderMaterial:
	if _foliage == null:
		var sh := Shader.new()
		sh.code = FOLIAGE_SHADER
		_foliage = ShaderMaterial.new()
		_foliage.shader = sh
	return _foliage


static var _vc_cache := {}
## Merged parts carry their tint as vertex colour, which is stored 8 bits per
## channel and clamps at 1: a tint brighter than the material's base (a sand
## paint over an olive preset) would be lost. So it's stored at a quarter and
## the shader multiplies it back up.
const VC_K := 4.0


## Same material, but reading the part colour from vertex colours (for merged meshes).
static func vc_variant(m: ShaderMaterial) -> ShaderMaterial:
	var id := m.get_instance_id()
	if _vc_cache.has(id):
		return _vc_cache[id]
	var v := m.duplicate() as ShaderMaterial
	v.set_shader_parameter("use_vcolor", true)
	if v.shader == shader():
		v.set_shader_parameter("vcolor_k", VC_K)
	_vc_cache[id] = v
	return v


## Bakes every static part under `root` that uses one of our shaders into a single
## mesh per material, carrying each part's tint as vertex colour. A ruined house
## or a tree goes from a dozen render objects to one or two.
static func merge_static(root: Node3D, keep: Array = [], deep := true, remerge := false, single := false) -> void:
	var groups := {}
	var victims: Array = []
	_collect(root, Transform3D.IDENTITY, groups, victims, keep, deep, remerge, single)
	if single and not groups.is_empty():
		# one mesh, a surface per material: one render instance to move, not a dozen
		var am2 := ArrayMesh.new()
		var shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for key in groups:
			var g2: Dictionary = groups[key]
			var arrays2 := []
			arrays2.resize(Mesh.ARRAY_MAX)
			arrays2[Mesh.ARRAY_VERTEX] = g2.v
			arrays2[Mesh.ARRAY_NORMAL] = g2.n
			arrays2[Mesh.ARRAY_COLOR] = g2.c
			am2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays2)
			am2.surface_set_material(am2.get_surface_count() - 1, g2.mat if g2.mat.get_shader_parameter("use_vcolor") == true else vc_variant(g2.mat))
			if int(g2.shadow) != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mi2 := MeshInstance3D.new()
		mi2.mesh = am2
		mi2.cast_shadow = shadow
		root.add_child(mi2)
		for v in victims:
			v.get_parent().remove_child(v)
			v.queue_free()
		return
	for key in groups:
		var g: Dictionary = groups[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g.v
		arrays[Mesh.ARRAY_NORMAL] = g.n
		arrays[Mesh.ARRAY_COLOR] = g.c
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = g.mat if g.mat.get_shader_parameter("use_vcolor") == true else vc_variant(g.mat)
		mi.cast_shadow = g.shadow
		root.add_child(mi)
	for v in victims:
		v.get_parent().remove_child(v)
		v.queue_free()


static var _flat_cache := {}
static var _distant_material: ShaderMaterial


## Snapshot an articulated model without changing its joints or meshes.
static func bake_mesh(root: Node3D) -> ArrayMesh:
	var groups := {}
	var unused := []
	_collect(root, Transform3D.IDENTITY, groups, unused, [], true, true, true)
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for group: Dictionary in groups.values():
		vertices.append_array(group.v)
		normals.append_array(group.n)
		var material: ShaderMaterial = group.mat
		var base: Color = material.get_shader_parameter("col_a")
		if int(material.get_shader_parameter("pattern")) == CAMO:
			base = base.lerp(material.get_shader_parameter("col_b"), 0.35)
		base = base.srgb_to_linear()
		var scale := VC_K
		if material.get_shader_parameter("use_vcolor") == true:
			scale = float(material.get_shader_parameter("vcolor_k"))
		for tint: Color in group.c:
			colors.append(Color(base.r * tint.r * scale, base.g * tint.g * scale, base.b * tint.b * scale, 1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# At this distance cloth weave and metal wear are subpixel. Keep the
	# uniform, skin and equipment colours in one surface for each shared pose.
	if _distant_material == null:
		_distant_material = ShaderMaterial.new()
		var simple := Shader.new()
		simple.code = "shader_type spatial; void fragment() { ALBEDO = COLOR.rgb; ROUGHNESS = 0.9; }"
		_distant_material.shader = simple
	mesh.surface_set_material(0, _distant_material)
	# Hundreds of instances share this mesh. Weld identical vertex attributes
	# once so the GPU can reuse transformed vertices without changing the pose.
	var indexed := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var tool := SurfaceTool.new()
		tool.create_from(mesh, surface)
		tool.index()
		tool.set_material(mesh.surface_get_material(surface))
		tool.commit(indexed)
	var importer := ImporterMesh.new()
	for surface in indexed.get_surface_count():
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, indexed.surface_get_arrays(surface), [], {}, indexed.surface_get_material(surface))
	importer.generate_lods(25.0, 60.0, [])
	return importer.get_mesh()


## A surface as an unindexed triangle list [verts, normals, colours or null].
## The shared primitives (boxes, cylinders, spheres) are flattened once and
## kept, so building a soldier or a house only appends arrays.
static func _flat(mesh: Mesh, si: int) -> Array:
	var cacheable := mesh is PrimitiveMesh or mesh is BevelMesh or mesh is BodyMesh
	var key := mesh.get_instance_id() * 8 + si
	if cacheable and _flat_cache.has(key):
		return _flat_cache[key]
	var arr := mesh.surface_get_arrays(si)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var c = arr[Mesh.ARRAY_COLOR]
	var hasc: bool = c != null and (c as PackedColorArray).size() == v.size()
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx != null and not (idx as PackedInt32Array).is_empty():
		var ii: PackedInt32Array = idx
		var v2 := PackedVector3Array()
		var n2 := PackedVector3Array()
		var c2 := PackedColorArray()
		v2.resize(ii.size())
		n2.resize(ii.size())
		if hasc:
			c2.resize(ii.size())
		for k in ii.size():
			var j := ii[k]
			v2[k] = v[j]
			n2[k] = n[j]
			if hasc:
				c2[k] = (c as PackedColorArray)[j]
		v = v2
		n = n2
		c = c2
	var out := [v, n, c if hasc else null]
	if cacheable:
		_flat_cache[key] = out
	return out


static func _collect(node: Node, xf: Transform3D, groups: Dictionary, victims: Array, keep: Array, deep := true, remerge := false, single := false) -> void:
	for c in node.get_children():
		if c in keep or not (c is Node3D):
			continue
		if not (c is MeshInstance3D) and not (c as Node3D).visible:
			continue  # a hidden attachment (the slung rifle on a corpse) stays out of the bake
		var cx: Transform3D = xf * (c as Node3D).transform
		if c is MeshInstance3D and c.get_child_count() == 0:
			var mi := c as MeshInstance3D
			if mi.mesh == null or not mi.visible:
				continue
			# every surface must be one of ours (the override, or each surface's own material)
			var mats := []
			var ok := true
			for si0 in mi.mesh.get_surface_count():
				var m0 = mi.material_override if mi.material_override else mi.mesh.surface_get_material(si0)
				var sm0 := m0 as ShaderMaterial
				var vc0: bool = sm0 != null and sm0.get_shader_parameter("use_vcolor") == true
				if sm0 == null or not (sm0.shader == shader() or sm0 == _foliage or (vc0 and sm0.shader == shader())) or (vc0 and not remerge):
					ok = false
					break
				mats.append(sm0)
			if ok and not mats.is_empty():
				var tint = mi.get_instance_shader_parameter("tint")
				# the tint uniform is sRGB (source_color); vertex colours are read as linear
				var col: Color = (tint as Color).srgb_to_linear() if tint is Color else Color(1, 1, 1)
				var nb := Transform3D(cx.basis.inverse().transposed(), Vector3.ZERO)
				for si in mi.mesh.get_surface_count():
					var sm: ShaderMaterial = mats[si]
					var vc: bool = sm.get_shader_parameter("use_vcolor") == true
					var key := str(sm.get_instance_id()) if single else "%d|%d" % [sm.get_instance_id(), mi.cast_shadow]
					if not groups.has(key):
						groups[key] = {"mat": sm, "shadow": mi.cast_shadow, "v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray()}
					var g: Dictionary = groups[key]
					if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
						g.shadow = mi.cast_shadow
					# plain triangle lists, so parts are appended with native array
					# ops (no index offsetting loop in script)
					var fa := _flat(mi.mesh, si)
					var verts: PackedVector3Array = fa[0]
					g.v.append_array(cx * verts)
					g.n.append_array(nb * (fa[1] as PackedVector3Array))
					if vc and fa[2] != null and (fa[2] as PackedColorArray).size() == verts.size():
						g.c.append_array(fa[2])
					else:
						# in the scale the merged material reads it back at (see VC_K)
						var fk := 1.0
						if vc:
							var kp = sm.get_shader_parameter("vcolor_k")
							fk = 1.0 / float(kp) if kp != null else 1.0
						elif sm.shader == shader():
							fk = 1.0 / VC_K
						var cols := PackedColorArray()
						cols.resize(verts.size())
						cols.fill(Color(col.r * fk, col.g * fk, col.b * fk, col.a))
						g.c.append_array(cols)
				victims.append(mi)
				continue
		if deep:
			_collect(c, cx, groups, victims, keep, deep, remerge, single)


static var _netting: ShaderMaterial


## Camouflage netting: ragged holes (discard) so it throws dappled shadows.
static func netting() -> ShaderMaterial:
	if _netting == null:
		var sh := Shader.new()
		sh.code = NETTING_SHADER
		_netting = ShaderMaterial.new()
		_netting.shader = sh
	return _netting


static var _netting_tent: ShaderMaterial


## The same netting for a net whose mesh is already shaped (pitched over a
## pole, draped to the ground): no sag of its own.
static func netting_tent() -> ShaderMaterial:
	if _netting_tent == null:
		_netting_tent = netting().duplicate() as ShaderMaterial
		_netting_tent.set_shader_parameter("sag", 0.0)
	return _netting_tent


static func _preset(kind: String) -> Dictionary:
	match kind:
		"steel":
			return {"pattern": PAINT, "col_a": Color(0.25, 0.26, 0.27), "col_b": Color(0.4, 0.38, 0.35), "rough": 0.6, "metal": 0.6, "bump": 0.8, "grime": 0.4, "rust": 0.3}
		"floor_tiles":
			return {"pattern": TILES, "col_a": Color(0.45, 0.42, 0.38), "col_b": Color(0.3, 0.28, 0.25), "col_c": Color(0.52, 0.4, 0.32), "rough": 0.7, "bump": 0.8, "grime": 0.0}
		"car_paint":
			return {"pattern": PAINT, "col_a": Color(0.5, 0.5, 0.5), "col_b": Color(0.35, 0.33, 0.3), "rough": 0.38, "metal": 0.3, "bump": 0.4, "grime": 0.9, "rust": 0.45}
		"wood_painted":
			return {"pattern": WOOD, "col_a": Color(0.3, 0.34, 0.22), "col_b": Color(0.22, 0.25, 0.16), "rough": 0.8, "bump": 1.0, "grime": 0.7}
		"gunmetal_w":
			return {"pattern": PAINT, "col_a": Color(0.14, 0.14, 0.135), "col_b": Color(0.34, 0.33, 0.31), "rough": 0.52, "metal": 0.55, "bump": 0.35, "grime": 0.2}
		"plaster":
			return {"pattern": PLASTER, "col_a": Color(0.74, 0.69, 0.6), "col_b": Color(0.6, 0.57, 0.5), "col_c": Color(0.5, 0.33, 0.26), "col_d": Color(0.45, 0.42, 0.37), "rough": 0.92, "bump": 1.2, "grime": 0.7}
		"brick":
			return {"pattern": BRICK, "col_a": Color(0.56, 0.3, 0.21), "col_b": Color(0.62, 0.58, 0.52), "col_c": Color(0.42, 0.24, 0.17), "rough": 0.9, "bump": 1.4, "grime": 0.6}
		"concrete":
			return {"pattern": CONCRETE, "col_a": Color(0.52, 0.51, 0.48), "col_b": Color(0.36, 0.35, 0.32), "rough": 0.9, "bump": 0.9, "grime": 0.8}
		"concrete_floor":
			return {"pattern": CONCRETE, "col_a": Color(0.42, 0.41, 0.38), "col_b": Color(0.3, 0.28, 0.25), "rough": 0.9, "bump": 0.6, "grime": 0.0}
		"sandbag":
			return {"pattern": SANDBAG, "col_a": Color(0.62, 0.55, 0.39), "col_b": Color(0.45, 0.39, 0.26), "rough": 0.95, "bump": 2.2, "grime": 0.6}
		"wood":
			return {"pattern": WOOD, "col_a": Color(0.5, 0.37, 0.23), "col_b": Color(0.34, 0.24, 0.14), "rough": 0.85, "bump": 1.2, "grime": 0.5}
		"wood_dark":
			return {"pattern": WOOD, "col_a": Color(0.33, 0.25, 0.17), "col_b": Color(0.22, 0.16, 0.1), "rough": 0.88, "bump": 1.2, "grime": 0.5}
		"bank":
			# earth thrown up and left a season: settled smooth, gone over with
			# moss and thin grass (berms, the mound over a dugout)
			return {"pattern": EARTH, "col_a": Color(0.3, 0.28, 0.18), "col_b": Color(0.2, 0.19, 0.12), "rough": 0.97, "bump": 0.45, "grime": 0.0, "scale": 0.6}
		"earth":
			return {"pattern": EARTH, "col_a": Color(0.33, 0.26, 0.17), "col_b": Color(0.22, 0.17, 0.11), "rough": 0.97, "bump": 1.6, "grime": 0.0}
		"stone":
			return {"pattern": STONE, "col_a": Color(0.58, 0.55, 0.5), "col_b": Color(0.42, 0.4, 0.36), "col_c": Color(0.5, 0.46, 0.4), "rough": 0.9, "bump": 2.0, "grime": 0.7}
		"rubble":
			return {"pattern": STONE, "col_a": Color(0.55, 0.52, 0.47), "col_b": Color(0.36, 0.34, 0.3), "col_c": Color(0.5, 0.33, 0.25), "rough": 0.95, "bump": 2.4, "grime": 0.5, "scale": 2.0}
		"roof_tile":
			return {"pattern": BRICK, "col_a": Color(0.5, 0.22, 0.14), "col_b": Color(0.36, 0.17, 0.11), "col_c": Color(0.44, 0.2, 0.13), "rough": 0.82, "bump": 1.8, "grime": 0.55, "scale": 0.7}
		"corrugated":
			return {"pattern": CORRUGATED, "col_a": Color(0.5, 0.51, 0.49), "col_b": Color(0.42, 0.24, 0.12), "rough": 0.55, "metal": 0.5, "bump": 1.0, "grime": 0.6}
		"canvas":
			return {"pattern": CANVAS, "col_a": Color(0.36, 0.38, 0.25), "col_b": Color(0.28, 0.3, 0.2), "rough": 0.95, "bump": 0.8, "grime": 0.5}
		"canvas_white":
			return {"pattern": CANVAS, "col_a": Color(0.85, 0.84, 0.79), "col_b": Color(0.7, 0.68, 0.62), "rough": 0.95, "bump": 0.8, "grime": 0.5}
		"bark":
			return {"pattern": BARK, "col_a": Color(0.32, 0.25, 0.18), "col_b": Color(0.18, 0.14, 0.1), "rough": 0.95, "bump": 2.0, "grime": 0.2}
		"paint":
			return {"pattern": PAINT, "col_a": Color(0.6, 0.6, 0.6), "col_b": Color(0.38, 0.37, 0.35), "rough": 0.45, "metal": 0.15, "bump": 0.6, "grime": 0.7}
		"aircraft":
			# clean matte low-visibility grey, the panel lines left to the light
			return {"pattern": PAINT, "col_a": Color(0.5, 0.52, 0.54), "col_b": Color(0.44, 0.46, 0.48), "rough": 0.62, "metal": 0.2, "bump": 0.25, "grime": 0.0, "rust": 0.0}
		"metal_dark":
			return {"pattern": PAINT, "col_a": Color(0.17, 0.17, 0.17), "col_b": Color(0.35, 0.33, 0.3), "rough": 0.5, "metal": 0.6, "bump": 0.5, "grime": 0.3}
		"burnt":
			return {"pattern": PAINT, "col_a": Color(0.085, 0.08, 0.075), "col_b": Color(0.2, 0.17, 0.15), "rough": 0.9, "metal": 0.25, "bump": 1.2, "grime": 0.2, "rust": 0.3, "scale": 1.6}
		"plain":
			return {"pattern": PLAIN, "col_a": Color(0.55, 0.55, 0.55), "rough": 0.85, "bump": 0.2, "grime": 0.3}
		"plain_dark":
			return {"pattern": PLAIN, "col_a": Color(0.18, 0.18, 0.18), "rough": 0.8, "bump": 0.2, "grime": 0.2}
		"rubber":
			return {"pattern": PLAIN, "col_a": Color(0.07, 0.07, 0.07), "rough": 0.85, "bump": 0.3, "grime": 0.4}
		"glass":
			return {"pattern": PLAIN, "col_a": Color(0.08, 0.1, 0.12), "rough": 0.08, "metal": 0.4, "bump": 0.0, "grime": 0.0}
		"track":
			return {"pattern": TRACK, "col_a": Color(0.13, 0.12, 0.11), "col_b": Color(0.3, 0.27, 0.23), "rough": 0.7, "metal": 0.5, "bump": 2.0, "grime": 0.5, "local_space": true}
		"camo_army":
			return {"pattern": CAMO, "col_a": Color(0.4, 0.4, 0.3), "col_b": Color(0.33, 0.35, 0.25), "col_c": Color(0.43, 0.38, 0.28), "col_d": Color(0.25, 0.24, 0.19), "scale": 10.0, "rough": 0.92, "bump": 0.5, "grime": 0.3, "local_space": true}
		"camo_rebel":
			return {"pattern": CAMO, "col_a": Color(0.5, 0.45, 0.34), "col_b": Color(0.42, 0.36, 0.26), "col_c": Color(0.38, 0.37, 0.3), "col_d": Color(0.3, 0.26, 0.19), "scale": 8.0, "rough": 0.92, "bump": 0.5, "grime": 0.3, "local_space": true}
		"camo_tank":
			return {"pattern": CAMO, "col_a": Color(0.3, 0.32, 0.23), "col_b": Color(0.27, 0.29, 0.21), "col_c": Color(0.31, 0.29, 0.22), "col_d": Color(0.21, 0.21, 0.17), "scale": 0.7, "rough": 0.68, "metal": 0.25, "bump": 0.6, "grime": 0.9, "local_space": true}
		"camo_tank_rebel":
			return {"pattern": CAMO, "col_a": Color(0.46, 0.42, 0.32), "col_b": Color(0.41, 0.37, 0.28), "col_c": Color(0.44, 0.39, 0.29), "col_d": Color(0.32, 0.29, 0.22), "scale": 0.6, "rough": 0.68, "metal": 0.25, "bump": 0.6, "grime": 0.9, "local_space": true}
		"fabric":
			return {"pattern": CANVAS, "col_a": Color(0.6, 0.6, 0.6), "col_b": Color(0.48, 0.48, 0.48), "scale": 3.0, "rough": 0.95, "bump": 0.4, "grime": 0.2, "local_space": true}
		"hesco":
			return {"pattern": HESCO, "col_a": Color(0.6, 0.55, 0.42), "col_b": Color(0.4, 0.35, 0.26), "col_c": Color(0.22, 0.21, 0.2), "rough": 0.95, "bump": 1.6, "grime": 0.8}
		"hesco_cell":
			# one filled HESCO cell (a mesh of its own): the geotextile behind the
			# welded mesh, no cell seams (the cell's own edges are the seams)
			return {"pattern": HESCO, "col_a": Color(0.6, 0.55, 0.42), "col_b": Color(0.42, 0.37, 0.27), "col_c": Color(0.24, 0.23, 0.21), "rough": 0.95, "bump": 1.4, "grime": 1.0, "cell_w": 0.0}
		"precast":
			# precast and cast-in-place defence concrete: smooth formwork faces,
			# weathered and rain-streaked, none of the pitting of old walls
			return {"pattern": CONCRETE, "col_a": Color(0.56, 0.55, 0.52), "col_b": Color(0.38, 0.37, 0.34), "rough": 0.88, "bump": 0.7, "grime": 0.85, "pitting": 0.15, "seams": 0.0}
		"rust_steel":
			return {"pattern": PAINT, "col_a": Color(0.32, 0.2, 0.12), "col_b": Color(0.22, 0.2, 0.18), "rough": 0.85, "metal": 0.35, "bump": 1.0, "grime": 0.5, "rust": 1.0}
		"wire":
			# galvanised barbed and razor wire, dulled and spotted with rust
			return {"pattern": PAINT, "col_a": Color(0.44, 0.44, 0.42), "col_b": Color(0.56, 0.55, 0.52), "rough": 0.42, "metal": 0.75, "bump": 0.0, "grime": 0.2, "rust": 0.35, "scale": 4.0}
		"bag":
			return {"pattern": CANVAS, "col_a": Color(0.5, 0.45, 0.33), "col_b": Color(0.4, 0.36, 0.26), "scale": 1.6, "rough": 0.97, "bump": 0.8, "grime": 0.7, "local_space": true, "use_vcolor": true}
		"canvas_l":
			return {"pattern": CANVAS, "col_a": Color(0.42, 0.4, 0.29), "col_b": Color(0.33, 0.31, 0.22), "scale": 4.0, "rough": 0.95, "bump": 0.6, "grime": 0.2, "local_space": true}
		"suit":
			# close-woven uniform cloth (a sneaking suit, a field jacket): a faint
			# weave and soft folds, a little sheen
			return {"pattern": CANVAS, "col_a": Color(0.5, 0.5, 0.5), "col_b": Color(0.43, 0.43, 0.43), "scale": 5.0, "rough": 0.78, "bump": 0.35, "grime": 0.3, "local_space": true}
		"armor":
			# moulded armour and helmet shells: smooth, matte, scuffed
			return {"pattern": PLAIN, "col_a": Color(0.5, 0.5, 0.5), "rough": 0.58, "bump": 0.25, "grime": 0.25, "local_space": true}
		"webbing":
			return {"pattern": CANVAS, "col_a": Color(0.2, 0.2, 0.2), "col_b": Color(0.16, 0.16, 0.16), "scale": 6.0, "rough": 0.9, "bump": 0.5, "grime": 0.2, "local_space": true}
		"wood_l":
			return {"pattern": WOOD, "col_a": Color(0.3, 0.2, 0.12), "col_b": Color(0.2, 0.13, 0.08), "scale": 3.0, "rough": 0.6, "bump": 0.4, "grime": 0.0, "local_space": true}
		"skin":
			return {"pattern": SKIN, "col_a": Color(0.8, 0.62, 0.5), "rough": 0.6, "bump": 0.0, "grime": 0.0, "local_space": true}
		"gunmetal":
			return {"pattern": PAINT, "col_a": Color(0.15, 0.15, 0.145), "col_b": Color(0.36, 0.35, 0.33), "rough": 0.52, "metal": 0.55, "bump": 0.35, "grime": 0.0, "local_space": true, "scale": 3.0}
		"boot":
			return {"pattern": CANVAS, "col_a": Color(0.16, 0.13, 0.1), "col_b": Color(0.11, 0.09, 0.07), "scale": 6.0, "rough": 0.75, "bump": 0.4, "grime": 0.0, "local_space": true}
	return {"pattern": PLAIN, "col_a": Color(0.6, 0.6, 0.6), "rough": 0.85}


const SURFACE_SHADER := """
shader_type spatial;
render_mode specular_schlick_ggx;

uniform int pattern = 0;
uniform vec3 col_a : source_color = vec3(0.6);
uniform vec3 col_b : source_color = vec3(0.4);
uniform vec3 col_c : source_color = vec3(0.5);
uniform vec3 col_d : source_color = vec3(0.2);
uniform float scale = 1.0;
uniform float rough = 0.85;
uniform float metal = 0.0;
uniform float bump = 1.0;
uniform float grime = 0.5;
uniform float rust = 0.0;
uniform float pitting = 1.0;  // concrete: how much of the old pitting shows
uniform float seams = 1.0;  // concrete: the formwork joints
uniform float cell_w = 1.05;  // HESCO: the width of a cell
uniform bool local_space = false;
uniform bool use_vcolor = false;
uniform float vcolor_k = 1.0;  // merged parts: the vertex colour is stored scaled down (Mats.VC_K)
// paving (Mats.paving): a shell hole or a trench punches through it, as through the roads
uniform bool crater_cut = false;
uniform sampler2DArray crater_tex : filter_linear, repeat_disable;
// TERRAIN_TEXTURE_HELPER
uniform sampler2D trench_tex : hint_default_black, filter_linear, repeat_disable;
uniform float crater_half = 256.0;
uniform sampler2D noise_tex : filter_linear_mipmap_anisotropic, repeat_enable;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform vec3 pofs = vec3(0.0);

varying vec3 tp;
varying vec3 tn;
varying vec3 wpos;
varying vec3 seed;

float h12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
// Value noise with one feature per unit, read from a mipmapped tileable
// texture: the GPU filters it, so fine detail averages out with distance
// instead of aliasing and crawling as the camera moves.
float tnoise(vec2 p) { return (texture(noise_tex, p * 0.0625).r - 0.467) * 1.103 + 0.5; }  // matched to the old procedural noise's spread
float tfbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * tnoise(p); p = p * 2.03 + 17.1; a *= 0.5; } return v; }
// How much of a feature `period` units across survives at this pixel
// footprint: 1 when it spans 5+ pixels, 0 when it's under 1.5.
float keep(float period, float px) { return smoothstep(1.5, 5.0, period / max(px, 1e-5)); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	seed = MODEL_MATRIX[3].xyz;
	if (local_space) {
		tp = VERTEX + pofs;
		tn = NORMAL;
	} else {
		tp = wpos;
		tn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

void fragment() {
	if (crater_cut) {
		vec2 cuv = (wpos.xz + crater_half) / (crater_half * 2.0);
		if (terrain_height(crater_tex, cuv) < -0.07 || texture(trench_tex, cuv).r > 0.5) {
			discard;
		}
	}
	vec3 an = abs(tn);
	vec2 uv;
	if (an.y > an.x && an.y > an.z) { uv = tp.xz; }
	else if (an.x > an.z) { uv = vec2(tp.z, tp.y); }
	else { uv = vec2(tp.x, tp.y); }
	vec2 off = vec2(h12(seed.xz * 0.37), h12(seed.zx * 0.71)) * 37.0;
	uv *= scale;
	// pattern units per pixel here (how fine a detail can still be drawn)
	vec2 fw = fwidth(uv);
	float px = max(fw.x, fw.y);
	// thresholds on filtered noise soften with distance rather than flicker
	float sw = clamp(px * 1.5, 0.0, 0.3);
	vec3 col = col_a;
	float h = 0.5;
	float r = rough;
	float m = metal;
	if (pattern == 1 || pattern == 2) {
		// brick (pattern 2 = plaster with chipped areas showing brick)
		vec2 bs = vec2(0.25, 0.085);
		float kb = keep(bs.y, px);
		vec2 q = uv / bs;
		float row = floor(q.y);
		q.x += mod(row, 2.0) * 0.5;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float mx = smoothstep(0.0, 0.05, f.x) * smoothstep(1.0, 0.95, f.x);
		float my = smoothstep(0.0, 0.14, f.y) * smoothstep(1.0, 0.86, f.y);
		float b = mix(0.8, mx * my, kb);
		float rb = mix(0.5, h12(cell + off), kb);
		vec3 bc = (pattern == 1 ? mix(col_a, col_c, rb) : mix(col_c, col_c * 0.75, rb)) * (0.85 + 0.3 * tnoise(uv * 41.0));
		vec3 mortar = (pattern == 1 ? col_b : col_b * 0.9) * (0.9 + 0.2 * tnoise(uv * 27.0));
		vec3 brick = mix(mortar, bc, b);
		float bh = b * 0.7 + tnoise(uv * 35.0) * 0.15;
		if (pattern == 1) {
			col = brick; h = bh;
		} else {
			float n = tfbm(uv * 0.9 + off);
			float chip = smoothstep(0.69 - sw, 0.72 + sw, n + (1.0 - smoothstep(0.0, 1.2, wpos.y)) * 0.06);
			vec3 pl = col_a * (0.88 + 0.18 * tfbm(uv * 2.3 + off));
			float streak = tfbm(vec2(uv.x * 3.0, uv.y * 0.35) + off);
			pl = mix(pl, col_d, smoothstep(0.5, 0.8, streak) * 0.45);
			col = mix(pl, brick, chip);
			h = mix(0.9 + tnoise(uv * 18.0) * 0.1, bh * 0.6, chip);
			r = mix(rough, 0.95, chip);
		}
	} else if (pattern == 3) {
		col = col_a * (0.86 + 0.22 * tfbm(uv * 2.1 + off));
		float st = tfbm(uv * 0.6 + off * 0.3);
		col = mix(col, col_b, smoothstep(0.42, 0.78, st) * 0.75);
		// rain streaks running down from the top
		float rs3 = tfbm(vec2(uv.x * 4.0, uv.y * 0.3) + off * 0.5);
		col = mix(col, col_b * 0.85, smoothstep(0.55, 0.8, rs3) * 0.35);
		vec2 g = abs(fract(uv / vec2(2.0, 1.25)) - 0.5);
		float seam = smoothstep(0.485, 0.497, max(g.x, g.y)) * keep(0.1, px) * seams;
		float pits = smoothstep(0.93, 0.97, h12(floor(uv * 60.0) + off)) * keep(0.05, px) * pitting;
		col *= 1.0 - seam * 0.35 - pits * 0.1;
		h = 1.0 - seam * 0.6 - pits * 0.5 + tnoise(uv * 25.0) * 0.08;
	} else if (pattern == 4) {
		vec2 bs = vec2(0.58, 0.2);
		vec2 q = uv / bs;
		float row = floor(q.y);
		q.x += mod(row, 2.0) * 0.5 + h12(vec2(row, off.x)) * 0.3;
		vec2 f = fract(q) - 0.5;
		float d = length(f * vec2(1.0, 1.7));
		float bulge = mix(0.6, clamp(1.0 - d * d * 2.4, 0.0, 1.0), keep(bs.y, px));
		float weave = ((sin(uv.x * 420.0) * sin(uv.y * 420.0)) * 0.5 + 0.5 - 0.5) * keep(0.015, px) + 0.5;
		col = mix(col_b, col_a, bulge * 0.7 + 0.3) * (0.88 + 0.18 * tnoise(uv * 13.0 + off) + weave * 0.04);
		h = bulge;
		r = 0.97;
	} else if (pattern == 5) {
		float pw = 0.19;
		float row = floor(uv.y / pw);
		float fy = fract(uv.y / pw);
		float gap = mix(0.85, smoothstep(0.0, 0.06, fy) * smoothstep(1.0, 0.94, fy), keep(pw * 0.5, px));
		float grain = tfbm(vec2(uv.x * 1.3 + row * 7.3, uv.y * 30.0));
		col = mix(col_b, col_a, grain) * (0.85 + 0.25 * mix(0.5, h12(vec2(row, off.y)), keep(pw, px)));
		col *= 0.5 + 0.5 * gap;
		h = gap * (0.8 + grain * 0.2);
	} else if (pattern == 6) {
		float c1 = tfbm(uv * 1.0 + off);
		float c2 = tfbm(uv * 1.25 + off + 13.0);
		float c3 = tfbm(uv * 1.6 + off + 29.0);
		col = col_a;
		col = mix(col, col_b, smoothstep(0.5 - sw, 0.53 + sw, c1));
		col = mix(col, col_c, smoothstep(0.56 - sw, 0.59 + sw, c2));
		col = mix(col, col_d, smoothstep(0.62 - sw, 0.65 + sw, c3));
		col *= 0.92 + 0.12 * tnoise(uv * 23.0);
		h = 0.5 + tnoise(uv * 30.0) * 0.2;
	} else if (pattern == 7) {
		col = col_a * (0.9 + 0.14 * tnoise(uv * 7.0 + off));
		float wear = smoothstep(0.68 - sw, 0.74 + sw, tfbm(uv * 3.5 + off));
		col = mix(col, col_b, wear);
		m = mix(metal, 0.85, wear);
		r = mix(rough, 0.35, wear);
		float rs = tfbm(vec2(uv.x * 5.0, uv.y * 0.6) + off) * (0.4 + rust);
		col = mix(col, vec3(0.32, 0.17, 0.08), smoothstep(0.55, 0.8, rs) * (0.08 + rust * 0.7));
		h = 0.6 - wear * 0.3 + tnoise(uv * 50.0) * 0.05;
	} else if (pattern == 8) {
		float n = tfbm(uv * 1.7 + off);
		col = mix(col_b, col_a, n) * (0.85 + 0.25 * tnoise(uv * 19.0));
		float peb = smoothstep(0.86, 0.93, h12(floor(uv * 14.0) + off)) * keep(0.07, px);
		col = mix(col, col * 1.45 + vec3(0.015), peb * 0.6);  // stones a shade lighter than the soil
		h = n * 0.7 + peb * 0.4;
	} else if (pattern == 9) {
		float ridge = mix(0.5, 0.5 + 0.5 * sin(uv.x * 6.2831 / 0.09), keep(0.09, px));
		col = col_a * (0.82 + 0.18 * ridge) * (0.9 + 0.15 * tnoise(uv * 4.0 + off));
		float rs = tfbm(vec2(uv.x * 2.0, uv.y * 0.4) + off);
		col = mix(col, col_b, smoothstep(0.55, 0.85, rs) * 0.8);
		h = ridge;
	} else if (pattern == 10) {
		float weave = ((sin(uv.x * 380.0) * sin(uv.y * 380.0)) * 0.5) * keep(0.0165, px) + 0.5;
		float fold = tfbm(uv * 1.3 + off);
		col = mix(col_b, col_a, fold) * (0.95 + weave * 0.08);
		h = fold * 0.8 + weave * 0.1;
	} else if (pattern == 11) {
		vec2 bs = vec2(0.5, 0.3);
		float kb = keep(bs.y, px);
		vec2 q = uv / bs;
		float row = floor(q.y);
		q.x += h12(vec2(row, 3.7 + off.x));
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float e = mix(0.82, smoothstep(0.0, 0.08, f.x) * smoothstep(1.0, 0.92, f.x) * smoothstep(0.0, 0.12, f.y) * smoothstep(1.0, 0.88, f.y), kb);
		float rb = mix(0.5, h12(cell + off), kb);
		vec3 sc = mix(col_a, col_c, rb) * (0.82 + 0.3 * tnoise(uv * 13.0));
		col = mix(col_b * 0.8, sc, e);
		h = e * (0.75 + 0.25 * tnoise(uv * 9.0 + rb * 10.0));
	} else if (pattern == 12) {
		float fib = tfbm(vec2(uv.x * 9.0, uv.y * 0.8) + off);
		col = mix(col_b, col_a, fib);
		h = fib;
	} else if (pattern == 13) {
		float link = fract(uv.y / 0.16);
		float ridge = mix(0.6, smoothstep(0.1, 0.2, link) * smoothstep(0.9, 0.8, link), keep(0.08, px));
		col = mix(col_a, col_b, (1.0 - ridge) * 0.4) * (0.85 + 0.25 * tnoise(uv * 20.0));
		h = ridge;
	} else if (pattern == 15) {
		float kt = keep(0.45, px);
		vec2 q = uv / 0.45;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float e = mix(0.9, smoothstep(0.0, 0.04, f.x) * smoothstep(1.0, 0.96, f.x) * smoothstep(0.0, 0.04, f.y) * smoothstep(1.0, 0.96, f.y), keep(0.12, px));
		float rb = mix(0.5, h12(cell + off), kt);
		vec3 tc = mix(col_a, col_c, mix(0.3, step(0.5, mod(cell.x + cell.y, 2.0)) * 0.6, kt)) * (0.85 + 0.25 * rb);
		float dirt = tfbm(uv * 0.8 + off);
		tc = mix(tc, col_b, smoothstep(0.45, 0.75, dirt) * 0.6);
		col = mix(col_b * 0.7, tc, e);
		h = e * 0.8 + tnoise(uv * 40.0) * 0.05;
		r = mix(0.95, rough - dirt * 0.2, e);
	} else if (pattern == 16) {
		// (cell 0: a single cell modelled on its own - no seams, no bulge drawn in)
		float has_cell = step(0.01, cell_w);
		vec2 q = uv / max(cell_w, 0.01);
		vec2 hcell = floor(q) * has_cell;
		vec2 f = fract(q);
		vec2 c2 = f - 0.5;
		float bulge = mix(0.5, clamp(1.0 - dot(c2, c2) * 2.2, 0.0, 1.0), has_cell);
		float seam = (1.0 - smoothstep(0.0, 0.035, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)))) * keep(0.1, px) * has_cell;
		vec2 wq = fract(uv / 0.075);
		float wire = (1.0 - smoothstep(0.0, 0.12, min(min(wq.x, 1.0 - wq.x), min(wq.y, 1.0 - wq.y)))) * keep(0.04, px) + 0.15 * (1.0 - keep(0.04, px));
		float stain = tfbm(uv * 1.3 + off);
		vec3 fab = mix(col_a, col_b, smoothstep(0.35, 0.8, stain) * 0.8) * (0.85 + 0.25 * mix(0.5, h12(hcell + off), keep(max(cell_w, 0.01), px) * has_cell));
		col = mix(fab, col_c, max(wire * 0.55, seam * 0.8));
		h = bulge * 0.8 - wire * 0.1 - seam * 0.5;
		m = mix(0.0, 0.6, wire * 0.6);
	} else if (pattern == 14) {
		col = col_a * (0.95 + 0.08 * tnoise(uv * 30.0));
		h = 0.5;
	} else {
		col = col_a * (0.92 + 0.12 * tnoise(uv * 5.0 + off));
		h = 0.5 + tnoise(uv * 20.0) * 0.1;
	}
	col *= tint.rgb;
	if (use_vcolor) { col *= COLOR.rgb * vcolor_k; }
	// broad, soft variation across a surface (sun-bleached, weathered, damp
	// patches): large enough never to alias, it keeps big walls from looking flat
	float macro = tfbm(wpos.xz * 0.11 + wpos.y * 0.07 + off * 0.2);
	col *= 0.88 + 0.24 * macro;
	// grime and dust toward the ground
	float low = 1.0 - smoothstep(0.0, 0.9, wpos.y);
	float gn = tnoise(uv * 2.0 + off);
	col = mix(col, col * 0.62 + vec3(0.05, 0.04, 0.02), low * grime * (0.6 + 0.4 * gn));
	ALBEDO = col;
	ROUGHNESS = clamp(r + (macro - 0.5) * 0.12, 0.05, 1.0);
	METALLIC = m;
	SPECULAR = 0.4;
	// bump mapping from the pattern height (surface gradient); the height is
	// band-limited above, so its screen-space slope is stable under motion
	if (bump > 0.0) {
		vec3 dpdx = dFdx(VERTEX);
		vec3 dpdy = dFdy(VERTEX);
		float dhx = dFdx(h);
		float dhy = dFdy(h);
		vec3 r1 = cross(dpdy, NORMAL);
		vec3 r2 = cross(NORMAL, dpdx);
		float det = dot(dpdx, r1);
		vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad * bump * 0.02);
	}
}
"""


const FOLIAGE_SHADER := """
shader_type spatial;
render_mode cull_disabled;

instance uniform vec4 tint : source_color = vec4(0.2, 0.32, 0.14, 1.0);
uniform float wind = 1.0;
uniform bool use_vcolor = false;
// on fire (a burning tree's own copy, see Structure._apply_char): the leaves
// shrivel brown, blacken and burn away, glowing at the edges while it burns
uniform float scorch = 0.0;
uniform float embers = 0.0;

varying vec3 lpos;
varying float shade;

float h13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float n3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h13(i), h13(i + vec3(1, 0, 0)), f.x), mix(h13(i + vec3(0, 1, 0)), h13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h13(i + vec3(0, 0, 1)), h13(i + vec3(1, 0, 1)), f.x), mix(h13(i + vec3(0, 1, 1)), h13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float lump = n3(wp * 1.3) * 0.55 + n3(wp * 3.1) * 0.25;
	VERTEX += NORMAL * (lump - 0.4) * 0.5;
	float t = TIME * 1.3 + wp.x * 0.11 + wp.z * 0.07;
	float sway = (sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.3) * wind * 0.06 * clamp(VERTEX.y + 1.0, 0.0, 2.0);
	VERTEX.x += sway;
	VERTEX.z += sway * 0.6;
	lpos = wp;
	shade = clamp(NORMAL.y * 0.35 + 0.65, 0.0, 1.0);
}

void fragment() {
	// ragged, leafy edges: holes open up where the surface turns away from
	// the eye (and from the sun, so the shadows are dappled too)
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	// detail finer than a few pixels is replaced by its average, so the holes
	// and leaf speckle don't fizz as the camera moves
	float px = max(length(fwidth(lpos)), 1e-4);
	float k6 = smoothstep(1.5, 5.0, (1.0 / 6.0) / px);
	float k15 = smoothstep(1.5, 5.0, (1.0 / 15.0) / px);
	float holes = mix(0.5, n3(lpos * 6.0 + 11.0), k6) * 0.6 + mix(0.5, n3(lpos * 15.0), k15) * 0.4;
	if (rim > 0.12 && holes < (rim - 0.12) * 1.25) {
		discard;
	}
	float burnt = holes - scorch * 1.15 + 0.3;
	if (scorch > 0.0 && burnt < 0.0) {
		discard;
	}
	float leaves = mix(0.5, n3(lpos * 9.0), smoothstep(1.5, 5.0, (1.0 / 9.0) / px));
	float gaps = mix(0.5, n3(lpos * 4.2 + 7.0), smoothstep(1.5, 5.0, (1.0 / 4.2) / px));
	vec3 c = (use_vcolor ? COLOR.rgb : tint.rgb) * (0.7 + 0.5 * leaves);
	c = mix(c, c * vec3(1.15, 1.1, 0.7), smoothstep(0.55, 0.8, gaps) * 0.5);
	if (scorch > 0.0) {
		// (linear colours: a withered brown, then soot)
		vec3 dry = vec3(0.06, 0.03, 0.01) * (0.7 + 0.5 * leaves);
		c = mix(c, dry, smoothstep(0.0, 0.3, scorch + (gaps - 0.5) * 0.3));
		c = mix(c, vec3(0.006, 0.005, 0.004), smoothstep(0.25, 0.7, scorch + (leaves - 0.5) * 0.4));
		float edge = 1.0 - smoothstep(0.0, 0.05, burnt);
		EMISSION = vec3(1.0, 0.32, 0.05) * embers * edge * (0.9 + 0.6 * sin(TIME * 7.0 + lpos.x * 3.0 + lpos.y * 5.0));
	}
	ALBEDO = c * (0.55 + 0.45 * shade);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.35, 0.42, 0.18) * (1.0 - scorch);
	AO = 0.55 + 0.45 * shade;
	AO_LIGHT_AFFECT = 0.6;
	float bh = leaves * 0.6 + gaps * 0.4;
	vec3 dpdx = dFdx(VERTEX); vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(bh); float dhy = dFdy(bh);
	vec3 r1 = cross(dpdy, NORMAL); vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.06);
}
"""


const NETTING_SHADER := """
shader_type spatial;
render_mode cull_disabled;
instance uniform vec4 tint : source_color = vec4(0.3, 0.34, 0.2, 1.0);
uniform float sag = 0.45;  // a flat net slung between poles sags in the middle
varying vec3 wp;
float h12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h12(i), h12(i + vec2(1.0, 0.0)), f.x), mix(h12(i + vec2(0.0, 1.0)), h12(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	vec2 u = UV * 2.0 - 1.0;
	VERTEX.y -= (1.0 - u.x * u.x) * (1.0 - u.y * u.y) * sag;
	VERTEX.y += sin(VERTEX.x * 0.9 + TIME * 0.7) * 0.03;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wp.xz;
	float n = vn(p * 1.9) * 0.55 + vn(p * 5.3) * 0.45;
	float g = vn(p * 13.0);
	vec2 u = UV * 2.0 - 1.0;
	float edge = max(abs(u.x), abs(u.y));
	if (n + g * 0.3 < 0.47 + smoothstep(0.8, 1.0, edge) * 0.3) { discard; }
	vec3 c = tint.rgb * (0.65 + 0.55 * g);
	c = mix(c, c * vec3(1.25, 1.05, 0.7), step(0.62, vn(p * 3.1 + 9.0)) * 0.6);
	// the garnish: darker brown and near-black scraps knotted in, breaking it up
	c = mix(c, c * vec3(0.62, 0.5, 0.38), step(0.6, vn(p * 2.3 + 31.0)) * 0.75);
	c = mix(c, c * 0.35, step(0.7, vn(p * 4.1 + 57.0)) * 0.6);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	BACKLIGHT = c * 0.5;
}
"""
