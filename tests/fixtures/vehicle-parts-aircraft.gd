extends Node
## The aircraft stores and fittings of the second construction pass: missiles,
## store pods, engine faces, stub-wing pylons and rotor hub caps. Each folds
## into its parent, registers no animation, keeps the point it was given,
## stays inside the envelope of the geometry it replaces (measured from the
## old primitives, grown only where the builder adds real hardware such as
## suspension lugs) and drops intact glass on wrecks.

const GREY := Color(0.55, 0.56, 0.55)
const LIGHT := Color(0.68, 0.69, 0.68)
const DRAB := Color(0.3, 0.33, 0.26)

func kit(burnt := false) -> VehicleModels:
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k._baking = true
	k.burnt = burnt
	return k

func parts(k: VehicleModels, node: Node3D) -> Array:
	return k._parts.get(node, [])

func bounds(k: VehicleModels, node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for part: Array in parts(k, node):
		var xf: Transform3D = Transform3D(part[7], part[4]) if part[7] is Basis else Mats.place(part[4], part[5], part[6])
		var aabb := xf * (part[0] as Mesh).get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	return box

func check(k: VehicleModels, envelope: AABB, label: String, node: Node3D = null) -> void:
	var on := node if node else k.root
	assert(on.get_child_count() == 0, label + ": construction pivots must fold into their parent")
	assert(k.wheels.is_empty() and k.rotors.is_empty() and k.rotor == null and k.tail_rotor == null, label + ": static parts must not register wheels or rotors")
	assert(not parts(k, on).is_empty(), label + ": nothing was built")
	var box := bounds(k, on)
	assert(box.size.is_finite() and box.position.is_finite(), label + ": non-finite geometry")
	if OS.has_environment("FL_DEBUG_PART_BOUNDS"):
		print("PART %s %s end %s" % [label, box.position, box.end])
	else:
		assert(envelope.grow(0.0005).encloses(box), "%s: %s escapes %s" % [label, box, envelope])
	if k.burnt:
		var burnt := Mats.get_mat(VehicleMaterials.key("burnt", k.surface_family))
		for part: Array in parts(k, on):
			assert(part[1] == burnt, label + ": wrecks use the burnt material throughout")
	k.root.free()

func glass_count(k: VehicleModels, node: Node3D = null) -> int:
	var glass := Mats.get_mat(VehicleMaterials.key("glass", k.surface_family))
	var n := 0
	for part: Array in parts(k, node if node else k.root):
		if part[1] == glass:
			n += 1
	return n

## An old envelope (measured from the replaced primitives), grown by `side`
## all round and `up` more above, where lugs or hangers now stand.
func env(from: Vector3, to: Vector3, side := 0.006, up := 0.0) -> AABB:
	return AABB(from - Vector3.ONE * side, to - from + Vector3.ONE * side * 2.0 + Vector3(0, up, 0))

## The pylon as it was before the helicopter parameters: the default call
## must still lay down exactly these parts.
func old_hardpoint(k: VehicleModels, parent: Node3D, top: Vector3, length: float, height: float, col: Color, payload_radius := 0.0, width := 0.09) -> Vector3:
	var profile := [-length * 0.5, 0.08, length * 0.5, 0.08, length * 0.4, -height, -length * 0.3, -height]
	k._add(parent, VehicleModels.extrude_x("hardpoint_" + var_to_str([length, height, width]), profile, -width * 0.5, width * 0.5), "aircraft", col, top)
	for side: float in [-1.0, 1.0]:
		k._add(parent, BevelMesh.make(Vector3(0.006, height * 0.34, length * 0.35), 0.0015), "aircraft", col.darkened(0.08), top + Vector3(side * (width * 0.5 + 0.003), -height * 0.35, 0))
		for z: float in [-length * 0.25, length * 0.25]:
			var foot := top + Vector3(side * (width * 0.5 + 0.035), -height + 0.015, z)
			VehicleFrames.tube(k, parent, top + Vector3(side * width * 0.4, -height + 0.08, z), foot, 0.014, "steel", null, 6, false)
			k._box(parent, Vector3(0.045, 0.018, 0.06), foot, "metal_dark")
			VehicleBody.fastener(k, parent, foot + Vector3(0, 0.012, 0), Vector3.UP, 0.012)
	VehicleFrames.beam(k, parent, top + Vector3(0, -height - 0.006, -length * 0.3), top + Vector3(0, -height - 0.006, length * 0.35), width * 0.7, 0.02, "metal_dark")
	return top + Vector3(0, -height - payload_radius, 0)

func same_parts(a: VehicleModels, b: VehicleModels, label: String) -> void:
	var pa := parts(a, a.root)
	var pb := parts(b, b.root)
	assert(pa.size() == pb.size(), "%s: %d parts, was %d" % [label, pa.size(), pb.size()])
	for i in pa.size():
		var x: Array = pa[i]
		var y: Array = pb[i]
		assert(x[1] == y[1] and x[2] == y[2] and x[3] == y[3], "%s: part %d's surface changed" % [label, i])
		assert((x[4] as Vector3).is_equal_approx(y[4]) and (x[5] as Vector3).is_equal_approx(y[5]) and (x[6] as Vector3).is_equal_approx(y[6]), "%s: part %d moved" % [label, i])
		var ma := x[0] as Mesh
		var mb := y[0] as Mesh
		assert(ma.get_aabb().is_equal_approx(mb.get_aabb()), "%s: part %d's shape changed" % [label, i])
	a.root.free()
	b.root.free()

func _ready() -> void:
	TestRun.watch()
	for burnt in [false, true]:
		var glass := 0 if burnt else 1
		# --- missiles, each in the conversion its old helper takes ---------------
		# VmPlane.missile (2.85 m Sidewinder on its rail)
		var L := 2.85
		var r := 0.064
		var k := kit(burnt)
		VehicleAircraft.missile(k, k.root, Vector3.ZERO, L * 0.97, r, GREY, VehicleAircraft.seeker(L * 0.1, r * 0.42),
			[VehicleAircraft.fin_set(-0.37 * L, -0.29 * L, r * 1.6), VehicleAircraft.fin_set(0.375 * L, 0.485 * L, r * 2.5)],
			Vector2(-0.3 * L, 0.08), Vector3(0.07, 0.07, L * 0.6), 0.05 * L)
		assert(glass_count(k) == glass, "missile seeker glass follows the wreck state")
		check(k, env(Vector3(-0.1626, -0.1626, -1.4078), Vector3(0.1626, 0.1626, 1.3823)), "plane missile")
		# VmFighter._aim9x
		k = kit(burnt)
		VehicleAircraft.missile(k, k.root, Vector3.ZERO, 3.0, 0.0635, LIGHT, VehicleAircraft.seeker(0.14, 0.0356),
			[VehicleAircraft.fin_set(-1.05, -0.86, 0.04, -1.0, -0.9), VehicleAircraft.fin_set(1.18, 1.5, 0.11, 1.32, 1.5)], Vector2(-0.9, 0.06))
		assert(glass_count(k) == glass)
		check(k, env(Vector3(-0.1262, -0.1262, -1.5056), Vector3(0.1262, 0.1262, 1.5)), "aim9x")
		# VmFighter._aim120: the ogive radome has no glass
		k = kit(burnt)
		VehicleAircraft.missile(k, k.root, Vector3.ZERO, 3.66, 0.089, LIGHT, VehicleAircraft.ogive(0.53),
			[VehicleAircraft.fin_set(-0.35, 0.1, 0.13, -0.15, 0.08), VehicleAircraft.fin_set(1.5, 1.83, 0.135, 1.66, 1.83)], Vector2(-1.28, 0.05))
		assert(glass_count(k) == 0)
		check(k, env(Vector3(-0.1619, -0.1619, -1.83), Vector3(0.1619, 0.1619, 1.83)), "aim120")
		# VmHeli._missile (a Hellfire): a lighter blunt cone, tail fins only
		L = 1.62
		r = 0.085
		k = kit(burnt)
		VehicleAircraft.missile(k, k.root, Vector3.ZERO, L * 0.94, r, DRAB, VehicleAircraft.cone(L * 0.14),
			[VehicleAircraft.fin_set(0.34 * L, 0.46 * L, r * 0.7)], Vector2.ZERO, Vector3.ZERO, 0.0, "paint", DRAB.lightened(0.15))
		assert(glass_count(k) == 0)
		check(k, env(Vector3(-0.1064, -0.1064, -0.7776), Vector3(0.1064, 0.1064, 0.7614)), "heli missile")
		# VmPlane.agm (a Maverick on its adapter rail): long low wings
		L = 2.49
		r = 0.152
		k = kit(burnt)
		VehicleAircraft.missile(k, k.root, Vector3.ZERO, L, r, GREY, VehicleAircraft.seeker(L * 0.1, r * 0.62),
			[VehicleAircraft.fin_set(-0.09 * L, 0.33 * L, r * 0.8), VehicleAircraft.fin_set(0.4 * L, 0.5 * L, r)], Vector2.ZERO, Vector3(0.08, 0.06, L * 0.5), 0.0)
		assert(glass_count(k) == glass)
		check(k, env(Vector3(-0.2192, -0.2192, -1.2457), Vector3(0.2192, 0.2192, 1.245)), "agm")
		# VmAttack._falchion: the centre moved to the old body's middle, so
		# every station is the old one less 0.04; long fixed strakes
		k = kit(burnt)
		VehicleAircraft.missile(k, k.root, Vector3(0, 0, 0.04), 2.92, 0.064, LIGHT, VehicleAircraft.seeker(0.28, 0.0256),
			[VehicleAircraft.fin_set(-0.49, 0.11, 0.0448, -0.42, 0.09), VehicleAircraft.fin_set(1.205, 1.415, 0.0832)], Vector2(-0.88, 0.06), Vector3(0.07, 0.07, 1.8), 0.11)
		assert(glass_count(k) == glass)
		check(k, env(Vector3(-0.1083, -0.1083, -1.4193), Vector3(0.1083, 0.134, 1.5)), "falchion")
		# --- store pods ----------------------------------------------------------
		# VmAttack._sniper (2.39 m, r 0.16, on its adapter)
		L = 2.39
		r = 0.16
		var st := [[-0.5 * L, 0, r * 0.2, r * 0.2, r * 0.2], [-0.47 * L, 0, r * 0.72, r * 0.72, r * 0.72], [-0.42 * L, 0, r * 0.95, r * 0.95, r * 0.95],
			[-0.36 * L, 0, r, r, r], [0.3 * L, 0, r, r, r], [0.45 * L, 0, r * 0.8, r * 0.8, r * 0.8], [0.5 * L, 0, r * 0.45, r * 0.45, r * 0.45]]
		k = kit(burnt)
		VehicleAircraft.pod(k, k.root, Vector3.ZERO, st, "paint", GREY, [-0.36 * L], VehicleAircraft.POD_TARGETING, 0, [], Vector3(0.1, 0.08, L * 0.5))
		assert(glass_count(k) == glass, "targeting window glass follows the wreck state")
		check(k, env(Vector3(-0.1632, -0.1632, -1.195), Vector3(0.1632, 0.23, 1.195)), "attack sniper")
		# VmFighter._sniper: the faceted head ahead of -0.85, no adapter (lugs show)
		r = 0.15
		st = [[-1.19, 0, r * 0.3, r * 0.3, r * 0.3], [-1.12, 0, r * 0.75, r * 0.75, r * 0.75], [-1.0, 0, r * 0.95, r * 0.95, r * 0.95], [-0.85, 0, r, r, r],
			[0.9, 0, r, r, r], [1.1, 0, r * 0.82, r * 0.82, r * 0.82], [1.2, 0, r * 0.45, r * 0.45, r * 0.45]]
		k = kit(burnt)
		VehicleAircraft.pod(k, k.root, Vector3.ZERO, st, "paint", GREY, [-0.85], VehicleAircraft.POD_TARGETING)
		assert(glass_count(k) == glass)
		check(k, env(Vector3(-0.15, -0.1605, -1.19), Vector3(0.15, 0.1462, 1.2), 0.008, 0.04), "fighter sniper")
		# VmAttack._ecm_pod (ALQ-131: deep and narrow, bay seams, adapter)
		L = 2.84
		st = [[-0.5 * L, 0, 0.05, 0.08, 0.1, 2, 2], [-0.46 * L, 0, 0.11, 0.17, 0.21, 2.2, 2.2], [-0.4 * L, 0, 0.14, 0.22, 0.26, 2.6, 2.6],
			[0.38 * L, 0, 0.14, 0.22, 0.26, 2.6, 2.6], [0.46 * L, 0, 0.11, 0.17, 0.21, 2.2, 2.2], [0.5 * L, 0, 0.05, 0.08, 0.1, 2, 2]]
		k = kit(burnt)
		VehicleAircraft.pod(k, k.root, Vector3.ZERO, st, "paint", LIGHT, [-0.4 * L, -0.15 * L, 0.15 * L, 0.38 * L], VehicleAircraft.POD_ECM, 0, [], Vector3(0.1, 0.08, L * 0.4))
		check(k, env(Vector3(-0.15, -0.27, -1.42), Vector3(0.15, 0.29, 1.42)), "alq131")
		# VmFighter._alq184: radome joints at both ends, antenna fairings under
		r = 0.17
		st = [[-1.95, 0, 0.02, 0.02, 0.02], [-1.82, 0, r * 0.6, r * 0.6, r * 0.6], [-1.6, 0, r * 0.95, r * 0.95, r * 0.95], [-1.45, 0, r, r, r],
			[1.45, 0, r, r, r], [1.6, 0, r * 0.95, r * 0.95, r * 0.95], [1.82, 0, r * 0.6, r * 0.6, r * 0.6], [1.95, 0, 0.02, 0.02, 0.02]]
		k = kit(burnt)
		VehicleAircraft.pod(k, k.root, Vector3.ZERO, st, "paint", LIGHT, [-1.45, 1.45], VehicleAircraft.POD_ECM, 0, [-1.1, 1.1])
		check(k, env(Vector3(-0.17, -0.224, -1.95), Vector3(0.17, 0.1717, 1.95), 0.006, 0.04), "alq184")
		# VmPlane.drop_tank (4.6 m, r 0.35): three tail fins, the barrel's seams
		L = 4.6
		r = 0.35
		st = [[-0.5 * L, 0, 0, 0, 0], [-0.42 * L, 0, r * 0.5, r * 0.5, r * 0.5], [-0.25 * L, 0, r * 0.92, r * 0.92, r * 0.92], [-0.05 * L, 0, r, r, r],
			[0.15 * L, 0, r, r, r], [0.35 * L, 0, r * 0.75, r * 0.75, r * 0.75], [0.5 * L, 0, r * 0.1, r * 0.1, r * 0.1]]
		k = kit(burnt)
		VehicleAircraft.pod(k, k.root, Vector3.ZERO, st, "aircraft", GREY, [-0.05 * L, 0.15 * L], VehicleAircraft.POD_TANK, 3)
		check(k, env(Vector3(-0.4411, -0.5075, -2.3), Vector3(0.4411, 0.35, 2.3), 0.006, 0.04), "drop tank")
		# VmCore._fuel_tank (the Black Hawk's 230-gallon tank on its adapter)
		k = kit(burnt)
		VehicleAircraft.pod(k, k.root, Vector3.ZERO, VehicleAircraft.tank_stations(-1.05, 1.05, 0.34, 0.57, 0.5), "aircraft", DRAB, [-1.05, 1.05], VehicleAircraft.POD_TANK, 0, [], Vector3(0.06, 0.13, 1.2))
		check(k, env(Vector3(-0.34, -0.34, -1.6192), Vector3(0.34, 0.46, 1.5523)), "uh60 tank")
		# --- engine faces ----------------------------------------------------------
		# a turboshaft's face on a cowling's front (vm_heli, vm_core)
		k = kit(burnt)
		VehicleAircraft.intake_face(k, k.root, Vector3.ZERO, 0.3, Vector3.FORWARD, 0.13)
		check(k, env(Vector3(-0.3, -0.3, -0.05), Vector3(0.3, 0.3, 0.02)), "heli face")
		k = kit(burnt)
		VehicleAircraft.intake_face(k, k.root, Vector3.ZERO, 0.3, Vector3.FORWARD, 0.13, 0.0, 0, 8)
		check(k, env(Vector3(-0.3, -0.3, -0.1), Vector3(0.3, 0.3, 0.02)), "heli face with vanes")
		# the A-10's fan deep in its tilted nacelle: spinner and 18 blades
		var b := Basis.from_euler(Vector3(0.06, 0, 0))
		k = kit(burnt)
		VehicleAircraft.intake_face(k, k.root, b * Vector3(0, 0, 0.64), 0.465, b * Vector3.FORWARD, 0.17, 0.34, 18)
		check(k, env(Vector3(-0.465, -0.5034, 0.2893), Vector3(0.465, 0.4267, 0.6817)), "a10 fan")
		# the Kajman's dust protector, its cone in the airframe's paint
		k = kit(burnt)
		VehicleAircraft.intake_face(k, k.root, Vector3.ZERO, 0.4, Vector3.FORWARD, 0.0, 0.0, 0, 0, Vector2(0.42, 0.36), "aircraft", DRAB)
		check(k, env(Vector3(-0.4, -0.4, -0.43), Vector3(0.4, 0.4, 0.03)), "dust protector")
		# a face opening sideways keeps its plane at the centre given
		k = kit(burnt)
		VehicleAircraft.intake_face(k, k.root, Vector3(1, 2, 0), 0.25, Vector3.RIGHT, 0.08)
		check(k, env(Vector3(0.96, 1.75, -0.25), Vector3(1.06, 2.25, 0.25)), "side face")
		# --- pylons ------------------------------------------------------------------
		# the default call is still exactly the old pylon, payload point and all
		var a := kit(burnt)
		var o := kit(burnt)
		assert(VehicleAircraft.hardpoint(a, a.root, Vector3(0.5, 0.5, -0.4), 1.5, 0.28, GREY, 0.16) == old_hardpoint(o, o.root, Vector3(0.5, 0.5, -0.4), 1.5, 0.28, GREY, 0.16))
		same_parts(a, o, "default hardpoint")
		# a helicopter's stub-wing pylon, the old gunmetal box (0.1, 0.24, 0.62)
		# centred 0.18 under the wing station, a 0.2 m rocket pod under it
		k = kit(burnt)
		var top := Vector3(1.7, 2.19 - 0.06, -0.1)
		var payload := VehicleAircraft.hardpoint(k, k.root, top, 0.62, 0.24, null, 0.2, 0.1, "gunmetal_w", 0.04)
		assert(payload.is_equal_approx(Vector3(1.7, 2.19 - 0.5, -0.1)), "a pylon keeps its payload point")
		var gunmetal := Mats.get_mat(VehicleMaterials.key("gunmetal_w" if not burnt else "burnt", k.surface_family))
		assert(parts(k, k.root)[0][1] == gunmetal, "the pylon takes the material it is given")
		check(k, env(Vector3(1.65, 1.89, -0.41), Vector3(1.75, 2.17, 0.21), 0.07), "heli pylon")
		k = kit(burnt)
		assert(VehicleAircraft.hardpoint(k, k.root, Vector3.ZERO, 1.3, 0.2, null, 0.0, 0.12, "gunmetal_w", 0.0, false).is_equal_approx(Vector3(0, -0.2, 0)))
		check(k, env(Vector3(-0.06, -0.2, -0.65), Vector3(0.06, 0.0, 0.65), 0.02), "launcher pylon")
		# --- rotor hub caps, built on a rotor pivot that keeps spinning them --------
		k = kit(burnt)
		var rotor := k._pivot(k.root, Vector3(0, 4.32, -5.95))
		VehicleRotors.hub_cap(k, rotor, Vector3(0, 0.24, 0), 0.4, 0.78, 0.22, 6, "aircraft", DRAB, false)
		check(k, env(Vector3(-0.6755, 0.13, -0.78), Vector3(0.6755, 0.35, 0.78), 0.002), "hexagonal cap", rotor)
		k = kit(burnt)
		rotor = k._pivot(k.root, Vector3(0, 3.62, -2.0))
		VehicleRotors.hub_cap(k, rotor, Vector3(0, 0.22, 0), 0.5, 0.84, 0.2, 8, "aircraft", DRAB, true, Vector3(0.2, 0.5, 0.1))
		check(k, env(Vector3(-0.84, 0.12, -0.84), Vector3(0.84, 0.42, 0.84), 0.002), "two-tier cap", rotor)
		k = kit(burnt)
		rotor = k._pivot(k.root, Vector3(0, 3.62, -2.0))
		VehicleRotors.hub_cap(k, rotor, Vector3(0, 0.3, 0), 0.16, 0.2, 0.3, 10, "gunmetal_w", null, false, Vector3.ZERO, 4, 0.5, PI / 4)
		check(k, env(Vector3(-0.4391, 0.15, -0.4391), Vector3(0.4391, 0.51, 0.4391), 0.02), "bifilar cap", rotor)
		k = kit(burnt)
		rotor = k._pivot(k.root, Vector3(0, 4.45, -2.5))
		VehicleRotors.hub_cap(k, rotor, Vector3(0, 0.2, 0), 0.36, 0.5, 0.18, 10)
		check(k, env(Vector3(-0.4755, 0.11, -0.5), Vector3(0.4755, 0.29, 0.5), 0.002), "round cap", rotor)
	print("VEHICLE_PARTS_AIRCRAFT passed")
	TestRun.quit(get_tree())
