class_name Res
extends RefCounted
## Cached primitive meshes and materials so thousands of parts share resources.

static var _mats := {}
static var _meshes := {}


static func mat(c: Color, rough := 0.9, glow := 0.0, unshaded := false) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [c.to_html(true), rough, glow, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if c.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = glow
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static func vcol_mat(unshaded := true, additive := false) -> StandardMaterial3D:
	var key := "vcol|%s|%s" % [unshaded, additive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mats[key] = m
	return m


## Soft round sprite material for smoke / dust / fire particles (uses the
## particle colour as tint, billboarded towards the camera).
static func puff_mat(additive := false, lit := false) -> StandardMaterial3D:
	var key := "puff|%s|%s" % [additive, lit]
	if _mats.has(key):
		return _mats[key]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mats[key] = m
	return m


static func plane(s: float) -> PlaneMesh:
	var key := "pl%.3f" % s
	if _meshes.has(key):
		return _meshes[key]
	var m := PlaneMesh.new()
	m.size = Vector2(s, s)
	_meshes[key] = m
	return m


static var _ring_shader: Shader


## Flat, anti-aliased selection ring drawn on the ground: a thin team-coloured line.
static func ring_mat(c: Color) -> ShaderMaterial:
	var key := "ring|" + c.to_html()
	if _mats.has(key):
		return _mats[key]
	if _ring_shader == null:
		_ring_shader = Shader.new()
		_ring_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 col : source_color = vec4(0.4, 0.7, 1.0, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float w = fwidth(r) * 1.2;
	// a crisp thin ring with a soft dark edge so it reads on any ground
	float ring = smoothstep(0.84 - w, 0.84 + w, r) * (1.0 - smoothstep(0.92 - w, 0.92 + w, r));
	float shade = smoothstep(0.78, 0.84, r) * (1.0 - smoothstep(0.92, 0.98, r));
	ALBEDO = mix(vec3(0.0), col.rgb, ring);
	ALPHA = clamp(ring * 0.95 + shade * 0.35, 0.0, 1.0) * col.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _ring_shader
	m.set_shader_parameter("col", c)
	m.render_priority = 2
	_mats[key] = m
	return m


## A box. Anything thicker than a sheet gets chamfered edges (BevelMesh), so
## every edge catches a highlight; very thin plates stay plain boxes.
static func box(s: Vector3) -> Mesh:
	var key := "b%.3f,%.3f,%.3f" % [s.x, s.y, s.z]
	if _meshes.has(key):
		return _meshes[key]
	var mn := minf(s.x, minf(s.y, s.z))
	var m: Mesh
	if mn < 0.012:
		var bm := BoxMesh.new()
		bm.size = s
		m = bm
	else:
		m = BevelMesh.make(s, clampf(mn * 0.16, 0.0025, 0.035))
	_meshes[key] = m
	return m


## The size of a box made by box() (ZERO for anything else).
static func box_size(m: Mesh) -> Vector3:
	if m is BoxMesh:
		return (m as BoxMesh).size
	if m is BevelMesh:
		return (m as BevelMesh).size
	return Vector3.ZERO


static func sphere(r: float, segs := 10) -> SphereMesh:
	var key := "s%.3f,%d" % [r, segs]
	if _meshes.has(key):
		return _meshes[key]
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = maxi(4, segs / 2)
	_meshes[key] = m
	return m


## A hemisphere standing on its base at the origin (helmets, caps).
static func dome(r: float, segs := 12) -> SphereMesh:
	var key := "d%.3f,%d" % [r, segs]
	if _meshes.has(key):
		return _meshes[key]
	var m := SphereMesh.new()
	m.radius = r
	m.height = r
	m.is_hemisphere = true
	m.radial_segments = segs
	m.rings = maxi(3, segs / 3)
	_meshes[key] = m
	return m


static func capsule(r: float, h: float, segs := 10) -> CapsuleMesh:
	var key := "c%.3f,%.3f,%d" % [r, h, segs]
	if _meshes.has(key):
		return _meshes[key]
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = segs
	m.rings = 3
	_meshes[key] = m
	return m


static func cyl(top: float, bottom: float, h: float, segs := 10) -> CylinderMesh:
	var key := "c%.3f,%.3f,%.3f,%d" % [top, bottom, h, segs]
	if _meshes.has(key):
		return _meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	_meshes[key] = m
	return m


static func prism(s: Vector3) -> PrismMesh:
	var key := "p%.3f,%.3f,%.3f" % [s.x, s.y, s.z]
	if _meshes.has(key):
		return _meshes[key]
	var m := PrismMesh.new()
	m.size = s
	_meshes[key] = m
	return m


static func torus(inner: float, outer: float) -> TorusMesh:
	var key := "t%.3f,%.3f" % [inner, outer]
	if _meshes.has(key):
		return _meshes[key]
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 6
	_meshes[key] = m
	return m


static func quad(s: Vector2) -> QuadMesh:
	var key := "q%.3f,%.3f" % [s.x, s.y]
	if _meshes.has(key):
		return _meshes[key]
	var m := QuadMesh.new()
	m.size = s
	_meshes[key] = m
	return m


## Creates a MeshInstance3D child of `parent`.
static func mi(parent: Node, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.rotation = rot
	if not shadow:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n


static func vary(c: Color, amt: float, rng: RandomNumberGenerator) -> Color:
	var k := 1.0 + rng.randf_range(-amt, amt)
	return Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1), c.a)
