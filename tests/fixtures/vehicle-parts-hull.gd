extends Node
## The hull and running-gear parts of the second construction pass: return
## rollers, raked skirt bow panels, smoke-discharger banks, lamp units, static
## whips, necked sensor turrets and wheel tubs. Each folds into its parent,
## registers no wheels, stays inside an envelope close to the geometry it
## replaces and drops its lenses on wrecks; the extended antenna and sensor
## reproduce their old output exactly with their old arguments, and a bank's
## tubes sit exactly where the family's own smoke_tube calls put them.

func kit(burnt := false) -> VehicleModels:
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k._baking = true
	k.burnt = burnt
	return k

## Every noted part, in root coordinates, whichever pivot it is noted on.
func parts(k: VehicleModels) -> Array:
	var out := []
	for node: Node3D in k._parts:
		var xf := Transform3D.IDENTITY
		var n := node
		while n and n != k.root:
			xf = n.transform * xf
			n = n.get_parent() as Node3D
		for part: Array in k._parts[node]:
			var local: Transform3D = Transform3D(part[7], part[4]) if part[7] is Basis else Mats.place(part[4], part[5], part[6])
			out.append([part, xf * local])
	return out

func bounds(k: VehicleModels) -> AABB:
	var box := AABB()
	var first := true
	for entry: Array in parts(k):
		var xf: Transform3D = entry[1]
		var aabb := xf * ((entry[0] as Array)[0] as Mesh).get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	return box

func vertices(k: VehicleModels) -> int:
	var count := 0
	for entry: Array in parts(k):
		var mesh: Mesh = (entry[0] as Array)[0]
		for i in mesh.get_surface_count():
			count += (Mats._flat(mesh, i)[0] as PackedVector3Array).size()
	return count

func count_material(k: VehicleModels, kind: String) -> int:
	var m := Mats.get_mat(VehicleMaterials.key(kind, k.surface_family))
	var n := 0
	for entry: Array in parts(k):
		if (entry[0] as Array)[1] == m:
			n += 1
	return n

func check(k: VehicleModels, envelope: AABB, label: String, children := 0) -> void:
	assert(k.root.get_child_count() == children, label + ": construction pivots must fold into their parent")
	assert(k.wheels.is_empty(), label + ": static parts must not register wheel animation")
	assert(not parts(k).is_empty(), label + ": nothing was built")
	var box := bounds(k)
	assert(box.size.is_finite() and box.position.is_finite(), label + ": non-finite geometry")
	if OS.has_environment("FL_DEBUG_PART_BOUNDS"):
		print("PART %s %s verts=%d" % [label, box, vertices(k)])
	else:
		assert(envelope.grow(0.0005).encloses(box), "%s: %s escapes %s" % [label, box, envelope])
	if k.burnt:
		var burnt := Mats.get_mat(VehicleMaterials.key("burnt", k.surface_family))
		for entry: Array in parts(k):
			assert((entry[0] as Array)[1] == burnt, label + ": wrecks use the burnt material throughout")
	k.root.free()

## Two builds made the same parts in the same places (BevelMeshes are made
## afresh each call, so meshes match by kind and extent).
func same_parts(a: VehicleModels, b: VehicleModels, label: String) -> void:
	var pa := parts(a)
	var pb := parts(b)
	assert(pa.size() == pb.size(), "%s: %d parts, expected %d" % [label, pa.size(), pb.size()])
	for i in pa.size():
		var x: Array = pa[i][0]
		var y: Array = pb[i][0]
		var mx: Mesh = x[0]
		var my: Mesh = y[0]
		assert(mx.get_class() == my.get_class() and mx.get_aabb().is_equal_approx(my.get_aabb()), "%s: part %d's mesh differs" % [label, i])
		assert(x[1] == y[1] and x[2] == y[2] and x[3] == y[3], "%s: part %d's surface differs" % [label, i])
		var xa: Transform3D = pa[i][1]
		var xb: Transform3D = pb[i][1]
		assert(xa.is_equal_approx(xb), "%s: part %d moved" % [label, i])
	assert(a.antennas.size() == b.antennas.size(), label + ": antenna registrations differ")
	a.root.free()
	b.root.free()

