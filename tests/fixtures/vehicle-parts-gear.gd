extends Node
## The running gear and fittings of the third extraction pass: track guards,
## tow cables, spare track links, exhaust runs and silencers, wishbones, air
## cleaners, searchlights, light bars and beacons. Each is built where an old
## hand-built copy stood, live and wrecked: it folds into its parent, registers
## no animation, stays inside the envelope of the geometry it replaces (plus
## the allowances its doc comment states) and drops its lenses on wrecks.

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

func count(k: VehicleModels, kind: String) -> int:
	var mat := Mats.get_mat(VehicleMaterials.key(kind, k.surface_family))
	var n := 0
	for part: Array in parts(k):
		if part[1] == mat:
			n += 1
	return n

## Parts built live, per label: a wreck must build fewer when it drops lenses.
var live := {}

## `lensed`: the live part carries lenses (signal_lens or headlamp), which the
## wreck must leave out rather than merely blacken.
func check(k: VehicleModels, envelope: AABB, label: String, lensed := false, exhausts := 0) -> void:
	assert(k.root.get_child_count() == 0, label + ": construction pivots must fold into their parent")
	assert(k.wheels.is_empty() and k.rotors.is_empty() and k.antennas.is_empty() and k.belts.is_empty(), label + ": static parts must not register wheel, rotor, antenna or belt animation")
	assert(k.turret == null and k.elev == null and k.gun_tip == null and k.mg_tip == null, label + ": builders leave turrets and muzzle markers to the caller")
	assert(k.exhausts.size() == exhausts, "%s: %d exhaust mouths noted, %d expected" % [label, k.exhausts.size(), exhausts])
	assert(not parts(k).is_empty(), label + ": nothing was built")
	var box := bounds(k)
	assert(box.size.is_finite() and box.position.is_finite(), label + ": non-finite geometry")
	if OS.has_environment("FL_DEBUG_PART_BOUNDS"):
		print("PART %s%s %s verts=%d parts=%d" % [label, " (wreck)" if k.burnt else "", box, vertices(k), parts(k).size()])
	else:
		assert(envelope.grow(0.0005).encloses(box), "%s: %s escapes %s" % [label, box, envelope])
	if lensed:
		var lenses := count(k, "signal_lens") + count(k, "headlamp")
		if k.burnt:
			assert(live.has(label) and parts(k).size() < int(live[label]), label + ": a wreck leaves its lenses out")
		else:
			assert(lenses > 0, label + ": the lenses are missing")
	if k.burnt:
		var burnt := Mats.get_mat(VehicleMaterials.key("burnt", k.surface_family))
		for part: Array in parts(k):
			assert(part[1] == burnt, label + ": wrecks use the burnt material throughout")
	else:
		live[label] = parts(k).size()
	k.root.free()

