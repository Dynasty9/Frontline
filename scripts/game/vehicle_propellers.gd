class_name VehiclePropellers
extends RefCounted
## Shared profiled blades, ogive spinners and feathered blur.
static var _discs := {}

static func disc_material(nb: int, hub: float) -> ShaderMaterial:
	var key := "%d_%.2f" % [nb, hub]
	if _discs.has(key):
		return _discs[key]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float nb = 4.0;
uniform float hub = 0.2;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float disc = smoothstep(1.0, 0.86, r) * smoothstep(hub * 0.8, hub + 0.1, r);
	float dens = mix(1.0, 0.45, smoothstep(0.3, 1.0, r));
	float ghost = pow(0.5 + 0.5 * cos(a * nb - TIME * 9.0 + r * 1.5), 8.0);
	ALBEDO = vec3(0.075, 0.075, 0.08);
	ALPHA = disc * dens * (0.065 + 0.07 * ghost);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("nb", float(nb))
	m.set_shader_parameter("hub", hub)
	_discs[key] = m
	return m


## One propeller blade along d (unit, in the disc plane of a shaft along local
## z), from radius r0 to r1: `prof` is [span fraction, chord] pairs, root to
## tip; twisted from blade angle p0 at the root to p1 at the tip, `th` its
## thickness as a fraction of chord. It pulls toward local z = fw and its
## leading edge leads as the pivot turns about +z.
static func blade(_key: String, d: Vector3, r0: float, r1: float, prof: Array, p0: float, p1: float, th: float, fw := -1.0) -> ArrayMesh:
	var f := Vector3(0, 0, fw)
	var t := Vector3(0, 0, 1).cross(d).normalized()
	var rings := []
	for i in range(0, prof.size(), 2):
		var u: float = prof[i]
		var c: float = prof[i + 1]
		var pa := lerpf(p0, p1, u)
		var cdir := (-t * cos(pa) - f * sin(pa)).normalized()
		var up := d.cross(cdir).normalized()
		if up.dot(f) < 0.0:
			up = -up
		var le := d * lerpf(r0, r1, u) - cdir * c * 0.4
		rings.append(VehicleAirfoils.section(le, c, th * c * lerpf(1.5, 0.7, u), up, 0.0, 1.0, cdir))
	return VehicleProfiles.loft(rings, 40.0)


## A spinner: an ogive from its back plate forward (toward z = fw * len) to a
## blunt point, a short skirt behind the plate.
static func spinner(_key: String, r: float, len: float, fw := -1.0, bluntness := 0.0) -> ArrayMesh:
	var prof := [[0.0, 1.0], [0.2, 0.98], [0.42, 0.9], [0.62, 0.74], [0.8, 0.5], [0.92, 0.27 + bluntness * 0.2], [0.985, 0.08 + bluntness * 0.2], [1.0, 0.0]]
	var rings := [circle(-fw * r * 0.25, r * 0.98)]
	for q in prof:
		var rr: float = r * float(q[1])
		rings.append(circle(fw * len * float(q[0]), rr))
	return VehicleProfiles.loft(rings, 50.0)


## A propeller at pos (its pivot turned by rot): a spinner, `nb` blades of
## profile `prof` out to radius r in a "Blades" node (turned a0 round the
## shaft), a "Blur" disc; the pivot goes in k.wheels and spins about its z.
## fw = 1 builds it pulling toward its own +z (a mirror-image, counter-rotating
## proprotor on a pivot turned round).
static func build(k: VehicleModels, p: Node3D, key: String, pos: Vector3, rot: Vector3, r: float, nb: int, prof: Array, p0: float, p1: float, th: float,
		spin_r: float, spin_len: float, bcol: Color, scol: Color, a0 := 0.0, fw := -1.0, bluntness := 0.0) -> Node3D:
	var pv := k._pivot(p, pos)
	pv.rotation = rot
	k._add(pv, spinner(key + "_sp", spin_r, spin_len, fw, bluntness), "paint", scol, Vector3.ZERO)
	var bl := k._pivot(pv, Vector3.ZERO)
	bl.name = "Blades"
	bl.rotation.z = a0
	for i in nb:
		var a := TAU * float(i) / float(nb)
		var d := Vector3(sin(a), cos(a), 0)
		k._add(bl, blade("%s_b%d" % [key, i], d, spin_r * 0.7, r, prof, p0, p1, th, fw), "paint", bcol, Vector3.ZERO)
	if not k.burnt:
		var disc := MeshInstance3D.new()
		disc.name = "Blur"
		var pm := PlaneMesh.new()
		pm.size = Vector2(r, r) * 2.0
		pm.orientation = PlaneMesh.FACE_Z
		disc.mesh = pm
		disc.material_override = disc_material(nb, spin_r / r)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pv.add_child(disc)
	k.wheels.append(pv)
	return pv


static func circle(z: float, radius: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		ring.append(Vector3(cos(angle) * radius, sin(angle) * radius, z))
	return ring
