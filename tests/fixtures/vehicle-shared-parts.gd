extends Node
## The twenty shared parts of the component extraction: each folds into its
## parent, registers no animation, keeps the muzzle it was given, stays inside
## the envelope of the geometry it replaced and drops intact glass on wrecks.

func kit(burnt := false) -> VehicleModels:
	var k := VehicleModels.new()
	k.root = Node3D.new()
	k._baking = true
	k.burnt = burnt
	return k

func bounds(k: VehicleModels) -> AABB:
	var box := AABB()
	var first := true
	for part: Array in k._parts.get(k.root, []):
		var basis: Basis = part[7] if part[7] is Basis else Basis.from_euler(part[5]) * Basis.from_scale(part[6])
		var aabb := Transform3D(basis, part[4]) * (part[0] as Mesh).get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	return box

func materials(k: VehicleModels) -> Array:
	var out := []
	for part: Array in k._parts.get(k.root, []):
		out.append(part[1])
	return out

func check(k: VehicleModels, envelope: AABB, label: String) -> void:
	assert(k.root.get_child_count() == 0, label + ": construction pivots must fold into their parent")
	assert(k.wheels.is_empty(), label + ": static parts must not register wheel animation")
	assert(not k._parts.get(k.root, []).is_empty(), label + ": nothing was built")
	var box := bounds(k)
	assert(box.size.is_finite() and box.position.is_finite(), label + ": non-finite geometry")
	if OS.has_environment("FL_DEBUG_PART_BOUNDS"):
		print("PART %s %s" % [label, box])
	else:
		assert(envelope.grow(0.0005).encloses(box), "%s: %s escapes %s" % [label, box, envelope])
	if k.burnt:
		var burnt := Mats.get_mat(VehicleMaterials.key("burnt", k.surface_family))
		for m in materials(k):
			assert(m == burnt, label + ": wrecks use the burnt material throughout")
	k.root.free()

func glass_count(k: VehicleModels) -> int:
	var glass := Mats.get_mat(VehicleMaterials.key("glass", k.surface_family))
	return materials(k).count(glass)