## Every tube part of `sub` (all but its bracket boxes) appears in `whole` at
## the same place, the same mesh.
func contains_parts(whole: VehicleModels, sub: VehicleModels, label: String) -> void:
	var pw := parts(whole)
	var tubes := 0
	for entry: Array in parts(sub):
		if (entry[0] as Array)[0] is BevelMesh or (entry[0] as Array)[0] is BoxMesh:
			continue
		tubes += 1
		var found := false
		for other: Array in pw:
			if (other[0] as Array)[0] == (entry[0] as Array)[0] and (other[1] as Transform3D).is_equal_approx(entry[1]):
				found = true
				break
		assert(found, label + ": a discharger tube moved")
	assert(tubes > 0, label + ": no tubes to compare")
	sub.root.free()

## The sensor and antenna as they were before their new parameters.
func old_sensor(k: VehicleModels, parent: Node3D, center: Vector3, size: Vector3, mat: String, col = null, style := "box") -> void:
	var mount := k._pivot(parent, center)
	if style == "ball":
		k._add(mount, Res.sphere(0.5, 16), mat, col, Vector3.ZERO, Vector3.ZERO, size)
	else:
		k._box(mount, size, Vector3.ZERO, mat, col)
		k._box(mount, Vector3(size.x * 1.07, size.y * 0.08, size.z * 1.08), Vector3(0, size.y * 0.54, 0), mat, col)
	for i in 2:
		var radius := minf(size.x * (0.13 if i == 0 else 0.09), size.y * 0.22)
		var at := Vector3(size.x * (-0.19 if i == 0 else 0.19), 0, -size.z * 0.49)
		k._cyl(mount, radius * 1.25, radius * 1.25, radius * 0.35, at, Vector3(PI / 2, 0, 0), "rubber", null, 12, false)
		if not k.burnt:
			k._cyl(mount, radius, radius, radius * 0.08, at + Vector3(0, 0, -radius * 0.2), Vector3(PI / 2, 0, 0), "glass", Color(0.13, 0.20, 0.23), 12, false)
		var rim := VehicleFittings._ring(radius, radius * 1.2)
		k._add(mount, rim, "metal_dark", null, at + Vector3(0, 0, -radius * 0.28), Vector3(PI / 2, 0, 0), Vector3(1, 0.45, 1))
	for side: float in [-1.0, 1.0]:
		k._cyl(mount, size.y * 0.16, size.y * 0.16, size.x * 0.06, Vector3(side * size.x * 0.5, 0, 0), Vector3(0, 0, PI / 2), mat, col, 10, false)
	if style == "box":
		k._box(mount, Vector3(size.x * 1.08, size.y * 0.07, size.z * 0.24), Vector3(0, size.y * 0.50, -size.z * 0.48), mat, col)
	else:
		k._add(mount, VehicleFittings._ring(size.y * 0.17, size.y * 0.21), "rubber", null, Vector3(0, size.y * 0.46, 0), Vector3.ZERO, Vector3(1, 0.3, 1))
	var cover := Vector3(0, 0, size.z * 0.49)
	if style == "ball":
		k._cyl(mount, minf(size.x, size.y) * 0.22, minf(size.x, size.y) * 0.22, size.z * 0.12, Vector3(0, 0, size.z * 0.44), Vector3(PI / 2, 0, 0), mat, col, 12)
	else:
		k._add(mount, BevelMesh.make(Vector3(size.x * 0.44, size.y * 0.42, size.z * 0.035), minf(size.z * 0.012, size.y * 0.03)), mat, col, cover)
	for side: float in [-1.0, 1.0]:
		VehicleBody.fastener(k, mount, cover + Vector3(side * size.x * 0.15, 0, size.z * 0.025), Vector3.BACK, minf(0.009, size.y * 0.035))
	k._fold(mount)

