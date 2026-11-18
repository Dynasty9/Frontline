extends Node
## Stowage carried outside the hull: 200-litre drums (VehicleEquipment.drum)
## and the hardware that holds a spare wheel (VehicleWheels.carrier). Each is
## built where an old hand-built copy stood, live and wrecked: it folds into
## its parent, registers no animation and stays inside the envelope of the
## geometry it replaces (a carrier: the spare it holds, the old bracket and the
## point it is mounted on, plus the allowances its doc comment states).

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
			# (as Mats.place sets a noted part: its scale is local to its rotation)
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

func check(k: VehicleModels, envelope: AABB, label: String) -> void:
	assert(k.root.get_child_count() == 0, label + ": construction pivots must fold into their parent")
	assert(k.wheels.is_empty() and k.rotors.is_empty() and k.antennas.is_empty() and k.belts.is_empty(), label + ": static parts must not register wheel, rotor, antenna or belt animation")
	assert(k.turret == null and k.elev == null and k.gun_tip == null and k.mg_tip == null, label + ": builders leave turrets and muzzle markers to the caller")
	assert(not parts(k).is_empty(), label + ": nothing was built")
	var box := bounds(k)
	assert(box.size.is_finite() and box.position.is_finite(), label + ": non-finite geometry")
	if OS.has_environment("FL_DEBUG_PART_BOUNDS"):
		print("PART %s%s %s verts=%d parts=%d" % [label, " (wreck)" if k.burnt else "", box, vertices(k), parts(k).size()])
	else:
		assert(envelope.grow(0.0005).encloses(box), "%s: %s escapes %s" % [label, box, envelope])
	if k.burnt:
		var burnt := Mats.get_mat(VehicleMaterials.key("burnt", k.surface_family))
		for part: Array in parts(k):
			assert(part[1] == burnt, label + ": wrecks use the burnt material throughout")
	k.root.free()

## The box that VehicleWheels.spare(pos, radius, width, rot) fills with its wheel.
func spare_box(pos: Vector3, radius: float, width: float, rot: Vector3) -> AABB:
	var local := AABB(Vector3(-radius, -width * 0.5, -radius), Vector3(radius * 2.0, width, radius * 2.0))
	return Transform3D(Basis.from_euler(rot), pos) * local

## A carrier's envelope: its spare, the old bracket boxes ([size, centre]
## pairs) and the point it is mounted on, grown by `allowance` (the clamp nut
## 2.5 cm proud of the tyre; the strap's ring plate round its mount).
func carrier_box(pos: Vector3, radius: float, width: float, rot: Vector3, mount: Vector3, old: Array = [], allowance := 0.026) -> AABB:
	var box := spare_box(pos, radius, width, rot).expand(mount)
	for i in range(0, old.size(), 2):
		var size: Vector3 = old[i]
		var at: Vector3 = old[i + 1]
		box = box.merge(AABB(at - size * 0.5, size))
	return box.grow(allowance)

