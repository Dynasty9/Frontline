extends Node
## The third pass's cabin, body and load parts: benches, tanker tops and pump
## cabinets, gas bottle racks, roof rails and racks, and crate stacks, built
## with the parameters of the sites they replace. Each folds into its parent,
## registers no animation, carries no glass and stays inside an envelope close
## to the geometry it replaces (noted case by case below).

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

func check(k: VehicleModels, envelope: AABB, label: String) -> void:
	assert(k.root.get_child_count() == 0, label + ": construction pivots must fold into their parent")
	assert(k.wheels.is_empty() and k.rotors.is_empty(), label + ": static parts must not register wheel or rotor animation")
	assert(k.turret == null and k.elev == null and k.gun_tip == null and k.mg_tip == null, label + ": builders leave turrets and muzzle markers to the caller")
	assert(not parts(k).is_empty(), label + ": nothing was built")
	assert(count(k, "glass") == 0, label + ": these parts carry no glass")
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
	for burnt in [false, true]:
		# Benches. The HEMTT's troop bench: slats on folding legs down to the
		# deck (1.38), hinged to the side rack, the backrest board bolted to it.
		var k := kit(burnt)
		VehicleCab.bench(k, k.root, Vector3(0.88, 1.85, 1.3), Vector3(0.38, 0.08, 6.6), Vector3.LEFT, Vector3(0.06, 0.3, 0.06), "wood_dark", null, 0.43, true)
		assert(absf(bounds(k).position.y - 1.38) < 0.001, "troop bench: the legs stand on the deck")
		check(k, AABB(Vector3(0.69, 1.38, -2.0), Vector3(0.44, 0.87, 6.6)), "troop bench")
		# The civilian truck's bench, its back board high on the dropside.
		k = kit(burnt)
		VehicleCab.bench(k, k.root, Vector3(0.8, 1.6, 0.95), Vector3(0.32, 0.05, 3.3), Vector3.LEFT, Vector3(0.145, 0.14, 0.04), "wood", null, 0.325, true)
		check(k, AABB(Vector3(0.64, 1.25, -0.7), Vector3(0.37, 0.66, 3.3)), "dropside bench")
		# The DAGOR's outward bench: a cushion on its frame, the back inboard.
		k = kit(burnt)
		VehicleCab.bench(k, k.root, Vector3(0.45, 1.0, 1.62), Vector3(0.4, 0.1, 0.9), Vector3.RIGHT, Vector3(-0.03, 0.36, 0.08), "canvas", Color(0.2, 0.21, 0.17))
		check(k, AABB(Vector3(0.155, 0.925, 1.17), Vector3(0.5, 0.455, 0.9)), "outward bench")
		# The LSV's pair back to back: two calls whose backs meet on the centre line.
		k = kit(burnt)
		for s: float in [-1.0, 1.0]:
			VehicleCab.bench(k, k.root, Vector3(s * 0.25, 1.0, 1.6), Vector3(0.4, 0.08, 1.2), Vector3(s, 0, 0), Vector3(-0.06, 0.36, 0.05), "canvas", Color(0.24, 0.24, 0.2))
		check(k, AABB(Vector3(-0.45, 0.935, 1.0), Vector3(0.9, 0.405, 1.2)), "back-to-back benches")
		# The MB 4WD's rear seat, its back as the old box (leaning 7 degrees).
		k = kit(burnt)
		VehicleCab.bench(k, k.root, Vector3(0, 1.04, 0.95), Vector3(1.4, 0.12, 0.45), Vector3.FORWARD, Vector3(-0.04, 0.5, 0.12), "plain", Color(0.16, 0.16, 0.15), 0.0, false, -0.12, 0.035)
		check(k, AABB(Vector3(-0.7, 0.955, 0.725), Vector3(1.4, 0.61, 0.6)), "rear bench")
		# The landing craft's troop seats on the bulwark, reclined.
		k = kit(burnt)
		VehicleCab.bench(k, k.root, Vector3(1.02, 1.76, 2.9), Vector3(0.44, 0.08, 0.86), Vector3.LEFT, Vector3(0.03, 0.38, 0.08), "plain_dark", Color(0.14, 0.14, 0.13), 0.0, true, 0.14, 0.06)
		check(k, AABB(Vector3(0.8, 1.695, 2.47), Vector3(0.49, 0.53, 0.86)), "bulwark bench")
		# The MH-6's external pad: no back, on the caller's tray.
		k = kit(burnt)
		VehicleCab.bench(k, k.root, Vector3(1.05, 0.82, -0.12), Vector3(0.42, 0.04, 1.75), Vector3.RIGHT, Vector3.ZERO, "canvas", Color(0.18, 0.19, 0.16))
		check(k, AABB(Vector3(0.84, 0.775, -0.995), Vector3(0.42, 0.07, 1.75)), "backless pad")
		# Tanker tops on each family's barrel: the HEMTT's central walkway over
		# three manholes, the Tempest's with a ladder up the back, the Zamak's
		# offset walkway beside two manholes, its rails standing on the shell.
		k = kit(burnt)
		VehicleEquipment.vessel(k, k.root, Vector3(0, 2.08, 0.75), Vector3(2.24, 1.36, 5.9), [-2.15, 0.0, 2.15], "camo_tank")
		var shell := bounds(k)
		k.root.free()
		k = kit(burnt)
		VehicleEquipment.tanker_top(k, k.root, Vector3(0, 2.08, 0.75), Vector3(2.24, 1.36, 5.9), "camo_tank", null, Vector3(0.6, 5.6, 0.0), [-1.2, 0.75, 2.7], Vector2(0.3, 0.44), 0.24)
		var top := bounds(k)
		assert(top.position.y > shell.end.y - 0.06, "the walkway and manholes sit on the crown, not inside the barrel")
		check(k, AABB(Vector3(-0.35, 2.72, -2.05), Vector3(0.7, 0.55, 5.6)), "HEMTT tanker top")
		k = kit(burnt)
		VehicleEquipment.tanker_top(k, k.root, Vector3(0, 2.38, 0.9), Vector3(2.36, 1.72, 5.72), "camo_tank", null, Vector3(0.7, 5.0, 0.0), [-0.8, 0.8, 2.4], Vector2(0.38, 0.31), 0.25, Vector3(0.62, 1.35, 3.78), 0.5)
		check(k, AABB(Vector3(-0.42, 1.35, -1.6), Vector3(1.32, 2.26, 5.47)), "Tempest tanker top")
		k = kit(burnt)
		VehicleEquipment.tanker_top(k, k.root, Vector3(0, 2.02, 1.5), Vector3(2.34, 1.44, 3.42), "camo_tank", olive, Vector3(0.36, 2.9, -0.42), [0.75, 2.25], Vector2(0.62, 0.25), 0.22)
		check(k, AABB(Vector3(-0.66, 2.55, 0.05), Vector3(1.32, 0.48, 2.9)), "Zamak tanker top")
		# Pump cabinets: across the HEMTT's and the Zamak's tails, the Tempest's
		# small one, and one facing the side.
		k = kit(burnt)
		VehicleEquipment.pump_cabinet(k, k.root, Vector3(0, 2.0, 4.42), Vector3(2.4, 1.3, 1.2), Vector3.BACK, "camo_tank")
		check(k, AABB(Vector3(-1.2, 1.35, 3.82), Vector3(2.4, 1.3, 1.265)), "tail pump cabinet")
		k = kit(burnt)
		VehicleEquipment.pump_cabinet(k, k.root, Vector3(-0.6, 1.85, 4.1), Vector3(1.0, 0.7, 0.6), Vector3.BACK, "gunmetal_w", null, 1)
		check(k, AABB(Vector3(-1.1, 1.5, 3.8), Vector3(1.0, 0.7, 0.665)), "small pump cabinet")
		k = kit(burnt)
		VehicleEquipment.pump_cabinet(k, k.root, Vector3(1.0, 1.6, 2.0), Vector3(0.5, 0.8, 1.2), Vector3.RIGHT, "paint", olive)
		check(k, AABB(Vector3(0.75, 1.2, 1.4), Vector3(0.565, 0.8, 1.2)), "side pump cabinet")
		# Gas bottles: the Tempest's pair against the bed side, the pickup's
		# across the bed, the Zamak's open valves.
		k = kit(burnt)
		VehicleEquipment.gas_bottle(k, k.root, [Vector3(-0.95, 1.95, 2.55), Vector3(-0.95, 1.95, 2.8)], 0.1, 0.9, [Color(0.25, 0.32, 0.3), Color(0.5, 0.42, 0.2)], Vector3.LEFT)
		check(k, AABB(Vector3(-1.085, 1.485, 2.405), Vector3(0.27, 1.03, 0.54)), "bottle rack")
		k = kit(burnt)
		VehicleEquipment.gas_bottle(k, k.root, [Vector3(0.62, 1.43, 1.85), Vector3(0.4, 1.43, 1.85)], 0.1, 0.9, [Color(0.2, 0.3, 0.22), Color(0.6, 0.5, 0.18)], Vector3.FORWARD)
		check(k, AABB(Vector3(0.25, 0.965, 1.715), Vector3(0.52, 1.03, 0.27)), "bed bottle rack")
		k = kit(burnt)
		VehicleEquipment.gas_bottle(k, k.root, [Vector3(-1.02, 1.97, 3.2), Vector3(-1.02, 1.97, 3.46)], 0.11, 1.05, [Color(0.42, 0.2, 0.14), Color(0.22, 0.27, 0.32)], Vector3.LEFT, false)
		check(k, AABB(Vector3(-1.165, 1.43, 3.045), Vector3(0.29, 1.165, 0.57)), "open bottles")
		# Roof rails and racks: the service van's rack of five bars on four
		# feet a side, the Ifrit's rails on end feet, the Hunter's flush rails.
		k = kit(burnt)
		VehicleCargo.roof_rack(k, k.root, Vector3(0, 2.59, 1.0), Vector3(1.56, 0.155, 3.5), 4, 5, "paint", Color(0.55, 0.56, 0.55))
		check(k, AABB(Vector3(-0.82, 2.59, -0.75), Vector3(1.64, 0.2, 3.5)), "van roof rack")
		k = kit(burnt)
		VehicleCargo.roof_rack(k, k.root, Vector3(0, 2.49, 1.95), Vector3(1.36, 0.075, 1.6), -1, 0, "gunmetal_w", null, Vector2(0.04, 0.05))
		check(k, AABB(Vector3(-0.71, 2.49, 1.15), Vector3(1.42, 0.082, 1.6)), "roof rails")
		k = kit(burnt)
		VehicleCargo.roof_rack(k, k.root, Vector3(0, 2.6, 0.42), Vector3(1.92, 0.045, 2.1))
		check(k, AABB(Vector3(-0.99, 2.59, -0.63), Vector3(1.98, 0.065, 2.1)), "flush roof rails")
		# Crate stacks: the HEMTT's ammunition pallet of four boxes, the Zamak's
		# three-high stack strapped twice, the Tempest's row of six, a wooden
		# crate, and a stack turned on the bed.
		k = kit(burnt)
		VehicleCargo.crate_stack(k, k.root, Vector3(0.56, 1.38, -1.7), Vector3(1.05, 0.74, 1.1), Vector3i(2, 1, 2), "paint", olive, 0.12, [0.0])
		check(k, AABB(Vector3(0.01, 1.38, -2.26), Vector3(1.1, 0.76, 1.12)), "ammunition pallet")
		k = kit(burnt)
		VehicleCargo.crate_stack(k, k.root, Vector3(0.6, 1.44, 1.53), Vector3(1.05, 0.82, 0.98), Vector3i(1, 3, 1), "paint", olive, 0.1, [-0.25, 0.25])
		check(k, AABB(Vector3(0.055, 1.44, 1.03), Vector3(1.09, 0.84, 1.0)), "strapped stack")
		k = kit(burnt)
		VehicleCargo.crate_stack(k, k.root, Vector3(0, 1.51, 0.95), Vector3(2.1, 0.92, 0.8), Vector3i(3, 2, 1), "paint", olive, 0.1, [], -0.15)
		check(k, AABB(Vector3(-1.06, 1.51, 0.54), Vector3(2.12, 0.93, 0.82)), "case row")
		k = kit(burnt)
		VehicleCargo.crate_stack(k, k.root, Vector3(-0.55, 1.38, -1.7), Vector3(0.94, 0.9, 0.96), Vector3i.ONE, "wood")
		check(k, AABB(Vector3(-1.03, 1.38, -2.19), Vector3(0.96, 0.9, 0.98)), "wooden crate")
		k = kit(burnt)
		VehicleCargo.crate_stack(k, k.root, Vector3(0.62, 1.44, 0.22), Vector3(0.95, 0.62, 0.72), Vector3i(2, 2, 1), "wood_dark", null, 0.0, [], 0.12, Color(0.28, 0.26, 0.2), 0.3)
		check(k, AABB(Vector3(0.05, 1.44, -0.33), Vector3(1.14, 0.62, 1.1)), "turned crates")
	print("VEHICLE_PARTS_CABIN passed")
	TestRun.quit(get_tree())
