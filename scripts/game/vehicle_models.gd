class_name VehicleModels
extends RefCounted
## Procedural vehicle models (tanks, pickups, trucks, helicopters, light
## vehicles). Sloped armour comes from lofted convex solids; every part gets a
## surface from Mats. `burnt` builds the same shape as a charred wreck.
## Local -Z is forward; y = 0 is the ground.

static var _cache := {}

var root: Node3D
var burnt := false
var turret: Node3D
var mg_tip: Node3D  # the machine gun's muzzle (shots start here)
var gun_tip: Node3D  # the main gun's muzzle
var rotor: Node3D
var tail_rotor: Node3D
var blur: MeshInstance3D
var blades: Node3D
var wheels: Array = []
var elev: Node3D  # an artillery barrel or rocket launcher that rises to fire (rotation.x)
## More rotors (a tandem's rear one, a coaxial's second, a drone's four or
## six): pivots spinning about Y. Each may hold a "Blades" node (shown slow)
## and a "Blur" disc (shown fast), like the main rotor.
var rotors: Array = []


## A civilian car: 0 saloon, 1 hatchback, 2 pickup, 3 van, 4 estate.
static func build_car(variant: int, col: Color, is_burnt := false) -> VehicleModels:
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k.burnt = is_burnt
	k._car(variant % 5, col)
	return k


static func build(kind: String, team: int, seed: int, is_burnt := false) -> VehicleModels:
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k.burnt = is_burnt
	k._baking = true
	# a vehicle may share another's model (a variant), named in its definition
	var mk := kind
	if Defs.VEHICLES.has(kind):
		mk = String(Defs.VEHICLES[kind].get("model", kind))
	# the aircraft builders in scripts/game/vehicles/ come first: until one of
	# them builds a key, the older model below stands
	if VmCore.build(k, mk, team, seed) or VmGunship.build(k, mk, team, seed) or VmAttack.build(k, mk, team, seed) or VmFighter.build(k, mk, team, seed):
		k._merge_parts(k.root, Vector3.ZERO)
		k._baked()
		return k
	match mk:
		"tank":
			k._tank(team)
		"old_tank":
			k._old_tank(team)
		"technical":
			k._technical(team, seed)
		"heli":
			k._heli(team, false)
		"gunship":
			k._heli(team, true)
		"humvee":
			k._humvee(team)
		"jet":
			k._jet(team)  # (superseded by VmFighter once it builds one)
		"a10":
			k._a10(team)
		"ac130":
			k._ac130(team)
		"apc", "btr":
			k._apc(team)
		"ifv":
			k._ifv(team)
		"aa_tech":
			k._technical(team, seed, true)
		"truck":
			# the supply convoy: a HEMTT for the Coalition, a Zamak for the Rebels
			if not ((team == 0 and VmNato.build(k, "hemtt_cargo", team, seed)) or (team == 1 and VmIndep.build(k, "zamak_cargo", team, seed))):
				k._truck(team)
		_:
			# the rest of the roster lives in scripts/game/vehicles/, by family
			if not (VmNato.build(k, mk, team, seed) or VmCsat.build(k, mk, team, seed) or VmIndep.build(k, mk, team, seed)
					or VmCiv.build(k, mk, team, seed) or VmHeli.build(k, mk, team, seed) or VmPlane.build(k, mk, team, seed)
					or VmBoat.build(k, mk, team, seed) or VmShips.build(k, mk, team, seed)):
				k._truck(team)
	k._merge_parts(k.root, Vector3.ZERO)
	k._baked()
	return k


## Every model key the families build (for the Field Manual's model pages).
static func family_keys() -> Array[String]:
	var out: Array[String] = []
	for ks in [VmNato.KEYS, VmCsat.KEYS, VmIndep.KEYS, VmCiv.KEYS, VmHeli.KEYS, VmPlane.KEYS, VmBoat.KEYS, VmShips.KEYS]:
		out.append_array(ks)
	return out


## Each moving part (hull, turret, every wheel, rotor) becomes one mesh with a
## surface per material: the detail costs vertices, not draw calls. The
## camouflage stays continuous across the parts.
func _merge_parts(n: Node3D, off: Vector3) -> void:
	for c in n.get_children():
		if c is Node3D and not (c is MeshInstance3D):
			_merge_parts(c, off + (c as Node3D).position)
	if _parts.has(n):
		# the parts made for it, straight into its mesh (see _add)
		var bake := Mats.Bake.new(true)
		for pt: Array in _parts[n]:
			var xf: Transform3D = Transform3D(pt[7], pt[4]) if pt[7] is Basis else Mats.place(pt[4], pt[5], pt[6])
			bake.part(pt[0], pt[8] if pt[8] is ShaderMaterial else pt[1], xf, pt[2] if pt[2] != Color(1, 1, 1) else null, pt[3])
		_parts.erase(n)
		bake.commit(n)
	var before := n.get_child_count()
	Mats.merge_static(n, [blur] if blur else [], false, false, true)
	for i in range(before, n.get_child_count()):
		var mi := n.get_child(i) as MeshInstance3D
		if mi and off != Vector3.ZERO:
			Mats.set_inst(mi, &"pofs", off)
	if not burnt:
		Mats.add_distance_lod(n, 100.0, [blur] if blur else [])


# --- mesh helpers ----------------------------------------------------------------