func _ready() -> void:
	TestRun.watch()
	const X90 := Vector3(PI / 2, 0, 0)
	for burnt in [false, true]:
		# Drums: the T-55's two on the rear plate (lying, strapped to their
		# brackets), the Zamak supply truck's standing in its bed, and the
		# HEMTT's four on a pallet; envelopes are the old cylinders, rims,
		# hoops, bungs and strap bars.
		for s: float in [-1.0, 1.0]:
			var k := kit(burnt)
			var dc: Color = Color(0.3, 0.2, 0.14) if s < 0.0 else Color(0.28, 0.31, 0.22)
			VehicleEquipment.drum(k, k.root, Vector3(s * 0.66, 1.5, 3.3), 0.29, 0.86, Vector3.BACK, "paint", dc, Vector3(s, 1, 0), 0.2, [-0.15, 0.25], 16)
			check(k, AABB(Vector3(s * 0.66 - 0.33, 1.2, 2.87), Vector3(0.66, 0.62, 0.885)), "T-55 drum %d" % int(s))
		var k := kit(burnt)
		VehicleEquipment.drum(k, k.root, Vector3(-0.86, 1.88, 0.15), 0.29, 0.88, Vector3.UP, "paint", Color(0.4, 0.2, 0.14), Vector3(0.1, 0, 0.12), 0.0, [], 14)
		check(k, AABB(Vector3(-1.16, 1.44, -0.15), Vector3(0.6, 0.9, 0.6)), "Zamak drum")
		var base := Vector3(0.55, 1.38, 0.65)
		for i in 2:
			for j in 2:
				k = kit(burnt)
				var center := base + Vector3((i - 0.5) * 0.46, 0.575, (j - 0.5) * 0.48)
				VehicleEquipment.drum(k, k.root, center, 0.21, 0.95, Vector3.UP, "paint", Color(0.28, 0.32, 0.22) if (i + j) % 2 == 0 else Color(0.36, 0.3, 0.2), Vector3(0.1, 0, 0.05))
				check(k, AABB(center - Vector3(0.218, 0.475, 0.218), Vector3(0.436, 0.9712, 0.436)), "HEMTT drum %d%d" % [i, j])
		# Spare-wheel carriers, each with the spare's own arguments.
		# The Hunter's swing-out carrier, hinged on the left of the tail.
		k = kit(burnt)
		VehicleWheels.carrier(k, k.root, Vector3(0.22, 1.66, 3.0), 0.56, 0.38, X90, "swing", Vector3(-0.5, 1.36, 2.77))
		check(k, carrier_box(Vector3(0.22, 1.66, 3.0), 0.56, 0.38, X90, Vector3(-0.5, 1.36, 2.77), [Vector3(0.12, 0.8, 0.1), Vector3(0.22, 1.66, 2.8), Vector3(1.1, 0.1, 0.1), Vector3(0.0, 1.36, 2.82)]), "Hunter swing carrier")
		# Hub carriers: the MB 4WD's tailgate, the Ifrit's rear face, the
		# Qilin's tail (rising from its edge), the HEMTT's and the M35's cabs.
		k = kit(burnt)
		VehicleWheels.carrier(k, k.root, Vector3(0, 1.08, 2.11), 0.39, 0.27, X90, "hub", Vector3(0, 1.08, 1.98))
		check(k, carrier_box(Vector3(0, 1.08, 2.11), 0.39, 0.27, X90, Vector3(0, 1.08, 1.98), [Vector3(0.2, 0.2, 0.12), Vector3(0, 1.08, 2.02)]), "MB 4WD tailgate carrier")
		k = kit(burnt)
		VehicleWheels.carrier(k, k.root, Vector3(-0.5, 1.62, 3.38), 0.52, 0.36, X90, "hub", Vector3(-0.5, 1.62, 3.16))
		check(k, carrier_box(Vector3(-0.5, 1.62, 3.38), 0.52, 0.36, X90, Vector3(-0.5, 1.62, 3.16), [Vector3(0.5, 0.08, 0.12), Vector3(-0.5, 1.62, 3.2)]), "Ifrit rear carrier")
		k = kit(burnt)
		VehicleWheels.carrier(k, k.root, Vector3(0, 0.98, 2.56), 0.4, 0.28, X90, "hub", Vector3(0, 0.84, 2.376))
		check(k, carrier_box(Vector3(0, 0.98, 2.56), 0.4, 0.28, X90, Vector3(0, 0.84, 2.376)), "Qilin tail carrier")
		k = kit(burnt)
		VehicleWheels.carrier(k, k.root, Vector3(0, 2.0, -2.65), 0.6, 0.42, X90, "hub", Vector3(0, 2.0, -2.91))
		check(k, carrier_box(Vector3(0, 2.0, -2.65), 0.6, 0.42, X90, Vector3(0, 2.0, -2.91)), "HEMTT cab carrier")
		k = kit(burnt)
		VehicleWheels.carrier(k, k.root, Vector3(0.45, 1.75, -0.45), 0.48, 0.3, X90, "hub", Vector3(0.45, 1.75, -0.638))
		check(k, carrier_box(Vector3(0.45, 1.75, -0.45), 0.48, 0.3, X90, Vector3(0.45, 1.75, -0.638)), "M35 cab carrier")
		# Cradles: the Zamak's on the chassis rails behind the cab (its old
		# bar), the Prowler's on the tub's tail, the Tempest's on its
		# platform, the workshop pickup's in the bed.
		k = kit(burnt)
		VehicleWheels.carrier(k, k.root, Vector3(0, 1.74, -0.5), 0.6, 0.4, X90, "cradle", Vector3(0, 1.11, -0.5))
		check(k, carrier_box(Vector3(0, 1.74, -0.5), 0.6, 0.4, X90, Vector3(0, 1.11, -0.5), [Vector3(1.2, 0.08, 0.1), Vector3(0, 1.16, -0.5)]), "Zamak cradle")
		k = kit(burnt)
		VehicleWheels.carrier(k, k.root, Vector3(0, 1.16, 2.25), 0.44, 0.28, X90, "cradle", Vector3(0, 0.78, 2.25))
		check(k, carrier_box(Vector3(0, 1.16, 2.25), 0.44, 0.28, X90, Vector3(0, 0.78, 2.25), [Vector3(0.9, 0.08, 0.08), Vector3(0, 1.1, 2.16)]), "Prowler cradle")
		k = kit(burnt)
		VehicleWheels.carrier(k, k.root, Vector3(-0.55, 2.14, 3.6), 0.6, 0.45, X90, "cradle", Vector3(-0.55, 1.5, 3.6))
		check(k, carrier_box(Vector3(-0.55, 2.14, 3.6), 0.6, 0.45, X90, Vector3(-0.55, 1.5, 3.6)), "Tempest cradle")
		k = kit(burnt)
		VehicleWheels.carrier(k, k.root, Vector3(0.0, 1.36, 0.6), 0.36, 0.25, X90, "cradle", Vector3(0.0, 0.98, 0.6))
		check(k, carrier_box(Vector3(0.0, 1.36, 0.6), 0.36, 0.25, X90, Vector3(0.0, 0.98, 0.6)), "workshop pickup cradle")
		# The technical's spare propped in its bed, strapped to a floor ring.
		k = kit(burnt)
		VehicleWheels.carrier(k, k.root, Vector3(-0.5, 1.0, 1.35), 0.36, 0.25, Vector3(0.12, 0, 0.18), "strap", Vector3(-0.1, 0.88, 1.12))
		check(k, carrier_box(Vector3(-0.5, 1.0, 1.35), 0.36, 0.25, Vector3(0.12, 0, 0.18), Vector3(-0.1, 0.88, 1.12), [], 0.04), "technical bed strap")
	# A spare and its carrier together: the spare's pivot folds as before
	# and nothing is registered for the wheel animation.
	var k := kit()
	VehicleWheels.spare(k, k.root, Vector3(0, 1.08, 2.11), 0.39, 0.27, X90, "gunmetal_w", Color(0.25, 0.25, 0.24))
	VehicleWheels.carrier(k, k.root, Vector3(0, 1.08, 2.11), 0.39, 0.27, X90, "hub", Vector3(0, 1.08, 1.98))
	check(k, carrier_box(Vector3(0, 1.08, 2.11), 0.39, 0.27, X90, Vector3(0, 1.08, 1.98)), "spare on its carrier")
	print("VEHICLE_PARTS_STOWAGE passed")
	TestRun.quit(get_tree())