func _ready() -> void:
	TestRun.watch()
	var olive := Color(0.3, 0.33, 0.22)
	var grey := Color(0.18, 0.18, 0.18)
	var amber := Color(0.8, 0.46, 0.1)
	var red := Color(0.62, 0.1, 0.08)
	var white := Color(0.9, 0.9, 0.86)
	for burnt in [false, true]:
		# Track guards: the T-55's shelf with its lip, six gussets and both
		# raked mudguards; the T-100's on its own with the front plate.
		var k := kit(burnt)
		VehicleBody.track_guard(k, k.root, Vector3(1.52, 1.28, -0.05), Vector3(0.3, 0.035, 5.6), 1.0, "paint", olive, 6, 0.075, Vector2(0.53, 0.21), Vector2(0.525, 0.194))
		check(k, AABB(Vector3(1.365, 1.05, -3.395), Vector3(0.33, 0.315, 6.685)), "T-55 track guard")
		k = kit(burnt)
		VehicleBody.track_guard(k, k.root, Vector3(-1.7, 1.03, 0.05), Vector3(0.24, 0.05, 7.4), -1.0, "paint", olive, 4, 0.0, Vector2(0.3, 0.23))
		check(k, AABB(Vector3(-1.85, 0.775, -3.97), Vector3(0.28, 0.321, 7.725)), "T-100 track guard")
		k = kit(burnt)
		VehicleBody.track_guard(k, k.root, Vector3(1.64, 1.78, 0.0), Vector3(0.12, 0.05, 7.0), 1.0, "paint", olive, 0, 0.0, Vector2.ZERO, Vector2.ZERO, false)
		check(k, AABB(Vector3(1.58, 1.752, -3.5), Vector3(0.1475, 0.063, 7.0)), "sponson lip")
		# Tow cables: the Slammer's along the sponson, the BTR's straight run.
		k = kit(burnt)
		VehicleFittings.tow_cable(k, k.root, [Vector3(1.79, 1.4, -2.9), Vector3(1.76, 1.4, 1.6)], 0.028, 0.04)
		check(k, AABB(Vector3(1.68, 1.28, -2.95), Vector3(0.2, 0.24, 4.6)), "tow cable")
		k = kit(burnt)
		VehicleFittings.tow_cable(k, k.root, [Vector3(-1.47, 1.3, -2.7), Vector3(-1.47, 1.3, 0.2), Vector3(-1.47, 1.25, 1.7)], 0.022, 0.0, 2)
		check(k, AABB(Vector3(-1.6, 1.16, -2.75), Vector3(0.2, 0.23, 4.5)), "clipped tow cable")
		# The T-55's four spare links across its glacis.
		k = kit(burnt)
		var gu := Vector3(0, 0.5, 0.96).normalized()
		var gn := Vector3(0, gu.z, -gu.y)
		VehicleTracks.spare_links(k, k.root, Vector3(0.53, 1.395, -2.3216), Vector3.RIGHT, gn, 4, Vector3(0.175, 0.51, 0.046), 0.19)
		check(k, AABB(Vector3(0.137, 1.277, -2.582), Vector3(0.786, 0.301, 0.487)), "spare links")
		# Exhaust runs: the offroad's straight pipe and tip, the quad's bent
		# header through its silencer, a car's plain open pipe; silencers.
		k = kit(burnt)
		VehicleFittings.exhaust_run(k, k.root, [Vector3(0.38, 0.33, 0.15), Vector3(0.38, 0.33, 2.34)], 0.035, Vector3.ZERO, Vector3.ZERO, Vector2(0.12, 0.045), 0.1)
		check(k, AABB(Vector3(0.302, 0.283, 0.145), Vector3(0.156, 0.151, 2.321)), "exhaust run", false, 1)
		k = kit(burnt)
		VehicleFittings.exhaust_run(k, k.root, [Vector3(0.14, 0.5, 0.1), Vector3(0.25, 0.56, 0.65), Vector3(0.25, 0.56, 0.94)], 0.025, Vector3(0.25, 0.56, 0.8), Vector3(0.11, 0.11, 0.3), Vector2(0.06, 0.025))
		check(k, AABB(Vector3(0.08, 0.44, 0.07), Vector3(0.23, 0.18, 0.934)), "quad exhaust", false, 1)
		k = kit(burnt)
		VehicleFittings.exhaust_run(k, k.root, [Vector3(-0.35, 0.22, 0.0), Vector3(-0.35, 0.22, 1.6)], 0.03, Vector3.ZERO, Vector3.ZERO, Vector2.ZERO, 0.08)
		check(k, AABB(Vector3(-0.42, 0.185, -0.005), Vector3(0.14, 0.12, 1.61)), "open exhaust")
		k = kit(burnt)
		VehicleFittings.silencer(k, k.root, Vector3(0.78, 0.8, -1.35), Vector3(0.2, 0.2, 0.6), "metal_dark")
		check(k, AABB(Vector3(0.6755, 0.6955, -1.65), Vector3(0.209, 0.209, 0.6)), "silencer")
		k = kit(burnt)
		VehicleFittings.silencer(k, k.root, Vector3(0, 0.5, 0), Vector3(0.5, 0.18, 0.3), "gunmetal_w", null, false)
		check(k, AABB(Vector3(-0.25, 0.4064, -0.156), Vector3(0.5, 0.1872, 0.312)), "box silencer")
		# Wishbones: the Hunter's front right corner with its coil-over, the
		# Marshall's arms alone, the Humvee's on its portal hub.
		k = kit(burnt)
		VehicleRunningGear.wishbone(k, k.root, Vector3(0.302, 0.485, -1.9), Vector3(0.798, 0.555, -1.9), Vector3(0.322, 0.868, -1.94), Vector3(0.778, 0.813, -1.94), Vector2(0.16, 0.07), Vector2(0.14, 0.07), Vector3(0.453, 1.133, -1.66), Vector3(0.667, 0.627, -1.66), 0.075)
		check(k, AABB(Vector3(0.255, 0.438, -2.015), Vector3(0.63, 0.73, 0.435)), "wishbone")
		k = kit(burnt)
		var x := 1.08
		var r := 0.6
		VehicleRunningGear.wishbone(k, k.root, Vector3(-(x - 0.608), r - 0.109, 0.8), Vector3(-(x - 0.192), r - 0.051, 0.8), Vector3(-(x - 0.589), r + 0.263, 0.75), Vector3(-(x - 0.211), r + 0.217, 0.75), Vector2(0.16, 0.08), Vector2(0.14, 0.07))
		check(k, AABB(Vector3(-1.0, 0.42, 0.675), Vector3(0.58, 0.49, 0.21)), "arms")
		k = kit(burnt)
		VehicleRunningGear.wishbone(k, k.root, Vector3(0.3, 0.45, 1.66), Vector3(0.66, 0.41, 1.66), Vector3(0.3, 0.72, 1.61), Vector3(0.66, 0.59, 1.61), Vector2(0.08, 0.06), Vector2(0.07, 0.05), Vector3.ZERO, Vector3.ZERO, 0.06, false)
		check(k, AABB(Vector3(0.26, 0.37, 1.57), Vector3(0.44, 0.39, 0.135)), "portal wishbone")
		k = kit(burnt)
		VehicleRunningGear.wishbone(k, k.root, Vector3(0.15, 0.3, -0.68), Vector3(0.38, 0.27, -0.6), Vector3(0.15, 0.42, -0.54), Vector3(0.36, 0.36, -0.6), Vector2(0.08, 0.036), Vector2(0.08, 0.036), Vector3(0.15, 0.62, -0.48), Vector3(0.33, 0.32, -0.58), 0.025, true, "gunmetal_w", null, Color(0.55, 0.12, 0.08))
		check(k, AABB(Vector3(0.12, 0.24, -0.73), Vector3(0.33, 0.4, 0.27)), "quad wishbone")
		# Air cleaners: the HEMTT's canister behind the cab, the tractor's
		# stack, the Zamak's with its intake hose.
		k = kit(burnt)
		VehicleFittings.air_cleaner(k, k.root, Vector3(-0.85, 2.0, -2.68), 0.24, 1.3, "paint", olive, Vector2(0.2, 0.1), Vector3.FORWARD)
		check(k, AABB(Vector3(-1.1, 1.35, -3.09), Vector3(0.5, 1.4, 0.66)), "air cleaner")
		k = kit(burnt)
		VehicleFittings.air_cleaner(k, k.root, Vector3(-0.22, 1.88, -0.62), 0.05, 0.5, "paint", grey, Vector2(0.08, 0.1))
		check(k, AABB(Vector3(-0.3, 1.63, -0.7), Vector3(0.16, 0.6, 0.16)), "intake stack")
		k = kit(burnt)
		VehicleFittings.air_cleaner(k, k.root, Vector3(0.95, 1.85, -0.52), 0.17, 0.9, "paint", olive, Vector2(0.2, 0.08), Vector3.FORWARD, Vector3(0.7, 1.45, -0.9))
		check(k, AABB(Vector3(0.6, 1.34, -0.96), Vector3(0.56, 1.04, 0.64)), "air cleaner and hose")
		# Searchlights: a ship's on its yoke, the T-55's IR light on its
		# bracket, a fixed boat lamp, a helicopter's landing light.
		k = kit(burnt)
		VehicleFittings.searchlight(k, k.root, Vector3(0, 0.3, 0), Vector3.FORWARD, 0.12, 0.3, "yoke", Vector3.ZERO, "paint", grey, 0.14, true)
		check(k, AABB(Vector3(-0.19, -0.001, -0.157), Vector3(0.38, 0.442, 0.457)), "yoke searchlight", true)
		k = kit(burnt)
		VehicleFittings.searchlight(k, k.root, Vector3(0.5, 0.82, -1.02), Vector3.FORWARD, 0.17, 0.34, "bracket", Vector3(0.5, 0.52, -0.98), "paint", olive)
		check(k, AABB(Vector3(0.31, 0.519, -1.2), Vector3(0.38, 0.491, 0.37)), "bracket searchlight", true)
		k = kit(burnt)
		VehicleFittings.searchlight(k, k.root, Vector3(-0.45, 2.1, -0.6), Vector3.FORWARD, 0.11, 0.16, "", Vector3.ZERO, "gunmetal_w", null, 0.1)
		check(k, AABB(Vector3(-0.565, 1.985, -0.69), Vector3(0.23, 0.23, 0.19)), "fixed lamp", true)
		k = kit(burnt)
		VehicleFittings.searchlight(k, k.root, Vector3(0, 0.6, -1.55), Vector3(0, -0.955, -0.296), 0.07, 0.04)
		check(k, AABB(Vector3(-0.075, 0.53, -1.63), Vector3(0.15, 0.13, 0.155)), "landing light", true)
		# Light bars: the ambulance's emergency bar, the Prowler's work bar,
		# the repair truck's beacon on its bar, the tractor's bare beacon.
		k = kit(burnt)
		VehicleFittings.light_bar(k, k.root, Vector3(0, 2.66, -0.75), Vector3(1.5, 0.1, 0.28), [red, red, white, red, red], "emergency", Vector3(0.26, 0.09, 0.24), -1.0, "plain", Color(0.22, 0.22, 0.22))
		check(k, AABB(Vector3(-0.75, 2.61, -0.9), Vector3(1.5, 0.175, 0.3)), "emergency bar", true)
		k = kit(burnt)
		VehicleFittings.light_bar(k, k.root, Vector3(0, 1.85, -0.3), Vector3(0.9, 0.09, 0.08), [white, white, white, white], "work", Vector3(0.14, 0.06, 0), -1.0, "gunmetal_w", null)
		check(k, AABB(Vector3(-0.462, 1.783, -0.364), Vector3(0.924, 0.112, 0.117)), "work bar", true)
		k = kit(burnt)
		VehicleFittings.light_bar(k, k.root, Vector3(0, 1.815, 0), Vector3(0.5, 0.05, 0.16), [amber], "beacon", Vector3(0.08, 0.1, 0.07))
		check(k, AABB(Vector3(-0.25, 1.79, -0.09), Vector3(0.5, 0.15, 0.18)), "beacon bar", true)
		k = kit(burnt)
		VehicleFittings.light_bar(k, k.root, Vector3(-0.3, 2.72, 0), Vector3.ZERO, [amber], "beacon", Vector3(0.05, 0.08, 0.05))
		check(k, AABB(Vector3(-0.356, 2.72, -0.056), Vector3(0.112, 0.08, 0.112)), "beacon", true)
	print("VEHICLE_PARTS_GEAR passed")
	TestRun.quit(get_tree())