static func _v2(a: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in range(0, a.size(), 2):
		p.append(Vector2(a[i], a[i + 1]))
	return p


## Ring in the XZ plane at height y.
static func ring_y(pts: PackedVector2Array, y: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for p in pts:
		r.append(Vector3(p.x, y, p.y))
	return r


## Ring in the ZY plane (a side profile) at x.
static func ring_x(pts: PackedVector2Array, x: float) -> PackedVector3Array:
	var r := PackedVector3Array()
	for p in pts:
		r.append(Vector3(x, p.y, p.x))
	return r


static func _centroid(r: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in r:
		c += p
	return c / maxf(1.0, r.size())


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-10:
		return
	if cr.dot((a + b + c) / 3.0 - inside) > 0.0:
		var t := b
		b = c
		c = t
		cr = -cr
	var n := -cr.normalized()
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


## Lofts between successive convex rings (same point count) and caps both ends.
static func solid(rings: Array, key: String) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in rings.size() - 1:
		var r0: PackedVector3Array = rings[k]
		var r1: PackedVector3Array = rings[k + 1]
		var cen := (_centroid(r0) + _centroid(r1)) * 0.5
		var n := r0.size()
		for i in n:
			var j := (i + 1) % n
			_tri(st, r0[i], r0[j], r1[j], cen)
			_tri(st, r0[i], r1[j], r1[i], cen)
	for e in [0, rings.size() - 1]:
		var r: PackedVector3Array = rings[e]
		var other: PackedVector3Array = rings[1 if e == 0 else rings.size() - 2]
		var inside := _centroid(other)
		for i in range(1, r.size() - 1):
			_tri(st, r[0], r[i], r[i + 1], inside)
	# (what st.commit() makes, keeping the arrays: see Mats.keep_arrays)
	var arrays := st.commit_to_arrays()
	var m := ArrayMesh.new()
	if arrays.size() == Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_VERTEX] != null and not (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		Mats.keep_arrays(m, arrays)
	_cache[key] = m
	return m


static func loft(key: String, bottom: Array, top: Array, y0: float, y1: float) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	return solid([ring_y(_v2(bottom), y0), ring_y(_v2(top), y1)], key)


static func extrude_x(key: String, profile: Array, x0: float, x1: float) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var p := _v2(profile)
	return solid([ring_x(p, x0), ring_x(p, x1)], key)


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var key := "cap%.2f,%.2f" % [r, h]
	if _cache.has(key):
		return _cache[key]
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 16
	m.rings = 6
	_cache[key] = m
	return m


# --- part helpers ----------------------------------------------------------------

## A part of the model on one of our surfaces, tinted to `col`. While the
## model is built it's only noted down (and the note returned: see _turn,
## _unshadow, _restyle for changing it afterwards): _merge_parts puts it
## straight into its piece's merged mesh without making a node of it (a tank
## is four hundred parts). Otherwise it's made as a node, and that returned.
func _add(parent: Node3D, mesh: Mesh, kind: String, col, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> Variant:
	var k := kind
	if burnt:
		k = "burnt" if kind != "glass" else "burnt"
	var t := Mats.tint_for(k, col) if col is Color and not burnt else Color(1, 1, 1)
	var pt := [mesh, Mats.get_mat(k), t, shadow, pos, rot, scl, null, null]
	if not _baking:
		return _add_node(parent, pt)
	if not _parts.has(parent):
		_parts[parent] = []
	(_parts[parent] as Array).append(pt)
	return pt


var _baking := false  # build(): parts are noted down for _merge_parts (see _add)
## node -> its parts noted down: [mesh, material, tint, shadow, position, rotation,
## scale, basis (or null: from rotation and scale), material set over it (or null)]
var _parts := {}


## A noted part as a node (as every part once was made).
func _add_node(parent: Node3D, pt: Array) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = pt[0]
	mi.position = pt[4]
	mi.rotation = pt[5]
	mi.scale = pt[6]
	if not pt[3]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	# (Mats.apply)
	Mats.set_material(mi, pt[1])
	if pt[2] != Color(1, 1, 1):
		Mats.set_inst(mi, &"tint", pt[2])
	# continuous camouflage across parts: offset the local pattern space
	var off: Vector3 = pt[4]
	var p := parent
	while p and p != root:
		off += p.position
		p = p.get_parent() as Node3D
	Mats.set_inst(mi, &"pofs", off)
	if pt[7] is Basis:
		mi.basis = pt[7]
	if pt[8] is Material:
		mi.material_override = pt[8]
	return mi


## A part turned by `b` after it was made (laid from a to b): its basis.
func _turn(part: Variant, b: Basis) -> void:
	if part is Array:
		part[7] = b
	else:
		(part as MeshInstance3D).basis = b


## A part that casts no shadow after all.
func _unshadow(part: Variant) -> void:
	if part is Array:
		part[3] = false
	else:
		(part as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A part given a surface of its own after it was made (a tinted canopy).
func _restyle(part: Variant, m: Material) -> void:
	if part is Array:
		part[8] = m
	else:
		(part as MeshInstance3D).material_override = m


## Moves pv's parts and nodes onto its parent, where they already are, and
## drops pv (VmBoat._bake: a tilted assembly the Field Manual would stand
## wrongly).
func _fold(pv: Node3D) -> void:
	var par := pv.get_parent() as Node3D
	for c in pv.get_children():
		var n := c as Node3D
		var t: Transform3D = pv.transform * n.transform
		pv.remove_child(n)
		par.add_child(n)
		n.transform = t
	if _parts.has(pv):
		if not _parts.has(par):
			_parts[par] = []
		for pt: Array in _parts[pv]:
			# (placed as the part's node, set to the same transform, would be)
			var t2: Transform3D = pv.transform * (Transform3D(pt[7], pt[4]) if pt[7] is Basis else Mats.place(pt[4], pt[5], pt[6]))
			pt[4] = t2.origin
			pt[7] = t2.basis
			(_parts[par] as Array).append(pt)
		_parts.erase(pv)
	par.remove_child(pv)
	pv.free()


## Every part on surface `from` put on `to` (VmFighter._repaint), noted down or not.
func _swap_noted(from: Material, to: Material) -> void:
	for parent: Node3D in _parts:
		for pt: Array in _parts[parent]:
			if Mats.base_of(pt[8] if pt[8] is Material else pt[1]) == from:
				pt[8] = to


## The model is built: a part noted down on a node _merge_parts didn't reach
## is made as a node after all, as it always was.
func _baked() -> void:
	_baking = false
	for parent: Node3D in _parts:
		for pt: Array in _parts[parent]:
			_add_node(parent, pt)
	_parts.clear()


func _box(parent: Node3D, s: Vector3, pos: Vector3, kind: String, col = null, rot := Vector3.ZERO, shadow := true) -> Variant:
	return _add(parent, Res.box(s), kind, col, pos, rot, Vector3.ONE, shadow)


func _cyl(parent: Node3D, r0: float, r1: float, h: float, pos: Vector3, rot: Vector3, kind: String, col = null, segs := 12, shadow := true) -> Variant:
	return _add(parent, Res.cyl(r0, r1, h, segs), kind, col, pos, rot, Vector3.ONE, shadow)


## An empty marker at a muzzle.
func _tip(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


## Wheel with tyre and hub on a spinning pivot (axis X).
func _wheel(parent: Node3D, pos: Vector3, r: float, w: float, hub_kind := "gunmetal_w", hub_col = null) -> Node3D:
	var pv := _pivot(parent, pos)
	# the tyre: a tread band with rounded shoulders, the sidewalls set in a little
	_cyl(pv, r * 0.93, r * 0.93, w, Vector3.ZERO, Vector3(0, 0, PI / 2), "rubber", null, 20)
	_cyl(pv, r, r, w * 0.8, Vector3.ZERO, Vector3(0, 0, PI / 2), "rubber", null, 20)
	# the rim set into it, a ring of wheel nuts and the hub
	_cyl(pv, r * 0.58, r * 0.58, w + 0.02, Vector3.ZERO, Vector3(0, 0, PI / 2), hub_kind, hub_col, 14, false)
	_cyl(pv, r * 0.3, r * 0.34, w + 0.07, Vector3.ZERO, Vector3(0, 0, PI / 2), hub_kind, hub_col, 10, false)
	_cyl(pv, r * 0.13, r * 0.13, w + 0.11, Vector3.ZERO, Vector3(0, 0, PI / 2), "gunmetal_w", null, 8, false)
	for i in 8:
		var a := TAU * i / 8.0
		_cyl(pv, r * 0.035, r * 0.035, w + 0.09, Vector3(0, sin(a) * r * 0.42, cos(a) * r * 0.42), Vector3(0, 0, PI / 2), "gunmetal_w", null, 6, false)
	wheels.append(pv)
	return pv


func _team_mark(parent: Node3D, team: int, pos: Vector3, s: Vector3) -> void:
	if burnt or team < 0:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = Res.box(s)
	mi.position = pos
	# a subdued identification panel, not a toy's coloured sticker
	var tc: Color = Defs.TEAM_COLORS[team]
	mi.material_override = Res.mat(tc.lerp(Color(0.25, 0.25, 0.25), 0.62).darkened(0.5), 0.85)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# --- tanks -----------------------------------------------------------------------

func _tank(team: int) -> void:
	var cam := "camo_tank"
	var m := root
	# lower hull between the tracks
	_add(m, loft("t_low", [-1.1, -2.95, 1.1, -2.95, 1.1, 3.0, -1.1, 3.0], [-1.1, -3.4, 1.1, -3.4, 1.1, 3.15, -1.1, 3.15], 0.38, 1.0), cam, null, Vector3.ZERO)
	# upper hull with a long sloped glacis
	_add(m, loft("t_up", [-1.74, -3.4, 1.74, -3.4, 1.74, 3.2, -1.74, 3.2], [-1.64, -1.85, 1.64, -1.85, 1.64, 3.15, -1.64, 3.15], 0.98, 1.52), cam, null, Vector3.ZERO)
	# tracks: side profile extruded across x
	var tp := [-3.45, 0.62, -3.0, 0.06, 2.85, 0.06, 3.35, 0.58, 3.1, 0.98, -3.1, 0.98]
	for s in [-1.0, 1.0]:
		_add(m, extrude_x("t_trk", tp, -0.32, 0.32), "track", null, Vector3(s * 1.43, 0, 0))
		for i in 7:
			_wheel(m, Vector3(s * 1.45, 0.38, -2.45 + i * 0.8), 0.33, 0.5)
		_wheel(m, Vector3(s * 1.45, 0.56, -3.05), 0.3, 0.45)
		_wheel(m, Vector3(s * 1.45, 0.6, 2.95), 0.34, 0.45)
		# side skirts: bolted panels with gaps between them, the front one angled
		for i in 6:
			_box(m, Vector3(0.07, 0.62, 0.9), Vector3(s * 1.78, 0.74, -2.0 + i * 0.92), cam)
			_box(m, Vector3(0.09, 0.05, 0.06), Vector3(s * 1.8, 1.0, -2.0 + i * 0.92), "gunmetal_w", null, Vector3.ZERO, false)
		_box(m, Vector3(0.07, 0.5, 0.9), Vector3(s * 1.78, 0.8, -2.95), cam, null, Vector3(0.35, 0, 0))
		_box(m, Vector3(0.22, 0.05, 6.4), Vector3(s * 1.66, 1.06, 0.1), cam)
		# headlights and tow hooks
		_box(m, Vector3(0.22, 0.12, 0.1), Vector3(s * 1.2, 1.12, -3.36), "gunmetal_w")
		_box(m, Vector3(0.12, 0.16, 0.2), Vector3(s * 0.7, 0.62, -3.42), "gunmetal_w")
	# rear deck: engine grilles and exhaust
	_box(m, Vector3(2.6, 0.04, 1.6), Vector3(0, 1.53, 2.2), "gunmetal_w")
	_box(m, Vector3(2.4, 0.5, 0.06), Vector3(0, 1.15, 3.2), "gunmetal_w")
	_cyl(m, 0.24, 0.24, 0.12, Vector3(0, 1.53, -1.55), Vector3.ZERO, cam, null, 12)
	# turret
	turret = _pivot(m, Vector3(0, 1.55, 0.4))
	var tb := [-0.5, -1.95, 0.5, -1.95, 1.3, -1.15, 1.4, 1.0, 1.15, 1.9, -1.15, 1.9, -1.4, 1.0, -1.3, -1.15]
	var tt := [-0.42, -1.72, 0.42, -1.72, 1.14, -1.0, 1.24, 0.95, 1.04, 1.74, -1.04, 1.74, -1.24, 0.95, -1.14, -1.0]
	_add(turret, loft("t_tur", tb, tt, 0.0, 0.74), cam, null, Vector3.ZERO)
	# bustle rack with stowage
	_box(turret, Vector3(2.2, 0.05, 0.6), Vector3(0, 0.25, 2.15), "gunmetal_w")
	_box(turret, Vector3(2.2, 0.35, 0.04), Vector3(0, 0.45, 2.45), "gunmetal_w")
	# stowage bins along the turret sides, the commander's independent sight
	for s in [-1.0, 1.0]:
		_box(turret, Vector3(0.3, 0.4, 1.0), Vector3(s * 1.35, 0.36, 1.0), cam, null, Vector3(0, s * -0.12, 0))
	_box(turret, Vector3(0.3, 0.32, 0.32), Vector3(-0.25, 0.92, -0.15), cam)
	_box(turret, Vector3(0.24, 0.16, 0.02), Vector3(-0.25, 0.95, -0.32), "glass")
	_box(turret, Vector3(0.6, 0.06, 0.5), Vector3(-0.55, 0.77, 0.5), cam)
	_box(turret, Vector3(0.8, 0.4, 0.45), Vector3(-0.55, 0.5, 2.15), "canvas", Color(0.33, 0.35, 0.24), Vector3(0, 0.1, 0))
	_box(turret, Vector3(0.6, 0.32, 0.42), Vector3(0.45, 0.46, 2.18), "canvas", Color(0.4, 0.38, 0.28), Vector3(0, -0.15, 0))
	# mantlet, barrel, fume extractor, muzzle
	_box(turret, Vector3(0.95, 0.52, 0.4), Vector3(0, 0.36, -1.95), cam)
	_cyl(turret, 0.1, 0.13, 3.9, Vector3(0, 0.38, -3.85), Vector3(PI / 2, 0, 0), "paint", Color(0.3, 0.33, 0.24), 12)
	_cyl(turret, 0.17, 0.17, 0.75, Vector3(0, 0.38, -3.25), Vector3(PI / 2, 0, 0), "paint", Color(0.3, 0.33, 0.24), 12)
	_cyl(turret, 0.13, 0.13, 0.18, Vector3(0, 0.38, -5.75), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	gun_tip = _tip(turret, Vector3(0, 0.38, -5.86))
	# coaxial MG beside the main gun
	_cyl(turret, 0.022, 0.022, 0.32, Vector3(0.34, 0.3, -2.28), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	mg_tip = _tip(turret, Vector3(0.34, 0.3, -2.45))
	# commander cupola + MG, loader hatch, gunner sight
	_cyl(turret, 0.36, 0.38, 0.26, Vector3(0.55, 0.86, 0.35), Vector3.ZERO, cam, null, 14)
	_cyl(turret, 0.3, 0.3, 0.06, Vector3(0.55, 1.02, 0.35), Vector3(0.0, 0, -0.5), cam, null, 12)
	_box(turret, Vector3(0.1, 0.14, 0.8), Vector3(0.55, 1.1, -0.05), "gunmetal_w")
	_cyl(turret, 0.28, 0.28, 0.08, Vector3(-0.55, 0.78, 0.5), Vector3.ZERO, cam, null, 12)
	_box(turret, Vector3(0.36, 0.3, 0.45), Vector3(-0.72, 0.88, -1.15), cam)
	_box(turret, Vector3(0.3, 0.2, 0.02), Vector3(-0.72, 0.9, -1.38), "glass")
	# smoke grenade launchers
	for s in [-1.0, 1.0]:
		for i in 4:
			_cyl(turret, 0.05, 0.05, 0.25, Vector3(s * (1.12 + i * 0.02), 0.55 + (i % 2) * 0.1, -1.05 + i * 0.12), Vector3(-0.9, 0, s * 0.4), "gunmetal_w", null, 6, false)
		_cyl(turret, 0.012, 0.012, 2.3, Vector3(s * 0.9, 1.85, 1.6), Vector3.ZERO, "gunmetal_w", null, 4, false)
	_team_mark(turret, team, Vector3(1.22, 0.42, 0.3), Vector3(0.04, 0.26, 0.8))
	_team_mark(turret, team, Vector3(-1.22, 0.42, 0.3), Vector3(0.04, 0.26, 0.8))


func _old_tank(team: int) -> void:
	var cam := "camo_tank_rebel"
	var m := root
	_add(m, loft("o_low", [-1.08, -2.9, 1.08, -2.9, 1.08, 2.95, -1.08, 2.95], [-1.08, -3.25, 1.08, -3.25, 1.08, 3.05, -1.08, 3.05], 0.42, 0.95), cam, null, Vector3.ZERO)
	_add(m, loft("o_up", [-1.62, -3.25, 1.62, -3.25, 1.62, 3.1, -1.62, 3.1], [-1.55, -2.15, 1.55, -2.15, 1.55, 3.05, -1.55, 3.05], 0.93, 1.38), cam, null, Vector3.ZERO)
	var tp := [-3.35, 0.7, -2.85, 0.06, 2.75, 0.06, 3.25, 0.66, 3.0, 0.92, -3.0, 0.92]
	for s in [-1.0, 1.0]:
		_add(m, extrude_x("o_trk", tp, -0.3, 0.3), "track", null, Vector3(s * 1.38, 0, 0))
		for i in 5:
			_wheel(m, Vector3(s * 1.4, 0.44, -2.25 + i * 1.12), 0.42, 0.48, "paint", Color(0.42, 0.38, 0.27))
		_wheel(m, Vector3(s * 1.4, 0.62, -2.95), 0.3, 0.42)
		# fenders and external fuel tanks
		_box(m, Vector3(0.66, 0.05, 6.3), Vector3(s * 1.4, 0.96, 0.0), cam)
		for i in 3:
			_box(m, Vector3(0.42, 0.4, 0.6), Vector3(s * 1.42, 1.2, 0.6 + i * 0.68), "steel", Color(0.32, 0.3, 0.23))
	# rear fuel drums and unditching log
	for s in [-1.0, 1.0]:
		_cyl(m, 0.28, 0.28, 0.9, Vector3(s * 0.7, 1.68, 3.15), Vector3(PI / 2, 0, 0), "steel", Color(0.3, 0.32, 0.24))
	_cyl(m, 0.14, 0.14, 2.9, Vector3(0, 1.5, 3.45), Vector3(0, 0, PI / 2), "bark")
	_box(m, Vector3(2.4, 0.04, 1.4), Vector3(0, 1.39, 2.0), "gunmetal_w")
	# dome turret
	turret = _pivot(m, Vector3(0, 1.4, 0.25))
	_cyl(turret, 1.15, 1.2, 0.18, Vector3(0, 0.05, 0), Vector3.ZERO, cam, null, 20)
	_add(turret, Res.sphere(1.0, 20), cam, null, Vector3(0, 0.12, 0.05), Vector3.ZERO, Vector3(1.22, 0.62, 1.32))
	_box(turret, Vector3(0.62, 0.48, 0.5), Vector3(0, 0.32, -1.18), cam)
	_cyl(turret, 0.09, 0.11, 3.6, Vector3(0, 0.34, -3.15), Vector3(PI / 2, 0, 0), "paint", Color(0.44, 0.4, 0.29), 10)
	_cyl(turret, 0.14, 0.14, 0.4, Vector3(0, 0.34, -4.1), Vector3(PI / 2, 0, 0), "paint", Color(0.44, 0.4, 0.29), 10)
	gun_tip = _tip(turret, Vector3(0, 0.34, -4.32))
	_cyl(turret, 0.02, 0.02, 0.28, Vector3(0.24, 0.28, -1.5), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	mg_tip = _tip(turret, Vector3(0.24, 0.28, -1.65))
	_box(turret, Vector3(0.25, 0.25, 0.25), Vector3(-0.45, 0.62, -1.0), "gunmetal_w")
	_cyl(turret, 0.3, 0.32, 0.18, Vector3(-0.45, 0.72, 0.35), Vector3.ZERO, cam, null, 12)
	_cyl(turret, 0.28, 0.28, 0.16, Vector3(0.5, 0.72, 0.35), Vector3.ZERO, cam, null, 12)
	# DShK on the loader hatch
	_box(turret, Vector3(0.1, 0.14, 0.7), Vector3(0.5, 0.95, 0.0), "gunmetal_w")
	_cyl(turret, 0.03, 0.03, 0.9, Vector3(0.5, 0.97, -0.75), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	_cyl(turret, 0.012, 0.012, 2.0, Vector3(-0.7, 1.4, 0.6), Vector3.ZERO, "gunmetal_w", null, 4, false)
	_team_mark(turret, team, Vector3(1.18, 0.35, 0.2), Vector3(0.04, 0.22, 0.6))
	_team_mark(turret, team, Vector3(-1.18, 0.35, 0.2), Vector3(0.04, 0.22, 0.6))


# --- wheeled ---------------------------------------------------------------------

func _technical(team: int, seed: int, aa := false) -> void:
	# sun-faded civilian paint, the way these trucks actually look
	var paint: Color = [Color(0.66, 0.64, 0.58), Color(0.55, 0.48, 0.36), Color(0.36, 0.37, 0.3), Color(0.34, 0.17, 0.14)][seed % 4]
	var m := root
	_box(m, Vector3(1.3, 0.22, 4.5), Vector3(0, 0.55, 0.1), "gunmetal_w")
	# body sides, hood and cab
	_add(m, loft("pk_lo", [-0.92, -2.35, 0.92, -2.35, 0.92, 2.35, -0.92, 2.35], [-0.92, -2.3, 0.92, -2.3, 0.92, 2.35, -0.92, 2.35], 0.62, 1.05), "car_paint", paint, Vector3.ZERO)
	_add(m, loft("pk_hood", [-0.9, -2.3, 0.9, -2.3, 0.9, -1.0, -0.9, -1.0], [-0.86, -2.2, 0.86, -2.2, 0.86, -1.0, -0.86, -1.0], 1.04, 1.2), "car_paint", paint, Vector3.ZERO)
	_add(m, loft("pk_cab", [-0.9, -1.02, 0.9, -1.02, 0.9, 0.3, -0.9, 0.3], [-0.8, -0.42, 0.8, -0.42, 0.8, 0.22, -0.8, 0.22], 1.04, 1.78), "car_paint", paint, Vector3.ZERO)
	# glass
	_box(m, Vector3(1.55, 0.6, 0.03), Vector3(0, 1.45, -0.74), "glass", null, Vector3(-0.85, 0, 0), false)
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.03, 0.4, 0.75), Vector3(s * 0.86, 1.5, -0.12), "glass", null, Vector3(0, 0, s * 0.12), false)
	_box(m, Vector3(1.45, 0.38, 0.03), Vector3(0, 1.5, 0.27), "glass", null, Vector3.ZERO, false)
	# bed
	_box(m, Vector3(1.75, 0.06, 1.95), Vector3(0, 1.06, 1.35), "steel", paint.darkened(0.3))
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.06, 0.42, 2.0), Vector3(s * 0.9, 1.28, 1.35), "car_paint", paint)
	_box(m, Vector3(1.8, 0.42, 0.06), Vector3(0, 1.28, 2.35), "car_paint", paint)
	# bumpers, grille, lights
	_box(m, Vector3(1.9, 0.18, 0.16), Vector3(0, 0.75, -2.4), "steel")
	_box(m, Vector3(1.9, 0.14, 0.14), Vector3(0, 0.72, 2.42), "steel")
	_box(m, Vector3(1.1, 0.25, 0.03), Vector3(0, 0.98, -2.35), "gunmetal_w")
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.24, 0.13, 0.03), Vector3(s * 0.68, 0.98, -2.36), "glass")
	# wheels with arches
	for s in [-1.0, 1.0]:
		for z in [-1.55, 1.5]:
			_wheel(m, Vector3(s * 0.84, 0.4, z), 0.4, 0.28)
	# bull bar, mirrors, a roll bar behind the cab with lights, door seams,
	# wheel-arch flares
	for s in [-1.0, 1.0]:
		_cyl(m, 0.03, 0.03, 0.55, Vector3(s * 0.55, 1.0, -2.55), Vector3.ZERO, "gunmetal_w", null, 6)
		_box(m, Vector3(0.12, 0.14, 0.03), Vector3(s * 1.02, 1.42, -0.85), "gunmetal_w")
		_cyl(m, 0.035, 0.035, 0.75, Vector3(s * 0.75, 1.55, 0.42), Vector3.ZERO, "gunmetal_w", null, 6)
		_box(m, Vector3(0.02, 0.4, 0.03), Vector3(s * 0.925, 1.2, -0.15), "gunmetal_w", null, Vector3.ZERO, false)
		for z in [-1.55, 1.5]:
			_box(m, Vector3(0.12, 0.05, 1.0), Vector3(s * 0.94, 1.02, z), "car_paint", paint.darkened(0.15))
	_cyl(m, 0.03, 0.03, 1.15, Vector3(0, 0.82, -2.6), Vector3(0, 0, PI / 2), "gunmetal_w", null, 6)
	_cyl(m, 0.03, 0.03, 1.1, Vector3(0, 1.27, -2.55), Vector3(0, 0, PI / 2), "gunmetal_w", null, 6)
	_cyl(m, 0.035, 0.035, 1.55, Vector3(0, 1.93, 0.42), Vector3(0, 0, PI / 2), "gunmetal_w", null, 6)
	for x in [-0.3, 0.3]:
		_box(m, Vector3(0.18, 0.12, 0.1), Vector3(x, 2.0, 0.4), "gunmetal_w")
	# spare tyre and ammo cans in the bed
	_cyl(m, 0.36, 0.36, 0.24, Vector3(-0.42, 1.22, 0.75), Vector3(0, 0, 0), "rubber", null, 12)
	_box(m, Vector3(0.3, 0.2, 0.18), Vector3(0.5, 1.19, 2.0), "paint", Color(0.3, 0.33, 0.22))
	_box(m, Vector3(0.3, 0.2, 0.18), Vector3(0.5, 1.39, 2.0), "paint", Color(0.3, 0.33, 0.22))
	if aa:
		# ZU-23 twin cannon on a turntable in the bed
		turret = _pivot(m, Vector3(0, 1.15, 1.35))
		_cyl(turret, 0.55, 0.6, 0.18, Vector3(0, 0.05, 0), Vector3.ZERO, "paint", Color(0.33, 0.35, 0.27), 14)
		_box(turret, Vector3(0.9, 0.45, 0.9), Vector3(0, 0.4, 0.05), "paint", Color(0.33, 0.35, 0.27))
		for sx in [-0.17, 0.17]:
			_cyl(turret, 0.05, 0.06, 2.3, Vector3(sx, 0.62, -1.2), Vector3(PI / 2 + 0.15, 0, 0), "gunmetal_w", null, 8)
			_cyl(turret, 0.08, 0.08, 0.25, Vector3(sx, 0.78, -2.3), Vector3(PI / 2 + 0.15, 0, 0), "gunmetal_w", null, 8, false)
		_box(turret, Vector3(0.5, 0.35, 0.03), Vector3(-0.45, 0.75, -0.3), "steel", Color(0.32, 0.3, 0.25))
		_box(turret, Vector3(0.25, 0.3, 0.3), Vector3(0.45, 0.5, 0.3), "paint", Color(0.3, 0.33, 0.22))
		mg_tip = _tip(turret, Vector3(0, 0.81, -2.44))
		_team_mark(m, team, Vector3(0.93, 1.2, 1.35), Vector3(0.03, 0.2, 0.8))
		return
	# heavy MG on a pintle
	turret = _pivot(m, Vector3(0, 1.3, 1.1))
	_cyl(turret, 0.05, 0.06, 0.9, Vector3(0, 0.25, 0), Vector3.ZERO, "gunmetal_w", null, 8)
	_box(turret, Vector3(0.18, 0.2, 0.75), Vector3(0, 0.78, -0.05), "gunmetal_w")
	_cyl(turret, 0.035, 0.035, 1.15, Vector3(0, 0.8, -0.95), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6)
	_cyl(turret, 0.06, 0.06, 0.2, Vector3(0, 0.8, -1.45), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6)
	mg_tip = _tip(turret, Vector3(0, 0.8, -1.56))
	_box(turret, Vector3(0.75, 0.5, 0.04), Vector3(0, 0.92, -0.35), "steel", Color(0.32, 0.3, 0.25))
	_box(turret, Vector3(0.12, 0.12, 0.25), Vector3(0.14, 0.7, 0.15), "paint", Color(0.3, 0.33, 0.22))
	_team_mark(m, team, Vector3(0.93, 1.2, 1.35), Vector3(0.03, 0.2, 0.8))


## Civilian cars, side profiles extruded across the width: a body with a
## shaped bonnet and boot, a narrower glasshouse on top, dark glass, bumpers,
## lights, wheels in arches. Local -Z is the front.
func _car(v: int, col: Color) -> void:
	var m := root
	var w := 0.88  # half width
	var body: Array
	var house: Array
	match v:
		1:  # hatchback: short, upright back
			body = [-1.9, 0.3, 1.85, 0.3, 1.92, 0.58, 1.86, 0.92, -1.0, 0.95, -1.88, 0.82, -1.95, 0.52]
			house = [-0.95, 0.93, 1.78, 0.93, 1.72, 1.42, -0.35, 1.46]
		2:  # pickup: cab and an open bed
			body = [-2.45, 0.38, 2.4, 0.38, 2.45, 0.7, 2.4, 1.02, -1.15, 1.02, -2.4, 0.92, -2.48, 0.6]
			house = [-1.1, 1.0, 0.45, 1.0, 0.42, 1.68, -0.62, 1.7]
		3:  # van: one tall box
			body = [-2.3, 0.35, 2.3, 0.35, 2.32, 0.7, 2.3, 1.05, -1.55, 1.05, -2.28, 0.95, -2.34, 0.6]
			house = [-1.55, 1.03, 2.28, 1.03, 2.28, 2.0, -0.9, 2.05]
		4:  # estate: long roof to the back
			body = [-2.3, 0.3, 2.25, 0.3, 2.32, 0.6, 2.28, 0.92, -1.15, 0.95, -2.25, 0.83, -2.33, 0.55]
			house = [-1.1, 0.93, 2.2, 0.93, 2.12, 1.43, -0.5, 1.46]
		_:  # saloon: bonnet, cabin, boot
			body = [-2.25, 0.3, 2.2, 0.3, 2.28, 0.6, 2.18, 0.9, 1.25, 0.95, -1.15, 0.96, -2.2, 0.82, -2.3, 0.55]
			house = [-1.1, 0.93, 1.3, 0.93, 0.75, 1.43, -0.45, 1.45]
	var key := "car%d" % v
	_add(m, extrude_x(key + "b", body, -w, w), "car_paint", col, Vector3.ZERO)
	var hw := w - 0.1 if v != 3 else w - 0.02
	_add(m, extrude_x(key + "h", house, -hw, hw), "car_paint", col, Vector3.ZERO)
	# glass: windscreen, rear screen, side windows (inset a touch)
	var hz: Array = house
	var fz: float = hz[0]
	var fy: float = hz[1]
	var tz: float = hz[6]
	var ty: float = hz[7]
	var rz: float = hz[4]
	var ry: float = hz[5]
	var bz: float = hz[2]
	var by: float = hz[3]
	if not burnt:
		var wl := Vector2(tz - fz, ty - fy).length()
		_box(m, Vector3(hw * 2.0 - 0.12, wl - 0.08, 0.03), Vector3(0, (fy + ty) * 0.5, (fz + tz) * 0.5 - 0.015), "glass", null, Vector3(-atan2(tz - fz, ty - fy), 0, 0), false)
		if v != 2:
			var rl := Vector2(bz - rz, by - ry).length()
			_box(m, Vector3(hw * 2.0 - 0.14, rl - 0.1, 0.03), Vector3(0, (ry + by) * 0.5, (rz + bz) * 0.5 + 0.015), "glass", null, Vector3(atan2(bz - rz, ry - by) if absf(by - ry) > 0.01 else 0.0, 0, 0), false)
		for s in [-1.0, 1.0]:
			_box(m, Vector3(0.02, (ty - fy) * 0.62, (rz - tz) + 0.25), Vector3(s * (hw + 0.005), fy + (ty - fy) * 0.5, (tz + rz) * 0.5), "glass", null, Vector3.ZERO, false)
	# bumpers, lights, plate
	var front: float = body[0] if v != 2 else body[0]
	var bf: float = minf(body[0], body[body.size() - 2])
	var bb: float = maxf(body[2], body[4])
	_box(m, Vector3(w * 2.0 + 0.04, 0.16, 0.12), Vector3(0, 0.42, bf - 0.02), "rubber")
	_box(m, Vector3(w * 2.0 + 0.04, 0.16, 0.12), Vector3(0, 0.42, bb + 0.02), "rubber")
	if not burnt:
		for s in [-1.0, 1.0]:
			_add(m, Res.box(Vector3(0.3, 0.1, 0.04)), "paint", Color(0.92, 0.9, 0.8), Vector3(s * (w - 0.24), 0.68, bf - 0.01), Vector3.ZERO, Vector3.ONE, false)
			_add(m, Res.box(Vector3(0.24, 0.12, 0.04)), "paint", Color(0.62, 0.06, 0.05), Vector3(s * (w - 0.2), 0.74, bb + 0.01), Vector3.ZERO, Vector3.ONE, false)
		_add(m, Res.box(Vector3(0.42, 0.11, 0.02)), "paint", Color(0.9, 0.88, 0.8), Vector3(0, 0.5, bb + 0.09), Vector3.ZERO, Vector3.ONE, false)
	if v == 2:
		# the bed: sides and tailgate
		for s in [-1.0, 1.0]:
			_box(m, Vector3(0.06, 0.38, 1.95), Vector3(s * (w - 0.03), 1.2, 1.4), "car_paint", col)
		_box(m, Vector3(w * 2.0, 0.38, 0.06), Vector3(0, 1.2, 2.38), "car_paint", col)
		_box(m, Vector3(w * 2.0 - 0.1, 0.04, 1.9), Vector3(0, 1.03, 1.4), "rubber")
	# wheels in dark arches
	var wz := [bf + 0.75, bb - 0.75]
	for s in [-1.0, 1.0]:
		for z in wz:
			_box(m, Vector3(0.05, 0.5, 0.86), Vector3(s * (w - 0.01), 0.52, z), "rubber", null, Vector3.ZERO, false)
			_wheel(m, Vector3(s * (w - 0.1), 0.33, z), 0.33, 0.22, "steel", Color(0.62, 0.63, 0.62))


## M1151 Humvee: wide and low, a long sloping bonnet over the grille, the
## armoured crew cab with its thick little windows and four heavy doors, the
## rear cargo shell, fender flares over big tyres, and the gunner's
## protection kit with an M2 on the roof.
func _humvee(team: int) -> void:
	var cam := "camo_tank" if team == 0 else "camo_tank_rebel"
	var m := root
	_box(m, Vector3(1.5, 0.25, 4.4), Vector3(0, 0.6, 0), "gunmetal_w")
	_add(m, loft("hv2_low", [-1.08, -2.42, 1.08, -2.42, 1.1, 2.45, -1.1, 2.45], [-1.1, -2.42, 1.1, -2.42, 1.1, 2.45, -1.1, 2.45], 0.62, 1.12), cam, null, Vector3.ZERO)
	_add(m, loft("hv2_hood", [-1.05, -2.42, 1.05, -2.42, 1.05, -0.85, -1.05, -0.85], [-0.95, -2.22, 0.95, -2.22, 1.0, -0.85, -1.0, -0.85], 1.11, 1.3), cam, null, Vector3.ZERO)
	_add(m, loft("hv2_cab", [-1.1, -0.9, 1.1, -0.9, 1.1, 1.3, -1.1, 1.3], [-1.02, -0.62, 1.02, -0.62, 1.02, 1.22, -1.02, 1.22], 1.11, 1.92), cam, null, Vector3.ZERO)
	_add(m, loft("hv2_rear", [-1.1, 1.28, 1.1, 1.28, 1.1, 2.45, -1.1, 2.45], [-1.06, 1.28, 1.06, 1.28, 1.06, 2.4, -1.06, 2.4], 1.11, 1.5), cam, null, Vector3.ZERO)
	# grille with its slats, headlights in their guards, bumper and winch
	_box(m, Vector3(1.1, 0.42, 0.04), Vector3(0, 0.92, -2.43), "gunmetal_w")
	for i in 7:
		_box(m, Vector3(0.05, 0.38, 0.03), Vector3(-0.45 + i * 0.15, 0.92, -2.455), cam, null, Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.24, 0.16, 0.06), Vector3(s * 0.78, 1.02, -2.43), "gunmetal_w")
		_box(m, Vector3(0.16, 0.1, 0.02), Vector3(s * 0.78, 1.02, -2.465), "glass")
	_box(m, Vector3(2.05, 0.2, 0.22), Vector3(0, 0.68, -2.55), "steel")
	_box(m, Vector3(0.5, 0.18, 0.2), Vector3(0, 0.7, -2.68), "gunmetal_w")
	# split windscreen, armoured door windows, door seams, mirrors
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.82, 0.5, 0.05), Vector3(s * 0.46, 1.62, -0.78), "glass", null, Vector3(-0.38, 0, 0), false)
		_box(m, Vector3(0.05, 0.62, 0.06), Vector3(s * 1.0, 1.62, -0.75), cam, null, Vector3(-0.38, 0, 0), false)
		for dz in [-0.32, 0.72]:
			_box(m, Vector3(0.04, 0.34, 0.52), Vector3(s * 1.07, 1.62, dz), "glass", null, Vector3(0, 0, s * 0.06), false)
		for dz in [-0.88, 0.2, 1.28]:
			_box(m, Vector3(0.02, 0.8, 0.03), Vector3(s * 1.105, 1.35, dz), "gunmetal_w", null, Vector3.ZERO, false)
		_box(m, Vector3(0.03, 0.04, 0.12), Vector3(s * 1.11, 1.32, -0.15), "gunmetal_w", null, Vector3.ZERO, false)
		_box(m, Vector3(0.16, 0.2, 0.04), Vector3(s * 1.25, 1.65, -0.9), "gunmetal_w")
		# fender flares over the wheels
		for z in [-1.62, 1.62]:
			_box(m, Vector3(0.18, 0.06, 1.15), Vector3(s * 1.08, 1.13, z), cam)
			_wheel(m, Vector3(s * 0.95, 0.48, z), 0.48, 0.4)
	_box(m, Vector3(2.0, 0.42, 0.05), Vector3(0, 1.3, 2.47), cam)
	_box(m, Vector3(0.5, 0.35, 0.4), Vector3(0.6, 1.72, 1.85), "canvas", Color(0.32, 0.33, 0.25))
	_cyl(m, 0.012, 0.012, 2.4, Vector3(-0.95, 2.6, 1.9), Vector3.ZERO, "gunmetal_w", null, 4, false)
	# the gunner's turret: armoured shields with ballistic windows, the M2
	turret = _pivot(m, Vector3(0, 1.93, 0.45))
	_cyl(turret, 0.58, 0.58, 0.12, Vector3(0, 0.06, 0), Vector3.ZERO, cam, null, 18)
	_box(turret, Vector3(1.15, 0.6, 0.06), Vector3(0, 0.45, -0.55), cam, null, Vector3(0.1, 0, 0))
	_box(turret, Vector3(0.4, 0.22, 0.03), Vector3(0, 0.6, -0.6), "glass", null, Vector3(0.1, 0, 0), false)
	for s in [-1.0, 1.0]:
		_box(turret, Vector3(0.06, 0.55, 0.62), Vector3(s * 0.6, 0.42, -0.28), cam, null, Vector3(0, s * 0.45, 0))
		_box(turret, Vector3(0.03, 0.2, 0.3), Vector3(s * 0.64, 0.55, -0.3), "glass", null, Vector3(0, s * 0.45, 0), false)
	_box(turret, Vector3(0.18, 0.2, 0.75), Vector3(0, 0.45, -0.05), "gunmetal_w")
	_cyl(turret, 0.035, 0.035, 1.15, Vector3(0, 0.47, -0.95), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6)
	_cyl(turret, 0.05, 0.035, 0.1, Vector3(0, 0.47, -1.55), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	mg_tip = _tip(turret, Vector3(0, 0.47, -1.6))
	_box(turret, Vector3(0.16, 0.14, 0.28), Vector3(-0.2, 0.38, 0.0), "paint", Color(0.3, 0.33, 0.22))
	_team_mark(m, team, Vector3(1.11, 1.0, 1.9), Vector3(0.03, 0.18, 0.6))


## Tracked IFV: a tall slab-sided hull, rear ramp, small two-man turret with
## the 25 mm and a missile box.
func _ifv(team: int) -> void:
	var cam := "camo_tank"
	var m := root
	_add(m, loft("ifv_low", [-1.15, -2.9, 1.15, -2.9, 1.15, 3.1, -1.15, 3.1], [-1.15, -3.25, 1.15, -3.25, 1.15, 3.2, -1.15, 3.2], 0.38, 1.0), cam, null, Vector3.ZERO)
	_add(m, loft("ifv_up", [-1.62, -3.25, 1.62, -3.25, 1.62, 3.2, -1.62, 3.2], [-1.5, -2.2, 1.5, -2.2, 1.55, 3.15, -1.55, 3.15], 0.98, 1.95), cam, null, Vector3.ZERO)
	var tp := [-3.3, 0.6, -2.9, 0.06, 2.8, 0.06, 3.25, 0.55, 3.0, 0.95, -3.0, 0.95]
	for s in [-1.0, 1.0]:
		_add(m, extrude_x("ifv_trk", tp, -0.3, 0.3), "track", null, Vector3(s * 1.33, 0, 0))
		for i in 6:
			_wheel(m, Vector3(s * 1.35, 0.36, -2.25 + i * 0.88), 0.31, 0.46)
		for i in 6:
			_box(m, Vector3(0.06, 0.6, 0.9), Vector3(s * 1.66, 0.72, -2.3 + i * 0.93), cam)
		_box(m, Vector3(0.24, 0.12, 0.1), Vector3(s * 1.1, 1.15, -3.2), "gunmetal_w")
		_box(m, Vector3(0.18, 0.08, 0.02), Vector3(s * 1.1, 1.15, -3.26), "glass")
		# appliqué armour tiles
		for i in 4:
			_box(m, Vector3(0.08, 0.5, 1.1), Vector3(s * 1.68, 1.45, -1.6 + i * 1.2), cam)
	_box(m, Vector3(2.2, 1.0, 0.08), Vector3(0, 1.45, 3.22), cam)
	_box(m, Vector3(0.9, 0.8, 0.05), Vector3(0, 1.4, 3.27), "gunmetal_w")
	# trim vane folded on the glacis, the ramp's hinges, tow points
	_box(m, Vector3(2.4, 0.05, 0.7), Vector3(0, 1.32, -2.75), cam, null, Vector3(-0.5, 0, 0))
	for s in [-1.0, 1.0]:
		_cyl(m, 0.06, 0.06, 0.3, Vector3(s * 0.75, 0.55, 3.25), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
		_box(m, Vector3(0.12, 0.14, 0.18), Vector3(s * 0.75, 0.55, -3.35), "gunmetal_w")
	_box(m, Vector3(2.0, 0.05, 1.2), Vector3(0, 1.96, 2.2), "gunmetal_w")
	turret = _pivot(m, Vector3(0.25, 1.95, -0.4))
	_add(turret, loft("ifv_tur", [-0.85, -1.0, 0.85, -1.0, 0.95, 0.9, -0.95, 0.9], [-0.7, -0.75, 0.7, -0.75, 0.8, 0.8, -0.8, 0.8], 0.0, 0.62), cam, null, Vector3.ZERO)
	_cyl(turret, 0.06, 0.07, 2.4, Vector3(0, 0.32, -2.1), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	_cyl(turret, 0.1, 0.1, 0.3, Vector3(0, 0.32, -3.25), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	mg_tip = _tip(turret, Vector3(0, 0.32, -3.42))
	_box(turret, Vector3(0.36, 0.42, 1.3), Vector3(-1.08, 0.38, 0.1), cam)
	_cyl(turret, 0.2, 0.2, 0.2, Vector3(0.45, 0.72, 0.35), Vector3.ZERO, cam, null, 10)
	_box(turret, Vector3(0.3, 0.22, 0.35), Vector3(-0.45, 0.72, -0.4), cam)
	for s in [-1.0, 1.0]:
		for i in 2:
			_cyl(turret, 0.05, 0.05, 0.22, Vector3(s * (0.9 + i * 0.05), 0.45 + i * 0.1, -0.7), Vector3(-0.9, 0, s * 0.4), "gunmetal_w", null, 6, false)
	_team_mark(m, team, Vector3(1.66, 1.5, 2.3), Vector3(0.04, 0.3, 0.7))
	_team_mark(m, team, Vector3(-1.66, 1.5, 2.3), Vector3(0.04, 0.3, 0.7))


## BTR-80: a long boat-shaped hull (it swims), the bow sloping back over a
## trim vane, sides angled in above the wheels, eight wheels with the gap for
## the side doors between the second and third axles, firing ports, hatches,
## and the small conical turret with its 14.5 mm KPVT and smoke dischargers.
func _apc(team: int) -> void:
	var cam := "camo_tank" if team == 0 else "camo_tank_rebel"
	var m := root
	var lo := [-0.85, -3.1, 0.85, -3.1, 1.15, -2.3, 1.15, 3.55, -1.15, 3.55, -1.15, -2.3]
	var mid := [-1.0, -3.8, 1.0, -3.8, 1.42, -2.95, 1.42, 3.75, -1.42, 3.75, -1.42, -2.95]
	var hi := [-0.62, -2.65, 0.62, -2.65, 1.1, -2.2, 1.1, 3.6, -1.1, 3.6, -1.1, -2.2]
	_add(m, loft("btr_lo", lo, mid, 0.5, 1.28), cam, null, Vector3.ZERO)
	_add(m, loft("btr_hi", mid, hi, 1.28, 2.05), cam, null, Vector3.ZERO)
	# trim vane on the bow, the driver's and commander's vision blocks, lights
	_box(m, Vector3(1.8, 0.05, 0.55), Vector3(0, 1.35, -3.55), cam, null, Vector3(-0.9, 0, 0))
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.5, 0.12, 0.05), Vector3(s * 0.32, 1.92, -2.58), "glass", null, Vector3(-0.6, 0, 0), false)
		_box(m, Vector3(0.18, 0.1, 0.1), Vector3(s * 0.7, 1.5, -3.3), "gunmetal_w")
		_box(m, Vector3(0.14, 0.07, 0.02), Vector3(s * 0.7, 1.5, -3.36), "glass")
		# wheels: two pairs forward, two aft
		for z in [-2.45, -1.1, 0.75, 2.1]:
			_wheel(m, Vector3(s * 1.28, 0.55, z), 0.55, 0.4)
		# the side door between the axle pairs, firing ports along the flank
		_box(m, Vector3(0.05, 0.62, 0.62), Vector3(s * 1.3, 1.62, -0.18), cam, null, Vector3(0, 0, s * 0.38))
		for z in [-1.6, 1.3, 2.5]:
			_cyl(m, 0.06, 0.08, 0.06, Vector3(s * 1.26, 1.68, z), Vector3(0, 0, s * (PI / 2 - 0.38)), "gunmetal_w", null, 8, false)
		# stowage boxes and a tow cable over the rear wheels
		_box(m, Vector3(0.32, 0.22, 0.9), Vector3(s * 1.05, 2.12, 2.4), "steel", Color(0.32, 0.31, 0.24))
		_box(m, Vector3(0.05, 0.05, 2.4), Vector3(s * 1.36, 1.3, 1.4), "gunmetal_w", null, Vector3.ZERO, false)
	# roof hatches, engine grilles, exhaust
	for z in [-1.7, 0.3]:
		for s2 in [-1.0, 1.0]:
			_cyl(m, 0.27, 0.27, 0.06, Vector3(s2 * 0.55, 2.08, z), Vector3.ZERO, cam, null, 14)
	_box(m, Vector3(1.6, 0.04, 1.2), Vector3(0, 2.07, 2.7), "gunmetal_w")
	_box(m, Vector3(1.4, 0.18, 0.12), Vector3(0, 1.5, 3.75), "gunmetal_w")
	_cyl(m, 0.012, 0.012, 2.2, Vector3(0.9, 3.1, 1.6), Vector3.ZERO, "gunmetal_w", null, 4, false)
	# the turret: a low cone with the KPVT and coax in its mantlet
	turret = _pivot(m, Vector3(0, 2.05, -1.0))
	_cyl(turret, 0.66, 0.68, 0.1, Vector3(0, 0.05, 0), Vector3.ZERO, cam, null, 20)
	_cyl(turret, 0.42, 0.62, 0.42, Vector3(0, 0.31, 0), Vector3.ZERO, cam, null, 20)
	_cyl(turret, 0.24, 0.24, 0.06, Vector3(0.12, 0.55, 0.12), Vector3.ZERO, cam, null, 12)
	_box(turret, Vector3(0.36, 0.28, 0.3), Vector3(0, 0.3, -0.58), cam)
	_cyl(turret, 0.05, 0.05, 1.8, Vector3(0, 0.3, -1.6), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	_cyl(turret, 0.075, 0.075, 0.5, Vector3(0, 0.3, -0.95), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10)
	_cyl(turret, 0.07, 0.07, 0.16, Vector3(0, 0.3, -2.55), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	_cyl(turret, 0.02, 0.02, 0.4, Vector3(0.14, 0.25, -0.85), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
	mg_tip = _tip(turret, Vector3(0, 0.3, -2.65))
	_box(turret, Vector3(0.12, 0.14, 0.14), Vector3(-0.2, 0.55, -0.35), "gunmetal_w")
	for s in [-1.0, 1.0]:
		for i in 3:
			_cyl(turret, 0.045, 0.045, 0.2, Vector3(s * 0.55, 0.32 + i * 0.07, 0.25 - i * 0.05), Vector3(-0.7, 0, s * 0.6), "gunmetal_w", null, 6, false)
	_team_mark(m, team, Vector3(1.3, 1.7, 2.4), Vector3(0.03, 0.22, 0.7))


func _truck(team: int) -> void:
	var cab := Color(0.32, 0.35, 0.25) if team != 1 else Color(0.45, 0.38, 0.28)
	var m := root
	_box(m, Vector3(1.2, 0.25, 6.0), Vector3(0, 0.75, 0.2), "gunmetal_w")
	_add(m, loft("tr_hood", [-0.9, -3.4, 0.9, -3.4, 0.9, -2.45, -0.9, -2.45], [-0.82, -3.3, 0.82, -3.3, 0.82, -2.45, -0.82, -2.45], 0.8, 1.55), "paint", cab, Vector3.ZERO)
	_add(m, loft("tr_cab", [-1.1, -2.5, 1.1, -2.5, 1.1, -1.0, -1.1, -1.0], [-1.0, -2.2, 1.0, -2.2, 1.0, -1.05, -1.0, -1.05], 1.0, 2.45), "paint", cab, Vector3.ZERO)
	_box(m, Vector3(1.75, 0.6, 0.03), Vector3(0, 2.02, -2.37), "glass", null, Vector3(-0.2, 0, 0), false)
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.03, 0.5, 0.6), Vector3(s * 1.06, 2.0, -1.65), "glass", null, Vector3(0, 0, s * 0.05), false)
		_box(m, Vector3(0.05, 0.3, 0.2), Vector3(s * 1.2, 2.0, -2.35), "gunmetal_w")
	_box(m, Vector3(1.0, 0.45, 0.04), Vector3(0, 1.15, -3.42), "gunmetal_w")
	_box(m, Vector3(2.1, 0.2, 0.2), Vector3(0, 0.75, -3.5), "steel")
	# cargo bed with a canvas cover
	_box(m, Vector3(2.35, 0.15, 4.2), Vector3(0, 1.1, 1.15), "wood_dark")
	_box(m, Vector3(2.35, 1.2, 4.1), Vector3(0, 1.8, 1.15), "canvas", cab.lightened(0.05))
	_add(m, Res.cyl(1.17, 1.17, 4.1, 16), "canvas", cab.lightened(0.05), Vector3(0, 2.4, 1.15), Vector3(PI / 2, 0, 0), Vector3(1.0, 1.0, 0.42))
	for i in 4:
		_box(m, Vector3(2.4, 0.05, 0.08), Vector3(0, 2.42, -0.6 + i * 1.18), "canvas", cab.darkened(0.2))
	_cyl(m, 0.28, 0.28, 1.1, Vector3(-1.12, 0.95, -0.45), Vector3(PI / 2, 0, 0), "steel", null, 10)
	_box(m, Vector3(0.5, 0.4, 0.5), Vector3(1.12, 0.95, -0.45), "gunmetal_w")
	for s in [-1.0, 1.0]:
		_wheel(m, Vector3(s * 1.0, 0.5, -2.75), 0.5, 0.36)
		_wheel(m, Vector3(s * 1.0, 0.5, 1.0), 0.5, 0.36)
		_wheel(m, Vector3(s * 1.0, 0.5, 2.15), 0.5, 0.36)
	_team_mark(m, team, Vector3(1.19, 1.9, 1.15), Vector3(0.03, 0.35, 1.2))


# --- jet ----------------------------------------------------------------------

func _jet(team: int) -> void:
	var m := root
	var paint := Color(0.44, 0.47, 0.5) if team != 1 else Color(0.5, 0.47, 0.4)
	_add(m, _capsule(0.72, 13.0), "aircraft", paint, Vector3(0, 0, 0.3), Vector3(PI / 2, 0, 0), Vector3(1.0, 0.85, 1.0))
	_add(m, Res.sphere(0.6, 14), "glass", null, Vector3(0, 0.55, -3.2), Vector3.ZERO, Vector3(0.75, 0.7, 2.0))
	# swept wings, tailplanes and fin as thin lofted plates
	_add(m, loft("jet_wing", [-0.6, -1.4, 0.6, -1.4, 6.2, 2.6, 6.2, 3.6, -6.2, 3.6, -6.2, 2.6], [-0.6, -1.3, 0.6, -1.3, 6.2, 2.65, 6.2, 3.55, -6.2, 3.55, -6.2, 2.65], -0.08, 0.08), "aircraft", paint, Vector3(0, -0.1, 0))
	_add(m, loft("jet_tail", [-0.4, 5.0, 0.4, 5.0, 2.8, 6.6, 2.8, 7.2, -2.8, 7.2, -2.8, 6.6], [-0.4, 5.05, 0.4, 5.05, 2.8, 6.62, 2.8, 7.18, -2.8, 7.18, -2.8, 6.62], -0.06, 0.06), "aircraft", paint, Vector3(0, 0.1, 0))
	_add(m, extrude_x("jet_fin", [4.6, 0.5, 6.9, 0.5, 7.4, 3.0, 6.6, 3.0], -0.07, 0.07), "aircraft", paint, Vector3.ZERO)
	_cyl(m, 0.55, 0.6, 0.8, Vector3(0, 0, 7.0), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
	for s in [-1.0, 1.0]:
		_cyl(m, 0.14, 0.14, 1.6, Vector3(s * 2.6, -0.45, 1.6), Vector3(PI / 2, 0, 0), "paint", Color(0.3, 0.32, 0.26), 8)
		_cyl(m, 0.25, 0.25, 2.6, Vector3(s * 4.0, -0.5, 2.2), Vector3(PI / 2, 0, 0), "aircraft", paint.darkened(0.2), 8)
	_team_mark(m, team, Vector3(3.6, 0.1, 3.0), Vector3(0.8, 0.03, 0.5))
	_team_mark(m, team, Vector3(-3.6, 0.1, 3.0), Vector3(0.8, 0.03, 0.5))
	if not burnt:
		var glow := MeshInstance3D.new()
		glow.name = "Afterburner"
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 1.6)
		glow.mesh = q
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		gm.albedo_color = Color(1.0, 0.55, 0.25)
		gm.albedo_texture = Res.puff_mat(true).albedo_texture
		glow.material_override = gm
		glow.position = Vector3(0, 0, 7.5)
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.add_child(glow)


## A-10 Warthog: straight wings, twin tail, engines high on the rear fuselage,
## the GAU-8's barrels poking out of the nose.
func _a10(team: int) -> void:
	var m := root
	var paint := Color(0.42, 0.45, 0.47)
	_add(m, _capsule(0.82, 14.5), "aircraft", paint, Vector3(0, 0, 0.2), Vector3(PI / 2, 0, 0), Vector3(1.0, 0.9, 1.0))
	_add(m, Res.sphere(0.55, 14), "glass", null, Vector3(0, 0.62, -4.4), Vector3.ZERO, Vector3(0.85, 0.75, 1.7))
	_cyl(m, 0.17, 0.17, 0.9, Vector3(0, -0.25, -7.55), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
	# straight, thick wings with drooped tips
	_add(m, loft("a10_wing", [-0.9, -0.9, 0.9, -0.9, 8.6, -0.3, 8.6, 1.3, -8.6, 1.3, -8.6, -0.3], [-0.9, -0.8, 0.9, -0.8, 8.6, -0.25, 8.6, 1.25, -8.6, 1.25, -8.6, -0.25], -0.12, 0.12), "aircraft", paint, Vector3(0, -0.35, 0.4))
	for s in [-1.0, 1.0]:
		_box(m, Vector3(0.9, 0.06, 1.5), Vector3(s * 9.0, -0.5, 0.95), "aircraft", paint, Vector3(0, 0, s * 0.35))
		# engine pods high on the back, on short pylons
		_cyl(m, 0.62, 0.55, 3.0, Vector3(s * 1.45, 1.05, 3.4), Vector3(PI / 2, 0, 0), "aircraft", paint.darkened(0.08), 14)
		_cyl(m, 0.5, 0.5, 0.1, Vector3(s * 1.45, 1.05, 1.88), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 12)
		_box(m, Vector3(0.18, 0.55, 1.4), Vector3(s * 0.9, 0.7, 3.4), "aircraft", paint)
		# underwing stores
		for k in 3:
			_cyl(m, 0.13, 0.13, 1.9, Vector3(s * (2.6 + k * 1.8), -0.7, 0.2), Vector3(PI / 2, 0, 0), "paint", Color(0.36, 0.38, 0.33), 8)
	# tailplane with twin fins
	_add(m, loft("a10_tail", [-2.9, 6.2, 2.9, 6.2, 2.9, 7.6, -2.9, 7.6], [-2.9, 6.25, 2.9, 6.25, 2.9, 7.55, -2.9, 7.55], -0.07, 0.07), "aircraft", paint, Vector3(0, 0.45, 0))
	for s in [-1.0, 1.0]:
		_add(m, extrude_x("a10_fin", [6.0, -0.6, 7.7, -0.6, 7.6, 2.1, 6.6, 2.1], -0.06, 0.06), "aircraft", paint, Vector3(s * 2.9, 0.45, 0))
	_team_mark(m, team, Vector3(4.5, -0.22, 0.6), Vector3(0.8, 0.03, 0.8))
	_team_mark(m, team, Vector3(-4.5, -0.22, 0.6), Vector3(0.8, 0.03, 0.8))


## AC-130 gunship: high wing, four turboprops, upswept tail, guns along the
## left side (25 mm forward, 40 mm and the 105 mm howitzer aft).
func _ac130(team: int) -> void:
	var m := root
	var paint := Color(0.27, 0.29, 0.31)
	_add(m, _capsule(2.0, 29.0), "aircraft", paint, Vector3(0, 0, 0), Vector3(PI / 2, 0, 0), Vector3(1.0, 1.05, 1.0))
	_add(m, Res.sphere(1.5, 14), "glass", null, Vector3(0, 1.0, -12.4), Vector3.ZERO, Vector3(1.0, 0.45, 0.9))
	# upswept rear fuselage and the tail
	_add(m, loft("ac_tailcone", [-1.9, 9.0, 1.9, 9.0, 1.0, 15.5, -1.0, 15.5], [-1.9, 9.0, 1.9, 9.0, 1.0, 15.5, -1.0, 15.5], 0.2, 2.2), "aircraft", paint, Vector3(0, 0, 0))
	_add(m, loft("ac_hstab", [-8.2, 13.6, 8.2, 13.6, 8.2, 16.2, -8.2, 16.2], [-8.2, 13.7, 8.2, 13.7, 8.2, 16.1, -8.2, 16.1], -0.12, 0.12), "aircraft", paint, Vector3(0, 2.4, 0))
	_add(m, extrude_x("ac_fin", [11.5, 1.6, 16.4, 1.6, 16.6, 8.6, 14.6, 8.6], -0.14, 0.14), "aircraft", paint, Vector3.ZERO)
	# high wing with four engines
	_add(m, loft("ac_wing", [-20.0, -3.8, 20.0, -3.8, 20.0, -1.6, -20.0, -1.6], [-20.0, -3.7, 20.0, -3.7, 20.0, -1.7, -20.0, -1.7], -0.18, 0.18), "aircraft", paint, Vector3(0, 2.15, 0))
	for x in [-10.2, -5.3, 5.3, 10.2]:
		_cyl(m, 0.62, 0.55, 4.2, Vector3(x, 1.55, -3.4), Vector3(PI / 2, 0, 0), "aircraft", paint.darkened(0.08), 12)
		var prop := _pivot(m, Vector3(x, 1.55, -5.65))
		_cyl(prop, 0.25, 0.1, 0.5, Vector3.ZERO, Vector3(PI / 2, 0, 0), "gunmetal_w", null, 8)
		if not burnt:
			var disc := MeshInstance3D.new()
			disc.mesh = Res.cyl(2.05, 2.05, 0.04, 24)
			disc.rotation = Vector3(PI / 2, 0, 0)
			disc.material_override = _blur_mat()
			disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			prop.add_child(disc)
		wheels.append(prop)
	# the guns, poking out of the left side
	_cyl(m, 0.08, 0.08, 1.6, Vector3(-2.3, -0.4, -7.0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
	_cyl(m, 0.12, 0.12, 1.8, Vector3(-2.35, -0.5, 3.0), Vector3(0, 0, PI / 2), "gunmetal_w", null, 8)
	_cyl(m, 0.22, 0.24, 2.6, Vector3(-2.6, -0.6, 6.5), Vector3(0, 0, PI / 2), "gunmetal_w", null, 10)
	_team_mark(m, team, Vector3(12.0, 2.35, -2.6), Vector3(1.5, 0.03, 1.2))
	_team_mark(m, team, Vector3(-12.0, 2.35, -2.6), Vector3(1.5, 0.03, 1.2))


# --- helicopters --------------------------------------------------------------

func _heli(team: int, attack: bool) -> void:
	var m := root
	var cam := "camo_tank" if team != 1 else "camo_tank_rebel"
	var dark := Color(0.24, 0.27, 0.21)
	if attack:
		# slim fuselage, tandem cockpit, stub wings with rocket pods, chin gun
		_add(m, _capsule(0.62, 5.2), cam, null, Vector3(0, 1.45, -0.1), Vector3(PI / 2, 0, 0), Vector3(0.85, 1.25, 1.0))
		_add(m, Res.sphere(0.6, 14), "glass", null, Vector3(0, 1.95, -1.85), Vector3.ZERO, Vector3(0.7, 0.75, 1.5))
		_add(m, Res.sphere(0.5, 12), "glass", null, Vector3(0, 2.05, -0.75), Vector3.ZERO, Vector3(0.75, 0.8, 1.3))
		_add(m, _capsule(0.4, 2.4), cam, null, Vector3(0, 2.15, 0.6), Vector3(PI / 2, 0, 0), Vector3(1.7, 1.0, 1.0))
		_cyl(m, 0.42, 0.18, 4.6, Vector3(0, 1.75, 4.2), Vector3(PI / 2, 0, 0), cam, null, 12)
		for s in [-1.0, 1.0]:
			_box(m, Vector3(1.4, 0.08, 0.7), Vector3(s * 1.0, 1.45, 0.3), cam, null, Vector3(0, 0, s * -0.08))
			for j in 2:
				var px: float = s * (0.8 + j * 0.6)
				_cyl(m, 0.17, 0.17, 1.1, Vector3(px, 1.2, 0.2), Vector3(PI / 2, 0, 0), "paint", Color(0.28, 0.3, 0.23), 10)
				_cyl(m, 0.12, 0.12, 0.05, Vector3(px, 1.2, -0.36), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 10, false)
			_cyl(m, 0.035, 0.035, 1.7, Vector3(s * 0.35, 0.35, -0.5), Vector3(0, 0, s * 0.35), "gunmetal_w", null, 6)
			_cyl(m, 0.14, 0.14, 0.1, Vector3(s * 0.65, 0.18, -0.5), Vector3(0, 0, PI / 2), "rubber", null, 10)
		_box(m, Vector3(0.12, 1.3, 0.8), Vector3(0, 2.45, 6.25), cam, null, Vector3(-0.3, 0, 0))
		_box(m, Vector3(1.6, 0.06, 0.45), Vector3(0, 1.8, 6.0), cam)
		turret = _pivot(m, Vector3(0, 0.8, -2.25))
		_cyl(turret, 0.13, 0.15, 0.4, Vector3.ZERO, Vector3.ZERO, "gunmetal_w", null, 10)
		_cyl(turret, 0.035, 0.035, 1.3, Vector3(0, -0.1, -0.6), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6, false)
		mg_tip = _tip(turret, Vector3(0, -0.1, -1.27))
		_team_mark(m, team, Vector3(0, 1.98, 3.6), Vector3(0.3, 0.04, 1.2))
		_cyl(m, 0.1, 0.1, 0.45, Vector3(0, 2.6, 0.0), Vector3.ZERO, "gunmetal_w", null, 10)
		rotor = _pivot(m, Vector3(0, 2.9, 0.0))
		tail_rotor = _pivot(m, Vector3(0.2, 2.55, 6.4))
	else:
		# utility transport: wide cabin, big sliding doors, skids
		_add(m, _capsule(0.98, 5.6), cam, null, Vector3(0, 1.45, 0.1), Vector3(PI / 2, 0, 0), Vector3(0.92, 1.0, 1.0))
		_add(m, Res.sphere(0.95, 16), "glass", null, Vector3(0, 1.62, -1.95), Vector3.ZERO, Vector3(0.88, 0.72, 1.05))
		_add(m, Res.sphere(0.9, 14), cam, null, Vector3(0, 1.15, -2.15), Vector3.ZERO, Vector3(0.82, 0.62, 0.95))
		_add(m, _capsule(0.45, 2.6), cam, null, Vector3(0, 2.38, 0.35), Vector3(PI / 2, 0, 0), Vector3(1.5, 0.9, 1.0))
		for s in [-1.0, 1.0]:
			_box(m, Vector3(0.04, 0.95, 1.3), Vector3(s * 0.9, 1.45, 0.15), "paint", dark)
			_box(m, Vector3(0.04, 0.4, 0.45), Vector3(s * 0.91, 1.75, 0.0), "glass")
			_box(m, Vector3(0.04, 0.35, 0.4), Vector3(s * 0.88, 1.7, 1.35), "glass")
			_cyl(m, 0.05, 0.05, 3.6, Vector3(s * 0.95, 0.08, 0.1), Vector3(PI / 2, 0, 0), "gunmetal_w", null, 6)
			for z in [-0.8, 1.0]:
				_cyl(m, 0.04, 0.04, 0.6, Vector3(s * 0.85, 0.35, z), Vector3(0, 0, s * 0.35), "gunmetal_w", null, 6, false)
		_cyl(m, 0.48, 0.24, 5.2, Vector3(0, 1.85, 4.9), Vector3(PI / 2, 0, 0), cam, null, 12)
		_box(m, Vector3(0.12, 1.6, 0.9), Vector3(0, 2.6, 7.2), cam, null, Vector3(-0.35, 0, 0))
		_box(m, Vector3(1.9, 0.06, 0.5), Vector3(0, 1.95, 6.7), cam)
		_cyl(m, 0.1, 0.1, 0.45, Vector3(0, 2.75, 0.1), Vector3.ZERO, "gunmetal_w", null, 10)
		rotor = _pivot(m, Vector3(0, 2.98, 0.1))
		tail_rotor = _pivot(m, Vector3(0.18, 2.8, 7.35))
		_team_mark(m, team, Vector3(0, 2.15, 4.0), Vector3(0.5, 0.04, 1.6))
	# main rotor: hub, blades (visible slow) and a blur disc (visible fast)
	_cyl(rotor, 0.22, 0.22, 0.18, Vector3.ZERO, Vector3.ZERO, "gunmetal_w", null, 10)
	blades = _pivot(rotor, Vector3.ZERO)
	var bl := 5.4 if not attack else 4.6
	for i in 4:
		var bp := _pivot(blades, Vector3.ZERO)
		bp.rotation.y = i * PI / 2
		_box(bp, Vector3(0.32, 0.04, bl), Vector3(0, 0.05, bl * 0.5 + 0.15), "gunmetal_w", null, Vector3(0, 0, 0.06))
	if not burnt:
		blur = MeshInstance3D.new()
		var disc := PlaneMesh.new()
		disc.size = Vector2(bl + 0.2, bl + 0.2) * 2.0
		blur.mesh = disc
		blur.material_override = _blur_mat()
		blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blur.position = Vector3(0, 0.06, 0)
		blur.visible = false
		rotor.add_child(blur)
	for i in 2:
		_box(tail_rotor, Vector3(0.03, 1.5, 0.14), Vector3.ZERO, "gunmetal_w", null, Vector3(i * PI / 2, 0, 0))


static var _blur: ShaderMaterial


static func _blur_mat() -> ShaderMaterial:
	if _blur == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float streak = 0.55 + 0.45 * sin(a * 4.0 + TIME * 3.0);
	float ring = smoothstep(1.0, 0.94, r) * smoothstep(0.05, 0.2, r);
	float tip = smoothstep(0.86, 0.95, r) * smoothstep(1.0, 0.96, r);
	ALBEDO = vec3(0.1, 0.1, 0.095) + tip * 0.15;
	ALPHA = ring * (0.05 + 0.07 * streak) + tip * 0.08;
}
"""
		_blur = ShaderMaterial.new()
		_blur.shader = sh
	return _blur