func _ready() -> void:
	TestRun.watch()
	var olive := Color(0.3, 0.33, 0.22)
	for burnt in [false, true]:
		# Guns keep the muzzle they were given, whatever their proportions.
		var muzzle := Vector3(0, 0.5, -1.47)
		var k := kit(burnt)
		assert(VehicleWeapons.hmg(k, k.root, Vector3(0, 0.5, 0.1), muzzle, 1.0, -1.0, true) == muzzle)
		check(k, AABB(Vector3(-0.3, 0.3, -1.5), Vector3(0.6, 0.4, 2.05)), "hmg")
		k = kit(burnt)
		assert(VehicleWeapons.mmg(k, k.root, Vector3.ZERO, Vector3(0, 0, -0.93)) == Vector3(0, 0, -0.93))
		check(k, AABB(Vector3(-0.16, -0.2, -0.95), Vector3(0.32, 0.32, 1.45)), "mmg")
		k = kit(burnt)
		assert(VehicleWeapons.gmg(k, k.root, Vector3.ZERO, Vector3(0, 0, -0.9)) == Vector3(0, 0, -0.9))
		check(k, AABB(Vector3(-0.2, -0.25, -0.92), Vector3(0.7, 0.5, 1.4)), "gmg")
		k = kit(burnt)
		var tip := VehicleWeapons.autocannon(k, k.root, Vector3(0, 0, -1.23), Vector3(0, 0, -3.54), Vector2(0.1, 0.3), Vector2(0.045, 0.04), Vector2(0.065, 0.24), "gunmetal_w", null, 2)
		assert(tip == Vector3(0, 0, -3.54))
		check(k, AABB(Vector3(-0.11, -0.11, -3.56), Vector3(0.22, 0.22, 2.35)), "autocannon")
		k = kit(burnt)
		# A rotary cluster may run along any axis; its barrels reach the muzzle.
		tip = VehicleWeapons.rotary(k, k.root, Vector3(0, 0, 0), Vector3(0.8, -0.2, -0.6), 6, 0.04, 0.012)
		assert(tip == Vector3(0.8, -0.2, -0.6))
		check(k, AABB(Vector3(-0.1, -0.3, -0.7), Vector3(1.0, 0.4, 0.8)), "rotary")
		k = kit(burnt)
		VehicleWeapons.coax(k, k.root, Vector3(0.3, 0.2, -1.3), 0.3, 0.025)
		check(k, AABB(Vector3(0.24, 0.14, -1.46), Vector3(0.12, 0.12, 0.32)), "coax")
		k = kit(burnt)
		VehicleWeapons.launch_tube(k, k.root, Vector3(0, 0.48, -0.25), 0.085, 1.25, "paint", olive)
		check(k, AABB(Vector3(-0.11, 0.37, -0.89), Vector3(0.22, 0.22, 1.29)), "launch_tube")
		# Turret and hull fittings.
		k = kit(burnt)
		VehicleMounts.turret_ring(k, k.root, Vector3(0, 0.03, 0.1), 1.1, 1.14, 0.06, "gunmetal_w")
		check(k, AABB(Vector3(-1.17, 0.0, -1.07), Vector3(2.34, 0.06, 2.34)), "turret_ring")
		k = kit(burnt)
		VehicleMounts.sight(k, k.root, Vector3(-0.42, 0.78, -0.5), Vector3(0.3, 0.26, 0.34), [], "paint", olive)
		assert(glass_count(k) == (0 if burnt else 1), "sight glass follows the wreck state")
		check(k, AABB(Vector3(-0.6, 0.64, -0.75), Vector3(0.36, 0.28, 0.43)), "sight")
		k = kit(burnt)
		VehicleMounts.sight(k, k.root, Vector3(0.45, 1.05, 0.55), Vector3(0.36, 0.3, 0.36), [Rect2(Vector2(-0.06, 0.02), Vector2(0.12, 0.12)), Rect2(Vector2(0.09, 0.02), Vector2(0.08, 0.08))], "paint", olive, Vector3(0.08, 0.1, 0.33))
		assert(glass_count(k) == (0 if burnt else 2))
		check(k, AABB(Vector3(0.24, 0.71, 0.29), Vector3(0.42, 0.5, 0.46)), "panoramic sight")
		k = kit(burnt)
		VehicleMounts.cupola(k, k.root, Vector3(0.62, 0.88, 0.62), 0.36, 0.38, 0.16, 5, -0.9, 0.45, "paint", olive)
		assert(glass_count(k) == (0 if burnt else 5))
		check(k, AABB(Vector3(0.2, 0.79, 0.18), Vector3(0.84, 0.2, 0.86)), "cupola")
		k = kit(burnt)
		VehicleMounts.era_brick(k, k.root, Vector3(0, 0, 0.05), Vector3(0.3, 0.2, 0.1), Vector3.ZERO, "paint", olive)
		check(k, AABB(Vector3(-0.15, -0.1, 0.0), Vector3(0.3, 0.2, 0.105)), "era_brick")
		k = kit(burnt)
		VehicleFittings.panel_hatch(k, k.root, Vector3(0, 0.03, 0), Vector3(0.62, 0.06, 0.6), "paint", olive, -1.0)
		check(k, AABB(Vector3(-0.35, 0.0, -0.33), Vector3(0.7, 0.12, 0.66)), "panel_hatch")
		k = kit(burnt)
		VehicleFittings.evacuator(k, k.root, Vector3(0, 1.0, -3.8), 0.135, 0.56)
		check(k, AABB(Vector3(-0.14, 0.86, -4.08), Vector3(0.28, 0.29, 0.56)), "evacuator")
		# Lights.
		k = kit(burnt)
		VehicleFittings.dome_light(k, k.root, Vector3(0, 4.45, 7.65), 0.06, Color(0.55, 0.08, 0.06))
		check(k, AABB(Vector3(-0.065, 4.39, 7.585), Vector3(0.13, 0.12, 0.13)), "dome_light")
		k = kit(burnt)
		VehicleFittings.nav_light(k, k.root, Vector3(1.12, 2.3, -4.2), Vector3(0.05, 0.05, 0.06), 1.0)
		check(k, AABB(Vector3(1.09, 2.27, -4.24), Vector3(0.07, 0.07, 0.08)), "nav_light")
		# Aircraft.
		k = kit(burnt)
		VehicleRotors.mast(k, k.root, Vector3(0, 3.3, -2.0), 0.16, 0.2, 0.55, [Vector2(3.28, 0.34)])
		check(k, AABB(Vector3(-0.36, 3.02, -2.36), Vector3(0.72, 0.56, 0.72)), "mast")
		k = kit(burnt)
		VehicleAircraft.turbine_exhaust(k, k.root, Vector3(1.0, 3.25, -1.45), Vector3(1.42, 3.3, -1.0), 0.2, 0.18)
		check(k, AABB(Vector3(0.78, 2.96, -1.67), Vector3(0.86, 0.63, 0.88)), "turbine_exhaust")
		# Trucks and stowage.
		k = kit(burnt)
		VehicleBody.fender(k, k.root, Vector3(0.86, 1.24, -2.42), Vector3(0.6, 0.04, 1.6), 1.0, "paint", olive)
		check(k, AABB(Vector3(0.46, 1.15, -3.23), Vector3(0.73, 0.12, 1.62)), "fender")
		k = kit(burnt)
		VehicleRunningGear.fuel_tank(k, k.root, Vector3(-1.0, 0.92, 0.1), Vector3(0.44, 0.44, 0.9), -1.0, "paint", olive)
		check(k, AABB(Vector3(-1.26, 0.69, -0.36), Vector3(0.52, 0.5, 0.92)), "fuel_tank")
		k = kit(burnt)
		VehicleRunningGear.fuel_tank(k, k.root, Vector3(0.95, 0.95, -1.2), Vector3(0.5, 0.52, 1.4), 1.0, "paint", olive, false)
		check(k, AABB(Vector3(0.66, 0.68, -1.91), Vector3(0.6, 0.6, 1.42)), "box fuel_tank")
		k = kit(burnt)
		VehicleCloth.roll(k, k.root, Vector3(0.05, 0.45, 2.84), 0.17, 0.9, Vector3(0, 0, PI / 2), Color(0.42, 0.38, 0.27))
		check(k, AABB(Vector3(-0.41, 0.27, 2.66), Vector3(0.92, 0.37, 0.36)), "roll")
	print("VEHICLE_SHARED_PARTS passed")
	TestRun.quit(get_tree())
