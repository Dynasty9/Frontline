extends Node
## The truck, technical and launcher parts of the second extraction pass: cargo
## beds, box bodies and their doors and shutters, weapon pedestals, shields and
## rings, roll bars and bull bars, box launchers. Each folds into its parent
## (leaving only the caller's own turret nodes), registers no animation, stays
## inside the envelope of the geometry it replaces and drops its lenses on
## wrecks.

func kit(burnt := false) -> VehicleModels:
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k._baking = true
	k.burnt = burnt
	return k

## Every noted part, wherever it hangs below the root, in the root's frame.
func bounds(k: VehicleModels) -> AABB:
	var box := AABB()
	var first := true
	for node: Node3D in k._parts:
		var place := Transform3D.IDENTITY
		var n := node
		while n != null and n != k.root:
			place = n.transform * place
			n = n.get_parent() as Node3D
		for part: Array in k._parts[node]:
			var basis: Basis = part[7] if part[7] is Basis else Basis.from_euler(part[5]) * Basis.from_scale(part[6])
			var aabb := place * Transform3D(basis, part[4]) * (part[0] as Mesh).get_aabb()
			box = aabb if first else box.merge(aabb)
			first = false
	return box

func parts(k: VehicleModels) -> Array:
	var out := []
	for node: Node3D in k._parts:
		out.append_array(k._parts[node])
	return out

