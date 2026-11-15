extends Node
## The gunners on crew-served vehicle guns, on the real models: the grips at
## a standing man's chest over the floor the builder gives him, a pickup's
## gun standing clear of its cab roof, the Humvee's gun in a turret that turns
## with it and out through its front shield, and, as the gun swings round
## its whole circle, the man kept on his floor and never in its line of fire.

## The pickups' cab roofs (their glasshouse tops), which the bore must clear.
const ROOFS := {"technical": 1.79, "offroad_hmg": 1.79}
const CREWED: Array[String] = ["technical", "offroad_hmg", "mb4wd_lmg", "humvee", "prowler_hmg"]


func _ready() -> void:
	TestRun.watch()
	# Every land vehicle with a man on its gun says where he stands: without
	# a floor he'd stand at arm's length behind the grips, wherever that is,
	# on the ground beside it or on its cab. (Door gunners crouch in their
	# doors and a boat's bow gunner kneels, behind the grips; a gun worked
	# from a seat has no man drawn on it.)
	for kind: String in Defs.VEHICLES:
		var any := VehicleModels.build(kind, 0, 0)
		var crewed := not any.mg_hands.is_empty() and (any.mg_hands[0] as Array).size() == 2
		if crewed and not any.gunner_seated and any.surface_family != "aircraft" and any.surface_family != "marine":
			assert(not any.gunner_floor.is_empty(), kind + " has a gunner and no floor for him")
		any.root.free()
	for kind: String in CREWED:
		var k := VehicleModels.build(kind, 0, 0)
		add_child(k.root)
		assert(k.mg_mounts.size() >= 1 and (k.mg_hands[0] as Array).size() == 2, kind + " gun has no grips")
		assert(not k.gunner_floor.is_empty(), kind + " has no floor for its gunner")
		var mount: Node3D = k.mg_mounts[0]
		var hands: Array = k.mg_hands[0]
		var st: Dictionary = k.gunner_floor
		var on: Node3D = st.on
		var area: Rect2 = st.area
		var grips := mount.global_transform * (((hands[0] as Vector3) + (hands[1] as Vector3)) * 0.5)
		var chest := grips.y - (on.global_transform * Vector3(0, float(st.y), 0)).y
		assert(chest > 1.2 and chest < 1.5, "%s grips %.2f m over the gunner's floor" % [kind, chest])
		if ROOFS.has(kind):
			var clear: float = k.mg_tip.global_position.y - float(ROOFS[kind])
			assert(clear > 0.38 and clear < 0.65, "%s bore %.2f m over the cab roof" % [kind, clear])
		if kind == "humvee":
			# the gun turns with the turret, its barrel a metre out of the
			# front shield, the man in the hatch behind the grips
			assert(k.turret.is_ancestor_of(mount), "humvee gun doesn't turn with its turret")
			var muzzle := k.turret.to_local(k.mg_tip.global_position)
			assert(muzzle.z < -1.6 and muzzle.y > 0.4 and muzzle.y < 0.6, "humvee muzzle at %s" % muzzle)
			var spot := Vector3(area.position.x, 0, area.position.y)
			var held := k.turret.to_local(grips)
			assert(spot.length() < 0.56 and spot.z > held.z + 0.2, "humvee gunner's spot %s, grips %s" % [spot, held])
		print("GUN_CREWS %s chest=%.2f" % [kind, chest])
		if area.size == Vector2.ZERO:
			continue
		# Swing the gun round: he stays on his floor, and behind the grips or
		# clear to the side of the gun, never in front of its muzzle.
		var inv := on.global_transform.affine_inverse()
		for i in 36:
			k.turret.rotation.y = TAU * i / 36.0
			var g3 := inv * (mount.global_transform * (((hands[0] as Vector3) + (hands[1] as Vector3)) * 0.5))
			var f3 := inv.basis * -mount.global_basis.z
			var g := Vector2(g3.x, g3.z)
			var f := Vector2(f3.x, f3.z).normalized()
			var at := Vehicle.gunner_spot(area, g, f)
			assert(area.grow(0.001).has_point(at), "%s gunner off his floor at %d" % [kind, i * 10])
			var ahead := (at - g).dot(f)
			var aside := absf((at - g).cross(f))
			assert(ahead < 0.05 or aside > 0.3, "%s gunner in the line of fire at %d deg: %.2f ahead, %.2f aside" % [kind, i * 10, ahead, aside])
		k.turret.rotation.y = 0.0
	print("GUN_CREWS passed")
	get_tree().quit()