func old_antenna(k: VehicleModels, parent: Node3D, base: Vector3, height: float) -> void:
	var mount := k._pivot(parent, base)
	k._box(mount, Vector3(0.13, 0.025, 0.13), Vector3(0, 0.0125, 0), "gunmetal_w")
	for side in [-1.0, 1.0]:
		VehicleBody.fastener(k, mount, Vector3(side * 0.045, 0.03, 0), Vector3.UP, 0.012)
	k._cyl(mount, 0.034, 0.05, 0.09, Vector3(0, 0.065, 0), Vector3.ZERO, "rubber", null, 10, false)
	var whip := k._pivot(mount, Vector3(0, 0.10, 0))
	if not k.burnt:
		k.antennas.append(whip)
	k._cyl(whip, 0.019, 0.019, 0.16, Vector3(0, 0.08, 0), Vector3.ZERO, "gunmetal_w", null, 8, false)
	k._add(whip, VehicleFittings._antenna_spring(), "gunmetal_w", Color(0.24, 0.25, 0.23), Vector3(0, 0.008, 0), Vector3.ZERO, Vector3.ONE, false)
	for i in 5:
		var t0 := float(i) / 5
		var t1 := float(i + 1) / 5
		var a := Vector3(0, 0.16 + (height - 0.14) * t0, height * 0.035 * t0 * t0)
		var b := Vector3(0, 0.16 + (height - 0.14) * t1, height * 0.035 * t1 * t1)
		VehicleFrames.tube(k, whip, a, b, lerpf(0.013, 0.005, t0), "gunmetal_w", null, 6, false, lerpf(0.013, 0.005, t1))
	if k.burnt:
		k._fold(whip)
	k._fold(mount)

## VmCore._smoke's layout and VmNato._smoke's, as each family computes it.
func core_tubes(pos: Vector3, yaw: float, cols: int, rows: int, pitch: float, r: float) -> Array:
	var t := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), pos)
	var out := []
	for j in rows:
		for i in cols:
			var fx := (i - (cols - 1) * 0.5) * r * 2.3
			var lp := Vector3(fx, 0.05 + j * r * 2.1, -0.02 + j * 0.03)
			out.append(Transform3D(t.basis * Basis.from_euler(Vector3(-PI / 2 + pitch + j * 0.15, fx * 1.2, 0)), t * lp))
	return out

func nato_tubes(pos: Vector3, s: float, n: int, yaw: float) -> Array:
	var b := Basis(Vector3.UP, yaw)
	var out := []
	for i in n:
		var o := b * Vector3(0, 0.07 + (i % 2) * 0.05, (i - (n - 1) * 0.5) * 0.12)
		out.append(Transform3D(Basis.from_euler(Vector3(0, yaw, s * -0.9)), pos + o + Vector3(s * 0.06, 0.04, 0)))
	return out