func vertices(k: VehicleModels) -> int:
	var total := 0
	for part: Array in parts(k):
		var mesh: Mesh = part[0]
		for i in mesh.get_surface_count():
			total += (mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return total

func count(k: VehicleModels, kind: String) -> int:
	var mat := Mats.get_mat(VehicleMaterials.key(kind, k.surface_family))
	var n := 0
	for part: Array in parts(k):
		if part[1] == mat:
			n += 1
	return n

## `heads` are the caller's own turret nodes, the only nodes allowed to remain.
func check(k: VehicleModels, envelope: AABB, label: String, heads: Array = []) -> void:
	assert(k.root.get_child_count() == heads.size(), label + ": construction pivots must fold into their parent")
	for head: Node3D in heads:
		assert(head.get_parent() == k.root and head.get_child_count() == 0, label + ": the caller's head keeps no construction nodes")
	assert(k.wheels.is_empty() and k.rotors.is_empty(), label + ": static parts must not register wheel or rotor animation")
	assert(k.turret == null and k.elev == null and k.gun_tip == null and k.mg_tip == null, label + ": builders leave turrets and muzzle markers to the caller")
	assert(not parts(k).is_empty(), label + ": nothing was built")
	var box := bounds(k)
	assert(box.size.is_finite() and box.position.is_finite(), label + ": non-finite geometry")
	if OS.has_environment("FL_DEBUG_PART_BOUNDS"):
		print("PART %s %s verts=%d parts=%d" % [label, box, vertices(k), parts(k).size()])
	else:
		assert(envelope.grow(0.0005).encloses(box), "%s: %s escapes %s" % [label, box, envelope])
	if k.burnt:
		var burnt := Mats.get_mat(VehicleMaterials.key("burnt", k.surface_family))
		for part: Array in parts(k):
			assert(part[1] == burnt, label + ": wrecks use the burnt material throughout")
	k.root.free()

func _ready() -> void:
	TestRun.watch()
	var olive := Color(0.3, 0.33, 0.22)
	var al := Color(0.62, 0.63, 0.62)
	for burnt in [false, true]:
		# Cargo beds: the civilian dropside with its cab guard, the HEMTT's tall
		# steel sides, the Zamak's flat deck.
		var k := kit(burnt)
		VehicleCargo.flatbed(k, k.root, -1.0, 2.8, 2.1, 1.25, "paint", al, 0.42, 3, 0.5, 0.725, 0.1, "wood_dark", null, Vector3(0.4, 0.14, 0.15), 0.05)
		check(k, AABB(Vector3(-1.09, 1.0, -1.01), Vector3(2.18, 1.52, 3.84)), "dropside flatbed")
		k = kit(burnt)
		VehicleCargo.flatbed(k, k.root, -2.4, 5.05, 2.44, 1.38, "camo_tank", null, 0.62, 6, 1.1, 0.0, 0.16, "paint", olive, Vector3(1.1, 0.18, 0.2), 0.06)
		check(k, AABB(Vector3(-1.265, 1.03, -2.41), Vector3(2.53, 1.46, 7.49)), "troop flatbed")
		k = kit(burnt)
		VehicleCargo.flatbed(k, k.root, -0.25, 3.8, 2.5, 1.44, "paint", olive, 0.0, 5, 0.0, 0.0, 0.12, "", null, Vector3(0.48, 0.14, 0.16))
		check(k, AABB(Vector3(-1.29, 1.17, -0.26), Vector3(2.58, 0.28, 4.07)), "flat deck")
		# Box bodies: a square shelter with a single door and a roof ladder,
		# a chamfered kung with double doors; clearance lenses go on a wreck.
		k = kit(burnt)
		VehicleCargo.shelter(k, k.root, -2.32, 4.98, 2.44, 1.39, 3.01, "camo_tank", null, Rect2(Vector2(0.45, 2.15), Vector2(0.9, 1.4)), 1, 0, 0.0, 0.0, -0.6, 2)
		assert(count(k, "signal_lens") == (0 if burnt else 24), "shelter markers keep their lenses only while intact")
		check(k, AABB(Vector3(-1.26, 1.27, -2.345), Vector3(2.52, 2.0, 7.425)), "square shelter")
		k = kit(burnt)
		VehicleCargo.shelter(k, k.root, -0.2, 2.85, 2.48, 1.44, 2.98, "paint", olive, Rect2(), 2, -1, 0.06, 0.06)
		check(k, AABB(Vector3(-1.28, 1.43, -0.225), Vector3(2.56, 1.72, 3.145)), "chamfered shelter")
		k = kit(burnt)
		VehicleCargo.body_door(k, k.root, Vector3(1.25, 2.15, 2.36), Vector2(0.72, 1.32), Vector3.RIGHT, -1, "paint", olive)
		check(k, AABB(Vector3(1.24, 1.44, 1.95), Vector3(0.08, 1.45, 0.82)), "side door")
		k = kit(burnt)
		VehicleCargo.roller_shutter(k, k.root, Vector3(1.22, 2.2, -1.2), Vector2(1.9, 1.3), Vector3.RIGHT, "paint", olive)
		check(k, AABB(Vector3(1.22, 1.48, -2.19), Vector3(0.065, 1.47, 1.98)), "roller shutter")
		k = kit(burnt)
		VehicleCargo.roller_shutter(k, k.root, Vector3(-1.255, 1.85, 2.35), Vector2(0.9, 0.7), Vector3.LEFT)
		check(k, AABB(Vector3(-1.32, 1.42, 1.86), Vector3(0.07, 0.88, 0.98)), "locker shutter")
		# Weapon mounts: a technical's pedestal under its traversing head, a
		# bar clamp, the head's shield, both ring mounts.
		k = kit(burnt)
		var head := k._pivot(k.root, Vector3(0, 1.62, 1.5))
		VehicleMounts.pedestal(k, k.root, Vector3(0, 0.98, 1.5), Vector3(0, 1.62, 1.5), head)
		VehicleMounts.gun_shield(k, head, Vector3(0, 0.38, -0.42), Vector2(0.62, 0.52), "paint", Color(0.2, 0.21, 0.19))
		check(k, AABB(Vector3(-0.52, 0.97, 1.03), Vector3(1.04, 1.31, 0.73)), "pedestal and shield", [head])
		k = kit(burnt)
		head = k._pivot(k.root, Vector3(0, 1.58, 1.5))
		VehicleMounts.pedestal(k, k.root, Vector3(0, 0.88, 1.5), Vector3(0, 1.58, 1.5), head, "gunmetal_w", null, 0.5, Vector2(0.06, 0.07), 4, Vector3(0.09, 0.26, 0.14))
		VehicleMounts.gun_shield(k, head, Vector3(0, 0.34, -0.5), Vector2(1.0, 0.44), "steel", Color(0.3, 0.31, 0.26), 0.1, Vector2(0.26, -0.6), Vector2(0.14, 0.1))
		check(k, AABB(Vector3(-0.53, 0.87, 0.96), Vector3(1.06, 1.29, 0.8)), "wrapped shield", [head])
		k = kit(burnt)
		head = k._pivot(k.root, Vector3(0, 1.94, 1.15))
		VehicleMounts.pedestal(k, k.root, Vector3(0, 1.76, 1.15), Vector3(0, 1.94, 1.15), head, "gunmetal_w", null, 0.0, Vector2(0.045, 0.05), 0, Vector3(0.04, 0.1, 0.08), 0.035)
		check(k, AABB(Vector3(-0.1, 1.7, 1.04), Vector3(0.23, 0.37, 0.22)), "bar clamp pedestal", [head])
		k = kit(burnt)
		VehicleMounts.ring_mount(k, k.root, Vector3(0, 1.82, 0.58), 0.48, 0.03, "gunmetal_w", null, [], k.root, -0.12)
		check(k, AABB(Vector3(-0.52, 1.74, 0.06), Vector3(1.04, 0.16, 1.04)), "turning ring")
		k = kit(burnt)
		head = k._pivot(k.root, Vector3(0, 1.74, 0.12))
		VehicleMounts.ring_mount(k, k.root, Vector3(0, 1.72, 0.12), 0.36, 0.03, "camo_tank", null, [Vector3(-0.6, 1.7, 0.12), Vector3(0.6, 1.7, 0.12)], head)
		check(k, AABB(Vector3(-0.65, 1.63, -0.27), Vector3(1.3, 0.17, 0.78)), "braced ring", [head])
		# Tubework: the Hilux's hoop and stays, the Dagor's cage, the Hilux's
		# bull bar on its legs and the Dagor's tube bumper.
		k = kit(burnt)
		VehicleFrames.roll_bar(k, k.root, [[Vector3(-0.8, 1.17, 1.12), Vector3(-0.74, 1.86, 1.08), Vector3(0.74, 1.86, 1.08), Vector3(0.8, 1.17, 1.12)], [Vector3(-0.76, 1.8, 1.1), Vector3(-0.8, 1.17, 1.62), 0.03], [Vector3(0.76, 1.8, 1.1), Vector3(0.8, 1.17, 1.62), 0.03]], 0.036)
		check(k, AABB(Vector3(-0.9, 1.14, 1.0), Vector3(1.8, 0.76, 0.7)), "roll bar")
		k = kit(burnt)
		var cage := []
		var cr := 0.035
		for s: float in [-1.0, 1.0]:
			var x0 := s * 0.7
			var x1 := s * 0.68
			cage.append([Vector3(x0, 1.08, -0.92), Vector3(x1, 1.8, -0.28), Vector3(x1, 1.8, 1.05), Vector3(x1 * 0.98, 1.32, 2.15), Vector3(x1 * 0.98, 0.8, 2.15)])
			cage.append([Vector3(x1, 0.8, 0.12), Vector3(x1, 1.8, 0.12)])
			cage.append([Vector3(x1, 0.8, 1.05), Vector3(x1, 1.8, 1.05)])
			cage.append([Vector3(x1, 1.3, 0.12), Vector3(x1, 1.3, 1.05), cr * 0.8])
			cage.append([Vector3(x1, 0.8, 0.12), Vector3(x1, 1.6, 1.05), cr * 0.7])
		for z: float in [-0.28, 0.12, 1.05]:
			cage.append([Vector3(-0.68, 1.8, z), Vector3(0.68, 1.8, z)])
		cage.append([Vector3(-0.67, 1.32, 2.15), Vector3(0.67, 1.32, 2.15)])
		cage.append([Vector3(-0.68, 1.8, 0.12), Vector3(0.68, 1.8, 1.05), cr * 0.8])
		VehicleFrames.roll_bar(k, k.root, cage, cr, "camo_tank")
		check(k, AABB(Vector3(-0.79, 0.78, -1.0), Vector3(1.58, 1.07, 3.24)), "roll cage")
		k = kit(burnt)
		var nz := -2.45
		VehicleFrames.bull_bar(k, k.root, [[Vector3(-0.7, 0.62, nz - 0.2), Vector3(-0.7, 1.08, nz - 0.18), Vector3(0.7, 1.08, nz - 0.18), Vector3(0.7, 0.62, nz - 0.2)], [Vector3(-0.7, 0.86, nz - 0.19), Vector3(0.7, 0.86, nz - 0.19), 0.03], [Vector3(-0.7, 0.62, nz - 0.2), Vector3(-0.7, 0.55, nz + 0.05), 0.03], [Vector3(0.7, 0.62, nz - 0.2), Vector3(0.7, 0.55, nz + 0.05), 0.03]], 0.035, "gunmetal_w", null, 2)
		check(k, AABB(Vector3(-0.77, 0.46, -2.7), Vector3(1.54, 0.75, 0.38)), "bull bar")
		k = kit(burnt)
		VehicleFrames.bull_bar(k, k.root, [[Vector3(-0.72, 0.6, -2.08), Vector3(-0.85, 0.66, -2.32), Vector3(0.85, 0.66, -2.32), Vector3(0.72, 0.6, -2.08)]], 0.045)
		check(k, AABB(Vector3(-0.92, 0.46, -2.38), Vector3(1.84, 0.28, 0.39)), "tube bumper")
		# Box launchers: the TOW box on its arm, a tilted Drozd pair box, a
		# rocket pod's face standing proud of its launcher.
		k = kit(burnt)
		VehicleWeapons.missile_box(k, k.root, Vector3(-1.32, 0.42, -0.1), Vector3(0.44, 0.5, 1.38), 2, 1, 0.1, "paint", olive, Vector3.ZERO, false, Vector3.RIGHT)
		check(k, AABB(Vector3(-1.55, 0.16, -0.8), Vector3(0.51, 0.52, 1.4)), "missile box")
		k = kit(burnt)
		VehicleWeapons.missile_box(k, k.root, Vector3(1.56, 0.3, -0.42), Vector3(0.22, 0.2, 0.46), 1, 2, 0.065, "paint", olive, Vector3(-0.12, 0.25, 0), true, Vector3.LEFT)
		check(k, AABB(Vector3(1.37, 0.14, -0.7), Vector3(0.36, 0.32, 0.56)), "covered missile box")
		k = kit(burnt)
		VehicleWeapons.missile_face(k, k.root, Vector3(0.54, 0.43, -3.83), Vector2(1.0, 0.76), 2, 3, 0.12, "paint", olive, Vector3.ZERO, false, Vector2(0.31, 0.38), 0.04)
		check(k, AABB(Vector3(0.04, 0.05, -3.846), Vector3(1.0, 0.76, 0.06)), "pod face")
	print("VEHICLE_PARTS_TRUCKS passed")
	TestRun.quit(get_tree())