func _ready() -> void:
	TestRun.watch()
	var olive := Color(0.3, 0.33, 0.22)
	# The extended builders' old arguments give exactly the old parts.
	for burnt in [false, true]:
		var a := kit(burnt)
		var b := kit(burnt)
		VehicleEquipment.sensor(a, a.root, Vector3(0, 0.5, -1.8), Vector3.ONE * 0.26, "paint", olive, "ball")
		old_sensor(b, b.root, Vector3(0, 0.5, -1.8), Vector3.ONE * 0.26, "paint", olive, "ball")
		same_parts(a, b, "default ball sensor")
		a = kit(burnt)
		b = kit(burnt)
		VehicleEquipment.sensor(a, a.root, Vector3(0.2, 1.1, 0.3), Vector3(0.5, 0.4, 0.4), "paint", olive)
		old_sensor(b, b.root, Vector3(0.2, 1.1, 0.3), Vector3(0.5, 0.4, 0.4), "paint", olive)
		same_parts(a, b, "default box sensor")
		a = kit(burnt)
		b = kit(burnt)
		VehicleFittings.antenna(a, a.root, Vector3(1.08, 1.4, 2.22), 2.1)
		old_antenna(b, b.root, Vector3(1.08, 1.4, 2.22), 2.1)
		assert(a.antennas.size() == (0 if burnt else 1), "a ground whip sways unless wrecked")
		same_parts(a, b, "default antenna")
	for burnt in [false, true]:
		# Return rollers: the Abrams' on both sides, static, axle along X.
		var k := kit(burnt)
		VehicleWheels.roller(k, k.root, Vector3(1.3, 0.86, -0.95), 0.075, 0.28)
		check(k, AABB(Vector3(1.13, 0.78, -1.03), Vector3(0.34, 0.16, 0.16)), "roller")
		k = kit(burnt)
		VehicleWheels.roller(k, k.root, Vector3(-1.36, 1.0, 0.05), 0.09, 0.28, "paint", olive)
		check(k, AABB(Vector3(-1.53, 0.905, -0.045), Vector3(0.34, 0.19, 0.19)), "left roller")
		# Skirt bow panels: the Bradley's (leaning forward) and the Merkava's
		# (raked up toward the nose), each within its old rotated box.
		k = kit(burnt)
		VehicleEquipment.skirt_bow(k, k.root, Vector3(1.44, 0.95, -2.85), Vector3(0.07, 0.42, 0.5), 1.0, "paint", olive, Vector3(-0.45, 0, 0))
		check(k, AABB(Vector3(1.385, 0.645, -3.17), Vector3(0.135, 0.61, 0.64)), "skirt_bow")
		k = kit(burnt)
		VehicleEquipment.skirt_bow(k, k.root, Vector3(-1.82, 0.98, -3.22), Vector3(0.08, 0.55, 0.9), -1.0, "paint", olive, Vector3(0.42, 0, 0))
		check(k, AABB(Vector3(-1.9, 0.54, -3.75), Vector3(0.14, 0.88, 1.06)), "merkava skirt_bow")
		# Smoke banks keep every tube exactly where the family's own helper puts
		# it, given that helper's layout as transforms.
		var tubes := core_tubes(Vector3(1.54, 0.6, -1.12), -1.05, 3, 2, 0.5, 0.043)
		k = kit(burnt)
		VehicleFittings.smoke_bank(k, k.root, Transform3D(Basis.from_euler(Vector3(0, -1.05, 0)), Vector3(1.54, 0.6, -1.12)) * Vector3(0, -0.03, 0.02), Vector3(3 * 0.043 * 2.3 + 0.04, 0.06, 0.16), Vector3(0, -1.05, 0), tubes, 0.043, 0.22)
		var family := kit(burnt)
		VmCore._smoke(family, family.root, Vector3(1.54, 0.6, -1.12), -1.05, 3, 2, 0.5, 0.043)
		contains_parts(k, family, "core smoke_bank")
		check(k, AABB(Vector3(1.355, 0.53, -1.315), Vector3(0.38, 0.34, 0.4)), "core smoke_bank")
		tubes = nato_tubes(Vector3(1.45, 2.37, -0.45), 1.0, 4, -0.5)
		k = kit(burnt)
		VehicleFittings.smoke_bank(k, k.root, Vector3(1.45, 2.37, -0.45), Vector3(0.14, 0.1, 0.52), Vector3(0, -0.5, 0), tubes, 0.042, 0.22)
		family = kit(burnt)
		VmNato._smoke(family, family.root, Vector3(1.45, 2.37, -0.45), 1.0, 4, -0.5)
		contains_parts(k, family, "nato smoke_bank")
		check(k, AABB(Vector3(1.255, 2.31, -0.72), Vector3(0.465, 0.345, 0.54)), "nato smoke_bank")
		# Lamp units: the shared convoy lamp in its cage, the twin-insert CSAT
		# cluster, the Humvee's lamp with indicator and strap, a round lamp
		# with a crossed guard, and a raked civilian cluster.
		k = kit(burnt)
		VehicleFittings.lamp_unit(k, k.root, Vector3(1.36, 1.24, -3.56), Vector3(0.065 * 2.6, 0.065 * 2.3, 0.12), -1.0, [0.065], Rect2(), "cage")
		var lenses := count_material(k, "headlamp")
		assert(lenses == (0 if burnt else 15), "a sealed beam keeps its reflector and ribs only while intact: %d" % lenses)
		check(k, AABB(Vector3(1.255, 1.14, -3.695), Vector3(0.21, 0.195, 0.215)), "lamp_unit")
		k = kit(burnt)
		VehicleFittings.lamp_unit(k, k.root, Vector3(0.66, 1.0, -3.2), Vector3(0.26, 0.15, 0.1), -1.0, [Rect2(Vector2(-0.06, 0), Vector2(0.1, 0.09)), Rect2(Vector2(0.07, 0), Vector2(0.08, 0.07))], Rect2(), "cage", Vector3(0.28, 0.18, 0.09))
		assert(count_material(k, "headlamp") == (0 if burnt else 2 * 8), "rectangular inserts lose their lenses on wrecks")
		check(k, AABB(Vector3(0.505, 0.895, -3.305), Vector3(0.31, 0.21, 0.175)), "twin lamp_unit")
		k = kit(burnt)
		VehicleFittings.lamp_unit(k, k.root, Vector3(0.84, 0.98, -2.47), Vector3(0.28, 0.2, 0.06), -1.0, [Vector3(0.04, 0, 0.075)], Rect2(Vector2(-0.1, 0), Vector2(0.06, 0.06)), "bar", Vector3(0.28, 0.24, 0.07))
		assert(count_material(k, "signal_lens") == (0 if burnt else 6), "the indicator lens goes with the wreck")
		check(k, AABB(Vector3(0.695, 0.855, -2.56), Vector3(0.29, 0.25, 0.14)), "humvee lamp_unit")
		k = kit(burnt)
		VehicleFittings.lamp_unit(k, k.root, Vector3(1.16, 1.22, -3.08), Vector3(0.26, 0.24, 0.16), -1.0, [0.1], Rect2(), "cross", Vector3(0.23, 0.23, 0.13), "round")
		check(k, AABB(Vector3(1.02, 1.08, -3.23), Vector3(0.28, 0.28, 0.25)), "round lamp_unit")
		k = kit(burnt)
		k.surface_family = "automotive"
		VehicleFittings.lamp_unit(k, k.root, Vector3(0.67, 1.48, -2.75), Vector3(0.4, 0.2, 0.06), -1.0, [Rect2(Vector2(0, 0.01), Vector2(0.34, 0.15)), Rect2(Vector2(-0.07, 0.01), Vector2(0.1, 0.1))], Rect2(), "", Vector3.ZERO, "box", Vector3(0.34, 0.12, 0))
		check(k, AABB(Vector3(0.455, 1.37, -2.845), Vector3(0.43, 0.22, 0.19)), "raked lamp_unit")
		# Static whips: a helicopter's belly whip raked down and aft, a boat's
		# VHF whip on its insulator; neither sways.
		k = kit(burnt)
		VehicleFittings.antenna(k, k.root, Vector3(0, 0.58, 0.1), 0.0, Vector3(0, -0.28, 0.32), 0.01, "gunmetal_w", null, "whip")
		assert(k.antennas.is_empty(), "a static whip never sways")
		check(k, AABB(Vector3(-0.03, 0.285, 0.07), Vector3(0.06, 0.31, 0.365)), "belly whip")
		k = kit(burnt)
		k.surface_family = "marine"
		VehicleFittings.antenna(k, k.root, Vector3(1.55, 4.1, -0.7), 0.0, Vector3(0, 4.0, 0.24), 0.012, "gunmetal_w", null, "whip", Vector3(0.035, 0.045, 0.16))
		assert(k.antennas.is_empty())
		check(k, AABB(Vector3(1.5, 4.095, -0.75), Vector3(0.1, 4.02, 0.31)), "boat whip")
		# A sprung whip may lean too; it still sways.
		k = kit(burnt)
		VehicleFittings.antenna(k, k.root, Vector3(0.6, 1.2, 1.0), 0.0, Vector3(0, 1.6, 0.4))
		assert(k.antennas.size() == (0 if burnt else 1))
		check(k, AABB(Vector3(0.53, 1.195, 0.93), Vector3(0.14, 1.6, 0.53)), "leaning antenna", 0 if burnt else 1)
		# EO/IR turrets on their necks: hanging under a nose, standing on one,
		# and the gunship's side-looking turret; a three-window head.
		k = kit(burnt)
		k.surface_family = "aircraft"
		VehicleEquipment.sensor(k, k.root, Vector3(0, 0.3, -4.3), Vector3.ONE * 0.54, "paint", olive, "ball", Vector3(0.14, 0.12, 0.36), 1)
		assert(count_material(k, "glass") == (0 if burnt else 1), "one window, glazed while intact")
		check(k, AABB(Vector3(-0.295, 0.025, -4.6), Vector3(0.59, 0.64, 0.59)), "necked sensor")
		k = kit(burnt)
		k.surface_family = "aircraft"
		VehicleEquipment.sensor(k, k.root, Vector3(0, 2.28, -4.85), Vector3.ONE * 0.42, "paint", olive, "ball", Vector3(0.12, 0.15, -0.3))
		check(k, AABB(Vector3(-0.23, 1.975, -5.08), Vector3(0.46, 0.52, 0.455)), "standing sensor")
		k = kit(burnt)
		k.surface_family = "aircraft"
		VehicleEquipment.sensor(k, k.root, Vector3(-2.18, 0.86, -5.25), Vector3.ONE * 0.6, "paint", olive, "ball", Vector3(0.255, 0.24, 0.245), 2, Vector3(0, PI / 2, 0))
		check(k, AABB(Vector3(-2.505, 0.555, -5.575), Vector3(0.645, 0.61, 0.65)), "side sensor")
		k = kit(burnt)
		k.surface_family = "aircraft"
		VehicleEquipment.sensor(k, k.root, Vector3(-1.25, 0.95, -7.6), Vector3.ONE * 0.6, "paint", olive, "ball", Vector3.ZERO, 3)
		assert(count_material(k, "glass") == (0 if burnt else 3), "three windows, glazed while intact")
		check(k, AABB(Vector3(-1.6, 0.64, -7.92), Vector3(0.7, 0.62, 0.64)), "three-window sensor")
		# Wheel tubs: a civilian well block between a pair of wheels, and one
		# wheel's tub open to the right.
		k = kit(burnt)
		k.surface_family = "automotive"
		VehicleWheelArches.tub(k, k.root, Vector3(0, 0.66, -1.5), Vector3(1.24, 0.48, 0.9))
		check(k, AABB(Vector3(-0.626, 0.42, -1.95), Vector3(1.252, 0.48, 0.9)), "tub")
		k = kit(burnt)
		VehicleWheelArches.tub(k, k.root, Vector3(0.9, 0.9, 1.5), Vector3(0.36, 0.5, 1.1), 1.0)
		check(k, AABB(Vector3(0.72, 0.65, 0.95), Vector3(0.366, 0.5, 1.1)), "side tub")
	print("VEHICLE_PARTS_HULL passed")
	TestRun.quit(get_tree())
